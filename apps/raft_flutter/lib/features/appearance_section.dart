import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/personal_presentation.dart';
import '../data/rail_side_preference.dart';
import '../platform/app_icon.dart';
import 'app_icon_settings_section.dart';
import 'message_type_scale.dart';

/// Component tokens traced to SettingsPanel.tsx AppearanceSection cards p-4,
/// border-line-muted/bg-layer-panel/shadow-raft-sm and14/20,12/16 hierarchy.
class RaftAppearanceSectionRecipe {
  const RaftAppearanceSectionRecipe(this.t);
  final RaftTokens t;
  static const inset = EdgeInsets.all(16);
  static const gap = 16.0;
  static const gapAbove = EdgeInsets.only(top: gap);
  BoxDecoration get card => RaftSettingsCard.decoration(t);

  /// v1.21.23 AppearanceSection: `text-subhead font-semibold` title,
  /// `text-footnote text-foreground-muted` description, `text-caption
  /// text-foreground-hint` note.
  TextStyle get heading => RaftTypography.body(
    t,
    size: t.typeSlot('subhead').fontSize,
    line: t.typeSlot('subhead').lineHeight,
    weight: FontWeight.w600,
    color: t.colors['foreground'],
  );
  TextStyle get description => RaftTypography.body(
    t,
    size: t.typeSlot('footnote').fontSize,
    line: t.typeSlot('footnote').lineHeight,
    color: t.muted,
  );
  TextStyle get annotation => RaftTypography.body(
    t,
    size: t.typeSlot('caption').fontSize,
    line: t.typeSlot('caption').lineHeight,
    color: t.colors['foreground-hint'],
  );

  /// The "Preview" label above the message sample: v1.21.23 draws it
  /// `text-footnote font-bold` (13/18 700).
  TextStyle get previewLabel => RaftTypography.body(
    t,
    size: t.typeSlot('footnote').fontSize,
    line: t.typeSlot('footnote').lineHeight,
    weight: FontWeight.w700,
    color: t.colors['foreground-hint'],
  );
}

class RaftAppearanceSection extends StatelessWidget {
  const RaftAppearanceSection({
    super.key,
    required this.appearance,
    required this.onAppearance,
    required this.presentation,
    this.railSide,
    this.publicSurface = false,
  }) : assert(publicSurface || presentation != null);
  final RaftAppearance appearance;
  final ValueChanged<RaftAppearance> onAppearance;
  final PersonalPresentationStore? presentation;

  /// Web public surfaces offer only the device-local theme picker.
  final bool publicSurface;

