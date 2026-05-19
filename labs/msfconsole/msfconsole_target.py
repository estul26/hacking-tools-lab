import base64
import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


HOST = "0.0.0.0"
PORT = 8080
EXPECTED_AUTH = "Basic " + base64.b64encode(b"msf:packetlab").decode("ascii")


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def page(title, body, links=None, extra=""):
    links = links or []
    nav = "\n".join(f'<li><a href="{html.escape(href)}">{html.escape(label)}</a></li>' for href, label in links)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{html.escape(title)}</title>
</head>
<body>
  <h1>{html.escape(title)}</h1>
  <main>
    <p>{html.escape(body)}</p>
    <ul>{nav}</ul>
    {extra}
  </main>
</body>
</html>
"""


class MsfconsoleLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "Apache/2.4.7"
    sys_version = "(Ubuntu)"

    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]}:{self.client_address[1]} {fmt % args}", flush=True)

    def send_body(self, status, body=b"", content_type="text/plain; charset=utf-8", headers=None):
        if isinstance(body, str):
            body = body.encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Powered-By", "PacketLab/1.0")
        self.send_header("X-Lab-Scope", "local-only")
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
        if username == "analyst" and password == "packetlab":
            return self.send_json(200, {"authenticated": True, "user": username})

        return self.send_json(401, {"authenticated": False, "hint": "local lab credentials only"})

    def route(self):
        path = urlsplit(self.path).path

        if path == "/":
            return self.send_body(
                200,
                page(
                    "MSFConsole Local Target",
                    "Local HTTP service for safe Metasploit auxiliary scanner practice.",
                    [
                        ("/robots.txt", "Robots file"),
                        ("/server-status", "Server status"),
                        ("/api/status", "JSON status"),
                        ("/login", "Login form"),
                        ("/admin/", "Basic auth admin"),
                    ],
                ),
                "text/html; charset=utf-8",
            )

        if path == "/health":
            return self.send_json(200, {"service": "msfconsole-lab", "status": "ok", "time": now_iso()})

        if path == "/robots.txt":
            return self.send_body(
                200,
                "User-agent: *\nDisallow: /admin/\nDisallow: /server-status\nDisallow: /private/\n",
            )

        if path == "/server-status":
            return self.send_body(
                200,
                page(
                    "Apache Server Status",
                    "Local-only status page for auxiliary scanner exercises.",
                    [("/", "Home")],
                    "<dl><dt>Server Version</dt><dd>Apache/2.4.7 (Ubuntu)</dd></dl>",
                ),
                "text/html; charset=utf-8",
            )

        if path == "/api/status":
            return self.send_json(200, {"service": "packetlab-http", "status": "ok", "scope": "local"})

        if path == "/login":
            return self.send_body(
                200,
                page(
                    "Login",
                    "Local training login form.",
                    [("/", "Home")],
                    '<form action="/login" method="post"><input name="username"><input name="password" type="password"><button>Login</button></form>',
                ),
                "text/html; charset=utf-8",
            )

        if path == "/admin/":
            if not self.is_authorized():
                return self.send_body(
                    401,
                    "admin login required\n",
                    headers={"WWW-Authenticate": 'Basic realm="msfconsole-lab-admin"'},
                )
            return self.send_json(200, {"admin": True, "scope": "local"})

        return self.send_json(404, {"error": "not found", "path": path})


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), MsfconsoleLabHandler)
    print(f"Serving msfconsole lab target on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()
