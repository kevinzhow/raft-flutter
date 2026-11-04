import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'app_setup.dart';
import 'human_login_sheet.dart' show RequestedAppScopes;
import 'integrations_views.dart' show integrationDomain;
import 'private_app_invite.dart';

/// Re-enters the root's navigation owner only after resolving a current
/// membership. The callback returns null after the root has been disposed.
Future<void> openPrivateAppSettings(
  WorkspaceController? Function() currentWorkspace,
  String serverId,
  Future<void> Function(Uri) navigate, {
  required bool Function() current,
}) async {
  if (!current()) return;
  final w = currentWorkspace();
  if (w == null) throw const RaftApiException('Your server list is not ready.');
  if (!w.servers.any((s) => s.id == serverId)) await w.loadServerDirectory();
  if (!current() || !identical(currentWorkspace(), w)) return;
  final server = w.servers.where((s) => s.id == serverId).firstOrNull;
  if (server == null) {
    throw const RaftApiException('This server is no longer available.');
  }
  await navigate(
    Uri(path: '/s/${server.string('slug')}/settings/integrations'),
  );
}

/// Authenticated IntegrationInvitePage. All choices come from the server's
/// manageableServers; selecting a choice does not switch a workspace or write.
class PrivateAppInviteView extends StatefulWidget {
  const PrivateAppInviteView({
    super.key,
    required this.client,
    required this.link,
    required this.onClose,
    required this.onSettings,
  });
  final RaftClient client;
  final PrivateAppInviteLink link;
  final VoidCallback onClose;
  final Future<void> Function(String serverId, bool Function() current)
  onSettings;
  @override
  State<PrivateAppInviteView> createState() => _PrivateAppInviteState();
}

class _PrivateAppInviteState extends State<PrivateAppInviteView> {
  late final owner = widget.client;
  late final token = widget.link.identity;
  late final principal = owner.user?.id;
  late final generation = owner.authenticationGeneration;
  PrivateAppInvite? invite;
  String? selected;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared on reload, install, target change and membership refresh. The root keys this view by token/account/generation, and late completions are fenced before setting it.
  String? error;
  bool loading = true, installing = false, closing = false;
  Object? activeInstall;
  int request = 0;
  StreamSubscription<RaftEvent>? events;
  bool get live =>
      mounted &&
      !closing &&
      identical(owner, widget.client) &&
      token == widget.link.identity &&
      principal != null &&
      widget.client.user?.id == principal &&
      widget.client.authenticationGeneration == generation;
  String get path =>
      '/integration-invites/${Uri.encodeComponent(widget.link.token)}';
  PrivateAppInstallServer? get server =>
      invite?.servers.where((s) => s.id == selected).firstOrNull;

  @override
  void initState() {
    super.initState();
    unawaited(load());
    events = widget.client.events.listen((event) {
      final payload = event.payload;
      if (event.name == 'server:deleted' ||
          event.name == 'server:membership-removed' ||
          (event.name == 'server:member-updated' &&
              payload is Map &&
              payload['userId'] == principal)) {
        unawaited(load());
      }
    });
  }

  @override
  void dispose() {
    unawaited(events?.cancel());
    super.dispose();
  }

