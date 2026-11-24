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
import { rememberArtifactShownTitle as parityRememberBrowserArtifact } from "../src/apps/artifacts/artifactShownTitle";
import { useArtifactViewerStore as parityBrowserArtifactStore } from "../src/apps/artifacts/artifactViewerStore";
import { MessageWebLink as ParityBrowserMessageLink } from "../src/components/message/MessageWebLink";
import { HowWebLinksOpenSetting as ParityBrowserLinkSetting } from "../src/features/webPreview/HowWebLinksOpenSetting";
import type { DesktopWebPreviewBridge as ParityWebPreviewBridge } from "@botiverse/raft-shared";
import { ContextMenu as ParityBrowserContextMenu, ContextMenuTrigger as ParityBrowserContextTrigger, ContextMenuContent as ParityBrowserContextContent, ContextMenuItem as ParityBrowserContextItem, ListRowGroup as ParityBrowserListRowGroup } from "@botiverse/raft-ui";
import { PanelRight as ParityBrowserPanelRight, ArrowUpRight as ParityBrowserArrowUpRight } from "lucide-react";

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

function ParityBrowserView({ id, state, artifactTitle }: { id: string; state: string; artifactTitle: string | null }) {
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
    if (artifactTitle) {
      const artifactId = parityBrowserArtifactFixture.artifactId;
      parityRememberBrowserArtifact(artifactId, artifactTitle);
      parityBrowserArtifactStore.getState().openArtifact({
        id: artifactId, version: null, conversationId: conversation, source: "message_card",
      });
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
  }, [artifact, artifactTitle, dense, id, state, titleFit]);
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

function ParityBrowserWebLink({ id, state }: { id: string; state: string }) {
  const [offeredUrl, offerLinkMenu] = useState<string>();
  useMemo(() => {
    primeDirectVisualStores(id);
    setServerFeatureFlagForTests(fxServer.id, "desktop_web_preview_view_v0", true);
    const webPreview: ParityWebPreviewBridge = {
      ...parityBrowserBridge,
      offerLinkMenu,
      onOpenLinkBeside: () => () => {},
    };
    (window as unknown as { raftDesktop: { webPreview: ParityWebPreviewBridge } }).raftDesktop = { webPreview };
  }, [id]);
  const link = <ParityBrowserMessageLink href="https://example.test/guide">Open guide</ParityBrowserMessageLink>;
  return (
    <main className="flex h-screen w-screen justify-center bg-layer-canvas" data-visual-case={id} data-web-preview-host="parity-browser">
      {state === "web-link-setting" ? (
        <div className="w-[760px] self-start pt-8">
          <ParityBrowserListRowGroup><ParityBrowserLinkSetting /></ParityBrowserListRowGroup>
        </div>
      ) : state === "web-link-menu" ? (
        <ParityBrowserContextMenu>
          <ParityBrowserContextTrigger className="self-center" data-testid="browser-link-trigger">{link}</ParityBrowserContextTrigger>
          {offeredUrl === "https://example.test/guide" && (
            <ParityBrowserContextContent data-testid="desktop-web-link-menu">
              <ParityBrowserContextItem><ParityBrowserPanelRight />Open beside</ParityBrowserContextItem>
              <ParityBrowserContextItem><ParityBrowserArrowUpRight />Open in browser</ParityBrowserContextItem>
            </ParityBrowserContextContent>
          )}
        </ParityBrowserContextMenu>
      ) : <div className="self-center" data-testid="browser-link-trigger">{link}</div>}
    </main>
  );
}

function parityExtBrowserElement() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("case") ?? "";
  if (!id.startsWith("components.browser.desktop.")) return null;
  const state = params.get("extCase") ?? "page";
  return state.startsWith("web-link-")
    ? <ParityBrowserWebLink id={id} state={state} />
    : <ParityBrowserView id={id} state={state} artifactTitle={params.get("artifactTitle")} />;
}
