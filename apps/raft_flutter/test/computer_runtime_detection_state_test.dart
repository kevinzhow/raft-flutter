// Runtime detection state on a Computer row (Web machineEvents applyCapabilities,
// task #1268) and the machines envelope's release notes / host group.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/computer_release_notes.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/computer_runtime_detection.dart';
import 'package:raft_ui/raft_ui.dart';

const _scope = WorkspaceEntityScope(
  origin: 'https://fixture.test',
  principal: 'alice',
  serverId: 's',
  generation: 1,
  role: 'owner',
  capabilities: {...WorkspaceEntityKind.values},
);

void main() {
  late WorkspaceEntityDirectory directory;
  late Map<String, List<Completer<dynamic>>> requests;
  late StreamController<RaftEvent> events;

  setUp(() {
    requests = {};
    events = StreamController.broadcast(sync: true);
    directory = WorkspaceEntityDirectory(
      scope: () => _scope,
      query: (path) {
        final pending = Completer<dynamic>();
        requests.putIfAbsent(path, () => []).add(pending);
        return pending.future;
      },
      events: events.stream,
    );
  });
  tearDown(() async {
    directory.dispose();
    await events.close();
  });

  Future<void> load(Object machines, {Map<String, dynamic>? envelope}) async {
    final pending = directory.refresh(WorkspaceEntityKind.computers);
    requests['/servers/s/machines']!.last.complete({
      'machines': machines,
      ...?envelope,
    });
    await pending;
  }

  Map<String, dynamic> row() => directory.computer('c')!;
  void capabilities(Map<String, dynamic> payload) => events.add(
    RaftEvent('machine:capabilities', {'machineId': 'c', ...payload}),
  );

  group('machine:capabilities carries the detection state', () {
    setUp(() async {
      await load([
        {
          'id': 'c',
          'name': 'Mac',
          'status': 'online',
          'runtimes': ['claude'],
          'runtimeDetection': {
            'status': 'incomplete',
            'reason': 'deadline',
            'unfinishedRuntimes': ['codex'],
          },
        },
      ]);
    });

    test('an explicit state wins and keeps the list it did not send', () {
      capabilities({
        'runtimeDetection': {'status': 'pending'},
      });
      expect(row()['runtimeDetection'], {'status': 'pending'});
      expect(row()['runtimes'], ['claude'], reason: 'no inventory: untouched');
    });

    test('an explicit null ends the state', () {
      capabilities({'runtimeDetection': null});
      expect(row()['runtimeDetection'], isNull);
    });

    test('an inventory without a state is authoritative and ends the earlier state', () {
      capabilities({
        'runtimes': ['claude', 'codex'],
      });
      expect(row()['runtimes'], ['claude', 'codex']);
      expect(row()['runtimeDetection'], isNull);
    });

    test('an inventory with a new state replaces both', () {
      capabilities({
        'runtimes': ['claude', 'codex'],
        'runtimeDetection': {'status': 'complete'},
      });
      expect(row()['runtimes'], ['claude', 'codex']);
      expect(row()['runtimeDetection'], {'status': 'complete'});
    });

    test('a duplicate frame costs no notification', () {
      var notified = 0;
      directory.addListener(() => notified++);
      final same = {
        'runtimeDetection': {
          'status': 'incomplete',
          'reason': 'deadline',
          'unfinishedRuntimes': ['codex'],
        },
      };
      capabilities(same);
      expect(notified, 0);
    });
  });

  test('the typed reading of the row: pending, incomplete, complete', () {
    String label(String id) => id.toUpperCase();
    final incomplete = computerRuntimeDetection({
      'runtimeDetection': {
        'status': 'incomplete',
        'reason': 'cancelled',
        'unfinishedRuntimes': ['codex', 7, 'claude'],
      },
    }, label)!;
    expect(incomplete.status, RaftRuntimeDetectionStatus.incomplete);
    expect(incomplete.reason, RaftRuntimeDetectionReason.cancelled);
    expect(incomplete.unfinishedLabels, ['CODEX', 'CLAUDE']);
    final pending = computerRuntimeDetection({
      'runtimeDetection': {'status': 'pending'},
    }, label)!;
    expect(pending.status, RaftRuntimeDetectionStatus.pending);
    // Web: a missing reason reads as a failed detection process.
    expect(pending.reason, RaftRuntimeDetectionReason.childFailed);
    for (final none in [
      <String, dynamic>{},
      {'runtimeDetection': null},
      {
        'runtimeDetection': {'status': 'complete'},
      },
      {'runtimeDetection': 'incomplete'},
    ]) {
      expect(computerRuntimeDetection(none, label), isNull, reason: '$none');
    }
  });

  group('latestComputerReleaseNotes', () {
    test(
      'the machines envelope carries them next to the latest version',
      () async {
        await load(
          [
            {'id': 'c', 'name': 'Mac', 'status': 'online'},
          ],
          envelope: {
            'latestComputerVersion': '1.4.0',
            'latestComputerReleaseNotes': {
              'version': ' 1.4.0 ',
              'en': ' - faster\n',
              'zh-CN': '- 更快',
              'fr': '- plus vite',
            },
          },
        );
        final notes = directory.latestComputerReleaseNotes!;
        expect(notes.version, '1.4.0');
        expect(notes.text(chinese: false), '- faster');
        expect(notes.text(chinese: true), '- 更快');
      },
    );

    test('a language without notes falls back to the other one', () {
      const only = ComputerReleaseNotes(version: '1', en: '- a');
      expect(only.text(chinese: true), '- a');
      const zhOnly = ComputerReleaseNotes(version: '1', zhCn: '- 甲');
      expect(zhOnly.text(chinese: false), '- 甲');
    });

    test('malformed or oversized notes are dropped, not rendered', () {
      expect(normalizeComputerReleaseNotes('1.0.40', null), isNull);
      expect(normalizeComputerReleaseNotes('1.0.40', ['- a']), isNull);
      expect(normalizeComputerReleaseNotes(7, {'en': '- a'}), isNull);
      expect(
        normalizeComputerReleaseNotes('1.0.40', {'en': '', 'zh-CN': '  '}),
        isNull,
      );
      expect(
        normalizeComputerReleaseNotes('1.0.40', {
          'en': {'text': '- a'},
        }),
        isNull,
      );
      expect(
        normalizeComputerReleaseNotes('1.0.40', {
          'en': 'x' * (computerReleaseNotesMaxChars + 1),
        }),
        isNull,
      );
      expect(normalizeComputerReleaseNotes('v' * 65, {'en': '- a'}), isNull);
    });

    test('a bare machine list has none', () async {
      await load([
        {'id': 'c', 'name': 'Mac'},
      ]);
      expect(directory.latestComputerReleaseNotes, isNull);
    });
  });

  test(
    'the same-machine group rides on the row and survives a capabilities frame',
    () async {
      await load([
        {'id': 'c', 'name': 'Mac', 'sameMachineGroup': 'machine-1'},
        {'id': 'd', 'name': 'Linux'},
      ]);
      expect(computerSameMachineGroup(row()), 'machine-1');
      expect(computerSameMachineGroup(directory.computer('d')!), isNull);
      capabilities({
        'runtimes': ['claude'],
      });
      expect(computerSameMachineGroup(row()), 'machine-1');
    },
  );
}
