import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Future<void> _pump(
  WidgetTester tester,
  List<RaftComposerAttachment> items, {
  bool dark = false,
  TargetPlatform platform = TargetPlatform.linux,
  ValueChanged<RaftComposerAttachment>? onRemove,
  ValueChanged<RaftComposerAttachment>? onRetry,
  ValueChanged<RaftComposerAttachment>? onPreview,
}) => tester.pumpWidget(
  MaterialApp(
    theme: raftTheme(dark: dark).copyWith(platform: platform),
    home: Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 16,
            top: 16,
            width: 400,
            child: RaftComposerAttachments(
              items: items,
              onRemove: onRemove ?? (_) {},
              onRetry: onRetry,
              onPreview: onPreview,
            ),
          ),
        ],
      ),
    ),
  ),
);

RaftComposerAttachment _image(
  String id, {
  RaftComposerAttachmentStatus status = RaftComposerAttachmentStatus.ready,
  int progress = 0,
}) => RaftComposerAttachment(
  id: id,
  name: '$id.png',
  mimeType: 'image/png',
  preview: _png,
  status: status,
  progress: progress,
);

RaftComposerAttachment _file(
  String id, {
  String mime = 'application/pdf',
  RaftComposerAttachmentStatus status = RaftComposerAttachmentStatus.ready,
  String? error,
  bool canRetry = true,
  bool quota = false,
}) => RaftComposerAttachment(
  id: id,
  name: '$id.pdf',
  mimeType: mime,
  status: status,
  error: error,
  canRetry: canRetry,
  quotaBlocked: quota,
);

