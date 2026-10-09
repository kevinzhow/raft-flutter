# Grid message task badges open independent thread tabs

This bounded K10b follow-up implements the actually reachable channel-message
footer opener. It follows pinned Source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`
and the three-theme real Source App observations retained in
[the container report](source-grid-task-presentation.md). It does not claim
complete workspace or task parity.

## Source ownership

All paths below are relative to `packages/web/src` in that pinned snapshot.

| Source | Mounted behavior |
| --- | --- |
| `components/message/MessageItem.tsx:3029–3035,3685–3700,4888–4900` | The actual message task badge opens its real parent channel/message with task intent. The supplied grid thread override wins over the global thread store. The footer does not supply an invented reply-channel hint. |
| `components/workspace/WorkspaceGridRealPanel.tsx:181–219` | The channel override creates a thread ref and a `Thread <first-eight-parent-characters>` tab, retaining the channel editor. It does not create a global task modal. |
| `components/workspace/WorkspaceGridDemo.tsx:185–186,365–370` and `workspaceGridModel.ts:82–104` | The ref deduplicates by parent channel/message. An existing tab is selected; a new tab is added to the target group. |
| `components/workspace/WorkspaceGridRealPanel.tsx:286–389` | The thread tab owns its identity, parent/reply loading and close callback. It mounts `ThreadPanel` with `hideHeader` and a workspace composer. |
| `store/threadStore.ts:369–375` | An already accepted parent summary or followed-thread record supplies the known reply-channel identity before lookup. |
| `components/workspace/WorkspaceGridRealPanel.tsx:510–530` | The standalone grid Tasks panel has a **separate explicit** card override which creates a thread ref with task-number/title metadata. This caller was inspected but is not implemented in this commit. |
| `components/layout/MainLayout.tsx:1394,1444,1459,1514` | Active workspace suppresses global task presentation and skips ordinary right-panel URL synchronization. A global-modal fallback would invent a visible surface. |

The immutable actual Source footer run is `.local/grid-task-source-v5` in the
private member worktree. Brutal, Elegant light and Elegant dark each observed
the reachable task badge adding `Thread msg-agen` beside `design`, rendering
the real parent/replies/composer, and leaving the global task store/anchor
closed. There are 262 / 159 / 161 DOM samples and stage PNGs. Its exact fixture
SHA-256 is `4bc45dda557a6fe313fb66f823056061cd69ec06a63c0857368330124b7341f2`;
Source input is `799c42a7703b30e809471e9835dfeeb1adbb75c06ae8689562685970292fef17`.
The runtime/runner manifests and earlier unreachable-control/raw-URI failures
remain unchanged. Its accepted thread summary avoided lookup; it does not
prove a delayed Source lookup sequence or a continuous compositor capture.

## Flutter owner and actual input coverage

`WorkspaceGridSessions` now owns parent-keyed thread refs and their separate
borrowed controllers on the existing authorized client and entity directory.
A footer click creates/selects its real thread tab in the existing active group.
It never selects a root channel, rewrites the global task/thread URI, creates
a second transport, or replaces the accepted channel window. Parent metadata
and actual thread resolution/replies load independently with the existing
controller acceptance fences. An already accepted channel summary supplies
the real thread hint and skips lookup, matching the observed cached Source
opener; the task DTO alone supplies no hint. The tab body uses the existing
thread timeline and composer without a duplicate header; its editor tab owns
close/title.

Switching away retains both editors, drafts, cursor positions and accepted
windows. Selecting the same parent again reuses the thread owner rather than
loading it again. The same-route grid callback no longer emits redundant Chat
navigation and invalidates the root navigation revision. Narrowing below the
existing 1024px workspace boundary removes presentation admission while
retaining the desktop thread editor. Closing the tab retires only its private
owner/subscriptions; the shared authenticated client remains usable.

`workspace_grid_task_thread_test.dart` contains 27 real mounted `WorkspaceView`
cases across all three supported themes. Real mode clicks, footer clicks,
channel/thread-tab selection, keyboard Enter activation, editor input, cursor
changes, resize and tab-close input verify the above behavior. Local HTTP gates
hold parent, resolution and replies independently. Channel removal uses the
real `channel:removed` event. Explicit server/principal/role/current-directory
capability changes retire the borrowed owner; late parent/reply success
cannot recover UI facts or emit a read acknowledgement. A retained inactive
tab can accept an authorized reply window while remaining unpresented and
sending no hidden read. Re-admitting a visible viewport may acknowledge it.
Three further real badge cases load the accepted summary through the actual
channel message response, then prove immediate reply identity/composer while
parent and replies are held independently, with zero lookup requests.

The Flutter widget fixture is explicit and independent of the browser fixture;
these are Source-derived behavior checks, not a shared-fixture renderer pair.

## Validation and retained attempts

| Check | Result | Private receipt |
| --- | --- | --- |
| Final footer/accepted-summary plus existing owner/routes | 44 passed | `.local/grid-thread-tab-final-v2.log` |
| Footer plus existing grid/task/route cases before summary follow-up | 111 passed | `.local/grid-thread-tab-regression-v2.log` |
| Final combined grid/task/authority/route set | 131 passed | `.local/grid-thread-tab-regression-v3.log` |
| Real `channelCapabilities.viewChannel=false` follow-up | 3 passed | `.local/grid-thread-tab-capability-v1.log` |
| Final selected analysis | Clean | `.local/grid-thread-tab-analysis-v4.log` |
| Design-system scanner/ratchet | 6 passed; no growth | `.local/grid-thread-tab-ds-v2.log` |

`.local/grid-thread-tab-v1.log` retains the initial compile failure from a
misspelled test getter. `v2` and `v3` retain 21 passes and three real root
navigation revision failures; the repeated same-route callback was corrected
in the grid owner. The first regression invocation retains 88 passing cases
and two load failures from nonexistent test paths.
`grid-thread-tab-analysis-v3.log` also retains one style diagnostic from a
missing branch block; `v4` checks the corrected branch. No failed receipt or
Source input was overwritten, normalized, or relabeled as a successful run.

Remaining gaps include the standalone grid Tasks card override, channel Tasks
body fallback, generic reply/profile/parent-channel openers and header-action
portals, workspace URI persistence/restoration, legacy docking, modern/legacy
combined slots, exact task/grid pixels and native task process evidence. This
commit does not broaden editor-group layouts, maximize/vertical behavior or
the paused Markdown/calibration work. K10b remains partial.
