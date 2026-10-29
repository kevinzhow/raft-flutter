// Debug/profile-only entrypoint: the production RaftApp (real MainActivity,
// RootErrorBoundary, phone shell, keyboard inset guard) on a fixture API, for
// the login / onboarding acceptance pass (docs/login-acceptance.md). No real
// login or network: every request is answered by [_QaAdapter].
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/login_qa_main.dart
//
// A loopback control server (adb forward tcp:8791 tcp:8791) steps through the
// states; tool/login-qa drives it:
//   GET /scenario?name=login&theme=brutal|elegant|dark   restart the app in a state
//   GET /set?login=wrong&servers=fail ...                flip fixture switches live
//   GET /release                                         answer every held request
//   GET /rect?text=Sign%20In | ?key=login-email          physical-pixel rect
//   GET /tap?text=.. | ?key=..  (&dy=-23)                real pointer tap
//   GET /down?key=..  /up                                hold / release a press
//   GET /texts                                           visible text + fallback-style paragraphs
//   GET /fallback                                        paragraphs in Flutter's missing-Material style
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/root_error_boundary.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/navigation_host.dart';

const _port = int.fromEnvironment('QA_PORT', defaultValue: 8791);
const _apiPort = int.fromEnvironment('QA_API_PORT', defaultValue: 8792);
const _origin = 'http://qa.invalid';

/// Mutable fixture state; every route reads it at request time.
class _Fx {
  bool signedIn = false;
  // restore / me: ok | pending | 401 | offline
  String me = 'ok';
  // ready | profile | verify
  String account = 'ready';
  // none | one | two | many | pending | fail
  String servers = 'two';
  // ok | wrong | network | server | rate | pending
  String login = 'ok';
  // ok | exists | pending
  String register = 'ok';
  // none | social
  String providers = 'none';
  // ok | expired | throttled | seat | agreement | pending | notfound
  String invite = 'ok';
  // ok | pending | fail
  String create = 'ok';
  // deferred | complete
  String setup = 'complete';
  // ok | pending | fail  (channel list = the workspace's first load)
  String channels = 'ok';
  // ok | pending (POST /servers/join-community)
  String community = 'pending';
  String location = '/';
  String theme = 'brutal';
  String lang = 'en';
  bool dark = false;
  final held = <Completer<void>>[];

  Future<void> hold() {
    final c = Completer<void>();
    held.add(c);
    return c.future;
  }

  void release() {
    for (final c in held) {
      if (!c.isCompleted) c.complete();
    }
    held.clear();
  }
}

final _fx = _Fx();
late Directory _dir;
var _generation = 0;

class _Net implements Exception {}

class _Status implements Exception {
  _Status(this.code, this.body);
  final int code;
  final Map<String, dynamic> body;
}

Map<String, dynamic> _user() => {
  'id': 'alice',
  'name': _fx.account == 'profile' ? 'pending_alice' : 'alice',
  'displayName': _fx.account == 'profile' ? null : 'Alice Zhang',
  'email': 'alice@example.invalid',
  'emailVerified': _fx.account != 'verify',
  'displayLanguage': _fx.lang,
  if (_fx.account == 'profile') 'profileSetupCompletedAt': null,
  if (_fx.account == 'profile') 'profileSetupSuggestedHandle': 'alice',
};

List<Map<String, dynamic>> _servers() {
  Map<String, dynamic> s(String id, String name, String slug) => {
    'id': id,
    'name': name,
    'slug': slug,
    'role': 'owner',
  };
  return switch (_fx.servers) {
    'none' => [],
    'one' => [s('a', 'Raft Design', 'raft-design')],
    'many' => [
      s('a', 'Raft Design', 'raft-design'),
      s('b', 'Launch Team', 'launch'),
      s('c', 'Alex Chen Studio With A Very Long Server Name', 'alex-chen-studio'),
      s('d', '陈思远的工作室', 'chen-studio'),
      s('e', 'Community', 'community'),
    ],
    _ => [
      s('a', 'Raft Design', 'raft-design'),
      s('b', 'Launch Team', 'launch'),
    ],
  };
}

