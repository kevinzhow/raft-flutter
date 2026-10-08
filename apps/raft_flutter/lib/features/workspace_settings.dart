import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/personal_presentation.dart';
import '../data/workspace_controller.dart';
import '../platform/native_notifications.dart';
import 'account_settings.dart';
import 'admin_views.dart';
import 'appearance_section.dart';
import 'fleet_views.dart';
import 'im_bridges_view.dart';
import 'integrations_views.dart';
import 'locale_settings_page.dart';
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
    this.providerEnabled = false,
    this.bridgeEnabled = false,
  });
  final WorkspaceController controller;
  final RaftAppearance appearance;
  final ValueChanged<RaftAppearance> onAppearance;
  final PersonalPresentationStore presentation;
  final NativeNotificationService? notifications;
  final Future<void> Function()? onLogout;
  final String initialTab;
  final bool mobileRoot;
  final int mobileResetRevision;
  final ValueChanged<bool>? onMobileDetailChanged;

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
      destinations: [
        RaftSettingsDestination(
          'account',
          'Account',
          RaftGlyph.user,
          (_) => AccountSettings(controller: w, onLogout: onLogout),
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
            (_) => NotificationSettingsView(service: notifications!),
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
      color: t.brutal ? Colors.black : t.strong,
    );
    final muted = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      color: t.brutal ? Colors.black.withValues(alpha: .6) : t.muted,
    );
    Widget card(String title, String detail) => RaftSettingsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: strong),
          const SizedBox(height: 4),
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
          const SizedBox(height: 16),
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
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
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
      if (mounted) setState(() => releases = items);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (error != null) {
      return Text(error!, style: RaftTypography.body(t, size: 14, line: 20));
    }
    if (releases == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final release in releases!)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
                  const SizedBox(height: 8),
                  for (final entry
                      in release['entries'] is List
                          ? release['entries'] as List
                          : const [])
                    if (entry is Map)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
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
