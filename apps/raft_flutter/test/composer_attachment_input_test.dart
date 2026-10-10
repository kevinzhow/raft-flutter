import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/composer_attachment_input.dart';
import 'package:raft_flutter/platform/clipboard_attachments.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

/// Drives the real desktop_drop plugin entry point the way GTK does.
Future<void> _gtk(String method, Object? arguments) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'desktop_drop',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue);
}

List<String> _uploaded(MessageAdapter api) => [
  for (final call in api.calls.where((c) => c.path == '/attachments/upload'))
    (call.data as FormData).files.single.value.filename!,
];

Future<(WorkspaceController, MessageAdapter)> _chat(WidgetTester tester) async {
  final (w, api) = (await tester.runAsync(() => fixture('member')))!;
  addTearDown(w.dispose);
  w.ledger.switchServer('s1');
  api.routes['GET /attachments/upload-capabilities'] = (_) => {
    'maxBytes': 1 << 20,
  };
  var next = 0;
  api.routes['POST /attachments/upload'] = (o) => {
    'attachments': [
      {
        'id': 'att-${next++}',
        'filename': (o.data as FormData).files.single.value.filename,
      },
    ],
  };
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(body: RaftChatView(controller: w)),
    ),
  );
  await tester.pumpAndSettle();
  return (w, api);
}

