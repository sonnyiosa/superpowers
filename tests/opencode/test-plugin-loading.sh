#!/usr/bin/env bash
# Test: Plugin Loading
# Verifies that the superpowers plugin loads correctly in OpenCode
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Test: Plugin Loading ==="

# Source setup to create isolated environment
source "$SCRIPT_DIR/setup.sh"

# Trap to cleanup on exit
trap cleanup_test_env EXIT

plugin_link="$OPENCODE_CONFIG_DIR/plugins/superpowers.js"

# Test 1: Verify plugin file exists and is registered
echo "Test 1: Checking plugin registration..."
if [ -L "$plugin_link" ]; then
    echo "  [PASS] Plugin symlink exists"
else
    echo "  [FAIL] Plugin symlink not found at $plugin_link"
    exit 1
fi

# Verify symlink target exists
if [ -f "$(readlink -f "$plugin_link")" ]; then
    echo "  [PASS] Plugin symlink target exists"
else
    echo "  [FAIL] Plugin symlink target does not exist"
    exit 1
fi

# Test 2: Verify skills directory is populated
echo "Test 2: Checking skills directory..."
skill_count=$(find "$SUPERPOWERS_SKILLS_DIR" -name "SKILL.md" | wc -l)
if [ "$skill_count" -gt 0 ]; then
    echo "  [PASS] Found $skill_count skills"
else
    echo "  [FAIL] No skills found in $SUPERPOWERS_SKILLS_DIR"
    exit 1
fi

# Test 3: Check using-superpowers skill exists (critical for bootstrap)
echo "Test 3: Checking using-superpowers skill (required for bootstrap)..."
if [ -f "$SUPERPOWERS_SKILLS_DIR/using-superpowers/SKILL.md" ]; then
    echo "  [PASS] using-superpowers skill exists"
else
    echo "  [FAIL] using-superpowers skill not found (required for bootstrap)"
    exit 1
fi

# Test 4: Verify plugin JavaScript syntax (basic check)
echo "Test 4: Checking plugin JavaScript syntax..."
if node --check "$SUPERPOWERS_PLUGIN_FILE" 2>/dev/null; then
    echo "  [PASS] Plugin JavaScript syntax is valid"
else
    echo "  [FAIL] Plugin has JavaScript syntax errors"
    exit 1
fi

# Test 5: Verify AGENT_PROMPTS was removed and bootstrap does not reference a wrong skills path
echo "Test 5a: Checking AGENT_PROMPTS constant was removed..."
if grep -q 'const AGENT_PROMPTS' "$SUPERPOWERS_PLUGIN_FILE"; then
    echo "  [FAIL] Plugin still has AGENT_PROMPTS constant"
    exit 1
else
    echo "  [PASS] AGENT_PROMPTS constant removed"
fi

echo "Test 5b: Checking bootstrap does not advertise a wrong skills path..."
if grep -q 'configDir}/skills/superpowers/' "$SUPERPOWERS_PLUGIN_FILE"; then
    echo "  [FAIL] Plugin still references old configDir skills path"
    exit 1
else
    echo "  [PASS] Plugin does not advertise a misleading skills path"
fi

# Test 6: Verify personal test skill was created
echo "Test 6: Checking test fixtures..."
if [ -f "$OPENCODE_CONFIG_DIR/skills/personal-test/SKILL.md" ]; then
    echo "  [PASS] Personal test skill fixture created"
else
    echo "  [FAIL] Personal test skill fixture not found"
    exit 1
fi

# Test 7: Verify superpowers.jsonc is scaffolded and drives agent config
echo "Test 7: Checking superpowers.jsonc scaffolding and config merge..."
superpowers_config="$HOME/.config/opencode/superpowers.jsonc"

if [ -f "$superpowers_config" ]; then
    echo "  [FAIL] superpowers.jsonc should not exist before plugin initialization"
    exit 1
fi

node_output=$(node --input-type=module <<'EOF'
import path from 'path';
import { pathToFileURL } from 'url';
import fs from 'fs';

const pluginPath = path.join(process.env.HOME, '.config/opencode/superpowers/.opencode/plugins/superpowers.js');
const { SuperpowersPlugin } = await import(pathToFileURL(pluginPath).href);
const plugin = await SuperpowersPlugin({ client: {}, directory: process.cwd() });

const initialConfig = {};
await plugin.config(initialConfig);

const scaffoldPath = path.join(process.env.HOME, '.config/opencode/superpowers.jsonc');
const scaffoldExists = fs.existsSync(scaffoldPath);
const scaffoldContent = scaffoldExists ? fs.readFileSync(scaffoldPath, 'utf8') : '';

fs.writeFileSync(
  scaffoldPath,
  `{
  // Override default subagent models here.
  "agent": {
    "implementer-sp": { "model": "anthropic/claude-haiku-4-5" },
    "spec-reviewer-sp": { "model": "anthropic/claude-sonnet-4-5" },
    "code-reviewer-sp": { "model": "anthropic/claude-opus-4-1" }
  }
}
`
);

const overriddenConfig = {};
await plugin.config(overriddenConfig);

console.log(JSON.stringify({
  scaffoldExists,
  scaffoldContent,
  initialModel: initialConfig.agent?.['implementer-sp']?.model,
  overrideModel: overriddenConfig.agent?.['implementer-sp']?.model,
  overrideSpecModel: overriddenConfig.agent?.['spec-reviewer-sp']?.model,
  overrideCodeModel: overriddenConfig.agent?.['code-reviewer-sp']?.model,
  overridePromptPresent: Boolean(overriddenConfig.agent?.['implementer-sp']?.prompt)
}));
EOF
)

