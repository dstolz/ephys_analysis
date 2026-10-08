# Changelog

Notable changes to this repository. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and version numbers
follow [Semantic Versioning](https://semver.org/). The current number is in
[`VERSION`](VERSION); [README.md](README.md#versions-license-and-citation)
says how to cut a release.

## [Unreleased]

### Added

- Plot designs (`PlotDesign`): whole looks for every analysis plot -- the
  ground behind it, the group colours, the heat maps' colours, and
  aesthetics rules for its axes, ticks, fonts, titles, axis labels,
  legends, colour bars, lines and marks. Built in: **Tufte** (Edward
  Tufte's data-ink: an off-white page, serif type, no box or grid, grey
  data and muted colour), **Journal** (print-ready, colour-blind safe),
  **Night** (dark), **Talk** (big type, thick lines) and **Gray panel**
  (the ggplot2 look). Picking one -- the analysis app's **Design** list
  and menu, any plot's right-click **Design** submenu, or
  `PlotDesign.use` -- redraws every plot on screen at once, and runs draw
  their figures in it. **Save look as design...** keeps a plot's look
  (every property of every component, its ground and group colours) as a
  JSON design of your own; designs can be imported, deleted and kept in a
  shared folder. A design is a preference, drawn under your rules and the
  plot's own, so those still win. `renderPlot` takes `Design=`.
- The aesthetics editor sets an axes' tick length, and a legend's or
  colour bar's font.

- A behavior plot kind (`behavior`): a per-trial value against a trial
  parameter, e.g. RespLatency by Depth, one series per value of another
  parameter (`param`, `seriesParam`). The value (`yParam`) is a numeric
  trial parameter or `"stop"`, each epoch's stop-event latency in ms (the
  first Trough onset after RespWindow onset, say). Layouts: points (each
  epoch's value, jitter optional, with the mean +/- SEM), line (mean +/-
  SEM), box (`boxchart`), swarm (`swarmchart`) and violin (`violinplot`,
  MATLAB R2024b or later); the x values evenly spaced or at their values
  (`xScale`). Epochs without a value (misses) are left out and counted in
  the caption. `behaviorValues` computes it, `renderBehavior` draws it.
- Events shifted by a trial parameter: an event reference's `offsetParam`
  (and `offsetParamUnit`, ms or s) adds each trial's value of the
  parameter to its event, so plots can be aligned to the response
  (RespWindow onset + RespLatency); events whose trial has no value are
  left out and counted (`nDroppedNoValue`). A stop event takes it too, so
  a stimulus-aligned raster can mark each response and sort by its
  latency. The app's Alignment controls have **Shift by** and **Stop
  shift by**.
- Raster rows: the sort's direction (`rasterSortOrder`, ascending or
  descending; missing values stay last), rows by group first or every
  epoch sorted as one block (`rasterByGroup`), and marks on each row at
  the onsets and / or offsets of digital lines inside its epoch, every one
  of them (several beam crossings in a trial get several marks;
  `rasterEvents`: lines, edge, window or trial scope, marker, size,
  colour; `epochEvents`). The marks are named per line and edge for the
  aesthetics editor and listed in the raster's legend. The plot editor
  has controls for all of them.

- A toolbar in the preprocessing app, under the menu bar: New, Open and
  Save config; Validate config, Plan, Run pipeline, Dry run and Cancel run;
  View manifest; Open analysis app and Channel mapper; Help for this tab.
  Each tool calls the same method as its menu item, and its tooltip names
  the item's shortcut (Ctrl+N, Ctrl+O, Ctrl+S, Ctrl+R; Cmd on a Mac). Run
  pipeline, Dry run and Cancel run turn on and off with the Run tab's
  buttons (`buildToolbar`; icons in `pipeline/icons/toolbar`).
- Copying the pipeline's outputs elsewhere: the config's `Transfer`
  section, the Run tab's **Copy outputs to**. A Run copies, or moves, each
  dataset's outputs to `<folder>/<subject>/<session>` (its recording folder
  below the project root), each one as soon as its step has written it
  (`When = "step"`) or all of them once the Run is over (`"run"`). When the
  dataset's folder is already there, `IfExists` puts the Run's copies in a
  new version folder `<session>_v2` (the default), overwrites the files
  there, or skips them. The copying runs outside MATLAB in the Copy tab's
  engine (robocopy), with size or SHA-256 checks, so the Run never waits for
  it: the Run tab's last row shows its progress (rate, time left, the batch
  in flight) with **Stop copying...**, and each dataset has a `transfer`
  result row and a plan row. A move removes the outputs here only once the
  Run is over, keeps the manifest, and records a moved sort folder as the
  dataset's sorting folder. A background sort is copied once it has
  finished. `OutputTransfer` is the transfer on its own;
  `EphysPipeline.transferOutputs` copies a script's step results, and both
  generated scripts copy too. The Diagram tab's data-flow overview draws it
  as Copy outputs, under every file it reads. A version folder reads as its
  dataset again: `EphysProject` over a copy, and `DatasetOutputs(folder)`,
  name the dataset of `<session>_v2` `<session>`
  (`EphysProject.outputFolderName`).
