// Web QuotedMessageCard (components/ui/cards/QuotedMessageCard.tsx) with its
// PreviewShell skin, and the permalink preview's loading skeleton.
import 'hover_region.dart';

import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import 'markdown_autolink.dart';
import 'raft_underline.dart';
import 'flex_shrink_row.dart';
import 'icons.dart';
import 'indicators.dart';
import 'message_row_recipe.dart' show RaftBodyTrailingBleed;
import 'localization.dart';
import 'theme.dart';

/// `InlineMarkdownPreview`: every markdown construct flattened inline (links
/// coloured and underlined, code monospaced, line breaks and list items
/// separated by a space) so a line clamp measures what is visible.
InlineSpan raftInlineMarkdownSpan(
  String source,
  TextStyle base, {
  required Color linkColor,
  required TextStyle code,
}) {
  final nodes = raftFlattenNestedLinks(
    md.Document(
      inlineSyntaxes: [RaftBareUrlSyntax()],
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parseLines(source.replaceAll('\r\n', '\n').split('\n')),
  );
  List<InlineSpan> walk(List<md.Node> list, TextStyle style) => [
    for (final node in list)
      if (node is md.Text)
        TextSpan(text: node.text, style: style)
      else if (node is md.Element)
        ...switch (node.tag) {
          'strong' => walk(
            node.children ?? const [],
            style.copyWith(fontWeight: FontWeight.w700),
          ),
          'em' => walk(
            node.children ?? const [],
            style.copyWith(fontStyle: FontStyle.italic),
          ),
          'del' => walk(
            node.children ?? const [],
            style.copyWith(decoration: TextDecoration.lineThrough),
          ),
          'a' => [
            RaftUnderlineSpan(
              style: style.copyWith(color: linkColor),
              children: walk(
                node.children ?? const [],
                style.copyWith(color: linkColor),
              ),
            ),
          ],
          'code' => [TextSpan(text: node.textContent, style: code)],
          'pre' => [
            TextSpan(
              text: node.textContent.trimRight(),
              style: code.copyWith(color: style.color),
            ),
          ],
          'br' || 'hr' => [TextSpan(text: ' ', style: style)],
          'li' || 'th' || 'td' => [
            ...walk(node.children ?? const [], style),
            TextSpan(text: ' ', style: style),
          ],
          'img' => [TextSpan(text: node.attributes['alt'] ?? '', style: style)],
          _ => walk(node.children ?? const [], style),
        },
  ];
  // Soft line breaks (remark-breaks) read as a space.
  return TextSpan(children: walk(nodes, base));
}

/// The compact card a Raft permalink in a message expands into.
/// Places a quoted-message preview under its message body (Web: the card's
/// `mt-1.5` wrapper inside MessageItem).
class RaftQuotedMessageSlot extends StatelessWidget {
  const RaftQuotedMessageSlot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: RaftBodyTrailingBleed(child: child),
  );
}

class RaftQuotedMessageCard extends StatefulWidget {
  const RaftQuotedMessageCard({
    super.key,
    required this.channelName,
    required this.timestamp,
    required this.authorName,
    required this.avatar,
    required this.content,
    this.isDm = false,
    this.isThread = false,
    this.isArchived = false,
    this.authorSubtitle,
    this.attachmentLabel,
    this.onTap,
  });
  final String channelName, timestamp, authorName, content;
  final Widget avatar;
  final bool isDm, isThread, isArchived;
  final String? authorSubtitle, attachmentLabel;
  final VoidCallback? onTap;

  @override
  State<RaftQuotedMessageCard> createState() => _RaftQuotedMessageCardState();
}

