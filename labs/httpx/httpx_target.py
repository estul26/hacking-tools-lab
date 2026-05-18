import base64
import html
import json
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


HOST = "0.0.0.0"
PORT = 8080
EXPECTED_AUTH = "Basic " + base64.b64encode(b"httpx:packetlab").decode("ascii")
FAVICON = (
    b"\x00\x00\x01\x00\x01\x00\x10\x10\x00\x00\x01\x00\x20\x00"
    b"\x68\x04\x00\x00\x16\x00\x00\x00"
)


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def page(title, body, links=None):
    link_items = ""
    if links:
        link_items = "\n  <ul>\n"
        for path, label in links:
            link_items += f'    <li><a href="{html.escape(path)}">{html.escape(label)}</a></li>\n'
        link_items += "  </ul>\n"

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{html.escape(title)}</title>
  <link rel="icon" href="/favicon.ico">
</head>
<body>
  <h1>{html.escape(title)}</h1>
  <p>{html.escape(body)}</p>{link_items}
</body>
</html>
"""


class HttpxLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "PacketLabHTTPX/1.0"
    sys_version = ""

    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]}:{self.client_address[1]} {fmt % args}", flush=True)

    def send_body(self, status, body=b"", content_type="text/plain; charset=utf-8", headers=None, cookie=False):
        if isinstance(body, str):
            body = body.encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Powered-By", "PacketLabHTTPX/1.0")
        self.send_header("X-Lab-Scope", "local-only")
        self.send_header("X-Frame-Options", "SAMEORIGIN")
        if cookie:
            self.send_header("Set-Cookie", "httpx_lab=local-session; Path=/; HttpOnly")
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.send_header("Connection", "close")
        self.end_headers()

        if self.command != "HEAD":
            self.wfile.write(body)

    def send_json(self, status, payload, headers=None):
        self.send_body(status, json_bytes(payload), "application/json; charset=utf-8", headers)

    def read_body(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length <= 0:
            return b""
        return self.rfile.read(length)

    def is_authorized(self):
        return self.headers.get("Authorization") == EXPECTED_AUTH

    def do_HEAD(self):
        self.route()

    def do_GET(self):
        self.route()

    def do_POST(self):
        parsed = urlsplit(self.path)
        if parsed.path != "/login":
            return self.send_json(404, {"error": "not found", "path": parsed.path})

        form = parse_qs(self.read_body().decode("utf-8", errors="replace"), keep_blank_values=True)
        username = form.get("username", [""])[0]
        password = form.get("password", [""])[0]
        if username == "admin" and password == "packetlab":
            return self.send_json(200, {"authenticated": True, "user": username, "tool": "httpx"})

        return self.send_json(401, {"authenticated": False, "hint": "try admin / packetlab"})

    def route(self):
        path = urlsplit(self.path).path

        if path == "/":
            return self.send_body(200, self.home_page(), "text/html; charset=utf-8", cookie=True)
        if path == "/health":
            return self.send_json(200, {"status": "ok", "service": "httpx-lab"})
        if path == "/api/status":
            return self.send_json(
                200,
                {
                    "service": "httpx-lab",
                    "status": "ok",
                    "time": now_iso(),
                    "client": self.client_address[0],
                },
            )
        if path == "/admin/":
            return self.admin_response()
        if path == "/forbidden":
            return self.send_body(403, page("Forbidden", "This local lab path returns 403."), "text/html; charset=utf-8")
        if path == "/login":
            return self.send_body(200, self.login_form(), "text/html; charset=utf-8", cookie=True)
        if path == "/redirect":
            return self.send_body(302, "redirecting\n", headers={"Location": "/login"})
        if path == "/slow":
            time.sleep(1)
            return self.send_json(200, {"status": "slow-ok", "delay_seconds": 1})
        if path == "/tech":
            return self.send_body(
                200,
                page("Technology Signals", "Headers and content for httpx fingerprinting."),
                "text/html; charset=utf-8",
                headers={
                    "X-Generator": "PacketLab CMS",
                    "X-App-Version": "httpx-lab-1.0",
                },
            )
        if path == "/robots.txt":
            return self.send_body(200, "User-agent: *\nDisallow: /admin/\nDisallow: /backup/\n")
        if path == "/favicon.ico":
            return self.send_body(200, FAVICON, "image/x-icon")

        return self.send_json(404, {"error": "not found", "path": path})

    def admin_response(self):
        if not self.is_authorized():
            return self.send_body(
                401,
                "admin login required\n",
                headers={"WWW-Authenticate": 'Basic realm="httpx-lab-admin"'},
            )

        return self.send_json(200, {"admin": True, "scope": "local", "tool": "httpx"})

    def home_page(self):
        return page(
            "HTTPX Local Lab",
            "A local-only target with predictable probe results for ProjectDiscovery httpx.",
            [
                ("/health", "Health JSON"),
                ("/api/status", "Status API"),
                ("/admin/", "Basic Auth Admin"),
                ("/forbidden", "Forbidden"),
                ("/login", "Login Form"),
                ("/redirect", "Redirect"),
                ("/slow", "Slow Response"),
                ("/tech", "Technology Signals"),
                ("/robots.txt", "Robots"),
            ],
        )

    def login_form(self):
        return """<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>HTTPX Login</title></head>
<body>
  <h1>HTTPX Login</h1>
  <form method="post" action="/login">
    <label>Username <input name="username"></label>
    <label>Password <input name="password" type="password"></label>
    <button type="submit">Sign in</button>
  </form>
</body>
</html>
"""


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), HttpxLabHandler)
    print(f"Serving httpx lab target on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()
