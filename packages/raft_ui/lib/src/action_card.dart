import 'package:flutter/material.dart';

import 'components.dart';
import 'localization.dart';
import 'theme.dart';
import 'icons.dart';
import 'rich_card_tokens.dart';

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
    final recipe = ActionSnapshotRecipe(t);
    return SizedBox(width: double.infinity, child: Padding(padding: EdgeInsets.only(top: recipe.topGap), child: DecoratedBox(
      decoration: BoxDecoration(color: recipe.background, border: Border.fromBorderSide(recipe.border)),
      child: Padding(padding: recipe.inset + EdgeInsets.all(recipe.border.width), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(title, style: recipe.title)),
            if (done) ...[
              const SizedBox(width: 8),
              Semantics(label: raftText(context, 'Done'), child: Container(
                key: const ValueKey('action-success-badge'),
                height: recipe.badgeHeight, padding: recipe.badgeInset,
                decoration: recipe.badgeDecoration,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  RaftIcon(RaftGlyph.check, size: 10, color: recipe.badge.color),
                  SizedBox(width: recipe.badgeGap),
                  Text(t.brutal ? raftText(context, 'Done').toUpperCase() : raftText(context, 'Done'), style: recipe.badge),
                ]),
              )),
            ],
          ]),
          for (final d in details)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(TextSpan(style: recipe.summary, children: [
                TextSpan(text: '${raftText(context, d.label)}: '),
                TextSpan(text: d.value, style: recipe.detailValue),
              ])),
            ),
          if (targetServer != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                raftFormat(context, 'Acts on {server}', {
                  'server': targetServer!,
                }),
              ),
            ),
          if (hint != null && hint!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border(left: recipe.hintBorder)),
                child: Padding(padding: EdgeInsets.only(left: recipe.hintInset), child: Text(hint!, style: recipe.hint)),
              ),
            ),
          if (done && completedBy != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Builder(builder: (context) {
                final template = raftFormat(context, 'Committed by {name}', {'name': '\uFFFC'});
                final parts = template.split('\uFFFC');
                return Text.rich(TextSpan(style: recipe.committed, children: [
                  TextSpan(text: parts.first),
                  TextSpan(text: completedBy!, style: recipe.committedName),
                  if (parts.length > 1) TextSpan(text: parts.sublist(1).join('\uFFFC')),
                ]));
              }),
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
                style: recipe.summary,
              ),
            ),
        ],
      )),
    )));
  }
}
