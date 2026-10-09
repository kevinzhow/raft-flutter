# Accepted inbox thread identity (N24a)

Pinned Source `ThreadsInbox.tsx:1111–1147` supplies the actual inbox row's
`threadChannelId`, `parentChannelId`, `parentMessageId` and focused reply ID.
`store/threadStore.ts:367–393` synchronously selects that known thread channel
and returns without the thread-resolution GET. `ThreadPanel.tsx:1275–1384`
loads replies independently of its parent-message lookup.

`WorkspaceController.openThreadIdentity(initialThreadChannelId: ...)` follows
that contract. Its first notification already identifies the real thread
channel and starts the focused reply request alongside the parent request.
The parent remains absent until real metadata is accepted. The SDK thread
loading body and real composer can therefore mount without waiting for the
parent or selecting a temporary parent-channel pane. The WorkspaceView adapter
owns the single URI publication and passes `navigate:false`.

Parent-channel membership/capability snapshots use the actual parent-channel
record, independent of another cached main conversation. Acceptance also checks
server/principal authority, current navigation revision, thread generation and
revoked parent/reply channels. Missing parent records retain server and request
fences without inventing records. Empty identities and denied authority do not
publish a route or make a request.

The focused mounted tests hold the parent and reply requests separately in all
three themes. They assert synchronous identity, no resolution GET, no main
channel selection, the real composer during loading, accepted replies before
parent metadata, and no parent insertion into the outer message ledger. Back,
server revocation, changed parent capability snapshots and membership removal
reject late replies and parent metadata.

Two different geometry contracts are explicit:

- The bounded multi-row window preserves the focused reply's exact coordinates
  in every visible frame before and after parent metadata is accepted.
- A one-reply window has zero legal scroll extent. Real parent insertion may
  move the reply once; every frame keeps the reply visible, and its new
  coordinates remain stable. The test checks the actual zero scroll range,
  rather than prescribing an invented scroll offset or parent placeholder.

The initial overstrict one-row equality assertion failed at 62→150px in Brutal
and 62→145px in Elegant; its receipt remains private in
`.local/known-thread-identity-v2.log`. A separate actual Source one-reply capture
also moves on parent arrival (124→238px, actual parent wrapper height114px),
while its 21-row target stays at y400. These are separate fixtures, so their
absolute coordinates are not a visual-parity comparison. The short-window
legal clamp is distinct from the strict multi-row invariant.

The final scoped contract run passed 43 tests, including the existing canonical
thread, context acceptance, scope-reuse and three-theme L02 focus tests. Application analysis was
clean. N24a widget/controller evidence does not replace the root's actual
WorkspaceView and native paired process checks; L03/L06 and the full K09
checklist items remain partial.
