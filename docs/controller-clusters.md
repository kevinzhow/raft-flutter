# WorkspaceController clusters

Where to cut `WorkspaceController` (`apps/raft_flutter/lib/data/workspace_controller.dart`) into per-domain repositories, services and per-page view models (Flutter app architecture: repository = single source of truth per domain, services wrap I/O, view models hold per-page state and commands). Generated with `tool/controller_clusters.py` (Markdown; `--json` for the full member/field tables; `--resolution 3.0` for a finer cut). Numbers below are from the default run on this tree and drift as the controller changes; rerun before starting a slice.

## What the controller is today

- One class, 145 instance fields (the structure-audit counts 220 for the whole `workspace_controller` module: the root plus `conversation_window.dart`, `workspace_message_windows.dart` and the types that extend/implement them). It has no `part` files and no `extension ... on WorkspaceController`; the tool handles both if they appear.
- 294 members (≈5100 member lines), 23 realtime events, all dispatched from `_event` (191 lines) and `_channelRealtime`. Presence events (`presenceEvents`) are ignored by design; entity directory and followed threads subscribe to `client.events` themselves.
- Tasks and agents are already out: `entityDirectory` (agents, computers, members), `taskHistoryCache`/`agentTabCache` (two thin `ServerBoundCache` fields), `followedThreads`, `composer`, `messageWindows`/`ledger` exist as owners. What is left is session, channel list, read state, navigation glue, presentation flags and thread/window loading state.
- Hub fields touched by 25-114 members each, excluded from clustering: `presentationSource`, `client`, `_disposed`, `messageWindows`, `channel`, `server`, `composer`, `_revokedChannels`, `threadChannelId`, `_threadIdentity`. `presentationSource` (route-local presentations borrowing a source controller) is in 114 members: every extracted owner must be shared with borrowed controllers once (`presentationSource?.x ?? own`), not re-forked per method.
- 8 cross-cutting orchestrators touch 5+ clusters (≈1100 lines): `selectServer` (206), `jumpToMessage` (224), `_event` (191), `selectChannel` (151), `_revokeChannel` (126), `send` (124), `revokeServer` (43), `_resetServerWindows` (23). Clusters cannot be cut cleanly until revocation and selection fan-out go through a small bus (see order).

## Clusters

Resolution 2.0. "Ext refs" counts receiver-typed uses in `lib` outside the controller (public members and public fields); "out/in" is member-call edges to/from other clusters. #133 = message window and history work in flight; "avoid" means entangled with it.

