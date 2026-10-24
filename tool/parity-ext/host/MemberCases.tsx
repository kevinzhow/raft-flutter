// raft-flutter parity EXTENSION cases (not part of the official case set):
// members directory, human / external profiles, agent detail tabs and the
// agent / member dialogs, Activity and Saved states.
//
// tool/parity-ext-web.mjs appends this file to a generated copy of the pinned
// packages/web/visual-testing/VisualTestingCases.tsx (the Source checkout is
// never edited), so it shares that module's imports and private fixture
// helpers (primeAgentDetailStores, fxServer, ...). Identifiers introduced here
// are prefixed `parityExtMb` / `ParityExtMb`. Ids:
//   components.members-ext.<key>.<theme>
// Each case mounts the REAL product component:
//   list      -> layout/Sidebar (members rail mode at /s/<slug>/members)
//   others    -> see parityExtMbView below
// Data: tool/parity-ext/fixtures/members.json (the Flutter provider reads the
// same file); its `routes` + the case's `routeSet` answer the API reads.
// MainLayout and the panels lazy-load these on first use; importing them here puts
// them in the host's module graph so a capture never races a chunk fetch (the
// Suspense fallback "Loading..." would be captured).
import "../src/components/agent/AgentActivityLog";
import "../src/components/agent/AgentMcpTab";
import "../src/components/agent/AgentSkills";
import "../src/components/member/HumanDetailPanel";
import "../src/components/profile/ExternalIdentityDetailPanel";
import parityExtMbActivityFixture from "../../visual-testing/shared/activityResultsFixture.json";
import parityExtMbFixture from "virtual:parity-ext/members";
import type { CSSProperties as ParityExtMbCSSProperties } from "react";

type ParityExtMbProps = {
  extCase: string;
  extKind: string;
  platform: "desktop" | "mobile";
  params: URLSearchParams;
};

function parityExtMbProps(): ParityExtMbProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.members-ext.")) return null;
  const extCase = params.get("extCase");
  const extKind = params.get("extKind");
  if (!extCase || !extKind) return null;
  return { extCase, extKind, platform: params.get("platform") === "mobile" ? "mobile" : "desktop", params };
}

// Route-based cases need the browser URL in place BEFORE BrowserRouter mounts.
(function parityExtMbPrimeRoute() {
  if (typeof window === "undefined") return;
  const props = parityExtMbProps();
  if (!props) return;
  const route = props.params.get("route");
  if (!route) return;
  const path = `/s/${fxServer.slug}${route}`;
  // Keep every case param (roster, humans, ...) next to the route's own query.
  const next = new URLSearchParams(props.params.get("routeQuery") ?? "");
  for (const [key, value] of props.params.entries()) {
    if (key !== "route" && key !== "routeQuery") next.set(key, value);
  }
  window.history.replaceState(null, "", `${path}?${next.toString()}`);
})();

type ParityExtMbAgent = Record<string, unknown> & { id: string };

function parityExtMbRoster(props: ParityExtMbProps): ParityExtMbAgent[] {
  const key = props.params.get("roster") ?? "default";
  return (parityExtMbFixture.rosters as Record<string, ParityExtMbAgent[]>)[key] ?? [];
}

function parityExtMbPrimeStores(props: ParityExtMbProps) {
  primeAgentDetailStores("screens.members.agent-detail.profile");
  // The Activity tab reads its rows from the case route (GET /agents/:id/activity-log) only: the official host's
  // primed trajectory rows would merge into them and show rows the Flutter fixture never has.
  useAgentStore.setState({ trajectoryLogs: {}, activityLogs: {} });
  const agents = parityExtMbRoster(props);
  const humans = (parityExtMbFixture.humans as Record<string, unknown>[]);
  const humanKey = props.params.get("humans") ?? "default";
  const humanRows = humanKey === "none" ? [] : humans;
  const loading = props.params.get("loading") === "true";
  useAgentStore.setState({
    agents: agents as never,
    agentActivities: Object.fromEntries(agents.map((a) => [a.id, {
      activity: a.activity,
      activityDetail: (a.activityDetail as string | null) ?? undefined,
      detailKind: "other",
    }])) as never,
    loading,
  });
  useServerStore.setState({ members: humanRows as never, membersLoadError: props.params.get("membersError") === "true" });
}

