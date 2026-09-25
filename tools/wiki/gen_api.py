"""Generate the API reference sections of the ephys_analysis wiki from the .m sources.

Parses MATLAB source text (no MATLAB needed): classdef blocks, property
declarations, method signatures (inline, declared, or in @Class/*.m files),
function signatures, `arguments` blocks and help comments ("%" plus one
space stripped). Each API page of the wiki keeps its hand-written lead; the
generated reference replaces everything from its "## Reference" heading on.

Usage (see README.md next to this file):
    python gen_api.py --wiki <wiki clone> [--src <source tree>] [--gen <folder>]
    python gen_api.py --src <source tree> --gen <folder> --no-splice

  --wiki       the wiki's git clone, whose API-*.md pages are spliced
  --src        the source tree to document (default: this repository). For a
               published update, use a snapshot of the commit the footer
               names (git archive), not the working tree
  --gen        also write each generated section to <folder>/api-<Name>.md
  --no-splice  generate only (needs --gen to be useful)
"""
import argparse, os, re, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", ".."))   # set by main()
WIKI = ""                                                 # set by main()
GEN = ""                                                  # set by main(); "" = don't write copies
REPO_URL = "https://github.com/dstolz/ephys_analysis/blob/main/"

# ---------------------------------------------------------------- lexing

