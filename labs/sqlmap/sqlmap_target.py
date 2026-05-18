import html
import json
import os
import sqlite3
from datetime import datetime, timezone
from http import cookies
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlsplit


HOST = "0.0.0.0"
PORT = 8080
DB_PATH = "/tmp/sqlmap_lab.sqlite"


SCHEMA = """
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS notes;
DROP TABLE IF EXISTS api_tokens;

CREATE TABLE products (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  price REAL NOT NULL,
  stock INTEGER NOT NULL
);

CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  username TEXT NOT NULL,
  password TEXT NOT NULL,
  role TEXT NOT NULL,
  email TEXT NOT NULL
);

CREATE TABLE notes (
  id INTEGER PRIMARY KEY,
  owner TEXT NOT NULL,
  body TEXT NOT NULL
);

CREATE TABLE api_tokens (
  id INTEGER PRIMARY KEY,
  owner TEXT NOT NULL,
  token TEXT NOT NULL
);
"""


PRODUCTS = [
    (1, "Packet Sensor", "network", 149.00, 7),
    (2, "Log Correlator", "analytics", 89.00, 12),
    (3, "Training Router", "network", 59.00, 5),
    (4, "Lab Console", "admin", 199.00, 2),
]

USERS = [
    (1, "admin", "packetlab", "administrator", "admin@sqlmap.lab"),
    (2, "analyst", "blue-team", "analyst", "analyst@sqlmap.lab"),
    (3, "developer", "local-dev", "developer", "dev@sqlmap.lab"),
]

NOTES = [
    (1, "admin", "Training-only data for SQL injection practice."),
    (2, "analyst", "Validate every automated finding manually."),
    (3, "developer", "Fix unsafe queries with parameterized statements."),
]

TOKENS = [
    (1, "admin", "local-admin-token"),
    (2, "analyst", "local-analyst-token"),
]


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def json_bytes(payload):
    return json.dumps(payload, indent=2, sort_keys=True).encode("utf-8") + b"\n"


def init_db():
    if os.path.exists(DB_PATH):
        os.unlink(DB_PATH)

    with sqlite3.connect(DB_PATH) as db:
        db.executescript(SCHEMA)
        db.executemany("INSERT INTO products VALUES (?, ?, ?, ?, ?)", PRODUCTS)
        db.executemany("INSERT INTO users VALUES (?, ?, ?, ?, ?)", USERS)
        db.executemany("INSERT INTO notes VALUES (?, ?, ?)", NOTES)
        db.executemany("INSERT INTO api_tokens VALUES (?, ?, ?)", TOKENS)
        db.commit()


def db_connect():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def page(title, body, links=None):
    link_items = ""
    if links:
        link_items = "\n  <ul>\n"
        for path, label in links:
            link_items += f"    <li><a href=\"{html.escape(path)}\">{html.escape(label)}</a></li>\n"
        link_items += "  </ul>\n"

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{html.escape(title)}</title>
</head>
<body>
  <h1>{html.escape(title)}</h1>
  <p>{html.escape(body)}</p>{link_items}
</body>
</html>
"""


def render_table(title, rows):
    if not rows:
        return page(title, "No rows matched this query.")

    headers = rows[0].keys()
    header_html = "".join(f"<th>{html.escape(str(name))}</th>" for name in headers)
    row_html = ""
    for row in rows:
        cells = "".join(f"<td>{html.escape(str(row[name]))}</td>" for name in headers)
        row_html += f"    <tr>{cells}</tr>\n"

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{html.escape(title)}</title>
</head>
<body>
  <h1>{html.escape(title)}</h1>
  <table>
    <thead><tr>{header_html}</tr></thead>
    <tbody>
{row_html}    </tbody>
  </table>
</body>
</html>
"""


class SqlmapLabHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "sqlmap-lab/1.0"
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

    def do_HEAD(self):
        self.route()

    def do_GET(self):
        self.route()

    def do_POST(self):
        parsed = urlsplit(self.path)
        if parsed.path == "/login":
            return self.login(parse_qs(self.read_body().decode("utf-8", errors="replace"), keep_blank_values=True))
        return self.send_json(404, {"error": "not found", "path": parsed.path})

    def route(self):
        parsed = urlsplit(self.path)
        path = parsed.path
        query = parse_qs(parsed.query, keep_blank_values=True)

        if path == "/":
            return self.send_body(200, self.home_page(), "text/html; charset=utf-8")
        if path == "/health":
            return self.send_body(200, "ok\n")
        if path == "/api/status":
            return self.send_json(
                200,
                {
                    "service": "sqlmap-lab",
                    "status": "ok",
                    "time": now_iso(),
                    "database": "SQLite",
                    "client": self.client_address[0],
                },
            )
        if path == "/products":
            return self.products()
        if path == "/product":
            return self.product(query)
        if path == "/search":
            return self.search(query)
        if path == "/profile":
            return self.profile()
        if path == "/login":
            return self.send_body(200, self.login_form(), "text/html; charset=utf-8")

        return self.send_json(404, {"error": "not found", "path": path})

    def products(self):
        sql = "SELECT id, name, category, price, stock FROM products ORDER BY id"
        rows = self.query_rows(sql)
        return self.send_body(200, render_table("Products", rows), "text/html; charset=utf-8")

    def product(self, query):
        product_id = query.get("id", ["1"])[0]
        sql = f"SELECT id, name, category, price, stock FROM products WHERE id = {product_id}"
        return self.unsafe_table_response("Product Lookup", sql)

    def search(self, query):
        term = query.get("q", ["network"])[0]
        sql = (
            "SELECT id, name, category, price, stock FROM products "
            f"WHERE name LIKE '%{term}%' OR category LIKE '%{term}%' ORDER BY id"
        )
        return self.unsafe_table_response("Product Search", sql)

    def profile(self):
        jar = cookies.SimpleCookie(self.headers.get("Cookie", ""))
        user_id = jar.get("user_id")
        unsafe_id = unquote(user_id.value) if user_id else "1"
        sql = f"SELECT id, username, role, email FROM users WHERE id = {unsafe_id}"
        return self.unsafe_table_response("User Profile", sql)

    def login(self, form):
        username = form.get("username", [""])[0]
        password = form.get("password", [""])[0]
        sql = (
            "SELECT id, username, role, email FROM users "
            f"WHERE username = '{username}' AND password = '{password}'"
        )
        return self.unsafe_table_response("Login Result", sql)

    def unsafe_table_response(self, title, sql):
        try:
            rows = self.query_rows(sql)
        except sqlite3.Error as exc:
            return self.send_body(
                500,
                f"SQLite error: {exc}\nQuery: {sql}\n",
                "text/plain; charset=utf-8",
            )

        status = 200 if rows else 404
        return self.send_body(status, render_table(title, rows), "text/html; charset=utf-8")

    def query_rows(self, sql):
        with db_connect() as db:
            return db.execute(sql).fetchall()

    def home_page(self):
        links = [
            ("/products", "Safe product listing"),
            ("/product?id=1", "GET parameter practice target"),
            ("/search?q=network", "String parameter practice target"),
            ("/profile", "Cookie practice target, default user_id=1"),
            ("/login", "POST form practice target"),
            ("/api/status", "JSON status"),
        ]
        return page(
            "Sqlmap Lab Target",
            "Use this local SQLite app to practice sqlmap safely against known injection points.",
            links,
        )

    def login_form(self):
        return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Sqlmap Lab Login</title>
</head>
<body>
  <h1>Sqlmap Lab Login</h1>
  <form method="post" action="/login">
    <label>Username <input name="username" value="admin"></label>
    <label>Password <input name="password" type="password" value="wrong"></label>
    <button type="submit">Sign in</button>
  </form>
</body>
</html>
"""


def main():
    init_db()
    server = ThreadingHTTPServer((HOST, PORT), SqlmapLabHandler)
    print(f"Sqlmap lab target listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