  /// The device's rail side choice. Always offered on touch-first platforms
  /// (phones and foldables take it in every layout); on computers only while
  /// a narrow window shows the phone rail. Null hides the row.
  final RailSideStore? railSide;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: presentation ?? const AlwaysStoppedAnimation(null),
    builder: (context, _) {
      final r = RaftAppearanceSectionRecipe(RaftTokens.of(context)),
          value = presentation?.value ?? const PersonalPresentation(),
          captured = presentation?.key;
      Widget card(List<Widget> children, {double spacing = 0}) => Container(
        padding: RaftAppearanceSectionRecipe.inset,
        decoration: r.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: children,
        ),
      );
      Widget title(String heading, String description) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(raftText(context, heading), style: r.heading),
          const SizedBox(height: 4),
          Text(raftText(context, description), style: r.description),
        ],
      );
      Widget toggle(
        String key,
        String heading,
        String description,
        bool current,
        void Function(bool) changed,
      ) => card([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title(heading, description),
                  const SizedBox(height: 8),
                  Text(
                    raftText(context, 'Saved on this device.'),
                    style: r.annotation,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            RaftSwitch(
              key: ValueKey(key),
              value: current,
              semanticLabel: heading,
              semanticDescription: description,
              onChanged: captured == null ? null : changed,
            ),
          ],
        ),
      ]);
      Widget themeCard() => card([
        Padding(
          padding: const EdgeInsets.only(bottom: RaftSpace.x3),
          child: title(
            'Theme',
            'Choose light, dark, or follow your device. Your choice is saved on this device.',
          ),
        ),
        RaftAppearanceModeCards(
          appearance: appearance,
          onChanged: onAppearance,
        ),
      ]);
      if (publicSurface) return themeCard();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Web `Card className="mb-6 p-4"`: the Light / Dark / System
          // preview cards.
          themeCard(),
          const SizedBox(height: RaftSpace.x6),
          const RaftSettingsSectionHeader(
            label: 'Appearance',
            glyph: RaftGlyph.type,
          ),
          card([
            title(
              'Message font size',
              'Adjust rendered message text on this device, including headings, code blocks, inline code, and reference chips. Buttons, labels, and sidebar keep their fixed UI sizes.',
            ),
            const SizedBox(height: 16),
            RaftSegmentedControl<String>(
              value: value.font,
              label: 'Message font size',
              items: [
                RaftSegmentedOption(
                  value: 'sm',
                  label: raftText(context, 'Small'),
                ),
                RaftSegmentedOption(
                  value: 'md',
                  label: raftText(context, 'Medium'),
                ),
                RaftSegmentedOption(
                  value: 'lg',
                  label: raftText(context, 'Large'),
                ),
              ],
              onChanged: captured == null
                  ? null
                  : (font) => presentation!.update(captured, font: font),
            ),
            const SizedBox(height: 16),
            Text(
              raftText(context, 'Saved on this device.'),
              style: r.annotation,
            ),
            const SizedBox(height: 16),
            Text(raftText(context, 'Preview'), style: r.previewLabel),
            const SizedBox(height: 8),
            IgnorePointer(
              child: Semantics(
                label: raftText(context, 'Message font size preview'),
                child: RaftMessageTile(
                  author: 'Cindy',
                  content: '@Joy #proj-uiux love the new design — doing a `git pull` now to try it locally.',
                  timestamp: '',
                  badge: 'Agent',
                  bodyFontSize: messagePreferenceDisplaySize(
                    context,
                    value.fontSize,
                  ),
                  body: RaftMessageBody(
                    content: '@Joy #proj-uiux love the new design — doing a `git pull` now to try it locally.',
                    fontSize: messagePreferenceDisplaySize(
                      context,
                      value.fontSize,
                    ),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: RaftAppearanceSectionRecipe.gap),
          toggle(
            'appearance-live-activity',
            'Live agent activity',
            'Show which agents are working, and what they are doing, at the top of the window and on the Home bar.',
            value.liveActivity,
            (show) => presentation!.update(captured, liveActivity: show),
          ),
          const SizedBox(height: RaftAppearanceSectionRecipe.gap),
          toggle(
            'appearance-agent-model',
            'Show agent model',
            "Show each agent's model next to its name in chat. On by default in the desktop app.",
            value.modelName,
            (show) => presentation!.update(captured, modelName: show),
          ),
          const SizedBox(height: RaftAppearanceSectionRecipe.gap),
          toggle(
            'appearance-hide-empty',
            'Hide empty sidebar sections',
            'Hide sidebar sections while they have nothing in them (empty Pinned, Joint Channels, Direct Messages). On by default in the desktop app.',
            value.hideEmptySections,
            (hide) => presentation!.update(captured, hideEmptySections: hide),
          ),
          if (railSide != null &&
              (railSideFollowsChoice() || railChoiceAvailable(context)))
            Padding(
              padding: RaftAppearanceSectionRecipe.gapAbove,
              child: ListenableBuilder(
                listenable: railSide!,
                builder: (context, _) {
                  final rtl = Directionality.of(context) == TextDirection.rtl;
                  // The options name the side the user sees, in any direction.
                  String visual(bool right) => right
                      ? raftTextZh(context, 'Right', '右侧')
                      : raftTextZh(context, 'Left', '左侧');
                  return card([
                    title(
                      'Navigation rail',
                      'Applies when the screen is wide or in landscape',
                    ),
                    RaftSegmentedControl<RaftRailSide>(
                      key: const ValueKey('appearance-rail-side'),
                      value: railSide!.side,
                      label: raftText(context, 'Navigation rail'),
                      items: [
                        RaftSegmentedOption(
                          value: RaftRailSide.start,
                          label: visual(rtl),
                        ),
                        RaftSegmentedOption(
                          value: RaftRailSide.end,
                          label: visual(!rtl),
                        ),
                      ],
                      onChanged: railSide!.update,
                    ),
                    Text(
                      raftText(context, 'Saved on this device.'),
                      style: r.annotation,
                    ),
                  ], spacing: RaftAppearanceSectionRecipe.gap);
                },
              ),
            ),
          // A product addition that Web v1.21.23 has no counterpart for sits
          // after its sections: on a phone, the app icon.
          if (NativeAppIcon.instance.mobile) ...[
            const SizedBox(height: RaftAppearanceSectionRecipe.gap),
            const RaftSettingsSectionHeader(
              label: 'App icon',
              glyph: RaftGlyph.smartphone,
            ),
            const AppIconSettingsSection(),
          ],
        ],
      );
    },
  );
}

/// Whether this window can show the phone rail on either side. On computers
/// the window decides (size and shape), so the desktop layout does not get a
/// setting that has no effect there; touch-first platforms always get it
/// (see [railSideFollowsChoice]).
bool railChoiceAvailable(BuildContext context) =>
    RaftAdaptiveWorkspace.phoneRailOf(context, side: RaftRailSide.start) ||
    RaftAdaptiveWorkspace.phoneRailOf(context, side: RaftRailSide.end);
