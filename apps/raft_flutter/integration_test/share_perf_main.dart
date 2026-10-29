// Debug/profile-only entrypoint for the incoming-share timing and QA pass
// (docs/parity.md). The production RaftApp with the real NativeSharing
// (receive_intent + NativeSharingBridge copy) on a fixture API whose latency
// is adjustable. Real Android SEND intents drive it; a loopback control server
// (adb forward tcp:8791 tcp:8791) reports a timeline and taps real pointers.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/share_perf_main.dart
//
//   GET /set?lat=800&msg=300&theme=brutal|elegant|dark   fixture latency, theme
//   GET /scenario?theme=..                               restart signed in
//   GET /timeline[?clear=1]                              events with ms stamps
//   GET /rect?text=..|key=..   GET /tap?text=..|key=..   GET /texts
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
const _origin = 'http://qa.invalid';

final _clock = Stopwatch()..start();
final _timeline = <String>[];
void _mark(String event) {
  final line = '${_clock.elapsedMilliseconds} $event';
  _timeline.add(line);
  debugPrint('SPT ${DateTime.now().millisecondsSinceEpoch} $event');
}

/// Mutable fixture state.
class _Fx {
  int lat = 120, msg = 150;
  String theme = 'brutal';
  bool dark = false;
}

final _fx = _Fx();
late Directory _dir;
var _generation = 0;

class _Status implements Exception {
  _Status(this.code, this.body);
  final int code;
  final Map<String, dynamic> body;
}

Map<String, dynamic> _server(String id, String name, String slug) => {
  'id': id,
  'name': name,
  'slug': slug,
  'role': 'owner',
};

