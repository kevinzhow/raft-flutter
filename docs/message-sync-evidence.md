# Message synchronization evidence

The pinned Web `messageSyncDomain.ts` uses a sparse `messages` domain: a server-wide message sequence is not contiguous inside one channel. Its compatibility domain consumes `message:new`; the established socket `sync:resume` transport owns reconnect replay. It does not invent a messages snapshot/difference HTTP endpoint.

`MessageSync` ports that consumer to `raft_sync`. `WorkspaceController` evaluates the mounted `sync_core_messages_v0` capability for the current workspace and rejects stale flag responses across account/workspace changes. Enabled ingress deduplicates/regression-checks new channel facts; unresolved/off ingress preserves the legacy delivery path. Positive safe numeric sequences and canonical uint64 strings remain exact at the boundary. Missing sequences retain the source's fallback.

Task/status `message:updated` facts merge only into existing loaded messages. They preserve absent text, sender, attachment and sequence fields, and use the canonical shared-null-preserve policy for `commentRef`. A partial update cannot manufacture a message. Channel revocation clears both the visible ledger and the pure core's channel scope; later revoked ingress is rejected.

Validation: 31 sync package tests, including 18 pinned TypeScript reducer equivalence scenarios and four message-domain boundary tests; three controller tests exercise real event ingestion, flag-off behavior and late capability rejection. Nine send/mention tests cover retry identity, immutable mentions, latest-history navigation, old success and old failure fencing, intentional current-channel refresh, and durable conversion pause/recovery. The expanded native suite owns reconnect/idempotency/read/revocation proof separately.

The experimental Activity TypeSpec cutover remains distinct from this message compatibility domain. The mounted Web's Activity cutover is off unless its build environment explicitly resolves `VITE_ACTIVITY_SYNC_CORE_MODE` to `shadow` or `on`; the current client uses the mounted inbox/read-state APIs. A passing pure reducer does not establish that experimental transport's platform parity.
