// Published Steps is authored CSS, not a tv recipe. This adapter projects its
// explicit DOM slots through the same parser/cascade used by recipe generation.
import postcss from 'postcss';
import {flatten, parseComplex, splitTopLevel, specificity, atRuleAtoms} from './selector.mjs';
import {parseValue, evaluate, hasFreeVar} from './css-value.mjs';
import {expand} from './expand.mjs';
import {cascade, atomMatches} from './cascade.mjs';

export const STEPS_SLOTS = ['root','item','main','indicator','icon','content','title','description','connector','status','buttonAfter'];
const CLASSES = new Set(['r-steps','r-steps--horizontal','r-steps--vertical','r-step',...['wait','process','finish','error','clickable','disabled'].map(s=>'r-step--'+s),...['main','indicator','content','title','description','connector','status','button'].map(s=>'r-step__'+s)]);
const PROPERTIES = new Set(('display line-height list-style margin padding min-width position gap align-items background border border-radius box-shadow box-sizing color flex font-family font-size font-variant-numeric font-weight height justify-content transition width padding-top white-space margin-top clip-path overflow appearance cursor text-align content inset outline border-color border-style border-width align-content grid-template-columns grid-column grid-row align-self margin-inline-start margin-inline border-top-width flex-wrap row-gap padding-inline-end overflow-wrap flex-direction padding-bottom border-inline-start-width bottom inset-inline-start top').split(' '));
const INHERITS = new Set(['color','font-family','font-size','font-weight','font-variant-numeric','line-height','text-align','white-space','list-style-type','list-style-position']);
const mediaKey = s => s.startsWith('width') || s==='hover-none' || s==='not:hover-none' || s==='motion-reduce';
function need(ok,message){if(!ok)throw Error('Steps CSS: '+message);}
function checkCompound(c,where){
  need(c.comb===null||c.comb===' '||c.comb==='>',`unsupported combinator in ${where}`);
  for(const s of c.simples){
    if(s.kind==='class')need(CLASSES.has(s.name),`unknown class ${s.name} in ${where}`);
    else if(s.kind==='type')need(s.name==='svg',`unsupported element ${s.name} in ${where}`);
    else if(s.kind==='pseudo-class'){
      need(['is','not','hover','focus-visible','disabled','last-child'].includes(s.name),`unsupported pseudo ${s.name} in ${where}`);
      if(s.name==='is'||s.name==='not')for(const alt of splitTopLevel(s.args)){
        const cs=parseComplex(alt);need(cs.length===1,`complex ${s.name} in ${where}`);checkCompound(cs[0],where);
      }
    }else if(s.kind==='pseudo-element')need(s.name==='after',`unsupported pseudo-element ${s.name} in ${where}`);
    else need(false,`unsupported selector token ${s.kind} in ${where}`);
  }
}
export function parseStepsCss(text){
  const ast=postcss.parse(text),rules=[];let order=0;
  function walk(node,parents=[],media=[]){
    if(node.type==='comment')return;
    if(node.type==='root'){for(const child of node.nodes)walk(child,parents,media);return;}
    if(node.type==='atrule'){
      need(node.name==='media',`unsupported @${node.name} at line${node.source.start.line}`);
      const ctx={unknown:[]},atoms=atRuleAtoms(node.name,node.params,ctx);
      if(node.params.replace(/[()]/g,'').trim()==='hover: hover')atoms.push('not:hover-none');
      need(!ctx.unknown.length&&atoms.every(mediaKey),`unsupported media ${node.params}`);
      for(const child of node.nodes??[])walk(child,parents,[...media,...atoms]);return;
    }
    need(node.type==='rule',`unexpected ${node.type}`);
    const selectors=parents.length?flatten(parents,node.selector):splitTopLevel(node.selector);
    // Validate even empty grouping selectors so upstream drift cannot hide in
    // an unvisited branch which happens to have no direct declarations.
    for(const selector of selectors)parseComplex(selector).forEach(c=>checkCompound(c,selector));
    const decls=[];
    for(const d of node.nodes??[])if(d.type==='decl'){
      need(!d.important,`unbound !important declaration at line${d.source.start.line}`);
      need(d.prop.startsWith('--r-step')||PROPERTIES.has(d.prop),`unsupported property ${d.prop} at line${d.source.start.line}`);
      decls.push({prop:d.prop,value:parseValue(d.value),important:false});
    }
    if(decls.length)for(const selector of selectors){
      const compounds=parseComplex(selector);compounds.forEach(c=>checkCompound(c,selector));
      rules.push({selector,compounds,atoms:media,spec:specificity(selector),decls,order:order++,line:node.source.start.line});
    }
    for(const child of node.nodes??[])if(child.type!=='decl'&&child.type!=='comment')walk(child,selectors,media);
  }
  walk(ast);
  need(rules.length>0,'empty stylesheet');return rules;
}
function compoundMatches(compound,node,env){
  for(const s of compound.simples){
    if(s.kind==='class'&&!node.classes.includes(s.name))return false;
    if(s.kind==='type'&&node.tag!==s.name)return false;
    if(s.kind==='pseudo-element'&&node.pseudo!==s.name)return false;
    if(s.kind==='pseudo-class'){
      if(s.name==='last-child'&&!node.last)return false;
      if(s.name==='disabled'&&!node.disabled)return false;
      if(s.name==='hover'&&!env.flags.has('hover'))return false;
      if(s.name==='focus-visible'&&!env.flags.has('focus-visible'))return false;
      if(s.name==='is'||s.name==='not'){
        const match=splitTopLevel(s.args).some(alt=>compoundMatches(parseComplex(alt)[0],node,env));
        if(s.name==='is'?!match:match)return false;
      }
    }
  }
  // An ordinary element rule is not a pseudo-element declaration. Inheritance
  // from its actual parent is handled separately below.
  return !!node.pseudo===compound.simples.some(s=>s.kind==='pseudo-element');
}
function matches(cs,node,env,index=cs.length-1){
  if(!node||!compoundMatches(cs[index],node,env))return false;
  if(index===0)return true;
  if(cs[index].comb==='>')return matches(cs,node.parent,env,index-1);
  for(let p=node.parent;p;p=p.parent)if(matches(cs,p,env,index-1))return true;
  return false;
}
function dom(config){
  const nodes={},list=[];
  const add=(slot,tag,classes,parent,last=true,extra={})=>{const n={slot,tag,classes,parent:parent?nodes[parent]:null,last,...extra};nodes[slot]=n;list.push(n);return n;};
  add('root','ol',['r-steps','r-steps--'+config.orientation]);
  add('item','li',['r-step','r-step--'+config.status,...(config.clickable&&!config.disabled?['r-step--clickable']:[]),...(config.disabled?['r-step--disabled']:[])],'root',config.last);
  add('main','div',['r-step__main'],'item',false);
  add('indicator','div',['r-step__indicator'],'main',false);
  add('icon','svg',[],'indicator');
  add('content','div',['r-step__content'],'main');
  add('title',config.clickable?'button':'div',['r-step__title',...(config.clickable?['r-step__button']:[])],'content',false,{disabled:config.disabled});
  add('description','div',['r-step__description'],'content',false);
  add('status','span',['r-step__status'],'title');
  add('buttonAfter','button',config.clickable?['r-step__title','r-step__button']:[],'title',true,{pseudo:'after',disabled:config.disabled});
  add('connector','div',['r-step__connector'],'item');
  return {nodes,list};
}
const canonical=(rules,env)=>rules.filter(r=>r.atoms.every(a=>atomMatches(a,env))).map(r=>({order:r.order,layers:[{target:'self',atoms:[],spec:r.spec,decls:r.decls}]}));
function inherited(parent){return new Map([...parent??[]].filter(([p])=>p.startsWith('--')||INHERITS.has(p)));}
function unset(value){if(value==null||value.t==='unset')return true;return false;}
function resolvedNode(rules,node,env,parent,isToken,hits){
  const matching=rules.filter(r=>matches(r.compounds,node,env)&&r.atoms.every(a=>atomMatches(a,env)));matching.forEach(r=>hits.add(r.order));
  const utilities=canonical(matching,env);
  const inheritedProps=inherited(parent);
  const prelude={order:-1,layers:[{target:'self',atoms:[],spec:[-1,-1,-1],decls:[...inheritedProps].map(([prop,value])=>({prop,value,important:false}))}]};
  const varUtilities=[prelude,...utilities].map(u=>({...u,layers:u.layers.map(l=>({...l,decls:l.decls.filter(d=>d.prop.startsWith('--'))}))}));
  const vars=cascade(varUtilities,varUtilities.map((_,i)=>i),env,{registered:new Map(),isToken}).get('self');
  for(const [name,value]of vars)need(!unset(value),`unresolved/cyclic local ${name} at ${node.slot}`);
  const ctx={lookupVar:n=>vars.get(n),registered:new Map(),isToken,partial:true};
  const normal=utilities.map(u=>({...u,layers:u.layers.map(l=>({...l,decls:l.decls.filter(d=>!d.prop.startsWith('--')).flatMap(d=>{
    const v=d.value.t==='kw'&&d.value.v==='inherit' ? inheritedProps.get(d.prop) : evaluate(d.value,ctx);need(!unset(v)&&!hasFreeVar(v),`unresolved value ${d.prop} at ${node.slot}`);
    return expand(d.prop,v).map(([prop,value])=>({prop,value,important:d.important}));
  })}))}));
  const all=[prelude,...normal],result=cascade(all,all.map((_,i)=>i),env,{registered:new Map(),isToken}).get('self');
  for(const [name,value]of vars)result.set(name,value);
  return result;
}
export function resolveSteps(rules,config,env,isToken=()=>false,hits=new Set(),globals=new Map()){
  const tree=dom(config),styles={};
  for(const n of tree.list)styles[n.slot]=resolvedNode(rules,n,env,n.parent?styles[n.parent.slot]:globals,isToken,hits);
  return Object.fromEntries(STEPS_SLOTS.map(slot=>[slot,Object.fromEntries([...styles[slot]].filter(([p])=>!p.startsWith('--')))]));
}
export function stepsConfigurations(){
  const out=[];
  for(const orientation of ['horizontal','vertical'])for(const status of ['wait','process','finish','error'])for(const last of [false,true])for(const clickable of [false,true])for(const disabled of [false,true])out.push({orientation,status,last,clickable,disabled});
  return out;
}
export function stepsEnvironments(rules){
  const atoms=[...new Set([...rules.flatMap(r=>r.atoms),...rules.filter(r=>r.selector.includes(':hover')).map(()=> 'hover'),...rules.filter(r=>r.selector.includes(':focus-visible')).map(()=> 'focus-visible')])].sort();
  const boundaries=[...new Set(atoms.map(a=>/width(?:<|>=)([\d.]+)/.exec(a)?.[1]).filter(Boolean).map(Number))];
  const widths=[undefined,0,...boundaries.flatMap(n=>[n-1,n,n+1])];
  const flags=['hover','hover-none','focus-visible','motion-reduce'];const unique=new Map();
  for(const width of widths)for(let bits=0;bits<1<<flags.length;bits++){
    const env={width,flags:new Set(flags.filter((_,i)=>bits&(1<<i)))};
    const key=atoms.map(a=>atomMatches(a,env)?a:'not:'+a).join('|');
    if(!unique.has(key))unique.set(key,{...env,atoms:key.split('|').filter(Boolean)});
  }
  return {atoms,environments:[...unique.values()]};
}

export function bindStepsThemeGlobals(css,themeVars,tokens){
  const declared=new Set();const ast=postcss.parse(css);ast.walkDecls(d=>declared.add(d.prop));
  const globals=new Map();
  function bind(value){
    for(const m of value.matchAll(/var\((--[\w-]+)/g)){
      const name=m[1];if(tokens.has(name)||declared.has(name)||globals.has(name))continue;
      need(themeVars.has(name),'unbound external variable '+name);
      globals.set(name,parseValue(themeVars.get(name)));bind(themeVars.get(name));
    }
  }
  ast.walkDecls(d=>bind(d.value));return globals;
}
