import 'dart:async';

import '../data/feature_flag_client_facts.dart' show RaftFeatureFlags;
import '../data/workspace_controller.dart';
import 'agent_lounge.dart' show AgentLoungeFlag;
import 'external_invite_channel_members.dart' show readExternalChannelFlag;
import 'management_support.dart' show cachedServerFlag, pageIdentity;

class SidebarGroupFacts {
  SidebarGroupFacts._(this.workspace);

  static final _owners = Expando<SidebarGroupFacts>();
  static SidebarGroupFacts of(WorkspaceController workspace) =>
      _owners[workspace] ??= SidebarGroupFacts._(workspace);

  final WorkspaceController workspace;
  final _loungeReads = <String>{};
  String? _authority;

  bool get externalEnabled =>
      cachedServerFlag(workspace, RaftFeatureFlags.externalChannels) == true;

  void sync(String authority) {
    if (workspace.server == null) return;
    if (_authority != authority) {
      _authority = authority;
      _loungeReads.clear();
      final scope = pageIdentity(workspace);
      final before = externalEnabled;
      unawaited(
        readExternalChannelFlag(workspace).then((enabled) {
          if (!workspace.services.isDisposed() &&
              pageIdentity(workspace) == scope &&
              enabled != before) {
            workspace.notifyListeners();
          }
        }),
      );
    }
    if (!AgentLoungeFlag.of(workspace).enabled) return;
    for (final dm in workspace.dms) {
      final summary = dm.lounge;
      if (dm.string('peerType') != 'agent' || summary == null) continue;
      final id = summary.channelId;
      if ((summary.joined || summary.mentionCount > 0) &&
          workspace.channelById(id) == null &&
          _loungeReads.add(id)) {
        unawaited(workspace.refreshChannel(id));
      }
    }
  }
}
