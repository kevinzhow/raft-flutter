// Product-composition inputs for the shared extract/resolve/generate pipeline.
// Drawing attributes and descendant structures fail closed on upstream drift.
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';

export function extractChoiceCompositions(web, ts) {
  function source(path) {
    const text=readFileSync(join(web,path),'utf8');
    const ast=ts.createSourceFile(path,text,ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
    if(ast.parseDiagnostics.length) throw Error(`Choice composition parse failed: ${path}`);
    return {path,text,ast};
  }
  function nodes(root,predicate) {
    const result=[];function visit(n){if(predicate(n))result.push(n);ts.forEachChild(n,visit);}visit(root);return result;
  }
  function only(xs,label) {if(xs.length!==1)throw Error(`Choice composition expected one ${label}, got ${xs.length}`);return xs[0];}
  const opening=n=>ts.isJsxElement(n)?n.openingElement:n;
  const tag=n=>opening(n).tagName.getText();
  const elements=(root,name)=>nodes(root,n=>(ts.isJsxElement(n)||ts.isJsxSelfClosingElement(n))&&tag(n)===name);
  const children=n=>n.children.filter(c=>ts.isJsxElement(c)||ts.isJsxSelfClosingElement(c));
  function knownAttributes(n, allowed, label) {
    for (const a of opening(n).attributes.properties) {
      if (!ts.isJsxAttribute(a) || !allowed.includes(a.name.getText())) {
        throw Error(`Choice ${label} has an unbound attribute or spread; style and new drawing inputs require an explicit binding`);
      }
    }
  }
  function exactDescendants(root, expected, label) {
    const allowed = new Set(expected);
    const actual = nodes(root, n => ts.isJsxElement(n) || ts.isJsxSelfClosingElement(n));
    if (actual.length !== allowed.size || actual.some(n => !allowed.has(n))) {
      throw Error(`Choice ${label} descendant structure changed; bind new rendered nodes explicitly`);
    }
  }
  function classes(n,label) {
    const a=opening(n).attributes.properties.find(a=>ts.isJsxAttribute(a)&&a.name.getText()==='className');
    if(!a||!a.initializer||!ts.isStringLiteral(a.initializer))throw Error(`Choice ${label} className must be literal; review new expressions explicitly`);
    return a.initializer.text;
  }
  function recipe(src,name,component,slots) {
    return {name,line:1,region:`Web ${src.path} sha256:${createHash('sha256').update(src.text).digest('hex')}`,
      exported:[],directUsers:[],exportedComponents:[component],options:{slots},nonLiteral:[],resolvedIdentifiers:[]};
  }
  const reset=source('src/components/agent/ResetAgentDialog.tsx');
  const group=only(elements(reset.ast,'RadioGroup'),'Reset RadioGroup');
  const row=only(elements(group,'label'),'Reset option label');
  const c=children(row);
  if(c.length!==2||tag(c[0])!=='RadioGroupItem'||tag(c[1])!=='span')throw Error('Reset option indicator/content structure changed');
  const texts=children(c[1]);
  if(texts.length!==2||texts.some(n=>tag(n)!=='span'))throw Error('Reset option title/description structure changed');
  knownAttributes(group, ['value', 'onValueChange', 'aria-label', 'className'], 'Reset group');
  knownAttributes(row, ['key', 'className'], 'Reset row');
  knownAttributes(c[0], ['value', 'className', 'data-testid'], 'Reset indicator');
  for (const [node, label] of [[c[1], 'Reset content'], [texts[0], 'Reset title'], [texts[1], 'Reset description']]) {
    knownAttributes(node, ['className'], label);
  }
  exactDescendants(group, [group, row, c[0], c[1], ...texts], 'Reset group');
  const result=[recipe(reset,'webAgentResetOptions' ,'ResetAgentDialogRadioOptions',{
    root:classes(group,'Reset group'),row:classes(row,'Reset row'),
    indicator:classes(c[0],'Reset indicator'),content:classes(c[1],'Reset content'),
    title:classes(texts[0],'Reset title'),description:classes(texts[1],'Reset description'),
  })];
  const attachment=source('src/components/message/attachmentPreviewSurfaces.tsx');
  const pane=only(nodes(attachment.ast,n=>ts.isFunctionDeclaration(n)&&n.name?.text==='XlsxPreviewPane'),'XlsxPreviewPane');
  const tabs=only(elements(pane,'Tabs'),'XLSX Tabs');
  knownAttributes(tabs, ['value', 'onValueChange', 'className'], 'XLSX Tabs');
  const list = only(elements(tabs, 'TabsList'), 'XLSX TabsList');
  const tab = only(elements(tabs, 'TabsTab'), 'XLSX TabsTab');
  const label = only(elements(tabs, 'TabsLabel'), 'XLSX TabsLabel');
  knownAttributes(list, ['aria-label'], 'XLSX TabsList');
  knownAttributes(tab, ['key', 'value'], 'XLSX TabsTab');
  knownAttributes(label, [], 'XLSX TabsLabel');
  exactDescendants(tabs, [tabs, list, tab, label], 'XLSX Tabs');
  result.push(recipe(attachment,'webXlsxTabsLayout' ,'XlsxPreviewPaneTabs',{root:classes(tabs,'XLSX Tabs')}));
  return result;
}
