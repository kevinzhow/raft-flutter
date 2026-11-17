import 'package:flutter/widgets.dart';

import '../data/workspace_controller.dart';
import 'tab_root_retap.dart';

/// Principal, page, and every value that changes how the list is built.
/// Messages and presence are not inputs.
Object mobileResourceInputs(
  WorkspaceController controller,
  String section, {
  required bool wide,
  required String? rootTab,
  required bool activityMasterDetail,
}) => (
  controller.client.generation,
  controller.client.user?.id,
  controller.server?.id,
  controller.server?.string('role'),
  section,
  wide,
  rootTab,
  activityMasterDetail,
);

/// Phone tasks and saved keep one list for the page, and rebuild it when
/// [inputs] change. A covered route keeps that list so coming back is the
/// same page.
Widget mobileResourceBody({
  required String route,
  required WorkspaceController page,
  required WorkspaceController? outer,
  required bool direct,
  required bool Function() active,
  required bool wide,
  required String? rootTab,
  required bool activityMasterDetail,
  required Widget Function(WorkspaceController owner) buildList,
}) {
  // The phone bar's re-tap reaches the list only while it is that tab's root.
  Widget list(WorkspaceController owner) =>
      TabRootRetapScope(tab: wide ? null : rootTab, child: buildList(owner));
  final useOuter = direct && (route == 'tasks' || route == 'saved');
  if (!useOuter || outer == null) return list(page);
  return MobileResourceDirectPage(
    inputs: mobileResourceInputs(
      outer,
      route,
      wide: wide,
      rootTab: rootTab,
      activityMasterDetail: activityMasterDetail,
    ),
    active: active,
    buildList: () => list(outer),
  );
}

/// The phone list. A covered route keeps the list it already built.
class MobileResourceDirectPage extends StatefulWidget {
  const MobileResourceDirectPage({
    super.key,
    required this.inputs,
    required this.active,
    required this.buildList,
  });

  final Object? inputs;
  final bool Function() active;
  final Widget Function() buildList;

  @override
  State<MobileResourceDirectPage> createState() =>
      _MobileResourceDirectPageState();
}

class _MobileResourceDirectPageState extends State<MobileResourceDirectPage> {
  Widget? _leaf;
  Object? _inputs;

  @override
  Widget build(BuildContext context) {
    TickerMode.valuesOf(context);
    if (!widget.active()) return _leaf ?? const SizedBox.shrink();
    if (_leaf != null && widget.inputs == _inputs) return _leaf!;
    _inputs = widget.inputs;
    _leaf = widget.buildList();
    return _leaf!;
  }
}
