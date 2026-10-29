// raft-flutter parity EXTENSION cases: shell & navigation (not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtSh`). Ids: components.shell.<platform>.<surface>.<theme>
// (tool/parity-ext/build-shell-cases.py).
//
// Each case mounts the REAL product components the Web shell shows with seeded
// stores (tool/parity-ext/fixtures/shell.json, which the Flutter provider also
// reads):
//   desktop rail + sidebar -> layout/LeftRail + layout/Sidebar inside raft-ui
//                             AppShellRoot / RailSlot / SidebarSlot (MainLayout)
import {
  AppShellMainSlot as ParityExtShMainSlot,
  Button as ParityExtShButton,
  AppShellRailSlot as ParityExtShRailSlot,
  AppShellRoot as ParityExtShRoot,
  AppShellSidebarSlot as ParityExtShSidebarSlot,
} from "raft-ui";
import { LeftRail as ParityExtShLeftRail } from "../src/components/layout/LeftRail";
import { MobileTabBar as ParityExtShMobileTabBar } from "../src/components/layout/MainLayout";
import ParityExtShConfirmDialog from "../src/components/ConfirmDialog";
import ParityExtShBanner from "../src/components/ui/Banner";
import ParityExtShEmptyState from "../src/components/ui/EmptyState";
import ParityExtShBottomSheet from "../src/components/ui/BottomSheet";
import {
  OverflowActionRow as ParityExtShOverflowActionRow,
  OverflowCommandRow as ParityExtShOverflowCommandRow,
  OverflowDangerZone as ParityExtShOverflowDangerZone,
  OverflowSheet as ParityExtShOverflowSheet,
  OverflowSwitchRow as ParityExtShOverflowSwitchRow,
} from "../src/components/ui/OverflowSheet";
import ParityExtShToastProvider from "../src/components/LocalizedToastProvider";
import { toast as parityExtShToast } from "raft-ui";
import { Archive as ParityExtShArchive, Bell as ParityExtShBell, Inbox as ParityExtShInbox, Link2 as ParityExtShLink, Search as ParityExtShSearch, Trash2 as ParityExtShTrash } from "lucide-react";
import parityExtShFixture from "virtual:parity-ext/shell";
import { useEffect as parityExtShUseEffect } from "react";
import type { CSSProperties as ParityExtShCSSProperties, ReactNode as ParityExtShNode } from "react";

type ParityExtShProps = {
  raw: string;
  platform: "desktop" | "mobile";
  surface: string;
  preset: string;
  theme: string;
  extra: number;
};

type ParityExtShPreset = {
  channels: string[];
  joint: string[];
  dms: string[];
  unread: Record<string, number>;
  drafts: Record<string, string>;
  mentions: string[];
  pinned: { kind: "channel" | "agent" | "human"; id: string }[];
  customSections: { id: string; name: string; emoji: string | null; sortMode: "manual" | "recent" | "az" }[];
  sectionOrder: string[];
  placements: { kind: "channel" | "agent"; id: string; sectionId: string; position: number }[];
  sortModes: Record<string, "manual" | "recent" | "az">;
  selected: string | null;
  loading: boolean;
};

type ParityExtShServer = { id: string; name: string; slug: string };

function parityExtShProps(): ParityExtShProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.shell.") || params.get("extKind") !== "shell") return null;
  return {
    raw,
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    surface: params.get("surface") ?? "",
    preset: params.get("preset") ?? "default",
    theme: params.get("parityTheme") ?? "brutal-light",
    extra: Number(params.get("extra") ?? 0),
  };
}

function parityExtShPreset(p: ParityExtShProps): ParityExtShPreset {
  return (parityExtShFixture.presets as Record<string, ParityExtShPreset>)[p.preset];
}

// Sidebar derives the selected row and the rail mode from the URL; put the
// route in place before the first render, like primeVisualRoutePath().
(function parityExtShPrimeRoute() {
  if (typeof window === "undefined") return;
  const p = parityExtShProps();
  if (!p) return;
  const preset = parityExtShPreset(p);
  const route = new URLSearchParams(window.location.search).get("route");
  const dm = preset.selected && parityExtShFixture.dms.some((d: { id: string }) => d.id === preset.selected);
  const path = route
    ? `/s/${fxServer.slug}/${route}`
    : preset.selected
      ? `/s/${fxServer.slug}/${dm ? "dm" : "channel"}/${preset.selected}`
      : `/s/${fxServer.slug}`;
  if (window.location.pathname !== path) {
    window.history.replaceState(null, "", `${path}${window.location.search}`);
  }
})();

