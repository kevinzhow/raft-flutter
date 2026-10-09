Thread resume review, 2026-10-09

The isolated `cindy/fix-thread` worktree was clean at `8174d6d`. Its nine commits add comments, authored reference chips, composer mentions, upload capability admission, and message-menu recipe adoption. An independent official parity run captured all 25 Thread cases: six passed the official scoring and 19 differed. Evidence is in `build/parity-thread-resume-20261009`; the committed receipt records the scope and diff SHA. Captures are Flutter widget-test rasters, not native device proof.

A completion audit found two authority defects. Attachment comments retained old private rows across same-State attachment/controller replacement and lacked a current permission check before posting. Multi-file selection checked scope only before the upload loop, so a later accepted file could enter a newly selected conversation after an awaited upload. The follow-up fixes use binding/request revisions, current authority and visibility checks, and per-file scope admission. Comments use a direct mutation followed by guarded unread refresh, so an old callback cannot refresh a newly adopted account. Regression tests exercise pending reads, replacement, same-generation role changes, revoked pending writes, viewer write denial and source HTML-anchor y ordering. Existing attachment revocation tests remain enabled.

The new pure comments panel now uses the shared source-derived spinner and has a three-theme interactive SDK preview. Preview callbacks are local public data only. Source markdown anchor ordering requires a live heading position: no fabricated persisted offset is used when that live geometry is unavailable.

The source `MarkdownContent.tsx` contains an ErrorBoundary that renders raw Markdown in a monospace `<pre data-markdown-dom-fallback>`. Several cached `md-*` baseline images visibly show that raw content while Flutter renders rich content. This is a failed comparison and a source-runtime investigation boundary, not evidence that the product should render raw HTML or Markdown. The later live diagnostic recovered the exact failure: VisualTestingCases.tsx seeds known tasks without status; MessageItem passes undefined to TaskStatusIconRoot, and its Markdown ErrorBoundary falls back. Those references need a separately admitted producer fixture before a rich-render comparison can be accepted.

Remaining visible differences include the actual mobile channel header composition, suggestions' agent presence and outside-channel avatar projection, selection/share framing, and rich row typography. None is declared fixed by the new safety regressions. The new comments route also has no native OS end-to-end proof; preview heading jump and source optimistic comment synchronization remain separate completion work.

## Channel identity and suggestion follow-up

The mounted ordinary/private/joint channel header now consumes the generated
`panelHeader` slots and `RaftPanelAction` for the same desktop/mobile identity,
description and Search/Settings composition. The previous mobile title omitted
the icon/description; the desktop header exposed unrelated refresh/status chrome.
The CSS primary-face line box is explicit for title/metadata (including CJK
fallback). A residual approximately 1 logical pixel CJK ink baseline difference
remains in the official header comparison; no per-string offset is applied.

Channel suggestions reserve the title's natural width, leaving all remaining
space to the metadata, as Source flex-basis:auto versus flex:1 1 0 specifies.
Elegant framed-icon negative right margin now reduces flow width instead of
constructing illegal negative Flutter Padding. Public three-theme preview and
a real channel-name/description plus keyboard insertion regression cover it.

The independent Source diagnostic lives at
`build/thread-source-diagnostic-20261009/receipt.json`. It mounts untouched Source
components, records real DOM/font metrics, and preserves the original runtime
error: `TaskStatusIconRoot` receives an undefined component in the Markdown case,
causing `MarkdownContentErrorBoundary` to fall back to raw Markdown. Matching
that failed reference by degrading Flutter's working Markdown is not a fix.
Search-this-channel now opens a fresh authority-scoped entry with the channel
seed and `initialSearchDeferUntilQuery: true`. Empty input, including clearing
an earlier query, issues no query. Typing queries only that channel; revocation
or account replacement removes the entry without falling back to global
search. Eight targeted entry/search-authority tests passed after integrating
93d7c97. Manual global filter-only search keeps its original behavior.

## Anchored comment interaction follow-up

The Source comments card is a real button, and Source index.css disables text
selection inside buttons. The earlier native card used a GestureDetector while
its prose SelectionArea consumed body taps. The corrected card uses shared
RaftInteractive: header and prose taps, Enter and Space activate its current
jump callback; Tab reaches the pending anchor's remove button. A drag is not a
jump. Only anchored comment prose loses its selection region; an ordinary
unanchored comment still has one. The shared source-hover treatment and quote/
location tooltip are retained. Four three-theme/unanchored tests, eleven
existing body tests and thirteen app comment/attachment authority tests passed.
Fenced-code controls, full-panel visual states and native comment synchronization
remain separate coverage; this is not whole-comment or whole-Thread acceptance.

## Latest selected official capture checkpoint

`build/parity-thread-channel-final-20261009` captured **25 Source and 25 Flutter
Thread cases** from clean a760ed1. Official results remain **six passing and
19 different**. The other 74 manifest cases were not selected, even though the
official whole-manifest summary lists missing captures. Flutter provider
`android` means host widget-test raster here; no physical Android proof ran.
The official cases contain Brutal-light and Elegant-light, with no dark cases.

Personal review of the fresh header pair confirms that the native Back paint,
CJK ink baseline and action distribution still differ. The Source crop also
includes the boundary of its unavailable-chat notice, while the native fixture
permits the conversation; that authority context must be admitted separately.
Personal review of the selection pair confirms two independent differences:
Source mounts two MessageItems near the top and its yellow one-row action bar
at the bottom, while the native fixture mounts a full bottom-anchored timeline
with Beginning/date rows; the native selection toolbar still uses its older
multi-row actions. Neither changing global timeline offsets nor matching a
failed Markdown fallback is an acceptable correction. The remaining selection
fixture and toolbar need source component/state contracts before a new capture.
