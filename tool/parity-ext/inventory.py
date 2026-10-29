#!/usr/bin/env python3
"""Web PAGE INVENTORY vs Flutter parity coverage (generated on demand, never committed).

The inventory is data (SECTIONS below, one row per user-facing Web page / panel /
modal / drawer / sheet / popover / empty-or-error state worth a screen): Web page
metadata, the case ids EXPECTED per platform (`d=` / `p=` extension globs, `off=`
official globs) and the marks (`excl=`, `verify=`, `*_state='partial'`). The
coverage STATUS is never written by hand: it is computed from the case ids that
exist in the built manifests (the official sharedCases.json and the extension
manifest the builders generate) and from the Flutter `noFlutterSurface` flags.
A branch that adds cases for an already listed page therefore edits nothing here;
only a new Web page needs a new row (or a missing page gets its expected ids).

  python3 tool/parity-ext/inventory.py --write build/parity-ext/page-inventory.md   # generate the document
  python3 tool/parity-ext/inventory.py --stdout                                     # print it
  python3 tool/parity-ext/inventory.py --check    # validate the rows and id globs (not a document)

Status per applicable platform (D = desktop 1280, P = phone 390):
  ok        every expected id glob of the row matches a case (official id, or extension id on the default theme brutal-light)
  partial   only some of the row's globs match a case, or the row carries a `partial` mark (known fewer states than the page has)
  web-only  cases exist but every one is flagged `noFlutterSurface` (the Web page renders, the Flutter app has no surface)
  MISSING   the row lists no id glob for the platform, or none matches a case
  n/a       the surface does not exist on that platform
  excluded  the page is dead, obsolete or not shown to normal users (`excl=(reason, evidence)`): it drops out of the
            missing counts and the ranking. Reasons: obsolete | flag-off | host-only | browser-only | dev-only | duplicate | superseded.
            Reachability evidence is from the pinned Web source only (no git history exists there: one release commit).
  verify    (`verify=` text, not a state) reachability is unclear or the page may not apply to a native client; the page
            stays in the counts and is listed in the "Verify" section.

The `noFlutterSurface` flags come from the Flutter case map written by a parity-ext run
(build/parity-ext/visual-testing-results/android-case-map.json, or --case-map FILE); without it no case is
treated as web-only. Official ids are matched against packages/visual-testing/shared/sharedCases.json when the
raft-source checkout is present, otherwise they count as existing.
Extension ids are written without the theme suffix and may be globs.
"""
import argparse
import fnmatch
import json
import os
import pathlib
import re
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEFAULT_DOC = ROOT / 'build/parity-ext/page-inventory.md'
CASE_MAP = ROOT / 'build/parity-ext/visual-testing-results/android-case-map.json'
RAFT_SOURCE = pathlib.Path(os.environ.get(
    'PARITY_RAFT_SOURCE', '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source'))
W = 'packages/web/src/'

OFFICIAL_UI = ('components.tokens.palette', 'components.ui.*')


class Row:
    def __init__(self, num, name, web, ap, off=(), d=(), p=(), prio=2, note='', d_state=None, p_state=None,
                 excl=None, verify=None):
        self.num, self.name, self.web, self.ap = num, name, web, ap
        self.excl, self.verify = excl, verify  # excl = (reason, evidence)
        self.off, self.d, self.p = tuple(off), tuple(d), tuple(p)
        self.prio, self.note = prio, note
        self.d_state, self.p_state = d_state, p_state  # mark: 'partial' (known fewer states than the page has); statuses are computed

    def groups(self, platform):
        """Expected id globs of the row on 'D' or 'P' -> [(kind, glob, negations)]; kind 'ext' | 'official'."""
        if platform == 'D':
            ext, off = self.d, ()
        else:
            ext, off = self.p, self.off
        negations = [g[1:] for g in ext if g.startswith('!')]
        return [('official', g, []) for g in off] + [('ext', g, negations) for g in ext if not g.startswith('!')]

    def state(self, platform, ctx=None):
        """-> ok | partial | web-only | MISSING | n/a | excluded for 'D' or 'P' (computed, see Context.state)."""
        return (ctx or default_context()).state(self, platform)


def R(*args, **kwargs):
    return Row(*args, **kwargs)


