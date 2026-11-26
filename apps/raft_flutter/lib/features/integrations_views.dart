import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/app_install_expectation.dart';
import '../data/cause_notice.dart';
import '../data/device_preferences.dart';
import '../data/managed_mcp_apps.dart';
import '../data/raft_location.dart' show RaftProfileKind;
import '../data/raft_navigation_history.dart';
import '../data/user_error.dart';
import '../data/web_error.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'app_notifications_catalog.dart';
import 'app_link_store.dart';
import 'app_permission_request_summary.dart';
import 'app_permission_updates.dart';
import 'app_setup.dart';
import 'connected_app_editor.dart';
import 'connected_app_marketplace.dart';
import 'connected_app_consent.dart';
import 'connected_app_bot.dart';
import 'connected_app_prompt_text_panel.dart';
import 'link_preview_consents.dart';
import 'mcp_app_editor.dart';
import 'second_factor_step_up.dart';

const integrationScopeLabels = <String, String>{
  'openid': 'OpenID identity',
  'profile': 'Basic profile',
  'email': 'Email address',
  'identity': 'Raft identity card',
  'agent:read': 'Read server agent directory',
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

/// Display copy for the server's category values.
String integrationCategoryDisplay(String category) => switch (category) {
  'AI & Automation' => 'AI & automation',
  'Productivity & Collaboration' => 'Productivity & collaboration',
  'Developer Tools' => 'Developer tools',
  'Data & Analytics' => 'Data & analytics',
  'Business Ops' => 'Business ops',
  'Content & Creative' => 'Content & creative',
  _ => category,
};

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
  'openid': 'Signs you in with Raft and issues a stable identity token. Authentication only.',
  'profile': 'Reads your basic profile fields (display name and similar). No access to messages, files, or agents.',
  'email': 'Reads your verified Raft account email address. No access to messages, files, or agents.',
  'identity': "Reads who you are — human or agent, your Raft subject, and which server/principal you're acting as. No content access.",
  'agent:read': 'Read the IDs, handles, display names and avatars of agents in the server you authorize. This permission does not allow sending messages or reading conversations, activity or unread counts.',
  'agent:event:write':
      'Sends structured event messages to the one agent you authorize.',
  'agent:notification:write':
      'Sends notification messages to the one agent you authorize.',
};
const integrationResourceScopes = {
  'agent:event:write',
  'agent:notification:write',
};

List<String> declaredIntegrationScopes(Object? scopes) =>
    effectiveAllowedOAuthScopes(scopes).toSet().toList();

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
  'publish_requested' || 'in_review' => 'Marketplace review is pending. You can edit this app while it waits, or withdraw the request.',
  'unpublish_requested' => 'Marketplace offline review is pending. The app stays listed and installable until App Admin approves removal. Approval preserves the source Server’s installation and access, but removes them on other Servers.',
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
    _ => RaftConnectedAppBadge.muted(tr('Private')),
  };
}

