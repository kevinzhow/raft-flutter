// raft-flutter parity EXTENSION cases: Wave 3A legacy UI cleanup surfaces
// (ServerCreatePreview, AccountIdentitySetupPage preview, CreateCindy screen,
// ServerSetupSurveyStep, ServerSetupHandoffStep, ServerSetupComputerRuntimeStep,
// ProviderAccountRow, MarketplaceServerRow, FeedbackInbox EmptyState, SearchSkeleton,
// Search error Banner).
import type { ReactElement as ParityExtWave3aElement } from "react";
import { useMemo as useParityExtWave3aMemo } from "react";
import { Plug as ParityExtWave3aPlug } from "lucide-react";
import {
  Card as ParityExtWave3aCard,
  ListRowGroup as ParityExtWave3aListRowGroup,
} from "@botiverse/raft-ui";
import {
  FeedbackInbox as ParityExtWave3aFeedbackInbox,
  FeedbackProvider as ParityExtWave3aFeedbackProvider,
} from "@botiverse/hands-feedback-react";
import "@botiverse/hands-feedback-react/styles.css";
import type { HandsFeedbackTransport as ParityExtWave3aFeedbackTransport } from "@botiverse/hands-feedback-react";
import parityExtWave3aFixture from "virtual:parity-ext/legacy-wave3a";
import ParityExtWave3aIdentityPage from "../src/components/auth/AccountIdentitySetupPage";
import { OnboardingCreateDotPane as ParityExtWave3aDotPane } from "../src/components/auth/OnboardingCreateShell";
import ParityExtWave3aServerPreview from "../src/components/auth/ServerCreatePreview";
import ParityExtWave3aComputerStep from "../src/components/onboarding/ServerSetupComputerRuntimeStep";
import ParityExtWave3aHandoffStep from "../src/components/onboarding/ServerSetupHandoffStep";
import ParityExtWave3aSurveyStep from "../src/components/onboarding/ServerSetupSurveyStep";
import { ProviderAccountRow as ParityExtWave3aProviderRow } from "../src/components/settings/ProviderAccountRow";
import ParityExtWave3aSectionHeader from "../src/components/ui/SectionHeader";
import ParityExtWave3aBanner from "../src/components/ui/Banner";
import { serverSetupPreviewFixture as parityExtWave3aSetupFixture } from "../src/dev/serverSetupPreviewFixtures";
import { SearchSkeleton as ParityExtWave3aSearchSkeleton } from "../src/features/search/SearchSkeleton";
import { FIELD_HELP_CLASS, FIELD_LABEL_CLASS } from "../src/features/login-with-raft/loginSetupClassNames";
import { MarketplaceServerRow as ParityExtWave3aMarketplaceRow } from "../src/pages/MarketplaceServerRow";
import { useAuthStore as useParityExtWave3aAuth } from "../src/store/authStore";
import { useMachineStore as useParityExtWave3aMachines } from "../src/store/machineStore";
import { useServerStore as useParityExtWave3aServer } from "../src/store/serverStore";

const parityExtWave3aEmptyFeedbackTransport: ParityExtWave3aFeedbackTransport = {
  listTickets: async () => ({ tickets: [], nextCursor: null, unreadTotal: 0 }),
  getTicket: async () => { throw new Error("not used"); },
  createTicket: async () => { throw new Error("not used"); },
  replyToTicket: async () => { throw new Error("not used"); },
  closeTicket: async () => { throw new Error("not used"); },
  uploadAttachment: async () => { throw new Error("not used"); },
};

function parityExtWave3aPrimeStores() {
  const fx = parityExtWave3aFixture;
  useParityExtWave3aAuth.setState({
    initialized: true,
    loading: false,
    user: fx.user,
  } as never);
  useParityExtWave3aServer.setState({
    current: fx.server,
    servers: [fx.server],
  } as never);
  useParityExtWave3aMachines.setState({
    machines: [fx.machine],
    machinesLoadedServerId: fx.server.id,
  } as never);
}

