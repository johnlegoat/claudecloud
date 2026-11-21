#!/usr/bin/env python3
"""claudecloud helper: build RemoteTrigger create bodies and track launched cloud tasks.

  cloudctl.py body --repo URL --env ENV_ID --name NAME --prompt-file FILE --model M [--delay 70] [--keep-connectors]
  cloudctl.py env [--set ENV_ID]
  cloudctl.py track add --project DIR --routine TRIG_ID --branch B --base B --task TEXT
  cloudctl.py track list [--project DIR] [--all]
  cloudctl.py track done --branch B
State: ~/.claude/claudecloud-state.json (environment id and launched tasks; no secrets).
"""
import argparse, datetime as dt, json, os, re, sys, uuid

STATE = os.path.expanduser("~/.claude/claudecloud-state.json")
TOOLS = ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]


def load():
    try:
        with open(STATE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"env": None, "tasks": []}


def save(st):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        json.dump(st, f, indent=1)


def norm_repo(url):
    url = url.strip()
    url = re.sub(r"^git@github\.com:", "https://github.com/", url)
    url = re.sub(r"^ssh://git@github\.com/", "https://github.com/", url)
    url = re.sub(r"^https://[^@/]+@github\.com/", "https://github.com/", url)
    if re.fullmatch(r"[\w.-]+/[\w.-]+", url):
        url = "https://github.com/" + url
    url = re.sub(r"\.git$", "", url).rstrip("/")
    if not url.startswith("https://github.com/"):
        sys.exit("repo must be a GitHub repository, got: " + url)
    return url


def body(a):
    prompt = (sys.stdin.read() if a.prompt_file == "-" else open(a.prompt_file).read()).strip()
    if not prompt:
        sys.exit("empty prompt file")
    when = dt.datetime.now(dt.timezone.utc).replace(microsecond=0) + dt.timedelta(seconds=a.delay)
    b = {
        "name": a.name[:120],
        "run_once_at": when.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "enabled": True,
        "job_config": {"ccr": {
            "environment_id": a.env,
            "session_context": {"model": a.model, "sources": [{"git_repository": {"url": norm_repo(a.repo)}}], "allowed_tools": TOOLS},
            "events": [{"data": {"uuid": str(uuid.uuid4()), "session_id": "", "type": "user", "parent_tool_use_id": None,
                                  "message": {"content": prompt, "role": "user"}}}],
        }},
    }
    if not a.keep_connectors:
        b["clear_mcp_connections"] = True
    st = load()
    if a.env and st.get("env") != a.env:
        st["env"] = a.env
        save(st)
    print(json.dumps(b))


def env(a):
    st = load()
    if a.set:
        st["env"] = a.set
        save(st)
    print(st.get("env") or "none saved")


def track(a):
    st = load()
    if a.op == "add":
        st["tasks"].append({"project": os.path.abspath(a.project), "routine": a.routine, "branch": a.branch, "base": a.base,
                            "task": a.task, "launched": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "done": False})
        save(st)
        print("tracked", a.branch)
    elif a.op == "done":
        n = 0
        for t in st["tasks"]:
            if t["branch"] == a.branch and not t["done"]:
                t["done"] = True
                n += 1
        save(st)
        print("marked done:", n)
    else:
        proj = os.path.abspath(a.project) if a.project else None
        rows = [t for t in st["tasks"] if (a.all or not t["done"]) and (proj is None or t["project"] == proj)]
        if not rows:
            print("no open cloud tasks" + (" for " + proj if proj else ""))
        for t in rows:
            print(f"{t['launched']}  {'done' if t['done'] else 'open'}  {t['routine']}  {t['branch']} (base {t['base']})  {t['task']}  [{t['project']}]")


def main():
    p = argparse.ArgumentParser()
    s = p.add_subparsers(dest="cmd", required=True)
    b = s.add_parser("body")
    b.add_argument("--repo", required=True); b.add_argument("--env", required=True); b.add_argument("--name", required=True)
    b.add_argument("--prompt-file", required=True); b.add_argument("--model", required=True)
    b.add_argument("--delay", type=int, default=70); b.add_argument("--keep-connectors", action="store_true")
    e = s.add_parser("env"); e.add_argument("--set")
    t = s.add_parser("track"); t.add_argument("op", choices=["add", "list", "done"])
    t.add_argument("--project"); t.add_argument("--routine"); t.add_argument("--branch"); t.add_argument("--base"); t.add_argument("--task")
    t.add_argument("--all", action="store_true")
    a = p.parse_args()
    if a.cmd == "body":
        if a.delay < 45:
            sys.exit("--delay must be at least 45 seconds (the run time has to be in the future when the server gets it)")
        body(a)
    elif a.cmd == "env":
        env(a)
    else:
        if a.op == "add" and not all([a.project, a.routine, a.branch, a.base, a.task]):
            sys.exit("track add needs --project --routine --branch --base --task")
        if a.op == "done" and not a.branch:
            sys.exit("track done needs --branch")
        track(a)


if __name__ == "__main__":
    main()
