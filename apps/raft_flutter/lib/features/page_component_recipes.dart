import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// Component layer, traced to raft-ui0.5.27 search recipe (dist/index.mjs) and
/// pinned SettingsProfileCard.tsx. Components consume shared semantic roles;
/// individual pages do not own a second color or typography palette.
class RaftSearchRecipe {
  const RaftSearchRecipe(this.t, {required this.mobile});
  final RaftTokens t;
  final bool mobile;
  EdgeInsets get viewportInset => t.brutal
      ? const EdgeInsets.all(16)
      : mobile
      ? const EdgeInsets.fromLTRB(20, 12, 14, 12)
      : const EdgeInsets.all(12);
  EdgeInsets get sectionInset =>
      t.brutal ? EdgeInsets.zero : const EdgeInsets.all(12);
  double get sectionRadius => t.brutal ? 0 : 10;
  double get cardRadius => t.brutal ? 0 : 8;
  double get gap => t.brutal ? 8 : 6;
  Color get background => t.panel;
  Color get sectionFill => t.brutal
      ? t.panel
      : t.dark
      ? t.card
      : Color.alphaBlend(t.strong.withValues(alpha: .04), t.panel);
  BorderSide get border => BorderSide(
    color: t.dark
        ? Colors.transparent
        : t.brutal
        ? t.strong.withValues(alpha: .3)
        : t.line,
    width: t.brutal ? 2 : .5,
  );
  EdgeInsets get messageHeaderInset => t.brutal
      ? const EdgeInsets.fromLTRB(12, 12, 12, 4)
      : const EdgeInsets.fromLTRB(12, 10, 12, 4);
  EdgeInsets get messageBodyInset => t.brutal
      ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
      : const EdgeInsets.fromLTRB(12, 0, 12, 10);
  EdgeInsets get entityInset => const EdgeInsets.all(12);
  Color get selectedLine => t.brutal ? t.strong : t.colors['primary-400']!;
  Color get highlight => t.brutal
      ? t.colors['primary-400']!
      : t.colors['primary-400']!.withValues(alpha: .7);
  TextStyle get sender => metadata.copyWith(
    color: t.brutal ? t.strong : t.muted,
    fontWeight: t.brutal ? FontWeight.w700 : FontWeight.w500,
  );
  TextStyle get timestamp => t.brutal
      ? RaftTypography.mono(
          t,
          size: 12,
          line: 16,
          color: t.strong.withValues(alpha: .4),
        )
      : RaftTypography.body(
          t,
          size: 12,
          line: 16,
          color: t.muted.withValues(alpha: .7),
        );

  TextStyle get summary => RaftTypography.body(
    t,
    size: 12,
    line: 16,
    weight: t.brutal ? FontWeight.w700 : FontWeight.w500,
    color: t.muted,
  );
  TextStyle get sectionTitle => t.brutal
      ? RaftTypography.mono(
          t,
          size: 10,
          line: 15,
          color: t.muted,
        ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 2)
      : RaftTypography.body(
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
    color: t.brutal ? t.strong.withValues(alpha: .7) : t.muted,
  ).copyWith(letterSpacing: t.brutal ? 0 : -.14);
  TextStyle get entityTitle => RaftTypography.body(
    t,
    size: 14,
    line: 20,
    weight: t.brutal ? FontWeight.w700 : FontWeight.w500,
  );
  TextStyle get metadata => RaftTypography.body(
    t,
    size: 12,
    line: 16,
    weight: t.brutal ? FontWeight.w700 : FontWeight.w500,
    color: t.muted,
  );
}

class RaftSettingsProfileRecipe {
  const RaftSettingsProfileRecipe(this.t);
  final RaftTokens t;
  static const double avatarSize = 64, gap = 16, fieldGap = 12;
  static const inset = EdgeInsets.all(16);
  BoxDecoration get surface => BoxDecoration(
    color: t.panel,
    border: Border.all(color: t.line, width: t.border),
    boxShadow: t.shadows,
  );
  TextStyle get title =>
      RaftTypography.body(t, size: 18, line: 22.5, weight: FontWeight.w700);
  TextStyle get subtitle =>
      RaftTypography.mono(t, size: 14, line: 20, color: t.muted);
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
    final t = RaftTokens.of(context),
        recipe = RaftSettingsProfileRecipe(RaftTokens.of(context));
    return Container(
      padding: RaftSettingsProfileRecipe.inset,
      decoration: recipe.surface,
      child: Material(
        color: t.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: RaftSettingsProfileRecipe.avatarSize,
                  child: avatar,
                ),
                const SizedBox(width: RaftSettingsProfileRecipe.gap),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: title,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: recipe.title,
                          ),
                        ),
                        Tooltip(
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
            Divider(height: 1, color: t.line),
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
  static const navigationWidth = 220.0;
  static const navigationGlyphSize = 15.0;
  static const navigationInset = EdgeInsets.fromLTRB(8, 12, 8, 12);
  static const contentInset = EdgeInsets.all(16);
  Color get navigationFill => t.brutal ? t.colors['brutal-cream']! : t.sidebar;
  Color get navigationLine =>
      t.brutal ? t.strong.withValues(alpha: .25) : t.line;
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
    width: t.brutal ? 2 : .5,
    color: selected
        ? (t.brutal ? t.strong : t.accent)
        : t.colors['line-muted']!,
  );
  List<BoxShadow> get shadow => selected && t.brutal ? t.shadows : const [];
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
  static const tagInset = EdgeInsets.fromLTRB(10, 6, 4, 6);
  static const tagHeight = 28.0;
  static const desktopColumnsBreakpoint = 640.0;
  static const touchHistoryBreakpoint = 768.0;
  Color get tagBackground => tokens.card;
  Color get tagBorder =>
      tokens.brutal ? tokens.strong.withValues(alpha: .2) : tokens.line;
  TextStyle get historyLabel =>
      RaftTypography.body(tokens, size: 12, line: 16, weight: FontWeight.w500);
}
