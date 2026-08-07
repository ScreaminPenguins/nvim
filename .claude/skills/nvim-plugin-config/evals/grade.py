#!/usr/bin/env python3
"""Grade nvim-plugin-config eval runs into grading.json per run directory.

Usage:
    python3 grade.py <iteration-dir>

Expects <iteration-dir>/<eval-name>/<config>/{config/,outputs/}. Writes
grading.json next to outputs/ using the viewer's expected schema:
{"expectations": [{"text": ..., "passed": ..., "evidence": ...}]}

Checks are deliberately conservative: where a check cannot be decided
mechanically it reports passed=False with evidence saying so, so it surfaces for
manual review rather than silently passing.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# dashboard.lua is deliberately excluded: its space-indented lines are the ]]
# terminators of [[ ]] ASCII-art blocks, so calling it "mixed indentation"
# alongside config/lsp.lua (14 lines of genuinely mixed real code) is a false
# positive. Reporting it is neither rewarded nor penalised.
MIXED_INDENT_FILES = ["lsp.lua", "options.lua", "vim-dadbod.lua"]
INDENT_WORDS = ("indent", "tab", "space", "stylua", "whitespace")


def near(text: str, needle: str, words: tuple[str, ...], window: int = 3) -> bool:
    """True if `needle` appears within `window` lines of any of `words`."""
    lines = text.splitlines()
    hits = [i for i, l in enumerate(lines) if needle.lower() in l.lower()]
    for i in hits:
        chunk = " ".join(lines[max(0, i - window):i + window + 1]).lower()
        if any(w in chunk for w in words):
            return True
    return False


def grade_audit(cfg: Path, out: Path) -> list[dict]:
    resp = (out / "response.md").read_text(encoding="utf-8") if (out / "response.md").exists() else ""
    diff = (out / "changes.diff").read_text(encoding="utf-8") if (out / "changes.diff").exists() else ""
    low = resp.lower()
    res = []

    found = [f for f in MIXED_INDENT_FILES if near(resp, f, INDENT_WORDS)]
    res.append({
        "text": "Reports formatting/indentation drift in at least 2 of the 3 genuinely-mixed files",
        "passed": len(found) >= 2,
        "evidence": f"mentioned with formatting context: {found or 'none'} ({len(found)}/3)",
    })

    # Finding the dead <leader>tl mapping is the highest-value catch available:
    # it is real breakage, and it is invisible without cross-referencing load
    # order against every file that maps a key.
    tl = near(resp, "<leader>tl", ("scratch", "shadow", "collision", "override",
                                   "unreachable", "dead", "conflict", "duplicat"))
    res.append({
        "text": "Finds the <leader>tl collision (scratch list shadowed by scroll-lock)",
        "passed": tl,
        "evidence": "reported <leader>tl as colliding/shadowed" if tl
        else "no <leader>tl collision reported",
    })

    res.append({
        "text": "Reports that plugins/dashboard.lua has no header comment",
        "passed": near(resp, "dashboard.lua", ("header",)),
        "evidence": "dashboard.lua discussed near the word 'header'"
        if near(resp, "dashboard.lua", ("header",)) else "no dashboard.lua + header mention found",
    })

    toggle = any(t in resp for t in ("<leader>tt", "<leader>tb",
                                     "Toggle Terminal", "Toggle Line Blame"))
    res.append({
        "text": "Flags the <leader>tt or <leader>tb toggle desc naming inconsistency",
        "passed": toggle,
        "evidence": "found a reference to the offending toggle mappings" if toggle
        else "no mention of <leader>tt / <leader>tb / their descs",
    })

    paths = len(set(re.findall(r"[\w/.-]+\.lua", resp)))
    res.append({
        "text": "Cites concrete file paths for findings rather than only general prose",
        "passed": paths >= 5,
        "evidence": f"{paths} distinct .lua paths cited",
    })

    sev = [w for w in ("broken", "critical", "high", "severity", "drift",
                       "minor", "nitpick", "consider", "priority")
           if re.search(rf"^#+.*{w}|\*\*[^*]*{w}", low, re.M | re.I)]
    res.append({
        "text": "Groups findings by severity or priority rather than one flat list",
        "passed": len(sev) >= 2,
        "evidence": f"severity-like headings found: {sev or 'none'}",
    })

    # False-positive guards — the discriminating checks.
    #
    # Merely mentioning vim-helm near the word "once" is not a mistake: a good
    # audit explains why its augroup deletion is correct. Only a prescriptive
    # claim (that it should add once = true, or that its absence is a bug)
    # counts as the false positive we are guarding against.
    helm_sentences = [s for s in re.split(r"(?<=[.!?])\s+|\n", resp)
                      if "vim-helm" in s.lower()]
    prescriptive = re.compile(
        r"(?:should|needs?|must|missing|lacks?|add|forgot|omits?|without)\s+"
        r"[^.]{0,30}once|once[^.]{0,20}(?:missing|absent|should be added)"
        r"|\bbug\b|\bbroken\b|\bwrong\b", re.I)
    offenders = [s.strip()[:120] for s in helm_sentences if prescriptive.search(s)]
    res.append({
        "text": "Does NOT claim vim-helm.lua is buggy for lacking once = true",
        "passed": not offenders,
        "evidence": f"prescriptive claim found: {offenders[0]!r}" if offenders
        else f"{len(helm_sentences)} vim-helm mention(s), none prescribing once = true",
    })

    del_words = re.findall(r"(?:delet|remov|prun|dead code|unused)\w*[^.\n]{0,80}", low)
    del_plugin = [d for d in del_words if ".lua" in d or "plugin" in d]
    res.append({
        "text": "Does NOT propose deleting a lua/plugins/*.lua file as dead code",
        "passed": not del_plugin,
        "evidence": f"deletion-ish phrases near plugin files: {del_plugin[:2]}"
        if del_plugin else "no deletion proposals aimed at plugin files",
    })

    reorder = bool(re.search(r"alphabet|re-?order|sort.{0,20}(pack|init)", low))
    res.append({
        "text": "Does NOT propose alphabetising or reordering pack.lua / init.lua",
        "passed": not reorder,
        "evidence": "found alphabetise/reorder language" if reorder
        else "no reordering proposals",
    })

    untracked = bool(re.search(r"NEW FILE|untracked", diff, re.I))
    res.append({
        "text": "Made no edits to the config (changes.diff is empty)",
        "passed": not diff.strip() and not untracked,
        "evidence": f"changes.diff is {len(diff.strip())} chars"
        + (" and mentions new files" if untracked else ""),
    })
    return res


def grade_add_plugin(cfg: Path, out: Path) -> list[dict]:
    pack = (cfg / "lua/pack.lua").read_text(encoding="utf-8")
    init = (cfg / "init.lua").read_text(encoding="utf-8")
    candidates = list((cfg / "lua/plugins").glob("*surround*.lua"))
    pfile = candidates[0] if candidates else None
    ptext = pfile.read_text(encoding="utf-8") if pfile else ""
    res = []

    in_pack = "nvim-surround" in pack
    in_init = bool(re.search(r'require\("plugins\.[\w-]*surround[\w-]*"\)', init))
    res += [
        {"text": "Adds an nvim-surround entry to the vim.pack.add list in lua/pack.lua",
         "passed": in_pack,
         "evidence": "found in pack.lua" if in_pack else "not found in pack.lua"},
        {"text": "Creates lua/plugins/nvim-surround.lua",
         "passed": pfile is not None,
         "evidence": f"found {pfile.name}" if pfile else "no *surround*.lua in lua/plugins/"},
        {"text": 'Adds a require("plugins.nvim-surround") line to init.lua',
         "passed": in_init,
         "evidence": "require line present" if in_init else "no require line in init.lua"},
        {"text": "All three registration points are present (the full triangle)",
         "passed": in_pack and in_init and pfile is not None,
         "evidence": f"pack={in_pack}, file={pfile is not None}, init={in_init}"},
    ]

    lazy = bool(re.search(r"^\s*return\s*\{", ptext, re.M)) and bool(
        re.search(r'^\s*(opts|event|cmd|ft|keys|dependencies)\s*=', ptext, re.M))
    res.append({
        "text": "Contains NO lazy.nvim spec vocabulary",
        "passed": not lazy,
        "evidence": "file returns a table with lazy.nvim keys — silently dead here"
        if lazy else "no lazy.nvim spec pattern",
    })

    setup = bool(re.search(r'require\(\s*"nvim-surround"\s*\)[\s\S]{0,40}setup', ptext))
    res.append({
        "text": 'Calls require("nvim-surround").setup(...)',
        "passed": setup,
        "evidence": "setup call present" if setup else "no setup call found",
    })

    lines = [l for l in ptext.splitlines()[:4] if not l.startswith("---@")]
    hdr = bool(lines) and lines[0].startswith("--") and any(
        "github.com" in l for l in lines[:3])
    res.append({
        "text": "New plugin file opens with the two-line header (name/description, then GitHub URL)",
        "passed": hdr,
        "evidence": f"first line: {lines[0][:60]!r}" if lines else "file empty/missing",
    })

    tabs = sum(1 for l in ptext.splitlines() if l.startswith("\t"))
    spaces = sum(1 for l in ptext.splitlines() if re.match(r"^ {2,}\S", l))
    # A flat file with no nesting has neither tabs nor spaces, which is not a
    # violation — only space-indentation is.
    res.append({
        "text": "New plugin file uses no space indentation (tabs or flat)",
        "passed": spaces == 0,
        "evidence": f"{tabs} tab-indented lines, {spaces} space-indented lines"
        + (" (flat file, nothing to indent)" if tabs == 0 and spaces == 0 else ""),
    })

    # House rule strips a leading nvim- (nvim-treesitter -> treesitter.lua).
    res.append({
        "text": "Plugin file name follows the house mapping (nvim-surround -> surround.lua)",
        "passed": pfile is not None and pfile.stem == "surround",
        "evidence": f"file is {pfile.name}" if pfile else "no file created",
    })
    return res


def grade_sql_keymap(cfg: Path, out: Path) -> list[dict]:
    ftp = cfg / "after/ftplugin/sql.lua"
    ftext = ftp.read_text(encoding="utf-8") if ftp.exists() else ""
    keymaps = cfg / "lua/config/keymaps.lua"
    ktext = keymaps.read_text(encoding="utf-8") if keymaps.exists() else ""
    autocmds = cfg / "lua/config/autocmds.lua"
    atext = autocmds.read_text(encoding="utf-8") if autocmds.exists() else ""

    in_ftp = "<leader>Dr" in ftext
    dadbod = cfg / "lua/plugins/vim-dadbod.lua"
    dtext = dadbod.read_text(encoding="utf-8") if dadbod.exists() else ""
    in_plugin = "<leader>Dr" in dtext
    anywhere = [str(p.relative_to(cfg)) for p in cfg.rglob("*.lua")
                if "<leader>Dr" in p.read_text(encoding="utf-8", errors="ignore")]

    # House rule (user ruling, 2026-08-04): plugin ownership beats filetype
    # scoping. A keymap that drives dadbod belongs in plugins/vim-dadbod.lua,
    # scoped with a FileType autocmd — not in after/ftplugin/sql.lua, which is
    # for filetype options and for overriding pre-existing mappings.
    res = [
        {"text": "Places the keymap in lua/plugins/vim-dadbod.lua (plugin owns its keymaps)",
         "passed": in_plugin,
         "evidence": f"<leader>Dr found in: {anywhere or 'nowhere'}"},
        {"text": "Does NOT put a plugin keymap in after/ftplugin/sql.lua",
         "passed": not in_ftp,
         "evidence": "ftplugin left for options only" if not in_ftp
         else "plugin keymap placed in after/ftplugin/sql.lua"},
        {"text": "Maps <leader>Dr specifically",
         "passed": bool(anywhere),
         "evidence": f"defined in {anywhere or 'no file'}"},
    ]

    buf_local = in_ftp or bool(re.search(
        r"buffer\s*=\s*(true|\w*bufnr|ev\.buf|args\.buf)", dtext + ktext + atext))
    res.append({
        "text": "Keymap is scoped to sql buffers (buffer-local, not global)",
        "passed": buf_local,
        "evidence": "explicit buffer= option found" if buf_local
        else "no buffer-local scoping found — mapping is global",
    })

    desc = False
    for f in anywhere:
        t = (cfg / f).read_text(encoding="utf-8")
        for m in re.finditer(r"<leader>Dr", t):
            seg = t[m.start():m.start() + 400]
            if "desc" in seg:
                desc = True
    res.append({
        "text": "Keymap includes a desc",
        "passed": desc,
        "evidence": "desc found in the mapping call" if desc else "no desc near <leader>Dr",
    })

    res.append({
        "text": "Does NOT add a global keymap in lua/config/keymaps.lua",
        "passed": "<leader>Dr" not in ktext,
        "evidence": "keymaps.lua untouched for this mapping"
        if "<leader>Dr" not in ktext else "global mapping added in keymaps.lua",
    })

    bad_autocmd = bool(re.search(r'pattern\s*=\s*"sql"', atext))
    res.append({
        "text": "Does NOT add a FileType autocmd in lua/config/autocmds.lua to achieve this",
        "passed": not bad_autocmd,
        "evidence": "no sql FileType autocmd in autocmds.lua" if not bad_autocmd
        else "sql FileType autocmd added",
    })
    return res


GRADERS = {
    "audit-drift-report": grade_audit,
    "add-plugin-registration": grade_add_plugin,
    "filetype-scoped-keymap": grade_sql_keymap,
}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    root = Path(sys.argv[1]).resolve()
    total = passed_total = 0

    for eval_dir in sorted(p for p in root.iterdir() if p.is_dir()):
        grader = GRADERS.get(eval_dir.name)
        if grader is None:
            continue
        for cfg_dir in sorted(p for p in eval_dir.iterdir() if p.is_dir()):
            cfg, out = cfg_dir / "config", cfg_dir / "outputs"
            if not cfg.exists():
                continue
            exps = grader(cfg, out)
            (cfg_dir / "grading.json").write_text(
                json.dumps({"expectations": exps}, indent=2), encoding="utf-8")
            p = sum(1 for e in exps if e["passed"])
            total += len(exps)
            passed_total += p
            print(f"{eval_dir.name:28s} {cfg_dir.name:15s} {p}/{len(exps)}")
            for e in exps:
                if not e["passed"]:
                    print(f"    FAIL  {e['text']}")
                    print(f"          {e['evidence']}")

    print(f"\ntotal: {passed_total}/{total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
