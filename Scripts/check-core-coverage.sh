#!/usr/bin/env bash
set -euo pipefail

THRESHOLD="${1:-80}"

PROFDATA="$(find .build -name default.profdata | head -n 1 || true)"
TEST_BINARY="$(find .build -path '*VitalBarPackageTests.xctest/Contents/MacOS/VitalBarPackageTests' | head -n 1 || true)"

if [[ -z "${PROFDATA}" || -z "${TEST_BINARY}" ]]; then
    echo "Failed to locate coverage artifacts (.profdata / test binary)."
    exit 1
fi

xcrun llvm-cov export -summary-only -instr-profile "${PROFDATA}" "${TEST_BINARY}" > coverage-summary.json

python3 - "${THRESHOLD}" <<'PY'
import json
import pathlib
import sys

threshold = float(sys.argv[1])

with open("coverage-summary.json", "r", encoding="utf-8") as f:
    report = json.load(f)

files = report.get("data", [{}])[0].get("files", [])
covered = 0
count = 0

for entry in files:
    filename = entry.get("filename", "")
    if "/Sources/VitalBarCore/" not in filename:
        continue

    line_summary = entry.get("summary", {}).get("lines", {})
    covered += int(line_summary.get("covered", 0))
    count += int(line_summary.get("count", 0))

if count == 0:
    print("No line coverage information found for Sources/VitalBarCore.")
    sys.exit(1)

coverage = (covered / count) * 100.0
summary = f"VitalBarCore line coverage: {coverage:.2f}% (threshold {threshold:.2f}%)"
print(summary)
pathlib.Path("coverage-summary.txt").write_text(summary + "\n", encoding="utf-8")

if coverage < threshold:
    print("Coverage gate failed.")
    sys.exit(1)
PY
