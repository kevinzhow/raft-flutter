#!/usr/bin/env node
// Independent published-CSS model. Never renumbers or writes the tv registry.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import postcss from 'postcss';
import {createCompiler,splitOutput} from './lib/tailwind.mjs';
import {parseStepsCss,resolveSteps,stepsConfigurations,stepsEnvironments,STEPS_SLOTS,bindStepsThemeGlobals} from './lib/steps-css.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const arg=(name,fallback)=>{const i=process.argv.indexOf('--'+name);return i<0?fallback:process.argv[i+1];};
const source=arg('source',process.env.RAFT_UI_SOURCE);if(!source)throw Error('Set pinned RAFT_UI_SOURCE or --source');
const cssPath=join(source,'dist/components/steps/steps.css'),css=readFileSync(cssPath,'utf8');
const pkg=JSON.parse(readFileSync(join(source,'package.json'),'utf8'));
const tokens=new Set();for(const f of ['foundation.css','fonts.css'])postcss.parse(readFileSync(join(source,'dist',f),'utf8')).walkDecls(d=>{if(d.prop.startsWith('--'))tokens.add(d.prop);});
const sha=s=>createHash('sha256').update(s).digest('hex');
const compiler=await createCompiler(source,{webTheme:!process.argv.includes('--raft-ui-only')});
const compiled=compiler.build([]);
const {themeVars}=splitOutput(compiled);
const globals=bindStepsThemeGlobals(css,themeVars,tokens);
const rules=parseStepsCss(css),configs=stepsConfigurations(),envs=stepsEnvironments(rules).environments,hits=new Set();
// These are dimensions of the published CSS DOM model, not tv variants.
// Keep their options mechanically tied to the actual enumerated configs, and
// share one default source with the typed resolve declaration below.
const defaults={orientation:'horizontal',status:'process',last:false,clickable:false,disabled:false};
const axes=Object.keys(configs[0]).map(name=>({name,values:[...new Set(configs.map(c=>String(c[name])))],defaultValue:String(defaults[name])}));
if(axes.length!==Object.keys(defaults).length||axes.some(a=>!a.values.includes(a.defaultValue)))throw Error('Steps CSS axis/default mismatch');
const utility=[],lists=[],pool=[],indices=new Map(),fixtures=[],stylePool=[],styleIndices=new Map(),utilityIndices=new Map();
const internStyle=v=>{const key=JSON.stringify(v);if(!styleIndices.has(key)){styleIndices.set(key,stylePool.length);stylePool.push(v);}return styleIndices.get(key);};
const intern=v=>{const key=JSON.stringify(v);if(!indices.has(key)){indices.set(key,pool.length);pool.push(v);}return indices.get(key);};
for(const [ci,c]of configs.entries()){
 const bySlot=Object.fromEntries(STEPS_SLOTS.map(s=>[s,[]]));
 for(const env of envs){
  const styles=resolveSteps(rules,c,env,n=>tokens.has(n),hits,globals);
  for(const slot of STEPS_SLOTS)bySlot[slot].push({atoms:env.atoms,decls:Object.entries(styles[slot]).map(([p,v])=>[p,intern(v)])});
  fixtures.push({config:c,width:env.width??null,flags:[...env.flags],expected:Object.fromEntries(Object.entries(styles).map(([slot,style])=>[slot,internStyle(style)]))});
 }
 const list=[];
 for(const slot of STEPS_SLOTS){
  const layers=bySlot[slot],base=layers[0].decls,baseMap=new Map(base);
  const groups=new Map();
  for(const layer of layers){
   const delta=layer.decls.filter(([p,n])=>baseMap.get(p)!==n);
   for(const [p]of base)if(!layer.decls.some(([q])=>p===q))throw Error('Unbound property removal '+slot+'.'+p);
   if(!delta.length)continue;
   const key=JSON.stringify(delta);if(!groups.has(key))groups.set(key,{decls:delta,cases:[]});groups.get(key).cases.push(layer.atoms);
  }
  const normalized=[{atoms:[],decls:base}];
  for(const group of groups.values()){
   const common=group.cases[0].filter(a=>group.cases.every(c=>c.includes(a)));
   const covered=layers.filter(l=>common.every(a=>l.atoms.includes(a)));
   if(covered.every(l=>group.cases.some(c=>JSON.stringify(c)===JSON.stringify(l.atoms))))normalized.push({atoms:common,decls:group.decls});
   else for(const atoms of group.cases)normalized.push({atoms,decls:group.decls});
  }
  const key=JSON.stringify(normalized);if(!utilityIndices.has(key)){utilityIndices.set(key,utility.length);utility.push({name:`steps-css-${ci}-${slot}`,layers:normalized});}
  list.push(utilityIndices.get(key));
 }
 lists.push(list);
}
const unmatched=rules.filter(r=>!hits.has(r.order));if(unmatched.length)throw Error('Unmatched published CSS rules: '+unmatched.map(r=>r.selector+'@'+r.line).join(', '));
const quote=s=>"'"+String(s).replace(/\\/g,'\\\\').replace(/'/g,"\\'").replace(/\$/g,'\\$').replace(/\n/g,'\\n')+"'";
const num=n=>Number.isInteger(n)?String(n):String(Number(n.toPrecision(15)));
const v=n=>{
 switch(n.t){
  case'num':return `CssNum(${num(n.v)}, ${quote(n.u)})`;
  case'kw':return `CssKeyword(${quote(n.v)})`;
  case'str':return `CssString(${quote(n.v)})`;
  case'color':return `CssColor(0x${n.argb.toString(16).padStart(8,'0')})`;
  case'var':return `CssVar(${quote(n.name)}, ${n.fb?v(n.fb):'null'}${n.token?', '+quote(n.token):''})`;
  case'fn':return `CssFunction(${quote(n.name)}, [${n.args.map(v)}])`;
  case'calc':return `CssCalc(${v(n.e)})`;
  case'op':return `CssOp(${quote(n.op)}, ${v(n.a)}, ${v(n.b)})`;
  case'seq':return `CssSeq([${n.items.map(v)}])`;
  case'list':return `CssList([${n.items.map(v)}])`;
  case'slash':return 'CssSlash()';
  case'unset':throw Error('Unexpected unset in generated Steps CSS');
  default:throw Error('Unknown CssValue AST kind '+n.t);
 }
};
const axisDart=axes.map(a=>`    RaftRecipeAxis(${quote(a.name)}, [${a.values.map(quote)}], ${quote(a.defaultValue)}, false),`).join('\n');
let dart=`// GENERATED from published raft-ui ${pkg.version} Steps CSS; do not edit.\n// Source SHA256 ${sha(css)}\n// Regenerate with tool/recipes/run. No tv recipe or global utility indices.\n// ignore_for_file: type=lint\nimport 'recipe_runtime.dart';\n\nenum RaftStepsCssStatus { wait, process, finish, error }\nenum RaftStepsCssOrientation { horizontal, vertical }\n\nabstract final class RaftStepsCssRecipe {\n  // Registry metadata describes CSS model axes, not a tailwind-variants recipe.\n  static const String recipeName = 'stepsCss';\n  static const List<RaftRecipeAxis> axes = [\n${axisDart}\n  ];\n  static const sourceSha256 = '${sha(css)}';\n  static const slotNames = ${JSON.stringify(STEPS_SLOTS).replaceAll('"',"'")};\n  static Map<String, RaftSlotStyle> resolve({\n    RaftStepsCssStatus status = RaftStepsCssStatus.${defaults.status},\n    RaftStepsCssOrientation orientation = RaftStepsCssOrientation.${defaults.orientation},\n    bool last = ${defaults.last}, bool clickable = ${defaults.clickable}, bool disabled = ${defaults.disabled},\n    RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens,\n  }) {\n    final index = ((((orientation.index * 4 + status.index) * 2 + (last ? 1 : 0)) * 2 + (clickable ? 1 : 0)) * 2 + (disabled ? 1 : 0));\n    final list = _lists[index];\n    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: _engine.resolveSlot([list[i]], states, tokens)};\n  }\n}\n\n`;
for(const [i,value]of pool.entries())dart+=`const _v${i} = ${v(value)};\n`;
dart+='\nconst _utilities = <RaftUtility>[\n';
for(const [i,u]of utility.entries()){
 dart+=`  RaftUtility(${quote(u.name)}, ${i}, RaftUtilityStatus.resolved, [\n`;
 for(const l of u.layers)dart+=`    RaftLayer('self', [${l.atoms.map(quote)}], 0, [${l.decls.map(([p,n])=>`RaftDecl(${quote(p)}, _v${n})`).join(',')}]),\n`;
 dart+='  ]),\n';
}
dart+='];\nconst _engine = RaftRecipeEngine(_utilities, {});\nconst _lists = <List<int>>[\n'+lists.map(l=>'  ['+l.join(',')+'],').join('\n')+'\n];\n';
const out=resolve(root,arg('out','build/steps-css'));mkdirSync(out,{recursive:true});
writeFileSync(join(out,'steps_css.g.dart'),dart);
writeFileSync(join(out,'steps_css_cases.g.json'),JSON.stringify({source:{version:pkg.version,sha256:sha(css)},stylePool,cases:fixtures})+'\n');
writeFileSync(join(out,'coverage.json'),JSON.stringify({source:{version:pkg.version,sha256:sha(css)},ruleCount:rules.length,matchedRules:hits.size,selectors:rules.map(({selector,line,atoms})=>({selector,line,atoms})),configurations:configs.length,environments:envs.length,slots:STEPS_SLOTS,fixtures:fixtures.length,values:pool.length,utilities:utility.length,stylePool:stylePool.length},null,2)+'\n');
if(process.argv.includes('--write')){
 const dest=join(root,'packages/raft_theme/lib/recipes/steps_css.g.dart');writeFileSync(dest,dart);
 writeFileSync(join(root,'packages/raft_ui/lib/src/recipes/steps_css.g.dart'),"// Published-CSS Steps; Raft look only. Frozen paint stays in steps_frozen.dart.\nexport 'package:raft_theme/recipes/steps_css.g.dart';\n");
 writeFileSync(join(root,'packages/raft_theme/test/recipes/steps_css_cases.g.json'),readFileSync(join(out,'steps_css_cases.g.json')));
}
console.log(`steps-css: ${rules.length} rules, ${hits.size} matched, ${configs.length} configurations, ${envs.length} environmental partitions; source ${sha(css)}`);
