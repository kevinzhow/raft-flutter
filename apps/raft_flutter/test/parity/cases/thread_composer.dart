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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/composer_directory.dart';
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
    widgets: const ['raft_ui:RaftUploadChip'],
    notes:
        'React picks composer-preview.png; its baseline shows the '
        '"upload size limit could not be checked" error instead of a preview. '
        'Flutter has no upload-size-limit check or image preview in the '
        'composer: the same pick yields a ready RaftUploadChip above the '
        'composer plus the "1 attachment(s)" pending label, composed exactly '
        'as RaftChatView does.',
  ),
  'components.thread.files.list': _files,
  'components.thread.header.states': _header,
};

final Map<String, ParityUncovered> threadComposerUncovered = {
  'components.thread.composer.pending-mention-actions': const ParityUncovered(
    ParityGap.noFlutterSurface,
    'React sends and renders PendingMentionActionStrip (outside-channel '
    'mention: avatar, "was not notified because they are not in #design", '
    'Add / Notify / Ignore). Flutter has no pending-mention action surface: '
    'RaftChatView.sendCurrent/WorkspaceController.send ignore '
    'pendingMentionActions, and no widget in apps/raft_flutter/lib or '
    'packages/raft_ui renders it (only unused localization strings exist).',
  ),
};

String get _seed => 'Review the Android composer crop before release.';

ParityCase _composer({
  required String? draft,
  double height = 100,
  double offsetTop = 0,
  String? type,
  bool tapTaskToggle = false,
  bool readyImage = false,
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
    'Flutter hint is the app string "Message #{name}" (React: "Message design").',
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
          ),
        ),
      ),
    );
  },
  interact: (tapTaskToggle || type != null)
      ? (t, ctx) async {
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
  });
  final ParityThreadFixture fixture;
  final String draft;
  final String? readyImage;
  @override
  State<_ComposerHost> createState() => _ComposerHostState();
}

class _ComposerHostState extends State<_ComposerHost> {
  late final WorkspaceController w = widget.fixture.composerWorkspace();
  late final ComposerDirectory directory = ComposerDirectory(w);
  bool alsoCreateTask = false;

  @override
  void dispose() {
    directory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: directory,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.readyImage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RaftUploadChip(
                  name: widget.readyImage!,
                  progress: 1,
                  ready: true,
                  onRetry: () {},
                  onRemove: () {},
                ),
              ],
            ),
          ),
        RaftComposer(
          initialDraft: widget.draft,
          taskAction: RaftComposerTaskToggle(
            key: const Key('composer-as-task'),
            checked: alsoCreateTask,
            label: raftText(context, 'As Task'),
            onChanged: (checked) => setState(() => alsoCreateTask = checked),
          ),
          onAttach: () {},
          onImagePick: () {},
          pendingLabel: widget.readyImage == null
              ? null
              : raftFormat(context, '{count} attachment(s)', {'count': 1}),
          hint: raftFormat(context, 'Message #{name}', {
            'name': w.channel?.name ?? '',
          }),
          suggestions: directory.suggestions,
          onSuggestionsRequested: directory.request,
          onSendWithMentions: (_, _) async => true,
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
