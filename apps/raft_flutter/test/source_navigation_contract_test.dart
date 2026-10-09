import 'package:flutter_test/flutter_test.dart';

import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';

// Pure ports of mounted Source 26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6.
// These test URL identity and observed-history decisions. They do not exercise
// widget mounting, async entity hydration, external-author fetch or OS Back.
void main() {
  group('Source mobileBackNavigation.test.ts:12–109', () {
    test('PUSH advances, REPLACE retains, POP clamps navigation depth', () {
      expect(nextRaftNavigationDepth(0, RaftNavigationKind.push), 1);
      expect(nextRaftNavigationDepth(3, RaftNavigationKind.push), 4);
      expect(nextRaftNavigationDepth(0, RaftNavigationKind.replace), 0);
      expect(nextRaftNavigationDepth(5, RaftNavigationKind.replace), 5);
      expect(nextRaftNavigationDepth(2, RaftNavigationKind.pop), 1);
      expect(nextRaftNavigationDepth(1, RaftNavigationKind.pop), 0);
      expect(nextRaftNavigationDepth(0, RaftNavigationKind.pop), 0);
    });

    test('observed push, query replace and pop retain exact origin', () {
      var stack = nextRaftNavigationStack(
        [],
        RaftNavigationKind.replace,
        '/s/dev',
      );
      stack = nextRaftNavigationStack(
        stack,
        RaftNavigationKind.push,
        '/s/dev/search',
      );
      stack = nextRaftNavigationStack(
        stack,
        RaftNavigationKind.replace,
        '/s/dev/search?q=hello',
      );
      expect(stack, ['/s/dev', '/s/dev/search?q=hello']);
      stack = nextRaftNavigationStack(stack, RaftNavigationKind.pop, '/s/dev');
      expect(stack, ['/s/dev']);
    });

    test('same-server previous search is a Back target', () {
      expect(
        resolveRaftMobileBack([
          '/s/dev',
          '/s/dev/search?q=hello',
          '/s/dev/channel/abc',
        ], '/s/dev'),
        isNull,
      );
    });

    test('foreign-server previous entry requires semantic replacement', () {
      expect(
        resolveRaftMobileBack([
          '/s/previous-server',
          '/s/current-server/channel/abc?thread=abc:p1',
        ], '/s/current-server/channel/abc'),
        '/s/current-server/channel/abc',
      );
    });

    test('callback fallback uses current server scope', () {
      expect(
        resolveRaftMobileBack([
          '/s/alpha/channel/a',
          '/s/bravo/tasks?thread=c:p',
        ], '/s/bravo'),
        '/s/bravo',
      );
    });

    test('fallback destination may differ from its server safety scope', () {
      expect(
        resolveRaftMobileBack(
          ['/s/alpha/channel/a', '/s/bravo/channel/b'],
          '/',
          scope: '/s/bravo/channel/b',
        ),
        '/',
      );
      expect(
        resolveRaftMobileBack(
          ['/s/bravo/search?q=exact', '/s/bravo/channel/b'],
          '/',
          scope: '/s/bravo/channel/b',
        ),
        isNull,
      );
    });

    test('scope comparison uses server segment, not a prefix', () {
      expect(canUseRaftHistoryBack('/s/dev-two', '/s/dev/channel/c'), isFalse);
      expect(canUseRaftHistoryBack('/s/dev/search?q=x', '/s/dev'), isTrue);
      expect(canUseRaftHistoryBack('/s/other', '/'), isTrue);
    });
  });

  group('Source mobileBackNavigation.test.ts:110–193', () {
    test('cold thread replacement cannot create a Back loop', () {
      var entries = nextRaftNavigationEntries(
        {},
        RaftNavigationKind.replace,
        0,
        '/s/dev/channel/abc?thread=abc:p1',
      );
      var stack = raftNavigationStackFromEntries(entries, 0);
      expect(
        resolveRaftMobileBack(stack, '/s/dev/channel/abc'),
        '/s/dev/channel/abc',
      );
      entries = nextRaftNavigationEntries(
        entries,
        RaftNavigationKind.replace,
        0,
        '/s/dev/channel/abc',
      );
      stack = raftNavigationStackFromEntries(entries, 0);
      expect(resolveRaftMobileBack(stack, '/s/dev'), '/s/dev');
      expect(stack, ['/s/dev/channel/abc']);
    });

    test('search query replace then result push unwinds without looping', () {
      var entries = nextRaftNavigationEntries(
        {},
        RaftNavigationKind.replace,
        0,
        '/s/dev',
      );
      entries = nextRaftNavigationEntries(
        entries,
        RaftNavigationKind.push,
        1,
        '/s/dev/search',
      );
      entries = nextRaftNavigationEntries(
        entries,
        RaftNavigationKind.replace,
        1,
        '/s/dev/search?q=hello',
      );
      entries = nextRaftNavigationEntries(
        entries,
        RaftNavigationKind.push,
        2,
        '/s/dev/channel/abc',
      );
      expect(
        resolveRaftMobileBack(
          raftNavigationStackFromEntries(entries, 2),
          '/s/dev',
        ),
        isNull,
      );
      entries = nextRaftNavigationEntries(
        entries,
        RaftNavigationKind.pop,
        1,
        '/s/dev/search?q=hello',
      );
      expect(raftNavigationStackFromEntries(entries, 1), [
        '/s/dev',
        '/s/dev/search?q=hello',
      ]);
      expect(
        resolveRaftMobileBack(
          raftNavigationStackFromEntries(entries, 1),
          '/s/dev',
        ),
        isNull,
      );
      expect(
        resolveRaftMobileBack(
          raftNavigationStackFromEntries(entries, 0),
          '/s/dev',
        ),
        '/s/dev',
      );
    });

    test('multi-entry POP and Forward retain real preceding entry', () {
      var entries = <int, String>{};
      const paths = [
        '/s/other',
        '/s/dev/channel/b',
        '/s/dev/channel/c',
        '/s/dev/channel/d',
        '/s/dev/channel/e',
      ];
      for (var index = 0; index < paths.length; index++) {
        entries = nextRaftNavigationEntries(
          entries,
          index == 0 ? RaftNavigationKind.replace : RaftNavigationKind.push,
          index,
          paths[index],
        );
      }
      for (final index in [1, 4, 2]) {
        entries = nextRaftNavigationEntries(
          entries,
          RaftNavigationKind.pop,
          index,
          paths[index],
        );
      }
      expect(raftNavigationStackFromEntries(entries, 2), paths.take(3));
      expect(
        resolveRaftMobileBack(
          raftNavigationStackFromEntries(entries, 2),
          '/s/dev',
        ),
        isNull,
      );
      expect(entries[4], '/s/dev/channel/e');
      final pushed = nextRaftNavigationEntries(
        entries,
        RaftNavigationKind.push,
        3,
        '/s/dev/channel/x',
      );
      expect(pushed.keys, [0, 1, 2, 3]);
      expect(pushed[3], '/s/dev/channel/x');
    });

    test('reload index gaps remain unknown and cannot authorize Back', () {
      final entries = nextRaftNavigationEntries(
        {},
        RaftNavigationKind.pop,
        2,
        '/s/dev/channel/c',
      );
      final stack = raftNavigationStackFromEntries(entries, 2);
      expect(stack, [
        raftUnknownNavigationEntry,
        raftUnknownNavigationEntry,
        '/s/dev/channel/c',
      ]);
      expect(resolveRaftMobileBack(stack, '/s/dev'), '/s/dev');
      expect(resolveRaftMobileBack(stack, '/'), '/');
    });
  });

  group('Source mobileBackNavigation.behavior.test.tsx:389–475', () {
    test('same-path POP cannot consume an earlier synchronous REPLACE', () {
      const pending = RaftSynchronousNavigation(
        RaftNavigationKind.replace,
        '/s/dev/channel/c?thread=c:p',
        historyIndex: 1,
      );
      expect(
        shouldConsumeRaftSynchronousNavigation(
          pending,
          const RaftSynchronousNavigation(
            RaftNavigationKind.pop,
            '/s/dev/channel/c?thread=c:p',
            historyIndex: 0,
          ),
        ),
        isFalse,
      );
      expect(
        shouldConsumeRaftSynchronousNavigation(
          pending,
          const RaftSynchronousNavigation(
            RaftNavigationKind.replace,
            '/s/dev/channel/c?thread=c:p',
            historyIndex: 0,
          ),
        ),
        isFalse,
      );
      expect(
        shouldConsumeRaftSynchronousNavigation(
          pending,
          const RaftSynchronousNavigation(
            RaftNavigationKind.replace,
            '/s/dev/channel/c?thread=c:p',
            historyIndex: 1,
          ),
        ),
        isTrue,
      );
    });

    test('same Router key cannot hide a changed history entry index', () {
      expect(
        isIdempotentRaftNavigationCommit('origin', 'origin', 1, 0),
        isFalse,
      );
      expect(
        isIdempotentRaftNavigationCommit('origin', 'origin', 0, 0),
        isTrue,
      );
      expect(
        isIdempotentRaftNavigationCommit('origin', 'destination', 0, 1),
        isFalse,
      );
    });

    test('only the pending path and kind consume a synchronous navigation', () {
      const pending = RaftSynchronousNavigation(
        RaftNavigationKind.push,
        '/s/dev/tasks?thread=c:p&task=c:t',
        historyIndex: 3,
      );
      expect(
        shouldConsumeRaftSynchronousNavigation(
          pending,
          const RaftSynchronousNavigation(
            RaftNavigationKind.push,
            '/s/dev/tasks?thread=c:p&task=c:t',
            historyIndex: 3,
          ),
        ),
        isTrue,
      );
      expect(
        shouldConsumeRaftSynchronousNavigation(
          pending,
          const RaftSynchronousNavigation(
            RaftNavigationKind.push,
            '/s/dev/tasks?thread=c:p',
            historyIndex: 3,
          ),
        ),
        isFalse,
      );
      expect(shouldConsumeRaftSynchronousNavigation(null, pending), isFalse);
    });
  });

  group('Source rightPanelUrlSyncContract.test.tsx:248–511, 988–1077', () {
    test('external profile is a message identity, not a human identity', () {
      final location = RaftLocation.parse(
        '/s/acme/channel/channel-1?profile=external%3Achannel-1%3Amessage-1',
      );
      expect(location.profile?.kind, RaftProfileKind.external);
      expect(location.profile?.id, 'message-1');
      expect(location.profile?.channelId, 'channel-1');
      expect(location.profile.toString(), 'external:channel-1:message-1');
      expect(location.withQuery({'profile': null}).profile, isNull);
      expect(RaftLocation.parse(location.toString()).profile?.id, 'message-1');
    });

    test('task modal identity coexists with a distinct side thread', () {
      final location = RaftLocation.parse(
        '/s/acme/channel/channel-1?msg=origin-reply&'
        'thread=channel-1%3Aorigin-parent&task=channel-1%3Atask-parent',
      );
      expect(location.thread.toString(), 'channel-1:origin-parent');
      expect(location.task.toString(), 'channel-1:task-parent');
      expect(location.messageId, 'origin-reply');
      final closed = location.withQuery({'task': null});
      expect(closed.task, isNull);
      expect(closed.thread.toString(), 'channel-1:origin-parent');
      expect(closed.messageId, 'origin-reply');
    });

    test('task identity survives with no side thread or the same anchor', () {
      for (final query in [
        'task=channel-1:task-parent',
        'thread=channel-1:task-parent&task=channel-1:task-parent',
      ]) {
        final location = RaftLocation.parse('/s/acme/tasks?$query');
        expect(location.task.toString(), 'channel-1:task-parent');
      }
    });

    test('legacy task=1 resolves against its thread anchor', () {
      final location = RaftLocation.parse(
        '/s/acme/tasks?thread=channel-1:task-parent&task=1',
      );
      expect(location.task.toString(), 'channel-1:task-parent');
      expect(RaftLocation.parse('/s/acme/tasks?task=1').task, isNull);
    });

    test('legacy task permalink retains its own channel/task identity', () {
      final location = RaftLocation.parse(
        '/s/acme/tasks?legacyTask=channel-1%3Alegacy-task&filter=mine',
      );
      expect(location.legacyTask.toString(), 'channel-1:legacy-task');
      expect(
        location.withQuery({'profile': 'human:user-1'}).legacyTask.toString(),
        'channel-1:legacy-task',
      );
      expect(location.query('filter'), 'mine');
    });

    test('Activity thread URL has no channel-route parse gate', () {
      final location = RaftLocation.parse(
        '/s/acme/activity?filter=mentions&thread=channel-1:parent-1',
      );
      expect(location.route, RaftRoute.activity);
      expect(location.thread.toString(), 'channel-1:parent-1');
      final closed = location.withQuery({'thread': null});
      expect(closed.route, RaftRoute.activity);
      expect(closed.query('filter'), 'mentions');
      expect(closed.hasOverlay, isFalse);
    });

    test('search thread slot and parent anchor remain independent', () {
      final location = RaftLocation.parse(
        '/s/acme/search?q=reply&open=thread:thread-1&msg=reply-1&'
        'thread=channel-1:parent-1',
      );
      expect(location.content?.kind, RaftContentKind.thread);
      expect(location.content?.id, 'thread-1');
      expect(location.content?.messageId, 'reply-1');
      expect(location.thread.toString(), 'channel-1:parent-1');
      expect(location.query('q'), 'reply');
      expect(location.knownThreadChannelId, 'thread-1');
      expect(location.threadFocusedMessageId, 'reply-1');
    });

    test('parent message does not become a focused thread reply', () {
      final parentFocus = RaftLocation.parse(
        '/s/acme/channel/channel-1?thread=channel-1:parent-1&msg=parent-1',
      );
      expect(parentFocus.messageId, 'parent-1');
      expect(parentFocus.threadFocusedMessageId, isNull);
      expect(parentFocus.knownThreadChannelId, isNull);
      final replyFocus = parentFocus.withQuery({'msg': 'reply-2'});
      expect(replyFocus.threadFocusedMessageId, 'reply-2');
      expect(replyFocus.thread.toString(), 'channel-1:parent-1');
    });

    test('a channel content slot does not claim a known thread channel', () {
      final location = RaftLocation.parse(
        '/s/acme/search?open=channel:channel-9&thread=channel-1:parent-1',
      );
      expect(location.content?.id, 'channel-9');
      expect(location.knownThreadChannelId, isNull);
    });
  });

  group('Source rightPanelUrlSync.ts:451–537 panel history decisions', () {
    final cases =
        <
          ({
            String name,
            String initial,
            Map<String, String?> changes,
            RaftNavigationKind expected,
          })
        >[
          (
            name: 'first thread open pushes',
            initial: '?keep=1',
            changes: {'thread': 'channel-1:parent-1'},
            expected: RaftNavigationKind.push,
          ),
          (
            name: 'ordinary thread retarget replaces',
            initial: '?keep=1&thread=channel-1:parent-1',
            changes: {'thread': 'channel-1:parent-2'},
            expected: RaftNavigationKind.replace,
          ),
          (
            name: 'thread close replaces and preserves filters',
            initial: '?filter=mentions&thread=channel-1:parent-1',
            changes: {'thread': null},
            expected: RaftNavigationKind.replace,
          ),
          (
            name: 'first profile open pushes',
            initial: '?keep=1',
            changes: {'profile': 'agent:agent-1', 'agentTab': 'activity'},
            expected: RaftNavigationKind.push,
          ),
          (
            name: 'existing profile retarget replaces',
            initial: '?profile=agent:old-agent&agentTab=profile&keep=1',
            changes: {'profile': 'agent:new-agent', 'agentTab': null},
            expected: RaftNavigationKind.replace,
          ),
          (
            name: 'same-agent explicit tab does not create another overlay',
            initial: '?profile=agent:agent-1&agentTab=profile',
            changes: {'agentTab': 'activity'},
            expected: RaftNavigationKind.replace,
          ),
          (
            name: 'profile over side thread pushes its own entry',
            initial: '?thread=channel-1:parent-1',
            changes: {'profile': 'human:user-1'},
            expected: RaftNavigationKind.push,
          ),
          (
            name: 'task modal over thread pushes an independent entry',
            initial: '?msg=reply-1&thread=channel-1:parent-1',
            changes: {'task': 'channel-1:task-parent'},
            expected: RaftNavigationKind.push,
          ),
          (
            name: 'task modal without side thread pushes',
            initial: '',
            changes: {'task': 'channel-1:task-parent'},
            expected: RaftNavigationKind.push,
          ),
          (
            name: 'task close leaves the side thread and replaces',
            initial: '?thread=channel-1:parent-1&task=channel-1:task-parent',
            changes: {'task': null},
            expected: RaftNavigationKind.replace,
          ),
          (
            name: 'task retarget preserves replace semantics',
            initial: '?task=channel-1:task-parent',
            changes: {'task': 'channel-1:next-task'},
            expected: RaftNavigationKind.replace,
          ),
          (
            name: 'external identity first open pushes',
            initial: '',
            changes: {'profile': 'external:channel-1:message-1'},
            expected: RaftNavigationKind.push,
          ),
          (
            name: 'replacing thread with profile is a removal and replaces',
            initial: '?thread=channel-1:parent-1&keep=1',
            changes: {'thread': null, 'profile': 'human:user-1'},
            expected: RaftNavigationKind.replace,
          ),
          (
            name: 'legacy task first open pushes',
            initial: '?keep=1',
            changes: {'legacyTask': 'channel-1:legacy-task'},
            expected: RaftNavigationKind.push,
          ),
        ];
    for (final vector in cases) {
      test(vector.name, () {
        final origin = RaftLocation.parse('/s/acme/activity${vector.initial}');
        final next = origin.withQuery(vector.changes);
        expect(origin.panelNavigationKindTo(next), vector.expected);
        expect(next.query('keep'), origin.query('keep'));
        expect(next.query('filter'), origin.query('filter'));
      });
    }

    test('explicit replace mode suppresses a first overlay PUSH', () {
      final origin = RaftLocation.parse('/s/acme/activity?filter=mentions');
      final next = origin.withQuery({'thread': 'channel-1:parent-1'});
      expect(origin.panelNavigationKindTo(next), RaftNavigationKind.push);
      expect(
        origin.panelNavigationKindTo(next, replaceMode: true),
        RaftNavigationKind.replace,
      );
    });

    test('Activity thread View-in-channel REPLACE returns in one Back', () {
      // Source e2e back-navigation.spec.ts:113–141 and URL contract:837–872.
      // The route transition's replace decision is supplied by the host;
      // these helpers must retain the exact Activity origin underneath it.
      const activity = '/s/acme/activity?filter=mentions';
      const thread = '/s/acme/activity?filter=mentions&thread=c:p';
      const channel = '/s/acme/channel/c?msg=p';
      var entries = nextRaftNavigationEntries(
        {},
        RaftNavigationKind.replace,
        0,
        activity,
      );
      entries = nextRaftNavigationEntries(
        entries,
        RaftNavigationKind.push,
        1,
        thread,
      );
      entries = nextRaftNavigationEntries(
        entries,
        RaftNavigationKind.replace,
        1,
        channel,
      );
      final stack = raftNavigationStackFromEntries(entries, 1);
      expect(stack, [activity, channel]);
      expect(resolveRaftMobileBack(stack, '/s/acme'), isNull);
      expect(entries[0], activity);
      expect(entries.values, isNot(contains(thread)));
    });
  });

  group(
    'Source searchContentStore.ts:63–83 and rightPanelUrlSync.ts:391–419',
    () {
      for (final kind in RaftContentKind.values) {
        test('open=${kind.name} identifies its real picked entity', () {
          final location = RaftLocation.parse(
            '/s/acme/search?open=${kind.name}:entity&msg=message',
          );
          expect(location.content?.kind, kind);
          expect(location.content?.id, 'entity');
          expect(
            location.content?.messageId,
            [
                  RaftContentKind.channel,
                  RaftContentKind.dm,
                  RaftContentKind.thread,
                ].contains(kind)
                ? 'message'
                : isNull,
          );
        });
      }

      test('invalid content kind or missing identity cannot create a slot', () {
        for (final value in ['', 'channel:', ':id', 'unknown:id', 'channel']) {
          expect(RaftContentLocation.parse(value), isNull, reason: value);
        }
      });

      test('external identity requires exactly channel and message parts', () {
        for (final value in [
          'external:',
          'external:channel',
          'external::message',
          'external:channel:',
          'external:channel:message:extra',
          'unknown:id',
        ]) {
          expect(RaftProfileLocation.parse(value), isNull, reason: value);
        }
        expect(
          RaftProfileLocation.parse('human:user-1')?.kind,
          RaftProfileKind.human,
        );
        expect(
          RaftProfileLocation.parse('agent:agent-1')?.kind,
          RaftProfileKind.agent,
        );
      });
    },
  );

  group('Source live useMobileNav.ts:89–109 and mobileNavStore.ts:45–89', () {
    const tabRoots = {
      RaftMobileTab.chat: '/s/acme',
      RaftMobileTab.tasks: '/s/acme/tasks',
      RaftMobileTab.members: '/s/acme/members',
      RaftMobileTab.settings: '/s/acme/settings',
    };
    for (final tab in tabRoots.entries) {
      test(
        'tap ${tab.key.name} selects root even from its remembered detail',
        () {
          final detail = RaftLocation.parse(
            '/s/acme/agent/a?profile=human:h&agentTab=activity',
          );
          expect(detail.tabHome(tab.key).toString(), tab.value);
          expect(detail.tabHome(tab.key).hasOverlay, isFalse);
        },
      );
    }

    test(
      'Search and Activity belong to Chat, Computers belong to Settings',
      () {
        for (final route in ['search?q=x', 'activity', 'inbox', 'threads']) {
          expect(
            RaftLocation.parse('/s/acme/$route').mobileTab,
            RaftMobileTab.chat,
          );
        }
        for (final route in [
          'computers',
          'computer/m',
          'machine/m',
          'settings',
        ]) {
          expect(
            RaftLocation.parse('/s/acme/$route').mobileTab,
            RaftMobileTab.settings,
          );
        }
      },
    );

    test(
      'cold hydration strips exactly thread/profile, retaining task/query',
      () {
        final location = RaftLocation.parse(
          '/s/acme/tasks?creator=user%3Ah&thread=c:p&profile=agent:a&'
          'task=c:t&msg=r&keep=1',
        );
        final underlying = location.withoutMobileOverlays();
        expect(underlying.thread, isNull);
        expect(underlying.profile, isNull);
        expect(underlying.task.toString(), 'c:t');
        expect(underlying.messageId, 'r');
        expect(underlying.query('creator'), 'user:h');
        expect(underlying.query('keep'), '1');
      },
    );
  });

  group('new local location value contract', () {
    test('query changes preserve repeated unknown values and fragment', () {
      final location = RaftLocation.parse(
        '/s/acme/channel/c?keep=one&keep=two&thread=c:p#anchor',
      );
      final closed = location.withQuery({'thread': null});
      expect(closed.uri.queryParametersAll['keep'], ['one', 'two']);
      expect(closed.uri.fragment, 'anchor');
      expect(location.thread.toString(), 'c:p');
    });

    test('only local server-scoped paths enter this value', () {
      for (final path in [
        'https://example.invalid/s/acme',
        '//example.invalid/s/acme',
        's/acme',
        '/',
        '/settings',
      ]) {
        expect(
          () => RaftLocation.parse(path),
          throwsFormatException,
          reason: path,
        );
      }
    });

    test(
      'generated permalink encodes identifiers and query without losing them',
      () {
        final location = RaftLocation.at(
          serverSlug: 'acme',
          route: RaftRoute.dm,
          entityId: 'dm-1',
          query: {'msg': 'reply-1', 'thread': 'dm-1:parent-1'},
        );
        final decoded = RaftLocation.parse(location.toString());
        expect(decoded.route, RaftRoute.dm);
        expect(decoded.entityId, 'dm-1');
        expect(decoded.messageId, 'reply-1');
        expect(decoded.thread.toString(), 'dm-1:parent-1');
      },
    );
  });
}
