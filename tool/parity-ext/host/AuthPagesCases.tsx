// raft-flutter parity EXTENSION cases: MISSING auth / onboarding / entry pages (page inventory area 1
// rows 1.01, 1.05, 1.06, 1.10, 1.12, 1.14, 1.16-1.18, 1.33 ... and settings rows of area 9).
// Appended by tool/parity-ext-web.mjs to the generated VisualTestingCases.tsx like the other host files
// (shares its imports and private helpers); identifiers are prefixed `parityExtAp`.
//
// Every case mounts the REAL Web page / component. Stores are primed the way App.tsx leaves them for that
// screen; API answers come from tool/parity-ext/fixtures/auth-pages.json (`routes` + `routeSets`, served by
// the provider spec's page.route, pinned with props.extFixture), the same data the Flutter fixture client
// reads. Ids: components.auth-pages.<platform>.<surface>.<theme>.
import ParityExtApRegisterPage from "../src/components/auth/RegisterPage";
import ParityExtApInvitePage from "../src/components/auth/InviteAcceptPage";
import ParityExtApRootError from "../src/components/errors/RootErrorFallback";
import ParityExtApCommunityAgreement from "../src/components/server/CommunityAgreementDialog";
import ParityExtApIdentityPage from "../src/components/auth/AccountIdentitySetupPage";
import ParityExtApServerSelector from "../src/components/auth/ServerSelector";
import ParityExtApSetupGate from "../src/components/onboarding/ServerSetupProjectionGate";
import ParityExtApReleaseNotes from "../src/components/settings/ReleaseNotesPanel";
import { useLayoutEffect as parityExtApUseLayoutEffect } from "react";
import { useChannelStore as parityExtApChannelStore } from "../src/store/channelStore";
import { AuthBootstrapStatus as ParityExtApBootstrap, ServerAccessDeniedPage as ParityExtApDenied, ServerSelectionPage as ParityExtApServerSelection } from "../src/App";
import { useAuthStore as parityExtApAuthStore } from "../src/store/authStore";
import { useServerStore as parityExtApServerStore } from "../src/store/serverStore";
import parityExtApFixture from "virtual:parity-ext/auth-pages";

function parityExtApProps() {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.auth-pages.")) return null;
  return {
    raw,
    view: params.get("view") ?? "register",
    kind: params.get("kind") ?? "",
    width: Number(params.get("w") ?? 390),
    height: Number(params.get("h") ?? 844),
    servers: params.get("servers") ?? "none",
    user: params.get("user") ?? "none",
    tab: params.get("tab") ?? "account",
    role: (params.get("role") ?? "owner") as "owner" | "admin" | "member" | "guest",
    flags: params.get("flags") ?? "",
    patch: params.get("patch") ?? "",
    routeSet: params.get("routeSet") ?? "",
    mobile: params.get("platform") === "mobile",
  };
}

type ParityExtApP = NonNullable<ReturnType<typeof parityExtApProps>>;

// Settings tab routes (Sidebar derives its rail and the active row from the URL; same priming as
// SettingsCases.tsx parityExtPrimeSettingsRoute, here keyed by the auth-pages ids).
(function parityExtApPrimeSettingsRoute() {
  if (typeof window === "undefined") return;
  const p = parityExtApProps();
  if (!p || p.view !== "settings") return;
  const path = parityExtSettingsRoutePath(p.tab);
  if (window.location.pathname !== path) {
    window.history.replaceState(null, "", `${path}${window.location.search}`);
  }
})();

// Settings pages of the missing-page rows: the shared ext-settings view over the primed stores, plus the
// per-case store patches the fixture names (props.patch).
function ParityExtApSettings({ p }: { p: ParityExtApP }) {
  const fx = parityExtApFixture as Record<string, any>;
  parityExtApUseLayoutEffect(() => {
    const serverPatch = fx.serverPatches?.[p.patch];
    if (serverPatch) {
      const current = parityExtApServerStore.getState().current;
      parityExtApServerStore.setState({
        current: current ? { ...current, ...serverPatch } : current,
        servers: current ? [{ ...current, ...serverPatch }] : [],
      } as never);
    }
    if (p.patch === "archived") {
      const channels = parityExtApChannelStore.getState().channels;
      // Idempotent: the layout effect runs twice under StrictMode, and a second append would
      // list every archived channel twice (duplicate React keys).
      const known = new Set(channels.map((c: any) => c.id));
      parityExtApChannelStore.setState({
        channels: [...channels, ...fx.archivedChannels.filter((c: any) => !known.has(c.id)).map((c: any) => ({
          ...channels[0], ...c, joined: true, serverId: channels[0]?.serverId,
        }))],
      } as never);
    }
  }, [p.raw]);
  const props = {
    caseId: p.raw,
    tab: p.tab,
    role: p.role,
    flags: new Set(p.flags.split(",").filter(Boolean)),
    routeSet: p.routeSet,
    mobile: p.mobile,
  } as ParityExtSettingsProps;
  if (p.mobile && p.tab === "release-notes") {
    // Phone /release-notes route: MainLayout renders ReleaseNotesPanel alone in the content column.
    useMemo(() => parityExtPrimeSettingsStores(props), [p.raw]);
    return (
      <main className="min-h-screen bg-white p-0 font-display text-black">
        <div
          data-visual-case={p.raw}
          className="bg-layer-canvas-muted theme-brutal:bg-white"
          style={{ ...parityExtShellVars(), width: p.width, height: p.height, display: "flex", flexDirection: "column", overflow: "hidden" }}
        >
          <ParityExtApReleaseNotes />
        </div>
      </main>
    );
  }
  return <ParityExtSettingsCaseView props={props} />;
}

