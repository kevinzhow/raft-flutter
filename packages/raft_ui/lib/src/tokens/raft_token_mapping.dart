/// The explicit old-name to raft-ui 0.7.1 token table that fills the legacy
/// [RaftSemanticColors] / [RaftProductColors] / [RaftComponentColors] /
/// [RaftThemeShadows] / [RaftThemeMetrics] schemas from [RaftLight] / [RaftDark].
///
/// Components still read the 0.5.52 names (`t.colors['layer-panel']`,
/// `t.product.brutalLime`). The design system renamed and re-valued many of
/// them, so every old name is mapped here BY MEANING, never by name alone:
///
/// * `layer-canvas` is the trap. The new `layer-canvas` is the old
///   `layer-panel` (the content paper); the old `layer-canvas` (the page under
///   the panels) has no successor. Both old names resolve to the new
///   `layer-canvas`, so pages and panels share one paper and the seams separate
///   them (dark: `#1b1b19`, one step brighter than the old `#141411` page).
/// * Renames follow [RaftDeprecatedTokenNames] (`primary-*` to `brand-*`,
///   `accent-*` to `attention-*`, `secondary-*` to `palette-stone-*`, `line` to
///   `line-seam`, `line-muted` to `line-hairline`, ...).
/// * Names with no successor are chosen by what the colour is for; see the
///   comment on each entry. `transparent` marks a role the Raft look does not
///   paint.
///
/// `test/raft_token_mapping_test.dart` fails when a field of any tier has no
/// entry here or an entry points at a token that does not exist.
library;

/// A role the Raft look does not paint (dark input insets, switch bottom shadow).
const raftTransparentToken = 'transparent';

/// A shadow role that casts nothing (raft-ui 0.7.1: controls never cast a shadow).
const raftNoShadowToken = 'none';

