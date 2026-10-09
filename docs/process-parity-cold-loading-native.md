# Controlled cold loading and obsolete response pairs

Twelve actual Source App / Linux `WorkspaceView` desktop pairs return
**BEHAVIOR_PASS_WITH_LIMITS**: four flows in Brutal, Elegant light and Elegant
dark. They establish the observed loading transitions and obsolete-response
ownership below. They do not establish pixel equality, physical desktop input,
the complete process matrix or Android behavior. Earlier failures remain intact.

## Bound application and detector

The application is the committed Root baseline
`86309efc70c378b69603d7de481eb66efe349aac`, whose engineering source hash is
`b68f51e81a81ae40cf71b4f3cc5e5a43c9f9c1e6abad2b911f801a2a3e85e4f8`.
No product file changed in this detector batch. The separately scoped process
product SHA, identical to Root at that commit, is
`f0749c169f494d1a7962d48e2d02fbf9d80972c16d55433e07a66d0af156bd7c`.
These receipts belong to that baseline, regardless of subsequent Root commits.

The integration probe changed its opener and desktop input. The cold-run test
SHA is `60e59e440017efeb8fd9ba7fd211da0d1706322b2a8ee90207233854bf39bfb4`;
the final stale-run test SHA is
`da865455f0dcb291c39c22a01d504e034d753613b9cdcf4da95d277176202242`.
The latter probe's engineering source hash is
`2e39e728589cd01cb6f5e4f770067ad970e42bbf19ac892022228f5321c991a5`.
It differs from Root's engineering hash because that scope includes tests.
Individual receipts bind the detector that actually executed; documentation
and later comparator corrections do not relabel it.

