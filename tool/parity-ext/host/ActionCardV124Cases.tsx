import type { ActionCardMetadata as ParityExtCardMetadata } from "@botiverse/raft-shared";
import parityExtCardFixture from "virtual:parity-ext/action-cards-v124";
import parityExtCardApi from "../src/api/client";
import { ActionCard as ParityExtActionCard } from "../src/components/actions/ActionCard";
import { useAgentStore as useParityExtCardAgents } from "../src/store/agentStore";
import { useAuthStore as useParityExtCardAuth } from "../src/store/authStore";
import { useChannelStore as useParityExtCardChannels } from "../src/store/channelStore";
import { useMachineStore as useParityExtCardMachines } from "../src/store/machineStore";
import { useMessageStore as useParityExtCardMessages } from "../src/store/messageStore";
import { useServerStore as useParityExtCardServer } from "../src/store/serverStore";
import { useState as useParityExtCardState } from "react";

function ParityExtActionCardFrame({ id, name, width }: { id: string; name: string; width: number }) {
  const fixture = parityExtCardFixture;
  const metadata = fixture.cards[name] as ParityExtCardMetadata;
  useParityExtCardState(() => {
    const { user, server, members, agent, computer, channel, messageId } = fixture;
    const message = { id: messageId, channelId: channel.id, senderType: "agent", senderId: agent.id, actionMetadata: metadata };
    useParityExtCardAuth.setState({ user } as never);
    useParityExtCardServer.setState({ current: server, members } as never);
    useParityExtCardAgents.setState({ agents: [agent] } as never);
    useParityExtCardMachines.setState({ machines: [computer] } as never);
    useParityExtCardChannels.setState({ channels: [channel], dmChannels: [] } as never);
    useParityExtCardMessages.setState({
      currentChannelId: channel.id,
      channelMessages: { [channel.id]: [message] },
      messages: [message],
    } as never);
    const get = parityExtCardApi.get.bind(parityExtCardApi);
    parityExtCardApi.get = ((path, config) =>
      path === `/mcp/servers/${fixture.mcp.mcpServerId}/connection-authorization`
        ? Promise.resolve({ data: fixture.mcp })
        : get(path, config)) as typeof parityExtCardApi.get;
    return true;
  });
  return (
    <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
      <div data-visual-case={id} className="flex flex-col gap-4 p-4" style={{ width }}>
        <div className="flex min-w-0 gap-3">
          <div className="size-9 shrink-0 rounded-full bg-fill-muted" aria-hidden="true" />
          <div className="min-w-0 flex-1">
            <div className="flex items-baseline gap-2 text-sm">
              <span className="font-semibold">{fixture.agent.displayName}</span>
              <span className="text-xs text-foreground-hint">09:41</span>
            </div>
            <ParityExtActionCard messageId={fixture.messageId} metadata={metadata} channelId={fixture.channel.id} />
          </div>
        </div>
      </div>
    </main>
  );
}

function parityExtActionCardElement() {
  const id = new URLSearchParams(window.location.search).get("case") ?? "";
  const match = /^components\.action-card-v124\.([\w-]+)\.(desktop|phone)\.(brutal|elegant-dark)$/.exec(id);
  if (!match) return null;
  const [, variant, platform] = match;
  const name = variant === "question-single-other" || variant === "question-single-undo"
    ? "question-single"
    : variant;
  if (!Object.hasOwn(parityExtCardFixture.cards, name)) return null;
  return <ParityExtActionCardFrame id={id} name={name} width={platform === "phone" ? 390 : 640} />;
}
