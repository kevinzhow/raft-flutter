// Server v1.24 enterprise SSO enforcement (middleware/auth.ts
// respondSsoRequired, socket handshake SSO_REQUIRED): a Server that requires
// its single sign-on refuses every request of this session. Web leaves for
// that Server's SSO sign-in (utils/ssoSignIn.ts goToServerSsoSignIn); this
// client has no SSO sign-in yet, so instead of failing silently it says what
// the server said and offers the one action the server still accepts:
// signing out (POST /auth/logout is the exempt route).
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

class SsoRequiredPage extends StatelessWidget {
  const SsoRequiredPage(this.client, this.onSignOut, {super.key});

  /// The refused session; [RaftClient.ssoRequired] is the server's own
  /// sentence (`SSO_REQUIRED_TEXT`).
  final RaftClient client;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => RaftAuthResultPage(
    key: const ValueKey('sso-required'),
    title: raftText(context, 'Sign in with SSO'),
    description: raftText(
      context,
      client.ssoRequired ?? RaftClient.ssoRequiredText,
    ),
    gapBeforeButton: RaftSpace.x1,
    buttonLabel: raftText(context, 'Log out'),
    buttonIcon: RaftGlyph.logOut,
    buttonKey: const ValueKey('sso-required-sign-out'),
    onButton: onSignOut,
  );
}
