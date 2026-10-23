// Web SelectShareLightbox + screenshotBudget (v1.21.23): the share preview
// copies the PNG to the clipboard, "Share to X" uploads it as a share
// artifact and opens the X intent, and an over-budget or empty render says so.
import 'dart:typed_data';

import 'package:dio/dio.dart' show FormData;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_image_export.dart';
import 'package:raft_flutter/features/message_selection.dart';
import 'package:raft_flutter/features/message_share_artifact.dart';
import 'package:raft_flutter/features/screenshot_budget.dart';
import 'package:raft_flutter/platform/image_clipboard.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_export_test.dart' show messages;
import 'message_presentation_test.dart' show MessageAdapter, fixture;

void main() {
  group('screenshot budget', () {
    test('keeps the preferred ratio while it fits, then falls back 3 2 1', () {
      expect(planScreenshotPixelRatio(500, 1000, 3), 3);
      // 1200 x 1500 at 3x is 16.2M pixels; at 2x it is 7.2M.
      expect(planScreenshotPixelRatio(1200, 1500, 3), 2);
      // 1900 x 2200: 3x and 2x are over 16M, 1x is 4.2M.
      expect(planScreenshotPixelRatio(1900, 2200, 3), 1);
      expect(planScreenshotPixelRatio(500, 1000, 2), 2);
      // Past 1x nothing is rendered.
      expect(planScreenshotPixelRatio(5000, 4000, 3), isNull);
      expect(planScreenshotPixelRatio(500, 5000, 2), isNull);
    });

    test('a render must be a non-empty PNG with a size', () {
      final png = Uint8List.fromList([
        137, 80, 78, 71, 13, 10, 26, 10, //
        0, 0, 0, 13, 73, 72, 68, 82, //
        0, 0, 0, 2, 0, 0, 0, 3, //
      ]);
      expect(() => validateScreenshotPng(png), returnsNormally);
      void rejects(Uint8List bytes, ScreenshotInvalidReason reason) => expect(
        () => validateScreenshotPng(bytes),
        throwsA(
          isA<ScreenshotInvalidOutputError>().having(
            (e) => e.reason,
            'reason',
            reason,
          ),
        ),
      );
      rejects(Uint8List(0), ScreenshotInvalidReason.emptyBlob);
      rejects(
        Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]),
        ScreenshotInvalidReason.notPng,
      );
      rejects(png.sublist(0, 12), ScreenshotInvalidReason.undecodable);
      rejects(
        Uint8List.fromList([...png.sublist(0, 16), 0, 0, 0, 0, 0, 0, 0, 3]),
        ScreenshotInvalidReason.zeroSize,
      );
    });

    test('the X intent carries the page URL and "via Raft"', () {
      expect(
        shareArtifactXIntentUrl(
          'https://app.example/share/abc',
          'via Raft',
        ).toString(),
        'https://twitter.com/intent/tweet?url=https%3A%2F%2Fapp.example%2Fshare%2Fabc&text=via%20Raft',
      );
    });
  });

  Future<(MessageAdapter, Future<bool?>)> open(
    WidgetTester t, {
    required ImageClipboard clipboard,
    required Future<bool> Function(Uri) openExternal,
    String role = 'owner',
    Locale locale = const Locale('en'),
    bool thread = false,
  }) async {
    final (w, transport) = (await t.runAsync(() => fixture(role)))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest(
      messages(),
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {'parent', 'later'};
    late Future<bool?> result;
    await t.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(RaftFamily.elegant),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () {
                result = previewMessageImage(
                  ctx,
                  w,
                  messages: [
                    SelectedMessageRow(w.messageDomain.messages.first),
                  ],
                  width: 500,
                  clipboard: clipboard,
                  openExternal: openExternal,
                );
              },
              child: const Text('Export'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Export'));
    for (
      var i = 0;
      i < 80 && find.byType(MessageImageReview).evaluate().isEmpty;
      i++
    ) {
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    expect(find.byType(MessageImageReview), findsOneWidget);
    return (transport, result);
  }

  testWidgets('Copy image puts the PNG on the clipboard and reads Copied', (
    t,
  ) async {
    Uint8List? copied;
    final (_, _) = await open(
      t,
      clipboard: ImageClipboard(
        supportedOverride: true,
        write: (png) async => copied = Uint8List.fromList(png),
      ),
      openExternal: (_) async => true,
    );
    expect(find.text('Copy image'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('image-review-copy')));
    await t.pump();
    await t.pump();
    expect(copied!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(find.text('Copied'), findsOneWidget);
    expect(find.byType(MessageImageReview), findsOneWidget);
  });

  testWidgets(
    'a failed copy offers Download instead; no clipboard hides the button',
    (t) async {
      await open(
        t,
        clipboard: ImageClipboard(
          supportedOverride: true,
          write: (_) async => throw StateError('blocked'),
        ),
        openExternal: (_) async => true,
      );
      await t.tap(find.byKey(const ValueKey('image-review-copy')));
      await t.pump();
      await t.pump();
      expect(
        find.text("Couldn't copy the image. Use Download instead."),
        findsOneWidget,
      );
      expect(find.text('Copy image'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));

      await open(
        t,
        clipboard: const ImageClipboard(supportedOverride: false),
        openExternal: (_) async => true,
      );
      expect(find.byKey(const ValueKey('image-review-copy')), findsNothing);
    },
  );

  testWidgets(
    'Share to X uploads the PNG as a share artifact and opens the intent',
    (t) async {
      Uri? intent;
      final (box, result) = await open(
        t,
        clipboard: const ImageClipboard(supportedOverride: false),
        openExternal: (uri) async {
          intent = uri;
          return true;
        },
      );
      box.routes['POST /share-artifacts/message-selection'] = (_) => {
        'id': 'art1',
        'url': 'https://app.example/share/art1',
        'imageUrl': 'https://app.example/share/art1.png',
      };
      await t.tap(find.byKey(const ValueKey('image-review-share-link')));
      for (var i = 0; i < 50 && intent == null; i++) {
        await t.pump();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await t.pumpAndSettle();
      final upload = box.calls.singleWhere(
        (c) => c.path == '/share-artifacts/message-selection',
      );
      final form = upload.data as FormData;
      expect(form.fields.single.key, 'channelId');
      expect(form.fields.single.value, 'c1');
      final file = form.files.single;
      expect(file.key, 'image');
      expect(file.value.contentType.toString(), 'image/png');
      expect(file.value.length, greaterThan(1000));
      expect(
        intent.toString(),
        contains('https%3A%2F%2Fapp.example%2Fshare%2Fart1'),
      );
      expect(intent.toString(), endsWith('&text=via%20Raft'));
      // Like Save: the review closes and the selection ends.
      expect(find.byType(MessageImageReview), findsNothing);
      expect(await t.runAsync(() => result), isTrue);
    },
  );

  testWidgets(
    'an answer without a share page keeps the preview and says Share failed',
    (t) async {
      final (box, _) = await open(
        t,
        clipboard: const ImageClipboard(supportedOverride: false),
        openExternal: (_) async => fail('no intent without an artifact'),
      );
      // An answer without a share page is not a share.
      box.routes['POST /share-artifacts/message-selection'] = (_) => {};
      await t.tap(find.byKey(const ValueKey('image-review-share-link')));
      await t.pump();
      for (
        var i = 0;
        i < 240 &&
            !box.calls.any(
              (c) => c.path == '/share-artifacts/message-selection',
            );
        i++
      ) {
        await t.pump(const Duration(milliseconds: 500));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
      }
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 500));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
      }
      expect(find.byType(MessageImageReview), findsOneWidget);
      await t.pump();
      expect(find.text('Share failed', findRichText: true), findsOneWidget);
    },
  );

  testWidgets('zh: the new buttons are Chinese', (t) async {
    await open(
      t,
      clipboard: const ImageClipboard(supportedOverride: true),
      openExternal: (_) async => true,
      locale: const Locale('zh', 'CN'),
    );
    expect(find.text('复制图片'), findsOneWidget);
    expect(find.text('分享到 X'), findsOneWidget);
  });
}
