import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/migration_error.dart';
import 'package:raft_flutter/features/agent_migration_presentation.dart';
import 'package:raft_ui/raft_ui.dart' show raftChinese;

// Web components/agentMigration/{state,presentation,errors}.ts, as pure
// functions over the status projection. Expected English is the Web v1.21.12
// catalog entry.

final _machines = <Map<String, dynamic>>[
  {'id': 'c1', 'name': 'Studio Mac', 'status': 'online'},
  {'id': 'c2', 'name': 'Build Box', 'status': 'offline'},
];
final _now = DateTime.utc(2026, 10, 16, 12, 0);

MigrationNoticePresentation _notice(Map<String, dynamic> migration) =>
    migrationNoticePresentation(
      {'sourceMachineId': 'c1', 'targetMachineId': 'c2', ...migration},
      _machines,
      now: _now,
      formatTimestamp: (value) => 'ts $value',
    );

RaftApiException _api({String? code, Object? details, String? message}) =>
    RaftApiException.response(
      message ?? 'Request failed',
      status: 409,
      body: {'error': message ?? 'Request failed', 'code': ?code, 'details': ?details},
    );

void main() {
  group('migrationProgressStep (state.ts)', () {
    test('the state sets the floor and timestamps advance it', () {
      expect(migrationProgressStep({'state': 'provisioning'}), 0);
      expect(migrationProgressStep({'state': 'prep'}), 1);
      expect(migrationProgressStep({'state': 'in_transit'}), 2);
      expect(migrationProgressStep({'state': 'starting'}), 3);
      expect(
        migrationProgressStep({
          'state': 'provisioning',
          'sourceQuiescedAt': '2026-10-16T11:00:00Z',
        }),
        1,
      );
      expect(
        migrationProgressStep({
          'state': 'provisioning',
          'transportControlRegisteredAt': '2026-10-16T11:00:00Z',
        }),
        2,
      );
      expect(
        migrationProgressStep({
          'state': 'in_transit',
          'readyAt': '2026-10-16T11:00:00Z',
          'flippedAt': '2026-10-16T11:01:00Z',
        }),
        3,
      );
      // A floor is never lowered by an older timestamp.
      expect(
        migrationProgressStep({
          'state': 'arriving',
          'sourceQuiescedAt': '2026-10-16T11:00:00Z',
        }),
        3,
      );
      expect(migrationProgressStep({'state': 'completed'}), 5);
      expect(migrationProgressStep({'state': 'mystery'}), 0);
    });

    test('canCancelMigration needs a cancellable state and a revision', () {
      expect(canCancelMigration({'state': 'ready', 'revision': 2}), isTrue);
      expect(canCancelMigration({'state': 'ready', 'revision': 0}), isFalse);
      expect(canCancelMigration({'state': 'ready'}), isFalse);
      expect(
        canCancelMigration({'state': 'cancel_requested_pre_flip', 'revision': 3}),
        isFalse,
      );
      expect(canCancelMigration({'state': 'failed', 'revision': 3}), isFalse);
    });
  });

  group('migrationNoticePresentation: active states', () {
    test('provisioning narrates the source stage', () {
      expect(
        _notice({'state': 'provisioning'}).message.english,
        'Stopping the agent on Studio Mac so its workspace can be packed.',
      );
      expect(
        _notice({
          'state': 'provisioning',
          'sourceQuiescedAt': '2026-10-16T11:59:30Z',
        }).message.english,
        'Packing the workspace on Studio Mac. Large workspaces can take up to 30 minutes.',
      );
      expect(
        _notice({
          'state': 'provisioning',
          'sourceQuiescedAt': '2026-10-16T11:57:00Z',
        }).message.english,
        'Packing the workspace on Studio Mac (3 minutes so far). Large workspaces can take up to 30 minutes.',
      );
      expect(
        _notice({
          'state': 'provisioning',
          'sourceQuiescedAt': '2026-10-16T11:59:00Z',
        }).message.english,
        'Packing the workspace on Studio Mac (1 minute so far). Large workspaces can take up to 30 minutes.',
      );
      expect(
        _notice({
          'state': 'provisioning',
          'sourceQuiescedAt': '2026-10-16T11:57:00Z',
          'sourceBuildProgress': {'files': 12345, 'bytes': 5 * 1024 * 1024},
        }).message.english,
        'Packing the workspace on Studio Mac: 12,345 files, 5.0 MB so far.',
      );
      expect(
        _notice({
          'state': 'provisioning',
          'sourceQuiescedAt': '2026-10-16T11:57:00Z',
          'transportControlRegisteredAt': '2026-10-16T11:58:00Z',
        }).message.english,
        'Uploading the workspace from Studio Mac to send to Build Box.',
      );
    });

    test('later states name the target', () {
      expect(
        _notice({'state': 'ready'}).message.english,
        'The workspace is packed. Sending it to Build Box.',
      );
      expect(
        _notice({'state': 'in_transit'}).message.english,
        'Transferring workspace to Build Box.',
      );
      expect(
        _notice({'state': 'arriving'}).message.english,
        'Setting up the workspace on Build Box.',
      );
      expect(
        _notice({'state': 'starting'}).message.english,
        'Starting the agent on Build Box.',
      );
      expect(_notice({'state': 'starting'}).title.english, 'Migration status');
      expect(_notice({'state': 'starting'}).intent, MigrationIntent.info);
      expect(
        _notice({'state': 'completed'}).message.english,
        'The agent migrated to Build Box and is now running there.',
      );
      expect(_notice({'state': 'completed'}).intent, MigrationIntent.success);
    });

    test('an unknown computer reads as its id prefix or Unknown computer', () {
      final unknown = migrationNoticePresentation(
        {'state': 'in_transit', 'targetMachineId': '0123456789abcdef'},
        const [],
        now: _now,
        formatTimestamp: (v) => v,
      );
      expect(unknown.message.english, 'Transferring workspace to 01234567.');
      final none = migrationNoticePresentation(
        {'state': 'in_transit'},
        const [],
        now: _now,
        formatTimestamp: (v) => v,
      );
      expect(none.message.english, 'Transferring workspace to Unknown computer.');
      expect(
        _notice({'state': 'weird_v2'}).message.english,
        'Migration state weird_v2 for Build Box.',
      );
    });
  });

  group('migrationNoticePresentation: cancel states', () {
    test('requested cancellation is not attention', () {
      final pre = _notice({'state': 'cancel_requested_pre_flip'});
      expect(pre.intent, MigrationIntent.info);
      expect(pre.title.english, 'Canceling migration');
      expect(
        pre.message.english,
        "The agent hasn't switched computers yet, so it stays on the original computer. Raft is cleaning up.",
      );
      final post = _notice({'state': 'cancel_requested_post_flip'});
      expect(post.intent, MigrationIntent.info);
      expect(post.title.english, 'Stopping the agent on the new computer');
      expect(
        post.message.english,
        'The agent had already switched to the new computer. Raft is stopping it there and cleaning up both computers.',
      );
    });

    test('attention titles and carries the cancel error code', () {
      final pre = _notice({
        'state': 'cancel_requested_pre_flip',
        'cancelNeedsAttention': true,
        'cancelErrorCode': 'CLEANUP_TIMEOUT',
      });
      expect(pre.intent, MigrationIntent.warning);
      expect(pre.title.english, "Cancellation couldn't finish");
      expect(pre.message.english, contains('cleaning up the original computer'));
      expect(pre.technicalCode, 'CLEANUP_TIMEOUT');
      final post = _notice({
        'state': 'cancel_requested_post_flip',
        'cancelNeedsAttention': true,
      });
      expect(
        post.message.english,
        contains('after the agent switched computers'),
      );
      expect(post.technicalCode, isNull);
    });

    test('canceled before and after the flip', () {
      final pre = _notice({'state': 'canceled_pre_flip'});
      expect(pre.title.english, 'Migration canceled');
      expect(
        pre.message.english,
        'The migration was canceled before the agent switched computers. The agent is still on the original computer.',
      );
      expect(
        _notice({'state': 'canceled_post_flip'}).message.english,
        'The migration was canceled after the agent switched computers. The agent is stopped on the new computer, and cleanup is done.',
      );
    });
  });

  group('migrationNoticePresentation: failures by flip', () {
    test('starting with auto_start_failed says the agent did not start', () {
      final n = _notice({
        'state': 'starting',
        'failureReason': 'auto_start_failed',
      });
      expect(n.intent, MigrationIntent.warning);
      expect(n.title.english, 'Agent did not start');
      expect(
        n.message.english,
        'The workspace moved to Build Box, but the agent did not start automatically.',
      );
      expect(n.technicalCode, 'auto_start_failed');
      expect(
        migrationShownFailed({
          'state': 'starting',
          'failureReason': 'auto_start_failed',
        }),
        isTrue,
      );
      expect(migrationShownFailed({'state': 'starting'}), isFalse);
    });

    test('before the flip the agent is still on the source', () {
      final n = _notice({
        'state': 'failed',
        'failureReason': 'MIGRATION_LEASE_EXPIRED',
      });
      expect(n.intent, MigrationIntent.warning);
      expect(n.title.english, 'Migration failed');
      expect(
        n.placement!.english,
        'The agent is still on Studio Mac and works as usual.',
      );
      expect(n.message.english, 'The transfer did not finish. Try again.');
      expect(n.technicalCode, 'MIGRATION_LEASE_EXPIRED');
    });

    test('after the flip the agent is on the target and did not start', () {
      final n = _notice({
        'state': 'failed',
        'flippedAt': '2026-10-16T11:30:00Z',
        'failureReason': 'MIGRATION_LEASE_EXPIRED',
      });
      expect(n.placement, isNull);
      expect(
        n.message.english,
        'The agent moved to Build Box but could not start there. Make sure Raft Computer is running on Build Box, then start the agent.',
      );
      expect(n.technicalCode, 'MIGRATION_LEASE_EXPIRED');
    });

    test('aborted names the computers and the deadline when REST sent it', () {
      final n = _notice({
        'state': 'aborted',
        'abortReason': 'prep-deadline',
        'prepDeadlineAt': '2026-10-16T11:00:00Z',
      });
      expect(n.title.english, 'Migration aborted');
      expect(
        n.message.english,
        'Preparing the workspace on Studio Mac stopped making progress before the deadline (ts 2026-10-16T11:00:00Z). Studio Mac may have gone offline, or packing stalled. Make sure Studio Mac is online, then try again.',
      );
      expect(n.technicalCode, 'prep-deadline');
      expect(
        _notice({'state': 'aborted', 'abortReason': 'prep-deadline'})
            .message
            .english,
        isNot(contains('(ts')),
      );
      expect(
        _notice({'state': 'aborted', 'abortReason': 'arrival-deadline'})
            .message
            .english,
        startsWith('The target computer Build Box did not finish'),
      );
      expect(
        _notice({'state': 'aborted', 'abortReason': 'mystery'}).message.english,
        'The migration stopped before it completed. Review the technical reason, then try again.',
      );
    });

    test('a daemon cause without copy falls back to the failure reason', () {
      final n = _notice({
        'state': 'failed',
        'transportErrorCode': 'MIGRATION_TARGET_IMPORT_ARRIVED_FAILED:503',
        'failureReason': 'MIGRATION_TRANSPORT_LOST',
        'transportLostAt': '2026-10-16T11:10:00Z',
      });
      // Studio Mac is online and Build Box offline.
      expect(
        n.message.english,
        'The connection between the two computers dropped at ts 2026-10-16T11:10:00Z, during the transfer. Bring Build Box online, then try again.',
      );
    });

    test('a workspace conflict points at the conventional directory', () {
      final n = _notice({
        'state': 'failed',
        'agentId': 'a1',
        'failureReason': 'MIGRATION_WORKSPACE_ALREADY_EXISTS',
      });
      expect(
        n.message.english,
        startsWith('A workspace already exists at ~/.slock/agents/a1 on the target'),
      );
    });
  });

  group('migrationErrorPresentation: size codes read the wire numbers', () {
    String text(String code, String raw) => migrationErrorPresentation(
      code: code,
      rawMessage: raw,
      context: MigrationErrorContext.failed,
    ).message.english;

    test('bundle too large', () {
      expect(
        text(
          'MIGRATION_OBJECT_STORE_BUNDLE_TOO_LARGE',
          'x:maxBytes=2147483648:topEntries=data%2F,3221225472;logs%2F,1073741824',
        ),
        'The workspace is too large to move: compressed, it is over the 2 GiB limit. Largest items: data/ (3 GiB), logs/ (1 GiB). Ask the agent to delete large files it no longer needs, or to list them in .raftmigrateignore, then try again.',
      );
      expect(
        text('MIGRATION_OBJECT_STORE_BUNDLE_TOO_LARGE', 'x:maxBytes=1610612736'),
        'The workspace is too large to move: compressed, it is over the 1.5 GiB limit. Ask the agent to delete large files it no longer needs, or to list them in .raftmigrateignore, then try again.',
      );
      expect(
        text('MIGRATION_OBJECT_STORE_BUNDLE_TOO_LARGE', 'nothing'),
        'The workspace is too large to move. Ask the agent to delete large files it no longer needs, or to list them in .raftmigrateignore, then try again.',
      );
    });

    test('manifest too large', () {
      expect(
        text(
          'MIGRATION_OBJECT_STORE_MANIFEST_TOO_LARGE',
          'x:entryCount=1234567:topPaths=node_modules%2F,1000000;src%2F,2345',
        ),
        'The workspace has too many files and folders to move (1,234,567). Most are in node_modules/ (1,000,000), src/ (2,345). Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.',
      );
      expect(
        text('MIGRATION_OBJECT_STORE_MANIFEST_TOO_LARGE', 'nothing'),
        'The workspace has too many files and folders to move. Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.',
      );
    });

    test('entry count limit needs a consistent triple', () {
      expect(
        text(
          'MIGRATION_OBJECT_STORE_ENTRY_COUNT_LIMIT_EXCEEDED',
          'x:entryCount=2000000:maxEntries=1000000:topPathCounts=cache%2F,1500000',
        ),
        'The workspace has 2,000,000 files and folders; migration supports up to 1,000,000. Most are in cache/ (1,500,000). Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.',
      );
      expect(
        text(
          'MIGRATION_OBJECT_STORE_ENTRY_COUNT_LIMIT_EXCEEDED',
          'x:entryCount=10:maxEntries=1000000:topPathCounts=cache%2F,5',
        ),
        'The workspace has too many files and folders to move. Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.',
      );
    });

    test('unsafe accounting paths are dropped', () {
      expect(
        text(
          'MIGRATION_OBJECT_STORE_MANIFEST_TOO_LARGE',
          'x:entryCount=9:topPaths=.env%2F,5;secrets%2F,4;ok%2F,2;a%2Fb%2F,3',
        ),
        'The workspace has too many files and folders to move (9). Most are in ok/ (2). Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.',
      );
    });

    test('insufficient disk', () {
      expect(
        text(
          'MIGRATION_OBJECT_STORE_INSUFFICIENT_DISK',
          'x:requiredBytes=5368709120:availableBytes=1073741824',
        ),
        'The target computer needs 5 GiB free to stage and install this migration, but only 1 GiB is available. Free disk space and try again.',
      );
      expect(
        text('MIGRATION_OBJECT_STORE_INSUFFICIENT_DISK', 'x'),
        'The target computer does not have enough free disk space to stage and install this migration. Free disk space and try again.',
      );
    });
  });

  group('start errors: capability details', () {
    const computers = MigrationComputers(
      sourceName: 'Studio Mac',
      targetName: 'Build Box',
      sourceId: 'c1',
      targetId: 'c2',
    );

    test('names the computer that lacks a runtime and offers its settings', () {
      final p = migrationStartErrorPresentation(
        _api(
          code: 'COMPUTER_CAPABILITY_INSUFFICIENT',
          details: {
            'failures': [
              {'side': 'target', 'reason': 'runtime_missing', 'runtime': 'codex'},
            ],
          },
        ),
        computers,
      );
      expect(
        p.message.english,
        'Fix these computer requirements before starting the migration:',
      );
      expect(p.issues.map((i) => i.english), [
        'Build Box does not support Codex CLI. Install or enable that runtime on this computer, or choose another computer.',
      ]);
      expect(p.recoveryOpenComputers, isTrue);
      expect(p.recoveryComputerId, 'c2');
      expect(p.technicalCode, 'COMPUTER_CAPABILITY_INSUFFICIENT');
    });

    test('both sides open the computer list instead of one computer', () {
      final p = migrationStartErrorPresentation(
        _api(
          code: 'COMPUTER_CAPABILITY_INSUFFICIENT',
          details: {
            'failures': [
              {'side': 'source', 'reason': 'runtime_unconfirmed', 'runtime': 'claude'},
              {'side': 'target', 'reason': 'runtime_missing', 'runtime': 'claude'},
            ],
          },
        ),
        computers,
      );
      expect(p.issues, hasLength(2));
      expect(
        p.issues.first.english,
        startsWith(
          'Studio Mac has not reported whether Claude Code is available.',
        ),
      );
      expect(p.recoveryComputerId, isNull);
      expect(p.recoveryOpenComputers, isTrue);
    });

    test('malformed details fall back to the generic capability copy', () {
      for (final details in <Object?>[
        null,
        'x',
        {'failures': []},
        {
          'failures': [
            {'side': 'target', 'reason': 'runtime_missing', 'runtime': 'bad id'},
          ],
        },
        {
          'failures': [
            {'side': 'target', 'reason': 'runtime_missing', 'runtime': 'a'},
            {'side': 'target', 'reason': 'runtime_missing', 'runtime': 'b'},
          ],
        },
      ]) {
        final p = migrationStartErrorPresentation(
          _api(code: 'COMPUTER_CAPABILITY_INSUFFICIENT', details: details),
          computers,
        );
        expect(p.issues, isEmpty, reason: '$details');
        expect(
          p.message.english,
          startsWith('Both computers must run a compatible Raft Computer'),
        );
        expect(p.recoveryOpenComputers, isTrue);
      }
    });

    test('a resumable capability gap names the side that needs an update', () {
      MigrationPresentation of(String? side) => migrationStartErrorPresentation(
        _api(
          code: 'MIGRATION_RESUMABLE_CAPABILITY_REQUIRED',
          details: side == null
              ? null
              : {'side': side, 'reason': 'capability_missing'},
        ),
        computers,
      );
      expect(
        of('source').message.english,
        'Studio Mac needs a Raft Computer update before it can move agents. Update Raft Computer on Studio Mac to the latest version, restart it, wait for it to reconnect, then try again.',
      );
      expect(of('source').recoveryComputerId, 'c1');
      expect(of('target').recoveryComputerId, 'c2');
      expect(
        of('both').message.english,
        'Studio Mac and Build Box need a Raft Computer update before they can move agents. Update Raft Computer on both to the latest version, restart them, wait for them to reconnect, then try again.',
      );
      expect(of('both').recoveryComputerId, isNull);
      expect(
        of(null).message.english,
        startsWith('One of these computers needs a Raft Computer update'),
      );
      expect(of(null).recoveryOpenComputers, isTrue);
    });

    test('other codes use catalog copy without recovery', () {
      final p = migrationStartErrorPresentation(
        _api(code: 'TARGET_COMPUTER_OFFLINE', message: 'server sentence'),
        computers,
      );
      expect(
        p.message.english,
        'The target computer is offline. Start Raft Computer on it and try again.',
      );
      expect(p.recoveryOpenComputers, isFalse);
      expect(p.technicalCode, 'TARGET_COMPUTER_OFFLINE');
    });
  });

  test('panel header follows the state', () {
    expect(migrationPanelHeader({'state': 'in_transit'}), 'Migrating to {target}');
    expect(migrationPanelHeader({'state': 'completed'}), 'Migrated to {target}');
    expect(
      migrationPanelHeader({'state': 'canceled_post_flip'}),
      'Migration to {target} canceled',
    );
    expect(
      migrationPanelHeader({'state': 'failed'}),
      'Migration to {target} needs attention',
    );
    expect(
      migrationPanelHeader({
        'state': 'cancel_requested_pre_flip',
        'cancelNeedsAttention': true,
      }),
      'Migration to {target} needs attention',
    );
    expect(
      migrationPanelHeader({'state': 'cancel_requested_pre_flip'}),
      'Canceling migration to {target}',
    );
  });

  test('every text a presentation can produce has Web zh-cn copy', () {
    final sources = <String>{};
    void collect(MigrationText? t) {
      if (t == null) return;
      sources.add(t.source);
      for (final v in t.values.values) {
        if (v is MigrationText) collect(v);
        if (v is List) v.whereType<MigrationText>().forEach(collect);
      }
    }

    void presentation(MigrationPresentation p) {
      collect(p.placement);
      collect(p.message);
      p.issues.forEach(collect);
      if (p is MigrationNoticePresentation) collect(p.title);
    }

    const states = [
      'provisioning', 'prep', 'ready', 'in_transit', 'arriving', 'starting',
      'cancel_requested_pre_flip', 'cancel_requested_post_flip',
      'canceled_pre_flip', 'canceled_post_flip', 'completed', 'aborted',
      'failed', 'mystery',
    ];
    final variants = <Map<String, dynamic>>[
      {},
      {'cancelNeedsAttention': true},
      {'flippedAt': '2026-10-16T11:30:00Z'},
      {'failureReason': 'auto_start_failed'},
      {'sourceQuiescedAt': '2026-10-16T11:57:00Z'},
      {'sourceQuiescedAt': '2026-10-16T11:59:00Z'},
      {
        'sourceQuiescedAt': '2026-10-16T11:57:00Z',
        'sourceBuildProgress': {'files': 3, 'bytes': 9},
      },
      {'sourceQuiescedAt': '2026-10-16T11:57:00Z', 'transportControlRegisteredAt': 'x'},
      {'abortReason': 'prep-deadline', 'prepDeadlineAt': '2026-10-16T11:00:00Z'},
      {'abortReason': 'prep-deadline'},
      {'abortReason': 'transfer-deadline'},
      {'abortReason': 'arrival-deadline'},
      for (final code in [
        'MIGRATION_TRANSPORT_LOST',
        'MIGRATION_WORKSPACE_ALREADY_EXISTS',
        'MIGRATION_WORKSPACE_COMPLETE_OLD_COPY',
      ])
        {
          'agentId': 'a1',
          'failureReason': code,
          'transportLostAt': '2026-10-16T11:00:00Z',
        },
    ];
    for (final state in states) {
      for (final v in variants) {
        presentation(_notice({'state': state, ...v}));
      }
    }
    for (final machines in [
      <Map<String, dynamic>>[],
      [
        {'id': 'c1', 'name': 'A', 'status': 'offline'},
        {'id': 'c2', 'name': 'B', 'status': 'offline'},
      ],
      [
        {'id': 'c1', 'name': 'A', 'status': 'online'},
        {'id': 'c2', 'name': 'B', 'status': 'online'},
      ],
    ]) {
      presentation(
        migrationNoticePresentation(
          {
            'state': 'failed',
            'sourceMachineId': 'c1',
            'targetMachineId': 'c2',
            'failureReason': 'MIGRATION_TRANSPORT_LOST',
            'transportLostAt': '2026-10-16T11:00:00Z',
          },
          machines,
          now: _now,
          formatTimestamp: (v) => v,
        ),
      );
    }
    const raw = 'x:maxBytes=1:topEntries=a,1:entryCount=3:topPaths=a,1:maxEntries=1:'
        'topPathCounts=a,1:requiredBytes=1:availableBytes=1';
    for (final code in [
      'MIGRATION_OBJECT_STORE_BUNDLE_TOO_LARGE',
      'MIGRATION_OBJECT_STORE_MANIFEST_TOO_LARGE',
      'MIGRATION_OBJECT_STORE_ENTRY_COUNT_LIMIT_EXCEEDED',
      'MIGRATION_OBJECT_STORE_INSUFFICIENT_DISK',
    ]) {
      for (final message in [raw, 'x:entryCount=3', 'x:maxBytes=1', 'none']) {
        presentation(
          migrationErrorPresentation(
            code: code,
            rawMessage: message,
            context: MigrationErrorContext.failed,
          ),
        );
      }
    }
    const computers = MigrationComputers(sourceName: 'A', targetName: 'B');
    for (final side in ['source', 'target', 'both', null]) {
      presentation(
        migrationStartErrorPresentation(
          _api(
            code: 'MIGRATION_RESUMABLE_CAPABILITY_REQUIRED',
            details: side == null ? null : {'side': side, 'reason': 'capability_missing'},
          ),
          computers,
        ),
      );
    }
    for (final reason in ['runtime_unconfirmed', 'runtime_missing']) {
      presentation(
        migrationStartErrorPresentation(
          _api(
            code: 'COMPUTER_CAPABILITY_INSUFFICIENT',
            details: {
              'failures': [
                {'side': 'source', 'reason': reason, 'runtime': 'codex'},
              ],
            },
          ),
          computers,
        ),
      );
    }
    for (final step in migrationProgressSteps) {
      sources.add(step);
    }
    for (final state in states) {
      sources.add(migrationPanelHeader({'state': state}));
      sources.add(
        migrationPanelHeader({'state': state, 'cancelNeedsAttention': true}),
      );
    }
    final missing = [
      for (final source in sources)
        // `{event} {retry}` is Web's own join of two catalog sentences.
        if (source != '{event} {retry}' && !raftChinese.containsKey(source))
          source,
    ];
    expect(missing, isEmpty);
  });
}
