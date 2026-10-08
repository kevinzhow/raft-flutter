import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:raft_client/raft_client.dart';
import 'package:url_launcher/url_launcher.dart';

class OAuthHandoff {
  const OAuthHandoff(this.code, this.verifier);
  final String code, verifier;
}

String _randomProof() {
  final random = Random.secure();
  return base64Url
      .encode(List.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

String oauthCodeChallenge(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

/// Proof keys and handoff codes live in this flow only and never enter app cache.
/// Desktop callbacks use the exact nonce-bound loopback contract of the server.
class NativeOAuthBroker {
  NativeOAuthBroker({
    Future<void> Function(Uri)? launch,
    this.links,
    bool? android,
  }) : _launch = launch ?? _open,
       _android = android ?? Platform.isAndroid;
  final Future<void> Function(Uri) _launch;
  final Stream<Uri>? links;
  final bool _android;
  HttpServer? _server;
  StreamSubscription<Uri>? _subscription;
  Completer<String>? _completion;
  String? _nonce, _provider;
  bool _closed = false;
  Uri? returnUri;
  static Future<void> _open(Uri uri) async {
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const RaftApiException(
        'Could not open the authentication browser.',
      );
    }
  }

  Future<OAuthHandoff> begin(
    RaftClient client,
    String provider, {
    String mode = 'login',
  }) async {
    if (_closed || _completion != null) {
      throw const RaftApiException(
        'The authentication attempt is no longer active.',
      );
    }
    _completion = Completer<String>();
    final completion = _completion!.future;
    unawaited(completion.then<void>((_) {}, onError: (Object e) {}));
    _provider = provider;
    final verifier = _randomProof();
    try {
      if (_android) {
        returnUri = Uri.parse('raft://oauth/callback');
        _subscription = (links ?? AppLinks().uriLinkStream).listen(
          (uri) {
            if (uri.scheme != 'raft' ||
                uri.host != 'oauth' ||
                uri.path != '/callback') {
              return;
            }
            _accept(uri.queryParameters, mode);
          },
          onError: (_) {
            _fail('Could not receive the authentication callback.');
          },
        );
      } else {
        _nonce = _randomProof();
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        returnUri = Uri.parse(
          'http://127.0.0.1:${_server!.port}/auth/done#state=$_nonce',
        );
        _server!.listen(
          (request) => _desktop(request, mode),
          onError: (_) =>
              _fail('The authentication callback could not be received.'),
        );
      }
      if (_closed) throw const RaftApiException('Authentication cancelled.');
      final started = await client.request(
        'POST',
        mode == 'link'
            ? '/auth/mobile/oauth/$provider/link/start'
            : '/auth/mobile/oauth/start',
        authorized: mode == 'link',
        data: {
          if (mode != 'link') 'provider': provider,
          'mode': mode,
          'returnUri': returnUri.toString(),
          'codeChallenge': oauthCodeChallenge(verifier),
        },
      );
      if (_closed) throw const RaftApiException('Authentication cancelled.');
      final url = Uri.tryParse(started['authorizationUrl'] ?? '');
      if (url == null ||
          !['http', 'https'].contains(url.scheme) ||
          url.host.isEmpty) {
        throw const RaftApiException(
          'The server did not return a valid authentication address.',
        );
      }
      await _launch(url);
      final code = await completion.timeout(
        const Duration(minutes: 10),
        onTimeout: () => throw const RaftApiException(
          'Authentication expired. Start again.',
        ),
      );
      return OAuthHandoff(code, verifier);
    } finally {
      await _closeResources();
      _completion = null;
      _nonce = null;
      _provider = null;
      returnUri = null;
    }
  }

  void _accept(Map<String, String> params, String mode) {
    if (_completion == null || _completion!.isCompleted) return;
    if (params['provider'] != _provider || params['mode'] != mode) return;
    if (params['error'] != null) {
      _fail('Authentication was not completed. Return to Raft and try again.');
      return;
    }
    final code = params['code'];
    if (code != null && code.isNotEmpty && code.length <= 2048) {
      _completion!.complete(code);
    }
  }

  Future<void> _desktop(HttpRequest request, String mode) async {
    Map<String, String>? accepted;
    final origin = 'http://127.0.0.1:${_server?.port}';
    request.response.headers.set('Cache-Control', 'no-store');
    request.response.headers.set('X-Content-Type-Options', 'nosniff');
    if (request.method == 'GET' && request.uri.path == '/auth/done') {
      final cspNonce = _randomProof();
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set(
        'Content-Security-Policy',
        "default-src 'none'; script-src 'nonce-$cspNonce'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'",
      );
      request.response.write(
        '''<!doctype html><html><head><meta charset="utf-8"><title>Return to Raft</title></head><body><h1>Returning to Raft</h1><p id="status">Completing authentication…</p><script nonce="$cspNonce">(async()=>{const q=new URLSearchParams(location.search),h=new URLSearchParams(location.hash.slice(1));const data={state:h.get('state'),provider:q.get('provider'),mode:q.get('mode'),code:q.get('code'),error:q.get('error')};history.replaceState(null,'','/auth/done');try{const response=await fetch('/auth/callback',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});document.getElementById('status').textContent=response.ok?'You can close this window and return to Raft.':'Authentication was not accepted. Return to Raft and try again.';}catch(_){document.getElementById('status').textContent='Return to Raft and try again.';}})();</script></body></html>''',
      );
    } else if (request.method == 'POST' &&
        request.uri.path == '/auth/callback' &&
        (request.headers.value('Origin') == null ||
            request.headers.value('Origin') == origin)) {
      try {
        final bytes = <int>[];
        await for (final chunk in request) {
          bytes.addAll(chunk);
          if (bytes.length > 8192) throw const FormatException('too large');
        }
        final payload = jsonDecode(utf8.decode(bytes));
        if (payload is! Map ||
            payload['state'] != _nonce ||
            payload['provider'] != _provider ||
            payload['mode'] != mode) {
          request.response.statusCode = 403;
        } else {
          accepted = {
            for (final e in payload.entries)
              if (e.value is String) '${e.key}': e.value as String,
          };
          request.response.statusCode = 200;
        }
      } catch (_) {
        request.response.statusCode = 400;
      }
    } else {
      request.response.statusCode = 404;
    }
    await request.response.close();
    if (accepted != null) _accept(accepted, mode);
  }

  void _fail(String message) {
    if (_completion != null && !_completion!.isCompleted) {
      _completion!.completeError(RaftApiException(message));
    }
  }

  Future<void> _closeResources() async {
    await _subscription?.cancel();
    _subscription = null;
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> cancel() async {
    _closed = true;
    _fail('Authentication cancelled.');
    await _closeResources();
  }
}
