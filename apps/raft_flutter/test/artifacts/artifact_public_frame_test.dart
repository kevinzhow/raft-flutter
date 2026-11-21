import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifacts/artifact_public_page.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../support/artifact_fake_client.dart';
import '../support/fake_artifact_webview.dart';

void main() {
  setUp(() {
    FakeArtifactWebView.reset();
    WebViewPlatform.instance = FakeArtifactWebView();
    addTearDown(FakeArtifactWebView.reset);
  });

  testWidgets('public frame uses its own anonymous ticket and shared bridge', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (_) async =>
          const StringCodec().encodeMessage('/* frame host fixture */'),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );
    final client = ArtifactFakeClient();
    addTearDown(client.ingress.close);
    const path = '/public/artifacts/$artifactId';
    client.answers['GET $path'] = (_) => {
      'title': 'Roadmap',
      'kind': 'html',
      'version': {'number': 1},
    };
    client.answers['POST $path/frame'] = (_) => artifactFrameJson();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: ArtifactPublicPage(
          client: client,
          id: artifactId,
          onBack: () {},
          onSignIn: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(client.requests, ['GET $path', 'POST $path/frame']);
    expect(FakeArtifactWebView.html, contains('data-bridge-nonce'));
    FakeArtifactWebView.finish('https://app.raft.build');
    await tester.pump();
    expect(FakeArtifactWebView.scripts, contains('/* frame host fixture */'));
    final nonce = RegExp(r'data-bridge-nonce="([^"]+)"')
        .firstMatch(FakeArtifactWebView.html!)!
        .group(1)!;
    FakeArtifactWebView.post(
      jsonEncode({
        'nonce': nonce,
        'type': 'outcome',
        'detail': {'state': 'loaded'},
      }),
    );
    await tester.pump();
    expect(client.requestAuthorization, {
      'GET $path': false,
      'POST $path/frame': false,
    });
    try {
      await tester.tap(find.byKey(const Key('public-artifact-find')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('artifact-find-input')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('artifact-find-input')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}
