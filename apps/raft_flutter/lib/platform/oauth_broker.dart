import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart' show Locale;
import 'package:crypto/crypto.dart';
import 'package:raft_client/raft_client.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_window.dart';
import 'oauth_return_page.dart';

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
    this.helpDelay = const Duration(seconds: 3),
    this.locale,
    Future<void> Function()? presentWindow,
  }) : _presentWindow = presentWindow ?? presentAppWindow,
       _launch = launch ?? _open,
       _android = android ?? Platform.isAndroid;
  final Future<void> Function(Uri) _launch;

  /// The app's display locale: the browser's "return to Raft" page is shown in
  /// it (Chinese for `zh`, otherwise English).
  final Locale? locale;

  /// Brings the app's window to the front once the browser has handed back the
  /// result of a desktop sign-in (the browser is in front until then).
  final Future<void> Function() _presentWindow;

  /// How long a desktop sign-in waits for the browser before the page offers
  /// the link (a `launchUrl` that returned true can still open nothing, e.g.
  /// the Linux AppImage when GIO cannot exec the browser).
  final Duration helpDelay;

  /// The authorization URL while the page should show "Browser didn't open?"
  /// (the launcher failed, or [helpDelay] passed without a callback); null
  /// otherwise. The URL carries the provider's state: it is shown only to the
  /// copy / open-again actions and is never logged.
  // ignore: raft_lints/avoid_unreleased_resource -- Process-wide singleton, never torn down.
  final ValueNotifier<Uri?> helpUrl = ValueNotifier<Uri?>(null);
  Uri? _url;
  Timer? _helpTimer;
  final Stream<Uri>? links;
  final bool _android;
  HttpServer? _server;
  StreamSubscription<Uri>? _subscription;
  Completer<String>? _completion;
  String? _nonce, _provider;
  bool _closed = false;

  /// The user (or the host) cancelled this attempt: nothing to report.
  bool get cancelled => _closed;
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
          // Opt in to "sign in and connect" when the email already has an
          // account (Web `buildSocialAuthStartUrl` `linkOnConflict=1`).
          if (mode != 'link') 'linkOnConflict': true,
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
      _url = url;
      if (!_android) _helpTimer = Timer(helpDelay, _showHelp);
      try {
        await _launch(url);
      } catch (_) {
        // The browser did not open: keep waiting (the link can be opened by
        // hand, the loopback / deep link completes the same attempt).
        _showHelp();
      }
      final code = await completion.timeout(
        const Duration(minutes: 10),
        onTimeout: () => throw const RaftApiException(
          'Authentication expired. Start again.',
        ),
      );
      return OAuthHandoff(code, verifier);
    } finally {
      _clearHelp();
      await _closeResources();
      _completion = null;
      _nonce = null;
      _provider = null;
      returnUri = null;
    }
  }

  void _showHelp() {
    final completion = _completion;
    if (_closed || completion == null || completion.isCompleted) return;
    helpUrl.value = _url;
  }

  void _clearHelp() {
    _helpTimer?.cancel();
    _helpTimer = null;
    _url = null;
    helpUrl.value = null;
  }

  /// Tries the system browser again with the same attempt (same URL).
  Future<void> openAgain() async {
    final url = _url;
    if (_closed || url == null) return;
    try {
      await _launch(url);
    } catch (_) {
      _showHelp();
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
      final page = OAuthReturnPage.render(
        languageCode: locale?.languageCode,
        error: _callbackError(request.uri),
      );
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set('Content-Security-Policy', page.csp);
      request.response.headers.set('Referrer-Policy', 'no-referrer');
      request.response.write(page.html);
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
    if (accepted != null) {
      _accept(accepted, mode);
      unawaited(_presentWindow().catchError((Object _) {}));
    }
  }

  /// The callback's `error` parameter; a malformed query is just "no error".
  static String? _callbackError(Uri uri) {
    try {
      return uri.queryParameters['error'];
    } on FormatException {
      return null;
    }
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
    _clearHelp();
    _fail('Authentication cancelled.');
    await _closeResources();
  }
}
