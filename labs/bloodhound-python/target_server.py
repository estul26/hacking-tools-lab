import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote


FIXTURE = Path("/app/fixtures/packetlab-graph.json")


def load_graph():
    with FIXTURE.open(encoding="utf-8") as handle:
        return json.load(handle)


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status, payload):
        body = json.dumps(payload, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        graph = load_graph()
        if self.path == "/health":
            self._send_json(200, {"status": "ok", "domain": graph["domain"]})
            return

        if self.path == "/objects":
            objects = [
                {"type": kind, "name": item["name"], "id": item["id"]}
                for kind in ("users", "groups", "computers")
                for item in graph[kind]
            ]
            self._send_json(200, {"objects": objects})
            return

        if self.path.startswith("/objects/"):
            object_id = unquote(self.path.rsplit("/", 1)[-1]).upper()
            for kind in ("users", "groups", "computers"):
                for item in graph[kind]:
                    if item["id"].upper() == object_id or item["name"].upper() == object_id:
                        self._send_json(200, {"type": kind, "object": item})
                        return
            self._send_json(404, {"error": "not found", "id": object_id})
            return

        self._send_json(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
