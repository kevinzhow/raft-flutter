import 'hover_region.dart';
import 'interaction.dart';
import 'raft_underline.dart';
import 'anchored_popup.dart';
import 'dismiss_scope.dart';
import 'tooltip.dart';
import 'text_scaling.dart' show RaftChrome, RaftScaled;
import 'large_content_viewer.dart';
import 'search_result_surface.dart';
import 'inline_badge_editor.dart' show RaftTouchTargetExpander;

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import 'mobile_page_header.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'localization.dart';
import 'theme.dart';
import 'primitive_tokens.dart';
import 'tokens/tokens.dart';
import 'control_typography.dart';
import 'recipe_surface.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/segmented_control.g.dart';

enum RaftDensity { desktop, touch }

/// Input density changes hit/layout bounds, never the source visual recipe.
class RaftDensityScope extends InheritedWidget {
  const RaftDensityScope({
    super.key,
    required this.density,
    required super.child,
  });
  final RaftDensity density;
  static RaftDensity of(BuildContext context) =>
      RaftInteraction.of(context).touch
      ? RaftDensity.touch
      : RaftDensity.desktop;
  @override
  bool updateShouldNotify(RaftDensityScope oldWidget) =>
      density != oldWidget.density;
}

@immutable
class RaftControlBounds {
  const RaftControlBounds({
    required this.visualHeight,
    required this.density,
    this.minimumTargetSize,
  });
  final double visualHeight;
  final RaftDensity density;
  final double? minimumTargetSize;
  double get layoutHeight =>
      minimumTargetSize ??
      (density == RaftDensity.touch ? RaftMetrics.touchTarget : visualHeight);
  double get hitHeight => layoutHeight;
  double get visualBoundsHeight => visualHeight;
}

/// Shared recipe geometry from raft-ui 0.5.27 and pinned Web product overrides.
/// Visual dimensions are independent of the native accessible touch rectangle.
abstract final class RaftMetrics {
  static const double touchTarget = 48;
  static const double buttonXs = 24,
      buttonSm = 28,
      buttonMd = 32,
      buttonLg = 36;
  static const double iconXs = 12, iconSm = 14, iconMd = 16;
  static const double fieldHorizontalPadding = 12, fieldVerticalPadding = 8;
  static const double railItem = 40,
      railItemCompact = 36,
      railSlot = 44,
      railGlyph = 18;
  static const double panelHeader = 56,
      brutalPanelHeader = 62,
      compactPanelHeader = 48;
  static const double composerGap = 8,
      composerInputMax = 128,
      elegantComposerInputMin = 64;
  static const double attachmentWidth = 176, attachmentHeight = 80;
}

/// Product layout recipe, not per-page coordinate overrides.
abstract final class RaftLayoutMetrics {
  static double shellHeaderHeight(RaftTokens t, double viewportHeight) =>
      viewportHeight <= 600
      ? RaftMetrics.compactPanelHeader
      : t.brutal
      ? RaftMetrics.brutalPanelHeader
      : RaftMetrics.panelHeader;
  static double railWidth(RaftTokens t, double viewportHeight) => t.brutal
      ? viewportHeight <= 600
            ? 50
            : 64
      : 56;
  static const double desktopBreakpoint = 768, threadOverlayBreakpoint = 1024;
  // index.css900–940: actual thread-layout container + portrait xl rule.
  static const threadSplitContainerWidth = 680.0;
  static const threadPortraitSplitViewport = 1280.0;
  static const double panelInset = 20, panelIcon = 36, panelGap = 12;
  static const EdgeInsets toolbarInset = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );
}

enum RaftSidebarVariant { generic, mountedProduct }

/// Library Sidebar recipe3151 and the mounted Sidebar.tsx2286/3769/3840.
/// Product overrides stay explicit; generic overlay padding must not leak into it.
@immutable
class RaftSidebarRecipe {
  const RaftSidebarRecipe(
    this.tokens, {
    required this.viewportWidth,
    required this.viewportHeight,
    this.variant = RaftSidebarVariant.generic,
    this.workspaceEnabled = false,
  });
  final RaftTokens tokens;
  final double viewportWidth, viewportHeight;
  final RaftSidebarVariant variant;
  final bool workspaceEnabled;
  bool get desktop => viewportWidth >= RaftLayoutMetrics.desktopBreakpoint;
  bool get product => variant == RaftSidebarVariant.mountedProduct;
  bool get headerOverlaysContent => !product && !tokens.brutal;
  // SidebarBody3151–3204 and mounted Sidebar3754 use the muted canvas;
  // the Brutal mobile product explicitly replaces its cream with white.
  Color get bodyBackground => tokens.brutal
      ? desktop
            ? tokens.colors['brutal-cream']!
            : tokens.panel
      : tokens.sidebar;
  double get headerHeight => product && desktop && workspaceEnabled
      ? RaftMetrics.compactPanelHeader
      : RaftLayoutMetrics.shellHeaderHeight(tokens, viewportHeight);
  EdgeInsetsDirectional get headerInset => product || tokens.brutal
      ? EdgeInsetsDirectional.symmetric(
          horizontal: desktop && !workspaceEnabled ? 20 : 16,
        )
      : EdgeInsetsDirectional.only(
          start: desktop ? 26 : 28,
          end: desktop ? 18 : 28,
        );
  EdgeInsetsDirectional contentInset({
    bool headerInFlow = false,
    bool liveActivity = false,
    double bottomInset = 0,

    /// False when the phone's navigation is the side rail: nothing floats at
    /// the bottom, so the list reserves no capsule clearance.
    bool bottomBar = true,
  }) => EdgeInsetsDirectional.only(
    start: product || tokens.brutal
        ? 8
        : desktop
        ? 26
        : 28,
    end: product || tokens.brutal
        ? 8
        : desktop
        ? 18
        : 28,
    top: product || tokens.brutal
        ? 12
        : headerInFlow
        ? 0
        : headerHeight,
    bottom: product
        ? !desktop && !tokens.brutal
              ? (bottomBar ? (liveActivity ? 116 : 68) : 12) + bottomInset
              : 12
        : liveActivity && desktop
        ? tokens.brutal
              ? 52
              : 68
        : 12,
  );
}

enum RaftPanelHeaderVariant { canonical, tasks }

@immutable
class RaftPanelHeaderRecipe {
  const RaftPanelHeaderRecipe(
    this.tokens, {
    required this.viewportHeight,
    this.mobile = false,
    this.variant = RaftPanelHeaderVariant.canonical,
  });
  final RaftPanelHeaderVariant variant;
  final RaftTokens tokens;
  final double viewportHeight;
  final bool mobile;
  double get height =>
      RaftLayoutMetrics.shellHeaderHeight(tokens, viewportHeight);
  Color get background =>
      mobile && tokens.brutal && variant == RaftPanelHeaderVariant.tasks
      ? tokens.colors['color-soft-signal']!
      : variant == RaftPanelHeaderVariant.tasks || tokens.brutal
      ? tokens.panel
      : tokens.colors['layer-canvas-muted']!;
  Color get iconBackground =>
      tokens.brutal ? tokens.primaryFill : tokens.colors['primary-soft']!;
  Color get foreground => tokens.strong;
  BorderSide get border =>
      !tokens.brutal && variant == RaftPanelHeaderVariant.canonical
      ? BorderSide.none
      // Brutal PanelHeader `border-b-2 border-black`: pure black, not ink.
      : BorderSide(
          color: tokens.brutal ? Colors.black : tokens.line,
          width: tokens.border,
        );
  BorderRadius get iconRadius => BorderRadius.circular(tokens.brutal ? 0 : 6);
  EdgeInsets get inset =>
      const EdgeInsets.symmetric(horizontal: RaftLayoutMetrics.panelInset);
  TextStyle get title => variant == RaftPanelHeaderVariant.tasks
      ? RaftTypography.heading(tokens, size: 16, line: 20)
      : RaftTypography.heading(
          tokens,
          size: tokens.brutal ? 18 : 17,
          line: tokens.brutal ? 22.5 : 21.25,
          weight: tokens.brutal ? FontWeight.w700 : FontWeight.w500,
        );
  TextStyle get subtitle => RaftTypography.mono(tokens);
}

@immutable
class RaftRailRecipe {
  const RaftRailRecipe(this.tokens, {required this.viewportHeight});
  final RaftTokens tokens;
  final double viewportHeight;
  double get width => RaftLayoutMetrics.railWidth(tokens, viewportHeight);
  double get glyphSize => tokens.brutal ? 18 : 16;
  double get itemSize => tokens.brutal && viewportHeight <= 600
      ? RaftMetrics.railItemCompact
      : RaftMetrics.railItem;
  // AppRailRoot's bg-primary resolves the primary-400 ramp; primaryFill is
  // the separate product Button alias and differs by one blue channel.
  Color get background =>
      tokens.brutal ? tokens.colors['primary-400']! : tokens.sidebar;
  Color get selectedBackground => tokens.brutal
      ? tokens.panel
      : tokens.dark
      ? tokens.card
      : tokens.colors['fill-strong']!;
  Color get identityBackground =>
      tokens.brutal ? tokens.colors['brutal-cream']! : tokens.panel;
  Color get foreground => tokens.strong;
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 6);
  BorderRadius get avatarRadius => BorderRadius.circular(tokens.brutal ? 0 : 8);
  // AppRailRoot `theme-brutal:border-r-2 border-black`: pure black, not the ink line token.
  BorderSide get border => BorderSide(
    color: tokens.brutal ? Colors.black : tokens.line,
    width: tokens.border,
  );
}

@immutable
class RaftCodeRecipe {
  const RaftCodeRecipe(this.tokens);
  final RaftTokens tokens;
  Color get background => tokens.colors['color-code-surface']!;
  Color get foreground => tokens.colors['color-code-foreground']!;
  Color get border => tokens.colors['code-border']!;
  BorderRadius get radius => RaftShapes.field(tokens);
  TextStyle get textStyle => RaftTypography.code(tokens);
}

@immutable
class RaftAttachmentRecipe {
  const RaftAttachmentRecipe(this.tokens);
  final RaftTokens tokens;
  Size get size =>
      const Size(RaftMetrics.attachmentWidth, RaftMetrics.attachmentHeight);
  Color get background => tokens.panel;
  BorderSide border({bool hovered = false, bool focused = false}) => BorderSide(
    color: tokens.brutal
        ? Colors.black.withValues(alpha: hovered || focused ? .3 : .15)
        : tokens.colors[hovered || focused ? 'line-muted' : 'line-hairline']!,
  );
  BorderRadius get radius => RaftShapes.attachment(tokens);
  TextStyle get title =>
      RaftTypography.attachmentTitle(tokens)
          .copyWith(fontWeight: FontWeight.w700);
  TextStyle get metadata => RaftTypography.attachmentMeta(tokens);
}

enum RaftSansSize { large, body, small, caption }

/// Marks a subtree that inherits the page's `font-family` (the theme's
/// heading family) instead of Geist: recipe-driven `Badge` and
/// `SegmentedControl` labels render Inter inside a Settings panel but Geist in
/// a Dialog portal.
class RaftInheritedFontScope extends InheritedWidget {
  const RaftInheritedFontScope({super.key, required super.child});
  static bool active(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftInheritedFontScope>() !=
      null;
  @override
  bool updateShouldNotify(RaftInheritedFontScope old) => false;
}

abstract final class RaftTypography {
  /// CSS `font-black` (900). Web serves the raft-ui families with
  /// `wght@300..700` / `400..700` @font-face ranges, so Chromium clamps 900
  /// to the 700 instance. Flutter's bundled faces go to 900 (and a 900
  /// request pinned to wght 700 is synthetically emboldened), so render the
  /// 700 instance the Web shows. System fonts keep their own heavy face.
  static FontWeight black(RaftTokens t) =>
      t.systemFonts ? FontWeight.w900 : FontWeight.w700;

