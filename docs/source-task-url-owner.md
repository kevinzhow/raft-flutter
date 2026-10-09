# Independent task URL ownership

This is the second bounded K10b implementation phase, following
[source-task-surfaces.md](source-task-surfaces.md). Source is pinned to
`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` (Web 1.17.5, raft-ui 0.5.27).
Source paths below are relative to `packages/web/src`.

## Mounted Source contract

| Source path and lines | Required behavior |
| --- | --- |
| `components/layout/rightPanelUrlSync.ts:334–355` | Modern `task=<channelId>:<messageId>` owns an identity independent of `thread`. The older `task=1` form resolves through the ordinary thread anchor. Removing the task query closes only its slot. |
| `components/layout/rightPanelUrlSync.ts:357–389,475–486` | Cold `legacyTask=<channelId>:<taskId>` reads the actual channel task bucket. Its pending URI survives until an explicitly legacy row is accepted; no metadata panel is invented while it waits. A changed URI rejects the old result. |
| `components/layout/rightPanelUrlSync.ts:512–535` | Opening a new task overlay pushes history when it does not remove another slot. Retargeting and closing use replacement. Task history retains the ordinary side anchor. |
| `store/threadStore.ts:337–357,527–618` | Modern task discussion has its own identity, request lifecycle and close action. It does not reuse the main or ordinary side-thread window. |
| `components/layout/MainLayout.tsx:1019–1057` | Host-task facts come from accepted task buckets. A DM/private parent bucket loads on demand. Before the real host task is known, the thread does not announce invented task facts. |
| `store/taskStore.ts:440–467` | Mounted consumers do not issue duplicate concurrent reads of the same channel task bucket. |
| `components/layout/MainLayout.tsx:1330–1420` | Task modal renders above the retained main and side panes. Covered side controls are not reachable through the modal backdrop. |
| `components/task/TasksPanel.tsx:964–987` | Actual board modern activation closes profile/legacy metadata but preserves ordinary side thread. Legacy activation closes ordinary thread and opens the metadata slot. |

## Implemented owner

`WorkspaceTaskHost` keeps the actual `WorkspaceView` child mounted and owns only
its task overlay. An accepted board row is seeded with the authority that
supplied it. A cold URL supplies identity only: it cannot invent title, number,
status, author or task ID. The host resolves the real channel task bucket and
matches the modern parent message or explicit legacy task ID. Modern pending
identity can show its independently loading discussion. Pending legacy identity
retains its URL without displaying a fabricated metadata panel.

`WorkspaceNavigation.taskRevision` retires task requests independently of the
main navigation request ticket. Task-only open, retarget, Close, Back and
Forward preserve the main request revision, side thread and unrelated query
values, including repeated values and fragments. Changes to the principal,
server, role or parent-channel capabilities retire the owner. General
navigation retains its existing revision fences. Modern task board activation
uses the Source profile/legacy arbitration; legacy board activation retires the
ordinary side identity.

The new `readSourceTaskBucket` shares only a currently pending request for the
same client and authority scope. It has no accepted-success or disk cache. The
message-task projection and task URL owner each retain their own acceptance
checks, so sharing transport does not share authorization or publish a stale
result. Session, server, role, parent membership, archival state and capability
changes separate the pending reads. Successful and failed reads are removed
when they settle; a later consumer performs a real current HTTP read.

The task surface keeps the existing API authorization, terminal cleanup and
borrowed-controller disposal rules. Closing it does not dispose the shared
client or its real main connection. A hydrated task's actual 404 still closes
the task. A failed cold bucket does not erase the unresolved task anchor or
invent missing facts.

## Actual evidence

Tests use the actual mounted `WorkspaceView`, real fixture HTTP calls and
controlled response gates. They cover Brutal light, Elegant light and Elegant
dark. Cold modern cases run at 390px and 1280px; cold legacy, role revocation and
board Back/retarget cases run at 390px. The original Source screenshot fixture
and calibration are unchanged.

| Check | Actual result | Private immutable receipt |
| --- | --- | --- |
| Seven focused navigation/task/Activity/Search test files | 88 passed | `.local/task-url-regressions-v7.log` |
| New actual task-route cases within that set | 18 passed | `apps/raft_flutter/test/workspace_task_route_test.dart` |
| New independent task history vectors | 2 passed | `apps/raft_flutter/test/workspace_task_slot_model_test.dart` |
| Pending transport sharing, scope separation and failure retry | 3 passed | `apps/raft_flutter/test/source_task_bucket_test.dart` |
| Existing task surfaces, authorization and controls | 56 passed | `.local/task-url-phase-a-regression-v1.log` |
| Existing three-theme SDK surface previews, history semantics and Escape | 6 passed | `.local/task-url-sdk-regression-v1.log` |
| Selected app/SDK analysis | Clean | `.local/task-url-analysis-v3.log` |
| App design-system ratchet | No growth; 696 findings | `.local/task-url-ds-v1.log` |

The board sequence holds a real main context request, opens a task, goes Back,
opens another task, and then releases the old detail as either success or
failure. It checks that the new task remains visible, the main request is still
accepted, drafts and ordinary side identity survive, and retired hidden task
replies issue no read acknowledgement. Other cases revoke role during a held
cold bucket and release that old result afterwards. The coalescing tests observe
actual request counts, client authority failures and a fresh read after failure.

Historical attempts remain intact:

| Receipt | Preserved result |
| --- | --- |
| `.local/task-url-mounted-v1.log` | Test compilation failed from an incorrect draft API in the new test. |
| `.local/task-url-mounted-v2.log` | Duplicate channel-bucket request failures and an aborted fake-async attempt. Only the private test processes were stopped. |
| `.local/task-url-mounted-v5.log` | 17 passed / 1 failed: the test incorrectly expected an old real-client request to succeed after server authority changed. |
| `.local/task-url-regressions-v6.log` | 84 passed / 4 failed: that authority expectation and three older N07a fixtures expected one thread header and attempted a covered side Close while a real task overlay was mounted. |
| `.local/task-url-analysis-v2.log` | One unused new-test import, subsequently removed. |

The N07a replacement preserves its original side-close assertions. It first
uses the visible `Close task` control, verifies that only the task slot was
removed, and then uses the now-visible side Close. This follows the Source modal
layer in `MainLayout.tsx:1330–1420`; it does not make covered controls clickable.

## Remaining boundaries

K10b remains **partial**. This batch proves root Tasks-board activation and
known-parent cold task URLs. The channel Tasks tab still uses the standalone
phase-A surface, and the message-task chip still invokes an ordinary thread;
those openers have not been adapted to the URI owner. A cold modern task whose
parent channel is absent from the authorized directory cannot yet mount its
borrowed discussion until a real parent record is available. No successful
unknown-parent discussion claim is made.

Legacy side docking/resizing and simultaneous modern-plus-legacy overlay
composition remain unimplemented. Source Timeline details and the exact
assignee popover pixels remain outside this batch. Real Linux/Android task
process pairs and task screenshot comparison are **NOT RUN**. Mounted tests,
preview tests and model vectors do not replace platform-renderer evidence.

The later [task-entrypoint follow-up](source-task-entrypoints.md) closes the
classic channel Tasks and message footer-chip entry gaps with actual mounted
input tests. This URI-owner report's receipts and other limits remain unchanged.

The subsequent [cold-parent metadata follow-up](source-task-parent-hydration.md)
admits an actual authorized parent absent from the directory before mounting its
borrowed discussion. Its delayed-HTTP, denial and retirement evidence is
separate from this report's original known-parent boundary.
