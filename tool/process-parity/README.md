# Controlled message process comparison

The runner renders the pinned, actual Source `index.html → main.tsx → App` and
actual Flutter `WorkspaceView`, using the same immutable public DTO fixture over
real local HTTP. Only fixture responses are gated. Unknown requests fail with
404; Source stores and product files are unchanged. Request/response/gate order,
wall timestamps, status and input hashes are preserved.

The original verified pair is **Activity → uncached target in an already accepted
channel**. The runner also supports separately labeled thread opening and
channel-after-thread gestures; their native receipts and retained failures are in
the [N24 report](../../docs/process-parity-n24-first-batch.md). Cold-channel,
cached-target, race/revocation and entity-hydration flows remain outside this
batch. Three actual themes and 390×844/1440×900 are selectable inputs; a supported
input is not a completed platform/matrix claim.

## Run

Use pinned Flutter 3.47.6 and installed pinned Source dependencies. Prepare the
private Linux media bundle with `./tool/prepare-media-linux` before its first
build. Coordinate Linux integration ownership with other workers. This runner
uses private Xvfb; no Android5580, real account/backend or shared native fixture.

```sh
python3 tool/process-parity/run.py --out .local/process-<new-attempt> --only brutal-desktop
python3 tool/process-parity/run.py --out .local/process-<new-matrix> --only all
python3 tool/process-parity/run.py --out .local/source-<new-attempt> --only all --source-only
node --test tool/process-parity/runtime.test.mjs
```

Every output path must be new. Failed attempts remain failures. The manifest
labels Source-only runs separately. No fixed delay substitutes for a held
response. The runner terminates its own runtime at completion.

Both sides accept a genuine canonical channel DTO, seq200 tail, then a seq300
context target with 21 rows so centering is observable. Source enters through
its real channel URI; Flutter bootstraps normally and selects the same channel
through the real sidebar. The assertion pre-state is the accepted visible tail.

## Evidence and assertions

Five checkpoints preserve PNGs, raw observations and actual HTTP chronology:
accepted tail, Activity, held context, accepted context, expired highlight.
Assertions require old accepted row, header, tabs and composer while held,
then the centered highlighted canonical target and two-second expiry. Before
release, a read POST cannot advance beyond accepted seq200. Flutter records
checkpoint failures and continues independent checks.

Source records every DOM rAF observation plus Chromium CDP screencast renderer
PNGs, ACKs and metadata timestamps. Flutter records post-frame layout state and
rasterizes changed actual RenderRepaintBoundary display-list layers, including
the first exposed target. These surfaces are labeled separately. Neither is
physical screen scanout. Sampling gaps remain observable; missing frames are
not invented. There is no pixel score or acceptance threshold change.

```sh
python3 tool/process-parity/compare-pair.py <source-dir> <flutter-dir> --out <new-pair.json>
```

Pair comparison checks input identity, completed receipts, renderer manifest
integrity and semantic checkpoint URIs. Success is `BEHAVIOR_PASS_WITH_LIMITS`.
Missing/malformed input fingerprints and missing native platform/device fail
admission. It retains transient missing controls/offsets; final checkpoints do not erase
intermediate observations or exclude unobserved paints.

Source authority at `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`:
`packages/web/src/store/messageStore.ts:2374–2460`,
`components/message/ChatPanel.tsx:581–597,1484–1534`,
`components/message/MessageTimeline.tsx:1028–1036`, `hooks/useMobileNav.ts:89–109`
and the mounted Activity handler. Consult the
[source loading contract](../../docs/source-message-loading-contract.md) and
[navigation contract](../../docs/source-navigation-contract.md).

Authentication, Socket.IO, backend read-back, Android, real permission changes
and final visual parity remain separate evidence. These read POSTs prove client
presentation gating against the controlled endpoint.

## Android transport (caller-owned device)

Android fetches the exact raw fixture bytes from `/__process/fixture`, checks
fixture SHA against host declaration and runtime state, and writes only a new
named subdirectory of its own `getTemporaryDirectory()` cache. Host product/test
hashes are required because Android does not have the Git checkout. Receipts
record actual OS/device, physical size/DPR and configured390/1440 viewport;
Linux390 is still Linux. The fixture client uses MemorySessionStore, mock
preferences, no persistent WorkspaceCache and no socket; main/auth/secure-store
entrypoints never execute. Existing account/keyring data is not cleared.

After starting the isolated runtime, the device owner runs:

```sh
tool/process-parity/capture-android.sh <exact-fixture.json> <new-host-output> brutal mobile emulator-5580
```

This wrapper verifies served bytes before installation, binds host input hashes,
sets `adb reverse tcp:15413 tcp:15413`, runs the actual integration entrypoint,
then collects only its freshly registered host-side receipt. The test uploads its
private files before returning; host acknowledgment follows input/hash/PNG
validation and fsync. Collection therefore survives Flutter uninstalling its test
app during driver teardown. Unknown/reused run IDs and incomplete uploads fail;
partial payload/error files remain under the runtime output.
Use `RAFT_PROCESS_PORT` for an independently owned fixture port. It preserves
native failure exit/log and attempts artifact readback even on a failed test.
It does not clear app data or remove retained device artifacts. Device execution
is **NOT RUN** by this tool author; the device owner must provide actual proof.

Android transport host checks:

```sh
node --test tool/process-parity/artifact-handoff.test.mjs
```

The host validates a complete result, layout observations, renderer manifest and
PNG inventory before acknowledgment. Every PNG chunk CRC and decompressed pixel
length is checked. Host readback also checks every byte hash and declared device,
fixture/product/test hashes. It rejects old run IDs and never falls back to
previous output. This transport check does not prove Android rendering; the
device owner must rerun in a fresh output directory.

## N24 thread and subsequent-channel gestures

These are separate process entries, not completion of the whole N24 item:

```sh
python3 tool/process-parity/run.py --out .local/<new-thread> --flow thread-single --only brutal-desktop --source-only
python3 tool/process-parity/run.py --out .local/<new-after-thread> --flow channel-after-thread-single --only brutal-desktop
python3 tool/process-parity/run.py --out .local/<new-exact-input> --fixture <exact-fixture.json> --only brutal-desktop
python3 tool/process-parity/fixture.test.py
python3 tool/process-parity/pair.test.py
```

Thread lookup, parent context and focused replies are independently held. Known
Source desktop thread IDs skip lookup; canonical/mobile routes can request it.
Both actual branches are retained. The parent is kept out of accepted outer
channel DTOs so a background loader cannot silently satisfy the held metadata.
A separately labeled `--short-thread` fixture measures a legal short-window
scroll clamp. It does not pretend that one reply can center in an unscrollable
viewport. `thread-double` and `channel-after-thread-double` retain separate
requirements. See [N24 process evidence](../../docs/process-parity-n24-first-batch.md)
for source receipts, failures and native execution limits.
