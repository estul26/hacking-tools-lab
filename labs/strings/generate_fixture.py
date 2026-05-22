#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


FIXTURE_SIZE = 4096

ASCII_MARKERS = [
    (0x80, "PACKETLAB_STRINGS_FIXTURE v1.0"),
    (0x180, "URL=http://127.0.0.1:8080/status"),
    (0x240, "API_TOKEN=LOCAL-TRAINING-ONLY-NOT-A-REAL-SECRET"),
    (0x320, "/opt/packetlab/bin/local-agent --mode offline"),
    (0x420, "ERROR: local fixture authentication failed for demo-user"),
    (0x560, "BUILD_ID=strings-lab-2026-01-01"),
    (0x700, "tiny"),
]

UTF16_MARKER_OFFSET = 0x900
UTF16_MARKER = "UNICODE_PACKETLAB_MARKER"


def deterministic_noise(size: int) -> bytearray:
    output = bytearray()
    counter = 0
    while len(output) < size:
        output.extend(hashlib.sha256(f"packetlab-{counter}".encode("ascii")).digest())
        counter += 1
    return output[:size]


def put_ascii(blob: bytearray, offset: int, text: str) -> None:
    data = text.encode("ascii") + b"\x00"
    if offset > 0:
        blob[offset - 1] = 0
    blob[offset : offset + len(data)] = data


def put_utf16le(blob: bytearray, offset: int, text: str) -> None:
    data = text.encode("utf-16le") + b"\x00\x00"
    if offset > 1:
        blob[offset - 2 : offset] = b"\x00\x00"
    blob[offset : offset + len(data)] = data


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a local strings practice fixture.")
    parser.add_argument("fixture_dir", type=Path)
    parser.add_argument("manifest_path", type=Path)
    args = parser.parse_args()

    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)

    blob = deterministic_noise(FIXTURE_SIZE)
    blob[0:16] = b"PKTLAB-STRINGS\x00\x01"
    for offset, text in ASCII_MARKERS:
        put_ascii(blob, offset, text)
    put_utf16le(blob, UTF16_MARKER_OFFSET, UTF16_MARKER)

    fixture_path = args.fixture_dir / "packetlab-sample.bin"
    fixture_path.write_bytes(blob)
    digest = hashlib.sha256(blob).hexdigest()

    manifest = {
        "fixture": str(fixture_path),
        "size": len(blob),
        "sha256": digest,
        "ascii_markers": [
            {
                "offset_hex": hex(offset),
                "offset_decimal": offset,
                "text": text,
            }
            for offset, text in ASCII_MARKERS
        ],
        "utf16le_marker": {
            "offset_hex": hex(UTF16_MARKER_OFFSET),
            "offset_decimal": UTF16_MARKER_OFFSET,
            "text": UTF16_MARKER,
        },
    }
    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
