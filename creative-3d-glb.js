(()=>{
const $=id=>document.getElementById(id),lib=window.Zenvio3DAssets;
if(!lib)return;
const originalInject=lib.inject;
lib.inject=function(html,list){
 const safe=(list||[]).filter(a=>a.type!=="glb");
 html=originalInject(html,safe);
 const models=(list||[]).filter(a=>a.type==="glb"&&a.dataUrl);
 if(!models.length)return html;
 const stage='<div id="z3d-real-stage" style="position:fixed;right:2vw;top:17vh;width:min(42vw,560px);height:min(62vh,520px);z-index:45;pointer-events:auto;touch-action:none;filter:drop-shadow(0 24px 35px #0008)"><canvas id="z3d-real-canvas" style="width:100%;height:100%;display:block;touch-action:none"></canvas><div style="position:absolute;left:12px;bottom:10px;padding:5px 9px;border:1px solid #ffffff30;border-radius:20px;background:#080812aa;color:#fff;font:10px system-ui">REAL 3D MODEL · DRAG TO MOVE</div></div>';
 const specs=models.map(m=>({id:m.id,dataUrl:m.dataUrl,x:m.x,y:m.y,scale:(m.scale||100)/100,rotation:(m.rotation||0)*Math.PI/180,label:m.label||m.name}));
 const moduleScript='<script type="module">import * as THREE from "https://cdn.jsdelivr.net/npm/three@0.169.0/build/three.module.js";import {GLTFLoader} from "https://cdn.jsdelivr.net/npm/three@0.169.0/examples/jsm/loaders/GLTFLoader.js";const canvas=document.getElementById("z3d-real-canvas");if(canvas){const scene=new THREE.Scene();const camera=new THREE.PerspectiveCamera(35,1,.1,100);camera.position.set(0,1.2,6);const renderer=new THREE.WebGLRenderer({canvas,alpha:true,antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.outputColorSpace=THREE.SRGBColorSpace;scene.add(new THREE.HemisphereLight(0xffffff,0x505070,2));const key=new THREE.DirectionalLight(0xffffff,3);key.position.set(3,5,5);scene.add(key);const root=new THREE.Group();scene.add(root);const loader=new GLTFLoader();const specs='+JSON.stringify(specs)+';const loaded=[];for(const s of specs){try{const buf=await(await fetch(s.dataUrl)).arrayBuffer();const gltf=await new Promise((resolve,reject)=>loader.parse(buf,"",resolve,reject));const obj=gltf.scene;const box=new THREE.Box3().setFromObject(obj);const center=box.getCenter(new THREE.Vector3());const size=box.getSize(new THREE.Vector3());obj.position.sub(center);const max=Math.max(size.x,size.y,size.z)||1;obj.scale.multiplyScalar(2.1/max*s.scale);const holder=new THREE.Group();holder.add(obj);holder.position.set((s.x-50)/18,(42-s.y)/24,0);holder.rotation.y=s.rotation;holder.userData.assetId=s.id;root.add(holder);loaded.push(holder)}catch(err){console.warn("ZENVIO GLB load failed",s.label,err)}}const resize=()=>{const w=canvas.clientWidth||500,h=canvas.clientHeight||400;renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix()};new ResizeObserver(resize).observe(canvas);resize();let drag=null,active=null;const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2();canvas.addEventListener("pointerdown",e=>{const r=canvas.getBoundingClientRect();pointer.x=((e.clientX-r.left)/r.width)*2-1;pointer.y=-((e.clientY-r.top)/r.height)*2+1;raycaster.setFromCamera(pointer,camera);const hit=raycaster.intersectObjects(root.children,true)[0];active=hit?.object||null;while(active&&!active.userData.assetId)active=active.parent;if(active){parent.postMessage({type:"z3d-select",id:active.userData.assetId},"*");drag={x:e.clientX,y:e.clientY};canvas.setPointerCapture(e.pointerId)}});canvas.addEventListener("pointermove",e=>{if(!drag||!active)return;active.rotation.y+=(e.clientX-drag.x)*.012;active.rotation.x+=(e.clientY-drag.y)*.008;drag={x:e.clientX,y:e.clientY}});canvas.addEventListener("pointerup",()=>{if(drag&&active)parent.postMessage({type:"z3d-rotate",id:active.userData.assetId,rotation:active.rotation.y*180/Math.PI},"*");drag=null});const tick=()=>{requestAnimationFrame(tick);renderer.render(scene,camera)};tick()}</script>';
 return html.replace("</body>",stage+moduleScript+"</body>");
};
const state=()=>pages[activePage].assets||(pages[activePage].assets=[]);
let selectedId=null;
function current(){return state().find(a=>a.id===selectedId&&a.type==="glb")}
function redraw(){
 const models=state().filter(a=>a.type==="glb");
 $("z3dGlbSelect").innerHTML=models.length?models.map(a=>'<option value="'+a.id+'">'+String(a.label||a.name).replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]))+'</option>').join(""):'<option value="">No uploaded models</option>';
 if(selectedId&&models.some(a=>a.id===selectedId))$("z3dGlbSelect").value=selectedId;
 $("z3dGlbDelete").disabled=!models.length;
}
function refreshPreview(){if(typeof window.render==="function")window.render();redraw()}
function select(id){
 selectedId=id||null;const a=current();if(!a){$("z3dGlbDelete").disabled=true;return}
 $("z3dGlbX").value=a.x;$("z3dGlbY").value=a.y;$("z3dGlbScale").value=a.scale;$("z3dGlbRotate").value=a.rotation;
 $("z3dGlbDelete").disabled=false;
}
function addFile(file){
 if(!file)return;
 if(!/\.glb$/i.test(file.name)){ $("z3dGlbStatus").textContent="Please choose a .glb file. GLTF JSON files are not supported in this first release.";return}
 if(file.size>1572864){$("z3dGlbStatus").textContent="This model is larger than 1.5 MB. Compress the GLB and try again.";return}
 $("z3dGlbStatus").textContent="Reading and preparing "+file.name+"…";
 const reader=new FileReader();
 reader.onload=()=>{
  const asset={id:"glb-"+Date.now().toString(36),type:"glb",name:file.name,label:file.name.replace(/\.glb$/i,""),dataUrl:reader.result,x:70,y:22,scale:100,rotation:0,industry:"Custom upload"};
  state().push(asset);selectedId=asset.id;refreshPreview();select(asset.id);
  $("z3dGlbStatus").textContent="3D model added. It should appear in the preview after Three.js loads. Save the project to keep it.";
 };
 reader.onerror=()=>{$("z3dGlbStatus").textContent="Could not read this file. Try another GLB."};
 reader.readAsDataURL(file);
}
function change(){
 const a=current();if(!a)return;
 a.x=Number($("z3dGlbX").value);a.y=Number($("z3dGlbY").value);a.scale=Number($("z3dGlbScale").value);a.rotation=Number($("z3dGlbRotate").value);
 refreshPreview();
}
function init(){
 if(!$("z3dGlbFile"))return;
 $("z3dGlbFile").addEventListener("change",e=>addFile(e.target.files?.[0]));
 $("z3dGlbSelect").addEventListener("change",e=>select(e.target.value));
 $("z3dGlbDelete").addEventListener("click",()=>{if(!selectedId)return;pages[activePage].assets=state().filter(a=>a.id!==selectedId);selectedId=null;refreshPreview();$("z3dGlbStatus").textContent="Uploaded model removed from this page."});
 ["z3dGlbX","z3dGlbY","z3dGlbScale","z3dGlbRotate"].forEach(id=>$(id).addEventListener("change",change));
 window.addEventListener("message",e=>{if(e.source!==$("preview").contentWindow)return;const d=e.data||{};if(d.type==="z3d-select"){const a=state().find(x=>x.id===d.id&&x.type==="glb");if(a)select(a.id);return}if(d.type==="z3d-rotate"){const a=state().find(x=>x.id===d.id&&x.type==="glb");if(a){a.rotation=Math.round(d.rotation);select(a.id)}return}if(d.type!=="z3d-glb-move")return;const a=state().find(x=>x.id===d.id);if(!a)return;a.x=Math.round(d.x);a.y=Math.round(d.y);select(a.id);redraw()});
 redraw();
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",init);else init();
})();