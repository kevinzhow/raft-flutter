# K07: Activity content opening and authority frame evidence

The current desktop Activity adapter opens a thread content slot directly. A
channel or DM row opens its own content slot and retires the previous thread.
Existing actual-page tests already cover those normal paths. This batch adds
only the missing combination of actual row input, the first 220 ms timer frame,
authority withdrawal, and independently delayed private responses. All 15 new
cases pass across Brutal, Elegant light and Elegant dark. No product repair was
required.

This is a mounted Flutter test receipt. It does not promote the complete K07
checklist item, replace a native process receipt, or claim pixel parity.

## Inputs and ownership

- Product before this tests-only batch:
  `0d1997b91085f79d6a8fbd6d44bbac77b9e0ade2`.
- Source checkout:
  `/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source`,
  revision `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, Web 1.17.5,
  raft-ui 0.5.27.
- Flutter is the repository-pinned 3.47.6. The mounted page is 1440×900 at DPR 1;
  it receives actual `WidgetTester.tap` input on the production Activity row.
- The Source tree already contains other owners' changes to
  `packages/server/scripts/seed.ts`,
  `packages/server/scripts/verify-risingwave-inbox-parity.ts`,
  `packages/web/visual-testing/VisualTestingCases.tsx`,
  `scripts/dev/raftdev.ts`, and the untracked
  `packages/visual-testing/build/` directory. This batch changes none of them.
  No whole-tree clean claim is made.
- No product, SDK, fixture, threshold, baseline, allowlist, native detector or
  checklist data file is changed. Root's active matrices and their input hashes
  remain owned by Root and are not rebound to this private receipt.

## Fresh Source contract and current adapter

All Source paths below are under `packages/web/src` at the revision above.

| Source location | Contract used here |
| --- | --- |
| `components/thread/ThreadsInbox.tsx:1072–1102` | The mounted desktop master/detail consumer delays a single activation 220 ms. A second activation cancels that timer and opens the canonical route. Narrow layouts use their direct route path. |
| `components/thread/ThreadsInbox.tsx:1119–1148` | Desktop thread input seeds the actual parent identity and known `threadChannelId`, then opens the thread content slot directly. It does not first open the parent channel content slot. |
| `components/thread/ThreadsInbox.tsx:1160–1175` | A channel/DM input closes the prior thread and installs the appropriate content slot. Mobile mention focus has its own rule. |
| `store/threadStore.ts:367–391` | A known actual thread ID publishes the open identity immediately and skips the thread lookup GET. |
| `components/message/ThreadPanel.tsx:1378–1398,1466–1506` | Reply context uses the actual reply channel. Uncached parent metadata is an independent request; canceled or retired receiver-private ingress cannot install its response. |
| `store/receiverPrivateIngress.ts:63–74` | Private acceptance depends on generation, principal, selected server ID and server epoch. |
| `store/threadStore.ts:977–992`; `store/searchContentStore.ts:43–60`; `store/serverStore.ts:368–387` | The selected-server reset clears thread/content ownership and advances the server lifecycle. |

In the product input used for this batch,
`apps/raft_flutter/lib/features/workspace_view.dart:1532–1575` derives the typed
Activity destination, installs `DesktopContentKind.thread` directly, and calls
`openThreadIdentity` with the actual row's known thread ID and `navigate:false`.
It calls `openDesktopConversation` only for the nonthread branch.
`resource_view.dart:2060–2086` owns the actual 220 ms activation timer and checks
the captured authority and navigation revision before forwarding the row.

The historical `audit_note` in `tool/checklist/data/loading.json:283–294` and
`baseline-audit.json:333–338` points at an older parent-channel detour in
WorkspaceView. That description is stale for this product input. Those raw
historical files are preserved; this report supplies the current evidence for
Root's next mapping review rather than rewriting a started checklist run.

## Coverage reused without duplicate normal-path tests

| Existing test file | Existing actual coverage | Cases in this receipt |
| --- | --- | ---: |
| `workspace_activity_activation_test.dart` | N24a direct thread; N24b channel after thread; N24c DM; N24d real double input and cancellation. Actual WorkspaceView, held parent/replies, typed URI, separate channel/thread renderers and accepted unrelated main window. | 15 |
| `workspace_activity_canonical_cold_test.dart` | N24e uncached canonical parent; N25a/b narrow thread/channel focus, history and Back. | 15 |
| `mounted_activity_boundaries_test.dart` | Actual evaluated flag branches at 767/768/1023/1024 px and narrow DM focus. | 33 |
| `pending_thread_revocation_test.dart` | Accepted controller/cache purge plus separately mounted ChatView privacy cases. Its widget cases do not exercise an Activity row in WorkspaceView. | 8 |

The normal desktop opening tests above observed frames after the timer expired.
The new cases assert the actual timer frame itself before another dispatch or
16 ms frame can hide an intermediate surface. They also exercise the missing
input-to-withdrawal composition through actual WorkspaceView.

## New actual-page cases

The new file is
[`workspace_activity_authority_frames_test.dart`](../apps/raft_flutter/test/workspace_activity_authority_frames_test.dart).
It uses the real WorkspaceController, ResourceView, SDK row, WorkspaceView,
RaftThreadHeader and RaftChatView. The local Dio adapter holds the real context
requests; it does not replace controller navigation or acceptance methods.

| Scenario, repeated in all three themes | Observed assertions | Cases |
| --- | --- | ---: |
| Actual row input, principal withdrawal at 120 ms | Timer expiry launches no old parent or reply context; no thread header or private paint appears. | 3 |
| Actual row input, server withdrawal at 120 ms | Same timer and paint checks across the retired selected-server scope. | 3 |
| Actual row input, principal withdrawal after the 220 ms first thread frame | First frame is the actual thread header/list, with no outer channel header or painted unrelated main window. Parent and reply requests use their distinct real channel IDs; the known hint skips lookup. Every subsequent retirement/late-response test frame rejects private paint and new old-scope read POSTs. | 3 |
| Actual row input, server withdrawal after that first frame | Same independent pending requests and frame assertions across the new selected-server authority. | 3 |
| Actual row input, accepted painted reply, then accepted parent-channel removal while parent HTTP waits | Real `refreshChannels` accepts a list without the parent channel. From its acceptance frame the reply and parent cannot paint; the thread cache/identity retire, unrelated accepted main data remains, and the late parent cannot restore private content or generate another old read POST. | 3 |

The route listener checks every observed location for both a canonical
channel/DM detour and an intermediate channel/DM content slot. The paint helper
requires an attached nonzero-opacity message inside the actual viewport; a
controller message ID alone is insufficient. Retirement is observed on every
one of twelve zero-duration dispatch pumps, followed by sixteen 16 ms late
response frames. Parent-channel removal is checked from the actual accepted
channel-list frame, rather than treating earlier still-authorized frames as
revoked.

Principal/server cases replace accepted identity state and notify the mounted
page. They prove this page's authority boundary, not a real login/logout,
server-menu hydration, websocket or backend membership workflow. The
parent-channel case extends the existing accepted Flutter purge contract
through the page and real input. Its exact post-revocation header/URI shape has
not been paired with a Source browser channel-revocation run; no such matched
UI claim is made.

## Execution and limits

From `apps/raft_flutter`:

```sh
../../tool/flutter test test/workspace_activity_authority_frames_test.dart test/workspace_activity_activation_test.dart test/workspace_activity_canonical_cold_test.dart test/mounted_activity_boundaries_test.dart test/pending_thread_revocation_test.dart --no-pub --reporter expanded
../../tool/flutter analyze test/workspace_activity_authority_frames_test.dart --no-pub
```

- **86 PASS**, including the 15 new cases. Private exact final receipt:
  `.local/k07-workspace-source-final-exact.log`.
- Scoped analysis: **no issues**. Receipt:
  `.local/k07-workspace-source-final-exact-analyze.log`.
- Earlier passing attempts remain in `.local/k07-workspace-authority-first.log`,
  `.local/k07-workspace-source-regressions.log` and
  `.local/k07-workspace-source-final.log`. The initial analyzer naming diagnostic
  is preserved in `.local/k07-workspace-authority-first-analyze.log`; the
  listener was subsequently changed to a named bound method.

There was no failing product observation in this batch and no product fix.
This test clock proves the asserted mounted frames, not physical scanout or
unsampled native frames. No new Source browser, Linux native, Android native,
backend or visual execution occurred here. The separately owned historical
process evidence in [process-parity-n24-first-batch.md](process-parity-n24-first-batch.md)
retains its exact older product hashes, failures and geometry limits; it is not
relabelled as a receipt for this input. Current native/full-matrix and checklist
admission remain Root's independent work.
