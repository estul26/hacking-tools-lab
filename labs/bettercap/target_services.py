#!/usr/bin/env python3
import json
import socket
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    server_version = "PacketlabBettercapHTTP/1.0"

    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)

    def do_GET(self):
        body = json.dumps(
            {
                "service": "bettercap-local-target",
                "path": self.path,
                "host": socket.gethostname(),
            },
            indent=2,
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def tcp_banner(port, banner):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", port))
    server.listen(8)
    while True:
        conn, _ = server.accept()
        with conn:
            conn.sendall(banner)


def start_http(port):
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "web"
    threads = []
    if mode == "web":
        specs = [
            (start_http, (80,)),
            (start_http, (8080,)),
        ]
    else:
        specs = [
            (tcp_banner, (2222, b"SSH-2.0-Packetlab_Bettercap_Target\r\n")),
            (tcp_banner, (2525, b"220 packetlab.local ESMTP Bettercap Lab\r\n")),
        ]
    for target, args in specs:
        thread = threading.Thread(target=target, args=args, daemon=True)
        thread.start()
        threads.append(thread)
    for thread in threads:
        thread.join()


if __name__ == "__main__":
    main()
