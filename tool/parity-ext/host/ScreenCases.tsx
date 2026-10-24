// raft-flutter parity EXTENSION cases: composed screens (not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtSc`). Ids: components.screens-ext.<surface>.<platform>.<state>.<theme>
// (tool/parity-ext/build-screen-cases.py).
//
// Desktop channel / DM / composer cases mount the REAL shell the Web app shows
// at 1280x800 (MainLayout's composition): raft-ui AppShellRoot with LeftRail,
// Sidebar and the main slot holding ChatPanel (thread-main-column). The Activity
// case replaces the sidebar + chat with the populated ThreadsInbox (the activity
// landing, no sidebar column). Mobile cases mount ChatPanel in the 390x844 page.
// Sidebar/rail data = tool/parity-ext/fixtures/shell.json (preset default, with the
// selected conversation read); messages / inbox rows = fixtures/screens.json
// `scenes[<scene>].routes` (the provider spec answers them for React, the fake
// client for Flutter). `win` crops a window with a transparent marker
// `screen-window` (the capture selector); popovers render in portals, so the
// crop is a page region, not a clipping container.
import {
  AppShellMainSlot as ParityExtScMainSlot,
  AppShellRailSlot as ParityExtScRailSlot,
  AppShellRoot as ParityExtScRoot,
  AppShellSidebarSlot as ParityExtScSidebarSlot,
} from "raft-ui";
import { LeftRail as ParityExtScLeftRail } from "../src/components/layout/LeftRail";
import parityExtScFixture from "virtual:parity-ext/screens";
import parityExtScShell from "virtual:parity-ext/shell";
import parityExtScActivity from "../../visual-testing/shared/activityResultsFixture.json";
import type { CSSProperties as ParityExtScCSSProperties } from "react";

type ParityExtScProps = {
  raw: string;
  platform: "desktop" | "mobile";
  scene: string;
  theme: string;
  win: string;
};

function parityExtScProps(): ParityExtScProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.screens-ext.") || params.get("extKind") !== "screens") return null;
  return {
    raw,
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    scene: params.get("scene") ?? "channel",
    theme: params.get("parityTheme") ?? "brutal-light",
    win: params.get("win") ?? "full",
  };
}

function parityExtScSelected(p: ParityExtScProps): string | null {
  return (parityExtScFixture.scenes as Record<string, { selected: string | null }>)[p.scene].selected;
}

// Sidebar derives the selected row and the rail mode from the URL; put the
// route in place before the first render, like primeVisualRoutePath().
(function parityExtScPrimeRoute() {
  if (typeof window === "undefined") return;
  const p = parityExtScProps();
  if (!p) return;
  const selected = parityExtScSelected(p);
  const dm = selected && parityExtScShell.dms.some((d: { id: string }) => d.id === selected);
  const path = p.scene === "activity"
    ? `/s/${fxServer.slug}/activity`
    : `/s/${fxServer.slug}/${dm ? "dm" : "channel"}/${selected}`;
  if (window.location.pathname !== path) {
    window.history.replaceState(null, "", `${path}${window.location.search}`);
  }
})();

function parityExtScPrimeStores(p: ParityExtScProps) {
  primeDirectVisualStores(p.raw);
  const preset = (parityExtScShell.presets as Record<string, {
    channels: string[]; joint: string[]; dms: string[]; unread: Record<string, number>; drafts: Record<string, string>;
    mentions: string[]; pinned: never[]; customSections: never[]; sectionOrder: string[]; placements: never[];
    sortModes: Record<string, string>;
  }>).default;
  const selected = parityExtScSelected(p);
  const all = [...parityExtScShell.channels, ...parityExtScShell.dms] as { id: string }[];
  const byId = (id: string) => all.find((c) => c.id === id) as never;
  useChannelStore.setState({
    channels: [...preset.channels, ...preset.joint].map(byId),
    dmChannels: preset.dms.map(byId),
    channelActivity: parityExtScShell.activity as never,
    loading: false,
  });
  useMachineStore.setState({ machines: [], loading: false, selectedMachineId: null });
  // The open conversation is read: no unread badge / divider on it.
  const unread = Object.fromEntries(Object.entries(preset.unread).filter(([id]) => id !== selected));
  useMessageStore.setState({
    currentChannelId: selected,
    currentUserId: fxOwner.id,
    unreadCounts: unread,
    drafts: preset.drafts,
    mentionFlags: Object.fromEntries(preset.mentions.map((id) => [id, true])),
    newFlags: {},
  });
  const current = useServerStore.getState().sidebarOrder;
  const currentServer = useServerStore.getState().current;
  useServerStore.setState({
    servers: (parityExtScShell.servers as { id: string; name: string; slug: string }[]).map((server) => ({
      ...(currentServer as never as Record<string, unknown>),
      id: server.id,
      name: server.name,
      slug: server.slug,
    })) as never,
    serverUnreadCounts: parityExtScShell.serverUnread as never,
    sidebarOrder: {
      ...current,
      pinned: preset.pinned,
      customSections: preset.customSections,
      sectionOrder: preset.sectionOrder,
      sectionPlacements: preset.placements,
      channelSortMode: "manual",
      jointChannelSortMode: "manual",
      dmSortMode: "manual",
      pinnedSortMode: "manual",
    } as never,
  });
  if (p.scene === "activity") {
    useInboxStore.setState({
      items: parityExtScActivity.items as never,
      filter: "all",
      loading: false,
      loadingMore: false,
      hasMore: false,
      totalCount: parityExtScActivity.totalCount,
      totalUnreadCount: parityExtScActivity.totalUnreadCount,
    });
  }
}

