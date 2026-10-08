import 'package:flutter_test/flutter_test.dart';

import 'package:raft_flutter/features/agent_metadata_projection.dart';
import 'package:raft_flutter/features/agent_metadata_catalog.dart';

const scope = (
  origin: 'https://public.example',
  principal: 'user',
  server: 'server',
  authorityRevision: 1,
);
const otherScope = (
  origin: 'https://public.example',
  principal: 'other',
  server: 'server',
  authorityRevision: 1,
);
const revokedScope = (
  origin: 'https://public.example',
  principal: 'user',
  server: 'server',
  authorityRevision: 2,
);
const agent = AgentPresentationIdentity(
  id: 'agent',
  status: 'active',
  runtime: 'codex',
  model: 'gpt-5-codex',
  machineId: 'machine',
  description: 'Public identity description',
);
final now = DateTime.utc(2026, 10, 8, 12);
AgentAmbientProjection projection() =>
    AgentAmbientProjection(scope)..replaceAuthorizedDirectory(scope, [agent]);

void main() {
  test(
    'managed no-entry fallback is online, REST hydration fallback is working',
    () {
      expect(
        resolveAgentAmbientDisplay(identity: agent, now: now).activity,
        'online',
      );
      expect(
        normalizeAgentSnapshotActivity(status: 'active').activity,
        'working',
      );
      expect(
        normalizeAgentSnapshotActivity(status: 'stopped').activity,
        'offline',
      );
      expect(
        normalizeAgentSnapshotActivity(
          status: 'active',
          activity: 'working',
          activityKind: 'offline',
        ).activity,
        'offline',
      );
    },
  );
  test(
    'managed terminal activity remains indefinitely, independent of ticker age',
    () {
      final p = projection();
      p.apply(
        expected: scope,
        agentId: 'agent',
        activity: 'offline',
        detailKind: 'stopped',
        serverSeq: 10,
      );
      expect(
        p.display('agent', now.add(const Duration(days: 2)))!.activity,
        'offline',
      );
      expect(
        p.display('agent', now.add(const Duration(days: 2)))!.online,
        false,
      );
      p.apply(
        expected: scope,
        agentId: 'agent',
        activity: 'working',
        serverSeq: 11,
      );
      expect(
        p.display('agent', now.add(const Duration(days: 2)))!.activity,
        'working',
      );
    },
  );
  test('stopped fallback carries stopped detail and deleted identity suppresses badge', () {
    final stopped = resolveAgentAmbientDisplay(
      identity: const AgentPresentationIdentity(
        id: 'a',
        status: 'stopped',
        deleted: true,
      ),
      now: now,
    );
    expect(stopped.detailKind, 'stopped');
    expect(stopped.showPresence, false);
    final deletedWorking = resolveAgentAmbientDisplay(
      identity: const AgentPresentationIdentity(
        id: 'a',
        status: 'active',
        deleted: true,
      ),
      now: now,
      current: const AgentAmbientActivity(activity: 'working'),
    );
    expect(deletedWorking.activity, 'working');
    expect(deletedWorking.showPresence, false);
  });
  test(
    'external has strict 120 second seen boundary and explicit offline wins',
    () {
      AgentPresentationIdentity external(int age) => AgentPresentationIdentity(
        id: 'a',
        status: 'active',
        runtime: 'external',
        lastSeenAt: now.subtract(Duration(milliseconds: age)),
      );
      expect(
        resolveAgentAmbientDisplay(identity: external(119999), now: now).online,
        true,
      );
      expect(
        resolveAgentAmbientDisplay(identity: external(120000), now: now).online,
        false,
      );
      final stopped = resolveAgentAmbientDisplay(
        identity: external(0),
        now: now,
        current: const AgentAmbientActivity(activity: 'offline'),
      );
      expect(stopped.external, true);
      expect(stopped.online, false);
      final aged = resolveAgentAmbientDisplay(
        identity: external(120000),
        now: now,
        current: const AgentAmbientActivity(activity: 'working'),
      );
      expect(aged.activity, 'offline');
      expect(
        resolveAgentAmbientDisplay(
          identity: const AgentPresentationIdentity(
            id: 'a',
            status: 'active',
            external: true,
          ),
          now: now,
        ).online,
        false,
      );
    },
  );
  test('external flag and runtime both admit external rule, future seen matches source', () {
    final flag = AgentPresentationIdentity(
      id: 'a',
      status: 'stopped',
      external: true,
      lastSeenAt: now.add(const Duration(seconds: 1)),
    );
    expect(
      resolveAgentAmbientDisplay(identity: flag, now: now).activity,
      'online',
    );
  });
  test('unknown directory identity never borrows ambient state', () {
    final p = projection();
    expect(
      p.apply(expected: scope, agentId: 'foreign', activity: 'working'),
      AgentAmbientApply.unauthorized,
    );
    expect(p.display('foreign', now), isNull);
  });
  test('per-agent server seq wins over late arrival, launch does not reset its baseline', () {
    final p = projection();
    p.apply(
      expected: scope,
      agentId: 'agent',
      activity: 'offline',
      serverSeq: 10,
      launchId: 'old',
    );
    expect(
      p.apply(
        expected: scope,
        agentId: 'agent',
        activity: 'working',
        serverSeq: 9,
        launchId: 'new',
      ),
      AgentAmbientApply.stale,
    );
    expect(p.display('agent', now)!.activity, 'offline');
    expect(
      p.apply(
        expected: scope,
        agentId: 'agent',
        activity: 'thinking',
        serverSeq: 11,
        launchId: 'new',
      ),
      AgentAmbientApply.applied,
    );
    expect(p.display('agent', now)!.activity, 'thinking');
  });
  test('equal seq conflicting activity requests reconcile without replacing current', () {
    final p = projection();
    p.apply(
      expected: scope,
      agentId: 'agent',
      activity: 'working',
      serverSeq: 3,
    );
    expect(
      p.apply(
        expected: scope,
        agentId: 'agent',
        activity: 'error',
        serverSeq: 3,
      ),
      AgentAmbientApply.conflict,
    );
    expect(p.display('agent', now)!.activity, 'working');
  });
  test('equal seq upgrades fallback detail kind but not typed authority', () {
    final p = projection();
    p.apply(
      expected: scope,
      agentId: 'agent',
      activity: 'working',
      detail: 'Public work',
      serverSeq: 3,
    );
    expect(
      p.apply(
        expected: scope,
        agentId: 'agent',
        activity: 'working',
        detail: 'Public work',
        detailKind: 'running_command',
        serverSeq: 3,
      ),
      AgentAmbientApply.applied,
    );
    expect(p.display('agent', now)!.detailKind, 'running_command');
    expect(
      p.apply(
        expected: scope,
        agentId: 'agent',
        activity: 'working',
        detail: 'Public work',
        serverSeq: 3,
      ),
      AgentAmbientApply.conflict,
    );
  });
  test('legacy no-seq frames are accepted, invalid activity does not replace current', () {
    final p = projection();
    p.apply(
      expected: scope,
      agentId: 'agent',
      activity: 'working',
      serverSeq: 3,
    );
    expect(
      p.apply(expected: scope, agentId: 'agent', activity: 'offline'),
      AgentAmbientApply.applied,
    );
    expect(
      p.apply(expected: scope, agentId: 'agent', activity: 'invented'),
      AgentAmbientApply.invalid,
    );
    expect(p.display('agent', now)!.activity, 'offline');
  });
  test(
    'reconnect resets producer baseline without clearing materialized activity',
    () {
      final p = projection();
      p.apply(
        expected: scope,
        agentId: 'agent',
        activity: 'offline',
        serverSeq: 10,
      );
      p.resetSequenceBaseline();
      expect(p.display('agent', now)!.activity, 'offline');
      expect(
        p.apply(
          expected: scope,
          agentId: 'agent',
          activity: 'online',
          serverSeq: 1,
        ),
        AgentAmbientApply.applied,
      );
    },
  );
  test('snapshot cannot overwrite newer changed socket current', () {
    final p = projection();
    final request = p.beginSnapshot();
    p.apply(
      expected: scope,
      agentId: 'agent',
      activity: 'offline',
      serverSeq: 4,
    );
    expect(
      p.hydrate(request, {
        'agent': const AgentAmbientActivity(activity: 'working'),
      }),
      true,
    );
    expect(p.display('agent', now)!.activity, 'offline');
    expect(
      p.apply(
        expected: scope,
        agentId: 'agent',
        activity: 'online',
        serverSeq: 1,
      ),
      AgentAmbientApply.applied,
    );
  });
  test(
    'new REST snapshot supersedes old REST and removes unauthorized IDs',
    () {
      final p = projection();
      final first = p.beginSnapshot();
      final second = p.beginSnapshot();
      expect(
        p.hydrate(first, {
          'agent': const AgentAmbientActivity(activity: 'working'),
        }),
        false,
      );
      expect(
        p.hydrate(second, {
          'agent': const AgentAmbientActivity(activity: 'offline'),
        }),
        true,
      );
      p.replaceAuthorizedDirectory(scope, []);
      expect(p.display('agent', now), isNull);
      expect(
        p.apply(expected: scope, agentId: 'agent', activity: 'working'),
        AgentAmbientApply.unauthorized,
      );
    },
  );
  test('account and same-generation authority revision reject late snapshot and events', () {
    final p = projection();
    final request = p.beginSnapshot();
    p.adopt(revokedScope);
    expect(
      p.hydrate(request, {
        'agent': const AgentAmbientActivity(activity: 'working'),
      }),
      false,
    );
    expect(
      p.apply(expected: scope, agentId: 'agent', activity: 'working'),
      AgentAmbientApply.unauthorized,
    );
    p.replaceAuthorizedDirectory(revokedScope, [agent]);
    p.apply(expected: revokedScope, agentId: 'agent', activity: 'offline');
    p.adopt(otherScope);
    expect(p.display('agent', now), isNull);
  });
  test('same scope adoption preserves current; unauthorized directory replacement ignored', () {
    final p = projection();
    p.apply(expected: scope, agentId: 'agent', activity: 'thinking');
    p.adopt(scope);
    p.replaceAuthorizedDirectory(otherScope, []);
    expect(p.display('agent', now)!.activity, 'thinking');
  });
  test('static label exact source generated table, unknown stays raw and default ON', () {
    expect(sourceRuntimeModelLabels.length, 13);
    expect(
      sourceRuntimeModelLabels.values.fold<int>(0, (n, m) => n + m.length),
      616,
    );
    expect(
      agentPresentationModelLabel(scope: scope, identity: agent),
      'GPT-5 Codex',
    );
    expect(
      agentPresentationModelLabel(
        scope: scope,
        identity: const AgentPresentationIdentity(
          id: 'a',
          status: 'active',
          runtime: 'unknown',
          model: 'literal-model',
        ),
      ),
      'literal-model',
    );
    expect(
      agentPresentationModelLabel(
        scope: scope,
        identity: agent,
        showModelName: false,
      ),
      isNull,
    );
  });
  test('catalog wins only for same full scope machine/runtime/model, malformed empty falls back', () {
    final machines = {
      'machine': {
        'codex': {'gpt-5-codex': 'Daemon-provided label'},
      },
    };
    final catalog = AgentModelLabelCatalog(scope: scope, machines: machines);
    machines['machine']!['codex']!['gpt-5-codex'] = 'Mutated';
    expect(
      agentPresentationModelLabel(
        scope: scope,
        identity: agent,
        catalog: catalog,
      ),
      'Daemon-provided label',
    );
    expect(
      agentPresentationModelLabel(
        scope: otherScope,
        identity: agent,
        catalog: catalog,
      ),
      'GPT-5 Codex',
    );
    expect(
      agentPresentationModelLabel(
        scope: revokedScope,
        identity: agent,
        catalog: catalog,
      ),
      'GPT-5 Codex',
    );
    expect(
      agentPresentationModelLabel(
        scope: scope,
        identity: agent,
        catalog: AgentModelLabelCatalog(
          scope: scope,
          machines: {
            'machine': {
              'codex': {'gpt-5-codex': ''},
            },
          },
        ),
      ),
      'GPT-5 Codex',
    );
  });
  test('subtitle uses identity description or translated human role, never model/Agent', () {
    expect(agentPresentationSubtitle(agent), 'Public identity description');
    expect(
      agentPresentationSubtitle(
        const AgentPresentationIdentity(
          id: 'a',
          status: 'active',
          runtime: 'codex',
        ),
      ),
      isNull,
    );
    expect(
      humanPresentationSubtitle(
        description: 'Identity text',
        localizedRole: 'Owner',
      ),
      'Identity text',
    );
    expect(humanPresentationSubtitle(localizedRole: 'Owner'), 'Owner');
    expect(humanPresentationSubtitle(), isNull);
  });
}
