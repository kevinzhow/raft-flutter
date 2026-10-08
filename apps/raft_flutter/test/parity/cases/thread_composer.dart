import 'dart:convert';

// Official cases owned by this group (default selection):
//   components.thread.composer.empty
//   components.thread.composer.states
//   components.thread.composer.pending-mention-actions
//   components.thread.composer.as-task-selected
//   components.thread.composer.member-suggestions
//   components.thread.composer.channel-suggestions
//   components.thread.composer.image-preview
//   components.thread.files.list
//   components.thread.header.states
//
// Builders render the real Flutter app/raft_ui widgets for each case, laid
// out like the React render host fixture for the same case id. Cases the
// Flutter app cannot show go to [threadComposerUncovered] with an honest reason.
//
// React host (VisualTestingCases.tsx ComposerVisualCaseView): a
// `<div data-visual-case>` of 342 x (height||100) with paddingTop
// composerOffsetTop, overflow hidden, containing <MessageInput>. Flutter's
// MessageInput is RaftComposer as mounted by RaftChatView (chat_view.dart):
// the same taskAction / attach / image-pick / hint / suggestions wiring is
// reproduced in [_ComposerHost]; suggestions come from the real
// ComposerDirectory over a WorkspaceController whose client answers the React
// provider's API mocks (thread_composer/fake_workspace.dart).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/composer_directory.dart';
import 'package:raft_flutter/features/pending_mention_actions.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'thread_composer/fake_workspace.dart';

final Map<String, ParityCase> threadComposerCases = {
  'components.thread.composer.empty': _composer(draft: ''),
  'components.thread.composer.states': _composer(
    draft: _seed,
    notes:
        'React host seeds fxMessages.composerSeed (not the manifest prop '
        'draft); the same seed is used.',
  ),
  'components.thread.composer.as-task-selected': _composer(
    draft: _seed,
    tapTaskToggle: true,
    notes:
        'React clicks [data-testid=composer-as-task-toggle]; Flutter taps the '
        'RaftComposerTaskToggle the app mounts (Key composer-as-task).',
  ),
  'components.thread.composer.member-suggestions': _composer(
    draft: '',
    height: 320,
    offsetTop: 210,
    type: '@',
    notes:
        'Suggestions come from the real ComposerDirectory over the React '
        'provider API mocks (channel roster, server members, /agents).',
  ),
  'components.thread.composer.channel-suggestions': _composer(
    draft: '',
    height: 320,
    offsetTop: 210,
    type: '#',
    notes:
        'Channel suggestions come from ComposerDirectory over the three '
        'channels primeVisualStores seeds (design, product, android-artifacts).',
  ),
  'components.thread.composer.image-preview': _composer(
    draft: null,
    height: 210,
    readyImage: true,
    widgets: const [
      'raft_flutter:WorkspaceController.attachSelection',
      'raft_ui:RaftComposerNotice',
    ],
    notes:
        'React picks composer-preview.png (the PNG bytes react-provider.spec '
        'uploads); Flutter feeds the same bytes to the product selection path '
        '(WorkspaceController.attachSelection). GET '
        '/attachments/upload-capabilities has no usable maxBytes in both mocks, '
        'so both refuse the batch with the warning banner.',
  ),
  'components.thread.composer.pending-mention-actions': _composer(
    draft: '@Android-Developer-4 please review the visual diff',
    height: 290,
    sendForPendingMentions: true,
    widgets: const [
      'raft_flutter:WorkspaceController.send',
      'raft_flutter:PendingMentionActions',
      'raft_ui:RaftPendingMentionActionStrip',
    ],
    notes:
        'React clicks Send; its sendMessage mock answers one '
        'pendingMentionActions row (agent Android-Developer-4, add+notify). '
        'Flutter clicks the composer Send with a mouse: WorkspaceController.send '
        'posts /v2/messages to the fake client, which returns the same receipt, '
        'and RaftChatView\'s accessory PendingMentionActions renders the strip. '
        'The mouse stays where Send was, so (like React) it hovers Ignore.',
  ),
  'components.thread.files.list': _files,
  'components.thread.header.states': _header,
};

final Map<String, ParityUncovered> threadComposerUncovered = {};

const _composerPreviewPng =
    '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';

String get _seed => 'Review the Android composer crop before release.';

