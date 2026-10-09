# Mounted message navigation evidence

The page tests in `mounted_message_navigation_test.dart` mount the actual
`WorkspaceView` and use real SDK controls with the normal RaftClient/Dio
request path. They extend the existing controller/model coverage with observed
paint, query identity and history transitions in all three themes.

| Evidence | Actual action and asserted page behavior |
| --- | --- |
| N07a | Open a message's real reply badge, then press desktop thread Close. The reply leaves paint, the parent remains visible, only the thread query disappears, and the current history entry is replaced. |
| N07b | Press the second message's reply badge while the first thread is open. The thread anchor changes in the same history entry; the held second reply response cannot expose the old private reply, then the accepted second reply is painted. |
| N09 | Paint accepted replies with parent metadata still held, then press mobile Back or select the desktop Activity destination. Releasing the late parent restores neither paint nor URI/history. |
| L04 | Click two real Activity rows with separately held context requests. The second accepted response owns the painted result after the first arrives late. When the second response is an actual HTTP 404, its latest-window fallback stays on the second slot and never revives the first target. |

N07 preserves the independent task/profile/msg and unknown query values. This
asserts URI-slot preservation; it does not claim full task/profile panel
rendering. The original desktop Close popped history instead of replacing its
entry, and unfocused `openThread` deleted the existing `msg`. The original
failures remain private in `.local/mounted-navigation-original.log` and
`.local/mounted-navigation-n07-source-query-fail.log`. Source
`rightPanelUrlSync.ts:438–550` retains the unrelated parameters and chooses
REPLACE for thread retarget/close. The controller now writes `msg` only when an
explicit focused reply is provided. The separately reviewed WorkspaceView
Close correction belongs to the navigation adapter.

`mounted_thread_focus_expiry_test.dart` adds nine actual N24f page tests. A real
focused reply paints while parent metadata is held. Its visible highlight
survives the pre-expiry check, expires at the normal two-second timer, and its
geometry remains stable in every subsequent observed frame. Activity and Search thread
content consume only `msg` from the current URI/history entry. A canonical
side thread retains its URI `msg`, matching Source's narrower callback.

Source `ThreadPanel.tsx:699–703` clears visual/store focus and invokes an optional
consumption callback. `MainLayout.tsx:908` supplies that callback for the mounted
Search/Activity content slot; `searchContentStore.ts:48–56` consumes only its
matching message focus. The reviewed navigation seam validates route, thread
channel, parent anchor, expected message and captured request revision. The
actual ChatView timer now passes its captured revision, and the controller
requires the current real thread identity's matching focused reply. Consuming
this owned focus changes the current history entry without changing request
intent, so the independently held parent request remains admissible. True
Back, a new route, a new thread or a changed authority retain their strict
revision/window fences.

The missing-context test uses a held HTTP response rather than completing an
error future across WidgetTester's real/FakeAsync error zones. Every frame of
its real error continuation is observed. Early fixture attempts and the
initial focus test's duplicate retained/new timeline selector failure remain
private attempt receipts; neither is presented as a product result.

This batch is widget/page evidence. It does not replace the owner-run Source
and native process pairs, and does not mark all of N07/N09/L04 or the complete
visual matrix verified beyond these explicit scenarios.

The final related run passed 91 tests, including 27 new mounted page cases.
Application analysis was clean. Detailed private receipts are
`.local/mounted-navigation-final-n24f.log` and
`.local/mounted-navigation-analysis-final.log`.
