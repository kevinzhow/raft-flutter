import 'hover_region.dart';
import 'focus_visible.dart';
import 'interaction.dart';
import 'raft_underline.dart';
import 'anchored_popup.dart';
import 'dismiss_scope.dart';
import 'tooltip.dart';
import 'tap_slop.dart';
import 'small_icon_recipe.dart';
import 'menu_action_row.dart';
import 'menu_focus_reveal.dart';
import 'popover_surface.dart';
import 'text_scaling.dart' show RaftChrome, RaftScaled;
import 'large_content_viewer.dart';

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
import 'raft/css_box.dart';
import 'raft/ui_tokens.dart';
import 'raft/button.dart';
import 'recipes/recipe_runtime.dart';
import 'raft/pixel_spinner.dart';
import 'recipes/spinner.g.dart' show RaftSpinnerRecipeSize;
import 'recipes/popover.g.dart';
import 'recipes/dropdown_menu.g.dart';
import 'recipes/web_selection_panel.g.dart';
import 'recipes/web_selection_row.g.dart';

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

/// Shared recipe geometry from raft-ui 0.5.52 and pinned Web product overrides.
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
      : t.size('size.panelHeader', fallback: RaftMetrics.panelHeader);

  /// `size.rail`, or `size.railShort` on short viewports (a57b9dab: Brutal
  /// 64/50, others 56). The 600px threshold is form, not a theme value.
  static double railWidth(RaftTokens t, double viewportHeight) {
    final rail = t.size('size.rail', fallback: 56);
    if (viewportHeight <= 600) {
      return t.size('size.railShort', fallback: rail);
    }
    return rail;
  }

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
  bool get headerOverlaysContent => !product;
  // Mobile-inline Sidebar uses its own surface option; the desktop sidebar
  // keeps its dedicated role. Other legacy muted surfaces stay unchanged.
  Color get bodyBackground =>
      !desktop &&
          tokens.option('sidebar.mobileSurface', or: 'sidebar') == 'canvas'
      ? tokens.canvas
      : tokens.colors['layer-sidebar'] ?? tokens.sidebar;
  double get headerHeight => product && desktop && workspaceEnabled
      ? RaftMetrics.compactPanelHeader
      : RaftLayoutMetrics.shellHeaderHeight(tokens, viewportHeight);
  EdgeInsetsDirectional get headerInset => product
      ? EdgeInsetsDirectional.symmetric(
          horizontal: desktop && !workspaceEnabled ? 20 : 16,
        )
      : EdgeInsetsDirectional.only(
          start: desktop ? 26 : 28,
          end: desktop ? 18 : 28,
        );
  EdgeInsetsDirectional contentInset({
    bool headerInFlow = false,
    double bottomInset = 0,

    /// False when the phone's navigation is the side rail: nothing floats at
    /// the bottom, so the list reserves no capsule clearance.
    bool bottomBar = true,
  }) => EdgeInsetsDirectional.only(
    start: product
        ? 8
        : desktop
        ? 26
        : 28,
    end: product
        ? 8
        : desktop
        ? 18
        : 28,
    top: product
        ? tokens.size(
            headerInFlow
                ? 'space.sidebarContentTop'
                : 'space.sidebarContentTopWithoutHeader',
            fallback: tokens.size('space.sidebarContentTop', fallback: 12),
          )
        : headerInFlow
        ? 0
        : headerHeight,
    bottom: product
        ? !desktop
              ? tokens.size('space.sidebarContentBottom', fallback: 12) +
                    (bottomBar
                        ? tokens.size(
                            'space.sidebarBottomClearance',
                            fallback: 56,
                          )
                        : 0) +
                    bottomInset
              : tokens.size('space.sidebarContentBottom', fallback: 12)
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
  Color get background => variant == RaftPanelHeaderVariant.tasks
      ? tokens.panel
      : tokens.colors['layer-canvas-muted']!;
  Color get iconBackground => tokens.colors['primary-soft']!;
  Color get foreground => tokens.strong;
  BorderSide get border => variant == RaftPanelHeaderVariant.canonical
      ? BorderSide.none
      // Brutal PanelHeader `border-b-2 border-black`: pure black, not ink.
      : BorderSide(color: tokens.line, width: tokens.border);
  BorderRadius get iconRadius => BorderRadius.circular(6);
  EdgeInsets get inset =>
      const EdgeInsets.symmetric(horizontal: RaftLayoutMetrics.panelInset);
  TextStyle get title => variant == RaftPanelHeaderVariant.tasks
      ? RaftTypography.heading(tokens, size: 16, line: 20)
      : RaftTypography.heading(
          tokens,
          size: 17,
          line: 21.25,
          weight: FontWeight.w500,
        );
  TextStyle get subtitle => RaftTypography.mono(tokens);
}

@immutable
class RaftRailRecipe {
  const RaftRailRecipe(this.tokens, {required this.viewportHeight});
  final RaftTokens tokens;
  final double viewportHeight;
  double get width => RaftLayoutMetrics.railWidth(tokens, viewportHeight);
  double get glyphSize => tokens.size('size.railGlyph', fallback: 16);
  double get itemSize => tokens.size(
    viewportHeight <= 600 ? 'size.railItemCompact' : 'size.railItem',
    fallback: RaftMetrics.railItem,
  );
  // AppRailRoot's bg-primary resolves the primary-400 ramp; primaryFill is
  // the separate product Button alias and differs by one blue channel.
  Color get background =>
      tokens.colors['layer-workspace-rail'] ?? tokens.sidebar;
  Color get selectedBackground =>
      tokens.colors['layer-workspace-rail-selected'] ?? tokens.card;
  Color get identityBackground => tokens.panel;
  Color get foreground =>
      tokens.colors['foreground-workspace-rail'] ?? tokens.muted;
  Color get selectedForeground =>
      tokens.colors['foreground-workspace-rail-selected'] ?? foreground;
  BorderRadius get radius =>
      BorderRadius.circular(tokens.size('radius.railItem', fallback: 6));
  BorderRadius get avatarRadius => BorderRadius.circular(8);
  // AppRailRoot `theme-brutal:border-r-2 border-black`: pure black, not the ink line token.
  BorderSide get border => BorderSide(
    color: tokens.colors['line-workspace-rail'] ?? tokens.line,
    width: tokens.size('stroke.rail', fallback: 0),
  );

