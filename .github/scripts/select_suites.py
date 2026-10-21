"""Choose the MATLAB test suites a change can affect (CI on pull requests, and by hand).

Usage: python select_suites.py BASE HEAD
       python select_suites.py --worktree [BASE] [--sections] [--why] [--expect]
    BASE, HEAD  git revisions; the change is `git diff BASE HEAD`, and the
                files are read as they are in the working tree (HEAD).
    --worktree  the change is the working tree against BASE (HEAD when left
                out), untracked files included as wholly new
    --sections  for a suite that takes sections (TestSections), name only the
                sections the change reaches, as test_X:5i,5j, when every hit
                lies inside sections; a hit in the suite's setup, its local
                functions or a suite without sections runs the whole suite
    --why       print why each suite (or section) runs, one line each
    --expect    with --why, add the seconds the last runs took, from
                tools\\Run-Tests.ps1's ledger (%LOCALAPPDATA%\\ephys_analysis)

Prints one line: "all", "none", or the suite names separated by spaces. With
GITHUB_STEP_SUMMARY set, appends why each suite was chosen to the job summary.
tools\\Run-Tests.ps1 -Select runs what --worktree --sections prints.

What a change names
- A .m file whose changed lines are all comments or blank: nothing.
- foo.m (a function file): foo. A change to one of its local functions is a
  change to foo.
- @Cls/meth.m: the method meth. @Cls/Cls.m, or a classdef file Cls.m: the
  functions whose lines changed (the constructor is the class); a change
  outside them (properties, method declarations, events) names the class.
- private/foo.m: foo, which only the folder above can call.
- A data or Python file: its base name. A file in pipeline/hardware: also the
  hardware bank (HardwareBank), which reads every file there.
- VERSION, CITATION.cff, CHANGELOG.md: test_RepositoryMetadata.
- Other documentation (*.md, documentation/, tools/, LICENSE): nothing.

Who uses it
A function or class is used where its whole word appears, a method where
.meth appears (obj.meth, Cls.meth) or, inside its own class, its word.
Comments do not count in the code, and do count in the suites. The users of a
name inside its own class (or, for a private function, its folder) are
followed to their own users until nothing more is added, so a change to a
private helper of an app reaches the app's constructor; a user anywhere else
is followed one step only.

A suite (pipeline/test_*.m, analysis/test_*.m) runs when it changed or uses a
changed name or one of its users. test_ClassdefDeclarations also runs when a
file of an @Class folder or a classdef changes, test_RepositoryMetadata when
the release files do. Every suite runs when the test runner, the CI workflow
or its scripts change.

Name matching cannot see a call made from a string built at run time, nor a
user two or more steps out across folders, so CI also runs every suite on
each push to main.
"""
import argparse
import csv
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SUITE_DIRS = ("pipeline", "analysis")
RUN_ALL = {
    "pipeline/run_all_tests.m",
    "pipeline/LegacySuiteTest.m",
    "pipeline/findTestSuites.m",
    ".github/workflows/matlab-tests.yml",
}
RUN_ALL_PREFIXES = (".github/scripts/",)
METADATA_FILES = {"VERSION", "CITATION.cff", "CHANGELOG.md"}
METADATA_SUITE = "test_RepositoryMetadata"
CLASSDEF_SUITE = "test_ClassdefDeclarations"
DOC_PREFIXES = ("documentation/", "tools/", ".claude/")
DOC_EXTS = {".md", ".txt", ".cff", ".png", ".svg", ".jpg"}
DOC_FILES = {"LICENSE", ".gitignore"}
HARDWARE_PREFIX = "pipeline/hardware/"
FUNC = re.compile(r"^[ \t]*function\s+(?:\[[^\]]*\]\s*=\s*|[\w.]+\s*=\s*)?([A-Za-z][\w.]*)", re.M)
CLASSDEF = re.compile(r"^\s*classdef\b", re.M)
WORD = re.compile(r"[A-Za-z]\w*")
DOTTED = re.compile(r"\.([A-Za-z]\w*)")
# a section of a function-style suite: its S.sec("id", ...) / S.wants("id") guard (TestSections), or
# the "== id. title ==" header of a suite not converted yet
SECTION = re.compile(r'^[ \t]*if S\.(?:sec|wants)\("([^"]+)"|^fprintf\(\'\\n== (\S+)\. ', re.M)
ACCEPTS = re.compile(r"^\s*opts\.Sections\s*\(", re.M)
MAIN_END = re.compile(r"^end[ \t]*$", re.M)
LEDGER_DIR = os.path.join(os.environ.get("LOCALAPPDATA", ""), "ephys_analysis")


