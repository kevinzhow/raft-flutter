// Debug/profile-only entrypoint for the text-scale emulator check: the
// production RaftApp on fixture data, no login, with a channel `kb` holding long
// CJK and Latin rows, attachments, reactions, code and thread replies.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/text_scale_main.dart
//
// A loopback control server (adb forward tcp:<host> tcp:8765):
//   GET /goto?path=/s/lab/channel/kb   push a route as the engine would
//   GET /misses                        fixture routes the app asked for and lacks
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/page_alignment_fixtures.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:raft_ui/raft_ui.dart'
    show RaftControlTypography, RaftFontFamilies;
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _theme = String.fromEnvironment('CJK_THEME', defaultValue: 'elegant');
const _lang = String.fromEnvironment('CJK_LANG', defaultValue: 'en');
// Optional CJK font file readable by the app (adb push to /data/local/tmp):
// registered as the first fallback family, to compare font metrics.
const _font = String.fromEnvironment('CJK_FONT');
const _port = int.fromEnvironment('CJK_PORT', defaultValue: 8765);

const _textScaleKinds = [
  'markdown', 'plain', 'plain', 'reactions', 'attachments', //
  'plain', 'thread-summary', 'plain', 'image', 'code', //
  'plain', 'task', 'plain', 'reactions', 'markdown', 'plain',
];

const _runtimes = ['claude', 'codex', 'grok', 'builtin', 'kimi-sdk'];

late LabAdapter _lab;
late LabChannel _channel;
final _content = LabNavigationContent();

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  if (_font.isNotEmpty) {
    final bytes = await File(_font).readAsBytes();
    await (FontLoader(
      'CjkProbe',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    NativeSystemFonts.instance.value = const RaftFontFamilies(
      fallback: ['CjkProbe'],
    );
  }
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  final channel = LabChannel('kb', _textScaleKinds);
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    [channel],
    images,
    mobile: true,
    ownsClient: false,
  );
  seed.dispose();
  _lab = api;
  _channel = channel;
  // The session user (not only /auth/me) carries the display language.
  client.user = RaftRecord({
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': _lang,
  });
  api.routes['GET /auth/me'] = (_) => {
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': _lang,
  };
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /channels/kb/files'] = (_) => {
    'files': <dynamic>[],
    'nextCursor': null,
  };
  api.routes['GET /channels/kb'] = (_) => channel.record.json;
  api.routes['GET /channels/inbox'] = (_) => pageActivityFixture;
  api.routes['GET /channels/saved'] = (_) => {
    'globalTotal': 0,
    'saved': <dynamic>[],
  };
  api.routes['GET /channels/threads/followed'] = (_) => {
    'threads': <dynamic>[],
  };
  api.routes['GET /announcements/active'] = (_) => {
    'announcements': <dynamic>[],
  };
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': <dynamic>[],
  };
  api.routes['GET /tasks/server'] = (o) => {
    'tasks': [
      for (final task in pageTasksFixture['tasks'] as List)
        if (o.queryParameters['status'] == null ||
            task['status'] == o.queryParameters['status'])
          task,
    ],
    'next_cursor': null,
  };
  api.routes['GET /servers/s1/machines'] = (_) => {
    'latestComputerVersion': '1.0.45',
    'machines': [
      {
        'id': 'm1',
        'name': 'K8-Plus',
        'description': '',
        'isComputer': true,
        'status': 'online',
        'computerVersion': '1.0.45',
        'hostname': 'k8-plus',
        'os': 'linux x64',
        'userId': 'alice',
        'runtimes': _runtimes,
        'createdAt': '2026-09-30T08:00:00Z',
        'creator': {'name': 'kevinzhow', 'displayName': 'Kevin Zhow'},
      },
      {
        'id': 'm2',
        'name': 'mibook',
        'isComputer': true,
        'status': 'offline',
        'computerVersion': '1.0.45',
        'userId': 'alice',
        'runtimes': <String>[],
      },
    ],
  };
  api.routes['GET /agents'] = (_) => [
    for (final (i, (name, rt, model)) in [
      ('Cindy', 'claude', 'opus'),
      ('Codex', 'codex', 'gpt-5'),
    ].indexed)
      {
        'id': 'agent-$i',
        'name': name.toLowerCase(),
        'displayName': name,
        'machineId': 'm1',
        'runtime': rt,
        'model': model,
        'activity': 'online',
        'status': 'online',
      },
  ];
  const tabs = MobileTabbarSettings(
    order: MobileTabs.configurable,
    enabled: {
      MobileTabs.home,
      MobileTabs.tasks,
      MobileTabs.members,
      MobileTabs.computers,
    },
  );
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': 'light',
    'raft.light': _theme,
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(
        path: const String.fromEnvironment(
          'CJK_ROUTE',
          defaultValue: '/s/lab/activity',
        ),
      ),
      nativeContent: _content,
      nativeSharing: NativeSharing(supported: false),
      // No on-disk workspace cache: history comes from the fixture routes.
      openWorkspaceCache: () async => null,
    ),
  );
  await _serve();
}

