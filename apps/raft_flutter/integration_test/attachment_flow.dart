import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

/// Proves native rendering + actual multipart/storage/message binding. The
/// separate host-driven picker exercise must cover the OS document dialogs.
Future<void> verifyAttachmentFlow(
  WidgetTester tester,
  WorkspaceController w,
  Future<void> Function(String) capture,
) async {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
  );
  final suffix = DateTime.now().microsecondsSinceEpoch;
  final imageName = 'native-image-$suffix.png';
  final textName = 'native-日本語-$suffix.txt';
  var fail = true;
  final failure = InterceptorsWrapper(
    onRequest: (options, handler) {
      if (fail &&
          options.method == 'POST' &&
          options.path == '/attachments/upload') {
        fail = false;
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
      } else {
        handler.next(options);
      }
    },
  );
  w.client.http.interceptors.add(failure);
  try {
    await w.attachUpload(imageName, png);
    final failed = w.uploads().single;
    expect(failed.error, isNotNull);
    expect(w.uploadsReady(), false);
    for (
      var i = 0;
      i < 100 && find.byTooltip('Retry upload').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (find.byTooltip('Retry upload').evaluate().isEmpty) {
      await capture('linux-attachment-retry-failure');
      debugPrint(
        'Attachment retry checkpoint: section=${w.section} loading=${w.loading} channelLoading=${w.channelLoading} uploadCount=${w.uploads().length} composerCount=${find.byType(RaftComposer).evaluate().length} chipCount=${find.byType(RaftUploadChip).evaluate().length} language=${w.client.user?.json['displayLanguage']} retryIconCount=${find.byIcon(Icons.refresh).evaluate().length} scaffoldCount=${find.byType(Scaffold).evaluate().length} setupText=${find.text('Set up your workspace').evaluate().length} chatWidgets=${find.byType(Chat).evaluate().length}',
      );
    }
    expect(find.byTooltip('Retry upload'), findsOneWidget);
    await tester.tap(find.byTooltip('Retry upload'));
    for (var i = 0; i < 150 && !w.uploadsReady(); i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(failed.id, isNotNull);
    expect(failed.error, isNull);
    await w.attachUpload(
      textName,
      Uint8List.fromList(utf8.encode('中文 日本語 attachment fixture')),
    );
    expect(w.uploads(), hasLength(2));
    expect(w.uploadsReady(), true);
    final ids = w.uploads().map((u) => u.id).toSet();
    expect(await w.send('Native attachment delivery $suffix'), true);
    final message = w.messages.singleWhere(
      (m) => m.content == 'Native attachment delivery $suffix',
    );
    expect(message.attachments.map((m) => m['id']).toSet(), ids);
    expect(w.uploads(), isEmpty);
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find
          .byWidgetPredicate(
            (widget) =>
                widget is RaftAttachmentCard && widget.filename == imageName,
          )
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    final card = find.byWidgetPredicate(
      (widget) => widget is RaftAttachmentCard && widget.filename == imageName,
    );
    expect(card, findsOneWidget);
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 150; i++) {
      final view = tester.widget<RaftAttachmentCard>(card);
      if (view.preview != null) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.widget<RaftAttachmentCard>(card).preview, isNotNull);
    final previewAction = find.descendant(
      of: card,
      matching: find.byTooltip('Preview $imageName'),
    );
    expect(previewAction, findsOneWidget);
    await tester.tap(previewAction);
    await tester.pumpAndSettle();
    final decoded = find.byKey(
      ValueKey(
        'attachment-image-${message.attachments.singleWhere((a) => a['filename'] == imageName)['id']}',
      ),
    );
    expect(decoded, findsOneWidget);
    final image = tester.widget<Image>(decoded);
    expect(image.image, isA<MemoryImage>());
    await capture('linux-attachment-preview');
    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
  } finally {
    w.client.http.interceptors.remove(failure);
  }
}
