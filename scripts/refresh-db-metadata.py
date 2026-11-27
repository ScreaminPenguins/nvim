#!/usr/bin/env python3
"""Refresh Cloud SQL metadata (cloudsql, team) in the dadbod connections file.

For every connection with a host, resolves the host's IP and matches it to a
Cloud SQL instance (gcloud sql instances list), then sets
    cloudsql = { project = ..., instance = ..., region = ... }
    team     = <the instance's helm `app-owner` label, as a team name>
Only those two fields are ever written. Connections that don't match an
instance (on-prem, Redis, Mongo, DNS not resolving) are left as they are; an
existing `cloudsql` whose instance still exists is refreshed by name.

Projects searched: those already referenced by `cloudsql` entries in the
file, plus --project ones, or every project you can see with --all-projects.

Safety: writes a timestamped backup to ~/.local/state/nvim/ first, reloads
the result with nvim and checks only cloudsql/team changed; if not, the
backup is restored. --dry-run prints the changes without writing.

Needs: gcloud (logged in), nvim, VPN/DNS for the internal host names.

Usage:
    scripts/refresh-db-metadata.py [--dry-run] [--project P ...] [--all-projects] [--file F]
Also available in nvim as :DBRefreshMetadata [args].
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import datetime
import json
import re
import shutil
import socket
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FILE = ROOT / "lua" / "config" / "db_connections.lua"
BACKUP_DIR = Path.home() / ".local" / "state" / "nvim"

# app-owner label -> team name as SweetServe shows it. Labels not listed here
# fall back to: drop "_team", "_" -> " ", Title Case (acronyms kept upper).
TEAM_NAMES = {
    "cdp_team": "CDP",
    "mobile_desktop_apps_team": "Mobile Desktop Applications",
    "band_orchestra_team": "Band And Orchestra",
    "crm_rapid_response_team": "CRM Rapid Response",
    "crm_inv_price_customer_support_team": "CRM Inv Price Customer Support",
}
ACRONYMS = {"cdp", "crm", "api", "sql", "dc", "it", "de", "qa", "b2b", "ssi", "mis", "4d"}

SIMPLE_FIELD = re.compile(
    r"^\s*(alias|type|host|port|user|database|databases|project|dataset|region|url|path|params|secret|group|env)\s*=.*?,?\s*$"
)


def team_name(label: str | None) -> str | None:
    if not label:
        return None
    if label in TEAM_NAMES:
        return TEAM_NAMES[label]
    if "_" not in label:  # e.g. "web-platform-engineering": used verbatim
        return label
    words = re.sub(r"_team$", "", label).split("_")
    return " ".join(w.upper() if w in ACRONYMS else w.capitalize() for w in words)


def lua_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def cloudsql_lua(c: dict) -> str:
    return f'{{ project = {lua_str(c["project"])}, instance = {lua_str(c["instance"])}, region = {lua_str(c["region"])} }}'


def load_connections(path: Path) -> dict:
    """The file's data via nvim (it is Lua): {"connections": [...], "defaults": {...}}."""
    lua = (
        "local s = dofile(" + json.dumps(str(path)) + ")"
        " io.write(vim.json.encode({ connections = s.connections or {}, defaults = s.defaults or vim.empty_dict() }))"
    )
    r = subprocess.run(["nvim", "--headless", "-u", "NONE", "-c", "lua " + lua, "+qa"], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout:
        sys.exit(f"could not load {path}:\n{r.stderr.strip()}")
    return json.loads(r.stdout)


def gcloud_json(args: list[str]):
    r = subprocess.run(["gcloud", *args, "--format=json"], capture_output=True, text=True)
    if r.returncode != 0:
        return None, r.stderr.strip().splitlines()[-1] if r.stderr.strip() else f"exit {r.returncode}"
    return json.loads(r.stdout or "[]"), None


def fetch_instances(projects: list[str]) -> tuple[list[dict], list[str]]:
    def one(p):
        data, err = gcloud_json(["sql", "instances", "list", "--project", p])
        return p, data, err

    instances, errors = [], []
    with cf.ThreadPoolExecutor(8) as ex:
        for p, data, err in ex.map(one, projects):
            if data is None:
                errors.append(f"{p}: {err}")
                continue
            for d in data:
                instances.append(
                    {
                        "project": p,
                        "instance": d["name"],
                        "region": d.get("region") or "",
                        "engine": (d.get("databaseVersion") or "").split("_")[0].lower(),
                        "ips": [a["ipAddress"] for a in d.get("ipAddresses", [])],
                        "owner": ((d.get("settings") or {}).get("userLabels") or {}).get("app-owner"),
                    }
                )
    return instances, errors


def host_of(entry: dict, defaults: dict) -> str | None:
    if entry.get("host"):
        return entry["host"]
    if entry.get("url"):
        m = re.search(r"//(?:[^@/]*@)?([^:/,?]+)", entry["url"])
        return m.group(1) if m else None
    return (defaults.get(entry.get("type") or "") or {}).get("host")


def resolve(host: str) -> str | None:
    if re.fullmatch(r"[\d.]+", host):
        return host
    try:
        return socket.gethostbyname(host)
    except OSError:
        return None


# --------------------------------------------------------------------------
# Text edits: keep the file as written, change only cloudsql/team.
# --------------------------------------------------------------------------


def find_entries(lines: list[str]) -> dict[str, tuple[int, int]]:
    """alias -> (first line, last line) of each active entry (0-based, inclusive)."""
    spans, i = {}, 0
    while i < len(lines):
        line = lines[i]
        if line.lstrip().startswith("--"):
            i += 1
            continue
        m = re.match(r"^(\s*)\{\s*$", line)
        if m:  # multi-line entry: ends at the "}" with the same indentation
            indent, j = m.group(1), i + 1
            while j < len(lines) and not re.match(rf"^{re.escape(indent)}\}},?\s*(--.*)?$", lines[j]):
                j += 1
            block = "\n".join(lines[i : j + 1])
            a = re.search(r'^\s*alias\s*=\s*"((?:[^"\\]|\\.)*)"', block, re.M)
            if a and j < len(lines):
                spans[a.group(1)] = (i, j)
                i = j + 1
                continue
        elif re.match(r'^\s*\{.*\balias\s*=\s*"', line) and re.search(r"\},?\s*(--.*)?$", line):
            a = re.search(r'\balias\s*=\s*"((?:[^"\\]|\\.)*)"', line)
            spans[a.group(1)] = (i, i)
        i += 1
    return spans


def edit_single_line(line: str, team: str | None, cloudsql: dict | None) -> str:
    m = re.match(r"^(\s*\{)(.*?)(\}\s*,?\s*(?:--.*)?)$", line)
    head, body, tail = m.groups()
    body = body.rstrip().rstrip(",")
    for key, value in (("team", lua_str(team) if team else None), ("cloudsql", cloudsql_lua(cloudsql) if cloudsql else None)):
        if value is None:
            continue
        pattern = rf"\b{key}\s*=\s*(\{{[^{{}}]*\}}|\"(?:[^\"\\]|\\.)*\")"
        if re.search(pattern, body):
            body = re.sub(pattern, lambda _: f"{key} = {value}", body, count=1)
        else:
            body = body + f", {key} = {value}"
    return f"{head}{body} {tail.lstrip()}"


def edit_block(block: list[str], team: str | None, cloudsql: dict | None) -> list[str]:
    inner = block[1:-1]
    indent = re.match(r"^(\s*)", next((l for l in inner if re.match(r"^\s*alias\s*=", l)), "\t\t\t")).group(1)

    def replace_field(key: str, value: str) -> bool:
        for n in top_level():
            l = inner[n]
            if re.match(rf"^\s*{key}\s*=", l):
                end = n
                if l.count("{") > l.count("}"):  # multi-line table value
                    depth = l.count("{") - l.count("}")
                    while depth > 0 and end + 1 < len(inner):
                        end += 1
                        depth += inner[end].count("{") - inner[end].count("}")
                ind = re.match(r"^(\s*)", l).group(1)
                inner[n : end + 1] = [f"{ind}{key} = {value},"]
                return True
        return False

    def top_level():
        """Indexes of the entry's own fields (not lines inside a nested table)."""
        depth, out = 0, []
        for n, l in enumerate(inner):
            if depth == 0:
                out.append(n)
            depth += l.count("{") - l.count("}")
        return out

    def insert_after_simple(lines_to_add: list[str]):
        # a complete one-line field (braces balanced), comma optional
        last = max(
            (n for n in top_level() if SIMPLE_FIELD.match(inner[n]) and inner[n].count("{") == inner[n].count("}")),
            default=len(inner) - 1,
        )
        if not inner[last].rstrip().endswith(","):
            inner[last] = inner[last].rstrip() + ","
        inner[last + 1 : last + 1] = lines_to_add

    if team and not replace_field("team", lua_str(team)):
        insert_after_simple([f"{indent}team = {lua_str(team)},"])
    if cloudsql and not replace_field("cloudsql", cloudsql_lua(cloudsql)):
        # right after team if present, else after the simple fields
        tn = next((n for n in top_level() if re.match(r"^\s*team\s*=", inner[n])), None)
        if tn is not None:
            inner[tn + 1 : tn + 1] = [f"{indent}cloudsql = {cloudsql_lua(cloudsql)},"]
        else:
            insert_after_simple([f"{indent}cloudsql = {cloudsql_lua(cloudsql)},"])
    return [block[0], *inner, block[-1]]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--file", default=str(DEFAULT_FILE))
    ap.add_argument("--project", action="append", default=[], help="also search this project (repeatable)")
    ap.add_argument("--all-projects", action="store_true", help="search every project gcloud can list (slow)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    path = Path(args.file).expanduser()

    data = load_connections(path)
    conns, defaults = data["connections"], data.get("defaults") or {}

    projects = {c["cloudsql"]["project"] for c in conns if isinstance(c.get("cloudsql"), dict) and c["cloudsql"].get("project")}
    projects |= set(args.project)
    if args.all_projects:
        listed, err = gcloud_json(["projects", "list"])
        if listed is None:
            sys.exit(f"gcloud projects list failed: {err}")
        projects |= {p["projectId"] for p in listed}
    if not projects:
        sys.exit("no projects to search: add a cloudsql entry, or pass --project / --all-projects")
    print(f"searching {len(projects)} projects ...", flush=True)
    instances, errors = fetch_instances(sorted(projects))
    for e in errors:
        print(f"  ! {e}")
    by_ip = {ip: i for i in instances for ip in i["ips"]}
    by_name = {(i["project"], i["instance"]): i for i in instances}
    print(f"{len(instances)} Cloud SQL instances")

    hosts = {c["alias"]: host_of(c, defaults) for c in conns}
    with cf.ThreadPoolExecutor(32) as ex:
        ips = dict(zip(hosts, ex.map(lambda h: resolve(h) if h else None, hosts.values())))

    changes, notes = {}, []
    for c in conns:
        alias, current = c["alias"], c.get("cloudsql") if isinstance(c.get("cloudsql"), dict) else None
        inst = by_ip.get(ips.get(alias) or "")
        if not inst and current:
            inst = by_name.get((current.get("project"), current.get("instance")))
            if not inst and current.get("project") in projects:
                notes.append(f"{alias}: cloudsql instance {current.get('project')}/{current.get('instance')} not found (left as is)")
        if not inst:
            continue
        kind = c.get("type") or ""
        if kind in ("postgres", "mysql") and inst["engine"] and inst["engine"] != kind:
            notes.append(f"{alias}: type is {kind} but {inst['instance']} is {inst['engine']}")
        want_sql = {"project": inst["project"], "instance": inst["instance"], "region": inst["region"]}
        want_team = team_name(inst["owner"])
        new_sql = want_sql if want_sql != {k: (current or {}).get(k) for k in want_sql} else None
        new_team = want_team if want_team and want_team != c.get("team") else None
        if new_sql or new_team:
            changes[alias] = {"cloudsql": new_sql, "team": new_team, "old_team": c.get("team"), "old_sql": current}

    for alias, ch in sorted(changes.items(), key=lambda kv: kv[0].lower()):
        parts = []
        if ch["cloudsql"]:
            s = ch["cloudsql"]
            parts.append(("cloudsql " if not ch["old_sql"] else "cloudsql -> ") + f'{s["project"]}/{s["instance"]} ({s["region"]})')
        if ch["team"]:
            parts.append(f'team {ch["old_team"]!r} -> {ch["team"]!r}' if ch["old_team"] else f'team {ch["team"]!r}')
        print(f"  {alias}: " + "; ".join(parts))
    for n in notes:
        print(f"  note: {n}")
    print(f"{len(changes)} connection(s) to update")
    if not changes or args.dry_run:
        return

    lines = path.read_text().split("\n")
    spans = find_entries(lines)
    missing = [a for a in changes if a not in spans]
    if missing:
        sys.exit(f"could not locate in the file: {missing}; nothing written")
    for alias in sorted(changes, key=lambda a: -spans[a][0]):  # bottom-up keeps spans valid
        i, j = spans[alias]
        ch = changes[alias]
        if i == j:
            lines[i] = edit_single_line(lines[i], ch["team"], ch["cloudsql"])
        else:
            lines[i : j + 1] = edit_block(lines[i : j + 1], ch["team"], ch["cloudsql"])

    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    backup = BACKUP_DIR / f"{path.name}.{datetime.datetime.now():%Y%m%d-%H%M%S}.bak"
    shutil.copy2(path, backup)
    backup.chmod(0o600)
    path.write_text("\n".join(lines))
    path.chmod(0o600)

    # Verify: same connections, only cloudsql/team differ, and the new values are in.
    try:
        after = load_connections(path)["connections"]
        before = {c["alias"]: c for c in conns}
        assert len(after) == len(conns), "connection count changed"
        for c in after:
            b = dict(before[c["alias"]])
            a = dict(c)
            ch = changes.get(c["alias"])
            for k in ("cloudsql", "team"):
                if ch and ch[k]:
                    assert a.get(k) == ch[k], f"{c['alias']}: {k} not updated"
                    a.pop(k, None)
                    b.pop(k, None)
            assert a == b, f"{c['alias']}: other fields changed"
    except (AssertionError, SystemExit, KeyError) as e:
        shutil.copy2(backup, path)
        sys.exit(f"verification failed ({e}); restored {backup}")
    print(f"updated {path} (backup: {backup})")


if __name__ == "__main__":
    main()
