import asyncio
import socket
import struct


HOST = "0.0.0.0"
PORT = 5353
ZONE = "dig.lab.test"
TTL = 300

TYPE_A = 1
TYPE_NS = 2
TYPE_CNAME = 5
TYPE_SOA = 6
TYPE_PTR = 12
TYPE_MX = 15
TYPE_TXT = 16
TYPE_AAAA = 28
TYPE_SRV = 33
TYPE_ANY = 255
CLASS_IN = 1
CLASS_ANY = 255

TYPE_NAMES = {
    TYPE_A: "A",
    TYPE_NS: "NS",
    TYPE_CNAME: "CNAME",
    TYPE_SOA: "SOA",
    TYPE_PTR: "PTR",
    TYPE_MX: "MX",
    TYPE_TXT: "TXT",
    TYPE_AAAA: "AAAA",
    TYPE_SRV: "SRV",
    TYPE_ANY: "ANY",
}

RECORDS = {
    ZONE: {
        TYPE_A: ["172.36.70.20"],
        TYPE_NS: ["ns1.dig.lab.test"],
        TYPE_MX: [(10, "mail.dig.lab.test")],
        TYPE_SOA: [("ns1.dig.lab.test", "admin.dig.lab.test", 2026051701, 3600, 600, 86400, 300)],
        TYPE_TXT: ["dig lab root zone"],
    },
    "www.dig.lab.test": {
        TYPE_A: ["172.36.70.20"],
        TYPE_TXT: ["web endpoint for dig lab"],
    },
    "api.dig.lab.test": {
        TYPE_CNAME: ["www.dig.lab.test"],
    },
    "mail.dig.lab.test": {
        TYPE_A: ["172.36.70.25"],
    },
    "ns1.dig.lab.test": {
        TYPE_A: ["172.36.70.20"],
    },
    "ipv6.dig.lab.test": {
        TYPE_AAAA: ["fd00:36:70::20"],
    },
    "text.dig.lab.test": {
        TYPE_TXT: ["hello from the dig lab", "second TXT string"],
    },
    "_service._tcp.dig.lab.test": {
        TYPE_SRV: [(10, 5, 8080, "www.dig.lab.test")],
    },
    "20.70.36.172.in-addr.arpa": {
        TYPE_PTR: ["www.dig.lab.test"],
    },
    "noanswer.dig.lab.test": {
        TYPE_TXT: ["this name exists, but has no A record"],
    },
}


class DnsError(Exception):
    def __init__(self, rcode):
        self.rcode = rcode


def normalize_name(name):
    return name.rstrip(".").lower()


def encode_name(name):
    name = name.rstrip(".")
    if not name:
        return b"\x00"

    encoded = bytearray()
    for label in name.split("."):
        label_bytes = label.encode("ascii")
        if len(label_bytes) > 63:
            raise ValueError(f"DNS label is too long: {label}")
        encoded.append(len(label_bytes))
        encoded.extend(label_bytes)
    encoded.append(0)
    return bytes(encoded)


def decode_name(message, offset):
    labels = []
    jumped = False
    next_offset = offset
    seen_offsets = set()

    while True:
        if offset >= len(message):
            raise DnsError(1)
        length = message[offset]

        if length & 0xC0 == 0xC0:
            if offset + 1 >= len(message):
                raise DnsError(1)
            pointer = ((length & 0x3F) << 8) | message[offset + 1]
            if pointer in seen_offsets:
                raise DnsError(1)
            seen_offsets.add(pointer)
            if not jumped:
                next_offset = offset + 2
            offset = pointer
            jumped = True
            continue

        if length & 0xC0:
            raise DnsError(1)

        offset += 1
        if length == 0:
            if not jumped:
                next_offset = offset
            break

        if offset + length > len(message):
            raise DnsError(1)
        labels.append(message[offset : offset + length].decode("ascii").lower())
        offset += length

    return ".".join(labels), next_offset


def encode_txt(value):
    data = value.encode("utf-8")
    chunks = []
    while data:
        chunk = data[:255]
        chunks.append(bytes([len(chunk)]) + chunk)
        data = data[255:]
    if not chunks:
        return b"\x00"
    return b"".join(chunks)


