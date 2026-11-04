import 'app_cache_bootstrap.dart';

import 'app_bootstrap.dart';
import 'platform/desktop_window_runtime.dart';
import 'data/device_preferences.dart';
import 'data/source_time_formatter.dart';
import 'platform/android_performance_hint.dart';
import 'platform/file_selection.dart' show configureAndroidPhotoPicker;
import 'platform/memory_budgets.dart';
import 'platform/system_proxy_bootstrap.dart';
import 'platform/system_fonts.dart';

export 'app_root.dart';

Future<void> main([List<String> args = const []]) async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  final desktopWindows = await initializeDesktopWindows(args);
  await RaftMemoryBudgets.initialize();
  configureAndroidPhotoPicker();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  // First frames read saved layout choices synchronously from this.
  await DevicePreferences.load();
  // Networking shares the OS/manual proxy decision (docs/system-proxy.md).
  await startSystemProxy(
    preferences: DevicePreferences.current,
    origins: [
      DevicePreferences.current?.getString('raft.origin') ??
          const String.fromEnvironment(
            'RAFT_ORIGIN',
            defaultValue: 'https://api.raft.build',
          ),
    ],
  );
  await initializeAppCaches(isChild: desktopWindows?.isChild == true);
  runRaftAppRoot(args, desktopWindows: desktopWindows);
}
