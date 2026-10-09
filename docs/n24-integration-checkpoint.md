# N24 checkpoint: owned navigation and actual thread rendering

The integration snapshot `1b87eef` passes 1928 project tests (3 existing skips),
75 host tool tests and analysis. It contains the mounted single/double Activity
handlers, uncached parent resolution, thread Close using REPLACE, scoped focus
consumption and pending private-thread revocation. These checks do not complete
all navigation, full application E2E or visual parity.

The checklist distinguishes verified, partial, missing test evidence and not
started. Historical implementation review can describe incomplete work but
cannot supply current verification. Its separate verifier checksum covers the
collector, requirements and page renderer, which are outside `tool/source-hash`.

## Actual Android thread process

The controlled Source App and actual Android WorkspaceView ran against identical
immutable DTOs over held local HTTP responses. Source is pinned to
`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`. Brutal mobile canvas was 390×844;
actual device was `emulator-5580` and its physical geometry is retained separately.

- Fixture SHA: `01afd535960ad4c1402176b953e3d5d31ee228614b81c1c0bda3fe0bdf999aba`.
- Runtime SHA: `ba8f7cb55572030b1651e1b2aace7cf98b4e6b65af3983d67852035171aefd1f`.
- Source input SHA: `799c42a7703b30e809471e9835dfeeb1adbb75c06ae8689562685970292fef17`.
- Source: 315 DOM observations and 55 CDP renderer PNGs.
- Android: 157 layout observations and 14 changed-layer raster PNGs.
- Native execution and durable pre-teardown host readback: PASS.
- Strict pair: `BEHAVIOR_PASS_WITH_LIMITS`; no input or stage failures.

The first observed reply is centered (0px measured error) and highlighted on both
sides. Thread metadata and parent requests are independently held; canonical
message query survives expiry as Source does. The Source pending composer gap
(16 DOM observations) and Flutter gap (4 layout observations) are retained.
Thread panels have no channel tabs. All renderer timestamps remain in the raw
manifests; maximum gaps are 1150.25ms for CDP and 1608.31ms for changed Flutter
layers. These are sampled renderer surfaces, not physical screen scanout or a
pixel acceptance score. They do not prove real authentication, Socket.IO,
backend readback, other themes/platforms or the full application.

Raw host artifacts are retained under `.local/cody-android-thread-{source,native}-1b87eef`
and `.local/cody-android-thread-pair-1b87eef.json`. The prior Android artifact
readback failure at `63a4568` remains a failed historical attempt.

## Remaining observed defect

C's separate actual Linux canonical thread → Back → Activity → channel double
case fails: Source restores an accepted per-channel memory window while target
context is held, whereas Flutter hides it. The original failure and exact
fixture remain retained. Checklist child N24g requires compatible accepted
window restoration and a rerun; N24 cannot be fully verified without it.
Unaccepted, disk-only or foreign principal/server rows must remain suppressed.
