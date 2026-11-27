// An Artifact opened from an Activity row or a Search hit (task #380): the real MainLayout on
// /activity or /search?q=plan; the case clicks the row, so the slot opens the way a person opens it
// (beside the list from 768px, a page over the list on a phone). Data: fixtures/list-artifact.json.
import { installArtifactShareHost as parityExtListArtifactShareHost } from "../src/components/message/artifactShareHost";

const PARITY_EXT_LIST_ARTIFACT_PREFIX = "components.pages.list-artifact.";

function parityExtListArtifactProps() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("case") ?? "";
  if (!id.startsWith(PARITY_EXT_LIST_ARTIFACT_PREFIX)) return null;
  return { id, params, search: params.get("source") === "search" };
}

(function parityExtListArtifactPrimeRoute() {
  if (typeof window === "undefined") return;
  const props = parityExtListArtifactProps();
  if (!props) return;
  if (props.search) props.params.set("q", "plan");
  const route = props.search ? "search" : "activity";
  window.history.replaceState(null, "", `/s/${fxServer.slug}/${route}?${props.params}`);
})();

function ParityExtListArtifactView({ id }: { id: string }) {
  useMemo(() => {
    primeDirectVisualStores(id);
    setServerFeatureFlagForTests(fxServer.id, "workspace_artifacts_v0", true);
    parityExtListArtifactShareHost();
  }, [id]);
  return (
    <div data-visual-case={id} className="flex h-dvh w-full min-h-0 flex-col overflow-hidden bg-layer-canvas">
      <Routes>
        <Route path="/s/:serverSlug/*" element={<MainLayout />} />
      </Routes>
    </div>
  );
}

function parityExtListArtifactElement() {
  const props = parityExtListArtifactProps();
  return props ? <ParityExtListArtifactView id={props.id} /> : null;
}
