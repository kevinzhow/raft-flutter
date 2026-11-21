import type { ComponentType as AppsHostComponent } from "react";
import { useLayoutEffect as useAppsLayoutEffect, useRef as useAppsRef } from "react";

const appsHosts = import.meta.glob<AppsHostComponent>([
  "../src/components/settings/SecondFactorStepUpHost.tsx",
  "../src/pages/HumanLoginSetupPage.tsx",
], {
  eager: true,
  import: "default",
});
const AppsStepUpHost = appsHosts["../src/components/settings/SecondFactorStepUpHost.tsx"];
const AppsHumanLogin = appsHosts["../src/pages/HumanLoginSetupPage.tsx"];

function AppsLoginContentTarget() {
  const marker = useAppsRef<HTMLDivElement>(null);
  useAppsLayoutEffect(() => {
    const target = marker.current;
    const scroller = document.querySelector('[data-testid="human-login-setup-scroller"]');
    if (!target || !scroller) return;
    const update = () => {
      const card = scroller.querySelector<HTMLElement>("main > section:first-child");
      if (!card || card.matches('[data-testid="login-lookup-loading"]')) {
        target.hidden = true;
        return;
      }
      const box = card.getBoundingClientRect();
      const style = getComputedStyle(card);
      const left = box.left + parseFloat(style.borderLeftWidth) + parseFloat(style.paddingLeft);
      const right = box.right - parseFloat(style.borderRightWidth) - parseFloat(style.paddingRight);
      const top = box.top + parseFloat(style.borderTopWidth) + parseFloat(style.paddingTop);
      const footer = card.querySelector(":scope > .mt-6 > button")?.parentElement;
      const bottom = footer
        ? footer.getBoundingClientRect().top - parseFloat(getComputedStyle(footer).marginTop)
        : box.bottom - parseFloat(style.borderBottomWidth) - parseFloat(style.paddingBottom);
      target.hidden = false;
      Object.assign(target.style, {
        left: `${left}px`,
        top: `${top}px`,
        width: `${right - left}px`,
        height: `${bottom - top}px`,
      });
    };
    const mutations = new MutationObserver(update);
    mutations.observe(scroller, { childList: true, attributes: true, subtree: true });
    scroller.addEventListener("scroll", update, true);
    update();
    return () => {
      mutations.disconnect();
      scroller.removeEventListener("scroll", update, true);
    };
  }, []);
  return (
    <div ref={marker} data-testid="apps-login-content-capture" aria-hidden="true"
      style={{ position: "fixed", pointerEvents: "none" }} />
  );
}

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
    if (shell) {
      primeNavigationVisualStores();
      useMachineStore.setState({ machines: [], selectedMachineId: null, machineWorkspaces: {} });
    } else {
      primeSettingsVisualStores({ id: caseId, tab });
    }
    if (shell === "login") {
      useServerStore.setState((state) => ({ servers: state.servers.slice(0, 1) }));
    }
    if (query.get("routeSet") === "external-bot") {
      void useServerStore.getState().loadSidebarOrder();
      useChannelStore.setState({ dmChannels: [], dmsLoading: false });
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
        style={{ width: window.innerWidth, height: window.innerHeight }}>
        {shell === "login" && AppsHumanLogin ? (
          <>
            <AppsHumanLogin />
            <AppsLoginContentTarget />
          </>
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
