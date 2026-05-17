import asyncio
import json
from datetime import datetime, timezone
from http import HTTPStatus
from urllib.parse import urlsplit


TCP_ECHO_PORT = 9001
TCP_BANNER_PORT = 9002
TCP_NOTES_PORT = 9003
UDP_ECHO_PORT = 9004
HTTP_PORT = 9080


def now_iso():
    return datetime.now(timezone.utc).isoformat()


async def read_some(reader, limit=4096, timeout=5):
    try:
        return await asyncio.wait_for(reader.read(limit), timeout)
    except asyncio.TimeoutError:
        return b""


async def read_line(reader, timeout=30):
    try:
        return await asyncio.wait_for(reader.readline(), timeout)
    except asyncio.TimeoutError:
        return b""


async def close_writer(writer):
    writer.close()
    try:
        await writer.wait_closed()
    except ConnectionError:
        pass


def peer_name(writer):
    peer = writer.get_extra_info("peername")
    if not peer:
        return "unknown"
    return f"{peer[0]}:{peer[1]}"


async def handle_echo(reader, writer):
    peer = peer_name(writer)
    print(f"tcp-echo connection from {peer}", flush=True)
    writer.write(
        b"Welcome to netcat-lab tcp-echo.\n"
        b"Send text and it will be echoed back. Send 'quit' to close.\n"
    )
    await writer.drain()

    while True:
        data = await read_line(reader, timeout=30)
        if not data:
            break
        text = data.decode("utf-8", errors="replace")
        if text.strip().lower() in {"quit", "exit"}:
            writer.write(b"bye\n")
            await writer.drain()
            break
        writer.write(b"echo: " + data)
        await writer.drain()

    await close_writer(writer)


async def handle_banner(reader, writer):
    peer = peer_name(writer)
    print(f"banner connection from {peer}", flush=True)
    banner = (
        "netcat-lab banner service\n"
        f"time: {now_iso()}\n"
        "hint: try `nc -v 127.0.0.1 19002`\n"
    )
    writer.write(banner.encode("utf-8"))
    await writer.drain()
    await read_some(reader, timeout=2)
    await close_writer(writer)


async def handle_notes(reader, writer):
    peer = peer_name(writer)
    print(f"notes connection from {peer}", flush=True)
    writer.write(
        b"netcat-lab note sink\n"
        b"Type a few lines, then close stdin with Ctrl-D or pipe data into nc.\n"
    )
    await writer.drain()
    data = await read_some(reader, limit=8192, timeout=20)
    text = data.decode("utf-8", errors="replace")
    if text:
        print(f"note from {peer}: {text!r}", flush=True)
    response = f"stored {len(data)} bytes at {now_iso()}\n"
    writer.write(response.encode("utf-8"))
    await writer.drain()
    await close_writer(writer)


def make_http_response(status, body, content_type="text/plain; charset=utf-8"):
    if isinstance(body, str):
        body = body.encode("utf-8")
    phrase = HTTPStatus(status).phrase
    headers = [
        f"HTTP/1.1 {status} {phrase}".encode("ascii"),
        b"Server: netcat-lab/1.0",
        f"Date: {now_iso()}".encode("ascii"),
        f"Content-Type: {content_type}".encode("ascii"),
        f"Content-Length: {len(body)}".encode("ascii"),
        b"Connection: close",
        b"",
        body,
    ]
    return b"\r\n".join(headers)


def route_http(path):
    if path == "/":
        return make_http_response(
            200,
            "netcat-lab raw HTTP target\ntry /health or /api/status\n",
        )
    if path == "/health":
        return make_http_response(200, "ok\n")
    if path == "/api/status":
        return make_http_response(
            200,
            json.dumps(
                {
                    "service": "netcat-lab",
                    "status": "ok",
                    "time": now_iso(),
                    "ports": {
                        "tcp_echo": 9001,
                        "tcp_banner": 9002,
                        "tcp_notes": 9003,
                        "udp_echo": 9004,
                        "http": 9080,
                    },
                },
                indent=2,
            )
            + "\n",
            "application/json; charset=utf-8",
        )
    return make_http_response(404, f"not found: {path}\n")


async def handle_http(reader, writer):
    peer = peer_name(writer)
    request = await read_some(reader, limit=4096, timeout=8)
    if not request:
        await close_writer(writer)
        return

    first_line = request.split(b"\r\n", 1)[0].decode("latin1", errors="replace")
    parts = first_line.split(" ")
    path = "/"
    if len(parts) >= 2:
        path = urlsplit(parts[1]).path or "/"
    print(f"http request from {peer}: {first_line}", flush=True)
    writer.write(route_http(path))
    await writer.drain()
    await close_writer(writer)


class UdpEchoProtocol(asyncio.DatagramProtocol):
    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        text = data.decode("utf-8", errors="replace").strip()
        print(f"udp echo from {addr[0]}:{addr[1]}: {text!r}", flush=True)
        response = f"udp-echo {now_iso()}: {text}\n".encode("utf-8")
        self.transport.sendto(response, addr)


async def start_tcp(port, handler, name):
    server = await asyncio.start_server(handler, host="0.0.0.0", port=port)
    print(f"{name} listening on tcp/{port}", flush=True)
    return server


async def main():
    servers = [
        await start_tcp(TCP_ECHO_PORT, handle_echo, "tcp-echo"),
        await start_tcp(TCP_BANNER_PORT, handle_banner, "tcp-banner"),
        await start_tcp(TCP_NOTES_PORT, handle_notes, "tcp-notes"),
        await start_tcp(HTTP_PORT, handle_http, "raw-http"),
    ]

    loop = asyncio.get_running_loop()
    transport, _ = await loop.create_datagram_endpoint(
        UdpEchoProtocol,
        local_addr=("0.0.0.0", UDP_ECHO_PORT),
    )
    print(f"udp-echo listening on udp/{UDP_ECHO_PORT}", flush=True)

    try:
        async with asyncio.TaskGroup() as group:
            for server in servers:
                group.create_task(server.serve_forever())
    finally:
        transport.close()


if __name__ == "__main__":
    asyncio.run(main())
