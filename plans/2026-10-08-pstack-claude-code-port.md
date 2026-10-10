# `pstack` Claude Code Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert every element of `plugins/pstack` (manifest, 53 skills, 2 agents, docs) from Cursor format to the current Claude Code plugin format. Use two fixed model tiers: `opus` for complex work and `sonnet` for everyday work. Remove the TypeScript guidance skill and every reference to it.

**Architecture:** `plugins/pstack` becomes a Claude Code plugin with `.claude-plugin/plugin.json` and the default `skills/` and `agents/` folders. Each role that spawns a subagent names a fixed tier (`opus` or `sonnet`) in the skill text, so no model config file exists. Cursor tool names and parameters change to their Claude Code equivalents. Features with no Claude Code equivalent are removed. Skills keep `disable-model-invocation: true`. `poteto-mode` and `poteto-agent` reach the principle skills by reading `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md`.

**Tech Stack:** Markdown `SKILL.md` and agent files, JSON manifests, `claude plugin validate`, `grep` checks.

## Terms

- **Tier.** The model alias that a subagent role uses: `opus` or `sonnet`.
- **Role.** A named subagent job in a skill, for example "how explorer" or "swarm workers".
- **Panel.** A role that spawns one subagent per tier entry, for example "interrogate reviewers".
- **Cursor-ism.** A Cursor path, tool name, parameter, frontmatter key, or product feature that Claude Code does not have.

## Global Constraints

- Format source: the live Claude Code docs as of 2026-10-08:
  - <https://code.claude.com/docs/en/plugins-reference>
  - <https://code.claude.com/docs/en/skills>
  - <https://code.claude.com/docs/en/sub-agents>
- The only model values in the plugin are `opus` and `sonnet`. Do not use full model IDs, `grok-*` slugs, `effort` keys, or effort ladders.
- Keep `skills/poteto-mode/scripts/` (the TypeScript and bun tooling). Change only the `~/.cursor/projects` path in `worktree-audit.sh`. Do not change the `.ts` files.
- TypeScript removal covers only the `typescript-best-practices` skill and the lines that reference it. Keep TypeScript examples inside language-agnostic skills and agents. For example, keep `@ts-ignore` in `comment-sicko` and `*.test-d.ts` in `principle-test-behavior-not-implementation`.
- Keep Bugbot content (`references/bugbot-triage.md`, the Bugbot steps in the playbooks, and the `watch-pr` author matching). It works on GitHub PR comments. Remove only the wording that names Cursor product surfaces.
- Do not reword skill prose beyond the lines that this plan names. Keep the author's voice.
- Do not touch the deleted `automations/` folder.
- Do not commit. Show the diff to the human partner and wait for approval.

## Model tier map

Every role gets one fixed tier. Former `grok-*` roles use `sonnet`. Former `claude-opus-*` roles use `opus`.

| Role | Tier | Consumer |
|---|---|---|
| feature, refactoring | `sonnet` | `poteto-mode/playbooks/feature.md:12`, `refactoring.md:11`, `poteto-mode/SKILL.md:95` |
| bug-fix | `sonnet` | `playbooks/bug-fix.md:9` |
| perf-issue | `sonnet` | `playbooks/perf-issue.md:17` |
| hillclimb | `sonnet` | `playbooks/hillclimb.md:12` |
| judgment and prose | `opus` | `poteto-mode/SKILL.md:95` |
| hardest tasks | `opus` | `poteto-mode/SKILL.md:95` |
| how explorer | `sonnet` | `how/SKILL.md:27` |
| how explainer | `opus` | `how/SKILL.md:37`, `:47` |
| why investigators | `sonnet` | `why/SKILL.md:84` |
| why synthesizer | `opus` | `why/SKILL.md:128` |
| reflect tooling | `sonnet` | `reflect/SKILL.md:38` |
| reflect judgment, divergent, synthesizer | `opus` | `reflect/SKILL.md:37`, `:39`, `:45` |
| arena runners | `[opus, sonnet]` | `arena/SKILL.md:28` |
| arena cross-judge | `opus` | `arena/SKILL.md:41` |
| architect runners | `[opus, sonnet]` | `architect/SKILL.md:33` |
| interrogate reviewers | Reviewer A `opus`, Reviewer B `sonnet` | `interrogate/SKILL.md:36-48` |
| swarm workers | `sonnet` | `swarm/SKILL.md:25` |
| `poteto-agent` (agent file) | `opus` | `agents/poteto-agent.md` |
| `comment-sicko` (agent file) | `sonnet` | `agents/comment-sicko.md` |

