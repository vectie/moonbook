///|
extern "js" fn lesson_requested_saved_reference() -> String =
  #| () => { const value=globalThis.__moonbookRequestedLesson||'';delete globalThis.__moonbookRequestedLesson;return value; }

///|
extern "js" fn lesson_return_book_origin() -> String =
  #| () => globalThis.location?.origin||''

///|
extern "js" fn lesson_download_saved_receipt(text : String) =
  #| text => {const url=URL.createObjectURL(new Blob([text],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='moonbook-saved-lesson-receipt.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}

///|
extern "js" fn lesson_send_saved_receipt_on(
  browser : LessonReceiverBrowser,
  text : String,
) -> @js.Promise =
  #| (browser,text) => new Promise(resolve=>{
  #|   let nonce,origin,opener;try{const params=new URLSearchParams(browser.location.search);nonce=params.get('proj_lesson_nonce');const source=params.get('proj_lesson_source');const url=new URL(source);opener=browser.opener;if(!nonce||!opener||opener.closed||!['http:','https:'].includes(url.protocol)||url.origin!==source)throw Error();origin=url.origin;}catch(_){resolve(false);return;}
  #|   let ended=false,timer;const finish=result=>{if(ended)return;ended=true;browser.clearTimeout(timer);browser.removeEventListener('message',receive);resolve(result);};
  #|   const receive=event=>{if(event.source!==opener||event.origin!==origin||event.data?.nonce!==nonce||event.data?.kind!=='moonproj.saved-lesson-received.v1'||event.data?.payload!==text)return;finish(true);};
  #|   try{browser.addEventListener('message',receive);timer=browser.setTimeout(()=>finish(false),15000);opener.postMessage({kind:'moonbook.saved-lesson-return.v1',nonce,payload:text},origin);}catch(_){finish(false);}
  #| })
