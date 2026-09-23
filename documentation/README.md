# Pipeline documentation

This folder is the reference for the code in [`pipeline`](../pipeline): a
config-driven preprocessing pipeline for extracellular recordings. It reads
recordings through an acquisition-agnostic reader layer (Intan RHD and Open
Ephys GUI sessions in its Binary, Open Ephys and NWB formats out of the box,
anything else through a universal binary format), screens them for
artifacts, sorts them with **Kilosort4** on a `.bin` (optional), derives LFP / MUA / spike-band signals, detects spikes and collects
sorted units, associates **Epsych2** behavior sessions, and exports files for
the **Chronux** and **FieldTrip** toolboxes. One JSON config drives the GUI,
the headless runner and generated scripts.

> Written 2026-09-11 and revised 2026-09-23 from the source in the working
> tree. When the code and these pages disagree, the code is authoritative.

The [`analysis`](../analysis) folder draws quick-look figures (PSTHs, evoked
potentials, rates, tuning curves, heatmaps, probe maps) and reports from the
pipeline's outputs, with its own config, runner, scripts and GUI. It depends
on `pipeline`; `pipeline` does not depend on it. See [Analysis](EphysAnalysis.md).

## Pages

| Page | Covers |
| --- | --- |
| [EphysPipeline](EphysPipeline.md) | `EphysPipelineConfig` (the config and its schema), `EphysPipeline` (plan / run / cancel; background Kilosort4 runs N at a time over the listed GPUs: `sortingSlot`, `waitForSortingSlot`), `EphysPipelineScript` (generated scripts), Epsych2 session readers |
| [EphysDataset](EphysDataset.md) | one recording: readers and the universal data struct, layouts, metadata, streaming, filtering, artifacts, spike detection, `.bin` writing, Kilosort4 runs, sorted-unit loader, derived signals, spikes file, exports, behavior, manifest |
| [EphysProject](EphysProject.md) | discovering many recordings, `refresh`, dataset keys, batch operations |
| [DatasetTracker](DatasetTracker.md) | read-only filesystem inventory (recordings, probe maps, `.bin` files, Kilosort4 runs) |
| [DatasetOutputs](DatasetOutputs.md) | one dataset's processed files (signals, spikes, behavior, exports, sorted units), found wherever they live and loaded on demand |
| [EphysPreprocessingApp](EphysPreprocessingApp.md) | the GUI, tab by tab, its config model and preferences |
| [Copying sessions](EphysPreprocessingApp.md#copy) | `findCopySessions`, `stitchCopySessions`, `copySessions`, `CopySchedule`: pairing recording folders (Intan RHX, Open Ephys GUI sessions) with ePsych files on the source and copying them to local session folders, by hand or on a schedule |
| [ProbeDesignerApp](ProbeDesignerApp.md) | building a Kilosort4 probe `.json` from probeinterface |
| [ManifestViewerApp](ManifestViewerApp.md) | viewing one dataset manifest, with its paths checked on disk |
| [intan2matlab](intan2matlab.md) | `intan2matlab` / `deriveSignals` / `toMat`: LFP, MUA, SPIKE and digital events |
| [ChronuxDataset](ChronuxDataset.md) | connector that hands recordings, trials and spike trains to the Chronux toolbox |
| [FieldTripExport](FieldTripExport.md) | FieldTrip raw / spike / event structures and `exportFieldTrip` |
| [Analysis](EphysAnalysis.md) | the `analysis` folder: event references, epochs, trial selection and grouping, PSTH / evoked / rate / tuning computations, renderers, export, HTML / PDF reports, `EphysAnalysisRunner`, `EphysAnalysisScript` |
| [EphysAnalysisConfig](EphysAnalysisConfig.md) | the analysis config (JSON `ephys-analysis-config`): every field, plot kinds, validation, tokens |
| [EphysAnalysisApp](EphysAnalysisApp.md) | the analysis GUI: Data, Alignment, Plots, Export and Log tabs, preferences, why a plot is skipped |
| [Python drivers](python-drivers.md) | `run_ks4.py`, `probe_tool.py` |
| [Files on disk](file-formats.md) | folder layout and every JSON / `.bin` / `.mat` schema |
| [Remote jobs](remote-jobs.md) | **design proposal, not implemented** — running the pipeline as queued jobs on a remote Windows machine, monitored from MATLAB or a browser |

Existing docs next to the code: [INSTALL.md](../pipeline/INSTALL.md) (Windows
setup, conda environments, GPU),
[probes/README.md](../pipeline/probes/README.md) (probe map format) and
[tools/wiki/README.md](../tools/wiki/README.md) (updating the GitHub wiki:
the API generator, the link check and the app screenshots).

## How the pieces fit

```mermaid
flowchart LR
    RAW(["Raw data"])
    RAW --- REC[("recording folder<br/>*.rhd, info.rhd + *.dat,<br/>Open Ephys Record Node,<br/>or recording.json + .bin")]
    RAW --- BEH[(Epsych2 session .mat)]

    REC -- digitalEvents --> EVT[("_events.mat<br/>digital-input events")]
    REC -- artifactIntervals --> ART[("_artifacts.json<br/>artifact intervals")]
    REC -- toBin --> BIN[(".bin<br/>Kilosort4 input")]
    REC -- toMat --> MAT[("_extract.mat<br/>LFP / MUA / SPIKE / AUX<br/>+ digital events")]
    REC -- spikesToMat --> SPK[("_spikes.mat<br/>detected + sorted spikes")]
    BEH -- behaviorToMat ----> BMAT[("_behavior.mat<br/>trials + pairing")]

    ART -. erased .-> BIN
    ART -. erased .-> MAT
    ART -. dropped .-> SPK
    BIN -- "Kilosort4<br/>run_ks4.py" --> KS[("kilosort4/<br/>phy files")]
    PRB[("probe .json<br/>ProbeDesignerApp")] -.-> KS
    KS -. readSortedUnits .-> SPK
    EVT -. pairTrials .-> BMAT

    subgraph EXP["exports"]
        CHX[(_chronux.mat)]
        FTX[(_fieldtrip.mat)]
        EPO[(_epochs.mat)]
    end
    MAT -- exportChronux --> CHX
    MAT -- exportFieldTrip --> FTX
    MAT -- exportEpochs --> EPO
    SPK & KS -.-> EXP
    BMAT -.-> EPO
    CHX -.-> CHRONUX[/Chronux/]
    FTX -.-> FIELDTRIP[/FieldTrip/]

    MAT -- EphysAnalysisRunner --> FIGS[("figures + reports<br/>.png / .svg / .eps / .pdf,<br/>HTML + PDF")]
    SPK & KS & BMAT -.-> FIGS
```

Each file hangs from the one it is made from, and the solid arrow names what
makes it (mostly an `EphysDataset` method); dashed arrows are further inputs.
Behavior pairing reads the cached digital events. The artifact periods are
erased in the `.bin` and, before any filter, in the data LFP / MUA / SPIKE are
derived from (`Signals.BlankArtifacts`, which also records them in
`_extract.mat`), and threshold detection drops spikes inside them. The exports
and the analysis take their signals, events and artifact periods from
`_extract.mat` (epochs that touch a period are dropped by default), detected
spikes from `_spikes.mat` and sorted units straight from `kilosort4/`; epochs and figures also read the
paired trials in `_behavior.mat`. The common reference (CAR / CMR), when set,
is subtracted as the recording is streamed, so artifact detection, the `.bin`
and threshold detection all see it.

The code that drives the tree: `EphysPreprocessingApp` or a generated
`EphysPipelineScript` sets up an `EphysPipelineConfig`, and `EphysPipeline`
runs its steps over an `EphysProject`, one `EphysDataset` per recording, read
through an `EphysReader` (`IntanReader` / `OpenEphysReader` / `BinaryReader`).
`readEpsychSession` reads the Epsych2 session, `intan2matlab` is a thin
wrapper around `deriveSignals` (what `toMat` saves), `exportChronux` packages
through `ChronuxDataset` and `exportFieldTrip` through `FieldTripExport`, and
`DatasetTracker` keeps the inventory of files on disk. Each dataset keeps its
state in `<Name>_manifest.json` (`writeManifest` / `applyManifest`), which
`ManifestViewerApp` shows (**Dataset → View manifest...**). Kilosort4
(`run_ks4.py`) and probeinterface (`probe_tool.py`, behind `ProbeDesignerApp`)
run in a conda Python through `system()`. On the analysis side,
`EphysAnalysisApp` or an `EphysAnalysisScript` sets up an
`EphysAnalysisConfig`, and `EphysAnalysisRunner` reads the processed files
through `DatasetOutputs`, never the recording.

**Steps** of a run, in order (each optional except the probe preflight):
`probe` → `behavior` → `artifacts` → `sorting` → `signals` → `spikes` →
`export`. See [EphysPipeline](EphysPipeline.md#run).

Sorting has one path: `EphysDataset.runKilosort` writes the recording to a
`.bin` (`toBin`, artifact periods erased) and runs Kilosort4 on it.

The artifact periods (the manual ones, plus the automatic detection per
`Artifacts.ApplyToSorting` / `ApplyToSignals` / `ApplyToSpikes`) reach three
steps: Sorting erases them in the `.bin`, Signals erases them in the amplifier
data before it derives LFP / MUA / SPIKE (`Signals.BlankArtifacts`; AUX and
the digital events are not touched), and Spikes rejects the events inside them
(`Spikes.RejectArtifacts`).

## Quick start

GUI:

```matlab
addpath_nogit('C:\src\ephys_analysis')   % once per session (see INSTALL.md)
EphysPreprocessingApp
```

Config + runner (what the GUI does):

```matlab
cfg = EphysPipelineConfig.load("D:\EPHYS\pipeline.json");   % File > Save config in the GUI
pipe = EphysPipeline(cfg);
disp(pipe.plan())
R = pipe.run();
```

One dataset by hand:

```matlab
ds = EphysDataset("D:\rec\subj1_day1");
ds.ProbeFile = "C:\src\ephys_analysis\pipeline\probes\H64LP_4x16lin_probemap.json";
ds.PythonExe = "C:\Users\me\miniconda3\envs\kilosort\python.exe";
res = ds.runKilosort();              % writes the .bin, blocks until Kilosort4 finishes
U   = ds.readSortedUnits();          % the sorted units (phy labels, times, channels)
out = ds.toMat(SignalOptions=struct('dataTypeOut', ["LFP" "MUA"]));
out = ds.spikesToMat(Source="both");
out = ds.exportChronux();  out = ds.exportFieldTrip();
E   = ds.eventEpochs(EventSource="behavior");   % the same data, one epoch per trial
out = ds.exportEpochs();                        % E, saved as _epochs.mat
```

Chronux spectra from the export (needs [Chronux](http://chronux.org) on the path):

```matlab
C = load("D:\out\subj1_day1\subj1_day1_chronux.mat");
[S, f] = mtspectrumc(C.LFP.data(:, 1), C.LFP.params);
```

## Conventions

### Supported recordings

| Reader | Layout | Files |
| --- | --- | --- |
| `IntanReader` | traditional | `*.rhd` with embedded data |
| `IntanReader` | one-file-per-signal | `info.rhd` + `amplifier.dat` |
| `IntanReader` | one-file-per-channel | `info.rhd` + `amp-*.dat` |
| `OpenEphysReader` | openephys-binary | an Open Ephys GUI session folder: `Record Node <id>/experiment*/recording*/structure.oebin` + `continuous.dat` |
| `OpenEphysReader` | openephys-legacy | `Record Node <id>/*.continuous` + `.events` (the Open Ephys format; GUI 0.4 / 0.5 names too) |
| `OpenEphysReader` | openephys-nwb | `Record Node <id>/experiment*.nwb` (NWB 2) |
| `BinaryReader` | binary (universal) | `recording.json` + one flat channel-major file |

All read identically through `streamPlan` / `readChunkUV` and return the same
in-memory struct. See
[EphysDataset → Acquisition readers](EphysDataset.md#acquisition-readers),
[Open Ephys sessions](EphysDataset.md#open-ephys-sessions) (recording modes,
record node / stream, TTL line names) and
[file-formats → recording.json](file-formats.md#universal-recording-format-recordingjson).

### Units

- Amplifier data is in **microvolts** everywhere in MATLAB.
- `toBin` multiplies by `Scale` (default `1/0.195`) to go back to int16 ADC
  counts. Out-of-range values are clipped, counted and warned about.

### Channel indexing

| Where | Base | Meaning |
| --- | --- | --- |
| MATLAB channel lists: `ExcludeChannels`, `KeepChannels`, `ChannelOrder`, config / GUI fields, `units.channel` | 1-based | amplifier channels in header order (= `.bin` rows) |
| `ChannelNumbers`, `units.channelNumber` | 0-based | hardware numbers (`A-012` → 12, Open Ephys `CH13` → 12); not `chanMap` values |
| Kilosort4 probe `chanMap` | 0-based | `.bin` rows: recording channel `c` sits at the site whose `chanMap` value is `c − 1`, for sorting, `readPhyUnits`, `channelLayout` (Artifacts tab) and the analysis probe maps |
| `units.ksChannel` | 1-based | among the **sorted** channels (after exclusions) |

Neither sorting nor the probe displays match probe sites to channels by their
hardware number: a recording with a channel disabled at acquisition needs a
probe that accounts for the gap; see
[Channel-numbering caveat](python-drivers.md#channel-numbering-caveat).

### Time and indexing conventions

- `readData`'s `t`, row k of a `deriveSignals` signal (at
  `(k − 1) / info.<type>.Fs`; the extracts carry no time vectors, only
  `info.<SIG>.nSamples`), spike times (`detectSpikes`, `readSortedUnits`:
  `samples / fs`) and manual artifact masks use **t = (row − 1) / Fs**.
- Digital-input event times (`readData`, `deriveSignals`, `intan2matlab`) use
  **t = row / Fs** (1-based row). They are therefore one sample later than `t`
  for the same row.
- A digital-event time `t = row / origFs` lies at `(row − 1) / origFs` on the
  continuous clock, so on any signal at `Fs` its row is
  `round((t − 1/origFs)·Fs) + 1`: that very row at the recording rate, the
  nearest sample of a derived signal. `ChronuxDataset.trials` (`OnsetRule`
  `"event"`), `eventEpochs` / `exportEpochs`, the pairing's
  `TrialOnsetSample_<SIG>`, FieldTrip `data_<SIG>.cfg.event`,
  `extract_trials` (`EventFs`) and the analysis module (`epochTable`'s
  `t0Continuous`, `evokedPotential`) all use it. Spikes are cut or binned
  around the event's recording row, `(row − 1) / origFs`, so a spike in the
  event's own sample is at 0 (`eventEpochs` spike epochs, `spikePSTH`,
  `firingRate`, `unitCorrelation`).
- `detectArtifacts` intervals are half-open on the continuous clock: the
  flagged rows a..b give `[a − 1, b) / Fs`, so a one-sample artifact is one
  sample long. An artifact period `[t0, t1)` erases exactly rows
  `round(t0·Fs) + 1` .. `round(t1·Fs)` at the recording rate
  (`EphysDataset.artifactSamples`), in the `.bin`, in the data the signals are
  derived from and in spike rejection alike.
- On a signal at any rate, the rows a period touches are those whose sample
  period `[(r − 1)/Fs, r/Fs)` overlaps it (`EphysDataset.intervalRows`), so a
  period shorter than one row of a derived signal still marks one (the
  FieldTrip `cfg.artfctdef.preprocessing.artifact` rows). An epoch touches a
  period when its closed window on the continuous clock, onset + `[tPre tPost]`
  with a digital-event onset moved to its recording row, overlaps it
  (`EphysDataset.overlapsIntervals`: `t0 <= tStop` and `t1 > tStart`).
- Manual artifact periods and `artifactIntervals` output are
  **recording-relative** seconds (the first sample of the first file is t = 0).
- FieldTrip `event.sample` is, at the recording rate, the row itself; spike
  `timestamp` = the 0-based sorted sample; both share the recording clock
  through `hdr.TimeStampPerSample`.

### Source data is read-only

No class modifies recording files. Sorting never modifies the probe `.json` it
uses: channel exclusions go through a derived probe. Artifacts are erased in
the written `.bin` and in the in-memory copy the derived signals are computed
from (a straight line across each period), never in the source. In the `.bin`,
by default (`ArtifactConfig.Fill`) each period becomes a straight line between the signal's level on either side
plus per-channel Gaussian noise at the recording's own level, because a sorter
reads a block of zeros across every channel as a signal discontinuity, and a
fill off the local level would leave a step at each edge that a sorter's
high-pass turns into spike-like transients. `toBin` and `matrixToBin` refuse a
`.bin` or sidecar path that is one of the recording's own files, and `BinFile`
is `<Name>_ks4.bin` when the recording's own data file is `<Name>.bin`
(universal format). Probe files are changed
only by explicit GUI actions: editing a Notes cell, a Designer save, or an
Import that you confirm should overwrite. The files written **into the raw
folder** are `<Name>_manifest.json` and, for Open Ephys sessions in
`"separate"` mode, the part folders (`openephys-part.json`); everything else
goes to the output folder (`<OutputRoot>/<Name>`, or the recording folder when
no output root is set).

## Known behaviors and caveats

Collected from the code. Each is explained on the linked page.

| Topic | Behavior | Page |
| --- | --- | --- |
| Artifacts tab threshold | the GUI always sends the Threshold field; changing Method swaps it for the new method's default while it still holds the old one's (a hand-typed value stays, so 9 under *Absolute microvolts* / *Common-mode* means 9 µV); `validate` warns when such a threshold is below 50 µV | [App → Artifacts](EphysPreprocessingApp.md#artifacts) |
| Visualize overlay | orange is the Artifacts tab's Detect / Preview of the plotted dataset, shown only while its detection settings still hold; a run's cached detection is not shown | [App → Visualize](EphysPreprocessingApp.md#visualize) |
| Visualize decimation | each point is a bin's peak drawn at the bin's start, so displayed time is exact to within one bin, with no drift | [App → Visualize](EphysPreprocessingApp.md#visualize) |
| Visualize reading | **Plot** streams the whole recording whatever window is shown, so on a slow disk a long recording takes minutes | [App → Visualize](EphysPreprocessingApp.md#visualize) |
| Sorted-output association | a hand-picked folder is restored on rescan as recorded, even while it is not there; the steps that read sorted units then report it missing (`error: sorting folder missing`) instead of using another sort | [EphysDataset → Sorted output](EphysDataset.md#sorted-output) |
| Sorted waveforms | `templateWaveform` is Kilosort4's template (its mean of the unit's spikes in the whitened, high-passed data), unwhitened with `whitening_mat_inv.npy` (transposed), in µV when the run's `settings.json` has `bin_scale` (`runKilosort` writes it), else in `.bin` units (`units.templateUnits` says which); it is not scaled by the amplitude and not a raw-spike average; raw waveforms at sorted spike times are not extracted | [EphysDataset → Reading sorted units](EphysDataset.md#reading-sorted-units) |
| Review firing rates | spike count ÷ the sorted time, from Kilosort4's `tmin` to `min(tmax, recording end)`; the time of the last spike only when the recording's length is unknown | [App → Review](EphysPreprocessingApp.md#review) |
| Epsych2 trials | paired **in order** with the intervals of the trial line, not by timestamps (`pairEpsychTrials` / `ds.pairTrials`, the behavior step's `PairTrials`, the Trials tab), and reviewed before approval (`setTrialPairing`, `autoApproveTrialPairing`); the pairing goes into `<Name>_behavior.mat` and the behavior-sourced epochs | [EphysPipeline → Pairing trials](EphysPipeline.md#pairing-trials-with-the-trial-line) |
| Background sorting + dependent steps | a background sorting run cannot feed `Spikes` (sorted) or `Export` (units) in the same run; `validate` reports it | [EphysPipeline → Validation](EphysPipeline.md#validation) |
| Duplicate dataset names | two recordings with the same leaf name under one `Project.OutputRoot` share `<OutputRoot>/<Name>`: `plan()` refuses either one (`error: output folder shared with <key>`), even when only one is selected; same-name files in a shared step `OutputDir` are `duplicate output`; `DatasetOutputs` and the clean-up ignore another recording's files by their recorded source folder. Rename one folder, or leave `OutputRoot` empty | [EphysPipeline → Dataset keys](EphysPipeline.md#dataset-keys) |
| Probe mapping | `chanMap` indexes `.bin` rows, not hardware channel numbers; a recording with a channel disabled at acquisition needs a probe that accounts for the gap | [Python drivers](python-drivers.md#channel-numbering-caveat) |
| Open Ephys TTL lines at a recording start | a line already high when a recording starts is seen from Binary always, from NWB when that recording has any TTL edge, and from the Open Ephys format only when its first edge there is falling; intervals are split at recording boundaries | [EphysDataset → Open Ephys sessions](EphysDataset.md#open-ephys-sessions) |
| Open Ephys samples | rows are the stored samples (dropped samples are not zero-filled; a warning lists them); the Open Ephys format zero-pads each recording's last record, as the GUI writes it | [EphysDataset → Open Ephys sessions](EphysDataset.md#open-ephys-sessions) |
| Open Ephys AUX | stored as (raw − 32768) × 37.4 µV: 1.2255 V below Intan RHX's volts for the same accelerometer | [EphysDataset → Open Ephys sessions](EphysDataset.md#open-ephys-sessions) |
| Background runs | at most `Sorting.MaxConcurrent` (default 1) at a time, so the run stays busy until the last dataset has started, unless the Run tab's **Queue the waiting runs** hands the rest to the monitor; automatic artifact detection runs synchronously in MATLAB before each launch (then cached); closing the app does not stop running Python processes (the Run tab's **Stop runs...** does), but drops the queued ones; a background launch goes through `<runDir>\ks4_launch.cmd`, so paths with `&` or `^` work, and a launch that fails writes the exit marker and errors | [App → Run](EphysPreprocessingApp.md#run) |
| Derived-signal bad channels | interpolated from the probe geometry (the 1/distance-weighted mean of the 4 nearest good sites on the same shank; in a pipeline run, a dataset without a probe of its own uses the default probe); without a probe, or for a site off the probe or with no good site on its shank, across the neighbouring **columns** (`makima`), with a warning | [intan2matlab](intan2matlab.md#processing-order) |
| Chronux `createdatamatc` | the connector puts a dig-in onset on the signal sample nearest its recording row (exact at the recording rate, within half a sample at a derived rate); Chronux's own `createdatamatc` anchors on `floor(t·Fs) + 1` and drops the window's last sample, so handed dig-in times it lands `1/origFs` late. Use `cx.trials`, or pass `t − 1/origFs` | [ChronuxDataset](ChronuxDataset.md#trial-sample-alignment) |
| Chronux point-process grid | left to itself `mtspectrumpt` normalizes by the span of the spikes, not the recording; pass the `t` the connector returns | [ChronuxDataset](ChronuxDataset.md#why-t-matters-for-point-processes) |
| MATLAB version | the Visualize tab uses `xregion` (R2023a+); the code is developed on R2025a | [INSTALL.md](../pipeline/INSTALL.md) |
| Parallel steps | the worker count is capped by free memory (4-5 on a 32 GB machine), not by the pool size; every worker reads the disk, so on a slow external disk a parallel step can be no faster than serial; the results are identical either way | [EphysPipeline → Parallel execution](EphysPipeline.md#parallel-execution) |

## Dependencies

**MATLAB**:

- Signal Processing Toolbox (required for filtering, resampling and derived
  signals).
- Statistics and Machine Learning Toolbox (only for `zscore` in automatic
  derived-signal bad-channel detection).
- Parallel Computing Toolbox (optional; `Parallel.Enabled` in a pipeline
  config, or `UseParallel=true` on `detectSpikes`, `artifactIntervals` and
  `analyzeArtifacts`).
- No Report Generator: the analysis module's PDF reports are built with
  `exportgraphics(..., Append=true)` and its HTML reports by hand.

**Functions from elsewhere in this repository**:

| Function | Used by |
| --- | --- |
| [`read_Intan_RHD2000_file_modified`](../pipeline/read_Intan_RHD2000_file_modified.m) | `IntanReader`, traditional `*.rhd` |
| [`matrix2kilosort`](../matrix2kilosort.m) | `EphysDataset.matrixToBin` |
| [`MultiChannelViewer`](../vendor/plotting/@MultiChannelViewer/MultiChannelViewer.m) | GUI Visualize tab |
| [`Manifest`](../vendor/tools/Manifest.m) | optional provenance log |
| [`parfor_progress`](../vendor/compute/parfor_progress.m) | `intan2matlab` console progress |
| [`addpath_nogit`](../addpath_nogit.m) | path setup |

**Python**: a conda environment with kilosort, probeinterface and torch, plus
an optional separate `phy` environment. Needed only for
the sorting step and the probe designer. See [INSTALL.md](../pipeline/INSTALL.md)
for known-good versions.

**Optional MATLAB toolboxes**: [Chronux](http://chronux.org) (bundled in
[`toolboxes/chronux`](../toolboxes/chronux); add it with `addpath(genpath(...))`)
and [FieldTrip](https://www.fieldtriptoolbox.org/), each only for analysing the
files the pipeline exports for it. Producing the files never calls either
toolbox; `ChronuxDataset.hasChronux` / `FieldTripExport.hasFieldTrip` report
whether they are on the path, and the FieldTrip export validates its
structures with `ft_datatype_*` when FieldTrip is present.

## Tests

Every suite is a function-style script that builds synthetic fixtures in a
temp folder (shared builders in [`pipeline/private`](../pipeline/private)), prints
PASS / FAIL lines and errors when anything fails. No real recordings, no
Python and no optional toolbox are needed.

For trying the pipeline or the app by hand without real data,
[`makeSyntheticProject`](../pipeline/makeSyntheticProject.m) (or the app's
**File → Create synthetic test project...**) writes a realistic project:
recordings with spiking units, LFP, artifacts, the lab's six digital lines
and accelerometer inputs, an Epsych2 session per recording, ground-truth
sorted output and a ready pipeline config. See
[EphysPreprocessingApp → Synthetic test project](EphysPreprocessingApp.md#synthetic-test-project).
To shape the data yourself, the app's **Synthetic** tab (or
[`SyntheticDesign`](../pipeline/SyntheticDesign.m) with
[`makeSyntheticRecording`](../pipeline/makeSyntheticRecording.m)) links units and
LFP oscillations or evoked potentials to the events of the built-in task or
of a real Epsych2 session ([`syntheticSessionSchedule`](../pipeline/syntheticSessionSchedule.m));
see [EphysPreprocessingApp → Synthetic](EphysPreprocessingApp.md#synthetic).

```matlab
cd C:\src\ephys_analysis\pipeline
run_all_tests            % every test_*.m; errors if any fails
test_EphysPipeline       % one suite
```

| Suite | Covers |
| --- | --- |
| `test_EphysDataset` | readers, layouts, streaming, artifacts, spikes, `.bin`, dry runs, manifest v2, sorted units, `spikesToMat`, exports, behavior |
| `test_IntanReader` | the Intan reader: every data-block and on-disk layout, truncated last blocks, window reads across files, `readDigitalEvents` without the amplifier data, the run helpers, one-file-per-channel digital files, the recording start (`AcqDate`), `streamPlan` chunks, `KeepChannels` / `Precision` |
| `test_BinaryReader` | the universal binary reader: `readDigitalEvents` from `dig_in_file` alone, `readData`, `Files` listing `dig_in_file`, `streamPlan` |
| `test_SortedUnits` | `readPhyUnits`' label tables, template units and per-unit grouping; `channelLayout` (`chanMap` values are `.bin` rows); `runKilosort(DryRun=true)` leaving an existing run alone |
| `test_DeriveSignals` | derived signals: bad channels as columns (the config's recording channels mapped to them), interpolated from the probe geometry or, without one, across columns; automatic detection; the MUA / SPIKE filters in double; non-integer rates; `info.<type>.nSamples`; line naming and polarity from `TrialConfig`; artifact periods erased before deriving (the line fill, `info.artifacts`, no filter ringing outside the period, AUX untouched) |
| `test_OpenEphysReader` | Open Ephys sessions (Binary, Open Ephys format, NWB): metadata, samples across recordings and gaps, TTL lines, AUX / ADC, discovery, record node / stream, the recording modes, line names, the pipeline on a synthetic Open Ephys project |
| `test_EphysProject` (in `test_EphysDataset` §7 / §15) | discovery, keys, `refresh` |
| `test_DatasetTracker` | the filesystem inventory |
| `test_ChronuxDataset` | the Chronux connector |
| `test_FieldTripExport` | the FieldTrip structures, the artifact matrix |
| `test_EventEpochs` | the event-organized export: sample alignment, spike windows, the trials table, the behavior source, the epoch settings, epochs touching an artifact period |
| `test_EpsychSession` | Epsych2 readers and matching |
| `test_EphysPipelineConfig`, `test_EphysPipeline`, `test_EphysPipelineScript` | config, runner, scripts |
| `test_EphysPreprocessingApp` | the GUI's config model, headless |
| `test_ManifestViewerApp` | the manifest viewer, headless: the Summary checks, opening from a file, a folder or a dataset, the plots, the default probe, Rewrite |
| `test_SyntheticDataset` | `makeSyntheticProject` / `makeSyntheticRecording`: the written lines, sessions, spikes, aux and artifacts read back; pairing per scenario; the other layouts (Open Ephys included); the config through the pipeline; the app's File-menu action |
| `test_SyntheticGenerator` | `SyntheticDesign` (validation, JSON), the built-in model, responses and LFP at their latency after the edge, `PreviewOnly` = what is written, schedules from a dataset's Epsych2 session (recorded lines, rebuilt lines, tuning, locked vs induced oscillations, `MaxDuration`), the app's Synthetic tab |
| `test_EphysAnalysisCompute` (analysis/) | compute functions on seeded spike trains and signals, the trial-filter compiler, every renderer |
| `test_EphysAnalysisEpochs` (analysis/) | sources, event references, epochs, trial selection and grouping against the synthetic truth |
| `test_EphysAnalysisConfig` (analysis/) | the analysis config: JSON round trips, `plotFor`, validation |
| `test_EphysAnalysisRunner` (analysis/) | plan, run, exports, HTML / PDF reports, cancel, compact vs standalone script equivalence |
| `test_EphysAnalysisApp` (analysis/) | the analysis GUI, headless |
