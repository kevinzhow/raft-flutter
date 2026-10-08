# Glyphs: generated Lucide set and Material icon mapping

Raft Web draws every icon with Lucide. The Flutter client must draw the same
geometry, so `RaftGlyph` is generated from the exact lucide-react builds the
Web ships, the painter is checked pixel by pixel against Chromium, and every
Material `Icons.*` left in the app is traced to the Web element it mirrors.

## 1. Generated glyph set (`tool/gen-glyphs`)

Two Lucide builds reach the Web screen (raft-source 26f77ef):

| Build | Who imports it | Names | Icons |
| --- | --- | --- | --- |
| lucide-react 0.575.0 | Web product code, `packages/web/src/**/*.ts(x)` (628 import specifiers in 133 files) | 152 | 148 |
| lucide-react 1.48.0 | raft-ui 0.5.27 `dist/index.mjs` (drawn inside raft-ui components) | 14 | 14 |

```
tool/gen-glyphs --import-sources --raft-source <raft-source checkout> [--raft-ui <dir>]
    # scan imports, resolve names via the pinned export maps, read iconNode arrays,
    # vendor nodes + sha256 + usage file:line in tool/design-source/lucide/glyphs.json
tool/gen-glyphs            # write packages/raft_ui/lib/src/glyphs.g.dart ("GENERATED — do not edit")
tool/gen-glyphs --check    # stale check (also tool/tests/test_gen_glyphs.py)
tool/gen-glyphs --list     # enum name, lucide icon, build, users
```

The output has **175 `RaftGlyph` values** and **167 geometries**:

- **152 Web names.** One value per Web import name, in lowerCamel (`CheckSquare` → `checkSquare`, `Home` → `home`, `Image as ImageIcon` → `image`). A call site reads like the Web import it mirrors. Aliases share one geometry.
- **raft-ui names.** These carry 1.48.0 geometry. Of the 14 names raft-ui imports, 13 have byte-identical geometry in both builds. The 14th, `CheckCircle2`, differs between builds: in 1.48.0 the tick is `m16 9-5.5 5.5L8 12`, in 0.575.0 it is `m9 12 2 2 4-4`. So it gets a second value, `checkCircle2RaftUi`, which `RaftNotificationCenter` now uses for the success status (raft-ui `DEFAULT_STATUS_ICON`, index.mjs:15048). `minus` is imported only by raft-ui.
- **20 legacy names.** These pre-generator names (`ellipsis`, `squareCheck`, `menu`, ...) are kept so existing code compiles. They resolve through the 0.575.0 export map. No Web file imports them, so treat them as candidates for review.
- **`bookmarkFilled`.** `bookmark` drawn with whole-icon `fill="currentColor"`, as Web does in MessageItem.tsx:4915 and SavedPanel.tsx:146. For any other glyph, use `RaftIcon(glyph, filled: true)` (e.g. Web `<Play fill="currentColor">`).

Compared with the hand-picked set, all 88 old names keep identical geometry
except `checkSquare`. It used to alias lucide `square-check`, but Web
`CheckSquare` is `square-check-big`. It now draws the Web icon (rail Tasks
tab, LeftRail.tsx:673).

## 2. Painter and pixel parity

`RaftIcon` / `RaftGlyphPainter` (`packages/raft_ui/lib/src/icons.dart`) draw the 24-unit viewBox scaled to `size`:

- **Elements.** All SVG element types are supported: `path` (the full SVG 1.1 grammar, including arcs with out-of-range radius correction via `Path.arcToPoint`), `circle`, `ellipse`, `rect` (rx/ry auto-resolved and clamped), `line`, `polyline` and `polygon`.
- **Stroke.** Round caps and joins. Each element is painted on its own, fill then stroke, as the browser does.
- **Fill.** Element-level `fill="currentColor"` (key-round, palette, tag) and whole-icon `filled` are both honoured.
- **Stroke width.** `strokeWidth` is in viewBox units, so it scales with size like lucide's default. `absoluteStrokeWidth: true` uses `strokeWidth * 24 / size`.

`tool/glyph-parity` checks the painter against Chromium:

- **Reference.** `--refresh-reference --raft-source DIR` renders `tool/glyph_parity/samples.json` (36 samples) with lucide-react's own `react-dom/server` markup. Playwright Chromium 147.0.7727.15 paints it at 16/20/24 px, deviceScaleFactor 1, black on white. The output is `tool/glyph_parity/reference/chromium.png` plus `manifest.json`.
- **Samples.** The 36 samples cover 0.575.0 and 1.48.0 builds, arcs, beziers, circles, rects, lines, the polyline in `inbox`, element fills, whole-icon fill, `strokeWidth` 2.5/3 and `absoluteStrokeWidth`. Probes (`database`, `codepen`, `navigation`) cover ellipse and polygon via `RaftGlyphPainter.debugNodes`.
- **Comparison.** `packages/raft_ui/test/glyph_parity_test.dart` paints the same grid with `RaftIcon` (`RepaintBoundary.toImage`) and compares every cell. It runs in `tool/check-project` with fixed ceilings. A geometry slip, such as the old `checkSquare`, scores 30+ mean-ink and fails.
- **Results** (`tool/glyph_parity/results.json`, 108 cells, 8-bit channel deltas):

| Size | Max delta | Mean delta (all pixels) | Mean delta (ink pixels) |
| --- | --- | --- | --- |
| 16 px | 64 | 0.022 | 0.152 |
| 20 px | 63 | 0.019 | 0.094 |
| 24 px | 35 | 0.032 | 0.142 |
| all | 64 | 0.024 | 0.159 |

