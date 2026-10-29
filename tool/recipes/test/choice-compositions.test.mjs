import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdtempSync,mkdirSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {tmpdir} from 'node:os';
import {extractChoiceCompositions} from '../lib/choice-compositions.mjs';
const web=process.env.RAFT_WEB_CSS ? dirname(dirname(process.env.RAFT_WEB_CSS)) : '/mnt/data/tmp/cindy/raft-source-23/packages/web';
const ts=createRequire(import.meta.url)('typescript');
const reset='src/components/agent/ResetAgentDialog.tsx';
const doc='src/components/message/attachmentPreviewSurfaces.tsx';
const original=new Map([reset,doc].map(f=>[f,readFileSync(join(web,f),'utf8')]));
function fixture(file, before, after) {
  const root=mkdtempSync(join(tmpdir(),'raft-choice-composition-'));
  for(const [f,text] of original){
    mkdirSync(dirname(join(root,f)),{recursive:true});
    if(f===file)assert.equal(text.split(before).length,2,`mutation anchor must be unique: ${before}`);
    writeFileSync(join(root,f),f===file?text.replace(before,after):text);
  }
  return root;
}

test('fixed product sources produce two deterministic recipes and six Reset slots',()=>{
  const a=extractChoiceCompositions(web,ts);assert.deepEqual(a,extractChoiceCompositions(web,ts));
  assert.deepEqual(a.map(r=>r.name),['webAgentResetOptions','webXlsxTabsLayout']);
  assert.deepEqual(Object.keys(a[0].options.slots),['root','row','indicator','content','title','description']);
});
test('class changes come from source instead of a copied Dart list',()=>{
  const root=fixture(reset,'className="gap-0"','className="gap-6"');
  assert.equal(extractChoiceCompositions(root,ts)[0].options.slots.root,'gap-6');
});
test('new class expressions fail instead of being silently discarded',()=>{
  const root=fixture(reset,'className="gap-0"','className={"gap-0"}');
  assert.throws(()=>extractChoiceCompositions(root,ts),/must be literal/);
});
const targets=[
  [reset,'Reset root','className="gap-0"'],
  [reset,'Reset row','className="flex min-h-11 items-start gap-3 py-3"'],
  [reset,'Reset indicator','className="shrink-0"'],
  [reset,'Reset content','className="flex min-w-0 flex-col gap-0.5"'],
  [reset,'Reset title','className="text-subhead font-semibold text-foreground"'],
  [reset,'Reset description','className="text-footnote font-normal text-foreground-muted"'],
  [doc,'XLSX root','className="mb-3 max-w-full overflow-x-auto pb-1"'],
  [doc,'XLSX list','<TabsList'],
  [doc,'XLSX tab','<TabsTab\n'],
  [doc,'XLSX label','<TabsLabel'],
];
for(const [file,name,anchor] of targets){
  for(const [kind,attrs] of [['inline style','style={{padding:1}}'],['spread','{...unboundPaintProps}'],['unknown attribute','hidden']]){
    test(`${name} rejects ${kind}`,()=>{
      const root=fixture(file,anchor,`${anchor} ${attrs} `);
      assert.throws(()=>extractChoiceCompositions(root,ts),/unbound attribute or spread/);
    });
  }
}
test('a new rendered node under a title requires an explicit binding',()=>{
  const root=fixture(reset,'{formatMessage({ id: opt.labelId })}','<em>{formatMessage({ id: opt.labelId })}</em>');
  assert.throws(()=>extractChoiceCompositions(root,ts),/descendant structure changed/);
});
