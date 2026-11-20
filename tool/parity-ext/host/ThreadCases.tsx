// raft-flutter parity EXTENSION cases: thread panel and message timeline
// states (not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtTh`). Ids: components.thread-ext.<scene>.<platform>.<state>.<theme>
// (the sibling families attachment./message. live in their own host files).
//
// Each case mounts the REAL product surface the Web shell shows and clips a
// window of it:
//   surface=thread -> message/ThreadPanel presentation="side" in the 400px
//                     side thread column (desktop) / the 390 page (mobile)
//   surface=chat   -> message/ChatPanel in the desktop main column
//                     (1280 - rail - 240 sidebar) or the 390 mobile page
//   surface=inbox  -> thread/ThreadsInbox in the official 342x620 box
// The window is (winY, winH) in column coordinates; winY < 0 counts from the
// bottom. Data: tool/parity-ext/fixtures/thread.json (`routes` + `routeSets`
// are answered by the provider spec for React and by the fake client for
// Flutter).
import { ThreadPanel as ParityExtThThreadPanel } from "../src/features/thread/ThreadPanel";
import { planRow as parityExtThPlanRow } from "../src/components/layout/rowPlan";
import { useRowPlanStore as parityExtThRowPlan } from "../src/components/layout/rowPlanStore";
import { useThreadStore as parityExtThThreadStore } from "../src/store/threadStore";
import parityExtThFixture from "virtual:parity-ext/thread";
import type { CSSProperties as ParityExtThCSSProperties } from "react";

type ParityExtThProps = {
  extCase: string;
  platform: "desktop" | "mobile";
  surface: "thread" | "chat" | "inbox";
  channel: string;
  winY: number;
  winH: number;
  longChannelName: string | null;
  routeSet: string;
};

function parityExtThProps(): ParityExtThProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.thread-ext.") || params.get("extKind") !== "thread") return null;
  const surface = params.get("surface");
  return {
    extCase: params.get("extCase") ?? "",
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    surface: surface === "chat" || surface === "inbox" ? surface : "thread",
    channel: params.get("channel") ?? "channel-design",
    winY: Number(params.get("winY") ?? 0),
    winH: Number(params.get("winH") ?? 120),
    longChannelName: params.get("longChannelName"),
    routeSet: params.get("routeSet") ?? "",
  };
}

function parityExtThTheme(): string {
  return new URLSearchParams(window.location.search).get("parityTheme") ?? "brutal-light";
}

function parityExtThPrimeStores(props: ParityExtThProps) {
  primeDirectVisualStores(new URLSearchParams(window.location.search).get("case") ?? "");
  useChannelStore.setState({
    channels: parityExtThFixture.channels.map((channel) =>
      props.longChannelName && channel.id === props.channel
        ? { ...channel, name: props.longChannelName }
        : channel) as never,
    dmChannels: parityExtThFixture.dms as never,
    loading: false,
  });
  useMessageStore.setState({ currentChannelId: props.channel, currentUserId: fxOwner.id });
  if (props.longChannelName) {
    const thread = parityExtThFixture.thread;
    const routes = (parityExtThFixture.routeSets as Record<string, Record<string, any>>)[props.routeSet];
    const channelPage = routes[`GET /messages/channel/${thread.parentChannelId}`];
    parityExtThThreadStore.setState({
      openParentMessageId: thread.parentMessageId,
      openParentChannelId: thread.parentChannelId,
      summaries: channelPage.threadSummariesByParentMessageId,
    });
    if (props.platform === "desktop") {
      const available = window.innerWidth - 56 - 240;
      parityExtThRowPlan.setState({ plan: parityExtThPlanRow({
        available, conversation: { saved: available - 400, contentMin: 360 },
        thread: { saved: 400, contentMin: 360 },
        columns: [{ key: "col:0", regions: ["thread"], mins: [360], saved: 400 }],
        expanded: null, expandFold: false, wasFolded: false,
      }) });
    }
  }
}

function ParityExtThView({ props }: { props: ParityExtThProps }) {
  const caseId = new URLSearchParams(window.location.search).get("case") ?? "";
  useMemo(() => parityExtThPrimeStores(props), [props]);
  const theme = parityExtThTheme();
  const brutal = theme === "brutal-light";
  // AppShell root sets the header height the PanelHeader recipe reads.
  const shellVars = { ["--shell-header-height" as string]: props.longChannelName ? "var(--header-height)" : "56px" } as ParityExtThCSSProperties;
  const mobile = props.platform === "mobile";
  // WorkspaceView's mounted desktop pane starts below its 44px window bar.
  const paneInset = props.longChannelName && !mobile ? 44 : 0;
  const viewportHeight = window.innerHeight - paneInset;
  // Desktop main column: viewport - LeftRail (brutal 64 / elegant 56) - 240 sidebar.
  const width = mobile
    ? 390
    : props.surface === "thread" ? 400 : 1280 - (brutal ? 64 : 56) - 240;
  const channel = useChannelStore((s) => [...s.channels, ...s.dmChannels].find((c) => c.id === props.channel) ?? null);
  const t = parityExtThFixture.thread;
  const top = props.winY < 0 ? viewportHeight + props.winY : props.winY;
  if (props.surface === "inbox") {
    // The official activity-results box: the inbox in a 342x620 column.
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div data-visual-case={caseId} style={{ width: 342, height: 620, overflow: "hidden" }}>
          <ThreadsInbox />
        </div>
      </main>
    );
  }
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black" style={{ paddingTop: paneInset }}>
      <div data-visual-case={caseId} style={{ ...shellVars, width, height: props.winH, overflow: "hidden", position: "relative", marginLeft: props.longChannelName && !mobile ? "auto" : undefined }}>
        <div
          // The transform also makes the column the containing block of the
          // mobile page's `fixed` header, so a window cannot leak it.
          // MainLayout's SideThreadColumn; on a portrait phone its index.css
          // rules drop the panel's left border (the thread is first in the row).
          className={props.surface === "thread"
            ? `${mobile ? "thread-side-column " : ""}flex flex-col bg-layer-card theme-brutal:bg-white`
            : "flex flex-col"}
          style={{ width, height: viewportHeight, position: "absolute", left: 0, top: 0, transform: `translateY(${-top}px)` }}
        >
          {props.surface === "thread" ? (
            <ParityExtThThreadPanel
              presentation="side"
              allowExpand={props.longChannelName ? !mobile : undefined}
              threadIdentity={{ parentMessageId: t.parentMessageId, parentChannelId: t.parentChannelId, threadChannelId: t.threadChannelId }}
              onClose={() => undefined}
            />
          ) : (
            <ChatPanel channel={channel} />
          )}
        </div>
      </div>
    </main>
  );
}

function parityExtThreadElement() {
  const props = parityExtThProps();
  return props ? <ParityExtThView props={props} /> : null;
}
