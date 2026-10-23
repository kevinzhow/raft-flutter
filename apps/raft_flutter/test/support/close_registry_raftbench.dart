import 'close_surface.dart';

/// RaftBench: the start-date picker of the analysis settings.
const raftbenchSurfaces = <CloseSurface>[
  CloseSurface(
    'raftbench-date-picker',
    kind: SurfaceKind.popup,
    web: 'raftbench/HostedAnalysis.tsx native <input type="date"> picker: Esc, outside press',
    phone: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    fold: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    desktop: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    files: [
      '../../packages/raft_ui/lib/src/raftbench/raftbench_date_field.dart',
    ],
  ),
];
