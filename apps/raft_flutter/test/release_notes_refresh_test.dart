import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_flutter/platform/client_release_notes.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'support/memory_storage.dart';
import 'workspace_source_location_contract_test.dart' show pageFixture;

/// Settings > Release Notes: the cached copy shows at once, opening the page
/// (and returning to the app) refreshes it quietly, a pull refreshes it on a
/// phone, and a failed refresh keeps what is shown.

const _sizes = [Size(412, 915), Size(1280, 800)];

String _page(List<(String, String)> notes) => jsonEncode({
  'items': [
    for (final (tag, text) in notes)
      {
        'releaseId': tag,
        'tag': tag,
        'version': '0.1.0',
        'date': '2026-10-14',
        'state': 'published',
        'entries': [
          {'type': 'feature', 'text': text, 'emphasis': false},
        ],
      },
  ],
  'nextCursor': null,
});

final _old = _page([('v0.1.0+5', 'Old note')]);
final _new = _page([('v0.1.0+6', 'New note'), ('v0.1.0+5', 'Old note')]);
final _newer = _page([
  ('v0.1.0+7', 'Newer note'),
  ('v0.1.0+6', 'New note'),
  ('v0.1.0+5', 'Old note'),
]);

class _Net {
  Future<String?> Function() respond = () async => _new;
  final requests = <Uri>[];
  Future<String?> fetch(Uri url) {
    requests.add(url);
    return respond();
  }
}

final _clock = DateTime(2026, 10, 14, 9);

/// A cache written by [build] of the app a minute ago holding [body].
MemoryStorage _cached(String body, {int? build = 21}) =>
    MemoryStorage()
      ..values[ClientReleaseNotes.storageKey] = jsonEncode({
        'fetchedAt': _clock
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        'body': body,
        'appBuild': ?build,
      });

ClientReleaseNotes _source(
  _Net net,
  MemoryStorage storage, {
  int? build = 21,
}) => ClientReleaseNotes(
  storage: storage,
  appBuild: build,
  clock: () => _clock,
  fetch: net.fetch,
);

