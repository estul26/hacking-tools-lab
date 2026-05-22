#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


SOURCE = r'''#include <stdint.h>
#include <stdio.h>
#include <string.h>

static const char *packetlab_banner = "PACKETLAB_R2_FIXTURE v1.0";
static const char *packetlab_url = "http://127.0.0.1:8080/radare2";
static const char *packetlab_token = "LOCAL-TRAINING-ONLY-NOT-A-REAL-SECRET";

int packetlab_check_mode(const char *mode) {
    if (mode == NULL) {
        return 0;
    }
    if (strcmp(mode, "local") == 0) {
        return 42;
    }
    return -1;
}

uint32_t packetlab_mix(uint32_t value) {
    value ^= 0x504b544cU;
    value = (value << 7) | (value >> 25);
    value += 0x13371337U;
    return value;
}

void packetlab_local_status(void) {
    printf("%s\n", packetlab_banner);
    printf("status_url=%s\n", packetlab_url);
    printf("training_token=%s\n", packetlab_token);
}

int main(int argc, char **argv) {
    const char *mode = argc > 1 ? argv[1] : "offline";
    int check = packetlab_check_mode(mode);
    uint32_t mixed = packetlab_mix((uint32_t)check);
    packetlab_local_status();
    printf("mode=%s check=%d mixed=%08x\n", mode, check, mixed);
    return check == 42 ? 0 : 1;
}
'''


def deterministic_blob(size: int) -> bytes:
    output = bytearray()
    counter = 0
    while len(output) < size:
        output.extend(hashlib.sha256(f"packetlab-r2-{counter}".encode("ascii")).digest())
        counter += 1
    return bytes(output[:size])


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate local radare2 practice fixtures.")
    parser.add_argument("fixture_dir", type=Path)
    parser.add_argument("manifest_path", type=Path)
    args = parser.parse_args()

    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)

    source_path = args.fixture_dir / "packetlab-r2-sample.c"
    source_path.write_text(SOURCE, encoding="utf-8")

    raw_path = args.fixture_dir / "packetlab-r2-raw.bin"
    raw_blob = bytearray(deterministic_blob(1024))
    raw_blob[0:8] = b"PKTLABR2"
    raw_blob[0x100:0x100 + 26] = b"PACKETLAB_RAW_R2_MARKER\x00"
    raw_blob[0x180:0x180 + 23] = b"R2_RAW_MODE=LOCAL_ONLY\x00"
    raw_path.write_bytes(raw_blob)

    manifest = {
        "source": str(source_path),
        "raw_blob": str(raw_path),
        "raw_blob_size": len(raw_blob),
        "raw_blob_sha256": hashlib.sha256(raw_blob).hexdigest(),
        "expected_symbols": [
            "main",
            "packetlab_check_mode",
            "packetlab_mix",
            "packetlab_local_status",
        ],
        "expected_strings": [
            "PACKETLAB_R2_FIXTURE v1.0",
            "http://127.0.0.1:8080/radare2",
            "LOCAL-TRAINING-ONLY-NOT-A-REAL-SECRET",
        ],
    }
    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