def split_code_comment(line):
    """Return (code, comment) for one physical line; strings kept in code."""
    code = []
    i, n = 0, len(line)
    prev = ""  # last non-space significant char in code
    while i < n:
        c = line[i]
        if c == "%":
            return "".join(code), line[i + 1:]
        if c == '"':
            j = i + 1
            while j < n:
                if line[j] == '"':
                    if j + 1 < n and line[j + 1] == '"':
                        j += 2
                        continue
                    break
                j += 1
            code.append(line[i:j + 1]); i = j + 1; prev = '"'; continue
        if c == "'":
            if prev and (prev.isalnum() or prev in "_)]}.'\""):
                code.append(c); i += 1; prev = c; continue  # transpose
            j = i + 1
            while j < n:
                if line[j] == "'":
                    if j + 1 < n and line[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            code.append(line[i:j + 1]); i = j + 1; prev = "'"; continue
        if line.startswith("...", i):
            return "".join(code) + " ...", line[i + 3:]
        code.append(c)
        if not c.isspace():
            prev = c
        elif prev and prev.isalnum():
            prev = " "
        i += 1
    return "".join(code), None


def strip_strings(code):
    """Replace string literal contents with blanks (keeps positions roughly)."""
    out = []
    i, n = 0, len(code)
    prev = ""
    while i < n:
        c = code[i]
        if c in "\"'":
            if c == "'" and prev and (prev.isalnum() or prev in "_)]}.'\""):
                out.append(c); i += 1; prev = c; continue
            j = i + 1
            while j < n:
                if code[j] == c:
                    if j + 1 < n and code[j + 1] == c:
                        j += 2; continue
                    break
                j += 1
            out.append('""'); i = j + 1; prev = '"'; continue
        out.append(c)
        if not c.isspace():
            prev = c
        elif prev and prev.isalnum():
            prev = " "
        i += 1
    return "".join(out)


class Line:
    def __init__(self, no, raw):
        self.no = no
        self.raw = raw.rstrip("\r\n")
        code, com = split_code_comment(self.raw)
        self.code = code
        self.comment = com
        self.cont = code.rstrip().endswith("...")
        if self.cont:
            self.code = code.rstrip()[:-3]
        self.stripped = self.raw.strip()

    @property
    def is_comment(self):
        return self.stripped.startswith("%")

    @property
    def is_blank(self):
        return self.stripped == ""


def read_lines(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        raw = f.read().split("\n")
    lines = []
    in_block = False
    for k, r in enumerate(raw):
        s = r.strip()
        if s == "%{":
            in_block = True
            lines.append(Line(k, "")); continue
        if in_block:
            if s == "%}":
                in_block = False
            lines.append(Line(k, "")); continue
        lines.append(Line(k, r))
    return lines


BLOCK_KW = {"if", "for", "parfor", "while", "switch", "try", "function", "spmd"}
WORD = re.compile(r"[A-Za-z_]\w*|[()\[\]{}]|\.|;|,|@")


def logical(lines, i):
    """Join continuation lines from index i. Returns (code, comments, next_i)."""
    code = lines[i].code
    comments = [lines[i].comment] if lines[i].comment is not None else []
    j = i
    while lines[j].cont and j + 1 < len(lines):
        j += 1
        code += " " + lines[j].code
        if lines[j].comment is not None:
            comments.append(lines[j].comment)
    return code, comments, j + 1


def find_end(lines, i):
    """Given lines[i] opening a block (classdef/properties/methods/function...),
    return the index of the line holding its matching `end`."""
    depth = 0
    bdepth = 0
    seen = {}          # function depth -> an ordinary statement has occurred
    is_class = lines[i].code.strip().startswith("classdef")
    j = i
    while j < len(lines):
        toks = WORD.findall(strip_strings(lines[j].code))
        prev = None
        first = True
        for t in toks:
            if t in ("(", "[", "{"):
                bdepth += 1; first = False; prev = t; continue
            if t in (")", "]", "}"):
                bdepth = max(0, bdepth - 1); prev = t; continue
            if t in (";", ","):
                if bdepth == 0:
                    first = True
                prev = t; continue
            if bdepth == 0 and prev not in (".", "@"):
                if first and depth in seen and t != "arguments":
                    seen[depth] = True
                if t in BLOCK_KW:
                    depth += 1
                    if t == "function":
                        seen[depth] = False
                elif t == "arguments" and first and depth in seen and not seen[depth]:
                    depth += 1
                elif t in ("properties", "methods", "events", "enumeration") and first and                         ((j == i and depth == 0) or (is_class and depth == 1)):
                    depth += 1
                elif t == "classdef" and j == i and depth == 0:
                    depth += 1
                elif t == "end":
                    depth -= 1
                    if depth == 0:
                        return j
            first = False
            prev = t
        j += 1
    return len(lines) - 1


# ---------------------------------------------------------------- pieces

def help_block(lines, i):
    """Comment lines directly after index i (the function/classdef line).
    Returns (list of raw comment texts, next index)."""
    out = []
    j = i + 1
    while j < len(lines) and lines[j].is_comment:
        out.append(lines[j].stripped[1:])
        j += 1
    # a trailing comment on the declaration line itself is not help
    return out, j


def strip_help(texts):
    res = []
    for t in texts:
        if t.startswith(" "):
            t = t[1:]
        res.append(t.rstrip())
    return res


def split_h1(texts, name):
    """First help line -> H1 (name token removed); rest -> help body lines."""
    if not texts:
        return "", []
    first = texts[0].strip()
    m = re.match(r"^([A-Za-z_][\w.]*)\s*(.*)$", first)
    if m and m.group(1).split(".")[-1].lower() == name.lower():
        first = m.group(2).strip()
    body = strip_help(texts[1:])
    while body and body[-1].strip() == "":
        body.pop()
    while body and body[0].strip() == "":
        body.pop(0)
    return first, body


def scan_balanced(s, i, open_c, close_c):
    depth = 0
    j = i
    q = None
    while j < len(s):
        c = s[j]
        if q:
            if c == q:
                q = None
        elif c in "\"":
            q = c
        elif c == "'" and (j == 0 or not (s[j - 1].isalnum() or s[j - 1] in "_)]}.'")):
            q = c
        elif c == open_c:
            depth += 1
        elif c == close_c:
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    return len(s)


def parse_decl(code):
    """Parse `name (size) class {validators} = default` (property or argument)."""
    s = code.strip().rstrip(";").strip()
    m = re.match(r"^([A-Za-z_][\w]*(?:\.[A-Za-z_?][\w.]*)?)", s)
    if not m:
        return None
    name = m.group(1)
    i = m.end()
    size = cls = val = default = ""
    rest = s[i:]
    k = len(rest) - len(rest.lstrip())
    i += k
    if i < len(s) and s[i] == "(":
        e = scan_balanced(s, i, "(", ")")
        size = re.sub(r"\s+", "", s[i:e]); i = e
        i += len(s[i:]) - len(s[i:].lstrip())
    mm = re.match(r"^([A-Za-z_][\w.]*)", s[i:])
    if mm:
        cls = mm.group(1); i += mm.end()
        i += len(s[i:]) - len(s[i:].lstrip())
    if i < len(s) and s[i] == "{":
        e = scan_balanced(s, i, "{", "}")
        val = s[i + 1:e - 1].strip(); i = e
        i += len(s[i:]) - len(s[i:].lstrip())
    if i < len(s) and s[i] == "=":
        default = re.sub(r"\s+", " ", s[i + 1:].strip())
    elif i < len(s):
        return None
    return dict(name=name, size=size, cls=cls, val=val, default=default)


def parse_attrs(code):
    """'(Access = private, Static)' -> dict"""
    m = re.search(r"\((.*)\)", code)
    d = {}
    if not m:
        return d
    for part in re.split(r",(?![^{]*\})", m.group(1)):
        part = part.strip()
        if not part:
            continue
        if "=" in part:
            k, v = part.split("=", 1)
            v = v.strip()
            if v.lower() == "true":
                v = True
            elif v.lower() == "false":
                v = False
            d[k.strip()] = v
        elif part.startswith("~"):
            d[part[1:].strip()] = False
        else:
            d[part] = True
    return d


SIG = re.compile(r"^\s*function\s+(?:(\[[^\]]*\]|[A-Za-z_]\w*)\s*=\s*)?([A-Za-z_][\w.]*)\s*(\([^)]*\))?")


def norm_sig(outs, name, args):
    outs = (outs or "").strip()
    if outs.startswith("["):
        outs = "[" + ", ".join(x for x in re.split(r"[\s,]+", outs[1:-1].strip()) if x) + "]"
    a = ""
    if args is not None:
        a = "(" + ", ".join(x.strip() for x in args.strip()[1:-1].split(",") if x.strip()) + ")"
    else:
        a = "()"
    return (outs + " = " if outs else "") + name + a


def parse_function_at(lines, i, end_known=None):
    """Parse the function whose `function` line is lines[i]."""
    code, comments, nxt = logical(lines, i)
    m = SIG.match(code)
    if not m:
        return None
    outs, name, args = m.group(1), m.group(2), m.group(3)
    if "." in name:  # set.Prop / get.Prop
        pass
    f = dict(name=name, sig=norm_sig(outs, name.split(".")[-1] if False else name, args),
             argnames=[a.strip() for a in (args or "()")[1:-1].split(",") if a.strip()],
             line=i)
    htexts, j = help_block(lines, nxt - 1)
    f["h1"], f["help"] = split_h1(htexts, name)
    # arguments blocks
    f["args"] = []
    f["nv"] = []
    f["repeating"] = []
    while j < len(lines):
        L = lines[j]
        if L.is_blank or L.is_comment:
            j += 1; continue
        c = strip_strings(L.code).strip()
        if re.match(r"^arguments\b", c) and not re.match(r"^arguments\s*=", c):
            attrs = parse_attrs(c)
            kind = "out" if attrs.get("Output") else ("rep" if attrs.get("Repeating") else "in")
            j += 1
            pending_comment = []
            while j < len(lines):
                L = lines[j]
                if L.is_blank:
                    pending_comment = []; j += 1; continue
                if L.is_comment:
                    pending_comment.append(L.stripped[1:].strip()); j += 1; continue
                cc = strip_strings(L.code).strip()
                if re.match(r"^end\b", cc):
                    j += 1; break
                dcode, dcom, j2 = logical(lines, j)
                d = parse_decl(dcode)
                if d:
                    com = " ".join(x.strip() for x in dcom if x.strip())
                    d["comment"] = com
                    if kind == "in":
                        if "." in d["name"]:
                            d["name"] = d["name"].split(".", 1)[1]
                            f["nv"].append(d)
                        else:
                            f["args"].append(d)
                    elif kind == "rep":
                        f["repeating"].append(d)
                pending_comment = []
                j = j2
            continue
        break
    return f


def parse_function_file(path):
    lines = read_lines(path)
    for i, L in enumerate(lines):
        if re.match(r"^\s*function\b", L.code):
            f = parse_function_at(lines, i)
            if f:
                f["path"] = path
                return f
    return None


# ---------------------------------------------------------------- classes

def parse_class(path):
    lines = read_lines(path)
    cls = dict(path=path, props=[], methods=[], declared=[], events=[], groups_order=[])
    i = 0
    while i < len(lines) and not re.match(r"^\s*classdef\b", lines[i].code):
        i += 1
    code, _, nxt = logical(lines, i)
    m = re.match(r"^\s*classdef\s*(\([^)]*\))?\s*([A-Za-z_]\w*)\s*(?:<\s*(.*))?$", code.strip())
    cls["attrs"] = parse_attrs(m.group(1) or "")
    cls["name"] = m.group(2)
    cls["supers"] = [s.strip() for s in (m.group(3) or "").split("&") if s.strip()]
    htexts, j = help_block(lines, nxt - 1)
    cls["h1"], cls["help"] = split_h1(htexts, cls["name"])
    end_i = find_end(lines, i)
    j = nxt
    while j < end_i:
        L = lines[j]
        c = strip_strings(L.code).strip()
        mm = re.match(r"^(properties|methods|events|enumeration)\b", c)
        if not mm:
            j += 1; continue
        kind = mm.group(1)
        attrs = parse_attrs(c)
        bend = find_end(lines, j)
        if kind == "properties":
            parse_props(lines, j + 1, bend, attrs, cls)
        elif kind == "methods":
            parse_methods(lines, j + 1, bend, attrs, cls)
        elif kind == "events":
            for k in range(j + 1, bend):
                w = strip_strings(lines[k].code).strip()
                if w:
                    cls["events"].append((w, (lines[k].comment or "").strip()))
        j = bend + 1
    return cls


GROUP = re.compile(r"^%+\s*-{2,}\s*(.*?)\s*-{2,}\s*$")


def parse_props(lines, a, b, attrs, cls):
    group = None
    pending = []
    cls.setdefault("prop_blocks", []).append(dict(attrs=attrs, start=len(cls["props"])))
    j = a
    while j < b:
        L = lines[j]
        if L.is_blank:
            pending = []; j += 1; continue
        if L.is_comment:
            g = GROUP.match(L.stripped)
            if g:
                group = g.group(1); pending = []
            else:
                pending.append(L.stripped[1:].strip())
            j += 1; continue
        code, coms, j2 = logical(lines, j)
        # bracket continuation (multi-line struct(...) defaults without ...)
        while code.count("(") + code.count("[") + code.count("{") > \
                code.count(")") + code.count("]") + code.count("}") and j2 < b:
            code += " " + lines[j2].code
            if lines[j2].comment is not None:
                coms.append(lines[j2].comment)
            j2 += 1
        d = parse_decl(code)
        if d:
            trailing = " ".join(x.strip() for x in coms[:1] if x and x.strip())
            d["desc"] = trailing if trailing else first_sentence(" ".join(pending))
            d["attrs"] = attrs
            d["group"] = group
            d["block"] = len(cls["prop_blocks"]) - 1
            cls["props"].append(d)
        pending = []
        j = j2


def first_sentence(t, limit=260):
    t = t.strip()
    if not t:
        return ""
    m = re.search(r"(?<=[.;:])\s+(?=[A-Z(\"'])", t)
    s = t[:m.start()] if m else t
    if len(s) > limit:
        s = s[:limit].rsplit(" ", 1)[0] + " …"
    return s


def parse_methods(lines, a, b, attrs, cls):
    group = None
    j = a
    while j < b:
        L = lines[j]
        if L.is_blank:
            j += 1; continue
        if L.is_comment:
            g = GROUP.match(L.stripped)
            if g:
                group = g.group(1)
            j += 1; continue
        c = strip_strings(L.code).strip()
        if re.match(r"^function\b", c):
            e = find_end(lines, j)
            f = parse_function_at(lines, j)
            if f:
                f["attrs"] = attrs; f["group"] = group; f["inline"] = True
                f["path"] = cls["path"]
                cls["methods"].append(f)
            j = e + 1
            continue
        code, coms, j2 = logical(lines, j)
        mm = re.match(r"^\s*(?:(\[[^\]]*\]|[A-Za-z_]\w*)\s*=\s*)?([A-Za-z_][\w.]*)\s*(\([^)]*\))?\s*;?\s*$", code)
        if mm:
            outs, name, args = mm.group(1), mm.group(2), mm.group(3)
            cls["declared"].append(dict(name=name, sig=norm_sig(outs, name, args), attrs=attrs, group=group,
                                        comment=" ".join(x.strip() for x in coms if x and x.strip())))
        j = j2


def rel(path):
    return os.path.relpath(path, SRC).replace("\\", "/")


def src_link(path):
    r = rel(path)
    return f"[{r}]({REPO_URL}{r})"


def load_class(clsdir_or_file):
    if os.path.isdir(clsdir_or_file):
        name = os.path.basename(clsdir_or_file).lstrip("@")
        main = os.path.join(clsdir_or_file, name + ".m")
    else:
        main = clsdir_or_file
        clsdir_or_file = None
    cls = parse_class(main)
    inline = {m["name"] for m in cls["methods"]}
    decl = {d["name"]: d for d in cls["declared"]}
    files = {}
    if clsdir_or_file:
        for p in sorted(glob.glob(os.path.join(clsdir_or_file, "*.m"))):
            n = os.path.splitext(os.path.basename(p))[0]
            if n == cls["name"]:
                continue
            files[n] = p
    # methods from separate files
    for n, p in files.items():
        f = parse_function_file(p)
        if not f:
            continue
        d = decl.get(n)
        f["attrs"] = d["attrs"] if d else {}
        f["group"] = d["group"] if d else None
        f["declared"] = d is not None
        f["inline"] = False
        if not f["h1"] and d and d["comment"]:
            f["h1"] = d["comment"]
        cls["methods"].append(f)
    have = {m["name"] for m in cls["methods"]}
    # declared but not defined -> abstract (or missing)
    for d in cls["declared"]:
        if d["name"] not in have:
            cls["methods"].append(dict(name=d["name"], sig=d["sig"], attrs=d["attrs"], group=d["group"],
                                       h1=d["comment"], help=[], args=[], nv=[], repeating=[],
                                       inline=True, abstract=True, path=main, argnames=[]))
    # private folder functions
    cls["private"] = []
    if clsdir_or_file:
        for p in sorted(glob.glob(os.path.join(clsdir_or_file, "private", "*.m"))):
            f = parse_function_file(p)
            if f:
                cls["private"].append(f)
    # order methods: keep declaration order for grouping
    order = {}
    for k, d in enumerate(cls["declared"]):
        order.setdefault(d["name"], k)
    return cls


HANDLE_CLASSES = {"handle", "EphysReader", "matlab.apps.AppBase"}


def kind_line(cls):
    supers = cls["supers"]
    is_handle = any(s in HANDLE_CLASSES or s.startswith("matlab.mixin") and "handle" in supers for s in supers) \
        or any(s in HANDLE_CLASSES for s in supers)
    k = "handle class" if is_handle else "value class"
    if cls["attrs"].get("Abstract"):
        k = "abstract " + k
    if supers:
        k += " (inherits " + ", ".join(f"`{s}`" for s in supers) + ")"
    return f"**Kind:** {k} &nbsp;·&nbsp; **Source:** {src_link(cls['path'])}"


# ---------------------------------------------------------------- markdown helpers

def esc(t):
    t = (t or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    t = t.replace("|", "\\|")
    t = re.sub(r"(?<![\\\w])\*(?=\S)", r"\\*", t)
    return t


def code(t):
    t = (t or "").replace("|", "\\|")
    if "`" in t:
        return f"`` {t} ``"
    return f"`{t}`"


def anchor(heading):
    h = heading.strip().lower()
    h = re.sub(r"[^\w\- ]", "", h)
    return h.replace(" ", "-")


def trunc(t, n=160):
    t = t or ""
    return t if len(t) <= n else t[:n].rstrip() + " …"


def prop_type(p):
    parts = [x for x in (p["size"], p["cls"]) if x]
    if p["val"]:
        parts.append("{" + p["val"] + "}")
    return " ".join(parts)


def attr_text(attrs, extra=()):
    out = []
    for k, v in attrs.items():
        if v is True:
            out.append(k)
        elif v is False:
            continue
        else:
            out.append(f"{k}={v}")
    out.extend(extra)
    return ", ".join(out)


def arg_tables(f):
    out = []
    args = [a for a in f["args"] if a["name"] not in ("obj", "app", "self", "~")]
    if args:
        out.append("| Argument | Type | Default | Notes |")
        out.append("| --- | --- | --- | --- |")
        for a in args:
            out.append(arg_row(a))
        out.append("")
    if f.get("repeating"):
        out.append("| Repeating argument | Type | Default | Notes |")
        out.append("| --- | --- | --- | --- |")
        for a in f["repeating"]:
            out.append(arg_row(a))
        out.append("")
    if f["nv"]:
        out.append("| Name-value option | Type | Default | Notes |")
        out.append("| --- | --- | --- | --- |")
        for a in f["nv"]:
            out.append(arg_row(a, nv=True))
        out.append("")
    return out


def arg_row(a, nv=False):
    typ = " ".join(x for x in (a["size"], a["cls"]) if x)
    dflt = code(trunc(a["default"], 120)) if a["default"] else ("*(none: absent unless given)*" if nv else "*(required)*")
    notes = []
    if a["val"]:
        notes.append(code(a["val"]))
    if a.get("comment"):
        notes.append(esc(a["comment"]))
    return f"| {code(a['name'])} | {code(typ) if typ else ''} | {dflt} | {' '.join(notes)} |"


def help_details(lines):
    if not lines:
        return []
    body = "\n".join(lines).replace("```", "'''")
    return ["<details><summary>Help text</summary>", "", "```text", body, "```", "", "</details>", ""]


def method_access(m):
    a = m["attrs"]
    acc = a.get("Access")
    if acc and acc not in ("public",):
        return str(acc)
    return None


# ---------------------------------------------------------------- class section

def class_section(cls, h="####", hide_props=False):
    name = cls["name"]
    h5 = h + "#"
    out = [kind_line(cls), ""]
    # properties
    if cls["props"] and not hide_props:
        out += [f"{h} Properties", "", "| Property | Type / default | Attributes | Description |",
                "| --- | --- | --- | --- |"]
        for p in cls["props"]:
            t = prop_type(p)
            td = code(trunc(t, 120)) if t else ""
            if p["default"]:
                td += (" = " if td else "= ") + code(trunc(p["default"], 120))
            out.append(f"| {code(p['name'])} | {td} | {attr_text(p['attrs'])} | {esc(p['desc'])} |")
        out.append("")
    if cls["events"]:
        out += [f"{h} Events", "", "| Event | Description |", "| --- | --- |"]
        for e, c in cls["events"]:
            out.append(f"| {code(e)} | {esc(c)} |")
        out.append("")
    ctor = [m for m in cls["methods"] if m["name"] == name]
    pub, stat, nonpub = [], [], []
    for m in cls["methods"]:
        if m["name"] == name or m["name"].startswith(("set.", "get.")):
            continue
        a = m["attrs"]
        if method_access(m) or a.get("Hidden"):
            nonpub.append(m)
        elif a.get("Static"):
            stat.append(m)
        else:
            pub.append(m)
    key = lambda m: m["name"].lower()
    pub.sort(key=key); stat.sort(key=key); nonpub.sort(key=key)

    def link(m):
        return f"[{code(m['sig'])}](#{anchor(name + '.' + m['name'])})"

    def desc(m):
        d = esc(m.get("h1", ""))
        if m.get("abstract"):
            d = ("*(abstract)* " + d).strip()
        return d

    out += [f"{h} Constructor", "", "| Method | Description |", "| --- | --- |"]
    if ctor:
        c = ctor[0]
        out.append(f"| {link(c)} | {esc(cls['h1'])} |")
    else:
        out.append(f"| [`obj = {name}()`](#{anchor(name + '.' + name)}) | {esc(cls['h1'])} *(no explicit constructor)* |")
    out.append("")
    if pub:
        out += [f"{h} Public methods", "", "| Method | Description |", "| --- | --- |"]
        out += [f"| {link(m)} | {desc(m)} |" for m in pub]
        out.append("")
    if stat:
        out += [f"{h} Static methods", "", "| Method | Description |", "| --- | --- |"]
        out += [f"| {link(m)} | {desc(m)} |" for m in stat]
        out.append("")
    priv = cls.get("private", [])
    if nonpub or priv:
        out += [f"{h} Non-public methods", "", "| Method | Access | Description |", "| --- | --- | --- |"]
        rows = []
        for m in nonpub:
            acc = []
            a = m["attrs"]
            if method_access(m):
                acc.append(method_access(m))
            if a.get("Hidden"):
                acc.append("Hidden")
            if a.get("Static"):
                acc.append("Static")
            rows.append((m["name"].lower(), f"| {code(m['sig'])} | {', '.join(acc)} | {esc(m.get('h1', ''))} |"))
        for f in priv:
            rows.append((f["name"].lower(), f"| {code(f['sig'])} | private folder | {esc(f['h1'])} |"))
        out += [r for _, r in sorted(rows)]
        out.append("")
    out += [f"{h} Method details", ""]
    # constructor details
    out += [f"{h5} {name}.{name}", ""]
    if ctor:
        c = ctor[0]
        out += ["```matlab", c["sig"], "```", ""]
    else:
        out += ["```matlab", f"obj = {name}()", "```", ""]
    if cls["h1"]:
        out += [esc(cls["h1"]), ""]
    out += ["Source: " + src_link(cls["path"]), ""]
    if ctor:
        out += arg_tables(ctor[0])
    hl = list(cls["help"])
    if ctor and (ctor[0]["h1"] or ctor[0]["help"]):
        extra = ([esc(ctor[0]["h1"])] if ctor[0]["h1"] else []) + ctor[0]["help"]
        if hl:
            hl += ["", "Constructor:"] + ["  " + x if x else x for x in extra]
        else:
            hl = extra
    out += help_details(hl)
    for m in sorted(pub + stat, key=key):
        out += [f"{h5} {name}.{m['name']}", "", "```matlab", m["sig"], "```", ""]
        if m.get("abstract"):
            out += ["*Abstract:* declared here; every subclass implements it.", ""]
        if m.get("h1"):
            out += [esc(m["h1"]), ""]
        if not m.get("inline"):
            out += ["Source: " + src_link(m["path"]), ""]
        out += arg_tables(m)
        out += help_details(m["help"])
    return out


# ---------------------------------------------------------------- app (by group) section

def app_section(cls, first_group_names):
    name = cls["name"]
    out = ["Properties and methods grouped as they are declared in the class file.", "",
           kind_line(cls), "", "#### Properties, by group", "",
           "UI handles are listed by name; their types are `matlab.ui.*` components. State properties carry a description.", ""]
    groups = []  # (title, [props])
    for p in cls["props"]:
        if p["attrs"].get("Constant"):
            title = "Constants"
        else:
            title = p["group"] or first_group_names.get(p["block"], "Other")
        if not groups or groups[-1][0] != title:
            groups.append((title, []))
        groups[-1][1].append(p)
    for title, ps in groups:
        out += [f"**{esc(title[0].upper() + title[1:])}**", ""]
        plain = [p for p in ps if p["cls"].startswith("matlab.ui") and not p["desc"] and not p["default"]]
        rich = [p for p in ps if p not in plain]
        if plain:
            out += [", ".join(code(p["name"]) for p in plain), ""]
        if rich:
            out += ["| Property | Type / default | Description |", "| --- | --- | --- |"]
            for p in rich:
                t = prop_type(p)
                td = code(trunc(t, 100)) if t else ""
                if p["default"]:
                    td += (" = " if td else "= ") + code(trunc(p["default"], 100))
                out.append(f"| {code(p['name'])} | {td} | {esc(p['desc'])} |")
            out.append("")
    out += ["#### Methods, by group", "",
            f"Every method is public unless marked. The constructor is defined in the class file; every other method in its own file under `@{name}/`.", ""]
    # constructor
    ctor = [m for m in cls["methods"] if m["name"] == name]
    if ctor:
        c = ctor[0]
        out += ["**Constructor**", "", "| Method | Description |", "| --- | --- |",
                f"| {code(c['sig'])} | {esc(c['h1'] or cls['h1'])} |", ""]
        a = arg_tables(c)
        if a:
            out += a
    bygroup = []
    seen = set()
    methods = {m["name"]: m for m in cls["methods"]}
    for d in cls["declared"]:
        m = methods.get(d["name"])
        if not m:
            continue
        g = d["group"] or "Other"
        if not bygroup or bygroup[-1][0] != g:
            bygroup.append((g, []))
        bygroup[-1][1].append(m)
        seen.add(d["name"])
    for m in cls["methods"]:
        if m["name"] == name or m["name"] in seen:
            continue
        if m.get("inline"):
            g = m.get("group") or "Other"
        else:
            g = "Not declared in the class file"
        bygroup.append((g, [m]))
    # merge same-named groups preserving first position
    merged = []
    idx = {}
    for g, ms in bygroup:
        if g in idx:
            merged[idx[g]][1].extend(ms)
        else:
            idx[g] = len(merged); merged.append((g, list(ms)))
    for g, ms in merged:
        out += [f"**{esc(g[0].upper() + g[1:])}**", "", "| Method | Description |", "| --- | --- |"]
        for m in ms:
            sig = m["sig"]
            acc = method_access(m)
            tag = []
            if acc:
                tag.append(acc)
            if m["attrs"].get("Static"):
                tag.append("Static")
            if m["attrs"].get("Hidden"):
                tag.append("Hidden")
            d = esc(m.get("h1", ""))
            if tag:
                d = f"*({', '.join(tag)})* " + d
            if m.get("inline") or m.get("abstract"):
                out.append(f"| {code(sig)} | {d} |")
            else:
                r = rel(m["path"])
                out.append(f"| [{code(sig)}]({REPO_URL}{r}) | {d} |")
        out.append("")
    return out


# ---------------------------------------------------------------- functions section

def function_detail(f, h="###"):
    out = [f"{h} {f['name']}", "", "```matlab", f["sig"], "```", ""]
    if f["h1"]:
        out += [esc(f["h1"]), ""]
    out += ["Source: " + src_link(f["path"]), ""]
    out += arg_tables(f)
    out += help_details(f["help"])
    return out


def functions_section(funcs, private, groups=None, intro=None):
    out = []
    if intro:
        out += [intro, ""]
    if groups:
        byname = {f["name"]: f for f in funcs}
        out += ["| Function | Description |", "| --- | --- |"]
        used = set()
        for title, names in groups:
            out.append(f"| **{title}** | |")
            for n in names:
                if n in byname:
                    f = byname[n]; used.add(n)
                    out.append(f"| [{code(n)}](#{anchor(n)}) | {esc(f['h1'])} |")
        rest = [f for f in funcs if f["name"] not in used]
        if rest:
            out.append("| **Other** | |")
            for f in rest:
                out.append(f"| [{code(f['name'])}](#{anchor(f['name'])}) | {esc(f['h1'])} |")
        out.append("")
        order = []
        for title, names in groups:
            order += [byname[n] for n in names if n in byname]
        order += rest
    else:
        out += ["| Function | Description |", "| --- | --- |"]
        for f in funcs:
            out.append(f"| [{code(f['name'])}](#{anchor(f['name'])}) | {esc(f['h1'])} |")
        out.append("")
        order = funcs
    for f in order:
        out += function_detail(f)
    if private:
        out += ["## Private helpers", "", "| Helper | Folder | Description |", "| --- | --- | --- |"]
        for f in sorted(private, key=lambda f: f["name"].lower()):
            out.append(f"| {code(f['sig'])} | `{os.path.dirname(rel(f['path']))}` | {esc(f['h1'])} |")
        out.append("")
    return out


# ---------------------------------------------------------------- pages

def splice(page, generated, marker="## Reference"):
    path = os.path.join(WIKI, page + ".md")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            txt = f.read()
        k = txt.find("\n" + marker + "\n")
        if k < 0:
            raise SystemExit(f"{page}: no '{marker}' heading")
        lead = txt[:k + 1]
    else:
        raise SystemExit(f"{page}: page missing (write its lead first)")
    body = lead + marker + "\n\n" + "\n".join(generated).rstrip() + "\n"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)


def write_gen(name, lines):
    if not GEN:
        return
    os.makedirs(GEN, exist_ok=True)
    with open(os.path.join(GEN, f"api-{name}.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines).rstrip() + "\n")


def pdir(*p):
    return os.path.join(SRC, *p)


def public_functions(folder, exclude=()):
    fs = []
    for p in sorted(glob.glob(os.path.join(folder, "*.m")), key=lambda s: os.path.basename(s).lower()):
        n = os.path.splitext(os.path.basename(p))[0]
        if n.startswith("test_") or n in exclude:
            continue
        with open(p, encoding="utf-8", errors="replace") as fh:
            t = fh.read()
        if re.search(r"^\s*classdef\b", t, re.M):
            continue
        f = parse_function_file(p)
        if f is None:
            continue  # script
        fs.append(f)
    return fs


PIPE_GROUPS = [
    ("Path setup", ["addpath_nogit"]),
    ("Epsych2 sessions and trials", ["readEpsychSession", "epsychSessionMeta", "findEpsychSessions",
                                     "matchEpsychSession", "pairEpsychTrials", "digitalLinePolarity",
                                     "stitchEpsychSessions"]),
    ("Copying sessions from the source", ["findCopySessions", "stitchCopySessions", "copySessions"]),
    ("Freeing local disk space (Clean up tab)", ["planLocalCleanup", "runLocalCleanup"]),
    ("Background Kilosort4 runs", ["sortingSlot", "waitForSortingSlot"]),
    ("Units and names", ["unitTable", "parseNameTokens"]),
    ("Derived signals and conversion", ["intan2matlab", "matrix2kilosort", "extract_trials"]),
    ("Synthetic data", ["makeSyntheticProject", "makeSyntheticRecording", "makeSyntheticProbe"]),
    ("Probe maps", ["probeMapProblems", "writeProbeMap"]),
    ("File I/O", ["readJsonFile", "writeJsonFile", "readNPY", "writeNPY", "read_Intan_RHD2000_file_modified"]),
    ("Tests", ["run_all_tests"]),
]

ANALYSIS_GROUPS = [
    ("Loading", ["loadAnalysisSource"]),
    ("Events, trial selection and epochs", ["eventRef", "resolveEvents", "respCodeBits", "trialSelection",
                                            "selectTrials", "epochWindow", "epochTable"]),
    ("Units and channels", ["selectUnits", "selectChannels"]),
    ("Compute", ["spikePSTH", "firingRate", "tuningCurve", "evokedPotential", "unitCorrelation",
                 "unitSummary", "probeMapValues"]),
    ("Renderers", ["renderPlot", "renderPSTH", "renderRaster", "renderRates", "renderHeatmap", "renderTuning",
                   "renderEvoked", "renderProbeMap", "renderCorrMap"]),
    ("Plot helpers", ["plotCaption", "plotSkipReason", "plotPageCount", "plotFileName", "blueWhiteRed"]),
    ("Figure export and reports", ["newExportFigure", "exportFigure", "figureFileName", "newAnalysisReport",
                                   "addReportDataset", "addReportFigure", "reportSummaryTables",
                                   "writeHtmlReport", "writePdfReport"]),
]


def main(do_splice=True):
    pages = {}
    simple = {
        "EphysDataset": pdir("pipeline", "@EphysDataset"),
        "EphysProject": pdir("pipeline", "@EphysProject"),
        "DatasetTracker": pdir("pipeline", "@DatasetTracker"),
        "DatasetOutputs": pdir("pipeline", "@DatasetOutputs"),
        "EphysPipelineConfig": pdir("pipeline", "@EphysPipelineConfig"),
        "EphysPipeline": pdir("pipeline", "@EphysPipeline"),
        "EphysPipelineScript": pdir("pipeline", "@EphysPipelineScript"),
        "ChronuxDataset": pdir("pipeline", "@ChronuxDataset"),
        "FieldTripExport": pdir("pipeline", "@FieldTripExport"),
        "ProbeDesignerApp": pdir("pipeline", "ProbeDesignerApp.m"),
        "CopySchedule": pdir("pipeline", "CopySchedule.m"),
        "EphysAnalysisConfig": pdir("analysis", "@EphysAnalysisConfig"),
        "EphysAnalysisRunner": pdir("analysis", "@EphysAnalysisRunner"),
        "EphysAnalysisScript": pdir("analysis", "@EphysAnalysisScript"),
    }
    for n, p in simple.items():
        cls = load_class(p)
        g = class_section(cls)
        write_gen(n, g)
        pages["API-" + n] = g
    # readers
    g = []
    for n in ["EphysReader", "IntanReader", "BinaryReader", "OpenEphysReader"]:
        cls = load_class(pdir("pipeline", "@" + n))
        sec = [f"### {n}", ""] + class_section(cls)
        write_gen(n, sec)
        g += sec
    pages["API-Readers"] = g
    # apps
    cls = load_class(pdir("pipeline", "@EphysPreprocessingApp"))
    g = app_section(cls, {0: "Figure and tab strip", 1: "Project and the active dataset"})
    write_gen("EphysPreprocessingApp", g); pages["API-EphysPreprocessingApp"] = g
    cls = load_class(pdir("analysis", "@EphysAnalysisApp"))
    g = app_section(cls, {0: "Figure and tabs", 1: "State"})
    write_gen("EphysAnalysisApp", g); pages["API-EphysAnalysisApp"] = g
    # functions
    pf = public_functions(pdir("pipeline")) + public_functions(SRC)
    pf.sort(key=lambda f: f["name"].lower())
    priv = []
    for d in [pdir("pipeline", "private"), pdir("pipeline", "@EphysDataset", "private")]:
        for p in sorted(glob.glob(os.path.join(d, "*.m"))):
            f = parse_function_file(p)
            if f:
                priv.append(f)
    g = functions_section(pf, priv, PIPE_GROUPS)
    write_gen("Functions", g); pages["API-Functions"] = g
    af = public_functions(pdir("analysis"))
    priv = [f for f in (parse_function_file(p) for p in sorted(glob.glob(pdir("analysis", "private", "*.m")))) if f]
    g = functions_section(af, priv, ANALYSIS_GROUPS)
    write_gen("Analysis-Functions", g); pages["API-Analysis-Functions"] = g
    if do_splice:
        for page, g in pages.items():
            if os.path.exists(os.path.join(WIKI, page + ".md")):
                splice(page, g)
            else:
                print("no page yet:", page)
    print("generated", len(pages), "pages")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Generate the wiki's API reference sections.")
    ap.add_argument("--wiki", default="", help="the wiki's git clone (pages to splice)")
    ap.add_argument("--src", default=SRC, help="source tree to document (default: this repository)")
    ap.add_argument("--gen", default="", help="also write each section to this folder")
    ap.add_argument("--no-splice", action="store_true", help="generate only")
    a = ap.parse_args()
    SRC = os.path.abspath(a.src)
    WIKI = os.path.abspath(a.wiki) if a.wiki else ""
    GEN = os.path.abspath(a.gen) if a.gen else ""
    if not os.path.isdir(os.path.join(SRC, "pipeline")):
        sys.exit(f"--src {SRC} has no pipeline/ folder")
    if not a.no_splice and not os.path.isdir(WIKI):
        sys.exit("--wiki must name the wiki's clone (or pass --no-splice)")
    main(not a.no_splice)
