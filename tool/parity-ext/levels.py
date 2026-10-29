"""Visual-suite levels (owner scope 2026-10-24): the three-level regression structure.

  frame      L1  app frame / shell chrome: window, top bar, rail, sidebar, mobile tab bar, panel layout,
                 channel header (the strip every page sits under)
  page       L2  every main page / route as a whole-page (or whole content column) capture
  component  L3  reusable pieces: the official component cases and the extension dialogs, menus, rows, cards

`level_of(case)` works for official ids (sharedCases.json) and extension ids (build-*.py manifests).
The table below is the one place that assigns a surface (`components.<area>.<surface>`, first three id
segments) to a level; a surface not listed falls back to `component` and is reported by `unassigned()`
so a new builder cannot silently escape the structure (tool/parity-ext/regress.py prints them).
"""
import fnmatch

FRAME, PAGE, COMPONENT = 'frame', 'page', 'component'
LEVELS = (FRAME, PAGE, COMPONENT)

# --- official ids (tool/parity, packages/visual-testing/shared/sharedCases.json) ---------------------------------
OFFICIAL_FRAME = (
    'components.navigation.tabbar.states',  # phone tab bar
    'components.home.titlebar.states',      # phone home title bar (server switcher + bell)
    'components.thread.header.states',      # channel / DM header strip
    'components.home.server-switcher.open',
)
OFFICIAL_PAGE_GLOBS = (
    'screens.*',
    'components.settings.*.page',
    'components.settings.root.page',
    'components.settings.account.error-state',
    'components.settings.server.profile',
    'components.members.agent-detail.profile',
    'components.home.activity.results',
    'components.home.saved.results',
    'components.home.search.results',
    'components.tasks.panel.states',
    'components.thread.files.list',
)

# --- extension surfaces (first three id segments) -----------------------------------------------------------------
EXT_SURFACE_LEVEL = {
    # L1 frame (the shell family's menus, dialogs and primitives are L3: see SHELL_FRAME)
    'components.shell.desktop': COMPONENT,
    'components.shell.mobile': COMPONENT,
    'components.channelheader.desktop': FRAME,
    'components.channelheader.mobile': FRAME,
    # L2 pages
    'components.screens-ext.channel': PAGE, 'components.screens-ext.dm': PAGE,
    'components.screens-ext.composer': PAGE, 'components.screens-ext.activity': PAGE,
    'components.ext-settings.nav': PAGE, 'components.ext-settings.about': PAGE,
    'components.ext-settings.release-notes': PAGE, 'components.ext-settings.feedback': PAGE,
    'components.ext-settings.server': PAGE, 'components.ext-settings.billing': PAGE,
    'components.ext-settings.administration': PAGE, 'components.ext-settings.integrations': PAGE,
    'components.ext-settings.mcp': PAGE, 'components.ext-settings.labs': PAGE,
    'components.ext-settings.providers': PAGE, 'components.ext-settings.im-bridges': PAGE,
    'components.ext-settings.account': PAGE, 'components.ext-settings.appearance': PAGE,
    'components.ext-settings.notifications': PAGE,
    'components.wp6.settings': PAGE, 'components.wp6.tasks': PAGE,
    'components.members-ext.list': PAGE, 'components.members-ext.human': PAGE, 'components.members-ext.agent': PAGE,
    'components.members-ext.activity': PAGE, 'components.members-ext.saved': PAGE,
    'components.members-pages.desktop': PAGE, 'components.members-pages.phone': PAGE,
    'components.list-pages.search': PAGE, 'components.list-pages.activity': PAGE, 'components.list-pages.saved': PAGE,
    'components.list-pages.tasks': PAGE, 'components.list-pages.computers': PAGE, 'components.list-pages.members': PAGE,
    'components.computers.list': PAGE, 'components.computers.detail': PAGE,
    'components.taskspage.desktop': PAGE, 'components.taskspage.mobile': PAGE,
    'components.taskdetail.desktop': PAGE, 'components.taskdetail.mobile': PAGE,
    'components.raftbench.page': PAGE,
    'components.channelsettings.desktop': PAGE, 'components.channelsettings.mobile': PAGE,
    'components.auth-ext.desktop': PAGE, 'components.auth-ext.mobile': PAGE,
    'components.auth-pages.desktop': PAGE, 'components.auth-pages.mobile': PAGE,
    'components.public-server.desktop': PAGE, 'components.public-server.mobile': PAGE,
    'components.forward-mobile.page': PAGE,
    'components.conversation.empty': PAGE,
    # L3 components (everything else listed explicitly so unassigned() is meaningful)
    'components.computers.add-dialog': COMPONENT, 'components.computers.dialog': COMPONENT,
    'components.announcements.desktop': COMPONENT, 'components.announcements.mobile': COMPONENT,
    'components.composerattachments.desktop': COMPONENT, 'components.composerattachments.mobile': COMPONENT,
    'components.dialogs.desktop': COMPONENT,
    'components.list-pages.notification': COMPONENT, 'components.list-pages.dialogs': COMPONENT,
    'components.list-pages.create-channel': COMPONENT,
    'components.members-ext.invite': COMPONENT,
    'components.notifications.desktop': COMPONENT,
    'components.row-menus.mobile': COMPONENT, 'components.row-menus.desktop': COMPONENT,
    'components.attachment.viewer': COMPONENT,
    'components.thread-pill.top': COMPONENT, 'components.thread-pill.bottom': COMPONENT,
}
# Area-wide defaults for the many small surfaces of the conversation / thread / composer / errors families.
EXT_AREA_LEVEL = {
    'conversation': COMPONENT, 'thread-ext': COMPONENT, 'composer-states': COMPONENT, 'errors': COMPONENT,
    'search-overlay': COMPONENT, 'composerattachments': COMPONENT,
    # the coverage families added by this audit name their level in the id: components.<area>.<level>.<...>
    'frame': FRAME, 'framework': FRAME, 'pages': PAGE, 'states': FRAME,
}


