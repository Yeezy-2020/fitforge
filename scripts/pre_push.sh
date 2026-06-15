#!/bin/bash
# pre_push.sh - Runs before every git push
# Usage: bash scripts/pre_push.sh

set -e
export PATH="/opt/flutter/bin:$PATH"

echo "============================================"
echo "  FitForge Pre-Push Check"
echo "============================================"

echo ""
echo "1/3 flutter analyze..."
ERRORS=$(flutter analyze 2>&1 | grep -c " error •")
if [ "$ERRORS" -gt 0 ]; then
  echo "   FAILED: $ERRORS errors found"
  exit 1
fi
echo "   PASSED (0 errors)"

echo ""
echo "2/3 flutter test..."
flutter test
if [ $? -ne 0 ]; then
  echo "ERROR: flutter test failed"
  exit 1
fi
echo "   PASSED"

echo ""
echo "3/3 Widget tree dump (pill buttons)..."
flutter test test/dump_test.dart 2>&1 | grep "^\[" || true
echo "   DONE"

echo ""
echo "============================================"
echo "  ALL CHECKS PASSED - Ready to push"
echo "============================================"
