import asyncio
import html
import json
import socket
import struct
from datetime import datetime, timezone
from http import HTTPStatus
from urllib.parse import parse_qs, quote, unquote, urlsplit


LAB_IP = "172.32.30.20"
WEB_PORT = 8080

USERS = [
    {"id": 1, "username": "analyst", "role": "blue-team"},
    {"id": 2, "username": "operator", "role": "helpdesk"},
    {"id": 3, "username": "auditor", "role": "readonly"},
]

ORDERS = [
    {"id": "ORD-1001", "owner": "analyst", "status": "queued"},
    {"id": "ORD-1002", "owner": "operator", "status": "shipped"},
    {"id": "ORD-1003", "owner": "analyst", "status": "review"},
]


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


def status_line(status):
    phrase = HTTPStatus(status).phrase
    return f"HTTP/1.1 {status} {phrase}".encode("ascii")


def make_response(status, body, content_type="text/html; charset=utf-8", headers=None):
    if isinstance(body, str):
        body = body.encode("utf-8")
    response_headers = [
        status_line(status),
        b"Server: local-target-lab/1.0",
        f"Date: {now_iso()}".encode("ascii"),
        f"Content-Type: {content_type}".encode("ascii"),
        f"Content-Length: {len(body)}".encode("ascii"),
        b"Connection: close",
        b"Cache-Control: no-store",
    ]
    for name, value in (headers or {}).items():
        response_headers.append(f"{name}: {value}".encode("utf-8"))
    return b"\r\n".join(response_headers + [b"", body])


def json_response(status, payload, headers=None):
    body = json.dumps(payload, indent=2).encode("utf-8")
    return make_response(status, body, "application/json; charset=utf-8", headers)


def redirect(location):
    return make_response(
        302,
        "<h1>Found</h1>",
        headers={"Location": location},
    )


def parse_headers(raw_headers):
    headers = {}
    for line in raw_headers.split(b"\r\n"):
        if b":" not in line:
            continue
        name, value = line.split(b":", 1)
        headers[name.decode("latin1").strip().lower()] = value.decode("latin1").strip()
    return headers


async def read_http_request(reader):
    raw = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=8)
    head, _, rest = raw.partition(b"\r\n\r\n")
    lines = head.split(b"\r\n")
    method, target, version = lines[0].decode("latin1").split(" ", 2)
    headers = parse_headers(b"\r\n".join(lines[1:]))
    content_length = int(headers.get("content-length", "0") or "0")
    body = rest
    if len(body) < content_length:
        body += await asyncio.wait_for(reader.readexactly(content_length - len(body)), timeout=8)
    return method, target, version, headers, body


