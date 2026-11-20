// raft-flutter parity EXTENSION cases: the Tasks board page and the task detail
// modal (not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtTd`). Ids:
//   components.taskspage.<platform>.<state>.<theme>
//   components.taskdetail.<platform>.<state>.<theme>
//
// Both mount the REAL MainLayout on the Tasks route (`/s/<slug>/tasks`), the
// way the app shows it (LeftRail + TasksPanel on desktop, TasksPanel + the
// floating MobileTabBar on mobile). A detail case additionally carries the
// route's `?task=<channel>:<message>` deep link and the store state
// `openTaskModal` leaves behind, so MainLayout's own RightPanel renders what
// the app renders for a task opened from the board: <Modal closeOnBackdrop>
// holding ThreadPanelWrapper presentation="modal" (>= 768 wide), or the
// full-screen "mobile-modal" overlay; both are TaskModalBar + the real
// TaskModalHead (parentSlot) + the real ThreadPanel (hideHeader,
// hideParentMessage). Nothing of that composition is copied here.
// Data: tool/parity-ext/fixtures/taskdetail.json (the Flutter provider reads
// the same file); its `routes` + the case's `routeSet` answer the API reads
// (see parityExtRoutes in tool/parity-ext/run).
import { useThreadStore as parityExtTdThreadStore } from "../src/store/threadStore";
// MainLayout lazy-loads these on first use; importing them here puts them in
// the host's module graph so the first capture never races the chunk fetch
// (the modal head would still show its Suspense skeleton).
import "../src/components/task/TaskModalHead";
import "../src/features/thread/ThreadPanel";
import parityExtTdFixture from "virtual:parity-ext/taskdetail";

type ParityExtTdProps = {
  kind: "taskspage" | "taskdetail";
  caseId: string;
  platform: "desktop" | "mobile";
  detail: string | null;
};

function parityExtTdProps(): ParityExtTdProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  const kind = params.get("extKind");
  if (!(raw.startsWith("components.taskspage.") || raw.startsWith("components.taskdetail."))) return null;
  if (kind !== "taskspage" && kind !== "taskdetail") return null;
  return {
    kind,
    caseId: raw,
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    detail: params.get("detail"),
  };
}

// Route-based cases need the browser URL in place BEFORE BrowserRouter mounts
// (see primeVisualRoutePath in the official host); this module-scope pass runs
// ahead of the React render.
(function parityExtTdPrimeRoute() {
  if (typeof window === "undefined") return;
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!(raw.startsWith("components.taskspage.") || raw.startsWith("components.taskdetail."))) return;
  const path = `/s/${fxServer.slug}/tasks`;
  const detail = params.get("detail");
  const entry = detail ? (parityExtTdFixture.details as Record<string, { task: { channelId: string; messageId: string } }>)[detail] : null;
  if (entry) params.set("task", `${entry.task.channelId}:${entry.task.messageId}`);
  if (window.location.pathname !== path || entry) {
    window.history.replaceState(null, "", `${path}?${params.toString()}`);
  }
})();

function parityExtTdPrimeStores(props: ParityExtTdProps) {
  primeNavigationVisualStores();
  const serverId = parityExtTdFixture.serverId;
  const board = parityExtTdFixture.board as unknown as Task[];
  useChannelStore.setState({
    channels: parityExtTdFixture.channels as never,
    dmChannels: [],
    loading: false,
  });
  useMessageStore.setState({ currentChannelId: parityExtTdFixture.channels[0].id, currentUserId: fxOwner.id });
  const lane = { nextCursor: null, loading: false, loaded: true };
  const entry = props.detail
    ? (parityExtTdFixture.details as Record<string, { task: Task & { threadChannelId: string } }>)[props.detail]
    : null;
  useTaskStore.setState({
    serverTasks: board,
    serverLoading: false,
    serverTasksLoaded: true,
    serverTaskPages: { todo: lane, in_progress: lane, in_review: lane, done: lane, closed: lane },
    tasks: entry ? [entry.task] : [],
    loading: false,
    currentChannelId: entry ? entry.task.channelId : null,
    tasksByChannelId: entry ? { [entry.task.channelId]: [entry.task] } : {},
    loadedByChannelId: entry ? { [entry.task.channelId]: true } : {},
    loadingByChannelId: {},
  } as never);
  if (entry) {
    // What openTaskModal leaves in the slot once the thread lookup answered,
    // so the first frame is the loaded modal (the URL `task=` param matches
    // it, so the URL->store pass does not reopen it).
    parityExtTdThreadStore.setState({
      taskModal: {
        parentMessageId: entry.task.messageId,
        parentChannelId: entry.task.channelId,
        threadChannelId: entry.task.threadChannelId,
        serverSlug: fxServer.slug,
        focusedMessageId: null,
        loading: false,
        error: null,
      },
    } as never);
  }
  void serverId;
}

function ParityExtTdView({ props }: { props: ParityExtTdProps }) {
  useMemo(() => parityExtTdPrimeStores(props), [props]);
  const mobile = props.platform === "mobile";
  // MainLayout's `flex-1` root stretches to the full viewport inside a flex
  // column wrapper, like the real App.tsx shell (see HomeLoadingRouteVisualCaseView).
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={props.caseId}
        style={{ width: mobile ? 390 : 1280, height: mobile ? 844 : 800, overflow: "hidden", display: "flex", flexDirection: "column" }}
      >
        <Routes>
          <Route path="/s/:serverSlug/*" element={<MainLayout />} />
        </Routes>
      </div>
    </main>
  );
}

function parityExtTdElement() {
  const props = parityExtTdProps();
  return props ? <ParityExtTdView props={props} /> : null;
}