# (section title, intro, rows)
SECTIONS = [
    ('1. Auth, onboarding and public entry', 'App.tsx AppShell / ServerResolver, components/auth, components/onboarding, pages/*', [
        R('1.01', 'Auth bootstrap status (loading / restoring session)', 'App.tsx AuthBootstrapStatus', 'DP', d=['components.auth-pages.desktop.bootstrap.*'], p=['components.auth-pages.mobile.bootstrap.*'], prio=3,
          note='Flutter showed a spinner (no text); now the same cream splash.'),
        R('1.02', 'Login (default)', 'components/auth/LoginPage.tsx', 'DP',
          off=['screens.auth.login'], d=['components.auth-ext.desktop.login.default'], p=['components.auth-ext.mobile.login.default']),
        R('1.03', 'Login states (invalid email, missing password, credentials error, filled, signing in)', 'components/auth/LoginPage.tsx', 'DP',
          off=['screens.auth.login.signing'], d=['components.auth-ext.desktop.login.*'], p=['components.auth-ext.mobile.login.*']),
        R('1.04', 'Social sign-in buttons (Google / GitHub / Apple, hover)', 'components/auth/SocialProviderButton.tsx', 'DP',
          d=['components.auth-ext.desktop.social.*', 'components.auth-ext.desktop.login.social'],
          p=['components.auth-ext.mobile.social.*', 'components.auth-ext.mobile.login.social']),
        R('1.05', 'Register', 'components/auth/RegisterPage.tsx', 'DP', off=['components.auth.register.inputs'],
          d=['components.auth-pages.desktop.register.default'], p=['components.auth-pages.mobile.register.default'], prio=2),
        R('1.06', 'Register states (validation errors, legal consent unchecked, submit error)', 'components/auth/RegisterPage.tsx, LegalAcceptanceCheckbox.tsx', 'DP',
          d=['components.auth-pages.desktop.register.*', '!*.register.default'], p=['components.auth-pages.mobile.register.*', '!*.register.default'], prio=2),
        R('1.07', 'Forgot password (default, filled, sent, error)', 'components/auth/ForgotPasswordPage.tsx', 'DP',
          off=['screens.auth.forgot-password'], d=['components.auth-ext.desktop.forgot.*'], p=['components.auth-ext.mobile.forgot.*']),
        R('1.08', 'Reset password (default, filled, too short, mismatch, error, done)', 'components/auth/ResetPasswordPage.tsx', 'DP',
          d=['components.auth-ext.desktop.reset.*'], p=['components.auth-ext.mobile.reset.*']),
        R('1.09', 'Email verification (link wait, manual code, resent, errors)', 'components/auth/EmailVerificationPage.tsx', 'DP',
          d=['components.auth-ext.desktop.verify.*'], p=['components.auth-ext.mobile.verify.*']),
        R('1.10', 'Account identity (profile) setup', 'components/auth/AccountIdentitySetupPage.tsx', 'DP',
          off=['screens.auth.profile-setup'], d=['components.auth-pages.desktop.identity.*'], p=['components.auth-pages.mobile.identity.*'], prio=2),
        R('1.11', 'Social auth callback (loading / error)', 'components/auth/SocialAuthCallbackPage.tsx', 'DP', prio=3),
        R('1.12', 'Invite accept (email invite link; signed-out and signed-in variants, expired / invalid)', 'components/auth/InviteAcceptPage.tsx', 'DP',
          d=['components.auth-pages.desktop.invite.*'], p=['components.auth-pages.mobile.invite.*'], prio=2,
          note='First screen every invited user sees. Flutter: InviteAcceptView / RaftInviteAcceptPage, opened by /join/<token>, ?invite=, raft://v1/join/<token> and the Join workspace dialog; Sign In / Create Account keep the token until the account is ready.'),
        R('1.13', 'Choose server', 'components/auth/ServerSelector.tsx', 'DP',
          off=['screens.auth.choose-server', 'screens.home.choose-server'],
          d=['components.auth-ext.desktop.server.choose'], p=['components.auth-ext.mobile.server.choose']),
        R('1.14', 'Create first server (no server yet)', 'components/auth/ServerSelector.tsx, OnboardingCreateShell.tsx, ServerCreatePreview.tsx', 'DP',
          d=['components.auth-pages.desktop.server.create-first*'], p=['components.auth-ext.mobile.server.create-first*'], prio=2),
        R('1.15', 'Create another server', 'components/auth/ServerSelector.tsx', 'DP',
          d=['components.auth-ext.desktop.server.create-more*'], p=['components.auth-ext.mobile.server.create-more*']),
        R('1.16', 'Server access denied / server not found', 'App.tsx ServerAccessDeniedPage', 'DP', d=['components.auth-pages.desktop.server-denied.*'], p=['components.auth-pages.mobile.server-denied.*'], prio=2,
          note='Flutter: RaftServerAccessDeniedPage; an unknown /s/<slug> keeps its URL, names the fallback server and redirects after 3 s.'),
        R('1.17', 'Servers loading and joining-community splash', 'App.tsx ServerResolver, ServerSelectionPage', 'DP', d=['components.auth-pages.desktop.servers.*'], p=['components.auth-pages.mobile.servers.*'], prio=3,
          note='Flutter: /s/community for a non-member joins on arrival behind the "Joining community…" splash (community_join.dart); community-cn has no Flutter page.'),
        R('1.18', 'Community agreement dialog (join a community server)', 'components/server/CommunityAgreementDialog.tsx', 'DP', d=['components.auth-pages.desktop.community-agreement.*'], p=['components.auth-pages.mobile.community-agreement.*'], prio=2,
          note='Flutter: one RaftCommunityAgreementDialog (agreement from the 409 receipt) for the public-server guest join, over the not-found page for /s/community, and from the Help menu Join Community.'),
        R('1.19', 'Public server preview (signed-out channel list + read-only messages, join / sign-in banner, unavailable)', 'pages/PublicServerPage.tsx', 'DP',
          d=['components.public-server.desktop.page.*', '!*.join-*'], p=['components.public-server.mobile.page.*', '!*.join-*'], prio=2,
          note='Flutter: PublicServerView (signed-out /s/<slug> route in main.dart). The server-switcher notice and the join error banner are Web layout bugs (shrink-wrapped 28px column), so they have no case.'),
        R('1.20', 'Public server: join confirm dialog and guest join', 'pages/PublicServerPage.tsx', 'DP',
          d=['components.public-server.desktop.page.join-*'], p=['components.public-server.mobile.page.join-*'], prio=3),
        R('1.21', 'Server setup survey (default, answered, other, save failed)', 'components/onboarding/ServerSetupSurveyStep.tsx', 'DP',
          d=['components.auth-ext.desktop.setup.survey*'], p=['components.auth-ext.mobile.setup.survey*']),
        R('1.22', 'Server setup: connect a computer (not connected, connecting, ready, not ready, offline recovery)', 'components/onboarding/ServerSetupComputerRuntimeStep.tsx', 'DP',
          d=['components.auth-ext.desktop.setup.computer-*'], p=['components.auth-ext.mobile.setup.computer-*']),
        R('1.23', 'Server setup: handoff step (default, starting)', 'components/onboarding/ServerSetupHandoffStep.tsx', 'DP',
          d=['components.auth-ext.desktop.setup.handoff*'], p=['components.auth-ext.mobile.setup.handoff*']),
        R('1.24', 'Server setup projection gate (loading, error, dedicated native surface, footer)', 'components/onboarding/ServerSetupProjectionGate.tsx, SetupSessionFooter.tsx', 'DP',
          d=['components.auth-pages.desktop.setup-gate.*'], p=['components.auth-pages.mobile.setup-gate.*'], prio=3,
          note='Flutter: deferred-setup resume bar (RaftSetupResumeBar in ServerSetupGate). The dedicated-surface cases (loading / unavailable / load failed / complete) stay without a Flutter widget: that page exists for native WebView hosts, the app renders setup natively.'),
        R('1.25', 'Device login (/login/device): enter code, approve, approved, invalid / expired / used code', 'pages/DeviceLoginPage.tsx', 'DP', prio=2,
          note='The CLI / computer sign-in confirmation.'),
        R('1.26', 'App login handoff (/login/app)', 'pages/AppLoginPage.tsx', 'DP', prio=3),
        R('1.27', 'Login with Raft setup (/login-with-raft/setup, scope consent)', 'pages/HumanLoginSetupPage.tsx, oauth/RequestedScopeConsent.tsx', 'DP', prio=3),
        R('1.28', 'Integration invite (/integration-invite): install app, not found, needs admin', 'pages/IntegrationInvitePage.tsx', 'DP', prio=3),
        R('1.29', 'Agent connection callback (connected / denied / expired / foreign account)', 'pages/AgentConnectionCallbackPage.tsx', 'DP', prio=3),
        R('1.30', 'Mobile download chooser (/download)', 'pages/MobileDownloadChooserPage.tsx', 'DP', prio=3),
        R('1.31', 'Chinese community page', 'pages/ChineseCommunityPage.tsx', 'DP', prio=3),
        R('1.32', 'PWA install prompt (iOS Safari add-to-home steps)', 'components/pwa/PwaInstallPrompt.tsx', 'P', prio=3),
        R('1.33', 'Root error fallback (app crashed, reload)', 'components/errors/RootErrorFallback.tsx', 'DP', d=['components.auth-pages.desktop.root-error.*'], p=['components.auth-pages.mobile.root-error.*'], prio=2,
          note='Flutter: RaftRootErrorFallback under RootErrorBoundary (release builds; debug keeps the framework error screen).'),
        R('1.34', 'App update gate (stale build, refresh to continue)', 'components/errors/AppUpdateGate.tsx', 'DP', prio=3),
    ]),
    ('2. Shell and navigation', 'components/layout (MainLayout, LeftRail, Sidebar, NotificationCenter, MobileBottomBarStack), components/ui', [
        R('2.01', 'Desktop rail + sidebar, chat mode (default, empty, loading, custom sections, sorted, collapsed, row hover)', 'components/layout/LeftRail.tsx, Sidebar.tsx', 'D',
          d=['components.shell.desktop.sidebar.*']),
        R('2.02', 'Phone Home: sidebar as the home list (default, collapsed, loading)', 'components/layout/Sidebar.tsx (mobileInline)', 'P',
          off=['screens.home.index', 'screens.home.loading'], p=['components.shell.mobile.sidebar.default', 'components.shell.mobile.sidebar.collapsed'],
          note='Activity count (server activityUnreadCount), @ mention marker, collapsed-section unread dot and other-server header dot match Web.'),
        R('2.03', 'Phone bottom tab bar', 'components/layout/MobileBottomBarStack.tsx', 'P', off=['components.navigation.tabbar.states']),
        R('2.04', 'Phone titlebar (server unread, notification trigger)', 'components/layout/Sidebar.tsx, NotificationTrigger.tsx', 'P', off=['components.home.titlebar.states']),
        R('2.05', 'Notification center (popover on desktop, sheet on phone)', 'components/layout/NotificationCenter.tsx', 'DP',
          off=['components.home.notification-center.states'], d=['components.list-pages.notification.desktop-center'], prio=2),
        R('2.06', 'Server switcher menu', 'components/ui/ServerSwitcherMenu.tsx', 'DP',
          off=['components.home.server-switcher.open'], d=['components.shell.desktop.server.menu']),
        R('2.07', 'Rail help menu (docs, mobile app, community)', 'components/layout/LeftRail.tsx', 'D', d=['components.shell.desktop.rail.help-menu']),
        R('2.08', 'Row context menus (channel, muted channel, DM, agent DM, section, custom section, surface, Move to section)', 'components/layout/Sidebar.tsx', 'DP',
          d=['components.shell.desktop.menu.*', 'components.row-menus.desktop.menu.*'],
          p=['components.shell.mobile.menu.*', 'components.row-menus.mobile.menu.*']),
        R('2.09', 'Section sort menu', 'components/layout/Sidebar.tsx', 'DP', d=['components.shell.desktop.sidebar.sort-menu'], p=['components.shell.mobile.sidebar.sort-menu']),
        R('2.10', 'Section dialogs (new, rename, delete)', 'components/layout/SidebarSectionDialog.tsx', 'DP',
          d=['components.shell.desktop.dialog.*-section'], p=['components.list-pages.dialogs.phone-*-section'], prio=3),
        R('2.11', 'Section emoji picker', 'components/layout/SidebarSectionEmojiPicker.tsx', 'DP',
          d=['components.list-pages.dialogs.desktop-emoji-picker'], p=['components.list-pages.dialogs.phone-emoji-picker'], prio=3,
          note='The section dialog emoji button opens RaftEmojiPicker (emoji-picker-react data via tool/gen-emoji-data); recently used emoji are kept for the session only.'),
        R('2.12', 'Archive channel confirm (from the sidebar menu)', 'components/layout/Sidebar.tsx', 'DP', d=['components.shell.desktop.dialog.archive-channel'],
          p=['components.list-pages.dialogs.phone-archive-channel'], prio=3),
        R('2.13', 'Conversation finder ("Find a conversation..." box and results)', 'components/layout/SidebarConversationFinder.tsx', 'DP', prio=2),
        R('2.14', 'Live agent activity bar (tool finished, working, thinking, compacting, long)', 'components/layout/LiveAgentActivityBar.tsx', 'DP',
          excl=('superseded', 'Raft Design System decision 0006 deprecates the live bar; Flutter shows working agents in place (summary, Working now, rows, channel subtitle).')),
        R('2.15', 'Activity page frame (rail + inbox column edge)', 'components/layout/MainLayout.tsx', 'DP',
          d=['components.shell.desktop.activity.frame'], p=['components.shell.mobile.activity.frame']),
        R('2.16', 'Confirm dialogs (danger, warning, acknowledge)', 'components/ConfirmDialog.tsx', 'DP',
          d=['components.shell.desktop.confirm.*'], p=['components.shell.mobile.confirm.*']),
        R('2.17', 'Banner, empty state, bottom sheet, overflow sheet', 'components/ui/Banner.tsx, EmptyState.tsx, BottomSheet.tsx, OverflowSheet.tsx', 'DP',
          d=['components.shell.desktop.banner.*', 'components.shell.desktop.empty.*', 'components.shell.desktop.bottomsheet.*', 'components.shell.desktop.overflow.*'],
          p=['components.shell.mobile.banner.*', 'components.shell.mobile.empty.*', 'components.shell.mobile.bottomsheet.*', 'components.shell.mobile.overflow.*']),
        R('2.18', 'Toasts (success, error, info, plain)', 'components/LocalizedToastProvider.tsx', 'DP',
          d=['components.shell.desktop.toast.*'], p=['components.shell.mobile.toast.*']),
        R('2.19', 'Announcement modal (single, multi-page, rich, long, overlay)', 'components/AnnouncementModal.tsx', 'DP',
          d=['components.announcements.desktop.*'], p=['components.announcements.mobile.*']),
        R('2.20', 'UI library primitives (button, card, badge, form field, checkbox, select, menu item, ...; shared by both platforms)', 'packages/ui (raft-ui)', 'P',
          off=OFFICIAL_UI, note='Rendered by the same Flutter raft_ui widgets on desktop; the shell primitive cases above cover the desktop sizes.'),
        R('2.21', 'Workspace grid mode (Labs: multi-panel desktop layout)', 'components/workspace/*, MainLayout.tsx', 'D', prio=3, note='Behind the Labs flag.'),
    ]),
    ('3. Channel and DM conversation', 'components/message (ChatPanel, MessageItem, MessageTimeline, MessageInput, ThreadPanel), components/channel', [
        R('3.01', 'Channel screen (rail + sidebar + header + timeline + composer composed)', 'components/layout/MainLayout.tsx ChannelRoute, message/ChatPanel.tsx', 'DP',
          off=['screens.thread.channel'], d=['components.screens-ext.channel.desktop.full'], p=['components.screens-ext.channel.mobile.full'], prio=1,
          note='Composed 1280x800 and phone screens with a realistic message mix (markdown, code, mention, reactions, inline thread, system line).'),
        R('3.02', 'DM screen (human DM, agent DM composed)', 'components/layout/MainLayout.tsx DmRoute', 'DP',
          off=['screens.thread.dm'], d=['components.screens-ext.dm.desktop.*'], p=['components.screens-ext.dm.mobile.agent'], prio=1,
          note='Human and agent DM screens composed at 1280x800; phone has the agent DM.'),
        R('3.03', 'Desktop with no conversation selected ("Select a channel" empty main)', 'components/message/ChatPanel.tsx (channel=null)', 'D',
          d=['components.conversation.empty.desktop.no-channel'], prio=2),
        R('3.04', 'Conversation header (channel, private, DM human / agent, description clamp, search button, Chat / Files / Tasks tabs)', 'components/message/ChatPanel.tsx, channel/ChannelDescription.tsx', 'DP',
          off=['components.thread.header.states'], d=['components.channelheader.desktop.*'], p=['components.channelheader.mobile.*']),
        R('3.05', 'Timeline (date dividers, empty channel, loading, history limit banner, beginning of messages, system groups, back to bottom)', 'components/message/MessageTimeline.tsx, DateDivider.tsx, HistoryLimitBanner.tsx, SystemMessageGroupDisclosure.tsx', 'DP',
          d=['components.thread-ext.timeline.desktop.*'], p=['components.thread-ext.timeline.mobile.*']),
        R('3.06', 'Channel state banners (archived + Unarchive, read-only quota + upgrade, guest read-only + Join channel, joint locked, over-limit grace, message not found, channel unavailable)', 'components/message/ChatPanel.tsx', 'DP', prio=2,
          d=['components.conversation.banner.desktop.*'], p=['components.conversation.banner.mobile.*'],
          note='Read-only quota and "Chat is unavailable" have no case: unreachable in the pinned source (maxChannels is -1 '
               'for every plan; ChatPanel readOnly is passed by the visual-testing host only).'),
        R('3.07', 'Channel Files tab (list; empty, loading, error, load more)', 'components/message/ChannelFilesPanel.tsx', 'DP',
          off=['components.thread.files.list'], d=['components.conversation.files.desktop.*'],
          p=['components.conversation.files.mobile.*'], prio=2,
          note='List, load more, empty, loading and error at both widths (the official case is the phone list).'),
        R('3.08', 'Channel Tasks tab (TasksPanel scoped to the channel)', 'components/message/ChatPanel.tsx, task/TasksPanel.tsx', 'DP', prio=3,
          d=['components.conversation.tasks.desktop.*'], p=['components.conversation.tasks.mobile.*'],
          note='Same panel as the Tasks page (6.01) minus the channel column.'),
        R('3.09', 'Message row (human, agent, system, deleted, rich markdown, code, long inline code, links, task chips)', 'components/message/MessageItem.tsx, markdown/*', 'DP',
          off=['components.thread.message.row', 'components.thread.message-row.*'], d=['components.thread-ext.message.toolbar.desktop'], prio=2,
          note='Desktop: rows only appear inside toolbar / forward / mermaid cases.', d_state='partial'),
        R('3.10', 'Message hover toolbar and quick reaction picker', 'components/message/MessageHoverToolbar.tsx', 'D',
          d=['components.thread-ext.message.toolbar*', 'components.thread-ext.message.picker*']),
        R('3.11', 'Message context menu (default message, task message)', 'components/message/MessageItem.tsx', 'DP',
          off=['components.thread.message-menu.*'], d=['components.conversation.menu.desktop.*'], prio=2),
        R('3.12', 'Reaction chips row and reactors tooltip', 'components/message/MessageItem.tsx', 'DP',
          d=['components.conversation.reactions.desktop.*'], p=['components.conversation.reactions.mobile.*'], prio=3,
          note='The reactors tooltip is hover only (desktop).'),
        R('3.13', 'Message selection mode (toolbar, share-as-image lightbox)', 'components/message/SelectModeToolbar.tsx, SelectShareLightbox.tsx', 'DP',
          off=['components.thread.message-share.*'], d=['components.conversation.selection.desktop.*'], prio=3,
          note='Desktop: selection toolbar with one / two rows selected. The share-as-image lightbox has no case (it needs the html-to-image export).'),
        R('3.14', 'Forward composer (destinations, note, send)', 'components/message/ForwardComposerDesktop.tsx, ForwardComposerMobile.tsx', 'DP',
          off=['components.thread.forward-modal'], d=['components.conversation.forward.desktop.*'],
          p=['components.forward-mobile.page.*'], prio=2,
          note='Desktop dialog opened from the selection toolbar (destinations column, preview, note composer). '
               'Phone: the full-screen destinations / note pages (components.forward-mobile.page.*, also the share-mode chrome).'),
        R('3.15', 'Forwarded bundle card in the timeline (single, multi, expanded, thread, restricted)', 'components/message/ForwardedBundleCard.tsx', 'DP',
          d=['components.thread-ext.message.forward-*', '!*.mobile'], p=['components.thread-ext.message.forward-*.mobile']),
        R('3.16', 'Quoted message permalink preview and linked-message fallbacks', 'components/message/QuotedMessagePermalinkPreview.tsx', 'DP',
          d=['components.conversation.quote.desktop.*'], p=['components.conversation.quote.mobile.*'], prio=3,
          note='A Raft message link renders as a Link chip (channel label + msg) with the quoted card (author, time, thread / archived tags, clamped markdown, attachment tag) under the body; skeleton while loading, card dropped + "Unavailable linked message" chip when unreadable.'),
        R('3.17', 'Mermaid diagram card (toolbar, code view, diagram view)', 'components/mermaid/MermaidDiagram.tsx', 'DP',
          d=['components.thread-ext.message.mermaid-*', '!*.mobile'], p=['components.thread-ext.message.mermaid-toolbar.mobile']),
        R('3.18', 'Mermaid full-screen viewer', 'components/mermaid/MermaidDiagramViewer.tsx', 'DP',
          d=['components.conversation.mermaid.desktop.*'], p=['components.conversation.mermaid.mobile.*'], prio=3,
          note='Toolbar expand opens a Lightbox (24 / 12px stage, close control only) with the whole diagram contain-fitted, wheel / pinch zoom, pan and double-tap zoom; Esc / backdrop close.'),
        R('3.19', 'Composer (empty, draft with send enabled)', 'components/message/MessageInput.tsx', 'DP',
          off=['components.thread.composer.empty', 'components.thread.composer.states'],
          d=['components.thread-ext.thread.desktop.composer'], p=['components.thread-ext.thread.mobile.composer']),
        R('3.20', 'Composer @mention and #channel suggestion popovers', 'components/message/MessageInput.tsx, mentionCandidates.ts', 'DP',
          off=['components.thread.composer.member-suggestions', 'components.thread.composer.channel-suggestions'],
          d=['components.screens-ext.composer.desktop.*'], prio=1, note='Desktop: @mention (not-in-channel group) and #channel popovers over the composed channel screen.'),
        R('3.21', 'Composer "As task" mode', 'components/message/MessageInput.tsx', 'DP', off=['components.thread.composer.as-task-selected'],
          d=['components.composer-states.as-task.desktop.*'], p=['components.composer-states.as-task.mobile.*'], prio=2,
          note='Checkbox on, draft typed, over the composed channel screen (bottom window).'),
        R('3.22', 'Composer pending-mention action strip (agent outside the channel)', 'components/message/PendingMentionActionStrip.tsx', 'DP',
          off=['components.thread.composer.pending-mention-actions'],
          d=['components.composer-states.pending-mention.desktop.*'], p=['components.composer-states.pending-mention.mobile.*'], prio=3,
          note='Send receipt with one row, then two rows (Add all footer); Add / Notify / Ignore result states (Added / Queued chips, fade) have no case.'),
        R('3.23', 'Composer attachments (image, file, mixed, checking, uploading, failed, over size / count, drag over)', 'components/message/MessageInput.tsx, AttachmentChip.tsx', 'DP',
          off=['components.thread.composer.image-preview', 'components.thread.composer.file-previews'],
          d=['components.composerattachments.desktop.*'], p=['components.composerattachments.mobile.*']),
        R('3.24', 'Composer warnings (agent stopped delivery, unresolved mentions, conversion in progress, archived badge)', 'components/message/MessageInput.tsx', 'DP',
          d=['components.composer-states.warning.desktop.*', 'components.composer-states.suggestions.desktop.*'],
          p=['components.composer-states.warning.mobile.*', 'components.composer-states.suggestions.mobile.*'], prio=3,
          note='Agent-stopped (DM) and unresolved-mention banners come from the send receipt; conversion in progress disables Send; archived badge in the #channel popover. Mention-action failure notice and the generic error banner have no case here.'),
        R('3.25', 'Attachment viewers (image lightbox + gallery, text / csv / xlsx / markdown, html sandbox, comments panel)', 'components/message/attachmentPreviewSurfaces.tsx, ImageLightbox.tsx', 'DP',
          off=['components.thread.comment-anchor'], d=['components.thread-ext.attachment.*', '!*.mobile'], p=['components.thread-ext.attachment.*.mobile']),
        R('3.26', 'Audio, video, PDF and diff / patch previews', 'components/message/MessageItem.tsx, ui/CrossOriginPdfFrame.tsx', 'DP', prio=3,
          d=['components.thread-ext.attachment.doc.header-pdf', 'components.conversation.attach.desktop.*'],
          p=['components.conversation.attach.mobile.*'],
          note='Audio and video attachments are inline players (audio card with seek / volume / download, 16:9 video with the preview corner action, loading / failed states); PDF and patch keep the attachment card.'),
        R('3.27', 'Profile preview card (hover / tap on an avatar: agent runtime, model, computer; human)', 'components/message/ProfilePreviewCardContent.tsx', 'D',
          d=['components.conversation.profile.desktop.agent', 'components.conversation.profile.desktop.human'], prio=2,
          note='Hover only: a touch screen never opens the PreviewCard (a tap navigates), so no phone case. The "Recent activity" link opens '
               'the agent profile panel on its Activity tab (3.30).'),
        R('3.28', 'Mention hover activity preview', 'components/message/MentionHoverActivityPreview.tsx', 'D',
          d=['components.conversation.profile.desktop.agent-activity'], prio=3),
        R('3.29', 'External identity preview card and detail panel', 'components/message/ExternalIdentityPreviewCard.tsx, profile/ExternalIdentityDetailPanel.tsx', 'DP',
          d=['components.conversation.external.desktop.*'], p=['components.conversation.external.mobile.*'], prio=3,
          note='Hover card (desktop) and the detail panel (desktop side panel / phone page) are mapped; the avatar opens the panel.'),
        R('3.30', 'Profile side panel (open from a sender)', 'components/profile/ProfilePanel.tsx', 'D',
          d=['components.members-ext.human.*', 'components.members-ext.agent.*'], prio=2, d_state='partial',
          note='The panel body is HumanDetailPanel / AgentDetailPanel (7.03, 7.08-7.14, already covered). A sender avatar, a mention, the hover '
               'card\'s Recent activity and a follower row open it (desktop column beside / over the thread, phone page). The composed panel next to a '
               'chat has no case, hence partial.'),
        R('3.31', 'Action card in a message (install app, create agent, channel members, owner recovery)', 'components/actions/ActionCard.tsx', 'DP',
          d=['components.conversation.action.desktop.*'], p=['components.conversation.action.mobile.*'], prio=2),
        R('3.32', 'SOS dialog (confirm, stopped, guidance)', 'components/message/SOSDialog.tsx', 'DP',
          d=['components.thread-ext.message.sos-*', '!*.mobile'], p=['components.thread-ext.message.sos-confirm.mobile']),
        R('3.33', 'Notification activation banner', 'components/message/NotificationActivationBanner.tsx', 'DP',
          d=['components.thread-ext.message.banner.desktop'], p=['components.thread-ext.message.banner.mobile']),
        R('3.34', 'Translation in message rows (translating, original / bilingual, unavailable)', 'components/message/MessageItem.tsx', 'DP',
          d=['components.conversation.translate.desktop.*'], p=['components.conversation.translate.mobile.*'], prio=3,
          note='Auto translation to zh-cn: translating, translated, bilingual, failed. The Language & Region settings page has cases (9.05).'),
        R('3.35', 'Thread panel (replies, empty, loading, history limited, overflow menu)', 'components/message/ThreadPanel.tsx, ThreadOverflowMenu.tsx', 'DP',
          d=['components.thread-ext.thread.desktop.*'], p=['components.thread-ext.thread.mobile.*']),
        R('3.36', 'Inline thread replies preview', 'components/message/InlineThreadReplies.tsx', 'DP',
          d=['components.thread-ext.inline.desktop.*'], p=['components.thread-ext.inline.mobile.*']),
        R('3.37', 'Thread load failed (retry), guest read-only, joint locked', 'components/message/ThreadPanel.tsx', 'DP',
          d=['components.conversation.threadstate.desktop.*'], p=['components.conversation.threadstate.mobile.*'], prio=3,
          note='Also the Join-parent-channel CTA. Flutter gates a guest\'s channel / thread open on the viewChannel capability '
               'the role matrix denies guests, so the guest case cannot open the thread on desktop.'),
        R('3.38', 'In-thread search (search bar, next / previous match)', 'components/message/ThreadPanel.tsx', 'DP',
          d=['components.conversation.threadsearch.desktop.*'], p=['components.conversation.threadsearch.mobile.*'], prio=3,
          note='Thread overflow menu "Search in thread" opens the search bar (Cmd/Ctrl+F too): query, n/m count, prev / next, marked matches.'),
        R('3.39', 'Thread agent followers (list, remove, undo)', 'components/thread/ThreadAgentFollowers.tsx', 'DP',
          d=['components.conversation.followers.desktop.*'], p=['components.conversation.followers.mobile.*'], prio=3,
          note='Thread header trigger (N Agents following) and popover: rows with activity, remove + Undo toast, peer-server rows, loading / error / retry. Remove / undo have widget tests, no parity case.'),
        R('3.40', 'Channel overflow menu (members summary, inline edit, stop all agents confirm)', 'components/channel/ChannelOverflowMenu.tsx', 'DP', prio=3),
    ]),
    ('4. Channel management dialogs', 'components/channel, components/agent/ChannelMembers.tsx', [
        R('4.01', 'Create channel dialog (public / private, members picker)', 'components/channel/CreateChannelDialog.tsx', 'DP',
          off=['components.home.create-channel.dialog'], d=['components.dialogs.desktop.create-channel'], prio=1),
        R('4.02', 'Create channel states (name error, archived name held + Unarchive, plan limit, creating)', 'components/channel/CreateChannelDialog.tsx', 'DP',
          d=['components.list-pages.create-channel.desktop-*'], p=['components.list-pages.create-channel.phone-*'], prio=3,
          note='Plan-limit state is unreachable in the pinned source (every plan has maxChannels -1).'),
        R('4.03', 'Create shared (joint) channel dialog', 'components/channel/CreateJointChannelDialog.tsx', 'DP',
          d=['components.list-pages.members.desktop-create-joint'], p=['components.list-pages.members.phone-create-joint'], prio=3),
        R('4.04', 'Channel settings drawer (owner, admin, member, guest, private, archived, dirty, #all, DM, members overflow, tall windows)', 'components/channel/EditChannelDialog.tsx, agent/ChannelMembers.tsx', 'DP',
          off=['components.channel.settings.panel'], d=['components.channelsettings.desktop.*'], p=['components.channelsettings.mobile.*']),
        R('4.05', 'Channel settings confirmations (leave, archive, make private, hide #all, delete, unsaved changes)', 'components/channel/EditChannelDialog.tsx', 'DP',
          d=['components.channelsettings.desktop.confirm-*', 'components.channelsettings.desktop.unsaved-prompt'], p=['components.channelsettings.mobile.confirm-delete'],
          note='Phone: delete confirm only.', p_state='partial'),
        R('4.06', 'Add members to a channel', 'components/channel/AddMembersDialog.tsx', 'DP',
          off=['components.channel.members.add-panel'],
          d=['components.channelsettings.desktop.members-page-add', 'components.list-pages.members.desktop-add-dialog'],
          p=['components.members-pages.phone.channel-members.add-view', 'components.list-pages.members.phone-add-dialog'], prio=2),
        R('4.07', 'Remove channel member confirm (and the members page row actions: profile, Make admin / Demote)', 'components/channel/useChannelMemberRemoval.tsx, agent/ChannelMembers.tsx', 'DP',
          d=['components.members-pages.desktop.channel-members.*', 'components.list-pages.members.desktop-remove-confirm'],
          p=['components.members-pages.phone.channel-members.*', 'components.list-pages.members.phone-remove-confirm'], prio=3),
    ]),
    ('5. Search, Activity and Saved', 'components/search, components/thread/ThreadsInbox.tsx, components/saved', [
        R('5.01', 'Search overlay (desktop Cmd-K): home, recents, query, exact, selected, no results, loading, error, thread group, sender filter', 'components/search/SearchOverlay.tsx, MessageSearchPage.tsx (overlay presentation)', 'D',
          d=['components.search-overlay.*']),
        R('5.02', 'Search results page (phone Search tab; desktop "view all results")', 'components/search/MessageSearchPage.tsx', 'DP',
          off=['components.home.search.results'], d=['components.list-pages.search.desktop-results'], prio=2),
        R('5.03', 'Search channel filter dropdown', 'components/search/MessageSearchPage.tsx', 'DP',
          off=['components.home.search.channel-dropdown'], d=['components.list-pages.search.desktop-channel-filter'], prio=3),
        R('5.04', 'Search page states (history + frequent, searching, no results, error + retry, load more, query too broad, beyond plan history)', 'components/search/MessageSearchPage.tsx', 'DP', prio=2,
          d=['components.list-pages.search.desktop-*'], p=['components.list-pages.search.phone-*'],
          note='Overlay variants are 5.01; the full-page variants are these cases.'),
        R('5.05', 'Activity inbox, populated list', 'components/thread/ThreadsInbox.tsx', 'DP',
          off=['components.home.activity.results', 'screens.home.activity'], d=['components.screens-ext.activity.desktop.list'], prio=1,
          note='Desktop: rail plus the 560px Activity master column with the official three-row inbox fixture.'),
        R('5.06', 'Activity empty / loading / error', 'components/thread/ThreadsInbox.tsx', 'DP',
          d=['components.members-ext.activity.*', 'components.thread-ext.inbox.desktop.empty'],
          p=['components.list-pages.activity.phone-empty', 'components.list-pages.activity.phone-loading', 'components.list-pages.activity.phone-error'], prio=3),
        R('5.07', 'Activity filters (All / Mentions / Unread)', 'components/thread/ThreadsInbox.tsx', 'DP',
          d=['components.list-pages.activity.desktop-filter-*'], p=['components.list-pages.activity.phone-filter-*'], prio=2),
        R('5.08', 'Activity item context menu (mark read / unread, follow, done)', 'components/thread/ThreadsInbox.tsx', 'DP',
          d=['components.list-pages.activity.desktop-context-menu'], p=['components.list-pages.activity.phone-context-menu'], prio=3),
        R('5.09', 'Saved messages list', 'components/saved/SavedPanel.tsx', 'DP',
          off=['components.home.saved.results', 'screens.home.saved'], d=['components.list-pages.saved.desktop-list'], prio=2),
        R('5.10', 'Saved empty / loading / error', 'components/saved/SavedPanel.tsx', 'DP', d=['components.members-ext.saved.*'],
          p=['components.list-pages.saved.phone-empty', 'components.list-pages.saved.phone-loading', 'components.list-pages.saved.phone-error'], prio=3),
        R('5.11', 'Saved item actions (copy link, copy Markdown, remove)', 'components/saved/SavedPanel.tsx', 'DP',
          d=['components.list-pages.saved.desktop-actions'], p=['components.list-pages.saved.phone-actions'], prio=3),
        R('5.12', 'Activity Done and Saved views, channel filter, sort, in-list search', 'components/thread/ThreadsInbox.tsx', 'DP', prio=2),
    ]),
    ('6. Tasks', 'components/task', [
        R('6.01', 'Tasks page (desktop board / phone list)', 'components/task/TasksPanel.tsx', 'DP',
          off=['screens.tasks.index', 'components.tasks.panel.states'], d=['components.taskspage.desktop.*'], p=['components.taskspage.mobile.*']),
        R('6.02', 'Tasks page, empty lanes', 'components/task/TasksPanel.tsx', 'DP', d=['components.wp6.tasks.empty-lanes', 'components.wp6.tasks.empty-lanes-expanded'], p=['components.wp6.tasks.empty-lanes-mobile']),
        R('6.03', 'Task filter segmented control', 'components/task/TaskFilterSegmentedControl.tsx', 'DP', d=['components.wp6.tasks.filter*', '!*-mobile'], p=['components.wp6.tasks.filter*-mobile']),
        R('6.04', 'Task filters (assignee, creator, channels popovers; clear all; filtered-empty)', 'components/task/TasksPanel.tsx', 'DP',
          d=['components.list-pages.tasks.desktop-filter*'], p=['components.list-pages.tasks.phone-filter*'], prio=2),
        R('6.05', 'Tasks list / board view toggle (the non-default view)', 'components/task/TasksPanel.tsx', 'D', d=['components.list-pages.tasks.desktop-board', 'components.list-pages.tasks.desktop-list'], prio=3),
        R('6.06', 'Task status menu', 'components/task/StatusBadge.tsx, TasksPanel.tsx', 'DP', off=['components.tasks.status-menu'], d=['components.list-pages.tasks.desktop-status-menu'], prio=3),
        R('6.07', 'Create task dialog (default, filled, batch, title required)', 'components/task/CreateTaskDialog.tsx', 'DP',
          d=['components.wp6.tasks.create-dialog*', '!*-mobile'], p=['components.wp6.tasks.create-dialog*-mobile']),
        R('6.08', 'Task detail (thread modal with properties, replies, history; every status)', 'components/task/TaskProperties.tsx, message/ThreadPanel.tsx', 'DP',
          off=['screens.thread.task-thread'], d=['components.taskdetail.desktop.*'], p=['components.taskdetail.mobile.*']),
        R('6.09', 'Legacy (v1) task panel, read-only', 'components/task/LegacyTaskPanel.tsx', 'DP', prio=3),
        R('6.10', 'Tasks loading and load-more states', 'components/task/TasksPanel.tsx', 'DP',
          d=['components.list-pages.tasks.desktop-loading', 'components.list-pages.tasks.desktop-load-more'],
          p=['components.list-pages.tasks.phone-loading', 'components.list-pages.tasks.phone-load-more'], prio=3),
    ]),
    ('7. Members, humans and agents', 'components/member, components/agent, components/agentMigration, components/handoff', [
        R('7.01', 'Members list (agents grouped by computer, humans; selected, hover, collapsed)', 'components/layout/Sidebar.tsx (members mode)', 'DP',
          off=['screens.members.index'], d=['components.members-ext.list.default', 'components.members-ext.list.selected-*', 'components.members-ext.list.row-hover',
                                           'components.members-ext.list.group-collapsed', 'components.members-ext.list.humans-collapsed']),
        R('7.02', 'Members list empty / loading / error', 'components/layout/Sidebar.tsx (members mode)', 'DP',
          d=['components.members-ext.list.empty', 'components.members-ext.list.loading', 'components.members-ext.list.error'],
          p=['components.members-pages.phone.list.*'], prio=3),
        R('7.03', 'Human profile (self, member, admin, guest, no description)', 'components/member/HumanDetailPanel.tsx', 'DP',
          off=['screens.members.human.profile'], d=['components.members-ext.human.*']),
        R('7.04', 'Human profile actions (edit role, remove member confirm)', 'components/member/HumanDetailPanel.tsx', 'DP',
          d=['components.members-ext.human.edit-role', 'components.members-ext.human.remove-confirm'],
          p=['components.members-pages.phone.human.edit-role', 'components.members-pages.phone.human.remove-confirm'], prio=3),
        R('7.05', 'Role permission help dialog', 'components/member/RolePermissionHelpDialog.tsx', 'DP',
          d=['components.members-pages.desktop.human.role-help', 'components.members-pages.desktop.agent.role-help'], p=['components.members-pages.phone.human.role-help', 'components.members-pages.phone.agent.role-help'], prio=3),
        R('7.06', 'Invite human dialog (email / link tabs, guest role, seat limit)', 'components/member/InviteHumanDialog.tsx', 'DP',
          d=['components.members-ext.invite.*', 'components.members-pages.desktop.invite.link'], p=['components.members-pages.phone.invite.*'], prio=2,
          note='Seat-limit state: no case (needs the billing store on both sides).'),
        R('7.07', 'Avatar management (upload, view)', 'components/member/HumanDetailPanel.tsx, agent/AgentDetailPanel.tsx', 'DP',
          off=['components.members.avatar-management'], d=['components.members-pages.desktop.agent.avatar-change', 'components.members-pages.desktop.human.avatar-view'], prio=3),
        R('7.08', 'Agent detail: Profile tab (computer online / offline / missing, no computer, daemon only, loading)', 'components/agent/AgentDetailPanel.tsx', 'DP',
          off=['components.members.agent-detail.profile', 'screens.members.agent-detail.profile', 'screens.members.agent-detail.profile.*'], d=['components.members-ext.agent.profile'],
          note='Desktop Agent-detail cases are being extended on cindy/alignment-audit.'),
        R('7.09', 'Agent detail: Activity tab (log, empty, loading, error)', 'components/agent/AgentActivityLog.tsx', 'DP',
          off=['screens.members.agent-detail.activity'], d=['components.members-ext.agent.activity*']),
        R('7.10', 'Agent detail: Chat tab (channels and DMs of the agent)', 'components/agent/AgentDetailPanel.tsx (AgentChatTab)', 'DP', prio=2,
          note='Desktop: in progress on cindy/alignment-audit. Phone: no case.'),
        R('7.11', 'Agent detail: Reminders tab', 'components/agent/AgentRemindersSection.tsx', 'DP',
          off=['screens.members.agent-detail.reminders'], d=['components.members-ext.agent.reminders']),
        R('7.12', 'Agent detail: Workspace tab (files)', 'components/agent/AgentWorkspace.tsx', 'DP',
          off=['screens.members.agent-detail.workspace'], d=['components.members-ext.agent.workspace']),
        R('7.13', 'Agent detail: Apps tab', 'components/agent/AgentAppAccessTab.tsx', 'DP',
          off=['screens.members.agent-detail.apps'], d=['components.members-ext.agent.apps']),
        R('7.14', 'Agent detail: MCP tab (servers, empty, loading)', 'components/agent/AgentMcpTab.tsx', 'DP',
          d=['components.members-ext.agent.mcp*'], p=['components.members-pages.phone.agent.mcp*'], prio=2),
        R('7.15', 'Reset / restart agent dialog (restart, reset session, full reset)', 'components/agent/ResetAgentDialog.tsx', 'DP',
          off=['components.members.agent-lifecycle-actions'], d=['components.members-ext.agent.reset-*']),
        R('7.16', 'Agent profile edit dialogs (name, description, role)', 'components/agent/AgentProfileEditDialog.tsx', 'DP',
          d=['components.members-ext.agent.edit-*'], p=['components.members-pages.phone.agent.edit-*'], prio=3),
        R('7.17', 'Agent runtime config editor (modal)', 'components/agent/AgentDetailPanel.tsx, RuntimeConfigFields.tsx', 'DP',
          d=['components.members-pages.desktop.agent.runtime-edit'], p=['components.members-pages.phone.agent.runtime-edit'], prio=2,
          note='Web presents the v2 server form only while runtime_form_v2_web (default off) is on and the runtime carries the v2 marker; otherwise its Runtime / Model / Reasoning / Mode modal. Flutter mirrors that choice; Built-in Pi / Pi / Kimi Code (provider and schema fields) stay on the v2 form.'),
        R('7.18', 'Stop agent / delete agent confirmations and overflow menu', 'components/agent/AgentProfileOverflowMenu.tsx, AgentDetailPanel.tsx', 'DP',
          d=['components.members-pages.desktop.agent.stop-confirm', 'components.members-pages.desktop.agent.delete-confirm'],
          p=['components.members-pages.phone.agent.overflow-menu', 'components.members-pages.phone.agent.stop-confirm', 'components.members-pages.phone.agent.delete-confirm'], prio=2),
        R('7.19', 'Report issue dialog', 'components/agent/ReportIssueDialog.tsx', 'DP',
          d=['components.members-pages.desktop.report-issue'], p=['components.members-pages.phone.report-issue'], prio=3,
          note='The entry (agent profile Actions) needs a feedback export worker in the build: Web VITE_FEEDBACK_EXPORT_URL, Flutter --dart-define RAFT_FEEDBACK_EXPORT_URL.'),
        R('7.20', 'Agent unavailable panel (terminated or no access)', 'components/agent/AgentUnavailablePanel.tsx', 'DP',
          d=['components.members-pages.desktop.agent.unavailable'], p=['components.members-pages.phone.agent.unavailable'], prio=2),
        R('7.21', 'Agent migration (move to another computer: dialog, progress, cancel, upgrade)', 'components/agentMigration/*', 'DP', prio=3, note='Behind agent_migration_v0: the profile action now follows the flag (Flutter reads it with the sync flags, no extra request).'),
        R('7.22', 'Agent connections (provider sign-in for the agent)', 'components/agent/AgentConnections.tsx', 'DP', prio=3),
        R('7.23', 'External agent setup (token, setup tabs)', 'components/agent/ExternalAgentToken.tsx, ExternalSetupTabSegmentedControl.tsx', 'DP',
          d=['components.members-pages.desktop.agent.external'], p=['components.members-pages.phone.agent.external'], prio=3,
          note='Hosted-runtime variants (HostedRuntimeStatus, AgentConnections) stay flag-off (antiproton_hosted_runtime), see 7.22.'),
        R('7.24', 'Create agent dialog (Codex, Claude, custom provider, built-in / Pi provider, onboarding, no computer, empty, name error)', 'components/agent/CreateAgentDialog.tsx', 'DP',
          off=['components.members.create-agent.*'], d=['components.dialogs.desktop.create-agent*'], prio=1),
        R('7.25', 'Member graph (/members/graph)', 'components/settings/MemberGraphSection.tsx', 'DP',
          d=['components.members-pages.desktop.graph'], p=['components.members-pages.phone.graph'], prio=3,
          note='Entry: the Graph row on top of the members list (classic sidebar, workspace grid off). Guests are sent home like the Web route.'),
        R('7.26', 'Handoff dialog (hand a local coding session to a new agent)', 'components/handoff/HandoffDialog.tsx, HandoffCreateFlow.tsx', 'D', prio=3, note='Desktop only (handoff.desktopOnly).'),
    ]),
    ('8. Computers', 'components/machine', [
        R('8.01', 'Computers list in the rail (rows, every row state, empty, loading, selected, hover)', 'components/layout/Sidebar.tsx (computers mode)', 'D',
          d=['components.computers.list.*']),
        R('8.02', 'Phone Computers page (list, needs-attention filter, empty, load error, refresh error)', 'components/machine/MobileComputersPanel.tsx', 'P',
          p=['components.list-pages.computers.phone-list', 'components.list-pages.computers.phone-attention', 'components.list-pages.computers.phone-empty',
             'components.list-pages.computers.phone-loading', 'components.list-pages.computers.phone-load-error', 'components.list-pages.computers.phone-refresh-error'],
          prio=2),
        R('8.03', 'Computer detail (header, identity, name / description edit, info, agents + bulk select, workspaces, service, recovery guide, offline, upgrading, disk low, legacy, delete)', 'components/machine/MachineDetailPanel.tsx', 'DP',
          d=['components.computers.detail.*'], p=['components.list-pages.computers.phone-detail.*'], prio=2),
        R('8.04', 'Add computer dialog (type step, connect step)', 'components/machine/AddMachineDialog.tsx', 'DP',
          d=['components.computers.add-dialog*'], p=['components.list-pages.computers.phone-add-dialog*'], prio=3,
          note='Connected, plan-limit and failed steps have no case.'),
        R('8.05', 'Computer dialogs (restart / reset agents, stop agents, delete workspace, delete blocked, delete)', 'components/machine/MachineDetailPanel.tsx', 'DP',
          d=['components.computers.dialog.*'], p=['components.list-pages.computers.phone-dialog.*'], prio=3),
        R('8.06', 'Runtime usage health chip and hover card', 'components/machine/RuntimeAccountUsageChip.tsx', 'D', d=['components.computers.detail.runtime-usage.*']),
    ]),
    ('9. Settings', 'components/settings/SettingsPanel.tsx (tabs in settingsNavigation.ts), WorkspaceSettingsModal.tsx', [
        R('9.01', 'Settings navigation (desktop rail by role / flags; phone root list)', 'components/layout/Sidebar.tsx (settings rail), settings/SettingsSidebarList.tsx, settingsNavigation.ts', 'DP',
          off=['components.settings.root.page'], d=['components.ext-settings.nav.*']),
        R('9.02', 'Account tab (profile card, display name, avatar, email, social links)', 'components/settings/SettingsPanel.tsx AccountSection', 'DP',
          off=['components.settings.account.page', 'components.settings.account.error-state'], d=['components.ext-settings.account.*'], prio=1),
        R('9.03', 'Account: change password, sign out', 'components/settings/SettingsPanel.tsx AccountSection', 'DP',
          d=['components.auth-pages.desktop.settings.account-*'], p=['components.auth-pages.mobile.settings.account-*'], prio=3),
        R('9.04', 'Account: usage data / storage', 'components/settings/UsageDataSettings.tsx, SettingsPanel.tsx', 'DP',
          off=['screens.settings.storage'], d=['components.wp6.settings.usage-data'],
          p=['components.wp6.settings.usage-data-mobile'],
          note='The workspace-mode card left with the desktop grid (Web v1.21.x).'),
        R('9.05', 'Language & Region (translation modes, display, provider missing, server off)', 'components/settings/SettingsPanel.tsx LanguageRegionSection', 'DP',
          d=['components.wp6.settings.language*', '!*-mobile'], p=['components.wp6.settings.language*-mobile']),
        R('9.06', 'Appearance tab (theme picker, text size)', 'components/settings/SettingsPanel.tsx AppearanceSection, AppearanceThemePicker.tsx', 'DP',
          off=['components.settings.appearance.page', 'screens.settings.appearance'], d=['components.ext-settings.appearance.*'], prio=2),
        R('9.07', 'Notifications tab (web push, desktop native, app notification controls)', 'components/settings/SettingsPanel.tsx NotificationsSection, AppNotificationsControls.tsx', 'DP',
          off=['components.settings.notifications.page'], d=['components.ext-settings.notifications.*', 'components.notifications.desktop.*'], prio=2),
        R('9.08', 'Server Profile tab (name, slug, avatar, description, public visibility)', 'components/settings/SettingsPanel.tsx ProfileSection, PublicVisibilitySection', 'DP',
          off=['components.settings.server.profile'], d=['components.ext-settings.server.*']),
        R('9.09', 'Server danger zone and its confirm modals (delete / leave server)', 'components/settings/SettingsPanel.tsx DangerZoneSection', 'DP',
          off=['screens.settings.server-danger-modal'], d=['components.auth-pages.desktop.settings.server-danger-*'], prio=2),
        R('9.10', 'Archived channels list (Unarchive)', 'components/settings/ArchivedChannelsSection.tsx', 'DP', d=['components.auth-pages.desktop.settings.archived-channels'], p=['components.auth-pages.mobile.settings.archived-channels'], prio=3,
          note='Flutter: ArchivedChannelsSection in Server settings (RaftArchivedChannelsSection); the React host patch now appends the channels once.'),
        R('9.11', 'Plan & Billing (free / trial, Pro, seats, checkout summary, confirm dialog, admin read-only, loading)', 'components/settings/SettingsPanel.tsx PlanSection', 'DP',
          off=['screens.settings.billing-portal'], d=['components.ext-settings.billing.*', '!*.mobile*'], p=['components.ext-settings.billing.mobile*']),
        R('9.12', 'Billing: downgrade warning card', 'components/settings/SettingsPanel.tsx DowngradeWarningCard', 'DP',
          d=['components.auth-pages.desktop.settings.downgrade-*'], p=['components.auth-pages.mobile.settings.downgrade-*'], prio=3),
        R('9.13', 'Administration (admins, system channels, invites, join links, agreement, onboarding, translation, analytics, member permissions)', 'components/settings/SettingsPanel.tsx AdministrationTabContent', 'DP',
          d=['components.ext-settings.administration.*', '!*.mobile.*'], p=['components.ext-settings.administration.mobile.*'],
          note='Phone: admins, join links, onboarding, pre-join agreement only.', p_state='partial'),
        R('9.14', 'Applications (installed, my apps, marketplace list / detail, installed detail, member read-only, empty)', 'components/settings/SettingsPanel.tsx IntegrationsSection', 'DP',
          d=['components.ext-settings.integrations.*', '!*.mobile*'], p=['components.ext-settings.integrations.mobile*']),
        R('9.15', 'Application editor (register app, redirect URLs, declared scopes, scope list)', 'components/settings/SettingsPanel.tsx ConnectedAppEditorSection, DeclaredScopesPicker', 'DP',
          d=['components.auth-pages.desktop.settings.app-editor'], p=['components.auth-pages.mobile.settings.app-editor'], prio=3,
          note='Flutter: RaftConnectedAppEditorCard (rail + six sections) in connected_app_editor.dart; only the register (new app) state has a case.'),
        R('9.16', 'MCP Servers tab', 'components/settings/SettingsPanel.tsx McpSettingsSection', 'DP', d=['components.ext-settings.mcp.*', '!*.mobile'], p=['components.ext-settings.mcp.mobile'], prio=3),
        R('9.17', 'AI Providers tab (connections list)', 'components/settings/ProviderConnectionsSettings.tsx', 'DP', d=['components.ext-settings.providers.*', '!*.mobile'], p=['components.ext-settings.providers.mobile'], prio=3),
        R('9.18', 'AI provider edit modal (gateway, preset, save failed)', 'components/settings/EditProviderConnectionModal.tsx', 'DP',
          d=['components.wp6.settings.provider-edit', 'components.wp6.settings.provider-edit-preset', 'components.wp6.settings.provider-edit-error'],
          p=['components.wp6.settings.provider-edit-mobile', 'components.wp6.settings.provider-edit-preset-mobile']),
        R('9.19', 'IM Bridges tab', 'components/settings/IMBridgesSettingsSection.tsx', 'DP', d=['components.ext-settings.im-bridges.*', '!*.mobile'], p=['components.ext-settings.im-bridges.mobile'], prio=3),
        R('9.20', 'Slack bridge wizard (connect, OAuth, channel pairs, preflight, enable, health, recovery, manage, disconnect, load failed)', 'components/settings/SlackBridgeSetupWizard.tsx', 'DP',
          d=['components.wp6.settings.bridge-*', '!*-mobile'], p=['components.wp6.settings.bridge-*-mobile'], note='Phone: connect, channel pairs, preflight, recovery only.', p_state='partial'),
        R('9.21', 'Labs tab', 'components/settings/SettingsPanel.tsx LabsSection', 'DP', d=['components.ext-settings.labs.*', '!*.mobile'], p=['components.ext-settings.labs.mobile'], prio=3),
        R('9.22', 'About tab (version, mobile app QR, workspace)', 'components/settings/SettingsPanel.tsx AboutSection, MobileDownloadQr.tsx', 'DP', d=['components.ext-settings.about.*', '!*.mobile'], p=['components.ext-settings.about.mobile'], prio=3),
        R('9.23', 'Release notes (current, retracted, older, loading, error, empty)', 'components/settings/ReleaseNotesPanel.tsx', 'DP', d=['components.ext-settings.release-notes.*'], p=['components.auth-pages.mobile.settings.release-notes*'], prio=3),
        R('9.24', 'Feedback (inbox, new, ticket, reply, close, errors)', 'components/settings/AboutFeedbackDialog.tsx, feedback/*', 'DP',
          d=['components.ext-settings.feedback.*'], p=['components.wp6.settings.feedback-*-mobile']),
    ]),
]