- `EphysProject(root)` reads a root of pipeline outputs without the
  recordings, such as a backup of an `OutputRoot`. When no recording is
  found, each folder laid out as `<OutputRoot>/<Name>` becomes a dataset,
  with a warning (`EphysProject:OutputsOnly`;
  `EphysProject.findOutputFolders`). `refresh()` takes their rate, channels
  and duration from the extract's `info` and writes nothing there.
  `outputs()` reads their files, and their `OutputDir` stays their own
  folder. `EphysDataset.hasRecording()` tells these datasets apart. An
  analysis config's `"project"` source can point at such a copy.
- **Hide unused** on the Diagram tab (`DiagramHideUnused` preference;
  `HideUnused=true` on `PipelineDiagram.overview` / `detail`): leaves out the
  disabled steps, stages and files switched off, arrows not read and inputs
  nothing reads. In the data-flow overview the Spikes step now sits in the
  same row as Signals and Sorting.
- SpikeInterface sorters as an alternative to Kilosort4, on the Sorting tab.
  **Sorter** (`Sorting.Sorter`) is Kilosort4 by default, run as before with
  the same settings and controls, or a sorter SpikeInterface runs
  (`spykingcircus2`, `tridesclous2`, `lupin`, `simple`, and any other
  installed in the Python env). **Find SpikeInterface sorters** lists the
  installed ones (`EphysDataset.spikeInterfaceSorters`, `si_sorters.py`).
  A chosen sorter's parameters replace the Kilosort4 parameters on the tab:
  JSON seeded with SpikeInterface's defaults, beside each parameter's
  description, kept per sorter in `Sorting.SIParams`.
  `EphysDataset.runSpikeInterface` (`run_si.py`) sorts the same `.bin`
  (artifact periods erased, the common reference applied once: the sorter's
  own is kept out when the `.bin` carries one). It writes phy files in
  Kilosort4's layout to `<output folder>/si_<sorter>/`, each unit labelled
  good or mua by the good-unit criteria (`cluster_SILabel.tsv`), so phy,
  the Review tab, the QC report, the exports and the analysis read it
  unchanged. Background runs, the queue, **Stop runs**, Clean up, the
  generated scripts and the diagrams cover it. A dataset's sorted output
  (`sortingResultsDir`) follows the config's sorter (`EphysDataset.Sorter`,
  `sortRunDir`).

