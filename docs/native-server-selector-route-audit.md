# Native server creation route

The retained Linux `0d1997b` attempt failed after 31 checkpoints. It exposed a
channel-settings route rebuild crash. Its later server-creation step also tried
to locate the retired `Switch workspace` tooltip and local workspace dialog.
The first failure remains in `.local/cody-full-native-linux-0d1997b`.

The native test now opens the real desktop `rail-workspace` or mobile
`mobile-server-selector`, selects **Switch or Create Server**, opens
**+ Create New Server**, enters the actual root-selector name and slug fields,
and submits **Create server**. Creation still sends the actual `/servers`
request and selects the returned authorized server using the existing
controller. The subsequent notification, invitation, membership, resource and
deletion API assertions remain intact.

The Source authority is `components/ui/ServerSwitcherMenu.tsx:416–428` and
`components/auth/ServerSelector.tsx:291–297`, relative to `packages/web/src` in
the pinned Source snapshot. The current Flutter root callback and selector
implement those routes; no product control was changed to satisfy the old test.

The existing actual `RaftApp` selector and server-switch hydration regressions
passed together: 50 tests, including themes, narrow and wide layouts, keyboard
creation, authorized returned directory, failure and account retirement.
This targeted result does not establish a complete native run. Fresh Linux
and Android receipts determine that separately.
