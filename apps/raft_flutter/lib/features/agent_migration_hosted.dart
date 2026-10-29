// Moving an agent to the cloud (Web v1.21.23, `targetKind: "hosted"`): what
// differs from a move between computers. There is no target computer to start
// on; the cloud checks the uploaded files, the user reviews what moves and
// confirms the switch, and a cancel is only possible before the switch. Web
// sources: components/agentMigration/{state,presentation,errors,
// HostedMigrationReview,MigrationProgressPanel}.tsx.
import '../data/migration_error.dart';
import 'agent_migration_presentation.dart';

/// `AGENT_MIGRATION_TARGET_KINDS`: a move to the cloud has no target computer.
bool isHostedMigration(Map<String, dynamic> migration) =>
    migration['targetKind'] == 'hosted';

bool _has(Object? value) => value is String && value.isNotEmpty;

Map<String, dynamic>? _hostedReview(Map<String, dynamic> migration) =>
    migration['hosted'] is Map
    ? Map<String, dynamic>.from(migration['hosted'] as Map)
    : null;

/// `isHostedReviewPending`: the review is built and waits for the user's
/// confirm (or cancel).
bool isHostedReviewPending(Map<String, dynamic> migration) {
  final review = _hostedReview(migration);
  return isHostedMigration(migration) &&
      migration['state'] == 'in_transit' &&
      _has(review?['reviewReadyAt']) &&
      !_has(review?['reviewConfirmedAt']);
}

/// `AgentMigrationHostedImportSummary` of the pending review, else null.
Map<String, dynamic>? hostedReviewSummary(Map<String, dynamic> migration) {
  if (!isHostedReviewPending(migration)) return null;
  final summary = _hostedReview(migration)?['importSummary'];
  return summary is Map ? Map<String, dynamic>.from(summary) : null;
}

/// state.ts HOSTED_MIGRATION_PROGRESS_STEPS.
const hostedMigrationProgressSteps = <String>[
  'Prepare and upload',
  'Check files',
  'Your review',
  'Switch to the cloud',
  'Running in the cloud',
];

/// `hostedMigrationProgressStep`: 0-based; the steps' length once completed.
int hostedMigrationProgressStep(Map<String, dynamic> migration) {
  final state = migration['state'];
  if (migrationPhase(state as String?) == 'completed') {
    return hostedMigrationProgressSteps.length;
  }
  if (_has(migration['flippedAt']) ||
      state == 'arriving' ||
      state == 'starting') {
    return 3;
  }
  if (_has(_hostedReview(migration)?['reviewReadyAt'])) return 2;
  if (_has(migration['readyAt']) || state == 'ready' || state == 'in_transit') {
    return 1;
  }
  return 0;
}

/// `canCancelMigration` after the switch: a cloud agent already runs in the
/// cloud and there is no computer to hand it back to.
bool hostedCancelRefused(Map<String, dynamic> migration) =>
    isHostedMigration(migration) &&
    (_has(migration['flippedAt']) ||
        migration['state'] == 'arriving' ||
        migration['state'] == 'starting');

/// presentation.ts HOSTED_ARRIVAL_ATTENTION_IDS: after the switch a move to
/// the cloud can stall without ending (a retry may still finish it).
const _attentionCopy = <String, String>{
  'HOSTED_IMPORT_FAILED': "The cloud couldn't import the workspace files. This can still finish, and the Raft team has been alerted. If you contact support, include the migration ID.",
  'HOSTED_IMPORT_STALLED': "The cloud still hasn't imported the workspace files, long after the switch. This can still finish, and the Raft team has been alerted. If you contact support, include the migration ID.",
  'HOSTED_PROVIDER_FAILED': "The cloud couldn't set up the agent. This can still finish, and the Raft team has been alerted. If you contact support, include the migration ID.",
  'HOSTED_AGENT_DELETED': "The agent was deleted in the cloud, and the cloud can't set it up again for this agent. The Raft team has been alerted. If you contact support, include the migration ID.",
  'HOSTED_PROVIDER_MISMATCH': "The cloud found this agent under a different account than Raft expected, a configuration problem on Raft's side. The Raft team has been alerted. If you contact support, include the migration ID.",
};

