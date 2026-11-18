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

Future<bool> openExternalChannel(
  WorkspaceController? w,
  String serverId,
  String? channelId, {
  bool refreshDirectory = false,
  required bool Function() current,
  required Future<void> Function(RaftRecord, Uri) choose,
}) async {
  if (w == null) return false;
  if ((refreshDirectory ||
          channelId != null ||
          !w.servers.any((server) => server.id == serverId)) &&
      !await w.loadServerDirectory()) {
    return false;
  }
  if (!current()) return false;
  final server = w.servers.where((server) => server.id == serverId).firstOrNull;
  if (server == null) return false;
  await choose(
    server,
    RaftLocation.at(
      serverSlug: server.string('slug'),
      route: channelId == null ? RaftRoute.home : RaftRoute.channel,
      entityId: channelId,
    ).uri,
  );
  return w.server?.id == serverId;
}
