import 'raft/button.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'control_typography.dart';
import 'recipe_surface.dart';
import 'recipes/message_text_selection_toolbar.g.dart';
import 'recipes/recipe_runtime.dart';
import 'theme.dart';

/// Raft's Android selection menu skin, using Flutter's original toolbar layout.
///
/// Flutter owns anchoring, row measurement, overflow, back navigation and button
/// padding. The caller's editing actions and platform extension items are kept.
class RaftTextSelectionToolbar extends StatelessWidget {
  const RaftTextSelectionToolbar.buttonItems({
    super.key,
    required this.anchors,
    required this.buttonItems,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;

  /// Shared builder for fields and [SelectableText], retaining supported native
  /// system menus on other platforms.
  static Widget editableText(BuildContext context, EditableTextState state) =>
      SystemContextMenu.isSupportedByField(state)
      ? SystemContextMenu.editableText(editableTextState: state)
      : RaftTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: state.contextMenuButtonItems,
        );

  static Widget selectableRegion(
    BuildContext context,
    SelectableRegionState state,
  ) => RaftTextSelectionToolbar.buttonItems(
    anchors: state.contextMenuAnchors,
    buttonItems: state.contextMenuButtonItems,
  );

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.android) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: anchors,
        buttonItems: buttonItems,
      );
    }
    if (buttonItems.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    RaftMessageTextSelectionToolbarRecipeStyle recipe(
      Set<WidgetState> states,
    ) => RaftMessageTextSelectionToolbarRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(
        hovered: states.contains(WidgetState.hovered),
        pressed: states.contains(WidgetState.pressed),
        focusVisible: states.contains(WidgetState.focused),
        disabled: states.contains(WidgetState.disabled),
      ),
      tokens: rt,
    );
    final skin = recipe({});
    // Selection overlays may inherit a link/code/fallback style from the text.
    final base = skin.toolbar.text(
      rt,
      base: theme.textTheme.labelLarge!.copyWith(
        decoration: TextDecoration.none,
      ),
    );
    TextStyle labelStyle(Set<WidgetState> states) => RaftControlTypography.of(
      context,
      recipe(states).button.text(rt, base: base),
    );
    final labels = [
      for (final item in buttonItems)
        AdaptiveTextSelectionToolbar.getButtonLabel(context, item),
    ];
    final scale = _toolbarScale(context, labels, labelStyle({}));
    Widget toolbar(TextSelectionToolbarAnchors localAnchors) => Theme(
      data: theme.copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(labelStyle({}).color),
          ),
        ),
      ),
      child: TextSelectionToolbar(
        anchorAbove: localAnchors.primaryAnchor,
        anchorBelow: localAnchors.secondaryAnchor ?? localAnchors.primaryAnchor,
        toolbarBuilder: (context, child) => RaftRecipeBox(
          style: skin.toolbar,
          tokens: rt,
          applyText: false,
          clip: true,
          child: Material(type: MaterialType.transparency, child: child),
        ),
        children: [
          for (var i = 0; i < buttonItems.length; i++)
            RaftButton.text(
              focusOnPointer: false,
              padding: TextSelectionToolbarTextButton.getPadding(
                i,
                buttonItems.length,
              ).resolve(Directionality.of(context)),
              styleBuilder: (context, state, root) {
                final states = <WidgetState>{
                  if (state.hovered) WidgetState.hovered,
                  if (state.pressed) WidgetState.pressed,
                  if (state.focusVisible) WidgetState.focused,
                  if (!state.enabled) WidgetState.disabled,
                };
                final button = recipe(states).button;
                final text = labelStyle(states);
                return button.copyWith(
                  properties: {
                    ...button.properties,
                    'font-family': CssString(text.fontFamily!),
                    'font-size': CssNum(text.fontSize!, 'px'),
                    if (text.height != null)
                      'line-height': CssNum(text.height!),
                    if (text.fontWeight != null)
                      'font-weight': CssNum(text.fontWeight!.value.toDouble()),
                  },
                );
              },
              onPressed: buttonItems[i].onPressed,
              legacyStyle: ButtonStyle(
                // The same geometry as TextSelectionToolbarTextButton.
                minimumSize: const WidgetStatePropertyAll(
                  Size(kMinInteractiveDimension, kMinInteractiveDimension),
                ),
                padding: WidgetStatePropertyAll(
                  TextSelectionToolbarTextButton.getPadding(
                    i,
                    buttonItems.length,
                  ),
                ),
                alignment: AlignmentDirectional.centerStart,
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: skin.button.borderRadius ?? BorderRadius.zero,
                  ),
                ),
                textStyle: WidgetStateProperty.resolveWith(labelStyle),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? theme.disabledColor
                      : labelStyle(states).color,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      recipe(states).button.backgroundColor?.resolve(rt),
                ),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
              child: Text(labels[i]),
            ),
        ],
      ),
    );
    if (scale == 1) return toolbar(anchors);
    // Material's closed row is fixed at 44dp. At exceptional accessibility
    // sizes, scale its coordinate space and inversely scale its text so the
    // actual glyph size is unchanged. The SDK still owns every layout decision.
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final size = constraints.biggest / scale;
        return OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: size.width,
          maxWidth: size.width,
          minHeight: size.height,
          maxHeight: size.height,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: MediaQuery(
              data: media.copyWith(
                size: size,
                padding: media.padding / scale,
                viewPadding: media.viewPadding / scale,
                viewInsets: media.viewInsets / scale,
                textScaler: _ToolbarTextScaler(media.textScaler, scale),
              ),
              child: toolbar(
                TextSelectionToolbarAnchors(
                  primaryAnchor: anchors.primaryAnchor / scale,
                  secondaryAnchor: anchors.secondaryAnchor == null
                      ? null
                      : anchors.secondaryAnchor! / scale,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

double _toolbarScale(
  BuildContext context,
  List<String> labels,
  TextStyle style,
) {
  var height = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
      maxLines: 1,
    )..layout();
    height = math.max(height, painter.height);
    painter.dispose();
  }
  // Flutter 3.47.6 TextSelectionToolbar's closed row height.
  return math.max(1, height / 44);
}

class _ToolbarTextScaler extends TextScaler {
  const _ToolbarTextScaler(this.original, this.viewportScale);
  final TextScaler original;
  final double viewportScale;
  @override
  double scale(double fontSize) => original.scale(fontSize) / viewportScale;
  // Required framework compatibility estimate; rendering only uses scale().
  @override
  double get textScaleFactor => scale(17) / 17;
}
