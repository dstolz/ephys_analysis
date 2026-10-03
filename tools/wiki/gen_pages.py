"""Generate the wiki's prose pages from documentation/, the one source.

pages.json (next to this file) maps each generated wiki page to what it is
made of: a markdown file of this repository, whole or some of its "## "
sections. A page is written whole. It starts with a comment naming its source
(edit that file, not the page); the file's "# " title is dropped, since the
wiki shows the page name. When only some sections are taken, their headings
go up one level. Links are rewritten for the wiki:
  a markdown file of the repo (+ #anchor)
        the wiki page made from it, or from the section holding the anchor;
        otherwise the file on GitHub
  any other file of the repo (../pipeline/x.m, ...)
        the file on GitHub (main)
  #anchor on the same file
        kept when the page holds that heading, else as above

Pages whose status is "candidate" still hold content in the wiki that
documentation/ lacks. They are generated for comparison (--out, --report)
and are written into a wiki clone only with --include-candidates, once that
content has been merged into documentation/. This script never runs git.

Usage (see README.md next to this file):
    python gen_pages.py --out <folder>                       generate every page into a folder
    python gen_pages.py --wiki <clone>                       write the "generated" pages into a wiki clone
    python gen_pages.py --wiki <clone> --include-candidates  ... and the candidates
    python gen_pages.py --wiki <clone> --report              how each page differs from the clone's
"""
import argparse, difflib, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
BLOB = "https://github.com/dstolz/ephys_analysis/blob/main/"


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


def split_sections(text):
    """[(title or None, lines)] split at "## " headings outside code blocks; the part before the first is None."""
    parts, title, cur, fence = [], None, [], False
    for line in text.split("\n"):
        if line.startswith("```"):
            fence = not fence
        if not fence and line.startswith("## "):
            parts.append((title, cur))
            title, cur = line[3:].strip(), [line]
            continue
        cur.append(line)
    parts.append((title, cur))
    return parts


def anchors_by_section(text):
    """{anchor: section title (None before the first "## ")} for every heading of TEXT."""
    seen, out, fence, section = set(), {}, False, None
    for line in text.split("\n"):
        if line.startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        m = re.match(r'^(#{1,6})\s+(.*?)\s*$', line)
        if m:
            if len(m.group(1)) == 2:
                section = m.group(2)
            out[anchor_of(m.group(2), seen)] = section
    for a in re.findall(r'<a (?:name|id)="([^"]+)"', text):
        out.setdefault(a, section)
    return out


def load_pages(repo):
    spec = json.load(open(os.path.join(HERE, "pages.json"), encoding="utf-8"))
    pages = spec["pages"]
    texts = {}
    for p in pages:
        src = p["source"]
        if src not in texts:
            texts[src] = open(os.path.join(repo, src), encoding="utf-8").read()
    return pages, texts


def page_index(pages, texts):
    """{(source, section title or None): page} for every source part a page takes ((src, None) for a whole file)."""
    idx = {}
    for p in pages:
        if p.get("sections"):
            for s in p["sections"]:
                idx[(p["source"], s)] = p["page"]
        else:
            idx[(p["source"], None)] = p["page"]
    return idx


def target_page(src, anchor, idx, texts):
    """The wiki page holding SRC (and ANCHOR in it), or None."""
    if (src, None) in idx:
        return idx[(src, None)]
    if src in texts and anchor:
        sec = anchors_by_section(texts[src]).get(anchor)
        if sec is not None and (src, sec) in idx:
            return idx[(src, sec)]
    return None


