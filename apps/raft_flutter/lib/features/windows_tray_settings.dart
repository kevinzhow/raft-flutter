import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/windows_tray.dart';

/// A device preference read back from the runner, including after a failed save.
class WindowsTraySettings extends StatefulWidget {
  const WindowsTraySettings({super.key, this.tray});
  final WindowsTray? tray;
  @override
  State<WindowsTraySettings> createState() => _WindowsTraySettingsState();
}

class _WindowsTraySettingsState extends State<WindowsTraySettings> {
  late final tray = widget.tray ?? WindowsTray();
  WindowsTrayState? accepted;
  Future<({WindowsTrayState? state, bool failed})> request(
    Future<WindowsTrayState> action,
  ) async {
    try {
      accepted = await action;
      return (state: accepted, failed: false);
    } catch (_) {
      return (state: accepted, failed: true);
    }
  }

  late var result = request(tray.readState());

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<({WindowsTrayState? state, bool failed})>(
        future: result,
        builder: (context, snapshot) {
          final state = snapshot.data?.state ?? accepted;
          final busy = snapshot.connectionState != ConnectionState.done;
          final unavailable =
              snapshot.data?.failed == true || state?.available == false;
          return RaftCard(
            padding: const EdgeInsets.all(RaftSpace.x4),
            child: RaftGapColumn(
              gap: RaftSpace.x3,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        raftText(
                          context,
                          'Keep Raft running when the window closes',
                        ),
                      ),
                    ),
                    const SizedBox(width: RaftSpace.x3),
                    RaftSwitch(
                      key: const ValueKey('windows-close-to-tray'),
                      semanticLabel: raftText(
                        context,
                        'Keep Raft running when the window closes',
                      ),
                      value: state?.closeToTray ?? true,
                      onChanged: busy || unavailable
                          ? null
                          : (enabled) {
                              setState(() {
                                result = request(tray.setCloseToTray(enabled));
                              });
                            },
                    ),
                  ],
                ),
                Text(
                  raftText(
                    context,
                    'Closing the window keeps messages and notifications connected. Open Raft or quit completely from its system tray icon.',
                  ),
                ),
                if (unavailable) ...[
                  const RaftErrorBanner(
                    'The system tray preference is unavailable. Close will exit Raft if its tray icon cannot be created.',
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: RaftButton(
                      label: 'Retry',
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              result = request(tray.readState());
                            }),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
}
