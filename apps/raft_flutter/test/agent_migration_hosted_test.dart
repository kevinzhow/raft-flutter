// Moving an agent to the cloud (Web v1.21.23 `targetKind: "hosted"`): the
// cloud as a target of the start dialog, the review the user confirms, the
// progress copy and the cloud agent's arrival block.

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_migration_hosted.dart';
import 'package:raft_flutter/features/agent_migration_presentation.dart';

Map<String, dynamic> _m(String state, [Map<String, dynamic> more = const {}]) =>
    {
      'agentId': 'a1',
      'migrationRef': 'mig_1',
      'state': state,
      'revision': 4,
      'sourceMachineId': 'c1',
      'targetKind': 'hosted',
      'targetMachineId': null,
      ...more,
    };

const _summary = {
  'importedFileCount': 12,
  'importedBytes': 2048,
  'skipped': [
    {
      'reason': 'git',
      'count': 7,
      'bytes': 4096,
      'largestPaths': [
        'a/.git/1',
        'a/.git/2',
        'a/.git/3',
        'a/.git/4',
        'a/.git/5',
        'a/.git/6',
      ],
    },
    {
      'reason': 'symlink',
      'count': 1,
      'bytes': 0,
      'largestPaths': ['link'],
    },
    {'reason': 'not_text', 'count': 0, 'bytes': 0, 'largestPaths': []},
  ],
};

Map<String, dynamic> _review({String? confirmed}) => _m('in_transit', {
  'readyAt': '2026-10-24T08:00:00.000Z',
  'transferDeadlineAt': '2026-10-24T20:00:00.000Z',
  'hosted': {
    'provider': 'antiproton',
    'hostedModel': null,
    'reviewReadyAt': '2026-10-24T08:05:00.000Z',
    'reviewConfirmedAt': confirmed,
    'importSummary': _summary,
  },
});

String _english(MigrationNoticePresentation p) =>
    '${p.title.english} | ${p.message.english}';

