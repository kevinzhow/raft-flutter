import parityExtSearchPageFixture from "virtual:parity-ext/search-page";
import { SearchScopeContext as ParityExtSearchPageScope } from "../src/features/search/searchScope";

const parityExtSearchPageParams = new URLSearchParams(window.location.search);
const parityExtSearchPageId = parityExtSearchPageParams.get("case") ?? "";
const parityExtSearchPageState = parityExtSearchPageParams.get("extCase");
const parityExtSearchPageScoped = parityExtSearchPageState === "scoped";
if (parityExtSearchPageId.startsWith("components.search-ext.")) {
  const route = parityExtSearchPageScoped ? `/channel/${fxChannels.design.id}/search` : "/search";
  window.history.replaceState(null, "", `/s/${fxServer.slug}${route}?${parityExtSearchPageParams}`);
}

function ParityExtSearchPage() {
  useMemo(() => {
    primeDirectVisualStores(parityExtSearchPageId);
    const channel = { ...parityExtSearchPageFixture.privateChannel, serverId: fxServer.id };
    useChannelStore.setState((store) => ({ channels: [...store.channels, channel as Channel] }));
    setServerFeatureFlagForTests(fxServer.id, "workspace_artifacts_v0", parityExtSearchPageState === "artifacts");
  }, []);
  const phone = parityExtSearchPageParams.get("platform") === "mobile";
  return (
    <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
      <div data-visual-case={parityExtSearchPageId} className="flex flex-col overflow-hidden"
        style={{ width: phone ? 390 : 1280, height: phone ? 844 : 900 }}>
        <ParityExtSearchPageScope.Provider value={
          parityExtSearchPageScoped ? { kind: "channel", id: fxChannels.design.id } : null
        }>
          <MessageSearchPage />
        </ParityExtSearchPageScope.Provider>
      </div>
    </main>
  );
}

function parityExtSearchPageElement() {
  return parityExtSearchPageId.startsWith("components.search-ext.") ? <ParityExtSearchPage /> : null;
}
