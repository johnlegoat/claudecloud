# Cloud gotchas

**Hardware and OS.** The VM is Ubuntu 24.04 with 4 vCPU, 16 GB RAM, 30 GB disk and no GPU. Pre-installed: Node 20/21/22
(npm, pnpm, yarn), Python 3 (pip, uv, pytest, ruff), Docker, PostgreSQL 16 and Redis (installed, not running), gh, git, ripgrep,
and Chrome at $CHROME_PATH. Work that needs a GPU (local AI models, Metal/MPS), macOS-only tools (Xcode, iOS simulators, Swift on
Apple frameworks), Blender, or any service only on the user's machine has to stay local. Split it: send the rest to the cloud
and keep that part for a local session.

**Browser and layout tests differ from macOS.** Linux Chrome draws classic scrollbars about 15 px wide, where macOS overlays
them, and its fonts are different. A layout that fits on a Mac can overflow by about 15 px in the cloud. Windows Chrome also has
classic scrollbars, so such a failure is often a real bug for Windows users, not noise. Playwright set to `channel: "chrome"`
looks for Chrome in the standard path; when `CHROME_PATH` is set, prefer
`launchOptions: { executablePath: process.env.CHROME_PATH }`.

**Versions and speed differ.** The cloud's default Node is 22. If the project or the user's machine runs another version
(check `node -v` locally, `.nvmrc`, `engines`), say so in the prompt, because timing- and regex-sensitive tests can behave
differently. Four vCPUs make big suites slower than on a recent Mac: about 2x for a Playwright suite (one project measured
29 min in the cloud vs 13.5 min locally), so timing-bound tests may fail there only. Playwright video recording needs its own
ffmpeg build, which the limited network cannot download: specs that record video fail with "Executable doesn't exist at
/opt/pw-browsers/ffmpeg-…".

**Network.** The default environment is "Limited": package registries, GitHub and the main cloud SDKs. Calls to any other API
fail. The user can add domains, or choose "Full", in the environment settings at https://claude.ai/code. Tell them which
domains the task needs.

**Secrets.** No .env files arrive in the cloud. For a key, the user adds it in the environment settings at
https://claude.ai/code. Use a network secret: the proxy attaches it for the listed host and it never enters the VM. A plain
variable is readable by anyone who uses that environment. Never put a key value in a prompt, a commit or a routine.

**Time.** A foreground command waits up to 10 minutes, then moves to the background. The VM pauses after a few idle minutes and
may be reclaimed later. The conversation survives, but running servers and background jobs do not, so a cloud session cannot
keep a dev server up for the user.

**What carries over.** The repo's committed `.claude/settings.json` hooks, `CLAUDE.md`, `.claude/skills` and
`.claude/agents` carry over. The user's `~/.claude` (global CLAUDE.md, skills, hooks), local MCP servers and keychain do not.
claude.ai connectors (Gmail, Docs and others) only reach a routine that is not created with `clear_mcp_connections`.

**The cloud's Stop hook wants everything pushed.** When a session ends its turn with uncommitted changes, a built-in hook
tells it to commit and push them. Tests that rewrite tracked files (snapshots, proof images, fixtures) trigger it. Tell the cloud
agent to restore those files (`git checkout -- <paths>`) before finishing, and, on read-only tasks, not to commit at all.

**Routines pile up.** Each task makes a one-shot routine that shows as "Ran" afterwards. The API cannot delete routines; the
user can clear them at https://claude.ai/code/routines. Branches `claude/*` stay on GitHub until someone deletes them, which
is safe once they are merged or dropped.

**Usage.** Cloud sessions draw from the same plan limits as local Claude Code. Parallel sessions draw in parallel.
