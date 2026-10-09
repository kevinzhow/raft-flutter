import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Source notification settings', size: Size(390, 540))
Widget sourceNotificationSettingsPreview() => const _Preview();

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _State();
}

class _State extends State<_Preview> {
  bool muted = false, saved = false, enabled = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: RaftNotificationSettingsCard(
      title: 'DMs, direct mentions, and followed thread replies',
      description: 'Messages arrive while connected. Background inbox checks provide a fallback when the system allows them; delivery may be delayed.',
      status: enabled ? 'Enabled' : 'Disabled',
      enableLabel: enabled
          ? 'Disable Push Notifications'
          : 'Enable Push Notifications',
      onEnable: () => setState(() => enabled = !enabled),
      showTest: enabled,
      onTest: () {},
      muted: muted,
      onMutedChanged: (v) => setState(() => muted = v),
      muteDescription: 'Stops web push notifications from Preview for your account. Other servers are unchanged.',
      onSave: muted == saved ? null : () => setState(() => saved = muted),
    ),
  );
}