  static TextStyle heading(
    RaftTokens t, {
    double size = 16,
    double line = 24,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) => TextStyle(
    locale: t.textLocale,
    fontFamily: t.headingFont,
    fontVariations: t.brutal || t.systemFonts
        ? null
        : [FontVariation('opsz', size.clamp(14.0, 32.0).toDouble())],
    fontFamilyFallback: t.fontFallback,
    fontSize: size,
    height: line / size,
    fontWeight: weight,
    letterSpacing: 0,
    color: color ?? t.strong,
  );

  /// Original Text.Heading recipe; compact product titles use heading instead.
  static TextStyle textHeading(RaftTokens t, {int level = 1, Color? color}) {
    final index = level.clamp(1, 6).toInt() - 1;
    const sizes = [56.0, 48.0, 40.0, 32.0, 24.0, 20.0];
    const lines = [64.0, 56.0, 48.0, 40.0, 32.0, 28.0];
    final size = sizes[index];
    return heading(
      t,
      size: size,
      line: lines[index],
      weight: FontWeight.w500,
    ).copyWith(
      color: color ?? t.ink,
      letterSpacing: index < 3
          ? -size * .01
          : index == 3
          ? -size * .005
          : 0,
    );
  }

  static TextStyle sans(
    RaftTokens t, {
    RaftSansSize size = RaftSansSize.body,
    Color? color,
  }) {
    final (fontSize, line) = switch (size) {
      RaftSansSize.large => (18.0, 28.0),
      RaftSansSize.body => (16.0, 24.0),
      RaftSansSize.small => (14.0, 20.0),
      RaftSansSize.caption => (12.0, 16.0),
    };
    return body(
      t,
      size: fontSize,
      line: line,
      color:
          color ??
          (size == RaftSansSize.small || size == RaftSansSize.caption
              ? t.muted
              : t.strong),
    );
  }

  static TextStyle body(
    RaftTokens t, {
    double size = 16,
    double line = 24,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    locale: t.textLocale,
    fontFamily: t.bodyFont,
    fontFamilyFallback: t.fontFallback,
    fontSize: size,
    height: line / size,
    fontWeight: weight,
    letterSpacing: 0,
    color: color ?? t.strong,
  );

  /// Text that inherits the page's `font-family` (no `font-sans` class): the
  /// Web body resolves to the theme's heading family (Inter in elegant, Hanken
  /// Grotesk in brutal), while the `font-sans` utility ([body]) is Geist.
  static TextStyle inherited(
    RaftTokens t, {
    double size = 16,
    double line = 24,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => body(
    t,
    size: size,
    line: line,
    weight: weight,
    color: color,
  ).copyWith(fontFamily: t.headingFont);
  static TextStyle mono(
    RaftTokens t, {
    double size = 12,
    double line = 16,
    Color? color,
  }) => TextStyle(
    locale: t.textLocale,
    fontFamily: t.monoFont,
    fontSize: size,
    height: line / size,
    letterSpacing: 0,
    color: color ?? t.muted,
  );
  static TextStyle attachmentTitle(RaftTokens t) =>
      body(t, size: 12, line: 16, weight: FontWeight.w500);
  static TextStyle attachmentMeta(RaftTokens t) =>
      body(t, size: 10, line: 12, color: t.muted);
  static TextStyle code(RaftTokens t) =>
      mono(t, size: 14, line: 20, color: t.ink);
}

abstract final class RaftShapes {
  static BorderRadius control(RaftTokens t, double visualHeight) =>
      BorderRadius.circular(
        t.brutal
            ? 0
            : visualHeight < 32
            ? 4
            : 6,
      );
  static BorderRadius field(RaftTokens t) =>
      BorderRadius.circular(t.fieldRadius);
  static BorderRadius panel(RaftTokens t) => BorderRadius.circular(t.radius);
  static BorderRadius attachment(RaftTokens t) =>
      BorderRadius.circular(t.brutal ? 0 : 6);
}

enum RaftControlKind {
  button,
  filter,
  tab,
  segmentedButton,
  sidebar,
  textLink,
  savedAction,
}

enum RaftSegmentedStyle { tabs, buttons, taskViews }

enum RaftControlVariant { surface, primary, accent, outline, ghost, danger }

@immutable
class RaftControlRecipe {
  const RaftControlRecipe(
    this.tokens, {
    this.variant = RaftControlVariant.surface,
    this.kind = RaftControlKind.button,
    this.selected = false,
    this.visualHeight = RaftMetrics.buttonMd,
    this.highContrast = false,
  });
  final bool highContrast;
  final RaftControlKind kind;
  final bool selected;
  final RaftTokens tokens;
  final RaftControlVariant variant;
  final double visualHeight;
  bool get transformsOnInteraction => true;

  /// Optional CSS outline, independent of selected borders/rings/shadows.
  double get focusOutlineWidth => 0;
  double get focusOutlineOffset => 0;
  double get disabledOpacity => .4;
  Color foregroundFor({bool hovered = false}) => foreground;
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered);
  Color get focusRing => tokens.brutal
      ? Colors.transparent
      : switch (variant) {
          RaftControlVariant.surface ||
          RaftControlVariant.outline => tokens.ink,
          RaftControlVariant.ghost => tokens.colors['line-hairline']!,
          RaftControlVariant.danger => tokens.colors['danger']!,
          RaftControlVariant.primary => tokens.colors['primary-strong']!,
          RaftControlVariant.accent => tokens.colors['accent-strong']!,
        };
  Color get background => kind == RaftControlKind.savedAction
      ? tokens.colors['accent-soft']!.withValues(
          alpha: tokens.colors['accent-soft']!.a * .3,
        )
      : kind == RaftControlKind.textLink
      ? Colors.transparent
      : highContrast && !tokens.brutal && variant == RaftControlVariant.danger
      ? tokens.colors['button-danger-high-contrast']!
      : kind == RaftControlKind.sidebar && selected
      ? tokens.brutal
            ? tokens.accentFill
            : tokens.dark
            ? tokens.card
            : tokens.panel
      : kind == RaftControlKind.tab
      ? selected
            ? tokens.primaryFill
            : tokens.dark
            ? tokens.colors['fill-muted']!
            : tokens.panel
      : switch (variant) {
          RaftControlVariant.primary =>
            tokens.brutal ? tokens.primaryFill : tokens.colors['primary-soft']!,
          RaftControlVariant.accent =>
            tokens.brutal ? tokens.accentFill : tokens.colors['accent-soft']!,
          RaftControlVariant.danger =>
            tokens.brutal
                ? tokens.colors['color-brutal-red']!
                : tokens.colors['button-danger-fill']!,
          RaftControlVariant.ghost => Colors.transparent,
          RaftControlVariant.outline =>
            tokens.brutal || !tokens.dark
                ? tokens.panel
                : tokens.colors['fill-muted']!,
          RaftControlVariant.surface =>
            tokens.brutal
                ? tokens.panel
                : tokens.colors['button-default-fill']!,
        };
  Color get foreground => kind == RaftControlKind.savedAction
      ? tokens.colors[tokens.brutal ? 'color-brutal-orange' : 'accent-strong']!
      : kind == RaftControlKind.textLink
      ? tokens.brutal
            ? Colors.black.withValues(alpha: .6)
            : tokens.muted
      : highContrast && !tokens.brutal && variant == RaftControlVariant.danger
      ? tokens.colors['button-danger-high-contrast-foreground']!
      : kind == RaftControlKind.tab
      ? selected && !tokens.brutal
            ? tokens.colors['primary-950']!
            : tokens.brutal
            ? tokens.strong
            : tokens.ink
      : tokens.brutal
      ? tokens.strong
      : switch (variant) {
          RaftControlVariant.primary => tokens.colors['primary-strong']!,
          RaftControlVariant.accent => tokens.colors['accent-strong']!,
          RaftControlVariant.danger =>
            tokens.colors['button-danger-foreground']!,
          RaftControlVariant.surface => tokens.colors['foreground-inverse']!,
          RaftControlVariant.ghost => tokens.muted,
          RaftControlVariant.outline => tokens.dark ? tokens.muted : tokens.ink,
        };
  Color backgroundFor({bool hovered = false}) {
    if (kind == RaftControlKind.savedAction) return background;
    if (kind == RaftControlKind.textLink) return Colors.transparent;
    if (!hovered ||
        tokens.brutal ||
        highContrast && variant == RaftControlVariant.danger)
      return background;
    if (kind == RaftControlKind.tab) return background;
    return switch (variant) {
      RaftControlVariant.primary => tokens.colors['button-primary-hover']!,
      RaftControlVariant.accent => tokens.colors['button-accent-hover']!,
      RaftControlVariant.danger => tokens.colors['button-danger-hover']!,
      RaftControlVariant.ghost => tokens.colors['ink-4']!,
      RaftControlVariant.outline =>
        tokens.colors[tokens.dark ? 'fill-strong' : 'fill-muted']!,
      RaftControlVariant.surface => tokens.colors['button-default-hover']!,
    };
  }

  Gradient? get overlayGradient {
    if (tokens.brutal ||
        kind == RaftControlKind.savedAction ||
        kind == RaftControlKind.textLink ||
        kind == RaftControlKind.tab ||
        variant == RaftControlVariant.ghost)
      return null;
    if (variant == RaftControlVariant.outline)
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: .01),
        ],
        stops: const [0, .3, 1],
      );
    final alpha = switch (variant) {
      RaftControlVariant.surface => .08,
      RaftControlVariant.danger => .10,
      _ => .04,
    };
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: alpha),
        Colors.white.withValues(alpha: 0),
      ],
    );
  }

  double get insetHighlightAlpha =>
      tokens.brutal ||
          kind == RaftControlKind.textLink ||
          kind == RaftControlKind.savedAction
      ? 0
      : kind == RaftControlKind.tab
      ? .05
      : switch (variant) {
          RaftControlVariant.surface || RaftControlVariant.danger => .12,
          RaftControlVariant.primary || RaftControlVariant.accent => .04,
          RaftControlVariant.outline => .05,
          RaftControlVariant.ghost => 0,
        };
  BorderRadius get radius => kind == RaftControlKind.textLink
      ? BorderRadius.zero
      : kind == RaftControlKind.tab
      ? BorderRadius.circular(tokens.brutal ? 0 : 4)
      : RaftShapes.control(tokens, visualHeight);
  double get iconSize => kind == RaftControlKind.segmentedButton
      ? 12
      : kind == RaftControlKind.tab
      ? 13
      : kind == RaftControlKind.filter
      ? 16
      : visualHeight <= 24
      ? 12
      : visualHeight <= 28
      ? 14
      : 16;
  TextStyle get textStyle => TextStyle(
    locale: tokens.textLocale,
    fontFamily: tokens.brutal ? tokens.headingFont : tokens.bodyFont,
    fontFamilyFallback: tokens.systemFonts ? tokens.fontFallback : null,
    fontSize: kind == RaftControlKind.segmentedButton
        ? 12
        : kind == RaftControlKind.tab
        ? 11
        : kind == RaftControlKind.filter
        ? 12
        : visualHeight <= 24
        ? 11
        : visualHeight <= 28
        ? 12
        : visualHeight <= 32
        ? 14
        : 16,
    height: kind == RaftControlKind.segmentedButton
        ? 16 / 12
        : kind == RaftControlKind.tab
        ? 16 / 11
        : kind == RaftControlKind.filter
        ? 16 / 12
        : visualHeight <= 24
        ? 16 / 11
        : visualHeight <= 28
        ? 16 / 12
        : visualHeight <= 32
        ? 20 / 14
        : 24 / 16,
    fontWeight: kind == RaftControlKind.tab
        ? tokens.brutal
              ? FontWeight.w600
              : FontWeight.w500
        : kind == RaftControlKind.filter || tokens.brutal
        ? FontWeight.w700
        : FontWeight.w500,
    letterSpacing: 0,
    color: foreground,
  );
  EdgeInsets get padding => kind == RaftControlKind.textLink
      ? EdgeInsets.zero
      : EdgeInsets.symmetric(
          horizontal: kind == RaftControlKind.sidebar
              ? tokens.brutal
                    ? 8
                    : 6
              : kind == RaftControlKind.segmentedButton
              ? 10
              : kind == RaftControlKind.tab
              ? 8
              : kind == RaftControlKind.filter
              ? 10
              : visualHeight <= 24
              ? 8
              : visualHeight <= 28
              ? 10
              : visualHeight <= 32
              ? 12
              : 14,
        );
  BorderSide side({bool hovered = false}) => BorderSide(
    color:
        kind == RaftControlKind.textLink ||
            variant == RaftControlVariant.ghost && !hovered
        ? Colors.transparent
        : tokens.line,
    width: tokens.brutal && kind != RaftControlKind.textLink ? 2 : 0,
    style: tokens.brutal && kind != RaftControlKind.textLink
        ? BorderStyle.solid
        : BorderStyle.none,
  );
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) {
    if (kind == RaftControlKind.savedAction && !tokens.brutal) {
      return focused
          ? [BoxShadow(color: tokens.colors['primary-500']!, spreadRadius: .5)]
          : const [];
    }
    if (kind == RaftControlKind.textLink) return const [];
    if (variant == RaftControlVariant.ghost ||
        kind == RaftControlKind.tab && tokens.brutal)
      return const [];
    if (tokens.brutal)
      return [
        BoxShadow(
          color: tokens.strong,
          offset: Offset(
            pressed
                ? 1
                : hovered
                ? 4
                : 2,
            pressed
                ? 1
                : hovered
                ? 4
                : 2,
          ),
        ),
      ];
    if (kind == RaftControlKind.tab) {
      if (tokens.dark)
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .15),
            offset: const Offset(0, 6),
            blurRadius: 6,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .25),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ];
      return [
        BoxShadow(
          color: selected
              ? tokens.colors['primary-edge']!.withValues(alpha: .7)
              : tokens.colors['line-muted']!,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: (selected ? tokens.colors['primary-400']! : Colors.black)
              .withValues(alpha: selected ? .08 : .035),
          offset: const Offset(0, 1),
          blurRadius: 1.5,
          spreadRadius: -1,
        ),
      ];
    }
    final edge = switch (variant) {
      RaftControlVariant.surface => tokens.colors['button-default-fill']!,
      RaftControlVariant.primary => tokens.colors['primary-edge']!,
      RaftControlVariant.accent => tokens.colors['button-accent-edge']!,
      RaftControlVariant.danger => tokens.colors['danger']!,
      _ => tokens.colors['line-muted']!,
    };
    return [
      if (tokens.dark) ...[
        BoxShadow(
          color: RaftPrimitiveColors.black.withValues(alpha: .4),
          spreadRadius: 1,
        ),
        BoxShadow(
          color: RaftPrimitiveColors.black.withValues(alpha: .22),
          offset: const Offset(0, 1),
          blurRadius: 3,
        ),
      ] else
        BoxShadow(color: edge, spreadRadius: 1),
      if (focused)
        BoxShadow(
          color: focusRing.withValues(alpha: focusRing.a * .8),
          spreadRadius: 3,
        ),
    ];
  }
}

