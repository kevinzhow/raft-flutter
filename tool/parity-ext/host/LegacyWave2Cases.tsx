// raft-flutter parity EXTENSION cases: Wave 2 legacy UI migration surfaces
// (ReportIssueDialog, CommunityAgreementDialog, AddMachineDialog confirm step,
// AddMembersDialog, ChannelMembers page, RuntimeProviderConnectDialog,
// AttachmentCommentsPanel, SelectShareLightbox).
import type { Channel as ParityExtWave2Channel, ChannelMemberSummary as ParityExtWave2MemberSummary, ChannelAgentSummary as ParityExtWave2AgentSummary } from "../src/store/channelStore";
import type { ReactElement as ParityExtWave2Element } from "react";
import { useEffect as useParityExtWave2Effect, useMemo as useParityExtWave2Memo, useState as useParityExtWave2State } from "react";
import parityExtWave2Fixture from "virtual:parity-ext/legacy-wave2";
import parityExtWave2Api from "../src/api/client";
import ParityExtWave2AddMembersDialog from "../src/components/channel/AddMembersDialog";
import ParityExtWave2AddMachineDialog from "../src/components/machine/AddMachineDialog";
import { AttachmentCommentsPanel as ParityExtWave2AttachmentCommentsPanel } from "../src/components/message/AttachmentCommentsPanel";
import ParityExtWave2SelectShareLightbox from "../src/components/message/SelectShareLightbox";
import ParityExtWave2CommunityAgreementDialog from "../src/components/server/CommunityAgreementDialog";
import ParityExtWave2ReportIssueDialog from "../src/components/agent/ReportIssueDialog";
import { ChannelMembers as ParityExtWave2ChannelMembers } from "../src/features/channel/ChannelMembers";
import { RuntimeProviderConnectDialog as ParityExtWave2RuntimeProviderConnectDialog } from "../src/features/computer/RuntimeProviderConnectDialog";
import { useAgentStore as useParityExtWave2Agents } from "../src/store/agentStore";
import { useAuthStore as useParityExtWave2Auth } from "../src/store/authStore";
import { useChannelStore as useParityExtWave2Channels } from "../src/store/channelStore";
import { useMachineStore as useParityExtWave2Machines } from "../src/store/machineStore";
import { useServerStore as useParityExtWave2Server } from "../src/store/serverStore";
import { useTranslationStore as useParityExtWave2Translation } from "../src/store/translationStore";
import type { RuntimeAuthClient as ParityExtWave2RuntimeAuthClient } from "../src/utils/runtimeAuthClient";

let parityExtWave2OrigPost: typeof parityExtWave2Api.post | null = null;
let parityExtWave2OrigGet: typeof parityExtWave2Api.get | null = null;
let parityExtWave2OrigFetch: typeof globalThis.fetch | null = null;

