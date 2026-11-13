// Settings > Account "Share usage data" card: Web UsageDataSettingsCard
// (packages/web/src/components/settings/UsageDataSettings.tsx), shown to
// everyone (Web 1.24 UsageDataSettings.tsx:57-67; the
// `product_analytics_settings_v0` flag is retired); saves on toggle
// (`PATCH /auth/me {shareUsageData}`), a failure shows the warning banner.
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';

class UsageDataSettingsCard extends StatefulWidget {
  const UsageDataSettingsCard({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<UsageDataSettingsCard> createState() => _UsageDataSettingsCardState();
}

class _UsageDataSettingsCardState extends State<UsageDataSettingsCard> {
  static final privacyUrl = Uri.parse('https://raft.build/privacy');
  WorkspaceController get w => widget.controller;
  bool saving = false, failed = false;

  /// `SHARE_USAGE_DATA_DEFAULT` (@botiverse/raft-shared) is off.
  bool get shared => w.client.user?.json['shareUsageData'] == true;

  Future<void> change(bool checked) async {
    final identity = pageIdentity(w);
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      final data = await w.command(
        'PATCH',
        '/auth/me',
        data: {'shareUsageData': checked},
      );
      if (!mounted || identity != pageIdentity(w)) return;
      if (data is Map) {
        w.client.user = RaftRecord({
          ...?w.client.user?.json,
          ...Map<String, dynamic>.from(data),
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RaftAdminSwitchCard(
      cardKey: const ValueKey('usage-data-card'),
      topGap: 24, // mt-6
      switchKey: const ValueKey('usage-data-switch'),
      title: 'Share usage data',
      description: 'Help improve Raft by sharing which pages and features you use. Never includes your messages or other content.',
      descriptionLink: 'Learn More',
      onDescriptionLink: () =>
          launchUrl(privacyUrl, mode: LaunchMode.externalApplication),
      checked: shared,
      onChanged: saving ? null : change,
      error: failed ? "Couldn't save this setting. Try again." : null,
    );
  }
}
