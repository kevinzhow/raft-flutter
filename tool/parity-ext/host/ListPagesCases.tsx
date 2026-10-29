// raft-flutter parity EXTENSION cases (not part of the official case set):
// list-style pages that had no case: Search page states, Activity filters and
// context menu, Saved list / actions, Tasks filters / views / status menu,
// the desktop notification center and channel / section dialogs.
//
// tool/parity-ext-web.mjs appends this file to a generated copy of the pinned
// packages/web/visual-testing/VisualTestingCases.tsx (the Source checkout is never
// edited), so it shares that module's imports and private fixture helpers
// (primeDirectVisualStores, fxServer, ThreadsInbox, SavedPanel, TasksPanel,
// MessageSearchPage, useInboxStore, ...). Identifiers introduced here are
// prefixed `parityExtLp` / `ParityExtLp`. Ids: components.list-pages.<key>.<theme>
// (tool/parity-ext/build-list-pages.py). API reads are answered from
// tool/parity-ext/fixtures/listpages.json (`routes` + the case's `routeSet`), the
// same file the Flutter provider reads.
import parityExtLpFixture from "virtual:parity-ext/listpages";
import ParityExtLpNotificationTrigger from "../src/components/layout/NotificationTrigger";
import ParityExtLpAddMembersDialog from "../src/components/channel/AddMembersDialog";
import ParityExtLpCreateJointChannelDialog from "../src/components/channel/CreateJointChannelDialog";
import ParityExtLpMobileComputersPanel from "../src/components/machine/MobileComputersPanel";

type ParityExtLpProps = {
  raw: string;
  extCase: string;
  extKind: string;
  platform: "desktop" | "mobile";
  params: URLSearchParams;
};

function parityExtLpProps(): ParityExtLpProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.list-pages.")) return null;
  const extCase = params.get("extCase");
  const extKind = params.get("extKind");
  if (!extCase || !extKind) return null;
  return { raw, extCase, extKind, platform: params.get("platform") === "mobile" ? "mobile" : "desktop", params };
}

// Route-based panels read their state from the URL (search q / filters, tasks
// view / filters): put it in place before BrowserRouter mounts, like the
// official primeVisualRoutePath().
(function parityExtLpPrimeRoute() {
  if (typeof window === "undefined") return;
  const props = parityExtLpProps();
  if (!props) return;
  const route = props.params.get("route");
  if (props.extKind === "shell") {
    window.history.replaceState(null, "", `/s/${fxServer.slug}${props.params.get("shellRoute") ?? ""}?${new URLSearchParams(window.location.search).toString()}`);
    return;
  }
  if (!route) return;
  const next = new URLSearchParams(props.params.get("routeQuery") ?? "");
  for (const [key, value] of props.params.entries()) {
    if (key !== "route" && key !== "routeQuery") next.set(key, value);
  }
  window.history.replaceState(null, "", `/s/${fxServer.slug}${route}?${next.toString()}`);
  // Local-only search memory (history tags) the page reads on mount.
  const history = props.params.get("searchHistory");
  if (history) {
    window.localStorage.setItem(`raft:search-history:${fxServer.id}:${fxOwner.id}`, JSON.stringify(history.split("|")));
  } else {
    window.localStorage.removeItem(`raft:search-history:${fxServer.id}:${fxOwner.id}`);
  }
  window.localStorage.removeItem(`raft:search-state:${fxServer.id}:${fxOwner.id}`);
})();

function parityExtLpBox(props: ParityExtLpProps) {
  const width = Number(props.params.get("w") ?? 342);
  const height = Number(props.params.get("h") ?? 620);
  return { width, height };
}

