# Activity activation contract and evidence

Authority is the mounted Web1.17.5 Source at `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` (`packages/web/src`). These checks leave the original screenshot baselines, fixture and acceptance thresholds unchanged.

| Check | Source contract | Executable coverage |
|---|---|---|
| N24a thread single | `components/thread/ThreadsInbox.tsx:1111–1147`: publish the accepted thread content slot directly; first unread/latest reply; independent parent metadata. `store/threadStore.ts:367–393`: actual row hint skips thread-channel lookup. | `workspace_activity_activation_test.dart`: real Activity row, unrelated accepted main window, parent and reply HTTP held independently; every observed location/frame remains the thread slot; parent never enters the main window. All three themes. |
| N24b channel after thread | `ThreadsInbox.tsx:1165–1184`: retire old thread, select channel slot; unread/last focus without desktop mention shortcut. | Same mounted file: genuine channel row after pending thread; old identity closes; channel slot survives stale parent/reply completion; no extra history entry. All three themes. |
| N24c DM single | `ThreadsInbox.tsx:1165–1184`: same single-open focus contract, `open=dm:<actualChannelId>`. | Same mounted file: separate accepted DM channel and row; same retirement/fencing assertions. All three themes. |
| N24d double to full chat | `ThreadsInbox.tsx:1036–1075,1077–1103`: cancel pending single activation; one canonical route PUSH, no intermediate Activity thread PUSH. Thread double activation prefers mention; channel/DM double activation uses first unread/last. | Same mounted file: actual two clicks 80 ms apart, channel and thread scenarios separately, every frame and listener location through held requests, exactly one added history entry. All three themes. |
| N24 220 ms arbitration | `ThreadsInbox.tsx:1077–1103`: the mounted master/detail consumer alone owns the 220 ms timer; cancel on second activation; custom embedded open consumers stay immediate. | Actual WorkspaceView single cases assert no content/thread/parent request at 219 ms, thread at 220 ms. SDK `conversation_card_activation_test.dart` proves immediate first signal, repeat detail, actual Enter activation, nested action exclusion and legacy immediate callback. |
| N25a/b narrow focus rules | `ThreadsInbox.tsx:1137–1145,1175–1184`: canonical thread uses unread/latest without mention shortcut; channel/DM single narrow open prefers mention. | `activity_destination_test.dart` is **pure policy only** for these focus rules. This batch does not claim narrow mounted/native N25 verification. |

`activity_destination_test.dart` validates Source DTO choices and URI identity only. The SDK component reports successful activation detail without API or navigation dependencies. Installing an `InkWell.onDoubleTap` recognizer would introduce an additional framework first-tap delay before the Source timer, so the SDK counts successful primary taps without that recognizer. The app timer is cancelled on disposal/scope reset and rejects a delayed callback after location revision changes.

The column-3 thread uses the same Source thread header contract as the actual thread overlay: known real reply channel provides source-channel title/composer while independent parent metadata is pending; unresolved identity uses the plain header. Back/Close closes the content slot. Selecting a thread does not select its parent as the main channel or fabricate a parent record from an ID.

For a double canonical thread with an accepted parent channel, the complete canonical URI is installed first. The outer-tail selection starts synchronously before the independent thread identity, and neither request is awaited before starting the other. The URI owns one PUSH. The uncached-parent fallback remains the existing guarded jump loader and is not included in this batch's accepted-parent double scenarios.

## Evidence boundaries

Widget checks exercise actual WorkspaceView and ResourceView with held local transport responses. They are distinct from pure DTO tests and from C's native paired process recordings. Native first-paint/scroll/highlight, Linux/Android pointer/keyboard behavior, mobile N25 mounted behavior, and the uncached-parent double fallback are not inferred from these widget passes. Failed local receipts remain in `.local/` and are never relabelled as not run.

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
