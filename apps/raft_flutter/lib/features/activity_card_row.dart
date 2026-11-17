import 'package:flutter/widgets.dart';

import 'activity_inbox_row.dart';
import 'activity_object_row.dart';
import 'activity_row_host.dart';

export 'activity_row_host.dart' show ActivityRowHost, cardHeight;

/// One Activity row: an Artifact's (`kind: object`) or a conversation's, both
/// on raft-ui's `RaftInboxItem`. The card layout is gone (Web v1.24 has one
/// row).
class ActivityCardRow extends StatelessWidget {
  const ActivityCardRow({super.key, required this.row, required this.host});
  final Map<String, dynamic> row;
  final ActivityRowHost host;

  @override
  Widget build(BuildContext context) => row['kind'] == 'object'
      ? ActivityObjectRow(row: row, host: host)
      : ActivityInboxRow(row: row, host: host);
}
