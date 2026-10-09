# L01, L03 and L06 mounted evidence mapping

The existing tests already exercise a real return-to-bottom click and the
retained historical window in all three themes. This batch reuses that proof
for L06. It adds only the missing actual-page cache-centering and highlight
ownership combinations for L01 and L03. The nine new cases pass without a
product change; the focused combined run passes 45 cases.

## Authority and input

Source is Web 1.17.5 / raft-ui 0.5.27 at
`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` in
`/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source`.
The tested product base is
`0d1997b91085f79d6a8fbd6d44bbac77b9e0ade2`, using repository-pinned Flutter
3.47.6. This private test commit is independent of the earlier K07 tests-only
commit; neither commit changes Root's active run inputs.

Source paths below are under `packages/web/src`:

| Check | Source contract |
| --- | --- |
| L01 | `store/messageStore.ts:2374–2392` accepts a target already in the channel bucket without context GET. `getCachedChannelWindowState` at `713–732` carries pagination/history metadata into the focused window. `components/message/ChatPanel.tsx:581–597` centers the actual accepted highlighted message. |
| L03 | `components/message/ChatPanel.tsx:581–597` schedules center alignment and a 2000 ms highlight timer. Dependency cleanup cancels the frame and timer. The new tests cover a changed target and a changed channel crossing the old deadline. |
| L06 | `components/message/ChatPanel.tsx:654–683` clears focus, reloads the tail when `hasNewer`, and scrolls after acceptance. `store/messageStore.ts:2001–2024` exits newer/context state without deleting the accepted bucket. |

The current Flutter cache branch is
`apps/raft_flutter/lib/data/workspace_controller.dart:2496–2550`; it requires
an accepted window with matching authority before taking the cache hit.
`features/chat_view.dart:713–768` owns reveal, positioning and the scoped timer.
The main-channel return path is `chat_view.dart:470–477` and
`workspace_controller.dart:2460–2472`. These product files are not edited by
this batch.

## Existing proof, with its actual layer

| Existing file and location | Evidence retained | Mapping and limits |
| --- | --- | --- |
| `test/message_context_transition_test.dart:106–125` | Accepted cached target skips context GET and leaves loading false. | Controller evidence for L01; it does not prove a painted row is centered. |
| `test/chat_focus_receipt_test.dart:52–160` | Actual RaftChatView keeps its old paint while context waits, publishes the first painted centered target without another visible jump, retains highlight at 1700 ms and removes it after another 400 ms. | Three mounted L02 cases also contain the ordinary L03 expiry proof. They do not cover a target/channel switch during the old timer. |
| `test/chat_focus_receipt_test.dart:162–188` | Clicks the real bottom control labelled `3 new messages`, waits for a held tail GET, checks the old target at the same painted bounds while loading, then accepts the tail and observes its last row and maximum scroll offset. | Genuine L06 mounted proof in the same three tests. There is one asserted pending painted-bounds sample for this return branch; incoming messages during/after the request and duplicate-input races are not proven here. |
| `test/mounted_thread_focus_expiry_test.dart:18–127` | Actual WorkspaceView thread content across Activity, Search and canonical routes. Expiry preserves the current painted anchor and independently pending parent; Activity consumes its owned `msg`, Search/canonical retain theirs. | Nine mounted cases, independent of the new ordinary channel cases. Query ownership is not inferred from an ordinary highlight assertion. |

These existing normal paths were rerun, not copied or renamed to manufacture a
new checklist count. The audit notes in `tool/checklist/data/loading.json` are
left intact. Root can map the L06 assertions to their actual existing L02 test
names and file; a missing L06 label is not a missing real interaction.

## New proof through actual WorkspaceView input

[`workspace_message_focus_lifetime_test.dart`](../apps/raft_flutter/test/workspace_message_focus_lifetime_test.dart)
mounts the actual WorkspaceView, ResourceView Search results and RaftChatView at
1440×900/DPR 1 in Brutal, Elegant light and Elegant dark. It types into the real
Search field and taps the production `RaftSearchResultSurface` rows. There are
no invented navigation buttons, controller method overrides or fake viewport
replacements. The local Dio fixture establishes the accepted cache through the
real tail GET and holds a real cross-channel context request.

| New scenario | Assertions | Cases |
| --- | --- | ---: |
| L01 actual cached result | The first painted target is centered within 0.5 logical px of the actual viewport center. Eight further frames keep the same bounds, loading remains false, no context GET occurs, and accepted message IDs, bundled reply summary, pagination and history-limit metadata remain unchanged. | 3 |
| L03 actual second cached target | After 1000 ms the real second Search click focuses another accepted target. The captured first timer is inactive after the new reveal. Crossing its old deadline leaves the second target highlighted and its bounds stable; the second still highlights at about 1700 ms and expires after about 2100 ms of its own reveal. Neither focus makes a context GET. | 3 |
| L03 actual cross-channel target with held HTTP | The second real result selects c2 and owns its pending target. Eighty 16 ms frames cross the old target deadline without clearing the new pending focus or painting c1's old private row. The sole context GET uses c2. After release, the first painted target is centered and receives its own full temporary highlight lifetime, then expires without moving the anchor. | 3 |

The cross-channel scenario uses the real Search input rather than a sidebar
click: it directly tests the current mounted detail's rebind and pending
request. Its cancellation proof is that the retired timer cannot affect the
new focus across its deadline; it does not assert immediate physical removal
of the timer while the new context waits. The same-channel changed-target case
separately observes the captured timer becoming inactive. These are distinct
claims, not a universal claim about every timer callback.

## Results and preserved attempts

From `apps/raft_flutter`:

```sh
../../tool/flutter test test/workspace_message_focus_lifetime_test.dart test/chat_focus_receipt_test.dart test/mounted_thread_focus_expiry_test.dart test/message_context_transition_test.dart --no-pub --reporter expanded
../../tool/flutter analyze test/workspace_message_focus_lifetime_test.dart --no-pub
```

- **45 PASS**: 9 new actual-page cases, 3 existing mounted context/expiry/bottom
  cases, 9 existing mounted thread expiry cases and 24 controller transitions.
  Final receipt: `.local/message-focus-lifetime-final-regressions.log`.
- Scoped analysis has **no issues**:
  `.local/message-focus-lifetime-final-analyze.log`.
- The standalone nine-case Source-input run passes:
  `.local/message-focus-lifetime-source-input.log`.
- The initial `.local/message-focus-lifetime-first.log` remains **3 PASS / 6
  FAIL**. Three cache tests incorrectly expected `historyLimited:true` from a
  context response: Source explicitly accepts context with `historyLimited:false`
  at `messageStore.ts:2433–2457`. The final fixture establishes history-limited
  tail metadata through its supported endpoint. Three cross-channel tests
  incorrectly asserted acceptance inside a real-time wait before advancing
  their FakeAsync Flutter frames; the final test releases the held response,
  advances actual test frames, and asserts loading false at its centered first
  paint. No product change or weakened centering/expiry assertion resolves
  either preparation error. The original analyzer receipt is also retained.

No native engine, Android device, live backend, Source browser or visual run
was executed here. This is local fixture transport and a Flutter test clock;
sampled test frames do not prove physical scanout or unsampled native frames.
L06's arrivals/duplicate-request extensions, L03 arrival-driven timer changes
and L07 follow-output behavior remain outside this bounded receipt. No
Markdown, controller, task, Source, pixel baseline, anti-aliasing setting,
threshold, calibration, DS baseline or checklist file is changed. Root owns the
independent native/Source process evidence and the eventual checklist decision.
