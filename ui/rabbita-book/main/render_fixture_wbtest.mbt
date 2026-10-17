///|
// Stateful SSR components need the same application graph initialization as
// application entry points. Constructing the app does not mount a browser DOM.
fn book_test_render_component(
  component : () -> @rabbita.Val[@rabbita.Html],
) -> String {
  ignore(@rabbita.new(component))
  @rabbita.render_to_string(component)
}
