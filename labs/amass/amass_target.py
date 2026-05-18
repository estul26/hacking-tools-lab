import html
import json
import socket
import struct
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


DNS_HOST = "0.0.0.0"
DNS_PORT = 53
HTTP_HOST = "0.0.0.0"
HTTP_PORT = 8080
LAB_IP = "172.52.220.20"
DOMAIN = "packetlab.local"

HOSTS = {
    "www.packetlab.local": ("Public Site", "Public web surface discovered by Amass brute forcing."),
    "api.packetlab.local": ("API", "API surface discovered by Amass brute forcing."),
    "admin.packetlab.local": ("Admin", "Admin surface discovered by Amass brute forcing."),
    "dev.packetlab.local": ("Dev", "Development surface discovered by Amass brute forcing."),
    "vpn.packetlab.local": ("VPN", "Remote access surface discovered by Amass brute forcing."),
    "mail.packetlab.local": ("Mail", "Mail surface discovered by Amass brute forcing."),
    "status.packetlab.local": ("Status", "Status surface discovered by Amass brute forcing."),
}


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def page(title, body):
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


def parse_qname(packet, offset=12):
    labels = []
    while True:
        length = packet[offset]
        offset += 1
        if length == 0:
            break
        labels.append(packet[offset : offset + length].decode("ascii", errors="ignore"))
        offset += length
    return ".".join(labels).lower(), offset


def dns_response(query):
    if len(query) < 12:
        return b""

    transaction_id = query[:2]
    qname, offset = parse_qname(query)
    if offset + 4 > len(query):
        return b""

    question = query[12 : offset + 4]
    qtype, _qclass = struct.unpack("!HH", query[offset : offset + 4])
    exists = qname in HOSTS or qname == DOMAIN
    is_a_query = qtype in (1, 255)

    flags = b"\x81\x80" if exists and is_a_query else b"\x81\x83"
    qdcount = b"\x00\x01"
    ancount = b"\x00\x01" if exists and is_a_query else b"\x00\x00"
    header = transaction_id + flags + qdcount + ancount + b"\x00\x00\x00\x00"

    if not (exists and is_a_query):
        return header + question

    answer = (
        b"\xc0\x0c"
        + struct.pack("!HHI", 1, 1, 60)
        + struct.pack("!H", 4)
        + socket.inet_aton(LAB_IP)
    )
    return header + question + answer


def udp_dns_server():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((DNS_HOST, DNS_PORT))
    print(f"Serving DNS on udp://{DNS_HOST}:{DNS_PORT}", flush=True)
    while True:
        data, addr = sock.recvfrom(512)
        response = dns_response(data)
        if response:
            sock.sendto(response, addr)


def tcp_dns_server():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((DNS_HOST, DNS_PORT))
    sock.listen(20)
    print(f"Serving DNS on tcp://{DNS_HOST}:{DNS_PORT}", flush=True)
    while True:
        conn, _addr = sock.accept()
        with conn:
            length_data = conn.recv(2)
            if len(length_data) != 2:
                continue
            length = struct.unpack("!H", length_data)[0]
            query = conn.recv(length)
            response = dns_response(query)
            if response:
                conn.sendall(struct.pack("!H", len(response)) + response)


class AmassLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "AmassLab/1.0"
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
            return self.send_json(200, {"service": "amass-lab", "status": "ok", "time": now_iso()})

        if host in HOSTS:
            title, body = HOSTS[host]
            if host == "api.packetlab.local":
                return self.send_json(200, {"host": host, "service": "api", "status": "ok"})
            if host == "admin.packetlab.local":
                return self.send_body(
                    401,
                    "admin login required\n",
                    headers={"WWW-Authenticate": 'Basic realm="amass-lab-admin"'},
                )
            return self.send_body(200, page(title, body), "text/html; charset=utf-8")

        return self.send_json(404, {"error": "unknown host", "host": host})


def http_server():
    server = ThreadingHTTPServer((HTTP_HOST, HTTP_PORT), AmassLabHandler)
    print(f"Serving HTTP on http://{HTTP_HOST}:{HTTP_PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    threading.Thread(target=udp_dns_server, daemon=True).start()
    threading.Thread(target=tcp_dns_server, daemon=True).start()
    http_server()
