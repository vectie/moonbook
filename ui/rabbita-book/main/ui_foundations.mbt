///|
#warnings("-alert_xss_vulnerable")
fn ui_icon(name : String, size? : Int = 20) -> @rabbita.Html {
  let body = match name {
    "overview" =>
      "<rect x=\"3\" y=\"3\" width=\"7\" height=\"7\" rx=\"1\"/><rect x=\"14\" y=\"3\" width=\"7\" height=\"7\" rx=\"1\"/><rect x=\"3\" y=\"14\" width=\"7\" height=\"7\" rx=\"1\"/><rect x=\"14\" y=\"14\" width=\"7\" height=\"7\" rx=\"1\"/>"
    "review" =>
      "<path d=\"M9 12l2 2 4-5\"/><circle cx=\"12\" cy=\"12\" r=\"9\"/>"
    "queue" => "<path d=\"M4 4h16v12H4z\"/><path d=\"M4 12h4l2 3h4l2-3h4\"/>"
    "map" =>
      "<circle cx=\"5\" cy=\"12\" r=\"2\"/><circle cx=\"19\" cy=\"5\" r=\"2\"/><circle cx=\"19\" cy=\"19\" r=\"2\"/><path d=\"M7 11l10-5M7 13l10 5\"/>"
    "keeper" =>
      "<path d=\"M4 5.5A3.5 3.5 0 017.5 2H12v18H7.5A3.5 3.5 0 004 23z\"/><path d=\"M20 5.5A3.5 3.5 0 0016.5 2H12v18h4.5A3.5 3.5 0 0120 23z\"/>"
    "arrow" => "<path d=\"M5 12h14M13 6l6 6-6 6\"/>"
    "record" =>
      "<path d=\"M6 3h9l4 4v14H6z\"/><path d=\"M14 3v5h5M9 13h6M9 17h6\"/>"
    "authority" =>
      "<circle cx=\"8\" cy=\"12\" r=\"4\"/><path d=\"M12 12h9M18 12v3M15 12v2\"/>"
    "verify" =>
      "<path d=\"M12 3l8 4v5c0 5-3.4 8-8 9-4.6-1-8-4-8-9V7z\"/><path d=\"M8.5 12l2.2 2.2 4.8-5\"/>"
    "settings" =>
      "<path d=\"M4 7h10M18 7h2M4 17h2M10 17h10\"/><circle cx=\"16\" cy=\"7\" r=\"2\"/><circle cx=\"8\" cy=\"17\" r=\"2\"/>"
    _ => "<circle cx=\"12\" cy=\"12\" r=\"9\"/>"
  }
  let markup = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" width=\"" +
    size.to_string() +
    "\" height=\"" +
    size.to_string() +
    "\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\" focusable=\"false\">" +
    body +
    "</svg>"
  @html.span(
    class="moonbook-ui-icon",
    attrs=@html.Attrs::build().aria_hidden("true").inner_html(markup),
    "",
  )
}

///|
fn app_accessibility_styles() -> @rabbita.Html {
  @html.style_tag(
    (
      #|.moonbook-skip-link{position:fixed;left:16px;top:12px;z-index:1000;transform:translateY(-160%);padding:10px 14px;border-radius:12px;background:#0f172a;color:#fff;text-decoration:none;font-weight:700}.moonbook-skip-link:focus{transform:translateY(0)}.moonbook-ui-icon{display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto;line-height:0}.moonbook-icon-label{display:flex;align-items:center;gap:10px;min-width:0}.moonbook-primary-action{min-height:44px;display:inline-flex;align-items:center;justify-content:center;gap:10px;padding:0 18px;border:0;border-radius:14px;background:#2563eb;color:#fff;font-weight:750;text-decoration:none;cursor:pointer;box-shadow:0 12px 28px rgba(37,99,235,.22)}.moonbook-secondary-action{min-height:44px;display:inline-flex;align-items:center;justify-content:center;gap:9px;padding:0 15px;border:1px solid #64748b;border-radius:14px;background:transparent;color:inherit;font-weight:700;cursor:pointer}.moonbook-progress{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px}.moonbook-progress-step{min-height:58px;padding:10px;border:1px solid #334155;border-radius:14px;color:#94a3b8;display:flex;align-items:center;gap:8px;font-size:12px;font-weight:700}.moonbook-progress-step.complete{color:#bbf7d0;border-color:#166534;background:rgba(22,101,52,.18)}.moonbook-progress-step.current{color:#dbeafe;border-color:#60a5fa;background:rgba(37,99,235,.22)}.moonbook-progress-step.blocked{color:#fde68a;border-color:#d97706;background:rgba(217,119,6,.16)}button,input,textarea,a,summary{scroll-margin-top:20px}button{min-height:44px}button:focus-visible,input:focus-visible,textarea:focus-visible,a:focus-visible,summary:focus-visible{outline:3px solid #38bdf8!important;outline-offset:3px}.moonbook-technical-disclosure>summary{min-height:44px;display:flex;align-items:center;gap:9px;cursor:pointer;font-weight:700;list-style:none}.moonbook-technical-disclosure>summary::-webkit-details-marker{display:none}@media(max-width:720px){.moonbook-progress{grid-template-columns:1fr 1fr}.moonbook-progress-step{min-height:52px}}@media(prefers-reduced-motion:reduce){*,*::before,*::after{scroll-behavior:auto!important;animation-duration:.001ms!important;animation-iteration-count:1!important;transition-duration:.001ms!important}}
    ),
  )
}
