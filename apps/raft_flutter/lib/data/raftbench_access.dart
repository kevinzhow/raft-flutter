import 'package:raft_client/raft_client.dart';

/// Web `raftbench/access.ts`. The server role proves the current membership;
/// staff access is never inferred.
bool canUseRaftBench(String? role) => role == 'owner' || role == 'admin';

/// Web `isRaftBenchChannel`: an active channel the channel API lists for this
/// viewer. Private channels additionally need explicit membership; public and
/// joint channels need not be joined. DMs, threads and archives stay outside.
///
/// `joined` is read literally (`joined === true`), not through
/// [RaftChannel.joined], whose fallbacks (`membership`, DMs) are not the Web
/// store's.
bool isRaftBenchChannel(RaftChannel channel) =>
    !channel.archived &&
    (channel.type == 'channel' ||
        channel.type == 'joint' ||
        (channel.type == 'private' && channel.json['joined'] == true));

/// `raftbench_overview_v0`: default off, enrolled per server by rollout controls.
const raftbenchFlagKey = 'raftbench_overview_v0';
