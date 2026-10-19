// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the side
// thread panel (parent + replies, empty / loading / history-limited, the
// composer footer, the overflow menu), the channel timeline states and the
// inline thread reply preview, at desktop and mobile widths. NOT official
// cases; ids are `components.thread-ext.<scene>.<platform>.<state>.<theme>`,
// dispatched on props like tool/parity-ext/host/ThreadCases.tsx.
//
// The REAL WorkspaceView is mounted at the case viewport and the capture is
// the same window the React host clips: `(winY, winH)` of the desktop main
// column (viewport - rail - 240 sidebar), of the 400px side thread column or
// of the 390 mobile page (`winY < 0` counts from the bottom).
//
// Data: tool/parity-ext/fixtures/thread.json (fixtures['ext:thread']): `routes`
// + the case's `routeSet`. The clock is the fixture instant, like React's.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/features/resource_view.dart';

import '../parity_harness.dart';
import 'home_tasks/fixture_workspace.dart';
import 'thread_composer/fake_workspace.dart';
import 'thread_messages/chat_stage.dart' show ParityIdentities;
import '../../support/app_services_fixture.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:thread'] as Map<String, dynamic>;

/// ParityFakeClient plus the fixture's `{"$pending": true}` (never answers)
/// and `{"$status": N}` (fails) route bodies.
class _ExtClient extends ParityFakeClient {
  _ExtClient({required super.user, required super.routes});

