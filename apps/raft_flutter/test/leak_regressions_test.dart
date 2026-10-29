// Leak-tracking regressions: each test builds the object, tears it down and
// ends; the object-leak report that `flutter_test_config.dart` enables fails
// this file when it leaves a ChangeNotifier / ImageInfo undisposed. None of
// these classes may ever be added to that file's ignore list.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/features/media_image_page.dart';

import 'flutter_test_config.dart' show OwnedFrameCodec;
import 'workspace_shell_contract_test.dart' show mountShell, retire;
import 'workspace_source_location_contract_test.dart' show pageFixture;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
);

const _scope = AttachmentImageScope(
  origin: 'https://example.invalid',
  principal: 'alice',
  server: 'server',
  generation: 1,
  role: 'member',
);

AttachmentImageKey _key(String id) => AttachmentImageKey(
  scope: _scope,
  channelId: 'channel',
  attachmentId: id,
  revision: 'A',
);

AttachmentImageRepository _repository() => AttachmentImageRepository(
  scope: _scope,
  retainedAuthority: (_) => true,
  decoder: (bytes, _) async => DecodedAttachmentImage(
    provider: MemoryImage(bytes),
    encodedBytes: bytes.length,
    decodedBytes: 4,
    release: () async {},
  ),
);

class _FakeCodec implements ui.Codec {
  _FakeCodec(this._next);
  final Future<ui.FrameInfo> _next;
  @override
  int get frameCount => 1;
  @override
  int get repetitionCount => 0;
  @override
  Future<ui.FrameInfo> getNextFrame() => _next;
  @override
  void dispose() {}
}

void main() {
  test('the app leak ignore list never hides what these tests guard', () {
    final ignored = LeakTesting.settings.ignoredLeaks.notDisposed.byClass.keys;
    for (final guarded in [
      'MobileTabbarStore',
      'AttachmentTransfer',
      'ValueNotifier<AttachmentTransferProgress?>',
      'ImageInfo',
      'Image',
    ]) {
      expect(ignored, isNot(contains(guarded)));
    }
  });

  testWidgets('the workspace shell disposes the tab bar store it owns', (
    t,
  ) async {
    final (w, api) = await pageFixture(t, section: 'chat');
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    await mountShell(t, w, false);
    await retire(t);
  });

  group('attachment image repository transfers', () {
    testWidgets('a finished download disposes both progress notifiers', (
      t,
    ) async {
      final repository = _repository();
      final bytes = Completer<Uint8List>();
      final lease = repository.acquire(
        _key('done'),
        authorized: () => true,
        load: (cancel) {
          cancel.progressSink?.call(1, 4);
          return bytes.future;
        },
      );
      await t.pump(const Duration(milliseconds: 10));
      expect(lease.progress.value, isNotNull, reason: 'the fetch reported');
      bytes.complete(Uint8List(4));
      await t.pump(const Duration(milliseconds: 250));
      await lease.ready;
      lease.discard();
      repository.dispose();
      await t.pump();
    });

    testWidgets('an abandoned download disposes both progress notifiers', (
      t,
    ) async {
      final repository = _repository();
      final bytes = Completer<Uint8List>();
      final lease = repository.acquire(
        _key('abandoned'),
        authorized: () => true,
        load: (cancel) {
          cancel.progressSink?.call(1, 4);
          return bytes.future;
        },
      );
      await t.pump(const Duration(milliseconds: 10));
      // The row scrolled away mid-download; the transport finishes later.
      lease.release();
      final stale = lease.ready.then<void>((_) {}, onError: (Object _) {});
      bytes.complete(Uint8List(4));
      await t.pump(const Duration(milliseconds: 250));
      await stale;
      repository.dispose();
      await t.pump();
    });

    testWidgets('a lease that outlives its dropped entry stays harmless', (
      t,
    ) async {
      final repository = _repository();
      final bytes = Completer<Uint8List>();
      final lease = repository.acquire(
        _key('late'),
        authorized: () => true,
        load: (_) => bytes.future,
      );
      await t.pump(const Duration(milliseconds: 10));
      repository.invalidate(_key('late'));
      // A listener attached after the drop must not trip the disposed
      // ChangeNotifier assertion.
      lease.progress.addListener(() {});
      bytes.complete(Uint8List(4));
      await t.pump(const Duration(milliseconds: 250));
      lease.release();
      repository.dispose();
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('a dropped decoded image is disposed before the drop returns', (
    t,
  ) async {
    final repository = AttachmentImageRepository(
      scope: _scope,
      retainedAuthority: (_) => true,
    );
    // Acquire and decode on the real event loop (the decoder needs it).
    late AttachmentImageLease lease;
    final provider = (await t.runAsync(() async {
      lease = repository.acquire(
        _key('decoded'),
        authorized: () => true,
        load: (_) async => _png,
      );
      await lease.ready;
      return lease.value;
    }))!;
    expect(provider, isA<AttachmentBitmapImage>());
    repository.invalidate(_key('decoded'));
    // No pump, no await: the decoded bitmap must already be retired. (It used
    // to be retired after `await provider.evict()`, a microtask that did not
    // always run before the test's owner was torn down: a flaky leak report.)
    expect(
      // ignore: invalid_use_of_protected_member
      () => provider.loadImage(
        provider as AttachmentBitmapImage,
        (buffer, {getTargetSize}) => throw StateError('unused'),
      ),
      throwsA(isA<StaleAttachmentImage>()),
    );
    lease.release();
    repository.dispose();
    imageCache.clear();
  });

  testWidgets('the lightbox disposes the ImageInfo clone it measures', (
    t,
  ) async {
    final zoom = TransformationController();
    addTearDown(zoom.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentLightboxImage(
            imageKey: const Key('image'),
            zoom: zoom,
            image: MemoryImage(_png),
            placeholder: null,
            previewFailed: false,
          ),
        ),
      ),
    );
    // Decode on the real event loop (until the listener has run, however long
    // a loaded machine takes), then deliver the frame.
    final state = t.state<AttachmentLightboxImageState>(
      find.byType(AttachmentLightboxImage),
    );
    for (var i = 0; i < 500 && state.decoded == null; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
    expect(state.decoded, const Size(16, 16), reason: 'the listener ran');
    await t.pumpWidget(const SizedBox());
    imageCache.clear();
  });

  test('a frame that lands after its codec was disposed is disposed', () async {
    // The shape of Flutter's MultiFrameImageStreamCompleter leak: the last
    // listener leaves (the codec is disposed) while getNextFrame is in flight.
    final real = await ui.instantiateImageCodec(_png);
    final late = Completer<ui.FrameInfo>();
    final codec = OwnedFrameCodec(_FakeCodec(late.future));
    final pending = codec.getNextFrame();
    codec.dispose();
    final frame = await real.getNextFrame();
    late.complete(frame);
    final delivered = await pending;
    expect(delivered.image.debugDisposed, isTrue);
    // A frame that lands while the codec is alive belongs to its caller.
    final other = await ui.instantiateImageCodec(_png);
    final alive = OwnedFrameCodec(_FakeCodec(other.getNextFrame()));
    final kept = await alive.getNextFrame();
    expect(kept.image.debugDisposed, isFalse);
    kept.image.dispose();
    other.dispose();
    real.dispose();
  });
}