Future<void> _serve() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  await for (final request in server) {
    try {
      switch (request.uri.path) {
        case '/goto':
          final path = request.uri.queryParameters['path']!;
          final codec = const JSONMethodCodec();
          ServicesBinding.instance.channelBuffers.push(
            'flutter/navigation',
            codec.encodeMethodCall(
              MethodCall('pushRouteInformation', {'location': path}),
            ),
            (_) {},
          );
          // Opening the page does not load history in this fixture; the lab
          // selects the channel itself, as the perf lab does.
          if (path.contains('/channel/')) {
            Timer(
              const Duration(milliseconds: 800),
              () =>
                  unawaited(_content.workspace?.selectChannel(_channel.record)),
            );
          }
          request.response.write('ok');
        case '/height':
          // Device sweep: replace the control line-height token at runtime.
          final raw = request.uri.queryParameters['value'] ?? '';
          final value = double.tryParse(raw);
          // ignore: invalid_use_of_visible_for_testing_member
          RaftControlTypography.debugAndroidChineseLineHeight = value;
          // ignore: invalid_use_of_visible_for_testing_member
          RaftControlTypography.debugDisabled = raw == 'off';
          WidgetsBinding.instance.reassembleApplication();
          request.response.write('height=$value');
        case '/misses':
          request.response.write(
            jsonEncode({'misses': _lab.misses, 'hits': _lab.hits}),
          );
        case '/dump':
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(_dump()));
        default:
          request.response.statusCode = 404;
      }
    } catch (error) {
      request.response
        ..statusCode = 500
        ..write('$error');
    }
    await request.response.close();
  }
}

bool _hidden(RenderObject node) {
  for (RenderObject? n = node; n != null; n = n.parent) {
    if (n is RenderOffstage && n.offstage) return true;
    if (n is RenderOpacity && n.opacity == 0) return true;
  }
  return false;
}

Map<String, Object?> _dump() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final labels = <Map<String, Object?>>[];
  void visit(RenderObject node) {
    if (node is RenderParagraph && node.attached && node.hasSize) {
      final text = node.text.toPlainText().replaceAll('￼', '');
      final box = node.size;
      if (text.trim().isNotEmpty && box.height <= 40 && !_hidden(node)) {
        final transform = node.getTransformTo(null);
        final rect = MatrixUtils.transformRect(transform, Offset.zero & box);
        // The control: nearest enclosing painted box with fill or border.
        RenderBox? control;
        EdgeInsets border = EdgeInsets.zero;
        for (RenderObject? n = node.parent; n != null; n = n.parent) {
          if (n is RenderDecoratedBox && n.decoration is BoxDecoration) {
            final d = n.decoration as BoxDecoration;
            if (d.color != null || d.border != null) {
              final size = n.size;
              if (size.height + 0.01 >= box.height && size.height <= 80) {
                control = n;
                border =
                    d.border?.dimensions.resolve(TextDirection.ltr) ??
                    EdgeInsets.zero;
                break;
              }
            }
          }
        }
        final style = node.text.style;
        labels.add({
          'text': text,
          'rect': [rect.left, rect.top, rect.right, rect.bottom],
          'font': style?.fontFamily,
          'size': style?.fontSize,
          'height': style?.height,
          'leading': style?.leadingDistribution?.name,
          'lines': box.height / ((style?.fontSize ?? 1) * (style?.height ?? 1)),
          if (control != null) ...{
            'control': () {
              final r = MatrixUtils.transformRect(
                control!.getTransformTo(null),
                Offset.zero & control.size,
              );
              return [r.left, r.top, r.right, r.bottom];
            }(),
            'border': [border.left, border.top, border.right, border.bottom],
          },
        });
      }
    }
    node.visitChildren(visit);
  }

  for (final renderView in RendererBinding.instance.renderViews) {
    visit(renderView);
  }
  return {
    'dpr': view.devicePixelRatio,
    'size': [view.physicalSize.width, view.physicalSize.height],
    'labels': labels,
  };
}
