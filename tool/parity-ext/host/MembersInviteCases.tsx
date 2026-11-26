// raft-flutter parity EXTENSION cases: the members page's external invites and
// the details preferences block (not official).
//
// Appended by tool/parity-ext-web.mjs to a generated copy of the pinned
// VisualTestingCases.tsx, so it shares that module's imports and helpers;
// identifiers introduced here are prefixed `parityExtMi` / `ParityExtMi`. Ids:
//   components.members-invite.<phone|fold>.<key>.<theme>
//
// The cases are copies of the channel-settings ones (host/ChannelSettingsCases.tsx),
// so the drawer, the stores and the interactions are the same; two things differ:
//   * external_channels_v1 is on, which is what makes the Invited group and the
//     "Invite people outside" entry exist (useExternalInviteAccess);
//   * the pane is sized from the case viewport instead of 390 / 1280, because
//     these cases are Kevin's screen classes (412x915 phone, 1124x1240 unfolded
//     foldable), not the 1280 desktop ChannelSettingsCases hardcodes.
// Data: tool/parity-ext/fixtures/members-invite.json (the Flutter provider reads
// the same file); its `routes` + the case's `routeSet` answer the API reads.
import { EXTERNAL_CHANNELS_FEATURE_FLAG_KEY as PARITY_EXT_MI_FLAG } from "@botiverse/raft-shared";
import type { CSSProperties as ParityExtMiCSSProperties } from "react";

type ParityExtMiProps = {
  platform: "desktop" | "mobile";
  channel: string;
  role: "owner" | "admin" | "member" | "guest";
  guestFlag: boolean;
  pinned: boolean;
};

function parityExtMiProps(): ParityExtMiProps | null {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.members-invite.") || params.get("extKind") !== "members-invite") return null;
  const role = params.get("role");
  return {
    platform: params.get("platform") === "mobile" ? "mobile" : "desktop",
    channel: params.get("channel") ?? "",
    role: role === "admin" || role === "member" || role === "guest" ? role : "owner",
    guestFlag: params.get("guestFlag") === "true",
    pinned: params.get("pinned") === "true",
  };
}

function ParityExtMiView({ props }: { props: ParityExtMiProps }) {
  const caseId = new URLSearchParams(window.location.search).get("case") ?? "";
  // Both calls merge into the same snapshot, so the drawer's own
  // `setServerFeatureFlagForTests(..., SERVER_GUEST, ...)` keeps this one on.
  useMemo(() => {
    parityExtCsPrimeStores(props as never);
    setServerFeatureFlagForTests(fxServer.id, PARITY_EXT_MI_FLAG, true);
  }, [props]);
  const theme = new URLSearchParams(window.location.search).get("parityTheme") ?? "brutal-light";
  const brutal = theme === "brutal-light";
  // AppShell root sets the header height the PanelHeader recipe reads.
  const shellVars = { ["--shell-header-height" as string]: "56px" } as ParityExtMiCSSProperties;
  // The conversation pane of this window: the whole width on a phone, the
  // window minus the rail and the 240 sidebar once the shell has both.
  const width = props.platform === "mobile"
    ? window.innerWidth
    : window.innerWidth - (brutal ? 64 : 56) - 240;
  const height = window.innerHeight;
  const channel = useChannelStore((s) => [...s.channels, ...s.dmChannels].find((c) => c.id === props.channel) ?? null);
  return (
    <main className="min-h-screen bg-white p-0 font-display text-black">
      <div data-visual-case={caseId} style={{ ...shellVars, width, height, overflow: "hidden", position: "relative" }}>
        <div className="flex flex-col" style={{ width, height }}>
          <ChatPanel channel={channel} />
        </div>
      </div>
    </main>
  );
}

function parityExtMembersInviteElement() {
  const props = parityExtMiProps();
  return props ? <ParityExtMiView props={props} /> : null;
}
