#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


SOURCE = r'''#include <stdint.h>
#include <stdio.h>
#include <string.h>

static const char packetlab_banner[] = "PACKETLAB_READELF_FIXTURE v1.0";
static const char packetlab_url[] = "http://127.0.0.1:8080/readelf";
static const uint64_t packetlab_build_id = 0x52454144454c4601ULL;

int packetlab_check_mode(const char *mode) {
    if (mode == NULL) {
        return 0;
    }
    if (strcmp(mode, "local") == 0) {
        return 11;
    }
    return -5;
}

uint64_t packetlab_rotate(uint64_t seed) {
    seed ^= packetlab_build_id;
    seed = (seed << 9) | (seed >> 55);
    seed += 0x20260522ULL;
    return seed;
}

void packetlab_print_status(const char *mode) {
    int check = packetlab_check_mode(mode);
    uint64_t rotated = packetlab_rotate((uint64_t)(uint32_t)check);
    printf("%s\n", packetlab_banner);
    printf("url=%s\n", packetlab_url);
    printf("mode=%s check=%d rotated=%016llx\n", mode, check, (unsigned long long)rotated);
}

int main(int argc, char **argv) {
    const char *mode = argc > 1 ? argv[1] : "offline";
    packetlab_print_status(mode);
    return packetlab_check_mode(mode) == 11 ? 0 : 1;
}
'''


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate local readelf practice fixtures.")
    parser.add_argument("fixture_dir", type=Path)
    parser.add_argument("manifest_path", type=Path)
    args = parser.parse_args()

    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)

    source_path = args.fixture_dir / "packetlab-readelf-sample.c"
    source_path.write_text(SOURCE, encoding="utf-8")
    source_bytes = source_path.read_bytes()

    manifest = {
        "source": str(source_path),
        "source_size": len(source_bytes),
        "source_sha256": hashlib.sha256(source_bytes).hexdigest(),
        "expected_symbols": [
            "main",
            "packetlab_check_mode",
            "packetlab_rotate",
            "packetlab_print_status",
        ],
        "expected_strings": [
            "PACKETLAB_READELF_FIXTURE v1.0",
            "http://127.0.0.1:8080/readelf",
            "local",
        ],
    }
    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
