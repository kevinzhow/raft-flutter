# Mobile Search typed-thread and focus contract

`[N02c]` now uses the accepted Search result DTO at both 390px and 1440px.
A thread hit installs the Search content slot and its parent anchor together,
then loads parent metadata and focused replies independently. The real DTO's
thread-channel hint bypasses lookup. The selected main channel stays unchanged;
no parent-channel presentation or thread-as-main-channel request is introduced.

Authority is pinned Source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`:

- `packages/web/src/components/search/MessageSearchPage.tsx:1281–1315` opens
  `threadStore` with `parentChannelId`, `parentMessageId`, `channelId` as the
  verified thread hint, and result `id` as reply focus. It then opens the Search
  thread slot. This branch has no viewport distinction.
- `packages/web/src/components/layout/MainLayout.tsx:756–793` mounts that same
  `ThreadPanel` for the Search slot, supplies an explicit close owner, and omits
  `onFocusedMessageConsumed`. `ThreadPanel.tsx:700–703` clears visual focus and
  calls a consumption callback only when one exists. Search therefore retains
  URI `msg` after its visible highlight expires. Activity supplies that callback
  separately at `MainLayout.tsx:899–910`; canonical side threads also retain
  their URI focus. The shared store method is not evidence of a mounted caller.
- `packages/web/src/components/message/ThreadPanel.tsx:934–957` uses the explicit
  Search close owner for its narrow Back button. It closes the slot by REPLACE
  and preserves the master query; this gesture does not pop the previous route.
- `packages/web/src/components/layout/MainLayout.tsx:1453–1501` subscribes to the thread
  anchor, `packages/web/src/components/layout/rightPanelUrlSync.ts:515–549` PUSHes a newly added anchor and
  REPLACEs retarget/removal, and `MainLayout.tsx:1594–1618` then REPLACEs the
  Search content slot into the same entry. First opening adds exactly one entry.
  Same-thread focus changes, different-thread retarget and close add none.

## Actual Source browser readback

An isolated real Source App used the committed desktop DTO fixture plus three
explicit Search thread result records. Only local transport/auth/preferences
were configured; Source product files and stores were untouched. The runtime
was independently owned on port15416 and stopped after capture. Its fixture,
Source inputs, runtime and capture script hashes are recorded in each result.
Every animation-frame observation records URI, `history.length` and cloned
`history.state`; the browser clicked actual result cards and visible Close/Back.
No store callback or history method was replaced by the observer.

| Actual Source gesture | Desktop 1440×900 | Narrow 390×844 |
| --- | --- | --- |
| Initial Search | length2, router idx0 | length2, router idx0 |
| First thread reply click | length3, idx1 | length3, idx1 |
| Actual highlight true → expired | same URI including `msg`; length3/idx1 | same URI including `msg`; length3/idx1 |
| Same-thread reply retarget | REPLACE; length3/idx1 | not run; Search master is hidden |
| Different-thread retarget | REPLACE; length3/idx1 | not run; Search master is hidden |
| Visible owned Close/Back | Search `q`, `presentation`, `keep` retained; length3/idx1 | same preserved master query; length3/idx1 |

Private immutable receipts are in the activity worktree:
`.local/search-history-source-v1/{desktop-v2,mobile-v2}/result.json`, with raw
`frames.jsonl`, checkpoint PNGs, request chronology and the original capture
scripts/fixture. The preceding v1 captures retain the same measured history
result; v2 additionally requires the actual reply's highlighted and expired DOM
states. This is Source browser behavior evidence in Brutal light, not a Source
three-theme visual claim or a native Flutter run.

## Actual Flutter page evidence

`apps/raft_flutter/test/workspace_mobile_search_thread_test.dart` adds nine
actual WorkspaceView tests:

- Six `[N02c]` cases cover all three actual themes at narrow and desktop widths.
  The real Search card is clicked while parent and reply HTTP responses are
  independently held. Every observed frame checks the correct Search URI,
  thread header/body, no channel detour, exact query preservation and one PUSH.
  Replies arrive before parent, the normal timer clears only the highlight, and
  the late real parent remains admissible. Visible Back/Close REPLACEs the slot
  and restores the same query and actual mounted Search master.
- Three actual desktop cases click a first reply, another reply in the same
  thread, a different thread and Close. The URI and live thread identity follow
  each accepted row, while history length/index increase only on first opening.

The nine existing `[N24f]` actual-page cases now name the independent contracts:
**Activity consumes msg / Search retains msg / canonical retains msg**. They
keep their real timer, stable geometry, every-frame and independently held
parent assertions. Ten model focus-consumption cases remain separate evidence.

Before changes, `.local/mobile-search-n02c-before.log` preserved six failures:
narrow Search used the ordinary channel handler, and desktop Search incorrectly
consumed URI focus. After measuring Source history, the new first-PUSH assertions
also preserved six failures in `.local/mobile-search-n02c-history-before-second.log`.
The previous `history-before.log` launch used the prior REPLACE expectation and
passed; it is retained as an obsolete assertion run, not a failing history proof.
The intermediate duplicate-timeline selector failure is retained in
`.local/mobile-search-n02c-after-first.log`; every visible matching tile is now
checked instead of assuming Flyer's outgoing/new tiles have a unique key.

Final focused run: **28 PASS**. Broader selected route, authority, Source-model,
Activity and expiry regressions: **199 PASS**. The design-system no-growth
ratchet and scanner tests passed; application analysis is clean after removing one unused test import. Raw receipts are `.local/mobile-search-n02c-{final-focused,combined,ds}.log`
and `analysis-final.log`. No official screenshot or threshold was changed.

Ordinary narrow Search channel/DM routing remains its previous fallback and
has not acquired this typed-thread contract. External full Search/Activity URI
bootstrap/hydration remains an explicit limitation from the earlier
[mounted location report](mounted-source-location-evidence.md). Narrow retarget
through hidden Search results, OS Back, real accounts, Android/Linux input and
full visual parity are not proved by these page tests. Activity's existing
single-click history policy is unchanged in this bounded Search batch.
