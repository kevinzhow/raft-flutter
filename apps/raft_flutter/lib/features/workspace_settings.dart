import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/personal_presentation.dart';
import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
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

/// The Settings tab: Sidebar.tsx `settingsSidebarGroups` (desktop Settings
/// rail, and the mobileInline Settings root) and the SettingsPanel tab each
/// row opens. Groups and gates follow settingsNavigation.ts
/// `canOpenSettingsTab` / WorkspaceSettingsModal hidden tabs.
class WorkspaceSettings extends StatefulWidget {
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
    this.labsEnabled = false,
    this.appVersion,
    this.frontendOrigin,
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

  /// Server feature flags (provider connections / Slack bridge / Labs UI).
  final bool providerEnabled, bridgeEnabled, labsEnabled;

  /// The running app version shown by About (Web: WEB_APP_VERSION); defaults
  /// to the `RAFT_APP_VERSION` define.
  final String? appVersion;

  /// Web origin for the mobile download QR (defaults to the content-link
  /// origin of the signed-in coordinator).
  final Uri? frontendOrigin;

  static const documentationUrl = 'https://docs.raft.build';
  static const personal = 'Personal', workspace = 'Workspace';
  static const resources = 'Resources';

  @override
  State<WorkspaceSettings> createState() => _WorkspaceSettingsState();
}

class _WorkspaceSettingsState extends State<WorkspaceSettings> {
  /// FeedbackUnreadDot: the account's `unread_total` from
  /// GET /product-feedback/tickets?limit=1, refreshed by the inbox.
  int feedbackUnread = 0;

  @override
  void initState() {
    super.initState();
    loadFeedbackUnread();
  }