# --- files -----------------------------------------------------------------------------------

def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True,
                          encoding="utf-8", errors="replace").stdout


def read(rel):
    try:
        with open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def suite_files():
    """{suite name: relative path}."""
    out = {}
    for d in SUITE_DIRS:
        for f in sorted(os.listdir(os.path.join(ROOT, d))):
            if f.startswith("test_") and f.endswith(".m"):
                out[f[:-2]] = f"{d}/{f}"
    return out


def class_folder(rel):
    """The @Cls folder REL is in ("" when none)."""
    parts = rel.split("/")
    for i in range(len(parts) - 2, -1, -1):
        if parts[i].startswith("@"):
            return "/".join(parts[:i + 1])
    return ""


def private_home(rel):
    """For a private function, the folder whose functions can call it ("" otherwise)."""
    parts = rel.split("/")
    return "/".join(parts[:-2]) if len(parts) > 1 and parts[-2] == "private" else ""


def inside(rel, home):
    """True when code in REL can use a name whose HOME is a class folder (anything in it), a
    classdef file (that file) or a private function's folder (that folder and its private)."""
    if not home:
        return False
    if home.endswith(".m"):
        return rel == home
    if home.split("/")[-1].startswith("@"):
        return rel.startswith(home + "/")
    return os.path.dirname(rel) in (home, home + "/private")


def strip_comments(text):
    """TEXT without MATLAB comments (% to the end of a line outside strings, %{ ... %} blocks)."""
    out, block = [], 0
    for line in text.split("\n"):
        t = line.strip()
        if t == "%{":
            block += 1
            out.append("")
            continue
        if t == "%}" and block:
            block -= 1
            out.append("")
            continue
        if block:
            out.append("")
            continue
        code, quote, prev, i = [], None, "", 0
        while i < len(line):
            ch = line[i]
            if quote:
                code.append(ch)
                if ch == quote:
                    if i + 1 < len(line) and line[i + 1] == quote:   # '' or "" inside a string
                        code.append(line[i + 1])
                        i += 1
                    else:
                        quote = None
            elif ch == "%":
                break
            elif ch == '"' or (ch == "'" and not (prev.isalnum() or prev in "_)]}.'")):
                quote = ch
                code.append(ch)
            else:
                code.append(ch)
            if not ch.isspace():
                prev = ch
            i += 1
        out.append("".join(code))
    return "\n".join(out)


def is_comment_or_blank(line):
    t = line.strip()
    return t == "" or t.startswith("%")


def changed_lines(base, head=None, untracked=False):
    """({path: changed line numbers in HEAD}, deleted paths, paths whose change touches code).

    HEAD None: the working tree against BASE. UNTRACKED: files git does not track count as wholly
    new. A .m file whose added and removed lines are all comments or blank does not touch code."""
    revs = [base] if head is None else [base, head]
    lines, deleted, code = {}, set(), set()
    cur = prev = None
    in_hunk = False
    for ln in git("diff", "--no-renames", "-U0", *revs).splitlines():
        if ln.startswith("diff --git "):
            cur = prev = None
            in_hunk = False
        elif not in_hunk and ln.startswith("--- "):
            prev = None if ln[4:] == "/dev/null" else ln[6:]
        elif not in_hunk and ln.startswith("+++ "):
            cur = None if ln[4:] == "/dev/null" else ln[6:]
            if cur is None:
                deleted.add(prev)
        elif ln.startswith("@@"):
            in_hunk = True
            m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", ln)
            start, n = int(m.group(1)), int(m.group(2) or 1)
            if cur is not None:
                lines.setdefault(cur, set()).update(range(start, start + n) if n else {start})
        elif in_hunk and ln[:1] in "+-" and not is_comment_or_blank(ln[1:]):
            code.add(cur or prev)
    for p in git("diff", "--no-renames", "--name-only", *revs).splitlines():
        lines.setdefault(p, set())
        if not p.endswith(".m"):
            code.add(p)                           # only MATLAB comments are told apart
    if untracked:
        for p in git("ls-files", "--others", "--exclude-standard").splitlines():
            text = read(p)
            lines[p] = set(range(1, text.count("\n") + 2))
            if not p.endswith(".m") or any(not is_comment_or_blank(l) for l in text.split("\n")):
                code.add(p)
    code |= deleted
    return lines, deleted, code


