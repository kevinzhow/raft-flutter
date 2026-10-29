import 'package:flutter/material.dart';
import 'package:raft_theme/recipes.dart' show RaftRecipeSet;

import 'design_primitives.dart';
import 'theme.dart';

/// The desktop window's title strip, painted in the nav rail's colours.
///
/// Brutal wears the rail's yellow with a 2 px black rule; Elegant (light and
/// dark) wears the rail's canvas with a 1 px divider. Everything is read from
/// the rail recipe, so the strip follows live theme changes with the rail.
@immutable
class RaftTitleBarRecipe {
  const RaftTitleBarRecipe(this.tokens);

  final RaftTokens tokens;

  /// The rail's own background (`AppRailRoot`).
  Color get background => RaftRailRecipe(tokens, viewportHeight: 0).background;

  /// The glyph colour the system draws window controls in, where they sit on
  /// [background]. New packs declare the Web frame role; older packs retain
  /// their frozen rail foreground.
  Color get foreground => tokens.recipeSet == RaftRecipeSet.legacy
      ? RaftRailRecipe(tokens, viewportHeight: 0).foreground
      : tokens.colors['foreground-on-frame'] ??
            RaftRailRecipe(tokens, viewportHeight: 0).foreground;

  /// The rail's divider: pure black in Brutal, the muted line in Elegant.
  Color get rule => RaftRailRecipe(tokens, viewportHeight: 0).border.color;

  /// 2 px in Brutal, 1 px in Elegant.
  double get ruleWidth => tokens.border;
}

/// The empty strip itself: rail colour, bottom rule, no text, no controls.
///
/// A press that moves, and a double press, are handed to the window: the
/// system's own title bar does both, and a Flutter view covering the bar takes
/// those events away from it.
class RaftDesktopTitleStrip extends StatelessWidget {
  const RaftDesktopTitleStrip({
    super.key,
    required this.height,
    this.title,
    this.onDragStart,
    this.onDoubleTap,
  });

  /// The whole strip, rule included: the system title bar's height, or just
  /// [RaftTitleBarRecipe.ruleWidth] below an independently drawn native bar.
  final double height;

  /// Optional noninteractive branding in the otherwise draggable strip.
  final Widget? title;

  /// Begin moving the window; the press that started the move is the pointer
  /// event being handled.
  final VoidCallback? onDragStart;

  /// A double press, which the system decides what to do with (zoom, minimise
  /// or nothing).
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final recipe = RaftTitleBarRecipe(RaftTokens.of(context));
    return SizedBox(
      height: height,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const Key('desktop-title-drag'),
          behavior: HitTestBehavior.opaque,
          onPanStart: onDragStart == null ? null : (_) => onDragStart!(),
          onDoubleTap: onDoubleTap,
          child: DecoratedBox(
            key: const Key('desktop-title-strip'),
            child: title == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(bottom: recipe.ruleWidth),
                    child: title,
                  ),
            decoration: BoxDecoration(
              color: recipe.background,
              border: Border(
                bottom: BorderSide(color: recipe.rule, width: recipe.ruleWidth),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts the title strip above [child] while the window shows one.
///
/// [height] is the native title bar height, or [RaftTitleBarRecipe.ruleWidth]
/// when only the rule below a native bar is needed. Zero draws nothing;
/// [fullscreen] hides the strip even if a height is stale
/// (macOS hides its title bar in fullscreen). The content below is given the
/// remaining height, and the [MediaQuery] size matches it so everything
/// measured against the viewport sees the area it really has.
class RaftDesktopTitleBar extends StatelessWidget {
  const RaftDesktopTitleBar({
    super.key,
    required this.height,
    required this.child,
    this.title,
    this.fullscreen = false,
    this.onDragStart,
    this.onDoubleTap,
  });

  final double height;

  /// Optional noninteractive branding in the otherwise draggable strip.
  final Widget? title;
  final bool fullscreen;
  final VoidCallback? onDragStart;
  final VoidCallback? onDoubleTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (fullscreen || !(height > 0)) return child;
    final media = MediaQuery.of(context);
    final remaining = media.size.height - height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftDesktopTitleStrip(
          height: height,
          title: title,
          onDragStart: onDragStart,
          onDoubleTap: onDoubleTap,
        ),
        Expanded(
          child: MediaQuery(
            data: media.copyWith(
              size: Size(media.size.width, remaining < 0 ? 0 : remaining),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
