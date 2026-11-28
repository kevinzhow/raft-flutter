// raft-flutter parity EXTENSION cases: auth & onboarding surfaces the official
// set does not cover (login states, forgot/reset password, email
// verification, social buttons, server selector, invite accept, server setup
// steps). Appended to the generated VisualTestingCases.tsx like the other host
// files (shares its imports and private helpers); identifiers are prefixed
// `parityExtAuth`.
//
// Every case mounts the REAL Web page/component. The auth/server stores are
// primed the way App.tsx leaves them for that screen; the API answers come
// from tool/parity-ext/fixtures/auth-ext.json (`routes` + `routeSets`, served
// by the provider spec's page.route), the same data the Flutter fixture client
// reads. Ids: components.auth-ext.<platform>.<surface>[.<state>].<theme>.
import ParityExtAuthLoginPage from "../src/components/auth/LoginPage";
import ParityExtAuthForgotPage from "../src/components/auth/ForgotPasswordPage";
import ParityExtAuthResetPage from "../src/components/auth/ResetPasswordPage";
import ParityExtAuthVerifyPage from "../src/components/auth/EmailVerificationPage";
import ParityExtAuthServerSelector from "../src/components/auth/ServerSelector";
import ParityExtAuthSurveyStep from "../src/components/onboarding/ServerSetupSurveyStep";
import ParityExtAuthHandoffStep from "../src/components/onboarding/ServerSetupHandoffStep";
import ParityExtAuthComputerStep from "../src/components/onboarding/ServerSetupComputerRuntimeStep";
import { serverSetupPreviewFixture as parityExtAuthSetupFixture } from "../src/dev/serverSetupPreviewFixtures";
import { useAuthStore as parityExtAuthStore } from "../src/store/authStore";
import { useServerStore as parityExtAuthServerStore } from "../src/store/serverStore";
import parityExtAuthFixture from "virtual:parity-ext/auth-ext";

function parityExtAuthProps() {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("case") ?? "";
  if (!raw.startsWith("components.auth-ext.")) return null;
  return {
    raw,
    view: params.get("view") ?? "login",
    width: Number(params.get("w") ?? 390),
    height: Number(params.get("h") ?? 844),
    servers: params.get("servers") ?? "none",
    step: params.get("step") ?? "ready",
    reset: params.get("reset") === "true",
  };
}

function parityExtAuthUser(emailVerified: boolean) {
  return {
    ...(parityExtAuthFixture.user as Record<string, unknown>),
    emailVerified,
  } as never;
}

function ParityExtAuthView({ p }: { p: NonNullable<ReturnType<typeof parityExtAuthProps>> }) {
  useMemo(() => {
    const signedIn = p.view !== "login" && p.view !== "forgot" && p.view !== "reset";
    parityExtAuthStore.setState({
      initialized: true,
      loading: false,
      user: signedIn ? parityExtAuthUser(p.view !== "verify") : null,
    });
    if (p.view === "server-selector") {
      const list = (parityExtAuthFixture.servers as Record<string, unknown[]>)[p.servers] ?? [];
      parityExtAuthServerStore.setState({ servers: list as never, loading: false });
    }
  }, [p.raw]);
  let page: any = null;
  if (p.view === "login") {
    page = <ParityExtAuthLoginPage onSwitchToRegister={() => undefined} onForgotPassword={() => undefined} />;
  } else if (p.view === "forgot") {
    page = <ParityExtAuthForgotPage onBack={() => undefined} />;
  } else if (p.view === "reset") {
    page = <ParityExtAuthResetPage token="parity-reset-token" onBack={() => undefined} />;
  } else if (p.view === "verify") {
    const fromLink = p.raw.includes(".verify.link-pending.");
    page = <ParityExtAuthVerifyPage
      initialToken={fromLink ? "parity-verify-token" : undefined}
      initialReturnTo={fromLink ? "/artifacts/release-checklist?revision=1" : undefined}
    />;
  } else if (p.view === "server-selector") {
    page = <ParityExtAuthServerSelector onSelect={() => undefined} />;
  } else if (p.view === "computer-step") {
    // ServerSetupProjectionGate renders the step inside the same StepContainer;
    // the props are the dev preview fixtures of the Web source
    // (dev/serverSetupPreviewFixtures.ts), the page the step was designed on.
    const fixture = parityExtAuthSetupFixture(p.step as never);
    page = (
      <div className="flex min-h-full w-full overflow-y-auto p-4">
        <div className="m-auto flex w-full justify-center">
          <ParityExtAuthComputerStep
            computer={fixture.computer}
            runtimeStatus={fixture.runtimeStatus}
            runtimeOptions={fixture.runtimeOptions}
            hasConnectedComputer={fixture.hasConnectedComputer}
            offlineComputers={fixture.offlineComputers}
            serverSlug="launch"
            showOwnApiKey={false}
            setupCommand="raft-computer setup /launch"
            computerInstallCommand="curl -fsSL https://cdn.raft.build/computer/install.sh | sh"
            canReset={p.reset}
            onCopyInstallCommand={() => undefined}
            onStartOver={() => undefined}
            onNext={() => undefined}
          />
        </div>
      </div>
    );
  } else if (p.view === "survey" || p.view === "handoff") {
    // ServerSetupProjectionGate `StepContainer` (dedicated surface): the step
    // card centred in `flex min-h-full w-full overflow-y-auto p-4`.
    page = (
      <div className="flex min-h-full w-full overflow-y-auto p-4">
        <div className="m-auto flex w-full justify-center">
          {p.view === "survey"
            ? <ParityExtAuthSurveyStep onDone={() => undefined} />
            : <ParityExtAuthHandoffStep serverId="visual-server" onDone={() => undefined} />}
        </div>
      </div>
    );
  }
  // App.tsx renders these pages directly inside the #root flex column, so the
  // AuthBrandShell `flex-1` root stretches to the viewport.
  return (
    <main className="min-h-screen bg-white p-0 font-display text-foreground">
      <div
        data-visual-case={p.raw}
        style={{ width: p.width, height: p.height, overflow: "hidden", display: "flex", flexDirection: "column" }}
      >
        {page}
      </div>
    </main>
  );
}

function parityExtAuthElement() {
  const p = parityExtAuthProps();
  return p ? <ParityExtAuthView p={p} /> : null;
}