def layout(title, body):
    escaped_title = html.escape(title)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{escaped_title}</title>
  <style>
    body {{ font-family: system-ui, sans-serif; margin: 2rem; line-height: 1.45; color: #17202a; }}
    main {{ max-width: 920px; }}
    code, pre {{ background: #f4f6f7; border-radius: 4px; padding: 0.12rem 0.25rem; }}
    table {{ border-collapse: collapse; margin-top: 1rem; }}
    th, td {{ border: 1px solid #d5d8dc; padding: 0.4rem 0.6rem; text-align: left; }}
    nav a {{ margin-right: 1rem; }}
    input, button {{ font: inherit; margin: 0.2rem 0; padding: 0.35rem 0.5rem; }}
  </style>
</head>
<body>
<main>
  <nav>
    <a href="/">home</a>
    <a href="/login">login</a>
    <a href="/api/status">api status</a>
    <a href="/debug/headers">headers</a>
  </nav>
  {body}
</main>
</body>
</html>
"""


def home_page():
    return layout(
        "Local Target Lab",
        f"""
<h1>Local Target Lab</h1>
<p>This is a host-reachable training target bound to <code>127.0.0.1</code>.</p>
<table>
  <tr><th>Service</th><th>Host endpoint</th><th>What to inspect</th></tr>
  <tr><td>HTTP</td><td><code>http://127.0.0.1:8088</code></td><td>Requests, headers, JSON, redirects</td></tr>
  <tr><td>SSH-like banner</td><td><code>127.0.0.1:2222</code></td><td>TCP handshake and service banner</td></tr>
  <tr><td>SMTP-like banner</td><td><code>127.0.0.1:2525</code></td><td>Text protocol exchange</td></tr>
  <tr><td>Redis-like service</td><td><code>127.0.0.1:16379</code></td><td>RESP request and response</td></tr>
  <tr><td>DNS-like UDP</td><td><code>127.0.0.1:5300</code></td><td>UDP query and answer</td></tr>
</table>
<h2>Useful paths</h2>
<ul>
  <li><a href="/api/status">/api/status</a></li>
  <li><a href="/api/users">/api/users</a></li>
  <li><a href="/api/orders?owner=analyst">/api/orders?owner=analyst</a></li>
  <li><a href="/search?q=packet">/search?q=packet</a></li>
  <li><a href="/redirect">/redirect</a></li>
  <li><a href="/download/report.txt">/download/report.txt</a></li>
  <li><a href="/robots.txt">/robots.txt</a></li>
</ul>
<p>Generated at <code>{now_iso()}</code>.</p>
""",
    )


def login_page(message=""):
    message_html = f"<p><strong>{html.escape(message)}</strong></p>" if message else ""
    return layout(
        "Local Target Login",
        f"""
<h1>Login</h1>
{message_html}
<form method="post" action="/login">
  <label>Username<br><input name="username" autocomplete="username"></label><br>
  <label>Password<br><input name="password" type="password" autocomplete="current-password"></label><br>
  <button type="submit">Sign in</button>
</form>
<p>Lab credentials: <code>analyst</code> / <code>packetlab</code></p>
""",
    )


def route_http(method, target, headers, body):
    parsed = urlsplit(target)
    path = unquote(parsed.path)
    query = parse_qs(parsed.query)

    print(f"http {method} {path} from {headers.get('host', 'unknown-host')}", flush=True)

    if path == "/":
        return make_response(200, home_page())
    if path == "/health":
        return make_response(200, "ok\n", "text/plain; charset=utf-8")
    if path == "/robots.txt":
        return make_response(
            200,
            "User-agent: *\nDisallow: /admin\nDisallow: /debug\n",
            "text/plain; charset=utf-8",
        )
    if path == "/login" and method == "GET":
        return make_response(200, login_page())
    if path == "/login" and method == "POST":
        fields = parse_qs(body.decode("utf-8", errors="replace"))
        username = fields.get("username", [""])[0]
        password = fields.get("password", [""])[0]
        if username == "analyst" and password == "packetlab":
            return make_response(
                200,
                login_page("Signed in for this response."),
                headers={"Set-Cookie": "lab_session=analyst; HttpOnly; SameSite=Lax"},
            )
        return make_response(401, login_page("Invalid lab credentials."))
    if path == "/admin":
        if "lab_session=analyst" in headers.get("cookie", ""):
            return make_response(200, layout("Admin", "<h1>Admin</h1><p>Local lab admin panel.</p>"))
        return make_response(403, layout("Forbidden", "<h1>Forbidden</h1><p>Sign in first.</p>"))
    if path == "/api/status":
        return json_response(
            200,
            {
                "service": "local-target-lab",
                "status": "ok",
                "time": now_iso(),
                "published_host_ports": [8088, 2222, 2525, 16379, 5300],
            },
        )
    if path == "/api/users":
        return json_response(200, {"users": USERS})
    if path == "/api/orders":
        owner = query.get("owner", [""])[0]
        rows = [order for order in ORDERS if not owner or order["owner"] == owner]
        return json_response(200, {"orders": rows})
    if path == "/search":
        term = query.get("q", [""])[0]
        return make_response(
            200,
            layout(
                "Search",
                f"<h1>Search</h1><p>You searched for <code>{html.escape(term)}</code>.</p>",
            ),
        )
    if path == "/debug/headers":
        return json_response(200, {"headers": headers})
    if path == "/redirect":
        return redirect("/api/status")
    if path == "/download/report.txt":
        report = (
            "Local Target Lab Report\n"
            f"Generated: {now_iso()}\n"
            "Scope: 127.0.0.1 only\n"
        )
        return make_response(200, report, "text/plain; charset=utf-8")
    if path == "/slow":
        return make_response(200, "slow response complete\n", "text/plain; charset=utf-8")

    return make_response(404, layout("Not Found", f"<h1>Not Found</h1><p>{html.escape(path)}</p>"))


async def handle_http(reader, writer):
    try:
        method, target, _version, headers, body = await read_http_request(reader)
        if target.startswith("/slow"):
            await asyncio.sleep(2)
        writer.write(route_http(method, target, headers, body))
        await writer.drain()
    except (asyncio.IncompleteReadError, asyncio.TimeoutError, ValueError):
        writer.write(make_response(400, "bad request\n", "text/plain; charset=utf-8"))
        await writer.drain()
    finally:
        await close_writer(writer)


async def handle_ssh(reader, writer):
    writer.write(b"SSH-2.0-OpenSSH_9.6p1 LocalTargetLab\r\n")
    await writer.drain()
    await read_some(reader, timeout=3)
    await close_writer(writer)


async def handle_smtp(reader, writer):
    writer.write(b"220 mail.local-target.lab ESMTP LocalTarget\r\n")
    await writer.drain()
    for _ in range(8):
        line = await read_some(reader, limit=512, timeout=5)
        if not line:
            break
        command = line.upper()
        if command.startswith(b"EHLO") or command.startswith(b"HELO"):
            writer.write(
                b"250-mail.local-target.lab\r\n"
                b"250-PIPELINING\r\n"
                b"250-SIZE 10240000\r\n"
                b"250 HELP\r\n"
            )
        elif command.startswith(b"MAIL FROM"):
            writer.write(b"250 Sender OK\r\n")
        elif command.startswith(b"RCPT TO"):
            writer.write(b"250 Recipient OK\r\n")
        elif command.startswith(b"DATA"):
            writer.write(b"354 End data with <CR><LF>.<CR><LF>\r\n")
        elif command.strip() == b".":
            writer.write(b"250 Message accepted for local lab delivery\r\n")
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
        info = b"redis_version:7.2.0\r\nrole:master\r\nconnected_clients:1\r\n"
        writer.write(b"$" + str(len(info)).encode("ascii") + b"\r\n" + info + b"\r\n")
    elif b"GET" in command:
        value = b"local-target-lab"
        writer.write(b"$" + str(len(value)).encode("ascii") + b"\r\n" + value + b"\r\n")
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


class DnsProtocol(asyncio.DatagramProtocol):
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
        await start_tcp(WEB_PORT, handle_http, "http"),
        await start_tcp(2222, handle_ssh, "ssh-banner"),
        await start_tcp(2525, handle_smtp, "smtp-banner"),
        await start_tcp(6379, handle_redis, "redis-like"),
    ]
    loop = asyncio.get_running_loop()
    transport, _ = await loop.create_datagram_endpoint(
        DnsProtocol,
        local_addr=("0.0.0.0", 5300),
    )
    print("dns-like listening on udp/5300", flush=True)

    try:
        async with asyncio.TaskGroup() as group:
            for server in servers:
                group.create_task(server.serve_forever())
    finally:
        transport.close()


if __name__ == "__main__":
    asyncio.run(main())
