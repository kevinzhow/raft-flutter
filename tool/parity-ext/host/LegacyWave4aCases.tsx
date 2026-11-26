// raft-flutter parity EXTENSION cases: Wave 4A legacy UI cleanup surfaces
// (DeclaredScopesPicker, OAuthScopeSummaryPanel, PublicChannelList, AgreementBody).
import type { ReactElement as ParityExtWave4aElement } from "react";
import { Card as ParityExtWave4aCard } from "@botiverse/raft-ui";
import parityExtWave4aFixture from "virtual:parity-ext/legacy-wave4a";
import ParityExtWave4aAgreementBody from "../src/components/server/AgreementBody";
import { DeclaredScopesPicker as ParityExtWave4aDeclaredScopes } from "../src/features/apps/connected-apps/DeclaredScopesPicker";
import { OAuthScopeSummaryPanel as ParityExtWave4aOAuthSummary } from "../src/features/apps/connected-apps/OAuthScopeSummaryPanel";
import { PublicChannelList as ParityExtWave4aPublicChannelList } from "../src/features/settings/server/PublicChannelList";
import type { RaftOAuthScopeId as ParityExtWave4aScopeId } from "../src/lib/oauthScopePresentation";

function ParityExtWave4aHost({
  cid,
  surface,
  platform,
}: {
  cid: string;
  surface: string;
  platform: "desktop" | "phone";
}) {
  const fx = parityExtWave4aFixture;
  const width =
    surface === "declared-scopes"
      ? platform === "phone"
        ? 390
        : 600
      : surface === "oauth-scope-summary"
        ? 540
        : 500;

  let body: ParityExtWave4aElement | null = null;
  if (surface === "declared-scopes") {
    body = (
      <ParityExtWave4aDeclaredScopes
        value={fx.declaredScopes as ParityExtWave4aScopeId[]}
        onChange={() => {}}
      />
    );
  } else if (surface === "oauth-scope-summary") {
    body = (
      <ParityExtWave4aOAuthSummary
        title="Permissions"
        description="Effective access granted to this app."
        scopes={fx.oauthScopes}
        defaultOpen={true}
      />
    );
  } else if (surface === "public-channel-list" || surface === "public-channel-list-empty") {
    body = (
      <ParityExtWave4aPublicChannelList
        channels={surface === "public-channel-list-empty" ? [] : fx.publicChannels}
      />
    );
  } else if (surface === "agreement-body" || surface === "agreement-body-empty") {
    body = (
      <ParityExtWave4aCard className="p-3">
        <div className="text-sm">
          <ParityExtWave4aAgreementBody
            source={surface === "agreement-body-empty" ? "" : fx.agreementBody}
          />
        </div>
      </ParityExtWave4aCard>
    );
  }

  return (
    <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
      <div
        data-visual-case={cid}
        className="bg-layer-canvas p-4 text-foreground"
        style={{ width }}
      >
        {body}
      </div>
    </main>
  );
}

function parityExtLegacyWave4aElement(): ParityExtWave4aElement | null {
  const raw = new URLSearchParams(window.location.search).get("case") ?? "";
  const match =
    /^components\.legacy-wave4a\.([\w-]+)\.(desktop|phone)\.(brutal|elegant-dark)$/.exec(
      raw,
    );
  if (!match) return null;
  const [, surface, platform] = match;
  return (
    <ParityExtWave4aHost
      cid={raw}
      surface={surface}
      platform={platform as "desktop" | "phone"}
    />
  );
}
