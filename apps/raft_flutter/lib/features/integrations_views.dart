import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/device_preferences.dart';
import '../data/user_error.dart';
import '../data/web_error.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'agent_jwt_settings.dart';
import 'app_notifications_catalog.dart';
import 'app_permission_review.dart';
import 'connected_app_editor.dart';

const integrationScopeLabels = <String, String>{
  'openid': 'OpenID identity',
  'profile': 'Basic profile',
  'email': 'Email address',
  'identity': 'Raft identity card',
  'agent:read': 'Read workspace agent directory',
  'agent:event:write': 'Send structured events to an agent',
  'agent:notification:write': 'Send notifications to an agent',
  'agent:action_request:write': 'Request agent action',
};
const integrationCategories = [
  'AI & Automation',
  'Communication',
  'Productivity & Collaboration',
  'Developer Tools',
  'Data & Analytics',
  'Business Ops',
  'Infrastructure',
  'Content & Creative',
  'Other',
];

/// OAUTH_CLIENT_CATEGORIES display labels (CONNECTED_APP_CATEGORY_LABEL_ID);
/// a value outside the catalog renders as Other.
String integrationCategoryLabel(String? category) =>
    integrationCategories.contains(category) ? category! : 'Other';

/// lib/oauthScopePresentation.ts: the visible OAuth scopes (in catalog
/// order), their consent copy and whether the user picks a target agent.
const integrationVisibleScopes = [
  'openid',
  'profile',
  'email',
  'agent:read',
  'identity',
  'agent:event:write',
  'agent:notification:write',
];
const integrationScopeCopy = <String, String>{
  'openid':
      'Signs you in with Raft and issues a stable identity token. Authentication only.',
  'profile':
      'Reads your basic profile fields (display name and similar). No access to messages, files, or agents.',
  'email':
      'Reads your verified Raft account email address. No access to messages, files, or agents.',
  'identity':
      "Reads who you are — human or agent, your Raft subject, and which server/principal you're acting as. No content access.",
  'agent:read':
      'Read the IDs, handles, display names and avatars of agents in the Server you authorize. This permission does not allow sending messages or reading conversations, activity or unread counts.',
  'agent:event:write':
      'Sends structured event messages to the one agent you authorize.',
  'agent:notification:write':
      'Sends notification messages to the one agent you authorize.',
};
const integrationResourceScopes = {
  'agent:event:write',
  'agent:notification:write',
};

/// `normalizeDeclaredOAuthScopes`: visible scopes in their declared order
/// (deduplicated), defaulting to openid / profile / identity.
List<String> declaredIntegrationScopes(Object? scopes) {
  final seen = <String>{};
  final visible = [
    for (final s in managementStrings(scopes))
      if (integrationVisibleScopes.contains(s) && seen.add(s)) s,
  ];
  return visible.isEmpty ? const ['openid', 'profile', 'identity'] : visible;
}

/// `initialsForApp`.
String integrationInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.length >= 2
      ? '${parts.first[0]}${parts.elementAt(1)[0]}'
      : (parts.firstOrNull ?? 'A').substring(
          0,
          (parts.firstOrNull ?? 'A').length.clamp(0, 2),
        );
  final upper = letters.toUpperCase();
  return upper.isEmpty ? 'A' : upper;
}

/// `getDomainFromUrl`.
String? integrationDomain(Object? raw) {
  final value = raw is String ? raw.trim() : '';
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty ? uri.host : value;
}

bool _canEditSourceOwned(String? status) => const {
  'private',
  'publish_requested',
  'in_review',
  'published',
  'rejected',
}.contains(status);

/// `sourceOwnedConnectedAppStatusHint`.
String? _statusHint(String? status) => switch (status) {
  'publish_requested' || 'in_review' =>
    'Marketplace review is pending. You can edit this app while it waits, or delete it to withdraw the request.',
  'unpublish_requested' =>
    'Marketplace offline review is pending. The app stays listed and installable until App Admin approves removal; approval revokes existing server installs and access.',
  _ => null,
};

/// ConnectedAppDistributionBadge.
RaftConnectedAppBadge? _distributionBadge(
  BuildContext context,
  String? status,
) {
  if (status == null) return null;
  String tr(String s) => raftText(context, s);
  return switch (status) {
    'published' => RaftConnectedAppBadge.success(tr('Published')),
    'publish_requested' ||
    'in_review' => RaftConnectedAppBadge.warning(tr('Review pending')),
    'unpublish_requested' => RaftConnectedAppBadge.warning(
      tr('Offline requested'),
    ),
    'rejected' => RaftConnectedAppBadge.warning(tr('Rejected')),
    _ => RaftConnectedAppBadge.outline(tr('Private')),
  };
}

