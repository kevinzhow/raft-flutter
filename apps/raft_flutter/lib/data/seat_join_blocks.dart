import 'system_notification_projection.dart';

/// Web v1.24 `useSeatJoinBlocks` (components/layout/useSeatJoinBlocks.ts):
/// people a full invite or join link turned away from the current server
/// (`GET /servers/:id/seat-join-blocks`, behind the `pro_seat_add` flag).

/// `SeatJoinBlock`: one person turned away; [id] keys the dismissal.
class SeatJoinBlock {
  const SeatJoinBlock({required this.id, required this.name});
  final String id, name;
}

/// Whether this viewer asks the server at all: a member role that is not a
/// guest (Web `role !== null && role !== "guest"`).
bool seatJoinBlocksAsked(Map<String, dynamic>? server) {
  final role = server?['role'];
  return server?['id'] is String && role is String && role != 'guest';
}

/// The blocks of a response body; empty when there are none or the body is not
/// one (Web `Array.isArray(data?.blocks) && length > 0`). Rows without an id
/// or a name are skipped rather than invented.
List<SeatJoinBlock> parseSeatJoinBlocks(dynamic raw) {
  final rows = raw is Map ? raw['blocks'] : null;
  if (rows is! List) return const [];
  return List.unmodifiable([
    for (final row in rows)
      if (row is Map &&
          row['id'] is String &&
          (row['id'] as String).isNotEmpty &&
          row['name'] is String)
        SeatJoinBlock(id: row['id'] as String, name: row['name'] as String),
  ]);
}

/// useSystemNotifications section 0b: one warning per block, dismissed per
/// `seat-join-blocked:<id>` (a person turned away again later is a new block
/// and shows). The action (Add seats for someone who manages billing, Ask an
/// owner for anyone else) opens the Web's Plan & Billing page.
List<SystemNotice> seatJoinBlockNotices(
  List<SeatJoinBlock> blocks, {
  required String serverName,
}) => [
  for (final block in blocks)
    SystemNotice(
      id: 'seat-join-blocked:${block.id}',
      kind: SystemNoticeKind.warning,
      title: "$serverName · ${block.name} couldn't join",
      body: 'Upgrade needed for ${block.name} to join',
      destination: SystemNoticeDestination.seatJoin,
      fingerprint: 'seat-join-blocked:${block.id}',
      parameters: {'server': serverName, 'name': block.name},
    ),
];
