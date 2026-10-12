"""Choose the MATLAB test suites a change can affect (CI on pull requests).

Usage: python select_suites.py BASE HEAD
    BASE, HEAD  git revisions; the change is `git diff BASE HEAD`, and the
                files are read as they are in the working tree (HEAD).

Prints one line: "all", "none", or the suite names separated by spaces. With
GITHUB_STEP_SUMMARY set, appends why each suite was chosen to the job summary.

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


def changed_lines(base, head):
    """({path: changed line numbers in HEAD}, deleted paths, paths whose change touches code).

    A .m file whose added and removed lines are all comments or blank does not touch code."""
    lines, deleted, code = {}, set(), set()
    cur = prev = None
    in_hunk = False
    for ln in git("diff", "--no-renames", "-U0", base, head).splitlines():
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
    for p in git("diff", "--no-renames", "--name-only", base, head).splitlines():
        lines.setdefault(p, set())
        if not p.endswith(".m"):
            code.add(p)                           # only MATLAB comments are told apart
    code |= deleted
    return lines, deleted, code


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
        self.words = {}       # name -> (why, home)
        self.methods = {}     # method -> (why, home)

    def add(self, kind, n, home, why):
        d = self.words if kind == "word" else self.methods
        if n in d:
            return False
        d[n] = (why, home)
        return True

    def uses(self, rel, text, local=True):
        """[(name as used, why, home)] of the names REL's text uses. LOCAL=False leaves out the
        bare names of methods (a classdef's declarations list them)."""
        out = []
        words = set(WORD.findall(text))
        for n in sorted(words & set(self.words)):
            why, home = self.words[n]
            if not home or inside(rel, home):
                out.append((n, why, home))
        for n in sorted(set(DOTTED.findall(text)) & set(self.methods)):
            why, home = self.methods[n]
            out.append(("." + n, why, home))
        if local:
            for n in sorted(words & set(self.methods)):
                why, home = self.methods[n]
                if inside(rel, home):
                    out.append((n, why, home))
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
    """[(kind, name, home, why, followed)]: what in REL uses a REACHED name. A classdef is split
    into its functions (what comes before them, the header and declarations, stands for the
    class); any other file is one name. FOLLOWED: REL is inside the home of a name it uses."""
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
            why = f"{hits[0][1]}, through {rel}" + (f" ({fname})" if fname else "")
            if not fname or fname == cls:
                out.append(("word", cls, "", why, followed))
            else:
                out.append(("method", fname, folder or rel, why, followed))
        return out
    hits = reached.uses(rel, text)
    if hits:
        followed = any(inside(rel, h[2]) for h in hits)
        why = f"{hits[0][1]}, through {rel}"
        if private_home(rel):
            out.append(("word", base, private_home(rel), why, followed))
        elif folder:
            out.append(("method", base, folder, why, followed))
        else:
            out.append(("word", base, "", why, followed))
    return out


def select(base, head):
    """("all" | "none" | [suites], {suite: why}, [changed paths])."""
    rows, deleted, touches_code = changed_lines(base, head)
    changed = sorted(rows)
    if any(c in RUN_ALL or c.startswith(RUN_ALL_PREFIXES) for c in changed):
        return "all", {}, changed
    suites = suite_files()
    suite_paths = set(suites.values())
    why = {}
    reached = Names()                             # the changed names, and their users inside their homes
    for c in changed:
        if c in suite_paths:
            why.setdefault(os.path.basename(c)[:-2], f"changed: {c}")
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
            for kind, n, home, src, followed in users(rel, text, reached):
                if followed:
                    grew = reached.add(kind, n, home, src) or grew
                else:
                    outer.add(kind, n, home, src)

    for s, rel in suites.items():
        if s in why:
            continue
        text = read(rel)
        hits = reached.uses(rel, text) or outer.uses(rel, text)
        if hits:
            why[s] = f"uses {hits[0][0]} ({hits[0][1]})"
    if not why:
        return "none", {}, changed
    return [s for s in suites if s in why], why, changed


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sel, why, changed = select(sys.argv[1], sys.argv[2])
    print(sel if isinstance(sel, str) else " ".join(sel))
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
