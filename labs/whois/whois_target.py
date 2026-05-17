import asyncio
from datetime import datetime, timezone


HOST = "0.0.0.0"
PORT = 43


RESPONSES = {
    "example.test": """Domain Name: EXAMPLE.TEST
Registry Domain ID: D000001-LAB
Registrar WHOIS Server: whois.dig.lab.test
Registrar: Local Lab Registrar
Updated Date: 2026-05-17T12:00:00Z
Creation Date: 2024-01-15T12:00:00Z
Registry Expiry Date: 2027-01-15T12:00:00Z
Domain Status: active https://icann.org/epp#active
Registrant Organization: Example Training Org
Registrant Country: TEST
Name Server: NS1.DIG.LAB.TEST
Name Server: NS2.DIG.LAB.TEST
DNSSEC: unsigned
""",
    "packetlab.test": """Domain Name: PACKETLAB.TEST
Registry Domain ID: D000002-LAB
Registrar: Local Lab Registrar
Updated Date: 2026-05-16T08:30:00Z
Creation Date: 2025-02-10T09:00:00Z
Registry Expiry Date: 2028-02-10T09:00:00Z
Domain Status: clientTransferProhibited https://icann.org/epp#clientTransferProhibited
Registrant Organization: Packet Lab
Registrant Email: admin@packetlab.test
Name Server: NS1.DIG.LAB.TEST
Name Server: NS2.DIG.LAB.TEST
DNSSEC: unsigned
""",
    "expired.test": """Domain Name: EXPIRED.TEST
Registry Domain ID: D000003-LAB
Registrar: Local Lab Registrar
Updated Date: 2024-05-17T00:00:00Z
Creation Date: 2023-05-17T00:00:00Z
Registry Expiry Date: 2025-05-17T00:00:00Z
Domain Status: redemptionPeriod https://icann.org/epp#redemptionPeriod
Registrant Organization: Expired Example
Name Server: NS1.DIG.LAB.TEST
DNSSEC: unsigned
""",
    "172.37.80.20": """NetRange:       172.37.80.0 - 172.37.80.255
CIDR:           172.37.80.0/24
NetName:        WHOIS-LAB-NET
NetHandle:      NET-172-37-80-0-1
Parent:         RFC1918-LAB
NetType:        Direct Assignment
Organization:   Local WHOIS Lab
RegDate:        2026-05-17
Updated:        2026-05-17
Comment:        Local-only training network.
""",
    "172.37.80.0/24": """NetRange:       172.37.80.0 - 172.37.80.255
CIDR:           172.37.80.0/24
NetName:        WHOIS-LAB-NET
NetHandle:      NET-172-37-80-0-1
Organization:   Local WHOIS Lab
AbuseContact:   ABUSE-WHOIS-LAB
TechContact:    TECH-WHOIS-LAB
""",
    "as64512": """ASNumber:       64512
ASName:         WHOIS-LAB-AS
ASHandle:       AS64512
RegDate:        2026-05-17
Updated:        2026-05-17
Organization:   Local WHOIS Lab
Comment:        Documentation-range ASN for lab practice.
""",
    "abuse-whois-lab": """Handle:         ABUSE-WHOIS-LAB
Role:           Abuse Contact
Organization:   Local WHOIS Lab
Email:          abuse@whois.lab.test
Phone:          +1-555-0100
Updated:        2026-05-17
""",
    "tech-whois-lab": """Handle:         TECH-WHOIS-LAB
Role:           Technical Contact
Organization:   Local WHOIS Lab
Email:          tech@whois.lab.test
Phone:          +1-555-0101
Updated:        2026-05-17
""",
    "registrar local": """Registrar Name: Local Lab Registrar
IANA ID:        999999
WHOIS Server:   127.0.0.1:1043
Referral URL:   https://example.invalid/local-lab-registrar
Abuse Contact:  abuse@whois.lab.test
""",
}


HELP_TEXT = """WHOIS Lab Server

Try one of these queries:
  example.test
  packetlab.test
  expired.test
  172.37.80.20
  172.37.80.0/24
  AS64512
  ABUSE-WHOIS-LAB
  TECH-WHOIS-LAB
  registrar local
  help

This server is local training data only.
"""


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def normalize_query(query):
    query = query.strip().lower()
    if query.startswith("="):
        query = query[1:].strip()
    if query.startswith("domain "):
        query = query.removeprefix("domain ").strip()
    if query.startswith("net "):
        query = query.removeprefix("net ").strip()
    if query.startswith("asn "):
        query = "as" + query.removeprefix("asn ").strip().lstrip("as")
    return query


def lookup(query):
    normalized = normalize_query(query)

    if normalized in {"", "?", "help"}:
        return HELP_TEXT
    if normalized.startswith("-"):
        return (
            "Error: WHOIS flags are not supported by this tiny lab server.\n"
            "Try querying a bare object, such as `example.test` or `AS64512`.\n"
        )
    if normalized in RESPONSES:
        return RESPONSES[normalized]
    if normalized == "whois.lab.test":
        return "ReferralServer: whois://127.0.0.1:1043\n"

    return f"""No match for query: {query.strip()}

Supported lab objects include:
  example.test
  packetlab.test
  172.37.80.20
  AS64512

Use `help` for the full local object list.
"""


async def handle_whois(reader, writer):
    peer = writer.get_extra_info("peername")
    try:
        data = await asyncio.wait_for(reader.readline(), timeout=10)
    except asyncio.TimeoutError:
        data = b""

    query = data.decode("utf-8", errors="replace").strip()
    print(f"whois query from {peer}: {query!r}", flush=True)

    body = lookup(query)
    response = (
        "% WHOIS Lab Server\n"
        "% Local-only training data. Do not treat as public registry truth.\n"
        f"% Query: {query or '<empty>'}\n"
        f"% Timestamp: {now_iso()}\n\n"
        f"{body.rstrip()}\n"
        "\n% End\n"
    )
    writer.write(response.encode("utf-8"))
    await writer.drain()
    writer.close()
    await writer.wait_closed()


async def main():
    server = await asyncio.start_server(handle_whois, host=HOST, port=PORT)
    print(f"whois lab listening on tcp/{PORT}", flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
