import 'text_selection_toolbar.dart';

import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/combobox.g.dart';
import 'theme.dart';

/// Drives a [RaftComboboxPanel] whose search input lives elsewhere (the field
/// itself, like Web's `RuntimeChoiceCombobox`): the host owns [query] and
/// forwards the keys its input receives to [handleKey].
class RaftComboboxController {
  final TextEditingController query = TextEditingController();
  KeyEventResult Function(KeyEvent event)? _handler;

  /// Arrow keys move the highlight over enabled rows, Enter chooses it and
  /// Escape dismisses; anything else is ignored.
  KeyEventResult handleKey(KeyEvent event) =>
      _handler?.call(event) ?? KeyEventResult.ignored;

  void dispose() => query.dispose();
}

/// One row of a [RaftComboboxPanel.items] panel.
class RaftComboboxItem {
  const RaftComboboxItem(
    this.id,
    this.label, {
    this.description,
    this.hint,
    this.keywords,
    this.group,
    this.enabled = true,
  });

  /// What [RaftComboboxPanel.onSelected] receives (the option's value).
  final String id;
  final String label;

  /// Second line that is part of the option's name (for example "Not in the
  /// current list"). Searchable.
  final String? description;

  /// Second line that only helps the eye (the stored id of a named option).
  /// Shown when there is no [description]; not part of the name.
  final String? hint;

  /// Extra searchable text (the option's stored value).
  final String? keywords;

  /// Heading above the first row of each run of equal groups.
  final String? group;
  final bool enabled;
}

/// Case-insensitive match on what a person may remember: the name, the stored
/// id, the group or the description. Each space-separated word must appear in
/// one of them, so "gpt sol" finds "GPT 6.1 Sol".
bool raftComboboxItemMatches(RaftComboboxItem item, String query) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final fields = [
    item.label,
    item.keywords ?? item.id,
    item.group ?? '',
    item.description ?? '',
  ].map((text) => text.toLowerCase()).toList();
  return words.every((word) => fields.any((text) => text.contains(word)));
}

/// Searchable, single-selection popup composed from the public Combobox slots.
/// The host owns anchoring, current options, permission checks and dismissal.
///
/// The default constructor lists plain `id -> label` options matched by a
/// substring of the label. [RaftComboboxPanel.items] lists grouped rows with
/// descriptions and disabled rows, matched word by word
/// ([raftComboboxItemMatches]), and can offer the typed text as a custom value.
class RaftComboboxPanel extends StatefulWidget {
  const RaftComboboxPanel({
    super.key,
    required this.label,
    required this.options,
    required this.onSelected,
    required this.onDismiss,
    this.glyph,
    this.enabled = true,
  }) : items = null,
       emptyLabel = 'No results',
       customLabel = null,
       onCustom = null,
       currentId = null,
       autofocus = false,
       controller = null;

  const RaftComboboxPanel.items({
    super.key,
    required this.label,
    required List<RaftComboboxItem> this.items,
    required this.onSelected,
    required this.onDismiss,
    this.customLabel,
    this.onCustom,
    this.currentId,
    this.autofocus = false,
    this.enabled = true,
    this.controller,
    this.emptyLabel = 'No results',
  }) : options = const {},
       glyph = null;

  final String label;

  /// The catalog text shown when no row matches the typed query.
  final String emptyLabel;
  final Map<String, String> options;
  final List<RaftComboboxItem>? items;
  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;
  final RaftGlyph? glyph;
  final bool enabled;

  /// With [onCustom]: a typed text that matches no row is offered as one more
  /// row labelled `customLabel(typed)`; choosing it calls `onCustom(typed)`.
  final String Function(String typed)? customLabel;
  final ValueChanged<String>? onCustom;

  /// The row that is the field's current value (not offered as custom text).
  final String? currentId;
  final bool autofocus;

  /// The search input is the host's: no header and no search box, only the
  /// rows, filtered by `controller.query`.
  final RaftComboboxController? controller;
  @override
  State<RaftComboboxPanel> createState() => _RaftComboboxPanelState();
}

class _RaftComboboxPanelState extends State<RaftComboboxPanel> {
  late final ownQuery = TextEditingController();
  TextEditingController get query => widget.controller?.query ?? ownQuery;
  final inputFocus = FocusNode();
  int highlighted = -1;
  final optionKeys = <String, GlobalKey>{};
  @override
  void initState() {
    super.initState();
    inputFocus.addListener(focusChanged);
    widget.controller
      ?..query.addListener(queryChanged)
      .._handler = (event) => navigate(inputFocus, event);
  }

  void queryChanged() {
    if (mounted) setState(() => highlighted = -1);
  }

  void focusChanged() {
    if (mounted) setState(() {});
  }

  static const _customPrefix = '\u0000custom:';

  List<RaftComboboxItem> get _all =>
      widget.items ??
      [
        for (final entry in widget.options.entries)
          RaftComboboxItem(entry.key, entry.value),
      ];

  void choose(String id) {
    if (!mounted || !widget.enabled) return;
    if (id.startsWith(_customPrefix)) {
      if (_rows.any((row) => row.id == id)) {
        widget.onCustom?.call(id.substring(_customPrefix.length));
      }
      return;
    }
    if (_all.any((item) => item.id == id && item.enabled)) {
      widget.onSelected(id);
    }
  }

