export const maxPackBytes=800000;
export function normalizeIconPack(value){
 if(!value||value.format!=='caros-icons-v1'||!value.icons||typeof value.icons!=='object'||Array.isArray(value.icons))throw Error('Gói icon không hợp lệ');
 const entries=Object.entries(value.icons);if(!entries.length||entries.length>15)throw Error('Số icon không hợp lệ');
 const icons={};let total=0;
 for(const [key,encoded] of entries){
  if(!/^(?:[0-9]|1[0-4])$/.test(key)||typeof encoded!=='string'||!encoded.length||encoded.length>200000||!/^([A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encoded))throw Error('Icon không hợp lệ');
  total+=encoded.length;if(total>maxPackBytes)throw Error('Gói quá lớn');
  const bytes=Uint8Array.from(atob(encoded.slice(0,32)),c=>c.charCodeAt(0));if(bytes.length<24||[137,80,78,71,13,10,26,10].some((v,i)=>bytes[i]!==v)||String.fromCharCode(...bytes.slice(12,16))!=='IHDR')throw Error('Chỉ hỗ trợ PNG chuẩn');
  const view=new DataView(bytes.buffer);const w=view.getUint32(16),h=view.getUint32(20);if(w<1||h<1||w>512||h>512)throw Error('Icon vượt 512px');
  icons[key]=encoded;
 }
 return {format:'caros-icons-v1',icons};
}
export async function loadIconPack(file){
 if(!file||file.size>maxPackBytes)throw Error('Gói icon vượt giới hạn');
 const pack=normalizeIconPack(JSON.parse(await file.text()));
 await Promise.all(Object.values(pack.icons).map(data=>new Promise((resolve,reject)=>{const img=new Image();img.onload=()=>resolve();img.onerror=()=>reject(Error('Ảnh PNG bị lỗi'));img.src='data:image/png;base64,'+data;})));
 return pack;
}