def encode_rdata(record_type, value):
    if record_type == TYPE_A:
        return socket.inet_aton(value)
    if record_type == TYPE_AAAA:
        return socket.inet_pton(socket.AF_INET6, value)
    if record_type in {TYPE_NS, TYPE_CNAME, TYPE_PTR}:
        return encode_name(value)
    if record_type == TYPE_TXT:
        return encode_txt(value)
    if record_type == TYPE_MX:
        preference, exchange = value
        return struct.pack("!H", preference) + encode_name(exchange)
    if record_type == TYPE_SOA:
        mname, rname, serial, refresh, retry, expire, minimum = value
        return (
            encode_name(mname)
            + encode_name(rname)
            + struct.pack("!IIIII", serial, refresh, retry, expire, minimum)
        )
    if record_type == TYPE_SRV:
        priority, weight, port, target = value
        return struct.pack("!HHH", priority, weight, port) + encode_name(target)
    raise ValueError(f"unsupported record type: {record_type}")


def encode_record(name, record_type, value):
    rdata = encode_rdata(record_type, value)
    return (
        encode_name(name)
        + struct.pack("!HHIH", record_type, CLASS_IN, TTL, len(rdata))
        + rdata
    )


def known_name(name):
    return name in RECORDS or name == "servfail.dig.lab.test"


def records_for(name, query_type):
    name = normalize_name(name)
    if name == "servfail.dig.lab.test":
        raise DnsError(2)
    if not known_name(name):
        raise DnsError(3)

    type_map = RECORDS.get(name, {})
    answers = []

    if query_type == TYPE_ANY:
        for record_type in sorted(type_map):
            for value in type_map[record_type]:
                answers.append((name, record_type, value))
        return answers

    if query_type in type_map:
        for value in type_map[query_type]:
            answers.append((name, query_type, value))
        return answers

    if TYPE_CNAME in type_map and query_type != TYPE_CNAME:
        target = type_map[TYPE_CNAME][0]
        answers.append((name, TYPE_CNAME, target))
        target_map = RECORDS.get(normalize_name(target), {})
        for value in target_map.get(query_type, []):
            answers.append((target, query_type, value))

    return answers


def build_response(query):
    if len(query) < 12:
        return b""

    request_id, flags, qdcount, _ancount, _nscount, _arcount = struct.unpack("!HHHHHH", query[:12])
    if qdcount < 1:
        rcode = 1
        return struct.pack("!HHHHHH", request_id, response_flags(flags, rcode), 0, 0, 0, 0)

    question = b""
    try:
        qname, offset = decode_name(query, 12)
        if offset + 4 > len(query):
            raise DnsError(1)
        qtype, qclass = struct.unpack("!HH", query[offset : offset + 4])
        question = query[12 : offset + 4]

        if qclass not in {CLASS_IN, CLASS_ANY}:
            answers = []
            rcode = 0
        else:
            answer_parts = [
                encode_record(answer_name, answer_type, value)
                for answer_name, answer_type, value in records_for(qname, qtype)
            ]
            answers = answer_parts
            rcode = 0
    except DnsError as exc:
        answers = []
        rcode = exc.rcode

    header = struct.pack(
        "!HHHHHH",
        request_id,
        response_flags(flags, rcode),
        1 if question else 0,
        len(answers),
        0,
        0,
    )
    return header + question + b"".join(answers)


def response_flags(request_flags, rcode):
    recursion_desired = request_flags & 0x0100
    return 0x8000 | 0x0400 | recursion_desired | 0x0080 | (rcode & 0x000F)


class DnsUdpProtocol(asyncio.DatagramProtocol):
    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        response = build_response(data)
        if response:
            self.transport.sendto(response, addr)


async def handle_tcp_dns(reader, writer):
    peer = writer.get_extra_info("peername")
    try:
        while True:
            length_bytes = await reader.readexactly(2)
            query_length = struct.unpack("!H", length_bytes)[0]
            query = await reader.readexactly(query_length)
            response = build_response(query)
            writer.write(struct.pack("!H", len(response)) + response)
            await writer.drain()
    except (asyncio.IncompleteReadError, ConnectionError):
        pass
    finally:
        print(f"tcp dns connection closed: {peer}", flush=True)
        writer.close()
        await writer.wait_closed()


async def main():
    loop = asyncio.get_running_loop()
    udp_transport, _ = await loop.create_datagram_endpoint(
        DnsUdpProtocol,
        local_addr=(HOST, PORT),
    )
    tcp_server = await asyncio.start_server(handle_tcp_dns, host=HOST, port=PORT)
    print(f"dig lab DNS listening on udp/tcp {HOST}:{PORT}", flush=True)

    try:
        async with tcp_server:
            await tcp_server.serve_forever()
    finally:
        udp_transport.close()


if __name__ == "__main__":
    asyncio.run(main())
