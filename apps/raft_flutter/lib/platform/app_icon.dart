import 'package:flutter/foundation.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus_platform_interface.dart';
import 'package:raft_ui/raft_ui.dart';

import 'launch_theme.dart';

/// Device-wide icon state, read back from the operating system after a change.
class NativeAppIcon extends ChangeNotifier {
  NativeAppIcon({
    FlutterDynamicIconPlusPlatform? api,
    this.platformOverride,
    NativeLaunchTheme? launchTheme,
  }) : api = api ?? FlutterDynamicIconPlusPlatform.instance,
       launchTheme = launchTheme ?? NativeLaunchTheme.instance;

  static final instance = NativeAppIcon();
  final FlutterDynamicIconPlusPlatform api;
  final TargetPlatform? platformOverride;
  final NativeLaunchTheme launchTheme;
  TargetPlatform get platform => platformOverride ?? defaultTargetPlatform;
  bool get mobile =>
      !kIsWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
  bool supported = false, busy = false, loaded = false;
  RaftAppIconPalette selected = RaftAppIconPalette.yellow;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears on the next successful refresh or when a selection starts.
  String? error;
  int _revision = 0;

  String? _name(RaftAppIconPalette choice) {
    final suffix = '${choice.name[0].toUpperCase()}${choice.name.substring(1)}';
    if (platform == TargetPlatform.android) {
      return 'app.raft.raft_flutter.Icon$suffix';
    }
    return choice == RaftAppIconPalette.yellow ? null : 'AppIcon$suffix';
  }

  Future<Object?> _read() async {
    final supported = await api.supportsAlternateIcons;
    if (!supported) return {'supported': false, 'color': 'yellow'};
    final name = await api.alternateIconName;
    final choice = RaftAppIconPalette.values
        .where((choice) => _name(choice) == name)
        .firstOrNull;
    if (choice == null) throw const FormatException('Unknown native icon');
    return {'supported': true, 'color': choice.name};
  }

  void _adopt(Object? value) {
    if (value is! Map || value['supported'] is! bool) {
      throw const FormatException('Invalid icon state');
    }
    final id = value['color'];
    final choice = RaftAppIconPalette.values
        .where((p) => p.name == id)
        .firstOrNull;
    if (choice == null) throw const FormatException('Invalid icon palette');
    selected = choice;
    supported = value['supported'] == true;
    loaded = true;
  }

  Future<void> refresh() async {
    if (!mobile || busy) return;
    final revision = ++_revision;
    try {
      final value = await _read();
      if (revision != _revision) return;
      _adopt(value);
      error = null;
    } catch (_) {
      if (revision != _revision) return;
      loaded = true;
      error = 'The icon setting could not be read. Try again.';
    }
    notifyListeners();
  }

  Future<void> select(RaftAppIconPalette choice) async {
    if (!mobile || !supported || busy || selected == choice) return;
    ++_revision;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await api.setAlternateIconName(iconName: _name(choice), isSilent: false);
      _adopt(await _read());
      if (selected != choice) {
        throw const FormatException('Icon readback mismatch');
      }
      // The native splash shows the enabled icon: persist it for next launch.
      await launchTheme.refresh();
    } catch (_) {
      // A native call may have changed the OS before reporting a later error.
      // Preserve the actual state rather than committing an optimistic choice.
      try {
        _adopt(await _read());
      } catch (_) {}
      error = 'The icon could not be changed. Try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
