import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_flutter/platform/attachment_player.dart';

// What mpv's `http-proxy` receives for a streamed attachment URL (Windows and
// Linux): the app's own proxy decision, host and credentials only.
void main() {
  final url = Uri.parse('https://storage.example/clip.mp4?sig=1');
  late SystemProxy previous;
  setUp(() => previous = SystemProxy.instance);
  tearDown(() => SystemProxy.instance = previous);

  test('direct: no proxy', () {
    SystemProxy.instance = SystemProxy()
      ..configure(const ProxySettings(mode: ProxyMode.direct));
    expect(NativeAttachmentPlayer.httpProxyFor(url), '');
  });

  test('manual proxy: an http proxy URL for mpv', () {
    SystemProxy.instance = SystemProxy()
      ..configure(const ProxySettings(mode: ProxyMode.manual, host: '10.0.0.2', port: 8080));
    expect(NativeAttachmentPlayer.httpProxyFor(url), 'http://10.0.0.2:8080');
  });

  test('manual proxy with credentials carries them', () {
    SystemProxy.instance = SystemProxy()
      ..configure(
        const ProxySettings(
          mode: ProxyMode.manual,
          host: '10.0.0.2',
          port: 8080,
          username: 'kev',
          password: 'pw',
        ),
      );
    expect(NativeAttachmentPlayer.httpProxyFor(url), 'http://kev:pw@10.0.0.2:8080');
  });

  test('direct: FFmpeg is told not to fall back to http_proxy', () {
    SystemProxy.instance = SystemProxy()
      ..configure(const ProxySettings(mode: ProxyMode.direct));
    expect(NativeAttachmentPlayer.lavfOptionsFor(url), 'http_proxy=');
  });

  test('a proxy decision leaves the FFmpeg option to http-proxy', () {
    SystemProxy.instance = SystemProxy()
      ..configure(const ProxySettings(mode: ProxyMode.manual, host: '10.0.0.2', port: 8080));
    expect(NativeAttachmentPlayer.lavfOptionsFor(url), '');
  });

  test('loopback is never proxied', () {
    SystemProxy.instance = SystemProxy()
      ..configure(const ProxySettings(mode: ProxyMode.manual, host: '10.0.0.2', port: 8080));
    expect(NativeAttachmentPlayer.httpProxyFor(Uri.parse('http://127.0.0.1:9/x.mp4')), '');
  });

  test('mpv repeats a clip of 60 seconds or less and nothing else', () {
    expect(NativeAttachmentPlayer.loopFileFor(const Duration(seconds: 3)), 'inf');
    expect(NativeAttachmentPlayer.loopFileFor(kLoopingVideoMaxDuration), 'inf');
    expect(
      NativeAttachmentPlayer.loopFileFor(kLoopingVideoMaxDuration + const Duration(milliseconds: 1)),
      'no',
    );
    expect(NativeAttachmentPlayer.loopFileFor(const Duration(minutes: 10)), 'no');
    expect(NativeAttachmentPlayer.loopFileFor(Duration.zero), 'no');
  });
}
