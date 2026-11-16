import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_preferences.dart';

/// Ids of the mobile bottom-bar tabs. They are the `RaftMobileNavItem` ids the
/// bar has always used (`chat` is Home).
abstract final class MobileTabs {
  static const home = 'chat',
      tasks = 'tasks',
      members = 'members',
      computers = 'computers',
      activity = 'activity',
      search = 'search',
      settings = 'settings';

  /// Every tab the user can place in the bar (Web v1.24 MobileTabBar: Home,
  /// Activity, Tasks, Search). The server tab always closes the bar and is
  /// not part of the choice. Members, Computers and Settings are pages the
  /// server tab opens; they only stay tab roots with the left rail.
  static const configurable = [home, activity, tasks, search];

  /// Most tabs the bar holds, the server tab included.
  static const maxTabs = 5;

  /// Most configurable tabs on at once.
  static const maxConfigurable = maxTabs - 1;
}

/// The device-local bottom-bar choice: the order of every configurable tab and
/// which of them are on. The server tab is not part of it.
@immutable
class MobileTabbarSettings {
  const MobileTabbarSettings({required this.order, required this.enabled});

  /// Web's bar: Home, Activity, Tasks, Search (+ the server tab).
  static const defaults = MobileTabbarSettings(
    order: MobileTabs.configurable,
    enabled: {
      MobileTabs.home,
      MobileTabs.activity,
      MobileTabs.tasks,
      MobileTabs.search,
    },
  );

  /// Every configurable id exactly once.
  final List<String> order;
  final Set<String> enabled;

  /// Enabled ids in bar order.
  List<String> get visible => [
    for (final id in order)
      if (enabled.contains(id)) id,
  ];

  bool get isDefault =>
      listEquals(order, defaults.order) && setEquals(enabled, defaults.enabled);

  /// Stored form: `{"order": [...], "enabled": [...]}` (ids in bar order).
  String encode() => jsonEncode({'order': order, 'enabled': visible});

  /// Reads a stored value. Unknown or removed ids (the Members and Computers
  /// tabs of the previous release) are dropped and the rest is kept. A tab
  /// that did not exist when the value was written (Search) is turned on while
  /// there is room, so the upgrade leaves the choice as it was plus Web's new
  /// tab. Anything unreadable (or leaving no tab on) is the default. A bare
  /// JSON list is read as the ordered enabled ids.
  static MobileTabbarSettings parse(String? raw) {
    if (raw == null) return defaults;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return defaults;
    }
    List<String> ids(Object? value) => value is List
        ? [
            for (final id in value)
              if (id is String && MobileTabs.configurable.contains(id)) id,
          ]
        : const [];
    final List<String> order, enabled;
    if (decoded is List) {
      enabled = ids(decoded);
      order = enabled;
    } else if (decoded is Map && decoded['enabled'] is List) {
      enabled = ids(decoded['enabled']);
      order = ids(decoded['order']);
    } else {
      return defaults;
    }
    final on = <String>{};
    for (final id in enabled) {
      if (on.length < MobileTabs.maxConfigurable) on.add(id);
    }
    if (on.isEmpty) return defaults;
    if (decoded is Map) {
      final stored = decoded['order'] is List
          ? (decoded['order'] as List).whereType<String>().toSet()
          : <String>{};
      for (final id in MobileTabs.configurable) {
        if (!stored.contains(id) && on.length < MobileTabs.maxConfigurable) {
          on.add(id);
        }
      }
    }
    final complete = <String>[];
    for (final id in [...order, ...enabled, ...MobileTabs.configurable]) {
      if (!complete.contains(id)) complete.add(id);
    }
    return MobileTabbarSettings(order: complete, enabled: on);
  }

  /// Tabs the bar shows for this account: the enabled ones the account may
  /// open, in order, at most [MobileTabs.maxConfigurable]. Without any, the bar
  /// shows Home next to the server tab.
  List<String> effective({
    required bool guest,
    required bool Function(String capability) can,
  }) {
    final shown = [
      for (final id in visible)
        if (mobileTabPermitted(id, guest: guest, can: can)) id,
    ].take(MobileTabs.maxConfigurable).toList();
    return shown.isEmpty ? const [MobileTabs.home] : shown;
  }

  /// This choice seen through [permitted] (tabs the account may open), with
  /// [view] (reordered, toggled in that subset) folded back in. Tabs the
  /// account cannot open keep their place and their on/off state.
  MobileTabbarSettings merged(
    MobileTabbarSettings view,
    Set<String> permitted,
  ) {
    final replacement = [
      for (final id in view.order)
        if (permitted.contains(id)) id,
    ].iterator;
    return MobileTabbarSettings(
      order: [
        for (final id in order)
          if (permitted.contains(id) && replacement.moveNext())
            replacement.current
          else
            id,
      ],
      enabled: {
        for (final id in enabled)
          if (!permitted.contains(id)) id,
        for (final id in view.enabled)
          if (permitted.contains(id)) id,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MobileTabbarSettings &&
      listEquals(order, other.order) &&
      setEquals(enabled, other.enabled);
  @override
  int get hashCode => Object.hash(Object.hashAll(order), enabled.length);
}

/// Whether the account may open [id] (the same rules the Members rail entry
/// and the Settings > Computers row use).
bool mobileTabPermitted(
  String id, {
  required bool guest,
  required bool Function(String capability) can,
}) => switch (id) {
  MobileTabs.members => !guest && can('viewMembers'),
  MobileTabs.computers => !guest && can('viewMachines'),
  _ => true,
};

/// Device-local owner of [MobileTabbarSettings]. Like the layout choices it
/// reads the preloaded [DevicePreferences] synchronously, so the first frame
/// already shows the configured bar.
class MobileTabbarStore extends ChangeNotifier {
  MobileTabbarStore() : settings = MobileTabbarSettings.parse(_stored());

  static const preferenceKey = 'raft.mobileTabbar';
  static String? _stored() {
    try {
      return DevicePreferences.current?.getString(preferenceKey);
    } catch (_) {
      return null;
    }
  }

  MobileTabbarSettings settings;

  void update(MobileTabbarSettings next) {
    if (next == settings) return;
    settings = next;
    notifyListeners();
    final loaded = DevicePreferences.current;
    final value = next.isDefault ? null : next.encode();
    Future<void> write(SharedPreferences p) async {
      try {
        value == null
            ? await p.remove(preferenceKey)
            : await p.setString(preferenceKey, value);
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

  void reset() => update(MobileTabbarSettings.defaults);
}
