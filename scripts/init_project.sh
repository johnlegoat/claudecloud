#!/usr/bin/env bash
# claudecloud setup: make every cloud session of this project start with its dependencies installed.
# Writes scripts/cloud-setup.sh (no-op unless CLAUDE_CODE_REMOTE=true) and merges a SessionStart hook into .claude/settings.json.
set -euo pipefail
root=$(git rev-parse --show-toplevel); cd "$root"
mkdir -p scripts .claude
if [ -e scripts/cloud-setup.sh ]; then
  echo "scripts/cloud-setup.sh exists: left as is"
else
  inst=""
  if [ -f pnpm-lock.yaml ]; then inst='corepack enable >/dev/null 2>&1 || true; pnpm install --frozen-lockfile'; lock=pnpm-lock.yaml
  elif [ -f yarn.lock ]; then inst='corepack enable >/dev/null 2>&1 || true; yarn install --frozen-lockfile'; lock=yarn.lock
  elif [ -f bun.lockb ] || [ -f bun.lock ]; then inst='command -v bun >/dev/null || npm i -g bun; bun install --frozen-lockfile'; lock=$( [ -f bun.lock ] && echo bun.lock || echo bun.lockb )
  elif [ -f package-lock.json ]; then inst='npm ci --no-audit --no-fund'; lock=package-lock.json
  fi
  py=""
  if [ -f uv.lock ]; then py='uv sync'
  elif [ -f requirements.txt ]; then py='python3 -m pip install -q -r requirements.txt'
  fi
  {
    echo '#!/usr/bin/env bash'
    echo '# Prepares a Claude Code cloud session. Cloud sessions set CLAUDE_CODE_REMOTE=true; locally this exits at once.'
    echo '[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0'
    echo 'set -euo pipefail'
    echo 'cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}"'
    if [ -n "$inst" ]; then
      echo "# JS dependencies, reinstalled only when $lock changes."
      echo "want=\$(sha256sum $lock | cut -d' ' -f1); stamp=node_modules/.cloud-lock-sha"
      echo "if [ ! -f \"\$stamp\" ] || [ \"\$(cat \"\$stamp\")\" != \"\$want\" ]; then $inst; mkdir -p node_modules; echo \"\$want\" > \"\$stamp\"; fi"
    fi
    [ -n "$py" ] && echo "$py"
    echo 'echo "cloud session ready"'
  } > scripts/cloud-setup.sh
  chmod +x scripts/cloud-setup.sh
  echo "wrote scripts/cloud-setup.sh"
  [ -z "$inst$py" ] && echo "NOTE: no lockfile at the repo root: edit scripts/cloud-setup.sh to install this project's dependencies"
fi
python3 - <<'PY'
import json, os
p = ".claude/settings.json"
s = {}
if os.path.exists(p):
    with open(p) as f:
        s = json.load(f)
cmd = 'bash "$CLAUDE_PROJECT_DIR/scripts/cloud-setup.sh"'
ss = s.setdefault("hooks", {}).setdefault("SessionStart", [])
if any(h.get("command") == cmd for g in ss for h in g.get("hooks", [])):
    print(".claude/settings.json already has the hook")
else:
    ss.append({"matcher": "startup|resume", "hooks": [{"type": "command", "command": cmd}]})
    with open(p, "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
    print("added the SessionStart hook to .claude/settings.json")
PY
if git check-ignore -q .claude/settings.json; then
  # A folder pattern (".claude/") cannot have exceptions; ".claude/*" ignores the same files but allows one.
  python3 - <<'PY'
import os, re
p = ".gitignore"
lines = open(p).read().splitlines() if os.path.exists(p) else []
lines = [re.sub(r"^(/?)\.claude/?$", r"\1.claude/*", l) for l in lines]
lines += ["", "# Claude Code cloud sessions need the shared settings", "!.claude/settings.json"]
open(p, "w").write("\n".join(lines) + "\n")
PY
  if git check-ignore -q .claude/settings.json; then
    echo "WARNING: .claude/settings.json is still ignored (global excludes or a broader pattern): stage it with git add -f .claude/settings.json"
  else
    echo "un-ignored .claude/settings.json in .gitignore"
  fi
fi
echo "next: review, commit and push scripts/cloud-setup.sh, .claude/settings.json and .gitignore"
