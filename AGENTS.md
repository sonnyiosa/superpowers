# Sonny skills contributor guidance

This is Sonny's personal agents repository. Superpowers, SWE Skills, and pstack are separate bundled plugins. Work here targets this repository. Do not submit personal customizations to their upstream projects.

## Repository boundaries

- `skills/<name>/SKILL.md` contains personal skills.
- `development_skills/` contains drafts that are not installed.
- `plugins/superpowers/` owns Superpowers skills, hooks, harness adapters, assets, documentation, and tests.
- `plugins/swe-skills/` and `plugins/pstack/` own their respective distributions.
- Root marketplace catalogs, scripts, and tests manage the collection.

Keep every plugin self-contained. Runtime files must resolve resources inside their plugin directory. Do not mirror bundled skills into root `skills/` or add root hooks that duplicate a plugin bootstrap. Preserve upstream licenses and attribution.

Plugin versions are independent. Update marketplace entries when a plugin version changes. Run `python3 scripts/check-layout.py` after any layout or manifest change. Run the affected plugin tests and collection tests before reporting completion.

For multi-file implementation and architecture changes, use `pstack:poteto-mode`. Keep migration work separate from changes to skill behavior. Follow a plugin's own skill-development and evaluation guidance when changing its skill content.

## CodeGraph

If `.codegraph/` exists at the repository root, use `codegraph explore "<symbol or question>"` or the CodeGraph MCP before searching or reading code to understand it. If the directory does not exist, skip CodeGraph. Indexing is the operator's decision.

## Review and publication

Do not publish, push, or open upstream PRs unless requested. Show the complete diff and get explicit approval before submitting a PR to Superpowers upstream. Its retained contributor guidance lives at `plugins/superpowers/AGENTS.md`.
