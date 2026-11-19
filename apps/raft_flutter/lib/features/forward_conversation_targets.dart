import '../data/workspace_controller.dart';

const forwardConversationTargetLimit = 4;

Future<List<Map<String, dynamic>>> fetchForwardConversationTargets(
  WorkspaceController w, {
  String? currentChannelId,
}) async {
  final result = await w.query(
    '/messages/forward/targets/conversations',
    query: {
      'limit': forwardConversationTargetLimit,
      'currentChannelId': ?currentChannelId,
    },
  );
  final rows = result is Map ? result['targets'] : null;
  if (rows is! List) return const [];
  final usable = [
    for (final row in rows.whereType<Map>())
      if ((row['type'] == 'thread' || row['type'] == 'task') &&
          row['channelId'] is String &&
          (row['channelId'] as String).isNotEmpty)
        Map<String, dynamic>.from(row),
  ];
  final current = usable.where((row) => row['current'] == true).firstOrNull;
  return [
    ?current,
    for (final row in usable)
      if (!identical(row, current)) row,
  ].take(forwardConversationTargetLimit).toList();
}
