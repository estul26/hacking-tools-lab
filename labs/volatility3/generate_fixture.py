#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


FIXTURE_SIZE = 2 * 1024 * 1024

STRINGS = [
    (
        0x1000,
        "Linux version 5.15.0-volatility3-lab (builder@packetlab) #1 SMP Fri Jan 1 00:00:00 UTC 2026\n",
        "linux_banner",
    ),
    (
        0x22000,
        "PID=4242 NAME=packetlab-agent CMD=/usr/local/bin/packetlab-agent --local-only\n",
        "process_hint",
    ),
    (
        0x34000,
        "URL=http://127.0.0.1:8080/admin STATUS=lab-only\n",
        "localhost_url",
    ),
    (
        0x36000,
        "NOTE=LOCAL_TRAINING_ONLY DO_NOT_UPLOAD_REAL_MEMORY_IMAGES\n",
        "handling_note",
    ),
    (
        0x3A000,
        "VOLLAB_MARKER=packetlab-memory-fixture CASE=VOL3-LOCAL-001\n",
        "case_marker",
    ),
]


def write_fixture(raw_path: Path) -> list[dict[str, str | int]]:
    raw_path.parent.mkdir(parents=True, exist_ok=True)
    image = bytearray(b"\x00" * FIXTURE_SIZE)
    manifest: list[dict[str, str | int]] = []

    for offset, text, label in STRINGS:
        data = text.encode("ascii")
        image[offset : offset + len(data)] = data
        manifest.append(
            {
                "label": label,
                "offset_hex": hex(offset),
                "offset_decimal": offset,
                "text": text.rstrip("\n"),
            }
        )

    raw_path.write_bytes(image)
    digest = hashlib.sha256(image).hexdigest()
    manifest.insert(
        0,
        {
            "label": "fixture",
            "offset_hex": "0x0",
            "offset_decimal": 0,
            "text": f"size={FIXTURE_SIZE} sha256={digest}",
        },
    )
    return manifest


def write_manifest(manifest_path: Path, strings_path: Path, raw_path: Path, manifest: list[dict[str, str | int]]) -> None:
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    strings_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(
            {
                "fixture": str(raw_path),
                "size": FIXTURE_SIZE,
                "sha256": hashlib.sha256(raw_path.read_bytes()).hexdigest(),
                "entries": manifest[1:],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    with strings_path.open("w", encoding="utf-8") as handle:
        handle.write("label\toffset_hex\ttext\n")
        for entry in manifest[1:]:
            handle.write(f"{entry['label']}\t{entry['offset_hex']}\t{entry['text']}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a tiny local Volatility3 practice fixture.")
    parser.add_argument("raw_path", type=Path)
    parser.add_argument("manifest_path", type=Path)
    parser.add_argument("strings_path", type=Path)
    args = parser.parse_args()

    manifest = write_fixture(args.raw_path)
    write_manifest(args.manifest_path, args.strings_path, args.raw_path, manifest)


if __name__ == "__main__":
    main()
