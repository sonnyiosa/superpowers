# Set up pstack

In this page you install the plugin and run your first task.

## Install the plugin

In Claude Code, run:

```text
/plugin marketplace add sonnyiosa/superpowers
/plugin install pstack@superpowers-dev
```

Claude Code confirms the plugin is installed.

## Models

There is nothing to configure. pstack uses fixed tiers. Code delegates (feature, refactoring, bug fix, perf, hillclimb) and explorers, investigators, and swarm workers run on `sonnet`. Judgment, prose, synthesis, and the hardest changes run on `opus`. The review panels (`/interrogate`, `/arena`, `/architect`) use one `opus` and one `sonnet`.

## Build a verification skill, or don't

If your project has no way to prove app behavior, a `verify-*` skill or an existing harness, generate one with [`/create-verification-skill`](../../skills/create-verification-skill/SKILL.md).

It writes `.claude/skills/verify-<app>/`, a project-local skill that teaches agents to drive your app the way a user does. It proves the skill works once before handing it over. [Verify and ship](./06-verify-and-ship.md#create-a-project-verification-skill) covers it in depth.

If you're new to pstack, do this early. An agent that can check its own work keeps going until the check passes. An agent that can't hands every result back to you to check by hand. Of everything in this guide, the verification skill pays off the most.

## Keep the cost in check

pstack spends extra tokens on subagents and review panels. That's the price of the rigor. To spend fewer:

- Ask for a smaller panel or fewer candidates when a decision is cheap to reverse. Each entry runs one subagent.
- Save `/poteto-mode` for work that needs rigor. A small, obvious edit doesn't.

## Run your first task

Pick something real but small, and describe it the way you'd describe it to a colleague:

```text
/poteto-mode add a --json flag to this command. text output stays byte-identical. verify both.
```

Watch the todo list. Its first items are the matched playbook's steps copied in, the Feature playbook for this prompt. If `/poteto-mode` skips a step, the step stays in the list with `skip: <reason>`, so you can see what it chose not to do.

From here you can type normal follow-ups. To keep `/poteto-mode` on for a whole session, start it as the agent with `claude --agent pstack:poteto-agent`. Otherwise run `/pstack:poteto-mode` per task.

Next: [Route work through `/poteto-mode`](./02-poteto-mode.md).
