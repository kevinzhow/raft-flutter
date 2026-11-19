part of 'message_selection.dart';

typedef MessageSelectionRange = ({
  List<String> ids,
  String edge,
  bool anchorAbove,
});

MessageSelectionRange? _messageSelectionRange(
  List<SelectedMessageRow> rows,
  String anchor,
  Iterable<String> visibleIds,
) {
  final visible = visibleIds.toSet();
  if (visible.isEmpty || visible.contains(anchor)) return null;
  final position = rows.indexWhere((row) => row.message.id == anchor);
  if (position < 0) return null;
  bool selectable(SelectedMessageRow row) =>
      !row.message.retracted && messageForwardable(row.message);
  final edges = [
    for (final (index, row) in rows.indexed)
      if (visible.contains(row.message.id) && selectable(row)) index,
  ];
  if (edges.isEmpty) return null;
  final above = position < edges.first;
  if (!above && position <= edges.last) return null;
  final edge = above ? edges.last : edges.first;
  return (
    ids: [
      for (final row in rows.getRange(
        above ? position : edge,
        (above ? edge : position) + 1,
      ))
        if (selectable(row)) row.message.id,
    ],
    edge: rows[edge].message.id,
    anchorAbove: above,
  );
}
