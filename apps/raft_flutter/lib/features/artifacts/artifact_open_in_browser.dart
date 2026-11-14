// Where the app frames no Artifact (Linux and Windows always, macOS while
// semantics are on, a server whose content domain the app doesn't know), an
// Artifact's page opens in the browser: Raft Web's own page for it
// (`/artifacts/<short id>`, shared artifactPagePath), where the reader signs
// in as on the Web and gets every capability (comments, find, files). Web
// `artifacts.page.hostOpenInBrowser`.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

class ArtifactOpenInBrowser extends StatelessWidget {
  const ArtifactOpenInBrowser({
    super.key,
    required this.title,
    required this.pageUrl,
    required this.open,
  });

  final String title;

  /// Raft Web's page for the Artifact (the server's `url` for it).
  final Uri pageUrl;
  final Future<bool> Function(Uri) open;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: RaftTokens.of(context).panel,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(RaftSpace.x6),
        child: RaftEmptyState(
          glyph: RaftGlyph.arrowUpRight,
          title: title,
          detail: '',
          action: RaftButton(
            key: const ValueKey('artifact-open-in-browser'),
            label: raftText(context, 'Open in browser'),
            glyph: RaftGlyph.arrowUpRight,
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.md,
            onPressed: () => open(pageUrl),
          ),
        ),
      ),
    ),
  );
}