  List<BoxShadow> selectedShadows({bool action = false}) =>
      _shadows(action ? 'shadow.railActionSelected' : 'shadow.railSelected');
  List<BoxShadow> get focusShadows => _shadows('shadow.railFocus');
  List<BoxShadow> _shadows(String role) => [
    for (final layer in tokens.shadowLayers(role).reversed)
      if (!layer.inset)
        BoxShadow(
          color: layer.color,
          offset: layer.offset,
          blurRadius: raftCssBlurRadius(layer.blur),
          spreadRadius: layer.spread,
        ),
  ];
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
    color: tokens.colors[hovered || focused ? 'line-muted' : 'line-hairline']!,
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
      BorderRadius.circular(visualHeight < 32 ? 4 : 6);
  static BorderRadius field(RaftTokens t) =>
      BorderRadius.circular(t.fieldRadius);
  static BorderRadius panel(RaftTokens t) => BorderRadius.circular(t.radius);
  static BorderRadius attachment(RaftTokens t) => BorderRadius.circular(6);
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

  /// A surface transform that leaves layout and hit bounds unchanged.
  Matrix4 interactionTransform({
    required bool hovered,
    required bool pressed,
    required bool reducedMotion,
  }) {
    final scale =
        transformsOnInteraction &&
            pressed &&
            !reducedMotion &&
            kind != RaftControlKind.textLink &&
            kind != RaftControlKind.savedAction
        ? .985
        : 1.0;
    return Matrix4.diagonal3Values(scale, scale, 1);
  }

  /// Optional CSS outline, independent of selected borders/rings/shadows.
  double get focusOutlineWidth => 0;
  double get focusOutlineOffset => 0;
  double get disabledOpacity => .4;
  Color foregroundFor({bool hovered = false}) => foreground;

