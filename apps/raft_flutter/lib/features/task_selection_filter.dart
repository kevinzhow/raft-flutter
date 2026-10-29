import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// Product anchoring for source SelectionPopover. Shared recipes own its paint;
/// the resource page owns the authority fence and immediate selection updates.
class TaskSelectionFilter extends StatefulWidget {
  const TaskSelectionFilter({
    super.key,
    required this.field,
    required this.options,
    required this.selection,
    required this.valid,
    required this.onToggle,
    required this.onClear,
    required this.onController,
    this.aliases = const {},
    this.beforeOpen,
    this.tooltip,
    this.label,
    this.glyph,
    this.closeOnSelect = false,
    this.picker = false,
    this.combobox = false,
  });

  /// Search filters use PickerTriggerButton; task filters an sm outline
  /// Button.
  final bool picker;

  /// MessageSearchPage's channel filter uses the public Combobox composition.
  final bool combobox;
  final String field;
  final String? tooltip, label;
  final RaftGlyph? glyph;
  final bool closeOnSelect;
  final Map<String, String> options, aliases;
  final Set<String> selection;
  final bool Function() valid;
  final void Function(String) onToggle;
  final VoidCallback onClear;
  final void Function(MenuController)? beforeOpen;
  final void Function(MenuController, bool) onController;
  @override
  State<TaskSelectionFilter> createState() => _TaskSelectionFilterState();
}

class _TaskSelectionFilterState extends State<TaskSelectionFilter> {
  final menu = MenuController();
  final search = TextEditingController();
  final anchorFocus = FocusNode();
  final triggerKey = GlobalKey();
  double horizontalOffset = 0;
  String needle = '';
  @override
  void initState() {
    super.initState();
    widget.onController(menu, true);
  }

  @override
  void dispose() {
    widget.onController(menu, false);
    search.dispose();
    anchorFocus.dispose();
    super.dispose();
  }

