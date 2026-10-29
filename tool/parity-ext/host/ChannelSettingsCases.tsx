// raft-flutter parity EXTENSION cases: channel / DM settings drawer (not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx (shares its imports and fixture helpers; identifiers
// here are prefixed `parityExtCs`). Ids: components.channelsettings.<platform>.<state>.<theme>.
//
// Each case mounts the REAL message/ChatPanel in the main column (desktop:
// 1280 - rail - 240 sidebar; mobile: the 390 page). The case's capture
// interactions click the header gear (data-testid="channel-overflow-trigger"),
// which opens ChannelOverflowMenu's OverflowSheet; the capture is the sheet
// (or the ConfirmDialog / unsaved prompt a further click opens).
// Data: tool/parity-ext/fixtures/channelsettings.json (the Flutter provider
// reads the same file). The viewer's server role and the server_guest flag come
// from the case props; everything else is the fixture channel row
// (channelCapabilities, joined, archivedAt, type) and its routes.
import parityExtCsFixture from "virtual:parity-ext/channelsettings";
import type { CSSProperties as ParityExtCsCSSProperties } from "react";

type ParityExtCsProps = {
  extCase: string;
  platform: "desktop" | "mobile";
  channel: string;
  role: "owner" | "admin" | "member" | "guest";
  guestFlag: boolean;
  pinned: boolean;
};

function parityExtCsProps(): ParityExtCsProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.channelsettings.") || params.get("extKind") !== "channelsettings") return null;
  const role = params.get("role");
  return {
    extCase: params.get("extCase") ?? "",
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    channel: params.get("channel") ?? "",
    role: role === "admin" || role === "member" || role === "guest" ? role : "owner",
    guestFlag: params.get("guestFlag") === "true",
    pinned: params.get("pinned") === "true",
  };
}

function parityExtCsTheme(): string {
  return new URLSearchParams(window.location.search).get("parityTheme") ?? "brutal-light";
}

function parityExtCsPrimeStores(props: ParityExtCsProps) {
  primeDirectVisualStores(new URLSearchParams(window.location.search).get("case") ?? "");
  useChannelStore.setState({
    channels: parityExtCsFixture.channels as never,
    dmChannels: parityExtCsFixture.dms as never,
    loading: false,
  });
  useMessageStore.setState({ currentChannelId: props.channel, currentUserId: fxOwner.id });
  // The viewer's server role drives useServerPermissions (capabilities.*).
  useServerStore.setState((state) => ({
    current: state.current ? { ...state.current, role: props.role } : state.current,
    members: visualMembers.map((member) => (member.userId === visualUser.id ? { ...member, role: props.role } : member)),
  }));
  // Pin switch state (ChannelPreferencesSection reads sidebarOrder.pinned).
  if (props.pinned) {
    useServerStore.setState((state) => ({
      sidebarOrder: { ...state.sidebarOrder, pinned: [{ kind: "channel", id: props.channel }] },
    }));
  }
  // Resolve every registered server flag (all off) so no evaluation request is
  // in flight when the drawer opens; only server_guest follows the case.
  setServerFeatureFlagForTests(fxServer.id, SERVER_GUEST_FEATURE_FLAG_KEY, props.guestFlag);
}

function ParityExtCsView({ props }: { props: ParityExtCsProps }) {
  const caseId = new URLSearchParams(window.location.search).get("case") ?? "";
  useMemo(() => parityExtCsPrimeStores(props), [props]);
  const theme = parityExtCsTheme();
  const brutal = theme === "brutal-light";
  // AppShell root sets the header height the PanelHeader recipe reads.
  const shellVars = { ["--shell-header-height" as string]: "56px" } as ParityExtCsCSSProperties;
  const mobile = props.platform === "mobile";
  const width = mobile ? 390 : 1280 - (brutal ? 64 : 56) - 240;
  const channel = useChannelStore((s) => [...s.channels, ...s.dmChannels].find((c) => c.id === props.channel) ?? null);
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={caseId} style={{ ...shellVars, width, height: window.innerHeight, overflow: "hidden", position: "relative" }}>
        <div className="flex flex-col" style={{ width, height: window.innerHeight }}>
          <ChatPanel channel={channel} />
        </div>
      </div>
    </main>
  );
}

function parityExtChannelSettingsElement() {
  const props = parityExtCsProps();
  return props ? <ParityExtCsView props={props} /> : null;
}
