import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

typedef MembersUsagePick = ({
  String id,
  String label,
  String group,
  Set<String> agents,
  Widget? avatar,
});

class MembersUsageFilter extends StatefulWidget {
  const MembersUsageFilter({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  final List<MembersUsagePick> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  @override
  State<MembersUsageFilter> createState() => _MembersUsageFilterState();
}

class _MembersUsageFilterState extends State<MembersUsageFilter> {
  final _menu = MenuController();
  final _anchor = GlobalKey();
  final _trigger = FocusNode();

  @override
  void dispose() {
    _trigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = raftText(context, 'Agents');
    final selected = widget.options
        .where((option) => widget.selected.contains(option.id))
        .toList();
    final value = switch (selected.length) {
      0 => null,
      1 => selected.firstOrNull?.label,
      final count => '$count',
    };
    return RaftPopoverAnchor(
      controller: _menu,
      anchorKey: _anchor,
      childFocusNode: _trigger,
      collisionPadding: 16,
      flipVertically: false,
      popup: RaftComboboxPanel.items(
        key: const ValueKey('members-usage-filter-menu'),
        width: (MediaQuery.sizeOf(context).width - 32)
            .clamp(0.0, 260.0)
            .toDouble(),
        label: title,
        searchPlaceholder: 'Search…',
        autofocus: RaftInteraction.of(context).pointer,
        highlightFirst: true,
        onDismiss: _menu.close,
        onClear: selected.isEmpty ? null : widget.onClear,
        selectedIds: widget.selected,
        onSelected: widget.onToggle,
        items: [
          for (final option in widget.options)
            RaftComboboxItem(
              option.id,
              option.label,
              rowKey: ValueKey('members-usage-filter-option-${option.id}'),
              group: raftText(context, option.group),
              leading: option.avatar,
              meta: option.avatar == null ? '${option.agents.length}' : null,
            ),
        ],
      ),
      builder: (context, controller, _) => RaftPickerTriggerButton(
        key: _anchor,
        focusNode: _trigger,
        label: title,
        value: value,
        selected: value != null,
        glyph: RaftGlyph.bot,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
