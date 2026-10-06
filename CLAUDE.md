# Notes for Claude Code

Standing instructions from the repository's owner.

## MATLAB toolboxes

- When a function from one of these toolboxes fits the job, use it instead of
  writing your own: Statistics and Machine Learning Toolbox, Parallel
  Computing Toolbox, Image Processing Toolbox, Signal Processing Toolbox.
- Before using a function from any other toolbox, ask.
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
  `run_all_tests({'test_A','test_B'})`. To find them, grep the `test_*.m`
  files in `pipeline/` and `analysis/` for the changed class, method or
  function. When a signature, a classdef declaration or a UI builder
  changed, also run the suites that call it or build the app.
- Test once, when the change is finished, not after each edit. While fixing
  failures, rerun only the suites that failed.
- Never run the whole suite (bare `run_all_tests`) unless the owner asks for
  it. If you judge a full run critical, for example after a change to code
  that most suites depend on, ask first. Say why, and how long it will take.
- When you report results, name the suites you ran and the ones you left
  out.
