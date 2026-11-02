// Native QA only: real RaftApp -> WorkspaceView -> ResourceView, fake transport.
// The observer never loads, scrolls, edits rows, or changes MediaQuery/insets.
// Build OLD and candidate with identical fixture bytes and target/version.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/activity_rollout_flags.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _fixture = 'activity-pagination-292-v1';
const _rowCount = 70;
const _port = 29292;

/// Control changes only the availability of a future/held adapter response.
/// Every offset and accepted row still comes from the actual product request.
class _Pages {
  final trace = <Map<String, Object?>>[];
  int pending = 0, peakPending = 0, serial = 0, flagReads = 0;
  int? holdOffset, failOffset;
  Completer<void>? held;

  Future<Object> read(RequestOptions request) async {
    final offset = _requestInteger(request.queryParameters['offset'], 0);
    final limit = _requestInteger(request.queryParameters['limit'], 30);
    if (offset < 0 || limit <= 0) throw ArgumentError('Invalid page window');
    final row = <String, Object?>{
      'serial': ++serial,
      'offset': offset,
      'limit': limit,
      'startUtc': DateTime.now().toUtc().toIso8601String(),
      'outcome': 'pending',
    };
    trace.add(row);
    pending++;
    if (pending > peakPending) peakPending = pending;
    try {
      if (offset == holdOffset) {
        held ??= Completer<void>();
        await held!.future;
      }
      if (offset == failOffset) {
        failOffset = null;
        row['outcome'] = 'controlled-503';
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response<Object>(
            requestOptions: request,
            statusCode: 503,
            data: const {'error': 'task292 controlled unavailable'},
          ),
        );
      }
      final items = [
        for (var i = offset; i < offset + limit && i < _rowCount; i++)
          {
            'kind': 'channel',
            'channelId': _id(i),
            'channelName': 'QA292 page${i ~/ 30 + 1} row${i + 1}',
            'channelType': 'channel',
            'lastMessageId': null,
            'firstUnreadMessageId': null,
            'firstMentionMessageId': null,
            'lastMessageAt': DateTime.utc(
              2026,
              10,
              12,
              12,
            ).subtract(Duration(minutes: i)).toIso8601String(),
            'lastMessagePreview': 'QA292 unique row ${i + 1} of $_rowCount',
            'lastMessageSenderType': 'user',
            'lastMessageSenderId': 'alice',
            'lastMessageSenderName': 'Alice',
            'unreadCount': 0,
            'hasMention': false,
          },
      ];
      row['outcome'] = 'success';
      row['returnedIds'] = items.map((item) => item['channelId']).toList();
      return {
        'items': items,
        'totalCount': _rowCount,
        'totalUnreadCount': 0,
        'hasMore': offset + items.length < _rowCount,
      };
    } finally {
      pending--;
      row['endUtc'] = DateTime.now().toUtc().toIso8601String();
    }
  }

  void control(String action, int offset) {
    switch (action) {
      case 'hold':
        if (held != null) throw StateError('A page is already held');
        holdOffset = offset;
      case 'fail-next':
        failOffset = offset;
      case 'release':
        holdOffset = null;
        final waiting = held;
        held = null;
        waiting?.complete();
      default:
        throw ArgumentError('Unknown fixture control');
    }
  }
}

String _id(int index) => 'qa292-${(index + 1).toString().padLeft(3, '0')}';

int _requestInteger(Object? value, int fallback) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw ArgumentError('Unsupported page parameter');
}

Object _finite(double value) => value.isFinite
    ? value
    : const {'geometry': 'unavailable', 'reason': 'non-finite'};

Map<String, Object?> _rect(Element element) {
  final render = element.findRenderObject();
  if (render is! RenderBox || !render.attached || !render.hasSize) {
    return const {'geometry': 'unavailable'};
  }
  final topLeft = render.localToGlobal(Offset.zero);
  if (![
    topLeft.dx,
    topLeft.dy,
    render.size.width,
    render.size.height,
  ].every((value) => value.isFinite)) {
    return const {'geometry': 'unavailable', 'reason': 'non-finite'};
  }
  return {
    'left': topLeft.dx,
    'top': topLeft.dy,
    'right': topLeft.dx + render.size.width,
    'bottom': topLeft.dy + render.size.height,
  };
}

