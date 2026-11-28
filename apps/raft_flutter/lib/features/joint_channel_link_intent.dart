import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/feature_flag_client_facts.dart';
import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import 'create_channel_dialog.dart';
import 'create_joint_channel_dialog.dart';
import 'external_invite_channel_members.dart' show readExternalChannelFlag;
import 'management_support.dart' show cachedServerFlag, pageIdentity;

bool isJointChannelLinkIntent(Uri uri) =>
    uri.queryParametersAll['dialog']?.firstOrNull == 'create-joint-channel';

Uri withoutJointChannelLinkIntent(Uri uri) => isJointChannelLinkIntent(uri)
    ? raftRemoveQueryParameters(uri, const {'dialog'})
    : uri;

void showJointChannelLink(
  GlobalKey<NavigatorState> navigator,
  WorkspaceController workspace,
) {
  final overlay = navigator.currentState?.overlay;
  if (overlay != null) {
    unawaited(openJointChannelLinkIntent(overlay.context, workspace));
  }
}

Future<void> openJointChannelLinkIntent(
  BuildContext context,
  WorkspaceController workspace,
) async {
  if (workspace.server == null || !workspace.can('federateChannels')) return;
  final authority = pageIdentity(workspace);
  final external =
      cachedServerFlag(workspace, RaftFeatureFlags.externalChannels) ??
      await readExternalChannelFlag(workspace);
  if (!context.mounted ||
      workspace.services.isDisposed() ||
      pageIdentity(workspace) != authority ||
      !workspace.can('federateChannels')) {
    return;
  }
  if (external) {
    await CreateChannelDialog.show(
      context,
      controller: workspace,
      prefilledVisibility: 'external',
      onCreated: workspace.selectChannel,
    );
  } else {
    await CreateJointChannelDialog.show(
      context,
      controller: workspace,
      onCreated: workspace.selectChannel,
    );
  }
}
