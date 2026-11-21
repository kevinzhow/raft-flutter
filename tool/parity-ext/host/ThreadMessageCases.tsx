// raft-flutter parity EXTENSION cases: message-level surfaces (not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtMsg`). Ids: components.thread-ext.message.<surface>.<platform>.<theme>.
//
// Each case mounts the REAL product component:
//   toolbar* / picker*   -> message/MessageItem on a hovered row (MessageHoverToolbar,
//                           the reaction picker portal)
//   forward-*            -> message/ForwardedBundleCard
//   mermaid-*            -> mermaid/MermaidDiagram (toolbar + frame)
//   banner               -> message/NotificationActivationBanner
//   sos-*                -> message/SOSDialog (DialogCard max-w-sm) over the modal backdrop
// Data: tool/parity-ext/fixtures/threadmessages.json (the Flutter provider reads
// the same file; `routes` are answered by the extension provider spec).
import ParityExtMsgForwardedBundleCard from "../src/components/message/ForwardedBundleCard";
import type { ForwardedBundleMetadata as ParityExtMsgBundleMetadata } from "../src/components/message/ForwardedBundleCard";
import { MermaidDiagram as ParityExtMsgMermaidDiagram } from "../src/components/mermaid/MermaidDiagram";
import ParityExtMsgBanner from "../src/components/message/NotificationActivationBanner";
import ParityExtMsgSosDialog from "../src/components/message/SOSDialog";
import parityExtMsgFixture from "virtual:parity-ext/threadmessages";

type ParityExtMsgProps = {
  caseId: string;
  state: string;
  extCase: string;
  platform: "desktop" | "mobile";
  boxWidth: number | null;
  boxHeight: number | null;
  bundle: string;
  diagram: string;
};

function parityExtMsgProps(): ParityExtMsgProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.thread-ext.message.") || params.get("extKind") !== "threadmessage") return null;
  const num = (key: string) => {
    const value = params.get(key);
    return value ? Number(value) : null;
  };
  return {
    caseId: raw,
    state: params.get("state") ?? "",
    extCase: params.get("extCase") ?? "",
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    boxWidth: num("boxWidth"),
    boxHeight: num("boxHeight"),
    bundle: params.get("bundle") ?? "single",
    diagram: params.get("diagram") ?? "flow",
  };
}

// The column background a message sits on (ChatPanel / ThreadPanel scroller).
const parityExtMsgPanelClass = "bg-layer-panel theme-brutal:bg-white";

function ParityExtMsgRowView({ p }: { p: ParityExtMsgProps }) {
  const m = parityExtMsgFixture.message;
  useMemo(() => {
    primeDirectVisualStores(p.caseId);
    useSavedStore.setState({
      savedIds: new Set(p.state === "toolbar-saved" ? [m.id] : []),
    });
  }, [p, m.id]);
  const message: Message = {
    id: m.id,
    channelId: fxChannels.design.id,
    senderType: "agent",
    senderId: fxCindy.id,
    senderName: fxCindy.displayName,
    content: p.state === "quoted-mentions" ? parityExtMsgFixture.quotedMentions : m.content,
    threadId: null,
    createdAt: m.createdAt,
  };
  const channels = useChannelStore.getState().channels;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={p.caseId}
        className={p.state === "quoted-mentions" ? "bg-layer-canvas" : parityExtMsgPanelClass}
        style={{ width: p.boxWidth ?? 440, height: p.boxHeight ?? 112, padding: "32px 16px 0", boxSizing: "border-box" }}
      >
        <MessageItem
          message={message}
          mentionMap={buildMentionMap(visualAgents, visualMembers)}
          channels={channels}
          previewSenderAgent={visualAgents[0]}
          hideThreadActions={p.state === "toolbar-thread"}
        />
      </div>
    </main>
  );
}

function ParityExtMsgForwardView({ p }: { p: ParityExtMsgProps }) {
  useMemo(() => primeDirectVisualStores(p.caseId), [p]);
  const metadata = (parityExtMsgFixture.bundles as Record<string, unknown>)[p.bundle] as ParityExtMsgBundleMetadata;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={p.caseId} className={parityExtMsgPanelClass} style={{ width: p.boxWidth ?? 480 }}>
        <ParityExtMsgForwardedBundleCard metadata={metadata} />
      </div>
    </main>
  );
}

function ParityExtMsgMermaidView({ p }: { p: ParityExtMsgProps }) {
  useMemo(() => primeDirectVisualStores(p.caseId), [p]);
  const code = (parityExtMsgFixture.mermaid as Record<string, string>)[p.diagram];
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={p.caseId}
        className={parityExtMsgPanelClass}
        // flow-root keeps the diagram's 0.5rem block margin inside the box.
        style={{ width: p.boxWidth ?? 560, display: "flow-root" }}
      >
        <ParityExtMsgMermaidDiagram code={code} />
      </div>
    </main>
  );
}

function ParityExtMsgBannerView({ p }: { p: ParityExtMsgProps }) {
  useMemo(() => {
    primeDirectVisualStores(p.caseId);
    // The banner only shows while the push permission is still undecided; a
    // headless browser reports "denied", a user's browser "default".
    Object.defineProperty(Notification, "permission", { configurable: true, get: () => "default" });
  }, [p]);
  // The composer stack: the form column the banner sits above (desktop, own
  // `mx-3 mt-2` placement) or inside (mobile, passed to the composer).
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={p.caseId} className={parityExtMsgPanelClass} style={{ width: p.boxWidth ?? 480, display: "flow-root" }}>
        <ParityExtMsgBanner placement={p.platform} />
      </div>
    </main>
  );
}

function ParityExtMsgSosView({ p }: { p: ParityExtMsgProps }) {
  useMemo(() => primeDirectVisualStores(p.caseId), [p]);
  const sos = parityExtMsgFixture.sos;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={p.caseId} style={{ width: "100vw", height: "100vh" }} />
      <ParityExtMsgSosDialog channelId={sos.channelId} channelName={sos.channelName} onClose={() => undefined} />
    </main>
  );
}

function parityExtThreadMessageElement() {
  const p = parityExtMsgProps();
  if (!p) return null;
  if (p.state === "quoted-mentions" || p.state.startsWith("toolbar") || p.state.startsWith("picker")) return <ParityExtMsgRowView p={p} />;
  if (p.state === "forward") return <ParityExtMsgForwardView p={p} />;
  if (p.state === "mermaid") return <ParityExtMsgMermaidView p={p} />;
  if (p.state === "banner") return <ParityExtMsgBannerView p={p} />;
  if (p.state === "sos") return <ParityExtMsgSosView p={p} />;
  return null;
}