/// `hostedArrivalAttentionReason`: why a switched move to the cloud needs
/// attention, or null while it is fine or over.
String? hostedArrivalAttentionReason(Map<String, dynamic> migration) {
  if (!isHostedMigration(migration) ||
      (migration['state'] != 'arriving' && migration['state'] != 'starting')) {
    return null;
  }
  final reason = migration['failureReason'];
  return reason is String && _attentionCopy.containsKey(reason) ? reason : null;
}

/// Where the migration goes: the target computer, or the cloud.
Object migrationNoticeTargetLabel(
  List<Map<String, dynamic>> machines,
  Map<String, dynamic> migration,
) => isHostedMigration(migration)
    ? const MigrationText('the cloud')
    : migrationComputerLabel(machines, migration['targetMachineId']);

const _agentNotCreated = 'HOSTED_AGENT_NOT_CREATED';

/// presentation.ts `migrationFailurePresentation` for a move to the cloud
/// where it differs, else null: the cloud never set the agent up (so Raft put
/// it back), or the agent switched but did not finish setting up.
MigrationPresentation? hostedFailureOverride(
  Map<String, dynamic> migration,
  List<Map<String, dynamic>> machines,
  MigrationPresentation Function() reason,
) {
  if (!isHostedMigration(migration)) return null;
  final source = migrationComputerLabel(machines, migration['sourceMachineId']);
  if (migration['failureReason'] == _agentNotCreated ||
      migration['transportErrorCode'] == _agentNotCreated) {
    return MigrationPresentation(
      placement: MigrationText(
        'The agent is still on {source} and works as usual.',
        {'source': source},
      ),
      message: MigrationText(
        'The cloud never set the agent up, so Raft put it back on {source} unchanged. You can try again.',
        {'source': source},
      ),
      technicalCode: _agentNotCreated,
    );
  }
  if (_has(migration['flippedAt'])) {
    return reason().copyWith(
      message: const MigrationText(
        'The agent switched to the cloud but did not finish setting up there. If you contact support, include the migration ID.',
      ),
    );
  }
  return null;
}

/// The upload from the source is the only transfer that can drop in a move to
/// the cloud.
MigrationPresentation? hostedTransportLost(
  Map<String, dynamic> migration,
  Object source,
) {
  if (!isHostedMigration(migration)) return null;
  final code = migrationFailureCopyCode(
    migration['transportErrorCode'] as String?,
    migration['failureReason'] as String?,
  );
  if (code != 'MIGRATION_TRANSPORT_LOST') return null;
  return MigrationPresentation(
    message: MigrationText(
      'The upload to the cloud was interrupted. Make sure {source} is online, then try again.',
      {'source': source},
    ),
    technicalCode: code,
  );
}

