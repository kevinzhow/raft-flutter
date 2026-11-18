import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';

import '../data/external_invite_api.dart';
import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import '../platform/local_network_access.dart';
import '../platform/web_billing.dart';
import 'external_invite_approval.dart';
import 'external_invite_page.dart';
import 'external_invite_page_frame.dart';
import 'external_invite_route.dart';
import 'invite_accept_view.dart';
import 'private_app_invite.dart';

bool isStandaloneInvite(Uri location, String origin) =>
    PrivateAppInviteLink.parse(location, origin) != null ||
    ExternalInviteRoute.parse(location, origin) != null;

// A relative invitation token belongs to the coordinator that admitted it.
bool shouldDropStandaloneInvite(Uri location, String origin, String base) =>
    Uri.parse(origin).origin != Uri.parse(base.trim()).origin &&
    isStandaloneInvite(location, origin);

String? inviteLandingId(
  ({ExternalInviteRoute kind, String id})? route,
  String? authMode,
) => switch (route) {
  (kind: ExternalInviteRoute.invitation, :final id) when authMode == null => id,
  _ => null,
};

Widget buildExternalInviteLanding(
  RaftClient reader,
  LocalNetworkAccess network,
  String token,
  ValueChanged<String> onAuth,
) => ExternalInviteLanding(
  key: ValueKey((reader.origin, token)),
  token: token,
  api: ExternalInviteApi((method, path, {data}) async {
    await network.ensure(reader.origin, request: true);
    return reader.request(method, path, authorized: false);
  }),
  onAuth: onAuth,
);

Widget buildExternalInviteHome(
  RaftClient active,
  WorkspaceController? workspace,
  ({ExternalInviteRoute kind, String id}) route, {
  required VoidCallback onSignOut,
  required VoidCallback onClose,
  required OpenExternalChannel open,
}) {
  final key = ValueKey((active, active.authenticationGeneration, route));
  final api = ExternalInviteApi(active.request);
  final account = active.user?.string('email') ?? '';
  Future<bool> upgrade(String serverId) {
    final target = workspace?.servers
        .where((server) => server.id == serverId)
        .firstOrNull;
    if (target == null || target.string('role') != 'owner') {
      return Future.value(false);
    }
    return openWebBilling(
      coordinator: active.origin,
      slug: target.string('slug'),
      gate: WebBillingGate.externalChannelFreeLimit,
    );
  }

  return switch (route.kind) {
    ExternalInviteRoute.approval => ExternalInviteApproval(
      key: key,
      api: api,
      id: route.id,
      account: account,
      onSignOut: onSignOut,
      onOpen: open,
      onUpgrade: upgrade,
    ),
    ExternalInviteRoute.invitation => ExternalInvitePage(
      key: key,
      api: api,
      token: route.id,
      account: account,
      onSignOut: onSignOut,
      onClose: onClose,
      onOpen: open,
      onUpgrade: upgrade,
    ),
  };
}

typedef InviteNavigationState = (
  bool mounted,
  int request,
  InviteLink? link,
  WorkspaceController? workspace,
  RaftClient? client,
);

class InviteNavigation {
  const InviteNavigation(this._read, this._clearInvite, this._chooseServer);

  final InviteNavigationState Function() _read;
  final VoidCallback _clearInvite;
  final Future<void> Function(RaftRecord, {required Uri location})
  _chooseServer;

  Future<bool> enterServer(String serverId) async {
    final state = _read();
    final (_, _, link, workspace, client) = state;
    if (client?.user == null || link == null) return false;
    if (workspace != null) return _open(state, serverId, null);
    _clearInvite();
    return true;
  }

  Future<bool> openChannel(String serverId, String? channelId) =>
      _open(_read(), serverId, channelId);

  Future<bool> _open(
    InviteNavigationState state,
    String serverId,
    String? channelId,
  ) async {
    final (_, request, link, w, client) = state;
    if (w == null) return false;
    if ((link != null ||
            channelId != null ||
            !w.servers.any((server) => server.id == serverId)) &&
        !await w.loadServerDirectory()) {
      return false;
    }
    final (mounted, activeRequest, activeLink, workspace, activeClient) =
        _read();
    if (!mounted ||
        request != activeRequest ||
        !identical(link, activeLink) ||
        !identical(w, workspace) ||
        !identical(client, activeClient)) {
      return false;
    }
    final server = w.servers
        .where((server) => server.id == serverId)
        .firstOrNull;
    if (server == null) return false;
    final location = RaftLocation.at(
      serverSlug: server.string('slug'),
      route: channelId == null ? RaftRoute.home : RaftRoute.channel,
      entityId: channelId,
    ).uri;
    if (link != null) _clearInvite();
    await _chooseServer(server, location: location);
    return w.server?.id == serverId;
  }
}
