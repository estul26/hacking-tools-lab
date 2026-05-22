#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


FIXTURE_SIZE = 512

MARKERS = [
    (0x00, b"PKTLAB-XXD\x00\x01"),
    (0x20, b"ORIGINAL"),
    (0x40, b"PacketLab xxd local fixture"),
    (0x80, b"URL=http://127.0.0.1:8080/xxd"),
    (0xC0, b"API_TOKEN=LOCAL-TRAINING-ONLY"),
    (0x120, b"END-OF-XXD-LAB"),
]


def deterministic_bytes(size: int) -> bytearray:
    output = bytearray()
    counter = 0
    while len(output) < size:
        output.extend(hashlib.sha256(f"packetlab-xxd-{counter}".encode("ascii")).digest())
        counter += 1
    return output[:size]


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a local xxd practice fixture.")
    parser.add_argument("fixture_dir", type=Path)
    parser.add_argument("manifest_path", type=Path)
    args = parser.parse_args()

    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)

    blob = deterministic_bytes(FIXTURE_SIZE)
    for offset, data in MARKERS:
        if offset > 0:
            blob[offset - 1] = 0
        blob[offset : offset + len(data)] = data
        end = offset + len(data)
        if end < len(blob):
            blob[end] = 0

    fixture_path = args.fixture_dir / "packetlab-sample.bin"
    fixture_path.write_bytes(blob)
    manifest = {
        "fixture": str(fixture_path),
        "size": len(blob),
        "sha256": hashlib.sha256(blob).hexdigest(),
        "markers": [
            {
                "offset_hex": hex(offset),
                "offset_decimal": offset,
                "text": data.decode("ascii", errors="replace").rstrip("\x00"),
            }
            for offset, data in MARKERS
        ],
        "patch": {
            "offset_hex": "0x20",
            "before": "ORIGINAL",
            "after": "PATCHED1",
        },
    }
    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
