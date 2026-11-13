import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifacts/artifact_frame_bridge.dart';
import 'package:raft_flutter/features/artifacts/artifact_open_in_browser.dart';
import 'package:raft_ui/raft_ui.dart';

/// WP-ART0 spike: where the app has no WebView for Artifact frames (Linux, Windows), the page
/// opens Raft Web's own page for the Artifact in the browser.
void main() {
  testWidgets('Open in browser opens Raft Web\'s page for the Artifact', (
    tester,
  ) async {
    final opened = <Uri>[];
    final page = Uri.parse(
      'https://app.example/artifacts/U5YUUwNcK8gqGo5mEh76Ms',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: ArtifactOpenInBrowser(
          title: 'probe',
          pageUrl: page,
          open: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    expect(find.text('probe'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('artifact-open-in-browser')));
    await tester.pump();
    expect(opened, [page]);
  });

  test('Linux and Windows take the browser path', () {
    for (final os in ['linux', 'windows']) {
      expect(artifactFrameSupportFor(os), ArtifactFrameSupport.browser);
    }
  });

  test('page theme: the app\'s Raft tokens as --raft-* colours', () {
    final theme = artifactPageTheme({
      'layer-canvas': const Color(0xFF1B1B19),
      'foreground-muted': const Color(0x80FFFFFF),
      'unrelated': const Color(0xFF000000),
    });
    expect(theme, {
      '--raft-layer-canvas': 'rgb(27, 27, 25)',
      '--raft-foreground-muted': 'rgba(255, 255, 255, 0.502)',
    });
  });
}