# Shell-family cases that are the frame itself (rail + sidebar in their states, the Activity column edge).
SHELL_FRAME = (
    'components.shell.*.sidebar.default.*', 'components.shell.*.sidebar.empty.*', 'components.shell.*.sidebar.loading.*',
    'components.shell.*.sidebar.custom.*', 'components.shell.*.sidebar.sorted.*', 'components.shell.*.sidebar.collapsed.*',
    'components.shell.*.sidebar.row-hover.*', 'components.shell.*.activity.frame.*',
)


STATES_PAGE_CONTROLS = ('composer-', 'activity-', 'settings-', 'list-')


def surface_of(case_id):
    return '.'.join(case_id.split('.')[:3])


def level_of(case_id):
    if case_id.startswith('screens.'):
        return PAGE
    if case_id in OFFICIAL_FRAME:
        return FRAME
    if any(fnmatch.fnmatchcase(case_id, g) for g in OFFICIAL_PAGE_GLOBS):
        return PAGE
    parts = case_id.split('.')
    if case_id.startswith('components.states.'):
        # control states: the frame's controls are L1, the composer's (and any later page control) L2
        return PAGE if parts[3].startswith(STATES_PAGE_CONTROLS) else FRAME
    if any(fnmatch.fnmatchcase(case_id, g) for g in SHELL_FRAME):
        return FRAME
    surface = surface_of(case_id)
    if surface in EXT_SURFACE_LEVEL:
        return EXT_SURFACE_LEVEL[surface]
    if len(parts) > 1 and parts[1] in EXT_AREA_LEVEL:
        return EXT_AREA_LEVEL[parts[1]]
    return COMPONENT


def is_assigned(case_id):
    """True when the level comes from an explicit rule (not the component fallback)."""
    parts = case_id.split('.')
    return (case_id.startswith('screens.') or case_id in OFFICIAL_FRAME
            or any(fnmatch.fnmatchcase(case_id, g) for g in OFFICIAL_PAGE_GLOBS)
            or surface_of(case_id) in EXT_SURFACE_LEVEL
            or (len(parts) > 1 and parts[1] in EXT_AREA_LEVEL)
            or case_id.startswith('components.') and not _is_extension(case_id))


def _is_extension(case_id):
    return case_id.split('.')[1] in {
        'computers', 'ext-settings', 'announcements', 'auth-ext', 'auth-pages', 'channelheader', 'channelsettings',
        'composerattachments', 'composer-states', 'conversation', 'dialogs', 'errors', 'forward-mobile', 'list-pages',
        'members-ext', 'members-pages', 'notifications', 'public-server', 'raftbench', 'row-menus', 'screens-ext',
        'search-overlay', 'shell', 'taskspage', 'taskdetail', 'thread-ext', 'thread-pill', 'attachment', 'wp6',
        'frame', 'framework', 'states'}


def unassigned(case_ids):
    """Extension surfaces that fall back to `component` without an explicit rule."""
    return sorted({surface_of(i) for i in case_ids if _is_extension(i) and not is_assigned(i)})


MODE_OF_THEME = {'brutal-light': 'light', 'elegant-light': 'light', 'elegant-dark': 'dark'}

# Key L2 pages of the nightly fast subset (`regress --fast`): the new whole-page cases of this audit plus the
# official real-screen cases. Phone and desktop widths, light mode (regress.py applies the width / mode filter).
FAST_PAGES = (
    'components.pages.*',
    'screens.*',
    'components.screens-ext.channel.*',
    'components.screens-ext.dm.*',
    'components.settings.*.page',
)


def is_fast_page(case_id):
    return any(fnmatch.fnmatchcase(case_id, g) for g in FAST_PAGES)
