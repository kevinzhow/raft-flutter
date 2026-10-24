// raft-flutter parity EXTENSION cases: conversation pages that had no case
// (inventory rows 3.03, 3.06-3.08, 3.11-3.14, 3.16, 3.18, 3.26-3.31, 3.34, 3.37-3.39; not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtCv`). Ids: components.conversation.<scene>.<platform>.<state>.<theme>.
//
// Each case mounts the REAL product surface and clips a window of it:
//   view=window -> message/ChatPanel (or ThreadPanel presentation="side") in the
//                  desktop main column (1280 - rail - 240 sidebar), the 400px side
//                  thread column or the 390 mobile page, like host/ThreadCases.tsx
//   view=row    -> message/MessageItem on a panel-coloured box (hover cards, menus,
//                  reactions, quotes, action cards, translation)
// Data: tool/parity-ext/fixtures/conversation.json (`routes` + `routeSets` are
// answered by the provider spec for React and by the fake client for Flutter).
import ParityExtCvThreadPanel from "../src/components/message/ThreadPanel";
import { useThreadStore as parityExtCvThreadStore } from "../src/store/threadStore";
import { useTranslationStore as parityExtCvTranslationStore } from "../src/store/translationStore";
import parityExtCvFixture from "virtual:parity-ext/conversation";
import type { CSSProperties as ParityExtCvCSSProperties } from "react";

type ParityExtCvProps = {
  caseId: string;
  extCase: string;
  view: "window" | "row" | "external-detail";
  platform: "desktop" | "mobile";
  surface: "chat" | "thread";
  channel: string;
  winY: number;
  winH: number;
  serverRole: string;
  threadKey: string;
  resolveFailed: boolean;
  row: string;
  translate: string;
  boxWidth: number | null;
  boxHeight: number | null;
  padX: number;
  padTop: number;
};

function parityExtCvProps(): ParityExtCvProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.conversation.") || params.get("extKind") !== "conversation") return null;
  const num = (key: string) => {
    const value = params.get(key);
    return value ? Number(value) : null;
  };
  return {
    caseId: raw,
    extCase: params.get("extCase") ?? "",
    view: params.get("view") === "row" ? "row" : params.get("view") === "external-detail" ? "external-detail" : "window",
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    surface: params.get("surface") === "thread" ? "thread" : "chat",
    channel: params.get("chan") ?? "",
    winY: Number(params.get("winY") ?? 0),
    winH: Number(params.get("winH") ?? 120),
    serverRole: params.get("serverRole") ?? "owner",
    threadKey: params.get("threadKey") ?? "main",
    resolveFailed: params.get("resolveFailed") === "true",
    row: params.get("row") ?? "",
    translate: params.get("translate") ?? "",
    boxWidth: num("boxWidth"),
    boxHeight: num("boxHeight"),
    padX: num("padX") ?? 16,
    padTop: num("padTop") ?? 32,
  };
}

function parityExtCvTheme(): string {
  return new URLSearchParams(window.location.search).get("parityTheme") ?? "brutal-light";
}

function parityExtCvPrimeStores(p: ParityExtCvProps) {
  primeDirectVisualStores(p.caseId);
  useChannelStore.setState({
    channels: parityExtCvFixture.channels as never,
    dmChannels: parityExtCvFixture.dms as never,
    loading: false,
  });
  useMessageStore.setState({ currentChannelId: p.channel || null, currentUserId: fxOwner.id });
  if (p.resolveFailed) {
    // ThreadPanel with no thread channel and a failed open: "Couldn't load" + Retry.
    const t = (parityExtCvFixture.threads as Record<string, { parentChannelId: string; parentMessageId: string }>)[p.threadKey];
    parityExtCvThreadStore.setState({
      openThreadError: { parentChannelId: t.parentChannelId, parentMessageId: t.parentMessageId },
      openThreadLoading: false,
    } as never);
  }
  if (p.serverRole !== "owner") {
    useServerStore.setState((s) => ({ current: s.current ? { ...s.current, role: p.serverRole as never } : s.current }));
  }
}