  Future<void> load() async {
    if (!live) return;
    final ticket = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = PrivateAppInvite.parse(
        await widget.client.getForAccount(path),
      );
      if (!live || ticket != request) return;
      setState(() {
        invite = result;
        if (!result.servers.any((s) => s.id == selected)) {
          selected =
              result.servers.where((s) => !s.installed).firstOrNull?.id ??
              result.servers.firstOrNull?.id;
        }
      });
    } catch (e) {
      if (live && ticket == request) {
        setState(() {
          invite = null;
          selected = null;
          error = userErrorText(
            e,
            fallback: 'Private app invite not found',
            where: 'private app invite',
          );
        });
      }
    } finally {
      if (live && ticket == request) setState(() => loading = false);
    }
  }

  Future<void> install() async {
    final target = server;
    if (!live || loading || installing || target == null || target.installed) {
      return;
    }
    final ticket = ++request;
    final operation = activeInstall = Object();
    setState(() {
      installing = true;
      error = null;
    });
    try {
      final result = PrivateAppInvite.parse(
        await widget.client.postForServer(
          target.id,
          '$path/install',
          data: {'serverId': target.id},
        ),
      );
      if (!live || ticket != request) return;
      if (!result.servers.any((s) => s.id == target.id && s.installed)) {
        throw const FormatException(
          'Private app installation was not confirmed',
        );
      }
      setState(() => invite = result);
    } catch (e) {
      if (live && ticket == request) {
        setState(
          () => error = userErrorText(
            e,
            fallback: 'Failed to install private app',
            where: 'private app install',
          ),
        );
      }
    } finally {
      if (mounted && identical(activeInstall, operation)) {
        activeInstall = null;
        setState(() => installing = false);
        if (live && ticket != request) unawaited(load());
      }
    }
  }

  Future<void> openSettings() async {
    final target = server;
    if (!live || target?.installed != true) return;
    final ticket = ++request;
    bool current() => live && ticket == request && server?.id == target!.id;
    try {
      await widget.onSettings(target!.id, current);
    } catch (e) {
      if (current()) {
        setState(
          () => error = userErrorText(
            e,
            fallback: 'Could not open app settings.',
            where: 'private app settings',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = live && !loading ? invite : null;
    String value(String key, String fallback) => data?.app[key] is String
        ? data!.app[key] as String
        : raftText(context, fallback);
    final expiry = data?.expiresAt == null
        ? null
        : DateTime.tryParse(data!.expiresAt!);
    return RaftPrivateAppInvitePage(
      loading: loading,
      error: error,
      name: data?.name,
      description: data?.app['description'] as String?,
      byline:
          '${raftText(context, 'Shared by')} ${value('publisherName', 'an app publisher')} '
          '${raftText(context, 'from')} ${value('sourceServerName', 'another server')}',
      details: data == null
          ? const []
          : [
              ('Client ID', value('clientId', 'Not configured')),
              (
                'Homepage',
                integrationDomain(data.app['homepageUrl']) ??
                    raftText(context, 'Not configured'),
              ),
              (
                'Callback',
                integrationDomain(data.app['returnUrl']) ??
                    raftText(context, 'Not configured'),
              ),
              (
                'Invite expiry',
                expiry == null
                    ? raftText(context, 'No expiry')
                    : MaterialLocalizations.of(context)
                          .formatCompactDate(expiry.toLocal()),
              ),
            ],
      scopes: data == null
          ? null
          : RequestedAppScopes(scopes: data.scopes, collapseIdentity: true),
      setup: data == null || !hasAppSetup(data.app)
          ? null
          : server?.installed == true
          ? AppSetupPanel.forServer(
              client: widget.client,
              serverId: server!.id,
              clientId: data.id,
            )
          : RaftAppSetupRequirement(
              domain: appSetupDomain(data.app['setupUrl']) ?? '',
              description: data.app['setupDescription'] as String?,
            ),
      servers: [
        for (final s in data?.servers ?? <PrivateAppInstallServer>[])
          RaftSelectItem(
            value: s.id,
            label:
                '${s.name}${s.installed ? raftText(context, ' (installed)') : ''}',
          ),
      ],
      selectedServer: selected,
      installed: server?.installed == true,
      installedServerName: server?.name,
      installing: installing,
      onClose: () {
        closing = true;
        request++;
        widget.onClose();
      },
      onRetry: () => unawaited(load()),
      onServer: (id) {
        if (!live || installing || !invite!.servers.any((s) => s.id == id)) {
          return;
        }
        setState(() {
          request++;
          selected = id;
          error = null;
        });
      },
      onInstall: () => unawaited(install()),
      onSettings: () => unawaited(openSettings()),
    );
  }
}
