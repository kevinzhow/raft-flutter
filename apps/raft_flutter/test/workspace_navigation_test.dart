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
    expect(n.back().thread?.itemId, 'p');
    expect(n.location.profile, isNull);
    expect(n.back().toString(), '/s/demo/channel/c');
    expect(n.entries.length, 1);
    final entity = navigation('/s/demo/agent/a');
    expect(entity.back().toString(), '/s/demo/members');
  });
  test('wired model cold Back closes independent task, profile and thread separately', () {
    final n = navigation(
      '/s/demo/channel/c?task=c:t&thread=c:p&profile=human:h&msg=r',
    );
    n.back();
    expect(n.location.task, isNull);
    expect(n.location.thread?.itemId, 'p');
    expect(n.location.profile?.id, 'h');
    expect(n.location.messageId, 'r');
    n.back();
    expect(n.location.profile, isNull);
    expect(n.location.thread?.itemId, 'p');
    n.back();
    expect(n.location.thread, isNull);
    expect(n.location.entityId, 'c');
  });

  test('legacy task=1 is the top task modal over its thread and profile', () {
    // Source rightPanelUrlSync.ts 272, 313–321 resolves task=1 against the
    // thread anchor; MainLayout.tsx 1360–1376 mounts that task modal last.
    final n = navigation(
      '/s/demo/channel/c?task=1&thread=c:p&profile=human:h&msg=r',
    );
    expect(n.location.task?.channelId, n.location.thread?.channelId);
    expect(n.location.task?.itemId, n.location.thread?.itemId);
    n.back();
    expect(n.location.query('task'), isNull);
    expect(n.location.thread?.itemId, 'p');
    expect(n.location.profile?.id, 'h');
    expect(n.location.messageId, 'r');
    n.back();
    expect(n.location.profile, isNull);
    expect(n.location.thread?.itemId, 'p');
    n.back();
    expect(n.location.thread, isNull);
    expect(n.location.toString(), '/s/demo/channel/c?msg=r');
    expect(n.index, 0);
  });

  test(
    '[N13] principal and server rebinding invalidate async tickets and history',
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
        '/s/demo/members?profile=human:h',
      ]) {
        expect(navigation(path).mobileRootTab, isNull, reason: path);
      }
      // Activity is a tab in the fixed phone bar and in the rail: always a
      // root (the bottom-bar customisation that could turn it off is gone).
      expect(navigation('/s/demo/activity').mobileRootTab, 'activity');
      // v1.24: pushed from the server tab, roots only beside the rail.
      expect(navigation('/s/demo/settings').mobileRootTab, isNull);
      expect(navigation('/s/demo/members').mobileRootTab, isNull);
      expect(
        (navigation(
          '/s/demo/settings',
        )..mobileTabs = {'settings'}).mobileRootTab,
        'settings',
      );
      expect(
        (navigation('/s/demo/members')..mobileTabs = {'members'}).mobileRootTab,
        'members',
      );
    },
  );
  // #383: `?artifact=` beside a page (the shell's column, Web
  // ShellArtifactHost) is not a new destination, so it keeps the revision and
  // the conversation under it current. On Activity or Search with no `open=`
  // it is the list slot's own target (ArtifactContentSlot): a new content
  // intent, which retires every ticket reserved before it.
  group('Artifact address and the navigation revision', () {
    const a1 = {'artifact': 'a1'};
    const a2 = {'artifact': 'a2', 'version': '2', 'review': 'r1'};
    const none = {'artifact': null, 'version': null, 'review': null};

    for (final page in [
      '/s/demo/activity?open=thread:t1&thread=c1:p1',
      '/s/demo/search?q=plan&open=thread:t1&thread=c1:p1',
      '/s/demo/tasks?open=task:task-1&task=c1:task:task-1',
      '/s/demo/activity?open=task:task-1&task=c1:task:task-1',
      '/s/demo/saved',
    ]) {
      test('beside $page the shell column keeps the revision', () {
        final n = navigation(page);
        final revision = n.revision;
        for (final step in [a1, a2, none]) {
          n.navigate(
            n.location.withQuery(step),
            kind: RaftNavigationKind.replace,
          );
          expect(n.revision, revision, reason: '${n.location}');
        }
        n.navigate(n.location.withQuery(a1));
        n.navigate(n.location.withQuery(a2));
        expect(n.location.query('artifact'), 'a2');
        n.back();
        expect(n.location.query('artifact'), 'a1');
        n.back();
        expect(n.location.query('artifact'), isNull);
        expect(n.forward(), isTrue);
        expect(n.location.query('artifact'), 'a1');
        expect(n.revision, revision);
        expect(n.location.content?.kind, isNot(RaftContentKind.artifact));
      });
    }

    for (final list in ['/s/demo/activity', '/s/demo/search?q=plan']) {
      for (final (name, from, to) in [
        ('opens', none, a1),
        ('switches', a1, a2),
        ('closes', a1, none),
      ]) {
        for (final kind in [
          RaftNavigationKind.replace,
          RaftNavigationKind.push,
        ]) {
          test('$list: the list slot ${kind.name} that $name its Artifact '
              'retires reserved tickets', () {
            final n = navigation(list);
            n.navigate(
              n.location.withQuery(from),
              kind: RaftNavigationKind.replace,
            );
            final ticket = n.reserve();
            n.navigate(n.location.withQuery(to), kind: kind);
            expect(n.revision, isNot(ticket), reason: '${n.location}');
          });
        }
      }

      test('$list: Back and Forward over the list slot\'s Artifact retire '
          'reserved tickets', () {
        final n = navigation(list);
        n.navigate(n.location.withQuery(a1));
        expect(n.location.content?.kind, RaftContentKind.artifact);
        var ticket = n.reserve();
        n.back();
        expect(n.location.query('artifact'), isNull);
        expect(n.revision, isNot(ticket), reason: 'Back');
        ticket = n.reserve();
        expect(n.forward(), isTrue);
        expect(n.revision, isNot(ticket), reason: 'Forward');
      });
    }
  });
}
