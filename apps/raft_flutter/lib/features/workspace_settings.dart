import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/personal_presentation.dart';
import '../data/resource_snapshot_cache.dart' show stableValue;
import '../data/workspace_controller.dart';
import '../platform/native_notifications.dart';
import 'account_settings.dart';
import 'admin_views.dart';
import 'appearance_section.dart';
import 'fleet_views.dart';
import 'im_bridges_view.dart';
import 'integrations_views.dart';
import 'locale_settings_page.dart';
import 'management_support.dart'
    show pageIdentity, readPageSnapshot, writePageSnapshot;
import 'mcp_views.dart';
import 'notification_settings_view.dart';
import 'provider_views.dart';
import 'server_views.dart';
import 'settings_page.dart';
import 'source_feedback_view.dart';

/// The Settings tab: Sidebar.tsx `settingsSidebarGroups` (mobileInline) and
/// the SettingsPanel tab each row opens. Groups and gates follow
/// settingsNavigation.ts `canOpenSettingsTab`.
class WorkspaceSettings extends StatelessWidget {
  const WorkspaceSettings({
    super.key,
    required this.controller,
    required this.appearance,
    required this.onAppearance,
    required this.presentation,
    this.notifications,
    this.onLogout,
    this.initialTab = 'account',
    this.mobileRoot = true,
    this.mobileResetRevision = 0,
    this.onMobileDetailChanged,
    this.onMobileLocationChanged,
    this.providerEnabled = false,
    this.bridgeEnabled = false,
    this.workspaceModeCard,
  });
  final WorkspaceController controller;
  final Widget? workspaceModeCard;
  final RaftAppearance appearance;
  final ValueChanged<RaftAppearance> onAppearance;
  final PersonalPresentationStore presentation;
  final NativeNotificationService? notifications;
  final Future<void> Function()? onLogout;
  final String initialTab;
  final bool mobileRoot;
  final int mobileResetRevision;
  final ValueChanged<bool>? onMobileDetailChanged;
  final ValueChanged<String?>? onMobileLocationChanged;

  /// Server feature flags (provider connections / Slack bridge).
  final bool providerEnabled, bridgeEnabled;

  static const documentationUrl = 'https://docs.raft.build';
  static const personal = 'Personal', workspace = 'Workspace';
  static const resources = 'Resources';

