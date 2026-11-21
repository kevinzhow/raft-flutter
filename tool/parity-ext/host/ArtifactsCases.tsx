import ParityExtArtifactsDashboard from "../src/apps/artifacts/ArtifactsDashboard";
import { installArtifactShareHost as parityExtInstallArtifactShareHost } from "../src/components/message/artifactShareHost";

function ParityExtArtifactsPage({ caseId, phone }: { caseId: string; phone: boolean }) {
  useMemo(() => {
    primeDirectVisualStores(caseId);
    setServerFeatureFlagForTests(fxServer.id, "workspace_artifacts_v0", true);
    parityExtInstallArtifactShareHost();
    window.localStorage.setItem("raft:artifacts:dashboard:v1", JSON.stringify({ view: "grid" }));
  }, [caseId]);
  return (
    <main className="thread-layout-container flex h-screen w-screen flex-col bg-layer-canvas" data-visual-case={caseId}
      style={phone ? undefined : { paddingLeft: 49, paddingTop: 44 }}>
      <ParityExtArtifactsDashboard serverId={fxServer.id} onMobileBack={phone ? () => history.back() : undefined} />
    </main>
  );
}

function parityExtArtifactsElement() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("case") ?? "";
  if (!id.startsWith("components.artifacts.")) return null;
  return <ParityExtArtifactsPage caseId={id} phone={params.get("platform") === "mobile"} />;
}