Model diversity in panels now means two tiers of the same family. Change the "different model families" wording in `interrogate`, `arena`, `poteto-mode/SKILL.md:97`, `docs/guide/04-design.md` and `docs/guide/07-overnight.md:68` to "different tiers (`opus` and `sonnet`)".

## Cursor-to-Claude Code mapping

| Cursor | Claude Code |
|---|---|
| `.cursor-plugin/plugin.json` | `.claude-plugin/plugin.json` |
| `Task` tool | `Agent` tool |
| `subagent_type: generalPurpose` | `subagent_type: "general-purpose"` |
| `subagent_type: "poteto-agent"` | `subagent_type: "pstack:poteto-agent"` |
| `subagent_type: "Comment Sicko"` | `subagent_type: "pstack:comment-sicko"` |
| `readonly: true` | `general-purpose`, plus the brief line "Read-only: do not edit or write files, and do not run commands that change state." |
| `readonly: false`, plus "readonly strips MCP" notes | Remove the parameter and the note. |
| `model: <slug>`; "omit `model`" for `auto`/`inherit-parent` | `model: "opus"` or `model: "sonnet"` from the tier map. Remove the `auto`/`inherit-parent` aliases. |
| `environment: "cloud"`, `cloud_base_branch` | `run_in_background: true` and `isolation: "worktree"`. Tell the worker to check out the named branch in its worktree. |
| `is_background: true` (agent frontmatter) | `background: true` |
| `AskQuestion`, `allow_multiple: true` | `AskUserQuestion`, `multiSelect: true` |
| `~/.cursor/rules/pstack-models.mdc` | Removed. The tier map is in the skill text. |
| `.cursor/skills/`, `~/.cursor/skills/` | `.claude/skills/`, `~/.claude/skills/` |
| `~/.cursor/plugins/` | `~/.claude/plugins/` |
| `.cursor/worktrees/` | `.claude/worktrees/` |
| `~/.cursor/projects/<slug>/agent-transcripts/<uuid>/<uuid>.jsonl` | `~/.claude/projects/<slug>/<session-id>.jsonl`. Subagent transcripts are under `<session-id>/subagents/`. The slug is the absolute working directory with each `/` and `.` changed to `-`. |
| "The system prompt names the `agent-transcripts/` directory" | `${CLAUDE_SESSION_ID}` in the skill body, plus the slug rule above |
| `mcps/` directory, "available MCPs from the Cursor environment" | MCP tools named `mcp__<server>__<tool>`. Deferred MCP tools load through `ToolSearch`. |
| Cursor built-in `create-skill` | Write `.claude/skills/<name>/SKILL.md` directly, per `playbooks/authoring-a-skill.md` |
| Cursor's `/loop` | Claude Code `/loop` |
| Cursor Plan Mode | Claude Code plan mode |
| "Cursor restart" | "Claude Code restart" |
| Skill frontmatter `mode`, `icon`, `color`, `reminder` | Removed |

---

## File Map

### Create

- `plugins/pstack/.claude-plugin/plugin.json`: the Claude Code manifest.

### Delete

- `plugins/pstack/.cursor-plugin/` (the whole folder)
- `plugins/pstack/skills/typescript-best-practices/` (the whole folder)
- `plugins/pstack/skills/setup-pstack/` (the whole folder)
- `plugins/pstack/skills/make-bot-ui/` (the whole folder)
- `plugins/pstack/skills/poteto-mode/playbooks/autopilot-full.md`
- `plugins/pstack/skills/poteto-mode/playbooks/autopilot-stack.md`