Map<String, dynamic> _inviteInfo() => {
  'kind': 'email',
  'serverName': 'Raft Design',
  'inviterName': 'Wenyi',
  'memberCount': 12,
  'agentCount': 5,
  'insideCountsHidden': false,
  'humanSeatLimitReached': _fx.invite == 'seat',
  'agreement': _fx.invite == 'agreement'
      ? {
          'id': 'agreement-1',
          'title': 'Community agreement',
          'version': 3,
          'bodyMarkdown': 'Be kind.\n\n1. No spam',
        }
      : null,
};

class _QaAdapter implements HttpClientAdapter {
  FutureOr<dynamic> route(RequestOptions o) async {
    final key = '${o.method} ${o.path}';
    debugPrint('qa-api $key');
    switch (key) {
      case 'GET /auth/me':
        if (_fx.me == 'pending') await _fx.hold();
        if (_fx.me == '401') {
          throw _Status(401, {'error': 'Sign in again.'});
        }
        if (_fx.me == 'offline') throw _Net();
        return _user();
      case 'POST /auth/login':
        switch (_fx.login) {
          case 'wrong':
            throw _Status(401, {
              'error': 'Invalid credentials',
              'code': 'AUTH_INVALID_CREDENTIALS',
            });
          case 'network':
            throw _Net();
          case 'server':
            throw _Status(500, {'error': 'Internal server error'});
          case 'rate':
            throw _Status(429, {
              'error': 'Too many attempts. Try again in 60 seconds.',
            });
          case 'pending':
            await _fx.hold();
        }
        _fx.signedIn = true;
        return {
          'accessToken': 'fixture-only',
          'refreshToken': 'fixture-only',
          'user': _user(),
        };
      case 'POST /auth/register':
        if (_fx.register == 'exists') {
          throw _Status(409, {'error': 'An account with this email already exists.'});
        }
        if (_fx.register == 'pending') await _fx.hold();
        return {
          'accessToken': 'fixture-only',
          'refreshToken': 'fixture-only',
          'user': {..._user(), 'emailVerified': false},
        };
      case 'GET /auth/providers':
        return {
          'providers': _fx.providers == 'social'
              ? [
                  {'id': 'google', 'label': 'Google', 'enabled': true},
                  {'id': 'github', 'label': 'GitHub', 'enabled': true},
                  {'id': 'apple', 'label': 'Apple', 'enabled': true},
                ]
              : [],
        };
      case 'POST /servers/join-community':
        if (_fx.community == 'pending') await _fx.hold();
        throw _Status(500, {'error': 'Could not join the community.'});
      case 'POST /auth/resend-verification':
      case 'POST /auth/verify-email':
      case 'POST /auth/forgot-password':
      case 'POST /auth/reset-password':
      case 'POST /auth/logout':
        return {};
      case 'GET /auth/invite-info':
        switch (_fx.invite) {
          case 'pending':
            await _fx.hold();
          case 'expired':
            throw _Status(404, {'error': 'This invite has expired.'});
          case 'throttled':
            throw _Status(429, {'error': 'Too many requests. Try again later.'});
          case 'notfound':
            throw _Status(404, {'error': 'Invite not found.'});
        }
        return _inviteInfo();
      case 'GET /servers':
        if (_fx.servers == 'pending') await _fx.hold();
        if (_fx.servers == 'fail') {
          throw _Status(500, {'error': 'Could not load your servers. Please retry.'});
        }
        return _servers();
      case 'POST /servers':
        if (_fx.create == 'pending') await _fx.hold();
        if (_fx.create == 'fail') {
          throw _Status(409, {'error': 'That server URL is already taken.'});
        }
        return {
          ...(o.data is Map ? Map<String, dynamic>.from(o.data) : {}),
          'id': 'new',
          'role': 'owner',
        };
      case 'GET /channels':
        if (_fx.channels == 'pending') await _fx.hold();
        if (_fx.channels == 'fail') {
          throw _Status(500, {'error': 'Could not load channels.'});
        }
        final id = o.headers['X-Server-Id'];
        return [
          {
            'id': 'c$id',
            'name': 'general',
            'type': 'channel',
            'serverId': id,
            'joined': true,
            'latestSeq': '1',
          },
        ];
      case 'GET /channels/dm':
      case 'GET /agents':
      case 'GET /machines':
      case 'GET /channels/public':
        return [];
      case 'GET /channels/unread':
        return {'channels': {}};
      case 'GET /channels/inbox':
        return {'items': [], 'hasMore': false, 'totalUnreadCount': 0};
      case 'GET /channels/saved':
        return {'globalTotal': 0, 'saved': []};
      case 'GET /channels/threads/followed':
        return {'threads': []};
      case 'GET /announcements/active':
        return {'announcements': []};
      case 'GET /product-feedback/tickets':
        return {'unread_total': 0, 'tickets': []};
      case 'GET /tasks':
        return [];
      case 'GET /tasks/server':
        return {'tasks': [], 'next_cursor': null};
      case 'POST /feature-flags/evaluate':
        return {'evaluations': []};
    }
    final path = o.path;
    if (path.endsWith('/setup-projection')) {
      if (_fx.setup == 'survey') {
        return {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
          'postSetup': {'surveyPending': true},
        };
      }
      if (_fx.setup == 'cindy') {
        return {
          'phase': 'in_progress',
          'surface': 'create_agent',
          'blocksChat': true,
          'allowedExits': <String>[],
          'sideEffectState': {'transitions': 'enabled', 'completion': 'enabled'},
        };
      }
      return _fx.setup == 'deferred'
          ? {
              'phase': 'deferred',
              'surface': 'computer_runtime',
              'blocksChat': false,
              'allowedExits': <String>[],
              'sideEffectState': {
                'transitions': 'enabled',
                'completion': 'enabled',
              },
            }
          : {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path.endsWith('/machines')) {
      return {
        'machines': _fx.setup == 'cindy'
            ? [
                {
                  'id': 'm1',
                  'name': 'Studio Mac',
                  'isComputer': true,
                  'status': 'online',
                },
              ]
            : [],
      };
    }
    if (path.endsWith('/members')) return [];
    if (path.endsWith('/sidebar-order')) return {};
    if (path.endsWith('/translation-settings')) {
      return {
        'translationEnabled': false,
        'translationAvailable': false,
        'canManageTranslation': false,
      };
    }
    if (path.startsWith('/messages/channel/')) {
      return {'messages': [], 'hasMore': false, 'hasNewer': false};
    }
    if (path.endsWith('/read')) return {};
    throw _Status(404, {'error': 'Unexpected endpoint $key'});
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    try {
      final body = await route(o);
      return ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    } on _Status catch (e) {
      return ResponseBody.fromString(
        jsonEncode(e.body),
        e.code,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    } on _Net {
      throw DioException.connectionError(
        requestOptions: o,
        reason: 'offline',
      );
    }
  }

  @override
  void close({bool force = false}) {}
}

class _QaClient extends RaftClient {
  _QaClient(String origin, SessionStore store, String kind)
    : super(
        origin: origin,
        sessionStore: store,
        clientKind: kind,
        transport: Dio()..httpClientAdapter = _QaAdapter(),
      ) {
    _forwarded = super.events.listen(_events.add);
  }
  final _events = StreamController<RaftEvent>.broadcast();
  late final StreamSubscription<RaftEvent> _forwarded;
  @override
  Stream<RaftEvent> get events => _events.stream;
  @override
  void connect() {}
  @override
  Future<void> dispose() async {
    await _forwarded.cancel();
    await _events.close();
    await super.dispose();
  }
}

const _scenarios = <String, void Function(_Fx)>{
  // Cold start.
  'restoring': _restoring,
  'restore-offline': _restoreOffline,
  'login': _login,
  'login-social': _loginSocial,
  'register': _register,
  'forgot': _forgot,
  'reset': _reset,
  'public-server': _publicServer,
  // Invite.
  'invite-signed-out': _inviteSignedOut,
  'invite-signed-in': _inviteSignedIn,
  'invite-loading': _inviteLoading,
  'invite-expired': _inviteExpired,
  'invite-throttled': _inviteThrottled,
  'invite-seat-limit': _inviteSeat,
  'invite-agreement': _inviteAgreement,
  // Account onboarding.
  'onboarding-verify': _onboardingVerify,
  'onboarding-profile': _onboardingProfile,
  // Server selection.
  'servers-loading': _serversLoading,
  'servers-many': _serversMany,
  'servers-two': _serversTwo,
  'servers-one': _serversOne,
  'servers-none': _serversNone,
  'servers-failed': _serversFailed,
  'servers-create': _serversTwo,
  'access-denied': _accessDenied,
  'joining-community': _joiningCommunity,
  'resolution-loading': _resolutionLoading,
  // First workspace frame.
  'workspace': _workspace,
  'workspace-setup-bar': _workspaceSetup,
  'workspace-setup-survey': _workspaceSetupSurvey,
  'workspace-setup-cindy': _workspaceSetupCindy,
  'root-error': _serversTwo,
};

void _signedOut(_Fx f) {
  f
    ..signedIn = false
    ..me = '401'
    ..login = 'ok'
    ..register = 'ok'
    ..providers = 'none'
    ..account = 'ready'
    ..servers = 'two'
    ..invite = 'ok'
    ..create = 'ok'
    ..setup = 'complete'
    ..channels = 'ok'
    ..location = '/';
}

void _in(_Fx f) {
  _signedOut(f);
  f
    ..signedIn = true
    ..me = 'ok';
}

void _restoring(_Fx f) {
  _in(f);
  f.me = 'pending';
}

void _restoreOffline(_Fx f) {
  _in(f);
  f.me = 'offline';
}

void _login(_Fx f) => _signedOut(f);
void _loginSocial(_Fx f) {
  _signedOut(f);
  f.providers = 'social';
}

void _register(_Fx f) => _signedOut(f);
void _forgot(_Fx f) => _signedOut(f);
void _reset(_Fx f) => _signedOut(f);
void _publicServer(_Fx f) {
  _signedOut(f);
  f.location = '/s/raft-design';
}

void _inviteSignedOut(_Fx f) {
  _signedOut(f);
  f.location = '/join/qa-token';
}

void _inviteSignedIn(_Fx f) {
  _in(f);
  f.location = '/join/qa-token';
}

void _inviteLoading(_Fx f) {
  _inviteSignedOut(f);
  f.invite = 'pending';
}

void _inviteExpired(_Fx f) {
  _inviteSignedOut(f);
  f.invite = 'expired';
}

void _inviteThrottled(_Fx f) {
  _inviteSignedOut(f);
  f.invite = 'throttled';
}

void _inviteSeat(_Fx f) {
  _inviteSignedOut(f);
  f.invite = 'seat';
}

void _inviteAgreement(_Fx f) {
  _inviteSignedOut(f);
  f.invite = 'agreement';
}

void _onboardingVerify(_Fx f) {
  _in(f);
  f.account = 'verify';
}

void _onboardingProfile(_Fx f) {
  _in(f);
  f.account = 'profile';
}

void _serversLoading(_Fx f) {
  _in(f);
  f.servers = 'pending';
}

void _serversMany(_Fx f) {
  _in(f);
  f.servers = 'many';
}

void _serversTwo(_Fx f) => _in(f);
void _serversOne(_Fx f) {
  _in(f);
  f.servers = 'one';
}

void _serversNone(_Fx f) {
  _in(f);
  f.servers = 'none';
}

void _serversFailed(_Fx f) {
  _in(f);
  f.servers = 'fail';
}

void _accessDenied(_Fx f) {
  _in(f);
  f.location = '/s/not-a-server';
}

void _joiningCommunity(_Fx f) {
  _in(f);
  f.location = '/s/community';
}

void _resolutionLoading(_Fx f) {
  _in(f);
  f
    ..location = '/s/raft-design'
    ..channels = 'pending';
}

void _workspace(_Fx f) {
  _in(f);
  f.location = '/s/raft-design';
}

void _workspaceSetupSurvey(_Fx f) {
  _workspace(f);
  f.setup = 'survey';
}

void _workspaceSetupCindy(_Fx f) {
  _workspace(f);
  f.setup = 'cindy';
}

void _workspaceSetup(_Fx f) {
  _workspace(f);
  f.setup = 'deferred';
}

Future<void> _start(String name, String theme) async {
  _fx.release();
  _scenarios[name]!(_fx);
  _fx
    ..theme = theme == 'brutal' ? 'brutal' : 'elegant'
    ..dark = theme == 'dark';
  final store = MemorySessionStore();
  if (_fx.signedIn) {
    await store.write(
      _origin,
      Session(accessToken: 'fixture-only', refreshToken: 'fixture-only'),
    );
  }
  SharedPreferences.setMockInitialValues({
    'raft.origin': _origin,
    'raft.mode': _fx.dark ? 'dark' : 'light',
    'raft.light': _fx.theme,
  });
  // main() preloads the saved preferences before the first frame.
  await DevicePreferences.load();
  final generation = ++_generation;
  // A restart inside one process does not honour the initial location of a
  // `/s/...` route, so it arrives as a deep link once the directory loaded.
  final deepLink = _fx.location.startsWith('/s/') ? _fx.location : null;
  runApp(_root(store, generation, Uri.parse(deepLink == null ? _fx.location : '/')));
  if (deepLink != null) {
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (generation == _generation) {
      ServicesBinding.instance.channelBuffers.push(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', {'location': deepLink}),
        ),
        (_) {},
      );
    }
  }
  if (name == 'root-error') {
    await Future<void>.delayed(const Duration(seconds: 2));
    RootErrors.instance.report(
      StateError('Bad state: fixture failure for the root fallback'),
      StackTrace.fromString(
        '#0 _Fixture.build (package:raft_flutter/qa.dart:1:1)\n#1 main (package:raft_flutter/main.dart:1:1)',
      ),
      componentStack: '\n  in ChannelHeader\n  in WorkspaceView',
    );
  }
}

Widget _root(MemorySessionStore store, int generation, Uri location) =>
    RootErrorBoundary(
      child: ProviderScope(
        child: KeyedSubtree(
          key: ValueKey(generation),
          child: app.RaftApp(
            services: const AppServices.updatesDisabledForTestOrPreview(),
            sessionStore: store,
            createClient: (origin, store, kind) =>
                _QaClient(origin, store, kind),
            initialLocation: location,
            nativeContent: LabNavigationContent(),
            nativeSharing: NativeSharing(supported: false),
            openWorkspaceCache: () async => LabNavigationCache(
              File('${_dir.path}/workspace-$generation.sqlite'),
            ),
          ),
        ),
      ),
    );

/// Anonymous clients (providers, forgot password) are built inside the app
/// with the default transport. Every connection to this process' fixture
/// origin goes to a loopback server answering from [_QaAdapter.route].
class _QaHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionFactory = (uri, proxyHost, proxyPort) =>
            Socket.startConnect(InternetAddress.loopbackIPv4, _apiPort);
}