/// [RaftSemanticColors] CSS name to 0.7.1 token name.
const Map<String, String> raftSemanticMapping = {
  // Foreground tiers: strong/icon/placeholder collapse onto the three tiers.
  'foreground': 'foreground',
  'foreground-strong': 'foreground',
  'foreground-muted': 'foreground-muted',
  'foreground-hint': 'foreground-hint',
  'foreground-icon': 'foreground-muted',
  'foreground-placeholder': 'foreground-hint',
  'foreground-disabled': 'foreground-disabled',
  'foreground-inverse': 'foreground-inverse',
  'foreground-active': 'foreground-active',
  'foreground-hover': 'foreground-hover',
  // Layers. Both old canvas and old panel are the new content paper (see above).
  'layer-canvas': 'layer-canvas',
  'layer-canvas-muted': 'layer-sidebar',
  'layer-panel': 'layer-canvas',
  'layer-popover': 'layer-popover',
  'layer-backdrop': 'layer-backdrop',
  'layer-inset': 'fill-muted',
  'layer-card': 'layer-card',
  'layer-hud': 'layer-hud',
  'layer-hud-foreground': 'foreground-on-hud',
  'fill-muted': 'fill-muted',
  'fill-strong': 'fill-strong',
  // Lines: `line` was the region line (now the 45% seam), `line-muted` the quiet
  // one (now the 15% hairline).
  'line-strong': 'line-strong',
  'line': 'line-seam',
  'line-muted': 'line-hairline',
  'line-hairline': 'line-hairline',
  'line-field': 'line-field',
  'line-field-hover': 'line-field-hover',
  // Ink alpha ladder.
  'ink': 'ink',
  'ink-2': 'ink-2',
  'ink-4': 'ink-4',
  'ink-6': 'ink-6',
  'ink-8': 'ink-8',
  'ink-10': 'ink-10',
  'ink-16': 'ink-16',
  'ink-20': 'ink-20',
  'ink-30': 'ink-30',
  'ink-40': 'ink-40',
  // primary -> brand
  'primary-50': 'brand-50',
  'primary-100': 'brand-100',
  'primary-200': 'brand-200',
  'primary-300': 'brand-300',
  'primary-400': 'brand-400',
  'primary-500': 'brand-500',
  'primary-600': 'brand-600',
  'primary-700': 'brand-700',
  'primary-800': 'brand-800',
  'primary-900': 'brand-900',
  'primary-950': 'brand-950',
  // accent -> attention (decision 0001: the pink is lighter, `attention-400`)
  'accent-50': 'attention-50',
  'accent-100': 'attention-100',
  'accent-200': 'attention-200',
  'accent-300': 'attention-300',
  'accent-400': 'attention-400',
  'accent-500': 'attention-500',
  'accent-600': 'attention-600',
  'accent-700': 'attention-700',
  'accent-800': 'attention-800',
  'accent-900': 'attention-900',
  'accent-950': 'attention-950',
  // secondary -> palette-stone
  'secondary-50': 'palette-stone-50',
  'secondary-100': 'palette-stone-100',
  'secondary-200': 'palette-stone-200',
  'secondary-300': 'palette-stone-300',
  'secondary-400': 'palette-stone-400',
  'secondary-500': 'palette-stone-500',
  'secondary-600': 'palette-stone-600',
  'secondary-700': 'palette-stone-700',
  'secondary-800': 'palette-stone-800',
  'secondary-900': 'palette-stone-900',
  'secondary-950': 'palette-stone-950',
  // Status colours. 0.7.1 solids are the sticker colours with ink text
  // (`*-foreground` is ink); the readable text colour is `*-strong`.
  'info': 'info',
  'info-strong': 'info-strong',
  'info-muted': 'info-muted',
  'info-soft': 'info-soft',
  'success': 'success',
  'success-foreground': 'success-foreground',
  'success-strong': 'success-strong',
  'success-muted': 'success-muted',
  'success-soft': 'success-soft',
  'warning': 'warning',
  'warning-foreground': 'warning-foreground',
  'warning-strong': 'warning-strong',
  'warning-muted': 'warning-muted',
  'warning-soft': 'warning-soft',
  'danger': 'danger',
  'danger-foreground': 'danger-foreground',
  'danger-strong': 'danger-strong',
  'danger-muted': 'danger-muted',
  'danger-soft': 'danger-soft',
  'inactive': 'inactive',
  'inactive-foreground': 'inactive-foreground',
  'task-status-todo': 'task-status-todo',
  'task-status-todo-soft': 'task-status-todo-soft',
  'task-status-todo-strong': 'task-status-todo-strong',
  'task-status-in-progress': 'task-status-in-progress',
  'task-status-in-progress-soft': 'task-status-in-progress-soft',
  'task-status-in-progress-strong': 'task-status-in-progress-strong',
  'task-status-in-review': 'task-status-in-review',
  'task-status-in-review-soft': 'task-status-in-review-soft',
  'task-status-in-review-strong': 'task-status-in-review-strong',
  'task-status-done': 'task-status-done',
  'task-status-done-soft': 'task-status-done-soft',
  'task-status-done-strong': 'task-status-done-strong',
  'task-status-closed': 'task-status-closed',
  'task-status-closed-soft': 'task-status-closed-soft',
  'task-status-closed-strong': 'task-status-closed-strong',
  // Family slots (strong/soft/edge/glow and the interaction colours).
  'primary-strong': 'brand-strong',
  'primary-soft': 'brand-soft',
  'primary-edge': 'brand-edge',
  'primary-glow': 'brand-glow',
  'accent-strong': 'attention-strong',
  'accent-soft': 'attention-soft',
  'primary-hover': 'brand-hover',
  'primary-active': 'brand-active',
  'accent-hover': 'attention-hover',
  'accent-active': 'attention-active',
  'info-hover': 'info-hover',
  'info-active': 'info-active',
  'warning-hover': 'warning-hover',
  'warning-active': 'warning-active',
  'danger-hover': 'danger-hover',
  'danger-active': 'danger-active',
};

