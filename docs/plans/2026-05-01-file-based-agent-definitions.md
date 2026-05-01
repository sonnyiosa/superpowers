# File-Based Agent Definitions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move agent definitions from hardcoded JS objects (`AGENT_PROMPTS` + `AGENT_DEFAULTS` in `superpowers.js`) to individual OpenCode-standard markdown files in the `agents/` directory.

**Architecture:** The plugin's `config` hook currently reads `AGENT_PROMPTS` and `AGENT_DEFAULTS` to register agents. After this change, it reads all `*.md` files from `agents/`, parses YAML frontmatter + body, and builds agent configs dynamically. Each `.md` file follows the OpenCode agent markdown format (filename = agent name, frontmatter = metadata, body = system prompt). `superpowers.jsonc` user overrides still merge on top.

**Tech Stack:** Node.js (ESM), YAML frontmatter (via existing `extractAndStripFrontmatter` helper), OpenCode plugin API

---

## File Structure

### New files (4)
- `agents/explore.md` — explore agent prompt + config
- `agents/implementer-sp.md` — implementer agent prompt + config
- `agents/spec-reviewer-sp.md` — spec reviewer agent prompt + config
- `agents/code-reviewer-sp.md` — code reviewer agent prompt + config

### Modified files (1)
- `.opencode/plugins/superpowers.js` — remove `AGENT_PROMPTS`, `AGENT_DEFAULTS`, add `loadAgentsFromDirectory()`

### Modified test files (1)
- `tests/opencode/test-plugin-loading.sh` — update test to verify agents loaded from files

### Unchanged
- `agents/code-reviewer.md` — user-facing agent, stays as-is

---

### Task 1: Migrate agent definitions to `agents/` files

**Files:**
- Create: `agents/explore.md`
- Create: `agents/implementer-sp.md`
- Create: `agents/spec-reviewer-sp.md`
- Create: `agents/code-reviewer-sp.md`

- [ ] **Step 1: Create `agents/explore.md`**

```markdown
---
description: |
  Fast codebase search and pattern matching. Use for finding files,
  locating code patterns, and answering 'where is X?' questions.
mode: subagent
temperature: 0.1
permission:
  "*": deny
  grep: allow
  glob: allow
  list: allow
  bash: allow
  read: allow
  webfetch: allow
  websearch: allow
  codesearch: allow
---

You are Explorer - a fast codebase navigation specialist for the superpowers subagent-driven development workflow.

**Role**: Quick contextual grep for codebases. Answer "Where is X?", "Find Y", "Which file has Z".

**When to use which tools**:
- **Text/regex patterns** (strings, comments, variable names): grep
- **Structural patterns** (function shapes, class structures): ast_grep_search
- **File discovery** (find by name/extension): glob

**Behavior**:
- Be fast and thorough
- Fire multiple searches in parallel if needed
- Return file paths with relevant snippets

**Output Format**:
<results>
<files>
- /path/to/file.ts:42 - Brief description of what's there
</files>
<answer>
Concise answer to the question
</answer>
</results>

**Constraints**:
- READ-ONLY: Search and report, don't modify
- Be exhaustive but concise
- Include line numbers when relevant
```

- [ ] **Step 2: Create `agents/implementer-sp.md`**

```markdown
---
description: |
  Implements tasks from plan, writes code, tests, and commits.
  Dispatched by the subagent-driven-development workflow controller.
mode: subagent
permission:
  edit: allow
  bash:
    "*": allow
---

You are an implementation agent for the superpowers subagent-driven development workflow.

Your job is to implement a task from a plan. The controller will provide:
- Full task description (from the plan)
- Context (where this fits, dependencies, architecture)

## Before You Begin

If you have questions about the requirements, approach, dependencies, or anything unclear — ask them now. Raise concerns before starting work.

## Your Job

Once you're clear on requirements:
1. Implement exactly what the task specifies
2. Write tests (following TDD if task says to)
3. Verify implementation works
4. Commit your work
5. Self-review (see below)
6. Report back

**While you work:** If you encounter something unexpected or unclear, ask questions. Don't guess or make assumptions.

## Before Reporting Back: Self-Review

Review your work with fresh eyes:

**Completeness:** Did I implement everything in the spec? Miss any requirements? Edge cases?
**Quality:** Is this my best work? Are names clear? Is code clean and maintainable?
**Discipline:** Did I avoid overbuilding (YAGNI)? Only build what was requested? Follow existing patterns?
**Testing:** Do tests verify behavior (not mocks)? Did I follow TDD if required? Are tests comprehensive?

If you find issues during self-review, fix them before reporting.

## Report Format

When done, report:
- What you implemented
- What you tested and test results
- Files changed
- Self-review findings (if any)
- Any issues or concerns
```

- [ ] **Step 3: Create `agents/spec-reviewer-sp.md`**

