///|
// Stateful SSR components need the same application graph initialization as
// application entry points. Constructing the app does not mount a browser DOM.
fn book_test_render_component(
  component : () -> @rabbita.Val[@rabbita.Html],
) -> String {
  book_test_ssr_window(false)
  defer book_test_ssr_window(true)
  ignore(@rabbita.new(component))
  @rabbita.render_to_string(component)
}

///|
// The unmounted SSR sandbox still schedules its state flush. Keep its real
// callback scheduling while supplying the frame API absent from Node fixtures.
extern "js" fn book_test_ssr_window(restore : Bool) -> Unit =
  #| restore => {
  #|   const key = "__moonbookTestSsrWindowScopes";
  #|   if (restore) {
  #|     const scopes = globalThis[key]; const saved = scopes.pop();
  #|     if (saved.had) globalThis.window = saved.value; else delete globalThis.window;
  #|     if (!scopes.length) delete globalThis[key]; return;
  #|   }
  #|   const had = Object.prototype.hasOwnProperty.call(globalThis, "window");
  #|   const value = globalThis.window; const scopes = globalThis[key] || (globalThis[key] = []);
  #|   const temporary = Object.create(value && typeof value === "object" ? value : null);
  #|   if (!value?.location?.href) {
  #|     Object.defineProperty(temporary, "location", {value: Object.assign(new URL("http://localhost/"), value?.location || {}), configurable: true});
  #|   }
  #|   const frame = typeof value?.requestAnimationFrame === "function" ? value.requestAnimationFrame.bind(value) : callback => { queueMicrotask(() => callback(performance.now())); return 0; };
  #|   Object.defineProperty(temporary, "requestAnimationFrame", {value: frame, configurable: true});
  #|   scopes.push({had, value}); globalThis.window = temporary;
  #| }
