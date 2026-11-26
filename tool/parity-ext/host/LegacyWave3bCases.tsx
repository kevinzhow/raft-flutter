// raft-flutter parity EXTENSION cases: Wave 3B legacy UI cleanup surfaces
// (AgentChatTab, EnvVarsSection, AgentRemindersSection, WorkspacesSection,
// MachineAgentRow / ListRowGroup, ComputerServiceActionsCard, ChannelFilesPanel).
import type { ReactElement as ParityExtWave3bElement } from "react";
import { useMemo as useParityExtWave3bMemo } from "react";
import parityExtWave3bFixture from "virtual:parity-ext/legacy-wave3b";
import parityExtWave3bApi from "../src/api/client";
import AgentRemindersSection from "../src/components/agent/AgentRemindersSection";
import { MachineAgentRow as ParityExtWave3bMachineAgentRow } from "../src/components/machine/MachineAgentRow";
import ParityExtWave3bSectionHeader from "../src/components/ui/SectionHeader";
import { AgentChatTab as ParityExtWave3bAgentChatTab } from "../src/features/agent/AgentChatTab";
import { EnvVarsSection as ParityExtWave3bEnvVarsSection } from "../src/features/agent/EnvVarsSection";
import { ComputerServiceActionsCard as ParityExtWave3bServiceCard } from "../src/features/computer/ComputerServiceActionsCard";
import { WorkspacesSection as ParityExtWave3bWorkspacesSection } from "../src/features/computer/WorkspacesSection";
import { getComputerCommands as getParityExtWave3bCommands } from "../src/utils/computerSetupCommand";

let parityExtWave3bOrigGet: typeof parityExtWave3bApi.get | null = null;

function parityExtWave3bPrime(surface: string) {
  const fx = parityExtWave3bFixture;
  const emptyChat = surface === "agent-chat-empty";
  const emptyFiles = surface === "channel-files-empty";

  useAuthStore.setState({
    initialized: true,
    loading: false,
    user: fx.user,
  } as never);
  useServerStore.setState({
    current: fx.server,
    servers: [fx.server],
  } as never);
  useChannelStore.setState({
    channels: fx.channels.map((c) => ({ ...c, serverId: fx.server.id, joined: true })) as never,
    dmChannels: [],
    loading: false,
    dmsLoading: false,
  });
  useAgentStore.setState({
    agents: [fx.agent, ...fx.computerAgents] as never,
    agentActivities: Object.fromEntries(
      fx.computerAgents.map((a) => [
        a.id,
        {
          activity: a.activity,
          activityDetail: a.activityDetail ?? undefined,
          detailKind: "other",
        },
      ]),
    ) as never,
  });
  useMachineStore.setState({
    machines: [fx.machine] as never,
    machinesLoadedServerId: fx.server.id,
    latestComputerVersion: fx.machine.daemonVersion,
    machineWorkspaces: {},
    machineWorkspacesLoading: {},
    scanMachineWorkspaces: (async (machineId: string) => {
      useMachineStore.setState({
        machineWorkspaces: { [machineId]: fx.workspaces as never },
        machineWorkspacesLoading: { [machineId]: false },
      });
      return fx.workspaces as never;
    }) as never,
  });

  if (!parityExtWave3bOrigGet) {
    parityExtWave3bOrigGet = parityExtWave3bApi.get.bind(parityExtWave3bApi);
  }
  const origGet = parityExtWave3bOrigGet;
  parityExtWave3bApi.get = ((path: string, config?: unknown) => {
    if (path === `/agents/${fx.agent.id}/channels`) {
      return Promise.resolve({ data: emptyChat ? [] : fx.channels });
    }
    if (path === `/agents/${fx.agent.id}/agent-dms`) {
      return Promise.resolve({ data: emptyChat ? [] : fx.agentDms });
    }
    if (path === `/channels/${fx.channel.id}/files`) {
      return Promise.resolve({
        data: {
          files: emptyFiles ? [] : fx.channelFiles,
          nextCursor: null,
          historyLimited: false,
        },
      });
    }
    if (path.includes("/artifacts")) {
      return Promise.resolve({ data: { cards: [], nextCursor: null } });
    }
    return origGet(path, config as never);
  }) as typeof parityExtWave3bApi.get;
}

