(()=>{
const $=id=>document.getElementById(id);
let selected=null;
const editable='h1,h2,h3,p,a,button,.tile,.section,.hero,.image,footer,.nav';
const esc=s=>String(s??"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const page=()=>pages[activePage];
function state(){const p=page();if(!p)return null;if(!p.visualEdits)p.visualEdits={};return p.visualEdits}
function say(s){$("visualEditorStatus").textContent=s}
function decorate(html){
 if(!page())return html;
 const edits=JSON.stringify(state()||{});
 const script='<script>(function(){const edits='+edits+';const nodes=[...document.querySelectorAll('+JSON.stringify(editable)+')];nodes.forEach((el,i)=>{el.dataset.zvNode=String(i);const e=edits[i];if(e){if(e.text!==undefined&&/^(H1|H2|H3|P|A|BUTTON)$/.test(el.tagName))el.textContent=e.text;if(e.color)el.style.color=e.color;if(e.background)el.style.backgroundColor=e.background;if(e.fontSize)el.style.fontSize=e.fontSize+"px";if(e.align)el.style.textAlign=e.align;if(e.bold!==undefined)el.style.fontWeight=e.bold?"800":"400"}el.style.cursor="pointer";el.addEventListener("click",ev=>{if(ev.target.closest("#z3d-section-dock"))return;ev.preventDefault();ev.stopPropagation();parent.postMessage({type:"zv-select",index:i,tag:el.tagName,text:el.innerText||el.textContent||"",color:rgb(el.style.color||getComputedStyle(el).color),background:rgb(el.style.backgroundColor||getComputedStyle(el).backgroundColor),fontSize:parseInt(getComputedStyle(el).fontSize)||16,align:getComputedStyle(el).textAlign,bold:Number(getComputedStyle(el).fontWeight)>=600},"*")},true)});function rgb(v){const m=String(v).match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/);return m?"#"+[m[1],m[2],m[3]].map(x=>Number(x).toString(16).padStart(2,"0")).join(""):"#ffffff"}})();<\\/script>';
 return html.replace("</body>",script+"</body>");
}
function sync(){
 if(!page())return;
 const html=decorate(window.__zvVisualBaseRender?currentHtml:currentHtml);
 currentHtml=html;$("preview").srcdoc=html;$("code").textContent=html;
}
function apply(){
 if(selected===null||!state())return;
 const e=state()[selected]||(state()[selected]={});
 e.text=$("visualText").value;
 e.fontSize=Number($("visualFontSize").value);
 e.color=$("visualTextColor").value;
 e.background=$("visualBgColor").value;
 e.align=$("visualAlign").value;
 e.bold=$("visualBold").checked;
 const p=page();p.visualEdits=state();
 const base=window.__zvVisualBaseRender;
 if(typeof base==="function")base();
 currentHtml=decorate(currentHtml);$("preview").srcdoc=currentHtml;$("code").textContent=currentHtml;
 say("Visual changes applied to this element. Save the project to keep them.");
}
function select(d){
 selected=Number(d.index);
 $("visualText").value=d.text||"";
 $("visualFontSize").value=d.fontSize||16;
 $("visualTextColor").value=d.color||"#ffffff";
 $("visualBgColor").value=d.background||"#000000";
 $("visualAlign").value=["left","center","right","justify"].includes(d.align)?d.align:"left";
 $("visualBold").checked=!!d.bold;
 $("visualEditorSelection").textContent=d.tag+" · Element "+(selected+1);
 $("visualApply").disabled=false;say("Selected element. Edit its content and styling.");
}
function init(){
 if(!$("preview")||$("zvVisualEditor"))return;
 const panel=document.createElement("section");panel.id="zvVisualEditor";panel.className="panel";panel.style.marginTop="14px";
 panel.innerHTML='<div class="eyebrow">ULTIMATE EDITION · VISUAL PAGE BUILDER</div><h2 style="margin:6px 0">Direct canvas editor</h2><p class="muted small">Click a heading, paragraph, button or section in the website preview to select it. Then edit its content and styling here. Changes are stored in the page project data.</p><div class="row"><strong id="visualEditorSelection" class="small">No element selected</strong></div><div class="field"><label>Text / label</label><textarea id="visualText" rows="2" placeholder="Select a text element first"></textarea></div><div class="row"><label class="small">Font size <input id="visualFontSize" type="range" min="10" max="120" value="16"></label><label class="small"><input id="visualBold" type="checkbox"> Bold</label></div><div class="row"><label class="small">Text color <input id="visualTextColor" type="color" value="#ffffff"></label><label class="small">Background <input id="visualBgColor" type="color" value="#000000"></label><select id="visualAlign"><option value="left">Left</option><option value="center">Center</option><option value="right">Right</option><option value="justify">Justify</option></select></div><div class="row"><button class="btn" id="visualApply" disabled>Apply to element</button><button class="btn secondary" id="visualReset" disabled>Reset element</button></div><div id="visualEditorStatus" class="status" aria-live="polite">Generate or open a project to start editing.</div>';
 $("z3dPanel").after(panel);
 $("visualApply").onclick=apply;
 $("visualReset").onclick=()=>{if(selected===null||!state())return;delete state()[selected];const base=window.__zvVisualBaseRender;if(typeof base==="function")base();currentHtml=decorate(currentHtml);$("preview").srcdoc=currentHtml;$("code").textContent=currentHtml;say("Element styling reset.")};
 const original=window.render;
 if(typeof original==="function"){
  window.__zvVisualBaseRender=original;
  window.render=function(){original();if(page()){currentHtml=decorate(currentHtml);$("preview").srcdoc=currentHtml;$("code").textContent=currentHtml;}};
 }
 window.addEventListener("message",e=>{if(e.source!==$("preview").contentWindow)return;if(e.data?.type==="zv-select"){select(e.data);$("visualReset").disabled=false}});
 $("orgSelect").addEventListener("change",()=>{selected=null;$("visualApply").disabled=true});
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",init);else init();
})();