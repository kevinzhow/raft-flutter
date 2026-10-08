# Desktop parity findings: Web vs Flutter Linux (first pass)

Date: 2026-10-09. Measurement only; no product code changed.

## What was compared

- **Web (provider `react`)**: the real Raft Web app (`packages/web` `index.html` → `main.tsx` → `App`, raft-source `26f77ef`). It is served by Vite (`tool/desktop-parity/web-runtime.mjs`) with every `/api/*` call answered from `tool/desktop-parity/desktop-fixture.json`. Chromium 1234 runs at 1x with real raft-ui fonts loaded from Google Fonts. Each capture checks that every raft-ui family used by visible text is loaded, and records the result in the metadata (`fonts`).
- **Flutter (provider `android`, metadata `source: flutter-linux`)**: the real `WorkspaceView` running on the Flutter Linux desktop engine under xvfb. Startup goes through the real `WorkspaceController.bootstrap()`, with a fixture `RaftClient` whose `request()` answers from the **same JSON file** using the same lookup rule. Navigation uses real taps and mouse hover on product keys. Capture is `RepaintBoundary.toImage` at 1x.
- **Cases**: `docs/desktop-cases.json` contains 105 cases (31 routes/states × 3 themes, plus 1440x900 for channel, thread, tasks and settings). They come from the Web desktop route table (LeftRail, MainLayout nested routes, ChatPanel tabs, `?thread=` column, settings navigation) plus the requested interaction states. Ids are `screens.desktop.<route>[.<size>].<theme>`.
- **Build under test**: worktree head `3f3c72f`, which is the WIP handoff commit. Six brutal routes were also captured from the released **`main` (`e210562`)** using the same harness. Three more failed there because their product keys don't exist on `main`. The `main` output is in `.local/desktop-parity/main-results/android/`.

Coordinates are logical px at 1280x800 unless stated. "W:" means Web, "F:" means Flutter. Region rects come from DOM and widget probes (`regions` in each metadata file). Separators come from `compare.py`.

Pixel mismatch (fraction of pixels with channel delta > 24), mean / max per theme:

| theme | mean | max |
|---|---|---|
| brutal | 0.065 | 0.180 |
| elegant-light | 0.042 | 0.140 |
| elegant-dark | 0.053 | 0.173 |

## Findings, ordered by visual impact

### 1. The released `main` build keeps the chat sidebar on every primary route

This is the human report. On `main` (`e210562`), Tasks, Search, Activity and Settings all keep a 240 px conversation sidebar at x=64..304. That sidebar has its own nav list (Activity, Search, Saved, Tasks, channels, DMs, and a "WORKSPACE" section with Agents, Computers, Members, Integrations, Joint channels, Administration, Billing, Sidebar preferences, Workspace settings). Content is squeezed into x=304..1280.

- W: Tasks, Search and Activity hide the sidebar, and content fills x=64..1280 (`MainLayout.tsx:2170` `hideSidebar = isTasksRoute || (isContentRoute && !searchMasterDetail)`).
- The WIP head `3f3c72f` fixes this for Tasks, Search and Activity: content is at x=64..1280 on both sides (`desktop_navigation_policy.dart`).
- Evidence: `main-results/android/screens.desktop.{tasks.board,search.empty,activity.inbox,settings.account}.brutal.png`.

### 2. Settings uses a different shell structure (8 tabs × 3 themes; highest mismatch, 0.06–0.18)

- **W**: rail | settings nav in the sidebar slot at x=64..304 (240 wide). The nav has a sidebar-style "Settings" title row at y=0..59, grouped Personal / Workspace / Resources. Content starts at x=304, with its own page header (icon tile + "Account") at y=0..59. Content cards begin at y≈77.
- **F**: rail | a **full-width page header** at x=64..1280, y=0..59 ("Settings" icon tile plus a refresh button with a dot). Below it is a second header row at y=59..122: "Settings" over a 220 px nav (x=64..283, separator at x=283) and "Account" over the content. Content starts at x≈300, y≈139.
  - Result: Flutter content sits ≈62 px lower and the nav is 20 px narrower. Brutal separators: W x=301 vs F x=283. Elegant: W x=294 vs F x=275.