  bool get acceptsInteraction => mounted && menu.isOpen && widget.valid();
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final pickerHeight = widget.picker ? 28.0 : RaftMetrics.buttonMd;
    final width = math.min(220.0, MediaQuery.sizeOf(context).width - 24);
    final entries = widget.options.entries
        .where(
          (entry) =>
              entry.value.toLowerCase().contains(needle) ||
              widget.aliases[entry.key]?.toLowerCase().contains(needle) == true,
        )
        .toList();
    return MenuAnchor(
      controller: menu,
      childFocusNode: anchorFocus,
      consumeOutsideTap: false,
      clipBehavior: Clip.none,
      alignmentOffset: Offset(horizontalOffset, 4),
      onOpen: () {
        widget.beforeOpen?.call(menu);
        search.clear();
        final box = triggerKey.currentContext?.findRenderObject();
        setState(() {
          needle = '';
          if (widget.combobox && box is RenderBox) {
            final left = box.localToGlobal(Offset.zero).dx;
            horizontalOffset = left + width > MediaQuery.sizeOf(context).width
                ? box.size.width - width
                : 0;
          }
        });
      },
      style: const MenuStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
      ),
      menuChildren: [
        if (widget.combobox)
          SizedBox(
            width: width,
            child: RaftComboboxPanel(
              label: 'Channels',
              options: widget.options,
              glyph: RaftGlyph.hash,
              enabled: widget.valid(),
              onDismiss: menu.close,
              onSelected: (id) {
                if (!acceptsInteraction || !widget.options.containsKey(id)) {
                  return;
                }
                widget.onToggle(id);
                menu.close();
              },
            ),
          )
        else
          RaftMenuPanel(
            width: width,
            kind: RaftMenuKind.selectionPopover,
            onDismiss: menu.close,
            children: [
              RaftSelectionPopoverHeader(
                title: raftText(context, widget.field),
                onClear: widget.selection.isEmpty
                    ? null
                    : () {
                        if (acceptsInteraction) widget.onClear();
                      },
              ),
              RaftSelectionPopoverSearchSlot(
                child: TextField(
                  contextMenuBuilder: RaftTextSelectionToolbar.editableText,
                  autofillHints: null,
                  controller: search,
                  autofocus: RaftInteraction.of(context).pointer,
                  style: RaftTypography.mono(t, size: 12, line: 16),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: raftText(context, 'Search…'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  onChanged: (value) {
                    if (acceptsInteraction) {
                      setState(() => needle = value.trim().toLowerCase());
                    }
                  },
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.min(
                    256,
                    MediaQuery.sizeOf(context).height * .4,
                  ),
                ),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            raftText(context, 'No results'),
                            style: RaftTypography.mono(t),
                          ),
                        ),
                      for (final (index, option) in entries.indexed)
                        RaftMenuItem(
                          key: ValueKey(
                            'task-filter-${widget.field}-${option.key}',
                          ),
                          label: option.value,
                          selected: widget.selection.contains(option.key),
                          kind: RaftMenuKind.selectionPopover,
                          divider: index != entries.length - 1,
                          italic:
                              option.key == 'unassigned' ||
                              (option.key.startsWith('user:') &&
                                  option.value.endsWith(' me')),
                          // Channel rows stay label-only; identity rows carry a
                          // 20px avatar slot (the sentinel rows reserve it).
                          leading: widget.field == 'Channel'
                              ? null
                              : RaftSelectionPopoverAvatarSlot(
                                  name:
                                      option.key == 'unassigned' ||
                                          option.value.endsWith(' me')
                                      ? null
                                      : option.value,
                                  agent: option.key.startsWith('agent:'),
                                ),
                          onPressed: () {
                            if (acceptsInteraction) {
                              widget.onToggle(option.key);
                              if (widget.closeOnSelect) menu.close();
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
      builder: (context, controller, child) => RaftTooltip(
        message: raftText(
          context,
          widget.tooltip ?? 'Filter tasks by ${widget.field.toLowerCase()}',
        ),
        child: Focus(
          key: triggerKey,
          focusNode: anchorFocus,
          // TasksPanel filter chip: Button sm outline `h-8 gap-2` with the
          // field icon (14), label, optional count and ChevronDown 12. Layout
          // follows the 32px Web box; the touch target stays 48px.
          child: t.isRaftLook
              // raft-ui `PickerTriggerButton`: the filter trigger of the tasks toolbar and the search filters.
              ? RaftTouchTargetExpander(
                  minSize: const Size.square(RaftMetrics.touchTarget),
                  child: RaftPickerTriggerButton(
                    label:
                        widget.label ??
                        '${raftText(context, widget.field)}${widget.selection.isEmpty ? '' : ' (${widget.selection.length})'}',
                    glyph:
                        widget.glyph ??
                        switch (widget.field) {
                          'Channel' => RaftGlyph.hash,
                          'Creator' || 'From' => RaftGlyph.userCircle2,
                          _ => RaftGlyph.user,
                        },
                    selected: widget.selection.isNotEmpty,
                    onPressed: () {
                      if (!widget.valid()) return;
                      controller.isOpen
                          ? controller.close()
                          : controller.open();
                    },
                  ),
                )
              : widget.picker
              ? RaftTouchTargetExpander(
                  minSize: const Size.square(RaftMetrics.touchTarget),
                  child: RaftControl(
                    kind: RaftControlKind.filter,
                    variant: widget.selection.isEmpty
                        ? RaftControlVariant.outline
                        : RaftControlVariant.primary,
                    selected: widget.selection.isNotEmpty,
                    recipe: widget.picker
                        ? RaftPickerTriggerRecipe(
                            t,
                            selected: widget.selection.isNotEmpty,
                            popupOpen: widget.combobox && menu.isOpen,
                          )
                        : null,
                    visualHeight: pickerHeight,
                    minimumTargetSize: pickerHeight,
                    onPressed: () {
                      if (!widget.valid()) return;
                      controller.isOpen
                          ? controller.close()
                          : controller.open();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: RaftResourceMetrics.gap1_5,
                      children: [
                        RaftIcon(
                          widget.glyph ??
                              switch (widget.field) {
                                'Channel' => RaftGlyph.hash,
                                'Creator' || 'From' => RaftGlyph.userCircle2,
                                _ => RaftGlyph.user,
                              },
                          size: 12,
                        ),
                        Text(
                          widget.label ??
                              '${raftText(context, widget.field)}${widget.selection.isEmpty ? '' : ' (${widget.selection.length})'}',
                        ),
                        // The picker's indicator slot is 16px wide.
                        const RaftPickerIndicator(),
                      ],
                    ),
                  ),
                )
              : RaftTouchTargetExpander(
                  minSize: const Size.square(RaftMetrics.touchTarget),
                  child: RaftTaskFilterButton(
                    selected: widget.selection.isNotEmpty,
                    onPressed: () {
                      if (!widget.valid()) return;
                      controller.isOpen
                          ? controller.close()
                          : controller.open();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: RaftResourceMetrics.gap2,
                      children: [
                        RaftIcon(
                          widget.glyph ??
                              switch (widget.field) {
                                'Channel' => RaftGlyph.hash,
                                'Creator' || 'From' => RaftGlyph.userCircle2,
                                _ => RaftGlyph.user,
                              },
                          size: 14,
                        ),
                        Text(
                          widget.label ??
                              '${raftText(context, widget.field)}${widget.selection.isEmpty ? '' : ' (${widget.selection.length})'}',
                        ),
                        RaftIcon(
                          RaftGlyph.chevronDown,
                          size: widget.picker ? 12 : 14,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