The worst ink-coverage difference is 0.47%. The
worst cells are paperclip@16 (mean-ink 2.523, max 64), paperclip@20 (mean-ink 1.962, max 63), paperclip@24 (mean-ink 1.87, max 35), atSign@16 (mean-ink 1.335, max 39).
Their maxima are single anti-aliasing pixels where self-overlapping arcs meet.
Most cells are bit-identical.

## 3. Material `Icons.*` in apps/raft_flutter/lib

**Totals.** Before this change the app used 113 Material icons. **68 are
replaced** (one of them was a dead fallback, removed). **45 remain as TODO.**
`tool/ds-audit` `style.material_icons` went from 113 to 45, and the
baseline was lowered to match.

**Columns.**

- **Line numbers** are from commit 81b382e, before the replacement.
- **Web paths** are relative to `raft-source/packages/web/src`.
- **REPLACED** means the call site now uses `RaftIcon(RaftGlyph.x)`, at the cited Web size where the Flutter site had no explicit size.

A mapping counts as proven only when the cited Web line renders that lucide
icon on the same UI element. Icon names were never used as evidence.

**raft_ui API additions** let app code pass glyphs:

- `RaftButton.glyph`
- `RaftEmptyState.glyph`
- `RaftRailDestination.glyph` (`icon` is now optional)
- `ManagementState.action(glyph:, glyphSize:)` in the app