function ParityExtApView({ p }: { p: ParityExtApP }) {
  useMemo(() => {
    const fx = parityExtApFixture as Record<string, any>;
    const user = p.user === "none" ? null : { ...fx.user, emailVerified: true };
    parityExtApAuthStore.setState({ initialized: true, loading: false, user } as never);
    const list = (fx.servers as Record<string, unknown[]>)[p.servers] ?? [];
    parityExtApServerStore.setState({
      servers: list as never,
      current: (list[0] ?? null) as never,
      loading: p.view === "servers-loading",
    });
  }, [p.raw]);
  const fx = parityExtApFixture as Record<string, any>;
  let page: any = null;
  let frame = true;
  if (p.view === "register") {
    page = <ParityExtApRegisterPage onSwitchToLogin={() => undefined} />;
  } else if (p.view === "bootstrap") {
    page = <ParityExtApBootstrap view={p.kind as "loading" | "restoring"} />;
  } else if (p.view === "servers-loading") {
    page = <ParityExtApServerSelection />;
  } else if (p.view === "joining-community") {
    // ServerResolver renders this splash inline (App.tsx `joiningCommunity` branch); the markup is the
    // same box as AuthBootstrapStatus (v1.21.23: bg-layer-sidebar, text-headline text-foreground-muted)
    // with the pages.app.joiningCommunity copy.
    page = (
      <div className="flex min-h-0 flex-1 items-center justify-center bg-layer-sidebar font-display safe-top">
        <div className="text-headline text-foreground-muted">Joining community…</div>
      </div>
    );
  } else if (p.view === "access-denied") {
    page = <ParityExtApDenied />;
  } else if (p.view === "invite") {
    page = (
      <ParityExtApInvitePage
        token="parity-invite-token"
        onInviteConsumed={() => undefined}
        onSwitchToLogin={() => undefined}
        onSwitchToRegister={() => undefined}
      />
    );
  } else if (p.view === "identity") {
    page = (
      <ParityExtApIdentityPage
        previewUser={{
          ...fx.user,
          name: "pending_new_designer",
          displayName: null,
          emailVerified: true,
          profileSetupCompletedAt: null,
          profileSetupSuggestedHandle: "new_designer",
          profileSetupProvider: null,
        } as never}
        onPreviewComplete={async () => undefined}
      />
    );
  } else if (p.view === "server-selector") {
    page = <ParityExtApServerSelector onSelect={() => undefined} />;
  } else if (p.view === "setup-gate") {
    if (p.kind === "resume") {
      frame = false;
      page = <ParityExtApSetupGate serverId="srv-1" serverSlug="raft-design" />;
    } else {
      // Dedicated native surface: App.tsx wraps the gate in this <main>.
      page = (
        <main className="relative flex min-h-0 flex-1 bg-layer-sidebar font-display safe-top safe-bottom" data-testid="native-onboarding-web-surface">
          <ParityExtApSetupGate
            serverId="srv-1"
            serverSlug="raft-design"
            dedicatedSurface
            completionWakeGeneration={p.kind === "complete" ? "gen-1" : null}
          />
        </main>
      );
    }
  } else if (p.view === "root-error") {
    const error = new Error(fx.rootError.message);
    error.stack = fx.rootError.stack;
    page = <ParityExtApRootError error={error} componentStack={fx.rootError.componentStack} />;
  } else if (p.view === "community-agreement") {
    frame = false;
    page = (
      <ParityExtApCommunityAgreement
        agreement={fx.agreement}
        onClose={() => undefined}
        onAgree={() => new Promise<void>((resolve, reject) => {
          if (p.kind === "pending") return;
          if (p.kind === "error") reject({ response: { data: { error: "agreement_changed" } } });
          else resolve();
        })}
      />
    );
  }
  // App.tsx renders these pages directly inside the #root flex column, so a `flex-1` page root stretches to
  // the viewport.
  return (
    <main className="min-h-screen bg-white p-0 font-display text-foreground">
      <div
        data-visual-case={p.raw}
        style={frame
          ? { width: p.width, height: p.height, overflow: "hidden", display: "flex", flexDirection: "column" }
          : { width: "100vw", height: "100vh", overflow: "hidden" }}
      >
        {page}
      </div>
    </main>
  );
}

function parityExtAuthPagesElement() {
  const p = parityExtApProps();
  if (!p) return null;
  return p.view === "settings" ? <ParityExtApSettings p={p} /> : <ParityExtApView p={p} />;
}
