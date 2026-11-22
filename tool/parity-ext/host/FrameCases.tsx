// raft-flutter parity EXTENSION cases: the app FRAME (level L1; not official).
//
// Also serves the control-state family (components.states.*, build-states-cases.py): the same window on a scene, plus the
// interactions that put one control into one state and a `states-crop` marker over it.
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtFr`). Ids: components.frame.<platform>.<key>.<theme>
// (tool/parity-ext/build-frame-cases.py; platform = phone | tablet | desktop).
//
// Every case mounts the REAL MainLayout (top bar, rail, sidebar, content column, mobile tab
// bar) on the case route with the shared shell data (fixtures/shell.json, the same file the
// Flutter provider reads), at the case viewport. A case either captures the whole window or a
// transparent marker rectangle (`frame-crop`, props cx / cy / cw / ch) over one part of it, so
// the top bar, the rail or the tab bar are scored on their own: a frame regression must not
// drag every page score down with it.
import parityExtFrShell from "virtual:parity-ext/shell";
import { useEffect as parityExtFrUseEffect, useState as parityExtFrUseState } from "react";
import { prefetchServerFeatureFlags as parityExtFrLoadFlags } from "../src/store/serverFeatureFlags";
import { NavigationDepthTracker as ParityExtFrNavigationDepth } from "../src/hooks/useAppNavigate";

type ParityExtFrProps = {
  raw: string;
  platform: string;
  scene: string;
  preset: string;
  route: string;
  sidePanels: boolean;
  crop: { x: number; y: number; w: number; h: number } | null;
};

function parityExtFrProps(): ParityExtFrProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  const kind = params.get("extKind");
  if (!(raw.startsWith("components.frame.") && kind === "frame") && !(raw.startsWith("components.states.") && kind === "states")) return null;
  const num = (key: string) => Number(params.get(key) ?? 0);
  return {
    raw,
    platform: params.get("platform") ?? "desktop",
    scene: params.get("scene") ?? "home",
    preset: params.get("preset") ?? "mobile",
    route: params.get("route") ?? "",
    sidePanels: params.get("sidePanels") === "true",
    crop: params.get("cw") ? { x: num("cx"), y: num("cy"), w: num("cw"), h: num("ch") } : null,
  };
}

// MainLayout derives the selected row and the mode from the URL: put the route in place before the
// first render, like primeVisualRoutePath().
(function parityExtFrPrimeRoute() {
  if (typeof window === "undefined") return;
  const p = parityExtFrProps();
  if (!p) return;
  const path = `/s/${fxServer.slug}${p.route}`;
  if (window.location.pathname !== path) {
    window.history.replaceState(null, "", `${path}${window.location.search}`);
  }
})();

function parityExtFrPrimeStores(p: ParityExtFrProps) {
  // The shell cases' seeding (channels, DMs, sections, unread, servers) with this case's preset.
  parityExtShPrimeStores({
    raw: p.raw, platform: "desktop", surface: "frame", preset: p.preset, theme: "raft", extra: 0,
  } as never);
  if (p.sidePanels) setServerFeatureFlagForTests(fxServer.id, "task_v2_conversations_v0", true);
  void parityExtFrShell;
}

function ParityExtFrView({ p }: { p: ParityExtFrProps }) {
  useMemo(() => parityExtFrPrimeStores(p), [p]);
  const [flagsReady, setFlagsReady] = parityExtFrUseState(false);
  const checkTabBar = p.raw.startsWith("components.frame.phone.tabbar-");
  parityExtFrUseEffect(() => {
    if (!checkTabBar) return;
    // MainLayout is mounted without App. Fetch the signed-in startup flag
    // snapshot through the same API as App, using the shared fixture response.
    let active = true;
    void parityExtFrLoadFlags(fxServer.id).then(() => {
      if (active) setFlagsReady(true);
    });
    return () => { active = false; };
  }, [checkTabBar]);
  const width = window.innerWidth;
  const height = window.innerHeight;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={p.raw}
        style={{ position: "relative", width, height, overflow: "hidden", display: "flex", flexDirection: "column" }}
      >
        {checkTabBar ? <ParityExtFrNavigationDepth /> : null}
        <Routes>
          <Route path="/s/:serverSlug/*" element={<MainLayout />} />
        </Routes>
        {p.crop ? (
          <div
            data-testid="frame-crop"
            data-tabbar-flags-ready={checkTabBar && flagsReady ? "" : undefined}
            style={{ position: "absolute", left: p.crop.x, top: p.crop.y, width: p.crop.w, height: p.crop.h, pointerEvents: "none" }}
          />
        ) : null}
      </div>
    </main>
  );
}

function parityExtFrameElement() {
  const p = parityExtFrProps();
  return p ? <ParityExtFrView p={p} /> : null;
}
