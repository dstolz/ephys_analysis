"""Table of contents for the wiki's pages.

A page with more than one section gets a "Contents" list of its sections
(and their subsections), right before its first section. The list sits
between "<!-- toc -->" and "<!-- /toc -->" lines, which GitHub hides, so
running this again replaces the list instead of adding a second one.

gen_pages.py and gen_api.py call add_toc() on every page they write. The
hand-written pages (Home, Quick-Start, the scripting pages, ...) get theirs
from the command line, which rewrites only the pages whose list changes
(the sidebar and footer, whose names start with "_", are left alone):

    python wiki_toc.py <wiki clone>
"""
import glob, os, re, sys

START, END = "<!-- toc -->", "<!-- /toc -->"


def anchor_of(heading, seen):
    """GitHub's anchor for HEADING (lowercase, punctuation but - and _ removed, spaces as hyphens, -1 ... for repeats)."""
    h = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', heading.strip())
    s = re.sub(r'[^\w\- ]', '', h.lower()).replace(' ', '-')
    base, n = s, 1
    while s in seen:
        s = f"{base}-{n}"
        n += 1
    seen.add(s)
    return s


def strip_toc(text):
    """TEXT without its table of contents block (and the blank line after it)."""
    return re.sub(re.escape(START) + r'.*?' + re.escape(END) + r'\n*', '', text, flags=re.S)


def headings(lines):
    """[(line index, level, text, anchor)] for the headings of LINES outside code blocks."""
    out, seen, fence = [], set(), False
    for i, line in enumerate(lines):
        if line.startswith("```"):
            fence = not fence
            continue
        m = None if fence else re.match(r'^(#{1,6})\s+(.*?)\s*$', line)
        if m:
            out.append((i, len(m.group(1)), m.group(2), anchor_of(m.group(2), seen)))
    return out


def add_toc(text):
    """TEXT with a table of contents before its first section, when it has more than one section;
    else TEXT without one. A lone "# " title at the top is the page's name, not a section."""
    lines = strip_toc(text).split("\n")
    hs = headings(lines)
    if len(hs) > 1 and sum(1 for h in hs if h[1] == hs[0][1]) == 1 and hs[0][1] < min(h[1] for h in hs[1:]):
        hs = hs[1:]
    if not hs:
        return "\n".join(lines)
    top = min(h[1] for h in hs)
    sections = [h for h in hs if h[1] == top]
    if len(sections) < 2:
        return "\n".join(lines)
    items = []
    for i, level, title, anchor in hs:
        if level == top:
            indent = ""
        elif level == top + 1:
            indent = "  "
        else:
            continue
        label = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', title)
        items.append(f"{indent}- [{label}](#{anchor})")
    block = [START, "**Contents**", ""] + items + ["", END, ""]
    at = sections[0][0]
    if at and lines[at - 1].strip():
        block = [""] + block
    return "\n".join(lines[:at] + block + lines[at:])


def main(wiki):
    changed = 0
    for f in sorted(glob.glob(os.path.join(wiki, "*.md"))):
        if os.path.basename(f).startswith("_"):
            continue
        old = open(f, encoding="utf-8", newline="").read()
        new = add_toc(old.replace("\r\n", "\n"))
        if new != old.replace("\r\n", "\n"):
            open(f, "w", encoding="utf-8", newline="\n").write(new)
            changed += 1
            print("updated", os.path.basename(f))
    print(f"{changed} page(s) changed")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
