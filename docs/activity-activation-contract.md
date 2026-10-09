# Activity activation contract and evidence

Authority is the mounted Web1.17.5 Source at `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` (`packages/web/src`). These checks leave the original screenshot baselines, fixture and acceptance thresholds unchanged.

| Check | Source contract | Executable coverage |
|---|---|---|
| N24a thread single | `components/thread/ThreadsInbox.tsx:1111–1147`: publish the accepted thread content slot directly; first unread/latest reply; independent parent metadata. `store/threadStore.ts:367–393`: actual row hint skips thread-channel lookup. | `workspace_activity_activation_test.dart`: real Activity row, unrelated accepted main window, parent and reply HTTP held independently; every observed location/frame remains the thread slot; parent never enters the main window. All three themes. |
| N24b channel after thread | `ThreadsInbox.tsx:1165–1184`: retire old thread, select channel slot; unread/last focus without desktop mention shortcut. | Same mounted file: genuine channel row after pending thread; old identity closes; channel slot survives stale parent/reply completion; no extra history entry. All three themes. |
| N24c DM single | `ThreadsInbox.tsx:1165–1184`: same single-open focus contract, `open=dm:<actualChannelId>`. | Same mounted file: separate accepted DM channel and row; same retirement/fencing assertions. All three themes. |
| N24d double to full chat | `ThreadsInbox.tsx:1036–1075,1077–1103`: cancel pending single activation; one canonical route PUSH, no intermediate Activity thread PUSH. Thread double activation prefers mention; channel/DM double activation uses first unread/last. | Same mounted file: actual two clicks 80 ms apart, channel and thread scenarios separately, every frame and listener location through held requests, exactly one added history entry. All three themes. |
| N24 220 ms arbitration | `ThreadsInbox.tsx:1077–1103`: the mounted master/detail consumer alone owns the 220 ms timer; cancel on second activation; custom embedded open consumers stay immediate. | Actual WorkspaceView single cases assert no content/thread/parent request at 219 ms, thread at 220 ms. SDK `conversation_card_activation_test.dart` proves immediate first signal, repeat detail, actual Enter activation, nested action exclusion and legacy immediate callback. |
| N24e uncached parent canonical | `components/layout/MainLayout.tsx:387–439` and `store/channelStore.ts:265–309`: ensure the actual channel independently from the canonical URL-owned thread. Unknown channel is Loading channel; unavailable channel is the Select a channel body from `components/message/ChatPanel.tsx:1208–1218`. | `workspace_activity_canonical_cold_test.dart`: independent held metadata, parent, replies and outer tail; one canonical PUSH, no wrong parent-channel reply context, no fake channel. Accepted, Back-before-metadata and unavailable metadata cases across three themes. |
| N25a/b narrow focus rules | `ThreadsInbox.tsx:1137–1145,1175–1184`: canonical thread uses unread/latest without mention shortcut; channel/DM single narrow open prefers mention. | `workspace_activity_canonical_cold_test.dart`: real 390px Activity row single activation immediately publishes one canonical PUSH; thread and channel focus choices are distinct. Actual Back returns Activity, then its auxiliary Back reaches Home. Held replies cannot reopen after Back; hidden parent-channel read POSTs remain zero every pending frame, across three themes. This is mounted proof; native process evidence is separate. |

`activity_destination_test.dart` validates Source DTO choices and URI identity only. The SDK component reports successful activation detail without API or navigation dependencies. Installing an `InkWell.onDoubleTap` recognizer would introduce an additional framework first-tap delay before the Source timer, so the SDK counts successful primary taps without that recognizer. The app timer is cancelled on disposal/scope reset and rejects a delayed callback after location revision changes.

The column-3 thread uses the same Source thread header contract as the actual thread overlay: known real reply channel provides source-channel title/composer while independent parent metadata is pending; unresolved identity uses the plain header. Back/Close closes the content slot. Selecting a thread does not select its parent as the main channel or fabricate a parent record from an ID.

For a double canonical thread with an accepted parent channel, the complete canonical URI is installed first. The outer-tail selection starts synchronously before the independent thread identity, and neither request is awaited before starting the other. The URI owns one PUSH. For an uncached parent, `resolveConversationChannel` accepts only real GET metadata under principal/server/request/location fences. Its tail selection preserves a live thread only when its actual parent and current canonical URI match. Parent replies never go through the main-channel context endpoint. The mobile folded thread suppresses parent read admission synchronously from the URI, including the interval before the new layout callback.

## Evidence boundaries

Widget checks exercise actual WorkspaceView and ResourceView with held local transport responses. They are distinct from pure DTO tests and from C's native paired process recordings. Native first-paint/scroll/highlight and Linux/Android pointer/keyboard behavior are not inferred from these widget passes. N24e and N25 now have the named mounted evidence above. Highlight-expiry URI cleanup remains a separate unverified fix; C's strict native pair-thread-v4 failure is retained. Failed local receipts remain in `.local/` and are never relabelled as not run.

## Local receipts

