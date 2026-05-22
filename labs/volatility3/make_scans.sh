#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
FIXTURE="$FIXTURE_DIR/toy-memory.raw"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$FIXTURE"

python3 /usr/local/bin/generate_fixture.py \
  "$FIXTURE" \
  "$OUTPUT_DIR/fixture-manifest.json" \
  "$OUTPUT_DIR/fixture-strings.tsv"

vol -h > "$OUTPUT_DIR/help.txt" 2>&1
/opt/volatility3/bin/python - <<'PY' > "$OUTPUT_DIR/version.txt"
import importlib.metadata
print(importlib.metadata.version("volatility3"))
PY

vol -q --offline frameworkinfo.FrameworkInfo > "$OUTPUT_DIR/frameworkinfo.txt" 2>&1
vol -q --offline isfinfo.IsfInfo > "$OUTPUT_DIR/isfinfo.txt" 2>&1
vol -q --offline linux.pslist.PsList --help > "$OUTPUT_DIR/linux-pslist-help.txt" 2>&1
vol -q --offline windows.info.Info --help > "$OUTPUT_DIR/windows-info-help.txt" 2>&1
vol -q --offline -f "$FIXTURE" banners.Banners > "$OUTPUT_DIR/banners.txt" 2>&1
vol -q --offline -f "$FIXTURE" windows.info.Info > "$OUTPUT_DIR/windows-info-expected-failure.txt" 2>&1 || true

strings -a -tx "$FIXTURE" > "$OUTPUT_DIR/strings.txt"
grep -E 'VOLLAB_MARKER|packetlab-agent|LOCAL_TRAINING_ONLY|127\.0\.0\.1' \
  "$OUTPUT_DIR/strings.txt" > "$OUTPUT_DIR/string-hits.txt"

sha256sum "$FIXTURE" > "$OUTPUT_DIR/fixture-sha256.txt"

{
  printf 'artifact\tpurpose\n'
  printf 'toy-memory.raw\tGenerated local practice image with a Linux banner and lab strings.\n'
  printf 'banners.txt\tVolatility3 banner scan against the toy image.\n'
  printf 'string-hits.txt\tLocal strings triage for known lab markers.\n'
  printf 'windows-info-expected-failure.txt\tExpected profile/symbol failure against a non-Windows toy image.\n'
  printf 'fixture-manifest.json\tGround truth offsets for the generated local fixture.\n'
} > "$OUTPUT_DIR/artifacts.tsv"

if grep -q 'An open-source memory forensics framework' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -Eq '^[0-9]+[.][0-9]+' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ -s "$FIXTURE" ] && grep -q '"sha256"' "$OUTPUT_DIR/fixture-manifest.json"; then
  fixture_generated="yes"
else
  fixture_generated="no"
fi

if grep -q 'banners.Banners' "$OUTPUT_DIR/help.txt"; then
  plugins_listed="yes"
else
  plugins_listed="no"
fi

if grep -q 'Linux version 5.15.0-volatility3-lab' "$OUTPUT_DIR/banners.txt"; then
  banner_found="yes"
else
  banner_found="no"
fi

if grep -q 'VOLLAB_MARKER=packetlab-memory-fixture' "$OUTPUT_DIR/string-hits.txt"; then
  marker_found="yes"
else
  marker_found="no"
fi

if grep -qi 'unsatisfied\|Unable to validate\|requirements' "$OUTPUT_DIR/windows-info-expected-failure.txt"; then
  expected_failure_recorded="yes"
else
  expected_failure_recorded="no"
fi

if grep -q 'sha256' "$OUTPUT_DIR/fixture-manifest.json" && [ -s "$OUTPUT_DIR/fixture-sha256.txt" ]; then
  hash_recorded="yes"
else
  hash_recorded="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'fixture_generated\t%s\n' "$fixture_generated"
  printf 'plugins_listed\t%s\n' "$plugins_listed"
  printf 'banner_found\t%s\n' "$banner_found"
  printf 'marker_found\t%s\n' "$marker_found"
  printf 'expected_failure_recorded\t%s\n' "$expected_failure_recorded"
  printf 'hash_recorded\t%s\n' "$hash_recorded"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'fixture\t%s\n' "$FIXTURE"
  printf 'fixture_size_bytes\t%s\n' "$(wc -c < "$FIXTURE" | tr -d ' ')"
  printf 'volatility3_version\t%s\n' "$(cat "$OUTPUT_DIR/version.txt")"
  printf 'banner_hits\t%s\n' "$(grep -c 'Linux version 5.15.0-volatility3-lab' "$OUTPUT_DIR/banners.txt" || true)"
  printf 'string_hits\t%s\n' "$(wc -l < "$OUTPUT_DIR/string-hits.txt" | tr -d ' ')"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Volatility3 lab outputs."
