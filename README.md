# claudecloud

A Claude Code skill that runs your coding work on Anthropic's cloud instead of your machine.
Installs, builds, test suites and the agent itself run on a cloud VM (Ubuntu, 4 vCPU, 16 GB RAM).
Your laptop only runs a few git commands, so it stays cool and keeps its RAM.

Cloud sessions are included in Claude plans that have Claude Code (Pro, Max and up): no extra bill,
they just count against the same usage limits as your local sessions.

## Install

```bash
git clone https://github.com/johnlegoat/claudecloud ~/.claude/skills/claudecloud
```

Then restart Claude Code. (Or unzip `claudecloud.zip` into `~/.claude/skills/`.)

Before the first launch:
- Check that `claude --help` lists `--cloud`. If it doesn't, update Claude Code.
- Open https://claude.ai/code once: it creates your default cloud environment.
- Give Claude access to your GitHub repos: run `/web-setup` in Claude Code, or install the Claude GitHub App on the repo.

## Use

Run `/claudecloud <task>` in any project. On the first launch in a project, Claude sets it up for you:
- **No GitHub repo yet:** it offers to create a private one with `gh`.
- **Every project:** it writes `scripts/cloud-setup.sh` and a SessionStart hook in `.claude/settings.json`, so every cloud session starts with dependencies installed. The script does nothing on your machine.

Then it pushes your branch and launches a cloud session that works on a `claude/<task>` branch. It watches the session and brings the result back. Several tasks in one message run in parallel.

| Command | What it does |
|---|---|
| `/claudecloud <task>` | Launch a task (sets the project up the first time). |
| `/claudecloud setup` | Only the per-project setup. |
| `/claudecloud status` | Open cloud tasks for this project. |
| `/claudecloud fetch` | Fetch a finished branch and show the diff. It merges or opens a PR only if you say so. |

You can also watch and chat with a running session at https://claude.ai/code or in the Claude mobile app.
Without the skill, `claude --cloud "<task>"` in a project folder starts a one-off cloud session.

The cloud session uses the same model as the session that launched it, unless you ask for another one.
claude.ai connectors (Gmail, Drive and others) are left out of cloud runs unless a task needs them.

## What it touches

- **Git:** pushes your current branch so the cloud sees the same code. It asks before pushing to main/master and never commits `.env` files or keys. Cloud work lands on `claude/*` branches only.
- **Setup:** `scripts/cloud-setup.sh`, `.claude/settings.json`, and `.gitignore` if `.claude/` was ignored.
- **Local state:** `~/.claude/claudecloud-state.json` keeps your environment id and the list of launched tasks. No secrets.
- **Routines:** each task is a one-shot routine. Clear old ones at https://claude.ai/code/routines.

## Limits

- No `.env` files or keys reach the cloud. Add keys in the environment settings at https://claude.ai/code (prefer network secrets).
- The default network only reaches package registries and GitHub. Add other domains in the environment settings.
- No GPU, Xcode, iOS simulators or macOS-only tools: keep that work local.
- It is not a VPS for hosting: the VM pauses when idle, so servers and bots do not stay up.

Details: `references/gotchas.md`. The skill holds no keys, ids or personal data.
