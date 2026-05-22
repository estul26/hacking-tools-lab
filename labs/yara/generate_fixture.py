#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


SAMPLES = {
    "packetlab-note.txt": (
        b"PacketLab YARA local fixture\n"
        b"URL=http://127.0.0.1:8080/yara\n"
        b"API_TOKEN=LOCAL-TRAINING-ONLY\n"
        b"mode=offline\n"
    ),
    "benign-note.txt": (
        b"This harmless note intentionally avoids training indicators.\n"
        b"It is used to validate non-matching behavior.\n"
    ),
    "packetlab-binary.bin": (
        b"\x7fELF\x02\x01\x01\x00"
        + hashlib.sha256(b"packetlab-yara-binary").digest()
        + b"\x00PACKETLAB_BINARY_MARKER\x00LOCAL-TRAINING-ONLY\x00"
    ),
    "subdir/nested-config.cfg": (
        b"[packetlab]\n"
        b"fixture=yara\n"
        b"indicator=PACKETLAB_NESTED_MARKER\n"
    ),
}


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate local YARA practice fixtures.")
    parser.add_argument("fixture_dir", type=Path)
    parser.add_argument("manifest_path", type=Path)
    args = parser.parse_args()

    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)

    manifest = {"samples": []}
    for relative_name, data in SAMPLES.items():
        path = args.fixture_dir / relative_name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        manifest["samples"].append(
            {
                "name": relative_name,
                "size": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
            }
        )

    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
