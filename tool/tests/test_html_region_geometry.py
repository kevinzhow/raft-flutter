"""Execute the production host-only JS in a bounded DOM fixture, not a renderer claim."""
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'apps/raft_flutter/lib/platform/attachment_html_geometry_script.dart'

FIXTURE = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const body = JSON.parse(require('node:fs').readFileSync(0, 'utf8'));
function fixture(command, nodes = [], elements = [], options = {}) {
  const window = {innerWidth:1000,innerHeight:800,scrollX:0,scrollY:100,
    scrollTo(x,y){this.scrollX=x;this.scrollY=y;},scrollBy(x,y){this.scrollX+=x;this.scrollY+=y;}};
  Object.assign(window, options);
  const root = {scrollWidth:1200,scrollHeight:3000,clientWidth:1000,clientHeight:800};
  const document = {documentElement:root, body:root,
    createTreeWalker(root, kind){let n=0;const list=kind===4?nodes:elements;return {nextNode:()=>list[n++]||null};},
    createRange(){let node;return {selectNodeContents(n){node=n;},getClientRects(){return node.rects;},detach(){}};},
    elementFromPoint(){return nodes.length ? {textContent:nodes[0].textContent,parentElement:root}:null;},
    caretPositionFromPoint(){return nodes.length?{offsetNode:nodes[0],offset:0}:null;},
  };
  const context = {window,document,NodeFilter:{SHOW_ELEMENT:1}};
  const source = '(() => {const command = '+JSON.stringify(command)+';\n'+body+'\n})()';
  if (options.stringify) context.JSON = {stringify:options.stringify};
  const raw = vm.runInNewContext(source, context, {timeout:500});
  const result = raw ? JSON.parse(raw) : null;
  assert.equal(context.appBridge,undefined);assert.equal(window.appBridge,undefined);
  assert.equal(context.command,undefined);assert.equal(window.acBridge,undefined);
  return {result,window};
}
const g = (operation,extra={})=>({operation,request:7,host:[500,400],...extra});
const node=(text,x,y,w,h)=>({nodeType:3,textContent:text,rects:[{left:x,top:y,right:x+w,bottom:y+h,width:w,height:h}]});
const first=node(' First\n sentence. Next.',20,30,100,20),second=node('Second section!',20,60,100,20);
let out=fixture(g('capture',{rect:[10,15,100,60]}),[second,first]).result;
assert.equal(out.request,7);assert.deepEqual(out.region,{x:20,y:130,w:200,h:120,viewportWidth:1000,documentWidth:1200,documentHeight:3000,quote:'First ... Second section'});
out=fixture(g('capture',{rect:[-100,-100,200,300]}),[]).result;assert.equal(out.region.x,0);assert.equal(out.region.y,0);
out=fixture(g('capture',{rect:[10,15,0,0]}),[first]).result;
assert.equal(out.region.w,0);assert.equal(out.region.h,0);assert.equal(out.region.quote,'First');
out=fixture(g('capture',{rect:[10,15,100,60]}),[]).result;assert.equal(out.region.quote,undefined);
out=fixture(g('capture',{rect:[0,0,500,400]}),[node('a'.repeat(500),0,0,500,300)]).result;assert.equal(out.region.quote.length,200);
out=fixture(g('capture',{rect:[10,15,100,60]}),[first],[],{visualViewport:{width:500,height:400,offsetLeft:5,offsetTop:10}}).result;
assert.equal(out.region.x,15);assert.equal(out.region.y,125);assert.equal(out.region.w,100);assert.equal(out.geometry.scrollY,110);
function element(text,y,h=30){return {textContent:text,contains(){return false;},getBoundingClientRect(){return {left:20,top:y-100,width:220,height:h};}};}
const early=element('Read this quote',200),late=element('Read this quote',1800);
const ancestor=element('Whole Read this quote document',0,2200);ancestor.contains=(el)=>el===early||el===late;
const stored={x:20,y:1770,w:220,h:70,viewportWidth:1000,documentWidth:1200,documentHeight:3000,quote:'Read this quote'};
let jump=fixture(g('jump',{region:stored}),[],[ancestor,early,late]);
assert.equal(jump.result.region.y,1800);assert.equal(jump.window.scrollY,1800-800/3);
jump=fixture(g('jump',{region:{...stored,quote:'Deleted passage'}}),[],[ancestor,early,late]);assert.equal(jump.result.region.y,1770);
assert.equal(jump.result.geometry.scrollY,1770-800/3);
out=fixture(g('scroll',{delta:[20,40]})).result;assert.equal(out.geometry.scrollX,40);assert.equal(out.geometry.scrollY,180);
const malformed=fixture(g('capture',{rect:null})).result;assert.equal(malformed,null);
assert.equal(fixture(g('measure'),[],[],{stringify:()=> 'x'.repeat(20000)}).result,null);
assert.equal(fixture(g('measure'),[],[],{stringify:()=> ({hostile:true})}).result,null);
console.log('12 production JS geometry/quote/locate/coordinate/no-bridge assertions passed');
'''

class HtmlRegionGeometryTest(unittest.TestCase):
    def test_production_geometry_script(self):
        source = SOURCE.read_text()
        body = source.split("const _geometry = r'''", 1)[1].split("''';", 1)[0]
        completed = subprocess.run(['node', '-e', FIXTURE], input=json.dumps(body), text=True,
                                   capture_output=True, timeout=10)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertNotIn('postMessage', body)
        self.assertNotIn('addEventListener', body)
        self.assertNotIn('appBridge', body)

if __name__ == '__main__':
    unittest.main()
