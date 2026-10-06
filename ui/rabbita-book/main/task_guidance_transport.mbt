///|
extern "js" fn task_guidance_incoming_origin() -> String =
  #| () => {try{const p=new URLSearchParams(globalThis.location?.search||''),source=p.get('proj_guidance_source'),u=new URL(source);return p.get('proj_guidance_nonce')&&['http:','https:'].includes(u.protocol)&&u.origin===source?source:'';}catch(_){return '';}}

///|
extern "js" fn task_guidance_export_fits(text : String) -> Bool =
  #| text => {try{const v=JSON.parse(text),u=new URL(v.book_origin);return ['http:','https:'].includes(u.protocol)&&u.origin===v.book_origin&&v.book_origin.length<=2048&&new TextEncoder().encode(text).length<=32768&&Number.isSafeInteger(v.observed_at)&&v.observed_at>=0;}catch(_){return false;}}

///|
extern "js" fn task_guidance_cancel_on(browser : LessonReceiverBrowser) =
  #| browser => {browser.__moonbookGuidanceCancel?.();delete browser.__moonbookGuidanceSession;}

///|
extern "js" fn task_guidance_receive_on(
  browser : LessonReceiverBrowser,
) -> @js.Promise =
  #| browser => new Promise(resolve=>{
  #|   browser.__moonbookGuidanceCancel?.();delete browser.__moonbookGuidanceSession;
  #|   let nonce,origin,opener;try{const p=new URLSearchParams(browser.location.search),source=p.get('proj_guidance_source'),u=new URL(source);nonce=p.get('proj_guidance_nonce');opener=browser.opener;if(!nonce||!opener||opener.closed||!['http:','https:'].includes(u.protocol)||u.origin!==source)throw Error();origin=u.origin;}catch(_){resolve('');return;}
  #|   let ended=false,timer;const finish=text=>{if(ended)return;ended=true;browser.clearTimeout(timer);browser.removeEventListener('message',receive);delete browser.__moonbookGuidanceCancel;resolve(text);};
  #|   const receive=e=>{if(e.source!==opener||e.origin!==origin||e.data?.nonce!==nonce||e.data?.kind!=='moonproj.guidance-query.v1')return;const text=e.data.payload;if(typeof text!=='string'||new TextEncoder().encode(text).length>32768)return;try{const handoff=JSON.parse(text);browser.__moonbookGuidanceSession={opener,origin,nonce,handoff};finish(text);}catch(_){finish('');}};
  #|   browser.__moonbookGuidanceCancel=()=>finish('');browser.addEventListener('message',receive);timer=browser.setTimeout(()=>finish(''),15000);try{opener.postMessage({kind:'moonbook.guidance-ready.v1',nonce},origin);}catch(_){finish('');}
  #| })

///|
extern "js" fn task_guidance_send_on(
  browser : LessonReceiverBrowser,
  text : String,
  expected_origin : String,
) -> @js.Promise =
  #| (browser,text,expectedOrigin) => new Promise(resolve=>{
  #|   const stable=v=>Array.isArray(v)?v.map(stable):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,stable(v[k])])):v;
  #|   let session=browser.__moonbookGuidanceSession;try{const p=new URLSearchParams(browser.location.search),v=JSON.parse(text);if(!session||!expectedOrigin||session.origin!==expectedOrigin||session.opener!==browser.opener||session.opener.closed||p.get('proj_guidance_nonce')!==session.nonce||p.get('proj_guidance_source')!==session.origin||JSON.stringify(stable(v.handoff))!==JSON.stringify(stable(session.handoff))||v.book_origin!==browser.location.origin||new TextEncoder().encode(text).length>32768)throw Error();}catch(_){resolve(false);return;}
  #|   browser.__moonbookGuidanceCancel?.();let ended=false,timer;const finish=ok=>{if(ended)return;ended=true;browser.clearTimeout(timer);browser.removeEventListener('message',receive);delete browser.__moonbookGuidanceCancel;resolve(ok);};
  #|   const receive=e=>{const p=new URLSearchParams(browser.location.search);if(browser.__moonbookGuidanceSession!==session||browser.opener!==session.opener||p.get('proj_guidance_source')!==session.origin||p.get('proj_guidance_nonce')!==session.nonce){finish(false);return;}if(e.source===session.opener&&e.origin===session.origin&&e.data?.nonce===session.nonce&&e.data?.kind==='moonproj.guidance-received.v1'&&e.data?.payload===text)finish(true);};
  #|   browser.__moonbookGuidanceCancel=()=>finish(false);browser.addEventListener('message',receive);timer=browser.setTimeout(()=>finish(false),15000);try{session.opener.postMessage({kind:'moonbook.guidance-selection.v1',nonce:session.nonce,payload:text},session.origin);}catch(_){finish(false);}
  #| })