Source remains `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, with input SHA
`799c42a7703b30e809471e9835dfeeb1adbb75c06ae8689562685970292fef17`.
The controlled HTTP runtime SHA is
`ba8f7cb55572030b1651e1b2aace7cf98b4e6b65af3983d67852035171aefd1f`.
Source and native use identical fixture bytes in every pair. No Source product,
store, calibration or threshold changes were made.

## Valid mounted inputs and assertions

| Flow | Real input and observed contract |
| --- | --- |
| Known cold channel | Start on the accepted design conversation; click the actual Android sidebar row. Hold its tail GET. The known header, Chat/Tasks/Files and composer are present before the message response, without fabricated accepted rows or a positive unaccepted read ACK. Release the tail and observe its accepted row. |
| Unknown channel identity | Use the actual Activity row with a valid message anchor. Hold real metadata and message context independently. Before metadata, the resolution placeholder appears without tabs, composer or accepted target. After metadata, the known shell appears while context still waits; release context and observe its accepted target. |
| Back → new target → late success | Hold A's focused context, return to Activity, open B, accept B's context, then actually deliver A's successful response. Every observed late-response layout retains B and its URI; A does not paint, restart a fallback tail or advance A's accepted read frontier. |
| Back → new target → late error | The same ownership sequence delivers A's real HTTP error after B acceptance. Cancellation alone is rejected as proof. |

Source authority, relative to `packages/web/src`:

- `components/layout/Sidebar.tsx:851,861` supplies the actual sidebar row and
  selection. `hooks/useAppNavigate.ts:492–511` distinguishes channel navigation
  from focused message navigation. `store/inboxStore.ts:133` requires the
  Activity row's `lastMessageId` to be a string.
- `components/layout/MainLayout.tsx:394–440` and
  `store/channelStore.ts:265–301` resolve real identity and its placeholder.
  `components/message/ChatPanel.tsx:1345–1534` separates known controls from
  the message loading body.
- `components/thread/ThreadsInbox.tsx:1020–1176` owns canonical Activity
  activation. `store/messageStore.ts:643–655,2374–2486` owns accepted windows,
  request replacement and obsolete-result rejection. The surrounding sequences
  are in the [source loading contract](source-message-loading-contract.md).

The desktop Source gesture is browser history Back. The native gesture focuses
the actual composer `TextField`, checks its live `FocusNode`, then dispatches
Escape to `WorkspaceView`'s supported history action. Flutter's test framework
dispatches the key; this is not a hardware-keyboard proof. Wide platform pop is
not equivalent: `workspace_view.dart:943–953` permits window closure on this
non-thread route. No product PopScope change was made to accommodate the probe.

These cold windows open after provider/bootstrap discovery; this is not a full
authenticated cold-launch test. The unknown input uses a focused context, while
the known input uses an unfocused tail. Their metadata DTO is the same, but
their opener and requested windows are deliberately distinct valid contracts.

## Actual counts and retained gaps

Each cell is `Source DOM observations / CDP PNGs; native layout observations /
layer PNGs`. All cells are bounded paired PASS.

| Flow | Brutal | Elegant light | Elegant dark |
| --- | --- | --- | --- |
| Known cold tail | `241/51; 48/7` | `132/44; 45/7` | `130/44; 44/7` |
| Unknown metadata/context | `263/42; 55/9` | `177/35; 56/9` | `178/37; 58/9` |
| Late A success after B | `409/97; 57/12` | `319/73; 65/14` | `222/101; 58/13` |
| Late A error after B | `326/92; 73/13` | `220/77; 70/13` | `221/81; 69/13` |

The selected held cold observations total Source177/native153; selected
late-response observations total Source163/native117. Their invalid-observation
arrays are empty. All six stale pairs contain actual late HTTP response records
after B acceptance, including failures; none substitutes client cancellation.
The detector changes the held-stage label before releasing HTTP, so accepted
responses are not counted as held observations.

CDP's largest gap in each capture ranges from 1.207 to 4.036 seconds. Native
changed-layer capture gaps range from 0.523 to 0.954 seconds. Exact per-capture
gaps remain in the index. DOM rAF rectangles are not compositor assertions, and
emitted PNG samples cannot prove every intermediate paint.

Source is configured at 1440×900. Native reports its actual Linux physical window
as **957×689, DPR1**, while the integration layer is configured at 1440×900.
Native layer PNGs and layout checks therefore are renderer/layout evidence;
they are not matched physical-window scanout or desktop hardware-input evidence.

## Pending replacement is a different prestate

Source enters directly through Android and has not accepted B's design window.
Native bootstrap previously accepted design. While B's new context waits,
Source records a visible `Loading…` surface and no channel scroller; native
records a scroller with three real previously accepted design IDs. The raw
Source selector's `messageLoading` flag is false despite that visible surface.
This pair does **not** claim identical B-pending lists. The shared assertion
starts after B's target context is accepted and proves obsolete A ownership.

The first optional cache-prelude summary missed this difference because it used
that generic flag. Fresh supplemental summaries use recorded surface/scroller
visibility and accepted native IDs, with a regression check for the real false
flag case. Original captures and all twelve original pair files remain unchanged.

## Immutable evidence

Private evidence root:
`/home/kevinzhow/github/raft-flutter-wt/cody-parallel-members/.local/process-loading-c/`.
The batch index `native-root863-loading-batch-v1.json` binds all twelve receipts,
raw layout streams, renderer manifests, pair hashes, input hashes and limits.
SHA: `4944fcc365160fd0941cbe99fead726a9c60c23e4c1473a3f758b93114150197`.
Every bound receipt, layout, renderer-manifest and pair hash was read back.

The separate cache-label supplement
`native-root863-loading-cache-label-v2.json` binds six fresh comparator outputs
to those same raw captures. SHA:
`84753b1cc9ea68b2f5312127bbe5bd0c6b5e592d9a97d6ac7169d98353df9e58`.
It adds the explicit different pending prestate; it is not a native rerun.

| Exact fixture SHA | Source/native output directories below evidence root |
| --- | --- |
| `25545af8619ddc7945c40f10de998de7b6b1e3970329deab01cfcb6604f4a17b` | `native-known-root863-sidebar-v2/{source,flutter}-<theme>-desktop` |
| `c2c654be73092dd13da7fdbf785cd8d85855e70c6473c82099057d996887bf2c` | `native-unknown-root863-valid-v2/{source,flutter}-<theme>-desktop` |
| `327358281ad1767fddd10800161d6ce2e9296de0c5373a16ea2fb0d9548ef263` | `native-stale-success-root863-escape-v3/{source,flutter}-brutal-desktop`; other themes in `native-stale-success-root863-escape-v3-rest/` |
| `c99b1b3a26d28bd812f1582121e0c8cb25e2aba832d79d96111b155af0da5ea0` | `native-stale-error-root863-escape-v3/{source,flutter}-<theme>-desktop` |

Retained failures:

- `pair-known-root863-v1-brutal-desktop.json`: invalid Activity DTO with
  `lastMessageId:null` produced Source `?msg=null`; native omitted it. Strict
  pairing failed. Fresh known/unknown fixtures use the real sidebar or valid
  anchor; null was neither normalized nor copied into the app.
- `native-stale-success-root863-v1/`: all three wide platform-pop attempts
  closed the native app while A waited. Partial manifests, CLI errors and the
  corresponding aborted-pair FAILs remain.
- `native-stale-success-root863-escape-v2/`: all three attempts clicked the
  outer composer container rather than its editor, so Escape had no focused
  history action. The unchanged URI and native FAILs remain. The fresh v3
  detector verifies editor focus before dispatch.
- Earlier Source-only failures, invalid cold receipts and the HTTP-boundary
  correction remain in the [historical first report](process-parity-cold-loading-first-batch.md).

## Reproduce without altering old inputs

Coordinate exclusive Linux integration ownership first. From this checkout:

```sh
python3 tool/process-parity/run.py --out .local/<fresh-known> --fixture .local/process-loading-c/known-valid-sidebar-v2/fixture.json --only brutal-desktop,elegant-light-desktop,elegant-dark-desktop --port <owned-port>
python3 tool/process-parity/run.py --out .local/<fresh-unknown> --fixture .local/process-loading-c/unknown-valid-activity-v2/fixture.json --only brutal-desktop,elegant-light-desktop,elegant-dark-desktop --port <owned-port>
python3 tool/process-parity/run.py --out .local/<fresh-stale> --fixture .local/process-loading-c/stale-error-v1/fixture.json --only brutal-desktop,elegant-light-desktop,elegant-dark-desktop --port <owned-port>
python3 tool/process-parity/compare-pair.py <source-dir> <flutter-dir> --out <fresh-pair.json>
```

The success flow uses `stale-success-v1/fixture.json`. Existing outputs are never
overwritten. Fixture-only local HTTP does not depend on Root's backend,
RisingWave or real credentials. All private runtimes and native apps for this
batch were closed after completion, and Linux ownership was released to Root.

Tool validation passes 2 loading-fixture tests, 8 paired-input/race/cache tests
and 3 existing Activity-fixture tests, Node syntax, Dart formatting and
integration-entrypoint analysis. Android5580, live authentication/socket/backend
read-back, authority revocation and the remaining process matrix are NOT RUN
by this batch. No public publish or Git push occurred.
