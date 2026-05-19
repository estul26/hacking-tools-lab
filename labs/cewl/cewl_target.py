import html
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse


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
  <meta name="description" content="Packetbridge research notes for local CeWL practice">
  <meta name="keywords" content="packetbridge, blueharbor, sensorboard, trailmap2026">
  <link rel="stylesheet" href="/assets/style.css">
</head>
<body>
  <h1>{html.escape(title)}</h1>
  <main>
    {body}
    <nav><ul>{nav}</ul></nav>
    {extra}
  </main>
</body>
</html>
"""


class CeWLLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "CeWLLab/1.0"
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

    def send_json(self, status, payload):
        self.send_body(status, json_bytes(payload), "application/json; charset=utf-8")

    def do_HEAD(self):
        self.route()

    def do_GET(self):
        self.route()

    def route(self):
        parsed = urlparse(self.path)

        if parsed.path == "/health":
            return self.send_json(200, {"service": "cewl-lab", "status": "ok", "time": now_iso()})

        if parsed.path == "/robots.txt":
            return self.send_body(200, "User-agent: *\nDisallow: /private\nDisallow: /debug\n")

        if parsed.path == "/assets/style.css":
            return self.send_body(200, "body { font-family: sans-serif; }\n", "text/css; charset=utf-8")

        if parsed.path == "/":
            return self.send_body(
                200,
                page(
                    "Packetbridge Field Notes",
                    """
                    <p>Packetbridge is a local training portal for wordlist generation,
                    blueharbor planning, sensorboard reviews, lighthouse recovery, and
                    calibration workshops.</p>
                    <p>The operations team tracks trailmap2026 milestones, beaconfield
                    procedures, archivekeeper notes, and weatherproof field manuals.</p>
                    <p>Contact <a href="mailto:training@packetlab.example">training@packetlab.example</a>
                    for scheduled exercises.</p>
                    """,
                    [
                        ("/about", "About Packetbridge"),
                        ("/projects", "Projects"),
                        ("/team", "Team"),
                        ("/private", "Private"),
                    ],
                ),
                "text/html; charset=utf-8",
            )

        if parsed.path == "/about":
            return self.send_body(
                200,
                page(
                    "About Packetbridge",
                    """
                    <p>Packetbridge documents authorized assessment language for local
                    labs. Analysts practice discovery, collection, normalization,
                    deduplication, and evidence handling.</p>
                    <p>Recurring terms include packetbridge, fieldnotes, blueharbor,
                    sensorboard, and lighthouse.</p>
                    """,
                    [("/projects", "Projects"), ("/contact", "Contact")],
                ),
                "text/html; charset=utf-8",
            )

        if parsed.path == "/projects":
            return self.send_body(
                200,
                page(
                    "Research Projects",
                    """
                    <p>The beaconfield project studies resilient radio rooms, backup
                    checklists, calibration windows, packetbridge dashboards, and
                    trailmap2026 release notes.</p>
                    <p>The blueharbor project studies shoreline gateways, fieldnotes,
                    sensorboard telemetry, and lighthouse maintenance.</p>
                    """,
                    [("/team", "Team"), ("/contact", "Contact")],
                ),
                "text/html; charset=utf-8",
            )

        if parsed.path == "/team":
            return self.send_body(
                200,
                page(
                    "Team Directory",
                    """
                    <p>Local-only contacts include Mara Fielding, Noel Harbor, and Lin
                    Beacon. Mailboxes include
                    <a href="mailto:training@packetlab.example">training@packetlab.example</a>
                    and <a href="mailto:ops-team@packetlab.example">ops-team@packetlab.example</a>.</p>
                    <p>Team notes mention archivekeeper, fieldnotes, beaconfield,
                    blueharbor, and calibration.</p>
                    """,
                    [("/contact", "Contact")],
                ),
                "text/html; charset=utf-8",
            )

        if parsed.path == "/contact":
            return self.send_body(
                200,
                page(
                    "Contact",
                    """
                    <p>Use <a href="mailto:training@packetlab.example">training@packetlab.example</a>
                    for exercises and
                    <a href="mailto:ops-team@packetlab.example">ops-team@packetlab.example</a>
                    for local lab operations. The demo aliases are not real internet
                    mailboxes.</p>
                    """,
                    [("/", "Home")],
                ),
                "text/html; charset=utf-8",
            )

        if parsed.path == "/private":
            return self.send_body(
                200,
                page(
                    "Private Draft",
                    """
                    <p>This excluded path contains noiseword, draftphrase, and
                    hiddenphrase. The helper excludes this route so scoped output can be
                    compared with an unrestricted spider.</p>
                    """,
                    [("/", "Home")],
                ),
                "text/html; charset=utf-8",
            )

        if parsed.path == "/debug":
            return self.send_json(403, {"error": "debug access denied"})

        return self.send_json(404, {"error": "not found", "path": parsed.path})


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), CeWLLabHandler)
    print(f"Serving CeWL lab target on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()
