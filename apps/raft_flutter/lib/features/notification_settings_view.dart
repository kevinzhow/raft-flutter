import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/native_notifications.dart';

/// SettingsPanel.tsx NotificationsSection in the WebPushNotificationsCard
/// layout (SectionHeader + `p-4 space-y-3` card: title/description with an
/// uppercase muted status Badge, hints, then `flex gap-2` sm actions). The
/// app's channel is the platform notification service, so the copy and the
/// actions are the native ones.
class NotificationSettingsView extends StatelessWidget {
  const NotificationSettingsView({super.key, required this.service});
  final NativeNotificationService service;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) {
      final t = RaftTokens.of(context);
      final strong = RaftSettingsText(t).strong;
      final muted = RaftSettingsText(t).muted;
      final hint = RaftTypography.body(t, size: 12, line: 16, color: muted);
      final problem = service.backgroundError ?? service.error;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RaftSettingsSectionHeader(
            label: 'Push Notifications',
            glyph: RaftGlyph.bell,
          ),
          RaftSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            raftText(context, 'System notifications'),
                            style: RaftTypography.body(
                              t,
                              size: 14,
                              line: 20,
                              weight: FontWeight.w700,
                              color: strong,
                            ),
                          ),
                          const SizedBox(height: RaftSpace.half),
                          Text(
                            raftText(
                              context,
                              service.receivesMessages
                                  ? 'Messages arrive while connected. Background inbox checks provide a fallback when the system allows them; delivery may be delayed.'
                                  : 'This server does not send desktop message notifications. You can test system delivery.',
                            ),
                            style: hint,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: RaftSpace.x3),
                    RaftSettingsRecipeBadge(
                      label: service.enabled ? 'Enabled' : 'Disabled',
                      variant: RaftBadgeRecipeVariant.muted,
                      uppercase: true,
                    ),
                  ],
                ),
                if (problem != null) ...[
                  const SizedBox(height: RaftSpace.x3),
                  Text(raftText(context, problem), style: hint),
                ],
                const SizedBox(height: RaftSpace.x3),
                Wrap(
                  spacing: RaftSpace.x2,
                  runSpacing: RaftSpace.x2,
                  children: [
                    if (service.enabled) ...[
                      RaftSettingsRecipeButton(
                        label: 'Disable Push Notifications',
                        size: RaftButtonRecipeSize.sm,
                        onPressed: () => service.requestEnable(false),
                      ),
                      RaftSettingsRecipeButton(
                        label: 'Send test notification',
                        variant: RaftButtonRecipeVariant.success,
                        size: RaftButtonRecipeSize.sm,
                        onPressed: service.test,
                      ),
                    ] else
                      RaftSettingsRecipeButton(
                        label: 'Enable Push Notifications',
                        size: RaftButtonRecipeSize.sm,
                        onPressed: () => service.requestEnable(true),
                      ),
                    if (service.canOpenSettings)
                      RaftSettingsRecipeButton(
                        label: 'Open system settings',
                        size: RaftButtonRecipeSize.sm,
                        onPressed: service.openSettings,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