  Object? _special(String method, String path) {
    final answer = routes['$method $path'];
    if (answer is Map && answer['\$pending'] == true) {
      return Completer<Never>().future;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) {
    final pending = _special('GET', '/messages/channel/$id');
    if (pending != null) return pending as Future<Map<String, dynamic>>;
    return super.messagePage(id, limit: limit, before: before, after: after);
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) {
    final pending = _special(method, path);
    if (pending != null) return pending as Future<dynamic>;
    return super.request(
      method,
      path,
      data: data,
      query: query,
      authorized: authorized,
      retried: retried,
      cancellation: cancellation,
      onSendProgress: onSendProgress,
      headers: headers,
      acceptServerExit: acceptServerExit,
      receiveTimeout: receiveTimeout,
    );
  }
}

WorkspaceController _workspace(ParityContext ctx) {
  SharedPreferences.setMockInitialValues({});
  // The React provider pins its clock to the fixture instant.
  // (`props.clockIso` overrides it per case, as in the provider spec).
  final clockIso = ctx.props['clockIso'] as String?;
  final now = clockIso != null
      ? DateTime.parse(clockIso)
      : DateTime.fromMillisecondsSinceEpoch(
          (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
        );
  sourceTimeNow = () => now;
  addTearDown(() => sourceTimeNow = DateTime.now);
  final fx = _fx(ctx);
  final base = ParityThreadFixture(ctx.fixtureData);
  final ids = ParityIdentities(ctx);
  final routeSet = (fx['routeSets'] as Map)[ctx.props['routeSet']] as Map? ?? {};
  final client = _ExtClient(
    user: base.authUser,
    routes: {
      ...Map<String, dynamic>.from(fx['routes'] as Map),
      // Same directory the React host seeds (visualAgents / visualMembers).
      'GET /agents': ids.agents,
      'GET /servers/visual-server/members': ids.members,
      'GET /tasks/channel/channel-design': {'tasks': <dynamic>[]},
      ...Map<String, dynamic>.from(routeSet),
    },
  );
  final channels = [
    for (final c in fx['channels'] as List)
      RaftChannel(Map<String, dynamic>.from(c as Map)),
  ];
  final dms = [
    for (final c in fx['dms'] as List)
      RaftChannel(Map<String, dynamic>.from(c as Map)),
  ];
  final w = WorkspaceController(client)
    ..server = RaftRecord(base.serverRecord)
    ..channels = channels
    ..dms = dms;
  w.messageDomain.ledger.switchServer('visual-server');
  return w;
}

/// Window the React host clips, in viewport coordinates.
Rect _window(ParityContext ctx) {
  final h = (ctx.props['winH'] as num).toDouble();
  final y = (ctx.props['winY'] as num).toDouble();
  final top = y < 0 ? ctx.height + y : y;
  if (ctx.props['platform'] == 'mobile') {
    return Rect.fromLTWH(0, top, ctx.width, h);
  }
  final rail = ctx.family == RaftFamily.brutal ? 64.0 : 56.0;
  return switch (ctx.props['surface']) {
    'thread' => Rect.fromLTWH(ctx.width - 400, top, 400, h),
    'inbox' => Rect.fromLTWH(rail, top, 240, h),
    _ => Rect.fromLTWH(rail + 240, top, ctx.width - rail - 240, h),
  };
}

class _Host extends StatefulWidget {
  const _Host({required this.ctx});
  final ParityContext ctx;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final WorkspaceController w = _workspace(widget.ctx);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final ctx = widget.ctx;
    final fx = _fx(ctx);
    final id = ctx.props['channel'] as String? ?? 'channel-design';
    final channel = [...w.channels, ...w.dms].firstWhere((c) => c.id == id);
    unawaited(w.selectChannel(channel));
    if (ctx.props['surface'] == 'thread') {
      final thread = Map<String, dynamic>.from(fx['thread'] as Map);
      await w.openThreadIdentity(
        parentChannelId: thread['parentChannelId'] as String,
        parentMessageId: thread['parentMessageId'] as String,
        initialThreadChannelId: thread['threadChannelId'] as String,
      );
    }
  }

  @override
  Widget build(BuildContext context) => withAppServices(
    WorkspaceView(
      controller: w,
      appearance: RaftAppearance(
        mode: widget.ctx.dark ? ThemeMode.dark : ThemeMode.light,
        light: widget.ctx.family,
      ),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
}

/// The Threads inbox in the official 342x620 activity box (ResourceView is the
/// activity page; the fixture workspace answers `/channels/inbox` with no rows
/// for every id except the official `components.home.activity.results`).
Widget _buildInbox(ParityContext ctx) {
  final w = parityWorkspace(ctx, section: 'activity');
  final now = parityNow(ctx);
  return ctx.frame(
    width: 342,
    height: 620,
    padding: EdgeInsets.zero,
    child: Scaffold(
      body: ResourceView(
        controller: w,
        section: 'activity',
        clock: () => now,
        onBack: () {},
        searchMemory: SearchMemoryStore(
          storage: ParityMemorySearchStorage(),
          clock: () => now,
        ),
        restoreSearchState: false,
        onMessage: (_, _) async {},
      ),
    ),
  );
}

Widget _build(ParityContext ctx) {
  if (ctx.props['surface'] == 'inbox') return _buildInbox(ctx);
  final window = _window(ctx);
  return Align(
    alignment: Alignment.topLeft,
    child: ctx.target(
      SizedBox.fromSize(
        size: window.size,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: ctx.width,
            maxWidth: ctx.width,
            minHeight: ctx.height,
            maxHeight: ctx.height,
            child: Transform.translate(
              offset: -window.topLeft,
              child: _Host(ctx: ctx),
            ),
          ),
        ),
      ),
    ),
  );
}

final ParityCase _case = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_ui:RaftThreadPanel',
    'raft_ui:RaftMessageTimeline',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView, clipped window.',
  settle: const Duration(milliseconds: 1200),
  build: _build,
);

const _scenes = {
  'thread': [
    'panel',
    'empty',
    'loading',
    'history-limited',
    'composer',
    'overflow-menu',
  ],
  'timeline': [
    'dates',
    'empty',
    'loading',
    'history-limited',
    'history-top',
    'system-collapsed',
    'system-expanded',
    'back-to-bottom',
  ],
  'inline': ['preview'],
};

// Desktop only: the inbox is a fixed 342x620 box on both providers.
const _inboxStates = ['empty'];


/// Every extension thread / timeline case, keyed by id (3 themes each).
final Map<String, ParityCase> extThreadCases = {
  for (final MapEntry(key: scene, value: states) in _scenes.entries)
    for (final platform in const ['desktop', 'mobile'])
      for (final state in states)
        for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
          'components.thread-ext.$scene.$platform.$state.$theme': _case,
  for (final state in _inboxStates)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.thread-ext.inbox.desktop.$state.$theme': _case,
};
