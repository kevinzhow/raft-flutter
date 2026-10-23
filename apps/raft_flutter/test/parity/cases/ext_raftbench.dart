// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the RaftBench
// page. NOT official cases; ids are `components.raftbench.<key>.<theme>`,
// dispatched on the props tool/parity-ext/host/RaftBenchCases.tsx mounts: the
// ext-settings shell on tab `raftbench` for an owner on an enrolled server.
//
// Data: tool/parity-ext/fixtures/raftbench.json (fixtures['ext:raftbench']),
// merged into the settings routes by ext_settings.dart.
import '../parity_harness.dart';
import 'ext_settings.dart';

final ParityCase _case = ParityCase(
  widgets: const [
    'raft_flutter:RaftbenchPage',
    'raft_flutter:RaftbenchManagerOverview',
    'raft_flutter:RaftbenchHostedAnalysis',
    'raft_flutter:WorkspaceSettings',
  ],
  notes: 'Extension suite (not official). RaftBench page (Web v1.21.23).',
  settle: const Duration(milliseconds: 1500),
  build: extSettingsPage,
);

const _states = [
  'disabled',
  'running',
  'ready',
  'stale',
  'skipped',
  'failed',
  'outside-window',
  'loading',
  'error',
];

/// Every RaftBench case, keyed by id (3 themes each).
final Map<String, ParityCase> extRaftbenchCases = {
  for (final theme in const ['brutal', 'elegant', 'elegant-dark']) ...{
    for (final state in _states) ...{
      'components.raftbench.page.$state.$theme': _case,
      'components.raftbench.page.$state-insights.$theme': _case,
    },
    for (final state in const ['disabled', 'ready']) ...{
      'components.raftbench.page.$state-mobile.$theme': _case,
      'components.raftbench.page.$state-insights-mobile.$theme': _case,
    },
  },
};
