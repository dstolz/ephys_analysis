"""Check the links of the ephys_analysis wiki before it is pushed.

Usage:  python check_links.py <wiki clone>

Reports, per page:
  MISSING PAGE    a [text](Page) link to a page that does not exist
  MISSING ANCHOR  a [text](Page#anchor) link to a heading the page lacks
                  (GitHub's anchors: the heading lowercased, punctuation
                  removed except - and _, spaces as hyphens, -1 / -2 ...
                  for repeats; <a name="..."> targets count too)
  MISSING IMG     an images/... link to a file that is not in the clone
  HTML-EATEN      <Name> outside backticks, which GitHub drops as an HTML tag
Code blocks are skipped. Exits with status 1 when anything is reported.
"""
import glob, os, re, sys


def anchors(text):
    """The anchors GitHub generates for TEXT's headings, plus explicit <a> targets."""
    found = set()
    body = re.sub(r'```.*?```', '', text, flags=re.S)
    for h in re.findall(r'^#{1,6}\s+(.*?)\s*$', body, re.M):
        h = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', h)   # a link in a heading keeps its text
        s = re.sub(r'[^\w\- ]', '', h.strip().lower()).replace(' ', '-')
        base, n = s, 1
        while s in found:
            s = f'{base}-{n}'
            n += 1
        found.add(s)
    found |= set(re.findall(r'<a (?:name|id)="([^"]+)"', text))
    return found


def main(wiki):
    os.chdir(wiki)
    pages = {f[:-3]: open(f, encoding='utf-8').read() for f in glob.glob('*.md')}
    targets = {p: anchors(t) for p, t in pages.items()}
    bad = 0
    for page, text in sorted(pages.items()):
        body = re.sub(r'```.*?```', '', text, flags=re.S)
        for m in re.finditer(r'\]\(([^)\s]+)\)', body):
            link = m.group(1)
            if link.startswith(('http', 'mailto')):
                continue
            if link.startswith('images/'):
                if not os.path.exists(link):
                    print(page, 'MISSING IMG', link)
                    bad += 1
                continue
            target, _, anchor = link.partition('#')
            target = target or page
            if target not in pages:
                print(page, 'MISSING PAGE', link)
                bad += 1
            elif anchor and anchor not in targets[target]:
                print(page, 'MISSING ANCHOR', link)
                bad += 1
        for m in re.finditer(r'(?<![`\\])<([A-Z][A-Za-z]*)>', re.sub(r'`[^`]*`', '', body)):
            print(page, 'HTML-EATEN', m.group(0))
            bad += 1
    print(f'{len(pages)} pages, {bad} problem(s)')
    return bad


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(1 if main(sys.argv[1]) else 0)
