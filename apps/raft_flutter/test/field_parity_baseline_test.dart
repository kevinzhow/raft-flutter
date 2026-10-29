// Guard for the "server/Web moved a field, Flutter still reads the old one"
// bug class (docs/field-parity.md). The payloads in test/fixtures/field_parity
// are real-shaped server serializer output (fake ids, source file:line inside
// each file or in the audit). The Flutter accessors must show what Web shows.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart' show projectThreadReply;
import 'package:raft_ui/raft_ui.dart' show raftForwardedItems;

const _dir = 'test/fixtures/field_parity';

dynamic fixture(String name) =>
    jsonDecode(File('$_dir/$name.json').readAsStringSync());

List<Map<String, dynamic>> rows(String name, [String? key]) {
  final value = fixture(name);
  final list = key == null ? value : (value as Map)[key];
  return [
    for (final row in list as List) Map<String, dynamic>.from(row as Map),
  ];
}

void main() {
  group('fixture inventory', () {
    final files = Directory(_dir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    test('every fixture is valid JSON', () {
      expect(files, isNotEmpty);
      for (final file in files) {
        expect(
          () => jsonDecode(file.readAsStringSync()),
          returnsNormally,
          reason: file.path,
        );
      }
    });

    test('every fixture is loaded by a field_parity test', () {
      final sources = Directory('test')
          .listSync()
          .whereType<File>()
          .where(
            (f) => RegExp(r'field_parity_\w+_test\.dart$').hasMatch(f.path),
          )
          .map((f) => f.readAsStringSync())
          .join('\n');
      final missing = [
        for (final file in files)
          if (!sources.contains(
            file.uri.pathSegments.last.replaceAll('.json', ''),
          ))
            file.uri.pathSegments.last,
      ];
      expect(
        missing,
        isEmpty,
        reason: 'a fixture nobody loads cannot catch a renamed field',
      );
    });
  });

  group('shared accessors against server shapes', () {
    test(
      'agent title is displayName || name, also for an empty displayName',
      () {
        final agents = rows('agents-list-managed-agent');
        expect(RaftRecord(agents.first).name, 'Atlas');
        final created = (agents.first['createdAgents'] as List).first as Map;
        expect(created['displayName'], '');
        expect(RaftRecord(Map<String, dynamic>.from(created)).name, 'scout');
      },
    );

    test('DM label is peerDisplayName || peerName (server sends null)', () {
      final dms = rows('channels-dm-list').map(RaftChannel.new).toList();
      expect(dms.map((c) => c.peerLabel), ['cindy', 'Artin L.']);
      expect(
        dms.every((c) => c.joined),
        isTrue,
        reason: 'DM rows carry no joined',
      );
    });

    test('channel list rows: type, joined, archived as Web reads them', () {
      final channels = rows(
        'channels-list-regular-and-joint',
      ).map(RaftChannel.new).toList();
      expect(channels.map((c) => c.type), ['channel', 'joint']);
      expect(channels.every((c) => c.joined && !c.archived), isTrue);
    });

    test('conversion state: canonical first; a restored failure is failed', () {
      final snapshot = ChannelConversionSnapshot.from(
        fixture('channels-conversion-failed-restored'),
      );
      expect(snapshot.status, 'failed');
      expect(snapshot.active, isFalse);
    });

    test('server list: role and plan come from the server row', () {
      final servers = rows('members-servers-list').map(RaftRecord.new).toList();
      expect(servers.map((s) => s.string('role')), ['owner', 'guest']);
      expect(servers.map((s) => s.string('plan')), ['free', 'pro']);
      expect(servers.first.flag('hideHumansFromMembers'), isTrue);
    });

    test('message page: seq, sender name and attachments', () {
      final page = fixture('messages-channel-page') as Map;
      final messages = [
        for (final m in page['messages'] as List)
          RaftMessage(Map<String, dynamic>.from(m as Map)),
      ];
      expect(messages.map((m) => m.seq.toInt()), [1201, 1202, 1203]);
      expect(messages[1].author, 'Product UX Designer');
      expect(messages[1].attachments, hasLength(2));
      expect(messages[1].threadId, isNotNull);
      expect(messages[0].threadId, isNull);
    });
  });

  group('wire contract: keys Flutter reads are still in the server shape', () {
    // name -> key paths (dot = nested, [0] = first list element). If a server
    // serializer renames one, regenerate the fixture and fix the Flutter read.
    const contract = <String, List<String>>{
      'realtime-agent-activity': [
        'payload.agentId',
        'payload.activity',
        'payload.activityKind',
        'payload.detail',
        'payload.detailKind',
      ],
      'realtime-thread-updated': [
        'payload.threadChannelId',
        'payload.replyCount',
        'payload.syncCoreReplyWindow',
      ],
      'realtime-messages-page': [
        'response.messages',
        'response.threadSummariesByParentMessageId',
        'response.messageWindow',
      ],
      'realtime-machine-events': ['events[0].event', 'events[0].payload'],
      'realtime-task-events': ['events[0].event', 'events[0].payload'],
      'realtime-channel-events': ['events[0].event', 'events[0].payload'],
      'realtime-notification-prefs-updated': [
        'events[0].payload.prefsVersion',
        'events[0].payload.scopeId',
      ],
      'members-mcp-agent-catalog': ['servers[0].id', 'recommendations'],
      'tasks-saved-and-search': [
        'GET /messages/search.results',
        'GET /messages/search.hasMore',
      ],
      'agents-list-external-agent': [
        '[0].lastSeenAt',
        '[0].activity',
        '[0].serverRole',
      ],
      'agents-list-wake-crash-loop': [
        '[0].activityDetailKind',
        '[1].activityDetailKind',
      ],
      'agents-machines-list': [
        'machines',
        'latestComputerVersion',
        'latestComputerReleaseNotes',
        'machines[0].status',
        'machines[0].statusVersion',
      ],
      'members-billing-subscription-pro': [
        'plan',
        'serverPlan',
        'capacity',
        'usage',
        'subscription.status',
        'permissions.canManageBilling',
      ],
      'members-setup-projection-survey-pending': [
        'surface',
        'phase',
        'blocksChat',
        'allowedExits',
      ],
      'messages-thread-updated-event': [
        'parentMessageId',
        'threadChannelId',
        'replyCount',
        'syncCoreReplyWindow.producer',
        'latestReply.id',
      ],
      'messages-translation-batch': [
        'results[0].status',
        'results[0].translatedContent',
      ],
      'messages-user-send-response-v2': ['message.id', 'message.senderName'],
      'tasks-notification-settings-mentions-mode': [
        'serverPushMuted',
        'serverPushMode',
        'prefsVersion',
      ],
      'tasks-server-tasks-summary-page': [
        'tasks[0].status',
        'tasks[0].taskNumber',
        'next_cursor',
      ],
      'tasks-task-detail': ['task.status', 'task.revision', 'task.title'],
      'tasks-history-events': ['events[0].eventType', 'events[0].payload'],
    };

    dynamic at(dynamic value, String path) {
      var current = value;
      for (final part in path.split(RegExp(r'\.|(?=\[)'))) {
        if (part.isEmpty) continue;
        final index = RegExp(r'^\[(\d+)\]$').firstMatch(part);
        if (index != null) {
          final list = current as List;
          current = list[int.parse(index.group(1)!)];
        } else {
          final map = current as Map;
          if (!map.containsKey(part)) throw StateError('missing $part');
          current = map[part];
        }
      }
      return current;
    }

    for (final entry in contract.entries) {
      test(entry.key, () {
        final value = fixture(entry.key);
        for (final path in entry.value) {
          expect(() => at(value, path), returnsNormally, reason: path);
        }
      });
    }

    test('credentials, scopes and bounded agent profiles', () {
      // Top-level keys are "METHOD route (server file:line)" labels.
      final credentials = fixture('agents-credentials-and-scopes') as Map;
      final parts = credentials.entries
          .where((e) => !e.key.startsWith('_'))
          .map((e) => e.value as Map)
          .toList();
      expect(parts[0], containsPair('credentials', isA<List>()));
      expect(parts[1], containsPair('granted', isA<List>()));
      expect(parts[1], contains('mode'));
      final profiles = fixture('agents-guest-and-joint-profiles') as Map;
      final bounded = profiles.entries
          .where((e) => !e.key.startsWith('_'))
          .map((e) => e.value as Map)
          .toList();
      expect(bounded[0], contains('displayName'));
      expect(bounded[1], containsPair('serverSlug', isA<String>()));
    });

    test('task status values are the five Web statuses', () {
      const web = {'todo', 'in_progress', 'in_review', 'done', 'closed'};
      final page = fixture('tasks-server-tasks-summary-page') as Map;
      for (final task in page['tasks'] as List) {
        expect(web, contains((task as Map)['status']));
      }
    });
  });

  group('readers that already existed keep matching the server', () {
    test('forwarded bundle shows the projected snapshot author and text', () {
      final message = fixture('messages-forwarded-bundle') as Map;
      final items = raftForwardedItems(
        Map<String, dynamic>.from(message['actionMetadata'] as Map),
      );
      expect(items, hasLength(1));
      expect(items.single.author, '@Product-UX-Designer');
      expect(items.single.content, 'Captured the Android artifact.');
    });

    test('thread:updated latestReply projects the public preview', () {
      final event = fixture('messages-thread-updated-event') as Map;
      final reply = projectThreadReply(event['latestReply']);
      expect(reply, isNotNull);
      expect(reply!['messageId'], (event['latestReply'] as Map)['id']);
      expect(reply['seq'], isA<int>());
      expect(event['replyCount'], 3);
    });
  });
}
