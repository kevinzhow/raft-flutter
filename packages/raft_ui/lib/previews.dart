import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter/semantics.dart';

import 'raft_ui.dart';

SemanticsHandle? previewSemantics;
Widget accessiblePreview(Widget child) {
  previewSemantics ??= SemanticsBinding.instance.ensureSemantics();
  return child;
}

Widget brutalWrapper(Widget child) => accessiblePreview(
  MaterialApp(
    theme: raftTheme(RaftFamily.brutal),
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child),
  ),
);
Widget elegantWrapper(Widget child) => accessiblePreview(
  MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child),
  ),
);
Widget darkWrapper(Widget child) => accessiblePreview(
  MaterialApp(
    theme: raftTheme(RaftFamily.elegant, dark: true),
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child),
  ),
);

final class RaftPreviews extends MultiPreview {
  const RaftPreviews(this.component, {this.size = const Size(640, 440)});
  final String component;
  final Size size;
  @override
  List<Preview> get previews => [
    Preview(
      group: component,
      name: '$component · Brutal light',
      wrapper: brutalWrapper,
      size: size,
    ),
    Preview(
      group: component,
      name: '$component · Elegant light',
      wrapper: elegantWrapper,
      size: size,
    ),
    Preview(
      group: component,
      name: '$component · Elegant dark',
      wrapper: darkWrapper,
      size: size,
    ),
  ];
}

@RaftPreviews('Buttons')
Widget buttonsPreview() => const _InteractivePreview('Buttons');
@RaftPreviews('Avatar')
Widget avatarPreview() => const Padding(
  padding: EdgeInsets.all(24),
  child: Wrap(
    spacing: 12,
    children: [
      RaftAvatar(name: 'Cody'),
      RaftAvatar(name: 'Kevin'),
      RaftAvatar(name: '日本語'),
      RaftAvatar(name: ''),
    ],
  ),
);
@RaftPreviews('Navigation')
Widget navigationPreview() => const _InteractivePreview('Navigation');
@RaftPreviews('Panel')
Widget panelPreview() => const Padding(
  padding: EdgeInsets.all(24),
  child: RaftPanel(
    shadow: true,
    child: Text('A shared workspace for humans and agents.'),
  ),
);
@RaftPreviews('Message')
Widget messagePreview() => const _InteractivePreview('Message');
@RaftPreviews('Composer')
Widget composerPreview() => const _InteractivePreview('Composer');
@RaftPreviews('Empty state')
Widget emptyPreview() => const RaftEmptyState(
  title: 'No unread messages',
  detail: 'You are up to date with your workspace.',
  icon: Icons.done_all,
);
@RaftPreviews('Upload')
Widget uploadPreview() => const _InteractivePreview('Upload');
@RaftPreviews('Form')
Widget formPreview() => const _InteractivePreview('Form');
@RaftPreviews('Task')
Widget taskPreview() => const _InteractivePreview('Task');

@RaftPreviews('Long message')
Widget longMessagePreview() => SingleChildScrollView(
  child: RaftMessageTile(
    author: 'Cody',
    timestamp: '09:41',
    content: List.generate(
      24,
      (i) => 'Paragraph ${i + 1}: 中文 日本語 content.',
    ).join('\n\n'),
  ),
);

class _InteractivePreview extends StatefulWidget {
  const _InteractivePreview(this.component);
  final String component;
  @override
  State<_InteractivePreview> createState() => _InteractivePreviewState();
}

