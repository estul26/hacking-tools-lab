import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


HOST = "0.0.0.0"
PORT = 8080

HOSTS = {
    "www.packetlab.local": "public",
    "api.packetlab.local": "api",
    "admin.packetlab.local": "admin",
    "static.packetlab.local": "static",
}


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def html_page(title, body):
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


class WaybackurlsLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "WaybackurlsLab/1.0"
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
        self.send_header("X-Lab-Scope", "local-only")
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.send_header("Connection", "close")
        self.end_headers()

        if self.command != "HEAD":
            self.wfile.write(body)

    def send_json(self, status, payload, headers=None):
        self.send_body(status, json_bytes(payload), "application/json; charset=utf-8", headers)

    def do_HEAD(self):
        self.route()

    def do_GET(self):
        self.route()

    def route(self):
        host = self.headers.get("Host", "").split(":", 1)[0].lower()
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)

        if parsed.path == "/health":
            return self.send_json(200, {"service": "waybackurls-lab", "status": "ok", "time": now_iso()})

        if host not in HOSTS:
            return self.send_json(404, {"error": "unknown host", "host": host})

        if host == "api.packetlab.local":
            if parsed.path == "/api/v1/users":
                return self.send_json(200, {"id": query.get("id", [""])[0], "name": "Ada"})
            if parsed.path == "/api/v1/search":
                return self.send_json(200, {"q": query.get("q", [""])[0], "results": []})

        if host == "admin.packetlab.local":
            if parsed.path == "/admin":
                return self.send_body(
                    401,
                    "admin login required\n",
                    headers={"WWW-Authenticate": 'Basic realm="waybackurls-lab-admin"'},
                )
            if parsed.path == "/backup/config.json":
                return self.send_json(403, {"error": "backup access denied"})

        if host == "static.packetlab.local" and parsed.path == "/static/app.js":
            return self.send_body(200, "console.log('packetlab');\n", "application/javascript; charset=utf-8")

        if host == "www.packetlab.local":
            if parsed.path in ("/", "/index.html"):
                return self.send_body(200, html_page("Packetlab", "Archived public landing page."), "text/html; charset=utf-8")
            if parsed.path == "/login":
                return self.send_body(200, html_page("Login", "Archived login route."), "text/html; charset=utf-8")
            if parsed.path == "/search":
                return self.send_body(200, html_page("Search", f"Query: {query.get('q', [''])[0]}"), "text/html; charset=utf-8")

        return self.send_json(404, {"error": "unknown archived path", "host": host, "path": parsed.path})


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), WaybackurlsLabHandler)
    print(f"Serving waybackurls lab target on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()
