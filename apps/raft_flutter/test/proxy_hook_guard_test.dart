import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/repo_root.dart';

/// Every network path must follow the shared proxy decision (system / manual /
/// direct): see docs/system-proxy.md. Creating a client that bypasses it is the
/// `avoid_unproxied_network_client` lint (tool/raft_lints); the tests below pin
/// the wiring of the hook itself.
void main() {
  final root = repoRoot();
  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test('the API client builds its Dio and socket through the hook', () {
    final client = read('packages/raft_client/lib/src/client.dart');
    expect(client, contains('createProxiedDio('));
    expect(client, contains('applyProxyTransport('));
  });

  test('app start-up installs the resolver and the process-wide overrides', () {
    final main = read('apps/raft_flutter/lib/main.dart');
    expect(main, contains('startSystemProxy('));
    // Avatars are fetched by our own proxy-aware fetcher and kept on disk.
    expect(main, contains('installAvatarImageCache('));
    final boot = read(
      'apps/raft_flutter/lib/platform/system_proxy_bootstrap.dart',
    );
    expect(boot, contains('installGlobally()'));
    // Avatars and other third-party image loaders create plain HttpClient()s;
    // only the override covers them.
    final chatUi = read('packages/flutter_chat_ui/lib/src/avatar.dart');
    expect(chatUi, contains('CachedNetworkImage'));
  });

  test('the media player opens http(s) only with the proxy decision wired', () {
    // media_kit/mpv does its own networking: it streams the attachment URL.
    // The whitelist is the fixed set an http(s) stream needs, and mpv's
    // `http-proxy` is set at run time (never through argv or logs) from the
    // same decision every other path uses. video_player (ExoPlayer, AVPlayer)
    // follows the OS proxy only; docs/system-proxy.md says so.
    final player = read(
      'apps/raft_flutter/lib/platform/attachment_player.dart',
    );
    expect(
      player,
      contains(
        "protocolWhitelist: ['file', 'http', 'https', 'tcp', 'tls', 'crypto']",
      ),
    );
    expect(player, contains("setProperty('http-proxy', httpProxyFor("));
    // An empty http-proxy lets FFmpeg read the http_proxy environment variable.
    expect(player, contains("setProperty('stream-lavf-o', lavfOptionsFor("));
    expect(player, contains('SystemProxy.instance.findProxyForClient'));
    expect(player, isNot(contains("'rtsp'")));
  });
}