/// [RaftProductColors] CSS name to 0.7.1 token name. The `brutal-*` hue aliases
/// were the Brutal sticker colours; they map to the token that carries the same
/// role (and the same bytes) in the Raft look.
const Map<String, String> raftProductMapping = {
  'color-brutal-yellow': 'brand-400',
  'color-soft-signal': 'brand-400',
  'color-brutal-lavender': 'palette-lavender-400',
  // The attention pink: decision 0001 lightens it to `attention-400` (#ff99c3);
  // the old #fe7da8 is `attention-500` now.
  'color-brutal-pink': 'attention-400',
  'color-brutal-cyan': 'info',
  'color-brutal-orange': 'warning',
  'color-brutal-lime': 'success',
  'color-brutal-red': 'danger',
  'color-brutal-stone': 'palette-stone-400',
  'color-brutal-cream': 'palette-cream-200',
  'color-status-busy': 'presence-busy',
  'color-brutal-black': 'sticker-ink',
  'color-code-surface': 'layer-code',
  // 0.7.1 has no code-foreground token; the body ink is the closest role.
  'color-code-foreground': 'foreground',
};

/// [RaftComponentColors] CSS name to 0.7.1 token name.
const Map<String, String> raftComponentMapping = {
  'primary': 'brand-400',
  'accent': 'attention-400',
  'brutal-cream': 'palette-cream-200',
  // Default (ink) button: the fill is the ink; 0.7.1 hover is an overlay, not a
  // new fill, so the hover colour is the ink's own hover token.
  'button-default-fill': 'ink',
  'button-default-hover': 'foreground-hover',
  'button-primary-hover': 'brand-hover',
  'button-accent-hover': 'attention-hover',
  // The edge of a sticker button is the sticker ink.
  'button-accent-edge': 'sticker-ink',
  'button-danger-fill': 'danger',
  'button-danger-hover': 'danger-hover',
  'button-danger-foreground': 'danger-foreground',
  // High-contrast destructive: the readable `danger-strong` with inverse text.
  'button-danger-high-contrast': 'danger-strong',
  'button-danger-high-contrast-foreground': 'foreground-inverse',
  'task-section-fill': 'fill-muted',
  'code-border': 'line-seam',
  // Dark inputs: a hairline ring, no inset highlight or shadow.
  'field-inset-line': 'line-hairline',
  'field-inset-top': raftTransparentToken,
  'field-inset-bottom': raftTransparentToken,
  // Stickers do not invert: the thumb is the sticker paper in both modes.
  'switch-thumb': 'sticker-paper',
  'switch-thumb-checked': 'sticker-paper',
  'switch-thumb-disabled': 'fill-strong',
  'switch-thumb-checked-disabled': 'fill-strong',
  'switch-shadow-bottom': raftTransparentToken,
};

/// [RaftThemeShadows] CSS name to a 0.7.1 shadow token, or [raftNoShadowToken].
/// Controls never cast a shadow; `lg` and `xl` were the overlay shadows.
const Map<String, String> raftShadowMapping = {
  'theme-shadow-xs': raftNoShadowToken,
  'theme-shadow-sm': raftNoShadowToken,
  'theme-shadow-md': raftNoShadowToken,
  'theme-shadow-lg': 'elevation-float',
  'theme-shadow-xl': 'elevation-float',
};

/// [RaftThemeMetrics] numeric field to its 0.7.1 metric token (`field-*`,
/// `card-title-*`).
///
/// [RaftTokenSet] carries [raftCarriedMetrics]: the `field-*` tokens (16/24/400) are applied with the ported
/// Input; the card title (16/24/600 in 0.7.1) still carries the Elegant 16/22/500 its structure is dimensioned for.
const Map<String, String> raftMetricMapping = {
  'fieldFontSize': 'field-font-size',
  'fieldFontWeight': 'field-font-weight',
  'fieldLineHeight': 'field-line-height',
  'cardTitleFontSize': 'card-title-font-size',
  'cardTitleFontWeight': 'card-title-font-weight',
  'cardTitleLineHeight': 'card-title-line-height',
};

/// The metric values [RaftTokenSet] uses until the structure follows the
/// tokens (see [raftMetricMapping]). The field metrics are the 0.7.1 `field-*` tokens (16/24/400: the ported
/// Input, the Material-hosted fields and the field recipes); the card title still carries Elegant's 16/22/500.
const Map<String, double> raftCarriedMetrics = {
  'fieldFontSize': 16,
  'fieldFontWeight': 400,
  'fieldLineHeight': 24,
  'cardTitleFontSize': 16,
  'cardTitleFontWeight': 500,
  'cardTitleLineHeight': 22,
};
