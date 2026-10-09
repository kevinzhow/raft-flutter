# Task board and footer-chip openers

This bounded follow-up to [source-task-url-owner.md](source-task-url-owner.md)
wires the real channel Tasks tab and message footer chip to the existing task
URI owner. Source remains `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`.

`packages/web/src/components/task/TasksPanel.tsx:964–987` applies board
arbitration to the in-channel Tasks tab as well as the server board: modern
activation closes profile/legacy metadata and preserves ordinary side thread;
legacy activation retires ordinary side thread. The `intent: "task"` declaration
prevents a plain thread panel from replacing task properties.

`packages/web/src/components/message/MessageItem.tsx:3685–3700,4873–4886`
uses different arbitration for its footer chip. That action adds the independent
task slot while retaining other slots. The ordinary replies action continues
to open the side thread. The Flutter callback therefore keeps message-chip
intent separate from board intent. It forwards only accepted row facts and a
scope-checked projection refresh; no Markdown parsing or inline reference
behavior was changed.

`ConversationPanel` forwards the Tasks-tab callback to the real ResourceView
and the footer-chip callback to the retained RaftChatView. WorkspaceView wires
the same callbacks in its classic conversation and Activity/Search conversation
preview. Its ordinary side timeline also receives the footer callback. Optional
callbacks retain standalone callers' existing behavior.

## Actual evidence

| Check | Result | Private immutable receipt |
| --- | --- | --- |
| Both actual openers, three themes at 390px/1280px | 12 passed | `.local/task-entry-mounted-v4.log` (plus the two projection cases) |
| Six related task-route, conversation, affordance and projection test files | 47 passed | `.local/task-entry-regression-v5.log` |
| Selected analysis | Clean | `.local/task-entry-analysis-v1.log` |
| App design-system ratchet | No growth; 696 findings | `.local/task-entry-ds-v1.log` |

The entry cases tap the actual channel Tasks tab/card or actual footer chip,
hold the real task-detail request, observe URI/history/arbitration, release the
accepted task and close with Escape. They verify that the main composer retains
its element, TextEditingController, text and cursor. Desktop cases also retain
the ordinary side anchor and draft. A mobile main opener is tested with the
main pane actually visible; mobile side-thread retention is covered separately
by the earlier cold URI cases.

The pre-existing projection refresh case used to assume a second HTTP read
while the same channel bucket was already pending. Its real failure remains in
`.local/task-url-projection-old-v1.log` (one passed, one failed). The replacement
uses the Source `store/taskStore.ts:440–467` pending-read contract, then changes
the real principal before accepting the new read. It verifies that the old
response cannot repopulate the newer principal.

New-test attempts are also retained: `.local/task-entry-mounted-v1.log` failed
because the runner referenced a missing test file; `v2` failed with an incomplete
channel fixture and an inaccessible narrow main composer behind an open thread;
`v3` passed eleven and failed three when the fixture returned one task for every
status lane. The final fixture honors the actual status query and targets a
reachable opener. No product warmup or detector normalization was added.

## Remaining boundaries

K10b remains partial. This batch does not wire independently owned workspace-grid
conversation callbacks, render legacy dock/resizers, prove unknown-parent cold
discussion, or reproduce exact Timeline/assignee pixels. A board action that also
removes a profile continues to use the existing general navigation revision;
profile-removal with an independently pending main request is not claimed.
Task-only opening retains the main request ticket as proven in the prior batch.
There is no real Linux/Android task process pair or new task screenshot result
from this follow-up.
