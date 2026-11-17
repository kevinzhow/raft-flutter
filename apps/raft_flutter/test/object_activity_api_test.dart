import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_object_rows.dart';
import 'package:raft_flutter/data/object_activity_api.dart';
import 'package:raft_flutter/data/resource_row_reconcile.dart';

void main() {
  final row = {
    'kind': 'object',
    'objectKind': 'artifact',
    'objectId': 'a1',
    'doneFrontierSeq': '42',
    'unreadCount': 2,
  };

  test('an object row has the key object:<objectKind>:<id>', () {
    expect(activityObjectKey(row), 'object:artifact:a1');
    expect(activityItemKey(row), 'object:artifact:a1');
    expect(activityScopeId(row), isNull);
    expect(activityItemKey({'kind': 'object'}), isNull);
  });

  test('Web bodies: done and read go through the newest event, undone names the object', () {
    expect(ObjectActivityApi.body(row), {
      'kind': 'artifact',
      'objectId': 'a1',
      'throughSeq': '42',
    });
    expect(ObjectActivityApi.body(row, throughSeq: false), {
      'kind': 'artifact',
      'objectId': 'a1',
    });
    expect(ObjectActivityPaths.done, '/objects/activity/done');
    expect(ObjectActivityPaths.undone, '/objects/activity/undone');
    expect(ObjectActivityPaths.read, '/objects/activity/read');
  });

  test('read state of an object row', () {
    expect(activityObjectRowIsRead(row), isFalse);
    expect(activityObjectRowIsRead({...row, 'unreadCount': 0}), isTrue);
    expect(
      activityObjectRowIsRead({...row, 'unreadCount': 0, 'hasMention': true}),
      isFalse,
    );
  });
}
