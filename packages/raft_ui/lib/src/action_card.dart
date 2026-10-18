import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftTypography;
import 'error_presentation.dart' show RaftErrorBanner;
import 'dialog_card.dart' show RaftRecipeButton;
import 'recipes/button_variants.g.dart';
import 'localization.dart';
import 'space.dart';
import 'theme.dart';
import 'icons.dart';
import 'message_row_recipe.dart' show RaftMessageBodyMargin;
import 'rich_card_tokens.dart';
import 'text_measure.dart';
import 'text_scaling.dart' show RaftScaled;

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
    this.titleParts,
    this.body = const [],
    this.completedResult,
  });

  /// ActionTitleLine: the title as `flex flex-wrap items-center gap-2` items
  /// (text pieces and bold chunks), instead of the single [title] string.
  final List<String>? titleParts;

  /// ActionDetail rows (`mt-1 text-xs text-foreground-muted`, `space-y-0.5`).
  final List<Widget> body;

  /// ResultLink after "Committed by": the `→ ...` produced resource.
  final String? completedResult;
  final String title, state, confirmLabel;
  final List<({String label, String value})> details;
  final String? hint, targetServer, completedBy, blockedReason, error;
  final bool busy;
  final VoidCallback? onConfirm;

  /// ActionTitleLine: `flex flex-wrap items-center gap-2` of the title items
  /// and, when done, the `ml-auto` Done badge (alone on its line when the
  /// items leave no room for it).
  Widget _titleLine(
    BuildContext context,
    List<String> parts,
    Widget? badge,
    ActionSnapshotRecipe recipe,
  ) {
    final style = recipe.title.copyWith(height: 19.25 / 14);
    Widget item(String part) =>
        // `leading-snug` (19.25px) is fractional; a Text would round the line
        // up to 20.
        RaftScaled.lineBox(
          context,
          height: 19.25,
          child: Text(part, style: style),
        );
    Wrap items() => Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [for (final part in parts) item(part)],
    );
    if (badge == null) return items();
    return LayoutBuilder(
      builder: (context, constraints) {
        double width(String text, [TextStyle? textStyle]) =>
            raftTextWidth(TextSpan(text: text, style: textStyle ?? style));
        final used =
            parts.fold<double>(0, (a, p) => a + width(p)) +
            8 * (parts.length - 1);
        final badgeWidth =
            recipe.badgeInset.horizontal +
            2 +
            10 +
            recipe.badgeGap +
            width('DONE', recipe.badge);
        if (used + 8 + badgeWidth <= constraints.maxWidth) {
          return Row(
            spacing: 8,
            children: [
              for (final part in parts) item(part),
              const Spacer(),
              badge,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            items(),
            Align(alignment: Alignment.centerRight, child: badge),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final done = state == 'executed', frozen = state == 'frozen';
    final recipe = ActionSnapshotRecipe(t);
    final badge = Semantics(
      label: raftText(context, 'Done'),
      child: Container(
        key: const ValueKey('action-success-badge'),
        height: recipe.badgeHeight,
        padding: recipe.badgeInset,
        decoration: recipe.badgeDecoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftIcon(RaftGlyph.check, size: 10, color: recipe.badge.color),
            SizedBox(width: recipe.badgeGap),
            Text(
              t.brutal
                  ? raftText(context, 'Done').toUpperCase()
                  : raftText(context, 'Done'),
              style: recipe.badge,
            ),
          ],
        ),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(
          top: RaftMessageBodyMargin.collapse(context, recipe.topGap),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: recipe.background,
            border: Border.fromBorderSide(recipe.border),
          ),
          child: Padding(
            padding: recipe.inset + EdgeInsets.all(recipe.border.width),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titleParts == null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(title, style: recipe.title)),
                      if (done) ...[const SizedBox(width: 8), badge],
                    ],
                  )
                else
                  _titleLine(context, titleParts!, done ? badge : null, recipe),
                if (body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DefaultTextStyle(
                      style: recipe.summary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: 2,
                        children: body,
                      ),
                    ),
                  ),
                for (final d in details)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(
                      TextSpan(
                        style: recipe.summary,
                        children: [
                          TextSpan(text: '${raftText(context, d.label)}: '),
                          TextSpan(text: d.value, style: recipe.detailValue),
                        ],
                      ),
                    ),
                  ),
                if (targetServer != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      raftFormat(context, 'Runs on {server}', {
                        'server': targetServer!,
                      }),
                    ),
                  ),
                if (hint != null && hint!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(left: recipe.hintBorder),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: recipe.hintInset),
                        child: Text(hint!, style: recipe.hint),
                      ),
                    ),
                  ),
                if (done && completedBy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Builder(
                      builder: (context) {
                        final template = raftFormat(
                          context,
                          'Committed by {name}',
                          {'name': '\uFFFC'},
                        );
                        final parts = template.split('\uFFFC');
                        return Text.rich(
                          TextSpan(
                            style: recipe.committed,
                            children: [
                              TextSpan(text: parts.first),
                              TextSpan(
                                text: completedBy!,
                                style: recipe.committedName,
                              ),
                              if (parts.length > 1)
                                TextSpan(text: parts.sublist(1).join('\uFFFC')),
                              if (completedResult != null)
                                TextSpan(
                                  text: ' $completedResult',
                                  style: recipe.committedName,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (error != null)
                  // Web `<Banner intent="warning" density="sm" className="mt-1">`.
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: RaftErrorBanner(error!, small: true),
                  ),
                if (!done)
                  Padding(
                    // `mt-2 flex flex-wrap items-center gap-x-3 gap-y-1`
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RaftRecipeButton(
                          variant: RaftButtonRecipeVariant.accent,
                          size: RaftButtonRecipeSize.sm,
                          label: busy
                              ? '…'
                              : frozen
                              ? 'Frozen'
                              : state == 'reconfirm_required'
                              ? 'Reconfirm'
                              : confirmLabel,
                          disabled: frozen || blockedReason != null,
                          onPressed: busy ? null : onConfirm,
                        ),
                        if (blockedReason != null)
                          Text(
                            raftText(context, blockedReason!),
                            style: recipe.summary,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One ActionDetail row: `<span text-foreground-hint>label</span> <span
/// text-foreground-strong>value</span>`.
class RaftActionField extends StatelessWidget {
  const RaftActionField({
    super.key,
    required this.label,
    this.value,
    this.child,
  });
  final String label;
  final String? value;

  /// A block value (scope list) below the label instead of an inline [value].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = ActionSnapshotRecipe(t);
    final labelStyle = recipe.summary.copyWith(
      color: t.colors['foreground-hint'],
    );
    final label = Text(raftText(context, this.label), style: labelStyle);
    if (child != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [label, child!],
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: raftText(context, this.label), style: labelStyle),
          const TextSpan(text: ' '),
          TextSpan(text: value, style: recipe.detailValue),
        ],
      ),
    );
  }
}

/// A bold notice line inside the summary (`font-bold text-brutal-orange`,
/// `text-amber-700`, `text-foreground-strong`).
class RaftActionNote extends StatelessWidget {
  const RaftActionNote(
    this.text, {
    super.key,
    this.tone = RaftActionTone.strong,
  });
  final String text;
  final RaftActionTone tone;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = ActionSnapshotRecipe(t);
    final color = switch (tone) {
      RaftActionTone.orange => t.colors['color-brutal-orange'],
      RaftActionTone.amber => const Color(0xFFB45309),
      RaftActionTone.strong => t.strong,
      RaftActionTone.hint => t.colors['foreground-hint'],
    };
    return Text(
      raftText(context, text),
      style: recipe.summary.copyWith(
        fontWeight: tone == RaftActionTone.hint ? null : FontWeight.w700,
        color: color,
      ),
    );
  }
}

/// The inbound-scope caveat box in the scope list footer: `border
/// border-line-hairline bg-warning-soft p-[7px]` around a [RaftActionNote].
class RaftActionWarningBox extends StatelessWidget {
  const RaftActionWarningBox(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.colors['warning-soft'],
        border: Border.all(color: t.colors['line-hairline']!),
      ),
      child: Padding(
        // `p-1.5` plus the 1px `border` (a DecoratedBox border takes no layout space).
        padding: const EdgeInsets.all(RaftSpace.x1_5 + RaftSpace.hairline),
        child: RaftActionNote(text),
      ),
    );
  }
}

/// `hint` is the regular-weight `text-foreground-hint` line.
enum RaftActionTone { orange, amber, strong, hint }

/// ActionScopeList: one `border border-line-hairline bg-layer-inset p-1.5`
/// block per visible OAuth scope (mono name + copy), `mt-1 space-y-1.5`.
class RaftActionScopeList extends StatelessWidget {
  const RaftActionScopeList({
    super.key,
    required this.scopes,
    this.footer = const [],
  });
  final List<({String scope, String copy})> scopes;

  /// Trailing blocks (`Will send to`, the inbound-scope warning).
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = ActionSnapshotRecipe(t);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          for (final s in scopes)
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.colors['layer-inset'],
                border: Border.all(color: t.colors['line-hairline']!),
              ),
              child: Padding(
                // `p-1.5` plus the 1px `border` (a DecoratedBox border takes no layout space).
                padding: const EdgeInsets.all(
                  RaftSpace.x1_5 + RaftSpace.hairline,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RaftScaled.lineBox(
                      context,
                      height: 11 * 4 / 3,
                      child: Text(
                        s.scope,
                        style: RaftTypography.mono(
                          t,
                          size: 11,
                          line: 11 * 4 / 3,
                          color: t.muted,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(raftText(context, s.copy), style: recipe.summary),
                  ],
                ),
              ),
            ),
          ...footer,
        ],
      ),
    );
  }
}
