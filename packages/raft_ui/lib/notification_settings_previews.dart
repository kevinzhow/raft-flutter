import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

// Settings › Notifications v2 (Web v1.24.0 components/settings/notifications):
// the settings rows (a switch or a fitted select at the row's end, under the
// text below 32rem), the This device card with its test result banner.

@RaftPreviews('Source notification settings (desktop)', size: Size(390, 460))
Widget sourceDesktopNotificationSettingsPreview() =>
    const _Preview(phone: false);

@RaftPreviews('Source notification settings (phone)', size: Size(390, 600))
Widget sourcePhoneNotificationSettingsPreview() => const _Preview(phone: true);

class _Preview extends StatefulWidget {
  const _Preview({required this.phone});
  final bool phone;
  @override
  State<_Preview> createState() => _State();
}

class _State extends State<_Preview> {
  bool sound = true, quiet = false, sent = false;
  String preview = 'full';

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: widget.phone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RaftSettingsSectionHeader(
                  label: 'All devices',
                  glyph: RaftGlyph.eye,
                ),
                RaftSettingsRowGroup(
                  rows: [
                    RaftSettingsRowSpec(
                      title: 'Notification preview',
                      control: RaftSettingsSelect<String>(
                        value: preview,
                        items: const [
                          RaftSelectItem(
                            value: 'full',
                            label: 'Sender and message',
                          ),
                          RaftSelectItem(
                            value: 'sender_only',
                            label: 'Sender only',
                          ),
                          RaftSelectItem(value: 'hidden', label: 'Hidden'),
                        ],
                        onChanged: (v) => setState(() => preview = v ?? 'full'),
                      ),
                    ),
                    RaftSettingsRowSpec(
                      title: 'Sound',
                      wrapNarrow: false,
                      control: RaftSwitch(
                        value: sound,
                        onChanged: (v) => setState(() => sound = v),
                      ),
                    ),
                    RaftSettingsRowSpec(
                      title: 'Quiet hours',
                      description: 'Every day between these times, nothing alerts on any of your devices; badges still update. Time zone: Europe/Berlin.',
                      wrapNarrow: false,
                      control: RaftSwitch(
                        value: quiet,
                        onChanged: (v) => setState(() => quiet = v),
                      ),
                    ),
                    if (quiet)
                      const RaftSettingsRowSpec(
                        attached: true,
                        description: '22:00 – 08:00',
                      ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RaftSettingsSectionHeader(
                  label: 'This device',
                  glyph: RaftGlyph.bell,
                ),
                RaftSettingsRowGroup(
                  rows: [
                    RaftSettingsRowSpec(
                      title: 'Desktop notifications',
                      titleTrailing: const RaftBadge(
                        label: 'Managed by the system',
                        appearance: RaftBadgeRecipeAppearance.soft,
                      ),
                      body: [
                        const RaftListRowDescription(
                          'Whether these notifications appear is decided by the system: Settings → System → Notifications on Windows, or your desktop’s notification settings on Linux. Do Not Disturb may hold banners back.',
                          wrap: true,
                        ),
                        if (sent)
                          const RaftTestNotificationBanner(
                            result: RaftTestNotificationResult.shown,
                            message: 'Test notification shown on this device.',
                          ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: RaftButton(
                            label: 'Send test notification',
                            tone: RaftButtonRecipeVariant.outline,
                            size: RaftButtonRecipeSize.md,
                            onPressed: () => setState(() => sent = true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
    ),
  );
}
