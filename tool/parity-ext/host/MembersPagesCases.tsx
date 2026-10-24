// raft-flutter parity EXTENSION cases: members / agents / humans PAGES that had no case (not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// packages/web/visual-testing/VisualTestingCases.tsx, so it shares that module's
// imports and private fixture helpers (primeAgentDetailStores, fxServer, fxOwner,
// useAgentStore, useServerStore, MainLayout, InviteHumanDialog, ...). Identifiers
// introduced here are prefixed `parityExtMp` / `ParityExtMp`. Ids:
//   components.members-pages.<platform>.<key>.<theme>      (platform = desktop | phone)
// Kinds (props.extKind):
//   main    the REAL MainLayout shell on the case route (desktop 1280x800 or the 390x844 phone page)
//   invite  InviteHumanDialog alone in a boxW x boxH page (the official host's way)
//   report  ReportIssueDialog alone (gated on VITE_FEEDBACK_EXPORT_URL in the Web build)
// Data: tool/parity-ext/fixtures/members-pages.json (the Flutter provider reads the same file);
// its `routes` + the case's `routeSet` answer the API reads.
import "../src/components/agent/AgentActivityLog";
import "../src/components/agent/AgentMcpTab";
import "../src/components/agent/AgentSkills";
import "../src/components/agent/AgentUnavailablePanel";
import "../src/components/member/HumanDetailPanel";
import "../src/components/profile/ExternalIdentityDetailPanel";
import "../src/components/settings/MemberGraphSection";
import ParityExtMpReportIssueDialog from "../src/components/agent/ReportIssueDialog";
import parityExtMpFixture from "virtual:parity-ext/members-pages";
import { CHANNEL_MANAGER_ROLE_ACTIONS_FEATURE_FLAG_KEY as parityExtMpRoleActionsKey } from "@botiverse/raft-shared";
import { useLayoutEffect as parityExtMpUseLayoutEffect } from "react";
import type { CSSProperties as ParityExtMpCSSProperties, ReactNode as ParityExtMpReactNode } from "react";

type ParityExtMpProps = {
  extCase: string;
  extKind: string;
  params: URLSearchParams;
};

function parityExtMpProps(): ParityExtMpProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.members-pages.")) return null;
  const extCase = params.get("extCase");
  const extKind = params.get("extKind");
  if (!extCase || !extKind) return null;
  return { extCase, extKind, params };
}

// Route-based cases need the browser URL in place BEFORE BrowserRouter mounts.
(function parityExtMpPrimeRoute() {
  if (typeof window === "undefined") return;
  const props = parityExtMpProps();
  if (!props) return;
  const route = props.params.get("route");
  if (!route) return;
  const path = `/s/${fxServer.slug}${route}`;
  const next = new URLSearchParams(props.params.get("routeQuery") ?? "");
  for (const [key, value] of props.params.entries()) {
    if (key !== "route" && key !== "routeQuery") next.set(key, value);
  }
  window.history.replaceState(null, "", `${path}?${next.toString()}`);
})();

type ParityExtMpAgent = Record<string, unknown> & { id: string };

function parityExtMpPrimeStores(props: ParityExtMpProps) {
  primeAgentDetailStores("screens.members.agent-detail.profile");
  // The Activity tab reads its rows from the case route (GET /agents/:id/activity-log) only: the official host's
  // primed trajectory rows would merge into them and show rows the Flutter fixture never has.
  useAgentStore.setState({ trajectoryLogs: {}, activityLogs: {} });
  const rosterKey = props.params.get("roster") ?? "default";
  const agents = ((parityExtMpFixture.rosters as Record<string, ParityExtMpAgent[]>)[rosterKey] ?? []);
  const humans = parityExtMpFixture.humans as Record<string, unknown>[];
  const humanRows = props.params.get("humans") === "none" ? [] : humans;
  useAgentStore.setState({
    agents: agents as never,
    agentActivities: Object.fromEntries(agents.map((a) => [a.id, {
      activity: a.activity,
      activityDetail: (a.activityDetail as string | null) ?? undefined,
      detailKind: "other",
    }])) as never,
    loading: props.params.get("loading") === "true",
  });
  useServerStore.setState({ members: humanRows as never, membersLoadError: props.params.get("membersError") === "true" });
}

