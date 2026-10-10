// raft-flutter parity EXTENSION cases (not part of the official case set).
//
// tool/parity-ext-web.mjs appends this file to a generated copy of the pinned
// packages/web/visual-testing/VisualTestingCases.tsx (the Source checkout is
// never edited), so it shares that module's imports and private fixture
// helpers (primeDirectVisualStores, fxServer, ...). Identifiers introduced
// here are prefixed `parityExt` / `ParityExt` to stay clear of the host's.
// The default export dispatches here first (one anchored line); every other id
// falls through to the official registry unchanged.
//
// Each case mounts the REAL product component the Web desktop shell shows:
//   list   -> layout/Sidebar (computers rail mode at /s/<slug>/computers)
//   detail -> machine/MachineDetailPanel in the 976px desktop detail column
//   add    -> machine/AddMachineDialog
// Data comes from tool/parity-ext/fixtures/computers.json, which the Flutter
// provider reads too.
import ParityExtMachineDetailPanel from "../src/components/machine/MachineDetailPanel";
import ParityExtAddMachineDialog from "../src/components/machine/AddMachineDialog";
import parityExtFixture from "virtual:parity-ext/computers";
import type { CSSProperties as ParityExtCSSProperties } from "react";

const PARITY_EXT_THEME_SUFFIXES = [".elegant-dark", ".elegant", ".brutal"];

function parityExtRawCaseId(): string {
  return new URLSearchParams(window.location.search).get("case") ?? "";
}

type ParityExtProps = {
  extCase: string;
  extKind: "list" | "detail" | "add";
  list?: string;
  machine?: string;
  selected?: string;
  loading?: string;
  flags?: string;
};

function parityExtProps(): ParityExtProps | null {
  const raw = parityExtRawCaseId();
  if (!raw.startsWith("components.computers.")) return null;
  const params = new URLSearchParams(window.location.search);
  const extCase = params.get("extCase");
  const extKind = params.get("extKind") as ParityExtProps["extKind"] | null;
  if (!extCase || !extKind || !PARITY_EXT_THEME_SUFFIXES.some((s) => raw.endsWith(s))) return null;
  return {
    extCase,
    extKind,
    list: params.get("list") ?? undefined,
    machine: params.get("machine") ?? undefined,
    selected: params.get("selected") ?? undefined,
    loading: params.get("loading") ?? undefined,
  };
}

// The rail list reads its mode from the URL (useRailMode); put the route in
// place before the first render, like the official primeVisualRoutePath().
(function parityExtPrimeRoute() {
  if (typeof window === "undefined") return;
  const props = parityExtProps();
  if (!props || props.extKind !== "list") return;
  const path = props.selected
    ? `/s/${fxServer.slug}/computer/${props.selected}`
    : `/s/${fxServer.slug}/computers`;
  if (window.location.pathname !== path) {
    window.history.replaceState(null, "", `${path}${window.location.search}`);
  }
})();

function parityExtMachines(list: string | undefined): Machine[] {
  const ids: string[] = (parityExtFixture.lists as Record<string, string[]>)[list ?? "default"] ?? [];
  return ids.map((id) => (parityExtFixture.machines as Record<string, Machine>)[id]);
}

function parityExtPrimeStores(props: ParityExtProps) {
  primeDirectVisualStores(parityExtRawCaseId());
  const machines = parityExtMachines(props.list);
  const detailMachine = props.machine
    ? (parityExtFixture.machines as Record<string, Machine>)[props.machine]
    : null;
  useMachineStore.setState({
    // The detail machine is part of the list the page loaded.
    // A detail variant (e.g. the one-click upgrade projection of computer-mbp)
    // replaces the list row with the same id.
    machines: detailMachine ? machines.map((m) => (m.id === detailMachine.id ? detailMachine : m)) : machines,
    latestComputerVersion: parityExtFixture.latestComputerVersion,
    latestComputerReleaseNotes: null,
    loading: props.loading === "true",
    selectedMachineId: props.selected ?? props.machine ?? null,
    showAddMachine: false,
    pendingApiKey: null,
    pendingMachineId: null,
    machineWorkspaces: {},
    machineWorkspacesLoading: {},
    computerOperationProgress: {},
  });
  const agents = parityExtFixture.agents.map((a) => ({
    ...visualAgents.find((v) => v.id === a.id),
    ...a,
    serverId: fxServer.id,
  }));
  useAgentStore.setState({
    agents: agents as never,
    agentActivities: Object.fromEntries(parityExtFixture.agents.map((a) => [a.id, {
      activity: a.activity,
      activityDetail: a.activityDetail ?? undefined,
      detailKind: "other",
    }])) as never,
  });
  if (props.machine?.endsWith("-one-click")) {
    setServerFeatureFlagForTests(fxServer.id, "remote_computer_upgrade_v2", true);
  }
}

// The real app mounts these inside raft-ui AppShell, whose root sets
// `[--shell-header-height:62px]` (Brutal) / `56px` (Elegant); Sidebar's
// `h-panel-header` reads it (index.css defaults to 62px without the shell).
function parityExtShellVars(): ParityExtCSSProperties {
  const theme = new URLSearchParams(window.location.search).get("parityTheme");
  return { ["--shell-header-height" as string]: theme === "brutal-light" ? "62px" : "56px" } as ParityExtCSSProperties;
}

function ParityExtCaseView({ props }: { props: ParityExtProps }) {
  const caseId = parityExtRawCaseId();
  useMemo(() => parityExtPrimeStores(props), [props]);
  if (props.extKind === "list") {
    // Sidebar column of the desktop shell: 240 x viewport height.
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div data-visual-case={caseId} style={{ ...parityExtShellVars(), width: 240, height: 800, display: "flex", flexDirection: "column", overflow: "hidden" }}>
          <Routes>
            <Route path="/s/:serverSlug/*" element={<Sidebar />} />
          </Routes>
        </div>
      </main>
    );
  }
  if (props.extKind === "add") {
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div data-visual-case={caseId} style={{ ...parityExtShellVars(), width: 1280, height: 800 }}>
          <ParityExtAddMachineDialog onClose={() => undefined} />
        </div>
      </main>
    );
  }
  const machineId = (parityExtFixture.machines as Record<string, Machine>)[props.machine ?? ""]?.id;
  const machine = useMachineStore((s) => s.machines.find((m) => m.id === machineId));
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      {/* Desktop detail column: 1280 - 64 rail - 240 sidebar. */}
      {/* MainLayout's content column paints `bg-layer-canvas-muted` behind the
          panel (its PanelHeader is transparent in Elegant). */}
      <div
        data-visual-case={caseId}
        className="bg-layer-canvas-muted theme-brutal:bg-white"
        style={{ ...parityExtShellVars(), width: 976, height: window.innerHeight, display: "flex", flexDirection: "column", overflow: "hidden" }}
      >
        {machine ? <ParityExtMachineDetailPanel machine={machine} /> : null}
      </div>
    </main>
  );
}

function parityExtCaseElement() {
  const props = parityExtProps();
  return props ? <ParityExtCaseView props={props} /> : null;
}
