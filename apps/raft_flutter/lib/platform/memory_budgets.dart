import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:raft_ui/raft_ui.dart';

import 'device_memory.dart';

/// The kind of device whose memory the budgets are sized for.
enum RaftMemoryClass {
  /// Android and iOS: a few GB shared with every other app, killed rather than
  /// swapped when the foreground app is too large.
  phone,

  /// Linux, macOS and Windows: gigabytes to spare, a window that may be
  /// resized to 4K.
  desktop,
}

enum RaftMemoryTier { low, medium, high }

/// Every rebuildable in-memory tier of the app and its limit, in one place
/// (the table in docs/architecture.md, "Cache", mirrors [describe]). Disk
/// tiers are not here: `AttachmentDiskCache` owns the 1 GiB budget.
///
/// Nothing in these tiers is the only copy of anything: a bitmap, a still or a
/// remembered verdict that is let go of is decoded or measured again on demand.
/// `RaftMemoryRelease` empties them while the app is hidden and under memory
/// pressure. Attachment images have an idle retention target and a separate
/// temporary active allowance, selected from total device RAM at startup.
///
/// | tier | owner | phone | desktop |
/// |---|---|---|---|
/// | framework `ImageCache` (decoded `Image` providers: sized images, avatars on remount, markdown / link previews, emoji) | `PaintingBinding` | 200 images / 64 MiB | 500 images / 128 MiB |
/// | attachment images, decoded (idle / active, low tier) | `AttachmentImageRepository` | 64 images / 64 / 192 MiB | 64 images / 96 / 384 MiB |
/// | attachment images, encoded (decode source) | `AttachmentImageRepository` | 32 MiB | 64 MiB |
/// | avatar bitmaps, decoded | `RaftHotImages` | 384 / 24 MiB | 384 / 24 MiB |
/// | avatar bytes, encoded | `RaftImageBytes` | 8 MiB | 8 MiB |
/// | video stills | `PlayerSessions` | 24 / 16 MiB | 24 / 16 MiB |
/// | video / audio players | `PlayerSessions` | 2 live (native demuxer 32 or 64 MiB + 8 MiB back each) | same |
/// | HDR verdicts, prepared set, resume positions | `PlayerSessions` | 256 each | 256 each |
/// | signed attachment URLs | `AttachmentUrlCache` | 256 entries, 4 min | same |
@immutable
class RaftMemoryBudgets {
  const RaftMemoryBudgets._({
    required this.memoryClass,
    required this.imageCacheEntries,
    required this.imageCacheBytes,
    required this.attachmentImageEntries,
    required this.attachmentImageDecodedBytes,
    required this.attachmentImageEncodedBytes,
    required this.attachmentImageActiveDecodedBytes,
    this.memoryTier = RaftMemoryTier.low,
  });

  final RaftMemoryClass memoryClass;
  final RaftMemoryTier memoryTier;

  /// The framework `ImageCache` (`PaintingBinding.instance.imageCache`):
  /// `maximumSize` and `maximumSizeBytes`.
  final int imageCacheEntries, imageCacheBytes;

  /// [AttachmentImageRepository]: entries, decoded and encoded bytes.
  final int attachmentImageEntries,
      attachmentImageDecodedBytes,
      attachmentImageEncodedBytes;

  /// Temporary total while images are actively viewed; idle retention uses
  /// [attachmentImageDecodedBytes]. This is not a reservation of OS memory.
  final int attachmentImageActiveDecodedBytes;

  static const _mib = 1024 * 1024;

  static const phone = RaftMemoryBudgets._(
    memoryClass: RaftMemoryClass.phone,
    imageCacheEntries: 200,
    imageCacheBytes: 64 * _mib,
    attachmentImageEntries: 64,
    attachmentImageDecodedBytes: 64 * _mib,
    attachmentImageEncodedBytes: 32 * _mib,
    attachmentImageActiveDecodedBytes: 192 * _mib,
  );

  static const desktop = RaftMemoryBudgets._(
    memoryClass: RaftMemoryClass.desktop,
    imageCacheEntries: 500,
    imageCacheBytes: 128 * _mib,
    attachmentImageEntries: 64,
    attachmentImageDecodedBytes: 96 * _mib,
    attachmentImageEncodedBytes: 64 * _mib,
    attachmentImageActiveDecodedBytes: 384 * _mib,
  );

