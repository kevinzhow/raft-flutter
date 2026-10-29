import 'package:flutter/foundation.dart' show ValueListenable, VoidCallback;
import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

const _agents = [
  RaftWorkingAgent(
    id: 'bugen',
    name: 'Bugen',
    text: 'Editing Flow.tsx · #25',
    avatar: RaftAvatarContent(
      name: 'Bugen',
      kind: RaftAvatarContentKind.agent,
      pixelKey: 'cat',
    ),
  ),
  RaftWorkingAgent(
    id: 'wug',
    name: 'Wug',
    text: 'Drafting release notes · #31',
    avatar: RaftAvatarContent(
      name: 'Wug',
      kind: RaftAvatarContentKind.agent,
      pixelKey: 'robot',
    ),
  ),
];

@RaftPreviews('Working agents · phone Home', size: Size(390, 520))
Widget workingAgentsPhoneHomePreview() => const _PhoneHome();

class _PhoneHome extends StatelessWidget {
  const _PhoneHome();
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftMobileRootHeader(
          title: 'Launch Crew',
          actions: const [
            RaftWideHeaderAction(child: RaftWorkingSummary(agents: _agents)),
          ],
        ),
        const SizedBox(height: 12),
        // What the summary opens: Working now, one row per working agent.
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: RaftWorkingNow(agents: _agents),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              _row('Bugen', 'Editing Flow.tsx · #25'),
              _row('Wug', 'Drafting release notes · #31'),
              _row('Mira', null),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _row(String name, String? activity) => RaftNavItem(
    label: name,
    glyph: RaftGlyph.user,
    conversationKind: RaftConversationNavKind.directMessage,
    description: activity == null ? 'Codex' : null,
    activityText: activity == null ? null : _Text(activity),
    onTap: () {},
  );
}

@RaftPreviews('Working agents · channel header', size: Size(390, 160))
Widget workingAgentsChannelHeaderPreview() => Column(
  children: [
    RaftChannelHeader(
      name: 'launch-week',
      description: 'Ship the launch week',
      workingAgents: _agents,
      onBack: () {},
      onSearch: () {},
      onSettings: () {},
    ),
    RaftChannelHeader(
      name: 'design',
      description: 'Product and UI decisions',
      onBack: () {},
      onSearch: () {},
      onSettings: () {},
    ),
  ],
);

@RaftPreviews('Working agents · desktop', size: Size(960, 420))
Widget workingAgentsDesktopPreview() => SingleChildScrollView(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 300,
        child: Column(
          children: [
            const RaftChatSidebarHeading(
              label: 'Chat',
              trailing: RaftWorkingSummary(agents: _agents),
            ),
            const SizedBox(height: 8),
            for (final (name, text) in [
              ('Bugen', 'Editing Flow.tsx · #25'),
              ('Wug', 'Drafting release notes · #31'),
            ])
              RaftNavItem(
                label: name,
                glyph: RaftGlyph.user,
                conversationKind: RaftConversationNavKind.directMessage,
                activityText: _Text(text),
                onTap: () {},
              ),
          ],
        ),
      ),
      Expanded(
        child: RaftChannelHeader(
          name: 'launch-week',
          description: 'Ship the launch week',
          workingAgents: _agents,
          onSearch: () {},
          onSettings: () {},
        ),
      ),
    ],
  ),
);

/// A row text that never changes (a preview has nothing to notify).
class _Text implements ValueListenable<String?> {
  const _Text(this.value);
  @override
  final String? value;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