# ---------------------------------------------------------------- reachability audit (owner follow-up 2026-10-11)
# Evidence from the pinned raft-source (packages/web/src, packages/server/drizzle, packages/shared/src). Only
# conservative marks: `excl` when the source shows the page is dead / withdrawn / flag-gated default-off / host-bound,
# `verify` when reachability is unclear or the page may not apply to a native client.
FLAG_SEED = 'server/drizzle seeds the flag default_enabled=false'
MARKS = {
    '6.03': dict(excl=('obsolete', 'TaskFilterSegmentedControl.tsx has no importer under src/; only tests/raftUiSegmentedControls.behavior.test.tsx '
                       'and tests/raftUiIntegration.contract.test.ts import it. TasksPanel.tsx uses its own filter popovers (task.filter.*).')),
    '6.09': dict(excl=('obsolete', 'LegacyTaskPanel opens only for `task.isLegacy` rows (TasksPanel.tsx:972-976, MessageItem.tsx:4184); '
                       'shared/src/agentText/tasks.ts:77 labels them "[LEGACY - read-only]"; new tasks open their message thread.')),
    '2.21': dict(excl=('flag-off', 'workspaceGridAvailability.ts gates on flag chat_grid_layout_v0 (config named WORKSPACE_GRID_DEMO); '
                       'migration 0151 "Workspace grid layout preview gate; Botiverse allowlist first", default_enabled=false.')),
    '7.21': dict(excl=('flag-off', 'AgentMigrationSection.tsx returns null unless useAgentMigrationUiEnabled() (flag agent_migration_v0); '
                       'migration 0150 default_enabled=false, 0154 dark-launches it to the botiverse server only.')),
    '7.22': dict(excl=('flag-off', 'AgentDetailPanel.tsx:1842 renders AgentConnections only for an external agent with hostedRuntime.state "active"; '
                       'hosted runtime is flag antiproton_hosted_runtime ("Server-stage, default off", shared/src/featureFlags.ts:11; migration 0296 default false).')),
    '1.29': dict(excl=('flag-off', 'OAuth return page of AgentConnections (7.22): same hosted-runtime flag antiproton_hosted_runtime, default off.')),
    '3.29': dict(verify='External-identity cards come from provider-bridge senders; slack_bridge_v0 and external_projection_directory are seeded default false and fail closed (migration 0252), but messages from an already-enabled bridge would show them. Confirm the bridge is out of scope before dropping.'),
    '9.17': dict(verify='provider_connections_v0 (migration 0217) was seeded default false, "initially limited to slock-android and botiverse servers"; the tab is hidden without it. Later rollout rules are not in the source. Cases exist (ext-settings.providers.*).'),
    '9.18': dict(verify='Edit modal of the AI Providers tab: same flag provider_connections_v0 as 9.17. Cases exist (wp6.settings.provider-edit*).'),
    '9.19': dict(verify='slack_bridge_v0 "Whole Slack Bridge launch and rollback gate": seeded default false with no allow rules (migration 0252); the tab is hidden without it. Cases exist (ext-settings.im-bridges.*).'),
    '9.20': dict(verify='Wizard of the IM Bridges tab: same flag slack_bridge_v0 as 9.19. Cases exist (wp6.settings.bridge-*, about 22).'),
    '9.21': dict(verify='server_labs_ui_v0 "Web Server Settings Labs UI exposure gate" (migration 0192, default false); the tab is hidden without it. Cases exist (ext-settings.labs.*).'),
    '2.13': dict(excl=('host-only', 'Sidebar.tsx:3856 renders SidebarConversationFinder only when isElectronDesktopShell(); the comment says "web withdraws it (@artin 2026-09-11)".')),
    '7.26': dict(excl=('host-only', 'handoff/handoffSessions.ts:59 isHandoffAvailable() = isElectronDesktopShell() && bridge; Sidebar.tsx:2447 shows the menu item only then.')),
    '3.40': dict(excl=('duplicate', 'ChannelOverflowMenu.tsx:568 renders EditChannelDialog: it is the channel settings sheet already listed as 4.04 / 4.05 '
                       '(the channelsettings cases open it through the header gear).')),
    '5.12': dict(excl=('flag-off', 'ThreadsInbox.tsx gates Saved / Done views (:872-879), the channel filter (:665), sort and in-list search (:922) on activity_sidebar_inbox_v0; no server migration seeds that key, so it evaluates disabled unless an operator created it (the Flutter DesktopActivityFlag reads the same flag).')),
    # verify: kept in the counts.
    '1.25': dict(excl=('browser-only', 'DeviceLoginPage.tsx (/login/device) is the browser page the CLI / computer opens to approve a device code; the native client never renders it and has no route for it.')),
    '1.26': dict(excl=('browser-only', 'AppLoginPage.tsx (/login/app) is the HarmonyOS web-login hand-off (pages/AppLoginPage.tsx:10); not a Flutter surface.')),
    '1.27': dict(excl=('browser-only', "HumanLoginSetupPage.tsx (/login-with-raft/setup) is the third-party 'Login with Raft' consent page opened in a browser; the Flutter app has no such route.")),
    '1.28': dict(excl=('browser-only', 'IntegrationInvitePage.tsx (/integration-invite) is a browser page for OAuth-app invites; the Flutter app has no route for it.')),
    '1.30': dict(excl=('browser-only', 'MobileDownloadChooserPage.tsx (/download) is the public browser page behind the mobile download QR; a native client cannot show it.')),
    '1.31': dict(excl=('browser-only', 'ChineseCommunityPage.tsx is a browser landing page linked from help menus and the invite page; the Flutter app has no route for it.')),
    '1.32': dict(excl=('browser-only', 'PwaInstallPrompt.tsx is the iOS Safari add-to-home-screen prompt; meaningless inside a native app.')),
    '1.34': dict(excl=('browser-only', 'AppUpdateGate.tsx is the Web stale-bundle gate (main.tsx); a native app updates through its store.')),
    '1.11': dict(excl=('browser-only', 'SocialAuthCallbackPage.tsx is the browser tab a Web OAuth redirect lands on (loading / error); the native client runs OAuth in the system browser and exchanges the code itself (RaftApp.completeOAuth), so no such page exists in the app.')),
    '9.04': dict(verify='UsageDataSettings ("Share usage data") is behind product_analytics_settings_v0, documented "Default off: hidden until the default and the privacy-policy section are confirmed" (serverFeatureFlags.ts:31-35).'),
    '9.13': dict(verify='The product-analytics switch inside Administration is behind product_analytics_settings_v0 (default off, hidden); the other eight sections are visible.'),
    '9.22': dict(verify='The mobile-app QR section is behind mobile_download_v0 (migration 0225, botiverse first).'),
}
for _row in [r for _, _, _rows in SECTIONS for r in _rows]:
    if _row.num in MARKS:
        _m = MARKS.pop(_row.num)
        _row.excl, _row.verify = _m.get('excl', _row.excl), _m.get('verify', _row.verify)
