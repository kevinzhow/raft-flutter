import 'package:raft_ui/raft_ui.dart' show RaftLayoutMetrics;
import 'package:shared_preferences/shared_preferences.dart';

import 'device_preferences.dart';

/// Device-local memory of the Tasks Board/List choice. Web TasksPanel keeps it
/// under `slock.tasks.viewMode` and shares it between the server-wide page and
/// every channel Tasks tab: the stored choice wins over the viewport default
/// (Board on desktop, List on a phone). Reads use the preloaded
/// [DevicePreferences] so the first frame already has the remembered layout.
abstract final class TaskViewModePreference {
  static const preferenceKey = 'raft.tasks.viewMode';

  /// Only `board` and `list` are modes; anything else is "no choice yet".
  static String? parse(Object? raw) =>
      raw == 'board' || raw == 'list' ? raw as String : null;

  /// The remembered mode, or null before the user ever picked one.
  static String? read() {
    try {
      return parse(DevicePreferences.current?.getString(preferenceKey));
    } catch (_) {
      return null;
    }
  }

  /// The layout a Tasks page opens with: the remembered mode, else the
  /// viewport default (Board from the desktop breakpoint, List below it).
  static String initial(double width) =>
      read() ??
      (width >= RaftLayoutMetrics.desktopBreakpoint ? 'board' : 'list');

  /// Remembers [mode]; storage failures are ignored (the viewport default
  /// still applies), like Web.
  static void write(String mode) {
    if (parse(mode) == null) return;
    final loaded = DevicePreferences.current;
    Future<void> store(SharedPreferences p) async {
      try {
        await p.setString(preferenceKey, mode);
      } catch (_) {
        /* optional local storage */
      }
    }

    if (loaded != null) {
      store(loaded);
    } else {
      SharedPreferences.getInstance().then(store, onError: (_) {});
    }
  }
}

/// The layout a Tasks page opens with (see [TaskViewModePreference.initial]).
String initialTaskView(double width) => TaskViewModePreference.initial(width);

/// Remembers the Board/List choice (see [TaskViewModePreference.write]).
void rememberTaskView(String mode) => TaskViewModePreference.write(mode);
