// Waiting for the copy of an incoming share: per-file progress on the "Add
// shared content" card, Continue as a progress block with Cancel, and the
// failure of one file (too large / unreadable / permission revoked) named on
// the page. The copy itself (bytes, reasons) is covered at the inbox.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/incoming_share_targets.dart';
import 'package:raft_flutter/features/incoming_share_picker.dart';
import 'package:raft_flutter/platform/incoming_share_inbox.dart';
import 'package:raft_flutter/platform/incoming_share_staging.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'flutter_test_config.dart' show leakDebt;

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://example.test', sessionStore: MemorySessionStore());
  @override
  Future<dynamic> getForServer(
    String server,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (path == '/channels') {
      return [
        {'id': 'c1', 'name': 'general', 'type': 'channel', 'joined': true},
      ];
    }
    return [];
  }
}

/// Every directory read hangs: only the device's rows are on screen.
class _Silent extends RaftClient {
  _Silent()
    : super(origin: 'https://example.test', sessionStore: MemorySessionStore());
  int reads = 0;
  @override
  Future<dynamic> getForServer(
    String server,
    String path, {
    Map<String, dynamic>? query,
  }) {
    reads++;
    return Completer<dynamic>().future;
  }

  @override
  Future<List<RaftRecord>> servers() => Completer<List<RaftRecord>>().future;
}

const _files = [
  IncomingSharedFile('content://f/a', 'IMG_2041.jpg', 'image/jpeg', 2000000),
  IncomingSharedFile('content://f/b', 'VID_0932.mp4', 'video/mp4', 12000000),
  IncomingSharedFile('content://f/c', 'review.pdf', 'application/pdf', 4000000),
];
const _raw = IncomingShare(files: _files);

/// A copy the test drives: [bytes] and [done] play the part of the host.
class _Copy {
  final release = Completer<void>();
  late void Function(int) done;
  late void Function(int, int) bytes;
  final finished = Completer<IncomingShare>();
  void start(IncomingShareStaging staging) => staging.start((progress, b) {
    done = progress;
    bytes = b;
    return finished.future;
  });
}

IncomingShare _staged() => const IncomingShare(
  token: 't',
  files: [
    IncomingSharedFile('item-0', 'IMG_2041.jpg', 'image/jpeg', 2000000),
    IncomingSharedFile('item-1', 'VID_0932.mp4', 'video/mp4', 12000000),
    IncomingSharedFile('item-2', 'review.pdf', 'application/pdf', 4000000),
  ],
);

Future<void> _page(
  WidgetTester t,
  IncomingShareStaging staging, {
  bool dark = false,
  Locale locale = const Locale('en'),
  Future<void> Function(RaftRecord, IncomingShareTarget)? onContinue,
  List<String>? pops,
}) async {
  t.view.physicalSize = const Size(390, 844) * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final client = _Client();
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: raftTheme(dark: dark),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => IncomingSharePicker(
                      client: client,
                      staging: staging,
                      servers: [
                        RaftRecord({'id': 's', 'name': 'S', 'role': 'owner'}),
                      ],
                      valid: () => true,
                      onContinue: onContinue ?? (server, target) async {},
                    ),
                  ),
                );
                pops?.add('$result');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.byKey(const Key('open')));
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await client.dispose();
  });
}

Future<void> _review(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('incoming-target-c1')));
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

/// Bars sweep forever: advance time instead of settling.
Future<void> _advance(WidgetTester t, [int ms = 300]) =>
    t.pump(Duration(milliseconds: ms));

