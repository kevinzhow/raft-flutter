import 'package:flutter/material.dart';

import 'icons.dart';
import 'message_body.dart';
import 'raft/badge.dart';
import 'separator.dart';
import 'raft/button.dart';
import 'raft/ui_tokens.dart';
import 'recipes/badge.g.dart'
    show RaftBadgeRecipeAppearance, RaftBadgeRecipeVariant;
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'tooltip.dart' show RaftTooltip;

// Card messages (Web 1.24 RFC 082, components/message/MessageCardBody.tsx,
// MessageCardElements.tsx, CardElements.tsx): a sender posts a small
// display-only element tree every member sees the same way. The sender picks
// only the structure; spacing, faces and colours are the design system's.
// Every string is text, never markup; a Markdown element is drawn by the
// message renderer. Buttons only leave Raft.

/// A header tag's status tone (RFC 082 §4.8).
enum RaftCardTagTone { neutral, info, success, warning, danger }

/// The card's optional header: a title, a one-line subtitle, up to 3 tags.
@immutable
class RaftCardHeader {
  const RaftCardHeader({
    required this.title,
    this.subtitle,
    this.tags = const [],
  });
  final String title;
  final String? subtitle;
  final List<(String, RaftCardTagTone)> tags;
}

/// One element of a card's tree.
sealed class RaftCardElement {
  const RaftCardElement();
}

class RaftCardStack extends RaftCardElement {
  const RaftCardStack({
    required this.children,
    this.row = false,
    this.wrap = false,
  });
  final List<RaftCardElement> children;
  final bool row, wrap;
}

enum RaftCardTextTone { normal, muted, warning }

class RaftCardText extends RaftCardElement {
  const RaftCardText(
    this.text, {
    this.tone = RaftCardTextTone.normal,
    this.mono = false,
  });
  final String text;
  final RaftCardTextTone tone;
  final bool mono;
}

/// A state in the sender's words: always a neutral soft badge.
class RaftCardBadge extends RaftCardElement {
  const RaftCardBadge(this.text);
  final String text;
}

class RaftCardRelativeTime extends RaftCardElement {
  const RaftCardRelativeTime(this.at);
  final DateTime at;
}

class RaftCardDuration extends RaftCardElement {
  const RaftCardDuration(this.start, [this.end]);
  final DateTime start;
  final DateTime? end;
}

/// A navigate button: drawn in the card's own row, never in the body.
class RaftCardButton extends RaftCardElement {
  const RaftCardButton({
    required this.label,
    required this.url,
    required this.domain,
    this.ghost = false,
    this.disabledReason,
  });
  final String label, url, domain;
  final bool ghost;
  final String? disabledReason;
}

class RaftCardMarkdown extends RaftCardElement {
  const RaftCardMarkdown(this.content);
  final String content;
}

class RaftCardFields extends RaftCardElement {
  const RaftCardFields(this.items);

  /// Label, value, and whether the value is machine-written (`mono`).
  final List<(String, String, bool)> items;
}

class RaftCardDivider extends RaftCardElement {
  const RaftCardDivider();
}

/// Whether [element] draws anything in the card's body: not a button, not
/// a Stack of only buttons.
bool raftCardDrawsSomething(RaftCardElement element) => switch (element) {
  RaftCardButton() => false,
  RaftCardStack(:final children) => children.any(raftCardDrawsSomething),
  _ => true,
};

bool _isBlock(RaftCardElement element) => switch (element) {
  RaftCardMarkdown() || RaftCardFields() || RaftCardDivider() => true,
  RaftCardStack(:final children) => children.any(_isBlock),
  _ => false,
};

/// The card's buttons in tree order.
List<RaftCardButton> raftCardButtons(RaftCardElement root) => [
  if (root is RaftCardButton) root,
  if (root is RaftCardStack)
    for (final child in root.children) ...raftCardButtons(child),
];

/// A card message's card in the message body, under the sender's name.
class RaftMessageCard extends StatelessWidget {
  const RaftMessageCard({
    super.key,
    required this.root,
    this.header,
    this.updated,
    required this.relativeTime,
    required this.duration,
    this.onOpen,
  });
  final RaftCardHeader? header;
  final RaftCardElement root;

  /// "Updated 3 minutes ago" once the card was replaced (revision > 1).
  final String? updated;

  /// "5 minutes ago" for a time; how long a [RaftCardDuration] took.
  final String Function(DateTime at) relativeTime;
  final String Function(DateTime start, DateTime? end) duration;

