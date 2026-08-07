#!/usr/bin/env python3
"""Audit this Neovim config for house-style consistency.

Checks the mechanical invariants that are tedious to verify by eye:
the pack.lua/plugins/init.lua registration triangle, the load=false -> packadd
contract, header comments, indentation, keymap desc coverage, which-key group
coverage, and the <leader>t toggle naming convention.

Run from the config root:
    python3 .claude/skills/nvim-plugin-config/scripts/audit.py
    python3 .claude/skills/nvim-plugin-config/scripts/audit.py --json

Findings are advisory. A finding is not automatically a bug — read
references/conventions.md for which inconsistencies are deliberate.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

# --- Name mapping ------------------------------------------------------------
# pack.lua entries whose config file name does not follow the normal
# "strip .nvim/.vim, drop leading nvim-" rule.
ALIASES = {
    "neo-tree.nvim": "neotree",
    "lkml.vim": "lookml",
}

# Shared dependencies with no config file of their own.
NO_CONFIG_FILE = {
    "plenary.nvim",
    "nvim-web-devicons",
    "nui.nvim",
    "nvim-nio",
    "friendly-snippets",
    "nvim-notify",
}

# Plugins configured as a group by another plugin's file, or from config/.
CONFIGURED_BY = {
    "vim-dadbod-ui": "lua/plugins/vim-dadbod.lua",
    "vim-dadbod-completion": "lua/plugins/vim-dadbod.lua",
    "nvim-dap-ui": "lua/plugins/dap.lua",
    "nvim-dap-python": "lua/plugins/dap.lua",
    "nvim-dap-virtual-text": "lua/plugins/dap.lua",
    "mason-nvim-dap.nvim": "lua/plugins/dap.lua",
    "nvim-lspconfig": "lua/config/lsp.lua",
}

# Config files for locally implemented "plugins" that legitimately have no
# pack.lua entry because there is no upstream repo.
LOCAL_PLUGINS = {"scratch"}

# Headers that deviate from "-- <plugin> — <purpose>" on purpose. lookml.lua
# covers a plugin plus custom tooling, so it reads as a title instead.
HEADER_EXCEPTIONS = {"lookml"}

SEVERITY_ORDER = {"broken": 0, "drift": 1, "consider": 2}


class Audit:
    def __init__(self, root: Path):
        self.root = root
        self.findings: list[dict] = []

    def add(self, severity: str, check: str, message: str,
            file: str = "", line: int = 0) -> None:
        self.findings.append({
            "severity": severity,
            "check": check,
            "message": message,
            "file": file,
            "line": line,
        })

    # --- helpers ------------------------------------------------------------
    def skip(self, path: Path) -> bool:
        """Skip the skill's own files, judged relative to the audit root.

        Testing on a copy of the config placed under some .claude/ directory is
        normal, so an absolute-path check silently skipped every file and
        reported a clean config. Only an in-tree .claude counts.
        """
        try:
            rel = path.relative_to(self.root)
        except ValueError:
            return True
        return ".claude" in rel.parts

    def read(self, rel: str) -> str:
        path = self.root / rel
        return path.read_text(encoding="utf-8") if path.exists() else ""

    @staticmethod
    def normalize(repo: str) -> str:
        """Map a repo name to its expected config file stem."""
        if repo in ALIASES:
            return ALIASES[repo]
        name = re.sub(r"\.(nvim|vim)$", "", repo)
        name = re.sub(r"-nvim$", "", name)
        name = re.sub(r"^nvim-", "", name)
        return name.replace(".", "-")

    def plugin_files(self) -> dict[str, Path]:
        d = self.root / "lua" / "plugins"
        if not d.is_dir():
            return {}
        return {p.stem: p for p in sorted(d.glob("*.lua"))}

    # --- parsing ------------------------------------------------------------
    def parse_pack(self) -> dict[str, dict]:
        """Return {repo_name: {line, load, version, url}} from pack.lua."""
        entries: dict[str, dict] = {}
        text = self.read("lua/pack.lua")
        if not text:
            self.add("broken", "pack.lua", "lua/pack.lua not found", "lua/pack.lua")
            return entries
        for i, raw in enumerate(text.splitlines(), 1):
            line = raw.split("--", 1)[0] if not raw.lstrip().startswith("--") else ""
            m = re.search(r'https://github\.com/([^/"\s]+)/([^/"\s]+)', line)
            if not m:
                continue
            repo = m.group(2)
            version = re.search(r'version\s*=\s*"([^"]+)"', line)
            entries[repo] = {
                "line": i,
                "load": "load = false" not in line.replace(" ", " "),
                "deferred": bool(re.search(r"load\s*=\s*false", line)),
                "version": version.group(1) if version else None,
                "url": m.group(0),
                "owner": m.group(1),
            }
        return entries

    def parse_requires(self) -> dict[str, int]:
        """Return {module_stem: line} for require("plugins.X") in init.lua."""
        out: dict[str, int] = {}
        for i, raw in enumerate(self.read("init.lua").splitlines(), 1):
            if raw.lstrip().startswith("--"):
                continue
            for m in re.finditer(r'require\("plugins\.([\w\-.]+)"\)', raw):
                out[m.group(1)] = i
        return out

    @staticmethod
    def _balanced(text: str, open_paren: int) -> str:
        """Return text from open_paren through its matching close paren."""
        depth, j = 0, open_paren
        while j < len(text):
            if text[j] == "(":
                depth += 1
            elif text[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        return text[open_paren:j + 1]

    @classmethod
    def keymap_calls(cls, text: str):
        """Yield (line_no, lhs, call_text) for each keymap set call."""
        for m in re.finditer(r"(?:vim\.keymap\.set|(?<![\w.])set)\s*\(", text):
            call = cls._balanced(text, m.end() - 1)
            lhs = re.search(
                r'^\(\s*(?:\{[^}]*\}|"[^"]*")\s*,\s*"((?:[^"\\]|\\.)*)"', call)
            yield text.count("\n", 0, m.start()) + 1, (lhs.group(1) if lhs else None), call

    @staticmethod
    def last_arg(call: str) -> str:
        """Return a call's final top-level argument.

        Needed because a mapping's callback body can itself contain
        keymap.set(..., { buffer = true }) calls — config/keymaps.lua's
        scroll-lock toggle does exactly that. Testing the whole call text for
        "buffer =" therefore misreads a global mapping as buffer-local, so the
        options table has to be isolated first.
        """
        body = call[1:-1] if call.startswith("(") else call
        depth, start, quote, i = 0, 0, None, 0
        last = body
        while i < len(body):
            c = body[i]
            if quote:
                if c == "\\":
                    i += 2
                    continue
                if c == quote:
                    quote = None
            elif c in "\"'":
                quote = c
            elif c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
            elif c == "," and depth == 0:
                last = body[start:i]
                start = i + 1
            i += 1
        return body[start:] if start < len(body) else last

    @classmethod
    def is_buffer_local(cls, call: str) -> bool:
        return bool(re.search(r"buffer\s*=", cls.last_arg(call)))

    @classmethod
    def autocmd_blocks(cls, text: str):
        """Yield (line_no, block_text) for each nvim_create_autocmd call."""
        for m in re.finditer(r"nvim_create_autocmd\s*\(", text):
            yield (text.count("\n", 0, m.start()) + 1,
                   cls._balanced(text, m.end() - 1))

    def which_key_groups(self) -> set[str]:
        """Collect <leader>X groups registered anywhere, not just which-key.lua.

        Deferred plugins register their own group inside the packadd callback
        (uv.lua, obsidian.lua, claude-code.lua all do), so scanning only
        which-key.lua reports groups as missing when they are not.
        """
        groups: set[str] = set()
        for path in sorted((self.root / "lua").rglob("*.lua")):
            if self.skip(path):
                continue
            groups.update(re.findall(
                r'"<leader>(\w)"\s*,\s*group\s*=',
                path.read_text(encoding="utf-8")))
        return groups

    # --- checks -------------------------------------------------------------
    def check_triangle(self, pack: dict, files: dict, requires: dict) -> None:
        expected = {}
        for repo, info in pack.items():
            if repo in NO_CONFIG_FILE or repo in CONFIGURED_BY:
                continue
            expected[self.normalize(repo)] = repo

        # A config file with no pack.lua entry is unfinished work, not dead code.
        for stem in files:
            if stem in LOCAL_PLUGINS or stem in expected:
                continue
            self.add(
                "broken", "registration",
                f"lua/plugins/{stem}.lua has no pack.lua entry — this is "
                f"unfinished work, not dead code. Review it and add the "
                f"pack.lua entry; do not delete it.",
                f"lua/plugins/{stem}.lua",
            )

        for stem, repo in expected.items():
            if stem not in files:
                self.add(
                    "consider", "registration",
                    f'"{repo}" is in pack.lua but has no lua/plugins/{stem}.lua. '
                    f"If it is a dependency or configured elsewhere, add it to "
                    f"NO_CONFIG_FILE or CONFIGURED_BY in this script.",
                    "lua/pack.lua", pack[repo]["line"],
                )
            elif stem not in requires:
                self.add(
                    "broken", "registration",
                    f'lua/plugins/{stem}.lua exists but init.lua never requires '
                    f"it — its configuration never runs.",
                    f"lua/plugins/{stem}.lua",
                )

        for stem, line in requires.items():
            if stem not in files:
                self.add(
                    "broken", "registration",
                    f'init.lua requires "plugins.{stem}" but no such file '
                    f"exists — startup will error.",
                    "init.lua", line,
                )

    def check_deferred(self, pack: dict, files: dict) -> None:
        for repo, info in pack.items():
            if not info["deferred"]:
                continue
            stem = self.normalize(repo)
            path = files.get(stem)
            if path is None:
                continue
            text = path.read_text(encoding="utf-8")
            if "packadd" not in text:
                self.add(
                    "broken", "deferred-loading",
                    f'"{repo}" is load = false in pack.lua but '
                    f"lua/plugins/{stem}.lua never calls packadd — the plugin "
                    f"is cloned and then never sourced.",
                    f"lua/plugins/{stem}.lua",
                )
                continue
            if re.search(r'packadd\(?\s*"?' + re.escape(repo), text) is None:
                got = re.search(r'packadd\(?\s*"([^"]+)"', text)
                self.add(
                    "broken", "deferred-loading",
                    f'lua/plugins/{stem}.lua calls packadd("{got.group(1) if got else "?"}") '
                    f'but the on-disk directory is "{repo}" — packadd takes the '
                    f"repo directory name, not the module name.",
                    f"lua/plugins/{stem}.lua",
                )
            # Only the autocmd that does the packadd needs to be one-shot. Other
            # FileType autocmds in the same file often register buffer-local
            # keymaps and are supposed to fire for every matching buffer.
            #
            # once = true is the usual mechanism, but deleting the augroup from
            # inside the callback is equally valid and is the right choice when
            # the callback must keep firing until a condition matches rather
            # than on the first event (vim-helm.lua does this).
            one_shot = (r"once\s*=\s*true"
                        r"|nvim_del_augroup_by_(?:name|id)"
                        r"|return\s+true")
            for line, block in self.autocmd_blocks(text):
                if "packadd" not in block:
                    continue
                if not re.search(one_shot, block):
                    self.add(
                        "drift", "deferred-loading",
                        f"the packadd autocmd in lua/plugins/{stem}.lua is not "
                        f"one-shot — it re-runs and re-registers keymaps on "
                        f"every matching buffer. Add once = true, or delete the "
                        f"augroup from inside the callback.",
                        f"lua/plugins/{stem}.lua", line,
                    )

        # lazy.nvim vocabulary is silently dead here.
        for stem, path in files.items():
            text = path.read_text(encoding="utf-8")
            if re.search(r"^\s*return\s*\{", text, re.M) and re.search(
                    r'^\s*(opts|event|cmd|ft|keys|dependencies)\s*=', text, re.M):
                self.add(
                    "broken", "lazy-nvim-spec",
                    f"lua/plugins/{stem}.lua looks like a lazy.nvim spec "
                    f"(returns a table with opts/event/cmd/ft/keys). Nothing "
                    f"reads that here — this config uses vim.pack.",
                    f"lua/plugins/{stem}.lua",
                )

    def check_headers(self, files: dict) -> None:
        for stem, path in files.items():
            lines = path.read_text(encoding="utf-8").splitlines()
            head = [l for l in lines[:4] if not l.startswith("---@")]
            if not head or not head[0].startswith("--"):
                self.add(
                    "drift", "header",
                    f"lua/plugins/{stem}.lua has no header comment. Convention "
                    f"is '-- <plugin> — <purpose>' then the GitHub URL.",
                    f"lua/plugins/{stem}.lua", 1,
                )
                continue
            if stem in HEADER_EXCEPTIONS:
                continue
            first = head[0]
            if "—" not in first and stem not in LOCAL_PLUGINS:
                if "-" in first[3:]:
                    self.add(
                        "drift", "header",
                        f"lua/plugins/{stem}.lua header uses a hyphen where the "
                        f"convention is an em dash (—).",
                        f"lua/plugins/{stem}.lua", 1,
                    )
                else:
                    self.add(
                        "drift", "header",
                        f"lua/plugins/{stem}.lua header has no description — "
                        f"convention is '-- <plugin> — <purpose>'.",
                        f"lua/plugins/{stem}.lua", 1,
                    )
            if stem not in LOCAL_PLUGINS and not any(
                    "https://github.com/" in l for l in head[:3]):
                self.add(
                    "drift", "header",
                    f"lua/plugins/{stem}.lua header is missing the plugin's "
                    f"GitHub URL on the second line.",
                    f"lua/plugins/{stem}.lua", 1,
                )

    def lua_files(self) -> list[Path]:
        targets = (list((self.root / "lua").rglob("*.lua"))
                   + list((self.root / "after").rglob("*.lua"))
                   + list((self.root / "lsp").glob("*.lua"))
                   + [self.root / "init.lua"])
        return sorted(p for p in targets if p.exists() and not self.skip(p))

    def check_indentation(self) -> None:
        """Report formatting drift, preferring stylua's own verdict.

        Counting tab/space-prefixed lines misjudges files containing [[ ]] long
        strings — dashboard.lua's ASCII art reads as "mixed indentation" when
        only the closing ]] delimiters are involved. stylua is the tool that
        actually decides, so ask it when it is installed and only fall back to
        the heuristic (flagged as approximate) when it is not.
        """
        files = self.lua_files()
        stylua = shutil.which("stylua") or next(
            (str(p) for p in [Path.home() / ".local/share/nvim/mason/bin/stylua"]
             if p.exists()), None)

        if stylua:
            unclean = []
            for path in files:
                try:
                    r = subprocess.run([stylua, "--check", str(path)],
                                       capture_output=True, timeout=20)
                except (OSError, subprocess.TimeoutExpired):
                    stylua = None
                    break
                if r.returncode != 0:
                    unclean.append(str(path.relative_to(self.root)))
            if stylua:
                # One finding, not one per file. These all share a single root
                # cause and a single fix, so listing them separately would bury
                # the findings that need individual decisions.
                if unclean:
                    shown = ", ".join(unclean[:6])
                    more = f", +{len(unclean) - 6} more" if len(unclean) > 6 else ""
                    self.add(
                        "drift", "formatting",
                        f"{len(unclean)} of {len(files)} Lua files are not "
                        f"stylua-clean ({shown}{more}). conform runs stylua on "
                        f"save, so each will reformat wholesale the next time it "
                        f"is touched, mixing noise into an unrelated diff. "
                        f"Reformatting all of them in one commit fixes the whole "
                        f"class. Run `stylua --check <file>` for the current list.",
                    )
                return

        for path in files:
            lines = path.read_text(encoding="utf-8").splitlines()
            tabs = sum(1 for l in lines if l.startswith("\t"))
            spaces = sum(1 for l in lines if re.match(r"^ {2,}\S", l))
            rel = str(path.relative_to(self.root))
            if tabs and spaces:
                self.add(
                    "drift", "indentation",
                    f"{rel} appears to mix tabs ({tabs} lines) and spaces "
                    f"({spaces} lines). Approximate — stylua is not installed, "
                    f"and lines inside [[ ]] strings can skew this.",
                    rel,
                )
            elif spaces and not tabs:
                self.add(
                    "consider", "indentation",
                    f"{rel} is space-indented ({spaces} lines); stylua's default "
                    f"and the house style is tabs.",
                    rel,
                )

    def check_keymaps(self, files: dict) -> None:
        targets = {f"lua/plugins/{s}.lua": p for s, p in files.items()}
        for rel in ("lua/config/keymaps.lua", "lua/config/lsp.lua",
                    "lua/config/autocmds.lua"):
            if (self.root / rel).exists():
                targets[rel] = self.root / rel
        for p in sorted((self.root / "after").rglob("*.lua")):
            targets[str(p.relative_to(self.root))] = p
        for p in sorted((self.root / "lua" / "custom").glob("*.lua")):
            targets[str(p.relative_to(self.root))] = p

        for rel, path in sorted(targets.items()):
            text = path.read_text(encoding="utf-8")
            for line, lhs, call in self.keymap_calls(text):
                if "desc" not in call:
                    self.add(
                        "drift", "keymap-desc",
                        f"keymap {lhs or '<unparsed>'} has no desc — which-key "
                        f"will show a raw command instead of a label.",
                        rel, line,
                    )
                    continue
                if not lhs:
                    continue
                m = re.match(r"<leader>t(\w)", lhs)
                if m:
                    desc = re.search(r'desc\s*=\s*"([^"]*)"', call)
                    if desc and desc.group(1).lower().startswith("toggle") \
                            and not desc.group(1).startswith("Toggle:"):
                        self.add(
                            "drift", "toggle-desc",
                            f'{lhs} desc is "{desc.group(1)}" — the '
                            f'<leader>t* convention is "Toggle: <thing>".',
                            rel, line,
                        )

    def check_which_key(self, files: dict) -> None:
        if not (self.root / "lua" / "plugins" / "which-key.lua").exists():
            return
        groups = self.which_key_groups()

        used: dict[str, int] = {}
        targets = list(files.values())
        targets += [p for p in (self.root / "lua" / "config").glob("*.lua")]
        targets += list((self.root / "after").rglob("*.lua"))
        targets += list((self.root / "lua" / "custom").glob("*.lua"))
        for path in targets:
            if not path.exists():
                continue
            for _, lhs, _ in self.keymap_calls(path.read_text(encoding="utf-8")):
                if not lhs:
                    continue
                m = re.match(r"<leader>(\w)(?=.)", lhs)
                if m:
                    used[m.group(1)] = used.get(m.group(1), 0) + 1

        for prefix, count in sorted(used.items(), key=lambda kv: -kv[1]):
            if count >= 2 and prefix not in groups:
                self.add(
                    "drift", "which-key-group",
                    f"<leader>{prefix} has {count} mappings but no which-key "
                    f"group — the popup shows a bare key instead of a label.",
                    "lua/plugins/which-key.lua",
                )

    def check_keymap_collisions(self) -> None:
        """Find <leader> mappings defined in more than one file.

        The loser is silently unreachable, which is invisible until you press
        the key and get the wrong thing. Scanning keymap.set calls alone is not
        enough: keys also arrive as plain string values in an options table
        (plugins/scratch.lua passes keys = { list = "<leader>tl" } to setup),
        and that is exactly how the one real collision in this config hid. So
        match <leader> string literals anywhere, then filter the two patterns
        that legitimately repeat a key:

        - buffer-local maps, which deliberately shadow a global inside one
          filetype (lookml.lua overrides <leader>ss where there is no LSP)
        - lua/custom/ implementation modules, whose key tables are defaults
          that the caller in lua/plugins/ overrides
        """
        init = self.read("init.lua")
        order = {}
        for i, m in enumerate(re.finditer(r'require\("plugins\.([\w.-]+)"\)', init)):
            order[f"plugins.{m.group(1)}"] = i
        for i, m in enumerate(re.finditer(r'require\("config\.([\w.-]+)"\)', init)):
            order[f"config.{m.group(1)}"] = 1000 + i

        seen: dict[str, list[tuple[str, int, int]]] = {}
        for path in self.lua_files():
            rel = path.relative_to(self.root)
            # after/ftplugin is buffer-local by nature; lua/custom holds defaults.
            if rel.parts[:2] in (("after", "ftplugin"), ("lua", "custom")):
                continue
            text = path.read_text(encoding="utf-8")
            mod = f"{rel.parts[1]}.{path.stem}" if len(rel.parts) > 2 else path.stem
            buf_local_keys = {lhs for _, lhs, c in self.keymap_calls(text)
                              if lhs and self.is_buffer_local(c)}
            for i, line in enumerate(text.splitlines(), 1):
                if line.lstrip().startswith("--"):
                    continue
                for m in re.finditer(r'"(<leader>\S+?)"', line):
                    lhs = m.group(1)
                    if lhs in buf_local_keys:
                        continue
                    seen.setdefault(lhs, []).append(
                        (str(rel), i, order.get(mod, -1)))

        for lhs, locs in sorted(seen.items()):
            if len({f for f, _, _ in locs}) < 2:
                continue
            locs.sort(key=lambda t: t[2])
            winner = locs[-1]
            losers = ", ".join(f"{f}:{l}" for f, l, _ in locs[:-1])
            self.add(
                "broken", "keymap-collision",
                f"{lhs} is mapped in {len({f for f, _, _ in locs})} files. "
                f"init.lua loads {winner[0]} last, so it wins and the mapping "
                f"in {losers} is unreachable.",
                winner[0], winner[1],
            )

    def check_stylua_config(self) -> None:
        conform = self.read("lua/plugins/conform.lua")
        if "stylua" in conform and not any(
                (self.root / n).exists() for n in ("stylua.toml", ".stylua.toml")):
            self.add(
                "consider", "formatter-config",
                "conform runs stylua on Lua but there is no stylua.toml, so "
                "stylua's defaults (tabs, width 4) apply implicitly. Adding one "
                "would make the house style explicit and reproducible.",
                "lua/plugins/conform.lua",
            )

    def run(self) -> list[dict]:
        pack = self.parse_pack()
        files = self.plugin_files()
        requires = self.parse_requires()
        self.check_triangle(pack, files, requires)
        self.check_deferred(pack, files)
        self.check_headers(files)
        self.check_indentation()
        self.check_keymaps(files)
        self.check_keymap_collisions()
        self.check_which_key(files)
        self.check_stylua_config()
        self.findings.sort(key=lambda f: (
            SEVERITY_ORDER.get(f["severity"], 9), f["check"], f["file"], f["line"]))
        return self.findings


HEADINGS = {
    "broken": "BROKEN INVARIANTS — a plugin silently does not load, or startup errors",
    "drift": "DRIFT — real inconsistency with the house style, mechanical to fix",
    "consider": "WORTH CONSIDERING — judgement calls, not necessarily wrong",
}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", default=".", help="config root (default: cwd)")
    ap.add_argument("--json", action="store_true", help="emit JSON")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if not (root / "init.lua").exists():
        print(f"error: {root} has no init.lua — run from the config root.",
              file=sys.stderr)
        return 2

    findings = Audit(root).run()

    if args.json:
        print(json.dumps({"root": str(root), "findings": findings}, indent=2))
        return 0

    counts = {s: sum(1 for f in findings if f["severity"] == s)
              for s in SEVERITY_ORDER}
    print(f"Neovim config audit — {root}")
    print(f"{counts['broken']} broken, {counts['drift']} drift, "
          f"{counts['consider']} to consider\n")

    if not findings:
        print("No mechanical findings. Style checks pass.")
        return 0

    for severity in ("broken", "drift", "consider"):
        group = [f for f in findings if f["severity"] == severity]
        if not group:
            continue
        print(HEADINGS[severity])
        print("-" * 78)
        for f in group:
            loc = (f["file"] + (f":{f['line']}" if f["line"] else "")
                   if f["file"] else "(config-wide)")
            print(f"  [{f['check']}] {loc}")
            print(f"      {f['message']}")
        print()

    print("Findings are advisory — see references/conventions.md for the "
          "exceptions that are deliberate.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
