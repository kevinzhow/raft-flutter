// Web MessageItem AttachmentCard: a document or diff card asks
// GET /attachments/:id/preview for its summary line (rows / columns of a CSV,
// the kind of the others, file / hunk counts and +/- totals of a diff), once
// per attachment for the session.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_preview_summary.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';

Map<String, Object?> _ok(Map<String, Object?> data, {bool truncated = false}) =>
    {'status': 'ok', 'data': data, if (truncated) 'truncated': true};

final _csv = _ok({
  'kind': 'csv',
  'delimiter': ',',
  'headers': ['a', 'b'],
  'rows': [
    ['1', '2'],
    ['3', '4'],
    ['5', '6'],
  ],
  'rowCount': 3,
  'columnCount': 2,
});

final _diff = _ok({
  'kind': 'diff',
  'stats': {'files': 1, 'hunks': 2, 'additions': 12, 'deletions': 3},
});

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://card-summary.invalid',
        sessionStore: MemorySessionStore(),
      );
  final requests = <String>[];
  final answers = <String, Object?>{};
  final gates = <String, Completer<void>>{};
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    requests.add(path);
    await gates[path]?.future;
    final answer = answers[path];
    if (answer is Exception) throw answer;
    return answer ?? {'status': 'unsupported', 'reason': 'unsupported'};
  }
}

