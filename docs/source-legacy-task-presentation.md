# Legacy task presentation

This is a bounded K10b container repair. Modern task properties and discussion,
the separate task URI revision, and active-grid task suppression retain their
existing owners. K10b remains **partial**.

Source is pinned to `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`
(Web 1.17.5, raft-ui 0.5.27). Source paths below are relative to
`packages/web/src`.

## Source and actual mounted input

| Source | Contract |
| --- | --- |
| `components/layout/MainLayout.tsx:1276–1312,1394–1417` | Ordinary thread/profile and active workspace take precedence over legacy presentation. Off `/tasks`, legacy uses a side panel. `/tasks` uses a centered modal at 768px and above; below that it uses the mobile modal. |
| `components/layout/MainLayout.tsx:1377–1391` | Search/Activity content routes return before the legacy branch. A retained legacy identity does not invent a visible panel there. |
| `components/task/LegacyTaskPanel.tsx:17–100` | Side presentation docks at 1024px and above. Width defaults to380 and is limited to320–560, stored under `slock:legacyTaskPanelWidth`. Below1024 the side panel fills the actual content container. |
| `components/task/LegacyTaskPanel.tsx:104–169` | The side back chevron remains visible below1024; its X appears at1024. `/tasks` mobile uses the back chevron; its desktop modal uses X. Closing empties the legacy slot. |
| `components/task/LegacyTaskPanel.tsx:171–226` | Legacy is accepted metadata only: no discussion, History, assignment editor or status mutation. |
| `hooks/useResizablePanel.ts:19–81` | Pointer movement changes bounded width; ending the drag persists it. A missing/invalid stored width uses the default. |

An isolated **real pinned Source App** exercised the actual channel Tasks card
and `/tasks` card. Workspace mode was disabled using its real preference; no
Source UI, availability gate, shared fixture, calibration or threshold changed.
Each route ran at390/800/1280×900 in Brutal light, Elegant light and Elegant dark.

| Real Source container | Measured bounds |
| --- | --- |
| Channel1280 | x900, width380, height900; real drag changes width to440, Close/reopen retains440. |
| Channel800 | Brutal x304/width496; Elegant x296/width504. The rail/sidebar stays visible. |
| Channel390 | x0, width390, height900. |
| `/tasks`800/1280 | Centered760×702, y99. |
| `/tasks`390 | Width390; Brutal height847 because its in-flow bottom bar remains outside the panel, Elegant height900. |

All18 cases opened and closed their actual panel. The three desktop channel
cases also dragged, closed/reopened, resized to800 and390, and closed through
the actual back button. Their final URI exactly retained the original route
and removed only `legacyTask`. These are DOM bounds and69 stage PNG
observations, **not** continuous renderer, pixel-score or native evidence.

Private immutable evidence under
`/home/kevinzhow/github/raft-flutter-wt/cody-parallel-members`:

- `.local/legacy-task-source-v1/fixture.json`:
  SHA256 `c32e7e824a71bb66ec35d0c1761737a0390c4434a5d28da3c818ed5df77a97c2`.
- `.local/legacy-task-source-capture-v2.mjs`:
  SHA256 `b17800112fd73dc0a2844bd748aad35a2da9b5bbef4c7ed0e0b21b57f7391843`.
- Source input SHA256
  `799c42a7703b30e809471e9835dfeeb1adbb75c06ae8689562685970292fef17`;
  runtime SHA256
  `ba8f7cb55572030b1651e1b2aace7cf98b4e6b65af3983d67852035171aefd1f`.
- `.local/legacy-task-source-v2/report.json`:
  SHA256 `c95b4f20d0b4664f3c5c272317a1f7fe7432e580b35c0cb5f56bcfcbd3b58cc6`.
  `readback-assertions.json` separately verifies all18 opened bounds, every
  final closed URI, and the three440px retention/resize sequences. Original
  v1 observations remain intact. Private port15417 was closed after capture.
- `.local/legacy-task-source-v3/report.json` independently records three real
  desktop drag→Escape→reopen sequences and24 stage PNGs, with the same fixture,
  Source input and runtime. Report SHA256
  `279deb1b64768e42d40e00ced037ba61adc486cbf8b08b0caf533a4bc64118ca`;
  runner SHA256
  `cb0303dc2557c92e3e38c737f19ba3a3f4cb7f8a5b243c2c3a15b4a7cdac273d`.
  Escape closes the panel and exactly retains the original channel Tasks URI.

