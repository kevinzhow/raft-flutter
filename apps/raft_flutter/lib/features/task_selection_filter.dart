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
  });

  /// Search filters use PickerTriggerButton; task filters an sm outline
  /// Button.
  final bool picker;
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
    final pickerHeight = widget.picker && !t.brutal
        ? 28.0
        : RaftMetrics.buttonMd;
    final width = math.min(248.0, MediaQuery.sizeOf(context).width - 24);
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
      alignmentOffset: const Offset(0, 4),
      onOpen: () {
        widget.beforeOpen?.call(menu);
        search.clear();
        setState(() => needle = '');
      },
      style: const MenuStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
      ),
      menuChildren: [
        RaftMenuPanel(
          width: width,
          kind: RaftMenuKind.selectionPopover,
          onDismiss: menu.close,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      raftText(context, widget.field),
                      style: RaftTypography.mono(t, size: 11, line: 16),
                    ),
                  ),
                  if (widget.selection.isNotEmpty)
                    RaftTextButton(
                      label: 'Clear',
                      visualHeight: 24,
                      onPressed: () {
                        if (acceptsInteraction) widget.onClear();
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: search,
                autofocus: true,
                style: RaftTypography.mono(t, size: 12, line: 16),
                decoration: InputDecoration(
                  hintText: raftText(context, 'Search'),
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
                    for (final option in entries)
                      RaftMenuItem(
                        key: ValueKey(
                          'task-filter-${widget.field}-${option.key}',
                        ),
                        label: option.value,
                        selected: widget.selection.contains(option.key),
                        kind: RaftMenuKind.selectionPopover,
                        glyph:
                            widget.field == 'Channel' ||
                                option.key == 'unassigned'
                            ? null
                            : option.key.startsWith('user:')
                            ? RaftGlyph.user
                            : RaftGlyph.bot,
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
      builder: (context, controller, child) => Tooltip(
        message: raftText(
          context,
          widget.tooltip ?? 'Filter tasks by ${widget.field.toLowerCase()}',
        ),
        child: Focus(
          focusNode: anchorFocus,
          // TasksPanel filter chip: Button sm outline `h-8 gap-2` with the
          // field icon (14), label, optional count and ChevronDown 12. Layout
          // follows the 32px Web box; the touch target stays 48px.
          child: RaftTouchTargetExpander(
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
                    )
                  : null,
              visualHeight: pickerHeight,
              minimumTargetSize: pickerHeight,
              onPressed: () {
                if (!widget.valid()) return;
                controller.isOpen ? controller.close() : controller.open();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
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
                  const RaftIcon(RaftGlyph.chevronDown, size: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
