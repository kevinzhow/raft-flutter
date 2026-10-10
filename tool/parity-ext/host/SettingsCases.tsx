// raft-flutter parity EXTENSION cases: Settings (Workspace + Resources groups).
// Appended to the generated VisualTestingCases module like the other host
// files (identifiers prefixed `parityExt` / `ParityExt`); tool/parity-ext-web.mjs
// chains parityExtSettingsCaseElement() for `components.ext-settings.*`.
//
// Each case mounts what the Web desktop shell shows for a Settings route, minus
// the 64px LeftRail (1216 wide):
//   settings-navigation -> layout/Sidebar in Settings rail mode (240 wide)
//   settings-panel      -> settings/SettingsPanel (tab) or
//                          settings/ReleaseNotesPanel (/release-notes) in the
//                          976px main column
// Data: tool/parity-ext/fixtures/settings.json (routes answered by the
// generated provider spec; the Flutter provider reads the same file).
import ParityExtReleaseNotesPanel from "../src/components/settings/ReleaseNotesPanel";
import parityExtSettingsFixture from "virtual:parity-ext/settings";

type ParityExtSettingsProps = {
  caseId: string;
  tab: string;
  role: "owner" | "admin" | "member" | "guest";
  flags: Set<string>;
};

function parityExtSettingsProps(): ParityExtSettingsProps | null {
  const raw = parityExtRawCaseId();
  if (!raw.startsWith("components.ext-settings.")) return null;
  const params = new URLSearchParams(window.location.search);
  const tab = params.get("tab");
  if (!tab || !PARITY_EXT_THEME_SUFFIXES.some((s) => raw.endsWith(s))) return null;
  return {
    caseId: raw,
    tab,
    role: (params.get("role") ?? "owner") as ParityExtSettingsProps["role"],
    flags: new Set((params.get("flags") ?? "").split(",").filter(Boolean)),
  };
}

function parityExtSettingsRoutePath(tab: string): string {
  if (tab === "release-notes") return `/s/${fxServer.slug}/release-notes`;
  const slug = tab === "integrations" ? "applications" : tab === "mcp" ? "mcp-servers" : tab;
  return `/s/${fxServer.slug}/settings/${slug}`;
}

// Sidebar derives its Settings rail (and the active row) from the URL; put the
// route in place before the first render, like primeVisualRoutePath().
(function parityExtPrimeSettingsRoute() {
  if (typeof window === "undefined") return;
  const props = parityExtSettingsProps();
  if (!props) return;
  const path = parityExtSettingsRoutePath(props.tab);
  if (window.location.pathname !== path) {
    window.history.replaceState(null, "", `${path}${window.location.search}`);
  }
})();

function parityExtPrimeSettingsStores(props: ParityExtSettingsProps) {
  primeDirectVisualStores(props.caseId);
  const current = useServerStore.getState().current;
  useServerStore.setState({
    current: current ? { ...current, role: props.role } : current,
    servers: current ? [{ ...current, role: props.role }] : [],
    members: visualMembers.map((member) => (
      member.userId === visualUser.id ? { ...member, role: props.role } : member
    )),
  });
  // Resolved flags up front: the gated tabs (Labs / AI Providers / IM Bridges)
  // must not wait on (or be reset by) a feature-flag fetch.
  setServerFeatureFlagForTests(fxServer.id, "server_labs_ui_v0", props.flags.has("labs"));
  setServerFeatureFlagForTests(fxServer.id, "provider_connections_v0", props.flags.has("providers"));
  setServerFeatureFlagForTests(fxServer.id, "slack_bridge_v0", props.flags.has("bridge"));
}

function ParityExtSettingsCaseView({ props }: { props: ParityExtSettingsProps }) {
  useMemo(() => parityExtPrimeSettingsStores(props), [props]);
  void parityExtSettingsFixture;
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div
        data-visual-case={props.caseId}
        style={{ ...parityExtShellVars(), width: 1216, height: window.innerHeight, display: "flex", overflow: "hidden" }}
      >
        <div
          data-parity-region="settings-navigation"
          style={{ width: 240, height: "100%", display: "flex", flexDirection: "column", overflow: "hidden", flexShrink: 0 }}
        >
          <Routes>
            <Route path="/s/:serverSlug/*" element={<Sidebar />} />
          </Routes>
        </div>
        {/* MainLayout's content column paints `bg-layer-canvas-muted` behind
            the panel (its PanelHeader is transparent in Elegant). */}
        <div
          data-parity-region="settings-panel"
          className="bg-layer-canvas-muted theme-brutal:bg-white"
          style={{ width: 976, height: "100%", display: "flex", flexDirection: "column", overflow: "hidden" }}
        >
          {props.tab === "release-notes"
            ? <ParityExtReleaseNotesPanel />
            : <SettingsPanel tab={props.tab} />}
        </div>
      </div>
    </main>
  );
}

function parityExtSettingsCaseElement() {
  const props = parityExtSettingsProps();
  return props ? <ParityExtSettingsCaseView props={props} /> : null;
}
