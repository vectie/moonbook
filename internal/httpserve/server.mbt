///|
pub struct ServeOptions {
  root : String
  hostname : String
  port : Int
} derive(Show, ToJson)

///|
pub fn default_options(root : String) -> ServeOptions {
  { root, hostname: "localhost", port: 3000 }
}

///|
pub fn parse_serve_args(args : Array[String]) -> ServeOptions? {
  let mut root = "."
  let mut hostname = "localhost"
  let mut port = 3000
  let mut index = 0
  let mut seen_root = false
  while index < args.length() {
    match args[index] {
      "-n" | "--hostname" =>
        if index + 1 < args.length() {
          hostname = args[index + 1]
          index += 2
        } else {
          return None
        }
      "-p" | "--port" =>
        if index + 1 < args.length() {
          port = @strconv.parse_int(args[index + 1]) catch { _ => return None }
          index += 2
        } else {
          return None
        }
      value =>
        if !seen_root && !value.has_prefix("-") {
          root = value
          seen_root = true
          index += 1
        } else {
          return None
        }
    }
  }
  Some({ root, hostname, port })
}

///|
pub struct Server {
  server : @http.Server
  port : Int
}

///|
pub fn Server::port(self : Server) -> Int {
  self.port
}

///|
pub fn Server::close(self : Server) -> Unit {
  self.server.close()
}

///|
pub fn Server::new(
  host : String,
  port : Int,
  dual_stack? : Bool = true,
  reuse_addr? : Bool = false,
) -> Server raise {
  let server = @http.Server::new(
    @socket.Addr::parse("\{host}:\{port}"),
    dual_stack~,
    reuse_addr~,
  )
  { server, port: server.addr().port() }
}

///|
async fn handle_file_request(
  root : String,
  method_ : @http.RequestMethod,
  path : StringView,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(root)
  guard method_ is @http.RequestMethod::Get ||
    method_ is @http.RequestMethod::Head else {
    send_status(conn, 405, "Method Not Allowed", "Method Not Allowed\n")
    return
  }
  let resolved = resolve_request_path(root, path)
  match resolved {
    Some(file_path) =>
      if @fs.exists(file_path) {
        send_file(conn, method_, file_path, 200, "OK")
      } else {
        send_not_found(root, conn, method_)
      }
    None => send_status(conn, 400, "Bad Request", "Bad Request\n")
  }
}

///|
fn resolve_request_path(root : String, request_path : StringView) -> String? {
  let relative = match request_path {
    "/" => "index.html"
    ['/', .. path] => path.to_string()
    _ => return None
  }
  let normalized = @pathx.normalize(relative)
  if normalized == "." {
    return Some(@pathx.join(root, "index.html"))
  }
  if normalized == ".." || normalized.has_prefix("../") {
    return None
  }
  let resolved = @pathx.join(root, normalized)
  let expected_prefix = root + "/"
  if resolved == root || resolved.has_prefix(expected_prefix) {
    Some(resolved)
  } else {
    None
  }
}

///|
async fn send_not_found(
  root : String,
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
) -> Unit {
  let not_found_path = @pathx.join(root, "404.html")
  if @fs.exists(not_found_path) {
    send_file(conn, method_, not_found_path, 404, "Not Found")
  } else {
    send_status(conn, 404, "Not Found", "Not Found\n")
  }
}

///|
pub async fn Server::serve_directory(self : Server, root : String) -> Unit {
  self.server.run_forever(
    (request, _, conn) => {
      handle_file_request(root, request.meth, request.path, conn)
    },
    allow_failure=true,
  )
}

///|
async fn send_file(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  path : String,
  code : Int,
  reason : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": content_type(path),
  })
  if method_ is @http.RequestMethod::Head {
    conn.end_response()
    return
  }
  conn.write(@fs.read_file(path).binary())
  conn.end_response()
}

///|
async fn send_status(
  conn : @http.ServerConnection,
  code : Int,
  reason : String,
  body : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": "text/plain; charset=utf-8",
  })
  conn.write(body)
  conn.end_response()
}

///|
fn content_type(path : String) -> String {
  match @pathx.ext(path) {
    ".html" => "text/html; charset=utf-8"
    ".css" => "text/css; charset=utf-8"
    ".js" => "application/javascript"
    ".json" => "application/json"
    ".svg" => "image/svg+xml"
    ".png" => "image/png"
    ".jpg" | ".jpeg" => "image/jpeg"
    ".gif" => "image/gif"
    ".webp" => "image/webp"
    ".ico" => "image/x-icon"
    ".txt" | ".md" => "text/plain; charset=utf-8"
    _ => "application/octet-stream"
  }
}

///|
test "serve args parser handles defaults and flags" {
  let defaults = parse_serve_args(["./book"]).unwrap()
  assert_eq(defaults.root, "./book")
  assert_eq(defaults.hostname, "localhost")
  assert_eq(defaults.port, 3000)
  let explicit = parse_serve_args(["./book", "-n", "127.0.0.1", "-p", "8001"]).unwrap()
  assert_eq(explicit.root, "./book")
  assert_eq(explicit.hostname, "127.0.0.1")
  assert_eq(explicit.port, 8001)
  assert_true(parse_serve_args(["-p"]) is None)
  assert_true(parse_serve_args(["./book", "--port", "bad"]) is None)
}

///|
test "resolve request path normalizes and rejects traversal" {
  assert_eq(
    resolve_request_path("/tmp/moonbook-serve", "/"),
    Some("/tmp/moonbook-serve/index.html"),
  )
  assert_eq(
    resolve_request_path("/tmp/moonbook-serve", "/nested/page.html"),
    Some("/tmp/moonbook-serve/nested/page.html"),
  )
  assert_eq(resolve_request_path("/tmp/moonbook-serve", "/../secret"), None)
}