assert not MARKS, f'unknown rows in MARKS: {sorted(MARKS)}'


EXCLUDED = [
    ('pages/PaletteAuditPage.tsx (/palette-audit)', 'dev-only', 'App.tsx PaletteAuditRoute redirects to / unless import.meta.env.DEV'),
    ('pages/AccountBootstrapPreviewPage.tsx (/dev/account-bootstrap)', 'dev-only', 'App.tsx: Navigate to / unless import.meta.env.DEV'),
    ('pages/ServerSetupComputerRuntimePreviewPage.tsx (/dev/server-setup)', 'dev-only', 'App.tsx: Navigate to / unless import.meta.env.DEV'),
    ('components/dev/DraggableDevOverlay.tsx, App.tsx dev overlay', 'dev-only', 'raftdev tooling overlay'),
    ('components/workspace/WorkspaceGridDemo.tsx (/workspace-grid-demo)', 'superseded',
     'MainLayout.tsx route WORKSPACE_GRID_DEMO_ROUTE renders LegacyWorkspaceGridRedirect; the real workspace mode is 2.21'),
    ('components/window/ThreadWindowRoute.tsx (/thread-window)', 'obsolete',
     'App.tsx comment: in-app entry points removed 2026-09-10 by product call; route kept only for later re-exposure'),
    ('/inbox and /threads', 'superseded', 'MainLayout.tsx routes render LegacyThreadsRedirect to Activity'),
]