/// ConnectedAppMarketplaceInstallBadge.
RaftConnectedAppBadge? _installBadge(BuildContext context, Object? raw) {
  final badge = managementMap(raw);
  return switch (badge['kind']) {
    // settings.connectedApps.marketplaceNew: 新上架 (the plain `New` entry is 新增).
    'new' => RaftConnectedAppBadge(
      raftTextZh(context, 'New', '新上架'),
      variant: RaftBadgeRecipeVariant.information,
      appearance: RaftBadgeRecipeAppearance.soft,
    ),
    'bucket' => RaftConnectedAppBadge.outline(
      raftFormat(context, '{count} installs', {
        'count': const {
          '10_plus': '10+',
          '100_plus': '100+',
          '1k_plus': '1k+',
        }[badge['bucket']],
      }),
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
  const IntegrationsView({
    super.key,
    required this.controller,
    this.standalone = false,
  });
  final WorkspaceController controller;
  final bool standalone;
  @override
  State<IntegrationsView> createState() => _IntegrationsState();
}

class _IntegrationsState extends ManagementState<IntegrationsView> {
  @override
  WorkspaceController get w => widget.controller;

  /// Registered clients, marketplace listings and the access overview.
  List<Map<String, dynamic>> apps = [], marketplace = [], access = [];
  List<Map<String, dynamic>> mcpApps = [];
  Future<void>? mcpLoad;
  bool mcpFailed = false;
  RaftConnectedAppsTab tab = RaftConnectedAppsTab.installed;
  final search = TextEditingController();
  final listingPage = ConnectedAppMarketplace();
  String category = 'all', listingType = 'all', listingSort = 'installs';
  Timer? listingSearch;
  Future<bool>? installTextFlag;
  int? handledAppLink;
  int? marketplaceTotal;
  late final botLinkNotice = CauseNotice(scope: () => authority);
  late final appActionNotice = CauseNotice(scope: () => authority);
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

  @override
  void didUpdateWidget(covariant IntegrationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    rebindManagementController();
    if (hasAcceptedData) _openLocationTarget();
  }

  Timer? secretReset;

  @override
  void dispose() {
    secretReset?.cancel();
    listingSearch?.cancel();
    search.dispose();
    createdSecret.dispose();
    super.dispose();
  }

  @override
  void clearData() {
    listingPage.clear();
    listingSearch?.cancel();
    appActionNotice.clear();
    installTextFlag = null;
    apps = [];
    marketplace = [];
    access = [];
    mcpApps = [];
    mcpLoad = null;
    mcpFailed = false;
    marketplaceTotal = null;
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
    'mcpApps': mcpApps,
    'marketplaceTotal': marketplaceTotal,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    apps = fields['apps'] as List<Map<String, dynamic>>;
    marketplace = fields['marketplace'] as List<Map<String, dynamic>>;
    access = fields['access'] as List<Map<String, dynamic>>;
    mcpApps = fields['mcpApps'] as List<Map<String, dynamic>>? ?? [];
    marketplaceTotal = fields['marketplaceTotal'] as int?;
    return true;
  }

  @override
  Future<void> loadData(int request, int generation) =>
      withWebError('Failed to load connected apps', () {
        appActionNotice.clear();
        return _loadData(request, generation);
      }, where: 'connected apps');

  Future<void> _loadData(int request, int generation) async {
    unawaited(mcpLoad ??= _loadMcpApps());
    unawaited(_readInstallTextFlag());
    if (widget.standalone) {
      unawaited(_loadMarketplaceTotal(request, generation));
    }
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
    if (tab == RaftConnectedAppsTab.marketplace) {
      await _loadListings();
    }
    if (accepts(generation, request)) _openLocationTarget();
  }

  Future<void> _loadMarketplaceTotal(int request, int generation) async {
    int? total;
    try {
      final result = await w.client.get(
        ConnectedAppMarketplace.path,
        query: const {'sort': 'installs'},
      );
      total = managementMap(result)['total'] as int?;
    } on RaftApiException {
      total = null;
    }
    if (!accepts(generation, request)) return;
    setState(() => marketplaceTotal = total);
    saveSnapshot();
  }

  void _openLocationTarget() {
    final revision = w.navigation.revision;
    if (handledAppLink == revision) return;
    final review = w.location.query('permission_updates') == '1';
    final listingId = w.location.query('marketplace_app')?.trim();
    final installedId = w.location.query('installed_app')?.trim();
    final botClientId = w.location.query('app_bot')?.trim();
    final consumesLink = botClientId != null || installedId != null;
    if (!review && listingId == null && !consumesLink) return;
    final listing = projection.listings
        .where(
          (row) =>
              listingId != null &&
              (row['id'] == listingId || row['clientId'] == listingId),
        )
        .firstOrNull;
    final installed = projection.installed
        .where(
          (app) => botClientId != null
              ? app.source['clientId'] == botClientId
              : app.id == installedId,
        )
        .firstOrNull;
    if (!review && listing == null && !consumesLink) return;
    handledAppLink = revision;
    final source = authority;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          authority != source ||
          w.navigation.revision != revision) {
        return;
      }
      if (consumesLink) {
        w.navigation.navigate(
          w.location.withQuery({'installed_app': null, 'app_bot': null}),
          kind: RaftNavigationKind.replace,
        );
        handledAppLink = w.navigation.revision;
      }
      if (botClientId != null) {
        selectTab(RaftConnectedAppsTab.installed);
        _clearFilters();
        setState(
          () => botLinkNotice.raise(
            installed == null
                ? 'This server doesn’t have this app installed.'
                : null,
          ),
        );
        if (installed != null) {
          unawaited(openInstalled(installed, fromBotLink: true));
        }
      } else if (review) {
        showUpdates();
      } else if (installed != null) {
        selectTab(RaftConnectedAppsTab.installed);
        _clearFilters();
        unawaited(openInstalled(installed));
      } else if (listing != null) {
        unawaited(openListing(listing));
      }
    });
  }

  Future<void> _loadMcpApps() async {
    final source = authority;
    try {
      final raw = await w.client.get('/mcp/apps');
      if (!mounted || source != authority) return;
      setState(() {
        mcpApps = managementRows(managementMap(raw)['apps']);
        mcpFailed = false;
      });
      if (!loading) saveSnapshot();
    } on RaftApiException catch (error) {
      if (!mounted || source != authority) return;
      setState(() => mcpFailed = error.status != 404);
    }
  }

  Future<void> _refreshApps() async {
    await Future.wait([mcpLoad = _loadMcpApps(), reload()]);
  }

  Future<void> _openMcpEditor([String? id]) => scopedRaftModal<void>(
    form: true,
    formDismissible: false,
    // FormDialog's backdrop draws no scrollbar; the route is not dismissible,
    // so an outside press still does not close the editor.
    formScrollbar: false,
    dialogMaxWidth: 1024,
    (modal) => McpAppEditor(
      controller: w,
      appId: id,
      onClose: () => Navigator.of(modal).pop(),
      onChanged: () => mcpLoad = _loadMcpApps(),
      onBrowse: () {
        Navigator.of(modal).pop();
        _clearFilters();
        selectTab(RaftConnectedAppsTab.marketplace);
      },
    ),
  );

  Future<void> _installMcpTemplate(Map<String, dynamic> row) async {
    ManagedMcpApp? installed;
    final source = authority;
    await run(() async {
      if (!w.can('manageIntegrations') || row['templateKey'] is! String) return;
      installed = ManagedMcpApp(
        await ManagedMcpAppsApi(w.client).request(
          'POST',
          '/mcp/apps',
          data: {
            'source': {'kind': 'template', 'templateKey': row['templateKey']},
            'profile': {
              for (final key in [
                'name',
                'description',
                'homepageUrl',
                'category',
              ])
                key: row[key],
              'whenToUse': null,
            },
          },
        ),
      );
      if (mounted && source == authority) {
        unawaited(mcpLoad = _loadMcpApps());
        unawaited(_loadListings());
      }
    }, refresh: false);
    if (mounted && source == authority && installed != null) {
      await _openMcpEditor(installed!.id);
    }
  }

  Future<bool> _readInstallTextFlag() {
    final serverId = w.server?.id;
    return installTextFlag ??= serverId == null
        ? Future.value(false)
        : appPromptTextConsent(w.client, serverId);
  }

  Future<void> _loadListings({bool next = false}) async {
    final source = authority;
    final query = search.text.trim();
    final operation = listingPage.fetch(
      w.client,
      {
        'sort': listingSort,
        if (listingType != 'all') 'type': listingType,
        if (category != 'all') 'category': category,
        if (query.isNotEmpty) 'q': query,
      },
      isCurrent: () => mounted && source == authority,
      next: next,
    );
    refreshPage();
    await operation;
    if (mounted && source == authority) refreshPage();
  }

  void selectTab(RaftConnectedAppsTab next) {
    setState(() => tab = next);
    if (next == RaftConnectedAppsTab.marketplace && !listingPage.loading) {
      unawaited(_loadListings());
    }
  }

  void filterListings({bool debounce = false}) {
    listingSearch?.cancel();
    setState(listingPage.clear);
    if (tab != RaftConnectedAppsTab.marketplace) return;
    if (debounce) {
      listingSearch = Timer(const Duration(milliseconds: 250), _loadListings);
    } else {
      unawaited(_loadListings());
    }
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
    final source = authority;
    if (createdSecret.value?.clientId != '${app?['id']}') {
      createdSecret.value = null;
    }
    setState(() => editorOpen = true);
    final bool? openInstalledDetail;
    try {
      openInstalledDetail = await _showEditor(app);
    } finally {
      if (mounted) setState(() => editorOpen = false);
    }
    if (!mounted || source != authority || openInstalledDetail != true) return;
    selectTab(RaftConnectedAppsTab.installed);
    _clearFilters();
    final entry = projection.entries
        .where((entry) => entry.id == app?['id'])
        .firstOrNull;
    if (entry != null) await openInstalled(entry);
  }

  Future<bool?> _showEditor(Map<String, dynamic>? app) => scopedRaftModal<bool>(
    form: true,
    formDismissible: false,
    // FormDialog's backdrop draws no scrollbar; the route is not dismissible,
    // so an outside press still does not close the editor.
    formScrollbar: false,
    dialogMaxWidth: 1024,
    (modal) => ConnectedAppEditor(
      controller: w,
      app: app,
      promptTextConsent: app == null ? null : _readInstallTextFlag(),
      secret: createdSecret,
      onDenied: invalidateDeniedMutation,
      onClose: () => Navigator.of(modal).pop(),
      onOpenInstalledApp: app == null
          ? null
          : () => Navigator.of(modal).pop(true),
      onUpdated: (updated) {
        if (!mounted) return;
        setState(
          () => apps = [
            for (final app in apps)
              if (app['id'] == updated['id']) updated else app,
          ],
        );
        saveSnapshot();
      },
      onSaved: ({created}) async {
        if (created != null && mounted) {
          setState(() => tab = RaftConnectedAppsTab.myApps);
        }
        await reload();
      },
    ),
  );

  /// Runs [body]; on failure returns the English text to show (the server's
  /// `error`, else [fallback]), or null when the change was dropped (stale or
  /// authority revoked).
  Future<String?> _mutate(
    String id,
    Future<void> Function() body, {
    required String fallback,
    String? Function(Object error)? explain,
    bool refresh = true,
  }) async {
    final generation = w.client.generation, source = authority;
    // Web: every connected-app action starts with `setError("")`.
    setState(() {
      savingId = id;
      error = null;
      appActionNotice.clear();
    });
    try {
      await body();
      if (refresh && accepts(generation) && source == authority) await reload();
      return null;
    } catch (e) {
      if (!accepts(generation) || source != authority) return null;
      // Closed "Verify it's you": nothing changed, no error.
      if (isSecondFactorStepUpCancelled(e)) return null;
      if (invalidateDeniedMutation(e)) return null;
      return explain?.call(e) ??
          userErrorText(e, fallback: fallback, where: 'connected apps');
    } finally {
      if (mounted && accepts(generation) && source == authority) {
        setState(() => savingId = null);
      }
    }
  }

  Future<bool> confirmUninstall(
    Map<String, dynamic> app, {
    ValueChanged<String?>? onError,
  }) async {
    final source = authority;
    final generation = w.client.generation;
    final showError =
        onError ?? (message) => setState(() => appActionNotice.raise(message));
    showError(null);
    var removed = false;
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
        confirmLabel: raftText(context, 'Uninstall'),
        cancelLabel: raftText(context, 'Cancel'),
        loadingLabel: raftText(context, 'Uninstalling...'),
        confirmGlyph: RaftGlyph.trash2,
        onConfirm: () async {
          if (!accepts(generation) || source != authority) return;
          final failure = await _mutate(
            '${app['id']}',
            () async {
              await w.client.delete(
                '/integrations/marketplace/${app['id']}/install',
              );
              removed = true;
            },
            fallback: 'Failed to uninstall marketplace app',
            refresh: false,
          );
          if (!accepts(generation) || source != authority) return;
          if (failure != null) showError(failure);
        },
      ),
      nestedBackdrop: false,
    );
    if (ok != true || !removed || !accepts(generation) || source != authority) {
      return false;
    }
    unawaited(reload());
    return true;
  }

  Future<void> openListing(Map<String, dynamic> opened) async {
    final source = authority;
    final promptTextFlag = _readInstallTextFlag();
    final dangerRowKey = GlobalKey();
    var joinBot = true, installing = false;
    Map<String, dynamic>? reviewedOverride;
    // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the install retry starts; the local variable dies with the app detail modal.
    String? modalError;
    await showRaftDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (modal) => FutureBuilder<bool>(
        future: promptTextFlag,
        builder: (modal, flag) => StatefulBuilder(
          builder: (modal, setModal) {
            String tr(String s) => raftText(modal, s);
            void close() => Navigator.of(modal).pop();
            if (source != authority) {
              WidgetsBinding.instance.addPostFrameCallback((_) => close());
            }
            final id = '${opened['id']}';
            // The listing reloads after a mutation; follow it by id.
            final listing =
                reviewedOverride ??
                marketplace.firstWhere(
                  (m) => '${m['id']}' == id,
                  orElse: () => opened,
                );
            final installed = listing['installedAt'] != null;
            final showPromptText = flag.data == true;
            final waitingForTextFlag =
                flag.connectionState == ConnectionState.waiting &&
                listing['promptTextRevisionId'] is String;
            final hasSetup = hasAppSetup(listing);
            final saving = installing || savingId == id;
            final botHandle =
                managementMap(listing['bot'])['handle'] as String?;
            final installedBot = installed
                ? managementMap(
                    projection.installed
                        .where((app) => app.id == id)
                        .firstOrNull
                        ?.source['bot'],
                  )
                : const <String, dynamic>{};
            final reviewed = AppInstallExpectation.of(
              allowedScopes: listing['allowedScopes'],
              groups: listing['appNotificationGroups'],
              textRevisionId: listing['promptTextRevisionId'],
              promptTextConsent: showPromptText,
            );
            final developer =
                '${listing['publisherServerName'] ?? listing['publisherName'] ?? tr('Third-party developer')}';
            final homepage = listing['homepageUrl'] as String?;
            Future<void> install() async {
              if (installing) return;
              setModal(() {
                modalError = null;
                installing = true;
              });
              var cancelled = false, changed = false;
              String? conflict;
              final failure = await _mutate(
                id,
                () async {
                  try {
                    final answer = managementMap(
                      await withSecondFactorStepUp(
                        modal,
                        w.client,
                        () => w.client.post(
                          '/integrations/marketplace/$id/install',
                          data: {
                            ...reviewed.body,
                            if (botHandle != null) 'bot': joinBot,
                          },
                        ),
                        reason: StepUpReason.appAccess,
                      ),
                    );
                    if (joinBot &&
                        managementStrings(answer['warnings'])
                            .contains('app_bot_handle_conflict')) {
                      conflict = botHandle;
                    }
                    if (modal.mounted && source == authority) {
                      if (hasSetup) {
                        setModal(
                          () => reviewedOverride = {
                            ...listing,
                            'installedAt': true,
                          },
                        );
                      } else {
                        close();
                      }
                    }
                  } on SecondFactorStepUpCancelled {
                    cancelled = true;
                    rethrow;
                  }
                },
                fallback: 'Failed to install marketplace app',
                explain: (e) {
                  changed = isAppPermissionsChanged(e);
                  final updated = appPermissionsChangedCurrent(e);
                  if (e is RaftApiException && updated != null) {
                    final text = managementMap(e.details['current_text']);
                    if (!showPromptText ||
                        updated.textRevisionId == reviewed.textRevisionId ||
                        text.isNotEmpty) {
                      reviewedOverride = {
                        ...listing,
                        'allowedScopes': updated.scopes,
                        'appNotificationGroups': updated.groups,
                        if (showPromptText)
                          'promptTextRevisionId': updated.textRevisionId,
                        if (text.isNotEmpty) ...{
                          'name': text['name'],
                          'description': text['description'],
                          'whenToUse': text['when_to_use'],
                        },
                      };
                      changed = false;
                    }
                  }
                  return appInstallRefusal(
                    e,
                    sentTextRevisionId: reviewed.textRevisionId,
                    // settings.connectedApps.permissionsChanged.
                    permissionsChanged:
                        "This app's permissions just changed. Review the "
                        'current permissions, then confirm again.',
                  );
                },
              );
              // Web: the current set replaces the shown one (it reloads when
              // the answer lacks it), so the next Install confirms it.
              if (changed && mounted && source == authority) {
                await reload();
                reviewedOverride = null;
              }
              if (conflict != null && mounted && source == authority) {
                setState(
                  () => appActionNotice.raise(
                    raftFormat(
                      context,
                      '@{handle} is already taken by another agent on this server, so the app didn’t join. Rename that agent, then add @{handle} from Installed apps.',
                      {'handle': conflict},
                    ),
                  ),
                );
              }
              if (!modal.mounted) return;
              if (cancelled || source != authority) {
                setModal(() => installing = false);
                return;
              }
              setModal(() {
                installing = false;
                modalError = failure;
              });
            }

            return RaftConnectedAppDetailCard(
              key: const ValueKey('connected-app-detail'),
              eyebrow: 'App detail',
              name: '${listing['name'] ?? ''}',
              initials: integrationInitials(
                '${listing['name'] ?? listing['clientId'] ?? ''}',
              ),
              logoUrl: listing['logoUrl'] as String?,
              badge: _installBadge(modal, listing['marketplaceInstallBadge']),
              byline: raftFormat(modal, '{category} · by {developer}', {
                'category': tr(
                  integrationCategoryDisplay(
                    integrationCategoryLabel(listing['category']),
                  ),
                ),
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
                      if (botHandle != null)
                        RaftConnectedAppDetailRow(
                          label: 'Posts as',
                          child: Column(
                            crossAxisAlignment:
                                raftBreakpointWidth(modal) >= 640
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            spacing: RaftSpace.x2,
                            children: [
                              RaftConnectedAppMonoValue('@$botHandle'),
                              if (installedBot['grant'] == 'pending')
                                ConnectedAppBot(
                                  workspace: w,
                                  clientId: id,
                                  appName: '${listing['name'] ?? ''}',
                                  offer: installedBot,
                                  marketplaceHint: true,
                                  onChanged: (bot) {
                                    _updateBot(id, bot);
                                    setModal(() {});
                                  },
                                  onViewProfile: (_) {},
                                ),
                            ],
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
                      for (final scope in declaredIntegrationScopes(
                        listing['allowedScopes'],
                      ))
                        scope: tr(
                          integrationScopeCopy[scope] ??
                              'Raft has no description for this scope.',
                        ),
                    },
                    resourceScopes: integrationResourceScopes,
                    emptyLabel: tr('No active grant scopes'),
                  ),
                ),
                if (hasSetup && installed)
                  AppSetupPanel(controller: w, clientId: id)
                else if (hasSetup &&
                    appSetupDomain(listing['setupUrl']) != null)
                  RaftAppSetupRequirement(
                    domain: appSetupDomain(listing['setupUrl'])!,
                    description: listing['setupDescription'] as String?,
                  ),
                RaftConnectedAppDetailSection(
                  title: 'App permissions',
                  cream: true,
                  child: AppPermissionRequestSummary(
                    listing: listing,
                    groupLabel: (g) => _groupLabel(modal, g),
                  ),
                ),
                if (showPromptText)
                  ConnectedAppPromptTextPanel(
                    key: ValueKey(('review', id)),
                    workspace: w,
                    clientId: id,
                    service: listing['clientId'] as String?,
                    onReviewed: reload,
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
                if (canManage && !installed)
                  RaftConnectedAppDetailSection(
                    title: 'Installing approves',
                    description: tr(
                      'Install records exactly these for this Server. If the app changes them before you confirm, nothing is installed and this list updates.',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: RaftSpace.x3,
                      children: [
                        ConnectedAppPermissionSet(permissions: reviewed),
                        if (botHandle != null)
                          ConnectedAppInstallBotOption(
                            app: '${listing['name'] ?? ''}',
                            handle: botHandle,
                            server: w.server?.name ?? '',
                            checked: joinBot,
                            onChanged: saving
                                ? null
                                : (value) => setModal(() => joinBot = value),
                          ),
                      ],
                    ),
                  ),
                if (canManage && !installed && reviewed.textRevisionId != null)
                  ConnectedAppInstallPromptText(
                    text: ConnectedAppPromptText(
                      name: '${listing['name'] ?? ''}',
                      description: listing['description'] as String?,
                      whenToUse: listing['whenToUse'] as String?,
                      service: listing['clientId'] as String?,
                    ),
                  ),
                if (canManage && installed)
                  RaftConnectedAppDetailSection(
                    title: 'Danger zone',
                    child: RaftConnectedAppDangerRow(
                      key: dangerRowKey,
                      description: tr(
                        'Removing this app revokes its existing Login with Raft access for this server.',
                      ),
                      action: RaftConnectedAppButton(
                        key: const ValueKey(
                          'connected-app-marketplace-uninstall',
                        ),
                        label: saving
                            ? tr('Uninstalling...')
                            : tr('Uninstall from this server'),
                        variant: RaftButtonRecipeVariant.danger,
                        onPressed: saving
                            ? null
                            : () async {
                                final scroll = Scrollable.of(
                                  dangerRowKey.currentContext!,
                                ).position;
                                final distanceFromEnd = scroll.extentAfter;
                                final removed = await confirmUninstall(
                                  listing,
                                  onError: (message) {
                                    if (modal.mounted) {
                                      setModal(() => modalError = message);
                                    }
                                  },
                                );
                                if (removed && modal.mounted) {
                                  close();
                                } else if (modalError != null) {
                                  await WidgetsBinding.instance.endOfFrame;
                                  final row = dangerRowKey.currentContext;
                                  if (row != null && row.mounted) {
                                    final position = Scrollable.of(row)
                                        .position;
                                    position.jumpTo(
                                      (position.maxScrollExtent -
                                              distanceFromEnd)
                                          .clamp(
                                            position.minScrollExtent,
                                            position.maxScrollExtent,
                                          )
                                          .toDouble(),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ),
              ],
              footer: [
                RaftConnectedAppButton(
                  label: canManage ? tr('Cancel') : tr('Close'),
                  variant: canManage && !installed
                      ? RaftButtonRecipeVariant.ghost
                      : RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.lg,
                  onPressed: close,
                ),
                if (canManage && !installed)
                  RaftConnectedAppButton(
                    key: const ValueKey('connected-app-install'),
                    label: waitingForTextFlag
                        ? tr('Loading…')
                        : saving
                        ? tr('Installing…')
                        : tr('Install to this server'),
                    variant: RaftButtonRecipeVariant.accent,
                    size: RaftButtonRecipeSize.lg,
                    onPressed: saving || waitingForTextFlag ? null : install,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  VoidCallback? _homepageAction(Map<String, dynamic> app) {
    final url = (app['homepageUrl'] as String?)?.trim();
    return url == null || url.isEmpty ? null : () => managementLaunch(url);
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

  Future<void> openInstalled(
    _InstalledApp app, {
    bool fromBotLink = false,
  }) async {
    final source = authority;
    setState(appActionNotice.clear);
    final modalError = CauseNotice(scope: () => authority);
    await showRaftDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (modal) => StatefulBuilder(
        builder: (modal, setModal) {
          void close() => Navigator.of(modal).pop();
          if (source != authority) {
            WidgetsBinding.instance.addPostFrameCallback((_) => close());
          }
          String tr(String s) => raftText(modal, s);
          final granted = app.grantedScopes;
          final awaitingApproval = _awaitsApproval(app);
          final permissions = canManage
              ? _InstalledAppPermissions(
                  controller: w,
                  clientId: app.id,
                  service: app.source['clientId'] as String?,
                  canManage: true,
                  topInset: awaitingApproval ? 0 : RaftSpace.x4,
                  groupLabel: (g) => _groupLabel(modal, g),
                  onError: (message) {
                    if (modal.mounted &&
                        source == authority &&
                        modalError.message != message) {
                      setState(() => appActionNotice.raise(message));
                      setModal(() => modalError.raise(message));
                    }
                  },
                  onUpdated: () async {
                    await Future.wait([
                      reload(),
                      AppPermissionUpdates.of(w).refresh(changed: true),
                    ]);
                  },
                )
              : null;
          final offeredBot = managementMap(app.source['bot']);
          final hasBot =
              offeredBot['offered'] != false &&
              (offeredBot['handle'] as String?)?.isNotEmpty == true;
          return RaftConnectedAppDetailCard(
            key: const ValueKey('connected-app-installed-detail'),
            eyebrow: 'Installed app',
            name: app.name,
            initials: integrationInitials(app.name),
            logoUrl: app.logoUrl,
            byline: app.developer,
            closeLabel: tr('Close installed app details'),
            onClose: close,
            error: modalError.message,
            sections: [
              if (awaitingApproval && !hasBot) ?permissions,
              if (hasBot)
                ConnectedAppBot(
                  workspace: w,
                  clientId: app.id,
                  appName: app.name,
                  logo: RaftAppLogo(
                    initials: integrationInitials(app.name),
                    logoUrl: app.logoUrl,
                    size: RaftAppLogoSize.sm,
                  ),
                  offer: offeredBot,
                  onChanged: (bot) => _updateBot(app.id, bot),
                  fromBotLink: fromBotLink,
                  pendingPermissions: awaitingApproval ? permissions : null,
                  onFindAdmin: () {
                    close();
                    if (source == authority) w.setSection('members');
                  },
                  onViewProfile: (id) {
                    close();
                    if (source == authority) {
                      w.openProfile(RaftProfileKind.agent, id);
                    }
                  },
                ),
              if (hasAppSetup(app.source))
                AppSetupPanel(controller: w, clientId: app.id),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RaftOAuthScopeSummary(
                    title: tr('Login with Raft access'),
                    description: tr(
                      'OAuth scopes currently granted to this server connection.',
                    ),
                    scopes: granted,
                    tooltips: {
                      for (final scope in granted)
                        scope: tr(
                          integrationScopeCopy[scope] ??
                              'Raft has no description for this scope.',
                        ),
                    },
                    resourceScopes: integrationResourceScopes,
                    emptyLabel: tr('No active grant scopes'),
                  ),
                  LinkPreviewAppChoice(
                    store: AppLinkStore.of(w),
                    appId: app.id,
                    padding: const EdgeInsets.only(top: RaftSpace.x4),
                  ),
                  if (!awaitingApproval) ?permissions,
                ],
              ),
            ],
            footer: [
              RaftConnectedAppButton(
                label: tr('Close'),
                variant: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.lg,
                onPressed: close,
              ),
            ],
          );
        },
      ),
    );
  }

  void showUpdates() {
    final waiting = projection.installed.where(_awaitsApproval).firstOrNull;
    selectTab(RaftConnectedAppsTab.installed);
    _clearFilters();
    if (waiting != null) unawaited(openInstalled(waiting));
  }

  void _clearFilters() {
    search.clear();
    category = listingType = 'all';
    filterListings();
  }

  bool _awaitsApproval(_InstalledApp app) =>
      app.source['permissionApprovalRequired'] == true ||
      marketplace.any(
        (row) =>
            row['id'] == app.id && row['permissionApprovalRequired'] == true,
      );

  void _updateBot(String id, Map<String, dynamic> bot) {
    if (!mounted) return;
    Map<String, dynamic> update(Map<String, dynamic> app) =>
        app['id'] == id ? {...app, 'bot': bot} : app;
    setState(() {
      apps = apps.map(update).toList();
      marketplace = marketplace.map(update).toList();
      listingPage.rows.updateAll((_, row) {
        final app = row['app'];
        return app is Map<String, dynamic> && app['id'] == id
            ? {...row, 'app': update(app)}
            : row;
      });
    });
    saveSnapshot();
  }

  /// The marketplace / installed / registered projection of
  /// IntegrationsSection.
  ({
    List<Map<String, dynamic>> listings,
    List<_InstalledApp> entries,
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
    final entries = [
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
          if (app['privateShared'] != true &&
              (app['serverId'] != w.server?.id ||
                  (app['humanMarketplaceVisible'] == true &&
                      const {
                        'published',
                        'unpublish_requested',
                      }.contains(app['publishStatus']))))
            app,
      ],
      entries: entries,
      installed: [
        for (final app in entries)
          if (!app.editable || app.source['installationId'] != null) app,
      ],
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
    if (widget.standalone) return section(context, tab, scrollable: true);
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
          onChanged: selectTab,
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
    final installedBots = {
      for (final app in p.installed) app.id: managementMap(app.source['bot']),
    };
    final updateCount = p.installed.where(_awaitsApproval).length;
    final query = search.text.trim().toLowerCase();
    final narrowed =
        query.isNotEmpty || category != 'all' || listingType != 'all';
    String byline(
      Map<String, dynamic> app,
    ) => raftFormat(context, '{category} · by {developer}', {
      'category': tr(
        integrationCategoryDisplay(integrationCategoryLabel(app['category'])),
      ),
      'developer':
          '${app['publisherServerName'] ?? app['publisherName'] ?? tr('Third-party developer')}',
    });
    RaftMarketplaceAppTile appTile(
      String id,
      Map<String, dynamic> app, {
      String? recommendation,
    }) {
      final installed = app['installedAt'] != null;
      final bot = installedBots[id];
      return RaftMarketplaceAppTile(
        id: id,
        name: '${app['name'] ?? ''}',
        initials: integrationInitials('${app['name'] ?? app['clientId']}'),
        logoUrl: app['logoUrl'] as String?,
        byline: recommendation ?? byline(app),
        botAction:
            installed && recommendation == null && bot?['grant'] == 'pending'
            ? ConnectedAppBot(
                key: ValueKey(('marketplace-bot', id)),
                workspace: w,
                clientId: id,
                appName: '${app['name'] ?? ''}',
                offer: bot!,
                marketplaceHint: true,
                onChanged: (bot) => _updateBot(id, bot),
                onViewProfile: (_) {},
              )
            : null,
        description: recommendation == null
            ? app['description'] as String?
            : null,
        badge: _installBadge(context, app['marketplaceInstallBadge']),
        state: installed
            ? RaftMarketplaceAppState.installed
            : canManage
            ? RaftMarketplaceAppState.install
            : RaftMarketplaceAppState.available,
        stateLabel: tr(
          installed
              ? 'Installed'
              : canManage
              ? 'Install'
              : 'Available',
        ),
        onOpen: () => openListing(app),
      );
    }

    final visibleListings = listingPage.legacy
        ? [
            for (final app in p.listings)
              if (matches(query, '${app['name'] ?? ''}', app['category'], [
                app['description'],
                app['publisherServerName'] ?? app['publisherName'],
                app['clientId'],
              ]))
                {'id': app['id'], 'kind': 'app', 'app': app},
          ]
        : listingPage.rows.values;
    final listings = [
      for (final row in visibleListings)
        if (row['kind'] == 'mcp')
          RaftMarketplaceAppTile(
            id: row['id'] as String,
            name: '${row['name'] ?? ''}',
            initials: integrationInitials('${row['name'] ?? ''}'),
            logoUrl: row['logoUrl'] as String?,
            byline:
                '${tr(integrationCategoryDisplay(integrationCategoryLabel(row['category'])))} · ${tr('Maintained by Raft')}',
            description: row['description'] as String?,
            badge: RaftConnectedAppBadge.outline(tr('MCP')),
            state: row['installed'] == true
                ? RaftMarketplaceAppState.installed
                : canManage
                ? RaftMarketplaceAppState.install
                : RaftMarketplaceAppState.available,
            stateLabel: tr(
              row['installed'] == true
                  ? 'Installed'
                  : canManage
                  ? 'Install'
                  : 'Available',
            ),
            onOpen: canManage && !busy && row['installed'] != true
                ? () => _installMcpTemplate(row)
                : null,
          )
        else if (row case {'app': final Map<String, dynamic> app})
          if (app['id'] case final String id) appTile(id, app),
    ];
    final recommended =
        widget.standalone &&
            shownTab == RaftConnectedAppsTab.installed &&
            !loading &&
            error == null &&
            !narrowed
        ? p.listings
              .where(
                (app) =>
                    app['clientId'] == 'stamp' &&
                    app['official'] == true &&
                    app['installedAt'] == null,
              )
              .firstOrNull
        : null;
    final installedRows = [
      for (final app in p.installed)
        if (listingType != 'mcp' &&
            matches(query, app.name, app.category, [
              app.source['description'],
              app.developer,
              app.source['clientId'],
            ]))
          RaftConnectedAppRow(
            id: app.id,
            name: app.name,
            initials: integrationInitials(app.name),
            logoUrl: app.logoUrl,
            meta: app.editable
                ? '${tr(integrationCategoryDisplay(integrationCategoryLabel(app.category)))} · ${app.developer}'
                : byline(app.source),
            badges: [
              ?_distributionBadge(
                context,
                app.source['publishStatus'] as String?,
              ),
              if (app.privateShared)
                RaftConnectedAppBadge.outline(tr('Shared')),
              if (app.editable)
                RaftConnectedAppBadge.success(tr('This server')),
              if (_awaitsApproval(app))
                RaftConnectedAppBadge.warning(tr('Permission update')),
            ],
            description: app.source['description'] as String?,
            homepageUrl: app.source['homepageUrl'] as String?,
            homepageLabel: integrationDomain(app.source['homepageUrl']),
            onOpenHomepage: _homepageAction(app.source),
            needsAdminReview:
                canManage &&
                (app.source['needsAdminReview'] == true ||
                    marketplace.any(
                      (row) =>
                          row['id'] == app.id &&
                          row['needsAdminReview'] == true,
                    )),
            onOpenName: () => openInstalled(app),
            onReviewPermissions: canManage && _awaitsApproval(app)
                ? () => openInstalled(app)
                : null,
            actionLabel: !canManage
                ? null
                : app.editable
                ? tr('Edit')
                : savingId == app.id
                ? tr('Uninstalling...')
                : tr('Uninstall'),
            actionGlyph: app.editable ? RaftGlyph.pencil : null,
            onAction: !canManage || savingId == app.id
                ? null
                : app.editable
                ? () => openEditor(app.source)
                : () => confirmUninstall(app.source),
          ),
      for (final app in mcpApps)
        if (app case {'id': final String id, 'name': final String name}
            when listingType != 'app' &&
                matches(query, name, app['category'] as String?, [
                  app['description'],
                  app['homepageUrl'],
                ]))
          RaftConnectedAppRow(
            id: 'mcp-$id',
            name: name,
            initials: integrationInitials(name),
            logoUrl: app['logoUrl'] as String?,
            meta:
                '${tr(integrationCategoryDisplay(integrationCategoryLabel(app['category'])))} · ${tr(managementMap(app['source'])['maintainedByRaft'] == true ? 'Maintained by Raft' : 'Custom')}',
            badges: [
              RaftConnectedAppBadge.outline(tr('MCP')),
              RaftConnectedAppBadge.outline(tr('Private')),
            ],
            description: app['description'] as String?,
            homepageUrl: app['homepageUrl'] as String?,
            homepageLabel: integrationDomain(app['homepageUrl']),
            onOpenHomepage: _homepageAction(app),
            onOpenName: canManage ? () => _openMcpEditor(id) : null,
            actionLabel: canManage ? tr('Edit') : null,
            actionGlyph: RaftGlyph.pencil,
            onAction: canManage ? () => _openMcpEditor(id) : null,
          ),
    ];
    final registeredRows = [
      for (final app in p.registered)
        if (listingType != 'mcp' &&
            matches(query, '${app['name'] ?? ''}', app['category'], [
              app['description'],
              app['clientId'],
            ]))
          RaftConnectedAppRow(
            id: '${app['id']}',
            name: '${app['name'] ?? ''}',
            initials: integrationInitials('${app['name'] ?? app['clientId']}'),
            logoUrl: app['logoUrl'] as String?,
            meta: tr(
              integrationCategoryDisplay(
                integrationCategoryLabel(app['category']),
              ),
            ),
            badges: [
              ?_distributionBadge(context, app['publishStatus'] as String?),
            ],
            description: app['description'] as String?,
            statusHint: _statusHint(app['publishStatus'] as String?) == null
                ? null
                : tr(_statusHint(app['publishStatus'] as String?)!),
            homepageUrl: app['homepageUrl'] as String?,
            homepageLabel: integrationDomain(app['homepageUrl']),
            onOpenHomepage: _homepageAction(app),
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
    final emptyDetail = cold || error != null
        ? null
        : switch (shownTab) {
            RaftConnectedAppsTab.marketplace
                when !narrowed &&
                    listingPage.loaded &&
                    !listingPage.failed &&
                    listings.isEmpty =>
              tr('Apps appear here once Raft has reviewed them.'),
            RaftConnectedAppsTab.installed
                when p.installed.isEmpty && mcpApps.isEmpty =>
              tr(
                canManage
                    ? 'Install one from the Marketplace, or add your own with Add App.'
                    : 'Server owners and admins install apps from the Marketplace.',
              ),
            RaftConnectedAppsTab.myApps when p.registered.isEmpty => tr(
              canManage
                  ? 'Create a Raft App with Add App to build your own for this server.'
                  : 'Raft Apps this server builds appear here.',
            ),
            _ => null,
          };
    final empty = cold || error != null
        ? null
        : switch (shownTab) {
            RaftConnectedAppsTab.marketplace
                when listingPage.loaded &&
                    !listingPage.failed &&
                    listings.isEmpty =>
              tr(
                emptyDetail == null
                    ? 'No marketplace apps match this view'
                    : 'No apps in the Marketplace yet',
              ),
            RaftConnectedAppsTab.installed
                when p.installed.isEmpty && mcpApps.isEmpty =>
              tr('No apps installed yet'),
            RaftConnectedAppsTab.installed when installedRows.isEmpty => tr(
              'No installed apps match this view',
            ),
            RaftConnectedAppsTab.myApps when registeredRows.isEmpty =>
              p.registered.isEmpty
                  ? tr('No Raft Apps yet')
                  : tr('No Raft Apps match this view'),
            _ => null,
          };
    final actionError = appActionNotice.message;
    return RaftConnectedAppsSection(
      standalone: widget.standalone,
      scrollable: scrollable,
      onRetry: actionError == null ? _refreshApps : null,
      announceRetry: hasAcceptedData,
      onRefresh: widget.standalone ? _refreshApps : null,
      typeFilter: _toolbarFilter(
        'apps-filter-type',
        RaftGlyph.shapes,
        listingType,
        const [('all', 'All types'), ('app', 'Raft apps'), ('mcp', 'MCP apps')],
        (type) => listingType = type,
        20,
      ),
      sortFilter: shownTab == RaftConnectedAppsTab.marketplace
          ? _toolbarFilter(
              'apps-filter-sort',
              RaftGlyph.arrowDownUp,
              listingSort,
              const [
                ('installs', 'Most installed'),
                ('published', 'Newest'),
                ('name', 'Name'),
              ],
              (sort) => listingSort = sort,
              10,
            )
          : null,
      onClearFilters: narrowed ? _clearFilters : null,
      onBrowseMarketplace:
          canManage &&
              shownTab == RaftConnectedAppsTab.installed &&
              p.installed.isEmpty &&
              mcpApps.isEmpty
          ? () {
              _clearFilters();
              selectTab(RaftConnectedAppsTab.marketplace);
            }
          : null,
      adminNote: canManage
          ? null
          : tr(
              'Only server owners and admins can install, edit, or remove apps.',
            ),
      loading: cold,
      marketplaceLoading: !listingPage.loaded && !listingPage.failed,
      notice: updateCount == 0 && !botLinkNotice.isActive
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: RaftSpace.x4,
              children: [
                if (updateCount > 0)
                  RaftBanner(
                    live: false,
                    size: RaftBannerRecipeSize.sm,
                    description: raftFormat(
                      context,
                      canManage
                          ? updateCount == 1
                                ? '{count} installed app has new permissions awaiting your review.'
                                : '{count} installed apps have new permissions awaiting your review.'
                          : updateCount == 1
                          ? '{count} installed app needs an administrator to approve new permissions.'
                          : '{count} installed apps need an administrator to approve new permissions.',
                      {'count': updateCount},
                    ),
                    action: RaftSettingsRecipeButton(
                      label: tr('View updates'),
                      variant: RaftButtonRecipeVariant.outline,
                      onPressed: showUpdates,
                    ),
                  ),
                if (botLinkNotice.message case final message?)
                  RaftBanner(
                    key: const ValueKey(
                      'connected-apps-bot-link-not-installed',
                    ),
                    description: tr(message),
                    status: RaftBannerRecipeStatus.info,
                    size: RaftBannerRecipeSize.sm,
                    closeLabel: tr('Close'),
                    onClose: () => setState(botLinkNotice.clear),
                  ),
              ],
            ),
      onRegister: canManage ? openEditor : null,
      onRegisterMcp: canManage ? _openMcpEditor : null,
      tab: shownTab,
      counts: (
        marketplace: widget.standalone ? marketplaceTotal : null,
        installed: p.installed.length + mcpApps.length,
        myApps: p.registered.length,
      ),
      onTab: selectTab,
      searchController: search,
      onSearch: (_) => filterListings(debounce: true),
      category: category,
      categories: [
        ('all', tr('All categories')),
        for (final c in integrationCategories)
          (c, tr(integrationCategoryDisplay(c))),
      ],
      onCategory: (next) {
        category = next;
        filterListings();
      },
      marketplaceFooter:
          listingPage.legacy ||
              emptyDetail != null ||
              (widget.standalone && !listingPage.loaded && !listingPage.failed)
          ? null
          : ConnectedAppMarketplaceFooter(
              page: listingPage,
              retry: _loadListings,
              loadMore: () => _loadListings(next: true),
              standalone: widget.standalone,
            ),
      installedWarning: mcpFailed
          ? RaftBanner(
              description: tr("Couldn't load MCP Apps."),
              size: RaftBannerRecipeSize.sm,
            )
          : null,
      installedFooter: LinkPreviewConsents(
        key: ValueKey(('link-preview-consents', authority)),
        workspace: w,
      ),
      layout: layout,
      onLayout: setLayout,
      error: actionError ?? error,
      marketplace: listings,
      recommendation: recommended != null && recommended['id'] is String
          ? appTile(
              recommended['id'] as String,
              recommended,
              recommendation: raftTextZh(
                context,
                'Connect GitHub: agents push code and open pull requests; you review and merge.',
                '连接 GitHub：Agent 推代码、开 PR，你来审批和合并。',
              ),
            )
          : null,
      rows: shownTab == RaftConnectedAppsTab.installed
          ? installedRows
          : registeredRows,
      emptyMessage: empty,
      emptyDetail: emptyDetail,
      myAppsIntro: tr(
        canManage
            ? 'Raft Apps this server builds. Edit one to change its details, get its client secret or request Marketplace review.'
            : 'Raft Apps this server builds. Only server owners and admins can change them.',
      ),
      secretReveal: canManage && !editorOpen ? secretReveal() : null,
      reviewNote: cold
          ? null
          : tr(
              'Raft reviews every third-party listing before it appears in the marketplace.',
            ),
    );
  }

  RaftFitSelect<String> _toolbarFilter(
    String key,
    RaftGlyph glyph,
    String selected,
    List<(String, String)> choices,
    ValueChanged<String> onSelect,
    int order,
  ) => RaftFitSelect<String>(
    key: ValueKey(key),
    label: _filterTitle(
      choices.firstWhere((choice) => choice.$1 == selected).$2,
    ),
    glyph: glyph,
    applied: selected != choices.first.$1,
    labelOrder: order,
    selection: selected,
    onChanged: (value) {
      if (value == selected) return;
      onSelect(value);
      filterListings();
    },
    items: [
      for (final (value, title) in choices)
        RaftSelectItem(value: value, label: _filterTitle(title)),
    ],
  );

  String _filterTitle(String title) => title == 'Newest'
      ? raftTextZh(context, 'Newest', '最新上架')
      : raftText(context, title);
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
    required this.service,
    required this.canManage,
    required this.topInset,
    required this.groupLabel,
    required this.onError,
    required this.onUpdated,
  });
  final WorkspaceController controller;
  final String clientId;
  final String? service;
  final bool canManage;
  final double topInset;
  final String Function(String group) groupLabel;
  final ValueChanged<String?> onError;
  final Future<void> Function() onUpdated;
  @override
  State<_InstalledAppPermissions> createState() =>
      _InstalledAppPermissionsState();
}

class _InstalledAppPermissionsState extends State<_InstalledAppPermissions> {
  Map<String, dynamic>? state;
  bool textConsent = false;
  bool loading = true, saving = false;
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
    textConsent =
        readPageSnapshot(widget.controller, _snapshotKey)?['textConsent'] ==
        true;
    loading = state == null;
    load();
  }

  Future<void> load() async {
    final identity = pageIdentity(widget.controller);
    try {
      final data = managementMap(
        await Future.sync(() => widget.controller.client.get(path)),
      );
      final serverId = widget.controller.server?.id;
      final consent =
          serverId != null &&
          managementMap(data['prompt_text'])['current'] is Map &&
          await appPromptTextConsent(widget.controller.client, serverId);
      if (!mounted || identity != pageIdentity(widget.controller)) return;
      setState(() {
        state = data;
        textConsent = consent;
        loading = false;
      });
      widget.onError(null);
      writePageSnapshot(widget.controller, _snapshotKey, identity, {
        'state': data,
        'textConsent': consent,
      });
    } catch (e) {
      if (!mounted || identity != pageIdentity(widget.controller)) return;
      setState(() => loading = false);
      widget.onError(
        userErrorText(
          e,
          fallback: 'Failed to load installed App Notifications settings',
          where: 'installed app notifications',
        ),
      );
    }
  }

  Future<void> approve(AppInstallExpectation reviewed) async {
    if (saving) return;
    final identity = pageIdentity(widget.controller);
    setState(() => saving = true);
    widget.onError(null);
    try {
      // Approving the app's update: "Verify it's you" first (Web
      // AppNotificationsControls, reason appAccess).
      await withSecondFactorStepUp(
        context,
        widget.controller.client,
        () => widget.controller.client.request(
          'PUT',
          '$path/grant',
          data: reviewed.body,
        ),
        reason: StepUpReason.appAccess,
      );
      if (!mounted || identity != pageIdentity(widget.controller)) return;
      await load();
      if (mounted && identity == pageIdentity(widget.controller)) {
        await widget.onUpdated();
      }
    } on SecondFactorStepUpCancelled {
      // Nothing changed.
    } catch (e) {
      if (mounted && identity == pageIdentity(widget.controller)) {
        if (isAppPermissionsChanged(e)) await load();
        if (!mounted || identity != pageIdentity(widget.controller)) return;
        widget.onError(
          appInstallRefusal(
                e,
                sentTextRevisionId: reviewed.textRevisionId,
                permissionsChanged: "This app's permissions just changed. Review the current permissions, then confirm again.",
              ) ??
              userErrorText(
                e,
                fallback:
                    'Failed to update installed App Notifications settings',
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
    final inset = EdgeInsets.only(top: widget.topInset);
    if (loading) {
      return Padding(
        padding: inset,
        child: RaftAppPermissionsSummary(
          columns: const [],
          loading: tr('Loading App Notifications...'),
        ),
      );
    }
    final s = state;
    if (s == null) return const SizedBox.shrink();
    List<String> events(Object? raw) => [
      for (final e in managementStrings(raw))
        tr(appNotificationEventLabels[e] ?? e),
    ];
    final approved = managementStrings(s['approved_groups']);
    final newly = [
      for (final g in managementStrings(s['requested_groups']))
        if (!approved.contains(g)) g,
    ];
    final textState = textConsent ? managementMap(s['prompt_text']) : const {};
    final confirmed = ConnectedAppPromptText.read(
      textState['confirmed'],
      service: widget.service,
    );
    final current = ConnectedAppPromptText.read(
      textState['current'],
      service: widget.service,
    );
    final needsText =
        textState['confirmation_required'] == true && current != null;
    final needsPermissions = s['approval_required'] == true;
    const promptChangeNotice =
        'This app changed the text it adds to agent prompts. Until an admin confirms it, agents keep using the last confirmed version. Confirmed text reaches each agent the next time it starts.';
    final reviewed = AppInstallExpectation(
      scopes: managementStrings(s['requested_scopes']),
      groups: managementStrings(s['requested_groups']),
      textRevisionId: managementMap(textState['current'])['id'] as String?,
    );
    final permissions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftAppPermissionsSummary(
          badge: managementStrings(s['effective_groups']).isNotEmpty
              ? RaftConnectedAppBadge.success(tr('Enabled'))
              : RaftConnectedAppBadge.muted(tr('Disabled')),
          reviewBadge: s['app_review_pending'] == true
              ? RaftConnectedAppBadge.warning(tr('App Review pending'))
              : null,
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
        if (needsPermissions || needsText) ...[
          const SizedBox(height: RaftSpace.x3),
          RaftBanner(
            live: false,
            size: RaftBannerRecipeSize.sm,
            descriptionBuilder: (style) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: RaftSpace.x2,
              children: [
                if (needsPermissions) ...[
                  Text(
                    tr(
                      'This app requests new access. Review it before approving the update; until then it keeps the access you approved.',
                    ),
                    style: style,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr('Approving the update approves all of this:'),
                        style: style,
                      ),
                      ConnectedAppPermissionSet(
                        permissions: reviewed,
                        newScopes: managementStrings(s['new_scopes']),
                        newGroups: newly,
                      ),
                    ],
                  ),
                ],
                if (needsText) ...[
                  Text(tr(promptChangeNotice), style: style),
                  if (needsPermissions)
                    Text(
                      tr('Approve Update also confirms this text.'),
                      style: style,
                    ),
                  ConnectedAppPromptComparison(
                    before: confirmed,
                    after: current,
                    beforeTitle: 'Agents use now',
                    afterTitle: 'Pending text',
                  ),
                ],
              ],
            ),
            action: widget.canManage
                ? RaftButton(
                    label: tr(saving ? 'Approving...' : 'Approve update'),
                    tone: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.md,
                    onPressed: saving ? null : () => approve(reviewed),
                  )
                : null,
          ),
        ] else if (confirmed != null) ...[
          const SizedBox(height: RaftSpace.x3),
          ConnectedAppPromptTextBlock(
            title: 'Text added to agent prompts',
            text: confirmed,
          ),
        ],
      ],
    );
    return Padding(padding: inset, child: permissions);
  }
}

List<String> parseIntegrationScopes(String input) =>
    input.split(RegExp(r'[,\s]+')).where((v) => v.isNotEmpty).toSet().toList();
