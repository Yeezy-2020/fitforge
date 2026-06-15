#!/bin/bash
# pre_push.sh - Runs before every git push
set -e
export PATH="/opt/flutter/bin:$PATH"

echo "=== FitForge Check ==="

# 1. Analyze
echo -n "analyze... "
if flutter analyze 2>&1 | grep -q " error •"; then
  echo "FAIL"
  flutter analyze 2>&1 | grep " error •"
  exit 1
fi
echo "OK"

# 2. Test
echo -n "test... "
if ! flutter test 2>&1 | grep -q "All tests passed"; then
  echo "FAIL"
  exit 1
fi
echo "OK"

# 3. Dump key elements
echo "--- Widget Dump ---"
flutter test test/dump_test.dart 2>&1 | grep "^\[" || echo "(dump skipped)"

echo "=== All Good ==="
