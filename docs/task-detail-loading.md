# Task detail loading boundary

Source reference: `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`.

`TasksPanel.tsx:964-987` activates the task surface immediately. Modern message tasks open the independent task/thread slot; legacy tasks open `LegacyTaskPanel`. `MainLayout.tsx:1165-1195` renders the modern title module's Suspense skeleton: height24 at two-thirds width, then height16 at full and four-fifths widths with12 gaps. This is a module-loading fallback; it must not be described as a requirement that every history HTTP request gates the Source title.

Flutter ResourceView previously awaited task lookup and history before mounting any dialog. The bounded repair mounts its existing authorized detail dialog immediately, shows those skeleton proportions during its pending requests, and fills the existing history view after both succeed. Closing or changing authority rejects late responses; failed lookup/history never becomes successful empty history. A missing/inaccessible404 keeps the previous deny/close behavior; other failures remain visible.

Three-theme actual ResourceView tests hold each HTTP response independently, inspect the mounted loading shape, then verify real history rendering. They also cover pending close, permission revocation, history500, and late failed history after close. Native first-frame dialog and History assertions remain independent. Earlier full-native failures and pre-fix focused failures are retained.

This does **not** prove full Source task surface parity. Flutter still uses the existing Material detail dialog and its History/actions, rather than Source's modern properties plus discussion and separate legacy panel. K10b remains unimplemented; K10 stays partial when current mounted K10a/K10c evidence exists. The new K10 discovery increases the current checklist to48; the frozen original47 audit and historical reports remain unchanged.

The statement above records the earlier loading-only batch. The later independent
modern discussion and legacy metadata implementation is described in
[source-task-surfaces.md](source-task-surfaces.md), including its remaining URL,
visual and native-process limits. Earlier receipts and failures remain unchanged.