Future<void> _serveApi() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _apiPort);
  final adapter = _QaAdapter();
  server.listen((request) async {
    try {
      final text = await utf8.decoder.bind(request).join();
      Object? data;
      try {
        data = text.isEmpty ? null : jsonDecode(text);
      } catch (_) {}
      final headers = <String, dynamic>{};
      request.headers.forEach((name, values) {
        headers[name == 'x-server-id' ? 'X-Server-Id' : name] = values.first;
      });
      final options = RequestOptions(
        // The client's base URL is `<origin>/api`.
        path: request.uri.path.replaceFirst(RegExp('^/api'), ''),
        method: request.method,
        data: data,
        queryParameters: request.uri.queryParameters,
        headers: headers,
      );
      try {
        final body = await adapter.route(options);
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
      } on _Status catch (e) {
        request.response
          ..statusCode = e.code
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(e.body));
      } on _Net {
        (await request.response.detachSocket()).destroy();
        return;
      }
    } catch (error) {
      request.response
        ..statusCode = 500
        ..write('$error');
    }
    await request.response.close();
  });
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _QaHttpOverrides();
  await _serveApi();
  RootErrors.instance.install();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  _dir = await Directory.systemTemp.createTemp('raft-login-qa-');
  await _start('login', 'brutal');
  await _serve();
}

