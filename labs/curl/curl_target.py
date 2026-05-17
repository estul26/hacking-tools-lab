import base64
import hashlib
import html
import json
import time
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


HOST = "0.0.0.0"
PORT = 8080
EXPECTED_AUTH = "Basic " + base64.b64encode(b"curl:packetlab").decode("ascii")
RANGE_TEXT = (
    "curl-lab range data\n"
    "0123456789 abcdefghijklmnopqrstuvwxyz\n"
    "Use curl -r to request byte ranges from this endpoint.\n"
)


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def parse_content_type(value):
    return (value or "").split(";", 1)[0].strip().lower()


class CurlLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "curl-lab/1.0"
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

    def request_context(self):
        parsed = urlsplit(self.path)
        return parsed, parse_qs(parsed.query, keep_blank_values=True)

    def do_HEAD(self):
        self.route_without_body()

    def do_GET(self):
        self.route_without_body()

    def do_OPTIONS(self):
        self.send_body(
            204,
            b"",
            headers={
                "Allow": "GET, HEAD, POST, PUT, OPTIONS",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, HEAD, POST, PUT, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Lab-Trace",
            },
        )

    def do_POST(self):
        self.route_with_body()

    def do_PUT(self):
        self.route_with_body()

    def route_without_body(self):
        parsed, query = self.request_context()
        path = parsed.path

        if path == "/":
            return self.send_body(200, self.home_page(), "text/html; charset=utf-8")
        if path == "/health":
            return self.send_body(200, "ok\n")
        if path == "/api/status":
            return self.send_json(200, self.status_payload(query))
        if path == "/api/headers":
            return self.send_json(200, {"headers": dict(self.headers), "time": now_iso()})
        if path == "/api/query":
            return self.send_json(200, {"query": query, "raw_query": parsed.query})
        if path == "/redirect":
            return self.redirect("/api/status?from=redirect")
        if path == "/redirect-chain/1":
            return self.redirect("/redirect-chain/2")
        if path == "/redirect-chain/2":
            return self.redirect("/api/status?from=redirect-chain")
        if path == "/cookies/set":
            return self.send_json(
                200,
                {"message": "cookie set", "next": "/cookies/check"},
                headers={"Set-Cookie": "curl_lab_session=packetlab; HttpOnly; SameSite=Lax"},
            )
        if path == "/cookies/check":
            cookie = self.headers.get("Cookie", "")
            return self.send_json(
                200,
                {
                    "cookie_header": cookie,
                    "has_lab_cookie": "curl_lab_session=packetlab" in cookie,
                },
            )
        if path == "/auth/basic":
            return self.basic_auth()
        if path == "/download/report.txt":
            return self.download_report()
        if path == "/range/data.txt":
            return self.range_response()
        if path == "/slow":
            seconds = min(float(query.get("seconds", ["2"])[0] or "2"), 10.0)
            time.sleep(seconds)
            return self.send_json(200, {"slept_seconds": seconds, "time": now_iso()})
        if path.startswith("/status/"):
            return self.status_response(path)

        return self.send_json(404, {"error": "not found", "path": path})

    def route_with_body(self):
        parsed, _query = self.request_context()
        path = parsed.path
        body = self.read_body()
        content_type = parse_content_type(self.headers.get("Content-Type", ""))

        if path == "/forms":
            form = parse_qs(body.decode("utf-8", errors="replace"), keep_blank_values=True)
            return self.send_json(200, {"form": form, "content_type": content_type})
        if path == "/api/echo":
            return self.echo_body(body, content_type)
        if path == "/upload":
            digest = hashlib.sha256(body).hexdigest()
            return self.send_json(
                200,
                {
                    "method": self.command,
                    "bytes_received": len(body),
                    "sha256": digest,
                    "content_type": content_type,
                    "preview": body[:120].decode("utf-8", errors="replace"),
                },
            )

        return self.send_json(404, {"error": "not found", "path": path})

    def home_page(self):
        rows = [
            ("/api/status", "JSON status"),
            ("/api/headers", "Echo request headers"),
            ("/api/query?name=curl&mode=lab", "Query-string parsing"),
            ("/redirect", "Single redirect"),
            ("/redirect-chain/1", "Redirect chain"),
            ("/cookies/set", "Set a cookie"),
            ("/auth/basic", "HTTP Basic auth"),
            ("/download/report.txt", "Text download"),
            ("/range/data.txt", "Byte range target"),
            ("/slow?seconds=2", "Timeout practice"),
        ]
        links = "\n".join(
            f"<li><a href=\"{html.escape(path)}\">{html.escape(path)}</a> - {html.escape(label)}</li>"
            for path, label in rows
        )
        return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Curl Lab Target</title>
