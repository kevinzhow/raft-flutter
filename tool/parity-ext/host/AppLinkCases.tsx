import { parseLinkCardReadAnswer as parityExtParseLinkCardAnswer } from "@botiverse/raft-shared/src/appLinkPreview";
import { MessageItemBody as ParityExtLinkMessageBody } from "@botiverse/raft-ui";
import parityExtLinkFixture from "virtual:parity-ext/app-links";
import ParityExtLinkToasts from "../src/components/LocalizedToastProvider";
import ParityExtMessageLinkUnavailable from "../src/components/deeplinks/MessageLinkUnavailable";
import {
  LinkPreviewCardSkeleton as ParityExtLinkSkeleton,
  LinkPreviewConsentPrompt as ParityExtLinkConsent,
} from "../src/components/message/LinkPreviewConsentPrompt";
import { MessageMarkdownBody as ParityExtLinkMarkdown } from "../src/components/message/MessageMarkdownBody";
import {
  MessageLinkCardsProvider as ParityExtLinkProvider,
  type MessageLinkCard as ParityExtLinkResult,
} from "../src/components/message/useMessageLinkCards";
import { readLinkCardAnswer as parityExtReadLinkCardAnswer } from "../src/components/message/useAppLinkPreviews";
import {
  getMessageBodyFontSizeClass as parityExtLinkSizeClass,
  getMessageBodyFontSizeStyle as parityExtLinkSizeStyle,
} from "../src/store/appearanceStore";

function parityExtAppLinkElement() {
  const id = new URLSearchParams(window.location.search).get("case") ?? "";
  const match = /^components\.app-links\.(block-chip|undo|consent|consent-failed|loading|unavailable)\.(desktop|phone)\.(brutal|elegant-dark)$/.exec(id);
  if (!match) return null;
  const [, name, platform] = match;
  const { url, app, answer, messageId, serverId, viewerId, channelId } = parityExtLinkFixture;
  const result = parityExtReadLinkCardAnswer(parityExtParseLinkCardAnswer(answer), answer).results.get(url);
  if (result?.kind !== "card" || !result.cardV2) throw new Error("Missing app-link fixture card");
  const card = {
    ...result,
    view: {
      key: `${viewerId}:${serverId}|${messageId}`,
      messageId,
      reread: async () => ({ kind: "unshown" as const }),
      beginExecute: () => { throw new Error("Parity fixture must not execute a card"); },
    },
  };
  const block = name === "block-chip" || name === "undo";
  const data = block ? card : { kind: "consent" as const, app, url };
  const links = new Map<string, ParityExtLinkResult>([
    [url, { kind: "app", url, state: data.kind, data }],
  ]);
  const content = `See ${url}`;
  const ignoreNav = () => {};
  return (
    <div
      data-visual-case={id}
      className={name === "unavailable" ? "flex bg-layer-canvas" : "bg-layer-canvas p-4"}
      style={{ width: platform === "phone" ? 390 : name === "undo" ? 800 : 640, height: 320 }}
    >
      {name === "unavailable" ? <ParityExtMessageLinkUnavailable backTo="/visual-testing.html" /> : (
        <ParityExtLinkToasts>
          <div className={block ? "" : "flex flex-col gap-2"}>
            <ParityExtLinkMessageBody className={parityExtLinkSizeClass("md")} style={parityExtLinkSizeStyle("md")}>
              <ParityExtLinkProvider value={links} blocks={block ? new Map([[url, card]]) : undefined} blocksIn={content}>
                <ParityExtLinkMarkdown
                  content={content}
                  channels={[]}
                  mentionMap={new Map()}
                  structuredMentionMap={new Map()}
                  onNavigateChannel={ignoreNav}
                  onNavigateDm={ignoreNav}
                  onNavigateAgent={ignoreNav}
                  onNavigateHuman={ignoreNav}
                  onNavigateExternal={ignoreNav}
                  timeFormatOptions={{}}
                  readReceiptChannelId={channelId}
                  readReceiptMessageSeq={undefined}
                  readReceiptEnabled={false}
                />
              </ParityExtLinkProvider>
            </ParityExtLinkMessageBody>
            {!block && (name === "loading" ? <ParityExtLinkSkeleton />
              : <ParityExtLinkConsent app={app} state={name === "consent-failed" ? "failed" : "idle"}
                  onAllow={() => {}} onDecline={() => {}} />)}
          </div>
        </ParityExtLinkToasts>
      )}
    </div>
  );
}
