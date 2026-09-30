#!/usr/bin/env python3
"""Build, rebuild, and verify review-md v2 eval scratch workspaces.

Standard library only. Python 3.10 or later.
"""

import argparse
import datetime
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

EVD = pathlib.Path(__file__).resolve().parent
REPO_ROOT = EVD.parents[2]
EV_ROOT = pathlib.Path(os.environ.get("RMV2_EV", "/tmp/rmv2-evals"))
CONFIG_DIR = pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR", str(pathlib.Path.home() / ".claude")))

sys.path.insert(0, str(EVD / "files"))
import generate  # noqa: E402

with open(EVD / "files" / "workspaces.json", encoding="utf-8") as f:
    WORKSPACES = json.load(f)
with open(EVD / "evals.json", encoding="utf-8") as f:
    EVALS = json.load(f)
EVALS_BY_ID = {e["id"]: e for e in EVALS["evals"]}

SCRIPT_NAMES = ["md-checks.sh", "link-recheck-hook.sh", "md-claims.sh"]

HOME_PATH = "/" + "home" + "/" + "rmv2user" + "/projects/ledger-notes"

_GIT_HOME = None


def _git_home():
    global _GIT_HOME
    if _GIT_HOME is None:
        _GIT_HOME = tempfile.mkdtemp(prefix="rmv2-git-home-")
    return _GIT_HOME


def run_git(cwd, args, extra_env=None):
    env = dict(os.environ)
    env["HOME"] = _git_home()
    if extra_env:
        env.update(extra_env)
    subprocess.run(
        ["git", "-c", "commit.gpgsign=false"] + args,
        cwd=cwd,
        env=env,
        check=True,
        capture_output=True,
    )


