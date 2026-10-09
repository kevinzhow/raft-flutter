import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import 'previews.dart';

/// The actual explicit caller from VisualTestingCases.tsx3105–3138. This is
/// separate from SelectionPopover.tsx117's theme-dependent default surface.
RaftSlotStyle selectionPopoverCallerSurface(RaftTokens tokens) {
  final card = RaftCardRecipe.resolve(
    theme: tokens.recipeTheme,
    states: tokens.recipeStates(),
    tokens: tokens.recipeTokens,
  ).root;
  return RaftSlotStyle(
    {
      ...card.properties,
      'background-color': const CssColor(0xffffffff),
      for (final side in ['top', 'right', 'bottom', 'left']) ...{
        'border-$side-width': const CssNum(2, 'px'),
        if (!tokens.dark) 'border-$side-color': const CssColor(0xff000000),
      },
    },
    card.targets,
    [
      ...card.classes.where(
        (name) => !const {
          'overflow-hidden',
          'border-2',
          'border-[0.5px]',
          'border-black',
          'border-line-muted',
          'border-line-strong',
          'bg-white',
          'bg-layer-panel',
        }.contains(name),
      ),
      'w-full',
      'overflow-hidden',
      'border-2',
      'border-black',
      'bg-white',
      'shadow-brutal',
    ],
    tokens.recipeTokens,
  );
}

@RaftPreviews(
  'Selection popover · default and explicit caller',
  size: Size(410, 420),
)
Widget selectionPopoverPreview() => const SelectionPopoverPreview();

/// Interactive popup owner: outside press and Escape close the layer. Source
/// SelectionPopover itself only marks the dismiss layer; its parent owns close.
class SelectionPopoverPreview extends StatefulWidget {
  const SelectionPopoverPreview({super.key});
  @override
  State<SelectionPopoverPreview> createState() =>
      _SelectionPopoverPreviewState();
}

class _SelectionPopoverPreviewState extends State<SelectionPopoverPreview> {
  final search = TextEditingController();
  final trigger = FocusNode();
  bool open = false, caller = false, selected = false;
  String result = 'Choose a channel';

  @override
  void dispose() {
    search.dispose();
    trigger.dispose();
    super.dispose();
  }

  void close() {
    if (!open) return;
    setState(() => open = false);
    trigger.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Focus(
        onKeyEvent: (_, event) {
          if (open &&
              event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            close();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RaftButton(
                  label: 'Choose channel',
                  focusNode: trigger,
                  onPressed: () => setState(() => open = !open),
                ),
                const SizedBox(width: 12),
                RaftButton(
                  label: caller ? 'Use default' : 'Use caller surface',
                  onPressed: () => setState(() => caller = !caller),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(result),
            const SizedBox(height: 8),
            if (open)
              TapRegion(
                onTapOutside: (_) => close(),
                child: RaftSelectionPopover(
                  title: 'Channels',
                  width: 310,
                  surfaceStyle: caller
                      ? selectionPopoverCallerSurface(tokens)
                      : null,
                  searchController: search,
                  onSearchChanged: (_) => setState(() {}),
                  searchPlaceholder: 'Search channels',
                  onClear: () => setState(() {
                    selected = false;
                    search.clear();
                  }),
                  options: [
                    if ('design'.contains(search.text.toLowerCase()))
                      RaftSelectionOption(
                        label: 'design',
                        checked: selected,
                        reserveLeadingSlot: true,
                        onTap: () => setState(() {
                          selected = !selected;
                          result = selected
                              ? 'design selected'
                              : 'design cleared';
                        }),
                      ),
                    RaftSelectionOption(
                      label: 'archived channel',
                      checked: false,
                      disabled: true,
                      onTap: () {},
                    ),
                    RaftSelectionOption(
                      label: 'No channel',
                      checked: false,
                      italic: true,
                      onTap: () {
                        setState(() => result = 'No channel selected');
                        close();
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