void main() {
  group('AttachmentPreviewSummary.parse', () {
    test('reads what a card shows of each kind', () {
      final csv = AttachmentPreviewSummary.parse(_csv)!;
      expect(
        (csv.kind, csv.rows, csv.columns, csv.truncated),
        ('csv', 3, 2, false),
      );
      final cut = AttachmentPreviewSummary.parse(
        _ok({'kind': 'csv', 'rows': [], 'columnCount': 4}, truncated: true),
      )!;
      expect(cut.truncated, true);
      final diff = AttachmentPreviewSummary.parse(_diff)!;
      expect(
        (diff.isDiff, diff.files, diff.hunks, diff.additions, diff.deletions),
        (true, 1, 2, 12, 3),
      );
      for (final kind in ['markdown', 'text', 'xlsx', 'pdf']) {
        expect(AttachmentPreviewSummary.parse(_ok({'kind': kind}))!.kind, kind);
      }
    });

    test('a refusal or an unknown payload has no summary', () {
      expect(
        AttachmentPreviewSummary.parse({
          'status': 'unsupported',
          'reason': 'too_large',
        }),
        isNull,
      );
      expect(
        AttachmentPreviewSummary.parse(_ok({'kind': 'sheet-music'})),
        isNull,
      );
      expect(AttachmentPreviewSummary.parse(_ok({'kind': 'diff'})), isNull);
      expect(AttachmentPreviewSummary.parse(null), isNull);
    });
  });

  group('AttachmentPreviewSummaries', () {
    test('askers share one request and the answer is cached', () async {
      var asked = 0;
      final gate = Completer<dynamic>();
      final summaries = AttachmentPreviewSummaries.testing((path) {
        asked++;
        return gate.future;
      });
      final first = summaries.fetch('a');
      final second = summaries.fetch('a');
      gate.complete(_csv);
      expect((await first)!.kind, 'csv');
      expect(identical(await first, await second), true);
      expect((await summaries.fetch('a'))!.rows, 3);
      expect(asked, 1);
      expect(summaries.cached('a'), isNotNull);
    });

    test('a settled refusal is cached like a summary (Web)', () async {
      var asked = 0;
      final summaries = AttachmentPreviewSummaries.testing((path) async {
        asked++;
        return {'status': 'unsupported', 'reason': 'too_large'};
      });
      expect(await summaries.fetch('a'), isNull);
      expect(await summaries.fetch('a'), isNull);
      expect(asked, 1);
    });

    test('a failure or a transient refusal is not cached: the next card asks again', () async {
      var asked = 0;
      final summaries = AttachmentPreviewSummaries.testing((path) async {
        asked++;
        if (asked == 1) {
          throw const RaftApiException('boom');
        }
        if (asked == 2) {
          return {'status': 'unsupported', 'reason': 'unavailable'};
        }
        return _diff;
      });
      expect(await summaries.fetch('a'), isNull);
      expect(await summaries.fetch('a'), isNull);
      expect((await summaries.fetch('a'))!.isDiff, true);
      expect(asked, 3);
    });
  });

  group('cards', () {
    late _Client client;
    late WorkspaceController w;
    setUp(() {
      client = _Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'channel', 'joined': true});
      w.channels = [w.channel!];
    });
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    Future<void> pumpCard(
      WidgetTester tester,
      String name,
      String mime, {
      String? messageId = 'message-1',
      bool chinese = false,
    }) => tester.pumpWidget(
      MaterialApp(
        locale: Locale(chinese ? 'zh' : 'en'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: AttachmentView(
              controller: w,
              files: AttachmentFiles(),
              messageId: messageId,
              metadata: {
                'id': name,
                'filename': name,
                'mimeType': mime,
                'sizeBytes': 2048,
              },
            ),
          ),
        ),
      ),
    );

    testWidgets('a CSV card shows the generic line, then rows and columns', (
      tester,
    ) async {
      final gate = client.gates['/attachments/table.csv/preview'] =
          Completer<void>();
      client.answers['/attachments/table.csv/preview'] = _csv;
      await pumpCard(tester, 'table.csv', 'text/csv');
      expect(find.text('Document preview'), findsOneWidget);
      expect(find.text('Preview 3 rows · 2 columns'), findsNothing);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Preview 3 rows · 2 columns'), findsOneWidget);
      expect(find.text('CSV preview'), findsOneWidget);
      expect(find.text('Document preview'), findsNothing);
      expect(client.requests, ['/attachments/table.csv/preview']);
    });

    testWidgets(
      'a truncated CSV says "First"; one row and one column are singular',
      (tester) async {
        client.answers['/attachments/one.csv/preview'] = _ok({
          'kind': 'csv',
          'rows': [
            ['x'],
          ],
          'columnCount': 1,
        }, truncated: true);
        await pumpCard(tester, 'one.csv', 'text/csv');
        await tester.pump();
        await tester.pump();
        expect(find.text('First 1 row · 1 column'), findsOneWidget);
      },
    );

    testWidgets('markdown, text, xlsx and pdf cards name their kind', (
      tester,
    ) async {
      const cases = {
        'readme.md': (
          'text/markdown',
          'markdown',
          'Markdown document',
          'Markdown preview',
        ),
        'notes.txt': (
          'text/plain',
          'text',
          'Plain text document',
          'Text preview',
        ),
        'sheet.xlsx': (
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'xlsx',
          'XLSX spreadsheet',
          'XLSX preview',
        ),
        'paper.pdf': ('application/pdf', 'pdf', 'PDF document', 'PDF preview'),
      };
      for (final entry in cases.entries) {
        client.answers['/attachments/${entry.key}/preview'] = _ok({
          'kind': entry.value.$2,
        });
        await pumpCard(tester, entry.key, entry.value.$1);
        await tester.pump();
        await tester.pump();
        expect(find.text(entry.value.$3), findsOneWidget, reason: entry.key);
        expect(find.text(entry.value.$4), findsOneWidget, reason: entry.key);
      }
    });

    testWidgets(
      'a diff card shows file and hunk counts with coloured +/- totals',
      (tester) async {
        client.answers['/attachments/fix.patch/preview'] = _diff;
        await pumpCard(tester, 'fix.patch', 'text/x-patch');
        expect(find.text('Diff preview'), findsOneWidget);
        await tester.pump();
        await tester.pump();
        final summary = find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().startsWith('1 file · 2 hunks'),
        );
        expect(summary, findsOneWidget);
        final text = tester.widget<RichText>(summary).text.toPlainText();
        expect(text.contains('+12'), true);
        expect(text.contains('-3'), true);
        final spans = <TextSpan>[];
        (tester.widget<RichText>(summary).text as TextSpan).visitChildren((s) {
          if (s is TextSpan && s.text != null && s.style?.color != null) {
            spans.add(s);
          }
          return true;
        });
        expect([for (final s in spans) s.text], ['+12', '-3']);
        expect(spans[0].style!.color, isNot(spans[1].style!.color));
      },
    );

    testWidgets('Chinese: counts and kinds read from the Web zh catalog', (
      tester,
    ) async {
      client.answers['/attachments/fix.patch/preview'] = _diff;
      client.answers['/attachments/table.csv/preview'] = _csv;
      await pumpCard(tester, 'table.csv', 'text/csv', chinese: true);
      await tester.pump();
      await tester.pump();
      expect(find.text('预览 3 行 · 2 列'), findsOneWidget);
      expect(find.text('CSV 预览'), findsOneWidget);
      await pumpCard(tester, 'fix.patch', 'text/x-patch', chinese: true);
      await tester.pump();
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().startsWith('1 个文件 · 2 个差异块'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a card of a message that is not sent yet asks nothing', (
      tester,
    ) async {
      await pumpCard(tester, 'table.csv', 'text/csv', messageId: null);
      await tester.pump();
      expect(find.text('Document preview'), findsOneWidget);
      expect(client.requests, isEmpty);
    });

    testWidgets('other files ask nothing', (tester) async {
      await pumpCard(tester, 'bundle.zip', 'application/zip');
      await tester.pump();
      expect(client.requests, isEmpty);
    });
  });
}
