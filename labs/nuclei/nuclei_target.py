import base64
import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


HOST = "0.0.0.0"
PORT = 8080
EXPECTED_AUTH = "Basic " + base64.b64encode(b"nuclei:packetlab").decode("ascii")


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
</head>
<body>
  <h1>{html.escape(title)}</h1>
  <p>{html.escape(body)}</p>{link_items}
</body>
</html>
"""


class NucleiLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "NucleiLab/0.1"
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
        self.send_header("X-Powered-By", "NucleiLab/0.1")
        self.send_header("X-Lab-Scope", "local-only")
        if cookie:
            self.send_header("Set-Cookie", "nuclei_lab=local-session; Path=/")
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
            return self.send_json(200, {"authenticated": True, "user": username, "role": "lab-admin"})

        return self.send_json(401, {"authenticated": False, "hint": "try admin / packetlab"})

    def route(self):
        path = urlsplit(self.path).path

        if path == "/":
            return self.send_body(200, self.home_page(), "text/html; charset=utf-8", cookie=True)
        if path == "/health":
            return self.send_json(200, {"status": "ok", "service": "nuclei-lab"})
        if path == "/api/status":
            return self.send_json(
                200,
                {
                    "service": "nuclei-lab",
                    "status": "ok",
                    "time": now_iso(),
                    "client": self.client_address[0],
                },
            )
        if path == "/debug":
            return self.send_json(
                200,
                {
                    "debug": True,
                    "environment": "local-lab",
                    "feature_flags": ["preview-admin", "verbose-errors"],
                    "secret_hint": "training-only",
                },
            )
        if path == "/backup/config.json":
            return self.send_json(
                200,
                {
                    "database": "packetlab",
                    "db_user": "nuclei_lab",
                    "db_password": "local-only-password",
                    "scope": "training",
                },
            )
        if path == "/.env":
            return self.send_body(
                200,
                "APP_ENV=local\nAPP_DEBUG=true\nNUCLEI_LAB_TOKEN=local-training-token\n",
            )
        if path == "/admin/":
            return self.admin_response()
        if path == "/login":
            return self.send_body(200, self.login_form(), "text/html; charset=utf-8", cookie=True)

        return self.send_json(404, {"error": "not found", "path": path})

    def admin_response(self):
        if not self.is_authorized():
            return self.send_body(
                401,
                "admin login required\n",
                headers={"WWW-Authenticate": 'Basic realm="nuclei-lab-admin"'},
            )

        return self.send_json(200, {"admin": True, "scope": "local", "tool": "nuclei"})

    def home_page(self):
        return page(
            "Nuclei Local Lab",
            "A local-only target with deterministic signals for nuclei templates.",
            [
                ("/health", "Health JSON"),
                ("/api/status", "Status API"),
                ("/debug", "Debug API"),
                ("/backup/config.json", "Backup Config"),
                ("/.env", "Environment File"),
                ("/admin/", "Basic Auth Admin"),
                ("/login", "Login Form"),
            ],
        )

    def login_form(self):
        return """<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Login</title></head>
<body>
  <h1>Login</h1>
  <form method="post" action="/login">
    <label>Username <input name="username"></label>
    <label>Password <input name="password" type="password"></label>
    <button type="submit">Sign in</button>
  </form>
</body>
</html>
"""


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), NucleiLabHandler)
    print(f"Serving nuclei lab target on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()
