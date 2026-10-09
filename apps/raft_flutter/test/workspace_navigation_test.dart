import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';

void main() {
  WorkspaceNavigation navigation(String path) {
    final current = RaftLocation.parse(path);
    return WorkspaceNavigation()..bind('alice/server/owner', current);
  }

  test('Activity preview is one URI; selected data never changes master', () {
    final n = navigation('/s/demo/activity');
    n.navigate(
      n.location.withQuery({'open': 'channel:design', 'msg': 'm'}),
      kind: RaftNavigationKind.replace,
    );
    expect(n.section, 'activity');
    expect(n.location.content?.id, 'design');
    expect(n.location.messageId, 'm');
    expect(n.mobileRootTab, isNull);
    expect(n.index, 0);
    n.back();
    expect(n.location.toString(), '/s/demo/activity');
  });
  test(
    'every mobile tab tap pushes its root, including active repeated taps',
    () {
      final n = navigation('/s/demo/tasks?task=design:m');
      final before = n.revision;
      n.navigate(n.location.tabHome(RaftMobileTab.tasks));
      n.navigate(n.location.tabHome(RaftMobileTab.tasks));
      expect(n.entries.map((l) => l.toString()), [
        '/s/demo/tasks?task=design:m',
        '/s/demo/tasks',
        '/s/demo/tasks',
      ]);
      expect(n.revision, before + 2);
      expect(n.mobileRootTab, 'tasks');
    },
  );
  test(
    'observed Back and Forward retain query identities; new push drops future',
    () {
      final n = navigation('/s/demo');
      n.navigate(
        RaftLocation.parse('/s/demo/channel/c?msg=m&thread=c:p&task=c:t'),
      );
      n.navigate(RaftLocation.parse('/s/demo/search?open=human:h'));
      expect(
        n.back().toString(),
        '/s/demo/channel/c?msg=m&thread=c:p&task=c:t',
      );
      expect(n.forward(), isTrue);
      n.back();
      n.navigate(RaftLocation.parse('/s/demo/saved'));
      expect(n.forward(), isFalse);
      expect(n.entries.last.route, RaftRoute.saved);
    },
  );
  test('cold overlay Back replaces with underlying route; entity Back reaches semantic tab', () {
    final n = navigation('/s/demo/channel/c?thread=c:p&profile=human:h');
    expect(n.back().toString(), '/s/demo/channel/c');
    expect(n.entries.length, 1);
    final entity = navigation('/s/demo/agent/a');
    expect(entity.back().toString(), '/s/demo/members');
  });
  test(
    'principal and server rebinding invalidate async tickets and history',
    () {
      final n = navigation('/s/demo/activity?open=channel:private');
      final ticket = n.reserve();
      n.bind('bob/other/member', RaftLocation.parse('/s/other'));
      expect(n.revision, greaterThan(ticket));
      expect(n.entries.map((l) => l.toString()), ['/s/other']);
      expect(
        () => n.navigate(RaftLocation.parse('/s/demo/channel/private')),
        throwsArgumentError,
      );
      expect(n.back().serverSlug, 'other');
    },
  );
  test(
    'root visibility is a location projection, independent of cached channel',
    () {
      for (final path in [
        '/s/demo/channel/c',
        '/s/demo/agent/a',
        '/s/demo/computer/c',
        '/s/demo/settings/account',
        '/s/demo/activity',
        '/s/demo/members?profile=human:h',
      ]) {
        expect(navigation(path).mobileRootTab, isNull, reason: path);
      }
      expect(navigation('/s/demo/settings').mobileRootTab, 'settings');
      expect(navigation('/s/demo/members').mobileRootTab, 'members');
    },
  );
}
