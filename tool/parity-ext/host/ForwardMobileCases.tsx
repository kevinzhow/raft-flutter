// raft-flutter parity EXTENSION cases: the phone forward page (Web
// ForwardComposerMobile via ForwardComposerDialog below md). Appended to the
// generated VisualTestingCases.tsx like host/ConversationPageCases.tsx (shares
// its imports and helpers); identifiers are prefixed `parityExtFm`.
//
// Ids: components.forward-mobile.page.<state>.<theme>. The REAL
// ForwardComposerDialog is mounted full-viewport at 390x844 with the channel /
// DM stores seeded from tool/parity-ext/fixtures/forwardmobile.json; the target
// search answers the fixture route `GET /messages/forward/targets/search`
// (routeSets: fm-empty, fm-error, fm-loading). State is reached by the case's
// interactions (type in the search, "Select multiple", tap a row).
import ParityExtFmDialog from "../src/components/message/ForwardComposerDialog";
import parityExtFmFixture from "virtual:parity-ext/forwardmobile";

function parityExtFmProps() {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.forward-mobile.") || params.get("extKind") !== "forward-mobile") return null;
  return { raw };
}

function ParityExtFmView({ raw }: { raw: string }) {
  useMemo(() => {
    primeDirectVisualStores(raw);
    useChannelStore.setState({
      channels: parityExtFmFixture.channels as never,
      dmChannels: parityExtFmFixture.dms as never,
      loading: false,
    });
    useMessageStore.setState({ currentChannelId: parityExtFmFixture.channels[0]!.id, currentUserId: fxOwner.id });
  }, [raw]);
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={raw} style={{ width: "100vw", height: "100vh" }}>
        <ParityExtFmDialog
          sourceMessages={parityExtFmFixture.messages as never}
          sourceChannel={parityExtFmFixture.channels[0] as never}
          onClose={() => undefined}
          onSent={() => undefined}
        />
      </div>
    </main>
  );
}

function parityExtForwardMobileElement() {
  const p = parityExtFmProps();
  return p ? <ParityExtFmView raw={p.raw} /> : null;
}
