# Upstream sync: following the Raft Web releases

The Flutter app mirrors the Raft Web client (`botiverse/raft-source`). Upstream publishes source snapshots as tags
`vX.Y.Z-source.N` (one commit per snapshot, message `Release vX.Y.Z-source.N`). This page is the standing process for
noticing what changed, proposing what to do about it, and moving our reference forward only after a human decided.

## Goals

- Never find out weeks later that Web changed an endpoint, a wire field, a string or a screen we mirror.
- One report per upstream release that Kevin can answer row by row: follow, partial, skip, or discuss.
- Reuse the parity tooling we already have; add no second source of truth.
- The pinned upstream version moves only after the decision, never as a side effect of running the report.

## Roles

| Who | Does |
| --- | --- |
| Cindy | Runs the tool when a new tag exists (weekly check), reads the report, corrects obviously wrong heuristic proposals, commits the report, and brings the decision table to Kevin. Implements what Kevin approves. |
| Kevin | Answers the decision table (follow / partial / skip / discuss per row). Only Kevin's answer authorises `record-decision`. |

The tool's proposals are heuristics (name mapping, line counts, regexes). They are a starting point for the conversation,
not a decision.

## State: what "pinned" means

`docs/upstream-sync.json`:

```json
{ "pinned": "v1.21.2-source.1", "commit": "26f77ef...", "history": [ { "tag": ..., "from": ..., "decision": ..., "date": ..., "note": ..., "report": ..., "deferred": [] } ] }
```

`pinned` is the newest upstream release whose differences we have *decided on* (adopted, partly adopted, skipped or
deferred on purpose). It is the baseline of the next report. It is not the same as "everything in it is implemented":
rows answered `partial` or `discuss` and left open are recorded in `deferred` so they are not forgotten.

Other files also name the Web revision (they describe what a piece of code or evidence was checked against) and are NOT
edited by the tool:

- `docs/source-reference.json`, `THIRD_PARTY_NOTICES.md`, `docs/capability-parity.json` (`webSource`),
  `packages/raft_sync/test/fixtures/ts-core-vectors.json`, source comments (`// Source: Foo.tsx at 26f77ef`).
- They move when the work for a decision lands (for example, capability entries are re-verified when the area is
  followed; `tool/behavior-parity --web <tree> --update-fingerprints` runs after a re-audit). `python3 tool/upstream_sync.py pins`
  lists the pin-bearing files that still cite the old revision.

## The weekly flow

1. **Check.** `python3 tool/upstream_sync.py status` fetches tags into our own mirror and prints pinned vs latest. It also compares the raft-ui version the Web depends on with the one our recipes were generated from (`docs/component-recipes.md`) and prints a drift line when they differ: the Web can change design-system releases without a source change we would otherwise notice; regenerate with `tool/recipes/run`.
   Nothing newer: stop.
2. **Report.** `python3 tool/upstream_sync.py report` (writes `/tmp/upstream-sync/report.md` + `report.json`; `--from/--to`
   pick other tags; `--out DIR`). Takes a few seconds; read-only network, no credentials.
3. **Review.** Cindy skims the highlights and decision table, fixes proposals that are plainly wrong, and commits the
   report as `docs/upstream-reports/<from>-to-<to>.md` (version numbers without `-source.N`, e.g. `v1.21.2-to-v1.21.12.md`).
4. **Decide.** Kevin answers each row. The answers are written into the committed report (the `Kevin` column) or a
   message that the commit message of step 6 quotes.
5. **Implement.** Approved rows become normal tasks (the report gives size, risk, the Web files and our counterpart files).
   Parity data is updated by that work: capability entries, field fixtures, zh catalog, parity cases.
6. **Advance the pin.** After the decision (not before):
   `python3 tool/upstream_sync.py record-decision --to vX.Y.Z-source.N --decision follow|partial|skip|discuss --note "..." --report docs/upstream-reports/... [--defer A03 --defer F05]`.
   This rewrites `pinned` and appends to `history`. Commit it with the report so history is reviewable.
   Skipping a release entirely is also a decision (`--decision skip`), so the next report does not repeat it.

If several upstream releases accumulated, one report from the pinned tag to the latest is fine; the diff is between the two
trees, not release by release.

## What is compared

The tool diffs the two tag trees (`git diff <tagA>^{tree} <tagB>^{tree}`, so unrelated snapshot commits do not matter,
renames of at least 50% similarity count as modifications) in a private bare mirror
(`~/.cache/raft-flutter/raft-source-mirror.git`, `--mirror` or `RAFT_SOURCE_MIRROR` to move it). It never touches another
agent's raft-source checkout. Changed files are classified; tests, lockfiles, infra and migrations are counted and ignored.

