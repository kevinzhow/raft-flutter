import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';

import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/media_image_page.dart';

import 'support/scroll_session.dart' show MemoryImageStore;
import 'solid_png.dart';

const _scope = AttachmentImageScope(
  origin: 'https://example.invalid',
  principal: 'fixture',
  server: 'fixture',
  generation: 1,
  role: 'member',
);
const _key = AttachmentImageKey(
  scope: _scope,
  channelId: 'fixture',
  attachmentId: 'fixture',
  revision: 'A',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stored in [true, false]) {
    for (final error in [
      StateError('temporary decoder failure'),
      Exception('Failed to allocate memory for bitmap of size 256 x 256'),
      const OutOfMemoryError(),
      const AttachmentImageBudgetExceeded(),
    ]) {
      test(
        '${stored ? "stored" : "downloaded"} source survives ${error.runtimeType} and manual retry',
        () async {
          final store = MemoryImageStore();
          final bytes = Uint8List.fromList([1, 2, 3]);
          if (stored) await store.write(_key.storeKey, bytes);
          var attempts = 0, downloads = 0;
          final repository = AttachmentImageRepository(
            scope: _scope,
            retainedAuthority: (_) => true,
            store: store,
            decoder: (source, target) async {
              if (attempts++ == 0) throw error;
              return DecodedAttachmentImage(
                provider: MemoryImage(source),
                encodedBytes: 0,
                decodedBytes: 4,
                release: () async {},
              );
            },
          );
          addTearDown(repository.dispose);
          AttachmentImageLease acquire() => repository.acquire(
            _key,
            authorized: () => true,
            foreground: true,
            load: (_) async {
              downloads++;
              return bytes;
            },
          );
          final first = acquire();
          // An unknown decoder failure cannot establish that these bytes are bad.
          await expectLater(
            first.ready,
            throwsA(
              error is AttachmentImageBudgetExceeded
                  ? same(error)
                  : isA<AttachmentImageDecodeUnavailable>().having(
                      (e) => e.cause,
                      'cause',
                      same(error),
                    ),
            ),
          );
          first.release();
          await Future<void>.delayed(Duration.zero);
          expect(await store.read(_key.storeKey), orderedEquals(bytes));
          expect(attempts, 1, reason: 'No automatic retry.');
          final retry = acquire();
          await retry.ready;
          expect(retry.fromStore, isTrue);
          expect(downloads, stored ? 0 : 1);
          expect(attempts, 2);
          retry.release();
        },
      );
    }
  }

  testWidgets(
    'a transient codec failure offers Retry and reuses the downloaded bytes',
    (tester) async {
      final bytes = solidPng(16, 16);
      final store = MemoryImageStore();
      var decodes = 0, downloads = 0;
      final repository = AttachmentImageRepository(
        scope: _scope,
        retainedAuthority: (_) => true,
        store: store,
        decoder: (source, target) async {
          if (decodes++ == 0) {
            throw Exception('Failed to allocate staging buffer.');
          }
          return decodeAttachmentImage(source, target: target);
        },
      );
      addTearDown(repository.dispose);
      final state = GlobalKey<AttachmentLightboxImageState>();
      final zoom = TransformationController();
      addTearDown(zoom.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttachmentLightboxImage(
              key: state,
              imageKey: const Key('image'),
              zoom: zoom,
              title: 'fixture.png',
              placeholder: null,
              previewFailed: false,
              acquire: () => WorkspaceAttachmentImageLease(
                repository.acquire(
                  _key,
                  authorized: () => true,
                  foreground: true,
                  load: (_) async {
                    downloads++;
                    return bytes;
                  },
                ),
                () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        state.currentState!.failure,
        isA<AttachmentImageDecodeUnavailable>(),
      );
      expect(
        find.text(
          'Cannot prepare this image preview right now. Try again or download it to open in another app.',
        ),
        findsOneWidget,
      );
      expect(find.text('Download failed · tap to retry'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('lightbox-retry')));
      for (var i = 0; i < 200 && state.currentState!.full == null; i++) {
        await tester.pump(const Duration(milliseconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(state.currentState!.full, isNotNull);
      expect(state.currentState!.failed, isFalse);
      expect(downloads, 1);
      expect(decodes, 2);
      await tester.pumpWidget(const SizedBox());
      repository.dispose();
      await tester.pump();
    },
  );
}
