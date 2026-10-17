///|
#external
priv type BookAsyncFixtureTicket

///|
extern "js" fn book_async_fixture_ticket() -> BookAsyncFixtureTicket =
  #| () => {
  #|   const key = "__moonbookAsyncFixtureQueue";
  #|   const queue = globalThis[key] || (globalThis[key] = {tail: Promise.resolve(), registered: 0, completed: 0});
  #|   const ready = queue.tail; let release;
  #|   queue.tail = new Promise(resolve => {release = resolve;}); queue.registered++;
  #|   let released = false;
  #|   return {ready, release() {
  #|     if (released) throw new Error("Async fixture released twice"); released = true;
  #|     queue.completed++; release();
  #|     if (queue.completed === queue.registered) {
  #|       console.log("BOOK_ASYNC_TESTS_COMPLETE=" + JSON.stringify({registered: queue.registered, completed: queue.completed}));
  #|       delete globalThis[key];
  #|     }
  #|   }};
  #| }

///|
extern "js" fn BookAsyncFixtureTicket::ready(
  self : BookAsyncFixtureTicket,
) -> @js.Promise = "ticket => ticket.ready"

///|
extern "js" fn BookAsyncFixtureTicket::release(
  self : BookAsyncFixtureTicket,
) -> Unit = "ticket => ticket.release()"

///|
// These fixtures own process-global browser doubles. Defer them until the
// synchronous driver finishes, then run each unchanged async body in FIFO order.
// The framework's original async assertion/error handler remains in charge.
fn book_test_async(op : async () -> Unit) -> Unit {
  let ticket = book_async_fixture_ticket()
  @js.async_test(async fn() {
    ignore(ticket.ready().wait())
    defer ticket.release()
    op()
  })
}
