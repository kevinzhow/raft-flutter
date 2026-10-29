import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/client_release_notes.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/memory_storage.dart';

Map<String, Object?> _item(
  String tag, {
  String state = 'published',
  String date = '2026-10-13',
  List<Object?>? entries,
}) => {
  'releaseId': tag,
  'tag': tag,
  'version': '0.1.0',
  'date': date,
  'state': state,
  'entries':
      entries ??
      [
        {'type': 'feature', 'text': 'Thing', 'emphasis': false},
      ],
};

String _page(List<Object?> items) =>
    jsonEncode({'items': items, 'nextCursor': null});

void main() {
  group('parseClientReleaseNotes', () {
    test('reads the Web page shape and marks the first published Current', () {
      final notes = parseClientReleaseNotes(
        _page([
          _item('v0.1.0+6', state: 'retracted'),
          _item('v0.1.0+5'),
          _item('v0.1.0+4'),
        ]),
      );
      expect(notes.map((n) => n.id), ['v0.1.0+6', 'v0.1.0+5', 'v0.1.0+4']);
      expect(notes.map((n) => n.current), [false, true, false]);
      expect(notes.first.retracted, isTrue);
      expect(notes[1].entries.single.kind, RaftReleaseNoteKind.feature);
      expect(notes[1].entries.single.text, 'Thing');
    });

    test('a malformed document fails as a whole', () {
      for (final body in [
        'nope',
        '[]',
        '{"items": 1}',
        _page([_item('v1.0.0'), 'x']),
        _page([_item('v1.0.0', date: 'yesterday')]),
        _page([_item('v1.0.0', state: 'draft')]),
        _page([
          _item(
            'v1.0.0',
            entries: [
              {'type': 'wish', 'text': 'x', 'emphasis': false},
            ],
          ),
        ]),
        _page([
          _item(
            'v1.0.0',
            entries: [
              {'type': 'fix', 'text': 'x'},
            ],
          ),
        ]),
      ]) {
        expect(
          () => parseClientReleaseNotes(body),
          throwsFormatException,
          reason: body,
        );
      }
    });

    test('an empty page is an empty list', () {
      expect(parseClientReleaseNotes(_page([])), isEmpty);
    });

    // RAFT_RELEASE_NOTES_JSON=<file written by tool/release_notes.py>
    test('the release tool output parses', () {
      final path = Platform.environment['RAFT_RELEASE_NOTES_JSON'];
      if (path == null) return;
      final notes = parseClientReleaseNotes(File(path).readAsStringSync());
      expect(notes, isNotEmpty);
      expect(notes.first.current, isTrue);
    });
  });

  group('ClientReleaseNotes', () {
    late MemoryStorage storage;
    late DateTime now;
    late List<Uri> requests;
    var body = _page([_item('v0.1.0+5')]);
    Future<String?> Function(Uri) respond = (_) async => body;

    ClientReleaseNotes make() => ClientReleaseNotes(
      storage: storage,
      clock: () => now,
      fetch: (url) {
        requests.add(url);
        return respond(url);
      },
    );

    setUp(() {
      storage = MemoryStorage();
      now = DateTime(2026, 10, 13, 9);
      requests = [];
      body = _page([_item('v0.1.0+5')]);
      respond = (_) async => body;
    });

    test('downloads the latest release asset and keeps a copy', () async {
      final notes = await make().load();
      expect(notes.single.id, 'v0.1.0+5');
      expect(
        requests.single.toString(),
        'https://github.com/kevinzhow/raft-flutter/releases/latest/download/'
        'release-notes.json',
      );
      expect(storage.values, contains(ClientReleaseNotes.storageKey));
    });

    test('a recent copy is served without a request', () async {
      await make().load();
      now = now.add(const Duration(hours: 5));
      expect((await make().load()).single.id, 'v0.1.0+5');
      expect(requests, hasLength(1));
      now = now.add(const Duration(hours: 2));
      body = _page([_item('v0.1.0+6'), _item('v0.1.0+5')]);
      expect(await make().load(), hasLength(2));
      expect(requests, hasLength(2));
    });

    test('offline falls back to the last copy, else rethrows', () async {
      respond = (_) async => throw StateError('offline');
      await expectLater(make().load(), throwsStateError);
      respond = (_) async => body;
      await make().load();
      now = now.add(const Duration(days: 2));
      respond = (_) async => throw StateError('offline');
      expect((await make().load()).single.id, 'v0.1.0+5');
    });

    test('an unusable download keeps the last copy', () async {
      await make().load();
      now = now.add(const Duration(days: 2));
      respond = (_) async => '<html>captive portal</html>';
      expect((await make().load()).single.id, 'v0.1.0+5');
    });

    test('a release without the asset is an empty list', () async {
      respond = (_) async => null;
      expect(await make().load(), isEmpty);
    });

    test('concurrent loads share one request', () async {
      final service = make();
      await Future.wait([service.load(), service.load()]);
      expect(requests, hasLength(1));
    });
  });

  group('refresh points', () {
    late MemoryStorage storage;
    late DateTime now;
    late List<Uri> requests;
    var body = _page([_item('v0.1.0+6'), _item('v0.1.0+5')]);
    Future<String?> Function() respond = () async => body;

    ClientReleaseNotes make({int? appBuild = 21}) => ClientReleaseNotes(
      storage: storage,
      clock: () => now,
      appBuild: appBuild,
      fetch: (url) {
        requests.add(url);
        return respond();
      },
    );

    setUp(() {
      storage = MemoryStorage();
      now = DateTime(2026, 10, 13, 9);
      requests = [];
      body = _page([_item('v0.1.0+6'), _item('v0.1.0+5')]);
      respond = () async => body;
    });

    test('a copy fetched by an older app build is refreshed even when '
        'young', () async {
      await make(appBuild: 20).load();
      expect(requests, hasLength(1));
      now = now.add(const Duration(minutes: 5));
      await make(appBuild: 20).load();
      expect(requests, hasLength(1));
      // The app was updated: same copy, new build.
      await make(appBuild: 21).load();
      expect(requests, hasLength(2));
      await make(appBuild: 21).load();
      expect(requests, hasLength(2));
    });

    test('a copy without a recorded build is refreshed once', () async {
      storage.values[ClientReleaseNotes.storageKey] = jsonEncode({
        'fetchedAt': now.millisecondsSinceEpoch,
        'body': body,
      });
      await make().load();
      expect(requests, hasLength(1));
      await make().load();
      expect(requests, hasLength(1));
    });

    test('a copy without the required release is refetched', () async {
      body = _page([_item('v0.1.0+5')]);
      await make().load();
      body = _page([_item('v0.1.0+6'), _item('v0.1.0+5')]);
      final notes = await make().load(requireTag: 'v0.1.0+6');
      expect(notes.map((n) => n.id), ['v0.1.0+6', 'v0.1.0+5']);
      expect(requests, hasLength(2));
      await make().load(requireTag: 'v0.1.0+6');
      expect(requests, hasLength(2));
    });

    test('offline, a copy without the required release is an error', () async {
      body = _page([_item('v0.1.0+5')]);
      await make().load();
      respond = () async => throw StateError('offline');
      await expectLater(make().load(requireTag: 'v0.1.0+6'), throwsStateError);
      // Without a requirement the old copy still serves.
      expect((await make().load(force: true)).single.id, 'v0.1.0+5');
    });

    test('cached() reads the copy without a request', () async {
      expect(await make().cached(), isNull);
      await make().load();
      requests.clear();
      expect((await make().cached())!.map((n) => n.id), [
        'v0.1.0+6',
        'v0.1.0+5',
      ]);
      expect(requests, isEmpty);
    });

    test('refresh() always fetches and reports a failure', () async {
      await make().load();
      requests.clear();
      body = _page([_item('v0.1.0+7'), _item('v0.1.0+6')]);
      expect((await make().refresh()).first.id, 'v0.1.0+7');
      expect(requests, hasLength(1));
      respond = () async => throw StateError('offline');
      await expectLater(make().refresh(), throwsStateError);
      // The stored copy is untouched by the failure.
      expect((await make().cached())!.first.id, 'v0.1.0+7');
    });

    test('refresh(minAge) reuses a download made moments ago', () async {
      final notes = make();
      await notes.refresh();
      now = now.add(const Duration(seconds: 10));
      await notes.refresh(minAge: const Duration(seconds: 30));
      expect(requests, hasLength(1));
      now = now.add(const Duration(seconds: 30));
      await notes.refresh(minAge: const Duration(seconds: 30));
      expect(requests, hasLength(2));
    });

    test('concurrent refreshes share one request', () async {
      final notes = make();
      await Future.wait([notes.refresh(), notes.refresh()]);
      expect(requests, hasLength(1));
    });
  });

  group('releasesBetween', () {
    List<RaftReleaseNote> notes(Iterable<String> tags) => [
      for (final tag in tags)
        RaftReleaseNote(
          id: tag,
          date: '2026-10-13',
          version: tag.substring(1).split('+').first,
        ),
    ];

    test('is the offered release down to, not including, the installed '
        'one', () {
      final all = notes([
        'v0.1.0+9',
        'v0.1.0+8',
        'v0.1.0+7',
        'v0.1.0+6',
        'v0.1.0+5',
      ]);
      expect(
        releasesBetween(
          all,
          offeredTag: 'v0.1.0+8',
          installedTag: 'v0.1.0+6',
          installedVersion: '0.1.0',
        ).map((n) => n.id),
        ['v0.1.0+8', 'v0.1.0+7'],
      );
    });

    test('without the installed tag it is the offered release and any '
        'higher app version', () {
      final all = notes(['v0.2.0+1', 'v0.1.1+1', 'v0.1.0+9', 'v0.1.0+8']);
      expect(
        releasesBetween(
          all,
          offeredTag: 'v0.2.0+1',
          installedTag: null,
          installedVersion: '0.1.0',
        ).map((n) => n.id),
        ['v0.2.0+1', 'v0.1.1+1'],
      );
      expect(
        releasesBetween(
          all,
          offeredTag: 'v0.1.0+9',
          installedTag: '',
          installedVersion: '0.1.0',
        ).map((n) => n.id),
        ['v0.1.0+9'],
      );
    });

    test('is empty when the offered release has no notes, and skips '
        'retracted ones', () {
      final all = [
        ...notes(['v0.1.0+9']),
        const RaftReleaseNote(
          id: 'v0.1.0+8',
          date: '2026-10-13',
          version: '0.1.0',
          retracted: true,
        ),
        ...notes(['v0.1.0+7']),
      ];
      expect(
        releasesBetween(
          all,
          offeredTag: 'v0.1.0+10',
          installedTag: 'v0.1.0+7',
          installedVersion: '0.1.0',
        ),
        isEmpty,
      );
      expect(
        releasesBetween(
          all,
          offeredTag: 'v0.1.0+9',
          installedTag: 'v0.1.0+7',
          installedVersion: '0.1.0',
        ).map((n) => n.id),
        ['v0.1.0+9'],
      );
    });
  });

  group('markInstalled', () {
    List<RaftReleaseNote> notes(List<(String, String)> rows) => [
      for (final (tag, version) in rows)
        RaftReleaseNote(id: tag, date: '2026-10-13', version: version),
    ];
    List<String> flags(List<RaftReleaseNote> list) => [
      for (final n in list)
        n.current
            ? 'current'
            : n.isNew
            ? 'new'
            : '-',
    ];

    test('the installed tag is Current and newer releases are New', () {
      final all = notes([
        ('v0.2.0+1', '0.2.0'),
        ('v0.1.0+9', '0.1.0'),
        ('v0.1.0+8', '0.1.0'),
        ('v0.1.0+7', '0.1.0'),
      ]);
      expect(
        flags(
          markInstalled(
            all,
            installedTag: 'v0.1.0+8',
            installedVersion: '0.1.0',
          ),
        ),
        ['new', 'new', 'current', '-'],
      );
    });

    test('a retracted newer release is not New', () {
      final all = [
        const RaftReleaseNote(
          id: 'v1+2',
          date: 'd',
          version: '1',
          retracted: true,
        ),
        ...notes([('v1+1', '1')]),
      ];
      expect(
        flags(markInstalled(all, installedTag: 'v1+1', installedVersion: '1')),
        ['-', 'current'],
      );
    });

    test('without the tag, the only release of the app version is the '
        'installed one', () {
      final all = notes([
        ('v0.2.0+1', '0.2.0'),
        ('v0.1.0+9', '0.1.0'),
        ('v0.1.0-rc+1', '0.1.0-rc'),
      ]);
      expect(
        flags(markInstalled(all, installedTag: '', installedVersion: '0.1.0')),
        ['new', 'current', '-'],
      );
    });

    test('when the installed release cannot be found the list is unchanged '
        '(the newest stays Current)', () {
      final all = parseClientReleaseNotes(
        _page([_item('v0.1.0+9'), _item('v0.1.0+8')]),
      );
      for (final (tag, version) in [
        (null, '0.1.0'),
        ('', '0.1.0'),
        ('v9+1', '9.0.0'),
        ('', ''),
      ]) {
        expect(
          markInstalled(all, installedTag: tag, installedVersion: version),
          same(all),
        );
      }
      expect(all.map((n) => n.current), [true, false]);
    });
  });
}
