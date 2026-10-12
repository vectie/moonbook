///|
fn book_search_optional_field(value : Json, field : String) -> Json {
  if value is Object(fields) && fields.get(field) == Some(Json::null()) {
    ignore(fields.remove(field))
  }
  value
}

///|
fn book_search_digest(value : String) -> Bool {
  value.length() == 71 &&
  value.has_prefix("sha256:") &&
  value[7:]
  .iter()
  .all(ch => (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))
}

///|
fn book_search_safe_reference(reference : String) -> Bool {
  reference.has_prefix("raw/") &&
  reference.split("/").all(part => part != "" && part != "." && part != "..") &&
  !reference
  .iter()
  .any(ch => ch.to_int() < 32 || "\\:?#%[]()".contains(ch.to_string()))
}

///|
fn book_search_decode_source(
  text : String,
  question : String,
  citation : String,
  descriptor : BookRetainedDescriptor,
  results_page? : Int,
) -> Result[BookRetainedSource, String] {
  let response : BookRetainedResponse = try {
    let value = @json.parse(text)
    if value is { "source": source, .. } {
      ignore(book_search_optional_field(source, "text"))
    }
    @json.from_json(book_search_optional_field(value, "page"))
  } catch {
    _ => return Err("Invalid retained source response.")
  }
  let source = response.source
  if response.schema != "moonbook.search.v1" ||
    !response.ok ||
    response.question != question ||
    response.citation != citation ||
    response.page != results_page ||
    source.reference != descriptor.reference ||
    source.page_digest != descriptor.page_digest ||
    !book_search_safe_reference(source.reference) ||
    !book_search_digest(source.page_digest) ||
    !book_search_digest(source.digest) ||
    source.size < 0 ||
    source.size > 2097152 ||
    source.bytes_base64.length() > 2796204 {
    Err("Retained source response does not match the selected page.")
  } else {
    Ok(source)
  }
}

///|
extern "js" fn book_search_verify_source(
  encoded : String,
  digest : String,
  size : Int,
  text : String?,
) -> @js.Promise =
  #| async (encoded, digest, size, text) => {
  #|   const binary = atob(encoded);
  #|   if (binary.length !== size || btoa(binary) !== encoded) throw new Error('Invalid retained bytes');
  #|   const bytes = Uint8Array.from(binary, ch => ch.charCodeAt(0));
  #|   if (!/^sha256:[0-9a-f]{64}$/.test(digest)) throw new Error('Invalid retained digest');
  #|   // The host always hashes these bytes. Independently cross-check when
  #|   // WebCrypto is available, without requiring HTTPS for an existing LAN host.
  #|   if (globalThis.crypto?.subtle) {
  #|     const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
  #|     if ('sha256:' + Array.from(hash, b => b.toString(16).padStart(2,'0')).join('') !== digest) throw new Error('Retained byte digest mismatch');
  #|   }
  #|   if (text !== undefined && text !== null) {
  #|     const decoded = new TextDecoder('utf-8', {fatal:true, ignoreBOM:true}).decode(bytes);
  #|     if (decoded.includes('\0') || decoded !== text) throw new Error('Retained text mismatch');
  #|   }
  #|   return true;
  #| }

///|
async fn book_search_read_source(
  question : String,
  citation : String,
  descriptor : BookRetainedDescriptor,
  results_page? : Int,
) -> Result[BookRetainedSource, String] noraise {
  let body : Map[String, Json] = {
    "question": question.to_json(),
    "citation": citation.to_json(),
    "page_digest": descriptor.page_digest.to_json(),
  }
  if results_page is Some(page) {
    body["page"] = page.to_json()
  }
  let response = book_search_post(
    "/api/book/query/retained-source",
    body.to_json(),
  )
  let text = match response {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  let decoded = book_search_decode_source(
    text,
    question,
    citation,
    descriptor,
    results_page?,
  )
  guard decoded is Ok(source) else { return decoded }
  let _ : Bool = book_search_verify_source(
      source.bytes_base64,
      source.digest,
      source.size,
      source.text,
    )
    .wait()
    .cast() catch {
      _ =>
        return Err(
          "Retained source bytes failed integrity validation. Inspect again.",
        )
    }
  Ok(source)
}

///|
extern "js" fn book_search_download_source(
  encoded : String,
  reference : String,
) -> @js.Promise =
  #| async (encoded, reference) => {
  #|   const bytes = Uint8Array.from(atob(encoded), ch => ch.charCodeAt(0));
  #|   const blob = new Blob([bytes], {type:'application/octet-stream'});
  #|   const url = URL.createObjectURL(blob);
  #|   const link = document.createElement('a');
  #|   link.href = url; link.download = 'moonbook-retained-' + reference.split('/').pop();
  #|   document.body.appendChild(link);
  #|   try { link.click(); } finally { link.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
  #|   return 'Exact retained bytes download requested.';
  #| }