| # | Proposed owner | Fields | Members | Lines | Ext refs (files) | Events | out/in | #133 |
|---|---|---:|---:|---:|---:|---:|---|---|
| 12 | `WorkspaceDeviceStore` (service: cache read/write queue, retire) | 4 | 10 | 155 | 70 (16) | 0 | 5/42 | free |
| 1 (media subset; res 3.0 #7, #20, #21) | `AttachmentMedia` (image repo glue, signed URLs, players, preview gate, purge) | 12 | 22 | 272 | 107 (35) | 0 | 6/92 | free |
| 1 (whole) | media above, plus `WorkspaceServices` (lazy stores, ownership flags) and `RaftApiGateway` (`query`, `command`, `sharedQuery`) | 27 | 62 | 743 | 553 (88) | 0 | 36/96 | free |
| 10 | `SidebarRepository` | 6 | 3 | 113 | 15 (7) | 1 | 10/4 | free (event only) |
| 6 | `ConversationPresentation` (per-page view model: foreground, tab/main/thread presented) | 8 | 8 | 103 | 53 (14) | 0 | 7/5 | feeds window layout callback |
| 13 | fold into existing `WorkspaceComposer` (notices, send warnings, pending mentions) | 4 | 13 | 213 | 22 (3) | 0 | 22/9 | `send` uses windows |
| 7 | `WorkspaceNavigation` binding (location, section, profile, conversation resolution) | 8 | 11 | 198 | 185 (23) | 0 | 14/35 | reads windows |
| 8 | `SessionScope` + `ServerDirectoryRepository` (servers, membership, revocation, bootstrap) | 7 | 16 | 358 | 76 (11) | 4 | 47/28 | revocation fan-out |
| 4 | split: `RealtimeConnection` (connected, rooms, heartbeat, gap sync), `ReactionRepository`, uploads into composer | 10 | 19 | 487 | 62 (16) | 7 | 58/38 | touches windows |
| 9 | `ChannelRepository` (channels, dms, prefs, `channel:*`, `dm:new`) | 7 | 24 | 639 | 220 (37) | 4 | 79/12 | needs bus first |
| 3 | `InboxRepository` (unread, mentions, read state, prefetch) | 11 | 32 | 571 | 82 (12) | 3 | 46/49 | avoid: `markRead`, `older`, `returnToLatest` |
| 2 | `ThreadSummaryRepository` / reply authority | 13 | 24 | 322 | 46 (13) | 4 | 12/57 | avoid |
| 5 | `MessageWindowRepository` (hasMore/hasNewer/loading, select/open/jump) | 10 | 31 | 958 | 356 (64) | 0 | 93/37 | avoid |
| 11 | `ThreadViewModel` (thread visit, parent, uploads, draft scope) | 5 | 24 | 219 | 128 (27) | 0 | 28/50 | avoid |
| 14-17 | tiny: preview gate and retained index go with `AttachmentMedia`; `refreshChannel` with channels; scope visits with composer | 10 | 5 | 77 | 1 | 0 | - | - |

Events by cluster (primary handler): channels #9 `channel:updated`, `dm:new`, `message_display_prefs:updated`, `notification_prefs:updated`; session #8 `connection:error`, `server:member-updated`, `server:membership-removed`, `server:plan-updated`; inbox #3 `read_state:updated(_bulk)`, `sync:resume:response`; connection/reactions #4 `connected`, `disconnected`, `heartbeat`, `rooms:joined`, `message:new`, `message:updated`, `reaction_viewer:updated`; reply authority #2 `channel:authority-updated`, `channel:members-updated`, `channel:removed`, `thread:updated`; sidebar #10 `pinned:updated`. The tool prints the full event table with every cluster each event touches; `message:new/updated` touches 4 clusters and `channel:removed` 5.

Mapping to the names in the task: `AgentDirectoryRepository` and `TaskRepository` already exist as `entityDirectory` and the task caches (only the two `ServerBoundCache` fields remain to move); `InboxRepository`, `ChannelRepository`, `MessageWindowRepository` and `SessionScope` are the rows above.

## Recommended order

Most independent and most valuable first; nothing before the last four touches message windows or history.

1. `AttachmentMedia` (first slice below). Leaf: it calls back into the controller about 3 times and is called 100+ times from 34 files.
2. `WorkspaceDeviceStore` (cluster 12). Leaf service: 5 outgoing calls, 42 incoming (every cluster persists through `_save`/`_cached`). Moves `cache`, `_cacheWrites`, `_cacheRetired`, `_save`, `_cached`, `_readEntities`, `_writeEntities`, `readDevice/writeDeviceTranslations`, `readTranslationGate`, `retireCache`, `cacheWritable`. Leave `error`/`setError` (UI state) behind.
3. Composition root: `WorkspaceServices` takes the lazy stores (`translations`, `threadSearch`, `threadFollowers`, `announcements`, `announcementGate`, `channelFilesStore`, `activityUnread`, entity directory, followed threads) and `_ownsX` flags; stores that take `this` as authority get a narrow interface instead. `RaftApiGateway` takes `query`/`command`/`sharedQuery`. Keep `query`/`command` overridable on the controller: 43 files subclass the controller and override `query`, `command`, `refreshUnread`, `jumpToMessage`, `refreshChannels`, `selectChannel`.
4. `SidebarRepository` (3 members, 113 lines; covered by `sidebar_load_authority_test`, `workspace_message_windows_test` for `pinned:updated`).
5. Revocation and selection bus: `SessionScope` publishes `serverRevoked`, `channelRevoked`, `serverSelected`; `AttachmentMedia`, device store, windows and unread subscribe. This removes the orchestrators (`revokeServer`, `_revokeChannel`, `selectServer`, `_resetServerWindows`) as the only cross-cluster paths and enables 6-8.
6. `ChannelRepository` (cluster 9 plus `_retainedAttachmentIndex`/`_admittedAttachmentChannels`).
7. `InboxRepository`, `NavigationBinding`, `ConversationPresentation` once #133 settles the window API (they only meet windows through `_messageWindowLayout`, `markRead`, `older`).
8. `ReactionRepository`, `MessageWindowRepository`, `ThreadViewModel`, then replace `_event` by per-repository event registrations using the event table.

## First slice: `AttachmentMedia`

Why: leaf with no dependency on window or history state; ties directly to the open structure-audit exception on `workspace_controller` tokens (reason: preview allowance and memory-pressure handling "no new controller state"), whose `_newImageRepository` budget code is the code that moves. Coordinate with that change: land it first, or move the budget wiring unchanged.

New file `apps/raft_flutter/lib/data/attachment_media.dart`, class `AttachmentMedia`, created by the source controller and shared by borrowed ones (`late final attachmentMedia = presentationSource?.attachmentMedia ?? AttachmentMedia(...)`), which removes the `presentationSource` forks inside `acquireAttachmentImage`, `peekAttachmentImage`, `attachmentUrl`, `attachmentDiskCache`, `attachmentPreviewEnabled`, `playerSessions` and the `debug*` getters.

Moves (current lines):

- Fields (12): `_attachmentImages`, `attachmentImageStore`, `_imageAuthorities`, `_removeImageTrimmer`, `_removeImageReporter` (487-495, 726), `_attachmentUrls`, `_playerSessions`, `_removePlayerTrim`, `_attachmentUrlRequests` (5346-5356), `_previewGate`, `_previewGateAt`, `_previewGateScope` (5447-5449). The retained-index fields (`_retainedIndex*`, `_retainedAdmissionStamp`, `_retainedChannelIds`) stay until step 6.
- Members: `retainedImage{DecodedBytes,Count,EncodedBytes}`, `_retainsAttachment`, `_registerImageAuthority`, `_newImageRepository`, `acquireAttachmentImage`, `peekAttachmentImage`, `attachmentDiskCache`, `attachmentCacheKey`, `attachmentStored` (586-820); `playerSessions`, `debugAttachmentUrl{Requests,s}`, `attachmentUrl`, `_urlOf`, `invalidateAttachmentUrl`, `_fetchAttachmentUrls`, `attachmentPreviewEnabled` (5342-5472); `_purgeStoredChannel` (3107) and the identity purge in `revokeServer` (1411).
- Inputs the new class takes as callbacks, not the controller: `scope()` (stays `attachmentImageScope` in the controller: it is session identity), `get(path)`/`post(path, data)` from `client` (not `query`, as today), `isDisposed`, `isRevoked(channelId)`, `retainedByHistory(key)` (wraps the retained index that stays in the controller for now), `admits(key)` for `server?.id == client.serverId`.
- Hooks left in the controller: `notifyListeners` calls `attachmentMedia.synchronize()` (3 lines to 1), `clearRebuildableMemory` calls `attachmentMedia.trimRebuildable()`, `_revokeChannel` calls `attachmentMedia.revokeChannel(scope)`, `revokeServer` calls `attachmentMedia.purgeIdentity(...)`, `dispose` calls `attachmentMedia.dispose()`.

Forwarding facade kept temporarily (one-liners, marked `@Deprecated('use attachmentMedia')` once callers move): `acquireAttachmentImage`, `peekAttachmentImage`, `attachmentUrl`, `invalidateAttachmentUrl`, `playerSessions`, `attachmentCacheKey`, `attachmentStored`, `attachmentDiskCache`, `attachmentPreviewEnabled`, `retainedImage*`, `debugAttachmentUrl*`. `attachmentImageScope` stays (public, 11 refs).

Tests that already cover it (all go through the controller, so they must pass unchanged through the facade): `attachment_url_cache_test` (28 cases: URL reuse, coalescing, preview gate), `attachment_url_reuse_test`, `attachment_retention_index_test`, `attachment_cache_revocation_test`, `attachment_image_cache_test`, `attachment_image_repository_test`, `attachment_preview_cache_test`, `attachment_scope_test`, `resource_release_test`, `cache_clear_test`, `video_card_frames_test`, `player_sessions_test`, plus widget tests `media_browser_video_test`, `viewer_hdr_fallback_test`, `viewer_video_surface_test`, `image_card_shape_test`, `inline_attachment_media_test`. Gaps to close before moving: no test exercises these paths on a borrowed controller (`presentationSource != null`), `revokeServer` purge ordering, or `dispose` order of the trimmers/reporters; add characterization tests for those first.

Callers to migrate later (lib, ≈106 refs in 34 files): `features/attachment_view.dart`, `conversation_panel.dart`, `media_browser.dart`, `video_card_poster.dart` (image leases); `attachment_image_loader.dart`, `attachment_preview_dialog.dart`, `attachment_transfers.dart`, `media_video_page.dart`, `source_channel_files_actions.dart`, `platform/attachment_stream.dart` (URLs); 8 files for `playerSessions` (`inline_attachment_media.dart`, `attachment_shape.dart`, `chat_view.dart`, ...); `attachment_html_preview.dart`, `attachment_shape.dart` (cache key and disk cache); `attachment_preview_gate.dart`.

Expected reduction (approximate): controller lines 6021 to about 5740 (-280: -294 moved, -30 hook lines, +45 facade), instance fields 145 to 134 (-12 moved, +1 `attachmentMedia`), tokens about -1350 of 39455 (-3.4%), which brings the module back under the pre-exception ceiling of 39455 with margin. The facade deletes with the caller migration (another ≈-45 lines, -1 field).

## Method and limits

The tool is lexical (comments and strings blanked, interpolations kept; no analyzer). Local variables that shadow a field hide it within their scope; zero-argument getters are transparent; `x.field` counts only for `this` and source aliases. External callers are found through receiver names declared with the controller type in the same file, so untyped aliases are undercounted and a short name like `w` can overcount. Louvain over members-per-field co-access (weight 1/(k-1) per member touching k fields), hubs and members touching more than 25 fields excluded; `--resolution` trades cluster count for purity. Treat clusters as a map of seams, not as a verdict: cluster 4 mixes connection, reactions and uploads, and cluster 1 mixes media with the store registry (the 3.0 run separates them).
