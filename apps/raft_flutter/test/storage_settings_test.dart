import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/cache_budget.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/cache_clear.dart';
import 'package:raft_flutter/features/storage_settings.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;
  late AttachmentDiskCache cache;
  late CacheClear coordinator;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    root = await Directory.systemTemp.createTemp('raft-storage-settings');
    cache = AttachmentDiskCache(() async => root);
    coordinator = CacheClear()..register('disk', cache.clear);
  });
  tearDown(() async {
    DevicePreferences.reset();
    await root.delete(recursive: true);
  });

  // The size is read off the first frame, from the disk.
  bool calculated() => find.text('Calculating…').evaluate().isEmpty;

  Future<void> pumpPage(WidgetTester t, {AttachmentDiskCache? with_}) async {
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: RaftToastHost(
          child: Scaffold(
            body: SingleChildScrollView(
              child: StorageSettingsPage(
                key: UniqueKey(),
                cache: with_,
                coordinator: coordinator,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(t, until: calculated);
  }

  Future<void> fill(WidgetTester t, int bytes) async {
    await t.runAsync(
      () => cache.write(
        AttachmentImageStoreKey(
          identity: AttachmentImageKey.identityOf(
            'https://x.invalid',
            'u',
            's',
          ),
          channelId: 'c',
          entry: '["a$bytes","r","original"]',
        ),
        Uint8List(bytes),
      ),
    );
  }

  Future<void> fillPublic(WidgetTester t, int bytes) => t.runAsync(
    () => cache.writePublic('https://x.invalid/a$bytes.webp', Uint8List(bytes)),
  );

  String text(WidgetTester t, String key) =>
      t.widget<Text>(find.byKey(Key(key))).data!;

  String size(WidgetTester t) => t
      .widget<Text>(
        find.descendant(
          of: find.byKey(const Key('storage-size')),
          matching: find.byType(Text),
        ),
      )
      .data!;

  testWidgets('shows the cache size, off the first frame', (t) async {
    await fill(t, 3 * 1024 * 1024);
    await fill(t, 512 * 1024);
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: StorageSettingsPage(
            key: UniqueKey(),
            cache: cache,
            coordinator: coordinator,
          ),
        ),
      ),
    );
    // The first frame does not wait for the disk.
    expect(size(t), 'Calculating…');
    expect(
      t
          .widget<RaftSettingsRecipeButton>(
            find.byKey(const Key('storage-clear')),
          )
          .onPressed,
      isNull,
    );
    await settle(t, until: calculated);
    expect(size(t), 'Cache size: 3.5 MB');
    expect(find.byType(RaftSettingsSectionHeader), findsNWidgets(2));
    expect(find.text('Cache'), findsOneWidget);
  });

  testWidgets('breaks the total down by what is stored', (t) async {
    await fill(t, 3 * 1024 * 1024);
    await fillPublic(t, 512 * 1024);
    await pumpPage(t, with_: cache);
    expect(size(t), 'Cache size: 3.5 MB');
    expect(text(t, 'storage-attachments-size'), '3.0 MB');
    expect(text(t, 'storage-public-size'), '512.0 KB');
    expect(find.text('Attachments and previews'), findsOneWidget);
    expect(find.text('Profile pictures and icons'), findsOneWidget);
  });

  testWidgets('the breakdown reads in Chinese', (t) async {
    await fill(t, 1024);
    await fillPublic(t, 1024);
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: StorageSettingsPage(cache: cache, coordinator: coordinator),
        ),
      ),
    );
    await settle(t, until: calculated);
    expect(find.text('附件和预览'), findsOneWidget);
    expect(find.text('头像和图标'), findsOneWidget);
  });

  testWidgets('clearing asks first, then empties the cache and says so', (
    t,
  ) async {
    await fill(t, 2 * 1024 * 1024);
    await fillPublic(t, 1024 * 1024);
    final session = File('${root.path}/session.json')
      ..writeAsStringSync('keep');
    await pumpPage(t, with_: cache);
    expect(size(t), 'Cache size: 3.0 MB');

    await t.tap(find.byKey(const Key('storage-clear')));
    await settle(t);
    expect(find.byKey(const ValueKey('storage-clear-dialog')), findsOneWidget);
    expect(
      find.textContaining('They are downloaded again the next time you open'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'so are your sign-in, drafts, settings, files you saved and files shared to Raft',
      ),
      findsOneWidget,
    );

    // Cancel leaves everything as it was.
    await t.tap(find.text('Keep Cache'));
    await settle(t);
    expect(find.byKey(const ValueKey('storage-clear-dialog')), findsNothing);
    expect(size(t), 'Cache size: 3.0 MB');
    expect((await t.runAsync(cache.sizeBytes)), 3 * 1024 * 1024);

    await t.tap(find.byKey(const Key('storage-clear')));
    await settle(t);
    await t.tap(find.byKey(const Key('storage-clear-confirm')));
    await settle(
      t,
      until: () =>
          find
              .byKey(const ValueKey('storage-clear-dialog'))
              .evaluate()
              .isEmpty &&
          find.text('Cache size: 0 B').evaluate().isNotEmpty,
    );
    expect(find.byKey(const ValueKey('storage-clear-dialog')), findsNothing);
    expect(find.text('Cache cleared.'), findsOneWidget);
    expect(size(t), 'Cache size: 0 B');
    expect(text(t, 'storage-attachments-size'), '0 B');
    expect(text(t, 'storage-public-size'), '0 B');
    expect((await t.runAsync(cache.sizeBytes)), 0);
    expect(session.existsSync(), isTrue, reason: 'only the cache is cleared');
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('goes through the coordinator: a layer registered later is '
      'cleared too, one that fails keeps the dialog open', (t) async {
    await fill(t, 1024);
    var memory = 0;
    coordinator.register('memory', () => memory++);
    coordinator.register('broken', () => throw const FileSystemException('x'));
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    await pumpPage(t, with_: cache);
    await t.tap(find.byKey(const Key('storage-clear')));
    await settle(
      t,
      until: () =>
          find.byKey(const Key('storage-clear-confirm')).evaluate().isNotEmpty,
    );
    await t.tap(find.byKey(const Key('storage-clear-confirm')));
    await settle(
      t,
      until: () => find
          .text('Some of the cache could not be cleared. Try again.')
          .evaluate()
          .isNotEmpty,
    );
    expect(memory, 1);
    expect((await t.runAsync(cache.sizeBytes)), 0);
    expect(find.byKey(const ValueKey('storage-clear-dialog')), findsOneWidget);
    expect(
      find.text('Some of the cache could not be cleared. Try again.'),
      findsOneWidget,
    );
    expect(reported, hasLength(1));
  });

  group('cache limit', () {
    const mb = 1024 * 1024;
    String v2() => '${root.path}/raft-attachments/v2/a/b/c';

    /// [count] sparse 100 MB private entries, opened one day apart (entry 0
    /// longest ago), and one 1 MB public entry. No real megabytes are written.
    List<File> populate(int count) {
      Directory(v2()).createSync(recursive: true);
      Directory('${root.path}/raft-attachments/public').createSync();
      final now = DateTime.now();
      final files = [
        for (var i = 0; i < count; i++) File('${v2()}/e$i')..createSync(),
      ];
      for (final f in files) {
        f.openSync(mode: FileMode.append)
          ..truncateSync(100 * mb)
          ..closeSync();
      }
      // After the truncation, which touches the modification time.
      for (var i = 0; i < count; i++) {
        files[i].setLastModifiedSync(now.subtract(Duration(days: count - i)));
      }
      File('${root.path}/raft-attachments/public/p1')
          .writeAsBytesSync(Uint8List(mb));
      return files;
    }

    Future<void> choose(WidgetTester t, int tier) async {
      await t.ensureVisible(find.byKey(const Key('storage-budget')));
      await t.tap(find.byKey(const Key('storage-budget')));
      await settle(
        t,
        until: () =>
            find.byKey(Key('storage-budget-$tier')).evaluate().isNotEmpty,
      );
      await t.tap(find.byKey(Key('storage-budget-$tier')));
      await settle(t);
    }

    String shown(WidgetTester t) => t
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('storage-budget')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    for (final (name, width, height) in [
      ('phone 390', 390.0, 844.0),
      ('desktop 1280', 1280.0, 800.0),
    ]) {
      testWidgets('picking a lower tier evicts and is remembered ($name)', (
        t,
      ) async {
        final files = populate(4);
        // 400 MB private + 1 MB public, under the default 1 GB.
        cache = AttachmentDiskCache(
          () async => root,
          maxBytes: CacheBudget.stored(),
          publicMaxBytes: attachmentPublicCacheMaxBytes,
        );
        t.view.physicalSize = Size(width, height);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        Widget page() => MaterialApp(
          theme: raftTheme(),
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: RaftToastHost(
            child: Scaffold(
              body: SingleChildScrollView(
                child: StorageSettingsPage(
                  key: UniqueKey(),
                  cache: cache,
                  coordinator: coordinator,
                ),
              ),
            ),
          ),
        );
        await t.pumpWidget(page());
        await settle(t, until: calculated);

        expect(shown(t), '1 GB', reason: 'the default tier');
        expect(size(t), 'Cache size: 401.0 MB');
        expect(find.text('Cache limit'), findsWidgets);
        expect(t.takeException(), isNull, reason: 'no overflow at $name');

        // A higher tier evicts nothing.
        await choose(t, 2048 * mb);
        expect(shown(t), '2 GB');
        expect(size(t), 'Cache size: 401.0 MB');
        expect(
          DevicePreferences.current!.getInt('raft.cacheBudget'),
          2048 * mb,
        );

        await choose(t, 256 * mb);
        expect(shown(t), '256 MB');
        // Over 256 MB: the oldest go until at most 90 % (230.4 MB) is left;
        // two private entries (200 MB) and the 1 MB avatar remain.
        expect(size(t), 'Cache size: 201.0 MB');
        expect(text(t, 'storage-attachments-size'), '200.0 MB');
        expect(text(t, 'storage-public-size'), '1.0 MB');
        expect(
          [for (final f in files) f.existsSync()],
          [false, false, true, true],
        );
        expect(
          File('${root.path}/raft-attachments/public/p1').existsSync(),
          isTrue,
          reason: 'the avatar cap does not follow the tier',
        );
        expect(DevicePreferences.current!.getInt('raft.cacheBudget'), 256 * mb);
        expect(cache.maxBytes, 256 * mb);
        expect(cache.publicMaxBytes, attachmentPublicCacheMaxBytes);

        // A restart: a new cache and a new page start from the stored tier.
        final restarted = AttachmentDiskCache(
          () async => root,
          maxBytes: CacheBudget.stored(),
          publicMaxBytes: attachmentPublicCacheMaxBytes,
        );
        expect(restarted.maxBytes, 256 * mb);
        cache = restarted;
        await t.pumpWidget(page());
        await settle(t, until: calculated);
        expect(shown(t), '256 MB');

        // Back to the default forgets the stored value.
        await choose(t, 1024 * mb);
        expect(shown(t), '1 GB');
        expect(DevicePreferences.current!.getInt('raft.cacheBudget'), isNull);
        await t.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('the tiers are offered smallest first and read in Chinese', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StorageSettingsPage(
                cache: cache,
                coordinator: coordinator,
              ),
            ),
          ),
        ),
      );
      await settle(t, until: calculated);
      expect(find.text('缓存上限'), findsWidgets);
      expect(find.textContaining('缓存最多可占用此设备的空间'), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('storage-budget')));
      await t.tap(find.byKey(const Key('storage-budget')));
      await settle(t);
      final offered = [
        for (final tier in attachmentCacheBudgetTiers)
          t.getTopLeft(find.byKey(Key('storage-budget-$tier')).last).dy,
      ];
      expect(offered, [...offered]..sort());
      expect(
        [
          for (final tier in attachmentCacheBudgetTiers)
            t.widget<Text>(find.byKey(Key('storage-budget-$tier')).last).data,
        ],
        ['256 MB', '512 MB', '1 GB', '2 GB', '5 GB'],
      );
    });

    testWidgets('without a cache the picker is disabled', (t) async {
      await pumpPage(t);
      expect(
        t
            .widget<RaftSelectField<int>>(
              find.byKey(const Key('storage-budget')),
            )
            .onChanged,
        isNull,
      );
    });

    test('an unknown or foreign stored value means the default', () async {
      expect(CacheBudget.stored(), attachmentCacheMaxBytes);
      SharedPreferences.setMockInitialValues({'raft.cacheBudget': 12345});
      expect(
        CacheBudget.stored(await SharedPreferences.getInstance()),
        attachmentCacheMaxBytes,
      );
      SharedPreferences.setMockInitialValues({'raft.cacheBudget': 'big'});
      expect(
        CacheBudget.stored(await SharedPreferences.getInstance()),
        attachmentCacheMaxBytes,
      );
      SharedPreferences.setMockInitialValues({
        'raft.cacheBudget': 5 * 1024 * mb,
      });
      expect(
        CacheBudget.stored(await SharedPreferences.getInstance()),
        5 * 1024 * mb,
      );
      expect(CacheBudget.label(5 * 1024 * mb), '5 GB');
      expect(CacheBudget.label(512 * mb), '512 MB');
    });
  });

  testWidgets('without a cache there is nothing to clear', (t) async {
    await pumpPage(t);
    expect(size(t), 'Cache size: 0 B');
    expect(
      t
          .widget<RaftSettingsRecipeButton>(
            find.byKey(const Key('storage-clear')),
          )
          .onPressed,
      isNull,
    );
  });
}

/// Real file I/O needs real time between frames: at least 12 frames, and when
/// [until] is given, more (up to ten seconds) until it holds, so a slow disk
/// on a loaded machine is waited for instead of guessed at.
Future<void> settle(WidgetTester t, {bool Function()? until}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  for (var i = 0; ; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await t.pump(const Duration(milliseconds: 50));
    if (i >= 11 && (until == null || until())) return;
    if (DateTime.now().isAfter(deadline)) return;
  }
}