ParityCase _composer({
  required String? draft,
  double height = 100,
  double offsetTop = 0,
  String? type,
  bool tapTaskToggle = false,
  bool readyImage = false,
  bool sendForPendingMentions = false,
  List<String> widgets = const [],
  String notes = '',
}) => ParityCase(
  widgets: [
    'raft_ui:RaftComposer',
    'raft_ui:RaftComposerTaskToggle',
    'raft_ui:RaftComposerAction',
    if (type != null) 'raft_flutter:ComposerDirectory',
    ...widgets,
  ],
  notes: [
    'Hint = the React host placeholder override (fxMessages.composerPlaceholder).',
    if (notes.isNotEmpty) notes,
  ].join(' '),
  build: (ctx) {
    final fx = ParityThreadFixture(ctx.fixtureData);
    final text =
        draft ?? (fx.messages['composerImagePreviewSeed'] as String? ?? '');
    // The app mounts RaftChatView under WorkspaceView's Scaffold; a
    // transparent Material stands in for that ancestor (TextField needs one).
    return Material(
      type: MaterialType.transparency,
      child: ctx.frame(
        width: 342,
        height: height,
        padding: EdgeInsets.only(top: offsetTop),
        // CSS block flow + overflow:hidden: the composer keeps its natural
        // height and the frame clips it.
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          child: _ComposerHost(
            fixture: fx,
            draft: text,
            readyImage: readyImage
                ? (fx.files['image'] as Map)['filename'] as String
                : null,
            sendForPendingMentions: sendForPendingMentions,
          ),
        ),
      ),
    );
  },
  interact: (tapTaskToggle || type != null || sendForPendingMentions)
      ? (t, ctx) async {
          if (sendForPendingMentions) {
            // React: `click button[aria-label='Send']` with the mouse, which
            // then stays at that point.
            final at = t.getCenter(find.byTooltip('Send message (Ctrl+Enter)'));
            final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
            await mouse.addPointer(location: at);
            await mouse.down(at);
            await mouse.up();
            for (var i = 0; i < 6; i++) {
              await t.pump(const Duration(milliseconds: 40));
            }
            // The pointer rests where Send was; the strip now lies under it.
            await mouse.moveTo(at + const Offset(0, 0.01));
            await t.pump(const Duration(milliseconds: 40));
          }
          if (tapTaskToggle) {
            await t.tap(find.byKey(const Key('composer-as-task')));
            await t.pump(const Duration(milliseconds: 120));
          }
          if (type != null) {
            await t.tap(find.byType(TextField));
            await t.pump(const Duration(milliseconds: 50));
            await t.enterText(find.byType(TextField), type);
            for (var i = 0; i < 6; i++) {
              await t.pump(const Duration(milliseconds: 40));
            }
          }
        }
      : null,
);

/// RaftComposer with the props RaftChatView passes for a channel composer.
class _ComposerHost extends StatefulWidget {
  const _ComposerHost({
    required this.fixture,
    required this.draft,
    this.readyImage,
    this.sendForPendingMentions = false,
  });
  final ParityThreadFixture fixture;
  final String draft;
  final String? readyImage;
  final bool sendForPendingMentions;
  @override
  State<_ComposerHost> createState() => _ComposerHostState();
}

class _ComposerHostState extends State<_ComposerHost> {
  late final WorkspaceController w = widget.fixture.composerWorkspace(
    extraRoutes: widget.sendForPendingMentions
        ? {'POST /v2/messages': widget.fixture.pendingMentionSendReceipt}
        : const {},
  );
  late final ComposerDirectory directory = ComposerDirectory(w);

  @override
  void initState() {
    super.initState();
    final image = widget.readyImage;
    if (image != null) {
      // react-provider.spec.ts setInputFiles(composer-preview.png).
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => w.attachSelection([
          (name: image, bytes: base64Decode(_composerPreviewPng)),
        ], text: (key, args) => raftFormat(context, key, args)),
      );
    }
  }

  bool alsoCreateTask = false;

  @override
  void dispose() {
    directory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([directory, w]),
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftComposer(
          initialDraft: widget.draft,
          // As RaftChatView mounts it.
          accessoryRow: raftComposerAccessory(w),
          taskAction: RaftComposerTaskToggle(
            key: const Key('composer-as-task'),
            checked: alsoCreateTask,
            label: raftText(context, 'As Task'),
            onChanged: (checked) => setState(() => alsoCreateTask = checked),
          ),
          onAttach: () {},
          onImagePick: () {},
          pendingLabel: w.uploads().isEmpty
              ? null
              : raftFormat(context, '{count} attachment(s)', {
                  'count': w.uploads().length,
                }),
          // ComposerVisualCaseView passes MessageInput an explicit
          // `placeholder` (fxMessages.composerPlaceholder); RaftComposer.hint
          // is the same override (the app default is "Message #name").
          hint: widget.fixture.messages['composerPlaceholder'] as String,
          suggestions: directory.suggestions,
          onSuggestionsRequested: directory.request,
          onSendWithMentions: widget.sendForPendingMentions
              ? (text, mentions) => w.send(text, mentions: mentions)
              : (_, _) async => true,
          onForceTaskSendWithMentions: (_, _) async => true,
          onSend: (_) async => true,
        ),
      ],
    ),
  );
}

