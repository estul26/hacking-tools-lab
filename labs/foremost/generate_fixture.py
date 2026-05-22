#!/usr/bin/env python3
import argparse
import binascii
import hashlib
import io
import json
import struct
import zipfile
import zlib
from pathlib import Path


IMAGE_SIZE = 96 * 1024
ARTIFACTS = [
    ("png_icon", "png", 0x1000),
    ("gif_pixel", "gif", 0x4000),
    ("zip_notes", "zip", 0x8000),
]


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    checksum = binascii.crc32(chunk_type + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", checksum)


def one_pixel_png() -> bytes:
    scanline = b"\x00\x60\x20\xff"
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanline))
        + png_chunk(b"IEND", b"")
    )


def one_pixel_gif() -> bytes:
    return (
        b"GIF89a"
        b"\x01\x00\x01\x00"
        b"\x80\x00\x00"
        b"\x00\x00\x00"
        b"\xff\xff\xff"
        b"!\xf9\x04\x01\x00\x00\x00\x00"
        b",\x00\x00\x00\x00\x01\x00\x01\x00\x00"
        b"\x02\x02D\x01\x00;"
    )


def local_zip() -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("case-note.txt", "PacketLab Foremost local carving fixture\n")
        archive.writestr("evidence/path.txt", "All content is generated locally for training.\n")
    return buffer.getvalue()


def deterministic_background(size: int) -> bytearray:
    output = bytearray()
    counter = 0
    while len(output) < size:
        output.extend(hashlib.sha256(f"foremost-background-{counter}".encode("ascii")).digest())
        counter += 1
    return output[:size]


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a local Foremost carving fixture.")
    parser.add_argument("fixture_dir", type=Path)
    parser.add_argument("manifest_path", type=Path)
    args = parser.parse_args()

    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)

    payloads = {
        "png": one_pixel_png(),
        "gif": one_pixel_gif(),
        "zip": local_zip(),
    }
    image = deterministic_background(IMAGE_SIZE)
    entries = []
    for label, artifact_type, offset in ARTIFACTS:
        payload = payloads[artifact_type]
        image[offset : offset + len(payload)] = payload
        entries.append(
            {
                "label": label,
                "type": artifact_type,
                "offset_hex": hex(offset),
                "offset_decimal": offset,
                "foremost_block_name": f"{offset // 512:08d}",
                "size": len(payload),
                "sha256": sha256_bytes(payload),
            }
        )

    image_path = args.fixture_dir / "packetlab-disk.img"
    image_path.write_bytes(image)
    manifest = {
        "fixture": str(image_path),
        "size": len(image),
        "sha256": hashlib.sha256(image).hexdigest(),
        "artifacts": entries,
    }
    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
