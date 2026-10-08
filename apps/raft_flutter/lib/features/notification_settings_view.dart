import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    show RaftBadgeRecipeVariant, RaftButtonRecipeSize, RaftButtonRecipeVariant;

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
      final strong = t.brutal ? Colors.black : t.strong;
      final muted = t.brutal ? Colors.black.withValues(alpha: .6) : t.muted;
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
                          const SizedBox(height: 2),
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
                    const SizedBox(width: 12),
                    RaftRecipeBadge(
                      label: service.enabled ? 'Enabled' : 'Disabled',
                      variant: RaftBadgeRecipeVariant.muted,
                      uppercase: true,
                    ),
                  ],
                ),
                if (problem != null) ...[
                  const SizedBox(height: 12),
                  Text(raftText(context, problem), style: hint),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (service.enabled) ...[
                      RaftRecipeButton(
                        label: 'Disable Push Notifications',
                        size: RaftButtonRecipeSize.sm,
                        onPressed: () => service.requestEnable(false),
                      ),
                      RaftRecipeButton(
                        label: 'Send test notification',
                        variant: RaftButtonRecipeVariant.success,
                        size: RaftButtonRecipeSize.sm,
                        onPressed: service.test,
                      ),
                    ] else
                      RaftRecipeButton(
                        label: 'Enable Push Notifications',
                        size: RaftButtonRecipeSize.sm,
                        onPressed: () => service.requestEnable(true),
                      ),
                    if (service.canOpenSettings)
                      RaftRecipeButton(
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
