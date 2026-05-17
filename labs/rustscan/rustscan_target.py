import asyncio
import json
from datetime import datetime, timezone
from urllib.parse import urlsplit


HTTP_BODY = b"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>RustScan Lab Target</title>
</head>
<body>
  <h1>RustScan Lab Target</h1>
  <p>This local target exposes predictable ports for safe scan practice.</p>
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


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def http_response(status, reason, body, content_type="text/plain; charset=utf-8"):
    if isinstance(body, str):
        body = body.encode("utf-8")
    headers = [
        f"HTTP/1.1 {status} {reason}".encode("ascii"),
        b"Server: rustscan-lab/1.0",
        f"Date: {now_iso()}".encode("ascii"),
        f"Content-Type: {content_type}".encode("ascii"),
        b"Cache-Control: no-store",
        f"Content-Length: {len(body)}".encode("ascii"),
        b"Connection: close",
        b"",
        b"",
    ]
    return b"\r\n".join(headers) + body


async def handle_http(reader, writer):
    data = await read_some(reader, timeout=8)
    if not data:
        await close_writer(writer)
        return

    request_line = data.splitlines()[0].decode("ascii", errors="replace")
    parts = request_line.split()
    path = parts[1] if len(parts) >= 2 else "/"
    route = urlsplit(path).path

    if route == "/api/status":
        body = json.dumps(
            {
                "service": "rustscan-lab",
                "status": "ok",
                "time": now_iso(),
                "client": writer.get_extra_info("peername")[0],
                "open_tcp_ports": [80, 2222, 2525, 6379, 8000],
            },
            indent=2,
            sort_keys=True,
        ) + "\n"
        response = http_response(200, "OK", body, "application/json; charset=utf-8")
    else:
        response = http_response(200, "OK", HTTP_BODY, "text/html; charset=utf-8")

    writer.write(response)
    await writer.drain()
    await close_writer(writer)


async def handle_ssh(reader, writer):
    writer.write(b"SSH-2.0-OpenSSH_8.9p1 RustScanLab\r\n")
    await writer.drain()
    await read_some(reader, timeout=3)
    await close_writer(writer)


async def handle_smtp(reader, writer):
    writer.write(b"220 mail.rustscan-lab.local ESMTP LabSMTP\r\n")
    await writer.drain()
    for _ in range(5):
        line = await read_some(reader, limit=512, timeout=4)
        if not line:
            break
        command = line.upper()
        if command.startswith(b"EHLO") or command.startswith(b"HELO"):
            writer.write(
                b"250-mail.rustscan-lab.local\r\n"
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


async def handle_mysql_banner(reader, writer):
    writer.write(b"\x4a\x00\x00\x00\x0a8.0.36-rustscan-lab\x00")
    writer.write(b"abcdefgh\x00\xff\xf7\x21\x02\x00\xff\x81\x15\x00\x00\x00\x00\x00\x00")
    writer.write(b"\x00\x00\x00ijklmnopqrst\x00mysql_native_password\x00")
    await writer.drain()
    await read_some(reader, timeout=3)
    await close_writer(writer)


async def start_tcp(port, handler, name):
    server = await asyncio.start_server(handler, host="0.0.0.0", port=port)
    print(f"{name} listening on tcp/{port}", flush=True)
    return server


async def main():
    servers = [
        await start_tcp(80, handle_http, "http"),
        await start_tcp(2222, handle_ssh, "ssh-banner"),
        await start_tcp(2525, handle_smtp, "smtp-banner"),
        await start_tcp(6379, handle_redis, "redis-like"),
        await start_tcp(8000, handle_mysql_banner, "mysql-banner"),
    ]

    async with asyncio.TaskGroup() as group:
        for server in servers:
            group.create_task(server.serve_forever())


if __name__ == "__main__":
    asyncio.run(main())
