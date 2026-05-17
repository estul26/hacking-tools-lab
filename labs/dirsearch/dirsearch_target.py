import base64
import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


HOST = "0.0.0.0"
PORT = 8080
EXPECTED_AUTH = "Basic " + base64.b64encode(b"dirsearch:packetlab").decode("ascii")
FILES = {
    "/files/config.txt": ("text/plain; charset=utf-8", b"mode=lab\nowner=dirsearch\n"),
    "/files/config.json": (
        "application/json; charset=utf-8",
        json.dumps({"mode": "lab", "owner": "dirsearch"}, indent=2, sort_keys=True).encode("utf-8") + b"\n",
    ),
    "/files/report.html": (
        "text/html; charset=utf-8",
        b"<!doctype html><title>Dirsearch Report</title><h1>Local report</h1>\n",
    ),
    "/files/notes.txt": (
        "text/plain; charset=utf-8",
        b"dirsearch lab notes\ntry extensions, recursion, filters, and auth\n",
    ),
    "/assets/app.js": (
        "application/javascript; charset=utf-8",
        b"console.log('dirsearch lab');\n",
    ),
    "/assets/style.css": (
        "text/css; charset=utf-8",
        b"body { font-family: system-ui, sans-serif; }\n",
    ),
}


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def basic_page(title, body):
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{html.escape(title)}</title>
</head>
<body>
  <h1>{html.escape(title)}</h1>
  <p>{html.escape(body)}</p>
</body>
</html>
"""


class DirsearchLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "dirsearch-lab/1.0"
    sys_version = ""

    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]}:{self.client_address[1]} {fmt % args}", flush=True)

    def send_body(self, status, body=b"", content_type="text/plain; charset=utf-8", headers=None):
        if isinstance(body, str):
            body = body.encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "close")
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()

        if self.command != "HEAD":
            self.wfile.write(body)

    def send_json(self, status, payload, headers=None):
        self.send_body(status, json_bytes(payload), "application/json; charset=utf-8", headers)

    def is_authorized(self):
        return self.headers.get("Authorization") == EXPECTED_AUTH

    def do_HEAD(self):
        self.route()

    def do_GET(self):
        self.route()

    def route(self):
        path = urlsplit(self.path).path

        if path == "/":
            return self.send_body(200, self.home_page(), "text/html; charset=utf-8")
        if path == "/health":
            return self.send_body(200, "ok\n")
        if path == "/status":
            return self.send_json(200, {"status": "ok", "hint": "try /api/status"})
        if path == "/api/status":
            return self.send_json(
                200,
                {
                    "service": "dirsearch-lab",
                    "status": "ok",
                    "time": now_iso(),
                    "method": self.command,
                    "client": self.client_address[0],
                },
            )
        if path == "/backup":
            return self.send_body(403, "backup area exists but is forbidden\n")
        if path == "/private":
            return self.send_body(403, "private area exists but is forbidden\n")
        if path == "/dev":
            return self.send_body(200, basic_page("Developer Area", "Local development notes."))
        if path == "/debug":
            return self.send_json(200, {"debug": True, "trace": "dirsearch-lab"})
        if path == "/portal":
            return self.send_body(200, basic_page("Partner Portal", "Local portal page."))
        if path == "/login":
            return self.send_body(200, self.login_form(), "text/html; charset=utf-8")
        if path == "/files":
            return self.send_body(200, basic_page("Files", "Try extension discovery under /files."))
        if path == "/assets":
            return self.send_body(200, basic_page("Assets", "Try app.js and style.css."))
        if path == "/docs":
            return self.redirect("/docs/")
        if path == "/docs/":
            return self.send_body(200, basic_page("Docs", "Try /docs/api and /docs/reference."))
        if path == "/docs/api":
            return self.send_body(200, basic_page("API Docs", "Local API documentation."))
        if path == "/docs/reference":
            return self.send_body(200, basic_page("Reference", "Local reference documentation."))
        if path == "/api":
            return self.redirect("/api/")
        if path == "/api/":
            return self.send_json(200, {"endpoints": ["/api/status", "/api/users", "/api/v1/status"]})
        if path == "/api/users":
            return self.send_json(200, {"users": ["alice", "bob"], "scope": "local"})
        if path == "/api/v1":
            return self.redirect("/api/v1/")
        if path == "/api/v1/":
            return self.send_json(200, {"version": "v1", "endpoints": ["/api/v1/status"]})
        if path == "/api/v1/status":
            return self.send_json(200, {"api": "v1", "status": "ok"})
        if path.startswith("/admin"):
            return self.admin_response(path)
        if path in FILES:
            content_type, body = FILES[path]
            return self.send_body(200, body, content_type)

        return self.send_json(404, {"error": "not found", "path": path})

    def redirect(self, location):
        return self.send_body(301, "moved\n", headers={"Location": location})

    def admin_response(self, path):
        if not self.is_authorized():
            return self.send_body(
                401,
                "admin login required\n",
                headers={"WWW-Authenticate": 'Basic realm="dirsearch-lab-admin"'},
            )

        if path == "/admin":
            return self.send_body(200, basic_page("Admin", "Authenticated admin landing page."))
        if path == "/admin/panel":
            return self.send_json(200, {"admin": True, "panel": "local"})
        if path == "/admin/logs":
            return self.send_body(200, "local admin log index\n")
        if path == "/admin/users":
            return self.send_json(200, {"users": ["alice", "bob"], "role": "admin"})
        if path == "/admin/backup":
            return self.send_body(403, "authenticated but still forbidden\n")

        return self.send_json(404, {"error": "admin path not found", "path": path})

    def home_page(self):
        rows = [
            ("/api/status", "JSON status"),
            ("/api/", "Recursive API area"),
            ("/docs/", "Recursive docs area"),
            ("/login", "Login form"),
            ("/files/config.txt", "Known text file"),
            ("/assets/app.js", "Known JavaScript asset"),
            ("/admin", "Basic auth, dirsearch / packetlab"),
        ]
        links = "\n".join(
            f"<li><a href=\"{html.escape(path)}\">{html.escape(path)}</a> - {html.escape(label)}</li>"
            for path, label in rows
        )
        return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Dirsearch Lab Target</title>
</head>
<body>
  <h1>Dirsearch Lab Target</h1>
  <p>Use this local web app to practice dirsearch safely.</p>
  <ul>
    {links}
  </ul>
</body>
</html>
"""

    def login_form(self):
        return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Dirsearch Login</title>
</head>
<body>
  <h1>Dirsearch Login</h1>
  <form method="post" action="/login">
    <label>Username <input name="username"></label>
    <label>Password <input name="password" type="password"></label>
    <button type="submit">Sign in</button>
  </form>
</body>
</html>
"""


def main():
    server = ThreadingHTTPServer((HOST, PORT), DirsearchLabHandler)
    print(f"dirsearch lab target listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
