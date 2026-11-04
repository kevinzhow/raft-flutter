import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_preferences.dart';
import 'display_language_preferences.dart';

/// Device-owned display choices. The app root holds one owner for its theme
/// and anonymous UI locale; account language remains a server-owned fact.
class DeviceDisplayPreferences extends ChangeNotifier {
  DeviceDisplayPreferences() {
    displayLanguage.addListener(changed);
  }
  RaftAppearance value = storedAppearance();
  final displayLanguage = DisplayLanguagePreferences();
  bool _disposed = false;

  void changed() {
    if (!_disposed) notifyListeners();
  }

  void adopt(SharedPreferences preferences) {
    if (_disposed) return;
    value = storedAppearance(preferences);
    displayLanguage.adopt(preferences);
    changed();
  }

  Future<void> save(RaftAppearance next) async {
    if (_disposed) return;
    value = next;
    changed();
    await saveAppearance(await SharedPreferences.getInstance(), next);
  }

  @override
  void dispose() {
    _disposed = true;
    displayLanguage.removeListener(changed);
    displayLanguage.dispose();
    super.dispose();
  }
}