if echo "$node_output" | grep -q '"scaffoldExists":true'; then
    echo "  [PASS] superpowers.jsonc was scaffolded on first config hook run"
else
    echo "  [FAIL] superpowers.jsonc was not scaffolded"
    echo "  Output: $node_output"
    exit 1
fi

if echo "$node_output" | grep -q 'anthropic/claude-sonnet-4-6'; then
    echo "  [PASS] Scaffolded config includes agent defaults"
else
    echo "  [FAIL] Scaffolded config missing agent defaults"
    echo "  Output: $node_output"
    exit 1
fi

if echo "$node_output" | grep -q '"overrideModel":"anthropic/claude-haiku-4-5"'; then
    echo "  [PASS] implementer model is loaded from superpowers.jsonc"
else
    echo "  [FAIL] implementer model was not loaded from superpowers.jsonc"
    echo "  Output: $node_output"
    exit 1
fi

if echo "$node_output" | grep -q '"overrideSpecModel":"anthropic/claude-sonnet-4-5"'; then
    echo "  [PASS] spec reviewer model is loaded from superpowers.jsonc"
else
    echo "  [FAIL] spec reviewer model was not loaded from superpowers.jsonc"
    echo "  Output: $node_output"
    exit 1
fi

if echo "$node_output" | grep -q '"overrideCodeModel":"anthropic/claude-opus-4-1"'; then
    echo "  [PASS] code reviewer model is loaded from superpowers.jsonc"
else
    echo "  [FAIL] code reviewer model was not loaded from superpowers.jsonc"
    echo "  Output: $node_output"
    exit 1
fi

if echo "$node_output" | grep -q '"overridePromptPresent":true'; then
    echo "  [PASS] plugin still injects agent prompts after config merge"
else
    echo "  [FAIL] agent prompt was lost after config merge"
    echo "  Output: $node_output"
    exit 1
fi

# Test 8: Verify agents are loaded from agents/ directory
echo "Test 8: Checking agents loaded from files..."

agent_count=$(find "$SUPERPOWERS_DIR/agents" -name "*.md" | wc -l)
if [ "$agent_count" -ge 4 ]; then
    echo "  [PASS] Found $agent_count agent files in agents/ directory"
else
    echo "  [FAIL] Expected at least 4 agent files, found $agent_count"
    exit 1
fi

# Verify specific agent files exist
for agent in "explore.md" "implementer-sp.md" "spec-reviewer-sp.md" "code-reviewer-sp.md"; do
    if [ -f "$SUPERPOWERS_DIR/agents/$agent" ]; then
        echo "  [PASS] Agent file $agent exists"
    else
        echo "  [FAIL] Agent file $agent not found"
        exit 1
    fi
done

# Verify existing user-facing agent still exists
if [ -f "$SUPERPOWERS_DIR/agents/code-reviewer.md" ]; then
    echo "  [PASS] User-facing code-reviewer.md still exists"
else
    echo "  [FAIL] code-reviewer.md was removed"
    exit 1
fi

# Verify the plugin loads agents from files
node_output=$(node --input-type=module <<'EOF'
import path from 'path';
import { pathToFileURL } from 'url';

const pluginPath = path.join(process.env.HOME, '.config/opencode/superpowers/.opencode/plugins/superpowers.js');
const { SuperpowersPlugin } = await import(pathToFileURL(pluginPath).href);
const plugin = await SuperpowersPlugin({ client: {}, directory: process.cwd() });

const testConfig = {};
await plugin.config(testConfig);

console.log(JSON.stringify({
  hasExplore: Boolean(testConfig.agent?.explore),
  hasImplementer: Boolean(testConfig.agent?.['implementer-sp']),
  hasSpecReviewer: Boolean(testConfig.agent?.['spec-reviewer-sp']),
  hasCodeReviewer: Boolean(testConfig.agent?.['code-reviewer-sp']),
  exploreHasPrompt: Boolean(testConfig.agent?.explore?.prompt),
  implementerHasPrompt: Boolean(testConfig.agent?.['implementer-sp']?.prompt),
  specReviewerHasPrompt: Boolean(testConfig.agent?.['spec-reviewer-sp']?.prompt),
  codeReviewerHasPrompt: Boolean(testConfig.agent?.['code-reviewer-sp']?.prompt),
  exploreHasPermission: Boolean(testConfig.agent?.explore?.permission),
}));
EOF
)

for key in "hasExplore" "hasImplementer" "hasSpecReviewer" "hasCodeReviewer" "exploreHasPrompt" "implementerHasPrompt" "specReviewerHasPrompt" "codeReviewerHasPrompt" "exploreHasPermission"; do
    if echo "$node_output" | grep -q "\"$key\":true"; then
        echo "  [PASS] $key is true"
    else
        echo "  [FAIL] $key is false"
        echo "  Output: $node_output"
        exit 1
    fi
done

echo ""
echo "=== All plugin loading tests passed ==="
