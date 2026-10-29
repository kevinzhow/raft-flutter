// Web components/agentMigration/{state,presentation,errors}.ts as pure
// functions over the status projection (`GET /agents/:id/migration`), so the
// copy is tested without a widget. Every text is a Web catalog English source
// string plus its values (a [MigrationText]); the display layer localizes it
// with raftText and fills the values. ICU select / plural arms of the Web
// messages are expanded here into plain keys, one per arm (raftText does not
// interpret ICU), and `{n, number}` is written `{n}` with the value grouped.

import 'package:raft_client/raft_client.dart' show RaftApiException;

import '../data/migration_error.dart';
import 'agent_detail_view.dart' show sourceRuntimeDisplayNames;
import 'agent_migration_hosted.dart';
import 'computer_detail_view.dart' show computerFileSize;

/// A catalog English [source] plus the values of its `{name}` placeholders. A
/// value may itself be a [MigrationText] (localized first) or a list of them
/// (joined with ", " as Web does).
class MigrationText {
  const MigrationText(this.source, [this.values = const {}]);
  final String source;
  final Map<String, Object?> values;

  /// [localize] maps a catalog English string to its localized form.
  String resolve(String Function(String source) localize) {
    return localize(source).replaceAllMapped(
      RegExp(r'\{([a-zA-Z0-9_]+)\}'),
      (match) {
        final name = match[1]!;
        if (!values.containsKey(name)) return match[0]!;
        final value = values[name];
        if (value is MigrationText) return value.resolve(localize);
        if (value is List) {
          return value
              .map((v) => v is MigrationText ? v.resolve(localize) : '$v')
              .join(', ');
        }
        return '${value ?? ''}';
      },
    );
  }

  /// The English rendering (tests, logs).
  String get english => resolve((s) => s);
}

/// Web errors.ts `MigrationErrorPresentation`.
class MigrationPresentation {
  const MigrationPresentation({
    required this.message,
    this.placement,
    this.issues = const [],
    this.technicalCode,
    this.diagnosticRef,
    this.recoveryOpenComputers = false,
    this.recoveryComputerId,
  });

  /// Shown first, on its own line: where the agent is now.
  final MigrationText? placement;
  final MigrationText message;
  final List<MigrationText> issues;
  final String? technicalCode, diagnosticRef;

  /// Web `recovery: "open_computers_and_retry"`.
  final bool recoveryOpenComputers;
  final String? recoveryComputerId;

  MigrationPresentation copyWith({
    MigrationText? placement,
    MigrationText? message,
  }) => MigrationPresentation(
    placement: placement ?? this.placement,
    message: message ?? this.message,
    issues: issues,
    technicalCode: technicalCode,
    diagnosticRef: diagnosticRef,
    recoveryOpenComputers: recoveryOpenComputers,
    recoveryComputerId: recoveryComputerId,
  );
}

enum MigrationIntent { info, warning, success }

/// Web presentation.ts `MigrationNoticePresentation`.
class MigrationNoticePresentation extends MigrationPresentation {
  const MigrationNoticePresentation({
    required this.intent,
    required this.title,
    required super.message,
    super.placement,
    super.issues,
    super.technicalCode,
  });
  final MigrationIntent intent;
  final MigrationText title;
}

// ------------------------------------------------------------------ state

/// Web state.ts MIGRATION_PROGRESS_STEPS.
const migrationProgressSteps = <String>[
  'Stop Agent',
  'Pack workspace',
  'Transfer files',
  'Start on new computer',
  'Migration complete',
];

// state -> lowest progress step it implies (state.ts AGENT_MIGRATION_STATE_INFO).
const _stateStep = <String, int>{
  'provisioning': 0,
  'prep': 1,
  'ready': 2,
  'in_transit': 2,
  'arriving': 3,
  'starting': 3,
  'cancel_requested_pre_flip': 0,
  'cancel_requested_post_flip': 0,
  'canceled_pre_flip': 0,
  'canceled_post_flip': 0,
  'completed': 5,
  'aborted': 0,
  'failed': 0,
};

const _cancellableStates = {
  'provisioning',
  'prep',
  'ready',
  'in_transit',
  'arriving',
  'starting',
};

bool _has(Object? value) => value is String && value.isNotEmpty;

/// Web state.ts `canCancelMigration`.
bool canCancelMigration(Map<String, dynamic> migration) {
  final revision = migration['revision'];
  return !hostedCancelRefused(migration) &&
      _cancellableStates.contains(migration['state']) &&
      revision is int &&
      revision > 0;
}

