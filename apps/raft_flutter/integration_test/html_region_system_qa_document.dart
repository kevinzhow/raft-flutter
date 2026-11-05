// Synthetic document for the real system renderer. No remote resources, account
// data, callable page bridge or host-driven input are part of this fixture.
const htmlRegionSystemQaCsp =
    "default-src 'none'; sandbox allow-scripts; script-src 'unsafe-inline'; "
    "style-src 'unsafe-inline'; img-src data: blob:; connect-src 'none'; "
    "object-src 'none'; base-uri 'none'; form-action 'none'; worker-src 'none'";

const htmlRegionSystemQaDocument = '''<!doctype html><meta charset="utf-8">
<title>System region comment QA</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f8fafc;color:#172554;font:20px sans-serif;padding:28px}
h1{font-size:25px;margin:0 0 18px}button{font-size:20px;padding:10px 18px;margin:0 12px 14px 0}
#blocks{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px}
section{background:#dbeafe;border:2px solid #1e40af;padding:22px;min-height:230px}
p{font-size:22px;line-height:1.7;margin:12px 0}h2{font-size:22px;margin:0}
.spacer{height:420px}.tail{min-height:700px;background:#ecfccb;padding:22px;margin-top:24px}
</style>
<h1>系统 WebKitGTK 区域评论</h1>
<button id="increment">Increment</button><strong id="count">0</strong>
<button id="reflow">Reflow blocks</button>
<div id="blocks">
<section id="alpha"><h2>甲区</h2><p id="quote">区域评论验收：这里是可以重新排版的中文内容。</p></section>
<section id="beta"><h2>乙区</h2><p>改变窗口宽度后，两个区块会从并排变为上下排列。</p></section>
</div><div class="spacer"></div>
<section class="tail" id="gamma"><h2>底部定位区</h2><p>滚动之后点击评论中的位置，应该回到所选区域并显示高亮。</p></section>
<script>
window.qaClicks=[];window.qaInputs=[];window.qaReflows=0;
for(const type of ['pointerdown','pointerup','click'])document.addEventListener(type,e=>{
 const id=e.target.closest('button')?.id;
 if(id){qaInputs.push({type,id,trusted:e.isTrusted});if(qaInputs.length>24)qaInputs.shift()}
},true);
increment.addEventListener('click',e=>{count.textContent=Number(count.textContent)+1;qaClicks.push({id:'increment',trusted:e.isTrusted})});
reflow.addEventListener('click',e=>{window.qaReflows++;blocks.style.gridTemplateColumns=window.qaReflows%2?'1fr':'';qaClicks.push({id:'reflow',trusted:e.isTrusted})});
</script>''';
