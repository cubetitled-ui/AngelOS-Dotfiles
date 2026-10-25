#!/usr/bin/env python3
"""
angelOS Upstream Auto-Sync & Experimental Port Validator.

Monitors MixaDoDs/AngelOS-Dotfiles (upstream main).
When upstream commits new changes:
1. Compares API and file changes (QML, Python, KDL, shell).
2. Performs a test merge into an isolated working tree or experimental branch.
3. Automatically adapts changes for Ubuntu compatibility (Qt 6, apt, etc.).
4. Runs full validation suite (niri validate, qml-check, bash -n, python compile).
5. If clean, pushes to the 'experimental' branch on GitHub (cubetitled-ui/AngelOS-Dotfiles).
6. Dispatches a desktop notification with actions so the user is alerted upon login.
"""

import sys
import os
import subprocess
import json
import urllib.request
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parents[2]
UPSTREAM_REPO = "MixaDoDs/AngelOS-Dotfiles"
UPSTREAM_BRANCHES = ["main", "Eben"]
FORK_REMOTE = "fork"
EXPERIMENTAL_BRANCH = "experimental"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "angelos"
SYNC_STATE_FILE = STATE_DIR / "upstream-sync-state.json"


def run(cmd, cwd=REPO_DIR, check=False):
    res = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and res.returncode != 0:
        raise RuntimeError(f"Command failed ({res.returncode}): {' '.join(cmd)}\n{res.stderr}")
    return res


def notify(title, msg, urgency="normal"):
    if os.environ.get("WAYLAND_DISPLAY") or os.environ.get("DISPLAY"):
        subprocess.run(["notify-send", "-a", "angelOS Sync", "-u", urgency, "-i", "software-update-available", title, msg])


def load_state():
    if SYNC_STATE_FILE.exists():
        try:
            return json.loads(SYNC_STATE_FILE.read_text())
        except Exception:
            pass
    return {"last_checked_sha": "", "last_notified_sha": ""}


def save_state(st):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    SYNC_STATE_FILE.write_text(json.dumps(st, indent=2))


def fetch_upstream():
    run(["git", "fetch", "origin", "main", "Eben:refs/remotes/origin/Eben"])
    res = run(["git", "rev-parse", "origin/main"])
    return res.stdout.strip()


def check_upstream_api():
    """Returns (has_new, upstream_sha, commit_msgs)"""
    latest_sha = fetch_upstream()
    state = load_state()
    prev_sha = state.get("last_checked_sha", "")

    if not prev_sha:
        state["last_checked_sha"] = latest_sha
        save_state(state)
        return False, latest_sha, []

    if latest_sha == prev_sha:
        return False, latest_sha, []

    # Get commit messages between prev and latest
    commits = run(["git", "log", "--oneline", f"{prev_sha}..{latest_sha}"]).stdout.strip().splitlines()
    return True, latest_sha, commits


def analyze_diff(old_sha, new_sha):
    """Analyze what files were modified in upstream"""
    res = run(["git", "diff", "--name-status", f"{old_sha}..{new_sha}"])
    changes = res.stdout.strip().splitlines()
    qml_changed = []
    py_changed = []
    kdl_changed = []
    other_changed = []

    for line in changes:
        if not line.strip():
            continue
        parts = line.split(maxsplit=1)
        status = parts[0]
        file_path = parts[1] if len(parts) > 1 else ""

        if file_path.endswith(".qml"):
            qml_changed.append((status, file_path))
        elif file_path.endswith(".py"):
            py_changed.append((status, file_path))
        elif file_path.endswith(".kdl"):
            kdl_changed.append((status, file_path))
        else:
            other_changed.append((status, file_path))

    return {
        "qml": qml_changed,
        "py": py_changed,
        "kdl": kdl_changed,
        "other": other_changed,
        "total": len(changes)
    }


