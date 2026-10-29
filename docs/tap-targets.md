# Tap targets

Scope: every container that renders a message (or a list of messages) and every
element Web makes interactive inside it, compared with Web `v1.21.2-source.1`
(`packages/web/src`, read only).

Bug class (Kevin, 2026-10-12: "in Activity, clicking Cindy's reply card below a
message does nothing"): a tap whose handler runs, writes its target, and the
container never renders it. In the reported case the "N replies" card called
`openThread`, the location gained `?thread=c1:parent`, `w.threadParent` loaded,
and no column showed it.

## Root cause of the reported case

`workspace_view.dart` decided the thread side panel with
`route == 'chat' && location.thread != null`, and the profile side panel with
`route == 'chat' || 'home'`. The Activity / Search master-detail preview
(`route == 'activity'` / `'search'`, content slot `open=channel:X`) is a message
timeline too, but it was never given a thread or profile column. Web
`RightPanel` (`MainLayout.tsx` 1340-1391) hosts both in column 4 beside a
channel / DM detail on `/activity` and `/search` (a thread detail is column 3
itself and gets no second thread; the profile still opens in column 4).

So on Activity and Search previews, desktop (1280) and foldable (816), these
were silent no-ops: inline thread card, replies badge, hover "Reply in
thread", sender avatar, `@mention` (profile panel), in both channel previews
and thread previews.

Fix: `DesktopNavigationPolicy.sidePanels` (one table: which route hosts which
location-driven panel) feeds both the slot computation and Escape
(`workspace_view.dart`), and the thread / profile column are now rendered on
the content routes.

## Mechanism

1. One table decides hosting. `DesktopNavigationPolicy.sidePanels(route, wide,
   location, target)` is the only place that says which routes render
   `?thread=` / `?profile=`. Escape closes column 4 (profile, then thread)
   before the column-3 detail (Web order).
2. Hosts must state their handlers. `RaftChatView` (`onTask`, `onViewBilling`),
   `ConversationPanel` (`onMessageTask`, `onViewBilling`,
   `onOpenChannelSettings`), `SourceTaskSurface` / `WorkspaceTaskHost`
   (`onTask`, `onViewBilling`) keep
   optional parameters (previews and unit tests build bare timelines), but
   `test/tap_target_registry_test.dart` fails when any call in `lib/` omits one.
   `null` is an explicit decision and always renders the affordance inert or
   hidden, never dead: a task chip without `onTask` is painted disabled (it used
   to open the thread, a wrong target), the plan / archived banners drop their
   link (they used to run `() {}`).
3. A registry lists every container. `lib/data/tap_target_registry.dart` names
   each `lib/` file that builds `RaftChatView`, `RaftMessageTile`,
   `RaftInlineThreadSurface`, `RaftThreadRepliesBadge`, `RaftConversationCard`
   or `RaftSearchResultSurface` and the test that taps it. A new file that builds
   one without being listed fails the static test.
4. A matrix test taps. `test/tap_target_matrix_test.dart` mounts the real
   `WorkspaceView` for each host in the registry, taps each element and asserts
   a visible effect (panel on screen with the location slot, location change,
   task slot, request, dialog route). A tap that changes nothing fails, and a
   location slot (`?thread=`, `?profile=`) with no panel on screen fails in
   every cell regardless of the expected effect. Known gaps are asserted as
   no-ops so fixing one fails its cell and forces this page to be updated.

Run: `tool/flutter test test/tap_target_matrix_test.dart test/tap_target_registry_test.dart`.
After editing the registry: `UPDATE_TAP_DOCS=1 tool/flutter test
test/tap_target_registry_test.dart` regenerates the block below.

### Adding a container

1. Build it, passing every handler it has (`null` where it has none).
2. Add a `TapContainer` (and a `TapHost` when it is a new mounted shape, plus
   its setup in `mount()` of the matrix test).
3. Regenerate this page. A container with no honest tap test is not accepted.

## Before / after

Before the fix, the matrix failed 20 cells, all in the Activity and Search
previews: `inlineThreadCard`, `repliesBadge`, `toolbarReply`, `avatar`,
`mention` on `activity-1280`, `activity-816`, `search-1280`, `search-816` (the
reply entry points) and `avatar` / `mention` on `activity-thread-1280` and
`activity-thread-816` (profile). The Chat hosts (1280, 390, thread panel)
passed: they were the only hosts with column 4.

## Sweep: container x element, Flutter vs Web

Status: OK = same as Web; FIXED = dead or wrong before this change; GAP = Web
has it and Flutter does not (recorded, not fixed here); SAME = Web behaves the
same way (including "inert").

| Container | Element | Flutter | Web | Status |
|---|---|---|---|---|
| Chat main (desktop, phone) | Inline thread card, replies badge | Thread panel (column 4 / folded overlay / phone page) | `closeProfile`, `openThread` | OK (matrix) |
| Chat main | Hover toolbar: reply, react, save | Thread panel, picker, save request (pointer only; hidden on touch) | same | OK (matrix, `chat_message_affordances_test`) |
| Chat main | Avatar, `@mention` | Profile panel; the hover card heading is wired to `openProfile(agent, activity)` | `openProfile` | OK (matrix) |
| Chat main | Sender name | Inserts `@name` into the composer | same | OK (`chat_message_affordances_test`) |
| Chat main | `#channel` link | Opens the channel | `nav.toChannel` | OK (matrix) |
| Chat main | Message / thread link, permalink chip, quoted card | `jumpToMessage` / `openThreadIdentity` (leaves Activity / Search, as Web) | `toMessage` + `openThread` | OK (`message_presentation_test`, `quoted_message_preview_test`) |
| Chat main | Inline `#N` task reference | Task slot (`?task=`) | `onOpenTaskRef` -> task modal | FIXED (was a read-only dialog with "Open message") |
| Chat main | Linked task chip | Task slot | task modal | OK (matrix); FIXED for hosts without a task slot (opened the thread, wrong target; now painted disabled) |
| Chat main | Reaction chip | Toggles the reaction | same | OK (matrix) |
| Chat main | Attachment chip | Preview dialog / lightbox | same | OK (matrix) |
| Chat main | Plan / archived / joint-locked banner links | Billing page / channel settings | same | FIXED where the host passed nothing (task discussion: `() {}`); hidden now |
| Chat main, touch | Tap on the row body | Nothing (SelectionArea owns the tap) | Opens the thread (`handleMobileTap`) | GAP (see below) |
| Thread panel (chat route) | Avatar, `@mention` | Profile panel | `openProfile(..., "thread")` | OK (matrix) |
| Thread panel | Reply actions, badge, inline card | Absent | `hideThreadActions` | SAME |
| Activity channel / DM preview, desktop 1280 and foldable 816 | Inline thread card, replies badge, toolbar reply | `?thread=` written, nothing shown | Thread in column 4 | FIXED |
| Activity channel / DM preview | Avatar, `@mention` | `?profile=` written, nothing shown | Profile in column 4 | FIXED |
| Activity channel / DM preview | `#channel`, task chip, `#N`, reaction, attachment | As Chat main | same | OK (matrix) |
| Activity thread preview (thread is column 3) | Avatar, `@mention` | `?profile=` written, nothing shown | Profile in column 4 | FIXED |
| Search channel / DM preview | all of the above | same as Activity channel preview | same | FIXED / OK (matrix) |
| Search thread preview | Avatar, `@mention` | same as Activity thread preview | same | FIXED (same code path, matrix covers Activity) |
| Activity list rows | Row, same-row double click, done, menu | Preview / canonical / done / menu | `handleActivate` | OK (`activity_*` tests) |
| Search result rows | Row, double click | Preview / chat | `handleMessageResultClick` | OK (`desktop_preview_single_location_test`, matrix setup) |
| Saved rows | Row, bookmark button, context menu | Opens the message (thread rows via `canonicalTarget`), removes, menu | `openSavedEntry`, `unsave` | OK (matrix) |
| Task discussion (modal / page) | Avatar, `@mention` | Profile panel on the route under the modal | profile panel mounts under the modal (`closeTaskModal` not called) | SAME |
| Task discussion | Inline `#N` | Swaps the task through the host | swaps the modal's task | FIXED (was a dialog) |
| Task discussion | Billing banner link | Billing page | `nav.toSettings("billing")` | FIXED (was `() {}`) |
| Public server (read-only) | Replies badge | Read-only thread panel | `onOpenThread` -> `openPublicThread` | OK (`public_server_view_test`) |
| Public server | `#channel` link | Selects the public channel | `selectPublicChannel` | OK |
| Public server | Avatar, name, `@mention`, thread / message / task refs, reactions | Inert | inert (`readOnlyProjection`) | SAME |
| Forward composer preview | Content, "View all" | Expands in place | same (source label inert without `onOpenSource`) | OK |
| Forwarded bundle in a message | Source label | Not rendered | Clickable when the source is public | GAP (missing element, not a dead tap) |
| Agent profile, activity tab | `#channel` / thread / `dm:` tokens | Plain text | RefText chips navigate | GAP (missing element, not a dead tap) |
| Appearance sample, exported image | all | Inert | n/a | SAME (inert by design) |
| Phone pages | Thread, profile | Pages over the chat (`chat-390` host) | mobile detail routes | OK (matrix) |

Counts: 34 rows. FIXED 10 (every Activity and Search preview
reply entry point and profile entry point, the inline `#N` reference, the task
chip fallback, the dead banner links, and the task discussion's `#N` and billing
link); GAP 3 (touch row tap, forwarded-bundle source label,
agent activity ref chips); the rest OK or SAME.

## Left unfixed

* Touch row tap. Web opens the thread when a message row is tapped on a device
  without hover. Flutter's message text sits in a `SelectionArea`; its tap
  recognizer is deeper than the row's, wins the arena, and a row-level `onTap`
  only fires on the margins. The cell is a `knownGap` (asserts no change). Needs
  a design decision (selection vs tap) and device proof (AGENTS.md: device fixes
  need device proof); phone routing is also being changed on
  `cindy/fold-routing`.
* Forwarded-bundle source label and agent activity ref chips are elements Flutter
  does not draw. They are feature gaps, not taps that do nothing.

## Generated matrix

<!-- tap-matrix:start -->
| Element | chat-1280 | chat-390 | chat-thread-1280 | activity-1280 | activity-816 | activity-thread-1280 | activity-thread-816 | search-1280 | search-816 |
|---|---|---|---|---|---|---|---|---|---|
| Inline thread card ("N replies") | thread panel | thread panel | - | thread panel | thread panel | - | - | thread panel | thread panel |
| Thread replies badge | thread panel | thread panel | - | thread panel | thread panel | - | - | thread panel | thread panel |
| Hover toolbar: Reply in thread (pointer) | thread panel | - | - | thread panel | - | - | - | thread panel | - |
| Row body tap (touch) | - | GAP: no-op | - | - | GAP: no-op | - | - | - | GAP: no-op |
| Sender avatar | profile panel | profile panel | profile panel | profile panel | profile panel | profile panel | profile panel | profile panel | profile panel |
| @mention link | profile panel | profile panel | profile panel | profile panel | profile panel | profile panel | profile panel | profile panel | profile panel |
| #channel link | opens channel | opens channel | - | opens channel | opens channel | - | - | opens channel | opens channel |
| Inline #N task reference | task slot | task slot | - | task slot | task slot | - | - | task slot | task slot |
| Linked task chip | task slot | task slot | - | task slot | task slot | - | - | task slot | task slot |
| Reaction chip | request | request | - | request | request | - | - | request | request |
| Attachment chip | dialog | dialog | - | dialog | dialog | - | - | dialog | dialog |

| Host | Surface | Width |
|---|---|---|
| `chat-1280` | Chat, desktop 1280 | 1280 |
| `chat-390` | Chat, phone 390 | 390 |
| `chat-thread-1280` | Chat thread panel, desktop 1280 | 1280 |
| `activity-1280` | Activity channel preview, desktop 1280 | 1280 |
| `activity-816` | Activity channel preview, foldable 816 (touch) | 816 |
| `activity-thread-1280` | Activity thread preview, desktop 1280 | 1280 |
| `activity-thread-816` | Activity thread preview, foldable 816 (touch) | 816 |
| `search-1280` | Search channel preview, desktop 1280 | 1280 |
| `search-816` | Search channel preview, foldable 816 (touch) | 816 |

| Container | File | Builds | Taps asserted in |
|---|---|---|---|
| message-timeline | `lib/features/chat_view.dart` | RaftMessageTile, RaftInlineThreadSurface, RaftThreadRepliesBadge | tap_target_matrix_test.dart (every host) |
| workspace-hosts | `lib/features/workspace_view.dart` | RaftChatView | tap_target_matrix_test.dart (thread panel, Activity / Search detail) |
| channel-panel | `lib/features/conversation_panel.dart` | RaftChatView | tap_target_matrix_test.dart (chat, Activity, Search hosts) |
| task-discussion | `lib/features/task_surface.dart` | RaftChatView | tap_target_matrix_test.dart (task discussion carries onTask / onViewBilling) |
| public-server | `lib/features/public_server_view.dart` | RaftMessageTile, RaftThreadRepliesBadge | public_server_view_test.dart (reply badge opens the thread) |
| activity-saved-rows | `lib/features/resource_view.dart` | RaftConversationCard | activity_row_interaction_test.dart; tap_target_matrix_test.dart (Saved rows) |
| activity-card-rows | `lib/features/activity_card_row.dart` | RaftConversationCard | activity_row_interaction_test.dart; activity_conversation_list_test.dart (Activity card and list rows) |
| search-rows | `lib/features/resource_search.dart` | RaftSearchResultSurface | desktop_preview_single_location_test.dart |
| image-export | `lib/features/message_image_export.dart` | RaftMessageTile | inert by design: off-screen render for the exported image |
| appearance-sample | `lib/features/appearance_section.dart` | RaftMessageTile | inert by design: static sample row in Appearance settings |
<!-- tap-matrix:end -->
