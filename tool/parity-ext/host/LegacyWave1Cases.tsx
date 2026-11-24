// raft-flutter parity EXTENSION cases: Wave 1 legacy UI migration surfaces
// (TaskHandoffCard, non-spec UnknownActionCard, QuotedMessageSkeleton,
// InlineAudioAttachmentCard, ForwardComposerDesktop).
import type { ActionCardMetadata as ParityExtWave1CardMetadata, ParsedRaftPermalink as ParityExtWave1Permalink } from "@botiverse/raft-shared";
import type { ReactElement as ParityExtWave1Element } from "react";
import { useState as useParityExtWave1State } from "react";
import parityExtWave1Fixture from "virtual:parity-ext/legacy-wave1";
import parityExtWave1Api from "../src/api/client";
import { ActionCard as ParityExtWave1ActionCard } from "../src/components/actions/ActionCard";
import ParityExtWave1ForwardDialog from "../src/components/message/ForwardComposerDialog";
import ParityExtWave1QuotedPreview from "../src/components/message/QuotedMessagePermalinkPreview";
import { TaskHandoffCard as ParityExtWave1TaskHandoffCard } from "../src/components/task/TaskHandoffCard";
import type { Channel as ParityExtWave1Channel } from "../src/store/channelStore";
import type { Message as ParityExtWave1Message } from "../src/store/messageStore";
import { useAgentStore as useParityExtWave1Agents } from "../src/store/agentStore";
import { useAuthStore as useParityExtWave1Auth } from "../src/store/authStore";
import { useChannelStore as useParityExtWave1Channels } from "../src/store/channelStore";
import { useMessageStore as useParityExtWave1Messages } from "../src/store/messageStore";
import { useServerStore as useParityExtWave1Server } from "../src/store/serverStore";
import { useTranslationStore as useParityExtWave1Translation } from "../src/store/translationStore";

function parityExtWave1PrimeStores(surface: string) {
  const fx = parityExtWave1Fixture;
  useParityExtWave1Auth.setState({ user: fx.user } as never);
  useParityExtWave1Server.setState({ current: fx.server, members: fx.members } as never);
  useParityExtWave1Agents.setState({ agents: fx.agents } as never);
  useParityExtWave1Translation.setState({
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
  useParityExtWave1Channels.setState({
    channels: fx.channels,
    dmChannels: [],
    loungeChannels: [],
    currentChannelId: fx.channels[0].id,
  } as never);
  useParityExtWave1Messages.setState({
    currentChannelId: fx.channels[0].id,
    channelMessages: { [fx.channels[0].id]: [fx.forwardMessage] },
    messages: [fx.forwardMessage],
  } as never);

  const origGet = parityExtWave1Api.get.bind(parityExtWave1Api);
  parityExtWave1Api.get = ((path: string, config?: unknown) => {
    if (path.startsWith("/messages/context/")) {
      return new Promise(() => undefined);
    }
    if (surface === "inline-audio-failed" && path.includes("/attachments/") && path.includes("/url")) {
      return Promise.reject(new Error("Audio load failed"));
    }
    if (path.startsWith("/channels/forward-targets") || path.includes("forward")) {
      return Promise.resolve({ data: { conversations: [], channels: fx.channels } });
    }
    return origGet(path, config as never);
  }) as typeof parityExtWave1Api.get;
}

function ParityExtWave1View({ id, surface, width }: { id: string; surface: string; width: number }) {
  const fx = parityExtWave1Fixture;
  useParityExtWave1State(() => {
    parityExtWave1PrimeStores(surface);
    return true;
  });

  if (surface === "forward-desktop") {
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <ParityExtWave1ForwardDialog
          sourceMessages={[fx.forwardMessage as unknown as ParityExtWave1Message]}
          sourceChannel={fx.channels[0] as unknown as ParityExtWave1Channel}
          onClose={() => undefined}
          onSent={() => undefined}
        />
      </main>
    );
  }

  if (surface === "inline-audio" || surface === "inline-audio-failed") {
    const ready = surface === "inline-audio";
    const audioMessage = {
      id: ready ? "msg-audio-ready-wave1" : "msg-audio-failed-wave1",
      seq: 1,
      serverId: fx.server.id,
      channelId: fx.channels[0].id,
      messageType: "chat",
      senderType: "agent",
      senderId: fx.agents[0].id,
      senderName: fx.agents[0].displayName,
      content: "",
      createdAt: "2026-06-22T09:41:00.000Z",
      attachments: [
        {
          id: ready ? fx.audio.readyAttachmentId : fx.audio.failedAttachmentId,
          filename: fx.audio.filename,
          mimeType: fx.audio.mimeType,
          sizeBytes: fx.audio.sizeBytes,
          localPreviewUrl: ready ? fx.audio.silentWavDataUrl : null,
        },
      ],
    } as unknown as ParityExtWave1Message;
    return (
      <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
        <div data-visual-case={id} className="bg-layer-canvas p-4" style={{ width }}>
          <MessageItem
            message={audioMessage}
            mentionMap={buildMentionMap(fx.agents as never, fx.members as never)}
            channels={fx.channels as never}
            previewSenderAgent={fx.agents[0] as never}
            hideThreadActions
          />
        </div>
      </main>
    );
  }

  let content: ParityExtWave1Element;
  if (surface === "task-handoff" || surface === "task-handoff-returned") {
    content = (
      <ParityExtWave1TaskHandoffCard
        message={{ id: fx.handoff.messageId }}
        notice={fx.handoff.notice as never}
        returned={surface === "task-handoff-returned" ? (fx.handoff.returned as never) : null}
        time={fx.handoff.time}
      />
    );
  } else if (surface === "action-card" || surface === "action-card-open") {
    content = (
      <ParityExtWave1ActionCard
        messageId="msg-unknown-action-wave1"
        metadata={fx.unknownActionCard as unknown as ParityExtWave1CardMetadata}
        channelId={fx.channels[0].id}
      />
    );
  } else {
    content = (
      <ParityExtWave1QuotedPreview
        permalink={fx.quotedPermalink as unknown as ParityExtWave1Permalink}
        onOpen={() => undefined}
      />
    );
  }

  return (
    <main className="min-h-screen bg-layer-canvas p-0 font-display text-foreground">
      <div data-visual-case={id} className="bg-layer-canvas p-4" style={{ width, boxSizing: "border-box" }}>
        {content}
      </div>
    </main>
  );
}

function parityExtLegacyWave1Element() {
  const id = new URLSearchParams(window.location.search).get("case") ?? "";
  const match = /^components\.legacy-wave1\.([\w-]+)\.(desktop|phone|dialog)\.(brutal|elegant-dark)$/.exec(id);
  if (!match) return null;
  const [, surface, name] = match;
  const width = name === "phone" ? 390 : name === "dialog" ? 1280 : 640;
  return <ParityExtWave1View id={id} surface={surface} width={width} />;
}
