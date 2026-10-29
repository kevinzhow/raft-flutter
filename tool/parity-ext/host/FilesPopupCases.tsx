// Actual ChannelFilesPanel first-row overflow; no replacement component board.
// Appended to the pinned official host, sharing its genuine fixture helpers.
function ParityExtFilesPopupView({ raw }: { raw: string }) {
  useMemo(() => primeDirectVisualStores(raw), [raw]);
  return (
    <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
      <div data-visual-case={raw} style={{ width: 390, height: 360, overflow: "hidden" }}>
        <ChannelFilesPanel channel={THREAD_FILES_CHANNEL} />
      </div>
    </main>
  );
}

function parityExtFilesPopupElement() {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.files-popup.")) return null;
  return <ParityExtFilesPopupView raw={raw} />;
}
