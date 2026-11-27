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
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _trigger.dispose();
    _search.dispose();
    _searchFocus.dispose();
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
      onOpen: () {
        _search.clear();
        setState(() => _query = '');
        if (RaftInteraction.of(context).pointer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _menu.isOpen) _searchFocus.requestFocus();
          });
        }
      },
      popup: RaftSelectionPopover(
        key: const ValueKey('members-usage-filter-menu'),
        width: (MediaQuery.sizeOf(context).width - 32)
            .clamp(0.0, 260.0)
            .toDouble(),
        title: title,
        searchController: _search,
        searchFocusNode: _searchFocus,
        searchPlaceholder: raftText(context, 'Search…'),
        searchIcon: false,
        onSearchChanged: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
        onClear: selected.isEmpty ? null : widget.onClear,
        options: [
          for (final option in widget.options)
            if (option.label.toLowerCase().contains(_query))
              RaftSelectionOption(
                rowKey: ValueKey('members-usage-filter-option-${option.id}'),
                label: option.label,
                group: raftText(context, option.group),
                leading: option.avatar,
                meta: option.avatar == null ? '${option.agents.length}' : null,
                checked: widget.selected.contains(option.id),
                onTap: () => widget.onToggle(option.id),
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
