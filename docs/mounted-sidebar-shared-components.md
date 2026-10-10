# Mounted sidebar components

The classic Members and Settings columns now use `RaftMountedSidebarFrame` and the same `RaftChatSidebarHeading` as Chat. The frame owns the muted canvas, including Brutal's cream desktop surface. The application supplies authorized data and navigation actions.

`RaftSidebarMachineGroup` follows the pinned Sidebar.tsx:4396–4438. Groups retain the first occurrence order of computers in the permitted agent list. Their names, counts, disclosure geometry, hover colors, keyboard activation and expansion semantics are shared SDK behavior. The application retains folds during events and retires them when its account, workspace or permissions change. Auxiliary computer-name failure does not discard accepted member rows.

Directory and pinned Agent DM rows use the existing `RaftNavItem`, mounted avatar projection and `RaftAvatarContent`. This preserves uploaded, Gravatar and pixel avatar behavior. Human descriptions, display-name fallback and the localized `(you)` suffix follow Sidebar.tsx:4510–4534. Pinned Agents no longer use the Material robot glyph.

The Search, Settings profile, Appearance and Search home recipes previously in the application now reside in the public `raft_ui` package. The former file only re-exports their public declarations. These components have no API, account, persistence or native service dependency. Existing consumer tests exercise the same declarations.

The resolved-AST scan decreases from 694 to 661 findings: 29 page recipe findings, two directory findings, one Settings surface and one pinned Agent Material icon. No scanner rule, scope or allowlist was changed. The remaining 661 findings are still work to do.

The shared sidebar preview covers all three supported themes. Six SDK tests exercise narrow and desktop geometry, hover, keyboard actions and semantics; four application tests verify order, pixel avatar projection, descriptions, self identity, live-event collapse retention, revocation and auxiliary request failure. Existing directory, Settings and mounted navigation tests remain applicable.

The Members Graph route and dedicated computer card rows remain incomplete. Their omissions are not filled with decorative controls or compensating space. The 402-case visual result must come from a new run against this source; earlier screenshots do not certify these changes. Full Linux and Android workflow results are recorded separately, including original failures.
