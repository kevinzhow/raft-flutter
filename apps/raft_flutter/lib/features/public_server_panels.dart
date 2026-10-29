// The public page's drag-resizable columns (Web PublicServerPage
// `useResizablePanel` + `lib/panelBounds.ts` + `PanelResizeHandle`).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SIDEBAR_PANEL_BOUNDS`: the channel and settings columns.
abstract final class PublicPanelBounds {
  static const sidebarMin = 180.0, sidebarMax = 320.0, sidebarDefault = 240.0;
  static const threadMin = 360.0, threadDefault = 400.0;

  /// `getThreadPanelDynamicMax`: 60% of the viewport, never below the default;
  /// Web recomputes it at drag start, so a window resize stays CSS-only.
  static double threadMax(double viewportWidth) =>
      math.max(400, (viewportWidth * .6).floorToDouble());
}

/// The three persisted widths. Keys and the stored-value rule follow Web: a
/// stored width outside its bounds is ignored, a drag persists on pointer up.
/// Widths apply only where the columns sit side by side (sm and up); the
/// caller decides.
class PublicPanelWidths extends ChangeNotifier {
  PublicPanelWidths({double viewport = 1280})
    : _threadMax = PublicPanelBounds.threadMax(viewport);

  static const channelSidebarKey = 'slock:publicServer:channelSidebarWidth';
  static const settingsSidebarKey = 'slock:publicServer:settingsSidebarWidth';
  static const threadKey = 'slock:publicServer:threadPanelWidth';

  double channelSidebar = PublicPanelBounds.sidebarDefault;
  double settingsSidebar = PublicPanelBounds.sidebarDefault;
  double thread = PublicPanelBounds.threadDefault;
  double _threadMax;
  bool _disposed = false;

  double get threadMax => _threadMax;

  /// Reads the stored widths (once, at mount). Unreadable device preferences
  /// keep the defaults.
  Future<void> load() async {
    final List<double?> values;
    try {
      final prefs = await SharedPreferences.getInstance();
      values = [
        prefs.getDouble(channelSidebarKey),
        prefs.getDouble(settingsSidebarKey),
        prefs.getDouble(threadKey),
      ];
    } catch (_) {
      return;
    }
    if (_disposed) return;
    bool within(double? v, double min, double max) =>
        v != null && v >= min && v <= max;
    const min = PublicPanelBounds.sidebarMin,
        max = PublicPanelBounds.sidebarMax;
    if (within(values[0], min, max)) channelSidebar = values[0]!;
    if (within(values[1], min, max)) settingsSidebar = values[1]!;
    if (within(values[2], PublicPanelBounds.threadMin, _threadMax)) {
      thread = values[2]!;
    }
    notifyListeners();
  }

  /// Drag start of the thread handle: the viewport-derived max is read now.
  void beginThreadResize(double viewportWidth) {
    _threadMax = PublicPanelBounds.threadMax(viewportWidth);
    thread = thread.clamp(PublicPanelBounds.threadMin, _threadMax);
  }

  void setChannelSidebar(double value) => _set(
    value,
    PublicPanelBounds.sidebarMin,
    PublicPanelBounds.sidebarMax,
    channelSidebar,
    (v) => channelSidebar = v,
  );

  void setSettingsSidebar(double value) => _set(
    value,
    PublicPanelBounds.sidebarMin,
    PublicPanelBounds.sidebarMax,
    settingsSidebar,
    (v) => settingsSidebar = v,
  );

  void setThread(double value) => _set(
    value,
    PublicPanelBounds.threadMin,
    _threadMax,
    thread,
    (v) => thread = v,
  );

  void _set(
    double value,
    double min,
    double max,
    double current,
    void Function(double) assign,
  ) {
    final next = value.clamp(min, max);
    if (next == current) return;
    assign(next);
    notifyListeners();
  }

  /// Pointer up (or a keyboard step): the width is kept (best effort, a
  /// preference that cannot be written is not an error to show).
  Future<void> persist(String key) async {
    final value = switch (key) {
      channelSidebarKey => channelSidebar,
      settingsSidebarKey => settingsSidebar,
      _ => thread,
    };
    try {
      await (await SharedPreferences.getInstance()).setDouble(key, value);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