- Nav items differ:
  - W: Account, Language & Region, Appearance, Notifications | Server Profile, Plan & Billing, Administration, Applications, MCP Servers | About, Documentation, Feedback, Release Notes.
  - F: Account, Language & Region, Appearance, Notifications | Sidebar preferences, Joint channels, Server profile, Plan & Billing, Administration, Applications. F has no MCP Servers and no Resources group.
- Account page:
  - W has a "Workspace mode" card at the top. Its Session card holds a "Log out" button on the right.
  - F has no Workspace mode card. It adds a "Refresh sign-in methods" button and a row of five buttons (Change profile image, Display language, Edit profile, Reading preferences, Connected sign-in accounts), with "Sign out" below.
- Appearance (brutal): Flutter's "Brutal" light-appearance preview card is drawn as a solid black block, and its "Brutal" label is missing. W draws a framed preview with the label and a check.
- Selected nav row: W is a pink filled row with a hard shadow, full nav width. F is pink, ≈20 px narrower.

### 3. Members and Computers detail panes are much thinner on Flutter

- **Agent detail** (`members.agent`):
  - W: header bar (pixel avatar + "Cindy" + three icon buttons) and a tab strip (Profile, Activity, Chat, Reminders, Workspace, Apps, MCP). Below that, a profile with a large avatar, @handle, live activity, Description, an INFO table (Role chip, Computer, status, version, Created, Creator), a RUNTIME CONFIG chip table, Created agents and Skills.
  - F: title row "Cindy" + close ×, then a plain property list (Status, Runtime, Model, Workspace role) and a vertical action list (Edit agent, Edit runtime configuration, Start/Stop, Restart runtime, Reset session, Reset workspace, Agent migration). F has no tabs, no avatar header and no chips.
- **Human detail**:
  - W: avatar header bar, profile block, DESCRIPTION, INFO (Role chip, Email, Joined), CREATED AGENTS.
  - F: avatar, name, description, email, and a pink "Message" button.
- **Computer detail**:
  - W: header, a large status block (Connected, hostname), NAME, DESCRIPTION, INFO (OS, version, Detected Runtimes chips, Created, Creator), and AGENTS ON THIS COMPUTER rows with Select/Create buttons.
  - F: property list (Status, Hostname, OS, Computer version) and an action list.
- **Robustness**: with a bare-array `GET /servers/:id/machines` body (which Web accepts), Flutter's computer detail rendered the error text `type 'String' is not a subtype of type 'int' of 'index'` followed by `null`. The final fixture uses the production `{machines:[…]}` shape. Flutter should tolerate both, as Web does (`machineStore.ts:280`).

### 4. Members and Computers page chrome

- **W**: the directory lives in the sidebar slot (x=64..304, y=0..800). Its title ("Members" / "Computers") is at the sidebar top. The main area shows the "SELECT A CHANNEL" placeholder until an item is chosen.
- **F, Computers**: a full-width page header "Computers" at y=0..62. Below it, master at x=64..304 starting at y=62, with a second "Computers" title and a refresh button. The empty detail at x=304..1280 has no placeholder text.
- **F, Members**: the master starts at y=0 (no page header), and its title row carries a refresh button.
- Directory rows:
  - Agents: W shows a pixel avatar, name and grey description, grouped under a "jiachengs-macbook-pro 2" computer sub-header. F shows a coloured square icon and the name only.
  - Humans: W shows "artin (you) Owner"; F shows "artin".
  - Computers: W has a status-dot badge and a "computer v0.0.48 → v0.0.50" subline; F shows one line.
  - W also shows a "Graph" link above AGENTS; F has none.

### 5. Left rail differences (every case)

- Bottom cluster: W has 4 buttons (bell at y≈611, Help, Workspace-mode toggle, Settings). F has 2 (bell at y≈730, Settings).
- As a result, the **notification center opens 120 px lower**: W rect (59, 344, 320, 288) vs F (60, 464, 320, 288). Size and content match.
- W shows attention dots on the Activity rail button (3 unread) and the Computers button (offline machine). F shows none.
- Rail hover tooltip: W shows it **to the right** of the button, vertically centred (the "Tasks" pill at x≈56). F shows it **below** the button, horizontally centred.
  - When the bell is hovered, F also shows a "Notification center" tooltip clipped at the rail's left edge. W shows none.
