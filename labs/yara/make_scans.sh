#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
RULES="/work/rules/packetlab.yar"
EXTERNAL_RULES="/work/rules/external-mode.yar"
COMPILED="$OUTPUT_DIR/packetlab.yarc"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -rf "$FIXTURE_DIR"/*
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.yarc

python3 /usr/local/bin/generate_fixture.py "$FIXTURE_DIR" "$OUTPUT_DIR/fixture-manifest.json"

yara --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
yara --version > "$OUTPUT_DIR/version.txt" 2>&1
find "$FIXTURE_DIR" -type f -print0 | sort -z | xargs -0 file > "$OUTPUT_DIR/file-types.txt"
find "$FIXTURE_DIR" -type f -print0 | sort -z | xargs -0 sha256sum > "$OUTPUT_DIR/sample-sha256.txt"

yara "$RULES" "$FIXTURE_DIR/packetlab-note.txt" > "$OUTPUT_DIR/text-match.txt"
yara -s -m -g "$RULES" "$FIXTURE_DIR/packetlab-note.txt" > "$OUTPUT_DIR/text-match-details.txt"
yara "$RULES" "$FIXTURE_DIR/packetlab-binary.bin" > "$OUTPUT_DIR/binary-match.txt"
yara -r "$RULES" "$FIXTURE_DIR" > "$OUTPUT_DIR/recursive-matches.txt"
yara -t binary "$RULES" "$FIXTURE_DIR/packetlab-binary.bin" > "$OUTPUT_DIR/tag-binary.txt"
yara -i PacketLab_Text_Indicator "$RULES" "$FIXTURE_DIR/packetlab-note.txt" > "$OUTPUT_DIR/identifier-filter.txt"
yara -d lab_mode=local "$EXTERNAL_RULES" "$FIXTURE_DIR/packetlab-note.txt" > "$OUTPUT_DIR/external-local.txt"
yara -d lab_mode=remote "$EXTERNAL_RULES" "$FIXTURE_DIR/packetlab-note.txt" > "$OUTPUT_DIR/external-remote.txt" || true
yara -c "$RULES" "$FIXTURE_DIR/packetlab-note.txt" > "$OUTPUT_DIR/count-text.txt"
yara -n "$RULES" "$FIXTURE_DIR/benign-note.txt" > "$OUTPUT_DIR/negated-benign.txt"
yara "$RULES" "$FIXTURE_DIR/benign-note.txt" > "$OUTPUT_DIR/benign-match.txt" || true

yarac "$RULES" "$COMPILED"
yara -C "$COMPILED" "$FIXTURE_DIR/packetlab-note.txt" > "$OUTPUT_DIR/compiled-match.txt"

{
  printf 'command\tpurpose\n'
  printf 'yara rules/packetlab.yar fixtures/packetlab-note.txt\tRun local rules against one sample.\n'
  printf 'yara -s -m -g rules/packetlab.yar sample\tPrint matching strings, metadata, and tags.\n'
  printf 'yara -r rules/packetlab.yar fixtures\tRecursively scan a local fixture directory.\n'
  printf 'yara -t binary rules/packetlab.yar packetlab-binary.bin\tFilter output to rules with a tag.\n'
  printf 'yara -d lab_mode=local rules/external-mode.yar sample\tPass an external variable into a rule.\n'
  printf 'yarac rules/packetlab.yar outputs/packetlab.yarc\tCompile rules for later scanning.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

jq -n \
  --arg rules "$RULES" \
  --arg version "$(cat "$OUTPUT_DIR/version.txt")" \
  --arg recursive_matches "$(wc -l < "$OUTPUT_DIR/recursive-matches.txt" | tr -d ' ')" \
  '{
    rules: $rules,
    yara_version: $version,
    recursive_matches: ($recursive_matches | tonumber)
  }' > "$OUTPUT_DIR/yara-summary.json"

if grep -q 'Usage: yara' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -Eq '^[0-9]+[.][0-9]+' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ "$(jq '.samples | length' "$OUTPUT_DIR/fixture-manifest.json")" -ge 4 ]; then
  fixtures_generated="yes"
else
  fixtures_generated="no"
fi

if grep -q 'PacketLab_Text_Indicator' "$OUTPUT_DIR/text-match.txt" \
  && grep -q 'PacketLab_Regex_Url' "$OUTPUT_DIR/text-match.txt"; then
  text_rules_matched="yes"
else
  text_rules_matched="no"
fi

if grep -q 'PacketLab_Binary_Indicator' "$OUTPUT_DIR/binary-match.txt"; then
  binary_rule_matched="yes"
else
  binary_rule_matched="no"
fi

if grep -q 'PacketLab_Nested_Config' "$OUTPUT_DIR/recursive-matches.txt"; then
  recursive_rule_matched="yes"
else
  recursive_rule_matched="no"
fi

if grep -q 'local_training' "$OUTPUT_DIR/text-match-details.txt" \
  && grep -q 'description' "$OUTPUT_DIR/text-match-details.txt"; then
  details_printed="yes"
else
  details_printed="no"
fi

if grep -q 'PacketLab_Binary_Indicator' "$OUTPUT_DIR/tag-binary.txt" \
  && ! grep -q 'PacketLab_Text_Indicator' "$OUTPUT_DIR/tag-binary.txt"; then
  tag_filter_worked="yes"
else
  tag_filter_worked="no"
fi

if grep -q 'PacketLab_External_Mode' "$OUTPUT_DIR/external-local.txt" \
  && ! grep -q 'PacketLab_External_Mode' "$OUTPUT_DIR/external-remote.txt"; then
  external_variable_worked="yes"
else
  external_variable_worked="no"
fi

if grep -Eq '^[0-9]+$' "$OUTPUT_DIR/count-text.txt"; then
  count_output_written="yes"
else
  count_output_written="no"
fi

if grep -q 'PacketLab_Text_Indicator' "$OUTPUT_DIR/compiled-match.txt"; then
  compiled_rules_worked="yes"
else
  compiled_rules_worked="no"
fi

if [ ! -s "$OUTPUT_DIR/benign-match.txt" ] && grep -q 'PacketLab_Text_Indicator' "$OUTPUT_DIR/negated-benign.txt"; then
  benign_negative_checked="yes"
else
  benign_negative_checked="no"
fi

if [ -s "$OUTPUT_DIR/sample-sha256.txt" ] && [ -s "$OUTPUT_DIR/yara-summary.json" ]; then
  summary_written="yes"
else
  summary_written="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'fixtures_generated\t%s\n' "$fixtures_generated"
  printf 'text_rules_matched\t%s\n' "$text_rules_matched"
  printf 'binary_rule_matched\t%s\n' "$binary_rule_matched"
  printf 'recursive_rule_matched\t%s\n' "$recursive_rule_matched"
  printf 'details_printed\t%s\n' "$details_printed"
  printf 'tag_filter_worked\t%s\n' "$tag_filter_worked"
  printf 'external_variable_worked\t%s\n' "$external_variable_worked"
  printf 'count_output_written\t%s\n' "$count_output_written"
  printf 'compiled_rules_worked\t%s\n' "$compiled_rules_worked"
  printf 'benign_negative_checked\t%s\n' "$benign_negative_checked"
  printf 'summary_written\t%s\n' "$summary_written"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'fixture_dir\t%s\n' "$FIXTURE_DIR"
  printf 'sample_count\t%s\n' "$(jq '.samples | length' "$OUTPUT_DIR/fixture-manifest.json")"
  printf 'yara_version\t%s\n' "$(cat "$OUTPUT_DIR/version.txt")"
  printf 'recursive_matches\t%s\n' "$(wc -l < "$OUTPUT_DIR/recursive-matches.txt" | tr -d ' ')"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated YARA lab outputs."
