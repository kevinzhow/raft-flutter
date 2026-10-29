# Session ownership: the foreground owns, background work are guests

Background workers exist on iOS only (BGAppRefresh); Android runs none since 2026-10-13, so its `NativeSessionOwner` is inert (`supported` is false) and only the foreground holds the session there. The history below describes the Android failure that led to these rules, which the rules still guard on iOS.

Rule: **the foreground never waits for, and never fails because of, background work.** Background work may wait, retry later, or be cancelled at any point.

Code: `apps/raft_flutter/lib/platform/session_owner.dart` (`NativeSessionOwner`, `GuestSessionStore`), the guest side in `background_notifications.dart`, and the credential handoff in `packages/raft_client/lib/src/client.dart`.

## Why the old lock failed (2026-10-12)

The old design was a mutex: the first engine registered a port under a process-wide name, the foreground waited up to 30 s for it to be released, and a timeout threw `Background session recovery is still running. Please retry.`

1. An OS-stopped WorkManager worker (job timeout, network constraint lost, app update) has its Flutter engine destroyed by the plugin. The Dart `finally` that releases the name never runs, so the name keeps pointing at a dead isolate. Nothing could ever release it.
2. The foreground sent `yield` to that dead port and waited the full 30 s, then threw.
3. The thrown error became the client's `credentialsReady` future. Every authorized request, refresh and socket connect awaited it, so every request failed with the same message, and it never cleared: Activity, channels and messages stayed broken until the process restarted. Also, a later worker delegated to the dead port and hung for 25 s each time.

## Rules

| Who | Rule | Enforced by |
|---|---|---|
| Foreground (UI engine) | Takes the session at startup, logout and login with `claim()`: synchronous, idempotent, replaces whatever is registered (live guest or dead isolate). Never waits, never throws. | `NativeSessionOwner.claim` |
| Foreground requests and sockets | Display, cached reads, authorized requests and the socket never wait for a guest. They use the credentials in memory. | `RaftClient._request` and `connect` have no ownership await |
| Foreground credential rotation | The only step that waits: until the guests registered at claim time confirmed they stopped (1 s cap; a dead guest never answers). Then it reloads the latest stored record and continues from its persisted refresh attempt. A guest that already rotated is adopted, not rotated again. | `RaftClient.refresh`, `_reloadOwnedCredentials`; `guestSettleTimeout` |
| Guest (background worker) | Registers only if nobody is registered. A live foreground polls on its behalf; a live guest makes it skip the wake. It never takes from a foreground. | `NativeSessionOwner.probe` / `registerGuest` |
| Guest on preemption | Stops at once: closes its transport, fences credential writes, drains the one write that may be in flight, then confirms. After that it can never write credentials. | `onPreempt`, `GuestSessionStore.preempt` |
| Guest writes | Compare-and-set against the record it last read or wrote; a write is dropped if the foreground changed, replaced or cleared the session. | `GuestSessionStore` |
| Stale registration | A probe that gets no answer within 1.5 s removes the registration. A foreground claim replaces it unconditionally. | `probe`, `claim` |

## Single-flight refresh without a lock

The refresh token rotates once; a retry with the same `X-Slock-Auth-Refresh-Attempt-Id` replays the same pair. The attempt id is persisted before the request is sent. So when the foreground preempts a guest mid-refresh it reads the stored record after the guest stopped; if an attempt is pending it re-sends that exact attempt (idempotent), otherwise it starts its own. Two different attempts on one token never overlap, because a guest cannot start or persist a rotation after it confirmed preemption, and the foreground does not rotate before that confirmation (or the 1 s cap).

Residual risks: (a) the guest-write compare-and-set and the foreground's own write are separate secure-storage calls, so a few milliseconds of overlap exist but a stale guest write would need to land after the foreground rewrote the same record; (b) a second foreground engine would preempt the first (not a supported configuration since MainActivity is `singleTask`); (c) the 1 s cap on a hung but live guest means rotation can proceed while that guest's final in-flight request is only being aborted.

## Tests

`test/session_owner_test.dart` (claim never waits for a hung guest, stale registration, probe, guest write fencing), `test/restart_cache_first_frame_test.dart` (cached first frame and startup reads with a busy guest), `test/activity_background_session_test.dart` (Activity rows with a hung or dead worker), `packages/raft_client/test/cached_restore_test.dart` (requests and socket do not wait; refresh waits and continues from the guest's persisted attempt).