void main() {
  group('state and presentation', () {
    final machines = [
      {'id': 'c1', 'name': 'Office-Mac', 'status': 'online'},
    ];
    MigrationNoticePresentation present(Map<String, dynamic> m) =>
        migrationNoticePresentation(
          m,
          machines,
          now: DateTime.utc(2026, 10, 24, 9),
          formatTimestamp: (v) => v,
        );

    test('a move to the cloud is told by targetKind', () {
      expect(isHostedMigration(_m('prep')), isTrue);
      expect(isHostedMigration({'state': 'prep'}), isFalse);
    });

    test('progress steps follow the cloud, not the target computer', () {
      expect(migrationProgressStep(_m('prep')), 0);
      expect(migrationProgressStep(_m('ready')), 1);
      expect(migrationProgressStep(_m('in_transit')), 1);
      expect(migrationProgressStep(_review()), 2);
      expect(migrationProgressStep(_m('arriving')), 3);
      expect(
        migrationProgressStep(
          _m('starting', {'flippedAt': '2026-10-24T09:00:00Z'}),
        ),
        3,
      );
      expect(
        hostedMigrationProgressStep(_m('completed')),
        hostedMigrationProgressSteps.length,
      );
      // The computer move keeps its own ladder.
      expect(
        migrationProgressStep({'state': 'ready', 'targetKind': 'machine'}),
        2,
      );
    });

    test('the review waits only until it is confirmed', () {
      expect(isHostedReviewPending(_review()), isTrue);
      expect(hostedReviewSummary(_review()), isNotNull);
      expect(
        isHostedReviewPending(_review(confirmed: '2026-10-24T08:10:00Z')),
        isFalse,
      );
      expect(hostedReviewSummary(_m('ready')), isNull);
      expect(
        isHostedReviewPending({..._review(), 'targetKind': 'machine'}),
        isFalse,
      );
    });

    test('cancel stops at the switch', () {
      expect(canCancelMigration(_m('prep')), isTrue);
      expect(canCancelMigration(_review()), isTrue);
      expect(canCancelMigration(_m('arriving')), isFalse);
      expect(canCancelMigration(_m('starting')), isFalse);
      expect(
        canCancelMigration(
          _m('in_transit', {'flippedAt': '2026-10-24T09:00:00Z'}),
        ),
        isFalse,
      );
      // A computer move can still be canceled while arriving.
      expect(canCancelMigration({'state': 'arriving', 'revision': 3}), isTrue);
    });

    test('stage copy names the cloud', () {
      expect(
        present(_m('ready')).message.english,
        'Checking which files can move to the cloud.',
      );
      expect(
        present(_review()).message.english,
        'Review what moves to the cloud, then confirm. The agent stays stopped on Office-Mac until you decide.',
      );
      expect(
        present(_m('in_transit')).message.english,
        'Checking which files can move to the cloud.',
      );
      expect(
        present(_m('arriving')).message.english,
        'Switching the agent to the cloud.',
      );
      expect(
        present(_m('provisioning', {'transportControlRegisteredAt': 'x'}))
            .message
            .english,
        'Uploading the workspace from Office-Mac to the cloud.',
      );
      expect(
        present(_m('completed')).message.english,
        'The agent now runs in the cloud.',
      );
    });

    test('cancel copy names where the agent stays', () {
      expect(
        _english(present(_m('cancel_requested_pre_flip'))),
        "Canceling migration | The agent hasn't switched to the cloud, so it stays on Office-Mac. Raft is cleaning up.",
      );
      expect(
        present(_m('canceled_pre_flip')).message.english,
        'The move to the cloud was canceled. The agent is still on Office-Mac.',
      );
      expect(
        present(_m('cancel_requested_pre_flip', {'cancelNeedsAttention': true}))
            .message
            .english,
        "Raft couldn't finish cleaning up on Office-Mac. Keep it online. If you contact support, include the migration ID.",
      );
    });

    test(
      'a stalled switch needs attention, not a failure banner of a move',
      () {
        for (final reason in [
          'HOSTED_IMPORT_FAILED',
          'HOSTED_IMPORT_STALLED',
          'HOSTED_PROVIDER_FAILED',
          'HOSTED_AGENT_DELETED',
          'HOSTED_PROVIDER_MISMATCH',
        ]) {
          final m = _m('arriving', {'failureReason': reason});
          expect(hostedArrivalAttentionReason(m), reason);
          expect(migrationShownFailed(m), isTrue);
          final p = present(m);
          expect(p.title.english, 'The cloud agent needs attention');
          expect(p.placement!.english, 'The agent is already in the cloud.');
          expect(p.intent, MigrationIntent.warning);
          expect(p.technicalCode, reason);
        }
        expect(hostedArrivalAttentionReason(_m('arriving')), isNull);
        expect(
          hostedArrivalAttentionReason(
            _m('failed', {'failureReason': 'HOSTED_IMPORT_FAILED'}),
          ),
          isNull,
        );
      },
    );

    test('a cloud that never set the agent up put it back', () {
      final p = present(
        _m('failed', {'failureReason': 'HOSTED_AGENT_NOT_CREATED'}),
      );
      expect(
        p.message.english,
        'The cloud never set the agent up, so Raft put it back on Office-Mac unchanged. You can try again.',
      );
      expect(
        p.placement!.english,
        'The agent is still on Office-Mac and works as usual.',
      );
    });

    test(
      'a failure after the switch and a dropped upload read as the cloud',
      () {
        expect(
          present(
            _m('failed', {
              'flippedAt': '2026-10-24T09:00:00Z',
              'failureReason': 'x',
            }),
          ).message.english,
          'The agent switched to the cloud but did not finish setting up there. If you contact support, include the migration ID.',
        );
        expect(
          present(
            _m('failed', {'transportErrorCode': 'MIGRATION_TRANSPORT_LOST'}),
          ).message.english,
          'The upload to the cloud was interrupted. Make sure Office-Mac is online, then try again.',
        );
      },
    );

    test('headers say Move to the cloud', () {
      expect(migrationPanelHeader(_m('prep')), 'Moving to the cloud');
      expect(migrationPanelHeader(_m('completed')), 'Moved to the cloud');
      expect(
        migrationPanelHeader(_m('canceled_pre_flip')),
        'Move to the cloud canceled',
      );
      expect(
        migrationPanelHeader(_m('cancel_requested_pre_flip')),
        'Canceling the move to the cloud',
      );
      expect(
        migrationPanelHeader(_m('failed')),
        'Move to the cloud needs attention',
      );
      expect(migrationPanelHeader({'state': 'prep'}), 'Migrating to {target}');
    });

    test('the arrival stays a day after it ends', () {
      final now = DateTime.utc(2026, 10, 25, 12);
      final done = _m('completed', {
        'flippedAt': '2026-10-24T09:00:00Z',
        'completedAt': '2026-10-25T01:00:00Z',
      });
      expect(hostedShowsArrival(done, now), isTrue);
      expect(
        hostedShowsArrival({
          ...done,
          'completedAt': '2026-10-24T11:00:00Z',
        }, now),
        isFalse,
      );
      expect(
        hostedShowsArrival(
          _m('arriving', {'flippedAt': '2026-10-25T11:00:00Z'}),
          now,
        ),
        isTrue,
      );
      expect(hostedShowsArrival(_m('arriving'), now), isFalse);
      expect(hostedShowsArrival(const {}, now), isFalse);
      expect(
        hostedShowsArrival(
          _m('canceled_post_flip', {
            'flippedAt': '2026-10-24T09:00:00Z',
            'updatedAt': '2026-10-25T10:00:00Z',
          }),
          now,
        ),
        isTrue,
      );
    });
  });
}
