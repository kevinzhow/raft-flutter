// raft-flutter parity EXTENSION suite builders (tool/parity-ext): conversation
// pages that had no case (inventory area 3, rows 3.03, 3.06-3.08, 3.11-3.14, 3.16,
// 3.18, 3.26-3.31, 3.34, 3.37-3.39). NOT official cases; ids are
// `components.conversation.<scene>.<platform>.<state>.<theme>`, dispatched on props
// like tool/parity-ext/host/ConversationPageCases.tsx.
//
//   view=window  the REAL WorkspaceView mounted at the case viewport; the capture is
//                the same window the React host clips: `(winY, winH)` of the desktop
//                main column (viewport - rail - 240 sidebar), of the 400px side thread
//                column or of the 390 mobile page (`winY < 0` counts from the bottom)
//
// Data: tool/parity-ext/fixtures/conversation.json (fixtures['ext:conversation']):
// `routes` + the case's `routeSet`.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/external_identity.dart';
import 'package:raft_flutter/features/profile_preview.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'thread_composer/fake_workspace.dart';
import 'thread_messages/chat_stage.dart';
import '../../support/app_services_fixture.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:conversation'] as Map<String, dynamic>;

/// ParityFakeClient plus the fixture's `{"$pending": true}` (never answers)
/// and `{"$status": N, "$body": {...}}` (fails) route bodies.
class _ConvClient extends ParityFakeClient {
  _ConvClient({required super.user, required super.routes});

