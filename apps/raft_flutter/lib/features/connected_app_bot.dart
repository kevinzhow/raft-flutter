import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'second_factor_step_up.dart';

class ConnectedAppBot extends StatefulWidget {
  const ConnectedAppBot({
    super.key,
    required this.workspace,
    required this.clientId,
    required this.appName,
    required this.offer,
    required this.onChanged,
    required this.onViewProfile,
    this.fromBotLink = false,
    this.pendingPermissions,
    this.onFindAdmin,
  });

  final WorkspaceController workspace;
  final String clientId, appName;
  final Map<String, dynamic> offer;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final ValueChanged<String> onViewProfile;
  final bool fromBotLink;
  final Widget? pendingPermissions;
  final VoidCallback? onFindAdmin;

  @override
  State<ConnectedAppBot> createState() => _ConnectedAppBotState();
}

class _ConnectedAppBotState extends State<ConnectedAppBot> {
  late Map<String, dynamic> bot = widget.offer;
  bool busy = false;
  late final failure = CauseNotice(scope: () => pageIdentity(workspace));
  WorkspaceController get workspace => widget.workspace;
  String get handle => '${bot['handle'] ?? ''}';

  Future<void> update(bool grant, {bool confirming = false}) async {
    if (busy || !workspace.can('manageIntegrations')) return;
    final identity = pageIdentity(workspace);
    bool current() => mounted && identity == pageIdentity(workspace);
    setState(() {
      busy = true;
      failure.clear();
    });
    try {
      final result = managementMap(
        await withSecondFactorStepUp(
          context,
          workspace.client,
          () => workspace.client.post(
            '/integrations/clients/${widget.clientId}/install/bot',
            data: {'action': grant ? 'grant' : 'revoke'},
          ),
          reason: StepUpReason.appAccess,
        ),
      );
      if (!current()) return;
      final status = result['botGrant'];
      if (status != (grant ? 'granted' : 'revoked')) {
        throw const FormatException('Invalid app bot grant');
      }
      final info = managementMap(result['bot']);
      setState(() {
        bot = {
          'offered': true,
          'grant': status,
          'handle': info['handle'] ?? handle,
          if (grant && info['agentId'] is String) 'agentId': info['agentId'],
        };
      });
      widget.onChanged(bot);
    } on SecondFactorStepUpCancelled {
      return;
    } catch (error) {
      if (!current()) return;
      final message =
          error is RaftApiException &&
              error.details['code'] == 'app_bot_handle_conflict'
          ? raftFormat(
              context,
              '@{handle} is already taken by another agent on this server, so the app didn’t join. Rename that agent, then add @{handle} from Installed apps.',
              {'handle': handle},
            )
          : userErrorText(
              error,
              fallback: 'Failed to update whether the app can post',
              where: 'installed app bot',
            );
      if (confirming) {
        throw StateError(message);
      }
      setState(() => failure.raise(message));
    } finally {
      if (current()) setState(() => busy = false);
    }
  }

  Future<void> confirmRemove() async {
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('connected-app-bot-remove-dialog'),
        title: raftFormat(context, 'Remove @{handle}?', {'handle': handle}),
        message: raftFormat(
          context,
          '@{handle} can no longer post as {app}. You can add it back any time; it returns to the channels it was in.',
          {'handle': handle, 'app': widget.appName},
        ),
        confirmLabel: raftText(context, 'Remove'),
        confirmVariant: RaftButtonRecipeVariant.warning,
        onConfirm: () => update(false, confirming: true),
      ),
      overModal: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (handle.isEmpty || bot['offered'] == false) {
      return const SizedBox.shrink();
    }
    String tr(String value) => raftText(context, value);
    final granted = bot['grant'] == 'granted';
    final agent = bot['agentId'];
    final canManage = workspace.can('manageIntegrations');
    final tokens = RaftTokens.of(context);
    final names = {
      'handle': handle,
      'server': workspace.server?.name ?? '',
      'app': widget.appName,
    };
    Widget button(String label, VoidCallback callback) => RaftButton(
      label: label,
      tone: RaftButtonRecipeVariant.outline,
      onPressed: busy ? null : callback,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x3,
      children: [
        if (canManage && bot['grant'] == 'pending')
          RaftBanner(
            description: raftFormat(
              context,
              '{app} can post as @{handle}. It hasn’t joined {server} yet.',
              names,
            ),
            footer: Wrap(
              spacing: RaftSpace.x2,
              runSpacing: RaftSpace.x2,
              children: [
                button(
                  raftFormat(context, 'Add @{handle}', names),
                  () => update(true),
                ),
                button(tr('Don’t add'), () => update(false)),
              ],
            ),
          ),
        ?widget.pendingPermissions,
        Focus(
          autofocus: widget.fromBotLink,
          skipTraversal: true,
          child: RaftConnectedAppDetailSection(
            title: 'Posts as',
            description: tr('Admins of this server decide whether it joins.'),
            child: RaftCard(
              padding: const EdgeInsets.all(RaftSpace.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: RaftSpace.x2,
                children: [
                  Text(
                    widget.appName,
                    style: tokens.scale(RaftTypeScale.callout),
                  ),
                  Text('@$handle', style: tokens.scale(RaftTypeScale.monoMeta)),
                  if (granted)
                    RaftSettingsRecipeBadge(
                      label: tr('Added to server'),
                      variant: RaftBadgeRecipeVariant.success,
                    )
                  else ...[
                    Text(
                      raftFormat(
                        context,
                        'DMs members as {app} (review requests, for example)',
                        names,
                      ),
                    ),
                    Text(tr('Posts in channels once it’s invited')),
                    Text(tr('Can’t see channels it hasn’t joined')),
                  ],
                  Wrap(
                    spacing: RaftSpace.x2,
                    runSpacing: RaftSpace.x2,
                    children: [
                      if (granted && agent is String)
                        button(
                          tr('View profile'),
                          () => widget.onViewProfile(agent),
                        ),
                      if (canManage)
                        granted
                            ? button(tr('Remove'), confirmRemove)
                            : button(
                                raftFormat(
                                  context,
                                  'Add @{handle} to {server}',
                                  names,
                                ),
                                () => update(true),
                              ),
                      if (!canManage && !granted && widget.fromBotLink) ...[
                        Text(
                          raftFormat(
                            context,
                            'Only an owner or admin can add @{handle}.',
                            names,
                          ),
                        ),
                        if (widget.onFindAdmin case final findAdmin?)
                          button(tr('Find a server admin'), findAdmin),
                      ],
                    ],
                  ),
                  if (failure.message case final message?)
                    RaftErrorBanner(message),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
