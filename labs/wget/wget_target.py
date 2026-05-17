import base64
import hashlib
import html
import json
from datetime import datetime, timezone
from email.utils import format_datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


HOST = "0.0.0.0"
PORT = 8080
EXPECTED_AUTH = "Basic " + base64.b64encode(b"wget:packetlab").decode("ascii")
LAST_MODIFIED = format_datetime(datetime(2026, 5, 17, 12, 0, tzinfo=timezone.utc), usegmt=True)
REPORT_TEXT = (
    "Wget Lab Report\n"
    "Scope: 127.0.0.1 only\n"
    "Use wget -O, -N, -c, --recursive, and --user/--password against this lab.\n"
)
DATA_TEXT = (
    "alpha,beta,gamma\n"
    "1,2,3\n"
    "4,5,6\n"
)
BIG_DATA = (b"wget-lab-block-" + bytes(range(32))) * 4096


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def etag_for(data):
    return '"' + hashlib.sha256(data).hexdigest()[:16] + '"'


class WgetLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "wget-lab/1.0"
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
        if path == "/api/status":
            return self.send_json(
                200,
                {
                    "service": "wget-lab",
                    "status": "ok",
                    "time": now_iso(),
                    "method": self.command,
                    "client": self.client_address[0],
                },
            )
        if path == "/robots.txt":
            return self.send_body(200, "User-agent: *\nDisallow: /private\n")
        if path == "/mirror/" or path == "/mirror/index.html":
            return self.send_body(200, self.mirror_index(), "text/html; charset=utf-8")
        if path == "/mirror/page1.html":
            return self.send_body(200, self.page_one(), "text/html; charset=utf-8")
        if path == "/mirror/page2.html":
            return self.send_body(200, self.page_two(), "text/html; charset=utf-8")
        if path == "/assets/style.css":
            return self.send_body(200, "body { font-family: system-ui, sans-serif; }\n", "text/css")
        if path == "/assets/info.txt":
            return self.static_file(DATA_TEXT.encode("utf-8"), "text/plain; charset=utf-8", "info.txt")
        if path == "/files/report.txt":
            return self.static_file(REPORT_TEXT.encode("utf-8"), "text/plain; charset=utf-8", "wget-lab-report.txt")
        if path == "/files/data.csv":
            return self.static_file(DATA_TEXT.encode("utf-8"), "text/csv; charset=utf-8", "data.csv")
        if path == "/files/big.bin":
            return self.range_file(BIG_DATA, "application/octet-stream", "big.bin")
        if path == "/redirect/report":
            return self.redirect("/files/report.txt")
        if path == "/auth/basic":
            return self.basic_auth()
        if path == "/private/secret.txt":
            return self.send_body(200, "This path is disallowed by robots.txt for recursive practice.\n")
        if path.startswith("/status/"):
            return self.status_response(path)

        return self.send_json(404, {"error": "not found", "path": path})

    def home_page(self):
        links = [
            ("/api/status", "JSON status"),
            ("/files/report.txt", "Text report"),
            ("/files/data.csv", "CSV data"),
            ("/files/big.bin", "Large binary for resume practice"),
            ("/redirect/report", "Redirect to report"),
            ("/auth/basic", "Basic auth, wget / packetlab"),
            ("/mirror/", "Small mirror site"),
            ("/robots.txt", "Robots rules"),
            ("/private/secret.txt", "Robots-disallowed path"),
        ]
        items = "\n".join(
            f"<li><a href=\"{html.escape(path)}\">{html.escape(path)}</a> - {html.escape(label)}</li>"
            for path, label in links
        )
        return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Wget Lab Target</title>
  <link rel="stylesheet" href="/assets/style.css">
</head>
<body>
  <h1>Wget Lab Target</h1>
  <p>Use this localhost target to practice wget safely.</p>
  <ul>
    {items}
  </ul>
</body>
</html>
"""

    def mirror_index(self):
        return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Mirror Index</title>
  <link rel="stylesheet" href="/assets/style.css">
</head>
<body>
  <h1>Mirror Index</h1>
  <a href="/mirror/page1.html">Page one</a>
  <a href="/mirror/page2.html">Page two</a>
  <a href="/assets/info.txt">Info text</a>
  <a href="/private/secret.txt">Robots-disallowed file</a>
</body>
</html>
"""

    def page_one(self):
        return """<!doctype html>
<html lang="en"><body><h1>Page One</h1><a href="/mirror/page2.html">Page two</a></body></html>
"""

    def page_two(self):
        return """<!doctype html>
<html lang="en"><body><h1>Page Two</h1><a href="/files/report.txt">Report</a></body></html>
"""

    def redirect(self, location):
        self.send_body(302, "found\n", headers={"Location": location})

    def static_file(self, data, content_type, filename):
        if self.headers.get("If-Modified-Since"):
            self.send_response(304)
            self.send_header("Connection", "close")
            self.end_headers()
            return

        self.send_body(
            200,
            data,
            content_type,
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"',
                "ETag": etag_for(data),
                "Last-Modified": LAST_MODIFIED,
            },
        )

    def range_file(self, data, content_type, filename):
        headers = {
            "Accept-Ranges": "bytes",
            "Content-Disposition": f'attachment; filename="{filename}"',
            "ETag": etag_for(data),
            "Last-Modified": LAST_MODIFIED,
        }
        range_header = self.headers.get("Range")
        if not range_header:
            return self.send_body(200, data, content_type, headers=headers)
        if not range_header.startswith("bytes="):
            return self.send_body(416, "unsupported range\n")

        start_text, _, end_text = range_header.removeprefix("bytes=").partition("-")
        try:
            start = int(start_text) if start_text else 0
            end = int(end_text) if end_text else len(data) - 1
        except ValueError:
            return self.send_body(416, "invalid range\n")

        if start < 0 or start >= len(data) or end < start:
            return self.send_body(416, "range not satisfiable\n")

        end = min(end, len(data) - 1)
        chunk = data[start : end + 1]
        headers["Content-Range"] = f"bytes {start}-{end}/{len(data)}"
        self.send_body(206, chunk, content_type, headers=headers)

    def basic_auth(self):
        if self.headers.get("Authorization") == EXPECTED_AUTH:
            return self.send_body(200, "authenticated download\n")
        self.send_body(
            401,
            "authentication required\n",
            headers={"WWW-Authenticate": 'Basic realm="wget-lab"'},
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


def main():
    server = ThreadingHTTPServer((HOST, PORT), WgetLabHandler)
    print(f"wget target listening on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