void main() {
  testWidgets('image chips are 64px, files 176x64', (tester) async {
    await _pump(tester, [_image('a'), _file('b')]);
    expect(
      tester.getSize(find.byKey(const ValueKey('composer-attachment-box-a'))),
      const Size(64, 64),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('composer-attachment-box-b'))),
      const Size(176, 64),
    );
    expect(find.text('application/pdf'), findsOneWidget);
    // 8px gap between chips (`gap-2`).
    final a = tester.getRect(
      find.byKey(const ValueKey('composer-attachment-box-a')),
    );
    final b = tester.getRect(
      find.byKey(const ValueKey('composer-attachment-box-b')),
    );
    expect(b.left - a.right, 8);
  });

  testWidgets('a file without a type shows the localized fallback', (
    tester,
  ) async {
    await _pump(tester, [_file('x', mime: '')]);
    expect(find.text('file'), findsOneWidget);
  });

  testWidgets('checking, uploading, finishing and failed overlays', (
    tester,
  ) async {
    await _pump(tester, [
      _file('c', status: RaftComposerAttachmentStatus.checking),
      _image('u0', status: RaftComposerAttachmentStatus.uploading),
      _image(
        'u1',
        status: RaftComposerAttachmentStatus.uploading,
        progress: 42,
      ),
      _image(
        'u2',
        status: RaftComposerAttachmentStatus.uploading,
        progress: 99,
      ),
      _file(
        'q',
        status: RaftComposerAttachmentStatus.failed,
        error: 'Monthly file upload quota exceeded',
        quota: true,
      ),
    ]);
    expect(find.text('Checking file…'), findsOneWidget);
    expect(find.text('Uploading'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('Finishing upload…'), findsOneWidget);
    // A quota failure keeps its chip with the failed overlay.
    expect(find.text('Upload failed'), findsOneWidget);
    expect(find.byKey(const ValueKey('composer-attachment-q')), findsOneWidget);
  });

  testWidgets('failed uploads leave the chips for alert rows with retry', (
    tester,
  ) async {
    final retried = <String>[], removed = <String>[];
    await _pump(
      tester,
      [
        _image('ok'),
        _file(
          'bad',
          status: RaftComposerAttachmentStatus.failed,
          error: 'The file reached Raft, but saving it timed out.',
        ),
        _file(
          'gone',
          status: RaftComposerAttachmentStatus.failed,
          error: 'File checking was interrupted. Remove it and attach again.',
          canRetry: false,
        ),
      ],
      onRetry: (i) => retried.add(i.id),
      onRemove: (i) => removed.add(i.id),
    );
    expect(find.byKey(const ValueKey('composer-attachment-bad')), findsNothing);
    expect(
      find.byKey(const ValueKey('composer-upload-error-bad')),
      findsOneWidget,
    );
    expect(
      find.text('The file reached Raft, but saving it timed out.'),
      findsOneWidget,
    );
    // Only the retryable row offers "Tap to retry".
    expect(find.text('Tap to retry'), findsOneWidget);
    await tester.tap(find.text('Tap to retry'));
    expect(retried, ['bad']);
    final rows = find.byKey(const ValueKey('composer-attachment-remove'));
    await tester.tap(rows.last);
    expect(removed, ['gone']);
  });

  testWidgets('desktop: remove is always shown and removes on tap', (
    tester,
  ) async {
    // The Raft chip carries its remove sticker at all times (no hover reveal).
    final removed = <String>[];
    await _pump(tester, [_image('a')], onRemove: (i) => removed.add(i.id));
    final remove = find.byKey(const ValueKey('composer-attachment-remove'));
    expect(remove, findsOneWidget);
    final chip = tester.getRect(
      find.byKey(const ValueKey('composer-attachment-box-a')),
    );
    final badge = tester.getRect(remove);
    expect(badge.width, badge.height);
    // The sticker sits on the chip's top-right corner.
    expect(badge.center.dx, greaterThan(chip.center.dx));
    expect(badge.center.dy, lessThan(chip.center.dy));
    await tester.tap(remove);
    expect(removed, ['a']);
  });

  testWidgets('touch: the remove sticker is shown and removes on tap', (
    tester,
  ) async {
    final removed = <String>[];
    await _pump(
      tester,
      [_image('a')],
      platform: TargetPlatform.android,
      onRemove: (i) => removed.add(i.id),
    );
    final remove = find.byKey(const ValueKey('composer-attachment-remove'));
    expect(remove, findsOneWidget);
    await tester.tap(remove);
    expect(removed, ['a']);
  });

  testWidgets('a ready image previews; checking images do not', (tester) async {
    final previewed = <String>[];
    await _pump(tester, [
      _image('a'),
      _image('b', status: RaftComposerAttachmentStatus.checking),
    ], onPreview: (i) => previewed.add(i.id));
    await tester.tap(
      find.byKey(const ValueKey('composer-attachment-box-a')),
      warnIfMissed: false,
    );
    expect(previewed, ['a']);
    await tester.tap(
      find.byKey(const ValueKey('composer-attachment-box-b')),
      warnIfMissed: false,
    );
    expect(previewed, ['a']);
  });

  testWidgets(
    'RaftComposer places attachments below notices and above the card',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RaftComposer(
                onSend: (_) async => true,
                hasAttachments: true,
                accessoryRow: const RaftComposerNotice(message: 'notice'),
                attachments: RaftComposerAttachments(
                  items: [_image('a')],
                  onRemove: (_) {},
                ),
                onAttach: () {},
                onImagePick: () {},
              ),
            ),
          ),
        ),
      );
      final host = tester.getRect(
        find.byKey(const ValueKey('composer-host-slot')),
      );
      final notice = tester.getRect(find.text('notice'));
      final chip = tester.getRect(
        find.byKey(const ValueKey('composer-attachment-box-a')),
      );
      final shell = tester.getRect(
        find.byKey(const ValueKey('composer-shell-slot')),
      );
      // The chip sits inside the host (below its rule), between notice and card.
      expect(chip.top, greaterThan(host.top + 12 - 1));
      expect(chip.top, greaterThan(notice.bottom));
      expect(shell.top - chip.bottom, 8);
      // Web: media button, then file button.
      expect(find.byTooltip('Attach Media'), findsOneWidget);
      expect(find.byTooltip('Attach File'), findsOneWidget);
    },
  );

  testWidgets(
    'a blocked send reports instead of sending; uploads show the send spinner',
    (tester) async {
      var blocked = 0, sent = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RaftComposer(
                onSend: (_) async {
                  sent++;
                  return true;
                },
                hasAttachments: true,
                canSend: false,
                submitSpinner: true,
                submitTooltip: 'Uploading attachments…',
                onSendBlocked: () => blocked++,
                initialDraft: 'hi',
              ),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Uploading attachments…'), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(blocked, 1);
      expect(sent, 0);
    },
  );

  testWidgets('the drop overlay covers the composer box', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 100,
            child: RaftComposerDropOverlay(),
          ),
        ),
      ),
    );
    final frame = tester.getRect(
      find.byKey(const ValueKey('composer-drop-overlay')),
    );
    // raft-ui 0.7 `composerDropOverlay` is `inset-0`: it covers the whole box
    // and takes no pointer input.
    expect(frame, const Rect.fromLTWH(0, 0, 300, 100));
  });
}
