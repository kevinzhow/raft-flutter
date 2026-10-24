"""Page-level theme tokens (the "pages" lane of the Web v1.21.23 alignment).

One file so the page work adds its tokens without touching the shared tables:
build_raft_pack.py and build_family_packs.py each call into it from a few lines.
Raft values follow the Web v1.21.23 render; the Elegant / Brutal columns keep
the pre-theme (a57b9dab) value of the same token, so those looks do not move.

Every entry says where the number comes from. Nothing here branches on a theme
name: a token has one value per pack, a component reads the token.
"""

from __future__ import annotations

# ---------------------------------------------------------------- geometry
# token: (Raft, Elegant and Brutal)
_GEOMETRY = {
    # AuthBrandShell top bar: `h-panel-header` (56) in the Raft look; a57b9dab
    # fell back to 62 in every look (the auth pages sit outside the app shell).
    'size.authBar': (56, 62),
    # AuthBrandIntro: h1 `text-title` (22/28), description `text-subhead` (15/20);
    # a57b9dab: `text-xl` 20/28 and `text-sm` 14/20.
    'type.authTitle.size': (22, 20), 'type.authTitle.line': (28, 28),
    'type.authDescription.size': (15, 14), 'type.authDescription.line': (20, 20),
    # Legal notice under the auth forms: `text-caption` 12/16 (v1.21.23) vs the
    # `leading-5` 20px line of a57b9dab.
    'type.authLegal.line': (16, 20),
    # Standalone splash / not-found page label: `text-headline` 17/22 (App.tsx
    # AuthBootstrapStatus); a57b9dab drew it 20/28.
    'type.splash.size': (17, 20), 'type.splash.line': (22, 28),
    # ServerAccessDeniedPage: h1 `text-title` 22/28, paragraph `text-callout`
    # 14/20; a57b9dab drew 24/32 and a 24px line.
    'type.notFoundTitle.size': (22, 24), 'type.notFoundTitle.line': (28, 32),
    'type.notFoundBody.line': (20, 24),
    # TasksPanelViewport `px-5 py-4` (max-md `px-4`); a57b9dab used 16 all round.
    'space.tasksViewportInline': (20, 16),
    # OnboardingCreateDotPane halftone: 1.5px dots on a 14px grid at 70% opacity
    # (v1.21.23) / 1px dots on a 16px grid at 60% (a57b9dab).
    'size.onboardingDotGrid': (14, 16), 'size.onboardingDotRadius': (1.5, 1),
    'opacity.onboardingDots': (0.7, 0.6),
    # InputGroup text addon: `font-mono text-mono-code` 13/20 (0.7.0); the
    # a57b9dab addon was 16/24 bold.
    'type.inputAddon.size': (13, 16), 'type.inputAddon.line': (20, 24),
    'type.inputAddon.weight': (400, 700),
    # SectionEyebrow: `text-footnote font-bold` (13/18); a57b9dab: 12/16.
    'type.sectionEyebrow.size': (13, 12), 'type.sectionEyebrow.line': (18, 16),
}

# ---------------------------------------------------------------- options
_OPTIONS = {
    # How wide the auth submit buttons are drawn: Web v1.21.23 LoginPage /
    # RegisterPage use `size="xl"`, a57b9dab used `lg`.
    'auth.submitSize': ('xl', 'lg'),
    # TextLink (v1.21.23): ink text with a permanent 1.5px underline 3px below
    # the baseline; a57b9dab: coloured, underlined on hover only.
    'auth.links': ('underlined', 'hover'),
    # Standalone pages (bootstrap splash, server not found, ...): the page
    # surface is `bg-layer-sidebar` in v1.21.23, the canvas in a57b9dab.
    'standalone.surface': ('sidebar', 'canvas'),
    # Field label of the auth forms: the raft-ui Field label (13/18 600
    # `foreground-field-label`, 6px to the control, `type.fieldLabel.*` /
    # `space.fieldGap`) in v1.21.23; a57b9dab drew the recipe label with a 4px gap.
    'auth.fieldLabel': ('tokens', 'recipe'),
    # Public server page columns: the shared mounted Sidebar frame (v1.21.23
    # builds them from the same SidebarRoot / SidebarHeader) or the page's own
    # column of a57b9dab.
    'publicServer.sidebar': ('shared', 'legacy'),
    # Bottom banner at sm and up: copy over the action row (v1.21.23 grid) or
    # copy and actions on one row (a57b9dab).
    'publicServer.banner': ('stacked', 'row'),
    # Channel header icon of the public page: the yellow location sticker
    # (`iconTone="location"`, v1.21.23) or the neutral tile (a57b9dab).
    'publicServer.channelTile': ('sticker', 'plain'),
    # ConversationPanelTabs (agent / channel / human panels): the yellow sticker
    # row (0.7.0 default TabsList) or the underline row (a57b9dab).
    'panelTabs.style': ('sticker', 'underline'),
    # Agent Workspace tab: v1.21.23 (canvas surfaces, seam rules, mono 13/20
    # rows, info-soft selection, hint / muted callout states) or a57b9dab's.
    'agentWorkspace.look': ('web23', 'legacy'),
    # Icon tile at the left of a page head (Tasks, Saved, Activity, Settings, ...):
    # v1.21.23 passes no icon, a57b9dab drew the 27 / 36px tile.
    'pageHeader.icon': ('none', 'tile'),
    # Tasks board lane: flat 232px column (raft-ui 0.7.0 taskBoardColumn) or the
    # bordered 320px lane card of a57b9dab.
    'taskBoard.column': ('flat', 'card'),
    # Task modal head: facts row then History (TaskProperties, v1.21.23) or the
    # a57b9dab order with the 11px terms.
    'taskModal.head': ('web23', 'legacy'),
    # EmptyState: bare 36px hint icon + headline title (0.7.0) or the recipe tile
    # of a57b9dab.
    'emptyState.look': ('plain', 'recipe'),
    # Skeleton fill: `bg-fill-muted rounded-sticker` (0.7.0) or the ink wash.
    'skeleton.look': ('fill', 'ink'),
    # Activity / Saved loading cards: edge to edge rounded cards (v1.21.23) or
    # the 16px-inset square cards of a57b9dab.
    'activity.loadingCards': ('edge', 'inset'),
    # Search page failure: a warning Banner with a Retry button (v1.21.23) or
    # the bordered card of a57b9dab.
    'search.failure': ('banner', 'card'),
    # Appearance page: Light / Dark / System preview cards first, the look
    # picker and the app icon (product additions) after the Web sections, or
    # the a57b9dab page.
    'appearance.layout': ('web23', 'legacy'),
    # FormSection heading and description (0.7.0): footnote bold muted title and
    # footnote hint description, or the call sites' own a57b9dab text steps.
    'formSection.look': ('web23', 'legacy'),
    # FormField label of the product forms (dialogs, settings): the raft-ui
    # Field label of v1.21.23 or the recipe label with `mb-1` of a57b9dab.
    'formField.label': ('tokens', 'recipe'),
    # Root error fallback: the DS dialog card with code boxes (v1.21.23) or the
    # a57b9dab card.
    'rootError.look': ('web23', 'legacy'),
    # First-server onboarding heading: mono 12 eyebrow, title / display, subhead
    # (v1.21.23) or the 10px eyebrow, 24/30 title, 14/20 text of a57b9dab.
    'onboarding.heading': ('web23', 'legacy'),
    # Onboarding preview cards: rounded 1.5px line-strong cards (v1.21.23) or
    # the square 2px black boxes of a57b9dab.
    'onboarding.preview': ('sticker', 'brutal'),
    # The one button of the not-found page: `size="lg"` (44) in v1.21.23.
    'standalone.buttonSize': ('lg', 'md'),
}