## Flutter change and tested boundary

`RaftLegacyTaskPresentation` gives the existing shared task component its
Source side/modal/mobile-modal container. `WorkspaceTaskHost` chooses that
container from the actual route and viewport. A dock reserves content width
inside `RaftAdaptiveWorkspace`, retaining the full viewport breakpoint,
rail/sidebar, real editor instance and cursor. Shrinking the entire workspace
would incorrectly turn a resized desktop dock into mobile navigation.

The legacy owner remains separate from the main and ordinary side windows.
Hidden grid/profile/content-route presentation retains the owner; authority
and task revision changes still retire it. Pending legacy metadata reserves no
width and renders no fabricated facts. Header back, X and Escape remove only
the owned legacy query. The shared8px resize hit strip consumes no layout width.

Width persistence accepts a valid numeric stored value and ignores invalid
values. The asynchronous preference read cannot overwrite a newer real drag.
The actual WorkspaceView Escape shortcut receives the presented legacy
owner's Close callback, so focus retained in the underlying board cannot turn
Escape into browser Back. Hardware/history Back retains its existing owner.
Existing resizer focus and pointer behavior are unchanged.

`workspace_legacy_task_presentation_test.dart` mounts the real `WorkspaceView`:
18 actual card/Close cases, three real draft/drag/Escape/resize/reopen/clamp
sequences,12 delayed bucket retirement cases, three accepted role denials,
three retained-profile priority cases, and six persisted-width cases. It uses
the existing product font loader, actual fixture HTTP and held responses.
It never injects focus, changes a threshold, or creates a native claim.

| Check | Receipt |
| --- | --- |
|45 new three-theme mounted cases | `.local/legacy-task-mounted-v6.log` |
|168 task URL, entrypoint, cold parent, grid suppression/thread-tab and task checks passed | `.local/legacy-task-regression-v4.log` |
|42 shared task preview, adaptive workspace, shell and thread checks passed | `.local/legacy-task-sdk-regression-v4.log` |
| App/SDK selected analysis | `.local/legacy-task-analysis-v5.log` |
| Design-system ratchet: no growth or baseline edit | `.local/legacy-task-ds-v3.log` |

Earlier failures stay immutable: `legacy-task-mounted-v1.log` counted the
underlying board editor as a legacy panel control and tried pointer tap as
keyboard focus; `legacy-task-regression-v1.log` assumed that an unused
channel capability overrides the server-level permission helper;
`legacy-task-mounted-v3.log`/`legacy-task-clamp-diagnostic-v1.log` exposed
Ahem's false subtitle wrap at320px; `legacy-task-mounted-v4.log` and the
focus diagnostic receipts show the underlying board filter group's Tab loop.
An opt-in pointer-focus experiment passed `legacy-task-mounted-v5.log` but
was withdrawn before handoff: Source pointer semantics take precedence over
an unsupported Arrow resize test. That passing experiment is not final product
evidence. The final test exercises the actually supported drag and independently
proved Escape contract, retaining the failed Arrow attempt as a gap.
`legacy-task-ds-v1.log` retained the initial raw
dimension failure, repaired with the shared resize recipe constant.
`legacy-task-analysis-v2.log` retained the new missing-braces diagnostic.

## Remaining gaps

This does not implement simultaneous modern-plus-legacy owners, exact shared
Timeline/history rendering, measured assignment popovers, or legacy header
icon/typography/border pixels. Generic grid openers, standalone grid Tasks-card
thread-tab override, grid URI restoration and header portals remain separately
documented gaps. Existing active-grid global-task suppression and reachable
footer independent thread tabs remain intact.

The narrow `/tasks` footer is proved only without a live-activity bar and with
zero device safe-area inset. Live-activity stacking, nonzero safe-area/IME,
persisted width on the very first seeded frame, medium pointer-resizer behavior,
and all native/pixel comparisons remain unproved. The underlying board's Tab
traversal is also outside this repair. Source stage observations retain their
raw theme/header differences; they were not normalized into a parity PASS.

No Root checkout, backend, device, existing Source input, parity fixture,
Markdown/calibration work or public push was changed in this private phase.