void main() {
  // Leak debt (share flow): see docs/development.md, Leak tracking.
  leakDebt(const ['IncomingShareStaging', 'ValueNotifier<RaftTransferProgress?>']);
  for (final (name, dark) in [
    ('light', false),
    ('dark', true),
  ]) {
    group(name, () {
      testWidgets(
        'chips show waiting / bytes / done while the copy runs; the targets page shows the bytes',
        (t) async {
          final staging = IncomingShareStaging(_raw);
          final copy = _Copy()..start(staging);
          await _page(t, staging, dark: dark);
          // Targets page: one compact bar, by bytes.
          expect(
            find.byKey(const Key('incoming-share-preparing')),
            findsOneWidget,
          );
          expect(find.textContaining('Preparing 0 of 3 files'), findsOneWidget);
          copy.bytes(0, 1000000);
          await _advance(t);
          expect(find.textContaining('1.0 / 17.2 MB'), findsOneWidget);
          await _review(t);
          expect(find.text('Add shared content'), findsOneWidget);
          // First file half-way, the others queued.
          expect(find.text('1.0 / 1.9 MB · 50%'), findsOneWidget);
          expect(find.text('Waiting'), findsNWidgets(2));
          copy.done(1);
          copy.bytes(1, 3000000);
          await _advance(t);
          expect(find.text('Waiting'), findsOneWidget);
          expect(find.text('2.9 / 11.4 MB · 25%'), findsOneWidget);
          copy.finished.complete(_staged());
          await _advance(t);
          copy.done(3);
          await _advance(t);
          expect(find.text('Waiting'), findsNothing);
          expect(find.byType(RaftTransferBar), findsNothing);
          // Continue is not busy: the copy ended, nothing is pending.
          expect(find.text('Continue'), findsOneWidget);
        },
      );

      testWidgets(
        'Continue before the copy ended: spinner, bytes and Cancel; hand-off starts at once and finishes with the copy',
        (t) async {
          final staging = IncomingShareStaging(_raw);
          final copy = _Copy()..start(staging);
          final handoff = Completer<void>();
          var started = 0;
          final pops = <String>[];
          await _page(
            t,
            staging,
            dark: dark,
            pops: pops,
            onContinue: (server, target) async {
              started++;
              await handoff.future;
            },
          );
          await _review(t);
          copy.done(1);
          copy.bytes(1, 5000000);
          await _advance(t);
          await t.tap(find.byKey(const Key('incoming-share-continue')));
          await _advance(t);
          // The validation / hand-off runs while the copy is still going.
          expect(started, 1);
          expect(find.text('Preparing files'), findsOneWidget);
          expect(find.textContaining('Preparing 1 of 3 files'), findsWidgets);
          expect(find.text('Cancel'), findsOneWidget);
          expect(find.text('Continue'), findsNothing);
          // A second tap on the busy button does nothing.
          await t.tap(find.text('Preparing files'), warnIfMissed: false);
          await _advance(t);
          expect(started, 1);
          copy.finished.complete(_staged());
          copy.done(3);
          await _advance(t);
          // Copy done: the wait is the hand-off.
          expect(find.text('Adding to the conversation'), findsOneWidget);
          expect(find.text('Preparing files'), findsNothing);
          handoff.complete();
          await _advance(t);
          await _advance(t, 500);
          await _advance(t, 500);
          expect(pops, ['true']);
        },
      );

      testWidgets(
        'Cancel while waiting leaves, stops the copy and hands off nothing',
        (t) async {
          final staging = IncomingShareStaging(_raw);
          _Copy().start(staging);
          final handoff = Completer<void>();
          final pops = <String>[];
          await _page(
            t,
            staging,
            dark: dark,
            pops: pops,
            onContinue: (server, target) => handoff.future,
          );
          await _review(t);
          await t.tap(find.byKey(const Key('incoming-share-continue')));
          await _advance(t);
          expect(staging.cancelled, false);
          await t.tap(find.text('Cancel'));
          await _advance(t, 500);
          await _advance(t, 500);
          expect(staging.cancelled, true);
          expect(pops, ['false']);
          expect(find.byType(IncomingSharePicker), findsNothing);
        },
      );

      testWidgets('system back while waiting cancels too', (t) async {
        final staging = IncomingShareStaging(_raw);
        _Copy().start(staging);
        final pops = <String>[];
        await _page(
          t,
          staging,
          dark: dark,
          pops: pops,
          onContinue: (server, target) => Completer<void>().future,
        );
        await _review(t);
        await t.tap(find.byKey(const Key('incoming-share-continue')));
        await _advance(t);
        await t.binding.handlePopRoute();
        await _advance(t, 500);
        await _advance(t, 500);
        expect(staging.cancelled, true);
        // The system back button pops without a result.
        expect(pops, ['null']);
      });

      for (final (reason, banner, chip) in [
        (
          IncomingShareFailureReason.tooLarge,
          'review.pdf is larger than 25 MB and cannot be added.',
          'Larger than 25 MB',
        ),
        (
          IncomingShareFailureReason.unreadable,
          'review.pdf could not be read.',
          'Could not be read',
        ),
        (
          IncomingShareFailureReason.permission,
          'Raft can no longer read review.pdf.',
          'Permission revoked',
        ),
      ]) {
        testWidgets(
          'a file that fails (${reason.name}) is named on both pages',
          (t) async {
            final staging = IncomingShareStaging(_raw);
            final copy = _Copy()..start(staging);
            await _page(t, staging, dark: dark);
            copy.done(1);
            copy.done(2);
            copy.finished.completeError(IncomingShareFailure(reason, index: 2));
            await _advance(t);
            expect(staging.failed, true);
            // The page stays: it does not close behind a toast.
            expect(find.byType(IncomingSharePicker), findsOneWidget);
            expect(find.text(banner), findsOneWidget);
            expect(
              find.byKey(const Key('incoming-share-preparing')),
              findsNothing,
            );
            await _review(t);
            expect(find.text(banner), findsOneWidget);
            expect(find.text(chip), findsOneWidget);
            // Nothing to continue with; Back still works.
            final continueButton = t.widget<RaftForwardContinueAction>(
              find.byKey(const Key('incoming-share-continue')),
            );
            expect(continueButton.onPressed, isNull);
            await t.tap(find.byTooltip('Back to Destinations'));
            await _advance(t);
            expect(find.text('Select destinations'), findsOneWidget);
          },
        );
      }

      testWidgets(
        'failure while Continue waits shows the reason and frees the button',
        (t) async {
          final staging = IncomingShareStaging(_raw);
          final copy = _Copy()..start(staging);
          await _page(
            t,
            staging,
            dark: dark,
            onContinue: (server, target) async {
              await staging.result;
            },
          );
          await _review(t);
          await t.tap(find.byKey(const Key('incoming-share-continue')));
          await _advance(t);
          copy.finished.completeError(
            IncomingShareFailure(IncomingShareFailureReason.tooLarge, index: 1),
          );
          await _advance(t);
          await _advance(t);
          expect(
            find.text('VID_0932.mp4 is larger than 25 MB and cannot be added.'),
            findsOneWidget,
          );
          expect(find.text('Cancel'), findsNothing);
          expect(find.text('Preparing files'), findsNothing);
        },
      );
    });
  }

  testWidgets(
    'Continue hands off from the device rows without waiting for any read',
    (t) async {
      t.view.physicalSize = const Size(390, 844) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final client = _Silent();
      final received = <String>[];
      final staging = IncomingShareStaging(_staged());
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: IncomingSharePicker(
            client: client,
            staging: staging,
            servers: [
              RaftRecord({'id': 's', 'name': 'S', 'role': 'owner'}),
            ],
            valid: () => true,
            cachedTargets: (server) => [
              IncomingShareTarget(
                '#general',
                channel: RaftChannel({
                  'id': 'c1',
                  'name': 'general',
                  'type': 'channel',
                  'joined': true,
                }),
              ),
            ],
            onContinue: (server, target) async =>
                received.add('${server.id}:${target.key}'),
          ),
        ),
      );
      await t.pump();
      // The directory and membership reads are in flight and never answer.
      expect(client.reads, greaterThan(0));
      await t.tap(find.byKey(const ValueKey('incoming-target-c1')));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const Key('incoming-share-continue')));
      await t.pump();
      expect(received, ['s:c1']);
      await t.pump(const Duration(milliseconds: 600));
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await client.dispose();
      });
    },
  );

  testWidgets('zh: waiting and error strings are Chinese', (t) async {
    final staging = IncomingShareStaging(_raw);
    final copy = _Copy()..start(staging);
    await _page(
      t,
      staging,
      locale: const Locale('zh', 'CN'),
      onContinue: (server, target) async {
        await staging.result;
      },
    );
    await _review(t);
    expect(find.text('等待中'), findsNWidgets(2));
    await t.tap(find.byKey(const Key('incoming-share-continue')));
    await _advance(t);
    expect(find.text('正在准备文件'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.textContaining('正在准备文件（0/3）'), findsWidgets);
    copy.finished.completeError(
      IncomingShareFailure(IncomingShareFailureReason.permission, index: 0),
    );
    await _advance(t);
    await _advance(t);
    expect(find.text('Raft 已无权读取 IMG_2041.jpg。'), findsOneWidget);
    expect(find.text('权限已撤销'), findsOneWidget);
  });

  group('staging model', () {
    test('per-file state, bytes and overall progress', () async {
      final staging = IncomingShareStaging(_raw);
      final copy = _Copy()..start(staging);
      expect(staging.files.first.state, IncomingShareFileState.copying);
      expect(staging.files[1].state, IncomingShareFileState.waiting);
      expect(staging.overall.value!.total, 18000000);
      copy.bytes(0, 500000);
      expect(staging.files.first.progress.value!.received, 500000);
      expect(staging.overall.value!.received, 500000);
      copy.done(1);
      expect(staging.files.first.state, IncomingShareFileState.ready);
      expect(staging.files[1].state, IncomingShareFileState.copying);
      expect(staging.overall.value!.received, 2000000);
      copy.bytes(1, 1000000);
      expect(staging.overall.value!.received, 3000000);
      copy.finished.complete(_staged());
      await staging.result;
      expect(staging.state, IncomingShareStagingState.ready);
    });

    test('a failure marks only the file to blame', () async {
      final staging = IncomingShareStaging(_raw);
      final copy = _Copy()..start(staging);
      copy.done(1);
      copy.finished.completeError(
        IncomingShareFailure(IncomingShareFailureReason.permission, index: 1),
      );
      await staging.settled;
      // Files not to blame show nothing (their copy is discarded with the rest).
      expect(staging.files[0].state, IncomingShareFileState.stopped);
      expect(staging.files[1].state, IncomingShareFileState.failed);
      expect(staging.files[1].failure, IncomingShareFailureReason.permission);
      expect(staging.files[2].state, IncomingShareFileState.stopped);
    });

    test('unknown sizes: no total, so no percentage', () {
      final staging = IncomingShareStaging(
        const IncomingShare(
          files: [IncomingSharedFile('content://x', 'a.bin', 'a/b', null)],
        ),
      );
      expect(staging.overall.value!.total, isNull);
      expect(staging.overall.value!.fraction, isNull);
    });
  });

  group('inbox failures', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('raft-share-fail-');
    });
    tearDown(() => directory.delete(recursive: true));
    IncomingShareInbox inbox({
      Stream<List<int>> Function(Uri)? read,
      Future<int> Function(Uri, File, int, void Function(int))? copy,
    }) => IncomingShareInbox(
      () async => directory,
      read ?? (_) => Stream.value([1, 2, 3]),
      copyContent: copy,
    );
    Future<IncomingShareFailure> failure(Future<Object?> run) async {
      try {
        await run;
      } on IncomingShareFailure catch (e) {
        return e;
      }
      fail('did not fail');
    }

    test(
      'an oversized declared file fails before anything is copied',
      () async {
        var opened = 0;
        final e = await failure(
          inbox(
            read: (_) {
              opened++;
              return Stream.value([1]);
            },
          ).stage(
            const IncomingShare(
              files: [
                IncomingSharedFile('content://a', 'ok.jpg', 'image/jpeg', 10),
                IncomingSharedFile(
                  'content://b',
                  'huge.mov',
                  'video/quicktime',
                  IncomingShareInbox.maxItemBytes + 1,
                ),
              ],
            ),
          ),
        );
        expect(e.reason, IncomingShareFailureReason.tooLarge);
        expect(e.index, 1);
        expect(opened, 0);
        expect(await directory.list().toList(), isEmpty);
      },
    );

    test('declared sizes over the total fail at once', () async {
      final e = await failure(
        inbox().stage(
          IncomingShare(
            files: [
              for (var i = 0; i < 5; i++)
                IncomingSharedFile(
                  'content://$i',
                  '$i.bin',
                  'a/b',
                  IncomingShareInbox.maxItemBytes,
                ),
            ],
          ),
        ),
      );
      expect(e.reason, IncomingShareFailureReason.totalTooLarge);
    });

    test(
      'a provider that fails while reading is unreadable, with its index',
      () async {
        final e = await failure(
          inbox(
            read: (uri) => uri.host == 'bad'
                ? Stream.error(const FileSystemException('closed pipe'))
                : Stream.value([1]),
          ).stage(
            const IncomingShare(
              files: [
                IncomingSharedFile('content://ok', 'a.jpg', 'image/jpeg', null),
                IncomingSharedFile(
                  'content://bad',
                  'b.jpg',
                  'image/jpeg',
                  null,
                ),
              ],
            ),
          ),
        );
        expect(e.reason, IncomingShareFailureReason.unreadable);
        expect(e.index, 1);
        expect(await directory.list().toList(), isEmpty);
      },
    );

    for (final (code, reason) in [
      ('permission', IncomingShareFailureReason.permission),
      ('unreadable', IncomingShareFailureReason.unreadable),
      ('too_large', IncomingShareFailureReason.tooLarge),
      ('empty', IncomingShareFailureReason.empty),
      ('copy_failed', IncomingShareFailureReason.unreadable),
    ]) {
      test('host error "$code" is reported as ${reason.name}', () async {
        final e = await failure(
          inbox(copy: (_, _, _, _) => throw PlatformException(code: code))
              .stage(
                const IncomingShare(
                  files: [IncomingSharedFile('content://a', 'a', 'a/b', null)],
                ),
              ),
        );
        expect(e.reason, reason);
        expect(e.index, 0);
      });
    }

    test('bytes are reported per file while it is copied', () async {
      final seen = <(int, int)>[];
      await inbox(
        read: (_) => Stream.fromIterable([
          [1, 2],
          [3],
        ]),
      ).stage(
        const IncomingShare(
          files: [
            IncomingSharedFile('content://a', 'a.jpg', 'image/jpeg', null),
            IncomingSharedFile('content://b', 'b.jpg', 'image/jpeg', null),
          ],
        ),
        onBytes: (index, bytes) => seen.add((index, bytes)),
      );
      expect(seen, [(0, 2), (0, 3), (1, 2), (1, 3)]);
    });

    test('host byte progress reaches the caller', () async {
      final seen = <int>[];
      await inbox(
        copy: (_, file, _, onBytes) async {
          onBytes(10);
          onBytes(30);
          await file.writeAsBytes([1, 2, 3]);
          return 3;
        },
      ).stage(
        const IncomingShare(
          files: [IncomingSharedFile('content://a', 'a', 'a/b', null)],
        ),
        onBytes: (_, bytes) => seen.add(bytes),
      );
      expect(seen, [10, 30]);
    });
  });
}
