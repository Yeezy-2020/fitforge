#!/bin/bash
set -e

if [ -x "/home/dyy/flutter/bin/flutter" ]; then
  FLUTTER="/home/dyy/flutter/bin/flutter"
elif [ -x "/opt/flutter/bin/flutter" ]; then
  FLUTTER="/opt/flutter/bin/flutter"
else
  FLUTTER="flutter"
fi

export NO_PROXY="localhost,127.0.0.1,${NO_PROXY:-}"
export no_proxy="localhost,127.0.0.1,${no_proxy:-}"

echo "=== 1. flutter analyze ==="
"$FLUTTER" analyze --no-fatal-infos --no-fatal-warnings
echo "PASS"

echo "=== 2. flutter test ==="
"$FLUTTER" test 2>&1 | grep -q "All tests passed" && echo "PASS" || { echo "FAILED"; exit 1; }

echo "=== 3. Widget dump ==="
"$FLUTTER" test test/dump_test.dart --plain-name "pill" 2>&1 | grep "^\[" || echo "(skipped)"

echo "=== 4. Dead button check ==="
DEAD=$(grep -rn "onPressed: () => {}" lib/ --include="*.dart" | wc -l)
if [ "$DEAD" -gt 0 ]; then
  echo "FAILED: $DEAD dead button(s) found!"
  grep -rn "onPressed: () => {}" lib/ --include="*.dart"
  exit 1
else
  echo "PASS (0 dead buttons)"
fi

echo ""
echo "=== ALL PASSED ==="