### Modify

- Root `.claude-plugin/marketplace.json`: add the `pstack` entry.
- `plugins/pstack/agents/poteto-agent.md`, `plugins/pstack/agents/comment-sicko.md`
- Skills: `poteto-mode` (`SKILL.md`, 9 playbooks, `scripts/worktree-audit.sh`), `poteto-help` (`SKILL.md`, `references/recipes.md`), `swarm`, `interrogate`, `arena`, `architect`, `how`, `why`, `reflect` (`SKILL.md`, 4 references), `no-comments`, `automate-me`, `recall`, `show-me-your-work`, `create-verification-skill`, `maintain-verification-skill`, `principle-type-system-discipline`
- `plugins/pstack/README.md`; `plugins/pstack/docs/guide/01`, `02`, `04`, `05`, `06`, `07`, `09`, `10`

---

### Task 1: Manifest and marketplace

**Files:** Create `plugins/pstack/.claude-plugin/plugin.json`. Delete `plugins/pstack/.cursor-plugin/`. Modify `.claude-plugin/marketplace.json`.

- [ ] Create `plugin.json`. Copy `name`, `displayName`, `version` (`0.15.15`), `description`, `author`, `homepage`, `repository`, `license` and `keywords` from the Cursor manifest. Do not set `skills` or `agents`. Claude Code scans the default `skills/` and `agents/` folders. Remove the `logo`, `category` and `tags` keys, because Claude Code does not read them.
- [ ] Delete `.cursor-plugin/`.
- [ ] Add a `pstack` entry to the root `marketplace.json` with `"source": "./plugins/pstack"`, the description, the version, and author Lauren Tan.
- [ ] Check: `claude plugin validate plugins/pstack` shows `Validation passed` with no `Unknown field` warnings.

### Task 2: Remove the TypeScript skill and its references

**Files:**
- Delete `skills/typescript-best-practices/`.
- Modify `README.md:131`, `skills/poteto-help/SKILL.md:76`, `docs/guide/05-build-and-clean.md:53-56` and `skills/principle-type-system-discipline/SKILL.md:11`.

- [ ] Delete `skills/typescript-best-practices/` (`SKILL.md` and `references/patterns.md`).
- [ ] Remove the table row at `README.md:131`.
- [ ] Remove the table row at `skills/poteto-help/SKILL.md:76`.
- [ ] Remove the "Load the TypeScript rules by name" section at `docs/guide/05-build-and-clean.md:53-56`. Keep one blank line before `## Clean before you commit`.
- [ ] In `principle-type-system-discipline/SKILL.md:11`, keep "Applies to any typed language." Remove the sentence that names `typescript-best-practices`.
- [ ] Check: `grep -rn typescript-best-practices plugins/pstack --exclude-dir=.git --exclude-dir=automations` returns no lines.

### Task 3: Replace the model config with fixed tiers

**Files:**
- Delete `skills/setup-pstack/`.
- Modify `swarm`, `interrogate`, `arena`, `architect`, `how`, `why`, `reflect`, `poteto-mode/SKILL.md`, the playbooks `feature`, `refactoring`, `bug-fix`, `perf-issue` and `hillclimb`, and `poteto-help/SKILL.md`.

- [ ] Delete `skills/setup-pstack/`.
- [ ] In each consumer in the tier map, change the text that reads the `pstack-models.mdc` line to the fixed tier. Example for `swarm/SKILL.md:25`: "Workers run on `sonnet`. For a model race, name each arm's tier (`opus` or `sonnet`) up front."
- [ ] Remove the slug-fallback text: "If the Task tool rejects a slug…", "Families go by prefix…", and "open a separate PR to update the default table". The locations are `interrogate:48`, `arena:28`, `swarm:25`, `how:11`, `why:13` and `reflect:33`.
- [ ] Change the default-model table at `interrogate/SKILL.md:38-41` to Reviewer A `opus` and Reviewer B `sonnet`. Remove the "configured entry count" text at `:36`. The panel has two reviewers.
- [ ] `poteto-mode/SKILL.md:95`: code delegates use `sonnet`. Prose, judgment and the hardest changes use `opus`.
- [ ] Remove the `inherit-parent`/`auto` alias text from `poteto-help/SKILL.md:27` and `:43`, and from every consumer.
- [ ] Remove the `/setup-pstack` references from `poteto-help/SKILL.md` and `poteto-mode/SKILL.md`. Task 9 covers the README and the docs.
- [ ] Check: `grep -rniE 'grok|pstack-models|xhigh|inherit-parent|setup-pstack|claude-opus' plugins/pstack/skills plugins/pstack/agents` returns no lines.

