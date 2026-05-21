#!/usr/bin/env python3
import base64
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "0.0.0.0"
PORT = 5985
USERNAME = "labadmin"
PASSWORD = "LabPass2026!"
REALM = "PACKETLAB"
SERVER = "Packetlab WinRM-style Local Target"

EVENTS = []


def now():
    return datetime.now(timezone.utc).isoformat()


def record(handler, note, body_size=0):
    auth = handler.headers.get("Authorization", "")
    if auth.startswith("Basic "):
        auth_type = "Basic"
    elif auth.startswith("NTLM "):
        auth_type = "NTLM"
    elif auth.startswith("Negotiate "):
        auth_type = "Negotiate"
    elif auth:
        auth_type = auth.split(" ", 1)[0]
    else:
        auth_type = "none"

    EVENTS.append(
        {
            "time": now(),
            "client": handler.client_address[0],
            "method": handler.command,
            "path": handler.path,
            "auth_type": auth_type,
            "user_agent": handler.headers.get("User-Agent", ""),
            "content_length": body_size,
            "note": note,
        }
    )
    del EVENTS[:-50]


def soap_fault(reason, code="2150858770"):
    return f"""<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"
            xmlns:w="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">
  <s:Body>
    <s:Fault>
      <s:Code><s:Value>s:Sender</s:Value></s:Code>
      <s:Reason><s:Text xml:lang="en-US">{reason}</s:Text></s:Reason>
      <s:Detail>
        <w:WSManFault Code="{code}" Machine="packetlab-winrm">
          <w:Message>{reason}</w:Message>
        </w:WSManFault>
      </s:Detail>
    </s:Fault>
  </s:Body>
</s:Envelope>
""".encode()


class Handler(BaseHTTPRequestHandler):
    server_version = SERVER

    def log_message(self, fmt, *args):
        print(json.dumps({"time": now(), "message": fmt % args}), flush=True)

    def send_json(self, payload, status=200):
        data = json.dumps(payload, indent=2).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def send_auth_required(self, note):
        record(self, note)
        self.send_response(401)
        self.send_header("WWW-Authenticate", f'Basic realm="{REALM}"')
        self.send_header("WWW-Authenticate", "NTLM")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def has_valid_basic_auth(self):
        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Basic "):
            return False
        try:
            decoded = base64.b64decode(auth.split(" ", 1)[1]).decode()
        except Exception:
            return False
        return decoded == f"{USERNAME}:{PASSWORD}"

    def do_GET(self):
        if self.path == "/health":
            record(self, "health check")
            self.send_json(
                {
                    "service": "winrm-style-local-target",
                    "status": "ok",
                    "wsman": "/wsman",
                    "auth": "Basic for curl, NTLM/Negotiate challenge markers for Evil-WinRM",
                    "username": USERNAME,
                }
            )
            return
        if self.path == "/events":
            record(self, "events read")
            self.send_json({"events": EVENTS})
            return
        if self.path == "/wsman":
            self.send_auth_required("GET /wsman requires auth")
            return
        record(self, "not found")
        self.send_json({"error": "not found"}, status=404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length) if length else b""
        if self.path != "/wsman":
            record(self, "not found", len(body))
            self.send_json({"error": "not found"}, status=404)
            return

        if not self.has_valid_basic_auth():
            self.send_auth_required("POST /wsman rejected without valid Basic credentials")
            return

        record(self, "authenticated mock WS-Man SOAP fault", len(body))
        fault = soap_fault(
            "Local lab endpoint reached. This mock target records WinRM requests but does not create a Windows shell."
        )
        self.send_response(500)
        self.send_header("Content-Type", "application/soap+xml;charset=UTF-8")
        self.send_header("Content-Length", str(len(fault)))
        self.end_headers()
        self.wfile.write(fault)


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(json.dumps({"time": now(), "listening": f"{HOST}:{PORT}"}), flush=True)
    server.serve_forever()
