import 'package:raft_sync/raft_sync.dart';
import 'package:test/test.dart';

const a = '11111111-1111-4111-8111-111111111111';
const s = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> reply(String updatedAt, {int? revision}) => {
  'id': 'r1',
  'seq': 7,
  'channelId': 'thread',
  'content': 'edited',
  'senderId': 'alice',
  'senderType': 'agent',
  'createdAt': '2026-11-01T00:00:00Z',
  'updatedAt': updatedAt,
  if (revision != null)
    'actionMetadata': {
      'kind': 'message-card',
      'revision': revision,
      'card': {},
    },
  'conversationContext': {
    'channelType': 'thread',
    'parentMessageId': 'parent',
    'parentChannelId': 'channel',
  },
};

void main() {
  group('live event readers', () {
    test('agent:typing keeps the Web wire shape', () {
      final event = LiveEvent.read('agent:typing', {
        'agentId': 'ag',
        'serverId': 's',
        'channelId': 'c',
        'callId': 'k',
        'state': 'start',
        'parentMessageId': 'p',
        'expiresAt': 1700000000000,
      }) as AgentTypingEvent;
      expect(event.started, isTrue);
      expect(event.parentMessageId, 'p');
      expect(event.expiresAt, 1700000000000);
      expect(
        LiveEvent.read('agent:typing', {
          'agentId': 'ag',
          'serverId': 's',
          'channelId': 'c',
          'callId': 'k',
          'state': 'typing',
        }),
        isNull,
      );
    });

    test('actor:updated takes agents with uuid ids only', () {
      final ok = {
        'kind': 'agent',
        'id': a,
        'homeServerId': s,
        'name': 'bot',
        'displayName': 'Bot',
        'avatarUrl': null,
      };
      final event = LiveEvent.read('actor:updated', ok) as ActorUpdatedEvent;
      expect(event.actorName, 'bot');
      expect(LiveEvent.read('actor:updated', {...ok, 'kind': 'human'}), isNull);
      expect(LiveEvent.read('actor:updated', {...ok, 'id': 'x'}), isNull);
      expect(LiveEvent.read('actor:updated', {...ok, 'avatarUrl': 3}), isNull);
    });

    test('user:profile-updated ignores the deprecated gravatarHash', () {
      final event = LiveEvent.read('user:profile-updated', {
        'serverId': s,
        'userId': a,
        'name': 'alice',
        'displayName': null,
        'avatarUrl': '/avatars/a.png',
        'gravatarHash': '',
      }) as UserProfileUpdatedEvent;
      expect(event.profile, {
        'name': 'alice',
        'displayName': null,
        'avatarUrl': '/avatars/a.png',
      });
      expect(
        LiveEvent.read('user:profile-updated', {'serverId': s, 'userId': a}),
        isNull,
      );
    });

    test('appearance:updated drops an unknown theme; null is the default', () {
      final event = LiveEvent.read('appearance:updated', {
        'serverId': 's',
        'theme': 'space',
        'themeDecor': false,
      }) as AppearanceUpdatedEvent;
      expect(event.patch, {'theme': 'space', 'themeDecor': false});
      expect(
        (LiveEvent.read('appearance:updated', {
          'serverId': 's',
          'theme': null,
        }) as AppearanceUpdatedEvent).patch,
        {'theme': null},
      );
      expect(
        LiveEvent.read('appearance:updated', {'serverId': 's', 'theme': 'x'}),
        isNull,
      );
    });

    test('list pings and gating flag changes name their list', () {
      expect(
        (LiveEvent.read('joint-invites:changed', {
          'serverId': 's',
        }) as ListChangedEvent).event,
        ListChangedEvent.jointInvites,
      );
      expect(LiveEvent.read('seat-join-blocks:changed', {}), isNull);
      final flags = LiveEvent.read('server:features-changed', {
        'serverId': 's',
        'keys': ['pro_seat_add', 'other'],
      }) as ServerFeaturesChangedEvent;
      expect(flags.listPings.map((e) => e.event), [
        ListChangedEvent.seatJoinBlocks,
      ]);
    });

    test('activity:changed, agent:activity_state and sync:changed', () {
      expect(
        (LiveEvent.read('activity:changed', {
          'serverId': 's',
          'source': 'object',
        }) as ActivityChangedEvent).serverId,
        's',
      );
      expect(LiveEvent.read('activity:changed', {}), isNull);
      final state = LiveEvent.read('agent:activity_state', {
        'agentId': 'ag',
        'state': 'busy',
        'activity': 'working',
        'timestamp': 5,
        'serverSeq': 9,
      }) as AgentActivityStateEvent;
      expect(state.serverSeq, 9);
      expect(LiveEvent.read('sync:changed', null), isA<SyncChangedEvent>());
      expect(LiveEvent.read('message:new', {}), isNull);
    });
  });

  group('thread reply update (thread:reply_updated, FLD-145)', () {
    ThreadRepliesSync held() {
      final sync = ThreadRepliesSync();
      sync.hydrateSummary('server', 'me', 'channel', 'parent', {
        'threadChannelId': 'thread',
        'replyCount': 1,
        'latestReplies': [
          projectThreadReply({
            ...reply('2026-11-01T00:00:00Z', revision: 2),
            'content': 'original',
          }),
        ],
      });
      return sync;
    }

    test('previews keep updatedAt and the card revision', () {
      final preview = projectThreadReply(
        reply('2026-11-02T00:00:00Z', revision: 3),
      )!;
      expect(preview['updatedAt'], '2026-11-02T00:00:00Z');
      expect(preview['cardRevision'], 3);
    });

    test('a newer copy edits the held preview without changing counts', () {
      final sync = held();
      final result = sync.applyReplyUpdate(
        reply('2026-11-02T00:00:00Z', revision: 3),
        serverId: 'server',
        principalId: 'me',
      )!;
      expect(result.parentMessageId, 'parent');
      expect(result.scope.replies.single['preview'], 'edited');
      expect(result.scope.replyCount, 1);
      final id = sync.scopeId('server', 'me', 'parent', 'thread');
      expect(sync.scope(id)!.replies.single['preview'], 'edited');
    });

    test(
      'an older or same updatedAt, or an older card revision, is dropped',
      () {
        final sync = held();
        expect(
          sync.applyReplyUpdate(
            reply('2026-11-01T00:00:00Z'),
            serverId: 'server',
            principalId: 'me',
          ),
          isNull,
        );
        expect(
          sync.applyReplyUpdate(
            reply('2026-11-03T00:00:00Z', revision: 1),
            serverId: 'server',
            principalId: 'me',
          ),
          isNull,
        );
      },
    );

    test('a reply not in the window is never inserted', () {
      final sync = held();
      expect(
        sync.applyReplyUpdate(
          {...reply('2026-11-02T00:00:00Z'), 'id': 'other', 'seq': 8},
          serverId: 'server',
          principalId: 'me',
        ),
        isNull,
      );
      expect(
        sync.applyReplyUpdate(
          reply('2026-11-02T00:00:00Z'),
          serverId: 'server',
          principalId: 'someone-else',
        ),
        isNull,
      );
    });
  });
}
