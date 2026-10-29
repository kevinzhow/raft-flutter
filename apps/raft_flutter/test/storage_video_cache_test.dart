// Settings > Storage > Video cache: the size of the signed-in account's cached
// videos, live, and a Clear that empties it and says so.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/data/cache_clear.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/storage_settings.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/video_cache.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_range_upstream.dart';

void main() {
  late Directory root;
  final alice = VideoCacheAccount('https://raft.example', 'alice');
  final bob = VideoCacheAccount('https://raft.example', 'bob');

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    root = await Directory.systemTemp.createTemp('raft-storage-video');
    VideoCache.debugRoot = root;
    VideoCache.debugEnabled = true;
    VideoCache.debugClientFactory = HttpClient.new;
  });

  tearDown(() async {
    await VideoCache.debugReset();
    VideoCache.debugRoot = null;
    VideoCache.debugEnabled = null;
    VideoCache.debugClientFactory = null;
    DevicePreferences.reset();
    await root.delete(recursive: true);
  });

  /// A chunk of [bytes] in [account]'s folder, as the proxy would leave it.
  void leave(VideoCacheAccount account, int bytes, {String video = 'v1'}) {
    final folder = Directory(p.join(root.path, account.segment, video))
      ..createSync(recursive: true);
    File(p.join(folder.path, '0.chunk'))
        .writeAsBytesSync(List.filled(bytes, 7));
  }

  Future<void> pumpPage(
    WidgetTester t, {
    VideoCacheAccount? account,
    Locale locale = const Locale('en'),
  }) async {
    t.view.physicalSize = const Size(390, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: RaftToastHost(
          child: Scaffold(
            body: SingleChildScrollView(
              child: StorageSettingsPage(
                key: UniqueKey(),
                coordinator: CacheClear(),
                videoAccount: account,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(t, until: () => find.text('Calculating…').evaluate().isEmpty);
  }

  String sizeLine(WidgetTester t) => t
      .widget<Text>(
        find.descendant(
          of: find.byKey(const Key('storage-video-size')),
          matching: find.byType(Text),
        ),
      )
      .data!;

  RaftSettingsRecipeButton clearButton(WidgetTester t) =>
      t.widget<RaftSettingsRecipeButton>(
        find.byKey(const Key('storage-video-clear')),
      );

  testWidgets('without a signed-in account there is no video block', (t) async {
    await pumpPage(t);
    expect(find.text('Video cache'), findsNothing);
    expect(find.byKey(const Key('storage-video-clear')), findsNothing);
  });

  testWidgets('the cache switched off hides the block', (t) async {
    VideoCache.debugEnabled = false;
    await pumpPage(t, account: alice);
    expect(find.text('Video cache'), findsNothing);
  });

  testWidgets('shows this account\'s size, not another\'s', (t) async {
    leave(alice, 3 * 1024 * 1024);
    leave(bob, 9 * 1024 * 1024);
    await pumpPage(t, account: alice);
    expect(find.text('Video cache'), findsOneWidget);
    expect(sizeLine(t), 'Video cache: 3.0 MB');
    expect(clearButton(t).onPressed, isNotNull);
  });

  testWidgets('an empty cache says so and has nothing to clear', (t) async {
    await pumpPage(t, account: alice);
    expect(sizeLine(t), 'Video cache: 0 B');
    expect(clearButton(t).onPressed, isNull);
  });

  testWidgets('Clear empties this account only and shows the result', (
    t,
  ) async {
    leave(alice, 2 * 1024 * 1024);
    leave(alice, 1024 * 1024, video: 'v2');
    leave(bob, 4 * 1024 * 1024);
    await pumpPage(t, account: alice);
    expect(sizeLine(t), 'Video cache: 3.0 MB');

    await t.tap(find.byKey(const Key('storage-video-clear')));
    await settle(
      t,
      until: () => find.text('Video cache cleared.').evaluate().isNotEmpty,
    );

    expect(find.text('Video cache cleared.'), findsOneWidget);
    expect(sizeLine(t), 'Video cache: 0 B');
    expect(clearButton(t).onPressed, isNull);
    expect(Directory(p.join(root.path, alice.segment)).existsSync(), isFalse);
    expect(Directory(p.join(root.path, bob.segment)).existsSync(), isTrue);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('the size follows the cache while the page is open', (t) async {
    final upstream = FakeUpstream();
    await t.runAsync(upstream.start);
    addTearDown(() => t.runAsync(upstream.stop));
    upstream.sizes['/v.mp4'] = 5000;
    await pumpPage(t, account: alice);
    expect(sizeLine(t), 'Video cache: 0 B');

    // A video is watched in the background of the open page.
    await t.runAsync(() async {
      final routed = await VideoCache.route(
        AttachmentSource.network(
          upstream.url('/v.mp4?sig=1'),
          cacheKey: 'att-1',
          cacheAccount: alice,
        ),
      );
      final answer = await fetch(routed.url!);
      expect(answer.body, FakeUpstream.bytes(0, 4999));
      await (await VideoCache.debugRunning(alice)!).flushWrites();
    });
    await settle(t, until: () => sizeLine(t) != 'Video cache: 0 B');
    expect(sizeLine(t), 'Video cache: 4.9 KB');
    expect(clearButton(t).onPressed, isNotNull);

    // Clearing a running cache goes through the proxy and the line follows.
    await t.tap(find.byKey(const Key('storage-video-clear')));
    await settle(t, until: () => sizeLine(t) == 'Video cache: 0 B');
    expect(sizeLine(t), 'Video cache: 0 B');
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('a cache that cannot be emptied says so', (t) async {
    leave(alice, 1024);
    await pumpPage(t, account: alice);
    // A folder held open on Windows: simulate by making the clear not remove
    // the chunk (the folder is read-only).
    final folder = Directory(p.join(root.path, alice.segment, 'v1'));
    Process.runSync('chmod', ['555', folder.path]);
    addTearDown(() => Process.runSync('chmod', ['755', folder.path]));
    await t.tap(find.byKey(const Key('storage-video-clear')));
    await settle(
      t,
      until: () => find
          .text('Some of the video cache could not be cleared. Try again.')
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.text('Some of the video cache could not be cleared. Try again.'),
      findsOneWidget,
    );
    expect(sizeLine(t), 'Video cache: 1.0 KB');
    await t.pump(const Duration(seconds: 6));
  }, skip: Platform.isWindows);

  testWidgets('reads in Chinese on the', (t) async {
    leave(alice, 5 * 1024 * 1024);
    await pumpPage(t, account: alice, locale: const Locale('zh', 'CN'));
    expect(find.text('视频缓存'), findsOneWidget);
    expect(sizeLine(t), '视频缓存：5.0 MB');
    expect(find.text('看过的视频会保存在此设备上，再次播放无需重新下载。退出登录时会一并删除。'), findsOneWidget);
    expect(find.text('清除'), findsOneWidget);
  });
}

/// Real file I/O needs real time between frames.
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
