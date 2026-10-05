# Wiki tools

Tools for updating the [GitHub wiki](https://github.com/dstolz/ephys_analysis/wiki)
so that each update repeats the last one instead of rebuilding it.

| File | What it does |
| --- | --- |
| `gen_api.py` | Generates the reference part of every `API-*` page from the `.m` sources. It needs no MATLAB. |
| `gen_pages.py`, `pages.json` | Generates the prose pages from `documentation/`, the one source: `pages.json` says which page is made from which file or sections. It needs no MATLAB, and `test_gen_pages.py` tests it. |
| `check_links.py` | Checks every page's links, anchors and images before a push. |
| `wikiScreenshots.m` | Takes the pipeline app's screenshots headlessly over a synthetic project, and runs it. |
| `wikiToolScreenshots.m` | Takes the other windows' screenshots (probe designer, channel mapper, manifest viewer, analysis app) over that project. |
| `restoreAppPrefs.m` | Puts back preferences from a backup an older version of the screenshot scripts left behind. The scripts now use a temporary preference store (`AppPrefs`), so a killed run leaves your preferences as they were. |

## Updating the wiki

The wiki is its own git repository (branch **master**):

```bat
git clone https://github.com/dstolz/ephys_analysis.wiki.git C:\temp\wiki
```

1. **Document a commit, not the working tree.** Push the code first. The API
   pages link to source files on `main`, and the footer names the commit.
   Then snapshot that commit, so that uncommitted edits (other sessions') and
   `.claude/worktrees` copies stay out:

   ```bat
   mkdir C:\temp\src
   git archive <sha> | tar -x -C C:\temp\src
   ```

2. **Regenerate the API sections:**

   ```bat
   python tools\wiki\gen_api.py --src C:\temp\src --wiki C:\temp\wiki
   ```

   Every `API-*.md` page keeps its hand-written lead. Everything from its
   `## Reference` heading on is replaced: properties, method and function
   signatures, `arguments` blocks with their defaults and validators, and the
   help text (`%` plus one space stripped). The first help line becomes the
   description in the tables (escaped for markdown and HTML). A page that
   exists without that heading stops the run; a missing page is skipped
   with a note.

   - A new class needs an entry in `main()`'s `simple` map (or the readers /
     apps blocks) and a page with a lead and a `## Reference` heading.
   - A new public function of `pipeline/` goes under "Other" until it gets a
     group in `PIPE_GROUPS` (`ANALYSIS_GROUPS` for `analysis/`).

   `--gen <folder>` also writes each generated section to
   `<folder>/api-<Name>.md`. `--no-splice` generates without touching the wiki.

3. **Generate the prose pages from `documentation/`:**

   ```bat
   python tools\wiki\gen_pages.py --src C:\temp\src --wiki C:\temp\wiki
   ```

   `documentation/` is the one source. Edit it, never a generated page,
   because the next run replaces that page whole. Each page in `pages.json`
   is made from a file, or from some of its `## ` sections (the app's tabs
   from `EphysPipelineApp.md`). The file's title is dropped, and the
   headings go up a level when sections are taken. Links to other docs
   point at the page made from them (or from the section that holds the
   anchor), and links to anything else point at the file on GitHub. A new
   page needs a line in `_Sidebar.md`.

   A page's `status` in `pages.json` says whether it is generated yet:

   - `generated`: written whole, every update.
   - `candidate`: the wiki version still says things `documentation/` does
     not. It is generated only for comparison:
     `gen_pages.py --wiki C:\temp\wiki --report` prints how many lines each
     page differs by, and `--out <folder>` writes them all for a diff.
     Merge what the wiki page has into `documentation/`, keep the headings
     other pages link to (`check_links.py` lists any link that breaks),
     then set it to `generated`. Until then, edit that wiki page by hand
     as before. `--include-candidates` writes them all.

   Pages not in `pages.json` stay hand-written in the wiki: Home,
   Quick-Start, Output-Files, Troubleshooting-and-FAQ, the scripting guide,
   Architecture, Extending-the-Pipeline, Testing, the sidebar and the
   footer. Check them for the change too.

4. **Retake the screenshots the change affects**, with MATLAB R2025a. First
   the pipeline app, which also writes and runs the synthetic project:

   ```bat
   matlab -batch "addpath('C:\src\ephys_analysis\tools\wiki'); wikiScreenshots('C:\temp\shots', Source='C:\temp\src', Project='C:\temp\wiki_shots\synthetic_ephys')"
   ```

   Then the other windows, over that project:

   ```bat
   matlab -batch "addpath('C:\src\ephys_analysis\tools\wiki'); wikiToolScreenshots('C:\temp\shots', Source='C:\temp\src', Project='C:\temp\wiki_shots\synthetic_ephys')"
   ```

   Copy the files into the wiki's `images/`. Every image there comes from
   one of the two scripts, except `flow-full.png` (a browser capture of the
   page the Diagram tab's **Save as HTML...** writes):

   - `wikiScreenshots`: every `app-*.png`. That is the Copy, Project,
     Trials (clean, mismatch, resolved), Probe, Artifacts, Sorting,
     Signals, Spikes, Export, Diagram (both views), Synthetic, Run (plan,
     results), Visualize (traces, heatmap), Review (unit, notes) and Clean
     up tabs.
   - `wikiToolScreenshots`: `probe-designer`, `channel-mapper`,
     `manifest-viewer`, the analysis app's four tabs (`analysis-*-tab`) and
     the three example figures its run writes (`analysis-example-*`).

   Each script's help says what each shot shows. `Shots={...}` takes a
   subset. A `Project=` folder that already holds a synthetic project is
   reused, so a subset of Visualize or Review shots needs no new run; the
   Run shots always run it. `wikiToolScreenshots` needs a project that has
   been run.

5. **Check the links**, update `_Footer.md` to the commit, then commit and push:

   ```bat
   python tools\wiki\check_links.py C:\temp\wiki
   cd C:\temp\wiki && git add -A && git commit -m "Update the wiki to commit <sha>: ..." && git push origin master
   ```

   If someone pushed to the wiki meanwhile, `git fetch` and `git rebase
   origin/master` first. Both tools only rewrite what they own, so rebases
   are usually clean.

## Things that bite

- **Preferences.** The scripts and the apps' test suites keep the apps'
  preferences in a temporary file of their own (`AppPrefs.useTemporary`),
  so they never read or change yours, and two of them can run at once.
  `Source=` must be a commit that has `AppPrefs`.
- **`exportapp` can hang, or capture a stale frame on a busy machine.** Two
  things reduce it: the script stops the resource monitor's timer before the
  results shot, and it waits for rendering (`Wait=`). If a run hangs, kill
  MATLAB; your preferences are as they were.
- **`-batch` strips double quotes.** Use single-quoted MATLAB strings and a
  cell array for `Shots`.
- **GitHub wiki markdown.**
  - Anchors are the heading lowercased with punctuation removed, spaces as
    hyphens and underscores kept.
  - `<Name>` outside backticks is eaten as an HTML tag.
  - `images/foo.png` links work once the file is committed under `images/`.
  - Mermaid renders.
- **Line endings.** The clone checks pages out with CRLF while the tools write
  LF. Git's "LF will be replaced by CRLF" warnings are harmless, and `git
  diff` shows only content changes.
