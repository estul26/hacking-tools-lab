import base64
import html
import json
import socket
import socketserver
import struct
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


HTTP_HOST = "0.0.0.0"
HTTP_PORT = 8080
DNS_HOST = "0.0.0.0"
DNS_PORT = 53
TARGET_IP = "172.43.130.20"
BASE_DOMAIN = "gobuster.lab"
NORMAL_HOSTS = {
    "target",
    "target:8080",
    "gobuster.lab",
    "gobuster.lab:8080",
    "127.0.0.1",
    "127.0.0.1:18089",
    "localhost",
    "localhost:18089",
}
VALID_VHOSTS = {
    "admin.gobuster.lab": ("Admin Console", "Restricted admin virtual host"),
    "api.gobuster.lab": ("API Gateway", "JSON API virtual host"),
    "dev.gobuster.lab": ("Developer Preview", "Development virtual host"),
    "staging.gobuster.lab": ("Staging Site", "Staging virtual host"),
}
DNS_A_RECORDS = {
    "admin.gobuster.lab": TARGET_IP,
    "api.gobuster.lab": TARGET_IP,
    "dev.gobuster.lab": TARGET_IP,
    "staging.gobuster.lab": TARGET_IP,
}
FILES = {
    "/files/config.txt": ("text/plain; charset=utf-8", b"mode=lab\nowner=gobuster\n"),
    "/files/config.json": (
        "application/json; charset=utf-8",
        json.dumps({"mode": "lab", "owner": "gobuster"}, indent=2, sort_keys=True).encode("utf-8") + b"\n",
    ),
    "/files/report.html": (
        "text/html; charset=utf-8",
        b"<!doctype html><title>Gobuster Report</title><h1>Local report</h1>\n",
    ),
    "/files/notes.txt": (
        "text/plain; charset=utf-8",
        b"gobuster lab notes\ntry dir, dns, vhost, and fuzz modes\n",
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


def decode_dns_name(packet, offset):
    labels = []

    while offset < len(packet):
        length = packet[offset]
        offset += 1

        if length == 0:
            break
        if length & 0xC0:
            return "", offset
        if offset + length > len(packet):
            return "", offset

        labels.append(packet[offset : offset + length].decode("ascii", errors="ignore"))
        offset += length

    return ".".join(labels).lower().rstrip("."), offset


class GobusterDnsHandler(socketserver.BaseRequestHandler):
    def handle(self):
        packet, sock = self.request
        if len(packet) < 12:
            return

        request_id, _, question_count, _, _, _ = struct.unpack("!HHHHHH", packet[:12])
        if question_count < 1:
            return

        qname, offset = decode_dns_name(packet, 12)
        if not qname or offset + 4 > len(packet):
            return

        question = packet[12 : offset + 4]
        qtype, qclass = struct.unpack("!HH", packet[offset : offset + 4])
        answer_ip = DNS_A_RECORDS.get(qname)
        answer = b""
        response_code = 0

        if answer_ip and qtype == 1 and qclass == 1:
            answer = (
                b"\xc0\x0c"
                + struct.pack("!HHIH", 1, 1, 60, 4)
                + socket.inet_aton(answer_ip)
            )
        elif answer_ip:
            response_code = 0
        else:
            response_code = 3

        flags = 0x8180 if response_code == 0 else 0x8183
        answer_count = 1 if answer else 0
        response = (
            struct.pack("!HHHHHH", request_id, flags, question_count, answer_count, 0, 0)
            + question
            + answer
        )
        sock.sendto(response, self.client_address)


class ThreadingUdpServer(socketserver.ThreadingMixIn, socketserver.UDPServer):
    allow_reuse_address = True


class GobusterLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "gobuster-lab/1.0"
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

        if host_name.endswith(f".{BASE_DOMAIN}"):
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
                    "service": "gobuster-lab",
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
                headers={"WWW-Authenticate": 'Basic realm="gobuster-lab-admin"'},
            )
        if path == "/backup":
            return self.send_body(403, "backup area exists but is forbidden\n")
        if path == "/private":
            return self.send_body(403, "private area exists but is forbidden\n")
        if path == "/dev":
            return self.send_body(200, basic_page("Developer Area", "Local development notes."))
        if path == "/debug":
            return self.send_json(200, {"debug": True, "trace": "gobuster-lab"})
        if path == "/portal":
            return self.send_body(200, basic_page("Partner Portal", "Local portal page."))
        if path == "/login":
            return self.send_body(200, self.login_form(), "text/html; charset=utf-8")
        if path == "/files":
            return self.send_body(200, basic_page("Files", "Try extension discovery under /files."))
        if path in FILES:
            content_type, body = FILES[path]
            return self.send_body(200, body, content_type)
        if path.startswith("/tokens/"):
            return self.token_response(path.rsplit("/", 1)[-1])
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
            token = base64.b64encode(b"gobuster-lab-session").decode("ascii")
            return self.send_json(
                200,
                {"authenticated": True, "user": username},
                headers={"Set-Cookie": f"gobuster_lab_session={token}; HttpOnly; SameSite=Lax"},
            )

        return self.send_json(401, {"authenticated": False, "hint": "try another password"})

    def route_vhost(self, host_name):
        if host_name not in VALID_VHOSTS:
            return self.send_body(404, "virtual host not found\n")

        title, body = VALID_VHOSTS[host_name]
        if host_name == "api.gobuster.lab":
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

    def token_response(self, token):
        if token == "packetlab":
            return self.send_json(200, {"token": token, "valid": True})
        return self.send_json(404, {"token": token, "valid": False})

    def home_page(self):
        rows = [
            ("/api/status", "JSON status"),
            ("/health", "Health check"),
            ("/login", "Login form"),
            ("/search?q=gobuster", "Search endpoint"),
            ("/tokens/packetlab", "Token fuzzing endpoint"),
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
  <title>Gobuster Lab Target</title>
</head>
<body>
  <h1>Gobuster Lab Target</h1>
  <p>Use this local web app and DNS responder to practice gobuster safely.</p>
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
  <title>Gobuster Login</title>
</head>
<body>
  <h1>Gobuster Login</h1>
  <form method="post" action="/login">
    <label>Username <input name="username"></label>
    <label>Password <input name="password" type="password"></label>
    <button type="submit">Sign in</button>
  </form>
</body>
</html>
"""


def run_dns_server():
    server = ThreadingUdpServer((DNS_HOST, DNS_PORT), GobusterDnsHandler)
    print(f"gobuster lab DNS listening on {DNS_HOST}:{DNS_PORT}/udp", flush=True)
    server.serve_forever()


def main():
    dns_thread = threading.Thread(target=run_dns_server, daemon=True)
    dns_thread.start()

    server = ThreadingHTTPServer((HTTP_HOST, HTTP_PORT), GobusterLabHandler)
    print(f"gobuster lab HTTP target listening on {HTTP_HOST}:{HTTP_PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