REASONS = ('obsolete', 'flag-off', 'host-only', 'browser-only', 'dev-only', 'duplicate', 'superseded')
PRIO_LABEL = {1: 'P1 daily path', 2: 'P2 common', 3: 'P3 rare / admin / edge'}


# ---------------------------------------------------------------- derived data
def all_rows():
    return [r for _, _, rows in SECTIONS for r in rows]


def suffix_free(case_id):
    return case_id.rsplit('.', 1)[0] if case_id.rsplit('.', 1)[-1] in ('brutal', 'elegant', 'elegant-dark') else case_id


def brutal_cases(manifest):
    """-> [(suffix-free id, viewport width)] of the default theme."""
    return [(suffix_free(c['id']), c['viewport']['width']) for c in manifest['cases'] if c['theme'] == 'brutal-light']


def matching(patterns, cases):
    """Cases matching any positive glob and no `!`-prefixed glob."""
    pos = [g for g in patterns if not g.startswith('!')]
    neg = [g[1:] for g in patterns if g.startswith('!')]
    return [(i, w) for i, w in cases
            if any(fnmatch.fnmatchcase(i, g) for g in pos) and not any(fnmatch.fnmatchcase(i, g) for g in neg)]


class Context:
    """The case ids that exist: default-theme extension cases [(suffix-free id, viewport width)], the official ids
    (None = unknown, official globs then count as existing) and the suffix-free ids flagged noFlutterSurface."""

    def __init__(self, cases, official=None, web_only=()):
        self.cases = list(cases)
        self.official = official
        self.web_only = frozenset(web_only)

    def hits(self, kind, glob, negations):
        """Existing case ids matched by one expected glob."""
        if kind == 'official':
            return ['?'] if self.official is None else fnmatch.filter(self.official, glob)
        return [i for i, _ in matching([glob, *['!' + n for n in negations]], self.cases)]

    def state(self, row, platform):
        if platform not in row.ap:
            return 'n/a'
        if row.excl:
            return 'excluded'
        groups = row.groups(platform)
        found = [self.hits(*g) for g in groups]
        live = [h for h in found if h]
        if not live:
            return 'MISSING'
        if len(live) < len(groups):
            return 'partial'
        ids = {i for h in live for i in h}
        if ids and ids <= self.web_only:
            return 'web-only'
        mark = row.d_state if platform == 'D' else row.p_state
        return 'partial' if mark == 'partial' else 'ok'