```markdown
---
description: |
  Verifies implementation matches spec, catches missing or extra work.
  Dispatched by the subagent-driven-development workflow controller.
mode: subagent
---

You are a spec compliance reviewer for the superpowers subagent-driven development workflow.

Your job is to verify that an implementation matches its specification — nothing more, nothing less.

The controller will provide:
- Full task requirements (from the plan)
- Implementer's report of what they claim they built

## CRITICAL: Do Not Trust the Report

The implementer's report may be incomplete, inaccurate, or optimistic. You MUST verify everything independently.

**DO NOT:** Take their word for what they implemented. Trust their claims about completeness. Accept their interpretation of requirements.

**DO:** Read the actual code they wrote. Compare actual implementation to requirements line by line. Check for missing pieces. Look for extra features they didn't mention.

**Verify by reading code, not by trusting report.**

## Your Job

Read the implementation code and verify:

**Missing requirements:** Did they implement everything requested? Are there requirements they skipped? Did they claim something works but didn't actually implement it?

**Extra/unneeded work:** Did they build things that weren't requested? Did they over-engineer? Did they add "nice to haves" not in spec?

**Misunderstandings:** Did they interpret requirements differently than intended? Did they solve the wrong problem?

## Report Format

- ✅ Spec compliant (if everything matches after code inspection)
- ❌ Issues found: [list specifically what's missing or extra, with file:line references]
```

- [ ] **Step 4: Create `agents/code-reviewer-sp.md`**

```markdown
---
description: |
  Deep code review — architecture, quality, security, production readiness.
  Dispatched by the subagent-driven-development workflow controller.
mode: subagent
---

You are a senior code reviewer for the superpowers subagent-driven development workflow.

You review code changes for production readiness. Only dispatched after spec compliance passes.

The controller will provide:
- What was implemented (from implementer's report)
- Plan/requirements reference
- Git SHA range to review

## Review Checklist

**Code Quality:** Clean separation of concerns? Proper error handling? Type safety? DRY? Edge cases handled?
**Architecture:** Sound design decisions? Scalability? Performance implications? Security concerns?
**Testing:** Tests actually test logic (not mocks)? Edge cases covered? Integration tests where needed? All tests passing?
**Requirements:** All plan requirements met? No scope creep? Breaking changes documented?
**Production Readiness:** Migration strategy? Backward compatibility? No obvious bugs?

## Output Format

### Strengths
[What's well done? Be specific with file:line references.]

### Issues

#### Critical (Must Fix)
[Bugs, security issues, data loss risks]

#### Important (Should Fix)
[Architecture problems, missing features, poor error handling, test gaps]

#### Minor (Nice to Have)
[Code style, optimization, documentation]

**For each issue:** file:line reference, what's wrong, why it matters, how to fix.

### Assessment
**Ready to merge?** [Yes/No/With fixes]
**Reasoning:** [1-2 sentences]

## Rules
- Categorize by actual severity (not everything is Critical)
- Be specific (file:line, not vague)
- Explain WHY issues matter
- Acknowledge strengths
- Give clear verdict
```

- [ ] **Step 5: Commit agent markdown files**

```bash
git add agents/explore.md agents/implementer-sp.md agents/spec-reviewer-sp.md agents/code-reviewer-sp.md
git commit -m "feat: add agent definition files following OpenCode markdown format"
```

---

### Task 2: Refactor `superpowers.js` to load agents from filesystem

**Files:**
- Modify: `.opencode/plugins/superpowers.js`

- [ ] **Step 1: Remove `AGENT_PROMPTS` constant**

Delete lines 74-235 (the entire `AGENT_PROMPTS` object definition).

- [ ] **Step 2: Remove `AGENT_DEFAULTS` constant**

Delete lines 237-269 (the entire `AGENT_DEFAULTS` object definition).

- [ ] **Step 3: Add `loadAgentsFromDirectory` function**

Add after the `deepMerge` function (after line 69):

```javascript
const loadAgentsFromDirectory = (agentsDir) => {
  const agents = {};
  if (!fs.existsSync(agentsDir)) return agents;

  const files = fs.readdirSync(agentsDir).filter(f => f.endsWith('.md'));
  for (const file of files) {
    const filePath = path.join(agentsDir, file);
    const content = fs.readFileSync(filePath, 'utf8');
    const { frontmatter, content: body } = extractAndStripFrontmatter(content);
    if (!frontmatter.description) continue; // skip files without agent metadata

    const name = path.basename(file, '.md');
    agents[name] = {
      ...frontmatter,
      prompt: body.trim(),
    };
  }
  return agents;
};
```

- [ ] **Step 4: Update the `config` hook to use `loadAgentsFromDirectory`**

Replace the agent registration loop (lines 360-369):

```javascript
const agentsDir = path.resolve(__dirname, '../../agents');
const fileAgents = loadAgentsFromDirectory(agentsDir);

for (const [name, config] of Object.entries(fileAgents)) {
  agents[name] = {
    ...(agents[name] || {}),  // user overrides from superpowers.jsonc
    ...config,                 // file-based config (frontmatter + prompt)
  };
}
```

