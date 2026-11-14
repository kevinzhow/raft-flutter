// Task v2 per-task mode and the create helpers (Web v1.24
// utils/taskConversation.ts, taskStatusUi.getTaskStatusOptions,
// createTaskForm.ts).
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/create_task_dialog.dart';
import 'package:raft_flutter/features/create_task_message_dialog.dart';
import 'package:raft_flutter/features/task_status_request.dart';
import 'package:raft_flutter/features/task_v2_mode.dart';

void main() {
  test('isTaskV2Task / opensAsTaskConversation', () {
    final v2 = {'id': 't', 'conversationAnchored': true, 'hostMessageId': null};
    final preV2 = {'id': 't', 'messageId': 'm', 'hostMessageId': 'm'};
    final old = {'id': 't', 'messageId': 'm'};
    expect(isTaskV2Task(v2), isTrue);
    expect(isTaskV2Task({'id': 't', 'conversationChannelId': 'c'}), isTrue);
    expect(isTaskV2Task({'id': 't', 'hostMessageId': null}), isTrue);
    expect(isTaskV2Task(preV2), isFalse);
    // An older server's DTO has none of the fields: pre-v2.
    expect(isTaskV2Task(old), isFalse);
    expect(isTaskV2Task({...v2, 'isLegacy': true}), isFalse);
    expect(opensAsTaskConversation(preV2, false), isFalse);
    expect(opensAsTaskConversation(preV2, true), isTrue);
    expect(opensAsTaskConversation(v2, false), isTrue);
    expect(opensAsTaskConversation({'isLegacy': true}, true), isFalse);
  });

  test('a task hangs under its source with task v2, its host before', () {
    final preV2 = {'id': 't', 'messageId': 'host', 'sourceMessageId': 'src'};
    expect(taskAnchorMessageId(preV2, false), 'host');
    expect(taskAnchorMessageId(preV2, true), 'src');
    final v2 = {
      'id': 't',
      'messageId': 't',
      'hostMessageId': null,
      'sourceMessageId': 'src',
    };
    expect(taskAnchorMessageId(v2, false), 'src');
    // A channel-only task (no source) hangs under no message.
    expect(taskAnchorMessageId({...v2, 'sourceMessageId': null}, true), isNull);
  });

  test('the URL item is task-keyed for a task on its own conversation', () {
    expect(
      taskSurfaceItemId({
        'id': 't',
        'messageId': 'm',
        'hostMessageId': 'm',
      }, false),
      'm',
    );
    expect(
      taskSurfaceItemId({
        'id': 't',
        'messageId': 'm',
        'hostMessageId': 'm',
      }, true),
      'task:t',
    );
    expect(taskSurfaceItemId({'id': 'L', 'isLegacy': true}, true), 'L');
    expect(taskIdOfTaskItem('task:t'), 't');
    expect(taskIdOfTaskItem('m'), isNull);
    expect(taskIdOfTaskItem('task:'), isNull);
  });

  test('directTaskConversationChannelId: not across a joint channel', () {
    expect(
      directTaskConversationChannelId({'conversationChannelId': 'c'}),
      'c',
    );
    expect(
      directTaskConversationChannelId({
        'conversationChannelId': 'c',
        'channelType': 'joint',
      }),
      isNull,
    );
    expect(directTaskConversationChannelId({}), isNull);
  });

  test('Source: the message, "Not recorded", or nothing', () {
    expect(
      taskSourceDisplay({'sourceMessageId': 's', 'sourceRecorded': true}),
      isA<TaskSourceMessage>().having((s) => s.id, 'id', 's'),
    );
    expect(
      taskSourceDisplay({'sourceMessageId': 's', 'sourceRecorded': false}),
      isA<TaskSourceNotRecorded>(),
    );
    expect(
      taskSourceDisplay({'sourceRecorded': true}),
      isA<TaskSourceNotRecorded>(),
    );
    // A server before sourceRecorded: a pre-v2 task's host stands for it.
    expect(
      taskSourceDisplay({'sourceMessageId': 'm', 'messageId': 'm'}),
      isNull,
    );
  });

  test('the task ref names its channel or DM', () {
    expect(
      formatTaskConversationRef({'taskNumber': 7, 'channelName': 'design'}),
      '#design:#7',
    );
    expect(
      formatTaskConversationRef({
        'taskNumber': 7,
        'channelType': 'dm',
      }, dmPeerName: 'bob'),
      'dm:@bob:#7',
    );
    expect(formatTaskConversationRef({'taskNumber': 7}), '#7');
  });

  test('status options: in_review retired for v2, backlog only for v2', () {
    expect(
      taskV2StatusOptions({'status': 'todo', 'hostMessageId': null}, false),
      ['backlog', 'todo', 'in_progress', 'done', 'closed'],
    );
    expect(
      taskV2StatusOptions({
        'status': 'in_review',
        'hostMessageId': null,
      }, false),
      contains('in_review'),
    );
    expect(taskV2StatusOptions({'status': 'todo', 'messageId': 'm'}, false), [
      'todo',
      'in_progress',
      'in_review',
      'done',
      'closed',
    ]);
  });

  test('a move into Backlog carries its reason', () {
    final task = {'id': 't', 'status': 'todo', 'claimedById': 'u'};
    expect(taskStatusRequest(task, 'backlog', reason: '  later ').data, {
      'status': 'backlog',
      'reason': 'later',
    });
    expect(taskStatusRequest(task, 'backlog').data, {'status': 'backlog'});
  });

  test('taskFromMessage: first line title, the rest description', () {
    expect(taskFromMessage('   '), isNull);
    expect(taskFromMessage(' Ship it '), (title: 'Ship it', description: null));
    expect(taskFromMessage('Ship it\n\n  with notes\n'), (
      title: 'Ship it',
      description: 'with notes',
    ));
  });

  test('create refusals a person can act on are said in their words', () {
    RaftApiException refusal(String code) => RaftApiException.response(
      'server words',
      status: 409,
      body: {'error': 'server words', 'code': code},
    );
    expect(
      createTaskFailureText(refusal('channel_archived')),
      'This channel is archived: unarchive it to create tasks in it.',
    );
    expect(
      createTaskFailureText(
        refusal('task_source_message_too_long'),
        asMessage: true,
      ),
      'This message is too long to send as a task: shorten it.',
    );
    expect(createTaskFailureText(refusal('other')), 'server words');
  });
}
