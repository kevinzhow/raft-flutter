// Web v1.24 ThreadsInbox toolbar (ThreadsInbox.tsx:521-596): the Filter menu,
// the chip of the filter in effect, and Mark all read, in one 49px bar (44 with
// a mouse from 768). Not raft-ui's `ActivityInboxToolbar`, which Web does not
// mount. Every string comes in from the app.
import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'interaction.dart';
import 'picker_trigger_button.dart';
import 'raft/button.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/filter_chip.g.dart';
import 'recipes/recipe_runtime.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftDesktopMetrics;
import 'tooltip.dart' show RaftTooltip;

/// `ActivityFilterChoice`: the read filters, then the scopes.
enum RaftActivityFilterChoice {
  all(RaftGlyph.inbox),
  unread(RaftGlyph.messageSquareDot),
  mentions(RaftGlyph.atSign),
  pinned(RaftGlyph.pin),
  saved(RaftGlyph.bookmark),
  artifacts(RaftGlyph.artifact);

  const RaftActivityFilterChoice(this.glyph);
  final RaftGlyph glyph;
}

/// The bar's words, translated by the app.
@immutable
class RaftActivityFilterLabels {
  const RaftActivityFilterLabels({
    required this.filter,
    required this.menu,
    required this.clear,
    required this.markAllRead,
    required this.markAllReadTooltip,
    required this.choices,
  });

  /// The trigger ("Filter") and the menu's accessible name ("Filter inbox").
  final String filter, menu;

  /// The chip's × ("Clear filter").
  final String clear;

  /// Mark all read: the label, and the tooltip it also has icon-only.
  final String markAllRead, markAllReadTooltip;

  /// The name of each choice (menu item and chip).
  final Map<RaftActivityFilterChoice, String> choices;
}

class RaftActivityFilterBar extends StatefulWidget {
  const RaftActivityFilterBar({
    super.key,
    required this.choice,
    required this.onChoice,
    required this.labels,
    this.showMarkAllRead = false,
    this.onMarkAllRead,
  });

  final RaftActivityFilterChoice choice;
  final ValueChanged<RaftActivityFilterChoice> onChoice;
  final RaftActivityFilterLabels labels;

  /// Web `showMarkAllRead`: only while something is unread.
  final bool showMarkAllRead;
  final VoidCallback? onMarkAllRead;

  /// The bar under a touch screen or below 768 (`h-[calc(--spacing(12)+1px)]`).
  static const double compactHeight = 49;

  /// `@max-[30rem]`: the bar's own width at which Mark all read is its icon.
  static const double iconOnlyWidth = 480;

  /// `px-(--column-margin)`: 20 on touch and below 768, 16 with a mouse from 768.
  static const double columnMargin = 20, desktopColumnMargin = 16;

  @override
  State<RaftActivityFilterBar> createState() => _RaftActivityFilterBarState();
}

class _RaftActivityFilterBarState extends State<RaftActivityFilterBar> {
  final RaftMenuController _menu = RaftMenuController();
  FocusNode? _filterButton;

  @override
  void initState() {
    super.initState();
    _menu.addListener(_menuChanged);
  }

  @override
  void dispose() {
    _menu.removeListener(_menuChanged);
    _menu.dispose();
    super.dispose();
  }

  void _menuChanged() => setState(() {});

