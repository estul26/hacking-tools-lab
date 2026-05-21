#!/usr/bin/env python3
import struct
import sys
import time


def mac(value):
    return bytes.fromhex(value.replace(":", ""))


def tag(number, data):
    return bytes([number, len(data)]) + data


def beacon(bssid, essid, channel, seq=0):
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
    fixed = struct.pack("<QHH", int(time.time() * 1000000), 100, 0x0411)
    body = (
        tag(0, essid.encode())
        + tag(1, b"\x82\x84\x8b\x96\x0c\x12\x18\x24")
        + tag(3, bytes([channel]))
    )
    return radiotap + header + fixed + body


def deauth_frame(bssid, station, seq=1):
    radiotap = b"\x00\x00\x08\x00\x00\x00\x00\x00"
    bssid_bytes = mac(bssid)
    station_bytes = mac(station)
    header = (
        b"\xc0\x00"
        + b"\x00\x00"
        + station_bytes
        + bssid_bytes
        + bssid_bytes
        + struct.pack("<H", seq << 4)
    )
    reason_code = struct.pack("<H", 7)
    return radiotap + header + reason_code


def write_pcap(path):
    packets = [
        beacon("02:11:22:33:44:55", "PacketLab-WEP", 6, 0),
        deauth_frame("02:11:22:33:44:55", "02:66:77:88:99:AA", 1),
    ]
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
        print("usage: generate_frames.py OUTPUT.pcap", file=sys.stderr)
        raise SystemExit(2)
    write_pcap(sys.argv[1])
