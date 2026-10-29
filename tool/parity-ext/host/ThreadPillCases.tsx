// raft-flutter parity EXTENSION cases: the channel's "Earliest / Next unread
// thread" pill (Web v1.21.23 ThreadUnreadJumpPill, `thread_unread_badge_v0`).
// Appended to the generated VisualTestingCases.tsx (shares its imports and
// private helpers: primeDirectVisualStores, fxServer, Button); identifiers are
// prefixed `parityExtTp`. Ids: components.thread-pill.<top|bottom>.<theme>
// (tool/parity-ext/build-thread-pill.py).
//
// The REAL pill is mounted in a 420x200 relative box (the chat's message
// surface) with the followed-thread store seeded: `top` has its parents above
// everything loaded; `bottom` has them past the newest loaded message while
// newer ones exist, so the pill sits beside the "Back to bottom" button.
import { ThreadUnreadJumpPill as ParityExtTpPill } from "../src/components/message/ThreadUnreadJumpPill";
import { useThreadStore as parityExtTpUseThreadStore } from "../src/store/threadStore";
import { ArrowDown as ParityExtTpArrowDown } from "lucide-react";
import { Button as ParityExtTpButton } from "raft-ui";

function parityExtTpProps() {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.thread-pill.")) return null;
  return { raw, variant: params.get("variant") === "bottom" ? "bottom" : "top" };
}

function parityExtTpThread(id: string, parentAt: string) {
  return {
    threadChannelId: `thread-${id}`,
    parentMessageId: `msg-${id}`,
    parentChannelId: "channel-pill",
    parentChannelName: "pill",
    parentChannelType: "channel",
    parentMessagePreview: "Parent text",
    parentMessageSenderType: "user",
    parentMessageSenderId: "visual-human-jiacheng",
    parentMessageCreatedAt: parentAt,
    latestActivitySeq: "10",
    replyCount: 2,
    lastReplyAt: "2026-06-19T11:00:00.000Z",
    unreadCount: 1,
    hasMention: false,
    firstUnreadMessageId: `reply-${id}`,
    taskNumber: null,
  };
}

function ParityExtTpView({ p }: { p: NonNullable<ReturnType<typeof parityExtTpProps>> }) {
  useMemo(() => {
    primeDirectVisualStores(p.raw);
    setServerFeatureFlagForTests(fxServer.id, "thread_unread_badge_v0", true);
    const parentAt = p.variant === "top" ? "2026-06-19T08:00:00.000Z" : "2026-06-19T13:00:00.000Z";
    parityExtTpUseThreadStore.setState({
      followedThreads: [parityExtTpThread("a", parentAt), parityExtTpThread("b", parentAt)] as never,
    });
  }, [p.raw, p.variant]);
  const bottomButton = p.variant === "bottom" ? (
    <ParityExtTpButton size="sm" variant="outline" className="w-fit">
      <ParityExtTpArrowDown size={12} />
      Back to bottom
    </ParityExtTpButton>
  ) : null;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={p.raw} className="relative" style={{ width: 420, height: 200, overflow: "hidden", background: "white" }}>
        <ParityExtTpPill
          channelId="channel-pill"
          onJumpToMessage={() => undefined}
          bottomButton={bottomButton}
          loadedRange={{ oldestAt: "2026-06-19T09:00:00.000Z", newestAt: "2026-06-19T12:00:00.000Z", hasNewer: p.variant === "bottom" }}
          renderKey="pill"
        />
      </div>
    </main>
  );
}

function parityExtThreadPillElement() {
  const p = parityExtTpProps();
  return p ? <ParityExtTpView p={p} /> : null;
}