  Future<void> loadFeedbackUnread() async {
    final w = widget.controller;
    if (w.server == null || w.client.user == null) return;
    final identity = pageIdentity(w);
    try {
      final page = await w.client.get(
        '/product-feedback/tickets',
        query: {'limit': 1},
      );
      final unread = page is Map ? page['unread_total'] : null;
      if (!mounted || identity != pageIdentity(w) || unread is! int) return;
      setState(() => feedbackUnread = unread < 0 ? 0 : unread);
    } catch (_) {
      // The dot is an accelerator; a failed read shows none.
    }
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final w = widget.controller;
    final role = w.server?.string('role');
    final guest = role == 'guest';
    return RaftSettingsPage(
      initialTab: widget.initialTab,
      mobileRoot: widget.mobileRoot,
      mobileResetRevision: widget.mobileResetRevision,
      onMobileDetailChanged: widget.onMobileDetailChanged,
      onMobileLocationChanged: widget.onMobileLocationChanged,
      destinations: [
        RaftSettingsDestination(
          'account',
          'Account',
          RaftGlyph.user,
          (_) => AccountSettings(
            controller: w,
            onLogout: widget.onLogout,
            workspaceModeCard: widget.workspaceModeCard,
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
            appearance: widget.appearance,
            onAppearance: widget.onAppearance,
            presentation: widget.presentation,
          ),
        ),
        if (widget.notifications != null)
          RaftSettingsDestination(
            'notifications',
            'Notifications',
            RaftGlyph.bell,
            (_) => NotificationSettingsView(
              service: widget.notifications!,
              controller: w,
            ),
          ),
        if (w.server != null) ...[
          RaftSettingsDestination(
            'server',
            'Server Profile',
            RaftGlyph.building2,
            (_) => ServerSettingsView(controller: w),
            group: WorkspaceSettings.workspace,
            scroll: false,
          ),
          if (w.can('viewBilling'))
            RaftSettingsDestination(
              'billing',
              'Plan & Billing',
              RaftGlyph.creditCard,
              (_) => BillingView(controller: w),
              group: WorkspaceSettings.workspace,
              scroll: false,
            ),
          if (w.can('changeMemberRoles') ||
              w.can('changeChannelVisibility') ||
              w.can('inviteMembers') ||
              w.can('editServerSettings'))
            RaftSettingsDestination(
              'administration',
              'Administration',
              RaftGlyph.shield,
              (_) => AdministrationView(controller: w),
              group: WorkspaceSettings.workspace,
              scroll: false,
            ),
          if (widget.bridgeEnabled)
            RaftSettingsDestination(
              'im-bridges',
              'IM Bridges',
              RaftGlyph.network,
              (_) => IMBridgesView(controller: w),
              group: WorkspaceSettings.workspace,
              scroll: false,
            ),
          if (!guest)
            RaftSettingsDestination(
              'integrations',
              'Applications',
              RaftGlyph.link2,
              (_) => IntegrationsView(controller: w),
              group: WorkspaceSettings.workspace,
              scroll: false,
            ),
          if (!guest)
            RaftSettingsDestination(
              'mcp',
              'MCP Servers',
              RaftGlyph.blocks,
              (_) => AgentMcpView(controller: w),
              group: WorkspaceSettings.workspace,
              scroll: false,
            ),
          if (widget.providerEnabled && w.can('manageExternalAuth'))
            RaftSettingsDestination(
              'providers',
              'AI Providers',
              RaftGlyph.keyRound,
              (_) => ProviderConnectionsView(controller: w),
              group: WorkspaceSettings.workspace,
              scroll: false,
            ),
          // Desktop has a dedicated Computers rail mode; the Settings
          // sub-nav lists it on mobile only (Sidebar.tsx mobileInline).
          if (!guest)
            RaftSettingsDestination(
              'computers',
              'Computers',
              RaftGlyph.monitor,
              (_) => FleetView(controller: w, computers: true),
              group: WorkspaceSettings.workspace,
              scroll: false,
              mobileOnly: true,
            ),
        ],
        RaftSettingsDestination(
          'about',
          'About',
          RaftGlyph.badgeInfo,
          (_) => WorkspaceAboutSection(
            controller: w,
            appVersion: widget.appVersion,
            frontendOrigin: widget.frontendOrigin,
          ),
          group: WorkspaceSettings.resources,
        ),
        RaftSettingsDestination.action(
          'documentation',
          'Documentation',
          RaftGlyph.bookOpenText,
          group: WorkspaceSettings.resources,
          onOpen: () => launchUrl(
            Uri.parse(WorkspaceSettings.documentationUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        if (w.server != null)
          RaftSettingsDestination(
            'feedback',
            'Feedback',
            RaftGlyph.messageSquare,
            (_) => SourceFeedbackView(
              controller: w,
              onUnreadChanged: (count) {
                if (mounted && count != feedbackUnread) {
                  setState(() => feedbackUnread = count);
                }
              },
            ),
            group: WorkspaceSettings.resources,
            scroll: false,
            attention: feedbackUnread > 0,
            ownHeader: true,
            contentColor: RaftSettingsPanelFrame.feedbackSurface,
          ),
        RaftSettingsDestination(
          'release-notes',
          'Release Notes',
          RaftGlyph.fileText,
          (_) => ReleaseNotesView(controller: w),
          group: WorkspaceSettings.resources,
          // /release-notes renders outside SettingsPanel's attached Panel.
          attached: false,
        ),
      ],
    );
  }
}

/// SettingsPanel.tsx AboutSection: Version, Mobile app (desktop: download
/// buttons + the /download QR), and the current Workspace.
class WorkspaceAboutSection extends StatelessWidget {
  const WorkspaceAboutSection({
    super.key,
    required this.controller,
    this.appVersion,
    this.frontendOrigin,
    this.showMobileApp,
  });
  final WorkspaceController controller;
  final String? appVersion;
  final Uri? frontendOrigin;

  /// Defaults to desktop platforms: on a phone the reader already runs the
  /// mobile app.
  final bool? showMobileApp;

  static const _version = String.fromEnvironment(
    'RAFT_APP_VERSION',
    defaultValue: 'development',
  );

  @override
  Widget build(BuildContext context) {
    final server = controller.server;
    final api = controller.client.origin;
    Future<void> open(String platform) => launchUrl(
      Uri.parse('$api/api/mobile-download?platform=$platform'),
      mode: LaunchMode.externalApplication,
    );
    final desktop = switch (Theme.of(context).platform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
    final web = frontendOrigin ?? ContentLinks.originFor(api);
    final slug = server?.string('slug') ?? '';
    return RaftSettingsAbout(
      version: appVersion ?? _version,
      mobileApp: showMobileApp ?? desktop
          ? RaftAboutMobileApp(
              onAndroid: () => open('android'),
              onIos: () => open('ios'),
              qrUrl: '${web.origin}/download',
            )
          : null,
      workspaceName: server == null
          ? null
          : server.string('name').isEmpty
          ? raftText(context, 'Current workspace')
          : server.string('name'),
      workspaceDetail: slug.isEmpty
          ? raftText(
              context,
              'Workspace details and administration are available from Settings.',
            )
          : '/$slug',
    );
  }
}

/// ReleaseNotesPanel.tsx: every published page of GET /release-notes
/// (cursor-paged, limit 100), validated like `parseReleaseNotesPage`; the
/// first published release is Current.
class ReleaseNotesView extends StatefulWidget {
  const ReleaseNotesView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<ReleaseNotesView> createState() => _ReleaseNotesViewState();
}

class _ReleaseNotesViewState extends State<ReleaseNotesView> {
  List<RaftReleaseNote>? releases;
  bool failed = false;
  int attempt = 0;
  static const snapshotKey = 'release-notes';

  @override
  void initState() {
    super.initState();
    // Revisit: the accepted list renders at once and revalidates quietly.
    releases =
        readPageSnapshot(widget.controller, snapshotKey)?['releases']
            as List<RaftReleaseNote>?;
    load();
  }

  static const _kinds = {
    'feature': RaftReleaseNoteKind.feature,
    'improvement': RaftReleaseNoteKind.improvement,
    'fix': RaftReleaseNoteKind.fix,
    'breaking': RaftReleaseNoteKind.breaking,
    'deprecated': RaftReleaseNoteKind.deprecated,
  };

  /// parseRelease: a malformed page fails the whole load (Web shows the
  /// unavailable banner rather than a partial list).
  static ({String id, RaftReleaseNote note, bool published}) _parse(
    Object? raw,
  ) {
    if (raw is! Map) throw const FormatException('release');
    final id = raw['releaseId'], date = raw['date'], state = raw['state'];
    final version = raw['version'], entries = raw['entries'];
    if (id is! String ||
        id.isEmpty ||
        date is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        (state != 'published' && state != 'retracted') ||
        (version != null && version is! String) ||
        entries is! List) {
      throw const FormatException('release');
    }
    final parsed = [
      for (final e in entries)
        if (e is Map &&
            _kinds[e['type']] != null &&
            e['text'] is String &&
            e['emphasis'] is bool)
          RaftReleaseNoteEntry(
            _kinds[e['type']]!,
            e['text'] as String,
            emphasis: e['emphasis'] as bool,
          )
        else
          throw const FormatException('release entry'),
    ];
    return (
      id: id,
      published: state == 'published',
      note: RaftReleaseNote(
        id: id,
        date: date,
        version: version as String?,
        retracted: state == 'retracted',
        entries: parsed,
      ),
    );
  }

  Future<void> load() async {
    final w = widget.controller;
    final identity = pageIdentity(w);
    final ticket = ++attempt;
    try {
      final rows = <({String id, RaftReleaseNote note, bool published})>[];
      final seen = <String>{};
      String? cursor;
      for (var page = 0; ; page++) {
        if (page >= 100) throw const FormatException('pagination bound');
        final raw = await w.client.get(
          '/release-notes',
          query: {'limit': 100, 'cursor': ?cursor},
        );
        if (raw is! Map || raw['items'] is! List) {
          throw const FormatException('release notes page');
        }
        rows.addAll((raw['items'] as List).map(_parse));
        final next = raw['nextCursor'];
        if (next == null) break;
        if (next is! String || !seen.add(next)) {
          throw const FormatException('release notes cursor');
        }
        cursor = next;
      }
      final current = rows.where((r) => r.published).firstOrNull?.id;
      final next = [
        for (final r in rows)
          r.id == current
              ? RaftReleaseNote(
                  id: r.note.id,
                  date: r.note.date,
                  version: r.note.version,
                  current: true,
                  retracted: r.note.retracted,
                  entries: r.note.entries,
                )
              : r.note,
      ];
      if (identity != pageIdentity(w) || ticket != attempt) return;
      writePageSnapshot(w, snapshotKey, identity, {'releases': next});
      if (mounted) {
        setState(() {
          releases = next;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted && ticket == attempt) {
        setState(() {
          failed = true;
          releases = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RaftReleaseNotesView(
    status: failed
        ? RaftReleaseNotesStatus.error
        : releases == null
        ? RaftReleaseNotesStatus.loading
        : RaftReleaseNotesStatus.ready,
    releases: releases ?? const [],
    onRetry: () {
      setState(() => failed = false);
      load();
    },
  );
}
