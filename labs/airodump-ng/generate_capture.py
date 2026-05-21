#!/usr/bin/env python3
import struct
import sys
import time


def mac(value):
    return bytes.fromhex(value.replace(":", ""))


def tag(number, data):
    return bytes([number, len(data)]) + data


def beacon(bssid, essid, channel, privacy=False, rsn=False, seq=0):
    radiotap = b"\x00\x00\x08\x00\x00\x00\x00\x00"
    bssid_bytes = mac(bssid)
    header = (
        b"\x80\x00"
        + b"\x00\x00"
        + (b"\xff" * 6)
        + bssid_bytes
        + bssid_bytes
        + struct.pack("<H", seq << 4)
    )
    capabilities = 0x0001 | 0x0400
    if privacy:
        capabilities |= 0x0010
    fixed = struct.pack("<QHH", int(time.time() * 1000000), 100, capabilities)
    body = (
        tag(0, essid.encode())
        + tag(1, b"\x82\x84\x8b\x96\x0c\x12\x18\x24")
        + tag(3, bytes([channel]))
    )
    if rsn:
        body += tag(48, bytes.fromhex("0100000fac040100000fac040100000fac040100000fac020000"))
    return radiotap + header + fixed + body


def write_pcap(path):
    packets = []
    for seq in range(24):
        packets.append(beacon("02:11:22:33:44:55", "PacketLab-WEP", 6, True, False, seq))
        packets.append(beacon("02:AA:BB:CC:DD:EE", "PacketLab-WPA2", 11, True, True, seq))

    with open(path, "wb") as handle:
        handle.write(struct.pack("<IHHIIII", 0xA1B2C3D4, 2, 4, 0, 0, 65535, 127))
        timestamp = int(time.time())
        usec = 0
        for packet in packets:
            handle.write(struct.pack("<IIII", timestamp, usec, len(packet), len(packet)))
            handle.write(packet)
            usec += 1000


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: generate_capture.py OUTPUT.pcap", file=sys.stderr)
        raise SystemExit(2)
    write_pcap(sys.argv[1])
