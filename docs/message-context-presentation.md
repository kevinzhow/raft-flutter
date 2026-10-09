# Message context presentation

Authority is raft-source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, Web 1.17.5. Product Source, original99 cases, thresholds and React baselines are unchanged.

## Accepted windows and navigation

Source `packages/web/src/store/messageStore.ts:2374–2411` focuses a target in its compatible current bucket without GET, otherwise leaves the same channel's accepted rows visible during the context request. `ChatPanel.tsx:217–235` projects the selected channel bucket: another channel's private rows must not be retained. The context response publishes messages, thread summaries, pagination, loading and canonical target together (`messageStore.ts:2425–2460`).

The controller follows this boundary. Same-channel pending context retains accepted rows. Cross-channel unknown context suppresses cached latest rows until acceptance. Compatible accepted cached targets skip GET. Late success and failure are rejected after a newer message window, navigation, principal/server change or channel revocation. A missing canonical parent cannot publish partial parent rows. Missing ordinary context falls back to latest and clears focus; late errors cannot launch that fallback for a newer request.

`jumpToMessage`, `selectChannel` and `openThread` accept `navigate: false` for a preview whose owning URI is already installed. An Activity/Search preview keeps its outer route. Default channel jumps install the channel/DM route and `msg`; default thread opening installs the `thread=channel:parent` anchor and optional focused reply. The navigation revision fences data requests independently of their channel generation.

Source's canonical-thread branch opens the canonical reply and reloads the outer channel tail (`messageStore.ts:2412–2423`). The controller resolves the parent as a separate ThreadPanel record, opens the canonical reply, then requests the outer channel tail. The parent context never replaces or expands the outer bucket. Same-channel accepted rows and reply focus survive the delayed tail request; accepting the tail replaces only the outer window. A stale tail cannot alter newer navigation; a transient tail failure preserves the open thread and reply focus. Parent lookup precedes thread resolution in this controller because its current thread view requires the real parent record, whereas Source mounts the thread identity immediately and lets ThreadPanel fetch that record separately.

## First visible paint

Source `MessageTimeline.tsx:595–648, 650–727, 990–1042` centers explicit targets using actual DOM geometry and keeps list anchors through accepted replacements. `ChatPanel.tsx:581–597` clears the highlight after 2000 ms.

The Flutter candidate window is staged with painting, pointer input and semantics disabled while the old accepted live list remains mounted and painted. A temporary hidden layout measures the bounded accepted window. That finite height is supplied as the cache extent, then Flyer's existing animated message sliver is restored before publication. Actual `RenderAbstractViewport.getOffsetToReveal(row, .5)` geometry centers the target. The candidate is published only after that layout is visible within the real clip. This preserves the SDK sliver contract and avoids infinite semantic rectangles, estimated offsets, screenshots or an eight-step visible retry sequence.

The old timeline's header parameters are captured with its accepted widget. New context metadata cannot alter its header height while the candidate is hidden. The two-second highlight expiry changes paint without moving the message.

## Back to bottom and read admission

Source `ChatPanel.tsx:599–616, 634, 654–683, 1290–1292, 1514–1525` counts small live appends while away from the end, uses server unread count in unloaded-newer history, and reloads latest before returning to the end. The shared outline button is centered 12 px above the timeline bottom, with its Source ArrowDown, size, text and padding. The close-to-bottom threshold is 100 px (`MessageTimeline.tsx:254`).

When newer history is unloaded, `returnToLatest` retains the accepted context while the real latest GET is pending and bypasses cached tail publication. The accepted latest window replaces that context and is laid out at its actual end before publication. Read requests require the actual channel/DM/thread URI plus mounted panel/tab visibility, foreground and current accepted window. Hidden cached channel data alone cannot send or accept a receipt; visible Activity/Search conversation previews are admitted.

## Evidence

`chat_focus_receipt_test.dart` observes every sampled frame of the actual mounted chat in Brutal light, Elegant light and Elegant dark. It holds the actual context response, checks unchanged old-row coordinates, verifies the target's first visible center within 0.5 px and unchanged subsequent coordinates, checks highlight persistence/expiry, then holds and releases the actual latest request and checks the real final extent. `message_context_transition_test.dart` checks atomic listener projections, cross-channel cache suppression, cached fast path, canonical replies/parent failure, navigation, revocation, late success/failure and preview read admission. The old observer-mock retry tests are retained privately in `.local/chat_focus_receipt_retry_contract.dart.txt` for comparison.

Private receipts are in `.local/message-jump-contract-complete.log` (62/62), `.local/message-jump-history-highlight.log` (23/23), `.local/message-jump-canonical-tail.log` and `.local/message-jump-analysis-canonical.log`. Intermediate failures are retained, including the finite-layout correction and header movement found by the new frame assertions. These tests use real product widgets and controller/client fixture transport; no native, full visual suite or production-server flow is claimed here. The root integration owns paired Source/Flutter process captures and native consolidation.
