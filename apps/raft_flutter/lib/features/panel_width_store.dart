import '../data/device_preferences.dart';

/// A drag-resizable panel's width kept as a device preference (Web
/// `useResizablePanel`: a stored width inside the bounds is the width, anything
/// else the default). Shared by every workspace and account.
class PanelWidthStore {
  const PanelWidthStore(this.key, this.min, this.max, this.fallback);
  final String key;
  final double min, max, fallback;

  /// The saved width; a value outside the bounds (or none) is the default.
  double get value {
    final stored = DevicePreferences.current?.get(key);
    final width = stored is num ? stored.toDouble() : null;
    return width != null && width >= min && width <= max ? width : fallback;
  }

  /// Remembers the width a drag ended on; a width the panel cannot have is
  /// never stored.
  void save(double width) {
    if (width < min || width > max) return;
    DevicePreferences.current?.setDouble(key, width);
  }
}

/// Web `ProfilePanel` (`slock:profilePanelWidth`): 300 to 600, 380 by default.
const profilePanelWidth = PanelWidthStore(
  'raft.layout.profileWidth',
  300,
  600,
  380,
);

/// Web `AgentWorkspace` (`slock:workspaceTreeWidth`): the file tree column,
/// 160 to 600, 256 by default.
const workspaceTreeWidth = PanelWidthStore(
  'raft.layout.workspaceTreeWidth',
  160,
  600,
  256,
);