/// components.thread.files.list: React mounts ChannelFilesPanel in a 390x360
/// overflow-hidden box. Flutter's Files tab body is SourceChannelFilesView,
/// mounted by ConversationPanel with the same formatter.
final ParityCase _files = ParityCase(
  widgets: const [
    'raft_flutter:SourceChannelFilesView',
    'raft_flutter:SourceChannelFileRow',
    'raft_flutter:SourceChannelFilesStore',
  ],
  notes:
      'Rows come from the real SourceChannelFilesStore over the React '
      '/channels/visual-thread-composer/files mock. The image row thumbnail is '
      'an SVG data: URL; ConversationPanel fetches thumbnails through '
      'AttachmentFiles (Dio) and Flutter has no SVG decoder, so no acquireImage '
      'is wired and the row shows the product image-glyph fallback.',
  build: (ctx) {
    final fx = ParityThreadFixture(ctx.fixtureData);
    // ConversationPanel sits under WorkspaceView's Scaffold (Material).
    return Material(
      type: MaterialType.transparency,
      child: ctx.frame(
        width: 390,
        height: 360,
        padding: EdgeInsets.zero,
        child: _FilesHost(fixture: fx),
      ),
    );
  },
  settle: const Duration(milliseconds: 600),
);

class _FilesHost extends StatefulWidget {
  const _FilesHost({required this.fixture});
  final ParityThreadFixture fixture;
  @override
  State<_FilesHost> createState() => _FilesHostState();
}

class _FilesHostState extends State<_FilesHost> {
  late final WorkspaceController w = widget.fixture.composerWorkspace();

  @override
  Widget build(BuildContext context) {
    final formatter = SourceTimeFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      preferredTimezone:
          w.client.user?.string('preferredTimezone') ??
          w.client.user?.string('timezone'),
      preferredTimeFormat: sourceTimeFormatPreference(
        w.client.user?.string('preferredTimeFormat') ??
            w.client.user?.string('timeFormat'),
      ),
      systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
          ? SourceTimeFormat.twentyFourHour
          : null,
    );
    return SizedBox(
      width: 390,
      height: 360,
      child: SourceChannelFilesView(
        controller: w,
        channelId: widget.fixture.composerChannelId,
        formatCreatedAt: formatter.shortDateTime,
        onOpenSource: (_) async {},
      ),
    );
  }
}

/// components.thread.header.states: React clips ChatPanel (PanelHeader +
/// chat tab strip) of channel-home to a 390x120 box at the page top. Flutter
/// shows the channel chrome through the mounted WorkspaceView on a mobile
/// viewport (mobilePageHeader = RaftPageHeader + ConversationPanel's
/// RaftConversationTabs), so the real WorkspaceView is mounted full-viewport
/// and its top 390x120 is the capture target.
final ParityCase _header = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:RaftPageHeader',
    'raft_flutter:ConversationPanel',
    'raft_ui:RaftConversationTabs',
    'raft_ui:RaftBackButton',
    'raft_ui:RaftIconButton',
  ],
  notes:
      'Real WorkspaceView (mobile; channel 首页专修 opened by tapping its Home '
      'row; fake client with no messages). '
      'Flutter mobile channel header shows no channel icon or description and '
      'adds a channel-settings action; that is the product difference.',
  build: (ctx) {
    SharedPreferences.setMockInitialValues({});
    final fx = ParityThreadFixture(ctx.fixtureData);
    return Align(
      alignment: Alignment.topLeft,
      child: ctx.target(
        SizedBox(
          width: 390,
          height: 120,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: ctx.width,
            maxWidth: ctx.width,
            minHeight: ctx.height,
            maxHeight: ctx.height,
            child: _HeaderHost(fixture: fx, family: ctx.family),
          ),
        ),
      ),
    );
  },
  // Mobile WorkspaceView starts on Home; open the channel like a user does
  // (same step as integration_test/native_primary_routes_test.dart).
  interact: (t, ctx) async {
    // The 390x120 target clips hit testing, so invoke the row's real onTap
    // (WorkspaceView.chooseChannel) instead of a pointer tap.
    t
        .widget<RaftNavItem>(
          find.byKey(const ValueKey('sidebar-channel-channel-home')),
        )
        .onTap();
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  },
  settle: const Duration(milliseconds: 600),
);

class _HeaderHost extends StatefulWidget {
  const _HeaderHost({required this.fixture, required this.family});
  final ParityThreadFixture fixture;
  final RaftFamily family;
  @override
  State<_HeaderHost> createState() => _HeaderHostState();
}

class _HeaderHostState extends State<_HeaderHost> {
  late final WorkspaceController w = widget.fixture.navigationWorkspace();

  @override
  void initState() {
    super.initState();
    w.ledger.switchServer('visual-server');
  }

  @override
  Widget build(BuildContext context) => WorkspaceView(
    controller: w,
    appearance: RaftAppearance(light: widget.family),
    onAppearance: (_) async {},
    onLogout: () async {},
  );
}
