import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import postcss from 'postcss';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {parseStepsCss,resolveSteps,stepsConfigurations,stepsEnvironments,bindStepsThemeGlobals} from '../lib/steps-css.mjs';
import {createCompiler,splitOutput} from '../lib/tailwind.mjs';
const source=process.env.RAFT_UI_SOURCE;
assert.ok(source,'Use the pinned package explicitly');
const css=readFileSync(join(source,'dist/components/steps/steps.css'),'utf8');
const rules=parseStepsCss(css),tokens=new Set();
for(const f of ['foundation.css','fonts.css'])postcss.parse(readFileSync(join(source,'dist',f),'utf8')).walkDecls(d=>{if(d.prop.startsWith('--'))tokens.add(d.prop);});
const compiler=await createCompiler(source),theme=splitOutput(compiler.build([])).themeVars;
const globals=bindStepsThemeGlobals(css,theme,tokens);
const config={orientation:'horizontal',status:'process',last:false,clickable:false,disabled:false};
const env=(width,flags=[])=>({width,flags:new Set(flags)});
const run=(text,c=config,e=env(640))=>resolveSteps(parseStepsCss(text),c,e,n=>tokens.has(n),new Set(),globals);

test('all published selectors are reached by the complete library capability matrix',()=>{
 const hits=new Set();for(const c of stepsConfigurations())for(const e of stepsEnvironments(rules).environments)resolveSteps(rules,c,e,n=>tokens.has(n),hits,globals);
 assert.equal(hits.size,rules.length);assert.equal(rules.length,50);
});
for(const [name,extra]of [['class','.r-step__future { color: red }'],['pseudo','.r-step:nth-child(2) { color: red }'],['combinator','.r-step + .r-step { color: red }'],['property','.r-step { filter: blur(1px) }'],['media','@media (resolution > 1dppx) { .r-step { color: red } }']]){
 test('unknown '+name+' rejects instead of dropping rules',()=>assert.throws(()=>parseStepsCss(css+'\n'+extra),/unsupported|unknown/));
}
test('empty unsupported selector still rejects',()=>assert.throws(()=>parseStepsCss(css+'\n.r-step__future {}'),/unknown/));
test('malformed CSS rejects',()=>assert.throws(()=>parseStepsCss(css+'\n.r-step {')));
test('unresolved local and cyclic variable reject',()=>{
 assert.throws(()=>run(css.replace('--r-steps-gap: 8px;','')),/unresolved/);
 assert.throws(()=>run(css.replace('--r-steps-gap: 8px;','--r-steps-gap: var(--r-steps-gap);')),/unresolved|cyclic/);
});
test('source geometry mutation flows into downstream slots mechanically',()=>{
 const original=run(css),changed=run(css.replace('--r-steps-gap: 8px;','--r-steps-gap: 9px;'));
 assert.equal(original.title['margin-left'].v,8);assert.equal(changed.title['margin-left'].v,9);
});
test('viewport boundary and mobile gap use parsed media/custom-property rules',()=>{
 assert.equal(run(css,config,env(639)).content['padding-right'].v,6);
 assert.equal(run(css,config,env(640)).title['margin-left'].v,8);
 assert.equal(run(css,config,env(641)).title['margin-left'].v,8);
 assert.equal(run(css,config,env(639)).description['margin-top'].v,2);
});
test('hover capability and disabled status respect published cascade',()=>{
 const c={...config,status:'wait',clickable:true};
 const hovered=run(css,c,env(640,['hover']));const touch=run(css,c,env(640,['hover','hover-none']));
 assert.notDeepEqual(hovered.title.color,touch.title.color);
 assert.equal(run(css,{...c,disabled:true},env(640,['hover'])).title.color.token,'foregroundDisabled');
});
test('marker line height and last connector remain source-owned',()=>{
 assert.equal(run(css).indicator['line-height'].v,1);
 assert.equal(run(css,{...config,last:true}).connector.display.v,'none');
});

test('DOM fixture binds the actual published Steps/Step markup and disabled class rule', async()=>{
 const req=createRequire(join(source,'package.json'));const React=req('react');
 const webReq=createRequire(join(source,'../../..','package.json'));const {renderToStaticMarkup}=webReq('react-dom/server');
 const {Steps,Step}=await import(pathToFileURL(join(source,'dist/index.mjs')).href);
 const html=renderToStaticMarkup(React.createElement(Steps,{current:2,onUpdateCurrent:()=>{}},
  React.createElement(Step,{title:'Connect'}),React.createElement(Step,{title:'Channels'}),React.createElement(Step,{title:'Health',disabled:true})));
 assert.match(html,/r-step--finish r-step--clickable/);
 assert.match(html,/r-step--process r-step--clickable/);
 assert.match(html,/r-step--wait r-step--disabled/);
 assert.doesNotMatch(html,/r-step--wait r-step--clickable r-step--disabled/);
 assert.match(html,/class="r-step__title r-step__button" disabled/);
 assert.match(html,/r-step__main/);assert.match(html,/r-step__indicator/);assert.match(html,/r-step__content/);
});
