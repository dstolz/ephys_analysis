"""Tests for gen_pages.py: sections, heading levels, link rewriting, and the
anchors the pipeline and analysis apps' Help opens.

    python -m unittest tools/wiki/test_gen_pages.py      (from the repository root)
"""
import os, re, sys, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_pages as g

APP = """# The app

Intro with a [link](#sorting) and [code](../pipeline/foo.m).

## Copy

Copies. See [the sort](#sorting) and [formats](file-formats.md#nwb-export).

### Details

<a name="old-details"></a>

```text
## not a heading
[not](a-link.md)
```

## Sorting

Sorts. Back to [copy](#copy). [Elsewhere](EphysDataset.md#reading). [Old](#old-details).

<!-- wiki: ![The Sorting tab](images/app-sorting-tab.png) -->

<!-- wiki
![Optimize](images/app-optimize.png)
See [copy](#copy) too.
-->

<!-- wiki: More in [Troubleshooting](Troubleshooting-and-FAQ#sorting) and [the start](Quick-Start). -->
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
        self.assertIn("[Old](Copy-Tab#old-details)", s, "an <a name> target goes with the section it sits in")
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
        self.assertIn("[Troubleshooting](Troubleshooting-and-FAQ#sorting) and [the start](Quick-Start)", s,
                      "a link to a page only the wiki has is kept")
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

    def test_app_help_anchors(self):
        """Every page#anchor the apps' Help opens is a heading of the page made for it: the pipeline
        app's helpURL.m, and the analysis app's helpURL.m (its tabs) and buildMenus.m (its quick start)."""
        pages, texts = g.load_pages(g.REPO)
        idx = g.page_index(pages, texts)
        built = {p["page"]: g.build(p, texts, idx) for p in pages}
        files = [("pipeline", "@EphysPipelineApp", "helpURL.m"),
                 ("analysis", "@EphysAnalysisApp", "helpURL.m"),
                 ("analysis", "@EphysAnalysisApp", "buildMenus.m")]
        for parts in files:
            name = "/".join(parts)
            src = open(os.path.join(g.REPO, *parts), encoding="utf-8").read()
            links = re.findall(r'(?:page = |onHelp\()"([A-Za-z0-9-]+)#([\w-]+)"', src)
            self.assertTrue(links, f"{name} opens some anchors")
            for page, anchor in links:
                self.assertIn(page, built, f"{name}: {page} is made from documentation/")
                self.assertIn(anchor, g.anchors_by_section(built[page]), f"{name}: {page}#{anchor}")


if __name__ == "__main__":
    unittest.main()
