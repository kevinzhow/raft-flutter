import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/artifacts/artifact_frame_bridge.dart';
import 'package:raft_flutter/features/artifacts/artifact_frame_view.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../support/fake_artifact_webview.dart';

/// The production frame host (WP-ART1): the per-page nonce on every host
/// message, WebKit's initial wrapper navigation allowed exactly once, the
/// one automatic reload of an expired view, and the route's codes.
void main() {
  const id = 'pt_db491d86-6156-4fe1-a742-01890ddbfffe';
  const domain = 'artifacts.localhost:18787';
  const content =
      'http://w-db491d86-6156-4fe1-a742-01890ddbfffe.artifacts.localhost:18787';
  final app = Uri.parse('http://localhost:15194');
  Map<String, Object?> location([String ticket = 'a']) => {
    'url': '$content/__porthole/f/x/?ticket=$ticket',
    'origin': content,
    'door': {'url': '$content/__porthole/door?ticket=$ticket'},
  };

  setUp(() {
    FakeArtifactWebView.reset();
    WebViewPlatform.instance = FakeArtifactWebView();
  });

  late List<Uri> opened;
  late int locates;
  late ArtifactFrameController frame;

  Future<void> mount(
    WidgetTester tester, {
    Object? first,
    Future<Object?> Function()? locate,
  }) async {
    opened = [];
    locates = 0;
    frame = ArtifactFrameController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ArtifactFrameView(
          artifactId: id,
          version: 1,
          title: 'probe',
          appOrigin: app,
          contentDomain: domain,
          allowLoopback: true,
          firstLocation: first,
          locate:
              locate ??
              () async {
                locates++;
                return location('n$locates');
              },
          host: ArtifactFrameHost(
            openLink: (uri) async {
              opened.add(uri);
              return true;
            },
            copyText: (_) async => true,
            comments: (_) async => false,
            confirm: (_, _, _) async => true,
          ),
          hostScript: () async => '/* host */',
          controller: frame,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  String nonce() =>
      RegExp(r'data-bridge-nonce="([^"]+)"')
          .firstMatch(FakeArtifactWebView.html!)!
          .group(1)!;

  void send(String type, Object? detail, {String? withNonce}) =>
      FakeArtifactWebView.post(
        jsonEncode({
          'nonce': withNonce ?? nonce(),
          'type': type,
          'detail': detail,
        }),
      );

  testWidgets('the viewer route\'s frame mounts first; the wrapper loads on '
      'the app origin', (tester) async {
    await mount(tester, first: location('viewer'));
    expect(locates, 0, reason: 'the viewer answer\'s tickets are used first');
    expect(FakeArtifactWebView.baseUrl, '$app');
    expect(FakeArtifactWebView.html, contains("frame-src http://*.$domain"));
    expect(frame.status, ArtifactFrameStatus.starting);
    send('ready', {});
    await tester.pump();
    expect(
      FakeArtifactWebView.scripts.last,
      allOf(startsWith('RaftArtifactHost.mount('), contains('ticket=viewer')),
    );
    send('outcome', {'state': 'loaded'});
    await tester.pump();
    expect(frame.status, ArtifactFrameStatus.loaded);
  });

  testWidgets('WebKit\'s initial wrapper navigation passes once; every later '
      'main-frame navigation is refused', (tester) async {
    await mount(tester);
    expect(await FakeArtifactWebView.navigate('$app/'), isTrue);
    expect(
      await FakeArtifactWebView.navigate('$app/'),
      isFalse,
      reason: 'only one initial document',
    );
    expect(
      await FakeArtifactWebView.navigate('https://evil.example/'),
      isFalse,
    );
    expect(
      await FakeArtifactWebView.navigate('$content/x', mainFrame: false),
      isTrue,
      reason: 'subframes are Porthole\'s and the content\'s own',
    );
  });

  test(
    'the initial navigation check takes only the app origin\'s bare root',
    () {
      bool allowed(String url, {bool injected = false, bool already = false}) =>
          artifactInitialWrapperNavigation(
            url,
            appOrigin: app,
            alreadyAllowed: already,
            injected: injected,
          );
      expect(allowed('http://localhost:15194'), isTrue);
      expect(allowed('http://localhost:15194/'), isTrue);
      expect(allowed('http://localhost:15194/x'), isFalse);
      expect(allowed('http://localhost:15194/?q=1'), isFalse);
      expect(allowed('http://localhost:15194/#f'), isFalse);
      expect(allowed('http://u:p@localhost:15194/'), isFalse);
      expect(allowed('https://localhost:15194/'), isFalse);
      expect(allowed('http://localhost:15195/'), isFalse);
      expect(allowed('about:blank'), isFalse);
      expect(allowed('http://localhost:15194/', injected: true), isFalse);
      expect(allowed('http://localhost:15194/', already: true), isFalse);
    },
  );

  testWidgets('a message without the page\'s nonce is dropped: a content frame '
      'that finds the channel can\'t open a link', (tester) async {
    await mount(tester);
    FakeArtifactWebView.post(
      jsonEncode({
        'type': 'openLink',
        'detail': {'id': 7, 'url': 'https://evil.example/'},
      }),
    );
    send('openLink', {
      'id': 8,
      'url': 'https://evil.example/',
    }, withNonce: 'guess');
    await tester.pump();
    expect(opened, isEmpty);
    expect(frame.refused, 2);
    send('openLink', {'id': 9, 'url': 'https://example.com/a'});
    await tester.pump();
    expect(opened, [Uri.parse('https://example.com/a')]);
    expect(
      FakeArtifactWebView.scripts.last,
      'RaftArtifactHost.answer(9, true, true)',
    );
  });

  testWidgets('an expired view reloads once with new tickets; a second expiry '
      'shows the expired state', (tester) async {
    await mount(tester);
    send('ready', {});
    send('fallback', {
      'fallback': {'kind': 'expired'},
    });
    await tester.pump();
    expect(FakeArtifactWebView.scripts.last, 'RaftArtifactHost.reload()');
    expect(frame.status, isNot(ArtifactFrameStatus.fallback));
    send('fallback', {
      'fallback': {'kind': 'expired'},
    });
    await tester.pump();
    expect(frame.status, ArtifactFrameStatus.fallback);
    expect(frame.fallback, ArtifactFrameFallback.expired);
  });

  testWidgets('a refused locate shows the route\'s code', (tester) async {
    await mount(
      tester,
      locate: () async => throw RaftApiException.response(
        'Too many',
        status: 429,
        body: {'error': 'Too many', 'code': 'RATE_LIMITED'},
      ),
    );
    expect(frame.status, ArtifactFrameStatus.error);
    expect(frame.errorCode, 'RATE_LIMITED');
  });

  testWidgets('a location on another Artifact\'s label is not framed', (
    tester,
  ) async {
    await mount(
      tester,
      first: {
        'url': 'http://w-00000000-0000-0000-0000-000000000000.$domain/x',
        'origin': 'http://w-00000000-0000-0000-0000-000000000000.$domain',
        'door': {
          'url': 'http://w-00000000-0000-0000-0000-000000000000.$domain/d',
        },
      },
    );
    expect(FakeArtifactWebView.html, isNull);
    expect(frame.errorCode, 'CONTENT_UNAVAILABLE');
  });

  testWidgets('find answers reach the controller', (tester) async {
    await mount(tester);
    send('findResult', {
      'query': 'a',
      'result': {'total': 5, 'active': 2},
    });
    await tester.pump();
    expect(frame.findAnswer?.total, 5);
    expect(frame.findAnswer?.active, 2);
    send('findRequested', null);
    await tester.pump();
    expect(frame.findRequests, 1);
    unawaited(frame.find('probe', direction: 'next'));
    await tester.pump();
    expect(
      FakeArtifactWebView.scripts.last,
      'RaftArtifactHost.find("probe", "next")',
    );
  });

  test('macOS opens Artifacts in the browser only while VoiceOver is on', () {
    // Another accessibility client (semantics on, VoiceOver off) keeps the frame: the viewer
    // passes VoiceOver alone, never semantics.
    expect(artifactFrameSupportFor('macos'), ArtifactFrameSupport.webView);
    expect(
      artifactFrameSupportFor('macos', voiceOver: false),
      ArtifactFrameSupport.webView,
    );
    expect(
      artifactFrameSupportFor('macos', voiceOver: true),
      ArtifactFrameSupport.browser,
    );
    expect(
      artifactFrameSupportFor('ios', voiceOver: true),
      ArtifactFrameSupport.webView,
    );
    expect(
      artifactFrameSupportFor('android', voiceOver: true),
      ArtifactFrameSupport.webView,
    );
    expect(
      artifactFrameSupportFor('linux', voiceOver: false),
      ArtifactFrameSupport.browser,
    );
  });
}