# --- sections --------------------------------------------------------------------------------

def suite_sections(text):
    """[(id, first line, line after the last)] of a suite's sections, in file order (an id can come
    twice: a continuation block); [] for a suite without sections. The lines before the first section
    (the fixture) and from the main function's `end` on (its local functions) are in no section."""
    starts = [(text.count("\n", 0, m.start()) + 1, m.group(1) or m.group(2)) for m in SECTION.finditer(text)]
    if not starts:
        return []
    # the main function's end: the first `end` at column 0 after the last section start
    last_start_pos = [m.start() for m in SECTION.finditer(text)][-1]
    tail = MAIN_END.search(text, pos=last_start_pos)
    end_line = text.count("\n", 0, tail.start()) + 1 if tail else text.count("\n") + 2
    out = []
    for i, (ln, sid) in enumerate(starts):
        nxt = starts[i + 1][0] if i + 1 < len(starts) else end_line
        out.append((sid, ln, nxt))
    return out


def section_of(segs, row):
    """The id of the section holding line ROW, or None (the fixture or the local functions)."""
    for sid, start, end in segs:
        if start <= row < end:
            return sid
    return None


def ordered_ids(segs, ids):
    """IDS in the order their sections come in the file, each once."""
    seen, out = set(), []
    for sid, _, _ in segs:
        if sid in ids and sid not in seen:
            seen.add(sid)
            out.append(sid)
    return out


def segments(text):
    """[(function name, or "" for what comes before the first function, text)] of a .m file."""
    starts = [(m.start(), m.group(1).split(".")[-1]) for m in FUNC.finditer(text)]
    out = [("", text[:starts[0][0]] if starts else text)]
    for i, (s, n) in enumerate(starts):
        out.append((n, text[s:starts[i + 1][0] if i + 1 < len(starts) else len(text)]))
    return out


def touched_functions(rel, rows):
    """The functions of REL whose lines changed, and whether a line outside them changed."""
    text = read(rel)
    starts = [(text.count("\n", 0, m.start()) + 1, m.group(1).split(".")[-1]) for m in FUNC.finditer(text)]
    names, outside = set(), False
    for r in rows:
        before = [n for (s, n) in starts if s <= max(r, 1)]
        if before:
            names.add(before[-1])
        else:
            outside = True
    return names, outside


# --- names -----------------------------------------------------------------------------------

class Names:
    """Names a change reaches: words (functions, classes) and methods, each with where it comes
    from and its home (where alone it can be used: a class folder, a classdef file, a private
    function's folder; "" for anywhere)."""

    def __init__(self):
        self.words = {}       # name -> (why, home, via_class)
        self.methods = {}     # method -> (why, home, via_class)

    def add(self, kind, n, home, why, via_class=False):
        """VIA_CLASS: N is a class reached from inside its own folder (a method's users followed up to
        the constructor), not changed itself; a suite's setup that builds the class covers that."""
        d = self.words if kind == "word" else self.methods
        if n in d:
            return False
        d[n] = (why, home, via_class)
        return True

    def uses(self, rel, text, local=True):
        """[(name as used, why, home, via_class)] of the names REL's text uses. LOCAL=False leaves
        out the bare names of methods (a classdef's declarations list them)."""
        out = []
        words = set(WORD.findall(text))
        for n in sorted(words & set(self.words)):
            why, home, via = self.words[n]
            if not home or inside(rel, home):
                out.append((n, why, home, via))
        for n in sorted(set(DOTTED.findall(text)) & set(self.methods)):
            why, home, via = self.methods[n]
            out.append(("." + n, why, home, via))
        if local:
            for n in sorted(words & set(self.methods)):
                why, home, via = self.methods[n]
                if inside(rel, home):
                    out.append((n, why, home, via))
        return out


