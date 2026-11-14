// A message's Artifact links: the cards under it and where a click opens.
//
// Source: packages/shared/src/appLinkPreview.ts (`messageVisibleLinks`) and
// packages/web/src/apps/artifacts/{ArtifactMessageRefs.tsx,
// artifactSource.ts (`useArtifactLinkSummaries`)} at v1.24.0-source.1: every
// visible http(s) link of the text, bare or with words, once each in order
// (code and image destinations don't count); those on the app hosts that
// name an Artifact get a card, from one object-summaries read per message.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/workspace_controller.dart';
import 'artifact_message_card.dart';
import 'artifact_models.dart';
import 'artifact_session.dart';
import 'artifact_viewer_page.dart';

final _fence = RegExp(r'(^|\n)(```|~~~)[\s\S]*?(\n\2|$)');
final _inlineCode = RegExp(r'`[^`\n]*`');
final _image = RegExp(r'!\[[^\]]*\]\([^)]*\)');
final _markdownLink = RegExp(
  r'\[[^\]]*\]\((https?://[^)\s]+)(?:\s+"[^"]*")?\)',
);
final _autolink = RegExp(r'<(https?://[^>\s]+)>');
final _bare = RegExp(r'https?://[^\s<>()\[\]"`]+', caseSensitive: false);

/// Every visible http(s) link of [content], once each, in message order
/// (Web `messageVisibleLinks`, without its full Markdown parse: fenced and
/// inline code and image destinations are left out).
List<String> artifactVisibleLinks(String content) {
  var text = content.replaceAllMapped(_fence, (m) => ' ' * m[0]!.length);
  text = text.replaceAllMapped(_inlineCode, (m) => ' ' * m[0]!.length);
  text = text.replaceAllMapped(_image, (m) => ' ' * m[0]!.length);
  final found = <({int at, String href})>[];
  for (final m in _markdownLink.allMatches(text)) {
    found.add((at: m.start, href: m[1]!));
  }
  for (final m in _autolink.allMatches(text)) {
    found.add((at: m.start, href: m[1]!));
  }
  // A bare address outside the links already read.
  final taken = [
    for (final m in [
      ..._markdownLink.allMatches(text),
      ..._autolink.allMatches(text),
    ])
      (m.start, m.end),
  ];
  for (final m in _bare.allMatches(text)) {
    if (taken.any((span) => m.start >= span.$1 && m.start < span.$2)) continue;
    var href = m[0]!;
    // Trailing punctuation closes the sentence, not the address.
    href = href.replaceFirst(RegExp(r'[.,;:!?]+$'), '');
    found.add((at: m.start, href: href));
  }
  found.sort((a, b) => a.at.compareTo(b.at));
  final seen = <String>{};
  return [
    for (final link in found)
      if (seen.add(link.href)) link.href,
  ];
}

/// A cheap first look: could [content] link to a workspace Artifact at all
/// (an `/artifacts/` path or an Artifact content host)? Messages without one
/// keep their body alone, with no listener.
bool mayLinkArtifacts(String content) =>
    content.contains('/artifacts/') ||
    content.contains('artifacts.raft.build') ||
    content.contains('.raftusercontent.com');

/// The Artifact cards under one message (none with the flag off).
class ArtifactLinkCards extends StatefulWidget {
  const ArtifactLinkCards({
    super.key,
    required this.controller,
    required this.content,
  });

  final WorkspaceController controller;
  final String content;

  @override
  State<ArtifactLinkCards> createState() => _ArtifactLinkCardsState();
}

class _ArtifactLinkCardsState extends State<ArtifactLinkCards> {
  late ArtifactSession session = ArtifactSession.of(widget.controller);

  @override
  void initState() {
    super.initState();
    session.addListener(_changed);
  }

  @override
  void didUpdateWidget(ArtifactLinkCards old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      session.removeListener(_changed);
      session = ArtifactSession.of(widget.controller)..addListener(_changed);
    }
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!session.enabled) return const SizedBox.shrink();
    final targets = <ArtifactLinkTarget>[
      for (final href in artifactVisibleLinks(widget.content))
        ?session.linkTarget(href),
    ];
    if (targets.isEmpty) return const SizedBox.shrink();
    final states = [
      for (final target in targets) session.summaries.stateOf(target),
    ];
    final w = widget.controller;
    return ArtifactMessageRefs(
      links: states,
      serverName: w.server?.name,
      onOpen: (target, card) =>
          unawaited(openWorkspaceArtifact(context, w, target, seed: card)),
      onOpenInBrowser: (card) {
        final uri = Uri.tryParse(card.url);
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        }
      },
    );
  }
}

/// Opens [href] in the Artifact viewer when it names a workspace Artifact
/// here (and the flag is on); false leaves it to the caller.
bool openArtifactMessageLink(
  BuildContext context,
  WorkspaceController w,
  String href,
) {
  final session = ArtifactSession.of(w);
  final target = session.linkTarget(href);
  if (target == null) return false;
  final state = session.summaries.stateOf(target);
  unawaited(
    openWorkspaceArtifact(
      context,
      w,
      target,
      seed: state is ArtifactLinkOk ? state.card : null,
    ),
  );
  return true;
}
