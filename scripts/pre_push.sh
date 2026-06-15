# Pre-Push Checklist
# Run before every git push

# 1. Static analysis (must be 0 errors)
echo "=== 1. flutter analyze ==="
flutter analyze 2>&1 | grep " error •" && { echo "FAILED"; exit 1; } || echo "PASS"

# 2. All tests
echo "=== 2. flutter test ==="
flutter test 2>&1 | grep -q "All tests passed" && echo "PASS" || { echo "FAILED"; exit 1; }

# 3. Widget dump - verify pill sizes match
echo "=== 3. Widget dump ==="
flutter test test/dump_test.dart --plain-name "pill" 2>&1 | grep "^\["

echo ""
echo "=== ALL PASSED ==="
