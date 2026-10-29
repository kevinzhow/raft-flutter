import 'dart:async';

import 'package:path_provider/path_provider.dart';

import 'app_root.dart';
import 'data/attachment_disk_cache.dart';
import 'data/avatar_image_store.dart';
import 'data/cache_budget.dart';
import 'data/cache_clear.dart';
import 'data/device_preferences.dart';
import 'data/source_time_formatter.dart';
import 'platform/android_performance_hint.dart';
import 'platform/cache_hygiene.dart';
import 'platform/cache_staging.dart';
import 'platform/file_selection.dart' show configureAndroidPhotoPicker;
import 'platform/memory_budgets.dart';
import 'platform/system_proxy_bootstrap.dart';
import 'platform/system_fonts.dart';

export 'app_root.dart';

Future<void> main([List<String> args = const []]) async {
  RaftWidgetsFlutterBinding.ensureInitialized();
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
  // Warm authority-gated attachment bytes under the stored cache budgets.
  AttachmentDiskCache.installed ??= AttachmentDiskCache(
    getApplicationCacheDirectory,
    maxBytes: CacheBudget.stored(),
    publicMaxBytes: attachmentPublicCacheMaxBytes,
  );
  unawaited(AttachmentDiskCache.installed!.warm());
  // One startup pass removes expired staging and retired-account caches.
  unawaited(runStartupCacheHygiene(cache: AttachmentDiskCache.installed!));
  installAvatarImageCache(AttachmentDiskCache.installed!);
  // Clear cache covers app layers; workspaces register their memory layers.
  CacheClear.instance.installAppLayers(
    cache: AttachmentDiskCache.installed,
    stagingDirectory: cacheStagingDirectory,
    legacyTemporary: getTemporaryDirectory,
  );
  runRaftAppRoot(args);
}
