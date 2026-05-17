import asyncio
import sys
from datetime import datetime, timezone


HTTP_BODY = b"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Nmap Lab Target</title>
</head>
<body>
  <h1>Nmap Lab Target</h1>
  <p>This is an intentionally exposed local training service.</p>
</body>
</html>
"""


async def read_some(reader, limit=2048, timeout=2):
    try:
        return await asyncio.wait_for(reader.read(limit), timeout)
    except asyncio.TimeoutError:
        return b""


async def close_writer(writer):
    writer.close()
    try:
        await writer.wait_closed()
    except ConnectionError:
        pass


async def handle_http(reader, writer):
    data = await read_some(reader, timeout=8)
    if not data:
        await close_writer(writer)
        return

    headers = [
        b"HTTP/1.1 200 OK",
        b"Server: Apache/2.4.58 (Ubuntu)",
        b"Content-Type: text/html; charset=utf-8",
        b"Content-Length: " + str(len(HTTP_BODY)).encode("ascii"),
        b"Connection: close",
        b"",
        b"",
    ]
    writer.write(b"\r\n".join(headers) + HTTP_BODY)
    await writer.drain()
    await close_writer(writer)


async def handle_ssh(reader, writer):
    writer.write(b"SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.1\r\n")
    await writer.drain()
    await read_some(reader, timeout=3)
    await close_writer(writer)


async def handle_smtp(reader, writer):
    writer.write(b"220 mail.nmap-lab.local ESMTP Postfix\r\n")
    await writer.drain()
    for _ in range(5):
        line = await read_some(reader, limit=512, timeout=4)
        if not line:
            break
        command = line.upper()
        if command.startswith(b"EHLO") or command.startswith(b"HELO"):
            writer.write(
                b"250-mail.nmap-lab.local\r\n"
                b"250-PIPELINING\r\n"
                b"250-SIZE 10240000\r\n"
                b"250 HELP\r\n"
            )
        elif command.startswith(b"QUIT"):
            writer.write(b"221 Bye\r\n")
            await writer.drain()
            break
        else:
            writer.write(b"250 OK\r\n")
        await writer.drain()
    await close_writer(writer)


async def handle_redis(reader, writer):
    data = await read_some(reader, limit=1024, timeout=4)
    command = data.upper()
    if b"PING" in command:
        writer.write(b"+PONG\r\n")
    elif b"INFO" in command:
        info = b"redis_version:7.2.0\r\nrole:master\r\n"
        writer.write(b"$" + str(len(info)).encode("ascii") + b"\r\n" + info + b"\r\n")
    else:
        writer.write(b"-NOAUTH Authentication required.\r\n")
    await writer.drain()
    await close_writer(writer)


class UdpLabProtocol(asyncio.DatagramProtocol):
    def datagram_received(self, data, addr):
        now = datetime.now(timezone.utc).isoformat()
        response = f"nmap-lab udp service 5353 {now}\n".encode("ascii")
        self.transport.sendto(response, addr)

    def connection_made(self, transport):
        self.transport = transport


async def start_tcp(port, handler, name):
    server = await asyncio.start_server(handler, host="0.0.0.0", port=port)
    print(f"{name} listening on tcp/{port}", flush=True)
    return server


async def run_web():
    server = await start_tcp(80, handle_http, "web")
    async with server:
        await server.serve_forever()


async def run_services():
    servers = [
        await start_tcp(2222, handle_ssh, "ssh-banner"),
        await start_tcp(2525, handle_smtp, "smtp-banner"),
        await start_tcp(6379, handle_redis, "redis-like"),
        await start_tcp(8000, handle_http, "http-alt"),
    ]
    loop = asyncio.get_running_loop()
    transport, _ = await loop.create_datagram_endpoint(
        UdpLabProtocol,
        local_addr=("0.0.0.0", 5353),
    )
    print("udp-service listening on udp/5353", flush=True)

    try:
        async with asyncio.TaskGroup() as group:
            for server in servers:
                group.create_task(server.serve_forever())
    finally:
        transport.close()


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "web"
    if mode == "web":
        asyncio.run(run_web())
    elif mode == "services":
        asyncio.run(run_services())
    else:
        raise SystemExit(f"unknown mode: {mode}")


if __name__ == "__main__":
    main()
