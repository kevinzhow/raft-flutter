// Web components/agent/runtimePickerOptions.ts + useRuntimeShowAllAction.ts:
// the runtime picker's rows, grouped by "can it run on this computer right
// now", from the server's runtime-options rows alone. Pure: no widgets, no I/O.
import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart' show RaftAgentSelectOption;

/// One runtime-options row, labelled and with today's selectability decided.
@immutable
class RuntimePickerRow {
  const RuntimePickerRow({
    required this.value,
    required this.label,
    required this.disabled,
    required this.capabilityStatus,
    this.availabilitySuffix,
    this.experimental = false,
    this.selectable,
    this.current = false,
  });

  final String value;

  /// The runtime's name, without what this computer lacks for it.
  final String label;

  /// What this computer lacks for it, as text after the name (" (not
  /// installed)", " · Update required"). Said wherever the row's group does
  /// not say it already.
  final String? availabilitySuffix;

  /// Drawn with the Experimental badge after the name.
  final bool experimental;
  final bool disabled;

  /// `available`, `not_installed` or `update_required` (`RuntimeCapabilityStatus`).
  final String capabilityStatus;

  /// The server lets the person pick it here at all (`canSelectInThisContext`).
  /// Unlike [disabled], a moment's loading does not clear it. Defaults to
  /// `!disabled`.
  final bool? selectable;

  /// The agent's current runtime (the switch picker): pinned first, in its own
  /// group.
  final bool current;

  bool get _selectable => selectable ?? !disabled;
}

/// The group headings (`runtime.picker.group.*`), already localized.
@immutable
class RuntimePickerGroupLabels {
  const RuntimePickerGroupLabels({
    required this.current,
    required this.ready,
    required this.notAvailable,
    required this.needsUpdate,
    required this.notInstalled,
  });
  final String current, ready, notAvailable, needsUpdate, notInstalled;
}

/// The id of the "Show all supported" row: it identifies the row and is never
/// a value.
const runtimePickerActionValue = '__runtime_picker_show_all__';

RaftAgentSelectOption<String> _option(
  RuntimePickerRow row, {
  required String? group,
  required String? badge,
  required bool suffixInList,
}) => RaftAgentSelectOption<String>(
  row.value,
  row.label,
  enabled: !row.disabled,
  group: group,
  badge: row.experimental ? badge : null,
  suffix: row.availabilitySuffix == null || row.availabilitySuffix!.isEmpty
      ? null
      : row.availabilitySuffix,
  suffixInList: suffixInList,
);

/// `groupRuntimePickerRows`: the current runtime first (switching), then Ready
/// on this computer, then Not available on this server (only as the field's
/// value), Needs a Raft Computer update, then (only when asked, or when nothing
/// else is listed) Not installed on this computer. Grouping never changes
/// whether a row can be picked. Inside Needs a Raft Computer update and Not
/// installed the heading already says what the row's suffix would, so the list
/// goes without it; the closed field keeps it.
///
/// [canToggle] says whether a Show all supported toggle has anything to show.
/// [selectedValue] stays listed even when it would be hidden, so the field
/// never shows a value its list does not have.
({List<RaftAgentSelectOption<String>> options, bool canToggle})
groupRuntimePickerRows(
  List<RuntimePickerRow> rows, {
  required bool showAll,
  required String selectedValue,
  required RuntimePickerGroupLabels labels,
  required String experimentalLabel,
}) {
  // Over the rows the list can show: one this server doesn't offer is not
  // listed, so it doesn't count.
  bool unoffered(RuntimePickerRow row) =>
      row.capabilityStatus == 'available' &&
      !row._selectable &&
      row.value != selectedValue;
  final onlyNotInstalled = rows.every(
    (row) =>
        unoffered(row) ||
        (!row.current && row.capabilityStatus == 'not_installed'),
  );
  final showEverything = showAll || onlyNotInstalled;
  final current = <RaftAgentSelectOption<String>>[];
  final ready = <RaftAgentSelectOption<String>>[];
  final notAvailable = <RaftAgentSelectOption<String>>[];
  final needsUpdate = <RaftAgentSelectOption<String>>[];
  final notInstalled = <RaftAgentSelectOption<String>>[];
  var notInstalledCount = 0;
  for (final row in rows) {
    RaftAgentSelectOption<String> inGroup(String group, bool suffixInList) =>
        _option(
          row,
          group: group,
          badge: experimentalLabel,
          suffixInList: suffixInList,
        );
    if (row.current) {
      current.add(inGroup(labels.current, true));
    } else if (row.capabilityStatus == 'available' && !row._selectable) {
      // Not offered here (rollout or admission): nothing to do about it, so
      // not listed, unless it is the field's value.
      if (row.value == selectedValue) {
        notAvailable.add(inGroup(labels.notAvailable, true));
      }
    } else if (row.capabilityStatus == 'available' || !row.disabled) {
      // A row the person can pick runs here by definition: never hide it.
      ready.add(inGroup(labels.ready, true));
    } else if (row.capabilityStatus == 'update_required') {
      needsUpdate.add(inGroup(labels.needsUpdate, false));
    } else {
      notInstalledCount += 1;
      if (showEverything || row.value == selectedValue) {
        notInstalled.add(inGroup(labels.notInstalled, false));
      }
    }
  }
  return (
    options: [
      ...current,
      ...ready,
      ...notAvailable,
      ...needsUpdate,
      ...notInstalled,
    ],
    canToggle: notInstalledCount > 0 && !onlyNotInstalled,
  );
}

/// `flatRuntimePickerOptions`: every row in one flat list, each saying what
/// this computer lacks for it (onboarding's list has no groups to say it).
List<RaftAgentSelectOption<String>> flatRuntimePickerOptions(
  List<RuntimePickerRow> rows, {
  required String experimentalLabel,
}) => [
  for (final row in rows)
    _option(row, group: null, badge: experimentalLabel, suffixInList: true),
];

/// `useRuntimeShowAllAction`: the Show all supported / Show installed only
/// row at the end of the list, when there are not-installed runtimes to show
/// or hide. Null when there is nothing to toggle.
RaftAgentSelectOption<String>? runtimeShowAllAction({
  required bool canToggle,
  required bool showAll,
  required String showAllLabel,
  required String installedOnlyLabel,
  required VoidCallback onToggle,
}) => canToggle
    ? RaftAgentSelectOption<String>.action(
        runtimePickerActionValue,
        showAll ? installedOnlyLabel : showAllLabel,
        onAction: onToggle,
      )
    : null;
