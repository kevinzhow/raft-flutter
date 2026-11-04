import 'dart:async';

import 'package:path_provider/path_provider.dart';

import 'data/attachment_disk_cache.dart';
import 'data/avatar_image_store.dart';
import 'data/cache_budget.dart';
import 'data/cache_clear.dart';
import 'platform/cache_hygiene.dart';
import 'platform/cache_staging.dart';
import 'platform/desktop_cache_scope.dart';

/// Cache ownership is window-local; only the primary sweeps shared history.
Future<void> initializeAppCaches({required bool isChild}) async {
  // Warm authority-gated attachment bytes under the stored cache budgets.
  AttachmentDiskCache.installed ??= AttachmentDiskCache(
    () =>
        DesktopCacheScope.directory('attachments') ??
        getApplicationCacheDirectory(),
    maxBytes: CacheBudget.stored(),
    publicMaxBytes: attachmentPublicCacheMaxBytes,
  );
  unawaited(AttachmentDiskCache.installed!.warm());
  // One startup pass removes expired staging and retired-account caches.
  if (!isChild) {
    unawaited(runStartupCacheHygiene(cache: AttachmentDiskCache.installed!));
  }
  installAvatarImageCache(AttachmentDiskCache.installed!);
  // Clear cache covers app layers; workspaces register their memory layers.
  CacheClear.instance.installAppLayers(
    cache: AttachmentDiskCache.installed,
    stagingDirectory: cacheStagingDirectory,
    legacyTemporary: () =>
        DesktopCacheScope.directory('legacy') ?? getTemporaryDirectory(),
  );
}