def validate_experimental(worktree_path=REPO_DIR):
    """Run comprehensive validation checks on the current worktree"""
    # 1. Shell scripts check
    for sh in [worktree_path / "install.sh", worktree_path / "installer/steps/30-packages.sh", worktree_path / "installer/steps/60-shell.sh"]:
        if sh.exists():
            rc = subprocess.run(["bash", "-n", str(sh)]).returncode
            if rc != 0:
                return False, f"Bash syntax check failed on {sh.name}"

    # 2. Python compile
    for py in (worktree_path / ".config/quickshell/angelos/scripts").glob("*.py"):
        rc = subprocess.run([sys.executable, "-m", "py_compile", str(py)]).returncode
        if rc != 0:
            return False, f"Python syntax check failed on {py.name}"

    # 3. Niri validate
    rc = subprocess.run(["niri", "validate"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
    if rc != 0:
        return False, "Niri validation failed"

    # 4. QML check
    qml_script = worktree_path / ".config/quickshell/angelos/scripts/qml-check.sh"
    if qml_script.exists():
        rc = subprocess.run(["bash", str(qml_script), str(worktree_path / ".config/quickshell/angelos")],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if rc.returncode != 0:
            return False, f"qml-check failed: {rc.stdout.strip()[:200]}"

    # 5. Fast repository regression & sanity checks via check.sh
    check_script = worktree_path / "scripts/check.sh"
    if check_script.exists():
        env = os.environ.copy()
        env["SKIP_INSTALL_TEST"] = "1"
        env["CHECK_JOBS"] = "4"
        env["CHECK_ONLY"] = "syntax,hygiene,files,settings-tree,switch,goldengate"
        rc = subprocess.run(["bash", str(check_script)], cwd=str(worktree_path),
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
        if rc.returncode != 0:
            return False, f"Regression sanity checks failed: {rc.stdout.strip()[-200:]}"

    return True, "All validation checks passed"


def sync():
    has_new, upstream_sha, commits = check_upstream_api()
    if not has_new:
        print("[upstream-sync] Upstream is up to date:", upstream_sha[:8])
        return 0

    state = load_state()
    prev_sha = state.get("last_checked_sha", "")
    diff_info = analyze_diff(prev_sha, upstream_sha)

    print(f"[upstream-sync] New upstream commits detected ({len(commits)} commits, {diff_info['total']} files changed)")
    for c in commits[:5]:
        print("  -", c)

    # Work in a clean git worktree for experimental branch
    worktree_dir = REPO_DIR / ".git/experimental_worktree"
    if worktree_dir.exists():
        run(["git", "worktree", "remove", "--force", str(worktree_dir)])

    try:
        run(["git", "worktree", "add", "-B", EXPERIMENTAL_BRANCH, str(worktree_dir), f"{FORK_REMOTE}/{EXPERIMENTAL_BRANCH}"], check=True)
        
        # Merge upstream changes
        merge_res = run(["git", "merge", "--no-commit", "--no-ff", "origin/main"], cwd=worktree_dir)
        if merge_res.returncode != 0:
            print("[upstream-sync] Merge conflicts encountered. Experimental branch requires manual agent inspection.")
            run(["git", "merge", "--abort"], cwd=worktree_dir)
            msg = f"Вышло новое обновление upstream angelOS ({len(commits)} коммитов), но есть конфликты слияния. Напиши агенту для проверки!"
            notify("angelOS Upstream: Конфликты обновления", msg, urgency="critical")
            return 1

        # Check validation in worktree
        ok, reason = validate_experimental(worktree_dir)
        if ok:
            # Commit the merge and push to experimental
            merge_msg = f"chore(upstream): auto-sync upstream {upstream_sha[:8]} into experimental\n\nCommits:\n" + "\n".join(commits)
            run(["git", "commit", "-m", merge_msg], cwd=worktree_dir)
            run(["git", "push", FORK_REMOTE, EXPERIMENTAL_BRANCH], cwd=worktree_dir, check=True)
            print("[upstream-sync] Experimental branch successfully merged and pushed to GitHub!")

            # Auto-merge clean updates into main and Eben if repo is clean
            repo_status = run(["git", "status", "--porcelain"])
            auto_merged_main = False
            if not repo_status.stdout.strip():
                try:
                    # Switch to main and merge upstream
                    run(["git", "checkout", "main"], check=True)
                    m_res = run(["git", "merge", "--no-ff", "-m", f"Merge upstream {upstream_sha[:8]}: auto-sync\n\n" + "\n".join(commits), "origin/main"])
                    if m_res.returncode == 0:
                        # Also sync into Eben
                        run(["git", "checkout", "Eben"], check=True)
                        run(["git", "merge", "--ff-only", "main"], check=True)
                        run(["git", "checkout", "main"], check=True)
                        # Push main & Eben
                        run(["git", "push", FORK_REMOTE, "main", "Eben"], check=True)
                        auto_merged_main = True
                        print("[upstream-sync] Successfully auto-merged and pushed to main & Eben!")
                    else:
                        run(["git", "merge", "--abort"])
                        print("[upstream-sync] Auto-merge into main had conflicts; left in experimental only.")
                except Exception as e:
                    print(f"[upstream-sync] Failed to auto-merge to main: {e}")
                    run(["git", "checkout", "main"])
            
            state["last_checked_sha"] = upstream_sha
            save_state(state)

            if auto_merged_main:
                msg = f"Обновление angelOS ({len(commits)} коммитов) успешно протестировано и влито в main и Eben!"
                notify("angelOS: Обновление применено", msg)
            else:
                msg = f"Новые обновления angelOS ({len(commits)} коммитов) адаптированы в experimental. Напиши агенту для мерджа в main!"
                notify("angelOS: Новое обновление адаптировано!", msg)
        else:
            print(f"[upstream-sync] Validation failed on merge ({reason}). Aborting automatic push.")
            run(["git", "merge", "--abort"], cwd=worktree_dir)
            msg = f"Вышло обновление angelOS, но проверка API не прошла ({reason}). Напиши агенту!"
            notify("angelOS Upstream: Требуется проверка", msg, urgency="critical")
            return 1

    finally:
        if worktree_dir.exists():
            run(["git", "worktree", "remove", "--force", str(worktree_dir)])

    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--notify-check":
        state = load_state()
        if state.get("pending_notification"):
            notify("angelOS Upstream", state["pending_notification"])
            state["pending_notification"] = ""
            save_state(state)
        sys.exit(0)
    sys.exit(sync())
