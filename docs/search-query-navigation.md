# Committed Search query and native navigation

Source is pinned to `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`.
`MessageSearchPage.tsx:1044–1078` trims only the committed URL query, pauses
publication during IME composition, replaces the same history entry, and
preserves other query slots. External URL changes take precedence over old
input state. `MainLayout.tsx` keeps desktop message content inside Search;
typed thread content also stays inside Search on narrow screens.

The real WorkspaceView now supplies the ResourceView query writer. It replaces
only `q` while retaining open content, thread/task/profile and unknown query
parameters. It does not retire the active content request merely because the
user edits a Search query. The input retains its original text, selection and
composition; an IME commit with unchanged text is observed separately because
TextField.onChanged omits that transition. A different external query replaces
the input and fences the old pending search response. Embedded ResourceViews
without URL ownership keep their existing local behavior.

The same nine actual mounted page cases failed against the unmodified
86309ef product, and passed after the repair. They cover three themes at
390/1440 widths, query trimming/clearing, cursor retention, unchanged-text IME
commit, held parent/reply context while editing, and external query adoption.
The full related six-suite batch passed 80 cases; analysis is clean. Raw
receipts are in Root `.local/cody-search-query-{before.log,exact-before.json,
first.log,final-tests.log,analyze-final.log}`. These are page tests with held
HTTP transport and a memory session, not native IME/backend acceptance.

The actual Linux full application run on 86309ef remains FAIL: 12 checkpoints,
then an old Search assertion requiring section chat at workspace_test.dart:1404.
The updated native flow requires desktop Search with typed channel content,
exact message focus and retained query; the narrow ordinary-channel route
remains canonical. Saved-message routing is unchanged. This updated actual
Linux/Android flow has not yet run and must not be reported PASS from the page
checks. Earlier message-arrival crash receipts remain preserved independently.
