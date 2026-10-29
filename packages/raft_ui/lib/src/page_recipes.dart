import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'settings_layout.dart';
import 'separator.dart';
import 'theme.dart';
import 'tooltip.dart' show RaftTooltip;

/// Component layer, traced to raft-ui 0.5.52 search recipe (dist/index.mjs) and
/// pinned SettingsProfileCard.tsx. Components consume shared semantic roles;
/// individual pages do not own a second color or typography palette.
class RaftSearchRecipe {
  const RaftSearchRecipe(this.t, {required this.mobile});
  final RaftTokens t;
  final bool mobile;
  // Current search results use flat groups (Web px-4 headings and summary),
  // while the generated framed recipe remains available to the older packs.
  EdgeInsets get flatSectionHeadingInset =>
      const EdgeInsets.fromLTRB(16, 20, 16, 8);
  EdgeInsets get flatResultsInset => const EdgeInsets.only(bottom: 16);
  EdgeInsets get flatSummaryInset => const EdgeInsets.fromLTRB(16, 8, 16, 0);
  BoxDecoration get flatEntityIconSurface => BoxDecoration(
    color: t.colors['fill-muted'],
    borderRadius: BorderRadius.circular(t.size('radius.sticker', fallback: 4)),
  );
  Widget resultSeparator({required bool flat, required double framedGap}) =>
      SizedBox(height: flat ? 0 : framedGap);
  EdgeInsets get viewportInset => mobile
      ? const EdgeInsets.fromLTRB(20, 12, 14, 12)
      : const EdgeInsets.all(12);
  EdgeInsets get sectionInset => const EdgeInsets.all(12);
  double get sectionRadius => 10;
  double get cardRadius => 8;
  double get gap => 6;
  Color get background => t.panel;
  Color get sectionFill => t.dark
      ? t.card
      : Color.alphaBlend(t.strong.withValues(alpha: .04), t.panel);
  BorderSide get border =>
      BorderSide(color: t.dark ? Colors.transparent : t.line, width: .5);
  EdgeInsets get messageHeaderInset => const EdgeInsets.fromLTRB(12, 10, 12, 4);
  EdgeInsets get messageBodyInset => const EdgeInsets.fromLTRB(12, 0, 12, 10);
  EdgeInsets get entityInset => const EdgeInsets.all(12);
  Color get selectedLine => t.colors['primary-400']!;
  Color get highlight => t.colors['primary-400']!.withValues(alpha: .7);
  TextStyle get sender =>
      metadata.copyWith(color: t.muted, fontWeight: FontWeight.w500);
  TextStyle get timestamp => RaftTypography.body(
    t,
    size: 12,
    line: 16,
    color: t.muted.withValues(alpha: .7),
  );

  TextStyle get summary => RaftTypography.body(
    t,
    size: 12,
    line: 16,
    weight: FontWeight.w500,
    color: t.muted,
  );
  TextStyle get sectionTitle => RaftTypography.body(
    t,
    size: 12,
    line: 16,
    weight: FontWeight.w500,
    color: t.muted,
  );
  TextStyle get snippet => RaftTypography.body(
    t,
    size: 14,
    line: 21,
    color: t.muted,
  ).copyWith(letterSpacing: -.14);
  TextStyle get entityTitle =>
      RaftTypography.body(t, size: 14, line: 20, weight: FontWeight.w500);
  TextStyle get metadata => RaftTypography.body(
    t,
    size: 12,
    line: 16,
    weight: FontWeight.w500,
    color: t.muted,
  );
}

class RaftSettingsProfileRecipe {
  const RaftSettingsProfileRecipe(this.t);
  final RaftTokens t;
  static const double avatarSize = 64, gap = 16, fieldGap = 12;
  // `border-t border-line-muted`
  static const double dividerWidth = 1;
  static const inset = EdgeInsets.all(16);
  // SettingsProfileCard.tsx: the shared settings card surface.
  BoxDecoration get surface => RaftSettingsCard.decoration(t);
  // `text-lg font-bold leading-tight text-foreground-strong theme-brutal:text-black`
  TextStyle get title => RaftTypography.body(
    t,
    size: t.size('type.settingsCardTitle.size', fallback: 18),
    line: t.size('type.settingsCardTitle.line', fallback: 22.5),
    weight: FontWeight.w700,
    color: RaftSettingsText(t).strong,
  );
  // `font-mono text-sm text-foreground-muted theme-brutal:text-black/50`
  TextStyle get subtitle => RaftTypography.mono(
    t,
    size: t.size('type.settingsCardMeta.size', fallback: 14),
    line: t.size('type.settingsCardMeta.line', fallback: 20),
    color: RaftSettingsText(t).faint,
  );
  // `border-t border-line-muted`
  Color get divider => t.colors['line-muted']!;
  TextStyle get label => RaftTypography.body(
    t,
    size: 12,
    line: 16,
    weight: FontWeight.w500,
    color: t.muted,
  );
}

