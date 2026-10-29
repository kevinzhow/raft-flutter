import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/media_image_page.dart';
import 'package:raft_flutter/features/attachment_image_zoom.dart';

import 'support/address_wait_harness.dart';
import 'solid_png.dart';

import 'parity/cases/ext_thread_attachments.dart';
import 'parity/parity_harness.dart';
import 'support/repo_root.dart';

void main() {
  testWidgets('real address query without preview mounts the source Spinner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final input = jsonDecode(
      File.fromUri(
        repoRoot().uri.resolve(
          'tool/parity-ext/fixtures/threadattachments.json',
        ),
      ).readAsStringSync(),
    ) as Map<String, dynamic>;
    final ctx = ParityContext(
      caseJson: {
        'id': 'components.thread-ext.attachment.image.pending-address-no-preview.brutal',
        'viewport': {'width': 1280, 'height': 800, 'density': 1},
        'capture': {'crop': 'viewport'},
        'variants': [
          {
            'props': {
              'host': 'image',
              'images': '1',
              'index': '0',
              'pendingSpinner': '1',
            },
          },
        ],
      },
      fixtures: {
        'ext:threadattachments': input,
        'fixtureData': {
          'humans': {
            'owner': {
              'id': 'visual-owner',
              'email': 'owner@parity.invalid',
              'name': 'owner',
              'displayName': 'Visual Owner',
              'timezone': 'UTC',
              'timeFormat': '24h',
            },
          },
          'server': {
            'id': 'visual-server',
            'name': 'Visual Workspace',
            'slug': 'visual',
            'plan': 'free',
          },
        },
      },
      dark: false,
      againstWeb: true,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      ctx.dispose();
      await tester.pump();
    });
    final caseBuilder =
        extThreadAttachmentCases['components.thread-ext.attachment.image.pending-address-no-preview.brutal']!;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(raftThemePackId)),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 800),
            disableAnimations: true,
          ),
          child: caseBuilder.build(ctx),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await caseBuilder.interact!(tester, ctx);
    expect(find.byType(RaftSpinner), findsOneWidget);
  });
  Future<void> mount(
    WidgetTester t,
    AddressWaitHarness h, {
    String id = 'a',
    Key? key,
    String look = raftThemePackId,
    bool dark = false,
  }) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(look), dark: dark),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: h.view(id: id, key: key),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
  }

  void cleanup(WidgetTester t, AddressWaitHarness h) {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      await t.runAsync(h.dispose);
      expect(h.client.pending, 0);
      expect(h.files.pending, 0);
      t.view.reset();
    });
  }

  testWidgets('address delivery ends Spinner while image bytes still wait', (
    t,
  ) async {
    final h = AddressWaitHarness();
    cleanup(t, h);
    await mount(t, h);
    final zoom = t.state<ImageZoomSurfaceState>(find.byType(ImageZoomSurface));
    final page = t.state<AttachmentLightboxImageState>(
      find.byType(AttachmentLightboxImage),
    );
    expect(page.lease!.lease.waitingForAddress, isTrue);
    expect(find.byType(RaftSpinner), findsOneWidget);
    expect(t.getSize(find.byType(RaftSpinner)), const Size.square(19));
    h.client.resolve('a');
    await t.pump();
    expect(h.files.queries.length, 1);
    expect(h.files.pending, 1);
    expect(page.lease!.lease.waitingForAddress, isFalse);
    expect(page.full, isNull);
    // The asynchronous URL result reached the phase notifier after the prior
    // frame; paint that already scheduled frame, without advancing time.
    await t.pump();
    expect(find.byType(RaftSpinner), findsNothing);
    expect(
      t.state<ImageZoomSurfaceState>(find.byType(ImageZoomSurface)),
      same(zoom),
    );
  });

  testWidgets(
    'a genuinely warm decoded original never flashes an address Spinner',
    (t) async {
      final h = AddressWaitHarness();
      cleanup(t, h);
      h.client.immediate = true;
      h.files.immediate = solidPng(16, 16);
      final warm = (await t.runAsync(() async {
        final lease = h.warm('a');
        await lease.lease.ready;
        return lease;
      }))!;
      addTearDown(() => warm.release(discard: true));
      final queries = h.client.queries.length;
      await mount(t, h);
      expect(find.byType(RaftSpinner), findsNothing);
      await t.pump();
      expect(find.byType(RaftSpinner), findsNothing);
      expect(h.client.queries.length, queries);
      expect(h.files.queries.length, 1);
    },
  );

  testWidgets('failed address lookup and Retry use a fresh owned wait', (
    t,
  ) async {
    final h = AddressWaitHarness();
    cleanup(t, h);
    await mount(t, h);
    final old = t
        .state<AttachmentLightboxImageState>(
          find.byType(AttachmentLightboxImage),
        )
        .lease!;
    h.client.reject();
    await t.pump();
    await t.pump();
    expect(find.byType(RaftSpinner), findsNothing);
    expect(find.byKey(const Key('lightbox-retry')), findsOneWidget);
    h.client.fail = false;
    await t.tap(find.byKey(const Key('lightbox-retry')));
    await t.pump(const Duration(milliseconds: 100));
    expect(old.lease.active, isFalse);
    expect(find.byType(RaftSpinner), findsOneWidget);
    expect(h.client.pending, 1);
    expect(h.files.queries, isEmpty);
  });

  testWidgets('route disposal frees its image lease and owned fixture query', (
    t,
  ) async {
    final h = AddressWaitHarness();
    cleanup(t, h);
    await mount(t, h);
    final lease = t
        .state<AttachmentLightboxImageState>(
          find.byType(AttachmentLightboxImage),
        )
        .lease!;
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(lease.lease.active, isFalse);
    expect(h.w.attachmentMedia.retainedImageCount, 0);
    // The production signed-query cache is not made cancellable by this fix.
    // Our test-owned client closes that pending fixture response explicitly.
    await t.runAsync(h.dispose);
    expect(h.client.pending, 0);
    expect(h.client.cancelled, 1);
    expect(h.files.queries, isEmpty);
  });

  testWidgets(
    'authority revocation ignores the late address and drops the wait',
    (t) async {
      final h = AddressWaitHarness();
      cleanup(t, h);
      await mount(t, h);
      final lease = t
          .state<AttachmentLightboxImageState>(
            find.byType(AttachmentLightboxImage),
          )
          .lease!;
      h.allowed = false;
      h.w.attachmentMedia.revokeChannel('address-channel');
      await t.pump();
      expect(lease.lease.active, isFalse);
      expect(h.w.attachmentMedia.retainedImageCount, 0);
      h.client.resolve('a');
      await t.pump();
      expect(h.files.queries, isEmpty);
      expect(find.byType(RaftSpinner), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'replacement page keeps its own wait after the old address arrives',
    (t) async {
      final h = AddressWaitHarness();
      cleanup(t, h);
      await mount(t, h, key: const ValueKey('old'));
      final old = t
          .state<AttachmentLightboxImageState>(
            find.byType(AttachmentLightboxImage),
          )
          .lease!;
      await mount(t, h, id: 'b', key: const ValueKey('new'));
      final current = t
          .state<AttachmentLightboxImageState>(
            find.byType(AttachmentLightboxImage),
          )
          .lease!;
      expect(old.lease.active, isFalse);
      expect(current.lease.active, isTrue);
      h.client.resolve('a');
      await t.pump();
      expect(current.lease.waitingForAddress, isTrue);
      expect(find.byType(RaftSpinner), findsOneWidget);
      expect(h.files.queries, isEmpty);
      h.client.resolve('b');
      await t.pump();
      expect(current.lease.waitingForAddress, isFalse);
      expect(h.files.queries.length, 1);
      expect(h.files.queries.single.url.endsWith('/b.png'), isTrue);
    },
  );
  for (final mode in [
    (look: elegantThemePackId, dark: false),
    (look: elegantThemePackId, dark: true),
    (look: brutalThemePackId, dark: false),
  ]) {
    testWidgets(
      'frozen ${mode.look}/${mode.dark} keeps its original waiting placeholder',
      (t) async {
        final h = AddressWaitHarness();
        cleanup(t, h);
        await mount(t, h, look: mode.look, dark: mode.dark);
        final lease = t
            .state<AttachmentLightboxImageState>(
              find.byType(AttachmentLightboxImage),
            )
            .lease!;
        expect(lease.lease.waitingForAddress, isTrue);
        expect(find.byType(RaftSpinner), findsNothing);
        expect(find.byType(RaftTransferPlaceholder), findsOneWidget);
        h.client.resolve('a');
        await t.pump();
        await t.pump();
        expect(lease.lease.waitingForAddress, isFalse);
        expect(find.byType(RaftSpinner), findsNothing);
        expect(find.byType(RaftTransferPlaceholder), findsOneWidget);
      },
    );
  }

  testWidgets(
    'two original-image leases share one actual address query and keep independent release',
    (t) async {
      final h = AddressWaitHarness();
      cleanup(t, h);
      final a = h.warm('a'), b = h.warm('a');
      final seenA = <bool>[], seenB = <bool>[];
      a.lease.progress.addListener(() => seenA.add(a.lease.waitingForAddress));
      b.lease.progress.addListener(() => seenB.add(b.lease.waitingForAddress));
      await t.pump(const Duration(milliseconds: 100));
      expect(h.client.queries.length, 1);
      expect(a.lease.waitingForAddress, isTrue);
      expect(b.lease.waitingForAddress, isTrue);
      h.client.resolve('a');
      await t.pump();
      await t.pump();
      expect(a.lease.waitingForAddress, isFalse);
      expect(b.lease.waitingForAddress, isFalse);
      expect(seenA, contains(false));
      expect(seenB, contains(false));
      expect(h.files.queries.length, 1);
      a.release(discard: true);
      await t.pump();
      expect(b.lease.active, isTrue);
      expect(h.files.queries.single.cancel.isCancelled, isFalse);
      b.release(discard: true);
      await t.pump();
      await t.pump();
      expect(h.files.queries.single.cancel.isCancelled, isTrue);
      expect(h.w.attachmentMedia.retainedImageCount, 0);
      expect(h.files.pending, 0);
    },
  );
}
