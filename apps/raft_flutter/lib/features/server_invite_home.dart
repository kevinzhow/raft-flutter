import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';

import '../platform/local_network_access.dart';
import 'invite_accept_view.dart';

/// Binds the shared server-invite page to its existing API contract. The root
/// keeps account ownership, sign-in and server navigation.
Widget buildServerInviteHome({
  required InviteLink link,
  required bool signedIn,
  required RaftClient Function() api,
  required LocalNetworkAccess network,
  required Future<bool> Function(String) onEnter,
  required VoidCallback onSignIn,
  required VoidCallback onCreateAccount,
  required VoidCallback onClose,
}) {
  return InviteAcceptView(
    key: ValueKey('invite-${link.token}-$signedIn'),
    token: link.token,
    signedIn: signedIn,
    loadInfo: () async {
      final reader = api();
      await network.ensure(reader.origin, request: true);
      return Map<String, dynamic>.from(
        await reader.request(
          'GET',
          '/auth/invite-info',
          query: {'token': link.token},
          authorized: false,
        ),
      );
    },
    accept: (agreementId) async {
      final result = await api().post(
        '/auth/accept-invite',
        data: {'token': link.token, 'agreementId': ?agreementId},
      );
      return InviteJoined(
        '${result['serverId']}',
        '${result['serverName'] ?? ''}',
      );
    },
    onEnter: onEnter,
    onSignIn: onSignIn,
    onCreateAccount: onCreateAccount,
    onGoToRaft: onClose,
  );
}
