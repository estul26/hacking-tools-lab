import random
import socket
import struct
import time


MULTICAST_LLMNR = ("224.0.0.252", 5355)
MULTICAST_MDNS = ("224.0.0.251", 5353)
BROADCAST_NBNS = ("172.60.82.255", 137)


def dns_name(name):
    return b"".join(bytes([len(part)]) + part.encode("ascii") for part in name.split(".")) + b"\x00"


def dns_query(name, qtype=1):
    transaction_id = random.randint(1, 65535)
    header = struct.pack("!HHHHHH", transaction_id, 0, 1, 0, 0, 0)
    question = dns_name(name) + struct.pack("!HH", qtype, 1)
    return header + question


def encode_netbios_name(name):
    padded = name.upper().ljust(15)[:15] + "\x00"
    encoded = []
    for char in padded.encode("ascii"):
        encoded.append(chr(((char >> 4) & 0x0F) + ord("A")))
        encoded.append(chr((char & 0x0F) + ord("A")))
    return bytes([32]) + "".join(encoded).encode("ascii") + b"\x00"


def nbns_query(name):
    transaction_id = random.randint(1, 65535)
    header = struct.pack("!HHHHHH", transaction_id, 0x0110, 1, 0, 0, 0)
    question = encode_netbios_name(name) + struct.pack("!HH", 0x0020, 1)
    return header + question


def send_udp(packet, target, broadcast=False, multicast_ttl=None):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        if broadcast:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        if multicast_ttl is not None:
            sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, multicast_ttl)
        sock.sendto(packet, target)


def main():
    names = ["wpad-lab", "files-lab", "printer-lab"]
    for _ in range(3):
        for name in names:
            send_udp(dns_query(name), MULTICAST_LLMNR, multicast_ttl=1)
            send_udp(dns_query(f"{name}.local"), MULTICAST_MDNS, multicast_ttl=1)
            send_udp(nbns_query(name), BROADCAST_NBNS, broadcast=True)
            time.sleep(0.2)

    print("sent synthetic LLMNR, mDNS, and NBNS lab queries")


if __name__ == "__main__":
    main()