  @override
  Widget build(BuildContext context) {
    final w = controller;
    final role = w.server?.string('role');
    final guest = role == 'guest';
    return RaftSettingsPage(
      initialTab: initialTab,
      mobileRoot: mobileRoot,
      mobileResetRevision: mobileResetRevision,
      onMobileDetailChanged: onMobileDetailChanged,
      onMobileLocationChanged: onMobileLocationChanged,
      destinations: [
        RaftSettingsDestination(
          'account',
          'Account',
          RaftGlyph.user,
          (_) => AccountSettings(
            controller: w,
            onLogout: onLogout,
            workspaceModeCard: workspaceModeCard,
          ),
        ),
        RaftSettingsDestination(
          'language-region',
          'Language & Region',
          RaftGlyph.languages,
          (_) => LocaleSettingsPage(controller: w),
        ),
        RaftSettingsDestination(
          'appearance',
          'Appearance',
          RaftGlyph.type,
          (_) => RaftAppearanceSection(
            appearance: appearance,
            onAppearance: onAppearance,
            presentation: presentation,
          ),
        ),
        if (notifications != null)
          RaftSettingsDestination(
            'notifications',
            'Notifications',
            RaftGlyph.bell,
            (_) => NotificationSettingsView(
              service: notifications!,
              controller: w,
            ),
          ),
        if (w.server != null) ...[
          RaftSettingsDestination(
            'server',
            'Server Profile',
            RaftGlyph.building2,
            (_) => ServerSettingsView(controller: w),
            group: workspace,
            scroll: false,
          ),
          if (w.can('viewBilling'))
            RaftSettingsDestination(
              'billing',
              'Plan & Billing',
              RaftGlyph.creditCard,
              (_) => BillingView(controller: w),
              group: workspace,
              scroll: false,
            ),
          if (w.can('viewServerSettings'))
            RaftSettingsDestination(
              'administration',
              'Administration',
              RaftGlyph.shield,
              (_) => AdministrationView(controller: w),
              group: workspace,
              scroll: false,
            ),
          if (bridgeEnabled && w.can('manageIntegrations'))
            RaftSettingsDestination(
              'im-bridges',
              'IM Bridges',
              RaftGlyph.network,
              (_) => IMBridgesView(controller: w),
              group: workspace,
              scroll: false,
            ),
          if (!guest)
            RaftSettingsDestination(
              'integrations',
              'Applications',
              RaftGlyph.link2,
              (_) => IntegrationsView(controller: w),
              group: workspace,
              scroll: false,
            ),
          if (!guest)
            RaftSettingsDestination(
              'mcp',
              'MCP Servers',
              RaftGlyph.blocks,
              (_) => AgentMcpView(controller: w),
              group: workspace,
              scroll: false,
            ),
          if (providerEnabled && w.can('manageExternalAuth'))
            RaftSettingsDestination(
              'providers',
              'Providers',
              RaftGlyph.keyRound,
              (_) => ProviderConnectionsView(controller: w),
              group: workspace,
              scroll: false,
            ),
          if (!guest)
            RaftSettingsDestination(
              'computers',
              'Computers',
              RaftGlyph.monitor,
              (_) => FleetView(controller: w, computers: true),
              group: workspace,
              scroll: false,
            ),
        ],
        RaftSettingsDestination(
          'about',
          'About',
          RaftGlyph.badgeInfo,
          (_) => WorkspaceAboutSection(controller: w),
          group: resources,
        ),
        RaftSettingsDestination.action(
          'documentation',
          'Documentation',
          RaftGlyph.bookOpenText,
          group: resources,
          onOpen: () => launchUrl(
            Uri.parse(documentationUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        if (w.server != null)
          RaftSettingsDestination(
            'feedback',
            'Feedback',
            RaftGlyph.messageSquare,
            (_) => SourceFeedbackView(controller: w),
            group: resources,
            scroll: false,
          ),
        RaftSettingsDestination(
          'release-notes',
          'Release Notes',
          RaftGlyph.fileText,
          (_) => ReleaseNotesView(controller: w),
          group: resources,
        ),
      ],
    );
  }
}

/// SettingsPanel.tsx AboutSection: version and current workspace cards.
class WorkspaceAboutSection extends StatelessWidget {
  const WorkspaceAboutSection({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final server = controller.server;
    final strong = RaftTypography.body(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w700,
      color: RaftSettingsText(t).strong,
    );
    final muted = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      color: RaftSettingsText(t).muted,
    );
    Widget card(String title, String detail) => RaftSettingsCard(
      padding: RaftSettingsCard.listItemInset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: strong),
          const SizedBox(height: RaftSpace.x1),
          Text(detail, style: muted),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RaftSettingsSectionHeader(
          label: 'Version',
          glyph: RaftGlyph.tag,
          bottom: 8,
        ),
        card('Raft', raftText(context, 'Flutter client')),
        if (server != null) ...[
          const SizedBox(height: RaftSpace.x4),
          const RaftSettingsSectionHeader(
            label: 'Current workspace',
            glyph: RaftGlyph.building2,
            bottom: 8,
          ),
          card(server.string('name'), '/${server.string('slug')}'),
        ],
      ],
    );
  }
}

/// ReleaseNotesPanel.tsx: published releases from GET /release-notes.
class ReleaseNotesView extends StatefulWidget {
  const ReleaseNotesView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<ReleaseNotesView> createState() => _ReleaseNotesViewState();
}

class _ReleaseNotesViewState extends State<ReleaseNotesView> {
  List<Map<String, dynamic>>? releases;
  String? error;
  static const snapshotKey = 'release-notes';
  @override
  void initState() {
    super.initState();
    // Revisit: the accepted list renders at once and revalidates quietly.
    releases =
        readPageSnapshot(widget.controller, snapshotKey)?['releases']
            as List<Map<String, dynamic>>?;
    load();
  }

  Future<void> load() async {
    final identity = pageIdentity(widget.controller);
    try {
      final page = await widget.controller.client.get(
        '/release-notes',
        query: {'limit': 100},
      );
      final items = page is Map && page['items'] is List
          ? [
              for (final item in page['items'] as List)
                if (item is Map) Map<String, dynamic>.from(item),
            ]
          : <Map<String, dynamic>>[];
      if (identity != pageIdentity(widget.controller)) return;
      // Unchanged releases keep their accepted objects.
      final next = stableValue(releases, items) as List<Map<String, dynamic>>;
      writePageSnapshot(widget.controller, snapshotKey, identity, {
        'releases': next,
      });
      if (mounted) {
        setState(() {
          releases = next;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final failure = error == null
        ? null
        : Text(error!, style: RaftTypography.body(t, size: 14, line: 20));
    if (releases == null) {
      return failure ?? const Center(child: RaftSpinner());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A failed revalidation keeps the accepted list.
        ?failure,
        for (final release in releases!)
          Padding(
            padding: const EdgeInsets.only(bottom: RaftSpace.x3),
            child: RaftSettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${release['version'] ?? release['tag'] ?? ''}',
                    style: RaftTypography.body(
                      t,
                      size: 14,
                      line: 20,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${release['date'] ?? ''}',
                    style: RaftTypography.mono(t),
                  ),
                  const SizedBox(height: RaftSpace.x2),
                  for (final entry
                      in release['entries'] is List
                          ? release['entries'] as List
                          : const [])
                    if (entry is Map)
                      Padding(
                        padding: const EdgeInsets.only(top: RaftSpace.x1),
                        child: Text(
                          '${entry['text'] ?? ''}',
                          style: RaftTypography.body(t, size: 14, line: 20),
                        ),
                      ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
