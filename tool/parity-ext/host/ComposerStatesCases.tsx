// raft-flutter parity EXTENSION cases: composer states (not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and the composed-screen helpers of
// host/ScreenCases.tsx; identifiers here are prefixed `parityExtCompSt`). Ids:
// components.composer-states.<surface>.<platform>.<state>.<theme>
// (tool/parity-ext/build-composer-states.py).
//
// The composed channel / DM screen of the screens-ext family (real LeftRail +
// Sidebar + ChatPanel at 1280x800, ChatPanel alone at 390x844) with a window
// marker over its bottom (`composer-window`): the composer, the banner above it
// and the suggestion popover. The send states press Enter in the composer; the
// POST /v2/messages receipt (pending-mention actions, unresolved handles, delivery
// warnings) is answered by the fixture routes. `patch` / `extraChannels` adjust the
// channel store after the composed screen primed it (a running conversion job, an
// archived channel for the #channel popover).
import parityExtCompStFixture from "virtual:parity-ext/composer-states";
import { useLayoutEffect as parityExtCompStUseLayoutEffect } from "react";

type ParityExtCompStState = {
  selected: string;
  draft: string;
  patch: Record<string, unknown>;
  extraChannels: Record<string, unknown>[];
};

function parityExtCompStProps() {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.composer-states.") || params.get("extKind") !== "composer-states") return null;
  const state = (parityExtCompStFixture.states as Record<string, ParityExtCompStState>)[params.get("state") ?? ""];
  if (!state) return null;
  return {
    raw,
    state,
    platform: (params.get("platform") === "mobile" ? "mobile" : "desktop") as "desktop" | "mobile",
    theme: params.get("parityTheme") ?? "brutal-light",
    height: Number(params.get("windowHeight") ?? 300),
    // The screens-ext scene the state's conversation belongs to (props of ParityExtScView).
    scene: (params.get("state") ?? "") === "agent-stopped" ? "dm-agent" : "channel",
  };
}

// Same route priming as the screens-ext host (parityExtScPrimeRoute) for this family's ids.
(function parityExtCompStPrimeRoute() {
  if (typeof window === "undefined") return;
  const p = parityExtCompStProps();
  if (!p) return;
  const dm = parityExtScShell.dms.some((d: { id: string }) => d.id === p.state.selected);
  const path = `/s/${fxServer.slug}/${dm ? "dm" : "channel"}/${p.state.selected}`;
  if (window.location.pathname !== path) {
    window.history.replaceState(null, "", `${path}${window.location.search}`);
  }
})();

function ParityExtCompStPatch({ p }: { p: NonNullable<ReturnType<typeof parityExtCompStProps>> }) {
  // After the composed screen primed the stores (its render ran before this layout effect).
  parityExtCompStUseLayoutEffect(() => {
    useChannelStore.setState((s) => ({
      channels: [
        ...s.channels.map((c) => (c.id === p.state.selected ? { ...c, ...p.state.patch } : c)),
        // Idempotent: React StrictMode runs layout effects twice.
        ...p.state.extraChannels.filter((x) => !s.channels.some((c) => c.id === (x as { id: string }).id)),
      ] as never,
      dmChannels: s.dmChannels.map((c) => (c.id === p.state.selected ? { ...c, ...p.state.patch } : c)) as never,
    }));
  }, []);
  return null;
}

function ParityExtCompStMarker({ p }: { p: NonNullable<ReturnType<typeof parityExtCompStProps>> }) {
  const brutal = p.theme === "brutal-light";
  const rail = brutal ? 64 : 56;
  const left = p.platform === "mobile" ? 0 : rail + 240;
  const width = p.platform === "mobile" ? 390 : window.innerWidth - rail - 240;
  return (
    <div
      data-testid="composer-window"
      style={{ position: "fixed", pointerEvents: "none", left, width, top: window.innerHeight - p.height, height: p.height }}
    />
  );
}

function parityExtComposerStatesElement() {
  const p = parityExtCompStProps();
  if (!p) return null;
  const sc = {
    raw: p.raw, platform: p.platform, scene: p.scene, theme: p.theme, win: "full",
  } as const;
  return (
    <>
      <ParityExtScView p={sc} />
      <ParityExtCompStPatch p={p} />
      <ParityExtCompStMarker p={p} />
    </>
  );
}