def name_change(names, rel, rows, deleted):
    """Add what changed file REL names; return the suites it calls for by itself."""
    base, ext = os.path.splitext(os.path.basename(rel))
    if rel in METADATA_FILES:
        return {METADATA_SUITE}
    if rel.startswith(DOC_PREFIXES) or ext in DOC_EXTS or os.path.basename(rel) in DOC_FILES:
        return set()
    extra = set()
    if rel.startswith(HARDWARE_PREFIX):
        names.add("word", "HardwareBank", "", rel)
    if ext != ".m":
        names.add("word", base, "", rel)
        return extra
    folder = class_folder(rel)
    if folder and rel.split("/")[0] in SUITE_DIRS:
        extra.add(CLASSDEF_SUITE)
    if private_home(rel):
        names.add("word", base, private_home(rel), rel)
        return extra
    if rel not in deleted and CLASSDEF.search(read(rel)):
        extra.add(CLASSDEF_SUITE)
        cls = folder.split("/")[-1][1:] if folder else base
        funcs, outside = touched_functions(rel, rows) if rows else (set(), True)
        if outside:
            names.add("word", cls, "", rel)
        for f in funcs:
            if f == cls:
                names.add("word", cls, "", f"{rel} (constructor)")
            else:
                names.add("method", f, folder or rel, f"{rel} ({f})")
    elif folder:
        names.add("method", base, folder, rel)    # @Cls/meth.m
    else:
        names.add("word", base, "", rel)          # foo.m, local functions included
    return extra


def users(rel, text, reached):
    """[(kind, name, home, why, followed, via_class)]: what in REL uses a REACHED name. A classdef
    is split into its functions (what comes before them, the header and declarations, stands for
    the class); any other file is one name. FOLLOWED: REL is inside the home of a name it uses.
    VIA_CLASS: the class itself, reached from inside its own folder."""
    folder = class_folder(rel)
    base = os.path.splitext(os.path.basename(rel))[0]
    out = []
    if CLASSDEF.search(text):
        cls = folder.split("/")[-1][1:] if folder else base
        for fname, seg in segments(text):
            hits = reached.uses(rel, seg, local=bool(fname))
            if not hits:
                continue
            followed = any(inside(rel, h[2]) for h in hits)
            via = all(h[3] for h in hits)          # reached only through such a class: the same for its users
            why = f"{hits[0][1]}, through {rel}" + (f" ({fname})" if fname else "")
            if not fname or fname == cls:
                out.append(("word", cls, "", why, followed, followed or via))
            else:
                out.append(("method", fname, folder or rel, why, followed, via))
        return out
    hits = reached.uses(rel, text)
    if hits:
        followed = any(inside(rel, h[2]) for h in hits)
        via = all(h[3] for h in hits)
        why = f"{hits[0][1]}, through {rel}"
        if private_home(rel):
            out.append(("word", base, private_home(rel), why, followed, via))
        elif folder:
            out.append(("method", base, folder, why, followed, via))
        else:
            out.append(("word", base, "", why, followed, via))
    return out


