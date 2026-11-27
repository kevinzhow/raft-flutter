import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

typedef MembersUsagePick = ({
  String id,
  String label,
  String group,
  Set<String> agents,
  Widget? avatar,
});

class MembersUsageFilter extends RaftFitPicker {
  MembersUsageFilter({
    super.key,
    required super.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  }) : super(
         glyph: RaftGlyph.bot,
         labelOrder: 20,
         value: switch (selected.length) {
           0 => null,
           1 =>
             options
                 .where((option) => selected.contains(option.id))
                 .firstOrNull
                 ?.label,
           final count => '$count',
         },
       );

  final List<MembersUsagePick> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  @override
  bool get hasPopup => true;

  @override
  Widget buildPopup(
    Widget Function(BuildContext, FocusNode, VoidCallback?) triggerBuilder,
  ) => _MembersUsageFilterPopup(
    key: key,
    filter: this,
    triggerBuilder: triggerBuilder,
  );
}

class _MembersUsageFilterPopup extends StatefulWidget {
  const _MembersUsageFilterPopup({
    super.key,
    required this.filter,
    required this.triggerBuilder,
  });

  final MembersUsageFilter filter;
  final Widget Function(BuildContext, FocusNode, VoidCallback?) triggerBuilder;

  @override
  State<_MembersUsageFilterPopup> createState() => _MembersUsageFilterState();
}

class _MembersUsageFilterState extends State<_MembersUsageFilterPopup> {
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
    final filter = widget.filter;
    return RaftPopoverAnchor(
      controller: _menu,
      anchorKey: _anchor,
      childFocusNode: _trigger,
      collisionPadding: 16,
      flipVertically: false,
      snapToDevicePixels: true,
      popup: RaftComboboxPanel.items(
        key: const ValueKey('members-usage-filter-menu'),
        width: (MediaQuery.sizeOf(context).width - 32)
            .clamp(0.0, 260.0)
            .toDouble(),
        label: filter.label,
        searchPlaceholder: 'Search…',
        autofocus: RaftInteraction.of(context).pointer,
        highlightFirst: true,
        highlightFirstOnOpen: false,
        onDismiss: _menu.close,
        onClear: filter.selected.isEmpty ? null : filter.onClear,
        selectedIds: filter.selected,
        onSelected: filter.onToggle,
        items: [
          for (final option in filter.options)
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
      builder: (context, controller, _) => KeyedSubtree(
        key: _anchor,
        child: widget.triggerBuilder(context, _trigger, () {
          controller.isOpen ? controller.close() : controller.open();
        }),
      ),
    );
  }
}
