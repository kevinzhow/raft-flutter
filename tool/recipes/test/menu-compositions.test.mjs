import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import ts from 'typescript';
import { extractMenuCompositions } from '../lib/menu-compositions.mjs';

const selection = `function SelectionPopoverOptionRow({checked, disabled, italic}: Props) {
  const labelClassName = italic ? "muted-label" : "normal-label";
  const rowTone = disabled ? "disabled-from-source" : \`enabled-\${checked ? "strong" : "normal"}\`;
  return <button className={\`row-from-source \${rowTone}\`}>
    <span className="group-from-source">
      <span className="leading-from-source">{leading}</span>
      <span className={labelClassName}>{label}</span>
    </span>
    {checked && <Check size={16} className="indicator-from-source" />}
  </button>;
}`;
function fixture(t, text = selection) {
  const root = mkdtempSync(join(tmpdir(), 'menu-compositions-'));
  const ui = join(root, 'src/components/ui');
  mkdirSync(ui, { recursive: true });
  writeFileSync(join(ui, 'MenuItem.tsx'), 'const MENU_ITEM_CLASS = ["action-from-source", "second"].join(" ");');
  writeFileSync(join(ui, 'SelectionPopover.tsx'), text + `
    const SELECTION_POPOVER_SURFACE = "surface-from-source";
    function SelectionPopoverSections() {
      return <>
        <div className="header-from-source">
          <span className="title-from-source">Title</span>
          <button className="clear-from-source">Clear</button>
        </div>
        <label className="search-from-source"><Search size={14} className="search-icon-from-source" /><input className="input-from-source" /></label>
        <div className="list-from-source"><div className="empty-from-source">Empty</div></div>
      </>;
    }
  `);
  const layout = join(root, 'src/components/layout');
  mkdirSync(layout, { recursive: true });
  writeFileSync(join(layout, 'LeftRail.tsx'), `
    export function HelpMenu() {
      return <PopoverContent className="help-surface-from-source">
        <div className="help-header-from-source"><SectionEyebrow>Help</SectionEyebrow></div>
        <MenuItem>Documentation</MenuItem>
      </PopoverContent>;
    }
  `);
  writeFileSync(join(layout, 'SidebarSortMenu.tsx'), `
    export default function SidebarSortMenu() {
      return <SelectionPopover showHeader={false} className="sort-caller-from-source" />;
    }
  `);
  t.after(() => rmSync(root, { recursive: true, force: true }));
  return root;
}
test('menu generation reads all boolean compositions from TSX, with source hashes', (t) => {
  const [panel, action, rows] = extractMenuCompositions(fixture(t), ts);
  assert.equal(panel.options.slots.list, 'list-from-source');
  assert.equal(panel.options.slots.root, 'surface-from-source');
  assert.equal(panel.options.slots.searchIcon, 'search-icon-from-source size-[14px]');
  assert.equal(action.options.slots.root, 'action-from-source second');
  assert.match(action.region, /MenuItem\.tsx sha256:[a-f0-9]{64}$/);
  assert.equal(rows.options.compoundVariants.length, 8);
  assert.equal(rows.options.slots.indicator, 'indicator-from-source size-[16px]');
  for (const entry of rows.options.compoundVariants) {
    assert.equal(entry.class.root, `row-from-source ${entry.disabled ? 'disabled-from-source' : `enabled-${entry.checked ? 'strong' : 'normal'}`}`);
    assert.equal(entry.class.label, entry.italic ? 'muted-label' : 'normal-label');
    assert.equal(entry.class.leading, 'leading-from-source');
  }
});
test('upstream class edits are read again and change the provenance', (t) => {
  const before = extractMenuCompositions(fixture(t), ts)[2];
  const after = extractMenuCompositions(fixture(t, selection.replace('row-from-source', 'new-upstream-row')), ts)[2];
  assert.notEqual(after.region, before.region);
  assert.match(after.options.compoundVariants[0].class.root, /^new-upstream-row /);
});
test('an unsupported new upstream class helper stops extraction', (t) => {
  const root = fixture(t, selection.replace('"muted-label"', 'unrecognizedHelper()'));
  assert.throws(() => extractMenuCompositions(root, ts), /Unsupported menu class expression/);
});
test('an upstream DOM structural change stops extraction', (t) => {
  const root = fixture(t, selection.replace('<span className="leading-from-source">{leading}</span>', ''));
  assert.throws(() => extractMenuCompositions(root, ts), /leading\/label structure changed/);
});
test('Help composition reads the real product surface and header, with provenance', (t) => {
  const help = extractMenuCompositions(fixture(t), ts).find((recipe) => recipe.name === 'webHelpMenu');
  assert.equal(help.options.slots.root, 'help-surface-from-source');
  assert.equal(help.options.slots.header, 'help-header-from-source');
  assert.match(help.region, /layout\/LeftRail\.tsx sha256:[a-f0-9]{64}$/);
});
test('a missing Help header stops generation instead of retaining stale styles', (t) => {
  const root = fixture(t);
  writeFileSync(join(root, 'src/components/layout/LeftRail.tsx'),
    'export function HelpMenu() { return <PopoverContent className="surface"><MenuItem>Doc</MenuItem></PopoverContent>; }');
  assert.throws(() => extractMenuCompositions(root, ts), /Help header structure changed/);
});

test('Sidebar sort composes its actual source surface and caller variant', (t) => {
  const sort = extractMenuCompositions(fixture(t), ts).find((recipe) => recipe.name === 'webSidebarSortMenu');
  assert.ok(sort, 'Sidebar sort must not borrow a numerically similar menu recipe');
  assert.equal(sort.options.slots.root, 'surface-from-source sort-caller-from-source');
  assert.match(sort.region, /layout\/SidebarSortMenu\.tsx sha256:[a-f0-9]{64}$/);
});
test('an unsupported Sidebar sort caller expression stops extraction', (t) => {
  const root = fixture(t);
  writeFileSync(join(root, 'src/components/layout/SidebarSortMenu.tsx'),
    'function SidebarSortMenu() { return <SelectionPopover className={unknownSortStyle()} />; }');
  assert.throws(() => extractMenuCompositions(root, ts), /Unsupported menu class expression/);
});
