// The runtime detection notice of the Computer detail page (Web
// MachineDetailPanel `machine-runtime-detection`, task #1268): while the
// daemon is still detecting, or when detection did not finish, the runtime
// list below is the last confirmed one; the notice says so, and offers the
// recovery (Rescan runtimes) to whoever may use it.
import 'package:flutter/material.dart';

import '../raft_ui.dart';

enum RaftRuntimeDetectionStatus { pending, incomplete }

enum RaftRuntimeDetectionReason { deadline, childFailed, cancelled }

/// The server's explicit detection state of one Computer. [unfinishedLabels]
/// are the display names of the runtimes that were not checked.
class RaftRuntimeDetection {
  const RaftRuntimeDetection({
    required this.status,
    this.unfinishedLabels = const [],
    this.reason = RaftRuntimeDetectionReason.childFailed,
  });
  final RaftRuntimeDetectionStatus status;
  final List<String> unfinishedLabels;
  final RaftRuntimeDetectionReason reason;
}

/// A rescan request that was refused or failed. [forbidden] is the 403 that
/// has its own message.
class RaftRuntimeRescanFailure implements Exception {
  const RaftRuntimeRescanFailure({this.forbidden = false});
  final bool forbidden;
}

class RaftRuntimeDetectionNotice extends StatefulWidget {
  const RaftRuntimeDetectionNotice({
    super.key,
    required this.detection,
    required this.canRescan,
    required this.rescan,
  });
  final RaftRuntimeDetection detection;

  /// The creator or someone with the Edit Machines capability.
  final bool canRescan;

  /// Throws [RaftRuntimeRescanFailure] when the request did not go through.
  final Future<void> Function() rescan;

  @override
  State<RaftRuntimeDetectionNotice> createState() =>
      _RaftRuntimeDetectionNoticeState();
}

enum _Rescan { idle, running, forbidden, failed }

class _RaftRuntimeDetectionNoticeState
    extends State<RaftRuntimeDetectionNotice> {
  // ignore: raft_lints/avoid_imperative_notice_state -- The outcome of the one button on this notice: cleared when the next rescan starts, and the state is dropped with the notice.
  _Rescan state = _Rescan.idle;

  Future<void> _rescan() async {
    setState(() => state = _Rescan.running);
    var next = _Rescan.idle;
    try {
      await widget.rescan();
    } on RaftRuntimeRescanFailure catch (e) {
      next = e.forbidden ? _Rescan.forbidden : _Rescan.failed;
    } catch (_) {
      next = _Rescan.failed;
    }
    // Never written after unmount (Web useRuntimeRescan).
    if (mounted) setState(() => state = next);
  }

  String _reason(BuildContext context) => raftText(
    context,
    switch (widget.detection.reason) {
      RaftRuntimeDetectionReason.deadline => 'timed out',
      RaftRuntimeDetectionReason.childFailed => 'the detection process failed',
      RaftRuntimeDetectionReason.cancelled => 'it was cancelled',
    },
  );

  String _message(BuildContext context) {
    final d = widget.detection;
    if (d.status == RaftRuntimeDetectionStatus.pending) {
      return raftText(
        context,
        'Detecting runtimes… the list below is the last confirmed one.',
      );
    }
    return d.unfinishedLabels.isEmpty
        ? raftFormat(
            context,
            'Runtime detection did not finish ({reason}). The list below is the last confirmed one.',
            {'reason': _reason(context)},
          )
        : raftFormat(
            context,
            'Runtime detection did not finish ({reason}). Not checked: {runtimes}. Their last known state is shown.',
            {
              'reason': _reason(context),
              'runtimes': d.unfinishedLabels.join(', '),
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final note = RaftTypography.body(
      t,
      size: 12,
      line: 20,
      color: raftPanelInk(t, .6, t.colors['foreground-muted']!),
    );
    final incomplete =
        widget.detection.status == RaftRuntimeDetectionStatus.incomplete;
    return Wrap(
      key: const ValueKey('machine-runtime-detection'),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (widget.detection.status == RaftRuntimeDetectionStatus.pending)
          const SizedBox.square(dimension: 16, child: RaftSpinner(size: 16)),
        Text(_message(context), style: note),
        if (incomplete && widget.canRescan)
          RaftRecipeButton(
            key: const ValueKey('machine-runtime-detection-rescan'),
            label: raftText(
              context,
              state == _Rescan.running ? 'Rescanning…' : 'Rescan runtimes',
            ),
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStep: (12, 16),
            disabled: state == _Rescan.running,
            onPressed: _rescan,
          ),
        if (incomplete && !widget.canRescan)
          Text(
            raftText(
              context,
              "Ask the Computer's creator or someone with the Edit Machines capability to rescan.",
            ),
            key: const ValueKey('machine-runtime-detection-rescan-hint'),
            style: note,
          ),
        if (state == _Rescan.forbidden || state == _Rescan.failed)
          Text(
            raftText(
              context,
              state == _Rescan.forbidden
                  ? 'Rescan was refused: only the Computer\'s creator or someone with the Edit Machines capability can rescan.'
                  : 'Rescan request failed. Check the Computer is online and try again.',
            ),
            key: const ValueKey('machine-runtime-detection-rescan-error'),
            style: note.copyWith(color: t.product.brutalOrange),
          ),
      ],
    );
  }
}
