import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

bool isAgentMigrationRetry(Map<String, dynamic> notice) =>
    switch (notice['retryOfMigrationId']) {
      final String id => id.isNotEmpty,
      _ => false,
    };

class MigrationRetryDetails {
  MigrationRetryDetails(this.notice, this.agent, this.currentUserId);

  final Map<String, dynamic> notice;
  final String agent;
  final String? currentUserId;

  String note(BuildContext context) {
    final starter = notice['initiatedBy'];
    if (starter is! Map) {
      return raftFormat(
        context,
        '{agent} trimmed its workspace and retried this migration.',
        {'agent': agent},
      );
    }
    if (starter['id'] == currentUserId && currentUserId != null) {
      return raftFormat(
        context,
        '{agent} trimmed its workspace and retried this migration on your behalf.',
        {'agent': agent},
      );
    }
    final displayName = starter['displayName'];
    return raftFormat(
      context,
      '{agent} trimmed its workspace and retried this migration on behalf of {name}.',
      {
        'agent': agent,
        'name': displayName is String && displayName.isNotEmpty
            ? displayName
            : starter['name'] ?? '',
      },
    );
  }

  List<RaftDescriptionEntry> entries(
    BuildContext context, {
    required bool failed,
    required bool completed,
  }) {
    final comparison = notice['retryComparison'];
    if (comparison is! Map) return const [];
    final failure = comparison['previousFailure'];
    final packed = comparison['packed'];
    final previous = switch (failure) {
      {'entries': final int files} => _files(context, files),
      {'bytes': final int bytes, 'bytesIsLowerBound': true} => raftFormat(
        context,
        'At least {size}',
        {'size': _size(bytes)},
      ),
      {'bytes': final int bytes} => _size(bytes),
      _ => null,
    };
    final current = switch (packed) {
      {'files': final int files, 'bytes': final int bytes}
          when completed || packed['final'] == true || failed =>
        raftFormat(
          context,
          completed || packed['final'] == true
              ? '{files}, {size}'
              : '{files}, {size} when it stopped',
          {'files': _files(context, files), 'size': _size(bytes)},
        ),
      _ => null,
    };
    return [
      if (previous != null)
        RaftDescriptionEntry(raftText(context, 'Failed attempt'), previous),
      if (current != null)
        RaftDescriptionEntry(raftText(context, 'This attempt'), current),
    ];
  }

  String _files(BuildContext context, int count) =>
      raftFormat(context, count == 1 ? '{count} file' : '{count} files', {
        'count': NumberFormat.decimalPattern(
          Localizations.localeOf(context).toLanguageTag(),
        ).format(count),
      });

  String _size(int bytes) {
    const kib = 1024, mib = kib * 1024, gib = mib * 1024;
    if (bytes < kib) return '${bytes < 0 ? 0 : bytes} B';
    final (unit, label) = bytes < mib
        ? (kib, 'KiB')
        : bytes < gib
        ? (mib, 'MiB')
        : (gib, 'GiB');
    final value = bytes / unit;
    return '${value.toStringAsFixed(bytes % unit == 0 ? 0 : 1)} $label';
  }
}
