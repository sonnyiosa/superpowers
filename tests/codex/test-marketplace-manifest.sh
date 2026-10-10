#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

python3 "$REPO_ROOT/scripts/check-layout.py"
python3 - "$REPO_ROOT/plugins/superpowers" <<'CHECK'
import json
import sys
from pathlib import Path

plugin = Path(sys.argv[1])
manifest = json.loads((plugin / ".codex-plugin/plugin.json").read_text())
assert manifest["hooks"] == {}, "Codex must suppress Claude hook auto-discovery"
assert (plugin / "hooks/hooks.json").is_file(), "Claude hook must remain plugin-local"
assert (plugin / "skills/using-superpowers/SKILL.md").is_file(), "bootstrap skill missing"
print("PASS: nested Codex plugin retains bootstrap resources and suppresses Claude hooks")
CHECK