  /// Opens a button's address (it always leaves Raft).
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final buttons = raftCardButtons(root);
    final elements = raftCardDrawsSomething(root);
    final radius = t.size('radius.container', fallback: 10);
    final header = this.header;
    return Padding(
      // `my-1`.
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        // MessageEmbed size item: `max-w-[400px] max-md:max-w-none`.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width < 768
              ? double.infinity
              : 400,
        ),
        child: DecoratedBox(
          key: const ValueKey('message-card'),
          decoration: BoxDecoration(
            color: ui.layerCard,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: ui.lineHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (header != null) _Header(header),
              if (elements || buttons.isNotEmpty || header == null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    header == null ? 12 : 0,
                    12,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (elements) _node(context, root, inRow: false),
                      if (elements && buttons.isNotEmpty)
                        const SizedBox(height: 12),
                      if (buttons.isNotEmpty)
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (i, button) in buttons.indexed)
                              _ButtonLink(
                                button: button,
                                // The domain once per address: on the last
                                // button that opens it.
                                showDomain: !buttons
                                    .skip(i + 1)
                                    .any(
                                      (later) =>
                                          later.disabledReason == null &&
                                          button.disabledReason == null &&
                                          later.url == button.url,
                                    ),
                                onOpen: onOpen,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              if (updated != null)
                Container(
                  key: const ValueKey('message-card-updated'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: ui.lineHairline)),
                  ),
                  child: Text(
                    updated!,
                    style: t.scale(
                      RaftTypeScale.caption,
                      color: ui.foregroundHint,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _node(
    BuildContext context,
    RaftCardElement element, {
    required bool inRow,
  }) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final muted = t.scale(RaftTypeScale.monoMeta, color: ui.foregroundMuted);
    switch (element) {
      case RaftCardStack(:final children, :final row, :final wrap):
        final shown = children.where(raftCardDrawsSomething).toList();
        if (shown.isEmpty) return const SizedBox.shrink();
        if (!row)
          return _column([
            for (final c in shown) _node(context, c, inRow: false),
          ]);
        // A Markdown, Fields or Divider in a row is a block of its own.
        final segments = <List<RaftCardElement>>[];
        bool? lastBlock;
        for (final child in shown) {
          final block = _isBlock(child);
          if (!block && lastBlock == false) {
            segments.last.add(child);
          } else {
            segments.add([child]);
          }
          lastBlock = block;
        }
        final drawn = [
          for (final segment in segments)
            _isBlock(segment.first)
                ? _node(context, segment.first, inRow: false)
                : _row(context, segment, wrap: wrap),
        ];
        return drawn.length == 1 ? drawn.first : _column(drawn);
      case RaftCardText(:final text, :final tone, :final mono):
        final color = switch (tone) {
          RaftCardTextTone.muted => ui.foregroundMuted,
          RaftCardTextTone.warning => t.colors['warning-strong'] ?? ui.warning,
          RaftCardTextTone.normal => ui.foreground,
        };
        return Text(
          text,
          maxLines: inRow ? 1 : null,
          softWrap: !inRow,
          overflow: inRow ? TextOverflow.ellipsis : TextOverflow.clip,
          style: mono
              ? t.scale(RaftTypeScale.monoMeta, color: color)
              : t.scale(RaftTypeScale.callout, color: color),
        );
      case RaftCardBadge(:final text):
        final badge = RaftBadge(
          label: text,
          appearance: RaftBadgeRecipeAppearance.soft,
        );
        return inRow
            ? badge
            : Align(alignment: Alignment.centerLeft, child: badge);
      case RaftCardRelativeTime(:final at):
        return Text(relativeTime(at), style: muted);
      case RaftCardDuration(:final start, :final end):
        return Text(duration(start, end), style: muted);
      case RaftCardButton():
        return const SizedBox.shrink();
      case RaftCardMarkdown(:final content):
        return RaftMessageBody(
          key: const ValueKey('message-card-markdown'),
          content: content,
          // `text-sm leading-5`: the callout size.
          fontSize: RaftTypeScale.callout.fontSize,
          lineHeight: RaftTypeScale.callout.lineHeight,
          onLink: onOpen,
        );
      case RaftCardFields(:final items):
        return _Fields(items);
      case RaftCardDivider():
        return RaftSeparator(color: ui.lineHairline);
    }
  }

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, child) in children.indexed) ...[
        if (i > 0) const SizedBox(height: 6),
        child,
      ],
    ],
  );

  /// One line of a row: its elements, a "·" between two that are not the
  /// state chip (DS PreviewCard › Item card).
  Widget _row(
    BuildContext context,
    List<RaftCardElement> elements, {
    required bool wrap,
  }) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final parts = <Widget>[];
    for (final (i, element) in elements.indexed) {
      if (i > 0 &&
          elements[i - 1] is! RaftCardBadge &&
          element is! RaftCardBadge) {
        parts.add(
          ExcludeSemantics(
            child: Text(
              '·',
              style: t.scale(RaftTypeScale.callout, color: ui.foregroundMuted),
            ),
          ),
        );
      }
      parts.add(_node(context, element, inRow: true));
    }
    return DefaultTextStyle.merge(
      style: t.scale(RaftTypeScale.callout, color: ui.foregroundMuted),
      child: wrap
          ? Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: parts,
            )
          : Row(
              children: [
                for (final (i, part) in parts.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Flexible(child: part),
                ],
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.header);
  final RaftCardHeader header;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    return Padding(
      key: const ValueKey('message-card-header'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            header.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t
                .scale(RaftTypeScale.subhead, color: ui.foreground)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          if (header.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              header.subtitle!,
              style: t.scale(RaftTypeScale.callout, color: ui.foregroundMuted),
            ),
          ],
          if (header.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (text, tone) in header.tags)
                  RaftBadge(
                    label: text,
                    appearance: RaftBadgeRecipeAppearance.soft,
                    variant: switch (tone) {
                      RaftCardTagTone.neutral =>
                        RaftBadgeRecipeVariant.default_,
                      RaftCardTagTone.info =>
                        RaftBadgeRecipeVariant.information,
                      RaftCardTagTone.success => RaftBadgeRecipeVariant.success,
                      RaftCardTagTone.warning => RaftBadgeRecipeVariant.warning,
                      RaftCardTagTone.danger => RaftBadgeRecipeVariant.danger,
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Fields: the label muted on the left, the value on the right; once a value
/// does not fit beside its label every label sits above its value. Values
/// wrap, never truncate.
class _Fields extends StatelessWidget {
  const _Fields(this.items);
  final List<(String, String, bool)> items;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final label = t.scale(RaftTypeScale.callout, color: ui.foregroundMuted);
    final value = t.scale(RaftTypeScale.callout, color: ui.foreground);
    final mono = t.scale(RaftTypeScale.monoCode, color: ui.foreground);
    return LayoutBuilder(
      key: const ValueKey('message-card-fields'),
      builder: (context, constraints) {
        // Labels take up to a third of the line beside their values.
        final stacked = constraints.maxWidth < 240;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (term, details, isMono)) in items.indexed) ...[
              if (i > 0) const SizedBox(height: 6),
              if (stacked) ...[
                Text(term, style: label),
                Text(details, style: isMono ? mono : value),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth / 3,
                      ),
                      child: Text(term, style: label),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        details,
                        textAlign: TextAlign.end,
                        style: isMono ? mono : value,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        );
      },
    );
  }
}

/// A card button: a link that leaves Raft, never an action. Its label, its
/// domain (once per address) and ↗. A disabled one gives its reason as its
/// tooltip and opens nothing.
class _ButtonLink extends StatelessWidget {
  const _ButtonLink({
    required this.button,
    required this.showDomain,
    required this.onOpen,
  });
  final RaftCardButton button;
  final bool showDomain;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final variant = button.ghost
        ? RaftButtonVariant.ghost
        : RaftButtonVariant.standard;
    final reason = button.disabledReason;
    if (reason != null) {
      return RaftTooltip(
        message: reason,
        child: Semantics(
          hint: reason,
          child: RaftButton(
            label: button.label,
            uiVariant: variant,
            uiSize: RaftButtonSize.sm,
            disabled: true,
          ),
        ),
      );
    }
    return Semantics(
      link: true,
      label: '${button.label} · ${button.domain}',
      excludeSemantics: true,
      child: RaftButton(
        uiVariant: variant,
        uiSize: RaftButtonSize.sm,
        onPressed: onOpen == null ? null : () => onOpen!(button.url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                button.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showDomain) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  button.domain,
                  key: const ValueKey('message-card-button-domain'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.ui.foregroundMuted),
                ),
              ),
            ],
            const SizedBox(width: 6),
            const RaftIcon(RaftGlyph.arrowUpRight, size: 14),
          ],
        ),
      ),
    );
  }
}
