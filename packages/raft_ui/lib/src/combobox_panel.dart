import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/combobox.g.dart';
import 'theme.dart';

/// Searchable, single-selection popup composed from the public Combobox slots.
/// The host owns anchoring, current options, permission checks and dismissal.
class RaftComboboxPanel extends StatefulWidget {
  const RaftComboboxPanel({
    super.key,
    required this.label,
    required this.options,
    required this.onSelected,
    required this.onDismiss,
    this.glyph,
    this.enabled = true,
  });
  final String label;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;
  final RaftGlyph? glyph;
  final bool enabled;
  @override
  State<RaftComboboxPanel> createState() => _RaftComboboxPanelState();
}

class _RaftComboboxPanelState extends State<RaftComboboxPanel> {
  final query = TextEditingController();
  final inputFocus = FocusNode();
  int highlighted = -1;
  final optionKeys = <String, GlobalKey>{};
  @override
  void initState() {
    super.initState();
    inputFocus.addListener(focusChanged);
  }

  void focusChanged() {
    if (mounted) setState(() {});
  }

  void choose(String id) {
    if (mounted && widget.enabled && widget.options.containsKey(id)) {
      widget.onSelected(id);
    }
  }

  @override
  void didUpdateWidget(RaftComboboxPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options) highlighted = -1;
  }

  @override
  void dispose() {
    query.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get entries => widget.options.entries
      .where(
        (entry) =>
            entry.value.toLowerCase().contains(query.text.trim().toLowerCase()),
      )
      .toList();

  KeyEventResult navigate(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || !widget.enabled) {
      return KeyEventResult.ignored;
    }
    final choices = entries;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
    } else if (choices.isNotEmpty &&
        (event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowUp)) {
      setState(() {
        final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
        highlighted = highlighted < 0
            ? (down ? 0 : choices.length - 1)
            : (highlighted + (down ? 1 : -1)) % choices.length;
      });
      final id = choices[highlighted].key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = optionKeys[id]?.currentContext;
        if (mounted && target != null) Scrollable.ensureVisible(target);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter &&
        highlighted >= 0 &&
        highlighted < choices.length) {
      choose(choices[highlighted].key);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final r = RaftComboboxRecipe.resolve(
      theme: t.recipeTheme,
      inputOwner: RaftComboboxRecipeInputOwner.group,
      states: t.recipeStates(focusVisible: inputFocus.hasFocus),
      tokens: tokens,
    );
    final base = RaftTypography.body(t, size: 14, line: 20);
    final input = r.input.text(tokens, base: base);
    final choices = entries;
    return DefaultTextStyle(
      style: base,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: navigate,
        child: RaftRecipeBox(
          style: r.content,
          tokens: tokens,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftRecipeBox(
                style: r.header,
                tokens: tokens,
                child: Text(
                  r.label.textTransform == 'uppercase'
                      ? raftText(context, widget.label).toUpperCase()
                      : raftText(context, widget.label),
                  style: r.label.text(tokens, base: base),
                ),
              ),
              if (r.separator.display != 'none')
                RaftRecipeBox(style: r.separator, tokens: tokens),
              RaftRecipeBox(
                style: r.inputGroup,
                tokens: tokens,
                child: RaftRecipeBox(
                  style: r.input,
                  tokens: tokens,
                  child: TextField(
                    autofillHints: null,
                    controller: query,
                    focusNode: inputFocus,
                    enabled: widget.enabled,
                    style: input,
                    onChanged: (_) => setState(() => highlighted = -1),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: raftText(context, 'Search...'),
                      hintStyle: input.copyWith(
                        color: t.brutal
                            ? (input.color ?? t.strong).withValues(alpha: .5)
                            : t.colors['foreground-placeholder']!.withValues(
                                alpha: .7,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: RaftRecipeBox(
                  style: r.list,
                  tokens: tokens,
                  child: SingleChildScrollView(
                    primary: false,
                    child: Semantics(
                      role: SemanticsRole.list,
                      explicitChildNodes: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < choices.length; i++) ...[
                            if (i > 0 && (r.list.rowGap ?? 0) > 0)
                              SizedBox(height: r.list.rowGap),
                            RaftInteractive(
                              key: optionKeys.putIfAbsent(
                                choices[i].key,
                                GlobalKey.new,
                              ),
                              semanticRole: SemanticsRole.listItem,
                              selected: false,
                              semanticLabel: choices[i].value,
                              onPressed: widget.enabled
                                  ? () => choose(choices[i].key)
                                  : null,
                              builder: (context, state) {
                                final item = RaftComboboxRecipe.resolve(
                                  theme: t.recipeTheme,
                                  states: t.recipeStates(
                                    hovered: state.hovered,
                                    extra: {
                                      if (i == highlighted) 'data-highlighted',
                                      if (i == choices.length - 1) 'last-child',
                                    },
                                  ),
                                  tokens: tokens,
                                ).item;
                                return RaftRecipeBox(
                                  style: item,
                                  tokens: tokens,
                                  child: Row(
                                    children: [
                                      if (widget.glyph != null)
                                        SizedBox.square(
                                          dimension: 20,
                                          child: Center(
                                            child: RaftIcon(
                                              widget.glyph!,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                      if (widget.glyph != null)
                                        SizedBox(width: item.columnGap ?? 8),
                                      Expanded(
                                        child: Text(
                                          choices[i].value,
                                          textAlign: widget.glyph == null
                                              ? TextAlign.start
                                              : TextAlign.end,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                          if (choices.isEmpty)
                            RaftRecipeBox(
                              style: r.empty,
                              tokens: tokens,
                              child: Text(
                                raftText(context, 'No results'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