class _RaftQuotedMessageCardState extends State<RaftQuotedMessageCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final hint = t.colors['foreground-hint']!;
    final placeholder = t.colors['foreground-placeholder']!;
    TextStyle style({
      required double size,
      required double line,
      required FontWeight weight,
      required Color color,
      bool mono = false,
      bool tabular = false,
    }) => TextStyle(
      fontFamily: mono ? t.monoFont : t.headingFont,
      fontFamilyFallback: t.fontFallback,
      fontSize: size,
      height: line / size,
      fontWeight: weight,
      color: color,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      letterSpacing: 0,
    );
    final channel = style(
      size: 11,
      line: 16,
      weight: FontWeight.w500,
      color: placeholder,
    );
    final channelBold = channel.copyWith(
      fontWeight: FontWeight.w700,
      color: t.strong,
    );
    // `text-xs leading-none` row text; the author name / meta overrides.
    final name = style(
      size: 12,
      line: 12,
      weight: FontWeight.w500,
      color: t.ink,
    ).copyWith(fontWeight: FontWeight.w700, color: t.strong);
    final meta = style(
      size: 11,
      line: 16,
      weight: FontWeight.w400,
      color: t.muted,
      mono: true,
    ).copyWith(color: hint);
    final stamp =
        style(
          size: 11,
          line: 16,
          weight: FontWeight.w400,
          color: placeholder,
          mono: false,
          tabular: true,
        ).copyWith(
          fontSize: 10,
          // `text-[10px]`: Brutal resolves 1.4286 (14.29px); Elegant inherits the
          // content's `leading-5.25` (21px), which also sets the header height.
          height: 2.1,
          color: hint,
          fontFamily: t.monoFont,
        );
    // TSX `text-xs leading-snug text-foreground-strong sm:text-[13px]`.
    final text = style(
      size: wide ? 13 : 12,
      line: (wide ? 13 : 12) * 1.375,
      weight: FontWeight.w400,
      color: t.strong,
    );
    final borderColor = t.colors[hovered ? 'line-strong' : 'line-muted']!;
    final surface = (hovered ? t.colors['fill-muted']! : t.panel);
    final dot = Text('·', style: channel.copyWith(color: hint));
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  if (!widget.isDm)
                    RaftIcon(RaftGlyph.hash, size: 11, color: t.strong),
                  Text(
                    widget.isDm ? '@${widget.channelName}' : widget.channelName,
                    style: channelBold,
                  ),
                ],
              ),
              dot,
              // `inline-flex min-w-0 items-center gap-1.5`: name and meta
              // shrink in proportion to their width.
              RaftFlexShrinkRow(
                gap: 6,
                truncating: true,
                fixed: const {0},
                children: [
                  widget.avatar,
                  Text(
                    widget.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: name,
                  ),
                  if (widget.authorSubtitle != null)
                    Text(
                      widget.authorSubtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                ],
              ),
              if (widget.isThread) ...[
                dot,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    RaftIcon(
                      RaftGlyph.messageSquare,
                      size: 10,
                      color: t.colors['accent-strong'],
                    ),
                    Text(
                      raftTextZh(context, 'Thread', '消息列'),
                      style: channel.copyWith(
                        fontWeight: FontWeight.w700,
                        color: t.colors['accent-strong'],
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.isArchived) ...[
                dot,
                RaftBadge(
                  label: raftText(context, 'Archived'),
                  appearance: RaftBadgeRecipeAppearance.soft,
                  variant: RaftBadgeRecipeVariant.warning,
                ),
              ],
            ],
          ),
        ),
        Text(widget.timestamp, style: stamp),
      ],
    );
    final body = RaftUnderlines(
      child: Text.rich(
        raftInlineMarkdownSpan(
          widget.content,
          text,
          linkColor: t.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
          code: text.copyWith(fontFamily: t.monoFont),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final attachment = widget.attachmentLabel == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.dark ? t.colors['fill-muted'] : t.panel,
                  border: Border.all(color: t.colors['line-muted']!, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                // `<Tag className="font-mono text-[10px] font-bold">` inside.
                child: RaftBadge(
                  label: widget.attachmentLabel!,
                  appearance: RaftBadgeRecipeAppearance.soft,
                  variant: RaftBadgeRecipeVariant.muted,
                  fontFamily: t.monoFont,
                ),
              ),
            ),
          );
    final headerBox = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: header,
    );
    final contentBox = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.colors['line-muted']!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [body, ?attachment],
      ),
    );
    return RaftHoverRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        container: true,
        child: GestureDetector(
          key: const Key('quoted-message-card'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 12 : 10,
              vertical: wide ? 10 : 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headerBox,
                SizedBox(height: wide ? 6 : 4),
                contentBox,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `animate-pulse border-2 border-black bg-white` loading skeleton (both
/// themes): header bar, avatar square and three text bars, 2s opacity pulse.
class RaftQuotedMessageSkeleton extends StatefulWidget {
  const RaftQuotedMessageSkeleton({super.key});
  @override
  State<RaftQuotedMessageSkeleton> createState() =>
      _RaftQuotedMessageSkeletonState();
}

class _RaftQuotedMessageSkeletonState extends State<RaftQuotedMessageSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion shows the static skeleton and keeps no ticker alive.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      pulse
        ..stop()
        ..value = 0;
    } else if (!pulse.isAnimating) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Loop driven by an AnimationController whose vsync is this State, so TickerMode (hidden routes, offstage tabs, folded panels) mutes it, it is disposed with the widget, and reduced motion stops it.
      pulse.repeat();
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double? width) => Container(
      width: width,
      height: 12,
      color: Colors.black.withValues(alpha: .1),
    );
    final card = Container(
      key: const Key('quoted-message-skeleton'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .6),
              border: const Border(
                bottom: BorderSide(color: Colors.black, width: 2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .05),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      bar(128),
                      bar(null),
                      FractionallySizedBox(widthFactor: .75, child: bar(null)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    // Tailwind `animate-pulse`: opacity 1 -> .5 -> 1, cubic-bezier(.4,0,.6,1).
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) return card;
    return RepaintBoundary(
      child: FadeTransition(
        opacity: TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 1.0,
              end: .5,
            ).chain(CurveTween(curve: const Cubic(.4, 0, .6, 1))),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: .5,
              end: 1.0,
            ).chain(CurveTween(curve: const Cubic(.4, 0, .6, 1))),
            weight: 50,
          ),
        ]).animate(pulse),
        child: card,
      ),
    );
  }
}
