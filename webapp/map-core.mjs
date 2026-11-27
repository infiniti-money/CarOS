export const tileSize=256, minZoom=2,maxZoom=18;
export const clamp=(v,a,b)=>Math.min(b,Math.max(a,v));
export function worldSize(z){return tileSize*2**z;}
export function project(lat,lon,z){const s=worldSize(z),r=clamp(lat,-85.05112878,85.05112878)*Math.PI/180;return {x:((lon+180)/360)*s,y:(1-Math.asinh(Math.tan(r))/Math.PI)/2*s};}
export function wrapX(x,z){const s=worldSize(z);return ((x%s)+s)%s;}
export function visibleTiles(center,w,h,z){const n=2**z,left=center.x-w/2,top=center.y-h/2,tiles=[];for(let y=Math.floor(top/256);y<=Math.floor((top+h-1)/256);y++){if(y<0||y>=n)continue;for(let x=Math.floor(left/256);x<=Math.floor((left+w-1)/256);x++)tiles.push({x:((x%n)+n)%n,y,z,left:x*256-left,top:y*256-top,key:x+':'+y+':'+z});}return tiles;}
export function zoomCenter(center,oldZ,newZ){const k=2**(newZ-oldZ);return {x:wrapX(center.x*k,newZ),y:clamp(center.y*k,0,worldSize(newZ))};}
export function relative(point,center,w,h,z){const s=worldSize(z);return {x:wrapX(point.x-center.x+s/2,z)-s/2+w/2,y:point.y-center.y+h/2};}