  // Tiers that do not differ by device class.

  /// Decoded avatar bitmaps ([RaftHotImages]) and their encoded bytes
  /// ([RaftImageBytes]); owned by raft_ui.
  static const avatarHotEntries = RaftHotImages.defaultMaxEntries;
  static const avatarHotBytes = RaftHotImages.defaultMaxBytes;
  static const avatarEncodedBytes = RaftImageBytes.defaultMemoryBudgetBytes;

  /// Video stills kept per attachment (card-sized pictures).
  static const playerStillEntries = 24;
  static const playerStillBytes = 16 * _mib;

  /// Entries of each of the small remembered maps of `PlayerSessions`.
  static const playerRememberedEntries = 256;

  /// Concurrent native players (see `PlayerSessions.maxLive`).
  static const playerLive = 2;

  /// The budgets of the platform the app runs on.
  static RaftMemoryBudgets get current =>
      forPlatform(defaultTargetPlatform, memory: _deviceMemory);

  static DeviceMemoryInfo? _deviceMemory;

  /// Complete before creating workspaces or installing the app's caches.
  static Future<void> initialize({Future<DeviceMemoryInfo?> Function()? probe}) async {
    try {
      _deviceMemory = await (probe ?? readDeviceMemory)().timeout(const Duration(milliseconds: 500));
    } catch (_) {
      _deviceMemory = null;
    }
  }

  @visibleForTesting
  static void resetDetection() => _deviceMemory = null;

  static RaftMemoryBudgets forPlatform(TargetPlatform platform, {DeviceMemoryInfo? memory}) {
    final base = switch (platform) {
        TargetPlatform.android || TargetPlatform.iOS => phone,
        _ => desktop,
      };
    final bytes = memory?.totalBytes ?? 0;
    if (bytes <= 0 || memory!.lowRam) return base;
    final mobile = base.memoryClass == RaftMemoryClass.phone;
    final low = (mobile ? 3 : 8) * 1024 * _mib;
    final mid = (mobile ? 6 : 16) * 1024 * _mib;
    if (bytes <= low) return base;
    final high = bytes > mid;
    return RaftMemoryBudgets._(
      memoryClass: base.memoryClass,
      memoryTier: high ? RaftMemoryTier.high : RaftMemoryTier.medium,
      imageCacheEntries: base.imageCacheEntries,
      imageCacheBytes: base.imageCacheBytes,
      attachmentImageEntries: base.attachmentImageEntries,
      attachmentImageEncodedBytes: base.attachmentImageEncodedBytes,
      attachmentImageDecodedBytes: (mobile ? (high ? 256 : 128) : (high ? 256 : 192)) * _mib,
      attachmentImageActiveDecodedBytes: (mobile ? (high ? 768 : 384) : (high ? 1024 : 768)) * _mib,
    );
  }

  /// Sets the framework image cache limits. Returns a callback that restores
  /// the limits the cache had (shrinking evicts the oldest entries at once).
  VoidCallback applyImageCache([ImageCache? cache]) {
    final target = cache ?? PaintingBinding.instance.imageCache;
    final entries = target.maximumSize, bytes = target.maximumSizeBytes;
    target
      ..maximumSize = imageCacheEntries
      ..maximumSizeBytes = imageCacheBytes;
    return () => target
      ..maximumSize = entries
      ..maximumSizeBytes = bytes;
  }

  /// One line per tier, for logs and the tests that pin the table.
  List<String> describe() => [
    'imageCache $imageCacheEntries images / ${imageCacheBytes ~/ _mib} MiB',
    'attachmentImages $attachmentImageEntries images / '
        '${attachmentImageDecodedBytes ~/ _mib} MiB decoded / '
        '${attachmentImageEncodedBytes ~/ _mib} MiB encoded / '
        '${attachmentImageActiveDecodedBytes ~/ _mib} MiB active (${memoryTier.name})',
    'avatarHot $avatarHotEntries / ${avatarHotBytes ~/ _mib} MiB',
    'avatarBytes ${avatarEncodedBytes ~/ _mib} MiB',
    'playerStills $playerStillEntries / ${playerStillBytes ~/ _mib} MiB',
    'playerLive $playerLive',
    'playerRemembered $playerRememberedEntries',
  ];
}
