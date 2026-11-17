// Delete Account's agent rows (Web features/settings/account/
// accountDeletionAgentGroups.ts, v7): the person's agents, one row per
// computer of theirs they run on, then one row per server for the rest
// (hosted, or on someone else's computer). Built from GET's `agents` (what
// becomes of each) and `computers` (the person's own computers and the agents
// bound to each). Agents that close with their server are not rows here: the
// closing server's row says so.
import 'package:raft_client/raft_client.dart';

typedef AccountDeletionNamed = ({String id, String name});

class AccountDeletionAgentGroup {
  const AccountDeletionAgentGroup({
    required this.key,
    required this.server,
    required this.computer,
    required this.agents,
    required this.owner,
    required this.handedOver,
    required this.hasAssistant,
    required this.othersAgents,
  });

  /// `computer:<id>` or `server:<id>`.
  final String key;
  final AccountDeletionServer server;

  /// The person's computer these agents run on; null for the server's others.
  final AccountDeletionNamed? computer;

  /// The person's agents in the row: handed to the server's owner, or (the
  /// personal assistant) archived.
  final List<AccountDeletionAgent> agents;

  /// Who the handed-over agents go to; null while the person is still the
  /// server's only owner.
  final AccountDeletionNamed? owner;

  /// How many of [agents] are handed over (the rest is the personal assistant).
  final int handedOver;
  final bool hasAssistant;

  /// Other members' agents on this computer (they are Needs action rows).
  final List<AccountDeletionNamed> othersAgents;

  AccountDeletionAgentGroup withOwner(AccountDeletionNamed named) =>
      AccountDeletionAgentGroup(
        key: key,
        server: server,
        computer: computer,
        agents: agents,
        owner: named,
        handedOver: handedOver,
        hasAssistant: hasAssistant,
        othersAgents: othersAgents,
      );
}

int _byName(AccountDeletionNamed a, AccountDeletionNamed b) {
  final byName = a.name.compareTo(b.name);
  return byName != 0 ? byName : a.id.compareTo(b.id);
}

int _byServer(AccountDeletionServer a, AccountDeletionServer b) {
  final byName = a.name.compareTo(b.name);
  return byName != 0 ? byName : a.id.compareTo(b.id);
}

AccountDeletionAgentGroup _group(
  String key,
  AccountDeletionServer server,
  AccountDeletionNamed? computer,
  List<AccountDeletionAgent> agents,
  List<AccountDeletionNamed> others,
) {
  final handed = [
    for (final agent in agents)
      if (agent.outcome == AgentOutcome.transferToOwner) agent,
  ];
  return AccountDeletionAgentGroup(
    key: key,
    server: server,
    computer: computer,
    agents: [...agents]
      ..sort(
        (a, b) => _byName((id: a.id, name: a.name), (id: b.id, name: b.name)),
      ),
    owner: handed.where((a) => a.toUser != null).firstOrNull?.toUser,
    handedOver: handed.length,
    hasAssistant: agents.any(
      (agent) => agent.outcome == AgentOutcome.archivePersonalAssistant,
    ),
    othersAgents: [...others]..sort(_byName),
  );
}

/// Null while GET has not listed the agents (an older server): the page then
/// says it in general terms. [newOwners] names who the person just made an
/// Owner here, by server: GET's `toUser` stays empty until the cleanup picks
/// the owner, so the row says that name instead of "the new Owner".
List<AccountDeletionAgentGroup>? accountDeletionAgentGroups(
  AccountDeletionChecklist? checklist, [
  Map<String, String> newOwners = const {},
]) {
  final all = checklist?.agents;
  if (all == null) return null;
  final kept = {
    for (final agent in all)
      if (agent.outcome != AgentOutcome.closesWithServer) agent.id: agent,
  };
  final placed = <String>{};
  final computers = [...?checklist!.computers]
    ..sort((a, b) {
      final server = _byServer(a.server, b.server);
      return server != 0
          ? server
          : _byName((id: a.id, name: a.name), (id: b.id, name: b.name));
    });

  final groups = <AccountDeletionAgentGroup>[];
  for (final computer in computers) {
    final own = <AccountDeletionAgent>[];
    for (final bound in computer.agents) {
      final agent = bound.ownedByMe ? kept[bound.id] : null;
      if (agent != null && !placed.contains(agent.id)) own.add(agent);
    }
    final others = [
      for (final bound in computer.agents)
        if (!bound.ownedByMe) (id: bound.id, name: bound.name),
    ];
    if (own.isEmpty && others.isEmpty) continue;
    placed.addAll(own.map((agent) => agent.id));
    groups.add(
      _group(
        'computer:${computer.id}',
        computer.server,
        (id: computer.id, name: computer.name),
        own,
        others,
      ),
    );
  }

  final byServer = <String, List<AccountDeletionAgent>>{};
  for (final agent in kept.values) {
    if (placed.contains(agent.id)) continue;
    byServer.putIfAbsent(agent.server.id, () => []).add(agent);
  }
  final serverGroups = [
    for (final agents in byServer.values)
      _group(
        'server:${agents.first.server.id}',
        agents.first.server,
        null,
        agents,
        const [],
      ),
  ]..sort((a, b) => _byServer(a.server, b.server));
  return [
    for (final group in [...groups, ...serverGroups])
      if (group.owner == null &&
          group.handedOver > 0 &&
          newOwners.containsKey(group.server.id))
        group.withOwner((id: '', name: newOwners[group.server.id]!))
      else
        group,
  ];
}
