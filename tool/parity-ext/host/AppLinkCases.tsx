import parityExtLinkFixture from "virtual:parity-ext/app-links";
import { AppLinkBlockCard as ParityExtLinkBlock } from "../src/components/message/AppLinkBlockCard";
import { AppLinkChip as ParityExtLinkChip } from "../src/components/message/AppLinkChip";
import {
  LinkPreviewCardSkeleton as ParityExtLinkSkeleton,
  LinkPreviewConsentPrompt as ParityExtLinkConsent,
} from "../src/components/message/LinkPreviewConsentPrompt";
import { readLinkCardAnswer as parityExtReadLinkCardAnswer } from "../src/components/message/useAppLinkPreviews";

function parityExtAppLinkElement() {
  const id = new URLSearchParams(window.location.search).get("case") ?? "";
  const match = /^components\.app-links\.(block-chip|consent|consent-failed|loading)\.(desktop|phone)\.(brutal|elegant-dark)$/.exec(id);
  if (!match) return null;
  const [, name, platform] = match;
  const { url, app, answer, messageId, serverId, viewerId } = parityExtLinkFixture;
  const result = parityExtReadLinkCardAnswer(answer.items, answer).results.get(url);
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
  const block = name === "block-chip";
  return (
    <div
      data-visual-case={id}
      className="flex flex-col gap-2 bg-layer-canvas p-4 font-sans text-body text-foreground"
      style={{ width: platform === "phone" ? 390 : 640, height: 320 }}
    >
      <p className="m-0 leading-[1.45]">
        See{" "}{block ? <ParityExtLinkChip result={card} /> : <a href={url} className="underline">{url}</a>}
      </p>
      {block ? <ParityExtLinkBlock result={card} />
        : name === "loading" ? <ParityExtLinkSkeleton />
        : <ParityExtLinkConsent app={app} state={name === "consent-failed" ? "failed" : "idle"}
            onAllow={() => {}} onDecline={() => {}} />}
    </div>
  );
}