_DEFAULT = None


def default_context():
    """Context of the current tree: builds the extension manifest once, reads the official ids and the Flutter case map."""
    global _DEFAULT
    if _DEFAULT is None:
        _DEFAULT = Context(build_cases(), official_ids(), flutter_web_only())
    return _DEFAULT


def flutter_web_only(case_map=None):
    """Suffix-free default-theme ids the Flutter case map flags noFlutterSurface (empty without a map)."""
    path = pathlib.Path(case_map) if case_map else CASE_MAP
    if not path.is_file():
        return set()
    data = json.loads(path.read_text())
    return {suffix_free(i) for i, v in data.items() if v.get('status') == 'noFlutterSurface' and i.endswith('.brutal')}


def ext_globs():
    return sorted({g for r in all_rows() for g in (*r.d, *r.p)})


def official_globs():
    return sorted({g for r in all_rows() for g in r.off})


def counts(ctx=None):
    ctx = ctx or default_context()
    out = {'rows': 0, 'all_rows': 0, 'excluded': {}, 'verify': 0}
    for plat in 'DP':
        out[plat] = {'applicable': 0, 'ok': 0, 'partial': 0, 'web-only': 0, 'MISSING': 0}
    out['rows_missing'] = out['rows_partial'] = out['rows_full'] = 0
    for r in all_rows():
        out['all_rows'] += 1
        if r.excl:
            out['excluded'][r.excl[0]] = out['excluded'].get(r.excl[0], 0) + 1
            continue
        out['rows'] += 1
        out['verify'] += bool(r.verify)
        states = [r.state(p, ctx) for p in 'DP' if p in r.ap]
        for plat in 'DP':
            s = r.state(plat, ctx)
            if s != 'n/a':
                out[plat]['applicable'] += 1
                out[plat][s] += 1
        if 'MISSING' in states:
            out['rows_missing'] += 1
        elif any(s in ('partial', 'web-only') for s in states):
            out['rows_partial'] += 1
        else:
            out['rows_full'] += 1
    return out


