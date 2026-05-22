#!/usr/bin/env python3
import argparse
import binascii
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
    scanline = b"\x00\xff\xff\xff"
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanline))
        + png_chunk(b"IEND", b"")
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate local ExifTool practice fixtures.")
    parser.add_argument("fixture_dir", type=Path)
    parser.add_argument("manifest_path", type=Path)
    args = parser.parse_args()

    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    image_path = args.fixture_dir / "lab-photo.png"
    note_path = args.fixture_dir / "case-note.txt"

    image_path.write_bytes(one_pixel_png())
    note_path.write_text(
        "PacketLab EXIF practice note\n"
        "Case: EXIF-LOCAL-001\n"
        "These fixtures are generated locally and contain no real personal data.\n",
        encoding="utf-8",
    )

    manifest = {
        "fixtures": [
            {
                "name": image_path.name,
                "purpose": "Tiny local PNG that ExifTool annotates with practice metadata.",
                "sha256_before_metadata": sha256(image_path),
            },
            {
                "name": note_path.name,
                "purpose": "Plain-text companion note for basic file identification practice.",
                "sha256": sha256(note_path),
            },
        ]
    }
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)
    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
