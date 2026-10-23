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
import ParityExtRaftBenchPage from "../src/raftbench/RaftBenchPage";
import parityExtSettingsFixture from "virtual:parity-ext/settings";

type ParityExtSettingsProps = {
  caseId: string;
  tab: string;
  role: "owner" | "admin" | "member" | "guest";
  flags: Set<string>;
  routeSet: string;
  mobile: boolean;
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
    routeSet: params.get("routeSet") ?? "",
    mobile: params.get("platform") === "mobile",
  };
}

function parityExtSettingsRoutePath(tab: string): string {
  if (tab === "release-notes") return `/s/${fxServer.slug}/release-notes`;
  if (tab === "raftbench") return `/s/${fxServer.slug}/raftbench`;
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
  // Administration states that live on the primed stores, not on a route:
  // MemberPermissionsSection reads `current.hideHumansFromMembers`,
  // SystemChannelsSection reads whether #all is in the channel list.
  const serverPatch = { role: props.role, ...(props.routeSet === "admin-hide-humans" ? { hideHumansFromMembers: true } : {}) };
  useServerStore.setState({
    current: current ? { ...current, ...serverPatch } : current,
    servers: current ? [{ ...current, ...serverPatch }] : [],
    members: visualMembers.map((member) => (
      member.userId === visualUser.id ? { ...member, role: props.role } : member
    )),
  });
  // Resolved flags up front: the gated tabs (Labs / AI Providers / IM Bridges)
  // must not wait on (or be reset by) a feature-flag fetch.
  setServerFeatureFlagForTests(fxServer.id, "server_labs_ui_v0", props.flags.has("labs"));
  setServerFeatureFlagForTests(fxServer.id, "provider_connections_v0", props.flags.has("providers"));
  setServerFeatureFlagForTests(fxServer.id, "slack_bridge_v0", props.flags.has("bridge"));
  setServerFeatureFlagForTests(fxServer.id, "product_analytics_settings_v0", props.flags.has("analytics"));
  setServerFeatureFlagForTests(fxServer.id, "raftbench_overview_v0", props.flags.has("raftbench"));
  if (props.routeSet === "admin-all-visible") {
    const channels = useChannelStore.getState().channels;
    if (!channels.some((channel) => channel.name === "all")) {
      useChannelStore.setState({ channels: [{ ...channels[0], id: "channel-all", name: "all" }, ...channels] });
    }
  }
}

function ParityExtSettingsCaseView({ props }: { props: ParityExtSettingsProps }) {
  useMemo(() => {
    parityExtPrimeSettingsStores(props);
    // Per-case store states of the WP6 surfaces (host/Wp6Cases.tsx).
    parityExtWp6AfterSettingsPrime();
  }, [props]);
  void parityExtSettingsFixture;
  if (props.mobile) {
    // Mobile settings sub-page: SettingsPanel fills the 390px viewport (its
    // PanelHeader shows the mobile back below `md`; the tab bar is covered).
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div
          data-visual-case={props.caseId}
          data-parity-region="settings-panel"
          className="bg-layer-canvas-muted theme-brutal:bg-white"
          style={{ ...parityExtShellVars(), width: window.innerWidth, height: window.innerHeight, display: "flex", flexDirection: "column", overflow: "hidden" }}
        >
          {props.tab === "raftbench" ? <ParityExtRaftBenchPage /> : <SettingsPanel tab={props.tab} />}
        </div>
      </main>
    );
  }
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
            : props.tab === "raftbench"
              ? <ParityExtRaftBenchPage />
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
