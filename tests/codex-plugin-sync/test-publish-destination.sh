#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

source_repo="$TEST_ROOT/source"
dest_repo="$TEST_ROOT/destination"
remote_repo="$TEST_ROOT/remote.git"
fake_bin="$TEST_ROOT/bin"
export SYNC_TEST_CAPTURE="$TEST_ROOT/capture"
mkdir -p "$source_repo/scripts" "$source_repo/plugins/superpowers/.codex-plugin" \
  "$source_repo/plugins/superpowers/skills/example" "$dest_repo/plugins/superpowers/skills/example" \
  "$fake_bin" "$SYNC_TEST_CAPTURE"
cp "$REPO_ROOT/scripts/sync-to-codex-plugin.sh" "$source_repo/scripts/"
printf '{"name":"superpowers","version":"7.0.0"}\n' > "$source_repo/plugins/superpowers/.codex-plugin/plugin.json"
printf 'new skill\n' > "$source_repo/plugins/superpowers/skills/example/SKILL.md"
printf 'old skill\n' > "$dest_repo/plugins/superpowers/skills/example/SKILL.md"
for repo in "$source_repo" "$dest_repo"; do
  git init -q -b main "$repo"
  git -C "$repo" config user.name 'Test Bot'
  git -C "$repo" config user.email 'test@example.com'
  git -C "$repo" add .
  git -C "$repo" commit -q -m 'Fixture'
done
git init -q --bare "$remote_repo"
git -C "$dest_repo" remote add origin "$remote_repo"
git -C "$dest_repo" push -q origin main
printf 'uncommitted personal note\n' > "$source_repo/personal-note.md"

cat > "$fake_bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == 'auth status' ]]; then exit 0; fi
[[ "$1 $2" == 'pr create' ]] || exit 1
shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) printf '%s\n' "$2" > "$SYNC_TEST_CAPTURE/repo"; shift 2 ;;
    --body-file) cp "$2" "$SYNC_TEST_CAPTURE/body.md"; shift 2 ;;
    *) shift ;;
  esac
done
printf 'https://github.com/test-owner/test-destination/pull/1\n'
GH
chmod +x "$fake_bin/gh"

if PATH="$fake_bin:$PATH" bash "$source_repo/scripts/sync-to-codex-plugin.sh" \
  -y --local "$dest_repo" > "$TEST_ROOT/refused.log" 2>&1; then
  echo 'FAIL: publishing accepted a missing repository' >&2
  exit 1
fi
grep -Fq 'publishing requires --repo OWNER/REPO' "$TEST_ROOT/refused.log"
[[ "$(git -C "$dest_repo" branch --show-current)" == main ]]
[[ "$(cat "$dest_repo/plugins/superpowers/skills/example/SKILL.md")" == 'old skill' ]]
echo 'PASS: missing publication repository is refused before destination mutation'

PATH="$fake_bin:$PATH" bash "$source_repo/scripts/sync-to-codex-plugin.sh" \
  -y --local "$dest_repo" --repo test-owner/test-destination > "$TEST_ROOT/published.log" 2>&1
[[ "$(cat "$SYNC_TEST_CAPTURE/repo")" == test-owner/test-destination ]]
[[ "$(cat "$dest_repo/plugins/superpowers/skills/example/SKILL.md")" == 'new skill' ]]
branch="$(git -C "$dest_repo" branch --show-current)"
[[ "$(git -C "$dest_repo" rev-parse HEAD)" == "$(git --git-dir="$remote_repo" rev-parse "$branch")" ]]
grep -Fq "$(git -C "$source_repo" rev-parse HEAD)" "$SYNC_TEST_CAPTURE/body.md"
grep -Fq 'Source working tree: uncommitted changes' "$SYNC_TEST_CAPTURE/body.md"
if grep -Fq 'github.com/obra/superpowers/commit' "$SYNC_TEST_CAPTURE/body.md"; then
  echo 'FAIL: publication misattributes a personal source commit' >&2
  exit 1
fi
grep -Fq 'https://github.com/test-owner/test-destination/pull/1/files' "$TEST_ROOT/published.log"
echo 'PASS: changed publication uses the explicit repository, actual source commit, and valid diff URL'
