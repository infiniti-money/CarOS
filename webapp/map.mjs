import {project,visibleTiles,zoomCenter,wrapX,clamp,worldSize,relative,minZoom,maxZoom} from './map-core.mjs';
export function createMap({getGps,getParking}){
 const $=id=>document.getElementById(id),view=$('map-view');let enabled=false,z=5,center=project(16,108,z),drag=null,tiles=new Map(),pins=[],generation=0;
 const template='https://tile.openstreetmap.org/{z}/{x}/{y}.png'; // replace with licensed provider for production load
 function render(){if(!enabled)return;const w=view.clientWidth,h=view.clientHeight;if(!w||!h)return;const wanted=new Set();++generation;
 for(const t of visibleTiles(center,w,h,z)){wanted.add(t.key);let img=tiles.get(t.key);if(!img){img=document.createElement('img');img.alt='';img.draggable=false;img.onerror=()=>{img.dataset.failed='true';if(enabled&&tiles.get(t.key)===img)updateStatus();};img.onload=()=>{delete img.dataset.failed;if(enabled&&tiles.get(t.key)===img)updateStatus();};tiles.set(t.key,img);view.append(img);img.src=template.replace('{z}',t.z).replace('{x}',t.x).replace('{y}',t.y);}img.style.left=t.left+'px';img.style.top=t.top+'px';}
 for(const [key,img] of tiles)if(!wanted.has(key)){img.remove();tiles.delete(key);}
 for(const pin of pins)pin.remove();pins=[];for(const [type,p] of [['gps',getGps()],['parking',getParking()]]){if(!p)continue;const pos=relative(project(p.lat,p.lon,z),center,w,h,z);if(pos.x<0||pos.x>w||pos.y<0||pos.y>h)continue;const pin=document.createElement('span');pin.className='map-pin '+type;pin.title=type==='gps'?'GPS hiện tại':'Chỗ đỗ đã lưu';pin.setAttribute('role','img');pin.setAttribute('aria-label',pin.title);pin.style.left=pos.x+'px';pin.style.top=pos.y+'px';view.append(pin);pins.push(pin);}
 updateStatus();
 }
 function updateStatus(){const failed=[...tiles.values()].some(img=>img.dataset.failed==='true');$('map-status').textContent=!navigator.onLine?'Mất mạng · Không có bản đồ ngoại tuyến':failed?'Một số ô bản đồ không tải được. Kiểm tra mạng hoặc nhà cung cấp.':'Mức thu phóng '+z+' · Bản đồ trực tuyến';}
 function pan(x,y){center={x:wrapX(center.x+x,z),y:clamp(center.y+y,0,worldSize(z))};render();}
 function zoom(d){const next=clamp(z+d,minZoom,maxZoom);center=zoomCenter(center,z,next);z=next;render();}
 function locate(p){if(!p)return;z=16;center=project(p.lat,p.lon,z);render();}
 function refresh(){ $('map-center').disabled=!enabled||!getGps();$('map-park').disabled=!enabled||!getParking();if(enabled)render();}
 $('map-enable').onclick=()=>{enabled=!enabled;$('map-ui').hidden=!enabled;$('map-enable').textContent=enabled?'Tắt bản đồ':'Bật bản đồ trực tuyến';if(!enabled){generation++;for(const img of tiles.values())img.remove();tiles.clear();for(const p of pins)p.remove();pins=[];}refresh();};
 $('map-center').onclick=()=>locate(getGps());$('map-park').onclick=()=>locate(getParking());
 for(const [id,x,y] of [['left',-128,0],['right',128,0],['up',0,-128],['down',0,128]])$('map-'+id).onclick=()=>pan(x,y);
 $('map-plus').onclick=()=>zoom(1);$('map-minus').onclick=()=>zoom(-1);
 view.addEventListener('pointerdown',e=>{if(!enabled||!e.isPrimary||e.button!==0)return;drag={x:e.clientX,y:e.clientY,id:e.pointerId};view.setPointerCapture(e.pointerId);});
 view.addEventListener('pointerup',e=>{if(drag?.id===e.pointerId){pan(drag.x-e.clientX,drag.y-e.clientY);drag=null;}});view.addEventListener('pointercancel',()=>{drag=null;});
 if('ResizeObserver'in window)new ResizeObserver(()=>{if(enabled)render();}).observe(view);
 window.addEventListener('online',()=>{if(enabled){for(const img of tiles.values())img.remove();tiles.clear();render();}});window.addEventListener('offline',refresh);refresh();return {refresh};
}
