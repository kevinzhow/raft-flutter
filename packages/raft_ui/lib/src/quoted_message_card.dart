// Web QuotedMessageCard (components/ui/cards/QuotedMessageCard.tsx) with its
// PreviewShell skin, and the permalink preview's loading skeleton.

import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import 'markdown_autolink.dart';
import 'markdown_cjk_emphasis.dart';
import 'raft_underline.dart';
import 'message_row_recipe.dart' show RaftBodyTrailingBleed;
import 'quoted_message_card_raft.dart';

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
      inlineSyntaxes: [...raftCjkEmphasisSyntaxes(), RaftBareUrlSyntax()],
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

class RaftQuotedMessageCard extends StatelessWidget {
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
    this.authorDelegatedBy,
    this.unavailableText,
    this.attachmentLabel,
    this.notice,
    this.onTap,
  });
  final String channelName, timestamp, authorName, content;
  final Widget avatar;
  final bool isDm, isThread, isArchived;
  final String? authorSubtitle, attachmentLabel;

  /// RFC 077 "(sent by Friday)" after the quoted author's name.
  final String? authorDelegatedBy;

  /// The quote is one muted line instead (Web `unavailable`: a retracted
  /// message is never quoted with its old words).
  final String? unavailableText;

  /// A line in place of the message text (the header stays), e.g. a message
  /// older than the plan's history window: the card is not tappable then and
  /// its attachments are hidden (Web `notice`).
  final Widget? notice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => RaftQuotedMessageCardRaft(card: this);
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
