// Source 1d689caf34442247cab70580d7feac1b8c302d60:
// packages/web/src/utils/taskConversation.ts (normalizeTaskConversationRow).
Map<String, dynamic> normalizeTaskConversationRow(Map<String, dynamic> row) {
  if (row['kind'] != 'task' &&
      (row['conversationKind'] != 'task' || row['parentMessageId'] == '')) {
    return row;
  }
  return {
    ...row,
    if (row['kind'] == 'task') 'kind': 'thread',
    'conversationKind': 'task',
    'parentMessageId': '',
  };
}

List<Map<String, dynamic>> normalizeTaskConversationRows(
  List<Map<String, dynamic>> rows,
) {
  var result = rows;
  var index = 0;
  for (final row in rows) {
    final normalized = normalizeTaskConversationRow(row);
    if (!identical(normalized, row)) {
      if (identical(result, rows)) result = List.of(rows);
      result[index] = normalized;
    }
    index++;
  }
  return result;
}
