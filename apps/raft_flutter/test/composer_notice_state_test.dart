import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../../../packages/raft_ui/test/task_typography_test.dart'
    show loadTaskFonts;
import '../../../tool/testing/system_fonts.dart';
import 'message_presentation_test.dart' show MessageAdapter, fixture;

// Kevin 2026-10-13: "Wait for attachments to finish uploading before sending."
// stayed above the composer after the upload finished and the message was
// sent. A composer notice is bound to its cause (the uploads) and to the
// composer visit; these tests pin every way the cause can end.
const _waiting = 'Wait for attachments to finish uploading before sending.';
const _failed = 'Remove or retry failed attachments before sending.';

String _text(String key, Map<String, Object> args) => args.entries.fold(
  key,
  (text, e) => text.replaceAll('{${e.key}}', '${e.value}'),
);

class _Chat {
  _Chat(this.tester, this.w, this.api);
  final WidgetTester tester;
  final WorkspaceController w;
  final MessageAdapter api;
  final uploads = <String, Completer<Map<String, dynamic>>>{};
  final sent = <Map<String, dynamic>>[];

  Future<void> pumpFor(int ms) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }

  /// Attaches [name]; the upload stays in flight until [finish].
  Future<void> attach(String name) async {
    unawaited(
      w.attachSelection([
        (name: name, bytes: Uint8List.fromList([1, 2, 3])),
      ], text: _text),
    );
    await pumpFor(30);
  }

  Future<void> finish(String name) async {
    uploads[name]!.complete({
      'attachments': [
        {'id': 'att-$name', 'filename': name},
      ],
    });
    await pumpFor(30);
  }

  /// Sends with Enter (the Send button is disabled while files are not
  /// sendable; Web's handleSubmit runs from the keyboard).
  Future<void> tapSend() async {
    final field = find.byType(EditableText);
    if (tester.widget<EditableText>(field).controller.text.isEmpty) {
      await tester.enterText(field, 'hi');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpFor(30);
  }
}

final _shots = Platform.environment['RAFT_NOTICE_SHOTS'];
final _shotKey = GlobalKey();