/// ConnectedAppMarketplaceInstallBadge.
RaftConnectedAppBadge? _installBadge(BuildContext context, Object? raw) {
  final badge = managementMap(raw);
  return switch (badge['kind']) {
    'new' => RaftConnectedAppBadge.warning(raftText(context, 'New')),
    'bucket' => RaftConnectedAppBadge.outline(
      raftFormat(context, '{count} installs', {
        'count': const {
          '10_plus': '10+',
          '100_plus': '100+',
          '1k_plus': '1k+',
        }[badge['bucket']],
      }),
      uppercase: false,
    ),
    _ => null,
  };
}

const _layoutPreference = 'raft:connected-apps:view-mode';

/// Settings > Applications (SettingsPanel.tsx IntegrationsSection): the
/// marketplace, the apps installed on this server and the apps it registered
/// (GET /integrations/clients, /integrations/marketplace,
/// /integrations/overview), with the listing and installed-app details,
/// install / uninstall, and Register / Edit for managers. A revisit renders
/// the last accepted rows at once and revalidates in the background.
class IntegrationsView extends StatefulWidget {
  const IntegrationsView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<IntegrationsView> createState() => _IntegrationsState();
}

class _IntegrationsState extends ManagementState<IntegrationsView> {
  @override
  WorkspaceController get w => widget.controller;

  /// Registered clients, marketplace listings and the access overview.
  List<Map<String, dynamic>> apps = [], marketplace = [], access = [];
  RaftConnectedAppsTab tab = RaftConnectedAppsTab.marketplace;
  final search = TextEditingController();
  String category = 'all';
  RaftConnectedAppsLayout layout =
      DevicePreferences.current?.getString(_layoutPreference) == 'list'
      ? RaftConnectedAppsLayout.list
      : RaftConnectedAppsLayout.grid;

  /// Web `savingClientId`.
  String? savingId;
  bool get canManage => w.can('manageIntegrations');

  @override
  void initState() {
    super.initState();
    createdSecret.addListener(refreshPage);
    startManagement();
  }

  void refreshPage() {
    if (mounted) setState(() {});
  }

  Timer? secretReset;

  @override
  void dispose() {
    secretReset?.cancel();
    search.dispose();
    createdSecret.dispose();
    super.dispose();
  }

  @override
  void clearData() {
    apps = [];
    marketplace = [];
    access = [];
    savingId = null;
    createdSecret.value = null;
  }

  @override
  String get snapshotKey => 'integrations';
  @override
  Map<String, Object?> captureSnapshot() => {
    'apps': apps,
    'marketplace': marketplace,
    'access': access,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    apps = fields['apps'] as List<Map<String, dynamic>>;
    marketplace = fields['marketplace'] as List<Map<String, dynamic>>;
    access = fields['access'] as List<Map<String, dynamic>>;
    return true;
  }

  @override
  Future<void> loadData(int request, int generation) => withWebError(
    'Failed to load connected apps',
    () => _loadData(request, generation),
    where: 'connected apps',
  );

  Future<void> _loadData(int request, int generation) async {
    final data = await Future.wait(
      [
        '/integrations/clients',
        '/integrations/marketplace',
        '/integrations/overview',
      ].map(w.client.get),
    );
    if (!accepts(generation, request)) return;
    apps = managementRows(data[0]);
    marketplace = managementRows(data[1]);
    access = managementRows(data[2]);
  }

  void setLayout(RaftConnectedAppsLayout next) {
    setState(() => layout = next);
    // The preference is optional; the switch works without storage.
    DevicePreferences.current?.setString(
      _layoutPreference,
      next == RaftConnectedAppsLayout.list ? 'list' : 'grid',
    );
  }

  /// The one-time client secret under the filters while the editor is closed
  /// (Web `createdSecret`).
  final ValueNotifier<ConnectedAppSecret?> createdSecret = ValueNotifier(null);

  /// Register app / Edit: the app editor modal (profile, login, permissions,
  /// webhook, distribution, danger zone). A new app opens My apps.
  bool editorOpen = false;