/// A Web-recipe visual surface inside a keyboard and touch accessible target.
class RaftControl extends StatefulWidget {
  const RaftControl({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = RaftControlVariant.surface,
    this.kind = RaftControlKind.button,
    this.selected = false,
    this.visualHeight = RaftMetrics.buttonMd,
    this.flexibleHeight = false,
    this.visualWidth,
    this.shadow = true,
    this.minimumTargetSize,
    this.tooltip,
    this.busy = false,
    this.semanticLabel,
    this.padding,
    this.focusNode,
    this.focusOnPointer = true,
    this.recipe,
    this.inertWhenDisabled = false,
  });
  final Widget child;
  final VoidCallback? onPressed;

  /// A control whose affordance can arrive after first paint (e.g. a message
  /// author that becomes linkable) keeps one widget shape and paints the same
  /// without [onPressed]: no disabled dimming and no button semantics.
  final bool inertWhenDisabled;
  final RaftControlVariant variant;
  final RaftControlKind kind;
  final bool selected;
  final double visualHeight;

  /// Content-sized box (CSS `min-height`): [visualHeight] is the minimum and a
  /// wrapping child (the pinned sidebar rows) may grow it.
  final bool flexibleHeight;
  final double? minimumTargetSize;
  final double? visualWidth;
  final String? tooltip;
  final bool busy, shadow;

  /// Composer actions retain editor focus on pointer; keyboard activation stays available.
  final bool focusOnPointer;
  final String? semanticLabel;
  final EdgeInsetsGeometry? padding;
  final FocusNode? focusNode;
  final RaftControlRecipe? recipe;
  @override
  State<RaftControl> createState() => _RaftControlState();
}

/// CSS focus-visible is keyboard modality, not Flutter's mouse/traditional
/// focus mode. This process-local tracker stores no account or product state.
class _RaftFocusVisible extends ChangeNotifier {
  static final shared = _RaftFocusVisible();
  bool keyboard = true;
  int users = 0;
  void acquire() {
    if (users++ == 0) {
      HardwareKeyboard.instance.addHandler(key);
      GestureBinding.instance.pointerRouter.addGlobalRoute(pointer);
    }
  }

  void release() {
    if (--users == 0) {
      HardwareKeyboard.instance.removeHandler(key);
      GestureBinding.instance.pointerRouter.removeGlobalRoute(pointer);
      keyboard = true;
    }
  }

  void update(bool value) {
    if (keyboard == value) return;
    keyboard = value;
    notifyListeners();
  }

  bool key(KeyEvent event) {
    if (event is KeyDownEvent) update(true);
    return false;
  }

  void pointer(PointerEvent event) {
    if (event is PointerDownEvent) update(false);
  }
}

class _RaftControlState extends State<RaftControl> {
  bool hovered = false, focused = false, pressed = false;
  // Tooltip admission follows a focus entry, while outline paint follows the
  // current modality. Escape can change the latter without entering focus.
  bool tooltipKeyboardFocused = false;
  final ownedFocus = FocusNode();
  FocusNode get controlFocus => widget.focusNode ?? ownedFocus;
  @override
  void initState() {
    super.initState();
    _RaftFocusVisible.shared.acquire();
    _RaftFocusVisible.shared.addListener(focusModeChanged);
  }

  void focusModeChanged() {
    final next =
        enabled && controlFocus.hasFocus && _RaftFocusVisible.shared.keyboard;
    final tooltipNext = tooltipKeyboardFocused && next;
    if (mounted && (focused != next || tooltipKeyboardFocused != tooltipNext)) {
      setState(() {
        focused = next;
        tooltipKeyboardFocused = tooltipNext;
      });
    }
  }

  void focusEntered(bool hasFocus) {
    if (!mounted) return;
    setState(() {
      focused = enabled && hasFocus && _RaftFocusVisible.shared.keyboard;
      tooltipKeyboardFocused = focused;
    });
  }

  @override
  void dispose() {
    _RaftFocusVisible.shared.removeListener(focusModeChanged);
    _RaftFocusVisible.shared.release();
    ownedFocus.dispose();
    super.dispose();
  }

  void activateControl() {
    if (!enabled) return;
    controlFocus.requestFocus();
    widget.onPressed?.call();
  }

