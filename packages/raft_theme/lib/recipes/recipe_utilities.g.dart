// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Tailwind utility table.
// ignore_for_file: type=lint

import 'dart:ui' show Color;

import 'recipe_runtime.dart';

/// Every class used by a raft-ui recipe, compiled by Tailwind v4 into
/// cascade layers (index = class id used by the recipe tables).
const List<RaftUtility> raftRecipeUtilities = <RaftUtility>[
  RaftUtility(
    '**:data-[activity-inbox-action=primary]:bg-brutal-cyan',
    2064,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-action="primary"]', [], 2000, [
        RaftDecl('background-color', CssColor(0xFF27CCF3)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[activity-inbox-action=primary]:text-foreground-strong',
    2065,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-action="primary"]', [], 2000, [
        RaftDecl('color', _v0),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[activity-inbox-action=sort]:font-mono',
    2066,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-action="sort"]', [], 2000, [
        RaftDecl('font-family', _v3),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[activity-inbox-action=sort]:text-black/60',
    2067,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-action="sort"]', [], 2000, [
        RaftDecl('color', _v8),
      ]),
      RaftLayer(':is(& *)[data-activity-inbox-action="sort"]', [], 2000, [
        RaftDecl('color', _v9),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'button-content\']:font-field',
    2230,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'button-content\']', [], 2000, [
        RaftDecl('--tw-font-weight', _v10),
        RaftDecl('font-weight', _v10),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'button-content\']:font-medium',
    2231,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'button-content\']', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(500)),
        RaftDecl('font-weight', CssNum(500)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'button-content\']:justify-between',
    2229,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'button-content\']', [], 2000, [
        RaftDecl('justify-content', _v11),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'button-content\']:w-full',
    2228,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'button-content\']', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'combobox-clear\']:shrink-0',
    2232,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'combobox-clear\']', [], 2000, [
        RaftDecl('flex-shrink', CssNum(0)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'select-item-text\']:font-bold',
    2233,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'select-item-text\']', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(700)),
        RaftDecl('font-weight', CssNum(700)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'select-item-text\']:font-field',
    2234,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'select-item-text\']', [], 2000, [
        RaftDecl('--tw-font-weight', _v10),
        RaftDecl('font-weight', _v10),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'select-value\']:font-field',
    2235,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'select-value\']', [], 2000, [
        RaftDecl('--tw-font-weight', _v10),
        RaftDecl('font-weight', _v10),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'select-value\']:font-medium',
    2236,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'select-value\']', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(500)),
        RaftDecl('font-weight', CssNum(500)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:duration-150',
    2254,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('--tw-duration', CssNum(150, 'ms')),
        RaftDecl('transition-duration', CssNum(150, 'ms')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:hover:before:bg-transparent',
    2259,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]:hover::before', [], 3001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:hover:bg-ink-10',
    2255,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]:hover', [], 3000, [
        RaftDecl('background-color', _v12),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:hover:bg-transparent',
    2256,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]:hover', [], 3000, [
        RaftDecl('background-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:hover:text-[oklch(0.269_0_0)]',
    2257,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]:hover', [], 3000, [
        RaftDecl('color', _v13),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:hover:text-foreground',
    2258,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]:hover', [], 3000, [
        RaftDecl('color', _v14),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:shadow-none',
    2252,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('--tw-shadow', _v15),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:text-[oklch(0.439_0_0)]',
    2250,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('color', _v21),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:text-foreground-muted',
    2251,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('color', _v22),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:transition-[color,background-color,box-shadow]',
    2253,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('transition-property', _v25),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:w-full',
    2249,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=composer-attachment]:shrink-0',
    2261,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="composer-attachment"]', [], 2000, [
        RaftDecl('flex-shrink', CssNum(0)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:col-start-1',
    2262,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('grid-column-start', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:duration-170',
    2266,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('--tw-duration', CssNum(170, 'ms')),
        RaftDecl('transition-duration', CssNum(170, 'ms')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:ease-[cubic-bezier(0.16,1,0.3,1)]',
    2267,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('--tw-ease', _v29),
        RaftDecl('transition-timing-function', _v29),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:origin-center',
    2264,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('transform-origin', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:row-start-1',
    2263,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('grid-row-start', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:transition-[opacity,filter,scale]',
    2265,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('transition-property', _v30),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:will-change-[opacity,filter,scale]',
    2268,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('will-change', _v30),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview-media]:bg-transparent',
    2275,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview-media"]', [], 2000, [
        RaftDecl('background-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview-media]:border-0',
    2274,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview-media"]', [], 2000, [
        RaftDecl('border-top-style', _v31),
        RaftDecl('border-right-style', _v31),
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-left-style', _v31),
        RaftDecl('border-top-width', CssNum(0, 'px')),
        RaftDecl('border-right-width', CssNum(0, 'px')),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
        RaftDecl('border-left-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview-media]:ring-0',
    2277,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview-media"]', [], 2000, [
        RaftDecl('--tw-ring-shadow', _v37),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview-media]:shadow-none',
    2276,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview-media"]', [], 2000, [
        RaftDecl('--tw-shadow', _v15),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview-media]:size-full',
    2273,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview-media"]', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
        RaftDecl('height', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview]:size-full',
    2272,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview"]', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
        RaftDecl('height', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd]:bg-layer-panel',
    2282,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('background-color', _v38),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd]:bg-white/8',
    2283,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('background-color', _v41),
      ]),
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('background-color', _v42),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd]:border-line-strong/70',
    2281,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('border-top-color', _v43),
        RaftDecl('border-right-color', _v43),
        RaftDecl('border-bottom-color', _v43),
        RaftDecl('border-left-color', _v43),
      ]),
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('border-top-color', _v46),
        RaftDecl('border-right-color', _v46),
        RaftDecl('border-bottom-color', _v46),
        RaftDecl('border-left-color', _v46),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd]:leading-none',
    2285,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('--tw-leading', CssNum(1)),
        RaftDecl('line-height', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd]:relative',
    2279,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('position', CssKeyword('relative')),
      ]),
    ],
  ),
  RaftUtility('**:data-[slot=kbd]:ring-0', 2288, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
      RaftDecl('--tw-ring-shadow', _v37),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility(
    '**:data-[slot=kbd]:text-[10px]',
    2284,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('font-size', CssNum(10, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd]:text-foreground-strong/70',
    2286,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('color', _v0),
      ]),
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('color', _v48),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd]:text-white/72',
    2287,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('color', _v50),
      ]),
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('color', _v51),
      ]),
    ],
  ),
  RaftUtility('**:data-[slot=kbd]:z-10', 2280, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
      RaftDecl('z-index', CssNum(10)),
    ]),
  ]),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:flex',
    2293,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('display', CssKeyword('flex')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:font-sans',
    2295,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('font-family', _v54),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:items-center',
    2294,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('align-items', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:normal-case',
    2298,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('text-transform', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:text-black/40',
    2296,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('color', _v56),
      ]),
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('color', _v57),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:text-foreground-placeholder',
    2297,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('color', _v58),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:uppercase',
    2299,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('text-transform', CssKeyword('uppercase')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-section-chevron]:opacity-55',
    2300,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-section-chevron"]', [], 2000, [
        RaftDecl('opacity', CssNum(55, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-section-chevron]:transition-transform',
    2301,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-section-chevron"]', [], 2000, [
        RaftDecl('transition-property', _v59),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=task-card-status-label]:inline-flex',
    2315,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="task-card-status-label"]', [], 2000, [
        RaftDecl('display', _v60),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=task-card-status-label]:items-center',
    2316,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="task-card-status-label"]', [], 2000, [
        RaftDecl('align-items', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=task-card]:shadow-raft-md',
    2314,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="task-card"]', [], 2000, [
        RaftDecl('--tw-shadow', _v61),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=toast-content]:opacity-100',
    2320,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="toast-content"]', [], 2000, [
        RaftDecl('opacity', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=toast-icon]:text-brutal-red',
    2321,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="toast-icon"]', [], 2000, [
        RaftDecl('color', CssColor(0xFFF97264)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=toast-icon]:text-info',
    2322,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="toast-icon"]', [], 2000, [
        RaftDecl('color', _v62),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=toast-icon]:text-success',
    2323,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="toast-icon"]', [], 2000, [
        RaftDecl('color', _v63),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=toast-icon]:text-warning',
    2324,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="toast-icon"]', [], 2000, [
        RaftDecl('color', _v64),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:decoration-2',
    1871,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('text-decoration-thickness', CssNum(2, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:font-sans',
    1864,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('font-family', _v54),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:normal-case',
    1869,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('text-transform', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:outline-none',
    1873,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('--tw-outline-style', CssKeyword('none')),
        RaftDecl('outline-style', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:text-[10px]',
    1865,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('font-size', CssNum(10, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:text-black/50',
    1867,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('color', _v66),
      ]),
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('color', _v67),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:text-foreground-placeholder',
    1868,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('color', _v58),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:underline',
    1870,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('text-decoration-line', CssKeyword('underline')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:underline-offset-2',
    1872,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('text-underline-offset', CssNum(2, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:whitespace-nowrap',
    1866,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('white-space', CssKeyword('nowrap')),
      ]),
    ],
  ),
  RaftUtility('**:data-icon:size-[1em]', 1943, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)[data-icon]', [], 2000, [
      RaftDecl('width', CssNum(1, 'em')),
      RaftDecl('height', CssNum(1, 'em')),
    ]),
  ]),
  RaftUtility(
    '**:data-lightbox-close:inset-auto',
    1981,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-lightbox-close]', [], 2000, [
        RaftDecl('top', CssKeyword('auto')),
        RaftDecl('right', CssKeyword('auto')),
        RaftDecl('bottom', CssKeyword('auto')),
        RaftDecl('left', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-lightbox-close:right-auto',
    1983,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-lightbox-close]', [], 2000, [
        RaftDecl('right', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-lightbox-close:static',
    1980,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-lightbox-close]', [], 2000, [
        RaftDecl('position', CssKeyword('static')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-lightbox-close:top-auto',
    1982,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-lightbox-close]', [], 2000, [
        RaftDecl('top', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-message-item:bg-transparent',
    1985,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-message-item]', [], 2000, [
        RaftDecl('background-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-message-item:bg-white',
    1986,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-message-item]', [], 2000, [
        RaftDecl('background-color', _v39),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-picker-trigger-indicator:opacity-100',
    1998,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-picker-trigger-indicator]', [], 2000, [
        RaftDecl('opacity', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-picker-trigger-indicator:text-inherit',
    1997,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-picker-trigger-indicator]', [], 2000, [
        RaftDecl('color', CssKeyword('inherit')),
      ]),
    ],
  ),
  RaftUtility('**:select-text', 1178, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)', [], 1000, [
      RaftDecl('-webkit-user-select', CssKeyword('text')),
      RaftDecl('user-select', CssKeyword('text')),
    ]),
  ]),
  RaftUtility(
    '*:data-[slot=app-rail-item]:text-foreground-muted',
    2237,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="app-rail-item"]', [], 2000, [
        RaftDecl('color', _v22),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar-group-count]:border-layer-canvas-muted',
    2243,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar-group-count"]', [], 2000, [
        RaftDecl('border-top-color', _v68),
        RaftDecl('border-right-color', _v68),
        RaftDecl('border-bottom-color', _v68),
        RaftDecl('border-left-color', _v68),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar-group-count]:outline',
    2244,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar-group-count"]', [], 2000, [
        RaftDecl('outline-style', _v69),
        RaftDecl('outline-width', CssNum(1, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar-group-count]:outline-2',
    2245,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar-group-count"]', [], 2000, [
        RaftDecl('outline-style', _v69),
        RaftDecl('outline-width', CssNum(2, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar-group-count]:outline-layer-canvas-muted',
    2246,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar-group-count"]', [], 2000, [
        RaftDecl('outline-color', _v68),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar-group-count]:outline-primary-50',
    2247,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar-group-count"]', [], 2000, [
        RaftDecl('outline-color', _v70),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar]:border-layer-canvas-muted',
    2238,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar"]', [], 2000, [
        RaftDecl('border-top-color', _v68),
        RaftDecl('border-right-color', _v68),
        RaftDecl('border-bottom-color', _v68),
        RaftDecl('border-left-color', _v68),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar]:outline',
    2239,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar"]', [], 2000, [
        RaftDecl('outline-style', _v69),
        RaftDecl('outline-width', CssNum(1, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar]:outline-2',
    2240,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar"]', [], 2000, [
        RaftDecl('outline-style', _v69),
        RaftDecl('outline-width', CssNum(2, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar]:outline-layer-canvas-muted',
    2241,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar"]', [], 2000, [
        RaftDecl('outline-color', _v68),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar]:outline-primary-50',
    2242,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar"]', [], 2000, [
        RaftDecl('outline-color', _v70),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=button]:ml-[-5px]',
    2248,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]', [], 2000, [
        RaftDecl('margin-left', CssNum(-5, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=checkbox]:mt-px',
    2260,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="checkbox"]', [], 2000, [
        RaftDecl('margin-top', CssNum(1, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=description-item]:contents',
    2269,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="description-item"]', [], 2000, [
        RaftDecl('display', CssKeyword('contents')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=file-preview]:self-center',
    2271,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="file-preview"]', [], 2000, [
        RaftDecl('align-self', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=file-preview]:translate-y-[-3px]',
    2270,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="file-preview"]', [], 2000, [
        RaftDecl('--tw-translate-y', CssNum(-3, 'px')),
        RaftDecl('translate', CssSeq([_v71, _v72])),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=input-group]:flex-1',
    2278,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="input-group"]', [], 2000, [
        RaftDecl('flex', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=status]:col-start-1',
    2302,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="status"]', [], 2000, [
        RaftDecl('grid-column-start', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=status]:row-span-2',
    2303,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="status"]', [], 2000, [
        RaftDecl('grid-row', _v73),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=status]:row-start-1',
    2304,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="status"]', [], 2000, [
        RaftDecl('grid-row-start', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=status]:self-center',
    2306,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="status"]', [], 2000, [
        RaftDecl('align-self', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=status]:size-full',
    2305,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="status"]', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
        RaftDecl('height', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=tabs-list]:bg-white',
    2313,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="tabs-list"]', [], 2000, [
        RaftDecl('background-color', _v39),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=tabs-list]:border-black',
    2312,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="tabs-list"]', [], 2000, [
        RaftDecl('border-top-color', _v5),
        RaftDecl('border-right-color', _v5),
        RaftDecl('border-bottom-color', _v5),
        RaftDecl('border-left-color', _v5),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=tabs-list]:border-l-0',
    2311,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="tabs-list"]', [], 2000, [
        RaftDecl('border-left-style', _v31),
        RaftDecl('border-left-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=tabs-list]:border-r-2',
    2310,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="tabs-list"]', [], 2000, [
        RaftDecl('border-right-style', _v31),
        RaftDecl('border-right-width', CssNum(2, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=tabs-list]:border-y-0',
    2309,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="tabs-list"]', [], 2000, [
        RaftDecl('border-top-style', _v31),
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-top-width', CssNum(0, 'px')),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=tabs-list]:max-w-none',
    2308,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="tabs-list"]', [], 2000, [
        RaftDecl('max-width', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=textarea-counter]:absolute',
    2318,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="textarea-counter"]', [], 2000, [
        RaftDecl('position', CssKeyword('absolute')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=textarea-counter]:pointer-events-none',
    2317,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="textarea-counter"]', [], 2000, [
        RaftDecl('pointer-events', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=textarea-counter]:z-10',
    2319,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="textarea-counter"]', [], 2000, [
        RaftDecl('z-index', CssNum(10)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:absolute',
    1975,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('position', CssKeyword('absolute')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:pointer-events-auto',
    1974,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('pointer-events', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:right-[calc(16px+env(safe-area-inset-right,0px))]',
    1977,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('right', CssCalc(_v76)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:rounded-full',
    1979,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('border-top-left-radius', _v77),
        RaftDecl('border-top-right-radius', _v77),
        RaftDecl('border-bottom-right-radius', _v77),
        RaftDecl('border-bottom-left-radius', _v77),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:top-[calc(16px+env(safe-area-inset-top,0px))]',
    1976,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('top', CssCalc(_v80)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:z-20',
    1978,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('z-index', CssNum(20)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-panel-frame-header:border-b',
    1993,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-panel-frame-header]', [], 2000, [
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-bottom-width', CssNum(1, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-panel-frame-header:border-b-2',
    1994,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-panel-frame-header]', [], 2000, [
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-bottom-width', CssNum(2, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-panel-frame-header:border-black',
    1995,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-panel-frame-header]', [], 2000, [
        RaftDecl('border-top-color', _v5),
        RaftDecl('border-right-color', _v5),
        RaftDecl('border-bottom-color', _v5),
        RaftDecl('border-left-color', _v5),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-panel-frame-header:border-line-muted',
    1996,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-panel-frame-header]', [], 2000, [
        RaftDecl('border-top-color', _v81),
        RaftDecl('border-right-color', _v81),
        RaftDecl('border-bottom-color', _v81),
        RaftDecl('border-left-color', _v81),
      ]),
    ],
  ),
  RaftUtility('*:relative', 1176, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)', [], 1000, [
      RaftDecl('position', CssKeyword('relative')),
    ]),
  ]),
  RaftUtility('*:z-10', 1177, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)', [], 1000, [RaftDecl('z-index', CssNum(10))]),
  ]),
  RaftUtility('-bottom-0.5', 45, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(-2, 'px'))]),
  ]),
  RaftUtility('-inset-1', 10, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('top', CssNum(-4, 'px')),
      RaftDecl('right', CssNum(-4, 'px')),
      RaftDecl('bottom', CssNum(-4, 'px')),
      RaftDecl('left', CssNum(-4, 'px')),
    ]),
  ]),
  RaftUtility('-ml-1', 128, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-left', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-ml-1.5', 129, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-left', CssNum(-6, 'px'))]),
  ]),
  RaftUtility('-mr-1', 116, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-mr-1.5', 117, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssNum(-6, 'px'))]),
  ]),
  RaftUtility('-mt-1', 103, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-mt-1.5', 104, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(-6, 'px'))]),
  ]),
  RaftUtility('-mt-px', 105, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(-1, 'px'))]),
  ]),
  RaftUtility(
    '-mx-(--sidebar-row-inset-x,6px)',
    96,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('margin-left', CssCalc(_v83)),
        RaftDecl('margin-right', CssCalc(_v83)),
      ]),
    ],
  ),
  RaftUtility('-mx-1', 97, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-left', CssNum(-4, 'px')),
      RaftDecl('margin-right', CssNum(-4, 'px')),
    ]),
  ]),
  RaftUtility('-mx-2', 98, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-left', CssNum(-8, 'px')),
      RaftDecl('margin-right', CssNum(-8, 'px')),
    ]),
  ]),
  RaftUtility('-outline-offset-1', 1011, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('outline-offset', CssNum(-1, 'px'))]),
  ]),
  RaftUtility('-right-0.5', 30, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(-2, 'px'))]),
  ]),
  RaftUtility('-right-1', 31, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-right-1.5', 32, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(-6, 'px'))]),
  ]),
  RaftUtility('-rotate-6', 324, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('rotate', CssNum(-6, 'deg'))]),
  ]),
  RaftUtility('-rotate-90', 325, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('rotate', CssNum(-90, 'deg'))]),
  ]),
  RaftUtility('-space-x-1.5', 399, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-space-x-reverse', CssNum(0)),
      RaftDecl('margin-left', CssCalc(_v85)),
      RaftDecl('margin-right', CssCalc(_v87)),
    ]),
  ]),
  RaftUtility('-space-x-2', 400, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-space-x-reverse', CssNum(0)),
      RaftDecl('margin-left', CssCalc(_v88)),
      RaftDecl('margin-right', CssCalc(_v89)),
    ]),
  ]),
  RaftUtility('-top-1', 16, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-top-1.5', 17, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(-6, 'px'))]),
  ]),
  RaftUtility('-top-3.5', 18, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(-14, 'px'))]),
  ]),
  RaftUtility('-top-px', 19, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(-1, 'px'))]),
  ]),
  RaftUtility('-translate-1/2', 314, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-x', CssNum(-50, '%')),
      RaftDecl('--tw-translate-y', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility('-translate-x-1/2', 316, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-x', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility('-translate-y-0.5', 317, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-y', CssNum(-2, 'px')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility('-translate-y-1/2', 318, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-y', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility('-z-10', 63, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(-10))]),
  ]),
  RaftUtility('@container', 0, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('container-type', _v90)]),
  ]),
  RaftUtility('@max-[24rem]:-col-end-1', 2521, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['container-width<384'],
      1000,
      [RaftDecl('grid-column-end', CssNum(-1))],
    ),
  ]),
  RaftUtility(
    '@max-[24rem]:[--banner-action-col:1]',
    2527,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container-width<384'],
        1000,
        [RaftDecl('--banner-action-col', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    '@max-[24rem]:justify-self-end',
    2526,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container-width<384'],
        1000,
        [RaftDecl('justify-self', CssKeyword('flex-end'))],
      ),
    ],
  ),
  RaftUtility('@max-[24rem]:mt-1', 2524, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['container-width<384'],
      1000,
      [RaftDecl('margin-top', CssNum(4, 'px'))],
    ),
  ]),
  RaftUtility('@max-[24rem]:mt-2', 2525, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['container-width<384'],
      1000,
      [RaftDecl('margin-top', CssNum(8, 'px'))],
    ),
  ]),
  RaftUtility('@max-[24rem]:row-span-1', 2522, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['container-width<384'],
      1000,
      [RaftDecl('grid-row', _v91)],
    ),
  ]),
  RaftUtility('@max-[24rem]:row-start-auto', 2523, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['container-width<384'],
      1000,
      [RaftDecl('grid-row-start', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility('[&+&]:before:absolute', 2901, RaftUtilityStatus.descendant, [
    RaftLayer('& + .\\[\\&\\+\\&\\]\\:before\\:absolute::before', [], 2001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('position', CssKeyword('absolute')),
    ]),
  ]),
  RaftUtility(
    '[&+&]:before:bg-line-strong',
    2908,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& + .\\[\\&\\+\\&\\]\\:before\\:bg-line-strong::before',
        [],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v43),
        ],
      ),
    ],
  ),
  RaftUtility('[&+&]:before:h-0.5', 2906, RaftUtilityStatus.descendant, [
    RaftLayer('& + .\\[\\&\\+\\&\\]\\:before\\:h-0\\.5::before', [], 2001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('[&+&]:before:inset-x-0', 2902, RaftUtilityStatus.descendant, [
    RaftLayer('& + .\\[\\&\\+\\&\\]\\:before\\:inset-x-0::before', [], 2001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('[&+&]:before:inset-y-0', 2903, RaftUtilityStatus.descendant, [
    RaftLayer('& + .\\[\\&\\+\\&\\]\\:before\\:inset-y-0::before', [], 2001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(0, 'px')),
      RaftDecl('bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('[&+&]:before:left-0', 2905, RaftUtilityStatus.descendant, [
    RaftLayer('& + .\\[\\&\\+\\&\\]\\:before\\:left-0::before', [], 2001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('[&+&]:before:top-0', 2904, RaftUtilityStatus.descendant, [
    RaftLayer('& + .\\[\\&\\+\\&\\]\\:before\\:top-0::before', [], 2001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('[&+&]:before:w-0.5', 2907, RaftUtilityStatus.descendant, [
    RaftLayer('& + .\\[\\&\\+\\&\\]\\:before\\:w-0\\.5::before', [], 2001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&::-webkit-scrollbar]:hidden',
    2909,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::-webkit-scrollbar', [], 1001, [
        RaftDecl('display', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '[&::before]:[-webkit-mask-clip:content-box,border-box]',
    2920,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('-webkit-mask-clip', CssList([_v92, _v93])),
      ]),
    ],
  ),
  RaftUtility(
    '[&::before]:[-webkit-mask-composite:xor]',
    2921,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('-webkit-mask-composite', CssKeyword('xor')),
      ]),
    ],
  ),
  RaftUtility(
    '[&::before]:[-webkit-mask-image:linear-gradient(oklch(1_0_0)_0_0),linear-gradient(oklch(1_0_0)_0_0)]',
    2922,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('-webkit-mask-image', CssList([_v95, _v95])),
      ]),
    ],
  ),
  RaftUtility(
    '[&::before]:[-webkit-mask-origin:content-box,border-box]',
    2923,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('-webkit-mask-origin', CssList([_v92, _v93])),
      ]),
    ],
  ),
  RaftUtility(
    '[&::before]:[background:var(--toast-gradient-border,linear-gradient(var(--toast-gradient-border-angle,to_bottom),var(--toast-gradient-border-from,oklch(1_0_0/0.24)),var(--toast-gradient-border-via,oklch(1_0_0/0.1)),var(--toast-gradient-border-to,transparent)))]',
    2924,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [RaftDecl('background', _v104)]),
    ],
  ),
  RaftUtility('[&::before]:[content:\'\']', 2919, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [RaftDecl('content', CssString(''))]),
  ]),
  RaftUtility(
    '[&::before]:[mask-clip:content-box,border-box]',
    2916,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('mask-clip', CssList([_v92, _v93])),
      ]),
    ],
  ),
  RaftUtility(
    '[&::before]:[mask-origin:content-box,border-box]',
    2917,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('mask-origin', CssList([_v92, _v93])),
      ]),
    ],
  ),
  RaftUtility('[&::before]:absolute', 2911, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('position', CssKeyword('absolute')),
    ]),
  ]),
  RaftUtility('[&::before]:inset-0', 2912, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('top', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
      RaftDecl('bottom', CssNum(0, 'px')),
      RaftDecl('left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&::before]:mask-[linear-gradient(oklch(1_0_0)_0_0),linear-gradient(oklch(1_0_0)_0_0)]',
    2914,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('mask-image', CssList([_v95, _v95])),
      ]),
    ],
  ),
  RaftUtility('[&::before]:mask-exclude', 2915, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('mask-composite', CssKeyword('exclude')),
    ]),
  ]),
  RaftUtility(
    '[&::before]:p-(--toast-gradient-border-width,1px)',
    2918,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('padding-top', _v105),
        RaftDecl('padding-right', _v105),
        RaftDecl('padding-bottom', _v105),
        RaftDecl('padding-left', _v105),
      ]),
    ],
  ),
  RaftUtility(
    '[&::before]:pointer-events-none',
    2910,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('pointer-events', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '[&::before]:rounded-[inherit]',
    2913,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('border-top-left-radius', CssKeyword('inherit')),
        RaftDecl('border-top-right-radius', CssKeyword('inherit')),
        RaftDecl('border-bottom-right-radius', CssKeyword('inherit')),
        RaftDecl('border-bottom-left-radius', CssKeyword('inherit')),
      ]),
    ],
  ),
  RaftUtility(
    '[&:has(>[data-slot=status]):has(>[data-slot=banner-action])]:grid-cols-[auto_minmax(0,1fr)_auto]',
    2925,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-action', 'has:>data-slot=status'],
        3000,
        [RaftDecl('grid-template-columns', _v107)],
      ),
    ],
  ),
  RaftUtility(
    '[&:has(>svg):has(>[data-slot=banner-action])]:grid-cols-[18px_minmax(0,1fr)_auto]',
    2926,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-action', 'has:>svg'],
        2001,
        [RaftDecl('grid-template-columns', _v108)],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-close])]:min-h-14',
    2927,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-close', 'has:data-slot=toast-description'],
        3000,
        [RaftDecl('min-height', CssNum(56, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-close])]:min-w-[18rem]',
    2928,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-close', 'has:data-slot=toast-description'],
        3000,
        [RaftDecl('min-width', CssNum(288, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-close])]:pl-3.5',
    2930,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-close', 'has:data-slot=toast-description'],
        3000,
        [RaftDecl('padding-left', CssNum(14, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-close])]:py-3',
    2929,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-close', 'has:data-slot=toast-description'],
        3000,
        [
          RaftDecl('padding-top', CssNum(12, 'px')),
          RaftDecl('padding-bottom', CssNum(12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-icon])]:min-h-14',
    2931,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-description', 'has:data-slot=toast-icon'],
        3000,
        [RaftDecl('min-height', CssNum(56, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-icon])]:min-w-[18rem]',
    2932,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-description', 'has:data-slot=toast-icon'],
        3000,
        [RaftDecl('min-width', CssNum(288, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-icon])]:pl-3.5',
    2934,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-description', 'has:data-slot=toast-icon'],
        3000,
        [RaftDecl('padding-left', CssNum(14, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-icon])]:py-3',
    2933,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-description', 'has:data-slot=toast-icon'],
        3000,
        [
          RaftDecl('padding-top', CssNum(12, 'px')),
          RaftDecl('padding-bottom', CssNum(12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-title])]:min-h-14',
    2935,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-description', 'has:data-slot=toast-title'],
        3000,
        [RaftDecl('min-height', CssNum(56, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-title])]:min-w-[18rem]',
    2936,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-description', 'has:data-slot=toast-title'],
        3000,
        [RaftDecl('min-width', CssNum(288, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-title])]:pl-3.5',
    2938,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-description', 'has:data-slot=toast-title'],
        3000,
        [RaftDecl('padding-left', CssNum(14, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-description]):has([data-slot=toast-title])]:py-3',
    2937,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-description', 'has:data-slot=toast-title'],
        3000,
        [
          RaftDecl('padding-top', CssNum(12, 'px')),
          RaftDecl('padding-bottom', CssNum(12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-icon]):has([data-slot=toast-actions])]:grid-cols-[auto_minmax(0,1fr)]',
    2939,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-actions', 'has:data-slot=toast-icon'],
        3000,
        [RaftDecl('grid-template-columns', _v109)],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-icon]):not(:has([data-slot=toast-actions])):not(:has([data-slot=toast-description]))]:min-h-10',
    2940,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:data-slot=toast-icon',
          'not:has:data-slot=toast-actions',
          'not:has:data-slot=toast-description',
        ],
        4000,
        [RaftDecl('min-height', CssNum(40, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-icon]):not(:has([data-slot=toast-actions])):not(:has([data-slot=toast-description]))]:min-w-0',
    2941,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:data-slot=toast-icon',
          'not:has:data-slot=toast-actions',
          'not:has:data-slot=toast-description',
        ],
        4000,
        [RaftDecl('min-width', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-icon]):not(:has([data-slot=toast-actions])):not(:has([data-slot=toast-description]))]:pl-3.5',
    2944,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:data-slot=toast-icon',
          'not:has:data-slot=toast-actions',
          'not:has:data-slot=toast-description',
        ],
        4000,
        [RaftDecl('padding-left', CssNum(14, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-icon]):not(:has([data-slot=toast-actions])):not(:has([data-slot=toast-description]))]:pr-3.5',
    2943,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:data-slot=toast-icon',
          'not:has:data-slot=toast-actions',
          'not:has:data-slot=toast-description',
        ],
        4000,
        [RaftDecl('padding-right', CssNum(14, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:has([data-slot=toast-icon]):not(:has([data-slot=toast-actions])):not(:has([data-slot=toast-description]))]:py-2',
    2942,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:data-slot=toast-icon',
          'not:has:data-slot=toast-actions',
          'not:has:data-slot=toast-description',
        ],
        4000,
        [
          RaftDecl('padding-top', CssNum(8, 'px')),
          RaftDecl('padding-bottom', CssNum(8, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('[&:has(svg)]:px-0', 2945, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:svg'],
      1001,
      [
        RaftDecl('padding-left', CssNum(0, 'px')),
        RaftDecl('padding-right', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('[&:has(svg)]:px-2', 2946, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:svg'],
      1001,
      [
        RaftDecl('padding-left', CssNum(8, 'px')),
        RaftDecl('padding-right', CssNum(8, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    '[&:not(:has([data-slot=task-card-status-label]))]:hidden',
    2947,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['not:has:data-slot=task-card-status-label'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:not([data-has-description])>[data-slot=toast-body]:only-child]:justify-self-center',
    2948,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=toast-body]:only-child',
        ['not:data-has-description'],
        4000,
        [RaftDecl('justify-self', CssKeyword('center'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:not([data-has-description])>[data-slot=toast-body]:only-child]:text-center',
    2949,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=toast-body]:only-child',
        ['not:data-has-description'],
        4000,
        [RaftDecl('text-align', CssKeyword('center'))],
      ),
    ],
  ),
  RaftUtility(
    '[&:not([data-has-icon]):not([data-has-actions]):not([data-has-description])]:min-h-(--toast-title-only-min-h,2.25rem)',
    2950,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'not:data-has-actions',
          'not:data-has-description',
          'not:data-has-icon',
        ],
        4000,
        [RaftDecl('min-height', _v110)],
      ),
    ],
  ),
  RaftUtility(
    '[&:not([data-has-icon]):not([data-has-actions]):not([data-has-description])]:min-w-(--toast-title-only-min-w,7rem)',
    2951,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'not:data-has-actions',
          'not:data-has-description',
          'not:data-has-icon',
        ],
        4000,
        [RaftDecl('min-width', _v111)],
      ),
    ],
  ),
  RaftUtility(
    '[&:not([data-has-icon]):not([data-has-actions]):not([data-has-description])]:px-(--toast-title-only-px,0.75rem)',
    2952,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'not:data-has-actions',
          'not:data-has-description',
          'not:data-has-icon',
        ],
        4000,
        [RaftDecl('padding-left', _v112), RaftDecl('padding-right', _v112)],
      ),
    ],
  ),
  RaftUtility(
    '[&:not([data-has-icon]):not([data-has-actions]):not([data-has-description])]:py-(--toast-title-only-py,0.5rem)',
    2953,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'not:data-has-actions',
          'not:data-has-description',
          'not:data-has-icon',
        ],
        4000,
        [RaftDecl('padding-top', _v113), RaftDecl('padding-bottom', _v113)],
      ),
    ],
  ),
  RaftUtility(
    '[&>*:first-child]:border-t-0',
    2956,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > *:first-child', [], 2000, [
        RaftDecl('border-top-style', _v31),
        RaftDecl('border-top-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&>:not(svg)]:min-w-0', 2957, RaftUtilityStatus.descendant, [
    RaftLayer('& > :not(svg)', [], 1001, [
      RaftDecl('min-width', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&>[data-lightbox-close]]:[&_svg]:size-3.5',
    2959,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-lightbox-close] svg', [], 2001, [
        RaftDecl('width', CssNum(14, 'px')),
        RaftDecl('height', CssNum(14, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-lightbox-close]]:p-1.5',
    2958,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-lightbox-close]', [], 2000, [
        RaftDecl('padding-top', CssNum(6, 'px')),
        RaftDecl('padding-right', CssNum(6, 'px')),
        RaftDecl('padding-bottom', CssNum(6, 'px')),
        RaftDecl('padding-left', CssNum(6, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-details]]:min-w-0',
    2961,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details]',
        [],
        3000,
        [RaftDecl('min-width', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-details]]:wrap-break-word',
    2962,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details]',
        [],
        3000,
        [RaftDecl('overflow-wrap', _v114)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-term]]:max-w-40',
    2964,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-term]',
        [],
        3000,
        [RaftDecl('max-width', CssNum(160, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-term]]:mb-0',
    2963,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-term]',
        [],
        3000,
        [RaftDecl('margin-bottom', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-term]]:min-w-0',
    2965,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-term]',
        [],
        3000,
        [RaftDecl('min-width', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-term]]:wrap-break-word',
    2966,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-term]',
        [],
        3000,
        [RaftDecl('overflow-wrap', _v114)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=empty-state-icon]]:mb-0',
    2967,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=empty-state-icon]', [], 2000, [
        RaftDecl('margin-bottom', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=empty-state-title]]:mb-0',
    2968,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=empty-state-title]', [], 2000, [
        RaftDecl('margin-bottom', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=input-group]]:min-w-0',
    2969,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=input-group]', [], 2000, [
        RaftDecl('min-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]:hover]:bg-fill-strong/80',
    2979,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]:hover',
        [],
        4000,
        [RaftDecl('background-color', _v115)],
      ),
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]:hover',
        [],
        4000,
        [RaftDecl('background-color', _v117)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]:hover]:bg-white',
    2980,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]:hover',
        [],
        4000,
        [RaftDecl('background-color', _v39)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]:hover]:text-brutal-orange',
    2981,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]:hover',
        [],
        4000,
        [RaftDecl('color', CssColor(0xFFF8A16F))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]:hover]:text-primary-400',
    2982,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]:hover',
        [],
        4000,
        [RaftDecl('color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]]:bg-transparent',
    2974,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=panel-toggle-action][data-pressed]', [], 3000, [
        RaftDecl('background-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]]:bg-white',
    2975,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=panel-toggle-action][data-pressed]', [], 3000, [
        RaftDecl('background-color', _v39),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]]:text-brutal-orange',
    2976,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=panel-toggle-action][data-pressed]', [], 3000, [
        RaftDecl('color', CssColor(0xFFF8A16F)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]]:text-primary-400',
    2977,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=panel-toggle-action][data-pressed]', [], 3000, [
        RaftDecl('color', _v118),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=status]]:size-1',
    2984,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=status]', [], 2000, [
        RaftDecl('width', CssNum(4, 'px')),
        RaftDecl('height', CssNum(4, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=status]]:size-2',
    2985,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=status]', [], 2000, [
        RaftDecl('width', CssNum(8, 'px')),
        RaftDecl('height', CssNum(8, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=tabs-list]>[data-slot=tabs-tab]+[data-slot=tabs-tab]]:before:bg-black',
    2992,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=tabs-list] > [data-slot=tabs-tab] + [data-slot=tabs-tab]::before',
        [],
        4001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v5),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=tabs-list]>[data-slot=tabs-tab][data-active]:hover]:bg-primary',
    2994,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=tabs-list] > [data-slot=tabs-tab][data-active]:hover',
        [],
        5000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=tabs-list]>[data-slot=tabs-tab][data-active]]:bg-primary',
    2993,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=tabs-list] > [data-slot=tabs-tab][data-active]',
        [],
        4000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=tabs-list]>[data-slot=tabs-tab]]:bg-white',
    2988,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=tabs-list] > [data-slot=tabs-tab]', [], 3000, [
        RaftDecl('background-color', _v39),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=tabs-list]>[data-slot=tabs-tab]]:max-md:h-10',
    2990,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=tabs-list] > [data-slot=tabs-tab]',
        ['width<768'],
        3000,
        [RaftDecl('height', CssNum(40, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=tabs-list]>[data-slot=tabs-tab]]:max-md:py-2',
    2991,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=tabs-list] > [data-slot=tabs-tab]',
        ['width<768'],
        3000,
        [
          RaftDecl('padding-top', CssNum(8, 'px')),
          RaftDecl('padding-bottom', CssNum(8, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=tabs-list]>[data-slot=tabs-tab]]:text-black',
    2989,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=tabs-list] > [data-slot=tabs-tab]', [], 3000, [
        RaftDecl('color', _v5),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=tabs-list]]:max-md:h-10',
    2986,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=tabs-list]',
        ['width<768'],
        2000,
        [RaftDecl('height', CssNum(40, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=textarea-counter]]:bottom-2.5',
    2996,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=textarea-counter]', [], 2000, [
        RaftDecl('bottom', CssNum(10, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=textarea-counter]]:right-3',
    2995,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=textarea-counter]', [], 2000, [
        RaftDecl('right', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=thread-panel-actions]]:gap-0.5',
    2997,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=thread-panel-actions]', [], 2000, [
        RaftDecl('row-gap', CssNum(2, 'px')),
        RaftDecl('column-gap', CssNum(2, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&>[role=menuitem]]:p-0', 2999, RaftUtilityStatus.descendant, [
    RaftLayer('& > [role=menuitem]', [], 2000, [
      RaftDecl('padding-top', CssNum(0, 'px')),
      RaftDecl('padding-right', CssNum(0, 'px')),
      RaftDecl('padding-bottom', CssNum(0, 'px')),
      RaftDecl('padding-left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&>[role=menuitem]]:size-7',
    2998,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [role=menuitem]', [], 2000, [
        RaftDecl('width', CssNum(28, 'px')),
        RaftDecl('height', CssNum(28, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>a:hover]:text-foreground',
    3003,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > a:hover', [], 2001, [RaftDecl('color', _v14)]),
    ],
  ),
  RaftUtility('[&>a]:underline', 3000, RaftUtilityStatus.descendant, [
    RaftLayer('& > a', [], 1001, [
      RaftDecl('text-decoration-line', CssKeyword('underline')),
    ]),
  ]),
  RaftUtility('[&>a]:underline-offset-4', 3001, RaftUtilityStatus.descendant, [
    RaftLayer('& > a', [], 1001, [
      RaftDecl('text-underline-offset', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&>button:has(svg):last-child>svg]:size-4',
    3025,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child > svg', [], 2003, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:before:bg-transparent',
    3021,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child::before', [], 2003, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:bg-transparent',
    3010,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('background-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:border-transparent',
    3009,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('border-top-color', _v7),
        RaftDecl('border-right-color', _v7),
        RaftDecl('border-bottom-color', _v7),
        RaftDecl('border-left-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:duration-200',
    3014,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('--tw-duration', CssNum(200, 'ms')),
        RaftDecl('transition-duration', CssNum(200, 'ms')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:hover:bg-foreground-strong/5',
    3023,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child:hover', [], 3002, [
        RaftDecl('background-color', _v0),
      ]),
      RaftLayer('& > button:has(svg):last-child:hover', [], 3002, [
        RaftDecl('background-color', _v120),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:hover:border-transparent',
    3022,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child:hover', [], 3002, [
        RaftDecl('border-top-color', _v7),
        RaftDecl('border-right-color', _v7),
        RaftDecl('border-bottom-color', _v7),
        RaftDecl('border-left-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:hover:text-current/70',
    3024,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child:hover', [], 3002, [
        RaftDecl('color', _v35),
      ]),
      RaftLayer('& > button:has(svg):last-child:hover', [], 3002, [
        RaftDecl('color', _v122),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:min-h-5',
    3006,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('min-height', CssNum(20, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:min-w-5',
    3007,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('min-width', CssNum(20, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:rounded-sm',
    3008,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('border-top-left-radius', CssNum(4, 'px')),
        RaftDecl('border-top-right-radius', CssNum(4, 'px')),
        RaftDecl('border-bottom-right-radius', CssNum(4, 'px')),
        RaftDecl('border-bottom-left-radius', CssNum(4, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:shadow-none',
    3012,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('--tw-shadow', _v15),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:size-5',
    3005,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('width', CssNum(20, 'px')),
        RaftDecl('height', CssNum(20, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:text-current/45',
    3011,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('color', _v35),
      ]),
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('color', _v124),
      ]),
    ],
  ),
  RaftUtility(
    '[&>button:has(svg):last-child]:transition-colors',
    3013,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > button:has(svg):last-child', [], 2002, [
        RaftDecl('transition-property', _v131),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility('[&>label]:font-medium', 3027, RaftUtilityStatus.descendant, [
    RaftLayer('& > label', [], 1001, [
      RaftDecl('--tw-font-weight', CssNum(500)),
      RaftDecl('font-weight', CssNum(500)),
    ]),
  ]),
  RaftUtility(
    '[&>span[data-slot=\'combobox-trigger-content\']>svg:not([class*=\'size-\'])]:size-3',
    3034,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > span[data-slot=\'combobox-trigger-content\'] > svg:not([class*=\'size-\'])',
        [],
        3002,
        [
          RaftDecl('width', CssNum(12, 'px')),
          RaftDecl('height', CssNum(12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'combobox-trigger-content\']>svg:not([class*=\'size-\'])]:size-4',
    3035,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > span[data-slot=\'combobox-trigger-content\'] > svg:not([class*=\'size-\'])',
        [],
        3002,
        [
          RaftDecl('width', CssNum(16, 'px')),
          RaftDecl('height', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'combobox-trigger-content\']>svg:not([class*=\'stroke-\'])]:stroke-2',
    3036,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > span[data-slot=\'combobox-trigger-content\'] > svg:not([class*=\'stroke-\'])',
        [],
        3002,
        [RaftDecl('stroke-width', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'combobox-trigger-content\']>svg:not([class*=\'stroke-\'])]:stroke-[1.5]',
    3037,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > span[data-slot=\'combobox-trigger-content\'] > svg:not([class*=\'stroke-\'])',
        [],
        3002,
        [RaftDecl('stroke-width', CssNum(1.5))],
      ),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'combobox-trigger-content\']>svg]:shrink-0',
    3033,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > span[data-slot=\'combobox-trigger-content\'] > svg',
        [],
        2002,
        [RaftDecl('flex-shrink', CssNum(0))],
      ),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'combobox-trigger-content\']]:flex-1',
    3032,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > span[data-slot=\'combobox-trigger-content\']', [], 2001, [
        RaftDecl('flex', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'combobox-trigger-content\']]:min-w-0',
    3031,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > span[data-slot=\'combobox-trigger-content\']', [], 2001, [
        RaftDecl('min-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'select-trigger-content\']]:flex-1',
    3039,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > span[data-slot=\'select-trigger-content\']', [], 2001, [
        RaftDecl('flex', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'select-trigger-content\']]:min-w-0',
    3038,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > span[data-slot=\'select-trigger-content\']', [], 2001, [
        RaftDecl('min-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&>svg:last-child]:size-3', 3105, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg:last-child', [], 2001, [
      RaftDecl('width', CssNum(12, 'px')),
      RaftDecl('height', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&>svg:not([class*=\'size-\'])]:size-3',
    3106,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(12, 'px')),
        RaftDecl('height', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg:not([class*=\'size-\'])]:size-3.5',
    3107,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(14, 'px')),
        RaftDecl('height', CssNum(14, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg:not([class*=\'stroke-\'])]:stroke-2',
    3108,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([class*=\'stroke-\'])', [], 2001, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg:not([class*=\'stroke-\'])]:stroke-[1.5]',
    3109,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([class*=\'stroke-\'])', [], 2001, [
        RaftDecl('stroke-width', CssNum(1.5)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg[data-slot=task-status-icon]]:size-3.5',
    3110,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg[data-slot=task-status-icon]', [], 2001, [
        RaftDecl('width', CssNum(14, 'px')),
        RaftDecl('height', CssNum(14, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&>svg]:absolute', 3041, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('position', CssKeyword('absolute')),
    ]),
  ]),
  RaftUtility('[&>svg]:block', 3048, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('display', CssKeyword('block'))]),
  ]),
  RaftUtility('[&>svg]:col-start-1', 3046, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('grid-column-start', CssNum(1))]),
  ]),
  RaftUtility('[&>svg]:h-5', 3056, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('height', CssNum(20, 'px'))]),
  ]),
  RaftUtility('[&>svg]:hidden', 3049, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('display', CssKeyword('none'))]),
  ]),
  RaftUtility('[&>svg]:left-0', 3044, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('left', CssNum(0, 'px'))]),
  ]),
  RaftUtility(
    '[&>svg]:pointer-events-none',
    3040,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [
        RaftDecl('pointer-events', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility('[&>svg]:relative', 3042, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('position', CssKeyword('relative')),
    ]),
  ]),
  RaftUtility('[&>svg]:row-start-1', 3047, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('grid-row-start', CssNum(1))]),
  ]),
  RaftUtility('[&>svg]:self-center', 3059, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('align-self', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('[&>svg]:shrink-0', 3058, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('flex-shrink', CssNum(0))]),
  ]),
  RaftUtility('[&>svg]:size-3', 3050, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(12, 'px')),
      RaftDecl('height', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-3.5', 3051, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(14, 'px')),
      RaftDecl('height', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-4', 3052, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(16, 'px')),
      RaftDecl('height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-4.5', 3053, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(18, 'px')),
      RaftDecl('height', CssNum(18, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-[0.857em]', 3054, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(0.857, 'em')),
      RaftDecl('height', CssNum(0.857, 'em')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-[13px]', 3055, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(13, 'px')),
      RaftDecl('height', CssNum(13, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:stroke-2', 3060, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('stroke-width', CssNum(2))]),
  ]),
  RaftUtility('[&>svg]:stroke-[1.5]', 3061, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('stroke-width', CssNum(1.5))]),
  ]),
  RaftUtility('[&>svg]:stroke-[2.25]', 3062, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('stroke-width', CssNum(2.25))]),
  ]),
  RaftUtility(
    '[&>svg]:text-[oklch(0.476_0.114_61.907)]',
    3064,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v132)]),
    ],
  ),
  RaftUtility(
    '[&>svg]:text-[oklch(0.55_0.11_220)]',
    3063,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v133)]),
    ],
  ),
  RaftUtility('[&>svg]:text-black/45', 3065, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v135)]),
    RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v136)]),
  ]),
  RaftUtility('[&>svg]:text-danger', 3066, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v137)]),
  ]),
  RaftUtility('[&>svg]:text-foreground', 3067, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v14)]),
  ]),
  RaftUtility(
    '[&>svg]:text-foreground-icon',
    3068,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v138)]),
    ],
  ),
  RaftUtility(
    '[&>svg]:text-foreground-muted',
    3069,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v22)]),
    ],
  ),
  RaftUtility('[&>svg]:text-success', 3070, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v63)]),
  ]),
  RaftUtility('[&>svg]:top-[3px]', 3043, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('top', CssNum(3, 'px'))]),
  ]),
  RaftUtility('[&>svg]:w-auto', 3057, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('width', CssKeyword('auto'))]),
  ]),
  RaftUtility('[&>svg]:z-10', 3045, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('z-index', CssNum(10))]),
  ]),
  RaftUtility('[&>svg_*]:stroke-2', 3102, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg *', [], 1001, [RaftDecl('stroke-width', CssNum(2))]),
  ]),
  RaftUtility('[&>svg_*]:stroke-[1.5]', 3103, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg *', [], 1001, [RaftDecl('stroke-width', CssNum(1.5))]),
  ]),
  RaftUtility('[&>svg_*]:stroke-[2.25]', 3104, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg *', [], 1001, [RaftDecl('stroke-width', CssNum(2.25))]),
  ]),
  RaftUtility(
    '[&>svg~svg:last-child]:size-3',
    3111,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg ~ svg:last-child', [], 2002, [
        RaftDecl('width', CssNum(12, 'px')),
        RaftDecl('height', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>tr:last-child>td]:border-b-0',
    3113,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > tr:last-child > td', [], 2002, [
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>tr:last-child>th]:border-b-0',
    3114,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > tr:last-child > th', [], 2002, [
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&[data-ending-style]:not([data-swipe-direction])]:transform-[translateY(120%)_scale(0.98)]',
    3115,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style', 'not:data-swipe-direction'],
        3000,
        [
          RaftDecl('transform', CssSeq([_v139, _v140])),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-has-description]_[data-slot=toast-body]]:self-start',
    3116,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=toast-body]',
        ['data-has-description'],
        3000,
        [RaftDecl('align-self', _v141)],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-has-description]_[data-slot=toast-icon]]:self-start',
    3117,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=toast-icon]',
        ['data-has-description'],
        3000,
        [RaftDecl('align-self', _v141)],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-panel-open]_[data-slot=sidebar-section-chevron]]:rotate-90',
    3118,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=sidebar-section-chevron]',
        ['data-panel-open'],
        3000,
        [RaftDecl('rotate', CssNum(90, 'deg'))],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-panel-open]_[data-slot=system-message-group-chevron]]:-rotate-90',
    3119,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=system-message-group-chevron]',
        ['data-panel-open'],
        3000,
        [RaftDecl('rotate', CssNum(-90, 'deg'))],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-popup-open]_[data-slot=\'select-icon\']]:rotate-180',
    3120,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'select-icon\']',
        ['data-popup-open'],
        3000,
        [RaftDecl('rotate', CssNum(180, 'deg'))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-action=primary]:hover]:bg-brutal-cyan',
    2758,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-action=primary]:hover', [], 3000, [
        RaftDecl('background-color', CssColor(0xFF27CCF3)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-action=sort]:hover]:bg-transparent',
    2762,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-action=sort]:hover', [], 3000, [
        RaftDecl('background-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-action=sort]:hover]:border-transparent',
    2761,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-action=sort]:hover', [], 3000, [
        RaftDecl('border-top-color', _v7),
        RaftDecl('border-right-color', _v7),
        RaftDecl('border-bottom-color', _v7),
        RaftDecl('border-left-color', _v7),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-action=sort]:hover]:text-black',
    2763,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-action=sort]:hover', [], 3000, [
        RaftDecl('color', _v5),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-action=sort]:hover]:text-foreground-strong',
    2764,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-action=sort]:hover', [], 3000, [
        RaftDecl('color', _v0),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-action=sort]]:font-bold',
    2759,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-action=sort]', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(700)),
        RaftDecl('font-weight', CssNum(700)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-action=sort]]:font-medium',
    2760,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-action=sort]', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(500)),
        RaftDecl('font-weight', CssNum(500)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-show-all]:focus-visible]:text-foreground-muted',
    2768,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-show-all]:focus-visible', [], 3000, [
        RaftDecl('color', _v22),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-show-all]:focus-visible]:underline',
    2769,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-show-all]:focus-visible', [], 3000, [
        RaftDecl('text-decoration-line', CssKeyword('underline')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-show-all]:hover]:text-black',
    2770,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-show-all]:hover', [], 3000, [
        RaftDecl('color', _v5),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-show-all]:hover]:text-foreground-muted',
    2771,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-show-all]:hover', [], 3000, [
        RaftDecl('color', _v22),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-show-all]:hover]:underline',
    2772,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-show-all]:hover', [], 3000, [
        RaftDecl('text-decoration-line', CssKeyword('underline')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-show-all]]:font-black',
    2765,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(900)),
        RaftDecl('font-weight', CssNum(900)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-show-all]]:font-medium',
    2766,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(500)),
        RaftDecl('font-weight', CssNum(500)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-activity-inbox-show-all]]:tracking-normal',
    2767,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('--tw-tracking', CssNum(0, 'em')),
        RaftDecl('letter-spacing', CssNum(0, 'em')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-content=\'combobox\']>svg:not([class*=\'size-\'])]:size-3',
    2774,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-picker-trigger-content=\'combobox\'] > svg:not([class*=\'size-\'])',
        [],
        3001,
        [
          RaftDecl('width', CssNum(12, 'px')),
          RaftDecl('height', CssNum(12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-content=\'combobox\']>svg:not([class*=\'stroke-\'])]:stroke-[1.5]',
    2775,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-picker-trigger-content=\'combobox\'] > svg:not([class*=\'stroke-\'])',
        [],
        3001,
        [RaftDecl('stroke-width', CssNum(1.5))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-content=\'combobox\']>svg]:shrink-0',
    2773,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-picker-trigger-content=\'combobox\'] > svg',
        [],
        2001,
        [RaftDecl('flex-shrink', CssNum(0))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-content=\'select\']_svg:not([class*=\'size-\'])]:size-3.5',
    2777,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-picker-trigger-content=\'select\'] svg:not([class*=\'size-\'])',
        [],
        3001,
        [
          RaftDecl('width', CssNum(14, 'px')),
          RaftDecl('height', CssNum(14, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-content=\'select\']_svg:not([class*=\'stroke-\'])]:stroke-[1.5]',
    2778,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-picker-trigger-content=\'select\'] svg:not([class*=\'stroke-\'])',
        [],
        3001,
        [RaftDecl('stroke-width', CssNum(1.5))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-content=\'select\']_svg]:shrink-0',
    2776,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-picker-trigger-content=\'select\'] svg', [], 2001, [
        RaftDecl('flex-shrink', CssNum(0)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-content]>svg:not([class*=\'size-\'])]:size-3.5',
    2779,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-picker-trigger-content] > svg:not([class*=\'size-\'])',
        [],
        3001,
        [
          RaftDecl('width', CssNum(14, 'px')),
          RaftDecl('height', CssNum(14, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-indicator]>svg]:size-3',
    2780,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-picker-trigger-indicator] > svg', [], 2001, [
        RaftDecl('width', CssNum(12, 'px')),
        RaftDecl('height', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-indicator]>svg]:stroke-2',
    2781,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-picker-trigger-indicator] > svg', [], 2001, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-indicator]>svg_*]:stroke-2',
    2782,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-picker-trigger-indicator] > svg *', [], 2001, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-clear\']]:min-w-5',
    2784,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'combobox-clear\']', [], 2000, [
        RaftDecl('min-width', CssNum(20, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-clear\']]:size-5',
    2783,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'combobox-clear\']', [], 2000, [
        RaftDecl('width', CssNum(20, 'px')),
        RaftDecl('height', CssNum(20, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-trigger-indicator\']>svg]:shrink-0',
    2787,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'combobox-trigger-indicator\'] > svg',
        [],
        2001,
        [RaftDecl('flex-shrink', CssNum(0))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-trigger-indicator\']>svg]:size-3.5',
    2786,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'combobox-trigger-indicator\'] > svg',
        [],
        2001,
        [
          RaftDecl('width', CssNum(14, 'px')),
          RaftDecl('height', CssNum(14, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-trigger-indicator\']>svg]:stroke-[1.5]',
    2788,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'combobox-trigger-indicator\'] > svg',
        [],
        2001,
        [RaftDecl('stroke-width', CssNum(1.5))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-trigger-indicator\']>svg_*]:fill-none',
    2789,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'combobox-trigger-indicator\'] > svg *',
        [],
        2001,
        [RaftDecl('fill', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-trigger-indicator\']>svg_*]:stroke-[1.5]',
    2790,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'combobox-trigger-indicator\'] > svg *',
        [],
        2001,
        [RaftDecl('stroke-width', CssNum(1.5))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-trigger-indicator\']]:size-4',
    2785,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'combobox-trigger-indicator\']', [], 2000, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'select-trigger-content\']_svg:not([class*=\'size-\'])]:size-3.5',
    2792,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'select-trigger-content\'] svg:not([class*=\'size-\'])',
        [],
        3001,
        [
          RaftDecl('width', CssNum(14, 'px')),
          RaftDecl('height', CssNum(14, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'select-trigger-content\']_svg:not([class*=\'stroke-\'])]:stroke-[1.5]',
    2793,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'select-trigger-content\'] svg:not([class*=\'stroke-\'])',
        [],
        3001,
        [RaftDecl('stroke-width', CssNum(1.5))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'select-trigger-content\']_svg]:shrink-0',
    2791,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'select-trigger-content\'] svg', [], 2001, [
        RaftDecl('flex-shrink', CssNum(0)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'select-value\']]:font-medium',
    2794,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'select-value\']', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(500)),
        RaftDecl('font-weight', CssNum(500)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'select-value\']_svg:not([class*=\'stroke-\'])]:stroke-2',
    2795,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'select-value\'] svg:not([class*=\'stroke-\'])',
        [],
        3001,
        [RaftDecl('stroke-width', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'spinner\']]:size-3',
    2796,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'spinner\']', [], 2000, [
        RaftDecl('width', CssNum(12, 'px')),
        RaftDecl('height', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'spinner\']]:text-xs',
    2797,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'spinner\']', [], 2000, [
        RaftDecl('font-size', CssNum(12, 'px')),
        RaftDecl('line-height', _v143),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=avatar][data-size=md]>[data-slot=avatar-badge]]:-bottom-px',
    2803,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=avatar][data-size=md] > [data-slot=avatar-badge]',
        [],
        4000,
        [RaftDecl('bottom', CssNum(-1, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=avatar][data-size=md]>[data-slot=avatar-badge]]:-right-px',
    2802,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=avatar][data-size=md] > [data-slot=avatar-badge]',
        [],
        4000,
        [RaftDecl('right', CssNum(-1, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=avatar][data-size=md]]:border-0',
    2800,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=avatar][data-size=md]', [], 3000, [
        RaftDecl('border-top-style', _v31),
        RaftDecl('border-right-style', _v31),
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-left-style', _v31),
        RaftDecl('border-top-width', CssNum(0, 'px')),
        RaftDecl('border-right-width', CssNum(0, 'px')),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
        RaftDecl('border-left-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=avatar][data-size=md]]:mt-(--mi-avatar-shift,3px)',
    2798,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=avatar][data-size=md]', [], 3000, [
        RaftDecl('margin-top', _v144),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=avatar][data-size=md]]:size-(--mi-avatar,2rem)',
    2799,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=avatar][data-size=md]', [], 3000, [
        RaftDecl('width', _v145),
        RaftDecl('height', _v145),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=button]]:ease-out',
    2804,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=button]', [], 2000, [
        RaftDecl('--tw-ease', _v146),
        RaftDecl('transition-timing-function', _v146),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=button]_svg]:stroke-2',
    2805,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=button] svg', [], 2001, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=kbd]]:font-semibold',
    2813,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=kbd]', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(600)),
        RaftDecl('font-weight', CssNum(600)),
      ]),
    ],
  ),
  RaftUtility('[&_[data-slot=kbd]]:h-4', 2809, RaftUtilityStatus.descendant, [
    RaftLayer('& [data-slot=kbd]', [], 2000, [
      RaftDecl('height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&_[data-slot=kbd]]:min-w-4',
    2810,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=kbd]', [], 2000, [
        RaftDecl('min-width', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=kbd]]:ml-1.5',
    2808,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=kbd]', [], 2000, [
        RaftDecl('margin-left', CssNum(6, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&_[data-slot=kbd]]:px-1', 2811, RaftUtilityStatus.descendant, [
    RaftLayer('& [data-slot=kbd]', [], 2000, [
      RaftDecl('padding-left', CssNum(4, 'px')),
      RaftDecl('padding-right', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('[&_[data-slot=kbd]]:py-0', 2812, RaftUtilityStatus.descendant, [
    RaftLayer('& [data-slot=kbd]', [], 2000, [
      RaftDecl('padding-top', CssNum(0, 'px')),
      RaftDecl('padding-bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&_[data-slot=notification-center-trigger]]:-mr-2',
    2814,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=notification-center-trigger]', [], 2000, [
        RaftDecl('margin-right', CssNum(-8, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=panel-action]>svg]:size-3.5',
    2817,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=panel-action] > svg', [], 2001, [
        RaftDecl('width', CssNum(14, 'px')),
        RaftDecl('height', CssNum(14, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=panel-action]]:px-1.5',
    2815,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=panel-action]', [], 2000, [
        RaftDecl('padding-left', CssNum(6, 'px')),
        RaftDecl('padding-right', CssNum(6, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=panel-action]]:py-1.5',
    2816,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=panel-action]', [], 2000, [
        RaftDecl('padding-top', CssNum(6, 'px')),
        RaftDecl('padding-bottom', CssNum(6, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:font-black',
    2823,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(900)),
        RaftDecl('font-weight', CssNum(900)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:font-medium',
    2824,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(500)),
        RaftDecl('font-weight', CssNum(500)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:gap-2',
    2820,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('row-gap', CssNum(8, 'px')),
        RaftDecl('column-gap', CssNum(8, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:mb-1',
    2819,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('margin-bottom', CssNum(4, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:mt-5',
    2818,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('margin-top', CssNum(20, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:px-2',
    2821,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('padding-left', CssNum(8, 'px')),
        RaftDecl('padding-right', CssNum(8, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:py-0',
    2822,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('padding-top', CssNum(0, 'px')),
        RaftDecl('padding-bottom', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:tracking-widest',
    2825,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('--tw-tracking', CssNum(0.1, 'em')),
        RaftDecl('letter-spacing', CssNum(0.1, 'em')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=tabs-list]]:gap-0',
    2826,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=tabs-list]', [], 2000, [
        RaftDecl('row-gap', CssNum(0, 'px')),
        RaftDecl('column-gap', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=tabs-list]]:gap-2',
    2827,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=tabs-list]', [], 2000, [
        RaftDecl('row-gap', CssNum(8, 'px')),
        RaftDecl('column-gap', CssNum(8, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=task-card-status-label]]:gap-1',
    2831,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=task-card-status-label]', [], 2000, [
        RaftDecl('row-gap', CssNum(4, 'px')),
        RaftDecl('column-gap', CssNum(4, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=task-card]:hover]:bg-ink-2/3',
    2832,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=task-card]:hover', [], 3000, [
        RaftDecl('background-color', _v147),
      ]),
      RaftLayer('& [data-slot=task-card]:hover', [], 3000, [
        RaftDecl('background-color', _v149),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=toast-content][data-behind]]:opacity-0',
    2833,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=toast-content][data-behind]', [], 3000, [
        RaftDecl('opacity', CssNum(0, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=toast-content][data-expanded]]:opacity-100',
    2834,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=toast-content][data-expanded]', [], 3000, [
        RaftDecl('opacity', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility('[&_img]:bg-white', 2839, RaftUtilityStatus.descendant, [
    RaftLayer('& img', [], 1001, [RaftDecl('background-color', _v39)]),
  ]),
  RaftUtility('[&_img]:block', 2837, RaftUtilityStatus.descendant, [
    RaftLayer('& img', [], 1001, [RaftDecl('display', CssKeyword('block'))]),
  ]),
  RaftUtility('[&_img]:object-contain', 2840, RaftUtilityStatus.descendant, [
    RaftLayer('& img', [], 1001, [
      RaftDecl('object-fit', CssKeyword('contain')),
    ]),
  ]),
  RaftUtility('[&_img]:object-cover', 2841, RaftUtilityStatus.descendant, [
    RaftLayer('& img', [], 1001, [RaftDecl('object-fit', CssKeyword('cover'))]),
  ]),
  RaftUtility(
    '[&_img]:pointer-events-none',
    2836,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& img', [], 1001, [
        RaftDecl('pointer-events', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility('[&_img]:size-full', 2838, RaftUtilityStatus.descendant, [
    RaftLayer('& img', [], 1001, [
      RaftDecl('width', CssNum(100, '%')),
      RaftDecl('height', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility(
    '[&_pre_span]:text-(--shiki-dark,currentColor)',
    2842,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& pre span', [], 1002, [RaftDecl('color', _v150)]),
    ],
  ),
  RaftUtility(
    '[&_pre_span]:text-(--shiki-light,currentColor)',
    2843,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& pre span', [], 1002, [RaftDecl('color', _v151)]),
    ],
  ),
  RaftUtility('[&_strong]:font-bold', 2845, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [
      RaftDecl('--tw-font-weight', CssNum(700)),
      RaftDecl('font-weight', CssNum(700)),
    ]),
  ]),
  RaftUtility('[&_strong]:font-semibold', 2846, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [
      RaftDecl('--tw-font-weight', CssNum(600)),
      RaftDecl('font-weight', CssNum(600)),
    ]),
  ]),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-2.5',
    2894,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(10, 'px')),
        RaftDecl('height', CssNum(10, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-3',
    2895,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(12, 'px')),
        RaftDecl('height', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-3.5',
    2896,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(14, 'px')),
        RaftDecl('height', CssNum(14, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-4',
    2897,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-[13px]',
    2898,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(13, 'px')),
        RaftDecl('height', CssNum(13, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'stroke-\'])]:stroke-2',
    2899,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'stroke-\'])', [], 2001, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'stroke-\'])]:stroke-[1.5]',
    2900,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'stroke-\'])', [], 2001, [
        RaftDecl('stroke-width', CssNum(1.5)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg]:[vector-effect:non-scaling-stroke]',
    2882,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [RaftDecl('vector-effect', _v152)]),
    ],
  ),
  RaftUtility('[&_svg]:duration-150', 2879, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('--tw-duration', CssNum(150, 'ms')),
      RaftDecl('transition-duration', CssNum(150, 'ms')),
    ]),
  ]),
  RaftUtility('[&_svg]:duration-200', 2880, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('--tw-duration', CssNum(200, 'ms')),
      RaftDecl('transition-duration', CssNum(200, 'ms')),
    ]),
  ]),
  RaftUtility('[&_svg]:ease-out', 2881, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('--tw-ease', _v146),
      RaftDecl('transition-timing-function', _v146),
    ]),
  ]),
  RaftUtility(
    '[&_svg]:pointer-events-none',
    2847,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [
        RaftDecl('pointer-events', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility('[&_svg]:self-center', 2864, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('align-self', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('[&_svg]:shrink-0', 2861, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('flex-shrink', CssNum(0))]),
  ]),
  RaftUtility('[&_svg]:size-2.5', 2848, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(10, 'px')),
      RaftDecl('height', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-3', 2849, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(12, 'px')),
      RaftDecl('height', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-3.5', 2850, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(14, 'px')),
      RaftDecl('height', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-4', 2851, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(16, 'px')),
      RaftDecl('height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-4.5', 2852, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(18, 'px')),
      RaftDecl('height', CssNum(18, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-5', 2853, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(20, 'px')),
      RaftDecl('height', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-6', 2854, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(24, 'px')),
      RaftDecl('height', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-9', 2855, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(36, 'px')),
      RaftDecl('height', CssNum(36, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-[0.857em]', 2856, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(0.857, 'em')),
      RaftDecl('height', CssNum(0.857, 'em')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-[10px]', 2857, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(10, 'px')),
      RaftDecl('height', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-[11px]', 2858, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(11, 'px')),
      RaftDecl('height', CssNum(11, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-[13px]', 2859, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(13, 'px')),
      RaftDecl('height', CssNum(13, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-full', 2860, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(100, '%')),
      RaftDecl('height', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility('[&_svg]:stroke-2', 2865, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('stroke-width', CssNum(2))]),
  ]),
  RaftUtility('[&_svg]:stroke-3', 2866, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('stroke-width', CssNum(3))]),
  ]),
  RaftUtility('[&_svg]:stroke-4', 2867, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('stroke-width', CssNum(4))]),
  ]),
  RaftUtility('[&_svg]:stroke-[1.5]', 2868, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('stroke-width', CssNum(1.5))]),
  ]),
  RaftUtility('[&_svg]:stroke-[1.5px]', 2869, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('stroke-width', CssNum(1.5, 'px'))]),
  ]),
  RaftUtility('[&_svg]:stroke-[1px]', 2870, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('stroke-width', CssNum(1, 'px'))]),
  ]),
  RaftUtility('[&_svg]:stroke-[2.5]', 2871, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('stroke-width', CssNum(2.5))]),
  ]),
  RaftUtility('[&_svg]:text-black/70', 2872, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('color', _v154)]),
    RaftLayer('& svg', [], 1001, [RaftDecl('color', _v155)]),
  ]),
  RaftUtility(
    '[&_svg]:text-brutal-orange',
    2873,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [RaftDecl('color', CssColor(0xFFF8A16F))]),
    ],
  ),
  RaftUtility('[&_svg]:text-foreground', 2874, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('color', _v14)]),
  ]),
  RaftUtility(
    '[&_svg]:text-foreground-hint',
    2875,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [RaftDecl('color', _v156)]),
    ],
  ),
  RaftUtility(
    '[&_svg]:text-foreground-icon',
    2876,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [RaftDecl('color', _v138)]),
    ],
  ),
  RaftUtility(
    '[&_svg]:text-foreground-strong',
    2877,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [RaftDecl('color', _v0)]),
    ],
  ),
  RaftUtility('[&_svg]:transition-colors', 2878, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('transition-property', _v131),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('[&_svg]:translate-y-0', 2862, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('--tw-translate-y', CssNum(0, 'px')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility(
    '[&_svg]:translate-y-[0.5px]',
    2863,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [
        RaftDecl('--tw-translate-y', CssNum(0.5, 'px')),
        RaftDecl('translate', CssSeq([_v71, _v72])),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg_*]:[vector-effect:non-scaling-stroke]',
    2893,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg *', [], 1001, [RaftDecl('vector-effect', _v152)]),
    ],
  ),
  RaftUtility('[&_svg_*]:stroke-2', 2888, RaftUtilityStatus.descendant, [
    RaftLayer('& svg *', [], 1001, [RaftDecl('stroke-width', CssNum(2))]),
  ]),
  RaftUtility('[&_svg_*]:stroke-[1.5]', 2889, RaftUtilityStatus.descendant, [
    RaftLayer('& svg *', [], 1001, [RaftDecl('stroke-width', CssNum(1.5))]),
  ]),
  RaftUtility('[&_svg_*]:stroke-[1.5px]', 2890, RaftUtilityStatus.descendant, [
    RaftLayer('& svg *', [], 1001, [
      RaftDecl('stroke-width', CssNum(1.5, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg_*]:stroke-[1px]', 2891, RaftUtilityStatus.descendant, [
    RaftLayer('& svg *', [], 1001, [RaftDecl('stroke-width', CssNum(1, 'px'))]),
  ]),
  RaftUtility('[&_svg_*]:stroke-[2.5]', 2892, RaftUtilityStatus.descendant, [
    RaftLayer('& svg *', [], 1001, [RaftDecl('stroke-width', CssNum(2.5))]),
  ]),
  RaftUtility(
    '[&~[data-slot=input-group-control]]:pl-0',
    3121,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& ~ [data-slot=input-group-control]', [], 2000, [
        RaftDecl('padding-left', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--button-focus-ring:var(--accent-strong)]',
    1071,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--button-focus-ring', _v157)]),
    ],
  ),
  RaftUtility(
    '[--button-focus-ring:var(--danger)]',
    1072,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--button-focus-ring', _v137)]),
    ],
  ),
  RaftUtility(
    '[--button-focus-ring:var(--foreground)]',
    1073,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--button-focus-ring', _v14)]),
    ],
  ),
  RaftUtility(
    '[--button-focus-ring:var(--info)]',
    1074,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--button-focus-ring', _v62)]),
    ],
  ),
  RaftUtility(
    '[--button-focus-ring:var(--line-hairline)]',
    1075,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--button-focus-ring', _v158)]),
    ],
  ),
  RaftUtility(
    '[--button-focus-ring:var(--primary-strong)]',
    1076,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--button-focus-ring', _v159)]),
    ],
  ),
  RaftUtility(
    '[--button-focus-ring:var(--warning)]',
    1077,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--button-focus-ring', _v64)]),
    ],
  ),
  RaftUtility('[--ca-overlay-border:0px]', 1078, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--ca-overlay-border', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    '[--closed-transform:translate3d(var(--drawer-exit-x,0px),var(--drawer-exit-y,0px),0)]',
    1079,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--closed-transform', _v162)]),
    ],
  ),
  RaftUtility(
    '[--code-block-header-height:--spacing(8)]',
    1080,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--code-block-header-height', CssNum(32, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--code-block-header-height:--spacing(9)]',
    1081,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--code-block-header-height', CssNum(36, 'px')),
      ]),
    ],
  ),
  RaftUtility('[--drawer-blur:2px]', 1082, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--drawer-blur', CssNum(2, 'px'))]),
  ]),
  RaftUtility(
    '[--drawer-content-height:100dvh]',
    1083,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-content-height', CssNum(100, 'dvh')),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-content-height:var(--drawer-height,auto)]',
    1084,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-content-height', _v163)]),
    ],
  ),
  RaftUtility(
    '[--drawer-ease:var(--ease-slide)]',
    1085,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-ease', _v164)]),
    ],
  ),
  RaftUtility(
    '[--drawer-exit-x:calc(-100%-var(--drawer-inset)-2px)]',
    1086,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-exit-x', CssCalc(_v167)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-exit-x:calc(100%+var(--drawer-inset)+2px)]',
    1087,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-exit-x', CssCalc(_v169)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-exit-y:calc(-100%-var(--drawer-inset)-2px)]',
    1088,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-exit-y', CssCalc(_v167)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-exit-y:calc(100%+var(--drawer-inset)+2px)]',
    1089,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-exit-y', CssCalc(_v169)),
      ]),
    ],
  ),
  RaftUtility('[--drawer-inset:12px]', 1090, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--drawer-inset', CssNum(12, 'px'))]),
  ]),
  RaftUtility('[--drawer-inset:20px]', 1091, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--drawer-inset', CssNum(20, 'px'))]),
  ]),
  RaftUtility(
    '[--drawer-inset:max(12px,env(safe-area-inset-bottom,0px))]',
    1092,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-inset', _v172)]),
    ],
  ),
  RaftUtility(
    '[--drawer-inset:max(12px,env(safe-area-inset-top,0px))]',
    1093,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-inset', _v173)]),
    ],
  ),
  RaftUtility(
    '[--drawer-inset:max(20px,env(safe-area-inset-bottom,0px))]',
    1094,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-inset', _v174)]),
    ],
  ),
  RaftUtility(
    '[--drawer-overlay-min-opacity:0.5]',
    1095,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-overlay-min-opacity', CssNum(0.5)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-offset:max(0px,calc((var(--nested-drawers)-var(--drawer-stack-progress))*var(--drawer-stack-peek)))]',
    1096,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-stack-offset', _v180)]),
    ],
  ),
  RaftUtility('[--drawer-stack-peek:16px]', 1097, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--drawer-stack-peek', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility(
    '[--drawer-stack-progress:clamp(0,var(--drawer-swipe-progress),1)]',
    1098,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-stack-progress', _v182)]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-scale-base:calc(max(0,1-(var(--nested-drawers)*var(--drawer-stack-step))))]',
    1099,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-scale-base', CssCalc(_v186)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-scale:clamp(0,calc(var(--drawer-stack-scale-base)+(var(--drawer-stack-step)*var(--drawer-stack-progress))),1)]',
    1100,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-stack-scale', _v190)]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-shrink-offset:calc(var(--drawer-stack-shrink)*var(--drawer-stack-size))]',
    1101,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-shrink-offset', CssCalc(_v193)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-shrink:calc(1-var(--drawer-stack-scale))]',
    1102,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-shrink', CssCalc(_v195)),
      ]),
    ],
  ),
  RaftUtility('[--drawer-stack-size:100%]', 1103, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--drawer-stack-size', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility(
    '[--drawer-stack-size:max(0px,var(--drawer-frontmost-height,var(--drawer-height)))]',
    1104,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-stack-size', _v198)]),
    ],
  ),
  RaftUtility('[--drawer-stack-step:0.05]', 1105, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--drawer-stack-step', CssNum(0.05)),
    ]),
  ]),
  RaftUtility(
    '[--drawer-stack-x:calc(0px-var(--drawer-stack-offset)-var(--drawer-stack-shrink-offset))]',
    1106,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-x', CssCalc(_v202)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-x:calc(var(--drawer-stack-offset)+var(--drawer-stack-shrink-offset))]',
    1107,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-x', CssCalc(_v203)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-y:calc(0px-var(--drawer-stack-offset)-var(--drawer-stack-shrink-offset))]',
    1108,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-y', CssCalc(_v202)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-y:calc(var(--drawer-stack-offset)+var(--drawer-stack-shrink-offset))]',
    1109,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-y', CssCalc(_v203)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-swipe-x:var(--drawer-swipe-movement-x)]',
    1110,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-swipe-x', _v204)]),
    ],
  ),
  RaftUtility(
    '[--drawer-swipe-y:calc(var(--drawer-snap-point-offset,0px)+var(--drawer-swipe-movement-y))]',
    1111,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-swipe-y', CssCalc(_v207)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-transform-origin:0%_50%]',
    1112,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-transform-origin', _v208),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-transform-origin:100%_50%]',
    1115,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-transform-origin', _v209),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-transform-origin:50%_0%]',
    1113,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-transform-origin', _v210),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-transform-origin:50%_100%]',
    1114,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-transform-origin', _v211),
      ]),
    ],
  ),
  RaftUtility(
    '[--ig-addon-fg-default:var(--foreground-placeholder)]',
    1116,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--ig-addon-fg-default', _v58)]),
    ],
  ),
  RaftUtility(
    '[--ig-text-fg-default:var(--foreground-placeholder)]',
    1117,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--ig-text-fg-default', _v58)]),
    ],
  ),
  RaftUtility(
    '[--panel-footer-clearance:0rem]',
    1118,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--panel-footer-clearance', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--panel-footer-clearance:10rem]',
    1119,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--panel-footer-clearance', CssNum(160, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--color-accent-400)]',
    1120,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v212)]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--color-danger)]',
    1121,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v137)]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--color-info)]',
    1122,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v62)]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--color-primary-400)]',
    1123,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v118)]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--color-success)]',
    1124,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v63)]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--color-warning)]',
    1125,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v64)]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--foreground)]',
    1126,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v14)]),
    ],
  ),
  RaftUtility(
    '[--progress-indicator:color-mix(in_oklab,var(--progress-color)_90%,transparent)]',
    1127,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-indicator', _v213)]),
      RaftLayer('self', [], 1000, [RaftDecl('--progress-indicator', _v215)]),
    ],
  ),
  RaftUtility(
    '[--progress-indicator:var(--progress-color)]',
    1128,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-indicator', _v213)]),
    ],
  ),
  RaftUtility(
    '[--progress-light:var(--color-accent-200)]',
    1129,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-light', _v216)]),
    ],
  ),
  RaftUtility(
    '[--progress-light:var(--color-danger-muted)]',
    1130,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-light', _v217)]),
    ],
  ),
  RaftUtility(
    '[--progress-light:var(--color-info-muted)]',
    1131,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-light', _v218)]),
    ],
  ),
  RaftUtility(
    '[--progress-light:var(--color-primary-200)]',
    1132,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-light', _v219)]),
    ],
  ),
  RaftUtility(
    '[--progress-light:var(--color-success-muted)]',
    1133,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-light', _v220)]),
    ],
  ),
  RaftUtility(
    '[--progress-light:var(--color-warning-muted)]',
    1134,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-light', _v221)]),
    ],
  ),
  RaftUtility(
    '[--progress-light:var(--fill-muted)]',
    1135,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-light', _v222)]),
    ],
  ),
  RaftUtility(
    '[--progress-sweep:color-mix(in_oklab,var(--progress-color)_40%,transparent)]',
    1136,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-sweep', _v213)]),
      RaftLayer('self', [], 1000, [RaftDecl('--progress-sweep', _v224)]),
    ],
  ),
  RaftUtility(
    '[--progress-track:color-mix(in_oklab,var(--line-muted)_35%,var(--layer-panel))]',
    1137,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-track', _v81)]),
      RaftLayer('self', [], 1000, [RaftDecl('--progress-track', _v226)]),
    ],
  ),
  RaftUtility(
    '[--progress-track:var(--fill-muted)]',
    1138,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-track', _v222)]),
    ],
  ),
  RaftUtility(
    '[--reference-badge-ink:var(--color-foreground-inverse)]',
    1139,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--reference-badge-ink', _v227)]),
    ],
  ),
  RaftUtility(
    '[--reference-badge:var(--accent-strong)]',
    1140,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--reference-badge', _v157)]),
    ],
  ),
  RaftUtility(
    '[--reference-badge:var(--color-foreground-muted)]',
    1141,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--reference-badge', _v22)]),
    ],
  ),
  RaftUtility(
    '[--reference-badge:var(--info-strong)]',
    1142,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--reference-badge', _v228)]),
    ],
  ),
  RaftUtility(
    '[--reference-icon:var(--color-brutal-cyan)]',
    1143,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--reference-icon', CssColor(0xFF27CCF3)),
      ]),
    ],
  ),
  RaftUtility(
    '[--reference-icon:var(--color-brutal-pink)]',
    1144,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--reference-icon', CssColor(0xFFFE7DA8)),
      ]),
    ],
  ),
  RaftUtility(
    '[--reference-icon:var(--color-brutal-stone)]',
    1145,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--reference-icon', CssColor(0xFFC0B9B1)),
      ]),
    ],
  ),
  RaftUtility(
    '[--shell-header-height:56px]',
    1146,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--shell-header-height', CssNum(56, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--shell-header-height:62px]',
    1147,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--shell-header-height', CssNum(62, 'px')),
      ]),
    ],
  ),
  RaftUtility('[--sidebar-inset-x:28px]', 1148, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--sidebar-inset-x', CssNum(28, 'px')),
    ]),
  ]),
  RaftUtility(
    '[--status-color:var(--color-accent-400)]',
    1149,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v212)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--color-brutal-lime)]',
    1150,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--status-color', CssColor(0xFFA9D877)),
      ]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--color-danger)]',
    1151,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v137)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--color-gray-400)]',
    1152,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v229)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--color-info)]',
    1153,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v62)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--color-primary-400)]',
    1154,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v118)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--color-secondary-400)]',
    1155,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v230)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--color-success)]',
    1156,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v63)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--color-warning)]',
    1157,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v64)]),
    ],
  ),
  RaftUtility('[--toast-gap:0.5rem]', 1158, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--toast-gap', CssNum(8, 'px'))]),
  ]),
  RaftUtility(
    '[--toast-gradient-border-angle:to_bottom]',
    1159,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--toast-gradient-border-angle', _v96),
      ]),
    ],
  ),
  RaftUtility(
    '[--toast-gradient-border-from:oklch(1_0_0/0.1)]',
    1160,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--toast-gradient-border-from', _v100),
      ]),
    ],
  ),
  RaftUtility(
    '[--toast-gradient-border-to:oklch(1_0_0/0)]',
    1161,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--toast-gradient-border-to', _v231),
      ]),
    ],
  ),
  RaftUtility(
    '[--toast-gradient-border-via:oklch(1_0_0/0.05)]',
    1162,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--toast-gradient-border-via', _v232),
      ]),
    ],
  ),
  RaftUtility('[--toast-peek-dir:-1]', 1163, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--toast-peek-dir', CssNum(-1))]),
  ]),
  RaftUtility('[--toast-peek:0.5rem]', 1164, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--toast-peek', CssNum(8, 'px'))]),
  ]),
  RaftUtility(
    '[--toast-scale:calc(max(0.84,1-(var(--toast-index)*0.04)))]',
    1165,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--toast-scale', CssCalc(_v235))]),
    ],
  ),
  RaftUtility(
    '[--toast-stack-height:var(--toast-frontmost-height,var(--toast-height))]',
    1166,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--toast-stack-height', _v237)]),
    ],
  ),
  RaftUtility(
    '[--toast-y:calc((var(--toast-offset-y)*-1)-(var(--toast-index)*var(--toast-gap))+var(--toast-swipe-movement-y))]',
    1167,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--toast-y', CssCalc(_v243))]),
    ],
  ),
  RaftUtility(
    '[-webkit-mask-image:radial-gradient(circle_at_96%_12%,black_0%,black_24%,oklch(0_0_0/0.82)_38%,oklch(0_0_0/0.38)_58%,transparent_74%)]',
    1168,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('-webkit-mask-image', _v253)]),
    ],
  ),
  RaftUtility(
    '[-webkit-overflow-scrolling:touch]',
    1169,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('-webkit-overflow-scrolling', CssKeyword('touch')),
      ]),
    ],
  ),
  RaftUtility('[@media(hover:none)]:h-6', 3122, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover-none'],
      1000,
      [RaftDecl('height', CssNum(24, 'px'))],
    ),
  ]),
  RaftUtility(
    '[@media(hover:none)]:opacity-100',
    3124,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover-none'],
        1000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility('[@media(hover:none)]:w-6', 3123, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover-none'],
      1000,
      [RaftDecl('width', CssNum(24, 'px'))],
    ),
  ]),
  RaftUtility(
    '[@media(max-height:600px)]:h-(--shell-header-height,62px)',
    3125,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['height<=600'], 1000, [RaftDecl('height', _v254)]),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:h-12',
    3126,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600'],
        1000,
        [RaftDecl('height', CssNum(48, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:h-auto',
    3127,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600'],
        1000,
        [RaftDecl('height', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:pb-1',
    3129,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600'],
        1000,
        [RaftDecl('padding-bottom', CssNum(4, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:py-1',
    3128,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600'],
        1000,
        [
          RaftDecl('padding-top', CssNum(4, 'px')),
          RaftDecl('padding-bottom', CssNum(4, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=banner-description]~[data-slot=banner-title]~&]:row-span-2',
    3132,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'ancestor:data-slot=banner-description',
          'ancestor:data-slot=banner-title',
        ],
        3000,
        [RaftDecl('grid-row', _v73)],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=banner-title]+[data-slot=banner-description]~&]:row-span-2',
    3133,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'ancestor:data-slot=banner-description',
          'ancestor:data-slot=banner-title',
        ],
        3000,
        [RaftDecl('grid-row', _v73)],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=banner-title]~[data-slot=banner-description]~&]:row-span-2',
    3134,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'ancestor:data-slot=banner-description',
          'ancestor:data-slot=banner-title',
        ],
        3000,
        [RaftDecl('grid-row', _v73)],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=code-block-body]>&]:absolute',
    3135,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=code-block-body'],
        2000,
        [RaftDecl('position', CssKeyword('absolute'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=code-block-body]>&]:right-2',
    3137,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=code-block-body'],
        2000,
        [RaftDecl('right', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=code-block-body]>&]:top-2',
    3136,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=code-block-body'],
        2000,
        [RaftDecl('top', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=code-block-body]>&]:z-10',
    3138,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=code-block-body'],
        2000,
        [RaftDecl('z-index', CssNum(10))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-toast-placement^=top]_&[data-ending-style]:not([data-swipe-direction])]:transform-[translateY(-120%)_scale(0.98)]',
    3139,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'ancestor:data-toast-placement^=top',
          'data-ending-style',
          'not:data-swipe-direction',
        ],
        4000,
        [
          RaftDecl('transform', CssSeq([_v255, _v140])),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[[data-toast-placement^=top]_&[data-starting-style]]:transform-[translateY(-120%)_scale(0.98)]',
    3140,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-toast-placement^=top', 'data-starting-style'],
        3000,
        [
          RaftDecl('transform', CssSeq([_v255, _v140])),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[border-width:var(--ca-overlay-border,2px)]',
    453,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-width', _v256),
        RaftDecl('border-right-width', _v256),
        RaftDecl('border-bottom-width', _v256),
        RaftDecl('border-left-width', _v256),
      ]),
    ],
  ),
  RaftUtility(
    '[clip-path:inset(0_0_0_100%_round_9999px_0_0_9999px)]',
    1170,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('clip-path', _v258)]),
    ],
  ),
  RaftUtility('[font-size:0.875em]', 776, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(0.875, 'em'))]),
  ]),
  RaftUtility('[font-size:inherit]', 777, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssKeyword('inherit'))]),
  ]),
  RaftUtility('[font:inherit]', 1171, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font', CssKeyword('inherit'))]),
  ]),
  RaftUtility('[overflow-anchor:auto]', 1172, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-anchor', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility(
    '[pointer-events:var(--mi-toolbar-pe,none)]',
    1,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('pointer-events', _v259)]),
    ],
  ),
  RaftUtility(
    '[text-shadow:0_1px_1px_oklch(0.25_0.08_20/0.45)]',
    1173,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('text-shadow', _v261)]),
    ],
  ),
  RaftUtility('absolute', 6, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('position', CssKeyword('absolute'))]),
  ]),
  RaftUtility('active:-translate-y-px', 1570, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [
        RaftDecl('--tw-translate-y', CssNum(-1, 'px')),
        RaftDecl('translate', CssSeq([_v71, _v72])),
      ],
    ),
  ]),
  RaftUtility('active:bg-black/10', 1580, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v263)]),
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v264)]),
  ]),
  RaftUtility('active:bg-black/8', 1579, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v266)]),
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v267)]),
  ]),
  RaftUtility('active:bg-brutal-pink/20', 1581, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v269)]),
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v270)]),
  ]),
  RaftUtility('active:bg-brutal-yellow/50', 1582, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v272)]),
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v273)]),
  ]),
  RaftUtility('active:bg-fill-strong', 1583, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v115)]),
  ]),
  RaftUtility('active:bg-fill-strong/80', 1584, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v115)]),
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v117)]),
  ]),
  RaftUtility('active:bg-ink-16', 1587, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v274)]),
  ]),
  RaftUtility('active:bg-ink-6', 1585, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v275)]),
  ]),
  RaftUtility('active:bg-ink-8', 1586, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v276)]),
  ]),
  RaftUtility('active:bg-white', 1588, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v39)]),
  ]),
  RaftUtility('active:border-black', 1577, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [
        RaftDecl('border-top-color', _v5),
        RaftDecl('border-right-color', _v5),
        RaftDecl('border-bottom-color', _v5),
        RaftDecl('border-left-color', _v5),
      ],
    ),
  ]),
  RaftUtility('active:border-transparent', 1578, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [
        RaftDecl('border-top-color', _v7),
        RaftDecl('border-right-color', _v7),
        RaftDecl('border-bottom-color', _v7),
        RaftDecl('border-left-color', _v7),
      ],
    ),
  ]),
  RaftUtility('active:cursor-grabbing', 1576, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [RaftDecl('cursor', CssKeyword('grabbing'))],
    ),
  ]),
  RaftUtility(
    'active:not-data-[haspopup]:translate-x-0',
    1598,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'not:data-haspopup'],
        3000,
        [
          RaftDecl('--tw-translate-x', CssNum(0, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'active:not-data-haspopup:-translate-y-1/2',
    1596,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'not:data-haspopup'],
        3000,
        [
          RaftDecl('--tw-translate-y', CssNum(-50, '%')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'active:not-data-haspopup:scale-100',
    1597,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'not:data-haspopup'],
        3000,
        [
          RaftDecl('--tw-scale-x', CssNum(100, '%')),
          RaftDecl('--tw-scale-y', CssNum(100, '%')),
          RaftDecl('--tw-scale-z', CssNum(100, '%')),
          RaftDecl('scale', _v277),
        ],
      ),
    ],
  ),
  RaftUtility('active:scale-100', 1572, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [
        RaftDecl('--tw-scale-x', CssNum(100, '%')),
        RaftDecl('--tw-scale-y', CssNum(100, '%')),
        RaftDecl('--tw-scale-z', CssNum(100, '%')),
        RaftDecl('scale', _v277),
      ],
    ),
  ]),
  RaftUtility('active:scale-[0.96]', 1573, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('scale', CssNum(0.96))]),
  ]),
  RaftUtility('active:scale-[0.97]', 1574, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('scale', CssNum(0.97))]),
  ]),
  RaftUtility('active:scale-[0.985]', 1575, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('scale', CssNum(0.985))]),
  ]),
  RaftUtility('active:shadow-none', 1591, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('active:shadow-raft-md', 1592, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [RaftDecl('--tw-shadow', _v61), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('active:shadow-raft-sm', 1593, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('active:shadow-raft-xs', 1594, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [RaftDecl('--tw-shadow', _v279), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('active:text-foreground', 1589, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('color', _v14)]),
  ]),
  RaftUtility(
    'active:text-foreground-strong',
    1590,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['active'], 2000, [RaftDecl('color', _v0)]),
    ],
  ),
  RaftUtility('active:translate-px', 1568, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [
        RaftDecl('--tw-translate-x', CssNum(1, 'px')),
        RaftDecl('--tw-translate-y', CssNum(1, 'px')),
        RaftDecl('translate', CssSeq([_v71, _v72])),
      ],
    ),
  ]),
  RaftUtility('active:translate-x-0', 1569, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [
        RaftDecl('--tw-translate-x', CssNum(0, 'px')),
        RaftDecl('translate', CssSeq([_v71, _v72])),
      ],
    ),
  ]),
  RaftUtility('active:translate-y-0', 1571, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [
        RaftDecl('--tw-translate-y', CssNum(0, 'px')),
        RaftDecl('translate', CssSeq([_v71, _v72])),
      ],
    ),
  ]),
  RaftUtility('after:-inset-x-3', 1375, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(-12, 'px')),
      RaftDecl('right', CssNum(-12, 'px')),
    ]),
  ]),
  RaftUtility('after:-inset-y-2', 1377, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(-8, 'px')),
      RaftDecl('bottom', CssNum(-8, 'px')),
    ]),
  ]),
  RaftUtility('after:absolute', 1373, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('position', CssKeyword('absolute')),
    ]),
  ]),
  RaftUtility('after:bg-linear-to-t', 1385, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-gradient-position', _v280),
      RaftDecl('background-image', _v282),
    ]),
    RaftLayer('::after', [], 1001, [RaftDecl('--tw-gradient-position', _v283)]),
  ]),
  RaftUtility('after:border', 1383, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-right-style', _v31),
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-left-style', _v31),
      RaftDecl('border-top-width', CssNum(1, 'px')),
      RaftDecl('border-right-width', CssNum(1, 'px')),
      RaftDecl('border-bottom-width', CssNum(1, 'px')),
      RaftDecl('border-left-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility(
    'after:border-[oklch(1_0_0/0.2)]',
    1384,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('border-top-color', _v284),
        RaftDecl('border-right-color', _v284),
        RaftDecl('border-bottom-color', _v284),
        RaftDecl('border-left-color', _v284),
      ]),
    ],
  ),
  RaftUtility('after:bottom-0', 1378, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('after:content-[\'\']', 1395, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('--tw-content', CssString('')),
      RaftDecl('content', CssVar('--tw-content')),
    ]),
  ]),
  RaftUtility('after:from-layer-panel', 1386, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-gradient-from', _v38),
      RaftDecl('--tw-gradient-stops', _v291),
    ]),
  ]),
  RaftUtility('after:from-white', 1387, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-gradient-from', _v39),
      RaftDecl('--tw-gradient-stops', _v291),
    ]),
  ]),
  RaftUtility('after:h-10', 1380, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(40, 'px')),
    ]),
  ]),
  RaftUtility('after:hidden', 1379, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('display', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('after:inset-0', 1374, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
      RaftDecl('bottom', CssNum(0, 'px')),
      RaftDecl('left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('after:inset-x-0', 1376, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('after:mix-blend-overlay', 1392, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('mix-blend-mode', CssKeyword('overlay')),
    ]),
  ]),
  RaftUtility('after:pointer-events-none', 1372, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('pointer-events', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('after:ring-1', 1393, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-ring-shadow', _v293),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('after:ring-white/35', 1394, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-ring-color', _v295),
    ]),
    RaftLayer('::after', [], 1001, [RaftDecl('--tw-ring-color', _v296)]),
  ]),
  RaftUtility('after:rounded-[inherit]', 1381, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', CssKeyword('inherit')),
      RaftDecl('border-top-right-radius', CssKeyword('inherit')),
      RaftDecl('border-bottom-right-radius', CssKeyword('inherit')),
      RaftDecl('border-bottom-left-radius', CssKeyword('inherit')),
    ]),
  ]),
  RaftUtility('after:rounded-sm', 1382, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', CssNum(4, 'px')),
      RaftDecl('border-top-right-radius', CssNum(4, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(4, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('after:to-layer-panel/0', 1390, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-gradient-to', _v38),
      RaftDecl('--tw-gradient-stops', _v291),
    ]),
    RaftLayer('::after', [], 1001, [RaftDecl('--tw-gradient-to', _v298)]),
  ]),
  RaftUtility('after:to-white/0', 1391, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-gradient-to', _v300),
      RaftDecl('--tw-gradient-stops', _v291),
    ]),
    RaftLayer('::after', [], 1001, [RaftDecl('--tw-gradient-to', _v301)]),
  ]),
  RaftUtility('after:via-layer-panel/80', 1388, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-gradient-via', _v38),
      RaftDecl('--tw-gradient-via-stops', _v304),
      RaftDecl('--tw-gradient-stops', _v305),
    ]),
    RaftLayer('::after', [], 1001, [RaftDecl('--tw-gradient-via', _v307)]),
  ]),
  RaftUtility('after:via-white/80', 1389, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-gradient-via', _v309),
      RaftDecl('--tw-gradient-via-stops', _v304),
      RaftDecl('--tw-gradient-stops', _v305),
    ]),
    RaftLayer('::after', [], 1001, [RaftDecl('--tw-gradient-via', _v310)]),
  ]),
  RaftUtility('align-baseline', 758, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('vertical-align', CssKeyword('baseline')),
    ]),
  ]),
  RaftUtility('align-bottom', 759, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('vertical-align', CssKeyword('bottom')),
    ]),
  ]),
  RaftUtility('align-middle', 760, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('vertical-align', CssKeyword('middle')),
    ]),
  ]),
  RaftUtility('align-top', 761, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('vertical-align', CssKeyword('top')),
    ]),
  ]),
  RaftUtility(
    'animate-[raft-status-pulse-background_1.4s_ease-out_infinite]',
    331,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('animation', _v312)]),
    ],
  ),
  RaftUtility(
    'animate-[raft-toast-timeout-progress_var(--toast-progress-duration)_linear_forwards]',
    332,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('animation', _v315)]),
    ],
  ),
  RaftUtility('animate-pulse', 333, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('animation', _v317)]),
  ]),
  RaftUtility('animate-spin', 334, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('animation', _v318)]),
  ]),
  RaftUtility('antialiased', 955, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('-webkit-font-smoothing', _v319),
      RaftDecl('-moz-osx-font-smoothing', CssKeyword('grayscale')),
    ]),
  ]),
  RaftUtility(
    'aria-disabled:active:scale-none',
    1837,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'aria-disabled=true'],
        3000,
        [RaftDecl('scale', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:active:shadow-raft-sm',
    1838,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'aria-disabled=true'],
        3000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:active:translate-none',
    1836,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'aria-disabled=true'],
        3000,
        [RaftDecl('translate', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:cursor-not-allowed',
    1819,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true'],
        2000,
        [RaftDecl('cursor', _v320)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:dark:hover:bg-[oklch(0.37_0.06_27)]',
    2693,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark', 'hover'],
        3000,
        [RaftDecl('background-color', _v321)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:dark:hover:bg-[oklch(0.58_0.21_27)]',
    2694,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark', 'hover'],
        3000,
        [RaftDecl('background-color', _v322)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:dark:hover:bg-[oklch(0.66_0.17_46)]',
    2695,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark', 'hover'],
        3000,
        [RaftDecl('background-color', _v323)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:dark:hover:bg-fill-muted',
    2696,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark', 'hover'],
        3000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:dark:hover:bg-info-strong',
    2697,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark', 'hover'],
        3000,
        [RaftDecl('background-color', _v228)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:dark:hover:bg-ink',
    2698,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark', 'hover'],
        3000,
        [RaftDecl('background-color', _v324)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:dark:hover:bg-layer-panel',
    2699,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark', 'hover'],
        3000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:bg-accent-soft',
    1824,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v325)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:bg-danger',
    1825,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v137)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:bg-danger-soft',
    1826,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v326)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:bg-fill-muted',
    1827,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:bg-foreground',
    1828,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v14)],
      ),
    ],
  ),
  RaftUtility('aria-disabled:hover:bg-info', 1829, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-disabled=true', 'hover'],
      3000,
      [RaftDecl('background-color', _v62)],
    ),
  ]),
  RaftUtility(
    'aria-disabled:hover:bg-layer-panel',
    1830,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:bg-primary-soft',
    1831,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v327)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:bg-transparent',
    1832,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v7)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:bg-warning',
    1833,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v64)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:border-line-strong',
    1822,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v43),
          RaftDecl('border-right-color', _v43),
          RaftDecl('border-bottom-color', _v43),
          RaftDecl('border-left-color', _v43),
        ],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:border-transparent',
    1823,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v7),
          RaftDecl('border-right-color', _v7),
          RaftDecl('border-bottom-color', _v7),
          RaftDecl('border-left-color', _v7),
        ],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:no-underline',
    1834,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('text-decoration-line', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:shadow-raft-sm',
    1835,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:translate-none',
    1821,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true', 'hover'],
        3000,
        [RaftDecl('translate', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility('aria-disabled:opacity-40', 1820, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-disabled=true'],
      2000,
      [RaftDecl('opacity', CssNum(40, '%'))],
    ),
  ]),
  RaftUtility(
    'aria-disabled:transform-none',
    1818,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true'],
        2000,
        [RaftDecl('transform', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility('aspect-video', 143, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('aspect-ratio', _v328)]),
  ]),
  RaftUtility('auto-cols-fr', 349, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-auto-columns', _v106)]),
  ]),
  RaftUtility('auto-rows-[7rem]', 351, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('grid-auto-rows', CssNum(112, 'px')),
    ]),
  ]),
  RaftUtility('auto-rows-[8rem]', 352, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('grid-auto-rows', CssNum(128, 'px')),
    ]),
  ]),
  RaftUtility('auto-rows-min', 353, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-auto-rows', _v329)]),
  ]),
  RaftUtility('backdrop-blur-2xl', 1020, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-backdrop-blur', _v330),
      RaftDecl('-webkit-backdrop-filter', _v340),
      RaftDecl('backdrop-filter', _v340),
    ]),
  ]),
  RaftUtility('backdrop-blur-[10px]', 1022, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-backdrop-blur', _v341),
      RaftDecl('-webkit-backdrop-filter', _v340),
      RaftDecl('backdrop-filter', _v340),
    ]),
  ]),
  RaftUtility('backdrop-blur-[2px]', 1021, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-backdrop-blur', _v342),
      RaftDecl('-webkit-backdrop-filter', _v340),
      RaftDecl('backdrop-filter', _v340),
    ]),
  ]),
  RaftUtility('backdrop-blur-md', 1023, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-backdrop-blur', _v343),
      RaftDecl('-webkit-backdrop-filter', _v340),
      RaftDecl('backdrop-filter', _v340),
    ]),
  ]),
  RaftUtility('basis-0', 306, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-basis', CssNum(0, 'px'))]),
  ]),
  RaftUtility('before:-inset-1', 1325, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(-4, 'px')),
      RaftDecl('right', CssNum(-4, 'px')),
      RaftDecl('bottom', CssNum(-4, 'px')),
      RaftDecl('left', CssNum(-4, 'px')),
    ]),
  ]),
  RaftUtility('before:-translate-1/2', 1346, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-translate-x', CssNum(-50, '%')),
      RaftDecl('--tw-translate-y', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility('before:-translate-x-1/2', 1347, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-translate-x', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility('before:-translate-y-1/2', 1348, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-translate-y', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility(
    'before:[-webkit-mask-composite:source-in]',
    1370,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('-webkit-mask-composite', CssKeyword('source-in')),
      ]),
    ],
  ),
  RaftUtility(
    'before:[-webkit-mask-image:linear-gradient(to_top,black_50%,transparent),linear-gradient(to_right,transparent,black_24px,black_calc(100%-24px),transparent)]',
    1371,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('-webkit-mask-image', CssList([_v345, _v350])),
      ]),
    ],
  ),
  RaftUtility('before:absolute', 1324, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('position', CssKeyword('absolute')),
    ]),
  ]),
  RaftUtility('before:backdrop-blur-[4px]', 1366, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-backdrop-blur', _v351),
      RaftDecl('-webkit-backdrop-filter', _v340),
      RaftDecl('backdrop-filter', _v340),
    ]),
  ]),
  RaftUtility(
    'before:bg-[linear-gradient(in_oklab_180deg,oklab(0%_0_0/0%)_30%,oklab(0%_0_0/1%)_100%)]',
    1356,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-image', _v357),
      ]),
    ],
  ),
  RaftUtility(
    'before:bg-[linear-gradient(in_oklab_180deg,oklab(100%_0_0/10%)_0%,oklab(0%_0_0/0%)_100%)]',
    1361,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-image', _v361),
      ]),
    ],
  ),
  RaftUtility(
    'before:bg-[linear-gradient(in_oklab_180deg,oklab(100%_0_0/4%)_0%,oklab(0%_0_0/0%)_100%)]',
    1357,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-image', _v364),
      ]),
    ],
  ),
  RaftUtility(
    'before:bg-[linear-gradient(in_oklab_180deg,oklab(100%_0_0/5%)_0%,oklab(0%_0_0/1%)_100%)]',
    1358,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-image', _v367),
      ]),
    ],
  ),
  RaftUtility(
    'before:bg-[linear-gradient(in_oklab_180deg,oklab(100%_0_0/8%)_0%,oklab(0%_0_0/0%)_100%)]',
    1359,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-image', _v370),
      ]),
    ],
  ),
  RaftUtility(
    'before:bg-[linear-gradient(in_oklab_180deg,oklab(100%_0_0/8%)_0%,oklab(0%_0_0/3%)_100%)]',
    1360,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-image', _v373),
      ]),
    ],
  ),
  RaftUtility(
    'before:bg-[linear-gradient(to_bottom,transparent,var(--layer-panel))]',
    1362,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-image', _v374),
      ]),
    ],
  ),
  RaftUtility('before:bg-black/10', 1352, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v263),
    ]),
    RaftLayer('::before', [], 1001, [RaftDecl('background-color', _v264)]),
  ]),
  RaftUtility('before:bg-ink-10', 1353, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v12),
    ]),
  ]),
  RaftUtility('before:bg-ink-20', 1354, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v375),
    ]),
  ]),
  RaftUtility('before:bg-ink-40', 1355, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v376),
    ]),
  ]),
  RaftUtility('before:bottom-0', 1332, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('before:bottom-3', 1333, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('bottom', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('before:content-[\'\']', 1368, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('--tw-content', CssString('')),
      RaftDecl('content', CssVar('--tw-content')),
    ]),
  ]),
  RaftUtility('before:content-[\'»\']', 1369, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('--tw-content', CssString('»')),
      RaftDecl('content', CssVar('--tw-content')),
    ]),
  ]),
  RaftUtility('before:h-1.5', 1338, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('before:h-12', 1340, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(48, 'px')),
    ]),
  ]),
  RaftUtility('before:h-36', 1341, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(144, 'px')),
    ]),
  ]),
  RaftUtility('before:h-6', 1339, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility(
    'before:h-[calc(var(--toast-gap)+3px)]',
    1342,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('height', CssCalc(_v377)),
      ]),
    ],
  ),
  RaftUtility('before:inset-0', 1326, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
      RaftDecl('bottom', CssNum(0, 'px')),
      RaftDecl('left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('before:inset-x-0', 1327, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('before:left-1/2', 1334, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(50, '%')),
    ]),
  ]),
  RaftUtility('before:left-3', 1335, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility(
    'before:mask-[linear-gradient(to_top,black_50%,transparent),linear-gradient(to_right,transparent,black_24px,black_calc(100%-24px),transparent)]',
    1363,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('mask-image', CssList([_v345, _v350])),
      ]),
    ],
  ),
  RaftUtility('before:mask-intersect', 1364, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('mask-composite', CssKeyword('intersect')),
    ]),
  ]),
  RaftUtility('before:mr-1.5', 1337, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('margin-right', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('before:pointer-events-auto', 1322, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('pointer-events', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('before:pointer-events-none', 1323, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('pointer-events', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('before:right-3', 1331, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('right', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('before:rounded-[inherit]', 1349, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', CssKeyword('inherit')),
      RaftDecl('border-top-right-radius', CssKeyword('inherit')),
      RaftDecl('border-bottom-right-radius', CssKeyword('inherit')),
      RaftDecl('border-bottom-left-radius', CssKeyword('inherit')),
    ]),
  ]),
  RaftUtility('before:rounded-full', 1350, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', _v77),
      RaftDecl('border-top-right-radius', _v77),
      RaftDecl('border-bottom-right-radius', _v77),
      RaftDecl('border-bottom-left-radius', _v77),
    ]),
  ]),
  RaftUtility('before:rounded-none', 1351, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', CssNum(0)),
      RaftDecl('border-top-right-radius', CssNum(0)),
      RaftDecl('border-bottom-right-radius', CssNum(0)),
      RaftDecl('border-bottom-left-radius', CssNum(0)),
    ]),
  ]),
  RaftUtility(
    'before:text-foreground-inverse/45',
    1365,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('color', _v227),
      ]),
      RaftLayer('::before', [], 1001, [RaftDecl('color', _v379)]),
    ],
  ),
  RaftUtility('before:top-1/2', 1328, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(50, '%')),
    ]),
  ]),
  RaftUtility('before:top-3', 1329, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('before:top-full', 1330, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility('before:transition-colors', 1367, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('transition-property', _v131),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('before:w-1', 1343, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('before:w-1.5', 1344, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('before:w-12', 1345, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(48, 'px')),
    ]),
  ]),
  RaftUtility('before:z-0', 1336, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('z-index', CssNum(0)),
    ]),
  ]),
  RaftUtility('bg-(--color-brutal-lime-100)', 509, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v380)]),
  ]),
  RaftUtility(
    'bg-(--color-brutal-orange-100)',
    510,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v381)]),
    ],
  ),
  RaftUtility(
    'bg-(--color-brutal-yellow-100)',
    511,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v382)]),
    ],
  ),
  RaftUtility('bg-(--progress-indicator)', 512, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v383)]),
  ]),
  RaftUtility('bg-(--progress-track)', 513, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v384)]),
  ]),
  RaftUtility(
    'bg-(--reference-badge,transparent)',
    514,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v385)]),
    ],
  ),
  RaftUtility('bg-(--status-color)', 515, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v386)]),
  ]),
  RaftUtility(
    'bg-[color-mix(in_oklch,var(--ink)_4%,var(--layer-panel))]',
    516,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v324)]),
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v389)]),
    ],
  ),
  RaftUtility(
    'bg-[color-mix(in_oklch,var(--ink-4),var(--layer-panel))]',
    517,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v390)]),
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v391)]),
    ],
  ),
  RaftUtility('bg-[oklch(0.52_0.13_75)]', 518, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v392)]),
  ]),
  RaftUtility('bg-[oklch(0.52_0.16_300)]', 519, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v393)]),
  ]),
  RaftUtility('bg-[oklch(0.54_0.14_160)]', 520, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v394)]),
  ]),
  RaftUtility('bg-[oklch(0.56_0.16_250)]', 521, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v395)]),
  ]),
  RaftUtility('bg-[oklch(0.63_0.21_20)]', 522, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v396)]),
  ]),
  RaftUtility('bg-[oklch(0.66_0.19_31)]', 523, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v397)]),
  ]),
  RaftUtility(
    'bg-[oklch(0.672_0.215_26.69)]',
    525,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v398)]),
    ],
  ),
  RaftUtility(
    'bg-[oklch(0.94_0.035_153.079)]',
    524,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v399)]),
    ],
  ),
  RaftUtility('bg-[oklch(0.955_0.035_50)]', 526, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v400)]),
  ]),
  RaftUtility('bg-[oklch(0.955_0_0)]', 527, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v401)]),
  ]),
  RaftUtility(
    'bg-[oklch(0.965_0.019_358.59)]',
    528,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v402)]),
    ],
  ),
  RaftUtility(
    'bg-[oklch(0.96625109_0.02494438_333.728876)]',
    531,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v403)]),
    ],
  ),
  RaftUtility(
    'bg-[oklch(0.966_0.022_224.02)]',
    529,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v404)]),
    ],
  ),
  RaftUtility('bg-[oklch(0.9702_0_0/0.8)]', 530, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v405)]),
  ]),
  RaftUtility('bg-[oklch(0_0_0/0.4)]', 532, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v406)]),
  ]),
  RaftUtility('bg-[oklch(0_0_0/0.72)]', 533, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v407)]),
  ]),
  RaftUtility('bg-accent-200', 534, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v216)]),
  ]),
  RaftUtility('bg-accent-400', 535, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v212)]),
  ]),
  RaftUtility('bg-accent-400/20', 536, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v212)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v409)]),
  ]),
  RaftUtility('bg-accent-400/35', 537, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v212)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v411)]),
  ]),
  RaftUtility('bg-accent-400/60', 538, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v212)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v413)]),
  ]),
  RaftUtility('bg-accent-soft', 539, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v325)]),
  ]),
  RaftUtility('bg-black', 540, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v5)]),
  ]),
  RaftUtility('bg-black/15', 543, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v415)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v416)]),
  ]),
  RaftUtility('bg-black/20', 544, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v418)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v419)]),
  ]),
  RaftUtility('bg-black/3', 541, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v421)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v422)]),
  ]),
  RaftUtility('bg-black/35', 545, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v424)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v425)]),
  ]),
  RaftUtility('bg-black/45', 546, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v135)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v136)]),
  ]),
  RaftUtility('bg-black/5', 542, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v427)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v428)]),
  ]),
  RaftUtility('bg-brutal-cream', 547, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssColor(0xFFFFFAEF)),
    ]),
  ]),
  RaftUtility('bg-brutal-cream/60', 548, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v430)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v431)]),
  ]),
  RaftUtility('bg-brutal-cyan', 549, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssColor(0xFF27CCF3)),
    ]),
  ]),
  RaftUtility('bg-brutal-cyan/20', 550, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v433)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v434)]),
  ]),
  RaftUtility('bg-brutal-cyan/30', 551, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v436)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v437)]),
  ]),
  RaftUtility('bg-brutal-lavender', 552, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssColor(0xFFBBAFE6)),
    ]),
  ]),
  RaftUtility('bg-brutal-lime', 553, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssColor(0xFFA9D877)),
    ]),
  ]),
  RaftUtility('bg-brutal-orange', 554, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssColor(0xFFF8A16F)),
    ]),
  ]),
  RaftUtility('bg-brutal-orange/25', 555, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v439)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v440)]),
  ]),
  RaftUtility('bg-brutal-orange/90', 556, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v442)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v443)]),
  ]),
  RaftUtility('bg-brutal-pink', 557, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssColor(0xFFFE7DA8)),
    ]),
  ]),
  RaftUtility('bg-brutal-pink/30', 558, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v445)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v446)]),
  ]),
  RaftUtility('bg-brutal-red', 559, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssColor(0xFFF97264)),
    ]),
  ]),
  RaftUtility('bg-brutal-stone', 560, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssColor(0xFFC0B9B1)),
    ]),
  ]),
  RaftUtility('bg-brutal-stone/25', 561, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v448)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v449)]),
  ]),
  RaftUtility('bg-brutal-stone/30', 562, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v451)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v452)]),
  ]),
  RaftUtility('bg-brutal-yellow', 563, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssColor(0xFFFFD440)),
    ]),
  ]),
  RaftUtility('bg-brutal-yellow/30', 564, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v454)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v455)]),
  ]),
  RaftUtility('bg-brutal-yellow/50', 565, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v272)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v273)]),
  ]),
  RaftUtility('bg-clip-padding', 645, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-clip', _v456)]),
  ]),
  RaftUtility('bg-current', 566, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v35)]),
  ]),
  RaftUtility('bg-danger', 567, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v137)]),
  ]),
  RaftUtility('bg-danger-muted', 568, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v217)]),
  ]),
  RaftUtility('bg-danger-soft', 569, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v326)]),
  ]),
  RaftUtility('bg-danger/80', 570, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v137)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v458)]),
  ]),
  RaftUtility('bg-fill-muted', 571, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v222)]),
  ]),
  RaftUtility('bg-fill-muted/35', 572, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v222)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v460)]),
  ]),
  RaftUtility('bg-fill-muted/40', 573, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v222)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v462)]),
  ]),
  RaftUtility('bg-fill-muted/50', 574, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v222)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v464)]),
  ]),
  RaftUtility('bg-fill-muted/70', 575, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v222)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v466)]),
  ]),
  RaftUtility('bg-fill-strong', 576, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v115)]),
  ]),
  RaftUtility('bg-foreground', 577, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v14)]),
  ]),
  RaftUtility('bg-foreground-inverse/10', 578, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v227)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v468)]),
  ]),
  RaftUtility('bg-foreground-muted/35', 579, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v22)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v470)]),
  ]),
  RaftUtility('bg-foreground-strong', 580, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v0)]),
  ]),
  RaftUtility('bg-foreground-strong/10', 582, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v472)]),
  ]),
  RaftUtility('bg-foreground-strong/12', 583, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v474)]),
  ]),
  RaftUtility('bg-foreground-strong/70', 584, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v48)]),
  ]),
  RaftUtility('bg-foreground-strong/8', 581, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v476)]),
  ]),
  RaftUtility('bg-inactive', 585, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v477)]),
  ]),
  RaftUtility('bg-info', 586, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v62)]),
  ]),
  RaftUtility('bg-info-muted', 587, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v218)]),
  ]),
  RaftUtility('bg-info-soft', 588, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v478)]),
  ]),
  RaftUtility('bg-info-soft/50', 589, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v478)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v480)]),
  ]),
  RaftUtility('bg-info/80', 590, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v62)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v482)]),
  ]),
  RaftUtility('bg-ink-10', 593, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v12)]),
  ]),
  RaftUtility('bg-ink-2', 591, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v147)]),
  ]),
  RaftUtility('bg-ink-8', 592, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v276)]),
  ]),
  RaftUtility('bg-layer-backdrop', 594, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v483)]),
  ]),
  RaftUtility('bg-layer-canvas-muted', 595, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v68)]),
  ]),
  RaftUtility('bg-layer-card', 596, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v484)]),
  ]),
  RaftUtility('bg-layer-hud', 597, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v485)]),
  ]),
  RaftUtility('bg-layer-hud/85', 598, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v485)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v487)]),
  ]),
  RaftUtility('bg-layer-inset', 599, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v488)]),
  ]),
  RaftUtility('bg-layer-panel', 600, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v38)]),
  ]),
  RaftUtility('bg-layer-panel/30', 601, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v38)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v490)]),
  ]),
  RaftUtility('bg-layer-panel/70', 602, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v38)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v492)]),
  ]),
  RaftUtility('bg-layer-popover', 603, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v493)]),
  ]),
  RaftUtility('bg-line-hairline', 604, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v158)]),
  ]),
  RaftUtility('bg-line-strong', 605, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v43)]),
  ]),
  RaftUtility('bg-primary', 606, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v118)]),
  ]),
  RaftUtility('bg-primary-100', 607, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v494)]),
  ]),
  RaftUtility('bg-primary-400', 608, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v118)]),
  ]),
  RaftUtility('bg-primary-400/40', 609, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v496)]),
  ]),
  RaftUtility('bg-primary-400/60', 610, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v498)]),
  ]),
  RaftUtility('bg-primary-400/70', 611, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v500)]),
  ]),
  RaftUtility('bg-primary-400/80', 612, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v502)]),
  ]),
  RaftUtility('bg-primary-soft', 613, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v327)]),
  ]),
  RaftUtility('bg-primary/20', 614, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v504)]),
  ]),
  RaftUtility('bg-primary/70', 615, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v500)]),
  ]),
  RaftUtility('bg-secondary-100', 616, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v505)]),
  ]),
  RaftUtility('bg-secondary-200', 617, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v506)]),
  ]),
  RaftUtility('bg-secondary-400', 618, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v230)]),
  ]),
  RaftUtility('bg-success', 619, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v63)]),
  ]),
  RaftUtility('bg-success-soft', 620, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v507)]),
  ]),
  RaftUtility('bg-success/30', 621, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v63)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v509)]),
  ]),
  RaftUtility('bg-success/80', 622, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v63)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v511)]),
  ]),
  RaftUtility('bg-task-status-closed', 623, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v512)]),
  ]),
  RaftUtility('bg-task-status-closed-soft', 624, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v513)]),
  ]),
  RaftUtility('bg-task-status-done', 625, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v514)]),
  ]),
  RaftUtility('bg-task-status-done-soft', 626, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v515)]),
  ]),
  RaftUtility('bg-task-status-in-progress', 627, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v516)]),
  ]),
  RaftUtility(
    'bg-task-status-in-progress-soft',
    628,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v517)]),
    ],
  ),
  RaftUtility('bg-task-status-in-review', 629, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v518)]),
  ]),
  RaftUtility(
    'bg-task-status-in-review-soft',
    630,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v519)]),
    ],
  ),
  RaftUtility('bg-task-status-todo', 631, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v520)]),
  ]),
  RaftUtility('bg-task-status-todo-soft', 632, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v521)]),
  ]),
  RaftUtility('bg-transparent', 633, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v7)]),
  ]),
  RaftUtility('bg-warning', 634, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v64)]),
  ]),
  RaftUtility('bg-warning-muted', 635, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v221)]),
  ]),
  RaftUtility('bg-warning-soft', 636, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v522)]),
  ]),
  RaftUtility('bg-warning/80', 637, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v64)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v524)]),
  ]),
  RaftUtility('bg-white', 638, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v39)]),
  ]),
  RaftUtility('bg-white/6', 639, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v526)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v527)]),
  ]),
  RaftUtility('bg-white/70', 640, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v529)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v530)]),
  ]),
  RaftUtility('bg-white/75', 641, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v532)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v533)]),
  ]),
  RaftUtility('bg-white/80', 642, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v309)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v310)]),
  ]),
  RaftUtility('bg-white/85', 643, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v535)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v536)]),
  ]),
  RaftUtility('block', 133, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('block'))]),
  ]),
  RaftUtility('blur-0', -1, RaftUtilityStatus.noCss, []),
  RaftUtility('border', 448, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-right-style', _v31),
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-left-style', _v31),
      RaftDecl('border-top-width', CssNum(1, 'px')),
      RaftDecl('border-right-width', CssNum(1, 'px')),
      RaftDecl('border-bottom-width', CssNum(1, 'px')),
      RaftDecl('border-left-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('border-0', 449, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-right-style', _v31),
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-left-style', _v31),
      RaftDecl('border-top-width', CssNum(0, 'px')),
      RaftDecl('border-right-width', CssNum(0, 'px')),
      RaftDecl('border-bottom-width', CssNum(0, 'px')),
      RaftDecl('border-left-width', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('border-2', 450, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-right-style', _v31),
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-left-style', _v31),
      RaftDecl('border-top-width', CssNum(2, 'px')),
      RaftDecl('border-right-width', CssNum(2, 'px')),
      RaftDecl('border-bottom-width', CssNum(2, 'px')),
      RaftDecl('border-left-width', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('border-[0.5px]', 451, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-right-style', _v31),
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-left-style', _v31),
      RaftDecl('border-top-width', CssNum(0.5, 'px')),
      RaftDecl('border-right-width', CssNum(0.5, 'px')),
      RaftDecl('border-bottom-width', CssNum(0.5, 'px')),
      RaftDecl('border-left-width', CssNum(0.5, 'px')),
    ]),
  ]),
  RaftUtility('border-[1.5px]', 452, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-right-style', _v31),
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-left-style', _v31),
      RaftDecl('border-top-width', CssNum(1.5, 'px')),
      RaftDecl('border-right-width', CssNum(1.5, 'px')),
      RaftDecl('border-bottom-width', CssNum(1.5, 'px')),
      RaftDecl('border-left-width', CssNum(1.5, 'px')),
    ]),
  ]),
  RaftUtility(
    'border-[color-mix(in_oklch,var(--status-color)_58%,transparent)]',
    468,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v386),
        RaftDecl('border-right-color', _v386),
        RaftDecl('border-bottom-color', _v386),
        RaftDecl('border-left-color', _v386),
      ]),
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v538),
        RaftDecl('border-right-color', _v538),
        RaftDecl('border-bottom-color', _v538),
        RaftDecl('border-left-color', _v538),
      ]),
    ],
  ),
  RaftUtility(
    'border-[color-mix(in_oklch,var(--task-status-closed-strong)_35%,transparent)]',
    469,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v539),
        RaftDecl('border-right-color', _v539),
        RaftDecl('border-bottom-color', _v539),
        RaftDecl('border-left-color', _v539),
      ]),
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v541),
        RaftDecl('border-right-color', _v541),
        RaftDecl('border-bottom-color', _v541),
        RaftDecl('border-left-color', _v541),
      ]),
    ],
  ),
  RaftUtility(
    'border-[color-mix(in_oklch,var(--task-status-done-strong)_35%,transparent)]',
    470,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v542),
        RaftDecl('border-right-color', _v542),
        RaftDecl('border-bottom-color', _v542),
        RaftDecl('border-left-color', _v542),
      ]),
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v544),
        RaftDecl('border-right-color', _v544),
        RaftDecl('border-bottom-color', _v544),
        RaftDecl('border-left-color', _v544),
      ]),
    ],
  ),
  RaftUtility(
    'border-[color-mix(in_oklch,var(--task-status-in-progress-strong)_35%,transparent)]',
    471,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v545),
        RaftDecl('border-right-color', _v545),
        RaftDecl('border-bottom-color', _v545),
        RaftDecl('border-left-color', _v545),
      ]),
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v547),
        RaftDecl('border-right-color', _v547),
        RaftDecl('border-bottom-color', _v547),
        RaftDecl('border-left-color', _v547),
      ]),
    ],
  ),
  RaftUtility(
    'border-[color-mix(in_oklch,var(--task-status-in-review-strong)_35%,transparent)]',
    472,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v548),
        RaftDecl('border-right-color', _v548),
        RaftDecl('border-bottom-color', _v548),
        RaftDecl('border-left-color', _v548),
      ]),
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v550),
        RaftDecl('border-right-color', _v550),
        RaftDecl('border-bottom-color', _v550),
        RaftDecl('border-left-color', _v550),
      ]),
    ],
  ),
  RaftUtility(
    'border-[color-mix(in_oklch,var(--task-status-todo-strong)_35%,transparent)]',
    473,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v551),
        RaftDecl('border-right-color', _v551),
        RaftDecl('border-bottom-color', _v551),
        RaftDecl('border-left-color', _v551),
      ]),
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-color', _v553),
        RaftDecl('border-right-color', _v553),
        RaftDecl('border-bottom-color', _v553),
        RaftDecl('border-left-color', _v553),
      ]),
    ],
  ),
  RaftUtility('border-[oklch(0_0_0/0.3)]', 474, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v554),
      RaftDecl('border-right-color', _v554),
      RaftDecl('border-bottom-color', _v554),
      RaftDecl('border-left-color', _v554),
    ]),
  ]),
  RaftUtility('border-accent-500', 475, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v555),
      RaftDecl('border-right-color', _v555),
      RaftDecl('border-bottom-color', _v555),
      RaftDecl('border-left-color', _v555),
    ]),
  ]),
  RaftUtility('border-b', 462, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-bottom-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('border-b-0', 463, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-bottom-width', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('border-b-2', 464, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-bottom-width', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('border-black', 476, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v5),
      RaftDecl('border-right-color', _v5),
      RaftDecl('border-bottom-color', _v5),
      RaftDecl('border-left-color', _v5),
    ]),
  ]),
  RaftUtility('border-black/10', 477, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v263),
      RaftDecl('border-right-color', _v263),
      RaftDecl('border-bottom-color', _v263),
      RaftDecl('border-left-color', _v263),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v264),
      RaftDecl('border-right-color', _v264),
      RaftDecl('border-bottom-color', _v264),
      RaftDecl('border-left-color', _v264),
    ]),
  ]),
  RaftUtility('border-black/15', 478, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v415),
      RaftDecl('border-right-color', _v415),
      RaftDecl('border-bottom-color', _v415),
      RaftDecl('border-left-color', _v415),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v416),
      RaftDecl('border-right-color', _v416),
      RaftDecl('border-bottom-color', _v416),
      RaftDecl('border-left-color', _v416),
    ]),
  ]),
  RaftUtility('border-black/20', 479, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v418),
      RaftDecl('border-right-color', _v418),
      RaftDecl('border-bottom-color', _v418),
      RaftDecl('border-left-color', _v418),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v419),
      RaftDecl('border-right-color', _v419),
      RaftDecl('border-bottom-color', _v419),
      RaftDecl('border-left-color', _v419),
    ]),
  ]),
  RaftUtility('border-black/30', 480, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v557),
      RaftDecl('border-right-color', _v557),
      RaftDecl('border-bottom-color', _v557),
      RaftDecl('border-left-color', _v557),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v558),
      RaftDecl('border-right-color', _v558),
      RaftDecl('border-bottom-color', _v558),
      RaftDecl('border-left-color', _v558),
    ]),
  ]),
  RaftUtility('border-black/40', 481, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v56),
      RaftDecl('border-right-color', _v56),
      RaftDecl('border-bottom-color', _v56),
      RaftDecl('border-left-color', _v56),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v57),
      RaftDecl('border-right-color', _v57),
      RaftDecl('border-bottom-color', _v57),
      RaftDecl('border-left-color', _v57),
    ]),
  ]),
  RaftUtility('border-collapse', 308, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-collapse', CssKeyword('collapse')),
    ]),
  ]),
  RaftUtility('border-current/20', 482, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v35),
      RaftDecl('border-right-color', _v35),
      RaftDecl('border-bottom-color', _v35),
      RaftDecl('border-left-color', _v35),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v560),
      RaftDecl('border-right-color', _v560),
      RaftDecl('border-bottom-color', _v560),
      RaftDecl('border-left-color', _v560),
    ]),
  ]),
  RaftUtility('border-current/40', 483, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v35),
      RaftDecl('border-right-color', _v35),
      RaftDecl('border-bottom-color', _v35),
      RaftDecl('border-left-color', _v35),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v562),
      RaftDecl('border-right-color', _v562),
      RaftDecl('border-bottom-color', _v562),
      RaftDecl('border-left-color', _v562),
    ]),
  ]),
  RaftUtility('border-danger', 484, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v137),
      RaftDecl('border-right-color', _v137),
      RaftDecl('border-bottom-color', _v137),
      RaftDecl('border-left-color', _v137),
    ]),
  ]),
  RaftUtility('border-dashed', 467, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-border-style', CssKeyword('dashed')),
      RaftDecl('border-top-style', CssKeyword('dashed')),
      RaftDecl('border-right-style', CssKeyword('dashed')),
      RaftDecl('border-bottom-style', CssKeyword('dashed')),
      RaftDecl('border-left-style', CssKeyword('dashed')),
    ]),
  ]),
  RaftUtility('border-foreground-inverse', 485, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v227),
      RaftDecl('border-right-color', _v227),
      RaftDecl('border-bottom-color', _v227),
      RaftDecl('border-left-color', _v227),
    ]),
  ]),
  RaftUtility('border-info', 486, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v62),
      RaftDecl('border-right-color', _v62),
      RaftDecl('border-bottom-color', _v62),
      RaftDecl('border-left-color', _v62),
    ]),
  ]),
  RaftUtility('border-ink-10', 488, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v12),
      RaftDecl('border-right-color', _v12),
      RaftDecl('border-bottom-color', _v12),
      RaftDecl('border-left-color', _v12),
    ]),
  ]),
  RaftUtility('border-ink-6', 487, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v275),
      RaftDecl('border-right-color', _v275),
      RaftDecl('border-bottom-color', _v275),
      RaftDecl('border-left-color', _v275),
    ]),
  ]),
  RaftUtility('border-l', 465, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-left-style', _v31),
      RaftDecl('border-left-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('border-l-2', 466, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-left-style', _v31),
      RaftDecl('border-left-width', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('border-layer-panel', 489, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v38),
      RaftDecl('border-right-color', _v38),
      RaftDecl('border-bottom-color', _v38),
      RaftDecl('border-left-color', _v38),
    ]),
  ]),
  RaftUtility('border-line-field', 490, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v563),
      RaftDecl('border-right-color', _v563),
      RaftDecl('border-bottom-color', _v563),
      RaftDecl('border-left-color', _v563),
    ]),
  ]),
  RaftUtility('border-line-hairline', 491, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v158),
      RaftDecl('border-right-color', _v158),
      RaftDecl('border-bottom-color', _v158),
      RaftDecl('border-left-color', _v158),
    ]),
  ]),
  RaftUtility('border-line-muted', 492, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v81),
      RaftDecl('border-right-color', _v81),
      RaftDecl('border-bottom-color', _v81),
      RaftDecl('border-left-color', _v81),
    ]),
  ]),
  RaftUtility('border-line-muted/70', 493, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v81),
      RaftDecl('border-right-color', _v81),
      RaftDecl('border-bottom-color', _v81),
      RaftDecl('border-left-color', _v81),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v565),
      RaftDecl('border-right-color', _v565),
      RaftDecl('border-bottom-color', _v565),
      RaftDecl('border-left-color', _v565),
    ]),
  ]),
  RaftUtility('border-line-muted/75', 494, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v81),
      RaftDecl('border-right-color', _v81),
      RaftDecl('border-bottom-color', _v81),
      RaftDecl('border-left-color', _v81),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v567),
      RaftDecl('border-right-color', _v567),
      RaftDecl('border-bottom-color', _v567),
      RaftDecl('border-left-color', _v567),
    ]),
  ]),
  RaftUtility('border-line-muted/90', 495, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v81),
      RaftDecl('border-right-color', _v81),
      RaftDecl('border-bottom-color', _v81),
      RaftDecl('border-left-color', _v81),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v569),
      RaftDecl('border-right-color', _v569),
      RaftDecl('border-bottom-color', _v569),
      RaftDecl('border-left-color', _v569),
    ]),
  ]),
  RaftUtility('border-line-strong', 496, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v43),
      RaftDecl('border-right-color', _v43),
      RaftDecl('border-bottom-color', _v43),
      RaftDecl('border-left-color', _v43),
    ]),
  ]),
  RaftUtility('border-line-strong/20', 497, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v43),
      RaftDecl('border-right-color', _v43),
      RaftDecl('border-bottom-color', _v43),
      RaftDecl('border-left-color', _v43),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v571),
      RaftDecl('border-right-color', _v571),
      RaftDecl('border-bottom-color', _v571),
      RaftDecl('border-left-color', _v571),
    ]),
  ]),
  RaftUtility('border-line-strong/30', 498, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v43),
      RaftDecl('border-right-color', _v43),
      RaftDecl('border-bottom-color', _v43),
      RaftDecl('border-left-color', _v43),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v573),
      RaftDecl('border-right-color', _v573),
      RaftDecl('border-bottom-color', _v573),
      RaftDecl('border-left-color', _v573),
    ]),
  ]),
  RaftUtility('border-primary-400/40', 499, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v118),
      RaftDecl('border-right-color', _v118),
      RaftDecl('border-bottom-color', _v118),
      RaftDecl('border-left-color', _v118),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v496),
      RaftDecl('border-right-color', _v496),
      RaftDecl('border-bottom-color', _v496),
      RaftDecl('border-left-color', _v496),
    ]),
  ]),
  RaftUtility('border-primary-500', 500, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v574),
      RaftDecl('border-right-color', _v574),
      RaftDecl('border-bottom-color', _v574),
      RaftDecl('border-left-color', _v574),
    ]),
  ]),
  RaftUtility('border-r', 460, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-right-style', _v31),
      RaftDecl('border-right-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('border-r-2', 461, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-right-style', _v31),
      RaftDecl('border-right-width', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('border-secondary-500', 501, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v575),
      RaftDecl('border-right-color', _v575),
      RaftDecl('border-bottom-color', _v575),
      RaftDecl('border-left-color', _v575),
    ]),
  ]),
  RaftUtility('border-success', 502, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v63),
      RaftDecl('border-right-color', _v63),
      RaftDecl('border-bottom-color', _v63),
      RaftDecl('border-left-color', _v63),
    ]),
  ]),
  RaftUtility('border-t', 456, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-top-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('border-t-0', 457, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-top-width', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('border-t-2', 458, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-top-width', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('border-t-[0.5px]', 459, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-top-width', CssNum(0.5, 'px')),
    ]),
  ]),
  RaftUtility('border-t-current', 507, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('border-top-color', _v35)]),
  ]),
  RaftUtility('border-transparent', 503, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v7),
      RaftDecl('border-right-color', _v7),
      RaftDecl('border-bottom-color', _v7),
      RaftDecl('border-left-color', _v7),
    ]),
  ]),
  RaftUtility('border-warning', 504, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v64),
      RaftDecl('border-right-color', _v64),
      RaftDecl('border-bottom-color', _v64),
      RaftDecl('border-left-color', _v64),
    ]),
  ]),
  RaftUtility('border-white/25', 505, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v577),
      RaftDecl('border-right-color', _v577),
      RaftDecl('border-bottom-color', _v577),
      RaftDecl('border-left-color', _v577),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v578),
      RaftDecl('border-right-color', _v578),
      RaftDecl('border-bottom-color', _v578),
      RaftDecl('border-left-color', _v578),
    ]),
  ]),
  RaftUtility('border-white/70', 506, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v529),
      RaftDecl('border-right-color', _v529),
      RaftDecl('border-bottom-color', _v529),
      RaftDecl('border-left-color', _v529),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v530),
      RaftDecl('border-right-color', _v530),
      RaftDecl('border-bottom-color', _v530),
      RaftDecl('border-left-color', _v530),
    ]),
  ]),
  RaftUtility('border-x', 454, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-left-style', _v31),
      RaftDecl('border-right-style', _v31),
      RaftDecl('border-left-width', CssNum(1, 'px')),
      RaftDecl('border-right-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('border-y-2', 455, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-top-width', CssNum(2, 'px')),
      RaftDecl('border-bottom-width', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('bottom-(--drawer-inset)', 46, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', _v165)]),
  ]),
  RaftUtility('bottom-0', 47, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(0, 'px'))]),
  ]),
  RaftUtility('bottom-0.5', 48, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(2, 'px'))]),
  ]),
  RaftUtility('bottom-1', 49, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(4, 'px'))]),
  ]),
  RaftUtility('bottom-1.5', 50, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(6, 'px'))]),
  ]),
  RaftUtility('bottom-20', 53, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(80, 'px'))]),
  ]),
  RaftUtility('bottom-3', 51, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(12, 'px'))]),
  ]),
  RaftUtility('bottom-4', 52, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(16, 'px'))]),
  ]),
  RaftUtility('bottom-full', 54, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(100, '%'))]),
  ]),
  RaftUtility('break-all', 841, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('word-break', CssKeyword('break-all')),
    ]),
  ]),
  RaftUtility('caption-bottom', 307, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('caption-side', CssKeyword('bottom')),
    ]),
  ]),
  RaftUtility('col-end-(--ph-meta-end,auto)', 88, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column-end', _v579)]),
  ]),
  RaftUtility('col-span-2', 78, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column', _v73)]),
  ]),
  RaftUtility('col-span-full', 79, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column', _v580)]),
  ]),
  RaftUtility(
    'col-start-(--banner-action-col,2)',
    80,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', _v581)]),
    ],
  ),
  RaftUtility(
    'col-start-(--banner-text-col,1)',
    81,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', _v582)]),
    ],
  ),
  RaftUtility('col-start-(--card-text-col,1)', 82, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', _v583)]),
  ]),
  RaftUtility(
    'col-start-(--card-trailing-col,2)',
    83,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', _v584)]),
    ],
  ),
  RaftUtility(
    'col-start-(--ph-meta-col,auto)',
    84,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', _v585)]),
    ],
  ),
  RaftUtility(
    'col-start-(--ph-text-col,auto)',
    85,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', _v586)]),
    ],
  ),
  RaftUtility('col-start-1', 86, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', CssNum(1))]),
  ]),
  RaftUtility('col-start-2', 87, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', CssNum(2))]),
  ]),
  RaftUtility('contents', 134, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('contents'))]),
  ]),
  RaftUtility('cursor-default', 335, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', CssKeyword('default'))]),
  ]),
  RaftUtility('cursor-ew-resize', 336, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', CssKeyword('ew-resize'))]),
  ]),
  RaftUtility('cursor-grab', 337, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', CssKeyword('grab'))]),
  ]),
  RaftUtility('cursor-pointer', 338, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', CssKeyword('pointer'))]),
  ]),
  RaftUtility('cursor-wait', 339, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', CssKeyword('wait'))]),
  ]),
  RaftUtility(
    'dark:**:data-[slot=button]:hover:text-[oklch(0.92_0.003_106.42)]',
    2751,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="button"]:hover',
        ['dark'],
        3000,
        [RaftDecl('color', _v587)],
      ),
    ],
  ),
  RaftUtility(
    'dark:**:data-[slot=button]:text-[oklch(0.76_0.005_106.42)]',
    2750,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="button"]',
        ['dark'],
        2000,
        [RaftDecl('color', _v588)],
      ),
    ],
  ),
  RaftUtility(
    'dark:**:data-[slot=kbd]:bg-ink-4',
    2752,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="kbd"]',
        ['dark'],
        2000,
        [RaftDecl('background-color', _v390)],
      ),
    ],
  ),
  RaftUtility(
    'dark:**:data-[slot=kbd]:text-foreground-muted',
    2753,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="kbd"]',
        ['dark'],
        2000,
        [RaftDecl('color', _v22)],
      ),
    ],
  ),
  RaftUtility(
    'dark:**:data-[slot=toast-icon]:text-foreground-muted',
    2754,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="toast-icon"]',
        ['dark'],
        2000,
        [RaftDecl('color', _v22)],
      ),
    ],
  ),
  RaftUtility(
    'dark:[&>[data-slot=panel-toggle-action][data-pressed]:hover]:bg-fill-strong',
    2983,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]:hover',
        ['dark'],
        4000,
        [RaftDecl('background-color', _v115)],
      ),
    ],
  ),
  RaftUtility(
    'dark:[&>[data-slot=panel-toggle-action][data-pressed]]:bg-fill-muted',
    2978,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]',
        ['dark'],
        3000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'dark:[&>svg]:text-[oklch(0.82_0.12_61.907)]',
    3101,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', ['dark'], 1001, [RaftDecl('color', _v589)]),
    ],
  ),
  RaftUtility(
    'dark:[&>svg]:text-[oklch(0.8_0.1_220)]',
    3100,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', ['dark'], 1001, [RaftDecl('color', _v590)]),
    ],
  ),
  RaftUtility(
    'dark:[&_pre_span]:text-(--shiki-dark,currentColor)',
    2844,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& pre span', ['dark'], 1002, [RaftDecl('color', _v150)]),
    ],
  ),
  RaftUtility(
    'dark:[--progress-indicator:var(--progress-color)]',
    2618,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--progress-indicator', _v213)],
      ),
    ],
  ),
  RaftUtility(
    'dark:[--progress-sweep:color-mix(in_oklab,var(--progress-color)_55%,transparent)]',
    2619,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--progress-sweep', _v213)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--progress-sweep', _v592)]),
    ],
  ),
  RaftUtility(
    'dark:[--progress-track:var(--layer-inset)]',
    2620,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--progress-track', _v488)]),
    ],
  ),
  RaftUtility(
    'dark:[--toast-gradient-border-from:oklch(0.985_0.004_106.42/0.14)]',
    2621,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--toast-gradient-border-from', _v593)],
      ),
    ],
  ),
  RaftUtility(
    'dark:[--toast-gradient-border-via:oklch(0.985_0.004_106.42/0.07)]',
    2622,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--toast-gradient-border-via', _v594)],
      ),
    ],
  ),
  RaftUtility(
    'dark:active:bg-[color-mix(in_oklch,var(--ink)_8%,var(--layer-panel))]',
    2686,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'dark'],
        2000,
        [RaftDecl('background-color', _v324)],
      ),
      RaftLayer(
        'self',
        ['active', 'dark'],
        2000,
        [RaftDecl('background-color', _v596)],
      ),
    ],
  ),
  RaftUtility('dark:active:bg-ink-6', 2687, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active', 'dark'],
      2000,
      [RaftDecl('background-color', _v275)],
    ),
  ]),
  RaftUtility(
    'dark:after:border-[oklch(1_0_0/0.08)]',
    2650,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['dark'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('border-top-color', _v597),
          RaftDecl('border-right-color', _v597),
          RaftDecl('border-bottom-color', _v597),
          RaftDecl('border-left-color', _v597),
        ],
      ),
    ],
  ),
  RaftUtility('dark:after:hidden', 2649, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::after',
      ['dark'],
      1001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('display', CssKeyword('none')),
      ],
    ),
  ]),
  RaftUtility('dark:backdrop-blur-none', 2617, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('--tw-backdrop-blur', CssSeq([])),
        RaftDecl('-webkit-backdrop-filter', _v340),
        RaftDecl('backdrop-filter', _v340),
      ],
    ),
  ]),
  RaftUtility(
    'dark:before:backdrop-blur-[2px]',
    2648,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['dark'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-backdrop-blur', _v342),
          RaftDecl('-webkit-backdrop-filter', _v340),
          RaftDecl('backdrop-filter', _v340),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:before:bg-[linear-gradient(to_bottom,transparent,oklch(0_0_0/0.16))]',
    2647,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['dark'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-image', _v599),
        ],
      ),
    ],
  ),
  RaftUtility('dark:before:hidden', 2646, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['dark'],
      1001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('display', CssKeyword('none')),
      ],
    ),
  ]),
  RaftUtility(
    'dark:bg-[oklch(0.15_0.004_106.42)]',
    2539,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v600)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.24_0.005_106.42/0.85)]',
    2540,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v601)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.37_0.06_27)]',
    2541,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v321)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.42_0.14_20)]',
    2543,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v602)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.42_0.1_75)]',
    2542,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v603)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.45_0.006_106.42)]',
    2544,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v604)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.45_0.006_106.42/0.85)]',
    2545,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v605)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.4_0.11_160)]',
    2534,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v606)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.4_0.12_250)]',
    2535,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v607)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.4_0.13_300)]',
    2536,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v608)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.58_0.21_27)]',
    2546,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v322)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.5_0.08_50/0.18)]',
    2537,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v609)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.5_0.12_153/0.18)]',
    2538,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v610)]),
    ],
  ),
  RaftUtility(
    'dark:bg-[oklch(0.66_0.17_46)]',
    2547,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v323)]),
    ],
  ),
  RaftUtility('dark:bg-accent-soft', 2548, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v325)]),
  ]),
  RaftUtility('dark:bg-danger-muted', 2549, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v217)]),
  ]),
  RaftUtility('dark:bg-fill-muted', 2550, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v222)]),
  ]),
  RaftUtility('dark:bg-fill-strong', 2551, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v115)]),
  ]),
  RaftUtility('dark:bg-info-muted', 2552, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v218)]),
  ]),
  RaftUtility('dark:bg-info-soft', 2553, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v478)]),
  ]),
  RaftUtility('dark:bg-info-strong', 2554, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v228)]),
  ]),
  RaftUtility('dark:bg-ink', 2555, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v324)]),
  ]),
  RaftUtility('dark:bg-ink-16', 2557, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v274)]),
  ]),
  RaftUtility('dark:bg-ink-6', 2556, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v275)]),
  ]),
  RaftUtility('dark:bg-layer-canvas-muted', 2558, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v68)]),
  ]),
  RaftUtility(
    'dark:bg-layer-canvas-muted/80',
    2559,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v68)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v612)]),
    ],
  ),
  RaftUtility('dark:bg-layer-card', 2560, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v484)]),
  ]),
  RaftUtility('dark:bg-layer-card/60', 2561, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v484)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v614)]),
  ]),
  RaftUtility('dark:bg-layer-inset', 2562, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v488)]),
  ]),
  RaftUtility('dark:bg-layer-panel', 2563, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v38)]),
  ]),
  RaftUtility('dark:bg-layer-popover', 2564, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v493)]),
  ]),
  RaftUtility('dark:bg-primary-400', 2565, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v118)]),
  ]),
  RaftUtility('dark:bg-primary/30', 2566, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v616)]),
  ]),
  RaftUtility('dark:bg-success', 2567, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v63)]),
  ]),
  RaftUtility('dark:bg-success-muted', 2568, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v220)]),
  ]),
  RaftUtility('dark:bg-transparent', 2569, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v7)]),
  ]),
  RaftUtility('dark:bg-warning-muted', 2570, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v221)]),
  ]),
  RaftUtility('dark:border-ink-10', 2530, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v12),
        RaftDecl('border-right-color', _v12),
        RaftDecl('border-bottom-color', _v12),
        RaftDecl('border-left-color', _v12),
      ],
    ),
  ]),
  RaftUtility('dark:border-ink-16', 2531, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v274),
        RaftDecl('border-right-color', _v274),
        RaftDecl('border-bottom-color', _v274),
        RaftDecl('border-left-color', _v274),
      ],
    ),
  ]),
  RaftUtility('dark:border-ink-4', 2528, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v390),
        RaftDecl('border-right-color', _v390),
        RaftDecl('border-bottom-color', _v390),
        RaftDecl('border-left-color', _v390),
      ],
    ),
  ]),
  RaftUtility('dark:border-ink-6', 2529, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v275),
        RaftDecl('border-right-color', _v275),
        RaftDecl('border-bottom-color', _v275),
        RaftDecl('border-left-color', _v275),
      ],
    ),
  ]),
  RaftUtility('dark:border-line-hairline', 2532, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v158),
        RaftDecl('border-right-color', _v158),
        RaftDecl('border-bottom-color', _v158),
        RaftDecl('border-left-color', _v158),
      ],
    ),
  ]),
  RaftUtility('dark:border-transparent', 2533, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v7),
        RaftDecl('border-right-color', _v7),
        RaftDecl('border-bottom-color', _v7),
        RaftDecl('border-left-color', _v7),
      ],
    ),
  ]),
  RaftUtility(
    'dark:data-[active=true]:ring-2',
    2733,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-active=true'],
        2000,
        [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[disabled=true]:bg-[oklch(0.45_0.006_106.42/0.35)]',
    2734,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-disabled=true'],
        2000,
        [RaftDecl('background-color', _v619)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[disabled=true]:hover:bg-[oklch(0.45_0.006_106.42/0.35)]',
    2736,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v619)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[disabled=true]:text-[oklch(0.92_0.003_106.42/0.35)]',
    2735,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-disabled=true'],
        2000,
        [RaftDecl('color', _v620)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[dragging-active=true]:bg-fill-muted',
    2737,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-dragging-active=true'],
        2000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[nested=true]:bg-transparent',
    2739,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-nested=true'],
        2000,
        [RaftDecl('background-color', _v7)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[nested=true]:border-ink-10',
    2738,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-nested=true'],
        2000,
        [
          RaftDecl('border-top-color', _v12),
          RaftDecl('border-right-color', _v12),
          RaftDecl('border-bottom-color', _v12),
          RaftDecl('border-left-color', _v12),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[nested=true]:hover:bg-[color-mix(in_oklch,var(--layer-canvas-muted)_20%,var(--layer-inset))]',
    2740,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-nested=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v68)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-nested=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v622)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[nested=true]:hover:shadow-none',
    2741,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-nested=true', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[nested=true][data-selected=true]:bg-fill-muted',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'dark:data-[nested=true][data-selected=true]:border-ink-10',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'dark:data-[nested=true][data-selected=true]:hover:bg-fill-muted',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'dark:data-[reorderable=true]:data-active:bg-fill-muted',
    2742,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-active', 'data-reorderable=true'],
        3000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[selected=true]:before:hidden',
    2749,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['dark', 'data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('display', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[selected=true]:bg-fill-muted',
    2743,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-selected=true'],
        2000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[selected=true]:bg-layer-card',
    2744,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-selected=true'],
        2000,
        [RaftDecl('background-color', _v484)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[selected=true]:ring-2',
    2747,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-selected=true'],
        2000,
        [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[selected=true]:ring-transparent',
    2748,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-selected=true'],
        2000,
        [RaftDecl('--tw-ring-color', _v7)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[selected=true]:shadow-raft-sm',
    2746,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-selected=true'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-[selected=true]:text-foreground-strong',
    2745,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-selected=true'],
        2000,
        [RaftDecl('color', _v0)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-active:bg-layer-card',
    2700,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-active'],
        2000,
        [RaftDecl('background-color', _v484)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-active:ring-transparent',
    2701,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-active'],
        2000,
        [RaftDecl('--tw-ring-color', _v7)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:bg-[oklch(0.205_0.004_106.42)]',
    2702,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked'],
        2000,
        [RaftDecl('background-color', _v623)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:bg-primary-400',
    2703,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked'],
        2000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:data-disabled:bg-[oklch(0.28_0.002_106.42)]',
    2714,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked', 'data-disabled'],
        3000,
        [RaftDecl('background-color', _v624)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:data-disabled:bg-layer-inset',
    2715,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked', 'data-disabled'],
        3000,
        [RaftDecl('background-color', _v488)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:data-disabled:shadow-[inset_0_0_0_1px_oklch(0_0_0/0.5)]',
    2716,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked', 'data-disabled'],
        3000,
        [RaftDecl('--tw-shadow', _v627), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:hover:bg-primary-500',
    2709,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked', 'hover'],
        3000,
        [RaftDecl('background-color', _v574)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:shadow-[0_0_0_1px_oklch(0_0_0/0.45),0_2px_4px_oklch(0_0_0/0.25)]',
    2705,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v630, _v633])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:shadow-[0_1px_1.5px_-1px_oklch(0_0_0/0.4),0_0_0_0.5px_color-mix(in_srgb,var(--primary-500)_35%,transparent)]',
    2706,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v635, _v637])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-checked'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v635, _v641])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.12),0_1px_1.5px_-1px_oklch(0_0_0/0.4)]',
    2707,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v644, _v635])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:shadow-raft-sm',
    2708,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-checked:text-foreground-inverse',
    2704,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked'],
        2000,
        [RaftDecl('color', _v227)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-disabled:bg-[oklch(0.38_0.002_106.42)]',
    2711,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-disabled'],
        2000,
        [RaftDecl('background-color', _v645)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-disabled:bg-layer-inset',
    2712,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-disabled'],
        2000,
        [RaftDecl('background-color', _v488)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-disabled:shadow-[inset_0_0_0_1px_oklch(0_0_0/0.5)]',
    2713,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-disabled'],
        2000,
        [RaftDecl('--tw-shadow', _v627), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-expanded:bg-layer-popover',
    2717,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-expanded'],
        2000,
        [RaftDecl('background-color', _v493)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-expanded:shadow-raft-xl',
    2718,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-expanded'],
        2000,
        [RaftDecl('--tw-shadow', _v646), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-indeterminate:[--progress-track:oklch(0.21_0.004_106.42)]',
    2721,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-indeterminate'],
        2000,
        [RaftDecl('--progress-track', _v647)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-indeterminate:shadow-[0_0_0_1px_oklch(0_0_0/0.45),0_2px_4px_oklch(0_0_0/0.25)]',
    2719,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-indeterminate'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v630, _v633])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-indeterminate:shadow-none',
    2720,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-indeterminate'],
        2000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-popup-open:bg-layer-card',
    2723,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-popup-open'],
        2000,
        [RaftDecl('background-color', _v484)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-popup-open:ring-transparent',
    2724,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-popup-open'],
        2000,
        [RaftDecl('--tw-ring-color', _v7)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-pressed:bg-accent-soft',
    2725,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-pressed'],
        2000,
        [RaftDecl('background-color', _v325)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-pressed:hover:bg-accent-soft',
    2728,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-pressed', 'hover'],
        3000,
        [RaftDecl('background-color', _v325)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-pressed:hover:bg-primary-500',
    2729,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-pressed', 'hover'],
        3000,
        [RaftDecl('background-color', _v574)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-pressed:shadow-raft-sm',
    2727,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-pressed'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-pressed:text-accent-strong',
    2726,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-pressed'],
        2000,
        [RaftDecl('color', _v157)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-unchecked:bg-fill-muted',
    2730,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-unchecked'],
        2000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-unchecked:hover:bg-fill-strong',
    2732,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-unchecked', 'hover'],
        3000,
        [RaftDecl('background-color', _v115)],
      ),
    ],
  ),
  RaftUtility(
    'dark:data-unchecked:shadow-raft-sm',
    2731,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-unchecked'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:drop-shadow-[0_1px_0_oklch(0_0_0/0.55)]',
    2615,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [
          RaftDecl('--tw-drop-shadow-size', _v651),
          RaftDecl('--tw-drop-shadow', _v652),
          RaftDecl('filter', _v662),
        ],
      ),
    ],
  ),
  RaftUtility('dark:fill-layer-inset', 2571, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('fill', _v488)]),
  ]),
  RaftUtility('dark:focus-visible:ring-2', 2682, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'focus-visible'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'dark:focus-visible:ring-offset-0',
    2684,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'focus-visible'],
        2000,
        [
          RaftDecl('--tw-ring-offset-width', CssNum(0, 'px')),
          RaftDecl('--tw-ring-offset-shadow', _v664),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:focus-visible:ring-offset-layer-card',
    2685,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'focus-visible'],
        2000,
        [RaftDecl('--tw-ring-offset-color', _v484)],
      ),
    ],
  ),
  RaftUtility(
    'dark:focus-visible:ring-primary-400/60',
    2683,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['dark', 'focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v498)],
      ),
    ],
  ),
  RaftUtility('dark:focus-within:ring-2', 2651, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'focus-within'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'dark:focus-within:ring-[0.5px]',
    2652,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'focus-within'],
        2000,
        [RaftDecl('--tw-ring-shadow', _v666), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:focus-within:ring-accent-400/70',
    2653,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'focus-within'],
        2000,
        [RaftDecl('--tw-ring-color', _v212)],
      ),
      RaftLayer(
        'self',
        ['dark', 'focus-within'],
        2000,
        [RaftDecl('--tw-ring-color', _v668)],
      ),
    ],
  ),
  RaftUtility(
    'dark:focus-within:ring-primary-400/60',
    2654,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'focus-within'],
        2000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['dark', 'focus-within'],
        2000,
        [RaftDecl('--tw-ring-color', _v498)],
      ),
    ],
  ),
  RaftUtility('dark:focus:bg-layer-card', 2681, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'focus'],
      2000,
      [RaftDecl('background-color', _v484)],
    ),
  ]),
  RaftUtility(
    'dark:group-data-[edge=inset]/panel-frame:md:shadow-[0_0_0_1px_var(--line-muted),0_16px_32px_-8px_oklch(0_0_0_/_0.45)]',
    2756,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/panel-frame:data-edge=inset', 'width>=768'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v670, _v671])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-data-[status=warning]/banner:text-[oklch(0.82_0.12_61.907)]',
    2645,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/banner:data-status=warning'],
        2000,
        [RaftDecl('color', _v589)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-data-checked/checkbox:fill-foreground',
    2636,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:data-checked'],
        2000,
        [RaftDecl('fill', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-data-checked/checkbox:fill-primary-400',
    2637,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:data-checked'],
        2000,
        [RaftDecl('fill', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-data-checked/checkbox:group-data-disabled/checkbox:fill-fill-muted',
    2640,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:data-checked', 'group/checkbox:data-disabled'],
        3000,
        [RaftDecl('fill', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-data-disabled/checkbox:fill-fill-muted',
    2639,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:data-disabled'],
        2000,
        [RaftDecl('fill', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-data-indeterminate/checkbox:fill-foreground',
    2641,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:data-indeterminate'],
        2000,
        [RaftDecl('fill', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-data-indeterminate/checkbox:fill-primary-400',
    2642,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:data-indeterminate'],
        2000,
        [RaftDecl('fill', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-data-indeterminate/checkbox:group-data-disabled/checkbox:fill-fill-muted',
    2644,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'dark',
          'group/checkbox:data-disabled',
          'group/checkbox:data-indeterminate',
        ],
        3000,
        [RaftDecl('fill', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-focus-visible/checkbox:fill-foreground',
    2634,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:focus-visible'],
        2000,
        [RaftDecl('fill', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-focus-visible/checkbox:fill-primary-400',
    2635,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:focus-visible'],
        2000,
        [RaftDecl('fill', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-hover/checkbox:fill-layer-card',
    2633,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:hover'],
        2000,
        [RaftDecl('fill', _v484)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-hover/checkbox:group-data-checked/checkbox:fill-foreground-hover',
    2638,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:data-checked', 'group/checkbox:hover'],
        3000,
        [RaftDecl('fill', _v672)],
      ),
    ],
  ),
  RaftUtility(
    'dark:group-hover/checkbox:group-data-indeterminate/checkbox:fill-foreground-hover',
    2643,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'group/checkbox:data-indeterminate', 'group/checkbox:hover'],
        3000,
        [RaftDecl('fill', _v672)],
      ),
    ],
  ),
  RaftUtility(
    'dark:has-[[data-slot=inbox-item-open]:focus-visible]:ring-2',
    2688,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=inbox-item-open+focus-visible'],
        3000,
        [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:has-[[data-slot=inbox-item-open]:focus-visible]:ring-primary-400/60',
    2689,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=inbox-item-open+focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=inbox-item-open+focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v498)],
      ),
    ],
  ),
  RaftUtility(
    'dark:has-[[data-slot=input-group-control]:focus-visible]:ring-2',
    2691,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=input-group-control+focus-visible'],
        3000,
        [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:has-[[data-slot=input-group-control]:focus-visible]:ring-primary-400/60',
    2692,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=input-group-control+focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=input-group-control+focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v498)],
      ),
    ],
  ),
  RaftUtility(
    'dark:has-[[data-slot=input-group-control]:focus]:bg-layer-card',
    2690,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=input-group-control+focus'],
        3000,
        [RaftDecl('background-color', _v484)],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:[--toast-gradient-border-from:oklch(0.985_0.004_106.42/0.22)]',
    2675,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('--toast-gradient-border-from', _v673)],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:[--toast-gradient-border-via:oklch(0.985_0.004_106.42/0.11)]',
    2676,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('--toast-gradient-border-via', _v674)],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:bg-[color-mix(in_oklch,var(--ink)_5%,var(--layer-panel))]',
    2657,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('background-color', _v324)],
      ),
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('background-color', _v676)],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:bg-[oklch(0.4_0.07_27)]',
    2658,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('background-color', _v677)],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:bg-[oklch(0.52_0.006_106.42/0.9)]',
    2659,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('background-color', _v678)],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:bg-[oklch(0.61_0.21_27)]',
    2660,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('background-color', _v679)],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:bg-[oklch(0.69_0.17_46)]',
    2661,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('background-color', _v680)],
      ),
    ],
  ),
  RaftUtility('dark:hover:bg-accent-soft', 2662, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v325)],
    ),
  ]),
  RaftUtility('dark:hover:bg-fill-muted', 2663, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v222)],
    ),
  ]),
  RaftUtility('dark:hover:bg-fill-strong', 2664, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v115)],
    ),
  ]),
  RaftUtility(
    'dark:hover:bg-foreground-strong',
    2665,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('background-color', _v0)],
      ),
    ],
  ),
  RaftUtility('dark:hover:bg-info', 2666, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v62)],
    ),
  ]),
  RaftUtility('dark:hover:bg-info-soft', 2667, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v478)],
    ),
  ]),
  RaftUtility('dark:hover:bg-ink-4', 2668, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v390)],
    ),
  ]),
  RaftUtility('dark:hover:bg-ink-6', 2669, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v275)],
    ),
  ]),
  RaftUtility('dark:hover:border-ink-8', 2655, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [
        RaftDecl('border-top-color', _v276),
        RaftDecl('border-right-color', _v276),
        RaftDecl('border-bottom-color', _v276),
        RaftDecl('border-left-color', _v276),
      ],
    ),
  ]),
  RaftUtility(
    'dark:hover:border-transparent',
    2656,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [
          RaftDecl('border-top-color', _v7),
          RaftDecl('border-right-color', _v7),
          RaftDecl('border-bottom-color', _v7),
          RaftDecl('border-left-color', _v7),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:data-checked:shadow-[0_0_0_1px_oklch(0_0_0/0.45),0_2px_4px_oklch(0_0_0/0.25)]',
    2710,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-checked', 'hover'],
        3000,
        [
          RaftDecl('--tw-shadow', CssList([_v630, _v633])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:data-indeterminate:shadow-[0_0_0_1px_oklch(0_0_0/0.45),0_2px_4px_oklch(0_0_0/0.25)]',
    2722,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'data-indeterminate', 'hover'],
        3000,
        [
          RaftDecl('--tw-shadow', CssList([_v630, _v633])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:not-data-invalid:border-ink-8',
    2679,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover', 'not:data-invalid'],
        3000,
        [
          RaftDecl('border-top-color', _v276),
          RaftDecl('border-right-color', _v276),
          RaftDecl('border-bottom-color', _v276),
          RaftDecl('border-left-color', _v276),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:not-has-[[data-slot=input-group-control][data-invalid]]:border-ink-8',
    2677,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover', 'not:has:data-slot=input-group-control+data-invalid'],
        4000,
        [
          RaftDecl('border-top-color', _v276),
          RaftDecl('border-right-color', _v276),
          RaftDecl('border-bottom-color', _v276),
          RaftDecl('border-left-color', _v276),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:hover:text-[oklch(0.21_0.006_106.42)]',
    2670,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark', 'hover'], 2000, [RaftDecl('color', _v681)]),
    ],
  ),
  RaftUtility(
    'dark:hover:text-[oklch(0.985_0.004_106.42)]',
    2671,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark', 'hover'], 2000, [RaftDecl('color', _v682)]),
    ],
  ),
  RaftUtility(
    'dark:hover:text-accent-strong',
    2672,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark', 'hover'], 2000, [RaftDecl('color', _v157)]),
    ],
  ),
  RaftUtility('dark:hover:text-foreground', 2673, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark', 'hover'], 2000, [RaftDecl('color', _v14)]),
  ]),
  RaftUtility(
    'dark:hover:text-foreground-strong/75',
    2674,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark', 'hover'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer('self', ['dark', 'hover'], 2000, [RaftDecl('color', _v684)]),
    ],
  ),
  RaftUtility(
    'dark:max-md:bg-layer-canvas-muted',
    2755,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'width<768'],
        1000,
        [RaftDecl('background-color', _v68)],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-data-checked:not-data-disabled:bg-layer-card',
    2626,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'not:data-checked', 'not:data-disabled'],
        3000,
        [RaftDecl('background-color', _v484)],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-data-checked:not-data-disabled:bg-layer-inset',
    2627,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'not:data-checked', 'not:data-disabled'],
        3000,
        [RaftDecl('background-color', _v488)],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-data-checked:not-data-disabled:hover:bg-layer-panel',
    2678,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover', 'not:data-checked', 'not:data-disabled'],
        4000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-data-checked:not-data-disabled:shadow-[inset_0_1px_1.5px_oklch(0_0_0/0.3),0_0_0_1px_oklch(0_0_0/0.4),0_1px_0_oklch(0.985_0.004_106.42/0.04)]',
    2628,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'not:data-checked', 'not:data-disabled'],
        3000,
        [RaftDecl('--tw-shadow', _v691), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-data-checked:not-data-indeterminate:shadow-[inset_0_1px_1.5px_oklch(0_0_0/0.3),0_0_0_1px_var(--line-field),0_1px_0_oklch(0.985_0.004_106.42/0.04)]',
    2629,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'not:data-checked', 'not:data-indeterminate'],
        3000,
        [RaftDecl('--tw-shadow', _v694), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-data-invalid:border-transparent',
    2630,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'not:data-invalid'],
        2000,
        [
          RaftDecl('border-top-color', _v7),
          RaftDecl('border-right-color', _v7),
          RaftDecl('border-bottom-color', _v7),
          RaftDecl('border-left-color', _v7),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-data-pressed:bg-fill-muted',
    2631,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'not:data-pressed'],
        2000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-data-pressed:hover:bg-fill-strong',
    2680,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'hover', 'not:data-pressed'],
        3000,
        [RaftDecl('background-color', _v115)],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-data-pressed:shadow-raft-sm',
    2632,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'not:data-pressed'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-has-[[data-slot=input-group-control][data-invalid]]:border-transparent',
    2625,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'not:has:data-slot=input-group-control+data-invalid'],
        3000,
        [
          RaftDecl('border-top-color', _v7),
          RaftDecl('border-right-color', _v7),
          RaftDecl('border-bottom-color', _v7),
          RaftDecl('border-left-color', _v7),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:not-has-data-indeterminate:overflow-visible',
    2624,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark', 'not:has:data-indeterminate'],
        2000,
        [
          RaftDecl('overflow-x', CssKeyword('visible')),
          RaftDecl('overflow-y', CssKeyword('visible')),
        ],
      ),
    ],
  ),
  RaftUtility('dark:pt-2.5', 2572, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('padding-top', CssNum(10, 'px'))],
    ),
  ]),
  RaftUtility('dark:ring-2', 2612, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('dark:ring-ink-10', 2613, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('--tw-ring-color', _v12)]),
  ]),
  RaftUtility('dark:ring-transparent', 2614, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('--tw-ring-color', _v7)]),
  ]),
  RaftUtility('dark:saturate-100', 2616, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('--tw-saturate', _v695), RaftDecl('filter', _v662)],
    ),
  ]),
  RaftUtility(
    'dark:shadow-[0_0_0_1px_oklch(1_0_0/0.08)]',
    2600,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--tw-shadow', _v697), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:shadow-[0_0_0_1px_oklch(1_0_0/0.16)]',
    2601,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--tw-shadow', _v700), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:shadow-[inset_0_1px_0_oklch(0.985_0.004_106.42/0.07),0_0_0_1px_oklch(0_0_0/0.45),0_1.5px_0_oklch(0_0_0/0.5)]',
    2602,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--tw-shadow', _v704), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:shadow-[inset_0_1px_0_oklch(1_0_0/0.04),0_0_0_1px_oklch(0_0_0/0.35)]',
    2603,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [
          RaftDecl('--tw-shadow', CssList([_v707, _v710])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:shadow-[inset_0_1px_0_oklch(1_0_0/0.08),0_1px_1px_color-mix(in_oklab,var(--progress-color)_14%,transparent),0_2px_3px_color-mix(in_oklab,var(--progress-color)_7%,transparent)]',
    2604,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--tw-shadow', _v715), RaftDecl('box-shadow', _v20)],
      ),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--tw-shadow', _v724)]),
    ],
  ),
  RaftUtility(
    'dark:shadow-[inset_0_1px_1.5px_oklch(0_0_0/0.3),0_0_0_1px_oklch(0_0_0/0.4),0_1px_0_oklch(0.985_0.004_106.42/0.04)]',
    2605,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--tw-shadow', _v691), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:shadow-[inset_0_1px_1px_oklch(0_0_0/0.35),0_1px_0_oklch(0.985_0.004_106.42/0.03)]',
    2606,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [
          RaftDecl('--tw-shadow', CssList([_v725, _v728])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'dark:shadow-[inset_0_1px_2px_oklch(0_0_0/0.3),inset_0_0_0_1px_oklch(0_0_0/0.35),0_1px_0_oklch(0.985_0.004_106.42/0.04)]',
    2607,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--tw-shadow', _v731), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'dark:shadow-[inset_0_1px_2px_oklch(0_0_0/0.35),inset_0_0_0_1px_oklch(0_0_0/0.4),0_1px_0_oklch(0.985_0.004_106.42/0.04)]',
    2608,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--tw-shadow', _v734), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('dark:shadow-none', 2609, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('dark:shadow-raft-xl', 2610, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('--tw-shadow', _v646), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('dark:shadow-raft-xs', 2611, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('--tw-shadow', _v279), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'dark:text-[oklch(0.36_0.006_106.42)]',
    2575,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v735)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.78_0.19_25)]',
    2576,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v736)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.82_0.06_90)]',
    2577,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v737)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.82_0.12_61.907)]',
    2578,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v589)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.86_0.09_160)]',
    2579,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v738)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.87_0.06_250)]',
    2580,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v739)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.87_0.06_300)]',
    2581,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v740)]),
    ],
  ),
  RaftUtility('dark:text-[oklch(0.87_0_0)]', 2582, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v741)]),
  ]),
  RaftUtility(
    'dark:text-[oklch(0.88_0.06_18)]',
    2583,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v742)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.89_0.08_80)]',
    2584,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v743)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.8_0.002_67.77)]',
    2573,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v744)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.8_0.17_22)]',
    2574,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v745)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.92_0.003_106.42)]',
    2585,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v587)]),
    ],
  ),
  RaftUtility(
    'dark:text-[oklch(0.985_0.004_106.42)]',
    2586,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v682)]),
    ],
  ),
  RaftUtility('dark:text-accent-strong', 2587, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v157)]),
  ]),
  RaftUtility('dark:text-danger-strong', 2588, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v746)]),
  ]),
  RaftUtility('dark:text-foreground', 2589, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v14)]),
  ]),
  RaftUtility('dark:text-foreground-hint', 2590, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v156)]),
  ]),
  RaftUtility(
    'dark:text-foreground-inverse',
    2591,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v227)]),
    ],
  ),
  RaftUtility('dark:text-foreground-muted', 2592, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v22)]),
  ]),
  RaftUtility(
    'dark:text-foreground-placeholder',
    2593,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v58)]),
    ],
  ),
  RaftUtility('dark:text-foreground-strong', 2594, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v0)]),
  ]),
  RaftUtility(
    'dark:text-foreground-strong/35',
    2595,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v0)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v748)]),
    ],
  ),
  RaftUtility(
    'dark:text-foreground-strong/40',
    2596,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v0)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v750)]),
    ],
  ),
  RaftUtility(
    'dark:text-foreground-strong/50',
    2597,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v0)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v752)]),
    ],
  ),
  RaftUtility('dark:text-primary-strong', 2598, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v159)]),
  ]),
  RaftUtility('dark:text-secondary-300', 2599, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v753)]),
  ]),
  RaftUtility('dark:text-shadow-none', 2623, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('text-shadow', CssKeyword('none'))],
    ),
  ]),
  RaftUtility(
    'data-[active=true]:border-black',
    2055,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active=true'],
        2000,
        [
          RaftDecl('border-top-color', _v5),
          RaftDecl('border-right-color', _v5),
          RaftDecl('border-bottom-color', _v5),
          RaftDecl('border-left-color', _v5),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[active=true]:border-transparent',
    2056,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active=true'],
        2000,
        [
          RaftDecl('border-top-color', _v7),
          RaftDecl('border-right-color', _v7),
          RaftDecl('border-bottom-color', _v7),
          RaftDecl('border-left-color', _v7),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[active=true]:hover:border-black',
    2062,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active=true', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v5),
          RaftDecl('border-right-color', _v5),
          RaftDecl('border-bottom-color', _v5),
          RaftDecl('border-left-color', _v5),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[active=true]:hover:shadow-raft-sm',
    2063,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active=true', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('data-[active=true]:ring-1', 2058, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active=true'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v293), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'data-[active=true]:ring-offset-2',
    2060,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active=true'],
        2000,
        [
          RaftDecl('--tw-ring-offset-width', CssNum(2, 'px')),
          RaftDecl('--tw-ring-offset-shadow', _v664),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[active=true]:ring-offset-layer-canvas-muted',
    2061,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active=true'],
        2000,
        [RaftDecl('--tw-ring-offset-color', _v68)],
      ),
    ],
  ),
  RaftUtility(
    'data-[active=true]:ring-primary-400',
    2059,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active=true'],
        2000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'data-[active=true]:shadow-raft-sm',
    2057,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active=true'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[busy=true]:cursor-wait',
    2069,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-busy=true'],
        2000,
        [RaftDecl('cursor', CssKeyword('wait'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[busy=true]:disabled:opacity-100',
    2071,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-busy=true', 'disabled'],
        3000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility('data-[busy=true]:opacity-60', 2070, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-busy=true'],
      2000,
      [RaftDecl('opacity', CssNum(60, '%'))],
    ),
  ]),
  RaftUtility(
    'data-[busy=true]:pointer-events-none',
    2068,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-busy=true'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[checked]:translate-x-3',
    2072,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [
          RaftDecl('--tw-translate-x', CssNum(12, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[checked]:translate-x-4',
    2073,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [
          RaftDecl('--tw-translate-x', CssNum(16, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[direction=down]:border-t',
    2075,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-direction=down'],
        2000,
        [
          RaftDecl('border-top-style', _v31),
          RaftDecl('border-top-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[direction=down]:bottom-0',
    2074,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-direction=down'],
        2000,
        [RaftDecl('bottom', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[direction=up]:border-b',
    2077,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-direction=up'],
        2000,
        [
          RaftDecl('border-bottom-style', _v31),
          RaftDecl('border-bottom-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('data-[direction=up]:top-0', 2076, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-direction=up'],
      2000,
      [RaftDecl('top', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility(
    'data-[disabled=true]:active:scale-100',
    2092,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-disabled=true'],
        3000,
        [
          RaftDecl('--tw-scale-x', CssNum(100, '%')),
          RaftDecl('--tw-scale-y', CssNum(100, '%')),
          RaftDecl('--tw-scale-z', CssNum(100, '%')),
          RaftDecl('scale', _v277),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:bg-white/35',
    2083,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('background-color', _v295)],
      ),
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('background-color', _v296)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:cursor-default',
    2080,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('cursor', CssKeyword('default'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:cursor-not-allowed',
    2081,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('cursor', _v320)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:hover:bg-black/5',
    2090,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v427)],
      ),
      RaftLayer(
        'self',
        ['data-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v428)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:hover:bg-white/35',
    2091,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v295)],
      ),
      RaftLayer(
        'self',
        ['data-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v296)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:opacity-40',
    2088,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('opacity', CssNum(40, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:pointer-events-none',
    2078,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:shadow-none',
    2089,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:text-black/50',
    2084,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('color', _v66)],
      ),
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('color', _v67)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:text-foreground-disabled',
    2085,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('color', _v754)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:text-foreground-strong/30',
    2086,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-disabled=true'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('color', _v756)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:text-foreground-strong/35',
    2087,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-disabled=true'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('color', _v748)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:touch-auto',
    2082,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('touch-action', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:transform-none',
    2079,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('transform', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[dragging-active=true]:bg-layer-panel',
    2093,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-dragging-active=true'],
        2000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'data-[dragging-active=true]:ring-1',
    2095,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-dragging-active=true'],
        2000,
        [RaftDecl('--tw-ring-shadow', _v293), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[dragging-active=true]:shadow-raft-sm',
    2094,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-dragging-active=true'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[dragging-source=true]:before:hidden',
    2097,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-dragging-source=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('display', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[dragging-source=true]:cursor-grabbing',
    2096,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-dragging-source=true'],
        2000,
        [RaftDecl('cursor', CssKeyword('grabbing'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[dragging=true]:opacity-90',
    2099,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-dragging=true'],
        2000,
        [RaftDecl('opacity', CssNum(90, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[dragging=true]:will-change-transform',
    2100,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-dragging=true'],
        2000,
        [RaftDecl('will-change', CssKeyword('transform'))],
      ),
    ],
  ),
  RaftUtility('data-[dragging=true]:z-20', 2098, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-dragging=true'],
      2000,
      [RaftDecl('z-index', CssNum(20))],
    ),
  ]),
  RaftUtility(
    'data-[drop-collapsed=true]:data-[drop-state=allowed]:[outline:1px_dashed_var(--line-muted)]',
    2105,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-drop-collapsed=true', 'data-drop-state=allowed'],
        3000,
        [
          RaftDecl('outline-width', CssNum(1, 'px')),
          RaftDecl('outline-style', CssKeyword('dashed')),
          RaftDecl('outline-color', _v81),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[drop-state=allowed]:bg-primary/20',
    2103,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-drop-state=allowed'],
        2000,
        [RaftDecl('background-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['data-drop-state=allowed'],
        2000,
        [RaftDecl('background-color', _v504)],
      ),
    ],
  ),
  RaftUtility(
    'data-[drop-state=allowed]:block',
    2101,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-drop-state=allowed'],
        2000,
        [RaftDecl('display', CssKeyword('block'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[drop-state=allowed]:border-line-strong',
    2102,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-drop-state=allowed'],
        2000,
        [
          RaftDecl('border-top-color', _v43),
          RaftDecl('border-right-color', _v43),
          RaftDecl('border-bottom-color', _v43),
          RaftDecl('border-left-color', _v43),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[drop-state=allowed]:shadow-raft-sm',
    2104,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-drop-state=allowed'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[drop-state=blocked]:bg-danger-soft',
    2107,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-drop-state=blocked'],
        2000,
        [RaftDecl('background-color', _v326)],
      ),
    ],
  ),
  RaftUtility(
    'data-[drop-state=blocked]:border-danger',
    2106,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-drop-state=blocked'],
        2000,
        [
          RaftDecl('border-top-color', _v137),
          RaftDecl('border-right-color', _v137),
          RaftDecl('border-bottom-color', _v137),
          RaftDecl('border-left-color', _v137),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[emphasis=strong]:font-bold',
    2108,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-emphasis=strong'],
        2000,
        [
          RaftDecl('--tw-font-weight', CssNum(700)),
          RaftDecl('font-weight', CssNum(700)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[fit=contain]:object-contain',
    2109,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-fit=contain'],
        2000,
        [RaftDecl('object-fit', CssKeyword('contain'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[fit=cover]:object-cover',
    2110,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-fit=cover'],
        2000,
        [RaftDecl('object-fit', CssKeyword('cover'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[followed-by=compact]:pb-0.5',
    2111,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-followed-by=compact'],
        2000,
        [RaftDecl('padding-bottom', CssNum(2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[followed-by=group]:pb-1.5',
    2112,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-followed-by=group'],
        2000,
        [RaftDecl('padding-bottom', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[highlighted=true]:bg-ink-4',
    2113,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-highlighted=true'],
        2000,
        [RaftDecl('background-color', _v390)],
      ),
    ],
  ),
  RaftUtility(
    'data-[highlighted=true]:bg-primary',
    2114,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-highlighted=true'],
        2000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'data-[highlighted=true]:font-bold',
    2115,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-highlighted=true'],
        2000,
        [
          RaftDecl('--tw-font-weight', CssNum(700)),
          RaftDecl('font-weight', CssNum(700)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[highlighted=true]:text-foreground',
    2116,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-highlighted=true'],
        2000,
        [RaftDecl('color', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'data-[icon-kind=avatar]:bg-transparent',
    2117,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-icon-kind=avatar'],
        2000,
        [RaftDecl('background-color', _v7)],
      ),
    ],
  ),
  RaftUtility(
    'data-[indeterminate]:inset-y-0',
    2118,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('top', CssNum(0, 'px')), RaftDecl('bottom', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[interaction=accent]:data-highlighted:bg-brutal-pink',
    2120,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-highlighted', 'data-interaction=accent'],
        3000,
        [RaftDecl('background-color', CssColor(0xFFFE7DA8))],
      ),
    ],
  ),
  RaftUtility(
    'data-[interaction=accent]:hover:bg-brutal-pink',
    2119,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-interaction=accent', 'hover'],
        3000,
        [RaftDecl('background-color', CssColor(0xFFFE7DA8))],
      ),
    ],
  ),
  RaftUtility(
    'data-[interaction=signal]:data-highlighted:bg-primary',
    2122,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-highlighted', 'data-interaction=signal'],
        3000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'data-[interaction=signal]:hover:bg-primary',
    2121,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-interaction=signal', 'hover'],
        3000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'data-[interactive=true]:active:bg-[color-mix(in_oklch,var(--ink)_1%,var(--layer-panel))]',
    2124,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-interactive=true'],
        3000,
        [RaftDecl('background-color', _v324)],
      ),
      RaftLayer(
        'self',
        ['active', 'data-interactive=true'],
        3000,
        [RaftDecl('background-color', _v758)],
      ),
    ],
  ),
  RaftUtility(
    'data-[interactive=true]:cursor-pointer',
    2123,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-interactive=true'],
        2000,
        [RaftDecl('cursor', CssKeyword('pointer'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[layer=blur]:[-webkit-mask-image:linear-gradient(to_bottom,black_0%,black_22%,oklch(0_0_0/0.55)_48%,transparent_100%)]',
    2129,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-layer=blur'],
        2000,
        [RaftDecl('-webkit-mask-image', _v762)],
      ),
    ],
  ),
  RaftUtility(
    'data-[layer=blur]:[mask-image:linear-gradient(to_bottom,black_0%,black_22%,oklch(0_0_0/0.55)_48%,transparent_100%)]',
    2126,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-layer=blur'],
        2000,
        [RaftDecl('mask-image', _v762)],
      ),
    ],
  ),
  RaftUtility(
    'data-[layer=blur]:backdrop-blur-[14px]',
    2127,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-layer=blur'],
        2000,
        [
          RaftDecl('--tw-backdrop-blur', _v763),
          RaftDecl('-webkit-backdrop-filter', _v340),
          RaftDecl('backdrop-filter', _v340),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[layer=blur]:backdrop-saturate-125',
    2128,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-layer=blur'],
        2000,
        [
          RaftDecl('--tw-backdrop-saturate', _v764),
          RaftDecl('-webkit-backdrop-filter', _v340),
          RaftDecl('backdrop-filter', _v340),
        ],
      ),
    ],
  ),
  RaftUtility('data-[layer=blur]:h-[112%]', 2125, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-layer=blur'],
      2000,
      [RaftDecl('height', CssNum(112, '%'))],
    ),
  ]),
  RaftUtility(
    'data-[layer=soft]:bg-[linear-gradient(to_bottom,color-mix(in_oklch,var(--layer-canvas-muted)_48%,transparent)_0%,color-mix(in_oklch,var(--layer-canvas-muted)_18%,transparent)_40%,transparent_100%)]',
    2131,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-layer=soft'],
        2000,
        [RaftDecl('background-image', _v767)],
      ),
      RaftLayer(
        'self',
        ['data-layer=soft'],
        2000,
        [RaftDecl('background-image', _v774)],
      ),
    ],
  ),
  RaftUtility('data-[layer=soft]:h-[108%]', 2130, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-layer=soft'],
      2000,
      [RaftDecl('height', CssNum(108, '%'))],
    ),
  ]),
  RaftUtility(
    'data-[layer=solid]:bg-[linear-gradient(to_bottom,var(--layer-canvas-muted)_0%,var(--layer-canvas-muted)_28%,color-mix(in_oklch,var(--layer-canvas-muted)_82%,transparent)_52%,transparent_100%)]',
    2132,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-layer=solid'],
        2000,
        [RaftDecl('background-image', _v777)],
      ),
      RaftLayer(
        'self',
        ['data-layer=solid'],
        2000,
        [RaftDecl('background-image', _v781)],
      ),
    ],
  ),
  RaftUtility(
    'data-[loading=true]:cursor-wait',
    2134,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-loading=true'],
        2000,
        [RaftDecl('cursor', CssKeyword('wait'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[loading=true]:invisible',
    2133,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-loading=true'],
        2000,
        [RaftDecl('visibility', CssKeyword('hidden'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[loading=true]:opacity-100',
    2135,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-loading=true'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:bg-transparent',
    2144,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true'],
        2000,
        [RaftDecl('background-color', _v7)],
      ),
    ],
  ),
  RaftUtility('data-[nested=true]:border-0', 2137, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-nested=true'],
      2000,
      [
        RaftDecl('border-top-style', _v31),
        RaftDecl('border-right-style', _v31),
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-left-style', _v31),
        RaftDecl('border-top-width', CssNum(0, 'px')),
        RaftDecl('border-right-width', CssNum(0, 'px')),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
        RaftDecl('border-left-width', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'data-[nested=true]:border-b-0',
    2141,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true'],
        2000,
        [
          RaftDecl('border-bottom-style', _v31),
          RaftDecl('border-bottom-width', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:border-black/10',
    2142,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true'],
        2000,
        [
          RaftDecl('border-top-color', _v263),
          RaftDecl('border-right-color', _v263),
          RaftDecl('border-bottom-color', _v263),
          RaftDecl('border-left-color', _v263),
        ],
      ),
      RaftLayer(
        'self',
        ['data-nested=true'],
        2000,
        [
          RaftDecl('border-top-color', _v264),
          RaftDecl('border-right-color', _v264),
          RaftDecl('border-bottom-color', _v264),
          RaftDecl('border-left-color', _v264),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:border-line-hairline',
    2143,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true'],
        2000,
        [
          RaftDecl('border-top-color', _v158),
          RaftDecl('border-right-color', _v158),
          RaftDecl('border-bottom-color', _v158),
          RaftDecl('border-left-color', _v158),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:border-t-2',
    2139,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true'],
        2000,
        [
          RaftDecl('border-top-style', _v31),
          RaftDecl('border-top-width', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:border-t-[0.5px]',
    2140,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true'],
        2000,
        [
          RaftDecl('border-top-style', _v31),
          RaftDecl('border-top-width', CssNum(0.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:border-x-0',
    2138,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true'],
        2000,
        [
          RaftDecl('border-left-style', _v31),
          RaftDecl('border-right-style', _v31),
          RaftDecl('border-left-width', CssNum(0, 'px')),
          RaftDecl('border-right-width', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:hover:bg-black/3',
    2150,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v421)],
      ),
      RaftLayer(
        'self',
        ['data-nested=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v422)],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:hover:bg-ink-2',
    2151,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v147)],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:hover:border-black/10',
    2149,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v263),
          RaftDecl('border-right-color', _v263),
          RaftDecl('border-bottom-color', _v263),
          RaftDecl('border-left-color', _v263),
        ],
      ),
      RaftLayer(
        'self',
        ['data-nested=true', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v264),
          RaftDecl('border-right-color', _v264),
          RaftDecl('border-bottom-color', _v264),
          RaftDecl('border-left-color', _v264),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:hover:shadow-none',
    2152,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('data-[nested=true]:p-3', 2145, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-nested=true'],
      2000,
      [
        RaftDecl('padding-top', CssNum(12, 'px')),
        RaftDecl('padding-right', CssNum(12, 'px')),
        RaftDecl('padding-bottom', CssNum(12, 'px')),
        RaftDecl('padding-left', CssNum(12, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-[nested=true]:px-3', 2146, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-nested=true'],
      2000,
      [
        RaftDecl('padding-left', CssNum(12, 'px')),
        RaftDecl('padding-right', CssNum(12, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-[nested=true]:py-3', 2147, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-nested=true'],
      2000,
      [
        RaftDecl('padding-top', CssNum(12, 'px')),
        RaftDecl('padding-bottom', CssNum(12, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'data-[nested=true]:rounded-none',
    2136,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true'],
        2000,
        [
          RaftDecl('border-top-left-radius', CssNum(0)),
          RaftDecl('border-top-right-radius', CssNum(0)),
          RaftDecl('border-bottom-right-radius', CssNum(0)),
          RaftDecl('border-bottom-left-radius', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true]:shadow-none',
    2148,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested=true'],
        2000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[nested=true][data-selected=true]:bg-[oklch(0.96299649_0.06890535_97.696701)]',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'data-[nested=true][data-selected=true]:bg-fill-muted',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'data-[nested=true][data-selected=true]:border-black',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'data-[nested=true][data-selected=true]:border-line-hairline',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'data-[nested=true][data-selected=true]:ring-0',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'data-[nested=true][data-selected=true]:shadow-none',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:-mb-1.5',
    2155,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('margin-bottom', CssNum(-6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:-mt-1.5',
    2153,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('margin-top', CssNum(-6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:before:h-1',
    2170,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-orientation=horizontal'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('height', CssNum(4, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:before:left-1/2',
    2169,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-orientation=horizontal'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', CssNum(50, '%')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:before:top-1/2',
    2168,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-orientation=horizontal'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(50, '%')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:before:w-6',
    2171,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-orientation=horizontal'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('width', CssNum(24, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:border-line-strong',
    2167,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [
          RaftDecl('border-top-color', _v43),
          RaftDecl('border-right-color', _v43),
          RaftDecl('border-bottom-color', _v43),
          RaftDecl('border-left-color', _v43),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:border-t-2',
    2166,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [
          RaftDecl('border-top-style', _v31),
          RaftDecl('border-top-width', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:cursor-ns-resize',
    2161,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('cursor', CssKeyword('ns-resize'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:flex-col',
    2162,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('flex-direction', CssKeyword('column'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:flex-row',
    2163,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('flex-direction', CssKeyword('row'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:flex-wrap',
    2164,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('flex-wrap', CssKeyword('wrap'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:h-0',
    2157,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('height', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:h-3',
    2158,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('height', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:h-px',
    2159,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('height', CssNum(1, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:justify-center',
    2165,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('justify-content', CssKeyword('center'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:ml-0',
    2156,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('margin-left', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:mr-0',
    2154,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('margin-right', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:w-full',
    2160,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('width', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=vertical]:border-l-2',
    2179,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=vertical'],
        2000,
        [
          RaftDecl('border-left-style', _v31),
          RaftDecl('border-left-width', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=vertical]:border-line-strong',
    2180,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=vertical'],
        2000,
        [
          RaftDecl('border-top-color', _v43),
          RaftDecl('border-right-color', _v43),
          RaftDecl('border-bottom-color', _v43),
          RaftDecl('border-left-color', _v43),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=vertical]:flex-col',
    2175,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=vertical'],
        2000,
        [RaftDecl('flex-direction', CssKeyword('column'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=vertical]:items-stretch',
    2176,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=vertical'],
        2000,
        [RaftDecl('align-items', CssKeyword('stretch'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=vertical]:justify-center',
    2177,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=vertical'],
        2000,
        [RaftDecl('justify-content', CssKeyword('center'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=vertical]:self-stretch',
    2178,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=vertical'],
        2000,
        [RaftDecl('align-self', CssKeyword('stretch'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=vertical]:w-0',
    2172,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=vertical'],
        2000,
        [RaftDecl('width', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=vertical]:w-3',
    2173,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=vertical'],
        2000,
        [RaftDecl('width', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=vertical]:w-px',
    2174,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=vertical'],
        2000,
        [RaftDecl('width', CssNum(1, 'px'))],
      ),
    ],
  ),
  RaftUtility('data-[panel-open]:mb-3', 2181, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-panel-open'],
      2000,
      [RaftDecl('margin-bottom', CssNum(12, 'px'))],
    ),
  ]),
  RaftUtility(
    'data-[reorderable=true]:cursor-pointer',
    2182,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-reorderable=true'],
        2000,
        [RaftDecl('cursor', CssKeyword('pointer'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[reorderable=true]:data-active:bg-layer-panel',
    2183,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active', 'data-reorderable=true'],
        3000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'data-[reorderable=true]:data-active:ring-1',
    2185,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active', 'data-reorderable=true'],
        3000,
        [RaftDecl('--tw-ring-shadow', _v293), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[reorderable=true]:data-active:shadow-raft-sm',
    2184,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active', 'data-reorderable=true'],
        3000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:absolute',
    2205,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('position', CssKeyword('absolute')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:bg-[linear-gradient(in_oklab_180deg,oklab(100%_0_0/12%)_0%,oklab(0%_0_0/6%)_100%)]',
    2209,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-image', _v786),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:content-[\'\']',
    2210,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('--tw-content', CssString('')),
          RaftDecl('content', CssVar('--tw-content')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:inset-0',
    2206,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(0, 'px')),
          RaftDecl('right', CssNum(0, 'px')),
          RaftDecl('bottom', CssNum(0, 'px')),
          RaftDecl('left', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:pointer-events-none',
    2204,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('pointer-events', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:rounded-[inherit]',
    2208,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('border-top-left-radius', CssKeyword('inherit')),
          RaftDecl('border-top-right-radius', CssKeyword('inherit')),
          RaftDecl('border-bottom-right-radius', CssKeyword('inherit')),
          RaftDecl('border-bottom-left-radius', CssKeyword('inherit')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:z-0',
    2207,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('z-index', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:bg-fill-strong',
    2189,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('background-color', _v115)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:bg-layer-panel',
    2190,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:bg-primary-400',
    2191,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:bg-white',
    2192,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('background-color', _v39)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:border-black',
    2187,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [
          RaftDecl('border-top-color', _v5),
          RaftDecl('border-right-color', _v5),
          RaftDecl('border-bottom-color', _v5),
          RaftDecl('border-left-color', _v5),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:border-transparent',
    2188,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [
          RaftDecl('border-top-color', _v7),
          RaftDecl('border-right-color', _v7),
          RaftDecl('border-bottom-color', _v7),
          RaftDecl('border-left-color', _v7),
        ],
      ),
    ],
  ),
  RaftUtility('data-[selected=true]:ring-1', 2199, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-selected=true'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v293), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'data-[selected=true]:ring-line-muted/45',
    2200,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('--tw-ring-color', _v81)],
      ),
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('--tw-ring-color', _v788)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:ring-offset-2',
    2202,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [
          RaftDecl('--tw-ring-offset-width', CssNum(2, 'px')),
          RaftDecl('--tw-ring-offset-shadow', _v664),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:ring-offset-layer-canvas-muted',
    2203,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('--tw-ring-offset-color', _v68)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:ring-primary-400',
    2201,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:shadow-none',
    2196,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:shadow-raft-sm',
    2197,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:shadow-raft-xl',
    2198,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('--tw-shadow', _v646), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:text-black',
    2193,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-selected=true'], 2000, [RaftDecl('color', _v5)]),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:text-foreground-muted',
    2194,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('color', _v22)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:text-foreground-strong',
    2195,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-selected=true'], 2000, [RaftDecl('color', _v0)]),
    ],
  ),
  RaftUtility('data-[selected]:font-bold', 2186, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-selected'],
      2000,
      [
        RaftDecl('--tw-font-weight', CssNum(700)),
        RaftDecl('font-weight', CssNum(700)),
      ],
    ),
  ]),
  RaftUtility(
    'data-[selected][data-highlighted]:bg-primary/30',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'data-[separator=active]:before:bg-black/20',
    2211,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-separator=active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v418),
        ],
      ),
      RaftLayer(
        '::before',
        ['data-separator=active'],
        2001,
        [RaftDecl('background-color', _v419)],
      ),
    ],
  ),
  RaftUtility(
    'data-[separator=active]:before:bg-ink-20',
    2212,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-separator=active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v375),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=bottom]:rotate-180',
    2214,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=bottom'],
        2000,
        [RaftDecl('rotate', CssNum(180, 'deg'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=bottom]:top-[-5px]',
    2213,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=bottom'],
        2000,
        [RaftDecl('top', CssNum(-5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=inline-end]:left-[-7px]',
    2215,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=inline-end'],
        2000,
        [RaftDecl('left', CssNum(-7, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=inline-end]:left-[-8px]',
    2216,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=inline-end'],
        2000,
        [RaftDecl('left', CssNum(-8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=inline-end]:rotate-90',
    2217,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=inline-end'],
        2000,
        [RaftDecl('rotate', CssNum(90, 'deg'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=inline-start]:-rotate-90',
    2220,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=inline-start'],
        2000,
        [RaftDecl('rotate', CssNum(-90, 'deg'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=inline-start]:right-[-7px]',
    2218,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=inline-start'],
        2000,
        [RaftDecl('right', CssNum(-7, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=inline-start]:right-[-8px]',
    2219,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=inline-start'],
        2000,
        [RaftDecl('right', CssNum(-8, 'px'))],
      ),
    ],
  ),
  RaftUtility('data-[side=left]:-rotate-90', 2223, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-side=left'],
      2000,
      [RaftDecl('rotate', CssNum(-90, 'deg'))],
    ),
  ]),
  RaftUtility(
    'data-[side=left]:right-[-7px]',
    2221,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=left'],
        2000,
        [RaftDecl('right', CssNum(-7, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=left]:right-[-8px]',
    2222,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=left'],
        2000,
        [RaftDecl('right', CssNum(-8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=right]:left-[-7px]',
    2224,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=right'],
        2000,
        [RaftDecl('left', CssNum(-7, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=right]:left-[-8px]',
    2225,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=right'],
        2000,
        [RaftDecl('left', CssNum(-8, 'px'))],
      ),
    ],
  ),
  RaftUtility('data-[side=right]:rotate-90', 2226, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-side=right'],
      2000,
      [RaftDecl('rotate', CssNum(90, 'deg'))],
    ),
  ]),
  RaftUtility(
    'data-[side=top]:bottom-[-5px]',
    2227,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-side=top'],
        2000,
        [RaftDecl('bottom', CssNum(-5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[slot=message-item-sender-button]:cursor-pointer',
    2289,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-slot=message-item-sender-button'],
        2000,
        [RaftDecl('cursor', CssKeyword('pointer'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[slot=message-item-sender-button]:hover:decoration-2',
    2291,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-slot=message-item-sender-button', 'hover'],
        3000,
        [RaftDecl('text-decoration-thickness', CssNum(2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[slot=message-item-sender-button]:hover:underline',
    2290,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-slot=message-item-sender-button', 'hover'],
        3000,
        [RaftDecl('text-decoration-line', CssKeyword('underline'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[slot=message-item-sender-button]:hover:underline-offset-2',
    2292,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-slot=message-item-sender-button', 'hover'],
        3000,
        [RaftDecl('text-underline-offset', CssNum(2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[sorting=true]:**:data-[slot=tabs-indicator]:opacity-0',
    2327,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="tabs-indicator"]',
        ['data-sorting=true'],
        3000,
        [RaftDecl('opacity', CssNum(0, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[sorting=true]:**:data-[slot=tabs-indicator]:transition-none',
    2328,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="tabs-indicator"]',
        ['data-sorting=true'],
        3000,
        [RaftDecl('transition-property', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[sorting=true]:overflow-x-hidden',
    2325,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-sorting=true'],
        2000,
        [RaftDecl('overflow-x', CssKeyword('hidden'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[sorting=true]:overflow-y-hidden',
    2326,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-sorting=true'],
        2000,
        [RaftDecl('overflow-y', CssKeyword('hidden'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=copied]:**:data-[icon=check]:opacity-100',
    2330,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="check"]',
        ['data-state=copied'],
        3000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=copied]:**:data-[icon=check]:scale-100',
    2329,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="check"]',
        ['data-state=copied'],
        3000,
        [
          RaftDecl('--tw-scale-x', CssNum(100, '%')),
          RaftDecl('--tw-scale-y', CssNum(100, '%')),
          RaftDecl('--tw-scale-z', CssNum(100, '%')),
          RaftDecl('scale', _v277),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=copied]:**:data-[icon=copy]:blur-[1px]',
    2333,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="copy"]',
        ['data-state=copied'],
        3000,
        [RaftDecl('--tw-blur', _v789), RaftDecl('filter', _v662)],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=copied]:**:data-[icon=copy]:opacity-0',
    2332,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="copy"]',
        ['data-state=copied'],
        3000,
        [RaftDecl('opacity', CssNum(0, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=copied]:**:data-[icon=copy]:scale-[0.72]',
    2331,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="copy"]',
        ['data-state=copied'],
        3000,
        [RaftDecl('scale', CssNum(0.72))],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=copied]:[&_[data-icon=check]]:blur-0',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility(
    'data-[state=idle]:**:data-[icon=check]:blur-[1px]',
    2336,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="check"]',
        ['data-state=idle'],
        3000,
        [RaftDecl('--tw-blur', _v789), RaftDecl('filter', _v662)],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=idle]:**:data-[icon=check]:opacity-0',
    2335,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="check"]',
        ['data-state=idle'],
        3000,
        [RaftDecl('opacity', CssNum(0, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=idle]:**:data-[icon=check]:scale-[0.72]',
    2334,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="check"]',
        ['data-state=idle'],
        3000,
        [RaftDecl('scale', CssNum(0.72))],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=idle]:**:data-[icon=copy]:opacity-100',
    2338,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="copy"]',
        ['data-state=idle'],
        3000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=idle]:**:data-[icon=copy]:scale-100',
    2337,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="copy"]',
        ['data-state=idle'],
        3000,
        [
          RaftDecl('--tw-scale-x', CssNum(100, '%')),
          RaftDecl('--tw-scale-y', CssNum(100, '%')),
          RaftDecl('--tw-scale-z', CssNum(100, '%')),
          RaftDecl('scale', _v277),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=idle]:[&_[data-icon=copy]]:blur-0',
    -1,
    RaftUtilityStatus.noCss,
    [],
  ),
  RaftUtility('data-[tight-fold]:after:h-5', 2343, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::after',
      ['data-tight-fold'],
      2001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('height', CssNum(20, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'data-[variant=block]:bg-foreground-strong/8',
    2345,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=block'],
        2000,
        [RaftDecl('background-color', _v0)],
      ),
      RaftLayer(
        'self',
        ['data-variant=block'],
        2000,
        [RaftDecl('background-color', _v476)],
      ),
    ],
  ),
  RaftUtility(
    'data-[variant=block]:bg-ink-10',
    2346,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=block'],
        2000,
        [RaftDecl('background-color', _v12)],
      ),
    ],
  ),
  RaftUtility(
    'data-[variant=block]:rounded-md',
    2344,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=block'],
        2000,
        [
          RaftDecl('border-top-left-radius', CssNum(6, 'px')),
          RaftDecl('border-top-right-radius', CssNum(6, 'px')),
          RaftDecl('border-bottom-right-radius', CssNum(6, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[variant=line]:bg-foreground-strong/8',
    2348,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=line'],
        2000,
        [RaftDecl('background-color', _v0)],
      ),
      RaftLayer(
        'self',
        ['data-variant=line'],
        2000,
        [RaftDecl('background-color', _v476)],
      ),
    ],
  ),
  RaftUtility(
    'data-[variant=line]:bg-ink-10',
    2349,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=line'],
        2000,
        [RaftDecl('background-color', _v12)],
      ),
    ],
  ),
  RaftUtility(
    'data-[variant=line]:rounded-full',
    2347,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=line'],
        2000,
        [
          RaftDecl('border-top-left-radius', _v77),
          RaftDecl('border-top-right-radius', _v77),
          RaftDecl('border-bottom-right-radius', _v77),
          RaftDecl('border-bottom-left-radius', _v77),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[variant=primary]:bg-[color-mix(in_srgb-linear,var(--color-primary-400)_86%,var(--ink))]',
    2350,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=primary'],
        2000,
        [RaftDecl('background-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['data-variant=primary'],
        2000,
        [RaftDecl('background-color', _v793)],
      ),
    ],
  ),
  RaftUtility('data-[x=left]:border-l-2', 2352, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-x=left'],
      2000,
      [
        RaftDecl('border-left-style', _v31),
        RaftDecl('border-left-width', CssNum(2, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-[x=left]:left-0', 2351, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-x=left'],
      2000,
      [RaftDecl('left', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('data-[x=right]:border-r-2', 2354, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-x=right'],
      2000,
      [
        RaftDecl('border-right-style', _v31),
        RaftDecl('border-right-width', CssNum(2, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-[x=right]:right-0', 2353, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-x=right'],
      2000,
      [RaftDecl('right', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('data-[y=bottom]:border-b-2', 2356, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-y=bottom'],
      2000,
      [
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-bottom-width', CssNum(2, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-[y=bottom]:bottom-0', 2355, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-y=bottom'],
      2000,
      [RaftDecl('bottom', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('data-[y=top]:border-t-2', 2358, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-y=top'],
      2000,
      [
        RaftDecl('border-top-style', _v31),
        RaftDecl('border-top-width', CssNum(2, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-[y=top]:top-0', 2357, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-y=top'], 2000, [RaftDecl('top', CssNum(0, 'px'))]),
  ]),
  RaftUtility(
    'data-active:**:data-[slot=tabs-label]:text-[13px]',
    2307,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="tabs-label"]',
        ['data-active'],
        3000,
        [RaftDecl('font-size', CssNum(13, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-active:[&_svg]:text-foreground',
    2885,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', ['data-active'], 2001, [RaftDecl('color', _v14)]),
    ],
  ),
  RaftUtility(
    'data-active:[&_svg]:text-foreground-active',
    2886,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', ['data-active'], 2001, [RaftDecl('color', _v794)]),
    ],
  ),
  RaftUtility('data-active:bg-brutal-pink', 1844, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('background-color', CssColor(0xFFFE7DA8))],
    ),
  ]),
  RaftUtility(
    'data-active:bg-brutal-yellow',
    1845,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [RaftDecl('background-color', CssColor(0xFFFFD440))],
      ),
    ],
  ),
  RaftUtility('data-active:bg-layer-panel', 1846, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('background-color', _v38)],
    ),
  ]),
  RaftUtility('data-active:bg-primary-400', 1847, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('background-color', _v118)],
    ),
  ]),
  RaftUtility('data-active:bg-white', 1848, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('background-color', _v39)],
    ),
  ]),
  RaftUtility('data-active:border-[3px]', 1839, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [
        RaftDecl('border-top-style', _v31),
        RaftDecl('border-right-style', _v31),
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-left-style', _v31),
        RaftDecl('border-top-width', CssNum(3, 'px')),
        RaftDecl('border-right-width', CssNum(3, 'px')),
        RaftDecl('border-bottom-width', CssNum(3, 'px')),
        RaftDecl('border-left-width', CssNum(3, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-active:border-black', 1840, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [
        RaftDecl('border-top-color', _v5),
        RaftDecl('border-right-color', _v5),
        RaftDecl('border-bottom-color', _v5),
        RaftDecl('border-left-color', _v5),
      ],
    ),
  ]),
  RaftUtility(
    'data-active:border-transparent',
    1841,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [
          RaftDecl('border-top-color', _v7),
          RaftDecl('border-right-color', _v7),
          RaftDecl('border-bottom-color', _v7),
          RaftDecl('border-left-color', _v7),
        ],
      ),
    ],
  ),
  RaftUtility('data-active:border-white', 1842, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [
        RaftDecl('border-top-color', _v39),
        RaftDecl('border-right-color', _v39),
        RaftDecl('border-bottom-color', _v39),
        RaftDecl('border-left-color', _v39),
      ],
    ),
  ]),
  RaftUtility('data-active:border-white/90', 1843, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [
        RaftDecl('border-top-color', _v796),
        RaftDecl('border-right-color', _v796),
        RaftDecl('border-bottom-color', _v796),
        RaftDecl('border-left-color', _v796),
      ],
    ),
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [
        RaftDecl('border-top-color', _v797),
        RaftDecl('border-right-color', _v797),
        RaftDecl('border-bottom-color', _v797),
        RaftDecl('border-left-color', _v797),
      ],
    ),
  ]),
  RaftUtility(
    'data-active:hover:[&_svg]:text-foreground',
    2887,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& svg',
        ['data-active', 'hover'],
        3001,
        [RaftDecl('color', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'data-active:hover:bg-primary-400',
    1859,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active', 'hover'],
        3000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'data-active:hover:text-brutal-orange',
    1860,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active', 'hover'],
        3000,
        [RaftDecl('color', CssColor(0xFFF8A16F))],
      ),
    ],
  ),
  RaftUtility(
    'data-active:hover:text-foreground',
    1861,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active', 'hover'],
        3000,
        [RaftDecl('color', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'data-active:hover:text-foreground-active',
    1862,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active', 'hover'],
        3000,
        [RaftDecl('color', _v794)],
      ),
    ],
  ),
  RaftUtility(
    'data-active:hover:text-primary-400',
    1863,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active', 'hover'],
        3000,
        [RaftDecl('color', _v118)],
      ),
    ],
  ),
  RaftUtility('data-active:opacity-100', 1854, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility('data-active:ring-1', 1857, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v293), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'data-active:ring-line-muted/45',
    1858,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [RaftDecl('--tw-ring-color', _v81)],
      ),
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [RaftDecl('--tw-ring-color', _v788)],
      ),
    ],
  ),
  RaftUtility(
    'data-active:shadow-[4px_4px_0_0_black]',
    1855,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [RaftDecl('--tw-shadow', _v799), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('data-active:shadow-raft-sm', 1856, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'data-active:text-brutal-orange',
    1849,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [RaftDecl('color', CssColor(0xFFF8A16F))],
      ),
    ],
  ),
  RaftUtility('data-active:text-foreground', 1850, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-active'], 2000, [RaftDecl('color', _v14)]),
  ]),
  RaftUtility(
    'data-active:text-foreground-active',
    1851,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-active'], 2000, [RaftDecl('color', _v794)]),
    ],
  ),
  RaftUtility(
    'data-active:text-foreground-strong',
    1852,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-active'], 2000, [RaftDecl('color', _v0)]),
    ],
  ),
  RaftUtility(
    'data-active:text-primary-400',
    1853,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-active'], 2000, [RaftDecl('color', _v118)]),
    ],
  ),
  RaftUtility(
    'data-checked:bg-[color-mix(in_srgb-linear,var(--primary-400)_94%,var(--ink))]',
    1874,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [RaftDecl('background-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [RaftDecl('background-color', _v801)],
      ),
    ],
  ),
  RaftUtility('data-checked:bg-primary-400', 1875, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-checked'],
      2000,
      [RaftDecl('background-color', _v118)],
    ),
  ]),
  RaftUtility(
    'data-checked:data-disabled:bg-fill-muted',
    1911,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'data-disabled'],
        3000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:data-disabled:bg-layer-panel',
    1912,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'data-disabled'],
        3000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:data-disabled:shadow-[0_1px_1px_-1px_oklch(0_0_0/0.02),0_0_0_1px_var(--line-muted)]',
    1914,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'data-disabled'],
        3000,
        [
          RaftDecl('--tw-shadow', CssList([_v804, _v670])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:data-disabled:shadow-[inset_0_0_0_1px_var(--line-muted)]',
    1915,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'data-disabled'],
        3000,
        [RaftDecl('--tw-shadow', _v805), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:data-disabled:text-line',
    1913,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'data-disabled'],
        3000,
        [RaftDecl('color', _v806)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:hover:bg-primary-hover',
    1885,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'hover'],
        3000,
        [RaftDecl('background-color', _v807)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:not-data-disabled:hover:bg-primary-400',
    1888,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'hover', 'not:data-disabled'],
        4000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:not-data-disabled:hover:bg-primary-hover',
    1889,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'hover', 'not:data-disabled'],
        4000,
        [RaftDecl('background-color', _v807)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:shadow-[0_1px_1.5px_-1px_color-mix(in_srgb,var(--primary-glow)_8%,transparent),0_0_0_1px_var(--primary-edge)]',
    1879,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v810, _v813])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v817, _v813])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:shadow-[0_1px_1.5px_-1px_oklch(0_0_0/0.06),0_0_0_0.5px_color-mix(in_srgb,var(--primary-400)_20%,transparent)]',
    1880,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v820, _v822])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v820, _v825])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:shadow-[0_2px_2px_-1px_oklch(0_0_0/0.04),0_4px_4px_-2px_oklch(0_0_0/0.02)]',
    1881,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v828, _v829])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.12),0_1px_1.5px_-1px_oklch(0_0_0/0.12)]',
    1883,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v644, _v832])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.2),0_1px_1px_-0.5px_color-mix(in_srgb,var(--primary-glow)_10%,transparent),0_2px_2px_-1px_color-mix(in_srgb,var(--primary-glow)_6%,transparent),0_0_0_1px_var(--primary-edge)]',
    1882,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [RaftDecl('--tw-shadow', _v837), RaftDecl('box-shadow', _v20)],
      ),
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [RaftDecl('--tw-shadow', _v846)],
      ),
    ],
  ),
  RaftUtility('data-checked:shadow-none', 1884, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-checked'],
      2000,
      [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'data-checked:text-foreground',
    1876,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-checked'], 2000, [RaftDecl('color', _v14)]),
    ],
  ),
  RaftUtility(
    'data-checked:text-primary-950',
    1877,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-checked'], 2000, [RaftDecl('color', _v847)]),
    ],
  ),
  RaftUtility('data-checked:text-white', 1878, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-checked'], 2000, [RaftDecl('color', _v39)]),
  ]),
  RaftUtility('data-closed:hidden', 1890, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-closed'],
      2000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility(
    'data-disabled:[&>label]:cursor-not-allowed',
    3028,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > label',
        ['data-disabled'],
        2001,
        [RaftDecl('cursor', _v320)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:[&>label]:text-foreground-disabled',
    3029,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > label',
        ['data-disabled'],
        2001,
        [RaftDecl('color', _v754)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:[&>label_*]:text-foreground-disabled',
    3030,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > label *',
        ['data-disabled'],
        2001,
        [RaftDecl('color', _v754)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:active:scale-100',
    1910,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-disabled'],
        3000,
        [
          RaftDecl('--tw-scale-x', CssNum(100, '%')),
          RaftDecl('--tw-scale-y', CssNum(100, '%')),
          RaftDecl('--tw-scale-z', CssNum(100, '%')),
          RaftDecl('scale', _v277),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:bg-[oklch(0.88_0.004_106.42)]',
    1895,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [RaftDecl('background-color', _v848)],
      ),
    ],
  ),
  RaftUtility('data-disabled:bg-fill-muted', 1896, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-disabled'],
      2000,
      [RaftDecl('background-color', _v222)],
    ),
  ]),
  RaftUtility(
    'data-disabled:bg-layer-panel',
    1897,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility('data-disabled:bg-line', 1898, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-disabled'],
      2000,
      [RaftDecl('background-color', _v806)],
    ),
  ]),
  RaftUtility(
    'data-disabled:border-line-hairline',
    1894,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [
          RaftDecl('border-top-color', _v158),
          RaftDecl('border-right-color', _v158),
          RaftDecl('border-bottom-color', _v158),
          RaftDecl('border-left-color', _v158),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:cursor-not-allowed',
    1893,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-disabled'], 2000, [RaftDecl('cursor', _v320)]),
    ],
  ),
  RaftUtility(
    'data-disabled:hover:bg-fill-muted',
    1908,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled', 'hover'],
        3000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:hover:border-black/30',
    1907,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v557),
          RaftDecl('border-right-color', _v557),
          RaftDecl('border-bottom-color', _v557),
          RaftDecl('border-left-color', _v557),
        ],
      ),
      RaftLayer(
        'self',
        ['data-disabled', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v558),
          RaftDecl('border-right-color', _v558),
          RaftDecl('border-bottom-color', _v558),
          RaftDecl('border-left-color', _v558),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:hover:shadow-none',
    1909,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('data-disabled:opacity-40', 1902, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-disabled'],
      2000,
      [RaftDecl('opacity', CssNum(40, '%'))],
    ),
  ]),
  RaftUtility(
    'data-disabled:pointer-events-none',
    1891,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:shadow-[0_1px_1px_-1px_oklch(0_0_0/0.02),0_0_0_1px_var(--line-muted)]',
    1903,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v804, _v670])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:shadow-[inset_0_0_0_1px_var(--line-muted)]',
    1904,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [RaftDecl('--tw-shadow', _v805), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('data-disabled:shadow-none', 1905, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-disabled'],
      2000,
      [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'data-disabled:shadow-raft-sm',
    1906,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:text-foreground-disabled',
    1899,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-disabled'], 2000, [RaftDecl('color', _v754)]),
    ],
  ),
  RaftUtility(
    'data-disabled:text-foreground-strong/30',
    1900,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-disabled'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer('self', ['data-disabled'], 2000, [RaftDecl('color', _v756)]),
    ],
  ),
  RaftUtility('data-disabled:text-line', 1901, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-disabled'], 2000, [RaftDecl('color', _v806)]),
  ]),
  RaftUtility(
    'data-disabled:transform-none',
    1892,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [RaftDecl('transform', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:blur-(--drawer-blur)',
    1923,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [RaftDecl('--tw-blur', _v849), RaftDecl('filter', _v662)],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:data-[swipe-direction=down]:transform-[translateY(calc(var(--toast-swipe-movement-y)+120%))]',
    2339,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style', 'data-swipe-direction=down'],
        3000,
        [RaftDecl('transform', _v851)],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:data-[swipe-direction=left]:transform-[translateX(calc(var(--toast-swipe-movement-x)-120%))_translateY(var(--toast-y))]',
    2340,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style', 'data-swipe-direction=left'],
        3000,
        [
          RaftDecl('transform', CssSeq([_v854, _v855])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:data-[swipe-direction=right]:transform-[translateX(calc(var(--toast-swipe-movement-x)+120%))_translateY(var(--toast-y))]',
    2341,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style', 'data-swipe-direction=right'],
        3000,
        [
          RaftDecl('transform', CssSeq([_v857, _v855])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:data-[swipe-direction=up]:transform-[translateY(calc(var(--toast-swipe-movement-y)-120%))]',
    2342,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style', 'data-swipe-direction=up'],
        3000,
        [RaftDecl('transform', _v859)],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:duration-150',
    1924,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [
          RaftDecl('--tw-duration', CssNum(150, 'ms')),
          RaftDecl('transition-duration', CssNum(150, 'ms')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:duration-[calc(var(--drawer-swipe-strength,1)*180ms)]',
    1925,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [
          RaftDecl('--tw-duration', CssCalc(_v861)),
          RaftDecl('transition-duration', CssCalc(_v861)),
        ],
      ),
    ],
  ),
  RaftUtility('data-ending-style:hidden', 1918, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-ending-style'],
      2000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('data-ending-style:opacity-0', 1922, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-ending-style'],
      2000,
      [RaftDecl('opacity', CssNum(0, '%'))],
    ),
  ]),
  RaftUtility(
    'data-ending-style:pointer-events-none',
    1917,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:scale-[0.99]',
    1919,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [RaftDecl('scale', CssNum(0.99))],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:transform-(--closed-transform)',
    1920,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [RaftDecl('transform', _v862)],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:transform-[scale(0.99)]',
    1921,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [RaftDecl('transform', _v863)],
      ),
    ],
  ),
  RaftUtility(
    'data-expanded:bg-layer-hud/85',
    1928,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-expanded'],
        2000,
        [RaftDecl('background-color', _v485)],
      ),
      RaftLayer(
        'self',
        ['data-expanded'],
        2000,
        [RaftDecl('background-color', _v487)],
      ),
    ],
  ),
  RaftUtility(
    'data-expanded:h-(--toast-height)',
    1926,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-expanded'], 2000, [RaftDecl('height', _v236)]),
    ],
  ),
  RaftUtility(
    'data-expanded:shadow-[0_18px_40px_-18px_oklch(0_0_0/0.54)]',
    1929,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-expanded'],
        2000,
        [RaftDecl('--tw-shadow', _v866), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-expanded:transform-[translateX(var(--toast-swipe-movement-x))_translateY(var(--toast-y))_scale(1)]',
    1927,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-expanded'],
        2000,
        [RaftDecl('transform', _v869)],
      ),
    ],
  ),
  RaftUtility(
    'data-follows-system:mt-[5px]',
    1930,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-follows-system'],
        2000,
        [RaftDecl('margin-top', CssNum(5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-follows-system:pt-[12px]',
    1931,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-follows-system'],
        2000,
        [RaftDecl('padding-top', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-has-value:active:shadow-raft-sm',
    1937,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-has-value'],
        3000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('data-has-value:bg-primary', 1932, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-has-value'],
      2000,
      [RaftDecl('background-color', _v118)],
    ),
  ]),
  RaftUtility(
    'data-has-value:hover:bg-primary',
    1935,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-has-value', 'hover'],
        3000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'data-has-value:hover:shadow-raft-sm',
    1936,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-has-value', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-has-value:shadow-raft-sm',
    1934,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-has-value'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-has-value:text-foreground-strong',
    1933,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-has-value'], 2000, [RaftDecl('color', _v0)]),
    ],
  ),
  RaftUtility(
    'data-highlighted:[&>svg]:text-foreground',
    3098,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['data-highlighted'],
        2001,
        [RaftDecl('color', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'data-highlighted:bg-brutal-yellow/30',
    1938,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-highlighted'],
        2000,
        [RaftDecl('background-color', _v454)],
      ),
      RaftLayer(
        'self',
        ['data-highlighted'],
        2000,
        [RaftDecl('background-color', _v455)],
      ),
    ],
  ),
  RaftUtility('data-highlighted:bg-ink-10', 1940, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-highlighted'],
      2000,
      [RaftDecl('background-color', _v12)],
    ),
  ]),
  RaftUtility('data-highlighted:bg-ink-4', 1939, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-highlighted'],
      2000,
      [RaftDecl('background-color', _v390)],
    ),
  ]),
  RaftUtility(
    'data-highlighted:bg-primary/30',
    1941,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-highlighted'],
        2000,
        [RaftDecl('background-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['data-highlighted'],
        2000,
        [RaftDecl('background-color', _v616)],
      ),
    ],
  ),
  RaftUtility(
    'data-highlighted:text-foreground',
    1942,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-highlighted'], 2000, [RaftDecl('color', _v14)]),
    ],
  ),
  RaftUtility(
    'data-indeterminate:[--progress-track:color-mix(in_oklab,var(--line-muted)_65%,var(--layer-panel))]',
    1954,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('--progress-track', _v81)],
      ),
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('--progress-track', _v871)],
      ),
    ],
  ),
  RaftUtility('data-indeterminate:absolute', 1944, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-indeterminate'],
      2000,
      [RaftDecl('position', CssKeyword('absolute'))],
    ),
  ]),
  RaftUtility(
    'data-indeterminate:animate-[raft-progress-indeterminate_1.4s_ease-in-out_infinite]',
    1948,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('animation', _v874)],
      ),
    ],
  ),
  RaftUtility(
    'data-indeterminate:animate-[raft-progress-sweep_1.6s_ease-in-out_infinite]',
    1949,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('animation', _v876)],
      ),
    ],
  ),
  RaftUtility(
    'data-indeterminate:bg-[linear-gradient(90deg,transparent,var(--progress-sweep),transparent)]',
    1950,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('background-image', _v878)],
      ),
    ],
  ),
  RaftUtility(
    'data-indeterminate:data-disabled:shadow-[0_1px_1px_-1px_oklch(0_0_0/0.02),0_0_0_1px_var(--line-muted)]',
    1957,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled', 'data-indeterminate'],
        3000,
        [
          RaftDecl('--tw-shadow', CssList([_v804, _v670])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-indeterminate:origin-left',
    1947,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('transform-origin', CssNum(0))],
      ),
    ],
  ),
  RaftUtility(
    'data-indeterminate:shadow-[0_2px_2px_-1px_oklch(0_0_0/0.04),0_4px_4px_-2px_oklch(0_0_0/0.02)]',
    1951,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v828, _v829])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-indeterminate:shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.2),0_1px_1px_-0.5px_color-mix(in_srgb,var(--primary-glow)_10%,transparent),0_2px_2px_-1px_color-mix(in_srgb,var(--primary-glow)_6%,transparent),0_0_0_1px_var(--primary-edge)]',
    1952,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('--tw-shadow', _v837), RaftDecl('box-shadow', _v20)],
      ),
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('--tw-shadow', _v846)],
      ),
    ],
  ),
  RaftUtility(
    'data-indeterminate:shadow-none',
    1953,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('data-indeterminate:w-1/2', 1945, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-indeterminate'],
      2000,
      [RaftDecl('width', CssNum(50, '%'))],
    ),
  ]),
  RaftUtility('data-indeterminate:w-2/5', 1946, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-indeterminate'],
      2000,
      [RaftDecl('width', CssNum(40, '%'))],
    ),
  ]),
  RaftUtility(
    'data-instant:transition-none',
    1959,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-instant'],
        2000,
        [RaftDecl('transition-property', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:bg-brutal-red/5',
    1962,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid'],
        2000,
        [RaftDecl('background-color', _v880)],
      ),
      RaftLayer(
        'self',
        ['data-invalid'],
        2000,
        [RaftDecl('background-color', _v881)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:border-brutal-red',
    1960,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid'],
        2000,
        [
          RaftDecl('border-top-color', CssColor(0xFFF97264)),
          RaftDecl('border-right-color', CssColor(0xFFF97264)),
          RaftDecl('border-bottom-color', CssColor(0xFFF97264)),
          RaftDecl('border-left-color', CssColor(0xFFF97264)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:border-danger/45',
    1961,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid'],
        2000,
        [
          RaftDecl('border-top-color', _v137),
          RaftDecl('border-right-color', _v137),
          RaftDecl('border-bottom-color', _v137),
          RaftDecl('border-left-color', _v137),
        ],
      ),
      RaftLayer(
        'self',
        ['data-invalid'],
        2000,
        [
          RaftDecl('border-top-color', _v883),
          RaftDecl('border-right-color', _v883),
          RaftDecl('border-bottom-color', _v883),
          RaftDecl('border-left-color', _v883),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:disabled:border-line-muted/60',
    1972,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'disabled'],
        3000,
        [
          RaftDecl('border-top-color', _v81),
          RaftDecl('border-right-color', _v81),
          RaftDecl('border-bottom-color', _v81),
          RaftDecl('border-left-color', _v81),
        ],
      ),
      RaftLayer(
        'self',
        ['data-invalid', 'disabled'],
        3000,
        [
          RaftDecl('border-top-color', _v885),
          RaftDecl('border-right-color', _v885),
          RaftDecl('border-bottom-color', _v885),
          RaftDecl('border-left-color', _v885),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:disabled:ring-0',
    1973,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'disabled'],
        3000,
        [RaftDecl('--tw-ring-shadow', _v37), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:focus-visible:border-danger/75',
    1967,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [
          RaftDecl('border-top-color', _v137),
          RaftDecl('border-right-color', _v137),
          RaftDecl('border-bottom-color', _v137),
          RaftDecl('border-left-color', _v137),
        ],
      ),
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [
          RaftDecl('border-top-color', _v887),
          RaftDecl('border-right-color', _v887),
          RaftDecl('border-bottom-color', _v887),
          RaftDecl('border-left-color', _v887),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:focus-visible:ring-2',
    1968,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:focus-visible:ring-3',
    1969,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [RaftDecl('--tw-ring-shadow', _v889), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:focus-visible:ring-[color-mix(in_oklch,var(--danger)_60%,transparent)]',
    1970,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v137)],
      ),
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v891)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:focus-visible:ring-danger/12',
    1971,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v137)],
      ),
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v893)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:hover:border-danger/75',
    1966,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v137),
          RaftDecl('border-right-color', _v137),
          RaftDecl('border-bottom-color', _v137),
          RaftDecl('border-left-color', _v137),
        ],
      ),
      RaftLayer(
        'self',
        ['data-invalid', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v887),
          RaftDecl('border-right-color', _v887),
          RaftDecl('border-bottom-color', _v887),
          RaftDecl('border-left-color', _v887),
        ],
      ),
    ],
  ),
  RaftUtility('data-invalid:ring-2', 1964, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-invalid'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'data-invalid:ring-brutal-red/60',
    1965,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid'],
        2000,
        [RaftDecl('--tw-ring-color', _v895)],
      ),
      RaftLayer(
        'self',
        ['data-invalid'],
        2000,
        [RaftDecl('--tw-ring-color', _v896)],
      ),
    ],
  ),
  RaftUtility('data-invalid:shadow-none', 1963, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-invalid'],
      2000,
      [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('data-limited:opacity-0', 1984, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-limited'],
      2000,
      [RaftDecl('opacity', CssNum(0, '%'))],
    ),
  ]),
  RaftUtility('data-muted:text-black/30', 1987, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-muted'], 2000, [RaftDecl('color', _v557)]),
    RaftLayer('self', ['data-muted'], 2000, [RaftDecl('color', _v558)]),
  ]),
  RaftUtility('data-muted:text-black/45', 1988, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-muted'], 2000, [RaftDecl('color', _v135)]),
    RaftLayer('self', ['data-muted'], 2000, [RaftDecl('color', _v136)]),
  ]),
  RaftUtility(
    'data-muted:text-foreground-disabled',
    1989,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-muted'], 2000, [RaftDecl('color', _v754)]),
    ],
  ),
  RaftUtility(
    'data-nested-drawer-open:h-(--drawer-frontmost-height)',
    1990,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested-drawer-open'],
        2000,
        [RaftDecl('height', _v897)],
      ),
    ],
  ),
  RaftUtility(
    'data-nested-drawer-open:overflow-hidden',
    1991,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested-drawer-open'],
        2000,
        [
          RaftDecl('overflow-x', CssKeyword('hidden')),
          RaftDecl('overflow-y', CssKeyword('hidden')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-nested-drawer-swiping:duration-0',
    1992,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested-drawer-swiping'],
        2000,
        [
          RaftDecl('--tw-duration', CssNum(0, 'ms')),
          RaftDecl('transition-duration', CssNum(0, 'ms')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:-translate-y-px',
    2000,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [
          RaftDecl('--tw-translate-y', CssNum(-1, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:[&>svg]:text-foreground',
    3099,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['data-popup-open'],
        2001,
        [RaftDecl('color', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:bg-brutal-yellow/30',
    2005,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-color', _v454)],
      ),
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-color', _v455)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:bg-fill-muted',
    2006,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-color', _v222)],
      ),
    ],
  ),
  RaftUtility('data-popup-open:bg-ink-2', 2007, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-popup-open'],
      2000,
      [RaftDecl('background-color', _v147)],
    ),
  ]),
  RaftUtility('data-popup-open:bg-ink-4', 2008, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-popup-open'],
      2000,
      [RaftDecl('background-color', _v390)],
    ),
  ]),
  RaftUtility(
    'data-popup-open:bg-layer-panel',
    2009,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:bg-primary/30',
    2010,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-color', _v616)],
      ),
    ],
  ),
  RaftUtility('data-popup-open:bg-white', 2011, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-popup-open'],
      2000,
      [RaftDecl('background-color', _v39)],
    ),
  ]),
  RaftUtility(
    'data-popup-open:border-black',
    2002,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [
          RaftDecl('border-top-color', _v5),
          RaftDecl('border-right-color', _v5),
          RaftDecl('border-bottom-color', _v5),
          RaftDecl('border-left-color', _v5),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:border-line-strong',
    2003,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [
          RaftDecl('border-top-color', _v43),
          RaftDecl('border-right-color', _v43),
          RaftDecl('border-bottom-color', _v43),
          RaftDecl('border-left-color', _v43),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:border-transparent',
    2004,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [
          RaftDecl('border-top-color', _v7),
          RaftDecl('border-right-color', _v7),
          RaftDecl('border-bottom-color', _v7),
          RaftDecl('border-left-color', _v7),
        ],
      ),
    ],
  ),
  RaftUtility('data-popup-open:ring-1', 2019, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-popup-open'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v293), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'data-popup-open:ring-line-muted/30',
    2020,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('--tw-ring-color', _v81)],
      ),
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('--tw-ring-color', _v899)],
      ),
    ],
  ),
  RaftUtility('data-popup-open:shadow-none', 2015, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-popup-open'],
      2000,
      [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'data-popup-open:shadow-raft-md',
    2016,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('--tw-shadow', _v61), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:shadow-raft-sm',
    2017,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:shadow-raft-xs',
    2018,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('--tw-shadow', _v279), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('data-popup-open:text-black', 2012, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-popup-open'], 2000, [RaftDecl('color', _v5)]),
  ]),
  RaftUtility(
    'data-popup-open:text-foreground',
    2013,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-popup-open'], 2000, [RaftDecl('color', _v14)]),
    ],
  ),
  RaftUtility(
    'data-popup-open:text-foreground-strong',
    2014,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-popup-open'], 2000, [RaftDecl('color', _v0)]),
    ],
  ),
  RaftUtility(
    'data-popup-open:translate-x-0',
    1999,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [
          RaftDecl('--tw-translate-x', CssNum(0, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:translate-y-0',
    2001,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [
          RaftDecl('--tw-translate-y', CssNum(0, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:bg-accent-200/50',
    2021,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed'],
        2000,
        [RaftDecl('background-color', _v216)],
      ),
      RaftLayer(
        'self',
        ['data-pressed'],
        2000,
        [RaftDecl('background-color', _v901)],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:bg-brutal-orange',
    2022,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed'],
        2000,
        [RaftDecl('background-color', CssColor(0xFFF8A16F))],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:bg-brutal-pink/20',
    2023,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed'],
        2000,
        [RaftDecl('background-color', _v269)],
      ),
      RaftLayer(
        'self',
        ['data-pressed'],
        2000,
        [RaftDecl('background-color', _v270)],
      ),
    ],
  ),
  RaftUtility('data-pressed:bg-fill-strong', 2024, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-pressed'],
      2000,
      [RaftDecl('background-color', _v115)],
    ),
  ]),
  RaftUtility('data-pressed:bg-primary-400', 2025, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-pressed'],
      2000,
      [RaftDecl('background-color', _v118)],
    ),
  ]),
  RaftUtility(
    'data-pressed:hover:bg-accent-200/70',
    2032,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed', 'hover'],
        3000,
        [RaftDecl('background-color', _v216)],
      ),
      RaftLayer(
        'self',
        ['data-pressed', 'hover'],
        3000,
        [RaftDecl('background-color', _v903)],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:hover:bg-brutal-orange',
    2033,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed', 'hover'],
        3000,
        [RaftDecl('background-color', CssColor(0xFFF8A16F))],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:hover:bg-brutal-pink/30',
    2034,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed', 'hover'],
        3000,
        [RaftDecl('background-color', _v445)],
      ),
      RaftLayer(
        'self',
        ['data-pressed', 'hover'],
        3000,
        [RaftDecl('background-color', _v446)],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:hover:bg-fill-strong',
    2035,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed', 'hover'],
        3000,
        [RaftDecl('background-color', _v115)],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:hover:bg-primary-hover',
    2036,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed', 'hover'],
        3000,
        [RaftDecl('background-color', _v807)],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:shadow-[0_1px_1.5px_-1px_color-mix(in_srgb,var(--primary-glow)_8%,transparent),0_0_0_1px_var(--primary-edge)]',
    2030,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v810, _v813])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
      RaftLayer(
        'self',
        ['data-pressed'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v817, _v813])),
        ],
      ),
    ],
  ),
  RaftUtility('data-pressed:shadow-raft-sm', 2031, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-pressed'],
      2000,
      [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'data-pressed:text-accent-700',
    2026,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-pressed'], 2000, [RaftDecl('color', _v904)]),
    ],
  ),
  RaftUtility('data-pressed:text-black', 2027, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-pressed'], 2000, [RaftDecl('color', _v5)]),
  ]),
  RaftUtility(
    'data-pressed:text-foreground-strong',
    2028,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-pressed'], 2000, [RaftDecl('color', _v0)]),
    ],
  ),
  RaftUtility(
    'data-pressed:text-primary-950',
    2029,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-pressed'], 2000, [RaftDecl('color', _v847)]),
    ],
  ),
  RaftUtility('data-scrolling:duration-0', 2039, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-scrolling'],
      2000,
      [
        RaftDecl('--tw-duration', CssNum(0, 'ms')),
        RaftDecl('transition-duration', CssNum(0, 'ms')),
      ],
    ),
  ]),
  RaftUtility('data-scrolling:opacity-100', 2038, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-scrolling'],
      2000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility(
    'data-scrolling:pointer-events-auto',
    2037,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-scrolling'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility('data-selected:bg-ink-4', 2040, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-selected'],
      2000,
      [RaftDecl('background-color', _v390)],
    ),
  ]),
  RaftUtility(
    'data-selected:bg-layer-popover',
    2041,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected'],
        2000,
        [RaftDecl('background-color', _v493)],
      ),
    ],
  ),
  RaftUtility(
    'data-selected:hover:bg-primary/30',
    2043,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected', 'hover'],
        3000,
        [RaftDecl('background-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['data-selected', 'hover'],
        3000,
        [RaftDecl('background-color', _v616)],
      ),
    ],
  ),
  RaftUtility(
    'data-selected:text-foreground',
    2042,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-selected'], 2000, [RaftDecl('color', _v14)]),
    ],
  ),
  RaftUtility(
    'data-starting-style:blur-(--drawer-blur)',
    2050,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [RaftDecl('--tw-blur', _v849), RaftDecl('filter', _v662)],
      ),
    ],
  ),
  RaftUtility(
    'data-starting-style:opacity-0',
    2049,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [RaftDecl('opacity', CssNum(0, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-starting-style:scale-[.98]',
    2044,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [RaftDecl('scale', CssNum(0.98))],
      ),
    ],
  ),
  RaftUtility(
    'data-starting-style:scale-[0.97]',
    2045,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [RaftDecl('scale', CssNum(0.97))],
      ),
    ],
  ),
  RaftUtility(
    'data-starting-style:transform-(--closed-transform)',
    2046,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [RaftDecl('transform', _v862)],
      ),
    ],
  ),
  RaftUtility(
    'data-starting-style:transform-[scale(0.97)]',
    2047,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [RaftDecl('transform', _v905)],
      ),
    ],
  ),
  RaftUtility(
    'data-starting-style:transform-[translateY(120%)_scale(0.98)]',
    2048,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [
          RaftDecl('transform', CssSeq([_v139, _v140])),
        ],
      ),
    ],
  ),
  RaftUtility('data-swiping:duration-0', 2051, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-swiping'],
      2000,
      [
        RaftDecl('--tw-duration', CssNum(0, 'ms')),
        RaftDecl('transition-duration', CssNum(0, 'ms')),
      ],
    ),
  ]),
  RaftUtility(
    'data-unchecked:hover:bg-[color-mix(in_oklch,var(--fill-muted)_55%,var(--layer-panel))]',
    2052,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-unchecked', 'hover'],
        3000,
        [RaftDecl('background-color', _v222)],
      ),
      RaftLayer(
        'self',
        ['data-unchecked', 'hover'],
        3000,
        [RaftDecl('background-color', _v907)],
      ),
    ],
  ),
  RaftUtility('data-visible:opacity-100', 2054, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-visible'],
      2000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility(
    'data-visible:pointer-events-auto',
    2053,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-visible'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility('decoration-1', 951, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-decoration-thickness', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('decoration-2', 952, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-decoration-thickness', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility(
    'decoration-[oklch(0.81_0.19_88.08)]',
    948,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('text-decoration-color', _v908)]),
    ],
  ),
  RaftUtility('decoration-black/30', 949, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-decoration-color', _v557)]),
    RaftLayer('self', [], 1000, [RaftDecl('text-decoration-color', _v558)]),
  ]),
  RaftUtility('decoration-black/40', 950, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-decoration-color', _v56)]),
    RaftLayer('self', [], 1000, [RaftDecl('text-decoration-color', _v57)]),
  ]),
  RaftUtility('disabled:bg-fill-muted/50', 1606, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('background-color', _v222)],
    ),
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('background-color', _v464)],
    ),
  ]),
  RaftUtility(
    'disabled:border-line-muted/60',
    1605,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['disabled'],
        2000,
        [
          RaftDecl('border-top-color', _v81),
          RaftDecl('border-right-color', _v81),
          RaftDecl('border-bottom-color', _v81),
          RaftDecl('border-left-color', _v81),
        ],
      ),
      RaftLayer(
        'self',
        ['disabled'],
        2000,
        [
          RaftDecl('border-top-color', _v885),
          RaftDecl('border-right-color', _v885),
          RaftDecl('border-bottom-color', _v885),
          RaftDecl('border-left-color', _v885),
        ],
      ),
    ],
  ),
  RaftUtility('disabled:cursor-default', 1603, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('cursor', CssKeyword('default'))],
    ),
  ]),
  RaftUtility('disabled:cursor-not-allowed', 1604, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['disabled'], 2000, [RaftDecl('cursor', _v320)]),
  ]),
  RaftUtility(
    'disabled:hover:border-line-muted/60',
    1614,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['disabled', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v81),
          RaftDecl('border-right-color', _v81),
          RaftDecl('border-bottom-color', _v81),
          RaftDecl('border-left-color', _v81),
        ],
      ),
      RaftLayer(
        'self',
        ['disabled', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v885),
          RaftDecl('border-right-color', _v885),
          RaftDecl('border-bottom-color', _v885),
          RaftDecl('border-left-color', _v885),
        ],
      ),
    ],
  ),
  RaftUtility('disabled:opacity-40', 1608, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('opacity', CssNum(40, '%'))],
    ),
  ]),
  RaftUtility('disabled:opacity-45', 1609, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('opacity', CssNum(45, '%'))],
    ),
  ]),
  RaftUtility('disabled:opacity-60', 1610, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('opacity', CssNum(60, '%'))],
    ),
  ]),
  RaftUtility(
    'disabled:placeholder:text-foreground-disabled',
    1613,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::placeholder',
        ['disabled'],
        2001,
        [RaftDecl('color', _v754)],
      ),
    ],
  ),
  RaftUtility(
    'disabled:pointer-events-none',
    1601,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['disabled'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility('disabled:shadow-none', 1611, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('disabled:shadow-raft-sm', 1612, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'disabled:text-foreground-disabled',
    1607,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['disabled'], 2000, [RaftDecl('color', _v754)]),
    ],
  ),
  RaftUtility('disabled:transform-none', 1602, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('transform', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('divide-line-hairline', 408, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('border-top-color', _v158),
      RaftDecl('border-right-color', _v158),
      RaftDecl('border-bottom-color', _v158),
      RaftDecl('border-left-color', _v158),
    ]),
  ]),
  RaftUtility('divide-line-strong', 409, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('border-top-color', _v43),
      RaftDecl('border-right-color', _v43),
      RaftDecl('border-bottom-color', _v43),
      RaftDecl('border-left-color', _v43),
    ]),
  ]),
  RaftUtility('divide-y', 406, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-divide-y-reverse', CssNum(0)),
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-top-width', CssCalc(_v910)),
      RaftDecl('border-bottom-width', CssCalc(_v912)),
    ]),
  ]),
  RaftUtility('divide-y-2', 407, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-divide-y-reverse', CssNum(0)),
      RaftDecl('border-bottom-style', _v31),
      RaftDecl('border-top-style', _v31),
      RaftDecl('border-top-width', CssCalc(_v913)),
      RaftDecl('border-bottom-width', CssCalc(_v914)),
    ]),
  ]),
  RaftUtility(
    'drop-shadow-[0_0_1px_oklch(0.87_0.16_92/0.82)]',
    1017,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-drop-shadow-size', _v918),
        RaftDecl('--tw-drop-shadow', _v652),
        RaftDecl('filter', _v662),
      ]),
    ],
  ),
  RaftUtility(
    'drop-shadow-[0_0_1px_oklch(88.3%_0.162_91.9/0.82)]',
    1018,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-drop-shadow-size', _v922),
        RaftDecl('--tw-drop-shadow', _v652),
        RaftDecl('filter', _v662),
      ]),
    ],
  ),
  RaftUtility('duration-100', 1051, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(100, 'ms')),
      RaftDecl('transition-duration', CssNum(100, 'ms')),
    ]),
  ]),
  RaftUtility('duration-150', 1052, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(150, 'ms')),
      RaftDecl('transition-duration', CssNum(150, 'ms')),
    ]),
  ]),
  RaftUtility('duration-160', 1053, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(160, 'ms')),
      RaftDecl('transition-duration', CssNum(160, 'ms')),
    ]),
  ]),
  RaftUtility('duration-180', 1054, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(180, 'ms')),
      RaftDecl('transition-duration', CssNum(180, 'ms')),
    ]),
  ]),
  RaftUtility('duration-200', 1055, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(200, 'ms')),
      RaftDecl('transition-duration', CssNum(200, 'ms')),
    ]),
  ]),
  RaftUtility('duration-220', 1056, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(220, 'ms')),
      RaftDecl('transition-duration', CssNum(220, 'ms')),
    ]),
  ]),
  RaftUtility('duration-240', 1057, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(240, 'ms')),
      RaftDecl('transition-duration', CssNum(240, 'ms')),
    ]),
  ]),
  RaftUtility('duration-250', 1058, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(250, 'ms')),
      RaftDecl('transition-duration', CssNum(250, 'ms')),
    ]),
  ]),
  RaftUtility('duration-300', 1059, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(300, 'ms')),
      RaftDecl('transition-duration', CssNum(300, 'ms')),
    ]),
  ]),
  RaftUtility('ease-(--drawer-ease)', 1060, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ease', CssVar('--drawer-ease')),
      RaftDecl('transition-timing-function', CssVar('--drawer-ease')),
    ]),
  ]),
  RaftUtility(
    'ease-[cubic-bezier(0.22,1,0.36,1)]',
    1061,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-ease', _v923),
        RaftDecl('transition-timing-function', _v923),
      ]),
    ],
  ),
  RaftUtility(
    'ease-[cubic-bezier(0.65,0,0.35,1)]',
    1062,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-ease', _v924),
        RaftDecl('transition-timing-function', _v924),
      ]),
    ],
  ),
  RaftUtility('ease-out', 1063, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ease', _v146),
      RaftDecl('transition-timing-function', _v146),
    ]),
  ]),
  RaftUtility('ease-slide', 1064, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ease', _v164),
      RaftDecl('transition-timing-function', _v164),
    ]),
  ]),
  RaftUtility('enabled:hover:brightness-90', 1599, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['enabled', 'hover'],
      3000,
      [RaftDecl('--tw-brightness', _v925), RaftDecl('filter', _v662)],
    ),
  ]),
  RaftUtility(
    'enabled:hover:brightness-[0.96]',
    1600,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['enabled', 'hover'],
        3000,
        [RaftDecl('--tw-brightness', _v926), RaftDecl('filter', _v662)],
      ),
    ],
  ),
  RaftUtility('field-sizing-content', 142, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('field-sizing', CssKeyword('content')),
    ]),
  ]),
  RaftUtility('fill-layer-panel', 646, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('fill', _v38)]),
  ]),
  RaftUtility('fixed', 7, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('position', CssKeyword('fixed'))]),
  ]),
  RaftUtility('flex', 135, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('flex'))]),
  ]),
  RaftUtility('flex-1', 301, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex', CssNum(1))]),
  ]),
  RaftUtility('flex-col', 361, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('flex-direction', CssKeyword('column')),
    ]),
  ]),
  RaftUtility('flex-none', 302, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex', CssKeyword('none'))]),
  ]),
  RaftUtility('flex-nowrap', 363, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-wrap', CssKeyword('nowrap'))]),
  ]),
  RaftUtility('flex-row', 362, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('flex-direction', CssKeyword('row')),
    ]),
  ]),
  RaftUtility('flex-wrap', 364, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-wrap', CssKeyword('wrap'))]),
  ]),
  RaftUtility(
    'focus-visible:-outline-offset-1',
    1549,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('outline-offset', CssNum(-1, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:-outline-offset-2',
    1550,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('outline-offset', CssNum(-2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:before:bg-black/20',
    1563,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v418),
        ],
      ),
      RaftLayer(
        '::before',
        ['focus-visible'],
        2001,
        [RaftDecl('background-color', _v419)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:before:bg-ink-20',
    1564,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v375),
        ],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:before:outline-2',
    1565,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('outline-style', _v69),
          RaftDecl('outline-width', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:before:outline-foreground-strong',
    1567,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('outline-color', _v0),
        ],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:before:outline-offset-2',
    1566,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('outline-offset', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('focus-visible:bg-black/5', 1525, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('background-color', _v427)],
    ),
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('background-color', _v428)],
    ),
  ]),
  RaftUtility('focus-visible:bg-fill-muted', 1526, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('background-color', _v222)],
    ),
  ]),
  RaftUtility('focus-visible:bg-primary/30', 1527, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('background-color', _v118)],
    ),
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('background-color', _v616)],
    ),
  ]),
  RaftUtility('focus-visible:outline', 1546, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [
        RaftDecl('outline-style', _v69),
        RaftDecl('outline-width', CssNum(1, 'px')),
      ],
    ),
  ]),
  RaftUtility('focus-visible:outline-1', 1547, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [
        RaftDecl('outline-style', _v69),
        RaftDecl('outline-width', CssNum(1, 'px')),
      ],
    ),
  ]),
  RaftUtility('focus-visible:outline-2', 1548, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [
        RaftDecl('outline-style', _v69),
        RaftDecl('outline-width', CssNum(2, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'focus-visible:outline-[black]',
    1553,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('outline-color', _v245)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:outline-[oklch(0.507_0.185_257.731)]',
    1554,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('outline-color', _v927)],
      ),
    ],
  ),
  RaftUtility('focus-visible:outline-black', 1555, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('outline-color', _v5)],
    ),
  ]),
  RaftUtility(
    'focus-visible:outline-foreground',
    1556,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('outline-color', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:outline-line-strong',
    1557,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('outline-color', _v43)],
      ),
    ],
  ),
  RaftUtility('focus-visible:outline-none', 1560, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [
        RaftDecl('--tw-outline-style', CssKeyword('none')),
        RaftDecl('outline-style', CssKeyword('none')),
      ],
    ),
  ]),
  RaftUtility(
    'focus-visible:outline-offset-1',
    1551,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('outline-offset', CssNum(1, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:outline-offset-2',
    1552,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('outline-offset', CssNum(2, 'px'))],
      ),
    ],
  ),
  RaftUtility('focus-visible:outline-solid', 1561, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [
        RaftDecl('--tw-outline-style', CssKeyword('solid')),
        RaftDecl('outline-style', CssKeyword('solid')),
      ],
    ),
  ]),
  RaftUtility(
    'focus-visible:outline-transparent',
    1558,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('outline-color', _v7)],
      ),
    ],
  ),
  RaftUtility('focus-visible:outline-white', 1559, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('outline-color', _v39)],
    ),
  ]),
  RaftUtility('focus-visible:ring-0', 1530, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v37), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('focus-visible:ring-1', 1531, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v293), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('focus-visible:ring-2', 1532, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('focus-visible:ring-[0.5px]', 1533, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v666), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'focus-visible:ring-[color-mix(in_oklch,var(--button-focus-ring,var(--primary-400))_80%,transparent)]',
    1534,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v928)],
      ),
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v930)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:ring-[color-mix(in_oklch,var(--primary-400)_85%,transparent)]',
    1535,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v932)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:ring-foreground-inverse/60',
    1536,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v227)],
      ),
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v934)],
      ),
    ],
  ),
  RaftUtility('focus-visible:ring-inset', 1562, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('--tw-ring-inset', CssKeyword('inset'))],
    ),
  ]),
  RaftUtility(
    'focus-visible:ring-line-strong',
    1537,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v43)],
      ),
    ],
  ),
  RaftUtility('focus-visible:ring-offset-0', 1541, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [
        RaftDecl('--tw-ring-offset-width', CssNum(0, 'px')),
        RaftDecl('--tw-ring-offset-shadow', _v664),
      ],
    ),
  ]),
  RaftUtility('focus-visible:ring-offset-1', 1542, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [
        RaftDecl('--tw-ring-offset-width', CssNum(1, 'px')),
        RaftDecl('--tw-ring-offset-shadow', _v664),
      ],
    ),
  ]),
  RaftUtility('focus-visible:ring-offset-2', 1543, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [
        RaftDecl('--tw-ring-offset-width', CssNum(2, 'px')),
        RaftDecl('--tw-ring-offset-shadow', _v664),
      ],
    ),
  ]),
  RaftUtility(
    'focus-visible:ring-offset-layer-canvas-muted',
    1544,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-offset-color', _v68)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:ring-offset-layer-panel',
    1545,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-offset-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:ring-primary-400',
    1538,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:ring-primary-400/80',
    1539,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v502)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:ring-primary-500',
    1540,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v574)],
      ),
    ],
  ),
  RaftUtility('focus-visible:text-black', 1528, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['focus-visible'], 2000, [RaftDecl('color', _v5)]),
  ]),
  RaftUtility(
    'focus-visible:text-foreground',
    1529,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['focus-visible'], 2000, [RaftDecl('color', _v14)]),
    ],
  ),
  RaftUtility(
    'focus-within:[--mi-toolbar-opacity:1]',
    1404,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-within'],
        2000,
        [RaftDecl('--mi-toolbar-opacity', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'focus-within:[--mi-toolbar-pe:auto]',
    1405,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-within'],
        2000,
        [RaftDecl('--mi-toolbar-pe', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility('focus-within:ring-1', 1402, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-within'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v293), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'focus-within:ring-primary-400',
    1403,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-within'],
        2000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
    ],
  ),
  RaftUtility('focus-within:shadow-raft-md', 1401, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-within'],
      2000,
      [RaftDecl('--tw-shadow', _v61), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('focus:bg-layer-panel', 1521, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['focus'], 2000, [RaftDecl('background-color', _v38)]),
  ]),
  RaftUtility('focus:border-transparent', 1520, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus'],
      2000,
      [
        RaftDecl('border-top-color', _v7),
        RaftDecl('border-right-color', _v7),
        RaftDecl('border-bottom-color', _v7),
        RaftDecl('border-left-color', _v7),
      ],
    ),
  ]),
  RaftUtility('focus:flex', 1519, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus'],
      2000,
      [RaftDecl('display', CssKeyword('flex'))],
    ),
  ]),
  RaftUtility('focus:outline-none', 1524, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus'],
      2000,
      [
        RaftDecl('--tw-outline-style', CssKeyword('none')),
        RaftDecl('outline-style', CssKeyword('none')),
      ],
    ),
  ]),
  RaftUtility('focus:ring-0', 1523, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v37), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('focus:shadow-raft-md', 1522, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus'],
      2000,
      [RaftDecl('--tw-shadow', _v61), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('font-[420]', 815, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(420)),
      RaftDecl('font-weight', CssNum(420)),
    ]),
  ]),
  RaftUtility('font-[450]', 816, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(450)),
      RaftDecl('font-weight', CssNum(450)),
    ]),
  ]),
  RaftUtility('font-[550]', 817, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(550)),
      RaftDecl('font-weight', CssNum(550)),
    ]),
  ]),
  RaftUtility('font-black', 818, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(900)),
      RaftDecl('font-weight', CssNum(900)),
    ]),
  ]),
  RaftUtility('font-bold', 819, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(700)),
      RaftDecl('font-weight', CssNum(700)),
    ]),
  ]),
  RaftUtility('font-card-title', 820, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', _v935),
      RaftDecl('font-weight', _v935),
    ]),
  ]),
  RaftUtility('font-field', 821, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', _v10),
      RaftDecl('font-weight', _v10),
    ]),
  ]),
  RaftUtility('font-heading', 762, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-family', _v936)]),
  ]),
  RaftUtility('font-medium', 822, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(500)),
      RaftDecl('font-weight', CssNum(500)),
    ]),
  ]),
  RaftUtility('font-mono', 763, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-family', _v3)]),
  ]),
  RaftUtility('font-normal', 823, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(400)),
      RaftDecl('font-weight', CssNum(400)),
    ]),
  ]),
  RaftUtility('font-sans', 764, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-family', _v54)]),
  ]),
  RaftUtility('font-semibold', 824, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(600)),
      RaftDecl('font-weight', CssNum(600)),
    ]),
  ]),
  RaftUtility(
    'forced-colors:focus-visible:outline-[CanvasText]',
    2757,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'forced-colors'],
        2000,
        [RaftDecl('outline-color', _v937)],
      ),
    ],
  ),
  RaftUtility('gap-0', 374, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(0, 'px')),
      RaftDecl('column-gap', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('gap-0.5', 375, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(2, 'px')),
      RaftDecl('column-gap', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('gap-1', 376, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(4, 'px')),
      RaftDecl('column-gap', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('gap-1.5', 377, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(6, 'px')),
      RaftDecl('column-gap', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('gap-2', 378, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(8, 'px')),
      RaftDecl('column-gap', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('gap-2.5', 379, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(10, 'px')),
      RaftDecl('column-gap', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('gap-3', 380, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(12, 'px')),
      RaftDecl('column-gap', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('gap-4', 381, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(16, 'px')),
      RaftDecl('column-gap', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('gap-[2.5px]', 382, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(2.5, 'px')),
      RaftDecl('column-gap', CssNum(2.5, 'px')),
    ]),
  ]),
  RaftUtility('gap-[5.5px]', 383, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(5.5, 'px')),
      RaftDecl('column-gap', CssNum(5.5, 'px')),
    ]),
  ]),
  RaftUtility('gap-[5px]', 384, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(5, 'px')),
      RaftDecl('column-gap', CssNum(5, 'px')),
    ]),
  ]),
  RaftUtility('gap-[inherit]', 385, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssKeyword('inherit')),
      RaftDecl('column-gap', CssKeyword('inherit')),
    ]),
  ]),
  RaftUtility('gap-x-1.5', 393, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(6, 'px'))]),
  ]),
  RaftUtility('gap-x-2', 394, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(8, 'px'))]),
  ]),
  RaftUtility('gap-x-3', 395, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(12, 'px'))]),
  ]),
  RaftUtility('gap-x-3.5', 396, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(14, 'px'))]),
  ]),
  RaftUtility('gap-x-4', 397, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(16, 'px'))]),
  ]),
  RaftUtility('gap-x-6', 398, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(24, 'px'))]),
  ]),
  RaftUtility('gap-y-0', 401, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('row-gap', CssNum(0, 'px'))]),
  ]),
  RaftUtility('gap-y-0.5', 402, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('row-gap', CssNum(2, 'px'))]),
  ]),
  RaftUtility('gap-y-1', 403, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('row-gap', CssNum(4, 'px'))]),
  ]),
  RaftUtility('gap-y-1.5', 404, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('row-gap', CssNum(6, 'px'))]),
  ]),
  RaftUtility('gap-y-2', 405, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('row-gap', CssNum(8, 'px'))]),
  ]),
  RaftUtility('grid', 136, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('grid'))]),
  ]),
  RaftUtility('grid-cols-1', 354, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v938)]),
  ]),
  RaftUtility('grid-cols-2', 355, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v939)]),
  ]),
  RaftUtility(
    'grid-cols-[max-content_minmax(0,1fr)]',
    356,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('grid-template-columns', CssSeq([_v940, _v106])),
      ]),
    ],
  ),
  RaftUtility('grid-cols-[minmax(0,1fr)]', 357, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v106)]),
  ]),
  RaftUtility(
    'grid-cols-[minmax(0,1fr)_auto]',
    358,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v941)]),
    ],
  ),
  RaftUtility(
    'grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)]',
    359,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v942)]),
    ],
  ),
  RaftUtility(
    'grid-cols-[minmax(0,1fr)_max-content]',
    360,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('grid-template-columns', CssSeq([_v106, _v940])),
      ]),
    ],
  ),
  RaftUtility('grid-flow-col', 350, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('grid-auto-flow', CssKeyword('column')),
    ]),
  ]),
  RaftUtility('group', -1, RaftUtilityStatus.marker, []),
  RaftUtility(
    'group-data-[compact=true]/message:mb-0',
    1240,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/message:data-compact=true'],
        2000,
        [RaftDecl('margin-bottom', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[compact=true]/message:mt-0',
    1239,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/message:data-compact=true'],
        2000,
        [RaftDecl('margin-top', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[dragging=true]/task-draggable:shadow-raft-sm',
    1242,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/task-draggable:data-dragging=true'],
        2000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[dragging=true]/task-draggable:transform-none',
    1241,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/task-draggable:data-dragging=true'],
        2000,
        [RaftDecl('transform', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[drop-over=true]/task-draggable:hover:bg-layer-panel',
    1516,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/task-draggable:data-drop-over=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[drop-state=allowed]:block',
    1243,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-drop-state=allowed'],
        2000,
        [RaftDecl('display', CssKeyword('block'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[drop-state=allowed]:border-line-strong',
    1245,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-drop-state=allowed'],
        2000,
        [
          RaftDecl('border-top-color', _v43),
          RaftDecl('border-right-color', _v43),
          RaftDecl('border-bottom-color', _v43),
          RaftDecl('border-left-color', _v43),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[drop-state=allowed]:hidden',
    1244,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-drop-state=allowed'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[drop-state=allowed]:text-foreground-strong/60',
    1246,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-drop-state=allowed'],
        2000,
        [RaftDecl('color', _v0)],
      ),
      RaftLayer(
        'self',
        ['group:data-drop-state=allowed'],
        2000,
        [RaftDecl('color', _v944)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[drop-state=blocked]:block',
    1247,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-drop-state=blocked'],
        2000,
        [RaftDecl('display', CssKeyword('block'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[drop-state=blocked]:border-danger',
    1249,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-drop-state=blocked'],
        2000,
        [
          RaftDecl('border-top-color', _v137),
          RaftDecl('border-right-color', _v137),
          RaftDecl('border-bottom-color', _v137),
          RaftDecl('border-left-color', _v137),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[drop-state=blocked]:border-danger/40',
    1250,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-drop-state=blocked'],
        2000,
        [
          RaftDecl('border-top-color', _v137),
          RaftDecl('border-right-color', _v137),
          RaftDecl('border-bottom-color', _v137),
          RaftDecl('border-left-color', _v137),
        ],
      ),
      RaftLayer(
        'self',
        ['group:data-drop-state=blocked'],
        2000,
        [
          RaftDecl('border-top-color', _v946),
          RaftDecl('border-right-color', _v946),
          RaftDecl('border-bottom-color', _v946),
          RaftDecl('border-left-color', _v946),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[drop-state=blocked]:hidden',
    1248,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-drop-state=blocked'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[drop-state=blocked]:text-danger-strong',
    1251,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-drop-state=blocked'],
        2000,
        [RaftDecl('color', _v746)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[edge=inset]/panel-frame:md:ml-2',
    2510,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/panel-frame:data-edge=inset', 'width>=768'],
        2000,
        [RaftDecl('margin-left', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[edge=inset]/panel-frame:md:rounded-tl-[10px]',
    2511,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/panel-frame:data-edge=inset', 'width>=768'],
        2000,
        [RaftDecl('border-top-left-radius', CssNum(10, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[edge=inset]/panel-frame:md:shadow-raft-xl',
    2512,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/panel-frame:data-edge=inset', 'width>=768'],
        2000,
        [RaftDecl('--tw-shadow', _v646), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[invalid]/field:font-bold',
    1252,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/field:data-invalid'],
        2000,
        [
          RaftDecl('--tw-font-weight', CssNum(700)),
          RaftDecl('font-weight', CssNum(700)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[invalid]/field:font-medium',
    1253,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/field:data-invalid'],
        2000,
        [
          RaftDecl('--tw-font-weight', CssNum(500)),
          RaftDecl('font-weight', CssNum(500)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[nested=true]/search-message:bg-transparent',
    1257,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/search-message:data-nested=true'],
        2000,
        [RaftDecl('background-color', _v7)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[nested=true]/search-message:border-0',
    1256,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/search-message:data-nested=true'],
        2000,
        [
          RaftDecl('border-top-style', _v31),
          RaftDecl('border-right-style', _v31),
          RaftDecl('border-bottom-style', _v31),
          RaftDecl('border-left-style', _v31),
          RaftDecl('border-top-width', CssNum(0, 'px')),
          RaftDecl('border-right-width', CssNum(0, 'px')),
          RaftDecl('border-bottom-width', CssNum(0, 'px')),
          RaftDecl('border-left-width', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[nested=true]/search-message:group-hover/search-message:bg-transparent',
    1259,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/search-message:data-nested=true', 'group/search-message:hover'],
        3000,
        [RaftDecl('background-color', _v7)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[nested=true]/search-message:mb-1',
    1254,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/search-message:data-nested=true'],
        2000,
        [RaftDecl('margin-bottom', CssNum(4, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[nested=true]/search-message:p-0',
    1258,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/search-message:data-nested=true'],
        2000,
        [
          RaftDecl('padding-top', CssNum(0, 'px')),
          RaftDecl('padding-right', CssNum(0, 'px')),
          RaftDecl('padding-bottom', CssNum(0, 'px')),
          RaftDecl('padding-left', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[nested=true]/search-message:rounded-none',
    1255,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/search-message:data-nested=true'],
        2000,
        [
          RaftDecl('border-top-left-radius', CssNum(0)),
          RaftDecl('border-top-right-radius', CssNum(0)),
          RaftDecl('border-bottom-right-radius', CssNum(0)),
          RaftDecl('border-bottom-left-radius', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[orientation=horizontal]/scroll-area-scrollbar:h-1.5',
    1260,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/scroll-area-scrollbar:data-orientation=horizontal'],
        2000,
        [RaftDecl('height', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[orientation=vertical]/scroll-area-scrollbar:w-1.5',
    1261,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/scroll-area-scrollbar:data-orientation=vertical'],
        2000,
        [RaftDecl('width', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:[&>svg]:size-2.5',
    3071,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=2xs'],
        2001,
        [
          RaftDecl('width', CssNum(10, 'px')),
          RaftDecl('height', CssNum(10, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:bottom-0',
    1263,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [RaftDecl('bottom', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:outline',
    1267,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [
          RaftDecl('outline-style', _v69),
          RaftDecl('outline-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:right-0',
    1262,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [RaftDecl('right', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:size-1.5',
    1264,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [
          RaftDecl('width', CssNum(6, 'px')),
          RaftDecl('height', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:text-[10px]',
    1266,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [RaftDecl('font-size', CssNum(10, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:translate-[2.875px]',
    1265,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [
          RaftDecl('--tw-translate-x', CssNum(2.875, 'px')),
          RaftDecl('--tw-translate-y', CssNum(2.875, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:[&>svg]:size-2.5',
    3072,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=3xs'],
        2001,
        [
          RaftDecl('width', CssNum(10, 'px')),
          RaftDecl('height', CssNum(10, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:bottom-[-0.667px]',
    1269,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=3xs'],
        2000,
        [RaftDecl('bottom', CssNum(-0.667, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:outline',
    1273,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=3xs'],
        2000,
        [
          RaftDecl('outline-style', _v69),
          RaftDecl('outline-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:right-[-0.667px]',
    1268,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=3xs'],
        2000,
        [RaftDecl('right', CssNum(-0.667, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:size-1.5',
    1270,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=3xs'],
        2000,
        [
          RaftDecl('width', CssNum(6, 'px')),
          RaftDecl('height', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:text-[10px]',
    1272,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=3xs'],
        2000,
        [RaftDecl('font-size', CssNum(10, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:translate-[3.125px]',
    1271,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=3xs'],
        2000,
        [
          RaftDecl('--tw-translate-x', CssNum(3.125, 'px')),
          RaftDecl('--tw-translate-y', CssNum(3.125, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/avatar:[&>svg]:block',
    3073,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=lg'],
        2001,
        [RaftDecl('display', CssKeyword('block'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/avatar:[&>svg]:size-2',
    3074,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=lg'],
        2001,
        [
          RaftDecl('width', CssNum(8, 'px')),
          RaftDecl('height', CssNum(8, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/avatar:[&>svg]:size-6',
    3075,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=lg'],
        2001,
        [
          RaftDecl('width', CssNum(24, 'px')),
          RaftDecl('height', CssNum(24, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/avatar:bottom-0.5',
    1275,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=lg'],
        2000,
        [RaftDecl('bottom', CssNum(2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/avatar:right-0.5',
    1274,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=lg'],
        2000,
        [RaftDecl('right', CssNum(2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/avatar:size-3',
    1276,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=lg'],
        2000,
        [
          RaftDecl('width', CssNum(12, 'px')),
          RaftDecl('height', CssNum(12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/avatar:translate-[calc(25%+2px)]',
    1277,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=lg'],
        2000,
        [
          RaftDecl('--tw-translate-x', CssCalc(_v947)),
          RaftDecl('--tw-translate-y', CssCalc(_v947)),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/banner:[&>button:has(svg):last-child]:min-h-6',
    3016,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > button:has(svg):last-child',
        ['group/banner:data-size=lg'],
        3002,
        [RaftDecl('min-height', CssNum(24, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/banner:[&>button:has(svg):last-child]:min-w-6',
    3017,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > button:has(svg):last-child',
        ['group/banner:data-size=lg'],
        3002,
        [RaftDecl('min-width', CssNum(24, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/banner:[&>button:has(svg):last-child]:size-6',
    3015,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > button:has(svg):last-child',
        ['group/banner:data-size=lg'],
        3002,
        [
          RaftDecl('width', CssNum(24, 'px')),
          RaftDecl('height', CssNum(24, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/banner:leading-5',
    1281,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/banner:data-size=lg'],
        2000,
        [
          RaftDecl('--tw-leading', CssNum(20, 'px')),
          RaftDecl('line-height', CssNum(20, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/banner:leading-6',
    1282,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/banner:data-size=lg'],
        2000,
        [
          RaftDecl('--tw-leading', CssNum(24, 'px')),
          RaftDecl('line-height', CssNum(24, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/banner:min-h-6',
    1278,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/banner:data-size=lg'],
        2000,
        [RaftDecl('min-height', CssNum(24, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/banner:text-[14.5px]',
    1280,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/banner:data-size=lg'],
        2000,
        [RaftDecl('font-size', CssNum(14.5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/banner:text-sm',
    1279,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/banner:data-size=lg'],
        2000,
        [
          RaftDecl('font-size', CssNum(14, 'px')),
          RaftDecl('line-height', _v949),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/progress:h-2.5',
    1283,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/progress:data-size=lg'],
        2000,
        [RaftDecl('height', CssNum(10, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/progress:h-5',
    1284,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/progress:data-size=lg'],
        2000,
        [RaftDecl('height', CssNum(20, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=md]/avatar:[&>svg]:block',
    3076,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=md'],
        2001,
        [RaftDecl('display', CssKeyword('block'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=md]/avatar:[&>svg]:size-1.5',
    3077,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=md'],
        2001,
        [
          RaftDecl('width', CssNum(6, 'px')),
          RaftDecl('height', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=md]/avatar:[&>svg]:size-4.5',
    3078,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=md'],
        2001,
        [
          RaftDecl('width', CssNum(18, 'px')),
          RaftDecl('height', CssNum(18, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=md]/avatar:bottom-px',
    1286,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=md'],
        2000,
        [RaftDecl('bottom', CssNum(1, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=md]/avatar:right-px',
    1285,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=md'],
        2000,
        [RaftDecl('right', CssNum(1, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=md]/avatar:size-2.5',
    1287,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=md'],
        2000,
        [
          RaftDecl('width', CssNum(10, 'px')),
          RaftDecl('height', CssNum(10, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=md]/avatar:translate-[4.75px]',
    1288,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=md'],
        2000,
        [
          RaftDecl('--tw-translate-x', CssNum(4.75, 'px')),
          RaftDecl('--tw-translate-y', CssNum(4.75, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/avatar:[&>svg]:size-4',
    3079,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=sm'],
        2001,
        [
          RaftDecl('width', CssNum(16, 'px')),
          RaftDecl('height', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/avatar:bottom-[1.333px]',
    1290,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=sm'],
        2000,
        [RaftDecl('bottom', CssNum(1.333, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/avatar:right-[1.333px]',
    1289,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=sm'],
        2000,
        [RaftDecl('right', CssNum(1.333, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/avatar:size-2',
    1291,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=sm'],
        2000,
        [
          RaftDecl('width', CssNum(8, 'px')),
          RaftDecl('height', CssNum(8, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/avatar:translate-x-1',
    1292,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=sm'],
        2000,
        [
          RaftDecl('--tw-translate-x', CssNum(4, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/avatar:translate-y-1',
    1293,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=sm'],
        2000,
        [
          RaftDecl('--tw-translate-y', CssNum(4, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/banner:[&>button:has(svg):last-child>svg]:size-3',
    3026,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > button:has(svg):last-child > svg',
        ['group/banner:data-size=sm'],
        3003,
        [
          RaftDecl('width', CssNum(12, 'px')),
          RaftDecl('height', CssNum(12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/banner:[&>button:has(svg):last-child]:min-h-4',
    3019,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > button:has(svg):last-child',
        ['group/banner:data-size=sm'],
        3002,
        [RaftDecl('min-height', CssNum(16, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/banner:[&>button:has(svg):last-child]:min-w-4',
    3020,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > button:has(svg):last-child',
        ['group/banner:data-size=sm'],
        3002,
        [RaftDecl('min-width', CssNum(16, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/banner:[&>button:has(svg):last-child]:size-4',
    3018,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > button:has(svg):last-child',
        ['group/banner:data-size=sm'],
        3002,
        [
          RaftDecl('width', CssNum(16, 'px')),
          RaftDecl('height', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/banner:leading-4',
    1297,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/banner:data-size=sm'],
        2000,
        [
          RaftDecl('--tw-leading', CssNum(16, 'px')),
          RaftDecl('line-height', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/banner:min-h-4',
    1294,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/banner:data-size=sm'],
        2000,
        [RaftDecl('min-height', CssNum(16, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/banner:text-[13px]',
    1296,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/banner:data-size=sm'],
        2000,
        [RaftDecl('font-size', CssNum(13, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/banner:text-xs',
    1295,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/banner:data-size=sm'],
        2000,
        [
          RaftDecl('font-size', CssNum(12, 'px')),
          RaftDecl('line-height', _v143),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/progress:h-1.5',
    1298,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/progress:data-size=sm'],
        2000,
        [RaftDecl('height', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/progress:h-3',
    1299,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/progress:data-size=sm'],
        2000,
        [RaftDecl('height', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xl]/avatar:[&>svg]:block',
    3080,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=xl'],
        2001,
        [RaftDecl('display', CssKeyword('block'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xl]/avatar:[&>svg]:size-2',
    3081,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=xl'],
        2001,
        [
          RaftDecl('width', CssNum(8, 'px')),
          RaftDecl('height', CssNum(8, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xl]/avatar:[&>svg]:size-6',
    3082,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=xl'],
        2001,
        [
          RaftDecl('width', CssNum(24, 'px')),
          RaftDecl('height', CssNum(24, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xl]/avatar:bottom-[3.667px]',
    1301,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xl'],
        2000,
        [RaftDecl('bottom', CssNum(3.667, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xl]/avatar:right-[3.667px]',
    1300,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xl'],
        2000,
        [RaftDecl('right', CssNum(3.667, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xl]/avatar:size-3.5',
    1302,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xl'],
        2000,
        [
          RaftDecl('width', CssNum(14, 'px')),
          RaftDecl('height', CssNum(14, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xl]/avatar:translate-[5px]',
    1303,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xl'],
        2000,
        [
          RaftDecl('--tw-translate-x', CssNum(5, 'px')),
          RaftDecl('--tw-translate-y', CssNum(5, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:[&>svg]:size-3',
    3083,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['group/avatar:data-size=xs'],
        2001,
        [
          RaftDecl('width', CssNum(12, 'px')),
          RaftDecl('height', CssNum(12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:bottom-[0.333px]',
    1305,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [RaftDecl('bottom', CssNum(0.333, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:outline',
    1309,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [
          RaftDecl('outline-style', _v69),
          RaftDecl('outline-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:right-[0.333px]',
    1304,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [RaftDecl('right', CssNum(0.333, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:size-1.5',
    1306,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [
          RaftDecl('width', CssNum(6, 'px')),
          RaftDecl('height', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:text-xs',
    1308,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [
          RaftDecl('font-size', CssNum(12, 'px')),
          RaftDecl('line-height', _v143),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:translate-[2.75px]',
    1307,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [
          RaftDecl('--tw-translate-x', CssNum(2.75, 'px')),
          RaftDecl('--tw-translate-y', CssNum(2.75, 'px')),
          RaftDecl('translate', CssSeq([_v71, _v72])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[status=warning]/banner:[&_button]:text-current',
    2835,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& button',
        ['group/banner:data-status=warning'],
        2001,
        [RaftDecl('color', _v35)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[status=warning]/banner:text-[oklch(0.476_0.114_61.907)]',
    1310,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/banner:data-status=warning'],
        2000,
        [RaftDecl('color', _v132)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[unread=true]/inbox-item:font-bold',
    1311,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-unread=true'],
        2000,
        [
          RaftDecl('--tw-font-weight', CssNum(700)),
          RaftDecl('font-weight', CssNum(700)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[unread=true]/inbox-item:text-black',
    1312,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-unread=true'],
        2000,
        [RaftDecl('color', _v5)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[unread=true]/inbox-item:text-foreground',
    1313,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-unread=true'],
        2000,
        [RaftDecl('color', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[unread=true]/inbox-item:text-foreground-strong',
    1314,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-unread=true'],
        2000,
        [RaftDecl('color', _v0)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-active/lightbox-thumb:bg-transparent',
    1199,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/lightbox-thumb:data-active'],
        2000,
        [RaftDecl('background-color', _v7)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-checked/checkbox:fill-foreground',
    1200,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-checked'],
        2000,
        [RaftDecl('fill', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-checked/checkbox:fill-primary-400',
    1201,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-checked'],
        2000,
        [RaftDecl('fill', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-checked/checkbox:group-data-disabled/checkbox:fill-fill-muted',
    1216,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-checked', 'group/checkbox:data-disabled'],
        3000,
        [RaftDecl('fill', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-checked/segmented-control-item:text-foreground-strong/70',
    1208,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/segmented-control-item:data-checked'],
        2000,
        [RaftDecl('color', _v0)],
      ),
      RaftLayer(
        'self',
        ['group/segmented-control-item:data-checked'],
        2000,
        [RaftDecl('color', _v48)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-checked/segmented-control-item:text-primary-950/60',
    1209,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/segmented-control-item:data-checked'],
        2000,
        [RaftDecl('color', _v847)],
      ),
      RaftLayer(
        'self',
        ['group/segmented-control-item:data-checked'],
        2000,
        [RaftDecl('color', _v951)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-complete/progress:shadow-none',
    1210,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/progress:data-complete'],
        2000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-disabled/checkbox:fill-fill-muted',
    1211,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-disabled'],
        2000,
        [RaftDecl('fill', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-disabled/checkbox:opacity-0',
    1213,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-disabled'],
        2000,
        [RaftDecl('opacity', CssNum(0, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-disabled/checkbox:text-line',
    1212,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-disabled'],
        2000,
        [RaftDecl('color', _v806)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-disabled/field:text-foreground-disabled',
    1219,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/field:data-disabled'],
        2000,
        [RaftDecl('color', _v754)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-disabled/label:text-foreground-disabled',
    1220,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/label:data-disabled'],
        2000,
        [RaftDecl('color', _v754)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-indeterminate/checkbox:fill-foreground',
    1221,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-indeterminate'],
        2000,
        [RaftDecl('fill', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-indeterminate/checkbox:fill-primary-400',
    1222,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-indeterminate'],
        2000,
        [RaftDecl('fill', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-indeterminate/checkbox:group-data-disabled/checkbox:fill-fill-muted',
    1229,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-disabled', 'group/checkbox:data-indeterminate'],
        3000,
        [RaftDecl('fill', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-invalid/field:text-danger',
    1232,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/field:data-invalid'],
        2000,
        [RaftDecl('color', _v137)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-nested-drawer-open/drawer-popup:opacity-0',
    1233,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/drawer-popup:data-nested-drawer-open'],
        2000,
        [RaftDecl('opacity', CssNum(0, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-nested-drawer-swiping/drawer-popup:opacity-100',
    1234,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/drawer-popup:data-nested-drawer-swiping'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-open/section:hidden',
    1235,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/section:data-open'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-panel-open:rotate-0',
    1236,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-panel-open'],
        2000,
        [RaftDecl('rotate', CssNum(0, 'deg'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-popup-open/section-header:hidden',
    1237,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/section-header:data-popup-open'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-swiping/drawer-popup:select-none',
    1238,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/drawer-popup:data-swiping'],
        2000,
        [
          RaftDecl('-webkit-user-select', CssKeyword('none')),
          RaftDecl('user-select', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:fill-foreground',
    1197,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:focus-visible'],
        2000,
        [RaftDecl('fill', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:fill-primary-400',
    1198,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:focus-visible'],
        2000,
        [RaftDecl('fill', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:group-data-checked/checkbox:fill-foreground',
    1205,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-checked', 'group/checkbox:focus-visible'],
        3000,
        [RaftDecl('fill', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:group-data-checked/checkbox:fill-primary-400',
    1206,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-checked', 'group/checkbox:focus-visible'],
        3000,
        [RaftDecl('fill', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:group-data-checked/checkbox:group-data-disabled/checkbox:fill-fill-muted',
    1218,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'group/checkbox:data-checked',
          'group/checkbox:data-disabled',
          'group/checkbox:focus-visible',
        ],
        4000,
        [RaftDecl('fill', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:group-data-checked/checkbox:opacity-100',
    1207,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-checked', 'group/checkbox:focus-visible'],
        3000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:group-data-disabled/checkbox:opacity-0',
    1215,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-disabled', 'group/checkbox:focus-visible'],
        3000,
        [RaftDecl('opacity', CssNum(0, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:group-data-indeterminate/checkbox:fill-foreground',
    1226,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-indeterminate', 'group/checkbox:focus-visible'],
        3000,
        [RaftDecl('fill', _v14)],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:group-data-indeterminate/checkbox:fill-primary-400',
    1227,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-indeterminate', 'group/checkbox:focus-visible'],
        3000,
        [RaftDecl('fill', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:group-data-indeterminate/checkbox:group-data-disabled/checkbox:fill-fill-muted',
    1231,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'group/checkbox:data-disabled',
          'group/checkbox:data-indeterminate',
          'group/checkbox:focus-visible',
        ],
        4000,
        [RaftDecl('fill', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible/checkbox:group-data-indeterminate/checkbox:opacity-100',
    1228,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-indeterminate', 'group/checkbox:focus-visible'],
        3000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-visible:[clip-path:inset(0_round_9999px_0_0_9999px)]',
    1196,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:focus-visible'],
        2000,
        [RaftDecl('clip-path', _v953)],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-within/toast:[animation-play-state:paused]',
    1182,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/toast:focus-within'],
        2000,
        [RaftDecl('animation-play-state', CssKeyword('paused'))],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/attachment:text-black',
    1187,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/attachment:hover'],
        2000,
        [RaftDecl('color', _v5)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/attachment:text-foreground-strong',
    1188,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/attachment:hover'],
        2000,
        [RaftDecl('color', _v0)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/checkbox:fill-[oklch(0.976_0.001_106.42)]',
    1189,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:hover'],
        2000,
        [RaftDecl('fill', _v954)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/checkbox:group-data-checked/checkbox:fill-foreground-active',
    1202,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-checked', 'group/checkbox:hover'],
        3000,
        [RaftDecl('fill', _v794)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/checkbox:group-data-checked/checkbox:fill-primary-hover',
    1203,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-checked', 'group/checkbox:hover'],
        3000,
        [RaftDecl('fill', _v807)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/checkbox:group-data-checked/checkbox:group-data-disabled/checkbox:fill-fill-muted',
    1217,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'group/checkbox:data-checked',
          'group/checkbox:data-disabled',
          'group/checkbox:hover',
        ],
        4000,
        [RaftDecl('fill', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/checkbox:group-data-checked/checkbox:opacity-100',
    1204,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-checked', 'group/checkbox:hover'],
        3000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/checkbox:group-data-disabled/checkbox:opacity-0',
    1214,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-disabled', 'group/checkbox:hover'],
        3000,
        [RaftDecl('opacity', CssNum(0, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/checkbox:group-data-indeterminate/checkbox:fill-foreground-active',
    1223,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-indeterminate', 'group/checkbox:hover'],
        3000,
        [RaftDecl('fill', _v794)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/checkbox:group-data-indeterminate/checkbox:fill-primary-hover',
    1224,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-indeterminate', 'group/checkbox:hover'],
        3000,
        [RaftDecl('fill', _v807)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/checkbox:group-data-indeterminate/checkbox:group-data-disabled/checkbox:fill-fill-muted',
    1230,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'group/checkbox:data-disabled',
          'group/checkbox:data-indeterminate',
          'group/checkbox:hover',
        ],
        4000,
        [RaftDecl('fill', _v222)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/checkbox:group-data-indeterminate/checkbox:opacity-100',
    1225,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/checkbox:data-indeterminate', 'group/checkbox:hover'],
        3000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/composer-attachment:opacity-100',
    1190,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/composer-attachment:hover'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility('group-hover/img:flex', 1191, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['group/img:hover'],
      2000,
      [RaftDecl('display', CssKeyword('flex'))],
    ),
  ]),
  RaftUtility(
    'group-hover/lightbox-thumb:bg-black/28',
    1192,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/lightbox-thumb:hover'],
        2000,
        [RaftDecl('background-color', _v956)],
      ),
      RaftLayer(
        'self',
        ['group/lightbox-thumb:hover'],
        2000,
        [RaftDecl('background-color', _v957)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/message-replies:text-black',
    1193,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/message-replies:hover'],
        2000,
        [RaftDecl('color', _v5)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/section-header:hidden',
    1194,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/section-header:hover'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/toast:[animation-play-state:paused]',
    1195,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/toast:hover'],
        2000,
        [RaftDecl('animation-play-state', CssKeyword('paused'))],
      ),
    ],
  ),
  RaftUtility(
    'group-hover:[clip-path:inset(0_round_9999px_0_0_9999px)]',
    1186,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['group:hover'], 2000, [RaftDecl('clip-path', _v953)]),
    ],
  ),
  RaftUtility(
    'group-hover:bg-[color-mix(in_oklch,var(--ink)_2%,var(--layer-panel))]',
    1183,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:hover'],
        2000,
        [RaftDecl('background-color', _v324)],
      ),
      RaftLayer(
        'self',
        ['group:hover'],
        2000,
        [RaftDecl('background-color', _v959)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover:text-foreground-strong',
    1184,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['group:hover'], 2000, [RaftDecl('color', _v0)]),
    ],
  ),
  RaftUtility(
    'group-hover:text-foreground-strong/20',
    1185,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['group:hover'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer('self', ['group:hover'], 2000, [RaftDecl('color', _v961)]),
    ],
  ),
  RaftUtility('group/attachment', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/avatar', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/avatar-group', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/banner', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/card-header', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/checkbox', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/code-block', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/composer-attachment', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/copyable-code', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/drawer-popup', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/field', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/field-item', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/file-row', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/img', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/input-group', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/label', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/lightbox-thumb', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/message', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/message-replies', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/panel-frame', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/progress', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/scroll-area-scrollbar', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/search-message', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/section', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/section-header', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/sidebar-item', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/tabs-list', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/tabs-tab', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/task-drag-overlay', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/task-draggable', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/toast', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/video', -1, RaftUtilityStatus.marker, []),
  RaftUtility('h-(--active-tab-height)', 167, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v962)]),
  ]),
  RaftUtility(
    'h-(--code-block-header-height)',
    168,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', _v963)]),
    ],
  ),
  RaftUtility('h-(--drawer-content-height)', 169, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v964)]),
  ]),
  RaftUtility(
    'h-(--shell-header-height,56px)',
    170,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', _v965)]),
    ],
  ),
  RaftUtility(
    'h-(--shell-header-height,62px)',
    171,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', _v254)]),
    ],
  ),
  RaftUtility(
    'h-(--task-dnd-placeholder-height,72px)',
    172,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', _v966)]),
    ],
  ),
  RaftUtility('h-(--toast-stack-height)', 173, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v967)]),
  ]),
  RaftUtility('h-0', 174, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(0, 'px'))]),
  ]),
  RaftUtility('h-0.5', 175, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(2, 'px'))]),
  ]),
  RaftUtility('h-1', 176, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(4, 'px'))]),
  ]),
  RaftUtility('h-1.5', 177, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(6, 'px'))]),
  ]),
  RaftUtility('h-10', 187, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(40, 'px'))]),
  ]),
  RaftUtility('h-11', 188, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(44, 'px'))]),
  ]),
  RaftUtility('h-12', 189, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(48, 'px'))]),
  ]),
  RaftUtility('h-16', 190, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(64, 'px'))]),
  ]),
  RaftUtility('h-18', 191, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(72, 'px'))]),
  ]),
  RaftUtility('h-2', 178, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(8, 'px'))]),
  ]),
  RaftUtility('h-20', 192, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(80, 'px'))]),
  ]),
  RaftUtility('h-3', 179, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(12, 'px'))]),
  ]),
  RaftUtility('h-3.5', 180, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(14, 'px'))]),
  ]),
  RaftUtility('h-4', 181, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(16, 'px'))]),
  ]),
  RaftUtility('h-5', 182, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(20, 'px'))]),
  ]),
  RaftUtility('h-56', 193, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(224, 'px'))]),
  ]),
  RaftUtility('h-6', 183, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(24, 'px'))]),
  ]),
  RaftUtility('h-7', 184, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(28, 'px'))]),
  ]),
  RaftUtility('h-72', 194, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(288, 'px'))]),
  ]),
  RaftUtility('h-8', 185, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(32, 'px'))]),
  ]),
  RaftUtility('h-9', 186, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(36, 'px'))]),
  ]),
  RaftUtility('h-96', 195, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(384, 'px'))]),
  ]),
  RaftUtility('h-[19px]', 197, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(19, 'px'))]),
  ]),
  RaftUtility('h-[3px]', 196, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(3, 'px'))]),
  ]),
  RaftUtility('h-[46px]', 198, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(46, 'px'))]),
  ]),
  RaftUtility('h-[calc(1.2em+2px)]', 199, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssCalc(_v968))]),
  ]),
  RaftUtility('h-[calc(100%+12px)]', 201, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssCalc(_v969))]),
  ]),
  RaftUtility(
    'h-[calc(56px+env(safe-area-inset-top,0px))]',
    200,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', CssCalc(_v970))]),
    ],
  ),
  RaftUtility(
    'h-[calc(var(--active-tab-height)-3.34375px)]',
    202,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', CssCalc(_v971))]),
    ],
  ),
  RaftUtility('h-auto', 203, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssKeyword('auto'))]),
  ]),
  RaftUtility('h-fit', 204, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v972)]),
  ]),
  RaftUtility('h-full', 205, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(100, '%'))]),
  ]),
  RaftUtility('h-px', 206, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(1, 'px'))]),
  ]),
  RaftUtility(
    'has-[+[data-slot=card-content]]:pb-0',
    1734,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:+data-slot=card-content'],
        2000,
        [RaftDecl('padding-bottom', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-message-reference-badge]]:overflow-visible',
    1735,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-message-reference-badge'],
        2000,
        [
          RaftDecl('overflow-x', CssKeyword('visible')),
          RaftDecl('overflow-y', CssKeyword('visible')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-action]]:gap-x-2',
    1737,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-action'],
        2000,
        [RaftDecl('column-gap', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-action]]:gap-x-3',
    1738,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-action'],
        2000,
        [RaftDecl('column-gap', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-action]]:grid-cols-[minmax(0,1fr)_auto]',
    1736,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-action'],
        2000,
        [RaftDecl('grid-template-columns', _v941)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-title]]:[--banner-desc-row:2]',
    1739,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-title'],
        2000,
        [RaftDecl('--banner-desc-row', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-title]]:has-[>[data-slot=banner-description]]:[&>svg]:mt-0.5',
    3086,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>data-slot=banner-description', 'has:>data-slot=banner-title'],
        3001,
        [RaftDecl('margin-top', CssNum(2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-title]]:has-[>[data-slot=banner-description]]:[&>svg]:row-span-2',
    3085,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>data-slot=banner-description', 'has:>data-slot=banner-title'],
        3001,
        [RaftDecl('grid-row', _v73)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-title]]:has-[>[data-slot=banner-description]]:[&>svg]:self-start',
    3087,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>data-slot=banner-description', 'has:>data-slot=banner-title'],
        3001,
        [RaftDecl('align-self', _v141)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-title]]:has-[>[data-slot=banner-description]]:gap-y-1',
    1742,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-description', 'has:>data-slot=banner-title'],
        3000,
        [RaftDecl('row-gap', CssNum(4, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-title]]:has-[>[data-slot=banner-description]]:grid-rows-[auto_auto]',
    1740,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-description', 'has:>data-slot=banner-title'],
        3000,
        [RaftDecl('grid-template-rows', _v973)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-title]]:has-[>[data-slot=banner-description]]:items-start',
    1741,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-description', 'has:>data-slot=banner-title'],
        3000,
        [RaftDecl('align-items', _v141)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=card-leading]]:[--card-text-col:2]',
    1744,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=card-leading'],
        2000,
        [RaftDecl('--card-text-col', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=card-leading]]:[--card-trailing-col:3]',
    1745,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=card-leading'],
        2000,
        [RaftDecl('--card-trailing-col', CssNum(3))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=card-leading]]:grid-cols-[auto_minmax(0,1fr)]',
    1743,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=card-leading'],
        2000,
        [RaftDecl('grid-template-columns', _v109)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=card-leading]]:has-[>[data-slot=card-trailing]]:grid-cols-[auto_minmax(0,1fr)_auto]',
    1747,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=card-leading', 'has:>data-slot=card-trailing'],
        3000,
        [RaftDecl('grid-template-columns', _v107)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=card-trailing]]:grid-cols-[minmax(0,1fr)_auto]',
    1746,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=card-trailing'],
        2000,
        [RaftDecl('grid-template-columns', _v941)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=composer-attachments]]:before:-inset-1',
    1752,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=composer-attachments'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-4, 'px')),
          RaftDecl('right', CssNum(-4, 'px')),
          RaftDecl('bottom', CssNum(-4, 'px')),
          RaftDecl('left', CssNum(-4, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=composer-attachments]]:before:-z-10',
    1753,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=composer-attachments'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('z-index', CssNum(-10)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=composer-attachments]]:before:absolute',
    1751,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=composer-attachments'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('position', CssKeyword('absolute')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=composer-attachments]]:before:bg-layer-inset',
    1755,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=composer-attachments'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v488),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=composer-attachments]]:before:pointer-events-none',
    1750,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=composer-attachments'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('pointer-events', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=composer-attachments]]:before:ring-1',
    1756,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=composer-attachments'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-ring-shadow', _v293),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=composer-attachments]]:before:ring-line-muted/60',
    1757,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=composer-attachments'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-ring-color', _v81),
        ],
      ),
      RaftLayer(
        '::before',
        ['has:>data-slot=composer-attachments'],
        2001,
        [RaftDecl('--tw-ring-color', _v885)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=composer-attachments]]:before:rounded-xl',
    1754,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=composer-attachments'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('border-top-left-radius', CssNum(12, 'px')),
          RaftDecl('border-top-right-radius', CssNum(12, 'px')),
          RaftDecl('border-bottom-right-radius', CssNum(12, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=composer-attachments]]:isolate',
    1749,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=composer-attachments'],
        2000,
        [RaftDecl('isolation', CssKeyword('isolate'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=composer-attachments]]:relative',
    1748,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=composer-attachments'],
        2000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-indicator]]:inline-block',
    1760,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=message-reference-indicator'],
        2000,
        [RaftDecl('display', _v974)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-indicator]]:mr-2',
    1759,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=message-reference-indicator'],
        2000,
        [RaftDecl('margin-right', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-indicator]]:overflow-visible',
    1761,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=message-reference-indicator'],
        2000,
        [
          RaftDecl('overflow-x', CssKeyword('visible')),
          RaftDecl('overflow-y', CssKeyword('visible')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-indicator]]:relative',
    1758,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=message-reference-indicator'],
        2000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:[&>svg]:mx-[calc((1.2em+2px-0.857em)/2)]',
    3090,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('margin-left', CssCalc(_v976)),
          RaftDecl('margin-right', CssCalc(_v976)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:[&>svg]:overflow-visible',
    3092,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('overflow-x', CssKeyword('visible')),
          RaftDecl('overflow-y', CssKeyword('visible')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:[&>svg]:relative',
    3088,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>data-slot=message-reference-label'],
        2001,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:[&>svg]:shrink-0',
    3091,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>data-slot=message-reference-label'],
        2001,
        [RaftDecl('flex-shrink', CssNum(0))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:[&>svg]:text-(--reference-badge-ink,currentColor)',
    3093,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>data-slot=message-reference-label'],
        2001,
        [RaftDecl('color', _v977)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:[&>svg]:z-10',
    3089,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>data-slot=message-reference-label'],
        2001,
        [RaftDecl('z-index', CssNum(10))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:before:-top-px',
    1769,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:before:absolute',
    1768,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('position', CssKeyword('absolute')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:before:bg-(--reference-badge,transparent)',
    1774,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v385),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:before:content-[\'\']',
    1775,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('--tw-content', CssString('')),
          RaftDecl('content', CssVar('--tw-content')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:before:left-0',
    1770,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:before:pointer-events-none',
    1767,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('pointer-events', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:before:rounded-full',
    1773,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('border-top-left-radius', _v77),
          RaftDecl('border-top-right-radius', _v77),
          RaftDecl('border-bottom-right-radius', _v77),
          RaftDecl('border-bottom-left-radius', _v77),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:before:size-[calc(1.2em+2px)]',
    1772,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('width', CssCalc(_v968)),
          RaftDecl('height', CssCalc(_v968)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:before:z-1',
    1771,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>data-slot=message-reference-label'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('z-index', CssNum(1)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:gap-1',
    1763,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=message-reference-label'],
        2000,
        [
          RaftDecl('row-gap', CssNum(4, 'px')),
          RaftDecl('column-gap', CssNum(4, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:isolate',
    1762,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=message-reference-label'],
        2000,
        [RaftDecl('isolation', CssKeyword('isolate'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:overflow-visible',
    1764,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=message-reference-label'],
        2000,
        [
          RaftDecl('overflow-x', CssKeyword('visible')),
          RaftDecl('overflow-y', CssKeyword('visible')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:pl-0',
    1766,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=message-reference-label'],
        2000,
        [RaftDecl('padding-left', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-label]]:pr-2',
    1765,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=message-reference-label'],
        2000,
        [RaftDecl('padding-right', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=panel-header-icon]]:[--ph-meta-col:2]',
    1780,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon'],
        2000,
        [RaftDecl('--ph-meta-col', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=panel-header-icon]]:[--ph-text-col:2]',
    1781,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon'],
        2000,
        [RaftDecl('--ph-text-col', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=panel-header-icon]]:gap-x-3',
    1779,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon'],
        2000,
        [RaftDecl('column-gap', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=panel-header-icon]]:grid',
    1776,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon'],
        2000,
        [RaftDecl('display', CssKeyword('grid'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=panel-header-icon]]:grid-cols-[auto_minmax(0,1fr)]',
    1777,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon'],
        2000,
        [RaftDecl('grid-template-columns', _v109)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=panel-header-icon]]:items-center',
    1778,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon'],
        2000,
        [RaftDecl('align-items', CssKeyword('center'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=panel-meta]]:[--ph-icon-row-end:span_2]',
    1782,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-meta'],
        2000,
        [RaftDecl('--ph-icon-row-end', _v978)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=panel-meta]]:[--ph-icon-row-start:span_2]',
    1783,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-meta'],
        2000,
        [RaftDecl('--ph-icon-row-start', _v978)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=sidebar-item-meta-icon]]:items-center',
    1784,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=sidebar-item-meta-icon'],
        2000,
        [RaftDecl('align-items', CssKeyword('center'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=sidebar-item-subtitle]]:[--si-title-max-w:70%]',
    1785,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=sidebar-item-subtitle'],
        2000,
        [RaftDecl('--si-title-max-w', CssNum(70, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=sidebar-item-subtitle]]:[--si-title-shrink:0]',
    1786,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=sidebar-item-subtitle'],
        2000,
        [RaftDecl('--si-title-shrink', CssNum(0))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=sidebar-live-activity]_[data-slot=live-agent-activity-bar]]:overflow-clip',
    1787,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:>data-slot=sidebar-live-activity data-slot=live-agent-activity-bar',
        ],
        3000,
        [
          RaftDecl('overflow-x', CssKeyword('clip')),
          RaftDecl('overflow-y', CssKeyword('clip')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=status]]:[--banner-action-col:3]',
    1791,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=status'],
        2000,
        [RaftDecl('--banner-action-col', CssNum(3))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=status]]:[--banner-text-col:2]',
    1792,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=status'],
        2000,
        [RaftDecl('--banner-text-col', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=status]]:gap-x-1.5',
    1789,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=status'],
        2000,
        [RaftDecl('column-gap', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=status]]:gap-x-2',
    1790,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=status'],
        2000,
        [RaftDecl('column-gap', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=status]]:grid-cols-[auto_minmax(0,1fr)]',
    1788,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=status'],
        2000,
        [RaftDecl('grid-template-columns', _v109)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=status]]:has-[>[data-slot=banner-action]]:grid-cols-[auto_minmax(0,1fr)_auto]',
    1793,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-action', 'has:>data-slot=status'],
        3000,
        [RaftDecl('grid-template-columns', _v107)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=tabs-background]]:[--tabs-ring:var(--ink-4)]',
    1794,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=tabs-background'],
        2000,
        [RaftDecl('--tabs-ring', _v390)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=textarea-counter]]:[--ta-pr:4rem]',
    1795,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=textarea-counter'],
        2000,
        [RaftDecl('--ta-pr', CssNum(64, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=textarea-counter]]:[--ta-scroll-pb:1.5rem]',
    1796,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=textarea-counter'],
        2000,
        [RaftDecl('--ta-scroll-pb', CssNum(24, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg]:[&>svg]:mx-[3px]',
    3096,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>svg'],
        1002,
        [
          RaftDecl('margin-left', CssNum(3, 'px')),
          RaftDecl('margin-right', CssNum(3, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg]:[&>svg]:relative',
    3094,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['has:>svg'],
        1002,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg]:[&>svg]:text-black',
    3097,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', ['has:>svg'], 1002, [RaftDecl('color', _v5)]),
    ],
  ),
  RaftUtility('has-[>svg]:[&>svg]:z-10', 3095, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', ['has:>svg'], 1002, [RaftDecl('z-index', CssNum(10))]),
  ]),
  RaftUtility(
    'has-[>svg]:[--banner-action-col:3]',
    1805,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>svg'],
        1001,
        [RaftDecl('--banner-action-col', CssNum(3))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg]:[--banner-text-col:2]',
    1806,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>svg'],
        1001,
        [RaftDecl('--banner-text-col', CssNum(2))],
      ),
    ],
  ),
  RaftUtility('has-[>svg]:before:absolute', 1808, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['has:>svg'],
      1002,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('position', CssKeyword('absolute')),
      ],
    ),
  ]),
  RaftUtility(
    'has-[>svg]:before:bg-(--reference-icon)',
    1815,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>svg'],
        1002,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v979),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg]:before:border-black',
    1814,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>svg'],
        1002,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('border-top-color', _v5),
          RaftDecl('border-right-color', _v5),
          RaftDecl('border-bottom-color', _v5),
          RaftDecl('border-left-color', _v5),
        ],
      ),
    ],
  ),
  RaftUtility('has-[>svg]:before:border-r', 1813, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['has:>svg'],
      1002,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('border-right-style', _v31),
        RaftDecl('border-right-width', CssNum(1, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'has-[>svg]:before:content-[\'\']',
    1816,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>svg'],
        1002,
        [
          RaftDecl('--tw-content', CssString('')),
          RaftDecl('content', CssVar('--tw-content')),
        ],
      ),
    ],
  ),
  RaftUtility('has-[>svg]:before:inset-y-0', 1809, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['has:>svg'],
      1002,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssNum(0, 'px')),
        RaftDecl('bottom', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('has-[>svg]:before:left-0', 1810, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['has:>svg'],
      1002,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('left', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'has-[>svg]:before:pointer-events-none',
    1807,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>svg'],
        1002,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('pointer-events', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg]:before:w-[calc(0.857em+6px)]',
    1812,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:>svg'],
        1002,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('width', CssCalc(_v980)),
        ],
      ),
    ],
  ),
  RaftUtility('has-[>svg]:before:z-0', 1811, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['has:>svg'],
      1002,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('z-index', CssNum(0)),
      ],
    ),
  ]),
  RaftUtility('has-[>svg]:gap-x-2', 1801, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:>svg'],
      1001,
      [RaftDecl('column-gap', CssNum(8, 'px'))],
    ),
  ]),
  RaftUtility('has-[>svg]:gap-x-3', 1802, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:>svg'],
      1001,
      [RaftDecl('column-gap', CssNum(12, 'px'))],
    ),
  ]),
  RaftUtility(
    'has-[>svg]:grid-cols-[18px_minmax(0,1fr)]',
    1799,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>svg'],
        1001,
        [RaftDecl('grid-template-columns', _v981)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg]:grid-cols-[auto_minmax(0,1fr)]',
    1800,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>svg'],
        1001,
        [RaftDecl('grid-template-columns', _v109)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg]:has-[>[data-slot=banner-action]]:grid-cols-[auto_minmax(0,1fr)_auto]',
    1817,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-action', 'has:>svg'],
        2001,
        [RaftDecl('grid-template-columns', _v107)],
      ),
    ],
  ),
  RaftUtility('has-[>svg]:isolate', 1798, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:>svg'],
      1001,
      [RaftDecl('isolation', CssKeyword('isolate'))],
    ),
  ]),
  RaftUtility('has-[>svg]:pl-0', 1804, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:>svg'],
      1001,
      [RaftDecl('padding-left', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('has-[>svg]:pr-1', 1803, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:>svg'],
      1001,
      [RaftDecl('padding-right', CssNum(4, 'px'))],
    ),
  ]),
  RaftUtility('has-[>svg]:relative', 1797, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:>svg'],
      1001,
      [RaftDecl('position', CssKeyword('relative'))],
    ),
  ]),
  RaftUtility(
    'has-[[data-slot=composer-attachment-image]]:size-16',
    1690,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=composer-attachment-image'],
        2000,
        [
          RaftDecl('width', CssNum(64, 'px')),
          RaftDecl('height', CssNum(64, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=composer-attachments-scroll-area]]:-mx-1',
    1691,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=composer-attachments-scroll-area'],
        2000,
        [
          RaftDecl('margin-left', CssNum(-4, 'px')),
          RaftDecl('margin-right', CssNum(-4, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=composer-attachments-scroll-area]]:min-w-0',
    1692,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=composer-attachments-scroll-area'],
        2000,
        [RaftDecl('min-width', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=file-preview]]:size-10',
    1693,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=file-preview'],
        2000,
        [
          RaftDecl('width', CssNum(40, 'px')),
          RaftDecl('height', CssNum(40, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=inbox-item-open]:focus-visible]:border-black',
    1694,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-open+focus-visible'],
        3000,
        [
          RaftDecl('border-top-color', _v5),
          RaftDecl('border-right-color', _v5),
          RaftDecl('border-bottom-color', _v5),
          RaftDecl('border-left-color', _v5),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=inbox-item-open]:focus-visible]:ring-1',
    1696,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-open+focus-visible'],
        3000,
        [RaftDecl('--tw-ring-shadow', _v293), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=inbox-item-open]:focus-visible]:ring-primary-400',
    1697,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-open+focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=inbox-item-open]:focus-visible]:shadow-raft-sm',
    1695,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-open+focus-visible'],
        3000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:[--ig-addon-fg:var(--foreground-disabled)]',
    1701,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('--ig-addon-fg', _v754)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:[--ig-text-fg:var(--foreground-disabled)]',
    1702,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('--ig-text-fg', _v754)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:bg-fill-muted/50',
    1700,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('background-color', _v222)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('background-color', _v464)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:border-line-muted/60',
    1699,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [
          RaftDecl('border-top-color', _v81),
          RaftDecl('border-right-color', _v81),
          RaftDecl('border-bottom-color', _v81),
          RaftDecl('border-left-color', _v81),
        ],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [
          RaftDecl('border-top-color', _v885),
          RaftDecl('border-right-color', _v885),
          RaftDecl('border-bottom-color', _v885),
          RaftDecl('border-left-color', _v885),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:cursor-not-allowed',
    1698,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('cursor', _v320)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:hover:border-line-muted/60',
    1703,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled', 'hover'],
        4000,
        [
          RaftDecl('border-top-color', _v81),
          RaftDecl('border-right-color', _v81),
          RaftDecl('border-bottom-color', _v81),
          RaftDecl('border-left-color', _v81),
        ],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled', 'hover'],
        4000,
        [
          RaftDecl('border-top-color', _v885),
          RaftDecl('border-right-color', _v885),
          RaftDecl('border-bottom-color', _v885),
          RaftDecl('border-left-color', _v885),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:focus-visible]:ring-1',
    1708,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+focus-visible'],
        3000,
        [RaftDecl('--tw-ring-shadow', _v293), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:focus-visible]:ring-primary-400',
    1709,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:focus]:[--ig-addon-fg:var(--foreground-strong)]',
    1705,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+focus'],
        3000,
        [RaftDecl('--ig-addon-fg', _v0)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:focus]:[--ig-text-fg:var(--foreground-muted)]',
    1706,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+focus'],
        3000,
        [RaftDecl('--ig-text-fg', _v22)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:focus]:bg-layer-panel',
    1704,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+focus'],
        3000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:focus]:not-has-[[data-slot=input-group-control][data-invalid]]:shadow-raft-md',
    1707,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:data-slot=input-group-control+focus',
          'not:has:data-slot=input-group-control+data-invalid',
        ],
        5000,
        [RaftDecl('--tw-shadow', _v61), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]:disabled]:border-line-muted/60',
    1717,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid+disabled'],
        4000,
        [
          RaftDecl('border-top-color', _v81),
          RaftDecl('border-right-color', _v81),
          RaftDecl('border-bottom-color', _v81),
          RaftDecl('border-left-color', _v81),
        ],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid+disabled'],
        4000,
        [
          RaftDecl('border-top-color', _v885),
          RaftDecl('border-right-color', _v885),
          RaftDecl('border-bottom-color', _v885),
          RaftDecl('border-left-color', _v885),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]:disabled]:ring-0',
    1718,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid+disabled'],
        4000,
        [RaftDecl('--tw-ring-shadow', _v37), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]:focus-visible]:ring-2',
    1720,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid+focus-visible'],
        4000,
        [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]:focus-visible]:ring-[color-mix(in_oklch,var(--danger)_60%,transparent)]',
    1721,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid+focus-visible'],
        4000,
        [RaftDecl('--tw-ring-color', _v137)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid+focus-visible'],
        4000,
        [RaftDecl('--tw-ring-color', _v891)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]:focus]:border-danger/75',
    1719,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid+focus'],
        4000,
        [
          RaftDecl('border-top-color', _v137),
          RaftDecl('border-right-color', _v137),
          RaftDecl('border-bottom-color', _v137),
          RaftDecl('border-left-color', _v137),
        ],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid+focus'],
        4000,
        [
          RaftDecl('border-top-color', _v887),
          RaftDecl('border-right-color', _v887),
          RaftDecl('border-bottom-color', _v887),
          RaftDecl('border-left-color', _v887),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]]:bg-brutal-red/5',
    1712,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid'],
        3000,
        [RaftDecl('background-color', _v880)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid'],
        3000,
        [RaftDecl('background-color', _v881)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]]:border-brutal-red',
    1710,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid'],
        3000,
        [
          RaftDecl('border-top-color', CssColor(0xFFF97264)),
          RaftDecl('border-right-color', CssColor(0xFFF97264)),
          RaftDecl('border-bottom-color', CssColor(0xFFF97264)),
          RaftDecl('border-left-color', CssColor(0xFFF97264)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]]:border-danger/45',
    1711,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid'],
        3000,
        [
          RaftDecl('border-top-color', _v137),
          RaftDecl('border-right-color', _v137),
          RaftDecl('border-bottom-color', _v137),
          RaftDecl('border-left-color', _v137),
        ],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid'],
        3000,
        [
          RaftDecl('border-top-color', _v883),
          RaftDecl('border-right-color', _v883),
          RaftDecl('border-bottom-color', _v883),
          RaftDecl('border-left-color', _v883),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]]:hover:border-danger/75',
    1716,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid', 'hover'],
        4000,
        [
          RaftDecl('border-top-color', _v137),
          RaftDecl('border-right-color', _v137),
          RaftDecl('border-bottom-color', _v137),
          RaftDecl('border-left-color', _v137),
        ],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid', 'hover'],
        4000,
        [
          RaftDecl('border-top-color', _v887),
          RaftDecl('border-right-color', _v887),
          RaftDecl('border-bottom-color', _v887),
          RaftDecl('border-left-color', _v887),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]]:ring-2',
    1714,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid'],
        3000,
        [RaftDecl('--tw-ring-shadow', _v618), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]]:ring-brutal-red/60',
    1715,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid'],
        3000,
        [RaftDecl('--tw-ring-color', _v895)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid'],
        3000,
        [RaftDecl('--tw-ring-color', _v896)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]]:shadow-none',
    1713,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid'],
        3000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=kbd]]:pr-1.5',
    1723,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=kbd'],
        2000,
        [RaftDecl('padding-right', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=kbd]]:py-1.5',
    1722,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=kbd'],
        2000,
        [
          RaftDecl('padding-top', CssNum(6, 'px')),
          RaftDecl('padding-bottom', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=segmented-control-count]]:pr-1.5',
    1724,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=segmented-control-count'],
        2000,
        [RaftDecl('padding-right', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=segmented-control-count]]:pr-2',
    1725,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=segmented-control-count'],
        2000,
        [RaftDecl('padding-right', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=sortable-composer-attachments-list]]:min-w-0',
    1726,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=sortable-composer-attachments-list'],
        2000,
        [RaftDecl('min-width', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=task-drop-placeholder][data-drop-state=allowed]]:bg-primary/20',
    1728,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=task-drop-placeholder+data-drop-state=allowed'],
        3000,
        [RaftDecl('background-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=task-drop-placeholder+data-drop-state=allowed'],
        3000,
        [RaftDecl('background-color', _v504)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=task-drop-placeholder][data-drop-state=allowed]]:border-line-strong',
    1727,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=task-drop-placeholder+data-drop-state=allowed'],
        3000,
        [
          RaftDecl('border-top-color', _v43),
          RaftDecl('border-right-color', _v43),
          RaftDecl('border-bottom-color', _v43),
          RaftDecl('border-left-color', _v43),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=task-drop-placeholder][data-drop-state=allowed]]:shadow-raft-sm',
    1729,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=task-drop-placeholder+data-drop-state=allowed'],
        3000,
        [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=task-drop-placeholder][data-drop-state=blocked]]:bg-danger-soft',
    1731,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=task-drop-placeholder+data-drop-state=blocked'],
        3000,
        [RaftDecl('background-color', _v326)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=task-drop-placeholder][data-drop-state=blocked]]:border-danger',
    1730,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=task-drop-placeholder+data-drop-state=blocked'],
        3000,
        [
          RaftDecl('border-top-color', _v137),
          RaftDecl('border-right-color', _v137),
          RaftDecl('border-bottom-color', _v137),
          RaftDecl('border-left-color', _v137),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:-bottom-3',
    1682,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('bottom', CssNum(-12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:[-webkit-mask-image:linear-gradient(to_top,black_50%,transparent)]',
    1689,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('-webkit-mask-image', _v345),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:[mask-image:linear-gradient(to_top,black_50%,transparent)]',
    1686,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('mask-image', _v345),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:absolute',
    1680,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('position', CssKeyword('absolute')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:backdrop-blur-[4px]',
    1687,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-backdrop-blur', _v351),
          RaftDecl('-webkit-backdrop-filter', _v340),
          RaftDecl('backdrop-filter', _v340),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:bg-[linear-gradient(to_bottom,transparent,var(--layer-canvas-muted))]',
    1685,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-image', _v982),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:content-[\'\']',
    1688,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('--tw-content', CssString('')),
          RaftDecl('content', CssVar('--tw-content')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:h-20',
    1684,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('height', CssNum(80, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:inset-x-0',
    1681,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', CssNum(0, 'px')),
          RaftDecl('right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:pointer-events-none',
    1679,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('pointer-events', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[_[data-slot=live-agent-activity-bar]]:before:z-0',
    1683,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=live-agent-activity-bar'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('z-index', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility('has-[svg]:pl-1.5', 1732, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:svg'],
      1001,
      [RaftDecl('padding-left', CssNum(6, 'px'))],
    ),
  ]),
  RaftUtility('has-[svg]:pl-2', 1733, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:svg'],
      1001,
      [RaftDecl('padding-left', CssNum(8, 'px'))],
    ),
  ]),
  RaftUtility(
    'has-data-[icon=inline-end]:pr-1.5',
    1631,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-icon=inline-end'],
        2000,
        [RaftDecl('padding-right', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[icon=inline-end]:pr-2',
    1632,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-icon=inline-end'],
        2000,
        [RaftDecl('padding-right', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[icon=inline-end]:pr-2.5',
    1633,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-icon=inline-end'],
        2000,
        [RaftDecl('padding-right', CssNum(10, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[icon=inline-end]:pr-3',
    1634,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-icon=inline-end'],
        2000,
        [RaftDecl('padding-right', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[icon=inline-end]:pr-3.5',
    1635,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-icon=inline-end'],
        2000,
        [RaftDecl('padding-right', CssNum(14, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[icon=inline-start]:pl-1.5',
    1636,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-icon=inline-start'],
        2000,
        [RaftDecl('padding-left', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[icon=inline-start]:pl-2',
    1637,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-icon=inline-start'],
        2000,
        [RaftDecl('padding-left', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[icon=inline-start]:pl-2.5',
    1638,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-icon=inline-start'],
        2000,
        [RaftDecl('padding-left', CssNum(10, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[icon=inline-start]:pl-3',
    1639,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-icon=inline-start'],
        2000,
        [RaftDecl('padding-left', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[icon=inline-start]:pl-3.5',
    1640,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-icon=inline-start'],
        2000,
        [RaftDecl('padding-left', CssNum(14, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[input-group-trim=inline-end]:[--ig-control-pr:0]',
    1641,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-input-group-trim=inline-end'],
        2000,
        [RaftDecl('--ig-control-pr', CssNum(0))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=composer-attachment-image]:[--ca-overlay-border:0px]',
    1644,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=composer-attachment-image'],
        2000,
        [RaftDecl('--ca-overlay-border', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=composer-attachment-image]:border-2',
    1642,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=composer-attachment-image'],
        2000,
        [
          RaftDecl('border-top-style', _v31),
          RaftDecl('border-right-style', _v31),
          RaftDecl('border-bottom-style', _v31),
          RaftDecl('border-left-style', _v31),
          RaftDecl('border-top-width', CssNum(2, 'px')),
          RaftDecl('border-right-width', CssNum(2, 'px')),
          RaftDecl('border-bottom-width', CssNum(2, 'px')),
          RaftDecl('border-left-width', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=composer-attachment-image]:border-black',
    1643,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=composer-attachment-image'],
        2000,
        [
          RaftDecl('border-top-color', _v5),
          RaftDecl('border-right-color', _v5),
          RaftDecl('border-bottom-color', _v5),
          RaftDecl('border-left-color', _v5),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=composer-attachments-scroll-area]:block',
    1646,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=composer-attachments-scroll-area'],
        2000,
        [RaftDecl('display', CssKeyword('block'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=composer-attachments-scroll-area]:relative',
    1645,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=composer-attachments-scroll-area'],
        2000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=file-preview]:bg-transparent',
    1649,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=file-preview'],
        2000,
        [RaftDecl('background-color', _v7)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=file-preview]:border-0',
    1648,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=file-preview'],
        2000,
        [
          RaftDecl('border-top-style', _v31),
          RaftDecl('border-right-style', _v31),
          RaftDecl('border-bottom-style', _v31),
          RaftDecl('border-left-style', _v31),
          RaftDecl('border-top-width', CssNum(0, 'px')),
          RaftDecl('border-right-width', CssNum(0, 'px')),
          RaftDecl('border-bottom-width', CssNum(0, 'px')),
          RaftDecl('border-left-width', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=file-preview]:overflow-visible',
    1647,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=file-preview'],
        2000,
        [
          RaftDecl('overflow-x', CssKeyword('visible')),
          RaftDecl('overflow-y', CssKeyword('visible')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=inbox-item-selection]:grid-cols-[auto_minmax(0,1fr)_auto]',
    1650,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-selection'],
        2000,
        [RaftDecl('grid-template-columns', _v107)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-image-gallery-overlay]:hover:brightness-100',
    1652,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-image-gallery-overlay', 'hover'],
        3000,
        [RaftDecl('--tw-brightness', _v983), RaftDecl('filter', _v662)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-image-gallery-overlay]:opacity-70',
    1651,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-image-gallery-overlay'],
        2000,
        [RaftDecl('opacity', CssNum(70, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:bg-brutal-cyan/25',
    1655,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('background-color', _v985)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('background-color', _v986)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:bg-info/10',
    1656,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('background-color', _v62)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('background-color', _v988)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:border-line-strong',
    1653,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [
          RaftDecl('border-top-color', _v43),
          RaftDecl('border-right-color', _v43),
          RaftDecl('border-bottom-color', _v43),
          RaftDecl('border-left-color', _v43),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:border-transparent',
    1654,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [
          RaftDecl('border-top-color', _v7),
          RaftDecl('border-right-color', _v7),
          RaftDecl('border-bottom-color', _v7),
          RaftDecl('border-left-color', _v7),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:hover:bg-brutal-cyan/25',
    1662,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match', 'hover'],
        3000,
        [RaftDecl('background-color', _v985)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match', 'hover'],
        3000,
        [RaftDecl('background-color', _v986)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:hover:bg-info/10',
    1663,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match', 'hover'],
        3000,
        [RaftDecl('background-color', _v62)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match', 'hover'],
        3000,
        [RaftDecl('background-color', _v988)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:ring-[0.5px]',
    1659,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('--tw-ring-shadow', _v666), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:ring-info/50',
    1660,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('--tw-ring-color', _v62)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('--tw-ring-color', _v990)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:ring-inset',
    1661,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('--tw-ring-inset', CssKeyword('inset'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:shadow-none',
    1657,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:shadow-raft-md',
    1658,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('--tw-shadow', _v61), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-reaction-error-indicator]:bg-brutal-orange/30',
    1664,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-reaction-error-indicator'],
        2000,
        [RaftDecl('background-color', _v992)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=message-reaction-error-indicator'],
        2000,
        [RaftDecl('background-color', _v993)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-reaction-error-indicator]:bg-danger-soft',
    1665,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-reaction-error-indicator'],
        2000,
        [RaftDecl('background-color', _v326)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-reaction-error-indicator]:hover:bg-brutal-orange/30',
    1667,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-reaction-error-indicator', 'hover'],
        3000,
        [RaftDecl('background-color', _v992)],
      ),
      RaftLayer(
        'self',
        ['has:data-slot=message-reaction-error-indicator', 'hover'],
        3000,
        [RaftDecl('background-color', _v993)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-reaction-error-indicator]:text-danger',
    1666,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-reaction-error-indicator'],
        2000,
        [RaftDecl('color', _v137)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=sortable-composer-attachments-list]:block',
    1668,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=sortable-composer-attachments-list'],
        2000,
        [RaftDecl('display', CssKeyword('block'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=task-card-status-label]:hidden',
    1669,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=task-card-status-label'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=toast-actions]:gap-y-2',
    1673,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-actions'],
        2000,
        [RaftDecl('row-gap', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=toast-actions]:grid-cols-[minmax(0,1fr)]',
    1672,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-actions'],
        2000,
        [RaftDecl('grid-template-columns', _v106)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=toast-actions]:min-h-14',
    1670,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-actions'],
        2000,
        [RaftDecl('min-height', CssNum(56, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=toast-actions]:min-w-[18rem]',
    1671,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-actions'],
        2000,
        [RaftDecl('min-width', CssNum(288, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=toast-actions]:pl-3.5',
    1676,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-actions'],
        2000,
        [RaftDecl('padding-left', CssNum(14, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=toast-actions]:pr-3',
    1675,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-actions'],
        2000,
        [RaftDecl('padding-right', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=toast-actions]:py-3',
    1674,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-actions'],
        2000,
        [
          RaftDecl('padding-top', CssNum(12, 'px')),
          RaftDecl('padding-bottom', CssNum(12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=toast-close]:pr-3',
    1677,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-close'],
        2000,
        [RaftDecl('padding-right', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=toast-icon]:grid-cols-[auto_minmax(0,1fr)]',
    1678,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=toast-icon'],
        2000,
        [RaftDecl('grid-template-columns', _v109)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:[--mi-ct-color:color-mix(in_oklab,var(--color-black)_40%,transparent)]',
    1627,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('--mi-ct-color', _v56)],
      ),
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('--mi-ct-color', _v57)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:[--mi-ct-color:color-mix(in_oklab,var(--foreground-muted)_60%,transparent)]',
    1628,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('--mi-ct-color', _v22)],
      ),
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('--mi-ct-color', _v995)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:[--mi-toolbar-opacity:1]',
    1629,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('--mi-toolbar-opacity', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:[--mi-toolbar-pe:auto]',
    1630,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('--mi-toolbar-pe', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:bg-ink-2',
    1625,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('background-color', _v147)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:bg-layer-panel',
    1626,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('background-color', _v38)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:border-line-strong',
    1624,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [
          RaftDecl('border-top-color', _v43),
          RaftDecl('border-right-color', _v43),
          RaftDecl('border-bottom-color', _v43),
          RaftDecl('border-left-color', _v43),
        ],
      ),
    ],
  ),
  RaftUtility('hidden', 137, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('none'))]),
  ]),
  RaftUtility('hover:-translate-y-1/2', 1406, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('--tw-translate-y', CssNum(-50, '%')),
        RaftDecl('translate', CssSeq([_v71, _v72])),
      ],
    ),
  ]),
  RaftUtility('hover:-translate-y-px', 1407, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('--tw-translate-y', CssNum(-1, 'px')),
        RaftDecl('translate', CssSeq([_v71, _v72])),
      ],
    ),
  ]),
  RaftUtility(
    'hover:[&>svg]:text-foreground',
    3084,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', ['hover'], 2001, [RaftDecl('color', _v14)]),
    ],
  ),
  RaftUtility(
    'hover:[&_svg]:text-foreground-hover',
    2883,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', ['hover'], 2001, [RaftDecl('color', _v672)]),
    ],
  ),
  RaftUtility(
    'hover:[&_svg]:text-foreground-muted',
    2884,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', ['hover'], 2001, [RaftDecl('color', _v22)]),
    ],
  ),
  RaftUtility(
    'hover:[--mi-ct-color:color-mix(in_oklab,var(--color-black)_40%,transparent)]',
    1506,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('--mi-ct-color', _v56)]),
      RaftLayer('self', ['hover'], 2000, [RaftDecl('--mi-ct-color', _v57)]),
    ],
  ),
  RaftUtility(
    'hover:[--mi-ct-color:color-mix(in_oklab,var(--foreground-muted)_60%,transparent)]',
    1507,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('--mi-ct-color', _v22)]),
      RaftLayer('self', ['hover'], 2000, [RaftDecl('--mi-ct-color', _v995)]),
    ],
  ),
  RaftUtility(
    'hover:[--mi-toolbar-opacity:1]',
    1508,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('--mi-toolbar-opacity', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'hover:[--mi-toolbar-pe:auto]',
    1509,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('--mi-toolbar-pe', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'hover:[--toast-gradient-border-from:oklch(1_0_0/0.24)]',
    1510,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('--toast-gradient-border-from', _v98)],
      ),
    ],
  ),
  RaftUtility(
    'hover:[--toast-gradient-border-via:oklch(1_0_0/0.08)]',
    1511,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('--toast-gradient-border-via', _v597)],
      ),
    ],
  ),
  RaftUtility('hover:before:bg-black/20', 1517, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['hover'],
      2001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-color', _v418),
      ],
    ),
    RaftLayer(
      '::before',
      ['hover'],
      2001,
      [RaftDecl('background-color', _v419)],
    ),
  ]),
  RaftUtility('hover:before:bg-ink-20', 1518, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['hover'],
      2001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('background-color', _v375),
      ],
    ),
  ]),
  RaftUtility(
    'hover:bg-[color-mix(in_oklch,black_2%,white)]',
    1419,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v996)]),
    ],
  ),
  RaftUtility(
    'hover:bg-[color-mix(in_oklch,var(--ink)_1%,var(--layer-panel))]',
    1420,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v324)]),
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v758)]),
    ],
  ),
  RaftUtility(
    'hover:bg-[color-mix(in_oklch,var(--ink)_2%,var(--layer-card))]',
    1421,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v324)]),
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v997)]),
    ],
  ),
  RaftUtility(
    'hover:bg-[color-mix(in_oklch,var(--line-strong)_6%,var(--layer-panel))]',
    1422,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v43)]),
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v999)]),
    ],
  ),
  RaftUtility(
    'hover:bg-[oklch(0.31_0.006_106.42)]',
    1423,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('background-color', _v1000)],
      ),
    ],
  ),
  RaftUtility(
    'hover:bg-[oklch(0.965_0.019_358.59)]',
    1424,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v402)]),
    ],
  ),
  RaftUtility(
    'hover:bg-[oklch(0.966_0.022_224.02)]',
    1425,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v404)]),
    ],
  ),
  RaftUtility('hover:bg-accent-500', 1426, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v555)]),
  ]),
  RaftUtility('hover:bg-accent-hover', 1427, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1001)]),
  ]),
  RaftUtility('hover:bg-black/5', 1428, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v427)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v428)]),
  ]),
  RaftUtility('hover:bg-black/55', 1430, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1003)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1004)]),
  ]),
  RaftUtility('hover:bg-black/8', 1429, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v266)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v267)]),
  ]),
  RaftUtility('hover:bg-brutal-cyan', 1431, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('background-color', CssColor(0xFF27CCF3))],
    ),
  ]),
  RaftUtility('hover:bg-brutal-cyan/40', 1432, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1006)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1007)]),
  ]),
  RaftUtility('hover:bg-brutal-cyan/60', 1433, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1009)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1010)]),
  ]),
  RaftUtility('hover:bg-brutal-lime', 1434, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('background-color', CssColor(0xFFA9D877))],
    ),
  ]),
  RaftUtility('hover:bg-brutal-orange', 1435, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('background-color', CssColor(0xFFF8A16F))],
    ),
  ]),
  RaftUtility('hover:bg-brutal-pink', 1436, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('background-color', CssColor(0xFFFE7DA8))],
    ),
  ]),
  RaftUtility('hover:bg-brutal-pink/20', 1437, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v269)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v270)]),
  ]),
  RaftUtility('hover:bg-brutal-pink/60', 1438, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1012)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1013)]),
  ]),
  RaftUtility('hover:bg-brutal-red', 1439, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('background-color', CssColor(0xFFF97264))],
    ),
  ]),
  RaftUtility('hover:bg-brutal-stone', 1440, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('background-color', CssColor(0xFFC0B9B1))],
    ),
  ]),
  RaftUtility('hover:bg-brutal-stone/40', 1441, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1015)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1016)]),
  ]),
  RaftUtility('hover:bg-brutal-yellow', 1442, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('background-color', CssColor(0xFFFFD440))],
    ),
  ]),
  RaftUtility('hover:bg-brutal-yellow/30', 1443, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v454)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v455)]),
  ]),
  RaftUtility('hover:bg-danger-hover', 1444, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1017)]),
  ]),
  RaftUtility('hover:bg-danger-muted', 1445, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v217)]),
  ]),
  RaftUtility('hover:bg-danger-soft', 1446, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v326)]),
  ]),
  RaftUtility('hover:bg-fill-muted', 1447, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v222)]),
  ]),
  RaftUtility('hover:bg-fill-strong', 1448, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v115)]),
  ]),
  RaftUtility('hover:bg-fill-strong/80', 1449, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v115)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v117)]),
  ]),
  RaftUtility(
    'hover:bg-foreground-inverse/20',
    1450,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v227)]),
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('background-color', _v1019)],
      ),
    ],
  ),
  RaftUtility(
    'hover:bg-foreground-muted/55',
    1451,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v22)]),
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('background-color', _v1021)],
      ),
    ],
  ),
  RaftUtility(
    'hover:bg-foreground-strong/85',
    1452,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v0)]),
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('background-color', _v1023)],
      ),
    ],
  ),
  RaftUtility('hover:bg-info', 1453, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v62)]),
  ]),
  RaftUtility('hover:bg-info-hover', 1454, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1024)]),
  ]),
  RaftUtility('hover:bg-ink-10', 1457, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v12)]),
  ]),
  RaftUtility('hover:bg-ink-2', 1455, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v147)]),
  ]),
  RaftUtility('hover:bg-ink-4', 1456, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v390)]),
  ]),
  RaftUtility('hover:bg-layer-panel', 1458, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v38)]),
  ]),
  RaftUtility('hover:bg-primary-400', 1459, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v118)]),
  ]),
  RaftUtility('hover:bg-primary-400/30', 1460, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v616)]),
  ]),
  RaftUtility('hover:bg-primary-500', 1461, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v574)]),
  ]),
  RaftUtility('hover:bg-primary-hover', 1462, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v807)]),
  ]),
  RaftUtility('hover:bg-primary/30', 1463, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v616)]),
  ]),
  RaftUtility('hover:bg-primary/50', 1464, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1026)]),
  ]),
  RaftUtility('hover:bg-primary/80', 1465, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v118)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v502)]),
  ]),
  RaftUtility('hover:bg-secondary-400', 1466, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v230)]),
  ]),
  RaftUtility('hover:bg-success', 1467, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v63)]),
  ]),
  RaftUtility('hover:bg-transparent', 1468, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v7)]),
  ]),
  RaftUtility('hover:bg-warning', 1469, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v64)]),
  ]),
  RaftUtility('hover:bg-warning-hover', 1470, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1027)]),
  ]),
  RaftUtility('hover:bg-warning-soft', 1471, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v522)]),
  ]),
  RaftUtility('hover:bg-white', 1472, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v39)]),
  ]),
  RaftUtility('hover:bg-white/5', 1473, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1029)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1030)]),
  ]),
  RaftUtility('hover:bg-white/7.5', 1474, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1032)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v1033)]),
  ]),
  RaftUtility('hover:bg-white/85', 1475, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v535)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v536)]),
  ]),
  RaftUtility('hover:border-black', 1409, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v5),
        RaftDecl('border-right-color', _v5),
        RaftDecl('border-bottom-color', _v5),
        RaftDecl('border-left-color', _v5),
      ],
    ),
  ]),
  RaftUtility('hover:border-black/20', 1410, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v418),
        RaftDecl('border-right-color', _v418),
        RaftDecl('border-bottom-color', _v418),
        RaftDecl('border-left-color', _v418),
      ],
    ),
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v419),
        RaftDecl('border-right-color', _v419),
        RaftDecl('border-bottom-color', _v419),
        RaftDecl('border-left-color', _v419),
      ],
    ),
  ]),
  RaftUtility('hover:border-black/30', 1411, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v557),
        RaftDecl('border-right-color', _v557),
        RaftDecl('border-bottom-color', _v557),
        RaftDecl('border-left-color', _v557),
      ],
    ),
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v558),
        RaftDecl('border-right-color', _v558),
        RaftDecl('border-bottom-color', _v558),
        RaftDecl('border-left-color', _v558),
      ],
    ),
  ]),
  RaftUtility('hover:border-danger-hover', 1412, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v1017),
        RaftDecl('border-right-color', _v1017),
        RaftDecl('border-bottom-color', _v1017),
        RaftDecl('border-left-color', _v1017),
      ],
    ),
  ]),
  RaftUtility(
    'hover:border-line-field-hover',
    1413,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [
          RaftDecl('border-top-color', _v1034),
          RaftDecl('border-right-color', _v1034),
          RaftDecl('border-bottom-color', _v1034),
          RaftDecl('border-left-color', _v1034),
        ],
      ),
    ],
  ),
  RaftUtility('hover:border-line-muted', 1414, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v81),
        RaftDecl('border-right-color', _v81),
        RaftDecl('border-bottom-color', _v81),
        RaftDecl('border-left-color', _v81),
      ],
    ),
  ]),
  RaftUtility('hover:border-line-strong', 1415, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v43),
        RaftDecl('border-right-color', _v43),
        RaftDecl('border-bottom-color', _v43),
        RaftDecl('border-left-color', _v43),
      ],
    ),
  ]),
  RaftUtility('hover:border-transparent', 1416, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v7),
        RaftDecl('border-right-color', _v7),
        RaftDecl('border-bottom-color', _v7),
        RaftDecl('border-left-color', _v7),
      ],
    ),
  ]),
  RaftUtility('hover:border-white', 1417, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v39),
        RaftDecl('border-right-color', _v39),
        RaftDecl('border-bottom-color', _v39),
        RaftDecl('border-left-color', _v39),
      ],
    ),
  ]),
  RaftUtility('hover:border-white/60', 1418, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v1036),
        RaftDecl('border-right-color', _v1036),
        RaftDecl('border-bottom-color', _v1036),
        RaftDecl('border-left-color', _v1036),
      ],
    ),
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('border-top-color', _v1037),
        RaftDecl('border-right-color', _v1037),
        RaftDecl('border-bottom-color', _v1037),
        RaftDecl('border-left-color', _v1037),
      ],
    ),
  ]),
  RaftUtility('hover:brightness-100', 1504, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('--tw-brightness', _v983), RaftDecl('filter', _v662)],
    ),
  ]),
  RaftUtility('hover:brightness-90', 1502, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('--tw-brightness', _v925), RaftDecl('filter', _v662)],
    ),
  ]),
  RaftUtility('hover:brightness-95', 1503, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('--tw-brightness', _v1038), RaftDecl('filter', _v662)],
    ),
  ]),
  RaftUtility('hover:brightness-[0.96]', 1505, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('--tw-brightness', _v926), RaftDecl('filter', _v662)],
    ),
  ]),
  RaftUtility(
    'hover:data-checked:data-disabled:shadow-[0_1px_1px_-1px_oklch(0_0_0/0.02),0_0_0_1px_var(--line-muted)]',
    1916,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'data-disabled', 'hover'],
        4000,
        [
          RaftDecl('--tw-shadow', CssList([_v804, _v670])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'hover:data-checked:shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.2),0_1px_1px_-0.5px_color-mix(in_srgb,var(--primary-glow)_10%,transparent),0_2px_2px_-1px_color-mix(in_srgb,var(--primary-glow)_6%,transparent),0_0_0_1px_var(--primary-edge)]',
    1886,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v837), RaftDecl('box-shadow', _v20)],
      ),
      RaftLayer(
        'self',
        ['data-checked', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v846)],
      ),
    ],
  ),
  RaftUtility(
    'hover:data-checked:shadow-none',
    1887,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility(
    'hover:data-indeterminate:data-disabled:shadow-[0_1px_1px_-1px_oklch(0_0_0/0.02),0_0_0_1px_var(--line-muted)]',
    1958,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled', 'data-indeterminate', 'hover'],
        4000,
        [
          RaftDecl('--tw-shadow', CssList([_v804, _v670])),
          RaftDecl('box-shadow', _v20),
        ],
      ),
    ],
  ),
  RaftUtility(
    'hover:data-indeterminate:shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.2),0_1px_1px_-0.5px_color-mix(in_srgb,var(--primary-glow)_10%,transparent),0_2px_2px_-1px_color-mix(in_srgb,var(--primary-glow)_6%,transparent),0_0_0_1px_var(--primary-edge)]',
    1955,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v837), RaftDecl('box-shadow', _v20)],
      ),
      RaftLayer(
        'self',
        ['data-indeterminate', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v846)],
      ),
    ],
  ),
  RaftUtility(
    'hover:data-indeterminate:shadow-none',
    1956,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('hover:decoration-black', 1494, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('text-decoration-color', _v5)],
    ),
  ]),
  RaftUtility(
    'hover:decoration-brutal-pink',
    1495,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('text-decoration-color', CssColor(0xFFFE7DA8))],
      ),
    ],
  ),
  RaftUtility(
    'hover:decoration-primary-active',
    1496,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('text-decoration-color', _v1039)],
      ),
    ],
  ),
  RaftUtility(
    'hover:not-data-invalid:border-line-field-hover',
    1514,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:data-invalid'],
        3000,
        [
          RaftDecl('border-top-color', _v1034),
          RaftDecl('border-right-color', _v1034),
          RaftDecl('border-bottom-color', _v1034),
          RaftDecl('border-left-color', _v1034),
        ],
      ),
    ],
  ),
  RaftUtility('hover:opacity-100', 1497, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('opacity', CssNum(100, '%'))]),
  ]),
  RaftUtility(
    'hover:shadow-[3px_3px_0_0_black]',
    1498,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [RaftDecl('--tw-shadow', _v1040), RaftDecl('box-shadow', _v20)],
      ),
    ],
  ),
  RaftUtility('hover:shadow-none', 1499, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('--tw-shadow', _v15), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('hover:shadow-raft-md', 1500, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('--tw-shadow', _v61), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility('hover:shadow-raft-sm', 1501, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('--tw-shadow', _v278), RaftDecl('box-shadow', _v20)],
    ),
  ]),
  RaftUtility(
    'hover:text-[oklch(0.431_0.088_86.67)]',
    1476,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v1041)]),
    ],
  ),
  RaftUtility(
    'hover:text-[oklch(0.543_0.215_359.77)]',
    1477,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v1042)]),
    ],
  ),
  RaftUtility('hover:text-black', 1478, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v5)]),
  ]),
  RaftUtility('hover:text-black/70', 1479, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v154)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v155)]),
  ]),
  RaftUtility('hover:text-black/75', 1480, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v1044)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v1045)]),
  ]),
  RaftUtility('hover:text-brutal-pink', 1481, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('color', CssColor(0xFFFE7DA8))],
    ),
  ]),
  RaftUtility('hover:text-foreground', 1482, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v14)]),
  ]),
  RaftUtility('hover:text-foreground-hover', 1483, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v672)]),
  ]),
  RaftUtility(
    'hover:text-foreground-inverse',
    1484,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v227)]),
    ],
  ),
  RaftUtility('hover:text-foreground-muted', 1485, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v22)]),
  ]),
  RaftUtility(
    'hover:text-foreground-strong',
    1486,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v0)]),
    ],
  ),
  RaftUtility('hover:text-info-strong', 1487, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v228)]),
  ]),
  RaftUtility('hover:text-primary-active', 1488, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v1039)]),
  ]),
  RaftUtility('hover:text-warning', 1489, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v64)]),
  ]),
  RaftUtility('hover:text-white', 1490, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v39)]),
  ]),
  RaftUtility('hover:text-white/88', 1491, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v1047)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v1048)]),
  ]),
  RaftUtility('hover:text-white/90', 1492, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v796)]),
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v797)]),
  ]),
  RaftUtility('hover:translate-y-0', 1408, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [
        RaftDecl('--tw-translate-y', CssNum(0, 'px')),
        RaftDecl('translate', CssSeq([_v71, _v72])),
      ],
    ),
  ]),
  RaftUtility('hover:underline', 1493, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('text-decoration-line', CssKeyword('underline'))],
    ),
  ]),
  RaftUtility('image-transparency-bg', 508, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--checker-cell', _v1050),
      RaftDecl('background-color', _v1052),
      RaftDecl('background-image', _v1062),
      RaftDecl('background-position', _v1067),
      RaftDecl('background-size', _v1068),
    ]),
  ]),
  RaftUtility(
    'in-data-[toast-placement\$=right]:left-auto',
    1615,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-toast-placement\$=right'],
        1000,
        [RaftDecl('left', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[toast-placement\$=right]:mx-0',
    1616,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-toast-placement\$=right'],
        1000,
        [
          RaftDecl('margin-left', CssNum(0, 'px')),
          RaftDecl('margin-right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[toast-placement^=top]:[--toast-peek-dir:1]',
    1620,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-toast-placement^=top'],
        1000,
        [RaftDecl('--toast-peek-dir', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[toast-placement^=top]:[--toast-y:calc(var(--toast-offset-y)+(var(--toast-index)*var(--toast-gap))+var(--toast-swipe-movement-y))]',
    1621,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-toast-placement^=top'],
        1000,
        [RaftDecl('--toast-y', CssCalc(_v1070))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[toast-placement^=top]:before:bottom-full',
    1623,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['ancestor:data-toast-placement^=top'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('bottom', CssNum(100, '%')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[toast-placement^=top]:before:top-auto',
    1622,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['ancestor:data-toast-placement^=top'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssKeyword('auto')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[toast-placement^=top]:bottom-auto',
    1618,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-toast-placement^=top'],
        1000,
        [RaftDecl('bottom', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[toast-placement^=top]:origin-top',
    1619,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-toast-placement^=top'],
        1000,
        [RaftDecl('transform-origin', CssKeyword('top'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[toast-placement^=top]:top-0',
    1617,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-toast-placement^=top'],
        1000,
        [RaftDecl('top', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility('inline', 138, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('inline'))]),
  ]),
  RaftUtility('inline-block', 139, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', _v974)]),
  ]),
  RaftUtility('inline-flex', 140, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', _v60)]),
  ]),
  RaftUtility('inline-grid', 141, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', _v1071)]),
  ]),
  RaftUtility('inset-0', 11, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('top', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
      RaftDecl('bottom', CssNum(0, 'px')),
      RaftDecl('left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('inset-x-0', 12, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('left', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('inset-x-3', 13, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('left', CssNum(12, 'px')),
      RaftDecl('right', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('inset-y-0', 14, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('top', CssNum(0, 'px')),
      RaftDecl('bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('inset-y-3', 15, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('top', CssNum(12, 'px')),
      RaftDecl('bottom', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('invisible', 4, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('visibility', CssKeyword('hidden'))]),
  ]),
  RaftUtility('isolate', 62, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('isolation', CssKeyword('isolate'))]),
  ]),
  RaftUtility('italic', 942, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-style', CssKeyword('italic'))]),
  ]),
  RaftUtility('items-baseline', 365, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-items', CssKeyword('baseline')),
    ]),
  ]),
  RaftUtility('items-center', 366, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-items', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('items-end', 367, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-items', CssKeyword('flex-end')),
    ]),
  ]),
  RaftUtility('items-start', 368, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('align-items', _v141)]),
  ]),
  RaftUtility('items-stretch', 369, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-items', CssKeyword('stretch')),
    ]),
  ]),
  RaftUtility('justify-between', 370, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('justify-content', _v11)]),
  ]),
  RaftUtility('justify-center', 371, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('justify-content', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('justify-end', 372, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('justify-content', CssKeyword('flex-end')),
    ]),
  ]),
  RaftUtility('justify-self-end', 413, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('justify-self', CssKeyword('flex-end')),
    ]),
  ]),
  RaftUtility('justify-self-start', 414, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('justify-self', _v141)]),
  ]),
  RaftUtility('justify-self-stretch', 415, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('justify-self', CssKeyword('stretch')),
    ]),
  ]),
  RaftUtility('justify-start', 373, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('justify-content', _v141)]),
  ]),
  RaftUtility('last:[&>td]:border-b-0', 3112, RaftUtilityStatus.descendant, [
    RaftLayer(
      '& > td',
      ['last-child'],
      2001,
      [
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('last:border-b-0', 1398, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['last-child'],
      2000,
      [
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('last:border-r-0', 1397, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['last-child'],
      2000,
      [
        RaftDecl('border-right-style', _v31),
        RaftDecl('border-right-width', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('last:mb-0', 1396, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['last-child'],
      2000,
      [RaftDecl('margin-bottom', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('leading-10', 803, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(40, 'px')),
      RaftDecl('line-height', CssNum(40, 'px')),
    ]),
  ]),
  RaftUtility('leading-12', 804, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(48, 'px')),
      RaftDecl('line-height', CssNum(48, 'px')),
    ]),
  ]),
  RaftUtility('leading-14', 805, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(56, 'px')),
      RaftDecl('line-height', CssNum(56, 'px')),
    ]),
  ]),
  RaftUtility('leading-16', 806, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(64, 'px')),
      RaftDecl('line-height', CssNum(64, 'px')),
    ]),
  ]),
  RaftUtility('leading-3', 794, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(12, 'px')),
      RaftDecl('line-height', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('leading-3.5', 795, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(14, 'px')),
      RaftDecl('line-height', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('leading-4', 796, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(16, 'px')),
      RaftDecl('line-height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('leading-4.5', 797, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(18, 'px')),
      RaftDecl('line-height', CssNum(18, 'px')),
    ]),
  ]),
  RaftUtility('leading-5', 798, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(20, 'px')),
      RaftDecl('line-height', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('leading-5.25', 799, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(21, 'px')),
      RaftDecl('line-height', CssNum(21, 'px')),
    ]),
  ]),
  RaftUtility('leading-6', 800, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(24, 'px')),
      RaftDecl('line-height', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('leading-7', 801, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(28, 'px')),
      RaftDecl('line-height', CssNum(28, 'px')),
    ]),
  ]),
  RaftUtility('leading-8', 802, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(32, 'px')),
      RaftDecl('line-height', CssNum(32, 'px')),
    ]),
  ]),
  RaftUtility('leading-[1.2em]', 807, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1.2, 'em')),
      RaftDecl('line-height', CssNum(1.2, 'em')),
    ]),
  ]),
  RaftUtility('leading-[1.3em]', 808, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1.3, 'em')),
      RaftDecl('line-height', CssNum(1.3, 'em')),
    ]),
  ]),
  RaftUtility('leading-[1.4]', 809, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1.4)),
      RaftDecl('line-height', CssNum(1.4)),
    ]),
  ]),
  RaftUtility('leading-[inherit]', 810, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssKeyword('inherit')),
      RaftDecl('line-height', CssKeyword('inherit')),
    ]),
  ]),
  RaftUtility('leading-none', 811, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1)),
      RaftDecl('line-height', CssNum(1)),
    ]),
  ]),
  RaftUtility('leading-relaxed', 812, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1.625)),
      RaftDecl('line-height', CssNum(1.625)),
    ]),
  ]),
  RaftUtility('leading-snug', 813, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1.375)),
      RaftDecl('line-height', CssNum(1.375)),
    ]),
  ]),
  RaftUtility('leading-tight', 814, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1.25)),
      RaftDecl('line-height', CssNum(1.25)),
    ]),
  ]),
  RaftUtility('left-(--active-tab-left)', 55, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', _v1072)]),
  ]),
  RaftUtility('left-(--drawer-inset)', 56, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', _v165)]),
  ]),
  RaftUtility('left-0', 57, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', CssNum(0, 'px'))]),
  ]),
  RaftUtility('left-1.5', 58, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', CssNum(6, 'px'))]),
  ]),
  RaftUtility('left-1/2', 59, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', CssNum(50, '%'))]),
  ]),
  RaftUtility('left-6', 60, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', CssNum(24, 'px'))]),
  ]),
  RaftUtility(
    'left-[calc(var(--active-tab-left)+1px)]',
    61,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('left', CssCalc(_v1073))]),
    ],
  ),
  RaftUtility('line-clamp-2', 131, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
      RaftDecl('display', _v1074),
      RaftDecl('-webkit-box-orient', CssKeyword('vertical')),
      RaftDecl('-webkit-line-clamp', CssNum(2)),
    ]),
  ]),
  RaftUtility('line-clamp-3', 132, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
      RaftDecl('display', _v1074),
      RaftDecl('-webkit-box-orient', CssKeyword('vertical')),
      RaftDecl('-webkit-line-clamp', CssNum(3)),
    ]),
  ]),
  RaftUtility('list-decimal', 347, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('list-style-type', CssKeyword('decimal')),
    ]),
  ]),
  RaftUtility('list-disc', 348, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('list-style-type', CssKeyword('disc')),
    ]),
  ]),
  RaftUtility('m-0', 95, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(0, 'px')),
      RaftDecl('margin-right', CssNum(0, 'px')),
      RaftDecl('margin-bottom', CssNum(0, 'px')),
      RaftDecl('margin-left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    'mask-[radial-gradient(circle_at_96%_12%,black_0%,black_24%,oklch(0_0_0/0.82)_38%,oklch(0_0_0/0.38)_58%,transparent_74%)]',
    644,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('mask-image', _v253)]),
    ],
  ),
  RaftUtility('max-h-(--available-height)', 207, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', _v1075)]),
  ]),
  RaftUtility('max-h-32', 208, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(128, 'px'))]),
  ]),
  RaftUtility('max-h-40', 209, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(160, 'px'))]),
  ]),
  RaftUtility('max-h-48', 210, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(192, 'px'))]),
  ]),
  RaftUtility('max-h-64', 211, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(256, 'px'))]),
  ]),
  RaftUtility('max-h-[204px]', 214, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(204, 'px'))]),
  ]),
  RaftUtility('max-h-[80vh]', 212, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(80, 'vh'))]),
  ]),
  RaftUtility('max-h-[82vh]', 213, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(82, 'vh'))]),
  ]),
  RaftUtility('max-h-[calc(100dvh-2rem)]', 215, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssCalc(_v1076))]),
  ]),
  RaftUtility('max-lg:[&>*]:relative', 2954, RaftUtilityStatus.descendant, [
    RaftLayer(
      '& > *',
      ['width<1024'],
      1000,
      [RaftDecl('position', CssKeyword('relative'))],
    ),
  ]),
  RaftUtility('max-lg:[&>*]:z-10', 2955, RaftUtilityStatus.descendant, [
    RaftLayer('& > *', ['width<1024'], 1000, [RaftDecl('z-index', CssNum(10))]),
  ]),
  RaftUtility('max-lg:before:-bottom-3', 2377, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['width<1024'],
      1001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('bottom', CssNum(-12, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'max-lg:before:[-webkit-mask-image:linear-gradient(to_bottom,black_50%,transparent)]',
    2383,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['width<1024'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('-webkit-mask-image', _v1077),
        ],
      ),
    ],
  ),
  RaftUtility(
    'max-lg:before:[mask-image:linear-gradient(to_bottom,black_50%,transparent)]',
    2380,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['width<1024'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('mask-image', _v1077),
        ],
      ),
    ],
  ),
  RaftUtility('max-lg:before:absolute', 2374, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['width<1024'],
      1001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('position', CssKeyword('absolute')),
      ],
    ),
  ]),
  RaftUtility(
    'max-lg:before:backdrop-blur-sm',
    2381,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['width<1024'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-backdrop-blur', _v1078),
          RaftDecl('-webkit-backdrop-filter', _v340),
          RaftDecl('backdrop-filter', _v340),
        ],
      ),
    ],
  ),
  RaftUtility(
    'max-lg:before:bg-[linear-gradient(to_bottom,var(--layer-canvas-muted),transparent)]',
    2379,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['width<1024'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-image', _v1079),
        ],
      ),
    ],
  ),
  RaftUtility(
    'max-lg:before:content-[\'\']',
    2382,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['width<1024'],
        1001,
        [
          RaftDecl('--tw-content', CssString('')),
          RaftDecl('content', CssVar('--tw-content')),
        ],
      ),
    ],
  ),
  RaftUtility('max-lg:before:inset-x-0', 2375, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['width<1024'],
      1001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('left', CssNum(0, 'px')),
        RaftDecl('right', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'max-lg:before:pointer-events-none',
    2373,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['width<1024'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('pointer-events', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility('max-lg:before:top-0', 2376, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['width<1024'],
      1001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-lg:before:z-0', 2378, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['width<1024'],
      1001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('z-index', CssNum(0)),
      ],
    ),
  ]),
  RaftUtility('max-lg:gap-2', 2369, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<1024'],
      1000,
      [
        RaftDecl('row-gap', CssNum(8, 'px')),
        RaftDecl('column-gap', CssNum(8, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-lg:pl-5', 2372, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<1024'],
      1000,
      [RaftDecl('padding-left', CssNum(20, 'px'))],
    ),
  ]),
  RaftUtility('max-lg:pr-3.5', 2371, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<1024'],
      1000,
      [RaftDecl('padding-right', CssNum(14, 'px'))],
    ),
  ]),
  RaftUtility('max-lg:px-3.5', 2370, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<1024'],
      1000,
      [
        RaftDecl('padding-left', CssNum(14, 'px')),
        RaftDecl('padding-right', CssNum(14, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-lg:z-10', 2368, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['width<1024'], 1000, [RaftDecl('z-index', CssNum(10))]),
  ]),
  RaftUtility(
    'max-md:[&>[data-slot=panel-actions]]:gap-2.5',
    2970,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-actions]',
        ['width<768'],
        2000,
        [
          RaftDecl('row-gap', CssNum(10, 'px')),
          RaftDecl('column-gap', CssNum(10, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'max-md:[&>[data-slot=panel-header-icon]]:hidden',
    2971,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-header-icon]',
        ['width<768'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:[&>[data-slot=tabs-list]>[data-slot=tabs-indicator]]:h-px',
    2987,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=tabs-list] > [data-slot=tabs-indicator]',
        ['width<768'],
        3000,
        [RaftDecl('height', CssNum(1, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:[&>a+[data-slot=panel-header-content]]:col-start-2',
    3002,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > a + [data-slot=panel-header-content]',
        ['width<768'],
        2001,
        [RaftDecl('grid-column-start', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:[&>button+[data-slot=panel-header-content]]:col-start-2',
    3004,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > button + [data-slot=panel-header-content]',
        ['width<768'],
        2001,
        [RaftDecl('grid-column-start', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:[&_[data-slot=avatar][data-size=md]]:size-(--mi-avatar-narrow,1.75rem)',
    2801,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=avatar][data-size=md]',
        ['width<768'],
        3000,
        [RaftDecl('width', _v1080), RaftDecl('height', _v1080)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:[grid-column-start:var(--ph-icon-col,2)]',
    2390,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width<768'],
        1000,
        [RaftDecl('grid-column-start', _v1081)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:[grid-row-end:var(--ph-icon-row-end,auto)]',
    2395,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width<768'],
        1000,
        [RaftDecl('grid-row-end', _v1082)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:[grid-row-start:var(--ph-icon-row-start,1)]',
    2393,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width<768'],
        1000,
        [RaftDecl('grid-row-start', _v1083)],
      ),
    ],
  ),
  RaftUtility('max-md:before:hidden', 2440, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['width<768'],
      1001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('display', CssKeyword('none')),
      ],
    ),
  ]),
  RaftUtility(
    'max-md:bg-layer-canvas-muted',
    2419,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width<768'],
        1000,
        [RaftDecl('background-color', _v68)],
      ),
    ],
  ),
  RaftUtility('max-md:bg-primary-400', 2420, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('background-color', _v118)],
    ),
  ]),
  RaftUtility('max-md:bg-white', 2421, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('background-color', _v39)],
    ),
  ]),
  RaftUtility('max-md:border-b', 2417, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('border-bottom-style', _v31),
        RaftDecl('border-bottom-width', CssNum(1, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:border-line-muted', 2418, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('border-top-color', _v81),
        RaftDecl('border-right-color', _v81),
        RaftDecl('border-bottom-color', _v81),
        RaftDecl('border-left-color', _v81),
      ],
    ),
  ]),
  RaftUtility('max-md:col-start-1', 2391, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('grid-column-start', CssNum(1))],
    ),
  ]),
  RaftUtility('max-md:col-start-4', 2392, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('grid-column-start', CssNum(4))],
    ),
  ]),
  RaftUtility('max-md:flex', 2399, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('display', CssKeyword('flex'))],
    ),
  ]),
  RaftUtility('max-md:flex-col', 2407, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('flex-direction', CssKeyword('column'))],
    ),
  ]),
  RaftUtility('max-md:flex-col-reverse', 2408, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('flex-direction', _v1084)],
    ),
  ]),
  RaftUtility('max-md:flex-wrap', 2409, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('flex-wrap', CssKeyword('wrap'))],
    ),
  ]),
  RaftUtility('max-md:gap-0.5', 2412, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('row-gap', CssNum(2, 'px')),
        RaftDecl('column-gap', CssNum(2, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:gap-1', 2413, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('row-gap', CssNum(4, 'px')),
        RaftDecl('column-gap', CssNum(4, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:gap-1.5', 2414, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('row-gap', CssNum(6, 'px')),
        RaftDecl('column-gap', CssNum(6, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:gap-2', 2415, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('row-gap', CssNum(8, 'px')),
        RaftDecl('column-gap', CssNum(8, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:grid', 2400, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('display', CssKeyword('grid'))],
    ),
  ]),
  RaftUtility(
    'max-md:grid-cols-[auto_auto_minmax(0,1fr)_auto]',
    2406,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width<768'],
        1000,
        [RaftDecl('grid-template-columns', _v1085)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:h-[var(--shell-header-height,56px)]',
    2402,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['width<768'], 1000, [RaftDecl('height', _v965)]),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:[--ph-icon-col:1]',
    2448,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('--ph-icon-col', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:[--ph-meta-col:1]',
    2449,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('--ph-meta-col', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:[--ph-meta-end:span_2]',
    2450,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('--ph-meta-end', _v978)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:[--ph-text-col:2]',
    2451,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('--ph-text-col', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:col-span-2',
    2441,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('grid-column', _v73)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:col-start-2',
    2442,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('grid-column-start', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:gap-x-2',
    2446,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('column-gap', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:grid',
    2443,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('display', CssKeyword('grid'))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:grid-cols-[auto_minmax(0,1fr)]',
    2444,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('grid-template-columns', _v109)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:items-center',
    2445,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('align-items', CssKeyword('center'))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-header-icon]]:self-center',
    2447,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width<768'],
        2000,
        [RaftDecl('align-self', CssKeyword('center'))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-meta]]:[--ph-icon-row-end:span_2]',
    2452,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-meta', 'width<768'],
        2000,
        [RaftDecl('--ph-icon-row-end', _v978)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:has-[>[data-slot=panel-meta]]:[--ph-icon-row-start:span_2]',
    2453,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-meta', 'width<768'],
        2000,
        [RaftDecl('--ph-icon-row-start', _v978)],
      ),
    ],
  ),
  RaftUtility('max-md:hidden', 2401, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('max-md:items-center', 2410, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('align-items', CssKeyword('center'))],
    ),
  ]),
  RaftUtility('max-md:items-end', 2411, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('align-items', CssKeyword('flex-end'))],
    ),
  ]),
  RaftUtility('max-md:leading-tight', 2438, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('--tw-leading', CssNum(1.25)),
        RaftDecl('line-height', CssNum(1.25)),
      ],
    ),
  ]),
  RaftUtility('max-md:mb-1', 2398, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('margin-bottom', CssNum(4, 'px'))],
    ),
  ]),
  RaftUtility('max-md:min-w-0', 2404, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('min-width', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('max-md:mt-1', 2396, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('margin-top', CssNum(4, 'px'))],
    ),
  ]),
  RaftUtility('max-md:mt-1.5', 2397, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('margin-top', CssNum(6, 'px'))],
    ),
  ]),
  RaftUtility('max-md:opacity-100', 2439, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility('max-md:pb-1.5', 2433, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('padding-bottom', CssNum(6, 'px'))],
    ),
  ]),
  RaftUtility(
    'max-md:pb-[calc(env(safe-area-inset-bottom)+0.375rem)]',
    2434,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width<768'],
        1000,
        [RaftDecl('padding-bottom', CssCalc(_v1087))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:pb-[calc(env(safe-area-inset-bottom)+0.625rem)]',
    2435,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width<768'],
        1000,
        [RaftDecl('padding-bottom', CssCalc(_v1088))],
      ),
    ],
  ),
  RaftUtility('max-md:pl-5', 2436, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('padding-left', CssNum(20, 'px'))],
    ),
  ]),
  RaftUtility('max-md:pl-[44.5px]', 2437, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('padding-left', CssNum(44.5, 'px'))],
    ),
  ]),
  RaftUtility('max-md:pointer-events-auto', 2384, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('pointer-events', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility('max-md:pr-3.5', 2432, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('padding-right', CssNum(14, 'px'))],
    ),
  ]),
  RaftUtility('max-md:pt-0', 2428, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('padding-top', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('max-md:pt-1.5', 2429, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('padding-top', CssNum(6, 'px'))],
    ),
  ]),
  RaftUtility('max-md:pt-[13px]', 2430, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('padding-top', CssNum(13, 'px'))],
    ),
  ]),
  RaftUtility(
    'max-md:pt-[env(safe-area-inset-top,0px)]',
    2431,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['width<768'], 1000, [RaftDecl('padding-top', _v79)]),
    ],
  ),
  RaftUtility('max-md:px-1.5', 2422, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(6, 'px')),
        RaftDecl('padding-right', CssNum(6, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:px-2.5', 2423, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(10, 'px')),
        RaftDecl('padding-right', CssNum(10, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:px-3.5', 2424, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(14, 'px')),
        RaftDecl('padding-right', CssNum(14, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:px-4', 2425, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(16, 'px')),
        RaftDecl('padding-right', CssNum(16, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:px-6', 2426, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(24, 'px')),
        RaftDecl('padding-right', CssNum(24, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:py-2', 2427, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('padding-top', CssNum(8, 'px')),
        RaftDecl('padding-bottom', CssNum(8, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:row-start-1', 2394, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('grid-row-start', CssNum(1))],
    ),
  ]),
  RaftUtility('max-md:self-center', 2416, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('align-self', CssKeyword('center'))],
    ),
  ]),
  RaftUtility('max-md:static', 2385, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('position', CssKeyword('static'))],
    ),
  ]),
  RaftUtility('max-md:sticky', 2386, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('position', CssKeyword('sticky'))],
    ),
  ]),
  RaftUtility('max-md:top-0', 2387, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['width<768'], 1000, [RaftDecl('top', CssNum(0, 'px'))]),
  ]),
  RaftUtility('max-md:translate-y-0', 2405, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('--tw-translate-y', CssNum(0, 'px')),
        RaftDecl('translate', CssSeq([_v71, _v72])),
      ],
    ),
  ]),
  RaftUtility('max-md:w-8', 2403, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('width', CssNum(32, 'px'))],
    ),
  ]),
  RaftUtility('max-md:z-10', 2388, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['width<768'], 1000, [RaftDecl('z-index', CssNum(10))]),
  ]),
  RaftUtility('max-md:z-30', 2389, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['width<768'], 1000, [RaftDecl('z-index', CssNum(30))]),
  ]),
  RaftUtility('max-sm:gap-y-0.5', 2455, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<640'],
      1000,
      [RaftDecl('row-gap', CssNum(2, 'px'))],
    ),
  ]),
  RaftUtility('max-sm:grid-cols-1', 2454, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<640'],
      1000,
      [RaftDecl('grid-template-columns', _v938)],
    ),
  ]),
  RaftUtility(
    'max-w-(--si-title-max-w,none)',
    264,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('max-width', _v1089)]),
    ],
  ),
  RaftUtility('max-w-28', 265, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(112, 'px'))]),
  ]),
  RaftUtility('max-w-40', 266, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(160, 'px'))]),
  ]),
  RaftUtility('max-w-44', 267, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(176, 'px'))]),
  ]),
  RaftUtility('max-w-60', 268, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(240, 'px'))]),
  ]),
  RaftUtility('max-w-[256px]', 274, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(256, 'px'))]),
  ]),
  RaftUtility('max-w-[26rem]', 269, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(416, 'px'))]),
  ]),
  RaftUtility('max-w-[280px]', 275, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(280, 'px'))]),
  ]),
  RaftUtility('max-w-[32ch]', 270, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(32, 'ch'))]),
  ]),
  RaftUtility('max-w-[33%]', 271, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(33, '%'))]),
  ]),
  RaftUtility('max-w-[360px]', 276, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(360, 'px'))]),
  ]),
  RaftUtility('max-w-[408px]', 277, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(408, 'px'))]),
  ]),
  RaftUtility('max-w-[72ch]', 272, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(72, 'ch'))]),
  ]),
  RaftUtility('max-w-[86vw]', 273, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(86, 'vw'))]),
  ]),
  RaftUtility('max-w-[calc(100vw-48px)]', 278, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssCalc(_v1090))]),
  ]),
  RaftUtility(
    'max-w-[min(20rem,var(--available-width,20rem))]',
    279,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('max-width', _v1092)]),
    ],
  ),
  RaftUtility(
    'max-w-[min(24rem,var(--available-width,calc(100vw-2rem)))]',
    280,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('max-width', _v1095)]),
    ],
  ),
  RaftUtility('max-w-[min(34rem,100%)]', 281, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', _v1096)]),
  ]),
  RaftUtility(
    'max-w-[min(352px,calc(100vw-112px))]',
    282,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('max-width', _v1098)]),
    ],
  ),
  RaftUtility(
    'max-w-[min(448px,calc(100vw-112px))]',
    283,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('max-width', _v1099)]),
    ],
  ),
  RaftUtility('max-w-full', 284, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(100, '%'))]),
  ]),
  RaftUtility('max-w-lg', 285, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(512, 'px'))]),
  ]),
  RaftUtility('max-w-md', 286, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(448, 'px'))]),
  ]),
  RaftUtility('max-w-none', 287, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssKeyword('none'))]),
  ]),
  RaftUtility('max-w-sm', 288, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(384, 'px'))]),
  ]),
  RaftUtility('mb-0', 120, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(0, 'px'))]),
  ]),
  RaftUtility('mb-0.5', 121, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(2, 'px'))]),
  ]),
  RaftUtility('mb-1', 122, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(4, 'px'))]),
  ]),
  RaftUtility('mb-1.5', 123, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(6, 'px'))]),
  ]),
  RaftUtility('mb-2', 124, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(8, 'px'))]),
  ]),
  RaftUtility('mb-3', 125, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(12, 'px'))]),
  ]),
  RaftUtility('mb-4', 126, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(16, 'px'))]),
  ]),
  RaftUtility(
    'mb-[max(8px,env(safe-area-inset-bottom,0px))]',
    127,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', _v1100)]),
    ],
  ),
  RaftUtility(
    'md:[&>[data-panel-frame-header]]:pl-3',
    2960,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-panel-frame-header]',
        ['width>=768'],
        2000,
        [RaftDecl('padding-left', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:[&>[data-slot=panel-header-icon]]:bg-primary-400',
    2973,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-header-icon]',
        ['width>=768'],
        2000,
        [RaftDecl('background-color', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'md:[&>[data-slot=panel-header-icon]]:size-10',
    2972,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-header-icon]',
        ['width>=768'],
        2000,
        [
          RaftDecl('width', CssNum(40, 'px')),
          RaftDecl('height', CssNum(40, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:[&_[data-slot=input-group-control]]:py-1.5',
    2806,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=input-group-control]',
        ['width>=768'],
        2000,
        [
          RaftDecl('padding-top', CssNum(6, 'px')),
          RaftDecl('padding-bottom', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:[&_[data-slot=input-group]]:h-[34px]',
    2807,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=input-group]',
        ['width>=768'],
        2000,
        [RaftDecl('height', CssNum(34, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:[&_[data-slot=tabs-list]]:h-[34px]',
    2828,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=tabs-list]',
        ['width>=768'],
        2000,
        [RaftDecl('height', CssNum(34, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:[&_[data-slot=tabs-tab]]:h-8',
    2829,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=tabs-tab]',
        ['width>=768'],
        2000,
        [RaftDecl('height', CssNum(32, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:[&_[data-slot=tabs-tab]]:py-1.5',
    2830,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=tabs-tab]',
        ['width>=768'],
        2000,
        [
          RaftDecl('padding-top', CssNum(6, 'px')),
          RaftDecl('padding-bottom', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:[--sidebar-inset-end:18px]',
    2506,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width>=768'],
        1000,
        [RaftDecl('--sidebar-inset-end', CssNum(18, 'px'))],
      ),
    ],
  ),
  RaftUtility('md:[--sidebar-inset-x:26px]', 2507, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('--sidebar-inset-x', CssNum(26, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:[@media(max-height:600px)]:size-9',
    3130,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600', 'width>=768'],
        1000,
        [
          RaftDecl('width', CssNum(36, 'px')),
          RaftDecl('height', CssNum(36, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:[@media(max-height:600px)]:w-[50px]',
    3131,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600', 'width>=768'],
        1000,
        [RaftDecl('width', CssNum(50, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:[align-self:var(--ph-icon-self,auto)]',
    2488,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['width>=768'], 1000, [RaftDecl('align-self', _v1101)]),
    ],
  ),
  RaftUtility('md:absolute', 2465, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('position', CssKeyword('absolute'))],
    ),
  ]),
  RaftUtility('md:basis-0', 2476, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('flex-basis', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('md:bg-brutal-cream', 2491, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('background-color', CssColor(0xFFFFFAEF))],
    ),
  ]),
  RaftUtility('md:bottom-0', 2467, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('bottom', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('md:flex', 2469, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('display', CssKeyword('flex'))],
    ),
  ]),
  RaftUtility('md:flex-1', 2474, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['width>=768'], 1000, [RaftDecl('flex', CssNum(1))]),
  ]),
  RaftUtility('md:flex-col', 2478, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('flex-direction', CssKeyword('column'))],
    ),
  ]),
  RaftUtility('md:flex-nowrap', 2480, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('flex-wrap', CssKeyword('nowrap'))],
    ),
  ]),
  RaftUtility('md:flex-row', 2479, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('flex-direction', CssKeyword('row'))],
    ),
  ]),
  RaftUtility('md:flex-wrap', 2481, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('flex-wrap', CssKeyword('wrap'))],
    ),
  ]),
  RaftUtility('md:focus-within:opacity-100', 2514, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-within', 'width>=768'],
      2000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility(
    'md:focus-within:pointer-events-auto',
    2513,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-within', 'width>=768'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility('md:gap-0', 2485, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('row-gap', CssNum(0, 'px')),
        RaftDecl('column-gap', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:gap-2', 2486, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('row-gap', CssNum(8, 'px')),
        RaftDecl('column-gap', CssNum(8, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:gap-3', 2487, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('row-gap', CssNum(12, 'px')),
        RaftDecl('column-gap', CssNum(12, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:grid-cols-3', 2477, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('grid-template-columns', _v1102)],
    ),
  ]),
  RaftUtility(
    'md:group-hover/section-header:opacity-100',
    2509,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/section-header:hover', 'width>=768'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'md:group-hover/section-header:pointer-events-auto',
    2508,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/section-header:hover', 'width>=768'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility('md:h-11', 2470, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('height', CssNum(44, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:has-[>[data-slot=panel-header-icon]]:[--ph-icon-self:center]',
    2517,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-header-icon', 'width>=768'],
        2000,
        [RaftDecl('--ph-icon-self', CssKeyword('center'))],
      ),
    ],
  ),
  RaftUtility(
    'md:has-[>[data-slot=panel-meta]]:items-baseline',
    2518,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=panel-meta', 'width>=768'],
        2000,
        [RaftDecl('align-items', CssKeyword('baseline'))],
      ),
    ],
  ),
  RaftUtility(
    'md:has-[>[data-slot=sidebar-live-activity]_[data-slot=live-agent-activity-bar]]:[--sidebar-content-bottom:52px]',
    2519,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:>data-slot=sidebar-live-activity data-slot=live-agent-activity-bar',
          'width>=768',
        ],
        3000,
        [RaftDecl('--sidebar-content-bottom', CssNum(52, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:has-[>[data-slot=sidebar-live-activity]_[data-slot=live-agent-activity-bar]]:[--sidebar-content-bottom:68px]',
    2520,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:>data-slot=sidebar-live-activity data-slot=live-agent-activity-bar',
          'width>=768',
        ],
        3000,
        [RaftDecl('--sidebar-content-bottom', CssNum(68, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:has-[[data-popup-open]]:opacity-100',
    2516,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open', 'width>=768'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'md:has-[[data-popup-open]]:pointer-events-auto',
    2515,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open', 'width>=768'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility('md:inset-x-0', 2466, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('left', CssNum(0, 'px')), RaftDecl('right', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('md:items-center', 2482, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('align-items', CssKeyword('center'))],
    ),
  ]),
  RaftUtility('md:items-stretch', 2483, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('align-items', CssKeyword('stretch'))],
    ),
  ]),
  RaftUtility('md:justify-between', 2484, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('justify-content', _v11)],
    ),
  ]),
  RaftUtility('md:max-w-[448px]', 2471, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('max-width', CssNum(448, 'px'))],
    ),
  ]),
  RaftUtility('md:max-w-full', 2472, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('max-width', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility('md:max-w-md', 2473, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('max-width', CssNum(448, 'px'))],
    ),
  ]),
  RaftUtility('md:mr-auto', 2468, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('margin-right', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility('md:overflow-hidden', 2489, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('overflow-x', CssKeyword('hidden')),
        RaftDecl('overflow-y', CssKeyword('hidden')),
      ],
    ),
  ]),
  RaftUtility('md:pb-3', 2502, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('padding-bottom', CssNum(12, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:pb-[var(--panel-footer-clearance)]',
    2503,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width>=768'],
        1000,
        [RaftDecl('padding-bottom', _v1103)],
      ),
    ],
  ),
  RaftUtility('md:pl-5', 2504, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('padding-left', CssNum(20, 'px'))],
    ),
  ]),
  RaftUtility('md:pr-5', 2500, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('padding-right', CssNum(20, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:pr-[var(--sidebar-inset-end,var(--sidebar-inset-x,26px))]',
    2501,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width>=768'],
        1000,
        [RaftDecl('padding-right', _v1105)],
      ),
    ],
  ),
  RaftUtility('md:pt-0', 2499, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('padding-top', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('md:px-5', 2492, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(20, 'px')),
        RaftDecl('padding-right', CssNum(20, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:px-6', 2493, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(24, 'px')),
        RaftDecl('padding-right', CssNum(24, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:px-7', 2494, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(28, 'px')),
        RaftDecl('padding-right', CssNum(28, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:py-0', 2495, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('padding-top', CssNum(0, 'px')),
        RaftDecl('padding-bottom', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:py-1', 2496, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('padding-top', CssNum(4, 'px')),
        RaftDecl('padding-bottom', CssNum(4, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:py-1.5', 2497, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('padding-top', CssNum(6, 'px')),
        RaftDecl('padding-bottom', CssNum(6, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:py-3', 2498, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('padding-top', CssNum(12, 'px')),
        RaftDecl('padding-bottom', CssNum(12, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:rounded-xl', 2490, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('border-top-left-radius', CssNum(12, 'px')),
        RaftDecl('border-top-right-radius', CssNum(12, 'px')),
        RaftDecl('border-bottom-right-radius', CssNum(12, 'px')),
        RaftDecl('border-bottom-left-radius', CssNum(12, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:shrink-0', 2475, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('flex-shrink', CssNum(0))],
    ),
  ]),
  RaftUtility('md:text-sm', 2505, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('font-size', CssNum(14, 'px')), RaftDecl('line-height', _v949)],
    ),
  ]),
  RaftUtility(
    'min-h-(--card-title-line-height)',
    216,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('min-height', _v1106)]),
    ],
  ),
  RaftUtility(
    'min-h-(--shell-header-height,56px)',
    217,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('min-height', _v965)]),
    ],
  ),
  RaftUtility('min-h-0', 218, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(0, 'px'))]),
  ]),
  RaftUtility('min-h-11', 223, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(44, 'px'))]),
  ]),
  RaftUtility('min-h-16', 224, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(64, 'px'))]),
  ]),
  RaftUtility('min-h-24', 225, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(96, 'px'))]),
  ]),
  RaftUtility('min-h-5', 219, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(20, 'px'))]),
  ]),
  RaftUtility('min-h-64', 226, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(256, 'px'))]),
  ]),
  RaftUtility('min-h-7', 220, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(28, 'px'))]),
  ]),
  RaftUtility('min-h-8', 221, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(32, 'px'))]),
  ]),
  RaftUtility('min-h-9', 222, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(36, 'px'))]),
  ]),
  RaftUtility('min-h-[3rem]', 227, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(48, 'px'))]),
  ]),
  RaftUtility('min-h-[512px]', 228, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(512, 'px'))]),
  ]),
  RaftUtility('min-h-dvh', 229, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(100, 'dvh'))]),
  ]),
  RaftUtility('min-h-full', 230, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(100, '%'))]),
  ]),
  RaftUtility('min-w-(--anchor-width)', 289, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', _v1107)]),
  ]),
  RaftUtility('min-w-0', 290, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(0, 'px'))]),
  ]),
  RaftUtility('min-w-36', 296, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(144, 'px'))]),
  ]),
  RaftUtility('min-w-4', 291, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(16, 'px'))]),
  ]),
  RaftUtility('min-w-4.5', 292, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(18, 'px'))]),
  ]),
  RaftUtility('min-w-44', 297, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(176, 'px'))]),
  ]),
  RaftUtility('min-w-48', 298, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(192, 'px'))]),
  ]),
  RaftUtility('min-w-5', 293, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(20, 'px'))]),
  ]),
  RaftUtility('min-w-8', 294, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(32, 'px'))]),
  ]),
  RaftUtility('min-w-9', 295, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(36, 'px'))]),
  ]),
  RaftUtility('min-w-[220px]', 299, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(220, 'px'))]),
  ]),
  RaftUtility(
    'min-w-[max(var(--anchor-width),220px)]',
    300,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('min-width', _v1108)]),
    ],
  ),
  RaftUtility('ml-auto', 130, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-left', CssKeyword('auto'))]),
  ]),
  RaftUtility(
    'motion-reduce:**:data-[slot=copyable-code-icon]:transition-none',
    2367,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="copyable-code-icon"]',
        ['motion-reduce'],
        2000,
        [RaftDecl('transition-property', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'motion-reduce:active:scale-100',
    2366,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'motion-reduce'],
        2000,
        [
          RaftDecl('--tw-scale-x', CssNum(100, '%')),
          RaftDecl('--tw-scale-y', CssNum(100, '%')),
          RaftDecl('--tw-scale-z', CssNum(100, '%')),
          RaftDecl('scale', _v277),
        ],
      ),
    ],
  ),
  RaftUtility('motion-reduce:animate-none', 2364, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['motion-reduce'],
      1000,
      [RaftDecl('animation', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('motion-reduce:rotate-0', 2362, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['motion-reduce'],
      1000,
      [RaftDecl('rotate', CssNum(0, 'deg'))],
    ),
  ]),
  RaftUtility('motion-reduce:scale-100', 2360, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['motion-reduce'],
      1000,
      [
        RaftDecl('--tw-scale-x', CssNum(100, '%')),
        RaftDecl('--tw-scale-y', CssNum(100, '%')),
        RaftDecl('--tw-scale-z', CssNum(100, '%')),
        RaftDecl('scale', _v277),
      ],
    ),
  ]),
  RaftUtility('motion-reduce:scale-x-100', 2361, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['motion-reduce'],
      1000,
      [RaftDecl('--tw-scale-x', CssNum(100, '%')), RaftDecl('scale', _v277)],
    ),
  ]),
  RaftUtility(
    'motion-reduce:transform-none',
    2363,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['motion-reduce'],
        1000,
        [RaftDecl('transform', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'motion-reduce:transition-none',
    2365,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['motion-reduce'],
        1000,
        [RaftDecl('transition-property', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility('mr-1', 118, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssNum(4, 'px'))]),
  ]),
  RaftUtility('mr-1.5', 119, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssNum(6, 'px'))]),
  ]),
  RaftUtility('mt-0', 106, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(0, 'px'))]),
  ]),
  RaftUtility('mt-0.5', 107, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(2, 'px'))]),
  ]),
  RaftUtility('mt-1', 108, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(4, 'px'))]),
  ]),
  RaftUtility('mt-1.5', 109, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(6, 'px'))]),
  ]),
  RaftUtility('mt-2', 110, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(8, 'px'))]),
  ]),
  RaftUtility('mt-2.5', 111, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(10, 'px'))]),
  ]),
  RaftUtility('mt-3', 112, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(12, 'px'))]),
  ]),
  RaftUtility('mt-4', 113, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(16, 'px'))]),
  ]),
  RaftUtility('mt-5', 114, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(20, 'px'))]),
  ]),
  RaftUtility('mt-auto', 115, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssKeyword('auto'))]),
  ]),
  RaftUtility('mx-auto', 99, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-left', CssKeyword('auto')),
      RaftDecl('margin-right', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('my-1', 100, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(4, 'px')),
      RaftDecl('margin-bottom', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('my-2', 101, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(8, 'px')),
      RaftDecl('margin-bottom', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('my-auto', 102, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssKeyword('auto')),
      RaftDecl('margin-bottom', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('no-underline', 946, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-decoration-line', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('normal-case', 940, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-transform', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('normal-nums', 945, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-variant-numeric', CssKeyword('normal')),
    ]),
  ]),
  RaftUtility(
    'not-data-disabled:active:scale-[0.96]',
    1595,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'not:data-disabled'],
        3000,
        [RaftDecl('scale', CssNum(0.96))],
      ),
    ],
  ),
  RaftUtility(
    'not-data-disabled:cursor-pointer',
    1181,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['not:data-disabled'],
        2000,
        [RaftDecl('cursor', CssKeyword('pointer'))],
      ),
    ],
  ),
  RaftUtility(
    'not-data-disabled:hover:bg-foreground-strong/16',
    1512,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:data-disabled'],
        3000,
        [RaftDecl('background-color', _v0)],
      ),
      RaftLayer(
        'self',
        ['hover', 'not:data-disabled'],
        3000,
        [RaftDecl('background-color', _v1110)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-disabled:hover:bg-primary-400/30',
    1513,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:data-disabled'],
        3000,
        [RaftDecl('background-color', _v118)],
      ),
      RaftLayer(
        'self',
        ['hover', 'not:data-disabled'],
        3000,
        [RaftDecl('background-color', _v616)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-pressed:hover:bg-[color-mix(in_oklch,var(--fill-muted)_55%,var(--layer-panel))]',
    1515,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:data-pressed'],
        3000,
        [RaftDecl('background-color', _v222)],
      ),
      RaftLayer(
        'self',
        ['hover', 'not:data-pressed'],
        3000,
        [RaftDecl('background-color', _v907)],
      ),
    ],
  ),
  RaftUtility('not-italic', 943, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-style', CssKeyword('normal'))]),
  ]),
  RaftUtility('not-last:border-ink-6', 1180, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['not:last-child'],
      2000,
      [
        RaftDecl('border-top-color', _v275),
        RaftDecl('border-right-color', _v275),
        RaftDecl('border-bottom-color', _v275),
        RaftDecl('border-left-color', _v275),
      ],
    ),
  ]),
  RaftUtility('not-last:border-r', 1179, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['not:last-child'],
      2000,
      [
        RaftDecl('border-right-style', _v31),
        RaftDecl('border-right-width', CssNum(1, 'px')),
      ],
    ),
  ]),
  RaftUtility('object-contain', 648, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('object-fit', CssKeyword('contain')),
    ]),
  ]),
  RaftUtility('object-cover', 649, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('object-fit', CssKeyword('cover'))]),
  ]),
  RaftUtility('only:col-auto', 1399, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['only-child'],
      2000,
      [RaftDecl('grid-column', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility('only:row-auto', 1400, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['only-child'],
      2000,
      [RaftDecl('grid-row', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility(
    'opacity-(--mi-toolbar-opacity,0)',
    956,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('opacity', _v1111)]),
    ],
  ),
  RaftUtility('opacity-0', 957, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(0, '%'))]),
  ]),
  RaftUtility('opacity-100', 963, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(100, '%'))]),
  ]),
  RaftUtility('opacity-50', 958, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(50, '%'))]),
  ]),
  RaftUtility('opacity-60', 959, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(60, '%'))]),
  ]),
  RaftUtility('opacity-70', 960, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(70, '%'))]),
  ]),
  RaftUtility('opacity-80', 961, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(80, '%'))]),
  ]),
  RaftUtility('opacity-90', 962, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(90, '%'))]),
  ]),
  RaftUtility(
    'opacity-[max(var(--drawer-overlay-min-opacity,0),calc(1-var(--drawer-swipe-progress)))]',
    964,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('opacity', _v1114)]),
    ],
  ),
  RaftUtility('order-1', 74, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('order', CssNum(1))]),
  ]),
  RaftUtility('order-2', 75, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('order', CssNum(2))]),
  ]),
  RaftUtility('order-first', 76, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('order', CssNum(-9999))]),
  ]),
  RaftUtility('order-last', 77, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('order', CssNum(9999))]),
  ]),
  RaftUtility(
    'origin-(--drawer-transform-origin)',
    309,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('transform-origin', _v1115)]),
    ],
  ),
  RaftUtility('origin-(--transform-origin)', 310, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('transform-origin', _v1116)]),
  ]),
  RaftUtility('origin-bottom', 311, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transform-origin', CssKeyword('bottom')),
    ]),
  ]),
  RaftUtility('origin-center', 312, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transform-origin', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('origin-left', 313, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('transform-origin', CssNum(0))]),
  ]),
  RaftUtility('outline', 1007, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('outline-style', _v69),
      RaftDecl('outline-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('outline-1', 1008, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('outline-style', _v69),
      RaftDecl('outline-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('outline-2', 1009, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('outline-style', _v69),
      RaftDecl('outline-width', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('outline-[1px]', 1010, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('outline-style', _v69),
      RaftDecl('outline-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('outline-[oklch(0.32_0_0)]', 1013, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('outline-color', _v1117)]),
  ]),
  RaftUtility('outline-layer-panel', 1014, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('outline-color', _v38)]),
  ]),
  RaftUtility('outline-none', 1067, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-outline-style', CssKeyword('none')),
      RaftDecl('outline-style', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('outline-offset-2', 1012, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('outline-offset', CssNum(2, 'px'))]),
  ]),
  RaftUtility('outline-solid', 1068, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-outline-style', CssKeyword('solid')),
      RaftDecl('outline-style', CssKeyword('solid')),
    ]),
  ]),
  RaftUtility('outline-transparent', 1015, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('outline-color', _v7)]),
  ]),
  RaftUtility('outline-white', 1016, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('outline-color', _v39)]),
  ]),
  RaftUtility('overflow-auto', 417, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('auto')),
      RaftDecl('overflow-y', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('overflow-clip', 418, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('clip')),
      RaftDecl('overflow-y', CssKeyword('clip')),
    ]),
  ]),
  RaftUtility('overflow-hidden', 419, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
    ]),
  ]),
  RaftUtility('overflow-visible', 420, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('visible')),
      RaftDecl('overflow-y', CssKeyword('visible')),
    ]),
  ]),
  RaftUtility('overflow-x-auto', 421, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('overflow-x', CssKeyword('auto'))]),
  ]),
  RaftUtility('overflow-x-hidden', 422, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('overflow-x', CssKeyword('hidden'))]),
  ]),
  RaftUtility('overflow-x-visible', 423, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('visible')),
    ]),
  ]),
  RaftUtility('overflow-y-auto', 424, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('overflow-y', CssKeyword('auto'))]),
  ]),
  RaftUtility('overflow-y-hidden', 425, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('overflow-y', CssKeyword('hidden'))]),
  ]),
  RaftUtility('overflow-y-visible', 426, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-y', CssKeyword('visible')),
    ]),
  ]),
  RaftUtility('overscroll-contain', 427, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overscroll-behavior', CssKeyword('contain')),
    ]),
  ]),
  RaftUtility('overscroll-none', 428, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overscroll-behavior', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('overscroll-x-contain', 429, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overscroll-behavior-x', CssKeyword('contain')),
    ]),
  ]),
  RaftUtility('p-0', 650, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(0, 'px')),
      RaftDecl('padding-right', CssNum(0, 'px')),
      RaftDecl('padding-bottom', CssNum(0, 'px')),
      RaftDecl('padding-left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('p-0.5', 651, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(2, 'px')),
      RaftDecl('padding-right', CssNum(2, 'px')),
      RaftDecl('padding-bottom', CssNum(2, 'px')),
      RaftDecl('padding-left', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('p-1', 652, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(4, 'px')),
      RaftDecl('padding-right', CssNum(4, 'px')),
      RaftDecl('padding-bottom', CssNum(4, 'px')),
      RaftDecl('padding-left', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('p-1.5', 653, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(6, 'px')),
      RaftDecl('padding-right', CssNum(6, 'px')),
      RaftDecl('padding-bottom', CssNum(6, 'px')),
      RaftDecl('padding-left', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('p-2', 654, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(8, 'px')),
      RaftDecl('padding-right', CssNum(8, 'px')),
      RaftDecl('padding-bottom', CssNum(8, 'px')),
      RaftDecl('padding-left', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('p-3', 655, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(12, 'px')),
      RaftDecl('padding-right', CssNum(12, 'px')),
      RaftDecl('padding-bottom', CssNum(12, 'px')),
      RaftDecl('padding-left', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('p-4', 656, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(16, 'px')),
      RaftDecl('padding-right', CssNum(16, 'px')),
      RaftDecl('padding-bottom', CssNum(16, 'px')),
      RaftDecl('padding-left', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('p-5', 657, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(20, 'px')),
      RaftDecl('padding-right', CssNum(20, 'px')),
      RaftDecl('padding-bottom', CssNum(20, 'px')),
      RaftDecl('padding-left', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('p-[2px]', 658, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(2, 'px')),
      RaftDecl('padding-right', CssNum(2, 'px')),
      RaftDecl('padding-bottom', CssNum(2, 'px')),
      RaftDecl('padding-left', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('p-[7px]', 659, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(7, 'px')),
      RaftDecl('padding-right', CssNum(7, 'px')),
      RaftDecl('padding-bottom', CssNum(7, 'px')),
      RaftDecl('padding-left', CssNum(7, 'px')),
    ]),
  ]),
  RaftUtility('p-px', 660, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(1, 'px')),
      RaftDecl('padding-right', CssNum(1, 'px')),
      RaftDecl('padding-bottom', CssNum(1, 'px')),
      RaftDecl('padding-left', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility(
    'pb-(--sidebar-content-bottom,12px)',
    726,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v1118)]),
    ],
  ),
  RaftUtility('pb-0', 727, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(0, 'px'))]),
  ]),
  RaftUtility('pb-0.5', 728, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(2, 'px'))]),
  ]),
  RaftUtility('pb-1', 729, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(4, 'px'))]),
  ]),
  RaftUtility('pb-1.5', 730, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(6, 'px'))]),
  ]),
  RaftUtility('pb-2', 731, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(8, 'px'))]),
  ]),
  RaftUtility('pb-2.5', 732, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(10, 'px'))]),
  ]),
  RaftUtility('pb-3', 733, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(12, 'px'))]),
  ]),
  RaftUtility('pb-3.5', 734, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(14, 'px'))]),
  ]),
  RaftUtility('pb-6', 735, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(24, 'px'))]),
  ]),
  RaftUtility('pb-7', 736, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(28, 'px'))]),
  ]),
  RaftUtility(
    'pb-[calc(1rem+env(safe-area-inset-bottom,0px))]',
    737,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('padding-bottom', CssCalc(_v1119)),
      ]),
    ],
  ),
  RaftUtility(
    'pb-[calc(env(safe-area-inset-bottom)+0.75rem)]',
    738,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('padding-bottom', CssCalc(_v1120)),
      ]),
    ],
  ),
  RaftUtility(
    'pb-[env(safe-area-inset-bottom,0px)]',
    739,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v171)]),
    ],
  ),
  RaftUtility(
    'pb-[max(0.625rem,env(safe-area-inset-bottom,0px))]',
    741,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v1121)]),
    ],
  ),
  RaftUtility(
    'pb-[max(0.75rem,env(safe-area-inset-bottom,0px))]',
    740,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v172)]),
    ],
  ),
  RaftUtility(
    'pb-[min(env(safe-area-inset-bottom,0px),34px)]',
    742,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v1122)]),
    ],
  ),
  RaftUtility('pe-1.5', 692, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(6, 'px'))]),
  ]),
  RaftUtility('pl-0.5', 743, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(2, 'px'))]),
  ]),
  RaftUtility('pl-1', 744, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(4, 'px'))]),
  ]),
  RaftUtility('pl-1.5', 745, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(6, 'px'))]),
  ]),
  RaftUtility('pl-2', 746, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(8, 'px'))]),
  ]),
  RaftUtility('pl-2.5', 747, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(10, 'px'))]),
  ]),
  RaftUtility('pl-3', 748, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(12, 'px'))]),
  ]),
  RaftUtility('pl-5', 749, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(20, 'px'))]),
  ]),
  RaftUtility('pl-[18px]', 750, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(18, 'px'))]),
  ]),
  RaftUtility('pl-[26px]', 751, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(26, 'px'))]),
  ]),
  RaftUtility('pl-[52.5px]', 752, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(52.5, 'px'))]),
  ]),
  RaftUtility(
    'pl-[calc(16px+env(safe-area-inset-left,0px))]',
    753,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssCalc(_v1125))]),
    ],
  ),
  RaftUtility(
    'pl-[calc(env(safe-area-inset-left,0px)+--spacing(4))]',
    754,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssCalc(_v1126))]),
    ],
  ),
  RaftUtility('placeholder:duration-200', 1320, RaftUtilityStatus.resolved, [
    RaftLayer('::placeholder', [], 1001, [
      RaftDecl('--tw-duration', CssNum(200, 'ms')),
      RaftDecl('transition-duration', CssNum(200, 'ms')),
    ]),
  ]),
  RaftUtility('placeholder:ease-out', 1321, RaftUtilityStatus.resolved, [
    RaftLayer('::placeholder', [], 1001, [
      RaftDecl('--tw-ease', _v146),
      RaftDecl('transition-timing-function', _v146),
    ]),
  ]),
  RaftUtility('placeholder:text-black/35', 1315, RaftUtilityStatus.resolved, [
    RaftLayer('::placeholder', [], 1001, [RaftDecl('color', _v424)]),
    RaftLayer('::placeholder', [], 1001, [RaftDecl('color', _v425)]),
  ]),
  RaftUtility(
    'placeholder:text-foreground-placeholder',
    1316,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::placeholder', [], 1001, [RaftDecl('color', _v58)]),
    ],
  ),
  RaftUtility(
    'placeholder:text-foreground-placeholder/70',
    1317,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::placeholder', [], 1001, [RaftDecl('color', _v58)]),
      RaftLayer('::placeholder', [], 1001, [RaftDecl('color', _v1128)]),
    ],
  ),
  RaftUtility(
    'placeholder:text-foreground-strong/40',
    1318,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::placeholder', [], 1001, [RaftDecl('color', _v0)]),
      RaftLayer('::placeholder', [], 1001, [RaftDecl('color', _v750)]),
    ],
  ),
  RaftUtility('placeholder:transition', 1319, RaftUtilityStatus.resolved, [
    RaftLayer('::placeholder', [], 1001, [
      RaftDecl('transition-property', _v1133),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('pointer-events-auto', 2, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('pointer-events', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('pointer-events-none', 3, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('pointer-events', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('pr-(--ig-control-pr,0.75rem)', 711, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', _v1134)]),
  ]),
  RaftUtility('pr-(--mi-hdr-pr,6rem)', 712, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', _v1135)]),
  ]),
  RaftUtility(
    'pr-(--sidebar-row-inset-x,6px)',
    713,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-right', _v82)]),
    ],
  ),
  RaftUtility('pr-(--ta-pr,0.75rem)', 714, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', _v1136)]),
  ]),
  RaftUtility('pr-0', 715, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(0, 'px'))]),
  ]),
  RaftUtility('pr-0.5', 716, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(2, 'px'))]),
  ]),
  RaftUtility('pr-1.5', 717, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(6, 'px'))]),
  ]),
  RaftUtility('pr-2', 718, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(8, 'px'))]),
  ]),
  RaftUtility('pr-2.5', 719, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(10, 'px'))]),
  ]),
  RaftUtility('pr-4', 720, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(16, 'px'))]),
  ]),
  RaftUtility('pr-6', 721, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(24, 'px'))]),
  ]),
  RaftUtility('pr-7', 722, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(28, 'px'))]),
  ]),
  RaftUtility('pr-[5px]', 723, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(5, 'px'))]),
  ]),
  RaftUtility(
    'pr-[calc(16px+env(safe-area-inset-right,0px))]',
    724,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssCalc(_v76))]),
    ],
  ),
  RaftUtility(
    'pr-[calc(env(safe-area-inset-right,0px)+--spacing(4))]',
    725,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssCalc(_v1137))]),
    ],
  ),
  RaftUtility(
    'pt-(--shell-header-height,56px)',
    693,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-top', _v965)]),
    ],
  ),
  RaftUtility('pt-0', 694, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(0, 'px'))]),
  ]),
  RaftUtility('pt-0.5', 695, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(2, 'px'))]),
  ]),
  RaftUtility('pt-1', 696, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(4, 'px'))]),
  ]),
  RaftUtility('pt-1.5', 697, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(6, 'px'))]),
  ]),
  RaftUtility('pt-2', 698, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(8, 'px'))]),
  ]),
  RaftUtility('pt-2.5', 699, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(10, 'px'))]),
  ]),
  RaftUtility('pt-3', 700, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(12, 'px'))]),
  ]),
  RaftUtility('pt-3.5', 701, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(14, 'px'))]),
  ]),
  RaftUtility('pt-4', 702, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(16, 'px'))]),
  ]),
  RaftUtility('pt-6', 703, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(24, 'px'))]),
  ]),
  RaftUtility('pt-8', 704, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(32, 'px'))]),
  ]),
  RaftUtility('pt-9', 705, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(36, 'px'))]),
  ]),
  RaftUtility('pt-[17px]', 707, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(17, 'px'))]),
  ]),
  RaftUtility('pt-[3px]', 706, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(3, 'px'))]),
  ]),
  RaftUtility(
    'pt-[calc(env(safe-area-inset-top,0px)+--spacing(3))]',
    708,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssCalc(_v1138))]),
    ],
  ),
  RaftUtility(
    'pt-[env(safe-area-inset-top,0px)]',
    709,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-top', _v79)]),
    ],
  ),
  RaftUtility('pt-px', 710, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(1, 'px'))]),
  ]),
  RaftUtility('px-(--sidebar-inset-x,26px)', 661, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', _v1104),
      RaftDecl('padding-right', _v1104),
    ]),
  ]),
  RaftUtility(
    'px-(--sidebar-row-inset-x,6px)',
    662,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('padding-left', _v82),
        RaftDecl('padding-right', _v82),
      ]),
    ],
  ),
  RaftUtility('px-0', 663, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(0, 'px')),
      RaftDecl('padding-right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('px-0.5', 664, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(2, 'px')),
      RaftDecl('padding-right', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('px-1', 665, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(4, 'px')),
      RaftDecl('padding-right', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('px-1.5', 666, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(6, 'px')),
      RaftDecl('padding-right', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('px-2', 667, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(8, 'px')),
      RaftDecl('padding-right', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('px-2.5', 668, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(10, 'px')),
      RaftDecl('padding-right', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('px-3', 669, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(12, 'px')),
      RaftDecl('padding-right', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('px-3.5', 670, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(14, 'px')),
      RaftDecl('padding-right', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('px-4', 671, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(16, 'px')),
      RaftDecl('padding-right', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('px-5', 672, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(20, 'px')),
      RaftDecl('padding-right', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('px-6', 673, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(24, 'px')),
      RaftDecl('padding-right', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('px-7', 674, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(28, 'px')),
      RaftDecl('padding-right', CssNum(28, 'px')),
    ]),
  ]),
  RaftUtility('px-8', 675, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(32, 'px')),
      RaftDecl('padding-right', CssNum(32, 'px')),
    ]),
  ]),
  RaftUtility('px-[7px]', 676, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(7, 'px')),
      RaftDecl('padding-right', CssNum(7, 'px')),
    ]),
  ]),
  RaftUtility('py-0', 677, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(0, 'px')),
      RaftDecl('padding-bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('py-0.5', 678, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(2, 'px')),
      RaftDecl('padding-bottom', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('py-1', 679, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(4, 'px')),
      RaftDecl('padding-bottom', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('py-1.5', 680, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(6, 'px')),
      RaftDecl('padding-bottom', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('py-12', 687, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(48, 'px')),
      RaftDecl('padding-bottom', CssNum(48, 'px')),
    ]),
  ]),
  RaftUtility('py-2', 681, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(8, 'px')),
      RaftDecl('padding-bottom', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('py-2.5', 682, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(10, 'px')),
      RaftDecl('padding-bottom', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('py-3', 683, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(12, 'px')),
      RaftDecl('padding-bottom', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('py-3.5', 684, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(14, 'px')),
      RaftDecl('padding-bottom', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('py-4', 685, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(16, 'px')),
      RaftDecl('padding-bottom', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('py-5', 686, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(20, 'px')),
      RaftDecl('padding-bottom', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('py-[1.5px]', 688, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(1.5, 'px')),
      RaftDecl('padding-bottom', CssNum(1.5, 'px')),
    ]),
  ]),
  RaftUtility('py-[5px]', 689, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(5, 'px')),
      RaftDecl('padding-bottom', CssNum(5, 'px')),
    ]),
  ]),
  RaftUtility('py-[7px]', 690, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(7, 'px')),
      RaftDecl('padding-bottom', CssNum(7, 'px')),
    ]),
  ]),
  RaftUtility('py-px', 691, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(1, 'px')),
      RaftDecl('padding-bottom', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('relative', 8, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('position', CssKeyword('relative'))]),
  ]),
  RaftUtility('resize-none', 342, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('resize', CssKeyword('none'))]),
  ]),
  RaftUtility('resize-y', 343, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('resize', CssKeyword('vertical'))]),
  ]),
  RaftUtility('right-(--drawer-inset)', 33, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', _v165)]),
  ]),
  RaftUtility(
    'right-(--sidebar-row-inset-x,6px)',
    34,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('right', _v82)]),
    ],
  ),
  RaftUtility('right-0', 35, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(0, 'px'))]),
  ]),
  RaftUtility('right-1', 36, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(4, 'px'))]),
  ]),
  RaftUtility('right-1.5', 37, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(6, 'px'))]),
  ]),
  RaftUtility('right-2', 38, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(8, 'px'))]),
  ]),
  RaftUtility('right-2.5', 39, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(10, 'px'))]),
  ]),
  RaftUtility('right-4', 40, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(16, 'px'))]),
  ]),
  RaftUtility('right-6', 41, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(24, 'px'))]),
  ]),
  RaftUtility('right-[29px]', 42, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(29, 'px'))]),
  ]),
  RaftUtility('right-[calc(100%+2px)]', 43, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssCalc(_v1139))]),
  ]),
  RaftUtility('right-[calc(100%-10px)]', 44, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssCalc(_v1140))]),
  ]),
  RaftUtility(
    'ring-(--tabs-ring,var(--ink-10))',
    996,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v1141)]),
    ],
  ),
  RaftUtility('ring-0', 992, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ring-shadow', _v37),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('ring-1', 993, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ring-shadow', _v293),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('ring-2', 994, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ring-shadow', _v618),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('ring-[0.5px]', 995, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ring-shadow', _v666),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('ring-ink-10', 998, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v12)]),
  ]),
  RaftUtility('ring-ink-20', 999, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v375)]),
  ]),
  RaftUtility('ring-ink-6', 997, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v275)]),
  ]),
  RaftUtility('ring-inset', 1174, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ring-inset', CssKeyword('inset')),
    ]),
  ]),
  RaftUtility('ring-layer-canvas-muted', 1000, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v68)]),
  ]),
  RaftUtility('ring-line-hairline', 1001, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v158)]),
  ]),
  RaftUtility('ring-line-muted', 1002, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v81)]),
  ]),
  RaftUtility('ring-line-muted/45', 1003, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v81)]),
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v788)]),
  ]),
  RaftUtility('ring-offset-2', 1005, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ring-offset-width', CssNum(2, 'px')),
      RaftDecl('--tw-ring-offset-shadow', _v664),
    ]),
  ]),
  RaftUtility(
    'ring-offset-layer-canvas-muted',
    1006,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-offset-color', _v68)]),
    ],
  ),
  RaftUtility('ring-primary-400', 1004, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v118)]),
  ]),
  RaftUtility('rotate-45', 326, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('rotate', CssNum(45, 'deg'))]),
  ]),
  RaftUtility('rotate-90', 327, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('rotate', CssNum(90, 'deg'))]),
  ]),
  RaftUtility('rounded-[10px]', 434, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(10, 'px')),
      RaftDecl('border-top-right-radius', CssNum(10, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(10, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('rounded-[3px]', 430, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(3, 'px')),
      RaftDecl('border-top-right-radius', CssNum(3, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(3, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(3, 'px')),
    ]),
  ]),
  RaftUtility('rounded-[5.5px]', 431, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(5.5, 'px')),
      RaftDecl('border-top-right-radius', CssNum(5.5, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(5.5, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(5.5, 'px')),
    ]),
  ]),
  RaftUtility('rounded-[5px]', 432, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(5, 'px')),
      RaftDecl('border-top-right-radius', CssNum(5, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(5, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(5, 'px')),
    ]),
  ]),
  RaftUtility('rounded-[7px]', 433, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(7, 'px')),
      RaftDecl('border-top-right-radius', CssNum(7, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(7, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(7, 'px')),
    ]),
  ]),
  RaftUtility('rounded-[inherit]', 435, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssKeyword('inherit')),
      RaftDecl('border-top-right-radius', CssKeyword('inherit')),
      RaftDecl('border-bottom-right-radius', CssKeyword('inherit')),
      RaftDecl('border-bottom-left-radius', CssKeyword('inherit')),
    ]),
  ]),
  RaftUtility('rounded-b-md', 446, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-bottom-right-radius', CssNum(6, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('rounded-b-xl', 447, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-bottom-right-radius', CssNum(12, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('rounded-full', 436, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', _v77),
      RaftDecl('border-top-right-radius', _v77),
      RaftDecl('border-bottom-right-radius', _v77),
      RaftDecl('border-bottom-left-radius', _v77),
    ]),
  ]),
  RaftUtility('rounded-l-full', 442, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', _v77),
      RaftDecl('border-bottom-left-radius', _v77),
    ]),
  ]),
  RaftUtility('rounded-lg', 437, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(8, 'px')),
      RaftDecl('border-top-right-radius', CssNum(8, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(8, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('rounded-md', 438, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(6, 'px')),
      RaftDecl('border-top-right-radius', CssNum(6, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(6, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('rounded-none', 439, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(0)),
      RaftDecl('border-top-right-radius', CssNum(0)),
      RaftDecl('border-bottom-right-radius', CssNum(0)),
      RaftDecl('border-bottom-left-radius', CssNum(0)),
    ]),
  ]),
  RaftUtility('rounded-r-none', 443, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-right-radius', CssNum(0)),
      RaftDecl('border-bottom-right-radius', CssNum(0)),
    ]),
  ]),
  RaftUtility('rounded-r-sm', 444, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-right-radius', CssNum(4, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('rounded-sm', 440, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(4, 'px')),
      RaftDecl('border-top-right-radius', CssNum(4, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(4, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('rounded-tr-[15%]', 445, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-right-radius', CssNum(15, '%')),
    ]),
  ]),
  RaftUtility('rounded-xl', 441, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(12, 'px')),
      RaftDecl('border-top-right-radius', CssNum(12, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(12, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility(
    'row-end-(--ph-icon-row-end,auto)',
    94,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-row-end', _v1082)]),
    ],
  ),
  RaftUtility('row-span-2', 89, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-row', _v73)]),
  ]),
  RaftUtility(
    'row-start-(--banner-desc-row,1)',
    90,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-row-start', _v1142)]),
    ],
  ),
  RaftUtility(
    'row-start-(--ph-icon-row-start,auto)',
    91,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-row-start', _v1143)]),
    ],
  ),
  RaftUtility('row-start-1', 92, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-row-start', CssNum(1))]),
  ]),
  RaftUtility('row-start-2', 93, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-row-start', CssNum(2))]),
  ]),
  RaftUtility('saturate-150', 1019, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-saturate', _v1144),
      RaftDecl('filter', _v662),
    ]),
  ]),
  RaftUtility('scale-[0.82]', 323, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('scale', CssNum(0.82))]),
  ]),
  RaftUtility('scale-x-50', 322, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-scale-x', CssNum(50, '%')),
      RaftDecl('scale', _v277),
    ]),
  ]),
  RaftUtility('scroll-pb-(--ta-scroll-pb,0)', 346, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('scroll-padding-bottom', _v1145)]),
  ]),
  RaftUtility('scroll-py-1', 344, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('scroll-padding-top', CssNum(4, 'px')),
      RaftDecl('scroll-padding-bottom', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('scroll-py-6', 345, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('scroll-padding-top', CssNum(24, 'px')),
      RaftDecl('scroll-padding-bottom', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('scrollbar-none', -1, RaftUtilityStatus.noCss, []),
  RaftUtility('select-none', 1069, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('-webkit-user-select', CssKeyword('none')),
      RaftDecl('user-select', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('select-text', 1070, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('-webkit-user-select', CssKeyword('text')),
      RaftDecl('user-select', CssKeyword('text')),
    ]),
  ]),
  RaftUtility('self-center', 410, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('align-self', CssKeyword('center'))]),
  ]),
  RaftUtility('self-start', 411, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('align-self', _v141)]),
  ]),
  RaftUtility('self-stretch', 412, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-self', CssKeyword('stretch')),
    ]),
  ]),
  RaftUtility(
    'shadow-[0_12px_32px_-18px_oklch(0_0_0/0.55)]',
    969,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1147),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[0_18px_42px_-18px_oklch(0_0_0/0.54)]',
    970,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1148),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[0_1px_1.5px_-0.5px_oklch(0_0_0/0.18),0_0_0_1px_oklch(0_0_0/0.04)]',
    965,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1153),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[0_1px_1px_color-mix(in_oklch,var(--ink)_5%,transparent)]',
    966,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1155),
        RaftDecl('box-shadow', _v20),
      ]),
      RaftLayer('self', [], 1000, [RaftDecl('--tw-shadow', _v1158)]),
    ],
  ),
  RaftUtility(
    'shadow-[0_3px_6px_oklch(0.42_0.12_20/0.25)]',
    967,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1161),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[0_4px_12px_oklch(0_0_0/0.08)]',
    968,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1164),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility('shadow-[2px_2px_0_0_black]', 971, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-shadow', _v1165),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility(
    'shadow-[inset_0_0.5px_1px_color-mix(in_oklch,oklch(1_0_0)_55%,transparent)]',
    972,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1168),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.025),0_0_0_1px_var(--danger-muted)]',
    985,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1174),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.04),0_0_0_1px_color-mix(in_srgb-linear,var(--accent-strong)_28%,transparent)]',
    973,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1178),
        RaftDecl('box-shadow', _v20),
      ]),
      RaftLayer('self', [], 1000, [RaftDecl('--tw-shadow', _v1183)]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.04),0_0_0_1px_var(--primary-edge)]',
    974,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1184),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.05),0_0_0_1px_var(--line-muted)]',
    975,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1187),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.05),0_1px_1.5px_-1px_oklch(0_0_0/0.035),0_0_0_1px_var(--line-muted)]',
    977,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1191),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.05),0_1px_1.5px_-1px_oklch(0_0_0/0.035),0_1px_2.5px_-0.5px_oklch(0_0_0/0.12),0_0_0_1px_var(--line-muted)]',
    978,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1193),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.05),0_1px_1.5px_-1px_oklch(0_0_0/0.08)]',
    976,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1195),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.05),0_2px_2px_-1px_oklch(0_0_0/0.04),0_4px_4px_-2px_oklch(0_0_0/0.02),0_0_0_1px_var(--line-muted)]',
    979,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1196),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.08),0_0_0_1px_var(--danger-muted)]',
    980,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1198),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.12),0_0_0_1px_var(--danger)]',
    981,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1201),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.12),0_0_0_1px_var(--foreground)]',
    982,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1204),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.12),0_0_0_1px_var(--info)]',
    983,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1207),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility(
    'shadow-[inset_0_1px_0.5px_oklch(1_0_0/0.14),0_0_0_1px_var(--warning)]',
    984,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v1213),
        RaftDecl('box-shadow', _v20),
      ]),
    ],
  ),
  RaftUtility('shadow-none', 986, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-shadow', _v15),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('shadow-raft-lg', 987, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-shadow', _v1214),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('shadow-raft-md', 988, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-shadow', _v61),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('shadow-raft-sm', 989, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-shadow', _v278),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('shadow-raft-xl', 990, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-shadow', _v646),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('shadow-raft-xs', 991, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-shadow', _v279),
      RaftDecl('box-shadow', _v20),
    ]),
  ]),
  RaftUtility('shrink', 303, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-shrink', CssNum(1))]),
  ]),
  RaftUtility('shrink-(--si-title-shrink,1)', 304, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-shrink', _v1215)]),
  ]),
  RaftUtility('shrink-0', 305, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-shrink', CssNum(0))]),
  ]),
  RaftUtility('size-0.5', 144, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(2, 'px')),
      RaftDecl('height', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('size-1', 145, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(4, 'px')),
      RaftDecl('height', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('size-1.5', 146, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(6, 'px')),
      RaftDecl('height', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('size-10', 158, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(40, 'px')),
      RaftDecl('height', CssNum(40, 'px')),
    ]),
  ]),
  RaftUtility('size-11', 159, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(44, 'px')),
      RaftDecl('height', CssNum(44, 'px')),
    ]),
  ]),
  RaftUtility('size-12', 160, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(48, 'px')),
      RaftDecl('height', CssNum(48, 'px')),
    ]),
  ]),
  RaftUtility('size-14', 161, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(56, 'px')),
      RaftDecl('height', CssNum(56, 'px')),
    ]),
  ]),
  RaftUtility('size-16', 162, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(64, 'px')),
      RaftDecl('height', CssNum(64, 'px')),
    ]),
  ]),
  RaftUtility('size-2', 147, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(8, 'px')),
      RaftDecl('height', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('size-2.5', 148, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(10, 'px')),
      RaftDecl('height', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('size-3', 149, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(12, 'px')),
      RaftDecl('height', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('size-3.5', 150, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(14, 'px')),
      RaftDecl('height', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('size-4', 151, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(16, 'px')),
      RaftDecl('height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('size-4.5', 152, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(18, 'px')),
      RaftDecl('height', CssNum(18, 'px')),
    ]),
  ]),
  RaftUtility('size-5', 153, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(20, 'px')),
      RaftDecl('height', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('size-6', 154, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(24, 'px')),
      RaftDecl('height', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('size-7', 155, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(28, 'px')),
      RaftDecl('height', CssNum(28, 'px')),
    ]),
  ]),
  RaftUtility('size-8', 156, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(32, 'px')),
      RaftDecl('height', CssNum(32, 'px')),
    ]),
  ]),
  RaftUtility('size-9', 157, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(36, 'px')),
      RaftDecl('height', CssNum(36, 'px')),
    ]),
  ]),
  RaftUtility('size-[11px]', 163, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(11, 'px')),
      RaftDecl('height', CssNum(11, 'px')),
    ]),
  ]),
  RaftUtility('size-[26px]', 164, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(26, 'px')),
      RaftDecl('height', CssNum(26, 'px')),
    ]),
  ]),
  RaftUtility('size-auto', 165, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssKeyword('auto')),
      RaftDecl('height', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('size-full', 166, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(100, '%')),
      RaftDecl('height', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility('sm:auto-rows-[8rem]', 2456, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=640'],
      1000,
      [RaftDecl('grid-auto-rows', CssNum(128, 'px'))],
    ),
  ]),
  RaftUtility('sm:auto-rows-[9rem]', 2457, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=640'],
      1000,
      [RaftDecl('grid-auto-rows', CssNum(144, 'px'))],
    ),
  ]),
  RaftUtility('sm:px-3', 2458, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=640'],
      1000,
      [
        RaftDecl('padding-left', CssNum(12, 'px')),
        RaftDecl('padding-right', CssNum(12, 'px')),
      ],
    ),
  ]),
  RaftUtility('sm:px-3.5', 2459, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=640'],
      1000,
      [
        RaftDecl('padding-left', CssNum(14, 'px')),
        RaftDecl('padding-right', CssNum(14, 'px')),
      ],
    ),
  ]),
  RaftUtility('sm:px-4', 2460, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=640'],
      1000,
      [
        RaftDecl('padding-left', CssNum(16, 'px')),
        RaftDecl('padding-right', CssNum(16, 'px')),
      ],
    ),
  ]),
  RaftUtility('sm:py-2.5', 2461, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=640'],
      1000,
      [
        RaftDecl('padding-top', CssNum(10, 'px')),
        RaftDecl('padding-bottom', CssNum(10, 'px')),
      ],
    ),
  ]),
  RaftUtility('sm:py-3', 2462, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=640'],
      1000,
      [
        RaftDecl('padding-top', CssNum(12, 'px')),
        RaftDecl('padding-bottom', CssNum(12, 'px')),
      ],
    ),
  ]),
  RaftUtility('sm:py-3.5', 2463, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=640'],
      1000,
      [
        RaftDecl('padding-top', CssNum(14, 'px')),
        RaftDecl('padding-bottom', CssNum(14, 'px')),
      ],
    ),
  ]),
  RaftUtility('sm:text-[13px]', 2464, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=640'],
      1000,
      [RaftDecl('font-size', CssNum(13, 'px'))],
    ),
  ]),
  RaftUtility('space-y-1.5', 386, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-space-y-reverse', CssNum(0)),
      RaftDecl('margin-top', CssCalc(_v1217)),
      RaftDecl('margin-bottom', CssCalc(_v1219)),
    ]),
  ]),
  RaftUtility('space-y-2', 387, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-space-y-reverse', CssNum(0)),
      RaftDecl('margin-top', CssCalc(_v1220)),
      RaftDecl('margin-bottom', CssCalc(_v1221)),
    ]),
  ]),
  RaftUtility('space-y-2.5', 388, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-space-y-reverse', CssNum(0)),
      RaftDecl('margin-top', CssCalc(_v1222)),
      RaftDecl('margin-bottom', CssCalc(_v1223)),
    ]),
  ]),
  RaftUtility('space-y-3', 389, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-space-y-reverse', CssNum(0)),
      RaftDecl('margin-top', CssCalc(_v1224)),
      RaftDecl('margin-bottom', CssCalc(_v1225)),
    ]),
  ]),
  RaftUtility('space-y-3.5', 390, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-space-y-reverse', CssNum(0)),
      RaftDecl('margin-top', CssCalc(_v1226)),
      RaftDecl('margin-bottom', CssCalc(_v1227)),
    ]),
  ]),
  RaftUtility('space-y-4', 391, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-space-y-reverse', CssNum(0)),
      RaftDecl('margin-top', CssCalc(_v1228)),
      RaftDecl('margin-bottom', CssCalc(_v1229)),
    ]),
  ]),
  RaftUtility('space-y-px', 392, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > :not(:last-child))', [], 0, [
      RaftDecl('--tw-space-y-reverse', CssNum(0)),
      RaftDecl('margin-top', CssCalc(_v1230)),
      RaftDecl('margin-bottom', CssCalc(_v1231)),
    ]),
  ]),
  RaftUtility('sr-only', 5, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('position', CssKeyword('absolute')),
      RaftDecl('width', CssNum(1, 'px')),
      RaftDecl('height', CssNum(1, 'px')),
      RaftDecl('padding-top', CssNum(0)),
      RaftDecl('padding-right', CssNum(0)),
      RaftDecl('padding-bottom', CssNum(0)),
      RaftDecl('padding-left', CssNum(0)),
      RaftDecl('margin-top', CssNum(-1, 'px')),
      RaftDecl('margin-right', CssNum(-1, 'px')),
      RaftDecl('margin-bottom', CssNum(-1, 'px')),
      RaftDecl('margin-left', CssNum(-1, 'px')),
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
      RaftDecl('clip-path', _v1232),
      RaftDecl('white-space', CssKeyword('nowrap')),
      RaftDecl('border-top-width', CssNum(0)),
      RaftDecl('border-right-width', CssNum(0)),
      RaftDecl('border-bottom-width', CssNum(0)),
      RaftDecl('border-left-width', CssNum(0)),
    ]),
  ]),
  RaftUtility('static', 9, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('position', CssKeyword('static'))]),
  ]),
  RaftUtility('stroke-transparent', 647, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('stroke', _v7)]),
  ]),
  RaftUtility(
    'supports-[-webkit-touch-callout:none]:absolute',
    2359,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('position', CssKeyword('absolute')),
      ]),
    ],
  ),
  RaftUtility('tabular-nums', 944, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-numeric-spacing', _v1233),
      RaftDecl('font-variant-numeric', _v1239),
    ]),
  ]),
  RaftUtility(
    'text-(--ig-addon-fg,var(--ig-addon-fg-default,var(--foreground-muted)))',
    845,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1241)]),
    ],
  ),
  RaftUtility(
    'text-(--ig-text-fg,var(--ig-text-fg-default,var(--foreground-placeholder)))',
    846,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1243)]),
    ],
  ),
  RaftUtility(
    'text-(--mi-ct-color,transparent)',
    847,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1244)]),
    ],
  ),
  RaftUtility(
    'text-(--reference-badge-ink,currentColor)',
    848,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v977)]),
    ],
  ),
  RaftUtility('text-2xl', 765, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(24, 'px')),
      RaftDecl('line-height', _v143),
    ]),
  ]),
  RaftUtility('text-5xl', 766, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(48, 'px')),
      RaftDecl('line-height', _v1245),
    ]),
  ]),
  RaftUtility('text-[1.071em]', 778, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(1.071, 'em'))]),
  ]),
  RaftUtility('text-[1.143em]', 779, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(1.143, 'em'))]),
  ]),
  RaftUtility('text-[1.286em]', 780, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(1.286, 'em'))]),
  ]),
  RaftUtility('text-[10px]', 783, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(10, 'px'))]),
  ]),
  RaftUtility('text-[11.5px]', 784, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(11.5, 'px'))]),
  ]),
  RaftUtility('text-[11px]', 785, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(11, 'px'))]),
  ]),
  RaftUtility('text-[12.5px]', 786, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(12.5, 'px'))]),
  ]),
  RaftUtility('text-[12px]', 787, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(12, 'px'))]),
  ]),
  RaftUtility('text-[13.5px]', 788, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(13.5, 'px'))]),
  ]),
  RaftUtility('text-[13px]', 789, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(13, 'px'))]),
  ]),
  RaftUtility('text-[17px]', 790, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(17, 'px'))]),
  ]),
  RaftUtility('text-[1em]', 781, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(1, 'em'))]),
  ]),
  RaftUtility('text-[32px]', 791, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(32, 'px'))]),
  ]),
  RaftUtility('text-[40px]', 792, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(40, 'px'))]),
  ]),
  RaftUtility('text-[4px]', 782, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(4, 'px'))]),
  ]),
  RaftUtility('text-[56px]', 793, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(56, 'px'))]),
  ]),
  RaftUtility(
    'text-[color-mix(in_oklab,var(--danger)_72%,transparent)]',
    849,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v137)]),
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1247)]),
    ],
  ),
  RaftUtility('text-[oklch(0.25_0.05_50)]', 850, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1248)]),
  ]),
  RaftUtility('text-[oklch(0.269_0_0)]', 859, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v13)]),
  ]),
  RaftUtility(
    'text-[oklch(0.39_0.11_153.079)]',
    851,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1249)]),
    ],
  ),
  RaftUtility('text-[oklch(0.409_0_0)]', 860, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1250)]),
  ]),
  RaftUtility(
    'text-[oklch(0.431_0.088_86.67)]',
    861,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1041)]),
    ],
  ),
  RaftUtility(
    'text-[oklch(0.43_0.12_44.441)]',
    852,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1251)]),
    ],
  ),
  RaftUtility(
    'text-[oklch(0.447_0.002_67.77)]',
    862,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1252)]),
    ],
  ),
  RaftUtility('text-[oklch(0.44_0_0)]', 853, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1253)]),
  ]),
  RaftUtility('text-[oklch(0.45_0.04_74)]', 854, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1254)]),
  ]),
  RaftUtility(
    'text-[oklch(0.476_0.114_61.907)]',
    863,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v132)]),
    ],
  ),
  RaftUtility(
    'text-[oklch(0.48_0.12_153.079)]',
    855,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1255)]),
    ],
  ),
  RaftUtility(
    'text-[oklch(0.543_0.215_359.77)]',
    864,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1042)]),
    ],
  ),
  RaftUtility('text-[oklch(0.54_0.19_31)]', 856, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1256)]),
  ]),
  RaftUtility(
    'text-[oklch(0.81_0.19_88.08)]',
    857,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v908)]),
    ],
  ),
  RaftUtility('text-[oklch(0.88_0.18_132)]', 858, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1257)]),
  ]),
  RaftUtility(
    'text-[oklch(0.985_0.001_286)]',
    865,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1258)]),
    ],
  ),
  RaftUtility('text-[oklch(0_0_0/0.7)]', 866, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1259)]),
  ]),
  RaftUtility(
    'text-[oklch(73.4%_0.149_89.2)]',
    867,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1260)]),
    ],
  ),
  RaftUtility('text-accent-400', 868, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v212)]),
  ]),
  RaftUtility('text-accent-700', 869, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v904)]),
  ]),
  RaftUtility('text-accent-950', 870, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1261)]),
  ]),
  RaftUtility('text-accent-strong', 871, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v157)]),
  ]),
  RaftUtility('text-balance', 837, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-wrap', CssKeyword('balance'))]),
  ]),
  RaftUtility('text-base', 767, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(16, 'px')),
      RaftDecl('line-height', _v1262),
    ]),
  ]),
  RaftUtility('text-black', 872, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v5)]),
  ]),
  RaftUtility('text-black/35', 873, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v424)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v425)]),
  ]),
  RaftUtility('text-black/40', 874, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v56)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v57)]),
  ]),
  RaftUtility('text-black/45', 875, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v135)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v136)]),
  ]),
  RaftUtility('text-black/50', 876, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v66)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v67)]),
  ]),
  RaftUtility('text-black/55', 877, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1003)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1004)]),
  ]),
  RaftUtility('text-black/60', 878, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v8)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v9)]),
  ]),
  RaftUtility('text-black/70', 879, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v154)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v155)]),
  ]),
  RaftUtility('text-black/75', 880, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1044)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1045)]),
  ]),
  RaftUtility('text-black/80', 881, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1264)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1265)]),
  ]),
  RaftUtility('text-brutal-orange', 882, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', CssColor(0xFFF8A16F))]),
  ]),
  RaftUtility('text-brutal-pink', 883, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', CssColor(0xFFFE7DA8))]),
  ]),
  RaftUtility('text-card-title', 768, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', _v1266),
      RaftDecl('line-height', _v1267),
    ]),
  ]),
  RaftUtility('text-center', 755, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-align', CssKeyword('center'))]),
  ]),
  RaftUtility('text-current', 884, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v35)]),
  ]),
  RaftUtility('text-danger', 885, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v137)]),
  ]),
  RaftUtility('text-danger-foreground', 886, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1268)]),
  ]),
  RaftUtility('text-danger-strong', 887, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v746)]),
  ]),
  RaftUtility('text-field', 769, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', _v1269),
      RaftDecl('line-height', _v1271),
    ]),
  ]),
  RaftUtility('text-foreground', 888, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v14)]),
  ]),
  RaftUtility('text-foreground-hint', 889, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v156)]),
  ]),
  RaftUtility('text-foreground-icon', 890, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v138)]),
  ]),
  RaftUtility('text-foreground-inverse', 891, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v227)]),
  ]),
  RaftUtility('text-foreground-inverse/70', 892, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v227)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1273)]),
  ]),
  RaftUtility('text-foreground-muted', 893, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v22)]),
  ]),
  RaftUtility('text-foreground-muted/70', 894, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v22)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1275)]),
  ]),
  RaftUtility('text-foreground-muted/80', 895, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v22)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1277)]),
  ]),
  RaftUtility('text-foreground-placeholder', 896, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v58)]),
  ]),
  RaftUtility(
    'text-foreground-placeholder/70',
    897,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v58)]),
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1128)]),
    ],
  ),
  RaftUtility(
    'text-foreground-placeholder/80',
    898,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v58)]),
      RaftLayer('self', [], 1000, [RaftDecl('color', _v1279)]),
    ],
  ),
  RaftUtility('text-foreground-strong', 899, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
  ]),
  RaftUtility('text-foreground-strong/30', 900, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v756)]),
  ]),
  RaftUtility('text-foreground-strong/35', 901, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v748)]),
  ]),
  RaftUtility('text-foreground-strong/40', 902, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v750)]),
  ]),
  RaftUtility('text-foreground-strong/45', 903, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1281)]),
  ]),
  RaftUtility('text-foreground-strong/50', 904, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v752)]),
  ]),
  RaftUtility('text-foreground-strong/60', 905, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v944)]),
  ]),
  RaftUtility('text-foreground-strong/65', 906, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1283)]),
  ]),
  RaftUtility('text-foreground-strong/70', 907, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v48)]),
  ]),
  RaftUtility('text-foreground-strong/75', 908, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v684)]),
  ]),
  RaftUtility('text-foreground/80', 909, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v14)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1285)]),
  ]),
  RaftUtility('text-inactive-foreground', 910, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1286)]),
  ]),
  RaftUtility('text-info-strong', 911, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v228)]),
  ]),
  RaftUtility('text-inherit', 912, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', CssKeyword('inherit'))]),
  ]),
  RaftUtility('text-ink-30', 913, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1287)]),
  ]),
  RaftUtility('text-layer-hud-foreground', 914, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1288)]),
  ]),
  RaftUtility('text-left', 756, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-align', CssKeyword('left'))]),
  ]),
  RaftUtility('text-lg', 770, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(18, 'px')),
      RaftDecl('line-height', _v1290),
    ]),
  ]),
  RaftUtility('text-pretty', 838, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-wrap', CssKeyword('pretty'))]),
  ]),
  RaftUtility('text-primary-600', 915, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1291)]),
  ]),
  RaftUtility('text-primary-700', 916, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1292)]),
  ]),
  RaftUtility('text-primary-900', 917, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1293)]),
  ]),
  RaftUtility('text-primary-950', 918, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v847)]),
  ]),
  RaftUtility('text-primary-strong', 919, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v159)]),
  ]),
  RaftUtility('text-right', 757, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-align', CssKeyword('right'))]),
  ]),
  RaftUtility('text-secondary-800', 920, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1294)]),
  ]),
  RaftUtility('text-secondary-900', 921, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1295)]),
  ]),
  RaftUtility('text-secondary-950', 922, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1296)]),
  ]),
  RaftUtility('text-shadow-none', 1175, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-shadow', CssKeyword('none'))]),
  ]),
  RaftUtility('text-sm', 771, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(14, 'px')),
      RaftDecl('line-height', _v949),
    ]),
  ]),
  RaftUtility('text-sm/5', 772, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(14, 'px')),
      RaftDecl('line-height', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('text-success', 923, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v63)]),
  ]),
  RaftUtility('text-success-foreground', 924, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1297)]),
  ]),
  RaftUtility('text-success-strong', 925, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1298)]),
  ]),
  RaftUtility(
    'text-task-status-closed-strong',
    926,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v539)]),
    ],
  ),
  RaftUtility('text-task-status-done-strong', 927, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v542)]),
  ]),
  RaftUtility(
    'text-task-status-in-progress-strong',
    928,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v545)]),
    ],
  ),
  RaftUtility(
    'text-task-status-in-review-strong',
    929,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v548)]),
    ],
  ),
  RaftUtility('text-task-status-todo-strong', 930, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v551)]),
  ]),
  RaftUtility('text-transparent', 931, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v7)]),
  ]),
  RaftUtility('text-warning', 932, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v64)]),
  ]),
  RaftUtility('text-warning-foreground', 933, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1299)]),
  ]),
  RaftUtility('text-warning-strong', 934, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1300)]),
  ]),
  RaftUtility('text-white', 935, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v39)]),
  ]),
  RaftUtility('text-white/62', 936, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1302)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1303)]),
  ]),
  RaftUtility('text-white/70', 937, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v529)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v530)]),
  ]),
  RaftUtility('text-white/74', 938, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1305)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v1306)]),
  ]),
  RaftUtility('text-white/75', 939, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v532)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v533)]),
  ]),
  RaftUtility('text-xl', 773, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(20, 'px')),
      RaftDecl('line-height', _v1307),
    ]),
  ]),
  RaftUtility('text-xs', 774, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(12, 'px')),
      RaftDecl('line-height', _v143),
    ]),
  ]),
  RaftUtility('text-xs/[1]', 775, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(12, 'px')),
      RaftDecl('line-height', CssNum(1)),
    ]),
  ]),
  RaftUtility('top-(--active-tab-top)', 20, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', _v1308)]),
  ]),
  RaftUtility('top-(--drawer-inset)', 21, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', _v165)]),
  ]),
  RaftUtility('top-0', 22, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(0, 'px'))]),
  ]),
  RaftUtility('top-1', 23, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(4, 'px'))]),
  ]),
  RaftUtility('top-1.5', 24, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(6, 'px'))]),
  ]),
  RaftUtility('top-1/2', 25, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(50, '%'))]),
  ]),
  RaftUtility('top-2.5', 26, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(10, 'px'))]),
  ]),
  RaftUtility('top-4', 27, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(16, 'px'))]),
  ]),
  RaftUtility('top-[-2px]', 28, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(-2, 'px'))]),
  ]),
  RaftUtility(
    'top-[calc(var(--active-tab-top)+1.671875px)]',
    29,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('top', CssCalc(_v1309))]),
    ],
  ),
  RaftUtility('touch-manipulation', 340, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('touch-action', _v1310)]),
  ]),
  RaftUtility('touch-none', 341, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('touch-action', CssKeyword('none'))]),
  ]),
  RaftUtility('tracking-[-0.005em]', 826, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(-0.005, 'em')),
      RaftDecl('letter-spacing', CssNum(-0.005, 'em')),
    ]),
  ]),
  RaftUtility('tracking-[-0.01em]', 825, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(-0.01, 'em')),
      RaftDecl('letter-spacing', CssNum(-0.01, 'em')),
    ]),
  ]),
  RaftUtility('tracking-[0.01em]', 827, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(0.01, 'em')),
      RaftDecl('letter-spacing', CssNum(0.01, 'em')),
    ]),
  ]),
  RaftUtility('tracking-[0.025em]', 831, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(0.025, 'em')),
      RaftDecl('letter-spacing', CssNum(0.025, 'em')),
    ]),
  ]),
  RaftUtility('tracking-[0.22px]', 830, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(0.22, 'px')),
      RaftDecl('letter-spacing', CssNum(0.22, 'px')),
    ]),
  ]),
  RaftUtility('tracking-[0.2em]', 828, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(0.2, 'em')),
      RaftDecl('letter-spacing', CssNum(0.2, 'em')),
    ]),
  ]),
  RaftUtility('tracking-[0.2px]', 829, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(0.2, 'px')),
      RaftDecl('letter-spacing', CssNum(0.2, 'px')),
    ]),
  ]),
  RaftUtility('tracking-normal', 832, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(0, 'em')),
      RaftDecl('letter-spacing', CssNum(0, 'em')),
    ]),
  ]),
  RaftUtility('tracking-tight', 833, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(-0.025, 'em')),
      RaftDecl('letter-spacing', CssNum(-0.025, 'em')),
    ]),
  ]),
  RaftUtility('tracking-wide', 834, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(0.025, 'em')),
      RaftDecl('letter-spacing', CssNum(0.025, 'em')),
    ]),
  ]),
  RaftUtility('tracking-wider', 835, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(0.05, 'em')),
      RaftDecl('letter-spacing', CssNum(0.05, 'em')),
    ]),
  ]),
  RaftUtility('tracking-widest', 836, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(0.1, 'em')),
      RaftDecl('letter-spacing', CssNum(0.1, 'em')),
    ]),
  ]),
  RaftUtility(
    'transform-[translate3d(calc(var(--drawer-swipe-x,0px)+var(--drawer-stack-x,0px)),calc(var(--drawer-swipe-y,0px)+var(--drawer-stack-y,0px)),0)_scale(var(--drawer-stack-scale))]',
    328,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('transform', _v1319)]),
    ],
  ),
  RaftUtility(
    'transform-[translateX(var(--toast-swipe-movement-x))_translateY(calc(var(--toast-swipe-movement-y)+(var(--toast-index)*var(--toast-peek)*var(--toast-peek-dir))))_scale(var(--toast-scale))]',
    329,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('transform', _v1326)]),
    ],
  ),
  RaftUtility('transform-gpu', 330, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('transform', _v1333)]),
  ]),
  RaftUtility('transition', 1024, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v1133),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility(
    'transition-[background-color,border-color]',
    1025,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', CssList([_v23, _v125])),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,box-shadow,color]',
    1026,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1334),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,box-shadow,transform]',
    1027,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1335),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,box-shadow]',
    1028,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', CssList([_v23, _v24])),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,color,border-color,box-shadow,transform]',
    1029,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1336),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,color,box-shadow,transform]',
    1030,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1337),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,color,opacity,box-shadow,transform]',
    1031,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1338),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,color]',
    1032,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1339),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[border-color,opacity,box-shadow]',
    1033,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1340),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[box-shadow,transform]',
    1034,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1341),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility('transition-[clip-path]', 1035, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', CssKeyword('clip-path')),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility(
    'transition-[color,background-color,opacity]',
    1036,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1342),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility('transition-[fill,stroke]', 1037, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v1343),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('transition-[filter,opacity]', 1038, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v1344),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('transition-[filter]', 1039, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', CssKeyword('filter')),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('transition-[left,width]', 1040, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v1345),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility(
    'transition-[opacity,transform]',
    1041,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1346),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility('transition-[top,height]', 1042, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v1347),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility(
    'transition-[transform,height,opacity,filter]',
    1043,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1348),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[transform,opacity,height]',
    1044,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1349),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[width,background-color]',
    1045,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v1350),
        RaftDecl('transition-timing-function', _v27),
        RaftDecl('transition-duration', _v28),
      ]),
    ],
  ),
  RaftUtility('transition-all', 1046, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', CssKeyword('all')),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('transition-colors', 1047, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v131),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('transition-opacity', 1048, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', CssKeyword('opacity')),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('transition-shadow', 1049, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v24),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('transition-transform', 1050, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v59),
      RaftDecl('transition-timing-function', _v27),
      RaftDecl('transition-duration', _v28),
    ]),
  ]),
  RaftUtility('translate-1/4', 315, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-x', CssNum(25, '%')),
      RaftDecl('--tw-translate-y', CssNum(25, '%')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility('translate-y-0.5', 319, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-y', CssNum(2, 'px')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility('translate-y-1', 320, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-y', CssNum(4, 'px')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility('translate-y-px', 321, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-y', CssNum(1, 'px')),
      RaftDecl('translate', CssSeq([_v71, _v72])),
    ]),
  ]),
  RaftUtility('truncate', 416, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
      RaftDecl('text-overflow', CssKeyword('ellipsis')),
      RaftDecl('white-space', CssKeyword('nowrap')),
    ]),
  ]),
  RaftUtility('underline', 947, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-decoration-line', CssKeyword('underline')),
    ]),
  ]),
  RaftUtility('underline-offset-2', 953, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-underline-offset', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('underline-offset-4', 954, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-underline-offset', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('uppercase', 941, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-transform', CssKeyword('uppercase')),
    ]),
  ]),
  RaftUtility('w-(--active-tab-width)', 231, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v1351)]),
  ]),
  RaftUtility('w-(--anchor-width)', 232, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v1107)]),
  ]),
  RaftUtility('w-0.5', 233, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(2, 'px'))]),
  ]),
  RaftUtility('w-10', 242, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(40, 'px'))]),
  ]),
  RaftUtility('w-11', 243, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(44, 'px'))]),
  ]),
  RaftUtility('w-14', 244, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(56, 'px'))]),
  ]),
  RaftUtility('w-16', 245, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(64, 'px'))]),
  ]),
  RaftUtility('w-18', 246, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(72, 'px'))]),
  ]),
  RaftUtility('w-2', 234, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(8, 'px'))]),
  ]),
  RaftUtility('w-2.5', 235, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(10, 'px'))]),
  ]),
  RaftUtility('w-22', 247, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(88, 'px'))]),
  ]),
  RaftUtility('w-3', 236, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(12, 'px'))]),
  ]),
  RaftUtility('w-3/4', 237, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(75, '%'))]),
  ]),
  RaftUtility('w-44', 248, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(176, 'px'))]),
  ]),
  RaftUtility('w-48', 249, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(192, 'px'))]),
  ]),
  RaftUtility('w-56', 250, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(224, 'px'))]),
  ]),
  RaftUtility('w-6', 238, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(24, 'px'))]),
  ]),
  RaftUtility('w-7', 239, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(28, 'px'))]),
  ]),
  RaftUtility('w-8', 240, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(32, 'px'))]),
  ]),
  RaftUtility('w-80', 251, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(320, 'px'))]),
  ]),
  RaftUtility('w-9', 241, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(36, 'px'))]),
  ]),
  RaftUtility('w-[380px]', 252, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(380, 'px'))]),
  ]),
  RaftUtility('w-[calc(100%+12px)]', 253, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssCalc(_v969))]),
  ]),
  RaftUtility('w-[calc(100%-2rem)]', 254, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssCalc(_v1352))]),
  ]),
  RaftUtility(
    'w-[calc(var(--active-tab-width)-2px)]',
    255,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('width', CssCalc(_v1353))]),
    ],
  ),
  RaftUtility('w-[clamp(144px,20vw,224px)]', 256, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v1354)]),
  ]),
  RaftUtility(
    'w-[min(24rem,calc(100vw-2rem))]',
    257,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('width', _v1355)]),
    ],
  ),
  RaftUtility('w-[min(92vw,360px)]', 258, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v1356)]),
  ]),
  RaftUtility('w-auto', 259, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssKeyword('auto'))]),
  ]),
  RaftUtility('w-fit', 260, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v972)]),
  ]),
  RaftUtility('w-full', 261, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(100, '%'))]),
  ]),
  RaftUtility('w-max', 262, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v940)]),
  ]),
  RaftUtility('w-px', 263, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(1, 'px'))]),
  ]),
  RaftUtility('whitespace-normal', 842, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('white-space', CssKeyword('normal')),
    ]),
  ]),
  RaftUtility('whitespace-nowrap', 843, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('white-space', CssKeyword('nowrap')),
    ]),
  ]),
  RaftUtility('whitespace-pre-wrap', 844, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('white-space', CssKeyword('pre-wrap')),
    ]),
  ]),
  RaftUtility(
    'will-change-[transform,opacity]',
    1065,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('will-change', _v1357)]),
    ],
  ),
  RaftUtility('will-change-transform', 1066, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('will-change', CssKeyword('transform')),
    ]),
  ]),
  RaftUtility('wrap-anywhere', 839, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-wrap', CssKeyword('anywhere')),
    ]),
  ]),
  RaftUtility('wrap-break-word', 840, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('overflow-wrap', _v114)]),
  ]),
  RaftUtility('z-0', 64, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(0))]),
  ]),
  RaftUtility('z-10', 65, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(10))]),
  ]),
  RaftUtility('z-20', 66, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(20))]),
  ]),
  RaftUtility('z-30', 67, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(30))]),
  ]),
  RaftUtility('z-40', 68, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(40))]),
  ]),
  RaftUtility('z-50', 69, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(50))]),
  ]),
  RaftUtility('z-60', 70, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(60))]),
  ]),
  RaftUtility('z-70', 71, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(70))]),
  ]),
  RaftUtility('z-71', 72, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(71))]),
  ]),
  RaftUtility(
    'z-[calc(70-var(--toast-index))]',
    73,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('z-index', CssCalc(_v1358))]),
    ],
  ),
];

/// `@property` registered custom properties (initial values).
const Map<String, CssValue?> raftRecipeRegistered = <String, CssValue?>{
  '--tw-backdrop-blur': null,
  '--tw-backdrop-brightness': null,
  '--tw-backdrop-contrast': null,
  '--tw-backdrop-grayscale': null,
  '--tw-backdrop-hue-rotate': null,
  '--tw-backdrop-invert': null,
  '--tw-backdrop-opacity': null,
  '--tw-backdrop-saturate': null,
  '--tw-backdrop-sepia': null,
  '--tw-blur': null,
  '--tw-border-style': CssKeyword('solid'),
  '--tw-brightness': null,
  '--tw-content': CssString(''),
  '--tw-contrast': null,
  '--tw-divide-y-reverse': CssNum(0),
  '--tw-drop-shadow': null,
  '--tw-drop-shadow-alpha': CssNum(100, '%'),
  '--tw-drop-shadow-color': null,
  '--tw-drop-shadow-size': null,
  '--tw-duration': null,
  '--tw-ease': null,
  '--tw-font-weight': null,
  '--tw-gradient-from': CssColor(0x00000000),
  '--tw-gradient-from-position': CssNum(0, '%'),
  '--tw-gradient-position': null,
  '--tw-gradient-stops': null,
  '--tw-gradient-to': CssColor(0x00000000),
  '--tw-gradient-to-position': CssNum(100, '%'),
  '--tw-gradient-via': CssColor(0x00000000),
  '--tw-gradient-via-position': CssNum(50, '%'),
  '--tw-gradient-via-stops': null,
  '--tw-grayscale': null,
  '--tw-hue-rotate': null,
  '--tw-inset-ring-color': null,
  '--tw-inset-ring-shadow': _v15,
  '--tw-inset-shadow': _v15,
  '--tw-inset-shadow-alpha': CssNum(100, '%'),
  '--tw-inset-shadow-color': null,
  '--tw-invert': null,
  '--tw-leading': null,
  '--tw-numeric-figure': null,
  '--tw-numeric-fraction': null,
  '--tw-numeric-spacing': null,
  '--tw-opacity': null,
  '--tw-ordinal': null,
  '--tw-outline-style': CssKeyword('solid'),
  '--tw-ring-color': null,
  '--tw-ring-inset': null,
  '--tw-ring-offset-color': CssColor(0xFFFFFFFF),
  '--tw-ring-offset-shadow': _v15,
  '--tw-ring-offset-width': CssNum(0, 'px'),
  '--tw-ring-shadow': _v15,
  '--tw-rotate-x': null,
  '--tw-rotate-y': null,
  '--tw-rotate-z': null,
  '--tw-saturate': null,
  '--tw-scale-x': CssNum(1),
  '--tw-scale-y': CssNum(1),
  '--tw-scale-z': CssNum(1),
  '--tw-sepia': null,
  '--tw-shadow': _v15,
  '--tw-shadow-alpha': CssNum(100, '%'),
  '--tw-shadow-color': null,
  '--tw-skew-x': null,
  '--tw-skew-y': null,
  '--tw-slashed-zero': null,
  '--tw-space-x-reverse': CssNum(0),
  '--tw-space-y-reverse': CssNum(0),
  '--tw-text-shadow-alpha': CssNum(100, '%'),
  '--tw-text-shadow-color': null,
  '--tw-tracking': null,
  '--tw-translate-x': CssNum(0),
  '--tw-translate-y': CssNum(0),
  '--tw-translate-z': CssNum(0),
};

const RaftRecipeEngine raftRecipeEngine = RaftRecipeEngine(
  raftRecipeUtilities,
  raftRecipeRegistered,
);

const _v0 = CssVar('--foreground-strong', null, 'foregroundStrong');
const _v1 = CssKeyword('ui-monospace');
const _v2 = CssList([CssString('Geist Mono'), _v1, CssKeyword('monospace')]);
const _v3 = CssVar('--mono-font', _v2, 'monoFont');
const _v4 = CssSeq([CssKeyword('in'), CssKeyword('srgb')]);
const _v5 = CssColor(0xFF000000, 'oklch(0 0 0)');
const _v6 = CssSeq([_v5, CssNum(60, '%')]);
const _v7 = CssColor(0x00000000, 'transparent');
const _v8 = CssFunction('color-mix', [_v4, _v6, _v7]);
const _v9 = CssColor(
  0x99000000,
  'color-mix(in oklab, oklch(0 0 0) 60%, transparent)',
  Color.from(alpha: 0.601164, red: 0.000231, green: 0.000231, blue: 0.000184),
);
const _v10 = CssVar('--field-font-weight', null, 'fieldFontWeight');
const _v11 = CssKeyword('space-between');
const _v12 = CssVar('--ink-10', null, 'ink10');
const _v13 = CssColor(0xFF262626, 'oklch(0.269 0 0)');
const _v14 = CssVar('--foreground', null, 'foreground');
const _v15 = CssSeq([CssNum(0), CssNum(0), CssColor(0x00000000)]);
const _v16 = CssVar('--tw-inset-shadow');
const _v17 = CssVar('--tw-inset-ring-shadow');
const _v18 = CssVar('--tw-ring-offset-shadow');
const _v19 = CssVar('--tw-ring-shadow');
const _v20 = CssList([_v16, _v17, _v18, _v19, CssVar('--tw-shadow')]);
const _v21 = CssColor(0xFF525252, 'oklch(0.439 0 0)');
const _v22 = CssVar('--foreground-muted', null, 'foregroundMuted');
const _v23 = CssKeyword('background-color');
const _v24 = CssKeyword('box-shadow');
const _v25 = CssList([CssKeyword('color'), _v23, _v24]);
const _v26 = CssFunction('cubic-bezier', [
  CssNum(0.4),
  CssNum(0),
  CssNum(0.2),
  CssNum(1),
]);
const _v27 = CssVar('--tw-ease', _v26);
const _v28 = CssVar('--tw-duration', CssNum(150, 'ms'));
const _v29 = CssFunction('cubic-bezier', [
  CssNum(0.16),
  CssNum(1),
  CssNum(0.3),
  CssNum(1),
]);
const _v30 = CssList([
  CssKeyword('opacity'),
  CssKeyword('filter'),
  CssKeyword('scale'),
]);
const _v31 = CssVar('--tw-border-style');
const _v32 = CssVar('--tw-ring-inset', CssSeq([]));
const _v33 = CssVar('--tw-ring-offset-width');
const _v34 = CssOp('+', CssNum(0, 'px'), _v33);
const _v35 = CssKeyword('currentcolor');
const _v36 = CssVar('--tw-ring-color', _v35);
const _v37 = CssSeq([
  _v32,
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssCalc(_v34),
  _v36,
]);
const _v38 = CssVar('--layer-panel', null, 'layerPanel');
const _v39 = CssColor(0xFFFFFFFF, 'oklch(1 0 0)');
const _v40 = CssSeq([_v39, CssNum(8, '%')]);
const _v41 = CssFunction('color-mix', [_v4, _v40, _v7]);
const _v42 = CssColor(
  0x14FFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 8%, transparent)',
  Color.from(alpha: 0.080368, red: 0.999237, green: 0.999237, blue: 0.999237),
);
const _v43 = CssVar('--line-strong', null, 'lineStrong');
const _v44 = CssSeq([CssKeyword('in'), CssKeyword('oklab')]);
const _v45 = CssSeq([_v43, CssNum(70, '%')]);
const _v46 = CssFunction('color-mix', [_v44, _v45, _v7]);
const _v47 = CssSeq([_v0, CssNum(70, '%')]);
const _v48 = CssFunction('color-mix', [_v44, _v47, _v7]);
const _v49 = CssSeq([_v39, CssNum(72, '%')]);
const _v50 = CssFunction('color-mix', [_v4, _v49, _v7]);
const _v51 = CssColor(
  0xB8FFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 72%, transparent)',
  Color.from(alpha: 0.721042, red: 0.999503, green: 0.999857, blue: 0.999227),
);
const _v52 = CssKeyword('sans-serif');
const _v53 = CssList([CssKeyword('system-ui'), _v52]);
const _v54 = CssVar('--sans-font', _v53, 'sansFont');
const _v55 = CssSeq([_v5, CssNum(40, '%')]);
const _v56 = CssFunction('color-mix', [_v4, _v55, _v7]);
const _v57 = CssColor(
  0x66000000,
  'color-mix(in oklab, oklch(0 0 0) 40%, transparent)',
  Color.from(alpha: 0.401164, red: 0.000470, green: 0.000810, blue: 0.000341),
);
const _v58 = CssVar('--foreground-placeholder', null, 'foregroundPlaceholder');
const _v59 = CssList([
  CssKeyword('transform'),
  CssKeyword('translate'),
  CssKeyword('scale'),
  CssKeyword('rotate'),
]);
const _v60 = CssKeyword('inline-flex');
const _v61 = CssVar('--theme-shadow-md', null, 'themeShadowMd');
const _v62 = CssVar('--info', null, 'info');
const _v63 = CssVar('--success', null, 'success');
const _v64 = CssVar('--warning', null, 'warning');
const _v65 = CssSeq([_v5, CssNum(50, '%')]);
const _v66 = CssFunction('color-mix', [_v4, _v65, _v7]);
const _v67 = CssColor(
  0x80000000,
  'color-mix(in oklab, oklch(0 0 0) 50%, transparent)',
  Color.from(alpha: 0.501961, red: 0.000050, green: 0.000050, blue: 0.000042),
);
const _v68 = CssVar('--layer-canvas-muted', null, 'layerCanvasMuted');
const _v69 = CssVar('--tw-outline-style');
const _v70 = CssVar('--primary-50', null, 'primary50');
const _v71 = CssVar('--tw-translate-x');
const _v72 = CssVar('--tw-translate-y');
const _v73 = CssSeq([
  CssKeyword('span'),
  CssNum(2),
  CssSlash(),
  CssKeyword('span'),
  CssNum(2),
]);
const _v74 = CssKeyword('safe-area-inset-right');
const _v75 = CssFunction('env', [_v74, CssNum(0, 'px')]);
const _v76 = CssOp('+', CssNum(16, 'px'), _v75);
const _v77 = CssNum(3.4028234663852886e+38, 'px');
const _v78 = CssKeyword('safe-area-inset-top');
const _v79 = CssFunction('env', [_v78, CssNum(0, 'px')]);
const _v80 = CssOp('+', CssNum(16, 'px'), _v79);
const _v81 = CssVar('--line-muted', null, 'lineMuted');
const _v82 = CssVar('--sidebar-row-inset-x', CssNum(6, 'px'));
const _v83 = CssOp('*', _v82, CssNum(-1));
const _v84 = CssVar('--tw-space-x-reverse');
const _v85 = CssOp('*', CssNum(-6, 'px'), _v84);
const _v86 = CssOp('-', CssNum(1), _v84);
const _v87 = CssOp('*', CssNum(-6, 'px'), _v86);
const _v88 = CssOp('*', CssNum(-8, 'px'), _v84);
const _v89 = CssOp('*', CssNum(-8, 'px'), _v86);
const _v90 = CssKeyword('inline-size');
const _v91 = CssSeq([
  CssKeyword('span'),
  CssNum(1),
  CssSlash(),
  CssKeyword('span'),
  CssNum(1),
]);
const _v92 = CssKeyword('content-box');
const _v93 = CssKeyword('border-box');
const _v94 = CssSeq([_v39, CssNum(0), CssNum(0)]);
const _v95 = CssFunction('linear-gradient', [_v94]);
const _v96 = CssSeq([CssKeyword('to'), CssKeyword('bottom')]);
const _v97 = CssVar('--toast-gradient-border-angle', _v96);
const _v98 = CssColor(
  0x3DFFFFFF,
  'oklch(1 0 0 / 0.24)',
  Color.from(alpha: 0.240429, red: 0.999363, green: 0.999363, blue: 0.999329),
);
const _v99 = CssVar('--toast-gradient-border-from', _v98);
const _v100 = CssColor(
  0x1AFFFFFF,
  'oklch(1 0 0 / 0.1)',
  Color.from(alpha: 0.100429, red: 0.994815, green: 0.999979, blue: 0.998796),
);
const _v101 = CssVar('--toast-gradient-border-via', _v100);
const _v102 = CssVar('--toast-gradient-border-to', _v7);
const _v103 = CssFunction('linear-gradient', [_v97, _v99, _v101, _v102]);
const _v104 = CssVar('--toast-gradient-border', _v103);
const _v105 = CssVar('--toast-gradient-border-width', CssNum(1, 'px'));
const _v106 = CssFunction('minmax', [CssNum(0), CssNum(1, 'fr')]);
const _v107 = CssSeq([CssKeyword('auto'), _v106, CssKeyword('auto')]);
const _v108 = CssSeq([CssNum(18, 'px'), _v106, CssKeyword('auto')]);
const _v109 = CssSeq([CssKeyword('auto'), _v106]);
const _v110 = CssVar('--toast-title-only-min-h', CssNum(36, 'px'));
const _v111 = CssVar('--toast-title-only-min-w', CssNum(112, 'px'));
const _v112 = CssVar('--toast-title-only-px', CssNum(12, 'px'));
const _v113 = CssVar('--toast-title-only-py', CssNum(8, 'px'));
const _v114 = CssKeyword('break-word');
const _v115 = CssVar('--fill-strong', null, 'fillStrong');
const _v116 = CssSeq([_v115, CssNum(80, '%')]);
const _v117 = CssFunction('color-mix', [_v44, _v116, _v7]);
const _v118 = CssVar('--primary-400', null, 'primary400');
const _v119 = CssSeq([_v0, CssNum(5, '%')]);
const _v120 = CssFunction('color-mix', [_v44, _v119, _v7]);
const _v121 = CssSeq([_v35, CssNum(70, '%')]);
const _v122 = CssFunction('color-mix', [_v44, _v121, _v7]);
const _v123 = CssSeq([_v35, CssNum(45, '%')]);
const _v124 = CssFunction('color-mix', [_v44, _v123, _v7]);
const _v125 = CssKeyword('border-color');
const _v126 = CssKeyword('outline-color');
const _v127 = CssKeyword('text-decoration-color');
const _v128 = CssKeyword('--tw-gradient-from');
const _v129 = CssKeyword('--tw-gradient-via');
const _v130 = CssKeyword('--tw-gradient-to');
const _v131 = CssList([
  CssKeyword('color'),
  _v23,
  _v125,
  _v126,
  _v127,
  CssKeyword('fill'),
  CssKeyword('stroke'),
  _v128,
  _v129,
  _v130,
]);
const _v132 = CssColor(0xFF894B00, 'oklch(0.476 0.114 61.907)');
const _v133 = CssColor(0xFF007F9E, 'oklch(0.55 0.11 220)');
const _v134 = CssSeq([_v5, CssNum(45, '%')]);
const _v135 = CssFunction('color-mix', [_v4, _v134, _v7]);
const _v136 = CssColor(
  0x73000000,
  'color-mix(in oklab, oklch(0 0 0) 45%, transparent)',
  Color.from(alpha: 0.451777, red: 0.000050, green: 0.000050, blue: 0.000838),
);
const _v137 = CssVar('--danger', null, 'danger');
const _v138 = CssVar('--foreground-icon', null, 'foregroundIcon');
const _v139 = CssFunction('translatey', [CssNum(120, '%')]);
const _v140 = CssFunction('scale', [CssNum(0.98)]);
const _v141 = CssKeyword('flex-start');
const _v142 = CssNum(1.3333333333333333);
const _v143 = CssVar('--tw-leading', _v142);
const _v144 = CssVar('--mi-avatar-shift', CssNum(3, 'px'));
const _v145 = CssVar('--mi-avatar', CssNum(32, 'px'));
const _v146 = CssFunction('cubic-bezier', [
  CssNum(0),
  CssNum(0),
  CssNum(0.2),
  CssNum(1),
]);
const _v147 = CssVar('--ink-2', null, 'ink2');
const _v148 = CssSeq([_v147, CssNum(3, '%')]);
const _v149 = CssFunction('color-mix', [_v44, _v148, _v7]);
const _v150 = CssVar('--shiki-dark', _v35);
const _v151 = CssVar('--shiki-light', _v35);
const _v152 = CssKeyword('non-scaling-stroke');
const _v153 = CssSeq([_v5, CssNum(70, '%')]);
const _v154 = CssFunction('color-mix', [_v4, _v153, _v7]);
const _v155 = CssColor(
  0xB3000000,
  'color-mix(in oklab, oklch(0 0 0) 70%, transparent)',
  Color.from(alpha: 0.702390, red: 0.000416, green: 0.000824, blue: 0.000083),
);
const _v156 = CssVar('--foreground-hint', null, 'foregroundHint');
const _v157 = CssVar('--accent-strong', null, 'accentStrong');
const _v158 = CssVar('--line-hairline', null, 'lineHairline');
const _v159 = CssVar('--primary-strong', null, 'primaryStrong');
const _v160 = CssVar('--drawer-exit-x', CssNum(0, 'px'));
const _v161 = CssVar('--drawer-exit-y', CssNum(0, 'px'));
const _v162 = CssFunction('translate3d', [_v160, _v161, CssNum(0)]);
const _v163 = CssVar('--drawer-height', CssKeyword('auto'));
const _v164 = CssFunction('cubic-bezier', [
  CssNum(0.32),
  CssNum(0.72),
  CssNum(0),
  CssNum(1),
]);
const _v165 = CssVar('--drawer-inset');
const _v166 = CssOp('-', CssNum(-100, '%'), _v165);
const _v167 = CssOp('-', _v166, CssNum(2, 'px'));
const _v168 = CssOp('+', CssNum(100, '%'), _v165);
const _v169 = CssOp('+', _v168, CssNum(2, 'px'));
const _v170 = CssKeyword('safe-area-inset-bottom');
const _v171 = CssFunction('env', [_v170, CssNum(0, 'px')]);
const _v172 = CssFunction('max', [CssNum(12, 'px'), CssCalc(_v171)]);
const _v173 = CssFunction('max', [CssNum(12, 'px'), CssCalc(_v79)]);
const _v174 = CssFunction('max', [CssNum(20, 'px'), CssCalc(_v171)]);
const _v175 = CssVar('--nested-drawers');
const _v176 = CssVar('--drawer-stack-progress');
const _v177 = CssOp('-', _v175, _v176);
const _v178 = CssVar('--drawer-stack-peek');
const _v179 = CssOp('*', _v177, _v178);
const _v180 = CssFunction('max', [CssNum(0, 'px'), CssCalc(_v179)]);
const _v181 = CssVar('--drawer-swipe-progress');
const _v182 = CssFunction('clamp', [CssNum(0), CssCalc(_v181), CssNum(1)]);
const _v183 = CssVar('--drawer-stack-step');
const _v184 = CssOp('*', _v175, _v183);
const _v185 = CssOp('-', CssNum(1), _v184);
const _v186 = CssFunction('max', [CssNum(0), CssCalc(_v185)]);
const _v187 = CssVar('--drawer-stack-scale-base');
const _v188 = CssOp('*', _v183, _v176);
const _v189 = CssOp('+', _v187, _v188);
const _v190 = CssFunction('clamp', [CssNum(0), CssCalc(_v189), CssNum(1)]);
const _v191 = CssVar('--drawer-stack-shrink');
const _v192 = CssVar('--drawer-stack-size');
const _v193 = CssOp('*', _v191, _v192);
const _v194 = CssVar('--drawer-stack-scale');
const _v195 = CssOp('-', CssNum(1), _v194);
const _v196 = CssVar('--drawer-height');
const _v197 = CssVar('--drawer-frontmost-height', _v196);
const _v198 = CssFunction('max', [CssNum(0, 'px'), CssCalc(_v197)]);
const _v199 = CssVar('--drawer-stack-offset');
const _v200 = CssOp('-', CssNum(0, 'px'), _v199);
const _v201 = CssVar('--drawer-stack-shrink-offset');
const _v202 = CssOp('-', _v200, _v201);
const _v203 = CssOp('+', _v199, _v201);
const _v204 = CssVar('--drawer-swipe-movement-x');
const _v205 = CssVar('--drawer-snap-point-offset', CssNum(0, 'px'));
const _v206 = CssVar('--drawer-swipe-movement-y');
const _v207 = CssOp('+', _v205, _v206);
const _v208 = CssSeq([CssNum(0, '%'), CssNum(50, '%')]);
const _v209 = CssSeq([CssNum(100, '%'), CssNum(50, '%')]);
const _v210 = CssSeq([CssNum(50, '%'), CssNum(0, '%')]);
const _v211 = CssSeq([CssNum(50, '%'), CssNum(100, '%')]);
const _v212 = CssVar('--accent-400', null, 'accent400');
const _v213 = CssVar('--progress-color');
const _v214 = CssSeq([_v213, CssNum(90, '%')]);
const _v215 = CssFunction('color-mix', [_v44, _v214, _v7]);
const _v216 = CssVar('--accent-200', null, 'accent200');
const _v217 = CssVar('--danger-muted', null, 'dangerMuted');
const _v218 = CssVar('--info-muted', null, 'infoMuted');
const _v219 = CssVar('--primary-200', null, 'primary200');
const _v220 = CssVar('--success-muted', null, 'successMuted');
const _v221 = CssVar('--warning-muted', null, 'warningMuted');
const _v222 = CssVar('--fill-muted', null, 'fillMuted');
const _v223 = CssSeq([_v213, CssNum(40, '%')]);
const _v224 = CssFunction('color-mix', [_v44, _v223, _v7]);
const _v225 = CssSeq([_v81, CssNum(35, '%')]);
const _v226 = CssFunction('color-mix', [_v44, _v225, _v38]);
const _v227 = CssVar('--foreground-inverse', null, 'foregroundInverse');
const _v228 = CssVar('--info-strong', null, 'infoStrong');
const _v229 = CssColor(0xFF99A1AF, 'oklch(70.7% 0.022 261.325)');
const _v230 = CssVar('--secondary-400', null, 'secondary400');
const _v231 = CssColor(0x00FFFFFF, 'oklch(1 0 0 / 0)');
const _v232 = CssColor(
  0x0DFFFFFF,
  'oklch(1 0 0 / 0.05)',
  Color.from(alpha: 0.050919, red: 0.986034, green: 0.986034, blue: 0.995930),
);
const _v233 = CssOp('*', CssVar('--toast-index'), CssNum(0.04));
const _v234 = CssOp('-', CssNum(1), _v233);
const _v235 = CssFunction('max', [CssNum(0.84), CssCalc(_v234)]);
const _v236 = CssVar('--toast-height');
const _v237 = CssVar('--toast-frontmost-height', _v236);
const _v238 = CssVar('--toast-offset-y');
const _v239 = CssOp('*', _v238, CssNum(-1));
const _v240 = CssOp('*', CssVar('--toast-index'), CssVar('--toast-gap'));
const _v241 = CssOp('-', _v239, _v240);
const _v242 = CssVar('--toast-swipe-movement-y');
const _v243 = CssOp('+', _v241, _v242);
const _v244 = CssSeq([
  CssKeyword('circle'),
  CssKeyword('at'),
  CssNum(96, '%'),
  CssNum(12, '%'),
]);
const _v245 = CssColor(0xFF000000, 'black');
const _v246 = CssSeq([_v245, CssNum(0, '%')]);
const _v247 = CssSeq([_v245, CssNum(24, '%')]);
const _v248 = CssColor(
  0xD1000000,
  'oklch(0 0 0 / 0.82)',
  Color.from(alpha: 0.820735, red: 0.000207, green: 0.000207, blue: 0.001278),
);
const _v249 = CssSeq([_v248, CssNum(38, '%')]);
const _v250 = CssColor(
  0x61000000,
  'oklch(0 0 0 / 0.38)',
  Color.from(alpha: 0.381042, red: 0.000311, green: 0.000311, blue: 0.000067),
);
const _v251 = CssSeq([_v250, CssNum(58, '%')]);
const _v252 = CssSeq([_v7, CssNum(74, '%')]);
const _v253 = CssFunction('radial-gradient', [
  _v244,
  _v246,
  _v247,
  _v249,
  _v251,
  _v252,
]);
const _v254 = CssVar('--shell-header-height', CssNum(62, 'px'));
const _v255 = CssFunction('translatey', [CssNum(-120, '%')]);
const _v256 = CssVar('--ca-overlay-border', CssNum(2, 'px'));
const _v257 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(100, '%'),
  CssKeyword('round'),
  CssNum(9999, 'px'),
  CssNum(0),
  CssNum(0),
  CssNum(9999, 'px'),
]);
const _v258 = CssFunction('inset', [_v257]);
const _v259 = CssVar('--mi-toolbar-pe', CssKeyword('none'));
const _v260 = CssColor(
  0x73400C11,
  'oklch(0.25 0.08 20 / 0.45)',
  Color.from(alpha: 0.449755, red: 0.249439, green: 0.040175, blue: 0.066512),
);
const _v261 = CssSeq([CssNum(0), CssNum(1, 'px'), CssNum(1, 'px'), _v260]);
const _v262 = CssSeq([_v5, CssNum(10, '%')]);
const _v263 = CssFunction('color-mix', [_v4, _v262, _v7]);
const _v264 = CssColor(
  0x1A000000,
  'color-mix(in oklab, oklch(0 0 0) 10%, transparent)',
  Color.from(alpha: 0.103922, red: 0.002275, green: 0.002275, blue: 0.000314),
);
const _v265 = CssSeq([_v5, CssNum(8, '%')]);
const _v266 = CssFunction('color-mix', [_v4, _v265, _v7]);
const _v267 = CssColor(
  0x14000000,
  'color-mix(in oklab, oklch(0 0 0) 8%, transparent)',
  Color.from(alpha: 0.080368, red: 0.001310, green: 0.001310, blue: 0.002836),
);
const _v268 = CssSeq([CssColor(0xFFFE7DA8), CssNum(20, '%')]);
const _v269 = CssFunction('color-mix', [_v4, _v268, _v7]);
const _v270 = CssColor(
  0x33FE7DA8,
  'color-mix(in oklab, #fe7da8 20%, transparent)',
  Color.from(alpha: 0.200000, red: 0.993137, green: 0.483333, blue: 0.658824),
);
const _v271 = CssSeq([CssColor(0xFFFFD440), CssNum(50, '%')]);
const _v272 = CssFunction('color-mix', [_v4, _v271, _v7]);
const _v273 = CssColor(
  0x80FFD440,
  'color-mix(in oklab, #ffd440 50%, transparent)',
  Color.from(alpha: 0.501900, red: 0.999974, green: 0.828322, blue: 0.253846),
);
const _v274 = CssVar('--ink-16', null, 'ink16');
const _v275 = CssVar('--ink-6', null, 'ink6');
const _v276 = CssVar('--ink-8', null, 'ink8');
const _v277 = CssSeq([CssVar('--tw-scale-x'), CssVar('--tw-scale-y')]);
const _v278 = CssVar('--theme-shadow-sm', null, 'themeShadowSm');
const _v279 = CssVar('--theme-shadow-xs', null, 'themeShadowXs');
const _v280 = CssSeq([CssKeyword('to'), CssKeyword('top')]);
const _v281 = CssVar('--tw-gradient-stops');
const _v282 = CssFunction('linear-gradient', [_v281]);
const _v283 = CssSeq([
  CssKeyword('to'),
  CssKeyword('top'),
  CssKeyword('in'),
  CssKeyword('oklab'),
]);
const _v284 = CssColor(
  0x33FFFFFF,
  'oklch(1 0 0 / 0.2)',
  Color.from(alpha: 0.201164, red: 0.995858, green: 0.995562, blue: 0.999467),
);
const _v285 = CssVar('--tw-gradient-position');
const _v286 = CssVar('--tw-gradient-from');
const _v287 = CssVar('--tw-gradient-from-position');
const _v288 = CssVar('--tw-gradient-to');
const _v289 = CssVar('--tw-gradient-to-position');
const _v290 = CssList([
  _v285,
  CssSeq([_v286, _v287]),
  CssSeq([_v288, _v289]),
]);
const _v291 = CssVar('--tw-gradient-via-stops', _v290);
const _v292 = CssOp('+', CssNum(1, 'px'), _v33);
const _v293 = CssSeq([
  _v32,
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssCalc(_v292),
  _v36,
]);
const _v294 = CssSeq([_v39, CssNum(35, '%')]);
const _v295 = CssFunction('color-mix', [_v4, _v294, _v7]);
const _v296 = CssColor(
  0x59FFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 35%, transparent)',
  Color.from(alpha: 0.350429, red: 0.999318, green: 0.999318, blue: 0.999685),
);
const _v297 = CssSeq([_v38, CssNum(0, '%')]);
const _v298 = CssFunction('color-mix', [_v44, _v297, _v7]);
const _v299 = CssSeq([_v39, CssNum(0, '%')]);
const _v300 = CssFunction('color-mix', [_v4, _v299, _v7]);
const _v301 = CssColor(
  0x00000000,
  'color-mix(in oklab, oklch(1 0 0) 0%, transparent)',
);
const _v302 = CssVar('--tw-gradient-via');
const _v303 = CssVar('--tw-gradient-via-position');
const _v304 = CssList([
  _v285,
  CssSeq([_v286, _v287]),
  CssSeq([_v302, _v303]),
  CssSeq([_v288, _v289]),
]);
const _v305 = CssVar('--tw-gradient-via-stops');
const _v306 = CssSeq([_v38, CssNum(80, '%')]);
const _v307 = CssFunction('color-mix', [_v44, _v306, _v7]);
const _v308 = CssSeq([_v39, CssNum(80, '%')]);
const _v309 = CssFunction('color-mix', [_v4, _v308, _v7]);
const _v310 = CssColor(
  0xCCFFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 80%, transparent)',
  Color.from(alpha: 0.800368, red: 0.999871, green: 0.999874, blue: 0.999874),
);
const _v311 = CssKeyword('raft-status-pulse-background');
const _v312 = CssSeq([
  _v311,
  CssNum(1400, 'ms'),
  CssKeyword('ease-out'),
  CssKeyword('infinite'),
]);
const _v313 = CssKeyword('raft-toast-timeout-progress');
const _v314 = CssVar('--toast-progress-duration');
const _v315 = CssSeq([
  _v313,
  _v314,
  CssKeyword('linear'),
  CssKeyword('forwards'),
]);
const _v316 = CssFunction('cubic-bezier', [
  CssNum(0.4),
  CssNum(0),
  CssNum(0.6),
  CssNum(1),
]);
const _v317 = CssSeq([
  CssKeyword('pulse'),
  CssNum(2000, 'ms'),
  _v316,
  CssKeyword('infinite'),
]);
const _v318 = CssSeq([
  CssKeyword('spin'),
  CssNum(1000, 'ms'),
  CssKeyword('linear'),
  CssKeyword('infinite'),
]);
const _v319 = CssKeyword('antialiased');
const _v320 = CssKeyword('not-allowed');
const _v321 = CssColor(0xFF5B332E, 'oklch(0.37 0.06 27)');
const _v322 = CssColor(0xFFDB2C2B, 'oklch(0.58 0.21 27)');
const _v323 = CssColor(0xFFE36A23, 'oklch(0.66 0.17 46)');
const _v324 = CssVar('--ink', null, 'ink');
const _v325 = CssVar('--accent-soft', null, 'accentSoft');
const _v326 = CssVar('--danger-soft', null, 'dangerSoft');
const _v327 = CssVar('--primary-soft', null, 'primarySoft');
const _v328 = CssSeq([CssNum(16), CssSlash(), CssNum(9)]);
const _v329 = CssKeyword('min-content');
const _v330 = CssFunction('blur', [CssNum(40, 'px')]);
const _v331 = CssVar('--tw-backdrop-blur', CssSeq([]));
const _v332 = CssVar('--tw-backdrop-brightness', CssSeq([]));
const _v333 = CssVar('--tw-backdrop-contrast', CssSeq([]));
const _v334 = CssVar('--tw-backdrop-grayscale', CssSeq([]));
const _v335 = CssVar('--tw-backdrop-hue-rotate', CssSeq([]));
const _v336 = CssVar('--tw-backdrop-invert', CssSeq([]));
const _v337 = CssVar('--tw-backdrop-opacity', CssSeq([]));
const _v338 = CssVar('--tw-backdrop-saturate', CssSeq([]));
const _v339 = CssVar('--tw-backdrop-sepia', CssSeq([]));
const _v340 = CssSeq([
  _v331,
  _v332,
  _v333,
  _v334,
  _v335,
  _v336,
  _v337,
  _v338,
  _v339,
]);
const _v341 = CssFunction('blur', [CssNum(10, 'px')]);
const _v342 = CssFunction('blur', [CssNum(2, 'px')]);
const _v343 = CssFunction('blur', [CssNum(12, 'px')]);
const _v344 = CssSeq([_v245, CssNum(50, '%')]);
const _v345 = CssFunction('linear-gradient', [_v280, _v344, _v7]);
const _v346 = CssSeq([CssKeyword('to'), CssKeyword('right')]);
const _v347 = CssSeq([_v245, CssNum(24, 'px')]);
const _v348 = CssOp('-', CssNum(100, '%'), CssNum(24, 'px'));
const _v349 = CssSeq([_v245, CssCalc(_v348)]);
const _v350 = CssFunction('linear-gradient', [_v346, _v7, _v347, _v349, _v7]);
const _v351 = CssFunction('blur', [CssNum(4, 'px')]);
const _v352 = CssSeq([
  CssKeyword('in'),
  CssKeyword('oklab'),
  CssNum(180, 'deg'),
]);
const _v353 = CssColor(0x00000000, 'oklab(0% 0 0 / 0%)');
const _v354 = CssSeq([_v353, CssNum(30, '%')]);
const _v355 = CssColor(
  0x03000000,
  'oklab(0% 0 0 / 1%)',
  Color.from(alpha: 0.013676, red: 0.004354, green: 0.004354, blue: 0.002393),
);
const _v356 = CssSeq([_v355, CssNum(100, '%')]);
const _v357 = CssFunction('linear-gradient', [_v352, _v354, _v356]);
const _v358 = CssColor(
  0x1AFFFFFF,
  'oklab(100% 0 0 / 10%)',
  Color.from(alpha: 0.100429, red: 0.994815, green: 0.999979, blue: 0.998796),
);
const _v359 = CssSeq([_v358, CssNum(0, '%')]);
const _v360 = CssSeq([_v353, CssNum(100, '%')]);
const _v361 = CssFunction('linear-gradient', [_v352, _v359, _v360]);
const _v362 = CssColor(
  0x0AFFFFFF,
  'oklab(100% 0 0 / 4%)',
  Color.from(alpha: 0.040551, red: 0.993550, green: 0.993550, blue: 0.996343),
);
const _v363 = CssSeq([_v362, CssNum(0, '%')]);
const _v364 = CssFunction('linear-gradient', [_v352, _v363, _v360]);
const _v365 = CssColor(
  0x0DFFFFFF,
  'oklab(100% 0 0 / 5%)',
  Color.from(alpha: 0.050919, red: 0.986034, green: 0.986034, blue: 0.995930),
);
const _v366 = CssSeq([_v365, CssNum(0, '%')]);
const _v367 = CssFunction('linear-gradient', [_v352, _v366, _v356]);
const _v368 = CssColor(
  0x14FFFFFF,
  'oklab(100% 0 0 / 8%)',
  Color.from(alpha: 0.080368, red: 0.999237, green: 0.999237, blue: 0.999237),
);
const _v369 = CssSeq([_v368, CssNum(0, '%')]);
const _v370 = CssFunction('linear-gradient', [_v352, _v369, _v360]);
const _v371 = CssColor(
  0x08000000,
  'oklab(0% 0 0 / 3%)',
  Color.from(alpha: 0.033309, red: 0.004891, green: 0.004891, blue: 0.001950),
);
const _v372 = CssSeq([_v371, CssNum(100, '%')]);
const _v373 = CssFunction('linear-gradient', [_v352, _v369, _v372]);
const _v374 = CssFunction('linear-gradient', [_v96, _v7, _v38]);
const _v375 = CssVar('--ink-20', null, 'ink20');
const _v376 = CssVar('--ink-40', null, 'ink40');
const _v377 = CssOp('+', CssVar('--toast-gap'), CssNum(3, 'px'));
const _v378 = CssSeq([_v227, CssNum(45, '%')]);
const _v379 = CssFunction('color-mix', [_v44, _v378, _v7]);
const _v380 = CssVar('--color-brutal-lime-100', null, 'colorBrutalLime100');
const _v381 = CssVar('--color-brutal-orange-100', null, 'colorBrutalOrange100');
const _v382 = CssVar('--color-brutal-yellow-100', null, 'colorBrutalYellow100');
const _v383 = CssVar('--progress-indicator');
const _v384 = CssVar('--progress-track');
const _v385 = CssVar('--reference-badge', _v7);
const _v386 = CssVar('--status-color');
const _v387 = CssSeq([CssKeyword('in'), CssKeyword('oklch')]);
const _v388 = CssSeq([_v324, CssNum(4, '%')]);
const _v389 = CssFunction('color-mix', [_v387, _v388, _v38]);
const _v390 = CssVar('--ink-4', null, 'ink4');
const _v391 = CssFunction('color-mix', [_v387, _v390, _v38]);
const _v392 = CssColor(0xFF935B00, 'oklch(0.52 0.13 75)');
const _v393 = CssColor(0xFF784DB6, 'oklch(0.52 0.16 300)');
const _v394 = CssColor(0xFF008651, 'oklch(0.54 0.14 160)');
const _v395 = CssColor(0xFF0077CD, 'oklch(0.56 0.16 250)');
const _v396 = CssColor(0xFFED3E51, 'oklch(0.63 0.21 20)');
const _v397 = CssColor(0xFFF05943, 'oklch(0.66 0.19 31)');
const _v398 = CssColor(0xFFFF4D47, 'oklch(0.672 0.215 26.69)');
const _v399 = CssColor(0xFFDAF2E0, 'oklch(0.94 0.035 153.079)');
const _v400 = CssColor(0xFFFFEADC, 'oklch(0.955 0.035 50)');
const _v401 = CssColor(0xFFF0F0F0, 'oklch(0.955 0 0)');
const _v402 = CssColor(0xFFFFEEF3, 'oklch(0.965 0.019 358.59)');
const _v403 = CssColor(0xFFFFEEFB, 'oklch(0.966251 0.024944 333.728876)');
const _v404 = CssColor(0xFFE5F7FF, 'oklch(0.966 0.022 224.02)');
const _v405 = CssColor(
  0xCCF5F5F5,
  'oklch(0.9702 0 0 / 0.8)',
  Color.from(alpha: 0.797549, red: 0.961506, green: 0.961731, blue: 0.961407),
);
const _v406 = CssColor(
  0x66000000,
  'oklch(0 0 0 / 0.4)',
  Color.from(alpha: 0.401164, red: 0.000470, green: 0.000810, blue: 0.000341),
);
const _v407 = CssColor(
  0xB8000000,
  'oklch(0 0 0 / 0.72)',
  Color.from(alpha: 0.722451, red: 0.000008, green: 0.000623, blue: 0.000086),
);
const _v408 = CssSeq([_v212, CssNum(20, '%')]);
const _v409 = CssFunction('color-mix', [_v44, _v408, _v7]);
const _v410 = CssSeq([_v212, CssNum(35, '%')]);
const _v411 = CssFunction('color-mix', [_v44, _v410, _v7]);
const _v412 = CssSeq([_v212, CssNum(60, '%')]);
const _v413 = CssFunction('color-mix', [_v44, _v412, _v7]);
const _v414 = CssSeq([_v5, CssNum(15, '%')]);
const _v415 = CssFunction('color-mix', [_v4, _v414, _v7]);
const _v416 = CssColor(
  0x26000000,
  'color-mix(in oklab, oklch(0 0 0) 15%, transparent)',
  Color.from(alpha: 0.150980, red: 0.002572, green: 0.001592, blue: 0.000433),
);
const _v417 = CssSeq([_v5, CssNum(20, '%')]);
const _v418 = CssFunction('color-mix', [_v4, _v417, _v7]);
const _v419 = CssColor(
  0x33000000,
  'color-mix(in oklab, oklch(0 0 0) 20%, transparent)',
  Color.from(alpha: 0.201961, red: 0.000609, green: 0.000609, blue: 0.001780),
);
const _v420 = CssSeq([_v5, CssNum(3, '%')]);
const _v421 = CssFunction('color-mix', [_v4, _v420, _v7]);
const _v422 = CssColor(
  0x08000000,
  'color-mix(in oklab, oklch(0 0 0) 3%, transparent)',
  Color.from(alpha: 0.033309, red: 0.004891, green: 0.004891, blue: 0.001950),
);
const _v423 = CssSeq([_v5, CssNum(35, '%')]);
const _v424 = CssFunction('color-mix', [_v4, _v423, _v7]);
const _v425 = CssColor(
  0x59000000,
  'color-mix(in oklab, oklch(0 0 0) 35%, transparent)',
  Color.from(alpha: 0.350000, red: 0.000140, green: 0.000140, blue: 0.000420),
);
const _v426 = CssSeq([_v5, CssNum(5, '%')]);
const _v427 = CssFunction('color-mix', [_v4, _v426, _v7]);
const _v428 = CssColor(
  0x0D000000,
  'color-mix(in oklab, oklch(0 0 0) 5%, transparent)',
  Color.from(alpha: 0.052941, red: 0.003486, green: 0.003486, blue: 0.001525),
);
const _v429 = CssSeq([CssColor(0xFFFFFAEF), CssNum(60, '%')]);
const _v430 = CssFunction('color-mix', [_v4, _v429, _v7]);
const _v431 = CssColor(
  0x99FFFAEF,
  'color-mix(in oklab, #fffaef 60%, transparent)',
  Color.from(alpha: 0.600000, red: 0.999510, green: 0.980392, blue: 0.937255),
);
const _v432 = CssSeq([CssColor(0xFF27CCF3), CssNum(20, '%')]);
const _v433 = CssFunction('color-mix', [_v4, _v432, _v7]);
const _v434 = CssColor(
  0x3327CCF3,
  'color-mix(in oklab, #27ccf3 20%, transparent)',
  Color.from(alpha: 0.200000, red: 0.150000, green: 0.797059, blue: 0.952941),
);
const _v435 = CssSeq([CssColor(0xFF27CCF3), CssNum(30, '%')]);
const _v436 = CssFunction('color-mix', [_v4, _v435, _v7]);
const _v437 = CssColor(
  0x4D27CCF3,
  'color-mix(in oklab, #27ccf3 30%, transparent)',
  Color.from(alpha: 0.301961, red: 0.149733, green: 0.799083, blue: 0.942857),
);
const _v438 = CssSeq([CssColor(0xFFF8A16F), CssNum(25, '%')]);
const _v439 = CssFunction('color-mix', [_v4, _v438, _v7]);
const _v440 = CssColor(
  0x40F8A16F,
  'color-mix(in oklab, #f8a16f 25%, transparent)',
  Color.from(alpha: 0.250000, red: 0.967647, green: 0.622549, blue: 0.434314),
);
const _v441 = CssSeq([CssColor(0xFFF8A16F), CssNum(90, '%')]);
const _v442 = CssFunction('color-mix', [_v4, _v441, _v7]);
const _v443 = CssColor(
  0xE6F8A16F,
  'color-mix(in oklab, #f8a16f 90%, transparent)',
  Color.from(alpha: 0.898775, red: 0.975389, green: 0.631102, blue: 0.434313),
);
const _v444 = CssSeq([CssColor(0xFFFE7DA8), CssNum(30, '%')]);
const _v445 = CssFunction('color-mix', [_v4, _v444, _v7]);
const _v446 = CssColor(
  0x4DFE7DA8,
  'color-mix(in oklab, #fe7da8 30%, transparent)',
  Color.from(alpha: 0.301961, red: 0.993888, green: 0.487395, blue: 0.657143),
);
const _v447 = CssSeq([CssColor(0xFFC0B9B1), CssNum(25, '%')]);
const _v448 = CssFunction('color-mix', [_v4, _v447, _v7]);
const _v449 = CssColor(
  0x40C0B9B1,
  'color-mix(in oklab, #c0b9b1 25%, transparent)',
  Color.from(alpha: 0.250000, red: 0.748039, green: 0.716667, blue: 0.685294),
);
const _v450 = CssSeq([CssColor(0xFFC0B9B1), CssNum(30, '%')]);
const _v451 = CssFunction('color-mix', [_v4, _v450, _v7]);
const _v452 = CssColor(
  0x4DC0B9B1,
  'color-mix(in oklab, #c0b9b1 30%, transparent)',
  Color.from(alpha: 0.301961, red: 0.747135, green: 0.721161, blue: 0.683117),
);
const _v453 = CssSeq([CssColor(0xFFFFD440), CssNum(30, '%')]);
const _v454 = CssFunction('color-mix', [_v4, _v453, _v7]);
const _v455 = CssColor(
  0x4DFFD440,
  'color-mix(in oklab, #ffd440 30%, transparent)',
  Color.from(alpha: 0.300245, red: 0.999812, green: 0.830632, blue: 0.251849),
);
const _v456 = CssKeyword('padding-box');
const _v457 = CssSeq([_v137, CssNum(80, '%')]);
const _v458 = CssFunction('color-mix', [_v44, _v457, _v7]);
const _v459 = CssSeq([_v222, CssNum(35, '%')]);
const _v460 = CssFunction('color-mix', [_v44, _v459, _v7]);
const _v461 = CssSeq([_v222, CssNum(40, '%')]);
const _v462 = CssFunction('color-mix', [_v44, _v461, _v7]);
const _v463 = CssSeq([_v222, CssNum(50, '%')]);
const _v464 = CssFunction('color-mix', [_v44, _v463, _v7]);
const _v465 = CssSeq([_v222, CssNum(70, '%')]);
const _v466 = CssFunction('color-mix', [_v44, _v465, _v7]);
const _v467 = CssSeq([_v227, CssNum(10, '%')]);
const _v468 = CssFunction('color-mix', [_v44, _v467, _v7]);
const _v469 = CssSeq([_v22, CssNum(35, '%')]);
const _v470 = CssFunction('color-mix', [_v44, _v469, _v7]);
const _v471 = CssSeq([_v0, CssNum(10, '%')]);
const _v472 = CssFunction('color-mix', [_v44, _v471, _v7]);
const _v473 = CssSeq([_v0, CssNum(12, '%')]);
const _v474 = CssFunction('color-mix', [_v44, _v473, _v7]);
const _v475 = CssSeq([_v0, CssNum(8, '%')]);
const _v476 = CssFunction('color-mix', [_v44, _v475, _v7]);
const _v477 = CssVar('--inactive', null, 'inactive');
const _v478 = CssVar('--info-soft', null, 'infoSoft');
const _v479 = CssSeq([_v478, CssNum(50, '%')]);
const _v480 = CssFunction('color-mix', [_v44, _v479, _v7]);
const _v481 = CssSeq([_v62, CssNum(80, '%')]);
const _v482 = CssFunction('color-mix', [_v44, _v481, _v7]);
const _v483 = CssVar('--layer-backdrop', null, 'layerBackdrop');
const _v484 = CssVar('--layer-card', null, 'layerCard');
const _v485 = CssVar('--layer-hud', null, 'layerHud');
const _v486 = CssSeq([_v485, CssNum(85, '%')]);
const _v487 = CssFunction('color-mix', [_v44, _v486, _v7]);
const _v488 = CssVar('--layer-inset', null, 'layerInset');
const _v489 = CssSeq([_v38, CssNum(30, '%')]);
const _v490 = CssFunction('color-mix', [_v44, _v489, _v7]);
const _v491 = CssSeq([_v38, CssNum(70, '%')]);
const _v492 = CssFunction('color-mix', [_v44, _v491, _v7]);
const _v493 = CssVar('--layer-popover', null, 'layerPopover');
const _v494 = CssVar('--primary-100', null, 'primary100');
const _v495 = CssSeq([_v118, CssNum(40, '%')]);
const _v496 = CssFunction('color-mix', [_v44, _v495, _v7]);
const _v497 = CssSeq([_v118, CssNum(60, '%')]);
const _v498 = CssFunction('color-mix', [_v44, _v497, _v7]);
const _v499 = CssSeq([_v118, CssNum(70, '%')]);
const _v500 = CssFunction('color-mix', [_v44, _v499, _v7]);
const _v501 = CssSeq([_v118, CssNum(80, '%')]);
const _v502 = CssFunction('color-mix', [_v44, _v501, _v7]);
const _v503 = CssSeq([_v118, CssNum(20, '%')]);
const _v504 = CssFunction('color-mix', [_v44, _v503, _v7]);
const _v505 = CssVar('--secondary-100', null, 'secondary100');
const _v506 = CssVar('--secondary-200', null, 'secondary200');
const _v507 = CssVar('--success-soft', null, 'successSoft');
const _v508 = CssSeq([_v63, CssNum(30, '%')]);
const _v509 = CssFunction('color-mix', [_v44, _v508, _v7]);
const _v510 = CssSeq([_v63, CssNum(80, '%')]);
const _v511 = CssFunction('color-mix', [_v44, _v510, _v7]);
const _v512 = CssVar('--task-status-closed', null, 'taskStatusClosed');
const _v513 = CssVar('--task-status-closed-soft', null, 'taskStatusClosedSoft');
const _v514 = CssVar('--task-status-done', null, 'taskStatusDone');
const _v515 = CssVar('--task-status-done-soft', null, 'taskStatusDoneSoft');
const _v516 = CssVar('--task-status-in-progress', null, 'taskStatusInProgress');
const _v517 = CssVar(
  '--task-status-in-progress-soft',
  null,
  'taskStatusInProgressSoft',
);
const _v518 = CssVar('--task-status-in-review', null, 'taskStatusInReview');
const _v519 = CssVar(
  '--task-status-in-review-soft',
  null,
  'taskStatusInReviewSoft',
);
const _v520 = CssVar('--task-status-todo', null, 'taskStatusTodo');
const _v521 = CssVar('--task-status-todo-soft', null, 'taskStatusTodoSoft');
const _v522 = CssVar('--warning-soft', null, 'warningSoft');
const _v523 = CssSeq([_v64, CssNum(80, '%')]);
const _v524 = CssFunction('color-mix', [_v44, _v523, _v7]);
const _v525 = CssSeq([_v39, CssNum(6, '%')]);
const _v526 = CssFunction('color-mix', [_v4, _v525, _v7]);
const _v527 = CssColor(
  0x0FFFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 6%, transparent)',
  Color.from(alpha: 0.060797, red: 0.996418, green: 0.996418, blue: 0.994457),
);
const _v528 = CssSeq([_v39, CssNum(70, '%')]);
const _v529 = CssFunction('color-mix', [_v4, _v528, _v7]);
const _v530 = CssColor(
  0xB3FFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 70%, transparent)',
  Color.from(alpha: 0.700368, red: 0.999349, green: 0.999997, blue: 0.999869),
);
const _v531 = CssSeq([_v39, CssNum(75, '%')]);
const _v532 = CssFunction('color-mix', [_v4, _v531, _v7]);
const _v533 = CssColor(
  0xBFFFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 75%, transparent)',
  Color.from(alpha: 0.750980, red: 0.998418, green: 0.999726, blue: 0.999706),
);
const _v534 = CssSeq([_v39, CssNum(85, '%')]);
const _v535 = CssFunction('color-mix', [_v4, _v534, _v7]);
const _v536 = CssColor(
  0xD9FFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 85%, transparent)',
  Color.from(alpha: 0.850429, red: 0.999650, green: 0.999650, blue: 0.999870),
);
const _v537 = CssSeq([_v386, CssNum(58, '%')]);
const _v538 = CssFunction('color-mix', [_v387, _v537, _v7]);
const _v539 = CssVar(
  '--task-status-closed-strong',
  null,
  'taskStatusClosedStrong',
);
const _v540 = CssSeq([_v539, CssNum(35, '%')]);
const _v541 = CssFunction('color-mix', [_v387, _v540, _v7]);
const _v542 = CssVar('--task-status-done-strong', null, 'taskStatusDoneStrong');
const _v543 = CssSeq([_v542, CssNum(35, '%')]);
const _v544 = CssFunction('color-mix', [_v387, _v543, _v7]);
const _v545 = CssVar(
  '--task-status-in-progress-strong',
  null,
  'taskStatusInProgressStrong',
);
const _v546 = CssSeq([_v545, CssNum(35, '%')]);
const _v547 = CssFunction('color-mix', [_v387, _v546, _v7]);
const _v548 = CssVar(
  '--task-status-in-review-strong',
  null,
  'taskStatusInReviewStrong',
);
const _v549 = CssSeq([_v548, CssNum(35, '%')]);
const _v550 = CssFunction('color-mix', [_v387, _v549, _v7]);
const _v551 = CssVar('--task-status-todo-strong', null, 'taskStatusTodoStrong');
const _v552 = CssSeq([_v551, CssNum(35, '%')]);
const _v553 = CssFunction('color-mix', [_v387, _v552, _v7]);
const _v554 = CssColor(
  0x4D000000,
  'oklch(0 0 0 / 0.3)',
  Color.from(alpha: 0.303922, red: 0.001423, green: 0.001423, blue: 0.000316),
);
const _v555 = CssVar('--accent-500', null, 'accent500');
const _v556 = CssSeq([_v5, CssNum(30, '%')]);
const _v557 = CssFunction('color-mix', [_v4, _v556, _v7]);
const _v558 = CssColor(
  0x4D000000,
  'color-mix(in oklab, oklch(0 0 0) 30%, transparent)',
  Color.from(alpha: 0.303922, red: 0.001423, green: 0.001423, blue: 0.000316),
);
const _v559 = CssSeq([_v35, CssNum(20, '%')]);
const _v560 = CssFunction('color-mix', [_v44, _v559, _v7]);
const _v561 = CssSeq([_v35, CssNum(40, '%')]);
const _v562 = CssFunction('color-mix', [_v44, _v561, _v7]);
const _v563 = CssVar('--line-field', null, 'lineField');
const _v564 = CssSeq([_v81, CssNum(70, '%')]);
const _v565 = CssFunction('color-mix', [_v44, _v564, _v7]);
const _v566 = CssSeq([_v81, CssNum(75, '%')]);
const _v567 = CssFunction('color-mix', [_v44, _v566, _v7]);
const _v568 = CssSeq([_v81, CssNum(90, '%')]);
const _v569 = CssFunction('color-mix', [_v44, _v568, _v7]);
const _v570 = CssSeq([_v43, CssNum(20, '%')]);
const _v571 = CssFunction('color-mix', [_v44, _v570, _v7]);
const _v572 = CssSeq([_v43, CssNum(30, '%')]);
const _v573 = CssFunction('color-mix', [_v44, _v572, _v7]);
const _v574 = CssVar('--primary-500', null, 'primary500');
const _v575 = CssVar('--secondary-500', null, 'secondary500');
const _v576 = CssSeq([_v39, CssNum(25, '%')]);
const _v577 = CssFunction('color-mix', [_v4, _v576, _v7]);
const _v578 = CssColor(
  0x40FFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 25%, transparent)',
  Color.from(alpha: 0.250551, red: 0.997440, green: 0.999538, blue: 0.999504),
);
const _v579 = CssVar('--ph-meta-end', CssKeyword('auto'));
const _v580 = CssSeq([CssNum(1), CssSlash(), CssNum(-1)]);
const _v581 = CssVar('--banner-action-col', CssNum(2));
const _v582 = CssVar('--banner-text-col', CssNum(1));
const _v583 = CssVar('--card-text-col', CssNum(1));
const _v584 = CssVar('--card-trailing-col', CssNum(2));
const _v585 = CssVar('--ph-meta-col', CssKeyword('auto'));
const _v586 = CssVar('--ph-text-col', CssKeyword('auto'));
const _v587 = CssColor(0xFFE5E5E2, 'oklch(0.92 0.003 106.42)');
const _v588 = CssColor(0xFFB1B1AE, 'oklch(0.76 0.005 106.42)');
const _v589 = CssColor(0xFFFCB26F, 'oklch(0.82 0.12 61.907)');
const _v590 = CssColor(0xFF6CCDEA, 'oklch(0.8 0.1 220)');
const _v591 = CssSeq([_v213, CssNum(55, '%')]);
const _v592 = CssFunction('color-mix', [_v44, _v591, _v7]);
const _v593 = CssColor(
  0x24FAFAF7,
  'oklch(0.985 0.004 106.42 / 0.14)',
  Color.from(alpha: 0.141103, red: 0.960494, green: 0.960494, blue: 0.967144),
);
const _v594 = CssColor(
  0x12FAFAF7,
  'oklch(0.985 0.004 106.42 / 0.07)',
  Color.from(alpha: 0.070551, red: 0.981243, green: 0.981409, blue: 0.925456),
);
const _v595 = CssSeq([_v324, CssNum(8, '%')]);
const _v596 = CssFunction('color-mix', [_v387, _v595, _v38]);
const _v597 = CssColor(
  0x14FFFFFF,
  'oklch(1 0 0 / 0.08)',
  Color.from(alpha: 0.080368, red: 0.999237, green: 0.999237, blue: 0.999237),
);
const _v598 = CssColor(
  0x29000000,
  'oklch(0 0 0 / 0.16)',
  Color.from(alpha: 0.162696, red: 0.001028, green: 0.001028, blue: 0.000191),
);
const _v599 = CssFunction('linear-gradient', [_v96, _v7, _v598]);
const _v600 = CssColor(0xFF0B0B09, 'oklch(0.15 0.004 106.42)');
const _v601 = CssColor(
  0xD91F1F1D,
  'oklch(0.24 0.005 106.42 / 0.85)',
  Color.from(alpha: 0.847978, red: 0.118010, green: 0.118010, blue: 0.113385),
);
const _v602 = CssColor(0xFF89202B, 'oklch(0.42 0.14 20)');
const _v603 = CssColor(0xFF6C4300, 'oklch(0.42 0.1 75)');
const _v604 = CssColor(0xFF555552, 'oklch(0.45 0.006 106.42)');
const _v605 = CssColor(
  0xD9555552,
  'oklch(0.45 0.006 106.42 / 0.85)',
  Color.from(alpha: 0.847978, red: 0.330742, green: 0.330742, blue: 0.321493),
);
const _v606 = CssColor(0xFF005932, 'oklch(0.4 0.11 160)');
const _v607 = CssColor(0xFF004985, 'oklch(0.4 0.12 250)');
const _v608 = CssColor(0xFF543282, 'oklch(0.4 0.13 300)');
const _v609 = CssColor(
  0x2E885538,
  'oklch(0.5 0.08 50 / 0.18)',
  Color.from(alpha: 0.180368, red: 0.534161, green: 0.321382, blue: 0.207110),
);
const _v610 = CssColor(
  0x2E167641,
  'oklch(0.5 0.12 153 / 0.18)',
  Color.from(alpha: 0.180368, red: 0.080537, green: 0.451834, blue: 0.250594),
);
const _v611 = CssSeq([_v68, CssNum(80, '%')]);
const _v612 = CssFunction('color-mix', [_v44, _v611, _v7]);
const _v613 = CssSeq([_v484, CssNum(60, '%')]);
const _v614 = CssFunction('color-mix', [_v44, _v613, _v7]);
const _v615 = CssSeq([_v118, CssNum(30, '%')]);
const _v616 = CssFunction('color-mix', [_v44, _v615, _v7]);
const _v617 = CssOp('+', CssNum(2, 'px'), _v33);
const _v618 = CssSeq([
  _v32,
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssCalc(_v617),
  _v36,
]);
const _v619 = CssColor(
  0x59555552,
  'oklch(0.45 0.006 106.42 / 0.35)',
  Color.from(alpha: 0.348284, red: 0.334522, green: 0.334722, blue: 0.322176),
);
const _v620 = CssColor(
  0x59E5E5E2,
  'oklch(0.92 0.003 106.42 / 0.35)',
  Color.from(alpha: 0.348284, red: 0.896281, green: 0.896532, blue: 0.887121),
);
const _v621 = CssSeq([_v68, CssNum(20, '%')]);
const _v622 = CssFunction('color-mix', [_v387, _v621, _v488]);
const _v623 = CssColor(0xFF171715, 'oklch(0.205 0.004 106.42)');
const _v624 = CssColor(0xFF292928, 'oklch(0.28 0.002 106.42)');
const _v625 = CssColor(
  0x80000000,
  'oklch(0 0 0 / 0.5)',
  Color.from(alpha: 0.501961, red: 0.000050, green: 0.000050, blue: 0.000042),
);
const _v626 = CssVar('--tw-shadow-color', _v625);
const _v627 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v626,
]);
const _v628 = CssColor(
  0x73000000,
  'oklch(0 0 0 / 0.45)',
  Color.from(alpha: 0.451777, red: 0.000050, green: 0.000050, blue: 0.000838),
);
const _v629 = CssVar('--tw-shadow-color', _v628);
const _v630 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(1, 'px'), _v629]);
const _v631 = CssColor(
  0x40000000,
  'oklch(0 0 0 / 0.25)',
  Color.from(alpha: 0.252022, red: 0.001202, green: 0.001202, blue: 0.000285),
);
const _v632 = CssVar('--tw-shadow-color', _v631);
const _v633 = CssSeq([CssNum(0), CssNum(2, 'px'), CssNum(4, 'px'), _v632]);
const _v634 = CssVar('--tw-shadow-color', _v406);
const _v635 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1.5, 'px'),
  CssNum(-1, 'px'),
  _v634,
]);
const _v636 = CssVar('--tw-shadow-color', _v574);
const _v637 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(0.5, 'px'),
  _v636,
]);
const _v638 = CssSeq([_v574, CssNum(35, '%')]);
const _v639 = CssFunction('color-mix', [_v4, _v638, _v7]);
const _v640 = CssVar('--tw-shadow-color', _v639);
const _v641 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(0.5, 'px'),
  _v640,
]);
const _v642 = CssColor(
  0x1FFFFFFF,
  'oklch(1 0 0 / 0.12)',
  Color.from(alpha: 0.120613, red: 0.997917, green: 0.999162, blue: 0.998737),
);
const _v643 = CssVar('--tw-shadow-color', _v642);
const _v644 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(0.5, 'px'),
  _v643,
]);
const _v645 = CssColor(0xFF424241, 'oklch(0.38 0.002 106.42)');
const _v646 = CssVar('--theme-shadow-xl', null, 'themeShadowXl');
const _v647 = CssColor(0xFF181816, 'oklch(0.21 0.004 106.42)');
const _v648 = CssColor(
  0x8C000000,
  'oklch(0 0 0 / 0.55)',
  Color.from(alpha: 0.550000, red: 0.000089, green: 0.000089, blue: 0.000357),
);
const _v649 = CssVar('--tw-drop-shadow-color', _v648);
const _v650 = CssSeq([CssNum(0), CssNum(1, 'px'), CssNum(0), _v649]);
const _v651 = CssFunction('drop-shadow', [_v650]);
const _v652 = CssVar('--tw-drop-shadow-size');
const _v653 = CssVar('--tw-blur', CssSeq([]));
const _v654 = CssVar('--tw-brightness', CssSeq([]));
const _v655 = CssVar('--tw-contrast', CssSeq([]));
const _v656 = CssVar('--tw-grayscale', CssSeq([]));
const _v657 = CssVar('--tw-hue-rotate', CssSeq([]));
const _v658 = CssVar('--tw-invert', CssSeq([]));
const _v659 = CssVar('--tw-saturate', CssSeq([]));
const _v660 = CssVar('--tw-sepia', CssSeq([]));
const _v661 = CssVar('--tw-drop-shadow', CssSeq([]));
const _v662 = CssSeq([
  _v653,
  _v654,
  _v655,
  _v656,
  _v657,
  _v658,
  _v659,
  _v660,
  _v661,
]);
const _v663 = CssVar('--tw-ring-offset-color');
const _v664 = CssSeq([_v32, CssNum(0), CssNum(0), CssNum(0), _v33, _v663]);
const _v665 = CssOp('+', CssNum(0.5, 'px'), _v33);
const _v666 = CssSeq([
  _v32,
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssCalc(_v665),
  _v36,
]);
const _v667 = CssSeq([_v212, CssNum(70, '%')]);
const _v668 = CssFunction('color-mix', [_v44, _v667, _v7]);
const _v669 = CssVar('--tw-shadow-color', _v81);
const _v670 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(1, 'px'), _v669]);
const _v671 = CssSeq([
  CssNum(0),
  CssNum(16, 'px'),
  CssNum(32, 'px'),
  CssNum(-8, 'px'),
  _v629,
]);
const _v672 = CssVar('--foreground-hover', null, 'foregroundHover');
const _v673 = CssColor(
  0x38FAFAF7,
  'oklch(0.985 0.004 106.42 / 0.22)',
  Color.from(alpha: 0.219877, red: 0.978183, green: 0.977645, blue: 0.958635),
);
const _v674 = CssColor(
  0x1CFAFAF7,
  'oklch(0.985 0.004 106.42 / 0.11)',
  Color.from(alpha: 0.109816, red: 0.951609, green: 0.951609, blue: 0.949688),
);
const _v675 = CssSeq([_v324, CssNum(5, '%')]);
const _v676 = CssFunction('color-mix', [_v387, _v675, _v38]);
const _v677 = CssColor(0xFF683833, 'oklch(0.4 0.07 27)');
const _v678 = CssColor(
  0xE6696965,
  'oklch(0.52 0.006 106.42 / 0.9)',
  Color.from(alpha: 0.898775, red: 0.412531, green: 0.412531, blue: 0.395044),
);
const _v679 = CssColor(0xFFE63935, 'oklch(0.61 0.21 27)');
const _v680 = CssColor(0xFFEE7330, 'oklch(0.69 0.17 46)');
const _v681 = CssColor(0xFF191815, 'oklch(0.21 0.006 106.42)');
const _v682 = CssColor(0xFFFAFAF7, 'oklch(0.985 0.004 106.42)');
const _v683 = CssSeq([_v0, CssNum(75, '%')]);
const _v684 = CssFunction('color-mix', [_v44, _v683, _v7]);
const _v685 = CssVar('--tw-shadow-color', _v554);
const _v686 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1.5, 'px'),
  _v685,
]);
const _v687 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(1, 'px'), _v634]);
const _v688 = CssColor(
  0x0AFAFAF7,
  'oklch(0.985 0.004 106.42 / 0.04)',
  Color.from(alpha: 0.039203, red: 0.954685, green: 0.954685, blue: 0.969524),
);
const _v689 = CssVar('--tw-shadow-color', _v688);
const _v690 = CssSeq([CssNum(0), CssNum(1, 'px'), CssNum(0), _v689]);
const _v691 = CssList([_v686, _v687, _v690]);
const _v692 = CssVar('--tw-shadow-color', _v563);
const _v693 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(1, 'px'), _v692]);
const _v694 = CssList([_v686, _v693, _v690]);
const _v695 = CssFunction('saturate', [CssNum(100, '%')]);
const _v696 = CssVar('--tw-shadow-color', _v597);
const _v697 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(1, 'px'), _v696]);
const _v698 = CssColor(
  0x29FFFFFF,
  'oklch(1 0 0 / 0.16)',
  Color.from(alpha: 0.160245, red: 0.998479, green: 0.998377, blue: 0.999309),
);
const _v699 = CssVar('--tw-shadow-color', _v698);
const _v700 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(1, 'px'), _v699]);
const _v701 = CssVar('--tw-shadow-color', _v594);
const _v702 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(0),
  _v701,
]);
const _v703 = CssSeq([CssNum(0), CssNum(1.5, 'px'), CssNum(0), _v626]);
const _v704 = CssList([_v702, _v630, _v703]);
const _v705 = CssColor(
  0x0AFFFFFF,
  'oklch(1 0 0 / 0.04)',
  Color.from(alpha: 0.040551, red: 0.993550, green: 0.993550, blue: 0.996343),
);
const _v706 = CssVar('--tw-shadow-color', _v705);
const _v707 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(0),
  _v706,
]);
const _v708 = CssColor(
  0x59000000,
  'oklch(0 0 0 / 0.35)',
  Color.from(alpha: 0.350000, red: 0.000140, green: 0.000140, blue: 0.000420),
);
const _v709 = CssVar('--tw-shadow-color', _v708);
const _v710 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(1, 'px'), _v709]);
const _v711 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(0),
  _v696,
]);
const _v712 = CssVar('--tw-shadow-color', _v213);
const _v713 = CssSeq([CssNum(0), CssNum(1, 'px'), CssNum(1, 'px'), _v712]);
const _v714 = CssSeq([CssNum(0), CssNum(2, 'px'), CssNum(3, 'px'), _v712]);
const _v715 = CssList([_v711, _v713, _v714]);
const _v716 = CssSeq([_v213, CssNum(14, '%')]);
const _v717 = CssFunction('color-mix', [_v44, _v716, _v7]);
const _v718 = CssVar('--tw-shadow-color', _v717);
const _v719 = CssSeq([CssNum(0), CssNum(1, 'px'), CssNum(1, 'px'), _v718]);
const _v720 = CssSeq([_v213, CssNum(7, '%')]);
const _v721 = CssFunction('color-mix', [_v44, _v720, _v7]);
const _v722 = CssVar('--tw-shadow-color', _v721);
const _v723 = CssSeq([CssNum(0), CssNum(2, 'px'), CssNum(3, 'px'), _v722]);
const _v724 = CssList([_v711, _v719, _v723]);
const _v725 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1, 'px'),
  _v709,
]);
const _v726 = CssColor(
  0x08FAFAF7,
  'oklch(0.985 0.004 106.42 / 0.03)',
  Color.from(alpha: 0.031348, red: 0.950292, green: 0.950292, blue: 0.944410),
);
const _v727 = CssVar('--tw-shadow-color', _v726);
const _v728 = CssSeq([CssNum(0), CssNum(1, 'px'), CssNum(0), _v727]);
const _v729 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(2, 'px'),
  _v685,
]);
const _v730 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v709,
]);
const _v731 = CssList([_v729, _v730, _v690]);
const _v732 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(2, 'px'),
  _v709,
]);
const _v733 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v634,
]);
const _v734 = CssList([_v732, _v733, _v690]);
const _v735 = CssColor(0xFF3D3D3A, 'oklch(0.36 0.006 106.42)');
const _v736 = CssColor(0xFFFF7E77, 'oklch(0.78 0.19 25)');
const _v737 = CssColor(0xFFD3C398, 'oklch(0.82 0.06 90)');
const _v738 = CssColor(0xFF9CE4BD, 'oklch(0.86 0.09 160)');
const _v739 = CssColor(0xFFB7D8FB, 'oklch(0.87 0.06 250)');
const _v740 = CssColor(0xFFDACCF7, 'oklch(0.87 0.06 300)');
const _v741 = CssColor(0xFFD4D4D4, 'oklch(0.87 0 0)');
const _v742 = CssColor(0xFFFDC8C9, 'oklch(0.88 0.06 18)');
const _v743 = CssColor(0xFFF7D69E, 'oklch(0.89 0.08 80)');
const _v744 = CssColor(0xFFBEBDBC, 'oklch(0.8 0.002 67.77)');
const _v745 = CssColor(0xFFFF8C8B, 'oklch(0.8 0.17 22)');
const _v746 = CssVar('--danger-strong', null, 'dangerStrong');
const _v747 = CssSeq([_v0, CssNum(35, '%')]);
const _v748 = CssFunction('color-mix', [_v44, _v747, _v7]);
const _v749 = CssSeq([_v0, CssNum(40, '%')]);
const _v750 = CssFunction('color-mix', [_v44, _v749, _v7]);
const _v751 = CssSeq([_v0, CssNum(50, '%')]);
const _v752 = CssFunction('color-mix', [_v44, _v751, _v7]);
const _v753 = CssVar('--secondary-300', null, 'secondary300');
const _v754 = CssVar('--foreground-disabled', null, 'foregroundDisabled');
const _v755 = CssSeq([_v0, CssNum(30, '%')]);
const _v756 = CssFunction('color-mix', [_v44, _v755, _v7]);
const _v757 = CssSeq([_v324, CssNum(1, '%')]);
const _v758 = CssFunction('color-mix', [_v387, _v757, _v38]);
const _v759 = CssSeq([_v245, CssNum(22, '%')]);
const _v760 = CssSeq([_v648, CssNum(48, '%')]);
const _v761 = CssSeq([_v7, CssNum(100, '%')]);
const _v762 = CssFunction('linear-gradient', [
  _v96,
  _v246,
  _v759,
  _v760,
  _v761,
]);
const _v763 = CssFunction('blur', [CssNum(14, 'px')]);
const _v764 = CssFunction('saturate', [CssNum(125, '%')]);
const _v765 = CssSeq([_v68, CssNum(0, '%')]);
const _v766 = CssSeq([_v68, CssNum(40, '%')]);
const _v767 = CssFunction('linear-gradient', [_v96, _v765, _v766, _v761]);
const _v768 = CssSeq([_v68, CssNum(48, '%')]);
const _v769 = CssFunction('color-mix', [_v387, _v768, _v7]);
const _v770 = CssSeq([_v769, CssNum(0, '%')]);
const _v771 = CssSeq([_v68, CssNum(18, '%')]);
const _v772 = CssFunction('color-mix', [_v387, _v771, _v7]);
const _v773 = CssSeq([_v772, CssNum(40, '%')]);
const _v774 = CssFunction('linear-gradient', [_v96, _v770, _v773, _v761]);
const _v775 = CssSeq([_v68, CssNum(28, '%')]);
const _v776 = CssSeq([_v68, CssNum(52, '%')]);
const _v777 = CssFunction('linear-gradient', [
  _v96,
  _v765,
  _v775,
  _v776,
  _v761,
]);
const _v778 = CssSeq([_v68, CssNum(82, '%')]);
const _v779 = CssFunction('color-mix', [_v387, _v778, _v7]);
const _v780 = CssSeq([_v779, CssNum(52, '%')]);
const _v781 = CssFunction('linear-gradient', [
  _v96,
  _v765,
  _v775,
  _v780,
  _v761,
]);
const _v782 = CssColor(
  0x1FFFFFFF,
  'oklab(100% 0 0 / 12%)',
  Color.from(alpha: 0.120613, red: 0.997917, green: 0.999162, blue: 0.998737),
);
const _v783 = CssSeq([_v782, CssNum(0, '%')]);
const _v784 = CssColor(
  0x0F000000,
  'oklab(0% 0 0 / 6%)',
  Color.from(alpha: 0.060735, red: 0.002258, green: 0.002258, blue: 0.000297),
);
const _v785 = CssSeq([_v784, CssNum(100, '%')]);
const _v786 = CssFunction('linear-gradient', [_v352, _v783, _v785]);
const _v787 = CssSeq([_v81, CssNum(45, '%')]);
const _v788 = CssFunction('color-mix', [_v44, _v787, _v7]);
const _v789 = CssFunction('blur', [CssNum(1, 'px')]);
const _v790 = CssKeyword('srgb-linear');
const _v791 = CssSeq([CssKeyword('in'), _v790]);
const _v792 = CssSeq([_v118, CssNum(86, '%')]);
const _v793 = CssFunction('color-mix', [_v791, _v792, _v324]);
const _v794 = CssVar('--foreground-active', null, 'foregroundActive');
const _v795 = CssSeq([_v39, CssNum(90, '%')]);
const _v796 = CssFunction('color-mix', [_v4, _v795, _v7]);
const _v797 = CssColor(
  0xE6FFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 90%, transparent)',
  Color.from(alpha: 0.900368, red: 0.999583, green: 0.999998, blue: 0.999898),
);
const _v798 = CssVar('--tw-shadow-color', _v245);
const _v799 = CssSeq([
  CssNum(4, 'px'),
  CssNum(4, 'px'),
  CssNum(0),
  CssNum(0),
  _v798,
]);
const _v800 = CssSeq([_v118, CssNum(94, '%')]);
const _v801 = CssFunction('color-mix', [_v791, _v800, _v324]);
const _v802 = CssColor(
  0x05000000,
  'oklch(0 0 0 / 0.02)',
  Color.from(alpha: 0.021532, red: 0.003705, green: 0.003705, blue: 0.001744),
);
const _v803 = CssVar('--tw-shadow-color', _v802);
const _v804 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1, 'px'),
  CssNum(-1, 'px'),
  _v803,
]);
const _v805 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v669,
]);
const _v806 = CssVar('--line', null, 'line');
const _v807 = CssVar('--primary-hover', null, 'primaryHover');
const _v808 = CssVar('--primary-glow', null, 'primaryGlow');
const _v809 = CssVar('--tw-shadow-color', _v808);
const _v810 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1.5, 'px'),
  CssNum(-1, 'px'),
  _v809,
]);
const _v811 = CssVar('--primary-edge', null, 'primaryEdge');
const _v812 = CssVar('--tw-shadow-color', _v811);
const _v813 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(1, 'px'), _v812]);
const _v814 = CssSeq([_v808, CssNum(8, '%')]);
const _v815 = CssFunction('color-mix', [_v4, _v814, _v7]);
const _v816 = CssVar('--tw-shadow-color', _v815);
const _v817 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1.5, 'px'),
  CssNum(-1, 'px'),
  _v816,
]);
const _v818 = CssColor(
  0x0F000000,
  'oklch(0 0 0 / 0.06)',
  Color.from(alpha: 0.060735, red: 0.002258, green: 0.002258, blue: 0.000297),
);
const _v819 = CssVar('--tw-shadow-color', _v818);
const _v820 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1.5, 'px'),
  CssNum(-1, 'px'),
  _v819,
]);
const _v821 = CssVar('--tw-shadow-color', _v118);
const _v822 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(0.5, 'px'),
  _v821,
]);
const _v823 = CssFunction('color-mix', [_v4, _v503, _v7]);
const _v824 = CssVar('--tw-shadow-color', _v823);
const _v825 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(0.5, 'px'),
  _v824,
]);
const _v826 = CssColor(
  0x0A000000,
  'oklch(0 0 0 / 0.04)',
  Color.from(alpha: 0.041164, red: 0.000837, green: 0.000837, blue: 0.002510),
);
const _v827 = CssVar('--tw-shadow-color', _v826);
const _v828 = CssSeq([
  CssNum(0),
  CssNum(2, 'px'),
  CssNum(2, 'px'),
  CssNum(-1, 'px'),
  _v827,
]);
const _v829 = CssSeq([
  CssNum(0),
  CssNum(4, 'px'),
  CssNum(4, 'px'),
  CssNum(-2, 'px'),
  _v803,
]);
const _v830 = CssColor(
  0x1F000000,
  'oklch(0 0 0 / 0.12)',
  Color.from(alpha: 0.123493, red: 0.000837, green: 0.000837, blue: 0.001066),
);
const _v831 = CssVar('--tw-shadow-color', _v830);
const _v832 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1.5, 'px'),
  CssNum(-1, 'px'),
  _v831,
]);
const _v833 = CssVar('--tw-shadow-color', _v284);
const _v834 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(0.5, 'px'),
  _v833,
]);
const _v835 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1, 'px'),
  CssNum(-0.5, 'px'),
  _v809,
]);
const _v836 = CssSeq([
  CssNum(0),
  CssNum(2, 'px'),
  CssNum(2, 'px'),
  CssNum(-1, 'px'),
  _v809,
]);
const _v837 = CssList([_v834, _v835, _v836, _v813]);
const _v838 = CssSeq([_v808, CssNum(10, '%')]);
const _v839 = CssFunction('color-mix', [_v4, _v838, _v7]);
const _v840 = CssVar('--tw-shadow-color', _v839);
const _v841 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1, 'px'),
  CssNum(-0.5, 'px'),
  _v840,
]);
const _v842 = CssSeq([_v808, CssNum(6, '%')]);
const _v843 = CssFunction('color-mix', [_v4, _v842, _v7]);
const _v844 = CssVar('--tw-shadow-color', _v843);
const _v845 = CssSeq([
  CssNum(0),
  CssNum(2, 'px'),
  CssNum(2, 'px'),
  CssNum(-1, 'px'),
  _v844,
]);
const _v846 = CssList([_v834, _v841, _v845, _v813]);
const _v847 = CssVar('--primary-950', null, 'primary950');
const _v848 = CssColor(0xFFD8D8D5, 'oklch(0.88 0.004 106.42)');
const _v849 = CssFunction('blur', [CssVar('--drawer-blur')]);
const _v850 = CssOp('+', _v242, CssNum(120, '%'));
const _v851 = CssFunction('translatey', [CssCalc(_v850)]);
const _v852 = CssVar('--toast-swipe-movement-x');
const _v853 = CssOp('-', _v852, CssNum(120, '%'));
const _v854 = CssFunction('translatex', [CssCalc(_v853)]);
const _v855 = CssFunction('translatey', [CssVar('--toast-y')]);
const _v856 = CssOp('+', _v852, CssNum(120, '%'));
const _v857 = CssFunction('translatex', [CssCalc(_v856)]);
const _v858 = CssOp('-', _v242, CssNum(120, '%'));
const _v859 = CssFunction('translatey', [CssCalc(_v858)]);
const _v860 = CssVar('--drawer-swipe-strength', CssNum(1));
const _v861 = CssOp('*', _v860, CssNum(180, 'ms'));
const _v862 = CssVar('--closed-transform');
const _v863 = CssFunction('scale', [CssNum(0.99)]);
const _v864 = CssColor(
  0x8A000000,
  'oklch(0 0 0 / 0.54)',
  Color.from(alpha: 0.541961, red: 0.000019, green: 0.000019, blue: 0.000089),
);
const _v865 = CssVar('--tw-shadow-color', _v864);
const _v866 = CssSeq([
  CssNum(0),
  CssNum(18, 'px'),
  CssNum(40, 'px'),
  CssNum(-18, 'px'),
  _v865,
]);
const _v867 = CssFunction('translatex', [_v852]);
const _v868 = CssFunction('scale', [CssNum(1)]);
const _v869 = CssSeq([_v867, _v855, _v868]);
const _v870 = CssSeq([_v81, CssNum(65, '%')]);
const _v871 = CssFunction('color-mix', [_v44, _v870, _v38]);
const _v872 = CssKeyword('raft-progress-indeterminate');
const _v873 = CssKeyword('ease-in-out');
const _v874 = CssSeq([
  _v872,
  CssNum(1400, 'ms'),
  _v873,
  CssKeyword('infinite'),
]);
const _v875 = CssKeyword('raft-progress-sweep');
const _v876 = CssSeq([
  _v875,
  CssNum(1600, 'ms'),
  _v873,
  CssKeyword('infinite'),
]);
const _v877 = CssVar('--progress-sweep');
const _v878 = CssFunction('linear-gradient', [
  CssNum(90, 'deg'),
  _v7,
  _v877,
  _v7,
]);
const _v879 = CssSeq([CssColor(0xFFF97264), CssNum(5, '%')]);
const _v880 = CssFunction('color-mix', [_v4, _v879, _v7]);
const _v881 = CssColor(
  0x0DF97264,
  'color-mix(in oklab, #f97264 5%, transparent)',
  Color.from(alpha: 0.050980, red: 0.962670, green: 0.424208, blue: 0.361991),
);
const _v882 = CssSeq([_v137, CssNum(45, '%')]);
const _v883 = CssFunction('color-mix', [_v44, _v882, _v7]);
const _v884 = CssSeq([_v81, CssNum(60, '%')]);
const _v885 = CssFunction('color-mix', [_v44, _v884, _v7]);
const _v886 = CssSeq([_v137, CssNum(75, '%')]);
const _v887 = CssFunction('color-mix', [_v44, _v886, _v7]);
const _v888 = CssOp('+', CssNum(3, 'px'), _v33);
const _v889 = CssSeq([
  _v32,
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssCalc(_v888),
  _v36,
]);
const _v890 = CssSeq([_v137, CssNum(60, '%')]);
const _v891 = CssFunction('color-mix', [_v387, _v890, _v7]);
const _v892 = CssSeq([_v137, CssNum(12, '%')]);
const _v893 = CssFunction('color-mix', [_v44, _v892, _v7]);
const _v894 = CssSeq([CssColor(0xFFF97264), CssNum(60, '%')]);
const _v895 = CssFunction('color-mix', [_v4, _v894, _v7]);
const _v896 = CssColor(
  0x99F97264,
  'color-mix(in oklab, #f97264 60%, transparent)',
  Color.from(alpha: 0.599203, red: 0.972755, green: 0.442639, blue: 0.390326),
);
const _v897 = CssVar('--drawer-frontmost-height');
const _v898 = CssSeq([_v81, CssNum(30, '%')]);
const _v899 = CssFunction('color-mix', [_v44, _v898, _v7]);
const _v900 = CssSeq([_v216, CssNum(50, '%')]);
const _v901 = CssFunction('color-mix', [_v44, _v900, _v7]);
const _v902 = CssSeq([_v216, CssNum(70, '%')]);
const _v903 = CssFunction('color-mix', [_v44, _v902, _v7]);
const _v904 = CssVar('--accent-700', null, 'accent700');
const _v905 = CssFunction('scale', [CssNum(0.97)]);
const _v906 = CssSeq([_v222, CssNum(55, '%')]);
const _v907 = CssFunction('color-mix', [_v387, _v906, _v38]);
const _v908 = CssColor(0xFFF3B700, 'oklch(0.81 0.19 88.08)');
const _v909 = CssVar('--tw-divide-y-reverse');
const _v910 = CssOp('*', CssNum(1, 'px'), _v909);
const _v911 = CssOp('-', CssNum(1), _v909);
const _v912 = CssOp('*', CssNum(1, 'px'), _v911);
const _v913 = CssOp('*', CssNum(2, 'px'), _v909);
const _v914 = CssOp('*', CssNum(2, 'px'), _v911);
const _v915 = CssColor(
  0xD1FAD03E,
  'oklch(0.87 0.16 92 / 0.82)',
  Color.from(alpha: 0.816691, red: 0.982024, green: 0.814084, blue: 0.243413),
);
const _v916 = CssVar('--tw-drop-shadow-color', _v915);
const _v917 = CssSeq([CssNum(0), CssNum(0), CssNum(1, 'px'), _v916]);
const _v918 = CssFunction('drop-shadow', [_v917]);
const _v919 = CssColor(
  0xD1FFD441,
  'oklch(88.3% 0.162 91.9 / 0.82)',
  Color.from(alpha: 0.818529, red: 0.999282, green: 0.831598, blue: 0.253140),
);
const _v920 = CssVar('--tw-drop-shadow-color', _v919);
const _v921 = CssSeq([CssNum(0), CssNum(0), CssNum(1, 'px'), _v920]);
const _v922 = CssFunction('drop-shadow', [_v921]);
const _v923 = CssFunction('cubic-bezier', [
  CssNum(0.22),
  CssNum(1),
  CssNum(0.36),
  CssNum(1),
]);
const _v924 = CssFunction('cubic-bezier', [
  CssNum(0.65),
  CssNum(0),
  CssNum(0.35),
  CssNum(1),
]);
const _v925 = CssFunction('brightness', [CssNum(90, '%')]);
const _v926 = CssFunction('brightness', [CssNum(0.96)]);
const _v927 = CssColor(0xFF015FCC, 'oklch(0.507 0.185 257.731)');
const _v928 = CssVar('--button-focus-ring', _v118);
const _v929 = CssSeq([_v928, CssNum(80, '%')]);
const _v930 = CssFunction('color-mix', [_v387, _v929, _v7]);
const _v931 = CssSeq([_v118, CssNum(85, '%')]);
const _v932 = CssFunction('color-mix', [_v387, _v931, _v7]);
const _v933 = CssSeq([_v227, CssNum(60, '%')]);
const _v934 = CssFunction('color-mix', [_v44, _v933, _v7]);
const _v935 = CssVar('--card-title-font-weight', null, 'cardTitleFontWeight');
const _v936 = CssVar('--heading-font', _v53, 'headingFont');
const _v937 = CssKeyword('CanvasText');
const _v938 = CssFunction('repeat', [CssNum(1), _v106]);
const _v939 = CssFunction('repeat', [CssNum(2), _v106]);
const _v940 = CssKeyword('max-content');
const _v941 = CssSeq([_v106, CssKeyword('auto')]);
const _v942 = CssSeq([_v106, CssKeyword('auto'), _v106]);
const _v943 = CssSeq([_v0, CssNum(60, '%')]);
const _v944 = CssFunction('color-mix', [_v44, _v943, _v7]);
const _v945 = CssSeq([_v137, CssNum(40, '%')]);
const _v946 = CssFunction('color-mix', [_v44, _v945, _v7]);
const _v947 = CssOp('+', CssNum(25, '%'), CssNum(2, 'px'));
const _v948 = CssNum(1.4285714285714286);
const _v949 = CssVar('--tw-leading', _v948);
const _v950 = CssSeq([_v847, CssNum(60, '%')]);
const _v951 = CssFunction('color-mix', [_v44, _v950, _v7]);
const _v952 = CssSeq([
  CssNum(0),
  CssKeyword('round'),
  CssNum(9999, 'px'),
  CssNum(0),
  CssNum(0),
  CssNum(9999, 'px'),
]);
const _v953 = CssFunction('inset', [_v952]);
const _v954 = CssColor(0xFFF7F7F6, 'oklch(0.976 0.001 106.42)');
const _v955 = CssSeq([_v5, CssNum(28, '%')]);
const _v956 = CssFunction('color-mix', [_v4, _v955, _v7]);
const _v957 = CssColor(
  0x47000000,
  'color-mix(in oklab, oklch(0 0 0) 28%, transparent)',
  Color.from(alpha: 0.280245, red: 0.000241, green: 0.000241, blue: 0.000107),
);
const _v958 = CssSeq([_v324, CssNum(2, '%')]);
const _v959 = CssFunction('color-mix', [_v387, _v958, _v38]);
const _v960 = CssSeq([_v0, CssNum(20, '%')]);
const _v961 = CssFunction('color-mix', [_v44, _v960, _v7]);
const _v962 = CssVar('--active-tab-height');
const _v963 = CssVar('--code-block-header-height');
const _v964 = CssVar('--drawer-content-height');
const _v965 = CssVar('--shell-header-height', CssNum(56, 'px'));
const _v966 = CssVar('--task-dnd-placeholder-height', CssNum(72, 'px'));
const _v967 = CssVar('--toast-stack-height');
const _v968 = CssOp('+', CssNum(1.2, 'em'), CssNum(2, 'px'));
const _v969 = CssOp('+', CssNum(100, '%'), CssNum(12, 'px'));
const _v970 = CssOp('+', CssNum(56, 'px'), _v79);
const _v971 = CssOp('-', _v962, CssNum(3.34375, 'px'));
const _v972 = CssKeyword('fit-content');
const _v973 = CssSeq([CssKeyword('auto'), CssKeyword('auto')]);
const _v974 = CssKeyword('inline-block');
const _v975 = CssOp('-', _v968, CssNum(0.857, 'em'));
const _v976 = CssOp('/', _v975, CssNum(2));
const _v977 = CssVar('--reference-badge-ink', _v35);
const _v978 = CssSeq([CssKeyword('span'), CssNum(2)]);
const _v979 = CssVar('--reference-icon');
const _v980 = CssOp('+', CssNum(0.857, 'em'), CssNum(6, 'px'));
const _v981 = CssSeq([CssNum(18, 'px'), _v106]);
const _v982 = CssFunction('linear-gradient', [_v96, _v7, _v68]);
const _v983 = CssFunction('brightness', [CssNum(100, '%')]);
const _v984 = CssSeq([CssColor(0xFF27CCF3), CssNum(25, '%')]);
const _v985 = CssFunction('color-mix', [_v4, _v984, _v7]);
const _v986 = CssColor(
  0x4027CCF3,
  'color-mix(in oklab, #27ccf3 25%, transparent)',
  Color.from(alpha: 0.250000, red: 0.151961, green: 0.795098, blue: 0.951961),
);
const _v987 = CssSeq([_v62, CssNum(10, '%')]);
const _v988 = CssFunction('color-mix', [_v44, _v987, _v7]);
const _v989 = CssSeq([_v62, CssNum(50, '%')]);
const _v990 = CssFunction('color-mix', [_v44, _v989, _v7]);
const _v991 = CssSeq([CssColor(0xFFF8A16F), CssNum(30, '%')]);
const _v992 = CssFunction('color-mix', [_v4, _v991, _v7]);
const _v993 = CssColor(
  0x4DF8A16F,
  'color-mix(in oklab, #f8a16f 30%, transparent)',
  Color.from(alpha: 0.301961, red: 0.967914, green: 0.630252, blue: 0.435498),
);
const _v994 = CssSeq([_v22, CssNum(60, '%')]);
const _v995 = CssFunction('color-mix', [_v44, _v994, _v7]);
const _v996 = CssColor(0xFFF8F8F8, 'color-mix(in oklch, black 2%, white)');
const _v997 = CssFunction('color-mix', [_v387, _v958, _v484]);
const _v998 = CssSeq([_v43, CssNum(6, '%')]);
const _v999 = CssFunction('color-mix', [_v387, _v998, _v38]);
const _v1000 = CssColor(0xFF31312D, 'oklch(0.31 0.006 106.42)');
const _v1001 = CssVar('--accent-hover', null, 'accentHover');
const _v1002 = CssSeq([_v5, CssNum(55, '%')]);
const _v1003 = CssFunction('color-mix', [_v4, _v1002, _v7]);
const _v1004 = CssColor(
  0x8C000000,
  'color-mix(in oklab, oklch(0 0 0) 55%, transparent)',
  Color.from(alpha: 0.550000, red: 0.000089, green: 0.000089, blue: 0.000357),
);
const _v1005 = CssSeq([CssColor(0xFF27CCF3), CssNum(40, '%')]);
const _v1006 = CssFunction('color-mix', [_v4, _v1005, _v7]);
const _v1007 = CssColor(
  0x6627CCF3,
  'color-mix(in oklab, #27ccf3 40%, transparent)',
  Color.from(alpha: 0.399142, red: 0.152942, green: 0.801201, blue: 0.950990),
);
const _v1008 = CssSeq([CssColor(0xFF27CCF3), CssNum(60, '%')]);
const _v1009 = CssFunction('color-mix', [_v4, _v1008, _v7]);
const _v1010 = CssColor(
  0x9927CCF3,
  'color-mix(in oklab, #27ccf3 60%, transparent)',
  Color.from(alpha: 0.599326, red: 0.148116, green: 0.795903, blue: 0.952941),
);
const _v1011 = CssSeq([CssColor(0xFFFE7DA8), CssNum(60, '%')]);
const _v1012 = CssFunction('color-mix', [_v4, _v1011, _v7]);
const _v1013 = CssColor(
  0x99FE7DA8,
  'color-mix(in oklab, #fe7da8 60%, transparent)',
  Color.from(alpha: 0.599203, red: 0.992389, green: 0.488452, blue: 0.658657),
);
const _v1014 = CssSeq([CssColor(0xFFC0B9B1), CssNum(40, '%')]);
const _v1015 = CssFunction('color-mix', [_v4, _v1014, _v7]);
const _v1016 = CssColor(
  0x66C0B9B1,
  'color-mix(in oklab, #c0b9b1 40%, transparent)',
  Color.from(alpha: 0.399142, red: 0.752941, green: 0.723529, blue: 0.694118),
);
const _v1017 = CssVar('--danger-hover', null, 'dangerHover');
const _v1018 = CssSeq([_v227, CssNum(20, '%')]);
const _v1019 = CssFunction('color-mix', [_v44, _v1018, _v7]);
const _v1020 = CssSeq([_v22, CssNum(55, '%')]);
const _v1021 = CssFunction('color-mix', [_v44, _v1020, _v7]);
const _v1022 = CssSeq([_v0, CssNum(85, '%')]);
const _v1023 = CssFunction('color-mix', [_v44, _v1022, _v7]);
const _v1024 = CssVar('--info-hover', null, 'infoHover');
const _v1025 = CssSeq([_v118, CssNum(50, '%')]);
const _v1026 = CssFunction('color-mix', [_v44, _v1025, _v7]);
const _v1027 = CssVar('--warning-hover', null, 'warningHover');
const _v1028 = CssSeq([_v39, CssNum(5, '%')]);
const _v1029 = CssFunction('color-mix', [_v4, _v1028, _v7]);
const _v1030 = CssColor(
  0x0DFFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 5%, transparent)',
  Color.from(alpha: 0.050919, red: 0.986034, green: 0.986034, blue: 0.995930),
);
const _v1031 = CssSeq([_v39, CssNum(7.5, '%')]);
const _v1032 = CssFunction('color-mix', [_v4, _v1031, _v7]);
const _v1033 = CssColor(
  0x13FFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 7.5%, transparent)',
  Color.from(alpha: 0.075306, red: 0.999647, green: 0.999647, blue: 0.999647),
);
const _v1034 = CssVar('--line-field-hover', null, 'lineFieldHover');
const _v1035 = CssSeq([_v39, CssNum(60, '%')]);
const _v1036 = CssFunction('color-mix', [_v4, _v1035, _v7]);
const _v1037 = CssColor(
  0x99FFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 60%, transparent)',
  Color.from(alpha: 0.600429, red: 0.999350, green: 0.999350, blue: 0.999663),
);
const _v1038 = CssFunction('brightness', [CssNum(95, '%')]);
const _v1039 = CssVar('--primary-active', null, 'primaryActive');
const _v1040 = CssSeq([
  CssNum(3, 'px'),
  CssNum(3, 'px'),
  CssNum(0),
  CssNum(0),
  _v798,
]);
const _v1041 = CssColor(0xFF654C00, 'oklch(0.431 0.088 86.67)');
const _v1042 = CssColor(0xFFC80D6B, 'oklch(0.543 0.215 359.77)');
const _v1043 = CssSeq([_v5, CssNum(75, '%')]);
const _v1044 = CssFunction('color-mix', [_v4, _v1043, _v7]);
const _v1045 = CssColor(
  0xBF000000,
  'color-mix(in oklab, oklch(0 0 0) 75%, transparent)',
  Color.from(alpha: 0.750919, red: 0.000342, green: 0.001242, blue: 0.000041),
);
const _v1046 = CssSeq([_v39, CssNum(88, '%')]);
const _v1047 = CssFunction('color-mix', [_v4, _v1046, _v7]);
const _v1048 = CssColor(
  0xE0FFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 88%, transparent)',
  Color.from(alpha: 0.880368, red: 0.999679, green: 0.999751, blue: 0.999450),
);
const _v1049 = CssColor(
  0x1F141111,
  'oklch(0.1813 0.00497 17.62 / 0.12)',
  Color.from(alpha: 0.121409, red: 0.051103, green: 0.051103, blue: 0.049304),
);
const _v1050 = CssFunction('light-dark', [_v1049, _v100]);
const _v1051 = CssColor(0xFF1D1D1D, 'oklch(0.23 0 0)');
const _v1052 = CssFunction('light-dark', [_v39, _v1051]);
const _v1053 = CssVar('--checker-cell');
const _v1054 = CssSeq([_v1053, CssNum(25, '%')]);
const _v1055 = CssSeq([_v7, CssNum(25, '%')]);
const _v1056 = CssFunction('linear-gradient', [
  CssNum(45, 'deg'),
  _v1054,
  _v1055,
]);
const _v1057 = CssFunction('linear-gradient', [
  CssNum(-45, 'deg'),
  _v1054,
  _v1055,
]);
const _v1058 = CssSeq([_v7, CssNum(75, '%')]);
const _v1059 = CssSeq([_v1053, CssNum(75, '%')]);
const _v1060 = CssFunction('linear-gradient', [
  CssNum(45, 'deg'),
  _v1058,
  _v1059,
]);
const _v1061 = CssFunction('linear-gradient', [
  CssNum(-45, 'deg'),
  _v1058,
  _v1059,
]);
const _v1062 = CssList([_v1056, _v1057, _v1060, _v1061]);
const _v1063 = CssSeq([CssNum(0), CssNum(0)]);
const _v1064 = CssSeq([CssNum(0), CssNum(8, 'px')]);
const _v1065 = CssSeq([CssNum(8, 'px'), CssNum(-8, 'px')]);
const _v1066 = CssSeq([CssNum(-8, 'px'), CssNum(0)]);
const _v1067 = CssList([_v1063, _v1064, _v1065, _v1066]);
const _v1068 = CssSeq([CssNum(16, 'px'), CssNum(16, 'px')]);
const _v1069 = CssOp('+', _v238, _v240);
const _v1070 = CssOp('+', _v1069, _v242);
const _v1071 = CssKeyword('inline-grid');
const _v1072 = CssVar('--active-tab-left');
const _v1073 = CssOp('+', _v1072, CssNum(1, 'px'));
const _v1074 = CssKeyword('-webkit-box');
const _v1075 = CssVar('--available-height');
const _v1076 = CssOp('-', CssNum(100, 'dvh'), CssNum(32, 'px'));
const _v1077 = CssFunction('linear-gradient', [_v96, _v344, _v7]);
const _v1078 = CssFunction('blur', [CssNum(8, 'px')]);
const _v1079 = CssFunction('linear-gradient', [_v96, _v68, _v7]);
const _v1080 = CssVar('--mi-avatar-narrow', CssNum(28, 'px'));
const _v1081 = CssVar('--ph-icon-col', CssNum(2));
const _v1082 = CssVar('--ph-icon-row-end', CssKeyword('auto'));
const _v1083 = CssVar('--ph-icon-row-start', CssNum(1));
const _v1084 = CssKeyword('column-reverse');
const _v1085 = CssSeq([
  CssKeyword('auto'),
  CssKeyword('auto'),
  _v106,
  CssKeyword('auto'),
]);
const _v1086 = CssFunction('env', [_v170]);
const _v1087 = CssOp('+', _v1086, CssNum(6, 'px'));
const _v1088 = CssOp('+', _v1086, CssNum(10, 'px'));
const _v1089 = CssVar('--si-title-max-w', CssKeyword('none'));
const _v1090 = CssOp('-', CssNum(100, 'vw'), CssNum(48, 'px'));
const _v1091 = CssVar('--available-width', CssNum(320, 'px'));
const _v1092 = CssFunction('min', [CssNum(320, 'px'), CssCalc(_v1091)]);
const _v1093 = CssOp('-', CssNum(100, 'vw'), CssNum(32, 'px'));
const _v1094 = CssVar('--available-width', CssCalc(_v1093));
const _v1095 = CssFunction('min', [CssNum(384, 'px'), CssCalc(_v1094)]);
const _v1096 = CssFunction('min', [CssNum(544, 'px'), CssNum(100, '%')]);
const _v1097 = CssOp('-', CssNum(100, 'vw'), CssNum(112, 'px'));
const _v1098 = CssFunction('min', [CssNum(352, 'px'), CssCalc(_v1097)]);
const _v1099 = CssFunction('min', [CssNum(448, 'px'), CssCalc(_v1097)]);
const _v1100 = CssFunction('max', [CssNum(8, 'px'), CssCalc(_v171)]);
const _v1101 = CssVar('--ph-icon-self', CssKeyword('auto'));
const _v1102 = CssFunction('repeat', [CssNum(3), _v106]);
const _v1103 = CssVar('--panel-footer-clearance');
const _v1104 = CssVar('--sidebar-inset-x', CssNum(26, 'px'));
const _v1105 = CssVar('--sidebar-inset-end', _v1104);
const _v1106 = CssVar('--card-title-line-height', null, 'cardTitleLineHeight');
const _v1107 = CssVar('--anchor-width');
const _v1108 = CssFunction('max', [CssCalc(_v1107), CssNum(220, 'px')]);
const _v1109 = CssSeq([_v0, CssNum(16, '%')]);
const _v1110 = CssFunction('color-mix', [_v44, _v1109, _v7]);
const _v1111 = CssVar('--mi-toolbar-opacity', CssNum(0));
const _v1112 = CssVar('--drawer-overlay-min-opacity', CssNum(0));
const _v1113 = CssOp('-', CssNum(1), _v181);
const _v1114 = CssFunction('max', [CssCalc(_v1112), CssCalc(_v1113)]);
const _v1115 = CssVar('--drawer-transform-origin');
const _v1116 = CssVar('--transform-origin');
const _v1117 = CssColor(0xFF333333, 'oklch(0.32 0 0)');
const _v1118 = CssVar('--sidebar-content-bottom', CssNum(12, 'px'));
const _v1119 = CssOp('+', CssNum(16, 'px'), _v171);
const _v1120 = CssOp('+', _v1086, CssNum(12, 'px'));
const _v1121 = CssFunction('max', [CssNum(10, 'px'), CssCalc(_v171)]);
const _v1122 = CssFunction('min', [CssCalc(_v171), CssNum(34, 'px')]);
const _v1123 = CssKeyword('safe-area-inset-left');
const _v1124 = CssFunction('env', [_v1123, CssNum(0, 'px')]);
const _v1125 = CssOp('+', CssNum(16, 'px'), _v1124);
const _v1126 = CssOp('+', _v1124, CssNum(16, 'px'));
const _v1127 = CssSeq([_v58, CssNum(70, '%')]);
const _v1128 = CssFunction('color-mix', [_v44, _v1127, _v7]);
const _v1129 = CssKeyword('-webkit-backdrop-filter');
const _v1130 = CssKeyword('backdrop-filter');
const _v1131 = CssKeyword('content-visibility');
const _v1132 = CssKeyword('pointer-events');
const _v1133 = CssList([
  CssKeyword('color'),
  _v23,
  _v125,
  _v126,
  _v127,
  CssKeyword('fill'),
  CssKeyword('stroke'),
  _v128,
  _v129,
  _v130,
  CssKeyword('opacity'),
  _v24,
  CssKeyword('transform'),
  CssKeyword('translate'),
  CssKeyword('scale'),
  CssKeyword('rotate'),
  CssKeyword('filter'),
  _v1129,
  _v1130,
  CssKeyword('display'),
  _v1131,
  CssKeyword('overlay'),
  _v1132,
]);
const _v1134 = CssVar('--ig-control-pr', CssNum(12, 'px'));
const _v1135 = CssVar('--mi-hdr-pr', CssNum(96, 'px'));
const _v1136 = CssVar('--ta-pr', CssNum(12, 'px'));
const _v1137 = CssOp('+', _v75, CssNum(16, 'px'));
const _v1138 = CssOp('+', _v79, CssNum(12, 'px'));
const _v1139 = CssOp('+', CssNum(100, '%'), CssNum(2, 'px'));
const _v1140 = CssOp('-', CssNum(100, '%'), CssNum(10, 'px'));
const _v1141 = CssVar('--tabs-ring', _v12);
const _v1142 = CssVar('--banner-desc-row', CssNum(1));
const _v1143 = CssVar('--ph-icon-row-start', CssKeyword('auto'));
const _v1144 = CssFunction('saturate', [CssNum(150, '%')]);
const _v1145 = CssVar('--ta-scroll-pb', CssNum(0));
const _v1146 = CssVar('--tw-shadow-color', _v648);
const _v1147 = CssSeq([
  CssNum(0),
  CssNum(12, 'px'),
  CssNum(32, 'px'),
  CssNum(-18, 'px'),
  _v1146,
]);
const _v1148 = CssSeq([
  CssNum(0),
  CssNum(18, 'px'),
  CssNum(42, 'px'),
  CssNum(-18, 'px'),
  _v865,
]);
const _v1149 = CssColor(
  0x2E000000,
  'oklch(0 0 0 / 0.18)',
  Color.from(alpha: 0.181961, red: 0.000273, green: 0.000273, blue: 0.000264),
);
const _v1150 = CssVar('--tw-shadow-color', _v1149);
const _v1151 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1.5, 'px'),
  CssNum(-0.5, 'px'),
  _v1150,
]);
const _v1152 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v827,
]);
const _v1153 = CssList([_v1151, _v1152]);
const _v1154 = CssVar('--tw-shadow-color', _v324);
const _v1155 = CssSeq([CssNum(0), CssNum(1, 'px'), CssNum(1, 'px'), _v1154]);
const _v1156 = CssFunction('color-mix', [_v387, _v675, _v7]);
const _v1157 = CssVar('--tw-shadow-color', _v1156);
const _v1158 = CssSeq([CssNum(0), CssNum(1, 'px'), CssNum(1, 'px'), _v1157]);
const _v1159 = CssColor(
  0x40822B31,
  'oklch(0.42 0.12 20 / 0.25)',
  Color.from(alpha: 0.250000, red: 0.510784, green: 0.167119, blue: 0.183333),
);
const _v1160 = CssVar('--tw-shadow-color', _v1159);
const _v1161 = CssSeq([CssNum(0), CssNum(3, 'px'), CssNum(6, 'px'), _v1160]);
const _v1162 = CssColor(
  0x14000000,
  'oklch(0 0 0 / 0.08)',
  Color.from(alpha: 0.080368, red: 0.001310, green: 0.001310, blue: 0.002836),
);
const _v1163 = CssVar('--tw-shadow-color', _v1162);
const _v1164 = CssSeq([CssNum(0), CssNum(4, 'px'), CssNum(12, 'px'), _v1163]);
const _v1165 = CssSeq([
  CssNum(2, 'px'),
  CssNum(2, 'px'),
  CssNum(0),
  CssNum(0),
  _v798,
]);
const _v1166 = CssColor(
  0x8CFFFFFF,
  'color-mix(in oklch, oklch(1 0 0) 55%, transparent)',
  Color.from(alpha: 0.550674, red: 0.998866, green: 0.999028, blue: 0.999724),
);
const _v1167 = CssVar('--tw-shadow-color', _v1166);
const _v1168 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0.5, 'px'),
  CssNum(1, 'px'),
  _v1167,
]);
const _v1169 = CssColor(
  0x06FFFFFF,
  'oklch(1 0 0 / 0.025)',
  Color.from(alpha: 0.025613, red: 0.974458, green: 0.974458, blue: 0.990144),
);
const _v1170 = CssVar('--tw-shadow-color', _v1169);
const _v1171 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(0.5, 'px'),
  _v1170,
]);
const _v1172 = CssVar('--tw-shadow-color', _v217);
const _v1173 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v1172,
]);
const _v1174 = CssList([_v1171, _v1173]);
const _v1175 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(0.5, 'px'),
  _v706,
]);
const _v1176 = CssVar('--tw-shadow-color', _v157);
const _v1177 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v1176,
]);
const _v1178 = CssList([_v1175, _v1177]);
const _v1179 = CssSeq([_v157, CssNum(28, '%')]);
const _v1180 = CssFunction('color-mix', [_v791, _v1179, _v7]);
const _v1181 = CssVar('--tw-shadow-color', _v1180);
const _v1182 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v1181,
]);
const _v1183 = CssList([_v1175, _v1182]);
const _v1184 = CssList([_v1175, _v813]);
const _v1185 = CssVar('--tw-shadow-color', _v232);
const _v1186 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(0.5, 'px'),
  _v1185,
]);
const _v1187 = CssList([_v1186, _v670]);
const _v1188 = CssColor(
  0x09000000,
  'oklch(0 0 0 / 0.035)',
  Color.from(alpha: 0.037206, red: 0.000670, green: 0.000670, blue: 0.003491),
);
const _v1189 = CssVar('--tw-shadow-color', _v1188);
const _v1190 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1.5, 'px'),
  CssNum(-1, 'px'),
  _v1189,
]);
const _v1191 = CssList([_v1186, _v1190, _v670]);
const _v1192 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(2.5, 'px'),
  CssNum(-0.5, 'px'),
  _v831,
]);
const _v1193 = CssList([_v1186, _v1190, _v1192, _v670]);
const _v1194 = CssSeq([
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(1.5, 'px'),
  CssNum(-1, 'px'),
  _v1163,
]);
const _v1195 = CssList([_v1186, _v1194]);
const _v1196 = CssList([_v1186, _v828, _v829, _v670]);
const _v1197 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(0.5, 'px'),
  _v696,
]);
const _v1198 = CssList([_v1197, _v1173]);
const _v1199 = CssVar('--tw-shadow-color', _v137);
const _v1200 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v1199,
]);
const _v1201 = CssList([_v644, _v1200]);
const _v1202 = CssVar('--tw-shadow-color', _v14);
const _v1203 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v1202,
]);
const _v1204 = CssList([_v644, _v1203]);
const _v1205 = CssVar('--tw-shadow-color', _v62);
const _v1206 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v1205,
]);
const _v1207 = CssList([_v644, _v1206]);
const _v1208 = CssColor(
  0x24FFFFFF,
  'oklch(1 0 0 / 0.14)',
  Color.from(alpha: 0.142512, red: 0.999518, green: 0.998538, blue: 0.987952),
);
const _v1209 = CssVar('--tw-shadow-color', _v1208);
const _v1210 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(1, 'px'),
  CssNum(0.5, 'px'),
  _v1209,
]);
const _v1211 = CssVar('--tw-shadow-color', _v64);
const _v1212 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v1211,
]);
const _v1213 = CssList([_v1210, _v1212]);
const _v1214 = CssVar('--theme-shadow-lg', null, 'themeShadowLg');
const _v1215 = CssVar('--si-title-shrink', CssNum(1));
const _v1216 = CssVar('--tw-space-y-reverse');
const _v1217 = CssOp('*', CssNum(6, 'px'), _v1216);
const _v1218 = CssOp('-', CssNum(1), _v1216);
const _v1219 = CssOp('*', CssNum(6, 'px'), _v1218);
const _v1220 = CssOp('*', CssNum(8, 'px'), _v1216);
const _v1221 = CssOp('*', CssNum(8, 'px'), _v1218);
const _v1222 = CssOp('*', CssNum(10, 'px'), _v1216);
const _v1223 = CssOp('*', CssNum(10, 'px'), _v1218);
const _v1224 = CssOp('*', CssNum(12, 'px'), _v1216);
const _v1225 = CssOp('*', CssNum(12, 'px'), _v1218);
const _v1226 = CssOp('*', CssNum(14, 'px'), _v1216);
const _v1227 = CssOp('*', CssNum(14, 'px'), _v1218);
const _v1228 = CssOp('*', CssNum(16, 'px'), _v1216);
const _v1229 = CssOp('*', CssNum(16, 'px'), _v1218);
const _v1230 = CssOp('*', CssNum(1, 'px'), _v1216);
const _v1231 = CssOp('*', CssNum(1, 'px'), _v1218);
const _v1232 = CssFunction('inset', [CssNum(50, '%')]);
const _v1233 = CssKeyword('tabular-nums');
const _v1234 = CssVar('--tw-ordinal', CssSeq([]));
const _v1235 = CssVar('--tw-slashed-zero', CssSeq([]));
const _v1236 = CssVar('--tw-numeric-figure', CssSeq([]));
const _v1237 = CssVar('--tw-numeric-spacing', CssSeq([]));
const _v1238 = CssVar('--tw-numeric-fraction', CssSeq([]));
const _v1239 = CssSeq([_v1234, _v1235, _v1236, _v1237, _v1238]);
const _v1240 = CssVar('--ig-addon-fg-default', _v22);
const _v1241 = CssVar('--ig-addon-fg', _v1240);
const _v1242 = CssVar('--ig-text-fg-default', _v58);
const _v1243 = CssVar('--ig-text-fg', _v1242);
const _v1244 = CssVar('--mi-ct-color', _v7);
const _v1245 = CssVar('--tw-leading', CssNum(1));
const _v1246 = CssSeq([_v137, CssNum(72, '%')]);
const _v1247 = CssFunction('color-mix', [_v44, _v1246, _v7]);
const _v1248 = CssColor(0xFF341A09, 'oklch(0.25 0.05 50)');
const _v1249 = CssColor(0xFF005526, 'oklch(0.39 0.11 153.079)');
const _v1250 = CssColor(0xFF4A4A4A, 'oklch(0.409 0 0)');
const _v1251 = CssColor(0xFF833406, 'oklch(0.43 0.12 44.441)');
const _v1252 = CssColor(0xFF555453, 'oklch(0.447 0.002 67.77)');
const _v1253 = CssColor(0xFF525252, 'oklch(0.44 0 0)');
const _v1254 = CssColor(0xFF63523C, 'oklch(0.45 0.04 74)');
const _v1255 = CssColor(0xFF09703B, 'oklch(0.48 0.12 153.079)');
const _v1256 = CssColor(0xFFC52E1A, 'oklch(0.54 0.19 31)');
const _v1257 = CssColor(0xFFAAF06A, 'oklch(0.88 0.18 132)');
const _v1258 = CssColor(0xFFFAFAFB, 'oklch(0.985 0.001 286)');
const _v1259 = CssColor(
  0xB3000000,
  'oklch(0 0 0 / 0.7)',
  Color.from(alpha: 0.702390, red: 0.000416, green: 0.000824, blue: 0.000083),
);
const _v1260 = CssColor(0xFFCEA306, 'oklch(73.4% 0.149 89.2)');
const _v1261 = CssVar('--accent-950', null, 'accent950');
const _v1262 = CssVar('--tw-leading', CssNum(1.5));
const _v1263 = CssSeq([_v5, CssNum(80, '%')]);
const _v1264 = CssFunction('color-mix', [_v4, _v1263, _v7]);
const _v1265 = CssColor(
  0xCC000000,
  'color-mix(in oklab, oklch(0 0 0) 80%, transparent)',
  Color.from(alpha: 0.799571, red: 0.000108, green: 0.000108, blue: 0.000114),
);
const _v1266 = CssVar('--card-title-font-size', null, 'cardTitleFontSize');
const _v1267 = CssVar('--tw-leading', _v1106);
const _v1268 = CssVar('--danger-foreground', null, 'dangerForeground');
const _v1269 = CssVar('--field-font-size', null, 'fieldFontSize');
const _v1270 = CssVar('--field-line-height', null, 'fieldLineHeight');
const _v1271 = CssVar('--tw-leading', _v1270);
const _v1272 = CssSeq([_v227, CssNum(70, '%')]);
const _v1273 = CssFunction('color-mix', [_v44, _v1272, _v7]);
const _v1274 = CssSeq([_v22, CssNum(70, '%')]);
const _v1275 = CssFunction('color-mix', [_v44, _v1274, _v7]);
const _v1276 = CssSeq([_v22, CssNum(80, '%')]);
const _v1277 = CssFunction('color-mix', [_v44, _v1276, _v7]);
const _v1278 = CssSeq([_v58, CssNum(80, '%')]);
const _v1279 = CssFunction('color-mix', [_v44, _v1278, _v7]);
const _v1280 = CssSeq([_v0, CssNum(45, '%')]);
const _v1281 = CssFunction('color-mix', [_v44, _v1280, _v7]);
const _v1282 = CssSeq([_v0, CssNum(65, '%')]);
const _v1283 = CssFunction('color-mix', [_v44, _v1282, _v7]);
const _v1284 = CssSeq([_v14, CssNum(80, '%')]);
const _v1285 = CssFunction('color-mix', [_v44, _v1284, _v7]);
const _v1286 = CssVar('--inactive-foreground', null, 'inactiveForeground');
const _v1287 = CssVar('--ink-30', null, 'ink30');
const _v1288 = CssVar('--layer-hud-foreground', null, 'layerHudForeground');
const _v1289 = CssNum(1.5555555555555556);
const _v1290 = CssVar('--tw-leading', _v1289);
const _v1291 = CssVar('--primary-600', null, 'primary600');
const _v1292 = CssVar('--primary-700', null, 'primary700');
const _v1293 = CssVar('--primary-900', null, 'primary900');
const _v1294 = CssVar('--secondary-800', null, 'secondary800');
const _v1295 = CssVar('--secondary-900', null, 'secondary900');
const _v1296 = CssVar('--secondary-950', null, 'secondary950');
const _v1297 = CssVar('--success-foreground', null, 'successForeground');
const _v1298 = CssVar('--success-strong', null, 'successStrong');
const _v1299 = CssVar('--warning-foreground', null, 'warningForeground');
const _v1300 = CssVar('--warning-strong', null, 'warningStrong');
const _v1301 = CssSeq([_v39, CssNum(62, '%')]);
const _v1302 = CssFunction('color-mix', [_v4, _v1301, _v7]);
const _v1303 = CssColor(
  0x9EFFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 62%, transparent)',
  Color.from(alpha: 0.620613, red: 0.999509, green: 0.999509, blue: 0.999675),
);
const _v1304 = CssSeq([_v39, CssNum(74, '%')]);
const _v1305 = CssFunction('color-mix', [_v4, _v1304, _v7]);
const _v1306 = CssColor(
  0xBDFFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 74%, transparent)',
  Color.from(alpha: 0.740674, red: 0.999491, green: 0.999714, blue: 0.999750),
);
const _v1307 = CssVar('--tw-leading', CssNum(1.4));
const _v1308 = CssVar('--active-tab-top');
const _v1309 = CssOp('+', _v1308, CssNum(1.671875, 'px'));
const _v1310 = CssKeyword('manipulation');
const _v1311 = CssVar('--drawer-swipe-x', CssNum(0, 'px'));
const _v1312 = CssVar('--drawer-stack-x', CssNum(0, 'px'));
const _v1313 = CssOp('+', _v1311, _v1312);
const _v1314 = CssVar('--drawer-swipe-y', CssNum(0, 'px'));
const _v1315 = CssVar('--drawer-stack-y', CssNum(0, 'px'));
const _v1316 = CssOp('+', _v1314, _v1315);
const _v1317 = CssFunction('translate3d', [
  CssCalc(_v1313),
  CssCalc(_v1316),
  CssNum(0),
]);
const _v1318 = CssFunction('scale', [_v194]);
const _v1319 = CssSeq([_v1317, _v1318]);
const _v1320 = CssOp('*', CssVar('--toast-index'), CssVar('--toast-peek'));
const _v1321 = CssVar('--toast-peek-dir');
const _v1322 = CssOp('*', _v1320, _v1321);
const _v1323 = CssOp('+', _v242, _v1322);
const _v1324 = CssFunction('translatey', [CssCalc(_v1323)]);
const _v1325 = CssFunction('scale', [CssVar('--toast-scale')]);
const _v1326 = CssSeq([_v867, _v1324, _v1325]);
const _v1327 = CssFunction('translatez', [CssNum(0)]);
const _v1328 = CssVar('--tw-rotate-x', CssSeq([]));
const _v1329 = CssVar('--tw-rotate-y', CssSeq([]));
const _v1330 = CssVar('--tw-rotate-z', CssSeq([]));
const _v1331 = CssVar('--tw-skew-x', CssSeq([]));
const _v1332 = CssVar('--tw-skew-y', CssSeq([]));
const _v1333 = CssSeq([_v1327, _v1328, _v1329, _v1330, _v1331, _v1332]);
const _v1334 = CssList([_v23, _v24, CssKeyword('color')]);
const _v1335 = CssList([_v23, _v24, CssKeyword('transform')]);
const _v1336 = CssList([
  _v23,
  CssKeyword('color'),
  _v125,
  _v24,
  CssKeyword('transform'),
]);
const _v1337 = CssList([
  _v23,
  CssKeyword('color'),
  _v24,
  CssKeyword('transform'),
]);
const _v1338 = CssList([
  _v23,
  CssKeyword('color'),
  CssKeyword('opacity'),
  _v24,
  CssKeyword('transform'),
]);
const _v1339 = CssList([_v23, CssKeyword('color')]);
const _v1340 = CssList([_v125, CssKeyword('opacity'), _v24]);
const _v1341 = CssList([_v24, CssKeyword('transform')]);
const _v1342 = CssList([CssKeyword('color'), _v23, CssKeyword('opacity')]);
const _v1343 = CssList([CssKeyword('fill'), CssKeyword('stroke')]);
const _v1344 = CssList([CssKeyword('filter'), CssKeyword('opacity')]);
const _v1345 = CssList([CssKeyword('left'), CssKeyword('width')]);
const _v1346 = CssList([CssKeyword('opacity'), CssKeyword('transform')]);
const _v1347 = CssList([CssKeyword('top'), CssKeyword('height')]);
const _v1348 = CssList([
  CssKeyword('transform'),
  CssKeyword('height'),
  CssKeyword('opacity'),
  CssKeyword('filter'),
]);
const _v1349 = CssList([
  CssKeyword('transform'),
  CssKeyword('opacity'),
  CssKeyword('height'),
]);
const _v1350 = CssList([CssKeyword('width'), _v23]);
const _v1351 = CssVar('--active-tab-width');
const _v1352 = CssOp('-', CssNum(100, '%'), CssNum(32, 'px'));
const _v1353 = CssOp('-', _v1351, CssNum(2, 'px'));
const _v1354 = CssFunction('clamp', [
  CssNum(144, 'px'),
  CssNum(20, 'vw'),
  CssNum(224, 'px'),
]);
const _v1355 = CssFunction('min', [CssNum(384, 'px'), CssCalc(_v1093)]);
const _v1356 = CssFunction('min', [CssNum(92, 'vw'), CssNum(360, 'px')]);
const _v1357 = CssList([CssKeyword('transform'), CssKeyword('opacity')]);
const _v1358 = CssOp('-', CssNum(70), CssVar('--toast-index'));
