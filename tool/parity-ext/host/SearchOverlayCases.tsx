// raft-flutter parity EXTENSION cases: the desktop search overlay (not part of
// the official case set). Appended to the generated VisualTestingCases module
// after ComputerCases.tsx, so it shares that module's imports and private
// fixture helpers (primeDirectVisualStores, fxServer, visualAgents, ...).
// Identifiers introduced here are prefixed `parityExtSearch` / `ParityExtSearch`;
// tool/parity-ext-web.mjs asks `parityExtSearchOverlayElement()` after the
// other families; it returns null for ids that are not search-overlay cases.
//
// Each case mounts the REAL <SearchOverlay> (Modal + PopoverPopup +
// MessageSearchPage with activateResultsInChat + overlayChrome) at the route
// /s/<slug>/search, over the official primed stores plus the extra catalog in
// tool/parity-ext/fixtures/search-overlay.json (the Flutter provider reads the
// same file). Without a desktop shell the card is position:fixed, width
// min(720px, 92vw), height min(680px, 80vh), top max(8vh + 16px, (100vh - h)/2).
// The query is typed by the case's interactions; /messages/search is answered
// by the generated provider spec from fixture.search (tool/parity-ext/run).
import { SearchOverlay as ParityExtSearchOverlay } from "../src/features/search/SearchOverlay";
import { useRecentConversationStore as useParityExtSearchRecentStore } from "../src/store/recentConversationStore";
import parityExtSearchFixture from "virtual:parity-ext/search-overlay";

type ParityExtSearchProps = {
  extCase: string;
  recents: "default" | "empty";
  senderId?: string;
};

function parityExtSearchProps(): ParityExtSearchProps | null {
  const raw = new URLSearchParams(window.location.search).get("case") ?? "";
  if (!raw.startsWith("components.search-overlay.")) return null;
  const params = new URLSearchParams(window.location.search);
  const extCase = params.get("extCase");
  if (!extCase || params.get("extKind") !== "search-overlay") return null;
  return {
    extCase,
    recents: params.get("recents") === "empty" ? "empty" : "default",
    senderId: params.get("senderId") ?? undefined,
  };
}

// MessageSearchPage reads its committed state from the URL (and seeds
// `senderId` from it); put /s/<slug>/search in place before BrowserRouter
// mounts, like the official primeVisualRoutePath().
(function parityExtSearchPrimeRoute() {
  if (typeof window === "undefined") return;
  const props = parityExtSearchProps();
  if (!props) return;
  const path = `/s/${fxServer.slug}/search`;
  if (window.location.pathname === path) return;
  window.history.replaceState(null, "", `${path}${window.location.search}`);
})();

function parityExtSearchPrimeStores(props: ParityExtSearchProps) {
  const f = parityExtSearchFixture;
  primeDirectVisualStores(new URLSearchParams(window.location.search).get("case") ?? undefined);
  const scenario = (f.recentScenarios as Record<string, { channelIds: string[]; activity: Record<string, string> }>)[props.recents];
  useChannelStore.setState({
    channels: f.channels.map((c) => ({
      id: c.id,
      serverId: fxServer.id,
      name: c.name,
      description: c.description,
      type: "channel" as const,
      createdAt: c.createdAt,
      joined: true,
    })),
    dmChannels: f.dmChannels.map((c) => ({
      id: c.id,
      serverId: fxServer.id,
      name: c.name,
      description: null,
      type: "dm" as const,
      createdAt: c.createdAt,
      peerType: c.peerType as "agent" | "user",
      peerId: c.peerId,
      peerName: c.peerName,
      peerDisplayName: c.peerDisplayName,
      peerDescription: c.peerDescription,
    })),
    channelActivity: scenario.activity,
    loading: false,
  });
  useServerStore.setState({
    members: f.members.map((m) => ({
      userId: m.userId,
      serverId: fxServer.id,
      email: m.email,
      gravatarHash: "",
      name: m.name,
      displayName: m.displayName,
      description: m.description,
      avatarUrl: null,
      role: m.role as "owner" | "member",
      joinedAt: fxTimes.memberJoinedAtIso,
    })),
  });
  useAgentStore.setState({
    agents: f.agents.map((a) => ({
      ...visualAgents[0],
      id: a.id,
      serverId: fxServer.id,
      name: a.name,
      displayName: a.displayName,
      avatarUrl: a.avatarUrl,
      description: a.description,
    })) as never,
    agentActivities: Object.fromEntries(f.agents.map((a) => [a.id, {
      activity: a.activity,
      activityDetail: a.activityDetail ?? undefined,
      detailKind: "other",
    }])) as never,
  });
  // The visit history the overlay's empty state lists (most recent first),
  // under the same scope key the app writes (`<serverId>:<userId>`).
  useParityExtSearchRecentStore.setState({
    scopes: scenario.channelIds.length > 0
      ? { [`${fxServer.id}:${fxOwner.id}`]: { channelIds: scenario.channelIds, lastTouchedAt: 1 } }
      : {},
  });
}

function ParityExtSearchCaseView({ props }: { props: ParityExtSearchProps }) {
  const caseId = new URLSearchParams(window.location.search).get("case") ?? "";
  useMemo(() => parityExtSearchPrimeStores(props), [props]);
  return (
    <main className="min-h-screen bg-layer-canvas-muted p-0 font-display text-black theme-brutal:bg-white">
      <div data-visual-case={caseId} style={{ width: 1280, height: 800 }}>
        <ParityExtSearchOverlay onClose={() => undefined} />
      </div>
    </main>
  );
}

function parityExtSearchOverlayElement() {
  const props = parityExtSearchProps();
  return props ? <ParityExtSearchCaseView props={props} /> : null;
}