- The Review tab reads any of a dataset's sorts. **Sort** lists them: the
  dataset's own first (its pinned folder, else its sorter's run folder),
  marked **in use**, then every other folder under its output folder that
  holds a sort (`kilosort4`, `si_<sorter>`, a sort sweep's variants), each
  with its sorter and number of units. Choosing one loads it and changes
  nothing the other steps read; a folder from **Browse...** / **Load** is
  added as **other**. **Use this sort** makes the sort shown the dataset's
  sorted output, as the Sorting tab's **Use folder...** does (the run
  folder of the config's sorter goes back to auto). The summary names the
  sorter and where the unit groups come from (phy, Kilosort4's `KSLabel`,
  or `SILabel`).

- An Analysis step at the end of the pipeline: it loads an analysis config
  saved in the analysis app (`Analysis.ConfigFile`, read when the step
  runs) and runs it with `EphysAnalysisRunner` over the pipeline's selected
  datasets instead of the config's own source. It writes the figure files
  (`Analysis.Figures`) and the HTML / PDF report (`Analysis.Report`) where
  the analysis config's Export and Report settings say
  (`EphysPipeline.runAnalysis`). Plan, dry run, cancel, progress, run
  records and both generated scripts cover it; the standalone script
  carries the analysis config as JSON. Validation checks the analysis
  config too, and its errors stop the run. The pipeline app has a new
  **Analysis** tab after Export: the config file, its summary and plots,
  **Open in the analysis app**, the figure and report switches, the plan,
  **Run this step**, **Open report** and **Open figures folder**. The step
  is also on the Run tab's checklist, the run diagram and both Diagram
  views. `EphysAnalysisRunner` gained `SearchDirs` (the pipeline's step
  output folders), and its `ProgressFcn` fraction now covers the whole run
  rather than restarting at each dataset.
- Visualize: views wider than one full-rate read, up to the whole
  recording, are drawn from the signal's min / max envelope
  (`EphysTraceEnvelope`), and the overview strip shows the signal itself.
  The envelope is built once in the background (the recording and the
  `.bin` on `backgroundPool` threads, derived signals on a timer; the status
  line shows progress), cached as `<Name>_envelope_<what>.dat` next to the
  outputs, fingerprinted on the files, the reference and the block sizes,
  and built again when stale. `EphysTraceSource.stamp` / `appliedReference`
  / `threadSafe`.
- `EphysPipeline.cachedDetection(cfg, d)`: whether `<Name>_artifacts.json`
  holds what the current settings detect, without detecting or writing
  (`artifactFingerprint`, `detectionConfig`, `artifactsFile`). Visualize
  says whether the last run's periods were found "with the current
  settings" or "with other settings".
- Clean up removes the Visualize tab's envelope caches: kind `"envelope"` of
  `planLocalCleanup`, ticked by default in the free-space group. A build's
  `.partial` file goes only once it is an hour old.
- Clean up's **Move to a folder** checks the folder at Preview: an **In the
  folder** column and the summary line say which files are already there
  (size and date), and **If a file is already there** chooses what the move
  does with them: skip (the default, as before), overwrite (the file there
  is renamed aside and deleted only once the new one is in place), or keep
  both by moving that dataset's files to a new version folder
  `<dataset key>_v2` (`_v3`, ...), so a sort run folder stays whole. The
  check is redone when the folder, the method or the choice changes and
  before the confirmation. `cleanupMoveTargets` is the preview;
  `runLocalCleanup` takes `IfExists=` and reports `Replaced`. The clean-up
  record is now schema `ephys-local-cleanup/3`, with each run's `ifExists`
  and each file's `replaced`.
- Pipeline app: closing with Kilosort4 runs queued offers **Keep the queue
  for next time**, **Drop the queue** or **Cancel**. A kept queue is stored
  per project root (preference `KeptSortingQueue`) and offered back once
  that root is scanned; the runs that cannot go back are listed with why.
  Background runs still going at close are followed again at the next
  launch (`KeptSortingRuns`); one with no process left is logged and left
  out. `EphysDataset.sortRunProcesses(statusFiles)` counts each run's
  processes.
- `EphysPipelineConfig.validate` warns (`sorting`, `MaxConcurrent`) when two
  or more background Kilosort4 runs at once all go on one GPU, which on a
  small card can run out of memory.
- `aurocCall`: the auROC call (95% CI, fixed, test) over every unit and
  group given; `aurocCurves(..., Call=false)` measures without calling, so
  results can be stacked and called together.
- `populationAnalysis` computes each unit's auROC (`Auroc`, per
  `AurocGroupBy` group) and calls every unit x group curve of the family in
  one `aurocCall`, pooling the 95% CI cutoff as Macedo-Lima et al. (2024)
  pooled their units' trial-type curves: `P.auroc` (curves, calls per unit
  and group, each family's cutoff), the unit's call and peak in `P.units`,
  auROC counts and an `auroc` group key in `populationSummary`, the shares
  and cutoff in the fractions figure, `population_auroc.csv` and the cutoff
  in `population.json`.
- `aurocCurves` checked against the paper's published OFC data (DRUM,
  doi:10.13016/qzzx-zfuh): given the spikes and spout-withdrawal times the
  lab used, it reproduces the published curves, apart from the windows the
  lab's code bins with 11 or 9 bins and spikes exactly on a bin edge. With
  the cutoff pooled over all 533 units, the calls match the paper's: 1050 of
  1050 before withdrawal, 1579 of 1583 after (the 4 differed because silent
  units entered the pool; they now stay out of it).
- `reportPdfPage`: a drawn page as the PDF report holds it.
- `IntanReader.notchFilter`: Intan's software notch for RHD2000 files before
  version 3.0 as one `filter` call (Intan's per-sample loop to rounding,
  several times faster), with `IntanReader.notchLeadIn`.
- `EphysPipelineConfig.numberText`: a number as the shortest text that reads
  back as the same double (replaces the pipeline app's private copy).
- `test_ClassdefDeclarations`: every classdef method declaration in
  `pipeline/` and `analysis/` against its method file's inputs and outputs.
- `tools/wiki/gen_pages.py` unwraps wiki-only comments (`<!-- wiki: ... -->`
  or a `<!-- wiki` block), so `documentation/` holds the wiki's screenshots
  too. Every tab page of the pipeline app, the Synthetic tab's new page, the
  analysis pages, File formats, Python drivers, Kilosort4 notes and
  Installation are now generated from `documentation/`; a test checks that
  every page and anchor the apps' Help opens exists.

- Unit waveforms on the analysis plots: a raster, or a PSTH or tuning
  grid, of spikes can draw each unit's mean waveform, a subsample of its
  spikes, or both, as a box in the unit's tile (the plot's `waveform`:
  `mode`, `location` -- north-east by default -- `box` for the axis box,
  `scale`, `maxSpikes`). `unitWaveforms` reads them: sorted units' spikes
  cut from the sorted `.bin` (`DatasetOutputs.readWaveforms`, cached; the
  template when the `.bin` is gone), detections' saved waveforms. The
  app's plot editor has a *Unit waveform* section.
