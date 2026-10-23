# Navigation audit

Scope: every navigation entry point in `apps/raft_flutter/lib` and the raft_ui
callbacks they feed, on the phone layout (mobile host, 390x844) and the wide
layout (desktop host, 1280x800), compared with Web `v1.21.2-source.1`
(`packages/web/src`, read only).

Bug class (fixed for Joint channels "+" in c88601bc): an entry point whose
target does not exist in one layout and silently falls back (here the default
Account page), or whose behaviour differs from Web (page instead of dialog,
wrong destination).

## Guard

* `lib/data/navigation_registry.dart` is the single list of targets named by
  literal: `sections` (what `select`, `setSection`, `selectSection`,
  `selectRoute` accept and the route / settings tab each must land on),
  `unsupportedSections` (`joint-channels`, `sidebar-settings`, with the reason)
  and `settingsTabs` (every Settings destination, with the layouts that lack it
  and why).
* Unknown targets fail loudly in debug and test through
  `NavigationRegistry.reportFallback` (a `FlutterError` naming the target) and
  keep the old safe fallback in release (Web falls back to Account too):
  `WorkspaceNavigation.locationForSection`, `WorkspaceController.setSection`,
  `_WorkspaceViewState.select`, `RaftSettingsPage` (settings tab nobody
  registered; a registered tab hidden by role, flag or layout still resolves to
  the first page like Web's denied tab) and `DesktopNavigationPolicy.forSection`.
* `test/navigation_registry_test.dart`:
  * lint: every `select('x')`, `setSection('x')`, `selectSection('x')`,
    `selectRoute('x')`, `canVisitSection('x')`, `section = 'x'`,
    `openHelpSettings('x')` and `settingsPath: ['x']` literal in `lib/` must be
    registered (a new unregistered literal fails the test);
  * registry consistency with `WorkspaceNavigation.settingsSections`,
    `settingsTab` aliases, bottom-bar ids and rail ids;
  * for phone and wide: every registered section lands on its intended route
    and page (settings sub-pages find their own tab page, never Account); every
    Settings row is registered, offered on exactly the layouts the registry
    declares, and opens its own page (or the Computers route for the action row);
  * phone Home sidebar: both "+" buttons open `CreateChannelDialog` /
    `CreateJointChannelDialog` in place; every item of the Channels, Joint and
    Direct messages section menus, the list-surface menu, and the channel,
    human DM and agent DM row menus is walked: dialogs open where Web opens
    them, no item changes the location; Search / Activity / Saved rows;
  * a feedback notice and Create Agent "Upgrade for more" land on Settings
    pages (below).
* `test/statusbar_audit_test.dart` was itself sampling four silent fallbacks
  (`/settings/language`, `/settings/joint-channels`, `/settings/workspace-settings`,
  `/settings/sidebar-settings` all rendered Account, `/member-graph` rendered
  Home). Its paths now name real pages.

## Table

Phone = mobile host (`wide == false`), Wide = desktop host. "Page" is what is
actually shown. Status: OK, FIXED (this change), DIFF (intended or recorded
difference), GAP (Web has it, Flutter does not; not a fallback).

| Entry point (file:line) | Target | Phone | Wide | Web | Status | Fix |
|---|---|---|---|---|---|---|
| Home sidebar Channels "+" (`workspace_view.dart` sidebarGroupActions) | `createChannel` | CreateChannelDialog | same | openCreateChannelDialog | OK | tested |
| Home sidebar Joint "+" | `createJointChannel` | CreateJointChannelDialog | same | openCreateJointChannelDialog | OK (c88601bc) | tested |
| Section menu Create Channel / Create Joint Channel (`..._sidebar_menus.dart` openSectionMenu) | same dialogs | dialog | dialog | dialog | OK (c88601bc) | tested |
| Surface menu Create Channel / Create Joint Channel / New section (openSurfaceMenu) | dialogs | dialog | dialog | dialog | OK | tested |
| Section menu sort / display / New section / Rename / Delete | in-place | no navigation | same | same | OK | tested |
| Row menus (channel, human DM, agent DM): Move, Mark read, Pin, Mute, Archive, Close Chat | in-place | no navigation (Close Chat on the open DM: Home) | closes detail | closeDm | OK | tested |
| Sidebar Search row (`workspace_view.dart:3357`) | `select('search')` | Search page | rail Search opens overlay | toSearch | OK | tested |
| Sidebar Activity row (:3379) | `select('activity')` | Activity page (hidden when Activity is a bottom tab) | rail | Activity | OK | tested |
| Sidebar Saved row (:3386) | `select('saved')` | Saved page | Saved page | toSaved | OK | tested |
| Rail buttons (:2433) | search, chat, activity, tasks, members, computers | n/a (bottom bar) | pages | LeftRail | OK | registry |
| Rail Settings (:2506), Cmd/Ctrl+, (:2112), phone fallback page header (:2909) | `select('settings')` | Settings root list | Account | toSettings | OK | tested |
| Bottom bar tabs (`selectMobileTab` :319) | home, tasks, members, computers, activity, settings | tab roots | n/a | MobileTabBar | OK | registry |
| Search this channel (:293), Cmd/Ctrl+K (:2122, :2134), quick switcher "search all" (:381), page header (:2904) | `select('search')` | Search page | overlay / page | SearchOverlay | OK | tested |
| Notification bell Upgrade, chat banners, thread banners, home header (`onViewBilling` / `onBilling`, :1153, :1683, :2337, :2344, :2443, :2528, :3307) | `select('billing')` | Settings > Plan & Billing | same | toSettings("billing") | OK (needs viewBilling; Web shows Account without it) | tested |
| Invite human sent (:2739) | `select('administration')` | Settings > Administration | same | toSettings("administration") | OK | tested |
| Invite dialog "view billing" (`workspace_menu_invite.dart:253`) | settingsPath `billing` | Settings > Billing | same | toSettings("billing") | OK | lint |
| Create Joint dialog billing link (`create_joint_channel_dialog.dart:90`) | `setSection('billing')` | Settings > Billing | same | toSettings("billing") | OK | lint |
| Create Agent "Upgrade for more" (`create_agent_dialog.dart`) | closed the dialog only | stayed on page | same | onClose + toSettings("billing") | FIXED | now `setSection('billing')`; tested |
| Create Channel / Add computer limit banners and "View plans" | none | missing | missing | toSettings("billing") | GAP (feature, not a fallback) | not done |
| System notice "View feedback" (`system_notification_center.dart`) | pushed a standalone Feedback page | off-route page | off-route page | toSettings("feedback") | FIXED | `onFeedback` -> `openHelpSettings('feedback')`; tested |
| System notice computer / computers (attention) | pushed FleetDetail / FleetView | off-route page | off-route page | toComputer / toComputers(filter=attention) | DIFF | recorded; the wide Computers page has no attention filter |
| Help menu Mobile App / Feedback (`openHelpSettings`, :2470, :2476) | settings `about`, `feedback` | n/a (rail only) | Settings tab | toSettings | OK | lint |
| Help menu Documentation / Join Community | external / server | n/a | external / `setSection('home')` | same | OK | registry |
| Server menu Switch or Create Server, Invite human | callbacks / dialog | same | same | same | OK | n/a |
| Settings rows (`workspace_settings.dart`) | account, language-region, appearance, bottom-bar, notifications, server, billing, administration, im-bridges, integrations, labs, mcp, providers, about, network (native-only), feedback, release-notes | tab page via `onMobileLocationChanged` (:3662) | in-panel tab | SettingsNavList | OK | tested row by row |
| Settings row Computers (`workspace_settings.dart:275`) | `selectSection('computers')` | Computers route | row hidden (Computers rail) | navigate(/computers) | OK | declared `wide: false` |
| Settings row Documentation | external URL | opens browser | opens browser | link | OK | declared `page: false` |
| Settings row Bottom bar | `bottom-bar` | page | hidden | none | DIFF (phone-only device preference) | declared `wide: false` |
| Settings tab not in the page | any other id | Account | Account | normalizeSettingsTab -> account | FIXED (loud in debug) | `reportFallback('settings tab')` |
| `select('joint-channels')` (removed by c88601bc) | settings joint-channels | Account | Account | no page | FIXED | `unsupportedSections`; the unreachable `JointChannelsView` page was removed (accept lives in the notification center, manage in the channel settings drawer) |
| `select('sidebar-settings')` | settings sidebar-settings | Account | Account | no page | FIXED | `unsupportedSections`; no caller left |
| Dead route branches in `workspace_view.dart` (workspace-settings, sidebar-settings, providers, administration, billing, joint-channels, im-bridges, integrations) | n/a | unreachable: `route` is forced to `settings` for every settings location | same | n/a | FIXED | removed with their titles and unused imports |
| Deep link `/settings/<slug>`, `server-labs` alias (`WorkspaceNavigation.settingsTab`) | slug | tab or Account | same | settingsTabIdForRouteSlug | FIXED (`server-labs` -> labs; unknown slug loud in debug) | |
| Deep link unknown route (`RaftRoute.unknown`) | Home | Home | Home | catch-all redirect | DIFF (external input, kept silent) | |
| Message link `app://` (`message_presentation.dart:396`) | `setSection('integrations')` | Settings > Applications | same | Applications | OK | lint |
| Share target (`main.dart:455`) | `setSection('chat')` | conversation | same | n/a | OK | lint |
| Open conversation / thread / message (content links, notification taps; `content_coordinator.dart`, `desktop_navigation_policy.dart`) | channel / dm / thread query | page | detail pane | toChannel | OK | existing tests |
| Channel header settings (`channelSettings` :3495) | `openChannelPage(settings)` | full-width page | dialog | EditChannelDialog | DIFF (recorded: Web phone drawer) | |
| Channel members (`ChannelMembers.show`) | `openChannelPage(members)` | full-width page | modal | drawer | DIFF (recorded) | |
| Members / Computers list rows (`openDirectoryLocation`) | agent / computer / human route | detail page | detail pane | toAgent... | OK | |
| Fleet "Add computer", "Create agent", "Invite human" | dialogs | dialog | dialog | dialog | OK | |
| Fleet detail fallback pushes (`fleet_views.dart` when no `onOpenDetail`) | MaterialPageRoute | only from system notices | same | n/a | DIFF (see system notice) | |

Entry points audited: 41 rows covering about 70 call sites. Issues found: 7
(Create Agent upgrade, feedback notice, settings-tab fallback, the two
unsupported sections, the dead route branches, the `server-labs` alias) plus 4
silent fallbacks in `statusbar_audit_test`. Fixed: all of them. Declared
unsupported: `joint-channels`, `sidebar-settings` (both layouts), `bottom-bar`
(wide), `computers` row (wide), and the `documentation` row has no page. Left
as recorded differences or gaps: system notice computer pages, channel
settings / members phone pages, Create Channel and Add computer limit banners,
unknown external routes.

## Why this audit missed the Activity reply-card no-op

Kevin's report (2026-10-12): in the Activity preview, clicking the "1 reply"
card under a message did nothing. Both audits above passed, because they check
a different thing:

* This audit walks *entry points that name a target* (`select('x')`,
  `setSection`, settings rows) and proves the target exists and lands on the
  right route / page in a phone and a wide `WorkspaceView`. The reply card does
  not name a target. It calls `openThread`, which writes the `?thread=` slot of
  the current location; the destination ("thread") was registered and correct.
* The registry cannot see a *container*. Whether `?thread=` or `?profile=` is
  rendered depends on which route the timeline sits in, and only the Chat route
  had a thread / profile column. The Activity / Search master-detail preview,
  added later (single tap = preview, docs/parity.md "Activity master-detail
  threshold"), mounts the same message timeline without that column. The
  handler ran, the location changed, nothing on screen did.
* Existing Activity tests asserted the location and the preview body, never that
  a tap *inside* the preview produced something visible.

The class is therefore "tap writes a target the container does not render", not
"unknown target". `docs/tap-targets.md` holds the second guard: a registry of
every message container, a matrix test that taps each element in each container
and fails on a silent no-op, and a static check that new containers state their
handlers. The two audits are complementary: this one checks that targets exist,
the matrix checks that every container shows them.

## Stale device flows

`integration_test/sidebar_flow.dart` calls `section('sidebar-settings')` and waits
for `SidebarPreferencesView`. That page is not reachable from any route (it was
already rendering Account before this change), so the flow can not pass on a
device. It needs a rewrite that opens sidebar preferences from the sidebar menus;
that needs a device run and is not part of this change. The joint-channel flow
(`joint_channel_flow.dart`, same problem) was removed with the page it drove.
