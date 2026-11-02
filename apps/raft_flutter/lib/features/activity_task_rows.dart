/// Thread-row task label `#N @claimant` (ThreadsInbox.tsx task badge).
String activityTaskLabel(Map<String, dynamic> row) {
  final claimant = row['taskClaimedByName'];
  return '#${row['taskNumber']}'
      '${claimant is String && claimant.isNotEmpty ? ' @$claimant' : ''}';
}

/// Source applyTaskToInboxItems / normalizeTaskMetadataUpdate: overlay
/// `taskNumber`, `taskStatus`, `taskClaimedByName` (null when unclaimed) on
/// thread rows whose `parentMessageId` is the task's `messageId`. Returns
/// [rows] itself when nothing changed.
List<Map<String, dynamic>> applyTaskToActivityRows(
  List<Map<String, dynamic>> rows,
  Map task,
) {
  final messageId = task['messageId'], status = task['status'];
  final number = task['taskNumber'];
  if (messageId is! String || status is! String || number is! num) return rows;
  final claimant = task['claimedByName'];
  final name = claimant is String ? claimant : null;
  var changed = false;
  final next = [
    for (final row in rows)
      if (row['kind'] != 'thread' || row['parentMessageId'] != messageId)
        row
      else if (row['taskNumber'] == number &&
          row['taskStatus'] == status &&
          row['taskClaimedByName'] == name)
        row
      else ...[
        () {
          changed = true;
          return {
            ...row,
            'taskNumber': number,
            'taskStatus': status,
            'taskClaimedByName': name,
          };
        }(),
      ],
  ];
  return changed ? next : rows;
}