- auROC in the analysis module (Cohen et al. 2012; Macedo-Lima, Hamlette &
  Caras 2024): `aurocCurves` measures each unit's firing in windows along
  the epoch against its baseline, from the trial-averaged PSTH's bins (the
  paper's, matching the Caras lab's `calculate_auROC.py`) or from each
  epoch's counts, in tiled or sliding windows, and calls the units
  modulated up or down by the paper's 95% CI cutoff, a fixed threshold or a
  per-unit test (bootstrap, ranksum or circular-shift shuffle, adjusted
  with `pAdjust`). PSTH and spike-heatmap plots take it as baseline mode
  `"auroc"` (the plot's `auroc` settings): curves on a 0-1 scale, each
  unit's call marked, heatmap rows in modulation order, optionally only
  the modulated units drawn. The unit selection's response test gains
  `"auroc"`. The app's plot editor shows their settings. Test suite
  `test_Auroc`.

- `LICENSE` (MIT), `THIRD_PARTY_NOTICES.md`, `CITATION.cff`, this changelog
  and a `VERSION` file that `ephysVersion` reads; `ephysVersion` also reports
  `git describe` (`Describe`).
- `run_all_tests` runs every suite through `matlab.unittest`: JUnit XML
  (`JUnit=`), HTML or Cobertura coverage (`Coverage=` / `CoverageXML=`),
  selection by name or tag. Function-style suites run as `LegacySuiteTest`,
  each failed check reported on its own; `findTestSuites` lists the suites.
- `AppPrefs` and `AppPrefsFixture`: the apps keep their preferences through
  one store, which tests and screenshot runs point at a temporary file.
- Test suites `test_AppPrefs` and `test_RepositoryMetadata`.
- Warnings, each with an identifier, wherever a read or parse failure used to
  fall back silently and the fallback changes a result: the `.bin` sidecar
  and an unread phy label table (Kilosort's labels then replace phy's), an
  unreadable probe, the manifest's session details, an unparseable name
  pattern in the probe rules, recording start times (binary, Intan, Open
  Ephys NWB), NWB channel types, electrodes and TTL series, Epsych2 start
  times, unreadable output files, the analysis report's unit tables, a copy
  cancel that could not be signalled and a clean-up that could not list a
  dataset's outputs. They are listed in `documentation/README.md`; suite
  `test_DataPathWarnings` checks six of them.
- Provenance in every output: the release, git commit, branch, uncommitted
  changes and `git describe`, MATLAB, host, user and time (`ephysProvenance`),
  plus the run id and the full pipeline config when `EphysPipeline` writes it.
  `.mat` outputs keep it in `conversion.provenance` / `export.provenance`; the
  `.bin` sidecar, `settings.json` and the kCSD `meta` as JSON. Every writer
  takes `Provenance=`.
- Run records: `EphysPipeline.run` writes
  `<OutputRoot or Root>/pipeline_runs/<runId>_<name>.json` (steps, datasets,
  config, code, machine, Results) whether the run finishes, is cancelled or
  fails; `EphysAnalysisRunner.run` writes `analysis_runs/<runId>_<name>.json`
  in the report folder. Analysis reports show the code version.
- `stringifyNonFinite` (moved out of `writeJsonFile`), `provenanceForJson`;
  suite `test_Provenance`.
- Recording-wide spike-detection thresholds: `detectSpikes(ThresholdScope=
  "recording")` measures each channel's noise over the whole recording in a
  first pass (the same chunks, context, artifact erasing and band-pass as
  detection; every sample counted once) and detects every chunk against it.
  `std` / `rms` are exact; `mad` / `percentile` come from a 0.05 µV histogram
  over ±2000 µV (`info.noiseEstimate` records how; a statistic beyond the
  range or below one bin leaves the channel degenerate, with a warning).
  `Spikes.ThresholdScope` in the config (default `"chunk"`, the behaviour so
  far) and **Noise measured over** on the Spikes tab; the spikes file records
  the scope (`detected.info.thresholdScope`). Suite `test_ThresholdScope`.
- Unit quality metrics with SpikeInterface's definitions (`unitQualityMetrics`:
  firing rate, ISI violations ratio and count, presence ratio, amplitude
  cutoff, SNR, drift), every one checked against SpikeInterface's own values
  (`tools/golden/unit_quality_golden.py`, `pipeline/testdata/`).
  `EphysDataset.unitQuality` / `unitQualityOf` / `readSortedUnits(Quality=true)`
  add them to the units, over the span Kilosort4 sorted, cached per sort in
  `quality_metrics.json`. Good-unit criteria (`unitQualityCriteria`,
  `unitQualityPass`; the Allen Institute's thresholds by default) in the
  pipeline config (`Sorting.Quality`) and the analysis config
  (`UnitSelection.quality`, applied by `selectUnits`). `unitTable` columns;
  the exporters, the Export step and the standalone pipeline script carry the
  metrics (`UnitQuality`, `Export.UnitQuality`, on by default; a failure is a
  warning). Review tab: QC, ISIv, Pres, Cutoff and SNR
  columns, editable criteria, **QC report** (`writeUnitQualityReport`, one HTML
  page per sort). `sortSweep` sorts a dataset with several Kilosort4 settings
  on the same `.bin` and compares the sorts. Suite `test_UnitQuality`.
- `benchmarkDetection`: spike and artifact detection scored against synthetic
  ground truth (per-unit recall with its SNR; per-channel precision, duplicate
  and noise-crossing rates; artifact recall, coverage, edge errors and false
  intervals), with a JSON report. Suite `test_DetectionBenchmark` (tag
  `Benchmark`) holds the default settings to regression floors.
- `Project.SaveScript` (on by default; Project tab, **Save the pipeline script
  on each run**): each pipeline run saves the config's standalone script as
  `<Root>/pipeline_<name>.m` before its first step, replacing the one the
  previous run saved and naming the run in its header; a file of that name
  that no run saved is never overwritten. The run record names the script
  (`script`). `EphysPipeline.writeScript`, `EphysPipeline.ScriptFile`,
  `EphysPipelineScript.standalone(Note=)`; suite `test_PipelineScriptSave`.
- Response statistics in the analysis module: `responseStats` tests every
  unit with the Statistics and Machine Learning Toolbox. `signrank` compares
  the response window's rate with the baseline's over the epochs (two-sided;
  the direction comes from the one-sided tests). With a trial parameter,
  `kruskalwallis` tests the rates across its levels, giving `bestLevel`.
  The p values are adjusted over the units by `pAdjust` (Benjamini-Hochberg,
  Holm, Bonferroni; R's `p.adjust` results, checked against statsmodels:
  `tools/golden/padjust_golden.py`). `UnitSelection.response` (off by
  default) keeps only the units that respond: `selectUnits(..., Ref=,
  Selection=)` with the plot's events, plus the analysis app's
  **Responsive only** row. Suite `test_ResponseStats`.
- Population analysis: `populationAnalysis` puts every unit of an analysis
  config's datasets into one table. It holds each unit's PSTH, rates, the
  response and tuning tests (one correction over every unit or per
  dataset), per-level rates, PSTH peak and latency, and the quality
  metrics. `populationSummary` groups the units by subject, dataset, class,
  shank, depth bin or test outcome: counts, shares responsive and tuned,
  rates, latencies, and mean PSTHs and tuning curves. `renderPopulation`
  draws the PSTH, share, tuning and depth figures. `writePopulation`
  writes the CSV tables, the figures and a JSON record with provenance.
  `responseEpochs`; `responseStats(Tests=false)` gives the rates and
  per-level rates without the toolbox. Suite `test_PopulationAnalysis`.
- NWB 2 export: `EphysDataset.exportNWB` and the Export step's `nwb`
  format write `<Name>.nwb`. It holds electrodes on the probe, LFP / MUA /
  SPIKE (float32 µV with conversion 1e-6), AUX, the sorted units with
  their quality metrics, the paired trials, each digital line's pulses,
  the erased artifact periods as `invalid_times`, and the session,
  subject and provenance. Trial and pulse times are moved to the
  continuous clock. MATLAB stages the data (`stage.json`, `stage.npz`, one
  `.npy` per signal), and `nwb_export.py` writes the file with pynwb and
  checks it with nwbinspector. Findings of importance CRITICAL and above
  warn, and all of them go to `<Name>_nwbinspector.json`.
  `Export.NWB` holds the metadata (nothing is made up when it is left
  blank) and the Python; it is validated, and the Export tab edits it.
  `DatasetOutputs` finds the file (`nwb` kind, `NWBFile`, `NWB`). Suite
  `test_NWBExport`.
- `platformSupport`: the table of the features that depend on the operating
  system (`documentation/platforms.md`). The Windows-only pieces (copying,
  scheduled copies, the Recycle Bin, the resource monitor) refuse other
  platforms through it, with one kind of message naming what they use and
  the alternative; each keeps its own error identifier. On macOS and Linux
  the resource monitor now says it needs Windows instead of failing to
  launch. `openInSystem` opens a folder or file the platform's way (winopen,
  open, xdg-open). The seven places in the apps that open one now call it.
  Off Windows they had used four different fallbacks, and one ran macOS's
  `open` on Linux too. Suite `test_PlatformSupport`.
