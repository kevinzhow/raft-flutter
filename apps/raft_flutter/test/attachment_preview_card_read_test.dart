import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_preview_summary.dart';

/// Web v1.24 attachmentPreviewSummaryCache.ts: a card reads
/// `GET /attachments/:id/preview?view=summary` (never the document body); the
/// CSV summary says `rowsShown`, and an older server's full payload still
/// reads the same.
void main() {
  test('the card asks for the summary view', () async {
    final asked = <(String, Map<String, dynamic>?)>[];
    final summaries = AttachmentPreviewSummaries.testing((path, {query}) async {
      asked.add((path, query));
      return {
        'status': 'ok',
        'data': {
          'kind': 'csv',
          'rowsShown': 200,
          'rowCount': 5000,
          'columnCount': 7,
        },
        'truncated': true,
      };
    });
    final csv = await summaries.fetch('a1');
    expect(asked.single.$1, '/attachments/a1/preview');
    expect(asked.single.$2, {'view': 'summary'});
    expect((csv!.rows, csv.columns, csv.truncated), (200, 7, true));
  });

  test('an older server answers the full payload: rows are counted', () {
    final csv = AttachmentPreviewSummary.parse({
      'status': 'ok',
      'data': {
        'kind': 'csv',
        'rows': [
          ['a'],
          ['b'],
        ],
        'rowCount': 2,
        'columnCount': 1,
      },
    });
    expect(csv!.rows, 2);
  });
}