  bool get enabled => widget.onPressed != null && !widget.busy;
  @override
  void didUpdateWidget(RaftControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!enabled) {
      pressed = false;
      hovered = false;
      focused = false;
      tooltipKeyboardFocused = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final flexible = widget.flexibleHeight || RaftScaled.grows(context);
    final bounds = RaftControlBounds(
      visualHeight: widget.visualHeight,
      density: RaftDensityScope.of(context),
      minimumTargetSize: widget.minimumTargetSize,
    );
    final recipe =
        widget.recipe ??
        RaftControlRecipe(
          t,
          variant: widget.variant,
          kind: widget.kind,
          selected: widget.selected,
          visualHeight: widget.visualHeight,
          highContrast: MediaQuery.highContrastOf(context),
        );
    final scale =
        recipe.transformsOnInteraction &&
            !t.brutal &&
            pressed &&
            !reducedMotion &&
            widget.kind != RaftControlKind.textLink &&
            widget.kind != RaftControlKind.savedAction
        ? .985
        : 1.0;
    final bg = recipe.backgroundForInteraction(
      hovered: hovered,
      pressed: pressed,
    );
    final inert = widget.inertWhenDisabled && !enabled;
    Widget result = Semantics(
      label: widget.semanticLabel,
      excludeSemantics: widget.busy,
      button:
          !inert &&
          !{
            RaftControlKind.tab,
            RaftControlKind.segmentedButton,
          }.contains(widget.kind),
      checked:
          {
            RaftControlKind.tab,
            RaftControlKind.segmentedButton,
          }.contains(widget.kind)
          ? widget.selected
          : null,
      inMutuallyExclusiveGroup: {
        RaftControlKind.tab,
        RaftControlKind.segmentedButton,
      }.contains(widget.kind),
      selected: widget.kind == RaftControlKind.sidebar ? widget.selected : null,
      toggled: widget.kind == RaftControlKind.savedAction
          ? widget.selected
          : null,
      enabled: inert ? null : enabled,
      onTap: enabled ? activateControl : null,
      child: RaftHoverRegion(
        onEnter: enabled ? (_) => setState(() => hovered = true) : null,
        onExit: (_) => setState(() => hovered = false),
        child: FocusableActionDetector(
          focusNode: controlFocus,
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (_) => focusModeChanged(),
          onFocusChange: focusEntered,
          actions: {
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) {
                activateControl();
                return null;
              },
            ),
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                activateControl();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: enabled
                ? (_) {
                    if (widget.focusOnPointer) controlFocus.requestFocus();
                    setState(() => pressed = true);
                  }
                : null,
            onTapUp: enabled
                ? (details) {
                    setState(() => pressed = false);
                    final box = context.findRenderObject();
                    // A finger may land in the enlarged touch target around
                    // the control (RaftTapSlopAnchor / RaftTouchTarget), so
                    // touch taps accept the target's reach, not just the box.
                    final reach = details.kind == PointerDeviceKind.touch
                        ? RaftMetrics.touchTarget / 2
                        : 0.0;
                    if (box is RenderBox &&
                        (Offset.zero & box.size)
                            .inflate(reach)
                            .contains(details.localPosition))
                      widget.onPressed?.call();
                  }
                : null,
            onTapCancel: enabled ? () => setState(() => pressed = false) : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth:
                    widget.minimumTargetSize ??
                    (RaftDensityScope.of(context) == RaftDensity.touch
                        ? RaftMetrics.touchTarget
                        : widget.visualWidth ?? 0),
                minHeight: bounds.layoutHeight,
              ),
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Opacity(
                  opacity: enabled || widget.busy || inert
                      ? 1
                      : recipe.disabledOpacity,
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : RaftPrimitives.controlDuration,
                    curve: RaftPrimitives.controlCurve,
                    // A control labelled with scaled text is a minimum height
                    // (CSS min-height): at 1.0x it is the pinned visual height.
                    height: flexible ? null : widget.visualHeight,
                    constraints: flexible
                        ? BoxConstraints(minHeight: widget.visualHeight)
                        : null,
                    width: widget.visualWidth,
                    transformAlignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(scale, scale, 1)
                      ..setTranslationRaw(
                        recipe.transformsOnInteraction &&
                                t.brutal &&
                                pressed &&
                                !reducedMotion &&
                                widget.kind != RaftControlKind.textLink
                            ? 1
                            : 0,
                        recipe.transformsOnInteraction &&
                                t.brutal &&
                                !reducedMotion &&
                                widget.kind != RaftControlKind.textLink
                            ? pressed
                                  ? 1
                                  : hovered
                                  ? -1
                                  : 0
                            : 0,
                        0,
                      ),
                    decoration: RaftCssBoxDecoration(
                      color: bg,
                      borderRadius: recipe.radius,
                      border: Border.fromBorderSide(
                        recipe.side(hovered: hovered),
                      ),
                      boxShadow: widget.shadow
                          ? recipe.shadows(
                              hovered: hovered,
                              pressed: pressed,
                              focused: focused,
                            )
                          : focused
                          ? [
                              BoxShadow(
                                color: recipe.focusRing.withValues(
                                  alpha: recipe.focusRing.a * .8,
                                ),
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        if (focused && recipe.focusOutlineWidth > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _ControlFocusOutlinePainter(
                                  color: recipe.focusRing,
                                  width: recipe.focusOutlineWidth,
                                  offset: recipe.focusOutlineOffset,
                                  radius: recipe.radius.resolve(
                                    Directionality.of(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (focused &&
                            (widget.kind == RaftControlKind.textLink ||
                                widget.kind == RaftControlKind.savedAction &&
                                    t.brutal))
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _TextLinkFocusPainter(
                                  t.brutal
                                      ? Colors.black
                                      : t.colors['line-strong']!,
                                ),
                              ),
                            ),
                          ),
                        if (recipe.overlayGradient != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: recipe.overlayGradient,
                                  borderRadius: recipe.radius,
                                ),
                              ),
                            ),
                          ),
                        if (recipe.insetHighlightAlpha > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _InsetHighlightPainter(
                                  recipe.radius,
                                  Colors.white.withValues(
                                    alpha: recipe.insetHighlightAlpha,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding:
                              widget.padding ??
                              (widget.visualWidth == null
                                  ? recipe.padding
                                  : EdgeInsets.zero),
                          child: IconTheme(
                            data: IconThemeData(
                              color:
                                  widget.kind == RaftControlKind.textLink &&
                                      hovered
                                  ? t.strong
                                  : recipe.foregroundFor(hovered: hovered),
                              size: recipe.iconSize,
                            ),
                            child: DefaultTextStyle(
                              style: RaftControlTypography.of(
                                context,
                                recipe.textStyle.copyWith(
                                  color:
                                      widget.kind == RaftControlKind.textLink &&
                                          hovered
                                      ? t.strong
                                      : recipe.foregroundFor(hovered: hovered),
                                ),
                              ),
                              child: Center(
                                widthFactor: 1,
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      result = RaftTooltip(
        message: widget.tooltip!,
        keyboardFocused: tooltipKeyboardFocused,
        child: result,
      );
    }
    return result;
  }
}

class RaftIconButton extends StatelessWidget {
  const RaftIconButton({
    super.key,
    required this.glyph,
    this.onPressed,
    this.tooltip,
    this.visualSize = RaftMetrics.buttonMd,
    this.minimumTargetSize,
    this.glyphSize,
    this.variant = RaftControlVariant.ghost,
    this.shadow = true,
    this.busy = false,
    this.semanticLabel,
  });
  final RaftGlyph glyph;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// The accessible name when it differs from the [tooltip] (Web `aria-label`
  /// that carries more than the tooltip text).
  final String? semanticLabel;
  final double visualSize;
  final double? minimumTargetSize;
  final double? glyphSize;
  final RaftControlVariant variant;
  final bool busy, shadow;
  @override
  Widget build(BuildContext context) {
    final button = RaftControl(
      shadow: shadow,
      onPressed: onPressed,
      tooltip: tooltip == null ? null : raftText(context, tooltip!),
      visualHeight: visualSize,
      visualWidth: visualSize,
      minimumTargetSize: minimumTargetSize,
      variant: variant,
      busy: busy,
      semanticLabel: busy
          ? raftText(context, tooltip ?? 'Loading')
          : semanticLabel,
      child: busy
          ? RaftSpinner(size: glyphSize)
          : RaftIcon(glyph, size: glyphSize ?? (visualSize <= 28 ? 14 : 16)),
    );
    final label = tooltip;
    if (label == null) return button;
    // An icon button is fixed chrome: at large text sizes a long press shows
    // its icon and label large (Large Content Viewer).
    return RaftChrome(
      child: RaftLargeContentViewer(
        label: raftText(context, label),
        enabled: onPressed != null && !busy,
        onActivate: onPressed,
        iconBuilder: (context, size) => RaftIcon(glyph, size: size),
        child: button,
      ),
    );
  }
}

/// Canonical framed navigation action; product callers supply source size.
class RaftBackButton extends StatelessWidget {
  const RaftBackButton({
    super.key,
    this.onPressed,
    this.visualSize = 28,
    this.tooltip = 'Back',
  });
  final VoidCallback? onPressed;
  final double visualSize;
  final String tooltip;
  @override
  Widget build(BuildContext context) =>
      MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint
      ? RaftMobileBackButton(onPressed: onPressed, tooltip: tooltip)
      : RaftIconButton(
          glyph: RaftGlyph.arrowLeft,
          glyphSize: 16,
          visualSize: visualSize,
          variant: RaftControlVariant.outline,
          tooltip: tooltip,
          onPressed: onPressed,
        );
}

/// Source Saved card action: filled Bookmark geometry on the accent recipe.
class RaftSavedActionButton extends StatelessWidget {
  const RaftSavedActionButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Remove from saved',
  });
  final VoidCallback? onPressed;
  final String tooltip;
  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final dimension = tokens.brutal ? 28.0 : 32.0;
    return RaftControl(
      onPressed: onPressed,
      tooltip: raftText(context, tooltip),
      kind: RaftControlKind.savedAction,
      selected: true,
      visualHeight: dimension,
      visualWidth: dimension,
      variant: RaftControlVariant.outline,
      child: RaftIcon(RaftGlyph.bookmarkFilled, size: tokens.brutal ? 14 : 16),
    );
  }
}

class RaftTextButton extends StatelessWidget {
  const RaftTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.trailingGlyph,
    this.visualHeight = RaftMetrics.buttonMd,
    this.minimumTargetSize,
    this.variant = RaftControlVariant.outline,
    this.kind = RaftControlKind.button,
    this.selected = false,
    this.tooltip,
  });
  final String label;
  final VoidCallback? onPressed;
  final RaftGlyph? glyph;
  final RaftGlyph? trailingGlyph;
  final double visualHeight;
  final double? minimumTargetSize;
  final RaftControlVariant variant;
  final RaftControlKind kind;
  final bool selected;
  final String? tooltip;
  @override
  Widget build(BuildContext context) => RaftControl(
    kind: kind,
    selected: selected,
    tooltip: tooltip,
    onPressed: onPressed,
    variant: variant,
    visualHeight: visualHeight,
    minimumTargetSize: minimumTargetSize,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (glyph != null) ...[
          RaftIcon(glyph!, size: visualHeight <= 28 ? 14 : 16),
          // ds-allow: Web raft-ui/button.tsx md `gap-[5.5px]`
          const SizedBox(width: 5.5),
        ],
        Flexible(
          child: Text(
            raftText(context, label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingGlyph != null) ...[
          const SizedBox(width: 6),
          RaftIcon(trailingGlyph!, size: 12),
        ],
      ],
    ),
  );
}

/// Shared field frame: retains the editor's focus/selection/validation behavior.
class RaftFieldSurface extends StatefulWidget {
  const RaftFieldSurface({super.key, required this.child});
  final Widget child;
  @override
  State<RaftFieldSurface> createState() => _RaftFieldSurfaceState();
}

class _RaftFieldSurfaceState extends State<RaftFieldSurface> {
  bool focused = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // Elegant `focus-visible:ring-*`: the field keeps its border and a ring is
    // drawn OUTSIDE it (1px primary-400; dark: 2px primary-400 at 60%), not the
    // Material focused-border colour swap.
    final theme = Theme.of(context);
    final inputs = theme.inputDecorationTheme;
    return Focus(
      skipTraversal: true,
      onFocusChange: (value) => setState(() => focused = value),
      child: DecoratedBox(
        decoration: RaftCssBoxDecoration(
          borderRadius: RaftShapes.field(t),
          boxShadow: t.brutal
              ? focused
                    ? t.focusShadows
                    : t.shadows
              : focused
              ? [
                  BoxShadow(
                    color: t.dark
                        ? t.primaryFill.withValues(alpha: .6)
                        : t.primaryFill,
                    spreadRadius: t.dark ? 2 : 1,
                  ),
                ]
              : null,
        ),
        child: t.brutal
            ? widget.child
            : Theme(
                data: theme.copyWith(
                  inputDecorationTheme: inputs.copyWith(
                    focusedBorder: inputs.enabledBorder,
                  ),
                ),
                child: widget.child,
              ),
      ),
    );
  }
}

@immutable
class RaftMenuRecipe {
  const RaftMenuRecipe(
    this.tokens, {
    this.kind = RaftMenuKind.dropdown,
    this.viewportHeight = 800,
  });
  final RaftTokens tokens;
  final RaftMenuKind kind;
  final double viewportHeight;
  Color get background => tokens.popover;
  Color get foreground => tokens.brutal ? tokens.strong : tokens.muted;
  Color get highlightedBackground => tokens.brutal
      ? tokens.primaryFill.withValues(alpha: .3)
      : tokens.colors['ink-4']!;
  BorderRadius get radius => RaftShapes.field(tokens);
  BorderSide get border => tokens.brutal
      ? const BorderSide(color: Colors.black, width: 2)
      : BorderSide.none;
  EdgeInsets get inset => EdgeInsets.all(tokens.brutal ? 0 : 4);
  EdgeInsets get rowInset => const EdgeInsets.symmetric(horizontal: 12);
  double get rowVisualHeight => kind == RaftMenuKind.selectionPopover
      ? 36
      : tokens.brutal
      ? viewportHeight <= 600
            ? 28
            : 36
      : viewportHeight <= 600
      ? 27.5
      : 31.5;
  double get rowTargetHeight => RaftMetrics.touchTarget;
  double get popupGap => tokens.brutal ? 4 : 6;
  TextStyle get label => kind == RaftMenuKind.selectionPopover
      ? RaftTypography.body(tokens, size: 12, line: 16, weight: FontWeight.w700)
      : RaftTypography.body(
          tokens,
          size: tokens.brutal ? 14 : 13,
          line: tokens.brutal ? 20 : 19.5,
          weight: tokens.brutal ? FontWeight.w500 : FontWeight.w400,
          color: foreground,
        ).copyWith(letterSpacing: tokens.brutal ? 0 : -.065);
  TextStyle get meta =>
      RaftTypography.body(tokens, size: 12, line: 16, color: tokens.muted);
  List<BoxShadow> get shadows => tokens.brutal
      ? const [BoxShadow(color: Colors.black, offset: Offset(4, 4))]
      : tokens.dark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .15),
            offset: const Offset(0, 6),
            blurRadius: 6,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .25),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            offset: const Offset(0, 3),
            blurRadius: 12,
          ),
          BoxShadow(color: tokens.colors['line-muted']!, spreadRadius: 1),
        ];
}

/// Original raft-ui spinner ring recipe, using the enclosing control foreground.
class RaftSpinner extends StatefulWidget {
  const RaftSpinner({super.key, this.size, this.inverse = false});
  final double? size;
  final bool inverse;
  @override
  State<RaftSpinner> createState() => _RaftSpinnerState();
}