| Section of the report | Source of truth compared | Reuses | Our side checked against |
| --- | --- | --- | --- |
| API and capabilities | Web client calls (`api.get/post/...`, wrapper `getWithRwOverloadRetry`, raw fetch, socket emits) in both trees | `tool/capability_parity.py` | `docs/capability-parity.json`, Dart path literals |
| Server route definitions, socket events | `router.get(...)` registrations; event names in socket modules | - | Dart literals |
| Field parity | interfaces / object types / zod objects in `packages/shared/src` and web `store/api/utils/hooks`: added, removed, retyped fields, split into wire / agent-contract / store-internal | field audit method of `docs/field-parity.md` | quoted keys in `apps/raft_flutter/lib`, `packages/*/lib`, `test/fixtures` |
| Server behaviour changes | changed lines in `packages/server/src/{routes,services,middleware,lib}` and `app.ts` that touch sorting, filtering, permissions, limits/defaults, rate limits, validation messages, with the affected endpoints and the Flutter features relying on them | capability JSON | same API shape, different logic: needs a human read and a live/fixture check |
| Behaviour-checklist drift | `tool/behavior-parity --web <new tree>`: audited Web symbols/events that CHANGED / MOVED / REMOVED | `docs/behavior-parity/*` | the checklists' audit verdicts |
| Web UI | changed components / pages / stores / hooks, lines, notable JSX tags, props, hooks, copy ids; new, removed, large unmapped files | counterpart map from `// Source: Foo.tsx` comments, the capability JSON `webEntry` and `flutterRefs`, doc mentions, file-name heuristics | `apps/raft_flutter/lib`, `packages/*/lib` |
| i18n | `en.ts` / `zh-cn.ts` ids added, removed, rewritten (English), reworded (zh only); appendix with the full sync list | - | `packages/raft_ui/lib/src/l10n/zh_*.dart` (keyed by English text; hand-derived from the Web catalog, no generator; `tool/gen_l10n_index.py` only merges the files) |
| Visual layer | `sharedCases.json` added / removed / changed cases; parity cases affected by changed components (official via `reactPathHint`, extension via `tool/parity-ext/host`) and the commands to re-run them | `docs/parity.md`, `tool/parity`, `tool/parity-ext` | case ids in `apps/raft_flutter/test/parity`, `tool/parity-ext` |
| Styles | CSS custom property changes, raft-ui / tailwind versions | `tool/gen-tokens`, `tool/design-source` | pinned raft-ui version |
| Release notes | release commit message, `CHANGELOG.md` additions, changed `manual/` pages | - | - |

### Decision table

One row per decision, each with: what changed, our current state, recommendation, reason, size (S/M/L), risk.

| Id | Row | Recommendation rules (heuristic) |
| --- | --- | --- |
| `A` | feature area (Web component directory, store, pages) with the API, type, string and visual items that belong to it | follow: small change to mirrored code; partial: mirrored but large or contract-only; skip: web-only surface or no counterpart and small |
| `F` | large new (or large changed but unmapped) Web file, a candidate feature | discuss |
| `R` | Web files removed that we mirror | discuss (skip when we never had it) |
| `G` | drifted rows of a behaviour checklist | partial (re-audit) |
| `B` | server behaviour change | partial when a Flutter feature relies on it, else skip |

Size counts changed lines plus weight for endpoints and strings (S <= 150, M <= 800, L above). Risk is high when a removed or
retyped endpoint / field is used by the app.

## Re-running visual cases against the new Web tree

The report lists the affected case ids and the commands. They need a private clone of the new tag with `pnpm install`
(the harness reads the Source commit from `git rev-parse HEAD`, so never point it at a checkout someone else uses):
`PARITY_RAFT_SOURCE=<clone> tool/parity run --cases '<ids>'` and
`PARITY_RAFT_SOURCE=<clone> tool/parity-ext/run run --cases '<globs>'`. The React cache key contains the Source commit, so captures
are re-taken. A drop on a case whose Web component changed means a visual follow-up row. The tool does not run captures itself.

## Limits to keep in mind

- Everything is regex- and name-based. Missing counterparts may be missing *mappings*; add a `// Source: Foo.tsx` comment
  or a capability entry and the next run finds it.
- The capability extractor only knows the `api`/`client` receivers and listed wrappers. When upstream adds a wrapper, endpoints
  appear removed/added; fix the extractor (as done for `getWithRwOverloadRetry`) before judging.
- Server behaviour and field sections point at places to look; they do not prove a divergence.
- Snapshot tags carry no per-change notes. Product release notes are served by the Web server, not stored in the tree.

## Commands

```bash
python3 tool/upstream_sync.py status                 # pinned, latest, recent history
python3 tool/upstream_sync.py latest                 # newest tag
python3 tool/upstream_sync.py report [--from T] [--to T] [--out DIR] [--keep-trees] [--visual-note TEXT]
python3 tool/upstream_sync.py pins                   # files that still cite the pinned revision
python3 tool/upstream_sync.py record-decision --to T --decision partial --note "..." --report docs/upstream-reports/X.md [--defer A03]
python3 -m unittest discover -s tool/tests -p 'test_upstream_sync.py'
RAFT_WEB_SOURCE=<extracted new tree> tool/flutter test apps/raft_flutter/test/capability_parity_guard_test.dart   # lists endpoints missing from the capability JSON
```

Global options (before the subcommand): `--mirror DIR`, `--remote URL`, `--repo DIR`, `--no-fetch`. A failed fetch (network
or authentication) exits 3 with the git message; the repository is public and needs no credentials.
