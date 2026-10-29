import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/media_image_page.dart';
import 'package:raft_flutter/platform/memory_budgets.dart';

import 'solid_png.dart';

const _scope = AttachmentImageScope(
  origin: 'https://example.invalid',
  principal: 'fixture',
  server: 'fixture',
  generation: 1,
  role: 'member',
);

AttachmentImageKey _key(String id, {String rendition = 'original'}) =>
    AttachmentImageKey(
      scope: _scope,
      channelId: 'fixture',
      attachmentId: id,
      revision: 'one',
      rendition: rendition,
    );

AttachmentImageRepository _repository({int? decodedBytes}) =>
    AttachmentImageRepository(
      scope: _scope,
      retainedAuthority: (_) => true,
      maxEncodedBytes: RaftMemoryBudgets.phone.attachmentImageEncodedBytes,
      maxDecodedBytes:
          decodedBytes ?? RaftMemoryBudgets.phone.attachmentImageDecodedBytes,
      maxActiveDecodedBytes:
          decodedBytes ??
          RaftMemoryBudgets.phone.attachmentImageActiveDecodedBytes,
    );

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 300 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
  expect(done(), isTrue, reason: 'The actual image decoder must complete.');
}

void main() {
  final original = solidPng(5600, 4500);
  final thumbnail = solidPng(320, 257);

  test('a bitmap needs at least four bytes, including narrow sources', () {
    expect(
      () => attachmentDecodeSize(1, 1, null, maxDecodedBytes: 3),
      throwsA(isA<AttachmentImageBudgetExceeded>()),
    );
    for (final (width, height) in [(1, 100000), (100000, 1)]) {
      final (w, h) = attachmentDecodeSize(
        width,
        height,
        null,
        maxDecodedBytes: 16,
      );
      expect(w * h * 4, lessThanOrEqualTo(16));
    }
  });

  testWidgets('a large original opens with its thumbnail still leased', (
    tester,
  ) async {
    final repository = _repository();
    addTearDown(repository.dispose);
    final thumb = repository.acquire(
      _key('large', rendition: 'thumbnail'),
      authorized: () => true,
      load: (_) async => thumbnail,
    );
    await _until(tester, () => thumb.decoded != null);
    final held = thumb.value;
    final state = GlobalKey<AttachmentLightboxImageState>();
    final zoom = TransformationController();
    addTearDown(zoom.dispose);
    var downloads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentLightboxImage(
            key: state,
            imageKey: const Key('original'),
            zoom: zoom,
            title: 'large.png',
            placeholder: held,
            previewFailed: false,
            acquire: () => WorkspaceAttachmentImageLease(
              repository.acquire(
                _key('large'),
                authorized: () => true,
                foreground: true,
                load: (_) async {
                  downloads++;
                  return original;
                },
              ),
              () {},
            ),
          ),
        ),
      ),
    );
    await _until(
      tester,
      () => state.currentState!.full != null || state.currentState!.failed,
    );
    expect(state.currentState!.full, isNotNull);
    expect(state.currentState!.failed, isFalse);
    expect(
      thumb.value,
      same(held),
      reason: 'A displayed thumbnail cannot be evicted.',
    );
    expect(state.currentState!.lease!.lease.decoded!.width, 5600);
    expect(state.currentState!.lease!.lease.decoded!.height, 4500);
    expect(
      repository.decodedByteCount,
      greaterThan(repository.maxDecodedBytes),
    );
    expect(
      repository.decodedByteCount,
      lessThanOrEqualTo(repository.maxActiveDecodedBytes),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(downloads, 1);
    expect(find.text('Download failed · tap to retry'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(
      repository.decodedByteCount,
      320 * 257 * 4,
      reason: 'Closing releases the borrowed preview capacity.',
    );
    thumb.release();
    repository.dispose();
    await tester.pump();
  });

  testWidgets(
    'two large pages can overlap without overrunning the phone budget',
    (tester) async {
      final repository = _repository();
      addTearDown(repository.dispose);
      final thumb = repository.acquire(
        _key('large', rendition: 'thumbnail'),
        authorized: () => true,
        load: (_) async => thumbnail,
      );
      await _until(tester, () => thumb.decoded != null);
      final pages = [
        for (final id in ['previous', 'next'])
          repository.acquire(
            _key(id),
            authorized: () => true,
            foreground: true,
            load: (_) async => original,
          ),
      ];
      final failures = <Object>[];
      var completed = 0;
      for (final page in pages) {
        unawaited(
          page.ready.then<void>(
            (_) => completed++,
            onError: (Object e) {
              failures.add(e);
              completed++;
            },
          ),
        );
      }
      await _until(tester, () => completed == 2);
      expect(failures, isEmpty);
      for (final page in pages) {
        expect(
          page.decoded!.width,
          greaterThan(2000),
          reason: 'Paging must retain a useful zoom resolution.',
        );
      }
      expect(
        repository.decodedByteCount,
        lessThanOrEqualTo(repository.maxActiveDecodedBytes),
      );
      for (final page in pages) {
        page.release();
      }
      thumb.release();
      repository.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'memory pressure keeps the current image and constrains new decodes temporarily',
    (tester) async {
      var now = Duration.zero;
      final repository = AttachmentImageRepository(
        scope: _scope,
        retainedAuthority: (_) => true,
        maxDecodedBytes: 64 * 1024,
        maxActiveDecodedBytes: 512 * 1024,
        clock: () => now,
      );
      addTearDown(repository.dispose);
      final bytes = solidPng(256, 256);
      AttachmentImageLease open(String id) => repository.acquire(
        _key(id),
        authorized: () => true,
        foreground: true,
        load: (_) async => bytes,
      );
      final current = open('current');
      await _until(tester, () => current.decoded != null);
      expect(current.decoded!.width, 256);
      repository.trimIdle(pressure: true);
      expect(
        current.decoded!.width,
        256,
        reason: 'An OS warning cannot blank the displayed image.',
      );
      final next = open('after-warning');
      await _until(tester, () => next.decoded != null);
      expect(next.decoded!.width, 128);
      current.discard();
      next.discard();
      expect(repository.decodedByteCount, 0);
      now = const Duration(seconds: 31);
      final recovered = open('later');
      await _until(tester, () => recovered.decoded != null);
      expect(recovered.decoded!.width, 256);
      recovered.release();
      expect(
        repository.decodedByteCount,
        lessThanOrEqualTo(repository.maxDecodedBytes),
        reason: 'Released oversized previews cannot stay in the idle cache.',
      );
      repository.dispose();
      await tester.pump();
    },
  );

  for (final kind in ['memory', 'decode', 'network']) {
    testWidgets('$kind failure has the right explanation and retry action', (
      tester,
    ) async {
      final repository = _repository(decodedBytes: kind == 'memory' ? 8 : null);
      addTearDown(repository.dispose);
      final small = solidPng(16, 16);
      final thumb = repository.acquire(
        _key('failure', rendition: 'thumbnail'),
        authorized: () => true,
        load: (_) async => small,
      );
      await _until(tester, () => thumb.decoded != null);
      AttachmentImageLease? blocker;
      if (kind == 'memory') {
        blocker = repository.acquire(
          _key('other-visible-image'),
          authorized: () => true,
          load: (_) async => small,
        );
        await _until(tester, () => blocker!.decoded != null);
      }
      final state = GlobalKey<AttachmentLightboxImageState>();
      final zoom = TransformationController();
      addTearDown(zoom.dispose);
      var downloads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttachmentLightboxImage(
              key: state,
              imageKey: const Key('failure-image'),
              zoom: zoom,
              title: 'fixture.png',
              placeholder: thumb.value,
              previewFailed: false,
              acquire: () => WorkspaceAttachmentImageLease(
                repository.acquire(
                  _key('failure'),
                  authorized: () => true,
                  foreground: true,
                  load: (_) async {
                    downloads++;
                    if (kind == 'network' && downloads == 1) {
                      throw StateError('offline');
                    }
                    return kind == 'decode'
                        ? Uint8List.fromList([1, 2, 3])
                        : small;
                  },
                ),
                () {},
              ),
            ),
          ),
        ),
      );
      await _until(tester, () => state.currentState!.failed);
      final retry = find.byKey(const ValueKey('lightbox-retry'));
      if (kind == 'network' || kind == 'memory') {
        if (kind == 'network') {
          expect(find.text('Download failed · tap to retry'), findsOneWidget);
        } else {
          expect(
            find.text(
              'Not enough memory to preview this image. Download it to open in another app.',
            ),
            findsOneWidget,
          );
          blocker!.discard();
        }
        expect(retry, findsOneWidget);
        await tester.tap(retry);
        await _until(tester, () => state.currentState!.full != null);
        expect(downloads, 2);
        expect(state.currentState!.failed, isFalse);
      } else {
        expect(
          find.text(
            kind == 'memory'
                ? 'Not enough memory to preview this image. Download it to open in another app.'
                : 'Cannot decode this image. Download it to open in another app.',
          ),
          findsOneWidget,
        );
        expect(find.text('Download failed · tap to retry'), findsNothing);
        expect(retry, findsNothing);
      }
      await tester.pump(const Duration(seconds: 2));
      expect(
        downloads,
        kind == 'decode' ? 1 : 2,
        reason: 'No automatic retry loop.',
      );
      await tester.pumpWidget(const SizedBox());
      thumb.release();
      repository.dispose();
      await tester.pump();
    });
  }
}
