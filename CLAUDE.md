# Notes for Claude Code

Standing instructions from the repository's owner.

To reduce redundancy, use functions already existing within this repository whenever possible. If needed, update the function without breaking existing behavior. Keep functions organized in a logical manner.

## MATLAB toolboxes

- When a function from one of these toolboxes fits the job, use it instead of
  writing your own: Statistics and Machine Learning Toolbox, Parallel
  Computing Toolbox, Image Processing Toolbox, Signal Processing Toolbox.
- Any other MathWorks toolbox may be used too, without asking: the owner is
  licensed for all of them (2026-10-29). Prefer a toolbox function to a
  hand-written one.
- List each toolbox the code uses, and what for, under Dependencies in
  [documentation/README.md](documentation/README.md#dependencies).
- Exception: `analysis/pAdjust.m` (Benjamini-Hochberg, Holm, Bonferroni)
  stays in the repository, by the owner's choice. The Statistics and Machine
  Learning Toolbox has no p-value adjustment; the owner chose this file over
  the Bioinformatics Toolbox's `mafdr`.

## Testing

The whole suite takes about 25 minutes, so test only what a change touched,
unless the owner says otherwise.

- Run only the suites that cover the code you changed, by name:
  `run_all_tests({'test_A','test_B'})`. To find them, run
  `python .github/scripts/select_suites.py --worktree --sections --why --expect`:
  it names the suites, or the sections of a suite, the uncommitted change
  reaches, why, and the expected seconds. When a signature, a classdef
  declaration or a UI builder changed, also run the suites that call it or
  build the app.
- When a suite takes sections (`test_EphysAnalysisApp`, `test_EphysPipelineApp`,
  `test_EphysAnalysisFigures`), run only the sections the change touches:
  `run_all_tests({'test_EphysAnalysisApp:5i'})`. Its fixture and what the
  sections declare they need run with them.
- Run suites through `tools\Run-Tests.ps1` (PowerShell): `-Select` runs what
  the selector prints; it logs, records every run's seconds, keeps to two test
  MATLABs on the machine, and leaves out the tests tagged `Slow` and
  `Benchmark` (CI runs them; `-IncludeSlow` does too).
- Test once, when the change is finished, not after each edit. While fixing
  failures, rerun only the suites that failed.
- Never run the whole suite (bare `run_all_tests`) unless the owner asks for
  it. If you judge a full run critical, for example after a change to code
  that most suites depend on, ask first. Say why, and how long it will take.
- When you report results, name the suites you ran and the ones you left
  out.

## Documentation and the wiki

The [GitHub wiki](https://github.com/dstolz/ephys_analysis/wiki) is how
people learn to use this repository. Keep it current; the mechanics are in
[tools/wiki/README.md](tools/wiki/README.md).

- **Two audiences, no third.** Write for (1) the scientist who uses the
  windows and does not program, and (2) the scientist who writes MATLAB
  scripts with the repository's tools. Nothing for developers of the code:
  no architecture, extending or testing pages. A doc's developer sections
  (`Tests`, `Where the code is`) stay in `documentation/` and are left out
  of the wiki with `exclude` in `tools/wiki/pages.json`.
- **Three branches.** The sidebar has one branch per tool: the pipeline app
  (`EphysPipelineApp`), the analysis app (`EphysAnalysisApp`) and the
  dataset browser (`DatasetBrowser`). Each is split into *Using the app*,
  starting at its plain-language guide, and *Writing scripts*, starting at
  its scripting page, with the tool's API pages under it. A new page goes
  in the branch and the audience it serves.
- **The guides** (`documentation/pipeline-app-guide.md`,
  `analysis-app-guide.md`, `dataset-browser-guide.md`) are for the first
  audience: plain words, short sentences, what to click and what you will
  see, a typical session, common tasks, what to do when something goes
  wrong. Keep them short and point to the reference pages for the details.
  When a change adds or renames something a user clicks, update the guide
  as well as the reference doc.
- **Encourage tags.** Keep the tags sections (the pipeline app guide's
  "Tag your datasets", the analysis app and browser guides' sections, the
  scripting overview's "Select datasets by tag" and Home's pointer), and
  show tags in new examples where they fit.
- **One source.** Edit `documentation/`, never a generated wiki page. Wiki
  pages not in `pages.json` (Home, Quick-Start, Output-Files,
  Troubleshooting-and-FAQ, the pipeline scripting pages,
  Analysis-Toolbox-Exports, the sidebar and footer) are edited in a wiki
  clone. Check them too when a change touches what they say.
- **When code changes**, update the matching `documentation/` page in the
  same commit. Update the wiki when the owner asks, and only from a commit
  pushed to main: regenerate the API pages (`gen_api.py`) and the prose
  pages (`gen_pages.py`), retake the screenshots the change affects, run
  `check_links.py` (0 problems) and `test_gen_pages.py`, and set the footer
  to the commit. A new public function needs a group in `gen_api.py`, and a
  new class a script writer uses needs an `API-<Class>` page with a short
  lead.
- **Help menus.** The apps' Help menus open wiki pages by name and anchor
  (`helpURL.m`, `buildMenus.m`, `DatasetBrowser.m`); `test_gen_pages.py`
  checks them. Keep those pages and headings, or change the menus with them.
- American spelling everywhere (color, gray, canceled, labeled).
