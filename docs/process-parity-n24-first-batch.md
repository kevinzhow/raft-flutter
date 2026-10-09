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
for actual native execution. A desktop double-click uses the canonical parent
channel route with its thread; that legitimate parent pane is allowed. Only
single-click master/detail and narrow thread surfaces forbid the parent channel
pane (ThreadsInbox.tsx:1036–1107,1118–1151). Every branch still rejects the
unrelated previously accepted Android channel rows and an intermediate
`open=channel:<parent>` detour.

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

## First native N24 thread receipts

Private product SHA
`d85b04c39387d607aa493726f8c64b12e6d1b488810884666d5c99eb44d9586e`
includes the accepted E975d041/F83892e5 dependencies. This is not a receipt for a
different integrated product hash.

| Gesture | Native Linux checks | Strict Source pair |
| --- | --- | --- |
| N24/thread-single,Brutal desktop | PASS,126 layout frames/12 rasters | FAIL at `thread-highlight-expired`: Source removes `msg`, Flutter retains it |
| N24/channel-after-thread-single,Brutal desktop | PASS,277 layout frames/16 rasters; prior thread is retired before held channel context accepts | Same retained URI failure |

Paths are `{source,flutter}-thread-v4-brutal-desktop`,
`{source,flutter}-after-thread-v4-brutal-desktop` and
`pair-{thread,after-thread}-v4-brutal-desktop.json`. Fixture SHAs are respectively
`01afd535960ad4c1402176b953e3d5d31ee228614b81c1c0bda3fe0bdf999aba`
and `b0d41563350472ddfb7f0dd6e02240280bedbf9a40d75dc75699e62fdaee2c66`.
Both providers share each fixture's actual Source-input/runtime hashes.

The focused reply keeps center error0 before/after independent parent acceptance
on both sides, with matching y=62,h=712 viewports. Its wrapper is 36px in Source
and62px in this native tree. This retained geometry difference and sampled-frame
limits prevent any pixel-parity claim. The Source/Flutter URI mismatch has been
handed to the message-controller owner; it is not normalized away in comparison.
Additional themes, mobile-native and double gestures remain separate pending
receipts. A follow-up detector labels the actual test name with its N24 gesture
and checks all activation frames for an exposed channel list, in addition to the
checkpoint and intermediate-URI checks.


## First native canonical double-click pair

`thread-double-v5/source-brutal-desktop` and
`flutter-thread-double-v5-brutal-desktop` produce
`pair-thread-double-v5-brutal-desktop.json`: **BEHAVIOR_PASS_WITH_LIMITS**.
Source records 424 layout observations/79 compositor PNGs and Linux Flutter
records 145 layout observations/14 raster PNGs. The canonical URI, independent
parent/reply acceptance and expiry checkpoints match. The original single-click
URI failures above remain failures.

The exact derived fixture is
`6daae115117e578c46d0f3f48bd11e1a86bbc6598483ebb3bfd623fa0ab2b7f2`;
the original channel input remains unchanged. Native product SHA is
`ab24c0990a3ff332445c822723e7585c011877655b5002c92c2ff9e6e16a2a6f`
with committed canonical loading and focus-ownership dependencies. The paired
receipt binds both providers to the same Source-input/runtime hashes. It proves
this gesture on this Linux viewport, with the renderer and geometry limits
already stated; it is not an Android or whole-N24 receipt.

For the distinct subsequent-channel double gesture, desktop canonical routes
have no narrow Back control. The native detector delivers a platform pop event
to the real mounted PopScope; Source uses browser history Back. Neither receipt
claims physical keyboard or hardware Back-button input.
