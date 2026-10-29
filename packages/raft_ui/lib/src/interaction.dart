import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'design_primitives.dart' show RaftDensity, RaftDensityScope;

/// How the person reaches the screen: a finger or a pointer.
enum RaftInputMode { touch, pointer }

/// The one place that says which interaction family the app speaks.
///
/// Two axes decide how a screen behaves, and they never mix:
///
/// * Layout (how many columns, whether a side panel sits beside or over the
///   content) follows the available width: `RaftAdaptiveWorkspace.compactOf`,
///   `raftBreakpointWidth`, `raftLayoutClassOf`.
/// * Interaction (swipe / drag to dismiss, long-press menus, hover bars and
///   cards, tooltips, context menus, Enter sends or breaks the line, touch
///   target size, immersive viewer chrome, pull to refresh) follows the input
///   modality, resolved here from the target platform.
///
/// Reading the width for an interaction decision is the bug this class exists
/// to prevent: an unfolded foldable or a tablet is as wide as a desktop window
/// and still touched with fingers; a narrow desktop window is as narrow as a
/// phone and still driven with a mouse.
///
/// The mode comes from the platform, not from the last pointer that moved. A
/// layout that flipped between finger and mouse every time the user switched
/// would re-parent state under their hand (a message row losing its menu, a
/// viewer swapping chrome mid-gesture). Hover-only widgets already check each
/// event's own `PointerDeviceKind` (`RaftTooltip`, `RaftHoverCard`), so a mouse
/// attached to a tablet still gets tooltips there without changing the rest.
/// Mobile web reports the OS in `defaultTargetPlatform`, so it resolves as
/// touch too.
@immutable
class RaftInteraction {
  const RaftInteraction(this.mode);

  /// Resolves the mode of a target platform: Android, iOS and Fuchsia are
  /// touch, macOS, Windows and Linux are pointer.
  factory RaftInteraction.forPlatform(TargetPlatform platform) =>
      RaftInteraction(
        platformIsTouch(platform) ? RaftInputMode.touch : RaftInputMode.pointer,
      );

  static const touchMode = RaftInteraction(RaftInputMode.touch);
  static const pointerMode = RaftInteraction(RaftInputMode.pointer);

  final RaftInputMode mode;

  static bool platformIsTouch(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => true,
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => false,
  };

  /// The interaction of [context]: the nearest [RaftInteractionScope]; else an
  /// explicit [RaftDensityScope] (the older override that previews, tests and a
  /// few fixed surfaces use: touch density is touch input); else the theme's
  /// platform (which a test sets with `debugDefaultTargetPlatformOverride` or
  /// `ThemeData.platform`).
  static RaftInteraction of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<RaftInteractionScope>();
    if (scope != null) return scope.interaction;
    final density = context
        .dependOnInheritedWidgetOfExactType<RaftDensityScope>();
    if (density != null) {
      return density.density == RaftDensity.touch ? touchMode : pointerMode;
    }
    return RaftInteraction.forPlatform(Theme.of(context).platform);
  }

  /// Fingers: long-press opens menus, no hover affordances, 48 dp targets, the
  /// media viewer is an immersive stage that a swipe down dismisses.
  bool get touch => mode == RaftInputMode.touch;

  /// A mouse or trackpad: hover bars and cards, right-click menus, tooltips,
  /// Enter sends, keyboard shortcut hints.
  bool get pointer => mode == RaftInputMode.pointer;

  /// Hover reveals actions (message bar, row actions, tooltips).
  bool get hover => pointer;

  /// A hardware Enter key in a multi-line field sends instead of breaking the
  /// line. Touch keyboards keep Enter as a line break; the send button sends.
  bool get enterSends => pointer;

  /// Keyboard shortcut hints (Ctrl+K, Esc) are worth showing.
  bool get shortcutHints => pointer;

  @override
  bool operator ==(Object other) =>
      other is RaftInteraction && other.mode == mode;

  @override
  int get hashCode => mode.hashCode;

  @override
  String toString() => 'RaftInteraction(${mode.name})';
}

/// Overrides the interaction below it. The app root does not need one: the
/// platform answers. Tests and previews use it to mount a touch surface on a
/// wide window or a pointer surface on a narrow one.
class RaftInteractionScope extends InheritedWidget {
  const RaftInteractionScope({
    super.key,
    required this.interaction,
    required super.child,
  });

  final RaftInteraction interaction;

  @override
  bool updateShouldNotify(RaftInteractionScope oldWidget) =>
      interaction != oldWidget.interaction;
}
