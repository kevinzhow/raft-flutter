// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Tailwind utility table.
// ignore_for_file: type=lint

import 'dart:ui' show Color;

import 'recipe_runtime.dart';

/// Every class used by a raft-ui recipe, compiled by Tailwind v4 into
/// cascade layers (index = class id used by the recipe tables).
const List<RaftUtility> raftRecipeUtilities = <RaftUtility>[
  RaftUtility(
    '**:data-[activity-inbox-action=sort]:hover:text-foreground',
    1808,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-action="sort"]:hover', [], 3000, [
        RaftDecl('color', _v0),
      ]),
      RaftLayer(
        ':is(& *)[data-activity-inbox-action="sort"]:hover',
        ['dark'],
        3000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[activity-inbox-action=sort]:text-foreground-muted',
    1807,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-action="sort"]', [], 2000, [
        RaftDecl('color', _v2),
      ]),
      RaftLayer(
        ':is(& *)[data-activity-inbox-action="sort"]',
        ['dark'],
        2000,
        [RaftDecl('color', _v3)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'button-content\']:font-field',
    1902,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'button-content\']', [], 2000, [
        RaftDecl('--tw-font-weight', _v4),
        RaftDecl('font-weight', _v4),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'button-content\']:justify-between',
    1901,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'button-content\']', [], 2000, [
        RaftDecl('justify-content', _v5),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'button-content\']:w-full',
    1900,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'button-content\']', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'combobox-clear\']:shrink-0',
    1904,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'combobox-clear\']', [], 2000, [
        RaftDecl('flex-shrink', CssNum(0)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'combobox-clear\']:size-control-embedded',
    1903,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'combobox-clear\']', [], 2000, [
        RaftDecl('width', _v6),
        RaftDecl('height', _v6),
      ]),
      RaftLayer(
        ':is(& *)[data-slot=\'combobox-clear\']',
        ['pointer-fine', 'width>=768'],
        2000,
        [
          RaftDecl('width', CssNum(22, 'px')),
          RaftDecl('height', CssNum(22, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'select-item-text\']:font-field',
    1907,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'select-item-text\']', [], 2000, [
        RaftDecl('--tw-font-weight', _v4),
        RaftDecl('font-weight', _v4),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=\'select-value\']:font-field',
    1909,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot=\'select-value\']', [], 2000, [
        RaftDecl('--tw-font-weight', _v4),
        RaftDecl('font-weight', _v4),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:after:inset-x-[-1.5px]',
    1932,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]::after', [], 2001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('left', CssNum(-1.5, 'px')),
        RaftDecl('right', CssNum(-1.5, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:after:inset-x-[-3px]',
    1933,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]::after', [], 2001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('left', CssNum(-3, 'px')),
        RaftDecl('right', CssNum(-3, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:duration-150',
    1929,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('--tw-duration', CssNum(150, 'ms')),
        RaftDecl('transition-duration', CssNum(150, 'ms')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:first:after:left-[-9.5px]',
    1936,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]:first-child::after', [], 3001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('left', CssNum(-9.5, 'px')),
      ]),
    ],
  ),
  RaftUtility('**:data-[slot=button]:h-7', 1923, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
      RaftDecl('height', CssNum(28, 'px')),
    ]),
  ]),
  RaftUtility(
    '**:data-[slot=button]:last:after:right-[-9.5px]',
    1939,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]:last-child::after', [], 3001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('right', CssNum(-9.5, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:min-w-7',
    1926,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('min-width', CssNum(28, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:rounded-chip',
    1927,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('border-top-left-radius', CssNum(6, 'px')),
        RaftDecl('border-top-right-radius', CssNum(6, 'px')),
        RaftDecl('border-bottom-right-radius', CssNum(6, 'px')),
        RaftDecl('border-bottom-left-radius', CssNum(6, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:transition-[color,background-color,box-shadow]',
    1928,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('transition-property', _v9),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:w-auto',
    1924,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('width', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=button]:w-full',
    1925,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="button"]', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=composer-attachment]:shrink-0',
    1944,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="composer-attachment"]', [], 2000, [
        RaftDecl('flex-shrink', CssNum(0)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:col-start-1',
    1945,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('grid-column-start', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:duration-170',
    1951,
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
    1952,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('--tw-ease', _v13),
        RaftDecl('transition-timing-function', _v13),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:origin-center',
    1948,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('transform-origin', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:row-start-1',
    1946,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('grid-row-start', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:size-4',
    1947,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:stroke-2',
    1949,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:transition-[opacity,filter,scale]',
    1950,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('transition-property', _v14),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=copyable-code-icon]:will-change-[opacity,filter,scale]',
    1953,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="copyable-code-icon"]', [], 2000, [
        RaftDecl('will-change', _v14),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview-media]:bg-transparent',
    1964,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview-media"]', [], 2000, [
        RaftDecl('background-color', _v15),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview-media]:border-0',
    1963,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview-media"]', [], 2000, [
        RaftDecl('border-top-style', _v16),
        RaftDecl('border-right-style', _v16),
        RaftDecl('border-bottom-style', _v16),
        RaftDecl('border-left-style', _v16),
        RaftDecl('border-top-width', CssNum(0, 'px')),
        RaftDecl('border-right-width', CssNum(0, 'px')),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
        RaftDecl('border-left-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview-media]:ring-0',
    1966,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview-media"]', [], 2000, [
        RaftDecl('--tw-ring-shadow', _v22),
        RaftDecl('box-shadow', _v27),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview-media]:shadow-none',
    1965,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview-media"]', [], 2000, [
        RaftDecl('--tw-shadow', _v28),
        RaftDecl('box-shadow', _v27),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=file-preview-media]:size-full',
    1962,
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
    1961,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="file-preview"]', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
        RaftDecl('height', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd-group]:ml-1.5',
    1983,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd-group"]', [], 2000, [
        RaftDecl('margin-left', CssNum(6, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd]:font-normal',
    1979,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(400)),
        RaftDecl('font-weight', CssNum(400)),
      ]),
    ],
  ),
  RaftUtility('**:data-[slot=kbd]:h-4', 1974, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
      RaftDecl('height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility(
    '**:data-[slot=kbd]:min-w-4',
    1975,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('min-width', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility('**:data-[slot=kbd]:ml-1.5', 1973, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
      RaftDecl('margin-left', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('**:data-[slot=kbd]:px-1', 1976, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
      RaftDecl('padding-left', CssNum(4, 'px')),
      RaftDecl('padding-right', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('**:data-[slot=kbd]:py-0', 1977, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
      RaftDecl('padding-top', CssNum(0, 'px')),
      RaftDecl('padding-bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    '**:data-[slot=kbd]:relative',
    1971,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('position', CssKeyword('relative')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd]:text-[12px]/4',
    1978,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('font-size', CssNum(12, 'px')),
        RaftDecl('line-height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=kbd]:z-raised',
    1972,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="kbd"]', [], 2000, [
        RaftDecl('z-index', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:active:bg-transparent',
    2006,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]:active',
        [],
        3000,
        [RaftDecl('background-color', _v15)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:active:overlay-frame-medium',
    2007,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]:active',
        [],
        3000,
        [RaftDecl('background-image', _v30)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]:active',
        ['dark'],
        3000,
        [RaftDecl('background-image', _v32)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:data-checked:active:bg-layer-frame-active',
    2013,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"][data-checked]:active',
        [],
        4000,
        [RaftDecl('background-color', _v33)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"][data-checked]:active',
        ['dark'],
        4000,
        [RaftDecl('background-color', _v34)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:data-checked:bg-layer-frame-active',
    2009,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"][data-checked]',
        [],
        3000,
        [RaftDecl('background-color', _v33)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"][data-checked]',
        ['dark'],
        3000,
        [RaftDecl('background-color', _v34)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:data-checked:border-line-frame-active',
    2008,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"][data-checked]',
        [],
        3000,
        [
          RaftDecl('border-top-color', _v35),
          RaftDecl('border-right-color', _v35),
          RaftDecl('border-bottom-color', _v35),
          RaftDecl('border-left-color', _v35),
        ],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:data-checked:hover:bg-layer-frame-active',
    2011,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"][data-checked]:hover',
        [],
        4000,
        [RaftDecl('background-color', _v33)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"][data-checked]:hover',
        ['dark'],
        4000,
        [RaftDecl('background-color', _v34)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:data-checked:hover:bg-none',
    2012,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"][data-checked]:hover',
        [],
        4000,
        [RaftDecl('background-image', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:data-checked:text-foreground-on-frame-active',
    2010,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"][data-checked]',
        [],
        3000,
        [RaftDecl('color', _v36)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:hover:bg-transparent',
    2003,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]:hover',
        [],
        3000,
        [RaftDecl('background-color', _v15)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:hover:overlay-frame-medium',
    2004,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]:hover',
        [],
        3000,
        [RaftDecl('background-image', _v30)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]:hover',
        ['dark'],
        3000,
        [RaftDecl('background-image', _v32)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:hover:text-foreground-on-frame',
    2005,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]:hover',
        [],
        3000,
        [RaftDecl('color', _v37)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]:hover',
        ['dark'],
        3000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=segmented-control-item]:text-foreground-on-frame-muted',
    2002,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="segmented-control-item"]', [], 2000, [
        RaftDecl('color', _v38),
      ]),
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['dark'],
        2000,
        [RaftDecl('color', _v39)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:flex',
    2022,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('display', CssKeyword('flex')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:font-sans',
    2024,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('font-family', _v42),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:items-center',
    2023,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('align-items', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:normal-case',
    2027,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('text-transform', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:text-footnote',
    2025,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('font-size', CssNum(13, 'px')),
        RaftDecl('line-height', _v43),
      ]),
      RaftLayer(
        ':is(& *)[data-slot="sidebar-group-label"]',
        ['pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('font-size', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-group-label]:text-foreground-hint',
    2026,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-group-label"]', [], 2000, [
        RaftDecl('color', _v44),
      ]),
      RaftLayer(
        ':is(& *)[data-slot="sidebar-group-label"]',
        ['dark'],
        2000,
        [RaftDecl('color', _v39)],
      ),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-item-channel-icon]:h-lh',
    2028,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-item-channel-icon"]', [], 2000, [
        RaftDecl('height', CssNum(1, 'lh')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-item-icon]:h-lh',
    2030,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-item-icon"]', [], 2000, [
        RaftDecl('height', CssNum(1, 'lh')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-item-meta-icon]:h-lh',
    2031,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-item-meta-icon"]', [], 2000, [
        RaftDecl('height', CssNum(1, 'lh')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-section-chevron]:size-3.5',
    2032,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-section-chevron"]', [], 2000, [
        RaftDecl('width', CssNum(14, 'px')),
        RaftDecl('height', CssNum(14, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-section-chevron]:stroke-2',
    2033,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-section-chevron"]', [], 2000, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=sidebar-section-chevron]:transition-transform',
    2034,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="sidebar-section-chevron"]', [], 2000, [
        RaftDecl('transition-property', _v45),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=task-card-status-label]:inline-flex',
    2052,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="task-card-status-label"]', [], 2000, [
        RaftDecl('display', _v46),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=task-card-status-label]:items-center',
    2053,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="task-card-status-label"]', [], 2000, [
        RaftDecl('align-items', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-[slot=toast-content]:opacity-100',
    2055,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-slot="toast-content"]', [], 2000, [
        RaftDecl('opacity', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-activity-inbox-show-all:whitespace-nowrap',
    1622,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-activity-inbox-show-all]', [], 2000, [
        RaftDecl('white-space', CssKeyword('nowrap')),
      ]),
    ],
  ),
  RaftUtility('**:data-icon:size-[1em]', 1696, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)[data-icon]', [], 2000, [
      RaftDecl('width', CssNum(1, 'em')),
      RaftDecl('height', CssNum(1, 'em')),
    ]),
  ]),
  RaftUtility(
    '**:data-lightbox-close:inset-auto',
    1719,
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
    1721,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-lightbox-close]', [], 2000, [
        RaftDecl('right', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-lightbox-close:static',
    1718,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-lightbox-close]', [], 2000, [
        RaftDecl('position', CssKeyword('static')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-lightbox-close:top-auto',
    1720,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-lightbox-close]', [], 2000, [
        RaftDecl('top', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-message-item:bg-transparent',
    1723,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-message-item]', [], 2000, [
        RaftDecl('background-color', _v15),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-picker-trigger-indicator:opacity-100',
    1735,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-picker-trigger-indicator]', [], 2000, [
        RaftDecl('opacity', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '**:data-picker-trigger-indicator:text-foreground-hint',
    1734,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& *)[data-picker-trigger-indicator]', [], 2000, [
        RaftDecl('color', _v44),
      ]),
      RaftLayer(
        ':is(& *)[data-picker-trigger-indicator]',
        ['dark'],
        2000,
        [RaftDecl('color', _v39)],
      ),
    ],
  ),
  RaftUtility('**:select-none!', 1101, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)', [], 1000, [
      RaftDecl('-webkit-user-select', CssKeyword('none'), true),
      RaftDecl('user-select', CssKeyword('none'), true),
    ]),
  ]),
  RaftUtility('**:select-text', 1102, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& *)', [], 1000, [
      RaftDecl('-webkit-user-select', CssKeyword('text')),
      RaftDecl('user-select', CssKeyword('text')),
    ]),
  ]),
  RaftUtility(
    '*:[[role=menuitem]]:justify-center',
    2491,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *):is([role=menuitem])', [], 2000, [
        RaftDecl('justify-content', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility('*:col-start-1', 1097, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)', [], 1000, [
      RaftDecl('grid-column-start', CssNum(1)),
    ]),
  ]),
  RaftUtility(
    '*:data-[slot=avatar]:me-0.5',
    1910,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar"]', [], 2000, [
        RaftDecl('margin-right', CssNum(2, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar]:mt-[calc((1lh-19px)/2)]',
    1911,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar"]', [], 2000, [
        RaftDecl('margin-top', CssCalc(_v48)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar]:shrink-0',
    1914,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar"]', [], 2000, [
        RaftDecl('flex-shrink', CssNum(0)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar]:size-5',
    1912,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar"]', [], 2000, [
        RaftDecl('width', CssNum(20, 'px')),
        RaftDecl('height', CssNum(20, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=avatar]:size-[22px]',
    1913,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="avatar"]', [], 2000, [
        RaftDecl('width', CssNum(22, 'px')),
        RaftDecl('height', CssNum(22, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=button]:after:inset-x-[-3px]',
    1931,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]::after', [], 2001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('left', CssNum(-3, 'px')),
        RaftDecl('right', CssNum(-3, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=button]:first:after:-left-[(var(--header-air)+1.5px)]',
    1934,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]:first-child::after', [], 3001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('left', CssCalc(_v51)),
      ]),
      RaftLayer(
        ':is(& > *)[data-slot="button"]:first-child::after',
        ['pointer-fine', 'width>=768'],
        3001,
        [RaftDecl('left', CssNum(-6.5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '*:data-[slot=button]:first:after:left-[-9.5px]',
    1935,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]:first-child::after', [], 3001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('left', CssNum(-9.5, 'px')),
      ]),
    ],
  ),
  RaftUtility('*:data-[slot=button]:h-7', 1919, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)[data-slot="button"]', [], 2000, [
      RaftDecl('height', CssNum(28, 'px')),
    ]),
  ]),
  RaftUtility(
    '*:data-[slot=button]:last:after:-right-[(var(--header-air)+1.5px)]',
    1937,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]:last-child::after', [], 3001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('right', CssCalc(_v51)),
      ]),
      RaftLayer(
        ':is(& > *)[data-slot="button"]:last-child::after',
        ['pointer-fine', 'width>=768'],
        3001,
        [RaftDecl('right', CssNum(-6.5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '*:data-[slot=button]:last:after:right-[-9.5px]',
    1938,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]:last-child::after', [], 3001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('right', CssNum(-9.5, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=button]:min-w-7',
    1921,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]', [], 2000, [
        RaftDecl('min-width', CssNum(28, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=button]:ml-[-5px]',
    1917,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]', [], 2000, [
        RaftDecl('margin-left', CssNum(-5, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=button]:rounded-chip',
    1922,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]', [], 2000, [
        RaftDecl('border-top-left-radius', CssNum(6, 'px')),
        RaftDecl('border-top-right-radius', CssNum(6, 'px')),
        RaftDecl('border-bottom-right-radius', CssNum(6, 'px')),
        RaftDecl('border-bottom-left-radius', CssNum(6, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=button]:size-control-embedded',
    1918,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]', [], 2000, [
        RaftDecl('width', _v6),
        RaftDecl('height', _v6),
      ]),
      RaftLayer(
        ':is(& > *)[data-slot="button"]',
        ['pointer-fine', 'width>=768'],
        2000,
        [
          RaftDecl('width', CssNum(22, 'px')),
          RaftDecl('height', CssNum(22, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '*:data-[slot=button]:w-auto',
    1920,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="button"]', [], 2000, [
        RaftDecl('width', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=checkbox]:mt-[calc((1lh-1.25rem)/2)]',
    1941,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="checkbox"]', [], 2000, [
        RaftDecl('margin-top', CssCalc(_v53)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=combobox-input]:h-control-embedded',
    1943,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="combobox-input"]', [], 2000, [
        RaftDecl('height', _v6),
      ]),
      RaftLayer(
        ':is(& > *)[data-slot="combobox-input"]',
        ['pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('height', CssNum(22, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '*:data-[slot=description-item]:contents',
    1954,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="description-item"]', [], 2000, [
        RaftDecl('display', CssKeyword('contents')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=description-item]:flex',
    1955,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="description-item"]', [], 2000, [
        RaftDecl('display', CssKeyword('flex')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=description-item]:gap-3',
    1959,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="description-item"]', [], 2000, [
        RaftDecl('row-gap', CssNum(12, 'px')),
        RaftDecl('column-gap', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=description-item]:items-baseline',
    1958,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="description-item"]', [], 2000, [
        RaftDecl('align-items', CssKeyword('baseline')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=description-item]:max-w-[min(100%,24rem)]',
    1956,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="description-item"]', [], 2000, [
        RaftDecl('max-width', _v54),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=description-item]:min-w-0',
    1957,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="description-item"]', [], 2000, [
        RaftDecl('min-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=dialog-close]:my-0',
    1960,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="dialog-close"]', [], 2000, [
        RaftDecl('margin-top', CssNum(0, 'px')),
        RaftDecl('margin-bottom', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=inbox-item-marks]:empty:hidden',
    1967,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="inbox-item-marks"]:empty', [], 3000, [
        RaftDecl('display', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=input-group-control]:-my-(--ig-hit)',
    1969,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="input-group-control"]', [], 2000, [
        RaftDecl('margin-top', CssCalc(_v55)),
        RaftDecl('margin-bottom', CssCalc(_v55)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=input-group-control]:h-[calc(100%+2*var(--ig-hit))]',
    1970,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="input-group-control"]', [], 2000, [
        RaftDecl('height', CssCalc(_v57)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=input-group]:flex-1',
    1968,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="input-group"]', [], 2000, [
        RaftDecl('flex', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=message-item-meta]:-ms-1.5',
    1988,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="message-item-meta"]', [], 2000, [
        RaftDecl('margin-left', CssNum(-6, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=message-item-meta]:basis-0',
    1990,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="message-item-meta"]', [], 2000, [
        RaftDecl('flex-basis', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=message-item-meta]:before:content-[\'\']',
    1993,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="message-item-meta"]::before', [], 2001, [
        RaftDecl('--tw-content', CssString('')),
        RaftDecl('content', CssVar('--tw-content')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=message-item-meta]:before:inline-block',
    1991,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="message-item-meta"]::before', [], 2001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('display', _v58),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=message-item-meta]:before:w-1.5',
    1992,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="message-item-meta"]::before', [], 2001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('width', CssNum(6, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=message-item-meta]:grow',
    1989,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="message-item-meta"]', [], 2000, [
        RaftDecl('flex-grow', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=message-list-jump-pill]:rounded-e-none',
    1994,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="message-list-jump-pill"]', [], 2000, [
        RaftDecl('border-top-right-radius', CssNum(0)),
        RaftDecl('border-bottom-right-radius', CssNum(0)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=panel-action]:h-8',
    1995,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="panel-action"]', [], 2000, [
        RaftDecl('height', CssNum(32, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=panel-action]:min-w-8',
    1996,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="panel-action"]', [], 2000, [
        RaftDecl('min-width', CssNum(32, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=panel-toggle-action]:h-8',
    1997,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="panel-toggle-action"]', [], 2000, [
        RaftDecl('height', CssNum(32, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=panel-toggle-action]:min-w-8',
    1998,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="panel-toggle-action"]', [], 2000, [
        RaftDecl('min-width', CssNum(32, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=radio-group-item]:mt-[calc((1lh-1.25rem)/2)]',
    1999,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="radio-group-item"]', [], 2000, [
        RaftDecl('margin-top', CssCalc(_v53)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=spinner]:col-start-1',
    2035,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="spinner"]', [], 2000, [
        RaftDecl('grid-column-start', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=spinner]:h-lh',
    2037,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="spinner"]', [], 2000, [
        RaftDecl('height', CssNum(1, 'lh')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=spinner]:justify-self-center',
    2042,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="spinner"]', [], 2000, [
        RaftDecl('justify-self', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=spinner]:lead-icon',
    2039,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="spinner"]', [], 2000, [
        RaftDecl('flex-shrink', CssNum(0)),
        RaftDecl('align-self', CssKeyword('start')),
        RaftDecl('translate', _v60),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=spinner]:leading-[inherit]',
    2043,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="spinner"]', [], 2000, [
        RaftDecl('--tw-leading', CssKeyword('inherit')),
        RaftDecl('line-height', CssKeyword('inherit')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=spinner]:row-start-1',
    2036,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="spinner"]', [], 2000, [
        RaftDecl('grid-row-start', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=spinner]:self-center',
    2040,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="spinner"]', [], 2000, [
        RaftDecl('align-self', CssKeyword('center')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=spinner]:self-start',
    2041,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="spinner"]', [], 2000, [
        RaftDecl('align-self', _v61),
      ]),
    ],
  ),
  RaftUtility('*:data-[slot=spinner]:w-4', 2038, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)[data-slot="spinner"]', [], 2000, [
      RaftDecl('width', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility(
    '*:data-[slot=status]:absolute',
    2044,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="status"]', [], 2000, [
        RaftDecl('position', CssKeyword('absolute')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=status]:lead-dot',
    2047,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="status"]', [], 2000, [
        RaftDecl('--lead-dot', CssNum(10, 'px')),
        RaftDecl('flex-shrink', CssNum(0)),
        RaftDecl('width', CssVar('--lead-dot')),
        RaftDecl('height', CssVar('--lead-dot')),
        RaftDecl('border-top-width', CssNum(1.5, 'px')),
        RaftDecl('border-right-width', CssNum(1.5, 'px')),
        RaftDecl('border-bottom-width', CssNum(1.5, 'px')),
        RaftDecl('border-left-width', CssNum(1.5, 'px')),
        RaftDecl('margin-top', CssCalc(_v63)),
        RaftDecl('margin-bottom', CssCalc(_v63)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=status]:left-[calc(50%+6px)]',
    2046,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="status"]', [], 2000, [
        RaftDecl('left', CssCalc(_v64)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=status]:size-full',
    2048,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="status"]', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
        RaftDecl('height', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=status]:top-1',
    2045,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="status"]', [], 2000, [
        RaftDecl('top', CssNum(4, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=switch]:mt-[calc((1lh-var(--switch-height))/2)]',
    2049,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="switch"]', [], 2000, [
        RaftDecl('margin-top', CssCalc(_v67)),
      ]),
      RaftLayer(
        ':is(& > *)[data-slot="switch"]',
        ['pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('margin-top', CssCalc(_v69))],
      ),
    ],
  ),
  RaftUtility(
    '*:data-[slot=tabs-list]:data-[variant=default]:py-2',
    2086,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="tabs-list"][data-variant="default"]',
        [],
        3000,
        [
          RaftDecl('padding-top', CssNum(8, 'px')),
          RaftDecl('padding-bottom', CssNum(8, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '*:data-[slot=tabs-list]:px-5',
    2051,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="tabs-list"]', [], 2000, [
        RaftDecl('padding-left', CssNum(20, 'px')),
        RaftDecl('padding-right', CssNum(20, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=tabs-list]:w-full',
    2050,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="tabs-list"]', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-[slot=text-link]:text-footnote',
    2054,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-slot="text-link"]', [], 2000, [
        RaftDecl('font-size', CssNum(13, 'px')),
        RaftDecl('line-height', _v43),
      ]),
      RaftLayer(
        ':is(& > *)[data-slot="text-link"]',
        ['pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('font-size', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '*:data-[variant=container]:data-[align=inline-end]:rounded-e-[calc(var(--radius-control)-1.5px)]',
    2084,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-variant="container"][data-align="inline-end"]',
        [],
        3000,
        [
          RaftDecl('border-top-right-radius', CssNum(6.5, 'px')),
          RaftDecl('border-bottom-right-radius', CssNum(6.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '*:data-[variant=container]:data-[align=inline-start]:rounded-s-[calc(var(--radius-control)-1.5px)]',
    2085,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-variant="container"][data-align="inline-start"]',
        [],
        3000,
        [
          RaftDecl('border-top-left-radius', CssNum(6.5, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(6.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '*:data-inbox-item-time:cursor-default',
    1698,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-inbox-item-time]', [], 2000, [
        RaftDecl('cursor', CssKeyword('default')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-inbox-item-time:pointer-events-auto',
    1697,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-inbox-item-time]', [], 2000, [
        RaftDecl('pointer-events', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:absolute',
    1714,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('position', CssKeyword('absolute')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:pointer-events-auto',
    1713,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('pointer-events', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:right-[calc(16px+env(safe-area-inset-right,0px))]',
    1716,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('right', CssCalc(_v72)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:top-[calc(16px+env(safe-area-inset-top,0px))]',
    1715,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('top', CssCalc(_v75)),
      ]),
    ],
  ),
  RaftUtility(
    '*:data-lightbox-close:z-raised',
    1717,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *)[data-lightbox-close]', [], 2000, [
        RaftDecl('z-index', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility('*:min-w-0', 1099, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)', [], 1000, [RaftDecl('min-width', CssNum(0, 'px'))]),
  ]),
  RaftUtility(
    '*:not-data-[reveal=hover]:mr-(--inbox-item-aside-room,0px)',
    1105,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *):not([data-reveal="hover"])', [], 2000, [
        RaftDecl('margin-right', _v76),
      ]),
    ],
  ),
  RaftUtility(
    '*:not-data-[reveal=hover]:opacity-[calc(1-var(--inbox-item-reveal-aside,0)*var(--inbox-item-revealed,0))]',
    1106,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *):not([data-reveal="hover"])', [], 2000, [
        RaftDecl('opacity', CssCalc(_v79)),
      ]),
    ],
  ),
  RaftUtility(
    '*:not-data-[reveal=hover]:transition-opacity',
    1107,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *):not([data-reveal="hover"])', [], 2000, [
        RaftDecl('transition-property', CssKeyword('opacity')),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    '*:not-data-[slot=inbox-item-marks]:flex-1',
    1109,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *):not([data-slot="inbox-item-marks"])', [], 2000, [
        RaftDecl('flex', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '*:not-data-[slot=inbox-item-marks]:min-w-0',
    1108,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(':is(& > *):not([data-slot="inbox-item-marks"])', [], 2000, [
        RaftDecl('min-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility('*:pointer-events-auto', 1094, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)', [], 1000, [
      RaftDecl('pointer-events', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('*:relative', 1095, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)', [], 1000, [
      RaftDecl('position', CssKeyword('relative')),
    ]),
  ]),
  RaftUtility('*:shrink-0', 1100, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)', [], 1000, [RaftDecl('flex-shrink', CssNum(0))]),
  ]),
  RaftUtility('*:size-full', 1098, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)', [], 1000, [
      RaftDecl('width', CssNum(100, '%')),
      RaftDecl('height', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility('*:z-raised', 1096, RaftUtilityStatus.descendant, [
    RaftLayer(':is(& > *)', [], 1000, [RaftDecl('z-index', CssNum(1))]),
  ]),
  RaftUtility('-bottom-0.5', 48, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(-2, 'px'))]),
  ]),
  RaftUtility('-bottom-1', 49, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-col-start-3', 90, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', CssNum(-3))]),
  ]),
  RaftUtility('-inset-px', 14, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('top', CssNum(-1, 'px')),
      RaftDecl('right', CssNum(-1, 'px')),
      RaftDecl('bottom', CssNum(-1, 'px')),
      RaftDecl('left', CssNum(-1, 'px')),
    ]),
  ]),
  RaftUtility('-m-1', 105, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(-4, 'px')),
      RaftDecl('margin-right', CssNum(-4, 'px')),
      RaftDecl('margin-bottom', CssNum(-4, 'px')),
      RaftDecl('margin-left', CssNum(-4, 'px')),
    ]),
  ]),
  RaftUtility('-me-icon-inset', 123, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssCalc(_v80))]),
  ]),
  RaftUtility('-ml-1', 155, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-left', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-mr-1', 141, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-mr-3', 142, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssNum(-12, 'px'))]),
  ]),
  RaftUtility('-mr-[calc((32px-18px)/2)]', 143, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssNum(-7, 'px'))]),
  ]),
  RaftUtility('-mt-1', 129, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-mx-1', 107, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-left', CssNum(-4, 'px')),
      RaftDecl('margin-right', CssNum(-4, 'px')),
    ]),
  ]),
  RaftUtility('-my-1', 111, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(-4, 'px')),
      RaftDecl('margin-bottom', CssNum(-4, 'px')),
    ]),
  ]),
  RaftUtility('-my-1.5', 112, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(-6, 'px')),
      RaftDecl('margin-bottom', CssNum(-6, 'px')),
    ]),
  ]),
  RaftUtility(
    '-my-[calc((--spacing(8)-1lh)/2)]',
    113,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('margin-top', CssCalc(_v83)),
        RaftDecl('margin-bottom', CssCalc(_v83)),
      ]),
    ],
  ),
  RaftUtility('-order-1', 82, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('order', CssNum(-1))]),
  ]),
  RaftUtility('-right-0.5', 35, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(-2, 'px'))]),
  ]),
  RaftUtility('-right-1', 36, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-right-1.5', 37, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(-6, 'px'))]),
  ]),
  RaftUtility('-right-2.5', 38, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(-10, 'px'))]),
  ]),
  RaftUtility('-right-3', 39, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(-12, 'px'))]),
  ]),
  RaftUtility('-rotate-90', 418, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('rotate', CssNum(-90, 'deg'))]),
  ]),
  RaftUtility('-top-1', 22, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(-4, 'px'))]),
  ]),
  RaftUtility('-top-1.5', 23, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(-6, 'px'))]),
  ]),
  RaftUtility('-translate-1/2', 412, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-x', CssNum(-50, '%')),
      RaftDecl('--tw-translate-y', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v84, _v85])),
    ]),
  ]),
  RaftUtility('-translate-x-1/2', 413, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-x', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v84, _v85])),
    ]),
  ]),
  RaftUtility('-translate-y-0.5', 414, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-y', CssNum(-2, 'px')),
      RaftDecl('translate', CssSeq([_v84, _v85])),
    ]),
  ]),
  RaftUtility('-translate-y-1/2', 415, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-translate-y', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v84, _v85])),
    ]),
  ]),
  RaftUtility('@container', 4, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('container-type', _v86)]),
  ]),
  RaftUtility('@container/announcement', 0, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('container-type', _v86),
      RaftDecl('container-name', _v87),
    ]),
  ]),
  RaftUtility('@container/bundle', 1, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('container-type', _v86),
      RaftDecl('container-name', CssKeyword('bundle')),
    ]),
  ]),
  RaftUtility('@container/gallery', 2, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('container-type', _v86),
      RaftDecl('container-name', CssKeyword('gallery')),
    ]),
  ]),
  RaftUtility('@container/tasks', 3, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('container-type', _v86),
      RaftDecl('container-name', CssKeyword('tasks')),
    ]),
  ]),
  RaftUtility(
    '@max-2xl:**:data-[slot=segmented-control-count]:sr-only',
    2158,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-count"]',
        ['container-width<672'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-2xl:**:data-[slot=segmented-control-item]:px-0',
    2161,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<672'],
        2000,
        [
          RaftDecl('padding-left', CssNum(0, 'px')),
          RaftDecl('padding-right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-2xl:**:data-[slot=segmented-control-item]:relative',
    2159,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<672'],
        2000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    '@max-2xl:**:data-[slot=segmented-control-item]:w-(--segment-size)',
    2160,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<672'],
        2000,
        [RaftDecl('width', _v89)],
      ),
    ],
  ),
  RaftUtility(
    '@max-2xl:**:data-[slot=segmented-control-label]:sr-only',
    2162,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-label"]',
        ['container-width<672'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-[28rem]/announcement:flex-col',
    2175,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:announcement (width < 28rem)'],
        1000,
        [RaftDecl('flex-direction', CssKeyword('column'))],
      ),
    ],
  ),
  RaftUtility(
    '@max-[28rem]/announcement:ml-0',
    2173,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:announcement (width < 28rem)'],
        1000,
        [RaftDecl('margin-left', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '@max-[28rem]/announcement:w-full',
    2174,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:announcement (width < 28rem)'],
        1000,
        [RaftDecl('width', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    '@max-[320px]/inbox-item-row:hidden',
    2156,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:inbox-item-row (width < 320px)'],
        1000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    '@max-[320px]/inbox-item-row:inline-flex',
    2157,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:inbox-item-row (width < 320px)'],
        1000,
        [RaftDecl('display', _v46)],
      ),
    ],
  ),
  RaftUtility(
    '@max-lg:**:data-[slot=segmented-control-count]:sr-only',
    2168,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-count"]',
        ['container-width<512'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-lg:**:data-[slot=segmented-control-item]:px-0',
    2171,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<512'],
        2000,
        [
          RaftDecl('padding-left', CssNum(0, 'px')),
          RaftDecl('padding-right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-lg:**:data-[slot=segmented-control-item]:relative',
    2169,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<512'],
        2000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    '@max-lg:**:data-[slot=segmented-control-item]:w-(--segment-size)',
    2170,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<512'],
        2000,
        [RaftDecl('width', _v89)],
      ),
    ],
  ),
  RaftUtility(
    '@max-lg:**:data-[slot=segmented-control-label]:sr-only',
    2172,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-label"]',
        ['container-width<512'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility('@max-md/tasks:px-4', 2176, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['container:tasks (width < 28rem)'],
      1000,
      [
        RaftDecl('padding-left', CssNum(16, 'px')),
        RaftDecl('padding-right', CssNum(16, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    '@max-md:**:data-[slot=segmented-control-count]:sr-only',
    2177,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-count"]',
        ['container-width<448'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-md:**:data-[slot=segmented-control-item]:px-0',
    2180,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<448'],
        2000,
        [
          RaftDecl('padding-left', CssNum(0, 'px')),
          RaftDecl('padding-right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-md:**:data-[slot=segmented-control-item]:relative',
    2178,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<448'],
        2000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    '@max-md:**:data-[slot=segmented-control-item]:w-(--segment-size)',
    2179,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<448'],
        2000,
        [RaftDecl('width', _v89)],
      ),
    ],
  ),
  RaftUtility(
    '@max-md:**:data-[slot=segmented-control-label]:sr-only',
    2181,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-label"]',
        ['container-width<448'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-sm:**:data-[slot=segmented-control-count]:sr-only',
    2182,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-count"]',
        ['container-width<384'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-sm:**:data-[slot=segmented-control-item]:px-0',
    2185,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<384'],
        2000,
        [
          RaftDecl('padding-left', CssNum(0, 'px')),
          RaftDecl('padding-right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-sm:**:data-[slot=segmented-control-item]:relative',
    2183,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<384'],
        2000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    '@max-sm:**:data-[slot=segmented-control-item]:w-(--segment-size)',
    2184,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<384'],
        2000,
        [RaftDecl('width', _v89)],
      ),
    ],
  ),
  RaftUtility(
    '@max-sm:**:data-[slot=segmented-control-label]:sr-only',
    2186,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-label"]',
        ['container-width<384'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-xl:**:data-[slot=segmented-control-count]:sr-only',
    2163,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-count"]',
        ['container-width<576'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-xl:**:data-[slot=segmented-control-item]:px-0',
    2166,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<576'],
        2000,
        [
          RaftDecl('padding-left', CssNum(0, 'px')),
          RaftDecl('padding-right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-xl:**:data-[slot=segmented-control-item]:relative',
    2164,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<576'],
        2000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    '@max-xl:**:data-[slot=segmented-control-item]:w-(--segment-size)',
    2165,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<576'],
        2000,
        [RaftDecl('width', _v89)],
      ),
    ],
  ),
  RaftUtility(
    '@max-xl:**:data-[slot=segmented-control-label]:sr-only',
    2167,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-label"]',
        ['container-width<576'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-xs:**:data-[slot=segmented-control-count]:sr-only',
    2187,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-count"]',
        ['container-width<320'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-xs:**:data-[slot=segmented-control-item]:px-0',
    2190,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<320'],
        2000,
        [
          RaftDecl('padding-left', CssNum(0, 'px')),
          RaftDecl('padding-right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@max-xs:**:data-[slot=segmented-control-item]:relative',
    2188,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<320'],
        2000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    '@max-xs:**:data-[slot=segmented-control-item]:w-(--segment-size)',
    2189,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['container-width<320'],
        2000,
        [RaftDecl('width', _v89)],
      ),
    ],
  ),
  RaftUtility(
    '@max-xs:**:data-[slot=segmented-control-label]:sr-only',
    2191,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-label"]',
        ['container-width<320'],
        2000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '@min-[360px]/bundle:auto-rows-32',
    2192,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:bundle (width >= 360px)'],
        1000,
        [RaftDecl('grid-auto-rows', CssNum(128, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '@min-[360px]/bundle:auto-rows-36',
    2193,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:bundle (width >= 360px)'],
        1000,
        [RaftDecl('grid-auto-rows', CssNum(144, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '@min-[360px]/gallery:auto-rows-[8rem]',
    2194,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:gallery (width >= 360px)'],
        1000,
        [RaftDecl('grid-auto-rows', CssNum(128, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '@min-[360px]/gallery:auto-rows-[9rem]',
    2195,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:gallery (width >= 360px)'],
        1000,
        [RaftDecl('grid-auto-rows', CssNum(144, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '@min-[452px]:has-[~[data-slot=banner-description]~[data-slot=banner-action]:not([data-wrap])]:col-end-[span_2]',
    2203,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'container-width>=452',
          'has:~data-slot=banner-description~data-slot=banner-action+not:data-wrap',
        ],
        4000,
        [RaftDecl('grid-column-end', _v90)],
      ),
    ],
  ),
  RaftUtility(
    '@min-[452px]:not-data-wrap:col-end-auto',
    2197,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container-width>=452', 'not:data-wrap'],
        2000,
        [RaftDecl('grid-column-end', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    '@min-[452px]:not-data-wrap:col-start-[calc(var(--banner-text-col,1)+1)]',
    2196,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container-width>=452', 'not:data-wrap'],
        2000,
        [RaftDecl('grid-column-start', CssCalc(_v92))],
      ),
    ],
  ),
  RaftUtility(
    '@min-[452px]:not-data-wrap:flex-nowrap',
    2201,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container-width>=452', 'not:data-wrap'],
        2000,
        [RaftDecl('flex-wrap', CssKeyword('nowrap'))],
      ),
    ],
  ),
  RaftUtility(
    '@min-[452px]:not-data-wrap:h-lh',
    2200,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container-width>=452', 'not:data-wrap'],
        2000,
        [RaftDecl('height', CssNum(1, 'lh'))],
      ),
    ],
  ),
  RaftUtility(
    '@min-[452px]:not-data-wrap:mt-0',
    2199,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container-width>=452', 'not:data-wrap'],
        2000,
        [RaftDecl('margin-top', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '@min-[452px]:not-data-wrap:row-start-(--banner-last-row,1)',
    2198,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container-width>=452', 'not:data-wrap'],
        2000,
        [RaftDecl('grid-row-start', _v93)],
      ),
    ],
  ),
  RaftUtility(
    '@min-[452px]:not-data-wrap:self-end',
    2202,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container-width>=452', 'not:data-wrap'],
        2000,
        [RaftDecl('align-self', CssKeyword('flex-end'))],
      ),
    ],
  ),
  RaftUtility('@min-md/tasks:flex', 2205, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['container:tasks (width >= 28rem)'],
      1000,
      [RaftDecl('display', CssKeyword('flex'))],
    ),
  ]),
  RaftUtility('@min-md/tasks:flex-wrap', 2206, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['container:tasks (width >= 28rem)'],
      1000,
      [RaftDecl('flex-wrap', CssKeyword('wrap'))],
    ),
  ]),
  RaftUtility('@min-md/tasks:items-center', 2207, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['container:tasks (width >= 28rem)'],
      1000,
      [RaftDecl('align-items', CssKeyword('center'))],
    ),
  ]),
  RaftUtility(
    '@min-md/tasks:justify-between',
    2208,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:tasks (width >= 28rem)'],
        1000,
        [RaftDecl('justify-content', _v5)],
      ),
    ],
  ),
  RaftUtility('@min-md/tasks:mr-auto', 2204, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['container:tasks (width >= 28rem)'],
      1000,
      [RaftDecl('margin-right', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility('[&+&]:pt-2', 2487, RaftUtilityStatus.descendant, [
    RaftLayer('& + .\\[\\&\\+\\&\\]\\:pt-2', [], 2000, [
      RaftDecl('padding-top', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&::-webkit-scrollbar]:hidden',
    2488,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::-webkit-scrollbar', [], 1001, [
        RaftDecl('display', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '[&::-webkit-search-cancel-button]:appearance-none',
    2489,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::-webkit-search-cancel-button', [], 1001, [
        RaftDecl('appearance', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '[&:not(:has([data-slot=task-card-status-label]))]:hidden',
    2495,
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
    2496,
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
    2497,
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
    2498,
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
        [RaftDecl('min-height', _v94)],
      ),
    ],
  ),
  RaftUtility(
    '[&:not([data-has-icon]):not([data-has-actions]):not([data-has-description])]:min-w-(--toast-title-only-min-w,7rem)',
    2499,
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
        [RaftDecl('min-width', _v95)],
      ),
    ],
  ),
  RaftUtility(
    '[&:not([data-has-icon]):not([data-has-actions]):not([data-has-description])]:px-(--toast-title-only-px,0.75rem)',
    2500,
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
        [RaftDecl('padding-left', _v96), RaftDecl('padding-right', _v96)],
      ),
    ],
  ),
  RaftUtility(
    '[&:not([data-has-icon]):not([data-has-actions]):not([data-has-description])]:py-(--toast-title-only-py,0.5rem)',
    2501,
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
        [RaftDecl('padding-top', _v97), RaftDecl('padding-bottom', _v97)],
      ),
    ],
  ),
  RaftUtility(
    '[&>:not([data-slot=combobox-chip-remove])]:min-w-0',
    2503,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > :not([data-slot=combobox-chip-remove])', [], 2000, [
        RaftDecl('min-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>:not([data-slot=combobox-chip-remove])]:truncate',
    2504,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > :not([data-slot=combobox-chip-remove])', [], 2000, [
        RaftDecl('overflow-x', CssKeyword('hidden')),
        RaftDecl('overflow-y', CssKeyword('hidden')),
        RaftDecl('text-overflow', CssKeyword('ellipsis')),
        RaftDecl('white-space', CssKeyword('nowrap')),
      ]),
    ],
  ),
  RaftUtility('[&>:not(svg)]:min-w-0', 2505, RaftUtilityStatus.descendant, [
    RaftLayer('& > :not(svg)', [], 1001, [
      RaftDecl('min-width', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&>[data-icon-inset]:nth-child(1_of_:not([data-base-ui-focus-guard],[aria-owns]))]:-ml-icon-inset',
    2506,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-icon-inset]:nth-child(1 of :not([data-base-ui-focus-guard], [aria-owns]))',
        [],
        4000,
        [RaftDecl('margin-left', CssCalc(_v80))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-icon-inset]:nth-last-child(1_of_:not([data-base-ui-focus-guard],[aria-owns]))]:-me-icon-inset',
    2507,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-icon-inset]:nth-last-child(1 of :not([data-base-ui-focus-guard], [aria-owns]))',
        [],
        4000,
        [RaftDecl('margin-right', CssCalc(_v80))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-icon-inset]:nth-last-child(1_of_:not([data-base-ui-focus-guard],[aria-owns]))]:-mr-icon-inset',
    2508,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-icon-inset]:nth-last-child(1 of :not([data-base-ui-focus-guard], [aria-owns]))',
        [],
        4000,
        [RaftDecl('margin-right', CssCalc(_v80))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=button]:last-child]:me-[calc(var(--control-embedded-inset)-0.75rem-1px)]',
    2510,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=button]:last-child', [], 3000, [
        RaftDecl('margin-right', CssCalc(_v100)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=button]_svg:not([class*=\'size-\'])]:size-4',
    2509,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=button] svg:not([class*=\'size-\'])',
        [],
        3001,
        [
          RaftDecl('width', CssNum(16, 'px')),
          RaftDecl('height', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=combobox-clear]:last-child]:me-[calc(var(--control-embedded-inset)-0.75rem-1px)]',
    2511,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=combobox-clear]:last-child', [], 3000, [
        RaftDecl('margin-right', CssCalc(_v100)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]+[data-slot=description-item]]:pt-0',
    2512,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] + [data-slot=description-item]',
        [],
        3000,
        [RaftDecl('padding-top', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-details]>:is([data-slot=task-chip],[data-slot=task-status-badge]):first-child]:max-w-[calc(100%+7px)]',
    2517,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details] > :is([data-slot=task-chip], [data-slot=task-status-badge]):first-child',
        [],
        5000,
        [RaftDecl('max-width', CssCalc(_v101))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-details]>:is([data-slot=task-chip],[data-slot=task-status-badge]):first-child]:ml-[-7px]',
    2516,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details] > :is([data-slot=task-chip], [data-slot=task-status-badge]):first-child',
        [],
        5000,
        [RaftDecl('margin-left', CssNum(-7, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-details]>[data-slot=badge]:first-child]:-ml-1.5',
    2518,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details] > [data-slot=badge]:first-child',
        [],
        5000,
        [RaftDecl('margin-left', CssNum(-6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-details]>[data-slot=badge]:first-child]:max-w-[calc(100%+6px)]',
    2519,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details] > [data-slot=badge]:first-child',
        [],
        5000,
        [RaftDecl('max-width', CssCalc(_v102))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-details]>[data-slot=button]:first-child]:ml-[-7.5px]',
    2520,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details] > [data-slot=button]:first-child',
        [],
        5000,
        [RaftDecl('margin-left', CssNum(-7.5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-details]>[data-slot=button]:first-child]:px-1.5',
    2521,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details] > [data-slot=button]:first-child',
        [],
        5000,
        [
          RaftDecl('padding-left', CssNum(6, 'px')),
          RaftDecl('padding-right', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-details]]:min-h-8',
    2513,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details]',
        [],
        3000,
        [RaftDecl('min-height', CssNum(32, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-details]]:min-w-0',
    2514,
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
    2515,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details]',
        [],
        3000,
        [RaftDecl('overflow-wrap', _v103)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-term]]:max-w-40',
    2523,
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
    2522,
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
    2524,
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
    '[&>[data-slot=description-item]>[data-slot=description-term]]:shrink-0',
    2525,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-term]',
        [],
        3000,
        [RaftDecl('flex-shrink', CssNum(0))],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=description-item]>[data-slot=description-term]]:wrap-break-word',
    2526,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-term]',
        [],
        3000,
        [RaftDecl('overflow-wrap', _v103)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=dialog-surface]]:flex-1',
    2531,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=dialog-surface]', [], 2000, [
        RaftDecl('flex', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=dialog-surface]]:max-h-none',
    2527,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=dialog-surface]', [], 2000, [
        RaftDecl('max-height', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=dialog-surface]]:max-w-none',
    2530,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=dialog-surface]', [], 2000, [
        RaftDecl('max-width', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=dialog-surface]]:min-h-0',
    2528,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=dialog-surface]', [], 2000, [
        RaftDecl('min-height', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=dialog-surface]]:ring-0',
    2534,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=dialog-surface]', [], 2000, [
        RaftDecl('--tw-ring-shadow', _v22),
        RaftDecl('box-shadow', _v27),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=dialog-surface]]:rounded-none',
    2532,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=dialog-surface]', [], 2000, [
        RaftDecl('border-top-left-radius', CssNum(0)),
        RaftDecl('border-top-right-radius', CssNum(0)),
        RaftDecl('border-bottom-right-radius', CssNum(0)),
        RaftDecl('border-bottom-left-radius', CssNum(0)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=dialog-surface]]:shadow-none',
    2533,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=dialog-surface]', [], 2000, [
        RaftDecl('--tw-shadow', _v28),
        RaftDecl('box-shadow', _v27),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=dialog-surface]]:w-full',
    2529,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=dialog-surface]', [], 2000, [
        RaftDecl('width', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=empty-state-icon]]:mb-0',
    2535,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=empty-state-icon]', [], 2000, [
        RaftDecl('margin-bottom', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=empty-state-title]]:mb-0',
    2536,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=empty-state-title]', [], 2000, [
        RaftDecl('margin-bottom', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=input-group]]:min-w-0',
    2537,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=input-group]', [], 2000, [
        RaftDecl('min-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-action]>svg]:size-[18px]',
    2538,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=panel-action] > svg', [], 2001, [
        RaftDecl('width', CssNum(18, 'px')),
        RaftDecl('height', CssNum(18, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action]>svg]:size-[18px]',
    2539,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=panel-toggle-action] > svg', [], 2001, [
        RaftDecl('width', CssNum(18, 'px')),
        RaftDecl('height', CssNum(18, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]]:active:bg-fill-medium',
    2544,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]:active',
        [],
        4000,
        [RaftDecl('background-color', _v104)],
      ),
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]:active',
        ['dark'],
        4000,
        [RaftDecl('background-color', _v105)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]]:bg-transparent',
    2541,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=panel-toggle-action][data-pressed]', [], 3000, [
        RaftDecl('background-color', _v15),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]]:border-transparent',
    2540,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=panel-toggle-action][data-pressed]', [], 3000, [
        RaftDecl('border-top-color', _v15),
        RaftDecl('border-right-color', _v15),
        RaftDecl('border-bottom-color', _v15),
        RaftDecl('border-left-color', _v15),
      ]),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]]:hover:bg-fill-medium',
    2543,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]:hover',
        [],
        4000,
        [RaftDecl('background-color', _v104)],
      ),
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]:hover',
        ['dark'],
        4000,
        [RaftDecl('background-color', _v105)],
      ),
    ],
  ),
  RaftUtility(
    '[&>[data-slot=panel-toggle-action][data-pressed]]:text-foreground',
    2542,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [data-slot=panel-toggle-action][data-pressed]', [], 3000, [
        RaftDecl('color', _v0),
      ]),
      RaftLayer(
        '& > [data-slot=panel-toggle-action][data-pressed]',
        ['dark'],
        3000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility('[&>[role=menuitem]]:p-0', 2546, RaftUtilityStatus.descendant, [
    RaftLayer('& > [role=menuitem]', [], 2000, [
      RaftDecl('padding-top', CssNum(0, 'px')),
      RaftDecl('padding-right', CssNum(0, 'px')),
      RaftDecl('padding-bottom', CssNum(0, 'px')),
      RaftDecl('padding-left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&>[role=menuitem]]:size-9',
    2545,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > [role=menuitem]', [], 2000, [
        RaftDecl('width', CssNum(36, 'px')),
        RaftDecl('height', CssNum(36, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&>a]:decoration-[1.5px]', 2549, RaftUtilityStatus.descendant, [
    RaftLayer('& > a', [], 1001, [
      RaftDecl('text-decoration-thickness', CssNum(1.5, 'px')),
    ]),
  ]),
  RaftUtility('[&>a]:font-semibold', 2548, RaftUtilityStatus.descendant, [
    RaftLayer('& > a', [], 1001, [
      RaftDecl('--tw-font-weight', CssNum(600)),
      RaftDecl('font-weight', CssNum(600)),
    ]),
  ]),
  RaftUtility(
    '[&>a]:hover:text-foreground',
    2551,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > a:hover', [], 2001, [RaftDecl('color', _v0)]),
      RaftLayer('& > a:hover', ['dark'], 2001, [RaftDecl('color', _v1)]),
    ],
  ),
  RaftUtility('[&>a]:hover:underline', 2552, RaftUtilityStatus.descendant, [
    RaftLayer('& > a:hover', [], 2001, [
      RaftDecl('text-decoration-line', CssKeyword('underline')),
    ]),
  ]),
  RaftUtility(
    '[&>a]:underline-offset-[3px]',
    2550,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > a', [], 1001, [
        RaftDecl('text-underline-offset', CssNum(3, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&>img]:object-cover', 2554, RaftUtilityStatus.descendant, [
    RaftLayer('& > img', [], 1001, [
      RaftDecl('object-fit', CssKeyword('cover')),
    ]),
  ]),
  RaftUtility('[&>img]:rounded-[2px]', 2553, RaftUtilityStatus.descendant, [
    RaftLayer('& > img', [], 1001, [
      RaftDecl('border-top-left-radius', CssNum(2, 'px')),
      RaftDecl('border-top-right-radius', CssNum(2, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(2, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('[&>label]:font-semibold', 2555, RaftUtilityStatus.descendant, [
    RaftLayer('& > label', [], 1001, [
      RaftDecl('--tw-font-weight', CssNum(600)),
      RaftDecl('font-weight', CssNum(600)),
    ]),
  ]),
  RaftUtility(
    '[&>span[data-slot=\'combobox-trigger-content\']>svg:not([class*=\'size-\'])]:size-3.5',
    2564,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > span[data-slot=\'combobox-trigger-content\'] > svg:not([class*=\'size-\'])',
        [],
        3002,
        [
          RaftDecl('width', CssNum(14, 'px')),
          RaftDecl('height', CssNum(14, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'combobox-trigger-content\']>svg:not([class*=\'stroke-\'])]:stroke-2',
    2565,
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
    '[&>span[data-slot=\'combobox-trigger-content\']>svg]:shrink-0',
    2563,
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
    2562,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > span[data-slot=\'combobox-trigger-content\']', [], 2001, [
        RaftDecl('flex', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'combobox-trigger-content\']]:min-w-0',
    2561,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > span[data-slot=\'combobox-trigger-content\']', [], 2001, [
        RaftDecl('min-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'select-trigger-content\']]:flex-1',
    2567,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > span[data-slot=\'select-trigger-content\']', [], 2001, [
        RaftDecl('flex', CssNum(1)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>span[data-slot=\'select-trigger-content\']]:min-w-0',
    2566,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > span[data-slot=\'select-trigger-content\']', [], 2001, [
        RaftDecl('min-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&>span]:max-w-full', 2559, RaftUtilityStatus.descendant, [
    RaftLayer('& > span', [], 1001, [RaftDecl('max-width', CssNum(100, '%'))]),
  ]),
  RaftUtility('[&>span]:truncate', 2560, RaftUtilityStatus.descendant, [
    RaftLayer('& > span', [], 1001, [
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
      RaftDecl('text-overflow', CssKeyword('ellipsis')),
      RaftDecl('white-space', CssKeyword('nowrap')),
    ]),
  ]),
  RaftUtility(
    '[&>svg:first-child]:size-4',
    2610,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:first-child', [], 2001, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg:first-child]:text-foreground-muted',
    2611,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:first-child', [], 2001, [RaftDecl('color', _v2)]),
      RaftLayer(
        '& > svg:first-child',
        ['dark'],
        2001,
        [RaftDecl('color', _v3)],
      ),
    ],
  ),
  RaftUtility('[&>svg:last-child]:size-3', 2613, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg:last-child', [], 2001, [
      RaftDecl('width', CssNum(12, 'px')),
      RaftDecl('height', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&>svg:not([class*=\'size-\'])]:size-3.5',
    2614,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(14, 'px')),
        RaftDecl('height', CssNum(14, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg:not([class*=\'size-\'])]:size-4',
    2615,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg:not([class*=\'size-\'])]:size-4.5',
    2616,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(18, 'px')),
        RaftDecl('height', CssNum(18, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg:not([class*=\'size-\'])]:size-[18px]',
    2617,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(18, 'px')),
        RaftDecl('height', CssNum(18, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg:not([class*=\'stroke-\'])]:stroke-2',
    2618,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([class*=\'stroke-\'])', [], 2001, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg:not([data-slot=task-status-icon])]:-mx-0.5',
    2619,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([data-slot=task-status-icon])', [], 2001, [
        RaftDecl('margin-left', CssNum(-2, 'px')),
        RaftDecl('margin-right', CssNum(-2, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg:not([data-slot=task-status-icon])]:mx-0',
    2620,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg:not([data-slot=task-status-icon])', [], 2001, [
        RaftDecl('margin-left', CssNum(0, 'px')),
        RaftDecl('margin-right', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>svg[data-slot=task-status-icon]]:size-2.5',
    2621,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg[data-slot=task-status-icon]', [], 2001, [
        RaftDecl('width', CssNum(10, 'px')),
        RaftDecl('height', CssNum(10, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&>svg]:absolute', 2569, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('position', CssKeyword('absolute')),
    ]),
  ]),
  RaftUtility('[&>svg]:block', 2579, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('display', CssKeyword('block'))]),
  ]),
  RaftUtility('[&>svg]:col-start-1', 2574, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('grid-column-start', CssNum(1))]),
  ]),
  RaftUtility('[&>svg]:duration-200', 2599, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('--tw-duration', CssNum(200, 'ms')),
      RaftDecl('transition-duration', CssNum(200, 'ms')),
    ]),
  ]),
  RaftUtility('[&>svg]:hidden', 2580, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('display', CssKeyword('none'))]),
  ]),
  RaftUtility('[&>svg]:lead-icon', 2589, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('flex-shrink', CssNum(0)),
      RaftDecl('align-self', CssKeyword('start')),
      RaftDecl('translate', _v60),
    ]),
  ]),
  RaftUtility('[&>svg]:left-0', 2572, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('left', CssNum(0, 'px'))]),
  ]),
  RaftUtility(
    '[&>svg]:mt-[calc((1lh-14px)/2)]',
    2576,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [RaftDecl('margin-top', CssCalc(_v107))]),
    ],
  ),
  RaftUtility(
    '[&>svg]:mt-[calc((1lh-16px)/2)]',
    2577,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [RaftDecl('margin-top', CssCalc(_v109))]),
    ],
  ),
  RaftUtility(
    '[&>svg]:mt-[calc((1lh-20px)/2)]',
    2578,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [RaftDecl('margin-top', CssCalc(_v53))]),
    ],
  ),
  RaftUtility(
    '[&>svg]:pointer-events-none',
    2568,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [
        RaftDecl('pointer-events', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility('[&>svg]:relative', 2570, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('position', CssKeyword('relative')),
    ]),
  ]),
  RaftUtility('[&>svg]:row-start-1', 2575, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('grid-row-start', CssNum(1))]),
  ]),
  RaftUtility('[&>svg]:self-center', 2592, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('align-self', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('[&>svg]:shrink-0', 2590, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('flex-shrink', CssNum(0))]),
  ]),
  RaftUtility('[&>svg]:size-2.5!', 2581, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(10, 'px'), true),
      RaftDecl('height', CssNum(10, 'px'), true),
    ]),
  ]),
  RaftUtility('[&>svg]:size-3', 2582, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(12, 'px')),
      RaftDecl('height', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-3.5', 2583, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(14, 'px')),
      RaftDecl('height', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-4', 2584, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(16, 'px')),
      RaftDecl('height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-5', 2585, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(20, 'px')),
      RaftDecl('height', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-9', 2586, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(36, 'px')),
      RaftDecl('height', CssNum(36, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-[13px]', 2587, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', CssNum(13, 'px')),
      RaftDecl('height', CssNum(13, 'px')),
    ]),
  ]),
  RaftUtility('[&>svg]:size-control-icon', 2588, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('width', _v110),
      RaftDecl('height', _v110),
    ]),
    RaftLayer(
      '& > svg',
      ['pointer-fine', 'width>=768'],
      1001,
      [
        RaftDecl('width', CssNum(18, 'px')),
        RaftDecl('height', CssNum(18, 'px')),
      ],
    ),
  ]),
  RaftUtility('[&>svg]:stroke-2', 2593, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('stroke-width', CssNum(2))]),
  ]),
  RaftUtility('[&>svg]:text-foreground', 2594, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v0)]),
    RaftLayer('& > svg', ['dark'], 1001, [RaftDecl('color', _v1)]),
  ]),
  RaftUtility(
    '[&>svg]:text-foreground-hint',
    2595,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v44)]),
      RaftLayer('& > svg', ['dark'], 1001, [RaftDecl('color', _v39)]),
    ],
  ),
  RaftUtility(
    '[&>svg]:text-foreground-muted',
    2596,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v2)]),
      RaftLayer('& > svg', ['dark'], 1001, [RaftDecl('color', _v3)]),
    ],
  ),
  RaftUtility('[&>svg]:text-read-mark', 2597, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('color', _v111)]),
    RaftLayer('& > svg', ['dark'], 1001, [RaftDecl('color', _v112)]),
  ]),
  RaftUtility(
    '[&>svg]:top-[calc((1lh-14px)/2)]',
    2571,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [RaftDecl('top', CssCalc(_v107))]),
    ],
  ),
  RaftUtility(
    '[&>svg]:transition-transform',
    2598,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 1001, [
        RaftDecl('transition-property', _v45),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility('[&>svg]:translate-y-0', 2591, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [
      RaftDecl('--tw-translate-y', CssNum(0, 'px')),
      RaftDecl('translate', CssSeq([_v84, _v85])),
    ]),
  ]),
  RaftUtility('[&>svg]:z-raised', 2573, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg', [], 1001, [RaftDecl('z-index', CssNum(1))]),
  ]),
  RaftUtility('[&>svg_*]:stroke-2', 2609, RaftUtilityStatus.descendant, [
    RaftLayer('& > svg *', [], 1001, [RaftDecl('stroke-width', CssNum(2))]),
  ]),
  RaftUtility(
    '[&>tr:last-child>td]:border-b-0',
    2625,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > tr:last-child > td', [], 2002, [
        RaftDecl('border-bottom-style', _v16),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>tr:last-child>th]:border-b-0',
    2626,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > tr:last-child > th', [], 2002, [
        RaftDecl('border-bottom-style', _v16),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&>tr]:active:bg-fill-medium',
    2624,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > tr:active', [], 2001, [
        RaftDecl('background-color', _v104),
      ]),
      RaftLayer(
        '& > tr:active',
        ['dark'],
        2001,
        [RaftDecl('background-color', _v105)],
      ),
    ],
  ),
  RaftUtility(
    '[&>tr]:hover:bg-fill-subtle',
    2623,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > tr:hover', [], 2001, [
        RaftDecl('background-color', _v113),
      ]),
      RaftLayer(
        '& > tr:hover',
        ['dark'],
        2001,
        [RaftDecl('background-color', _v114)],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-ending-style]:not([data-swipe-direction])]:transform-[translateY(120%)_scale(0.98)]',
    2627,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style', 'not:data-swipe-direction'],
        3000,
        [
          RaftDecl('transform', CssSeq([_v115, _v116])),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-has-description]_[data-slot=toast-body]]:self-start',
    2628,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=toast-body]',
        ['data-has-description'],
        3000,
        [RaftDecl('align-self', _v61)],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-has-description]_[data-slot=toast-icon]]:self-start',
    2629,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=toast-icon]',
        ['data-has-description'],
        3000,
        [RaftDecl('align-self', _v61)],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-has-icon][data-has-actions]]:grid-cols-[auto_minmax(0,1fr)_auto]',
    2630,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-has-actions', 'data-has-icon'],
        3000,
        [RaftDecl('grid-template-columns', _v118)],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-panel-open]_[data-slot=sidebar-section-chevron]]:rotate-90',
    2631,
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
    2632,
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
    '[&[data-stacked]>[data-slot=description-item]+[data-slot=description-item]>[data-slot=description-term]]:mt-2',
    2633,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] + [data-slot=description-item] > [data-slot=description-term]',
        ['data-stacked'],
        5000,
        [RaftDecl('margin-top', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-stacked]>[data-slot=description-item]>*]:col-span-full',
    2634,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > *',
        ['data-stacked'],
        3000,
        [RaftDecl('grid-column', _v119)],
      ),
    ],
  ),
  RaftUtility(
    '[&[data-stacked]>[data-slot=description-item]>[data-slot=description-details]]:min-h-0',
    2635,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [data-slot=description-item] > [data-slot=description-details]',
        ['data-stacked'],
        4000,
        [RaftDecl('min-height', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-icon]:not(svg):not([class*=\'size-\'])]:size-4',
    2362,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-icon]:not(svg):not([class*=\'size-\'])', [], 3001, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-icon]:not(svg):not([class*=\'size-\'])]:size-[18px]',
    2363,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-icon]:not(svg):not([class*=\'size-\'])', [], 3001, [
        RaftDecl('width', CssNum(18, 'px')),
        RaftDecl('height', CssNum(18, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-indicator]>svg]:size-3.5',
    2364,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-picker-trigger-indicator] > svg', [], 2001, [
        RaftDecl('width', CssNum(14, 'px')),
        RaftDecl('height', CssNum(14, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-indicator]>svg]:stroke-2',
    2365,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-picker-trigger-indicator] > svg', [], 2001, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-picker-trigger-indicator]>svg_*]:stroke-2',
    2366,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-picker-trigger-indicator] > svg *', [], 2001, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-clear\']]:px-0',
    2367,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'combobox-clear\']', [], 2000, [
        RaftDecl('padding-left', CssNum(0, 'px')),
        RaftDecl('padding-right', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-trigger-indicator\']>svg]:shrink-0',
    2370,
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
    '[&_[data-slot=\'combobox-trigger-indicator\']>svg]:size-4',
    2369,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'combobox-trigger-indicator\'] > svg',
        [],
        2001,
        [
          RaftDecl('width', CssNum(16, 'px')),
          RaftDecl('height', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'combobox-trigger-indicator\']]:size-4',
    2368,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'combobox-trigger-indicator\']', [], 2000, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'select-trigger-content\']_svg:not([class*=\'size-\'])]:size-4',
    2372,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'select-trigger-content\'] svg:not([class*=\'size-\'])',
        [],
        3001,
        [
          RaftDecl('width', CssNum(16, 'px')),
          RaftDecl('height', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'select-trigger-content\']_svg:not([class*=\'stroke-\'])]:stroke-2',
    2373,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=\'select-trigger-content\'] svg:not([class*=\'stroke-\'])',
        [],
        3001,
        [RaftDecl('stroke-width', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'select-trigger-content\']_svg]:shrink-0',
    2371,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'select-trigger-content\'] svg', [], 2001, [
        RaftDecl('flex-shrink', CssNum(0)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=\'spinner\']]:size-3',
    2374,
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
    2375,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=\'spinner\']', [], 2000, [
        RaftDecl('font-size', CssNum(12, 'px')),
        RaftDecl('line-height', _v121),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=announcement-picture]+[data-slot=announcement-text]]:mt-5',
    2376,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=announcement-picture] + [data-slot=announcement-text]',
        [],
        3000,
        [RaftDecl('margin-top', CssNum(20, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=avatar][data-size=md]]:size-(--mi-avatar,35px)',
    2377,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=avatar][data-size=md]', [], 3000, [
        RaftDecl('width', _v122),
        RaftDecl('height', _v122),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=button]]:ease-out',
    2378,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=button]', [], 2000, [
        RaftDecl('--tw-ease', _v123),
        RaftDecl('transition-timing-function', _v123),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=dialog-body]]:content-start',
    2379,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=dialog-body]', [], 2000, [
        RaftDecl('align-content', _v61),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=dialog-body]]:pb-[max(16px,env(safe-area-inset-bottom,0px))]',
    2382,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=dialog-body]', [], 2000, [
        RaftDecl('padding-bottom', _v126),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=dialog-body]]:pt-4',
    2381,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=dialog-body]', [], 2000, [
        RaftDecl('padding-top', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=dialog-body]]:px-4',
    2380,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=dialog-body]', [], 2000, [
        RaftDecl('padding-left', CssNum(16, 'px')),
        RaftDecl('padding-right', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=kbd-group]_[data-slot=kbd]]:ml-0',
    2383,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=kbd-group] [data-slot=kbd]', [], 3000, [
        RaftDecl('margin-left', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=kbd][data-glyph=icon]]:px-0',
    2384,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=kbd][data-glyph=icon]', [], 3000, [
        RaftDecl('padding-left', CssNum(0, 'px')),
        RaftDecl('padding-right', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=message-attachment-action]_svg]:size-4',
    2385,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=message-attachment-action] svg', [], 2001, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=message-reaction-glyph]>svg]:size-4',
    2386,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=message-reaction-glyph] > svg', [], 2001, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:font-bold',
    2392,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('--tw-font-weight', CssNum(700)),
        RaftDecl('font-weight', CssNum(700)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:gap-2',
    2389,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('row-gap', CssNum(8, 'px')),
        RaftDecl('column-gap', CssNum(8, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:mb-0',
    2388,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('margin-bottom', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:mt-3',
    2387,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('margin-top', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:px-5',
    2390,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('padding-left', CssNum(20, 'px')),
        RaftDecl('padding-right', CssNum(20, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:py-0',
    2391,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('padding-top', CssNum(0, 'px')),
        RaftDecl('padding-bottom', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=sidebar-group-label]]:tracking-normal',
    2393,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=sidebar-group-label]', [], 2000, [
        RaftDecl('--tw-tracking', CssNum(0, 'em')),
        RaftDecl('letter-spacing', CssNum(0, 'em')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=task-card-status-label]]:gap-1.5',
    2395,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=task-card-status-label]', [], 2000, [
        RaftDecl('row-gap', CssNum(6, 'px')),
        RaftDecl('column-gap', CssNum(6, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=toast-content][data-behind]]:opacity-0',
    2396,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=toast-content][data-behind]', [], 3000, [
        RaftDecl('opacity', CssNum(0, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_[data-slot=toast-content][data-expanded]]:opacity-100',
    2397,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& [data-slot=toast-content][data-expanded]', [], 3000, [
        RaftDecl('opacity', CssNum(100, '%')),
      ]),
    ],
  ),
  RaftUtility('[&_a]:decoration-[1.5px]', 2399, RaftUtilityStatus.descendant, [
    RaftLayer('& a', [], 1001, [
      RaftDecl('text-decoration-thickness', CssNum(1.5, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&_a]:focus-visible:shadow-focus',
    2403,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& a:focus-visible', [], 2001, [
        RaftDecl('--tw-shadow', _v127),
        RaftDecl('box-shadow', _v27),
      ]),
      RaftLayer(
        '& a:focus-visible',
        ['dark'],
        2001,
        [
          RaftDecl('--tw-shadow', CssList([_v129, _v130])),
        ],
      ),
    ],
  ),
  RaftUtility('[&_a]:hover:underline', 2402, RaftUtilityStatus.descendant, [
    RaftLayer('& a:hover', [], 2001, [
      RaftDecl('text-decoration-line', CssKeyword('underline')),
    ]),
  ]),
  RaftUtility('[&_a]:outline-none', 2401, RaftUtilityStatus.descendant, [
    RaftLayer('& a', [], 1001, [
      RaftDecl('--tw-outline-style', CssKeyword('none')),
      RaftDecl('outline-style', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('[&_a]:rounded-[2px]', 2398, RaftUtilityStatus.descendant, [
    RaftLayer('& a', [], 1001, [
      RaftDecl('border-top-left-radius', CssNum(2, 'px')),
      RaftDecl('border-top-right-radius', CssNum(2, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(2, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility(
    '[&_a]:underline-offset-[3px]',
    2400,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& a', [], 1001, [
        RaftDecl('text-underline-offset', CssNum(3, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&_h1]:font-bold', 2405, RaftUtilityStatus.descendant, [
    RaftLayer('& h1', [], 1001, [
      RaftDecl('--tw-font-weight', CssNum(700)),
      RaftDecl('font-weight', CssNum(700)),
    ]),
  ]),
  RaftUtility('[&_h1]:text-xl', 2404, RaftUtilityStatus.descendant, [
    RaftLayer('& h1', [], 1001, [
      RaftDecl('font-size', CssNum(20, 'px')),
      RaftDecl('line-height', _v131),
    ]),
  ]),
  RaftUtility('[&_h2]:font-bold', 2407, RaftUtilityStatus.descendant, [
    RaftLayer('& h2', [], 1001, [
      RaftDecl('--tw-font-weight', CssNum(700)),
      RaftDecl('font-weight', CssNum(700)),
    ]),
  ]),
  RaftUtility('[&_h2]:text-lg', 2406, RaftUtilityStatus.descendant, [
    RaftLayer('& h2', [], 1001, [
      RaftDecl('font-size', CssNum(18, 'px')),
      RaftDecl('line-height', _v133),
    ]),
  ]),
  RaftUtility('[&_h3]:font-bold', 2409, RaftUtilityStatus.descendant, [
    RaftLayer('& h3', [], 1001, [
      RaftDecl('--tw-font-weight', CssNum(700)),
      RaftDecl('font-weight', CssNum(700)),
    ]),
  ]),
  RaftUtility('[&_h3]:text-base', 2408, RaftUtilityStatus.descendant, [
    RaftLayer('& h3', [], 1001, [
      RaftDecl('font-size', CssNum(16, 'px')),
      RaftDecl('line-height', _v134),
    ]),
  ]),
  RaftUtility('[&_img]:bg-transparent', 2413, RaftUtilityStatus.descendant, [
    RaftLayer('& img', [], 1001, [RaftDecl('background-color', _v15)]),
  ]),
  RaftUtility('[&_img]:block', 2411, RaftUtilityStatus.descendant, [
    RaftLayer('& img', [], 1001, [RaftDecl('display', CssKeyword('block'))]),
  ]),
  RaftUtility('[&_img]:object-contain', 2414, RaftUtilityStatus.descendant, [
    RaftLayer('& img', [], 1001, [
      RaftDecl('object-fit', CssKeyword('contain')),
    ]),
  ]),
  RaftUtility('[&_img]:object-cover', 2415, RaftUtilityStatus.descendant, [
    RaftLayer('& img', [], 1001, [RaftDecl('object-fit', CssKeyword('cover'))]),
  ]),
  RaftUtility(
    '[&_img]:pointer-events-none',
    2410,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& img', [], 1001, [
        RaftDecl('pointer-events', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility('[&_img]:size-full', 2412, RaftUtilityStatus.descendant, [
    RaftLayer('& img', [], 1001, [
      RaftDecl('width', CssNum(100, '%')),
      RaftDecl('height', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility('[&_ol]:list-decimal', 2416, RaftUtilityStatus.descendant, [
    RaftLayer('& ol', [], 1001, [
      RaftDecl('list-style-type', CssKeyword('decimal')),
    ]),
  ]),
  RaftUtility('[&_ol]:pl-5', 2417, RaftUtilityStatus.descendant, [
    RaftLayer('& ol', [], 1001, [RaftDecl('padding-left', CssNum(20, 'px'))]),
  ]),
  RaftUtility('[&_p+p]:mt-3', 2418, RaftUtilityStatus.descendant, [
    RaftLayer('& p + p', [], 1002, [RaftDecl('margin-top', CssNum(12, 'px'))]),
  ]),
  RaftUtility(
    '[&_pre]:focus-visible:keyboard:inset-ring-2',
    2422,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& pre:focus-visible:not(:where(:root[data-input-modality="pointer"] *))',
        [],
        2001,
        [
          RaftDecl('--tw-inset-ring-shadow', _v136),
          RaftDecl('box-shadow', _v27),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&_pre]:focus-visible:keyboard:inset-ring-foreground',
    2423,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& pre:focus-visible:not(:where(:root[data-input-modality="pointer"] *))',
        [],
        2001,
        [RaftDecl('--tw-inset-ring-color', _v0)],
      ),
      RaftLayer(
        '& pre:focus-visible:not(:where(:root[data-input-modality="pointer"] *))',
        ['dark'],
        2001,
        [RaftDecl('--tw-inset-ring-color', _v1)],
      ),
    ],
  ),
  RaftUtility('[&_pre]:max-w-full', 2419, RaftUtilityStatus.descendant, [
    RaftLayer('& pre', [], 1001, [RaftDecl('max-width', CssNum(100, '%'))]),
  ]),
  RaftUtility('[&_pre]:outline-none', 2421, RaftUtilityStatus.descendant, [
    RaftLayer('& pre', [], 1001, [
      RaftDecl('--tw-outline-style', CssKeyword('none')),
      RaftDecl('outline-style', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('[&_pre]:overflow-x-auto', 2420, RaftUtilityStatus.descendant, [
    RaftLayer('& pre', [], 1001, [RaftDecl('overflow-x', CssKeyword('auto'))]),
  ]),
  RaftUtility(
    '[&_pre_span]:text-(--shiki-light,currentColor)',
    2424,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& pre span', [], 1002, [RaftDecl('color', _v137)]),
    ],
  ),
  RaftUtility('[&_strong]:bg-attention', 2432, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [RaftDecl('background-color', _v138)]),
  ]),
  RaftUtility('[&_strong]:font-bold', 2436, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [
      RaftDecl('--tw-font-weight', CssNum(700)),
      RaftDecl('font-weight', CssNum(700)),
    ]),
  ]),
  RaftUtility('[&_strong]:font-mono', 2434, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [RaftDecl('font-family', _v141)]),
  ]),
  RaftUtility('[&_strong]:h-5', 2427, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [RaftDecl('height', CssNum(20, 'px'))]),
  ]),
  RaftUtility('[&_strong]:inline-flex', 2426, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [RaftDecl('display', _v46)]),
  ]),
  RaftUtility(
    '[&_strong]:inset-ring-[1.5px]',
    2439,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& strong', [], 1001, [
        RaftDecl('--tw-inset-ring-shadow', _v142),
        RaftDecl('box-shadow', _v27),
      ]),
    ],
  ),
  RaftUtility(
    '[&_strong]:inset-ring-sticker-ink',
    2441,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& strong', [], 1001, [
        RaftDecl('--tw-inset-ring-color', _v143),
      ]),
    ],
  ),
  RaftUtility('[&_strong]:items-center', 2429, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [
      RaftDecl('align-items', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('[&_strong]:justify-center', 2430, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [
      RaftDecl('justify-content', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('[&_strong]:min-w-5', 2428, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [RaftDecl('min-width', CssNum(20, 'px'))]),
  ]),
  RaftUtility('[&_strong]:px-1.5', 2433, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [
      RaftDecl('padding-left', CssNum(6, 'px')),
      RaftDecl('padding-right', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('[&_strong]:ring-[1.5px]', 2438, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [
      RaftDecl('--tw-ring-shadow', _v145),
      RaftDecl('box-shadow', _v27),
    ]),
  ]),
  RaftUtility(
    '[&_strong]:ring-sticker-edge',
    2440,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& strong', [], 1001, [RaftDecl('--tw-ring-color', _v146)]),
      RaftLayer(
        '& strong',
        ['dark'],
        1001,
        [RaftDecl('--tw-ring-color', _v147)],
      ),
    ],
  ),
  RaftUtility(
    '[&_strong]:rounded-sticker',
    2431,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& strong', [], 1001, [
        RaftDecl('border-top-left-radius', CssNum(4, 'px')),
        RaftDecl('border-top-right-radius', CssNum(4, 'px')),
        RaftDecl('border-bottom-right-radius', CssNum(4, 'px')),
        RaftDecl('border-bottom-left-radius', CssNum(4, 'px')),
      ]),
    ],
  ),
  RaftUtility('[&_strong]:text-mono-meta', 2435, RaftUtilityStatus.descendant, [
    RaftLayer('& strong', [], 1001, [
      RaftDecl('font-size', CssNum(12, 'px')),
      RaftDecl('line-height', _v148),
    ]),
    RaftLayer(
      '& strong',
      ['pointer-fine', 'width>=768'],
      1001,
      [RaftDecl('line-height', _v43)],
    ),
  ]),
  RaftUtility(
    '[&_strong]:text-sticker-ink',
    2437,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& strong', [], 1001, [RaftDecl('color', _v143)]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-3',
    2473,
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
    2474,
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
    2475,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-4.5',
    2476,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(18, 'px')),
        RaftDecl('height', CssNum(18, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-5',
    2477,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(20, 'px')),
        RaftDecl('height', CssNum(20, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-[11px]',
    2478,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(11, 'px')),
        RaftDecl('height', CssNum(11, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-[18px]',
    2479,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(18, 'px')),
        RaftDecl('height', CssNum(18, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-[22px]',
    2480,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', CssNum(22, 'px')),
        RaftDecl('height', CssNum(22, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'size-\'])]:size-control-icon',
    2481,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'size-\'])', [], 2001, [
        RaftDecl('width', _v110),
        RaftDecl('height', _v110),
      ]),
      RaftLayer(
        '& svg:not([class*=\'size-\'])',
        ['pointer-fine', 'width>=768'],
        2001,
        [
          RaftDecl('width', CssNum(18, 'px')),
          RaftDecl('height', CssNum(18, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[&_svg:not([class*=\'stroke-\'])]:stroke-2',
    2482,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([class*=\'stroke-\'])', [], 2001, [
        RaftDecl('stroke-width', CssNum(2)),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg:not([data-slot=task-status-icon])]:-mx-0.5',
    2483,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg:not([data-slot=task-status-icon])', [], 2001, [
        RaftDecl('margin-left', CssNum(-2, 'px')),
        RaftDecl('margin-right', CssNum(-2, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg[data-slot=task-status-icon]]:size-2.5',
    2484,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg[data-slot=task-status-icon]', [], 2001, [
        RaftDecl('width', CssNum(10, 'px')),
        RaftDecl('height', CssNum(10, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[&_svg]:[vector-effect:non-scaling-stroke]',
    2466,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [RaftDecl('vector-effect', _v149)]),
    ],
  ),
  RaftUtility('[&_svg]:lead-icon', 2458, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('flex-shrink', CssNum(0)),
      RaftDecl('align-self', CssKeyword('start')),
      RaftDecl('translate', _v60),
    ]),
  ]),
  RaftUtility(
    '[&_svg]:pointer-events-none',
    2442,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [
        RaftDecl('pointer-events', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility('[&_svg]:self-center', 2461, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('align-self', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('[&_svg]:shrink-0', 2459, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('flex-shrink', CssNum(0))]),
  ]),
  RaftUtility('[&_svg]:size-2.5', 2443, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(10, 'px')),
      RaftDecl('height', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-3', 2444, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(12, 'px')),
      RaftDecl('height', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-3.5', 2445, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(14, 'px')),
      RaftDecl('height', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-4', 2446, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(16, 'px')),
      RaftDecl('height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-4.5', 2447, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(18, 'px')),
      RaftDecl('height', CssNum(18, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-5', 2448, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(20, 'px')),
      RaftDecl('height', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-5.5', 2449, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(22, 'px')),
      RaftDecl('height', CssNum(22, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-6', 2450, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(24, 'px')),
      RaftDecl('height', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-9', 2451, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(36, 'px')),
      RaftDecl('height', CssNum(36, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-[0.857em]', 2452, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(0.857, 'em')),
      RaftDecl('height', CssNum(0.857, 'em')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-[10px]', 2453, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(10, 'px')),
      RaftDecl('height', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-[11px]', 2454, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(11, 'px')),
      RaftDecl('height', CssNum(11, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-[13px]', 2455, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(13, 'px')),
      RaftDecl('height', CssNum(13, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-[18px]', 2456, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(18, 'px')),
      RaftDecl('height', CssNum(18, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:size-[22px]', 2457, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('width', CssNum(22, 'px')),
      RaftDecl('height', CssNum(22, 'px')),
    ]),
  ]),
  RaftUtility('[&_svg]:stroke-2', 2462, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('stroke-width', CssNum(2))]),
  ]),
  RaftUtility('[&_svg]:text-foreground', 2463, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [RaftDecl('color', _v0)]),
    RaftLayer('& svg', ['dark'], 1001, [RaftDecl('color', _v1)]),
  ]),
  RaftUtility(
    '[&_svg]:text-foreground-muted',
    2464,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [RaftDecl('color', _v2)]),
      RaftLayer('& svg', ['dark'], 1001, [RaftDecl('color', _v3)]),
    ],
  ),
  RaftUtility(
    '[&_svg]:transition-transform',
    2465,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg', [], 1001, [
        RaftDecl('transition-property', _v45),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility('[&_svg]:translate-y-0', 2460, RaftUtilityStatus.descendant, [
    RaftLayer('& svg', [], 1001, [
      RaftDecl('--tw-translate-y', CssNum(0, 'px')),
      RaftDecl('translate', CssSeq([_v84, _v85])),
    ]),
  ]),
  RaftUtility(
    '[&_svg_*]:[vector-effect:non-scaling-stroke]',
    2472,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& svg *', [], 1001, [RaftDecl('vector-effect', _v149)]),
    ],
  ),
  RaftUtility('[&_svg_*]:stroke-2', 2471, RaftUtilityStatus.descendant, [
    RaftLayer('& svg *', [], 1001, [RaftDecl('stroke-width', CssNum(2))]),
  ]),
  RaftUtility('[&_ul]:list-disc', 2485, RaftUtilityStatus.descendant, [
    RaftLayer('& ul', [], 1001, [
      RaftDecl('list-style-type', CssKeyword('disc')),
    ]),
  ]),
  RaftUtility('[&_ul]:pl-5', 2486, RaftUtilityStatus.descendant, [
    RaftLayer('& ul', [], 1001, [RaftDecl('padding-left', CssNum(20, 'px'))]),
  ]),
  RaftUtility(
    '[&~[data-slot=input-group-control]]:pl-0',
    2636,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& ~ [data-slot=input-group-control]', [], 2000, [
        RaftDecl('padding-left', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--banner-button:--spacing(8)]',
    981,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--banner-button', CssNum(32, 'px')),
      ]),
    ],
  ),
  RaftUtility('[--ca-overlay-border:1px]', 982, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--ca-overlay-border', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility(
    '[--cell-inset-end:max(0px,calc(var(--cell-inset-x)-var(--scrollbar-size,0px)))]',
    983,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--cell-inset-end', _v153)]),
    ],
  ),
  RaftUtility('[--cell-inset-x:8px]', 984, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--cell-inset-x', CssNum(8, 'px'))]),
  ]),
  RaftUtility('[--cell-pad-x:12px]', 985, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--cell-pad-x', CssNum(12, 'px'))]),
  ]),
  RaftUtility(
    '[--cell-radius:var(--radius-control)]',
    986,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--cell-radius', CssNum(8, 'px'))]),
    ],
  ),
  RaftUtility(
    '[--closed-transform:translate3d(var(--drawer-exit-x,0px),var(--drawer-exit-y,0px),0)]',
    987,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--closed-transform', _v156)]),
    ],
  ),
  RaftUtility(
    '[--code-block-header-height:--spacing(10)]',
    988,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--code-block-header-height', CssNum(40, 'px')),
      ]),
    ],
  ),
  RaftUtility('[--column-margin:20px]', 989, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--column-margin', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility(
    '[--control-embedded-size:calc(2rem-2*var(--control-embedded-inset))]',
    990,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--control-embedded-size', CssCalc(_v158)),
      ]),
    ],
  ),
  RaftUtility('[--drawer-blur:2px]', 991, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--drawer-blur', CssNum(2, 'px'))]),
  ]),
  RaftUtility(
    '[--drawer-content-height:100dvh]',
    992,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-content-height', CssNum(100, 'dvh')),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-content-height:var(--drawer-height,auto)]',
    993,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-content-height', _v159)]),
    ],
  ),
  RaftUtility(
    '[--drawer-ease:var(--ease-slide)]',
    994,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-ease', _v160)]),
    ],
  ),
  RaftUtility(
    '[--drawer-exit-x:calc(-100%-var(--drawer-inset)-2px)]',
    995,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-exit-x', CssCalc(_v163)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-exit-x:calc(100%+var(--drawer-inset)+2px)]',
    996,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-exit-x', CssCalc(_v165)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-exit-y:calc(-100%-var(--drawer-inset)-2px)]',
    997,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-exit-y', CssCalc(_v163)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-exit-y:calc(100%+var(--drawer-inset)+2px)]',
    998,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-exit-y', CssCalc(_v165)),
      ]),
    ],
  ),
  RaftUtility('[--drawer-inset:0px]', 999, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--drawer-inset', CssNum(0, 'px'))]),
  ]),
  RaftUtility('[--drawer-inset:12px]', 1000, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--drawer-inset', CssNum(12, 'px'))]),
  ]),
  RaftUtility(
    '[--drawer-overlay-min-opacity:0.5]',
    1001,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-overlay-min-opacity', CssNum(0.5)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-offset:max(0px,calc((var(--nested-drawers)-var(--drawer-stack-progress))*var(--drawer-stack-peek)))]',
    1002,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-stack-offset', _v171)]),
    ],
  ),
  RaftUtility('[--drawer-stack-peek:16px]', 1003, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--drawer-stack-peek', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility(
    '[--drawer-stack-progress:clamp(0,var(--drawer-swipe-progress),1)]',
    1004,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-stack-progress', _v173)]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-scale-base:calc(max(0,1-(var(--nested-drawers)*var(--drawer-stack-step))))]',
    1005,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-scale-base', CssCalc(_v177)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-scale:clamp(0,calc(var(--drawer-stack-scale-base)+(var(--drawer-stack-step)*var(--drawer-stack-progress))),1)]',
    1006,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-stack-scale', _v181)]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-shrink-offset:calc(var(--drawer-stack-shrink)*var(--drawer-stack-size))]',
    1007,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-shrink-offset', CssCalc(_v184)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-shrink:calc(1-var(--drawer-stack-scale))]',
    1008,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-shrink', CssCalc(_v186)),
      ]),
    ],
  ),
  RaftUtility('[--drawer-stack-size:100%]', 1009, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--drawer-stack-size', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility(
    '[--drawer-stack-size:max(0px,var(--drawer-frontmost-height,var(--drawer-height)))]',
    1010,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-stack-size', _v189)]),
    ],
  ),
  RaftUtility('[--drawer-stack-step:0.05]', 1011, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--drawer-stack-step', CssNum(0.05)),
    ]),
  ]),
  RaftUtility(
    '[--drawer-stack-x:calc(0px-var(--drawer-stack-offset)-var(--drawer-stack-shrink-offset))]',
    1012,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-x', CssCalc(_v193)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-x:calc(var(--drawer-stack-offset)+var(--drawer-stack-shrink-offset))]',
    1013,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-x', CssCalc(_v194)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-y:calc(0px-var(--drawer-stack-offset)-var(--drawer-stack-shrink-offset))]',
    1014,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-y', CssCalc(_v193)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-stack-y:calc(var(--drawer-stack-offset)+var(--drawer-stack-shrink-offset))]',
    1015,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-stack-y', CssCalc(_v194)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-swipe-x:var(--drawer-swipe-movement-x)]',
    1016,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--drawer-swipe-x', _v195)]),
    ],
  ),
  RaftUtility(
    '[--drawer-swipe-y:calc(var(--drawer-snap-point-offset,0px)+var(--drawer-swipe-movement-y))]',
    1017,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-swipe-y', CssCalc(_v198)),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-transform-origin:0%_50%]',
    1018,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-transform-origin', _v199),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-transform-origin:100%_50%]',
    1021,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-transform-origin', _v200),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-transform-origin:50%_0%]',
    1019,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-transform-origin', _v201),
      ]),
    ],
  ),
  RaftUtility(
    '[--drawer-transform-origin:50%_100%]',
    1020,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--drawer-transform-origin', _v202),
      ]),
    ],
  ),
  RaftUtility(
    '[--icon-inset:calc((--spacing(6)-14px)/2)]',
    1022,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--icon-inset', CssNum(5, 'px'))]),
    ],
  ),
  RaftUtility(
    '[--icon-inset:calc((--spacing(8)-18px)/2)]',
    1023,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--icon-inset', CssNum(7, 'px'))]),
    ],
  ),
  RaftUtility(
    '[--icon-inset:calc((var(--bar-button-size)-var(--control-icon-size))/2)]',
    1024,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--icon-inset', CssCalc(_v205))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--icon-inset', CssNum(5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[--icon-inset:calc((var(--control-height)-var(--control-icon-size))/2)]',
    1025,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--icon-inset', CssCalc(_v208))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--icon-inset', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[--icon-inset:calc((var(--frame-item-height)-20px)/2)]',
    1026,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--icon-inset', CssCalc(_v211))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--icon-inset', CssNum(7, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[--ig-addon-fg-default:var(--foreground-hint)]',
    1027,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--ig-addon-fg-default', _v44)]),
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--ig-addon-fg-default', _v39)],
      ),
    ],
  ),
  RaftUtility(
    '[--ig-hit:calc(--spacing(1.5)+1.5px)]',
    1028,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--ig-hit', CssNum(7.5, 'px'))]),
    ],
  ),
  RaftUtility(
    '[--ig-text-fg-default:var(--foreground-hint)]',
    1029,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--ig-text-fg-default', _v44)]),
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('--ig-text-fg-default', _v39)],
      ),
    ],
  ),
  RaftUtility(
    '[--inbox-item-skeleton-body:80%]',
    1030,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--inbox-item-skeleton-body', CssNum(80, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '[--inbox-item-skeleton-context:5rem]',
    1031,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--inbox-item-skeleton-context', CssNum(80, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--inbox-item-skeleton-title:60%]',
    1032,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--inbox-item-skeleton-title', CssNum(60, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '[--list-row-ink-2:var(--foreground-muted)]',
    1033,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--list-row-ink-2', _v2)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--list-row-ink-2', _v3)]),
    ],
  ),
  RaftUtility(
    '[--list-row-ink-3:var(--foreground-hint)]',
    1034,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--list-row-ink-3', _v44)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--list-row-ink-3', _v39)]),
    ],
  ),
  RaftUtility(
    '[--list-row-ink:var(--foreground)]',
    1035,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--list-row-ink', _v0)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--list-row-ink', _v1)]),
    ],
  ),
  RaftUtility(
    '[--list-row-risk-ink:initial]',
    1036,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--list-row-risk-ink', CssKeyword('initial')),
      ]),
    ],
  ),
  RaftUtility(
    '[--list-row-rule-start:16px]',
    1037,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--list-row-rule-start', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--list-row-rule-start:63px]',
    1038,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--list-row-rule-start', CssNum(63, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--list-row-skeleton-description:75%]',
    1039,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--list-row-skeleton-description', CssNum(75, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '[--list-row-skeleton-title:45%]',
    1040,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--list-row-skeleton-title', CssNum(45, '%')),
      ]),
    ],
  ),
  RaftUtility(
    '[--message-reference-em:1em]',
    1041,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--message-reference-em', CssNum(1, 'em')),
      ]),
    ],
  ),
  RaftUtility(
    '[--meter-indicator:var(--info)]',
    1042,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--meter-indicator', _v212)]),
    ],
  ),
  RaftUtility(
    '[--meter-indicator:var(--warning)]',
    1043,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--meter-indicator', _v213)]),
    ],
  ),
  RaftUtility(
    '[--meter-value:var(--foreground-muted)]',
    1044,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--meter-value', _v2)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--meter-value', _v3)]),
    ],
  ),
  RaftUtility(
    '[--meter-value:var(--warning-strong)]',
    1045,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--meter-value', _v214)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--meter-value', _v215)]),
    ],
  ),
  RaftUtility(
    '[--mi-row-fill:var(--located-fill)]',
    1046,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--mi-row-fill', _v216)]),
    ],
  ),
  RaftUtility(
    '[--panel-footer-clearance:0rem]',
    1047,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--panel-footer-clearance', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--panel-footer-clearance:10rem]',
    1048,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--panel-footer-clearance', CssNum(160, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--danger)]',
    1049,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v217)]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--foreground)]',
    1050,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v0)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--progress-color', _v1)]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--info)]',
    1051,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v212)]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--success)]',
    1052,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v218)]),
    ],
  ),
  RaftUtility(
    '[--progress-color:var(--warning)]',
    1053,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-color', _v213)]),
    ],
  ),
  RaftUtility(
    '[--progress-indicator:var(--progress-color)]',
    1054,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-indicator', _v219)]),
    ],
  ),
  RaftUtility(
    '[--progress-track:var(--fill-muted)]',
    1055,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--progress-track', _v220)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--progress-track', _v221)]),
    ],
  ),
  RaftUtility(
    '[--r-scroll-area-resize-grip-size:0px]',
    1056,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--r-scroll-area-resize-grip-size', CssNum(0, 'px')),
      ]),
    ],
  ),
  RaftUtility('[--segment-size:2rem]', 1057, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--segment-size', CssNum(32, 'px'))]),
  ]),
  RaftUtility(
    '[--shell-header-height:var(--header-height)]',
    1058,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--shell-header-height', _v222)]),
    ],
  ),
  RaftUtility('[--spinner-gap:1.5px]', 1059, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--spinner-gap', CssNum(1.5, 'px'))]),
  ]),
  RaftUtility('[--spinner-gap:2px]', 1060, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--spinner-gap', CssNum(2, 'px'))]),
  ]),
  RaftUtility('[--spinner-gap:3px]', 1061, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--spinner-gap', CssNum(3, 'px'))]),
  ]),
  RaftUtility('[--spinner-pixel:4px]', 1062, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--spinner-pixel', CssNum(4, 'px'))]),
  ]),
  RaftUtility('[--spinner-pixel:5px]', 1063, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--spinner-pixel', CssNum(5, 'px'))]),
  ]),
  RaftUtility('[--spinner-pixel:6px]', 1064, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--spinner-pixel', CssNum(6, 'px'))]),
  ]),
  RaftUtility('[--spinner-pixel:8px]', 1065, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--spinner-pixel', CssNum(8, 'px'))]),
  ]),
  RaftUtility(
    '[--status-color:var(--attention-400)]',
    1066,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v138)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--danger)]',
    1067,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v217)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--info)]',
    1068,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v212)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--palette-stone-400)]',
    1069,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v223)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--presence-busy)]',
    1070,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v224)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--presence-offline)]',
    1071,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v225)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--success)]',
    1072,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v218)]),
    ],
  ),
  RaftUtility(
    '[--status-color:var(--warning)]',
    1073,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--status-color', _v213)]),
    ],
  ),
  RaftUtility('[--toast-gap:0.5rem]', 1074, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--toast-gap', CssNum(8, 'px'))]),
  ]),
  RaftUtility('[--toast-peek-dir:-1]', 1075, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--toast-peek-dir', CssNum(-1))]),
  ]),
  RaftUtility('[--toast-peek:0.5rem]', 1076, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--toast-peek', CssNum(8, 'px'))]),
  ]),
  RaftUtility(
    '[--toast-scale:calc(max(0.84,1-(var(--toast-index)*0.04)))]',
    1077,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--toast-scale', CssCalc(_v228))]),
    ],
  ),
  RaftUtility(
    '[--toast-stack-height:var(--toast-frontmost-height,var(--toast-height))]',
    1078,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--toast-stack-height', _v230)]),
    ],
  ),
  RaftUtility(
    '[--toast-title-only-min-h:2.75rem]',
    1079,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--toast-title-only-min-h', CssNum(44, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--toast-title-only-px:1rem]',
    1080,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--toast-title-only-px', CssNum(16, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--toast-title-only-py:0.75rem]',
    1081,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--toast-title-only-py', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[--toast-y:calc((var(--toast-offset-y)*-1)-(var(--toast-index)*var(--toast-gap))+var(--toast-swipe-movement-y))]',
    1082,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('--toast-y', CssCalc(_v236))]),
    ],
  ),
  RaftUtility(
    '[-webkit-overflow-scrolling:touch]',
    1083,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('-webkit-overflow-scrolling', CssKeyword('touch')),
      ]),
    ],
  ),
  RaftUtility(
    '[-webkit-touch-callout:none]',
    1084,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('-webkit-touch-callout', CssKeyword('none')),
      ]),
    ],
  ),
  RaftUtility(
    '[@media(hover:hover)]:has-[[data-slot=file-row-open]:hover]:overlay-subtle',
    2637,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=file-row-open+hover'],
        3000,
        [RaftDecl('background-image', _v237)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=file-row-open+hover'],
        3000,
        [RaftDecl('background-image', _v238)],
      ),
    ],
  ),
  RaftUtility(
    '[@media(hover:none)]:opacity-100',
    2639,
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
  RaftUtility('[@media(hover:none)]:size-5', 2638, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover-none'],
      1000,
      [
        RaftDecl('width', CssNum(20, 'px')),
        RaftDecl('height', CssNum(20, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    '[@media(max-height:600px)]:[--shell-header-height:var(--header-height-short)]',
    2648,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600'],
        1000,
        [RaftDecl('--shell-header-height', _v239)],
      ),
      RaftLayer(
        'self',
        ['height<=600', 'pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--shell-header-height', CssCalc(_v242))],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:first:pt-1.5',
    2649,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['first-child', 'height<=600'],
        2000,
        [RaftDecl('padding-top', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:h-(--header-height-short)',
    2641,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['height<=600'], 1000, [RaftDecl('height', _v239)]),
      RaftLayer(
        'self',
        ['height<=600', 'pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('height', CssCalc(_v242))],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:min-h-8',
    2642,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600'],
        1000,
        [RaftDecl('min-height', CssNum(32, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:pb-1.5',
    2647,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600'],
        1000,
        [RaftDecl('padding-bottom', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:ps-[calc(var(--raft-frame-inset-start,0px)+(var(--rail-width-short)-1px-var(--rail-item-short))/2)]',
    2645,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600'],
        1000,
        [RaftDecl('padding-left', CssCalc(_v249))],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:pt-1.5',
    2646,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600'],
        1000,
        [RaftDecl('padding-top', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:py-1',
    2644,
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
    '[@media(max-height:600px)]:size-(--rail-item-short)',
    2640,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600'],
        1000,
        [RaftDecl('width', _v246), RaftDecl('height', _v246)],
      ),
    ],
  ),
  RaftUtility(
    '[@media(max-height:600px)]:w-(--rail-width-short)',
    2643,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['height<=600'], 1000, [RaftDecl('width', _v244)]),
    ],
  ),
  RaftUtility(
    '[[data-size=\'2xs\']>&]:[&>svg]:size-3',
    2653,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 2001, [
        RaftDecl('width', CssNum(12, 'px')),
        RaftDecl('height', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[[data-size=\'2xs\']>&]:text-[11px]',
    2652,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-size=2xs'],
        2000,
        [RaftDecl('font-size', CssNum(11, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-size=\'3xs\']>&]:[&>svg]:size-2',
    2655,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 2001, [
        RaftDecl('width', CssNum(8, 'px')),
        RaftDecl('height', CssNum(8, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[[data-size=\'3xs\']>&]:text-[8px]',
    2654,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-size=3xs'],
        2000,
        [RaftDecl('font-size', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-size=\'lg\']>&]:[&>svg]:size-6',
    2657,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 2001, [
        RaftDecl('width', CssNum(24, 'px')),
        RaftDecl('height', CssNum(24, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[[data-size=\'lg\']>&]:text-[22px]',
    2656,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-size=lg'],
        2000,
        [RaftDecl('font-size', CssNum(22, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-size=\'md\']>&]:[&>svg]:size-4.5',
    2658,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 2001, [
        RaftDecl('width', CssNum(18, 'px')),
        RaftDecl('height', CssNum(18, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[[data-size=\'sm\']>&]:[&>svg]:size-3.5',
    2660,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 2001, [
        RaftDecl('width', CssNum(14, 'px')),
        RaftDecl('height', CssNum(14, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[[data-size=\'sm\']>&]:text-[13px]',
    2659,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-size=sm'],
        2000,
        [RaftDecl('font-size', CssNum(13, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-size=\'xl\']>&]:[&>svg]:size-12',
    2662,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 2001, [
        RaftDecl('width', CssNum(48, 'px')),
        RaftDecl('height', CssNum(48, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[[data-size=\'xl\']>&]:text-[40px]',
    2661,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-size=xl'],
        2000,
        [RaftDecl('font-size', CssNum(40, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-size=\'xs\']>&]:[&>svg]:size-3',
    2664,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', [], 2001, [
        RaftDecl('width', CssNum(12, 'px')),
        RaftDecl('height', CssNum(12, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    '[[data-size=\'xs\']>&]:text-[11px]',
    2663,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-size=xs'],
        2000,
        [RaftDecl('font-size', CssNum(11, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=alert-dialog-header]+&]:pt-(--surface-inset)',
    2665,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=alert-dialog-header'],
        2000,
        [RaftDecl('padding-top', CssNum(20, 'px'))],
      ),
      RaftLayer(
        'self',
        [
          'ancestor:data-slot=alert-dialog-header',
          'pointer-fine',
          'width>=768',
        ],
        2000,
        [RaftDecl('padding-top', CssNum(16, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=code-block-body]>&]:col-start-2',
    2667,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=code-block-body'],
        2000,
        [RaftDecl('grid-column-start', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=code-block-body]>&]:ml-3',
    2671,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=code-block-body'],
        2000,
        [RaftDecl('margin-left', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=code-block-body]>&]:mr-[calc(var(--control-embedded-inset)-0.75rem-1px)]',
    2670,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=code-block-body'],
        2000,
        [RaftDecl('margin-right', CssCalc(_v100))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=code-block-body]>&]:my-[calc(var(--control-embedded-inset)-0.5rem-1px)]',
    2669,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=code-block-body'],
        2000,
        [
          RaftDecl('margin-top', CssCalc(_v251)),
          RaftDecl('margin-bottom', CssCalc(_v251)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=code-block-body]>&]:row-start-1',
    2668,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=code-block-body'],
        2000,
        [RaftDecl('grid-row-start', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=code-block-body]>&]:z-raised',
    2666,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=code-block-body'],
        2000,
        [RaftDecl('z-index', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=comment-entry]+&]:mt-1',
    2672,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=comment-entry'],
        2000,
        [RaftDecl('margin-top', CssNum(4, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=dialog-header]+&]:pt-(--surface-inset)',
    2673,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=dialog-header'],
        2000,
        [RaftDecl('padding-top', CssNum(20, 'px'))],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-slot=dialog-header', 'pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('padding-top', CssNum(16, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=dialog-header]+&]:pt-3',
    2674,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=dialog-header'],
        2000,
        [RaftDecl('padding-top', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=field]>&]:-mt-0.5',
    2675,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=field'],
        2000,
        [RaftDecl('margin-top', CssNum(-2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=form-section]+&]:border-line-hairline',
    2677,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=form-section'],
        2000,
        [
          RaftDecl('border-top-color', _v252),
          RaftDecl('border-right-color', _v252),
          RaftDecl('border-bottom-color', _v252),
          RaftDecl('border-left-color', _v252),
        ],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-slot=form-section', 'dark'],
        2000,
        [
          RaftDecl('border-top-color', _v253),
          RaftDecl('border-right-color', _v253),
          RaftDecl('border-bottom-color', _v253),
          RaftDecl('border-left-color', _v253),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=form-section]+&]:border-t',
    2676,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=form-section'],
        2000,
        [
          RaftDecl('border-top-style', _v16),
          RaftDecl('border-top-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=list-row-body]>&]:mt-0.5',
    2678,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=list-row-body'],
        2000,
        [RaftDecl('margin-top', CssNum(2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=list-row]+&]:before:block',
    2679,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['ancestor:data-slot=list-row'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('display', CssKeyword('block')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=list-row][data-interactive]:not([data-attached])+&]:before:block',
    2681,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['ancestor:data-slot=list-row+data-interactive+not:data-attached'],
        4001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('display', CssKeyword('block')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=list-row][data-interactive]:not([data-attached])+&]:pt-(--settings-row-inset)',
    2680,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=list-row+data-interactive+not:data-attached'],
        4000,
        [RaftDecl('padding-top', _v254)],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=message-action-card-hint-label]+&]:-mt-1',
    2682,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=message-action-card-hint-label'],
        2000,
        [RaftDecl('margin-top', CssNum(-4, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-slot=select-item-leading]~&]:ps-[calc(--spacing(4)+(--spacing(2.5)))]',
    2683,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=select-item-leading'],
        2000,
        [RaftDecl('padding-left', CssNum(26, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-split-action-main][aria-pressed=true]~&]:[--split-action-menu-tint:var(--fill-subtle)]',
    2684,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-split-action-main+aria-pressed=true'],
        3000,
        [RaftDecl('--split-action-menu-tint', _v113)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-split-action-main+aria-pressed=true', 'dark'],
        3000,
        [RaftDecl('--split-action-menu-tint', _v114)],
      ),
    ],
  ),
  RaftUtility(
    '[[data-split-action-main][data-pressed]~&]:[--split-action-menu-tint:var(--fill-subtle)]',
    2685,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-split-action-main+data-pressed'],
        3000,
        [RaftDecl('--split-action-menu-tint', _v113)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-split-action-main+data-pressed', 'dark'],
        3000,
        [RaftDecl('--split-action-menu-tint', _v114)],
      ),
    ],
  ),
  RaftUtility(
    '[[data-stacked]>[data-slot=message-action-card-property]+[data-slot=message-action-card-property]>&]:mt-2',
    2686,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'ancestor:data-slot=message-action-card-property',
          'ancestor:data-stacked',
        ],
        4000,
        [RaftDecl('margin-top', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-stacked]>[data-slot=message-action-card-property]>&]:min-h-0',
    2687,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'ancestor:data-slot=message-action-card-property',
          'ancestor:data-stacked',
        ],
        3000,
        [RaftDecl('min-height', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[[data-stacked]>[data-slot=message-action-card-property]>&]:py-0',
    2688,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'ancestor:data-slot=message-action-card-property',
          'ancestor:data-stacked',
        ],
        3000,
        [
          RaftDecl('padding-top', CssNum(0, 'px')),
          RaftDecl('padding-bottom', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[[data-toast-placement^=top]_&[data-ending-style]:not([data-swipe-direction])]:transform-[translateY(-120%)_scale(0.98)]',
    2689,
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
          RaftDecl('transform', CssSeq([_v255, _v116])),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[[data-toast-placement^=top]_&[data-starting-style]]:transform-[translateY(-120%)_scale(0.98)]',
    2690,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-toast-placement^=top', 'data-starting-style'],
        3000,
        [
          RaftDecl('transform', CssSeq([_v255, _v116])),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[[data-type=\'server\']>&]:text-brand',
    2691,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-type=server'],
        2000,
        [RaftDecl('color', _v256)],
      ),
    ],
  ),
  RaftUtility(
    '[a,button]:active:overlay-medium',
    2494,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'is(a, button)'],
        2001,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['active', 'dark', 'is(a, button)'],
        2001,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility('[a,button]:cursor-pointer', 2492, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['is(a, button)'],
      1001,
      [RaftDecl('cursor', CssKeyword('pointer'))],
    ),
  ]),
  RaftUtility(
    '[a,button]:hover:overlay-medium',
    2493,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'is(a, button)'],
        2001,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['dark', 'hover', 'is(a, button)'],
        2001,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    '[border-width:var(--ca-overlay-border,2px)]',
    546,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-width', _v259),
        RaftDecl('border-right-width', _v259),
        RaftDecl('border-bottom-width', _v259),
        RaftDecl('border-left-width', _v259),
      ]),
    ],
  ),
  RaftUtility('[button&]:bg-transparent', 2695, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['button'], 1001, [RaftDecl('background-color', _v15)]),
  ]),
  RaftUtility('[button&]:border-0', 2694, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['button'],
      1001,
      [
        RaftDecl('border-top-style', _v16),
        RaftDecl('border-right-style', _v16),
        RaftDecl('border-bottom-style', _v16),
        RaftDecl('border-left-style', _v16),
        RaftDecl('border-top-width', CssNum(0, 'px')),
        RaftDecl('border-right-width', CssNum(0, 'px')),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
        RaftDecl('border-left-width', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('[button&]:cursor-pointer', 2692, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['button'],
      1001,
      [RaftDecl('cursor', CssKeyword('pointer'))],
    ),
  ]),
  RaftUtility(
    '[button&]:decoration-[1.5px]',
    2698,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['button'],
        1001,
        [RaftDecl('text-decoration-thickness', CssNum(1.5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[button&]:enabled:active:overlay-medium',
    2705,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'button', 'enabled'],
        3001,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['active', 'button', 'dark', 'enabled'],
        3001,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    '[button&]:enabled:cursor-pointer',
    2702,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['button', 'enabled'],
        2001,
        [RaftDecl('cursor', CssKeyword('pointer'))],
      ),
    ],
  ),
  RaftUtility(
    '[button&]:enabled:hover:overlay-medium',
    2703,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['button', 'enabled', 'hover'],
        3001,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['button', 'dark', 'enabled', 'hover'],
        3001,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    '[button&]:enabled:hover:underline',
    2704,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['button', 'enabled', 'hover'],
        3001,
        [RaftDecl('text-decoration-line', CssKeyword('underline'))],
      ),
    ],
  ),
  RaftUtility(
    '[button&]:focus-visible:shadow-focus',
    2701,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['button', 'focus-visible'],
        2001,
        [RaftDecl('--tw-shadow', _v127), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        ['button', 'dark', 'focus-visible'],
        2001,
        [
          RaftDecl('--tw-shadow', CssList([_v129, _v130])),
        ],
      ),
    ],
  ),
  RaftUtility('[button&]:outline-none', 2700, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['button'],
      1001,
      [
        RaftDecl('--tw-outline-style', CssKeyword('none')),
        RaftDecl('outline-style', CssKeyword('none')),
      ],
    ),
  ]),
  RaftUtility('[button&]:p-0', 2696, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['button'],
      1001,
      [
        RaftDecl('padding-top', CssNum(0, 'px')),
        RaftDecl('padding-right', CssNum(0, 'px')),
        RaftDecl('padding-bottom', CssNum(0, 'px')),
        RaftDecl('padding-left', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('[button&]:rounded-chip', 2693, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['button'],
      1001,
      [
        RaftDecl('border-top-left-radius', CssNum(6, 'px')),
        RaftDecl('border-top-right-radius', CssNum(6, 'px')),
        RaftDecl('border-bottom-right-radius', CssNum(6, 'px')),
        RaftDecl('border-bottom-left-radius', CssNum(6, 'px')),
      ],
    ),
  ]),
  RaftUtility('[button&]:text-start', 2697, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['button'],
      1001,
      [RaftDecl('text-align', CssKeyword('start'))],
    ),
  ]),
  RaftUtility(
    '[button&]:underline-offset-[3px]',
    2699,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['button'],
        1001,
        [RaftDecl('text-underline-offset', CssNum(3, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    '[contain-intrinsic-block-size:auto_1lh]',
    1085,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('contain-intrinsic-block-size', _v260),
      ]),
    ],
  ),
  RaftUtility(
    '[display:var(--inbox-item-content-display,block)]',
    164,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('display', _v261)]),
    ],
  ),
  RaftUtility(
    '[display:var(--inbox-item-time-display,none)]',
    165,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('display', _v262)]),
    ],
  ),
  RaftUtility('[font-size:0.875em]', 807, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(0.875, 'em'))]),
  ]),
  RaftUtility('[font-size:inherit]', 808, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssKeyword('inherit'))]),
  ]),
  RaftUtility('[font:inherit]', 1086, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font', CssKeyword('inherit'))]),
  ]),
  RaftUtility(
    '[label>&]:after:-inset-y-[calc(max(0px,(1lh-1.25rem)/2)+4px)]',
    2707,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['ancestor:label'],
        1002,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssCalc(_v265)),
          RaftDecl('bottom', CssCalc(_v265)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[label>&]:after:-inset-y-[calc(max(0px,(1lh-1.25rem)/2)+5.5px)]',
    2708,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['ancestor:label'],
        1002,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssCalc(_v267)),
          RaftDecl('bottom', CssCalc(_v267)),
        ],
      ),
    ],
  ),
  RaftUtility(
    '[label>&]:my-[max(0px,calc((1lh-1.25rem)/2))]',
    2706,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:label'],
        1001,
        [RaftDecl('margin-top', _v263), RaftDecl('margin-bottom', _v263)],
      ),
    ],
  ),
  RaftUtility('[li+li>&]:before:block', 2709, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['ancestor:li'],
      1003,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('display', CssKeyword('block')),
      ],
    ),
  ]),
  RaftUtility('[overflow-anchor:auto]', 1087, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-anchor', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('[overflow-clip-margin:2px]', 1088, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-clip-margin', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility(
    '[pointer-events:var(--mi-toolbar-pe,none)]',
    5,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('pointer-events', _v268)]),
    ],
  ),
  RaftUtility('[stroke-linecap:butt]', 1089, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('stroke-linecap', CssKeyword('butt')),
    ]),
  ]),
  RaftUtility('[stroke-linecap:round]', 1090, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('stroke-linecap', CssKeyword('round')),
    ]),
  ]),
  RaftUtility(
    '[text-box:trim-both_cap_alphabetic]',
    1091,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('text-box', _v270)]),
    ],
  ),
  RaftUtility('absolute', 10, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('position', CssKeyword('absolute'))]),
  ]),
  RaftUtility(
    'active:after:bg-foreground-on-hud/15',
    1404,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v271),
        ],
      ),
      RaftLayer(
        '::after',
        ['active', 'dark'],
        2001,
        [RaftDecl('background-color', _v1)],
      ),
      RaftLayer(
        '::after',
        ['active'],
        2001,
        [RaftDecl('background-color', _v274)],
      ),
      RaftLayer(
        '::after',
        ['active', 'dark'],
        2001,
        [RaftDecl('background-color', CssColor(0x26E5E5E2))],
      ),
    ],
  ),
  RaftUtility(
    'active:before:bg-fill-medium',
    1401,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v104),
        ],
      ),
      RaftLayer(
        '::before',
        ['active', 'dark'],
        2001,
        [RaftDecl('background-color', _v105)],
      ),
    ],
  ),
  RaftUtility(
    'active:before:transition-none',
    1402,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('transition-property', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility('active:bg-brand-soft', 1393, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v275)]),
    RaftLayer(
      'self',
      ['active', 'dark'],
      2000,
      [RaftDecl('background-color', _v276)],
    ),
  ]),
  RaftUtility('active:bg-fill-frame-medium', 1394, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v29)]),
    RaftLayer(
      'self',
      ['active', 'dark'],
      2000,
      [RaftDecl('background-color', _v31)],
    ),
  ]),
  RaftUtility('active:bg-fill-medium', 1395, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-color', _v104)]),
    RaftLayer(
      'self',
      ['active', 'dark'],
      2000,
      [RaftDecl('background-color', _v105)],
    ),
  ]),
  RaftUtility('active:cursor-grabbing', 1392, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['active'],
      2000,
      [RaftDecl('cursor', CssKeyword('grabbing'))],
    ),
  ]),
  RaftUtility('active:overlay-medium', 1396, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('background-image', _v257)]),
    RaftLayer(
      'self',
      ['active', 'dark'],
      2000,
      [RaftDecl('background-image', _v258)],
    ),
  ]),
  RaftUtility(
    'active:overlay-sticker-medium',
    1397,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active'],
        2000,
        [RaftDecl('background-image', _v278)],
      ),
    ],
  ),
  RaftUtility('active:text-foreground', 1398, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['active'], 2000, [RaftDecl('color', _v0)]),
    RaftLayer('self', ['active', 'dark'], 2000, [RaftDecl('color', _v1)]),
  ]),
  RaftUtility('after:-inset-2', 1264, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(-8, 'px')),
      RaftDecl('right', CssNum(-8, 'px')),
      RaftDecl('bottom', CssNum(-8, 'px')),
      RaftDecl('left', CssNum(-8, 'px')),
    ]),
  ]),
  RaftUtility('after:-inset-3', 1265, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(-12, 'px')),
      RaftDecl('right', CssNum(-12, 'px')),
      RaftDecl('bottom', CssNum(-12, 'px')),
      RaftDecl('left', CssNum(-12, 'px')),
    ]),
  ]),
  RaftUtility(
    'after:-inset-[calc((44px-var(--frame-item-height))/2+1.5px)]',
    1266,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssCalc(_v282)),
        RaftDecl('right', CssCalc(_v282)),
        RaftDecl('bottom', CssCalc(_v282)),
        RaftDecl('left', CssCalc(_v282)),
      ]),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('top', CssNum(-6.5, 'px')),
          RaftDecl('right', CssNum(-6.5, 'px')),
          RaftDecl('bottom', CssNum(-6.5, 'px')),
          RaftDecl('left', CssNum(-6.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'after:-inset-[calc((var(--control-height)+2*var(--control-hit-inset)-var(--bar-button-size))/2+1.5px)]',
    1267,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssCalc(_v289)),
        RaftDecl('right', CssCalc(_v289)),
        RaftDecl('bottom', CssCalc(_v289)),
        RaftDecl('left', CssCalc(_v289)),
      ]),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('top', CssNum(-9.5, 'px')),
          RaftDecl('right', CssNum(-9.5, 'px')),
          RaftDecl('bottom', CssNum(-9.5, 'px')),
          RaftDecl('left', CssNum(-9.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'after:-inset-[calc(--spacing(1.5)+1.5px)]',
    1268,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssNum(-7.5, 'px')),
        RaftDecl('right', CssNum(-7.5, 'px')),
        RaftDecl('bottom', CssNum(-7.5, 'px')),
        RaftDecl('left', CssNum(-7.5, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    'after:-inset-[calc(var(--spacing-control-hit)+1.5px)]',
    1269,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssCalc(_v291)),
        RaftDecl('right', CssCalc(_v291)),
        RaftDecl('bottom', CssCalc(_v291)),
        RaftDecl('left', CssCalc(_v291)),
      ]),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('top', CssNum(-6.5, 'px')),
          RaftDecl('right', CssNum(-6.5, 'px')),
          RaftDecl('bottom', CssNum(-6.5, 'px')),
          RaftDecl('left', CssNum(-6.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'after:-inset-e-[calc(--spacing(2)+1.5px)]',
    1288,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('right', CssNum(-9.5, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    'after:-inset-e-[calc(--spacing(4)+1.5px)]',
    1289,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('right', CssNum(-17.5, 'px')),
      ]),
    ],
  ),
  RaftUtility('after:-inset-x-1', 1271, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(-4, 'px')),
      RaftDecl('right', CssNum(-4, 'px')),
    ]),
  ]),
  RaftUtility('after:-inset-x-2', 1272, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(-8, 'px')),
      RaftDecl('right', CssNum(-8, 'px')),
    ]),
  ]),
  RaftUtility('after:-inset-x-2.5', 1273, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(-10, 'px')),
      RaftDecl('right', CssNum(-10, 'px')),
    ]),
  ]),
  RaftUtility('after:-inset-x-3', 1274, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(-12, 'px')),
      RaftDecl('right', CssNum(-12, 'px')),
    ]),
  ]),
  RaftUtility('after:-inset-y-1.5', 1276, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(-6, 'px')),
      RaftDecl('bottom', CssNum(-6, 'px')),
    ]),
  ]),
  RaftUtility('after:-inset-y-2', 1277, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(-8, 'px')),
      RaftDecl('bottom', CssNum(-8, 'px')),
    ]),
  ]),
  RaftUtility('after:-inset-y-2.5', 1278, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(-10, 'px')),
      RaftDecl('bottom', CssNum(-10, 'px')),
    ]),
  ]),
  RaftUtility('after:-inset-y-3', 1279, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(-12, 'px')),
      RaftDecl('bottom', CssNum(-12, 'px')),
    ]),
  ]),
  RaftUtility(
    'after:-inset-y-[calc((44px-var(--frame-item-height))/2+1.5px)]',
    1280,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssCalc(_v282)),
        RaftDecl('bottom', CssCalc(_v282)),
      ]),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('top', CssNum(-6.5, 'px')),
          RaftDecl('bottom', CssNum(-6.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'after:-inset-y-[calc((44px-var(--switch-height))/2+1.5px)]',
    1281,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssCalc(_v295)),
        RaftDecl('bottom', CssCalc(_v295)),
      ]),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('top', CssNum(-12.5, 'px')),
          RaftDecl('bottom', CssNum(-12.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'after:-inset-y-[calc(--spacing(1.5)+1.5px)]',
    1282,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssNum(-7.5, 'px')),
        RaftDecl('bottom', CssNum(-7.5, 'px')),
      ]),
    ],
  ),
  RaftUtility(
    'after:-inset-y-[calc(var(--spacing-control-hit)+1.5px)]',
    1283,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssCalc(_v291)),
        RaftDecl('bottom', CssCalc(_v291)),
      ]),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('top', CssNum(-6.5, 'px')),
          RaftDecl('bottom', CssNum(-6.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('after:-mb-px', 1298, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('margin-bottom', CssNum(-1, 'px')),
    ]),
  ]),
  RaftUtility('after:absolute', 1263, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('position', CssKeyword('absolute')),
    ]),
  ]),
  RaftUtility('after:bg-attention-400', 1314, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v138),
    ]),
  ]),
  RaftUtility('after:border-[1.5px]', 1310, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-style', _v16),
      RaftDecl('border-right-style', _v16),
      RaftDecl('border-bottom-style', _v16),
      RaftDecl('border-left-style', _v16),
      RaftDecl('border-top-width', CssNum(1.5, 'px')),
      RaftDecl('border-right-width', CssNum(1.5, 'px')),
      RaftDecl('border-bottom-width', CssNum(1.5, 'px')),
      RaftDecl('border-left-width', CssNum(1.5, 'px')),
    ]),
  ]),
  RaftUtility('after:border-line-hairline', 1312, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-color', _v252),
      RaftDecl('border-right-color', _v252),
      RaftDecl('border-bottom-color', _v252),
      RaftDecl('border-left-color', _v252),
    ]),
    RaftLayer(
      '::after',
      ['dark'],
      1001,
      [
        RaftDecl('border-top-color', _v253),
        RaftDecl('border-right-color', _v253),
        RaftDecl('border-bottom-color', _v253),
        RaftDecl('border-left-color', _v253),
      ],
    ),
  ]),
  RaftUtility('after:border-sticker-ink', 1313, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-color', _v143),
      RaftDecl('border-right-color', _v143),
      RaftDecl('border-bottom-color', _v143),
      RaftDecl('border-left-color', _v143),
    ]),
  ]),
  RaftUtility('after:border-t', 1311, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-style', _v16),
      RaftDecl('border-top-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('after:content-[\'\']', 1318, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('--tw-content', CssString('')),
      RaftDecl('content', CssVar('--tw-content')),
    ]),
  ]),
  RaftUtility('after:end-0', 1290, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('after:flex-1', 1305, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('flex', CssNum(1)),
    ]),
  ]),
  RaftUtility('after:frame-decor-rail', 1315, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-image', _v296),
      RaftDecl('background-repeat', CssKeyword('no-repeat')),
      RaftDecl('background-position', _v297),
    ]),
  ]),
  RaftUtility('after:h-28', 1301, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(112, 'px')),
    ]),
  ]),
  RaftUtility('after:hidden', 1299, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('display', CssKeyword('none')),
    ]),
  ]),
  RaftUtility(
    'after:inset-[min(0px,calc((100%-44px)/2))]',
    1270,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', _v300),
        RaftDecl('right', _v300),
        RaftDecl('bottom', _v300),
        RaftDecl('left', _v300),
      ]),
    ],
  ),
  RaftUtility('after:inset-e-[-21.5px]', 1291, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('right', CssNum(-21.5, 'px')),
    ]),
  ]),
  RaftUtility('after:inset-s-0', 1286, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('after:inset-x-0', 1275, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('after:inset-y-0', 1284, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(0, 'px')),
      RaftDecl('bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('after:inset-y-[-1.5px]', 1285, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(-1.5, 'px')),
      RaftDecl('bottom', CssNum(-1.5, 'px')),
    ]),
  ]),
  RaftUtility('after:left-0', 1295, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('after:min-h-0', 1302, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('min-height', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('after:min-w-3', 1304, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('min-width', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility(
    'after:mr-(--inbox-item-aside-room,0px)',
    1297,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('margin-right', _v76),
      ]),
    ],
  ),
  RaftUtility('after:mt-auto', 1296, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('margin-top', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility(
    'after:opacity-[calc(1-var(--inbox-item-reveal-aside,0)*var(--inbox-item-revealed,0))]',
    1316,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('opacity', CssCalc(_v79)),
      ]),
    ],
  ),
  RaftUtility('after:pointer-events-none', 1262, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('pointer-events', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('after:right-4', 1293, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('right', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility(
    'after:right-[calc(-0.75rem-1.5px)]',
    1294,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('right', CssNum(-13.5, 'px')),
      ]),
    ],
  ),
  RaftUtility('after:rounded-[2px]', 1308, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', CssNum(2, 'px')),
      RaftDecl('border-top-right-radius', CssNum(2, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(2, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('after:rounded-control', 1309, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', CssNum(8, 'px')),
      RaftDecl('border-top-right-radius', CssNum(8, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(8, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('after:shrink', 1306, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('flex-shrink', CssNum(1)),
    ]),
  ]),
  RaftUtility('after:shrink-0', 1307, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('flex-shrink', CssNum(0)),
    ]),
  ]),
  RaftUtility('after:size-2.5', 1300, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(10, 'px')),
      RaftDecl('height', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('after:start-0', 1287, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    'after:top-[calc(--spacing(3)+(var(--text-subhead--line-height)-10px)/2)]',
    1292,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::after', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('top', CssNum(17, 'px')),
      ]),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [RaftDecl('top', CssNum(18, 'px'))],
      ),
    ],
  ),
  RaftUtility('after:transition-opacity', 1317, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('transition-property', CssKeyword('opacity')),
      RaftDecl('transition-timing-function', _v11),
      RaftDecl('transition-duration', _v12),
    ]),
  ]),
  RaftUtility('after:w-12', 1303, RaftUtilityStatus.resolved, [
    RaftLayer('::after', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(48, 'px')),
    ]),
  ]),
  RaftUtility('align-baseline', 779, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('vertical-align', CssKeyword('baseline')),
    ]),
  ]),
  RaftUtility('align-bottom', 780, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('vertical-align', CssKeyword('bottom')),
    ]),
  ]),
  RaftUtility('align-middle', 781, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('vertical-align', CssKeyword('middle')),
    ]),
  ]),
  RaftUtility('align-top', 782, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('vertical-align', CssKeyword('top')),
    ]),
  ]),
  RaftUtility(
    'animate-[raft-toast-timeout-progress_var(--toast-progress-duration)_linear_forwards]',
    424,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('animation', _v303)]),
    ],
  ),
  RaftUtility('animate-pulse', 425, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('animation', _v305)]),
  ]),
  RaftUtility(
    'aria-[current=page]:text-foreground',
    1594,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['aria-current=page'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer(
        'self',
        ['aria-current=page', 'dark'],
        2000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility('aria-current:font-bold', 1564, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-current=true'],
      2000,
      [
        RaftDecl('--tw-font-weight', CssNum(700)),
        RaftDecl('font-weight', CssNum(700)),
      ],
    ),
  ]),
  RaftUtility(
    'aria-disabled:[--list-row-ink-2:var(--foreground-disabled)]',
    1577,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true'],
        2000,
        [RaftDecl('--list-row-ink-2', _v306)],
      ),
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark'],
        2000,
        [RaftDecl('--list-row-ink-2', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:[--list-row-ink-3:var(--foreground-disabled)]',
    1578,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true'],
        2000,
        [RaftDecl('--list-row-ink-3', _v306)],
      ),
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark'],
        2000,
        [RaftDecl('--list-row-ink-3', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:[--list-row-ink:var(--foreground-disabled)]',
    1579,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true'],
        2000,
        [RaftDecl('--list-row-ink', _v306)],
      ),
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark'],
        2000,
        [RaftDecl('--list-row-ink', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:active:scale-none',
    1582,
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
    'aria-disabled:active:translate-none',
    1581,
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
  RaftUtility('aria-disabled:bg-fill-muted', 1569, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-disabled=true'],
      2000,
      [RaftDecl('background-color', _v220)],
    ),
    RaftLayer(
      'self',
      ['aria-disabled=true', 'dark'],
      2000,
      [RaftDecl('background-color', _v221)],
    ),
  ]),
  RaftUtility('aria-disabled:bg-none', 1571, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-disabled=true'],
      2000,
      [RaftDecl('background-image', CssKeyword('none'))],
    ),
  ]),
  RaftUtility(
    'aria-disabled:bg-transparent',
    1570,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true'],
        2000,
        [RaftDecl('background-color', _v15)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:border-line-hairline',
    1567,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true'],
        2000,
        [
          RaftDecl('border-top-color', _v252),
          RaftDecl('border-right-color', _v252),
          RaftDecl('border-bottom-color', _v252),
          RaftDecl('border-left-color', _v252),
        ],
      ),
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark'],
        2000,
        [
          RaftDecl('border-top-color', _v253),
          RaftDecl('border-right-color', _v253),
          RaftDecl('border-bottom-color', _v253),
          RaftDecl('border-left-color', _v253),
        ],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:border-transparent',
    1568,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true'],
        2000,
        [
          RaftDecl('border-top-color', _v15),
          RaftDecl('border-right-color', _v15),
          RaftDecl('border-bottom-color', _v15),
          RaftDecl('border-left-color', _v15),
        ],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:cursor-not-allowed',
    1566,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true'],
        2000,
        [RaftDecl('cursor', _v308)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:hover:translate-none',
    1580,
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
  RaftUtility('aria-disabled:inset-ring-0', 1576, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-disabled=true'],
      2000,
      [RaftDecl('--tw-inset-ring-shadow', _v309), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility('aria-disabled:opacity-100', 1574, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-disabled=true'],
      2000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility('aria-disabled:opacity-40', 1573, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-disabled=true'],
      2000,
      [RaftDecl('opacity', CssNum(40, '%'))],
    ),
  ]),
  RaftUtility('aria-disabled:ring-0', 1575, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-disabled=true'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v22), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'aria-disabled:text-foreground-disabled',
    1572,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-disabled=true'],
        2000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        'self',
        ['aria-disabled=true', 'dark'],
        2000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'aria-disabled:transform-none',
    1565,
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
  RaftUtility(
    'aria-expanded:bg-fill-frame-medium',
    1583,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-expanded=true'],
        2000,
        [RaftDecl('background-color', _v29)],
      ),
      RaftLayer(
        'self',
        ['aria-expanded=true', 'dark'],
        2000,
        [RaftDecl('background-color', _v31)],
      ),
    ],
  ),
  RaftUtility(
    'aria-pressed:active:overlay-sticker-medium',
    1590,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'aria-pressed=true'],
        3000,
        [RaftDecl('background-image', _v278)],
      ),
    ],
  ),
  RaftUtility('aria-pressed:bg-selected', 1586, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-pressed=true'],
      2000,
      [RaftDecl('background-color', _v310)],
    ),
  ]),
  RaftUtility(
    'aria-pressed:border-sticker-ink',
    1585,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-pressed=true'],
        2000,
        [
          RaftDecl('border-top-color', _v143),
          RaftDecl('border-right-color', _v143),
          RaftDecl('border-bottom-color', _v143),
          RaftDecl('border-left-color', _v143),
        ],
      ),
    ],
  ),
  RaftUtility('aria-pressed:ring-[1.5px]', 1588, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-pressed=true'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v145), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'aria-pressed:ring-sticker-edge',
    1589,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-pressed=true'],
        2000,
        [RaftDecl('--tw-ring-color', _v146)],
      ),
      RaftLayer(
        'self',
        ['aria-pressed=true', 'dark'],
        2000,
        [RaftDecl('--tw-ring-color', _v147)],
      ),
    ],
  ),
  RaftUtility(
    'aria-pressed:text-sticker-ink',
    1587,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-pressed=true'],
        2000,
        [RaftDecl('color', _v143)],
      ),
    ],
  ),
  RaftUtility('aria-pressed:z-raised', 1584, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-pressed=true'],
      2000,
      [RaftDecl('z-index', CssNum(1))],
    ),
  ]),
  RaftUtility(
    'aria-selected:active:bg-info-soft',
    1593,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'aria-selected=true'],
        3000,
        [RaftDecl('background-color', _v311)],
      ),
      RaftLayer(
        'self',
        ['active', 'aria-selected=true', 'dark'],
        3000,
        [RaftDecl('background-color', _v312)],
      ),
    ],
  ),
  RaftUtility('aria-selected:bg-info-soft', 1591, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['aria-selected=true'],
      2000,
      [RaftDecl('background-color', _v311)],
    ),
    RaftLayer(
      'self',
      ['aria-selected=true', 'dark'],
      2000,
      [RaftDecl('background-color', _v312)],
    ),
  ]),
  RaftUtility(
    'aria-selected:hover:bg-info-soft',
    1592,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['aria-selected=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v311)],
      ),
      RaftLayer(
        'self',
        ['aria-selected=true', 'dark', 'hover'],
        3000,
        [RaftDecl('background-color', _v312)],
      ),
    ],
  ),
  RaftUtility('aspect-video', 176, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('aspect-ratio', _v313)]),
  ]),
  RaftUtility('auto-cols-fr', 443, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-auto-columns', _v117)]),
  ]),
  RaftUtility('auto-rows-28', 445, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('grid-auto-rows', CssNum(112, 'px')),
    ]),
  ]),
  RaftUtility('auto-rows-32', 446, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('grid-auto-rows', CssNum(128, 'px')),
    ]),
  ]),
  RaftUtility('auto-rows-[7rem]', 447, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('grid-auto-rows', CssNum(112, 'px')),
    ]),
  ]),
  RaftUtility('auto-rows-[8rem]', 448, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('grid-auto-rows', CssNum(128, 'px')),
    ]),
  ]),
  RaftUtility('auto-rows-min', 449, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-auto-rows', _v314)]),
  ]),
  RaftUtility(
    'basis-(--fit-scroll-basis,0px)',
    402,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('flex-basis', _v315)]),
    ],
  ),
  RaftUtility('basis-0', 403, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-basis', CssNum(0, 'px'))]),
  ]),
  RaftUtility('basis-full', 404, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-basis', CssNum(100, '%'))]),
  ]),
  RaftUtility('before:-inset-1', 1197, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(-4, 'px')),
      RaftDecl('right', CssNum(-4, 'px')),
      RaftDecl('bottom', CssNum(-4, 'px')),
      RaftDecl('left', CssNum(-4, 'px')),
    ]),
  ]),
  RaftUtility('before:-left-px', 1209, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(-1, 'px')),
    ]),
  ]),
  RaftUtility('before:-translate-x-1/2', 1232, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-translate-x', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v84, _v85])),
    ]),
  ]),
  RaftUtility('before:-translate-y-1/2', 1233, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-translate-y', CssNum(-50, '%')),
      RaftDecl('translate', CssSeq([_v84, _v85])),
    ]),
  ]),
  RaftUtility('before:absolute', 1196, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('position', CssKeyword('absolute')),
    ]),
  ]),
  RaftUtility('before:bg-attention', 1246, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v138),
    ]),
  ]),
  RaftUtility('before:bg-danger', 1247, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v217),
    ]),
  ]),
  RaftUtility('before:bg-inactive', 1248, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v316),
    ]),
  ]),
  RaftUtility('before:bg-info', 1249, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v212),
    ]),
  ]),
  RaftUtility('before:bg-line-seam', 1250, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v317),
    ]),
    RaftLayer(
      '::before',
      ['dark'],
      1001,
      [RaftDecl('background-color', _v318)],
    ),
  ]),
  RaftUtility('before:bg-presence-busy', 1251, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v224),
    ]),
  ]),
  RaftUtility('before:bg-success', 1252, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v218),
    ]),
  ]),
  RaftUtility('before:bg-transparent', 1253, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v15),
    ]),
  ]),
  RaftUtility('before:bg-warning', 1254, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('background-color', _v213),
    ]),
  ]),
  RaftUtility('before:block', 1217, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('display', CssKeyword('block')),
    ]),
  ]),
  RaftUtility('before:border-0', 1240, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-style', _v16),
      RaftDecl('border-right-style', _v16),
      RaftDecl('border-bottom-style', _v16),
      RaftDecl('border-left-style', _v16),
      RaftDecl('border-top-width', CssNum(0, 'px')),
      RaftDecl('border-right-width', CssNum(0, 'px')),
      RaftDecl('border-bottom-width', CssNum(0, 'px')),
      RaftDecl('border-left-width', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('before:border-[1.5px]', 1241, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-style', _v16),
      RaftDecl('border-right-style', _v16),
      RaftDecl('border-bottom-style', _v16),
      RaftDecl('border-left-style', _v16),
      RaftDecl('border-top-width', CssNum(1.5, 'px')),
      RaftDecl('border-right-width', CssNum(1.5, 'px')),
      RaftDecl('border-bottom-width', CssNum(1.5, 'px')),
      RaftDecl('border-left-width', CssNum(1.5, 'px')),
    ]),
  ]),
  RaftUtility('before:border-line-hairline', 1243, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-color', _v252),
      RaftDecl('border-right-color', _v252),
      RaftDecl('border-bottom-color', _v252),
      RaftDecl('border-left-color', _v252),
    ]),
    RaftLayer(
      '::before',
      ['dark'],
      1001,
      [
        RaftDecl('border-top-color', _v253),
        RaftDecl('border-right-color', _v253),
        RaftDecl('border-bottom-color', _v253),
        RaftDecl('border-left-color', _v253),
      ],
    ),
  ]),
  RaftUtility('before:border-sticker-ink', 1244, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-color', _v143),
      RaftDecl('border-right-color', _v143),
      RaftDecl('border-bottom-color', _v143),
      RaftDecl('border-left-color', _v143),
    ]),
  ]),
  RaftUtility('before:border-t', 1242, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-style', _v16),
      RaftDecl('border-top-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('before:border-transparent', 1245, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-color', _v15),
      RaftDecl('border-right-color', _v15),
      RaftDecl('border-bottom-color', _v15),
      RaftDecl('border-left-color', _v15),
    ]),
  ]),
  RaftUtility('before:bottom-3', 1208, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('bottom', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('before:content-[\'\']', 1259, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('--tw-content', CssString('')),
      RaftDecl('content', CssVar('--tw-content')),
    ]),
  ]),
  RaftUtility('before:content-[\'·\']', 1260, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('--tw-content', CssString('·')),
      RaftDecl('content', CssVar('--tw-content')),
    ]),
  ]),
  RaftUtility('before:duration-150', 1257, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-duration', CssNum(150, 'ms')),
      RaftDecl('transition-duration', CssNum(150, 'ms')),
    ]),
  ]),
  RaftUtility('before:ease-out', 1258, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('--tw-ease', _v123),
      RaftDecl('transition-timing-function', _v123),
    ]),
  ]),
  RaftUtility('before:flex-1', 1230, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('flex', CssNum(1)),
    ]),
  ]),
  RaftUtility('before:h-1', 1220, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('before:h-9', 1221, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(36, 'px')),
    ]),
  ]),
  RaftUtility('before:h-[30px]', 1222, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(30, 'px')),
    ]),
  ]),
  RaftUtility(
    'before:h-[calc(var(--toast-gap)+3px)]',
    1223,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('height', CssCalc(_v319)),
      ]),
    ],
  ),
  RaftUtility('before:h-full', 1224, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('height', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility('before:hidden', 1218, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('display', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('before:inset-x-0', 1198, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('before:inset-y-0', 1199, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(0, 'px')),
      RaftDecl('bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility(
    'before:left-(--cell-inset-x)',
    1210,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('left', _v150),
      ]),
    ],
  ),
  RaftUtility(
    'before:left-(--list-row-rule-start)',
    1211,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('left', _v320),
      ]),
    ],
  ),
  RaftUtility('before:left-1/2', 1212, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(50, '%')),
    ]),
  ]),
  RaftUtility('before:left-3', 1213, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('before:left-4', 1214, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('left', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('before:min-w-3', 1229, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('min-width', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('before:pe-1.5', 1255, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('padding-right', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('before:pointer-events-auto', 1194, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('pointer-events', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('before:pointer-events-none', 1195, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('pointer-events', CssKeyword('none')),
    ]),
  ]),
  RaftUtility(
    'before:right-(--cell-inset-end)',
    1205,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('right', _v321),
      ]),
    ],
  ),
  RaftUtility('before:right-0', 1206, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('before:right-3', 1207, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('right', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility(
    'before:rounded-(--cell-radius)',
    1235,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::before', [], 1001, [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('border-top-left-radius', CssVar('--cell-radius')),
        RaftDecl('border-top-right-radius', CssVar('--cell-radius')),
        RaftDecl('border-bottom-right-radius', CssVar('--cell-radius')),
        RaftDecl('border-bottom-left-radius', CssVar('--cell-radius')),
      ]),
    ],
  ),
  RaftUtility('before:rounded-[2px]', 1236, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', CssNum(2, 'px')),
      RaftDecl('border-top-right-radius', CssNum(2, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(2, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('before:rounded-control', 1237, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', CssNum(8, 'px')),
      RaftDecl('border-top-right-radius', CssNum(8, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(8, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('before:rounded-full', 1238, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', _v322),
      RaftDecl('border-top-right-radius', _v322),
      RaftDecl('border-bottom-right-radius', _v322),
      RaftDecl('border-bottom-left-radius', _v322),
    ]),
  ]),
  RaftUtility('before:rounded-none', 1239, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('border-top-left-radius', CssNum(0)),
      RaftDecl('border-top-right-radius', CssNum(0)),
      RaftDecl('border-bottom-right-radius', CssNum(0)),
      RaftDecl('border-bottom-left-radius', CssNum(0)),
    ]),
  ]),
  RaftUtility('before:shrink-0', 1231, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('flex-shrink', CssNum(0)),
    ]),
  ]),
  RaftUtility('before:size-2.5', 1219, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(10, 'px')),
      RaftDecl('height', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('before:top-0', 1200, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('before:top-1.5', 1201, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('before:top-1/2', 1202, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(50, '%')),
    ]),
  ]),
  RaftUtility('before:top-3', 1203, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('before:top-full', 1204, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('top', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility('before:transition-colors', 1256, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('transition-property', _v329),
      RaftDecl('transition-timing-function', _v11),
      RaftDecl('transition-duration', _v12),
    ]),
  ]),
  RaftUtility('before:translate-none', 1234, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('translate', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('before:w-1', 1225, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('before:w-14', 1227, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(56, 'px')),
    ]),
  ]),
  RaftUtility('before:w-9', 1226, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(36, 'px')),
    ]),
  ]),
  RaftUtility('before:w-px', 1228, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('before:z-base', 1215, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('z-index', CssNum(0)),
    ]),
  ]),
  RaftUtility('before:z-below', 1216, RaftUtilityStatus.resolved, [
    RaftLayer('::before', [], 1001, [
      RaftDecl('content', CssVar('--tw-content')),
      RaftDecl('z-index', CssNum(-1)),
    ]),
  ]),
  RaftUtility('bg-(--fill-muted)', 569, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v220)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v221)]),
  ]),
  RaftUtility('bg-(--meter-indicator)', 570, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v330)]),
  ]),
  RaftUtility('bg-(--mi-row-fill)', 571, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssVar('--mi-row-fill')),
    ]),
  ]),
  RaftUtility('bg-(--progress-indicator)', 572, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v331)]),
  ]),
  RaftUtility('bg-(--progress-track)', 573, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v332)]),
  ]),
  RaftUtility(
    'bg-(--split-action-main-tint,transparent)',
    574,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v333)]),
    ],
  ),
  RaftUtility(
    'bg-(--split-action-menu-tint,transparent)',
    575,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v334)]),
    ],
  ),
  RaftUtility('bg-(--status-color)', 576, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v335)]),
  ]),
  RaftUtility(
    'bg-[linear-gradient(var(--fill-subtle),var(--fill-subtle))]',
    630,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-image', _v237)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-image', _v238)]),
    ],
  ),
  RaftUtility(
    'bg-[linear-gradient(var(--info-soft),var(--info-soft))]',
    631,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-image', _v336)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-image', _v337)]),
    ],
  ),
  RaftUtility(
    'bg-[linear-gradient(var(--mi-row-fill,transparent),var(--mi-row-fill,transparent))]',
    632,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-image', _v339)]),
    ],
  ),
  RaftUtility('bg-attention', 577, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v138)]),
  ]),
  RaftUtility('bg-attention-400', 578, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v138)]),
  ]),
  RaftUtility('bg-attention-soft', 579, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v340)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v341)]),
  ]),
  RaftUtility('bg-black', 580, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v342)]),
  ]),
  RaftUtility('bg-brand', 581, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v256)]),
  ]),
  RaftUtility('bg-brand-soft', 582, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v275)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v276)]),
  ]),
  RaftUtility('bg-clip-padding', 639, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-clip', _v343)]),
  ]),
  RaftUtility('bg-current', 583, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v20)]),
  ]),
  RaftUtility('bg-danger', 584, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v217)]),
  ]),
  RaftUtility('bg-danger-soft', 585, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v344)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v345)]),
  ]),
  RaftUtility('bg-fill-frame-medium', 586, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v29)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v31)]),
  ]),
  RaftUtility('bg-fill-muted', 587, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v220)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v221)]),
  ]),
  RaftUtility('bg-fill-subtle', 588, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v113)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v114)]),
  ]),
  RaftUtility('bg-foreground', 589, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v0)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v1)]),
  ]),
  RaftUtility('bg-foreground-disabled', 590, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v306)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v307)]),
  ]),
  RaftUtility('bg-foreground-on-hud/40', 591, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v271)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v1)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v347)]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('background-color', CssColor(0x66E5E5E2))],
    ),
  ]),
  RaftUtility('bg-foreground/10', 592, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v0)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v1)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v349)]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('background-color', CssColor(0x1AE5E5E2))],
    ),
  ]),
  RaftUtility('bg-foreground/15', 593, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v0)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v1)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v351)]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('background-color', CssColor(0x26E5E5E2))],
    ),
  ]),
  RaftUtility('bg-foreground/25', 594, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v0)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v1)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v353)]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('background-color', CssColor(0x40E5E5E2))],
    ),
  ]),
  RaftUtility('bg-foreground/40', 595, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v0)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v1)]),
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v355)]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('background-color', CssColor(0x66E5E5E2))],
    ),
  ]),
  RaftUtility('bg-inactive', 596, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v316)]),
  ]),
  RaftUtility('bg-inactive-soft', 597, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v356)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v221)]),
  ]),
  RaftUtility('bg-info', 598, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v212)]),
  ]),
  RaftUtility('bg-info-soft', 599, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v311)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v312)]),
  ]),
  RaftUtility('bg-layer-backdrop', 600, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v357)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v358)]),
  ]),
  RaftUtility('bg-layer-backdrop-nested', 601, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v359)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v360)]),
  ]),
  RaftUtility('bg-layer-canvas', 602, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v361)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v128)]),
  ]),
  RaftUtility('bg-layer-card', 603, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v362)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v363)]),
  ]),
  RaftUtility('bg-layer-code', 604, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v364)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v365)]),
  ]),
  RaftUtility('bg-layer-frame', 605, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v366)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v367)]),
  ]),
  RaftUtility('bg-layer-hud', 606, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v368)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v369)]),
  ]),
  RaftUtility('bg-layer-popover', 607, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v370)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v369)]),
  ]),
  RaftUtility('bg-layer-sidebar', 608, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v371)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v367)]),
  ]),
  RaftUtility('bg-layer-veil', 609, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v372)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v373)]),
  ]),
  RaftUtility('bg-line-hairline', 610, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v252)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v253)]),
  ]),
  RaftUtility('bg-linear-to-t', 628, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-gradient-position', _v374),
      RaftDecl('background-image', _v376),
    ]),
    RaftLayer('self', [], 1000, [RaftDecl('--tw-gradient-position', _v377)]),
  ]),
  RaftUtility('bg-palette-lavender', 611, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v378)]),
  ]),
  RaftUtility('bg-presence-busy', 612, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v224)]),
  ]),
  RaftUtility('bg-presence-busy-soft', 613, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v379)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v276)]),
  ]),
  RaftUtility('bg-presence-online', 614, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v112)]),
  ]),
  RaftUtility('bg-sticker-ink', 615, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v143)]),
  ]),
  RaftUtility('bg-sticker-paper', 616, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v380)]),
  ]),
  RaftUtility('bg-success', 617, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v218)]),
  ]),
  RaftUtility('bg-success-soft', 618, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v381)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v382)]),
  ]),
  RaftUtility('bg-task-status-closed-soft', 619, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v383)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v221)]),
  ]),
  RaftUtility('bg-task-status-done-soft', 620, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v384)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v382)]),
  ]),
  RaftUtility(
    'bg-task-status-in-progress-soft',
    621,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v385)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v312)]),
    ],
  ),
  RaftUtility(
    'bg-task-status-in-review-soft',
    622,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('background-color', _v386)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v387)]),
    ],
  ),
  RaftUtility('bg-task-status-todo-soft', 623, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v388)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v389)]),
  ]),
  RaftUtility('bg-transparent', 624, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v15)]),
  ]),
  RaftUtility('bg-warning', 625, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v213)]),
  ]),
  RaftUtility('bg-warning-soft', 626, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v390)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('background-color', _v389)]),
  ]),
  RaftUtility('bg-you', 627, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('background-color', _v391)]),
  ]),
  RaftUtility('block', 166, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('block'))]),
  ]),
  RaftUtility('blur-0', -1, RaftUtilityStatus.noCss, []),
  RaftUtility('border', 543, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v16),
      RaftDecl('border-right-style', _v16),
      RaftDecl('border-bottom-style', _v16),
      RaftDecl('border-left-style', _v16),
      RaftDecl('border-top-width', CssNum(1, 'px')),
      RaftDecl('border-right-width', CssNum(1, 'px')),
      RaftDecl('border-bottom-width', CssNum(1, 'px')),
      RaftDecl('border-left-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('border-0', 544, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v16),
      RaftDecl('border-right-style', _v16),
      RaftDecl('border-bottom-style', _v16),
      RaftDecl('border-left-style', _v16),
      RaftDecl('border-top-width', CssNum(0, 'px')),
      RaftDecl('border-right-width', CssNum(0, 'px')),
      RaftDecl('border-bottom-width', CssNum(0, 'px')),
      RaftDecl('border-left-width', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('border-[1.5px]', 545, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v16),
      RaftDecl('border-right-style', _v16),
      RaftDecl('border-bottom-style', _v16),
      RaftDecl('border-left-style', _v16),
      RaftDecl('border-top-width', CssNum(1.5, 'px')),
      RaftDecl('border-right-width', CssNum(1.5, 'px')),
      RaftDecl('border-bottom-width', CssNum(1.5, 'px')),
      RaftDecl('border-left-width', CssNum(1.5, 'px')),
    ]),
  ]),
  RaftUtility('border-b', 553, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-bottom-style', _v16),
      RaftDecl('border-bottom-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('border-collapse', 406, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-collapse', CssKeyword('collapse')),
    ]),
  ]),
  RaftUtility('border-danger-strong', 557, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v392),
      RaftDecl('border-right-color', _v392),
      RaftDecl('border-bottom-color', _v392),
      RaftDecl('border-left-color', _v392),
    ]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v393),
        RaftDecl('border-right-color', _v393),
        RaftDecl('border-bottom-color', _v393),
        RaftDecl('border-left-color', _v393),
      ],
    ),
  ]),
  RaftUtility('border-dashed', 556, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-border-style', CssKeyword('dashed')),
      RaftDecl('border-top-style', CssKeyword('dashed')),
      RaftDecl('border-right-style', CssKeyword('dashed')),
      RaftDecl('border-bottom-style', CssKeyword('dashed')),
      RaftDecl('border-left-style', CssKeyword('dashed')),
    ]),
  ]),
  RaftUtility('border-e-0', 548, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-right-style', _v16),
      RaftDecl('border-right-width', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('border-foreground', 558, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v0),
      RaftDecl('border-right-color', _v0),
      RaftDecl('border-bottom-color', _v0),
      RaftDecl('border-left-color', _v0),
    ]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v1),
        RaftDecl('border-right-color', _v1),
        RaftDecl('border-bottom-color', _v1),
        RaftDecl('border-left-color', _v1),
      ],
    ),
  ]),
  RaftUtility('border-foreground-disabled', 559, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v306),
      RaftDecl('border-right-color', _v306),
      RaftDecl('border-bottom-color', _v306),
      RaftDecl('border-left-color', _v306),
    ]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v307),
        RaftDecl('border-right-color', _v307),
        RaftDecl('border-bottom-color', _v307),
        RaftDecl('border-left-color', _v307),
      ],
    ),
  ]),
  RaftUtility('border-foreground/40', 560, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v0),
      RaftDecl('border-right-color', _v0),
      RaftDecl('border-bottom-color', _v0),
      RaftDecl('border-left-color', _v0),
    ]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v1),
        RaftDecl('border-right-color', _v1),
        RaftDecl('border-bottom-color', _v1),
        RaftDecl('border-left-color', _v1),
      ],
    ),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v355),
      RaftDecl('border-right-color', _v355),
      RaftDecl('border-bottom-color', _v355),
      RaftDecl('border-left-color', _v355),
    ]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', CssColor(0x66E5E5E2)),
        RaftDecl('border-right-color', CssColor(0x66E5E5E2)),
        RaftDecl('border-bottom-color', CssColor(0x66E5E5E2)),
        RaftDecl('border-left-color', CssColor(0x66E5E5E2)),
      ],
    ),
  ]),
  RaftUtility('border-l', 554, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-left-style', _v16),
      RaftDecl('border-left-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('border-l-2', 555, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-left-style', _v16),
      RaftDecl('border-left-width', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('border-line-field', 561, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v394),
      RaftDecl('border-right-color', _v394),
      RaftDecl('border-bottom-color', _v394),
      RaftDecl('border-left-color', _v394),
    ]),
  ]),
  RaftUtility('border-line-hairline', 562, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v252),
      RaftDecl('border-right-color', _v252),
      RaftDecl('border-bottom-color', _v252),
      RaftDecl('border-left-color', _v252),
    ]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v253),
        RaftDecl('border-right-color', _v253),
        RaftDecl('border-bottom-color', _v253),
        RaftDecl('border-left-color', _v253),
      ],
    ),
  ]),
  RaftUtility('border-line-seam', 563, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v317),
      RaftDecl('border-right-color', _v317),
      RaftDecl('border-bottom-color', _v317),
      RaftDecl('border-left-color', _v317),
    ]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v318),
        RaftDecl('border-right-color', _v318),
        RaftDecl('border-bottom-color', _v318),
        RaftDecl('border-left-color', _v318),
      ],
    ),
  ]),
  RaftUtility('border-line-strong', 564, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v395),
      RaftDecl('border-right-color', _v395),
      RaftDecl('border-bottom-color', _v395),
      RaftDecl('border-left-color', _v395),
    ]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('border-top-color', _v1),
        RaftDecl('border-right-color', _v1),
        RaftDecl('border-bottom-color', _v1),
        RaftDecl('border-left-color', _v1),
      ],
    ),
  ]),
  RaftUtility('border-r', 552, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-right-style', _v16),
      RaftDecl('border-right-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('border-s-0', 547, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-left-style', _v16),
      RaftDecl('border-left-width', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('border-sticker-ink', 565, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v143),
      RaftDecl('border-right-color', _v143),
      RaftDecl('border-bottom-color', _v143),
      RaftDecl('border-left-color', _v143),
    ]),
  ]),
  RaftUtility('border-sticker-paper/40', 566, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v380),
      RaftDecl('border-right-color', _v380),
      RaftDecl('border-bottom-color', _v380),
      RaftDecl('border-left-color', _v380),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v397),
      RaftDecl('border-right-color', _v397),
      RaftDecl('border-bottom-color', _v397),
      RaftDecl('border-left-color', _v397),
    ]),
  ]),
  RaftUtility('border-t', 549, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v16),
      RaftDecl('border-top-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility(
    'border-t-(length:--spacing-timeline-turn)',
    550,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-style', _v16),
        RaftDecl('border-top-width', CssCalc(_v401)),
      ]),
    ],
  ),
  RaftUtility('border-t-0', 551, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-style', _v16),
      RaftDecl('border-top-width', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('border-transparent', 567, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-color', _v15),
      RaftDecl('border-right-color', _v15),
      RaftDecl('border-bottom-color', _v15),
      RaftDecl('border-left-color', _v15),
    ]),
  ]),
  RaftUtility('bottom-(--drawer-inset)', 50, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', _v161)]),
  ]),
  RaftUtility('bottom-0', 51, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(0, 'px'))]),
  ]),
  RaftUtility('bottom-0.5', 52, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(2, 'px'))]),
  ]),
  RaftUtility('bottom-1.5', 53, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(6, 'px'))]),
  ]),
  RaftUtility('bottom-20', 55, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(80, 'px'))]),
  ]),
  RaftUtility('bottom-4', 54, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(16, 'px'))]),
  ]),
  RaftUtility('bottom-[-3px]', 56, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(-3, 'px'))]),
  ]),
  RaftUtility(
    'bottom-[calc(--spacing(3)+var(--message-list-bottom-inset,0px))]',
    57,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('bottom', CssCalc(_v403))]),
    ],
  ),
  RaftUtility(
    'bottom-[calc(max(var(--toast-viewport-bottom,0px),env(safe-area-inset-bottom))+1rem)]',
    58,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('bottom', CssCalc(_v407))]),
    ],
  ),
  RaftUtility(
    'bottom-[calc(var(--control-embedded-inset)-1px)]',
    59,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('bottom', CssCalc(_v408))]),
    ],
  ),
  RaftUtility('bottom-full', 60, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('bottom', CssNum(100, '%'))]),
  ]),
  RaftUtility('box-border', 158, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('box-sizing', _v409)]),
  ]),
  RaftUtility('box-decoration-clone', 638, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('-webkit-box-decoration-break', CssKeyword('clone')),
      RaftDecl('box-decoration-break', CssKeyword('clone')),
    ]),
  ]),
  RaftUtility('break-all', 850, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('word-break', CssKeyword('break-all')),
    ]),
  ]),
  RaftUtility('caption-bottom', 405, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('caption-side', CssKeyword('bottom')),
    ]),
  ]),
  RaftUtility('clear-end', 104, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('clear', _v410)]),
  ]),
  RaftUtility('col-[-2/-1]', 87, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column', _v411)]),
  ]),
  RaftUtility(
    'col-end-(--banner-action-end,-1)',
    97,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-column-end', _v412)]),
    ],
  ),
  RaftUtility(
    'col-end-(--inbox-item-content-end)',
    98,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-column-end', _v413)]),
    ],
  ),
  RaftUtility('col-span-2', 88, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column', _v414)]),
  ]),
  RaftUtility('col-span-full', 89, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column', _v119)]),
  ]),
  RaftUtility(
    'col-start-(--banner-text-col,1)',
    91,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', _v91)]),
    ],
  ),
  RaftUtility('col-start-(--card-text-col,1)', 92, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', _v415)]),
  ]),
  RaftUtility(
    'col-start-(--card-trailing-col,2)',
    93,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', _v416)]),
    ],
  ),
  RaftUtility('col-start-1', 94, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', CssNum(1))]),
  ]),
  RaftUtility('col-start-2', 95, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-column-start', CssNum(2))]),
  ]),
  RaftUtility(
    'col-start-[calc(var(--banner-text-col,1)+1)]',
    96,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('grid-column-start', CssCalc(_v92)),
      ]),
    ],
  ),
  RaftUtility('content-start', 467, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('align-content', _v61)]),
  ]),
  RaftUtility('contents', 167, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('contents'))]),
  ]),
  RaftUtility('cursor-default', 426, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', CssKeyword('default'))]),
  ]),
  RaftUtility('cursor-ew-resize', 427, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', CssKeyword('ew-resize'))]),
  ]),
  RaftUtility('cursor-grab', 428, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', CssKeyword('grab'))]),
  ]),
  RaftUtility('cursor-not-allowed', 429, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', _v308)]),
  ]),
  RaftUtility('cursor-pointer', 430, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', CssKeyword('pointer'))]),
  ]),
  RaftUtility('cursor-wait', 431, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('cursor', CssKeyword('wait'))]),
  ]),
  RaftUtility(
    'dark:[&_pre_span]:text-(--shiki-dark,currentColor)',
    2425,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& pre span', ['dark'], 1002, [RaftDecl('color', _v417)]),
    ],
  ),
  RaftUtility(
    'dark:shadow-[0_0_0_3px_var(--mi-row-fill,transparent),0_0_0_3px_var(--layer-canvas)]',
    2209,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [
          RaftDecl('--tw-shadow', CssList([_v419, _v421])),
          RaftDecl('box-shadow', _v27),
        ],
      ),
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [
          RaftDecl('--tw-shadow', CssList([_v419, _v423])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[active=true]:before:bg-fill-cell-selected',
    1806,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-active=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v424),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'data-active=true'],
        2001,
        [RaftDecl('background-color', _v425)],
      ),
    ],
  ),
  RaftUtility(
    'data-[busy=true]:cursor-wait',
    1810,
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
    1812,
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
  RaftUtility(
    'data-[busy=true]:opacity-dimmed',
    1811,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-busy=true'], 2000, [RaftDecl('opacity', _v426)]),
    ],
  ),
  RaftUtility(
    'data-[busy=true]:pointer-events-none',
    1809,
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
    'data-[direction=down]:bottom-0',
    1813,
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
  RaftUtility('data-[direction=up]:top-0', 1814, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-direction=up'],
      2000,
      [RaftDecl('top', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility(
    'data-[disabled=true]:bg-fill-muted',
    1819,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('background-color', _v220)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-disabled=true'],
        2000,
        [RaftDecl('background-color', _v221)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:cursor-default',
    1817,
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
    'data-[disabled=true]:hover:bg-transparent',
    1822,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v15)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:opacity-100',
    1821,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:pointer-events-none',
    1815,
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
    'data-[disabled=true]:text-foreground-disabled',
    1820,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled=true'],
        2000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-disabled=true'],
        2000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'data-[disabled=true]:touch-auto',
    1818,
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
    1816,
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
    'data-[dragging-source=true]:cursor-grabbing',
    1823,
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
    'data-[dragging=true]:will-change-transform',
    1825,
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
  RaftUtility(
    'data-[dragging=true]:z-raised',
    1824,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-dragging=true'],
        2000,
        [RaftDecl('z-index', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'data-[drop-collapsed=true]:data-[drop-state=allowed]:[outline:1.5px_dashed_var(--line-strong)]',
    1827,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-drop-collapsed=true', 'data-drop-state=allowed'],
        3000,
        [
          RaftDecl('outline-width', CssNum(1.5, 'px')),
          RaftDecl('outline-style', CssKeyword('dashed')),
          RaftDecl('outline-color', _v395),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-drop-collapsed=true', 'data-drop-state=allowed'],
        3000,
        [
          RaftDecl('outline-width', CssNum(1.5, 'px')),
          RaftDecl('outline-style', CssKeyword('dashed')),
          RaftDecl('outline-color', _v1),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[drop-collapsed=true]:data-[drop-state=allowed]:outline-offset-4',
    1828,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-drop-collapsed=true', 'data-drop-state=allowed'],
        3000,
        [RaftDecl('outline-offset', CssNum(4, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[drop-state=allowed]:block',
    1826,
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
    'data-[emphasis=strong]:font-bold',
    1829,
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
    'data-[exit=finish]:duration-150',
    1831,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-exit=finish'],
        2000,
        [
          RaftDecl('--tw-duration', CssNum(150, 'ms')),
          RaftDecl('transition-duration', CssNum(150, 'ms')),
        ],
      ),
    ],
  ),
  RaftUtility('data-[exit=finish]:ease-out', 1832, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-exit=finish'],
      2000,
      [
        RaftDecl('--tw-ease', _v123),
        RaftDecl('transition-timing-function', _v123),
      ],
    ),
  ]),
  RaftUtility('data-[exit=finish]:scale-0', 1830, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-exit=finish'],
      2000,
      [
        RaftDecl('--tw-scale-x', CssNum(0, '%')),
        RaftDecl('--tw-scale-y', CssNum(0, '%')),
        RaftDecl('--tw-scale-z', CssNum(0, '%')),
        RaftDecl('scale', _v427),
      ],
    ),
  ]),
  RaftUtility(
    'data-[fit=contain]:object-contain',
    1833,
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
    1834,
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
  RaftUtility('data-[glyph=icon]:px-0', 1835, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-glyph=icon'],
      2000,
      [
        RaftDecl('padding-left', CssNum(0, 'px')),
        RaftDecl('padding-right', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'data-[highlighted=true]:bg-brand-soft',
    1836,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-highlighted=true'],
        2000,
        [RaftDecl('background-color', _v275)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-highlighted=true'],
        2000,
        [RaftDecl('background-color', _v276)],
      ),
    ],
  ),
  RaftUtility(
    'data-[icon-kind=avatar]:bg-transparent',
    1839,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-icon-kind=avatar'],
        2000,
        [RaftDecl('background-color', _v15)],
      ),
    ],
  ),
  RaftUtility(
    'data-[icon-kind=avatar]:border-transparent',
    1838,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-icon-kind=avatar'],
        2000,
        [
          RaftDecl('border-top-color', _v15),
          RaftDecl('border-right-color', _v15),
          RaftDecl('border-bottom-color', _v15),
          RaftDecl('border-left-color', _v15),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[icon-kind=avatar]:size-auto',
    1837,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-icon-kind=avatar'],
        2000,
        [
          RaftDecl('width', CssKeyword('auto')),
          RaftDecl('height', CssKeyword('auto')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[indeterminate]:inset-y-0',
    1840,
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
    'data-[interactive=true]:active:overlay-medium',
    1843,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-interactive=true'],
        3000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['active', 'dark', 'data-interactive=true'],
        3000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    'data-[interactive=true]:cursor-pointer',
    1841,
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
    'data-[interactive=true]:hover:overlay-subtle',
    1842,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-interactive=true', 'hover'],
        3000,
        [RaftDecl('background-image', _v237)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-interactive=true', 'hover'],
        3000,
        [RaftDecl('background-image', _v238)],
      ),
    ],
  ),
  RaftUtility(
    'data-[layout=grid]:grid-cols-3',
    1845,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-layout=grid'],
        2000,
        [RaftDecl('grid-template-columns', _v428)],
      ),
    ],
  ),
  RaftUtility(
    'data-[layout=grid]:grid-flow-row',
    1844,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-layout=grid'],
        2000,
        [RaftDecl('grid-auto-flow', CssKeyword('row'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[loading=true]:cursor-wait',
    1847,
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
    1846,
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
    1848,
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
    'data-[orientation=horizontal]:-mb-3',
    1850,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal'],
        2000,
        [RaftDecl('margin-bottom', CssNum(-12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:before:-top-px',
    1857,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-orientation=horizontal'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:before:h-px',
    1859,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-orientation=horizontal'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('height', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:before:left-0',
    1858,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-orientation=horizontal'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:before:w-full',
    1860,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-orientation=horizontal'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('width', CssNum(100, '%')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:cursor-ns-resize',
    1854,
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
    'data-[orientation=horizontal]:flex-row',
    1855,
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
    1856,
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
    'data-[orientation=horizontal]:focus-visible:keyboard:before:h-0.5',
    2361,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        [
          'data-orientation=horizontal',
          'focus-visible',
          'not:in:root+data-input-modality=pointer',
        ],
        3001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('height', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[orientation=horizontal]:h-3',
    1851,
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
    1852,
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
    'data-[orientation=horizontal]:mr-0',
    1849,
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
    1853,
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
    'data-[orientation=vertical]:flex-col',
    1862,
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
    1863,
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
    'data-[orientation=vertical]:self-stretch',
    1864,
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
    'data-[orientation=vertical]:w-px',
    1861,
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
  RaftUtility('data-[panel-open]:mb-2', 1865, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-panel-open'],
      2000,
      [RaftDecl('margin-bottom', CssNum(8, 'px'))],
    ),
  ]),
  RaftUtility(
    'data-[reorderable=true]:cursor-pointer',
    1866,
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
    'data-[selected=true]:[&_svg]:text-sticker-ink',
    2470,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& svg',
        ['data-selected=true'],
        2001,
        [RaftDecl('color', _v143)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:active:before:overlay-sticker-medium',
    1882,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['active', 'data-selected=true'],
        3001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-image', _v278),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:active:bg-info-soft',
    1881,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-selected=true'],
        3000,
        [RaftDecl('background-color', _v311)],
      ),
      RaftLayer(
        'self',
        ['active', 'dark', 'data-selected=true'],
        3000,
        [RaftDecl('background-color', _v312)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:bg-brand-soft',
    1876,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v275),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'data-selected=true'],
        2001,
        [RaftDecl('background-color', _v276)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:bg-selected',
    1877,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v310),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:border-sticker-ink',
    1875,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('border-top-color', _v143),
          RaftDecl('border-right-color', _v143),
          RaftDecl('border-bottom-color', _v143),
          RaftDecl('border-left-color', _v143),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:ring-[1.5px]',
    1878,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-ring-shadow', _v145),
          RaftDecl('box-shadow', _v27),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:before:ring-sticker-edge',
    1879,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-ring-color', _v146),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'data-selected=true'],
        2001,
        [RaftDecl('--tw-ring-color', _v147)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:bg-info-soft',
    1868,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('background-color', _v311)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-selected=true'],
        2000,
        [RaftDecl('background-color', _v312)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:bg-layer-frame-active',
    1869,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('background-color', _v33)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-selected=true'],
        2000,
        [RaftDecl('background-color', _v34)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:border-line-frame-active',
    1867,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [
          RaftDecl('border-top-color', _v35),
          RaftDecl('border-right-color', _v35),
          RaftDecl('border-bottom-color', _v35),
          RaftDecl('border-left-color', _v35),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:font-bold',
    1870,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [
          RaftDecl('--tw-font-weight', CssNum(700)),
          RaftDecl('font-weight', CssNum(700)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:hover:bg-info-soft',
    1880,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v311)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-selected=true', 'hover'],
        3000,
        [RaftDecl('background-color', _v312)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:ring-[1.5px]',
    1873,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('--tw-ring-shadow', _v145), RaftDecl('box-shadow', _v27)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:ring-sticker-edge',
    1874,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('--tw-ring-color', _v146)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-selected=true'],
        2000,
        [RaftDecl('--tw-ring-color', _v147)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:text-foreground',
    1871,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-selected=true'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer(
        'self',
        ['dark', 'data-selected=true'],
        2000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'data-[selected=true]:text-foreground-on-frame-active',
    1872,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-selected=true'],
        2000,
        [RaftDecl('color', _v36)],
      ),
    ],
  ),
  RaftUtility(
    'data-[separator=active]:before:bg-foreground-muted',
    1883,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-separator=active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v2),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'data-separator=active'],
        2001,
        [RaftDecl('background-color', _v3)],
      ),
    ],
  ),
  RaftUtility(
    'data-[side=bottom]:rotate-180',
    1885,
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
    1884,
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
    1886,
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
    1887,
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
    1888,
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
    1891,
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
    1889,
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
    1890,
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
  RaftUtility('data-[side=left]:-rotate-90', 1894, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-side=left'],
      2000,
      [RaftDecl('rotate', CssNum(-90, 'deg'))],
    ),
  ]),
  RaftUtility(
    'data-[side=left]:right-[-7px]',
    1892,
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
    1893,
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
    1895,
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
    1896,
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
  RaftUtility('data-[side=right]:rotate-90', 1897, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-side=right'],
      2000,
      [RaftDecl('rotate', CssNum(90, 'deg'))],
    ),
  ]),
  RaftUtility(
    'data-[side=top]:bottom-[-5px]',
    1898,
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
    'data-[size=lg]:rounded-(--control-radius)',
    1899,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-size=lg'],
        2000,
        [
          RaftDecl('border-top-left-radius', _v429),
          RaftDecl('border-top-right-radius', _v429),
          RaftDecl('border-bottom-right-radius', _v429),
          RaftDecl('border-bottom-left-radius', _v429),
        ],
      ),
      RaftLayer(
        'self',
        ['data-size=lg', 'pointer-fine', 'width>=768'],
        2000,
        [
          RaftDecl('border-top-left-radius', CssNum(8, 'px')),
          RaftDecl('border-top-right-radius', CssNum(8, 'px')),
          RaftDecl('border-bottom-right-radius', CssNum(8, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(8, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[slot=sidebar-item-count]:px-1.5',
    2029,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-slot=sidebar-item-count'],
        2000,
        [
          RaftDecl('padding-left', CssNum(6, 'px')),
          RaftDecl('padding-right', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[sorting=true]:overflow-x-hidden',
    2056,
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
    2057,
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
    2059,
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
    2058,
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
          RaftDecl('scale', _v427),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=copied]:**:data-[icon=copy]:blur-[1px]',
    2062,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="copy"]',
        ['data-state=copied'],
        3000,
        [RaftDecl('--tw-blur', _v430), RaftDecl('filter', _v440)],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=copied]:**:data-[icon=copy]:opacity-0',
    2061,
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
    2060,
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
    2066,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-icon="check"]',
        ['data-state=idle'],
        3000,
        [RaftDecl('--tw-blur', _v430), RaftDecl('filter', _v440)],
      ),
    ],
  ),
  RaftUtility(
    'data-[state=idle]:**:data-[icon=check]:opacity-0',
    2065,
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
    2064,
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
    2068,
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
    2067,
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
          RaftDecl('scale', _v427),
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
  RaftUtility('data-[state=idle]:opacity-0', 2063, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-state=idle'],
      2000,
      [RaftDecl('opacity', CssNum(0, '%'))],
    ),
  ]),
  RaftUtility(
    'data-[state=pulling]:transition-none',
    2069,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-state=pulling'],
        2000,
        [RaftDecl('transition-property', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-[variant=block]:bg-fill-muted',
    2083,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=block'],
        2000,
        [RaftDecl('background-color', _v220)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-variant=block'],
        2000,
        [RaftDecl('background-color', _v221)],
      ),
    ],
  ),
  RaftUtility(
    'data-[variant=block]:rounded-sticker',
    2082,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=block'],
        2000,
        [
          RaftDecl('border-top-left-radius', CssNum(4, 'px')),
          RaftDecl('border-top-right-radius', CssNum(4, 'px')),
          RaftDecl('border-bottom-right-radius', CssNum(4, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(4, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-[variant=line]:bg-fill-muted',
    2088,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=line'],
        2000,
        [RaftDecl('background-color', _v220)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-variant=line'],
        2000,
        [RaftDecl('background-color', _v221)],
      ),
    ],
  ),
  RaftUtility(
    'data-[variant=line]:rounded-sticker',
    2087,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-variant=line'],
        2000,
        [
          RaftDecl('border-top-left-radius', CssNum(4, 'px')),
          RaftDecl('border-top-right-radius', CssNum(4, 'px')),
          RaftDecl('border-bottom-right-radius', CssNum(4, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(4, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('data-[x=left]:left-0', 2089, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-x=left'],
      2000,
      [RaftDecl('left', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('data-[x=right]:right-0', 2090, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-x=right'],
      2000,
      [RaftDecl('right', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('data-[y=bottom]:bottom-0', 2091, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-y=bottom'],
      2000,
      [RaftDecl('bottom', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('data-[y=top]:top-0', 2092, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-y=top'], 2000, [RaftDecl('top', CssNum(0, 'px'))]),
  ]),
  RaftUtility(
    'data-active:active:before:overlay-sticker-medium',
    1621,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['active', 'data-active'],
        3001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-image', _v278),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-active:active:overlay-sticker-medium',
    1620,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-active'],
        3000,
        [RaftDecl('background-image', _v278)],
      ),
    ],
  ),
  RaftUtility(
    'data-active:before:bg-selected',
    1615,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v310),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-active:before:inset-ring-[1.5px]',
    1617,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-inset-ring-shadow', _v142),
          RaftDecl('box-shadow', _v27),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-active:before:inset-ring-sticker-ink',
    1619,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-inset-ring-color', _v143),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-active:before:ring-[1.5px]',
    1616,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-ring-shadow', _v145),
          RaftDecl('box-shadow', _v27),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-active:before:ring-sticker-edge',
    1618,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-active'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-ring-color', _v146),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'data-active'],
        2001,
        [RaftDecl('--tw-ring-color', _v147)],
      ),
    ],
  ),
  RaftUtility('data-active:bg-brand-soft', 1600, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('background-color', _v275)],
    ),
    RaftLayer(
      'self',
      ['dark', 'data-active'],
      2000,
      [RaftDecl('background-color', _v276)],
    ),
  ]),
  RaftUtility('data-active:bg-selected', 1601, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('background-color', _v310)],
    ),
  ]),
  RaftUtility('data-active:border-[1.5px]', 1596, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [
        RaftDecl('border-top-style', _v16),
        RaftDecl('border-right-style', _v16),
        RaftDecl('border-bottom-style', _v16),
        RaftDecl('border-left-style', _v16),
        RaftDecl('border-top-width', CssNum(1.5, 'px')),
        RaftDecl('border-right-width', CssNum(1.5, 'px')),
        RaftDecl('border-bottom-width', CssNum(1.5, 'px')),
        RaftDecl('border-left-width', CssNum(1.5, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'data-active:border-line-strong',
    1597,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [
          RaftDecl('border-top-color', _v395),
          RaftDecl('border-right-color', _v395),
          RaftDecl('border-bottom-color', _v395),
          RaftDecl('border-left-color', _v395),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-active'],
        2000,
        [
          RaftDecl('border-top-color', _v1),
          RaftDecl('border-right-color', _v1),
          RaftDecl('border-bottom-color', _v1),
          RaftDecl('border-left-color', _v1),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-active:border-sticker-ink',
    1598,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [
          RaftDecl('border-top-color', _v143),
          RaftDecl('border-right-color', _v143),
          RaftDecl('border-bottom-color', _v143),
          RaftDecl('border-left-color', _v143),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-active:border-sticker-paper',
    1599,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [
          RaftDecl('border-top-color', _v380),
          RaftDecl('border-right-color', _v380),
          RaftDecl('border-bottom-color', _v380),
          RaftDecl('border-left-color', _v380),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-active:focus-visible:keyboard:before:shadow-[inset_0_0_0_3.5px_var(--foreground)]',
    2360,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        [
          'data-active',
          'focus-visible',
          'not:in:root+data-input-modality=pointer',
        ],
        3001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-shadow', _v442),
          RaftDecl('box-shadow', _v27),
        ],
      ),
      RaftLayer(
        '::before',
        [
          'dark',
          'data-active',
          'focus-visible',
          'not:in:root+data-input-modality=pointer',
        ],
        3001,
        [RaftDecl('--tw-shadow', _v444)],
      ),
    ],
  ),
  RaftUtility('data-active:font-bold', 1605, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [
        RaftDecl('--tw-font-weight', CssNum(700)),
        RaftDecl('font-weight', CssNum(700)),
      ],
    ),
  ]),
  RaftUtility('data-active:p-[11.5px]', 1602, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [
        RaftDecl('padding-top', CssNum(11.5, 'px')),
        RaftDecl('padding-right', CssNum(11.5, 'px')),
        RaftDecl('padding-bottom', CssNum(11.5, 'px')),
        RaftDecl('padding-left', CssNum(11.5, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-active:pe-[5.5px]', 1604, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('padding-right', CssNum(5.5, 'px'))],
    ),
  ]),
  RaftUtility('data-active:ps-[2.5px]', 1603, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('padding-left', CssNum(2.5, 'px'))],
    ),
  ]),
  RaftUtility('data-active:ring-[1.5px]', 1613, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v145), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'data-active:ring-sticker-edge',
    1614,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [RaftDecl('--tw-ring-color', _v146)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-active'],
        2000,
        [RaftDecl('--tw-ring-color', _v147)],
      ),
    ],
  ),
  RaftUtility(
    'data-active:shadow-[inset_-2px_0_0_var(--foreground)]',
    1608,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [RaftDecl('--tw-shadow', _v445), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-active'],
        2000,
        [RaftDecl('--tw-shadow', _v446)],
      ),
    ],
  ),
  RaftUtility(
    'data-active:shadow-[inset_0_-2px_0_var(--foreground)]',
    1609,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [RaftDecl('--tw-shadow', _v447), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-active'],
        2000,
        [RaftDecl('--tw-shadow', _v448)],
      ),
    ],
  ),
  RaftUtility(
    'data-active:shadow-[inset_0_2px_0_var(--foreground)]',
    1610,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [RaftDecl('--tw-shadow', _v449), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-active'],
        2000,
        [RaftDecl('--tw-shadow', _v450)],
      ),
    ],
  ),
  RaftUtility(
    'data-active:shadow-[inset_2px_0_0_var(--foreground)]',
    1611,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-active'],
        2000,
        [RaftDecl('--tw-shadow', _v451), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-active'],
        2000,
        [RaftDecl('--tw-shadow', _v452)],
      ),
    ],
  ),
  RaftUtility('data-active:shadow-float', 1612, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-active'],
      2000,
      [RaftDecl('--tw-shadow', _v453), RaftDecl('box-shadow', _v27)],
    ),
    RaftLayer(
      'self',
      ['dark', 'data-active'],
      2000,
      [
        RaftDecl('--tw-shadow', CssList([_v455, _v457])),
      ],
    ),
  ]),
  RaftUtility('data-active:text-foreground', 1606, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-active'], 2000, [RaftDecl('color', _v0)]),
    RaftLayer('self', ['dark', 'data-active'], 2000, [RaftDecl('color', _v1)]),
  ]),
  RaftUtility(
    'data-active:text-sticker-ink',
    1607,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-active'], 2000, [RaftDecl('color', _v143)]),
    ],
  ),
  RaftUtility('data-active:z-raised', 1595, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-active'], 2000, [RaftDecl('z-index', CssNum(1))]),
  ]),
  RaftUtility('data-animate:duration-150', 1624, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-animate'],
      2000,
      [
        RaftDecl('--tw-duration', CssNum(150, 'ms')),
        RaftDecl('transition-duration', CssNum(150, 'ms')),
      ],
    ),
  ]),
  RaftUtility('data-animate:ease-out', 1625, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-animate'],
      2000,
      [
        RaftDecl('--tw-ease', _v123),
        RaftDecl('transition-timing-function', _v123),
      ],
    ),
  ]),
  RaftUtility(
    'data-animate:transition-transform',
    1623,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-animate'],
        2000,
        [
          RaftDecl('transition-property', _v45),
          RaftDecl('transition-timing-function', _v11),
          RaftDecl('transition-duration', _v12),
        ],
      ),
    ],
  ),
  RaftUtility('data-armed:opacity-100', 1626, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-armed'],
      2000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility(
    'data-checked:active:bg-selected',
    1639,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-checked'],
        3000,
        [RaftDecl('background-color', _v310)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:active:overlay-sticker-medium',
    1640,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-checked'],
        3000,
        [RaftDecl('background-image', _v278)],
      ),
    ],
  ),
  RaftUtility('data-checked:bg-selected', 1629, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-checked'],
      2000,
      [RaftDecl('background-color', _v310)],
    ),
  ]),
  RaftUtility(
    'data-checked:bg-sticker-paper',
    1630,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [RaftDecl('background-color', _v380)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:border-sticker-ink',
    1628,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [
          RaftDecl('border-top-color', _v143),
          RaftDecl('border-right-color', _v143),
          RaftDecl('border-bottom-color', _v143),
          RaftDecl('border-left-color', _v143),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:data-disabled:bg-fill-muted',
    1654,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'data-disabled'],
        3000,
        [RaftDecl('background-color', _v220)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-checked', 'data-disabled'],
        3000,
        [RaftDecl('background-color', _v221)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:data-disabled:border-foreground-disabled',
    1653,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'data-disabled'],
        3000,
        [
          RaftDecl('border-top-color', _v306),
          RaftDecl('border-right-color', _v306),
          RaftDecl('border-bottom-color', _v306),
          RaftDecl('border-left-color', _v306),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-checked', 'data-disabled'],
        3000,
        [
          RaftDecl('border-top-color', _v307),
          RaftDecl('border-right-color', _v307),
          RaftDecl('border-bottom-color', _v307),
          RaftDecl('border-left-color', _v307),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:data-disabled:shadow-[0_0_0_1.5px_var(--foreground-disabled)]',
    1655,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'data-disabled'],
        3000,
        [RaftDecl('--tw-shadow', _v459), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-checked', 'data-disabled'],
        3000,
        [RaftDecl('--tw-shadow', _v461)],
      ),
    ],
  ),
  RaftUtility('data-checked:font-bold', 1631, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-checked'],
      2000,
      [
        RaftDecl('--tw-font-weight', CssNum(700)),
        RaftDecl('font-weight', CssNum(700)),
      ],
    ),
  ]),
  RaftUtility(
    'data-checked:hover:bg-selected',
    1637,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'hover'],
        3000,
        [RaftDecl('background-color', _v310)],
      ),
    ],
  ),
  RaftUtility('data-checked:ring-[1.5px]', 1635, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-checked'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v145), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'data-checked:ring-sticker-edge',
    1636,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [RaftDecl('--tw-ring-color', _v146)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-checked'],
        2000,
        [RaftDecl('--tw-ring-color', _v147)],
      ),
    ],
  ),
  RaftUtility(
    'data-checked:shadow-[0_0_0_1.5px_var(--sticker-ink)]',
    1633,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [RaftDecl('--tw-shadow', _v463), RaftDecl('box-shadow', _v27)],
      ),
    ],
  ),
  RaftUtility('data-checked:shadow-none', 1634, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-checked'],
      2000,
      [RaftDecl('--tw-shadow', _v28), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'data-checked:text-sticker-ink',
    1632,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-checked'], 2000, [RaftDecl('color', _v143)]),
    ],
  ),
  RaftUtility(
    'data-checked:translate-x-[calc(var(--switch-width)-var(--switch-height))]',
    1627,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked'],
        2000,
        [
          RaftDecl('--tw-translate-x', _v465),
          RaftDecl('translate', CssSeq([_v84, _v85])),
        ],
      ),
      RaftLayer(
        'self',
        ['data-checked', 'pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('--tw-translate-x', CssNum(16, 'px'))],
      ),
    ],
  ),
  RaftUtility('data-closed:hidden', 1641, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-closed'],
      2000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility(
    'data-complete:[--progress-indicator:var(--success)]',
    1642,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-complete'],
        2000,
        [RaftDecl('--progress-indicator', _v218)],
      ),
    ],
  ),
  RaftUtility(
    'data-deleted:*:data-[slot=avatar]:grayscale',
    1916,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="avatar"]',
        ['data-deleted'],
        3000,
        [RaftDecl('--tw-grayscale', _v466), RaftDecl('filter', _v440)],
      ),
    ],
  ),
  RaftUtility(
    'data-deleted:*:data-[slot=avatar]:opacity-dimmed',
    1915,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="avatar"]',
        ['data-deleted'],
        3000,
        [RaftDecl('opacity', _v426)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:**:data-[slot=\'select-icon\']:text-foreground-disabled',
    1906,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot=\'select-icon\']',
        ['data-disabled'],
        3000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        ':is(& *)[data-slot=\'select-icon\']',
        ['dark', 'data-disabled'],
        3000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:**:data-picker-trigger-indicator:text-foreground-disabled',
    1737,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-picker-trigger-indicator]',
        ['data-disabled'],
        3000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        ':is(& *)[data-picker-trigger-indicator]',
        ['dark', 'data-disabled'],
        3000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:[&>label]:cursor-not-allowed',
    2556,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > label',
        ['data-disabled'],
        2001,
        [RaftDecl('cursor', _v308)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:[&>label]:text-foreground-disabled',
    2557,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > label',
        ['data-disabled'],
        2001,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        '& > label',
        ['dark', 'data-disabled'],
        2001,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:[&>label_*]:text-foreground-disabled',
    2558,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > label *',
        ['data-disabled'],
        2001,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        '& > label *',
        ['dark', 'data-disabled'],
        2001,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:[&>svg]:text-foreground-disabled',
    2606,
    RaftUtilityStatus.descendant,
    [
      RaftLayer('& > svg', ['data-disabled'], 2001, [RaftDecl('color', _v306)]),
      RaftLayer(
        '& > svg',
        ['dark', 'data-disabled'],
        2001,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility('data-disabled:bg-fill-muted', 1647, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-disabled'],
      2000,
      [RaftDecl('background-color', _v220)],
    ),
    RaftLayer(
      'self',
      ['dark', 'data-disabled'],
      2000,
      [RaftDecl('background-color', _v221)],
    ),
  ]),
  RaftUtility(
    'data-disabled:bg-transparent',
    1648,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [RaftDecl('background-color', _v15)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:border-foreground-disabled',
    1646,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [
          RaftDecl('border-top-color', _v306),
          RaftDecl('border-right-color', _v306),
          RaftDecl('border-bottom-color', _v306),
          RaftDecl('border-left-color', _v306),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-disabled'],
        2000,
        [
          RaftDecl('border-top-color', _v307),
          RaftDecl('border-right-color', _v307),
          RaftDecl('border-bottom-color', _v307),
          RaftDecl('border-left-color', _v307),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:cursor-not-allowed',
    1645,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-disabled'], 2000, [RaftDecl('cursor', _v308)]),
    ],
  ),
  RaftUtility(
    'data-disabled:data-placeholder:text-foreground-disabled',
    1742,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled', 'data-placeholder'],
        3000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-disabled', 'data-placeholder'],
        3000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:hover:bg-transparent',
    1652,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled', 'hover'],
        3000,
        [RaftDecl('background-color', _v15)],
      ),
    ],
  ),
  RaftUtility('data-disabled:opacity-100', 1650, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-disabled'],
      2000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility(
    'data-disabled:pointer-events-none',
    1643,
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
    'data-disabled:shadow-[0_0_0_1.5px_var(--foreground-disabled)]',
    1651,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-disabled'],
        2000,
        [RaftDecl('--tw-shadow', _v459), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-disabled'],
        2000,
        [RaftDecl('--tw-shadow', _v461)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:text-foreground-disabled',
    1649,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-disabled'], 2000, [RaftDecl('color', _v306)]),
      RaftLayer(
        'self',
        ['dark', 'data-disabled'],
        2000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'data-disabled:transform-none',
    1644,
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
    1664,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [RaftDecl('--tw-blur', _v467), RaftDecl('filter', _v440)],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:data-[swipe-direction=down]:transform-[translateY(calc(var(--toast-swipe-movement-y)+120%))]',
    2070,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style', 'data-swipe-direction=down'],
        3000,
        [RaftDecl('transform', _v469)],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:data-[swipe-direction=left]:transform-[translateX(calc(var(--toast-swipe-movement-x)-120%))_translateY(var(--toast-y))]',
    2071,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style', 'data-swipe-direction=left'],
        3000,
        [
          RaftDecl('transform', CssSeq([_v472, _v473])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:data-[swipe-direction=right]:transform-[translateX(calc(var(--toast-swipe-movement-x)+120%))_translateY(var(--toast-y))]',
    2072,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style', 'data-swipe-direction=right'],
        3000,
        [
          RaftDecl('transform', CssSeq([_v475, _v473])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:data-[swipe-direction=up]:transform-[translateY(calc(var(--toast-swipe-movement-y)-120%))]',
    2073,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style', 'data-swipe-direction=up'],
        3000,
        [RaftDecl('transform', _v477)],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:duration-150',
    1665,
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
    'data-ending-style:duration-180',
    1666,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [
          RaftDecl('--tw-duration', CssNum(180, 'ms')),
          RaftDecl('transition-duration', CssNum(180, 'ms')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:duration-[calc(var(--drawer-swipe-strength,1)*180ms)]',
    1667,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [
          RaftDecl('--tw-duration', CssCalc(_v479)),
          RaftDecl('transition-duration', CssCalc(_v479)),
        ],
      ),
    ],
  ),
  RaftUtility('data-ending-style:h-0', 1658, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-ending-style'],
      2000,
      [RaftDecl('height', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('data-ending-style:hidden', 1657, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-ending-style'],
      2000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('data-ending-style:opacity-0', 1663, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-ending-style'],
      2000,
      [RaftDecl('opacity', CssNum(0, '%'))],
    ),
  ]),
  RaftUtility(
    'data-ending-style:pointer-events-none',
    1656,
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
    1660,
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
    1661,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [RaftDecl('transform', _v480)],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:transform-[scale(0.99)]',
    1662,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [RaftDecl('transform', _v481)],
      ),
    ],
  ),
  RaftUtility(
    'data-ending-style:translate-y-full',
    1659,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-ending-style'],
        2000,
        [
          RaftDecl('--tw-translate-y', CssNum(100, '%')),
          RaftDecl('translate', CssSeq([_v84, _v85])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-expanded:h-(--toast-height)',
    1668,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-expanded'], 2000, [RaftDecl('height', _v229)]),
    ],
  ),
  RaftUtility(
    'data-expanded:transform-[translateX(var(--toast-swipe-movement-x))_translateY(var(--toast-y))_scale(1)]',
    1669,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-expanded'],
        2000,
        [RaftDecl('transform', _v484)],
      ),
    ],
  ),
  RaftUtility(
    'data-fit-label:**:data-[slot=segmented-control-count]:sr-only',
    2000,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-count"]',
        ['data-fit-label'],
        3000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-fit-label:**:data-[slot=segmented-control-item]:px-0',
    2016,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['data-fit-label'],
        3000,
        [
          RaftDecl('padding-left', CssNum(0, 'px')),
          RaftDecl('padding-right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-fit-label:**:data-[slot=segmented-control-item]:relative',
    2014,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['data-fit-label'],
        3000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    'data-fit-label:**:data-[slot=segmented-control-item]:w-(--segment-size)',
    2015,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['data-fit-label'],
        3000,
        [RaftDecl('width', _v89)],
      ),
    ],
  ),
  RaftUtility(
    'data-fit-label:**:data-[slot=segmented-control-label]:sr-only',
    2020,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-label"]',
        ['data-fit-label'],
        3000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility('data-fit-label:gap-1', 1672, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-label'],
      2000,
      [
        RaftDecl('row-gap', CssNum(4, 'px')),
        RaftDecl('column-gap', CssNum(4, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-fit-label:px-0', 1673, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-label'],
      2000,
      [
        RaftDecl('padding-left', CssNum(0, 'px')),
        RaftDecl('padding-right', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-fit-label:px-2', 1674, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-label'],
      2000,
      [
        RaftDecl('padding-left', CssNum(8, 'px')),
        RaftDecl('padding-right', CssNum(8, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-fit-label:sr-only', 1670, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-label'],
      2000,
      [
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
        RaftDecl('clip-path', _v88),
        RaftDecl('white-space', CssKeyword('nowrap')),
        RaftDecl('border-top-width', CssNum(0)),
        RaftDecl('border-right-width', CssNum(0)),
        RaftDecl('border-bottom-width', CssNum(0)),
        RaftDecl('border-left-width', CssNum(0)),
      ],
    ),
  ]),
  RaftUtility('data-fit-label:w-8', 1671, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-label'],
      2000,
      [RaftDecl('width', CssNum(32, 'px'))],
    ),
  ]),
  RaftUtility('data-fit-more:hidden', 1675, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-more'],
      2000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('data-fit-plus:px-0', 1677, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-plus'],
      2000,
      [
        RaftDecl('padding-left', CssNum(0, 'px')),
        RaftDecl('padding-right', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('data-fit-plus:w-8', 1676, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-plus'],
      2000,
      [RaftDecl('width', CssNum(32, 'px'))],
    ),
  ]),
  RaftUtility(
    'data-fit-search:[--fit-scroll-basis:auto]',
    1679,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-fit-search'],
        2000,
        [RaftDecl('--fit-scroll-basis', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'data-fit-search:[--fit-scroll-grow:0]',
    1680,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-fit-search'],
        2000,
        [RaftDecl('--fit-scroll-grow', CssNum(0))],
      ),
    ],
  ),
  RaftUtility('data-fit-search:relative', 1678, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-search'],
      2000,
      [RaftDecl('position', CssKeyword('relative'))],
    ),
  ]),
  RaftUtility('data-fit-shown:inline-flex', 1681, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-fit-shown'], 2000, [RaftDecl('display', _v46)]),
  ]),
  RaftUtility('data-fit-wrap:grow', 1683, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-wrap'],
      2000,
      [RaftDecl('flex-grow', CssNum(1))],
    ),
  ]),
  RaftUtility(
    'data-fit-wrap:mt-(--fit-gap)',
    1682,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-fit-wrap'],
        2000,
        [RaftDecl('margin-top', CssVar('--fit-gap'))],
      ),
    ],
  ),
  RaftUtility('data-fit-wrapping:flex-wrap', 1684, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-wrapping'],
      2000,
      [RaftDecl('flex-wrap', CssKeyword('wrap'))],
    ),
  ]),
  RaftUtility('data-fit-wrapping:gap-y-0', 1685, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-fit-wrapping'],
      2000,
      [RaftDecl('row-gap', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility(
    'data-has-actions:grid-cols-[minmax(0,1fr)_auto]',
    1686,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-has-actions'],
        2000,
        [RaftDecl('grid-template-columns', _v485)],
      ),
    ],
  ),
  RaftUtility(
    'data-has-icon:grid-cols-[auto_minmax(0,1fr)]',
    1687,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-has-icon'],
        2000,
        [RaftDecl('grid-template-columns', _v486)],
      ),
    ],
  ),
  RaftUtility(
    'data-has-value:active:overlay-medium',
    1693,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-has-value'],
        3000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['active', 'dark', 'data-has-value'],
        3000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility('data-has-value:bg-info-soft', 1688, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-has-value'],
      2000,
      [RaftDecl('background-color', _v311)],
    ),
    RaftLayer(
      'self',
      ['dark', 'data-has-value'],
      2000,
      [RaftDecl('background-color', _v312)],
    ),
  ]),
  RaftUtility(
    'data-has-value:hover:bg-info-soft',
    1691,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-has-value', 'hover'],
        3000,
        [RaftDecl('background-color', _v311)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-has-value', 'hover'],
        3000,
        [RaftDecl('background-color', _v312)],
      ),
    ],
  ),
  RaftUtility(
    'data-has-value:hover:overlay-medium',
    1692,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-has-value', 'hover'],
        3000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-has-value', 'hover'],
        3000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility('data-has-value:inset-ring-0', 1690, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-has-value'],
      2000,
      [RaftDecl('--tw-inset-ring-shadow', _v309), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'data-has-value:text-foreground',
    1689,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-has-value'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer(
        'self',
        ['dark', 'data-has-value'],
        2000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility('data-hidden:hidden', 1694, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-hidden'],
      2000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility(
    'data-highlighted:bg-brand-soft',
    1695,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-highlighted'],
        2000,
        [RaftDecl('background-color', _v275)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-highlighted'],
        2000,
        [RaftDecl('background-color', _v276)],
      ),
    ],
  ),
  RaftUtility(
    'data-icons-only:**:data-[slot=segmented-control-count]:sr-only',
    2001,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-count"]',
        ['data-icons-only'],
        3000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-icons-only:**:data-[slot=segmented-control-item]:px-0',
    2019,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['data-icons-only'],
        3000,
        [
          RaftDecl('padding-left', CssNum(0, 'px')),
          RaftDecl('padding-right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-icons-only:**:data-[slot=segmented-control-item]:relative',
    2017,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['data-icons-only'],
        3000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    'data-icons-only:**:data-[slot=segmented-control-item]:w-(--segment-size)',
    2018,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-item"]',
        ['data-icons-only'],
        3000,
        [RaftDecl('width', _v89)],
      ),
    ],
  ),
  RaftUtility(
    'data-icons-only:**:data-[slot=segmented-control-label]:sr-only',
    2021,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="segmented-control-label"]',
        ['data-icons-only'],
        3000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility('data-indeterminate:absolute', 1699, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-indeterminate'],
      2000,
      [RaftDecl('position', CssKeyword('absolute'))],
    ),
  ]),
  RaftUtility(
    'data-indeterminate:animate-[raft-progress-indeterminate_1.4s_ease-in-out_infinite]',
    1702,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('animation', _v489)],
      ),
    ],
  ),
  RaftUtility(
    'data-indeterminate:origin-left',
    1701,
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
    'data-indeterminate:shadow-none',
    1703,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate'],
        2000,
        [RaftDecl('--tw-shadow', _v28), RaftDecl('box-shadow', _v27)],
      ),
    ],
  ),
  RaftUtility('data-indeterminate:w-1/2', 1700, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-indeterminate'],
      2000,
      [RaftDecl('width', CssNum(50, '%'))],
    ),
  ]),
  RaftUtility(
    'data-instant:transition-none',
    1705,
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
    'data-invalid:**:data-[slot=kbd]:bg-danger-soft',
    1980,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="kbd"]',
        ['data-invalid'],
        3000,
        [RaftDecl('background-color', _v344)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="kbd"]',
        ['dark', 'data-invalid'],
        3000,
        [RaftDecl('background-color', _v345)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:**:data-[slot=kbd]:inset-ring-danger-strong',
    1982,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="kbd"]',
        ['data-invalid'],
        3000,
        [RaftDecl('--tw-inset-ring-color', _v392)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="kbd"]',
        ['dark', 'data-invalid'],
        3000,
        [RaftDecl('--tw-inset-ring-color', _v393)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:**:data-[slot=kbd]:text-danger-strong',
    1981,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="kbd"]',
        ['data-invalid'],
        3000,
        [RaftDecl('color', _v392)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="kbd"]',
        ['dark', 'data-invalid'],
        3000,
        [RaftDecl('color', _v393)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:border-danger-strong',
    1706,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid'],
        2000,
        [
          RaftDecl('border-top-color', _v392),
          RaftDecl('border-right-color', _v392),
          RaftDecl('border-bottom-color', _v392),
          RaftDecl('border-left-color', _v392),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-invalid'],
        2000,
        [
          RaftDecl('border-top-color', _v393),
          RaftDecl('border-right-color', _v393),
          RaftDecl('border-bottom-color', _v393),
          RaftDecl('border-left-color', _v393),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:focus-visible:border-danger-strong',
    1710,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [
          RaftDecl('border-top-color', _v392),
          RaftDecl('border-right-color', _v392),
          RaftDecl('border-bottom-color', _v392),
          RaftDecl('border-left-color', _v392),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-invalid', 'focus-visible'],
        3000,
        [
          RaftDecl('border-top-color', _v393),
          RaftDecl('border-right-color', _v393),
          RaftDecl('border-bottom-color', _v393),
          RaftDecl('border-left-color', _v393),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:focus-visible:ring-0',
    1711,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [RaftDecl('--tw-ring-shadow', _v22), RaftDecl('box-shadow', _v27)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:focus-visible:ring-[color-mix(in_oklch,var(--danger)_60%,transparent)]',
    1712,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v217)],
      ),
      RaftLayer(
        'self',
        ['data-invalid', 'focus-visible'],
        3000,
        [RaftDecl('--tw-ring-color', _v492)],
      ),
    ],
  ),
  RaftUtility(
    'data-invalid:hover:border-danger-strong',
    1709,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v392),
          RaftDecl('border-right-color', _v392),
          RaftDecl('border-bottom-color', _v392),
          RaftDecl('border-left-color', _v392),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-invalid', 'hover'],
        3000,
        [
          RaftDecl('border-top-color', _v393),
          RaftDecl('border-right-color', _v393),
          RaftDecl('border-bottom-color', _v393),
          RaftDecl('border-left-color', _v393),
        ],
      ),
    ],
  ),
  RaftUtility('data-invalid:inset-ring', 1707, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-invalid'],
      2000,
      [RaftDecl('--tw-inset-ring-shadow', _v493), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'data-invalid:inset-ring-danger-strong',
    1708,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid'],
        2000,
        [RaftDecl('--tw-inset-ring-color', _v392)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-invalid'],
        2000,
        [RaftDecl('--tw-inset-ring-color', _v393)],
      ),
    ],
  ),
  RaftUtility('data-limited:opacity-0', 1722, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-limited'],
      2000,
      [RaftDecl('opacity', CssNum(0, '%'))],
    ),
  ]),
  RaftUtility(
    'data-muted:text-foreground-hint',
    1724,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-muted'], 2000, [RaftDecl('color', _v44)]),
      RaftLayer(
        'self',
        ['dark', 'data-muted'],
        2000,
        [RaftDecl('color', _v39)],
      ),
    ],
  ),
  RaftUtility(
    'data-nested-drawer-open:h-(--drawer-frontmost-height)',
    1725,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-nested-drawer-open'],
        2000,
        [RaftDecl('height', _v494)],
      ),
    ],
  ),
  RaftUtility(
    'data-nested-drawer-open:overflow-hidden',
    1726,
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
    1727,
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
    'data-overflowing:overflow-x-auto',
    1731,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-overflowing'],
        2000,
        [RaftDecl('overflow-x', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'data-overflowing:overflow-y-hidden',
    1732,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-overflowing'],
        2000,
        [RaftDecl('overflow-y', CssKeyword('hidden'))],
      ),
    ],
  ),
  RaftUtility(
    'data-overflowing:overscroll-x-contain',
    1733,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-overflowing'],
        2000,
        [RaftDecl('overscroll-behavior-x', CssKeyword('contain'))],
      ),
    ],
  ),
  RaftUtility(
    'data-overflowing:scrollbar-none',
    1730,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-overflowing'],
        2000,
        [RaftDecl('scrollbar-width', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-panel-open:[&>svg]:rotate-180',
    2607,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['data-panel-open'],
        2001,
        [RaftDecl('rotate', CssNum(180, 'deg'))],
      ),
    ],
  ),
  RaftUtility(
    'data-panel-open:[&_svg]:rotate-90',
    2469,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& svg',
        ['data-panel-open'],
        2001,
        [RaftDecl('rotate', CssNum(90, 'deg'))],
      ),
    ],
  ),
  RaftUtility('data-placeholder:font-field', 1738, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-placeholder'],
      2000,
      [RaftDecl('--tw-font-weight', _v4), RaftDecl('font-weight', _v4)],
    ),
  ]),
  RaftUtility(
    'data-placeholder:font-medium',
    1739,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-placeholder'],
        2000,
        [
          RaftDecl('--tw-font-weight', CssNum(500)),
          RaftDecl('font-weight', CssNum(500)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-placeholder:text-foreground-hint',
    1740,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-placeholder'], 2000, [RaftDecl('color', _v44)]),
      RaftLayer(
        'self',
        ['dark', 'data-placeholder'],
        2000,
        [RaftDecl('color', _v39)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:[--mi-row-fill:var(--fill-subtle)]',
    1753,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('--mi-row-fill', _v113)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-popup-open'],
        2000,
        [RaftDecl('--mi-row-fill', _v114)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:before:bg-fill-medium',
    1756,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-popup-open'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v104),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'data-popup-open'],
        2001,
        [RaftDecl('background-color', _v105)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:bg-brand-soft',
    1745,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-color', _v275)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-popup-open'],
        2000,
        [RaftDecl('background-color', _v276)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:bg-fill-frame-medium',
    1746,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-color', _v29)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-popup-open'],
        2000,
        [RaftDecl('background-color', _v31)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:bg-fill-medium',
    1747,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-color', _v104)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-popup-open'],
        2000,
        [RaftDecl('background-color', _v105)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:border-[1.5px]',
    1743,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [
          RaftDecl('border-top-style', _v16),
          RaftDecl('border-right-style', _v16),
          RaftDecl('border-bottom-style', _v16),
          RaftDecl('border-left-style', _v16),
          RaftDecl('border-top-width', CssNum(1.5, 'px')),
          RaftDecl('border-right-width', CssNum(1.5, 'px')),
          RaftDecl('border-bottom-width', CssNum(1.5, 'px')),
          RaftDecl('border-left-width', CssNum(1.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:border-line-strong',
    1744,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [
          RaftDecl('border-top-color', _v395),
          RaftDecl('border-right-color', _v395),
          RaftDecl('border-bottom-color', _v395),
          RaftDecl('border-left-color', _v395),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-popup-open'],
        2000,
        [
          RaftDecl('border-top-color', _v1),
          RaftDecl('border-right-color', _v1),
          RaftDecl('border-bottom-color', _v1),
          RaftDecl('border-left-color', _v1),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:overlay-medium',
    1748,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-popup-open'],
        2000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    'data-popup-open:overlay-sticker-medium',
    1749,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open'],
        2000,
        [RaftDecl('background-image', _v278)],
      ),
    ],
  ),
  RaftUtility('data-popup-open:pe-[5.5px]', 1751, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-popup-open'],
      2000,
      [RaftDecl('padding-right', CssNum(5.5, 'px'))],
    ),
  ]),
  RaftUtility('data-popup-open:ps-[2.5px]', 1750, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-popup-open'],
      2000,
      [RaftDecl('padding-left', CssNum(2.5, 'px'))],
    ),
  ]),
  RaftUtility(
    'data-popup-open:text-foreground',
    1752,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-popup-open'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer(
        'self',
        ['dark', 'data-popup-open'],
        2000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:active:bg-selected',
    1767,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-pressed'],
        3000,
        [RaftDecl('background-color', _v310)],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:active:overlay-sticker-medium',
    1768,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'data-pressed'],
        3000,
        [RaftDecl('background-image', _v278)],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:bg-attention-soft',
    1760,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed'],
        2000,
        [RaftDecl('background-color', _v340)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-pressed'],
        2000,
        [RaftDecl('background-color', _v341)],
      ),
    ],
  ),
  RaftUtility('data-pressed:bg-selected', 1761, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-pressed'],
      2000,
      [RaftDecl('background-color', _v310)],
    ),
  ]),
  RaftUtility(
    'data-pressed:border-sticker-ink',
    1759,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed'],
        2000,
        [
          RaftDecl('border-top-color', _v143),
          RaftDecl('border-right-color', _v143),
          RaftDecl('border-bottom-color', _v143),
          RaftDecl('border-left-color', _v143),
        ],
      ),
    ],
  ),
  RaftUtility('data-pressed:font-bold', 1762, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-pressed'],
      2000,
      [
        RaftDecl('--tw-font-weight', CssNum(700)),
        RaftDecl('font-weight', CssNum(700)),
      ],
    ),
  ]),
  RaftUtility(
    'data-pressed:hover:bg-selected',
    1766,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed', 'hover'],
        3000,
        [RaftDecl('background-color', _v310)],
      ),
    ],
  ),
  RaftUtility('data-pressed:ring-[1.5px]', 1764, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-pressed'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v145), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'data-pressed:ring-sticker-edge',
    1765,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-pressed'],
        2000,
        [RaftDecl('--tw-ring-color', _v146)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-pressed'],
        2000,
        [RaftDecl('--tw-ring-color', _v147)],
      ),
    ],
  ),
  RaftUtility(
    'data-pressed:text-sticker-ink',
    1763,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['data-pressed'], 2000, [RaftDecl('color', _v143)]),
    ],
  ),
  RaftUtility('data-pressed:z-raised', 1758, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-pressed'], 2000, [RaftDecl('z-index', CssNum(1))]),
  ]),
  RaftUtility(
    'data-recording:bg-layer-card',
    1775,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-recording'],
        2000,
        [RaftDecl('background-color', _v362)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-recording'],
        2000,
        [RaftDecl('background-color', _v363)],
      ),
    ],
  ),
  RaftUtility(
    'data-recording:border-[1.5px]',
    1773,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-recording'],
        2000,
        [
          RaftDecl('border-top-style', _v16),
          RaftDecl('border-right-style', _v16),
          RaftDecl('border-bottom-style', _v16),
          RaftDecl('border-left-style', _v16),
          RaftDecl('border-top-width', CssNum(1.5, 'px')),
          RaftDecl('border-right-width', CssNum(1.5, 'px')),
          RaftDecl('border-bottom-width', CssNum(1.5, 'px')),
          RaftDecl('border-left-width', CssNum(1.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-recording:border-line-field',
    1774,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-recording'],
        2000,
        [
          RaftDecl('border-top-color', _v394),
          RaftDecl('border-right-color', _v394),
          RaftDecl('border-bottom-color', _v394),
          RaftDecl('border-left-color', _v394),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-recording:data-invalid:border-danger-strong',
    1778,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-invalid', 'data-recording'],
        3000,
        [
          RaftDecl('border-top-color', _v392),
          RaftDecl('border-right-color', _v392),
          RaftDecl('border-bottom-color', _v392),
          RaftDecl('border-left-color', _v392),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-invalid', 'data-recording'],
        3000,
        [
          RaftDecl('border-top-color', _v393),
          RaftDecl('border-right-color', _v393),
          RaftDecl('border-bottom-color', _v393),
          RaftDecl('border-left-color', _v393),
        ],
      ),
    ],
  ),
  RaftUtility('data-recording:h-control', 1771, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['data-recording'], 2000, [RaftDecl('height', _v206)]),
    RaftLayer(
      'self',
      ['data-recording', 'pointer-fine', 'width>=768'],
      2000,
      [RaftDecl('height', CssNum(34, 'px'))],
    ),
  ]),
  RaftUtility('data-recording:mx-0', 1769, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-recording'],
      2000,
      [
        RaftDecl('margin-left', CssNum(0, 'px')),
        RaftDecl('margin-right', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'data-recording:my-[calc((24px-var(--control-height))/2)]',
    1770,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-recording'],
        2000,
        [
          RaftDecl('margin-top', CssCalc(_v496)),
          RaftDecl('margin-bottom', CssCalc(_v496)),
        ],
      ),
      RaftLayer(
        'self',
        ['data-recording', 'pointer-fine', 'width>=768'],
        2000,
        [
          RaftDecl('margin-top', CssNum(-5, 'px')),
          RaftDecl('margin-bottom', CssNum(-5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-recording:px-[calc(--spacing(2)-1.5px)]',
    1776,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-recording'],
        2000,
        [
          RaftDecl('padding-left', CssNum(6.5, 'px')),
          RaftDecl('padding-right', CssNum(6.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('data-recording:py-0', 1777, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-recording'],
      2000,
      [
        RaftDecl('padding-top', CssNum(0, 'px')),
        RaftDecl('padding-bottom', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'data-recording:rounded-(--control-radius)',
    1772,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-recording'],
        2000,
        [
          RaftDecl('border-top-left-radius', _v429),
          RaftDecl('border-top-right-radius', _v429),
          RaftDecl('border-bottom-right-radius', _v429),
          RaftDecl('border-bottom-left-radius', _v429),
        ],
      ),
      RaftLayer(
        'self',
        ['data-recording', 'pointer-fine', 'width>=768'],
        2000,
        [
          RaftDecl('border-top-left-radius', CssNum(8, 'px')),
          RaftDecl('border-top-right-radius', CssNum(8, 'px')),
          RaftDecl('border-bottom-right-radius', CssNum(8, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(8, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-selected:**:data-[slot=\'select-item-text\']:font-bold',
    1908,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot=\'select-item-text\']',
        ['data-selected'],
        3000,
        [
          RaftDecl('--tw-font-weight', CssNum(700)),
          RaftDecl('font-weight', CssNum(700)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-selected:before:bg-fill-cell-selected',
    1781,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-selected'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v424),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'data-selected'],
        2001,
        [RaftDecl('background-color', _v425)],
      ),
    ],
  ),
  RaftUtility('data-selected:bg-info-soft', 1779, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-selected'],
      2000,
      [RaftDecl('background-color', _v311)],
    ),
    RaftLayer(
      'self',
      ['dark', 'data-selected'],
      2000,
      [RaftDecl('background-color', _v312)],
    ),
  ]),
  RaftUtility('data-selected:font-bold', 1780, RaftUtilityStatus.resolved, [
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
    'data-soft-keyboard:max-h-[calc(var(--dialog-visible-height)-env(safe-area-inset-top,0px)-var(--header-height)-16px)]',
    1784,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-soft-keyboard'],
        2000,
        [RaftDecl('max-height', CssCalc(_v499))],
      ),
    ],
  ),
  RaftUtility(
    'data-soft-keyboard:max-h-none',
    1785,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-soft-keyboard'],
        2000,
        [RaftDecl('max-height', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-soft-keyboard:top-[calc(var(--dialog-visible-top)+env(safe-area-inset-top,0px)+var(--header-height))]',
    1782,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-soft-keyboard'],
        2000,
        [RaftDecl('top', CssCalc(_v501))],
      ),
    ],
  ),
  RaftUtility('data-soft-keyboard:top-auto', 1783, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-soft-keyboard'],
      2000,
      [RaftDecl('top', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility(
    'data-soft-keyboard:translate-none',
    1787,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-soft-keyboard'],
        2000,
        [RaftDecl('translate', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'data-soft-keyboard:translate-y-0',
    1786,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-soft-keyboard'],
        2000,
        [
          RaftDecl('--tw-translate-y', CssNum(0, 'px')),
          RaftDecl('translate', CssSeq([_v84, _v85])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-stacked:*:data-[slot=button]:w-full',
    1940,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="button"]',
        ['data-stacked'],
        3000,
        [RaftDecl('width', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-stacked:[&>*>[data-slot=button]:only-child]:w-full',
    2502,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > * > [data-slot=button]:only-child',
        ['data-stacked'],
        4000,
        [RaftDecl('width', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'data-stacked:flex-col-reverse',
    1791,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-stacked'],
        2000,
        [RaftDecl('flex-direction', _v502)],
      ),
    ],
  ),
  RaftUtility('data-stacked:grid-cols-1', 1790, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-stacked'],
      2000,
      [RaftDecl('grid-template-columns', _v503)],
    ),
  ]),
  RaftUtility('data-stacked:items-stretch', 1792, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-stacked'],
      2000,
      [RaftDecl('align-items', CssKeyword('stretch'))],
    ),
  ]),
  RaftUtility('data-stacked:ms-0', 1788, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-stacked'],
      2000,
      [RaftDecl('margin-left', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('data-stacked:w-full', 1789, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-stacked'],
      2000,
      [RaftDecl('width', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility(
    'data-starting-style:blur-(--drawer-blur)',
    1800,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [RaftDecl('--tw-blur', _v467), RaftDecl('filter', _v440)],
      ),
    ],
  ),
  RaftUtility('data-starting-style:h-0', 1793, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-starting-style'],
      2000,
      [RaftDecl('height', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility(
    'data-starting-style:opacity-0',
    1799,
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
    'data-starting-style:scale-[0.97]',
    1795,
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
    1796,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [RaftDecl('transform', _v480)],
      ),
    ],
  ),
  RaftUtility(
    'data-starting-style:transform-[scale(0.97)]',
    1797,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [RaftDecl('transform', _v504)],
      ),
    ],
  ),
  RaftUtility(
    'data-starting-style:transform-[translateY(120%)_scale(0.98)]',
    1798,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [
          RaftDecl('transform', CssSeq([_v115, _v116])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-starting-style:translate-y-full',
    1794,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-starting-style'],
        2000,
        [
          RaftDecl('--tw-translate-y', CssNum(100, '%')),
          RaftDecl('translate', CssSeq([_v84, _v85])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'data-sticker-edge:ring-[1.5px]',
    1801,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-sticker-edge'],
        2000,
        [RaftDecl('--tw-ring-shadow', _v145), RaftDecl('box-shadow', _v27)],
      ),
    ],
  ),
  RaftUtility('data-swiping:duration-0', 1802, RaftUtilityStatus.resolved, [
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
    'data-tight-fold:mask-fade-b-edge',
    1803,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-tight-fold'],
        2000,
        [RaftDecl('mask-image', _v506)],
      ),
    ],
  ),
  RaftUtility('data-visible:opacity-100', 1805, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-visible'],
      2000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility(
    'data-visible:pointer-events-auto',
    1804,
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
  RaftUtility('decoration-1', 903, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-decoration-thickness', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('decoration-2', 904, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-decoration-thickness', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('decoration-[1.5px]', 905, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-decoration-thickness', CssNum(1.5, 'px')),
    ]),
  ]),
  RaftUtility('decoration-foreground', 901, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-decoration-color', _v0)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('text-decoration-color', _v1)]),
  ]),
  RaftUtility(
    'decoration-foreground-link/40',
    902,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('text-decoration-color', _v507)]),
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('text-decoration-color', _v508)],
      ),
      RaftLayer('self', [], 1000, [RaftDecl('text-decoration-color', _v510)]),
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [RaftDecl('text-decoration-color', CssColor(0x666DA7EC))],
      ),
    ],
  ),
  RaftUtility(
    'disabled:**:data-[slot=\'select-icon\']:text-foreground-disabled',
    1905,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot=\'select-icon\']',
        ['disabled'],
        3000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        ':is(& *)[data-slot=\'select-icon\']',
        ['dark', 'disabled'],
        3000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'disabled:**:data-picker-trigger-indicator:text-foreground-disabled',
    1736,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-picker-trigger-indicator]',
        ['disabled'],
        3000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        ':is(& *)[data-picker-trigger-indicator]',
        ['dark', 'disabled'],
        3000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'disabled:[&>svg:first-child]:text-foreground-disabled',
    2612,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg:first-child',
        ['disabled'],
        3001,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        '& > svg:first-child',
        ['dark', 'disabled'],
        3001,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'disabled:[--list-row-ink-2:var(--foreground-disabled)]',
    1429,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['disabled'],
        2000,
        [RaftDecl('--list-row-ink-2', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'disabled'],
        2000,
        [RaftDecl('--list-row-ink-2', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'disabled:[--list-row-ink-3:var(--foreground-disabled)]',
    1430,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['disabled'],
        2000,
        [RaftDecl('--list-row-ink-3', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'disabled'],
        2000,
        [RaftDecl('--list-row-ink-3', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'disabled:[--list-row-ink:var(--foreground-disabled)]',
    1431,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['disabled'],
        2000,
        [RaftDecl('--list-row-ink', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'disabled'],
        2000,
        [RaftDecl('--list-row-ink', _v307)],
      ),
    ],
  ),
  RaftUtility('disabled:bg-fill-muted', 1420, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('background-color', _v220)],
    ),
    RaftLayer(
      'self',
      ['dark', 'disabled'],
      2000,
      [RaftDecl('background-color', _v221)],
    ),
  ]),
  RaftUtility('disabled:bg-none', 1422, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('background-image', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('disabled:bg-transparent', 1421, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['disabled'], 2000, [RaftDecl('background-color', _v15)]),
  ]),
  RaftUtility(
    'disabled:border-line-hairline',
    1418,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['disabled'],
        2000,
        [
          RaftDecl('border-top-color', _v252),
          RaftDecl('border-right-color', _v252),
          RaftDecl('border-bottom-color', _v252),
          RaftDecl('border-left-color', _v252),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'disabled'],
        2000,
        [
          RaftDecl('border-top-color', _v253),
          RaftDecl('border-right-color', _v253),
          RaftDecl('border-bottom-color', _v253),
          RaftDecl('border-left-color', _v253),
        ],
      ),
    ],
  ),
  RaftUtility('disabled:border-transparent', 1419, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [
        RaftDecl('border-top-color', _v15),
        RaftDecl('border-right-color', _v15),
        RaftDecl('border-bottom-color', _v15),
        RaftDecl('border-left-color', _v15),
      ],
    ),
  ]),
  RaftUtility('disabled:cursor-default', 1415, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('cursor', CssKeyword('default'))],
    ),
  ]),
  RaftUtility('disabled:cursor-not-allowed', 1416, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['disabled'], 2000, [RaftDecl('cursor', _v308)]),
  ]),
  RaftUtility(
    'disabled:data-placeholder:text-foreground-disabled',
    1741,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-placeholder', 'disabled'],
        3000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-placeholder', 'disabled'],
        3000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility('disabled:inset-ring-0', 1428, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('--tw-inset-ring-shadow', _v309), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility('disabled:opacity-100', 1426, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility('disabled:opacity-40', 1424, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('opacity', CssNum(40, '%'))],
    ),
  ]),
  RaftUtility('disabled:opacity-45', 1425, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('opacity', CssNum(45, '%'))],
    ),
  ]),
  RaftUtility(
    'disabled:placeholder:text-foreground-disabled',
    1432,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::placeholder',
        ['disabled'],
        2001,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        '::placeholder',
        ['dark', 'disabled'],
        2001,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'disabled:pointer-events-none',
    1413,
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
  RaftUtility('disabled:resize-none', 1417, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('resize', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('disabled:ring-0', 1427, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v22), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'disabled:text-foreground-disabled',
    1423,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['disabled'], 2000, [RaftDecl('color', _v306)]),
      RaftLayer('self', ['dark', 'disabled'], 2000, [RaftDecl('color', _v307)]),
    ],
  ),
  RaftUtility('disabled:transform-none', 1414, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['disabled'],
      2000,
      [RaftDecl('transform', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('duration-100', 963, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(100, 'ms')),
      RaftDecl('transition-duration', CssNum(100, 'ms')),
    ]),
  ]),
  RaftUtility('duration-150', 964, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(150, 'ms')),
      RaftDecl('transition-duration', CssNum(150, 'ms')),
    ]),
  ]),
  RaftUtility('duration-200', 965, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(200, 'ms')),
      RaftDecl('transition-duration', CssNum(200, 'ms')),
    ]),
  ]),
  RaftUtility('duration-220', 966, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(220, 'ms')),
      RaftDecl('transition-duration', CssNum(220, 'ms')),
    ]),
  ]),
  RaftUtility('duration-240', 967, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(240, 'ms')),
      RaftDecl('transition-duration', CssNum(240, 'ms')),
    ]),
  ]),
  RaftUtility('duration-250', 968, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(250, 'ms')),
      RaftDecl('transition-duration', CssNum(250, 'ms')),
    ]),
  ]),
  RaftUtility('duration-300', 969, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(300, 'ms')),
      RaftDecl('transition-duration', CssNum(300, 'ms')),
    ]),
  ]),
  RaftUtility('duration-75', 961, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(75, 'ms')),
      RaftDecl('transition-duration', CssNum(75, 'ms')),
    ]),
  ]),
  RaftUtility('duration-90', 962, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-duration', CssNum(90, 'ms')),
      RaftDecl('transition-duration', CssNum(90, 'ms')),
    ]),
  ]),
  RaftUtility('ease-(--drawer-ease)', 970, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ease', CssVar('--drawer-ease')),
      RaftDecl('transition-timing-function', CssVar('--drawer-ease')),
    ]),
  ]),
  RaftUtility(
    'ease-[cubic-bezier(0.22,1,0.36,1)]',
    971,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-ease', _v511),
        RaftDecl('transition-timing-function', _v511),
      ]),
    ],
  ),
  RaftUtility('ease-out', 972, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ease', _v123),
      RaftDecl('transition-timing-function', _v123),
    ]),
  ]),
  RaftUtility('ease-slide', 973, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ease', _v160),
      RaftDecl('transition-timing-function', _v160),
    ]),
  ]),
  RaftUtility('empty:hidden', 1338, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['empty'],
      2000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility(
    'enabled:active:bg-fill-medium',
    1410,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'enabled'],
        3000,
        [RaftDecl('background-color', _v104)],
      ),
      RaftLayer(
        'self',
        ['active', 'dark', 'enabled'],
        3000,
        [RaftDecl('background-color', _v105)],
      ),
    ],
  ),
  RaftUtility(
    'enabled:active:overlay-medium',
    1411,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'enabled'],
        3000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['active', 'dark', 'enabled'],
        3000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    'enabled:active:overlay-sticker-medium',
    1412,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'enabled'],
        3000,
        [RaftDecl('background-image', _v278)],
      ),
    ],
  ),
  RaftUtility(
    'enabled:focus-visible:bg-brand-soft',
    1409,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['enabled', 'focus-visible'],
        3000,
        [RaftDecl('background-color', _v275)],
      ),
      RaftLayer(
        'self',
        ['dark', 'enabled', 'focus-visible'],
        3000,
        [RaftDecl('background-color', _v276)],
      ),
    ],
  ),
  RaftUtility('enabled:hover:bg-brand-soft', 1405, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['enabled', 'hover'],
      3000,
      [RaftDecl('background-color', _v275)],
    ),
    RaftLayer(
      'self',
      ['dark', 'enabled', 'hover'],
      3000,
      [RaftDecl('background-color', _v276)],
    ),
  ]),
  RaftUtility(
    'enabled:hover:bg-fill-medium',
    1406,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['enabled', 'hover'],
        3000,
        [RaftDecl('background-color', _v104)],
      ),
      RaftLayer(
        'self',
        ['dark', 'enabled', 'hover'],
        3000,
        [RaftDecl('background-color', _v105)],
      ),
    ],
  ),
  RaftUtility(
    'enabled:hover:overlay-medium',
    1407,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['enabled', 'hover'],
        3000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['dark', 'enabled', 'hover'],
        3000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    'enabled:hover:overlay-sticker-medium',
    1408,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['enabled', 'hover'],
        3000,
        [RaftDecl('background-image', _v278)],
      ),
    ],
  ),
  RaftUtility('end-0', 21, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(0, 'px'))]),
  ]),
  RaftUtility('field-sizing-content', 175, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('field-sizing', CssKeyword('content')),
    ]),
  ]),
  RaftUtility('fill-current', 640, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('fill', _v20)]),
  ]),
  RaftUtility('fill-none', 641, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('fill', CssKeyword('none'))]),
  ]),
  RaftUtility('first:border-t-0', 1328, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['first-child'],
      2000,
      [
        RaftDecl('border-top-style', _v16),
        RaftDecl('border-top-width', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('first:mt-0', 1326, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['first-child'],
      2000,
      [RaftDecl('margin-top', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('first:pt-(--surface-inset)', 1329, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['first-child'],
      2000,
      [RaftDecl('padding-top', CssNum(20, 'px'))],
    ),
    RaftLayer(
      'self',
      ['first-child', 'pointer-fine', 'width>=768'],
      2000,
      [RaftDecl('padding-top', CssNum(16, 'px'))],
    ),
  ]),
  RaftUtility('first:pt-0', 1330, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['first-child'],
      2000,
      [RaftDecl('padding-top', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('first:pt-2', 1331, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['first-child'],
      2000,
      [RaftDecl('padding-top', CssNum(8, 'px'))],
    ),
  ]),
  RaftUtility('first:pt-3', 1332, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['first-child'],
      2000,
      [RaftDecl('padding-top', CssNum(12, 'px'))],
    ),
  ]),
  RaftUtility('first:pt-4', 1333, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['first-child'],
      2000,
      [RaftDecl('padding-top', CssNum(16, 'px'))],
    ),
  ]),
  RaftUtility('first:rounded-t-container', 1327, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['first-child'],
      2000,
      [
        RaftDecl('border-top-left-radius', CssNum(10, 'px')),
        RaftDecl('border-top-right-radius', CssNum(10, 'px')),
      ],
    ),
  ]),
  RaftUtility('fixed', 11, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('position', CssKeyword('fixed'))]),
  ]),
  RaftUtility('flex', 168, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('flex'))]),
  ]),
  RaftUtility('flex-1', 393, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex', CssNum(1))]),
  ]),
  RaftUtility(
    'flex-[var(--mi-owner-flex,0_1)_var(--mi-owner-basis,auto)]',
    394,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('flex', CssSeq([_v513, _v514])),
      ]),
    ],
  ),
  RaftUtility('flex-auto', 395, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex', CssKeyword('auto'))]),
  ]),
  RaftUtility('flex-col', 462, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('flex-direction', CssKeyword('column')),
    ]),
  ]),
  RaftUtility('flex-none', 396, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex', CssKeyword('none'))]),
  ]),
  RaftUtility('flex-nowrap', 464, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-wrap', CssKeyword('nowrap'))]),
  ]),
  RaftUtility('flex-row', 463, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('flex-direction', CssKeyword('row')),
    ]),
  ]),
  RaftUtility('flex-wrap', 465, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-wrap', CssKeyword('wrap'))]),
  ]),
  RaftUtility('flex-wrap-reverse', 466, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-wrap', _v515)]),
  ]),
  RaftUtility('float-end', 103, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('float', _v410)]),
  ]),
  RaftUtility(
    'focus-visible:before:outline-2',
    1388,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('outline-style', _v516),
          RaftDecl('outline-width', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:before:outline-foreground',
    1390,
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
      RaftLayer(
        '::before',
        ['dark', 'focus-visible'],
        2001,
        [RaftDecl('outline-color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:before:outline-none',
    1391,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-outline-style', CssKeyword('none')),
          RaftDecl('outline-style', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:before:outline-offset-2',
    1389,
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
  RaftUtility('focus-visible:bg-brand-soft', 1376, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('background-color', _v275)],
    ),
    RaftLayer(
      'self',
      ['dark', 'focus-visible'],
      2000,
      [RaftDecl('background-color', _v276)],
    ),
  ]),
  RaftUtility(
    'focus-visible:keyboard:-outline-offset-2',
    2341,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('outline-offset', CssNum(-2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:before:bg-foreground',
    2349,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v0),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'focus-visible', 'not:in:root+data-input-modality=pointer'],
        2001,
        [RaftDecl('background-color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:before:inset-ring-2',
    2350,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-inset-ring-shadow', _v136),
          RaftDecl('box-shadow', _v27),
        ],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:before:inset-ring-foreground',
    2351,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-inset-ring-color', _v0),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'focus-visible', 'not:in:root+data-input-modality=pointer'],
        2001,
        [RaftDecl('--tw-inset-ring-color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:before:w-0.5',
    2348,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('width', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:inset-ring-2',
    2337,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [
          RaftDecl('--tw-inset-ring-shadow', _v136),
          RaftDecl('box-shadow', _v27),
        ],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:inset-ring-foreground',
    2338,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('--tw-inset-ring-color', _v0)],
      ),
      RaftLayer(
        'self',
        ['dark', 'focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('--tw-inset-ring-color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:outline-1',
    2339,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [
          RaftDecl('outline-style', _v516),
          RaftDecl('outline-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:outline-2',
    2340,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [
          RaftDecl('outline-style', _v516),
          RaftDecl('outline-width', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:outline-foreground',
    2344,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('outline-color', _v0)],
      ),
      RaftLayer(
        'self',
        ['dark', 'focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('outline-color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:outline-foreground-on-hud',
    2345,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('outline-color', _v271)],
      ),
      RaftLayer(
        'self',
        ['dark', 'focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('outline-color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:outline-line-strong',
    2346,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('outline-color', _v395)],
      ),
      RaftLayer(
        'self',
        ['dark', 'focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('outline-color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:outline-offset-1',
    2342,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('outline-offset', CssNum(1, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:outline-offset-2',
    2343,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('outline-offset', CssNum(2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'focus-visible:keyboard:outline-white',
    2347,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('outline-color', _v517)],
      ),
    ],
  ),
  RaftUtility('focus-visible:outline-2', 1384, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [
        RaftDecl('outline-style', _v516),
        RaftDecl('outline-width', CssNum(2, 'px')),
      ],
    ),
  ]),
  RaftUtility('focus-visible:outline-none', 1387, RaftUtilityStatus.resolved, [
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
    'focus-visible:outline-offset-2',
    1385,
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
  RaftUtility(
    'focus-visible:outline-transparent',
    1386,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('outline-color', _v15)],
      ),
    ],
  ),
  RaftUtility('focus-visible:ring-0', 1380, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v22), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'focus-visible:ring-line-strong',
    1381,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v395)],
      ),
      RaftLayer(
        'self',
        ['dark', 'focus-visible'],
        2000,
        [RaftDecl('--tw-ring-color', _v1)],
      ),
    ],
  ),
  RaftUtility('focus-visible:ring-offset-0', 1382, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [
        RaftDecl('--tw-ring-offset-width', CssNum(0, 'px')),
        RaftDecl('--tw-ring-offset-shadow', _v519),
      ],
    ),
  ]),
  RaftUtility(
    'focus-visible:ring-offset-layer-sidebar',
    1383,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-visible'],
        2000,
        [RaftDecl('--tw-ring-offset-color', _v371)],
      ),
      RaftLayer(
        'self',
        ['dark', 'focus-visible'],
        2000,
        [RaftDecl('--tw-ring-offset-color', _v367)],
      ),
    ],
  ),
  RaftUtility('focus-visible:shadow-focus', 1378, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('--tw-shadow', _v127), RaftDecl('box-shadow', _v27)],
    ),
    RaftLayer(
      'self',
      ['dark', 'focus-visible'],
      2000,
      [
        RaftDecl('--tw-shadow', CssList([_v129, _v130])),
      ],
    ),
  ]),
  RaftUtility('focus-visible:shadow-none', 1379, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('--tw-shadow', _v28), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility(
    'focus-visible:text-foreground',
    1377,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['focus-visible'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer(
        'self',
        ['dark', 'focus-visible'],
        2000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility('focus-visible:z-raised', 1375, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus-visible'],
      2000,
      [RaftDecl('z-index', CssNum(1))],
    ),
  ]),
  RaftUtility(
    'focus-within:[--mi-header-mask:linear-gradient(to_left,transparent_calc(var(--mi-toolbar-width)+8px),black_calc(var(--mi-toolbar-width)+20px))]',
    1339,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['focus-within'],
        2000,
        [RaftDecl('--mi-header-mask', _v527)],
      ),
    ],
  ),
  RaftUtility(
    'focus-within:[--mi-toolbar-opacity:1]',
    1340,
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
    1341,
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
  RaftUtility('focus:border-transparent', 1373, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus'],
      2000,
      [
        RaftDecl('border-top-color', _v15),
        RaftDecl('border-right-color', _v15),
        RaftDecl('border-bottom-color', _v15),
        RaftDecl('border-left-color', _v15),
      ],
    ),
  ]),
  RaftUtility('focus:flex', 1372, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus'],
      2000,
      [RaftDecl('display', CssKeyword('flex'))],
    ),
  ]),
  RaftUtility('focus:ring-0', 1374, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['focus'],
      2000,
      [RaftDecl('--tw-ring-shadow', _v22), RaftDecl('box-shadow', _v27)],
    ),
  ]),
  RaftUtility('font-bold', 837, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(700)),
      RaftDecl('font-weight', CssNum(700)),
    ]),
  ]),
  RaftUtility('font-card-title', 838, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', _v528),
      RaftDecl('font-weight', _v528),
    ]),
  ]),
  RaftUtility('font-field', 839, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', _v4),
      RaftDecl('font-weight', _v4),
    ]),
  ]),
  RaftUtility('font-heading', 783, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-family', _v529)]),
  ]),
  RaftUtility('font-medium', 840, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(500)),
      RaftDecl('font-weight', CssNum(500)),
    ]),
  ]),
  RaftUtility('font-mono', 784, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-family', _v141)]),
  ]),
  RaftUtility('font-normal', 841, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(400)),
      RaftDecl('font-weight', CssNum(400)),
    ]),
  ]),
  RaftUtility('font-sans', 785, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-family', _v42)]),
  ]),
  RaftUtility('font-semibold', 842, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-font-weight', CssNum(600)),
      RaftDecl('font-weight', CssNum(600)),
    ]),
  ]),
  RaftUtility('frame-decor-top', 629, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('background-repeat', CssKeyword('no-repeat')),
      RaftDecl('background-position', _v533),
    ]),
    RaftLayer(
      'self',
      ['width>=1024'],
      1000,
      [RaftDecl('background-image', _v534)],
    ),
  ]),
  RaftUtility('from-layer-canvas', 633, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-gradient-from', _v361),
      RaftDecl('--tw-gradient-stops', _v541),
    ]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('--tw-gradient-from', _v128)]),
  ]),
  RaftUtility('gap-(--field-gap)', 477, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', _v542),
      RaftDecl('column-gap', _v542),
    ]),
  ]),
  RaftUtility('gap-(--spinner-gap)', 478, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssVar('--spinner-gap')),
      RaftDecl('column-gap', CssVar('--spinner-gap')),
    ]),
  ]),
  RaftUtility('gap-0', 479, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(0, 'px')),
      RaftDecl('column-gap', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('gap-0.5', 480, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(2, 'px')),
      RaftDecl('column-gap', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('gap-1', 481, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(4, 'px')),
      RaftDecl('column-gap', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('gap-1.5', 482, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(6, 'px')),
      RaftDecl('column-gap', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('gap-2', 483, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(8, 'px')),
      RaftDecl('column-gap', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('gap-2.5', 484, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(10, 'px')),
      RaftDecl('column-gap', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('gap-3', 485, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(12, 'px')),
      RaftDecl('column-gap', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('gap-4', 486, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(16, 'px')),
      RaftDecl('column-gap', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('gap-5', 487, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(20, 'px')),
      RaftDecl('column-gap', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('gap-[2.5px]', 488, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(2.5, 'px')),
      RaftDecl('column-gap', CssNum(2.5, 'px')),
    ]),
  ]),
  RaftUtility('gap-[3px]', 489, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(3, 'px')),
      RaftDecl('column-gap', CssNum(3, 'px')),
    ]),
  ]),
  RaftUtility('gap-[7px]', 490, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssNum(7, 'px')),
      RaftDecl('column-gap', CssNum(7, 'px')),
    ]),
  ]),
  RaftUtility('gap-[inherit]', 491, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', CssKeyword('inherit')),
      RaftDecl('column-gap', CssKeyword('inherit')),
    ]),
  ]),
  RaftUtility('gap-embedded-inset', 492, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('row-gap', _v98),
      RaftDecl('column-gap', _v98),
    ]),
  ]),
  RaftUtility('gap-x-0', 493, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(0, 'px'))]),
  ]),
  RaftUtility('gap-x-1', 494, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(4, 'px'))]),
  ]),
  RaftUtility('gap-x-1.5', 495, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(6, 'px'))]),
  ]),
  RaftUtility('gap-x-2', 496, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(8, 'px'))]),
  ]),
  RaftUtility('gap-x-2.5', 497, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(10, 'px'))]),
  ]),
  RaftUtility('gap-x-3', 498, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(12, 'px'))]),
  ]),
  RaftUtility('gap-x-4', 499, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(16, 'px'))]),
  ]),
  RaftUtility('gap-x-6', 500, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('column-gap', CssNum(24, 'px'))]),
  ]),
  RaftUtility('gap-y-0', 501, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('row-gap', CssNum(0, 'px'))]),
  ]),
  RaftUtility('gap-y-0.5', 502, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('row-gap', CssNum(2, 'px'))]),
  ]),
  RaftUtility('gap-y-1', 503, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('row-gap', CssNum(4, 'px'))]),
  ]),
  RaftUtility('gap-y-2', 504, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('row-gap', CssNum(8, 'px'))]),
  ]),
  RaftUtility('gap-y-3', 505, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('row-gap', CssNum(12, 'px'))]),
  ]),
  RaftUtility('grid', 169, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('grid'))]),
  ]),
  RaftUtility('grid-cols-1', 450, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v503)]),
  ]),
  RaftUtility('grid-cols-2', 451, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v543)]),
  ]),
  RaftUtility('grid-cols-3', 452, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v428)]),
  ]),
  RaftUtility('grid-cols-[1fr_auto_1fr]', 453, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v544)]),
  ]),
  RaftUtility('grid-cols-[minmax(0,1fr)]', 454, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v117)]),
  ]),
  RaftUtility(
    'grid-cols-[minmax(0,1fr)_auto]',
    455,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v485)]),
    ],
  ),
  RaftUtility(
    'grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)]',
    456,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v545)]),
    ],
  ),
  RaftUtility(
    'grid-cols-[minmax(0,1fr)_max-content]',
    457,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('grid-template-columns', CssSeq([_v117, _v546])),
      ]),
    ],
  ),
  RaftUtility(
    'grid-cols-[minmax(88px,max-content)_minmax(0,1fr)]',
    458,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('grid-template-columns', CssSeq([_v547, _v117])),
      ]),
    ],
  ),
  RaftUtility(
    'grid-cols-[repeat(2,var(--spinner-pixel))]',
    459,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-template-columns', _v549)]),
    ],
  ),
  RaftUtility('grid-cols-subgrid', 460, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('grid-template-columns', CssKeyword('subgrid')),
    ]),
  ]),
  RaftUtility('grid-flow-col', 444, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('grid-auto-flow', CssKeyword('column')),
    ]),
  ]),
  RaftUtility('grid-rows-subgrid', 461, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('grid-template-rows', CssKeyword('subgrid')),
    ]),
  ]),
  RaftUtility('group', -1, RaftUtilityStatus.descendant, [
    RaftLayer(
      '& .r-code-copy',
      ['hover'],
      3000,
      [RaftDecl('opacity', CssNum(0.55))],
    ),
  ]),
  RaftUtility(
    'group-data-[active=true]/inbox-item:[--inbox-item-revealed:1]',
    1149,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-active=true'],
        2000,
        [RaftDecl('--inbox-item-revealed', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[active=true]/inbox-item:opacity-100',
    1148,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-active=true'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[active=true]/inbox-item:pointer-events-auto',
    1147,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-active=true'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[dragging=true]/task-draggable:not-in-data-drag-origin:shadow-float',
    1151,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'group/task-draggable:data-dragging=true',
          'not:(:where([data-drag-origin]) *)',
        ],
        2000,
        [RaftDecl('--tw-shadow', _v453), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        [
          'dark',
          'group/task-draggable:data-dragging=true',
          'not:(:where([data-drag-origin]) *)',
        ],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v455, _v457])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[dragging=true]/task-draggable:transform-none',
    1150,
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
    'group-data-[drop-state=allowed]:block',
    1152,
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
    'group-data-[drop-state=allowed]:hidden',
    1153,
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
    'group-data-[drop-state=blocked]:block',
    1154,
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
    'group-data-[drop-state=blocked]:hidden',
    1155,
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
    'group-data-[drop-state=blocked]:text-foreground-muted',
    1156,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group:data-drop-state=blocked'],
        2000,
        [RaftDecl('color', _v2)],
      ),
      RaftLayer(
        'self',
        ['dark', 'group:data-drop-state=blocked'],
        2000,
        [RaftDecl('color', _v3)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[invalid]/field:font-bold',
    1157,
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
    'group-data-[size=2xs]/avatar:-bottom-0.5',
    1159,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [RaftDecl('bottom', CssNum(-2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:-right-0.5',
    1158,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [RaftDecl('right', CssNum(-2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:border',
    1161,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [
          RaftDecl('border-top-style', _v16),
          RaftDecl('border-right-style', _v16),
          RaftDecl('border-bottom-style', _v16),
          RaftDecl('border-left-style', _v16),
          RaftDecl('border-top-width', CssNum(1, 'px')),
          RaftDecl('border-right-width', CssNum(1, 'px')),
          RaftDecl('border-bottom-width', CssNum(1, 'px')),
          RaftDecl('border-left-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:outline',
    1162,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [
          RaftDecl('outline-style', _v516),
          RaftDecl('outline-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=2xs]/avatar:size-[7px]',
    1160,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=2xs'],
        2000,
        [
          RaftDecl('width', CssNum(7, 'px')),
          RaftDecl('height', CssNum(7, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:-bottom-0.5',
    1164,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=3xs'],
        2000,
        [RaftDecl('bottom', CssNum(-2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:-right-0.5',
    1163,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=3xs'],
        2000,
        [RaftDecl('right', CssNum(-2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:border',
    1166,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=3xs'],
        2000,
        [
          RaftDecl('border-top-style', _v16),
          RaftDecl('border-right-style', _v16),
          RaftDecl('border-bottom-style', _v16),
          RaftDecl('border-left-style', _v16),
          RaftDecl('border-top-width', CssNum(1, 'px')),
          RaftDecl('border-right-width', CssNum(1, 'px')),
          RaftDecl('border-bottom-width', CssNum(1, 'px')),
          RaftDecl('border-left-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:outline',
    1167,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=3xs'],
        2000,
        [
          RaftDecl('outline-style', _v516),
          RaftDecl('outline-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=3xs]/avatar:size-1.5',
    1165,
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
    'group-data-[size=lg]/avatar:[&>svg]:block',
    2600,
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
    2601,
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
    'group-data-[size=lg]/avatar:bottom-[-5px]',
    1169,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=lg'],
        2000,
        [RaftDecl('bottom', CssNum(-5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/avatar:right-[-5px]',
    1168,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=lg'],
        2000,
        [RaftDecl('right', CssNum(-5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/avatar:size-3.5',
    1170,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=lg'],
        2000,
        [
          RaftDecl('width', CssNum(14, 'px')),
          RaftDecl('height', CssNum(14, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=lg]/progress:h-2.5',
    1171,
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
    'group-data-[size=md]/avatar:[&>svg]:block',
    2602,
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
    2603,
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
    'group-data-[size=md]/avatar:size-[11px]',
    1172,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=md'],
        2000,
        [
          RaftDecl('width', CssNum(11, 'px')),
          RaftDecl('height', CssNum(11, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=md]/avatar:size-[19px]',
    1173,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=md'],
        2000,
        [
          RaftDecl('width', CssNum(19, 'px')),
          RaftDecl('height', CssNum(19, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/avatar:bottom-[-3px]',
    1175,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=sm'],
        2000,
        [RaftDecl('bottom', CssNum(-3, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/avatar:right-[-3px]',
    1174,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=sm'],
        2000,
        [RaftDecl('right', CssNum(-3, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/avatar:size-[9px]',
    1176,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=sm'],
        2000,
        [
          RaftDecl('width', CssNum(9, 'px')),
          RaftDecl('height', CssNum(9, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/meter:h-1.5',
    1177,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/meter:data-size=sm'],
        2000,
        [RaftDecl('height', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=sm]/progress:h-1.5',
    1178,
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
    'group-data-[size=xl]/avatar:-bottom-2',
    1180,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xl'],
        2000,
        [RaftDecl('bottom', CssNum(-8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xl]/avatar:-right-2',
    1179,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xl'],
        2000,
        [RaftDecl('right', CssNum(-8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xl]/avatar:[&>svg]:block',
    2604,
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
    2605,
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
    'group-data-[size=xl]/avatar:border-2',
    1182,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xl'],
        2000,
        [
          RaftDecl('border-top-style', _v16),
          RaftDecl('border-right-style', _v16),
          RaftDecl('border-bottom-style', _v16),
          RaftDecl('border-left-style', _v16),
          RaftDecl('border-top-width', CssNum(2, 'px')),
          RaftDecl('border-right-width', CssNum(2, 'px')),
          RaftDecl('border-bottom-width', CssNum(2, 'px')),
          RaftDecl('border-left-width', CssNum(2, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xl]/avatar:size-5',
    1181,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xl'],
        2000,
        [
          RaftDecl('width', CssNum(20, 'px')),
          RaftDecl('height', CssNum(20, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:-bottom-0.5',
    1184,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [RaftDecl('bottom', CssNum(-2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:-right-0.5',
    1183,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [RaftDecl('right', CssNum(-2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:border',
    1186,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [
          RaftDecl('border-top-style', _v16),
          RaftDecl('border-right-style', _v16),
          RaftDecl('border-bottom-style', _v16),
          RaftDecl('border-left-style', _v16),
          RaftDecl('border-top-width', CssNum(1, 'px')),
          RaftDecl('border-right-width', CssNum(1, 'px')),
          RaftDecl('border-bottom-width', CssNum(1, 'px')),
          RaftDecl('border-left-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:outline',
    1187,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [
          RaftDecl('outline-style', _v516),
          RaftDecl('outline-width', CssNum(1, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[size=xs]/avatar:size-[7px]',
    1185,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/avatar:data-size=xs'],
        2000,
        [
          RaftDecl('width', CssNum(7, 'px')),
          RaftDecl('height', CssNum(7, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[tone=unread]/list-row:font-bold',
    1188,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/list-row:data-tone=unread'],
        2000,
        [
          RaftDecl('--tw-font-weight', CssNum(700)),
          RaftDecl('font-weight', CssNum(700)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[tone=unread]/sidebar-item:font-bold',
    1189,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/sidebar-item:data-tone=unread'],
        2000,
        [
          RaftDecl('--tw-font-weight', CssNum(700)),
          RaftDecl('font-weight', CssNum(700)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[unread=true]/inbox-item:after:block',
    1324,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['group/inbox-item:data-unread=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('display', CssKeyword('block')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[unread=true]/inbox-item:after:hidden',
    1325,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['group/inbox-item:data-unread=true'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('display', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-[unread=true]/inbox-item:font-bold',
    1190,
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
    'group-data-[unread=true]/inbox-item:text-foreground',
    1191,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-unread=true'],
        2000,
        [RaftDecl('color', _v0)],
      ),
      RaftLayer(
        'self',
        ['dark', 'group/inbox-item:data-unread=true'],
        2000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-active/lightbox-thumb:bg-transparent',
    1126,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/lightbox-thumb:data-active'],
        2000,
        [RaftDecl('background-color', _v15)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-active/sidebar-item:text-sticker-ink',
    1127,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/sidebar-item:data-active'],
        2000,
        [RaftDecl('color', _v143)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-closed/action-card:pb-3',
    1128,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/action-card:data-closed'],
        2000,
        [RaftDecl('padding-bottom', CssNum(12, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-disabled/field:text-foreground-disabled',
    1129,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/field:data-disabled'],
        2000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'group/field:data-disabled'],
        2000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-disabled/label:text-foreground-disabled',
    1130,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/label:data-disabled'],
        2000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'group/label:data-disabled'],
        2000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-fit-collapse/fit-group:contents',
    1131,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/fit-group:data-fit-collapse'],
        2000,
        [RaftDecl('display', CssKeyword('contents'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-fit-collapse/fit-group:hidden',
    1132,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/fit-group:data-fit-collapse'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-invalid/field:text-danger-strong',
    1133,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/field:data-invalid'],
        2000,
        [RaftDecl('color', _v392)],
      ),
      RaftLayer(
        'self',
        ['dark', 'group/field:data-invalid'],
        2000,
        [RaftDecl('color', _v393)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-measuring/ellipsis:hidden',
    1134,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/ellipsis:data-measuring'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-nested-drawer-open/drawer-popup:opacity-0',
    1135,
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
    1136,
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
    1137,
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
    'group-data-open/system-group:mb-0',
    1138,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/system-group:data-open'],
        2000,
        [RaftDecl('margin-bottom', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-open/system-group:pb-1.5',
    1139,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/system-group:data-open'],
        2000,
        [RaftDecl('padding-bottom', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-panel-open:rotate-0',
    1140,
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
    'group-data-popup-open/inbox-item:[--inbox-item-revealed:1]',
    1143,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-popup-open'],
        2000,
        [RaftDecl('--inbox-item-revealed', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-popup-open/inbox-item:opacity-100',
    1142,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-popup-open'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-popup-open/inbox-item:pointer-events-auto',
    1141,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:data-popup-open'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'group-data-read/notification-center-item:font-semibold',
    1144,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/notification-center-item:data-read'],
        2000,
        [
          RaftDecl('--tw-font-weight', CssNum(600)),
          RaftDecl('font-weight', CssNum(600)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'group-data-read/notification-center-item:text-foreground-muted',
    1145,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/notification-center-item:data-read'],
        2000,
        [RaftDecl('color', _v2)],
      ),
      RaftLayer(
        'self',
        ['dark', 'group/notification-center-item:data-read'],
        2000,
        [RaftDecl('color', _v3)],
      ),
    ],
  ),
  RaftUtility(
    'group-data-swiping/drawer-popup:select-none',
    1146,
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
    'group-focus-within/inbox-item:[--inbox-item-revealed:1]',
    1113,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:focus-within'],
        2000,
        [RaftDecl('--inbox-item-revealed', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-within/inbox-item:opacity-100',
    1112,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:focus-within'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-within/inbox-item:pointer-events-auto',
    1111,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:focus-within'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'group-focus-within/toast:[animation-play-state:paused]',
    1114,
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
    'group-hover/composer-attachment:opacity-100',
    1118,
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
  RaftUtility('group-hover/img:flex', 1119, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['group/img:hover'],
      2000,
      [RaftDecl('display', CssKeyword('flex'))],
    ),
  ]),
  RaftUtility(
    'group-hover/inbox-item:[--inbox-item-revealed:1]',
    1122,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:hover'],
        2000,
        [RaftDecl('--inbox-item-revealed', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/inbox-item:opacity-100',
    1121,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:hover'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/inbox-item:pointer-events-auto',
    1120,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/inbox-item:hover'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/lightbox-thumb:bg-layer-backdrop-nested/70',
    1123,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/lightbox-thumb:hover'],
        2000,
        [RaftDecl('background-color', _v359)],
      ),
      RaftLayer(
        'self',
        ['dark', 'group/lightbox-thumb:hover'],
        2000,
        [RaftDecl('background-color', _v360)],
      ),
      RaftLayer(
        'self',
        ['group/lightbox-thumb:hover'],
        2000,
        [RaftDecl('background-color', _v551)],
      ),
      RaftLayer(
        'self',
        ['dark', 'group/lightbox-thumb:hover'],
        2000,
        [RaftDecl('background-color', _v552)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/split-action:bg-fill-subtle',
    1124,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['group/split-action:hover'],
        2000,
        [RaftDecl('background-color', _v113)],
      ),
      RaftLayer(
        'self',
        ['dark', 'group/split-action:hover'],
        2000,
        [RaftDecl('background-color', _v114)],
      ),
    ],
  ),
  RaftUtility(
    'group-hover/toast:[animation-play-state:paused]',
    1125,
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
  RaftUtility('group-hover:text-foreground', 1115, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['group:hover'], 2000, [RaftDecl('color', _v0)]),
    RaftLayer('self', ['dark', 'group:hover'], 2000, [RaftDecl('color', _v1)]),
  ]),
  RaftUtility(
    'group-hover:text-foreground/20',
    1116,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['group:hover'], 2000, [RaftDecl('color', _v0)]),
      RaftLayer(
        'self',
        ['dark', 'group:hover'],
        2000,
        [RaftDecl('color', _v1)],
      ),
      RaftLayer('self', ['group:hover'], 2000, [RaftDecl('color', _v554)]),
      RaftLayer(
        'self',
        ['dark', 'group:hover'],
        2000,
        [RaftDecl('color', CssColor(0x33E5E5E2))],
      ),
    ],
  ),
  RaftUtility(
    'group-hover:text-transparent',
    1117,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['group:hover'], 2000, [RaftDecl('color', _v15)]),
    ],
  ),
  RaftUtility('group/action-card', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/attachment', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/avatar', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/avatar-group', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/banner', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/card-header', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/code-block', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/composer-attachment', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/copyable-code', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/drawer-popup', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/ellipsis', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/field', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/field-item', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/file-row', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/fit-group', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/img', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/input-group', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/label', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/lightbox-thumb', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/list-row', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/message', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/message-replies', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/meter', -1, RaftUtilityStatus.marker, []),
  RaftUtility(
    'group/notification-center-item',
    -1,
    RaftUtilityStatus.marker,
    [],
  ),
  RaftUtility('group/panel-frame', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/progress', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/section', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/section-header', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/sidebar-item', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/split-action', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/system-group', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/task-drag-overlay', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/task-draggable', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/toast', -1, RaftUtilityStatus.marker, []),
  RaftUtility('group/video', -1, RaftUtilityStatus.marker, []),
  RaftUtility('grow', 400, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-grow', CssNum(1))]),
  ]),
  RaftUtility('grow-(--fit-scroll-grow,1)', 401, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-grow', _v555)]),
  ]),
  RaftUtility('h-(--bar-button-size)', 215, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v203)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(28, 'px'))],
    ),
  ]),
  RaftUtility(
    'h-(--code-block-header-height)',
    216,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', _v556)]),
    ],
  ),
  RaftUtility(
    'h-(--collapsible-panel-height)',
    217,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', _v557)]),
    ],
  ),
  RaftUtility('h-(--drawer-content-height)', 218, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v558)]),
  ]),
  RaftUtility('h-(--frame-item-height)', 219, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v209)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(34, 'px'))],
    ),
  ]),
  RaftUtility('h-(--header-height)', 220, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v222)]),
  ]),
  RaftUtility('h-(--option-height)', 221, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v559)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(34, 'px'))],
    ),
  ]),
  RaftUtility('h-(--row-height)', 222, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v560)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(34, 'px'))],
    ),
  ]),
  RaftUtility('h-(--segment-size)', 223, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v89)]),
  ]),
  RaftUtility(
    'h-(--shell-header-height,var(--header-height))',
    224,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', _v561)]),
    ],
  ),
  RaftUtility('h-(--switch-height)', 225, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v65)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(22, 'px'))],
    ),
  ]),
  RaftUtility(
    'h-(--task-dnd-placeholder-height,72px)',
    226,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', _v562)]),
    ],
  ),
  RaftUtility(
    'h-(--text-callout--line-height)',
    227,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(20, 'px'))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('height', CssNum(22, 'px'))],
      ),
    ],
  ),
  RaftUtility('h-(--toast-stack-height)', 228, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v563)]),
  ]),
  RaftUtility('h-0', 229, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(0, 'px'))]),
  ]),
  RaftUtility('h-0.5', 230, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(2, 'px'))]),
  ]),
  RaftUtility('h-1', 231, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(4, 'px'))]),
  ]),
  RaftUtility('h-10', 241, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(40, 'px'))]),
  ]),
  RaftUtility('h-11', 242, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(44, 'px'))]),
  ]),
  RaftUtility('h-16', 243, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(64, 'px'))]),
  ]),
  RaftUtility('h-2', 232, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(8, 'px'))]),
  ]),
  RaftUtility('h-20', 244, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(80, 'px'))]),
  ]),
  RaftUtility('h-3', 233, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(12, 'px'))]),
  ]),
  RaftUtility('h-3.5', 234, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(14, 'px'))]),
  ]),
  RaftUtility('h-4', 235, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(16, 'px'))]),
  ]),
  RaftUtility('h-44', 245, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(176, 'px'))]),
  ]),
  RaftUtility('h-5', 236, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(20, 'px'))]),
  ]),
  RaftUtility('h-56', 246, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(224, 'px'))]),
  ]),
  RaftUtility('h-6', 237, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(24, 'px'))]),
  ]),
  RaftUtility('h-7', 238, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(28, 'px'))]),
  ]),
  RaftUtility('h-72', 247, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(288, 'px'))]),
  ]),
  RaftUtility('h-8', 239, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(32, 'px'))]),
  ]),
  RaftUtility('h-9', 240, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(36, 'px'))]),
  ]),
  RaftUtility('h-96', 248, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(384, 'px'))]),
  ]),
  RaftUtility('h-[0.75em]', 249, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(0.75, 'em'))]),
  ]),
  RaftUtility('h-[18px]', 251, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(18, 'px'))]),
  ]),
  RaftUtility('h-[22px]', 252, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(22, 'px'))]),
  ]),
  RaftUtility('h-[3px]', 250, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(3, 'px'))]),
  ]),
  RaftUtility('h-[90dvh]', 253, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(90, 'dvh'))]),
  ]),
  RaftUtility('h-[calc(100%-1lh)]', 254, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssCalc(_v564))]),
  ]),
  RaftUtility(
    'h-[calc(var(--frame-item-height)+2*var(--header-air))]',
    255,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', CssCalc(_v566))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('height', CssNum(44, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'h-[calc(var(--header-height)+env(safe-area-inset-top,0px))]',
    256,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', _v567)]),
    ],
  ),
  RaftUtility(
    'h-[min(760px,calc(100dvh-2rem))]',
    257,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('height', _v569)]),
    ],
  ),
  RaftUtility('h-auto', 258, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssKeyword('auto'))]),
  ]),
  RaftUtility('h-control', 259, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v206)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(34, 'px'))],
    ),
  ]),
  RaftUtility('h-control-cta', 260, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v570)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(40, 'px'))],
    ),
  ]),
  RaftUtility('h-control-embedded', 261, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v6)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(22, 'px'))],
    ),
  ]),
  RaftUtility('h-fit', 262, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v571)]),
  ]),
  RaftUtility('h-full', 263, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(100, '%'))]),
  ]),
  RaftUtility('h-lh', 264, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(1, 'lh'))]),
  ]),
  RaftUtility('h-px', 265, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', CssNum(1, 'px'))]),
  ]),
  RaftUtility('h-timeline-section', 266, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('height', _v572)]),
  ]),
  RaftUtility(
    'has-[+[data-slot=card-content]]:pb-0',
    1536,
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
    'has-[>[data-banner-close]]:[--banner-action-end:span_2]',
    1537,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-banner-close'],
        2000,
        [RaftDecl('--banner-action-end', _v90)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-inbox-item-time]]:h-(--text-subhead--line-height)',
    1538,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-inbox-item-time'],
        2000,
        [RaftDecl('height', CssNum(20, 'px'))],
      ),
      RaftLayer(
        'self',
        ['has:>data-inbox-item-time', 'pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('height', CssNum(22, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-inbox-item-time]]:items-baseline',
    1539,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-inbox-item-time'],
        2000,
        [RaftDecl('align-items', CssKeyword('baseline'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-popup-open]]:[--split-action-main-tint:var(--fill-subtle)]',
    1540,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-popup-open'],
        2000,
        [RaftDecl('--split-action-main-tint', _v113)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:>data-popup-open'],
        2000,
        [RaftDecl('--split-action-main-tint', _v114)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-reveal=hover]_[data-popup-open]]:[--inbox-item-revealed:1]',
    1541,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-reveal=hover data-popup-open'],
        3000,
        [RaftDecl('--inbox-item-revealed', CssNum(1))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-action],>[data-banner-close]]:py-[calc((var(--banner-button)-1lh)/2+(--spacing(1)))]',
    1542,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-action>data-banner-close'],
        2000,
        [
          RaftDecl('padding-top', CssCalc(_v576)),
          RaftDecl('padding-bottom', CssCalc(_v576)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-description]]:[--banner-last-row:var(--banner-desc-row,1)]',
    1543,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=banner-description'],
        2000,
        [RaftDecl('--banner-last-row', _v577)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=banner-title]]:[--banner-desc-row:2]',
    1544,
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
    'has-[>[data-slot=card-leading]]:[--card-text-col:2]',
    1546,
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
    1547,
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
    1545,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=card-leading'],
        2000,
        [RaftDecl('grid-template-columns', _v486)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=card-leading]]:has-[>[data-slot=card-trailing]]:grid-cols-[auto_minmax(0,1fr)_auto]',
    1549,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=card-leading', 'has:>data-slot=card-trailing'],
        3000,
        [RaftDecl('grid-template-columns', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=card-trailing]]:grid-cols-[minmax(0,1fr)_auto]',
    1548,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=card-trailing'],
        2000,
        [RaftDecl('grid-template-columns', _v485)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=inbox-item-line]]:has-[>[data-reveal=hover]]:pr-(--inbox-item-actions-room,0px)',
    1550,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-reveal=hover', 'has:>data-slot=inbox-item-line'],
        3000,
        [RaftDecl('padding-right', _v578)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-indicator],>[data-slot=message-reference-read-mark]]:inline-block',
    1553,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:>data-slot=message-reference-indicator>data-slot=message-reference-read-mark',
        ],
        2000,
        [RaftDecl('display', _v58)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-indicator],>[data-slot=message-reference-read-mark]]:mr-2.5',
    1552,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:>data-slot=message-reference-indicator>data-slot=message-reference-read-mark',
        ],
        2000,
        [RaftDecl('margin-right', CssNum(10, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-indicator],>[data-slot=message-reference-read-mark]]:overflow-visible',
    1554,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:>data-slot=message-reference-indicator>data-slot=message-reference-read-mark',
        ],
        2000,
        [
          RaftDecl('overflow-x', CssKeyword('visible')),
          RaftDecl('overflow-y', CssKeyword('visible')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=message-reference-indicator],>[data-slot=message-reference-read-mark]]:relative',
    1551,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:>data-slot=message-reference-indicator>data-slot=message-reference-read-mark',
        ],
        2000,
        [RaftDecl('position', CssKeyword('relative'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=sidebar-item-meta-icon]]:items-center',
    1555,
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
    'has-[>[data-slot=spinner]]:[--banner-text-col:2]',
    1558,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=spinner'],
        2000,
        [RaftDecl('--banner-text-col', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=spinner]]:grid-cols-[16px_minmax(0,1fr)]',
    1556,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=spinner'],
        2000,
        [RaftDecl('grid-template-columns', _v579)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>[data-slot=spinner]]:grid-cols-[20px_minmax(0,1fr)]',
    1557,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-slot=spinner'],
        2000,
        [RaftDecl('grid-template-columns', _v580)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg,>[data-slot=spinner],>[data-slot=message-reference-icon]]:px-[4.5px]',
    1563,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>svg>data-slot=spinner>data-slot=message-reference-icon'],
        2000,
        [
          RaftDecl('padding-left', CssNum(4.5, 'px')),
          RaftDecl('padding-right', CssNum(4.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg]:[--banner-text-col:2]',
    1562,
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
  RaftUtility(
    'has-[>svg]:grid-cols-[16px_minmax(0,1fr)]',
    1559,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>svg'],
        1001,
        [RaftDecl('grid-template-columns', _v579)],
      ),
    ],
  ),
  RaftUtility(
    'has-[>svg]:grid-cols-[20px_minmax(0,1fr)]',
    1560,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>svg'],
        1001,
        [RaftDecl('grid-template-columns', _v580)],
      ),
    ],
  ),
  RaftUtility('has-[>svg]:pl-[18px]', 1561, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:>svg'],
      1001,
      [RaftDecl('padding-left', CssNum(18, 'px'))],
    ),
  ]),
  RaftUtility(
    'has-[[data-slot=composer-attachments-scroll-area]]:min-w-0',
    1519,
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
    'has-[[data-slot=composer-attachments-scroll-area]]:p-0',
    1520,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=composer-attachments-scroll-area'],
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
    'has-[[data-slot=file-preview]]:size-9',
    1521,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=file-preview'],
        2000,
        [
          RaftDecl('width', CssNum(36, 'px')),
          RaftDecl('height', CssNum(36, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=file-row-open]:active]:overlay-medium',
    1522,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=file-row-open+active'],
        3000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=file-row-open+active'],
        3000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=file-row-open]:focus-visible]:shadow-focus',
    1523,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=file-row-open+focus-visible'],
        3000,
        [RaftDecl('--tw-shadow', _v127), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=file-row-open+focus-visible'],
        3000,
        [
          RaftDecl('--tw-shadow', CssList([_v129, _v130])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=inbox-item-open]:focus-visible]:keyboard:before:inset-ring-2',
    2358,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        [
          'has:data-slot=inbox-item-open+focus-visible',
          'not:in:root+data-input-modality=pointer',
        ],
        3001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-inset-ring-shadow', _v136),
          RaftDecl('box-shadow', _v27),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=inbox-item-open]:focus-visible]:keyboard:before:inset-ring-foreground',
    2359,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        [
          'has:data-slot=inbox-item-open+focus-visible',
          'not:in:root+data-input-modality=pointer',
        ],
        3001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-inset-ring-color', _v0),
        ],
      ),
      RaftLayer(
        '::before',
        [
          'dark',
          'has:data-slot=inbox-item-open+focus-visible',
          'not:in:root+data-input-modality=pointer',
        ],
        3001,
        [RaftDecl('--tw-inset-ring-color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:[--ig-addon-fg:var(--foreground-disabled)]',
    1527,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('--ig-addon-fg', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('--ig-addon-fg', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:[--ig-text-fg:var(--foreground-disabled)]',
    1528,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('--ig-text-fg', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('--ig-text-fg', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:bg-fill-muted',
    1526,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('background-color', _v220)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('background-color', _v221)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:border-line-hairline',
    1525,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [
          RaftDecl('border-top-color', _v252),
          RaftDecl('border-right-color', _v252),
          RaftDecl('border-bottom-color', _v252),
          RaftDecl('border-left-color', _v252),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=input-group-control+disabled'],
        3000,
        [
          RaftDecl('border-top-color', _v253),
          RaftDecl('border-right-color', _v253),
          RaftDecl('border-bottom-color', _v253),
          RaftDecl('border-left-color', _v253),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control]:disabled]:cursor-not-allowed',
    1524,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+disabled'],
        3000,
        [RaftDecl('cursor', _v308)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=input-group-control][data-invalid]]:border-danger-strong',
    1529,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=input-group-control+data-invalid'],
        3000,
        [
          RaftDecl('border-top-color', _v392),
          RaftDecl('border-right-color', _v392),
          RaftDecl('border-bottom-color', _v392),
          RaftDecl('border-left-color', _v392),
        ],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=input-group-control+data-invalid'],
        3000,
        [
          RaftDecl('border-top-color', _v393),
          RaftDecl('border-right-color', _v393),
          RaftDecl('border-bottom-color', _v393),
          RaftDecl('border-left-color', _v393),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=message-multi-select-checkbox][data-checked]]:[--mi-row-fill:var(--info-soft)]',
    1530,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-multi-select-checkbox+data-checked'],
        3000,
        [RaftDecl('--mi-row-fill', _v311)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=message-multi-select-checkbox+data-checked'],
        3000,
        [RaftDecl('--mi-row-fill', _v312)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=message-multi-select-checkbox][data-checked]]:hover:[--mi-row-fill:var(--info-soft)]',
    1531,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-multi-select-checkbox+data-checked', 'hover'],
        4000,
        [RaftDecl('--mi-row-fill', _v311)],
      ),
      RaftLayer(
        'self',
        [
          'dark',
          'has:data-slot=message-multi-select-checkbox+data-checked',
          'hover',
        ],
        4000,
        [RaftDecl('--mi-row-fill', _v312)],
      ),
    ],
  ),
  RaftUtility(
    'has-[[data-slot=sortable-composer-attachments-list]]:min-w-0',
    1532,
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
    'has-[[data-slot=sortable-composer-attachments-list]]:pt-0',
    1533,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=sortable-composer-attachments-list'],
        2000,
        [RaftDecl('padding-top', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-[strong]:text-foreground',
    1534,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['has:strong'], 1001, [RaftDecl('color', _v0)]),
      RaftLayer('self', ['dark', 'has:strong'], 1001, [RaftDecl('color', _v1)]),
    ],
  ),
  RaftUtility('has-[svg]:px-0', 1535, RaftUtilityStatus.resolved, [
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
  RaftUtility(
    'has-data-[icon=inline-end]:pr-2.5',
    1487,
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
    'has-data-[icon=inline-end]:pr-3.5',
    1488,
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
    'has-data-[icon=inline-start]:pl-2.5',
    1489,
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
    'has-data-[icon=inline-start]:pl-3.5',
    1490,
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
    1491,
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
    'has-data-[slot=composer-attachments-scroll-area]:block',
    1493,
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
    1492,
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
    1496,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=file-preview'],
        2000,
        [RaftDecl('background-color', _v15)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=file-preview]:border-0',
    1495,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=file-preview'],
        2000,
        [
          RaftDecl('border-top-style', _v16),
          RaftDecl('border-right-style', _v16),
          RaftDecl('border-bottom-style', _v16),
          RaftDecl('border-left-style', _v16),
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
    1494,
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
    'has-data-[slot=inbox-item-leading]:grid-cols-[auto_minmax(0,1fr)_auto]',
    1497,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-leading'],
        2000,
        [RaftDecl('grid-template-columns', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=inbox-item-line]:@container/inbox-item-row',
    1498,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-line'],
        2000,
        [RaftDecl('container-type', _v86), RaftDecl('container-name', _v581)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=inbox-item-line]:[--inbox-item-content-end:-1]',
    1499,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-line'],
        2000,
        [RaftDecl('--inbox-item-content-end', CssNum(-1))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=inbox-item-line]:hover:[--inbox-item-time-display:inline]',
    1500,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-line', 'hover'],
        3000,
        [RaftDecl('--inbox-item-time-display', CssKeyword('inline'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=inbox-item-line]:keyboard:focus-within:[--inbox-item-time-display:inline]',
    2357,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'focus-within',
          'has:data-slot=inbox-item-line',
          'not:in:root+data-input-modality=pointer',
        ],
        3000,
        [RaftDecl('--inbox-item-time-display', CssKeyword('inline'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=inbox-item-line]:pointer-coarse:[--inbox-item-actions-room:--spacing(11)]',
    2236,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-line', 'pointer-coarse'],
        2000,
        [RaftDecl('--inbox-item-actions-room', CssNum(44, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=inbox-item-line]:pointer-fine:[:focus-within,[data-active=true],[data-popup-open],:has([data-popup-open])]:[--inbox-item-actions-room:--spacing(10)]',
    2490,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:data-slot=inbox-item-line',
          'is(:focus-within, [data-active=true], [data-popup-open], :has([data-popup-open]))',
          'pointer-fine',
        ],
        3000,
        [RaftDecl('--inbox-item-actions-room', CssNum(40, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=inbox-item-line]:pointer-fine:hover:[--inbox-item-actions-room:--spacing(10)]',
    2257,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-line', 'hover', 'pointer-fine'],
        3000,
        [RaftDecl('--inbox-item-actions-room', CssNum(40, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=inbox-item-selection]:grid-cols-[auto_minmax(0,1fr)_auto]',
    1501,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-selection'],
        2000,
        [RaftDecl('grid-template-columns', _v118)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=inbox-item-selection]:has-data-[slot=inbox-item-leading]:grid-cols-[auto_auto_minmax(0,1fr)_auto]',
    1502,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:data-slot=inbox-item-leading',
          'has:data-slot=inbox-item-selection',
        ],
        3000,
        [RaftDecl('grid-template-columns', _v582)],
      ),
    ],
  ),
  RaftUtility('has-data-[slot=kbd]:pr-2.5', 1506, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:data-slot=kbd'],
      2000,
      [RaftDecl('padding-right', CssNum(10, 'px'))],
    ),
  ]),
  RaftUtility('has-data-[slot=kbd]:py-1', 1505, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['has:data-slot=kbd'],
      2000,
      [
        RaftDecl('padding-top', CssNum(4, 'px')),
        RaftDecl('padding-bottom', CssNum(4, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'has-data-[slot=message-item-delegated-by-button]:max-w-[45%]',
    1509,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-delegated-by-button'],
        2000,
        [RaftDecl('max-width', CssNum(45, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-delegated-by-button]:whitespace-pre',
    1510,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-delegated-by-button'],
        2000,
        [RaftDecl('white-space', CssKeyword('pre'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-delegated-by-name]:max-w-[45%]',
    1511,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-delegated-by-name'],
        2000,
        [RaftDecl('max-width', CssNum(45, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-delegated-by-name]:whitespace-pre',
    1512,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-delegated-by-name'],
        2000,
        [RaftDecl('white-space', CssKeyword('pre'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-delegated-by]:[--mi-owner-basis:3rem]',
    1507,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-delegated-by'],
        2000,
        [RaftDecl('--mi-owner-basis', CssNum(48, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-delegated-by]:[--mi-owner-flex:1_0]',
    1508,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-delegated-by'],
        2000,
        [RaftDecl('--mi-owner-flex', _v583)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:[--mi-row-fill:var(--info-soft)]',
    1513,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('--mi-row-fill', _v311)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=message-item-search-match'],
        2000,
        [RaftDecl('--mi-row-fill', _v312)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-item-search-match]:hover:[--mi-row-fill:var(--info-soft)]',
    1514,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-item-search-match', 'hover'],
        3000,
        [RaftDecl('--mi-row-fill', _v311)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=message-item-search-match', 'hover'],
        3000,
        [RaftDecl('--mi-row-fill', _v312)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-quoted-preview-author-delegated-by]:flex-wrap',
    1515,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-quoted-preview-author-delegated-by'],
        2000,
        [RaftDecl('flex-wrap', CssKeyword('wrap'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=message-reaction-error-indicator]:bg-warning-soft',
    1516,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=message-reaction-error-indicator'],
        2000,
        [RaftDecl('background-color', _v390)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-slot=message-reaction-error-indicator'],
        2000,
        [RaftDecl('background-color', _v389)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=notification-center-item-icon]:before:left-[63px]',
    1517,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-slot=notification-center-item-icon'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', CssNum(63, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-data-[slot=sortable-composer-attachments-list]:block',
    1518,
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
    'has-data-disabled:cursor-not-allowed',
    1475,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-disabled'],
        2000,
        [RaftDecl('cursor', _v308)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-disabled:text-foreground-disabled',
    1476,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-disabled'],
        2000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-disabled'],
        2000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:[--mi-ct-color:var(--foreground-hint)]',
    1480,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('--mi-ct-color', _v44)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-popup-open'],
        2000,
        [RaftDecl('--mi-ct-color', _v39)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:[--mi-header-mask:linear-gradient(to_left,transparent_calc(var(--mi-toolbar-width)+8px),black_calc(var(--mi-toolbar-width)+20px))]',
    1481,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('--mi-header-mask', _v527)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:[--mi-row-fill:var(--fill-subtle)]',
    1482,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('--mi-row-fill', _v113)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-popup-open'],
        2000,
        [RaftDecl('--mi-row-fill', _v114)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:[--mi-toolbar-opacity:1]',
    1483,
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
    1484,
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
    'has-data-popup-open:opacity-100',
    1479,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('opacity', CssNum(100, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:overlay-subtle',
    1478,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('background-image', _v237)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:data-popup-open'],
        2000,
        [RaftDecl('background-image', _v238)],
      ),
    ],
  ),
  RaftUtility(
    'has-data-popup-open:pointer-events-auto',
    1477,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-popup-open'],
        2000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility(
    'has-focus-visible:keyboard:inset-ring-2',
    2355,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [
          RaftDecl('--tw-inset-ring-shadow', _v136),
          RaftDecl('box-shadow', _v27),
        ],
      ),
    ],
  ),
  RaftUtility(
    'has-focus-visible:keyboard:inset-ring-foreground',
    2356,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('--tw-inset-ring-color', _v0)],
      ),
      RaftLayer(
        'self',
        [
          'dark',
          'has:focus-visible',
          'not:in:root+data-input-modality=pointer',
        ],
        2000,
        [RaftDecl('--tw-inset-ring-color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'has-focus-visible:shadow-focus',
    1474,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:focus-visible'],
        2000,
        [RaftDecl('--tw-shadow', _v127), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        ['dark', 'has:focus-visible'],
        2000,
        [
          RaftDecl('--tw-shadow', CssList([_v129, _v130])),
        ],
      ),
    ],
  ),
  RaftUtility('hidden', 170, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('none'))]),
  ]),
  RaftUtility(
    'hover:*:data-[slot=checkbox-indicator-graphic]:text-foreground/20',
    1942,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="checkbox-indicator-graphic"]',
        ['hover'],
        3000,
        [RaftDecl('color', _v0)],
      ),
      RaftLayer(
        ':is(& > *)[data-slot="checkbox-indicator-graphic"]',
        ['dark', 'hover'],
        3000,
        [RaftDecl('color', _v1)],
      ),
      RaftLayer(
        ':is(& > *)[data-slot="checkbox-indicator-graphic"]',
        ['hover'],
        3000,
        [RaftDecl('color', _v554)],
      ),
      RaftLayer(
        ':is(& > *)[data-slot="checkbox-indicator-graphic"]',
        ['dark', 'hover'],
        3000,
        [RaftDecl('color', CssColor(0x33E5E5E2))],
      ),
    ],
  ),
  RaftUtility(
    'hover:[--mi-ct-color:var(--foreground-hint)]',
    1358,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('--mi-ct-color', _v44)]),
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('--mi-ct-color', _v39)],
      ),
    ],
  ),
  RaftUtility(
    'hover:[--mi-header-mask:linear-gradient(to_left,transparent_calc(var(--mi-toolbar-width)+8px),black_calc(var(--mi-toolbar-width)+20px))]',
    1359,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('--mi-header-mask', _v527)]),
    ],
  ),
  RaftUtility(
    'hover:[--mi-toolbar-opacity:1]',
    1360,
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
    1361,
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
    'hover:before:bg-foreground-muted',
    1370,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['hover'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v2),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'hover'],
        2001,
        [RaftDecl('background-color', _v3)],
      ),
    ],
  ),
  RaftUtility('hover:bg-brand-soft', 1343, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v275)]),
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v276)],
    ),
  ]),
  RaftUtility('hover:bg-fill-frame-medium', 1344, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v29)]),
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v31)],
    ),
  ]),
  RaftUtility('hover:bg-fill-medium', 1345, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v104)]),
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v105)],
    ),
  ]),
  RaftUtility('hover:bg-fill-subtle', 1346, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v113)]),
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v114)],
    ),
  ]),
  RaftUtility('hover:bg-ink-8', 1347, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v584)]),
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-color', _v585)],
    ),
  ]),
  RaftUtility('hover:bg-none', 1349, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('background-image', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('hover:bg-transparent', 1348, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-color', _v15)]),
  ]),
  RaftUtility(
    'hover:border-sticker-paper/80',
    1342,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [
          RaftDecl('border-top-color', _v380),
          RaftDecl('border-right-color', _v380),
          RaftDecl('border-bottom-color', _v380),
          RaftDecl('border-left-color', _v380),
        ],
      ),
      RaftLayer(
        'self',
        ['hover'],
        2000,
        [
          RaftDecl('border-top-color', _v587),
          RaftDecl('border-right-color', _v587),
          RaftDecl('border-bottom-color', _v587),
          RaftDecl('border-left-color', _v587),
        ],
      ),
    ],
  ),
  RaftUtility(
    'hover:data-checked:shadow-none',
    1638,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-checked', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v28), RaftDecl('box-shadow', _v27)],
      ),
    ],
  ),
  RaftUtility(
    'hover:data-indeterminate:shadow-none',
    1704,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-indeterminate', 'hover'],
        3000,
        [RaftDecl('--tw-shadow', _v28), RaftDecl('box-shadow', _v27)],
      ),
    ],
  ),
  RaftUtility('hover:decoration-current', 1357, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('text-decoration-color', _v20)],
    ),
  ]),
  RaftUtility('hover:overlay-medium', 1350, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-image', _v257)]),
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-image', _v258)],
    ),
  ]),
  RaftUtility(
    'hover:overlay-sticker-medium',
    1351,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('background-image', _v278)]),
    ],
  ),
  RaftUtility('hover:overlay-subtle', 1352, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('background-image', _v237)]),
    RaftLayer(
      'self',
      ['dark', 'hover'],
      2000,
      [RaftDecl('background-image', _v238)],
    ),
  ]),
  RaftUtility(
    'hover:text-[color-mix(in_oklab,var(--foreground-link)_80%,var(--foreground))]',
    1353,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v507)]),
      RaftLayer('self', ['dark', 'hover'], 2000, [RaftDecl('color', _v508)]),
      RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v589)]),
      RaftLayer(
        'self',
        ['dark', 'hover'],
        2000,
        [RaftDecl('color', CssColor(0xFF86B4EB))],
      ),
    ],
  ),
  RaftUtility('hover:text-foreground', 1354, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v0)]),
    RaftLayer('self', ['dark', 'hover'], 2000, [RaftDecl('color', _v1)]),
  ]),
  RaftUtility('hover:text-white', 1355, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['hover'], 2000, [RaftDecl('color', _v517)]),
  ]),
  RaftUtility('hover:underline', 1356, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['hover'],
      2000,
      [RaftDecl('text-decoration-line', CssKeyword('underline'))],
    ),
  ]),
  RaftUtility('image-transparency-bg', 568, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--checker-cell', _v592),
      RaftDecl('background-color', _v594),
      RaftDecl('background-image', _v604),
      RaftDecl('background-position', _v609),
      RaftDecl('background-size', _v610),
    ]),
    RaftLayer('self', [], 1000, [
      RaftDecl('background-color', CssColor(0xFFFFFFFF)),
      RaftDecl('background-image', _v618),
      RaftDecl('background-position', _v609),
      RaftDecl('background-size', _v610),
    ]),
  ]),
  RaftUtility(
    'in-data-[disabled=true]:text-foreground-disabled',
    1456,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-disabled=true'],
        1000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-disabled=true', 'dark'],
        1000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[slot=message-action-card-header-description]:inline',
    1458,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=message-action-card-header-description'],
        1000,
        [RaftDecl('display', CssKeyword('inline'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[slot=message-action-card-header-description]:mt-0',
    1457,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=message-action-card-header-description'],
        1000,
        [RaftDecl('margin-top', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[slot=system-message-group-panel]:py-1.5',
    1459,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=system-message-group-panel'],
        1000,
        [
          RaftDecl('padding-top', CssNum(6, 'px')),
          RaftDecl('padding-bottom', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[slot=tooltip-content]:shadow-[inset_0_0_0_1px_color-mix(in_oklch,var(--foreground-on-hud)_70%,transparent)]',
    1461,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=tooltip-content'],
        1000,
        [RaftDecl('--tw-shadow', _v620), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-slot=tooltip-content', 'dark'],
        1000,
        [RaftDecl('--tw-shadow', _v621)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-slot=tooltip-content'],
        1000,
        [RaftDecl('--tw-shadow', _v625)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-slot=tooltip-content', 'dark'],
        1000,
        [RaftDecl('--tw-shadow', _v627)],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[slot=tooltip-content]:text-foreground-on-hud/70',
    1460,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-slot=tooltip-content'],
        1000,
        [RaftDecl('color', _v271)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-slot=tooltip-content', 'dark'],
        1000,
        [RaftDecl('color', _v1)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-slot=tooltip-content'],
        1000,
        [RaftDecl('color', _v628)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-slot=tooltip-content', 'dark'],
        1000,
        [RaftDecl('color', CssColor(0xB3E5E5E2))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[state=idle]:opacity-0',
    1462,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-state=idle'],
        1000,
        [RaftDecl('opacity', CssNum(0, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[state=pulling]:opacity-(--pull-progress)',
    1463,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-state=pulling'],
        1000,
        [RaftDecl('opacity', _v629)],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[state=pulling]:transition-none',
    1464,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-state=pulling'],
        1000,
        [RaftDecl('transition-property', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[toast-placement\$=right]:left-auto',
    1465,
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
    1466,
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
    1470,
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
    1471,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-toast-placement^=top'],
        1000,
        [RaftDecl('--toast-y', CssCalc(_v631))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-[toast-placement^=top]:before:bottom-full',
    1473,
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
    1472,
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
    1468,
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
    1469,
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
    1467,
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
  RaftUtility(
    'in-data-disabled:text-foreground-disabled',
    1434,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-disabled'],
        1000,
        [RaftDecl('color', _v306)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-disabled', 'dark'],
        1000,
        [RaftDecl('color', _v307)],
      ),
    ],
  ),
  RaftUtility('in-data-fit-collapse:block', 1435, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-collapse'],
      1000,
      [RaftDecl('display', CssKeyword('block'))],
    ),
  ]),
  RaftUtility(
    'in-data-fit-collapse:data-open:absolute',
    1728,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-fit-collapse', 'data-open'],
        2000,
        [RaftDecl('position', CssKeyword('absolute'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-fit-collapse:data-open:min-w-0',
    1729,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-fit-collapse', 'data-open'],
        2000,
        [RaftDecl('min-width', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-fit-collapse:focus-within:absolute',
    1438,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-fit-collapse', 'focus-within'],
        2000,
        [RaftDecl('position', CssKeyword('absolute'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-fit-collapse:focus-within:min-w-0',
    1439,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-fit-collapse', 'focus-within'],
        2000,
        [RaftDecl('min-width', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'in-data-fit-collapse:inline-flex',
    1436,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-fit-collapse'],
        1000,
        [RaftDecl('display', _v46)],
      ),
    ],
  ),
  RaftUtility(
    'in-data-fit-collapse:not-data-open:not-focus-within:hidden',
    1437,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-fit-collapse', 'not:data-open', 'not:focus-within'],
        3000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility('in-data-fit-label:contents', 1441, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-label'],
      1000,
      [RaftDecl('display', CssKeyword('contents'))],
    ),
  ]),
  RaftUtility('in-data-fit-label:hidden', 1442, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-label'],
      1000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('in-data-fit-label:px-0', 1444, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-label'],
      1000,
      [
        RaftDecl('padding-left', CssNum(0, 'px')),
        RaftDecl('padding-right', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('in-data-fit-label:sr-only', 1440, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-label'],
      1000,
      [
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
        RaftDecl('clip-path', _v88),
        RaftDecl('white-space', CssKeyword('nowrap')),
        RaftDecl('border-top-width', CssNum(0)),
        RaftDecl('border-right-width', CssNum(0)),
        RaftDecl('border-bottom-width', CssNum(0)),
        RaftDecl('border-left-width', CssNum(0)),
      ],
    ),
  ]),
  RaftUtility('in-data-fit-label:w-8', 1443, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-label'],
      1000,
      [RaftDecl('width', CssNum(32, 'px'))],
    ),
  ]),
  RaftUtility('in-data-fit-plus:block', 1446, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-plus'],
      1000,
      [RaftDecl('display', CssKeyword('block'))],
    ),
  ]),
  RaftUtility('in-data-fit-plus:hidden', 1447, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-plus'],
      1000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('in-data-fit-plus:px-0', 1449, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-plus'],
      1000,
      [
        RaftDecl('padding-left', CssNum(0, 'px')),
        RaftDecl('padding-right', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('in-data-fit-plus:sr-only', 1445, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-plus'],
      1000,
      [
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
        RaftDecl('clip-path', _v88),
        RaftDecl('white-space', CssKeyword('nowrap')),
        RaftDecl('border-top-width', CssNum(0)),
        RaftDecl('border-right-width', CssNum(0)),
        RaftDecl('border-bottom-width', CssNum(0)),
        RaftDecl('border-left-width', CssNum(0)),
      ],
    ),
  ]),
  RaftUtility('in-data-fit-plus:w-8', 1448, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['ancestor:data-fit-plus'],
      1000,
      [RaftDecl('width', CssNum(32, 'px'))],
    ),
  ]),
  RaftUtility(
    'in-data-stacked:active:bg-layer-card',
    1454,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'ancestor:data-stacked'],
        2000,
        [RaftDecl('background-color', _v362)],
      ),
      RaftLayer(
        'self',
        ['active', 'ancestor:data-stacked', 'dark'],
        2000,
        [RaftDecl('background-color', _v363)],
      ),
    ],
  ),
  RaftUtility(
    'in-data-stacked:active:overlay-medium',
    1455,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'ancestor:data-stacked'],
        2000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['active', 'ancestor:data-stacked', 'dark'],
        2000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    'in-data-stacked:bg-layer-card',
    1451,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-stacked'],
        1000,
        [RaftDecl('background-color', _v362)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-stacked', 'dark'],
        1000,
        [RaftDecl('background-color', _v363)],
      ),
    ],
  ),
  RaftUtility(
    'in-data-stacked:border-line-strong',
    1450,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-stacked'],
        1000,
        [
          RaftDecl('border-top-color', _v395),
          RaftDecl('border-right-color', _v395),
          RaftDecl('border-bottom-color', _v395),
          RaftDecl('border-left-color', _v395),
        ],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-stacked', 'dark'],
        1000,
        [
          RaftDecl('border-top-color', _v1),
          RaftDecl('border-right-color', _v1),
          RaftDecl('border-bottom-color', _v1),
          RaftDecl('border-left-color', _v1),
        ],
      ),
    ],
  ),
  RaftUtility(
    'in-data-stacked:hover:bg-layer-card',
    1452,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-stacked', 'hover'],
        2000,
        [RaftDecl('background-color', _v362)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-stacked', 'dark', 'hover'],
        2000,
        [RaftDecl('background-color', _v363)],
      ),
    ],
  ),
  RaftUtility(
    'in-data-stacked:hover:overlay-medium',
    1453,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-stacked', 'hover'],
        2000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-stacked', 'dark', 'hover'],
        2000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility('inert:invisible', 1433, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['is([inert], [inert] *)'],
      2000,
      [RaftDecl('visibility', CssKeyword('hidden'))],
    ),
  ]),
  RaftUtility('inline', 171, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', CssKeyword('inline'))]),
  ]),
  RaftUtility('inline-block', 172, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', _v58)]),
  ]),
  RaftUtility('inline-flex', 173, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', _v46)]),
  ]),
  RaftUtility('inline-grid', 174, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('display', _v632)]),
  ]),
  RaftUtility('inset-0', 15, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('top', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
      RaftDecl('bottom', CssNum(0, 'px')),
      RaftDecl('left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('inset-auto', 16, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('top', CssKeyword('auto')),
      RaftDecl('right', CssKeyword('auto')),
      RaftDecl('bottom', CssKeyword('auto')),
      RaftDecl('left', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('inset-ring', 925, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-inset-ring-shadow', _v493),
      RaftDecl('box-shadow', _v27),
    ]),
  ]),
  RaftUtility('inset-ring-0', 926, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-inset-ring-shadow', _v309),
      RaftDecl('box-shadow', _v27),
    ]),
  ]),
  RaftUtility('inset-ring-[1.5px]', 927, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-inset-ring-shadow', _v142),
      RaftDecl('box-shadow', _v27),
    ]),
  ]),
  RaftUtility('inset-ring-line-hairline', 931, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-inset-ring-color', _v252)]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('--tw-inset-ring-color', _v253)],
    ),
  ]),
  RaftUtility('inset-ring-line-seam', 932, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-inset-ring-color', _v317)]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('--tw-inset-ring-color', _v318)],
    ),
  ]),
  RaftUtility('inset-ring-sticker-ink', 933, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-inset-ring-color', _v143)]),
  ]),
  RaftUtility('inset-s-0', 20, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', CssNum(0, 'px'))]),
  ]),
  RaftUtility('inset-x-0', 17, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('left', CssNum(0, 'px')),
      RaftDecl('right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('inset-x-4', 18, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('left', CssNum(16, 'px')),
      RaftDecl('right', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('inset-y-0', 19, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('top', CssNum(0, 'px')),
      RaftDecl('bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('invisible', 8, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('visibility', CssKeyword('hidden'))]),
  ]),
  RaftUtility('isolate', 66, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('isolation', CssKeyword('isolate'))]),
  ]),
  RaftUtility('items-baseline', 468, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-items', CssKeyword('baseline')),
    ]),
  ]),
  RaftUtility('items-center', 469, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-items', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('items-end', 470, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-items', CssKeyword('flex-end')),
    ]),
  ]),
  RaftUtility('items-start', 471, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('align-items', _v61)]),
  ]),
  RaftUtility('items-stretch', 472, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-items', CssKeyword('stretch')),
    ]),
  ]),
  RaftUtility('justify-between', 473, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('justify-content', _v5)]),
  ]),
  RaftUtility('justify-center', 474, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('justify-content', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('justify-end', 475, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('justify-content', CssKeyword('flex-end')),
    ]),
  ]),
  RaftUtility('justify-self-end', 510, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('justify-self', CssKeyword('flex-end')),
    ]),
  ]),
  RaftUtility('justify-self-start', 511, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('justify-self', _v61)]),
  ]),
  RaftUtility('justify-start', 476, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('justify-content', _v61)]),
  ]),
  RaftUtility(
    'keyboard:has-focus-visible:shadow-[inset_0_0_0_2px_var(--foreground)]',
    2354,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:focus-visible', 'not:in:root+data-input-modality=pointer'],
        2000,
        [RaftDecl('--tw-shadow', _v633), RaftDecl('box-shadow', _v27)],
      ),
      RaftLayer(
        'self',
        [
          'dark',
          'has:focus-visible',
          'not:in:root+data-input-modality=pointer',
        ],
        2000,
        [RaftDecl('--tw-shadow', _v634)],
      ),
    ],
  ),
  RaftUtility('last:[&>td]:border-b-0', 2622, RaftUtilityStatus.descendant, [
    RaftLayer(
      '& > td',
      ['last-child'],
      2001,
      [
        RaftDecl('border-bottom-style', _v16),
        RaftDecl('border-bottom-width', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('last:mb-0', 1334, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['last-child'],
      2000,
      [RaftDecl('margin-bottom', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility('last:pb-4', 1335, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['last-child'],
      2000,
      [RaftDecl('padding-bottom', CssNum(16, 'px'))],
    ),
  ]),
  RaftUtility('leading-10', 826, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(40, 'px')),
      RaftDecl('line-height', CssNum(40, 'px')),
    ]),
  ]),
  RaftUtility('leading-12', 827, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(48, 'px')),
      RaftDecl('line-height', CssNum(48, 'px')),
    ]),
  ]),
  RaftUtility('leading-14', 828, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(56, 'px')),
      RaftDecl('line-height', CssNum(56, 'px')),
    ]),
  ]),
  RaftUtility('leading-16', 829, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(64, 'px')),
      RaftDecl('line-height', CssNum(64, 'px')),
    ]),
  ]),
  RaftUtility('leading-4', 821, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(16, 'px')),
      RaftDecl('line-height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('leading-5', 822, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(20, 'px')),
      RaftDecl('line-height', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('leading-6', 823, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(24, 'px')),
      RaftDecl('line-height', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('leading-7', 824, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(28, 'px')),
      RaftDecl('line-height', CssNum(28, 'px')),
    ]),
  ]),
  RaftUtility('leading-8', 825, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(32, 'px')),
      RaftDecl('line-height', CssNum(32, 'px')),
    ]),
  ]),
  RaftUtility('leading-[1.2em]', 830, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1.2, 'em')),
      RaftDecl('line-height', CssNum(1.2, 'em')),
    ]),
  ]),
  RaftUtility('leading-[1.3em]', 831, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1.3, 'em')),
      RaftDecl('line-height', CssNum(1.3, 'em')),
    ]),
  ]),
  RaftUtility('leading-[1.4]', 832, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1.4)),
      RaftDecl('line-height', CssNum(1.4)),
    ]),
  ]),
  RaftUtility('leading-[inherit]', 833, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssKeyword('inherit')),
      RaftDecl('line-height', CssKeyword('inherit')),
    ]),
  ]),
  RaftUtility(
    'leading-[var(--chip-line-height,calc(var(--text-body--line-height)-2px))]',
    834,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-leading', _v635),
        RaftDecl('line-height', _v635),
      ]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--tw-leading', _v636), RaftDecl('line-height', _v636)],
      ),
    ],
  ),
  RaftUtility('leading-none', 835, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1)),
      RaftDecl('line-height', CssNum(1)),
    ]),
  ]),
  RaftUtility('leading-tight', 836, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-leading', CssNum(1.25)),
      RaftDecl('line-height', CssNum(1.25)),
    ]),
  ]),
  RaftUtility('left-(--drawer-inset)', 61, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', _v161)]),
  ]),
  RaftUtility('left-0', 62, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', CssNum(0, 'px'))]),
  ]),
  RaftUtility('left-1.5', 63, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', CssNum(6, 'px'))]),
  ]),
  RaftUtility('left-1/2', 64, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', CssNum(50, '%'))]),
  ]),
  RaftUtility('left-6', 65, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('left', CssNum(24, 'px'))]),
  ]),
  RaftUtility(
    'line-clamp-(--ellipsis-lines)',
    159,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('overflow-x', CssKeyword('hidden')),
        RaftDecl('overflow-y', CssKeyword('hidden')),
        RaftDecl('display', _v637),
        RaftDecl('-webkit-box-orient', CssKeyword('vertical')),
        RaftDecl('-webkit-line-clamp', _v638),
      ]),
    ],
  ),
  RaftUtility('line-clamp-1', 160, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
      RaftDecl('display', _v637),
      RaftDecl('-webkit-box-orient', CssKeyword('vertical')),
      RaftDecl('-webkit-line-clamp', CssNum(1)),
    ]),
  ]),
  RaftUtility('line-clamp-2', 161, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
      RaftDecl('display', _v637),
      RaftDecl('-webkit-box-orient', CssKeyword('vertical')),
      RaftDecl('-webkit-line-clamp', CssNum(2)),
    ]),
  ]),
  RaftUtility('line-clamp-3', 162, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
      RaftDecl('display', _v637),
      RaftDecl('-webkit-box-orient', CssKeyword('vertical')),
      RaftDecl('-webkit-line-clamp', CssNum(3)),
    ]),
  ]),
  RaftUtility('line-clamp-none', 163, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('visible')),
      RaftDecl('overflow-y', CssKeyword('visible')),
      RaftDecl('display', CssKeyword('block')),
      RaftDecl('-webkit-box-orient', _v639),
      RaftDecl('-webkit-line-clamp', CssKeyword('unset')),
    ]),
  ]),
  RaftUtility('list-cell', 1092, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--list-cell', CssNum(1))]),
    RaftLayer(
      '::before',
      ['data-located'],
      2001,
      [RaftDecl('--located-tint', _v424), RaftDecl('animation', _v642)],
    ),
    RaftLayer(
      '::before',
      ['dark', 'data-located'],
      2001,
      [RaftDecl('--located-tint', _v425)],
    ),
    RaftLayer(
      '::before',
      [
        'data-located',
        'not:( :active, [data-selected]:not([data-selected="false"]), [data-active]:not([data-active="false"]), [aria-selected="true"], [aria-current]:not([aria-current="false"]), [data-popup-open] )',
      ],
      4001,
      [RaftDecl('background-image', _v643)],
    ),
  ]),
  RaftUtility('list-decimal', 441, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('list-style-type', CssKeyword('decimal')),
    ]),
  ]),
  RaftUtility('list-disc', 442, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('list-style-type', CssKeyword('disc')),
    ]),
  ]),
  RaftUtility('m-0', 106, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(0, 'px')),
      RaftDecl('margin-right', CssNum(0, 'px')),
      RaftDecl('margin-bottom', CssNum(0, 'px')),
      RaftDecl('margin-left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('mask-(--mi-header-mask,none)', 636, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('mask-image', _v644)]),
  ]),
  RaftUtility('mask-fade-b', 637, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('mask-image', _v646)]),
  ]),
  RaftUtility('mask-fade-x', 635, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['data-overflow=start'],
      2000,
      [RaftDecl('mask-image', _v648)],
    ),
    RaftLayer(
      'self',
      ['data-overflow=end'],
      2000,
      [RaftDecl('mask-image', _v649)],
    ),
    RaftLayer(
      'self',
      ['data-overflow=both'],
      2000,
      [RaftDecl('mask-image', _v652)],
    ),
  ]),
  RaftUtility('max-h-(--available-height)', 267, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', _v653)]),
  ]),
  RaftUtility('max-h-32', 268, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(128, 'px'))]),
  ]),
  RaftUtility('max-h-40', 269, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(160, 'px'))]),
  ]),
  RaftUtility('max-h-60', 270, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(240, 'px'))]),
  ]),
  RaftUtility('max-h-64', 271, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(256, 'px'))]),
  ]),
  RaftUtility('max-h-72', 272, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(288, 'px'))]),
  ]),
  RaftUtility('max-h-[136px]', 276, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(136, 'px'))]),
  ]),
  RaftUtility('max-h-[70dvh]', 273, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(70, 'dvh'))]),
  ]),
  RaftUtility('max-h-[80vh]', 274, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(80, 'vh'))]),
  ]),
  RaftUtility('max-h-[82vh]', 275, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssNum(82, 'vh'))]),
  ]),
  RaftUtility('max-h-[calc(100dvh-2rem)]', 277, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssCalc(_v568))]),
  ]),
  RaftUtility(
    'max-h-[min(max(60dvh,var(--mobile-nav-server-popover-floor,0px)),calc(var(--available-height)-env(safe-area-inset-top,0px)))]',
    278,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('max-height', _v657)]),
    ],
  ),
  RaftUtility('max-h-none', 279, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-height', CssKeyword('none'))]),
  ]),
  RaftUtility(
    'max-md:**:data-[slot=panel-action]:active:bg-fill-frame-medium',
    2134,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="panel-action"]:active',
        ['width<768'],
        3000,
        [RaftDecl('background-color', _v29)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="panel-action"]:active',
        ['dark', 'width<768'],
        3000,
        [RaftDecl('background-color', _v31)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:**:data-[slot=panel-action]:hover:bg-fill-frame-medium',
    2133,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="panel-action"]:hover',
        ['width<768'],
        3000,
        [RaftDecl('background-color', _v29)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="panel-action"]:hover',
        ['dark', 'width<768'],
        3000,
        [RaftDecl('background-color', _v31)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:**:data-[slot=panel-action]:text-foreground-on-frame',
    2132,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="panel-action"]',
        ['width<768'],
        2000,
        [RaftDecl('color', _v37)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="panel-action"]',
        ['dark', 'width<768'],
        2000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:**:data-[slot=panel-meta]:text-foreground-on-frame-muted',
    2136,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="panel-meta"]',
        ['width<768'],
        2000,
        [RaftDecl('color', _v38)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="panel-meta"]',
        ['dark', 'width<768'],
        2000,
        [RaftDecl('color', _v39)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:**:data-[slot=panel-title]:text-foreground-on-frame',
    2137,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="panel-title"]',
        ['width<768'],
        2000,
        [RaftDecl('color', _v37)],
      ),
      RaftLayer(
        ':is(& *)[data-slot="panel-title"]',
        ['dark', 'width<768'],
        2000,
        [RaftDecl('color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'max-md:*:data-[slot=panel-header-icon]:hidden',
    2135,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="panel-header-icon"]',
        ['width<768'],
        2000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:*:data-[slot=tabs-list]:px-4',
    2138,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="tabs-list"]',
        ['width<768'],
        2000,
        [
          RaftDecl('padding-left', CssNum(16, 'px')),
          RaftDecl('padding-right', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('max-md:bg-layer-canvas', 2123, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('background-color', _v361)],
    ),
    RaftLayer(
      'self',
      ['dark', 'width<768'],
      1000,
      [RaftDecl('background-color', _v128)],
    ),
  ]),
  RaftUtility('max-md:bg-layer-frame', 2124, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('background-color', _v366)],
    ),
    RaftLayer(
      'self',
      ['dark', 'width<768'],
      1000,
      [RaftDecl('background-color', _v367)],
    ),
  ]),
  RaftUtility('max-md:border-l-0', 2122, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('border-left-style', _v16),
        RaftDecl('border-left-width', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:flex-col', 2118, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('flex-direction', CssKeyword('column'))],
    ),
  ]),
  RaftUtility('max-md:font-semibold', 2130, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('--tw-font-weight', CssNum(600)),
        RaftDecl('font-weight', CssNum(600)),
      ],
    ),
  ]),
  RaftUtility('max-md:gap-0', 2120, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('row-gap', CssNum(0, 'px')),
        RaftDecl('column-gap', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:gap-2', 2121, RaftUtilityStatus.resolved, [
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
  RaftUtility('max-md:h-auto', 2115, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('height', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility('max-md:hidden', 2114, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('display', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('max-md:items-end', 2119, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('align-items', CssKeyword('flex-end'))],
    ),
  ]),
  RaftUtility('max-md:max-w-none', 2117, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('max-width', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('max-md:min-h-11', 2116, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('min-height', CssNum(44, 'px'))],
    ),
  ]),
  RaftUtility(
    'max-md:pb-[calc(env(safe-area-inset-bottom)+0.5rem)]',
    2128,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width<768'],
        1000,
        [RaftDecl('padding-bottom', CssCalc(_v658))],
      ),
    ],
  ),
  RaftUtility(
    'max-md:pt-[env(safe-area-inset-top,0px)]',
    2127,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['width<768'], 1000, [RaftDecl('padding-top', _v74)]),
    ],
  ),
  RaftUtility('max-md:px-4', 2125, RaftUtilityStatus.resolved, [
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
  RaftUtility('max-md:py-2.5', 2126, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [
        RaftDecl('padding-top', CssNum(10, 'px')),
        RaftDecl('padding-bottom', CssNum(10, 'px')),
      ],
    ),
  ]),
  RaftUtility('max-md:sticky', 2111, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('position', CssKeyword('sticky'))],
    ),
  ]),
  RaftUtility('max-md:text-body', 2129, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width<768'],
      1000,
      [RaftDecl('font-size', CssNum(16, 'px')), RaftDecl('line-height', _v659)],
    ),
    RaftLayer(
      'self',
      ['pointer-fine', 'width<768', 'width>=768'],
      1000,
      [RaftDecl('font-size', CssNum(14, 'px')), RaftDecl('line-height', _v660)],
    ),
  ]),
  RaftUtility(
    'max-md:text-foreground-on-frame',
    2131,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', ['width<768'], 1000, [RaftDecl('color', _v37)]),
      RaftLayer('self', ['dark', 'width<768'], 1000, [RaftDecl('color', _v1)]),
    ],
  ),
  RaftUtility('max-md:top-0', 2112, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['width<768'], 1000, [RaftDecl('top', CssNum(0, 'px'))]),
  ]),
  RaftUtility('max-md:z-chrome', 2113, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['width<768'], 1000, [RaftDecl('z-index', CssNum(35))]),
  ]),
  RaftUtility('max-w-(--available-width)', 342, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', _v661)]),
  ]),
  RaftUtility('max-w-1/2', 343, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(50, '%'))]),
  ]),
  RaftUtility('max-w-100', 350, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(400, 'px'))]),
  ]),
  RaftUtility('max-w-160', 351, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(640, 'px'))]),
  ]),
  RaftUtility('max-w-28', 345, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(112, 'px'))]),
  ]),
  RaftUtility('max-w-40', 346, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(160, 'px'))]),
  ]),
  RaftUtility('max-w-44', 347, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(176, 'px'))]),
  ]),
  RaftUtility('max-w-4xl', 344, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(896, 'px'))]),
  ]),
  RaftUtility('max-w-60', 348, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(240, 'px'))]),
  ]),
  RaftUtility('max-w-80', 349, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(320, 'px'))]),
  ]),
  RaftUtility('max-w-[256px]', 356, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(256, 'px'))]),
  ]),
  RaftUtility('max-w-[26rem]', 352, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(416, 'px'))]),
  ]),
  RaftUtility('max-w-[280px]', 357, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(280, 'px'))]),
  ]),
  RaftUtility('max-w-[300px]', 358, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(300, 'px'))]),
  ]),
  RaftUtility('max-w-[33%]', 353, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(33, '%'))]),
  ]),
  RaftUtility('max-w-[360px]', 359, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(360, 'px'))]),
  ]),
  RaftUtility('max-w-[400px]', 360, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(400, 'px'))]),
  ]),
  RaftUtility('max-w-[420px]', 361, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(420, 'px'))]),
  ]),
  RaftUtility('max-w-[45%]', 354, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(45, '%'))]),
  ]),
  RaftUtility('max-w-[560px]', 362, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(560, 'px'))]),
  ]),
  RaftUtility('max-w-[86vw]', 355, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(86, 'vw'))]),
  ]),
  RaftUtility('max-w-[calc(100%-1.5rem)]', 363, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssCalc(_v662))]),
  ]),
  RaftUtility('max-w-[calc(100vw-48px)]', 364, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssCalc(_v663))]),
  ]),
  RaftUtility('max-w-[min(100%,24em)]', 367, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', _v664)]),
  ]),
  RaftUtility(
    'max-w-[min(20rem,var(--available-width,20rem))]',
    365,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('max-width', _v666)]),
    ],
  ),
  RaftUtility(
    'max-w-[min(24rem,var(--available-width,calc(100vw-2rem)))]',
    366,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('max-width', _v669)]),
    ],
  ),
  RaftUtility('max-w-[min(360px,100%)]', 368, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', _v670)]),
  ]),
  RaftUtility(
    'max-w-[min(var(--available-width),max(var(--anchor-width),24rem))]',
    369,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('max-width', _v673)]),
    ],
  ),
  RaftUtility('max-w-full', 370, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(100, '%'))]),
  ]),
  RaftUtility('max-w-max', 371, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', _v546)]),
  ]),
  RaftUtility('max-w-md', 372, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(448, 'px'))]),
  ]),
  RaftUtility('max-w-none', 373, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssKeyword('none'))]),
  ]),
  RaftUtility('max-w-sm', 374, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(384, 'px'))]),
  ]),
  RaftUtility('max-w-xl', 375, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('max-width', CssNum(576, 'px'))]),
  ]),
  RaftUtility('mb-0', 146, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(0, 'px'))]),
  ]),
  RaftUtility('mb-0.5', 147, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(2, 'px'))]),
  ]),
  RaftUtility('mb-1', 148, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(4, 'px'))]),
  ]),
  RaftUtility('mb-2', 149, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(8, 'px'))]),
  ]),
  RaftUtility('mb-3', 150, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(12, 'px'))]),
  ]),
  RaftUtility('mb-4', 151, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(16, 'px'))]),
  ]),
  RaftUtility(
    'mb-[calc(var(--control-embedded-inset)-9px)]',
    152,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssCalc(_v674))]),
    ],
  ),
  RaftUtility(
    'mb-[calc(var(--spacing-timeline-row)-(--spacing(7)-var(--text-mono-meta--line-height))/2)]',
    153,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssCalc(_v675))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('margin-bottom', CssCalc(_v676))],
      ),
    ],
  ),
  RaftUtility('mb-px', 154, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-bottom', CssNum(1, 'px'))]),
  ]),
  RaftUtility(
    'md:[@media(max-height:600px)]:py-0',
    2650,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssNum(0, 'px')),
          RaftDecl('padding-bottom', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:[@media(max-height:600px)]:py-[calc((var(--row-height)-20px)/2)]',
    2651,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['height<=600', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssCalc(_v678)),
          RaftDecl('padding-bottom', CssCalc(_v678)),
        ],
      ),
      RaftLayer(
        'self',
        ['height<=600', 'pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssNum(7, 'px')),
          RaftDecl('padding-bottom', CssNum(7, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('md:border-r', 2152, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('border-right-style', _v16),
        RaftDecl('border-right-width', CssNum(1, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:flex', 2141, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('display', CssKeyword('flex'))],
    ),
  ]),
  RaftUtility('md:flex-1', 2144, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['width>=768'], 1000, [RaftDecl('flex', CssNum(1))]),
  ]),
  RaftUtility('md:flex-row', 2147, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('flex-direction', CssKeyword('row'))],
    ),
  ]),
  RaftUtility('md:gap-2', 2150, RaftUtilityStatus.resolved, [
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
  RaftUtility('md:items-baseline', 2148, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('align-items', CssKeyword('baseline'))],
    ),
  ]),
  RaftUtility('md:justify-start', 2149, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('justify-content', _v61)],
    ),
  ]),
  RaftUtility(
    'md:max-h-[calc(100dvh-var(--dialog-top,8vh)-16px)]',
    2142,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width>=768'],
        1000,
        [RaftDecl('max-height', CssCalc(_v681))],
      ),
    ],
  ),
  RaftUtility('md:max-w-md', 2143, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('max-width', CssNum(448, 'px'))],
    ),
  ]),
  RaftUtility('md:me-2', 2140, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('margin-right', CssNum(8, 'px'))],
    ),
  ]),
  RaftUtility('md:overflow-clip', 2151, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('overflow-x', CssKeyword('clip')),
        RaftDecl('overflow-y', CssKeyword('clip')),
      ],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:**:data-[slot=button]:after:inset-x-[-3px]',
    2333,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="button"]::after',
        ['pointer-fine', 'width>=768'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', CssNum(-3, 'px')),
          RaftDecl('right', CssNum(-3, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:*:data-[slot=avatar]:mr-[-3px]',
    2332,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="avatar"]',
        ['pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('margin-right', CssNum(-3, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:*:data-[slot=tabs-list]:data-[variant=default]:py-[calc((var(--header-height)-1px-var(--control-height))/2)]',
    2335,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="tabs-list"][data-variant="default"]',
        ['pointer-fine', 'width>=768'],
        3000,
        [
          RaftDecl('padding-top', CssCalc(_v684)),
          RaftDecl('padding-bottom', CssCalc(_v684)),
        ],
      ),
      RaftLayer(
        ':is(& > *)[data-slot="tabs-list"][data-variant="default"]',
        ['pointer-fine', 'width>=768'],
        3000,
        [
          RaftDecl('padding-top', CssCalc(_v686)),
          RaftDecl('padding-bottom', CssCalc(_v686)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:*:data-[slot=tabs-list]:px-(--page-inset)',
    2334,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="tabs-list"]',
        ['pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('padding-left', _v687), RaftDecl('padding-right', _v687)],
      ),
      RaftLayer(
        ':is(& > *)[data-slot="tabs-list"]',
        ['pointer-fine', 'width>=768'],
        2000,
        [
          RaftDecl('padding-left', CssNum(16, 'px')),
          RaftDecl('padding-right', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:-mr-[calc((var(--bar-button-size)-18px)/2)]',
    2263,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('margin-right', CssCalc(_v690))],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('margin-right', CssNum(-5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:@min-[40rem]/tasks:py-0',
    2336,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['container:tasks (width >= 40rem)', 'pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssNum(0, 'px')),
          RaftDecl('padding-bottom', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:[&>[role=menuitem]]:size-control',
    2547,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > [role=menuitem]',
        ['pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('width', _v206), RaftDecl('height', _v206)],
      ),
      RaftLayer(
        '& > [role=menuitem]',
        ['pointer-fine', 'width>=768'],
        2000,
        [
          RaftDecl('width', CssNum(34, 'px')),
          RaftDecl('height', CssNum(34, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:[&_[data-slot=sidebar-group-label]]:px-2',
    2394,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& [data-slot=sidebar-group-label]',
        ['pointer-fine', 'width>=768'],
        2000,
        [
          RaftDecl('padding-left', CssNum(8, 'px')),
          RaftDecl('padding-right', CssNum(8, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:[--banner-button:var(--control-height)]',
    2307,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--banner-button', _v206)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--banner-button', CssNum(34, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:[--cell-pad-x:calc(var(--page-inset)-var(--cell-inset-x))]',
    2308,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--cell-pad-x', CssCalc(_v691))],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--cell-pad-x', CssCalc(_v692))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:[--column-margin:var(--page-inset)]',
    2309,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--column-margin', _v687)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--column-margin', CssNum(16, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:[--control-embedded-size:calc(var(--control-height)-2*var(--control-embedded-inset))]',
    2310,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--control-embedded-size', CssCalc(_v693))],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--control-embedded-size', CssCalc(_v694))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:[--icon-inset:calc((var(--bar-button-size)-var(--control-icon-size))/2)]',
    2311,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--icon-inset', CssCalc(_v205))],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--icon-inset', CssNum(5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:[--icon-inset:calc((var(--control-height)-18px)/2)]',
    2312,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--icon-inset', CssCalc(_v696))],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--icon-inset', CssNum(8, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:[--ig-hit:0px]',
    2313,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--ig-hit', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:[--segment-size:var(--control-height)]',
    2314,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--segment-size', _v206)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('--segment-size', CssNum(34, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:after:-end-[calc(var(--spacing-control-hit)+1.5px)]',
    2318,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('right', CssCalc(_v291)),
        ],
      ),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [RaftDecl('right', CssNum(-6.5, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:after:-inset-[calc((var(--control-height)+2*var(--control-hit-inset)-var(--bar-button-size))/2+1.5px)]',
    2315,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssCalc(_v289)),
          RaftDecl('right', CssCalc(_v289)),
          RaftDecl('bottom', CssCalc(_v289)),
          RaftDecl('left', CssCalc(_v289)),
        ],
      ),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('top', CssNum(-9.5, 'px')),
          RaftDecl('right', CssNum(-9.5, 'px')),
          RaftDecl('bottom', CssNum(-9.5, 'px')),
          RaftDecl('left', CssNum(-9.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:after:-inset-[calc(var(--control-hit-inset)+1.5px)]',
    2316,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssCalc(_v291)),
          RaftDecl('right', CssCalc(_v291)),
          RaftDecl('bottom', CssCalc(_v291)),
          RaftDecl('left', CssCalc(_v291)),
        ],
      ),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('top', CssNum(-6.5, 'px')),
          RaftDecl('right', CssNum(-6.5, 'px')),
          RaftDecl('bottom', CssNum(-6.5, 'px')),
          RaftDecl('left', CssNum(-6.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:after:-inset-e-[calc(--spacing(4)+1.5px)]',
    2319,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('right', CssNum(-17.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:after:-inset-y-[calc(var(--control-hit-inset)+1.5px)]',
    2317,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssCalc(_v291)),
          RaftDecl('bottom', CssCalc(_v291)),
        ],
      ),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('top', CssNum(-6.5, 'px')),
          RaftDecl('bottom', CssNum(-6.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:after:hidden',
    2322,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('display', CssKeyword('none')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:after:left-0',
    2321,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:after:right-[calc(-2*var(--control-hit-inset)-1.5px)]',
    2320,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('right', CssCalc(_v698)),
        ],
      ),
      RaftLayer(
        '::after',
        ['pointer-fine', 'width>=768'],
        1001,
        [RaftDecl('right', CssNum(-11.5, 'px'))],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:block', 2264, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('display', CssKeyword('block'))],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:data-fit-label:px-0',
    2330,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-fit-label', 'pointer-fine', 'width>=768'],
        2000,
        [
          RaftDecl('padding-left', CssNum(0, 'px')),
          RaftDecl('padding-right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:data-fit-label:w-(--control-height)',
    2329,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-fit-label', 'pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('width', _v206)],
      ),
      RaftLayer(
        'self',
        ['data-fit-label', 'pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('width', CssNum(34, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:data-fit-plus:w-(--control-height)',
    2331,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-fit-plus', 'pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('width', _v206)],
      ),
      RaftLayer(
        'self',
        ['data-fit-plus', 'pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('width', CssNum(34, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:first:pt-1.5',
    2323,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['first-child', 'pointer-fine', 'width>=768'],
        2000,
        [RaftDecl('padding-top', CssNum(6, 'px'))],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:flex', 2265, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('display', CssKeyword('flex'))],
    ),
  ]),
  RaftUtility('md:pointer-fine:gap-1', 2283, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('row-gap', CssNum(4, 'px')),
        RaftDecl('column-gap', CssNum(4, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:h-(--bar-button-size)',
    2270,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('height', _v203)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('height', CssNum(28, 'px'))],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:h-5', 2271, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(20, 'px'))],
    ),
  ]),
  RaftUtility('md:pointer-fine:h-6', 2272, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(24, 'px'))],
    ),
  ]),
  RaftUtility('md:pointer-fine:h-control', 2273, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', _v206)],
    ),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('height', CssNum(34, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:in-data-chevron-at-end:hidden',
    2324,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-chevron-at-end', 'pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:in-data-fit-label:hidden',
    2326,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-fit-label', 'pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('display', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:in-data-fit-label:sr-only',
    2325,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-fit-label', 'pointer-fine', 'width>=768'],
        1000,
        [
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
          RaftDecl('clip-path', _v88),
          RaftDecl('white-space', CssKeyword('nowrap')),
          RaftDecl('border-top-width', CssNum(0)),
          RaftDecl('border-right-width', CssNum(0)),
          RaftDecl('border-bottom-width', CssNum(0)),
          RaftDecl('border-left-width', CssNum(0)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:in-data-fit-label:w-(--control-height)',
    2327,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-fit-label', 'pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('width', _v206)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-fit-label', 'pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('width', CssNum(34, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:in-data-fit-plus:w-(--control-height)',
    2328,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['ancestor:data-fit-plus', 'pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('width', _v206)],
      ),
      RaftLayer(
        'self',
        ['ancestor:data-fit-plus', 'pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('width', CssNum(34, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:justify-center',
    2282,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('justify-content', CssKeyword('center'))],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:me-0', 2262, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('margin-right', CssNum(0, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:min-h-(--bar-button-size)',
    2274,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('min-height', _v203)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('min-height', CssNum(28, 'px'))],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:min-h-6', 2275, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('min-height', CssNum(24, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:min-h-control',
    2276,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('min-height', _v206)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('min-height', CssNum(34, 'px'))],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:min-w-6', 2281, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('min-width', CssNum(24, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:mx-[calc((var(--control-icon-size)-var(--bar-button-size))/2)]',
    2261,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('margin-left', CssCalc(_v700)),
          RaftDecl('margin-right', CssCalc(_v700)),
        ],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('margin-left', CssNum(-5, 'px')),
          RaftDecl('margin-right', CssNum(-5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:not-sr-only', 2259, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('position', CssKeyword('static')),
        RaftDecl('width', CssKeyword('auto')),
        RaftDecl('height', CssKeyword('auto')),
        RaftDecl('padding-top', CssNum(0)),
        RaftDecl('padding-right', CssNum(0)),
        RaftDecl('padding-bottom', CssNum(0)),
        RaftDecl('padding-left', CssNum(0)),
        RaftDecl('margin-top', CssNum(0)),
        RaftDecl('margin-right', CssNum(0)),
        RaftDecl('margin-bottom', CssNum(0)),
        RaftDecl('margin-left', CssNum(0)),
        RaftDecl('overflow-x', CssKeyword('visible')),
        RaftDecl('overflow-y', CssKeyword('visible')),
        RaftDecl('clip-path', CssKeyword('none')),
        RaftDecl('white-space', CssKeyword('normal')),
      ],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:p-(--page-inset)',
    2287,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', _v687),
          RaftDecl('padding-right', _v687),
          RaftDecl('padding-bottom', _v687),
          RaftDecl('padding-left', _v687),
        ],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssNum(16, 'px')),
          RaftDecl('padding-right', CssNum(16, 'px')),
          RaftDecl('padding-bottom', CssNum(16, 'px')),
          RaftDecl('padding-left', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:pb-1.5', 2302, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-bottom', CssNum(6, 'px'))],
    ),
  ]),
  RaftUtility('md:pointer-fine:pb-[5px]', 2303, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-bottom', CssNum(5, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:pl-(--sidebar-glyph-axis)',
    2304,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-left', _v687)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-left', CssNum(16, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:pl-(--sidebar-text-axis)',
    2305,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-left', CssCalc(_v701))],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-left', CssNum(40, 'px'))],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:pl-2.5', 2306, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-left', CssNum(10, 'px'))],
    ),
  ]),
  RaftUtility('md:pointer-fine:pr-2.5', 2299, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-right', CssNum(10, 'px'))],
    ),
  ]),
  RaftUtility('md:pointer-fine:pr-3', 2300, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-right', CssNum(12, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:pr-[calc(max(0px,calc(8px-var(--scrollbar-size,0px)))+10px)]',
    2301,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-right', CssCalc(_v704))],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:pt-1', 2296, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-top', CssNum(4, 'px'))],
    ),
  ]),
  RaftUtility('md:pointer-fine:pt-1.5', 2297, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-top', CssNum(6, 'px'))],
    ),
  ]),
  RaftUtility('md:pointer-fine:pt-2', 2298, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-top', CssNum(8, 'px'))],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:px-(--page-inset)',
    2288,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-left', _v687), RaftDecl('padding-right', _v687)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-left', CssNum(16, 'px')),
          RaftDecl('padding-right', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:px-(--sidebar-glyph-axis)',
    2289,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-left', _v687), RaftDecl('padding-right', _v687)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-left', CssNum(16, 'px')),
          RaftDecl('padding-right', CssNum(16, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:px-2', 2290, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(8, 'px')),
        RaftDecl('padding-right', CssNum(8, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:px-[calc((var(--bar-button-size)-var(--control-icon-size)-3px)/2)]',
    2291,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-left', CssCalc(_v706)),
          RaftDecl('padding-right', CssCalc(_v706)),
        ],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-left', CssNum(3.5, 'px')),
          RaftDecl('padding-right', CssNum(3.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:py-0', 2292, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('padding-top', CssNum(0, 'px')),
        RaftDecl('padding-bottom', CssNum(0, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:pointer-fine:py-2', 2293, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('padding-top', CssNum(8, 'px')),
        RaftDecl('padding-bottom', CssNum(8, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:py-[calc((var(--header-height)-1px-var(--control-height))/2)]',
    2294,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssCalc(_v684)),
          RaftDecl('padding-bottom', CssCalc(_v684)),
        ],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssCalc(_v686)),
          RaftDecl('padding-bottom', CssCalc(_v686)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:py-[calc((var(--header-height)-var(--control-height))/2)]',
    2295,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssCalc(_v708)),
          RaftDecl('padding-bottom', CssCalc(_v708)),
        ],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssCalc(_v710)),
          RaftDecl('padding-bottom', CssCalc(_v710)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:rounded-(--bar-button-radius)',
    2284,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('border-top-left-radius', _v711),
          RaftDecl('border-top-right-radius', _v711),
          RaftDecl('border-bottom-right-radius', _v711),
          RaftDecl('border-bottom-left-radius', _v711),
        ],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
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
    'md:pointer-fine:rounded-control',
    2285,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('border-top-left-radius', CssNum(8, 'px')),
          RaftDecl('border-top-right-radius', CssNum(8, 'px')),
          RaftDecl('border-bottom-right-radius', CssNum(8, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(8, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:rounded-sticker',
    2286,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('border-top-left-radius', CssNum(4, 'px')),
          RaftDecl('border-top-right-radius', CssNum(4, 'px')),
          RaftDecl('border-bottom-right-radius', CssNum(4, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(4, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:size-(--bar-button-size)',
    2266,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('width', _v203), RaftDecl('height', _v203)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('width', CssNum(28, 'px')),
          RaftDecl('height', CssNum(28, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:size-4', 2267, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('width', CssNum(16, 'px')),
        RaftDecl('height', CssNum(16, 'px')),
      ],
    ),
  ]),
  RaftUtility('md:pointer-fine:size-auto', 2268, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('width', CssKeyword('auto')),
        RaftDecl('height', CssKeyword('auto')),
      ],
    ),
  ]),
  RaftUtility(
    'md:pointer-fine:size-control',
    2269,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('width', _v206), RaftDecl('height', _v206)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('width', CssNum(34, 'px')),
          RaftDecl('height', CssNum(34, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:top-[calc(-1*(var(--control-height)+8px)/2)]',
    2260,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('top', CssCalc(_v714))],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('top', CssNum(-21, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'md:pointer-fine:w-(--control-height)',
    2277,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('width', _v206)],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('width', CssNum(34, 'px'))],
      ),
    ],
  ),
  RaftUtility('md:pointer-fine:w-5', 2278, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('width', CssNum(20, 'px'))],
    ),
  ]),
  RaftUtility('md:pointer-fine:w-7', 2279, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('width', CssNum(28, 'px'))],
    ),
  ]),
  RaftUtility('md:pointer-fine:w-auto', 2280, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('width', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility('md:py-0', 2153, RaftUtilityStatus.resolved, [
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
  RaftUtility(
    'md:py-[calc((var(--row-height)-20px)/2)]',
    2154,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssCalc(_v678)),
          RaftDecl('padding-bottom', CssCalc(_v678)),
        ],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssNum(7, 'px')),
          RaftDecl('padding-bottom', CssNum(7, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('md:shrink-1000', 2145, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('flex-shrink', CssNum(1000))],
    ),
  ]),
  RaftUtility('md:top-(--dialog-top,8vh)', 2139, RaftUtilityStatus.resolved, [
    RaftLayer('self', ['width>=768'], 1000, [RaftDecl('top', _v679)]),
  ]),
  RaftUtility('md:translate-y-0', 2146, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('--tw-translate-y', CssNum(0, 'px')),
        RaftDecl('translate', CssSeq([_v84, _v85])),
      ],
    ),
  ]),
  RaftUtility('md:whitespace-nowrap', 2155, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [RaftDecl('white-space', CssKeyword('nowrap'))],
    ),
  ]),
  RaftUtility('me-5', 124, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssNum(20, 'px'))]),
  ]),
  RaftUtility(
    'min-h-(--card-title-line-height)',
    280,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('min-height', _v715)]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('min-height', CssNum(22, 'px'))],
      ),
    ],
  ),
  RaftUtility('min-h-(--header-height)', 281, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', _v222)]),
  ]),
  RaftUtility('min-h-(--row-height)', 282, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', _v560)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('min-height', CssNum(34, 'px'))],
    ),
  ]),
  RaftUtility('min-h-0', 283, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(0, 'px'))]),
  ]),
  RaftUtility('min-h-10', 288, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(40, 'px'))]),
  ]),
  RaftUtility('min-h-11', 289, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(44, 'px'))]),
  ]),
  RaftUtility('min-h-13', 290, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(52, 'px'))]),
  ]),
  RaftUtility('min-h-16', 291, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(64, 'px'))]),
  ]),
  RaftUtility('min-h-5', 284, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(20, 'px'))]),
  ]),
  RaftUtility('min-h-6', 285, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(24, 'px'))]),
  ]),
  RaftUtility('min-h-64', 292, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(256, 'px'))]),
  ]),
  RaftUtility('min-h-7', 286, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(28, 'px'))]),
  ]),
  RaftUtility('min-h-8', 287, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(32, 'px'))]),
  ]),
  RaftUtility(
    'min-h-[calc(var(--field-line-height)*3+--spacing(6))]',
    293,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('min-height', CssCalc(_v718))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('min-height', CssNum(90, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'min-h-[calc(var(--spacing-option)+var(--text-mono-meta--line-height)+(--spacing(2)))]',
    294,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('min-height', CssCalc(_v720))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('min-height', CssNum(60, 'px'))],
      ),
    ],
  ),
  RaftUtility('min-h-control', 295, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', _v206)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('min-height', CssNum(34, 'px'))],
    ),
  ]),
  RaftUtility('min-h-dvh', 296, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(100, 'dvh'))]),
  ]),
  RaftUtility('min-h-full', 297, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', CssNum(100, '%'))]),
  ]),
  RaftUtility('min-h-option', 298, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-height', _v559)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('min-height', CssNum(34, 'px'))],
    ),
  ]),
  RaftUtility('min-w-(--bar-button-size)', 376, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', _v203)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('min-width', CssNum(28, 'px'))],
    ),
  ]),
  RaftUtility('min-w-(--fit-search-min)', 377, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', _v721)]),
  ]),
  RaftUtility('min-w-0', 378, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(0, 'px'))]),
  ]),
  RaftUtility('min-w-3', 379, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(12, 'px'))]),
  ]),
  RaftUtility('min-w-36', 385, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(144, 'px'))]),
  ]),
  RaftUtility('min-w-4', 380, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(16, 'px'))]),
  ]),
  RaftUtility('min-w-4.5', 381, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(18, 'px'))]),
  ]),
  RaftUtility('min-w-40', 386, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(160, 'px'))]),
  ]),
  RaftUtility('min-w-44', 387, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(176, 'px'))]),
  ]),
  RaftUtility('min-w-5', 382, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(20, 'px'))]),
  ]),
  RaftUtility('min-w-6', 383, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(24, 'px'))]),
  ]),
  RaftUtility('min-w-60', 388, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(240, 'px'))]),
  ]),
  RaftUtility('min-w-8', 384, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(32, 'px'))]),
  ]),
  RaftUtility('min-w-[160px]', 389, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(160, 'px'))]),
  ]),
  RaftUtility('min-w-[220px]', 390, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', CssNum(220, 'px'))]),
  ]),
  RaftUtility(
    'min-w-[max(var(--anchor-width),220px)]',
    391,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('min-width', _v722)]),
    ],
  ),
  RaftUtility('min-w-min', 392, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('min-width', _v314)]),
  ]),
  RaftUtility('ml-0', 156, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-left', CssNum(0, 'px'))]),
  ]),
  RaftUtility('ml-auto', 157, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-left', CssKeyword('auto'))]),
  ]),
  RaftUtility(
    'motion-reduce:**:data-[slot=copyable-code-icon]:transition-none',
    2110,
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
    'motion-reduce:[&>svg]:transition-none',
    2608,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& > svg',
        ['motion-reduce'],
        1001,
        [RaftDecl('transition-property', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility('motion-reduce:animate-none', 2108, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['motion-reduce'],
      1000,
      [RaftDecl('animation', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('motion-reduce:scale-x-100', 2106, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['motion-reduce'],
      1000,
      [RaftDecl('--tw-scale-x', CssNum(100, '%')), RaftDecl('scale', _v427)],
    ),
  ]),
  RaftUtility(
    'motion-reduce:transform-none',
    2107,
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
    2109,
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
  RaftUtility('mr-1', 144, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssNum(4, 'px'))]),
  ]),
  RaftUtility('mr-1.5', 145, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-right', CssNum(6, 'px'))]),
  ]),
  RaftUtility('ms-1', 120, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-left', CssNum(4, 'px'))]),
  ]),
  RaftUtility('ms-auto', 121, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-left', CssKeyword('auto'))]),
  ]),
  RaftUtility('mt-0', 130, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(0, 'px'))]),
  ]),
  RaftUtility('mt-0.5', 131, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(2, 'px'))]),
  ]),
  RaftUtility('mt-1', 132, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(4, 'px'))]),
  ]),
  RaftUtility('mt-1.5', 133, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(6, 'px'))]),
  ]),
  RaftUtility('mt-2', 134, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(8, 'px'))]),
  ]),
  RaftUtility('mt-3', 135, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(12, 'px'))]),
  ]),
  RaftUtility('mt-4', 136, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(16, 'px'))]),
  ]),
  RaftUtility('mt-5', 137, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssNum(20, 'px'))]),
  ]),
  RaftUtility('mt-[calc((27px-1lh)/2)]', 138, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssCalc(_v724))]),
  ]),
  RaftUtility('mt-auto', 139, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssKeyword('auto'))]),
  ]),
  RaftUtility('mt-option-inset', 140, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('margin-top', CssCalc(_v726))]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('margin-top', CssCalc(_v728))],
    ),
  ]),
  RaftUtility('mx-0.5', 108, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-left', CssNum(2, 'px')),
      RaftDecl('margin-right', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility(
    'mx-[calc(var(--control-embedded-inset)-0.75rem-1px)]',
    109,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('margin-left', CssCalc(_v100)),
        RaftDecl('margin-right', CssCalc(_v100)),
      ]),
    ],
  ),
  RaftUtility('mx-auto', 110, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-left', CssKeyword('auto')),
      RaftDecl('margin-right', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('my-0', 114, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(0, 'px')),
      RaftDecl('margin-bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('my-1', 115, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(4, 'px')),
      RaftDecl('margin-bottom', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('my-2', 116, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(8, 'px')),
      RaftDecl('margin-bottom', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('my-3', 117, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssNum(12, 'px')),
      RaftDecl('margin-bottom', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('my-auto', 118, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', CssKeyword('auto')),
      RaftDecl('margin-bottom', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('my-timeline-row', 119, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('margin-top', _v399),
      RaftDecl('margin-bottom', _v399),
    ]),
  ]),
  RaftUtility('narrow-dialog-enter', -1, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('animation', _v730)]),
    RaftLayer(
      'self',
      ['motion-reduce'],
      1000,
      [RaftDecl('animation', CssKeyword('none'))],
    ),
  ]),
  RaftUtility('no-underline', 899, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-decoration-line', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('normal-case', 896, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-transform', CssKeyword('none')),
    ]),
  ]),
  RaftUtility(
    'not-aria-selected:not-data-[selected=true]:data-popup-open:bg-fill-subtle',
    1755,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open', 'not:aria-selected=true', 'not:data-selected=true'],
        4000,
        [RaftDecl('background-color', _v113)],
      ),
      RaftLayer(
        'self',
        [
          'dark',
          'data-popup-open',
          'not:aria-selected=true',
          'not:data-selected=true',
        ],
        4000,
        [RaftDecl('background-color', _v114)],
      ),
    ],
  ),
  RaftUtility(
    'not-aria-selected:not-data-[selected=true]:has-data-popup-open:bg-fill-subtle',
    1485,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'has:data-popup-open',
          'not:aria-selected=true',
          'not:data-selected=true',
        ],
        4000,
        [RaftDecl('background-color', _v113)],
      ),
      RaftLayer(
        'self',
        [
          'dark',
          'has:data-popup-open',
          'not:aria-selected=true',
          'not:data-selected=true',
        ],
        4000,
        [RaftDecl('background-color', _v114)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-[density=compact]:has-data-[slot=inbox-item-trailing]:[--inbox-item-content-display:grid]',
    1503,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-trailing', 'not:data-density=compact'],
        3000,
        [RaftDecl('--inbox-item-content-display', CssKeyword('grid'))],
      ),
    ],
  ),
  RaftUtility(
    'not-data-[density=compact]:has-data-[slot=inbox-item-trailing]:[--inbox-item-content-end:-1]',
    1504,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:data-slot=inbox-item-trailing', 'not:data-density=compact'],
        3000,
        [RaftDecl('--inbox-item-content-end', CssNum(-1))],
      ),
    ],
  ),
  RaftUtility(
    'not-data-[frame=bar]:*:data-[slot=message-embed-content]:first:overflow-clip',
    1984,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="message-embed-content"]:first-child',
        ['not:data-frame=bar'],
        4000,
        [
          RaftDecl('overflow-x', CssKeyword('clip')),
          RaftDecl('overflow-y', CssKeyword('clip')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-data-[frame=bar]:*:data-[slot=message-embed-content]:first:rounded-t-[calc(var(--radius-container)-1px)]',
    1985,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="message-embed-content"]:first-child',
        ['not:data-frame=bar'],
        4000,
        [
          RaftDecl('border-top-left-radius', CssNum(9, 'px')),
          RaftDecl('border-top-right-radius', CssNum(9, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-data-[frame=bar]:*:data-[slot=message-embed-content]:last:overflow-clip',
    1986,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="message-embed-content"]:last-child',
        ['not:data-frame=bar'],
        4000,
        [
          RaftDecl('overflow-x', CssKeyword('clip')),
          RaftDecl('overflow-y', CssKeyword('clip')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-data-[frame=bar]:*:data-[slot=message-embed-content]:last:rounded-b-[calc(var(--radius-container)-1px)]',
    1987,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="message-embed-content"]:last-child',
        ['not:data-frame=bar'],
        4000,
        [
          RaftDecl('border-bottom-right-radius', CssNum(9, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(9, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-data-[icon-kind=avatar]:[&_svg]:size-3.5',
    2467,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& svg',
        ['not:data-icon-kind=avatar'],
        2001,
        [
          RaftDecl('width', CssNum(14, 'px')),
          RaftDecl('height', CssNum(14, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-data-[icon-kind=avatar]:[&_svg]:stroke-2',
    2468,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        '& svg',
        ['not:data-icon-kind=avatar'],
        2001,
        [RaftDecl('stroke-width', CssNum(2))],
      ),
    ],
  ),
  RaftUtility(
    'not-data-active:data-[tone=away]:text-foreground-hint',
    2076,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-tone=away', 'not:data-active'],
        3000,
        [RaftDecl('color', _v44)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-tone=away', 'not:data-active'],
        3000,
        [RaftDecl('color', _v39)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-active:data-[tone=muted]:text-foreground-muted',
    2079,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-tone=muted', 'not:data-active'],
        3000,
        [RaftDecl('color', _v2)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-tone=muted', 'not:data-active'],
        3000,
        [RaftDecl('color', _v3)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-active:focus-visible:keyboard:before:inset-ring-2',
    2352,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        [
          'focus-visible',
          'not:data-active',
          'not:in:root+data-input-modality=pointer',
        ],
        3001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-inset-ring-shadow', _v136),
          RaftDecl('box-shadow', _v27),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-data-active:focus-visible:keyboard:before:inset-ring-foreground',
    2353,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        [
          'focus-visible',
          'not:data-active',
          'not:in:root+data-input-modality=pointer',
        ],
        3001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('--tw-inset-ring-color', _v0),
        ],
      ),
      RaftLayer(
        '::before',
        [
          'dark',
          'focus-visible',
          'not:data-active',
          'not:in:root+data-input-modality=pointer',
        ],
        3001,
        [RaftDecl('--tw-inset-ring-color', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-active:not-data-selected:data-popup-open:before:bg-fill-cell-hover',
    1757,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['data-popup-open', 'not:data-active', 'not:data-selected'],
        4001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v731),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'data-popup-open', 'not:data-active', 'not:data-selected'],
        4001,
        [RaftDecl('background-color', _v732)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-active:not-data-selected:has-data-popup-open:before:bg-fill-cell-hover',
    1486,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        ['has:data-popup-open', 'not:data-active', 'not:data-selected'],
        4001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v731),
        ],
      ),
      RaftLayer(
        '::before',
        ['dark', 'has:data-popup-open', 'not:data-active', 'not:data-selected'],
        4001,
        [RaftDecl('background-color', _v732)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-active:not-data-selected:not-data-disabled:not-disabled:not-aria-disabled:active:before:bg-fill-cell-press',
    1403,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        [
          'active',
          'not:aria-disabled=true',
          'not:data-active',
          'not:data-disabled',
          'not:data-selected',
          'not:disabled',
        ],
        7001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v733),
        ],
      ),
      RaftLayer(
        '::before',
        [
          'active',
          'dark',
          'not:aria-disabled=true',
          'not:data-active',
          'not:data-disabled',
          'not:data-selected',
          'not:disabled',
        ],
        7001,
        [RaftDecl('background-color', _v734)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-active:not-data-selected:not-data-disabled:not-disabled:not-aria-disabled:hover:before:bg-fill-cell-hover',
    1371,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::before',
        [
          'hover',
          'not:aria-disabled=true',
          'not:data-active',
          'not:data-disabled',
          'not:data-selected',
          'not:disabled',
        ],
        7001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('background-color', _v731),
        ],
      ),
      RaftLayer(
        '::before',
        [
          'dark',
          'hover',
          'not:aria-disabled=true',
          'not:data-active',
          'not:data-disabled',
          'not:data-selected',
          'not:disabled',
        ],
        7001,
        [RaftDecl('background-color', _v732)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-disabled:active:overlay-medium',
    1399,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['active', 'not:data-disabled'],
        3000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['active', 'dark', 'not:data-disabled'],
        3000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-disabled:cursor-pointer',
    1104,
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
    'not-data-disabled:hover:bg-brand-soft',
    1364,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:data-disabled'],
        3000,
        [RaftDecl('background-color', _v275)],
      ),
      RaftLayer(
        'self',
        ['dark', 'hover', 'not:data-disabled'],
        3000,
        [RaftDecl('background-color', _v276)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-located:hover:[--mi-row-fill:var(--fill-subtle)]',
    1365,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:data-located'],
        3000,
        [RaftDecl('--mi-row-fill', _v113)],
      ),
      RaftLayer(
        'self',
        ['dark', 'hover', 'not:data-located'],
        3000,
        [RaftDecl('--mi-row-fill', _v114)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-measured:**:data-[slot=button]:transition-none',
    1930,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="button"]',
        ['not:data-measured'],
        3000,
        [RaftDecl('transition-property', CssKeyword('none'))],
      ),
    ],
  ),
  RaftUtility(
    'not-data-recording:hover:inset-ring',
    1367,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:data-recording'],
        3000,
        [
          RaftDecl('--tw-inset-ring-shadow', _v493),
          RaftDecl('box-shadow', _v27),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-data-recording:hover:inset-ring-line-hairline',
    1368,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:data-recording'],
        3000,
        [RaftDecl('--tw-inset-ring-color', _v252)],
      ),
      RaftLayer(
        'self',
        ['dark', 'hover', 'not:data-recording'],
        3000,
        [RaftDecl('--tw-inset-ring-color', _v253)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-recording:hover:overlay-medium',
    1366,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:data-recording'],
        3000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        ['dark', 'hover', 'not:data-recording'],
        3000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    'not-data-selected:data-popup-open:overlay-subtle',
    1754,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-popup-open', 'not:data-selected'],
        3000,
        [RaftDecl('background-image', _v237)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-popup-open', 'not:data-selected'],
        3000,
        [RaftDecl('background-image', _v238)],
      ),
    ],
  ),
  RaftUtility(
    'not-disabled:hover:underline',
    1362,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:disabled'],
        3000,
        [RaftDecl('text-decoration-line', CssKeyword('underline'))],
      ),
    ],
  ),
  RaftUtility(
    'not-disabled:not-aria-disabled:data-[tone=away]:[--list-row-ink-2:var(--foreground-hint)]',
    2074,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-tone=away', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-ink-2', _v44)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-tone=away', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-ink-2', _v39)],
      ),
    ],
  ),
  RaftUtility(
    'not-disabled:not-aria-disabled:data-[tone=away]:[--list-row-ink:var(--foreground-hint)]',
    2075,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-tone=away', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-ink', _v44)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-tone=away', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-ink', _v39)],
      ),
    ],
  ),
  RaftUtility(
    'not-disabled:not-aria-disabled:data-[tone=danger]:[--list-row-risk-ink:var(--danger-strong)]',
    2077,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-tone=danger', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-risk-ink', _v392)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-tone=danger', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-risk-ink', _v393)],
      ),
    ],
  ),
  RaftUtility(
    'not-disabled:not-aria-disabled:data-[tone=muted]:[--list-row-ink:var(--foreground-muted)]',
    2078,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-tone=muted', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-ink', _v2)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-tone=muted', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-ink', _v3)],
      ),
    ],
  ),
  RaftUtility(
    'not-disabled:not-aria-disabled:data-[tone=unread]:[--list-row-ink-2:var(--foreground)]',
    2080,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-tone=unread', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-ink-2', _v0)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-tone=unread', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-ink-2', _v1)],
      ),
    ],
  ),
  RaftUtility(
    'not-disabled:not-aria-disabled:data-[tone=warning]:[--list-row-risk-ink:var(--warning-strong)]',
    2081,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-tone=warning', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-risk-ink', _v214)],
      ),
      RaftLayer(
        'self',
        ['dark', 'data-tone=warning', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('--list-row-risk-ink', _v215)],
      ),
    ],
  ),
  RaftUtility(
    'not-disabled:not-aria-disabled:hover:underline',
    1363,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['hover', 'not:aria-disabled=true', 'not:disabled'],
        4000,
        [RaftDecl('text-decoration-line', CssKeyword('underline'))],
      ),
    ],
  ),
  RaftUtility(
    'not-disabled:not-aria-disabled:not-data-selected:active:overlay-medium',
    1400,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'active',
          'not:aria-disabled=true',
          'not:data-selected',
          'not:disabled',
        ],
        5000,
        [RaftDecl('background-image', _v257)],
      ),
      RaftLayer(
        'self',
        [
          'active',
          'dark',
          'not:aria-disabled=true',
          'not:data-selected',
          'not:disabled',
        ],
        5000,
        [RaftDecl('background-image', _v258)],
      ),
    ],
  ),
  RaftUtility(
    'not-disabled:not-aria-disabled:not-data-selected:hover:overlay-subtle',
    1369,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        [
          'hover',
          'not:aria-disabled=true',
          'not:data-selected',
          'not:disabled',
        ],
        5000,
        [RaftDecl('background-image', _v237)],
      ),
      RaftLayer(
        'self',
        [
          'dark',
          'hover',
          'not:aria-disabled=true',
          'not:data-selected',
          'not:disabled',
        ],
        5000,
        [RaftDecl('background-image', _v238)],
      ),
    ],
  ),
  RaftUtility('not-first:before:block', 1261, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::before',
      ['not:first-child'],
      2001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('display', CssKeyword('block')),
      ],
    ),
  ]),
  RaftUtility('not-italic', 897, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-style', CssKeyword('normal'))]),
  ]),
  RaftUtility('not-last:border-r', 1103, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['not:last-child'],
      2000,
      [
        RaftDecl('border-right-style', _v16),
        RaftDecl('border-right-width', CssNum(1, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'not-pointer-fine:after:absolute',
    1319,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['not:pointer-fine'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('position', CssKeyword('absolute')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-pointer-fine:after:content-[\'\']',
    1321,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['not:pointer-fine'],
        1001,
        [
          RaftDecl('--tw-content', CssString('')),
          RaftDecl('content', CssVar('--tw-content')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-pointer-fine:after:inset-[-11px]',
    1320,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['not:pointer-fine'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-11, 'px')),
          RaftDecl('right', CssNum(-11, 'px')),
          RaftDecl('bottom', CssNum(-11, 'px')),
          RaftDecl('left', CssNum(-11, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-pointer-fine:not-first:after:left-[-3px]',
    1322,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['not:first-child', 'not:pointer-fine'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', CssNum(-3, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'not-pointer-fine:not-last:after:right-[-3px]',
    1323,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['not:last-child', 'not:pointer-fine'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('right', CssNum(-3, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('not-pointer-fine:pb-1.5', 1110, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['not:pointer-fine'],
      1000,
      [RaftDecl('padding-bottom', CssNum(6, 'px'))],
    ),
  ]),
  RaftUtility('nth-[-n+2]:col-[1/2]', 2093, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['nth-child(-n+2)'],
      2000,
      [RaftDecl('grid-column', _v735)],
    ),
  ]),
  RaftUtility(
    'nth-[3n+2]:[--inbox-item-skeleton-body:70%]',
    2099,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['nth-child(3n+2)'],
        2000,
        [RaftDecl('--inbox-item-skeleton-body', CssNum(70, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'nth-[3n+2]:[--inbox-item-skeleton-context:4rem]',
    2100,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['nth-child(3n+2)'],
        2000,
        [RaftDecl('--inbox-item-skeleton-context', CssNum(64, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'nth-[3n+2]:[--inbox-item-skeleton-title:45%]',
    2101,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['nth-child(3n+2)'],
        2000,
        [RaftDecl('--inbox-item-skeleton-title', CssNum(45, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'nth-[3n+2]:[--list-row-skeleton-description:60%]',
    2102,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['nth-child(3n+2)'],
        2000,
        [RaftDecl('--list-row-skeleton-description', CssNum(60, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'nth-[3n+2]:[--list-row-skeleton-title:35%]',
    2103,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['nth-child(3n+2)'],
        2000,
        [RaftDecl('--list-row-skeleton-title', CssNum(35, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'nth-[3n]:[--inbox-item-skeleton-body:75%]',
    2094,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['nth-child(3n)'],
        2000,
        [RaftDecl('--inbox-item-skeleton-body', CssNum(75, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'nth-[3n]:[--inbox-item-skeleton-context:6rem]',
    2095,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['nth-child(3n)'],
        2000,
        [RaftDecl('--inbox-item-skeleton-context', CssNum(96, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'nth-[3n]:[--inbox-item-skeleton-title:55%]',
    2096,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['nth-child(3n)'],
        2000,
        [RaftDecl('--inbox-item-skeleton-title', CssNum(55, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'nth-[3n]:[--list-row-skeleton-description:70%]',
    2097,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['nth-child(3n)'],
        2000,
        [RaftDecl('--list-row-skeleton-description', CssNum(70, '%'))],
      ),
    ],
  ),
  RaftUtility(
    'nth-[3n]:[--list-row-skeleton-title:55%]',
    2098,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['nth-child(3n)'],
        2000,
        [RaftDecl('--list-row-skeleton-title', CssNum(55, '%'))],
      ),
    ],
  ),
  RaftUtility('object-contain', 643, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('object-fit', CssKeyword('contain')),
    ]),
  ]),
  RaftUtility('object-cover', 644, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('object-fit', CssKeyword('cover'))]),
  ]),
  RaftUtility('only:col-auto', 1336, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['only-child'],
      2000,
      [RaftDecl('grid-column', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility('only:row-auto', 1337, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['only-child'],
      2000,
      [RaftDecl('grid-row', CssKeyword('auto'))],
    ),
  ]),
  RaftUtility(
    'opacity-(--mi-toolbar-opacity,0)',
    908,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('opacity', _v736)]),
    ],
  ),
  RaftUtility('opacity-0', 909, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(0, '%'))]),
  ]),
  RaftUtility('opacity-100', 913, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(100, '%'))]),
  ]),
  RaftUtility('opacity-20', 910, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(20, '%'))]),
  ]),
  RaftUtility('opacity-30', 911, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(30, '%'))]),
  ]),
  RaftUtility('opacity-60', 912, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('opacity', CssNum(60, '%'))]),
  ]),
  RaftUtility(
    'opacity-[max(var(--drawer-overlay-min-opacity,0),calc(1-var(--drawer-swipe-progress)))]',
    914,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('opacity', _v739)]),
    ],
  ),
  RaftUtility('order-1', 83, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('order', CssNum(1))]),
  ]),
  RaftUtility('order-2', 84, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('order', CssNum(2))]),
  ]),
  RaftUtility('order-first', 85, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('order', CssNum(-9999))]),
  ]),
  RaftUtility('order-last', 86, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('order', CssNum(9999))]),
  ]),
  RaftUtility(
    'origin-(--drawer-transform-origin)',
    407,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('transform-origin', _v740)]),
    ],
  ),
  RaftUtility('origin-(--transform-origin)', 408, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('transform-origin', _v741)]),
  ]),
  RaftUtility('origin-bottom', 409, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transform-origin', CssKeyword('bottom')),
    ]),
  ]),
  RaftUtility('origin-center', 410, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transform-origin', CssKeyword('center')),
    ]),
  ]),
  RaftUtility('origin-left', 411, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('transform-origin', CssNum(0))]),
  ]),
  RaftUtility('outline-1', 934, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('outline-style', _v516),
      RaftDecl('outline-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('outline-2', 935, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('outline-style', _v516),
      RaftDecl('outline-width', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('outline-[1px]', 936, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('outline-style', _v516),
      RaftDecl('outline-width', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('outline-layer-canvas', 938, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('outline-color', _v361)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('outline-color', _v128)]),
  ]),
  RaftUtility('outline-none', 976, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-outline-style', CssKeyword('none')),
      RaftDecl('outline-style', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('outline-offset-2', 937, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('outline-offset', CssNum(2, 'px'))]),
  ]),
  RaftUtility('outline-solid', 977, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-outline-style', CssKeyword('solid')),
      RaftDecl('outline-style', CssKeyword('solid')),
    ]),
  ]),
  RaftUtility('outline-transparent', 939, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('outline-color', _v15)]),
  ]),
  RaftUtility('overflow-clip', 513, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('clip')),
      RaftDecl('overflow-y', CssKeyword('clip')),
    ]),
  ]),
  RaftUtility('overflow-hidden', 514, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
    ]),
  ]),
  RaftUtility('overflow-visible', 515, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('visible')),
      RaftDecl('overflow-y', CssKeyword('visible')),
    ]),
  ]),
  RaftUtility('overflow-x-auto', 516, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('overflow-x', CssKeyword('auto'))]),
  ]),
  RaftUtility('overflow-x-hidden', 517, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('overflow-x', CssKeyword('hidden'))]),
  ]),
  RaftUtility('overflow-y-auto', 518, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('overflow-y', CssKeyword('auto'))]),
  ]),
  RaftUtility('overflow-y-hidden', 519, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('overflow-y', CssKeyword('hidden'))]),
  ]),
  RaftUtility('overscroll-contain', 520, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overscroll-behavior', CssKeyword('contain')),
    ]),
  ]),
  RaftUtility('overscroll-none', 521, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overscroll-behavior', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('p-0', 645, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(0, 'px')),
      RaftDecl('padding-right', CssNum(0, 'px')),
      RaftDecl('padding-bottom', CssNum(0, 'px')),
      RaftDecl('padding-left', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('p-1', 646, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(4, 'px')),
      RaftDecl('padding-right', CssNum(4, 'px')),
      RaftDecl('padding-bottom', CssNum(4, 'px')),
      RaftDecl('padding-left', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('p-1.5', 647, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(6, 'px')),
      RaftDecl('padding-right', CssNum(6, 'px')),
      RaftDecl('padding-bottom', CssNum(6, 'px')),
      RaftDecl('padding-left', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('p-2', 648, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(8, 'px')),
      RaftDecl('padding-right', CssNum(8, 'px')),
      RaftDecl('padding-bottom', CssNum(8, 'px')),
      RaftDecl('padding-left', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('p-3', 649, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(12, 'px')),
      RaftDecl('padding-right', CssNum(12, 'px')),
      RaftDecl('padding-bottom', CssNum(12, 'px')),
      RaftDecl('padding-left', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('p-4', 650, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(16, 'px')),
      RaftDecl('padding-right', CssNum(16, 'px')),
      RaftDecl('padding-bottom', CssNum(16, 'px')),
      RaftDecl('padding-left', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('p-5', 651, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(20, 'px')),
      RaftDecl('padding-right', CssNum(20, 'px')),
      RaftDecl('padding-bottom', CssNum(20, 'px')),
      RaftDecl('padding-left', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('p-[2.5px]', 652, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(2.5, 'px')),
      RaftDecl('padding-right', CssNum(2.5, 'px')),
      RaftDecl('padding-bottom', CssNum(2.5, 'px')),
      RaftDecl('padding-left', CssNum(2.5, 'px')),
    ]),
  ]),
  RaftUtility('p-[3px]', 653, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(3, 'px')),
      RaftDecl('padding-right', CssNum(3, 'px')),
      RaftDecl('padding-bottom', CssNum(3, 'px')),
      RaftDecl('padding-left', CssNum(3, 'px')),
    ]),
  ]),
  RaftUtility('pb-(--page-inset)', 736, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v687)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-bottom', CssNum(16, 'px'))],
    ),
  ]),
  RaftUtility(
    'pb-(--sidebar-content-bottom,8px)',
    737,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v742)]),
    ],
  ),
  RaftUtility('pb-(--surface-inset)', 738, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(20, 'px'))]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-bottom', CssNum(16, 'px'))],
    ),
  ]),
  RaftUtility('pb-0', 739, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(0, 'px'))]),
  ]),
  RaftUtility('pb-0.5', 740, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(2, 'px'))]),
  ]),
  RaftUtility('pb-1', 741, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(4, 'px'))]),
  ]),
  RaftUtility('pb-2', 742, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(8, 'px'))]),
  ]),
  RaftUtility('pb-3', 743, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(12, 'px'))]),
  ]),
  RaftUtility('pb-4', 744, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(16, 'px'))]),
  ]),
  RaftUtility('pb-5', 745, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(20, 'px'))]),
  ]),
  RaftUtility('pb-[5px]', 746, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssNum(5, 'px'))]),
  ]),
  RaftUtility(
    'pb-[calc(--spacing(3)+env(safe-area-inset-bottom))]',
    747,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssCalc(_v743))]),
    ],
  ),
  RaftUtility('pb-[calc(1px+0.0275em)]', 748, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssCalc(_v744))]),
  ]),
  RaftUtility(
    'pb-[calc(1rem+env(safe-area-inset-bottom,0px))]',
    749,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssCalc(_v745))]),
    ],
  ),
  RaftUtility(
    'pb-[calc(8px+env(safe-area-inset-bottom,0px))]',
    750,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssCalc(_v746))]),
    ],
  ),
  RaftUtility(
    'pb-[calc(env(safe-area-inset-bottom)+1rem)]',
    751,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssCalc(_v747))]),
    ],
  ),
  RaftUtility(
    'pb-[calc(var(--control-embedded-inset)-1px)]',
    752,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssCalc(_v408))]),
    ],
  ),
  RaftUtility(
    'pb-[calc(var(--spacing-timeline-section)-var(--spacing-timeline-lead)-var(--text-mono-meta--line-height)/2)]',
    753,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssCalc(_v750))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-bottom', CssCalc(_v751))],
      ),
    ],
  ),
  RaftUtility(
    'pb-[env(safe-area-inset-bottom,0px)]',
    754,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v125)]),
    ],
  ),
  RaftUtility(
    'pb-[max(16px,env(safe-area-inset-bottom,0px))]',
    756,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v126)]),
    ],
  ),
  RaftUtility(
    'pb-[max(8px,min(env(safe-area-inset-bottom,0px),34px))]',
    755,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v753)]),
    ],
  ),
  RaftUtility('pb-timeline-end', 757, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', CssCalc(_v754))]),
  ]),
  RaftUtility('pb-timeline-row', 758, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-bottom', _v399)]),
  ]),
  RaftUtility('pe-1.5', 697, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(6, 'px'))]),
  ]),
  RaftUtility('pe-2', 698, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(8, 'px'))]),
  ]),
  RaftUtility(
    'pe-[calc(var(--raft-frame-inset-end,0px)+var(--column-margin))]',
    699,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssCalc(_v755))]),
      RaftLayer(
        'self',
        ['width>=768'],
        1000,
        [RaftDecl('padding-right', CssCalc(_v756))],
      ),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-right', CssCalc(_v755))],
      ),
    ],
  ),
  RaftUtility('pl-0', 759, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(0, 'px'))]),
  ]),
  RaftUtility('pl-0.5', 760, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(2, 'px'))]),
  ]),
  RaftUtility('pl-1.5', 761, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(6, 'px'))]),
  ]),
  RaftUtility('pl-2', 762, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(8, 'px'))]),
  ]),
  RaftUtility('pl-2.5', 763, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(10, 'px'))]),
  ]),
  RaftUtility('pl-3', 764, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(12, 'px'))]),
  ]),
  RaftUtility('pl-3.5', 765, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(14, 'px'))]),
  ]),
  RaftUtility('pl-4', 766, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(16, 'px'))]),
  ]),
  RaftUtility('pl-5', 767, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(20, 'px'))]),
  ]),
  RaftUtility('pl-[18px]', 769, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(18, 'px'))]),
  ]),
  RaftUtility('pl-[5.5px]', 768, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(5.5, 'px'))]),
  ]),
  RaftUtility(
    'pl-[calc(16px+env(safe-area-inset-left,0px))]',
    770,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssCalc(_v759))]),
    ],
  ),
  RaftUtility(
    'pl-[calc(env(safe-area-inset-left,0px)+--spacing(4))]',
    771,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssCalc(_v760))]),
    ],
  ),
  RaftUtility(
    'pl-[calc(var(--cell-inset-x)+var(--cell-pad-x))]',
    772,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssCalc(_v761))]),
    ],
  ),
  RaftUtility(
    'pl-[calc(var(--control-embedded-inset)-1px)]',
    773,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssCalc(_v408))]),
    ],
  ),
  RaftUtility(
    'pl-[env(safe-area-inset-left,0px)]',
    774,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-left', _v758)]),
    ],
  ),
  RaftUtility(
    'placeholder:text-foreground-hint',
    1193,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('::placeholder', [], 1001, [RaftDecl('color', _v44)]),
      RaftLayer('::placeholder', ['dark'], 1001, [RaftDecl('color', _v39)]),
    ],
  ),
  RaftUtility(
    'pointer-coarse:**:data-[slot=button]:after:inset-y-[-9.5px]',
    2242,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& *)[data-slot="button"]::after',
        ['pointer-coarse'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-9.5, 'px')),
          RaftDecl('bottom', CssNum(-9.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:*:data-[slot=button]:after:inset-y-[-9.5px]',
    2241,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="button"]::after',
        ['pointer-coarse'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-9.5, 'px')),
          RaftDecl('bottom', CssNum(-9.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:*:data-[slot=panel-action]:after:-inset-1.5',
    2244,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="panel-action"]::after',
        ['pointer-coarse'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-6, 'px')),
          RaftDecl('right', CssNum(-6, 'px')),
          RaftDecl('bottom', CssNum(-6, 'px')),
          RaftDecl('left', CssNum(-6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:*:data-[slot=panel-action]:after:absolute',
    2243,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="panel-action"]::after',
        ['pointer-coarse'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('position', CssKeyword('absolute')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:*:data-[slot=panel-toggle-action]:after:-inset-1.5',
    2246,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="panel-toggle-action"]::after',
        ['pointer-coarse'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-6, 'px')),
          RaftDecl('right', CssNum(-6, 'px')),
          RaftDecl('bottom', CssNum(-6, 'px')),
          RaftDecl('left', CssNum(-6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:*:data-[slot=panel-toggle-action]:after:absolute',
    2245,
    RaftUtilityStatus.descendant,
    [
      RaftLayer(
        ':is(& > *)[data-slot="panel-toggle-action"]::after',
        ['pointer-coarse'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('position', CssKeyword('absolute')),
        ],
      ),
    ],
  ),
  RaftUtility('pointer-coarse:-mr-6', 2215, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-coarse'],
      1000,
      [RaftDecl('margin-right', CssNum(-24, 'px'))],
    ),
  ]),
  RaftUtility(
    'pointer-coarse:after:-inset-3',
    2224,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-12, 'px')),
          RaftDecl('right', CssNum(-12, 'px')),
          RaftDecl('bottom', CssNum(-12, 'px')),
          RaftDecl('left', CssNum(-12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:after:-inset-y-2.5',
    2226,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-10, 'px')),
          RaftDecl('bottom', CssNum(-10, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:after:-inset-y-3',
    2227,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-12, 'px')),
          RaftDecl('bottom', CssNum(-12, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:after:-inset-y-[calc(--spacing(3)+1.5px)]',
    2228,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-13.5, 'px')),
          RaftDecl('bottom', CssNum(-13.5, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:after:-left-1.5',
    2232,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', CssNum(-6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:after:-right-3.5',
    2230,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('right', CssNum(-14, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:after:-top-[calc(--spacing(11)-100%)]',
    2229,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssCalc(_v763)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:after:absolute',
    2223,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('position', CssKeyword('absolute')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:after:bottom-0',
    2231,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('bottom', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:after:content-[\'\']',
    2233,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('--tw-content', CssString('')),
          RaftDecl('content', CssVar('--tw-content')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:after:inset-x-0',
    2225,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-coarse'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', CssNum(0, 'px')),
          RaftDecl('right', CssNum(0, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:data-[orientation=horizontal]:-mb-6',
    2239,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal', 'pointer-coarse'],
        2000,
        [RaftDecl('margin-bottom', CssNum(-24, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:data-[orientation=horizontal]:h-6',
    2240,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal', 'pointer-coarse'],
        2000,
        [RaftDecl('height', CssNum(24, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'pointer-coarse:data-[orientation=horizontal]:mr-0',
    2238,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['data-orientation=horizontal', 'pointer-coarse'],
        2000,
        [RaftDecl('margin-right', CssNum(0, 'px'))],
      ),
    ],
  ),
  RaftUtility('pointer-coarse:gap-3', 2219, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-coarse'],
      1000,
      [
        RaftDecl('row-gap', CssNum(12, 'px')),
        RaftDecl('column-gap', CssNum(12, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'pointer-coarse:has-[>[data-reveal=hover]]:[--inbox-item-aside-room:--spacing(11)]',
    2237,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-reveal=hover', 'pointer-coarse'],
        2000,
        [RaftDecl('--inbox-item-aside-room', CssNum(44, 'px'))],
      ),
    ],
  ),
  RaftUtility('pointer-coarse:min-h-11', 2216, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-coarse'],
      1000,
      [RaftDecl('min-height', CssNum(44, 'px'))],
    ),
  ]),
  RaftUtility('pointer-coarse:min-h-14', 2217, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-coarse'],
      1000,
      [RaftDecl('min-height', CssNum(56, 'px'))],
    ),
  ]),
  RaftUtility(
    'pointer-coarse:mt-[calc((--spacing(11)-1lh)/2)]',
    2214,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-coarse'],
        1000,
        [RaftDecl('margin-top', CssCalc(_v765))],
      ),
    ],
  ),
  RaftUtility('pointer-coarse:only:static', 2234, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['only-child', 'pointer-coarse'],
      2000,
      [RaftDecl('position', CssKeyword('static'))],
    ),
  ]),
  RaftUtility(
    'pointer-coarse:only:translate-y-0',
    2235,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['only-child', 'pointer-coarse'],
        2000,
        [
          RaftDecl('--tw-translate-y', CssNum(0, 'px')),
          RaftDecl('translate', CssSeq([_v84, _v85])),
        ],
      ),
    ],
  ),
  RaftUtility('pointer-coarse:opacity-100', 2222, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-coarse'],
      1000,
      [RaftDecl('opacity', CssNum(100, '%'))],
    ),
  ]),
  RaftUtility(
    'pointer-coarse:pointer-events-auto',
    2213,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-coarse'],
        1000,
        [RaftDecl('pointer-events', CssKeyword('auto'))],
      ),
    ],
  ),
  RaftUtility('pointer-coarse:py-2', 2220, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-coarse'],
      1000,
      [
        RaftDecl('padding-top', CssNum(8, 'px')),
        RaftDecl('padding-bottom', CssNum(8, 'px')),
      ],
    ),
  ]),
  RaftUtility(
    'pointer-coarse:py-[calc((--spacing(11)-1lh)/2)]',
    2221,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['pointer-coarse'],
        1000,
        [
          RaftDecl('padding-top', CssCalc(_v765)),
          RaftDecl('padding-bottom', CssCalc(_v765)),
        ],
      ),
    ],
  ),
  RaftUtility('pointer-coarse:w-6', 2218, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['pointer-coarse'],
      1000,
      [RaftDecl('width', CssNum(24, 'px'))],
    ),
  ]),
  RaftUtility('pointer-events-auto', 6, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('pointer-events', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('pointer-events-none', 7, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('pointer-events', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('pointer-fine:after:absolute', 2254, RaftUtilityStatus.resolved, [
    RaftLayer(
      '::after',
      ['pointer-fine'],
      1001,
      [
        RaftDecl('content', CssVar('--tw-content')),
        RaftDecl('position', CssKeyword('absolute')),
      ],
    ),
  ]),
  RaftUtility(
    'pointer-fine:after:content-[\'\']',
    2256,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-fine'],
        1001,
        [
          RaftDecl('--tw-content', CssString('')),
          RaftDecl('content', CssVar('--tw-content')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-fine:after:inset-[-3px]',
    2255,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['pointer-fine'],
        1001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssNum(-3, 'px')),
          RaftDecl('right', CssNum(-3, 'px')),
          RaftDecl('bottom', CssNum(-3, 'px')),
          RaftDecl('left', CssNum(-3, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'pointer-fine:has-[>[data-reveal=hover]]:[--inbox-item-reveal-aside:1]',
    2258,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['has:>data-reveal=hover', 'pointer-fine'],
        2000,
        [RaftDecl('--inbox-item-reveal-aside', CssNum(1))],
      ),
    ],
  ),
  RaftUtility('pr-(--ig-control-pr,0.75rem)', 718, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', _v766)]),
  ]),
  RaftUtility('pr-(--ta-pr,0.75rem)', 719, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', _v767)]),
  ]),
  RaftUtility('pr-0', 720, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(0, 'px'))]),
  ]),
  RaftUtility('pr-0.5', 721, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(2, 'px'))]),
  ]),
  RaftUtility('pr-1', 722, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(4, 'px'))]),
  ]),
  RaftUtility('pr-1.5', 723, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(6, 'px'))]),
  ]),
  RaftUtility('pr-11', 726, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(44, 'px'))]),
  ]),
  RaftUtility('pr-13', 727, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(52, 'px'))]),
  ]),
  RaftUtility('pr-2', 724, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(8, 'px'))]),
  ]),
  RaftUtility('pr-3', 725, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(12, 'px'))]),
  ]),
  RaftUtility('pr-[37px]', 729, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(37, 'px'))]),
  ]),
  RaftUtility('pr-[6.5px]', 728, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssNum(6.5, 'px'))]),
  ]),
  RaftUtility(
    'pr-[calc(16px+env(safe-area-inset-right,0px))]',
    730,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssCalc(_v72))]),
    ],
  ),
  RaftUtility(
    'pr-[calc(env(safe-area-inset-right,0px)+--spacing(4))]',
    731,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssCalc(_v768))]),
    ],
  ),
  RaftUtility(
    'pr-[calc(max(0px,calc(8px-var(--scrollbar-size,0px)))+12px)]',
    732,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssCalc(_v769))]),
    ],
  ),
  RaftUtility(
    'pr-[calc(var(--cell-inset-end)+var(--cell-pad-x))]',
    733,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssCalc(_v770))]),
    ],
  ),
  RaftUtility(
    'pr-[calc(var(--control-embedded-inset)-1px)]',
    734,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-right', CssCalc(_v408))]),
    ],
  ),
  RaftUtility(
    'pr-[env(safe-area-inset-right,0px)]',
    735,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-right', _v71)]),
    ],
  ),
  RaftUtility('print:line-clamp-none', 2210, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['print'],
      1000,
      [
        RaftDecl('overflow-x', CssKeyword('visible')),
        RaftDecl('overflow-y', CssKeyword('visible')),
        RaftDecl('display', CssKeyword('block')),
        RaftDecl('-webkit-box-orient', _v639),
        RaftDecl('-webkit-line-clamp', CssKeyword('unset')),
      ],
    ),
  ]),
  RaftUtility('print:overflow-visible', 2211, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['print'],
      1000,
      [
        RaftDecl('overflow-x', CssKeyword('visible')),
        RaftDecl('overflow-y', CssKeyword('visible')),
      ],
    ),
  ]),
  RaftUtility('print:whitespace-normal', 2212, RaftUtilityStatus.resolved, [
    RaftLayer(
      'self',
      ['print'],
      1000,
      [RaftDecl('white-space', CssKeyword('normal'))],
    ),
  ]),
  RaftUtility('ps-1', 693, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(4, 'px'))]),
  ]),
  RaftUtility('ps-2', 694, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(8, 'px'))]),
  ]),
  RaftUtility('ps-[3px]', 695, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssNum(3, 'px'))]),
  ]),
  RaftUtility(
    'ps-[calc(var(--raft-frame-inset-start,0px)+(var(--rail-width)-1px-var(--rail-item))/2)]',
    696,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-left', CssCalc(_v776))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-left', CssCalc(_v249))],
      ),
    ],
  ),
  RaftUtility('pt-(--page-top)', 700, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', _v777)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-top', CssNum(12, 'px'))],
    ),
  ]),
  RaftUtility('pt-(--surface-inset)', 701, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(20, 'px'))]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('padding-top', CssNum(16, 'px'))],
    ),
  ]),
  RaftUtility('pt-0', 702, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(0, 'px'))]),
  ]),
  RaftUtility('pt-1', 703, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(4, 'px'))]),
  ]),
  RaftUtility('pt-1.5', 704, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(6, 'px'))]),
  ]),
  RaftUtility('pt-2', 705, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(8, 'px'))]),
  ]),
  RaftUtility('pt-2.5', 706, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(10, 'px'))]),
  ]),
  RaftUtility('pt-3', 707, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(12, 'px'))]),
  ]),
  RaftUtility('pt-4', 708, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(16, 'px'))]),
  ]),
  RaftUtility('pt-[calc((27px-1lh)/2)]', 709, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssCalc(_v724))]),
  ]),
  RaftUtility('pt-[calc(1px-0.0275em)]', 710, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssCalc(_v778))]),
  ]),
  RaftUtility(
    'pt-[calc(env(safe-area-inset-top,0px)+--spacing(3))]',
    711,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssCalc(_v779))]),
    ],
  ),
  RaftUtility(
    'pt-[calc(var(--spacing-timeline-lead)-(--spacing(7)-var(--text-mono-meta--line-height))/2)]',
    712,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssCalc(_v780))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-top', CssCalc(_v781))],
      ),
    ],
  ),
  RaftUtility(
    'pt-[calc(var(--spacing-timeline-section)-var(--spacing-timeline-row)-var(--text-mono-meta--line-height)/2)]',
    713,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssCalc(_v782))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('padding-top', CssCalc(_v783))],
      ),
    ],
  ),
  RaftUtility(
    'pt-[env(safe-area-inset-top,0px)]',
    714,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('padding-top', _v74)]),
    ],
  ),
  RaftUtility('pt-px', 715, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssNum(1, 'px'))]),
  ]),
  RaftUtility('pt-timeline-lead', 716, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssCalc(_v748))]),
  ]),
  RaftUtility('pt-timeline-start', 717, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('padding-top', CssCalc(_v785))]),
  ]),
  RaftUtility('px-(--column-margin)', 654, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(16, 'px')),
      RaftDecl('padding-right', CssNum(16, 'px')),
    ]),
    RaftLayer(
      'self',
      ['width>=768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(20, 'px')),
        RaftDecl('padding-right', CssNum(20, 'px')),
      ],
    ),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(16, 'px')),
        RaftDecl('padding-right', CssNum(16, 'px')),
      ],
    ),
  ]),
  RaftUtility('px-(--header-air)', 655, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', _v49),
      RaftDecl('padding-right', _v49),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(5, 'px')),
        RaftDecl('padding-right', CssNum(5, 'px')),
      ],
    ),
  ]),
  RaftUtility('px-(--surface-inset)', 656, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(20, 'px')),
      RaftDecl('padding-right', CssNum(20, 'px')),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('padding-left', CssNum(16, 'px')),
        RaftDecl('padding-right', CssNum(16, 'px')),
      ],
    ),
  ]),
  RaftUtility('px-0', 657, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(0, 'px')),
      RaftDecl('padding-right', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('px-0.5', 658, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(2, 'px')),
      RaftDecl('padding-right', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('px-1', 659, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(4, 'px')),
      RaftDecl('padding-right', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('px-1.5', 660, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(6, 'px')),
      RaftDecl('padding-right', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('px-2', 661, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(8, 'px')),
      RaftDecl('padding-right', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('px-2.5', 662, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(10, 'px')),
      RaftDecl('padding-right', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('px-3', 663, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(12, 'px')),
      RaftDecl('padding-right', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('px-3.5', 664, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(14, 'px')),
      RaftDecl('padding-right', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('px-4', 665, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(16, 'px')),
      RaftDecl('padding-right', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('px-5', 666, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(20, 'px')),
      RaftDecl('padding-right', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('px-6', 667, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(24, 'px')),
      RaftDecl('padding-right', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('px-[2px]', 668, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(2, 'px')),
      RaftDecl('padding-right', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('px-[5px]', 669, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(5, 'px')),
      RaftDecl('padding-right', CssNum(5, 'px')),
    ]),
  ]),
  RaftUtility('px-[7px]', 670, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-left', CssNum(7, 'px')),
      RaftDecl('padding-right', CssNum(7, 'px')),
    ]),
  ]),
  RaftUtility('py-(--settings-row-inset)', 671, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', _v254),
      RaftDecl('padding-bottom', _v254),
    ]),
  ]),
  RaftUtility('py-0', 672, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(0, 'px')),
      RaftDecl('padding-bottom', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('py-0.5', 673, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(2, 'px')),
      RaftDecl('padding-bottom', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('py-1', 674, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(4, 'px')),
      RaftDecl('padding-bottom', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('py-1.5', 675, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(6, 'px')),
      RaftDecl('padding-bottom', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('py-12', 683, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(48, 'px')),
      RaftDecl('padding-bottom', CssNum(48, 'px')),
    ]),
  ]),
  RaftUtility('py-2', 676, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(8, 'px')),
      RaftDecl('padding-bottom', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('py-2.5', 677, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(10, 'px')),
      RaftDecl('padding-bottom', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('py-3', 678, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(12, 'px')),
      RaftDecl('padding-bottom', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('py-3.5', 679, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(14, 'px')),
      RaftDecl('padding-bottom', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('py-4', 680, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(16, 'px')),
      RaftDecl('padding-bottom', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('py-5', 681, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(20, 'px')),
      RaftDecl('padding-bottom', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('py-6', 682, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(24, 'px')),
      RaftDecl('padding-bottom', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('py-[3px]', 684, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(3, 'px')),
      RaftDecl('padding-bottom', CssNum(3, 'px')),
    ]),
  ]),
  RaftUtility('py-[5px]', 685, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(5, 'px')),
      RaftDecl('padding-bottom', CssNum(5, 'px')),
    ]),
  ]),
  RaftUtility('py-[9px]', 686, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(9, 'px')),
      RaftDecl('padding-bottom', CssNum(9, 'px')),
    ]),
  ]),
  RaftUtility(
    'py-[calc((var(--row-height)-20px)/2)]',
    687,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('padding-top', CssCalc(_v678)),
        RaftDecl('padding-bottom', CssCalc(_v678)),
      ]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssNum(7, 'px')),
          RaftDecl('padding-bottom', CssNum(7, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'py-[calc(var(--control-embedded-inset)-1.5px)]',
    688,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('padding-top', CssCalc(_v786)),
        RaftDecl('padding-bottom', CssCalc(_v786)),
      ]),
    ],
  ),
  RaftUtility(
    'py-[calc(var(--section-gap)/2)]',
    689,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('padding-top', CssCalc(_v788)),
        RaftDecl('padding-bottom', CssCalc(_v788)),
      ]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('padding-top', CssCalc(_v790)),
          RaftDecl('padding-bottom', CssCalc(_v790)),
        ],
      ),
    ],
  ),
  RaftUtility('py-option-inset', 690, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssCalc(_v726)),
      RaftDecl('padding-bottom', CssCalc(_v726)),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('padding-top', CssCalc(_v728)),
        RaftDecl('padding-bottom', CssCalc(_v728)),
      ],
    ),
  ]),
  RaftUtility('py-px', 691, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', CssNum(1, 'px')),
      RaftDecl('padding-bottom', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('py-timeline-row', 692, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('padding-top', _v399),
      RaftDecl('padding-bottom', _v399),
    ]),
  ]),
  RaftUtility('relative', 12, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('position', CssKeyword('relative'))]),
  ]),
  RaftUtility('resize-none', 434, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('resize', CssKeyword('none'))]),
  ]),
  RaftUtility('resize-y', 435, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('resize', CssKeyword('vertical'))]),
  ]),
  RaftUtility('right-(--drawer-inset)', 40, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', _v161)]),
  ]),
  RaftUtility('right-0', 41, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(0, 'px'))]),
  ]),
  RaftUtility('right-1.5', 42, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(6, 'px'))]),
  ]),
  RaftUtility('right-3', 43, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(12, 'px'))]),
  ]),
  RaftUtility('right-4', 44, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(16, 'px'))]),
  ]),
  RaftUtility('right-6', 45, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(24, 'px'))]),
  ]),
  RaftUtility('right-[-3px]', 46, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('right', CssNum(-3, 'px'))]),
  ]),
  RaftUtility(
    'right-[calc(var(--control-embedded-inset)-1px)]',
    47,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('right', CssCalc(_v408))]),
    ],
  ),
  RaftUtility('ring-0', 922, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ring-shadow', _v22),
      RaftDecl('box-shadow', _v27),
    ]),
  ]),
  RaftUtility('ring-1', 923, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ring-shadow', _v792),
      RaftDecl('box-shadow', _v27),
    ]),
  ]),
  RaftUtility('ring-[1.5px]', 924, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ring-shadow', _v145),
      RaftDecl('box-shadow', _v27),
    ]),
  ]),
  RaftUtility('ring-inset', 1093, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-ring-inset', CssKeyword('inset')),
    ]),
  ]),
  RaftUtility('ring-line-hairline', 928, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v252)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('--tw-ring-color', _v253)]),
  ]),
  RaftUtility('ring-line-seam', 929, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v317)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('--tw-ring-color', _v318)]),
  ]),
  RaftUtility('ring-sticker-edge', 930, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('--tw-ring-color', _v146)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('--tw-ring-color', _v147)]),
  ]),
  RaftUtility('rotate-45', 419, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('rotate', CssNum(45, 'deg'))]),
  ]),
  RaftUtility('rotate-90', 420, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('rotate', CssNum(90, 'deg'))]),
  ]),
  RaftUtility(
    'rounded-(--bar-button-radius)',
    522,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('border-top-left-radius', _v711),
        RaftDecl('border-top-right-radius', _v711),
        RaftDecl('border-bottom-right-radius', _v711),
        RaftDecl('border-bottom-left-radius', _v711),
      ]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('border-top-left-radius', CssNum(6, 'px')),
          RaftDecl('border-top-right-radius', CssNum(6, 'px')),
          RaftDecl('border-bottom-right-radius', CssNum(6, 'px')),
          RaftDecl('border-bottom-left-radius', CssNum(6, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('rounded-(--control-radius)', 523, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', _v429),
      RaftDecl('border-top-right-radius', _v429),
      RaftDecl('border-bottom-right-radius', _v429),
      RaftDecl('border-bottom-left-radius', _v429),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('border-top-left-radius', CssNum(8, 'px')),
        RaftDecl('border-top-right-radius', CssNum(8, 'px')),
        RaftDecl('border-bottom-right-radius', CssNum(8, 'px')),
        RaftDecl('border-bottom-left-radius', CssNum(8, 'px')),
      ],
    ),
  ]),
  RaftUtility('rounded-[11px]', 527, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(11, 'px')),
      RaftDecl('border-top-right-radius', CssNum(11, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(11, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(11, 'px')),
    ]),
  ]),
  RaftUtility('rounded-[1px]', 524, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(1, 'px')),
      RaftDecl('border-top-right-radius', CssNum(1, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(1, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('rounded-[2px]', 525, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(2, 'px')),
      RaftDecl('border-top-right-radius', CssNum(2, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(2, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('rounded-[3px]', 526, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(3, 'px')),
      RaftDecl('border-top-right-radius', CssNum(3, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(3, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(3, 'px')),
    ]),
  ]),
  RaftUtility('rounded-[inherit]', 528, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssKeyword('inherit')),
      RaftDecl('border-top-right-radius', CssKeyword('inherit')),
      RaftDecl('border-bottom-right-radius', CssKeyword('inherit')),
      RaftDecl('border-bottom-left-radius', CssKeyword('inherit')),
    ]),
  ]),
  RaftUtility('rounded-b-dialog', 542, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-bottom-right-radius', CssNum(16, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('rounded-chip', 529, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(6, 'px')),
      RaftDecl('border-top-right-radius', CssNum(6, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(6, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('rounded-container', 530, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(10, 'px')),
      RaftDecl('border-top-right-radius', CssNum(10, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(10, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('rounded-control', 531, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(8, 'px')),
      RaftDecl('border-top-right-radius', CssNum(8, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(8, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('rounded-dialog', 532, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(16, 'px')),
      RaftDecl('border-top-right-radius', CssNum(16, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(16, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('rounded-e-none', 539, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-right-radius', CssNum(0)),
      RaftDecl('border-bottom-right-radius', CssNum(0)),
    ]),
  ]),
  RaftUtility('rounded-full', 533, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', _v322),
      RaftDecl('border-top-right-radius', _v322),
      RaftDecl('border-bottom-right-radius', _v322),
      RaftDecl('border-bottom-left-radius', _v322),
    ]),
  ]),
  RaftUtility('rounded-md', 534, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(6, 'px')),
      RaftDecl('border-top-right-radius', CssNum(6, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(6, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('rounded-none', 535, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(0)),
      RaftDecl('border-top-right-radius', CssNum(0)),
      RaftDecl('border-bottom-right-radius', CssNum(0)),
      RaftDecl('border-bottom-left-radius', CssNum(0)),
    ]),
  ]),
  RaftUtility('rounded-s-none', 538, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(0)),
      RaftDecl('border-bottom-left-radius', CssNum(0)),
    ]),
  ]),
  RaftUtility('rounded-sm', 536, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(4, 'px')),
      RaftDecl('border-top-right-radius', CssNum(4, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(4, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('rounded-sticker', 537, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(4, 'px')),
      RaftDecl('border-top-right-radius', CssNum(4, 'px')),
      RaftDecl('border-bottom-right-radius', CssNum(4, 'px')),
      RaftDecl('border-bottom-left-radius', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('rounded-t-dialog', 540, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-left-radius', CssNum(16, 'px')),
      RaftDecl('border-top-right-radius', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('rounded-tr-[15%]', 541, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('border-top-right-radius', CssNum(15, '%')),
    ]),
  ]),
  RaftUtility('row-span-2', 99, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-row', _v414)]),
  ]),
  RaftUtility(
    'row-start-(--banner-desc-row,1)',
    100,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('grid-row-start', _v577)]),
    ],
  ),
  RaftUtility('row-start-1', 101, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-row-start', CssNum(1))]),
  ]),
  RaftUtility('row-start-2', 102, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('grid-row-start', CssNum(2))]),
  ]),
  RaftUtility('scroll-pb-(--ta-scroll-pb,0)', 439, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('scroll-padding-bottom', _v793)]),
  ]),
  RaftUtility('scroll-px-6', 436, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('scroll-padding-left', CssNum(24, 'px')),
      RaftDecl('scroll-padding-right', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('scroll-py-1', 437, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('scroll-padding-top', CssNum(4, 'px')),
      RaftDecl('scroll-padding-bottom', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('scroll-py-6', 438, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('scroll-padding-top', CssNum(24, 'px')),
      RaftDecl('scroll-padding-bottom', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('scrollbar-none', 440, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('scrollbar-width', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('select-none', 978, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('-webkit-user-select', CssKeyword('none')),
      RaftDecl('user-select', CssKeyword('none')),
    ]),
  ]),
  RaftUtility('select-none!', 979, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('-webkit-user-select', CssKeyword('none'), true),
      RaftDecl('user-select', CssKeyword('none'), true),
    ]),
  ]),
  RaftUtility('select-text', 980, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('-webkit-user-select', CssKeyword('text')),
      RaftDecl('user-select', CssKeyword('text')),
    ]),
  ]),
  RaftUtility('selection:bg-selection', 1192, RaftUtilityStatus.resolved, [
    RaftLayer('& ::selection', [], 1001, [RaftDecl('background-color', _v794)]),
    RaftLayer(
      '& ::selection',
      ['dark'],
      1001,
      [RaftDecl('background-color', _v256)],
    ),
    RaftLayer('::selection', [], 1001, [RaftDecl('background-color', _v794)]),
    RaftLayer(
      '::selection',
      ['dark'],
      1001,
      [RaftDecl('background-color', _v256)],
    ),
  ]),
  RaftUtility('self-center', 506, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('align-self', CssKeyword('center'))]),
  ]),
  RaftUtility('self-end', 507, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-self', CssKeyword('flex-end')),
    ]),
  ]),
  RaftUtility('self-start', 508, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('align-self', _v61)]),
  ]),
  RaftUtility('self-stretch', 509, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('align-self', CssKeyword('stretch')),
    ]),
  ]),
  RaftUtility(
    'shadow-[0_0_0_1.5px_var(--line-strong)]',
    915,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v796),
        RaftDecl('box-shadow', _v27),
      ]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--tw-shadow', _v797)]),
    ],
  ),
  RaftUtility(
    'shadow-[0_0_0_1.5px_var(--mi-row-fill,transparent),0_0_0_1.5px_var(--layer-canvas)]',
    916,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', CssList([_v798, _v799])),
        RaftDecl('box-shadow', _v27),
      ]),
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [
          RaftDecl('--tw-shadow', CssList([_v798, _v800])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'shadow-[0_0_0_1.5px_var(--sticker-edge),var(--elevation-sticker)]',
    917,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', CssList([_v802, _v803])),
        RaftDecl('box-shadow', _v27),
      ]),
      RaftLayer(
        'self',
        ['dark'],
        1000,
        [
          RaftDecl('--tw-shadow', CssList([_v805, _v806])),
        ],
      ),
    ],
  ),
  RaftUtility(
    'shadow-[0_0_0_1.5px_var(--sticker-edge)]',
    918,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v802),
        RaftDecl('box-shadow', _v27),
      ]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--tw-shadow', _v805)]),
    ],
  ),
  RaftUtility(
    'shadow-[0_0_0_2px_var(--layer-canvas)]',
    919,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-shadow', _v807),
        RaftDecl('box-shadow', _v27),
      ]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('--tw-shadow', _v808)]),
    ],
  ),
  RaftUtility('shadow-float', 920, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-shadow', _v453),
      RaftDecl('box-shadow', _v27),
    ]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [
        RaftDecl('--tw-shadow', CssList([_v455, _v457])),
      ],
    ),
  ]),
  RaftUtility('shadow-none', 921, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-shadow', _v28),
      RaftDecl('box-shadow', _v27),
    ]),
  ]),
  RaftUtility('shrink', 397, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-shrink', CssNum(1))]),
  ]),
  RaftUtility('shrink-0', 398, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-shrink', CssNum(0))]),
  ]),
  RaftUtility('shrink-1000', 399, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('flex-shrink', CssNum(1000))]),
  ]),
  RaftUtility('size-(--bar-button-size)', 177, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', _v203),
      RaftDecl('height', _v203),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('width', CssNum(28, 'px')),
        RaftDecl('height', CssNum(28, 'px')),
      ],
    ),
  ]),
  RaftUtility('size-(--frame-item-height)', 178, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', _v209),
      RaftDecl('height', _v209),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('width', CssNum(34, 'px')),
        RaftDecl('height', CssNum(34, 'px')),
      ],
    ),
  ]),
  RaftUtility('size-(--rail-item)', 179, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', _v773),
      RaftDecl('height', _v773),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('width', _v246), RaftDecl('height', _v246)],
    ),
  ]),
  RaftUtility('size-(--spinner-pixel)', 180, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', _v548),
      RaftDecl('height', _v548),
    ]),
  ]),
  RaftUtility('size-0', 181, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(0, 'px')),
      RaftDecl('height', CssNum(0, 'px')),
    ]),
  ]),
  RaftUtility('size-0.5', 182, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(2, 'px')),
      RaftDecl('height', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('size-1', 183, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(4, 'px')),
      RaftDecl('height', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('size-1.5', 184, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(6, 'px')),
      RaftDecl('height', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('size-10', 196, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(40, 'px')),
      RaftDecl('height', CssNum(40, 'px')),
    ]),
  ]),
  RaftUtility('size-11', 197, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(44, 'px')),
      RaftDecl('height', CssNum(44, 'px')),
    ]),
  ]),
  RaftUtility('size-12', 198, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(48, 'px')),
      RaftDecl('height', CssNum(48, 'px')),
    ]),
  ]),
  RaftUtility('size-16', 199, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(64, 'px')),
      RaftDecl('height', CssNum(64, 'px')),
    ]),
  ]),
  RaftUtility('size-2', 185, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(8, 'px')),
      RaftDecl('height', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('size-2.5', 186, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(10, 'px')),
      RaftDecl('height', CssNum(10, 'px')),
    ]),
  ]),
  RaftUtility('size-3', 187, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(12, 'px')),
      RaftDecl('height', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('size-3.5', 188, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(14, 'px')),
      RaftDecl('height', CssNum(14, 'px')),
    ]),
  ]),
  RaftUtility('size-4', 189, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(16, 'px')),
      RaftDecl('height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('size-4.5', 190, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(18, 'px')),
      RaftDecl('height', CssNum(18, 'px')),
    ]),
  ]),
  RaftUtility('size-5', 191, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(20, 'px')),
      RaftDecl('height', CssNum(20, 'px')),
    ]),
  ]),
  RaftUtility('size-6', 192, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(24, 'px')),
      RaftDecl('height', CssNum(24, 'px')),
    ]),
  ]),
  RaftUtility('size-7', 193, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(28, 'px')),
      RaftDecl('height', CssNum(28, 'px')),
    ]),
  ]),
  RaftUtility('size-8', 194, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(32, 'px')),
      RaftDecl('height', CssNum(32, 'px')),
    ]),
  ]),
  RaftUtility('size-9', 195, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(36, 'px')),
      RaftDecl('height', CssNum(36, 'px')),
    ]),
  ]),
  RaftUtility('size-[11px]', 201, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(11, 'px')),
      RaftDecl('height', CssNum(11, 'px')),
    ]),
  ]),
  RaftUtility('size-[16px]', 202, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(16, 'px')),
      RaftDecl('height', CssNum(16, 'px')),
    ]),
  ]),
  RaftUtility('size-[18px]', 203, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(18, 'px')),
      RaftDecl('height', CssNum(18, 'px')),
    ]),
  ]),
  RaftUtility('size-[19px]', 204, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(19, 'px')),
      RaftDecl('height', CssNum(19, 'px')),
    ]),
  ]),
  RaftUtility('size-[27px]', 205, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(27, 'px')),
      RaftDecl('height', CssNum(27, 'px')),
    ]),
  ]),
  RaftUtility('size-[35px]', 206, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(35, 'px')),
      RaftDecl('height', CssNum(35, 'px')),
    ]),
  ]),
  RaftUtility('size-[51px]', 207, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(51, 'px')),
      RaftDecl('height', CssNum(51, 'px')),
    ]),
  ]),
  RaftUtility('size-[99px]', 208, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(99, 'px')),
      RaftDecl('height', CssNum(99, 'px')),
    ]),
  ]),
  RaftUtility('size-[9px]', 200, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(9, 'px')),
      RaftDecl('height', CssNum(9, 'px')),
    ]),
  ]),
  RaftUtility(
    'size-[calc(var(--control-embedded-size)-4px)]',
    209,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('width', CssCalc(_v809)),
        RaftDecl('height', CssCalc(_v809)),
      ]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('width', CssNum(18, 'px')),
          RaftDecl('height', CssNum(18, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'size-[calc(var(--switch-height)-8px)]',
    210,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('width', CssCalc(_v810)),
        RaftDecl('height', CssCalc(_v810)),
      ]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [
          RaftDecl('width', CssNum(14, 'px')),
          RaftDecl('height', CssNum(14, 'px')),
        ],
      ),
    ],
  ),
  RaftUtility('size-auto', 211, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssKeyword('auto')),
      RaftDecl('height', CssKeyword('auto')),
    ]),
  ]),
  RaftUtility('size-control', 212, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', _v206),
      RaftDecl('height', _v206),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('width', CssNum(34, 'px')),
        RaftDecl('height', CssNum(34, 'px')),
      ],
    ),
  ]),
  RaftUtility('size-control-icon', 213, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', _v110),
      RaftDecl('height', _v110),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [
        RaftDecl('width', CssNum(18, 'px')),
        RaftDecl('height', CssNum(18, 'px')),
      ],
    ),
  ]),
  RaftUtility('size-full', 214, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('width', CssNum(100, '%')),
      RaftDecl('height', CssNum(100, '%')),
    ]),
  ]),
  RaftUtility('sr-only', 9, RaftUtilityStatus.resolved, [
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
      RaftDecl('clip-path', _v88),
      RaftDecl('white-space', CssKeyword('nowrap')),
      RaftDecl('border-top-width', CssNum(0)),
      RaftDecl('border-right-width', CssNum(0)),
      RaftDecl('border-bottom-width', CssNum(0)),
      RaftDecl('border-left-width', CssNum(0)),
    ]),
  ]),
  RaftUtility('stack-x-[-5px]', 122, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > * + *)', [], 0, [
      RaftDecl('margin-left', CssNum(-5, 'px')),
    ]),
  ]),
  RaftUtility('stack-y-1', 125, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > * + *)', [], 0, [
      RaftDecl('margin-top', CssNum(4, 'px')),
    ]),
  ]),
  RaftUtility('stack-y-1.5', 126, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > * + *)', [], 0, [
      RaftDecl('margin-top', CssNum(6, 'px')),
    ]),
  ]),
  RaftUtility('stack-y-2', 127, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > * + *)', [], 0, [
      RaftDecl('margin-top', CssNum(8, 'px')),
    ]),
  ]),
  RaftUtility('stack-y-px', 128, RaftUtilityStatus.descendant, [
    RaftLayer(':where(& > * + *)', [], 0, [
      RaftDecl('margin-top', CssNum(1, 'px')),
    ]),
  ]),
  RaftUtility('sticky', 13, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('position', CssKeyword('sticky'))]),
  ]),
  RaftUtility('stroke-current', 642, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('stroke', _v20)]),
  ]),
  RaftUtility(
    'supports-[-webkit-touch-callout:none]:absolute',
    2104,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('position', CssKeyword('absolute')),
      ]),
    ],
  ),
  RaftUtility(
    'supports-[anchor-scope:all]:pointer-coarse:enabled:[anchor-name:--badge]',
    2247,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['enabled', 'pointer-coarse'],
        2000,
        [RaftDecl('anchor-name', CssKeyword('--badge'))],
      ),
    ],
  ),
  RaftUtility(
    'supports-[anchor-scope:all]:pointer-coarse:enabled:[anchor-scope:--badge]',
    2248,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        'self',
        ['enabled', 'pointer-coarse'],
        2000,
        [RaftDecl('anchor-scope', CssKeyword('--badge'))],
      ),
    ],
  ),
  RaftUtility(
    'supports-[anchor-scope:all]:pointer-coarse:enabled:after:[position-anchor:--badge]',
    2253,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['enabled', 'pointer-coarse'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('position-anchor', CssKeyword('--badge')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'supports-[anchor-scope:all]:pointer-coarse:enabled:after:absolute',
    2249,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['enabled', 'pointer-coarse'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('position', CssKeyword('absolute')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'supports-[anchor-scope:all]:pointer-coarse:enabled:after:content-[\'\']',
    2252,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['enabled', 'pointer-coarse'],
        2001,
        [
          RaftDecl('--tw-content', CssString('')),
          RaftDecl('content', CssVar('--tw-content')),
        ],
      ),
    ],
  ),
  RaftUtility(
    'supports-[anchor-scope:all]:pointer-coarse:enabled:after:inset-x-[min(anchor(inside),anchor(center)-22px)]',
    2250,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['enabled', 'pointer-coarse'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('left', _v814),
          RaftDecl('right', _v814),
        ],
      ),
    ],
  ),
  RaftUtility(
    'supports-[anchor-scope:all]:pointer-coarse:enabled:after:inset-y-[calc(anchor(center)-22px)]',
    2251,
    RaftUtilityStatus.resolved,
    [
      RaftLayer(
        '::after',
        ['enabled', 'pointer-coarse'],
        2001,
        [
          RaftDecl('content', CssVar('--tw-content')),
          RaftDecl('top', CssCalc(_v813)),
          RaftDecl('bottom', CssCalc(_v813)),
        ],
      ),
    ],
  ),
  RaftUtility(
    'supports-[overflow-clip-margin:2px]:[content-visibility:auto]',
    2105,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('content-visibility', CssKeyword('auto')),
      ]),
    ],
  ),
  RaftUtility('tabular-nums', 898, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-numeric-spacing', _v815),
      RaftDecl('font-variant-numeric', _v821),
    ]),
  ]),
  RaftUtility(
    'text-(--ig-addon-fg,var(--ig-addon-fg-default,var(--foreground-hint)))',
    855,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v823)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v825)]),
    ],
  ),
  RaftUtility(
    'text-(--ig-text-fg,var(--ig-text-fg-default,var(--foreground-hint)))',
    856,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v827)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v829)]),
    ],
  ),
  RaftUtility('text-(--list-row-ink)', 857, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v830)]),
  ]),
  RaftUtility('text-(--list-row-ink-2)', 858, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v831)]),
  ]),
  RaftUtility('text-(--list-row-ink-3)', 859, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v832)]),
  ]),
  RaftUtility('text-(--list-row-risk-ink)', 860, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v833)]),
  ]),
  RaftUtility(
    'text-(--list-row-risk-ink,var(--list-row-ink-3))',
    861,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v834)]),
    ],
  ),
  RaftUtility('text-(--meter-value)', 862, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', CssVar('--meter-value'))]),
  ]),
  RaftUtility(
    'text-(--mi-ct-color,transparent)',
    863,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v835)]),
    ],
  ),
  RaftUtility('text-2xl', 790, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(24, 'px')),
      RaftDecl('line-height', _v121),
    ]),
  ]),
  RaftUtility('text-5xl', 791, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(48, 'px')),
      RaftDecl('line-height', _v836),
    ]),
  ]),
  RaftUtility('text-[0.875em]', 809, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(0.875, 'em'))]),
  ]),
  RaftUtility('text-[1.071em]', 810, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(1.071, 'em'))]),
  ]),
  RaftUtility('text-[1.143em]', 811, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(1.143, 'em'))]),
  ]),
  RaftUtility('text-[1.286em]', 812, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(1.286, 'em'))]),
  ]),
  RaftUtility('text-[10px]', 815, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(10, 'px'))]),
  ]),
  RaftUtility('text-[10px]/3', 792, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(10, 'px')),
      RaftDecl('line-height', CssNum(12, 'px')),
    ]),
  ]),
  RaftUtility('text-[12px]', 816, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(12, 'px'))]),
  ]),
  RaftUtility('text-[15px]', 817, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(15, 'px'))]),
  ]),
  RaftUtility('text-[1em]', 813, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(1, 'em'))]),
  ]),
  RaftUtility('text-[32px]', 818, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(32, 'px'))]),
  ]),
  RaftUtility('text-[40px]', 819, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(40, 'px'))]),
  ]),
  RaftUtility('text-[4px]', 814, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(4, 'px'))]),
  ]),
  RaftUtility('text-[56px]', 820, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('font-size', CssNum(56, 'px'))]),
  ]),
  RaftUtility('text-attention-700', 864, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v837)]),
  ]),
  RaftUtility('text-attention-strong', 865, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v838)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v839)]),
  ]),
  RaftUtility('text-balance', 846, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-wrap', CssKeyword('balance'))]),
  ]),
  RaftUtility('text-base', 793, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(16, 'px')),
      RaftDecl('line-height', _v134),
    ]),
  ]),
  RaftUtility('text-body', 794, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(16, 'px')),
      RaftDecl('line-height', _v659),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('font-size', CssNum(14, 'px')), RaftDecl('line-height', _v660)],
    ),
  ]),
  RaftUtility('text-brand-strong', 866, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v840)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v34)]),
  ]),
  RaftUtility('text-callout', 795, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(14, 'px')),
      RaftDecl('line-height', _v841),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('line-height', _v660)],
    ),
  ]),
  RaftUtility('text-caption', 787, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(12, 'px')),
      RaftDecl('line-height', _v148),
      RaftDecl('font-weight', _v842),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('line-height', _v43)],
    ),
  ]),
  RaftUtility('text-card-title', 796, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', _v843),
      RaftDecl('line-height', _v844),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('font-size', CssNum(14, 'px')), RaftDecl('line-height', _v660)],
    ),
  ]),
  RaftUtility('text-center', 775, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-align', CssKeyword('center'))]),
  ]),
  RaftUtility('text-control', 797, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(13, 'px')),
      RaftDecl('line-height', _v43),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('font-size', CssNum(14, 'px')), RaftDecl('line-height', _v660)],
    ),
  ]),
  RaftUtility('text-current', 867, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v20)]),
  ]),
  RaftUtility('text-danger', 868, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v217)]),
  ]),
  RaftUtility('text-danger-strong', 869, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v392)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v393)]),
  ]),
  RaftUtility('text-ellipsis', 851, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-overflow', CssKeyword('ellipsis')),
    ]),
  ]),
  RaftUtility('text-field', 798, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', _v845),
      RaftDecl('line-height', _v846),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('font-size', CssNum(14, 'px')), RaftDecl('line-height', _v660)],
    ),
  ]),
  RaftUtility('text-footnote', 799, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(13, 'px')),
      RaftDecl('line-height', _v43),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('font-size', CssNum(12, 'px'))],
    ),
  ]),
  RaftUtility('text-foreground', 870, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v1)]),
  ]),
  RaftUtility('text-foreground-disabled', 871, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v306)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v307)]),
  ]),
  RaftUtility('text-foreground-hint', 872, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v44)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v39)]),
  ]),
  RaftUtility('text-foreground-inverse', 873, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v847)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v128)]),
  ]),
  RaftUtility('text-foreground-link', 874, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v507)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v508)]),
  ]),
  RaftUtility('text-foreground-muted', 875, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v2)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v3)]),
  ]),
  RaftUtility('text-foreground-on-frame', 876, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v37)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v1)]),
  ]),
  RaftUtility('text-foreground-on-hud', 877, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v271)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v1)]),
  ]),
  RaftUtility('text-foreground-on-hud/70', 878, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v271)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v1)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v628)]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('color', CssColor(0xB3E5E5E2))],
    ),
  ]),
  RaftUtility('text-foreground/30', 879, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v1)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v849)]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('color', CssColor(0x4DE5E5E2))],
    ),
  ]),
  RaftUtility('text-foreground/45', 880, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v0)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v1)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v851)]),
    RaftLayer(
      'self',
      ['dark'],
      1000,
      [RaftDecl('color', CssColor(0x73E5E5E2))],
    ),
  ]),
  RaftUtility('text-headline', 788, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(17, 'px')),
      RaftDecl('line-height', _v660),
      RaftDecl('font-weight', _v852),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('font-size', CssNum(16, 'px')), RaftDecl('line-height', _v659)],
    ),
  ]),
  RaftUtility('text-info-strong', 881, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v853)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v854)]),
  ]),
  RaftUtility('text-label', 789, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(11, 'px')),
      RaftDecl('line-height', _v855),
      RaftDecl('font-weight', _v856),
    ]),
  ]),
  RaftUtility('text-layer-card', 882, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v362)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v363)]),
  ]),
  RaftUtility('text-left', 776, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-align', CssKeyword('left'))]),
  ]),
  RaftUtility('text-lg', 800, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(18, 'px')),
      RaftDecl('line-height', _v133),
    ]),
  ]),
  RaftUtility('text-mono-code', 801, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(13, 'px')),
      RaftDecl('line-height', _v841),
    ]),
  ]),
  RaftUtility('text-mono-meta', 802, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(12, 'px')),
      RaftDecl('line-height', _v148),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('line-height', _v43)],
    ),
  ]),
  RaftUtility('text-pretty', 847, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-wrap', CssKeyword('pretty'))]),
  ]),
  RaftUtility('text-right', 777, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-align', CssKeyword('right'))]),
  ]),
  RaftUtility('text-sm', 803, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(14, 'px')),
      RaftDecl('line-height', _v858),
    ]),
  ]),
  RaftUtility('text-start', 778, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('text-align', CssKeyword('start'))]),
  ]),
  RaftUtility('text-sticker-ink', 883, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v143)]),
  ]),
  RaftUtility('text-subhead', 804, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(15, 'px')),
      RaftDecl('line-height', _v841),
    ]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('font-size', CssNum(14, 'px')), RaftDecl('line-height', _v660)],
    ),
  ]),
  RaftUtility('text-success', 884, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v218)]),
  ]),
  RaftUtility('text-success-strong', 885, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v859)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v860)]),
  ]),
  RaftUtility(
    'text-task-status-closed-strong',
    886,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v861)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v39)]),
    ],
  ),
  RaftUtility('text-task-status-done-strong', 887, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v862)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v863)]),
  ]),
  RaftUtility(
    'text-task-status-in-progress-strong',
    888,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v864)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v854)]),
    ],
  ),
  RaftUtility(
    'text-task-status-in-review-strong',
    889,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('color', _v865)]),
      RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v866)]),
    ],
  ),
  RaftUtility('text-task-status-todo-strong', 890, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v867)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v215)]),
  ]),
  RaftUtility('text-title', 786, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(22, 'px')),
      RaftDecl('line-height', _v868),
      RaftDecl('letter-spacing', _v869),
      RaftDecl('font-weight', _v852),
    ]),
  ]),
  RaftUtility('text-transparent', 891, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v15)]),
  ]),
  RaftUtility('text-warning', 892, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v213)]),
  ]),
  RaftUtility('text-warning-strong', 893, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v214)]),
    RaftLayer('self', ['dark'], 1000, [RaftDecl('color', _v215)]),
  ]),
  RaftUtility('text-white', 894, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v517)]),
  ]),
  RaftUtility('text-white/75', 895, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('color', _v872)]),
    RaftLayer('self', [], 1000, [RaftDecl('color', _v873)]),
  ]),
  RaftUtility('text-xl', 805, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(20, 'px')),
      RaftDecl('line-height', _v131),
    ]),
  ]),
  RaftUtility('text-xs', 806, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('font-size', CssNum(12, 'px')),
      RaftDecl('line-height', _v121),
    ]),
  ]),
  RaftUtility('to-transparent', 634, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-gradient-to', _v15),
      RaftDecl('--tw-gradient-stops', _v541),
    ]),
  ]),
  RaftUtility('top-(--drawer-inset)', 24, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', _v161)]),
  ]),
  RaftUtility('top-0', 25, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(0, 'px'))]),
  ]),
  RaftUtility('top-1.5', 26, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(6, 'px'))]),
  ]),
  RaftUtility('top-1/2', 27, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(50, '%'))]),
  ]),
  RaftUtility('top-3', 28, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(12, 'px'))]),
  ]),
  RaftUtility('top-[-18px]', 29, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(-18, 'px'))]),
  ]),
  RaftUtility(
    'top-[calc((1em-var(--message-reference-em))/4)]',
    30,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('top', CssCalc(_v876))]),
    ],
  ),
  RaftUtility(
    'top-[calc((var(--text-body--line-height)-var(--text-mono-meta--line-height))/2)]',
    31,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('top', CssNum(4, 'px'))]),
      RaftLayer(
        'self',
        ['pointer-fine', 'width>=768'],
        1000,
        [RaftDecl('top', CssNum(2, 'px'))],
      ),
    ],
  ),
  RaftUtility(
    'top-[calc(max(var(--toast-viewport-top,0px),env(safe-area-inset-top))+1rem)]',
    32,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('top', CssCalc(_v880))]),
    ],
  ),
  RaftUtility(
    'top-[calc(var(--control-embedded-inset)-1px)]',
    33,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('top', CssCalc(_v408))]),
    ],
  ),
  RaftUtility('top-auto', 34, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('top', CssKeyword('auto'))]),
  ]),
  RaftUtility('touch-manipulation', 432, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('touch-action', _v881)]),
  ]),
  RaftUtility('touch-none', 433, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('touch-action', CssKeyword('none'))]),
  ]),
  RaftUtility('tracking-[-0.005em]', 844, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(-0.005, 'em')),
      RaftDecl('letter-spacing', CssNum(-0.005, 'em')),
    ]),
  ]),
  RaftUtility('tracking-[-0.01em]', 843, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(-0.01, 'em')),
      RaftDecl('letter-spacing', CssNum(-0.01, 'em')),
    ]),
  ]),
  RaftUtility('tracking-normal', 845, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('--tw-tracking', CssNum(0, 'em')),
      RaftDecl('letter-spacing', CssNum(0, 'em')),
    ]),
  ]),
  RaftUtility(
    'transform-[translate3d(calc(var(--drawer-swipe-x,0px)+var(--drawer-stack-x,0px)),calc(var(--drawer-swipe-y,0px)+var(--drawer-stack-y,0px)),0)_scale(var(--drawer-stack-scale))]',
    421,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transform', CssSeq([_v888, _v889])),
      ]),
    ],
  ),
  RaftUtility(
    'transform-[translateX(var(--toast-swipe-movement-x))_translateY(calc(var(--toast-swipe-movement-y)+(var(--toast-index)*var(--toast-peek)*var(--toast-peek-dir))))_scale(var(--toast-scale))]',
    422,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('transform', _v896)]),
    ],
  ),
  RaftUtility('transform-gpu', 423, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('transform', _v903)]),
  ]),
  RaftUtility(
    'transition-[background-color,box-shadow,color]',
    940,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v904),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,box-shadow,transform]',
    941,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v905),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,box-shadow]',
    942,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', CssList([_v7, _v8])),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,color,border-color,box-shadow,transform]',
    943,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v906),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,color,box-shadow,transform]',
    944,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v907),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,color,opacity,box-shadow,transform]',
    945,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v908),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[background-color,color]',
    946,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v909),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[border-color,opacity,box-shadow]',
    947,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v910),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[color,background-color,opacity]',
    948,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v911),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility('transition-[filter,opacity]', 949, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v912),
      RaftDecl('transition-timing-function', _v11),
      RaftDecl('transition-duration', _v12),
    ]),
  ]),
  RaftUtility('transition-[height]', 950, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', CssKeyword('height')),
      RaftDecl('transition-timing-function', _v11),
      RaftDecl('transition-duration', _v12),
    ]),
  ]),
  RaftUtility(
    'transition-[opacity,transform]',
    951,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v913),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[transform,height,opacity,filter]',
    952,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v914),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[transform,opacity,height]',
    953,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v915),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[translate,opacity,scale]',
    954,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v916),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility(
    'transition-[width,background-color]',
    955,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('transition-property', _v917),
        RaftDecl('transition-timing-function', _v11),
        RaftDecl('transition-duration', _v12),
      ]),
    ],
  ),
  RaftUtility('transition-all', 956, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', CssKeyword('all')),
      RaftDecl('transition-timing-function', _v11),
      RaftDecl('transition-duration', _v12),
    ]),
  ]),
  RaftUtility('transition-colors', 957, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v329),
      RaftDecl('transition-timing-function', _v11),
      RaftDecl('transition-duration', _v12),
    ]),
  ]),
  RaftUtility('transition-opacity', 958, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', CssKeyword('opacity')),
      RaftDecl('transition-timing-function', _v11),
      RaftDecl('transition-duration', _v12),
    ]),
  ]),
  RaftUtility('transition-shadow', 959, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v8),
      RaftDecl('transition-timing-function', _v11),
      RaftDecl('transition-duration', _v12),
    ]),
  ]),
  RaftUtility('transition-transform', 960, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('transition-property', _v45),
      RaftDecl('transition-timing-function', _v11),
      RaftDecl('transition-duration', _v12),
    ]),
  ]),
  RaftUtility('translate-none', 417, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('translate', CssKeyword('none'))]),
  ]),
  RaftUtility(
    'translate-y-[calc(var(--pull-distance)-100%)]',
    416,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [
        RaftDecl('--tw-translate-y', CssCalc(_v919)),
        RaftDecl('translate', CssSeq([_v84, _v85])),
      ]),
    ],
  ),
  RaftUtility('truncate', 512, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-x', CssKeyword('hidden')),
      RaftDecl('overflow-y', CssKeyword('hidden')),
      RaftDecl('text-overflow', CssKeyword('ellipsis')),
      RaftDecl('white-space', CssKeyword('nowrap')),
    ]),
  ]),
  RaftUtility('underline', 900, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-decoration-line', CssKeyword('underline')),
    ]),
  ]),
  RaftUtility('underline-offset-2', 906, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-underline-offset', CssNum(2, 'px')),
    ]),
  ]),
  RaftUtility('underline-offset-[3px]', 907, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('text-underline-offset', CssNum(3, 'px')),
    ]),
  ]),
  RaftUtility('w-(--anchor-width)', 299, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v671)]),
  ]),
  RaftUtility(
    'w-(--inbox-item-skeleton-body)',
    300,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('width', _v920)]),
    ],
  ),
  RaftUtility(
    'w-(--inbox-item-skeleton-context)',
    301,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('width', _v921)]),
    ],
  ),
  RaftUtility(
    'w-(--inbox-item-skeleton-title)',
    302,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('width', _v922)]),
    ],
  ),
  RaftUtility(
    'w-(--list-row-skeleton-description)',
    303,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('width', _v923)]),
    ],
  ),
  RaftUtility(
    'w-(--list-row-skeleton-title)',
    304,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('width', _v924)]),
    ],
  ),
  RaftUtility('w-(--rail-width)', 305, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v771)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('width', _v244)],
    ),
  ]),
  RaftUtility('w-(--switch-width)', 306, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v464)]),
    RaftLayer(
      'self',
      ['pointer-fine', 'width>=768'],
      1000,
      [RaftDecl('width', CssNum(38, 'px'))],
    ),
  ]),
  RaftUtility('w-0', 307, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(0, 'px'))]),
  ]),
  RaftUtility('w-10', 316, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(40, 'px'))]),
  ]),
  RaftUtility('w-11', 317, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(44, 'px'))]),
  ]),
  RaftUtility('w-16', 318, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(64, 'px'))]),
  ]),
  RaftUtility('w-2', 308, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(8, 'px'))]),
  ]),
  RaftUtility('w-2.5', 309, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(10, 'px'))]),
  ]),
  RaftUtility('w-22', 319, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(88, 'px'))]),
  ]),
  RaftUtility('w-28', 320, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(112, 'px'))]),
  ]),
  RaftUtility('w-3', 310, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(12, 'px'))]),
  ]),
  RaftUtility('w-44', 321, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(176, 'px'))]),
  ]),
  RaftUtility('w-5', 311, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(20, 'px'))]),
  ]),
  RaftUtility('w-52', 322, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(208, 'px'))]),
  ]),
  RaftUtility('w-56', 323, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(224, 'px'))]),
  ]),
  RaftUtility('w-6', 312, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(24, 'px'))]),
  ]),
  RaftUtility('w-7', 313, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(28, 'px'))]),
  ]),
  RaftUtility('w-8', 314, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(32, 'px'))]),
  ]),
  RaftUtility('w-80', 324, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(320, 'px'))]),
  ]),
  RaftUtility('w-9', 315, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(36, 'px'))]),
  ]),
  RaftUtility('w-[1.5px]', 325, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(1.5, 'px'))]),
  ]),
  RaftUtility('w-[232px]', 327, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(232, 'px'))]),
  ]),
  RaftUtility('w-[300px]', 328, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(300, 'px'))]),
  ]),
  RaftUtility('w-[35px]', 326, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(35, 'px'))]),
  ]),
  RaftUtility('w-[380px]', 329, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(380, 'px'))]),
  ]),
  RaftUtility('w-[400px]', 330, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(400, 'px'))]),
  ]),
  RaftUtility('w-[calc(100%-2rem)]', 331, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssCalc(_v925))]),
  ]),
  RaftUtility(
    'w-[calc(var(--anchor-width)-16px)]',
    332,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('width', CssCalc(_v926))]),
    ],
  ),
  RaftUtility('w-[clamp(144px,20vw,224px)]', 333, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v927)]),
  ]),
  RaftUtility('w-[clamp(360px,32vw,520px)]', 334, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v928)]),
  ]),
  RaftUtility(
    'w-[min(24rem,calc(100vw-2rem))]',
    335,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('width', _v929)]),
    ],
  ),
  RaftUtility(
    'w-[min(var(--available-width,calc(100vw-16px)),480px)]',
    336,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('width', _v932)]),
    ],
  ),
  RaftUtility('w-auto', 337, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssKeyword('auto'))]),
  ]),
  RaftUtility('w-fit', 338, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v571)]),
  ]),
  RaftUtility('w-full', 339, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(100, '%'))]),
  ]),
  RaftUtility('w-max', 340, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', _v546)]),
  ]),
  RaftUtility('w-px', 341, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('width', CssNum(1, 'px'))]),
  ]),
  RaftUtility('whitespace-normal', 852, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('white-space', CssKeyword('normal')),
    ]),
  ]),
  RaftUtility('whitespace-nowrap', 853, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('white-space', CssKeyword('nowrap')),
    ]),
  ]),
  RaftUtility('whitespace-pre-wrap', 854, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('white-space', CssKeyword('pre-wrap')),
    ]),
  ]),
  RaftUtility(
    'will-change-[transform,opacity]',
    974,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('will-change', _v933)]),
    ],
  ),
  RaftUtility('will-change-transform', 975, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('will-change', CssKeyword('transform')),
    ]),
  ]),
  RaftUtility('wrap-anywhere', 848, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [
      RaftDecl('overflow-wrap', CssKeyword('anywhere')),
    ]),
  ]),
  RaftUtility('wrap-break-word', 849, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('overflow-wrap', _v103)]),
  ]),
  RaftUtility(
    'z-[calc(var(--z-index-toast)-var(--toast-index))]',
    67,
    RaftUtilityStatus.resolved,
    [
      RaftLayer('self', [], 1000, [RaftDecl('z-index', CssCalc(_v934))]),
    ],
  ),
  RaftUtility('z-base', 68, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(0))]),
  ]),
  RaftUtility('z-below', 69, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(-1))]),
  ]),
  RaftUtility('z-chrome', 70, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(35))]),
  ]),
  RaftUtility('z-control', 71, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(10))]),
  ]),
  RaftUtility('z-cover', 72, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(40))]),
  ]),
  RaftUtility('z-dialog', 73, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(50))]),
  ]),
  RaftUtility('z-dialog-layer', 74, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(60))]),
  ]),
  RaftUtility('z-drag', 75, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(999))]),
  ]),
  RaftUtility('z-float', 76, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(30))]),
  ]),
  RaftUtility('z-lightbox', 77, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(70))]),
  ]),
  RaftUtility('z-popup', 78, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(50))]),
  ]),
  RaftUtility('z-raised', 79, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(1))]),
  ]),
  RaftUtility('z-sticky', 80, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(20))]),
  ]),
  RaftUtility('z-toast', 81, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 1000, [RaftDecl('z-index', CssNum(80))]),
  ]),
];

/// `@property` registered custom properties (initial values).
const Map<String, CssValue?> raftRecipeRegistered = <String, CssValue?>{
  '--icon-inset': CssNum(0, 'px'),
  '--located-fill': _v15,
  '--message-reference-em': CssNum(0, 'px'),
  '--r-scroll-area-overflow-x-end': CssNum(0, 'px'),
  '--r-scroll-area-overflow-x-start': CssNum(0, 'px'),
  '--r-scroll-area-overflow-y-end': CssNum(0, 'px'),
  '--r-scroll-area-overflow-y-start': CssNum(0, 'px'),
  '--r-scroll-area-padding-left': CssNum(0, 'px'),
  '--r-scroll-area-padding-right': CssNum(0, 'px'),
  '--r-scroll-area-padding-top': CssNum(0, 'px'),
  '--r-scroll-area-rail-inset-bottom': CssNum(0, 'px'),
  '--r-scroll-area-rail-inset-left': CssNum(0, 'px'),
  '--r-scroll-area-rail-inset-right': CssNum(0, 'px'),
  '--r-scroll-area-rail-inset-top': CssNum(0, 'px'),
  '--r-scroll-area-viewport-height': CssNum(100, '%'),
  '--r-scroll-area-viewport-width': CssNum(100, '%'),
  '--row-width': null,
  '--tw-blur': null,
  '--tw-border-style': CssKeyword('solid'),
  '--tw-brightness': null,
  '--tw-content': CssString(''),
  '--tw-contrast': null,
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
  '--tw-inset-ring-shadow': _v28,
  '--tw-inset-shadow': _v28,
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
  '--tw-ring-offset-shadow': _v28,
  '--tw-ring-offset-width': CssNum(0, 'px'),
  '--tw-ring-shadow': _v28,
  '--tw-rotate-x': null,
  '--tw-rotate-y': null,
  '--tw-rotate-z': null,
  '--tw-saturate': null,
  '--tw-scale-x': CssNum(1),
  '--tw-scale-y': CssNum(1),
  '--tw-scale-z': CssNum(1),
  '--tw-sepia': null,
  '--tw-shadow': _v28,
  '--tw-shadow-alpha': CssNum(100, '%'),
  '--tw-shadow-color': null,
  '--tw-skew-x': null,
  '--tw-skew-y': null,
  '--tw-slashed-zero': null,
  '--tw-tracking': null,
  '--tw-translate-x': CssNum(0),
  '--tw-translate-y': CssNum(0),
  '--tw-translate-z': CssNum(0),
};

const RaftRecipeEngine raftRecipeEngine = RaftRecipeEngine(
  raftRecipeUtilities,
  raftRecipeRegistered,
);

const _v0 = CssVar('--foreground', null, 'foreground');
const _v1 = CssColor(0xFFE5E5E2, 'oklch(0.9211 0.004 106.48)');
const _v2 = CssVar('--foreground-muted', null, 'foregroundMuted');
const _v3 = CssColor(0xFFC4C4C1, 'oklch(0.8195 0.0041 106.49)');
const _v4 = CssVar('--field-font-weight', null, 'fieldFontWeight');
const _v5 = CssKeyword('space-between');
const _v6 = CssVar('--control-embedded-size', null, 'controlEmbeddedSize');
const _v7 = CssKeyword('background-color');
const _v8 = CssKeyword('box-shadow');
const _v9 = CssList([CssKeyword('color'), _v7, _v8]);
const _v10 = CssFunction('cubic-bezier', [
  CssNum(0.4),
  CssNum(0),
  CssNum(0.2),
  CssNum(1),
]);
const _v11 = CssVar('--tw-ease', _v10);
const _v12 = CssVar('--tw-duration', CssNum(150, 'ms'));
const _v13 = CssFunction('cubic-bezier', [
  CssNum(0.16),
  CssNum(1),
  CssNum(0.3),
  CssNum(1),
]);
const _v14 = CssList([
  CssKeyword('opacity'),
  CssKeyword('filter'),
  CssKeyword('scale'),
]);
const _v15 = CssColor(0x00000000, 'transparent');
const _v16 = CssVar('--tw-border-style');
const _v17 = CssVar('--tw-ring-inset', CssSeq([]));
const _v18 = CssVar('--tw-ring-offset-width');
const _v19 = CssOp('+', CssNum(0, 'px'), _v18);
const _v20 = CssKeyword('currentcolor');
const _v21 = CssVar('--tw-ring-color', _v20);
const _v22 = CssSeq([
  _v17,
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssCalc(_v19),
  _v21,
]);
const _v23 = CssVar('--tw-inset-shadow');
const _v24 = CssVar('--tw-inset-ring-shadow');
const _v25 = CssVar('--tw-ring-offset-shadow');
const _v26 = CssVar('--tw-ring-shadow');
const _v27 = CssList([_v23, _v24, _v25, _v26, CssVar('--tw-shadow')]);
const _v28 = CssSeq([CssNum(0), CssNum(0), CssColor(0x00000000)]);
const _v29 = CssVar('--fill-frame-medium', null, 'fillFrameMedium');
const _v30 = CssFunction('linear-gradient', [_v29, _v29]);
const _v31 = CssColor(0x0FFAFAF7, 'oklch(0.9843 0.004 106.47 / 0.06)');
const _v32 = CssFunction('linear-gradient', [_v31, _v31]);
const _v33 = CssVar('--layer-frame-active', null, 'layerFrameActive');
const _v34 = CssColor(0xFFFFD440, 'oklch(0.8829 0.1623 91.9)');
const _v35 = CssVar('--line-frame-active', null, 'lineFrameActive');
const _v36 = CssVar(
  '--foreground-on-frame-active',
  null,
  'foregroundOnFrameActive',
);
const _v37 = CssVar('--foreground-on-frame', null, 'foregroundOnFrame');
const _v38 = CssVar(
  '--foreground-on-frame-muted',
  null,
  'foregroundOnFrameMuted',
);
const _v39 = CssColor(0xFF9E9E9B, 'oklch(0.6984 0.0043 106.51)');
const _v40 = CssKeyword('sans-serif');
const _v41 = CssList([CssKeyword('system-ui'), _v40]);
const _v42 = CssVar('--sans-font', _v41, 'sansFont');
const _v43 = CssVar('--tw-leading', CssNum(18, 'px'));
const _v44 = CssVar('--foreground-hint', null, 'foregroundHint');
const _v45 = CssList([
  CssKeyword('transform'),
  CssKeyword('translate'),
  CssKeyword('scale'),
  CssKeyword('rotate'),
]);
const _v46 = CssKeyword('inline-flex');
const _v47 = CssOp('-', CssNum(1, 'lh'), CssNum(19, 'px'));
const _v48 = CssOp('/', _v47, CssNum(2));
const _v49 = CssVar('--header-air', null, 'headerAir');
const _v50 = CssOp('+', _v49, CssNum(1.5, 'px'));
const _v51 = CssOp('*', _v50, CssNum(-1));
const _v52 = CssOp('-', CssNum(1, 'lh'), CssNum(20, 'px'));
const _v53 = CssOp('/', _v52, CssNum(2));
const _v54 = CssFunction('min', [CssNum(100, '%'), CssNum(384, 'px')]);
const _v55 = CssOp('*', CssVar('--ig-hit'), CssNum(-1));
const _v56 = CssOp('*', CssNum(2), CssVar('--ig-hit'));
const _v57 = CssOp('+', CssNum(100, '%'), _v56);
const _v58 = CssKeyword('inline-block');
const _v59 = CssOp('-', CssNum(0.5, 'lh'), CssNum(50, '%'));
const _v60 = CssSeq([CssNum(0), CssCalc(_v59)]);
const _v61 = CssKeyword('flex-start');
const _v62 = CssOp('-', CssNum(1, 'lh'), CssVar('--lead-dot'));
const _v63 = CssOp('/', _v62, CssNum(2));
const _v64 = CssOp('+', CssNum(50, '%'), CssNum(6, 'px'));
const _v65 = CssVar('--switch-height', null, 'switchHeight');
const _v66 = CssOp('-', CssNum(1, 'lh'), _v65);
const _v67 = CssOp('/', _v66, CssNum(2));
const _v68 = CssOp('-', CssNum(1, 'lh'), CssNum(22, 'px'));
const _v69 = CssOp('/', _v68, CssNum(2));
const _v70 = CssKeyword('safe-area-inset-right');
const _v71 = CssFunction('env', [_v70, CssNum(0, 'px')]);
const _v72 = CssOp('+', CssNum(16, 'px'), _v71);
const _v73 = CssKeyword('safe-area-inset-top');
const _v74 = CssFunction('env', [_v73, CssNum(0, 'px')]);
const _v75 = CssOp('+', CssNum(16, 'px'), _v74);
const _v76 = CssVar('--inbox-item-aside-room', CssNum(0, 'px'));
const _v77 = CssVar('--inbox-item-reveal-aside', CssNum(0));
const _v78 = CssVar('--inbox-item-revealed', CssNum(0));
const _v79 = CssOp('-', CssNum(1), CssOp('*', _v77, _v78));
const _v80 = CssOp('*', CssVar('--icon-inset'), CssNum(-1));
const _v81 = CssOp('-', CssNum(32, 'px'), CssNum(1, 'lh'));
const _v82 = CssOp('/', _v81, CssNum(2));
const _v83 = CssOp('*', _v82, CssNum(-1));
const _v84 = CssVar('--tw-translate-x');
const _v85 = CssVar('--tw-translate-y');
const _v86 = CssKeyword('inline-size');
const _v87 = CssKeyword('announcement');
const _v88 = CssFunction('inset', [CssNum(50, '%')]);
const _v89 = CssVar('--segment-size');
const _v90 = CssSeq([CssKeyword('span'), CssNum(2)]);
const _v91 = CssVar('--banner-text-col', CssNum(1));
const _v92 = CssOp('+', _v91, CssNum(1));
const _v93 = CssVar('--banner-last-row', CssNum(1));
const _v94 = CssVar('--toast-title-only-min-h', CssNum(36, 'px'));
const _v95 = CssVar('--toast-title-only-min-w', CssNum(112, 'px'));
const _v96 = CssVar('--toast-title-only-px', CssNum(12, 'px'));
const _v97 = CssVar('--toast-title-only-py', CssNum(8, 'px'));
const _v98 = CssVar('--control-embedded-inset', null, 'controlEmbeddedInset');
const _v99 = CssOp('-', _v98, CssNum(12, 'px'));
const _v100 = CssOp('-', _v99, CssNum(1, 'px'));
const _v101 = CssOp('+', CssNum(100, '%'), CssNum(7, 'px'));
const _v102 = CssOp('+', CssNum(100, '%'), CssNum(6, 'px'));
const _v103 = CssKeyword('break-word');
const _v104 = CssVar('--fill-medium', null, 'fillMedium');
const _v105 = CssColor(0x11FAFAF7, 'oklch(0.9843 0.004 106.47 / 0.065)');
const _v106 = CssOp('-', CssNum(1, 'lh'), CssNum(14, 'px'));
const _v107 = CssOp('/', _v106, CssNum(2));
const _v108 = CssOp('-', CssNum(1, 'lh'), CssNum(16, 'px'));
const _v109 = CssOp('/', _v108, CssNum(2));
const _v110 = CssVar('--control-icon-size', null, 'controlIconSize');
const _v111 = CssVar('--read-mark', null, 'readMark');
const _v112 = CssVar('--presence-online', null, 'presenceOnline');
const _v113 = CssVar('--fill-subtle', null, 'fillSubtle');
const _v114 = CssColor(0x08FAFAF7, 'oklch(0.9843 0.004 106.47 / 0.03)');
const _v115 = CssFunction('translatey', [CssNum(120, '%')]);
const _v116 = CssFunction('scale', [CssNum(0.98)]);
const _v117 = CssFunction('minmax', [CssNum(0), CssNum(1, 'fr')]);
const _v118 = CssSeq([CssKeyword('auto'), _v117, CssKeyword('auto')]);
const _v119 = CssSeq([CssNum(1), CssSlash(), CssNum(-1)]);
const _v120 = CssNum(1.3333333333333333);
const _v121 = CssVar('--tw-leading', _v120);
const _v122 = CssVar('--mi-avatar', CssNum(35, 'px'));
const _v123 = CssFunction('cubic-bezier', [
  CssNum(0),
  CssNum(0),
  CssNum(0.2),
  CssNum(1),
]);
const _v124 = CssKeyword('safe-area-inset-bottom');
const _v125 = CssFunction('env', [_v124, CssNum(0, 'px')]);
const _v126 = CssFunction('max', [CssNum(16, 'px'), CssCalc(_v125)]);
const _v127 = CssVar('--focus-ring', null, 'focusRing');
const _v128 = CssColor(0xFF1B1B19, 'oklch(0.2213 0.0038 106.71)');
const _v129 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(2, 'px'), _v128]);
const _v130 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(4, 'px'), _v1]);
const _v131 = CssVar('--tw-leading', CssNum(1.4));
const _v132 = CssNum(1.5555555555555556);
const _v133 = CssVar('--tw-leading', _v132);
const _v134 = CssVar('--tw-leading', CssNum(1.5));
const _v135 = CssVar('--tw-inset-ring-color', _v20);
const _v136 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(2, 'px'),
  _v135,
]);
const _v137 = CssVar('--shiki-light', _v20);
const _v138 = CssVar('--attention-400', null, 'attention400');
const _v139 = CssKeyword('ui-monospace');
const _v140 = CssList([_v139, CssKeyword('monospace')]);
const _v141 = CssVar('--mono-font', _v140, 'monoFont');
const _v142 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v135,
]);
const _v143 = CssVar('--sticker-ink', null, 'stickerInk');
const _v144 = CssOp('+', CssNum(1.5, 'px'), _v18);
const _v145 = CssSeq([
  _v17,
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssCalc(_v144),
  _v21,
]);
const _v146 = CssVar('--sticker-edge', null, 'stickerEdge');
const _v147 = CssColor(0x59FAFAF7, 'oklch(0.9843 0.004 106.47 / 0.349)');
const _v148 = CssVar('--tw-leading', CssNum(16, 'px'));
const _v149 = CssKeyword('non-scaling-stroke');
const _v150 = CssVar('--cell-inset-x');
const _v151 = CssVar('--scrollbar-size', CssNum(0, 'px'));
const _v152 = CssOp('-', _v150, _v151);
const _v153 = CssFunction('max', [CssNum(0, 'px'), CssCalc(_v152)]);
const _v154 = CssVar('--drawer-exit-x', CssNum(0, 'px'));
const _v155 = CssVar('--drawer-exit-y', CssNum(0, 'px'));
const _v156 = CssFunction('translate3d', [_v154, _v155, CssNum(0)]);
const _v157 = CssOp('*', CssNum(2), _v98);
const _v158 = CssOp('-', CssNum(32, 'px'), _v157);
const _v159 = CssVar('--drawer-height', CssKeyword('auto'));
const _v160 = CssFunction('cubic-bezier', [
  CssNum(0.32),
  CssNum(0.72),
  CssNum(0),
  CssNum(1),
]);
const _v161 = CssVar('--drawer-inset');
const _v162 = CssOp('-', CssNum(-100, '%'), _v161);
const _v163 = CssOp('-', _v162, CssNum(2, 'px'));
const _v164 = CssOp('+', CssNum(100, '%'), _v161);
const _v165 = CssOp('+', _v164, CssNum(2, 'px'));
const _v166 = CssVar('--nested-drawers');
const _v167 = CssVar('--drawer-stack-progress');
const _v168 = CssOp('-', _v166, _v167);
const _v169 = CssVar('--drawer-stack-peek');
const _v170 = CssOp('*', _v168, _v169);
const _v171 = CssFunction('max', [CssNum(0, 'px'), CssCalc(_v170)]);
const _v172 = CssVar('--drawer-swipe-progress');
const _v173 = CssFunction('clamp', [CssNum(0), CssCalc(_v172), CssNum(1)]);
const _v174 = CssVar('--drawer-stack-step');
const _v175 = CssOp('*', _v166, _v174);
const _v176 = CssOp('-', CssNum(1), _v175);
const _v177 = CssFunction('max', [CssNum(0), CssCalc(_v176)]);
const _v178 = CssVar('--drawer-stack-scale-base');
const _v179 = CssOp('*', _v174, _v167);
const _v180 = CssOp('+', _v178, _v179);
const _v181 = CssFunction('clamp', [CssNum(0), CssCalc(_v180), CssNum(1)]);
const _v182 = CssVar('--drawer-stack-shrink');
const _v183 = CssVar('--drawer-stack-size');
const _v184 = CssOp('*', _v182, _v183);
const _v185 = CssVar('--drawer-stack-scale');
const _v186 = CssOp('-', CssNum(1), _v185);
const _v187 = CssVar('--drawer-height');
const _v188 = CssVar('--drawer-frontmost-height', _v187);
const _v189 = CssFunction('max', [CssNum(0, 'px'), CssCalc(_v188)]);
const _v190 = CssVar('--drawer-stack-offset');
const _v191 = CssOp('-', CssNum(0, 'px'), _v190);
const _v192 = CssVar('--drawer-stack-shrink-offset');
const _v193 = CssOp('-', _v191, _v192);
const _v194 = CssOp('+', _v190, _v192);
const _v195 = CssVar('--drawer-swipe-movement-x');
const _v196 = CssVar('--drawer-snap-point-offset', CssNum(0, 'px'));
const _v197 = CssVar('--drawer-swipe-movement-y');
const _v198 = CssOp('+', _v196, _v197);
const _v199 = CssSeq([CssNum(0, '%'), CssNum(50, '%')]);
const _v200 = CssSeq([CssNum(100, '%'), CssNum(50, '%')]);
const _v201 = CssSeq([CssNum(50, '%'), CssNum(0, '%')]);
const _v202 = CssSeq([CssNum(50, '%'), CssNum(100, '%')]);
const _v203 = CssVar('--bar-button-size', null, 'barButtonSize');
const _v204 = CssOp('-', _v203, _v110);
const _v205 = CssOp('/', _v204, CssNum(2));
const _v206 = CssVar('--control-height', null, 'controlHeight');
const _v207 = CssOp('-', _v206, _v110);
const _v208 = CssOp('/', _v207, CssNum(2));
const _v209 = CssVar('--frame-item-height', null, 'frameItemHeight');
const _v210 = CssOp('-', _v209, CssNum(20, 'px'));
const _v211 = CssOp('/', _v210, CssNum(2));
const _v212 = CssVar('--info', null, 'info');
const _v213 = CssVar('--warning', null, 'warning');
const _v214 = CssVar('--warning-strong', null, 'warningStrong');
const _v215 = CssColor(0xFFFFAF76, 'oklch(0.82 0.12 55)');
const _v216 = CssVar('--located-fill');
const _v217 = CssVar('--danger', null, 'danger');
const _v218 = CssVar('--success', null, 'success');
const _v219 = CssVar('--progress-color');
const _v220 = CssVar('--fill-muted', null, 'fillMuted');
const _v221 = CssColor(0xFF32322F, 'oklch(0.3161 0.0052 106.7)');
const _v222 = CssVar('--header-height', null, 'headerHeight');
const _v223 = CssVar('--palette-stone-400', null, 'paletteStone400');
const _v224 = CssVar('--presence-busy', null, 'presenceBusy');
const _v225 = CssVar('--presence-offline', null, 'presenceOffline');
const _v226 = CssOp('*', CssVar('--toast-index'), CssNum(0.04));
const _v227 = CssOp('-', CssNum(1), _v226);
const _v228 = CssFunction('max', [CssNum(0.84), CssCalc(_v227)]);
const _v229 = CssVar('--toast-height');
const _v230 = CssVar('--toast-frontmost-height', _v229);
const _v231 = CssVar('--toast-offset-y');
const _v232 = CssOp('*', _v231, CssNum(-1));
const _v233 = CssOp('*', CssVar('--toast-index'), CssVar('--toast-gap'));
const _v234 = CssOp('-', _v232, _v233);
const _v235 = CssVar('--toast-swipe-movement-y');
const _v236 = CssOp('+', _v234, _v235);
const _v237 = CssFunction('linear-gradient', [_v113, _v113]);
const _v238 = CssFunction('linear-gradient', [_v114, _v114]);
const _v239 = CssVar('--header-height-short', null, 'headerHeightShort');
const _v240 = CssVar('--control-air', null, 'controlAir');
const _v241 = CssOp('*', CssNum(2), _v240);
const _v242 = CssOp('+', CssNum(28, 'px'), _v241);
const _v243 = CssVar('--raft-frame-inset-start', CssNum(0, 'px'));
const _v244 = CssVar('--rail-width-short', null, 'railWidthShort');
const _v245 = CssOp('-', _v244, CssNum(1, 'px'));
const _v246 = CssVar('--rail-item-short', null, 'railItemShort');
const _v247 = CssOp('-', _v245, _v246);
const _v248 = CssOp('/', _v247, CssNum(2));
const _v249 = CssOp('+', _v243, _v248);
const _v250 = CssOp('-', _v98, CssNum(8, 'px'));
const _v251 = CssOp('-', _v250, CssNum(1, 'px'));
const _v252 = CssVar('--line-hairline', null, 'lineHairline');
const _v253 = CssColor(0x1AFAFAF7, 'oklch(0.9843 0.004 106.47 / 0.102)');
const _v254 = CssVar('--settings-row-inset', null, 'settingsRowInset');
const _v255 = CssFunction('translatey', [CssNum(-120, '%')]);
const _v256 = CssVar('--brand-400', null, 'brand400');
const _v257 = CssFunction('linear-gradient', [_v104, _v104]);
const _v258 = CssFunction('linear-gradient', [_v105, _v105]);
const _v259 = CssVar('--ca-overlay-border', CssNum(2, 'px'));
const _v260 = CssSeq([CssKeyword('auto'), CssNum(1, 'lh')]);
const _v261 = CssVar('--inbox-item-content-display', CssKeyword('block'));
const _v262 = CssVar('--inbox-item-time-display', CssKeyword('none'));
const _v263 = CssFunction('max', [CssNum(0, 'px'), CssCalc(_v53)]);
const _v264 = CssOp('+', _v263, CssNum(4, 'px'));
const _v265 = CssOp('*', _v264, CssNum(-1));
const _v266 = CssOp('+', _v263, CssNum(5.5, 'px'));
const _v267 = CssOp('*', _v266, CssNum(-1));
const _v268 = CssVar('--mi-toolbar-pe', CssKeyword('none'));
const _v269 = CssKeyword('alphabetic');
const _v270 = CssSeq([CssKeyword('trim-both'), CssKeyword('cap'), _v269]);
const _v271 = CssVar('--foreground-on-hud', null, 'foregroundOnHud');
const _v272 = CssSeq([CssKeyword('in'), CssKeyword('oklab')]);
const _v273 = CssSeq([_v271, CssNum(15, '%')]);
const _v274 = CssFunction('color-mix', [_v272, _v273, _v15]);
const _v275 = CssVar('--brand-soft', null, 'brandSoft');
const _v276 = CssColor(0x33876F1F, 'oklch(0.5501 0.0999 91.5 / 0.2)');
const _v277 = CssVar('--sticker-medium', null, 'stickerMedium');
const _v278 = CssFunction('linear-gradient', [_v277, _v277]);
const _v279 = CssOp('-', CssNum(44, 'px'), _v209);
const _v280 = CssOp('/', _v279, CssNum(2));
const _v281 = CssOp('+', _v280, CssNum(1.5, 'px'));
const _v282 = CssOp('*', _v281, CssNum(-1));
const _v283 = CssVar('--control-hit-inset', null, 'controlHitInset');
const _v284 = CssOp('*', CssNum(2), _v283);
const _v285 = CssOp('+', _v206, _v284);
const _v286 = CssOp('-', _v285, _v203);
const _v287 = CssOp('/', _v286, CssNum(2));
const _v288 = CssOp('+', _v287, CssNum(1.5, 'px'));
const _v289 = CssOp('*', _v288, CssNum(-1));
const _v290 = CssOp('+', _v283, CssNum(1.5, 'px'));
const _v291 = CssOp('*', _v290, CssNum(-1));
const _v292 = CssOp('-', CssNum(44, 'px'), _v65);
const _v293 = CssOp('/', _v292, CssNum(2));
const _v294 = CssOp('+', _v293, CssNum(1.5, 'px'));
const _v295 = CssOp('*', _v294, CssNum(-1));
const _v296 = CssVar('--frame-decor-rail', CssKeyword('none'));
const _v297 = CssSeq([CssKeyword('center'), CssKeyword('bottom')]);
const _v298 = CssOp('-', CssNum(100, '%'), CssNum(44, 'px'));
const _v299 = CssOp('/', _v298, CssNum(2));
const _v300 = CssFunction('min', [CssNum(0, 'px'), CssCalc(_v299)]);
const _v301 = CssKeyword('raft-toast-timeout-progress');
const _v302 = CssVar('--toast-progress-duration');
const _v303 = CssSeq([
  _v301,
  _v302,
  CssKeyword('linear'),
  CssKeyword('forwards'),
]);
const _v304 = CssFunction('cubic-bezier', [
  CssNum(0.4),
  CssNum(0),
  CssNum(0.6),
  CssNum(1),
]);
const _v305 = CssSeq([
  CssKeyword('pulse'),
  CssNum(2000, 'ms'),
  _v304,
  CssKeyword('infinite'),
]);
const _v306 = CssVar('--foreground-disabled', null, 'foregroundDisabled');
const _v307 = CssColor(0xFF636360, 'oklch(0.4987 0.0047 106.57)');
const _v308 = CssKeyword('not-allowed');
const _v309 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(0, 'px'),
  _v135,
]);
const _v310 = CssVar('--selected', null, 'selected');
const _v311 = CssVar('--info-soft', null, 'infoSoft');
const _v312 = CssColor(0x2E005F7A, 'oklch(0.452 0.0862 225.67 / 0.18)');
const _v313 = CssSeq([CssNum(16), CssSlash(), CssNum(9)]);
const _v314 = CssKeyword('min-content');
const _v315 = CssVar('--fit-scroll-basis', CssNum(0, 'px'));
const _v316 = CssVar('--inactive', null, 'inactive');
const _v317 = CssVar('--line-seam', null, 'lineSeam');
const _v318 = CssColor(0x42FAFAF7, 'oklch(0.9843 0.004 106.47 / 0.259)');
const _v319 = CssOp('+', CssVar('--toast-gap'), CssNum(3, 'px'));
const _v320 = CssVar('--list-row-rule-start');
const _v321 = CssVar('--cell-inset-end');
const _v322 = CssNum(3.4028234663852886e+38, 'px');
const _v323 = CssKeyword('border-color');
const _v324 = CssKeyword('outline-color');
const _v325 = CssKeyword('text-decoration-color');
const _v326 = CssKeyword('--tw-gradient-from');
const _v327 = CssKeyword('--tw-gradient-via');
const _v328 = CssKeyword('--tw-gradient-to');
const _v329 = CssList([
  CssKeyword('color'),
  _v7,
  _v323,
  _v324,
  _v325,
  CssKeyword('fill'),
  CssKeyword('stroke'),
  _v326,
  _v327,
  _v328,
]);
const _v330 = CssVar('--meter-indicator');
const _v331 = CssVar('--progress-indicator');
const _v332 = CssVar('--progress-track');
const _v333 = CssVar('--split-action-main-tint', _v15);
const _v334 = CssVar('--split-action-menu-tint', _v15);
const _v335 = CssVar('--status-color');
const _v336 = CssFunction('linear-gradient', [_v311, _v311]);
const _v337 = CssFunction('linear-gradient', [_v312, _v312]);
const _v338 = CssVar('--mi-row-fill', _v15);
const _v339 = CssFunction('linear-gradient', [_v338, _v338]);
const _v340 = CssVar('--attention-soft', null, 'attentionSoft');
const _v341 = CssColor(0x29D0457C, 'oklch(0.5997 0.1805 359.83 / 0.161)');
const _v342 = CssColor(0xFF000000, 'oklch(0 0 0)');
const _v343 = CssKeyword('padding-box');
const _v344 = CssVar('--danger-soft', null, 'dangerSoft');
const _v345 = CssColor(0x2EC93126, 'oklch(0.5509 0.1903 29.01 / 0.18)');
const _v346 = CssSeq([_v271, CssNum(40, '%')]);
const _v347 = CssFunction('color-mix', [_v272, _v346, _v15]);
const _v348 = CssSeq([_v0, CssNum(10, '%')]);
const _v349 = CssFunction('color-mix', [_v272, _v348, _v15]);
const _v350 = CssSeq([_v0, CssNum(15, '%')]);
const _v351 = CssFunction('color-mix', [_v272, _v350, _v15]);
const _v352 = CssSeq([_v0, CssNum(25, '%')]);
const _v353 = CssFunction('color-mix', [_v272, _v352, _v15]);
const _v354 = CssSeq([_v0, CssNum(40, '%')]);
const _v355 = CssFunction('color-mix', [_v272, _v354, _v15]);
const _v356 = CssVar('--inactive-soft', null, 'inactiveSoft');
const _v357 = CssVar('--layer-backdrop', null, 'layerBackdrop');
const _v358 = CssColor(0x99000000, 'oklch(0 0 0 / 0.6)');
const _v359 = CssVar('--layer-backdrop-nested', null, 'layerBackdropNested');
const _v360 = CssColor(
  0x66000000,
  'oklch(0 0 0 / 0.4)',
  Color.from(alpha: 0.401164, red: 0.000470, green: 0.000810, blue: 0.000341),
);
const _v361 = CssVar('--layer-canvas', null, 'layerCanvas');
const _v362 = CssVar('--layer-card', null, 'layerCard');
const _v363 = CssColor(0xFF242422, 'oklch(0.2596 0.0037 106.65)');
const _v364 = CssVar('--layer-code', null, 'layerCode');
const _v365 = CssColor(0xFF0A0C10, 'oklch(0.154 0.0092 264.28)');
const _v366 = CssVar('--layer-frame', null, 'layerFrame');
const _v367 = CssColor(0xFF0D0D0B, 'oklch(0.1582 0.0041 106.86)');
const _v368 = CssVar('--layer-hud', null, 'layerHud');
const _v369 = CssColor(0xFF292927, 'oklch(0.2802 0.0036 106.63)');
const _v370 = CssVar('--layer-popover', null, 'layerPopover');
const _v371 = CssVar('--layer-sidebar', null, 'layerSidebar');
const _v372 = CssVar('--layer-veil', null, 'layerVeil');
const _v373 = CssColor(0xCC1B1B19, 'oklch(0.2213 0.0038 106.71 / 0.8)');
const _v374 = CssSeq([CssKeyword('to'), CssKeyword('top')]);
const _v375 = CssVar('--tw-gradient-stops');
const _v376 = CssFunction('linear-gradient', [_v375]);
const _v377 = CssSeq([
  CssKeyword('to'),
  CssKeyword('top'),
  CssKeyword('in'),
  CssKeyword('oklab'),
]);
const _v378 = CssVar('--palette-lavender-400', null, 'paletteLavender400');
const _v379 = CssVar('--presence-busy-soft', null, 'presenceBusySoft');
const _v380 = CssVar('--sticker-paper', null, 'stickerPaper');
const _v381 = CssVar('--success-soft', null, 'successSoft');
const _v382 = CssColor(0x2E167641, 'oklch(0.4997 0.1193 153.22 / 0.18)');
const _v383 = CssVar('--task-status-closed-soft', null, 'taskStatusClosedSoft');
const _v384 = CssVar('--task-status-done-soft', null, 'taskStatusDoneSoft');
const _v385 = CssVar(
  '--task-status-in-progress-soft',
  null,
  'taskStatusInProgressSoft',
);
const _v386 = CssVar(
  '--task-status-in-review-soft',
  null,
  'taskStatusInReviewSoft',
);
const _v387 = CssColor(0x3D6853A0, 'oklch(0.4995 0.1202 294.19 / 0.239)');
const _v388 = CssVar('--task-status-todo-soft', null, 'taskStatusTodoSoft');
const _v389 = CssColor(0x2E9E511E, 'oklch(0.5204 0.1197 50.16 / 0.18)');
const _v390 = CssVar('--warning-soft', null, 'warningSoft');
const _v391 = CssVar('--you', null, 'you');
const _v392 = CssVar('--danger-strong', null, 'dangerStrong');
const _v393 = CssColor(0xFFF8A49D, 'oklch(0.7996 0.1009 24.79)');
const _v394 = CssVar('--line-field', null, 'lineField');
const _v395 = CssVar('--line-strong', null, 'lineStrong');
const _v396 = CssSeq([_v380, CssNum(40, '%')]);
const _v397 = CssFunction('color-mix', [_v272, _v396, _v15]);
const _v398 = CssVar('--timeline-gap-message', null, 'timelineGapMessage');
const _v399 = CssVar('--timeline-row-inset', null, 'timelineRowInset');
const _v400 = CssOp('*', CssNum(2), _v399);
const _v401 = CssOp('-', _v398, _v400);
const _v402 = CssVar('--message-list-bottom-inset', CssNum(0, 'px'));
const _v403 = CssOp('+', CssNum(12, 'px'), _v402);
const _v404 = CssVar('--toast-viewport-bottom', CssNum(0, 'px'));
const _v405 = CssFunction('env', [_v124]);
const _v406 = CssFunction('max', [CssCalc(_v404), CssCalc(_v405)]);
const _v407 = CssOp('+', _v406, CssNum(16, 'px'));
const _v408 = CssOp('-', _v98, CssNum(1, 'px'));
const _v409 = CssKeyword('border-box');
const _v410 = CssKeyword('inline-end');
const _v411 = CssSeq([CssNum(-2), CssSlash(), CssNum(-1)]);
const _v412 = CssVar('--banner-action-end', CssNum(-1));
const _v413 = CssVar('--inbox-item-content-end');
const _v414 = CssSeq([
  CssKeyword('span'),
  CssNum(2),
  CssSlash(),
  CssKeyword('span'),
  CssNum(2),
]);
const _v415 = CssVar('--card-text-col', CssNum(1));
const _v416 = CssVar('--card-trailing-col', CssNum(2));
const _v417 = CssVar('--shiki-dark', _v20);
const _v418 = CssVar('--tw-shadow-color', _v338);
const _v419 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(3, 'px'), _v418]);
const _v420 = CssVar('--tw-shadow-color', _v361);
const _v421 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(3, 'px'), _v420]);
const _v422 = CssVar('--tw-shadow-color', _v128);
const _v423 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(3, 'px'), _v422]);
const _v424 = CssVar('--fill-cell-selected', null, 'fillCellSelected');
const _v425 = CssColor(0x61005F7A, 'oklch(0.452 0.0862 225.67 / 0.38)');
const _v426 = CssVar('--opacity-dimmed', null, 'opacityDimmed');
const _v427 = CssSeq([CssVar('--tw-scale-x'), CssVar('--tw-scale-y')]);
const _v428 = CssFunction('repeat', [CssNum(3), _v117]);
const _v429 = CssVar('--control-radius', null, 'controlRadius');
const _v430 = CssFunction('blur', [CssNum(1, 'px')]);
const _v431 = CssVar('--tw-blur', CssSeq([]));
const _v432 = CssVar('--tw-brightness', CssSeq([]));
const _v433 = CssVar('--tw-contrast', CssSeq([]));
const _v434 = CssVar('--tw-grayscale', CssSeq([]));
const _v435 = CssVar('--tw-hue-rotate', CssSeq([]));
const _v436 = CssVar('--tw-invert', CssSeq([]));
const _v437 = CssVar('--tw-saturate', CssSeq([]));
const _v438 = CssVar('--tw-sepia', CssSeq([]));
const _v439 = CssVar('--tw-drop-shadow', CssSeq([]));
const _v440 = CssSeq([
  _v431,
  _v432,
  _v433,
  _v434,
  _v435,
  _v436,
  _v437,
  _v438,
  _v439,
]);
const _v441 = CssVar('--tw-shadow-color', _v0);
const _v442 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(3.5, 'px'),
  _v441,
]);
const _v443 = CssVar('--tw-shadow-color', _v1);
const _v444 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(3.5, 'px'),
  _v443,
]);
const _v445 = CssSeq([
  CssKeyword('inset'),
  CssNum(-2, 'px'),
  CssNum(0),
  CssNum(0),
  _v441,
]);
const _v446 = CssSeq([
  CssKeyword('inset'),
  CssNum(-2, 'px'),
  CssNum(0),
  CssNum(0),
  _v443,
]);
const _v447 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(-2, 'px'),
  CssNum(0),
  _v441,
]);
const _v448 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(-2, 'px'),
  CssNum(0),
  _v443,
]);
const _v449 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(2, 'px'),
  CssNum(0),
  _v441,
]);
const _v450 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(2, 'px'),
  CssNum(0),
  _v443,
]);
const _v451 = CssSeq([
  CssKeyword('inset'),
  CssNum(2, 'px'),
  CssNum(0),
  CssNum(0),
  _v441,
]);
const _v452 = CssSeq([
  CssKeyword('inset'),
  CssNum(2, 'px'),
  CssNum(0),
  CssNum(0),
  _v443,
]);
const _v453 = CssVar('--elevation-float', null, 'elevationFloat');
const _v454 = CssColor(0x14FAFAF7, 'oklch(0.9843 0.004 106.47 / 0.078)');
const _v455 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(1, 'px'), _v454]);
const _v456 = CssColor(0xCC000000, 'oklch(0 0 0 / 0.8)');
const _v457 = CssSeq([
  CssNum(0),
  CssNum(16, 'px'),
  CssNum(40, 'px'),
  CssNum(-12, 'px'),
  _v456,
]);
const _v458 = CssVar('--tw-shadow-color', _v306);
const _v459 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v458,
]);
const _v460 = CssVar('--tw-shadow-color', _v307);
const _v461 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v460,
]);
const _v462 = CssVar('--tw-shadow-color', _v143);
const _v463 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v462,
]);
const _v464 = CssVar('--switch-width', null, 'switchWidth');
const _v465 = CssCalc(CssOp('-', _v464, _v65));
const _v466 = CssFunction('grayscale', [CssNum(100, '%')]);
const _v467 = CssFunction('blur', [CssVar('--drawer-blur')]);
const _v468 = CssOp('+', _v235, CssNum(120, '%'));
const _v469 = CssFunction('translatey', [CssCalc(_v468)]);
const _v470 = CssVar('--toast-swipe-movement-x');
const _v471 = CssOp('-', _v470, CssNum(120, '%'));
const _v472 = CssFunction('translatex', [CssCalc(_v471)]);
const _v473 = CssFunction('translatey', [CssVar('--toast-y')]);
const _v474 = CssOp('+', _v470, CssNum(120, '%'));
const _v475 = CssFunction('translatex', [CssCalc(_v474)]);
const _v476 = CssOp('-', _v235, CssNum(120, '%'));
const _v477 = CssFunction('translatey', [CssCalc(_v476)]);
const _v478 = CssVar('--drawer-swipe-strength', CssNum(1));
const _v479 = CssOp('*', _v478, CssNum(180, 'ms'));
const _v480 = CssVar('--closed-transform');
const _v481 = CssFunction('scale', [CssNum(0.99)]);
const _v482 = CssFunction('translatex', [_v470]);
const _v483 = CssFunction('scale', [CssNum(1)]);
const _v484 = CssSeq([_v482, _v473, _v483]);
const _v485 = CssSeq([_v117, CssKeyword('auto')]);
const _v486 = CssSeq([CssKeyword('auto'), _v117]);
const _v487 = CssKeyword('raft-progress-indeterminate');
const _v488 = CssKeyword('ease-in-out');
const _v489 = CssSeq([
  _v487,
  CssNum(1400, 'ms'),
  _v488,
  CssKeyword('infinite'),
]);
const _v490 = CssSeq([CssKeyword('in'), CssKeyword('oklch')]);
const _v491 = CssSeq([_v217, CssNum(60, '%')]);
const _v492 = CssFunction('color-mix', [_v490, _v491, _v15]);
const _v493 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v135,
]);
const _v494 = CssVar('--drawer-frontmost-height');
const _v495 = CssOp('-', CssNum(24, 'px'), _v206);
const _v496 = CssOp('/', _v495, CssNum(2));
const _v497 = CssVar('--dialog-visible-height');
const _v498 = CssOp('-', CssOp('-', _v497, _v74), _v222);
const _v499 = CssOp('-', _v498, CssNum(16, 'px'));
const _v500 = CssVar('--dialog-visible-top');
const _v501 = CssOp('+', CssOp('+', _v500, _v74), _v222);
const _v502 = CssKeyword('column-reverse');
const _v503 = CssFunction('repeat', [CssNum(1), _v117]);
const _v504 = CssFunction('scale', [CssNum(0.97)]);
const _v505 = CssVar('--fade-edge', null, 'fadeEdge');
const _v506 = CssFunction('linear-gradient', [
  _v374,
  _v15,
  CssSeq([_v342, _v505]),
]);
const _v507 = CssVar('--foreground-link', null, 'foregroundLink');
const _v508 = CssColor(0xFF6DA7EC, 'oklch(0.717 0.1183 253.58)');
const _v509 = CssSeq([_v507, CssNum(40, '%')]);
const _v510 = CssFunction('color-mix', [_v272, _v509, _v15]);
const _v511 = CssFunction('cubic-bezier', [
  CssNum(0.22),
  CssNum(1),
  CssNum(0.36),
  CssNum(1),
]);
const _v512 = CssSeq([CssNum(0), CssNum(1)]);
const _v513 = CssVar('--mi-owner-flex', _v512);
const _v514 = CssVar('--mi-owner-basis', CssKeyword('auto'));
const _v515 = CssKeyword('wrap-reverse');
const _v516 = CssVar('--tw-outline-style');
const _v517 = CssColor(0xFFFFFFFF, 'oklch(1 0 0)');
const _v518 = CssVar('--tw-ring-offset-color');
const _v519 = CssSeq([_v17, CssNum(0), CssNum(0), CssNum(0), _v18, _v518]);
const _v520 = CssSeq([CssKeyword('to'), CssKeyword('left')]);
const _v521 = CssVar('--mi-toolbar-width');
const _v522 = CssOp('+', _v521, CssNum(8, 'px'));
const _v523 = CssSeq([_v15, CssCalc(_v522)]);
const _v524 = CssColor(0xFF000000, 'black');
const _v525 = CssOp('+', _v521, CssNum(20, 'px'));
const _v526 = CssSeq([_v524, CssCalc(_v525)]);
const _v527 = CssFunction('linear-gradient', [_v520, _v523, _v526]);
const _v528 = CssVar('--card-title-font-weight', null, 'cardTitleFontWeight');
const _v529 = CssVar('--heading-font', _v41, 'headingFont');
const _v530 = CssVar('--frame-decor-top-end', CssNum(72, 'px'));
const _v531 = CssVar('--raft-frame-inset-end', CssNum(0, 'px'));
const _v532 = CssOp('+', _v530, _v531);
const _v533 = CssSeq([
  CssKeyword('right'),
  CssCalc(_v532),
  CssKeyword('center'),
]);
const _v534 = CssVar('--frame-decor-top', CssKeyword('none'));
const _v535 = CssVar('--tw-gradient-position');
const _v536 = CssVar('--tw-gradient-from');
const _v537 = CssVar('--tw-gradient-from-position');
const _v538 = CssVar('--tw-gradient-to');
const _v539 = CssVar('--tw-gradient-to-position');
const _v540 = CssList([
  _v535,
  CssSeq([_v536, _v537]),
  CssSeq([_v538, _v539]),
]);
const _v541 = CssVar('--tw-gradient-via-stops', _v540);
const _v542 = CssVar('--field-gap', null, 'fieldGap');
const _v543 = CssFunction('repeat', [CssNum(2), _v117]);
const _v544 = CssSeq([CssNum(1, 'fr'), CssKeyword('auto'), CssNum(1, 'fr')]);
const _v545 = CssSeq([_v117, CssKeyword('auto'), _v117]);
const _v546 = CssKeyword('max-content');
const _v547 = CssFunction('minmax', [CssNum(88, 'px'), _v546]);
const _v548 = CssVar('--spinner-pixel');
const _v549 = CssFunction('repeat', [CssNum(2), _v548]);
const _v550 = CssSeq([_v359, CssNum(70, '%')]);
const _v551 = CssFunction('color-mix', [_v272, _v550, _v15]);
const _v552 = CssColor(
  0x47000000,
  'color-mix(in oklab, oklch(0 0 0 / 0.4) 70%, transparent)',
);
const _v553 = CssSeq([_v0, CssNum(20, '%')]);
const _v554 = CssFunction('color-mix', [_v272, _v553, _v15]);
const _v555 = CssVar('--fit-scroll-grow', CssNum(1));
const _v556 = CssVar('--code-block-header-height');
const _v557 = CssVar('--collapsible-panel-height');
const _v558 = CssVar('--drawer-content-height');
const _v559 = CssVar('--option-height', null, 'optionHeight');
const _v560 = CssVar('--row-height', null, 'rowHeight');
const _v561 = CssVar('--shell-header-height', _v222);
const _v562 = CssVar('--task-dnd-placeholder-height', CssNum(72, 'px'));
const _v563 = CssVar('--toast-stack-height');
const _v564 = CssOp('-', CssNum(100, '%'), CssNum(1, 'lh'));
const _v565 = CssOp('*', CssNum(2), _v49);
const _v566 = CssOp('+', _v209, _v565);
const _v567 = CssCalc(CssOp('+', _v222, _v74));
const _v568 = CssOp('-', CssNum(100, 'dvh'), CssNum(32, 'px'));
const _v569 = CssFunction('min', [CssNum(760, 'px'), CssCalc(_v568)]);
const _v570 = CssVar('--control-height-cta', null, 'controlHeightCta');
const _v571 = CssKeyword('fit-content');
const _v572 = CssVar('--timeline-gap-section', null, 'timelineGapSection');
const _v573 = CssVar('--banner-button');
const _v574 = CssOp('-', _v573, CssNum(1, 'lh'));
const _v575 = CssOp('/', _v574, CssNum(2));
const _v576 = CssOp('+', _v575, CssNum(4, 'px'));
const _v577 = CssVar('--banner-desc-row', CssNum(1));
const _v578 = CssVar('--inbox-item-actions-room', CssNum(0, 'px'));
const _v579 = CssSeq([CssNum(16, 'px'), _v117]);
const _v580 = CssSeq([CssNum(20, 'px'), _v117]);
const _v581 = CssKeyword('inbox-item-row');
const _v582 = CssSeq([
  CssKeyword('auto'),
  CssKeyword('auto'),
  _v117,
  CssKeyword('auto'),
]);
const _v583 = CssSeq([CssNum(1), CssNum(0)]);
const _v584 = CssVar('--ink-8', null, 'ink8');
const _v585 = CssColor(0x14FAFAF7, 'oklch(0.9843 0.004 106.47 / 0.08)');
const _v586 = CssSeq([_v380, CssNum(80, '%')]);
const _v587 = CssFunction('color-mix', [_v272, _v586, _v15]);
const _v588 = CssSeq([_v507, CssNum(80, '%')]);
const _v589 = CssFunction('color-mix', [_v272, _v588, _v0]);
const _v590 = CssColor(
  0x1F141111,
  'oklch(0.1813 0.00497 17.62 / 0.12)',
  Color.from(alpha: 0.121409, red: 0.051103, green: 0.051103, blue: 0.049304),
);
const _v591 = CssColor(
  0x1AFFFFFF,
  'oklch(1 0 0 / 0.1)',
  Color.from(alpha: 0.100429, red: 0.994815, green: 0.999979, blue: 0.998796),
);
const _v592 = CssFunction('light-dark', [_v590, _v591]);
const _v593 = CssColor(0xFF1D1D1D, 'oklch(0.23 0 0)');
const _v594 = CssFunction('light-dark', [_v517, _v593]);
const _v595 = CssVar('--checker-cell');
const _v596 = CssSeq([_v595, CssNum(25, '%')]);
const _v597 = CssSeq([_v15, CssNum(25, '%')]);
const _v598 = CssFunction('linear-gradient', [CssNum(45, 'deg'), _v596, _v597]);
const _v599 = CssFunction('linear-gradient', [
  CssNum(-45, 'deg'),
  _v596,
  _v597,
]);
const _v600 = CssSeq([_v15, CssNum(75, '%')]);
const _v601 = CssSeq([_v595, CssNum(75, '%')]);
const _v602 = CssFunction('linear-gradient', [CssNum(45, 'deg'), _v600, _v601]);
const _v603 = CssFunction('linear-gradient', [
  CssNum(-45, 'deg'),
  _v600,
  _v601,
]);
const _v604 = CssList([_v598, _v599, _v602, _v603]);
const _v605 = CssSeq([CssNum(0), CssNum(0)]);
const _v606 = CssSeq([CssNum(0), CssNum(8, 'px')]);
const _v607 = CssSeq([CssNum(8, 'px'), CssNum(-8, 'px')]);
const _v608 = CssSeq([CssNum(-8, 'px'), CssNum(0)]);
const _v609 = CssList([_v605, _v606, _v607, _v608]);
const _v610 = CssSeq([CssNum(16, 'px'), CssNum(16, 'px')]);
const _v611 = CssColor(0x1F141111, 'rgba(20, 17, 17, 0.12)');
const _v612 = CssSeq([_v611, CssNum(25, '%')]);
const _v613 = CssFunction('linear-gradient', [CssNum(45, 'deg'), _v612, _v597]);
const _v614 = CssFunction('linear-gradient', [
  CssNum(-45, 'deg'),
  _v612,
  _v597,
]);
const _v615 = CssSeq([_v611, CssNum(75, '%')]);
const _v616 = CssFunction('linear-gradient', [CssNum(45, 'deg'), _v600, _v615]);
const _v617 = CssFunction('linear-gradient', [
  CssNum(-45, 'deg'),
  _v600,
  _v615,
]);
const _v618 = CssList([_v613, _v614, _v616, _v617]);
const _v619 = CssVar('--tw-shadow-color', _v271);
const _v620 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v619,
]);
const _v621 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v443,
]);
const _v622 = CssSeq([_v271, CssNum(70, '%')]);
const _v623 = CssFunction('color-mix', [_v490, _v622, _v15]);
const _v624 = CssVar('--tw-shadow-color', _v623);
const _v625 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v624,
]);
const _v626 = CssVar('--tw-shadow-color', CssColor(0xB3E5E5E2));
const _v627 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1, 'px'),
  _v626,
]);
const _v628 = CssFunction('color-mix', [_v272, _v622, _v15]);
const _v629 = CssVar('--pull-progress');
const _v630 = CssOp('+', _v231, _v233);
const _v631 = CssOp('+', _v630, _v235);
const _v632 = CssKeyword('inline-grid');
const _v633 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(2, 'px'),
  _v441,
]);
const _v634 = CssSeq([
  CssKeyword('inset'),
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(2, 'px'),
  _v443,
]);
const _v635 = CssVar('--chip-line-height', CssNum(22, 'px'));
const _v636 = CssVar('--chip-line-height', CssNum(20, 'px'));
const _v637 = CssKeyword('-webkit-box');
const _v638 = CssVar('--ellipsis-lines');
const _v639 = CssKeyword('horizontal');
const _v640 = CssKeyword('raft-located');
const _v641 = CssVar('--located-animation', _v640);
const _v642 = CssSeq([_v641, CssNum(2000, 'ms'), CssKeyword('linear')]);
const _v643 = CssFunction('linear-gradient', [_v216, _v216]);
const _v644 = CssVar('--mi-header-mask', CssKeyword('none'));
const _v645 = CssVar('--fade-content', null, 'fadeContent');
const _v646 = CssFunction('linear-gradient', [
  _v374,
  _v15,
  CssSeq([_v342, _v645]),
]);
const _v647 = CssSeq([CssKeyword('to'), CssKeyword('right')]);
const _v648 = CssFunction('linear-gradient', [
  _v647,
  _v15,
  CssSeq([_v342, _v505]),
]);
const _v649 = CssFunction('linear-gradient', [
  _v520,
  _v15,
  CssSeq([_v342, _v505]),
]);
const _v650 = CssOp('-', CssNum(100, '%'), _v505);
const _v651 = CssSeq([_v342, CssCalc(_v650)]);
const _v652 = CssFunction('linear-gradient', [
  _v647,
  _v15,
  CssSeq([_v342, _v505]),
  _v651,
  _v15,
]);
const _v653 = CssVar('--available-height');
const _v654 = CssVar('--mobile-nav-server-popover-floor', CssNum(0, 'px'));
const _v655 = CssFunction('max', [CssNum(60, 'dvh'), CssCalc(_v654)]);
const _v656 = CssCalc(CssOp('-', _v653, _v74));
const _v657 = CssFunction('min', [CssCalc(_v655), _v656]);
const _v658 = CssOp('+', _v405, CssNum(8, 'px'));
const _v659 = CssVar('--tw-leading', CssNum(24, 'px'));
const _v660 = CssVar('--tw-leading', CssNum(22, 'px'));
const _v661 = CssVar('--available-width');
const _v662 = CssOp('-', CssNum(100, '%'), CssNum(24, 'px'));
const _v663 = CssOp('-', CssNum(100, 'vw'), CssNum(48, 'px'));
const _v664 = CssFunction('min', [CssNum(100, '%'), CssNum(24, 'em')]);
const _v665 = CssVar('--available-width', CssNum(320, 'px'));
const _v666 = CssFunction('min', [CssNum(320, 'px'), CssCalc(_v665)]);
const _v667 = CssOp('-', CssNum(100, 'vw'), CssNum(32, 'px'));
const _v668 = CssVar('--available-width', CssCalc(_v667));
const _v669 = CssFunction('min', [CssNum(384, 'px'), CssCalc(_v668)]);
const _v670 = CssFunction('min', [CssNum(360, 'px'), CssNum(100, '%')]);
const _v671 = CssVar('--anchor-width');
const _v672 = CssFunction('max', [CssCalc(_v671), CssNum(384, 'px')]);
const _v673 = CssFunction('min', [CssCalc(_v661), CssCalc(_v672)]);
const _v674 = CssOp('-', _v98, CssNum(9, 'px'));
const _v675 = CssOp('-', _v399, CssNum(6, 'px'));
const _v676 = CssOp('-', _v399, CssNum(5, 'px'));
const _v677 = CssOp('-', _v560, CssNum(20, 'px'));
const _v678 = CssOp('/', _v677, CssNum(2));
const _v679 = CssVar('--dialog-top', CssNum(8, 'vh'));
const _v680 = CssOp('-', CssNum(100, 'dvh'), _v679);
const _v681 = CssOp('-', _v680, CssNum(16, 'px'));
const _v682 = CssOp('-', _v222, CssNum(1, 'px'));
const _v683 = CssOp('-', _v682, _v206);
const _v684 = CssOp('/', _v683, CssNum(2));
const _v685 = CssOp('-', _v682, CssNum(34, 'px'));
const _v686 = CssOp('/', _v685, CssNum(2));
const _v687 = CssVar('--page-inset', null, 'pageInset');
const _v688 = CssOp('-', _v203, CssNum(18, 'px'));
const _v689 = CssOp('/', _v688, CssNum(2));
const _v690 = CssOp('*', _v689, CssNum(-1));
const _v691 = CssOp('-', _v687, _v150);
const _v692 = CssOp('-', CssNum(16, 'px'), _v150);
const _v693 = CssOp('-', _v206, _v157);
const _v694 = CssOp('-', CssNum(34, 'px'), _v157);
const _v695 = CssOp('-', _v206, CssNum(18, 'px'));
const _v696 = CssOp('/', _v695, CssNum(2));
const _v697 = CssOp('*', CssNum(-2), _v283);
const _v698 = CssOp('-', _v697, CssNum(1.5, 'px'));
const _v699 = CssOp('-', _v110, _v203);
const _v700 = CssOp('/', _v699, CssNum(2));
const _v701 = CssOp('+', _v687, CssNum(24, 'px'));
const _v702 = CssOp('-', CssNum(8, 'px'), _v151);
const _v703 = CssFunction('max', [CssNum(0, 'px'), CssCalc(_v702)]);
const _v704 = CssOp('+', _v703, CssNum(10, 'px'));
const _v705 = CssOp('-', _v204, CssNum(3, 'px'));
const _v706 = CssOp('/', _v705, CssNum(2));
const _v707 = CssOp('-', _v222, _v206);
const _v708 = CssOp('/', _v707, CssNum(2));
const _v709 = CssOp('-', _v222, CssNum(34, 'px'));
const _v710 = CssOp('/', _v709, CssNum(2));
const _v711 = CssVar('--bar-button-radius', null, 'barButtonRadius');
const _v712 = CssOp('+', _v206, CssNum(8, 'px'));
const _v713 = CssOp('*', CssNum(-1), _v712);
const _v714 = CssOp('/', _v713, CssNum(2));
const _v715 = CssVar('--card-title-line-height', null, 'cardTitleLineHeight');
const _v716 = CssVar('--field-line-height', null, 'fieldLineHeight');
const _v717 = CssOp('*', _v716, CssNum(3));
const _v718 = CssOp('+', _v717, CssNum(24, 'px'));
const _v719 = CssOp('+', _v559, CssNum(16, 'px'));
const _v720 = CssOp('+', _v719, CssNum(8, 'px'));
const _v721 = CssVar('--fit-search-min');
const _v722 = CssFunction('max', [CssCalc(_v671), CssNum(220, 'px')]);
const _v723 = CssOp('-', CssNum(27, 'px'), CssNum(1, 'lh'));
const _v724 = CssOp('/', _v723, CssNum(2));
const _v725 = CssOp('-', _v559, CssNum(1, 'lh'));
const _v726 = CssOp('/', _v725, CssNum(2));
const _v727 = CssOp('-', CssNum(34, 'px'), CssNum(1, 'lh'));
const _v728 = CssOp('/', _v727, CssNum(2));
const _v729 = CssKeyword('narrow-dialog-enter');
const _v730 = CssSeq([_v729, CssNum(280, 'ms'), _v160]);
const _v731 = CssVar('--fill-cell-hover', null, 'fillCellHover');
const _v732 = CssColor(0x13FAFAF7, 'oklch(0.9843 0.004 106.47 / 0.075)');
const _v733 = CssVar('--fill-cell-press', null, 'fillCellPress');
const _v734 = CssColor(0x1FFAFAF7, 'oklch(0.9843 0.004 106.47 / 0.12)');
const _v735 = CssSeq([CssNum(1), CssSlash(), CssNum(2)]);
const _v736 = CssVar('--mi-toolbar-opacity', CssNum(0));
const _v737 = CssVar('--drawer-overlay-min-opacity', CssNum(0));
const _v738 = CssOp('-', CssNum(1), _v172);
const _v739 = CssFunction('max', [CssCalc(_v737), CssCalc(_v738)]);
const _v740 = CssVar('--drawer-transform-origin');
const _v741 = CssVar('--transform-origin');
const _v742 = CssVar('--sidebar-content-bottom', CssNum(8, 'px'));
const _v743 = CssOp('+', CssNum(12, 'px'), _v405);
const _v744 = CssOp('+', CssNum(1, 'px'), CssNum(0.0275, 'em'));
const _v745 = CssOp('+', CssNum(16, 'px'), _v125);
const _v746 = CssOp('+', CssNum(8, 'px'), _v125);
const _v747 = CssOp('+', _v405, CssNum(16, 'px'));
const _v748 = CssOp('-', _v398, _v399);
const _v749 = CssOp('-', _v572, _v748);
const _v750 = CssOp('-', _v749, CssNum(8, 'px'));
const _v751 = CssOp('-', _v749, CssNum(9, 'px'));
const _v752 = CssFunction('min', [CssCalc(_v125), CssNum(34, 'px')]);
const _v753 = CssFunction('max', [CssNum(8, 'px'), CssCalc(_v752)]);
const _v754 = CssOp('-', _v572, _v399);
const _v755 = CssOp('+', _v531, CssNum(16, 'px'));
const _v756 = CssOp('+', _v531, CssNum(20, 'px'));
const _v757 = CssKeyword('safe-area-inset-left');
const _v758 = CssFunction('env', [_v757, CssNum(0, 'px')]);
const _v759 = CssOp('+', CssNum(16, 'px'), _v758);
const _v760 = CssOp('+', _v758, CssNum(16, 'px'));
const _v761 = CssOp('+', _v150, CssVar('--cell-pad-x'));
const _v762 = CssOp('-', CssNum(44, 'px'), CssNum(100, '%'));
const _v763 = CssOp('*', _v762, CssNum(-1));
const _v764 = CssOp('-', CssNum(44, 'px'), CssNum(1, 'lh'));
const _v765 = CssOp('/', _v764, CssNum(2));
const _v766 = CssVar('--ig-control-pr', CssNum(12, 'px'));
const _v767 = CssVar('--ta-pr', CssNum(12, 'px'));
const _v768 = CssOp('+', _v71, CssNum(16, 'px'));
const _v769 = CssOp('+', _v703, CssNum(12, 'px'));
const _v770 = CssOp('+', _v321, CssVar('--cell-pad-x'));
const _v771 = CssVar('--rail-width', null, 'railWidth');
const _v772 = CssOp('-', _v771, CssNum(1, 'px'));
const _v773 = CssVar('--rail-item', null, 'railItem');
const _v774 = CssOp('-', _v772, _v773);
const _v775 = CssOp('/', _v774, CssNum(2));
const _v776 = CssOp('+', _v243, _v775);
const _v777 = CssVar('--page-top', null, 'pageTop');
const _v778 = CssOp('-', CssNum(1, 'px'), CssNum(0.0275, 'em'));
const _v779 = CssOp('+', _v74, CssNum(12, 'px'));
const _v780 = CssOp('-', _v748, CssNum(6, 'px'));
const _v781 = CssOp('-', _v748, CssNum(5, 'px'));
const _v782 = CssOp('-', _v754, CssNum(8, 'px'));
const _v783 = CssOp('-', _v754, CssNum(9, 'px'));
const _v784 = CssOp('-', _v572, _v398);
const _v785 = CssOp('+', _v784, _v399);
const _v786 = CssOp('-', _v98, CssNum(1.5, 'px'));
const _v787 = CssVar('--section-gap', null, 'sectionGap');
const _v788 = CssOp('/', _v787, CssNum(2));
const _v789 = CssOp('*', CssNum(2), _v542);
const _v790 = CssOp('/', _v789, CssNum(2));
const _v791 = CssOp('+', CssNum(1, 'px'), _v18);
const _v792 = CssSeq([
  _v17,
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssCalc(_v791),
  _v21,
]);
const _v793 = CssVar('--ta-scroll-pb', CssNum(0));
const _v794 = CssVar('--selection', null, 'selection');
const _v795 = CssVar('--tw-shadow-color', _v395);
const _v796 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v795,
]);
const _v797 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v443,
]);
const _v798 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v418,
]);
const _v799 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v420,
]);
const _v800 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v422,
]);
const _v801 = CssVar('--tw-shadow-color', _v146);
const _v802 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v801,
]);
const _v803 = CssVar('--elevation-sticker', null, 'elevationSticker');
const _v804 = CssVar('--tw-shadow-color', _v147);
const _v805 = CssSeq([
  CssNum(0),
  CssNum(0),
  CssNum(0),
  CssNum(1.5, 'px'),
  _v804,
]);
const _v806 = CssSeq([CssNum(4, 'px'), CssNum(4, 'px'), CssNum(0), _v342]);
const _v807 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(2, 'px'), _v420]);
const _v808 = CssSeq([CssNum(0), CssNum(0), CssNum(0), CssNum(2, 'px'), _v422]);
const _v809 = CssOp('-', _v6, CssNum(4, 'px'));
const _v810 = CssOp('-', _v65, CssNum(8, 'px'));
const _v811 = CssFunction('anchor', [CssKeyword('inside')]);
const _v812 = CssFunction('anchor', [CssKeyword('center')]);
const _v813 = CssOp('-', _v812, CssNum(22, 'px'));
const _v814 = CssFunction('min', [CssCalc(_v811), CssCalc(_v813)]);
const _v815 = CssKeyword('tabular-nums');
const _v816 = CssVar('--tw-ordinal', CssSeq([]));
const _v817 = CssVar('--tw-slashed-zero', CssSeq([]));
const _v818 = CssVar('--tw-numeric-figure', CssSeq([]));
const _v819 = CssVar('--tw-numeric-spacing', CssSeq([]));
const _v820 = CssVar('--tw-numeric-fraction', CssSeq([]));
const _v821 = CssSeq([_v816, _v817, _v818, _v819, _v820]);
const _v822 = CssVar('--ig-addon-fg-default', _v44);
const _v823 = CssVar('--ig-addon-fg', _v822);
const _v824 = CssVar('--ig-addon-fg-default', _v39);
const _v825 = CssVar('--ig-addon-fg', _v824);
const _v826 = CssVar('--ig-text-fg-default', _v44);
const _v827 = CssVar('--ig-text-fg', _v826);
const _v828 = CssVar('--ig-text-fg-default', _v39);
const _v829 = CssVar('--ig-text-fg', _v828);
const _v830 = CssVar('--list-row-ink');
const _v831 = CssVar('--list-row-ink-2');
const _v832 = CssVar('--list-row-ink-3');
const _v833 = CssVar('--list-row-risk-ink');
const _v834 = CssVar('--list-row-risk-ink', _v832);
const _v835 = CssVar('--mi-ct-color', _v15);
const _v836 = CssVar('--tw-leading', CssNum(1));
const _v837 = CssVar('--attention-700', null, 'attention700');
const _v838 = CssVar('--attention-strong', null, 'attentionStrong');
const _v839 = CssColor(0xFFFFACC7, 'oklch(0.84 0.11 0)');
const _v840 = CssVar('--brand-strong', null, 'brandStrong');
const _v841 = CssVar('--tw-leading', CssNum(20, 'px'));
const _v842 = CssVar('--tw-font-weight', CssNum(500));
const _v843 = CssVar('--card-title-font-size', null, 'cardTitleFontSize');
const _v844 = CssVar('--tw-leading', _v715);
const _v845 = CssVar('--field-font-size', null, 'fieldFontSize');
const _v846 = CssVar('--tw-leading', _v716);
const _v847 = CssVar('--foreground-inverse', null, 'foregroundInverse');
const _v848 = CssSeq([_v0, CssNum(30, '%')]);
const _v849 = CssFunction('color-mix', [_v272, _v848, _v15]);
const _v850 = CssSeq([_v0, CssNum(45, '%')]);
const _v851 = CssFunction('color-mix', [_v272, _v850, _v15]);
const _v852 = CssVar('--tw-font-weight', CssNum(700));
const _v853 = CssVar('--info-strong', null, 'infoStrong');
const _v854 = CssColor(0xFF6CCDEA, 'oklch(0.8 0.1 220)');
const _v855 = CssVar('--tw-leading', CssNum(13, 'px'));
const _v856 = CssVar('--tw-font-weight', CssNum(600));
const _v857 = CssNum(1.4285714285714286);
const _v858 = CssVar('--tw-leading', _v857);
const _v859 = CssVar('--success-strong', null, 'successStrong');
const _v860 = CssColor(0xFFB7E18C, 'oklch(0.86 0.12 130)');
const _v861 = CssVar(
  '--task-status-closed-strong',
  null,
  'taskStatusClosedStrong',
);
const _v862 = CssVar('--task-status-done-strong', null, 'taskStatusDoneStrong');
const _v863 = CssColor(0xFF6ED892, 'oklch(0.8 0.14 153)');
const _v864 = CssVar(
  '--task-status-in-progress-strong',
  null,
  'taskStatusInProgressStrong',
);
const _v865 = CssVar(
  '--task-status-in-review-strong',
  null,
  'taskStatusInReviewStrong',
);
const _v866 = CssVar('--palette-lavender-300', null, 'paletteLavender300');
const _v867 = CssVar('--task-status-todo-strong', null, 'taskStatusTodoStrong');
const _v868 = CssVar('--tw-leading', CssNum(28, 'px'));
const _v869 = CssVar('--tw-tracking', CssNum(-0.01, 'em'));
const _v870 = CssSeq([CssKeyword('in'), CssKeyword('srgb')]);
const _v871 = CssSeq([_v517, CssNum(75, '%')]);
const _v872 = CssFunction('color-mix', [_v870, _v871, _v15]);
const _v873 = CssColor(
  0xBFFFFFFF,
  'color-mix(in oklab, oklch(1 0 0) 75%, transparent)',
  Color.from(alpha: 0.750980, red: 0.998418, green: 0.999726, blue: 0.999706),
);
const _v874 = CssVar('--message-reference-em');
const _v875 = CssOp('-', CssNum(1, 'em'), _v874);
const _v876 = CssOp('/', _v875, CssNum(4));
const _v877 = CssVar('--toast-viewport-top', CssNum(0, 'px'));
const _v878 = CssFunction('env', [_v73]);
const _v879 = CssFunction('max', [CssCalc(_v877), CssCalc(_v878)]);
const _v880 = CssOp('+', _v879, CssNum(16, 'px'));
const _v881 = CssKeyword('manipulation');
const _v882 = CssVar('--drawer-swipe-x', CssNum(0, 'px'));
const _v883 = CssVar('--drawer-stack-x', CssNum(0, 'px'));
const _v884 = CssOp('+', _v882, _v883);
const _v885 = CssVar('--drawer-swipe-y', CssNum(0, 'px'));
const _v886 = CssVar('--drawer-stack-y', CssNum(0, 'px'));
const _v887 = CssOp('+', _v885, _v886);
const _v888 = CssFunction('translate3d', [
  CssCalc(_v884),
  CssCalc(_v887),
  CssNum(0),
]);
const _v889 = CssFunction('scale', [_v185]);
const _v890 = CssOp('*', CssVar('--toast-index'), CssVar('--toast-peek'));
const _v891 = CssVar('--toast-peek-dir');
const _v892 = CssOp('*', _v890, _v891);
const _v893 = CssOp('+', _v235, _v892);
const _v894 = CssFunction('translatey', [CssCalc(_v893)]);
const _v895 = CssFunction('scale', [CssVar('--toast-scale')]);
const _v896 = CssSeq([_v482, _v894, _v895]);
const _v897 = CssFunction('translatez', [CssNum(0)]);
const _v898 = CssVar('--tw-rotate-x', CssSeq([]));
const _v899 = CssVar('--tw-rotate-y', CssSeq([]));
const _v900 = CssVar('--tw-rotate-z', CssSeq([]));
const _v901 = CssVar('--tw-skew-x', CssSeq([]));
const _v902 = CssVar('--tw-skew-y', CssSeq([]));
const _v903 = CssSeq([_v897, _v898, _v899, _v900, _v901, _v902]);
const _v904 = CssList([_v7, _v8, CssKeyword('color')]);
const _v905 = CssList([_v7, _v8, CssKeyword('transform')]);
const _v906 = CssList([
  _v7,
  CssKeyword('color'),
  _v323,
  _v8,
  CssKeyword('transform'),
]);
const _v907 = CssList([_v7, CssKeyword('color'), _v8, CssKeyword('transform')]);
const _v908 = CssList([
  _v7,
  CssKeyword('color'),
  CssKeyword('opacity'),
  _v8,
  CssKeyword('transform'),
]);
const _v909 = CssList([_v7, CssKeyword('color')]);
const _v910 = CssList([_v323, CssKeyword('opacity'), _v8]);
const _v911 = CssList([CssKeyword('color'), _v7, CssKeyword('opacity')]);
const _v912 = CssList([CssKeyword('filter'), CssKeyword('opacity')]);
const _v913 = CssList([CssKeyword('opacity'), CssKeyword('transform')]);
const _v914 = CssList([
  CssKeyword('transform'),
  CssKeyword('height'),
  CssKeyword('opacity'),
  CssKeyword('filter'),
]);
const _v915 = CssList([
  CssKeyword('transform'),
  CssKeyword('opacity'),
  CssKeyword('height'),
]);
const _v916 = CssList([
  CssKeyword('translate'),
  CssKeyword('opacity'),
  CssKeyword('scale'),
]);
const _v917 = CssList([CssKeyword('width'), _v7]);
const _v918 = CssVar('--pull-distance');
const _v919 = CssOp('-', _v918, CssNum(100, '%'));
const _v920 = CssVar('--inbox-item-skeleton-body');
const _v921 = CssVar('--inbox-item-skeleton-context');
const _v922 = CssVar('--inbox-item-skeleton-title');
const _v923 = CssVar('--list-row-skeleton-description');
const _v924 = CssVar('--list-row-skeleton-title');
const _v925 = CssOp('-', CssNum(100, '%'), CssNum(32, 'px'));
const _v926 = CssOp('-', _v671, CssNum(16, 'px'));
const _v927 = CssFunction('clamp', [
  CssNum(144, 'px'),
  CssNum(20, 'vw'),
  CssNum(224, 'px'),
]);
const _v928 = CssFunction('clamp', [
  CssNum(360, 'px'),
  CssNum(32, 'vw'),
  CssNum(520, 'px'),
]);
const _v929 = CssFunction('min', [CssNum(384, 'px'), CssCalc(_v667)]);
const _v930 = CssOp('-', CssNum(100, 'vw'), CssNum(16, 'px'));
const _v931 = CssVar('--available-width', CssCalc(_v930));
const _v932 = CssFunction('min', [CssCalc(_v931), CssNum(480, 'px')]);
const _v933 = CssList([CssKeyword('transform'), CssKeyword('opacity')]);
const _v934 = CssOp('-', CssNum(80), CssVar('--toast-index'));
