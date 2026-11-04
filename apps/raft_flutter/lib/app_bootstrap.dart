import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/system_proxy.dart' show SystemProxy;
import 'package:raft_updater/raft_updater.dart' show AppUpdater;

import 'app_root.dart';
import 'features/root_error_boundary.dart';
import 'platform/app_update.dart';
import 'platform/app_update_smoke.dart';
import 'platform/app_services.dart';
import 'platform/desktop_windows.dart';

/// Creates the owned application services after native bootstrap is ready.
void runRaftAppRoot(List<String> args, {DesktopWindows? desktopWindows}) {
  // Release builds show the root fallback instead of a grey/red screen.
  RootErrors.instance.install();
  // The branded splash stays until startup is ready; a fatal startup error
  // releases the first frame too, so the root fallback can paint.
  WidgetsBinding.instance.deferFirstFrame();
  var firstFrameAllowed = false;
  void allowFirstFrame() {
    if (firstFrameAllowed) return;
    firstFrameAllowed = true;
    WidgetsBinding.instance.allowFirstFrame();
  }

  void releaseOnError() {
    if (RootErrors.instance.current != null) allowFirstFrame();
  }

  RootErrors.instance.addListener(releaseOnError);
  // Release builds only: dev/local builds and platforms without a GitHub
  // release asset get a disabled service. Starts after the first frame.
  if (desktopWindows?.isChild == true) {
    runApp(
      RootErrorBoundary(
        child: RaftApp(
          initialLocation: desktopWindows!.initialLocation,
          onStartupReady: allowFirstFrame,
          services: AppServices.updatesDisabledForTestOrPreview(
            desktopWindows: desktopWindows,
          ),
        ),
      ),
    );
    unawaited(
      WidgetsBinding.instance.waitUntilFirstFrameRasterized.then(
        (_) => desktopWindows.frameReady(),
      ),
    );
    return;
  }
  final updateOrigin = updateOriginOverride();
  final appUpdate = AppUpdateService.forThisBuild(origin: updateOrigin);
  // Linux AppImage in-place updates use the app's proxy-aware HTTP client.
  AppUpdater.instance.configureAppImage(
    httpClientFactory: (url) async {
      await SystemProxy.instance.ready(url);
      return SystemProxy.instance.createHttpClient();
    },
    origin: updateOrigin,
  );
  runApp(
    RootErrorBoundary(
      child: RaftApp(
        initialArguments: args,
        onStartupReady: allowFirstFrame,
        services: AppServices.withUpdates(
          appUpdate,
          desktopWindows: desktopWindows,
        ),
        ownsAppUpdate: true,
      ),
    ),
  );
  unawaited(
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) async {
      await appUpdate.start();
      await runAppImageUpdateSmoke(
        appUpdate,
        AppUpdater.instance,
        origin: updateOrigin,
      );
    }),
  );
}
