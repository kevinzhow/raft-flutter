# Cold conversation and superseded context process evidence

This first batch records **actual Source App browser execution only**. All four
desktop flows passed in the three actual themes. The matching real
`WorkspaceView` native detector is implemented and analyzes clean; Linux and
Android execution of these new flows are **NOT RUN**. Root owns the current
full-app Linux lane, and the existing N24g receipts stay bound to their original
product and fixture.

## Mounted Source authority

Pinned Source: `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`.

| Input/transition | Actual mounted behavior and authority |
| --- | --- |
| Known channel metadata; first tail held | `ChatPanel.tsx:1345–1478` mounts its real channel header, Chat/Tasks/Files and composer independently of the body loading branch at `1484–1534`. |
| Unknown channel metadata held; tail independently held | `MainLayout.tsx:394–440` uses `ChannelById` and its resolution sentinel to show the loading-channel placeholder without resolved controls. `store/channelStore.ts:265–301` ensures the channel through its real HTTP endpoint. Releasing metadata mounts the known shell while messages still wait. |
| Held target A, actual Back to Activity, target B accepted, then A succeeds or fails | `store/messageStore.ts:643–655,2374–2486` assigns message-window request ownership. An obsolete success cannot replace B; an obsolete failure cannot start A's fallback tail. |
| Actual Activity activation and Back | `ThreadsInbox.tsx:1020–1176` routes the desktop double activation to a canonical channel; mobile uses its live tap path. Source uses real browser history Back. Flutter delivers the actual platform pop to the mounted `WorkspaceView` PopScope on desktop. |

Paths in the table are relative to `packages/web/src`. See the existing
[loading contract](source-message-loading-contract.md) for the surrounding
state sequences. The fixtures use public DTOs over local HTTP, with distinct
metadata, tail and context endpoints. No Source store, product file, calibration
or screenshot threshold changes.

The cold flows mean **a cold conversation window after channel discovery and
Activity are ready**, not an authenticated application's entire cold launch.
Both providers bootstrap normally. The native shell can accept an unrelated
initial design channel during bootstrap; it must not expose that channel's rows
when opening the uncached Android conversation. The known/unknown fixtures
preserve identical target metadata/tail responses and differ in whether channel
discovery initially includes the target.

## Actual Source results

Configured viewport: `1440×900`. Source input SHA:
`799c42a7703b30e809471e9835dfeeb1adbb75c06ae8689562685970292fef17`.
Runtime SHA:
`ba8f7cb55572030b1651e1b2aace7cf98b4e6b65af3983d67852035171aefd1f`.
Loading-capture runner SHA:
`8b25e778d7bf791d9bef3e60a3ba6284d51f6115716d38740bf42c3c1d592d3e`.

Each cell below is `DOM layout observations / CDP compositor PNGs`.

| Flow | Brutal | Elegant light | Elegant dark |
| --- | --- | --- | --- |
| Cold known metadata | PASS `297 / 37` | PASS `169 / 36` | PASS `193 / 37` |
| Cold unknown metadata, then tail | PASS `341 / 38` | PASS `182 / 33` | PASS `162 / 31` |
| Back → B accepted → late A success | PASS `390 / 101` | PASS `230 / 97` | PASS `233 / 91` |
| Back → B accepted → late A error | PASS `387 / 101` | PASS `232 / 106` | PASS `237 / 94` |

All 207 observed frames labeled held resolved tail retain header, tabs and
composer with no fabricated message. All 167 observed frames labeled late
response retain B, with no A target. Both success and error responses are
actually delivered after B acceptance in all three themes; these are not
canceled-request-only checks. HTTP receipts retain requests, gate releases,
responses, read POSTs and wall timestamps. No stale fallback tail or read advance
past A's accepted seq200 was observed.

These counts concern observed layout frames. They do not prove that every
compositor paint was seen. Maximum retained CDP timestamp gaps range from
1.030 to 4.034 seconds. Initial URI observations may precede React's matching
layout commit; the raw prior layout remains in the evidence. There is no claim
of physical scanout, first compositor paint equality, pixel parity, real
auth/socket, permission revocation or the full 36-case matrix.

## Immutable receipts and failures

Private evidence root is
`/home/kevinzhow/github/raft-flutter-wt/cody-parallel-members/.local/process-loading-c/`.
`source-loading-first-batch.json` binds receipt, raw layout and renderer-manifest
hashes, fixture/source/runtime/runner fingerprints, counts and sampling gaps.
Its SHA is
`f3d8cfa996a971a590683942f79f35e41c1d067dfda66af67e840e8ae260a9b9`.

| Fixture SHA | Source output directories below evidence root |
| --- | --- |
| `7adc292116b162128728ad15ebb67051a459765a001c8b0046bf9deda09bea1d` | `known-run-v3/source-<theme>-desktop` |
| `539dfaafd6b9c82f9cbd298e855ce10d2da9687298db908445a14d5cafac3a23` | `unknown-run-v4/source-<theme>-desktop` |
| `327358281ad1767fddd10800161d6ce2e9296de0c5373a16ea2fb0d9548ef263` | `stale-success-run-v3/source-<theme>-desktop` |
| `c99b1b3a26d28bd812f1582121e0c8cb25e2aba832d79d96111b155af0da5ea0` | `stale-error-run-v3/source-<theme>-desktop` |

The three `unknown-run-v1` FAIL receipts remain unchanged: the detector used
CSS-transformed `innerText` and expected mixed-case text, whereas Source renders
`LOADING CHANNEL`. Their actual screenshots show the placeholder. The observer
now reads the exact Source node text through `textContent`; new captures use the
same immutable fixture bytes. The `unknown-run-v3/run.json` runtime-input
mismatch also remains FAIL; a separately owned port and new v4 output were used.
Earlier successful development captures remain separate receipts and are not
the final runner-bound baseline.

## Reproduce and pair after lane handoff

```sh
python3 tool/process-parity/run.py --out .local/<new-source-attempt> --flow cold-known --only brutal-desktop,elegant-light-desktop,elegant-dark-desktop --source-only --port <owned-port>
python3 tool/process-parity/run.py --out .local/<new-source-unknown> --flow cold-unknown --only brutal-desktop --source-only --port <owned-port>
python3 tool/process-parity/run.py --out .local/<new-source-stale> --flow stale-back-retarget-error --only brutal-desktop --source-only --port <owned-port>
```

Use `--fixture <exact-json>` to preserve prior bytes. Omitting `--source-only`
launches the native Linux detector and requires exclusive lane ownership and
the private Linux media bundle. `stale-back-retarget-success` is independent of
the error flow. Mobile390 is selectable but is not included in this batch.

The extended pair comparator rejects fake resolved controls during identity
loading and rejects a late-response proof when HTTP cancellation prevented
delivery. It retains raw missing-control frames and sampling gaps. Native
receipts require their actual platform/device and product/test hashes; Source
PASS alone cannot produce paired PASS.

Validation: 2 new loading-fixture tests, 7 pair-admission tests including 2 new
loading/race guards, 3 existing Activity-fixture tests and 2 actual HTTP runtime
gate tests; the native integration
entrypoint analyzer and Node syntax checks passed. These checks validate tools
and compilation, not the still-unexecuted native process.
