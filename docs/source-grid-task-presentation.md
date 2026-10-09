# Workspace task container and hidden channel tabs

This bounded K10b correction follows actual pinned Source App observations,
not just the task-card caller. Source is
`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, Web 1.17.5 / raft-ui 0.5.27.
Paths below are relative to `packages/web/src`.

## Mounted Source contract

| Source path and lines | Container behavior |
| --- | --- |
| `components/workspace/WorkspaceGridRealPanel.tsx:210–219` | The grid channel mounts `ChatPanel` with `hideHeader`. |
| `components/message/ChatPanel.tsx:411–415,1458–1475` | `hideHeader` also hides the channel Chat/Tasks/Files tab controls. URI-selected task/file bodies still render. |
| `components/layout/MainLayout.tsx:1377–1394` | Search/Activity content routes return their overlays first. Other active workspace routes suppress the global right-panel/task container. |
| `components/layout/MainLayout.tsx:1444,1459,1514` | Active workspace skips ordinary right-panel URL synchronization. Global task caller intent therefore does not prove a visible modal or task query there. |
| `components/workspace/WorkspaceGridRealPanel.tsx:181–195` | The reachable message footer/thread override creates an independent grid thread tab. |
| `components/workspace/WorkspaceGridRealPanel.tsx:510–530` | Standalone grid Tasks cards have their own independent thread-tab override. |

## Actual Source browser observations

An isolated Vite runtime serves the unchanged pinned `index.html → App` against
explicit local fixture bytes. It uses the real persisted workspace preference
for the fixture user and Source's unmodified development availability gate.
No Source store or product file is changed. The browser uses the existing
Chromium executable without font/AA or calibration changes. It records every
DOM rAF sample, real HTTP chronology, raw URIs, read-only live store snapshots
and stage PNGs at 1440×900 in all three themes.

The reachable footer capture uses the existing real `msg-agent-reply` task
badge. Clicking it adds `Thread msg-agen` beside the retained `design` grid tab,
renders the actual parent, replies and composer, leaves the global task store
closed and creates no global task anchor. Before clicking it, the real channel
composer accepts a draft. The existing thread summary supplies the thread
identity, so the armed lookup gate is unused: this proves a cached identity
opener, not delayed lookup handling.

| Receipt | Actual result |
| --- | --- |
| `.local/grid-task-source-v1` | Failed: the assumed visible Tasks tab could not be clicked. |
| `.local/grid-task-source-v2` | Failed at the same missing control; the arrival PNG, DOM and real store confirm workspace active with zero channel tab controls. |
| `.local/grid-task-source-v3` | Failed: the supported `chatTab=tasks` URI mounted the channel task body, but the runner selected a server-board title absent from that real channel bucket. |
| `.local/grid-task-source-v4` | Strict raw URI-retention check failed in all themes. Nevertheless, the real channel card opened the global task store while every sampled task frame contained zero visible task surface/title and grid tabs stayed unchanged. Raw URI changes remain intact. This deep-link input does not prove a reachable channel Tasks tab. |
| `.local/grid-task-source-v5` | Reachable footer behavior observed in all themes: independent grid thread tab, no global task store/anchor/modal; 262 / 159 / 161 DOM samples plus stage PNGs. |

The footer fixture SHA-256 is
`4bc45dda557a6fe313fb66f823056061cd69ec06a63c0857368330124b7341f2`.
Source input is
`799c42a7703b30e809471e9835dfeeb1adbb75c06ae8689562685970292fef17`;
the exact runtime and runner hashes are in each immutable `report.json`.
DOM samples and stage screenshots do not constitute a continuous Chromium
compositor stream, a matched Flutter pixel pair or native platform proof.

## Bounded Flutter correction

Grid channel `ConversationPanel` now receives `hideHeader`; its invented tab
controls disappear while the accepted editor and URI-selected bodies retain
their existing owners. Its channel header was already absent in the inspected
product; no additional header is removed. Independent grid thread tabs remain
the next phase.

`WorkspaceTaskHost.presented` separates presentation from the independent task
owner. Active non-content grid routes omit the global task surface. The task
identity, authorized client and in-flight acceptance fences remain alive; a
hidden borrowed discussion has no foreground presentation and sends no hidden
read acknowledgement. Leaving the grid at the actual 1024px breakpoint restores
the same task/discussion owner and its draft without a second detail request.
Search/Activity retain Source's earlier content-route exception. Closing or a
server authority change still retires the owner.

`workspace_grid_task_presentation_test.dart` includes twelve three-theme actual
`WorkspaceView` cases. Real mode clicks, text input, cursor changes, resize and
visible task Close exercise retained root/grid/task drafts and accepted channel
windows. Task URI and content-route identities are explicit fixture inputs;
these tests do not claim a Source grid Tasks-tab opener or native Back input.

| Check | Result | Private receipt |
| --- | --- | --- |
| Container plus task/grid/authority/entrypoint regression set | 89 passed | `.local/task-grid-container-regression-v3.log` |
| Final captured-owner container cases | 12 passed | `.local/task-grid-container-v4.log` |
| Final selected analysis | Clean | `.local/task-grid-container-analysis-v2.log` |
| Design-system scanner/ratchet | 6 passed, no growth | `.local/task-grid-container-ds-v1.log` |

The first container test attempt `.local/task-grid-container-v1.log` retains
three passes and three failures from counting both raw title widgets during
Flyer's hidden staging. The revised check waits for one actually hit-testable
title with a bounded frame limit; it does not delete or normalize that failure.
The old global-modal callback and its Flutter-only tests are archived under
`.local/grid-task-flutter-only-experiment` and are absent from the product.

K10b remains partial: independent grid thread tabs, grid task-card routing,
legacy docking, modern/legacy composition, exact task pixels and native task
process comparison remain outside this commit. The suppressed deep-link card
observation is recorded as Source behavior, without inventing a visible modal
to make that otherwise unreachable tab useful.
