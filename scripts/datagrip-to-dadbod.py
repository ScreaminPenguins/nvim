#!/usr/bin/env python3
"""Convert DataGrip data sources into a dadbod connections file (Lua).

Reads a DataGrip project's .idea/dataSources.xml (names, folders, JDBC URLs)
and dataSources.local.xml (user names, auth provider) and writes entries in
the format of lua/config/db_connections.lua, as a reference to copy from.

Never reads or writes passwords: DataGrip keeps those in its own password
store, and they are not in these files. Entries with a user get
`secret = true`; store each password with
    security add-generic-password -U -s nvim-dadbod -a "<alias>" -w

Usage:
    scripts/datagrip-to-dadbod.py [PROJECT_DIR] [-o OUT]

PROJECT_DIR  DataGrip project folder (contains .idea/); default: the only
             project under ~/DataGripProjects
OUT          default: lua/config/db_connections.datagrip.lua (gitignored)

Mapping:
    name            -> alias
    folder (group)  -> group
    jdbc-url        -> type, host, port, database, params
    user-name       -> user (+ secret = true)
    BigQuery        -> project from the ProjectId property, no secret (gcloud)
    MongoDB / other -> url = "..." (dadbod's raw-URL form), user spliced in
Anything that needs a look is marked with a `-- CHECK:` comment.
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import parse_qsl, quote

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "lua" / "config" / "db_connections.datagrip.lua"

TYPES = {"postgresql": "postgres", "mysql": "mysql", "mariadb": "mariadb", "redis": "redis", "sqlserver": "sqlserver"}
DEFAULT_PORTS = {"postgres": 5432, "mysql": 3306, "mariadb": 3306, "redis": 6379, "sqlserver": 1433}


def lua_str(s: str) -> str:
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def lua_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{lua_key(k)} = {lua_value(x)}" for k, x in v.items()) + " }"
    if isinstance(v, list):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }"
    return lua_str(v)


def lua_key(k: str) -> str:
    return k if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", k) else f"[{lua_str(k)}]"


def find_project(arg: str | None) -> Path:
    if arg:
        return Path(arg).expanduser()
    projects = [p.parent.parent for p in (Path.home() / "DataGripProjects").glob("*/.idea/dataSources.xml")]
    if len(projects) != 1:
        sys.exit(f"pass the DataGrip project folder; found {len(projects)} under ~/DataGripProjects")
    return projects[0]


def parse_jdbc(url: str):
    """(scheme, host, port, database, params) for host-style JDBC URLs, else None."""
    m = re.match(r"jdbc:(\w+)://([^/:;?]+)(?::(\d+))?(?:/([^?;]*))?(?:[?;](.*))?$", url)
    if not m:
        return None
    scheme, host, port, db, rest = m.groups()
    params = {}
    if rest:
        sep = ";" if ";" in rest and "&" not in rest else "&"
        params = dict(parse_qsl(rest.replace(";", "&") if sep == ";" else rest, keep_blank_values=True))
    return scheme, host, int(port) if port else None, db or None, params


def convert(ds: ET.Element, local: dict) -> tuple[dict, list[str]]:
    name = ds.get("name")
    entry: dict = {"alias": name}
    checks: list[str] = []
    if ds.get("group"):
        entry["group"] = ds.get("group")
    url = (ds.findtext("jdbc-url") or "").strip()
    driver = (ds.findtext("driver-ref") or "").strip()
    props = {p.get("name"): p.get("value") for p in ds.iter("property")}
    info = local.get(ds.get("uuid"), {})
    user = info.get("user")
    auth = info.get("auth")

    if driver.startswith("bigquery"):
        entry["type"] = "bigquery"
        project = props.get("ProjectId") or (re.search(r"ProjectId=([^;]+)", url) or [None, None])[1]
        if project:
            entry["project"] = project
        else:
            checks.append("no ProjectId found; set project")
        return entry, checks

    parsed = parse_jdbc(url)
    scheme = parsed and TYPES.get(parsed[0])
    if parsed and scheme:
        _, host, port, db, params = parsed
        entry["type"] = scheme
        entry["host"] = host
        if port and port != DEFAULT_PORTS.get(scheme):
            entry["port"] = port
        if scheme == "sqlserver" and "database" in params:
            db = params.pop("database")
        if db:
            entry["database"] = int(db) if scheme == "redis" and db.isdigit() else db
        if params:
            entry["params"] = params
        if ("." not in host and host != "localhost") or re.search(r"\.svc(\.|$)", host):
            checks.append(f"host '{host}' looks cluster-internal; may only resolve on that network")
    else:
        # MongoDB and anything else: dadbod's raw-URL form.
        raw = re.sub(r"^jdbc:", "", url)
        if user and "@" not in raw.split("/")[2 if "//" in raw else 0]:
            raw = re.sub(r"^([\w+.-]+://)", lambda m: m.group(1) + quote(user, safe="") + "@", raw, count=1)
        entry["url"] = raw
        checks.append(f"driver '{driver}': check dadbod supports this URL")

    if user:
        entry["user"] = user if "url" not in entry else None
        if entry["user"] is None:
            del entry["user"]
        if auth != "no-auth":
            entry["secret"] = True
    return entry, checks


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("project", nargs="?")
    ap.add_argument("-o", "--out", default=str(DEFAULT_OUT))
    args = ap.parse_args()

    idea = find_project(args.project) / ".idea"
    sources = ET.parse(idea / "dataSources.xml").getroot()
    local: dict = {}
    local_path = idea / "dataSources.local.xml"
    if local_path.exists():
        for d in ET.parse(local_path).getroot().iter("data-source"):
            local[d.get("uuid")] = {
                "user": (d.findtext("user-name") or "").strip() or None,
                "auth": (d.findtext("auth-provider") or "").strip() or None,
            }

    order = ["alias", "group", "type", "host", "port", "user", "database", "project", "url", "params", "secret"]
    by_group: dict[str, list[str]] = {}
    counts: dict[str, int] = {}
    n_checks = 0
    for ds in sources.iter("data-source"):
        entry, checks = convert(ds, local)
        fields = [f"{k} = {lua_value(entry[k])}" for k in order if k in entry]
        line = "\t\t{ " + ", ".join(fields) + " },"
        if checks:
            n_checks += 1
            line += "  -- CHECK: " + "; ".join(checks)
        by_group.setdefault(entry.get("group") or "(no folder)", []).append(line)
        kind = entry.get("type") or "url"
        counts[kind] = counts.get(kind, 0) + 1

    out = [
        "-- Generated by scripts/datagrip-to-dadbod.py from " + str(idea.parent),
        "-- A reference to copy from into db_connections.lua (gitignored; regenerate any time).",
        "-- No passwords: store them with",
        '--   security add-generic-password -U -s nvim-dadbod -a "<alias>" -w',
        "-- stylua: ignore",
        "return {",
        "\tdefaults = {",
        '\t\tpostgres = { port = 5432 },',
        "\t\tmysql = { port = 3306 },",
        "\t\tredis = { port = 6379 },",
        "\t},",
        "",
        "\tconnections = {",
    ]
    for group in sorted(by_group, key=lambda g: (g == "(no folder)", g.lower())):
        out.append(f"\t\t-- {group} ({len(by_group[group])})")
        out.extend(sorted(by_group[group], key=str.lower))
        out.append("")
    out[-1:] = ["\t},", "}", ""]
    Path(args.out).write_text("\n".join(out))
    Path(args.out).chmod(0o600)
    total = sum(counts.values())
    print(f"wrote {total} connections to {args.out}")
    print("  " + ", ".join(f"{k}: {v}" for k, v in sorted(counts.items(), key=lambda kv: -kv[1])))
    print(f"  {n_checks} marked CHECK")


if __name__ == "__main__":
    main()
