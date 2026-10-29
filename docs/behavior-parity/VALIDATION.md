# Drift detection: validation

`tool/behavior-parity --web` was checked against an independent ground truth on the three tagged Web sources (`v1.13.0-source.1`, `v1.21.0-source.1`, `v1.21.2-source.1`; 129 of the 135 rows have a Web anchor, 6 are `n/a`).

**Ground truth** (`tool/behavior_parity_truth.js`): the same anchors resolved on the TypeScript AST (TypeScript 5.9), compared by a hash of the AST structure (node kinds and token texts, no trivia), so comments, whitespace, quote style and trailing commas never count. It shares no code with the Python scanner. A third signal, `git diff -U0 OLD NEW` hunks overlapping the resolved line ranges, cross-checks both. Reproduce:

```sh
python3 tool/behavior_parity_validate.py --old v1.21.0-source.1 --new v1.21.2-source.1 [--rename] [--out r.json]
python3 tool/behavior_parity_mutation_test.py --tag v1.21.2-source.1
```

## Run 1: v1.21.0 -> v1.21.2 (fingerprints taken fresh at v1.21.0)

| | tool | AST truth |
|---|---|---|
| anchors resolved at v1.21.0 | 129 / 129 | 129 / 129 |
| unchanged / CHANGED / MOVED / REMOVED | 129 / 0 / 0 / 0 | 129 / 0 / 0 / 0 |

False negatives 0, false positives 0, tool line ranges equal the AST node ranges for 129 / 129 anchors. The release touches 32 files under `packages/web/src`, three of them anchored files (`Sidebar.tsx`, `ThreadsInbox.tsx`, `ThreadPanel.tsx`); every hunk is a class-name or route-helper edit outside the anchored symbols (confirmed by reading the diff), so **this run has no true positive to find**: it only proves specificity. That is why runs 2 and 3 below exist.

UNCOVERED new in v1.21.2: 0 socket events, 0 new exported functions or store actions in `store/*.ts`, 0 inside any domain scope. Across the whole of `src` the tool lists exactly 3 new exports; all three are irrelevant to the two domains (read by the diff): `openThreadParentMessageRoute` (thread -> parent route helper), `DeveloperAppPermissions` (settings picker), `snapshotAgentMachine` (feedback export). 3 of 3 spot-checked; there are fewer than 10 to check.

## Run 2: v1.13.0 -> v1.21.0 (big jump, 396 files, 30k lines changed)

- 119 of 129 anchors resolve at v1.13.0 (tool and AST agree on all 129). The other 10 do not exist there: `hasNew`, `hasCurrentServerActivityUnread`, `loadServerUnreadSummary` (in `serverStore.ts`), `subscribeThreadLiveReplies` (x2), `armBootConnectFallback`, `event:connect_error` in `socketBridge.ts`, `event:agent:seen`, `event:agent:updated`, `event:agent:migration-updated`. They are features or locations added after v1.13.0 and cannot be baselined there.
- Of the 119: **103 unchanged, 16 CHANGED, 0 MOVED, 0 REMOVED**, identical to the AST truth. FN 0, FP 0, extent 119 / 119. All 16 CHANGED rows have a git hunk inside the symbol, and no unchanged row has one (no cosmetic-only edit hit an anchored symbol in these tags, so false positives on real formatting churn cannot be measured from tags alone; see the synthetic test).
- CHANGED: BP-READ-009, 012, 028, 036, 045, 051, 056, 057, 067; BP-RT-014, 015, 025, 040, 041, 049, 052 (e.g. `getChannelUnreadIndicatorState`, `parseUnreadSnapshot`, the `rooms:joined` and `connect` handlers, `MAIN_LAYOUT_SOCKET_EVENT_NAMES`).
- Run 3 (v1.13.0 -> v1.21.2) gives the same numbers.

**MOVED / REMOVED, reverse direction.** The tags never move an anchored symbol forward, so the baseline is taken at v1.21.0 and checked against v1.13.0 (symbols "disappear" the same way a refactor makes them): 129 resolved, 103 unchanged, 16 CHANGED, **3 MOVED, 7 REMOVED, all identical to the AST truth**. MOVED: `loadServerUnreadSummary` (`serverStore.ts` -> `Sidebar.tsx`, body changed), `event:connect_error` (`socketBridge.ts` -> `api/socket.ts`), `event:agent:migration-updated` (`components/agentMigration/realtime.ts` -> `store/agentMigrationRealtime.ts`, restructured path found by symbol). REMOVED: the 7 features above that did not exist yet; none is a rename.

**UNCOVERED, v1.13.0 -> v1.21.0.** 46 new exported functions or store actions in `store/*.ts` (5 inside a domain scope), 3 new events (`agent:seen`, `agent:updated`, `machine:upgrade-request`) and 2 removed (`computer:upgrade:done`, `computer:upgrade:progress`). Spot check of 10 new symbols by reading the source:

