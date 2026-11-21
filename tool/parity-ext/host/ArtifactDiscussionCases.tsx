import ParityExtDiscussionViewer from "../src/apps/artifacts/ArtifactViewer";
import type { ArtifactId as ParityExtDiscussionId } from "@botiverse/raft-shared";
import parityExtDiscussionFixture from "virtual:parity-ext/artifact-discussion";

function ParityExtDiscussion({ caseId, phone }: { caseId: string; phone: boolean }) {
  useMemo(() => {
    primeDirectVisualStores(caseId);
    setServerFeatureFlagForTests(fxServer.id, "workspace_artifacts_v0", true);
  }, [caseId]);
  const id = parityExtDiscussionFixture.artifactId as ParityExtDiscussionId;
  const target = useMemo(() => ({ id, version: null }), [id]);
  return (
    <main className="thread-layout-container flex h-screen w-screen flex-col bg-layer-canvas" data-visual-case={caseId}>
      <ParityExtDiscussionViewer
        target={target}
        source="message_card"
        expanded={!phone}
        covering={phone}
        ownBack={phone}
        onClose={() => {}}
      />
    </main>
  );
}

function parityExtArtifactDiscussionElement() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("case") ?? "";
  return id.startsWith("components.artifact-discussion.")
    ? <ParityExtDiscussion caseId={id} phone={params.get("platform") === "mobile"} />
    : null;
}