function parityExtShPrimeStores(p: ParityExtShProps) {
  primeDirectVisualStores(p.raw);
  const preset = parityExtShPreset(p);
  const all = [...parityExtShFixture.channels, ...parityExtShFixture.dms] as { id: string }[];
  const byId = (id: string) => all.find((c) => c.id === id) as never;
  useChannelStore.setState({
    channels: [...preset.channels, ...preset.joint].map(byId),
    dmChannels: preset.dms.map(byId),
    channelActivity: parityExtShFixture.activity as never,
    loading: preset.loading,
  });
  // No computers: the rail's Computers dot and the Notification Center bell
  // dot stay off (both providers show a clean workspace).
  useMachineStore.setState({ machines: [], loading: false, selectedMachineId: null });
  useMessageStore.setState({
    currentChannelId: preset.selected,
    currentUserId: fxOwner.id,
    unreadCounts: preset.unread,
    drafts: preset.drafts,
    mentionFlags: Object.fromEntries(preset.mentions.map((id) => [id, true])),
    newFlags: {},
  });
  const current = useServerStore.getState().sidebarOrder;
  const currentServer = useServerStore.getState().current;
  useServerStore.setState({
    servers: (parityExtShFixture.servers as ParityExtShServer[]).map((server) => ({
      ...(currentServer as never as Record<string, unknown>),
      id: server.id,
      name: server.name,
      slug: server.slug,
    })) as never,
    serverUnreadCounts: parityExtShFixture.serverUnread as never,
    sidebarOrder: {
      ...current,
      pinned: preset.pinned,
      customSections: preset.customSections,
      sectionOrder: preset.sectionOrder,
      sectionPlacements: preset.placements,
      channelSortMode: preset.sortModes.channels ?? "manual",
      jointChannelSortMode: preset.sortModes.joint ?? "manual",
      dmSortMode: preset.sortModes.dms ?? "manual",
      pinnedSortMode: preset.sortModes.pinned ?? "manual",
    },
  });
}

function parityExtShShellVars(theme: string): ParityExtShCSSProperties {
  return { ["--shell-header-height" as string]: theme === "brutal-light" ? "62px" : "56px" } as ParityExtShCSSProperties;
}

