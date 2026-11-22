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
import { useState as parityExtAnnUseState } from "react";

(function parityExtAnnRoute() {
  if (typeof window === "undefined") return;
  const query = new URLSearchParams(window.location.search);
  if (!query.get("case")?.startsWith("components.announcements.") || query.get("sidebar") !== "1") return;
  window.history.replaceState(null, "", `/s/${fxServer.slug}${window.location.search}`);
})();

function parityExtAnnProps() {
  const raw = new URLSearchParams(window.location.search).get("case") ?? "";
  if (!raw.startsWith("components.announcements.")) return null;
  const params = new URLSearchParams(window.location.search);
  const key = params.get("ann") ?? "";
  const announcement = (parityExtAnnFixture.announcements as Record<string, ParityExtAnnouncement>)[key];
  if (!announcement) return null;
  return { raw, announcement, sidebar: params.get("sidebar") === "1" };
}

function ParityExtAnnView({ p }: { p: NonNullable<ReturnType<typeof parityExtAnnProps>> }) {
  const [slot, setSlot] = parityExtAnnUseState<HTMLDivElement | null>(null);
  useMemo(() => {
    primeDirectVisualStores(p.raw);
    parityExtAnnStore.setState({
      pending: p.sidebar
        ? [{ ...p.announcement, displayMode: "sidebar" }, { ...p.announcement, id: "next", displayMode: "sidebar" }]
        : [p.announcement],
      stackTotal: p.sidebar ? 2 : 1,
      loaded: true,
      markedReadIds: [],
      writeFailedIds: [],
    } as Parameters<typeof parityExtAnnStore.setState>[0]);
  }, [p]);
  const options = p.sidebar ? { preferSidebar: true, sidebarContainer: slot } : {};
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={p.raw} style={{ width: "100vw", height: "100vh" }}>
        {p.sidebar && <div ref={setSlot} style={{ width: 268 }} />}
      </div>
      <ParityExtAnnouncementModal {...options} />
    </main>
  );
}

function parityExtAnnouncementElement() {
  const p = parityExtAnnProps();
  return p ? <ParityExtAnnView p={p} /> : null;
}
