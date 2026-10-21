# Field parity audit: server/Web wire shapes vs Flutter reads

Bug class: the server or Web moved a field or structure, and Flutter still reads the
old one, reads the wrong place, or falls back to a default that hides the problem.
Trigger: the Agent profile read legacy `fastMode` / `reasoningEffort` while Web reads
`runtimeConfig.mode.kind`.

Reference: raft-source `26f77ef` (same commit as `docs/source-reference.json`). The audit
compared server serializers (`packages/server/src`), shared contracts, and Web readers
(`packages/web/src`) against every Flutter read of the same entities. Verdicts: OK, stale
(reads a field the server no longer or never sends), wrong (wrong key / path / rule),
missing-fallback (Web has a fallback or field Flutter lacks), masked-default (Flutter
default hides missing data), unhandled-enum, unverified.

Totals over the six audit groups: 86 non-OK findings (20 wrong, 24 stale, 14
masked-default, 11 missing-fallback, 6 missing event/field, 3 unhandled-enum, 8
unverified), plus the agent runtime-config reads, which are owned by branch
`cindy/runtime-config-read` and only listed here as KNOWN. Detailed per-group tables
(Web path, Flutter path, effect, confidence) were produced for each group; the rows
below are the user-visible ones, ranked by impact.

Status: FIXED = changed on this branch with a fixture-backed test; LEFT = not changed
(reason given).

## Findings, ranked by user impact