# Allowed values per option, merged into raftStructuralOptions (theme_pack.dart).
OPTION_VALUES = {
    'auth.submitSize': ('xl', 'lg'),
    'auth.links': ('underlined', 'hover'),
    'standalone.surface': ('sidebar', 'canvas'),
    'standalone.buttonSize': ('lg', 'md'),
    'auth.fieldLabel': ('tokens', 'recipe'),
    'publicServer.sidebar': ('shared', 'legacy'),
    'publicServer.banner': ('stacked', 'row'),
    'publicServer.channelTile': ('sticker', 'plain'),
    'panelTabs.style': ('sticker', 'underline'),
    'agentWorkspace.look': ('web23', 'legacy'),
    'pageHeader.icon': ('none', 'tile'),
    'taskBoard.column': ('flat', 'card'),
    'taskModal.head': ('web23', 'legacy'),
    'emptyState.look': ('plain', 'recipe'),
    'skeleton.look': ('fill', 'ink'),
    'activity.loadingCards': ('edge', 'inset'),
    'search.failure': ('banner', 'card'),
    'appearance.layout': ('web23', 'legacy'),
    'formSection.look': ('web23', 'legacy'),
    'formField.label': ('tokens', 'recipe'),
    'rootError.look': ('web23', 'legacy'),
    'onboarding.heading': ('web23', 'legacy'),
    'onboarding.preview': ('sticker', 'brutal'),
}

# ---------------------------------------------------------------- colours
# role: (Raft source role, family source role). Values are existing roles.
_COLOR_ALIASES = {
    # AUTH_BRAND_TOP_BAR_CLASS `border-line-seam` (Raft); a57b9dab hairline.
    'line-auth-header': ('line-seam', 'line-hairline'),
    # Standalone page label: `text-foreground-muted` (Raft), foreground before.
    'foreground-splash': ('foreground-muted', 'foreground-strong'),
    # SectionEyebrow tone "hint" (Raft), a57b9dab muted.
    'foreground-eyebrow': ('foreground-hint', 'foreground-muted'),
    # TextLink variant primary: ink in v1.21.23, accent-strong before.
    'foreground-text-link': ('foreground', 'accent-strong'),
    # Onboarding brand pane: the frame colour (v1.21.23), the muted canvas before.
    'layer-onboarding-pane': ('layer-frame', 'layer-canvas-muted'),
    'line-onboarding-dot': ('line-seam', 'line-strong'),
    'line-onboarding-panel': ('line-seam', 'line-hairline'),
    # InputGroup addon (`variant="container"`): `bg-fill-muted`, hint mono text
    # (0.7.0); a57b9dab: the soft-signal wash with muted bold mono.
    'layer-input-addon': ('fill-muted', 'color-soft-signal'),
    'foreground-input-addon': ('foreground-hint', 'foreground-muted'),
    # Legal links of the auth pages: `text-foreground-link` (Raft), muted before.
    'foreground-legal-link': ('foreground-link', 'foreground-muted'),
}


def geometry_raft() -> dict:
    return {k: v[0] for k, v in _GEOMETRY.items()}


def geometry_family() -> dict:
    return {k: v[1] for k, v in _GEOMETRY.items()}


def options_raft() -> dict:
    return {k: v[0] for k, v in _OPTIONS.items()}


def options_family() -> dict:
    return {k: v[1] for k, v in _OPTIONS.items()}


def raft_aliases(colors: dict) -> None:
    for role, (raft, _) in _COLOR_ALIASES.items():
        colors[role] = colors[raft]


def family_aliases(colors: dict) -> None:
    for role, (_, family) in _COLOR_ALIASES.items():
        colors[role] = colors[family]
