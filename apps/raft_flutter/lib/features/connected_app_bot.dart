import 'dart:async';

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
    this.logo,
    this.fromBotLink = false,
    this.marketplaceHint = false,
    this.pendingPermissions,
    this.onFindAdmin,
  });

  final WorkspaceController workspace;
  final String clientId, appName;
  final Map<String, dynamic> offer;
  final Widget? logo;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final ValueChanged<String> onViewProfile;
  final bool fromBotLink, marketplaceHint;
  final Widget? pendingPermissions;
  final VoidCallback? onFindAdmin;

  @override
  State<ConnectedAppBot> createState() => _ConnectedAppBotState();
}

class _ConnectedAppBotState extends State<ConnectedAppBot> {
  late Map<String, dynamic> bot = widget.offer;
  bool busy = false;
  final _linkedSection = GlobalKey();
  late final failure = CauseNotice(scope: () => pageIdentity(workspace));
  WorkspaceController get workspace => widget.workspace;
  String get handle => '${bot['handle'] ?? ''}';

  @override
  void initState() {
    super.initState();
    if (!widget.fromBotLink) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final section = _linkedSection.currentContext;
      if (section != null) {
        unawaited(Scrollable.ensureVisible(section, alignment: .5));
      }
    });
  }

  Widget _focusLinkedSection(RaftTokens tokens, Widget child) {
    if (!widget.fromBotLink) return child;
    return Focus(
      autofocus: true,
      skipTraversal: true,
      child: Builder(
        key: _linkedSection,
        builder: (context) => Stack(
          key: const ValueKey('connected-app-bot-section'),
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            if (Focus.of(context).hasPrimaryFocus)
              Positioned.fill(
                left: -RaftSpace.x2,
                top: -RaftSpace.x2,
                right: -RaftSpace.x2,
                bottom: -RaftSpace.x2,
                child: RaftOuterRings(
                  radius: RaftRadius.container,
                  rings: [
                    for (final layer in tokens.ui.focusRing.layers)
                      RaftRing(layer.spread, layer.color),
                  ],
                  child: const SizedBox.expand(),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }

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
      if (!mounted || !current()) return;
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
      nestedBackdrop: false,
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
    if (widget.marketplaceHint) {
      return Column(
        crossAxisAlignment: raftBreakpointWidth(context) >= 640
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        spacing: RaftSpace.x2,
        children: [
          if (canManage)
            RaftButton(
              key: const ValueKey('connected-app-bot-marketplace-add'),
              label: raftFormat(context, 'Add @{handle} to {server}', names),
              uiVariant: RaftButtonVariant.standard,
              uiSize: RaftButtonSize.md,
              onPressed: busy ? null : () => update(true),
            )
          else
            RaftCssText(
              raftFormat(
                context,
                'Only an owner or admin can add @{handle}.',
                names,
              ),
              style: tokens.scale(RaftTypeScale.footnote, color: tokens.muted),
            ),
          if (failure.message case final message?) RaftErrorBanner(message),
        ],
      );
    }
    Widget button(
      String label,
      VoidCallback callback, {
      RaftButtonVariant variant = RaftButtonVariant.standard,
    }) => RaftButton(
      label: label,
      uiVariant: variant,
      uiSize: RaftButtonSize.md,
      onPressed: busy ? null : callback,
    );
    Widget capability(RaftGlyph glyph, String label) => Row(
      spacing: RaftSpace.x2,
      children: [
        RaftIcon(glyph, size: 14, color: tokens.ui.foregroundHint),
        Expanded(
          child: RaftCssText(
            label,
            style: tokens.scale(RaftTypeScale.footnote, color: tokens.muted),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x4,
      children: [
        if (canManage && bot['grant'] == 'pending')
          RaftBanner(
            status: RaftBannerRecipeStatus.info,
            size: RaftBannerRecipeSize.sm,
            glyph: RaftGlyph.info,
            live: false,
            description: raftFormat(
              context,
              '{app} can post as @{handle}. It hasn’t joined {server} yet.',
              names,
            ),
            actions: [
              button(
                tr('Don’t add'),
                () => update(false),
                variant: RaftButtonVariant.ghost,
              ),
              button(
                raftFormat(context, 'Add @{handle}', names),
                () => update(true),
              ),
            ],
          ),
        ?widget.pendingPermissions,
        _focusLinkedSection(
          tokens,
          Semantics(
            container: true,
            label: tr('Posts as'),
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: RaftSpace.x2,
              children: [
                RaftSectionEyebrow(tr('Posts as')),
                RaftCssText(
                  tr('Admins of this server decide whether it joins.'),
                  style: tokens.scale(
                    RaftTypeScale.footnote,
                    color: tokens.muted,
                  ),
                ),
                RaftCard(
                  padding: const EdgeInsets.all(RaftSpace.x3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: RaftSpace.x3,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: RaftSpace.x3,
                        children: [
                          ?widget.logo,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: RaftSpace.half,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: RaftSpace.x1_5,
                                  children: [
                                    RaftCssText(
                                      widget.appName,
                                      style: tokens.scale(
                                        RaftTypeScale.subhead,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    RaftBadge(
                                      label: tr('App'),
                                      variant: RaftBadgeRecipeVariant.muted,
                                      appearance:
                                          RaftBadgeRecipeAppearance.soft,
                                    ),
                                  ],
                                ),
                                RaftCssText(
                                  '@$handle',
                                  style: tokens.scale(
                                    RaftTypeScale.monoMeta,
                                    color: tokens.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (granted)
                            RaftBadge(
                              label: tr('Added to server'),
                              variant: RaftBadgeRecipeVariant.success,
                              appearance: RaftBadgeRecipeAppearance.soft,
                            ),
                        ],
                      ),
                      if (!granted) ...[
                        const RaftSeparator(),
                        Column(
                          spacing: RaftSpace.x1_5,
                          children: [
                            capability(
                              RaftGlyph.directMessage,
                              raftFormat(
                                context,
                                'DMs members as {app} (review requests, for example)',
                                names,
                              ),
                            ),
                            capability(
                              RaftGlyph.hash,
                              tr('Posts in channels once it’s invited'),
                            ),
                            capability(
                              RaftGlyph.eyeOff,
                              tr('Can’t see channels it hasn’t joined'),
                            ),
                          ],
                        ),
                      ],
                      if (granted ? agent is String || canManage : canManage)
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
                                  ? button(
                                      tr('Remove'),
                                      confirmRemove,
                                      variant: RaftButtonVariant.ghost,
                                    )
                                  : button(
                                      raftFormat(
                                        context,
                                        'Add @{handle} to {server}',
                                        names,
                                      ),
                                      () => update(true),
                                    ),
                          ],
                        ),
                      if (!canManage && !granted && widget.fromBotLink)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: RaftSpace.x2,
                          children: [
                            RaftCssText(
                              raftFormat(
                                context,
                                'Only an owner or admin can add @{handle}.',
                                names,
                              ),
                              style: tokens.scale(
                                RaftTypeScale.footnote,
                                color: tokens.muted,
                              ),
                            ),
                            if (widget.onFindAdmin case final findAdmin?)
                              button(
                                tr('Find a server admin'),
                                findAdmin,
                                variant: RaftButtonVariant.outline,
                              ),
                          ],
                        ),
                      if (failure.message case final message?)
                        RaftErrorBanner(message),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