- Elegant server avatar: W is a borderless circle with a "V" glyph. F is a white rounded square with a 1 px border.
- Rail width matches (brutal 64, elegant 56), as does the first button position (W y=70/72 vs F y=72/74, so F is 2 px lower).

### 6. Chat sidebar content

- W always shows the **Pinned** ("Drag channels or DMs here to pin") and **Joint Channels** ("No joint channels yet") empty sections. F hides both once loaded, so CHANNELS starts at y≈84 vs W y≈165 and every row below moves up ≈81 px.
  - F does show Pinned and Joint while loading, with skeleton rows.
- F adds a "Visual Server ▾" workspace switcher in the sidebar title row and an "artin" account footer at y≈766..800. W has neither; it switches servers from the rail avatar.
- DM row: W shows Cindy's pixel avatar plus the grey description "Keeps visual testing re…". F shows a generic person glyph and the name only.
- Section header icons: W shows sort ⇅ (and + for channels). F shows sort and + on both CHANNELS and DIRECT MESSAGES, with a slightly different sort glyph.

### 7. Conversation header

- Brutal right actions: W has boxed Search and Channel settings buttons at x≈1198..1258. F has a status dot, a sliders icon and a refresh icon, all unboxed.
- Elegant:
  - W puts "# design" and the description "Product and UI decisions" on **one line** next to a 36 px ghost "#" tile, with a header bottom border at y=54.
  - F is **two lines** (title, then a monospace description) next to a filled yellow "#" tile, and has no header bottom border. The tab underline position matches.
- DM header:
  - W shows Cindy's pixel avatar, a presence dot and the live activity text "Capturing visual testing baselines".
  - F shows a "#" tile and "Cindy".
  - Composer placeholder: W "Message @Cindy" vs F "Message #Cindy".

### 8. Loading state (`state.channel-loading`, message page never answers)

- W keeps the header with the Chat/Tasks/Files tabs and the composer, and shows the text "Loading..." at the top of the message area.
- F shows the header **without tabs**, **no composer**, and a small spinner at the centre of the content. Its sidebar shows Pinned/Joint sections with skeleton rows.

### 9. Tasks (board and list)

- Structure matches: no sidebar; content x=64..1280 (brutal), lanes at the same x positions, filter row and cards aligned.
- Differences:
  - F adds header actions (refresh, +, sliders); W has none.
  - Toolbar: W filter row ends at y=117 vs F y=133 (F 16 px taller).
  - Lane headers: W uppercase chips ("TODO", "IN PROGRESS") vs F title case with a leading icon, plus a collapse chevron per lane on F.
  - Done lane: W lazy-loads it (count 0, subtitle "3 channel tasks"); F loads eagerly (count 1, "4 channel tasks").
  - Card status chip: W is a bordered button with a hard shadow and a pencil glyph ("Todo ✎"); F is a flat icon + label chip.
- List layout: same grouping. F adds chevrons and pushes rows down (W first card y≈166 vs F ≈175; later groups drift up to ≈20 px).
- Channel Tasks tab: W has a "+ New Task" button in the filter row and dashed empty lanes ("No Todo tasks."). F has no New Task button and shows "No tasks · Todo".

### 10. Search

- Structure matches (no sidebar; full-width search bar at top; filter chips From / Scope / Channel / Any Time / Relevant).
- Empty state:
  - W: magnifier icon, "Search everything", "Search channels, DMs, people, agents, and message history.".
  - F: chat-bubble icon, "Search your workspace", "Enter words to find messages.".