  Object? _special(String method, String path) {
    final answer = routes['$method $path'];
    if (answer is Map && answer['\$pending'] == true) {
      return Completer<Never>().future;
    }
    if (answer is Map && answer['\$status'] != null) {
      return Future<Never>.error(
        RaftApiException(
          '${(answer['\$body'] as Map?)?['error'] ?? 'fixture error'}',
          status: (answer['\$status'] as num).toInt(),
        ),
      );
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
    final special = _special('GET', '/messages/channel/$id');
    if (special != null) return special as Future<Map<String, dynamic>>;
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
    final special = _special(method, path);
    if (special != null) return special as Future<dynamic>;
    // The server honours `?status=` on the channel task list (one board lane
    // per call) and answers `next_cursor: null` for a short window.
    final status = query?['status'];
    final tasks = routes['GET $path'];
    if (method == 'GET' &&
        path.startsWith('/tasks/channel/') &&
        status is String &&
        tasks is Map &&
        tasks['tasks'] is List) {
      return Future<dynamic>.value({
        'tasks': [
          for (final row in tasks['tasks'] as List)
            if ((row as Map)['status'] == status) row,
        ],
        'next_cursor': null,
      });
    }
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
  final routeSet =
      (fx['routeSets'] as Map)[ctx.props['routeSet']] as Map? ?? {};
  final client = _ConvClient(
    user: base.authUser,
    routes: {
      ...Map<String, dynamic>.from(fx['routes'] as Map),
      // Same directory the React host seeds (visualAgents / visualMembers).
      'GET /agents': ids.agents,
      'GET /servers/visual-server/members': ids.members,
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
  final role = ctx.props['serverRole'] as String? ?? 'owner';
  final w = WorkspaceController(client)
    ..server = RaftRecord({...base.serverRecord, 'role': role})
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
  final rail = 56.0;
  return switch (ctx.props['surface']) {
    'thread' => Rect.fromLTWH(ctx.width - 400, top, 400, h),
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
    final id = ctx.props['chan'] as String? ?? '';
    if (id.isEmpty) return;
    final channel = [...w.channels, ...w.dms].firstWhere((c) => c.id == id);
    final msg = ctx.props['msg'] as String?;
    if (msg != null) {
      unawaited(w.jumpToMessage(id, msg));
    } else {
      unawaited(w.selectChannel(channel));
    }
    if (ctx.props['surface'] == 'thread') {
      final thread = Map<String, dynamic>.from(
        (fx['threads'] as Map)[ctx.props['threadKey'] ?? 'main'] as Map,
      );
      final failed = ctx.props['resolveFailed'] == true;
      await w.openThreadIdentity(
        parentChannelId: thread['parentChannelId'] as String,
        parentMessageId: thread['parentMessageId'] as String,
        initialThreadChannelId: failed
            ? null
            : thread['threadChannelId'] as String,
      );
    }
  }

  @override
  Widget build(BuildContext context) => withAppServices(
    WorkspaceView(
      controller: w,
      appearance: RaftAppearance(
        mode: widget.ctx.dark ? ThemeMode.dark : ThemeMode.light,
      ),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
}

Widget _buildWindow(ParityContext ctx) {
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

/// Window case that first opens a conversation tab (`props.tab`: files / tasks).
final ParityCase _tabCase = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:ConversationPanel',
    'raft_ui:RaftConversationTabs',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView, channel tab, clipped window.',
  settle: const Duration(milliseconds: 1200),
  build: _buildWindow,
  interact: (t, ctx) async {
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final tab = ctx.props['convTab'] == 'files' ? 'Files' : 'Tasks';
    await t.tap(
      find
          .descendant(
            of: find.byKey(const Key('conversation-tabs')),
            matching: find.text(tab),
          )
          .first,
    );
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  },
);

/// In-thread search (3.38): overflow menu -> "Search in Thread" -> optional query.
ParityCase _threadSearchCase(String? query) => ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:RaftChatView',
    'raft_ui:RaftThreadSearchBar',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView thread panel, in-thread search bar.',
  settle: const Duration(milliseconds: 1200),
  build: _buildWindow,
  interact: (t, ctx) async {
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.tap(find.byKey(const Key('thread-options')).first);
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.tap(find.text('Search in Thread'));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    if (query != null) {
      await t.enterText(find.byKey(const Key('thread-search-input')), query);
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }
  },
);

/// External identity detail panel (3.29): the panel in the bordered box of the
/// React host (`view=external-detail`).
final ParityCase _externalDetailCase = ParityCase(
  widgets: const [
    'raft_flutter:ExternalIdentityDetailPanel',
    'raft_ui:RaftExternalIdentityBody',
  ],
  notes: 'Extension suite (not official). Real ExternalIdentityDetailPanel in a bordered box.',
  settle: const Duration(milliseconds: 600),
  build: (ctx) {
    final w = _workspace(ctx);
    final mobile = ctx.props['platform'] == 'mobile';
    final tokens = RaftTokens.theme(dark: ctx.dark);
    return Align(
      alignment: Alignment.topLeft,
      child: ctx.target(
        SizedBox(
          width: (ctx.props['boxWidth'] as num).toDouble(),
          height: (ctx.props['boxHeight'] as num).toDouble(),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.panel,
              border: Border.all(color: tokens.colors['line-muted']!, width: 1),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ExternalIdentityDetailPanel(
                controller: w,
                profile: Map<String, dynamic>.from(
                  _fx(ctx)['externalProfile'] as Map,
                ),
                onClose: () {},
                // Below md the header leads with the back chevron.
                onBack: mobile ? () {} : null,
              ),
            ),
          ),
        ),
      ),
    );
  },
);

/// Thread agent followers (3.39): the header trigger, optionally opened.
ParityCase _followersCase({required bool open}) => ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:ThreadAgentFollowersView',
    'raft_ui:RaftThreadFollowers',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView thread header, followers trigger / popover.',
  settle: const Duration(milliseconds: 1200),
  build: _buildWindow,
  interact: (t, ctx) async {
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    if (open) {
      await t.tap(find.byKey(const Key('thread-followers-header-trigger')));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }
  },
);

final ParityCase _threadCase = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:RaftChatView',
    'raft_ui:RaftThreadPanel',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView thread panel, clipped window.',
  settle: const Duration(milliseconds: 1200),
  build: _buildWindow,
);

/// Selection mode on the main column: right-click the first row -> "Select
/// Message" (`props.rows`: how many rows end up selected, 1 or 2).
/// The [i]-th message row from the top of the timeline (the widget tree lists
/// the newest row first).
Finder _rowFromTop(int i) {
  final rows = find.byType(RaftMessageRow).evaluate().toList()
    ..sort(
      (a, b) => (a.renderObject! as RenderBox)
          .localToGlobal(Offset.zero)
          .dy
          .compareTo(
            (b.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
          ),
    );
  return find.byWidget(rows[i].widget);
}

Future<void> _selectRows(WidgetTester t, {required bool second}) async {
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final row = _rowFromTop(0);
  final box = find.descendant(of: row, matching: find.byType(Container)).first;
  await t.tapAt(
    t.getCenter(box),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.tap(find.text('Select Message'));
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  if (second) {
    final next = find.descendant(
      of: _rowFromTop(1),
      matching: find.byType(Container),
    );
    await t.tapAt(t.getCenter(next.first));
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }
}

/// Selection mode on the main column: right-click the first row -> "Select
/// Message", optionally tap the second row too.
ParityCase _selectCase({required bool second}) => ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:MessageSelection',
    'raft_ui:RaftSelectionToolbar',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView, selection mode.',
  settle: const Duration(milliseconds: 1200),
  build: _buildWindow,
  interact: (t, ctx) => _selectRows(t, second: second),
);

final ParityCase _forwardCase = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:ForwardMessagesDialog',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView, selection toolbar -> forward dialog.',
  settle: const Duration(milliseconds: 1200),
  build: _buildWindow,
  interact: (t, ctx) async {
    await _selectRows(t, second: true);
    await t.tap(find.text('Forward').first);
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  },
);

final ParityCase _windowCase = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:RaftChatView',
    'raft_ui:RaftConversationSurface',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView, clipped window.',
  settle: const Duration(milliseconds: 1200),
  build: _buildWindow,
);

