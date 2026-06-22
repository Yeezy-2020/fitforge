#!/bin/bash
set -e
export PATH="/opt/flutter/bin:$PATH"

echo "=== 1. flutter analyze ==="
flutter analyze --no-fatal-infos --no-fatal-warnings
echo "PASS"

echo "=== 2. flutter test ==="
flutter test 2>&1 | grep -q "All tests passed" && echo "PASS" || { echo "FAILED"; exit 1; }

echo "=== 3. Widget dump ==="
flutter test test/dump_test.dart --plain-name "pill" 2>&1 | grep "^\[" || echo "(skipped)"

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