- Tables keep their sort: a header click in the preprocessing app's Project,
  Trials, Review units, Clean up and Artifacts Selection tables is kept when
  the app fills the table again (another dataset, a reload, an edit, a new
  preview) and in the next session (preference `TableSorts`); right-click →
  **Clear sort** returns to the app's own order. Rows keep their link to
  their dataset, unit, file or trial in any order, and the Clean up table's
  map from a row to the file it removes follows the sort. `TableSort`;
  suite `test_TableSort`.
- `CLAUDE.md`: standing instructions for Claude Code in this repository
  (which MATLAB toolboxes to use, and when to ask first).
- Rasters can sort each group's epochs by something other than trial
  order: plot option `rasterSort` (psth and raster; **Sort raster by** in
  the analysis app) takes `"stop"` (the stop event's latency) or a trial
  parameter, which `computePlot` copies onto the epochs. `renderRaster` and
  `renderPSTH` take `SortBy=`; the y label and the caption name the order.
- Plot aesthetics: right-click any part of an analysis plot (the app's
  preview, or any visible figure `renderPlot` draws into) and pick **Edit
  aesthetics...**. A modal window (`PlotAestheticsDialog`) lists every
  component drawn and edits colours, line styles and widths, markers,
  opacity, fonts, axes, legends and colormaps, with each change shown at
  once. A change goes to this component, the same one in every tile, every
  group of its role, or the rows ticked. **Reset**, **Cancel** and **OK**.
  **Remember for future plots** saves the changes as rules (role, group,
  property, value) with the plot (new plot field `aesthetics`, in the
  config) or for every plot of the kind (preferences, group
  `PlotAesthetics`). `renderPlot` applies the user's rules, then the
  plot's, after drawing; new options `UserAesthetics`, `Editable` and
  `OnRemember`. The renderers name everything they draw (`tagPart`).
  `PlotAesthetics`; suite `test_PlotAesthetics`. The script generator's
  `literal` writes struct arrays.

### Changed

- `EphysAnalysisConfig.addPlot` gives a plot added without a source its
  kind's first source (LFP for an evoked potential; trials for a behavior
  plot), as the app's Add does.
