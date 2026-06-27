#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

codex exec \
  -C "$(pwd)" \
  -s read-only \
  "$(cat docs/ai-workflow/prompts/gpt_review_task_2.md)

Inspect the repository's uncommitted changes yourself with git commands. Do not
modify files."
