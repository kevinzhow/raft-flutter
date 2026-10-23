import 'package:flutter/material.dart';

import 'theme.dart';

enum RaftSwitchSize { sm, md }

/// Geometry shared by the public switch and its painter. Insets measure from
/// the track's outside edge to the thumb, including any track border.
@immutable
class RaftSwitchRecipe {
  const RaftSwitchRecipe({this.tokens, this.size = RaftSwitchSize.md});
  final RaftTokens? tokens;
  final RaftSwitchSize size;
  String get _size => size.name;
  double _value(String name, double fallback) =>
      tokens?.size(name, fallback: fallback) ?? fallback;
  Size get visualSize => Size(
    _value('size.switch.width.$_size', 50),
    _value('size.switch.height.$_size', 30),
  );
  double get thumbSize => _value('size.switch.thumb.$_size', 22);
  double get thumbInset => _value('space.switchInset', 4);
  double get travel => visualSize.width - thumbSize - 2 * thumbInset;
  double get borderWidth => _value('stroke.control', 1.5);
  bool get square => tokens?.option('switch.shape', or: 'pill') == 'square';
  bool get inkBorder =>
      tokens?.option('control.edge', or: 'inkBorder') != 'ring';
  BorderRadius get radius =>
      BorderRadius.circular(square ? 0 : visualSize.height / 2);
  Duration get slideDuration =>
      Duration(milliseconds: _value('motion.switchSlideMs', 220).round());
  Duration get colorDuration =>
      Duration(milliseconds: _value('motion.switchColorMs', 150).round());
  RaftSwitchSemanticTokens get semantics => RaftSwitchSemanticTokens(tokens!);
}

/// Existing colour roles of a ring or square switch (a57b9dab switch.dart).
/// The border and shape options describe paint, independently of pack identity.
@immutable
class RaftSwitchSemanticTokens {
  const RaftSwitchSemanticTokens(this.tokens);
  final RaftTokens tokens;
  bool get square => tokens.option('switch.shape', or: 'pill') == 'square';
  Color track({
    required bool value,
    bool disabled = false,
    bool hovered = false,
  }) {
    if (disabled) {
      return square
          ? tokens.colors['fill-muted']!
          : tokens.dark
          ? tokens.colors['layer-inset']!
          : tokens.panel;
    }
    if (value) {
      return hovered && !square
          ? tokens.colors['button-primary-hover']!
          : tokens.colors['primary-400']!;
    }
    if (square) {
      return hovered
          ? tokens.colors['primary-400']!.withValues(alpha: .3)
          : tokens.panel;
    }
    if (tokens.dark) return hovered ? tokens.panel : tokens.card;
    return tokens.strong.withValues(alpha: hovered ? .16 : .12);
  }

  Color thumb({required bool value, bool disabled = false}) {
    if (square) return tokens.colors[disabled ? 'line' : 'line-strong']!;
    if (disabled)
      return value
          ? tokens.components.switchThumbCheckedDisabled
          : tokens.components.switchThumbDisabled;
    return value
        ? tokens.components.switchThumbChecked
        : tokens.components.switchThumb;
  }
}
