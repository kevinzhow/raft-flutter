// raft-flutter parity EXTENSION cases: conversation headers (not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtCh`). Ids: components.channelheader.<platform>.<state>.<theme>.
//
// Each case mounts the REAL product surface the Web shell shows and clips a
// window at its top (header + the Chat/Tasks/Files tab strip):
//   channel / DM -> message/ChatPanel in the desktop main column
//                   (1280 - rail - 240 sidebar) or the 390 mobile page
//   thread       -> message/ThreadPanel presentation="side" in the 400px
//                   side thread column (desktop) / full width (mobile)
// Data: tool/parity-ext/fixtures/channelheader.json (the Flutter provider
// reads the same file).
import ParityExtChThreadPanel from "../src/components/message/ThreadPanel";
import parityExtChFixture from "virtual:parity-ext/channelheader";
import type { CSSProperties as ParityExtChCSSProperties } from "react";

type ParityExtChProps = {
  extCase: string;
  platform: "desktop" | "mobile";
  channel: string;
  thread: boolean;
  windowHeight: number;
};

function parityExtChProps(): ParityExtChProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.channelheader.") || params.get("extKind") !== "channelheader") return null;
  return {
    extCase: params.get("extCase") ?? "",
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    channel: params.get("channel") ?? "",
    thread: params.get("thread") === "true",
    windowHeight: Number(params.get("windowHeight") ?? 120),
  };
}

function parityExtChTheme(): string {
  return new URLSearchParams(window.location.search).get("parityTheme") ?? "brutal-light";
}

function parityExtChPrimeStores(props: ParityExtChProps) {
  primeDirectVisualStores(new URLSearchParams(window.location.search).get("case") ?? "");
  useChannelStore.setState({
    channels: parityExtChFixture.channels as never,
    dmChannels: parityExtChFixture.dms as never,
    loading: false,
  });
  useMessageStore.setState({ currentChannelId: props.channel, currentUserId: fxOwner.id });
}

function ParityExtChView({ props }: { props: ParityExtChProps }) {
  const caseId = new URLSearchParams(window.location.search).get("case") ?? "";
  useMemo(() => parityExtChPrimeStores(props), [props]);
  const theme = parityExtChTheme();
  const brutal = theme === "brutal-light";
  // AppShell root sets the header height the PanelHeader recipe reads.
  const shellVars = { ["--shell-header-height" as string]: brutal ? "62px" : "56px" } as ParityExtChCSSProperties;
  const mobile = props.platform === "mobile";
  const viewportHeight = window.innerHeight;
  // Desktop main column: viewport - LeftRail (brutal 64 / elegant 56) - 240 sidebar.
  const width = mobile ? 390 : props.thread ? 400 : 1280 - (brutal ? 64 : 56) - 240;
  const channel = useChannelStore((s) => [...s.channels, ...s.dmChannels].find((c) => c.id === props.channel) ?? null);
  const t = parityExtChFixture.thread;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={caseId} style={{ ...shellVars, width, height: props.windowHeight, overflow: "hidden", position: "relative" }}>
        <div
          // MainLayout's SideThreadColumn; on a portrait phone its index.css
          // rules drop the panel's left border (the thread is first in the row).
          className={props.thread
            ? `${mobile ? "thread-side-column " : ""}flex flex-col bg-layer-card theme-brutal:bg-white`
            : "flex flex-col"}
          style={{ width, height: viewportHeight }}
        >
          {props.thread ? (
            <ParityExtChThreadPanel
              presentation="side"
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

function parityExtChannelHeaderElement() {
  const props = parityExtChProps();
  return props ? <ParityExtChView props={props} /> : null;
}
