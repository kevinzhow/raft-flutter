// raft-flutter parity EXTENSION suite builders (tool/parity-ext): message-level
// surfaces the official 99 cases do not cover. NOT official cases; ids are
// `components.thread-ext.message.<surface>.<platform>.<theme>`, dispatched on
// props like tool/parity-ext/host/ThreadMessageCases.tsx.
//
//   toolbar*, picker*  the REAL RaftChatView row (RaftMessageRow + its hover
//                      toolbar overlay, RaftQuickReactionPicker) over the
//                      official canned client, windowed onto a panel-coloured
//                      box exactly like the React wrapper (row at 16,32)
//   forward-*          RaftForwardedBundle (what MessagePresentation mounts)
//   mermaid-*          RaftMermaidBlock (toolbar + frame; the SVG comes from
//                      the package renderer and differs from Mermaid.js)
//   banner             no production Flutter surface (Web Push opt-in): the
//                      closest real widgets are composed (RaftBanner + the
//                      accent RaftRecipeButton + RaftCloseButton)
//   sos-*              RaftSosDialog over RaftModalBackdrop, like
//                      ChannelSettings.stopAgents mounts it
//
// Data: tool/parity-ext/fixtures/threadmessages.json (fixtures['ext:threadmessages']).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'thread_messages/chat_stage.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:threadmessages'] as Map<String, dynamic>;

/// The column background messages sit on (`bg-layer-panel`, brutal white).
Color _panel(BuildContext context) {
  final t = RaftTokens.of(context);
  return t.panel;
}

// --------------------------------------------------------------------------
// Hover toolbar and reaction picker
// --------------------------------------------------------------------------