  Future<void> openEditor([Map<String, dynamic>? app]) async {
    if (createdSecret.value?.clientId != '${app?['id']}') {
      createdSecret.value = null;
    }
    setState(() => editorOpen = true);
    try {
      await _showEditor(app);
    } finally {
      if (mounted) setState(() => editorOpen = false);
    }
  }

  Future<void> _showEditor(Map<String, dynamic>? app) async {
    await scopedRaftModal<void>(
      (modal) => RaftModalBackdrop(
        child: ConnectedAppEditor(
          controller: w,
          app: app,
          secret: createdSecret,
          onDenied: invalidateDeniedMutation,
          onClose: () => Navigator.of(modal).pop(),
          onSaved: ({created}) async {
            if (created != null && mounted) {
              setState(() => tab = RaftConnectedAppsTab.myApps);
            }
            await reload();
          },
        ),
      ),
    );
  }

  /// Runs [body]; on failure returns the English text to show (the server's
  /// `error`, else [fallback]), or null when the change was dropped (stale or
  /// authority revoked).
  Future<String?> _mutate(
    String id,
    Future<void> Function() body, {
    required String fallback,
  }) async {
    final generation = w.client.generation, source = authority;
    // Web: every connected-app action starts with `setError("")`.
    setState(() {
      savingId = id;
      error = null;
    });
    try {
      await body();
      if (accepts(generation) && source == authority) await reload();
      return null;
    } catch (e) {
      if (!accepts(generation) || source != authority) return null;
      if (invalidateDeniedMutation(e)) return null;
      return userErrorText(e, fallback: fallback, where: 'connected apps');
    } finally {
      if (mounted && accepts(generation) && source == authority) {
        setState(() => savingId = null);
      }
    }
  }

