import 'package:flutter/material.dart';

import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'components.dart';
import 'settings_controls.dart' show RaftSettingsRecipeBadge;
import 'settings_layout.dart';
import 'theme.dart';
import '../recipes.dart';

/// SettingsPanel.tsx WebPushNotificationsCard mounted composition. Transport,
/// permission facts, subscription state and member preference writes belong to
/// the caller. Native hosts supply their actual delivery description/actions.
class RaftNotificationSettingsCard extends StatelessWidget {
  const RaftNotificationSettingsCard({
    super.key,
    required this.title,
    required this.description,
    required this.status,
    required this.enableLabel,
    required this.muted,
    this.availabilityHint,
    this.error,
    this.message,
    this.muteDescription,
    this.testLabel = 'Send test notification',
    this.saveLabel = 'Save',
    this.showTest = false,
    this.showSettings = false,
    this.onEnable,
    this.onTest,
    this.onOpenSettings,
    this.onRetry,
    this.onMutedChanged,
    this.onSave,
  });
  final String title, description, status, enableLabel, testLabel, saveLabel;
  final String? availabilityHint, error, message, muteDescription;
  final bool muted, showTest, showSettings;
  final VoidCallback? onEnable, onTest, onOpenSettings, onRetry, onSave;
  final ValueChanged<bool>? onMutedChanged;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final inherited = DefaultTextStyle.of(context).style;
    final titleStyle = inherited.copyWith(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w700,
      color: RaftSettingsText(t).strong,
    );
    final hint = inherited.copyWith(
      fontSize: 12,
      height: 16 / 12,
      color: RaftSettingsText(t).muted,
    );
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
                        Text(raftText(context, title), style: titleStyle),
                        const SizedBox(height: 2),
                        Text(raftText(context, description), style: hint),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  RaftSettingsRecipeBadge(
                    label: status,
                    variant: RaftBadgeRecipeVariant.muted,
                    uppercase: true,
                  ),
                ],
              ),
              if (availabilityHint != null) ...[
                const SizedBox(height: 12),
                Text(raftText(context, availabilityHint!), style: hint),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: RaftRecipeBox(
                    style: RaftBannerRecipe.resolve(
                      theme: t.recipeTheme,
                      status: RaftBannerRecipeStatus.warning,
                      size: RaftBannerRecipeSize.sm,
                      states: t.recipeStates(),
                      tokens: t.recipeTokens,
                    ).root,
                    tokens: t.recipeTokens,
                    child: Text(
                      raftText(context, error!),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (onRetry != null)
                  RaftButton(
                    label: 'Retry',
                    tone: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: onRetry,
                  ),
              ],
              if (message != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.colors['color-brutal-lime']!.withValues(
                        alpha: .3,
                      ),
                      border: Border.all(
                        color: t.brutal
                            ? Colors.black
                            : t.colors['line-muted']!,
                        width: t.brutal ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      message!,
                      style: hint.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  RaftButton(
                    label: enableLabel,
                    tone: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: onEnable,
                  ),
                  if (showTest)
                    RaftButton(
                      label: testLabel,
                      tone: RaftButtonRecipeVariant.success,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: onTest,
                    ),
                  if (showSettings)
                    RaftButton(
                      label: 'Open system settings',
                      tone: RaftButtonRecipeVariant.outline,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: onOpenSettings,
                    ),
                ],
              ),
              if (muteDescription != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: t.brutal
                            ? Colors.black.withValues(alpha: .2)
                            : t.colors['line-muted']!,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTap: onMutedChanged == null
                            ? null
                            : () => onMutedChanged!(!muted),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: RaftCheckbox(
                                value: muted,
                                size: RaftCheckboxRecipeSize.md,
                                semanticLabel: raftText(
                                  context,
                                  'Mute this server',
                                ),
                                onChanged: onMutedChanged,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    raftText(context, 'Mute this server'),
                                    style: titleStyle,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(muteDescription!, style: hint),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: RaftButton(
                          key: const ValueKey('notification-settings-save'),
                          label: saveLabel,
                          tone: RaftButtonRecipeVariant.accent,
                          size: RaftButtonRecipeSize.sm,
                          onPressed: onSave,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