function parityExtLpPrime(props: ParityExtLpProps) {
  primeDirectVisualStores(props.raw);
  const state = props.params.get("state") ?? "results";
  const panel = props.params.get("panel");
  const results = state === "results";
  const routes = { ...(parityExtLpFixture.routes as Record<string, unknown>), ...((parityExtLpFixture.routeSets as Record<string, Record<string, unknown>>)[props.params.get("routeSet") ?? ""] ?? {}) };
  const inbox = routes["GET /channels/inbox"] as typeof activityResultsFixture;
  const saved = routes["GET /channels/saved"] as typeof savedMessagesFixture;
  if (panel === "activity") {
    // activity_conversation_list_v0 (and a sidebar-pinned channel) from the case props.
    setServerFeatureFlagForTests(fxServer.id, "activity_conversation_list_v0", (props.params.get("flags") ?? "").split(",").includes("list"));
    const pinnedChannel = props.params.get("pinned");
    if (pinnedChannel) {
      useServerStore.setState((s) => ({ sidebarOrder: { ...s.sidebarOrder, pinned: [{ kind: "channel", id: pinnedChannel }] } }) as never);
    }
    useInboxStore.setState({
      items: (results ? inbox.items : []) as never,
      filter: (props.params.get("filter") ?? "all") as never,
      loading: state === "loading",
      loadingMore: false,
      hasMore: false,
      totalCount: results ? inbox.totalCount : 0,
      totalUnreadCount: results ? inbox.totalUnreadCount : 0,
    });
  }
  if (panel === "saved") {
    useSavedStore.setState({
      saved: (results ? saved.saved : []) as never,
      savedIds: new Set(results ? saved.saved.map((s) => s.messageId) : []),
      loading: state === "loading",
      hasMore: results ? Boolean(saved.hasMore) : false,
      total: results ? saved.total : 0,
    });
  }
}

function ParityExtLpPanel({ props }: { props: ParityExtLpProps }) {
  const panel = props.params.get("panel");
  const { width, height } = parityExtLpBox(props);
  useMemo(() => parityExtLpPrime(props), [props]);
  const body = panel === "saved" ? <SavedPanel /> : panel === "activity" ? <ThreadsInbox /> : panel === "tasks" ? <TasksPanel /> : <MessageSearchPage />;
  // The app shell (not the panel) sets the shell header height (`--shell-header-height`: 56px
  // Elegant, 62px Brutal); this host has no shell root. The page canvas is the document body,
  // `--layer-canvas-muted` (index.css `body`): the Tasks panel is `dark:bg-transparent` over it.
  const brutal = props.params.get("parityTheme") === "brutal-light";
  const shell = { "--shell-header-height": "56px" } as Record<string, string>;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={props.raw}
        style={{ ...shell, width, height, overflow: "hidden", display: "flex", flexDirection: "column", background: brutal ? "white" : panel === "tasks" ? "var(--layer-canvas-muted, white)" : "var(--layer-canvas, white)" }}
      >
        {body}
      </div>
    </main>
  );
}

// Desktop rail bell: NotificationTrigger "rail-bottom" at the bottom of a rail-wide column; the popup
// opens to its right on hover (openOnHover, delay 0).
function ParityExtLpNotification({ props }: { props: ParityExtLpProps }) {
  useMemo(() => primeDirectVisualStores(props.raw), [props]);
  const brutal = props.params.get("parityTheme") === "brutal-light";
  const entries = (parityExtLpFixture.notifications as { id: string; kind: string; title: string; body: string }[])
    .map((n) => ({
      ...n,
      action: { label: "View", onClick: () => undefined },
      dismissalKey: `fp-${n.id}`,
    }));
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={props.raw}
        style={{ width: 420, height: 800, display: "flex", flexDirection: "column", justifyContent: "flex-end", overflow: "hidden", background: "white" }}
      >
        <div style={{ width: brutal ? 64 : 56, paddingBottom: 12 }}>
          <ParityExtLpNotificationTrigger flavor="rail-bottom" notifications={entries as never} />
        </div>
      </div>
    </main>
  );
}

// Shell-derived cases (section dialogs, archive confirm, emoji picker): the shell host's own view.
function ParityExtLpShell({ props }: { props: ParityExtLpProps }) {
  const p = {
    raw: props.raw,
    platform: props.platform,
    surface: props.params.get("surface") ?? "",
    preset: props.params.get("preset") ?? "default",
    theme: props.params.get("parityTheme") ?? "brutal-light",
    extra: Number(props.params.get("extra") ?? 0),
  };
  return <ParityExtShView p={p as never} />;
}

// Create channel dialog states (official stores + prefill, states driven by the case's interactions / routes).
function ParityExtLpCreateChannel({ props }: { props: ParityExtLpProps }) {
  useMemo(() => primeCreateChannelStores(), []);
  const { width, height } = parityExtLpBox(props);
  const named = props.params.get("name");
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={props.raw} style={{ width, height, overflow: "hidden" }}>
        <CreateChannelDialog
          prefilledName={named ?? ""}
          prefilledDescription={props.params.get("description") ?? ""}
          prefilledVisibility="public"
          onClose={() => undefined}
        />
      </div>
    </main>
  );
}

