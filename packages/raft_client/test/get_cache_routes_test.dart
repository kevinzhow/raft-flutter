import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

import 'support/get_cache_harness.dart';

void main() {
  late GetCacheWire wire;
  late RaftClient client;

  setUp(() async {
    wire = GetCacheWire();
    client = await openGetCacheClient(wire, () => DateTime.utc(2026, 11, 21));
  });

  tearDown(() => client.dispose());

  for (final path in [
    '/channels',
    '/channels/dm',
    '/channels/conversation',
    '/channels/unread',
    '/channels/main/members',
    '/channels/main/agents',
    '/channels/main/files',
    '/channels/inbox',
    '/channels/inbox/done',
    '/channels/inbox/unfollowed',
    '/channels/saved',
    '/channels/threads/followed',
    '/agents',
    '/servers/s1/members',
    '/servers/s1/members/person/profile',
    '/tasks/channel/main/number/3',
    '/tasks/channel/main',
    '/tasks/task/history',
    '/tasks/server',
    '/tasks/server/counts',
    '/messages/channel/conversation',
    '/channels/main/threads/m1',
    '/messages/context/m1',
    '/messages/m1/reactions/viewer',
    '/messages/search',
    '/artifacts/conversations/main',
    '/artifacts/artifact-id/details',
    '/integrations/marketplace',
    '/integrations/overview',
  ]) {
    test('revisiting $path reuses the accepted response', () async {
      final first = await client.get(path);
      expect(wire.requests(path), 1);
      expect(await client.get(path), first);
      expect(wire.requests(path), 1);
    });
  }
}
