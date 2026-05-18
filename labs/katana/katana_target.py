import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


HOST = "0.0.0.0"
PORT = 8080


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
  <script src="/assets/app.js" defer></script>
</head>
<body>
  <h1>{html.escape(title)}</h1>
  <p>{html.escape(body)}</p>
  <ul>{nav}</ul>
  {extra}
</body>
</html>
"""


class KatanaLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "KatanaLab/1.0"
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

    def do_POST(self):
        self.route()

    def route(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)

        if parsed.path == "/health":
            return self.send_json(200, {"service": "katana-lab", "status": "ok", "time": now_iso()})

        if parsed.path == "/robots.txt":
            return self.send_body(200, "User-agent: *\nDisallow: /admin\nSitemap: /sitemap.xml\n")

        if parsed.path == "/sitemap.xml":
            return self.send_body(
                200,
                """<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>http://172.56.60.20:8080/about</loc></url>
  <url><loc>http://172.56.60.20:8080/products/widget</loc></url>
  <url><loc>http://172.56.60.20:8080/contact</loc></url>
</urlset>
""",
                "application/xml; charset=utf-8",
            )

        if parsed.path == "/assets/app.js":
            return self.send_body(
                200,
                """
fetch('/api/v1/status');
fetch('/api/v1/users?id=1');
const exportUrl = '/products/export?format=json';
const debugUrl = '/debug/vars';
""",
                "application/javascript; charset=utf-8",
            )

        if parsed.path == "/":
            return self.send_body(
                200,
                page(
                    "Packetlab",
                    "Local crawler target.",
                    [
                        ("/about", "About"),
                        ("/products", "Products"),
                        ("/login", "Login"),
                        ("/search?q=packet", "Search"),
                        ("/robots.txt", "Robots"),
                    ],
                    '<form action="/search" method="get"><input name="q" value="packet"><button>Search</button></form>',
                ),
                "text/html; charset=utf-8",
            )

        if parsed.path == "/about":
            return self.send_body(
                200,
                page("About", "About this local lab.", [("/contact", "Contact"), ("/team", "Team")]),
                "text/html; charset=utf-8",
            )

        if parsed.path == "/contact":
            return self.send_body(200, page("Contact", "Contact form.", [("/api/v1/status", "Status API")]), "text/html; charset=utf-8")

        if parsed.path == "/team":
            return self.send_body(200, page("Team", "People and roles.", [("/login", "Login")]), "text/html; charset=utf-8")

        if parsed.path == "/products":
            return self.send_body(
                200,
                page("Products", "Catalog.", [("/products/widget", "Widget"), ("/products/export?format=json", "Export")]),
                "text/html; charset=utf-8",
            )

        if parsed.path == "/products/widget":
            return self.send_body(200, page("Widget", "Product detail.", [("/download?file=widget.pdf", "Download")]), "text/html; charset=utf-8")

        if parsed.path == "/products/export":
            return self.send_json(200, {"format": query.get("format", ["json"])[0], "status": "ok"})

        if parsed.path == "/download":
            return self.send_body(200, f"download={query.get('file', [''])[0]}\n")

        if parsed.path == "/search":
            return self.send_body(200, page("Search", f"Query: {query.get('q', [''])[0]}", [("/api/v1/search?q=packet", "Search API")]), "text/html; charset=utf-8")

        if parsed.path == "/login":
            return self.send_body(
                200,
                page("Login", "Authentication surface.", [], '<form action="/session" method="post"><input name="username"><input name="password" type="password"><button>Login</button></form>'),
                "text/html; charset=utf-8",
            )

        if parsed.path == "/session":
            return self.send_json(401, {"error": "invalid credentials"})

        if parsed.path == "/admin":
            return self.send_body(401, "admin login required\n", headers={"WWW-Authenticate": 'Basic realm="katana-lab-admin"'})

        if parsed.path == "/debug/vars":
            return self.send_json(403, {"error": "debug access denied"})

        if parsed.path == "/api/v1/status":
            return self.send_json(200, {"status": "ok"})

        if parsed.path == "/api/v1/users":
            return self.send_json(200, {"id": query.get("id", [""])[0], "name": "Lin"})

        if parsed.path == "/api/v1/search":
            return self.send_json(200, {"q": query.get("q", [""])[0], "results": []})

        return self.send_json(404, {"error": "not found", "path": parsed.path})


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), KatanaLabHandler)
    print(f"Serving katana lab target on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()
