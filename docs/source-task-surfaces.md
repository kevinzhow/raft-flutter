# Task surfaces: independent modern discussion and legacy metadata

Source is pinned to `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`
(Web 1.17.5, raft-ui 0.5.27). Paths below are relative to
`packages/web/src`. This document describes the first implementation phase;
it does not supersede historical failures in [task-detail-loading.md](task-detail-loading.md).

## Mounted Source contract

| Source path and lines | Required behavior |
| --- | --- |
| `components/task/TasksPanel.tsx:964–987` | A board task opens immediately. Modern tasks declare `intent: "task"`; legacy tasks open the legacy metadata slot. |
| `store/threadStore.ts:337–357,527–618` | The modern task identity is independent of the ordinary side thread. A known thread hint avoids lookup; unknown resolution uses the existing-thread read endpoint. Closing a task clears its own slot. |
| `components/layout/MainLayout.tsx:1019–1057` | Task facts resolve from accepted current, parent-channel and server task buckets. The parent-channel bucket is loaded on demand for DM/private tasks. |
| `components/layout/MainLayout.tsx:1066–1195` | The fixed task bar contains channel and task number. The title belongs to the scrolling head. Desktop modern bounds are `min(960px, viewport−32px)` by `min(86vh,900px)`; narrow mode fills the surface. The 24/16/16 skeleton is the lazy-module fallback, not a history HTTP gate. |
| `components/task/TaskModalHead.tsx:36–150` | Title is three lines, 18px/22.5px. Empty description has no placeholder; a trimmed description above three lines plus 1px epsilon can expand. The embedded discussion hides its duplicate header and parent message. |
| `components/task/TaskProperties.tsx:55–300` | History begins loading as a mounted consumer but starts collapsed. Internal resource receipts are hidden. Status permits legal transitions; assignment uses channel members with typed identities, humans before agents, and Unassigned survives filtering. Completed assignment is read-only. |
| `components/message/ThreadPanel.tsx:2523–2557` | The task head is the discussion's parent slot, including while replies load. Parent metadata, reply requests and the composer have independent readiness. |
| `components/task/LegacyTaskPanel.tsx:17–226` | Legacy metadata is a separate read-only panel. It has no discussion, history request or task mutation. Its desktop modal is bounded by 760px and `min(78vh,720px)`; narrow mode fills the surface. |

## Flutter phase A

`TaskSurfaceController` accepts a real task row and owns only its detail/history
and borrowed discussion lifecycle. The borrowed `WorkspaceController` shares
the authenticated client, cache and entity directory, but cannot dispose the
session. It has a separate ledger, thread identity, draft and presentation
owner. Opening, sending and closing it preserve the main and ordinary side-thread
windows, drafts and navigation revision. Parent/message reply requests remain
independent; the duplicate parent/header is suppressed by the optional
`RaftChatView.threadParentSlot` / `hideThreadParent` composition seam.

Task-number lookup refreshes accepted facts, while history errors remain local
to History. Task writes use the mounted status and assignment properties,
perform the real PATCH, and refresh the originating resource bucket from its
API response. An expected revision is sent only when the accepted task supplies
one. Authorization failures revoke the accepted resource scope. Close, server,
principal and permission fences reject late results. Deleted-parent terminal
cleanup still requires fresh accessible history and administrator capability;
it is not inferred from a missing local channel.

`RaftTaskSurface` is API-free and has two widget previews. It provides the modern
fixed bar, title/description, properties, collapsed history and real embedded
discussion; legacy mode provides the accepted metadata and read-only notice.
History exposes its actual expanded semantic state. Ordinary task-modal Claim,
Release, Discussion and Delete buttons were removed because these controls do
not appear in the mounted Source properties. The separately authorized orphan
cleanup path retains its real status/delete API guards.

## Evidence and boundaries

The actual ResourceView tests exercise three themes at 390px and 1280px, hold
detail, parent, replies and history independently, send a real discussion reply,
check stable header height (53px Elegant / 54px Brutal), retain both original
windows/drafts, and check no redirect or hidden outer read acknowledgement.
Further cases cover legacy no-API behavior, pending close and late responses,
typed human/Agent assignment, expected revision, completed assignment lock,
fresh orphan cleanup authorization and history failure.

| Check | Actual result | Private immutable receipt |
| --- | --- | --- |
| Six related app test files | 79 passed | `.local/task-surface-regressions-v9.log` |
| New app surface cases within that set | 15 passed | `.local/task-surface-expanded-v6.log` |
| Three-theme SDK previews, history expanded semantics and Escape | 6 passed | `.local/task-surface-sdk-v2.log` |
| Selected app/SDK analysis | Clean | `.local/task-surface-analysis-v5.log` |
| App design-system ratchet | No growth; 696 findings | `.local/task-surface-ds-final.log` |
| Original old-control expectations | Preserved FAIL: 22 passed / 19 failed | `.local/task-surface-old-controls-v1.log` |
| Owner disposal regression | Preserved FAIL | `.local/task-surface-mounted-v1.log` |
| Pending SDK scroll-timer teardown | Preserved FAIL: 73 passed / 6 failed | `.local/task-surface-regressions-v7.log` |
| New SDK semantics handle teardown | Preserved FAIL: 3 passed / 3 failed | `.local/task-surface-sdk-v1.log` |

The teardown-timer test repair removes the widget only **after** all visible
assertions, then drains the SDK timer that checks `mounted`; no product warmup
or acceptance delay was added. The previous failure remains intact.

K10b is **partial**. This phase does not implement task URL/history ownership,
cold task deep links, Source legacy side docking/resizing, or Source board
profile/legacy-slot arbitration. These belong to phase B. The history rows do
not yet reproduce the Source Timeline marker/detail widgets, and the assignment
trigger/popover is not yet a measured pixel match to InlineBadgeEditor with
SelectionPopover. Real Linux/Android task process pairs and screenshot parity
are **NOT RUN** for this batch; mounted tests and previews do not replace them.

## Native harness changes for review

The existing actual task-card entry remains the visible title or its
`RaftTaskCard.onOpen` callback. The opened surface is `SourceTaskSurface`.

| Control / state | Finder |
| --- | --- |
| Modern surface | `ValueKey('task-thread-modal')` |
| Legacy surface | `ValueKey('legacy-task-panel')` |
| Fixed bar | `ValueKey('task-modal-bar')` |
| Title | `ValueKey('task-modal-title')` |
| History toggle, initially collapsed | `ValueKey('task-properties-history')` |
| History error, after expanding | `ValueKey('task-history-error')` |
| Status editor | `ValueKey('task-properties-status')`, then the real `RaftInlineBadgeMenu` option key such as `done` |
| Assignee trigger / search | `ValueKey('task-properties-assignee')` / `ValueKey('task-assignee-search')` |
| Close / narrow Back | tooltip `Close task`; Escape also closes the owned task |
| Real modern discussion | existing `RaftComposer` / Send tooltip, scoped to `SourceTaskSurface` |

History being mounted is not evidence that its HTTP request completed. Expand
the toggle and wait for actual events or the explicit history error. Legacy
mode has neither History nor a composer. Do not retain obsolete AlertDialog,
Claim/Release/Discussion button assertions as Source requirements.

Phase B's independent URI owner, known-parent cold hydration, history and scope
fences are documented separately in
[source-task-url-owner.md](source-task-url-owner.md). The phase-A evidence and
historical limits above remain tied to their original implementation; the new
report states which boundaries the later batch actually covers.
