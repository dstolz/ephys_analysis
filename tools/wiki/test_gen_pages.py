"""Tests for gen_pages.py: sections, heading levels, link rewriting.

    python -m unittest tools/wiki/test_gen_pages.py      (from the repository root)
"""
import os, sys, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_pages as g

APP = """# The app

Intro with a [link](#sorting) and [code](../pipeline/foo.m).

## Copy

Copies. See [the sort](#sorting) and [formats](file-formats.md#nwb-export).

### Details

```text
## not a heading
[not](a-link.md)
```

## Sorting

Sorts. Back to [copy](#copy). [Elsewhere](EphysDataset.md#reading).

<!-- wiki: ![The Sorting tab](images/app-sorting-tab.png) -->

<!-- wiki
![Optimize](images/app-optimize.png)
See [copy](#copy) too.
-->
"""
FMT = """# Files

## NWB export

Text.
"""


class GenPages(unittest.TestCase):
    def setUp(self):
        self.texts = {"documentation/app.md": APP, "documentation/file-formats.md": FMT}
        self.pages = [
            {"page": "Copy-Tab", "source": "documentation/app.md", "sections": ["Copy"], "status": "candidate"},
            {"page": "Sorting-Tab", "source": "documentation/app.md", "sections": ["Sorting"], "status": "candidate"},
            {"page": "File-Formats", "source": "documentation/file-formats.md", "status": "generated"},
        ]
        self.idx = g.page_index(self.pages, self.texts)

    def page(self, name):
        p = next(p for p in self.pages if p["page"] == name)
        return g.build(p, self.texts, self.idx)

    def test_sections_and_levels(self):
        t = self.page("Copy-Tab")
        self.assertIn("# Copy", t)
        self.assertIn("## Details", t, "### becomes ##")
        self.assertIn("## not a heading", t, "code blocks are left alone")
        self.assertIn("[not](a-link.md)", t, "no link is rewritten in a code block")
        self.assertNotIn("Sorts.", t, "only the sections asked for")
        self.assertTrue(t.startswith("<!-- Generated from documentation/app.md"))

    def test_links(self):
        t = self.page("Copy-Tab")
        self.assertIn("[the sort](Sorting-Tab#sorting)", t, "an anchor in another page's section")
        self.assertIn("[formats](File-Formats#nwb-export)", t, "a whole file made into a page")
        s = self.page("Sorting-Tab")
        self.assertIn("[copy](Copy-Tab#copy)", s)
        self.assertIn("[Elsewhere](" + g.BLOB + "documentation/EphysDataset.md#reading)", s,
                      "a file no page is made from: GitHub")
        f = self.page("File-Formats")
        self.assertNotIn("# Files", f, "the title is dropped")
        self.assertIn("## NWB export", f, "a whole file keeps its levels")

    def test_wiki_only(self):
        s = self.page("Sorting-Tab")
        self.assertIn("\n![The Sorting tab](images/app-sorting-tab.png)\n", s, "a one-line wiki comment is unwrapped")
        self.assertIn("\n![Optimize](images/app-optimize.png)\nSee [copy](Copy-Tab#copy) too.\n", s,
                      "a wiki block is unwrapped, and its links rewritten")
        self.assertNotIn("<!-- wiki", s)
        self.assertNotIn("\n-->", s)
        with self.assertRaises(SystemExit):
            g.unwrap_wiki("<!-- wiki\n![x](images/x.png)\n")

    def test_anchors(self):
        seen = set()
        self.assertEqual(g.anchor_of("NWB export (`exportNWB`; the Export step)", seen),
                         "nwb-export-exportnwb-the-export-step")
        self.assertEqual(g.anchor_of("NWB export (`exportNWB`; the Export step)", seen),
                         "nwb-export-exportnwb-the-export-step-1")

    def test_real_map(self):
        pages, texts = g.load_pages(g.REPO)
        idx = g.page_index(pages, texts)
        for p in pages:
            self.assertTrue(g.build(p, texts, idx).strip(), p["page"])


if __name__ == "__main__":
    unittest.main()
