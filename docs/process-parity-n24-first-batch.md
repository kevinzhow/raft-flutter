# N24 Activity gesture process evidence

This report separates `N24/channel-single`, `N24/thread-single`,
`N24/channel-after-thread-single` and double-click gestures. The earlier desktop
channel pair covers one gesture on one platform. It does not complete N24.

Authority is the mounted Source at
`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`:

- `packages/web/src/components/thread/ThreadsInbox.tsx:1036–1107`: desktop
  double-click leaves Activity through one canonical navigation; single-click
  is deferred 220 ms. Narrow/mobile opens directly.
- `ThreadsInbox.tsx:1118–1151`: desktop thread rows seed the known thread ID and
  open the thread content slot directly. Canonical/mobile routes hydrate through
  URL ownership. A channel row closes the previous thread at lines1163–1174.
- `packages/web/src/store/threadStore.ts:367–393`: a known thread ID publishes
  identity before requests and skips the lookup.
- `packages/web/src/components/message/ThreadPanel.tsx:1275–1440,1458–1510`:
  focused reply context and uncached parent metadata load independently. Parent
  context is not an accepted outer message window.

## Immutable fixture boundaries

The original channel fixture remains SHA256
`8112e525b7ab6a14313aa34bb2edd2488fb2030bc84876bcc94662f8ae04ee6d`.
`build-thread-fixture.py --base <fixture> --out <new-fixture>` creates a new
input; it never overwrites that base. Each derived input records the base SHA.

The thread fixture has 21 genuine reply DTOs, one focused target, and a parent
that is absent from accepted outer tails. Parent context, thread lookup and
reply context have separate gates. Known desktop identity skips lookup;
canonical/mobile identity can request it. The detector records which branch
actually requests the gate. The after-thread input retains the original Android
channel tail/context DTOs and then selects that channel from Activity.

The native detector uses actual WorkspaceView and real local HTTP. It records
thread identity, accepted parent, reply IDs, actual separate thread/channel
lists, visible controls and read requests. It rejects a channel-slot detour or
old thread surviving channel selection. Cold/race/revocation/entity flows remain
outside this batch. Transport, fixture checks and compilation do not substitute
for actual native execution.

## Source receipts retained

All paths below are under the private checkout `.local/process-parity-c/`.
Source input hash is
`799c42a7703b30e809471e9835dfeeb1adbb75c06ae8689562685970292fef17`.
These receipts precede the new Android host-handoff runtime; native comparison
must use the exact same recorded runtime hash or recapture Source.

| Receipt | Actual outcome | Observations |
| --- | --- | --- |
| `source-thread-v1-brutal-desktop` | Source stage PASS | 319 DOM frames,82 CDP PNGs; parent held while centered reply accepts; direct thread slot |
| `source-thread-v1-brutal-mobile` | Harness FAIL retained | Duplicate mounted parent IDs made a broad locator ambiguous; its outer tail also contained the parent, so it cannot prove independent uncached parent hydration |
| `source-thread-v2-brutal-mobile` | Source stage PASS | 319 DOM frames; scoped parent locator and real nonparent outer DTO preserve independent gates |
| `source-after-thread-v2-brutal-desktop` | Source stage PASS | 504 DOM frames; channel selection removes the prior thread before context accepts |
| `source-thread-short-v3-brutal-desktop` | Source stage PASS with short-window clamp | 346 DOM frames,118 CDP PNGs; separate one-reply fixture, not a centered 21-row claim |

The 21-row desktop reply remains at focus y=400,h=36 before and after parent
acceptance (viewport y=62,h=712; center error0). In the separate one-reply input
`2a2300c08143ea45b03e54a29683ed4560076e78834f1265306e1619ad96f6ee`,
Source focus moves y=124→238,h=62 when its 114px parent wrapper accepts. A short
window cannot center. This is a measured legal clamp, not a requirement to
reproduce a transient Web flash or a dense-window position error.

Source rAF observations precede compositing. CDP PNGs sample emitted compositor
frames, with timestamps and gaps retained. A Source stage PASS cannot remove
an earlier failed attempt or prove unseen first paints. Neither layer captures
physical screen scanout. New native receipts and paired claims are pending.

## Run and admission

```sh
python3 tool/process-parity/run.py --out .local/<new-run> --flow thread-single --only brutal-desktop --source-only
python3 tool/process-parity/run.py --out .local/<new-run> --flow channel-after-thread-single --only brutal-desktop
python3 tool/process-parity/run.py --out .local/<new-run> --fixture <exact-fixture.json> --only brutal-desktop
python3 tool/process-parity/fixture.test.py
node --test tool/process-parity/runtime.test.mjs
```

`--flow thread-double` and `--flow channel-after-thread-double` are distinct
inputs. Their product timer/gesture arbitration still requires actual native
receipts. The comparator binds fixture, Source revision/product-input hash,
runtime hash, gesture, theme and viewport, and labels the actual Flutter
platform/device. The original sparse channel pair still passes these stronger
input guards in the newly written `pair-v11-strict-input-comparison.json`;
its old artifacts are unchanged.
