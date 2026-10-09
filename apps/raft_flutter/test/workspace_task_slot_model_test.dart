import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';

void main() {
  test('Source independent task open/retarget/Back retains main ticket and side anchor', () {
    // rightPanelUrlSync.ts331–389/475–535 and threadStore337–357: task owns
    // an overlay slot and history; the ordinary side thread remains accepted.
    final origin = RaftLocation.parse(
      '/s/demo/channel/c1?thread=c1:side&x=one&x=two#hash',
    );
    final n = WorkspaceNavigation()..bind('alice/server/owner', origin);
    final main = n.revision;
    final task = n.taskRevision;
    final first = origin.withQuery({'task': 'c1:task-a'});
    n.navigateTask(first, kind: origin.panelNavigationKindTo(first));
    expect(n.revision, main);
    expect(n.taskRevision, greaterThan(task));
    expect(n.index, 1);
    final second = first.withQuery({'task': 'c1:task-b'});
    n.navigateTask(second, kind: first.panelNavigationKindTo(second));
    expect(n.index, 1);
    expect(n.location.task!.itemId, 'task-b');
    expect(n.revision, main);
    n.back();
    expect(n.location.uri, origin.uri);
    expect(n.revision, main);
    expect(n.forward(), isTrue);
    expect(n.location.task!.itemId, 'task-b');
    expect(n.revision, main);
    expect(n.location.uri.queryParametersAll['x'], ['one', 'two']);
    expect(n.location.uri.fragment, 'hash');
  });

  test('Source cold legacy Back removes only its pending slot; non-task intent still retires', () {
    // rightPanelUrlSync.ts360–389/483–486 keeps pending legacyTask through
    // hydration; useMobileBack has a cold fallback inside the same server.
    final n = WorkspaceNavigation()
      ..bind(
        'owner',
        RaftLocation.parse(
          '/s/demo/tasks?legacyTask=c1:legacy-id&thread=c1:side',
        ),
      );
    final main = n.revision;
    n.back();
    expect(n.location.query('legacyTask'), isNull);
    expect(n.location.thread!.itemId, 'side');
    expect(n.revision, main);
    n.navigate(RaftLocation.parse('/s/demo/search?q=real'));
    expect(n.revision, greaterThan(main));
    final routeTicket = n.revision;
    n.bind('other principal', RaftLocation.parse('/s/other'));
    expect(n.revision, greaterThan(routeTicket));
    expect(n.index, 0);
  });
}