Map<String, dynamic> _channel(
  String id,
  String name,
  String server, {
  String type = 'channel',
  bool joined = true,
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'name': name,
  'type': type,
  'serverId': server,
  'joined': joined,
  'latestSeq': '1',
  'lastMessageAt': '2026-10-11T10:00:00.000Z',
  ...extra,
};

List<Map<String, dynamic>> _channels(String server) => [
  _channel('c${server}1', 'general', server),
  _channel('c${server}2', 'design', server),
  _channel('c${server}3', 'random', server, joined: false),
];

List<Map<String, dynamic>> _dms(String server) => [
  _channel(
    'd${server}1',
    'wenyi',
    server,
    type: 'dm',
    extra: {'peerDisplayName': 'Wenyi', 'peerId': 'wenyi', 'peerType': 'user'},
  ),
];

final _joined = <String>{};

Map<String, dynamic>? _row(String id) {
  if (id == 'dm-bob') {
    return _channel(
      'dm-bob',
      'bob',
      'a',
      type: 'dm',
      extra: {'peerDisplayName': 'Bob', 'peerId': 'bob', 'peerType': 'user'},
    );
  }
  for (final s in ['a', 'b']) {
    for (final c in [..._channels(s), ..._dms(s)]) {
      if (c['id'] == id) {
        return {...c, if (_joined.contains(id)) 'joined': true};
      }
    }
  }
  return null;
}

class _QaAdapter implements HttpClientAdapter {
  FutureOr<dynamic> route(RequestOptions o) async {
    final key = '${o.method} ${o.path}';
    final started = _clock.elapsedMilliseconds;
    _mark('req $key');
    await Future<void>.delayed(
      Duration(
        milliseconds: _fx.lat + (o.path.startsWith('/messages/') ? _fx.msg : 0),
      ),
    );
    try {
      return await _route(o, key);
    } finally {
      _mark('res $key (${_clock.elapsedMilliseconds - started} ms)');
    }
  }

  Future<dynamic> _route(RequestOptions o, String key) async {
    switch (key) {
      case 'GET /auth/me':
        return {
          'id': 'alice',
          'name': 'alice',
          'displayName': 'Alice Zhang',
          'email': 'alice@example.invalid',
          'emailVerified': true,
          'displayLanguage': 'en',
        };
      case 'GET /servers':
        return [
          _server('a', 'Raft Design', 'raft-design'),
          _server('b', 'Launch Team', 'launch'),
        ];
      case 'GET /channels':
        return _channels('${o.headers['X-Server-Id'] ?? 'a'}');
      case 'GET /channels/dm':
        return _dms('${o.headers['X-Server-Id'] ?? 'a'}');
      case 'GET /agents':
        return [
          {'id': 'agent1', 'name': 'Raft Bot', 'displayName': 'Raft Bot'},
        ];
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
      case 'POST /channels/dm':
        return {'id': 'dm-bob'};
    }
    final path = o.path;
    final channel = RegExp(r'^/channels/([^/]+)$').firstMatch(path);
    if (o.method == 'GET' && channel != null) {
      final row = _row(channel.group(1)!);
      if (row != null) return row;
    }
    if (o.method == 'POST' && path.endsWith('/join')) {
      _joined.add(path.split('/')[2]);
      return {...?_row(path.split('/')[2]), 'joined': true};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path.endsWith('/machines')) return {'machines': []};
    if (path.endsWith('/members')) {
      return [
        {'userId': 'alice', 'displayName': 'Alice Zhang'},
        {'userId': 'bob', 'displayName': 'Bob'},
      ];
    }
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
    if (path.endsWith('/upload-capabilities')) return {'maxBytes': 52428800};
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

Future<void> _start() async {
  final store = MemorySessionStore();
  await store.write(
    _origin,
    Session(accessToken: 'fixture-only', refreshToken: 'fixture-only'),
  );
  SharedPreferences.setMockInitialValues({
    'raft.origin': _origin,
    'raft.mode': _fx.dark ? 'dark' : 'light',
    'raft.light': _fx.theme,
  });
  await DevicePreferences.load();
  final generation = ++_generation;
  runApp(
    RootErrorBoundary(
      child: ProviderScope(
        child: KeyedSubtree(
          key: ValueKey(generation),
          child: app.RaftApp(
            services: const AppServices.updatesDisabledForTestOrPreview(),
            sessionStore: store,
            createClient: (origin, store, kind) =>
                _QaClient(origin, store, kind),
            initialLocation: Uri.parse('/'),
            nativeContent: LabNavigationContent(),
            // The real platform bridge: receive_intent + copyIncoming.
            nativeSharing: NativeSharing(),
            openWorkspaceCache: () async => LabNavigationCache(
              File('${_dir.path}/workspace-$generation.sqlite'),
            ),
          ),
        ),
      ),
    ),
  );
}

bool _has(String type) {
  var found = false;
  void visit(Element e) {
    if (found) return;
    if (e.widget.runtimeType.toString() == type) {
      found = true;
      return;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return found;
}

/// While armed, logs the first frame where the picker leaves the tree.
bool _armed = false, _pickerSeen = false;
void _watch() {
  _armed = true;
  _pickerSeen = false;
  void frame(Duration _) {
    if (!_armed) return;
    final picker = _has('IncomingSharePicker');
    if (picker && !_pickerSeen) {
      _pickerSeen = true;
      _mark('picker visible');
    } else if (!picker && _pickerSeen) {
      _armed = false;
      _mark('picker gone (composer visible)');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(frame);
    WidgetsBinding.instance.scheduleFrame();
  }

  WidgetsBinding.instance.addPostFrameCallback(frame);
  WidgetsBinding.instance.scheduleFrame();
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  RootErrors.instance.install();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  _dir = await Directory.systemTemp.createTemp('raft-share-perf-');
  _watch();
  await _start();
  await _serve();
}

Future<void> _serve() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  await for (final request in server) {
    try {
      final q = request.uri.queryParameters;
      switch (request.uri.path) {
        case '/scenario':
          _joined.clear();
          _fx.theme = (q['theme'] ?? 'brutal') == 'brutal'
              ? 'brutal'
              : 'elegant';
          _fx.dark = q['theme'] == 'dark';
          await _start();
          request.response.write('ok');
        case '/set':
          _fx.lat = int.tryParse(q['lat'] ?? '') ?? _fx.lat;
          _fx.msg = int.tryParse(q['msg'] ?? '') ?? _fx.msg;
          request.response.write('ok');
        case '/watch':
          _watch();
          request.response.write('ok');
        case '/timeline':
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(_timeline));
          if (q['clear'] == '1') _timeline.clear();
        case '/rect':
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(_find(q)));
        case '/tap':
          final r = _find(q);
          if (r == null) {
            request.response
              ..statusCode = 404
              ..write('not found');
          } else {
            _mark('tap ${q['text'] ?? q['key']}');
            await _pointer(r, double.tryParse(q['dy'] ?? '') ?? 0, hold: false);
            request.response.write('tapped');
          }
        case '/texts':
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(_texts()));
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
        // Pages kept under the top route stay in the tree; only a visible hit counts.
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        final center = MatrixUtils.transformPoint(
          ro.getTransformTo(null),
          ro.size.center(Offset.zero),
        );
        final size = view.physicalSize / view.devicePixelRatio;
        if (center.dx >= 0 &&
            center.dy >= 0 &&
            center.dx <= size.width &&
            center.dy <= size.height) {
          hit = e;
          return;
        }
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

Future<void> _pointer(
  Map<String, dynamic> r,
  double dyLogical, {
  bool hold = false,
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
  await Future<void>.delayed(const Duration(milliseconds: 60));
  binding.handlePointerEvent(
    PointerUpEvent(position: physical, pointer: id, viewId: view),
  );
  binding.handlePointerEvent(
    PointerRemovedEvent(position: physical, pointer: id, viewId: view),
  );
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