class _RaftSpinnerState extends State<RaftSpinner>
    with TickerProviderStateMixin {
  late final spin = AnimationController(vsync: this);
  late final dash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool reduced = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = RaftTokens.of(context);
    reduced = MediaQuery.disableAnimationsOf(context);
    spin.duration = Duration(milliseconds: t.brutal ? 1000 : 1600);
    if (reduced) {
      spin.stop();
      dash.stop();
    } else {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Loop driven by an AnimationController whose vsync is this State, so TickerMode (hidden routes, offstage tabs, folded panels) mutes it, it is disposed with the widget, and reduced motion stops it.
      spin.repeat();
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Loop driven by an AnimationController whose vsync is this State, so TickerMode (hidden routes, offstage tabs, folded panels) mutes it, it is disposed with the widget, and reduced motion stops it.
      if (!t.brutal) dash.repeat();
    }
  }

  @override
  void dispose() {
    spin.dispose();
    dash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final dimension = widget.size ?? (t.brutal ? 16 : 14);
    // [inverse]: on a dark surface (the video stage, a dark button) in every
    // theme; elegant used to ignore it and drew an ink spinner on black.
    final color = widget.inverse
        ? Colors.white
        : t.brutal
        ? Colors.black
        : IconTheme.of(context).color ?? t.ink;
    // The spinner repaints every frame while it is mounted. Its own repaint
    // boundary keeps that to the spinner's layer instead of re-recording the
    // button, page or list that happens to contain it.
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: dimension,
          child: AnimatedBuilder(
            animation: Listenable.merge([spin, dash]),
            builder: (_, _) => CustomPaint(
              painter: _SpinnerPainter(
                brutal: t.brutal,
                color: color,
                rotation: reduced ? 0 : spin.value,
                phase: reduced ? .5 : dash.value,
                reduced: reduced,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({
    required this.brutal,
    required this.color,
    required this.rotation,
    required this.phase,
    required this.reduced,
  });
  final bool brutal, reduced;
  final Color color;
  final double rotation, phase;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = brutal ? 2.0 : size.width * 2.5 / 24;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: brutal ? size.width / 2 - 1 : size.width * 10 / 24,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation * math.pi * 2);
    canvas.translate(-size.width / 2, -size.height / 2);
    paint.color = color.withValues(alpha: .2);
    canvas.drawOval(rect, paint);
    paint.color = color.withValues(alpha: brutal ? 1 : .8);
    paint.strokeCap = brutal ? StrokeCap.butt : StrokeCap.round;
    final eased = Curves.easeInOut.transform(phase);
    final length = reduced
        ? 72.0
        : phase < .5
        ? 1 + 89 * Curves.easeInOut.transform(phase * 2)
        : 90.0;
    final offset = reduced ? -30.0 : -124 * eased;
    canvas.drawArc(
      rect,
      -math.pi / 2 + offset / 150 * math.pi * 2,
      brutal ? math.pi / 2 : length / 150 * math.pi * 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.rotation != rotation ||
      old.phase != phase ||
      old.color != color ||
      old.brutal != brutal ||
      old.reduced != reduced;
}

@immutable
class RaftActionCardRecipe {
  const RaftActionCardRecipe(this.tokens);
  final RaftTokens tokens;
  Color get background => tokens.panel;
  BorderSide get border =>
      BorderSide(color: tokens.colors['line-muted']!, width: 2);
  EdgeInsets get inset => const EdgeInsets.all(12);
  double get topGap => 4;
  TextStyle get title =>
      RaftTypography.body(tokens, size: 14, line: 20, weight: FontWeight.w700);
  TextStyle get summary =>
      RaftTypography.body(tokens, size: 12, line: 16, color: tokens.muted);
  TextStyle get hint => summary.copyWith(fontStyle: FontStyle.italic);
  BorderSide get hintBorder =>
      BorderSide(color: tokens.colors['line-hairline']!, width: 2);
  double get hintInset => 8;
  TextStyle get done => RaftTypography.mono(
    tokens,
    size: 10,
    line: 12,
  ).copyWith(fontWeight: FontWeight.w500);
}

@immutable
class RaftMessageEmbedRecipe {
  const RaftMessageEmbedRecipe(this.tokens);
  final RaftTokens tokens;
  double get maxWidth => 544;
  BorderRadius get radius => BorderRadius.circular(8);
  BorderSide get border => BorderSide(
    color: tokens.brutal
        ? Colors.black.withValues(alpha: .2)
        : tokens.colors['line-muted']!,
    width: tokens.brutal ? 1 : .5,
  );
  EdgeInsets get inset => const EdgeInsets.all(2);
  EdgeInsets get itemInset =>
      EdgeInsets.symmetric(horizontal: 12, vertical: tokens.brutal ? 8 : 14);
  EdgeInsets get itemPadding => itemInset;
  EdgeInsets get headerPadding =>
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  EdgeInsets get footerPadding =>
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  BoxDecoration get decoration => BoxDecoration(
    color: tokens.panel,
    borderRadius: radius,
    border: Border.fromBorderSide(border),
  );
  TextStyle get author => metadata.copyWith(
    fontWeight: tokens.brutal ? FontWeight.w700 : FontWeight.w600,
    color: tokens.brutal ? Colors.black.withValues(alpha: .75) : tokens.strong,
  );
  TextStyle get count => header.copyWith(
    fontWeight: tokens.brutal ? FontWeight.w700 : FontWeight.w500,
    color: tokens.brutal
        ? Colors.black.withValues(alpha: .55)
        : tokens.colors['foreground-placeholder']!,
  );
  TextStyle get source => count.copyWith(
    color: tokens.brutal
        ? Colors.black.withValues(alpha: .5)
        : tokens.colors['foreground-placeholder']!,
  );
  TextStyle get footer => showMore;
  TextStyle get header =>
      RaftTypography.body(tokens, size: 11, line: 16, color: tokens.muted);
  TextStyle get metadata => header;
  TextStyle get showMore =>
      header.copyWith(fontWeight: RaftTypography.black(tokens));
  bool get showMoreUnderlined => true;
  double get collapsedHeight => 160;
  int get collapsedLines => 8;
}

@immutable
class RaftLightboxRecipe {
  const RaftLightboxRecipe(this.tokens);
  final RaftTokens tokens;
  Color get backdrop => tokens.colors['layer-backdrop']!;
  Color get surface => tokens.panel;
  EdgeInsets get headerInset =>
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  double get toolbarHeight => 56;
  double get closeInset => 16;
  double get actionsGap => 6;
  Size mediaBounds(Size viewport) =>
      Size(viewport.width * .86, viewport.height * .8);
  TextStyle get title => RaftTypography.body(tokens, size: 14, line: 24);
  BorderSide get navigationBorder =>
      BorderSide(color: tokens.colors['line-strong']!, width: 2);
}

enum RaftMenuKind { dropdown, selectionPopover }

/// Scoped open state; the product owner closes it when its authority changes.
class RaftMenuController extends ChangeNotifier {
  bool _open = false, _disposed = false;
  bool get isOpen => _open;
  void open() => _set(true);
  void close() => _set(false);
  void _set(bool value) {
    if (_disposed || _open == value) {
      return;
    }
    _open = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

@immutable
class RaftMenuEntry {
  const RaftMenuEntry({
    required this.label,
    this.glyph,
    this.leading,
    this.trailing,
    this.onPressed,
  });
  const RaftMenuEntry.separator()
    : label = null,
      glyph = null,
      leading = null,
      trailing = null,
      onPressed = null;
  final String? label;
  final RaftGlyph? glyph;
  final Widget? leading, trailing;
  final VoidCallback? onPressed;
}

/// Original dropdown composition with one owner for popup and keyboard focus.
enum RaftDropdownTriggerStyle { button, picker }

/// The 16px indicator slot of a PickerTriggerButton (`combobox-trigger-indicator`)
/// around its 12px chevron.
class RaftPickerIndicator extends StatelessWidget {
  const RaftPickerIndicator({super.key, this.glyph = RaftGlyph.chevronDown});
  final RaftGlyph glyph;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 16,
    child: Center(child: RaftIcon(glyph, size: 12)),
  );
}

enum RaftDropdownSide { bottom, top, right }

enum RaftDropdownAlign { start, end }

/// The popup retains ownership of its trigger focus and dismissal callbacks.
typedef RaftDropdownTriggerBuilder = Widget Function(
  BuildContext context,
  FocusNode focusNode,
  VoidCallback? onPressed,
);

class RaftDropdownMenu extends StatefulWidget {
  const RaftDropdownMenu({
    super.key,
    required this.label,
    required this.entries,
    this.controller,
    this.defaultOpen = false,
    this.width = 192,
    this.tooltip,
    this.glyph,
    this.trailingGlyph,
    this.enabled = true,
    this.triggerStyle = RaftDropdownTriggerStyle.button,
    this.selected = false,
    this.minimumTargetSize,
    this.side = RaftDropdownSide.bottom,
    this.align = RaftDropdownAlign.start,
    this.sideOffset,
    this.triggerBuilder,
    this.header,
    this.panelInset,
    this.openOnHover = false,
    this.closeDelay = const Duration(milliseconds: 120),
  });

  /// Passed to the trigger [RaftControl] (layout follows the Web box when
  /// set to the visual height).
  final double? minimumTargetSize;
  final RaftDropdownSide side;
  final RaftDropdownAlign align;
  final double? sideOffset;
  final RaftDropdownTriggerBuilder? triggerBuilder;
  final Widget? header;
  final EdgeInsetsGeometry? panelInset;
  final bool openOnHover;
  final Duration closeDelay;
  final String label;
  final List<RaftMenuEntry> entries;
  final RaftMenuController? controller;
  final bool defaultOpen;
  final double width;
  final String? tooltip;
  final RaftGlyph? glyph;
  final RaftGlyph? trailingGlyph;
  final bool enabled, selected;
  final RaftDropdownTriggerStyle triggerStyle;
  @override
  State<RaftDropdownMenu> createState() => _RaftDropdownMenuState();
}

class _RaftDropdownMenuState extends State<RaftDropdownMenu> {
  final portal = OverlayPortalController();
  final anchor = LayerLink();
  final anchorKey = GlobalKey();
  final trigger = FocusNode();
  final menuFocus = FocusNode(skipTraversal: true);
  final popup = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  final ownedController = RaftMenuController();
  final nodes = <FocusNode>[];
  int ticket = 0;
  Timer? hoverClose;
  bool focusPopup = true;
  bool presentationActive = true;
  bool get triggerEnabled => widget.enabled && presentationActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active =
        TickerMode.valuesOf(context).enabled && Visibility.of(context);
    if (active == presentationActive) return;
    presentationActive = active;
    ++ticket;
    if (!active) {
      hoverClose?.cancel();
      // Retained pages suspend their presentation before removing layout.
      // Never reopen or restore focus into a suspended trigger.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !presentationActive) close(restoreFocus: false);
      });
    }
  }

  RaftMenuController get controller => widget.controller ?? ownedController;
  @override
  void initState() {
    super.initState();
    _resizeNodes();
    controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.defaultOpen && triggerEnabled) {
        controller.open();
      }
      if (controller.isOpen) {
        _changed();
      }
    });
  }

  void _resizeNodes() {
    while (nodes.length < widget.entries.length) {
      nodes.add(FocusNode());
    }
  }

  @override
  void didUpdateWidget(RaftDropdownMenu old) {
    super.didUpdateWidget(old);
    ticket++;
    if (old.controller != widget.controller) {
      (old.controller ?? ownedController).removeListener(_changed);
      controller.addListener(_changed);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _changed();
        }
      });
    }
    _resizeNodes();
    if (!triggerEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !triggerEnabled) {
          close(restoreFocus: false);
        }
      });
    }
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    ticket++;
    if (!triggerEnabled && controller.isOpen) {
      controller.close();
      return;
    }
    setState(() {});
    if (controller.isOpen) {
      portal.show();
      final captured = ticket, requestFocus = focusPopup;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            triggerEnabled &&
            captured == ticket &&
            controller.isOpen &&
            requestFocus) {
          menuFocus.requestFocus();
        }
      });
    } else {
      portal.hide();
    }
  }

  void close({bool restoreFocus = true}) {
    hoverClose?.cancel();
    controller.close();
    if (restoreFocus &&
        triggerEnabled &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      trigger.requestFocus();
    }
  }

  void show({int? edge}) {
    if (!triggerEnabled) {
      return;
    }
    focusPopup =
        !widget.openOnHover ||
        _RaftFocusVisible.shared.keyboard ||
        edge != null;
    controller.open();
    if (edge != null) {
      final captured = ticket;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            triggerEnabled &&
            captured == ticket &&
            controller.isOpen) {
          _edge(edge);
        }
      });
    }
  }

  void hoverEnter() {
    hoverClose?.cancel();
    if (!widget.openOnHover || !triggerEnabled || controller.isOpen) return;
    // Source Help opens immediately on hover without moving keyboard focus.
    focusPopup = false;
    controller.open();
  }

  void hoverExit() {
    if (!widget.openOnHover) return;
    hoverClose?.cancel();
    hoverClose = Timer(widget.closeDelay, () => close(restoreFocus: false));
  }

  List<int> get enabled => [
    for (var i = 0; i < widget.entries.length; i++)
      if (widget.entries[i].label != null &&
          widget.entries[i].onPressed != null)
        i,
  ];
  void _edge(int delta) {
    if (!triggerEnabled) {
      return;
    }
    if (enabled.isEmpty) {
      menuFocus.requestFocus();
      return;
    }
    nodes[delta > 0 ? enabled.first : enabled.last].requestFocus();
  }

  void move(int delta) {
    if (!triggerEnabled) {
      return;
    }
    final choices = enabled;
    if (choices.isEmpty) {
      return;
    }
    final current = choices.indexWhere((i) => nodes[i].hasFocus);
    if (current < 0) {
      _edge(delta);
      return;
    }
    nodes[choices[(current + delta) % choices.length]].requestFocus();
  }

  void activateEntry(int index) {
    if (!mounted ||
        !triggerEnabled ||
        !controller.isOpen ||
        index >= widget.entries.length) {
      return;
    }
    final action = widget.entries[index].onPressed;
    if (action == null) {
      return;
    }
    close();
    action();
  }

  @override
  void dispose() {
    hoverClose?.cancel();
    ticket++;
    controller.removeListener(_changed);
    ownedController.dispose();
    for (final node in nodes) {
      node.dispose();
    }
    trigger.dispose();
    menuFocus.dispose();
    popup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftMenuRecipe(
      t,
      viewportHeight: MediaQuery.sizeOf(context).height,
    );
    void toggle() {
      if (!triggerEnabled) return;
      if (controller.isOpen) {
        close();
      } else {
        show();
      }
    }

    final end = widget.align == RaftDropdownAlign.end;
    final right = end == (Directionality.of(context) == TextDirection.ltr);
    final top = widget.side == RaftDropdownSide.top;
    final gap = widget.sideOffset ?? recipe.popupGap;
    final movement = Scrollable.maybeOf(context)?.position;
    return OverlayPortal(
      controller: portal,
      overlayChildBuilder: raftBackDismissed(
        () => close(),
        (context) => !triggerEnabled
            ? const SizedBox.shrink()
            : Stack(
                children: [
                  if (!widget.openOnHover)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => close(),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  Positioned.fill(
                    child: RaftAnchoredPopup(
                      anchorKey: anchorKey,
                      movement: movement,
                      above: top,
                      toRight: widget.side == RaftDropdownSide.right,
                      alignRight: right,
                      gap: gap,
                      child: RaftHoverRegion(
                        onEnter: (_) => hoverClose?.cancel(),
                        onExit: (_) => hoverExit(),
                        child: TapRegion(
                          groupId: this,
                          enabled: widget.openOnHover,
                          child: FocusScope(
                            node: popup,
                            child: CallbackShortcuts(
                              bindings: {
                                const SingleActivator(
                                  LogicalKeyboardKey.escape,
                                ): () =>
                                    close(),
                                const SingleActivator(
                                  LogicalKeyboardKey.arrowDown,
                                ): () =>
                                    move(1),
                                const SingleActivator(
                                  LogicalKeyboardKey.arrowUp,
                                ): () =>
                                    move(-1),
                                const SingleActivator(
                                  LogicalKeyboardKey.home,
                                ): () =>
                                    _edge(1),
                                const SingleActivator(
                                  LogicalKeyboardKey.end,
                                ): () =>
                                    _edge(-1),
                              },
                              child: Focus(
                                focusNode: menuFocus,
                                child: RaftMenuPanel(
                                  width: widget.width,
                                  padding: widget.panelInset,
                                  onDismiss: () => close(),
                                  children: [
                                    if (widget.header != null) widget.header!,
                                    for (
                                      var i = 0;
                                      i < widget.entries.length;
                                      i++
                                    )
                                      if (widget.entries[i].label == null)
                                        SizedBox(
                                          height: t.brutal ? 2 : 9,
                                          child: Center(
                                            child: Container(
                                              height: t.brutal ? 2 : .5,
                                              color: t.brutal
                                                  ? Colors.black
                                                  : t.colors['line-hairline'],
                                            ),
                                          ),
                                        )
                                      else
                                        RaftMenuItem(
                                          label: widget.entries[i].label!,
                                          glyph: widget.entries[i].glyph,
                                          leading: widget.entries[i].leading,
                                          trailing: widget.entries[i].trailing,
                                          focusNode: nodes[i],
                                          onMove: move,
                                          onPressed:
                                              widget.entries[i].onPressed ==
                                                  null
                                              ? null
                                              : () => activateEntry(i),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      child: RaftHoverRegion(
        onEnter: (_) => hoverEnter(),
        onExit: (_) => hoverExit(),
        child: TapRegion(
          groupId: this,
          enabled: widget.openOnHover,
          onTapOutside: (_) {
            if (controller.isOpen) close(restoreFocus: false);
          },
          child: CompositedTransformTarget(
            key: anchorKey,
            link: anchor,
            child: CallbackShortcuts(
              bindings: {
                if (triggerEnabled) ...{
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      show(edge: 1),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      show(edge: -1),
                  if (controller.isOpen)
                    const SingleActivator(LogicalKeyboardKey.escape): () =>
                        close(),
                },
              },
              child:
                  widget.triggerBuilder?.call(
                    context,
                    trigger,
                    triggerEnabled ? toggle : null,
                  ) ??
                  RaftControl(
                    focusNode: trigger,
                    tooltip: widget.tooltip,
                    minimumTargetSize: widget.minimumTargetSize,
                    variant: RaftControlVariant.outline,
                    visualHeight:
                        widget.triggerStyle == RaftDropdownTriggerStyle.picker
                        ? t.brutal
                              ? 32
                              : 28
                        : 32,
                    recipe:
                        widget.triggerStyle == RaftDropdownTriggerStyle.picker
                        ? RaftPickerTriggerRecipe(t, selected: widget.selected)
                        : null,
                    onPressed: !triggerEnabled
                        ? null
                        : () {
                            if (controller.isOpen) {
                              close();
                            } else {
                              show();
                            }
                          },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.glyph != null) ...[
                          // PickerTriggerButton scales its leading icon
                          // (`size-3` Elegant, 14px Brutal) and gaps 6px.
                          RaftIcon(
                            widget.glyph!,
                            size:
                                widget.triggerStyle ==
                                    RaftDropdownTriggerStyle.picker
                                ? (t.brutal ? 14 : 12)
                                : 14,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(widget.label),
                        if (widget.trailingGlyph != null) ...[
                          const SizedBox(width: 6),
                          if (widget.triggerStyle ==
                              RaftDropdownTriggerStyle.picker)
                            // The picker's indicator slot is 16px wide.
                            RaftPickerIndicator(glyph: widget.trailingGlyph!)
                          else
                            RaftIcon(widget.trailingGlyph!, size: 12),
                        ],
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Original menu surface. Product overlays own anchoring, authority and dismissal.
class RaftMenuPanel extends StatelessWidget {
  const RaftMenuPanel({
    super.key,
    required this.children,
    this.kind = RaftMenuKind.dropdown,
    this.onDismiss,
    this.width = 192,
    this.padding,
  });
  final List<Widget> children;
  final RaftMenuKind kind;
  final VoidCallback? onDismiss;
  final double width;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftMenuRecipe(
      RaftTokens.of(context),
      kind: kind,
      viewportHeight: MediaQuery.sizeOf(context).height,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            onDismiss?.call(),
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Semantics(
          role: SemanticsRole.menu,
          // Menus open in the root Overlay, outside any Material: keep the
          // debug "no Material" underline style off the items.
          child: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Container(
              width: width,
              padding: padding ?? recipe.inset,
              decoration: BoxDecoration(
                color: recipe.background,
                borderRadius: recipe.radius,
                border: Border.fromBorderSide(recipe.border),
                boxShadow: recipe.shadows,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RaftMenuItem extends StatefulWidget {
  const RaftMenuItem({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.leading,
    this.trailing,
    this.selected = false,
    this.kind = RaftMenuKind.dropdown,
    this.autofocus = false,
    this.focusNode,
    this.onMove,
    this.italic = false,
    this.divider = false,
  });

  /// SelectionPopover sentinel rows ("Assigned to me", "Unassigned"):
  /// `italic text-foreground-muted` (brutal black/70).
  final bool italic;

  /// SelectionPopover rows end in `border-b` (brutal black/10) except the last.
  final bool divider;
  final String label;
  final VoidCallback? onPressed;
  final RaftGlyph? glyph;

  /// Caller-owned content (e.g. an authored 14px glyph or loading spinner).
  final Widget? leading, trailing;
  final FocusNode? focusNode;
  final ValueChanged<int>? onMove;
  final bool selected, autofocus;
  final RaftMenuKind kind;
  @override
  State<RaftMenuItem> createState() => _RaftMenuItemState();
}

class _RaftMenuItemState extends State<RaftMenuItem> {
  final ownedFocus = FocusNode();
  FocusNode get focus => widget.focusNode ?? ownedFocus;
  bool hovered = false, focused = false, semanticFocused = false;
  @override
  void dispose() {
    ownedFocus.dispose();
    super.dispose();
  }

  void activateItem() {
    if (widget.onPressed == null) return;
    focus.requestFocus();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftMenuRecipe(
      t,
      kind: widget.kind,
      viewportHeight: MediaQuery.sizeOf(context).height,
    );
    final enabled = widget.onPressed != null;
    // Match DropdownMenuItem's CSS row while retaining the same 48px native
    // hit/semantics expansion as the shared recipe controls.
    final height = recipe.rowVisualHeight;
    final grows = RaftScaled.grows(context);
    Widget result = Semantics(
      role: widget.kind == RaftMenuKind.selectionPopover
          ? SemanticsRole.menuItemCheckbox
          : SemanticsRole.menuItem,
      checked: widget.kind == RaftMenuKind.selectionPopover
          ? widget.selected
          : null,
      label: widget.label,
      enabled: enabled,
      focusable: enabled,
      focused: semanticFocused,
      onTap: enabled ? activateItem : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        focusNode: focus,
        autofocus: widget.autofocus,
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) => setState(() => focused = value),
        onFocusChange: (value) => setState(() => semanticFocused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
        },
        actions: {
          NextFocusIntent: CallbackAction<NextFocusIntent>(
            onInvoke: (_) {
              if (widget.onMove != null) {
                widget.onMove!(1);
              } else {
                Focus.of(context).nextFocus();
              }
              return null;
            },
          ),
          PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
            onInvoke: (_) {
              if (widget.onMove != null) {
                widget.onMove!(-1);
              } else {
                Focus.of(context).previousFocus();
              }
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              activateItem();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              activateItem();
              return null;
            },
          ),
        },
        child: RaftHoverRegion(
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: enabled ? activateItem : null,
            child: Container(
              height: grows ? null : height,
              constraints: grows ? BoxConstraints(minHeight: height) : null,
              padding: recipe.rowInset,
              decoration: BoxDecoration(
                color: enabled && (hovered || focused)
                    ? recipe.highlightedBackground
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(t.brutal ? 0 : 2),
                border: widget.divider
                    ? Border(
                        bottom: BorderSide(
                          color: t.brutal
                              ? Colors.black.withValues(alpha: .1)
                              : t.colors['line-muted']!,
                        ),
                      )
                    : null,
              ),
              child: Opacity(
                opacity: enabled ? 1 : .3,
                child: Row(
                  children: [
                    if (widget.leading != null || widget.glyph != null) ...[
                      if (widget.leading != null)
                        DefaultTextStyle.merge(
                          style: TextStyle(
                            color: enabled && (hovered || focused)
                                ? t.ink
                                : recipe.foreground,
                          ),
                          child: widget.leading!,
                        )
                      else
                        RaftIcon(
                          widget.glyph!,
                          size: t.brutal ? 14 : 16,
                          strokeWidth: t.brutal ? 2 : 1.5,
                          color: enabled && (hovered || focused)
                              ? t.ink
                              : recipe.foreground,
                        ),
                      SizedBox(
                        width:
                            t.brutal ||
                                widget.kind == RaftMenuKind.selectionPopover
                            ? 8
                            : 10,
                      ),
                    ],
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: grows ? null : 1,
                        overflow: TextOverflow.ellipsis,
                        style: RaftControlTypography.of(
                          context,
                          recipe.label.copyWith(
                            fontWeight:
                                widget.selected ||
                                    widget.kind == RaftMenuKind.selectionPopover
                                ? FontWeight.w700
                                : recipe.label.fontWeight,
                            fontStyle: widget.italic ? FontStyle.italic : null,
                            color: widget.italic
                                ? (t.brutal
                                      ? Colors.black.withValues(alpha: .7)
                                      : t.muted)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (widget.trailing != null) widget.trailing!,
                    if (widget.kind == RaftMenuKind.selectionPopover &&
                        widget.selected)
                      RaftIcon(RaftGlyph.check, size: 12, color: t.strong),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (RaftDensityScope.of(context) == RaftDensity.touch) {
      result = RaftTouchTarget(child: result);
    }
    return result;
  }
}

class RaftTextLink extends StatelessWidget {
  const RaftTextLink({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.textStyle,
  });
  final String label;
  final VoidCallback? onPressed;
  final RaftGlyph? glyph;
  final TextStyle? textStyle;
  @override
  Widget build(BuildContext context) => RaftControl(
    kind: RaftControlKind.textLink,
    visualHeight: 16,
    shadow: true,
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (glyph != null) ...[
          RaftIcon(glyph!, size: 12),
          const SizedBox(width: 4),
        ],
        RaftUnderlinedText(
          label,
          style:
              textStyle ??
              TextStyle(
                fontFamily: RaftTokens.of(context).bodyFont,
                fontSize: 11,
                height: 16 / 11,
                fontWeight: RaftTypography.black(RaftTokens.of(context)),
              ),
        ),
      ],
    ),
  );
}

class _InsetHighlightPainter extends CustomPainter {
  const _InsetHighlightPainter(this.radius, this.color);
  final BorderRadius radius;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final shape = radius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipRRect(shape);
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, .5));
    canvas.drawRRect(
      shape.deflate(.25),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsetHighlightPainter old) =>
      old.radius != radius || old.color != color;
}

class _ControlFocusOutlinePainter extends CustomPainter {
  const _ControlFocusOutlinePainter({
    required this.color,
    required this.width,
    required this.offset,
    required this.radius,
  });
  final Color color;
  final double width, offset;
  final BorderRadius radius;
  @override
  void paint(Canvas canvas, Size size) {
    final expansion = offset + width / 2;
    final rect = (Offset.zero & size).inflate(expansion);
    final rounded = BorderRadius.only(
      topLeft: Radius.circular(radius.topLeft.x + expansion),
      topRight: Radius.circular(radius.topRight.x + expansion),
      bottomLeft: Radius.circular(radius.bottomLeft.x + expansion),
      bottomRight: Radius.circular(radius.bottomRight.x + expansion),
    );
    canvas.drawRRect(
      rounded.toRRect(rect),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_ControlFocusOutlinePainter old) =>
      old.color != color ||
      old.width != width ||
      old.offset != offset ||
      old.radius != radius;
}

class _TextLinkFocusPainter extends CustomPainter {
  const _TextLinkFocusPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    (Offset.zero & size).inflate(3),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  @override
  bool shouldRepaint(_TextLinkFocusPainter old) => old.color != color;
}

@immutable
class RaftTaskSectionRecipe {
  const RaftTaskSectionRecipe(this.tokens);
  final RaftTokens tokens;
  EdgeInsets get inset => EdgeInsets.all(tokens.brutal ? 0 : 12);

  /// TasksPanel.tsx1178 applies p-4 over the raft-ui dark viewport p-7.
  EdgeInsets get viewportInset => const EdgeInsets.all(16);

  /// MainLayout.tsx2255 AppShellRoot font-display, inherited by task cards.
  TextStyle get documentStyle => TextStyle(
    locale: tokens.textLocale,
    fontFamily: tokens.headingFont,
    fontFamilyFallback: tokens.systemFonts ? tokens.fontFallback : null,
    fontSize: 16,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    color: tokens.ink,
  );
  double get itemGap => 10;
  double get sectionGap => 24;
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 10);
  Color get background => tokens.colors['task-section-fill']!;
  BoxDecoration get decoration =>
      BoxDecoration(color: background, borderRadius: radius);
  TextStyle get heading => RaftTypography.body(
    tokens,
    size: 12,
    line: 16,
    weight: tokens.brutal ? FontWeight.w700 : FontWeight.w500,
  );
  TextStyle get count => RaftTypography.mono(tokens, size: 12, line: 16);
  Color get chevron => tokens.brutal
      ? tokens.strong.withValues(alpha: .5)
      : tokens.colors['foreground-icon']!;
}

@immutable
class RaftSegmentedOption<T> {
  const RaftSegmentedOption({
    required this.value,
    required this.label,
    this.glyph,
    this.tooltip,
    this.count,
    this.enabled = true,
    this.labelSuffix,
    this.itemKey,
  });
  final T value;
  final String label;

  /// Key of the segment (tests, parity interactions).
  final Key? itemKey;

  /// A `font-mono text-[10px] font-bold uppercase text-black/60` note inside
  /// the label (`gap-1.5`), e.g. BillingIntervalSegmentedControl's "Save 12%".
  final String? labelSuffix;
  final RaftGlyph? glyph;
  final String? tooltip;

  /// `SegmentedControlCount` (buttons style).
  final String? count;
  final bool enabled;
}

/// One source radio group: arrow keys select and move focus within the group.
class RaftSegmentedControl<T> extends StatefulWidget {
  const RaftSegmentedControl({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.visualHeight = 32,
    this.style = RaftSegmentedStyle.buttons,
    this.minimumTargetSize,
  });
  final RaftSegmentedStyle style;
  final T value;
  final List<RaftSegmentedOption<T>> items;
  final ValueChanged<T>? onChanged;
  final String? label;
  final double visualHeight;

  /// Passed to each segment's [RaftControl] (layout follows the Web box when
  /// set to [visualHeight]).
  final double? minimumTargetSize;
  @override
  State<RaftSegmentedControl<T>> createState() =>
      _RaftSegmentedControlState<T>();
}

class _RaftSegmentedControlState<T> extends State<RaftSegmentedControl<T>> {
  final scope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  @override
  void dispose() {
    scope.dispose();
    super.dispose();
  }

  void move(int delta) {
    if (widget.onChanged == null || widget.items.isEmpty) return;
    final current = widget.items.indexWhere((e) => e.value == widget.value);
    final next =
        ((current < 0
                ? delta > 0
                      ? -1
                      : 0
                : current) +
            delta) %
        widget.items.length;
    widget.onChanged!(widget.items[next].value);
    if (delta > 0) {
      scope.nextFocus();
    } else {
      scope.previousFocus();
    }
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    node: scope,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => move(1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => move(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => move(-1),
      },
      child: Semantics(
        label: widget.label,
        container: true,
        child: Wrap(
          spacing: widget.style == RaftSegmentedStyle.buttons
              ? _segmentedRoot(context).columnGap ?? 0
              : 4,
          runSpacing: widget.style == RaftSegmentedStyle.buttons
              ? _segmentedRoot(context).rowGap ?? 0
              : 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < widget.items.length; i++) ...[
              if (widget.style == RaftSegmentedStyle.buttons)
                _SegmentedItem<T>(
                  key: widget.items[i].itemKey,
                  option: widget.items[i],
                  checked: widget.items[i].value == widget.value,
                  onPressed:
                      widget.onChanged == null || !widget.items[i].enabled
                      ? null
                      : () => widget.onChanged!(widget.items[i].value),
                )
              else if (widget.style == RaftSegmentedStyle.taskViews)
                RaftTouchTargetExpander(
                  minSize: const Size.square(RaftMetrics.touchTarget),
                  child: RaftTaskFilterButton(
                    selected: widget.items[i].value == widget.value,
                    onPressed:
                        widget.onChanged == null || !widget.items[i].enabled
                        ? null
                        : () => widget.onChanged!(widget.items[i].value),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        if (widget.items[i].glyph != null)
                          RaftIcon(widget.items[i].glyph!, size: 14),
                        Text(widget.items[i].label),
                      ],
                    ),
                  ),
                )
              else
                RaftControl(
                  kind: RaftControlKind.tab,
                  variant: widget.items[i].value == widget.value
                      ? RaftControlVariant.primary
                      : RaftControlVariant.outline,
                  selected: widget.items[i].value == widget.value,
                  tooltip: widget.items[i].tooltip,
                  visualHeight: widget.visualHeight,
                  minimumTargetSize: widget.minimumTargetSize,
                  onPressed: widget.onChanged == null
                      ? null
                      : () => widget.onChanged!(widget.items[i].value),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.items[i].glyph != null) ...[
                        RaftIcon(widget.items[i].glyph!, size: 13),
                        const SizedBox(width: 4),
                      ],
                      Text(widget.items[i].label),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Original PickerTriggerButton, not the generic Button outline variant.
/// Source: raft-ui0.5.27 index.mjs7146; Search activeFilterClass2173.
class RaftPickerTriggerRecipe extends RaftControlRecipe {
  const RaftPickerTriggerRecipe(
    super.tokens, {
    super.selected,
    this.popupOpen = false,
  }) : super(variant: RaftControlVariant.outline);
  final bool popupOpen;
  @override
  bool get transformsOnInteraction => false;
  @override
  Color get background => selected
      ? tokens.brutal
            ? tokens.primaryFill
            : tokens.colors['primary-soft']!
      : tokens.dark
      ? tokens.colors['fill-muted']!
      : tokens.panel;
  @override
  Color backgroundFor({bool hovered = false}) =>
      selected || !hovered || tokens.brutal
      ? background
      : tokens.colors[tokens.dark ? 'fill-strong' : 'ink-2']!;
  @override
  Color get foreground => selected
      ? tokens.strong
      : tokens.brutal
      ? RaftPrimitiveColors.black.withValues(alpha: .7)
      : tokens.colors['foreground-placeholder']!;
  @override
  Color get focusRing => tokens.colors['primary-400']!;
  @override
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 6);
  @override
  BorderSide side({bool hovered = false}) => tokens.brutal
      ? BorderSide(
          color: selected || hovered || popupOpen
              ? RaftPrimitiveColors.black
              : RaftPrimitiveColors.black.withValues(alpha: .3),
          width: 2,
        )
      : BorderSide.none;
  @override
  EdgeInsets get padding =>
      EdgeInsets.symmetric(horizontal: tokens.brutal ? 12 : 10);
  @override
  TextStyle get textStyle => RaftTypography.body(
    tokens,
    size: 12,
    line: 16,
    weight: tokens.brutal ? FontWeight.w700 : FontWeight.w500,
    color: foreground,
  ).copyWith(letterSpacing: tokens.brutal ? 0 : -.06);
  @override
  double get insetHighlightAlpha => tokens.brutal
      ? 0
      : tokens.dark
      ? .045
      : .05;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => [
    if (tokens.brutal && selected)
      const BoxShadow(color: Colors.black, offset: Offset(2, 2)),
    if (!tokens.brutal && selected) ...tokens.shadows,
    if (!tokens.brutal && !selected && !tokens.dark)
      BoxShadow(color: tokens.colors['line-muted']!, spreadRadius: 1),
    if (!tokens.brutal && !selected && tokens.dark) ...[
      BoxShadow(color: Colors.black.withValues(alpha: .4), spreadRadius: 1),
      BoxShadow(
        color: Colors.black.withValues(alpha: .22),
        offset: const Offset(0, 1),
        blurRadius: 3,
      ),
    ],
    if (focused && !tokens.brutal) BoxShadow(color: focusRing, spreadRadius: 2),
  ];
}

/// The same original PickerTriggerButton recipe for product-owned comboboxes.
class RaftPickerTriggerButton extends StatelessWidget {
  const RaftPickerTriggerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.trailingGlyph = RaftGlyph.chevronDown,
    this.selected = false,
    this.enabled = true,
    this.tooltip,
    this.focusNode,
  });
  final String label;
  final VoidCallback? onPressed;
  final RaftGlyph? glyph, trailingGlyph;
  final bool selected, enabled;
  final String? tooltip;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftControl(
      onPressed: enabled ? onPressed : null,
      focusNode: focusNode,
      tooltip: tooltip,
      visualHeight: t.brutal ? 32 : 28,
      variant: RaftControlVariant.outline,
      recipe: RaftPickerTriggerRecipe(t, selected: selected),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            RaftIcon(glyph!, size: 14),
            const SizedBox(width: 8),
          ],
          Text(raftText(context, label)),
          if (trailingGlyph != null) ...[
            const SizedBox(width: 8),
            RaftIcon(trailingGlyph!, size: 12),
          ],
        ],
      ),
    );
  }
}

/// Interaction state fed to recipe-painted controls (CSS :hover, :active,
/// :focus-visible, :disabled).
@immutable
class RaftInteractionState {
  const RaftInteractionState({
    this.hovered = false,
    this.pressed = false,
    this.focusVisible = false,
    this.enabled = true,
  });
  final bool hovered, pressed, focusVisible, enabled;
}

/// Pointer, keyboard and semantics plumbing for controls whose visuals are
/// painted from a generated recipe. Layout is exactly the child's (no touch
/// target inflation: the Web control box is the layout box).
class RaftInteractive extends StatefulWidget {
  const RaftInteractive({
    super.key,
    required this.builder,
    this.onPressed,
    this.onKeyboardActivate,
    this.busy = false,
    this.focusNode,
    this.focusOnPointer = true,
    this.semanticLabel,
    this.semanticRole,
    this.button = true,
    this.selected,
    this.checked,
    this.tooltip,
  });

  final Widget Function(BuildContext context, RaftInteractionState state)
  builder;
  final VoidCallback? onPressed;

  /// Optional keyboard/semantics activation. Pointer activation continues
  /// to call [onPressed]; without this callback all inputs call [onPressed].
  final VoidCallback? onKeyboardActivate;
  final bool busy, focusOnPointer, button;
  final bool? selected, checked;
  final FocusNode? focusNode;
  final String? semanticLabel, tooltip;
  final SemanticsRole? semanticRole;

  @override
  State<RaftInteractive> createState() => _RaftInteractiveState();
}

class _RaftInteractiveState extends State<RaftInteractive> {
  bool hovered = false, focused = false, pressed = false;
  bool tooltipKeyboardFocused = false;
  final ownedFocus = FocusNode();
  FocusNode get node => widget.focusNode ?? ownedFocus;
  bool get enabled => widget.onPressed != null && !widget.busy;

  @override
  void initState() {
    super.initState();
    _RaftFocusVisible.shared.acquire();
    _RaftFocusVisible.shared.addListener(modeChanged);
  }

  @override
  void dispose() {
    _RaftFocusVisible.shared.removeListener(modeChanged);
    _RaftFocusVisible.shared.release();
    ownedFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RaftInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!enabled) {
      pressed = hovered = focused = tooltipKeyboardFocused = false;
    }
  }

  void modeChanged() {
    final next = enabled && node.hasFocus && _RaftFocusVisible.shared.keyboard;
    if (mounted && next != focused) {
      setState(() {
        focused = next;
        tooltipKeyboardFocused = tooltipKeyboardFocused && next;
      });
    }
  }

  void focusChanged(bool hasFocus) {
    if (!mounted) return;
    setState(() {
      focused = enabled && hasFocus && _RaftFocusVisible.shared.keyboard;
      tooltipKeyboardFocused = focused;
    });
  }

  void activateControl() {
    if (!enabled) return;
    node.requestFocus();
    (widget.onKeyboardActivate ?? widget.onPressed)?.call();
  }

  @override
  Widget build(BuildContext context) {
    final touch = RaftDensityScope.of(context) == RaftDensity.touch;
    final state = RaftInteractionState(
      hovered: hovered,
      pressed: pressed,
      focusVisible: focused,
      enabled: enabled,
    );
    Widget result = Semantics(
      // TouchTarget supplies this boundary and its larger semantics rect on
      // touch devices, including controls whose inner density is desktop to
      // preserve visual geometry. Other desktop controls own their boundary.
      container:
          !touch &&
          context.findAncestorWidgetOfExactType<RaftTouchTarget>() == null,
      label: widget.semanticLabel,
      excludeSemantics: widget.busy,
      button: widget.button,
      role: widget.semanticRole,
      selected: widget.selected,
      checked: widget.checked,
      enabled: enabled,
      onTap: enabled ? activateControl : null,
      child: RaftHoverRegion(
        onEnter: enabled ? (_) => setState(() => hovered = true) : null,
        onExit: (_) => setState(() => hovered = false),
        child: FocusableActionDetector(
          focusNode: node,
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (_) => modeChanged(),
          onFocusChange: focusChanged,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                activateControl();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) {
                activateControl();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: enabled
                ? (_) {
                    if (widget.focusOnPointer) node.requestFocus();
                    setState(() => pressed = true);
                  }
                : null,
            onTapUp: enabled
                ? (_) {
                    setState(() => pressed = false);
                    widget.onPressed?.call();
                  }
                : null,
            onTapCancel: enabled ? () => setState(() => pressed = false) : null,
            child: widget.builder(context, state),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      result = RaftTooltip(
        message: widget.tooltip!,
        keyboardFocused: tooltipKeyboardFocused,
        child: result,
      );
    }
    // The expander must surround the tooltip's render boxes too; otherwise
    // those 32px boxes reject pointers before the expanded target sees them.
    if (touch) {
      result = RaftTouchTarget(child: result);
    }
    return result;
  }
}

/// Touch accessibility without changing the Web layout: hit testing and the
/// semantics rect extend to at least [minSize] around the visual box (where
/// the parent routes the pointer), while layout and paint stay exactly the
/// control's own box. Platform exception: the Web has no touch-target
/// inflation; Android's 48dp guideline is met this way.
class RaftTouchTarget extends SingleChildRenderObjectWidget {
  const RaftTouchTarget({
    super.key,
    super.child,
    this.minSize = const Size.square(RaftMetrics.touchTarget),
  });
  final Size minSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTouchTarget(minSize);
  @override
  void updateRenderObject(BuildContext context, _RenderTouchTarget r) =>
      r.minSize = minSize;
}

class _RenderTouchTarget extends RenderProxyBox {
  _RenderTouchTarget(this._minSize);
  Size _minSize;
  set minSize(Size v) {
    if (v == _minSize) return;
    _minSize = v;
    markNeedsSemanticsUpdate();
  }

  Rect get _target => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: math.max(size.width, _minSize.width),
    height: math.max(size.height, _minSize.height),
  );

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_target.contains(position)) return false;
    // Nearest point inside the box (Size.contains excludes the far edge).
    final inside = Offset(
      position.dx.clamp(0, math.max(0, size.width - 1e-3)),
      position.dy.clamp(0, math.max(0, size.height - 1e-3)),
    );
    if (hitTestChildren(result, position: inside)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  Rect get semanticBounds => _target;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
  }
}

RaftSlotStyle _segmentedRoot(BuildContext context) {
  final t = RaftTokens.of(context);
  return RaftSegmentedControlRecipe.resolve(
    theme: t.recipeTheme,
    states: t.recipeStates(),
    tokens: t.recipeTokens,
  ).root;
}

/// raft-ui `SegmentedControlItem` (+ `SegmentedControlLabel` /
/// `SegmentedControlCount`) on the `segmentedControl` recipe.
class _SegmentedItem<T> extends StatelessWidget {
  const _SegmentedItem({
    super.key,
    required this.option,
    required this.checked,
    required this.onPressed,
  });
  final RaftSegmentedOption<T> option;
  final bool checked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    return RaftInteractive(
      onPressed: onPressed,
      button: false,
      checked: checked,
      tooltip: option.tooltip,
      builder: (context, st) {
        final s = RaftSegmentedControlRecipe.resolve(
          theme: t.recipeTheme,
          disabled: !option.enabled,
          states: t.recipeStates(
            hovered: st.hovered,
            pressed: st.pressed,
            focusVisible: st.focusVisible,
            disabled: !option.enabled,
            extra: [
              checked ? 'data-checked' : 'data-unchecked',
              if (checked) 'group/segmented-control-item:data-checked',
              if (!option.enabled) 'data-disabled',
              if (option.count != null) 'has:data-slot=segmented-control-count',
              if (option.glyph != null) 'has:svg',
            ],
          ),
          tokens: rt,
        );
        final svg = s.item.target("& svg:not([class*='size-'])");
        final gap = s.item.columnGap ?? 0;
        return RaftRecipeBox(
          style: s.item,
          tokens: rt,
          controlLabel: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (option.glyph != null) ...[
                Builder(
                  builder: (context) => RaftIcon(
                    option.glyph!,
                    size: svg?.width ?? 14,
                    strokeWidth: 2.5,
                    color: DefaultTextStyle.of(context).style.color,
                  ),
                ),
                SizedBox(width: gap),
              ],
              Flexible(
                child: Builder(
                  builder: (context) {
                    final inherited = RaftInheritedFontScope.active(context);
                    // The label restates its own style, so the box's control
                    // profile reaches it only through this resolve.
                    final label = RaftControlTypography.of(
                      context,
                      s.label
                          .text(rt, base: DefaultTextStyle.of(context).style)
                          .copyWith(
                            fontFamily: inherited ? t.headingFont : null,
                          ),
                    );
                    final text = Text(
                      option.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: label,
                    );
                    if (option.labelSuffix == null) return text;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: text),
                        const SizedBox(width: 6),
                        Text(
                          option.labelSuffix!.toUpperCase(),
                          maxLines: 1,
                          softWrap: false,
                          style: label.copyWith(
                            fontFamily: t.monoFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withValues(alpha: .6),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (option.count != null) ...[
                SizedBox(width: gap),
                Builder(
                  builder: (context) => Text(
                    option.count!,
                    style: RaftControlTypography.of(
                      context,
                      s.count.text(
                        rt,
                        base: DefaultTextStyle.of(context).style,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
