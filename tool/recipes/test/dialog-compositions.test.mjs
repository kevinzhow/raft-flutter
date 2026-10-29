import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import ts from 'typescript';
import { extractDialogCompositions } from '../lib/dialog-compositions.mjs';

const source = 'function DialogCard({ maxWidthClass = "max-w-md" }: Props) {\n' +
  'return <DialogSurface className={`w-full p-5 ${maxWidthClass}`}>' +
  '<div className="mb-4 flex items-start gap-2"><h2 className="font-sans text-headline">Title</h2>' +
  '<CloseButton size="icon-sm" className="-my-1.5 -mr-1.5"><X size={18} /></CloseButton></div>' +
  '{children}</DialogSurface>;}';
function fixture(t, text = source) {
  const root = mkdtempSync(join(tmpdir(), 'dialog-compositions-'));
  const ui = join(root, 'src/components/ui');
  mkdirSync(ui, {recursive: true});
  writeFileSync(join(ui, 'DialogCard.tsx'), text);
  t.after(() => rmSync(root, {recursive: true, force: true}));
  return root;
}
test('DialogCard reads product classes, width default and glyph from JSX', (t) => {
  const [r] = extractDialogCompositions(fixture(t), ts);
  assert.deepEqual(r.options.slots.root, ['w-full', 'p-5']);
  assert.deepEqual(r.options.slots.header, ['mb-4', 'flex', 'items-start', 'gap-2']);
  assert.deepEqual(r.options.slots.defaultWidth, ['max-w-md']);
  assert.equal(r.options.slots.glyph, 'size-[18px]');
  assert.match(r.region, new RegExp('sha256:' + createHash('sha256').update(source).digest('hex') + '$'));
});
test('upstream padding and glyph edits change the generated recipe and hash', (t) => {
  const [before] = extractDialogCompositions(fixture(t), ts);
  const [after] = extractDialogCompositions(fixture(t, source.replace('p-5', 'p-6').replace('{18}', '{20}')), ts);
  assert.deepEqual(after.options.slots.root, ['w-full', 'p-6']);
  assert.equal(after.options.slots.glyph, 'size-[20px]');
  assert.notEqual(after.region, before.region);
});
test('unknown class expression fails rather than dropping product padding', (t) => {
  assert.throws(() => extractDialogCompositions(fixture(t, source.replace('"mb-4 flex items-start gap-2"', '{unknownClassHelper()}')), ts), /className must/);
});
test('new dynamic root composition fails explicitly', (t) => {
  assert.throws(() => extractDialogCompositions(fixture(t, source.replace('${maxWidthClass}', '${maxWidthClass} ${newVariant}')), ts), /unsupported dynamic/);
});
test('an ambiguous header or malformed JSX is rejected', (t) => {
  assert.throws(() => extractDialogCompositions(fixture(t, source.replace('{children}', '<div className="other" />')), ts), /expected one div/);
  assert.throws(() => extractDialogCompositions(fixture(t, source.replace('</DialogSurface>', '')), ts), /Cannot parse/);
});
test('a changed close Button axis requires its binding to be reviewed', (t) => {
  assert.throws(() => extractDialogCompositions(fixture(t, source.replace('icon-sm', 'icon-lg')), ts), /source close size changed/);
});