def excluded_rows():
    return [r for r in all_rows() if r.excl]


def verify_rows():
    return [r for r in all_rows() if r.verify and not r.excl]


def missing_rows(ctx=None):
    """Rows with a MISSING platform, most visible first (priority, then rows not flagged verify, then both platforms,
    then document order). Excluded rows are not ranked."""
    ctx = ctx or default_context()
    rows = [(i, r) for i, r in enumerate(all_rows()) if not r.excl and 'MISSING' in [r.state(p, ctx) for p in 'DP']]
    rows.sort(key=lambda ir: (ir[1].prio, bool(ir[1].verify), -sum(ir[1].state(p, ctx) == 'MISSING' for p in 'DP'), ir[0]))
    return [r for _, r in rows]


def code(items):
    return '<br>'.join(f'`{i}`' for i in items)


def render(ctx=None):
    ctx = ctx or default_context()
    c = counts(ctx)
    miss = missing_rows(ctx)
    L = []
    a = L.append
    a('# Web page inventory vs Flutter parity coverage')
    a('')
    a('Generated on demand by `tool/parity-ext/inventory.py --write <path>` (not committed). The rows are the data in that')
    a('file (Web page metadata, expected case ids per platform, excluded / verify marks); every status below is computed from')
    a('the case ids that exist in the built manifests and from the Flutter `noFlutterSurface` flags, so adding cases for a')
    a('listed page changes nothing in the source. Web source: the pinned raft-source checkout,')
    a('`packages/web/src` (routes in `App.tsx` and `components/layout/MainLayout.tsx`, tabs in')
    a('`components/settings/settingsNavigation.ts`, agent tabs in `components/agent/AgentDetailPanel.tsx`).')
    a('')
    a('## Owner decision (2026-10-11)')
    a('')
    a('The main problem is missing pages. The default theme (brutal-light) must cover ALL pages; the other themes')
    a('(elegant-light, elegant-dark) get one or two cases per surface for a simple alignment check. The runner')
    a('implements the sampling (`tool/parity-ext/sampling.py`, docs/parity.md "Theme sampling"). This inventory is the')
    a('list of pages that default-theme coverage must reach.')
    a('')
    a('## How to read it')
    a('')
    a('- One row per user-facing page, panel, modal, drawer, sheet, popover or empty / error state family worth a screen.')
    a('  Dev-only routes are excluded (end of the document); pages the Web source shows to nobody are marked `excluded`.')
    a('- **D** = desktop (extension suite, 1280 wide, brutal-light). **P** = phone (390 wide): the official suite')
    a('  (`tool/parity`, 99 cases, phone only) or an extension case with a `.mobile` / 390 viewport.')
    a('- Cell values (computed): `ok` every expected id of the row has a case; `partial` only some of the expected ids have')
    a('  a case, or the row is marked as covering fewer states than the page has; `web-only` cases exist but all are flagged')
    a('  `noFlutterSurface` (the Flutter app has no surface to capture); `MISSING` no expected id has a case; `n/a` the surface')
    a('  does not exist on that platform; `excluded` dead / obsolete / not shown to')
    a('  normal users (reason and evidence in "Excluded pages"): it drops out of the counts and the ranking.')
    a('- Extension ids are shown without the theme suffix (`.brutal` = brutal-light; the other two themes only exist for')
    a('  the sampled surfaces) and may be globs. "Coverage" means a case exists, not that Flutter passes it.')
    a('- Priority of a missing page by user visibility: **P1** daily path (every session), **P2** common secondary or')
    a('  first-run, **P3** rare, admin-only, flag-gated or edge state.')
    a('')
    a('## Summary')
    a('')
    ex = c['excluded']
    ex_routes = {}
    for _, reason, _ in EXCLUDED:
        ex_routes[reason] = ex_routes.get(reason, 0) + 1
    a(f"- Pages (rows) in the inventory: **{c['all_rows']}** in {len(SECTIONS)} areas, of which **{sum(ex.values())}** are excluded as dead,")
    a(f"  obsolete or not shown to normal users (below), leaving **{c['rows']}** pages that count. {len(EXCLUDED)} dev-only / entry-less")
    a(f"  routes are excluded on top (end of the document). {c['verify']} counted pages are flagged \"verify\" (reachability unclear).")
    a(f"- Fully covered on every platform they exist on: **{c['rows_full']}**; partly covered (partial / web-only): **{c['rows_partial']}**;"
      f" with at least one MISSING platform: **{c['rows_missing']}**.")
    a('')
    a('| platform | pages that exist there | ok | partial | web-only | MISSING |')
    a('| --- | --- | --- | --- | --- | --- |')
    a(f"| Desktop (D) | {c['D']['applicable']} | {c['D']['ok']} | {c['D']['partial']} | {c['D']['web-only']} | {c['D']['MISSING']} |")
    a(f"| Phone (P) | {c['P']['applicable']} | {c['P']['ok']} | {c['P']['partial']} | {c['P']['web-only']} | {c['P']['MISSING']} |")
    a('')
    a('Excluded pages by reason (rows / extra routes):')
    a('')
    a('| reason | rows | routes | meaning |')
    a('| --- | --- | --- | --- |')
    meaning = {
        'obsolete': 'no entry point, or reachable only for legacy data, or no production importer',
        'flag-off': 'exists only behind a server feature flag seeded default-off (staged / allowlist / preview)',
        'host-only': 'needs the Electron desktop shell bridge; not shown in a browser or a native client',
        'browser-only': 'a Web page that only exists in the browser; the Flutter app has no route or feature for it',
        'dev-only': 'development tooling, redirected away in production',
        'duplicate': 'the same screen as another row',
        'superseded': 'replaced by a newer page; only a redirect remains',
    }
    for reason in REASONS:
        a(f"| {reason} | {ex.get(reason, 0)} | {ex_routes.get(reason, 0)} | {meaning[reason]} |")
    a('')
    a('Findings:')
    a('')
    a('- The official suite covers phone only, so every desktop page depends on the extension suite; the extension')
    a('  suite is concentrated on Settings, Auth, Thread and Shell components and has almost no composed desktop screens.')
    a(f"- {c['D']['MISSING']} desktop and {c['P']['MISSING']} phone page-platforms have no case.")
    a('')
    a('## Prioritized missing pages')
    a('')
    a('Ordered by priority, then pages not flagged "verify" first, then missing on both platforms, then area order. "Where" names the platform(s) without a case; "verify" marks pages whose reachability is unclear (section "Verify").')
    a('')
    a('| rank | # | page | where | priority |')
    a('| --- | --- | --- | --- | --- |')
    for n, r in enumerate(miss, 1):
        where = '+'.join(p for p in 'DP' if r.state(p, ctx) == 'MISSING')
        a(f"| {n} | {r.num} | {r.name}{' (verify)' if r.verify else ''} | {where} | {PRIO_LABEL[r.prio]} |")
    a('')
    for title, intro, rows in SECTIONS:
        a(f'## {title}')
        a('')
        a(f'Web: {intro}.')
        a('')
        a('| # | page / state | Web component | D | P | official (phone) ids | extension ids (brutal-light) | note |')
        a('| --- | --- | --- | --- | --- | --- | --- | --- |')
        for r in rows:
            ext = []
            if r.d:
                ext.append('D: ' + code(r.d))
            if r.p:
                ext.append('P: ' + code(r.p))
            note = r.note
            if r.excl:
                note = (note + ' ' if note else '') + f'[excluded: {r.excl[0]}]'
            if r.verify and not r.excl:
                note = (note + ' ' if note else '') + '[verify]'
            if 'MISSING' in (r.state('D', ctx), r.state('P', ctx)):
                note = (note + ' ' if note else '') + f'[{PRIO_LABEL[r.prio].split()[0]}]'
            a(f"| {r.num} | {r.name} | `{r.web}` | {r.state('D', ctx)} | {r.state('P', ctx)} | {code(r.off) or ''} | {'<br>'.join(ext)} | {note} |")
        a('')
    a('## Excluded pages')
    a('')
    a('Reachability evidence comes from the pinned Web source only (the checkout is a single release commit, so there is no')
    a('git history). Rollout state of a flag is operational data, not in the source: if a flagged feature has since been')
    a('enabled for everyone, delete its `excl=` in `inventory.py` and it counts again. Every excluded page keeps its row and')
    a('number above.')
    a('')
    a('| # | page | reason | evidence |')
    a('| --- | --- | --- | --- |')
    for r in excluded_rows():
        a(f"| {r.num} | {r.name} | {r.excl[0]} | {r.excl[1]} |")
    a('')
    a('Excluded pages that still have cases (cases that can be dropped from the default run if the exclusion holds):')
    a('')
    for r in excluded_rows():
        ids = [i for i in (*r.off, *r.d, *r.p) if not i.startswith('!')]
        if ids:
            a(f"- {r.num} {r.name}: " + ', '.join(f'`{i}`' for i in ids))
    a('')
    a('## Excluded routes')
    a('')
    a('| route / file | reason | evidence |')
    a('| --- | --- | --- |')
    for name, reason, why in EXCLUDED:
        a(f'| `{name}` | {reason} | {why} |')
    a('')
    a('## Verify (kept in the counts)')
    a('')
    a('Pages whose reachability is unclear or that may not apply to a native client. They stay counted; confirm with the owner')
    a('before spending case effort.')
    a('')
    a('| # | page | what to verify |')
    a('| --- | --- | --- |')
    for r in verify_rows():
        a(f"| {r.num} | {r.name} | {r.verify} |")
    a('')
    a('## Cases no row claims')
    a('')
    a('Default-theme extension cases whose id matches no row glob, by area (`components.<area>`). A new Web page needs a')
    a('row in `tool/parity-ext/inventory.py`; cases of an already listed page are claimed through that row\'s globs.')
    a('')
    orphans = unclaimed(ctx)
    if orphans:
        a('| area | cases | example |')
        a('| --- | --- | --- |')
        for area, ids in sorted(orphans.items()):
            a(f'| `{area}` | {len(ids)} | `{ids[0]}` |')
    else:
        a('None.')
    a('')
    a('## Maintaining the rows')
    a('')
    a('1. Add or change cases through the builder pattern (docs/parity-ext-quickstart.md). Nothing here changes.')
    a('2. A new Web page (or a MISSING page whose case ids you now know) gets / completes one row in')
    a('   `tool/parity-ext/inventory.py`: `d=` / `p=` extension id globs, `off=` official id globs, `*_state=\'partial\'` only')
    a('   when the cases cover fewer states than the page has. Never write a status.')
    a('3. `python3 tool/parity-ext/inventory.py --check` (also run by the unit tests) validates the rows and globs.')
    a('')
    return '\n'.join(L).replace('\n\n\n', '\n\n')