class _InteractivePreviewState extends State<_InteractivePreview> {
  String result = 'Ready', selected = 'Activity', taskStatus = 'todo';
  int count = 0;
  bool reacted = false, failDelivery = false;
  final uploads = <String, String>{
    'design.png': 'uploading',
    'report.pdf': 'ready',
    'audio.wav': 'failed',
  };
  void record(String text) => setState(() => result = text);
  @override
  Widget build(BuildContext context) {
    final demo = switch (widget.component) {
      'Buttons' => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          RaftButton(
            label: 'Send',
            icon: Icons.send,
            onPressed: () => record('Sent ${++count}'),
          ),
          RaftButton(
            label: 'Delete',
            destructive: true,
            onPressed: () => record('Deleted'),
          ),
          RaftButton(
            label: 'Cancel',
            secondary: true,
            onPressed: () => record('Cancelled'),
          ),
          const RaftButton(label: 'Disabled'),
          const RaftButton(label: 'Sending', busy: true),
        ],
      ),
      'Navigation' => Column(
        children: [
          for (final label in ['Activity', 'general', 'Private channel'])
            RaftNavItem(
              label: label,
              icon: label == 'Activity'
                  ? Icons.inbox_outlined
                  : label == 'general'
                  ? Icons.tag
                  : Icons.lock_outline,
              selected: selected == label,
              unread: label == 'Activity'
                  ? 12
                  : label == 'Private channel'
                  ? 2
                  : 0,
              onTap: () => setState(() {
                selected = label;
                result = 'Opened $label';
              }),
            ),
        ],
      ),
      'Message' => RaftMessageTile(
        author: 'Cody',
        timestamp: '10:42',
        badge: 'Agent',
        content: '**Raft Flutter** is ready for review.\n\n- Linux and Android\n- 日本語 / 中文\n\n```dart\nawait client.send(channel, content);\n```',
        onThread: () => record('Thread opened'),
        onActions: () => record('Actions opened'),
        onLink: (href) => record('Link: $href'),
        reactions: [
          {'emoji': '👍', 'count': reacted ? 4 : 3},
        ],
        reactedEmojis: reacted ? {'👍'} : {},
        onReaction: (_) => setState(() {
          reacted = !reacted;
          result = reacted ? 'Reaction added' : 'Reaction removed';
        }),
        attachments: const [
          {'filename': 'design.png'},
        ],
        onAttachment: (_) => record('Attachment opened'),
      ),
      'Composer' => Column(
        children: [
          SwitchListTile(
            title: const Text('Fail next delivery'),
            value: failDelivery,
            onChanged: (value) => setState(() => failDelivery = value),
          ),
          RaftComposer(
            onSend: (text) async {
              if (failDelivery) {
                record('Delivery failed; draft retained');
                return false;
              }
              record('Sent: $text');
              return true;
            },
            onAttach: () => record('Attachment picker opened'),
            hint: 'Message #general',
          ),
          RaftComposer(
            onSend: (_) async => false,
            enabled: false,
            hint: 'Join this channel to send',
          ),
        ],
      ),
      'Upload' => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final entry in uploads.entries)
            RaftUploadChip(
              name: entry.key,
              ready: entry.value == 'ready',
              progress: entry.value == 'uploading' ? .4 : 0,
              error: entry.value == 'failed' ? 'Upload failed' : null,
              onRetry: entry.value != 'failed'
                  ? null
                  : () => setState(() {
                      uploads[entry.key] = 'ready';
                      result = 'Retried ${entry.key}';
                    }),
              onRemove: () => setState(() {
                uploads.remove(entry.key);
                result = 'Removed ${entry.key}';
              }),
            ),
        ],
      ),
      'Form' => Column(
        children: [
          SwitchListTile(
            title: const Text('Fail next submission'),
            value: failDelivery,
            onChanged: (value) => setState(() => failDelivery = value),
          ),
          RaftButton(
            label: 'Open form',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => RaftFormDialog(
                title: 'Create task',
                submitLabel: 'Create',
                fields: const [
                  RaftFormField('title', 'Title', required: true),
                  RaftFormField('description', 'Description', multiline: true),
                ],
                onSubmit: (values) async {
                  if (failDelivery)
                    throw StateError('Submission failed; keep your changes.');
                  record('Created: ${values['title']}');
                },
              ),
            ),
          ),
        ],
      ),
      'Task' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftTaskCard(
            title: 'Verify Linux and Android',
            number: '42',
            channel: 'general',
            status: taskStatus,
            description:
                'Chinese / Japanese input, reconnect and saved drafts.',
            assignee: 'Cody',
            onTap: () => record('Task details opened'),
            statusOptions: raftTaskStatuses,
            onStatus: (status) => setState(() {
              taskStatus = status;
              result = 'Status: ${raftTaskStatusLabel(status)}';
            }),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in raftTaskStatuses)
                RaftTaskStatus(status: status),
            ],
          ),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            demo,
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(result, key: const Key('preview-result')),
            ),
          ],
        ),
      ),
    );
  }
}

@RaftPreviews('Credential')
Widget credentialPreview() => Padding(
  padding: const EdgeInsets.all(24),
  child: RaftSecretView(
    value: 'demo-only-not-a-real-credential',
    onCopy: (_) async {},
  ),
);