| Flutter (81b382e) | Material | UI element | Web file:line | Web lucide (props) | RaftGlyph | Status | Note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `features/sidebar_preferences_view.dart:246` | `Icons.drag_handle` | Sidebar prefs "Section order" reorder row, trailing handle | components/layout/Sidebar.tsx:425-457 (SortableSidebarItem) | none | — | TODO | Web has no prefs page. Sidebar rows drag as a whole (`cursor-grab`) and show no grip icon. The only `GripVertical` (ServerSwitcherMenu.tsx:187) belongs to the server switcher. |
| `features/sidebar_preferences_view.dart:293` | `Icons.drag_handle` | Sidebar prefs pinned-order reorder row, trailing handle | components/layout/Sidebar.tsx:425-457 | none | — | TODO | Same as above: pinned items drag as a whole row with no grip icon. |
| `features/sidebar_preferences_view.dart:344` | `Icons.visibility_off` | Sidebar prefs DM row, shown when the DM is hidden ("Show direct message") | components/layout/Sidebar.tsx:1614,1735 (reopenDm) | none | — | TODO | Web has no "show DM" control. A closed DM reopens on its own when you navigate to it. |
| `features/sidebar_preferences_view.dart:345` | `Icons.visibility` | Sidebar prefs DM row, shown when the DM is visible ("Hide direct message") | components/layout/Sidebar.tsx:5066 (also 5027, 5170) | `X` (size={14}) | x | TODO | proven, but its toggle partner (:344) is not; the conditional stays Material. Same action is the DM context-menu item "Close Chat" (`layout.sidebar.closeChat`) calling closeDm. Web uses a menu item, not a toggle. |
| `features/sidebar_preferences_view.dart:356` | `Icons.drag_handle` | Sidebar prefs channel/DM order row, trailing handle | components/layout/Sidebar.tsx:425-457 | none | — | TODO | Whole-row drag, no grip icon. |
| `features/sidebar_preferences_view.dart:419` | `Icons.delete_outline` | Custom section row "Remove section" button | components/layout/Sidebar.tsx:4822 | `Trash2` (size={14}) | trash2 | REPLACED | Section context-menu item "Delete section" (`layout.sidebar.deleteSection`). |
| `features/sidebar_preferences_view.dart:434` | `Icons.smart_toy_outlined` | Sidebar prefs agent list row (leading), tap to place the agent in a section | components/layout/Sidebar.tsx:1083; components/ui/AvatarSlot.tsx:221 | none (AgentAvatar pixel art) | — | TODO | Web has no such list. Agent rows use the agent avatar, which is not lucide. |
| `features/thread_actions.dart:247` | `Icons.notifications_off_outlined` | Inline thread follow toggle when following ("Unfollow thread") | components/message/ThreadOverflowMenu.tsx:110 (also MessageItem.tsx:5258) | `MessageCircleOff` (no props in the menu; size={14} in MessageItem) | messageCircleOff | REPLACED | Branch `followed ?` matches `message.messageItem.unfollowThread`. |
| `features/thread_actions.dart:248` | `Icons.notifications_active_outlined` | Inline thread follow toggle when not following ("Follow thread") | components/message/ThreadOverflowMenu.tsx:110 (also MessageItem.tsx:5258) | `MessageCirclePlus` (no props; size={14} in MessageItem) | messageCirclePlus | REPLACED | Branch `: <MessageCirclePlus />` matches `followThread`. |
| `features/workspace_view.dart:874` | `Icons.circle` | Page-header connected/reconnecting status dot (size 8) | not found | none | — | TODO | No Connected/Reconnecting header indicator exists in Web (no i18n key, no component). |
| `features/workspace_view.dart:1273` | `Icons.search` | Rail destination "Search" (`icon:` fallback) | components/layout/LeftRail.tsx:654 (also 375, 780) | `Search` (size={18}) | search | REPLACED | Already set via iconWidget. |
| `features/workspace_view.dart:1279` | `Icons.chat_bubble_outline` | Rail destination "Chat" | components/layout/LeftRail.tsx:655 | `MessageSquare` (size={18}) | messageSquare | REPLACED |  |
| `features/workspace_view.dart:1285` | `Icons.inbox_outlined` | Rail destination "Activity" | components/layout/LeftRail.tsx:657 | `Activity` (size={18}) | activity | REPLACED | Material says inbox, Web says Activity. |
| `features/workspace_view.dart:1292` | `Icons.check_box_outlined` | Rail destination "Tasks" | components/layout/LeftRail.tsx:673 | `CheckSquare` (size={18}) | checkSquare | REPLACED |  |
| `features/workspace_view.dart:1299` | `Icons.people_outline` | Rail destination "Members" | components/layout/LeftRail.tsx:674 | `Users` (size={18}) | users | REPLACED |  |
| `features/workspace_view.dart:1306` | `Icons.computer_outlined` | Rail destination "Computers" | components/layout/LeftRail.tsx:676 | `Monitor` (size={18}) | monitor | REPLACED |  |
| `features/workspace_view.dart:1354` | `Icons.check` | Workspace-switcher dialog, mark on the current server | components/ui/ServerSwitcherMenu.tsx:158 | `Check` (size={14}, opacity 0/100 by isCurrent) | check | REPLACED | In Web the check is leading and always laid out (hidden by opacity). In Flutter it is trailing and only shown on the current server. |
| `features/workspace_view.dart:1547` | `Icons.smart_toy_outlined` | Sidebar agent entry (RaftNavItem) | components/layout/Sidebar.tsx:1083; components/ui/AvatarSlot.tsx:221 | none (AgentAvatar pixel art) | — | TODO | AgentDmRow renders the agent avatar, which is not lucide. |
| `features/workspace_view.dart:1604` | `Icons.person_outline` | Sidebar channel item, `type=='dm'` | components/layout/Sidebar.tsx:994-999 → components/ui/AvatarSlot.tsx:230 | `User` (size={10} for sidebar-list, inside an 18px avatar) | user | REPLACED | Only for a human DM with no avatar (`humanPlaceholder`). Otherwise Web shows a Gravatar or avatar image. Agent DMs use AgentAvatar (Sidebar.tsx:987). |
| `features/workspace_view.dart:1606` | `Icons.archive_outlined` | Sidebar channel item, archived | components/layout/Sidebar.tsx:2501 | none | — | REMOVED | dead fallback removed: RaftNavItem already renders `glyph:` (hash for an archived public channel); Web never lists archived channels. Web's sidebar filters out archived channels (`!channel.archivedAt`). ChannelKindIcon has no archived branch. |
| `features/workspace_view.dart:1608` | `Icons.lock_outline` | Sidebar channel item, private | components/channel/channelKindIcon.tsx:15 (rendered at Sidebar.tsx:867) | `Lock` (size={14}) | lock | REPLACED |  |
| `features/workspace_view.dart:1610` | `Icons.link` | Sidebar channel item, joint | components/channel/channelKindIcon.tsx:16 (Sidebar.tsx:867) | `GitBranch` (size={14}) | gitBranch | REPLACED | Material "link" is wrong. Web uses GitBranch. |
| `features/workspace_view.dart:1611` | `Icons.tag` | Sidebar channel item, public channel (default) | components/channel/channelKindIcon.tsx:17 (Sidebar.tsx:867) | `Hash` (size={14}) | hash | REPLACED |  |
| `features/workspace_view.dart:1749` | `Icons.open_in_new` | Linux-only "Open workspace in browser" button in the workspace menu | not found | none | — | TODO | The feature does not exist in Web (no open-in-browser per server in ServerSwitcherMenu or elsewhere). |
| `features/workspace_view.dart:1780` | `Icons.expand_more` | Workspace-name dropdown trigger in the sidebar header | components/layout/Sidebar.tsx:3800 | `ChevronDown` (size={16}, `rotate-2`, `rotate-0` at max-h 600) | chevronDown | REPLACED | Web renders this pill only on mobile (`mobileInline`, Sidebar.tsx:3769). On desktop Web uses the LeftRail server avatar, with no chevron. |
| `features/workspace_view.dart:1808` | `Icons.search` | Mobile-home sidebar "Search" entry | components/layout/Sidebar.tsx:3962 | `Search` (size={14}) | search | REPLACED | mobileInline only, as in Flutter. |
| `features/workspace_view.dart:1819` | `Icons.inbox_outlined` | Mobile-home sidebar "Activity" entry | components/layout/Sidebar.tsx:3993 | `Activity` (size={14}) | activity | REPLACED |  |
| `features/workspace_view.dart:1840` | `Icons.account_circle_outlined` | Desktop sidebar bottom "Account" nav row | components/layout/Sidebar.tsx:4560-4562 | none | — | TODO | Web removed the bottom user bar. Account is reached via the LeftRail Settings button or the settings sub-nav (`User`, Sidebar.tsx:2233). |
| `features/workspace_view.dart:2083` | `Icons.logout` | "Sign out" button on Account settings | components/settings/SettingsPanel.tsx:962 (button), :948 (section header) | button: none; section header: `LogOut` (size={16}) | (logOut if used) | TODO | The Web "Log out" button is text only. `LogOut` sits on the section header above it. |
| `features/account_onboarding.dart:305` | `Icons.add_a_photo` | Onboarding profile step, "Choose profile image" avatar upload button | components/auth/AccountIdentitySetupPage.tsx:515 | `Camera` (size=15) | camera | REPLACED | Web button label is `pages.identitySetup.avatarCta` ("Upload") |
| `features/admin_views.dart:284` | `Icons.public` | Admin public visibility: row leading icon in the exposed channels list | components/settings/SettingsPanel.tsx:2127 | `Hash` (size=14, strokeWidth=2.5) | hash | REPLACED | Sits in a size-7 bordered chip in `PublicChannelList` |
| `features/agent_apps_view.dart:305` | `Icons.add` | "Grant app access" action in the Agent App Access view | components/agent/AgentAppAccessTab.tsx:376 | none | — | TODO | Web `agent.apps.grantAccess` is a text-only outline Button. The file has no lucide import |
| `features/agent_migration_view.dart:178` | `Icons.refresh` | Agent migration AppBar Refresh button | components/agentMigration/AgentMigrationSection.tsx:60-138 | none | — | TODO | Web has no migration screen and no manual refresh. Status refreshes through `useAgentMigrationStatus` |
| `features/fleet_views.dart:290` | `Icons.refresh` | Agents/Computers list header Refresh IconButton | components/machine/MobileComputersPanel.tsx:97,110 | (`RefreshCw` size=14, only in the Retry button after an error) | — | TODO | Web has no header refresh. `RefreshCw` appears only in the load-error Retry button |
| `features/fleet_views.dart:310` | `Icons.computer` | "Create managed agent" button on the Agents list | components/layout/Sidebar.tsx:2430 | `Bot` (size=14, className shrink-0) | bot | REPLACED | Web "+" menu item `layout.sidebar.createAgent`, which opens `openCreateAgentDialog` (managed agent). External agent is a separate item with `Link2` |
| `features/fleet_views.dart:342` | `Icons.computer` | Computers list row leading icon (agents branch uses RaftAvatar) | components/machine/MobileComputersPanel.tsx:149; components/layout/Sidebar.tsx:704 | `Monitor` (size=20 mobile page / size=18 sidebar) | monitor | REPLACED | Web wraps it in a bordered box with a StatusDot |
| `features/fleet_views.dart:350` | `Icons.chevron_right` | Fleet list row trailing chevron | components/machine/MobileComputersPanel.tsx:143-191; components/layout/Sidebar.tsx:689-720 | none | — | TODO | Web computer and agent rows have no trailing chevron |
| `features/fleet_views.dart:813` | `Icons.edit` | "Edit agent" / "Edit computer" tile | components/agent/AgentDetailPanel.tsx:677; components/machine/MachineDetailPanel.tsx:1108 | `Pencil` (agent size=14; computer size=12) | pencil | REPLACED | Both branches use `Pencil`. Web places it inline next to the name (also description: agent :1715, computer :1180) |
| `features/fleet_views.dart:822` | `Icons.tune` | "Edit runtime configuration" tile | components/agent/AgentDetailPanel.tsx:1993 | `Pencil` (size=12) | pencil | REPLACED | Inline icon button `agent.detail.editRuntimeConfig` |
| `features/fleet_views.dart:852` | `Icons.key` | "Rotate computer key" / "Connect external agent" tile | components/agent/ExternalAgentToken.tsx:102-105; store/machineStore.ts:417 | none | — | TODO | External: "Generate login token" is a text-only Button. Computer: `rotateApiKey` exists in the store but no UI calls it |
| `features/fleet_views.dart:893` | `Icons.restart_alt` | Restart runtime / Reset session / Reset workspace tiles | components/agent/AgentDetailPanel.tsx:3215; components/agent/ResetAgentDialog.tsx:106 | `RotateCcw` (size=14) | rotateCcw | REPLACED | Web has one "Restart/Reset" button plus a radio dialog. The confirm button uses `RotateCcw` for every mode |
| `features/fleet_views.dart:908` | `Icons.move_up` | "Agent migration" tile | components/agentMigration/AgentMigrationSection.tsx:78 | `MoveRight` (size=14, aria-hidden) | moveRight | REPLACED | Swapped for a Spinner while a migration is active. Label is "Move to another computer" |
| `features/fleet_views.dart:928` | `Icons.folder` | Computer "Workspaces" tile | components/machine/MachineDetailPanel.tsx:121 | `FolderOpen` (size=14) | folderOpen | REPLACED | SectionHeader icon for `machine.detail.agentWorkspaces` |
| `features/fleet_views.dart:934` | `Icons.security` | "Agent permissions" (scopes editor) tile | i18n/messages/en.ts:1444-1460 | none | — | TODO | The `agent.scopes.*` strings exist, but no Web component renders a scopes editor |
| `features/fleet_views.dart:947` | `Icons.psychology` | "Skills" tile | components/agent/AgentSkills.tsx:149-153 | none | — | TODO | Web Skills SectionHeader has no icon. Sub-sections use `Globe` / `FolderOpen` (size=12) |
| `features/fleet_views.dart:952` | `Icons.apps` | "App access" tile | components/agent/AgentDetailPanel.tsx:225 (rendered :3091) | `Link2` (size=12) | link2 | REPLACED | Agent panel tab "Apps" (`integrations`) |
| `features/fleet_views.dart:966` | `Icons.extension_outlined` | "MCP servers" tile | components/agent/AgentDetailPanel.tsx:226 (rendered :3091) | `Blocks` (size=12) | blocks | REPLACED | Agent panel tab "MCP" |
| `features/fleet_views.dart:979` | `Icons.history` | "Activity log" tile | components/agent/AgentDetailPanel.tsx:221 (rendered :3091) | `Activity` (size=12) | activity | REPLACED | Agent panel tab "Activity" |
| `features/fleet_views.dart:984` | `Icons.tag` | "Agent channels" tile | components/agent/AgentDetailPanel.tsx:222,375 | none (`ChatIcon` from raft-ui on the Chat tab) | — | TODO | Web shows channels in the Chat tab (non-lucide `ChatIcon`). The Channels SectionHeader has no icon. `Hash` appears only in empty state (:390, size 18) and in rows (:410, size 14) |
| `features/fleet_views.dart:989` | `Icons.forum` | "Agent conversations" tile | components/agent/AgentDetailPanel.tsx:222,459,474 | none (raft-ui `ChatIcon` / `DirectMessageIcon`) | — | TODO | Agent DMs SectionHeader has no icon. The empty state uses raft-ui `DirectMessageIcon` |
| `features/fleet_views.dart:994` | `Icons.folder` | "Workspace files" tile | components/agent/AgentDetailPanel.tsx:224 (rendered :3091) | `FolderOpen` (size=12) | folderOpen | REPLACED | Agent panel tab "Workspace" |
| `features/fleet_views.dart:1008` | `Icons.delete_outline` | "Delete agent" / "Delete computer" tile | components/agent/AgentDetailPanel.tsx:3252; components/machine/MachineDetailPanel.tsx:2036 | `Trash2` (size=14) | trash2 | REPLACED | Both branches use a danger Button with `Trash2` |
| `features/fleet_views.dart:1167` | `Icons.refresh` | FleetInspect AppBar Refresh (all kinds) | components/agent/AgentWorkspace.tsx:503; components/machine/MachineDetailPanel.tsx:130 | `RefreshCw` (size=12) | refreshCw | REPLACED | Proven only for workspace-files and computer workspaces (Scan/Rescan, which spins while loading). Activity, channels, DMs and skills have no refresh in Web |
| `features/fleet_views.dart:1199` | `Icons.arrow_upward` | "Root folder" row in the workspace-files list | components/agent/AgentWorkspace.tsx:100-180 | none | — | TODO | Web uses an expandable tree with no up/root row. `ArrowLeft` at :584 is "back from file preview", a different element |
| `features/fleet_views.dart:1217` | `Icons.folder` | Workspace-files directory row | components/agent/AgentWorkspace.tsx:122,124 | `FolderClosed` (collapsed) / `FolderOpen` (expanded) (size=14) | folderClosed | REPLACED | Flutter has no expanded state, so it matches the collapsed `FolderClosed`. Web also has a `ChevronRight` (size 14) before it |
| `features/fleet_views.dart:1218` | `Icons.insert_drive_file` | Workspace-files file row | components/agent/AgentWorkspace.tsx:175 | `FileText` (size=14) | fileText | REPLACED | - |
| `features/attachment_preview_dialog.dart:402` | `Icons.music_note` | Attachment preview dialog, audio placeholder (body for audio, i.e. not document/pdf/video) | components/message/attachmentPreviewSurfaces.tsx:821 (AudioPreviewBody, used by AudioAttachmentPreviewModal:795) | `Music` (size 20 in the modal, 16 inline) | music | REPLACED | Web shows it at 20px inside a 40px tile next to the filename. Flutter shows it at 72px, centered. |
| `features/chat_view.dart:597` | `Icons.check_circle_outline` | Message action sheet, "Select messages" | components/message/MessageItem.tsx:5234 (context menu "Select Message") | `CheckCircle` (size 14) | checkCircle | REPLACED |  |
| `features/chat_view.dart:603` | `Icons.forward` | Message action sheet, "Forward" (ordinary messages only) | components/message/SelectModeToolbar.tsx:184 (select-mode "Forward" button) | `Send` (size 14) | send | REPLACED | Same label and action, but Web has no per-message Forward item. Forward is only in the select-mode toolbar. |
| `features/chat_view.dart:608` | `Icons.forum_outlined` | Message action sheet, "Reply in thread" | components/message/MessageItem.tsx:5244 ("Open Thread"); MessageHoverToolbar.tsx:59 | none (raft-ui `ThreadIcon` 14px, inline SVG) | — | TODO | Not lucide: `ThreadIcon` is drawn by raft-ui (rui index.mjs:19040). |
| `features/chat_view.dart:614` | `Icons.share_outlined` | Message action sheet, "Share link" (native sharing only) | — | — | — | TODO | Web message context menu (MessageItem.tsx:5155-5286) has no share-link item. Native share only exists for images in SelectShareLightbox.tsx:135. |
| `features/chat_view.dart:619` | `Icons.link` | Message action sheet, "Copy link" | components/message/MessageItem.tsx:5156 ("Copy Link") | `Link` (size 14) | link | REPLACED |  |
| `features/chat_view.dart:624` | `Icons.bookmark_border` | Message action sheet, "Save message" | components/message/MessageItem.tsx:5251 | `Bookmark` (size 14); when saved: `BookmarkMinus` (size 14) | bookmark | REPLACED | Web changes the icon and label when already saved. Flutter does not. |
| `features/chat_view.dart:629` | `Icons.add_reaction_outlined` | Message action sheet, "React 👍" (one-tap thumbs-up) | components/message/MessageItem.tsx:5137-5148 (quick-reaction row) | none (`ReactionGlyph` emoji) | — | TODO | Web's quick reactions are emoji buttons. The closest lucide icon is the hover-toolbar "Add reaction" button, MessageHoverToolbar.tsx:72 `SmilePlus` (size 13, strokeWidth 2), but that opens a picker. |
| `features/chat_view.dart:634` | `Icons.check_box_outlined` | Message action sheet, "Create task from message" | components/message/MessageItem.tsx:5279 ("Convert to Task") | `ClipboardCheck` (size 14) | clipboardCheck | REPLACED | Web shows `CheckCircle`/`RotateCcw` instead when a task is already linked (5271). |
| `features/forward_messages_dialog.dart:375` | `Icons.check_circle_outline` | Forward dialog, per-destination result row, success | components/message/forwardToast.ts:29 | none | — | TODO | Web has no per-destination result list. Results are toasts with `hasIcon: false` (ForwardComposerDialog.tsx:440). |
| `features/forward_messages_dialog.dart:376` | `Icons.error_outline` | Forward dialog, per-destination result row, failed or awaiting | components/message/forwardToast.ts:29 | none | — | TODO | Same as above: error toast, no icon (ForwardComposerDialog.tsx:404). |
| `features/resource_search.dart:485` | `Icons.search` | Search results empty state ("Search your workspace" / "No results") | components/search/MessageSearchPage.tsx:2661 (no results); 2178 (empty home) | `Search` (size 48, or 32 in the overlay) | search | REPLACED |  |
| `features/resource_view.dart:779` | `Icons.view_list_outlined` | Tasks toolbar layout toggle, shown while on board ("Show task list") | components/task/TasksPanel.tsx:1166 (segmented "List") | `LayoutList` (size 12) | layoutList | REPLACED | Web uses a two-item segmented control (Board/List). Flutter uses one toggle button. |
| `features/resource_view.dart:780` | `Icons.view_kanban_outlined` | Tasks toolbar layout toggle, shown while on list ("Show task board") | components/task/TasksPanel.tsx:1156 (segmented "Board") | `Columns3` (size 12) | columns3 | REPLACED |  |
| `features/resource_view.dart:790` | `Icons.refresh` | Resource toolbar "Refresh" button (all sections) | — | — | — | TODO | Web resource pages have no manual refresh. `RefreshCw` (size 14) appears only as a retry-on-error button (machine/MobileComputersPanel.tsx:97). |
| `features/resource_view.dart:798` | `Icons.add` | Tasks toolbar "Create task" | components/task/TasksPanel.tsx:1138 ("New Task") | `Plus` (size 12) | plus | REPLACED | Web shows it in channel mode only. |
| `features/resource_view.dart:2018` | `Icons.expand_more` | `filterMenu` dropdown trigger chevron (search/activity filters: channel, sender, date, sort) | components/search/MessageSearchPage.tsx:2249 (also 2318/2376/2433/2484) | `ChevronDown` (aria-hidden, size 12) | chevronDown | REPLACED | Activity's switcher uses `ChevronDown` 14 (thread/ThreadsInbox.tsx:1499). Its sort Select uses raft-ui `SelectIcon`, which is also lucide `ChevronDown` at 14px. |
| `features/resource_view.dart:2681` | `Icons.computer_outlined` | Generic row leading icon, computers section | components/machine/MobileComputersPanel.tsx:149 | `Monitor` (size 20) | monitor | TODO | proven, but the other branches (:2683, :2684) are not; the conditional stays Material. |
| `features/resource_view.dart:2683` | `Icons.bookmark_border` | Generic row leading icon, saved section | components/saved/SavedPanel.tsx:108-137 | none | — | TODO | The Web saved card has no leading icon; it shows a `MessageSquare` 10px only next to the thread label (114). This Flutter branch never runs. |
| `features/resource_view.dart:2684` | `Icons.forum_outlined` | Generic row leading icon, fallback section | — | — | — | TODO | Every section is handled earlier (search, tasks, saved, activity, agents/members, computers), so this never runs and has no Web counterpart. |
| `features/resource_view.dart:2691` | `Icons.bookmark_remove_outlined` | Saved row trailing "Remove saved message" | components/saved/SavedPanel.tsx:146 (pressed toggle); 162 (context "Remove") | `Bookmark` (size 14, fill="currentColor" on the toggle) | bookmark | REPLACED | Web shows a filled Bookmark, not BookmarkMinus. This Flutter branch never runs. |
| `features/resource_view.dart:2709` | `Icons.undo` | Activity row "Restore conversation" (done filter) | components/thread/ThreadsInbox.tsx:563 | `RotateCcw` (size 14) | rotateCcw | REPLACED | Both branches of the Web ternary are on 563. This Flutter branch never runs. |
| `features/resource_view.dart:2709` | `Icons.done` | Activity row "Mark conversation done" | components/thread/ThreadsInbox.tsx:563 (also context menu 1380) | `Check` (size 14) | check | REPLACED | This Flutter branch never runs. |
| `features/resource_view.dart:2726` | `Icons.notifications_outlined` | Activity thread row "Follow thread" (isFollowing == false) | components/thread/ThreadsInbox.tsx:1413 (context menu Follow) | `Bell` (size 14) | bell | REPLACED | Web has it in the context menu only, not as a row button. This Flutter branch never runs. |
| `features/resource_view.dart:2727` | `Icons.notifications_off_outlined` | Activity thread row "Unfollow thread" | components/thread/ThreadsInbox.tsx:1390 (context menu Unfollow) | `BellOff` (size 14) | bellOff | REPLACED | Same as above. |
| `features/auth_view.dart:374` | `Icons.visibility_off` | Password field suffix "Hide password" (visible=true) | components/auth/LoginPage.tsx:96-108 | none | — | TODO | Web uses a plain raft-ui `Input type="password"` with no show/hide toggle. There are no "Show/Hide password" strings in en.ts. |
| `features/auth_view.dart:375` | `Icons.visibility` | Password field suffix "Show password" (visible=false) | components/auth/LoginPage.tsx:96-108 | none | — | TODO | Same as above. No toggle in Login/Register/ResetPassword. |
| `features/auth_view.dart:427` | `Icons.open_in_browser` | "Continue with {provider}" social button | components/auth/SocialProviderButton.tsx:18-22,32 | none (brand SVG: GoogleLogo/GitHubLogo/AppleLogo from icons/ProviderLogos.tsx) | — | TODO | Not lucide. The icon is a per-provider brand logo. |
| `features/channel_conversion_section.dart:492` | `Icons.hub_outlined` | "Convert to joint channel" button | components/channel/JointConversionSection.tsx:125 | `GitBranch` (no size prop, `aria-hidden`) | gitBranch | REPLACED | Label key channel.edit.convertAction. |
| `features/channel_settings.dart:301` | `Icons.close` | Channel settings header close ("Close channel settings") | components/channel/EditChannelDialog.tsx:1553 | `X` (size=20) | x | REPLACED | Key message.channelSettings.close. |
| `features/channel_settings.dart:346` | `Icons.edit_outlined` | "Edit channel" button (opens edit dialog) | components/channel/EditChannelDialog.tsx:1360-1428 | none | — | TODO | Web edits name and description inline with a text "Save Changes" button. There is no Edit entry button. |
| `features/channel_settings.dart:418` | `Icons.person_add_outlined` | "Add members" button in the channel members header | components/agent/ChannelMembers.tsx:1082 | `Plus` (size=16) | plus | REPLACED | Add Member button (key agent.channelMembers.addMember). The overflow member strip tile is a text "+" in AvatarSlot (ChannelOverflowMenu.tsx:242). |
| `features/channel_settings.dart:573` | `Icons.archive_outlined` | Archive / Unarchive channel row (same icon for both states) | components/channel/EditChannelDialog.tsx:1036 (archive), 1028 (unarchive); legacy 971/961 | `Archive` (size=14) / `ArchiveRestore` (size=14) | archive / archiveRestore | REPLACED | Web switches icon by state: isArchived ? ArchiveRestore : Archive. Flutter needs the same conditional. |
| `features/channel_settings.dart:587` | `Icons.logout` | "Leave channel" row | components/channel/EditChannelDialog.tsx:1148 (panel row); legacy 925 | `LogOut` (size=14) | logOut | REPLACED |  |
| `features/channel_settings.dart:599` | `Icons.delete_outline` | "Delete channel" row | components/channel/EditChannelDialog.tsx:1059; legacy 992 | `Trash2` (size=14) | trash2 | REPLACED | For a completed joint channel the same slot shows `Unplug` size=14 with "Disconnect Channel" (1050/982). |
| `features/integrations_views.dart:293` | `Icons.search` | "Search apps" field prefix | components/settings/SettingsPanel.tsx:6342-6351 | none | — | TODO | Web search `Input` has only a placeholder, no icon. |
| `features/integrations_views.dart:306` | `Icons.apps` | Marketplace app card leading icon | components/settings/SettingsPanel.tsx:6403 | none (`ConnectedAppLogo` → raft-ui AvatarSlot type="app", logo/initials) | — | TODO | Not lucide. Web shows the app logo or initials avatar. |
| `features/integrations_views.dart:373` | `Icons.chevron_right` | "My apps" row trailing affordance (tap opens editor) | components/settings/SettingsPanel.tsx:6589-6594 | none for this element (Web has an explicit Edit button: `Pencil` size=14 at 6592) | — | TODO | Web has no chevron. pencil would match only if Flutter switches to an Edit button. |
| `features/integrations_views.dart:456` | `Icons.add` | "Register app" header action | components/settings/SettingsPanel.tsx:6308 | `Plus` (size=14) | plus | REPLACED |  |
| `features/integrations_views.dart:907` | `Icons.delete` | "Delete app" action in app editor | components/settings/SettingsPanel.tsx:7156 | `Trash2` (size=14, as DangerActionCard actionIcon) | trash2 | REPLACED | The confirm dialog also uses `Trash2` size=14 (7183). |
| `features/joint_channel_views.dart:354` | `Icons.add` | "Create joint channel" action | components/layout/Sidebar.tsx:2394 | `Plus` (size=14) | plus | REPLACED | Joint Channels section header "+" button (tooltip layout.sidebar.createJointChannel). The context-menu items for the same action use `GitBranch` size=14 (Sidebar.tsx:4729, 4862). |
| `features/joint_channel_views.dart:505` | `Icons.link_off` | "Disconnect workspace" from joint channel | components/channel/EditChannelDialog.tsx:1050; legacy 982 | `Unplug` (size=14) | unplug | REPLACED | "Disconnect Channel" calls disconnectJointChannel (EditChannelDialog.tsx:902). |
| `features/joint_channel_views.dart:511` | `Icons.add` | "Invite workspace" action (form posts joint-invites) | components/channel/EditChannelDialog.tsx:1300 | `Mail` (size=14) | mail | REPLACED | Web has no separate entry button. The invite form is inline and `Mail` sits on its "Send Invite" submit. |
| `features/management_support.dart:309` | `Icons.refresh` | Generic page-header "Refresh" for every ManagementState page | — | none | — | TODO | Shared helper with no single Web element. Web settings SectionHeaders have no generic refresh. Some sections have their own RefreshCw (e.g. ProviderConnectionsSettings.tsx:425, MemberGraphSection.tsx:722). |
| `features/management_support.dart:363` | `Icons.chevron_right` | Default icon for any `action()` button without an explicit icon | — | none | — | TODO | Fallback icon with no Web counterpart. The matching Web buttons are text-only (e.g. Install, Resend). |
| `features/mcp_views.dart:393` | `Icons.handyman_outlined` | MCP tool catalog row leading icon | components/agent/AgentMcpTab.tsx:504-519 | none (only a trailing `Info` size=13 tooltip at 519) | — | TODO | Web tool rows have no leading icon. |
| `features/mcp_views.dart:497` | `Icons.add` | "Add connection" (MCP server) header action | components/agent/AgentMcpTab.tsx:352 | `Plus` (size=13) | plus | REPLACED | Web label is "Add server" (agent.mcp.addServer). The empty state has the same icon at 552. |
| `features/provider_views.dart:219` | `Icons.link_off` | "Detach deleted agent" on a provider connection | components/settings/ProviderConnectionsSettings.tsx:473 | `Link2Off` (size=15) | link2Off | REPLACED |  |
| `features/provider_views.dart:406` | `Icons.verified_outlined` | Verification history receipt, outcome=success | components/settings/ProviderConnectionsSettings.tsx:965-973 | none | — | TODO | Web has no probe-history list (no GET /probes). It shows only a text result for a single probe. |
| `features/provider_views.dart:407` | `Icons.error_outline` | Verification history receipt, outcome≠success | components/settings/ProviderConnectionsSettings.tsx:965-973 | none | — | TODO | Same as above. |
| `features/provider_views.dart:510` | `Icons.add` | "Add provider" header action | components/settings/ProviderConnectionsSettings.tsx:116 | `Plus` (size=16) | plus | REPLACED | Web label key settings.providers.add ("Add connection"). |
| `features/server_setup_gate.dart:427` | `Icons.copy` | "Copy command" button on install/setup command rows | components/machine/ComputerCommandGuide.tsx:87 → raft-ui index.mjs:2573 | `Copy` (className size-3, strokeWidth=1.75); `Check` when copied (2578) | copy | REPLACED | Rendered by raft-ui CopyableCodeAction, a lucide icon inside raft-ui. Used by onboarding/ServerSetupComputerRuntimeStep.tsx:342. |
| `features/server_views.dart:390` | `Icons.edit_outlined` | "Edit workspace" button | components/settings/SettingsPanel.tsx:2041-2051 | none | — | TODO | Web ProfileSection edits inline with a text "Save Profile" button (a `Check` icon appears only in the saved state). |
| `features/server_views.dart:458` | `Icons.close` | "Revoke invitation" icon button on an email invite row | components/settings/SettingsPanel.tsx:2972 | `X` (size=12) | x | REPLACED |  |
| `features/server_views.dart:489` | `Icons.link_off` | "Revoke invitation link" icon button | components/settings/SettingsPanel.tsx:3161 | `X` (size=14) | x | REPLACED | Web uses X, not a link-off glyph. |
| `features/server_views.dart:510` | `Icons.logout` | "Leave workspace" button | components/settings/SettingsPanel.tsx:4920-4927 | none | — | TODO | Web DangerZone "Leave Server" is a text-only warning Button. |
| `features/server_views.dart:675` | `Icons.refresh` | "Refresh members" in the workspace Members view | components/layout/Sidebar.tsx:9 (import list) | none | — | TODO | Web lists members in the sidebar with no refresh control (Sidebar does not import RefreshCw). Only the Member Graph page has `RefreshCw` size=14 (MemberGraphSection.tsx:722). |