// --------------------------------------------------------------------------
// view=row: one message row on a panel-coloured box (Web MessageItem)
// --------------------------------------------------------------------------

/// The column background messages sit on (`bg-layer-panel`, brutal white).
Color _panel(BuildContext context) {
  final t = RaftTokens.of(context);
  return t.panel;
}

/// [ChatStage] whose capture canvas is painted with the panel colour (the
/// official stage hard-codes white, right only for the light themes).
class _RowStage extends ChatStage {
  _RowStage(
    super.ctx, {
    required super.messages,
    required super.rowWidth,
    required super.rowOrigin,
    required Size super.canvas,
    super.threadSummaries,
    super.tasks,
  });

  @override
  Widget build() {
    final canvas = this.canvas!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder(
        valueListenable: geometry,
        builder: (context, g, _) {
          final (chatWidth, shift, _) = g;
          final windowed = ClipRect(
            child: SizedBox(
              width: g.$3?.width ?? chatWidth,
              height: g.$3?.height ?? 844,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: chatWidth,
                maxWidth: chatWidth,
                minHeight: 1800,
                maxHeight: 1800,
                child: Transform.translate(
                  offset: shift,
                  child: RaftChatView(key: chatKey, controller: w),
                ),
              ),
            ),
          );
          // A zero canvas height is the CSS auto height: the row plus its top inset.
          final size = canvas.height > 0
              ? canvas
              : Size(canvas.width, rowOrigin.dy + (g.$3?.height ?? 120));
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: ctx.target(
                  SizedBox.fromSize(
                    size: size,
                    child: ClipRect(
                      child: ColoredBox(
                        color: _panel(context),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: rowOrigin.dx,
                              top: rowOrigin.dy,
                              child: windowed,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

_RowStage _rowStage(ParityContext ctx) {
  final row = Map<String, dynamic>.from(
    (_fx(ctx)['rows'] as Map)[ctx.props['row']] as Map,
  );
  final message = Map<String, dynamic>.from(row['message'] as Map);
  // The React host fills the page origin into permalink fixtures.
  message['content'] = (message['content'] as String).replaceAll(
    '__ORIGIN__',
    'https://parity-fixture.invalid',
  );
  final width = (ctx.props['boxWidth'] as num?)?.toDouble() ?? 440;
  // No boxHeight: the box is as tall as its row (CSS auto height), height 0.
  final height = (ctx.props['boxHeight'] as num?)?.toDouble() ?? 0;
  final padX = (ctx.props['padX'] as num?)?.toDouble() ?? 16;
  final padTop = (ctx.props['padTop'] as num?)?.toDouble() ?? 32;
  final summary = row['threadSummary'];
  final task = row['linkedTask'];
  final stage = _RowStage(
    ctx,
    rowWidth: width - 2 * padX,
    rowOrigin: Offset(padX, padTop),
    canvas: Size(width, height),
    messages: [
      {'threadId': null, ...message},
    ],
    threadSummaries: summary == null
        ? const {}
        : {message['id'] as String: Map<String, dynamic>.from(summary as Map)},
    tasks: task == null ? const [] : [Map<String, dynamic>.from(task as Map)],
  );
  // The fixture's routes (activity log, ...) on top of the stage's defaults.
  final routeSet =
      (_fx(ctx)['routeSets'] as Map)[ctx.props['routeSet']] as Map? ?? {};
  for (final MapEntry(:key, :value) in {
    ...Map<String, dynamic>.from(_fx(ctx)['routes'] as Map),
    ...Map<String, dynamic>.from(routeSet),
  }.entries) {
    stage.client.routes[key] = (_) {
      if (value is Map && value['\$pending'] == true) {
        return Completer<Never>().future;
      }
      if (value is Map && value['\$status'] != null) {
        throw RaftApiException(
          '${(value['\$body'] as Map?)?['error'] ?? 'fixture error'}',
          status: (value['\$status'] as num).toInt(),
        );
      }
      return value;
    };
  }
  // Translation rows: auto-translate into zh-CN (the account preferences the
  // translation store reads; the settings / batch answers come from routes).
  final translate = ctx.props['translate'] as String? ?? '';
  if (translate.isNotEmpty) {
    stage.client.user = RaftRecord({
      ...stage.client.user!.json,
      'preferredLanguage': 'zh-CN',
      'autoTranslationEnabled': true,
      'preferredTranslationMode': 'auto',
      'preferredTranslationDisplay': translate == 'bilingual'
          ? 'bilingual'
          : 'translated',
    });
  }
  // The React capture never receives the inline media URL (the card sits in its
  // pre-load state); the Flutter media URL read stays pending the same way.
  for (final id in const ['att-cv-audio', 'att-cv-video']) {
    stage.client.routes['GET /attachments/$id/url'] = (_) =>
        Completer<Never>().future;
  }
  // The server's computer list (Computer fact of the profile card).
  final machine = Map<String, dynamic>.from(
    ctx.fixtureData['machines']['primary'] as Map,
  );
  stage.client.routes['GET /servers/visual-server/machines'] = (_) => {
    'machines': [
      {
        'id': machine['id'],
        'name': machine['name'],
        'status': 'online',
        'runtimes': ['codex', 'claude'],
        'hostname': machine['hostname'],
        'isComputer': true,
      },
    ],
  };
  return stage;
}

Future<void> _pumpFrames(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// A mouse that stays on the page until the case ends, like Playwright's.
Future<TestGesture> _mouse(WidgetTester t) async {
  final g = await t.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  return g;
}

/// Profile preview card (3.27) and its recent-activity section (3.28): the
/// pointer rests on the sender avatar until the hover card opens.
final ParityCase _profileCase = _profileCaseFor();

ParityCase _profileCaseFor() => ParityCase(
  widgets: const [
    'raft_flutter:RaftChatView',
    'raft_flutter:ProfilePreviewHoverCard',
    'raft_ui:RaftProfilePreviewCard',
  ],
  notes: 'Extension suite (not official). Real RaftChatView row, hover card on the avatar.',
  settle: const Duration(milliseconds: 300),
  build: (ctx) => stageFor(ctx, () => _rowStage(ctx)).build(),
  interact: (t, ctx) async {
    final stage = stageFor(ctx, () => _rowStage(ctx));
    stage.w.entityDirectory.ensure({WorkspaceEntityKind.computers});
    await _pumpFrames(t);
    await stage.alignRow(t);
    final mouse = await _mouse(t);
    final card = find.byType(ProfilePreviewHoverCard).evaluate().isNotEmpty
        ? find.byType(ProfilePreviewHoverCard)
        : find.byType(ExternalIdentityHoverCard);
    await mouse.moveTo(t.getCenter(card.first));
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  },
);

/// A plain row case: the real RaftChatView row on the panel-coloured box; the
/// optional [act] runs once the row is aligned (hover, click, ...).
ParityCase _rowCase({
  List<String> widgets = const [],
  Future<void> Function(WidgetTester t, ParityContext ctx, _RowStage stage)?
  act,
  Duration settle = const Duration(milliseconds: 300),
}) => ParityCase(
  widgets: ['raft_flutter:RaftChatView', 'raft_ui:RaftMessageRow', ...widgets],
  notes: 'Extension suite (not official). Real RaftChatView row on a panel-coloured box.',
  settle: settle,
  build: (ctx) => stageFor(ctx, () => _rowStage(ctx)).build(),
  interact: (t, ctx) async {
    final stage = stageFor(ctx, () => _rowStage(ctx)) as _RowStage;
    // The workspace bootstrap loads the directories the rows resolve names
    // from; they must land before the row is measured (a longer name re-wraps).
    stage.w.entityDirectory.ensure({WorkspaceEntityKind.computers});
    // Translations land before the row is measured (a translated body re-wraps).
    await _pumpFrames(
      t,
      (ctx.props['translate'] as String? ?? '').isEmpty ? 8 : 40,
    );
    await stage.alignRow(t);
    await act?.call(t, ctx, stage);
    await _pumpFrames(t);
  },
);

/// Web keeps playback/error states inside the row; all Flutter timeline
/// variants intentionally remain posters. Playback is covered in the viewer.
ParityCase _videoCase({Future<void> Function(WidgetTester t)? act}) {
  final base = _rowCase(
    widgets: const [
      'raft_flutter:InlineVideoAttachment',
      'raft_ui:RaftVideoPosterCard',
    ],
    act: (t, ctx, stage) async {
      await _pumpFrames(t, 12);
      await act?.call(t);
      await _pumpFrames(t, 6);
    },
  );
  return ParityCase(
    widgets: base.widgets,
    notes:
        '${base.notes} Intentional: timeline videos are poster-only on every platform (owner decision 2026-10-17); playback/error UI lives in the viewer, unlike Web.',
    settle: base.settle,
    build: base.build,
    interact: base.interact,
  );
}

Future<void> _hoverVideo(WidgetTester t) async {
  final mouse = await _mouse(t);
  await mouse.moveTo(t.getCenter(find.byKey(const Key('inline-video'))));
  await _pumpFrames(t, 8);
}

/// Every extension conversation-page case, keyed by id (3 themes each).
final Map<String, ParityCase> extConversationCases = () {
  final cases = <String, ParityCase>{};
  void add(String scene, String platform, String state, ParityCase c) {
    for (final theme in const ['brutal', 'elegant', 'elegant-dark']) {
      cases['components.conversation.$scene.$platform.$state.$theme'] = c;
    }
  }

  add('empty', 'desktop', 'no-channel', _windowCase);
  add('selection', 'desktop', 'one', _selectCase(second: false));
  add('selection', 'desktop', 'two', _selectCase(second: true));
  add('forward', 'desktop', 'dialog', _forwardCase);
  for (final platform in const ['desktop', 'mobile']) {
    for (final state in const [
      'load-failed',
      'guest-readonly',
      'joint-locked',
      'join-parent',
    ]) {
      add('threadstate', platform, state, _threadCase);
    }
  }
  for (final platform in const ['desktop', 'mobile']) {
    add('threadsearch', platform, 'open', _threadSearchCase(null));
    add('threadsearch', platform, 'matches', _threadSearchCase('parity'));
    add('threadsearch', platform, 'none', _threadSearchCase('zzzz'));
  }
  for (final platform in const ['desktop', 'mobile']) {
    add('external', platform, 'detail', _externalDetailCase);
  }
  for (final platform in const ['desktop', 'mobile']) {
    add('followers', platform, 'header', _followersCase(open: false));
    add('followers', platform, 'popover', _followersCase(open: true));
    add('followers', platform, 'error', _followersCase(open: true));
  }
  for (final platform in const ['desktop', 'mobile']) {
    for (final state in const ['list', 'more', 'empty', 'loading', 'error']) {
      add('files', platform, state, _tabCase);
    }
    for (final state in const ['list', 'empty']) {
      add('tasks', platform, state, _tabCase);
    }
  }
  for (final state in const ['agent', 'agent-activity', 'human']) {
    add('profile', 'desktop', state, _profileCase);
  }
  add('external', 'desktop', 'card', _profileCase);
  for (final state in const ['default', 'task']) {
    add(
      'menu',
      'desktop',
      state,
      _rowCase(
        widgets: const ['raft_ui:RaftMessageContextMenu'],
        act: (t, ctx, stage) async {
          // A device runs resumed: the body's SelectableRegion clears its
          // collapsed right-click selection when the opened menu takes focus.
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          final row = find.byType(RaftMessageRow).first;
          final box = find
              .descendant(of: row, matching: find.byType(Container))
              .first;
          await t.tapAt(
            t.getCenter(box),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await _pumpFrames(t, 12);
        },
      ),
    );
  }
  for (final platform in const ['desktop', 'mobile']) {
    add(
      'mermaid',
      platform,
      'fullscreen',
      _rowCase(
        widgets: const ['raft_ui:RaftMermaidFullscreen'],
        settle: const Duration(milliseconds: 900),
        act: (t, ctx, stage) async {
          // The diagram renders natively; the toolbar's expand control is
          // enabled once the scene is ready.
          await _pumpFrames(t, 30);
          await t.tap(find.byTooltip('Expand Diagram').first);
          await _pumpFrames(t, 30);
        },
      ),
    );
  }
  for (final platform in const ['desktop', 'mobile']) {
    for (final state in const [
      'text',
      'attachment',
      'archived',
      'loading',
      'unavailable',
    ]) {
      add(
        'quote',
        platform,
        state,
        _rowCase(
          widgets: const [
            'raft_flutter:QuotedMessagePermalinkPreview',
            'raft_ui:RaftQuotedMessageCard',
          ],
          settle: const Duration(milliseconds: 600),
        ),
      );
    }
  }
  for (final platform in const ['desktop', 'mobile']) {
    for (final kind in const ['audio', 'video', 'pdf', 'patch']) {
      add('attach', platform, kind, _rowCase());
    }
  }
  for (final platform in const ['desktop', 'mobile']) {
    add('attach', platform, 'video-poster', _videoCase());
    add('attach', platform, 'video-error', _videoCase());
  }
  add('attach', 'desktop', 'video-hover', _videoCase(act: _hoverVideo));
  add('attach', 'desktop', 'video-playing', _videoCase());
  for (final platform in const ['desktop', 'mobile']) {
    for (final state in const [
      'translating',
      'translated',
      'bilingual',
      'failed',
    ]) {
      add('translate', platform, state, _rowCase());
    }
  }
  for (final platform in const ['desktop', 'mobile']) {
    for (final state in const ['single', 'multi']) {
      add(
        'reactions',
        platform,
        state,
        _rowCase(widgets: const ['raft_ui:RaftMountedReaction']),
      );
    }
  }
  add(
    'reactions',
    'desktop',
    'tooltip',
    _rowCase(
      widgets: const ['raft_ui:RaftMountedReaction'],
      act: (t, ctx, stage) async {
        final mouse = await _mouse(t);
        await mouse.moveTo(t.getCenter(find.byType(RaftMountedReaction).first));
        await _pumpFrames(t, 14);
      },
    ),
  );
  for (final platform in const ['desktop', 'mobile']) {
    for (final state in const [
      'install-app',
      'create-agent',
      'channel-members',
      'owner-recovery',
      'executed',
    ]) {
      add(
        'action',
        platform,
        state,
        _rowCase(widgets: const ['raft_flutter:MessageActionCard']),
      );
    }
  }
  for (final platform in const ['desktop', 'mobile']) {
    for (final state in const [
      'archived',
      'archived-header',
      'guest-readonly',
      'guest-join',
      'join',
      'joint-locked',
      'joint-grace',
      'message-not-found',
    ]) {
      add('banner', platform, state, _windowCase);
    }
  }
  return cases;
}();

/// Cases whose Web page has no Flutter counterpart (`Flutter page missing`):
/// they stay in the manifest as honest gaps instead of faked captures.
final Map<String, ParityUncovered> extConversationUncovered = () {
  final gaps = <String, ParityUncovered>{};
  return gaps;
}();
