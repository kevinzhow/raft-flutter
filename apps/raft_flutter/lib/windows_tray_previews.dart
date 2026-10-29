import 'package:flutter/material.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/raft_ui.dart' show RaftSpace;

import 'features/windows_tray_settings.dart';
import 'platform/windows_tray.dart';

@RaftPreviews('Windows close-to-tray preference', size: Size(390, 350))
Widget windowsTraySettingsPreview() => Padding(
  padding: const EdgeInsets.all(RaftSpace.x4),
  child: WindowsTraySettings(tray: _PreviewTray()),
);

class _PreviewTray extends WindowsTray {
  bool enabled = true;
  @override
  Future<WindowsTrayState> readState() async =>
      WindowsTrayState(available: true, closeToTray: enabled);
  @override
  Future<WindowsTrayState> setCloseToTray(bool value) async {
    enabled = value;
    return readState();
  }
}
