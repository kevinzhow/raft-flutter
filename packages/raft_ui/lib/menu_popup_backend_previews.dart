import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';
import 'recipes.dart';

@RaftPreviews('Menu · action and typed choice', size: Size(480, 520))
Widget menuPopupBackendPreview() => const _MenuPreview();

class _MenuPreview extends StatefulWidget {
  const _MenuPreview();

  @override
  State<_MenuPreview> createState() => _MenuPreviewState();
}

class _MenuPreviewState extends State<_MenuPreview> {
  final trigger = FocusNode();
  final anchorKey = GlobalKey();
  final menu = MenuController();
  int selected = 0;

  @override
  void dispose() {
    trigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftMenuPanel(
            children: [
              RaftMenuItem(label: 'Documentation', onPressed: () {}),
              const RaftMenuItem(label: 'Unavailable action'),
            ],
          ),
          const SizedBox(height: 24),
          RaftPopoverAnchor(
            controller: menu,
            anchorKey: anchorKey,
            childFocusNode: trigger,
            builder: (context, controller, child) => RaftButton(
              key: anchorKey,
              label: 'Choose a language',
              focusNode: trigger,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
            popup: RaftMenuPopupBackend(
              anchorWidth: 280,
              maxHeight: 200,
              triggerFocus: trigger,
              semanticRole: SemanticsRole.list,
              itemSemanticRole: SemanticsRole.listItem,
              selectionSemantics: true,
              entries: [
                for (final (index, label) in [
                  'English',
                  '中文',
                  'Unavailable',
                  '日本語',
                ].indexed)
                  RaftMenuPopupEntry(
                    key: ValueKey(label),
                    label: label,
                    selected: index == selected,
                    enabled: index != 2,
                    indicator: const RaftIcon(RaftGlyph.check, size: 14),
                  ),
              ],
              resolveSlots: (state) {
                final recipe = RaftSelectRecipe.resolve(
                  theme: tokens.recipeTheme,
                  tokens: tokens.recipeTokens,
                  states: tokens.recipeStates(
                    hovered: state.hovered,
                    focusVisible: state.focusVisible,
                    disabled: state.disabled,
                    extra: [
                      if (state.selected) 'data-selected',
                      if (state.disabled) 'data-disabled',
                      if (state.highlighted) 'data-highlighted',
                      if (state.lastChild) 'last-child',
                    ],
                  ),
                );
                return RaftMenuPopupSlots(
                  content: recipe.content,
                  list: recipe.list,
                  item: recipe.item,
                  itemLeading: recipe.itemLeading,
                  itemText: recipe.itemText,
                  itemIndicator: recipe.itemIndicator,
                );
              },
              onActivate: (index) => setState(() {
                selected = index;
                menu.close();
              }),
              onDismiss: menu.close,
            ),
          ),
        ],
      ),
    );
  }
}
