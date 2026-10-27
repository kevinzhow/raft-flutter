import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import ts from 'typescript';
import { extractMemberPickerCompositions } from '../lib/member-picker-compositions.mjs';

const row = '<button className={PICKER_ROW_CLASS}><CheckboxIndicator checked={selected} /><AvatarSlot /><span className="min-w-0 flex-1 truncate">Name</span></button>';
const product = `<Card className="max-h-48 overflow-y-auto p-1.5"><SectionEyebrow className={PICKER_GROUP_LABEL_CLASS}>Agents</SectionEyebrow>${row}<SectionEyebrow className={PICKER_GROUP_LABEL_CLASS}>Humans</SectionEyebrow>${row}<div className="px-2.5 py-2 text-callout text-foreground-hint">No matches</div></Card>`;
const constants = 'export const PICKER_GROUP_LABEL_CLASS="px-2.5 pt-2 pb-1"; export const PICKER_ROW_CLASS="flex min-h-9 gap-2.5 px-2.5";';
const eyebrow = 'const BASE_CLASS="text-footnote font-bold"; const TONE_CLASS={hint:"text-foreground-hint"} as const; function SectionEyebrow({tone="hint"}){}';
function fixture(t, change = {}) {
  const root=mkdtempSync(join(tmpdir(),'member-picker-compositions-'));
  for (const [path,text] of Object.entries({
    'channel/CreateChannelDialog.tsx':change.product??product,
    'channel/memberPickerClasses.ts':change.constants??constants,
    'ui/SectionEyebrow.tsx':change.eyebrow??eyebrow,
  })) { const file=join(root,'src/components',path);mkdirSync(join(file,'..'),{recursive:true});writeFileSync(file,text); }
  t.after(()=>rmSync(root,{recursive:true,force:true}));return root;
}
test('member picker reads the source Card, option constants and canonical eyebrow', t=>{
  const [r]=extractMemberPickerCompositions(fixture(t),ts);
  assert.equal(r.options.slots.root,'max-h-48 overflow-y-auto p-1.5');
  assert.equal(r.options.slots.group,'text-footnote font-bold text-foreground-hint px-2.5 pt-2 pb-1');
  assert.equal(r.options.slots.row,'flex min-h-9 gap-2.5 px-2.5');
  assert.equal(r.options.slots.empty,'px-2.5 py-2 text-callout text-foreground-hint');
  assert.match(r.region,/SectionEyebrow\.tsx sha256:[a-f0-9]{64}/);
});
test('an upstream source spacing change changes output instead of a copied Dart list', t=>{
  const [r]=extractMemberPickerCompositions(fixture(t,{constants:constants.replace('min-h-9','min-h-10'),product:product.replace('p-1.5','p-2')}),ts);
  assert.match(r.options.slots.row,/min-h-10/);assert.match(r.options.slots.root,/p-2$/);
});
test('unknown source expressions and checkbox structure changes fail closed', t=>{
  assert.throws(()=>extractMemberPickerCompositions(fixture(t,{constants:constants.replace('"flex min-h-9 gap-2.5 px-2.5"','unknownClasses()')}),ts),/must be a literal/);
  assert.throws(()=>extractMemberPickerCompositions(fixture(t,{product:product.replace('<CheckboxIndicator checked={selected} />','<Check />')}),ts),/checkbox\/avatar\/label structure/);
  assert.throws(()=>extractMemberPickerCompositions(fixture(t,{product:product.replace('className={PICKER_ROW_CLASS}','className={other}')}),ts),/must bind/);
  assert.throws(()=>extractMemberPickerCompositions(fixture(t,{product:product.replace('<CheckboxIndicator checked={selected} />','<CheckboxIndicator checked={selected} size={16} />')}),ts),/attribute needs/);
  assert.throws(()=>extractMemberPickerCompositions(fixture(t,{product:product.replace('<Card className=', '<Card style={{padding: 10}} className=')}),ts),/attribute needs/);
});
