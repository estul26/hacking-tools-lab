import asyncio
import socket
import struct
from datetime import datetime, timezone


HTTP_BODY = b"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Wireshark Lab Target</title>
</head>
<body>
  <h1>Wireshark Lab Target</h1>
  <p>This local service exists to generate safe, inspectable packet captures.</p>
</body>
</html>
"""

LAB_IP = "172.31.20.20"


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

    now = datetime.now(timezone.utc).isoformat().encode("ascii")
    body = HTTP_BODY + b"\n<!-- generated-at: " + now + b" -->\n"
    headers = [
        b"HTTP/1.1 200 OK",
        b"Server: wireshark-lab/1.0",
        b"Content-Type: text/html; charset=utf-8",
        b"Cache-Control: no-store",
        b"Content-Length: " + str(len(body)).encode("ascii"),
        b"Connection: close",
        b"",
        b"",
    ]
    writer.write(b"\r\n".join(headers) + body)
    await writer.drain()
    await close_writer(writer)


async def handle_smtp(reader, writer):
    writer.write(b"220 mail.wireshark-lab.local ESMTP LabSMTP\r\n")
    await writer.drain()
    for _ in range(5):
        line = await read_some(reader, limit=512, timeout=4)
        if not line:
            break
        command = line.upper()
        if command.startswith(b"EHLO") or command.startswith(b"HELO"):
            writer.write(
                b"250-mail.wireshark-lab.local\r\n"
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


def build_dns_response(query):
    if len(query) < 12:
        return b""

    offset = 12
    while offset < len(query):
        label_length = query[offset]
        offset += 1
        if label_length == 0:
            break
        offset += label_length
    else:
        return b""

    if offset + 4 > len(query):
        return b""

    question = query[12 : offset + 4]
    header = (
        query[:2]
        + b"\x81\x80"
        + b"\x00\x01"
        + b"\x00\x01"
        + b"\x00\x00"
        + b"\x00\x00"
    )
    answer = (
        b"\xc0\x0c"
        + b"\x00\x01"
        + b"\x00\x01"
        + struct.pack("!I", 30)
        + b"\x00\x04"
        + socket.inet_aton(LAB_IP)
    )
    return header + question + answer


class DnsLabProtocol(asyncio.DatagramProtocol):
    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        response = build_dns_response(data)
        if response:
            self.transport.sendto(response, addr)


async def start_tcp(port, handler, name):
    server = await asyncio.start_server(handler, host="0.0.0.0", port=port)
    print(f"{name} listening on tcp/{port}", flush=True)
    return server


async def main():
    servers = [
        await start_tcp(8080, handle_http, "http"),
        await start_tcp(2525, handle_smtp, "smtp-banner"),
        await start_tcp(6379, handle_redis, "redis-like"),
    ]
    loop = asyncio.get_running_loop()
    transport, _ = await loop.create_datagram_endpoint(
        DnsLabProtocol,
        local_addr=("0.0.0.0", 5300),
    )
    print("dns-like service listening on udp/5300", flush=True)

    try:
        async with asyncio.TaskGroup() as group:
            for server in servers:
                group.create_task(server.serve_forever())
    finally:
        transport.close()


if __name__ == "__main__":
    asyncio.run(main())