final class RaftWorkspacePreviews extends MultiPreview {
  const RaftWorkspacePreviews();
  @override
  List<Preview> get previews => [
    for (final configuration in [
      ('Brutal light', brutalWrapper),
      ('Elegant light', elegantWrapper),
      ('Elegant dark', darkWrapper),
    ]) ...[
      Preview(
        group: 'Adaptive workspace',
        name: 'Adaptive workspace · ${configuration.$1} · desktop',
        wrapper: configuration.$2,
        size: const Size(1200, 620),
      ),
      Preview(
        group: 'Adaptive workspace',
        name: 'Adaptive workspace · ${configuration.$1} · mobile',
        wrapper: configuration.$2,
        size: const Size(390, 620),
      ),
    ],
  ];
}

@RaftWorkspacePreviews()
Widget adaptiveWorkspacePreview() => const _WorkspacePreview();

@RaftPreviews('Workspace rail')
Widget workspaceRailPreview() => const _WorkspacePreview(railOnly: true);

class _WorkspacePreview extends StatefulWidget {
  const _WorkspacePreview({this.railOnly = false});
  final bool railOnly;
  @override
  State<_WorkspacePreview> createState() => _WorkspacePreviewState();
}

class _WorkspacePreviewState extends State<_WorkspacePreview> {
  String selected = 'chat', result = 'Chat opened';
  bool thread = false;
  double sidebarWidth = 240, threadWidth = 400;
  final destinations = const [
    RaftRailDestination(
      id: 'chat',
      label: 'Chat',
      icon: Icons.chat_bubble_outline,
    ),
    RaftRailDestination(
      id: 'activity',
      label: 'Activity',
      icon: Icons.inbox_outlined,
      unread: 12,
    ),
    RaftRailDestination(
      id: 'tasks',
      label: 'Tasks',
      icon: Icons.check_box_outlined,
    ),
  ];
  void select(String id) => setState(() {
    selected = id;
    result = '${id[0].toUpperCase()}${id.substring(1)} opened';
  });
  Widget rail() => RaftWorkspaceRail(
    destinations: destinations,
    selected: selected,
    onSelected: select,
    workspaceName: 'Raft',
    onWorkspace: () => setState(() => result = 'Workspace switcher opened'),
  );
  @override
  Widget build(BuildContext context) {
    if (widget.railOnly) {
      return Row(
        children: [
          SizedBox(width: 64, child: rail()),
          Expanded(
            child: Center(
              child: Semantics(liveRegion: true, child: Text(result)),
            ),
          ),
        ],
      );
    }
    return RaftAdaptiveWorkspace(
      sidebar: ListView(
        children: [
          const Material(
            type: MaterialType.transparency,
            child: ListTile(
              title: Text('Raft workspace'),
              subtitle: Text('Channels'),
            ),
          ),
          for (final name in ['general', 'design', 'release'])
            RaftNavItem(
              label: name,
              icon: Icons.tag,
              selected: name == 'general',
              onTap: () => setState(() => result = '#$name opened'),
            ),
        ],
      ),
      rail: rail(),
      sidebarWidth: sidebarWidth,
      threadWidth: threadWidth,
      onPanelWidthsChanged: (left, right) => setState(() {
        sidebarWidth = left;
        threadWidth = right;
        result = 'Sidebar ${left.round()} px · Thread ${right.round()} px';
      }),
      mobileNavigation: NavigationBar(
        selectedIndex: ['chat', 'activity', 'tasks'].indexOf(selected),
        onDestinationSelected: (i) => select(['chat', 'activity', 'tasks'][i]),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '#general',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RaftButton(
              label: 'Open thread',
              onPressed: () => setState(() => thread = true),
            ),
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: Text(result)),
            const Spacer(),
            RaftComposer(
              hint: 'Message #general',
              onSend: (text) async {
                setState(() => result = 'Sent: $text');
                return true;
              },
            ),
          ],
        ),
      ),
      thread: !thread
          ? null
          : Column(
              children: [
                ListTile(
                  title: const Text('Thread'),
                  trailing: IconButton(
                    tooltip: 'Close thread',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => thread = false),
                  ),
                ),
                const Expanded(
                  child: Center(child: Text('Thread conversation')),
                ),
              ],
            ),
    );
  }
}