| # | Entity | Field | Web | Flutter (before) | Verdict | User-visible effect | Status |
|---|---|---|---|---|---|---|---|
| 1 | agent | `activityDetailKind` on REST rows | `agentStore.ts:766` | read `row['detailKind']` (socket-only key) in `message_agent_presentation.dart`, `composer_directory.dart` | wrong | Wake-paused / delivery-unconsumed / terminal-failure agents show plain Online/Offline after any refresh | FIXED |
| 2 | agent | external agent presence from `lastSeenAt` (120 s) | `agentStore.ts:219-262` | sidebar, DM header, profile card, followers read `row['activity']` only | masked-default | External agents seen seconds ago show Offline in most surfaces | FIXED (not channel roster rows, see 33) |
| 3 | agent | activity text rules | `utils/activity.ts:75-134` | raw `activityDetail`, no ellipsis, raw JSON in error rows | wrong | "Error" rows show a JSON blob; Thinking/Online show detail text | FIXED (`agentActivityText`) |
| 4 | agent | `agent:activity` patch ordering | `agentActivityEvents.ts:283-371` | directory applied frames with no `serverSeq` gate, dropped kind | stale | Late frame regresses sidebar/profile status | FIXED |
| 5 | activity | DM row title / thread-in-DM subtitle | `ThreadsInbox.tsx:324-327` | titled with the raw DM handle (`channelName`) | wrong | Every DM in Activity shows the handle, not the display name | FIXED |
| 6 | activity | `firstMentionMessageId` gate for mentions-only alerts | not a gate | equality with the last message id (server sends the OLDEST unread mention, null on RisingWave path) | wrong | Mentions-only users miss background/desktop alerts | FIXED |
| 7 | member | remove / message / role gating by `membershipStatus`, owner/admin target rules, remote joint human | `HumanDetailPanel.tsx:200-241` | only excluded `left` | wrong | Enabled Remove/Message that the server refuses | FIXED (`member_profile_rules.dart`) |
| 8 | member | departure badge, Status row, `channel_summary` projection (hide Info/Created Agents, show source server) | `HumanDetailPanel.tsx:117-126,586` | never read | missing-fallback | Removed/left members look active; peer humans show empty "Created Agents" | FIXED (data and rules; Left/Removed badge on the identity header needs a raft_ui slot: LEFT) |
| 9 | server | `server:plan-updated` | `socketBridge.ts:1114-1122` | not handled | missing | Plan-dependent banners and billing stay stale after an upgrade until restart | FIXED (patch plan, notify, billing reloads) |
| 10 | thread | HTTP 404 on thread lookup | `threadStore.ts:80-100` | any 404 meant "empty thread" | wrong | Lost-access thread opens as an empty thread with a composer, no error/Retry | FIXED |
| 11 | channel | hidden `#all` in `channel:updated` | `channelDomain.ts:121-130` | merged as a private channel | wrong | `#all` stays in the sidebar as a lock channel after an admin hides it | FIXED |
| 12 | channel | `message_display_prefs:updated` | `socketBridge.ts:705-709` | only the open settings sheet | missing | "Collapse long messages" from another device not applied | FIXED |
| 13 | message | action card `sourceServerId: null` | `shared actionCards.ts:546-550` | null treated as same server | wrong | Confirm enabled on a card Web makes read-only; server error | FIXED |
| 14 | message | upload ceiling with direct upload enabled | `directAttachmentUpload.ts:331-366` | accepted `maxBytes` up to 200 MB, posted multipart (server caps 90 MB) | wrong | 90-200 MB files fail with 413 | FIXED (cap at 90 MB; direct-upload sessions LEFT) |
| 15 | message | provisional task chip keys (`taskClaimedByName`, `taskTitle`, `taskId`) | taskStore rows | keys the server never sends | stale | First-frame chip lacks assignee, shows message text as title | FIXED |
| 16 | message | optimistic `senderName` | `MessageInput.tsx:2122` | `user.name` | stale | Pending row shows handle, flips to display name on echo | FIXED |
| 17 | message | external sender subtitle (`externalAuthor.provider`) | `MessageItem.tsx:3000` | none | missing-fallback | Slack senders have no provider subtitle | FIXED |
| 18 | channel roster | `externalMembers`, joint peer badge / no Remove for peer members | `ChannelMembers.tsx:310-317,893-898` | never read | wrong | Slack participants missing from the count and list; Remove shown for peer-server members | FIXED (rows and gating; the name badge was LEFT until v1.21.12: one badge per server from `servers[]`, in the roster, the profile "From" line and the overflow strip's Slack count and tiles) |
| 19 | channel roster | agent presence | `ChannelMembers.tsx:60-72` | one-shot snapshot | wrong | Roster dots do not follow live activity / lastSeenAt | FIXED |
| 20 | feature flags | evaluate request: `platform`, `os`, `buildNumber`, `buildType` | `serverFeatureFlags.ts:140-146`, `featureFlagClientRules.ts:131-143` | 14 call sites, inconsistent platform, no client facts | missing-fallback | Client-rule flags never match; different surfaces evaluate differently | FIXED (`featureFlagEvaluateBody`; needs `--dart-define=RAFT_BUILD_NUMBER` in release builds for build rules) |
| 21 | agent | `serverRole` chip | `agentServerRoleDisplay.ts` | `admin ? Admin : Member` | unhandled-enum | Unknown role shows "Member" | FIXED |
| 22 | agent | migration state / `abortReason` / `agent:migration-updated` | `agentMigration/state.ts` | raw snake_case state, no realtime refresh | unhandled-enum / missing | Raw state text; stale progress | FIXED |
| 23 | member | `displayName || name` (empty string) | many | `?? name` in ~56 sites | masked-default | Blank titles for an empty stored displayName | FIXED centrally (`RaftRecord.name`, `RaftChannel.peerLabel`) and in the files touched; other `??` sites remain (LEFT) |
| 24 | member | human avatar (Gravatar, uploaded avatars preempt, ignore legacy provider URL) | `humanAvatar.ts:1-18` | raw `avatarUrl` | wrong | No Gravatar in profile header; legacy provider avatars drawn | LEFT in the profile header/hover card (needs a raft_ui avatar slot) |
| 25 | member | open a human profile as a guest | `ProfilePanel.tsx:151-156` | gated on `viewMembers` | wrong | Guest gets "Profile unavailable" | FIXED |
| 26 | member | guest role option when guest flag is off | `humanRoleTransitions.ts:11` | offered | wrong | Server rejects | FIXED |
| 27 | member | `preferredTimeFormat` null | `translationStore.ts:259` | shown as 12h, cannot reset | masked-default | Wrong state on Language & Region | FIXED |
| 28 | activity | thread row task badge `#N @claimant` and live update | `ThreadsInbox.tsx:482-489` | status pill only | stale | Missing number/assignee | PARTIAL (text beside the pill; needs `RaftTaskStatus` label: LEFT) |
| 29 | unread | `hasNew` quiet dot for non-joined channels | `channelUnreadIndicator.ts:14` | not read | missing | Non-joined public channels with new messages look idle | LEFT (data parsed into `newFlags`; sidebar row needs a raft_ui slot) |
| 30 | forward | eligibility by `messageType` / action metadata | `forwardSelectionUtils.ts:25-45` | one ineligible row blocks the selection | unhandled-enum | Mixed selections rejected | PARTIAL (eligible subset logic aligned; see test) |
| 31 | misc | dead reads: `isPrivate`, `capabilities`, `membership`, `taskId`, message-level `sourceServerId` / `threadChannelId` / `parentChannelId`, `revokedAt` on machines, `server:updated`, `channel:removed`, `message:deleted` | n/a | stale keys/events | stale | None directly; masks real change detection | PARTIAL: joint policy keys, channel-membership keys, `revokedAt`, `channel:removed` cleanup via the 403/404 path fixed; message-level dead reads and harmless dead listeners LEFT |
| 34 | attachment | SVG with a server `thumbnailUrl` | `urlImageFallback.ts:5-10` | SVG never inline | wrong | Rasterized SVG shows as a file card | FIXED (raster thumbnail only; SVG bytes are never decoded) |
| 32 | channel | mute switch gate `activityMuteSupported` | `channelDomain.ts:241-248` | wire flag required | unverified | Mute switch can vanish | FIXED |
| 33 | agent runtime | `fastMode`, `reasoningEffort`, `runtimeConfig`, model label | `runtimeConfig.mode.kind` | legacy keys | KNOWN(runtime-config) | Profile shows wrong mode/effort | Owned by `cindy/runtime-config-read`, not touched |

## Left, with reasons

- Features Web has and Flutter does not (not stale reads): attachment `commentRef` chip and `commentCount` badge, direct-upload sessions, agent read receipts (`scope_read:updated`), hosted external runtime (`hostedRuntime`, retry), `lastRuntimeError` banner, `latestComputerReleaseNotes`, Slack `bridge` indicator, server profile avatar upload, `computer:restart:done` feedback, mobile push registrations, server-side system notifications contract. Each needs a product decision or a raft_ui widget.
- raft_ui follow-ups: `RaftTaskStatus` label, profile identity avatar slot and Left/Removed badge slot, member-row name badge and Slack section, sidebar quiet "new" dot. Avoided here to keep `ds-audit` counts and widget previews unchanged.
- Low-confidence or harmless: followed-thread unread double count on replayed `thread:updated`, DM merge-vs-replace semantics on `channel:updated`, agent model-label catalog on the Computer page, activity sender-name precedence, HistoryLimit banner using the entitlement plan.

## Guard against recurrence

`apps/raft_flutter/test/field_parity_*_test.dart` load real-shaped server payloads from
`apps/raft_flutter/test/fixtures/field_parity/*.json` (shapes copied from server
serializers and server tests, ids fake, source file:line in the audit) through the
Flutter accessors and assert the values Web would display. `field_parity_baseline_test.dart`
fails when a fixture is added without being loaded by a test, or a fixture is not valid JSON.

When a server serializer or a Web reader changes: update the fixture from the new
serializer output first, then the test fails where Flutter still reads the old shape.
Prefer a central accessor over a new `row['x']` read:
`RaftRecord.firstNonEmpty`, `RaftChannel.peerLabel`, `agentActivityText`,
`agentRowAmbientDisplay`, `featureFlagEvaluateBody`, `member_profile_rules.dart`.