  void _clear() {
    widget.onChoice(RaftActivityFilterChoice.all);
    // The chip and its x go away: focus stays in the bar, on Filter.
    _filterButton?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final labels = widget.labels;
    final choice = widget.choice;
    final minHeight = t.desktop
        ? RaftDesktopMetrics.headerHeight
        : RaftActivityFilterBar.compactHeight;
    final open = _menu.isOpen;
    // `--column-margin`: 16 with a mouse from 768, else 20 (measured on Web).
    final margin = t.desktop
        ? RaftActivityFilterBar.desktopColumnMargin
        : RaftActivityFilterBar.columnMargin;
    return Container(
      key: const ValueKey('activity-filter-bar'),
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.symmetric(horizontal: margin),
      decoration: BoxDecoration(
        color: t.canvas,
        border: Border(
          bottom: BorderSide(color: t.colors['line-seam']!, width: t.border),
        ),
      ),
      child: Center(
        heightFactor: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconOnly =
                constraints.maxWidth + 2 * margin <=
                RaftActivityFilterBar.iconOnlyWidth;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 16,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      RaftDropdownMenu(
                        label: labels.menu,
                        kind: RaftMenuKind.dropdownMenu,
                        controller: _menu,
                        entries: [
                          for (final c in RaftActivityFilterChoice.values) ...[
                            if (c == RaftActivityFilterChoice.pinned)
                              const RaftMenuEntry.separator(),
                            RaftMenuEntry(
                              label: labels.choices[c] ?? c.name,
                              glyph: c.glyph,
                              checked: c == choice,
                              onPressed: () {
                                if (c != choice) widget.onChoice(c);
                              },
                            ),
                          ],
                        ],
                        triggerBuilder: (context, focusNode, onPressed) {
                          _filterButton = focusNode;
                          return RaftPickerTriggerButton(
                            key: const ValueKey('inbox-filter-button'),
                            label: labels.filter,
                            glyph: RaftGlyph.listFilter,
                            focusNode: focusNode,
                            onPressed: onPressed,
                            // `data-popup-open:bg-fill-medium`.
                            restyle: open
                                ? (style) {
                                    final fill = t.colors['fill-medium']!;
                                    return style.copyWith(
                                      properties: {
                                        ...style.properties,
                                        'background-color': CssColor(
                                          fill.toARGB32(),
                                          null,
                                          fill,
                                        ),
                                      },
                                    );
                                  }
                                : null,
                          );
                        },
                      ),
                      if (choice != RaftActivityFilterChoice.all)
                        Flexible(
                          child: _FilterChip(
                            key: const ValueKey('inbox-filter-chip'),
                            glyph: choice.glyph,
                            label: labels.choices[choice] ?? choice.name,
                            clearLabel: labels.clear,
                            onClear: _clear,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.showMarkAllRead)
                  _MarkAllRead(
                    iconOnly: iconOnly,
                    label: labels.markAllRead,
                    tooltip: labels.markAllReadTooltip,
                    onPressed: widget.onMarkAllRead,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// raft-ui `FilterChip` + `FilterChipLabel` + `FilterChipRemove`.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.glyph,
    required this.label,
    required this.clearLabel,
    required this.onClear,
  });
  final RaftGlyph glyph;
  final String label, clearLabel;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final style = RaftFilterChipRecipe.resolve(
      states: t.recipeStates(responsive: true),
      tokens: rt,
    );
    final iconSize =
        style.root.target('& > svg:not([class*=\'size-\'])')?.width ?? 14;
    return RaftRecipeBox(
      style: style.root,
      tokens: rt,
      controlLabel: true,
      growWithText: true,
      child: Builder(
        builder: (context) {
          final ink = DefaultTextStyle.of(context).style.color;
          return Row(
            mainAxisSize: MainAxisSize.min,
            spacing: style.root.columnGap ?? 6,
            children: [
              RaftIcon(glyph, size: iconSize, color: ink),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              RaftInteractive(
                key: const ValueKey('inbox-filter-clear'),
                onPressed: onClear,
                semanticLabel: clearLabel,
                builder: (context, state) {
                  final remove = RaftFilterChipRecipe.resolve(
                    states: t.recipeStates(
                      responsive: true,
                      hovered: state.hovered,
                      pressed: state.pressed,
                      focusVisible: state.focusVisible,
                    ),
                    tokens: rt,
                  ).remove;
                  return ExcludeSemantics(
                    child: RaftRecipeBox(
                      style: remove,
                      tokens: rt,
                      alignment: Alignment.center,
                      child: Builder(
                        builder: (context) => RaftIcon(
                          RaftGlyph.x,
                          size: remove.target('& > svg')?.width ?? 14,
                          color: DefaultTextStyle.of(context).style.color,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The ghost Mark all read: its words end on the column margin (its padding
/// hangs outward); a 32px icon under 30rem, a 28px bar button (radius 6) with a
/// mouse from 768.
class _MarkAllRead extends StatelessWidget {
  const _MarkAllRead({
    required this.iconOnly,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });
  final bool iconOnly;
  final String label, tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final bar = t.desktop;
    const barSize = RaftDesktopMetrics.barButtonSize;
    // `-mr-[calc(--spacing(3)+1.5px)]` (13.5), bar 11.5, icon: `-mr-2` (8), bar 6.
    final hang = iconOnly ? (bar ? 6.0 : 8.0) : (bar ? 11.5 : 13.5);
    Widget button = RaftButton(
      key: const ValueKey('inbox-mark-all-read'),
      tone: RaftButtonRecipeVariant.ghost,
      size: iconOnly ? RaftButtonRecipeSize.iconMd : RaftButtonRecipeSize.md,
      label: iconOnly ? '' : label,
      glyph: iconOnly ? RaftGlyph.checkCheck : null,
      semanticLabel: label,
      onPressed: onPressed,
      physicalHeight: bar ? barSize : null,
      visualWidth: bar && iconOnly ? barSize : null,
      padding: bar && !iconOnly
          ? const EdgeInsets.symmetric(horizontal: 10)
          : null,
      styleBuilder: !bar
          ? null
          : (context, state, style) => style.copyWith(
              properties: {
                ...style.properties,
                for (final corner in [
                  'top-left',
                  'top-right',
                  'bottom-left',
                  'bottom-right',
                ])
                  'border-$corner-radius': const CssNum(
                    RaftDesktopMetrics.barButtonRadius,
                    'px',
                  ),
              },
            ),
    );
    button = RaftTooltip(
      message: tooltip,
      enabled: !RaftInteraction.of(context).touch,
      child: button,
    );
    return Transform.translate(
      offset: Offset(
        Directionality.of(context) == TextDirection.ltr ? hang : -hang,
        0,
      ),
      child: button,
    );
  }
}