function ParityExtShView({ p }: { p: ParityExtShProps }) {
  useMemo(() => parityExtShPrimeStores(p), [p]);
  if (p.surface.startsWith("activity.")) {
    // Activity page framing (MainLayout): desktop = LeftRail (thinDivider) +
    // the master-detail column holding ThreadsInbox `compactActivitySidebar`
    // (`border-r` on the column); mobile = the full-width inbox page.
    const brutal = p.theme === "brutal-light";
    if (p.platform === "mobile") {
      return (
        <main className="min-h-screen bg-white p-0 font-display text-black">
          <div
            data-visual-case={p.raw}
            data-testid="shell-activity-frame"
            className={`flex flex-col ${brutal ? "bg-white" : "bg-layer-canvas-muted"}`}
            style={{ ...parityExtShShellVars(p.theme), width: 390, height: 360, overflow: "hidden" }}
          >
            {/* MainLayout mobile: AppShellRoot > AppShellMainSlot > route (the
                panel keeps its `edge="attached"` left border). */}
            <ParityExtShRoot className="min-h-0 flex-1 flex-col font-display">
              <div className="flex min-h-0 flex-1">
                <ParityExtShMainSlot overlay className="relative flex">
                  <ThreadsInbox />
                </ParityExtShMainSlot>
              </div>
            </ParityExtShRoot>
          </div>
        </main>
      );
    }
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div
          data-visual-case={p.raw}
          style={{ ...parityExtShShellVars(p.theme), width: window.innerWidth, height: window.innerHeight, display: "flex", overflow: "hidden" }}
        >
          <ParityExtShRoot className="min-h-0 flex-1 flex-col font-display">
            <div className="flex min-h-0 flex-1">
              {/* Activity landing (no content slot): the sidebar column is hidden and the
                  inbox panel fills the main slot beside the rail; the crop keeps the
                  rail plus the first 560px of the panel. */}
              <div data-testid="shell-activity-frame" className="min-h-0 overflow-hidden" style={{ width: (brutal ? 64 : 56) + 560, background: "white" }}>
                <div className="flex min-h-0" style={{ width: window.innerWidth, height: window.innerHeight }}>
                  <ParityExtShRailSlot>
                    <ParityExtShLeftRail thinDivider />
                  </ParityExtShRailSlot>
                  <ParityExtShMainSlot overlay className="relative flex">
                    <ThreadsInbox />
                  </ParityExtShMainSlot>
                </div>
              </div>
            </div>
          </ParityExtShRoot>
        </div>
      </main>
    );
  }
  if (p.platform === "mobile") {
    // Mobile Home tab: the tab-root Sidebar fills the 390 page (MainLayout
    // `mobileShowSidebarInline`), white in Brutal, canvas-muted in Elegant.
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div
          data-visual-case={p.raw}
          data-testid="shell-mobile-home"
          style={{ ...parityExtShShellVars(p.theme), width: 390, height: 844, display: "flex", flexDirection: "column", overflow: "hidden", background: "white" }}
        >
          <div style={{ display: "flex", flex: 1, minHeight: 0 }}>
            <Routes>
              <Route path="/s/:serverSlug/*" element={<Sidebar mobileInline />} />
            </Routes>
          </div>
          {/* MainLayout (v1.21.23): the tab bar is an in-flow edge bar under the page
              (MobileTabBar, raft-ui MobileNavRoot); the older floating stack is gone. */}
          <div style={{ pointerEvents: "none" }}>
            {/* The capture parks the mouse in the viewport's bottom-right corner,
                which would paint the Settings tab hovered; Flutter has no hover. */}
            <ParityExtShMobileTabBar />
          </div>
        </div>
      </main>
    );
  }
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={p.raw}
        style={{ ...parityExtShShellVars(p.theme), width: window.innerWidth, height: window.innerHeight, display: "flex", overflow: "hidden" }}
      >
        <ParityExtShRoot className="min-h-0 flex-1 flex-col font-display">
          <div className="flex min-h-0 flex-1">
            {/* The crop: rail + sidebar (+ `extra` px of page to the right, where
                the menus and popovers open). */}
            <div
              data-testid="shell-rail-sidebar"
              className="flex min-h-0"
              style={{ width: (p.theme === "brutal-light" ? 64 : 56) + 240 + p.extra, background: "white" }}
            >
              <ParityExtShRailSlot>
                <ParityExtShLeftRail />
              </ParityExtShRailSlot>
              <ParityExtShSidebarSlot className="md:relative md:flex md:z-auto" style={{ width: 240, flex: "none" }}>
                <div
                  data-testid="shell-sidebar"
                  className="relative h-full min-w-0 shrink-0 bg-layer-canvas-muted theme-brutal:bg-brutal-cream"
                  style={{ width: 240 }}
                >
                  <Routes>
                    <Route path="/s/:serverSlug/*" element={<Sidebar workspaceRailMode={null} />} />
                  </Routes>
                </div>
              </ParityExtShSidebarSlot>
            </div>
          </div>
        </ParityExtShRoot>
      </div>
    </main>
  );
}

type ParityExtShPrimitives = {
  confirms: Record<string, { title: string; message: string; confirmLabel: string; variant?: string; hideCancel?: boolean }>;
  banners: { intent: "destructive" | "warning" | "info" | "success"; density?: "sm" | "md" | "lg"; title?: string; text: string; icon?: boolean; action?: string }[];
  empties: Record<string, { icon: string; title: string; description?: string; action?: string }>;
  toasts: Record<string, { kind: "success" | "error" | "info" | "warning"; title: string; description?: string; plain?: boolean; action?: string }>;
};

function parityExtShPrimitives(): ParityExtShPrimitives {
  return (parityExtShFixture as unknown as { primitives: ParityExtShPrimitives }).primitives;
}

function parityExtShEmptyIcon(name: string) {
  return name === "search" ? <ParityExtShSearch size={36} /> : <ParityExtShInbox size={36} />;
}