Future<WorkspaceController> _mount(
  WidgetTester t,
  ClientReleaseNotes source, {
  Size size = const Size(412, 915),
  String? installedTag,
  String? installedVersion,
  Locale? locale,
}) async {
  final (w, _) = await pageFixture(t, section: 'chat');
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: raftTheme().copyWith(platform: TargetPlatform.android),
      home: Scaffold(
        body: SizedBox.expand(
          child: ReleaseNotesView(
            controller: w,
            source: source,
            installedTag: installedTag,
            installedVersion: installedVersion,
          ),
        ),
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return w;
}

final _quietRetry = find.byKey(const ValueKey('release-notes-refresh-retry'));
const _unavailable = 'Release notes are unavailable right now.';

Future<void> _pull(WidgetTester t) async {
  await t.drag(find.byType(RefreshIndicator), const Offset(0, 360));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  await t.pumpAndSettle();
}

void main() {
  leakDebt(const ['ValueNotifier<bool>']);
  for (final size in _sizes) {
    final on = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('$on: opens on the cached copy, refreshes in the '
        'background and shows the new data', (t) async {
      final net = _Net();
      final gate = Completer<String?>();
      net.respond = () => gate.future;
      await _mount(t, _source(net, _cached(_old)), size: size);
      // The copy is on screen while the refresh is still in flight, with no
      // loading line, banner or message about it.
      expect(find.text('Old note'), findsOneWidget);
      expect(find.text('Loading release notes…'), findsNothing);
      expect(find.text(_unavailable), findsNothing);
      expect(net.requests, hasLength(1));
      gate.complete(_new);
      await t.pumpAndSettle();
      expect(find.text('New note'), findsOneWidget);
      expect(find.text('Old note'), findsOneWidget);
      expect(_quietRetry, findsNothing);
      expect(net.requests, hasLength(1));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('$on: a cache written by an older app build is refreshed '
        'on open', (t) async {
      final net = _Net();
      // Fetched by build 20, installed build 21, and well within maxAge.
      await _mount(t, _source(net, _cached(_old, build: 20)), size: size);
      await t.pumpAndSettle();
      expect(net.requests, hasLength(1));
      expect(find.text('New note'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('$on: a failed refresh keeps the cached content and '
        'offers a quiet retry', (t) async {
      final net = _Net()..respond = () async => throw StateError('offline');
      await _mount(t, _source(net, _cached(_old)), size: size);
      await t.pumpAndSettle();
      expect(find.text('Old note'), findsOneWidget);
      expect(find.text(_unavailable), findsNothing);
      expect(_quietRetry, findsOneWidget);
      net.respond = () async => _new;
      await t.ensureVisible(_quietRetry);
      await t.tap(_quietRetry);
      await t.pumpAndSettle();
      expect(find.text('New note'), findsOneWidget);
      expect(_quietRetry, findsNothing);
      expect(net.requests, hasLength(2));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('$on: with no copy and no network the unavailable banner '
        'still retries', (t) async {
      final net = _Net()..respond = () async => throw StateError('offline');
      await _mount(t, _source(net, MemoryStorage()), size: size);
      await t.pumpAndSettle();
      expect(find.text(_unavailable), findsOneWidget);
      expect(_quietRetry, findsNothing);
      net.respond = () async => _old;
      await t.tap(find.byKey(const ValueKey('release-notes-retry')));
      await t.pumpAndSettle();
      expect(find.text('Old note'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('pull to refresh refetches and the list updates', (t) async {
    final net = _Net();
    await _mount(t, _source(net, _cached(_old)));
    await t.pumpAndSettle();
    expect(net.requests, hasLength(1));
    expect(find.text('Newer note'), findsNothing);
    net.respond = () async => _newer;
    await _pull(t);
    expect(net.requests, hasLength(2));
    expect(find.text('Newer note'), findsOneWidget);
    expect(find.text('New note'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a failed pull keeps the list', (t) async {
    final net = _Net();
    await _mount(t, _source(net, _cached(_old)));
    await t.pumpAndSettle();
    net.respond = () async => throw StateError('offline');
    await _pull(t);
    expect(net.requests, hasLength(2));
    expect(find.text('New note'), findsOneWidget);
    expect(_quietRetry, findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a plain rebuild makes no request; only open, a pull and '
      'returning to the app do', (t) async {
    final net = _Net();
    await _mount(t, _source(net, _cached(_old)));
    await t.pumpAndSettle();
    expect(net.requests, hasLength(1));
    // Rebuilds: a relayout, a theme change, repeated frames.
    t.view.physicalSize = const Size(600, 915);
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(1280, 800);
    await t.pumpAndSettle();
    await t.pump(const Duration(minutes: 10));
    expect(net.requests, hasLength(1));
    // Returning to the app right after a refresh is not another request.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(state);
    }
    await t.pumpAndSettle();
    expect(net.requests, hasLength(1));
    await t.pumpWidget(const SizedBox());
  });

  group('which release is Current', () {
    Finder badge(String tag, String label) => find.descendant(
      of: find.byKey(ValueKey('release-entry-$tag')),
      matching: find.text(label),
    );

    Future<void> open(
      WidgetTester t, {
      String? tag,
      String? version,
      Size size = const Size(412, 915),
      Locale? locale,
    }) async {
      final net = _Net()..respond = () async => _newer;
      await _mount(
        t,
        _source(net, _cached(_newer)),
        size: size,
        installedTag: tag,
        installedVersion: version,
        locale: locale,
      );
      await t.pumpAndSettle();
    }

    for (final size in _sizes) {
      testWidgets('${size.width.toInt()}: the installed release is Current, '
          'newer ones are New', (t) async {
        await open(t, tag: 'v0.1.0+6', version: '0.1.0', size: size);
        expect(badge('v0.1.0+6', 'Current'), findsOneWidget);
        expect(badge('v0.1.0+7', 'New version'), findsOneWidget);
        expect(badge('v0.1.0+7', 'Current'), findsNothing);
        expect(badge('v0.1.0+5', 'Current'), findsNothing);
        expect(badge('v0.1.0+5', 'New version'), findsNothing);
        expect(badge('v0.1.0+6', 'New version'), findsNothing);
        expect(find.text('Current'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets('the badges speak Chinese', (t) async {
      await open(
        t,
        tag: 'v0.1.0+6',
        version: '0.1.0',
        locale: const Locale('zh'),
      );
      expect(badge('v0.1.0+6', '当前'), findsOneWidget);
      expect(badge('v0.1.0+7', '新版本'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a build without a compiled-in tag learns it from the update '
        'manifest and remembers it', (t) async {
      final storage = MemoryStorage();
      AppUpdateService make(Future<String?> Function(Uri) fetch) =>
          AppUpdateService(
            currentVersion: '0.1.0',
            currentBuild: 37,
            platformKey: 'android-arm64',
            storage: storage,
            scheduleTimer: false,
            fetch: fetch,
          );
      final first = make(
        (_) async => jsonEncode([
          {
            'platform': 'android',
            'arch': 'arm64',
            'version': '0.1.0',
            'buildNumber': '37',
            'releaseTag': 'v0.1.0+6',
            'artifact': 'raft-flutter-0.1.0+6-android-arm64.apk',
          },
        ]),
      );
      addTearDown(first.dispose);
      expect(first.installedTag, '');
      await t.runAsync(first.start);
      // The latest release is the running build: that is its tag.
      expect(first.installedTag, 'v0.1.0+6');
      // A later run, when a newer build is already published, still knows.
      final later = make((_) async => throw StateError('offline'));
      addTearDown(later.dispose);
      await t.runAsync(later.start);
      expect(later.installedTag, 'v0.1.0+6');
      await open(t, tag: later.installedTag, version: later.currentVersion);
      expect(badge('v0.1.0+6', 'Current'), findsOneWidget);
      expect(badge('v0.1.0+7', 'New version'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('without a tag, the one release of the app version is the '
        'installed one', (t) async {
      // _newer lists three builds of 0.1.0, so no unique match: unchanged.
      await open(t, tag: '', version: '0.1.0');
      expect(badge('v0.1.0+7', 'Current'), findsOneWidget);
      expect(find.text('New version'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('an unknown installed release keeps the newest as Current', (
      t,
    ) async {
      await open(t, tag: 'v9.9.9+1', version: '9.9.9');
      expect(badge('v0.1.0+7', 'Current'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('New version'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });
}