@RaftPreviews('Rich message', size: Size(640, 580))
Widget richMessagePreview() => const _RichMessagePreview();

class _RichMessagePreview extends StatefulWidget {
  const _RichMessagePreview();
  @override
  State<_RichMessagePreview> createState() => _RichMessagePreviewState();
}

class _RichMessagePreviewState extends State<_RichMessagePreview> {
  String result = 'Ready';
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftMessageBody(
            content: '### Delivery plan\nAsk @Cody in #design about task #27.\n\n- **Draft** the change\n- Review the evidence\n\n```mermaid\nflowchart LR\n A[Draft] --> B[Review]\n B --> C[Ship]\n```\n\n`@Cody` stays code.',
            references: const [
              RaftTextReference(
                text: '@Cody',
                href: 'raft-ref://mention/agent/demo',
              ),
              RaftTextReference(
                text: '#design',
                href: 'raft-ref://channel/demo',
              ),
            ],
            taskHref: (n) => 'raft-ref://task/$n',
            onLink: (href) => setState(() => result = 'Opened $href'),
            onCopyCode: (source) async => setState(
              () => result = source.startsWith('flowchart LR')
                  ? 'Copied diagram source'
                  : 'Unexpected source',
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(result, key: const Key('preview-result')),
          ),
        ],
      ),
    ),
  );
}

@RaftPreviews('Action card', size: Size(640, 620))
Widget actionCardPreview() => const _ActionCardPreview();

class _ActionCardPreview extends StatefulWidget {
  const _ActionCardPreview();
  @override
  State<_ActionCardPreview> createState() => _ActionCardPreviewState();
}

class _ActionCardPreviewState extends State<_ActionCardPreview> {
  String state = 'prepared', result = 'Ready';
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftActionCard(
            title: 'Create channel',
            state: state,
            details: const [
              (label: 'Channel name', value: 'design'),
              (label: 'Visibility', value: 'Private channel'),
            ],
            hint: 'Review the draft before creating this channel.',
            confirmLabel: 'Create channel',
            completedBy: state == 'executed' ? 'Kevin' : null,
            onConfirm: () => setState(() {
              state = 'executed';
              result = 'Action confirmed';
            }),
          ),
          const SizedBox(height: 12),
          const RaftActionCard(
            title: 'Install app',
            state: 'frozen',
            blockedReason:
                'This action was frozen after the workspace changed.',
          ),
          const SizedBox(height: 12),
          RaftActionCard(
            title: 'Approve agent login',
            state: 'reconfirm_required',
            onConfirm: () =>
                setState(() => result = 'Reconfirmation requested'),
          ),
          Semantics(
            liveRegion: true,
            child: Text(result, key: const Key('preview-result')),
          ),
        ],
      ),
    ),
  );
}

@RaftPreviews('Message export', size: Size(640, 680))
Widget messageExportPreview() => const _MessageExportPreview();

class _MessageExportPreview extends StatefulWidget {
  const _MessageExportPreview();
  @override
  State<_MessageExportPreview> createState() => _MessageExportPreviewState();
}

class _MessageExportPreviewState extends State<_MessageExportPreview> {
  int count = 2;
  String status = '';
  Widget surface() => const RaftMessageExportSurface(
    width: 540,
    messages: [
      RaftMessageTile(
        author: 'Cody',
        timestamp: '09:41',
        content: '',
        collapseLongMessages: false,
        body: RaftMessageBody(
          content: '**中文输入、日本語確認**\n\n```mermaid\nflowchart LR\n A[Draft] --> B[Review]\n```',
          exportMode: true,
        ),
      ),
      Padding(
        padding: EdgeInsets.only(left: 32),
        child: RaftMessageTile(
          author: 'Kevin',
          timestamp: '09:42',
          content: 'Review this image before sharing.',
          collapseLongMessages: false,
        ),
      ),
    ],
  );
  void review() => showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: SizedBox(
        width: 590,
        height: 560,
        child: RaftImageReview(
          preview: surface(),
          onClose: () => Navigator.pop(ctx),
          onSave: () {
            setState(() => status = 'Image save requested');
            Navigator.pop(ctx);
          },
          onShare: () {
            setState(() => status = 'Image share requested');
            Navigator.pop(ctx);
          },
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: SingleChildScrollView(child: surface())),
      Text(status),
      RaftSelectionToolbar(
        selected: count,
        total: 3,
        onExit: () => setState(() => status = 'Selection exited'),
        onSelectAll: () => setState(() => count = 3),
        onCopyMarkdown: () => setState(() => status = 'Markdown copied'),
        onPreview: review,
      ),
    ],
  );
}

