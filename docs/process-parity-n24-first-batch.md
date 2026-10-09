# N24 Activity gesture process evidence

N24g controlled Linux behavior passes in all three themes against the integrated
root baseline c17f149. These are native-engine layout/layer receipts with the
physical-window and geometry limits below. They do not describe later Root
product commits; old failures remain unchanged.

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


## Separate cached-window failure after canonical Back

`pair-after-thread-double-v5-brutal-desktop.json` remains **FAIL**. Source's
`after-thread-double-v5/source-brutal-desktop` completes; native
`flutter-after-thread-double-v5-brutal-desktop` records 264 layout observations
and18 raster PNGs and completes with one pending-state failure: the already
accepted Android tail is absent while its uncached target context waits. The
later target accepts and centers. Its fixture is
`85bfcae038858f916e479734017c0d559523b23ef800749017125fe1b7e7a056`,
with the same native product SHA as the successful thread double above.

This is an accepted in-memory bucket contract. Source's fresh browser context
starts with no persisted message fixture. Android tail requests49/59 accept
before the first visible `accepted-tail`; design-channel tails106/118 then
accept during the canonical thread. Android target context160 is held. At the
`pending-context` checkpoint, the old Android tail is visible before gate
release181; there is no new Android tail GET until185 after context acceptance.
The exact chronology is retained in the Source receipt.

Source `messageStore.ts:1246–1252` selects a per-channel bucket and
`ChatPanel.ts:223` subscribes to that selector. `loadMessageContext` at
`messageStore.ts:2374–2412` publishes loading/current channel without clearing
that existing accepted bucket; response acceptance replaces it atomically at
2440. This does not authorize displaying an unaccepted disk or other-channel
window. The message-controller owner has this independent failure and its
Source evidence. The detector still requires the retained window.


## Owned-focus correction: new native receipts

After the committed E67dd8e owned timer correction, all three desktop
`N24/thread-single` pairs pass behavior admission with the original sampled-frame
limits. A separate Brutal `N24/channel-after-thread-single` pair also passes.
The earlier v4 URL failures are retained unchanged; these are new v6 outputs.

| Pair under `.local/process-parity-c/` | Source layout/PNG | Native Linux layout/PNG | Outcome |
| --- | --- | --- | --- |
| `pair-thread-v6-brutal-desktop.json` | 324/84 | 144/13 | BEHAVIOR_PASS_WITH_LIMITS |
| `pair-thread-v6-elegant-light-desktop.json` | 347/71 | 96/13 | BEHAVIOR_PASS_WITH_LIMITS |
| `pair-thread-v6-elegant-dark-desktop.json` | 306/68 | 154/12 | BEHAVIOR_PASS_WITH_LIMITS |
| `pair-after-thread-v6-brutal-desktop.json` | 508/123 | 234/16 | BEHAVIOR_PASS_WITH_LIMITS |

Native product SHA is
`a5edf3453cb017cb3c92f41b9c6510744e21ae166e2b086a96e3753cea7136b3`.
The thread input retains SHA01afd535… and the subsequent-channel input retains
SHAb0d41563… from the full hashes above. Source input remains799c42a7…;
both providers bind runtime
`ba8f7cb55572030b1651e1b2aace7cf98b4e6b65af3983d67852035171aefd1f`.
The recorded maximum renderer timestamp gaps across these pairs are
1.02–1.94 seconds, including quiet unchanged periods. They do not prove absence
of unobserved intermediate paints.

The private Linux thread pane remains x624/w816 versus Source x626/w814, and
its focused reply wrapper remains62px versus36px. Its vertical center and
independent parent acceptance are correct, but geometry/pixel parity is not
claimed. Native Android and the root-integrated product require their own bound
receipts. This section predates the accepted-window correction below; its failed receipt
remains unchanged.

Pair admission also rejects identical missing/malformed Source or runtime
fingerprints and missing native device/platform; it never infers Android from
390px width or fills absent native identity with Linux defaults. Five receipt
admission tests cover these failure boundaries. They are host unit checks,
not renderer execution.


## Root-baseline accepted-window correction: N24g

After E f237e34 was integrated as rootc17f149, the exact previously failed
subsequent-channel double fixture passes behavior admission in all three desktop
themes. The tested private tree is identical to rootc17f149's full Git tree,
`fc538e6b3eb0e603372c06ed8cedb686660de31b`; every native receipt records product
SHA `2da7940f898e71ecbbc669ed9ebd9c92700c1c3cdd17c6b3fe68395e35b5fa9c`.
This evidence belongs to that integrated baseline, rather than the earlier private
a5edf345 tree or a later Root product. Root advanced to5e155f4 during capture;
its typed Search callback changes alter the product hash and are outside these
receipts. The verification owner accepted the completed c17 baseline and assigned
full-app window verification separately.

N24g maps to the unchanged fixture's `N24/channel-after-thread-double`
requirement. Its exact input SHA remains
`85bfcae038858f916e479734017c0d559523b23ef800749017125fe1b7e7a056`.
Both providers bind Source input799c42a7… and runtimeba8f7cb5… as recorded above.

| New pair under `.local/process-parity-c/` | Source layout/PNG | Native Linux layout/PNG | Outcome |
| --- | --- | --- | --- |
| `pair-n24g-root-v7-brutal-desktop.json` | 582/117 | 260/18 | BEHAVIOR_PASS_WITH_LIMITS |
| `pair-n24g-root-v7-elegant-light-desktop.json` | 506/106 | 257/19 | BEHAVIOR_PASS_WITH_LIMITS |
| `pair-n24g-root-v7-elegant-dark-desktop.json` | 482/101 | 237/19 | BEHAVIOR_PASS_WITH_LIMITS |

Source receipts are `n24g-root-source-v7/source-<theme>-desktop`; native receipts
are `n24g-root-flutter-v7-<theme>-desktop`. `n24g-root-v7-batch.json` binds the
pair, result, renderer-manifest and raw-layout hashes, counts and retained failed
receipts for all three cases. Native test exits and every individual Source/native
receipt pass; renderer inventories match their manifests.

While the context request is held, both sides restore the earlier accepted
Android tail, close the preceding thread, and preserve the channel shell and
composer. The restored tail keeps its initial checkpoint position on each side.
The context response then accepts the target and centers it with highlight;
canonical URI/expiry checkpoints match. The thread's independent parent/reply
hydration checkpoints remain admitted. The cache ownership boundaries are
specified in [the accepted bucket contract](accepted-context-bucket.md).

The old v5 pair is still FAIL with byte SHA
`eeca9008d546308d42bbc0fe1858430e002758eff7ea99501eeaa9771fb334d3`.
Its native failed result retains byte SHA
`7c8118e518a6d47f480d8a6eda1d7bc57b4122184ad3d3c5384e0cb2eddd7355`.
The new passing attempts do not rewrite those failures.

The configured layer viewport is1440×900, but these receipts report an actual
Linux window957×689 at DPR1. They prove native Linux-engine layout and rasterized
layers for the configured viewport; they do not prove the whole layout was
visible in that physical window or provide physical-pointer input evidence.
The greatest renderer timestamp gap is2.58 seconds. Unobserved paints remain
unproven. In Brutal, the restored tail focus wrapper is93px in Source and62px
in Flutter; both retain their own initial position. The canonical thread pane
starts at x1042/width398 in Source and x1040/width400 in Flutter, with focused
reply wrappers56/82px. These retained differences prevent any pixel-parity claim.
Android, live authentication/socket, backend read-back and the remaining process
matrix require separate evidence.
