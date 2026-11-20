import type { ComponentType as AppsHostComponent } from "react";

const appsHosts = import.meta.glob<AppsHostComponent>([
  "../src/components/settings/SecondFactorStepUpHost.tsx",
  "../src/pages/HumanLoginSetupPage.tsx",
], {
  eager: true,
  import: "default",
});
const AppsStepUpHost = appsHosts["../src/components/settings/SecondFactorStepUpHost.tsx"];
const AppsHumanLogin = appsHosts["../src/pages/HumanLoginSetupPage.tsx"];

function parityExtAppsCaseId() {
  const id = requestedCaseId();
  return id.startsWith("components.apps.") ? id : null;
}

if (typeof window !== "undefined" && parityExtAppsCaseId()) {
  const query = new URLSearchParams(window.location.search);
  const shell = query.get("appsShell");
  const slug = query.get("tab") === "im-bridges" ? "im-bridges" : "applications";
  if (shell === "login") {
    query.set("client_id", "fixture-login");
    query.set("return_to", "https://app.example.invalid/complete");
  }
  const path = shell === "login" ? "/login-with-raft/setup" : `/s/${fxServer.slug}/${shell || `settings/${slug}`}`;
  window.history.replaceState(null, "", `${path}?${query}`);
}

function ParityExtAppsSettings({ caseId }: { caseId: string }) {
  const query = new URLSearchParams(window.location.search);
  const promptText = query.get("flags") === "prompt-text";
  const bridge = query.get("flags") === "bridge";
  const shell = query.get("appsShell");
  const role = query.get("role");
  const tab = bridge ? "im-bridges" : "integrations";
  useMemo(() => {
    if (shell) primeNavigationVisualStores();
    else primeSettingsVisualStores({ id: caseId, tab });
    if (shell === "login") {
      useServerStore.setState((state) => ({ servers: state.servers.slice(0, 1) }));
    }
    if (role === "guest" || role === "member") {
      useServerStore.setState((state) => ({
        current: state.current ? { ...state.current, role } : null,
        servers: state.servers.map((server) =>
          server.id === fxServer.id ? { ...server, role } : server
        ),
      }));
    }
    setServerFeatureFlagForTests(fxServer.id, "app_prompt_text_consent", promptText);
    setServerFeatureFlagForTests(fxServer.id, "slack_bridge_v0", bridge);
  }, [caseId, promptText, bridge, tab, shell, role]);
  const mobile = query.get("platform") === "mobile";
  return (
    <main className="min-h-screen bg-layer-canvas font-display text-foreground">
      <div data-visual-case={caseId} className={`flex overflow-hidden ${shell ? "flex-col" : ""}`}
        style={{ width: mobile || shell ? window.innerWidth : 1216, height: window.innerHeight }}>
        {shell === "login" && AppsHumanLogin ? (
          <AppsHumanLogin />
        ) : shell ? (
          <Routes>
            <Route path="/s/:serverSlug/*" element={<MainLayout />} />
          </Routes>
        ) : (
          <>
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
          </>
        )}
      </div>
      {AppsStepUpHost && <AppsStepUpHost />}
    </main>
  );
}

function parityExtAppsElement() {
  const caseId = parityExtAppsCaseId();
  return caseId ? <ParityExtAppsSettings caseId={caseId} /> : null;
}
