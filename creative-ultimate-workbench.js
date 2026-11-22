(()=>{
const $=id=>document.getElementById(id);
const page=()=>pages?.[activePage];
const assets=()=>page()?.assets||(page()&&(page().assets=[]))||[];
let selectedId=null,mode="move";
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
function say(s){const el=$("zuwStatus");if(el)el.textContent=s}
function selected(){return assets().find(a=>a.id===selectedId)}
function fill(a){
 if(!a)return;
 $("zuwName").value=a.label||a.name||"";
 $("zuwX").value=Math.round(Number(a.x)||0);
 $("zuwY").value=Math.round(Number(a.y)||0);
 $("zuwScale").value=a.type==="glb"?(Number(a.scale)||100):(Number(a.size)||130);
 $("zuwRotation").value=Math.round(Number(a.rotation)||0);
 $("zuwScaleLabel").textContent=a.type==="glb"?"Model scale (%)":"Object size (px)";
 $("zuwApply").disabled=false;$("zuwDelete").disabled=false;
 $("zuwSelected").textContent=(a.type==="glb"?"GLB MODEL":"CSS 3D OBJECT")+" · "+(a.label||a.name||a.id);
}
function render(){if(typeof window.render==="function")window.render()}
function choose(id){selectedId=id;const a=selected();if(a)fill(a)}
function apply(){
 const a=selected();if(!a)return;
 a.label=$("zuwName").value.trim()||a.name;
 a.x=Number($("zuwX").value);a.y=Number($("zuwY").value);a.rotation=Number($("zuwRotation").value);
 if(a.type==="glb")a.scale=Number($("zuwScale").value);else a.size=Number($("zuwScale").value);
 render();fill(a);say("3D transform applied and stored in the active page. Save the project to keep it.");
}
function reorderHtml(html){
 try{
  const doc=new DOMParser().parseFromString(html,"text/html");
  const nodes=[...doc.body.querySelectorAll(":scope > [data-zv-section-key]")];
  if(nodes.length>1){
   const order=nodes.map(n=>n.dataset.zvSectionKey);
   page().sectionOrder=order;
   say("Section order saved in this page. Save the project to keep it.");
  }
 }catch{}
}
function decorate(html,p){
 const order=JSON.stringify(Array.isArray(p?.sectionOrder)?p.sectionOrder:[]);
 const script='<script>(function(){const body=document.body;const pick=()=>[...body.querySelectorAll(":scope > header,:scope > section,:scope > .tiles")];let nodes=pick();nodes.forEach((n,i)=>{if(!n.dataset.zvSectionKey)n.dataset.zvSectionKey="section-"+i});const wanted='+order+';if(wanted.length){const map=new Map(nodes.map(n=>[n.dataset.zvSectionKey,n]));wanted.forEach(k=>{const n=map.get(k);if(n)body.appendChild(n)})}window.addEventListener("message",e=>{if(e.data?.type==="z3d-transform-mode")window.__zvTransformMode=e.data.mode==="rotate"?"rotate":"move"})})();<\/script>';
 html=html.replace("</body>",script+"</body>");
 html=html.replace('if(e.shiftKey||e.altKey){','if(e.shiftKey||e.altKey||window.__zvTransformMode==="rotate"){');
 const old='canvas.addEventListener("pointermove",e=>{if(!drag||!active)return;active.rotation.y+=(e.clientX-drag.x)*.012;active.rotation.x+=(e.clientY-drag.y)*.008;drag={x:e.clientX,y:e.clientY}});canvas.addEventListener("pointerup",()=>{if(drag&&active)parent.postMessage({type:"z3d-rotate",id:active.userData.assetId,rotation:active.rotation.y*180/Math.PI},"*");drag=null});';
 const newer='let transformMode="rotate";window.addEventListener("message",e=>{if(e.data?.type==="z3d-transform-mode")transformMode=e.data.mode==="move"?"move":"rotate"});canvas.addEventListener("pointermove",e=>{if(!drag||!active)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;if(transformMode==="move"){active.position.x+=dx*.012;active.position.y-=dy*.012}else{active.rotation.y+=dx*.012;active.rotation.x+=dy*.008}drag={x:e.clientX,y:e.clientY}});canvas.addEventListener("pointerup",()=>{if(drag&&active)parent.postMessage({type:"z3d-transform",id:active.userData.assetId,x:active.position.x*18+50,y:42-active.position.y*24,rotation:active.rotation.y*180/Math.PI},"*");drag=null});';
 return html.replace(old,newer);
}
function init(){
 if(!$("z3dGlbTools")||$("zuwPanel"))return;
 const panel=document.createElement("section");panel.id="zuwPanel";panel.style.cssText="margin-top:14px;padding:14px;border:1px solid #a78bfa66;border-radius:12px;background:linear-gradient(145deg,#1c1930,#0d0b17)";
 panel.innerHTML='<div class="eyebrow">ULTIMATE EDITION · ADVANCED 3D TRANSFORM</div><h2 style="margin:6px 0 4px">Object control desk</h2><p class="small muted">Select a CSS 3D object or uploaded GLB model in the preview. Move by dragging; choose Rotate mode and drag to rotate. Fine-tune exact values below.</p><div class="row"><strong id="zuwSelected" class="small">No 3D object selected</strong><span style="flex:1"></span><select id="zuwMode" aria-label="Transform mode"><option value="move">Move mode</option><option value="rotate">Rotate mode</option></select></div><div class="field"><label>Object / model label</label><input id="zuwName" maxlength="80" placeholder="Select a 3D object first"></div><div class="row"><label class="small">Horizontal <input id="zuwX" type="range" min="0" max="90" value="50"></label><label class="small">Vertical <input id="zuwY" type="range" min="0" max="90" value="20"></label></div><div class="row"><label class="small" id="zuwScaleLabel">Object size (px) <input id="zuwScale" type="range" min="25" max="250" value="130"></label><label class="small">Rotation <input id="zuwRotation" type="range" min="-180" max="180" value="0"></label></div><div class="row"><button class="btn" id="zuwApply" disabled>Apply transform</button><button class="btn secondary" id="zuwDelete" disabled>Remove object</button></div><div id="zuwStatus" class="status" style="margin-top:9px">Choose an object in the preview to begin.</div><div class="note">Section order is now recorded in page project data. Save the project after rearranging sections or changing 3D objects.</div>';
 $("z3dPanel").appendChild(panel);
 $("zuwApply").onclick=apply;
 $("zuwDelete").onclick=()=>{if(!selectedId)return;const p=page();p.assets=assets().filter(a=>a.id!==selectedId);selectedId=null;$("zuwApply").disabled=true;$("zuwDelete").disabled=true;$("zuwSelected").textContent="No 3D object selected";render();say("Object removed from the active page.")};
 $("zuwMode").addEventListener("change",()=>{mode=$("zuwMode").value;$("preview").contentWindow?.postMessage({type:"z3d-transform-mode",mode},"*");say(mode==="move"?"Move mode: drag objects to reposition.":"Rotate mode: drag objects to rotate.");});
 $("preview").addEventListener("load",()=>{$("preview").contentWindow?.postMessage({type:"z3d-transform-mode",mode},"*")});
 ["zuwX","zuwY","zuwScale","zuwRotation"].forEach(id=>$(id).addEventListener("input",()=>{const a=selected();if(!a)return;if(id==="zuwX")a.x=Number($(id).value);if(id==="zuwY")a.y=Number($(id).value);if(id==="zuwScale"){if(a.type==="glb")a.scale=Number($(id).value);else a.size=Number($(id).value)}if(id==="zuwRotation")a.rotation=Number($(id).value)}));
 $("zuwName").addEventListener("change",()=>{const a=selected();if(a)a.label=$("zuwName").value.trim()||a.name});
 const lib=window.Zenvio3DAssets;
 if(lib?.inject&&!lib.__ultimateWorkbench){const original=lib.inject;lib.inject=function(html,list){return decorate(original(html,list),page())};lib.__ultimateWorkbench=true}
 window.addEventListener("message",e=>{
  if(e.source!==$("preview").contentWindow)return;
  const d=e.data||{};
  if(d.type==="z3d-select")choose(d.id);
  if(d.type==="z3d-move"){const a=assets().find(x=>x.id===d.id);if(a){a.x=Number(d.x);a.y=Number(d.y);if(selectedId===a.id)fill(a)}}
  if(d.type==="z3d-rotate"){const a=assets().find(x=>x.id===d.id);if(a){a.rotation=Math.round(d.rotation);if(selectedId===a.id)fill(a)}}
  if(d.type==="z3d-transform"){const a=assets().find(x=>x.id===d.id);if(a){a.x=Math.max(0,Math.min(90,Number(d.x)||0));a.y=Math.max(0,Math.min(90,Number(d.y)||0));a.rotation=Math.round(d.rotation);if(selectedId===a.id)fill(a);say("Mouse transform saved to the selected 3D model. Use Apply transform to update the preview.")}}
  if(d.type==="z3d-sections-reordered"&&d.html)reorderHtml(d.html);
 });
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",init);else init();
})();