def official_ids():
    shared = RAFT_SOURCE / 'packages/visual-testing/shared/sharedCases.json'
    if not shared.is_file():
        return None
    return [c['id'] for c in json.loads(shared.read_text())['cases']]


def build_cases():
    sys.path.insert(0, str(HERE))
    import builders
    with tempfile.TemporaryDirectory() as tmp:
        manifest = json.loads(builders.build_manifest(pathlib.Path(tmp)).read_text())
    return brutal_cases(manifest)


def unclaimed(ctx=None):
    """Default-theme extension cases no row glob matches -> {components.<area>: [ids]}."""
    ctx = ctx or default_context()
    claimed = set()
    for r in all_rows():
        for platform in 'DP':
            for kind, glob, negations in r.groups(platform):
                if kind == 'ext':
                    claimed.update(ctx.hits(kind, glob, negations))
    out = {}
    for case_id, _ in ctx.cases:
        if case_id not in claimed:
            out.setdefault('.'.join(case_id.split('.')[:2]), []).append(case_id)
    return out


_GLOB = re.compile(r'^(components|screens)\.[A-Za-z0-9_.*?\[\]-]+$')
_NEGATION = re.compile(r'^![A-Za-z0-9_.*?\[\]-]+$')


def problems(ctx=None):
    """-> list of human readable problems with the rows and globs (empty = consistent).

    A glob that matches no case is NOT a problem: it is an expected id that is not built yet (the status is MISSING /
    partial). Problems are malformed globs, globs on a platform the row does not have, and globs that match a case of
    the other platform (a 390 wide case for D, anything else for P)."""
    ctx = ctx or default_context()
    out, seen = [], set()
    for r in all_rows():
        if r.num in seen:
            out.append(f'{r.num}: duplicate row number')
        seen.add(r.num)
        if r.excl and r.excl[0] not in REASONS:
            out.append(f'{r.num}: unknown excluded reason {r.excl[0]}')
        for platform, patterns in (('D', r.d), ('P', r.p)):
            if patterns and platform not in r.ap:
                out.append(f'{r.num}: extension ids given for {platform} but the row is {r.ap}')
            if patterns and not any(not g.startswith('!') for g in patterns):
                out.append(f'{r.num}: only negations for {platform}: {list(patterns)}')
            for g in patterns:
                if g.startswith('!'):
                    if not _NEGATION.match(g):
                        out.append(f'{r.num}: malformed negation: {g}')
                    continue
                if not _GLOB.match(g) or not g.startswith('components.'):
                    out.append(f'{r.num}: malformed or unknown extension id prefix: {g}')
                    continue
                hit = matching([g, *[x for x in patterns if x.startswith('!')]], ctx.cases)
                if platform == 'D' and any(w == 390 for _, w in hit):
                    out.append(f'{r.num}: desktop glob {g} matches a 390 wide (phone) case')
                elif platform == 'P' and any(w != 390 for _, w in hit):
                    out.append(f'{r.num}: phone glob {g} matches a non-390 case')
        for g in r.off:
            if not _GLOB.match(g):
                out.append(f'{r.num}: malformed or unknown official id prefix: {g}')
        if r.off and 'P' not in r.ap:
            out.append(f'{r.num}: official ids given but the row has no phone platform')
        for platform, mark in (('D', r.d_state), ('P', r.p_state)):
            if mark not in (None, 'partial'):
                out.append(f'{r.num}: unknown {platform} state mark {mark!r} (only "partial" is a mark; statuses are computed)')
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--write', metavar='PATH', help=f'write the generated document ("-" = stdout; e.g. {DEFAULT_DOC.relative_to(ROOT)})')
    ap.add_argument('--stdout', action='store_true', help='print the generated document')
    ap.add_argument('--check', action='store_true', help='validate the rows and id globs; writes nothing')
    ap.add_argument('--case-map', metavar='FILE', help='Flutter android-case-map.json (noFlutterSurface flags)')
    args = ap.parse_args(argv)
    ctx = Context(build_cases(), official_ids(), flutter_web_only(args.case_map))
    bad = problems(ctx)
    if bad:
        sys.exit('\n'.join(bad))
    if args.check:
        pending = sorted({r.num for r in all_rows() if not r.excl and any(
            g for p in 'DP' for g in r.groups(p) if not ctx.hits(*g))})
        print(f'inventory rows consistent; {len(pending)} rows list ids that have no case yet' if pending
              else 'inventory rows consistent')
        return
    text = render(ctx)
    if args.write and args.write != '-':
        out = pathlib.Path(args.write)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text)
        c = counts(ctx)
        print(f"wrote {out}: {c['rows']} pages, desktop {c['D']}, phone {c['P']}")
    else:
        sys.stdout.write(text)


if __name__ == '__main__':
    main()