def select(base, head=None, sections=False, untracked=False):
    """("all" | "none" | [items], {item: why}, [changed paths]); an item is a suite, or, with SECTIONS,
    "suite:id1,id2" when every hit in a suite that takes sections lies inside its sections."""
    rows, deleted, touches_code = changed_lines(base, head, untracked)
    changed = sorted(rows)
    if any(c in RUN_ALL or c.startswith(RUN_ALL_PREFIXES) for c in changed):
        return "all", {}, changed
    suites = suite_files()
    suite_paths = set(suites.values())
    why = {}            # suite -> why the whole suite runs
    section_why = {}    # suite -> {section id: why}
    segs = {}           # suite -> its sections (when SECTIONS and the suite takes them)
    if sections:
        for s, rel in suites.items():
            text = read(rel)
            if ACCEPTS.search(text):
                segs[s] = suite_sections(text)

    def hit(suite, reason, row=None, text_segment=None):
        """Record a hit on SUITE: on the section holding ROW / named by TEXT_SEGMENT, else on the whole."""
        sid = text_segment
        if sid is None and row is not None and suite in segs:
            sid = section_of(segs[suite], row)
        if sid is not None and suite in segs:
            section_why.setdefault(suite, {}).setdefault(sid, reason)
        else:
            why.setdefault(suite, reason)

    def tail_parts(s, text):
        """(the setup text, [(local function name, its text)], {section id: its text}) of suite S."""
        lines = text.split("\n")
        first = segs[s][0][1]
        last = segs[s][-1][2]
        setup = "\n".join(lines[:first - 1])
        funcs = segments("\n".join(lines[last - 1:]))
        bodies = {}
        for sid, start, end in segs[s]:
            bodies[sid] = bodies.get(sid, "") + "\n" + "\n".join(lines[start - 1:end - 1])
        return setup, funcs, bodies

    def hit_local(s, fname, reason, bodies, setup):
        """A hit in the local function FNAME of suite S: the sections that call it; the first section
        when only the setup does; the whole suite when it is not called from them at all."""
        word = re.compile(r"\b" + re.escape(fname) + r"\b")
        callers = [sid for sid, body in bodies.items() if word.search(body)]
        for sid in callers:
            hit(s, f"{reason} through {fname}", text_segment=sid)
        if not callers:
            if word.search(setup):
                hit(s, f"{reason} through {fname}, in its setup", text_segment=segs[s][0][0])
            else:
                hit(s, f"{reason} through {fname}")

    reached = Names()                             # the changed names, and their users inside their homes
    for c in changed:
        if c in suite_paths:
            s = os.path.basename(c)[:-2]
            if s in segs and segs[s] and rows[c] and c not in deleted:
                text = read(c)
                setup, funcs, bodies = tail_parts(s, text)
                first_line = segs[s][0][1]
                last_line = segs[s][-1][2]
                tail_start = last_line
                func_lines = []   # (first line of each local function in the file, name)
                pos = 0
                tail_text = "\n".join(text.split("\n")[last_line - 1:])
                for fname, seg in funcs:
                    func_lines.append((tail_start + tail_text.count("\n", 0, pos), fname))
                    pos += len(seg)
                for r in sorted(rows[c]):
                    if r < first_line:
                        hit(s, f"changed: {c} (its setup)", text_segment=segs[s][0][0])
                    elif r < last_line:
                        hit(s, f"changed: {c}", row=r)
                    else:
                        fname = [n for (ln, n) in func_lines if ln <= r][-1] if func_lines else ""
                        if fname:
                            hit_local(s, fname, f"changed: {c}", bodies, setup)
                        else:
                            hit(s, f"changed: {c}")
            else:
                why.setdefault(s, f"changed: {c}")
        elif c in touches_code:
            for s in name_change(reached, c, rows[c], deleted):
                why.setdefault(s, f"{c} changed")

    code = {}
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for f in filenames:
            rel = os.path.relpath(os.path.join(dirpath, f), ROOT).replace("\\", "/")
            if f.endswith(".m") and rel not in suite_paths and rel not in RUN_ALL:   # not the test runner
                code[rel] = strip_comments(read(rel))   # help text and See also lines are not calls

    # users inside a name's home are followed until nothing is added; others are one step out
    outer = Names()
    grew = True
    while grew:
        grew = False
        for rel, text in code.items():
            for kind, n, home, src, followed, via_class in users(rel, text, reached):
                if followed:
                    grew = reached.add(kind, n, home, src, via_class) or grew
                else:
                    outer.add(kind, n, home, src, via_class)

    for s, rel in suites.items():
        if s in why:
            continue
        text = read(rel)
        if s in segs and segs[s]:
            setup, funcs, bodies = tail_parts(s, text)
            # The setup runs with any section. A name changed or reached through its users that the
            # setup uses means every section may see it: the whole suite. A class reached only from
            # inside its own folder (a method followed up to the constructor) is covered by the
            # setup building it: the first section is enough, and the sections that merely name
            # the class (new builds, static calls) are left alone.
            hits = reached.uses(rel, setup) or outer.uses(rel, setup)
            direct = [h for h in hits if not h[3]]
            if direct:
                hit(s, f"uses {direct[0][0]} ({direct[0][1]}) in its setup")
            elif hits:
                hit(s, f"uses {hits[0][0]} ({hits[0][1]}) in its setup", text_segment=segs[s][0][0])
            for fname, seg in funcs:
                hits = [h for h in (reached.uses(rel, seg) or outer.uses(rel, seg)) if not h[3]]
                if not hits:
                    continue
                if fname:
                    hit_local(s, fname, f"uses {hits[0][0]} ({hits[0][1]})", bodies, setup)
                else:
                    hit(s, f"uses {hits[0][0]} ({hits[0][1]})")
            for sid, body in bodies.items():
                hits = [h for h in (reached.uses(rel, body) or outer.uses(rel, body)) if not h[3]]
                if hits:
                    hit(s, f"uses {hits[0][0]} ({hits[0][1]})", text_segment=sid)
            continue
        hits = reached.uses(rel, text) or outer.uses(rel, text)
        if hits:
            why[s] = f"uses {hits[0][0]} ({hits[0][1]})"

    items, item_why = [], {}
    for s in suites:
        if s in why:
            items.append(s)
            item_why[s] = why[s]
        elif s in section_why:
            ids = ordered_ids(segs[s], set(section_why[s]))
            item = s + ":" + ",".join(ids)
            items.append(item)
            item_why[item] = "; ".join(f"{i}: {section_why[s][i]}" for i in ids)
    if not items:
        return "none", {}, changed
    return items, item_why, changed