### Task 4: Agents

**Files:** `agents/poteto-agent.md`, `agents/comment-sicko.md`.

- [ ] `poteto-agent.md` frontmatter: keep `name: poteto-agent` and `description`. Change `is_background: true` to `background: true`. Add `model: opus`.
- [ ] `poteto-agent.md` body: change "Read the `poteto-mode` skill's `SKILL.md`" to "Read `${CLAUDE_PLUGIN_ROOT}/skills/poteto-mode/SKILL.md`". Change "Navigate to a leaf `principle-*` skill" to "Read `${CLAUDE_PLUGIN_ROOT}/skills/<principle-name>/SKILL.md`".
- [ ] `poteto-agent.md` description: change "Substituting `generalPurpose`" to "Substituting `general-purpose`".
- [ ] `comment-sicko.md` frontmatter: change `name: Comment Sicko` to `name: comment-sicko`. Add `model: sonnet`.
- [ ] `comment-sicko.md:26`: keep the `/how` and `/why` invocations unchanged.
- [ ] Change every spawn site to the plugin-scoped names:
  - `no-comments/SKILL.md:19`: `subagent_type: "pstack:comment-sicko"`.
  - `poteto-mode/SKILL.md:93`, `playbooks/multi-phase-plan.md:7` and `poteto-help/SKILL.md:57`: `subagent_type: "pstack:poteto-agent"`.
- [ ] Check: both files pass `claude plugin validate`. `/agents` lists `pstack:poteto-agent` and `pstack:comment-sicko`.

### Task 5: Skill frontmatter and principle access

**Files:** `poteto-mode/SKILL.md` and every `SKILL.md` that uses a bare principle name as a read target.

- [ ] `poteto-mode/SKILL.md`: remove `mode`, `icon`, `color` and `reminder`. Change `name: Poteto Mode` to `name: poteto-mode`.
- [ ] `poteto-mode/SKILL.md`: add one line above the Principles index: "Principle skills live at `${CLAUDE_PLUGIN_ROOT}/skills/<principle-name>/SKILL.md`. Read the file. The Skill tool cannot load them, because they set `disable-model-invocation: true`."
- [ ] Keep `disable-model-invocation: true` on all skills.
- [ ] Check: each `SKILL.md` frontmatter has only the keys `name`, `description` and `disable-model-invocation`. Each `name` is kebab-case.

### Task 6: Tool names and parameters

**Files:** `how`, `why`, `reflect` (`SKILL.md` and `references/{tooling,judgment,divergent}-reviewer.md`), `swarm`, `interrogate`, `arena`, `no-comments`, `automate-me`, `poteto-mode/SKILL.md`, and the playbooks `opening-a-pr`, `orchestrate` and `autonomous-run`.

- [ ] Apply the Cursor-to-Claude Code mapping table to each hit of these names:
  - `Task`
  - `generalPurpose`
  - `readonly`
  - `environment`
  - `cloud_base_branch`
  - `AskQuestion`
  - `allow_multiple`
- [ ] `swarm/SKILL.md:9`, `:24`, `:30` and `:32`: workers are local background agents in their own worktrees. Remove "not the cloud concurrency limit".
- [ ] `reflect/references/*-reviewer.md`: change "Shell" to "Bash".
- [ ] `why/SKILL.md:64`: change the Cursor `mcps/` text to the `mcp__<server>__<tool>` and `ToolSearch` text from the mapping table.
- [ ] Check: `grep -rnE '\bTask\b tool|generalPurpose|readonly|environment: "|cloud_base_branch|AskQuestion|allow_multiple|is_background' plugins/pstack/skills plugins/pstack/agents` returns no lines.

