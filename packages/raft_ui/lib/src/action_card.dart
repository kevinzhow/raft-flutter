import 'package:flutter/material.dart';

import 'components.dart';
import 'localization.dart';
import 'theme.dart';

/// A safe presentation of server-owned action metadata. Execution and current
/// permissions belong to the application adapter, never this component.
class RaftActionCard extends StatelessWidget {
  const RaftActionCard({
    super.key,
    required this.title,
    required this.state,
    this.details = const [],
    this.hint,
    this.targetServer,
    this.completedBy,
    this.confirmLabel = 'Confirm',
    this.blockedReason,
    this.error,
    this.busy = false,
    this.onConfirm,
  });
  final String title, state, confirmLabel;
  final List<({String label, String value})> details;
  final String? hint, targetServer, completedBy, blockedReason, error;
  final bool busy;
  final VoidCallback? onConfirm;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final done = state == 'executed', frozen = state == 'frozen';
    return RaftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
              ),
              if (done)
                Semantics(
                  label: raftText(context, 'Done'),
                  child: const Icon(Icons.check_circle_outline),
                ),
            ],
          ),
          for (final d in details)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${raftText(context, d.label)}: ${d.value}',
                style: TextStyle(color: t.muted),
              ),
            ),
          if (targetServer != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                raftFormat(context, 'Acts on {server}', {
                  'server': targetServer!,
                }),
              ),
            ),
          if (hint != null && hint!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                hint!,
                style: TextStyle(color: t.muted, fontStyle: FontStyle.italic),
              ),
            ),
          if (done && completedBy != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                raftFormat(context, 'Completed by {name}', {
                  'name': completedBy!,
                }),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!done)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RaftButton(
                label: frozen
                    ? 'Frozen'
                    : state == 'reconfirm_required'
                    ? 'Reconfirm'
                    : confirmLabel,
                busy: busy,
                onPressed: frozen || blockedReason != null ? null : onConfirm,
              ),
            ),
          if (blockedReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                raftText(context, blockedReason!),
                style: TextStyle(color: t.muted),
              ),
            ),
        ],
      ),
    );
  }
}
