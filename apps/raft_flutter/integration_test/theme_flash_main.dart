// ignore_for_file: avoid_print
// Debug/profile-only entrypoint: the production startup path (deferred first
// frame, RootErrorBoundary, RaftApp restore) on perf-lab fixtures, no login,
// and REAL persisted SharedPreferences, so a cold start (`am force-stop` +
// `am start`) reads the stored appearance from disk exactly like the formal
// App. See docs/theme-flash.md.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/theme_flash_main.dart
//
// Seed once (writes the real preferences), then cold-start as often as needed:
//   adb shell 'echo "dark elegant" > /data/local/tmp/raft-theme-flash.txt; chmod 644 ...'
//   ("<mode light|dark|system> <family brutal|elegant|...> [icon yellow|blue|green|white|pink] [nodefer]")
// Delete the file afterwards: later launches read what is stored.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/root_error_boundary.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/app_icon.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart' show RaftAppIconPalette;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

// Android: pushed with adb. Desktop: THEME_FLASH_SEED=<file> in the environment.
final _seedFile = Platform.environment['THEME_FLASH_SEED'] ?? '/data/local/tmp/raft-theme-flash.txt';
final _boot = Stopwatch()..start();

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  _boot.start();
  final seed = File(_seedFile);
  if (seed.existsSync()) {
    final parts = seed.readAsStringSync().trim().split(RegExp(r'\s+'));
    final p = await SharedPreferences.getInstance();
    await p.setString('raft.mode', parts[0]);
    await p.setString('raft.light', parts.length > 1 ? parts[1] : 'brutal');
    await p.setString('raft.origin', 'https://example.invalid');
    // THEME_FLASH_PRESENTATION='{"font":"lg","hideEmptySections":false}': the
    // stored Appearance-section choices (font size, hidden empty sections...).
    final presentation = Platform.environment['THEME_FLASH_PRESENTATION'];
    if (presentation != null) {
      await p.setString('raft:presentation:["https://example.invalid","alice"]', presentation);
    }
    // `nodefer` skips deferFirstFrame: shows what any path that paints before
    // the stored appearance is known would put on screen.
    await p.setBool('theme_flash.nodefer', parts.length > 3 && parts[3] == 'nodefer');
    if (parts.length > 2 && Platform.isAndroid) {
      // The launcher icon (and so the native splash colour) of the isolated package.
      final icon = NativeAppIcon.instance;
      await icon.refresh();
      await icon.select(RaftAppIconPalette.values.byName(parts[2]));
      print('theme-flash: icon=${icon.selected.name} error=${icon.error}');
    }
    final tabs = const MobileTabbarSettings(
      order: MobileTabs.configurable,
      enabled: {MobileTabs.home, MobileTabs.tasks, MobileTabs.members, MobileTabs.computers},
    );
    await p.setString(MobileTabbarStore.preferenceKey, tabs.encode());
  }
  // First frames read saved layout choices synchronously from this.
  await DevicePreferences.load();

  final channel = LabChannel('kb', List.filled(40, 'plain'));
  final images = await LabImages.start();
  final (wsSeed, api, client) = await labWorkspace([channel], images, mobile: true, ownsClient: false);
  wsSeed.dispose();
  api.routes['GET /auth/me'] = (_) => {
    'id': 'alice', 'name': 'Alice Zhang', 'email': 'alice@example.invalid', 'emailVerified': true, 'displayLanguage': 'en',
  };
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /channels/kb'] = (_) => channel.record.json;
  api.routes['GET /channels/inbox'] = (_) => {'items': <dynamic>[]};
  api.routes['GET /channels/saved'] = (_) => {'globalTotal': 0, 'saved': <dynamic>[]};
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': <dynamic>[]};
  api.routes['GET /announcements/active'] = (_) => {'announcements': <dynamic>[]};
  api.routes['GET /product-feedback/tickets'] = (_) => {'unread_total': 0, 'tickets': <dynamic>[]};
  api.routes['GET /tasks/server'] = (_) => {'tasks': <dynamic>[]};
  // THEME_FLASH_CACHE=<dir> keeps the workspace cache between launches, so the
  // second cold start paints from the on-device cache (cache-first start).
  final cacheDir = Platform.environment['THEME_FLASH_CACHE'];
  final dir = cacheDir != null
      ? await Directory(cacheDir).create(recursive: true)
      : await Directory.systemTemp.createTemp('raft-theme-flash-');

  // === Same sequence as lib/main.dart main() from here. ===
  RootErrors.instance.install();
  final defer = DevicePreferences.current?.getBool('theme_flash.nodefer') != true;
  if (defer) WidgetsBinding.instance.deferFirstFrame();
  var firstFrameAllowed = !defer;
  void allowFirstFrame() {
    if (firstFrameAllowed) return;
    firstFrameAllowed = true;
    print('theme-flash: allowFirstFrame t=${_boot.elapsedMilliseconds}ms');
    WidgetsBinding.instance.allowFirstFrame();
  }

  void releaseOnError() {
    if (RootErrors.instance.current != null) allowFirstFrame();
  }

  RootErrors.instance.addListener(releaseOnError);
  WidgetsBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      print('theme-flash: frame raster-finish t=${_boot.elapsedMilliseconds}ms '
          'build=${t.buildDuration.inMicroseconds}us');
    }
  });
  runApp(
    RootErrorBoundary(
      child: ProviderScope(
        child: app.RaftApp(
          services: const AppServices.updatesDisabledForTestOrPreview(),
          sessionStore: client.sessionStore,
          createClient: (_, _, _) => client,
          initialLocation: Uri(path: '/s/lab'),
          nativeContent: LabNavigationContent(),
          nativeSharing: NativeSharing(supported: false),
          openWorkspaceCache: () async => LabNavigationCache(File('${dir.path}/workspace.sqlite')),
          onStartupReady: allowFirstFrame,
        ),
      ),
    ),
  );
}