function ParityExtWave3aHost({
  cid,
  surface,
  platform,
}: {
  cid: string;
  surface: string;
  platform: "desktop" | "phone";
}) {
  useParityExtWave3aMemo(() => parityExtWave3aPrimeStores(), []);
  const phone = platform === "phone";
  const fx = parityExtWave3aFixture;
  let body: ParityExtWave3aElement | null = null;

  if (surface === "server-create-preview" || surface === "server-create-custom") {
    const custom = surface === "server-create-custom";
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <style>{`.wave3a-dotpane > aside { display: flex !important; flex: 1 1 0% !important; }`}</style>
        <div
          data-visual-case={cid}
          className="flex flex-col bg-layer-frame wave3a-dotpane"
          style={{ width: phone ? 390 : 768, height: phone ? 620 : 640 }}
        >
          <ParityExtWave3aDotPane>
            <ParityExtWave3aServerPreview
              serverName={custom ? "Design Lab" : ""}
              serverSlug={custom ? "design-lab" : ""}
            />
          </ParityExtWave3aDotPane>
        </div>
      </main>
    );
  }

  if (surface === "identity-impact-preview") {
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <div style={{ width: 1280, height: 800, display: "flex", flexDirection: "column" }}>
          <ParityExtWave3aIdentityPage onContinue={() => undefined} />
        </div>
      </main>
    );
  }

  if (surface === "cindy-setup") {
    body = (
      <div className="flex min-h-screen w-full items-center justify-center bg-layer-canvas p-4">
        <CreateAgentDialog
          onboarding
          onboardingShell="step"
          previewOnly
          previewRuntimeOptions={fx.runtimeOptions as never}
          defaultMachineId={fx.machine.id}
          onClose={() => undefined}
        />
      </div>
    );
  } else if (surface === "setup-survey") {
    body = (
      <div className="flex min-h-screen w-full items-center justify-center bg-layer-canvas p-4">
        <ParityExtWave3aSurveyStep onDone={() => undefined} />
      </div>
    );
  } else if (surface === "setup-handoff") {
    body = (
      <div className="flex min-h-screen w-full items-center justify-center bg-layer-canvas p-4">
        <ParityExtWave3aHandoffStep serverId={fx.server.id} onDone={() => undefined} />
      </div>
    );
  } else if (surface === "setup-computer") {
    const setupFx = parityExtWave3aSetupFixture("ready");
    body = (
      <div
        data-visual-case={cid}
        className="flex min-h-screen w-full items-center justify-center bg-layer-canvas p-4"
      >
        <ParityExtWave3aComputerStep
          computer={setupFx.computer}
          runtimeStatus={setupFx.runtimeStatus}
          runtimeOptions={setupFx.runtimeOptions}
          hasConnectedComputer={setupFx.hasConnectedComputer}
          offlineComputers={setupFx.offlineComputers}
          serverSlug={fx.server.slug}
          showOwnApiKey={false}
          setupCommand="raft-computer setup /launch"
          computerInstallCommand="curl -fsSL https://cdn.raft.build/computer/install.sh | sh"
          canReset={false}
          onCopyInstallCommand={() => undefined}
          onStartOver={() => undefined}
          onNext={() => undefined}
        />
      </div>
    );
  } else if (surface === "provider-accounts") {
    body = (
      <div
        data-visual-case={cid}
        className="bg-layer-canvas p-4"
        style={{ width: phone ? 358 : 560 }}
      >
        <ParityExtWave3aSectionHeader
          className="mb-3"
          icon={<ParityExtWave3aPlug size={16} />}
          label="Connected accounts"
        />
        <ParityExtWave3aListRowGroup>
          {fx.providers.map((provider) => {
            const identity = fx.identities.find((i) => i.provider === provider.id);
            return (
              <ParityExtWave3aProviderRow
                key={provider.id}
                provider={provider as never}
                identity={identity}
                linking={false}
                onConnect={() => undefined}
                onRequestDisconnect={() => undefined}
              />
            );
          })}
        </ParityExtWave3aListRowGroup>
      </div>
    );
  } else if (surface === "human-login-servers") {
    body = (
      <div
        data-visual-case={cid}
        className="bg-layer-canvas p-2"
        style={{ width: phone ? 358 : 520 }}
      >
        <div className={FIELD_LABEL_CLASS}>Raft server</div>
        <div className="mt-1.5">
          <ParityExtWave3aCard>
            {fx.loginServers.map((s) => {
              const entry = s.state === "unavailable"
                ? undefined
                : {
                    serverId: s.id,
                    client: {
                      clientId: "app-share",
                      name: "Artifact Share",
                      marketplace: true,
                      accountMode: false,
                      suspended: false,
                      installRequired: s.state !== "ready",
                      availability: s.state === "ready" ? "ready" : "install_required",
                      installation: {
                        canInstall: s.state === "install",
                      },
                    },
                  };
              return (
                <ParityExtWave3aMarketplaceRow
                  key={s.id}
                  server={{ id: s.id, name: s.name, slug: s.slug, avatarUrl: null } as never}
                  entry={entry as never}
                  selected={s.id === "srv-1"}
                  installPending={false}
                  installInFlight={false}
                  onSelect={() => undefined}
                />
              );
            })}
          </ParityExtWave3aCard>
        </div>
        <p className={FIELD_HELP_CLASS}>
          All Raft Servers you can access are shown here. Continue with an installed Server, or install the App where you have permission.
        </p>
      </div>
    );
  } else if (surface === "feedback-empty") {
    body = (
      <div
        data-visual-case={cid}
        className="bg-layer-canvas p-4"
        style={{
          width: phone ? 358 : 640,
          ["--hf-margin" as string]: phone ? "16px" : "20px",
        }}
      >
        <ParityExtWave3aFeedbackProvider transport={parityExtWave3aEmptyFeedbackTransport} locale="en">
          <ParityExtWave3aFeedbackInbox
            hideHeaderTitle
            onSelectTicket={() => undefined}
            onNewFeedback={() => undefined}
          />
        </ParityExtWave3aFeedbackProvider>
      </div>
    );
  } else if (surface === "search-skeleton") {
    body = (
      <div
        data-visual-case={cid}
        className="bg-layer-canvas"
        style={{ width: phone ? 358 : 680 }}
      >
        <ParityExtWave3aSearchSkeleton />
      </div>
    );
  } else if (surface === "search-error") {
    body = (
      <div
        data-visual-case={cid}
        className="bg-layer-canvas p-5"
        style={{ width: phone ? 358 : 680 }}
      >
        <ParityExtWave3aBanner
          intent="warning"
          live={false}
          withIcon
          title="Search failed"
          actions={(
            <Button type="button" variant="outline" size="md" onClick={() => undefined}>
              Retry
            </Button>
          )}
        >
          The last search request failed. Existing results are preserved when possible, but this query needs a retry.
        </ParityExtWave3aBanner>
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
      {body}
    </main>
  );
}

function parityExtLegacyWave3aElement(): ParityExtWave3aElement | null {
  const raw = new URLSearchParams(window.location.search).get("case") ?? "";
  const match = /^components\.legacy-wave3a\.([\w-]+)\.(desktop|phone)\.(brutal|elegant-dark)$/.exec(raw);
  if (!match) return null;
  const [, surface, platform] = match;
  return (
    <ParityExtWave3aHost
      cid={raw}
      surface={surface}
      platform={platform as "desktop" | "phone"}
    />
  );
}