/// Web state.ts `migrationProgressStep`: the state's floor, advanced by what
/// the timestamps show happened.
int migrationProgressStep(Map<String, dynamic> migration) {
  if (isHostedMigration(migration)) return hostedMigrationProgressStep(migration);
  final step = _stateStep[migration['state']] ?? 0;
  if (step == migrationProgressSteps.length) return step;
  final observed = _has(migration['arrivedAt']) || _has(migration['flippedAt'])
      ? 3
      : _has(migration['readyAt']) ||
            _has(migration['transportControlRegisteredAt'])
      ? 2
      : _has(migration['sourceQuiescedAt'])
      ? 1
      : 0;
  return step > observed ? step : observed;
}

/// presentation.ts: a `starting` run whose auto start failed is shown failed.
bool migrationShownFailed(Map<String, dynamic> migration) =>
    migrationPhase(migration['state'] as String?) == 'failed' ||
    migration['state'] == 'starting' &&
        migration['failureReason'] == 'auto_start_failed' ||
    // A switched move to the cloud that stalled needs attention like a failure.
    hostedArrivalAttentionReason(migration) != null;

// ----------------------------------------------------------------- labels

/// presentation.ts `migrationTargetLabel`: the computer's name, else its id
/// prefix; "Unknown computer" without an id.
Object migrationComputerLabel(
  List<Map<String, dynamic>> machines,
  Object? machineId,
) {
  if (machineId is! String || machineId.isEmpty) {
    return const MigrationText('Unknown computer');
  }
  final name = machines
      .where((m) => m['id'] == machineId)
      .firstOrNull?['name'];
  if (name is String) return name;
  return machineId.length > 8 ? machineId.substring(0, 8) : machineId;
}

// ------------------------------------------------------------- wire values

const _gib = 1024 * 1024 * 1024;
final _safeTechnicalCode = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{1,127}$');
final _safeRuntimeId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');

int? _safeInt(String text) {
  final value = int.tryParse(text);
  return value != null && value >= 0 && value <= 9007199254740991
      ? value
      : null;
}

int? _wireInteger(String? raw, String key) {
  if (raw == null) return null;
  final match = RegExp('(?:^|:)$key=(\\d+)(?=:|\$)').firstMatch(raw);
  return match == null ? null : _safeInt(match[1]!);
}

String? _wireString(String? raw, String key) {
  if (raw == null) return null;
  return RegExp('(?:^|:)$key=([^:]*)').firstMatch(raw)?[1];
}

String _formatGib(int bytes) {
  final value = bytes / _gib;
  return '${value == value.truncateToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} GiB';
}

/// ICU `{n, number}` in the en locale.
String _grouped(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

bool _hasControlCharacters(String value) =>
    value.codeUnits.any((c) => c <= 31 || c == 127);

String? _decode(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return null;
  }
}

List<(String, int)> _largestEntries(String? raw) {
  final encoded = _wireString(raw, 'topEntries');
  if (encoded == null || encoded.isEmpty) return const [];
  final entries = <(String, int)>[];
  for (final item in encoded.split(';').take(3)) {
    final separator = item.lastIndexOf(',');
    if (separator <= 0) continue;
    final path = _decode(item.substring(0, separator));
    final size = int.tryParse(item.substring(separator + 1));
    if (path == null ||
        path.isEmpty ||
        path.length > 128 ||
        _hasControlCharacters(path) ||
        size == null ||
        size < 0) {
      continue;
    }
    entries.add((path, size));
  }
  return entries;
}

