import base64
import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


HOST = "0.0.0.0"
PORT = 8080
EXPECTED_AUTH = "Basic " + base64.b64encode(b"nikto:packetlab").decode("ascii")

STATIC_FILES = {
    "/backup.tar.gz": (
        "application/gzip",
        b"local nikto lab backup placeholder\n",
    ),
    "/config.inc.php~": (
        "text/plain; charset=utf-8",
        b"<?php\n$db_user = 'local_lab';\n$db_password = 'packetlab-only';\n",
    ),
    "/crossdomain.xml": (
        "application/xml; charset=utf-8",
        b'<?xml version="1.0"?><cross-domain-policy><allow-access-from domain="*" /></cross-domain-policy>\n',
    ),
    "/icons/README": (
        "text/plain; charset=utf-8",
        b"Apache icons directory README placeholder for local Nikto practice.\n",
    ),
    "/phpinfo.php": (
        "text/html; charset=utf-8",
        b"<!doctype html><title>phpinfo()</title><h1>PHP Version 5.6.40</h1>\n",
    ),
    "/readme.html": (
        "text/html; charset=utf-8",
        b"<!doctype html><title>Readme</title><h1>Local lab readme</h1>\n",
    ),
    "/test.php": (
        "text/html; charset=utf-8",
        b"<!doctype html><title>Test Page</title><h1>Local test page</h1>\n",
    ),
    "/web.config": (
        "text/xml; charset=utf-8",
        b"<configuration><appSettings><add key=\"mode\" value=\"local-lab\" /></appSettings></configuration>\n",
    ),
    "/.git/HEAD": (
        "text/plain; charset=utf-8",
        b"ref: refs/heads/main\n",
    ),
}


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def page(title, body, links=None):
    link_items = ""
    if links:
        link_items = "\n  <ul>\n"
        for path, label in links:
            link_items += f"    <li><a href=\"{html.escape(path)}\">{html.escape(label)}</a></li>\n"
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


class NiktoLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "Apache/2.4.7"
    sys_version = "(Ubuntu)"

    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]}:{self.client_address[1]} {fmt % args}", flush=True)

    def send_body(self, status, body=b"", content_type="text/plain; charset=utf-8", headers=None, cookie=False):
        if isinstance(body, str):
            body = body.encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Powered-By", "PHP/5.6.40")
        if cookie:
            self.send_header("Set-Cookie", "nikto_lab=local-session; Path=/")
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
            return self.send_json(200, {"authenticated": True, "user": username})

        return self.send_json(401, {"authenticated": False, "hint": "try admin / packetlab"})

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Allow", "GET, HEAD, POST, OPTIONS, TRACE")
        self.send_header("Content-Length", "0")
        self.send_header("X-Powered-By", "PHP/5.6.40")
        self.send_header("Connection", "close")
        self.end_headers()

    def do_TRACE(self):
        lines = [self.requestline]
        for name, value in self.headers.items():
            lines.append(f"{name}: {value}")
        body = "\r\n".join(lines).encode("utf-8") + b"\r\n"
        self.send_body(200, body, "message/http")

    def route(self):
        path = urlsplit(self.path).path

        if path == "/":
            return self.send_body(200, self.home_page(), "text/html; charset=utf-8", cookie=True)
        if path == "/health":
            return self.send_body(200, "ok\n")
        if path == "/api/status":
            return self.send_json(
                200,
                {
                    "service": "nikto-lab",
                    "status": "ok",
                    "time": now_iso(),
                    "method": self.command,
                    "client": self.client_address[0],
                },
            )
        if path == "/robots.txt":
            return self.send_body(200, self.robots_txt())
        if path == "/server-status":
            return self.send_body(200, self.server_status(), "text/html; charset=utf-8")
        if path == "/backup/":
            return self.send_body(200, self.directory_listing("/backup/"), "text/html; charset=utf-8")
        if path == "/admin/":
            return self.admin_response()
        if path == "/login":
            return self.send_body(200, self.login_form(), "text/html; charset=utf-8", cookie=True)
        if path in STATIC_FILES:
            content_type, body = STATIC_FILES[path]
            return self.send_body(200, body, content_type)

        return self.send_json(404, {"error": "not found", "path": path})

    def admin_response(self):
        if not self.is_authorized():
            return self.send_body(
                401,
                "admin login required\n",
                headers={"WWW-Authenticate": 'Basic realm="nikto-lab-admin"'},
            )

        return self.send_json(200, {"admin": True, "scope": "local", "tool": "nikto"})

    def robots_txt(self):
        return """User-agent: *
Disallow: /admin/
Disallow: /backup/
Disallow: /phpinfo.php
Disallow: /.git/
"""

    def directory_listing(self, path):
        rows = [
            ("../", "Parent Directory"),
            ("backup.tar.gz", "backup.tar.gz"),
            ("config.inc.php~", "config.inc.php~"),
            ("notes.txt", "notes.txt"),
        ]
        links = "\n".join(
            f'<li><a href="{html.escape(name)}">{html.escape(label)}</a></li>'
            for name, label in rows
        )
        return f"""<!doctype html>
<html lang="en">
<head><title>Index of {html.escape(path)}</title></head>
<body>
<h1>Index of {html.escape(path)}</h1>
<ul>
{links}
</ul>
</body>
</html>
"""

    def server_status(self):
        return """<!doctype html>
<html lang="en">
<head><title>Apache Server Status for localhost</title></head>
<body>
<h1>Apache Server Status for localhost</h1>
<dl>
  <dt>Server Version</dt><dd>Apache/2.4.7 (Ubuntu) PHP/5.6.40</dd>
  <dt>Server MPM</dt><dd>prefork</dd>
  <dt>Local Scope</dt><dd>Docker-only training target</dd>
</dl>
</body>
</html>
"""

    def home_page(self):
        links = [
            ("/robots.txt", "Robots file with local-only disallowed paths"),
            ("/backup/", "Directory listing example"),
            ("/server-status", "Server status page"),
            ("/phpinfo.php", "PHP information page"),
            ("/config.inc.php~", "Backup configuration file"),
            ("/.git/HEAD", "Exposed Git metadata sample"),
            ("/login", "Login form"),
            ("/api/status", "JSON status"),
        ]
        return page(
            "Nikto Lab Target",
            "Use this local web app to practice Nikto safely against known findings.",
            links,
        )

    def login_form(self):
        return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Nikto Lab Login</title>
</head>
<body>
  <h1>Nikto Lab Login</h1>
  <form method="post" action="/login">
    <label>Username <input name="username"></label>
    <label>Password <input name="password" type="password"></label>
    <button type="submit">Sign in</button>
  </form>
</body>
</html>
"""


def main():
    server = ThreadingHTTPServer((HOST, PORT), NiktoLabHandler)
    print(f"Nikto lab target listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