function ParityExtCvWindowView({ p }: { p: ParityExtCvProps }) {
  useMemo(() => parityExtCvPrimeStores(p), [p]);
  const brutal = parityExtCvTheme() === "brutal-light";
  // AppShell root sets the header height the PanelHeader recipe reads.
  const shellVars = { ["--shell-header-height" as string]: "56px" } as ParityExtCvCSSProperties;
  const mobile = p.platform === "mobile";
  const viewportHeight = window.innerHeight;
  const width = mobile ? 390 : p.surface === "thread" ? 400 : 1280 - (brutal ? 64 : 56) - 240;
  const channel = useChannelStore((s) => [...s.channels, ...s.dmChannels].find((c) => c.id === p.channel) ?? null);
  const t = (parityExtCvFixture.threads as Record<string, { parentChannelId: string; parentMessageId: string; threadChannelId: string }>)[p.threadKey];
  const top = p.winY < 0 ? viewportHeight + p.winY : p.winY;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={p.caseId} style={{ ...shellVars, width, height: p.winH, overflow: "hidden", position: "relative" }}>
        <div
          // The transform also makes the column the containing block of the
          // mobile page's `fixed` header, so a window cannot leak it.
          className={p.surface === "thread"
            ? `${mobile ? "thread-side-column " : ""}flex flex-col bg-layer-card theme-brutal:bg-white`
            : "flex flex-col"}
          style={{ width, height: viewportHeight, position: "absolute", left: 0, top: 0, transform: `translateY(${-top}px)` }}
        >
          {p.surface === "thread" ? (
            <ParityExtCvThreadPanel
              presentation="side"
              threadIdentity={{ parentMessageId: t.parentMessageId, parentChannelId: t.parentChannelId, threadChannelId: p.resolveFailed ? undefined : t.threadChannelId }}
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

// The column background a message sits on (ChatPanel / ThreadPanel scroller).
const parityExtCvPanelClass = "bg-layer-panel theme-brutal:bg-white";

type ParityExtCvRow = {
  message: Record<string, unknown>;
  threadSummary?: Record<string, unknown>;
  linkedTask?: Record<string, unknown>;
  hideThreadActions?: boolean;
};


// Translation row states: the auto-translation settings and the entry the message list's
// batch request would have stored (the row view mounts MessageItem without the list).
function parityExtCvPrimeTranslation(p: ParityExtCvProps, messageId: string, content: string) {
  if (!p.translate) return;
  const display = p.translate === "bilingual" ? "bilingual" : "translated";
  parityExtCvTranslationStore.setState({
    settings: {
      preferredLanguage: "zh-CN", effectiveLanguage: "zh-cn", preferredTimezone: null, effectiveTimezone: null,
      autoTranslationEnabled: true, preferredTranslationMode: "auto", preferredTranslationDisplay: display,
      preferredTimeFormat: null, effectiveTimeFormat: "24h", available: true, serverTranslationEnabled: true,
      providerAvailable: true, canManageServerTranslation: false,
    },
    entries: p.translate === "translating" ? { [messageId]: { messageId, status: "pending", targetLanguage: "zh-cn", originalContent: content, pendingSince: Date.now() } } : {
      [messageId]: p.translate === "failed"
        ? { messageId, status: "failed", reason: "provider", targetLanguage: "zh-cn", originalContent: content }
        : {
          messageId, status: "translated", sourceLanguage: "en", targetLanguage: "zh-cn", originalContent: content,
          translatedContent: "已截取视觉基线，并将 React 对照排入队列。",
          ...(p.translate === "original" ? { showOriginal: true } : {}),
        },
    },
  } as never);
}

function ParityExtCvRowView({ p }: { p: ParityExtCvProps }) {
  useMemo(() => primeDirectVisualStores(p.caseId), [p.caseId]);
  const spec = (parityExtCvFixture.rows as Record<string, ParityExtCvRow>)[p.row];
  const message = { channelId: fxChannels.design.id, threadId: null, ...spec.message } as unknown as Message;
  useMemo(() => parityExtCvPrimeTranslation(p, spec.message.id as string, message.content), [p, spec, message.content]);
  // Permalinks point at the page's own origin (the preview only resolves current-host links).
  message.content = message.content.replaceAll("__ORIGIN__", window.location.origin);
  const channels = useChannelStore.getState().channels;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={p.caseId}
        className={parityExtCvPanelClass}
        // flow-root keeps the row's own block margins inside the box (auto height).
        style={{ width: p.boxWidth ?? 440, height: p.boxHeight ?? undefined, padding: `${p.padTop}px ${p.padX}px 0`, boxSizing: "border-box", display: "flow-root" }}
      >
        <MessageItem
          message={message}
          mentionMap={buildMentionMap(visualAgents, visualMembers)}
          channels={channels}
          previewSenderAgent={message.senderId === fxCindy.id ? visualAgents[0] : undefined}
          threadSummary={spec.threadSummary as never}
          linkedTask={spec.linkedTask as never}
          hideThreadActions={spec.hideThreadActions}
        />
      </div>
    </main>
  );
}

// components/profile/ExternalIdentityDetailPanel.tsx in its own panel-sized frame.
function ParityExtCvExternalDetailView({ p }: { p: ParityExtCvProps }) {
  useMemo(() => primeDirectVisualStores(p.caseId), [p.caseId]);
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={p.caseId}
        className="flex flex-col overflow-hidden border border-line-muted bg-layer-panel theme-brutal:border-2 theme-brutal:border-black"
        style={{ width: p.boxWidth ?? 380, height: p.boxHeight ?? 640 }}
      >
        <ExternalIdentityDetailPanel
          profile={parityExtCvFixture.externalProfile as never}
          onClose={() => undefined}
        />
      </div>
    </main>
  );
}

function parityExtConversationElement() {
  const p = parityExtCvProps();
  if (!p) return null;
  if (p.view === "external-detail") return <ParityExtCvExternalDetailView p={p} />;
  if (p.view === "row") return <ParityExtCvRowView p={p} />;
  return <ParityExtCvWindowView p={p} />;
}
