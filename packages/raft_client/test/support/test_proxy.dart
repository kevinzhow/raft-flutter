import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One request the proxy saw.
class ProxiedRequest {
  ProxiedRequest(this.method, this.target, this.authorization);
  final String method;
  final String target;
  final String? authorization;
  @override
  String toString() => '$method $target';
}

/// A tiny HTTP proxy for tests: absolute-URI forwarding, `CONNECT` tunnels and
/// optional Basic `Proxy-Authorization`. Host names are mapped to local ports
/// so a test can use names that only the proxy can resolve (`api.test`).
class TestProxy {
  TestProxy._(this._server, this.hosts, this.requireAuth);

  final ServerSocket _server;

  /// `host:port` as the client asked for it -> local port.
  final Map<String, int> hosts;
  final String? requireAuth;
  final seen = <ProxiedRequest>[];
  final rejected = <ProxiedRequest>[];
  final _open = <Socket>{};

  int get port => _server.port;

  static Future<TestProxy> start({
    required Map<String, int> hosts,
    String? basicUser,
    String? basicPassword,
    int port = 0,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    final proxy = TestProxy._(
      server,
      hosts,
      basicUser == null
          ? null
          : 'Basic ${base64Encode(utf8.encode('$basicUser:$basicPassword'))}',
    );
    server.listen(proxy._accept);
    return proxy;
  }

  Future<void> close() async {
    await _server.close();
    for (final socket in _open.toList()) {
      socket.destroy();
    }
  }

  void _accept(Socket client) {
    _open.add(client);
    client.done.then((_) => _open.remove(client), onError: (_) {});
    final buffer = BytesBuilder();
    late StreamSubscription<Uint8List> sub;
    sub = client.listen(
      (chunk) {
        buffer.add(chunk);
        final bytes = buffer.toBytes();
        final end = _headerEnd(bytes);
        if (end < 0) return;
        sub.pause();
        unawaited(_serve(client, sub, bytes, end));
      },
      onError: (_) => client.destroy(),
      onDone: client.destroy,
    );
  }

  static int _headerEnd(Uint8List b) {
    for (var i = 0; i + 3 < b.length; i++) {
      if (b[i] == 13 && b[i + 1] == 10 && b[i + 2] == 13 && b[i + 3] == 10) {
        return i + 4;
      }
    }
    return -1;
  }

  Future<void> _serve(
    Socket client,
    StreamSubscription<Uint8List> sub,
    Uint8List bytes,
    int end,
  ) async {
    final head = latin1.decode(bytes.sublist(0, end));
    final lines = head.split('\r\n');
    final parts = lines.first.split(' ');
    final method = parts[0], target = parts[1];
    String? header(String name) {
      for (final line in lines.skip(1)) {
        final i = line.indexOf(':');
        if (i > 0 && line.substring(0, i).toLowerCase() == name) {
          return line.substring(i + 1).trim();
        }
      }
      return null;
    }

    final auth = header('proxy-authorization');
    final request = ProxiedRequest(method, target, auth);
    if (requireAuth != null && auth != requireAuth) {
      rejected.add(request);
      client.write(
        'HTTP/1.1 407 Proxy Authentication Required\r\n'
        'Proxy-Authenticate: Basic realm="test"\r\n'
        'Content-Length: 0\r\nConnection: close\r\n\r\n',
      );
      await client.flush();
      client.destroy();
      return;
    }
    seen.add(request);

    final String authority;
    List<int> forward = const [];
    if (method == 'CONNECT') {
      authority = target;
    } else {
      final uri = Uri.parse(target);
      authority = '${uri.host}:${uri.hasPort ? uri.port : 80}';
      final path = uri.path.isEmpty ? '/' : uri.path;
      final upgrade = (header('upgrade') ?? '').isNotEmpty;
      final rewritten = StringBuffer(
        '$method ${path}${uri.hasQuery ? '?${uri.query}' : ''} ${parts[2]}\r\n',
      );
      for (final line in lines.skip(1)) {
        if (line.isEmpty) continue;
        final name = line.split(':').first.toLowerCase();
        if (name == 'proxy-authorization' || name == 'proxy-connection') {
          continue;
        }
        if (!upgrade && name == 'connection') continue;
        rewritten.write('$line\r\n');
      }
      if (!upgrade) rewritten.write('Connection: close\r\n');
      rewritten.write('\r\n');
      forward = [...latin1.encode(rewritten.toString()), ...bytes.sublist(end)];
    }
    final local = hosts[authority];
    if (local == null) {
      client.write('HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n');
      await client.flush();
      client.destroy();
      return;
    }
    final Socket upstream;
    try {
      upstream = await Socket.connect(InternetAddress.loopbackIPv4, local);
    } catch (_) {
      client.destroy();
      return;
    }
    _open.add(upstream);
    if (method == 'CONNECT') {
      client.write('HTTP/1.1 200 Connection Established\r\n\r\n');
    } else {
      upstream.add(forward);
    }
    sub.onData(upstream.add);
    sub.onDone(() => upstream.destroy());
    upstream.listen(
      client.add,
      onDone: () => client.destroy(),
      onError: (_) => client.destroy(),
    );
    sub.resume();
  }
}