// Phone Computers page (MobileComputersPanel), the computers fixture and machine store like the desktop cases.
function ParityExtLpMobileComputers({ props }: { props: ParityExtLpProps }) {
  useMemo(() => {
    const list = props.params.get("list") ?? "default";
    parityExtPrimeStores({ extCase: props.extCase, extKind: "list", list, loading: props.params.get("loading") ?? undefined } as never);
    const status = props.params.get("loadStatus") ?? "loaded";
    useMachineStore.setState({
      loadStatus: status as never,
      loadError: props.params.get("loadError") === "true" ? "Failed to load" : null,
    } as never);
  }, [props]);
  const { width, height } = parityExtLpBox(props);
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={props.raw}
        style={{ ...parityExtShellVars(), width, height, overflow: "hidden", display: "flex", flexDirection: "column" }}
      >
        <ParityExtLpMobileComputersPanel />
      </div>
    </main>
  );
}

// Phone computer detail / Add dialog (the desktop case's props at 390 wide).
function ParityExtLpMobileMachine({ props }: { props: ParityExtLpProps }) {
  const sub = {
    extCase: props.extCase,
    extKind: props.extKind === "m-add" ? "add" : "detail",
    list: props.params.get("list") ?? "default",
    machine: props.params.get("machine") ?? undefined,
  };
  useMemo(() => parityExtPrimeStores(sub as never), [props]);
  const { width, height } = parityExtLpBox(props);
  const machineId = (parityExtFixture.machines as Record<string, Machine>)[sub.machine ?? ""]?.id;
  const machine = useMachineStore((s) => s.machines.find((m) => m.id === machineId));
  if (sub.extKind === "add") {
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div data-visual-case={props.raw} style={{ ...parityExtShellVars(), width, height }}>
          <ParityExtAddMachineDialog onClose={() => undefined} />
        </div>
      </main>
    );
  }
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={props.raw}
        className="bg-layer-canvas-muted theme-brutal:bg-white"
        style={{ ...parityExtShellVars(), width, height, display: "flex", flexDirection: "column", overflow: "hidden" }}
      >
        {machine ? <ParityExtMachineDetailPanel machine={machine} /> : null}
      </div>
    </main>
  );
}

// Channel member dialogs: ChannelMembers panel -> remove confirm, AddMembersDialog, CreateJointChannelDialog.
function parityExtLpGrantChannelCaps() {
  const caps = { addChannelMembers: true, removeChannelMembers: true };
  useChannelStore.setState({
    channels: useChannelStore.getState().channels.map((c) => (
      c.id === fxChannels.design.id ? { ...c, channelCapabilities: caps } : c
    )) as never,
  });
}

function ParityExtLpMemberDialog({ props }: { props: ParityExtLpProps }) {
  useMemo(() => {
    if (props.extKind === "create-joint") primeCreateChannelStores();
    else primeDirectVisualStores(props.raw);
    parityExtLpGrantChannelCaps();
  }, [props]);
  if (props.extKind === "remove-member") {
    return (
      <main className="min-h-screen bg-white p-4 font-display text-black">
        <div data-visual-case={props.raw}>
          <ChannelMembers channelId={fxChannels.design.id} />
        </div>
      </main>
    );
  }
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={props.raw} style={{ width: window.innerWidth, height: window.innerHeight, overflow: "hidden" }}>
        {props.extKind === "add-members" ? (
          <ParityExtLpAddMembersDialog
            channelId={fxChannels.design.id}
            prefilledHumanIds={[fxDesigner.id]}
            prefilledAgentIds={[fxProductUx.id]}
            onClose={() => undefined}
            onSubmitted={() => undefined}
          />
        ) : (
          <ParityExtLpCreateJointChannelDialog onClose={() => undefined} />
        )}
      </div>
    </main>
  );
}

function ParityExtLpView({ props }: { props: ParityExtLpProps }) {
  if (props.extKind === "panel") return <ParityExtLpPanel props={props} />;
  if (props.extKind === "notification") return <ParityExtLpNotification props={props} />;
  if (props.extKind === "shell") return <ParityExtLpShell props={props} />;
  if (props.extKind === "create-channel") return <ParityExtLpCreateChannel props={props} />;
  if (["remove-member", "add-members", "create-joint"].includes(props.extKind)) return <ParityExtLpMemberDialog props={props} />;
  if (props.extKind === "m-computers") return <ParityExtLpMobileComputers props={props} />;
  if (props.extKind === "m-detail" || props.extKind === "m-add") return <ParityExtLpMobileMachine props={props} />;
  return null;
}

function parityExtListPagesElement() {
  const props = parityExtLpProps();
  return props ? <ParityExtLpView props={props} /> : null;
}
