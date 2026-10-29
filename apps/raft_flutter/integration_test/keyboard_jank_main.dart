// Debug/profile-only entrypoint for the soft-keyboard frame-time probe: the
// production RaftApp (real MainActivity, phone shell, composer) on a long
// CJK / markdown / image channel plus a thread, no login. It logs one
// `KBJ` line per frame (FrameTiming) and per metrics change, so a host script
// can drive real taps with adb and read the keyboard animation's frames from
// logcat. Never built into the release app.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/keyboard_jank_main.dart
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _prose = [
  '代码和相关回归检查已通过，右侧操作复用原播放器，不会另开一份播放状态。独立 Duo 原生包正在编译；设备窗口目前出现空白和绑定超时，我会保留这次失败记录，恢复窗口后再做实际交互验证。',
  '工具栏的浅色、深色预览已实际渲染；1、1.3、1.6、2 倍字号的标签、触控目标和对比度检查通过。主页切换保持同一个页面状态，正在用独立 Duo 测试包验证折叠时播放器和字幕位置不会重置。',
  '号放不下时保留底部操作，接下来验证播放位置、字幕跟随和页面切换是否保持。这是一段更长的中文说明，用来模拟真实频道里常见的大段文字消息，包含标点、English words、数字 123 和换行折返。',
];

String _longProse(int n) =>
    '${_prose[n % 3]}\n\n${_prose[(n + 1) % 3]}\n\n${_prose[(n + 2) % 3]}';

LabChannel _channel(String id, List<String> kinds) {
  final c = LabChannel(id, kinds);
  for (var i = 0; i < c.rows.length; i++) {
    if (kinds[i] == 'plain') c.rows[i]['content'] = _longProse(i);
  }
  return c;
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  _installFrameLog();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  const cycle = [
    'plain',
    'markdown',
    'plain',
    'image',
    'plain',
    'thread-summary',
    'plain',
    'code',
    'plain',
    'markdown',
  ];
  final channel = _channel('kb', [
    for (var i = 0; i < 60; i++) cycle[i % cycle.length],
  ]);
  final parent = channel.rows.lastWhere(
    (r) => channel.summaries.containsKey(r['id']),
  );
  final threadId = 'thread-${parent['id']}';
  final thread = _channel(threadId, [
    for (var i = 0; i < 40; i++)
      const ['plain', 'markdown', 'plain', 'image', 'plain'][i % 5],
  ]);
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    [channel, thread],
    images,
    mobile: true,
    ownsClient: false,
  );
  seed.dispose();
  api.routes['GET /auth/me'] = (_) => {
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': 'zh',
  };
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /channels/kb'] = (_) => channel.record.json;
  api.routes['GET /channels/$threadId'] = (_) => thread.record.json;
  api.routes['GET /channels/kb/threads/${parent['id']}'] = (_) => {
    'threadChannelId': threadId,
  };
  api.routes['GET /channels/inbox'] = (_) => {'items': <dynamic>[]};
  api.routes['GET /channels/saved'] = (_) => {
    'globalTotal': 0,
    'saved': <dynamic>[],
  };
  api.routes['GET /channels/threads/followed'] = (_) => {
    'threads': <dynamic>[],
  };
  api.routes['GET /announcements/active'] = (_) => {
    'announcements': <dynamic>[],
  };
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': <dynamic>[],
  };
  api.routes['GET /tasks/server'] = (_) => {'tasks': <dynamic>[]};
  const tabs = MobileTabbarSettings(
    order: MobileTabs.configurable,
    enabled: {
      MobileTabs.home,
      MobileTabs.tasks,
      MobileTabs.members,
      MobileTabs.computers,
    },
  );
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': 'light',
    'raft.light': const String.fromEnvironment(
      'KB_THEME',
      defaultValue: 'brutal',
    ),
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  final dir = await Directory.systemTemp.createTemp('raft-keyboard-jank-');
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab'),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
  );
}

/// `KBJ f <buildStart> <build> <raster> <total>` per frame and
/// `KBJ m <timelineNow> <insetPx>` per metrics change; all microseconds on the
/// engine clock (the same clock as the VM timeline).
void _installFrameLog() {
  final binding = WidgetsBinding.instance;
  binding.addTimingsCallback((timings) {
    for (final t in timings) {
      // ignore: avoid_print
      print(
        'KBJ f ${t.timestampInMicroseconds(ui.FramePhase.buildStart)} ${t.buildDuration.inMicroseconds} ${t.rasterDuration.inMicroseconds} ${t.totalSpan.inMicroseconds}',
      );
    }
  });
  binding.addObserver(_MetricsLog());
  if (kDebugMode) {
    // Marks the end of each frame's build in the rebuild log (debug builds).
    binding.addPersistentFrameCallback((_) {
      if (debugPrintRebuildDirtyWidgets) {
        // ignore: avoid_print
        print('KBJ frame');
      }
    });
  }
}

class _MetricsLog with WidgetsBindingObserver {
  Timer? _dirtyOff;
  MediaQueryData? _last;

  @override
  void didChangeMetrics() {
    // Debug builds only (`--dart-define=KBJ_DIRTY=true`): print every widget
    // the framework rebuilds, with its dependencies, for the frames of a
    // keyboard animation.
    if (kDebugMode && const bool.fromEnvironment('KBJ_DIRTY')) {
      debugPrintRebuildDirtyWidgets = true;
      _dirtyOff?.cancel();
      _dirtyOff = Timer(
        const Duration(milliseconds: 500),
        () => debugPrintRebuildDirtyWidgets = false,
      );
    }
    final v = WidgetsBinding.instance.platformDispatcher.views.first;
    final data = MediaQueryData.fromView(v);
    final old = _last;
    _last = data;
    if (old != null) {
      final changed = <String>[
        if (data.size != old.size) 'size',
        if (data.viewInsets != old.viewInsets) 'viewInsets',
        if (data.padding != old.padding) 'padding',
        if (data.viewPadding != old.viewPadding) 'viewPadding',
        if (data.systemGestureInsets != old.systemGestureInsets)
          'systemGestureInsets',
        if (data.textScaler != old.textScaler) 'textScaler',
        if (data.displayFeatures.length != old.displayFeatures.length)
          'displayFeatures',
        if (data.devicePixelRatio != old.devicePixelRatio) 'dpr',
        if (data.platformBrightness != old.platformBrightness) 'brightness',
        if (data.gestureSettings != old.gestureSettings) 'gestureSettings',
        if (data.accessibleNavigation != old.accessibleNavigation)
          'accessibleNavigation',
      ];
      // ignore: avoid_print
      print('KBJ c ${changed.join(',')} size=${data.size}');
    }
    // ignore: avoid_print
    print(
      'KBJ m ${developer.Timeline.now} ${v.viewInsets.bottom.round()} h=${v.physicalSize.height.round()} pad=${v.padding.bottom.round()} vpad=${v.viewPadding.bottom.round()}',
    );
  }
}
