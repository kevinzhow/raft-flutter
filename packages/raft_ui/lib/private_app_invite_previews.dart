import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Private app invitation', size: Size(768, 900))
Widget privateAppInvitePreview() => const _InvitePreview();

class _InvitePreview extends StatefulWidget {
  const _InvitePreview();
  @override
  State<_InvitePreview> createState() => _InvitePreviewState();
}

class _InvitePreviewState extends State<_InvitePreview> {
  String? selected = 'design';
  final installed = <String>{};
  bool identityExpanded = false;
  @override
  Widget build(BuildContext context) => RaftPrivateAppInvitePage(
    name: 'Shared Calendar',
    description: 'A shared calendar for your team.',
    byline: 'Shared by Publisher from Design',
    details: const [
      ('Client ID', 'calendar-client'),
      ('Homepage', 'calendar.example.invalid'),
      ('Callback', 'calendar.example.invalid'),
      ('Invite expiry', 'No expiry'),
    ],
    servers: const [
      RaftSelectItem(value: 'design', label: 'Design'),
      RaftSelectItem(value: 'engineering', label: 'Engineering'),
    ],
    selectedServer: selected,
    installed: installed.contains(selected),
    scopes: RaftDisclosureCard(
      child: RaftCollapsibleSectionHeader(
        label: 'Identity',
        labelSpan: const TextSpan(text: 'Identity — Basic profile information'),
        expanded: identityExpanded,
        leadingDisclosure: true,
        onExpandedChanged: (value) => setState(() => identityExpanded = value),
        children: const [Text('openid · profile')],
      ),
    ),
    onServer: (value) => setState(() => selected = value),
    onInstall: () => setState(() => installed.add(selected!)),
    onSettings: () {},
    onRetry: () {},
    onClose: () {},
  );
}