# --- expected times ----------------------------------------------------------------------------

def ledger(name):
    """The rows of tools\\Run-Tests.ps1's ledger NAME ([] when there is none)."""
    try:
        with open(os.path.join(LEDGER_DIR, name), encoding="utf-8-sig", newline="") as fh:
            return list(csv.DictReader(fh))
    except OSError:
        return []


def median(values):
    v = sorted(values)
    return v[(len(v) - 1) // 2] if v else None


def expected_seconds(item, runs, secs):
    """Seconds ITEM took at the median of its last runs; for sections never run on their own, the
    suite's setup (a full run less its sections) plus the sections' medians. None when unknown."""
    suite, _, ids = item.partition(":")
    same = [float(r["Seconds"]) for r in runs if r["Suite"] == suite and r["Sections"] == ids][-5:]
    if same:
        return median(same)
    if not ids:
        return None
    full = [r for r in runs if r["Suite"] == suite and r["Sections"] == ""][-5:]
    if not full:
        return None
    by_run = {}
    for r in secs:
        if r["Suite"] == suite:
            by_run.setdefault((r["Date"], r["Sha"]), {})[r["Section"]] = float(r["Seconds"])
    setups = []
    for r in full:
        parts = by_run.get((r["Date"], r["Sha"]))
        if parts:
            setups.append(max(0.0, float(r["Seconds"]) - sum(parts.values())))
    setup = median(setups)
    if setup is None:
        return None
    total = setup
    for wanted in ids.split(","):
        times = [t for parts in by_run.values() for sid, t in parts.items()
                 if sid == wanted or sid.startswith(wanted + ".")]
        if not times:
            return None
        per_id = {}
        for parts in by_run.values():
            for sid, t in parts.items():
                if sid == wanted or sid.startswith(wanted + "."):
                    per_id.setdefault(sid, []).append(t)
        total += sum(median(v) for v in per_id.values())
    return total


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("revs", nargs="*", help="BASE HEAD, or BASE with --worktree")
    ap.add_argument("--worktree", action="store_true")
    ap.add_argument("--sections", action="store_true")
    ap.add_argument("--why", action="store_true")
    ap.add_argument("--expect", action="store_true")
    a = ap.parse_args()
    if a.worktree:
        if len(a.revs) > 1:
            ap.error("--worktree takes one revision at most")
        base, head = (a.revs[0] if a.revs else "HEAD"), None
    else:
        if len(a.revs) != 2:
            ap.error("give BASE and HEAD, or --worktree [BASE]")
        base, head = a.revs
    sel, why, changed = select(base, head, sections=a.sections, untracked=a.worktree)
    print(sel if isinstance(sel, str) else " ".join(sel))
    if a.why and not isinstance(sel, str):
        runs, secs = (ledger("test_timings.csv"), ledger("section_timings.csv")) if a.expect else ([], [])
        for item in sel:
            line = f"  {item}  {why[item]}"
            if a.expect:
                e = expected_seconds(item, runs, secs)
                line += f"  ~{e:.0f} s" if e is not None else "  (no record yet)"
            print(line)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        total = len(suite_files())
        with open(summary, "a", encoding="utf-8") as fh:
            if sel == "all":
                fh.write(f"### Suites: all {total} (the test runner, the CI workflow or its scripts changed)\n")
            elif sel == "none":
                fh.write("### Suites: none (no change reaches a test suite)\n")
            else:
                fh.write(f"### Suites: {len(sel)} of {total}\n\n| Suite | Why |\n| --- | --- |\n")
                for s in sel:
                    fh.write(f"| `{s}` | {why[s]} |\n")
            fh.write("\n<details><summary>Changed files</summary>\n\n")
            fh.write("".join(f"- `{c}`\n" for c in changed))
            fh.write("\n</details>\n")


if __name__ == "__main__":
    main()