def rewrite_links(body, src, idx, texts, own):
    """Rewrite the relative links of BODY (from repo file SRC) for the wiki page OWN."""
    src_dir = os.path.dirname(src)

    def fix(m):
        label, url = m.group(1), m.group(2)
        if re.match(r'^[a-z]+:', url) or url.startswith("mailto:"):
            return m.group(0)
        path, _, anchor = url.partition("#")
        if path == "":
            rel = src                                   # same file
        else:
            rel = os.path.normpath(os.path.join(src_dir, path)).replace("\\", "/")
        if rel.endswith(".md"):
            page = target_page(rel, anchor, idx, texts)
            if page == own and path == "":
                return m.group(0)                        # an anchor on this very page
            if page:
                return f"[{label}]({page}" + (f"#{anchor}" if anchor else "") + ")"
        return f"[{label}]({BLOB}{rel}" + (f"#{anchor}" if anchor else "") + ")"

    out, fence = [], False
    for line in body.split("\n"):
        if line.startswith("```"):
            fence = not fence
        if not fence:
            line = re.sub(r'(?<!!)\[([^\]]*)\]\(([^)\s]+)\)', fix, line)
        out.append(line)
    return "\n".join(out)


def build(p, texts, idx):
    src = p["source"]
    text = texts[src]
    lines = text.split("\n")
    if lines and lines[0].startswith("# "):
        lines = lines[1:]
        while lines and lines[0].strip() == "":
            lines = lines[1:]
    if p.get("sections"):
        want = p["sections"]
        parts = dict((t, ls) for t, ls in split_sections("\n".join(lines)) if t is not None)
        missing = [s for s in want if s not in parts]
        if missing:
            raise SystemExit(f"{p['page']}: {src} has no section(s) {missing}")
        body_lines = []
        for s in want:
            fence = False
            for line in parts[s]:
                if line.startswith("```"):
                    fence = not fence
                if not fence and re.match(r'^#{2,5}\s', line):
                    line = line[1:]                        # ## -> #, ### -> ##, ...
                body_lines.append(line)
            while body_lines and body_lines[-1].strip() == "":
                body_lines.pop()
            body_lines.append("")
        body = "\n".join(body_lines)
    else:
        body = "\n".join(lines)
    body = rewrite_links(body, src, idx, texts, p["page"])
    what = src + (" (" + ", ".join(f'"## {s}"' for s in p["sections"]) + ")" if p.get("sections") else "")
    banner = (f"<!-- Generated from {what} by tools/wiki/gen_pages.py. "
              f"Edit that file, not this page: the next update replaces it. -->\n\n")
    return banner + body.rstrip() + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", help="write every page here")
    ap.add_argument("--wiki", help="a wiki clone: write the generated pages into it (no git)")
    ap.add_argument("--include-candidates", action="store_true", help="also write the candidate pages into the clone")
    ap.add_argument("--report", action="store_true", help="with --wiki: compare each page with the clone's, write nothing")
    ap.add_argument("--src", default=REPO, help="the repository to read (default: this one)")
    a = ap.parse_args()
    if not (a.out or a.wiki):
        ap.error("give --out and/or --wiki")
    pages, texts = load_pages(a.src)
    idx = page_index(pages, texts)
    built = {p["page"]: build(p, texts, idx) for p in pages}
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        for name, txt in built.items():
            open(os.path.join(a.out, name + ".md"), "w", encoding="utf-8", newline="\n").write(txt)
        print(f"wrote {len(built)} page(s) to {a.out}")
    if a.wiki:
        for p in pages:
            name = p["page"]
            f = os.path.join(a.wiki, name + ".md")
            old = open(f, encoding="utf-8").read() if os.path.isfile(f) else None
            new = built[name]
            if a.report:
                if old is None:
                    print(f"{name:24s} {p['status']:10s} new page")
                else:
                    d = [l for l in difflib.unified_diff(old.split("\n"), new.split("\n"), lineterm="", n=0)
                         if l[:1] in "+-" and not l.startswith(("+++", "---"))]
                    print(f"{name:24s} {p['status']:10s} {len(d):5d} line(s) differ")
                continue
            if p["status"] != "generated" and not a.include_candidates:
                continue
            open(f, "w", encoding="utf-8", newline="\n").write(new)
            print(f"wrote {name}" + ("" if old is not None else " (new: add it to _Sidebar.md)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