### Task 7: Cursor paths and transcripts

**Files:**
- `recall`, `show-me-your-work`, `reflect/SKILL.md:19`, `automate-me`, `create-verification-skill`, `maintain-verification-skill`.
- The playbooks `session-pickup`, `eval` and `worktree-cleanup`.
- `reflect/references/*-reviewer.md` and `poteto-mode/scripts/worktree-audit.sh:25-27`.

- [ ] Change every `.cursor` path to its `.claude` path per the mapping table.
- [ ] `recall/SKILL.md:15`, `show-me-your-work`, `session-pickup.md:5`, `eval.md:22` and `automate-me/SKILL.md:29`: use the Claude Code transcript path and the slug rule. Find the current session file with `${CLAUDE_SESSION_ID}`.
- [ ] Check the JSONL line format in a real `~/.claude/projects/<slug>/<session-id>.jsonl` file. Correct the format claims in `recall` and `show-me-your-work`, for example "Every line is one chat message". Each line has a `type` field. Only `user` and `assistant` lines carry messages.
- [ ] `worktree-audit.sh:25-27`: change `$HOME/.cursor/projects/$slug/agent-transcripts` to `$HOME/.claude/projects/$slug`.
- [ ] `worktree-cleanup.md:10`: remove `~/Library/Application Support/Cursor`.
- [ ] Check: `grep -rn '\.cursor' plugins/pstack/skills plugins/pstack/agents` returns no lines. `bash -n plugins/pstack/skills/poteto-mode/scripts/worktree-audit.sh` passes.

### Task 8: Remove Cursor-only features

**Files:**
- Delete `skills/make-bot-ui/`, `playbooks/autopilot-full.md` and `playbooks/autopilot-stack.md`.
- Modify `poteto-mode/SKILL.md`, the playbooks `opening-a-pr`, `multi-phase-plan`, `orchestrate`, `shipping`, `babysit`, `autonomous-run` and `authoring-a-skill`, plus `reflect/SKILL.md` and `reflect/references/synthesizer.md`.
- Modify `poteto-help/SKILL.md` and `poteto-help/references/recipes.md`.

- [ ] Delete `skills/make-bot-ui/`.
- [ ] Delete the Autopilot-full and Autopilot-stack playbooks. Remove their index rows at `poteto-mode/SKILL.md:141-142` and the Autopilot clause at `opening-a-pr.md:36`. Remove their routing lines at `poteto-help/SKILL.md:118` and `poteto-help/references/recipes.md:44-45`.
- [ ] `orchestrate.md`: workers and verifiers run as local background agents with `isolation: "worktree"`. Remove the cloud default and the local exception list at `:17` and `:54`, and remove "Restacks run in cloud" at `:80`. At `:95`, change the Cursor dashboard to the agent's task output and the `/agents` panel. At `:101`, change "After a Cursor restart: local agents are dead, cloud work is not" to "After a Claude Code restart, background agents are dead." Reattach the work by PR and branch.
- [ ] `multi-phase-plan.md:71`: remove the cloud-VM lane sentence.
- [ ] `shipping.md:7` and `poteto-mode/SKILL.md:143`: remove "Cursor cloud agent" and "cloud-agent URL".
- [ ] Remove the `cursor-team-kit` references:
  - Remove the `/deslop` steps at `poteto-mode/SKILL.md:28`, `opening-a-pr.md:9` and `:36`, and `multi-phase-plan.md:59`.
  - Remove the `control-ui`/`control-cli` references at `poteto-mode/SKILL.md:30`, `multi-phase-plan.md:15` and `orchestrate.md:17`. Point each one to the repository's `verify-<app>` skill, which `/create-verification-skill` creates.
  - Remove `poteto-help/SKILL.md:106`.