void main() {
  late Directory temp;
  late String notes, folder;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('raft-composer-drop');
    notes = p.join(temp.path, 'notes.txt');
    await File(notes).writeAsString('meeting notes');
    folder = p.join(temp.path, 'designs');
    await Directory(folder).create();
  });
  tearDown(() => temp.delete(recursive: true));

  testWidgets('desktop file drop shows the overlay and attaches files', (
    tester,
  ) async {
    final (w, api) = await _chat(tester);
    final composer = find.byType(RaftComposer);
    final at = tester.getCenter(composer);
    final overlay = find.byType(RaftComposerDropOverlay);
    expect(overlay, findsNothing);

    // GTK: motion → leave → data. A URL/text drag carries no local file.
    await _gtk('updated', [at.dx, at.dy]);
    await tester.pump();
    expect(overlay, findsOneWidget);
    expect(tester.getRect(overlay), tester.getRect(composer));
    await _gtk('exited', null);
    await tester.pump();
    expect(overlay, findsNothing);
    await _gtk('performOperation_linux', [
      'https://example.com/page',
      [at.dx, at.dy],
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(_uploaded(api), isEmpty);
    expect(w.composerErrorFor(), isNull);

    // Folder only: Web `foldersCantUpload`, nothing uploaded.
    await _gtk('updated', [at.dx, at.dy]);
    await _gtk('exited', null);
    await _gtk('performOperation_linux', [
      Uri.file(folder).toString(),
      [at.dx, at.dy],
    ]);
    await _until(tester, () => w.composerErrorFor() != null);
    expect(
      find.text("Folders can't be uploaded — drag individual files instead."),
      findsOneWidget,
    );
    expect(_uploaded(api), isEmpty);

    // A drop outside the composer is not the composer's.
    await _gtk('performOperation_linux', [
      Uri.file(notes).toString(),
      [at.dx, 4.0],
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(_uploaded(api), isEmpty);

    // Mixed drop (duplicate listed twice): the file uploads once and the
    // selection decision then owns the banner, as in Web.
    await _gtk('updated', [at.dx, at.dy]);
    await _gtk('exited', null);
    await _gtk('performOperation_linux', [
      '${Uri.file(notes)}\r\n${Uri.file(folder)}\r\n${Uri.file(notes)}\r\n',
      [at.dx, at.dy],
    ]);
    await _until(tester, () => w.uploadsReady() && w.uploads().isNotEmpty);
    await tester.pumpAndSettle();
    expect(_uploaded(api), ['notes.txt']);
    expect(w.uploads().single.filename, 'notes.txt');
    expect(w.composerErrorFor(), isNull);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a route covering the chat takes the composer out of drops', (
    tester,
  ) async {
    final (w, api) = await _chat(tester);
    final at = tester.getCenter(find.byType(RaftComposer));
    showDialog<void>(
      context: tester.element(find.byType(RaftComposer)),
      builder: (_) => const SizedBox(width: 10, height: 10),
    );
    await tester.pumpAndSettle();
    await _gtk('updated', [at.dx, at.dy]);
    await tester.pump();
    expect(find.byType(RaftComposerDropOverlay), findsNothing);
    await _gtk('exited', null);
    await _gtk('performOperation_linux', [
      Uri.file(notes).toString(),
      [at.dx, at.dy],
    ]);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(_uploaded(api), isEmpty);
    expect(w.uploads(), isEmpty);
  });

  testWidgets('Ctrl+V attaches copied files or an image; text still pastes', (
    tester,
  ) async {
    var files = <String>[];
    Uint8List? image;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('pasteboard'),
      (call) async => switch (call.method) {
        'files' => files,
        'image' => image,
        _ => null,
      },
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => switch (call.method) {
        'Clipboard.getData' => {'text': 'copied words'},
        'Clipboard.hasStrings' => {'value': true},
        _ => null,
      },
    );
    final (w, api) = await _chat(tester);
    final editor = find.descendant(
      of: find.byType(RaftComposer),
      matching: find.byType(TextField),
    );
    String text() => tester.widget<TextField>(editor).controller!.text;
    Future<void> paste() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }

    await tester.tap(editor);
    await tester.pump();

    files = [notes];
    await paste();
    await _until(tester, () => _uploaded(api).length == 1);
    expect(_uploaded(api), ['notes.txt']);
    expect(text(), isEmpty);

    files = [];
    image = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
    await paste();
    await _until(tester, () => _uploaded(api).length == 2);
    expect(_uploaded(api).last, ClipboardAttachments.imageName);
    expect(text(), isEmpty);

    image = null;
    await paste();
    await _until(tester, () => text().isNotEmpty);
    expect(text(), 'copied words');
    expect(_uploaded(api), hasLength(2));

    // Android keyboard image insertion feeds the same upload flow.
    tester
        .widget<TextField>(editor)
        .contentInsertionConfiguration!
        .onContentInserted(
          KeyboardInsertedContent(
            mimeType: 'image/gif',
            uri: 'content://com.keyboard/stickers/party',
            data: Uint8List.fromList([1, 2, 3]),
          ),
        );
    await _until(tester, () => _uploaded(api).length == 3);
    expect(_uploaded(api).last, 'party.gif');
    expect(w.uploads().map((u) => u.filename), [
      'notes.txt',
      'image.png',
      'party.gif',
    ]);
    expect(tester.takeException(), isNull);
  });

  test(
    'clipboard reader prefers files, skips folders and unreadable paths',
    () async {
      final read = await ClipboardAttachments(
        files: () async => [
          folder,
          notes,
          p.join(temp.path, 'gone.txt'),
          'relative.txt',
        ],
        image: () async => Uint8List.fromList([1]),
        desktop: true,
      ).read();
      expect(read.map((f) => f.name), ['notes.txt']);
      final android = await ClipboardAttachments(
        files: () async => ['content://media/1'],
        image: () async => Uint8List.fromList([1]),
        desktop: false,
      ).read();
      expect(android.single.name, 'image.png');
      final failing = await ClipboardAttachments(
        files: () => Future.error(PlatformException(code: 'x')),
        image: () async => null,
        desktop: true,
      ).read();
      expect(failing, isEmpty);
    },
  );

  test('keyboard content names keep or infer their extension', () {
    String name(String uri, String mime) =>
        insertedName(KeyboardInsertedContent(mimeType: mime, uri: uri));
    expect(name('content://k/a/photo.webp', 'image/webp'), 'photo.webp');
    expect(name('content://k/a/123', 'image/jpeg'), '123.jpg');
    expect(name('', 'image/png'), 'image.png');
  });
}
