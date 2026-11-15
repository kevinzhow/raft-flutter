import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a hint link outside the app (the system browser).
typedef RuntimeFormLinkOpener = FutureOr<void> Function(Uri uri);

Future<void> openRuntimeFormLink(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// The hint as plain text, links reduced to their text: what a look without
/// link support prints, and what assistive text reads before the links.
String runtimeFormHintPlain(String hint) =>
    parseRuntimeFormHint(hint).map((part) => part.text).join();

/// Whether [hint] carries at least one usable https link.
bool runtimeFormHintHasLinks(String hint) =>
    parseRuntimeFormHint(hint).any((part) => part.href != null);

/// A hint with its inline https Markdown links as external links (Web
/// `RuntimeFormV2HintText`): the link text in the strong link variant, then
/// the leaves-Raft mark; "(opens in a new tab)" is read with the link.
class RuntimeFormHintText extends StatelessWidget {
  const RuntimeFormHintText({
    super.key,
    required this.hint,
    required this.style,
    this.open = openRuntimeFormLink,
  });
  final String hint;
  final TextStyle style;
  final RuntimeFormLinkOpener open;

  @override
  Widget build(BuildContext context) {
    // The mark is 0.857em of the surrounding text (Web `TextLinkExternalIcon`).
    final markSize = (style.fontSize ?? RaftTypeScale.caption.fontSize) * .857;
    final spans = <InlineSpan>[];
    for (final part in parseRuntimeFormHint(hint)) {
      final href = part.href;
      if (href == null) {
        spans.add(TextSpan(text: raftText(context, part.text)));
        continue;
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: RaftSpace.half,
            children: [
              Semantics(
                link: true,
                linkUrl: Uri.parse(href),
                label:
                    '${part.text} ${raftText(context, '(opens in a new tab)')}',
                excludeSemantics: true,
                child: RaftTextLink(
                  label: part.text,
                  variant: RaftTextLinkVariant.strong,
                  scale: RaftTypeScale.caption,
                  onPressed: () =>
                      unawaited(Future.sync(() => open(Uri.parse(href)))),
                ),
              ),
              // The leaves-Raft mark (Web `TextLinkExternalIcon`).
              ExcludeSemantics(
                child: RaftIcon(
                  RaftGlyph.arrowUpRight,
                  size: markSize,
                  color: style.color,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
