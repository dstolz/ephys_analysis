# Wiki tools

Tools for updating the [GitHub wiki](https://github.com/dstolz/ephys_analysis/wiki)
so that each update repeats the last one instead of rebuilding it.

| File | What it does |
| --- | --- |
| `gen_api.py` | Generates the reference part of every `API-*` page from the `.m` sources. It needs no MATLAB. |
| `check_links.py` | Checks every page's links, anchors and images before a push. |
| `wikiScreenshots.m` | Takes the preprocessing app's screenshots headlessly over a synthetic project, and runs it. |
| `wikiToolScreenshots.m` | Takes the other windows' screenshots (probe designer, channel mapper, manifest viewer, analysis app) over that project. |
| `restoreAppPrefs.m` | Puts the apps' preferences back if a screenshot run had to be killed. |

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

3. **Edit the prose pages by hand.** Mirror the change in `documentation/`
   and treat the code as authoritative. Pages to check for background-run
   changes, for example: Run-and-Flow-Tabs, Sorting-Tab, File-Formats,
   Output-Files, Pipeline-Configs, Python-Drivers,
   Running-Pipelines-from-Scripts, Working-with-Datasets, Architecture,
   Testing and Troubleshooting-and-FAQ.

4. **Retake the screenshots the change affects**, with MATLAB R2025a. First
   the preprocessing app, which also writes and runs the synthetic project:

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

- **Preferences.** Both scripts and the apps' test suites back up and
  restore the same preferences (`EphysPreprocessingApp`, and for
  `wikiToolScreenshots` also `EphysAnalysisApp` and `ChannelMapperApp`), so
  never run two app-driving MATLABs at once. Check first:
  `Get-CimInstance Win32_Process -Filter "Name='MATLAB.exe'"`.
- **`exportapp` can hang, or capture a stale frame on a busy machine.** Two
  things reduce it: the script stops the resource monitor's timer before the
  results shot, and it waits for rendering (`Wait=`). If a run hangs, kill
  MATLAB and run `restoreAppPrefs('<out folder>\prefs_backup.mat')`.
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
