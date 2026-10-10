import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/message_task_projection.dart';

import 'message_presentation_test.dart' show fixture;

const task = {
  'id': 'parent',
  'messageId': 'parent',
  'channelId': 'c1',
  'taskNumber': 10,
  'title': 'Public linked task',
  'status': 'in_progress',
  'claimedByName': 'Cindy',
};
Future<void> drain() => Future<void>.delayed(const Duration(milliseconds: 20));
void main() {
  test(
    'accepted channel task reference is scoped and invalid rows are omitted',
    () async {
      final (w, transport) = await fixture('owner');
      addTearDown(w.dispose);
      transport.routes['GET /tasks/channel/c1'] = (_) => {
        'tasks': [
          task,
          {...task, 'messageId': 'foreign', 'channelId': 'other'},
          {...task, 'messageId': 'unknown', 'status': 'invented'},
        ],
      };
      final projection = MessageTaskProjection(w);
      addTearDown(projection.dispose);
      await drain();
      final message = RaftMessage({'id': 'parent', 'channelId': 'c1'});
      expect(projection.taskFor(message)?['taskNumber'], 10);
      expect(projection.byMessage.keys, ['parent']);
      expect(
        projection.taskFor(RaftMessage({'id': 'parent', 'channelId': 'other'})),
        null,
      );
      w.channel = RaftChannel({...w.channel!.json, 'joined': false});
      w.notifyListeners();
      expect(projection.byMessage, isEmpty);
    },
  );
  test(
    'Source pending refresh shares reads; late old principal stays retired',
    () async {
      final (w, transport) = await fixture('owner');
      addTearDown(w.dispose);
      final first = Completer<dynamic>(), second = Completer<dynamic>();
      var reads = 0;
      transport.routes['GET /tasks/channel/c1'] = (_) =>
          ++reads == 1 ? first.future : second.future;
      final projection = MessageTaskProjection(w);
      addTearDown(projection.dispose);
      await drain();
      projection.refresh();
      await drain();
      // Source taskStore440–467 suppresses duplicate pending bucket reads.
      expect(reads, 1);
      w.client.user = RaftRecord({'id': 'new principal'});
      w.notifyListeners();
      await drain();
      expect(reads, 2);
      second.complete({
        'tasks': [task],
      });
      await drain();
      expect(projection.byMessage['parent']?['taskNumber'], 10);
      first.complete({
        'tasks': [
          {...task, 'taskNumber': 99},
        ],
      });
      await drain();
      expect(projection.byMessage['parent']?['taskNumber'], 10);
      w.client.user = RaftRecord({'id': 'other'});
      w.notifyListeners();
      expect(projection.byMessage, isEmpty);
    },
  );
  test(
    'channel switches keep accepted buckets; authority changes revalidate in place',
    () async {
      final (w, transport) = await fixture('owner');
      addTearDown(w.dispose);
      final c2 = RaftChannel({'id': 'c2', 'name': 'two', 'joined': true});
      w.channels = [w.channel!, c2];
      transport.routes['GET /tasks/channel/c2'] = (_) => {'tasks': []};
      var reads = 0;
      transport.routes['GET /tasks/channel/c1'] = (_) {
        reads++;
        return {
          'tasks': [task],
        };
      };
      final projection = MessageTaskProjection(w);
      addTearDown(projection.dispose);
      await drain();
      expect(projection.byMessage.keys, ['parent']);
      final accepted = projection.byMessage['parent'];
      final c1 = w.channel!;
      w.channel = c2;
      w.notifyListeners();
      expect(projection.byMessage, isEmpty);
      await drain();
      w.channel = c1;
      w.notifyListeners();
      // Present at once, same object, no refetch of a fresh bucket.
      expect(identical(projection.byMessage['parent'], accepted), isTrue);
      await drain();
      expect(reads, 1);
      // A non-reducing authority change keeps the bucket while it
      // revalidates in the background.
      final pending = Completer<dynamic>();
      transport.routes['GET /tasks/channel/c1'] = (_) {
        reads++;
        return pending.future;
      };
      w.channel = RaftChannel({
        ...c1.json,
        'archivedAt': '2026-10-10T00:00:00Z',
      });
      w.notifyListeners();
      await drain();
      expect(reads, 2);
      expect(identical(projection.byMessage['parent'], accepted), isTrue);
      pending.complete({
        'tasks': [
          {...task, 'status': 'done'},
        ],
      });
      await drain();
      expect(projection.byMessage['parent']?['status'], 'done');
    },
  );
}