  @override
  void didUpdateWidget(RaftComboboxPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options ||
        oldWidget.items != widget.items) {
      highlighted = -1;
    }
  }

  @override
  void dispose() {
    widget.controller
      ?..query.removeListener(queryChanged)
      .._handler = null;
    ownQuery.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  /// The rows the query leaves, then the "use what I typed" row.
  List<RaftComboboxItem> get _rows {
    final text = query.text.trim();
    final all = _all;
    final matches = widget.items == null
        ? all
              .where(
                (item) => item.label.toLowerCase().contains(text.toLowerCase()),
              )
              .toList()
        : all.where((item) => raftComboboxItemMatches(item, text)).toList();
    final offerCustom =
        widget.customLabel != null &&
        widget.onCustom != null &&
        text.isNotEmpty &&
        text != widget.currentId &&
        !all.any((item) => item.id == text);
    return [
      ...matches,
      if (offerCustom)
        RaftComboboxItem('$_customPrefix$text', widget.customLabel!(text)),
    ];
  }

  KeyEventResult navigate(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || !widget.enabled) {
      return KeyEventResult.ignored;
    }
    final choices = _rows;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
    } else if (choices.any((row) => row.enabled) &&
        (event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowUp)) {
      setState(() {
        final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
        var next = highlighted < 0
            ? (down ? 0 : choices.length - 1)
            : (highlighted + (down ? 1 : -1)) % choices.length;
        // Disabled rows are listed but never highlighted.
        while (!choices[next].enabled) {
          next = (next + (down ? 1 : -1)) % choices.length;
        }
        highlighted = next;
      });
      final id = choices[highlighted].id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = optionKeys[id]?.currentContext;
        if (mounted && target != null) Scrollable.ensureVisible(target);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter &&
        highlighted >= 0 &&
        highlighted < choices.length &&
        choices[highlighted].enabled) {
      choose(choices[highlighted].id);
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
    final choices = _rows;
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
              if (widget.controller == null)
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
              if (widget.controller == null && r.separator.display != 'none')
                RaftRecipeBox(style: r.separator, tokens: tokens),
              if (widget.controller == null)
                RaftRecipeBox(
                  style: r.inputGroup,
                  tokens: tokens,
                  child: RaftRecipeBox(
                    style: r.input,
                    tokens: tokens,
                    child: TextField(
                      contextMenuBuilder: RaftTextSelectionToolbar.editableText,
                      autofillHints: null,
                      controller: query,
                      focusNode: inputFocus,
                      autofocus: widget.autofocus,
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
                            if (choices[i].group != null &&
                                (i == 0 ||
                                    choices[i - 1].group != choices[i].group))
                              RaftComboboxGroupLabel(choices[i].group!)
                            else if (i > 0 && (r.list.rowGap ?? 0) > 0)
                              SizedBox(height: r.list.rowGap),
                            RaftInteractive(
                              key: optionKeys.putIfAbsent(
                                choices[i].id,
                                GlobalKey.new,
                              ),
                              semanticRole: SemanticsRole.listItem,
                              selected: choices[i].id == widget.currentId,
                              semanticLabel: [
                                choices[i].label,
                                ?choices[i].description,
                              ].join(', '),
                              onPressed: widget.enabled && choices[i].enabled
                                  ? () => choose(choices[i].id)
                                  : null,
                              builder: (context, state) {
                                final item = RaftComboboxRecipe.resolve(
                                  theme: t.recipeTheme,
                                  states: t.recipeStates(
                                    hovered:
                                        state.hovered && choices[i].enabled,
                                    extra: {
                                      if (i == highlighted) 'data-highlighted',
                                      if (i == choices.length - 1) 'last-child',
                                    },
                                  ),
                                  tokens: tokens,
                                ).item;
                                final second =
                                    choices[i].description ??
                                    (choices[i].hint != choices[i].label
                                        ? choices[i].hint
                                        : null);
                                final row = RaftRecipeBox(
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
                                        child: second == null
                                            ? Text(
                                                choices[i].label,
                                                textAlign: widget.glyph == null
                                                    ? TextAlign.start
                                                    : TextAlign.end,
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    choices[i].label,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    second,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      height: 16 / 12,
                                                      color:
                                                          t.colors['foreground-muted'] ??
                                                          t.muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ],
                                  ),
                                );
                                return choices[i].enabled
                                    ? row
                                    : Opacity(opacity: .5, child: row);
                              },
                            ),
                          ],
                          if (choices.isEmpty)
                            RaftRecipeBox(
                              style: r.empty,
                              tokens: tokens,
                              child: Text(
                                raftText(context, widget.emptyLabel),
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

/// `ComboboxGroupLabel`: the heading above a group of options (Web groups the
/// runtime form's saved and direct providers this way). Not an option: it takes
/// no focus and no taps.
class RaftComboboxGroupLabel extends StatelessWidget {
  const RaftComboboxGroupLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final r = RaftComboboxRecipe.resolve(
      theme: t.recipeTheme,
      inputOwner: RaftComboboxRecipeInputOwner.group,
      states: t.recipeStates(),
      tokens: tokens,
    );
    final base = RaftTypography.body(t, size: 14, line: 20);
    return Semantics(
      header: true,
      child: RaftRecipeBox(
        style: r.groupLabel,
        tokens: tokens,
        child: Text(
          raftText(context, label),
          style: r.groupLabel.text(tokens, base: base),
        ),
      ),
    );
  }
}