@RaftPreviews('Forwarded bundle', size: Size(640, 680))
Widget forwardedBundlePreview() => SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        RaftForwardedBundle(
          metadata: {
            'kind': 'forwarded-bundle',
            'version': 1,
            'forwardedItems': [
              for (var i = 0; i < 3; i++)
                {
                  'index': i,
                  'sourceIsThreadParent': i == 0,
                  'provenanceState': 'available',
                  'sourceTargetSnapshot': {
                    'type': 'thread',
                    'label': '#design · thread',
                    'labelVisibility': 'public',
                  },
                  'sourceAuthorSnapshot': {
                    'type': i == 0 ? 'agent' : 'user',
                    'uniqueName': i == 0 ? 'Cody' : 'Kevin',
                  },
                  'sourceCreatedAt': '2026-10-07T09:0$i:00Z',
                  'contentSnapshot': [
                    '**Copied snapshot** — 中文内容',
                    '日本語の返信',
                    'Final review',
                  ][i],
                  'attachmentPolicy': i == 1 ? 'projected' : 'excluded',
                  'attachmentSnapshots': [
                    {
                      'id': 'fake-preview-projection',
                      'filename': 'design-notes.txt',
                      'mimeType': 'text/plain',
                      'sizeBytes': 128,
                    },
                  ],
                },
            ],
          },
        ),
        const SizedBox(height: 16),
        const RaftForwardedBundle(
          metadata: {
            'kind': 'forwarded-bundle',
            'version': 1,
            'forwardedItems': [
              {
                'index': 0,
                'provenanceState': 'original_unavailable',
                'sourceTargetSnapshot': {
                  'type': 'dm',
                  'label': 'Never expose this source',
                  'labelVisibility': 'restricted',
                },
                'sourceAuthorSnapshot': {
                  'type': 'user',
                  'name': 'Former member',
                },
                'contentSnapshot': 'The copied message remains available without a source link.',
                'attachmentPolicy': 'excluded',
              },
            ],
          },
        ),
      ],
    ),
  ),
);

@RaftPreviews('Composer suggestions', size: Size(640, 520))
Widget composerSuggestionsPreview() => const _ComposerSuggestionsPreview();

class _ComposerSuggestionsPreview extends StatefulWidget {
  const _ComposerSuggestionsPreview();
  @override
  State<_ComposerSuggestionsPreview> createState() =>
      _ComposerSuggestionsPreviewState();
}

class _ComposerSuggestionsPreviewState
    extends State<_ComposerSuggestionsPreview> {
  String result = 'Choose the human or agent identity before sending.';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Type @same or #design. Arrow keys, Tab and Enter accept a suggestion. Ctrl+Enter sends.',
        ),
      ),
      Text(result),
      const Spacer(),
      RaftComposer(
        initialDraft: '',
        onSend: (_) async => false,
        suggestions: const [
          RaftComposerSuggestion(
            type: 'user',
            id: 'preview-human',
            name: 'same',
            title: 'Human Same',
          ),
          RaftComposerSuggestion(
            type: 'agent',
            id: 'preview-agent',
            name: 'same',
            title: 'Agent Same',
          ),
          RaftComposerSuggestion(
            type: 'channel',
            id: 'preview-channel',
            name: 'design',
          ),
          RaftComposerSuggestion(
            type: 'computer',
            id: 'preview-computer',
            name: 'K8',
            referenceText: '[@K8](<computer:preview-computer>)',
          ),
        ],
        onSendWithMentions: (text, mentions) async {
          setState(
            () => result =
                'Sent $text · ${mentions.map((m) => '${m['type']}:${m['id']}').join(', ')}',
          );
          return true;
        },
      ),
    ],
  );
}

@RaftPreviews('Timeline return to latest', size: Size(390, 360))
Widget timelineBottomButtonPreview() => Stack(
  fit: StackFit.expand,
  children: [
    const Center(child: Text('History window')),
    RaftTimelineBottomButton(label: '3 new messages', onPressed: () {}),
  ],
);