  /// Icons inherit the text foreground unless the component separates them.
  Color iconForegroundFor({bool hovered = false}) =>
      foregroundFor(hovered: hovered);
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered);
  Color get focusRing => switch (variant) {
    RaftControlVariant.surface || RaftControlVariant.outline => tokens.ink,
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
      : highContrast && variant == RaftControlVariant.danger
      ? tokens.colors['button-danger-high-contrast']!
      : kind == RaftControlKind.sidebar && selected
      ? tokens.dark
            ? tokens.card
            : tokens.panel
      : kind == RaftControlKind.tab
      ? selected
            ? tokens.primaryFill
            : tokens.dark
            ? tokens.colors['fill-muted']!
            : tokens.panel
      : switch (variant) {
          RaftControlVariant.primary => tokens.colors['primary-soft']!,
          RaftControlVariant.accent => tokens.colors['accent-soft']!,
          RaftControlVariant.danger => tokens.colors['button-danger-fill']!,
          RaftControlVariant.ghost => Colors.transparent,
          RaftControlVariant.outline =>
            !tokens.dark ? tokens.panel : tokens.colors['fill-muted']!,
          RaftControlVariant.surface => tokens.colors['button-default-fill']!,
        };
  Color get foreground => kind == RaftControlKind.savedAction
      ? tokens.colors['accent-strong']!
      : kind == RaftControlKind.textLink
      ? tokens.muted
      : highContrast && variant == RaftControlVariant.danger
      ? tokens.colors['button-danger-high-contrast-foreground']!
      : kind == RaftControlKind.tab
      ? selected
            ? tokens.colors['primary-950']!
            : tokens.ink
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
    if (!hovered || highContrast && variant == RaftControlVariant.danger) {
      return background;
    }
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
    if (kind == RaftControlKind.savedAction ||
        kind == RaftControlKind.textLink ||
        kind == RaftControlKind.tab ||
        variant == RaftControlVariant.ghost) {
      return null;
    }
    if (variant == RaftControlVariant.outline) {
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
    }
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
      kind == RaftControlKind.textLink || kind == RaftControlKind.savedAction
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
      ? BorderRadius.circular(4)
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
    fontFamily: tokens.bodyFont,
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
        ? FontWeight.w500
        : kind == RaftControlKind.filter
        ? FontWeight.w700
        : FontWeight.w500,
    letterSpacing: 0,
    color: foreground,
  );
  EdgeInsets get padding => kind == RaftControlKind.textLink
      ? EdgeInsets.zero
      : EdgeInsets.symmetric(
          horizontal: kind == RaftControlKind.sidebar
              ? 6
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
    width: 0,
    style: BorderStyle.none,
  );
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) {
    if (kind == RaftControlKind.savedAction) {
      return focused
          ? [BoxShadow(color: tokens.colors['primary-500']!, spreadRadius: .5)]
          : const [];
    }
    if (kind == RaftControlKind.textLink) return const [];
    if (variant == RaftControlVariant.ghost) return const [];
    if (kind == RaftControlKind.tab) {
      if (tokens.dark) {
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
      }
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
class RaftControl extends StatelessWidget {
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
  Widget build(BuildContext context) => asButton();

  /// Compatibility wrappers reuse the frozen paint while letting the current
  /// Button compose label / icon slots from its own recipe.
  Widget legacySurface(BuildContext context, RaftInteractionState state) =>
      _RaftLegacyControlSurface(this, state);

  Widget asButton({
    String? label,
    RaftGlyph? glyph,
    RaftGlyph? trailingGlyph,
    RaftButtonVariant? uiVariant,
    bool useComponentRecipe = true,
  }) {
    final tab =
        kind == RaftControlKind.tab || kind == RaftControlKind.segmentedButton;
    // Tab/sidebar appearances belong to their own component family, not the
    // Button variant axis. They keep the shared input and original surface.
    if (tab || kind == RaftControlKind.sidebar) {
      return RaftInteractive(
        onPressed: onPressed,
        busy: busy,
        focusNode: focusNode,
        focusOnPointer: focusOnPointer,
        tooltip: tooltip,
        semanticLabel: semanticLabel,
        semanticContainer: false,
        expandTouchTarget: false,
        button: !tab,
        checked: tab ? selected : null,
        inMutuallyExclusiveGroup: tab,
        selected: kind == RaftControlKind.sidebar ? selected : null,
        inertWhenDisabled: inertWhenDisabled,
        builder: (context, state) => _RaftLegacyControlSurface(this, state),
      );
    }
    final square = visualWidth != null && visualWidth == visualHeight;
    return RaftButton(
      label: label ?? '',
      child: label == null && glyph == null
          ? (busy && child is RaftSpinner ? const SizedBox() : child)
          : null,
      glyph: glyph,
      trailingGlyph: trailingGlyph,
      onPressed: onPressed,
      busy: busy,
      variant: variant,
      uiVariant:
          uiVariant ??
          (kind == RaftControlKind.textLink ? RaftButtonVariant.link : null),
      uiSize: kind == RaftControlKind.textLink
          ? RaftButtonSize.inline
          : square
          ? (visualHeight <= 24
                ? RaftButtonSize.iconXs
                : visualHeight <= 28
                ? RaftButtonSize.iconSm
                : visualHeight <= 32
                ? RaftButtonSize.iconMd
                : RaftButtonSize.iconLg)
          : null,
      visualHeight: visualHeight,
      visualWidth: square ? null : visualWidth,
      minimumTargetSize: minimumTargetSize,
      layoutTouchTarget: true,
      semanticContainer: false,
      expandTouchTarget: false,
      focusNode: focusNode,
      focusOnPointer: focusOnPointer,
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      toggled: kind == RaftControlKind.savedAction ? selected : null,
      inertWhenDisabled: inertWhenDisabled,
      padding: padding?.resolve(TextDirection.ltr),
      styleBuilder: recipe == null && !flexibleHeight
          ? null
          : (context, state, root) {
              final tokens = RaftTokens.of(context);
              final sourceShape =
                  tokens.option('iconButton.surface', or: 'generic') ==
                      'generic' &&
                  tokens.option('press.effect', or: 'overlay') == 'overlay';
              return !useComponentRecipe && sourceShape
                  ? root
                  : _raftControlButtonStyle(context, this, state, root);
            },
      legacyBuilder: (context, state) => _RaftLegacyControlSurface(this, state),
    );
  }
}

/// Existing composed-control recipes become explicit class overrides on the
/// Button root. They no longer own a second input or surface implementation.
RaftSlotStyle _raftControlButtonStyle(
  BuildContext context,
  RaftControl control,
  RaftInteractionState state,
  RaftSlotStyle root,
) {
  final recipe =
      control.recipe ??
      RaftControlRecipe(
        RaftTokens.of(context),
        variant: control.variant,
        kind: control.kind,
        selected: control.selected,
        visualHeight: control.visualHeight,
        highContrast: MediaQuery.highContrastOf(context),
      );
  CssColor color(Color c) => CssColor(c.toARGB32(), null, c);
  final radius = recipe.radius.resolve(Directionality.of(context));
  final border = recipe.side(hovered: state.hovered);
  final text = recipe.textStyle;
  final padding =
      (control.padding ??
              (control.visualWidth == null ? recipe.padding : EdgeInsets.zero))
          .resolve(Directionality.of(context));
  final matrix = recipe.interactionTransform(
    hovered: state.hovered,
    pressed: state.pressed,
    reducedMotion: MediaQuery.disableAnimationsOf(context),
  );
  final shadows = control.shadow
      ? recipe.shadows(
          hovered: state.hovered,
          pressed: state.pressed,
          focused: state.focusVisible,
        )
      : <BoxShadow>[
          if (state.focusVisible)
            BoxShadow(
              color: recipe.focusRing.withValues(
                alpha: recipe.focusRing.a * .8,
              ),
              spreadRadius: 2,
            ),
        ];
  return root.copyWith(
    properties: {
      ...root.properties,
      'height': control.flexibleHeight
          ? const CssKeyword('auto')
          : CssNum(control.visualHeight, 'px'),
      'min-height': CssNum(control.visualHeight, 'px'),
      if (control.visualWidth != null)
        'width': CssNum(control.visualWidth!, 'px'),
      'background-color': color(
        recipe.backgroundForInteraction(
          hovered: state.hovered,
          pressed: state.pressed,
        ),
      ),
      'background-image': const CssKeyword('none'),
      'color': color(recipe.foregroundFor(hovered: state.hovered)),
      if (text.fontSize != null) 'font-size': CssNum(text.fontSize!, 'px'),
      if (text.height != null) 'line-height': CssNum(text.height!),
      if (text.fontWeight != null)
        'font-weight': CssNum(text.fontWeight!.value.toDouble()),
      if (text.fontFamily != null) 'font-family': CssString(text.fontFamily!),
      if (text.letterSpacing != null)
        'letter-spacing': CssNum(text.letterSpacing!, 'px'),
      for (final side in ['top', 'right', 'bottom', 'left']) ...{
        'border-$side-width': CssNum(border.width, 'px'),
        'border-$side-style': const CssKeyword('solid'),
        'border-$side-color': color(border.color),
        'padding-$side': CssNum(switch (side) {
          'top' => padding.top,
          'right' => padding.right,
          'bottom' => padding.bottom,
          _ => padding.left,
        }, 'px'),
      },
      'border-top-left-radius': CssNum(radius.topLeft.x, 'px'),
      'border-top-right-radius': CssNum(radius.topRight.x, 'px'),
      'border-bottom-left-radius': CssNum(radius.bottomLeft.x, 'px'),
      'border-bottom-right-radius': CssNum(radius.bottomRight.x, 'px'),
      'box-shadow': CssList([
        // Recipes return Flutter paint order; CSS lists the top layer first.
        for (final s in shadows.reversed)
          CssSeq([
            CssNum(s.offset.dx, 'px'),
            CssNum(s.offset.dy, 'px'),
            CssNum(
              s.blurRadius <= .5
                  ? s.blurRadius * 2
                  : (s.blurRadius * .57735 + .5) * 2,
              'px',
            ),
            CssNum(s.spreadRadius, 'px'),
            color(s.color),
          ]),
      ]),
      'translate': CssSeq([CssNum(matrix[12], 'px'), CssNum(matrix[13], 'px')]),
      'scale': CssNum(matrix[0]),
      'opacity': CssNum(
        state.enabled || control.busy || control.inertWhenDisabled
            ? 1
            : recipe.disabledOpacity,
      ),
    },
  );
}

/// Frozen control paint. The enclosing Button / Interactive owns all input.
class _RaftLegacyControlSurface extends StatelessWidget {
  const _RaftLegacyControlSurface(this.control, this.state);
  final RaftControl control;
  final RaftInteractionState state;
  @override
  Widget build(BuildContext context) {
    final widget = control;
    final enabled = state.enabled;
    final hovered = state.hovered;
    final pressed = state.pressed;
    final focused = state.focusVisible;
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
    final bg = recipe.backgroundForInteraction(
      hovered: hovered,
      pressed: pressed,
    );
    final inert = widget.inertWhenDisabled && !enabled;
    return ConstrainedBox(
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
          opacity: enabled || widget.busy || inert ? 1 : recipe.disabledOpacity,
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
            transform: recipe.interactionTransform(
              hovered: hovered,
              pressed: pressed,
              reducedMotion: reducedMotion,
            ),
            decoration: RaftCssBoxDecoration(
              color: bg,
              borderRadius: recipe.radius,
              border: Border.fromBorderSide(recipe.side(hovered: hovered)),
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
                if (focused && (widget.kind == RaftControlKind.textLink))
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _TextLinkFocusPainter(
                          t.colors['line-strong']!,
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
                      color: widget.kind == RaftControlKind.textLink && hovered
                          ? t.strong
                          : recipe.iconForegroundFor(hovered: hovered),
                      size: recipe.iconSize,
                    ),
                    child: DefaultTextStyle(
                      style: RaftControlTypography.of(
                        context,
                        recipe.textStyle.copyWith(
                          color:
                              widget.kind == RaftControlKind.textLink && hovered
                              ? t.strong
                              : recipe.foregroundFor(hovered: hovered),
                        ),
                      ),
                      child: Center(widthFactor: 1, child: widget.child),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    this.uiVariant,
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

  /// Source Button variant, including the frame's 36px / 20px icon role.
  /// Legacy looks keep the frozen [variant] painter.
  final RaftButtonVariant? uiVariant;
  final bool busy, shadow;
  @override
  Widget build(BuildContext context) {
    // Only the source's 24px icon path consumes the shared layout minimum.
    // Larger icons retain their existing layout; explicit minima always win.
    final smallTouch =
        visualSize == RaftMetrics.buttonXs &&
        RaftDensityScope.of(context) == RaftDensity.touch;
    final button = RaftControl(
      shadow: shadow,
      onPressed: onPressed,
      tooltip: tooltip == null ? null : raftText(context, tooltip!),
      visualHeight: visualSize,
      visualWidth: visualSize,
      minimumTargetSize:
          minimumTargetSize ??
          (smallTouch
              ? RaftTokens.of(context).size('size.touchLayoutMin', fallback: 0)
              : null),
      variant: variant,
      recipe: visualSize == RaftMetrics.buttonXs
          ? RaftSmallIconRecipe(
              RaftTokens.of(context),
              variant: variant,
              visualHeight: visualSize,
              highContrast: MediaQuery.highContrastOf(context),
            )
          : null,
      busy: busy,
      semanticLabel: busy
          ? raftText(context, tooltip ?? 'Loading')
          : semanticLabel,
      child: busy
          ? RaftSpinner(size: glyphSize)
          : RaftIcon(glyph, size: glyphSize ?? (visualSize <= 28 ? 14 : 16)),
    ).asButton(glyph: glyph, uiVariant: uiVariant, useComponentRecipe: false);
    final label = tooltip;
    // An icon button is fixed chrome: at large text sizes a long press shows
    // its icon and label large (Large Content Viewer).
    Widget result = label == null
        ? button
        : RaftChrome(
            child: RaftLargeContentViewer(
              label: raftText(context, label),
              enabled: onPressed != null && !busy,
              onActivate: onPressed,
              iconBuilder: (context, size) => RaftIcon(glyph, size: size),
              child: button,
            ),
          );
    if (smallTouch) {
      // Wrap tooltip and large-content-viewer boxes too. The anchor lets an
      // enclosing RaftTapSlopHost route touches outside a narrow toolbar row.
      result = RaftTapSlopAnchor(
        minSize: const Size.square(RaftMetrics.touchTarget),
        child: RaftTouchTarget(child: result),
      );
    }
    return result;
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
    this.tooltip = 'Remove from Saved',
  });
  final VoidCallback? onPressed;
  final String tooltip;
  @override
  Widget build(BuildContext context) {
    final dimension = 32.0;
    return RaftControl(
      onPressed: onPressed,
      tooltip: raftText(context, tooltip),
      kind: RaftControlKind.savedAction,
      selected: true,
      visualHeight: dimension,
      visualWidth: dimension,
      variant: RaftControlVariant.outline,
      child: RaftIcon(RaftGlyph.bookmarkFilled, size: 16),
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
  Widget build(BuildContext context) =>
      RaftControl(
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
      ).asButton(
        label: raftText(context, label),
        glyph: glyph,
        trailingGlyph: trailingGlyph,
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
    // raft-ui 0.7.1 `focus:shadow-focus`: the field keeps its border and the focus ring (2px surface gap, 2px ink)
    // is drawn OUTSIDE it, not the Material focused-border colour swap.
    final theme = Theme.of(context);
    final inputs = theme.inputDecorationTheme;
    return Focus(
      skipTraversal: true,
      onFocusChange: (value) => setState(() => focused = value),
      child: RaftOuterRings(
        radius: 8,
        rings: focused
            ? [
                for (final layer in t.ui.focusRing.layers)
                  RaftRing(layer.spread, layer.color),
              ]
            : const [],
        child: Theme(
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
  Color get foreground => tokens.muted;
  Color get highlightedBackground => tokens.colors['ink-4']!;
  BorderRadius get radius => RaftShapes.field(tokens);
  BorderSide get border => BorderSide.none;
  EdgeInsets get inset => EdgeInsets.all(4);
  EdgeInsets get rowInset => const EdgeInsets.symmetric(horizontal: 12);
  double get rowVisualHeight => kind == RaftMenuKind.selectionPopover
      ? 36
      : viewportHeight <= 600
      ? 27.5
      : 31.5;
  double get rowTargetHeight => RaftMetrics.touchTarget;
  double get popupGap => 6;
  TextStyle get label => kind == RaftMenuKind.selectionPopover
      ? RaftTypography.body(tokens, size: 12, line: 16, weight: FontWeight.w700)
      : RaftTypography.body(
          tokens,
          size: 13,
          line: 19.5,
          weight: FontWeight.w400,
          color: foreground,
        ).copyWith(letterSpacing: -.065);
  TextStyle get meta =>
      RaftTypography.body(tokens, size: 12, line: 16, color: tokens.muted);
  List<BoxShadow> get shadows => tokens.dark
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

/// raft-ui `Spinner`, the one spinner of the client: the pixel grid in the Raft
/// look and the original ring in the frozen looks, with caller overrides.
class RaftSpinner extends StatefulWidget {
  const RaftSpinner({
    super.key,
    this.size,
    this.inverse = false,
    this.recipeSize,
  });

  /// Explicit physical slot size. Wins over the recipe's intrinsic extent.
  final double? size;

  /// Source size axis; retained separately from a caller's physical override.
  final RaftSpinnerRecipeSize? recipeSize;
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
    final pixel = t.option('spinner.style', or: 'ring') == 'pixel';
    final quarter = t.option('spinner.ringShape', or: 'sweep') == 'quarter';
    reduced = MediaQuery.disableAnimationsOf(context);
    spin.duration = Duration(
      milliseconds: t.size('duration.spinnerTurn', fallback: 1600).round(),
    );
    if (reduced || pixel) {
      spin.stop();
      dash.stop();
    } else {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Loop driven by an AnimationController whose vsync is this State, so TickerMode (hidden routes, offstage tabs, folded panels) mutes it, it is disposed with the widget, and reduced motion stops it.
      spin.repeat();
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Loop driven by an AnimationController whose vsync is this State, so TickerMode (hidden routes, offstage tabs, folded panels) mutes it, it is disposed with the widget, and reduced motion stops it.
      if (quarter) {
        dash.stop();
      } else {
        // ignore: raft_lints/avoid_unreviewed_idle_work -- State vsync and TickerMode bound this animation; reduced motion stops it and dispose retires it.
        dash.repeat();
      }
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
    final pixel = t.option('spinner.style', or: 'ring') == 'pixel';
    final quarter = t.option('spinner.ringShape', or: 'sweep') == 'quarter';
    final fixed = t.option('spinner.foreground', or: 'inherited') == 'fixed';
    if (pixel) {
      final size = switch (widget.recipeSize) {
        RaftSpinnerRecipeSize.xs => RaftPixelSpinnerSize.xs,
        RaftSpinnerRecipeSize.md => RaftPixelSpinnerSize.md,
        RaftSpinnerRecipeSize.lg => RaftPixelSpinnerSize.lg,
        _ => RaftPixelSpinnerSize.sm,
      };
      final ambient = DefaultTextStyle.of(context).style;
      final color = size
          .resolve(t.recipeTokens, inverse: widget.inverse)
          .root
          .text(
            t.recipeTokens,
            base: ambient.copyWith(
              color: fixed
                  ? t.colors['foreground-spinner']!
                  : ambient.color ?? t.ink,
            ),
          )
          .color;
      final grid = RaftPixelSpinner(size: size, color: color);
      return ExcludeSemantics(
        child: RepaintBoundary(
          child: widget.size == null && widget.recipeSize != null
              ? grid
              : SizedBox.square(
                  dimension:
                      widget.size ??
                      t.size('size.spinnerDefault', fallback: 12),
                  child: Center(child: grid),
                ),
        ),
      );
    }
    final dimension =
        widget.size ??
        switch (widget.recipeSize) {
          RaftSpinnerRecipeSize.xs => 10.0,
          RaftSpinnerRecipeSize.sm => 16.0,
          RaftSpinnerRecipeSize.md => 20.0,
          RaftSpinnerRecipeSize.lg => 32.0,
          null => t.size('size.spinnerDefault', fallback: 14),
        };
    // [inverse]: on a dark surface (the video stage, a dark button) in every
    // theme; elegant used to ignore it and drew an ink spinner on black.
    final color = widget.inverse
        ? Colors.white
        : fixed
        ? t.colors['foreground-spinner']!
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
                quarter: quarter,
                stroke: t.size('stroke.spinnerRing', fallback: 0),
                radiusRatio: t.size(
                  'ratio.spinnerRingRadius',
                  fallback: 10 / 24,
                ),
                inset: t.size('space.spinnerRingInset', fallback: 0),
                arcOpacity: t.size('opacity.spinnerArc', fallback: .8),
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
    required this.color,
    required this.quarter,
    required this.stroke,
    required this.radiusRatio,
    required this.inset,
    required this.arcOpacity,
    required this.rotation,
    required this.phase,
    required this.reduced,
  });
  final bool reduced, quarter;
  final double stroke, radiusRatio, inset, arcOpacity;
  final Color color;
  final double rotation, phase;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = this.stroke > 0 ? this.stroke : size.width * 2.5 / 24;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width * radiusRatio - inset,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation * math.pi * 2);
    canvas.translate(-size.width / 2, -size.height / 2);
    paint.color = color.withValues(alpha: .2);
    canvas.drawOval(rect, paint);
    paint.color = color.withValues(alpha: arcOpacity);
    paint.strokeCap = quarter ? StrokeCap.butt : StrokeCap.round;
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
      quarter ? math.pi / 2 : length / 150 * math.pi * 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.quarter != quarter ||
      old.stroke != stroke ||
      old.radiusRatio != radiusRatio ||
      old.inset != inset ||
      old.arcOpacity != arcOpacity ||
      old.rotation != rotation ||
      old.phase != phase ||
      old.color != color ||
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
  BorderSide get border =>
      BorderSide(color: tokens.colors['line-muted']!, width: .5);
  EdgeInsets get inset => const EdgeInsets.all(2);
  EdgeInsets get itemInset =>
      EdgeInsets.symmetric(horizontal: 12, vertical: 14);
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
  TextStyle get author =>
      metadata.copyWith(fontWeight: FontWeight.w600, color: tokens.strong);
  TextStyle get count => header.copyWith(
    fontWeight: FontWeight.w500,
    color: tokens.colors['foreground-placeholder']!,
  );
  TextStyle get source =>
      count.copyWith(color: tokens.colors['foreground-placeholder']!);
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

enum RaftMenuKind {
  /// The Web product MenuItem inside a Popover (for example Help).
  dropdown,

  /// The published RUI DropdownMenuContent / DropdownMenuItem slots.
  dropdownMenu,
  selectionPopover,
}

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
    this.kind = RaftMenuKind.dropdown,
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
    this.surfaceKey,
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

  /// Identifies the rendered popup surface without changing trigger identity.
  final Key? surfaceKey;
  final EdgeInsetsGeometry? panelInset;
  final bool openOnHover;
  final Duration closeDelay;
  final String label;
  final List<RaftMenuEntry> entries;
  final RaftMenuController? controller;
  final RaftMenuKind kind;
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
        !widget.openOnHover || RaftFocusVisible.shared.keyboard || edge != null;
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
    _focusAndReveal(delta > 0 ? enabled.first : enabled.last);
  }

  void _focusAndReveal(int index) {
    final node = nodes[index];
    node.requestFocus();
    final captured = ticket;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !triggerEnabled ||
          !controller.isOpen ||
          captured != ticket ||
          index >= nodes.length ||
          nodes[index] != node ||
          !node.hasFocus) {
        return;
      }
      final rowContext = node.context;
      if (rowContext == null ||
          !rowContext.mounted ||
          FocusScope.of(rowContext) != popup) {
        return;
      }
      final target = rowContext.findRenderObject();
      final scrollable = Scrollable.maybeOf(rowContext);
      if (target == null || scrollable == null) return;
      // The nearest scrollable is the anchored popup, never the page.
      revealRaftMenuRow(target: target, position: scrollable.position);
    });
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
    _focusAndReveal(choices[(current + delta) % choices.length]);
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
    final grows = RaftScaled.grows(context);
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
                      snapToPixel: t.isRaftLook,
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
                                  key: widget.surfaceKey,
                                  kind: widget.kind,
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
                                          height: 9,
                                          child: Center(
                                            child: Container(
                                              height: .5,
                                              color: t.colors['line-hairline'],
                                            ),
                                          ),
                                        )
                                      else
                                        RaftMenuItem(
                                          kind: widget.kind,
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
                        ? 28
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
                                ? (12)
                                : 14,
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (t.isRaftLook)
                          // Match Button's label constraints inside composed
                          // content; icons keep their own intrinsic width.
                          Flexible(
                            child: Text(
                              widget.label,
                              maxLines: grows ? null : 1,
                              softWrap: grows,
                              overflow: grows
                                  ? TextOverflow.clip
                                  : TextOverflow.ellipsis,
                            ),
                          )
                        else
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
    final t = RaftTokens.of(context);
    final recipe = RaftMenuRecipe(
      t,
      kind: kind,
      viewportHeight: MediaQuery.sizeOf(context).height,
    );
    final items = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    Widget panel;
    if (t.isRaftLook && kind == RaftMenuKind.selectionPopover) {
      final rt = t.recipeTokens;
      final selection = RaftWebSelectionPanelRecipe.resolve(
        tokens: rt,
        states: t.recipeStates(),
      );
      final minimumWidth =
          selection.root.minWidth ??
          RaftPopoverRecipe.resolve(
            theme: t.recipeTheme,
            tokens: rt,
            states: t.recipeStates(),
          ).content.minWidth ??
          0;
      panel = SizedBox(
        width: math.max(width, minimumWidth),
        child: RaftPopoverSurface(
          surfaceStyle: selection.root,
          padding: padding?.resolve(Directionality.of(context)),
          child: RaftRecipeBox(
            style: selection.list,
            tokens: rt,
            applyText: false,
            child: SingleChildScrollView(primary: false, child: items),
          ),
        ),
      );
    } else if (t.isRaftLook && kind != RaftMenuKind.selectionPopover) {
      final rt = t.recipeTokens;
      final currentPopover = kind == RaftMenuKind.dropdownMenu
          ? RaftDropdownMenuRecipe.resolve(
              theme: t.recipeTheme,
              tokens: rt,
              states: t.recipeStates(),
            ).content
          : RaftPopoverRecipe.resolve(
              theme: t.recipeTheme,
              tokens: rt,
              states: t.recipeStates(),
            ).content;
      panel = SizedBox(
        // CSS min-width wins over a narrower authored width; the placement
        // owner's viewport constraints still cap the used popup width.
        width: math.max(width, currentPopover.minWidth ?? 0),
        child: RaftPopoverSurface(
          surfaceStyle: currentPopover,
          padding: padding?.resolve(Directionality.of(context)),
          child: DefaultTextStyle.merge(
            style: currentPopover.text(rt),
            child: items,
          ),
        ),
      );
    } else {
      panel = Container(
        width: width,
        padding: padding ?? recipe.inset,
        decoration: BoxDecoration(
          color: recipe.background,
          borderRadius: recipe.radius,
          border: Border.fromBorderSide(recipe.border),
          boxShadow: recipe.shadows,
        ),
        child: items,
      );
    }
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
            child: panel,
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
            child: t.isRaftLook && widget.kind == RaftMenuKind.dropdown
                ? RaftMenuActionRow(
                    label: widget.label,
                    leading:
                        widget.leading ??
                        (widget.glyph == null
                            ? null
                            : RaftIcon(widget.glyph!, size: 14)),
                    trailing: widget.trailing,
                    enabled: enabled,
                    hovered: hovered,
                    focusVisible: focused,
                  )
                : t.isRaftLook && widget.kind == RaftMenuKind.dropdownMenu
                ? RaftMenuSlotRow(
                    label: widget.label,
                    leading:
                        widget.leading ??
                        (widget.glyph == null
                            ? null
                            : RaftIcon(widget.glyph!, size: 16)),
                    trailing: widget.trailing,
                    root: RaftDropdownMenuRecipe.resolve(
                      theme: t.recipeTheme,
                      tokens: t.recipeTokens,
                      states: t
                          .recipeStates(
                            disabled: !enabled,
                            extra: [
                              if (!enabled) 'data-disabled',
                              if (widget.selected) 'data-selected',
                              if (enabled && (hovered || focused))
                                'data-highlighted',
                            ],
                          )
                          .copyWith(
                            viewportWidth: MediaQuery.sizeOf(context).width,
                            viewportHeight: MediaQuery.sizeOf(context).height,
                          ),
                    ).item,
                    tokens: t.recipeTokens,
                  )
                : t.isRaftLook && widget.kind == RaftMenuKind.selectionPopover
                ? Builder(
                    builder: (context) {
                      final rt = t.recipeTokens;
                      final slots = RaftWebSelectionRowRecipe.resolve(
                        checked: widget.selected,
                        disabled: !enabled,
                        italic: widget.italic,
                        states: t.recipeStates(
                          hovered: enabled && hovered,
                          focusVisible: enabled && focused,
                          disabled: !enabled,
                        ),
                        tokens: rt,
                      );
                      return RaftMenuSlotRow(
                        label: widget.label,
                        labelChild: Text(
                          widget.label,
                          overflow: widget.italic
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                        leading:
                            widget.leading ??
                            (widget.glyph == null
                                ? null
                                : RaftIcon(widget.glyph!, size: 16)),
                        trailing: widget.trailing,
                        indicator: widget.selected
                            ? RaftIcon(
                                RaftGlyph.check,
                                size: slots.indicator.width!,
                              )
                            : null,
                        root: slots.root,
                        itemLeading: slots.leading,
                        itemText: slots.label,
                        itemIndicator: slots.indicator,
                        tokens: rt,
                      );
                    },
                  )
                : Container(
                    height: grows ? null : height,
                    constraints: grows
                        ? BoxConstraints(minHeight: height)
                        : null,
                    padding: recipe.rowInset,
                    decoration: BoxDecoration(
                      color: enabled && (hovered || focused)
                          ? recipe.highlightedBackground
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                      border: widget.divider
                          ? Border(
                              bottom: BorderSide(
                                color: t.colors['line-muted']!,
                              ),
                            )
                          : null,
                    ),
                    child: Opacity(
                      opacity: enabled ? 1 : .3,
                      child: Row(
                        children: [
                          if (widget.leading != null ||
                              widget.glyph != null) ...[
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
                                size: 16,
                                strokeWidth: 1.5,
                                color: enabled && (hovered || focused)
                                    ? t.ink
                                    : recipe.foreground,
                              ),
                            SizedBox(
                              width:
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
                                          widget.kind ==
                                              RaftMenuKind.selectionPopover
                                      ? FontWeight.w700
                                      : recipe.label.fontWeight,
                                  fontStyle: widget.italic
                                      ? FontStyle.italic
                                      : null,
                                  color: widget.italic ? t.muted : null,
                                ),
                              ),
                            ),
                          ),
                          if (widget.trailing != null) widget.trailing!,
                          if (widget.kind == RaftMenuKind.selectionPopover &&
                              widget.selected)
                            RaftIcon(
                              RaftGlyph.check,
                              size: 12,
                              color: t.strong,
                            ),
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
  EdgeInsets get inset => EdgeInsets.all(12);

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
  BorderRadius get radius => BorderRadius.circular(10);
  Color get background => tokens.colors['task-section-fill']!;
  BoxDecoration get decoration =>
      BoxDecoration(color: background, borderRadius: radius);
  TextStyle get heading =>
      RaftTypography.body(tokens, size: 12, line: 16, weight: FontWeight.w500);
  TextStyle get count => RaftTypography.mono(tokens, size: 12, line: 16);
  Color get chevron => tokens.colors['foreground-icon']!;
}

/// Original PickerTriggerButton, not the generic Button outline variant.
/// Source: raft-ui 0.5.52 index.mjs, Search activeFilterClass.
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
      ? tokens.colors['primary-soft']!
      : tokens.dark
      ? tokens.colors['fill-muted']!
      : tokens.panel;
  @override
  Color backgroundFor({bool hovered = false}) => selected || !hovered
      ? background
      : tokens.colors[tokens.dark ? 'fill-strong' : 'ink-2']!;
  @override
  Color get foreground =>
      selected ? tokens.strong : tokens.colors['foreground-placeholder']!;
  @override
  Color get focusRing => tokens.colors['primary-400']!;
  @override
  BorderRadius get radius => BorderRadius.circular(6);
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  EdgeInsets get padding => EdgeInsets.symmetric(horizontal: 10);
  @override
  TextStyle get textStyle => RaftTypography.body(
    tokens,
    size: 12,
    line: 16,
    weight: FontWeight.w500,
    color: foreground,
  ).copyWith(letterSpacing: -.06);
  @override
  double get insetHighlightAlpha => tokens.dark ? .045 : .05;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => [
    if (selected) ...tokens.shadows,
    if (!selected && !tokens.dark)
      BoxShadow(color: tokens.colors['line-muted']!, spreadRadius: 1),
    if (!selected && tokens.dark) ...[
      BoxShadow(color: Colors.black.withValues(alpha: .4), spreadRadius: 1),
      BoxShadow(
        color: Colors.black.withValues(alpha: .22),
        offset: const Offset(0, 1),
        blurRadius: 3,
      ),
    ],
    if (focused) BoxShadow(color: focusRing, spreadRadius: 2),
  ];
}

/// The frozen Elegant and Brutal paint of `RaftPickerTriggerButton`: the pre-0.7.0 PickerTriggerButton recipe on a
/// [RaftControl]. Delete with the legacy looks.
Widget raftFrozenPickerTriggerButton(
  BuildContext context, {
  required String label,
  required VoidCallback? onPressed,
  required RaftGlyph? glyph,
  required RaftGlyph? trailingGlyph,
  required bool selected,
  required String? tooltip,
  required FocusNode? focusNode,
}) => RaftControl(
  onPressed: onPressed,
  focusNode: focusNode,
  tooltip: tooltip,
  visualHeight: 28,
  variant: RaftControlVariant.outline,
  recipe: RaftPickerTriggerRecipe(RaftTokens.of(context), selected: selected),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (glyph != null) ...[
        RaftIcon(glyph, size: 14),
        const SizedBox(width: 8),
      ],
      Text(raftText(context, label)),
      if (trailingGlyph != null) ...[
        const SizedBox(width: 8),
        RaftIcon(trailingGlyph, size: 12),
      ],
    ],
  ),
);

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
    this.onShowHoverHighlight,
    this.onTapDown,
    this.onTapCancel,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.semanticContainer,
    this.expandTouchTarget = true,
    this.cancelOutsideRelease = false,
    this.busy = false,
    this.focusNode,
    this.focusOnPointer = true,
    this.semanticLabel,
    this.semanticRole,
    this.semanticValue,
    this.liveRegion = false,
    this.button = true,
    this.selected,
    this.checked,
    this.toggled,
    this.inMutuallyExclusiveGroup = false,
    this.inertWhenDisabled = false,
    this.tooltip,
  });

  final Widget Function(BuildContext context, RaftInteractionState state)
  builder;
  final VoidCallback? onPressed;

  /// Optional keyboard/semantics activation. Pointer activation continues
  /// to call [onPressed]; without this callback all inputs call [onPressed].
  final VoidCallback? onKeyboardActivate;

  /// Modality-gated hover paint, as supplied by [FocusableActionDetector].
  final ValueChanged<bool>? onShowHoverHighlight;
  final GestureTapDownCallback? onTapDown;
  final GestureTapCancelCallback? onTapCancel;
  final GestureLongPressCallback? onLongPress;
  final GestureTapDownCallback? onSecondaryTapDown;
  final bool? semanticContainer;
  final bool busy, focusOnPointer, button, cancelOutsideRelease;
  final bool expandTouchTarget;
  final bool? selected, checked, toggled;
  final bool inMutuallyExclusiveGroup, inertWhenDisabled;
  final FocusNode? focusNode;
  final String? semanticLabel, tooltip;
  final SemanticsRole? semanticRole;
  final String? semanticValue;
  final bool liveRegion;

  @override
  State<RaftInteractive> createState() => _RaftInteractiveState();
}

class _RaftInteractiveState extends State<RaftInteractive>
    with AutomaticKeepAliveClientMixin<RaftInteractive> {
  @override
  bool get wantKeepAlive => pressed || heldPointers.isNotEmpty;
  final heldPointers = <int>{};
  void holdPointer(PointerEvent event) {
    heldPointers.add(event.pointer);
    updateKeepAlive();
  }

  void releasePointer(PointerEvent event) {
    heldPointers.remove(event.pointer);
    updateKeepAlive();
  }

  bool hovered = false, focused = false, pressed = false;
  bool tooltipKeyboardFocused = false;
  final ownedFocus = FocusNode();
  FocusNode get node => widget.focusNode ?? ownedFocus;
  bool get enabled => widget.onPressed != null && !widget.busy;

  @override
  void initState() {
    super.initState();
    RaftFocusVisible.shared.acquire();
    RaftFocusVisible.shared.addListener(modeChanged);
  }

  @override
  void dispose() {
    RaftFocusVisible.shared.removeListener(modeChanged);
    RaftFocusVisible.shared.release();
    ownedFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RaftInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!enabled) {
      pressed = hovered = focused = tooltipKeyboardFocused = false;
      updateKeepAlive();
    }
  }

  void modeChanged() {
    final next = enabled && node.hasFocus && RaftFocusVisible.shared.keyboard;
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
      focused = enabled && hasFocus && RaftFocusVisible.shared.keyboard;
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
    super.build(context);
    final touch = RaftDensityScope.of(context) == RaftDensity.touch;
    final state = RaftInteractionState(
      hovered: hovered,
      pressed: pressed,
      focusVisible: focused,
      enabled: enabled,
    );
    final inert = widget.inertWhenDisabled && !enabled;
    Widget result = Semantics(
      // TouchTarget supplies this boundary and its larger semantics rect on
      // touch devices, including controls whose inner density is desktop to
      // preserve visual geometry. Other desktop controls own their boundary.
      container:
          widget.semanticContainer ??
          (!touch &&
              context.findAncestorWidgetOfExactType<RaftTouchTarget>() == null),
      label: widget.semanticLabel,
      value: widget.semanticValue,
      liveRegion: widget.liveRegion,
      excludeSemantics: widget.busy,
      button: !inert && widget.button,
      role: widget.semanticRole,
      selected: widget.selected,
      checked: widget.checked,
      toggled: widget.toggled,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      enabled: inert ? null : enabled,
      onTap: enabled ? activateControl : null,
      onLongPress: enabled ? widget.onLongPress : null,
      child: RaftHoverRegion(
        onEnter: enabled ? (_) => setState(() => hovered = true) : null,
        onExit: (_) => setState(() => hovered = false),
        child: FocusableActionDetector(
          focusNode: node,
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowHoverHighlight: widget.onShowHoverHighlight,
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
          child: Listener(
            onPointerDown: enabled ? holdPointer : null,
            onPointerUp: releasePointer,
            onPointerCancel: releasePointer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapDown: enabled
                  ? (details) {
                      if (widget.focusOnPointer) node.requestFocus();
                      setState(() => pressed = true);
                      updateKeepAlive();
                      widget.onTapDown?.call(details);
                    }
                  : null,
              onTapUp: enabled
                  ? (details) {
                      setState(() => pressed = false);
                      updateKeepAlive();
                      if (!widget.cancelOutsideRelease) {
                        widget.onPressed?.call();
                        return;
                      }
                      final box = context.findRenderObject();
                      final reach = details.kind == PointerDeviceKind.touch
                          ? RaftMetrics.touchTarget / 2
                          : 0.0;
                      if (box is RenderBox &&
                          (Offset.zero & box.size)
                              .inflate(reach)
                              .contains(details.localPosition)) {
                        widget.onPressed?.call();
                      }
                    }
                  : null,
              onTapCancel: enabled
                  ? () {
                      setState(() => pressed = false);
                      updateKeepAlive();
                      widget.onTapCancel?.call();
                    }
                  : null,
              onLongPress: enabled ? widget.onLongPress : null,
              onSecondaryTapDown: enabled ? widget.onSecondaryTapDown : null,
              child: widget.builder(context, state),
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
    // The expander must surround the tooltip's render boxes too; otherwise
    // those 32px boxes reject pointers before the expanded target sees them.
    if (touch && widget.expandTouchTarget) {
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
    if (!size.contains(position)) {
      // Preserve the visual hit path while an enclosing host probes or
      // protects a direct control. The control's own visible box still hits.
      if (raftTapSlopVisualBoundsOnly(this)) return false;
    }
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
