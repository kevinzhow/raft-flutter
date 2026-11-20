function parityExtAppsCaseId() {
  const id = requestedCaseId();
  return id.startsWith("components.apps.") ? id : null;
}

if (typeof window !== "undefined" && parityExtAppsCaseId()) {
  const slug = new URLSearchParams(window.location.search).get("tab") === "im-bridges"
    ? "im-bridges"
    : "applications";
  window.history.replaceState(null, "", `/s/${fxServer.slug}/settings/${slug}${window.location.search}`);
}

function ParityExtAppsSettings({ caseId }: { caseId: string }) {
  const query = new URLSearchParams(window.location.search);
  const promptText = query.get("flags") === "prompt-text";
  const bridge = query.get("flags") === "bridge";
  const tab = bridge ? "im-bridges" : "integrations";
  useMemo(() => {
    primeSettingsVisualStores({ id: caseId, tab });
    setServerFeatureFlagForTests(fxServer.id, "app_prompt_text_consent", promptText);
    setServerFeatureFlagForTests(fxServer.id, "slack_bridge_v0", bridge);
  }, [caseId, promptText, bridge, tab]);
  const mobile = query.get("platform") === "mobile";
  return (
    <main className="min-h-screen bg-layer-canvas font-display text-foreground">
      <div data-visual-case={caseId} className="flex overflow-hidden"
        style={{ width: mobile ? window.innerWidth : 1216, height: window.innerHeight }}>
        {!mobile && (
          <aside className="h-full w-[240px] shrink-0">
            <Routes>
              <Route path="/s/:serverSlug/*" element={<Sidebar />} />
            </Routes>
          </aside>
        )}
        <div className="flex min-w-0 flex-1 flex-col overflow-hidden">
          <SettingsPanel tab={tab} />
        </div>
      </div>
    </main>
  );
}

function parityExtAppsElement() {
  const caseId = parityExtAppsCaseId();
  return caseId ? <ParityExtAppsSettings caseId={caseId} /> : null;
}