/// presentation.ts `migrationNoticePresentation` for a move to the cloud
/// where it differs from a computer move; null falls back to the shared copy.
MigrationNoticePresentation? hostedNoticePresentation(
  Map<String, dynamic> migration,
  Object source,
) {
  if (!isHostedMigration(migration)) return null;
  final attention = hostedArrivalAttentionReason(migration);
  if (attention != null) {
    return MigrationNoticePresentation(
      intent: MigrationIntent.warning,
      title: const MigrationText('The cloud agent needs attention'),
      placement: const MigrationText('The agent is already in the cloud.'),
      message: MigrationText(_attentionCopy[attention]!),
      technicalCode: attention,
    );
  }
  MigrationNoticePresentation status(MigrationText message) =>
      MigrationNoticePresentation(
        intent: MigrationIntent.info,
        title: const MigrationText('Migration status'),
        message: message,
      );
  switch (migration['state']) {
    case 'ready':
      return status(
        const MigrationText('Checking which files can move to the cloud.'),
      );
    case 'in_transit':
      return status(
        isHostedReviewPending(migration)
            ? MigrationText(
                'Review what moves to the cloud, then confirm. The agent stays stopped on {source} until you decide.',
                {'source': source},
              )
            : const MigrationText(
                'Checking which files can move to the cloud.',
              ),
      );
    case 'arriving':
    case 'starting':
      return status(const MigrationText('Switching the agent to the cloud.'));
    case 'cancel_requested_pre_flip':
      return migration['cancelNeedsAttention'] == true
          ? MigrationNoticePresentation(
              intent: MigrationIntent.warning,
              title: const MigrationText("Cancellation couldn't finish"),
              message: MigrationText(
                "Raft couldn't finish cleaning up on {source}. Keep it online. If you contact support, include the migration ID.",
                {'source': source},
              ),
              technicalCode: migration['cancelErrorCode'] is String
                  ? migration['cancelErrorCode'] as String
                  : null,
            )
          : MigrationNoticePresentation(
              intent: MigrationIntent.info,
              title: const MigrationText('Canceling migration'),
              message: MigrationText(
                "The agent hasn't switched to the cloud, so it stays on {source}. Raft is cleaning up.",
                {'source': source},
              ),
            );
    case 'canceled_pre_flip':
      return MigrationNoticePresentation(
        intent: MigrationIntent.info,
        title: const MigrationText('Migration canceled'),
        message: MigrationText(
          'The move to the cloud was canceled. The agent is still on {source}.',
          {'source': source},
        ),
      );
    case 'completed':
      return const MigrationNoticePresentation(
        intent: MigrationIntent.success,
        title: MigrationText('Migration status'),
        message: MigrationText('The agent now runs in the cloud.'),
      );
  }
  return null;
}

/// MigrationProgressPanel `HOSTED_HEADER_IDS`: the English header of a move
/// to the cloud (`{target}` is not used).
String hostedPanelHeader(Map<String, dynamic> migration) {
  final state = migration['state'] as String?;
  final phase = migrationPhase(state);
  if (phase == 'completed') return 'Moved to the cloud';
  if (phase == 'canceled') return 'Move to the cloud canceled';
  if (migrationShownFailed(migration) ||
      migration['cancelNeedsAttention'] == true) {
    return 'Move to the cloud needs attention';
  }
  if (state != null && state.startsWith('cancel_requested_')) {
    return 'Canceling the move to the cloud';
  }
  return phase == 'active' ? 'Moving to the cloud' : 'Move to the cloud';
}

/// `HostedMigrationReview` skip reasons (`AgentMigrationHostedSkipReason`).
String hostedSkipReasonLabel(String? reason) => switch (reason) {
  'symlink' => 'Symbolic links',
  'git' => 'Git data (.git)',
  'raft_state' => "Raft's own files",
  'path_rule' => "Names the cloud can't store",
  'reserved' => 'Names the cloud reserves',
  'file_too_large' => 'Too large for a single file',
  'not_text' => 'Not text',
  'over_budget' => "Over the cloud's size or file limit",
  'provider_rejected' => 'Refused by the cloud',
  _ => 'Other reasons',
};

/// How long a finished move to the cloud stays on the cloud agent's profile.
const hostedArrivalVisible = Duration(hours: 24);

/// `showsHostedArrival`: a cloud agent shows the migration section only for
/// the move that brought it there: while it is switching, and for a day after
/// it ends.
bool hostedShowsArrival(Map<String, dynamic> migration, DateTime now) {
  if (migration.isEmpty ||
      !isHostedMigration(migration) ||
      !_has(migration['flippedAt'])) {
    return false;
  }
  final phase = migrationPhase(migration['state'] as String?);
  if (phase == 'active') return true;
  final endedAt = DateTime.tryParse(
    '${phase == 'completed' ? migration['completedAt'] : migration['updatedAt']}',
  );
  return endedAt != null && now.difference(endedAt) < hostedArrivalVisible;
}
