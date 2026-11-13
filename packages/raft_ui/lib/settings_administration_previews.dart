import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

const _candidates = [
  RaftAdminPrincipal(
    key: 'human:dana',
    label: 'Dana',
    agent: false,
    optionLabel: 'Dana · dana@raft.test',
  ),
  RaftAdminPrincipal(
    key: 'agent:helper',
    label: '@helper',
    agent: true,
    optionLabel: '@helper · Agent',
    avatarUrl: 'pixel:robot',
  ),
];

@RaftPreviews('Administration: Owners & Admins', size: Size(760, 420))
Widget administrationAdminsPreview() => const _AdminsPreview();

class _AdminsPreview extends StatefulWidget {
  const _AdminsPreview();
  @override
  State<_AdminsPreview> createState() => _AdminsPreviewState();
}

class _AdminsPreviewState extends State<_AdminsPreview> {
  String? selected;
  String role = 'admin';
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: RaftAdminSection(
      label: 'Owners & admins',
      glyph: RaftGlyph.shield,
      count: 2,
      child: RaftAdminsCard(
        candidates: _candidates,
        selectedKey: selected,
        onSelect: (key) => setState(() => selected = key),
        role: role,
        roleOptions: selected == null
            ? const {}
            : selected!.startsWith('agent')
            ? const {'admin'}
            : const {'owner', 'admin'},
        onRole: (value) => setState(() => role = value),
        onPromote: () => setState(() => selected = null),
        rows: [
          const RaftAdminRow(
            principal: RaftAdminPrincipal(
              key: 'human:owner',
              label: 'Owner',
              agent: false,
              subtitle: 'owner@raft.test · Owner',
            ),
            note: 'Last owner',
          ),
          RaftAdminRow(
            principal: const RaftAdminPrincipal(
              key: 'agent:bot',
              label: '@bot',
              agent: true,
              subtitle: 'Agent · Admin',
              avatarUrl: 'pixel:robot',
            ),
            removeLabel: 'Remove admin',
            onRemove: () {},
          ),
        ],
      ),
    ),
  );
}

@RaftPreviews(
  'Administration: checkbox, switch and links',
  size: Size(760, 760),
)
Widget administrationFormsPreview() => const _FormsPreview();

class _FormsPreview extends StatefulWidget {
  const _FormsPreview();
  @override
  State<_FormsPreview> createState() => _FormsPreviewState();
}

class _FormsPreviewState extends State<_FormsPreview> {
  bool hidden = false, analytics = true;
  final maxUses = TextEditingController();
  @override
  void dispose() {
    maxUses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftAdminSection(
          label: 'System channels',
          glyph: RaftGlyph.eye,
          child: RaftAdminCheckboxForm(
            title: 'Hide #all channel',
            description: 'Existing history is preserved.',
            checked: hidden,
            onChanged: (v) => setState(() => hidden = v),
            save: RaftAdminSaveState.idle,
            onSave: hidden ? () {} : null,
          ),
        ),
        RaftAdminSection(
          label: 'Product analytics',
          glyph: RaftGlyph.barChart3,
          child: RaftAdminSwitchCard(
            title: 'Product analytics for this workspace',
            description: 'When off, no usage data is recorded.',
            checked: analytics,
            onChanged: (v) => setState(() => analytics = v),
          ),
        ),
        RaftAdminSection(
          label: 'Invite links',
          glyph: RaftGlyph.link2,
          count: 1,
          child: RaftAdminJoinLinksCard(
            maxUses: maxUses,
            expiresAt: null,
            onExpiresAt: (_) {},
            onCreate: () {},
            links: [
              RaftAdminJoinLink(
                id: 'l1',
                url: 'https://raft.test/join/design',
                meta: '8/25 uses · no expiry',
                copied: false,
                onCopy: () {},
                onRevoke: () {},
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
