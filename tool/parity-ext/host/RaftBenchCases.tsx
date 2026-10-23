// raft-flutter parity EXTENSION cases: the RaftBench page (Web v1.21.23
// raftbench/RaftBenchPage.tsx). Ids: components.raftbench.<state>[.<region>].<theme>.
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtRaftbench`). The page is mounted by the ext-settings
// shell (host/SettingsCases.tsx: the settings rail and the page in the 1216px
// frame, the bare page at 390 on mobile) for an owner on a server enrolled in
// `raftbench_overview_v0`. Data: tool/parity-ext/fixtures/raftbench.json (every
// route lives in a `routeSets` entry); the Flutter provider reads the same file
// (cases/ext_raftbench.dart).
import parityExtRaftbenchFixture from "virtual:parity-ext/raftbench";

type ParityExtRaftbenchProps = {
  caseId: string;
  routeSet: string;
  mobile: boolean;
};

function parityExtRaftbenchProps(): ParityExtRaftbenchProps | null {
  const raw = parityExtRawCaseId();
  if (!raw.startsWith("components.raftbench.")) return null;
  const params = new URLSearchParams(window.location.search);
  if (params.get("extKind") !== "raftbench") return null;
  return { caseId: raw, routeSet: params.get("routeSet") ?? "", mobile: params.get("platform") === "mobile" };
}

// The settings rail derives its active row from the URL: put the route in place
// before the first render (see primeVisualRoutePath in the official host).
(function parityExtRaftbenchPrimeRoute() {
  if (typeof window === "undefined") return;
  if (!parityExtRaftbenchProps()) return;
  const path = `/s/${fxServer.slug}/raftbench`;
  if (window.location.pathname !== path) {
    window.history.replaceState(null, "", `${path}${window.location.search}`);
  }
})();

function parityExtRaftbenchElement() {
  const props = parityExtRaftbenchProps();
  if (!props) return null;
  void parityExtRaftbenchFixture;
  return (
    <ParityExtSettingsCaseView
      props={{ caseId: props.caseId, tab: "raftbench", role: "owner", flags: new Set(["raftbench"]), routeSet: props.routeSet, mobile: props.mobile }}
    />
  );
}