// The real app mounts these inside raft-ui AppShell, whose root sets
// `[--shell-header-height:62px]` (Brutal) / `56px` (Elegant).
function parityExtMpShellVars(): ParityExtMpCSSProperties {
  const theme = new URLSearchParams(window.location.search).get("parityTheme");
  return { ["--shell-header-height" as string]: "56px" } as ParityExtMpCSSProperties;
}

function ParityExtMpDialogBox({ props, caseId, children }: { props: ParityExtMpProps; caseId: string; children: ParityExtMpReactNode }) {
  const width = Number(props.params.get("boxW") ?? 1280);
  const height = Number(props.params.get("boxH") ?? 800);
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={caseId} style={{ ...parityExtMpShellVars(), width, height, overflow: "hidden" }}>
        {children}
      </div>
    </main>
  );
}

// InviteHumanDialog like the official host: owner (so `inviteMembers` holds) and the
// Guest server flag from the case.
function ParityExtMpInvite({ props, caseId }: { props: ParityExtMpProps; caseId: string }) {
  const guest = props.params.get("guest") === "true";
  useMemo(() => {
    useServerStore.setState({
      current: {
        id: fxServer.id, name: fxServer.name, avatarUrl: null, slug: fxServer.slug, ownerId: fxOwner.id,
        onboardingAgentId: null, hideHumansFromMembers: false, plan: "free", role: "owner",
      },
      billing: props.params.get("seatLimit") === "true"
        ? {
            plan: "free", displayName: "Free", serverPlan: "free", source: "server",
            capacity: { maxHumans: 2, maxAgents: 2, maxUniversalSeats: -1 },
            usage: { humans: 2, agents: 2, universalSeats: 0 },
          }
        : null,
      loadBilling: async () => {},
    } as never);
    setServerFeatureFlagForTests(fxServer.id, SERVER_GUEST_FEATURE_FLAG_KEY, guest);
  }, [guest, props]);
  return (
    <ParityExtMpDialogBox props={props} caseId={caseId}>
      <InviteHumanDialog onClose={() => undefined} />
    </ParityExtMpDialogBox>
  );
}

function ParityExtMpReport({ props, caseId }: { props: ParityExtMpProps; caseId: string }) {
  useMemo(() => parityExtMpPrimeStores(props), [props]);
  const agent = (parityExtMpFixture.rosters as Record<string, ParityExtMpAgent[]>).default[0];
  return (
    <ParityExtMpDialogBox props={props} caseId={caseId}>
      <ParityExtMpReportIssueDialog agent={agent as never} onClose={() => undefined} feedbackExportUrl="https://feedback.example.test" />
    </ParityExtMpDialogBox>
  );
}

// The channel-settings drawer's members page (host/ChannelSettingsCases.tsx ParityExtCsView, which owns the
// stores, the ChatPanel mount and the shell sizing) with the channel-manager role actions flag on. The
// case props are the channel-settings case's (channel, role, guestFlag); the interactions open the page.
function ParityExtMpChannel({ props }: { props: ParityExtMpProps }) {
  const params = props.params;
  const csProps = {
    extCase: props.extCase,
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    channel: params.get("channel") ?? "",
    role: params.get("role") ?? "owner",
    guestFlag: params.get("guestFlag") === "true",
    pinned: params.get("pinned") === "true",
  };
  useMemo(() => setServerFeatureFlagForTests(fxServer.id, parityExtMpRoleActionsKey, true), []);
  parityExtMpUseLayoutEffect(() => {
    setServerFeatureFlagForTests(fxServer.id, parityExtMpRoleActionsKey, true);
  }, []);
  return <ParityExtCsView props={csProps as never} />;
}

function ParityExtMpView({ props }: { props: ParityExtMpProps }) {
  const caseId = new URLSearchParams(window.location.search).get("case") ?? "";
  if (props.extKind === "channel") return <ParityExtMpChannel props={props} />;
  if (props.extKind === "invite") return <ParityExtMpInvite props={props} caseId={caseId} />;
  if (props.extKind === "report") return <ParityExtMpReport props={props} caseId={caseId} />;
  useMemo(() => parityExtMpPrimeStores(props), [props]);
  // The real shell (desktop: rail + Sidebar + panel frame; phone: the mobile page) on the case route.
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

function parityExtMembersPagesElement() {
  const props = parityExtMpProps();
  return props ? <ParityExtMpView props={props} /> : null;
}
