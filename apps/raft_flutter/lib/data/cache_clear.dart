import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../platform/cache_staging.dart';
import 'attachment_disk_cache.dart';

/// What one [CacheClear.run] did.
class CacheClearResult {
  const CacheClearResult(this.cleared, this.failed);

  /// Hooks that completed, in the order they ran.
  final List<String> cleared;

  /// Hooks that threw, by name. The others still ran.
  final Map<String, Object> failed;

  bool get ok => failed.isEmpty;
}

/// The one place "Clear cache" (Settings > Storage) goes through. Every layer
/// that holds rebuildable data registers a named hook and the page knows none
/// of them: the disk cache, the decoded and encoded picture layers, the signed
/// URL cache, the video stills, the staging folders. A layer added later
/// registers itself and is cleared with the rest; the page does not change.
///
/// A hook may only drop data that is rebuilt on demand. Never register
/// anything that is the user's: the sign-in, drafts, settings, the workspace
/// database, files the user saved, files received from other apps
/// (`raft-incoming`). A hook leaves alone what is in use right now (an open
/// preview's file, a playing player, a running transfer).
///
/// Hooks run one after the other in registration order, so a layer in front
/// of another is registered after it (disk first, memory after): a hook that
/// throws is reported and the rest still run.
class CacheClear {
  CacheClear();

  /// The app-wide coordinator. Tests make their own.
  static final CacheClear instance = CacheClear();

  final List<_Hook> _hooks = [];
  Future<CacheClearResult>? _running;

  /// Names of the registered hooks, in running order.
  List<String> get names => [for (final hook in _hooks) hook.name];

  /// Adds [hook] under [name]. Returns the callback that removes it (a layer
  /// that is disposed, such as a workspace's image repository, calls it).
  VoidCallback register(String name, FutureOr<void> Function() hook) {
    final entry = _Hook(name, hook);
    _hooks.add(entry);
    return () => _hooks.remove(entry);
  }

  /// Runs every hook. A second call while one is running joins it.
  Future<CacheClearResult> run() => _running ??= _run().whenComplete(() {
    _running = null;
  });

  Future<CacheClearResult> _run() async {
    final cleared = <String>[];
    final failed = <String, Object>{};
    for (final hook in List.of(_hooks)) {
      try {
        await hook.run();
        cleared.add(hook.name);
      } catch (error, stack) {
        failed[hook.name] = error;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'raft cache clear',
            context: ErrorDescription('while clearing "${hook.name}"'),
          ),
        );
      }
    }
    return CacheClearResult(cleared, failed);
  }

  /// Registers the layers that exist once per app: both namespaces of [cache]
  /// (the avatar layer in front of the public one is cleared by the cache's own
  /// listener, see `installAvatarImageCache`), the framework `ImageCache`, and
  /// the staging folders (where step 3 keeps them: [stagingDirectory], and
  /// what earlier versions left in [legacyTemporary]). Workspace-scoped layers
  /// (decoded attachment pictures, signed URLs, stills) are registered by their
  /// owner. Returns the callback that removes them again.
  VoidCallback installAppLayers({
    AttachmentDiskCache? cache,
    Future<Directory> Function()? stagingDirectory,
    Future<Directory> Function()? legacyTemporary,
  }) {
    final removers = <VoidCallback>[
      if (cache != null) register('disk', cache.clear),
      if (stagingDirectory != null)
        register('staging', () async {
          await clearStaging(
            staging: await stagingDirectory(),
            legacyTemporary: await legacyTemporary?.call(),
          );
        }),
      // Decoded pictures nobody shows; the ones on screen stay (they are
      // tracked as live) and are released when their widget goes.
      register('image-cache', PaintingBinding.instance.imageCache.clear),
    ];
    return () {
      for (final remove in removers) {
        remove();
      }
    };
  }
}

class _Hook {
  _Hook(this.name, this.run);
  final String name;
  final FutureOr<void> Function() run;
}
