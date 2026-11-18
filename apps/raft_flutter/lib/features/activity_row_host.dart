import 'package:flutter/widgets.dart';

import '../data/workspace_controller.dart';

/// What one Activity row needs from the page that lists it: the page's own
/// reads and actions, handed over as values and callbacks (the row is drawn in
/// `activity_inbox_row.dart` and `activity_object_row.dart`; the data and the
/// gestures stay with the page).
class ActivityRowHost {
  const ActivityRowHost({
    required this.controller,
    required this.filter,
    required this.interval,
    required this.selected,
    required this.canonical,
    required this.popupOpen,
    required this.open,
    required this.activate,
    required this.menu,
    required this.action,
    required this.stableSender,
    required this.directorySenderLabel,
    required this.agents,
    required this.people,
    this.located = false,
    this.phoneTouch,
    this.taskV2,
    this.onOpenObject,
    this.onLongPress,
    this.onSecondaryTap,
    // The card layout is gone: these four stay for call sites that still pass
    // them, and do nothing.
    this.savedView = false,
    this.listLayout = true,
    this.relativeTime,
    this.pinnedHeight,
    this.separator = false,
    this.topRule = false,
  });
  final WorkspaceController controller;

  /// The view the row is listed in (`all`, `unread`, `mentions`, ...).
  final String filter;

  /// Double-click window: the host platform's, or the one captured while the
  /// row's gesture was pinned.
  final Duration interval;

  /// Open in the detail pane (Web `active`).
  final bool selected;

  /// A jump just landed on this row (Web `located`, `useLocated`): the row
  /// washes `info-soft`, held 1.2 s and faded out by 2 s. The page clears it
  /// after `raftLocatedDuration`.
  final bool located;

  /// The row's menu is open.
  final bool popupOpen;

  /// A second click upgrades to the canonical page (Activity master/detail).
  final bool canonical;

  /// Overrides compact touch swipe eligibility. Null uses the layout width
  /// and input mode. True also gives the row the touch Done presentation.
  final bool? phoneTouch;

  /// Task v2 is on for this server (null reads the server's flag).
  final bool? taskV2;

  final VoidCallback open;

  /// Opens the object of an Artifact row (Web `useArtifactOpenIntent`); null
  /// opens it like any row, through [open].
  final ValueChanged<Map<String, dynamic>>? onOpenObject;
  final void Function(int detail, double? height, {bool pointer}) activate;

  /// The row menu at a global position: right click and press-and-hold.
  final ValueChanged<Offset> menu;

  /// Overrides for [menu] on touch hold / right click.
  final ValueChanged<Offset>? onLongPress, onSecondaryTap;

  /// `done`, `undone`.
  final void Function(String action) action;
  final String Function(String key, String Function() build) stableSender;
  final String Function(dynamic id, dynamic type) directorySenderLabel;
  final List<Map<String, dynamic>> agents, people;

  /// Unused since the row draws its own time.
  final String Function(dynamic value)? relativeTime;
  final double? pinnedHeight;
  final bool savedView, listLayout, separator, topRule;

  /// The directory row of one agent, when known.
  Map<String, dynamic>? agentFor(String id) =>
      agents.where((a) => a['id'] == id).firstOrNull;
}

double? cardHeight(BuildContext context) =>
    (context.findRenderObject() as RenderBox?)?.size.height;