Future<_Chat> _open(WidgetTester tester) async {
  final (w, api) = (await tester.runAsync(() => fixture('member')))!;
  addTearDown(w.dispose);
  w.messageDomain.ledger.switchServer('s1');
  final chat = _Chat(tester, w, api);
  api.routes['GET /attachments/upload-capabilities'] = (_) => {
    'maxBytes': 1 << 20,
  };
  api.routes['POST /attachments/upload'] = (o) async {
    final name = (o.data as FormData).files.single.value.filename!;
    return (chat.uploads[name] = Completer()).future;
  };
  api.routes['POST /v2/messages'] = (o) {
    chat.sent.add(Map<String, dynamic>.from(o.data as Map));
    return {
      'message': {
        'id': 'm${chat.sent.length}',
        'channelId': 'c1',
        'content': '',
        'seq': '${chat.sent.length}',
      },
    };
  };
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(
        RaftFamily.elegant,
      ).copyWith(platform: TargetPlatform.linux),
      home: Scaffold(
        body: RepaintBoundary(
          key: _shotKey,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: RaftChatView(controller: w),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return chat;
}

void main() {
  testWidgets('the upload notice goes away when the upload finishes', (
    tester,
  ) async {
    final chat = await _open(tester);
    await chat.attach('a.png');
    await chat.tapSend();
    expect(find.text(_waiting), findsOneWidget);
    // Unrelated rebuilds keep it while the cause holds.
    await chat.pumpFor(50);
    expect(find.text(_waiting), findsOneWidget);
    await chat.finish('a.png');
    expect(find.text(_waiting), findsNothing);
    expect(chat.w.composerErrorFor(), isNull);
  });

  testWidgets('it does not come back after the upload finished', (
    tester,
  ) async {
    final chat = await _open(tester);
    await chat.attach('a.png');
    await chat.tapSend();
    await chat.finish('a.png');
    expect(find.text(_waiting), findsNothing);
    // A second attachment starts uploading: the old notice must not return.
    await chat.attach('b.png');
    expect(find.text(_waiting), findsNothing);
  });

  testWidgets('removing the attachment clears it', (tester) async {
    final chat = await _open(tester);
    await chat.attach('a.png');
    await chat.tapSend();
    expect(find.text(_waiting), findsOneWidget);
    chat.w.removeUpload(chat.w.uploads().single);
    await chat.pumpFor(30);
    expect(find.text(_waiting), findsNothing);
  });

  testWidgets('sending successfully clears any composer notice', (
    tester,
  ) async {
    final chat = await _open(tester);
    await chat.attach('a.png');
    await chat.finish('a.png');
    chat.w.setComposerError(
      'Folders were skipped — only individual files can be uploaded.',
    );
    await chat.pumpFor(30);
    expect(find.textContaining('Folders were skipped'), findsOneWidget);
    await chat.tapSend();
    await chat.pumpFor(50);
    expect(chat.sent, hasLength(1));
    expect(find.textContaining('Folders were skipped'), findsNothing);
    expect(chat.w.composerErrorFor(), isNull);
  });

  testWidgets('a blocked-send notice follows the upload state, not a flag', (
    tester,
  ) async {
    final chat = await _open(tester);
    await chat.attach('a.png');
    await chat.tapSend();
    expect(find.text(_waiting), findsOneWidget);
    // The upload fails: the "uploading" notice no longer describes anything.
    chat.uploads['a.png']!.completeError(
      const RaftApiException('Upload failed'),
    );
    await chat.pumpFor(50);
    expect(find.text(_waiting), findsNothing);
    expect(find.text(_failed), findsNothing);
    // Sending now explains the new reason.
    await chat.tapSend();
    expect(find.text(_failed), findsOneWidget);
  });

  testWidgets('leaving the channel and coming back does not resurrect it', (
    tester,
  ) async {
    final chat = await _open(tester);
    final other = RaftChannel({'id': 'c2', 'name': 'other', 'joined': true});
    chat.w.channels = [chat.w.channel!, other];
    await chat.attach('a.png');
    await chat.tapSend();
    expect(find.text(_waiting), findsOneWidget);
    final first = chat.w.channel!;
    chat.w.channel = other;
    chat.w.notifyListeners();
    await chat.pumpFor(30);
    expect(find.text(_waiting), findsNothing);
    chat.w.channel = first;
    chat.w.notifyListeners();
    await chat.pumpFor(30);
    // The upload is still running, but the notice belonged to the old visit.
    expect(chat.w.uploads(), isNotEmpty);
    expect(find.text(_waiting), findsNothing);
  });

  // Evidence for the screenshot case (set RAFT_NOTICE_SHOTS to a directory).
  // RAFT_NOTICE_BEFORE=1 raises the notice with no cause, which is how it
  // behaved before: nothing ended it when the upload finished.
  testWidgets('screenshots: send while uploading, then the upload finishes', (
    tester,
  ) async {
    final dir = _shots;
    if (dir == null) {
      markTestSkipped('set RAFT_NOTICE_SHOTS to write screenshots');
      return;
    }
    final fonts = missingTestFontReason(cjkTestFonts());
    if (fonts != null) {
      markTestSkipped(fonts);
      return;
    }
    await loadTaskFonts(tester);
    await tester.runAsync(() async {
      for (final face in ['Regular', 'Bold']) {
        final file = systemTestFont('opentype/noto/NotoSansCJK-$face.ttc');
        await (FontLoader('sans-serif')..addFont(
              Future.value(ByteData.sublistView(file.readAsBytesSync())),
            ))
            .load();
      }
    });
    tester.view.physicalSize = const Size(1100, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final before = Platform.environment['RAFT_NOTICE_BEFORE'] == '1';
    final tag = before ? 'before' : 'after';
    final chat = await _open(tester);
    Future<void> shot(String name) async {
      final boundary =
          _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/composer-$tag-$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await chat.attach('report.pdf');
    await chat.tapSend();
    if (before) {
      chat.w.setComposerError(_waiting);
      await chat.pumpFor(30);
    }
    await shot('1-sent-while-uploading');
    await chat.finish('report.pdf');
    await shot('2-upload-finished');
  });
}