/// [ChatStage] whose capture canvas is painted with the panel colour (the
/// official stage hard-codes white, right only for the light themes).
class _RowStage extends ChatStage {
  _RowStage(
    super.ctx, {
    required super.messages,
    required super.rowWidth,
    required super.rowOrigin,
    required Size super.canvas,
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
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: ctx.target(
                  SizedBox.fromSize(
                    size: canvas,
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
  final ids = ParityIdentities(ctx);
  final m = _fx(ctx)['message'] as Map<String, dynamic>;
  final width = (ctx.props['boxWidth'] as num?)?.toDouble() ?? 440;
  final height = (ctx.props['boxHeight'] as num?)?.toDouble() ?? 112;
  return _RowStage(
    ctx,
    rowWidth: width - 32,
    rowOrigin: const Offset(16, 32),
    canvas: Size(width, height),
    messages: [
      {
        'id': m['id'],
        'channelId': 'channel-design',
        'senderType': 'agent',
        'senderId': ids.cindy['id'],
        'senderName': ids.cindy['displayName'],
        'content': m['content'],
        'threadId': null,
        'createdAt': m['createdAt'],
      },
    ],
  );
}

Finder _rowFinder() => find.byType(RaftMessageRow).first;

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

ParityCase _rowCase() => ParityCase(
  widgets: const [
    'raft_flutter:RaftChatView',
    'raft_ui:RaftMessageRow',
    'raft_ui:RaftMessageToolbar',
    'raft_ui:RaftQuickReactionPicker',
  ],
  notes: 'Extension suite (not official). Real RaftChatView row, windowed.',
  settle: const Duration(milliseconds: 300),
  build: (ctx) => stageFor(ctx, () => _rowStage(ctx)).build(),
  interact: (t, ctx) async {
    final stage = stageFor(ctx, () => _rowStage(ctx));
    await stage.alignRow(t);
    final id = (_fx(ctx)['message'] as Map)['id'] as String;
    final mouse = await _mouse(t);
    final state = ctx.props['state'] as String;
    // Playwright hovers the centre of `#message-<id>` (the row box).
    await mouse.moveTo(t.getCenter(_rowFinder()));
    await _pumpFrames(t);
    Finder reaction() => find.byKey(ValueKey('message-react-$id'));
    switch (state) {
      case 'toolbar-button-hover':
        await mouse.moveTo(t.getCenter(reaction()));
      case 'picker' || 'picker-emoji-hover':
        await mouse.moveTo(t.getCenter(reaction()));
        await t.pump(const Duration(milliseconds: 50));
        await mouse.down(t.getCenter(reaction()));
        await mouse.up();
        await _pumpFrames(t);
        if (state == 'picker-emoji-hover') {
          await mouse.moveTo(
            t.getCenter(find.byKey(const ValueKey('quick-reaction-🎉'))),
          );
        }
    }
    await _pumpFrames(t);
  },
);

// --------------------------------------------------------------------------
// Forwarded bundle
// --------------------------------------------------------------------------

ParityCase _forwardCase() => ParityCase(
  widgets: const [
    'raft_flutter:MessagePresentation',
    'raft_ui:RaftForwardedBundle',
  ],
  notes:
      'Extension suite (not official). MessagePresentation mounts '
      'RaftForwardedBundle for a forwarded-bundle actionMetadata.',
  settle: const Duration(milliseconds: 400),
  build: (ctx) {
    final width = (ctx.props['boxWidth'] as num).toDouble();
    final bundle = Map<String, dynamic>.from(
      (_fx(ctx)['bundles'] as Map)[ctx.props['bundle']] as Map,
    );
    final ids = ParityIdentities(ctx);
    final w = WorkspaceController(ParityRaftClient({}, user: ids.user))
      ..server = RaftRecord(ids.server)
      ..channel = RaftChannel(ids.channel('design'))
      ..channels = [RaftChannel(ids.channel('design'))];
    addTearDown(w.dispose);
    final message = RaftMessage({
      'id': 'msg-parity-ext-forward',
      'messageType': 'chat',
      'serverId': ids.serverId,
      'seq': 1,
      'channelId': 'channel-design',
      'senderType': 'agent',
      'senderId': ids.cindy['id'],
      'senderName': ids.cindy['displayName'],
      'content': '',
      'threadId': null,
      'createdAt': '2026-06-22T02:40:00.000Z',
      'actionMetadata': bundle,
    });
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.topLeft,
        child: ctx.target(
          Builder(
            builder: (context) => Container(
              width: width,
              color: _panel(context),
              // A Column hands its child unbounded height, like the message
              // content column does in the timeline.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The Web capture clips the card box: its `mt-1` margin
                  // collapses out of the harness root (the message body's own
                  // margin absorbs it in the timeline).
                  RaftMessageBodyMargin(
                    gap: 4,
                    child: MessagePresentation(
                      controller: w,
                      message: message,
                      onExternalLink: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  },
  interact: (t, ctx) async {
    await _pumpFrames(t, 10);
    if (ctx.id.contains('.forward-expanded.')) {
      await t.tap(
        find.descendant(
          of: find.byType(RaftForwardedBundle),
          matching: find.byType(RaftShowMoreToggle),
        ),
      );
      await _pumpFrames(t, 6);
    }
  },
);

// --------------------------------------------------------------------------
// Mermaid
// --------------------------------------------------------------------------

ParityCase _mermaidCase() => ParityCase(
  widgets: const ['raft_ui:RaftMermaidBlock'],
  notes:
      'Extension suite (not official). Toolbar and frame are comparable; '
      'the diagram SVG comes from the package renderer, not Mermaid.js.',
  settle: const Duration(milliseconds: 600),
  build: (ctx) {
    final width = (ctx.props['boxWidth'] as num).toDouble();
    final source = (_fx(ctx)['mermaid'] as Map)[ctx.props['diagram']] as String;
    return Align(
      alignment: Alignment.topLeft,
      child: Builder(
        builder: (context) => Container(
          width: width,
          color: _panel(context),
          child: Material(
            type: MaterialType.transparency,
            child: RaftMermaidBlock(
              source: source,
              // The app passes both (MessagePresentation.saveDiagram); the
              // download menu is disabled without an exporter.
              onExport: (_, _) async {},
            ),
          ),
        ),
      ),
    );
  },
  interact: (t, ctx) async {
    await _pumpFrames(t, 10);
    if (ctx.id.contains('.mermaid-code.')) {
      await t.tap(find.text('Code'));
      await _pumpFrames(t, 6);
    }
  },
);

// --------------------------------------------------------------------------
// Notification activation banner
// --------------------------------------------------------------------------

ParityCase _bannerCase() => ParityCase(
  widgets: const [
    'raft_ui:RaftBanner',
    'raft_ui:RaftRecipeButton',
    'raft_ui:RaftCloseButton',
  ],
  notes:
      'Extension suite (not official). The Flutter app has no Web Push '
      'activation banner; the closest real widgets are composed.',
  settle: const Duration(milliseconds: 300),
  build: (ctx) {
    final width = (ctx.props['boxWidth'] as num).toDouble();
    final mobile = ctx.props['platform'] == 'mobile';
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.topLeft,
        child: ctx.target(
          Builder(
            builder: (context) => Container(
              width: width,
              color: _panel(context),
              // desktop placement: `mx-3 mb-0 mt-2 w-auto min-w-0`.
              padding: mobile
                  ? EdgeInsets.zero
                  : const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: RaftBanner(
                status: RaftBannerRecipeStatus.info,
                size: RaftBannerRecipeSize.sm,
                glyph: RaftGlyph.bell,
                title: mobile
                    ? 'Agents keep working after you leave.'
                    : 'Your agents keep working after you leave.',
                description: mobile
                    ? 'Get notified when they finish or need you.'
                    : "Turn on notifications so you don't miss when they finish or need you.",
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RaftRecipeButton(
                      variant: RaftButtonRecipeVariant.accent,
                      size: RaftButtonRecipeSize.sm,
                      label: 'Enable Notifications',
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    RaftCloseButton(
                      onPressed: () {},
                      tooltip: 'Hide Notification Reminder for This Session',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
);

// --------------------------------------------------------------------------
// SOS dialog
// --------------------------------------------------------------------------

ParityCase _sosCase() => ParityCase(
  widgets: const ['raft_ui:RaftSosDialog', 'raft_ui:RaftModalBackdrop'],
  notes:
      'Extension suite (not official). Real RaftSosDialog over the modal '
      'backdrop; stop / resume callbacks resolve like a 200 from the API.',
  settle: const Duration(milliseconds: 300),
  build: (ctx) {
    final sos = _fx(ctx)['sos'] as Map<String, dynamic>;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
          Positioned.fill(
            child: RaftModalBackdrop(
              child: KeyedSubtree(
                key: const ValueKey('sos-dialog-card'),
                child: RaftSosDialog(
                  channelName: sos['channelName'] as String,
                  onStop: () async => null,
                  onResume: (_) async => null,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  },
  interact: (t, ctx) async {
    await _pumpFrames(t, 4);
    if (ctx.id.contains('.sos-stopped.') || ctx.id.contains('.sos-guidance.')) {
      await t.tap(find.byKey(const ValueKey('sos-stop')));
      await _pumpFrames(t, 8);
    }
    if (ctx.id.contains('.sos-guidance.')) {
      final sos = _fx(ctx)['sos'] as Map<String, dynamic>;
      await t.enterText(
        find.byType(EditableText).last,
        sos['guidance'] as String,
      );
      await _pumpFrames(t, 4);
    }
  },
);

const _hoverStates = [
  'toolbar',
  'toolbar-saved',
  'toolbar-thread',
  'toolbar-button-hover',
  'picker',
  'picker-emoji-hover',
];

/// Every extension message-surface case, keyed by id (3 themes each).
final Map<String, ParityCase> extThreadMessageCases = () {
  final cases = <String, ParityCase>{};
  void add(String platform, String surface, ParityCase c) {
    for (final theme in const ['brutal', 'elegant', 'elegant-dark']) {
      cases['components.thread-ext.message.$surface.$platform.$theme'] = c;
    }
  }

  for (final s in _hoverStates) {
    add('desktop', s, _rowCase());
  }
  for (final s in const [
    'forward-single',
    'forward-multi',
    'forward-expanded',
    'forward-thread',
    'forward-restricted',
  ]) {
    add('desktop', s, _forwardCase());
  }
  add('mobile', 'forward-single', _forwardCase());
  add('mobile', 'forward-multi', _forwardCase());
  for (final s in const [
    'mermaid-toolbar',
    'mermaid-code',
    'mermaid-diagram',
  ]) {
    add('desktop', s, _mermaidCase());
  }
  add('mobile', 'mermaid-toolbar', _mermaidCase());
  add('desktop', 'banner', _bannerCase());
  add('mobile', 'banner', _bannerCase());
  for (final s in const ['sos-confirm', 'sos-stopped', 'sos-guidance']) {
    add('desktop', s, _sosCase());
  }
  add('mobile', 'sos-confirm', _sosCase());
  return cases;
}();
