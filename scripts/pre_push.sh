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
if "$FLUTTER" test; then
  echo "PASS"
else
  test_status=$?
  echo "FAILED (flutter test exited with status $test_status)"
  exit "$test_status"
fi

echo "=== 3. Widget dump ==="
widget_dump_log=$(mktemp)
trap 'rm -f "$widget_dump_log"' EXIT
if "$FLUTTER" test test/dump_test.dart --plain-name "pill" >"$widget_dump_log" 2>&1; then
  if ! grep "^\[" "$widget_dump_log"; then
    echo "(no widget dump lines)"
  fi
else
  widget_dump_status=$?
  cat "$widget_dump_log"
  echo "FAILED (widget dump test exited with status $widget_dump_status)"
  exit "$widget_dump_status"
fi

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