Map<String, Object?> _snapshot(_Pages pages, LabNavigationContent content) {
  final views = <Map<String, Object?>>[];
  final controls = <Map<String, Object?>>[];
  final resourceViews = <Map<String, Object?>>[];
  final renderedRows = <Map<String, Object?>>[];
  void visit(Element element) {
    final widget = element.widget;
    final kind = widget.runtimeType.toString();
    if (widget is Text && (widget.data?.startsWith('QA292 ') ?? false)) {
      renderedRows.add({'label': widget.data, 'rect': _rect(element)});
    }
    if (kind == 'WorkspaceMobileTabBar' ||
        kind == 'WorkspaceMobileDetailNavigation') {
      controls.add({'kind': kind, 'rect': _rect(element)});
    }
    if (widget is Text &&
        [
          'Load More',
          'Retry',
          'Loading…',
          'Loading...',
        ].contains(widget.data)) {
      controls.add({
        'kind': 'footer-text',
        'label': widget.data,
        'rect': _rect(element),
      });
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget.runtimeType.toString() == 'RaftButton') {
          controls.add({
            'kind': 'footer-button',
            'label': widget.data,
            'rect': _rect(ancestor),
          });
          return false;
        }
        return true;
      });
    }
    if (widget is CircularProgressIndicator || kind == 'RaftSpinner') {
      controls.add({'kind': kind, 'rect': _rect(element)});
    }
    if (widget is ResourceView &&
        widget.section == 'activity' &&
        element is StatefulElement) {
      // The State class is private; these fields/getters are public. Read only.
      final dynamic state = element.state;
      final rows = (state.rows as List).cast<Map<String, dynamic>>();
      final ids = rows.map((row) => row['channelId']).toList();
      final ScrollController? scroll = state.listScroll as ScrollController?;
      resourceViews.add({
        'mobileRoot': widget.mobileRoot,
        'activitySidebarEnabled': widget.activitySidebarEnabled,
        'compactActivitySidebar': widget.compactActivitySidebar,
        'acceptedIds': ids,
        'uniqueAccepted': ids.toSet().length,
        'fixtureOnly': ids.every(
          (id) => id is String && id.startsWith('qa292-'),
        ),
        'projectedIds': (state.visibleRows as List)
            .cast<Map<String, dynamic>>()
            .map((row) => row['channelId'])
            .toList(),
        'hasMore': state.hasMore as bool,
        'loading': state.loading as bool,
        'activeAppend': state.activeAppend as bool,
        'conversationList': state.activityListLayout as bool,
        'rect': _rect(element),
        'scroll':
            scroll != null &&
                scroll.positions.length == 1 &&
                scroll.position.hasContentDimensions
            ? {
                'pixels': _finite(scroll.position.pixels),
                'min': _finite(scroll.position.minScrollExtent),
                'max': _finite(scroll.position.maxScrollExtent),
                'viewport': _finite(scroll.position.viewportDimension),
                'extentAfter': _finite(scroll.position.extentAfter),
                'isScrolling': scroll.position.isScrollingNotifier.value,
              }
            : null,
      });
    }
    element.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  root?.visitChildren(visit);
  for (final view in WidgetsBinding.instance.platformDispatcher.views) {
    final dpr = view.devicePixelRatio;
    if (!dpr.isFinite || dpr <= 0) {
      views.add(const {'geometry': 'unavailable', 'reason': 'invalid-dpr'});
      continue;
    }
    views.add({
      'physicalWidth': _finite(view.physicalSize.width),
      'physicalHeight': _finite(view.physicalSize.height),
      'dpr': dpr,
      'logicalWidth': _finite(view.physicalSize.width / dpr),
      'logicalHeight': _finite(view.physicalSize.height / dpr),
      'viewPaddingBottomPhysical': _finite(view.viewPadding.bottom),
      'viewInsetsBottomPhysical': _finite(view.viewInsets.bottom),
      'safeBottomLogical': _finite(
        (view.physicalSize.height - view.viewPadding.bottom) / dpr,
      ),
    });
  }
  final workspace = content.workspace;
  return {
    'fixture': _fixture,
    'utc': DateTime.now().toUtc().toIso8601String(),
    'totalFixtureRows': _rowCount,
    'actualRequests': pages.trace,
    'pending': pages.pending,
    'peakPending': pages.peakPending,
    'flagEvaluateReads': pages.flagReads,
    'flagOwnerExists':
        workspace != null && ActivityRolloutFlags.peek(workspace) != null,
    'rememberedConversationList': workspace == null
        ? null
        : FeatureFlagMemory.read([
            workspace.client.origin,
            workspace.client.user?.id,
            workspace.server?.id,
            workspace.server?.string('role'),
          ], ActivityRolloutFlags.activityConversationListKey),
    'flutterViews': views,
    'activityViews': resourceViews,
    'renderedRows': renderedRows,
    'footerControls': controls,
  };
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    'raft.origin': 'https://activity292.example.invalid',
    'raft.mode': 'light',
    'raft.light': 'elegant',
  });
  await DevicePreferences.load();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  final channels = [
    for (var i = 0; i < _rowCount; i++) LabChannel(_id(i), ['plain']),
  ];
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    channels,
    images,
    mobile: true,
    ownsClient: false,
    origin: 'https://activity292.example.invalid',
  );
  seed.dispose();
  final pages = _Pages();
  final content = LabNavigationContent();
  client.user = RaftRecord({
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': 'en',
  });
  api.routes['GET /auth/me'] = (_) => client.user!.json;
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'QA292', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /channels/inbox'] = pages.read;
  api.routes['POST /feature-flags/evaluate'] = (_) {
    pages.flagReads++;
    return {
      'evaluations': [
        for (final key in ActivityRolloutFlags.keys)
          {
            'key': key,
            'enabled': key == ActivityRolloutFlags.activityConversationListKey,
          },
      ],
    };
  };
  api.routes['GET /announcements/active'] = (_) => {
    'announcements': <dynamic>[],
  };
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': <dynamic>[],
  };
  for (final channel in channels) {
    api.routes['GET /channels/${channel.id}'] = (_) => channel.record.json;
  }
  // New app-private task292 database per process. Never open old task251 data.
  final dir = await Directory.systemTemp.createTemp('raft-activity292-');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  server.listen((request) async {
    request.response.headers.contentType = ContentType.json;
    try {
      if (request.method == 'POST' &&
          request.uri.path.startsWith('/control/')) {
        final action = request.uri.pathSegments.last;
        final offset = int.tryParse(
          request.uri.queryParameters['offset'] ?? '30',
        );
        if (offset != 30 && offset != 60) {
          throw ArgumentError('Only append pages are controllable');
        }
        pages.control(action, offset!);
        request.response.write(
          jsonEncode({'controlAccepted': action, 'offset': offset}),
        );
      } else if (request.method == 'GET' && request.uri.path == '/snapshot') {
        final result = _snapshot(pages, content);
        request.response.write(jsonEncode(result));
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
      initialLocation: Uri(path: '/s/lab/activity'),
      nativeContent: content,
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
  );
  debugPrint('RAFT292_READY fixture=$_fixture observerPort=$_port');
}