- A psth or raster plot sorted by a trial parameter the dataset lacks is
  skipped ("no trial parameter X") instead of failing when it runs.
- Pipeline app: the Run tab always shows the run diagram and the Resource use
  panel (CPU, memory, disk and GPU). The **Show the run diagram** and
  **Monitor CPU, memory, disk and GPU** switches and their `ShowRunDiagram`
  and `MonitorResources` preferences are gone. The resource sampler starts the
  first time the Run tab is shown (also by Validate, Plan and Run) and runs
  until the app closes.
- Pipeline app: the text that named Kilosort4 for any sort now names the
  sorter. The Run diagram's Sorting step, the Artifacts tab's **Erase in
  sorting** and the Sorting tab's SpikeInterface note follow the selected
  sorter. The background-run label, the queue, **Stop runs...** and the
  close and restart prompts name the sorter of the runs they act on
  ("sorting" when the runs come from more than one sorter). The tooltips,
  Clean up's **Sorting** box (which covers the `si_<sorter>` folders too)
  and the Sorting log are worded for any sorter. Text that only applies
  to Kilosort4 still names it: its parameters, the probe `.json` format,
  `temp_wh.dat` and the GPUs.
- The MUA follows Lakatos et al. (2005, J Neurophysiol 94:1904): band-pass
  `MUA_bpLoHi`, rectify, then a zero-phase 4th-order Butterworth low-pass at
  `MUA_IntegrationHz` (the "integration", 1000 Hz), all at the recording
  rate, then resampled to `MUA_Fs` (2000 Hz). The moving mean after
  resampling is gone: it smoothed the envelope to about 500 Hz and put it
  half a sample (0.25 ms at 2 kHz) late. `MUA_IntegrationHz` is now the
  low-pass cutoff and must be at most `MUA_Fs / 2`
  (`EphysPipelineConfig:SignalsMUAIntegration`,
  `EphysDataset:deriveSignals:MUA_IntegrationNyquist`).
