///|
extern "js" fn book_collection_export(
  text : String,
  download : Bool,
) -> @js.Promise =
  #| async (text, download) => {
  #|   if (!download) { await navigator.clipboard.writeText(text); return "Research brief copied. Keep a downloaded copy before leaving."; }
  #|   const blob = new Blob([text], { type: "text/markdown;charset=utf-8" });
  #|   const url = URL.createObjectURL(blob);
  #|   const link = document.createElement("a");
  #|   link.href = url; link.download = "moonbook-research-brief.md";
  #|   document.body.appendChild(link);
  #|   try { link.click(); } finally { link.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
  #|   return "Research brief download requested. Check your browser downloads before leaving.";
  #| }
