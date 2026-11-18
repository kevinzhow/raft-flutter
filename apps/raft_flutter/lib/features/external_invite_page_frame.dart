import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/external_invite_api.dart';

typedef OpenExternalChannel = Future<bool> Function(
  String serverId,
  String? channelId,
);
typedef UpgradeExternalServer = Future<bool> Function(String serverId);

int? externalErrorStatus(Object? error) =>
    error is RaftApiException ? error.status : null;

String? externalErrorCode(Object? error) =>
    error is RaftApiException ? error.code : null;

class ExternalInviteFrame extends StatelessWidget {
  const ExternalInviteFrame({
    super.key,
    required this.title,
    this.description,
    this.account,
    this.actions = const [],
  });

  final String title;
  final String? description, account;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => RaftAuthShell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftAuthIntro(
          title: title,
          description: description,
          children: [
            if (account case final String email when email.isNotEmpty)
              Text(
                raftFormat(context, 'Signed in as {email}', {'email': email}),
              ),
          ],
        ),
        for (final action in actions) ...[
          action,
          if (action != actions.last) const SizedBox(height: RaftSpace.x3),
        ],
      ],
    ),
  );
}

Widget externalInviteButton(
  String label,
  VoidCallback? onPressed, {
  bool primary = false,
  RaftGlyph? icon,
}) => RaftAuthWideButton(
  label: label,
  variant: primary ? RaftControlVariant.accent : RaftControlVariant.outline,
  onPressed: onPressed,
  leading: icon == null ? null : RaftIcon(icon, size: 16),
);

class ExternalInviteLanding extends StatefulWidget {
  const ExternalInviteLanding({
    super.key,
    required this.api,
    required this.token,
    required this.onAuth,
  });

  final ExternalInviteApi api;
  final String token;
  final ValueChanged<String> onAuth;

  @override
  State<ExternalInviteLanding> createState() => _ExternalInviteLandingState();
}

class _ExternalInviteLandingState extends State<ExternalInviteLanding> {
  late Future<ExternalJson> _preview = widget.api.previewLink(widget.token);

  @override
  Widget build(BuildContext context) => FutureBuilder<ExternalJson>(
    future: _preview,
    builder: (context, snapshot) {
      String tr(String text) => raftText(context, text);
      if (snapshot.connectionState != ConnectionState.done) {
        return ExternalInviteFrame(title: tr('Loading invite…'));
      }
      if (snapshot.hasError) {
        final invalid = externalErrorStatus(snapshot.error) == 404;
        return ExternalInviteFrame(
          title: tr(
            invalid
                ? 'This invite link is not valid'
                : "Couldn't load this page",
          ),
          description: tr(
            invalid
                ? 'It may have expired or been withdrawn. Ask the person who invited you for a new one.'
                : 'Check your connection and try again.',
          ),
          actions: [
            invalid
                ? externalInviteButton(
                    tr('Sign in'),
                    () => widget.onAuth('login'),
                  )
                : externalInviteButton(tr('Retry'), () {
                    setState(
                      () => _preview = widget.api.previewLink(widget.token),
                    );
                  }),
          ],
        );
      }
      return ExternalInviteFrame(
        title: tr("You're invited to a channel"),
        description: raftFormat(
          context,
          'This invite was sent to {email}. Sign in or create an account with that address to join the channel and start working with them.',
          {'email': externalString(snapshot.data?['invitedEmailMasked'])},
        ),
        actions: [
          externalInviteButton(
            tr('Sign in'),
            () => widget.onAuth('login'),
            primary: true,
            icon: RaftGlyph.logIn,
          ),
          externalInviteButton(
            tr('Create account'),
            () => widget.onAuth('register'),
            icon: RaftGlyph.userPlus,
          ),
        ],
      );
    },
  );
}

Future<void> openExternalChannelOrToast(
  BuildContext context,
  OpenExternalChannel open,
  String serverId,
  String? channelId,
) async {
  if (!await open(serverId, channelId) && context.mounted) {
    showRaftToast(context, "Couldn't load this page");
  }
}

Future<void> upgradeExternalServerOrToast(
  BuildContext context,
  UpgradeExternalServer upgrade,
  String serverId,
) async {
  if (!await upgrade(serverId) && context.mounted) {
    showRaftToast(context, 'Could not open this address.');
  }
}
