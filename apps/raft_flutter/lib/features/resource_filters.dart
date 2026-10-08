/// Mounted Web request contracts, pinned to source 26f77ef.
class ResourceSender {
  const ResourceSender(this.id, this.type, this.label, {this.handle = ''});
  final String id, type, label;
  final String handle;
  String get key => '$type:$id';
}

/// TasksPanel filters are local: OR inside each set, AND between sets.
/// Participant kinds are part of identity, even when two tables share an ID.
class TaskResourceFilters {
  final Set<String> channels = {}, creators = {}, assignees = {};
  bool get isEmpty => channels.isEmpty && creators.isEmpty && assignees.isEmpty;
  void clear() {
    channels.clear();
    creators.clear();
    assignees.clear();
  }

  bool matches(Map<String, dynamic> row) {
    if (channels.isNotEmpty && !channels.contains(row['channelId'])) {
      return false;
    }
    if (creators.isNotEmpty &&
        !creators.contains('${row['createdByType']}:${row['createdById']}')) {
      return false;
    }
    if (assignees.isEmpty) return true;
    final id = row['claimedById'], type = row['claimedByType'];
    return id == null || id == '' || type == null || type == ''
        ? assignees.contains('unassigned')
        : assignees.contains('$type:$id');
  }
}

class ResourceFilters {
  String? channelId;
  ResourceSender? sender;
  final Set<String> scopes = {};
  String timeRange = 'any', searchSort = 'relevance', direction = 'desc';
  bool groupByChannel = false;
  bool get hasSearchFilter =>
      channelId != null ||
      sender != null ||
      scopes.isNotEmpty ||
      timeRange != 'any';
  String? get senderType =>
      scopes.contains('humans') == scopes.contains('agents')
      ? null
      : scopes.contains('humans')
      ? 'user'
      : 'agent';
  void selectSender(ResourceSender? value) {
    sender = value;
    if (value != null && senderType != null && senderType != value.type) {
      scopes.remove(value.type == 'user' ? 'agents' : 'humans');
    }
  }

  void toggleScope(String scope) {
    if (!scopes.remove(scope)) scopes.add(scope);
    if (sender != null && senderType != null && senderType != sender!.type) {
      sender = null;
    }
  }

  Map<String, dynamic>? search(String text, {int offset = 0, DateTime? now}) {
    final q = text.trim();
    if (q.isEmpty && !hasSearchFilter) return null;
    final clock = (now ?? DateTime.now()).toLocal();
    final after = switch (timeRange) {
      'today' => DateTime(clock.year, clock.month, clock.day),
      '7d' || '30d' => DateTime(
        clock.year,
        clock.month,
        clock.day - (timeRange == '7d' ? 7 : 30),
        clock.hour,
        clock.minute,
        clock.second,
        clock.millisecond,
      ),
      _ => null,
    };
    String iso(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
      value.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
    return {
      'q': q,
      'limit': 20,
      'offset': offset,
      if (q.isNotEmpty && searchSort == 'recent') 'sort': 'recent',
      if (channelId != null) 'channelId': channelId,
      if (sender != null) 'senderId': sender!.id,
      if (senderType != null) 'senderType': senderType,
      if (scopes.contains('mentioned')) 'mentionTarget': 'self',
      if (after != null) 'after': iso(after),
      if (after != null) 'before': iso(clock),
    };
  }

  Map<String, dynamic> list(
    String text, {
    int offset = 0,
    int limit = 30,
    String? filter,
  }) => {
    'limit': limit,
    'offset': offset,
    'sort': direction,
    if (text.trim().isNotEmpty) 'q': text.trim(),
    if (channelId != null) 'channelId': channelId,
    'filter': ?filter,
  };
}

({String path, Map<String, dynamic> data})? activityMutation(
  Map<String, dynamic> row,
  String action,
) {
  final thread = row['kind'] == 'thread';
  final id = thread ? row['threadChannelId'] : row['channelId'];
  if (id is! String || row['kind'] == 'mention_action') return null;
  if (action == 'follow') {
    final parent = row['parentMessageId'];
    return thread && parent is String
        ? (path: '/channels/threads/follow', data: {'parentMessageId': parent})
        : null;
  }
  if (action == 'unfollow') {
    return thread
        ? (path: '/channels/threads/unfollow', data: {'threadChannelId': id})
        : null;
  }
  if (!['done', 'undone'].contains(action)) return null;
  final data = <String, dynamic>{thread ? 'threadChannelId' : 'channelId': id};
  if (action == 'done' && row.containsKey('doneFrontierSeq')) {
    final seq = row['doneFrontierSeq'];
    if (seq is! String || !RegExp(r'^[1-9][0-9]*$').hasMatch(seq)) return null;
    data.addAll({'throughActivitySeq': seq, 'frontierSpace': 'storage'});
  }
  return (
    path: '/channels/${thread ? 'threads' : 'inbox'}/$action',
    data: data,
  );
}