- `.local/n24-mounted-final.log`: 91 PASS (15 actual N24 scenarios, 6 actual pending-header scenarios, 6 DTO policy checks, 64 unchanged Source route/history ports).
- `.local/n24-final-with-resource-regressions.log`: 128 PASS, adding actual Resource authority/control and desktop transition regressions to the 91-case batch.
- `.local/n24-sdk-activation-final.log`: 5 PASS, including actual Enter activation and adaptive reparent without dispatch.
- `.local/n24-analyze-final.log` and `.local/n24-sdk-analyze-corrected-final.log`: both analyses clean.
- `.local/n24-ds-final.log`: DS no-growth passes, 727 existing findings; baseline and allow rules unchanged.
- `.local/n24-mounted-first.log` retains 15 fixture-entry failures: initial Dio tasks had not been flushed before attempting to click. `.local/n24-mounted-first-entry-corrected.log` retains the late-parent fixture continuation failure, corrected by settling only after both held responses were released.
- `.local/n24-mounted-second.log` retains the six genuine channel/DM listener-order failures. Publishing the selected content URI before retiring the old thread fixed these without removing the location/frame assertions.
- `.local/n24-sdk-analyze-final.log` retains the State.activate naming warning; the input dispatcher was renamed and an actual reparent regression now proves mounting never activates a row.

The full root integration checks and C's native process recordings are separate owner-run receipts. No private-worktree native execution, source fixture mutation, screenshot capture, remote push or publication was performed for this batch.

## Cold-parent and narrow follow-up receipts

- `.local/n24e-n25-app-final.log`: 146 PASS (the prior Activity/resource/navigation contracts plus 9 N24e cases, 6 N25a/b cases and existing joint-channel regressions).
- `.local/n24e-missing-extended.log`: 9 N24e actual page cases PASS independently.
- `.local/n24e-n25-final-read-admission.log`: 15 new page cases PASS, including an explicit visible desktop outer-channel read assertion and zero hidden mobile parent receipts.
- `.local/n24e-sdk-final.log`: 9 Source loading/unavailable shell geometry/input cases PASS.
- `.local/n24e-n25-analyze-final.log`, `.local/n24e-sdk-analyze-final.log`: app and SDK analyses clean.
- `.local/n24e-ds-final.log`: no-growth passes; no baseline or allow changes.
- `.local/n24e-n25-mounted-second.log` retains six harness failures from incorrectly assuming Activity has the root bottom bar; Source Activity is an auxiliary page, and its own Back reaches Home.
- `.local/n24e-n25-mounted-third.log` and `.local/n25a-read-stage.log` retain the genuine hidden parent-channel read leak before the first pending mobile frame. The URI-aware folded-thread guard corrects it without suppressing the visible desktop outer-channel receipt.

No private native run, source fixture changes, Source PNG changes, calibration changes, live account changes or remote push were performed.

## Owned thread-focus seam and desktop Close

Source `components/message/ThreadPanel.tsx:700–703,1540–1559` consumes visual focus after the accepted reply is centered. Only the Activity thread content slot supplies `onFocusedMessageConsumed` (`components/layout/MainLayout.tsx:908`); `store/searchContentStore.ts:48–57` clears that slot's message focus, then `MainLayout.tsx:1594–1618` replaces its `msg` query. Search `renderContentSlot` (MainLayout756–784) and canonical side threads have no consumption callback, and `components/layout/rightPanelUrlSync.ts:438–503` preserves unrelated query state.

`WorkspaceNavigation.consumeThreadFocus` is an exact owned presentation operation: Activity route, thread content ID, parent channel/message anchor, expected focused message and captured navigation revision must all match. It replaces only `msg` in the current location/history entry and preserves the request revision so independent pending parent metadata remains eligible. Ordinary Back, Forward, navigation and principal/server binding still advance revision; stale ownership, including same-identity reentry, fails. This commit exposes the seam only: E owns the actual timer/controller connection and mounted held-parent expiry proof. C's `pair-thread-v4` native failure remains a failure until the connected code is rerun.

The desktop side-thread header Close now calls `controller.closeThread` to replace its URL slot instead of invoking observed Back. Mobile Back keeps its history behavior, and Activity/Search content-slot headers retain their explicit close handler. `workspace_thread_close_location_test.dart` covers the actual pending header across all three themes, preserving independent task/profile/msg/unknown query parameters, history index/count and rejection of late parent/resolution results. This verifies query preservation, not unimplemented mounting of independent task/profile overlays. E's separate mounted N07 test covers loaded reply-close and retarget behavior.

- `.local/thread-focus-model-final.log`: 74 pure model and existing navigation/Source contracts PASS; 10 new focus-ownership cases.
- `.local/thread-focus-close-corrected.log`: 113 PASS including three actual pending desktop Close cases and existing actual N24/N25/header checks.
- `.local/thread-focus-analyze-final.log`: app analysis clean.
- `.local/thread-focus-close-final.log`: retained interrupted first attempt; its test harness awaited a FakeAsync future inside `runAsync`. Completing the held transport, pumping the widget clock, then awaiting the completed operation corrects the harness without dropping the late-arrival assertions.

No native execution or whole-N24 expiry claim is made by this seam delivery.
