import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifacts/artifact_frame_bridge.dart';

/// WP-ART0 spike: the checks the app makes around Raft Web v1.24's Artifact frame (Porthole) in
/// a WebView. Web's own checks are in packages/web/src/apps/artifacts/ArtifactFrame.tsx.
void main() {
  const id = 'pt_0f8b6c7e-1a2b-4c3d-8e9f-001122334455';
  const uuid = '0f8b6c7e-1a2b-4c3d-8e9f-001122334455';
  const domain = 'raftusercontent.example';
  const origin = 'https://w-$uuid.$domain';

  ArtifactFrameLocation location({
    String origin = origin,
    String? url,
    String? door,
  }) => ArtifactFrameLocation.parse({
    'url': url ?? '$origin/_raft/open?ticket=t1',
    'origin': origin,
    'reports': true,
    'door': {'url': door ?? '$origin/__porthole/door/_raft?ticket=t2'},
    'instanceVersion': 'v_11111111-2222-4333-8444-555555555555',
  })!;

  String? source(ArtifactFrameLocation location, {bool loopback = false}) =>
      artifactFrameContentSource(
        artifactId: id,
        contentDomain: domain,
        location: location,
        allowLoopback: loopback,
      );

  group('frame location', () {
    test('an answer without a door frames nothing (Porthole 0.14.10+)', () {
      expect(
        ArtifactFrameLocation.parse({
          'url': '$origin/_raft/open?ticket=t1',
          'origin': origin,
        }),
        isNull,
      );
    });

    test('only this Artifact\'s own label on the build\'s domain', () {
      expect(source(location()), 'https://*.$domain');
      const other = 'https://w-11111111-2222-4333-8444-555555555555.$domain';
      expect(source(location(origin: other)), isNull);
      expect(source(location(origin: 'https://w-$uuid.evil.example')), isNull);
      expect(
        artifactFrameContentSource(
          artifactId: id,
          contentDomain: null,
          location: location(),
          allowLoopback: false,
        ),
        isNull,
      );
    });

    test('the ticket and the door are on that origin', () {
      expect(source(location(url: 'https://evil.example/_raft/open')), isNull);
      expect(source(location(door: 'https://evil.example/door')), isNull);
    });

    test('plain http only on a *.localhost domain, only when allowed', () {
      final local = ArtifactFrameLocation.parse({
        'url': 'http://w-$uuid.artifacts.localhost:18787/_raft/open?ticket=t',
        'origin': 'http://w-$uuid.artifacts.localhost:18787',
        'door': {
          'url': 'http://w-$uuid.artifacts.localhost:18787/__porthole/door/_raft',
        },
      })!;
      String? check(bool loopback) => artifactFrameContentSource(
        artifactId: id,
        contentDomain: 'artifacts.localhost:18787',
        location: local,
        allowLoopback: loopback,
      );
      expect(check(true), 'http://*.artifacts.localhost:18787');
      expect(check(false), isNull);
      final plain = ArtifactFrameLocation.parse({
        'url': 'http://w-$uuid.$domain/_raft/open',
        'origin': 'http://w-$uuid.$domain',
        'door': {'url': 'http://w-$uuid.$domain/__porthole/door/_raft'},
      })!;
      expect(source(plain, loopback: true), isNull);
    });

    test('passes the door and instance version on as they came', () {
      final json = location().toJson();
      expect(json['door'], {'url': '$origin/__porthole/door/_raft?ticket=t2'});
      expect(json['instanceVersion'], 'v_11111111-2222-4333-8444-555555555555');
    });
  });

  group('openLink', () {
    test('only absolute http and https addresses open', () {
      expect(artifactFrameLink('https://example.com/a?b=1'), isNotNull);
      expect(artifactFrameLink('http://example.com'), isNotNull);
      for (final raw in [
        'javascript:alert(1)',
        'data:text/html,hi',
        'file:///etc/passwd',
        'blob:https://x/y',
        '/relative',
        'intent://scan#Intent;end',
        42,
        null,
      ]) {
        expect(artifactFrameLink(raw), isNull, reason: '$raw');
      }
    });
  });

  group('bridge gate', () {
    test('takes only messages with the page\'s nonce', () {
      final gate = ArtifactBridgeGate(nonce: 'n0nce');
      final ok = gate.accept(
        jsonEncode({
          'nonce': 'n0nce',
          'type': 'openLink',
          'detail': {'id': 3, 'url': 'https://example.com'},
        }),
      );
      expect(ok?.type, ArtifactBridgeMessageType.openLink);
      expect(ok?.callId, 3);
      // What content in any frame can send: the channel without the nonce.
      expect(
        gate.accept(jsonEncode({'type': 'openLink', 'detail': {'id': 1}})),
        isNull,
      );
      expect(
        gate.accept(jsonEncode({'nonce': 'guess', 'type': 'copyText'})),
        isNull,
      );
      expect(gate.accept('not json'), isNull);
      expect(
        gate.accept(jsonEncode({'nonce': 'n0nce', 'type': 'eval'})),
        isNull,
      );
      expect(gate.refused, 4);
    });

    test('drops oversized messages', () {
      final gate = ArtifactBridgeGate(nonce: 'n', maxMessageBytes: 64);
      expect(
        gate.accept(jsonEncode({'nonce': 'n', 'type': 'ready', 'x': 'y' * 80})),
        isNull,
      );
    });

    test('a fresh gate has an unguessable nonce', () {
      final a = ArtifactBridgeGate(), b = ArtifactBridgeGate();
      expect(a.nonce, isNot(b.nonce));
      expect(a.nonce.length, greaterThanOrEqualTo(32));
    });
  });

  group('wrapper page', () {
    test('frames only the content source and runs no script of its own', () {
      final gate = ArtifactBridgeGate(nonce: 'n0nce');
      final html = artifactWrapperHtml(
        contentSource: 'https://*.$domain',
        gate: gate,
        dark: false,
      );
      expect(html, contains('data-bridge-nonce="n0nce"'));
      expect(html, contains('frame-src https://*.$domain'));
      expect(html, contains("default-src 'none'"));
      expect(html, contains("script-src 'none'"));
      expect(html, isNot(contains('<script')));
    });
  });

  group('host calls', () {
    test('values are JSON, never pasted text', () {
      expect(
        ArtifactHostCalls.find('a"); evil(); ("'),
        r'RaftArtifactHost.find("a\"); evil(); (\"", null)',
      );
      expect(
        ArtifactHostCalls.answer(2, ok: true, value: true),
        'RaftArtifactHost.answer(2, true, true)',
      );
    });
  });

  test('WebView on Android, iOS and macOS; the browser elsewhere', () {
    expect(artifactFrameSupportFor('android'), ArtifactFrameSupport.webView);
    expect(artifactFrameSupportFor('ios'), ArtifactFrameSupport.webView);
    expect(artifactFrameSupportFor('macos'), ArtifactFrameSupport.webView);
    expect(artifactFrameSupportFor('linux'), ArtifactFrameSupport.browser);
    expect(artifactFrameSupportFor('windows'), ArtifactFrameSupport.browser);
  });

  test('the sandbox is Web\'s', () {
    expect(artifactFrameSandbox, 'allow-scripts allow-same-origin');
  });
}
