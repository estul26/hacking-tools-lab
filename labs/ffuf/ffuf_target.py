import base64
import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


HOST = "0.0.0.0"
PORT = 8080
NORMAL_HOSTS = {"target", "target:8080", "127.0.0.1", "127.0.0.1:18088", "localhost", "localhost:18088"}
VALID_VHOSTS = {
    "admin.ffuf.lab": ("Admin Console", "Restricted admin virtual host"),
    "api.ffuf.lab": ("API Gateway", "JSON API virtual host"),
    "dev.ffuf.lab": ("Developer Preview", "Development virtual host"),
}
FILES = {
    "/files/config.txt": ("text/plain; charset=utf-8", b"mode=lab\nowner=ffuf\n"),
    "/files/config.json": (
        "application/json; charset=utf-8",
        json.dumps({"mode": "lab", "owner": "ffuf"}, indent=2, sort_keys=True).encode("utf-8") + b"\n",
    ),
    "/files/report.html": (
        "text/html; charset=utf-8",
        b"<!doctype html><title>FFUF Report</title><h1>Local report</h1>\n",
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


class FfufLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "ffuf-lab/1.0"
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

    def read_body(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length <= 0:
            return b""
        return self.rfile.read(length)

    def normalized_host(self):
        return (self.headers.get("Host", "") or "").strip().lower()

    def do_HEAD(self):
        self.route_without_body()

    def do_GET(self):
        self.route_without_body()

    def do_POST(self):
        self.route_with_body()

    def route_without_body(self):
        host = self.normalized_host()
        host_name = host.split(":", 1)[0]
        parsed = urlsplit(self.path)
        path = parsed.path

        if host_name.endswith(".ffuf.lab"):
            return self.route_vhost(host_name)

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
                    "service": "ffuf-lab",
                    "status": "ok",
                    "time": now_iso(),
                    "client": self.client_address[0],
                    "host": host,
                },
            )
        if path == "/admin":
            return self.send_body(
                401,
                "admin login required\n",
                headers={"WWW-Authenticate": 'Basic realm="ffuf-lab-admin"'},
            )
        if path == "/backup":
            return self.send_body(403, "backup area exists but is forbidden\n")
        if path == "/private":
            return self.send_body(403, "private area exists but is forbidden\n")
        if path == "/dev":
            return self.send_body(200, basic_page("Developer Area", "Local development notes."))
        if path == "/debug":
            return self.send_json(200, {"debug": True, "trace": "ffuf-lab"})
        if path == "/portal":
            return self.send_body(200, basic_page("Partner Portal", "Local portal page."))
        if path == "/login":
            return self.send_body(200, self.login_form(), "text/html; charset=utf-8")
        if path in FILES:
            content_type, body = FILES[path]
            return self.send_body(200, body, content_type)
        if path == "/search":
            return self.search_response(parse_qs(parsed.query, keep_blank_values=True))

        return self.send_body(404, "not found\n")

    def route_with_body(self):
        parsed = urlsplit(self.path)
        if parsed.path != "/login":
            return self.send_json(404, {"error": "not found", "path": parsed.path})

        body = self.read_body().decode("utf-8", errors="replace")
        form = parse_qs(body, keep_blank_values=True)
        username = form.get("username", [""])[0]
        password = form.get("password", [""])[0]

        if username == "admin" and password == "packetlab":
            token = base64.b64encode(b"ffuf-lab-session").decode("ascii")
            return self.send_json(
                200,
                {"authenticated": True, "user": username},
                headers={"Set-Cookie": f"ffuf_lab_session={token}; HttpOnly; SameSite=Lax"},
            )

        return self.send_json(401, {"authenticated": False, "hint": "try another password"})

    def route_vhost(self, host_name):
        if host_name not in VALID_VHOSTS:
            return self.send_body(404, "virtual host not found\n")

        title, body = VALID_VHOSTS[host_name]
        if host_name == "api.ffuf.lab":
            return self.send_json(200, {"vhost": host_name, "service": "api", "status": "ok"})
        return self.send_body(200, basic_page(title, body), "text/html; charset=utf-8")

    def search_response(self, query):
        if "q" in query:
            return self.send_json(200, {"mode": "search", "q": query["q"]})
        if "query" in query:
            return self.send_json(200, {"mode": "legacy-search", "query": query["query"]})
        if "debug" in query:
            return self.send_json(200, {"mode": "debug", "enabled": query["debug"]})
        return self.send_json(400, {"error": "missing searchable parameter"})

    def home_page(self):
        rows = [
            ("/api/status", "JSON status"),
            ("/health", "Health check"),
            ("/login", "Login form"),
            ("/search?q=ffuf", "Search endpoint"),
            ("/files/config.txt", "Known file target"),
        ]
        links = "\n".join(
            f"<li><a href=\"{html.escape(path)}\">{html.escape(path)}</a> - {html.escape(label)}</li>"
            for path, label in rows
        )
        return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>FFUF Lab Target</title>
</head>
<body>
  <h1>FFUF Lab Target</h1>
  <p>Use this local web app to practice ffuf safely.</p>
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
  <title>FFUF Login</title>
</head>
<body>
  <h1>FFUF Login</h1>
  <form method="post" action="/login">
    <label>Username <input name="username"></label>
    <label>Password <input name="password" type="password"></label>
    <button type="submit">Sign in</button>
  </form>
</body>
</html>
"""


def main():
    server = ThreadingHTTPServer((HOST, PORT), FfufLabHandler)
    print(f"ffuf lab target listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
