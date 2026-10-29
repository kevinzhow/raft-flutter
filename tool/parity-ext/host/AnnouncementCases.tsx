// raft-flutter parity EXTENSION cases: the account-level announcement modal.
// Appended to the generated VisualTestingCases.tsx like host/ComputerCases.tsx
// (shares its imports and private helpers); identifiers are prefixed
// `parityExtAnn`.
//
// Mounts the REAL product component `AnnouncementModal` (MainLayout mounts it
// over the whole app; v1.21.12 renders raft-ui's AnnouncementDialog) with the
// announcement store primed the way a `GET /announcements/active` response
// leaves it (`pending[0]` presented). The page behind it is the host's plain
// white `main`; the dialog portals to document.body. The host's own router
// serves the CTA's `useNavigate`. Data: tool/parity-ext/fixtures/announcements.json, which the
// Flutter provider serves from its fixture client.
import ParityExtAnnouncementModal from "../src/components/AnnouncementModal";
import { useAnnouncementStore as parityExtAnnStore } from "../src/store/announcementStore";
import parityExtAnnFixture from "virtual:parity-ext/announcements";
import type { Announcement as ParityExtAnnouncement } from "@botiverse/raft-shared";

function parityExtAnnProps() {
  const raw = new URLSearchParams(window.location.search).get("case") ?? "";
  if (!raw.startsWith("components.announcements.")) return null;
  const params = new URLSearchParams(window.location.search);
  const key = params.get("ann") ?? "";
  const announcement = (parityExtAnnFixture.announcements as Record<string, ParityExtAnnouncement>)[key];
  if (!announcement) return null;
  return { raw, announcement };
}

function ParityExtAnnView({ p }: { p: NonNullable<ReturnType<typeof parityExtAnnProps>> }) {
  useMemo(() => {
    primeDirectVisualStores(p.raw);
    parityExtAnnStore.setState({
      pending: [p.announcement],
      loaded: true,
      markedReadIds: [],
      writeFailedIds: [],
    });
  }, [p]);
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={p.raw} style={{ width: "100vw", height: "100vh" }} />
      <ParityExtAnnouncementModal />
    </main>
  );
}

function parityExtAnnouncementElement() {
  const p = parityExtAnnProps();
  return p ? <ParityExtAnnView p={p} /> : null;
}
