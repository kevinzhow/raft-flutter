// raft-flutter parity EXTENSION cases: attachment previews (not official).
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtAtt`). Ids:
// components.thread-ext.attachment.<surface>[.<platform>].<theme>.
//
// Each case mounts the REAL app-level host with seeded stores, exactly what
// MainLayout mounts beside the message list:
//   image     -> components/ImageLightbox (imageLightboxStore)
//   document  -> message/DocumentPreviewHost (documentPreviewStore)
//   html      -> message/MediaPreviewHost (mediaPreviewStore, kind html)
//   panel     -> message/AttachmentCommentsPanel in the 320px aside column
// The lightbox portals to document.body; the capture selector (set by
// tool/parity-ext/build-thread-attachments.py) picks the portal root or its
// header strip. Data: tool/parity-ext/fixtures/threadattachments.json (the
// Flutter provider reads the same file); the case's `routeSet` selects the
// route overrides tool/parity-ext/run installs.
import ParityExtAttImageLightbox from "../src/components/ImageLightbox";
import ParityExtAttDocumentPreviewHost from "../src/components/message/DocumentPreviewHost";
import ParityExtAttMediaPreviewHost from "../src/components/message/MediaPreviewHost";
import { useImageLightboxStore as parityExtAttImageStore } from "../src/store/imageLightboxStore";
import { useDocumentPreviewStore as parityExtAttDocumentStore } from "../src/store/documentPreviewStore";
import { useMediaPreviewStore as parityExtAttMediaStore } from "../src/store/mediaPreviewStore";
import parityExtAttFixture from "virtual:parity-ext/threadattachments";

type ParityExtAttProps = {
  raw: string;
  host: "image" | "document" | "html" | "panel";
  platform: "desktop" | "mobile";
  images: number;
  index: number;
  doc: string;
  hideArrows: boolean;
  pendingSpinner: boolean;
};

const PARITY_EXT_ATT_HTML_URL = "data:text/html;charset=utf-8,%3C!doctype%20html%3E%3Cbody%3E%3C!--";

function parityExtAttProps(): ParityExtAttProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.thread-ext.attachment.") || params.get("extKind") !== "threadattachment") return null;
  return {
    raw,
    host: (params.get("host") ?? "image") as ParityExtAttProps["host"],
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    images: Number(params.get("images") ?? 1),
    index: Number(params.get("index") ?? 0),
    doc: params.get("doc") ?? "text",
    hideArrows: params.get("hideArrows") === "1",
    pendingSpinner: params.get("pendingSpinner") === "1",
  };
}

function parityExtAttPrime(p: ParityExtAttProps) {
  primeDirectVisualStores(p.raw);
  const fx = parityExtAttFixture as any;
  const commentContext = { parentMessage: fx.parent };
  if (p.host === "image") {
    if (p.pendingSpinner) {
      // Use the real opener; never write loading/error or a prepared image URL.
      parityExtAttImageStore.getState().open([{ ...fx.pendingSpinner.image }], 0, {});
      return;
    }
    const images = (fx.images as any[]).slice(0, p.images).map((image) => ({
      id: image.id,
      filename: image.filename,
      mimeType: image.mimeType,
      sizeBytes: image.sizeBytes,
      width: image.width,
      height: image.height,
      thumbnailUrl: image.thumbnailUrl,
      commentCount: image.commentCount,
    }));
    parityExtAttImageStore.setState({
      isOpen: true,
      images,
      currentIndex: p.index,
      imageUrlCache: {},
      // MessageItem opens the lightbox without comment contexts, so the
      // message flow shows no comments toggle on images.
      commentContexts: {},
    });
  } else if (p.host === "document") {
    const doc = fx.documents[p.doc];
    parityExtAttDocumentStore.setState({
      entry: {
        attachment: doc.attachment,
        preview: doc.preview,
        truncated: doc.truncated,
        url: null,
        commentContext,
      },
    });
  } else if (p.host === "html") {
    parityExtAttMediaStore.setState({
      entry: { kind: "html", attachment: fx.html, url: PARITY_EXT_ATT_HTML_URL, commentContext },
    });
  }
}

function ParityExtAttView({ p }: { p: ParityExtAttProps }) {
  useMemo(() => parityExtAttPrime(p), [p]);
  if (p.host === "panel") {
    const mobile = p.platform === "mobile";
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div
          data-visual-case={p.raw}
          style={{ width: mobile ? 390 : 320, height: mobile ? 360 : 742, overflow: "hidden" }}
        >
          <AttachmentCommentsPanel
            attachmentId={(parityExtAttFixture as any).documents[p.doc].attachment.id}
            filename={(parityExtAttFixture as any).documents[p.doc].attachment.filename}
            parentMessage={(parityExtAttFixture as any).parent}
          />
        </div>
      </main>
    );
  }
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      {p.host === "image" && p.hideArrows ? (
        // Flutter's gallery has no previous/next arrows (owner decision 2026-10-13): hide Web's two
        // absolute left-8 / right-8 buttons so the case compares counter, thumbnail strip and stage.
        <style>{".absolute.left-8.z-10, .absolute.right-8.z-10 { display: none !important; }"}</style>
      ) : null}
      {p.host === "image" ? <ParityExtAttImageLightbox /> : null}
      {p.host === "document" ? <ParityExtAttDocumentPreviewHost /> : null}
      {p.host === "html" ? <ParityExtAttMediaPreviewHost /> : null}
    </main>
  );
}

function parityExtThreadAttachmentElement() {
  const p = parityExtAttProps();
  return p ? <ParityExtAttView p={p} /> : null;
}
