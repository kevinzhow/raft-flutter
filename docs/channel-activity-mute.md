# Channel activity mute and native flow restoration

The chat-panel settings sheet now exposes the existing per-user activity mute
preference. Its text and placement follow the pinned Web
`ChannelPreferencesSection.tsx` and `ChatPanel.tsx`; it uses the mounted
`PATCH /channels/:id/notification-settings` API. Standalone settings, DMs,
unjoined channels and unavailable preference projections omit the control.

Saving disables repeated activation. An API error keeps the previous value and
allows retry. A callback retained from an earlier workspace, client generation
or channel membership cannot submit a write. The existing shared sheet and
switch own the theme, geometry and input behavior.

Twelve focused widget tests cover three-theme round trips, pending duplicate
activation, omitted surfaces, authority changes and failure/retry. All pass.
The actual Linux application also completed mute-on and mute-off with separate
API readback, plus the existing pin, collapse and channel metadata assertions.

Two full Linux attempts remain **FAIL**, not full-application acceptance:

| Input | Run | Last completed screenshots | Failure |
| --- | --- | --- | --- |
| `b75ca65c792dbab8d70c5bc4ed81a4dcf8a4ab434d0109199542b73e89150098` | 2026-10-09T12:00:57.287923Z | 26 | The settings helper required a scrolling-page key on a non-scrolling Server Profile page. |
| `b642bf58827ccc02bd1f93e4721a0598f2d13ca79ab034d77897251f26fced1a` | 2026-10-09T12:10:18.790340Z | 26 | Profile input was tapped before its dirty-state frame enabled Save. |

Private original receipts, screenshots and logs are retained under
`.local/cody-full-native-linux-attempt1/` and `attempt2/`. The native fixture's
existing response-based ownership registry cleans only resources created by
that run, including on failure; the fixture workspace list was read back after
the first attempt and contained only its four seeded workspaces.

The native flow now uses the actual Source-aligned creation fields, sheet
switches, settings destinations, Agent profile edit controls and Activity tab.
Server deletion confirms the immutable slug; the edited display name must not
enable deletion. These preserve the original API assertions. They do not yet
establish a completed Linux or Android full application run on the final input.