def sha256_file(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def check_scripts():
    hashes = {}
    ok = True
    for name in SCRIPT_NAMES:
        cfg_path = CONFIG_DIR / "scripts" / name
        repo_path = REPO_ROOT / "scripts" / name
        h1 = sha256_file(cfg_path) if cfg_path.exists() else "MISSING"
        h2 = sha256_file(repo_path) if repo_path.exists() else "MISSING"
        if h1 != h2:
            print(f"{name}: config={h1} repo={h2}", file=sys.stderr)
            ok = False
        else:
            hashes[name] = h1
    if not ok:
        sys.exit(3)
    return hashes


def check_no_existing_outputs(iter_dir):
    if iter_dir.exists():
        for p in iter_dir.glob("**/outputs/response.md"):
            print(f"existing output found: {p}", file=sys.stderr)
            sys.exit(4)


def replace_home_path(dest):
    for p in dest.rglob("*"):
        if p.is_file():
            try:
                text = p.read_text(encoding="utf-8")
            except (UnicodeDecodeError, ValueError):
                continue
            if "{{HOME_PATH}}" in text:
                p.write_text(text.replace("{{HOME_PATH}}", HOME_PATH), encoding="utf-8")


def apply_tracking(case_id, dest, run_date):
    src = EVD / "files" / "tracking" / f"case-{case_id}.md"
    if not src.exists():
        return
    text = src.read_text(encoding="utf-8")
    text = text.replace("{{TODAY}}", run_date.isoformat())

    def days_ago(m):
        n = int(m.group(1))
        return (run_date - datetime.timedelta(days=n)).isoformat()

    text = re.sub(r"\{\{DAYS_AGO:(\d+)\}\}", days_ago, text)
    target = dest / ".claude" / "review-tracking.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


def build_workspace(workspace_name, case_id, dest, run_date, keep_git):
    ws = WORKSPACES[workspace_name]
    src = EVD / "files" / workspace_name
    if dest.exists():
        shutil.rmtree(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(src, dest)

    if ws.get("generate"):
        gen_fn = getattr(generate, ws["generate"])
        gen_fn(dest)

    replace_home_path(dest)

    if ws["git"]:
        run_git(dest, ["init", "-q", "-b", "main"])
        run_git(dest, ["config", "user.name", "Fixture Author"])
        run_git(dest, ["config", "user.email", "fixture@example.invalid"])
        run_git(dest, ["config", "commit.gpgsign", "false"])

        before_dir = EVD / "files" / f"{workspace_name}.before"
        for entry in ws["later"]:
            path = entry["path"]
            before_file = before_dir / path
            target = dest / path
            if before_file.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(before_file, target)
            elif target.exists():
                target.unlink()

        run_git(dest, ["add", "-A"])
        base_env = {"GIT_AUTHOR_DATE": ws["base_date"], "GIT_COMMITTER_DATE": ws["base_date"]}
        run_git(dest, ["commit", "-q", "--no-verify", "-m", "Initial commit"], extra_env=base_env)

        for entry in ws["later"]:
            path = entry["path"]
            final_src = src / path
            target = dest / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(final_src, target)
            run_git(dest, ["add", path])
            later_env = {"GIT_AUTHOR_DATE": entry["date"], "GIT_COMMITTER_DATE": entry["date"]}
            run_git(dest, ["commit", "-q", "--no-verify", "-m", entry["message"]], extra_env=later_env)

    apply_tracking(case_id, dest, run_date)

    if not keep_git and (dest / ".git").exists():
        shutil.rmtree(dest / ".git")


def parse_case_spec(spec):
    if spec == "v1":
        return {e["id"]: 3 for e in EVALS["evals"] if e["v1_prompt"] is not None}
    if spec == "v2":
        return {i: 3 for i in range(1, 27)}
    if spec == "calib":
        spec = "27:3,26:3,1:1,9:1,17:1"
    result = {}
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        id_str, runs_str = part.split(":")
        result[int(id_str)] = int(runs_str)
    return result


def repo_head():
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=REPO_ROOT, capture_output=True, text=True, check=True
    )
    return result.stdout.strip()


def build_run(case_id, workspace, case_dir, run_n, run_date):
    run_project = case_dir / "with_skill" / f"run-{run_n}" / "project"
    build_workspace(workspace, case_id, run_project, run_date, keep_git=True)
    outputs_dir = case_dir / "with_skill" / f"run-{run_n}" / "outputs"
    outputs_dir.mkdir(parents=True, exist_ok=True)
    if workspace == "cfg":
        scrub_local = run_project / "scripts" / "scrub-patterns.local"
        scrub_local.parent.mkdir(parents=True, exist_ok=True)
        scrub_local.touch()


def cmd_iteration(args):
    iteration = args.iteration
    skill_dir = pathlib.Path(args.skill).resolve()
    cases = parse_case_spec(args.cases)
    if args.exclude:
        for tok in args.exclude.split(","):
            tok = tok.strip()
            if tok:
                cases.pop(int(tok), None)

    scripts_hashes = check_scripts()

    iter_dir = EV_ROOT / iteration
    check_no_existing_outputs(iter_dir)
    if iter_dir.exists():
        shutil.rmtree(iter_dir)
    iter_dir.mkdir(parents=True)

    skill_dest = iter_dir / "skill-under-test" / "review-md"
    skill_dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(skill_dir, skill_dest, ignore=shutil.ignore_patterns("evals"))

    today = datetime.date.today()

    for case_id in sorted(cases):
        runs = cases[case_id]
        case = EVALS_BY_ID[case_id]
        workspace = case["workspace"]

        original_dest = iter_dir / "originals" / f"eval-{case_id}"
        build_workspace(workspace, case_id, original_dest, today, keep_git=False)

        case_dir = iter_dir / f"eval-{case_id}"
        for run_n in range(1, runs + 1):
            build_run(case_id, workspace, case_dir, run_n, today)

        if iteration == "v1":
            prompt = case["v1_prompt"]
            expectations = [case["expectations"][i] for i in case["v1_expectations"]]
        else:
            prompt = case["prompt"]
            expectations = list(case["expectations"])
        metadata = {
            "eval_id": case_id,
            "eval_name": case["name"],
            "prompt": prompt,
            "expectations": expectations,
        }
        write_json(case_dir / "eval_metadata.json", metadata)

    manifest = {
        "iteration": iteration,
        "date": today.isoformat(),
        "evals_dir": str(EVD),
        "repo_head": repo_head(),
        "skill_dir": str(skill_dir),
        "skill_sha256": sha256_file(skill_dest / "SKILL.md"),
        "scripts": scripts_hashes,
        "cases": {str(k): v for k, v in cases.items()},
    }
    write_json(iter_dir / "manifest.json", manifest)


def cmd_rebuild(iteration, case_id_str, run_n_str):
    case_id = int(case_id_str)
    run_n = int(run_n_str)
    iter_dir = EV_ROOT / iteration
    manifest = json.loads((iter_dir / "manifest.json").read_text(encoding="utf-8"))
    if str(case_id) not in manifest["cases"]:
        print(f"case {case_id} not in manifest for iteration {iteration}", file=sys.stderr)
        sys.exit(1)
    run_date = datetime.date.fromisoformat(manifest["date"])
    case = EVALS_BY_ID[case_id]
    workspace = case["workspace"]

    case_dir = iter_dir / f"eval-{case_id}"
    run_dir = case_dir / "with_skill" / f"run-{run_n}"
    if run_dir.exists():
        shutil.rmtree(run_dir)
    build_run(case_id, workspace, case_dir, run_n, run_date)


def git_log_dates(project):
    result = subprocess.run(
        [
            "git",
            "-c",
            "commit.gpgsign=false",
            "log",
            "--reverse",
            "--date=format:%Y-%m-%dT%H:%M:%S",
            "--format=%ad",
        ],
        cwd=project,
        capture_output=True,
        text=True,
        check=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def cmd_verify(iteration):
    iter_dir = EV_ROOT / iteration
    failures = []

    manifest = None
    manifest_path = iter_dir / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        failures.append(f"manifest.json does not parse: {exc}")

    if manifest is not None:
        for name in SCRIPT_NAMES:
            cfg_path = CONFIG_DIR / "scripts" / name
            live_hash = sha256_file(cfg_path) if cfg_path.exists() else "MISSING"
            if manifest.get("scripts", {}).get(name) != live_hash:
                failures.append(f"script hash mismatch for {name}")

    skill_md = iter_dir / "skill-under-test" / "review-md" / "SKILL.md"
    if not skill_md.exists():
        failures.append(f"{skill_md}: missing")
    skill_root = iter_dir / "skill-under-test"
    if skill_root.exists():
        for p in skill_root.rglob("evals"):
            if p.is_dir():
                failures.append(f"{p}: evals directory found under skill-under-test")

    forbidden = ["planted-defects", "eval_metadata", "grading.json", "specs/drafts"]
    placeholders = ["{{HOME_PATH}}", "{{TODAY}}", "{{DAYS_AGO", "{{FILLER"]
    if iter_dir.exists():
        for p in iter_dir.rglob("*"):
            if not p.is_file():
                continue
            try:
                text = p.read_text(encoding="utf-8")
            except (UnicodeDecodeError, ValueError):
                continue
            if p.name != "eval_metadata.json" and "skill-under-test" not in p.parts:
                for token in forbidden:
                    if token in text:
                        failures.append(f"{p}: contains forbidden token '{token}'")
            if "skill-under-test" not in p.parts:
                for token in placeholders:
                    if token in text:
                        failures.append(f"{p}: contains unresolved placeholder '{token}'")

    if manifest is not None:
        for case_id_str, runs in manifest.get("cases", {}).items():
            case_id = int(case_id_str)
            case = EVALS_BY_ID.get(case_id)
            if case is None:
                failures.append(f"unknown case id {case_id} in manifest")
                continue
            workspace = case["workspace"]
            ws = WORKSPACES[workspace]

            for run_n in range(1, runs + 1):
                run_dir = iter_dir / f"eval-{case_id}" / "with_skill" / f"run-{run_n}"
                project = run_dir / "project"
                outputs = run_dir / "outputs"
                if not outputs.exists():
                    failures.append(f"{outputs}: missing")

                if ws["git"]:
                    expected_dates = [ws["base_date"]] + [e["date"] for e in ws["later"]]
                    try:
                        actual_dates = git_log_dates(project)
                    except subprocess.CalledProcessError as exc:
                        failures.append(f"{project}: git log failed: {exc}")
                        actual_dates = None
                    if actual_dates is not None and actual_dates != expected_dates:
                        failures.append(
                            f"{project}: git log dates {actual_dates} != expected {expected_dates}"
                        )
                else:
                    if (project / ".git").exists():
                        failures.append(f"{project}: .git exists for nongit workspace")

                if workspace == "cfg":
                    notes = project / "docs" / "notes.md"
                    if not notes.exists() or HOME_PATH not in notes.read_text(encoding="utf-8"):
                        failures.append(f"{notes}: missing joined home path")
                    scrub_local = project / "scripts" / "scrub-patterns.local"
                    if not scrub_local.exists():
                        failures.append(f"{scrub_local}: missing")

                if case.get("tracking"):
                    tracking_file = project / ".claude" / "review-tracking.md"
                    if not tracking_file.exists():
                        failures.append(f"{tracking_file}: missing")

    for line in failures:
        print(line)
    if failures:
        sys.exit(1)
    print("VERIFY OK")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iteration")
    parser.add_argument("--skill")
    parser.add_argument("--cases")
    parser.add_argument("--exclude")
    parser.add_argument("--rebuild", nargs=3, metavar=("ITER", "ID", "N"))
    parser.add_argument("--verify", metavar="ITER")
    args = parser.parse_args()

    if args.rebuild:
        cmd_rebuild(*args.rebuild)
    elif args.verify:
        cmd_verify(args.verify)
    elif args.iteration:
        if not args.skill or not args.cases:
            parser.error("--iteration requires --skill and --cases")
        cmd_iteration(args)
    else:
        parser.error("one of --iteration, --rebuild, or --verify is required")


if __name__ == "__main__":
    main()
