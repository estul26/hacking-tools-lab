import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


HOST = "0.0.0.0"
PORT = 8080


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


class TracerouteLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "traceroute-lab/1.0"
    sys_version = ""

    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]}:{self.client_address[1]} {fmt % args}", flush=True)

    def send_body(self, status, body=b"", content_type="text/plain; charset=utf-8"):
        if isinstance(body, str):
            body = body.encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "close")
        self.end_headers()

        if self.command != "HEAD":
            self.wfile.write(body)

    def send_json(self, status, payload):
        self.send_body(status, json_bytes(payload), "application/json; charset=utf-8")

    def do_HEAD(self):
        self.route()

    def do_GET(self):
        self.route()

    def route(self):
        path = self.path.split("?", 1)[0]
        if path == "/":
            return self.send_body(200, self.home_page(), "text/html; charset=utf-8")
        if path == "/health":
            return self.send_body(200, "ok\n")
        if path == "/api/status":
            return self.send_json(
                200,
                {
                    "service": "traceroute-lab",
                    "status": "ok",
                    "time": now_iso(),
                    "client": self.client_address[0],
                    "expected_path": [
                        "172.38.10.20",
                        "172.38.10.10",
                        "172.38.20.20",
                        "172.38.30.20",
                    ],
                },
            )

        return self.send_json(404, {"error": "not found", "path": path})

    def home_page(self):
        rows = [
            ("/api/status", "JSON status"),
            ("/health", "Plain health check"),
        ]
        links = "\n".join(
            f"<li><a href=\"{html.escape(path)}\">{html.escape(path)}</a> - {html.escape(label)}</li>"
            for path, label in rows
        )
        return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Traceroute Lab Target</title>
</head>
<body>
  <h1>Traceroute Lab Target</h1>
  <p>This HTTP service sits behind two local Docker routers.</p>
  <ul>
    {links}
  </ul>
</body>
</html>
"""


def main():
    server = ThreadingHTTPServer((HOST, PORT), TracerouteLabHandler)
    print(f"traceroute lab target listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
