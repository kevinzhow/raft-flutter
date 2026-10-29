// raft-flutter parity EXTENSION cases: the media viewer (lightbox) for a video attachment.
// Appended to the generated VisualTestingCases.tsx like the other host files.
//
// Mounts the REAL VideoAttachmentPreviewModal (attachmentPreviewSurfaces.tsx: AttachmentPreviewShell +
// VideoPreviewBody) with a data: WebM (tool/parity-ext/fixtures/video-viewer.json) the headless Chromium can decode.
// Ids: components.attachment.viewer.<state>.<theme>; states: video-paused (first frame, native controls).
import { VideoAttachmentPreviewModal as ParityExtVvModal } from "../src/components/message/attachmentPreviewSurfaces";
import parityExtVvFixture from "virtual:parity-ext/video-viewer";

function parityExtVvProps() {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.attachment.viewer.") || params.get("extKind") !== "video-viewer") return null;
  return { raw };
}

function ParityExtVvView({ p }: { p: NonNullable<ReturnType<typeof parityExtVvProps>> }) {
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      {/* The transform makes this box the containing block of the modal's fixed layers. */}
      <div data-visual-case={p.raw} style={{ width: 1280, height: 800, overflow: "hidden", position: "relative", transform: "translateZ(0)" }}>
        <ParityExtVvModal filename={parityExtVvFixture.filename} url={parityExtVvFixture.url} onClose={() => {}} onDownload={() => {}} />
      </div>
    </main>
  );
}

function parityExtVvElement() {
  const p = parityExtVvProps();
  return p ? <ParityExtVvView p={p} /> : null;
}