  Future<bool> confirmUninstall(Map<String, dynamic> app) async {
    final ok = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('connected-app-uninstall-dialog'),
        confirmKey: const ValueKey('connected-app-uninstall-confirm-button'),
        title: raftFormat(context, 'Uninstall {name}?', {'name': app['name']}),
        content: RaftInlineCodeMessage(
          prefix: raftText(
            context,
            'This removes the marketplace app from this server and revokes its existing Login with Raft access for agents on this server. Active grants and tokens will be revoked, and pending agent login requests will be denied. Agents must get a fresh approval before using ',
          ),
          code: '${app['clientId'] ?? ''}',
          suffix:
              '${raftText(context, ' again.')}${app['official'] == true ? ' ${raftText(context, 'This also opts this server out of automatic installation. It stays uninstalled until an owner or admin explicitly installs it again.')}' : ''}',
        ),
        confirmLabel: raftText(context, 'Uninstall app'),
      ),
    );
    if (ok != true || !mounted) return false;
    final failure = await _mutate(
      '${app['id']}',
      () => w.client.delete('/integrations/marketplace/${app['id']}/install'),
      fallback: 'Failed to uninstall marketplace app',
    );
    if (failure != null || error != null) {
      if (mounted) {
        setState(
          () => error = failure ?? 'Failed to uninstall marketplace app',
        );
      }
      return false;
    }
    return true;
  }

  /// Approves the pending permission update the reviewer is looking at
  /// (Web handleApproveSelectedAppPermissionUpdate). Returns the English error
  /// text to show, or null on success / when the change was dropped.
  Future<String?> approvePermissionUpdate(Map<String, dynamic> listing) {
    final id = '${listing['id']}';
    return _mutate(
      id,
      () => w.client.post(
        appPermissionReviewPath(id),
        data: appPermissionReviewBody(listing),
      ),
      fallback: 'Failed to approve permission update',
    );
  }

  Future<void> openListing(Map<String, dynamic> opened) async {
    final source = authority;
    // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the install retry starts; the local variable dies with the app detail modal.
    String? modalError;
    await showRaftModal<void>(
      context,
      builder: (modal) => StatefulBuilder(
        builder: (modal, setModal) {
          String tr(String s) => raftText(modal, s);
          void close() => Navigator.of(modal).pop();
          if (source != authority) {
            WidgetsBinding.instance.addPostFrameCallback((_) => close());
          }
          final id = '${opened['id']}';
          // The listing reloads after a mutation; follow it by id.
          final listing = marketplace.firstWhere(
            (m) => '${m['id']}' == id,
            orElse: () => opened,
          );
          final installed = listing['installedAt'] != null;
          final saving = savingId == id;
          final developer =
              '${listing['publisherServerName'] ?? listing['publisherName'] ?? tr('Third-party developer')}';
          final homepage = listing['homepageUrl'] as String?;
          Future<void> approveUpdate() async {
            setModal(() => modalError = null);
            final run = approvePermissionUpdate(listing);
            setModal(() {});
            final failure = await run;
            if (!modal.mounted) return;
            setModal(() => modalError = failure ?? error);
          }

          Future<void> install() async {
            setModal(() => modalError = null);
            final failure = await _mutate(
              id,
              () => w.client.post('/integrations/marketplace/$id/install'),
              fallback: 'Failed to install marketplace app',
            );
            if (!modal.mounted) return;
            if (failure == null && error == null) {
              close();
            } else {
              setModal(
                () => modalError =
                    failure ?? 'Failed to install marketplace app',
              );
            }
          }

          return RaftModalBackdrop(
            child: RaftConnectedAppDetailCard(
              key: const ValueKey('connected-app-detail'),
              eyebrow: 'App detail',
              name: '${listing['name'] ?? ''}',
              initials: integrationInitials(
                '${listing['name'] ?? listing['clientId'] ?? ''}',
              ),
              logoUrl: listing['logoUrl'] as String?,
              badge: _installBadge(modal, listing['marketplaceInstallBadge']),
              byline: raftFormat(modal, '{category} · by {developer}', {
                'category': tr(integrationCategoryLabel(listing['category'])),
                'developer': developer,
              }),
              closeLabel: tr('Close app detail'),
              onClose: close,
              error: modalError,
              sections: [
                RaftConnectedAppDetailSection(
                  title: 'Profile',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RaftConnectedAppParagraph(
                        '${listing['description'] ?? ''}',
                      ),
                      const SizedBox(height: RaftSpace.x2),
                      RaftConnectedAppDetailRow(
                        first: true,
                        label: 'Publisher',
                        child: Text(developer),
                      ),
                      RaftConnectedAppDetailRow(
                        label: 'Homepage URL',
                        child: homepage != null && homepage.trim().isNotEmpty
                            ? RaftConnectedAppUrlLink(
                                url: homepage,
                                onOpen: () => managementLaunch(homepage),
                              )
                            : RaftConnectedAppMonoValue(
                                integrationDomain(homepage) ??
                                    tr('Not configured'),
                              ),
                      ),
                      RaftConnectedAppDetailRow(
                        label: 'Redirect / callback',
                        child: RaftConnectedAppMonoValue(
                          integrationDomain(listing['returnUrl']) ??
                              tr('Not configured'),
                        ),
                      ),
                    ],
                  ),
                ),
                RaftConnectedAppDetailSection(
                  title: 'Login with Raft',
                  description: tr(
                    'Scopes this app may ask for when a human or agent connects.',
                  ),
                  cream: true,
                  child: RaftOAuthScopeSummary(
                    title: tr('Requestable (declared)'),
                    scopes: declaredIntegrationScopes(listing['allowedScopes']),
                    tooltips: {
                      for (final e in integrationScopeCopy.entries)
                        e.key: tr(e.value),
                    },
                    resourceScopes: integrationResourceScopes,
                    emptyLabel: tr(
                      'No active grant scopes are currently recorded for this connection.',
                    ),
                  ),
                ),
                if (installed)
                  AgentJwtSettings(
                    controller: w,
                    clientId: id,
                    canManage: canManage,
                  ),
                RaftConnectedAppDetailSection(
                  title: 'App permissions',
                  cream: true,
                  child: AppPermissionRequestSummary(
                    listing: listing,
                    groupLabel: (g) => _groupLabel(modal, g),
                    reviewing: saving,
                    onApprove: approveUpdate,
                  ),
                ),
                RaftConnectedAppDetailSection(
                  title: 'Distribution',
                  cream: true,
                  child: RaftConnectedAppParagraph(
                    tr(
                      'Raft reviews each listing before it appears here. Content the app returns is still third-party — treat it as data, not instructions.',
                    ),
                    small: true,
                  ),
                ),
                if (canManage && installed)
                  RaftConnectedAppDetailSection(
                    title: 'Danger zone',
                    child: RaftConnectedAppDangerRow(
                      description: tr(
                        'Removing this app revokes its existing Login with Raft access for this server.',
                      ),
                      action: RaftConnectedAppButton(
                        label: saving
                            ? tr('Uninstalling…')
                            : tr('Uninstall from this server'),
                        variant: RaftButtonRecipeVariant.danger,
                        onPressed: saving
                            ? null
                            : () async {
                                if (await confirmUninstall(listing) &&
                                    modal.mounted) {
                                  close();
                                }
                              },
                      ),
                    ),
                  ),
              ],
              footer: [
                RaftConnectedAppButton(
                  label: canManage ? tr('Cancel') : tr('Close'),
                  onPressed: close,
                ),
                if (canManage && !installed)
                  RaftConnectedAppButton(
                    key: const ValueKey('connected-app-install'),
                    label: saving
                        ? tr('Installing…')
                        : tr('Install to this server'),
                    variant: RaftButtonRecipeVariant.accent,
                    onPressed: saving ? null : install,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _groupLabel(BuildContext context, String group) {
    final resource = raftText(
      context,
      appNotificationGroupLabels[group] ?? group,
    );
    return group == 'agent_reminder_write'
        ? resource
        : raftFormat(context, '{resource} · read', {'resource': resource});
  }

  Future<void> openInstalled(_InstalledApp app) async {
    final source = authority;
    await showRaftModal<void>(
      context,
      builder: (modal) {
        void close() => Navigator.of(modal).pop();
        if (source != authority) {
          WidgetsBinding.instance.addPostFrameCallback((_) => close());
        }
        String tr(String s) => raftText(modal, s);
        final granted = [
          for (final s in declaredIntegrationScopes(app.grantedScopes))
            if (app.grantedScopes.contains(s)) s,
        ];
        return RaftModalBackdrop(
          child: RaftConnectedAppDetailCard(
            key: const ValueKey('connected-app-installed-detail'),
            eyebrow: 'Installed app',
            name: app.name,
            initials: integrationInitials(app.name),
            logoUrl: app.logoUrl,
            byline: app.developer,
            closeLabel: tr('Close installed app details'),
            onClose: close,
            sections: [
              RaftOAuthScopeSummary(
                title: tr('Login with Raft access'),
                description: tr(
                  'OAuth scopes currently granted to this server connection.',
                ),
                scopes: granted,
                tooltips: {
                  for (final e in integrationScopeCopy.entries)
                    e.key: tr(e.value),
                },
                resourceScopes: integrationResourceScopes,
                emptyLabel: tr(
                  'No active grant scopes are currently recorded for this connection.',
                ),
              ),
              AgentJwtSettings(
                controller: w,
                clientId: app.id,
                canManage: canManage,
              ),
              _InstalledAppPermissions(
                controller: w,
                clientId: app.id,
                canManage: canManage,
                groupLabel: (g) => _groupLabel(modal, g),
              ),
            ],
            footer: [
              RaftConnectedAppButton(label: tr('Close'), onPressed: close),
            ],
          ),
        );
      },
    );
  }

  /// The marketplace / installed / registered projection of
  /// IntegrationsSection.
  ({
    List<Map<String, dynamic>> listings,
    List<_InstalledApp> installed,
    List<Map<String, dynamic>> registered,
  })
  get projection {
    final granted = <String, Set<String>>{};
    for (final item in access) {
      if (item['type'] != 'active' || item['revokedAt'] != null) continue;
      (granted['${item['clientId']}'] ??= {}).addAll(
        managementStrings(item['scopes']),
      );
    }
    final editable = {
      for (final app in apps)
        if (app['appType'] == 'server_local' ||
            (app['appType'] == 'third_party_global' &&
                _canEditSourceOwned(app['publishStatus'] as String?)))
          '${app['id']}',
    };
    final installed = [
      for (final app in marketplace)
        if (app['installedAt'] != null && !editable.contains('${app['id']}'))
          _InstalledApp(
            id: '${app['id']}',
            source: app,
            name: '${app['name'] ?? ''}',
            developer:
                '${app['publisherServerName'] ?? app['publisherName'] ?? raftText(context, 'Third-party developer')}',
            category: app['category'] as String?,
            editable: false,
            privateShared: app['privateShared'] == true,
            grantedScopes: [...?granted['${app['id']}']],
          ),
      for (final app in apps)
        if (editable.contains('${app['id']}'))
          _InstalledApp(
            id: '${app['id']}',
            source: app,
            name: '${app['name'] ?? ''}',
            developer: raftText(context, 'This server'),
            category: app['category'] as String?,
            editable: true,
            privateShared: false,
            grantedScopes: [...?granted['${app['id']}']],
          ),
    ];
    return (
      listings: [
        for (final app in marketplace)
          if (app['privateShared'] != true) app,
      ],
      installed: installed,
      registered: apps,
    );
  }

  bool matches(
    String query,
    String name,
    String? categoryValue,
    List<Object?> fields,
  ) {
    if (category != 'all' && categoryValue != category) return false;
    if (query.isEmpty) return true;
    return [
      name,
      ...fields,
    ].any((v) => v is String && v.toLowerCase().contains(query));
  }

  Widget? secretReveal() {
    final secret = createdSecret.value;
    if (secret == null) return null;
    return RaftAppEditorSecretReveal(
      secret: secret.value,
      copied: secret.copied,
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: secret.value));
        createdSecret.value = secret.copy(copied: true);
        secretReset?.cancel();
        secretReset = Timer(const Duration(milliseconds: 1500), () {
          final current = createdSecret.value;
          if (current != null) {
            createdSecret.value = current.copy(copied: false);
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget page(BuildContext context, RaftConnectedAppsTab value) =>
        KeyedSubtree(
          key: PageStorageKey(('connected-apps', authority, value)),
          child: section(context, value, scrollable: true),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return section(context, tab);
        return RaftSectionPager<RaftConnectedAppsTab>(
          key: ValueKey(authority),
          sections: RaftConnectedAppsTab.values,
          value: tab,
          onChanged: (value) => setState(() => tab = value),
          swipeEnabled: RaftInteraction.of(context).touch,
          builder: page,
        );
      },
    );
  }

  Widget section(
    BuildContext context,
    RaftConnectedAppsTab shownTab, {
    bool scrollable = false,
  }) {
    String tr(String s) => raftText(context, s);
    final p = projection;
    final query = search.text.trim().toLowerCase();
    String byline(
      Map<String, dynamic> app,
    ) => raftFormat(context, '{category} · by {developer}', {
      'category': tr(integrationCategoryLabel(app['category'])),
      'developer':
          '${app['publisherServerName'] ?? app['publisherName'] ?? tr('Third-party developer')}',
    });
    final listings = [
      for (final app in p.listings)
        if (matches(query, '${app['name'] ?? ''}', app['category'], [
          app['description'],
          app['publisherServerName'] ?? app['publisherName'],
          app['clientId'],
        ]))
          RaftMarketplaceAppTile(
            id: '${app['id']}',
            name: '${app['name'] ?? ''}',
            initials: integrationInitials('${app['name'] ?? app['clientId']}'),
            logoUrl: app['logoUrl'] as String?,
            byline: byline(app),
            description: app['description'] as String?,
            badge: _installBadge(context, app['marketplaceInstallBadge']),
            state: app['installedAt'] != null
                ? RaftMarketplaceAppState.installed
                : canManage
                ? RaftMarketplaceAppState.install
                : RaftMarketplaceAppState.available,
            stateLabel: app['installedAt'] != null
                ? tr('Installed')
                : canManage
                ? tr('Install')
                : tr('Available'),
            onOpen: () => openListing(app),
          ),
    ];
    final installedRows = [
      for (final app in p.installed)
        if (matches(query, app.name, app.category, [
          app.source['description'],
          app.developer,
          app.source['clientId'],
        ]))
          RaftConnectedAppRow(
            id: app.id,
            name: app.name,
            initials: integrationInitials(app.name),
            logoUrl: app.logoUrl,
            meta:
                '${tr(integrationCategoryLabel(app.category))} · ${app.developer}',
            badges: [
              ?_distributionBadge(
                context,
                app.source['publishStatus'] as String?,
              ),
              if (app.privateShared)
                RaftConnectedAppBadge.outline(tr('Shared')),
              if (app.editable)
                RaftConnectedAppBadge.success(tr('This server')),
            ],
            description: app.source['description'] as String?,
            homepageUrl: app.source['homepageUrl'] as String?,
            homepageLabel: integrationDomain(app.source['homepageUrl']),
            onOpenName: app.editable ? null : () => openInstalled(app),
            actionLabel: !canManage
                ? null
                : app.editable
                ? tr('Edit')
                : savingId == app.id
                ? tr('Uninstalling…')
                : tr('Uninstall'),
            actionGlyph: app.editable ? RaftGlyph.pencil : null,
            onAction: !canManage || savingId == app.id
                ? null
                : app.editable
                ? () => openEditor(app.source)
                : () => confirmUninstall(app.source),
          ),
    ];
    final registeredRows = [
      for (final app in p.registered)
        if (matches(query, '${app['name'] ?? ''}', app['category'], [
          app['description'],
          app['clientId'],
        ]))
          RaftConnectedAppRow(
            id: '${app['id']}',
            name: '${app['name'] ?? ''}',
            initials: integrationInitials('${app['name'] ?? app['clientId']}'),
            logoUrl: app['logoUrl'] as String?,
            meta: tr(integrationCategoryLabel(app['category'])),
            badges: [
              ?_distributionBadge(context, app['publishStatus'] as String?),
            ],
            description: app['description'] as String?,
            statusHint: _statusHint(app['publishStatus'] as String?) == null
                ? null
                : tr(_statusHint(app['publishStatus'] as String?)!),
            homepageUrl: app['homepageUrl'] as String?,
            homepageLabel: integrationDomain(app['homepageUrl']),
            actionLabel:
                canManage &&
                    _canEditSourceOwned(app['publishStatus'] as String?)
                ? tr('Edit')
                : null,
            actionGlyph: RaftGlyph.pencil,
            onAction: () => openEditor(app),
          ),
    ];
    final cold = loading;
    final empty = cold
        ? null
        : switch (shownTab) {
            RaftConnectedAppsTab.marketplace when listings.isEmpty => tr(
              'No third-party marketplace apps match this view.',
            ),
            RaftConnectedAppsTab.installed when installedRows.isEmpty => tr(
              'No installed apps match this view.',
            ),
            RaftConnectedAppsTab.myApps when registeredRows.isEmpty =>
              p.registered.isEmpty
                  ? tr('No registered apps yet.')
                  : tr('No registered apps match this view.'),
            _ => null,
          };
    return Semantics(
      liveRegion: error != null,
      child: RaftConnectedAppsSection(
        scrollable: scrollable,
        description: tr(
          canManage
              ? 'Browse reviewed marketplace apps, see apps installed on this server, and manage apps registered by this server.'
              : 'Browse reviewed marketplace apps, see apps installed on this server, and view apps registered by this server.',
        ),
        adminNote: canManage
            ? null
            : tr(
                'Only server owners and admins can install, edit, or remove apps.',
              ),
        loading: cold,
        onRegister: canManage ? openEditor : null,
        tab: shownTab,
        counts: (
          marketplace: p.listings.length,
          installed: p.installed.length,
          myApps: p.registered.length,
        ),
        onTab: (next) => setState(() => tab = next),
        searchController: search,
        onSearch: (_) => setState(() {}),
        category: category,
        categories: [
          ('all', tr('All categories')),
          for (final c in integrationCategories) (c, tr(c)),
        ],
        onCategory: (next) => setState(() => category = next),
        layout: layout,
        onLayout: setLayout,
        error: error,
        marketplace: listings,
        rows: shownTab == RaftConnectedAppsTab.installed
            ? installedRows
            : registeredRows,
        emptyMessage: empty,
        myAppsIntro: tr(
          canManage
              ? 'Apps registered by this server are managed here. Edit an app to update metadata or request marketplace review.'
              : 'Apps registered by this server are shown here. Only server owners and admins can change them.',
        ),
        secretReveal: canManage && !editorOpen ? secretReveal() : null,
        reviewNote: cold
            ? null
            : tr(
                'Raft reviews every third-party listing before it appears in the marketplace.',
              ),
      ),
    );
  }
}

/// IntegrationsSection `InstalledConnectedApp`.
class _InstalledApp {
  _InstalledApp({
    required this.id,
    required this.source,
    required this.name,
    required this.developer,
    required this.category,
    required this.editable,
    required this.privateShared,
    required this.grantedScopes,
  });
  final String id, name, developer;
  final String? category;
  final Map<String, dynamic> source;
  final bool editable, privateShared;
  final List<String> grantedScopes;
  String? get logoUrl => source['logoUrl'] as String?;
}

/// InstalledAppNotifications: GET
/// /integrations/marketplace/:id/install/app-notifications, the approved /
/// subscribed / active columns, and the approve action (PUT …/grant).
class _InstalledAppPermissions extends StatefulWidget {
  const _InstalledAppPermissions({
    required this.controller,
    required this.clientId,
    required this.canManage,
    required this.groupLabel,
  });
  final WorkspaceController controller;
  final String clientId;
  final bool canManage;
  final String Function(String group) groupLabel;
  @override
  State<_InstalledAppPermissions> createState() =>
      _InstalledAppPermissionsState();
}

class _InstalledAppPermissionsState extends State<_InstalledAppPermissions> {
  Map<String, dynamic>? state;
  bool loading = true, saving = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next load of the installed-app notification settings succeeds; the state is dropped with the page.
  String? error;
  String get path =>
      '/integrations/marketplace/${widget.clientId}/install/app-notifications';
  String get _snapshotKey => 'integrations:installed:${widget.clientId}';

  @override
  void initState() {
    super.initState();
    // A revisit paints the last accepted columns and revalidates in place.
    state =
        readPageSnapshot(widget.controller, _snapshotKey)?['state']
            as Map<String, dynamic>?;
    loading = state == null;
    load();
  }

  Future<void> load() async {
    final identity = pageIdentity(widget.controller);
    try {
      final data = managementMap(await widget.controller.client.get(path));
      if (!mounted || identity != pageIdentity(widget.controller)) return;
      setState(() {
        state = data;
        loading = false;
        error = null;
      });
      writePageSnapshot(widget.controller, _snapshotKey, identity, {
        'state': data,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = userErrorText(
          e,
          fallback: 'Failed to load installed App Notifications settings',
          where: 'installed app notifications',
        );
      });
    }
  }

  Future<void> approve() async {
    setState(() => saving = true);
    try {
      await widget.controller.client.request('PUT', '$path/grant');
      await load();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = userErrorText(
            e,
            fallback: 'Failed to update installed App Notifications settings',
            where: 'installed app notifications update',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    if (loading) {
      return RaftAppPermissionsSummary(
        description: '',
        columns: const [],
        loading: tr('Loading App Notifications...'),
      );
    }
    final s = state;
    if (s == null) {
      return error == null
          ? const SizedBox.shrink()
          : RaftConnectedAppsError(error!);
    }
    List<String> events(Object? raw) => [
      for (final e in managementStrings(raw))
        tr(appNotificationEventLabels[e] ?? e),
    ];
    final approved = managementStrings(s['approved_groups']);
    final newly = [
      for (final g in managementStrings(s['requested_groups']))
        if (!approved.contains(g)) g,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftAppPermissionsSummary(
          description: tr(
            'Permissions granted to this app on this Server are independent of user login and webhook delivery. Review and approve any additional access here.',
          ),
          badge: managementStrings(s['effective_groups']).isNotEmpty
              ? RaftConnectedAppBadge.success(tr('Enabled'))
              : RaftConnectedAppBadge.outline(tr('Disabled')),
          columns: [
            (
              tr('Approved data'),
              [for (final g in approved) widget.groupLabel(g)],
              tr('No data access'),
            ),
            (
              tr('Developer subscriptions'),
              events(s['subscribed_events']),
              tr('No subscriptions'),
            ),
            (
              tr('Active events'),
              events(s['effective_events']),
              tr('No active events'),
            ),
          ],
        ),
        if (s['app_review_pending'] == true) ...[
          const SizedBox(height: RaftSpace.x3),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftSettingsRecipeBadge(
              label: tr('App Review pending'),
              variant: RaftBadgeRecipeVariant.warning,
              uppercase: true,
            ),
          ),
        ],
        if (s['approval_required'] == true) ...[
          const SizedBox(height: RaftSpace.x3),
          RaftAppPermissionsApproval(
            notice: tr(
              'This app requests new data access. Review the new data groups before approving the update.',
            ),
            groups: [
              for (final g in newly)
                raftFormat(context, 'New data group: {group}', {
                  'group': widget.groupLabel(g),
                }),
            ],
            action: widget.canManage
                ? RaftSettingsRecipeButton(
                    label: saving ? tr('Approving...') : tr('Approve update'),
                    variant: RaftButtonRecipeVariant.accent,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: saving ? null : approve,
                  )
                : null,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: RaftSpace.x3),
          RaftConnectedAppsError(error!),
        ],
      ],
    );
  }
}

List<String> parseIntegrationScopes(String input) =>
    input.split(RegExp(r'[,\s]+')).where((v) => v.isNotEmpty).toSet().toList();
