#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

claude \
  --print \
  --permission-mode acceptEdits \
  --model sonnet \
  --max-budget-usd 8 \
  "$(cat docs/ai-workflow/prompts/claude_task_1_domain_storage.md)"