// ---------------------------------------------------------------- control

Future<void> _serve() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  await for (final request in server) {
    try {
      final q = request.uri.queryParameters;
      switch (request.uri.path) {
        case '/scenario':
          _fx.lang = q['lang'] ?? 'en';
          await _start(q['name']!, q['theme'] ?? 'brutal');
          request.response.write('ok');
        case '/set':
          for (final MapEntry(:key, :value) in q.entries) {
            switch (key) {
              case 'me':
                _fx.me = value;
              case 'account':
                _fx.account = value;
              case 'servers':
                _fx.servers = value;
              case 'login':
                _fx.login = value;
              case 'register':
                _fx.register = value;
              case 'providers':
                _fx.providers = value;
              case 'invite':
                _fx.invite = value;
              case 'create':
                _fx.create = value;
              case 'setup':
                _fx.setup = value;
              case 'channels':
                _fx.channels = value;
            }
          }
          request.response.write('ok');
        case '/release':
          _fx.release();
          request.response.write('ok');
        case '/rect':
          final rect = _find(q);
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(rect));
        case '/tap':
          final r = _find(q);
          if (r == null) {
            request.response
              ..statusCode = 404
              ..write('not found');
          } else {
            if (q['at'] == 'left') {
              r['cx'] = (r['left'] as double) + 12 * (r['dpr'] as double);
            }
            final dy = double.tryParse(q['dy'] ?? '') ?? 0;
            await _pointer(r, dy, hold: false);
            request.response.write('tapped');
          }
        case '/down':
          final r = _find(q);
          if (r == null) {
            request.response
              ..statusCode = 404
              ..write('not found');
          } else {
            await _pointer(r, 0, hold: true);
            request.response.write('down');
          }
        case '/up':
          _up();
          request.response.write('up');
        case '/texts':
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(_texts()));
        case '/fallback':
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(_fallbackParagraphs()));
        default:
          request.response.statusCode = 404;
      }
    } catch (error, stack) {
      request.response
        ..statusCode = 500
        ..write('$error\n$stack');
    }
    await request.response.close();
  }
}

