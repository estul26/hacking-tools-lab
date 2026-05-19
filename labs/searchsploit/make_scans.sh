#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

searchsploit -h > "$OUTPUT_DIR/help.txt" 2>&1 || true
dpkg-query -W -f='${Package}\t${Version}\n' exploitdb > "$OUTPUT_DIR/version.txt" 2>&1 || true

searchsploit --json apache 2.4 > "$OUTPUT_DIR/apache-24.json" 2>"$OUTPUT_DIR/apache-24.log"
searchsploit --json -t wordpress 5.0 > "$OUTPUT_DIR/wordpress-50-title.json" 2>"$OUTPUT_DIR/wordpress-50-title.log"
searchsploit --json --cve 2021-41773 > "$OUTPUT_DIR/cve-2021-41773.json" 2>"$OUTPUT_DIR/cve-2021-41773.log"
searchsploit --www --id apache 2.4 > "$OUTPUT_DIR/apache-24-www.txt" 2>"$OUTPUT_DIR/apache-24-www.log"
searchsploit -p 50383 > "$OUTPUT_DIR/path-50383.txt" 2>"$OUTPUT_DIR/path-50383.log" || true
searchsploit --nmap "$FIXTURE_DIR/nmap-apache.xml" > "$OUTPUT_DIR/nmap-apache.txt" 2>"$OUTPUT_DIR/nmap-apache.log" || true

{
  printf 'query\tresults\n'
  printf 'apache-24\t%s\n' "$(jq '.RESULTS_EXPLOIT | length' "$OUTPUT_DIR/apache-24.json")"
  printf 'wordpress-50-title\t%s\n' "$(jq '.RESULTS_EXPLOIT | length' "$OUTPUT_DIR/wordpress-50-title.json")"
  printf 'cve-2021-41773\t%s\n' "$(jq '.RESULTS_EXPLOIT | length' "$OUTPUT_DIR/cve-2021-41773.json")"
} > "$OUTPUT_DIR/result-counts.tsv"

{
  printf 'check\tstatus\n'
  if jq -e '.RESULTS_EXPLOIT[] | select(.Title | test("Apache"; "i"))' "$OUTPUT_DIR/apache-24.json" >/dev/null; then
    printf 'apache_search\tyes\n'
  else
    printf 'apache_search\tno\n'
  fi
  if jq -e '.RESULTS_EXPLOIT[] | select(.Title | test("WordPress"; "i"))' "$OUTPUT_DIR/wordpress-50-title.json" >/dev/null; then
    printf 'wordpress_title_search\tyes\n'
  else
    printf 'wordpress_title_search\tno\n'
  fi
  if jq -e '.RESULTS_EXPLOIT[] | select(.Codes | test("CVE-2021-41773"; "i"))' "$OUTPUT_DIR/cve-2021-41773.json" >/dev/null; then
    printf 'cve_search\tyes\n'
  else
    printf 'cve_search\tno\n'
  fi
  if grep -Fq '50383' "$OUTPUT_DIR/path-50383.txt" && grep -Fq '/usr/share/exploitdb/' "$OUTPUT_DIR/path-50383.txt"; then
    printf 'path_lookup\tyes\n'
  else
    printf 'path_lookup\tno\n'
  fi
  if grep -Fq 'https://www.exploit-db.com/exploits/' "$OUTPUT_DIR/apache-24-www.txt"; then
    printf 'www_output\tyes\n'
  else
    printf 'www_output\tno\n'
  fi
  if grep -Eiq 'Apache|Exploit Title|searchsploit' "$OUTPUT_DIR/nmap-apache.txt"; then
    printf 'nmap_fixture_search\tyes\n'
  else
    printf 'nmap_fixture_search\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
  printf 'json_queries\t%s\n' "$(awk 'NR > 1 {count++} END {print count + 0}' "$OUTPUT_DIR/result-counts.tsv")"
  printf 'apache_results\t%s\n' "$(awk -F'\t' '$1 == "apache-24" {print $2}' "$OUTPUT_DIR/result-counts.tsv")"
  printf 'wordpress_results\t%s\n' "$(awk -F'\t' '$1 == "wordpress-50-title" {print $2}' "$OUTPUT_DIR/result-counts.tsv")"
  printf 'cve_results\t%s\n' "$(awk -F'\t' '$1 == "cve-2021-41773" {print $2}' "$OUTPUT_DIR/result-counts.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Searchsploit lab outputs."
