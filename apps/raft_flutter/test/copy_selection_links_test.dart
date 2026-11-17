import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/copy_selection_links.dart';
import 'package:raft_flutter/features/message_selection.dart';

import 'message_export_test.dart' show messages;
import 'message_presentation_test.dart' show fixture;

class _ObservedSelection extends MessageSelection {
  _ObservedSelection(super.w, {required super.thread});
  int projections = 0;
  @override
  List<SelectedMessageRow> get available {
    projections++;
    return super.available;
  }
}

void main() {
  test(
    'empty selection does not project messages on workspace changes',
    () async {
      final (w, _) = await fixture('owner');
      final selection = _ObservedSelection(w, thread: false);
      addTearDown(w.dispose);
      addTearDown(selection.dispose);
      selection.projections = 0;
      w.notifyListeners();
      expect(selection.selected, isEmpty);
      expect(selection.projections, 0);
    },
  );
  test(
    'main links are built locally and written in one ordered commit',
    () async {
      final (w, a) = await fixture('owner');
      addTearDown(w.dispose);
      w.server = RaftRecord({
        'id': 's1',
        'role': 'owner',
        'slug': 'public-workspace',
      });
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.ledger.ingest(
        messages(),
        expectedGeneration: w.messageDomain.ledger.generation,
      );
      w.messageDomain.visibleIds['c1'] = {'parent', 'later'};
      final selection = MessageSelection(w, thread: false)
        ..enter('parent')
        ..toggle('later');
      addTearDown(selection.dispose);
      final writes = <String>[];
      a.calls.clear();
      expect(
        await copySelectedMessageLinks(
          w,
          selection,
          write: (v) async => writes.add(v),
        ),
        2,
      );
      expect(writes, [
        'https://example.invalid/s/public-workspace/channel/c1?msg=parent\nhttps://example.invalid/s/public-workspace/channel/c1?msg=later',
      ]);
      expect(a.calls, isEmpty, reason: 'Web builds every link locally');
    },
  );
  test('thread root and reply: the reply carries the parent route', () async {
    final (w, a) = await fixture('owner');
    addTearDown(w.dispose);
    w.server = RaftRecord({
      'id': 's1',
      'role': 'owner',
      'slug': 'public-workspace',
    });
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest(
      messages(),
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {'parent', 'later'};
    w.messageDomain.visibleIds['t1'] = {'reply'};
    w.messageDomain.state.threadParent = w.messageDomain.messages.first;
    w.threadChannelId = 't1';
    final selection = MessageSelection(w, thread: true)
      ..enter('parent')
      ..selectAll();
    addTearDown(selection.dispose);
    final writes = <String>[];
    a.calls.clear();
    expect(
      await copySelectedMessageLinks(
        w,
        selection,
        write: (v) async => writes.add(v),
      ),
      2,
    );
    final lines = writes.single.split('\n').map(Uri.parse).toList();
    expect(lines.first.queryParameters, {'msg': 'parent'});
    expect(lines.last.queryParameters, {'msg': 'reply', 'thread': 'c1:parent'});
    expect(a.calls, isEmpty);
  });
  test('an unknown server slug writes nothing', () async {
    final (w, _) = await fixture('owner');
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest(
      messages(),
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {'parent'};
    final selection = MessageSelection(w, thread: false)..enter('parent');
    addTearDown(selection.dispose);
    final writes = <String>[];
    expect(
      await copySelectedMessageLinks(
        w,
        selection,
        write: (v) async => writes.add(v),
      ),
      0,
    );
    expect(writes, isEmpty);
  });
}
