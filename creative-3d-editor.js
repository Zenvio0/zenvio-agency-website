(()=>{
const $=id=>document.getElementById(id),lib=window.Zenvio3DAssets;
if(!lib)return;
let selected=null,selectedId=null;
const state=()=>pages[activePage].assets||(pages[activePage].assets=[]);
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
function refresh(){
 if(!pages.length){$("z3dStatus").textContent="Generate a website first.";return;}
 const assets=state();$("z3dPlaced").textContent=assets.length?assets.length+" asset(s) on this page: "+assets.map(a=>a.label||a.name).join(", "):"No 3D assets placed on this page yet.";
}
function draw(){
 const industry=$("z3dIndustry").value||"All industries",q=$("z3dSearch").value.toLowerCase();
 const list=lib.items.filter(a=>(industry==="All industries"||a.industry===industry)&&(!q||(a.name+" "+a.industry+" "+a.material).toLowerCase().includes(q)));
 $("z3dGrid").innerHTML=list.map(a=>'<button type="button" data-asset="'+a.id+'" style="text-align:left;border:1px solid #ffffff20;border-radius:10px;padding:9px;background:linear-gradient(145deg,#262238,#11101a);color:#fff;min-height:92px"><div style="font-size:29px;filter:drop-shadow(0 7px 5px #0008)">'+a.emoji+'</div><div style="font-size:11px;font-weight:700;margin-top:5px">'+esc(a.name)+'</div><div style="font-size:9px;color:#aaa">'+esc(a.material)+'</div></button>').join("")||'<div class="muted small">No matching assets.</div>';
 $("z3dGrid").querySelectorAll("[data-asset]").forEach(b=>b.addEventListener("click",()=>choose(b.dataset.asset)));
}
function choose(id){
 selected=lib.items.find(a=>a.id===id);if(!selected)return;
 $("z3dLabel").value=selected.name;$("z3dColor").value=selected.color;$("z3dSize").value=130;
 $("z3dStatus").textContent=selected.name+" selected · "+selected.industry+" · "+selected.material;
}
function values(){return {x:Number($("z3dX").value),y:Number($("z3dY").value),size:Math.max(48,Math.min(360,Number($("z3dSize").value)||130)),rotation:Number($("z3dRotation").value),color:$("z3dColor").value,label:$("z3dLabel").value.trim()||selected.name};}
function add(){
 if(!pages.length){$("z3dStatus").textContent="Generate a website first.";return;}
 if(!selected){$("z3dStatus").textContent="Choose an asset from the library first.";return;}
 const v=values(),asset={...selected,...v,id:"z3d-"+Date.now().toString(36)+"-"+Math.random().toString(36).slice(2,6)};
 state().push(asset);selectedId=asset.id;sync();$("z3dStatus").textContent=asset.name+" added to "+pages[activePage].title+". Drag it in the preview to reposition.";
}
function update(){
 if(!selectedId)return;const asset=state().find(a=>a.id===selectedId);if(!asset)return;
 Object.assign(asset,values());sync();$("z3dStatus").textContent="Selected asset updated.";
}
function remove(){
 if(!selectedId)return;pages[activePage].assets=state().filter(a=>a.id!==selectedId);selectedId=null;sync();$("z3dStatus").textContent="Asset removed from this page.";
}
function sync(){
 const baseRender=window.__z3dBaseRender;if(typeof baseRender==="function")baseRender();
 if(!pages.length)return;
 currentHtml=lib.inject(currentHtml,state());
 $("preview").srcdoc=currentHtml;$("code").textContent=currentHtml;
 $("z3dUpdate").disabled=!selectedId;$("z3dRemove").disabled=!selectedId;refresh();
}
function init(){
 $("z3dIndustry").innerHTML='<option>All industries</option>'+lib.groups.map(g=>'<option>'+esc(g[0])+'</option>').join("");
 $("z3dIndustry").addEventListener("change",draw);$("z3dSearch").addEventListener("input",draw);
 $("z3dAdd").addEventListener("click",add);$("z3dUpdate").addEventListener("click",update);$("z3dRemove").addEventListener("click",remove);
 $("z3dX").addEventListener("input",()=>{if(selectedId)update()});$("z3dY").addEventListener("input",()=>{if(selectedId)update()});
 $("z3dSize").addEventListener("change",()=>{if(selectedId)update()});$("z3dRotation").addEventListener("input",()=>{if(selectedId)update()});
 $("z3dColor").addEventListener("change",()=>{if(selectedId)update()});$("z3dLabel").addEventListener("change",()=>{if(selectedId)update()});
 draw();
 const original=window.render;
 if(typeof original==="function"){
  window.__z3dBaseRender=original;
  window.render=function(){original();if(pages.length){currentHtml=lib.inject(currentHtml,state());$("preview").srcdoc=currentHtml;$("code").textContent=currentHtml;refresh();}};
 }
 window.addEventListener("message",e=>{
  if(e.source!==$("preview").contentWindow||e.data?.type!=="z3d-move"||!pages.length)return;
  const a=state().find(x=>x.id===e.data.id);if(!a)return;
  a.x=Math.max(0,Math.min(90,Number(e.data.x)||0));a.y=Math.max(0,Math.min(90,Number(e.data.y)||0));refresh();
 });
 refresh();
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",init);else init();
})();