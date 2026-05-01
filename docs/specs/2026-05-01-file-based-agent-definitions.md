# File-Based Agent Definitions

## Problem

Agent prompts, metadata, and permissions for the subagent-driven-development workflow (`@explore`, `@implementer-sp`, `@spec-reviewer-sp`, `@code-reviewer-sp`) are hardcoded in `AGENT_PROMPTS` and `AGENT_DEFAULTS` inside `.opencode/plugins/superpowers.js`. This makes them:

- Hard to discover (buried in JS code)
- Difficult to extend (must edit the plugin JS to add a new agent)
- Tightly coupled to the plugin implementation

## Solution

Move all agent definitions from inline JS objects to individual markdown files in the `agents/` directory. Each `.md` file follows the [OpenCode agent markdown format](https://opencode.ai/docs/agents/#markdown) — frontmatter with all metadata + body as the system prompt.

The plugin auto-discovers agent files from `agents/` at startup and registers them with OpenCode via the `config.agent` hook.

## Agent File Format

Follows the OpenCode standard for markdown agents. Filename becomes the agent name.

```
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

You are Explorer - a fast codebase navigation specialist...
```

### Fields (OpenCode Standard)

| Field | Required | Description |
|-------|----------|-------------|
| `description` | yes | User-facing description shown in agent list |
| `mode` | no | `primary`, `subagent`, or `all` (default `all`) |
| `model` | no | Model override (default `inherit` — uses parent agent's model) |
| `temperature` | no | Model temperature (0.0–1.0; defaults to model-specific) |
| `permission` | no | Permission rules (e.g., `{ "*": "deny", grep: "allow" }`) |
| `hidden` | no | Hide from @ autocomplete (`true`/`false`, default `false`) |
| `steps` | no | Max agentic iterations before forced text response |
| `color` | no | Hex color or theme token for UI |
| `top_p` | no | Response diversity (0.0–1.0) |

**No `name` field** — the filename (without `.md`) is the agent name.
**No `tools` field** — deprecated in OpenCode; use `permission` instead.

Body is the system prompt text, which becomes the agent's system instructions.

## Plugin Changes

1. **Remove** `AGENT_PROMPTS` and `AGENT_DEFAULTS` constants from `superpowers.js`
2. **Add** `loadAgentsFromDirectory(dir)` function that:
   - Reads all `*.md` files from the `agents/` directory
   - Parses YAML frontmatter using existing `extractAndStripFrontmatter` helper
   - Extracts remaining body as the `prompt` field
   - Returns `{ filename: config }` keyed by agent name (file stem)
3. **Update** `config` hook to call `loadAgentsFromDirectory` instead of referencing hardcoded objects
4. **Preserve** merge order: agent file config → user overrides from `superpowers.jsonc`

### Frontmatter → Config mapping

| Frontmatter key | Config key | Notes |
|-----------------|------------|-------|
| `description` | `description` | Pass through |
| `mode` | `mode` | Pass through |
| `model` | `model` | Pass through |
| `temperature` | `temperature` | Pass through |
| `permission` | `permission` | Pass through |
| `hidden` | `hidden` | Pass through |
| `steps` | `steps` | Pass through |
| `color` | `color` | Pass through |
| `top_p` | `top_p` | Pass through |
| Body | `prompt` | System prompt text |

Any unknown frontmatter keys pass through as-is (OpenCode forwards them to the provider as model options).

## Migration

Create 4 new files in `agents/` following the OpenCode markdown format:

- `explore.md` — from `AGENT_PROMPTS.explore` + `AGENT_DEFAULTS.explore`
- `implementer-sp.md` — from `AGENT_PROMPTS.implementer-sp` + `AGENT_DEFAULTS.implementer-sp`
- `spec-reviewer-sp.md` — from `AGENT_PROMPTS.spec-reviewer-sp` + `AGENT_DEFAULTS.spec-reviewer-sp`
- `code-reviewer-sp.md` — from `AGENT_PROMPTS.code-reviewer-sp` + `AGENT_DEFAULTS.code-reviewer-sp`

The existing `agents/code-reviewer.md` stays as-is — it's a user-facing agent that follows the OpenCode standard and is unrelated to the internal `code-reviewer-sp`.

## Non-Goals

- Agent file validation (invalid frontmatter is caught at parse time)
- Hot-reloading agents (plugin config runs once at startup)
- Directory recursion (only top-level `*.md` files in `agents/`)
- Changing existing `code-reviewer.md` (stays as-is)

## Backward Compatibility

`superpowers.jsonc` overrides still work — agent file config is loaded first, then user overrides from the JSONC file are merged on top.
