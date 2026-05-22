#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


SOURCE = r'''#include <stdint.h>
#include <stdio.h>
#include <string.h>

static const char packetlab_banner[] = "PACKETLAB_OBJDUMP_FIXTURE v1.0";
static const char packetlab_url[] = "http://127.0.0.1:8080/objdump";
static const uint32_t packetlab_table[] = {
    0x504b544cU, 0x4f424a44U, 0x554d5044U, 0x13371337U
};

int packetlab_check_mode(const char *mode) {
    if (mode == NULL) {
        return 0;
    }
    if (strcmp(mode, "local") == 0) {
        return 7;
    }
    return -3;
}

uint32_t packetlab_fold(uint32_t seed) {
    for (unsigned int i = 0; i < 4; i++) {
        seed ^= packetlab_table[i];
        seed = (seed << 5) | (seed >> 27);
    }
    return seed;
}

void packetlab_print_status(const char *mode) {
    int check = packetlab_check_mode(mode);
    uint32_t folded = packetlab_fold((uint32_t)check);
    printf("%s\n", packetlab_banner);
    printf("url=%s\n", packetlab_url);
    printf("mode=%s check=%d folded=%08x\n", mode, check, folded);
}

int main(int argc, char **argv) {
    const char *mode = argc > 1 ? argv[1] : "offline";
    packetlab_print_status(mode);
    return packetlab_check_mode(mode) == 7 ? 0 : 1;
}
'''


def deterministic_blob(size: int) -> bytes:
    output = bytearray()
    counter = 0
    while len(output) < size:
        output.extend(hashlib.sha256(f"packetlab-objdump-{counter}".encode("ascii")).digest())
        counter += 1
    return bytes(output[:size])


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate local objdump practice fixtures.")
    parser.add_argument("fixture_dir", type=Path)
    parser.add_argument("manifest_path", type=Path)
    args = parser.parse_args()

    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)

    source_path = args.fixture_dir / "packetlab-objdump-sample.c"
    source_path.write_text(SOURCE, encoding="utf-8")

    raw_path = args.fixture_dir / "packetlab-objdump-data.bin"
    raw_blob = bytearray(deterministic_blob(512))
    raw_blob[0:10] = b"PKTOBJDUMP"
    raw_blob[0x80:0x80 + 28] = b"PACKETLAB_OBJDUMP_RAW_MARKER"
    raw_path.write_bytes(raw_blob)

    manifest = {
        "source": str(source_path),
        "raw_blob": str(raw_path),
        "raw_blob_size": len(raw_blob),
        "raw_blob_sha256": hashlib.sha256(raw_blob).hexdigest(),
        "expected_symbols": [
            "main",
            "packetlab_check_mode",
            "packetlab_fold",
            "packetlab_print_status",
        ],
        "expected_strings": [
            "PACKETLAB_OBJDUMP_FIXTURE v1.0",
            "http://127.0.0.1:8080/objdump",
            "local",
        ],
    }
    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
