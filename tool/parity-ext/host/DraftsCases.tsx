// The real /drafts route with the same device-local draft that Flutter reads.
import parityExtDraftsFixture from "virtual:parity-ext/drafts-v124";
import { draftsStorageKey, draftTimesStorageKey } from "../src/store/draftStorage";

function parityExtDraftsProps() {
  const query = new URLSearchParams(window.location.search);
  const id = query.get("case") ?? "";
  if (!id.startsWith("components.pages.drafts-v124.")) return null;
  return { id, hasDraft: query.get("state") === "private" };
}

(function parityExtDraftsPrimeRoute() {
  if (typeof window === "undefined" || !parityExtDraftsProps()) return;
  window.history.replaceState(null, "", `/s/${fxServer.slug}/drafts${window.location.search}`);
})();

function ParityExtDraftsView({ id, hasDraft }: { id: string; hasDraft: boolean }) {
  useMemo(() => {
    const channels = parityExtDraftsFixture.routes["GET /channels"];
    const drafts = hasDraft ? { [channels[0].id]: parityExtDraftsFixture.draft } : {};
    window.localStorage.setItem(draftsStorageKey(fxOwner.id), JSON.stringify(drafts));
    window.localStorage.removeItem(draftTimesStorageKey(fxOwner.id));
    primeDirectVisualStores(id);
    setServerFeatureFlagForTests(fxServer.id, "drafts_section_v0", true);
    useChannelStore.setState({ channels: channels as never, dmChannels: [], loading: false });
    useMessageStore.setState({
      currentUserId: fxOwner.id,
      currentChannelId: null,
      drafts,
      // Legacy local drafts can have no timestamp. Both providers use that format.
      draftUpdatedAt: {},
    });
  }, [id, hasDraft]);
  return (
    <div data-visual-case={id} className="flex h-dvh w-full min-h-0 flex-col overflow-hidden bg-layer-canvas">
      <Routes>
        <Route path="/s/:serverSlug/*" element={<MainLayout />} />
      </Routes>
    </div>
  );
}

function parityExtDraftsElement() {
  const props = parityExtDraftsProps();
  return props ? <ParityExtDraftsView {...props} /> : null;
}