- Field: W placeholder "Search channels, DMs, messages... Ctrl+K" with an ESC chip; F "Search messages" with no hint.
- Results ("visual"): both show 3 results (one agent entity, two messages) in the same order.
  - W: heading "3 RESULTS" and section labels in small caps. The result column is inset ≈16 px further right (W card text x≈110 vs F x≈92). The entity card shows Cindy's pixel avatar and a bordered "AGENT" chip, and has a hard shadow. Message sender chips use the pixel avatar.
  - F: "3 results" in sentence case and "Server entities" / "Messages" in letter-spaced monospace. The entity card shows a generic robot glyph and a soft "Agent" chip. Sender chips use a coloured square.
  - Filter chips: W has light borders with no shadow; F has heavier borders with hard shadows.

### 11. Activity

Structure matches (no sidebar; filter row; full-width cards). In brutal, W cards have a 2 px black border and a hard offset shadow; F cards have a 1 px grey border and no shadow. Chips: W "5 replies" / "@ you" / "2 new" have black borders and fills; F chips are softer with no border. F adds a sliders icon in the header.

### 12. Message rows and thread panel (near parity)

- Thread column geometry is **identical**: x=880, width 400 on both. The main column is x=304..880 (brutal) and 296..880 (elegant).
- Brutal message row inset: W x=328, w=928 vs F x=316, w=952 (F is 12 px further left and 24 px wider). In elegant both are x=308, w=960.
- In the Flutter inline-thread summary, timestamps are bold; Web's are regular.
- Thread reply author badge: W "Member" vs F "Owner" for artin. Same fixture, so Web derives it from the thread channel's members.
- Thread header: W "Thread— #design" with no space before the em dash; F "Thread — #design".

### 13. Hover and interaction states (close to parity)

- Message hover toolbar: same position (top-right of the row, three buttons: thread, reaction, save) and the same brutal outline around the hovered row.
- Reaction picker rect: brutal W (996, 435, 224, 40) = F (996, 435, 224, 40); elegant W (979, 422, 220, 36) vs F (980, 422, 220, 36). The emoji set and order match.
- Sidebar row hover (brutal): both show a white fill, black border and hard shadow on #android-artifacts.
- Composer focus: equivalent framing. Dark mode shows the pink focus ring on both. The Web caret is hidden by the harness (stabilising CSS), so caret colour is not compared.

## Harness notes and limits

- Fixed fixture data is shared by both sides. Time is not frozen on either side (Flutter uses `DateTime.now()` everywhere), so relative labels ("109 days ago") match only when both sides are captured on the same day.
- Web realtime socket: refused deterministically. Web loads agents and machines via its 2 s no-socket fallback, so captures wait 2.6 s after ready. The push-permission banner is suppressed by granting the notification permission, the equivalent of a desktop client. Dev-only overlays (react-scan, react-grab) are hidden with CSS.
- After click-only steps, the Web pointer is parked on inert header chrome at (0.55w, 2) so no stale hover remains. Flutter taps leave no hover.
- Remaining Web fixture misses (404): `/servers/:id/machines/:mid/runtime-models/codex` and `/runtime-account-usage/*`, requested only by agent detail. Flutter misses: `GET /messages/msg-agent-reply/reactions/viewer` (answered with the neutral default).
- Flutter is given `notifications: NativeNotificationService()` as production does (`main.dart:276`). Without it, Settings > Notifications does not exist.

## Rerun

```bash
# 1. fixture + cases (deterministic generators)
python3 tool/desktop-parity/build-fixture.py
python3 tool/desktop-parity/build-cases.py
# 2. Web runtime (Node 24: prepend the toolchain bin dir to PATH, unset npm_config_*)
node tool/desktop-parity/web-runtime.mjs 15260 &
# 3. captures (official provider layout under .local/desktop-parity/visual-testing-results/{react,android})
node tool/desktop-parity/capture-web.mjs            # --only <substr,...>
tool/desktop-parity/capture-flutter.sh              # [substr,...]; uses xvfb-run when no DISPLAY
# 4. pairing: side-by-side + diff mask + summary.json
python3 tool/desktop-parity/compare.py
```

Flutter needs the Linux media runtime at `.local/media-linux` (`tool/prepare-media-linux`, or a symlink to the main checkout's prepared copy). Run only one Flutter Linux integration test at a time on the display: two concurrent runs fail with "Error waiting for a debug connection".
