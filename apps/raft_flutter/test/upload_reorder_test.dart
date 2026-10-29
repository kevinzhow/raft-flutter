// Web `handleAttachmentDragEnd`: reordering the chips of a draft.
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/upload_reorder.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/composer_attachments_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://reorder.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {
    'maxBytes': 1 << 20,
  };
  final order = <String>[];
  @override
  Future<List<Map<String, dynamic>>> upload(
    String channelId,
    Uint8List bytes,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) async => [
    {'id': 'id-$filename'},
  ];
}

UploadDraft _draft(int key, {bool failed = false}) =>
    UploadDraft('f$key.txt', Uint8List(1), key: key)
      ..error = failed ? 'failed' : null;

void main() {
  test('the chips take the places of the dragged ones', () {
    final drafts = [_draft(1), _draft(2), _draft(3)];
    expect(reorderUploadDrafts(drafts, [2, 3, 1]), isTrue);
    expect([for (final d in drafts) d.key], [2, 3, 1]);
  });

  test('a failed-upload row keeps its position', () {
    final drafts = [_draft(1), _draft(9, failed: true), _draft(2), _draft(3)];
    // The row (key 9) is not a chip: only the chips are reported.
    expect(reorderUploadDrafts(drafts, [3, 1, 2]), isTrue);
    expect([for (final d in drafts) d.key], [3, 9, 1, 2]);
  });

  test('a removed or repeated key leaves the list alone', () {
    final drafts = [_draft(1), _draft(2), _draft(3)];
    expect(reorderUploadDrafts(drafts, [3, 7, 1]), isFalse);
    expect(reorderUploadDrafts(drafts, [3, 3, 1]), isFalse);
    expect([for (final d in drafts) d.key], [1, 2, 3]);
  });

  testWidgets(
    'dragging a pending chip changes the order the files are sent in',
    (tester) async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..channel = RaftChannel({'id': 'channel', 'name': 'general'});
      for (final name in ['one.txt', 'two.txt', 'three.txt']) {
        await w.attachUpload(name, Uint8List.fromList([1, 2]));
      }
      expect(
        [for (final d in w.uploads()) d.filename],
        ['one.txt', 'two.txt', 'three.txt'],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.linux),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: w.composer.changes(w.draftScope()),
              builder: (context, _) => Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 420,
                  child: composerAttachmentsFor(
                    context,
                    w,
                    thread: false,
                    onPreview: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final drafts = w.uploads();
      Finder chip(int index) =>
          find.byKey(ValueKey('composer-attachment-${drafts[index].key}'));
      final gesture = await tester.startGesture(
        tester.getCenter(chip(0)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(chip(2)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        [for (final d in w.uploads()) d.filename],
        ['two.txt', 'three.txt', 'one.txt'],
      );
      w.dispose();
      await client.dispose();
    },
  );
}