</head>
<body>
  <h1>Curl Lab Target</h1>
  <p>Use this localhost target to practice curl requests safely.</p>
  <ul>
    {links}
  </ul>
</body>
</html>
"""

    def status_payload(self, query):
        return {
            "service": "curl-lab",
            "status": "ok",
            "time": now_iso(),
            "method": self.command,
            "path": urlsplit(self.path).path,
            "query": query,
            "client": self.client_address[0],
        }

    def redirect(self, location):
        self.send_body(
            302,
            "found\n",
            headers={"Location": location},
        )

    def basic_auth(self):
        if self.headers.get("Authorization") == EXPECTED_AUTH:
            return self.send_json(200, {"authenticated": True, "user": "curl"})
        self.send_json(
            401,
            {"authenticated": False, "hint": "try curl -u curl:packetlab"},
            headers={"WWW-Authenticate": 'Basic realm="curl-lab"'},
        )

    def download_report(self):
        report = (
            "Curl Lab Report\n"
            f"Generated: {now_iso()}\n"
            "Scope: 127.0.0.1 only\n"
            "Use -OJ or -o to save this file with curl.\n"
        )
        self.send_body(
            200,
            report,
            headers={"Content-Disposition": 'attachment; filename="curl-lab-report.txt"'},
        )

    def range_response(self):
        data = RANGE_TEXT.encode("utf-8")
        range_header = self.headers.get("Range", "")
        if not range_header:
            return self.send_body(200, data)
        if not range_header.startswith("bytes="):
            return self.send_body(416, "unsupported range\n")

        start_text, _, end_text = range_header.removeprefix("bytes=").partition("-")
        try:
            start = int(start_text) if start_text else 0
            end = int(end_text) if end_text else len(data) - 1
        except ValueError:
            return self.send_body(416, "invalid range\n")

        if start < 0 or end < start or start >= len(data):
            return self.send_body(416, "range not satisfiable\n")

        end = min(end, len(data) - 1)
        chunk = data[start : end + 1]
        self.send_body(
            206,
            chunk,
            headers={
                "Accept-Ranges": "bytes",
                "Content-Range": f"bytes {start}-{end}/{len(data)}",
            },
        )

    def status_response(self, path):
        _, _, code_text = path.rpartition("/")
        try:
            code = int(code_text)
        except ValueError:
            code = 400
        if code < 100 or code > 599:
            code = 400
        phrase = HTTPStatus(code).phrase if code in HTTPStatus._value2member_map_ else "Custom Status"
        self.send_json(code, {"status": code, "phrase": phrase})

    def echo_body(self, body, content_type):
        if content_type == "application/json":
            try:
                parsed = json.loads(body.decode("utf-8"))
            except json.JSONDecodeError as exc:
                return self.send_json(400, {"error": "invalid json", "detail": str(exc)})
            return self.send_json(200, {"json": parsed, "bytes_received": len(body)})

        return self.send_json(
            200,
            {
                "content_type": content_type,
                "bytes_received": len(body),
                "body": body.decode("utf-8", errors="replace"),
            },
        )


def main():
    server = ThreadingHTTPServer((HOST, PORT), CurlLabHandler)
    print(f"curl target listening on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
