// Framework navigation uses the mounted MainLayout from the pinned Web.
// Only deterministic store inputs and an observational crop are supplied here;
// rail widths, header heights and background colors belong to the product.
import parityExtFwShell from "virtual:parity-ext/shell";
import parityExtFwInputs from "virtual:parity-ext/framework";
import { useLayoutEffect as parityExtFwLayoutEffect, useRef as parityExtFwRef, useState as parityExtFwState } from "react";

type ParityExtFwProps = { raw: string; platform: string; preset: string; shell: string };

function parityExtFwProps(): ParityExtFwProps | null {
  const q = new URLSearchParams(window.location.search);
  const raw = q.get("case") ?? "";
  if (!raw.startsWith("components.framework.") || q.get("extKind") !== "framework") return null;
  return { raw, platform: q.get("platform") ?? "desktop", preset: q.get("preset") ?? "default", shell: q.get("shell") ?? "browser" };
}

// Route-dependent selection must be present when the router first mounts.
(function parityExtFwPrimeRoute() {
  if (typeof window === "undefined") return;
  const p = parityExtFwProps();
  if (!p) return;
  // Exercise the source's explicit desktop-shell branch. This supplies only
  // the environment identity; it does not emulate native Electron services.
  if (p.shell === "desktop") {
    (window as unknown as { raftDesktop: { isDesktop: boolean } }).raftDesktop = { isDesktop: true };
  }
  const preset = (parityExtFwShell.presets as Record<string, { selected: string | null }>)[p.preset];
  const path = `/s/${fxServer.slug}${preset.selected ? `/channel/${preset.selected}` : ""}`;
  window.history.replaceState(null, "", `${path}${window.location.search}`);
})();

function parityExtFwPrimeStores(p: ParityExtFwProps) {
  primeDirectVisualStores(p.raw);
  // Explicitly retain primeDirectVisualStores' newer live frames on both hosts.
  // The shared agent snapshot still says Product UX is working.
  useAgentStore.setState({ agentActivities: parityExtFwInputs.agentActivities as never });
  const preset = (parityExtFwShell.presets as Record<string, {
    channels: string[]; joint: string[]; dms: string[]; selected: string | null;
    unread: Record<string, number>; drafts: Record<string, string>; mentions: string[];
    pinned: never[]; customSections: never[]; sectionOrder: string[]; placements: never[];
    sortModes: Record<string, string>; loading: boolean;
  }>)[p.preset];
  const all = [...parityExtFwShell.channels, ...parityExtFwShell.dms] as { id: string }[];
  const byId = (id: string) => all.find((item) => item.id === id) as never;
  useChannelStore.setState({
    channels: [...preset.channels, ...preset.joint].map(byId),
    dmChannels: preset.dms.map(byId), channelActivity: parityExtFwShell.activity as never,
    loading: preset.loading,
  });
  useMachineStore.setState({ machines: [], loading: false, selectedMachineId: null });
  useMessageStore.setState({
    currentChannelId: preset.selected, currentUserId: fxOwner.id,
    unreadCounts: Object.fromEntries(Object.entries(preset.unread).filter(([id]) => id !== preset.selected)),
    drafts: preset.drafts,
    mentionFlags: Object.fromEntries(preset.mentions.filter((id) => id !== preset.selected).map((id) => [id, true])),
    newFlags: {},
  });
  const current = useServerStore.getState().current;
  useServerStore.setState({
    servers: parityExtFwShell.servers.map((item: { id: string; name: string; slug: string }) => ({ ...current, ...item })) as never,
    serverUnreadCounts: parityExtFwShell.serverUnread as never,
    sidebarOrder: {
      ...useServerStore.getState().sidebarOrder,
      pinned: preset.pinned, customSections: preset.customSections,
      sectionOrder: preset.sectionOrder, sectionPlacements: preset.placements,
      channelSortMode: preset.sortModes.channels ?? "manual",
      jointChannelSortMode: preset.sortModes.joint ?? "manual",
      dmSortMode: preset.sortModes.dms ?? "manual",
      pinnedSortMode: preset.sortModes.pinned ?? "manual",
    },
  });
}

function ParityExtFwView({ p }: { p: ParityExtFwProps }) {
  useMemo(() => parityExtFwPrimeStores(p), [p]);
  const host = parityExtFwRef<HTMLDivElement>(null);
  const [crop, setCrop] = parityExtFwState<{ left: number; top: number; width: number; height: number } | null>(null);
  parityExtFwLayoutEffect(() => {
    if (p.platform === "mobile") return;
    const root = host.current;
    if (!root) return;
    const measure = () => {
      const nodes = [...root.querySelectorAll('[data-testid="workspace-left-rail"], [data-testid="sidebar-root"]')]
        .map((node) => node.getBoundingClientRect()).filter((r) => r.width > 0 && r.height > 0);
      if (nodes.length !== 2) return;
      const parent = root.getBoundingClientRect();
      const left = Math.min(...nodes.map((r) => r.left));
      const top = Math.min(...nodes.map((r) => r.top));
      const next = { left: left - parent.left, top: top - parent.top,
        width: Math.max(...nodes.map((r) => r.right)) - left,
        height: Math.max(...nodes.map((r) => r.bottom)) - top };
      setCrop((old) => JSON.stringify(old) === JSON.stringify(next) ? old : next);
    };
    const observer = new ResizeObserver(measure);
    observer.observe(root);
    const frame = requestAnimationFrame(measure);
    return () => { cancelAnimationFrame(frame); observer.disconnect(); };
  }, [p.platform]);
  return (
    <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
      <div ref={host} data-visual-case={p.raw} data-testid="framework-shell"
        style={{ width: window.innerWidth, height: window.innerHeight, display: "flex", flexDirection: "column", position: "relative", overflow: "hidden" }}>
        <Routes><Route path="/s/:serverSlug/*" element={<MainLayout />} /></Routes>
        {crop && <div data-testid="framework-navigation" aria-hidden="true"
          style={{ position: "absolute", pointerEvents: "none", ...crop }} />}
      </div>
    </main>
  );
}

function parityExtFrameworkElement() {
  const p = parityExtFwProps();
  return p ? <ParityExtFwView p={p} /> : null;
}
