# Changelog

Notable changes to this repository. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and version numbers
follow [Semantic Versioning](https://semver.org/). The current number is in
[`VERSION`](VERSION); [README.md](README.md#versions-license-and-citation)
says how to cut a release.

## [Unreleased]

### Added

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
  the exporters carry the metrics (`UnitQuality`, `Export.UnitQuality`, on by
  default; a failure is a warning). Review tab: QC, ISIv, Pres, Cutoff and SNR
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
- `stringifyNonFinite` (moved out of `writeJsonFile`), `provenanceForJson`;
  suite `test_Provenance`.

### Changed

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

- The guard that stops `toBin` writing over a recording file now resolves
  `.` and `..` itself when MATLAB runs without Java.

## [0.1.0] - untagged

The code on `main` up to commit `75fa4e2` (2026-10-02), before releases were
tagged. Its history is in git and in the Done list of
[ephys_analysis-TODO.md](ephys_analysis-TODO.md).
