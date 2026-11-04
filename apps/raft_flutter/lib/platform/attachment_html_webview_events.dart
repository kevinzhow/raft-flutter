import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart' show RaftHtmlRegionController;

/// Events from an isolated HTML renderer. Uploaded documents receive no
/// application JavaScript channel, account session or filesystem capability.
class AttachmentHtmlWebViewEvents {
  const AttachmentHtmlWebViewEvents({
    required this.onNavigation,
    required this.onLoaded,
    required this.onFailed,
    this.onProgress,
    this.onGeometryReady,
  });

  /// Main-frame navigation other than the initial preview. The owner opens
  /// approved links externally and returns false.
  final bool Function(String url) onNavigation;
  final VoidCallback onLoaded;
  final ValueChanged<RaftHtmlRegionController>? onGeometryReady;
  final void Function(String reason) onFailed;
  final void Function(int percent)? onProgress;
}

typedef AttachmentHtmlWebViewBuilder = Widget Function(
  BuildContext context,
  Uri uri,
  AttachmentHtmlWebViewEvents events,
);