function ParityExtWave3bHost({
  cid,
  surface,
  platform,
}: {
  cid: string;
  surface: string;
  platform: "desktop" | "phone";
}) {
  useParityExtWave3bMemo(() => parityExtWave3bPrime(surface), [surface]);
  const fx = parityExtWave3bFixture;
  const phone = platform === "phone";
  const activities = useAgentStore((s) => s.agentActivities);

  let body: ParityExtWave3bElement | null = null;
  if (surface === "agent-chat" || surface === "agent-chat-empty") {
    body = (
      <div
        data-visual-case={cid}
        className="flex flex-col bg-layer-canvas"
        style={{ width: phone ? 390 : 540, height: surface === "agent-chat-empty" ? 480 : 680 }}
      >
        <ParityExtWave3bAgentChatTab agentId={fx.agent.id} />
      </div>
    );
  } else if (surface === "agent-env-vars") {
    body = (
      <div
        data-visual-case={cid}
        className="bg-layer-canvas p-5"
        style={{ width: 520 }}
      >
        <ParityExtWave3bEnvVarsSection agent={fx.agent as never} canManageAgent={false} />
      </div>
    );
  } else if (surface === "agent-reminders" || surface === "agent-reminders-empty") {
    body = (
      <div
        data-visual-case={cid}
        className="flex flex-col bg-layer-canvas"
        style={{ width: 520, height: 420 }}
      >
        <AgentRemindersSection
          reminders={surface === "agent-reminders-empty" ? [] : (fx.reminders as never)}
          loading={false}
          error={null}
          variant="tab"
        />
      </div>
    );
  } else if (surface === "computer-workspaces") {
    body = (
      <div
        data-visual-case={cid}
        className="bg-layer-canvas"
        style={{ width: 600 }}
      >
        <ParityExtWave3bWorkspacesSection machineId={fx.machine.id} canManageMachines={true} />
      </div>
    );
  } else if (surface === "computer-agent-rows") {
    const compAgents = fx.computerAgents.map((ca) => {
      const ds = (activities as Record<string, { activity?: string; activityDetail?: string }>)[ca.id];
      return {
        agent: ca,
        displayState: {
          activity: (ds?.activity ?? "offline") as never,
          activityDetail: ds?.activityDetail ?? null,
          activityDetailKind: "other" as const,
          likelyOnline: false,
          blocked: null,
        },
      };
    });
    body = (
      <div
        data-visual-case={cid}
        className="bg-layer-canvas p-5"
        style={{ width: phone ? 390 : 640 }}
      >
        <ParityExtWave3bSectionHeader label="Agents on this computer" count={compAgents.length} />
        <div className="mt-3">
          <ListRowGroup>
            {compAgents.map(({ agent, displayState }) => (
              <ParityExtWave3bMachineAgentRow
                key={agent.id}
                agent={agent as never}
                displayState={displayState as never}
                selectionMode={false}
                selected={false}
                canManageMachines={false}
                onToggleSelection={() => undefined}
                onOpenAgent={() => undefined}
              />
            ))}
          </ListRowGroup>
        </div>
      </div>
    );
  } else if (surface === "computer-service") {
    const cmds = getParityExtWave3bCommands(fx.machine.id, fx.server.slug, false);
    body = (
      <div
        data-visual-case={cid}
        className="bg-layer-canvas p-5"
        style={{ width: 640 }}
      >
        <ParityExtWave3bServiceCard
          machine={fx.machine as never}
          computerOperationProgress={null}
          handleComputerRestartClick={() => undefined}
          cardState={{ kind: "upToDate" } as never}
          versionTier={"current" as never}
          webUpgradeOn={false}
          upgradeRefusal={null}
          recommendRepair={false}
          upgradeRequest={null}
          requestOutcomeStillTrue={false}
          upgradeFailureHint={null}
          handleRemoteUpgradeV2Click={() => undefined}
          computerFreshInstallCommands={cmds}
          statusCommand={<code>raft-computer status</code>}
          noResponseLine={null}
          releaseNotesForUpdate={null}
          windowsMachine={false}
          copiedCommand={null}
          handleCopy={() => undefined}
          machineComputerCommands={cmds}
          terminalRestartCommand={cmds.restart}
        />
      </div>
    );
  } else if (surface === "channel-files" || surface === "channel-files-empty") {
    body = (
      <div
        data-visual-case={cid}
        className="flex flex-col bg-layer-canvas"
        style={{ width: phone ? 390 : 640, height: 360, overflow: "hidden" }}
      >
        <ChannelFilesPanel channel={fx.channel as never} />
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
      {body}
    </main>
  );
}

function parityExtLegacyWave3bElement(): ParityExtWave3bElement | null {
  const raw = new URLSearchParams(window.location.search).get("case") ?? "";
  const match = /^components\.legacy-wave3b\.([\w-]+)\.(desktop|phone)\.(brutal|elegant-dark)$/.exec(raw);
  if (!match) return null;
  const [, surface, platform] = match;
  return (
    <ParityExtWave3bHost
      cid={raw}
      surface={surface}
      platform={platform as "desktop" | "phone"}
    />
  );
}
