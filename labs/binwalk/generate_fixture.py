#!/usr/bin/env python3
import argparse
import binascii
import gzip
import hashlib
import io
import json
import struct
import tarfile
import zlib
from pathlib import Path


GZIP_OFFSET = 0x400
PNG_OFFSET = 0x2000


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    checksum = binascii.crc32(chunk_type + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", checksum)


def one_pixel_png() -> bytes:
    scanline = b"\x00\x00\x88\xff"
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanline))
        + png_chunk(b"IEND", b"")
    )


def add_tar_file(tar: tarfile.TarFile, name: str, data: bytes, mode: int = 0o644) -> None:
    info = tarfile.TarInfo(name)
    info.size = len(data)
    info.mode = mode
    info.mtime = 1_767_225_600
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    tar.addfile(info, io.BytesIO(data))


def build_rootfs() -> bytes:
    tar_buffer = io.BytesIO()
    with tarfile.open(fileobj=tar_buffer, mode="w") as tar:
        add_tar_file(
            tar,
            "etc/device.conf",
            b"model=packetlab-router\nadmin_enabled=false\nsecret=local-training-only\n",
        )
        add_tar_file(
            tar,
            "www/index.html",
            b"<html><body><h1>PacketLab Firmware</h1><p>local fixture</p></body></html>\n",
        )
        add_tar_file(
            tar,
            "bin/startup.sh",
            b"#!/bin/sh\necho packetlab boot\n",
            0o755,
        )

    gzip_buffer = io.BytesIO()
    with gzip.GzipFile(filename="rootfs.tar", mode="wb", fileobj=gzip_buffer, mtime=0) as gz:
        gz.write(tar_buffer.getvalue())
    return gzip_buffer.getvalue()


def build_firmware() -> tuple[bytes, dict[str, object]]:
    rootfs_gz = build_rootfs()
    png = one_pixel_png()
    firmware = bytearray(
        b"PKTLAB-FIRMWARE\x00"
        b"model=packetlab-router\n"
        b"version=1.0.0\n"
        b"contains=training-data-only\n"
    )
    firmware.extend(b"\x00" * (GZIP_OFFSET - len(firmware)))
    firmware.extend(rootfs_gz)
    firmware.extend(b"\xff" * (PNG_OFFSET - len(firmware)))
    firmware.extend(png)

    manifest = {
        "firmware_size": len(firmware),
        "entries": [
            {
                "label": "gzip_rootfs",
                "offset_hex": hex(GZIP_OFFSET),
                "offset_decimal": GZIP_OFFSET,
                "description": "Gzip-compressed tar archive with harmless local firmware files.",
                "sha256": sha256(rootfs_gz),
            },
            {
                "label": "png_icon",
                "offset_hex": hex(PNG_OFFSET),
                "offset_decimal": PNG_OFFSET,
                "description": "Tiny PNG icon used for signature scanning practice.",
                "sha256": sha256(png),
            },
        ],
        "expected_files": [
            "etc/device.conf",
            "www/index.html",
            "bin/startup.sh",
        ],
    }
    manifest["firmware_sha256"] = sha256(bytes(firmware))
    return bytes(firmware), manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a local Binwalk firmware practice fixture.")
    parser.add_argument("fixture_dir", type=Path)
    parser.add_argument("manifest_path", type=Path)
    parser.add_argument("expected_files_path", type=Path)
    args = parser.parse_args()

    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)
    firmware, manifest = build_firmware()

    firmware_path = args.fixture_dir / "packetlab-firmware.bin"
    firmware_path.write_bytes(firmware)
    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    args.expected_files_path.write_text(
        "path\tpurpose\n"
        "etc/device.conf\tLocal configuration fixture for extraction review.\n"
        "www/index.html\tLocal web UI fixture for extracted-file review.\n"
        "bin/startup.sh\tHarmless startup script fixture for permission review.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