function ParityExtShPrimitiveView({ p }: { p: ParityExtShProps }) {
  useMemo(() => primeDirectVisualStores(p.raw), [p.raw]);
  const prim = parityExtShPrimitives();
  const [surface, variant = ""] = p.surface.split(".");
  const mobile = p.platform === "mobile";
  const toastKey = surface === "toast" ? variant : "";
  parityExtShUseEffect(() => {
    if (!toastKey) return;
    const t = prim.toasts[toastKey];
    const options = {
      description: t.description,
      ...(t.plain ? { icon: false, dismissible: false } : {}),
      ...(t.action ? { actionProps: { children: t.action, onClick: () => undefined } } : {}),
    } as never;
    parityExtShToast[t.kind](t.title, options);
  }, [toastKey, prim]);
  let body: ParityExtShNode = null;
  if (surface === "confirm") {
    const c = prim.confirms[variant];
    body = (
      <ParityExtShConfirmDialog
        chromeLocale="active"
        title={c.title}
        message={c.message}
        confirmLabel={c.confirmLabel}
        confirmVariant={c.variant as never}
        hideCancel={c.hideCancel}
        onConfirm={() => undefined}
        onClose={() => undefined}
      />
    );
  } else if (surface === "banner") {
    body = (
      <div data-testid="shell-banners" className="flex flex-col gap-3 bg-white p-4" style={{ width: mobile ? 390 : 480 }}>
        {prim.banners.map((b, i) => (
          <ParityExtShBanner
            key={i}
            intent={b.intent}
            density={b.density}
            title={b.title}
            withIcon={b.icon}
            actions={b.action ? <button type="button" className="text-sm font-bold underline">{b.action}</button> : undefined}
          >
            {b.text}
          </ParityExtShBanner>
        ))}
      </div>
    );
  } else if (surface === "empty") {
    const e = prim.empties[variant];
    body = (
      <div data-testid="shell-empty" className="bg-white" style={{ width: mobile ? 390 : 480, height: 320, display: "flex" }}>
        <ParityExtShEmptyState
          icon={parityExtShEmptyIcon(e.icon)}
          title={e.title}
          description={e.description}
          action={e.action ? <ParityExtShButton size="sm" variant="outline">{e.action}</ParityExtShButton> : undefined}
        />
      </div>
    );
  } else if (surface === "bottomsheet") {
    body = (
      <ParityExtShBottomSheet data-testid="shell-bottom-sheet" onClose={() => undefined} sheetClassName="p-4">
        <div className="text-base font-bold">Add to home screen</div>
        <p className="mt-2 text-sm text-foreground-muted theme-brutal:text-black/70">Install Raft for faster access and notifications.</p>
        <div className="mt-4 flex justify-end gap-2">
          <ParityExtShButton size="sm" variant="outline">Not now</ParityExtShButton>
          <ParityExtShButton size="sm" variant="default">Install</ParityExtShButton>
        </div>
      </ParityExtShBottomSheet>
    );
  } else if (surface === "overflow") {
    body = (
      <ParityExtShOverflowSheet
        open
        onOpenChange={() => undefined}
        title="#design"
        descriptionId={"message.channelSettings.infoDescription" as never}
        testId="shell-overflow-sheet"
      >
        <ParityExtShOverflowCommandRow icon={<ParityExtShLink size={16} />} label="Copy channel link" onClick={() => undefined} />
        <ParityExtShOverflowSwitchRow labelId="shell-mute" icon={<ParityExtShBell size={16} />} label="Mute notifications" checked={false} onCheckedChange={() => undefined} />
        <div className="px-4 py-2">
          <ParityExtShOverflowActionRow icon={<ParityExtShArchive size={16} />} label="Archive channel" trailing="3" onClick={() => undefined} />
        </div>
        <ParityExtShOverflowDangerZone>
          <div className="px-4 py-2">
            <ParityExtShOverflowActionRow danger icon={<ParityExtShTrash size={16} />} label="Delete channel" onClick={() => undefined} />
          </div>
        </ParityExtShOverflowDangerZone>
      </ParityExtShOverflowSheet>
    );
  }
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={p.raw} style={{ ...parityExtShShellVars(p.theme), width: window.innerWidth, height: window.innerHeight }}>
        <ParityExtShToastProvider>{body}</ParityExtShToastProvider>
      </div>
    </main>
  );
}

function parityExtShellElement() {
  const p = parityExtShProps();
  if (!p) return null;
  const primitive = ["confirm", "banner", "empty", "bottomsheet", "overflow", "toast"].includes(p.surface.split(".")[0]);
  return primitive ? <ParityExtShPrimitiveView p={p} /> : <ParityExtShView p={p} />;
}
