import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Source notification settings (desktop)', size: Size(390, 460))
Widget sourceDesktopNotificationSettingsPreview() =>
    const _Preview(phone: false);

@RaftPreviews('Source notification settings (phone)', size: Size(390, 600))
Widget sourcePhoneNotificationSettingsPreview() => const _Preview(phone: true);

class _Preview extends StatefulWidget {
  const _Preview({required this.phone});
  final bool phone;
  @override
  State<_Preview> createState() => _State();
}

class _State extends State<_Preview> {
  bool muted = false, saved = false, enabled = false, sent = false;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: widget.phone
          ? RaftNotificationSettingsCard(
              title: 'Phone notifications',
              description: 'While Raft is connected, new DMs, direct mentions and replies in followed threads show a system notification. In the background Raft checks for new messages periodically, so some may arrive later.',
              status: enabled ? 'Enabled' : 'Not enabled',
              hint: 'Whether notifications appear is decided by the system: on Android, Settings → Apps → Raft → Notifications. With Do Not Disturb or a Focus mode on, the system may delay or silence notifications.',
              actionLabel: enabled
                  ? 'Send Test Notification'
                  : 'Enable Notifications',
              actionTone: enabled
                  ? RaftButtonRecipeVariant.success
                  : RaftButtonRecipeVariant.accent,
              onAction: () => setState(() => enabled = true),
              muted: muted,
              onMutedChanged: (v) => setState(() => muted = v),
              muteDescription: 'Stops notifications from Preview for your account. Other servers are unchanged.',
              onSave: muted == saved
                  ? null
                  : () => setState(() => saved = muted),
            )
          : RaftNotificationSettingsCard(
              title: 'Desktop notifications',
              description: 'Raft Desktop shows system notifications for new DMs, direct mentions, and followed thread replies while the window is in the background. Web push is not used on desktop.',
              status: 'Managed by the system',
              hint: 'Whether these notifications appear is decided by the system, not by Raft: macOS → System Settings → Notifications → Raft. The system may ask for permission the first time a notification is posted. A Focus mode or Do Not Disturb may delay or silence banners.',
              message: sent
                  ? 'Test notification posted to the system. If no banner appeared, allow notifications for Raft in System Settings → Notifications, then try again.'
                  : null,
              actionLabel: 'Send a test notification',
              onAction: () => setState(() => sent = true),
              muted: false,
            ),
    ),
  );
}