double get _dpr =>
    WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

/// Physical-pixel rect of the first visible element matching `text`
/// (exact paragraph text) or `key` (ValueKey/Key string).
Map<String, dynamic>? _find(Map<String, String> q) {
  final text = q['text'], key = q['key'], contains = q['contains'];
  Element? hit;
  void visit(Element e) {
    if (hit != null) return;
    final w = e.widget;
    final matches = key != null
        ? (w.key is ValueKey && '${(w.key as ValueKey).value}' == key) ||
              w.key.toString() == "[<'$key'>]"
        : (text != null || contains != null) &&
              w is RichText &&
              (text != null
                  ? w.text.toPlainText().replaceAll('￼', '') == text
                  : w.text.toPlainText().contains(contains!));
    if (matches) {
      final ro = e.renderObject;
      if (ro is RenderBox && ro.attached && ro.hasSize) {
        hit = e;
        return;
      }
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  final ro = hit?.renderObject;
  if (ro is! RenderBox) return null;
  final r = MatrixUtils.transformRect(
    ro.getTransformTo(null),
    Offset.zero & ro.size,
  );
  final s = _dpr;
  return {
    'left': r.left * s,
    'top': r.top * s,
    'right': r.right * s,
    'bottom': r.bottom * s,
    'cx': r.center.dx * s,
    'cy': r.center.dy * s,
    'dpr': s,
  };
}

int _pointerId = 100;
int? _heldPointer;
Offset? _heldAt;

Future<void> _pointer(
  Map<String, dynamic> r,
  double dyLogical, {
  required bool hold,
}) async {
  final s = _dpr;
  final at = Offset(
    (r['cx'] as double) / s,
    (r['cy'] as double) / s + dyLogical,
  );
  final physical = at; // handlePointerEvent takes logical positions
  final id = _pointerId++;
  final binding = GestureBinding.instance;
  final view = WidgetsBinding.instance.platformDispatcher.views.first.viewId;
  binding.handlePointerEvent(
    PointerAddedEvent(position: physical, pointer: id, viewId: view),
  );
  binding.handlePointerEvent(
    PointerDownEvent(position: physical, pointer: id, viewId: view),
  );
  if (hold) {
    _heldPointer = id;
    _heldAt = physical;
    return;
  }
  await Future<void>.delayed(const Duration(milliseconds: 60));
  binding.handlePointerEvent(
    PointerUpEvent(position: physical, pointer: id, viewId: view),
  );
  binding.handlePointerEvent(
    PointerRemovedEvent(position: physical, pointer: id, viewId: view),
  );
}

void _up() {
  final id = _heldPointer, at = _heldAt;
  if (id == null || at == null) return;
  final view = WidgetsBinding.instance.platformDispatcher.views.first.viewId;
  final binding = GestureBinding.instance;
  binding.handlePointerEvent(
    PointerUpEvent(position: at, pointer: id, viewId: view),
  );
  binding.handlePointerEvent(
    PointerRemovedEvent(position: at, pointer: id, viewId: view),
  );
  _heldPointer = null;
  _heldAt = null;
}

bool _fallback(TextStyle? style) {
  if (style == null) return false;
  if ((style.debugLabel ?? '').contains('fallback style')) return true;
  return (style.decoration?.contains(TextDecoration.underline) ?? false) &&
      style.decorationStyle == TextDecorationStyle.double &&
      style.decorationColor == const Color(0xFFFFFF00);
}

List<String> _fallbackParagraphs() {
  final out = <String>[];
  void visit(RenderObject n) {
    if (n is RenderParagraph) {
      var bad = _fallback(n.text.style);
      n.text.visitChildren((span) {
        if (span is TextSpan && _fallback(span.style)) bad = true;
        return true;
      });
      if (bad) out.add(n.text.toPlainText());
    }
    n.visitChildren(visit);
  }

  for (final v in RendererBinding.instance.renderViews) {
    visit(v);
  }
  return out;
}

Map<String, dynamic> _texts() {
  final texts = <String>[];
  void visit(RenderObject n) {
    if (n is RenderParagraph && n.attached && n.hasSize) {
      final t = n.text.toPlainText().replaceAll('￼', '').trim();
      if (t.isNotEmpty) texts.add(t);
    }
    n.visitChildren(visit);
  }

  for (final v in RendererBinding.instance.renderViews) {
    visit(v);
  }
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  return {
    'texts': texts,
    'fallback': _fallbackParagraphs(),
    'viewInsetsBottom': view.viewInsets.bottom / view.devicePixelRatio,
    'paddingTop': view.padding.top / view.devicePixelRatio,
    'paddingBottom': view.padding.bottom / view.devicePixelRatio,
    'size': [
      view.physicalSize.width / view.devicePixelRatio,
      view.physicalSize.height / view.devicePixelRatio,
    ],
  };
}
