import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/features/forward_messages_dialog.dart';
import 'package:raft_flutter/features/message_action_card.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/message_task_projection.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/platform/background_inbox.dart';

dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/field_parity/$name.json').readAsStringSync());

Map<String, dynamic> inboxItem(String kind) =>
    Map<String, dynamic>.from(
      (fixture('tasks-activity-inbox-window')['items'] as List).firstWhere(
        (row) => row['kind'] == kind,
      ),
    );

RaftMessage channelPageMessage(String suffix) => RaftMessage(
  Map<String, dynamic>.from(
    (fixture('messages-channel-page')['messages'] as List).firstWhere(
      (m) => (m['id'] as String).endsWith(suffix),
    ),
  ),
);

void main() {
  group('Activity DM rows resolve the peer through the DM channel list', () {
    final dms = [
      RaftChannel({
        'id': 'd1000000-0000-4000-8000-0000000000d1',
        'name': 'dm-user-alice',
        'type': 'dm',
        'peerName': 'alice',
        'peerDisplayName': 'Alice Chen',
      }),
      RaftChannel({
        'id': 'd2',
        'name': 'dm-agent',
        'type': 'dm',
        'peerName': 'cindy',
        'peerDisplayName': null,
      }),
    ];

    test('dm row title is peerDisplayName, not the raw channelName', () {
      expect(activityRowTitle(inboxItem('dm'), dms), 'Alice Chen');
    });

    test('peerName, then the row channelName, when no display name', () {
      expect(
        activityRowTitle({'kind': 'dm', 'channelId': 'd2', 'channelName': 'x'}, dms),
        'cindy',
      );
      expect(
        activityRowTitle(
          {'kind': 'dm', 'channelId': 'unknown', 'channelName': 'alice'},
          dms,
        ),
        'alice',
      );
    });

    test('channel rows keep channelName', () {
      expect(
        activityRowTitle({
          'kind': 'channel',
          'channelId': 'd2',
          'channelName': 'design',
        }, dms),
        'design',
      );
    });

    test('thread under a dm shows @peerDisplayName; others keep #name', () {
      final thread = inboxItem('thread');
      expect(activityThreadSubtitle(thread, dms), '@Alice Chen');
      expect(
        activityThreadSubtitle({
          ...thread,
          'parentChannelType': 'channel',
          'parentChannelName': 'design',
        }, dms),
        '#design',
      );
      expect(
        activityThreadSubtitle({...thread, 'parentChannelId': 'nope'}, dms),
        '@alice',
      );
    });

    test('group header title resolves the dm peer', () {
      expect(activityGroupTitle(inboxItem('thread'), dms), 'Alice Chen');
      expect(activityGroupTitle(inboxItem('dm'), dms), 'Alice Chen');
    });
  });

  group('background mentions-only gate', () {
    final since = DateTime.utc(2026, 10, 1);

    test('thread mention whose firstMentionMessageId is older than the latest alerts', () {
      final row = inboxItem('thread');
      expect(row['firstMentionMessageId'], isNot(row['latestActivityMessageId']));
      row['latestActivityMessageId'] = 'm-th-0009';
      final alert = BackgroundInboxAlert.fromRow(
        row,
        's',
        since,
        mentionsOnly: true,
      );
      expect(alert, isNotNull);
      expect(alert!.target.messageId, 'm-th-0009');
    });

    test('RisingWave path (firstMentionMessageId null) still alerts', () {
      final row = {...inboxItem('thread'), 'firstMentionMessageId': null};
      row['latestActivityMessageId'] = 'm-th-0009';
      expect(
        BackgroundInboxAlert.fromRow(row, 's', since, mentionsOnly: true),
        isNotNull,
      );
    });

    test('no mention or no unread stays silent in mentions-only mode', () {
      final row = {...inboxItem('thread'), 'latestActivityMessageId': 'm9'};
      expect(
        BackgroundInboxAlert.fromRow(
          {...row, 'hasMention': false},
          's',
          since,
          mentionsOnly: true,
        ),
        isNull,
      );
      expect(
        BackgroundInboxAlert.fromRow(
          {...row, 'unreadCount': 0},
          's',
          since,
          mentionsOnly: true,
        ),
        isNull,
      );
    });
  });

  group('action card read-only rule (isActionCardReadOnlyInServer)', () {
    final metadata = Map<String, dynamic>.from(
      fixture('messages-action-card-null-source')['actionMetadata'],
    );

    test('explicit null sourceServerId is read-only', () {
      expect(metadata.containsKey('sourceServerId'), true);
      expect(actionCardReadOnlyInServer(metadata, 'srv'), true);
    });

    test('absent key (older server) is not read-only', () {
      final older = {...metadata}..remove('sourceServerId');
      expect(actionCardReadOnlyInServer(older, 'srv'), false);
    });

    test('same server executes, foreign server is read-only', () {
      expect(
        actionCardReadOnlyInServer({...metadata, 'sourceServerId': 'srv'}, 'srv'),
        false,
      );
      expect(
        actionCardReadOnlyInServer({...metadata, 'sourceServerId': 'o'}, 'srv'),
        true,
      );
      expect(
        actionCardReadOnlyInServer({...metadata, 'sourceServerId': 'o'}, null),
        true,
      );
    });
  });

  group('provisional task chip reads the real message fields', () {
    test('title from taskCurrentProjection and assignee from taskAssigneeName', () {
      final task = provisionalMessageTask(channelPageMessage('0002'))!;
      expect(task['title'], 'Ship the parity audit (amended title)');
      expect(task['claimedByName'], 'Product-UX-Designer');
      expect(task['taskNumber'], 12);
      expect(task['status'], 'in_progress');
      expect(task['id'], task['messageId']);
    });

    test('no projection falls back to content; unclaimed has no claimant', () {
      final json = {
        ...channelPageMessage('0002').json,
        'taskCurrentProjection': null,
        'taskAssigneeName': null,
        'taskId': 'ignored',
        'taskTitle': 'ignored',
        'taskClaimedByName': 'ignored',
      };
      final task = provisionalMessageTask(RaftMessage(json))!;
      expect(task['title'], json['content']);
      expect(task.containsKey('claimedByName'), false);
      expect(task['id'], json['id']);
    });

    test('a message without a task yields none', () {
      expect(provisionalMessageTask(channelPageMessage('0003')), isNull);
    });
  });

  group('activity thread rows follow task:updated', () {
    final payload = fixture('tasks-socket-task-and-message-payloads');
    final task = payload['task:updated']['task'] as Map;

    test('overlay number, status and claimant on the matching parent', () {
      final rows = [inboxItem('dm'), inboxItem('thread')];
      expect(rows[1]['taskStatus'], 'in_review');
      final next = applyTaskToActivityRows(rows, task);
      expect(identical(next, rows), false);
      expect(next[0], same(rows[0]));
      expect(next[1]['taskStatus'], 'done');
      expect(next[1]['taskNumber'], 12);
      expect(next[1]['taskClaimedByName'], 'cindy');
      expect(activityTaskLabel(next[1]), '#12 @cindy');
    });

    test('unchanged facts keep the same list; unclaimed drops the claimant', () {
      final rows = [inboxItem('thread')];
      final same = applyTaskToActivityRows(rows, {
        ...task,
        'status': 'in_review',
      });
      expect(identical(same, rows), true);
      final unclaimed = applyTaskToActivityRows(rows, {
        ...task,
        'claimedByName': null,
      });
      expect(unclaimed[0]['taskClaimedByName'], isNull);
      expect(activityTaskLabel(unclaimed[0]), '#12');
    });

    test('another message and malformed facts are ignored', () {
      final rows = [inboxItem('thread')];
      expect(
        identical(applyTaskToActivityRows(rows, {...task, 'messageId': 'x'}), rows),
        true,
      );
      expect(identical(applyTaskToActivityRows(rows, {'status': 3}), rows), true);
    });
  });

  test('external_projection sender subtitle is externalAuthor.provider', () {
    final message = RaftMessage(
      Map<String, dynamic>.from(fixture('messages-external-projection')),
    );
    expect(externalSenderSubtitle(message), 'slack');
    expect(
      externalSenderSubtitle(
        RaftMessage({...message.json, 'externalAuthor': null}),
      ),
      isNull,
    );
    expect(
      externalSenderSubtitle(channelPageMessage('0002')),
      isNull,
    );
  });

  group('SVG attachments are inline only through their raster thumbnail', () {
    final attachments = (channelPageMessage('0002').json['attachments'] as List)
        .cast<Map<String, dynamic>>();

    test('svg with thumbnailUrl (a WebP rendition) is an inline image', () {
      expect(attachments.first['mimeType'], 'image/svg+xml');
      expect(attachmentIsInlineImage(attachments.first), true);
    });

    test('svg without a thumbnail and non-images are file cards', () {
      expect(
        attachmentIsInlineImage({...attachments.first, 'thumbnailUrl': null}),
        false,
      );
      expect(attachmentIsInlineImage(attachments.last), false);
    });

    test('raster images and parameterised mime types stay inline', () {
      expect(attachmentIsInlineImage({'mimeType': 'image/png'}), true);
      expect(
        attachmentIsInlineImage({
          'mimeType': 'image/SVG+xml; charset=utf-8',
          'thumbnailUrl': 'https://cdn.example.test/t.webp',
        }),
        true,
      );
    });
  });

  group('forward eligibility follows getForwardableMessages', () {
    test('system messages and any action metadata kind are blocked', () {
      expect(messageForwardable(channelPageMessage('0001')), false);
      expect(
        messageForwardable(
          RaftMessage(
            Map<String, dynamic>.from(fixture('messages-action-card-null-source')),
          ),
        ),
        false,
      );
      expect(
        messageForwardable(
          RaftMessage({
            'messageType': 'chat',
            'actionMetadata': {'kind': 'forwarded-bundle'},
          }),
        ),
        false,
      );
    });

    test('chat, unknown future messageType and kind-less metadata forward', () {
      expect(messageForwardable(channelPageMessage('0002')), true);
      expect(messageForwardable(RaftMessage({'messageType': 'rich'})), true);
      expect(
        messageForwardable(
          RaftMessage({'messageType': 'chat', 'actionMetadata': {}}),
        ),
        true,
      );
    });
  });

  test('thread parent channel comes from conversationContext', () {
    final json = Map<String, dynamic>.from(fixture('messages-comment-ref'));
    expect(
      messageParentChannelId(json),
      '33333333-3333-4333-8333-333333333333',
    );
    expect(messageParentChannelId({'channelId': 'c'}), isNull);
    expect(
      messageParentChannelId({'conversationContext': {'parentChannelId': ''}}),
      isNull,
    );
  });
}
