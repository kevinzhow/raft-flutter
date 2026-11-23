import { BrowserPanel as ParityBrowserPanel } from "../src/features/webPreview/BrowserPanel";
import { useBrowserTabsStore as parityBrowserStore } from "../src/features/webPreview/browserTabsStore";
import type { DesktopWebPreviewTabsBridge as ParityBrowserBridge } from "@botiverse/raft-shared";
import { PanelHeadLeadContext as ParityBrowserHeadLead } from "../src/components/layout/appPanelHead";
import { BrowserSwitchChip as ParityBrowserSwitchChip } from "../src/features/webPreview/SwitchChip";
import { browserChipWidth as parityBrowserChipWidth } from "../src/features/webPreview/browserHeadFit";
import ParityBrowserArtifactViewer from "../src/apps/artifacts/ArtifactViewer";
import parityBrowserArtifactFixture from "virtual:parity-ext/artifact-discussion";
import { planRow as parityBrowserPlanRow } from "../src/components/layout/rowPlan";
import { useRowPlanStore as parityBrowserRowPlan } from "../src/components/layout/rowPlanStore";

const parityBrowserBridge: ParityBrowserBridge = {
  open() {},
  activate() {},
  close() {},
  closeAll() {},
  back() {},
  forward() {},
  reload() {},
  setBounds() {},
  async setVisible() { return null; },
  onState() { return () => {}; },
};

function ParityBrowserView({ id, state }: { id: string; state: string }) {
  const conversation = "parity-browser";
  const artifact = state === "artifact-front";
  const dense = state === "narrow" || state === "overflow";
  const chip = state === "artifact-behind" || state === "narrow" || artifact;
  const titleFit = state === "short-front" || state === "long-front";
  useMemo(() => {
    const store = parityBrowserStore.getState();
    store.close(conversation);
    if (artifact) {
      primeDirectVisualStores(id);
      setServerFeatureFlagForTests(fxServer.id, "workspace_artifacts_v0", true);
    }
    if (dense) {
      for (let tab = 1; tab < 12; tab++) store.openUrl(conversation, `https://site${tab}.test/`);
    }
    if (titleFit) {
      parityBrowserRowPlan.setState({ plan: parityBrowserPlanRow({
        available: 1280,
        conversation: { saved: 800, contentMin: 360 },
        columns: [{ key: "browser", regions: ["artifact"], mins: [160], saved: 480 }],
        thread: null, expanded: null, expandFold: false, wasFolded: false,
      }) });
      for (const title of ["Loopback Alpha", "Loopback Bravo", "Loopback Charlie"]) {
        store.openUrl(conversation, `https://${title.split(" ")[1].toLowerCase()}.test/`);
        const tabId = parityBrowserStore.getState().browsers[conversation]!.activeId;
        store.applyState(conversation, {
          tabId, title, url: `https://${title.split(" ")[1].toLowerCase()}.test/`,
          canGoBack: false, canGoForward: false, loading: false,
        });
      }
    }
    store.openUrl(conversation, "http://localhost:8040/guide");
    if (titleFit) {
      const tabId = parityBrowserStore.getState().browsers[conversation]!.activeId;
      store.applyState(conversation, {
        tabId, title: state === "short-front" ? "Echo" : "Loopback Delta",
        url: "http://localhost:8040/guide",
        canGoBack: false, canGoForward: false, loading: false,
      });
    }
    if (artifact) {
      store.newTab(conversation);
      const browser = parityBrowserStore.getState().browsers[conversation]!;
      parityBrowserStore.setState({
        browsers: { [conversation]: { ...browser, frontAt: Date.now() - 1 } },
      });
    }
  }, [artifact, dense, id, state, titleFit]);
  const browser = parityBrowserStore((store) => store.browsers[conversation]);
  const artifactInFront = artifact && browser !== undefined && browser.parkedAt > browser.frontAt;
  return (
    <main className="thread-layout-container flex h-screen w-screen justify-end bg-layer-canvas" data-visual-case={id}>
      <div data-browser-fixture="" style={{ width: state === "narrow" ? 224 : 480, height: "100%" }}>
        {artifactInFront ? (
          <ParityBrowserHeadLead.Provider value={{
            node: <ParityBrowserSwitchChip conversationId={conversation} />,
            width: parityBrowserChipWidth(browser.tabs.length),
          }}>
            <ParityBrowserArtifactViewer
              target={{ id: parityBrowserArtifactFixture.artifactId, version: null }}
              source="message_card"
              expanded={false}
              covering={false}
              onClose={() => parityBrowserStore.getState().toFront(conversation)}
            />
          </ParityBrowserHeadLead.Provider>
        ) : <ParityBrowserPanel
          bridge={parityBrowserBridge}
          conversationId={conversation}
          covering={false}
          artifactBehind={chip}
        />}
      </div>
    </main>
  );
}

function parityExtBrowserElement() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("case") ?? "";
  return id.startsWith("components.browser.desktop.")
    ? <ParityBrowserView id={id} state={params.get("extCase") ?? "page"} />
    : null;
}
