import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Mounted chat sidebar groups', size: Size(320, 560))
Widget mountedChatSidebarGroupsPreview() => const _GroupPreview();

@RaftPreviews('Conversation tabs desktop', size: Size(1024, 220))
Widget conversationTabsDesktopPreview() =>
    const _TabPreview(RaftDensity.desktop);

@RaftPreviews('Conversation tabs phone touch', size: Size(390, 220))
Widget conversationTabsTouchPreview() => const _TabPreview(RaftDensity.touch);

@RaftPreviews('Composer task action', size: Size(640, 440))
Widget composerTaskActionPreview() => const _TaskPreview();

@RaftPreviews('Recipe group opacity', size: Size(390, 180))
Widget recipeGroupOpacityPreview() => Padding(
  padding: const EdgeInsets.all(24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const RaftButton(
        label: 'Create Cindy',
        tone: RaftButtonRecipeVariant.accent,
        size: RaftButtonRecipeSize.lg,
        expand: true,
        opacityCompositing: RaftOpacityCompositing.alphaFilter,
      ),
      const SizedBox(height: 16),
      RaftCssOpacity(
        opacity: .4,
        child: RaftButton(
          label: 'Create Cindy',
          tone: RaftButtonRecipeVariant.accent,
          size: RaftButtonRecipeSize.lg,
          expand: true,
          onPressed: () {},
        ),
      ),
    ],
  ),
);

@RaftPreviews('Composer editable CSS line boxes', size: Size(390, 240))
Widget composerEditableLineBoxPreview() => Align(
  alignment: Alignment.bottomCenter,
  child: RaftComposer(
    initialDraft: 'Review the Android composer crop before release.',
    onImagePick: () {},
    onAttach: () {},
    onSend: (_) async => false,
  ),
);

class _GroupPreview extends StatefulWidget {
  const _GroupPreview();
  @override
  State<_GroupPreview> createState() => _GroupPreviewState();
}

class _GroupPreviewState extends State<_GroupPreview> {
  final expanded = {
    for (final kind in RaftChatSidebarGroupKind.values) kind: true,
  };
  var hideEmpty = false, loading = false, actions = 0;
  @override
  Widget build(BuildContext context) => RaftDensityScope(
    density: RaftDensity.desktop,
    child: ListView(
      children: [
        for (final kind in RaftChatSidebarGroupKind.values)
          RaftChatSidebarGroup(
            kind: kind,
            label: switch (kind) {
              RaftChatSidebarGroupKind.pinned => 'Pinned',
              RaftChatSidebarGroupKind.joint => 'Joint channels',
              RaftChatSidebarGroupKind.channels => 'Channels',
              RaftChatSidebarGroupKind.directMessages => 'Direct messages',
            },
            count: 0,
            expanded: expanded[kind]!,
            hideEmpty: hideEmpty,
            loading: loading,
            emptyLabel: switch (kind) {
              RaftChatSidebarGroupKind.pinned =>
                'Drag channels or DMs here to pin',
              RaftChatSidebarGroupKind.joint => 'No joint channels yet',
              RaftChatSidebarGroupKind.channels => 'No channels yet',
              RaftChatSidebarGroupKind.directMessages => '',
            },
            onExpandedChanged: (value) =>
                setState(() => expanded[kind] = value),
            actions: [
              RaftSidebarSectionAction(
                label: 'Sort ${kind.name}',
                glyph: RaftGlyph.arrowDownUp,
                onPressed: () => setState(() => actions++),
              ),
              if (kind == RaftChatSidebarGroupKind.channels ||
                  kind == RaftChatSidebarGroupKind.joint)
                RaftSidebarSectionAction(
                  label: 'Add ${kind.name}',
                  glyph: RaftGlyph.plus,
                  onPressed: () => setState(() => actions++),
                ),
            ],
            children: const [],
          ),
        const Divider(),
        // Fixture controls are outside the source section composition.
        Wrap(
          spacing: 8,
          children: [
            RaftTextButton(
              label: hideEmpty ? 'Show empty groups' : 'Hide empty groups',
              onPressed: () => setState(() => hideEmpty = !hideEmpty),
            ),
            RaftTextButton(
              label: loading ? 'Finish loading' : 'Begin loading',
              onPressed: () => setState(() => loading = !loading),
            ),
          ],
        ),
        Text('Fixture action receipts: $actions'),
      ],
    ),
  );
}

class _TabPreview extends StatefulWidget {
  const _TabPreview(this.density);
  final RaftDensity density;
  @override
  State<_TabPreview> createState() => _TabPreviewState();
}

class _TabPreviewState extends State<_TabPreview> {
  var value = RaftConversationTabId.chat;
  var actions = 0;
  @override
  Widget build(BuildContext context) => RaftDensityScope(
    density: widget.density,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftConversationTabs(
          tabs: const [
            RaftConversationTab(id: RaftConversationTabId.chat, label: 'Chat'),
            RaftConversationTab(
              id: RaftConversationTabId.tasks,
              label: 'Tasks',
            ),
            RaftConversationTab(
              id: RaftConversationTabId.files,
              label: 'Files',
            ),
          ],
          value: value,
          onChanged: (next) => setState(() => value = next),
        ),
        const RaftConversationDateHeader(label: 'October 8'),
        Align(
          alignment: Alignment.centerRight,
          child: RaftConversationHeaderActions(
            onSearch: () => setState(() => actions++),
            onSettings: () => setState(() => actions++),
            searchLabel: 'Search conversation',
            settingsLabel: 'Conversation settings',
          ),
        ),
        Text('Fixture panel: ${value.name}; actions: $actions'),
      ],
    ),
  );
}

class _TaskPreview extends StatefulWidget {
  const _TaskPreview();
  @override
  State<_TaskPreview> createState() => _TaskPreviewState();
}

class _TaskPreviewState extends State<_TaskPreview> {
  var checked = false, receipts = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: Center(child: Text('Fixture accepted sends: $receipts'))),
      RaftComposer(
        initialDraft: 'Public draft 中文',
        onSend: (_) async {
          setState(() => receipts++);
          return true;
        },
        taskAction: RaftComposerTaskToggle(
          checked: checked,
          label: 'As task',
          onChanged: (value) => setState(() => checked = value),
        ),
      ),
    ],
  );
}