- [ ] Change the Cursor built-in references to Claude Code:
  - `create-skill` in `authoring-a-skill.md:5`, `automate-me` (`:11`, `:67`, `:72`, `:77`, `:102`), `reflect/SKILL.md:62` and `synthesizer.md:17`, `:44`.
  - `/loop` in `autonomous-run.md:6`.
  - The built-in `/babysit` comparison at `poteto-mode/SKILL.md:32`.
- [ ] Bugbot: keep the logic. Change "Cursor dashboard" and "Cursor Bugbot" wording to "Bugbot". Do not change `watch-pr`.
- [ ] Check: `grep -rniE 'cursor|autopilot|make-bot-ui|cursor-team-kit|deslop' plugins/pstack/skills plugins/pstack/agents` returns only hits in `scripts/watch-pr/*.ts` (Bugbot author matching).

### Task 9: README and guide

**Files:** `README.md` and `docs/guide/01`, `02`, `04`, `05`, `06`, `07`, `09`, `10`.

- [ ] Install text (`README.md:18`, `01-setup.md:7-13`): `/plugin marketplace add <repo>` and `/plugin install pstack@superpowers-dev`.
- [ ] Models (`README.md:11`, `:25`, `:30`, `:255-257`; `01-setup.md:15-46`): replace the setup section with the tier map summary. Code delegates run on `sonnet`. Judgment, prose and the hardest changes run on `opus`. Panels use one of each.
- [ ] Remove the `/setup-pstack` rows and links (`README.md:124`, `04-design.md:47`) and the `/make-bot-ui` rows (`README.md:123`, `09-make-it-yours.md:94-96`).
- [ ] Remove the Autopilot rows and sections (`README.md:71-72`, `07-overnight.md:74-83` and `:100`, `02-poteto-mode.md:28`). Change "twenty-three playbooks" to "twenty-one playbooks" (`README.md:38` and `:51`, `02-poteto-mode.md:3`).
- [ ] Custom Mode text (`README.md:91`, `01-setup.md:60`, `02-poteto-mode.md:85`): replace it with `/pstack:poteto-mode` per task, or with `claude --agent pstack:poteto-agent` for a whole session.
- [ ] Replace the Cursor features with their Claude Code equivalents or remove them:
  - `/loop` (`README.md:93`, `07-overnight.md:35`)
  - plan mode (`README.md:247`)
  - `cursor-team-kit` (`README.md:239-243`, `05-build-and-clean.md:59` and `:79`)
  - cloud subagents (`02-poteto-mode.md:99`, `10-recipes-and-pitfalls.md:144`, which become worktree isolation)
  - Cursor Project (`07-overnight.md:94`)
  - `auto` as a slug (`10-recipes-and-pitfalls.md:150`)
  - `.cursor/skills` (`01-setup.md:35`, `06-verify-and-ship.md:61`, `09-make-it-yours.md:13`)
- [ ] Keep the author bio lines (`README.md:3`, `:7`) unchanged.
- [ ] Check: `grep -rniE 'cursor|grok|setup-pstack|autopilot|make-bot-ui' plugins/pstack/README.md plugins/pstack/docs` returns only the author bio lines.

### Task 10: End-to-end check

- [ ] `claude plugin validate plugins/pstack --strict` passes.
- [ ] Load the plugin locally: `claude --plugin-dir plugins/pstack`. `/` lists `pstack:poteto-mode` and does not list `typescript-best-practices`, `setup-pstack` or `make-bot-ui`.
- [ ] Run `/pstack:poteto-mode explain how <some function> works`. The agent reads `${CLAUDE_PLUGIN_ROOT}/skills/poteto-mode/SKILL.md` and a principle file by absolute path. The `how` skill spawns the explorer on `sonnet` and the explainer on `opus`.
- [ ] Run `/pstack:interrogate` on a small diff. It spawns two reviewers: one on `opus`, one on `sonnet`.
- [ ] Run `/pstack:no-comments` on a diff. It spawns `pstack:comment-sicko` on `sonnet`.
- [ ] Run all the grep checks from Tasks 2–9 again. Each returns only the allowed hits.
- [ ] Show the complete diff to the human partner. Commit only after explicit approval.
