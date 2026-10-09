# Channel settings overlay identity

The actual Root Linux run on `0d1997b` failed after channel deletion: the
`WorkspaceView.channelSettings` DialogRoute builder dereferenced `w.channel!`
after refresh had cleared that selection. This repair captures the opening
channel once and passes that record to every route build. It does not change
the settings body, deletion/archive API, navigation or authority guards.

## Source ownership

The reference is Source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`:

- [ChannelOverflowMenu.tsx:568–581](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/channel/ChannelOverflowMenu.tsx#L568) passes the overlay's explicit `channelId`, initial name and description to `EditChannelDialog`.
- [EditChannelDialog.tsx:96–143](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/channel/EditChannelDialog.tsx#L96) owns those props and initializes its editable state from them.
- [channelStore.ts:553–561](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/store/channelStore.ts#L553) removes the accepted channel after DELETE. [EditChannelDialog.tsx:1674–1683](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/channel/EditChannelDialog.tsx#L1674) closes the overlay and chooses its fallback afterward.

Flutter's existing `ChannelSettings.channel` resolves current metadata by its
opening prop ID, retaining that prop as the fallback during removal/exit.
The host previously undermined that ownership by reading current selection
again inside the deferred route builder. The captured record preserves the
existing sheet State, draft controller and selection when the selected channel
temporarily clears or switches to another accepted channel.

## Mounted verification

`apps/raft_flutter/test/workspace_channel_settings_identity_test.dart` opens the
actual WorkspaceView settings control and uses isolated real client REST
transport. All cases run in Brutal, Elegant light and Elegant dark:

- Clear selection while keeping the accepted channel, rebuild the root
  MaterialApp/Navigator, then select another channel: the sheet retains the
  opening ID, State, draft controller/text/selection and settings request scope.
- Hold and accept the actual Archive confirmation: refreshed archived metadata
  remains accessible to the opening sheet across a Navigator rebuild.
- Hold and accept the actual Delete confirmation: channel refresh clears the
  selection, both overlays retire, and WorkspaceView remains mounted.
- Reduce membership, change principal or change workspace with the sheet open:
  existing PrivateRouteGuard retirement remains effective; no PATCH/DELETE is
  submitted by the rebuild.

Root-app rebuilding intentionally updates the actual Navigator widget. Flutter
then rebuilds its DialogRoute page via `changedExternalState`; a metrics-only
pump can reuse the cached route page and did not reproduce this failure.

Before the product change, the final same 18 tests produced **15 PASS / 3 FAIL**;
all three selected-channel clearing/rebuild cases reported the null dereference.
Afterward, **18/18 PASS**. Together with existing message/private-overlay and
activity-mute checks, **41/41 PASS**; app analysis is clean. Private logs are
`.local/channel-settings-identity-original-final-tests.log`,
`.local/channel-settings-identity-focused-final.log`,
`.local/channel-settings-identity-analysis.log` and
`.local/channel-settings-identity-ds.log`. Earlier detector/compile failures are
also preserved in `.local/channel-settings-identity-before*.log`.

These are mounted widget/transport results, not a fresh Linux/Android replay or
pixel-parity result. The original Root native failure remains immutable for the
parent's full replay. Existing Source-vs-Flutter archive close/fallback behavior
is not expanded or certified by this identity repair.
