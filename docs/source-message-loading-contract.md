# Message loading and entity hydration contract

This is a source audit and an implementation/test handoff, not runtime parity
evidence. Source is pinned to
`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` (Web 1.17.5,
raft-ui 0.5.27). Flutter was read at child commit `2c3b53b`; the five compared
controller/detail files were also unchanged in integration HEAD `9bcf512`.
No product code, Source fixture, baseline, native device or API account changed.

Source references below are paths relative to the pinned repository:
[browse the pinned Web source](https://github.com/botiverse/raft-source/tree/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src).
Flutter references are paths relative to this repository. Line intervals identify
the inspected implementation, not a promise about later commits.

## Accepted window and pending intent are separate

`packages/web/src/store/messageStore.ts:643–655` gives every window request an
ownership generation; acceptance requires both that generation and the current
channel. `packages/web/src/components/message/ChatPanel.tsx:217–235` selects the
channel's bucket and metadata rather than displaying the global message array.
Old content is retained only for the selected channel, never borrowed from the
previous channel while a new channel loads.

| Event | Source state and visible result | Exact Source implementation |
| --- | --- | --- |
| Focus a target already in this channel's cached bucket | Activate that bucket and its pagination metadata, loading false, highlight requested ID; no context GET. | `packages/web/src/store/messageStore.ts:2374–2392`, cached window fields `714–732` |
| Focus an uncached target | Claim request; set loading and requested highlight; retain the channel's accepted bucket. If it has rows, the existing timeline stays mounted during the request. | `packages/web/src/store/messageStore.ts:2393–2411`; `packages/web/src/components/message/ChatPanel.tsx:1484–1512` |
| Accept a context response | Normalize rows, hydrate bundled thread summaries first, then set the bucket, active messages, loading false, older/newer flags, error reset and **response targetMessageId** (or requested ID) together. | `packages/web/src/store/messageStore.ts:2425–2460` |
| Response canonicalizes to a thread | Open canonical parent/focused reply through threadStore; if still owned, load the channel tail. This is a distinct branch. | `packages/web/src/store/messageStore.ts:2412–2423` |
| Context fails | Clear requested highlight and loading only if still owned, load tail under a new generation, then distinguish history cutoff from not-found. | `packages/web/src/store/messageStore.ts:2461–2486` |
| Older/newer request | Retain the window while the directional load is pending. Newer uses after=maxSeq, 50 rows and bundled summaries, with hasNewer based on returned count. | `packages/web/src/store/messageStore.ts:1864–1926`, `1930–1997` |

“Atomic” here means the accepted window fields are one messageStore update and
bundled summaries already exist when message rows first commit. It does not mean
all unrelated stores or network calls share a transaction.

## Position, highlight, arrivals and returning to the tail

`packages/web/src/components/message/ChatPanel.tsx:581–597` waits until the target
exists, schedules **center** alignment, and clears the temporary highlight after
**2000ms**. Cleanup cancels both scheduled frame and timer on dependency changes.
`packages/web/src/components/message/MessageTimeline.tsx:595–648` distinguishes
initial explicit focus (center, stop following) from saved reading position
(start, stop following) and normal entry (tail, follow).

The timeline classifies mutations before paint: prepend preserves the live
message/offset anchor; append follows only with existing follow/send intent and
no truncated newer window; a full replacement centers a present focus target,
otherwise respects tail-follow intent. See
`packages/web/src/components/message/MessageTimeline.tsx:650–727`.
Imperative bottom navigation clears saved scroll memory and arms following;
focus uses the real item's scrollIntoView, default center (`990–1042`).

Arrivals are not a generic “always jump” rule:

- Source keeps a contiguous context segment. An arrival beyond a newer-history
  gap advances sequence/unread state without appending a disconnected row;
  existing-row updates still merge. See
  `packages/web/src/store/messageStore.ts:2043–2062`, `2095–2108`.
- Off-bottom badge counting tracks increases of at most five rows and resets
  at bottom. First accepted list establishes the count baseline. See
  `packages/web/src/components/message/ChatPanel.tsx:599–640`.
- Back-to-bottom with hasNewer clears highlight/count, exits context, reloads
  the tail and scrolls after loading settles. With a live tail, it just scrolls.
  The button uses server unread count for hasNewer and local new-row count
  otherwise. See `packages/web/src/components/message/ChatPanel.tsx:654–683`,
  `1290–1292`; exit bookkeeping is
  `packages/web/src/store/messageStore.ts:2001–2024`.
- Returning from another conversation tab follows the tail only when there is
  no newer-history gap (`packages/web/src/components/message/ChatPanel.tsx:618–628`).
  Sending clears context focus and arms next-append follow (`685–700`).

## Cold loading retains the appropriate shell

For a **known channel**, header and eligible tabs precede the message-body load
branch; the composer/join footer follows it and is controlled by membership,
read-only and tab eligibility, not by message loading. An empty pending bucket
shows the mounted Loading text; an accepted nonempty bucket retains its timeline.
See `packages/web/src/components/message/ChatPanel.tsx:1345–1409`,
`1458–1478`, `1484–1534`. No full-page spinner or artificial message skeleton is
specified here. Unknown channel/DM identity resolution is a different surface:
`packages/web/src/components/layout/MainLayout.tsx:425–440`, `452–490` keeps a
loading-channel placeholder until resolution is exhausted. The null-channel
select state is not the pre-resolution first frame (`ChatPanel.tsx:1208–1216`).

Entity hydration differs by presentation. It must not be collapsed into one
invented loading screenshot:

| Surface | Source's first usable frame / pending behavior | Exact Source implementation |
| --- | --- | --- |
| Agent/human connected profile overlay or embedded profile | Resolve current store row or viewer-server-keyed projection cache immediately. If unresolved, keep ProfilePanel + empty-title PanelHeader + operational back/close and a quiet body Loading. No entity facts or profile tabs until accepted data passes the render guard. Key/cancellation keeps old target responses invisible. | `packages/web/src/components/profile/ProfilePanel.tsx:67–172`, `208–238`, `267–291`, `316–345`, `349–401` |
| Agent detail availability | Full local profile requires actual id/name/status/runtime/model and not deleted; bounded public/remote projections have their own explicit guard, without synthesizing private facts. | `packages/web/src/components/agent/agentDetailAvailability.ts:3–42` |
| Human profile | Live membership can render immediately; fallback supplies detail fields, live member wins conflicts. Live-only projection intentionally initializes membershipStatus active and createdAgents empty. | `packages/web/src/components/member/resolveHumanProfile.ts:4–17` |
| Dedicated Agent route | Uses current store/cached projection; missing/incomplete data goes to AgentUnavailablePanel. This route does **not** implement the connected overlay's hydration skeleton. | `packages/web/src/components/layout/MainLayout.tsx:547–558` |
| Dedicated Computer route | Reads the hydrated machine store; missing machine renders Computer not found; a present row supplies real data directly to MachineDetailPanel. No ID-only placeholder machine. | `packages/web/src/components/layout/MainLayout.tsx:569–580`; actual header/status `packages/web/src/components/machine/MachineDetailPanel.tsx:1034–1065` |
| Dedicated Human route | Live/fallback resolved row renders detail; fallback-loading renders PanelFallback. Its effect starts after render, so it differs from the connected overlay first-frame guarantee. | `packages/web/src/components/layout/MainLayout.tsx:595–648` |
| Agent list hydration/refresh | Initial loading starts true. Refresh does not reset it to true or discard accepted rows; epoch fences stale snapshots. Hydrates actual agent and activity state together, preserving newer live activity. | `packages/web/src/store/agentStore.ts:749–839` |
| Computer list hydration/refresh | Initial/no-row retry enters loading; refresh retains rows. Request keyed by server+epoch, status hydration precedes loaded state. Failure retains accepted rows or exposes error if none. Mobile initial list is four SkeletonRows below real header. | `packages/web/src/store/machineStore.ts:265–305`; `packages/web/src/components/machine/MobileComputersPanel.tsx:59–98` |
| Membership hydration | Server switch clears members and triggers load; server epoch prevents cross-server result acceptance. No persistent old-server profile facts. | `packages/web/src/store/serverStore.ts:375–395`, `654–668` |

## Flutter comparison and coherent repair boundaries

| Actual Flutter path | Current behavior / consequence | Repair boundary |
| --- | --- | --- |
| `apps/raft_flutter/lib/data/workspace_controller.dart:1854–1939` | Same-channel jump retains visibleIds while GET pending; latest generation fences success. Always fetches even a cached target; accepted response never reads targetMessageId. Failure catch writes error without a current-window check, then only final loading reset is fenced. No Source-style fallback-tail/context error classification. | One accepted-window state plus independently owned pending navigation intent; generation fence success **and** failure. Cache hit, canonical target, fallback and read projection need one transition contract. |
| `apps/raft_flutter/lib/features/chat_view.dart:443–463`, `498–550`, `551–652` | Context acceptance creates a new keyed adapter/list and viewport. Rows are focused after list layout with bounded retries; both reveal calls use .3 instead of Source center. | Keep the existing observer/disposal safety, but derive position from the accepted intent. Test every pending/accept frame and real row geometry, not just final hitTestable. |
| `apps/raft_flutter/lib/features/chat_view.dart:1535`, `1636`, controller highlightedMessageId assignments | Highlight is rendered from the controller ID, with no two-second expiry in these paths. | Separate temporary paint lifetime from retained focus/navigation intent; timer ownership must survive stale results and deactivate on close/switch. |
| `apps/raft_flutter/lib/features/chat_view.dart:1729–1871`, `1910–1928` | Timeline and composer remain mounted; cold empty list shows Loading text. Header lives in WorkspaceView, not ChatView. Global bootstrap (`workspace_view.dart:670–674`) can instead replace route content with a spinner. | Distinguish missing channel identity, empty pending window, and refreshing accepted window. Do not gate the entire known-channel shell on general bootstrap. |
| `apps/raft_flutter/lib/data/workspace_controller.dart:1430–1536`, `1695–1702`, `2124–2143` | Selecting a channel drops context visibleIds, merges/reconciles tail with retained history; sending from hasNewer refreshes first. Socket arrivals are hidden whenever hasNewer, including a contiguous next row. No directional newer loader or Source back-to-bottom badge/control was found in controller/chat host. | Represent tail/context, older/newer flags, retained rows, follow intent and unread separately; add Source's explicit return-to-tail and newer-page operations. |
| `apps/raft_flutter/lib/features/workspace_view.dart:1368–1391` → `fleet_views.dart:413`, `476–543`, `871–939` | Desktop Agent/Computer selection passes **only id** as initial; FleetDetail immediately renders full detail from it while GET is pending. Agent defaults can show offline/default model/unassigned facts before actual data. Directory entry passes a genuine row and does have useful immediate data. | Allow a validated real cached/list projection; otherwise render source-appropriate unresolved shell. ID-only is navigation identity, never accepted profile data. Keep refresh retention and permission revocation. |
| `apps/raft_flutter/lib/features/member_profile_view.dart:34–68`, `138–196`; `management_support.dart:41–57`, `96–127` | Human always starts from empty profile and GET, while header/back exist. It cannot immediately reuse a live member or scope cache, unlike Source; refresh retains current data and accepts with authority fence. | Scoped entity store/projection resolver separate from shell; preserve existing request/authority fences and merge current membership with details. |

Suggested model: `acceptedWindow(scope, rows, bundledSummaries, pagination,
historyLimit)` + `pendingIntent(token, target, kind)` + `positionIntent` +
`temporaryHighlight(owner, id, deadline)` + separate read/unread projection.
Entity detail similarly separates `target(scope,id)` from `acceptedProjection`
and `requestStatus`. These are proposed Flutter boundaries, not names or extra
APIs asserted to exist in Source.

## State-sequence acceptance tests to implement

Use controlled request completers and record each listener notification and
pumped frame. Use Source transitions above as assertions; test all three real
themes only for paint/input variants. No arbitrary timing delay or fake fixture
snapshot replaces the transition checks.

1. **Cached focus:** request present row; context GET count remains zero,
   accepted bucket/summaries/pagination unchanged; actual row centers.
2. **Delayed same-channel focus:** old rows and scroll anchor remain visible
   before response; header/tabs/composer remain interactive. Accept a disjoint
   window with bundled replies and a different canonical targetMessageId. First
   new-row frame has replies, correct metadata and target; no empty/parent-only
   intermediate frame. Target center uses actual viewport and row bounds.
3. **Highlight lifetime:** accepted target is highlighted before 2000ms and
   unhighlighted after the owned timer fires; switching channel/target cancels
   old timers. A retained focus reference cannot suppress ordinary follow mode
   forever after paint expires.
4. **Latest request wins:** A then B; complete B then A, including A failure.
   No A row, error, loading reset, focus or scroll operation reaches B. Repeat
   across principal/server/permission change.
5. **Context failure:** preserve accepted rows while fallback tail is pending;
   accept tail and distinguish missing target from plan history cutoff. Stale
   fallback must not replace a newer navigation.
6. **Back to bottom:** hasNewer context, actual control click, focus removed,
   no duplicate context load, old window retained while tail pending, accepted
   tail then bottom/follow. Simulate arrival during the request and after it.
7. **Arrivals and paging:** off-bottom live arrival retains reading anchor and
   updates badge; own send arms follow; distant context arrival updates unread
   without a gap row; contiguous next context row can append; older prepend
   and newer append preserve the Source position rules.
8. **Cold channel:** unresolved identity uses loading-channel state; known
   channel with pending empty bucket renders header/eligible tabs/input and
   Loading body. A failed resolved empty bucket shows the appropriate terminal
   state rather than flashing select-channel or old-channel content.
9. **Entity first frame:** ID-only Agent/Computer never paints invented status,
   model or unassigned facts. Real list/cached projection paints immediately
   while refresh is pending; target switch hides old projection synchronously.
   Test overlay and dedicated route separately because Source differs.
10. **Member hydration:** live membership renders while profile GET pending;
    accepted profile enriches details while live role wins. Server/role switch
    cancels stale detail; transient refresh failure retains accepted public
    facts, with no false-success empty result.

Existing `apps/raft_flutter/test/chat_jump_test.dart:162–389` covers eventual
variable-height context visibility, observer replacement and history-offset
repair. It does not certify cached no-request behavior, every pending/accept
frame, canonical target, center, timed highlight or return-to-bottom. The tests
above are a proposal and were **not run** by this audit. Native use-case evidence
and immutable paired captures should follow the state-model implementation.
