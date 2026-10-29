import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart' show RaftRailSide;
import 'package:shared_preferences/shared_preferences.dart';

import 'device_preferences.dart';

/// Device-local choice of the side the phone layout's rail takes (wide
/// foldable, landscape phone): `start` (default) or `end`, in leading /
/// trailing terms so right-to-left locales mirror it. Like the other layout
/// choices it reads the preloaded [DevicePreferences] synchronously, so the
/// first frame already has the rail on its side.
class RailSideStore extends ChangeNotifier {
  RailSideStore() : side = parse(_stored());

  static const preferenceKey = 'raft.railSide';

  /// Unknown or missing values are the default.
  static RaftRailSide parse(String? raw) =>
      raw == 'end' ? RaftRailSide.end : RaftRailSide.start;

  static String? _stored() {
    try {
      return DevicePreferences.current?.getString(preferenceKey);
    } catch (_) {
      return null;
    }
  }

  RaftRailSide side;

  void update(RaftRailSide next) {
    if (next == side) return;
    side = next;
    notifyListeners();
    final loaded = DevicePreferences.current;
    Future<void> write(SharedPreferences p) async {
      try {
        next == RaftRailSide.start
            ? await p.remove(preferenceKey)
            : await p.setString(preferenceKey, next.name);
      } catch (_) {
        /* optional local storage */
      }
    }

    if (loaded != null) {
      write(loaded);
    } else {
      SharedPreferences.getInstance().then(write, onError: (_) {});
    }
  }
}

/// Touch-first platforms (Android, iOS: phones, foldables, tablets) follow the
/// rail side choice in every layout, the desktop layout of an unfolded inner
/// screen included. Computers (macOS, Windows, Linux) keep the navigation on
/// the left in the desktop layout and offer the choice only while a narrow
/// window shows the phone rail. Decided by platform, never by window size.
bool railSideFollowsChoice() =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;