- The QC report (`writeUnitQualityReport`, the Review tab's **QC report**)
  lists the units labelled good first, sorts its table by a click on a
  column header (again: reversed; a third time: back), and draws each good
  unit's mean waveform on its peak channel: the mean and SD of up to
  `WaveformSpikes` (100) of its spikes cut from the sorted `.bin`, else its
  template. A good unit's label in the table links to its waveform.
- The common reference has a config section of its own: `Reference` with
  `Mode` (`"none"` / `"car"` / `"cmr"`), `BadLow` and `BadHigh` (0.3, 2). It
  replaces `Artifacts.Reference`, `Artifacts.ReferenceBadLow` and
  `Artifacts.ReferenceBadHigh`, since every step that reads the recording
  takes it. It is always validated (issues under `reference`), saved as its
  own JSON object and carried onto every dataset's `ArtifactConfig` as
  before. `EphysPipelineConfig.artifactConfig(A, R)` takes both sections.
  The Artifacts tab's panel is titled "Common reference, for every step
  (config: Reference)" and lists the reads it applies to.
- The Intan readers filter a recording's pre-3.0 notch files as one stream:
  no step or ringing at file boundaries. Windows and chunks start the filter
  1.76 s before their first row instead of reading whole files; `readData`
  carries the filter state from file to file; `read_Intan_RHD2000_file_modified`
  takes `Notch=false`.
- `EphysDataset.setTrialPairing` returns `[file, saved]`; the Trials tab's
  Approve no longer writes the manifest twice.
- PDF reports are joined from the pages the runner (and the standalone
  script) drew and exported, with the Apache PDFBox library MATLAB ships; no
  page is drawn twice and no result is kept. A run with both reports took
  about half the time on the test fixture. `addReportFigure` takes `Pages=`;
  `writeHtmlReport` no longer takes `EmbedFormat` / `Dpi`.
- The auROC cutoff warnings are `aurocCall:WideCutoff` /
  `aurocCall:NoCutoff`. `populationAnalysis` builds its epochs with
  `Baseline`, so the PSTH and the auROC share them.
- The pipeline app's Help opens `Run-and-Flow-Tabs#diagram` and `#run`, the
  headings of the page generated from `documentation/`.
- Test descriptions in `documentation/` match the suites; the README table
  lists every suite.

- The analysis app's parameter lists (group-by, tuning x axis and series,
  tuning-test parameter, the dataset's Parameters table, the filter help's
  columns) offer every trial column, `RespCode` among them, in alphabetical
  order (ignoring case). `loadAnalysisSource`'s `paramNames` leaves out only
  the pairing's times and samples; it no longer follows `info.WriteParams`.
- Analysis figures and the HTML report are easier to read:
  - A PSTH grid puts each raster right on top of its rate panel. The two
    sit in a 2 x 1 tiled layout in the unit's tile, so the gap between
    rows falls between units, not between a raster and its own PSTH.
  - A grid page grows taller than `Export.FigureSizeCm(2)` when its rows
    need it: 3 cm a row, 4.5 cm for PSTHs with rasters, plus 1.5 cm. Call
    `newExportFigure(X, R, spec, Page=p)`; the runner, both reports and
    the generated scripts do.
  - In grids of more than one tile, the tick labels are 2 points smaller
    than `Style.FontSize` and each automatic y axis has at most three
    ticks (new private `tileTicks`).
  - A raster drops its ticks in the bottom tenth, and "Epoch" is shown on
    the left column only.
  - Depths in unit titles are whole µm.
  - The probe map writes each site's number on the outer side of its
    column, so the labels stay clear of the markers.
  - The report's digital-line and highest-rate tables have readable
    headers ("Mean duration (s)", "Rate (Hz)") and short unit labels. An
    empty value prints as an empty cell, not `NaN`.
  - A printed report (or one saved as PDF) no longer splits a table or a
    figure across pages, or breaks right after a heading.
  - `Report.Title` defaults to `"{Name}"`. The app names a new config
    `"<folder> quick look"`, so the old default `"{Name} quick look"` read
    "… quick look quick look".
- `EphysPreprocessingApp` is renamed `EphysPipelineApp` (class folder,
  `test_EphysPipelineApp`, `documentation/EphysPipelineApp.md`), and the
  analysis app's **File → Open preprocessing app** is now **Open pipeline
  app** (`onOpenPipelineApp`). Its preferences group is `EphysPipelineApp`,
  so preferences saved under the old name are not read.
- `S_ExampleAnalysis.m` is a walkthrough that runs on any machine. Before,
  it was a launcher with a user-specific path. It writes a synthetic
  project to `tempdir` and goes through the project, pairing review, the
  pipeline, the outputs, unit quality, a PSTH, response statistics and a
  population summary.
- `documentation/` is the one source of the wiki's prose pages.
  `tools/wiki/gen_pages.py` generates them from it, and `pages.json` maps
  each page to its file or sections. Links are rewritten to wiki pages, or
  to GitHub, and the script never runs git. Platforms is generated. The
  other 21 mapped pages are candidates until their wiki-only content is
  merged into `documentation/`: `--report` shows how far each one differs
  (`test_gen_pages.py`).
