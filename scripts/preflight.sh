#!/usr/bin/env bash
# claudecloud preflight: facts about the current project that decide how to send it to the cloud. Read-only.
set -u
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "git: NOT A GIT REPO (offer git init + a private GitHub repo)"; exit 0; fi
root=$(git rev-parse --show-toplevel); cd "$root"
remote=""
for r in origin $(git remote); do
  case "$(git remote get-url "$r" 2>/dev/null)" in *github.com*) remote=$r; break;; esac
done
url=""; [ -n "$remote" ] && url=$(git remote get-url "$remote")
gh_url=""
case "$url" in
  *github.com*) gh_url=$(echo "$url" | sed -E 's#^git@github.com:#https://github.com/#; s#^ssh://git@github.com/#https://github.com/#; s#^https://[^@/]*@github.com/#https://github.com/#; s#\.git$##');;
esac
echo "root: $root"
echo "remotes: $(git remote | tr '\n' ' ')"
echo "github_remote: ${remote:-none}"
echo "github_url: ${gh_url:-NONE (routines cannot clone this project)}"
if [ -z "$gh_url" ]; then
  if ! command -v gh >/dev/null; then echo "gh: missing"; elif gh auth status >/dev/null 2>&1; then echo "gh: logged in"; else echo "gh: logged out"; fi
fi
branch=$(git branch --show-current); echo "branch: ${branch:-DETACHED}"
def=$(git symbolic-ref --quiet --short refs/remotes/${remote:-origin}/HEAD 2>/dev/null | sed 's#^[^/]*/##'); echo "default_branch: ${def:-unknown}"
if [ -n "$branch" ]; then
  if [ -n "$remote" ] && git rev-parse --verify --quiet "$remote/$branch" >/dev/null; then
    echo "unpushed_commits: $(git rev-list --count "$remote/$branch..HEAD")"
  else
    echo "unpushed_commits: branch not on the remote yet"
  fi
fi
dirty=$(git status --porcelain | head -40)
echo "uncommitted_files: $(git status --porcelain | wc -l | tr -d ' ')"
[ -n "$dirty" ] && echo "$dirty" | sed 's/^/  /'
pm=""
[ -f package-lock.json ] && pm="$pm npm"; [ -f pnpm-lock.yaml ] && pm="$pm pnpm"; [ -f yarn.lock ] && pm="$pm yarn"
{ [ -f bun.lockb ] || [ -f bun.lock ]; } && pm="$pm bun"; [ -f uv.lock ] && pm="$pm uv"
[ -f requirements.txt ] && pm="$pm pip"; [ -f pyproject.toml ] && [ ! -f uv.lock ] && pm="$pm pyproject"
[ -f Cargo.toml ] && pm="$pm cargo"; [ -f go.mod ] && pm="$pm go"
echo "package_managers:${pm:- none found}"
if [ -f .claude/settings.json ] && grep -q "cloud-setup" .claude/settings.json 2>/dev/null; then
  if git ls-files --error-unmatch .claude/settings.json >/dev/null 2>&1; then echo "cloud_setup: yes (committed)"; else echo "cloud_setup: present but NOT committed"; fi
else
  echo "cloud_setup: no (run the setup on this first launch)"
fi
for f in CLAUDE.md AGENTS.md .claude/CLAUDE.md; do git ls-files --error-unmatch "$f" >/dev/null 2>&1 && echo "committed_rules: $f"; done
exit 0
