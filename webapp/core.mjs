export const maxAge=15000;
export function validFix(p,now=Date.now()){
 const c=p?.coords;return !!c&&Number.isFinite(p.timestamp)&&p.timestamp<=now+1000&&now-p.timestamp<=maxAge&&Number.isFinite(c.latitude)&&Math.abs(c.latitude)<=90&&Number.isFinite(c.longitude)&&Math.abs(c.longitude)<=180&&Number.isFinite(c.accuracy)&&c.accuracy>0&&c.accuracy<=50;
}
export function speedText(p,now=Date.now()){return validFix(p,now)&&Number.isFinite(p.coords.speed)&&p.coords.speed>=0?`${Math.round(p.coords.speed*3.6)} km/h`:'— km/h';}
export function distanceMeters(a,b){const rad=Math.PI/180;const dlat=(b.latitude-a.latitude)*rad,dlon=(b.longitude-a.longitude)*rad;const h=Math.sin(dlat/2)**2+Math.cos(a.latitude*rad)*Math.cos(b.latitude*rad)*Math.sin(dlon/2)**2;return 6371000*2*Math.asin(Math.sqrt(Math.min(1,h)));}
export function segment(a,b){if(!a||!b||b.timestamp<=a.timestamp||b.timestamp-a.timestamp>maxAge)return 0;const d=distanceMeters(a.coords,b.coords);return d>Math.max(a.coords.accuracy,b.coords.accuracy)&&d/((b.timestamp-a.timestamp)/1000)<=70?d:0;}
export function mapsUrl(query){const u=new URL('https://www.google.com/maps/search/');u.searchParams.set('api','1');u.searchParams.set('query',query);return u.href;}