| symbol | real new behaviour? | relevant to read / realtime? |
|---|---|---|
| agentStore `applyAgentSeen` | yes, `agent:seen` push | yes (realtime, has a row via the event) |
| agentStore `isExternalAgentSeenOnline` | yes, presence from `lastSeenAt` window | yes (presence) |
| agentStore `reloadAgentsAfterServerChange` | yes, coalesced reload on agent pushes | yes (realtime) |
| presenceClock `subscribePresenceClock` | yes, 15 s tick because nothing is pushed when an agent goes quiet | yes (presence) |
| serverStore `loadServerUnreadSummary` | moved + changed | yes (read, row BP-READ-050) |
| threadStore `isThreadAbsentLookupError` | yes, 404 on open thread | marginal |
| taskStore `loadActiveTaskSummaries` | yes, paged task read tied to the `disconnect` invalidation | marginal |
| messageStore `normalizeDeliveryWarnings` | yes, send response | no |
| recentConversationStore `recordVisit` | yes, recents | no |
| profileStore `openExternalProfile` | yes, profile panel | no |

10 of 10 are real additions; 5 relevant, 2 marginal, 3 not. The relevant ones live in `agentStore.ts`, `presenceClock.ts` and `serverStore.ts`, which are **outside** the current `scope:` lists, so the symbol scan would not flag them: a domain auditor has to widen the scope (the event scan has no scope and does catch the three event changes).

## Synthetic drift (covers what real tags do not)

`tool/behavior_parity_mutation_test.py` copies a tag, applies one edit to each distinct anchored symbol, then compares tool and AST truth on the copy. Edits: **S** semantic (`===` -> `!==`, `&&` -> `||`, literal change), **F** formatting only (inserted comment line, re-indent, `"` -> `'`, trailing comma removed, blank line), **R** rename of the declaration, **M** move of a top-level declaration to another file. Expected labels come from the AST truth, never from the edit.

| base tag | mutants | S | F | M | R | tool vs truth |
|---|---|---|---|---|---|---|
| v1.21.2 | 90 | 33 / 33 CHANGED | 31 / 31 unchanged | 13 / 13 MOVED (new path right) | 12 REMOVED + 1 MOVED | 90 / 90 agree |
| v1.13.0 | 77 | 28 / 28 CHANGED | 26 / 26 unchanged | 10 / 10 MOVED | 11 REMOVED + 2 MOVED | 77 / 77 agree |

FN 0, FP 0 on 167 mutants. (14 and 18 anchors got no applicable edit; they are not counted.) The two R rows that came out MOVED are name collisions: `handleWillSend` and `handleBackToBottom` are also declared in another file, so the tool reports "MOVED (body changed)" there, which the AST truth reports too; it is wrong in spirit but the tool cannot tell a rename from a same-name symbol elsewhere.

## Renamed symbols

A rename shows up as REMOVED (and the new name as an UNCOVERED candidate), as expected. Mitigation implemented: the sidecar stores a bottom-32 sketch of 3-token shingles per anchor, and `--rename-candidates` finds the most similar function-like declaration in the new tree (threshold `RENAME_MIN_SIMILARITY = 0.6`, from the data below).

- Synthetic renames that came out REMOVED: v1.21.2 11 of 12 correct (similarity 0.67-1.00), v1.13.0 9 of 11 correct. The misses are tiny one-liners below the 80-character floor (`showMentionMarker`, best similarity 0.08).
- Unrelated best matches for the 7 real REMOVED rows: 0.12, 0.12, 0.19, 0.22, 0.25, 0.27, 0.59. So the threshold separates true renames from noise on this sample, but only with a small margin (0.59 vs 0.67); treat a candidate as a lead for the auditor, not as a verdict.

## Limitations

- The fingerprint covers the anchored symbol's own text. A change in a helper it calls, or in a type it uses, is not seen (the cause of "unchanged" for a behaviour that did change). Anchor the helper with its own row.
- Heuristic scanner, not a parser. The AST agreement above is 100% on these anchors, but unusual syntax can still be misread; an anchor that cannot be resolved at the audited commit is reported as an audit error. Homonyms (several declarations of one name in a file) resolve to the best-ranked/shallowest ones; at v1.21.2 no anchor has a homonym with a different rank.
- Real tags contain no formatting-only edit inside an anchored symbol, so false positives are only tested on synthetic edits. Not covered: line re-wrapping, added or removed parentheses, semicolon style, JSX text reflow.
- Rename plus body edit in the same release is not detected (similarity falls under the threshold). Symbols whose name also exists elsewhere are reported MOVED, not REMOVED.
- The UNCOVERED symbol scan only looks at the `scope:` files and only lists exported functions and zustand store actions; with the current scopes it reports 101 (read) and 18 (realtime) symbols at v1.21.2 that the auditors still have to triage with `ignore:`. The event scan found 11 events the realtime checklist has no row for at v1.21.2 (`task:updated`, `task:deleted`, `agent:deleted`, `server:member-removed`, `server:member-updated`, `server:member:left`, `machine:upgrade-request`, `computer:restart:done`, `reminder:scheduled`, `reminder:canceled`, `reconnect_attempt`).
- Only `test()` / `testWidgets()` descriptions count as test evidence for the computed status; a test with a `skip:` does not.