class RaftSettingsProfileCard extends StatelessWidget {
  const RaftSettingsProfileCard({
    super.key,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final Widget avatar, child;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftSettingsProfileRecipe(RaftTokens.of(context));
    return Container(
      padding: RaftSettingsProfileRecipe.inset,
      decoration: recipe.surface,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: RaftSettingsProfileRecipe.avatarSize,
                  child: Center(child: avatar),
                ),
                const SizedBox(width: RaftSettingsProfileRecipe.gap),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RaftTooltip(
                          onlyWhenTruncated: true,
                          message: title,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: recipe.title,
                          ),
                        ),
                        RaftTooltip(
                          onlyWhenTruncated: true,
                          message: subtitle,
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: recipe.subtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RaftSettingsProfileRecipe.gap),
            RaftSeparator(
              thickness: RaftSettingsProfileRecipe.dividerWidth,
              color: recipe.divider,
            ),
            const SizedBox(height: RaftSettingsProfileRecipe.gap),
            child,
          ],
        ),
      ),
    );
  }
}

/// Product SettingsNavList / SettingsPanel / AppearanceThemePicker metrics.
class RaftSettingsLayoutRecipe {
  const RaftSettingsLayoutRecipe(this.t);
  final RaftTokens t;
  // Sidebar slot width (AdaptiveWorkspace sidebarWidth default 240).
  static const navigationWidth = 240.0;
  static const navigationHeaderInset = EdgeInsets.symmetric(
    horizontal: RaftSpace.x5,
  );
  BorderSide get navigationHeaderLine =>
      BorderSide(color: RaftSettingsText(t).edge, width: t.border);
  TextStyle get navigationTitle => RaftTypography.heading(
    t,
    size: 18,
    line: 28,
    weight: FontWeight.w700,
  ).copyWith(color: RaftSettingsText(t).strong);
  static const navigationGlyphSize = 15.0;
  static const navigationInset = EdgeInsets.fromLTRB(8, 12, 8, 12);
  static const contentInset = EdgeInsets.all(16);
  Color get navigationFill => t.sidebar;
  Color get navigationLine => t.line;
  double headerHeight(double height) =>
      RaftLayoutMetrics.shellHeaderHeight(t, height);
  TextStyle get groupLabel => RaftTypography.body(
    t,
    size: 10,
    line: 15,
    weight: FontWeight.w700,
    color: t.colors['foreground-placeholder'],
  ).copyWith(letterSpacing: 1);
  TextStyle get modeLabel => RaftTypography.body(
    t,
    size: 12,
    line: 16,
    weight: FontWeight.w700,
    color: t.muted,
  ).copyWith(letterSpacing: 1.2);
  TextStyle get sectionTitle =>
      RaftTypography.body(t, size: 14, line: 20, weight: FontWeight.w700);
  TextStyle get description =>
      RaftTypography.body(t, size: 12, line: 16, color: t.muted);
  TextStyle get currentLabel => RaftTypography.body(
    t,
    size: 10,
    line: 15,
    weight: FontWeight.w700,
    color: t.colors['primary-strong'],
  );
}

class RaftAppearanceCardRecipe {
  const RaftAppearanceCardRecipe(this.t, {required this.selected});
  final RaftTokens t;
  final bool selected;
  BorderSide get border => BorderSide(
    width: .5,
    color: selected ? (t.accent) : t.colors['line-muted']!,
  );
  List<BoxShadow> get shadow => const [];
}

/// Component tokens: pinned MessageSearchPage.tsx Search-home p-4, gap-2,
/// SectionEyebrow and history-tag recipe; semantic roles come from raft_ui.
class RaftSearchHomeRecipe {
  const RaftSearchHomeRecipe(this.tokens);
  final RaftTokens tokens;
  static const inset = EdgeInsets.all(16);
  static const sectionGap = 24.0;
  static const tagGap = 8.0;
  static const headingInset = EdgeInsets.fromLTRB(4, 0, 4, 8);

  /// Web `py-1.5 pl-2.5 pr-1` around a 16px line. The 28px [tagHeight] is a
  /// minimum (CSS min-height) that centres the line; the vertical inset is the
  /// breathing room that makes the tag grow once the line is taller than 16px
  /// (larger text, the Android Chinese profile), not part of the 28px: with the
  /// control's own border it would squeeze the line into a box shorter than it.
  static const tagInset = EdgeInsets.fromLTRB(10, 2, 4, 2);
  static const tagHeight = 28.0;
  static const desktopColumnsBreakpoint = 640.0;
  Color get tagBackground => tokens.card;
  Color get tagBorder => tokens.line;
  TextStyle get historyLabel =>
      RaftTypography.body(tokens, size: 12, line: 16, weight: FontWeight.w500);
}
