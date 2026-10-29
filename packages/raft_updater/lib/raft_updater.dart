/// In-app updates for Raft on macOS (Sparkle 2), Windows (WinSparkle) and
/// Linux AppImages (zsync delta updates).
///
/// Call `AppUpdater.instance.checkAndInstall()` from an "update available"
/// button. See `docs/auto-update.md`.
library;

export 'src/app_updater.dart';
export 'src/appimage/appimage_failure.dart';
export 'src/appimage/appimage_http.dart'
    show AppImageHttp, AppImageHttpClientFactory;
export 'src/appimage/update_information.dart' show AppImageUpdateInformation;
export 'src/appimage/appimage_updater.dart'
    show
        AppImageRelease,
        AppImageTransferReport,
        AppImageUpdatePhase,
        AppImageUpdateStage,
        AppImageUpdateStatus,
        AppImageUpdater;