Wait — this reverses the merge order. Let me think about this more carefully.

**Current merge logic:**
```javascript
agents[name] = {
  ...defaults,         // AGENT_DEFAULTS (mode, tools, permission)
  ...AGENT_PROMPTS[name],  // prompt, description, temperature
  ...(agents[name] || {})  // user overrides from superpowers.jsonc
};
```

Current order: defaults → prompts → user overrides (user wins).

**New merge logic should be:**
```javascript
agents[name] = {
  ...fileConfig,            // from agents/*.md (frontmatter + prompt)
  ...(superpowersConfig.agent?.[name] || {}),  // user overrides from superpowers.jsonc
};
```

Order: file config → user overrides (user wins). This is simpler and correct.

The `agents` variable is already `mergedConfig.agent || {}` which contains user overrides from superpowers.jsonc. So:

```javascript
const agentsDir = path.resolve(__dirname, '../../agents');
const fileAgents = loadAgentsFromDirectory(agentsDir);

for (const [name, config] of Object.entries(fileAgents)) {
  agents[name] = {
    ...config,
    ...(agents[name] || {}),
  };
}
```

- [ ] **Step 5: Verify the plugin has no syntax errors or broken references**

```bash
node --check .opencode/plugins/superpowers.js
```

- [ ] **Step 6: Commit the plugin changes**

```bash
git add .opencode/plugins/superpowers.js
git commit -m "refactor: load agent definitions from agents/ directory instead of hardcoded JS objects"
```

---

### Task 3: Update test setup and plugin loading test

**Files:**
- Modify: `tests/opencode/setup.sh`
- Modify: `tests/opencode/test-plugin-loading.sh`

- [ ] **Step 1: Update `setup.sh` to also copy the `agents/` directory**

After the skills copy (line 28: `cp -r "$REPO_ROOT/skills" "$SUPERPOWERS_DIR/"`), add:

```bash
# Install agents
cp -r "$REPO_ROOT/agents" "$SUPERPOWERS_DIR/"
```

- [ ] **Step 2: Update `test-plugin-loading.sh` Test 5 to check AGENT_PROMPTS removal**

Replace the existing Test 5 (lines 63-70) with:

```bash
# Test 5: Verify AGENT_PROMPTS was removed and bootstrap does not reference a wrong skills path
echo "Test 5: Checking plugin no longer has AGENT_PROMPTS constant..."
if grep -q 'const AGENT_PROMPTS' "$SUPERPOWERS_PLUGIN_FILE"; then
    echo "  [FAIL] Plugin still has AGENT_PROMPTS constant"
    exit 1
else
    echo "  [PASS] AGENT_PROMPTS constant removed"
fi

if grep -q 'configDir}/skills/superpowers/' "$SUPERPOWERS_PLUGIN_FILE"; then
    echo "  [FAIL] Plugin still references old configDir skills path"
    exit 1
else
    echo "  [PASS] Plugin does not advertise a misleading skills path"
fi
```

- [ ] **Step 3: Add Test 8 for agent file loading from `agents/` directory**

After the existing Test 7 (line 181) and before the final pass message, add:

```bash
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

# Verify the plugin loads agents from files by checking node output
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
}));
EOF
)

for key in "hasExplore" "hasImplementer" "hasSpecReviewer" "hasCodeReviewer" "exploreHasPrompt" "implementerHasPrompt" "specReviewerHasPrompt" "codeReviewerHasPrompt"; do
    if echo "$node_output" | grep -q "\"$key\":true"; then
        echo "  [PASS] $key is true"
    else
        echo "  [FAIL] $key is false"
        echo "  Output: $node_output"
        exit 1
    fi
done
```

Note: Uses existing `$SUPERPOWERS_DIR` env var (already exported by `setup.sh`).

- [ ] **Step 4: Run the test suite to verify everything passes**

```bash
cd tests/opencode && bash run-tests.sh --verbose
```

- [ ] **Step 5: Commit the test changes**

```bash
git add tests/opencode/setup.sh tests/opencode/test-plugin-loading.sh
git commit -m "test: add agent file loading verification to plugin tests"
```

---

## Self-Review Checklist

1. **Spec coverage:**
   - Task 1 covers creating agent files (spec section "Migration")
   - Task 2 covers plugin refactoring (spec section "Plugin Changes")
   - Task 3 covers test updates (spec section "Backward Compatibility")
   - All spec requirements are covered: OpenCode markdown format (✓), no `name` in frontmatter (✓), no `tools` field (✓), `description` required (✓)

2. **Placeholder scan:** No TBDs, TODOs, or incomplete code blocks.

3. **Type consistency:** The `loadAgentsFromDirectory` returns `{ name: { ...frontmatter, prompt: body } }` which matches the expected agent config shape. Frontmatter keys map directly to config keys (per spec mapping table).
