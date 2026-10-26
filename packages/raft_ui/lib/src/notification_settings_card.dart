import 'package:flutter/material.dart';
import 'raft/checkbox.dart' show RaftCheckbox;
import 'package:flutter/rendering.dart';

import 'icons.dart';
import 'error_presentation.dart' show RaftErrorBanner;
import 'localization.dart';
import 'components.dart';
import 'settings_layout.dart';
import 'theme.dart';
import '../recipes.dart';

/// SettingsPanel.tsx DesktopNativeNotificationsCard mounted composition: a
/// SectionHeader (Bell) over a card holding the title, description and status
/// pill, the system hint, an optional warning Banner or success message and
/// one action button. The caller owns the copy, the permission facts and the
/// server mute form (phones only; Web's desktop card has none).
class RaftNotificationSettingsCard extends StatelessWidget {
  const RaftNotificationSettingsCard({
    super.key,
    required this.title,
    required this.description,
    required this.status,
    required this.actionLabel,
    required this.muted,
    this.sectionLabel = 'Notifications',
    this.hint,
    this.notice,
    this.noticeActionLabel,
    this.onNoticeAction,
    this.error,
    this.message,
    this.muteDescription,
    this.actionTone = RaftButtonRecipeVariant.success,
    this.saveLabel = 'Save',
    this.onAction,
    this.onRetry,
    this.onMutedChanged,
    this.onSave,
  });
  final String sectionLabel, title, description, status, actionLabel, saveLabel;
  final String? hint, error, message, muteDescription;

  /// A short action the person can take outside the app for notifications to
  /// work (Android battery optimisation), with one button for it.
  final String? notice, noticeActionLabel;
  final bool muted;
  final RaftButtonRecipeVariant actionTone;
  final VoidCallback? onAction, onRetry, onSave, onNoticeAction;
  final ValueChanged<bool>? onMutedChanged;

  /// `inline-flex shrink-0 border border-line-strong bg-primary-soft px-2 py-1
  /// text-[10px] font-bold text-primary-strong theme-brutal:border-2
  /// theme-brutal:border-black theme-brutal:bg-soft-signal theme-brutal:text-black`.
  static Widget statusPill(BuildContext context, String label) {
    final t = RaftTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.colors['primary-soft'],
        border: Border.all(color: t.colors['line-strong']!, width: 1),
      ),
      child: Text(
        raftText(context, label),
        maxLines: 1,
        softWrap: false,
        // Web: `font-display` (Hanken Grotesk) at 10px bold, line-height 1.5.
        style: TextStyle(
          fontFamily: t.headingFont,
          fontFamilyFallback: t.fontFallback,
          fontSize: 10,
          height: 1.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: t.colors['primary-strong'],
        ),
      ),
    );
  }

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
    final hintStyle = inherited.copyWith(
      fontSize: 12,
      height: 16 / 12,
      color: RaftSettingsText(t).muted,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSettingsSectionHeader(label: sectionLabel, glyph: RaftGlyph.bell),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: RaftSettingsCard.decoration(t).copyWith(color: t.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(raftText(context, title), style: titleStyle),
                          const SizedBox(height: 2),
                          Text(
                            raftText(context, description),
                            style: hintStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _PixelCenter(child: statusPill(context, status)),
                  ],
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 12),
                Text(raftText(context, hint!), style: hintStyle),
              ],
              if (notice != null) ...[
                const SizedBox(height: 12),
                Text(
                  raftText(context, notice!),
                  key: const ValueKey('notification-settings-notice'),
                  style: hintStyle.copyWith(fontWeight: FontWeight.w700),
                ),
                if (noticeActionLabel != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RaftButton(
                      key: const ValueKey(
                        'notification-settings-notice-action',
                      ),
                      label: noticeActionLabel!,
                      tone: RaftButtonRecipeVariant.outline,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: onNoticeAction,
                    ),
                  ),
                ],
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                // Web SettingsPanel: `<Banner intent="warning" density="sm" className="font-bold">`.
                RaftErrorBanner(error!, small: true, bold: true),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RaftButton(
                      label: 'Retry',
                      tone: RaftButtonRecipeVariant.outline,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: onRetry,
                    ),
                  ),
                ],
              ],
              if (message != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  // `border border-line-muted bg-success-soft p-2 text-xs
                  // font-bold text-success-strong theme-brutal:border-2
                  // theme-brutal:border-black theme-brutal:bg-brutal-lime/30
                  // theme-brutal:text-black`.
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.colors['success-soft'],
                      border: Border.all(
                        color: t.colors['line-muted']!,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      message!,
                      style: hintStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: t.colors['success-strong'],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: RaftButton(
                  key: const ValueKey('notification-settings-action'),
                  label: actionLabel,
                  tone: actionTone,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: onAction,
                ),
              ),
              if (muteDescription != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: t.colors['line-muted']!, width: 2),
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
                                  Text(muteDescription!, style: hintStyle),
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

/// `items-center` for a bordered chip: Chromium snaps box edges to whole
/// pixels, so the centred offset is rounded instead of blurring a 1px border
/// across two pixel rows.
class _PixelCenter extends SingleChildRenderObjectWidget {
  const _PixelCenter({required Widget child}) : super(child: child);
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPixelCenter();
}

class _RenderPixelCenter extends RenderShiftedBox {
  _RenderPixelCenter() : super(null);
  @override
  void performLayout() {
    final c = child!;
    c.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(c.size);
    (c.parentData! as BoxParentData).offset = Offset(
      ((size.width - c.size.width) / 2).roundToDouble(),
      ((size.height - c.size.height) / 2).roundToDouble(),
    );
  }
}