bool _isSafeAccountingPath(String value) {
  final base = value.endsWith('/')
      ? value.substring(0, value.length - 1)
      : value;
  return base.isNotEmpty &&
      base != '.' &&
      base != '..' &&
      !value.startsWith('/') &&
      !value.startsWith(r'\') &&
      !value.contains(r'\') &&
      !base.contains('/') &&
      !RegExp(r'^[A-Za-z]:').hasMatch(value) &&
      !RegExp(r'^\.env(?:\.|$)', caseSensitive: false).hasMatch(base) &&
      !RegExp(
        r'(?:secret|token|credential|api[-_]?key)',
        caseSensitive: false,
      ).hasMatch(base);
}

/// errors.ts `parseTopPathCounts`; [strict] returns null on any bad item.
List<(String, int)>? _topPathCounts(
  String? raw, {
  String key = 'topPaths',
  bool strict = false,
}) {
  final encoded = _wireString(raw, key);
  if (encoded == null) return strict ? null : const [];
  if (encoded.isEmpty) return const [];
  final items = encoded.split(';');
  if (strict && items.length > 3) return null;
  final entries = <(String, int)>[];
  for (final item in items.take(3)) {
    final separator = item.lastIndexOf(',');
    if (separator <= 0) {
      if (strict) return null;
      continue;
    }
    final path = _decode(item.substring(0, separator));
    final count = int.tryParse(item.substring(separator + 1));
    if (path == null ||
        path.isEmpty ||
        path.length > 128 ||
        _hasControlCharacters(path) ||
        !_isSafeAccountingPath(path) ||
        count == null ||
        count <= 0) {
      if (strict) return null;
      continue;
    }
    entries.add((path, count));
  }
  return entries;
}

List<MigrationText> _pathCounts(List<(String, int)> entries) => [
  for (final (path, count) in entries)
    MigrationText('{path} ({count})', {'path': path, 'count': _grouped(count)}),
];

const _bundleAdvice =
    'Ask the agent to delete large files it no longer needs, or to list them in .raftmigrateignore, then try again.';
const _foldersAdvice =
    'Ask the agent to delete folders it no longer needs, or to list them in .raftmigrateignore, then try again.';

MigrationText _bundleTooLarge(String? raw) {
  final maxBytes = _wireInteger(raw, 'maxBytes');
  final entries = _largestEntries(raw);
  final items = [
    for (final (path, size) in entries) '$path (${_formatGib(size)})',
  ].join(', ');
  final values = <String, Object?>{
    if (maxBytes != null) 'limit': _formatGib(maxBytes),
    if (entries.isNotEmpty) 'items': items,
  };
  final head = maxBytes != null
      ? 'The workspace is too large to move: compressed, it is over the {limit} limit.'
      : 'The workspace is too large to move.';
  return MigrationText(
    entries.isEmpty
        ? '$head $_bundleAdvice'
        : '$head Largest items: {items}. $_bundleAdvice',
    values,
  );
}

MigrationText _manifestTooLarge(String? raw) {
  final count = _wireInteger(raw, 'entryCount');
  final paths = _pathCounts(_topPathCounts(raw) ?? const []);
  final head = count != null
      ? 'The workspace has too many files and folders to move ({count}).'
      : 'The workspace has too many files and folders to move.';
  return MigrationText(
    paths.isEmpty
        ? '$head $_foldersAdvice'
        : '$head Most are in {paths}. $_foldersAdvice',
    {
      if (count != null) 'count': _grouped(count),
      if (paths.isNotEmpty) 'paths': paths,
    },
  );
}

MigrationText _entryCountLimit(String? raw) {
  final count = _wireInteger(raw, 'entryCount');
  final limit = _wireInteger(raw, 'maxEntries');
  final top = _topPathCounts(raw, key: 'topPathCounts', strict: true);
  if (count == null ||
      limit == null ||
      limit <= 0 ||
      count <= limit ||
      top == null ||
      top.any((e) => e.$2 > count)) {
    return MigrationText(migrationCodeText(_entryCountCode, _failed));
  }
  final paths = _pathCounts(top);
  const head =
      'The workspace has {count} files and folders; migration supports up to {limit}.';
  return MigrationText(
    paths.isEmpty
        ? '$head $_foldersAdvice'
        : '$head Most are in {paths}. $_foldersAdvice',
    {
      'count': _grouped(count),
      'limit': _grouped(limit),
      if (paths.isNotEmpty) 'paths': paths,
    },
  );
}

const _entryCountCode = 'MIGRATION_OBJECT_STORE_ENTRY_COUNT_LIMIT_EXCEEDED';
const _failed = MigrationErrorContext.failed;

MigrationText _insufficientDisk(String? raw) {
  final required = _wireInteger(raw, 'requiredBytes');
  final available = _wireInteger(raw, 'availableBytes');
  return required != null && available != null
      ? MigrationText(
          'The target computer needs {required} free to stage and install this migration, but only {available} is available. Free disk space and try again.',
          {'required': _formatGib(required), 'available': _formatGib(available)},
        )
      : const MigrationText(
          'The target computer does not have enough free disk space to stage and install this migration. Free disk space and try again.',
        );
}

// ------------------------------------------------------------- capability

/// errors.ts `MigrationComputerCapabilityFailure`.
class MigrationCapabilityFailure {
  const MigrationCapabilityFailure(this.side, this.reason, this.runtime);
  final String side, reason, runtime;
}

/// errors.ts `parseMigrationComputerCapabilityDetails`: null when the wire
/// value is not exactly 1-2 well-formed failures for distinct sides.
List<MigrationCapabilityFailure>? parseMigrationComputerCapabilityDetails(
  Object? value,
) {
  if (value is! Map) return null;
  final failures = value['failures'];
  if (failures is! List || failures.isEmpty || failures.length > 2) return null;
  final parsed = <MigrationCapabilityFailure>[];
  final sides = <String>{};
  for (final candidate in failures) {
    if (candidate is! Map) return null;
    final side = candidate['side'], reason = candidate['reason'];
    final runtime = candidate['runtime'];
    if (side != 'source' && side != 'target') return null;
    if (reason != 'runtime_unconfirmed' && reason != 'runtime_missing') {
      return null;
    }
    if (!sides.add(side as String)) return null;
    if (runtime is! String || !_safeRuntimeId.hasMatch(runtime)) return null;
    parsed.add(MigrationCapabilityFailure(side, reason as String, runtime));
  }
  return parsed;
}

/// errors.ts `parseMigrationResumableCapabilityDetail`: the side that needs a
/// Raft Computer update ('source' | 'target' | 'both'), or null.
String? parseMigrationResumableCapabilityDetail(Object? value) {
  if (value is! Map) return null;
  final side = value['side'];
  if (side != 'source' && side != 'target' && side != 'both') return null;
  if (value['reason'] != 'capability_missing') return null;
  return side as String;
}

/// The computers an error is about, for copy that names them.
class MigrationComputers {
  const MigrationComputers({
    this.sourceName,
    this.targetName,
    this.sourceId,
    this.targetId,
    this.sourceStatus,
    this.targetStatus,
  });
  final String? sourceName, targetName, sourceId, targetId;
  final String? sourceStatus, targetStatus;
}

String _runtimeName(String id) => sourceRuntimeDisplayNames[id] ?? id;

MigrationPresentation _capability(
  Object? details,
  MigrationComputers computers,
  String? technicalCode,
) {
  const generic = MigrationText(
    "Both computers must run a compatible Raft Computer version and support this agent's runtime. Update or reconnect them, or choose another computer, then try again.",
  );
  MigrationPresentation fallback() => MigrationPresentation(
    message: generic,
    technicalCode: technicalCode,
    recoveryOpenComputers: true,
  );
  final failures = parseMigrationComputerCapabilityDetails(details);
  if (failures == null) return fallback();
  final issues = <MigrationText>[];
  final sides = <String>{};
  for (final failure in failures) {
    final computer = failure.side == 'source'
        ? computers.sourceName
        : computers.targetName;
    if (computer == null || computer.isEmpty) return fallback();
    sides.add(failure.side);
    issues.add(
      MigrationText(
        failure.reason == 'runtime_unconfirmed'
            ? '{computer} has not reported whether {runtime} is available. Start or restart Raft Computer and wait for runtime detection, or choose another computer.'
            : '{computer} does not support {runtime}. Install or enable that runtime on this computer, or choose another computer.',
        {'computer': computer, 'runtime': _runtimeName(failure.runtime)},
      ),
    );
  }
  final only = sides.length == 1 ? failures.first.side : null;
  return MigrationPresentation(
    message: const MigrationText(
      'Fix these computer requirements before starting the migration:',
    ),
    issues: issues,
    technicalCode: technicalCode,
    recoveryOpenComputers: true,
    recoveryComputerId: only == 'source'
        ? computers.sourceId
        : only == 'target'
        ? computers.targetId
        : null,
  );
}

MigrationPresentation _resumable(
  Object? details,
  MigrationComputers computers,
  String? technicalCode,
) {
  final side = parseMigrationResumableCapabilityDetail(details);
  final source = computers.sourceName, target = computers.targetName;
  final hasSource = source != null && source.isNotEmpty;
  final hasTarget = target != null && target.isNotEmpty;
  if (side == 'both' && hasSource && hasTarget) {
    return MigrationPresentation(
      message: MigrationText(
        '{source} and {target} need a Raft Computer update before they can move agents. Update Raft Computer on both to the latest version, restart them, wait for them to reconnect, then try again.',
        {'source': source, 'target': target},
      ),
      technicalCode: technicalCode,
      recoveryOpenComputers: true,
    );
  }
  final computer = side == 'source' && hasSource
      ? source
      : side == 'target' && hasTarget
      ? target
      : null;
  if (computer != null) {
    return MigrationPresentation(
      message: MigrationText(
        '{computer} needs a Raft Computer update before it can move agents. Update Raft Computer on {computer} to the latest version, restart it, wait for it to reconnect, then try again.',
        {'computer': computer},
      ),
      technicalCode: technicalCode,
      recoveryOpenComputers: true,
      recoveryComputerId: side == 'source'
          ? computers.sourceId
          : computers.targetId,
    );
  }
  return MigrationPresentation(
    message: MigrationText(
      migrationCodeText(
        'MIGRATION_RESUMABLE_CAPABILITY_REQUIRED',
        MigrationErrorContext.start,
      ),
    ),
    technicalCode: technicalCode,
    recoveryOpenComputers: true,
  );
}

// ------------------------------------------------------------ transport

MigrationText _transportLost({
  required MigrationErrorContext context,
  required MigrationComputers computers,
  String? transportLostAt,
  String Function(String value)? formatTimestamp,
}) {
  final plain = MigrationText(
    migrationCodeText('MIGRATION_TRANSPORT_LOST', context),
  );
  if (context != MigrationErrorContext.failed) return plain;
  final lostAt = _has(transportLostAt) && DateTime.tryParse(transportLostAt!) != null
      ? formatTimestamp?.call(transportLostAt)
      : null;
  final event = lostAt != null && lostAt.isNotEmpty
      ? MigrationText(
          'The connection between the two computers dropped at {time}, during the transfer.',
          {'time': lostAt},
        )
      : const MigrationText(
          'The connection between the two computers dropped during the transfer.',
        );
  final sourceKnown =
      _has(computers.sourceName) &&
      (computers.sourceStatus == 'online' ||
          computers.sourceStatus == 'offline');
  final targetKnown =
      _has(computers.targetName) &&
      (computers.targetStatus == 'online' ||
          computers.targetStatus == 'offline');
  final sourceOffline = computers.sourceStatus == 'offline';
  final targetOffline = computers.targetStatus == 'offline';
  final retry = sourceKnown && targetKnown && !sourceOffline && !targetOffline
      ? const MigrationText('Both computers are online now, so you can try again.')
      : sourceKnown && targetKnown && sourceOffline && targetOffline
      ? MigrationText('Bring {source} and {target} online, then try again.', {
          'source': computers.sourceName,
          'target': computers.targetName,
        })
      : sourceKnown && targetKnown
      ? MigrationText('Bring {computer} online, then try again.', {
          'computer': sourceOffline
              ? computers.sourceName
              : computers.targetName,
        })
      : const MigrationText(
          'Check that both computers are online, then try again.',
        );
  // Web joins the two sentences with a space in every locale.
  return MigrationText('{event} {retry}', {'event': event, 'retry': retry});
}

MigrationText _workspaceConflict(
  String code,
  MigrationErrorContext context,
  String? workspacePath,
) {
  final path = workspacePath?.trim();
  if (path == null || path.isEmpty) {
    return MigrationText(migrationCodeText(code, context));
  }
  return code == 'MIGRATION_WORKSPACE_ALREADY_EXISTS'
      ? MigrationText(
          'A workspace already exists at {path} on the target computer, so the agent was not installed. Rename or move that folder — for example, appending .bak to its name is enough — then start the migration again. Check before you move it that this is not a copy you still need — Raft never deletes it, and moving it leaves it on that computer.',
          {'path': path},
        )
      : MigrationText(
          'A completed copy of this workspace from an earlier migration is at {path} on the target computer, so Raft stopped instead of replacing it. Rename or move that folder — for example, appending .old to its name is enough — then start the migration again. Check before you move it which copy is current — Raft never deletes it, and moving it leaves it on that computer.',
          {'path': path},
        );
}

// ------------------------------------------------------------------ errors

/// errors.ts `conventionalAgentWorkspacePath`.
String? conventionalAgentWorkspacePath(String? agentId) {
  final id = agentId?.trim();
  return id == null || id.isEmpty ? null : '~/.slock/agents/$id';
}

/// errors.ts `migrationFailureCopyCode`: a detailed daemon cause in
/// `transportErrorCode` is used only when it has copy, else `failureReason`.
String? migrationFailureCopyCode(
  String? transportErrorCode,
  String? failureReason,
) {
  if (transportErrorCode == null || transportErrorCode.isEmpty) {
    return failureReason;
  }
  return migrationHasCopy(transportErrorCode) ||
          failureReason == null ||
          failureReason.isEmpty
      ? transportErrorCode
      : failureReason;
}

/// errors.ts `targetRuntimeDetectionMessage` (task #1268): the target computer
/// is still detecting its runtimes (`pending`) or its last detection never
/// probed the agent's runtime (`incomplete`); both are retryable.
MigrationText _targetDetection(Object? details) {
  final map = details is Map ? details : const {};
  if (map['detectionStatus'] == 'incomplete') {
    final runtime = map['runtime'];
    return MigrationText(
      "The target computer's last runtime detection did not finish for {runtime}. Rescan its runtimes on the Computer page, then try again.",
      {'runtime': runtime is String ? runtime : ''},
    );
  }
  return const MigrationText(
    'The target computer is still detecting its runtimes. Try again in a moment.',
  );
}

/// errors.ts `migrationErrorPresentation`. [details] is the response's
/// `details` (capability codes), [rawMessage] its `transportErrorMessage` /
/// message (the size codes carry their numbers there).
MigrationPresentation migrationErrorPresentation({
  String? code,
  String? rawMessage,
  required MigrationErrorContext context,
  String? reason,
  Object? details,
  MigrationComputers computers = const MigrationComputers(),
  String? agentWorkspacePath,
  String? transportLostAt,
  String Function(String value)? formatTimestamp,
}) {
  final technicalCode = code != null && _safeTechnicalCode.hasMatch(code)
      ? code
      : reason != null && _safeTechnicalCode.hasMatch(reason)
      ? reason
      : null;
  if (code == 'COMPUTER_CAPABILITY_INSUFFICIENT') {
    return _capability(details, computers, technicalCode);
  }
  if (code == 'MIGRATION_RESUMABLE_CAPABILITY_REQUIRED') {
    return _resumable(details, computers, technicalCode);
  }
  final message = switch (code) {
    'MIGRATION_TRANSPORT_LOST' => _transportLost(
      context: context,
      computers: computers,
      transportLostAt: transportLostAt,
      formatTimestamp: formatTimestamp,
    ),
    'MIGRATION_WORKSPACE_ALREADY_EXISTS' ||
    'MIGRATION_WORKSPACE_COMPLETE_OLD_COPY' => _workspaceConflict(
      code!,
      context,
      agentWorkspacePath,
    ),
    'TARGET_RUNTIME_DETECTION_PENDING' => _targetDetection(details),
    'MIGRATION_OBJECT_STORE_BUNDLE_TOO_LARGE' => _bundleTooLarge(rawMessage),
    'MIGRATION_OBJECT_STORE_MANIFEST_TOO_LARGE' => _manifestTooLarge(
      rawMessage,
    ),
    'MIGRATION_OBJECT_STORE_INSUFFICIENT_DISK' => _insufficientDisk(rawMessage),
    _entryCountCode => _entryCountLimit(rawMessage),
    _ => MigrationText(migrationCodeText(code, context, reason: reason)),
  };
  return MigrationPresentation(message: message, technicalCode: technicalCode);
}

/// presentation.ts `migrationStartErrorPresentation`: the `code` and
/// `details` of a failed start request, naming the computers of the move.
MigrationPresentation migrationStartErrorPresentation(
  Object error,
  MigrationComputers computers,
) {
  final api = error is RaftApiException ? error : null;
  final code = api?.details['code'];
  return migrationErrorPresentation(
    code: code is String ? code : null,
    rawMessage: api?.message,
    context: MigrationErrorContext.start,
    details: api?.details['details'],
    computers: computers,
  );
}

// ----------------------------------------------------------------- notice

/// presentation.ts abort detail: the copy states no fixed duration, and the
/// prep-deadline variant carries the deadline only when REST sent it.
MigrationText _abortDetail(
  String? reason,
  Object source,
  Object target,
  String? deadline,
) {
  final values = {'source': source, 'target': target};
  return switch (reason) {
    'prep-deadline' when deadline != null => MigrationText(
      'Preparing the workspace on {source} stopped making progress before the deadline ({deadline}). {source} may have gone offline, or packing stalled. Make sure {source} is online, then try again.',
      {...values, 'deadline': deadline},
    ),
    'prep-deadline' => MigrationText(
      'Preparing the workspace on {source} stopped making progress before the deadline. {source} may have gone offline, or packing stalled. Make sure {source} is online, then try again.',
      values,
    ),
    'transfer-deadline' => const MigrationText(
      'The workspace transfer did not finish before the deadline. Make sure both computers stay online and the target has enough free disk space, then try again.',
    ),
    'arrival-deadline' => MigrationText(
      'The target computer {target} did not finish installing the workspace before the deadline. Make sure the target is running and has enough free disk space, then try again.',
      values,
    ),
    _ => const MigrationText(
      'The migration stopped before it completed. Review the technical reason, then try again.',
    ),
  };
}

MigrationPresentation _failureReason(
  Map<String, dynamic> migration,
  List<Map<String, dynamic>> machines,
  String Function(String value) formatTimestamp,
) {
  final sourceMachine = machines
      .where((m) => m['id'] == migration['sourceMachineId'])
      .firstOrNull;
  final targetMachine = machines
      .where((m) => m['id'] == migration['targetMachineId'])
      .firstOrNull;
  final source = migrationComputerLabel(machines, migration['sourceMachineId']);
  final target = migrationNoticeTargetLabel(machines, migration);
  String? text(String key) => migration[key] is String
      ? migration[key] as String
      : null;
  if (migration['state'] == 'aborted') {
    final fallback = migrationErrorPresentation(
      context: MigrationErrorContext.aborted,
      reason: text('abortReason'),
    );
    final deadline = text('prepDeadlineAt');
    return MigrationPresentation(
      message: _abortDetail(
        text('abortReason'),
        source,
        target,
        deadline == null ? null : formatTimestamp(deadline),
      ),
      technicalCode: fallback.technicalCode,
    );
  }
  final lost = hostedTransportLost(migration, source);
  if (lost != null) return lost;
  return migrationErrorPresentation(
    code: migrationFailureCopyCode(
      text('transportErrorCode'),
      text('failureReason'),
    ),
    rawMessage: text('transportErrorMessage'),
    context: MigrationErrorContext.failed,
    reason: text('abortReason'),
    agentWorkspacePath: conventionalAgentWorkspacePath(text('agentId')),
    computers: MigrationComputers(
      sourceName: sourceMachine == null
          ? (source is String ? source : null)
          : sourceMachine['name'] as String?,
      targetName: targetMachine == null
          ? (target is String ? target : null)
          : targetMachine['name'] as String?,
      sourceStatus: sourceMachine?['status'] as String?,
      targetStatus: targetMachine?['status'] as String?,
    ),
    transportLostAt: text('transportLostAt'),
    formatTimestamp: formatTimestamp,
  );
}

/// presentation.ts `migrationFailurePresentation`: before the flip the agent
/// never left the source, so the copy says that first; after it, the agent is
/// on the target and could not start there.
MigrationPresentation _failurePresentation(
  Map<String, dynamic> migration,
  List<Map<String, dynamic>> machines,
  String Function(String value) formatTimestamp,
) {
  final hosted = hostedFailureOverride(
    migration,
    machines,
    () => _failureReason(migration, machines, formatTimestamp),
  );
  if (hosted != null) return hosted;
  final reason = _failureReason(migration, machines, formatTimestamp);
  if (_has(migration['flippedAt'])) {
    return reason.copyWith(
      message: MigrationText(
        'The agent moved to {target} but could not start there. Make sure Raft Computer is running on {target}, then start the agent.',
        {'target': migrationComputerLabel(machines, migration['targetMachineId'])},
      ),
    );
  }
  return reason.copyWith(
    placement: MigrationText(
      'The agent is still on {source} and works as usual.',
      {'source': migrationComputerLabel(machines, migration['sourceMachineId'])},
    ),
  );
}

MigrationText _sourceStage(
  Map<String, dynamic> migration,
  Object source,
  Object target,
  DateTime now,
) {
  if (_has(migration['transportControlRegisteredAt'])) {
    if (isHostedMigration(migration)) {
      return MigrationText(
        'Uploading the workspace from {source} to the cloud.',
        {'source': source},
      );
    }
    return MigrationText(
      'Uploading the workspace from {source} to send to {target}.',
      {'source': source, 'target': target},
    );
  }
  final quiesced = migration['sourceQuiescedAt'];
  if (!_has(quiesced)) {
    return MigrationText(
      'Stopping the agent on {source} so its workspace can be packed.',
      {'source': source},
    );
  }
  final progress = migration['sourceBuildProgress'];
  if (progress is Map) {
    final files = progress['files'], bytes = progress['bytes'];
    if (files is num && bytes is num && (files > 0 || bytes > 0)) {
      return MigrationText(
        'Packing the workspace on {source}: {files} files, {size} so far.',
        {
          'source': source,
          'files': _grouped(files.toInt()),
          'size': computerFileSize(bytes),
        },
      );
    }
  }
  final since = DateTime.tryParse(quiesced as String);
  final minutes = since == null ? 0 : now.difference(since).inMinutes;
  if (minutes >= 1) {
    return MigrationText(
      minutes == 1
          ? 'Packing the workspace on {source} (1 minute so far). Large workspaces can take up to 30 minutes.'
          : 'Packing the workspace on {source} ({minutes} minutes so far). Large workspaces can take up to 30 minutes.',
      {'source': source, 'minutes': minutes},
    );
  }
  return MigrationText(
    'Packing the workspace on {source}. Large workspaces can take up to 30 minutes.',
    {'source': source},
  );
}

/// presentation.ts `migrationNoticePresentation`. [now] is the clock for the
/// packing elapsed time; [formatTimestamp] formats a deadline / lost-at value.
MigrationNoticePresentation migrationNoticePresentation(
  Map<String, dynamic> migration,
  List<Map<String, dynamic>> machines, {
  required DateTime now,
  required String Function(String value) formatTimestamp,
}) {
  final source = migrationComputerLabel(machines, migration['sourceMachineId']);
  final target = migrationNoticeTargetLabel(machines, migration);
  final hosted = hostedNoticePresentation(migration, source);
  if (hosted != null) return hosted;
  MigrationNoticePresentation status(MigrationText message) =>
      MigrationNoticePresentation(
        intent: MigrationIntent.info,
        title: const MigrationText('Migration status'),
        message: message,
      );
  MigrationNoticePresentation fromFailure(MigrationText title) {
    final failure = _failurePresentation(migration, machines, formatTimestamp);
    return MigrationNoticePresentation(
      intent: MigrationIntent.warning,
      title: title,
      message: failure.message,
      placement: failure.placement,
      issues: failure.issues,
      technicalCode: failure.technicalCode,
    );
  }

  final attention = migration['cancelNeedsAttention'] == true;
  final cancelCode = migration['cancelErrorCode'] is String
      ? migration['cancelErrorCode'] as String
      : null;
  switch (migration['state']) {
    case 'failed':
      return fromFailure(const MigrationText('Migration failed'));
    case 'aborted':
      return fromFailure(const MigrationText('Migration aborted'));
    case 'cancel_requested_pre_flip':
      return attention
          ? MigrationNoticePresentation(
              intent: MigrationIntent.warning,
              title: const MigrationText("Cancellation couldn't finish"),
              message: const MigrationText(
                "Raft couldn't finish cleaning up the original computer. Keep both computers online. If you contact support, include the migration ID.",
              ),
              technicalCode: cancelCode,
            )
          : const MigrationNoticePresentation(
              intent: MigrationIntent.info,
              title: MigrationText('Canceling migration'),
              message: MigrationText(
                "The agent hasn't switched computers yet, so it stays on the original computer. Raft is cleaning up.",
              ),
            );
    case 'cancel_requested_post_flip':
      return attention
          ? MigrationNoticePresentation(
              intent: MigrationIntent.warning,
              title: const MigrationText("Cancellation couldn't finish"),
              message: const MigrationText(
                "Raft couldn't finish cleaning up after the agent switched computers. Keep both computers online. If you contact support, include the migration ID.",
              ),
              technicalCode: cancelCode,
            )
          : const MigrationNoticePresentation(
              intent: MigrationIntent.info,
              title: MigrationText('Stopping the agent on the new computer'),
              message: MigrationText(
                'The agent had already switched to the new computer. Raft is stopping it there and cleaning up both computers.',
              ),
            );
    case 'canceled_pre_flip':
      return const MigrationNoticePresentation(
        intent: MigrationIntent.info,
        title: MigrationText('Migration canceled'),
        message: MigrationText(
          'The migration was canceled before the agent switched computers. The agent is still on the original computer.',
        ),
      );
    case 'canceled_post_flip':
      return const MigrationNoticePresentation(
        intent: MigrationIntent.info,
        title: MigrationText('Migration canceled'),
        message: MigrationText(
          'The migration was canceled after the agent switched computers. The agent is stopped on the new computer, and cleanup is done.',
        ),
      );
    case 'provisioning':
      return status(_sourceStage(migration, source, target, now));
    case 'prep':
      return status(
        MigrationText(
          'Packing the workspace on {source}. Large workspaces can take up to 30 minutes.',
          {'source': source},
        ),
      );
    case 'ready':
      return status(
        MigrationText('The workspace is packed. Sending it to {target}.', {
          'target': target,
        }),
      );
    case 'in_transit':
      return status(
        MigrationText('Transferring workspace to {target}.', {'target': target}),
      );
    case 'arriving':
      return status(
        MigrationText('Setting up the workspace on {target}.', {
          'target': target,
        }),
      );
    case 'starting':
      return migration['failureReason'] == 'auto_start_failed'
          ? MigrationNoticePresentation(
              intent: MigrationIntent.warning,
              title: const MigrationText('Agent did not start'),
              message: MigrationText(
                'The workspace moved to {target}, but the agent did not start automatically.',
                {'target': target},
              ),
              technicalCode: 'auto_start_failed',
            )
          : status(
              MigrationText('Starting the agent on {target}.', {
                'target': target,
              }),
            );
    case 'completed':
      return MigrationNoticePresentation(
        intent: MigrationIntent.success,
        title: const MigrationText('Migration status'),
        message: MigrationText(
          'The agent migrated to {target} and is now running there.',
          {'target': target},
        ),
      );
    default:
      return status(
        MigrationText('Migration state {state} for {target}.', {
          'state': '${migration['state']}',
          'target': target,
        }),
      );
  }
}

/// Web MigrationProgressPanel header: (message id source, uses {target}).
String migrationPanelHeader(Map<String, dynamic> migration) {
  if (isHostedMigration(migration)) return hostedPanelHeader(migration);
  final state = migration['state'] as String?;
  final phase = migrationPhase(state);
  final cancelRequested = state != null && state.startsWith('cancel_requested_');
  if (phase == 'completed') return 'Migrated to {target}';
  if (phase == 'canceled') return 'Migration to {target} canceled';
  if (migrationShownFailed(migration) ||
      migration['cancelNeedsAttention'] == true) {
    return 'Migration to {target} needs attention';
  }
  if (cancelRequested) return 'Canceling migration to {target}';
  if (phase == 'active') return 'Migrating to {target}';
  return 'Migration to {target}';
}
