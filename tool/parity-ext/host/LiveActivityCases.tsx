// raft-flutter parity EXTENSION cases: the live agent activity bar
// ("what the bot is doing now"). Appended to the generated
// VisualTestingCases.tsx like host/ComputerCases.tsx (shares its imports and
// private helpers); identifiers are prefixed `parityExtLive`.
//
// Mounts the REAL product component `LiveAgentActivityBarPresentation`
// (layout/LiveAgentActivityBar) in the two places MainLayout puts it:
//   desktop -> Sidebar `bottomSlot` (`pointer-events-none shrink-0`, below the
//              list, inside SidebarRoot's `border-r` and canvas background)
//   mobile  -> MobileBottomBarStack slot (`mobile-live-activity-slot`), the
//              elegant themes floating over the content (`fixed inset-x-0
//              bottom-0`), brutal in normal flow above the tab bar.
// The capture is the bar's slot, so its outer offset is part of the image.
import { LiveAgentActivityBarPresentation as ParityExtLiveBarPresentation } from "../src/components/layout/LiveAgentActivityBar";
import ParityExtMobileBottomBarStack from "../src/components/layout/MobileBottomBarStack";
import type { LiveAgentActivityItem as ParityExtLiveItem } from "../src/utils/liveAgentActivity";

function parityExtLiveProps() {
  const raw = new URLSearchParams(window.location.search).get("case") ?? "";
  if (!raw.startsWith("components.liveactivity.")) return null;
  const params = new URLSearchParams(window.location.search);
  const theme = params.get("parityTheme");
  return {
    raw,
    platform: params.get("platform") ?? "desktop",
    activity: (params.get("activity") ?? "working") as "working" | "thinking",
    text: params.get("text") ?? "",
    descriptor: params.get("descriptor") ?? "",
    brutal: theme === "brutal-light",
  };
}

function parityExtLiveItem(p: NonNullable<ReturnType<typeof parityExtLiveProps>>): ParityExtLiveItem {
  return {
    id: "activity:agent-cindy:parity",
    kind: "activity",
    agentId: fxCindy.id,
    agentName: fxCindy.displayName,
    agentAvatarUrl: fxCindy.avatar,
    text: p.text,
    textDescriptor: p.descriptor
      ? { primary: { id: p.descriptor as never } }
      : { primary: { raw: p.text } },
    context: null,
    activity: p.activity,
    createdAt: Date.now(),
  };
}

function ParityExtLiveView({ p }: { p: NonNullable<ReturnType<typeof parityExtLiveProps>> }) {
  useMemo(() => primeDirectVisualStores(p.raw), [p.raw]);
  const bar = <ParityExtLiveBarPresentation latest={parityExtLiveItem(p)} />;
  if (p.platform === "mobile") {
    // Home tab: the tab-root Sidebar fills the screen (white in brutal, canvas
    // muted in elegant) and the bars sit at the bottom.
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div
          className={`relative flex flex-col justify-end ${p.brutal ? "bg-white" : "bg-layer-canvas-muted"}`}
          style={{ width: 390, height: 844, overflow: "hidden" }}
        >
          <ParityExtMobileBottomBarStack
            showLiveActivity
            liveActivity={bar}
            tabBar={<div style={{ height: 0 }} />}
            floating={!p.brutal}
          />
        </div>
      </main>
    );
  }
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div style={{ width: 240, height: 400, display: "flex", flexDirection: "column" }}>
        <div
          className={`relative flex h-full w-full flex-col justify-end ${p.brutal ? "border-r-2 border-black bg-brutal-cream" : "border-r border-line-muted bg-layer-canvas-muted"} font-display select-none`}
        >
          <div className="pointer-events-none shrink-0">{bar}</div>
        </div>
      </div>
    </main>
  );
}

function parityExtLiveElement() {
  const p = parityExtLiveProps();
  return p ? <ParityExtLiveView p={p} /> : null;
}
