// The shared host of a person / agent / computer opened beside a page on
// desktop (Web ProfilePanel, ProfilePanel.tsx:78-93, 304): focus moves into the
// panel when it opens and returns to the row that opened it when it closes,
// and Escape in a field that is editing is the field's, not the panel's.
import 'package:flutter/widgets.dart';

import '../data/workspace_controller.dart';
import 'desktop_navigation_policy.dart';
import 'fleet_views.dart';
import 'member_profile_view.dart';

/// Keys of the panels this host wraps (see [detailFieldHasFocus]).
const desktopDetailKeys = <Key>[
  ValueKey('desktop-profile-detail'),
  ValueKey('computers-rack-side-panel'),
  Key('profile-panel'),
];

Widget desktopThreadFocus(Widget thread) => DesktopDetailFocus(
  open: true,
  restoreOnUnmount: true,
  builder: (scope) => FocusScope(node: scope, child: thread),
);

/// A text field editing inside an open detail panel takes the first Escape
/// (Web: the field marks it handled): it only loses focus. True when it did.
bool takeDetailFieldEscape() {
  if (!_detailFieldHasFocus()) return false;
  FocusManager.instance.primaryFocus?.unfocus();
  return true;
}

bool _detailFieldHasFocus() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  var inField = context.widget is EditableText;
  var inDetail = false;
  context.visitAncestorElements((e) {
    if (e.widget is EditableText) inField = true;
    if (desktopDetailKeys.contains(e.widget.key)) inDetail = true;
    return !inDetail;
  });
  return inField && inDetail;
}

/// Tracks a detail panel opening and closing: [builder] gets the scope to put
/// around the panel. Focus enters it when [open] turns true, and goes back to
/// whatever had it (the row) when [open] turns false.
class DesktopDetailFocus extends StatefulWidget {
  const DesktopDetailFocus({
    super.key,
    required this.open,
    required this.builder,
    this.restoreOnUnmount = false,
    this.moveFocus = true,
  });
  final bool open;
  final Widget Function(FocusScopeNode scope) builder;
  final bool restoreOnUnmount;
  final bool moveFocus;

  @override
  State<DesktopDetailFocus> createState() => _DesktopDetailFocusState();
}

class _DesktopDetailFocusState extends State<DesktopDetailFocus> {
  final scope = FocusScopeNode(debugLabel: 'desktop-detail');
  FocusNode? opener;

  @override
  void initState() {
    super.initState();
    if (widget.open) _open();
  }

  @override
  void didUpdateWidget(DesktopDetailFocus old) {
    super.didUpdateWidget(old);
    if (!old.open && widget.open) {
      _open();
    } else if (old.open && !widget.open) {
      final back = opener;
      opener = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && back != null && back.context != null) {
          back.requestFocus();
        }
      });
    }
  }

  void _open() {
    opener = FocusManager.instance.primaryFocus;
    if (widget.moveFocus) _enter();
  }

  void _enter() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !widget.open) return;
    scope.requestFocus();
    scope.nextFocus();
  });

  @override
  void dispose() {
    final back = opener;
    if (widget.restoreOnUnmount && back != null && scope.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (back.context != null) back.requestFocus();
      });
    }
    scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(scope);
}

/// A person, agent or computer beside the page on desktop, or null for any
/// other target. Web puts every one of them in the same ProfilePanel: an X
/// (hidden below 768, where Back leads), Escape, resize and focus return; the
/// Search / Activity slot ([slot]) keeps Back only (`renderContentSlot`).
Widget? desktopProfileDetail({
  required WorkspaceController w,
  required Key key,
  required DesktopContentTarget target,
  required bool wide,
  required bool slot,
  required VoidCallback close,
  required VoidCallback dismiss,
  required Future<void> Function() message,
  required void Function(String id) openAgent,
}) {
  if (target.kind == DesktopContentKind.human) {
    return MemberProfileView(
      key: key,
      controller: w,
      userId: target.id,
      onClose: close,
      onBack: !wide
          ? dismiss
          : slot
          ? close
          : null,
      showClose: !slot,
      onMessage: message,
    );
  }
  if (target.kind != DesktopContentKind.agent &&
      target.kind != DesktopContentKind.computer) {
    return null;
  }
  final computer = target.kind == DesktopContentKind.computer;
  return FleetDetail(
    key: key,
    controller: w,
    computers: computer,
    initial:
        (computer
            ? w.services.entityDirectory.computer(target.id)
            : w.services.entityDirectory.agent(target.id)) ??
        {'id': target.id},
    onClose: !wide && computer ? dismiss : close,
    backAlways: slot && !computer,
    closeAction: !slot,
    onOpenAgent: openAgent,
  );
}
