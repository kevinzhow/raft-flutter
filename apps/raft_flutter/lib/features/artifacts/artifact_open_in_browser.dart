// WP-ART0 spike: where the app has no WebView (Linux, Windows), an Artifact's page opens in the
// browser: Raft Web's own page for it (`/artifacts/<short id>`, shared artifactPagePath), where
// the reader signs in as on the Web and gets every capability (comments, find, files).
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
    child: RaftEmptyState(
      glyph: RaftGlyph.arrowUpRight,
      title: title,
      // Spike wording; ART1 takes Web's strings (`artifacts.frame.needsTab*`,
      // `artifacts.page.hostOpenInBrowser`).
      detail: 'This device opens Artifact pages in your browser.',
      action: RaftButton(
        key: const ValueKey('artifact-open-in-browser'),
        label: 'Open in browser',
        onPressed: () => open(pageUrl),
      ),
    ),
  );
}