- The preprocessing app's Diagram pages are drawn by a plain class,
  `PipelineDiagram` (`detail`, `overview`, `zoomFrame`), which needs no app:
  `PipelineDiagram.overview(cfg, [])` writes a config's diagram from a
  script. The app's `flowChartHTML` / `flowOverviewHTML` call it; the code
  moved unchanged. The run monitor's log tail is `readNewLines`. Suite
  `test_ReadNewLines`.
- The Kilosort4 `.bin` keeps the recording's own resolution when it can:
  `EphysDataset.Scale` and `EphysProject.Scale` default to `NaN`, meaning
  `EphysDataset.binScale`, which uses 1 / the recording's µV per stored unit
  when every channel shares it and one stored unit maps onto one int16 unit
  (readers report their storage through `EphysReader.storageFormat`), else
  `1/0.195` as before. Intan and Open Ephys headstage data are unchanged
  (0.195 µV); a `recording.json` recording at another `gain_to_uV` is now
  written to the integer instead of re-quantised. `toBin` returns
  `scaleSource` and the sidecar records `scale_source`. Suite `test_BinScale`.
- The apps and the screenshot tools no longer call `getpref` / `setpref`
  directly. The test suites no longer back up, clear and restore your
  preferences; they never touch them.
- `test_BinaryReader` is a `matlab.unittest.TestCase` class (the pattern for
  new suites), with the same checks.
- `.gitignore` covers MATLAB backups and autosaves, test-runner output,
  `.claude/worktrees` and operating-system files.

### Fixed

- A run that launched background sorting runs wrote no run record (warning
  `EphysPipeline:RunRecord`, `Unrecognized field name "name"`): the record
  read each run's name from the wrong field. It now lists them under
  `backgroundRuns` as intended.
- Finding recordings (`EphysProject`, the app's Scan, `DatasetTracker`) and
  a dataset's outputs (`DatasetOutputs`) walk the folder tree once instead of
  once per file pattern, and skip hidden folders such as phy's `.phy`
  caches (`listTree`, `matchFiles`). On a network share holding sorted data
  the scan took minutes: `EphysProject` on a NAS folder of 7 datasets went
  from 125 s to 1.3 s, and `DatasetOutputs` of its sorted dataset from 92 s
  of folder walks to 4.3 s in all. A reader's `findRecordingFolders` takes that
  listing as a fourth input, `files`.
- The Review tab clears its folder field when the active dataset has no
  sorted output (or its pinned folder is not there), so **Load**, **Open
  folder in explorer** and **Open in phy** no longer bring back the
  previous dataset's sort.
- The Run tab's results table fills as the Run goes, one row per step and
  dataset, instead of staying empty until the Run ends; a row the Kilosort4
  monitor restates during the Run shows at once.
- A problem with the common reference colours the Artifacts tab even while
  automatic detection is off.
- `EphysProject.toBinAll` with options failed with "Too many input
  arguments" (its classdef declaration listed `opts` for a `varargin` file).
- A unit with no spike over a group's epochs has no auROC (NaN) and stays
  out of the 95% CI cutoff, as in `calculate_auROC.py`, instead of 0.5.
- A spike on a bin edge (within 1e-9 s) is always counted in the bin that
  starts there (`binCounts`); with spikes and events on one sample grid,
  rounding picked the bin. The auROC stop mask uses the same tolerance.
- The Run tab's Spikes box and the docs said the Spikes step writes
  "detected / sorted" spikes; it writes detections only. The probe tool's
  errors and two help lines still named a "Kilosort tab".
- Test fixtures no longer give extract `info` a `time` vector that real
  extracts do not have.

- `renderProbeMap` held a Latin-1 `µ` in its axis labels, which MATLAB
  reads as UTF-8. It is UTF-8 again.
- `EphysDataset.exportEpochs` no longer passes `Provenance` on to
  `eventEpochs`, which does not take it. Every epochs export given a
  provenance (the pipeline's Export step, generated scripts) failed with
  *Invalid argument name 'Provenance'*.
- The guard that stops `toBin` writing over a recording file now resolves
  `.` and `..` itself when MATLAB runs without Java.
- Visualize: spike ticks are drawn 2 points wide, edged in the plot's
  background colour and in front of the traces. Before, they were 1.2-point
  lines inside the trace's own band and hard to see on a dense trace.
  Stored waveforms in µV on their own lanes have a scale of their own
  (`EphysTraceViewer.RasterSpacing`, picked from the units' or channels'
  waveform peaks and given on the status line) instead of the traces'
  Spacing, which on a broadband trace can be many times a spike's
  amplitude and left the waveforms a few pixels tall.

## [0.1.0] - untagged

The code on `main` up to commit `75fa4e2` (2026-10-02), before releases were
tagged. Its history is in git and in the Done list of
[ephys_analysis-TODO.md](ephys_analysis-TODO.md).
