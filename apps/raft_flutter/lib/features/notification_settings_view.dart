import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/native_notifications.dart';

class NotificationSettingsView extends StatelessWidget {
  const NotificationSettingsView({super.key, required this.service});
  final NativeNotificationService service;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(raftText(context, 'System notifications')),
          subtitle: Text(
            raftText(
              context,
              service.receivesMessages
                  ? 'Messages arrive while connected. Background inbox checks provide a fallback when the system allows them; delivery may be delayed.'
                  : 'This server does not send desktop message notifications. You can test system delivery.',
            ),
          ),
          value: service.enabled,
          onChanged: service.requestEnable,
        ),
        if (service.backgroundError != null || service.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              raftText(context, service.backgroundError ?? service.error!),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: service.enabled ? service.test : null,
              child: Text(raftText(context, 'Send test notification')),
            ),
            if (service.canOpenSettings)
              TextButton(
                onPressed: service.openSettings,
                child: Text(raftText(context, 'Open system settings')),
              ),
          ],
        ),
      ],
    ),
  );
}