### TODO groups

- **Web has no icon on that element** (text-only button, no prefix, no chevron). Decide whether Flutter drops the icon:
  - `agent_apps_view:305`, `fleet_views:290/350/852/947`, `integrations_views:293/373`, `management_support:309/363`
  - `server_views:390/510/675`, `channel_settings:346`, `mcp_views:393`, `workspace_view:2083`, `resource_view:790`
- **Feature or element does not exist in Web:**
  - `auth_view:374/375` (password reveal), `workspace_view:874/1749/1840`
  - `sidebar_preferences_view` (the whole page), `chat_view:614` (share link)
  - `forward_messages_dialog:375/376`, `provider_views:406/407`
  - `fleet_views:934/1199`, `agent_migration_view:178`
- **Web draws a non-lucide icon:**
  - raft-ui `ThreadIcon`/`ChatIcon`/`DirectMessageIcon`: `chat_view:608`, `fleet_views:984/989`
  - agent avatars: `workspace_view:1547`, `sidebar_preferences_view:434`
  - provider brand logos: `auth_view:427`
  - app logos: `integrations_views:306`
  - emoji reaction: `chat_view:629`
  These need dedicated glyphs, not Lucide.
- **Conditionals with one unproven branch:** `sidebar_preferences_view:344/345`, `resource_view:2681/2683/2684`.