// The real app mounts these inside raft-ui AppShell, whose root sets
// `[--shell-header-height:62px]` (Brutal) / `56px` (Elegant).
function parityExtMbShellVars(): ParityExtMbCSSProperties {
  const theme = new URLSearchParams(window.location.search).get("parityTheme");
  return { ["--shell-header-height" as string]: "56px" } as ParityExtMbCSSProperties;
}

// InviteHumanDialog like the official host: owner (so `inviteMembers` holds) and the
// Guest server flag from the case.
function ParityExtMbInvite({ props, caseId }: { props: ParityExtMbProps; caseId: string }) {
  const guest = props.params.get("guest") === "true";
  useMemo(() => {
    useServerStore.setState({
      current: {
        id: fxServer.id, name: fxServer.name, avatarUrl: null, slug: fxServer.slug, ownerId: fxOwner.id,
        onboardingAgentId: null, hideHumansFromMembers: false, plan: "free", role: "owner",
      },
      billing: null,
      loadBilling: async () => {},
    } as never);
    setServerFeatureFlagForTests(fxServer.id, SERVER_GUEST_FEATURE_FLAG_KEY, guest);
  }, [guest]);
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={caseId} style={{ ...parityExtMbShellVars(), width: 1280, height: 800, overflow: "hidden" }}>
        <InviteHumanDialog onClose={() => undefined} />
      </div>
    </main>
  );
}

// Activity / Saved panels in the official 342x620 box.
function ParityExtMbResource({ props, caseId }: { props: ParityExtMbProps; caseId: string }) {
  const panel = props.params.get("panel");
  const state = props.params.get("state") ?? "results";
  useMemo(() => {
    primeDirectVisualStores("components.home.activity.results");
    const results = state === "results";
    useInboxStore.setState({
      items: (results ? parityExtMbActivityFixture.items : []) as never,
      filter: "all",
      loading: state === "loading",
      loadingMore: false,
      hasMore: false,
      totalCount: results ? parityExtMbActivityFixture.totalCount : 0,
      totalUnreadCount: results ? parityExtMbActivityFixture.totalUnreadCount : 0,
    });
    useSavedStore.setState({ saved: [], savedIds: new Set(), loading: state === "loading", hasMore: false, total: 0 });
  }, [state]);
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={caseId} style={{ width: 342, height: 620, overflow: "hidden", display: "flex", flexDirection: "column" }}>
        {panel === "saved" ? <SavedPanel /> : <ThreadsInbox />}
      </div>
    </main>
  );
}

function ParityExtMbView({ props }: { props: ParityExtMbProps }) {
  const caseId = new URLSearchParams(window.location.search).get("case") ?? "";
  if (props.extKind === "invite") return <ParityExtMbInvite props={props} caseId={caseId} />;
  if (props.extKind === "resource") return <ParityExtMbResource props={props} caseId={caseId} />;
  useMemo(() => parityExtMbPrimeStores(props), [props]);
  if (props.extKind === "list") {
    // Sidebar column of the desktop shell: 240 x viewport height.
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div data-visual-case={caseId} style={{ ...parityExtMbShellVars(), width: 240, height: 800, display: "flex", flexDirection: "column", overflow: "hidden" }}>
          <Routes>
            <Route path="/s/:serverSlug/*" element={<Sidebar />} />
          </Routes>
        </div>
      </main>
    );
  }
  if (props.extKind === "main") {
    // The real desktop shell (rail + Sidebar + panel frame) on a members route;
    // cases crop the main column (`thread-main-column`).
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div
          data-visual-case={caseId}
          style={{ width: window.innerWidth, height: window.innerHeight, overflow: "hidden", display: "flex", flexDirection: "column" }}
        >
          <Routes>
            <Route path="/s/:serverSlug/*" element={<MainLayout />} />
          </Routes>
        </div>
      </main>
    );
  }
  return null;
}

function parityExtMemberElement() {
  const props = parityExtMbProps();
  return props ? <ParityExtMbView props={props} /> : null;
}
