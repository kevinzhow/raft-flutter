// raft-flutter parity EXTENSION suite builders (tool/parity-ext): Settings ->
// Notifications on a desktop. Ids
// `components.notifications.desktop.<available|unavailable>.<theme>`,
// dispatched on props.extCase like tool/parity-ext/host/NotificationCardCases.tsx.
//
// The real NotificationSettingsView is mounted with the desktop service
// (macOS: Web's own hint names macOS, so the OS path matches). The capture is
// the card block (`capture.androidKey` notification-settings-card).
import 'package:flutter/material.dart';
import 'package:raft_flutter/features/notification_settings_view.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';

class _DesktopService extends NativeNotificationService {
  _DesktopService({required bool ready})
    : super(platform: TargetPlatform.macOS) {
    available = ready;
    initialized = true;
  }
}

Widget _build(ParityContext ctx) {
  final ready = '${ctx.props['available']}' != 'false';
  return ctx.frame(
    width: ctx.width,
    height: ctx.height,
    padding: EdgeInsets.zero,
    child: Material(
      type: MaterialType.transparency,
      // SettingsPanel content surface (`bg-layer-panel`, white in brutal).
      child: Builder(
        builder: (context) {
          final t = RaftTokens.of(context);
          return ColoredBox(
            color: t.panel,
            child: Padding(
              // The panel's left border (brutal 2px, elegant 1px) + `px-5`
              // inside the 640px column.
              padding: EdgeInsets.fromLTRB(21, 0, 20, 0),
              child: NotificationSettingsView(
                service: _DesktopService(ready: ready),
              ),
            ),
          );
        },
      ),
    ),
  );
}

ParityCase _case() => const ParityCase(
  widgets: [
    'raft_flutter:NotificationSettingsView',
    'raft_ui:RaftNotificationSettingsCard',
  ],
  notes: 'Extension suite (not official).',
  settle: Duration(milliseconds: 300),
  build: _build,
);

/// Every extension notifications case, keyed by id (3 themes each).
final Map<String, ParityCase> extNotificationCases = {
  for (final kind in const ['available', 'unavailable'])
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.notifications.desktop.$kind.$theme': _case(),
};
