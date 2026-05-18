import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


HOST = "0.0.0.0"
PORT = 8080

HOSTS = {
    "www.packetlab.local": ("Public Site", "hello@packetlab.local"),
    "api.packetlab.local": ("API", "api-team@packetlab.local"),
    "admin.packetlab.local": ("Admin", "admin@packetlab.local"),
    "dev.packetlab.local": ("Dev", "dev-team@packetlab.local"),
    "mail.packetlab.local": ("Mail", "postmaster@packetlab.local"),
    "status.packetlab.local": ("Status", "status@packetlab.local"),
}


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def page(title, contact):
    safe_title = html.escape(title)
    safe_contact = html.escape(contact)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{safe_title}</title>
</head>
<body>
  <h1>{safe_title}</h1>
  <p>Contact: <a href="mailto:{safe_contact}">{safe_contact}</a></p>
</body>
</html>
"""


class TheHarvesterLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "TheHarvesterLab/1.0"
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
        if self.path == "/health":
            return self.send_json(200, {"service": "theharvester-lab", "status": "ok", "time": now_iso()})

        if host in HOSTS:
            title, contact = HOSTS[host]
            if host == "api.packetlab.local":
                return self.send_json(200, {"contact": contact, "host": host, "service": "api"})
            if host == "admin.packetlab.local":
                return self.send_body(
                    401,
                    "admin login required\n",
                    headers={"WWW-Authenticate": 'Basic realm="theharvester-lab-admin"'},
                )
            return self.send_body(200, page(title, contact), "text/html; charset=utf-8")

        return self.send_json(404, {"error": "unknown host", "host": host})


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), TheHarvesterLabHandler)
    print(f"Serving theHarvester lab target on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()
