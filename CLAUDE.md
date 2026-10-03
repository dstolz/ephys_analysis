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
