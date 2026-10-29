import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// The package exports its notification model but not the hint types; the
// `desktop-entry` hint is the only way to bind an alert to the launcher.
// ignore: implementation_imports
import 'package:flutter_local_notifications_linux/src/model/hint.dart';
import 'package:path/path.dart' as p;

/// Suffix of an isolated test build, for example `.isolated`; empty for the
/// real app. linux/CMakeLists.txt reads the same value from the environment
/// variable `RAFT_APPLICATION_ID_SUFFIX` while tool/release.py passes it here,
/// so the GApplication id, the XDG data/cache directories and the keyring
/// attribute all move together.
const linuxApplicationIdSuffix = String.fromEnvironment(
  'RAFT_LINUX_APPLICATION_ID_SUFFIX',
);

/// True for an isolated test build, which must leave the host's `raft://`
/// handler, mime defaults and desktop files alone.
const linuxIsolatedBuild = linuxApplicationIdSuffix != '';

/// GApplication / window app id of the Linux runner (linux/CMakeLists.txt).
const linuxApplicationId = 'app.raft.raft_flutter$linuxApplicationIdSuffix';

/// Desktop file the AppImage registers in the member's own applications
/// directory. Its id differs from the packaged launcher so both can coexist.
const linuxAppImageDesktopId = '$linuxApplicationId-appimage';

/// Where the runner installs its icon, relative to the executable's directory
/// (linux/CMakeLists.txt) and below the XDG data home once registered.
const linuxIconRelative = 'icons/hicolor/256x256/apps/$linuxApplicationId.png';

/// True for the AppImage runtime, which exports the image path as `APPIMAGE`.
bool runningFromAppImage(Map<String, String> environment) =>
    (environment['APPIMAGE'] ?? '').isNotEmpty;

/// `$XDG_DATA_HOME`, or `$HOME/.local/share` when unset or not absolute.
String? linuxDataHome(Map<String, String> environment) {
  final configured = environment['XDG_DATA_HOME'] ?? '';
  if (configured.isNotEmpty && p.isAbsolute(configured)) return configured;
  final home = environment['HOME'] ?? '';
  return home.isEmpty || !p.isAbsolute(home)
      ? null
      : p.join(home, '.local', 'share');
}

/// The icon file a Linux notification or desktop entry can reference: the
/// member's installed copy while an AppImage is registered (it outlives the
/// image's mount), otherwise the icon bundled next to the executable.
String? linuxAppIconPath({
  Map<String, String>? environment,
  String? executable,
  bool Function(String path)? exists,
}) {
  final env = environment ?? Platform.environment;
  final present = exists ?? (path) => File(path).existsSync();
  if (runningFromAppImage(env)) {
    final data = linuxDataHome(env);
    if (data != null) {
      final installed = p.join(data, linuxIconRelative);
      if (present(installed)) return installed;
    }
  }
  return bundledLinuxIconPath(executable: executable, exists: exists);
}

/// The icon the runner bundle installs beside the executable.
String? bundledLinuxIconPath({
  String? executable,
  bool Function(String path)? exists,
}) {
  final bundled = p.join(
    p.dirname(executable ?? Platform.resolvedExecutable),
    'data',
    linuxIconRelative,
  );
  return (exists ?? (path) => File(path).existsSync())(bundled)
      ? bundled
      : null;
}

/// The `desktop-entry` hint ties a notification to the launcher the desktop
/// already knows (icon, per-app notification settings, "Open" behaviour).
String linuxDesktopEntryId({
  Map<String, String>? environment,
  bool Function(String path)? exists,
}) {
  final env = environment ?? Platform.environment;
  if (!runningFromAppImage(env)) return linuxApplicationId;
  final data = linuxDataHome(env);
  final present = exists ?? (path) => File(path).existsSync();
  return data != null &&
          present(
            p.join(data, 'applications', '$linuxAppImageDesktopId.desktop'),
          )
      ? linuxAppImageDesktopId
      : linuxApplicationId;
}

/// org.freedesktop.Notifications presentation of one message alert: the app
/// icon, the instant-message category (desktops route it to chat settings and
/// DND rules), normal urgency and the launcher id.
LinuxNotificationDetails linuxMessageNotificationDetails({
  String? iconPath,
  String? desktopEntry,
}) => LinuxNotificationDetails(
  icon: iconPath == null ? null : FilePathLinuxIcon(iconPath),
  category: LinuxNotificationCategory.imReceived,
  urgency: LinuxNotificationUrgency.normal,
  customHints: [
    if (desktopEntry != null)
      LinuxNotificationCustomHint<String>(
        name: 'desktop-entry',
        value: LinuxHintStringValue(desktopEntry),
      ),
  ],
);
