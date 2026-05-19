import base64
import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs


HOST = "0.0.0.0"
PORT = 8080
VALID_USERNAME = "admin"
VALID_PASSWORD = "packetlab"


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def page(title, body, extra=""):
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{html.escape(title)}</title>
</head>
<body>
  <h1>{html.escape(title)}</h1>
  <p>{html.escape(body)}</p>
  {extra}
</body>
</html>
"""


class HydraLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "HydraLab/1.0"
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

    def read_form(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        parsed = parse_qs(body)
        return {key: values[0] if values else "" for key, values in parsed.items()}

    def basic_credentials(self):
        header = self.headers.get("Authorization", "")
        prefix = "Basic "
        if not header.startswith(prefix):
            return "", ""
        try:
            decoded = base64.b64decode(header[len(prefix) :], validate=True).decode("utf-8")
        except Exception:
            return "", ""
        username, separator, password = decoded.partition(":")
        if not separator:
            return "", ""
        return username, password

    def is_valid(self, username, password):
        return username == VALID_USERNAME and password == VALID_PASSWORD

    def do_HEAD(self):
        self.route()

    def do_GET(self):
        self.route()

    def do_POST(self):
        self.route()

    def route(self):
        if self.path == "/health":
            return self.send_json(200, {"service": "hydra-lab", "status": "ok", "time": now_iso()})

        if self.path == "/":
            return self.send_body(
                200,
                page(
                    "Hydra Lab",
                    "Local-only authentication target.",
                    '<ul><li><a href="/basic">Basic auth</a></li><li><a href="/login">Login form</a></li></ul>',
                ),
                "text/html; charset=utf-8",
            )

        if self.path == "/basic":
            username, password = self.basic_credentials()
            if self.is_valid(username, password):
                return self.send_body(200, "Welcome to the local basic auth area\n")
            return self.send_body(
                401,
                "Unauthorized\n",
                headers={"WWW-Authenticate": 'Basic realm="hydra-lab-basic"'},
            )

        if self.path == "/login" and self.command == "GET":
            return self.send_body(
                200,
                page(
                    "Login",
                    "Submit local lab credentials.",
                    '<form method="post" action="/login"><input name="username"><input name="password" type="password"><button>Login</button></form>',
                ),
                "text/html; charset=utf-8",
            )

        if self.path == "/login" and self.command == "POST":
            form = self.read_form()
            username = form.get("username", "")
            password = form.get("password", "")
            if self.is_valid(username, password):
                return self.send_body(200, "Welcome admin, local form login succeeded\n")
            return self.send_body(200, "Invalid login\n")

        return self.send_json(404, {"error": "not found", "path": self.path})


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), HydraLabHandler)
    print(f"Serving hydra lab target on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()
