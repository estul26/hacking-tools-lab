#!/usr/bin/env python3
import argparse
import binascii
import gzip
import hashlib
import json
import struct
import zlib
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    checksum = binascii.crc32(chunk_type + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", checksum)


def one_pixel_png() -> bytes:
    scanline = b"\x00\x20\x80\xff"
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanline))
        + png_chunk(b"IEND", b"")
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate local file(1) practice fixtures.")
    parser.add_argument("fixture_dir", type=Path)
    parser.add_argument("manifest_path", type=Path)
    args = parser.parse_args()

    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)

    fixtures: list[dict[str, str]] = []

    def write(name: str, data: bytes, expected: str, purpose: str) -> None:
        path = args.fixture_dir / name
        path.write_bytes(data)
        fixtures.append(
            {
                "name": name,
                "expected": expected,
                "purpose": purpose,
                "sha256": sha256(path),
            }
        )

    write(
        "note.txt",
        b"PacketLab file command fixture\nThis is plain ASCII text.\n",
        "ASCII text",
        "Baseline plain text file.",
    )
    write(
        "script.sh",
        b"#!/bin/sh\necho packetlab local fixture\n",
        "POSIX shell script",
        "Executable-style script identified from shebang/content.",
    )
    write(
        "config.json",
        b'{\n  "lab": "file",\n  "local_only": true,\n  "count": 3\n}\n',
        "JSON text data",
        "Structured text fixture.",
    )
    write(
        "image.png",
        one_pixel_png(),
        "PNG image data",
        "Tiny valid PNG fixture.",
    )
    write(
        "renamed-as-jpg.jpg",
        one_pixel_png(),
        "PNG image data",
        "Mismatched extension proves file does not trust names.",
    )
    write(
        "packetlab.bin",
        b"PKTLABMAGIC\x00\x01local binary fixture\x00" + bytes(range(32)),
        "PacketLab custom firmware blob",
        "Custom magic-rule fixture.",
    )
    write(
        "random.bin",
        hashlib.sha256(b"packetlab-random").digest() * 8,
        "data",
        "Opaque binary data fixture.",
    )

    gzip_path = args.fixture_dir / "note.txt.gz"
    with gzip.GzipFile(filename="note.txt", mode="wb", fileobj=gzip_path.open("wb"), mtime=0) as gz:
        gz.write((args.fixture_dir / "note.txt").read_bytes())
    fixtures.append(
        {
            "name": gzip_path.name,
            "expected": "gzip compressed data",
            "purpose": "Compressed text fixture for -z decompression-aware detection.",
            "sha256": sha256(gzip_path),
        }
    )

    manifest = {"fixtures": fixtures}
    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