function parityExtWave2PrimeStores(surface: string) {
  const fx = parityExtWave2Fixture;
  const emptyMembers = surface === "add-members-empty";
  const allAgents = fx.agents;
  const allMembers = fx.members;

  useParityExtWave2Auth.setState({ user: fx.user } as never);
  useParityExtWave2Server.setState({
    current: fx.server,
    members: allMembers,
  } as never);
  useParityExtWave2Agents.setState({ agents: allAgents } as never);
  useParityExtWave2Channels.setState({
    channels: fx.channels,
    dmChannels: [],
    loungeChannels: [],
    currentChannelId: fx.channels[0].id,
    channelMembers: emptyMembers
      ? {
          [fx.channels[0].id]: {
            humans: allMembers.map((m) => ({
              id: m.userId,
              name: m.name,
              displayName: m.displayName,
              role: m.role,
              description: m.description,
              avatarUrl: m.avatarUrl,
            })),
            agents: allAgents.map((a) => ({
              id: a.id,
              name: a.name,
              displayName: a.displayName,
              description: a.description,
              avatarUrl: a.avatarUrl,
              status: a.status,
              role: a.role,
            })),
          },
        }
      : {
          [fx.channels[0].id]: {
            humans: [
              {
                id: allMembers[0].userId,
                name: allMembers[0].name,
                displayName: allMembers[0].displayName,
                role: allMembers[0].role,
                description: allMembers[0].description,
                avatarUrl: allMembers[0].avatarUrl,
              },
            ],
            agents: [
              {
                id: allAgents[0].id,
                name: allAgents[0].name,
                displayName: allAgents[0].displayName,
                description: allAgents[0].description,
                avatarUrl: allAgents[0].avatarUrl,
                status: allAgents[0].status,
                role: allAgents[0].role,
              },
            ],
          },
        },
  } as never);

  const initialMachine =
    surface === "add-computer-confirm"
      ? { ...fx.machine, status: "offline", computerAttachedByCurrentUser: true }
      : fx.machine;
  useParityExtWave2Machines.setState({
    machines: [initialMachine],
    addMachineIntent: surface === "add-computer-confirm" ? "another-computer" : null,
  } as never);

  useParityExtWave2Translation.setState({
    settings: {
      preferredLanguage: "en",
      effectiveLanguage: "en",
      preferredTimezone: "UTC",
      effectiveTimezone: "UTC",
      autoTranslationEnabled: false,
      preferredTranslationMode: "off",
      preferredTranslationDisplay: "translated",
      preferredTimeFormat: "24h",
      effectiveTimeFormat: "24h",
      available: false,
      serverTranslationEnabled: false,
      providerAvailable: false,
      canManageServerTranslation: false,
    },
  } as never);

  if (!parityExtWave2OrigPost) {
    parityExtWave2OrigPost = parityExtWave2Api.post.bind(parityExtWave2Api);
  }
  const origPost = parityExtWave2OrigPost;
  parityExtWave2Api.post = ((path: string, body?: unknown, config?: unknown) => {
    if (path.includes("/scope-attestation")) {
      return Promise.resolve({
        data: {
          attestation: "att-wave2-01",
          scope: "feedback-report:create",
          expiresAt: "2026-12-01T00:00:00.000Z",
        },
      });
    }
    if (path === "/product-feedback") {
      return Promise.resolve({ data: { id: "tkt-wave2-01" } });
    }
    if (path.includes("/feedback/") && path.endsWith("/transcript")) {
      return Promise.resolve({ data: { status: "requested" } });
    }
    return origPost(path, body as never, config as never);
  }) as typeof parityExtWave2Api.post;

  if (!parityExtWave2OrigGet) {
    parityExtWave2OrigGet = parityExtWave2Api.get.bind(parityExtWave2Api);
  }
  const origGet = parityExtWave2OrigGet;
  parityExtWave2Api.get = ((path: string, config?: unknown) => {
    if (path === `/attachments/${fx.attachment.id}/comments`) {
      return Promise.resolve({
        data: {
          comments: surface === "attachment-comments-empty" ? [] : fx.attachment.comments,
          threadChannelId: "chan-wave2-thread",
          viewer: { canComment: true, reason: "ok" },
        },
      });
    }
    if (path.includes(`/channels/${fx.channels[0].id}/members`)) {
      return Promise.resolve({
        data: emptyMembers
          ? {
              humans: allMembers.map((m) => ({
                id: m.userId,
                name: m.name,
                displayName: m.displayName,
                role: m.role,
              })),
              agents: allAgents.map((a) => ({
                id: a.id,
                name: a.name,
                displayName: a.displayName,
                role: a.role,
              })),
            }
          : {
              humans: [{ id: allMembers[0].userId, name: allMembers[0].name, displayName: allMembers[0].displayName, role: allMembers[0].role }],
              agents: [{ id: allAgents[0].id, name: allAgents[0].name, displayName: allAgents[0].displayName, role: allAgents[0].role }],
            },
      });
    }
    return origGet(path, config as never);
  }) as typeof parityExtWave2Api.get;

  if (!parityExtWave2OrigFetch) {
    parityExtWave2OrigFetch = globalThis.fetch.bind(globalThis);
  }
  const origFetch = parityExtWave2OrigFetch;
  globalThis.fetch = ((input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
    if (url === "https://feedback.example.test/api/reports") {
      return Promise.resolve(
        new Response(
          JSON.stringify({
            id: "rep-wave2-01",
            upload: { method: "PUT", url: "https://upload.example.test/put", headers: {} },
            completeToken: "tok-wave2-01",
            expiresAt: "2026-12-01T00:00:00.000Z",
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );
    }
    if (url === "https://upload.example.test/put") {
      return Promise.resolve(new Response("", { status: 200 }));
    }
    if (url === "https://feedback.example.test/api/reports/rep-wave2-01/complete") {
      return Promise.resolve(new Response(JSON.stringify({ ok: true }), { status: 200, headers: { "Content-Type": "application/json" } }));
    }
    return origFetch(input, init);
  }) as typeof globalThis.fetch;
}

function parityExtWave2DataUrlToBlob(b64: string): Blob {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new Blob([bytes], { type: "image/png" });
}

function ParityExtWave2View({ id, surface, platform }: { id: string; surface: string; platform: string }) {
  const fx = parityExtWave2Fixture;
  useParityExtWave2State(() => {
    parityExtWave2PrimeStores(surface);
    return true;
  });

  useParityExtWave2Effect(() => {
    if (surface !== "runtime-provider-connect") return;
    const blurActive = () => {
      if (document.activeElement instanceof HTMLElement) {
        document.activeElement.blur();
      }
    };
    const timers = [20, 60, 140, 220].map((ms) => window.setTimeout(blurActive, ms));
    const onFocusIn = () => window.setTimeout(blurActive, 0);
    document.addEventListener("focusin", onFocusIn, true);
    const stopTimer = window.setTimeout(() => document.removeEventListener("focusin", onFocusIn, true), 300);
    return () => {
      timers.forEach((t) => window.clearTimeout(t));
      window.clearTimeout(stopTimer);
      document.removeEventListener("focusin", onFocusIn, true);
    };
  }, [surface]);

  useParityExtWave2Effect(() => {
    if (surface !== "add-computer-confirm") return;
    const timer = window.setTimeout(() => {
      useParityExtWave2Machines.setState({
        machines: [{ ...fx.machine, status: "online", computerAttachedByCurrentUser: true }],
      } as never);
    }, 40);
    return () => window.clearTimeout(timer);
  }, [surface, fx.machine]);

  const stubRuntimeClient = useParityExtWave2Memo(
    () =>
      ({
        listProviders: async () => ({
          kind: "listed" as const,
          providers: fx.runtimeProviders,
        }),
        connectProvider: async () => ({ kind: "connected" as const }),
        invalidate: () => undefined,
      }) as unknown as ParityExtWave2RuntimeAuthClient,
    [fx.runtimeProviders],
  );

  if (surface === "report-issue" || surface === "report-issue-submitted") {
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <ParityExtWave2ReportIssueDialog
          agent={fx.agents[0] as never}
          onClose={() => undefined}
          feedbackExportUrl="https://feedback.example.test"
        />
      </main>
    );
  }

  if (surface === "community-agreement") {
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <ParityExtWave2CommunityAgreementDialog
          agreement={fx.agreement}
          onClose={() => undefined}
          onAgree={async () => undefined}
        />
      </main>
    );
  }

  if (surface === "add-computer-confirm") {
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <ParityExtWave2AddMachineDialog onClose={() => undefined} intent="another-computer" />
      </main>
    );
  }

  if (surface === "add-members" || surface === "add-members-empty") {
    const empty = surface === "add-members-empty";
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <ParityExtWave2AddMembersDialog
          channelId={fx.channels[0].id}
          prefilledHumanIds={empty ? [] : [fx.members[1].userId]}
          prefilledAgentIds={empty ? [] : [fx.agents[1].id]}
          draftHint={empty ? undefined : "Cindy suggested inviting Lux and Ben for design review."}
          onClose={() => undefined}
          onSubmitted={() => undefined}
        />
      </main>
    );
  }

  if (surface === "channel-members-page") {
    const prefetched = {
      channelAgents: fx.agents.map((a) => ({
        id: a.id,
        name: a.name,
        displayName: a.displayName,
        description: a.description,
        avatarUrl: a.avatarUrl,
        status: a.status,
        role: a.role,
      })) as ParityExtWave2AgentSummary[],
      channelHumans: fx.members.map((m) => ({
        id: m.userId,
        name: m.name,
        displayName: m.displayName,
        description: m.description,
        avatarUrl: m.avatarUrl,
        role: m.role,
      })) as ParityExtWave2MemberSummary[],
      channelExternalMembers: [],
      loading: false,
      addMembers: async () => ({}),
      addAgent: async () => undefined,
      removeAgent: async () => undefined,
      addHuman: async () => undefined,
      removeHuman: async () => undefined,
      changeMemberRole: async () => undefined,
      roleChangeFailed: false,
    };
    const w = platform === "desktop" ? 384 : 390;
    const h = platform === "desktop" ? 720 : 844;
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <div style={{ width: w, height: h, display: "flex", flexDirection: "column", overflow: "hidden" }}>
          <ParityExtWave2ChannelMembers
            channelId={fx.channels[0].id}
            presentation="page"
            prefetchedMembers={prefetched}
            onClose={() => undefined}
          />
        </div>
      </main>
    );
  }

  if (surface === "runtime-provider-connect") {
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <ParityExtWave2RuntimeProviderConnectDialog
          serverId={fx.server.id}
          machineId={fx.machine.id}
          runtimeId="qwen"
          runtime="qwen"
          client={stubRuntimeClient}
          onClose={() => undefined}
        />
      </main>
    );
  }

  if (surface === "attachment-comments" || surface === "attachment-comments-empty") {
    const w = platform === "desktop" ? 320 : 390;
    const h = 640;
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <div data-visual-case={id} style={{ width: w, height: h, display: "flex", flexDirection: "column", overflow: "hidden" }}>
          <ParityExtWave2AttachmentCommentsPanel
            attachmentId={fx.attachment.id}
            filename={fx.attachment.filename}
            parentMessage={fx.attachment.parentMessage as never}
            pendingAnchor={surface === "attachment-comments" ? (fx.attachment.pendingAnchor as never) : null}
          />
        </div>
      </main>
    );
  }

  if (surface === "message-image-export") {
    const b64 = fx.exportPngBase64;
    const dataUrl = `data:image/png;base64,${b64}`;
    const blob = parityExtWave2DataUrlToBlob(b64);
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <ParityExtWave2SelectShareLightbox
          image={{
            blob,
            dataUrl,
            width: 360,
            height: 180,
            pixelRatio: 2,
            pixelCount: 360 * 180,
          }}
          filename="release-export.png"
          onClose={() => undefined}
        />
      </main>
    );
  }

  return <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground" />;
}

function parityExtLegacyWave2Element(): ParityExtWave2Element | null {
  const id = new URLSearchParams(window.location.search).get("case") ?? "";
  const match = /^components\.legacy-wave2\.([\w-]+)\.(desktop|phone)\.(brutal|elegant-dark)$/.exec(id);
  if (!match) return null;
  const [, surface, platform] = match;
  return <ParityExtWave2View id={id} surface={surface} platform={platform} />;
}
