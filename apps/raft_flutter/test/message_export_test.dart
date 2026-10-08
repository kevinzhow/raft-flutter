import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/message_image_export.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/features/message_selection.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

List<Map<String, dynamic>> messages() => [
  {
    'id': 'parent',
    'channelId': 'c1',
    'seq': '1',
    'content': '中文 export **body**\n```mermaid\nflowchart LR\n A[Draft] --> B[Review]\n```',
    'senderName': 'Alice',
    'createdAt': '2026-10-07T09:00:00Z',
    'threadId': 't1',
  },
  {
    'id': 'later',
    'channelId': 'c1',
    'seq': '3',
    'content': 'Later root',
    'senderName': 'Alice',
  },
  {
    'id': 'reply',
    'channelId': 't1',
    'seq': '2',
    'content': '日本語 reply',
    'senderName': 'Bob',
  },
];

class PendingSaveFiles extends AttachmentFiles {
  final requested = Completer<void>();
  final destination = Completer<String?>();
  int committed = 0;
  @override
  Future<String?> saveBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required bool Function() authorized,
  }) async {
    requested.complete();
    final result = await destination.future;
    if (!authorized()) return null;
    committed++;
    return result;
  }
}

void main() {
  test('channel selection includes loaded replies after their parent; metadata has no capability URLs', () async {
    final (w, _) = await fixture('owner');
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    w.ledger.ingest(messages(), expectedGeneration: w.ledger.generation);
    w.visibleIds['c1'] = {'parent', 'later'};
    final selection = MessageSelection(w, thread: false);
    addTearDown(selection.dispose);
    selection.enter('parent');
    expect(selection.selected.map((r) => r.message.id), ['parent', 'reply']);
    expect(selection.selected.last.isThreadChild, isTrue);
    final text = selectedMessagesMarkdown(selection.selected);
    expect(text, contains('中文 export **body**'));
    expect(text, contains('> 日本語 reply'));
    selection.toggle('parent');
    expect(selection.ids, isEmpty);
  });
  test('bounded selection retains prior choices and clears on visibility/role loss', () async {
    final (w, _) = await fixture('owner');
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    final rows = [
      for (var i = 0; i < 31; i++)
        {'id': 'm$i', 'channelId': 'c1', 'seq': '${i + 1}', 'content': 'body'},
    ];
    w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
    w.visibleIds['c1'] = rows.map((r) => r['id']!).toSet();
    final selection = MessageSelection(w, thread: false);
    addTearDown(selection.dispose);
    selection.enter('m0');
    selection.selectAll();
    expect(selection.ids, {'m0'});
    expect(selection.error, contains('30'));
    w.server = RaftRecord({'id': 's1', 'role': 'guest'});
    w.setError(null);
    expect(selection.active, isFalse);
    expect(selection.ids, isEmpty);
  });
  testWidgets(
    'real rendered PNG preview has current content and cancellation preserves selection',
    (tester) async {
      final (w, _) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      w.ledger.ingest(messages(), expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = {'parent', 'later'};
      Future<bool?>? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant, dark: true),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () {
                  result = previewMessageImage(
                    ctx,
                    w,
                    messages: [SelectedMessageRow(w.messages.first)],
                    width: 500,
                  );
                },
                child: const Text('Export'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Export'));
      for (
        var i = 0;
        i < 80 && find.byType(MessageImageReview).evaluate().isEmpty;
        i++
      ) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(MessageImageReview), findsOneWidget);
      // Archiving preserves readable message history, and a newly loaded
      // capability projection grants authority. Neither revokes this preview.
      w.channel = RaftChannel({
        ...w.channel!.json,
        'archivedAt': '2026-10-08T00:00:00Z',
        'channelCapabilities': {'canRead': true},
      });
      w.setError(null);
      await tester.pump();
      expect(find.byType(MessageImageReview), findsOneWidget);
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(MessageImageReview),
          matching: find.byType(Image),
        ),
      );
      final bytes = (image.image as MemoryImage).bytes;
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(bytes.length, greaterThan(1000));
      final decoded = await tester.runAsync(
        () => ui.instantiateImageCodec(bytes),
      );
      final frame = await tester.runAsync(() => decoded!.getNextFrame());
      expect(frame!.image.width, 1500);
      expect(frame.image.height, greaterThan(100));
      frame.image.dispose();
      decoded!.dispose();
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => result!), isFalse);
      expect(find.text('Export'), findsOneWidget);
    },
  );
  testWidgets(
    'revocation closes reviewed private PNG while a save picker is pending',
    (tester) async {
      final (w, _) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      var authorized = true;
      final files = PendingSaveFiles();
      // Generated pixels avoid fixture image payloads and exercise real decoding.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 10, 10),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final img = await tester.runAsync(() => picture.toImage(10, 10));
      final data = await tester.runAsync(
        () => img!.toByteData(format: ui.ImageByteFormat.png),
      );
      img!.dispose();
      picture.dispose();
      final png = Uint8List.fromList(data!.buffer.asUint8List());
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => MessageImageReview(
                    controller: w,
                    bytes: png,
                    filename: 'fixture.png',
                    files: files,
                    authorized: () => authorized,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(MessageImageReview), findsOneWidget);
      await tester.tap(find.text('Save image'));
      await tester.pump();
      expect(files.requested.isCompleted, isTrue);
      authorized = false;
      w.setError(null);
      await tester.pumpAndSettle();
      expect(find.byType(MessageImageReview), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      files.destination.complete("/tmp/revoked.png");
      await tester.pumpAndSettle();
      expect(files.committed, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
