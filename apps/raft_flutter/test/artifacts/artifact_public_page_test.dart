import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifacts/artifact_public_page.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../support/artifact_fake_client.dart';
import '../support/fake_artifact_webview.dart';

void main() {
  test('versioned public links select the current view on this deployment', () {
    const origin = 'https://api.raft.build';
    expect(
      publicArtifactRoute(Uri.parse('/artifacts/$artifactShort/v/3'), origin),
      artifactId,
    );
    for (final route in [
      'ftp://app.raft.build/artifacts/$artifactShort',
      '//app.raft.build/artifacts/$artifactShort',
      'https://elsewhere.invalid/artifacts/$artifactShort',
      '/artifacts/$artifactShort/v/0',
    ]) {
      expect(publicArtifactRoute(Uri.parse(route), origin), isNull);
    }
  });

  testWidgets('a signed-out visitor sees public Artifact metadata', (
    tester,
  ) async {
    var signIns = 0;
    final client = ArtifactFakeClient();
    addTearDown(client.ingress.close);
    client.answers['GET /public/artifacts/$artifactId'] = (_) => {
      'id': artifactId,
      'title': 'Public roadmap',
      'kind': 'html',
      'attribution': {'kind': 'raft'},
      'version': {'number': 1, 'updatedAt': '2026-11-19T00:00:00Z'},
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: ArtifactPublicPage(
          client: client,
          id: artifactId,
          onBack: () {},
          onSignIn: () => signIns++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Public roadmap'), findsWidgets);
    expect(find.text('Made with Raft'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    expect(signIns, 1);
    expect(client.requests, ['GET /public/artifacts/$artifactId']);
  });

  testWidgets('public actions open without making an authenticated request', (
    tester,
  ) async {
    final client = ArtifactFakeClient();
    addTearDown(client.ingress.close);
    client.answers['GET /public/artifacts/$artifactId'] = (_) => {
      'title': 'Roadmap',
      'kind': 'html',
      'version': {'number': 1},
    };
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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('public-artifact-more')));
    await tester.pumpAndSettle();
    for (final label in [
      'Copy link',
      'Copy for AI',
      'Open in ChatGPT',
      'Open in Claude',
      'Report abuse',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(client.requests, ['GET /public/artifacts/$artifactId']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a published text file draws through the anonymous file route', (
    tester,
  ) async {
    final client = ArtifactFakeClient();
    addTearDown(client.ingress.close);
    const path = '/public/artifacts/$artifactId';
    client.answers['GET $path'] = (_) => {
      'title': 'Roadmap',
      'kind': 'text',
      'version': {'number': 1},
    };
    client.answers['GET $path/meta'] = (_) => {
      'entry': 'notes/road map.txt',
      'files': [
        {'path': 'notes/road map.txt', 'size': 21},
      ],
    };
    const file = '$path/files/notes/road%20map.txt';
    client.answers['GET $file'] = (_) =>
        Uint8List.fromList(utf8.encode('A published roadmap.'));
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
    await tester.pumpAndSettle();
    expect(find.text('A published roadmap.'), findsOneWidget);
    expect(client.requestAuthorization, {
      'GET $path': false,
      'GET $path/meta': false,
      'GET $file': false,
    });
  });

  testWidgets('public frame uses its own anonymous ticket and shared bridge', (
    tester,
  ) async {
    FakeArtifactWebView.reset();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = FakeArtifactWebView();
    if (previous != null) {
      addTearDown(() => WebViewPlatform.instance = previous);
    }
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
    expect(client.requestAuthorization, {
      'GET $path': false,
      'POST $path/frame': false,
    });
    await tester.pumpWidget(const SizedBox());
  });
}
