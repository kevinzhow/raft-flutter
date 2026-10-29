import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Activity compact scope', size: Size(440, 110))
Widget activityCompactScopePreview() => RaftActivityScopeToolbar(
  view: RaftActivityView.unread,
  compact: true,
  sort: 'desc',
  onView: (_) {},
  onOpenSwitcher: () {},
  onSort: (_) {},
  markAllRead: RaftTextButton(
    label: 'Mark All Read',
    visualHeight: 32,
    minimumTargetSize: 32,
    onPressed: () {},
  ),
);

@RaftPreviews('Activity mobile views', size: Size(390, 70))
Widget activityMobileScopePreview() => RaftActivityScopeToolbar(
  view: RaftActivityView.saved,
  compact: false,
  sort: 'desc',
  onView: (_) {},
  onOpenSwitcher: () {},
  onSort: (_) {},
);

@RaftPreviews('Activity scope picker', size: Size(440, 590))
Widget activityScopePickerPreview() => RaftActivityScopePicker(
  view: RaftActivityView.all,
  onView: (_) {},
  onGroup: (_) {},
  onClearGroup: () {},
  groups: const [
    RaftActivityGroup(id: 'alice', label: 'Alice', count: 2, dm: true),
    RaftActivityGroup(id: 'general', label: 'general', count: 4),
  ],
  counts: const {RaftActivityView.all: 6, RaftActivityView.unread: 2},
);

@RaftPreviews('Activity DMs mobile', size: Size(390, 70))
Widget activityDirectMessagesMobilePreview() => RaftActivityScopeToolbar(
  view: RaftActivityView.dms,
  compact: false,
  sort: 'desc',
  onView: (_) {},
  onOpenSwitcher: () {},
  onSort: (_) {},
);

@RaftPreviews('Activity DMs picker', size: Size(440, 590))
Widget activityDirectMessagesPickerPreview() => RaftActivityScopePicker(
  view: RaftActivityView.dms,
  onView: (_) {},
  onGroup: (_) {},
  onClearGroup: () {},
  groups: const [
    RaftActivityGroup(id: 'alice', label: 'Alice', count: 2, dm: true),
    RaftActivityGroup(id: 'general', label: 'general', count: 4),
  ],
  counts: const {RaftActivityView.all: 6, RaftActivityView.dms: 2},
);

@RaftPreviews('Activity pending results', size: Size(440, 600))
Widget activityLoadingPreview() => const RaftActivityLoadingList();

@RaftPreviews('Activity scoped finder', size: Size(440, 70))
Widget activityFinderPreview() => const _ActivityFinderPreview();

class _ActivityFinderPreview extends StatefulWidget {
  const _ActivityFinderPreview();
  @override
  State<_ActivityFinderPreview> createState() => _ActivityFinderPreviewState();
}

class _ActivityFinderPreviewState extends State<_ActivityFinderPreview> {
  final controller = TextEditingController();
  final focus = FocusNode();
  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftActivitySearchInput(
    controller: controller,
    focusNode: focus,
    onChanged: (_) {},
    onDismissEmpty: controller.clear,
  );
}