function ParityExtScWindowMarker({ p }: { p: ParityExtScProps }) {
  if (p.win === "full") return null;
  const brutal = p.theme === "brutal-light";
  const rail = brutal ? 64 : 56;
  const rect = p.win === "activity"
    ? { left: 0, top: 0, width: rail + 560, height: window.innerHeight }
    // Bottom of the main column: the composer and the popover that opens above it.
    : { left: rail + 240, top: window.innerHeight - 340, width: window.innerWidth - rail - 240, height: 340 };
  return <div data-testid="screen-window" style={{ position: "absolute", pointerEvents: "none", ...rect }} />;
}

function ParityExtScView({ p }: { p: ParityExtScProps }) {
  useMemo(() => parityExtScPrimeStores(p), [p]);
  const brutal = p.theme === "brutal-light";
  const shellVars = { ["--shell-header-height" as string]: "56px" } as ParityExtScCSSProperties;
  const selected = parityExtScSelected(p);
  const channel = useChannelStore((s) => [...s.channels, ...s.dmChannels].find((c) => c.id === selected) ?? null);
  if (p.platform === "mobile") {
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div data-visual-case={p.raw} style={{ ...shellVars, width: 390, height: 844, overflow: "hidden", position: "relative" }}>
          <div
            // The transform makes the column the containing block of the mobile page's `fixed` header.
            className="flex flex-col"
            style={{ width: 390, height: window.innerHeight, position: "absolute", left: 0, top: 0, transform: "translateY(0px)" }}
          >
            <ChatPanel channel={channel} />
          </div>
        </div>
      </main>
    );
  }
  const activity = p.scene === "activity";
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={p.raw}
        style={{ ...shellVars, width: window.innerWidth, height: window.innerHeight, display: "flex", overflow: "hidden", position: "relative" }}
      >
        <ParityExtScRoot className="min-h-0 flex-1 flex-col font-display">
          <div className="flex min-h-0 flex-1">
            <ParityExtScRailSlot>
              <ParityExtScLeftRail thinDivider={activity} />
            </ParityExtScRailSlot>
            {activity ? null : (
              <ParityExtScSidebarSlot className="md:relative md:flex md:z-auto" style={{ width: 240, flex: "none" }}>
                <div className="relative h-full min-w-0 shrink-0 bg-layer-canvas-muted theme-brutal:bg-brutal-cream" style={{ width: 240 }}>
                  <Routes>
                    <Route path="/s/:serverSlug/*" element={<Sidebar workspaceRailMode={null} />} />
                  </Routes>
                </div>
              </ParityExtScSidebarSlot>
            )}
            <ParityExtScMainSlot overlay className="relative flex">
              {activity ? (
                <ThreadsInbox />
              ) : (
                <div className="thread-layout-container flex min-h-0 min-w-0 flex-1" data-testid="thread-layout-container">
                  <div className="thread-main-column flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden" data-testid="thread-main-column">
                    <ChatPanel channel={channel} />
                  </div>
                </div>
              )}
            </ParityExtScMainSlot>
          </div>
        </ParityExtScRoot>
        <ParityExtScWindowMarker p={p} />
      </div>
    </main>
  );
}

function parityExtScreenElement() {
  const p = parityExtScProps();
  return p ? <ParityExtScView p={p} /> : null;
}
