// Native QA: real RaftApp -> WorkspaceView -> unjoined channel -> join/composer.
// Only transport is controlled. The observer never changes layout or insets.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _fixture = 'safe-area-295-v1';
const _port = 29595;
const _ids = [
  'qa295-gesture-landscape',
  'qa295-gesture-portrait',
  'qa295-three-landscape',
  'qa295-three-portrait',
];

Object _finite(double value) => value.isFinite ? value : 'non-finite';

Map<String, Object?> _rect(Element element) {
  final render = element.findRenderObject();
  if (render is! RenderBox || !render.attached || !render.hasSize) {
    return const {'available': false};
  }
  final point = render.localToGlobal(Offset.zero);
  final media = element.getInheritedWidgetOfExactType<MediaQuery>()?.data;
  return {
    'left': _finite(point.dx),
    'top': _finite(point.dy),
    'right': _finite(point.dx + render.size.width),
    'bottom': _finite(point.dy + render.size.height),
    'mediaPaddingBottom': media?.padding.bottom,
    'mediaViewPaddingBottom': media?.viewPadding.bottom,
    'mediaViewInsetsBottom': media?.viewInsets.bottom,
  };
}

bool _insideComposer(Element element) {
  var result = false;
  element.visitAncestorElements((ancestor) {
    result = ancestor.widget is RaftComposer;
    return !result;
  });
  return result;
}

Map<String, Object?> _snapshot(
  LabAdapter api,
  LabNavigationContent content,
  Map<String, bool> membership,
  List<Map<String, Object?>> joins,
  List<Map<String, Object?>> navigations,
) {
  final controls = <Map<String, Object?>>[];
  final views = <Map<String, Object?>>[];
  void visit(Element element) {
    final widget = element.widget;
    String? kind;
    String? label;
    if (widget is RaftChannelJoinFooter) kind = 'join-footer';
    if (widget is RaftRecipeButton && widget.metricsKey == 'channelJoin') {
      kind = 'join-button';
      label = widget.label;
    }
    if (widget is RaftComposer) kind = 'composer';
    if (widget is EditableText && _insideComposer(element)) {
      kind = 'composer-editable';
    }
    if (kind != null) {
      controls.add({'kind': kind, 'label': label, 'rect': _rect(element)});
    }
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  for (final view in WidgetsBinding.instance.platformDispatcher.views) {
    final dpr = view.devicePixelRatio;
    views.add({
      'id': view.viewId,
      'physicalWidth': _finite(view.physicalSize.width),
      'physicalHeight': _finite(view.physicalSize.height),
      'dpr': _finite(dpr),
      'viewPaddingLeftPhysical': _finite(view.viewPadding.left),
      'viewPaddingTopPhysical': _finite(view.viewPadding.top),
      'viewPaddingRightPhysical': _finite(view.viewPadding.right),
      'viewPaddingBottomPhysical': _finite(view.viewPadding.bottom),
      'viewInsetsBottomPhysical': _finite(view.viewInsets.bottom),
      'logicalWidth': _finite(view.physicalSize.width / dpr),
      'logicalHeight': _finite(view.physicalSize.height / dpr),
    });
  }
  final workspace = content.workspace;
  return {
    'fixture': _fixture,
    'utc': DateTime.now().toUtc().toIso8601String(),
    'activeChannelId': workspace?.channel?.id,
    'acceptedJoined': workspace?.channel?.joined,
    'hasWorkspaceError': workspace?.error != null,
    'fixtureMembership': membership,
    'joinRequests': joins,
    'platformNavigationRequests': navigations,
    'transportHits': api.hits,
    'transportMisses': api.misses,
    'transportPending': api.pending,
    'flutterViews': views,
    'controls': controls,
  };
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    'raft.origin': 'https://safearea295.example.invalid',
    'raft.mode': 'light',
  });
  await DevicePreferences.load();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  final channels = [
    for (final id in _ids) LabChannel(id, ['plain', 'plain', 'plain']),
  ];
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    channels,
    images,
    mobile: true,
    ownsClient: false,
    origin: 'https://safearea295.example.invalid',
  );
  seed.dispose();
  final content = LabNavigationContent();
  final membership = {for (final id in _ids) id: false};
  final joins = <Map<String, Object?>>[];
  final navigations = <Map<String, Object?>>[];
  Map<String, Object?> row(String id) => {
    'id': id,
    'name': id,
    'type': 'public',
    'serverId': 's1',
    'joined': membership[id],
  };
  api.routes['GET /auth/me'] = (_) => client.user!.json;
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'QA295', 'slug': 'lab', 'role': 'member'},
  ];
  api.routes['GET /channels'] = (_) => [for (final id in _ids) row(id)];
  api.routes['GET /channels/public'] = (_) => [
    for (final id in _ids)
      if (!membership[id]!) row(id),
  ];
  api.routes['GET /announcements/active'] = (_) => {'announcements': []};
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': [],
  };
  for (final id in _ids) {
    api.routes['GET /channels/$id'] = (_) => row(id);
    api.routes['POST /channels/$id/join'] = (_) {
      joins.add({
        'channelId': id,
        'serial': joins.length + 1,
        'utc': DateTime.now().toUtc().toIso8601String(),
      });
      membership[id] = true;
      return {'channel': row(id)};
    };
  }
  final directory = await Directory.systemTemp.createTemp('raft-safearea295-');
  final observer = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  observer.listen((request) async {
    request.response.headers.contentType = ContentType.json;
    try {
      if (request.method == 'GET' && request.uri.path == '/snapshot') {
        request.response.write(
          jsonEncode(_snapshot(api, content, membership, joins, navigations)),
        );
      } else if (request.method == 'POST' &&
          request.uri.pathSegments.length == 2 &&
          request.uri.pathSegments.first == 'navigate' &&
          _ids.contains(request.uri.pathSegments.last)) {
        final id = request.uri.pathSegments.last;
        final path = '/s/lab/channel/$id';
        navigations.add({
          'path': path,
          'utc': DateTime.now().toUtc().toIso8601String(),
        });
        // Deliver a normal engine navigation event. No controller selection,
        // accepted membership, layout, inset or route-state setter is called.
        ServicesBinding.instance.channelBuffers.push(
          'flutter/navigation',
          const JSONMethodCodec().encodeMethodCall(
            MethodCall('pushRouteInformation', {'location': path}),
          ),
          (_) {},
        );
        request.response.write('{"navigationDelivered":true}');
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('{"error":"unknown QA endpoint"}');
      }
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('{"error":"fixture request refused"}');
    }
    await request.response.close();
  });
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab/channel/${_ids.first}'),
      nativeContent: content,
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${directory.path}/workspace.sqlite')),
    ),
  );
  debugPrint('RAFT295_READY fixture=$_fixture observerPort=$_port');
}
