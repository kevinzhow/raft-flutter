import 'package:raft_client/raft_client.dart';

/// A display projection of the server's sidebar preferences. Activity values
/// come from channel projections or retained server messages, never local time.
class SidebarEntry {
  const SidebarEntry({
    required this.key,
    required this.label,
    this.channel,
    this.agent,
  });
  final String key, label;
  final RaftChannel? channel;
  final Map<String, dynamic>? agent;
}

class SidebarGroup {
  const SidebarGroup(this.id, this.label, this.entries, {this.custom = false});
  final String id, label;
  final List<SidebarEntry> entries;
  final bool custom;
}

List<SidebarGroup> projectSidebar({
  required List<RaftChannel> channels,
  required List<RaftChannel> dms,
  required Map<String, dynamic> preferences,
  List<Map<String, dynamic>> agents = const [],
  Map<String, DateTime> activity = const {},
}) {
  final visibleChannels = channels.where((c) => !c.archived).toList();
  final byChannel = {
    for (final c in [...visibleChannels, ...dms]) c.id: c,
  };
  final byAgent = {for (final a in agents) '${a['id']}': a};
  final agentDms = {
    for (final c in dms)
      if (c.string('peerType') == 'agent') c.string('peerId'): c,
  };
  final humanDms = {
    for (final c in dms)
      if (c.string('peerType') != 'agent') c.string('peerId'): c,
  };
  final claimedChannels = <String>{}, claimedAgents = <String>{};
  SidebarEntry channel(RaftChannel c) => SidebarEntry(
    key: 'channel:${c.id}',
    label: c.type == 'dm'
        ? c.string('peerDisplayName', c.string('peerName', c.name))
        : c.name,
    channel: c,
  );
  SidebarEntry? agent(String id) {
    final a = byAgent[id], dm = agentDms[id];
    if (a == null) return dm == null ? null : channel(dm);
    return SidebarEntry(
      key: 'agent:$id',
      label: '${a['displayName'] ?? a['name'] ?? id}',
      channel: dm,
      agent: a,
    );
  }

  void claim(SidebarEntry entry) {
    if (entry.channel != null) claimedChannels.add(entry.channel!.id);
    if (entry.agent != null) claimedAgents.add('${entry.agent!['id']}');
  }

  List<Map<String, dynamic>> rows(String key) =>
      (preferences[key] as List? ?? [])
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  void sort(List<SidebarEntry> entries, dynamic mode) {
    if (mode == 'az') {
      entries.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
    } else if (mode == 'recent') {
      DateTime? time(SidebarEntry entry) {
        final c = entry.channel;
        if (c == null) return null;
        final projected = DateTime.tryParse(c.string('lastMessageAt'));
        final retained = activity[c.id];
        if (projected == null) return retained;
        return retained != null && retained.isAfter(projected)
            ? retained
            : projected;
      }

      // Retain manual order for unavailable/equal activity projections.
      final manual = {
        for (var i = 0; i < entries.length; i++) entries[i].key: i,
      };
      entries.sort((a, b) {
        final at = time(a), bt = time(b);
        if (at == null && bt == null) {
          return manual[a.key]!.compareTo(manual[b.key]!);
        }
        if (at == null) return 1;
        if (bt == null) return -1;
        final compared = bt.compareTo(at);
        return compared == 0
            ? manual[a.key]!.compareTo(manual[b.key]!)
            : compared;
      });
    }
  }

  final pinned = <SidebarEntry>[];
  for (final ref in rows('pinned')) {
    final id = '${ref['id']}';
    final entry = switch (ref['kind']) {
      'channel' => byChannel[id] == null ? null : channel(byChannel[id]!),
      'human' => humanDms[id] == null ? null : channel(humanDms[id]!),
      'agent' => agent(id),
      _ => null,
    };
    if (entry == null || pinned.any((e) => e.key == entry.key)) continue;
    pinned.add(entry);
    claim(entry);
  }
  sort(pinned, preferences['pinnedSortMode']);
  final groups = <String, SidebarGroup>{
    'system:pinned': SidebarGroup('system:pinned', 'PINNED', pinned),
  };
  final placements = rows('sectionPlacements')
    ..sort(
      (a, b) => ((a['position'] as num?) ?? 0).compareTo(
        (b['position'] as num?) ?? 0,
      ),
    );
  for (final section in rows('customSections')) {
    final id = '${section['id']}', entries = <SidebarEntry>[];
    for (final placement in placements.where((p) => p['sectionId'] == id)) {
      if (placement['kind'] != 'channel' && placement['kind'] != 'agent') {
        continue;
      }
      final itemId = '${placement['id']}';
      final entry = placement['kind'] == 'agent'
          ? agent(itemId)
          : byChannel[itemId] == null
          ? null
          : channel(byChannel[itemId]!);
      if (entry == null ||
          claimedChannels.contains(entry.channel?.id) ||
          claimedAgents.contains(entry.agent?['id'])) {
        continue;
      }
      entries.add(entry);
      claim(entry);
    }
    sort(entries, section['sortMode']);
    final emoji = '${section['emoji'] ?? ''}'.trim();
    groups[id] = SidebarGroup(
      id,
      '${emoji.isEmpty ? '' : '$emoji '}${section['name'] ?? ''}',
      entries,
      custom: true,
    );
  }
  List<SidebarEntry> ordered(List<RaftChannel> values, String key) {
    final order = (preferences[key] as List? ?? [])
        .whereType<String>()
        .toList();
    final rest = {for (final c in values) c.id: c};
    return [
      for (final id in order)
        if (rest.containsKey(id)) channel(rest.remove(id)!),
      ...rest.values.map(channel),
    ];
  }

  final regular = visibleChannels
      .where((c) => !claimedChannels.contains(c.id))
      .toList();
  final joint = ordered(
    regular.where((c) => c.type == 'joint').toList(),
    'channelOrder',
  );
  final normal = ordered(
    regular.where((c) => c.type != 'joint').toList(),
    'channelOrder',
  );
  final hidden = (preferences['hiddenDmIds'] as List? ?? []).toSet();
  final direct = ordered(
    dms
        .where((c) => !hidden.contains(c.id) && !claimedChannels.contains(c.id))
        .toList(),
    'dmOrder',
  );
  sort(joint, preferences['jointChannelSortMode']);
  sort(normal, preferences['channelSortMode']);
  sort(direct, preferences['dmSortMode']);
  groups['system:joint'] = SidebarGroup(
    'system:joint',
    'JOINT CHANNELS',
    joint,
  );
  groups['system:channels'] = SidebarGroup(
    'system:channels',
    'CHANNELS',
    normal,
  );
  groups['system:dms'] = SidebarGroup('system:dms', 'DIRECT MESSAGES', direct);
  final order = [
    ...(preferences['sectionOrder'] as List? ?? []).whereType<String>(),
    'system:pinned',
    'system:joint',
    'system:channels',
    'system:dms',
    ...rows('customSections').map((s) => '${s['id']}'),
  ];
  final seen = <String>{};
  return [
    for (final id in order)
      if (seen.add(id) && groups.containsKey(id)) groups[id]!,
  ];
}
