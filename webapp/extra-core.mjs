export function httpsUrl(raw){const u=new URL(raw);if(u.protocol!=='https:'||u.username||u.password)throw Error('HTTPS without credentials required');return u.href;}
export function mediaExtension(type){return type.startsWith('video/mp4')?'mp4':type.startsWith('video/webm')?'webm':null;}
export const maxVideoBytes=32*1024*1024;
