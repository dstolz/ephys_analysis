# EphysPipelineConfig, EphysPipeline, EphysPipelineScript

Three classes make a preprocessing run reproducible outside the GUI:

| Class | Kind | Role |
| --- | --- | --- |
| [`EphysPipelineConfig`](../pipeline/@EphysPipelineConfig/EphysPipelineConfig.m) | value | every setting of every step, which steps are enabled, the project root / output root and the dataset selection; round-trips through JSON exactly |
| [`EphysPipeline`](../pipeline/@EphysPipeline/EphysPipeline.m) | handle | runs a config over an [`EphysProject`](EphysProject.md): plan, validate, run, cancel, progress, results |
| [`EphysPipelineScript`](../pipeline/@EphysPipelineScript/EphysPipelineScript.m) | static | writes MATLAB scripts that reproduce a config's run, with or without the two classes above |

The GUI ([`EphysPipelineApp`](EphysPipelineApp.md)) edits one config
and runs it through the same `EphysPipeline`, so a run from the app, from a
saved config, or from a generated script does the same thing.

Per-dataset state (probe, channel exclusions, manual artifact periods, the
sorted-output folder, the Epsych2 session) is **not** in the config. It lives in
each dataset's manifest ([file-formats.md](file-formats.md#dataset-manifest))
and is restored by `EphysProject.refresh()` before a run.

```matlab
cfg = EphysPipelineConfig();
cfg.Name = "LFP + spikes";
cfg.Project.Root = "D:\EPHYS\subj1";
cfg.Project.OutputRoot = "D:\EPHYS\subj1_out";
cfg.Signals.Enabled = true;                  % LFP .mat per dataset
cfg.Spikes.Enabled = true;                   % threshold-detected spikes
cfg.Export.Enabled = true;  cfg.Export.Formats = ["chronux" "fieldtrip" "epochs"];
cfg = cfg.save("D:\EPHYS\subj1\pipeline.json");

pipe = EphysPipeline(cfg);                   % scans Root, restores manifests
disp(pipe.plan())                            % what would run; writes nothing
R = pipe.run();                              % every enabled step, in order
```

---

## EphysPipelineConfig

### Sections

One struct property per section. Assigning a section normalizes it: missing
fields take their defaults, values are coerced to the type and shape of the
default (`"Inf"` → `Inf`, a one-element list read from JSON → string array),
and unknown fields are dropped with a warning. `EphysPipelineConfig.defaults(section)`
returns the defaults and is the single source of truth for field names.

| Section | Step | Holds |
| --- | --- | --- |
| `Project` | – | `Root`, `Recursive` (`true`: search every sub-folder of `Root` for recordings; `false`: only `Root` and the folders directly in it), `OutputRoot` (`""` = outputs next to each recording), `Selection` (`"all"` or `"list"`), `Datasets` (root-relative keys, see [Dataset keys](#dataset-keys)), `NamePattern` (`"{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}"`, see [Dataset name tokens](#dataset-name-tokens); also labels sorted units, see [Unit labels](#unit-labels)), `TokenColumns` (list text, `"SubjectID"`: tokens shown as app table columns), `SaveScript` (`true`: each run saves its standalone script as `<Root>/pipeline_<name>.m`, see [Run](#run)) |
| `Acquisition` | – | reader options, see [Acquisition](#acquisition): `OpenEphys.Recordings` (`"concatenate"`), `OpenEphys.RecordNode` (`""`), `OpenEphys.Stream` (`""`), `TDT.Stream` (`""`), `TDT.GainToMicrovolts` (`NaN`) |
| `Parallel` | – | `Enabled` (run the chunks of the artifacts and spike-detection steps on a process pool), `MaxWorkers` (`NaN` = automatic; always capped by free memory); see [Parallel execution](#parallel-execution) |
| `Probe` | `probe` (always runs) | `DefaultProbeFile` (used for datasets without a probe of their own: for sorting, to place the derived signals' bad channels, and for the app's Artifacts lanes), `WriteDefaultToManifest` (`true`: also assign it to them and save it to their manifests), `AutoAssign` with `RuleSubjects` / `RuleProbes` (probe rules: the first subject pattern matching a dataset's `SubjectID` gives it that probe file; with `AutoAssign` the probe check assigns it and saves it to the manifest, before the default is used) |
| `Behavior` | `behavior` | `Enabled`, `Search` (`true`; `false`: no search or matching, only the sessions already associated), `SearchDirs`, `Match` (`"prefix"`, `"time"`, `"prefix-then-time"`), `MaxStartOffsetMin` (30), `Overwrite`, `WriteFile` (`true`: write `<Name>_behavior.mat` for every associated dataset), `PairTrials` (`true`), `AutoApprove` (`false`: approve a pairing whose trial and interval counts match without cuts), `TrialLine` (`"InTrial"`) |
| `Artifacts` | `artifacts` | `Reference` (`"none"`, `"car"` or `"cmr"`: the common reference every step subtracts once from its read of the recording: detection, sorting (Kilosort4's own `do_CAR` is then off), spike detection and the derived signals of `Signals.<TYPE>_Reference`), `ReferenceBadLow`, `ReferenceBadHigh` (the noise band, as a multiple of the median, outside which a channel is suggested to stay out of the reference), `Enabled` (automatic detection; manual periods always apply), `Method`, `Threshold`, `RmsWindowMs`, `MergeGapMs`, `MinChannels`, `PadMs`, `Filter`, `FilterType`, `FilterCutoff` (a scalar, or `[lo hi]` for a band-pass), `FilterOrder`, `Fill` (`"noise"` or `"zero"`: what replaces the artifact samples), `NoiseBandHz`, `NoiseSeed`, `ApplyToSorting`, `ApplyToSpikes`, `ApplyToSignals` (whether the automatic detections reach those steps; manual periods always do), `CacheIntervals` |
| `Sorting` | `sorting` | `Enabled`, `PythonExe`, `CondaEnv`, `Execution` (`"background"` or `"blocking"`), `MaxConcurrent` (background runs at once, default 1; see [Background Kilosort4 runs](#background-kilosort4-runs)), `Devices` (torch devices shared out among the runs, e.g. `["cuda:0" "cuda:1"]`; empty = Kilosort4's choice), `DryRun`, `SkipExisting`, `KS4` (one typed field per `kilosortParamSpec` entry), `KS4ExtraJSON`; `Quality`: good-unit criteria on the units' quality metrics ([`unitQualityCriteria`](../pipeline/unitQualityCriteria.m): `isiViolationsRatioMax` 0.5, `presenceRatioMin` 0.9, `amplitudeCutoffMax` 0.1, the rest off), which the app's Review tab and QC report apply ([Unit quality metrics](EphysDataset.md#unit-quality-metrics)) |
| `Signals` | `signals` | `Enabled`, `OutputDir`, `Suffix` (`"_extract"`), `SeparateFiles` (`true`: `<Name><Suffix>_<TYPE>.mat` per signal type), `MatVersion`, `Overwrite`, `LFP` / `MUA` / `SPIKE`, `LFP_Reference` / `MUA_Reference` / `SPIKE_Reference` (`false` / `true` / `true`: which signals the common reference of `Artifacts.Reference` is subtracted from; the LFP is taken as recorded by default), `BlankArtifacts` (`true`: erase the dataset's artifact periods, a straight line across each, before any signal is derived, and record them in every file as `info.artifacts`; `false`: the recording as it is, no periods recorded), `LFP_Fs`, `LFP_HighpassOn/Hz`, `LFP_LowpassOn/Hz`, `LFP_NotchOn/Hz/BW`, `MUA_Fs`, `MUA_IntegrationHz`, `MUA_bpLoHi`, `SPIKE_KeepOriginal`, `SPIKE_Fs`, `SPIKE_bpLoHi`, `LabelField` (`"custom"` or `"native"`: which name labels channels, aux inputs and digital lines), `LineNames` (`"native=name"` entries naming digital lines, e.g. `"TTL4=InTrial"`; see [line names](#digital-line-names)), `InvertedLines` (digital lines with inverted polarity: onset = falling edge; see [polarity](#digital-line-polarity)), `KeepChannels`, `BadMode`, `BadThreshold`, `BadList` (recording channels, like `KeepChannels`), `ChannelRemap`, `ExcludeHandling` (`"none"`, `"drop"`, `"interpolate"`: what to do with the manifest's excluded channels) |
| `Spikes` | `spikes` | `Enabled`, the `detectSpikes` options (`Filter`, `Band`, `FilterOrder`, `Polarity`, `ThresholdMethod`, `Threshold` (`NaN` = the method's default), `ThresholdScope` (`"chunk"`: each chunk's noise; `"recording"`: each channel's noise over the whole recording, measured by a first pass; see [detectSpikes](EphysDataset.md#whole-recording-mode)), `Align`, `AlignWindowMs`, `MinPeriodMs`, `MaxAmplitudeUV`, `Waveforms`, `WindowMs`, `WaveformSource`, `EdgeHandling`, `MaxChunkSamples`, `EdgePadMs`), `Channels` (`"all"`, `"excludeManifest"`, `"list"`) + `ChannelList`, `ArtifactMode` (`"reject"`: drop the events inside the artifact periods; `"erase"`: erase the periods before detection, which then runs on the cleaned recording; `"none"`: ignore them), `OutputDir`, `Suffix` (`"_spikes"`), `MatVersion`, `Overwrite` |
| `Export` | `export` | `Enabled`, `Formats` (subset of `["chronux" "fieldtrip" "epochs" "kcsd" "nwb"]`; `kcsd` needs the LFP and a probe; `nwb` a Python with pynwb and nwbinspector), `Signals` (`[]` = every signal in the extract), `IncludeUnits`, `IncludeDetected`, `IncludeEvents`, `Groups`, `Validate`, the epoch settings `EpochSource` (`"line"` / `"behavior"`), `EpochLine`, `EpochWindow` (`[tPre tPost]` s), `EpochOnsetRule` (`"event"`, the default: digital-input times, each placed on every signal's sample nearest its recording row, `round((t − 1/origFs)·Fs) + 1`; `"sample"`: times on the continuous clock, `round(t·Fs) + 1`), `EpochIncomplete`, `EpochNonFinite`, `EpochArtifacts` (`"drop"`: an epoch whose window touches an artifact period of the extract is left out of the signals; `"keep"`: flagged only), `EpochSpikeTimeBase`, `EpochClass`, `OutputDir`, `MatVersion`, `Overwrite`; `UnitQuality` (`true`): the exported units carry their quality metrics (`EphysDataset.unitQuality`; a sort whose metrics cannot be computed is exported without them, with a warning); `NWB`: the `nwb` format's metadata (`SessionDescription`, `ExperimentDescription`, `Experimenter`, `Lab`, `Institution`, `Keywords`, `Location`, `SubjectId`, `Species`, `Sex`, `Age`, `SubjectDescription`, `Strain`, `Genotype`, `TimeZone`, `SessionStartTime`; `""` is not written), `Trials`, `Inspect` and the Python that writes it (`PythonExe`, `CondaEnv`; `""` = the Sorting step's). `validate` checks the Python, `Sex`, `Age` (ISO 8601), `TimeZone` and `SessionStartTime`, and warns when species, sex or age is not set |
| `Analysis` | `analysis` | `Enabled`, `ConfigFile` (an [analysis config](EphysAnalysisConfig.md), `.json`, read when the step runs), `Figures` (`true`: write the figure files), `Report` (`true`: write the report). The step runs the analysis config over the selected datasets, not over its own `Source`; where and how the figures and the report are written is the analysis config's `Export` / `Report` (their own `Enabled` is not used). See [Analysis step](#analysis-step) |

`Name` and `Description` are free text. `File` (where the config was loaded
from or saved to) and `LoadWarnings` are transient.

Channel lists (`KeepChannels`, `BadList`, `ChannelRemap`, `ChannelList`) and the
notch list are kept as typed text and parsed when a run starts
(`parseOrderedList`, `parseFreqList`: order and repeats are kept, anything
unparseable is an error). `KeepChannels`, `BadList`, `Spikes.ChannelList` and
the manifest exclusions are recording channels (1-based, in header order);
`ChannelRemap` indexes the kept channels. `signalOptions` maps `BadList` and
the `"interpolate"` exclusions to columns of the kept data, which is what
`deriveSignals` takes, and drops the channels that are not kept.

### Acquisition

Reader options, pushed to every dataset as `ReaderOptions` and used by
`EphysProject.discover`. Each reader reads its own sub-struct.

| Field | Default | Meaning |
| --- | --- | --- |
| `OpenEphys.Recordings` | `"concatenate"` | an Open Ephys session with several recordings is one dataset (`"concatenate"`), one dataset per recording in part folders (`"separate"`), or refused (`"single"`); see [Open Ephys sessions](EphysDataset.md#open-ephys-sessions) |
| `OpenEphys.RecordNode` | `""` | Record Node id to read; `""` = the only one (the lowest id, with a warning, when there are several) |
| `OpenEphys.Stream` | `""` | continuous stream to read, by name; `""` = the stream with the most headstage channels |
| `TDT.Stream` | `""` | TDT stream store read as the amplifier channels (`"Wav1"`); `""` = the stream with the most channels, the highest rate among those (a warning when several have that many channels); see [TDT Synapse blocks](EphysDataset.md#tdt-synapse-blocks) |
| `TDT.GainToMicrovolts` | `NaN` | microvolts per stored unit; `NaN` = 1e6 for float streams (TDT stores them in volts); required for a stream stored as integers |

`validate()` checks the mode, that `RecordNode` is blank or digits, and that
`TDT.GainToMicrovolts` is `NaN` or positive. The
section decides which folders are datasets (in `"separate"` mode), so changing
it needs a rescan; the app rescans on every change.

### JSON

`cfg.save(file)` / `EphysPipelineConfig.load(file)`; the on-disk schema is in
[file-formats.md](file-formats.md#pipeline-config-json). `Inf`, `NaN` and empty
values round-trip exactly (`isequaln(load(save(cfg)), cfg)`), and so does a
band-pass `Artifacts.FilterCutoff` (`[lo hi]`, a row where the default is a
scalar). A file with
another `schema` or a newer `version` raises `EphysPipelineConfig:BadSchema`;
there is no migration. Unknown fields are dropped and listed in
`LoadWarnings`.

### Validation

`issues = cfg.validate()` returns a table (`Step`, `Field`, `Severity`,
`Message`). `Project`, `Acquisition`, `Parallel` and `Probe` are always checked; a step section only when
it is enabled (`Signals.LabelField` and `Signals.LineNames` also when
`Behavior` is, since they name the trial line). Severity `"error"` stops `run()`. Cross-step rule: a background
sorting run cannot feed the sorted-unit consumers (`Export.IncludeUnits`, and
an enabled plot of sorted units in the Analysis step's config) in
the same run; set `Sorting.Execution = "blocking"` or run Export and Analysis later. When
that consumer is on, `Project.NamePattern` must be able to label units (a
`SubjectID` token and `Date` / `Time` tokens with datetime formats); otherwise
it is an error. With `Artifacts.Enabled` and `Method` `"microvolts"` or
`"commonmode"`, a `Threshold` below 50 µV is a warning: a robust-SD multiplier
(the `rms` / `mad` default, 9) read as microvolts sits inside the noise and
flags almost every sample.

The `Parallel` checks: `MaxWorkers` must be `NaN` or a whole number ≥ 1
(error); `Enabled` without a licensed Parallel Computing Toolbox is a warning
(the steps run serially). With sorting enabled, `Sorting.MaxConcurrent` must
be a whole number ≥ 1 (error), and each of `Sorting.Devices` must be a torch
device, `cpu`, `mps`, `cuda` or `cuda:N` (error). More devices than
`MaxConcurrent`, several devices with blocking runs (only the first is used)
and `Devices` next to a `torch_device` in `KS4ExtraJSON` (`Devices` wins) are
warnings.

The `Analysis` checks, with the step enabled: no `ConfigFile` is an error.
With `CheckPaths` (the default), the file is read too: a file that is not
there, is not an analysis config, or cannot be read because the analysis
module is not on the path is an error. The analysis config's own
`validate()` issues, its `Source` aside (the step replaces it), become rows
of step `analysis` with `Field` `<Section>.<Field>` of the analysis config
(`Plots.psth_1.window`, ...), and so do its load warnings. Without
`CheckPaths` the file is not read. Writing neither the figures nor the
report, and the Signals step off, are warnings.

### Helpers

| Static | Returns |
| --- | --- |
| `defaults(section)`, `normalizeSection(section, s)` | defaults; a normalized copy |
| `artifactConfig(A)` | the `EphysDataset.ArtifactConfig` struct for an `Artifacts` section |
| `detectOptions(K, P)` | `detectSpikes` name-value options for a `Spikes` section; with a `Parallel` section `P`, its `UseParallel` / `MaxWorkers` too |
| `parallelOptions(P)` | `UseParallel` / `MaxWorkers` name-value options for a `Parallel` section (`MaxWorkers` omitted when `NaN`) |
| `spikeChannels(K, ds)` | the channel list for a dataset (`"all"`, `"excludeManifest"`, `"list"`) |
| `signalOptions(S, ExcludeChannels=, NumChannels=)` | `deriveSignals` options for a `Signals` section, with the exclude handling applied (error IDs `EphysPipelineConfig:Signals*`) |
| `exportOptions(E, fmt)` | name-value options shared by `exportChronux` / `exportFieldTrip` / `exportEpochs`, plus `Validate` for `"fieldtrip"` and, for `"epochs"`, the `Epoch*` settings under `eventEpochs`' names (`EpochArtifacts` → `Artifacts`, ...); for `"kcsd"` only `Events` and `Overwrite` (the caller adds the dataset's `ProbeFile`); for `"nwb"` the shared ones without `Detected` / `MatVersion`, plus `Trials`, `Inspect`, `PythonExe`, `CondaEnv` and `Metadata` (the rest of `Export.NWB`) |
| `ks4Settings(S)` | the Kilosort4 settings struct (blank / `Inf` fields omitted, `KS4ExtraJSON` merged last) |
| `outputSearchDirs(cfg)` | the `Signals` / `Spikes` / `Export` `OutputDir` settings that are not blank, once each: where `outputsFor` and the Analysis step also look for a dataset's outputs |
| `analysisSource(cfg, keys)` | the analysis config `Source` the Analysis step runs with: `Mode` `"project"` on this config's `Root`, `OutputRoot`, `NamePattern` and Open Ephys recording mode, `Selection` `"list"` of the dataset `keys` |
| `[acfg, msg] = loadAnalysisConfig(file)` | the Analysis step's `EphysAnalysisConfig` (load warnings kept on `acfg.LoadWarnings`), or `[]` and why not: no file chosen, the file is not there, the analysis module is not on the path, or it is not an analysis config |
| `[S, report] = ks4ForProbe(S, probeFile)` | `S` with the Kilosort4 parameters listed in the probe's parameter file ([`<probe>.ks4.json`](file-formats.md#kilosort4-probe-parameters-probeks4json)) set; the others and `KS4ExtraJSON` kept. `report`: `File`, `Description`, `Changes` (a table with one row per parameter: old, new, changed, the file's reason) and `Notes` (extra-JSON overrides). Errors `EphysPipelineConfig:NoProbeParams`, `:BadParams`, `:BadValue` |
| `file = writeKS4Params(probeFile, values, Description=, Reasons=, Overwrite=)` | writes a struct of typed Kilosort4 parameters as the probe's parameter file. Errors `EphysPipelineConfig:ParamsExist`, `:BadParams` |
| `[values, report] = ks4ProbeDefaults(probe, ExcludeChannels=)` | good defaults for `KS4ProbeParams` derived from a probe `.json` file or struct ([rules](EphysPipelineApp.md#optimize-for-probe)). `report`: `Probe`, `Summary`, `Geometry` (sites, shanks, row / lateral / nearest-contact spacing, width, span), `Reasons` (per parameter) and `Notes`. Errors `EphysPipelineConfig:BadProbe`, `:ProbeEmpty` |
| `ks4ParamsFile(probeFile)` | the probe's parameter file path, `<folder>/<probe>.ks4.json` |
| `ks4ParamText`, `ks4ParamFromText`, `kilosortParamSpec` | the typed Kilosort4 parameter spec and its text form (used by the GUI); `ks4ParamText` writes each number in the shortest form that reads back as the same double, so a value round-trips exactly |
| `validateSuffix(s)` | rejects `\ / : * ? " < > \|` |
| `datasetKey(root, folder)` | root-relative key with forward slashes |

Instance: `stepSection(step)`, `stepEnabled(step)`, `enabledSteps()`,
`isequalConfig(other)`, `toStruct()`, `fromStruct(s)`.

Constants for probe parameter files: `KS4ProbeParams` (the probe-dependent
parameters: `nblocks`, `dmin`, `dminx`, `nearest_chans`, `nearest_templates`,
`min_template_size`, `x_centers`), `KS4ParamsSuffix` (`".ks4.json"`),
`KS4ParamsSchema` (`"ephys-ks4-params/1"`).

### Dataset keys

Dataset names are folder leaves and are not unique (`mouse1/sess1` and
`mouse2/sess1`). The config's `Project.Datasets` therefore holds
**root-relative keys** with forward slashes (`"mouse1/sess1"`), and
`EphysProject.datasetKey(i)` / `findByKey(key)` map between them and datasets.
`plan()` compares the output folders and files of the selected datasets with
those of every dataset in the project, selected or not, from names and
folders alone. Two recordings with the same name under one
`Project.OutputRoot` share `<OutputRoot>/<Name>`, where each would read or
overwrite the other's outputs, so the rows of either are
`error: output folder shared with <key>`: rename one recording folder, or
leave `OutputRoot` empty (outputs next to each recording). A file two datasets
would both write (the same name in a configured step `OutputDir`) is
`duplicate output`. Both stop the run.

### Dataset name tokens

`Project.NamePattern` describes how a dataset name splits into tokens;
`[values, names, ok, formats] = parseNameTokens(name, pattern)` applies it (the
whole name must match; `ok` is false and `values` are `""` otherwise;
`formats` holds each token's datetime format, `""` for free text and regex
tokens).

| In the pattern | Matches |
| --- | --- |
| `{Token}` | any text, as short as possible |
| `{Token:yyMMdd}` | a format made only of `y M d H h m s`: that many digits |
| `{Token:yyyy-MM-dd}` | runs of those letters joined by separators (any characters other than letters and digits): the digits per run, the separators literally |
| `{Token:regex}` | any other format is a regular expression |
| `*` | any text that is not kept (e.g. a trailing suffix) |
| other text | itself (e.g. the `_` separators) |

The default `"{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}"` splits
`SUBJ-ID-1245_260916_143015` into `SubjectID = "SUBJ-ID-1245"`,
`Date = "260916"`, `Time = "143015"`. Fixed text belongs in the pattern as
literal text: `"SUBJ-ID-{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}"` gives
`SubjectID = "1245"` for the same name, which is what the lab configs in
`pipeline/pipeline_configs` use. Open Ephys session folders
(`SUBJ-ID-1219_2026-07-07_16-35-39_active`) match
`OpenEphysReader.DefaultNamePattern`,
`"{SubjectID}_{Date:yyyy-MM-dd}_{Time:HH-mm-ss}*"` (the `*` takes the GUI's
appended text). Token names must be unique valid
identifiers; `validate()` reports an invalid pattern as an error and a
`TokenColumns` entry missing from the pattern as a warning.

### Unit labels

The `SubjectID`, `Date` and `Time` tokens label every sorted unit, so a unit
leads back to its recording wherever it ends up:

| Label part | Example | From |
| --- | --- | --- |
| class + cluster id (at least 3 digits) | `su042` | phy label (`good` → `su`, `mua`, `noise`, `unsorted` → `uns`, else `other`) and `spike_clusters.npy` |
| subject | `1255` | `SubjectID` token |
| recording start, to the minute | `260908T1039` | `Date` + `Time` tokens |

`su042_1255_260908T1039` splits with `split(labels, "_")` and filters with
`startsWith(labels, "su")`. The `units` struct carries the same facts as
columns (`class`, `subject`, `recordingStart` to the second, `datasetKey` =
root-relative folder), with the unit's location (`channel`, `channelName`,
`ksChannel`, `shank`, peak site `peakX` / `peakY`, template centre `x` / `y`)
and `notes` (see [Reading sorted units](EphysDataset.md#reading-sorted-units)).
A unit is identified by `datasetKey` + `unitId`.

- **Names that do not match.** A dataset whose name gives no subject and start
  cannot label units. Its export rows (`IncludeUnits`) plan as
  `error: unit identity`, and
  `ds.readSortedUnits()` throws `EphysDataset:unitIdentity:*`.
- **Collisions.** Two recordings of one subject starting in the same minute
  would share labels. `T = P.unitIdentities(Among=idx, NamePattern="")` lists
  each dataset's `Subject`, `RecordingStart`, `LabelSuffix` and `Status`
  (`ok`, `pattern`, `nomatch`, `subject`, `datetime` or `collision`). `plan()`
  checks the selected datasets plus every dataset that is already sorted and
  marks the unit rows `error: unit label collision`.
- **Tables.** [`T = unitTable(units)`](../pipeline/unitTable.m) takes `units`
  structs or `<Name>_chronux.mat` files and returns one
  row per unit (`label`, `class`, `subject`, `recordingStart`, `datasetKey`,
  `unitId`, `group`, `channel`, `channelName`, `ksChannel`, `shank`, `peakX`,
  `peakY`, `x`, `y`, `notes`, `nSpikes`, `amplitude`, `contamPct`, `curated`,
  `fs`, `resultsDir`, `times`). Notes are re-read from each sort folder when it
  is reachable (`RefreshNotes=true`). The same unit twice is an error
  (`unitTable:DuplicateUnit`); a shared label is a warning
  (`unitTable:DuplicateLabel`).

```matlab
f  = dir("D:\out\**\*_chronux.mat");
T  = unitTable(string(fullfile({f.folder}, {f.name})));
su = T(T.class == "su" & T.subject == "1255" & T.shank == 2, :);
```

---

## EphysPipeline

### Construction

```matlab
pipe = EphysPipeline(cfg)                         % EphysProject(cfg.Project.Root, ...) + refresh() of the selected datasets
pipe = EphysPipeline(cfg, Project=P)              % reuse a project (the GUI's)
pipe = EphysPipeline(cfg, Project=P, Refresh=false)
```

Construction always calls `EphysPipeline.applyConfigToDatasets(cfg, P)`
(pushes `PythonExe`, `CondaEnv`, `ArtifactConfig`, `TrialConfig`,
`ReaderOptions`, `OutputDir` (`<OutputRoot>/<Name>`, or `""` without an output
root), `NamePattern` and `DatasetKey` into every dataset; never touches
`ProbeFile`, `SortingDir` or `BehaviorFile`)
and `selectDatasets()`. Assigning a new `Config` does both again. Only the
selected datasets are then refreshed (`EphysProject.refresh(Datasets=)`:
headers and manifests); `Refresh=false` skips that.
`EphysPipeline:NoRoot` when the root does not exist.

### Properties

| Property | Meaning |
| --- | --- |
| `Config`, `Project` | the config and the project it runs on |
| `DatasetIdx` | indices of the selected datasets (`Selection = "all"` → all) |
| `ProgressFcn` | `ProgressFcn(evt)`, `evt` = `step`, `dataset`, `index`, `count`, `done`, `total`, `message` (see [Progress events](#progress-events)) |
| `LogFcn` | one line per event (default `fprintf`) |
| `CancelRequested` | set by `cancel()` |
| `Results` | table `Step`, `Dataset`, `Status`, `Message`, `Output`, `Seconds`, one row per step × dataset |
| `LaunchedRuns` | background Kilosort4 runs (`Name`, `statusFile`, `resultsDir` (the run's kilosort4 folder, which identifies the dataset), `logFile`, `logPos`, `done`, `device`, `started` (`NaT` while queued), `queued`; `EphysPipeline.emptyRuns()`), the shape the app's monitor consumes. `EphysPipeline.sortRun(name, res)` builds one from a `launchSorting` result; `sortRun(name, res, Queued=true)` one for a prepared run waiting in a queue |
| `LaunchFcn` | `LaunchFcn(run)` is called with each background run (a `LaunchedRuns` element) as soon as it starts (default none) |
| `PriorRuns` | background runs started elsewhere, in `LaunchedRuns`' shape, queued ones included; while they are running they take slots of `Sorting.MaxConcurrent` (queued ones do not), and their `device` counts when GPUs are shared out. A dataset with a run here or in `LaunchedRuns` that is queued or still going is not sorted again (`activeRun`) |
| `QueueFcn` | `QueueFcn(d, res)`: when set, background runs are not started by the step but handed over prepared ([below](#background-kilosort4-runs)); default none |
| `SortingWaiting` | how many datasets the sorting step has still to start (or, with `QueueFcn`, to hand over) |
| `RunRecordFile`, `ScriptFile` | the run record and the pipeline script the last `run()` wrote (`""` when none) |

### Plan

`T = pipe.plan()` (or `plan(Steps=...)`) returns a table (`Step`, `Dataset`,
`Key`, `Output`, `Status`, `Note`) and writes nothing.

| Status | Meaning |
| --- | --- |
| `ready` | will run |
| `ok` / `associated` | the probe (the dataset's own, else `Probe.DefaultProbeFile`: `probeFor`) fits / behavior file already associated |
| `behavior file missing` | the associated session file is not there (a disk or share not connected); the association is kept, and nothing is paired or written |
| `exists: skip`, `exists: overwrite` | the output file exists; `Overwrite` decides |
| `exists: skip (SkipExisting)`, `exists: will re-sort` | sorted output exists |
| `skip: Kilosort4 queued`, `skip: Kilosort4 running` | a Kilosort4 run for this dataset waits in a queue or is going (`PriorRuns`, `LaunchedRuns`) |
| `no recording files` | the folder holds no readable recording |
| `no probe`, `probe file missing`, `probe-channel mismatch` | probe preflight; the sorting row is `no probe` or `probe file missing` too |
| `no extract file` | export needs the Signals output (the files of `Export.Signals` only: `exportExtractFiles`) |
| `duplicate output` | another dataset of the project, selected or not, writes the same file (the same name in a configured step `OutputDir`) |
| `error: output folder shared with <key>` | another dataset of the project has the same name, so both would use `<OutputRoot>/<Name>` (see [Dataset keys](#dataset-keys)) |
| `error: sorting folder missing` | the step reads sorted units but the dataset's hand-picked sorted-output folder (`SortingDir`) is not there; a sort is never read from anywhere else |
| `error: unit identity` | the step reads sorted units but the name gives no subject and start (see [Unit labels](#unit-labels)) |
| `error: unit label collision` | another selected or sorted dataset has the same subject and start minute |
| `error: ...` | a setting cannot apply (for example `LFP_Fs` above the recording rate) |
| `error: analysis config` | the Analysis step's config cannot be loaded (`Note` says why) |
| `error: figure folder`, `error: report folder` | an analysis config's folder pattern cannot be filled for this dataset |

The Analysis step has one row per dataset and enabled plot (`analysis:<plot
id>`, `Output` the figure folder, `""` without `Analysis.Figures`) and one
per report (`analysis:report`, `Output` its file(s); `Dataset` and `Key` `""`
for one report over every dataset): `pipe.analysisTargets(acfg, idx)`. Which
plots a dataset can have is known only when it runs. Its folders and its
report are shared by design, so they are not `duplicate output`.

The probe row's status is the probe step's own (`EphysPipeline.probeStatus`).
Rows whose status starts with `duplicate` or `error` stop `run()`
(`EphysPipeline:PlanInvalid`); a config with validation errors stops it before
that (`EphysPipeline:ConfigInvalid`). `T = pipe.checkRun(Steps=)` makes these
checks (it validates, logs the warnings, plans, and raises either error) and
returns the plan; `run()` calls it, and a script that calls the step methods
one by one calls it first.

### Run

`R = pipe.run(Steps=[], DryRun=false)` validates, plans (`checkRun`), then runs each enabled
step in `EphysPipelineConfig.StepNames` order. With `DryRun=true` every step
runs with `DryRun`: nothing is written (no manifest, cache, behavior or
output file), no artifact detection streams the recording, and each step
records `dry run` rows saying what it would do; the sorting step writes only
its `settings.json` and `run_ks4.py`, into `kilosort4\dryrun`.

**Provenance.** Every file a run writes records the code version (the
release, the git commit and whether the checkout had uncommitted changes),
MATLAB, host, user, the config and the run's id: `pipe.provenance()`, passed
to each writer as `Provenance=` and stored in the file's `conversion` /
`export` struct or JSON ([format](file-formats.md#provenance)). When the run
ends (finished, cancelled or failed; not a dry run) it writes a run record,
`<OutputRoot or Root>/pipeline_runs/<runId>_<name>.json`, with the steps,
datasets, config, code, machine and every Results row
([format](file-formats.md#run-records)); `pipe.RunRecordFile` names it and
the log ends with `Run record: <file>`. A step method called on its own
records the config but no run id, and writes no record.

**Pipeline script.** With `Project.SaveScript` on (the default), the run
first saves the config's standalone script
([`EphysPipelineScript.standalone`](#ephyspipelinescript): every setting
written out, no config file needed) as `<Root>/pipeline_<name>.m`, the config
name made a MATLAB name (`EphysPipeline.scriptFileFor`). It holds what the
run used whether or not the config was saved. Its header names the run
(`% Saved by EphysPipeline.run, run <runId>`, the id in every output and the
run record) and, when the run ran only some steps, which; the script itself
runs the config's enabled steps. Each run replaces the script the previous
run saved, so copy it to keep edits; a file of that name that no run saved is
left as it is (warning `EphysPipeline:ScriptExists`; a saved script has a
`% Saved by EphysPipeline` line in its header). `pipe.ScriptFile` names
the file (`""` when nothing was saved), the run record's `script` field too,
and the log says `Pipeline script: <file>`. A dry run saves none; a script
that cannot be written is a warning (`EphysPipeline:Script`) and the run goes
on. `pipe.writeScript()` saves it on its own (its header then says
`% Saved by EphysPipeline.writeScript, outside a run`).

| Step | Method | Does |
| --- | --- | --- |
| `probe` | `checkProbes()` | checks each dataset's probe (`probeFor`: its own, else `Probe.DefaultProbeFile`, read at each call) against its channel count. With `AutoAssign`, a dataset without a probe first takes that of the first matching probe rule, assigned and saved to its manifest (a dry run saves nothing; a missing rule file is reported, not saved). The default is assigned to a dataset, and saved to its manifest, only with `WriteDefaultToManifest`; otherwise it is only used |
| `behavior` | `checkBehavior()` | for datasets without a `BehaviorFile` (or all with `Overwrite`) runs `findEpsychSessions` over `SearchDirs` and `matchEpsychSession`; sets `BehaviorFile`, writes the manifest; reports unmatched and ambiguous datasets. With `Search` off, no folder is searched and nothing is matched: only datasets that already have a `BehaviorFile` (associated by hand, or the session file in the recording folder) are paired and written, and the others are reported `no session`. An associated session is kept unless `Overwrite`, also while its file is not there (`behavior file missing`: nothing is paired or written). With `WriteFile`, every dataset that ends up associated (matched or kept) gets `behaviorToMat` → `<outputFolder>/<Name>_behavior.mat`, rewritten each run (result step `behavior:file`). With `PairTrials`, trials are first paired with the `TrialLine` intervals (`EphysDataset.pairTrials`, result step `behavior:pairing`): a recorded pairing that still matches is reused (`approved`, `auto-approved` or `needs review`); with `AutoApprove`, a pairing whose counts match without cuts is approved (`auto-approved`, `EphysDataset.autoApproveTrialPairing`); anything else is recorded in the manifest as unreviewed (`needs review`, or `count mismatch`); `no trial line` when the recording has no such line. The pairing columns go into the behavior file |
| `artifacts` | `runArtifacts()` | computes `artifactIntervals()` per dataset and caches them (see below) |
| `sorting` | `runSorting()` | `runKilosort(ProbeFile=probeFor(d), ExtraSettings=ks4Settings, ArtifactIntervals=, DryRun=, Launch=false)` (writes the `.bin` with the artifact periods erased; a dry run writes only `settings.json` and `run_ks4.py`, into `kilosort4\dryrun`, and detects nothing), then `launchSorting(res, Wait=, Device=)` and `writeManifest`. Background runs go at most `Sorting.MaxConcurrent` at a time, spread over `Sorting.Devices` ([below](#background-kilosort4-runs)), and are listed in `LaunchedRuns` with status `launched`; with `QueueFcn` set they are handed over with status `queued`. Skipped: a dataset with a Kilosort4 run queued or still going (`activeRun`), so its `.bin` is never rewritten under a running sort; one without a probe or whose probe file is not there; with `SkipExisting`, one already sorted (also when its hand-picked sorted-output folder is not there now). A cancel stops the datasets not started yet; a run already launched, queued or finished keeps its row |
| `signals` | `runSignals()` | `toMat(File=, SeparateFiles=, SignalOptions=, MatVersion=, Overwrite=, ProgressFcn=)` with the configured exclude handling. `SignalOptions.referenceSignals` lists the computed signals whose `<TYPE>_Reference` is on; with `Artifacts.Reference` set, the log says `common CAR reference over N channel(s), subtracted from MUA, SPIKE` and a dry run `MUA+SPIKE CAR referenced`. When bad channels are to be interpolated (`BadList`, or the manifest exclusions with `ExcludeHandling = "interpolate"`), `SignalOptions.probeFile` is `probeFor(d)`: the dataset's own probe, else `Probe.DefaultProbeFile`, whose geometry places them. With `Signals.BlankArtifacts`, the dataset's artifact periods (`artifactIntervalsForStep(d, Artifacts.ApplyToSignals, ...)`, as Sorting and Spikes take them) go in as `SignalOptions.artifactIntervals` and are erased before any signal is derived; the log says `N artifact period(s) erased before deriving (<source>, <samples> samples)` and each result message ends `, N artifact period(s) erased`. A dry run says `artifact periods erased (manual + automatic)` or `(manual)` |
| `spikes` | `runSpikeDetection()` | `spikesToMat(DetectOptions=, Channels=, ArtifactMode=, ArtifactIntervals=, ...)`: threshold detection only; the sorted units stay in the sorting folder (with `ArtifactMode` `"erase"` the result message ends `, N artifact period(s) erased before detection`) |
| `export` | `runExport()` | per format `exportChronux(...)` / `exportFieldTrip(...)` / `exportEpochs(...)` / `exportKCSD(...)`, with units, detected spikes and events as configured. A dataset's inputs are read once for all its formats and passed to each (`Sources` names the files): the extract files of `Export.Signals` (per-type files of other signals are not read), the sorted units and the spikes file; `plan()` and `runExport` find the extract files by the same rule (`exportExtractFiles`). With `IncludeUnits`, a dataset whose hand-picked sorted-output folder is not there is skipped. The `epochs` format organizes the same data by event — one epoch per digital pulse (`EpochSource = "line"`) or per paired trial (`"behavior"`, which also carries the session's trial columns) — over `EpochWindow` ([`EphysDataset.eventEpochs`](EphysDataset.md#event-organized-epoched-data)); when epochs touch an artifact period of the extract, its result message adds `, N touch an artifact period (left out of the signals)` (`EpochArtifacts = "drop"`) or `(kept, flagged)`. The `kcsd` format writes `<Name>_kcsd.npz` for [kCSD-python](https://github.com/Neuroinflab/kCSD-python): the LFP alone, on the probe `probeFor` gives, with interpolated bad channels left out ([schema](file-formats.md#kcsd-export-ephysdatasetexportkcsd-the-export-step)); units, detected spikes and a missing sorted-output folder do not concern it, and `plan()` marks a dataset with no probe (`error: no probe`) or an offline one (`error: probe file missing`). Its result message is `LFP; N electrode(s) in D-D, M channel(s) left out; K event(s)`. The `nwb` format writes `<Name>.nwb` ([EphysDataset.exportNWB](EphysDataset.md#neurodata-without-borders-nwb)) with the probe `probeFor` gives, the trials of the behavior step's file, `Export.NWB`'s metadata and its Python (else the Sorting step's); its result message counts the electrodes, units, trials and lines and nwbinspector's findings (`..., N critical or above`). With `UnitQuality`, the units read once for every format carry their quality metrics, as when an exporter is called on its own |
| `analysis` | `runAnalysis()` | runs the analysis config `Analysis.ConfigFile` with [`EphysAnalysisRunner`](EphysAnalysis.md) over the selected datasets; see [Analysis step](#analysis-step) |

Each step method can be called directly; it then runs even when the step is
disabled in the config. Call `checkRun()` first for the checks `run()` makes;
each step method takes `Datasets=` (indices) and `DryRun=true`. Result statuses are `done`, `skipped`, `dry run`,
`launched`, `queued`, `error`, `cancelled` and `not run`. Errors on one dataset are
recorded and the run continues with the next. Work that ends after its step
has returned (a background Kilosort4 run) can restate its row with
`pipe.updateResult(step, dataset, output, status, message, addSeconds)`; the
static `EphysPipeline.restateResult(T, ...)` does the same to any results
table.

Helpers: `f = pipe.probeFor(d)` is the probe file a dataset is sorted with,
and whose geometry places its bad channels in the signals step (its own, else
with `Probe.AutoAssign` the first matching probe rule, else
`Probe.DefaultProbeFile`, read at each call; `""` for none; the second output
says which: `"own"`, `"rule"`, `"default"`, `""`);
`[probe, k] = EphysPipeline.probeRule(d, subjects, probes)` the probe of the
first rule whose subject pattern (`*` and `?`, not case sensitive; `*` matches
every dataset) matches the `SubjectID` of `d`'s name, and its index (`""`, 0 for
none); `T = EphysPipeline.assignProbeRules(datasets, subjects, probes)` sets
`ProbeFile` on the datasets without one that match a rule and saves their
manifests (`Overwrite=true` also replaces a dataset's own probe, `DryRun=true`
changes nothing; a rule whose probe file is missing is skipped);
`[st, note] = EphysPipeline.probeStatus(probe, d)` how that probe fits the
dataset (`ok`, `no probe`, `probe file missing`, `probe-channel mismatch`);
`run = pipe.activeRun(d)` a Kilosort4 run of the dataset in `PriorRuns` or
`LaunchedRuns` that is queued or still going (`[]` when none); and
`f = pipe.exportExtractFiles(d)` the extract files the Export step reads (with
`Signals.SeparateFiles` and a non-empty `Export.Signals`, only those signal
types' files).

**Artifact cache.** `artifactIntervalsFor(d)` returns the intervals for a
dataset: manual periods always, automatic detections when `Artifacts.Enabled`.
Automatic detection streams the whole recording, so its result - the
automatic detection alone - is cached in
`<outputFolder>/<Name>_artifacts.json` (schema in
[file-formats.md](file-formats.md#artifact-cache)), keyed by a fingerprint of
what decides it: the detector settings, the channels of the common reference,
`ExcludeChannels` and the recording files. A cache with a different
fingerprint is recomputed. The bounds moved by hand on the Artifacts tab
(`d.ArtifactAdjustments`, applied with `EphysDataset.adjustArtifacts`) and the
manual periods are applied on every call, so moving a bound or marking a
period needs no new detection; the cache keeps the detection as found. A detection is also kept for the rest of
the run (`reused`), so the steps that need it detect once even with
`CacheIntervals` off. `ApplyToSorting` / `ApplyToSpikes` / `ApplyToSignals`
decide whether the automatic detections reach those steps (manual periods
always do): each step calls `[iv, source] = artifactIntervalsForStep(d,
applyAuto, report)`, which is `artifactIntervalsFor(d, report)` when
`applyAuto` and the manual periods alone (`source` `"manual"`) otherwise.
Sorting erases the periods in its `.bin`, Signals (with
`Signals.BlankArtifacts`) in the amplifier data before it derives LFP / MUA /
SPIKE, and Spikes erases them before detection (`Spikes.ArtifactMode`
`"erase"`) or rejects the events inside them (`"reject"`).

**Cancel.** `pipe.cancel()` makes the next progress notification throw
`EphysPipeline:Cancelled`. The current dataset is marked `cancelled` (its
output is written atomically, so nothing half-done is left behind), the
remaining rows are `not run`, and `run()` returns normally.

### Analysis step

`runAnalysis` loads the analysis config when the step runs
(`analysisConfig`: `loadAnalysisConfig`, then `Source` =
`analysisSource(cfg, keys)` of the selected datasets), so what the
[analysis app](EphysAnalysisApp.md) saved last is what runs. An
`EphysAnalysisRunner` scans the project root again, keeps those keys and also
looks for each dataset's outputs in `outputSearchDirs`. Each dataset's
outputs are read first (`loadAnalysisSource`): one that cannot be read, or a
key the scan does not find, is an `analysis` row with status `error`, and
the others still run. `run(Export=Analysis.Figures,
Report=Analysis.Report)` then draws every enabled plot on every dataset:

- one row per dataset and plot, step `analysis:<plot id>`: `done` (`Output`
  the files written), `skipped` (`Message`: why the dataset cannot have it,
  `plotSkipReason`), `error` or `cancelled`;
- with `Report`, one `analysis:report` row per report: `Dataset` `""` for one
  report over every dataset, else the dataset (`Report.PerDataset`). After a
  cancel, the report over every dataset is not written (`cancelled`).

The runner also writes its own run record,
`<report folder>/analysis_runs/<runId>_<name>.json`. A dry run reads the
analysis config and lists `analysisTargets` as `dry run` rows; it draws and
writes nothing. The step needs the repository's `analysis` folder on the
path; the rest of the pipeline never does.

### Background Kilosort4 runs

With `Sorting.Execution = "background"`, at most `Sorting.MaxConcurrent`
(default 1) Kilosort4 processes run at once, so a batch does not overload the
GPU. For each dataset, `runSorting` writes the run files first
(`Launch=false`): the `.bin` and `settings.json`. Then it waits until a slot is free and starts the run
with [`launchSorting`](EphysDataset.md#running-kilosort4). The next dataset's
files are therefore ready while the current runs sort. A slot frees when a
run's `ks4_status.json` says it is done or failed, or its process has exited
without writing one
([`EphysDataset.sortRunState`](EphysDataset.md#running-kilosort4)). Runs listed
in `PriorRuns` take slots too (queued ones do not); the app passes the runs it
is still following, and a dataset with a run there that is queued or going is
skipped. While it waits, the step reports `waiting for a free Kilosort4
slot (N at a time): R running, F finished, W still to start`, and `cancel()`
stops the wait. The dataset it was waiting to start and the rest are marked
`cancelled`, and runs already started carry on. The step returns once the
last dataset has started, so a later step in the same run overlaps only the
last runs. Blocking runs always go one at a time.

**GPUs.** `Sorting.Devices` lists torch devices to share out, such as
`["cuda:0" "cuda:1"]`. Each background run gets the device the fewest
running runs use, the first listed on a tie, so two runs at once on a
two-GPU machine get one GPU each. The device goes to the driver as
`--device` and overrides a `torch_device` in `KS4ExtraJSON`. Blocking runs
use the first device. Empty (the default) leaves the choice to Kilosort4,
which takes the first GPU. With more devices than `MaxConcurrent`, the
extra ones stay idle, and validation warns.

**Queued.** With `QueueFcn` set, `runSorting` starts no background run
itself and never waits for a slot. It writes each dataset's run files, calls
`QueueFcn(d, res)` with the prepared result, and records the row as `queued`.
The owner of `QueueFcn` starts each run later with
`d.launchSorting(res, Wait=false, Device=...)` when a slot frees, and can
restate the row with `updateResult`. The step returns once the last
dataset's files are written, so the steps after it start at once. The app
uses this for its **Queue the waiting runs** option.

`EphysDataset.stopSortRun(statusFile)` stops a background run that is going:
its status becomes `"cancelled"` and its slot frees.

`[free, device] = sortingSlot(runs, maxRunning, devices)` checks for a slot
without waiting (`runs` is a struct array with `statusFile` and `device`,
such as `LaunchedRuns` or `launchSorting` results). `device =
waitForSortingSlot(runs, maxRunning, Devices=...)` waits for one. The
standalone script uses them the same way:

```matlab
launched = [];
for d = datasets
    res = d.runKilosort(ExtraSettings=ks4, Launch=false);   % the run files
    device = waitForSortingSlot(launched, 2, Devices=["cuda:0" "cuda:1"]);
    res = d.launchSorting(res, Wait=false, Device=device);
    launched = [launched, res];
end
```

### Progress events

`ProgressFcn(evt)` is called with a struct:

| Field | Meaning |
| --- | --- |
| `step` | the step name (`probe` ... `analysis`, as in `StepNames`) |
| `dataset` | the dataset's name; `""` when the step is starting |
| `index`, `count` | the dataset's place in the step's selection; `index` is 0 when the step is starting |
| `done`, `total` | how far that dataset is (`done / total`, 0 to 1) |
| `message` | what is being done (`starting`, `detecting: <file>`, `fieldtrip: exporting`, ...) |

A step is therefore `(max(index, 1) - 1 + done / total) / count` done, and
that fraction only grows while the step runs. `run()` sends one event with
`dataset = ""`, `index = 0` and `message = "starting"` as each step starts,
so every step is seen to begin, including those that report nothing else;
after `cancel()` it sends none, and the step records its datasets as
`cancelled` instead. Every step also reports each dataset as it begins it.
Artifact detection that Sorting, Signals or Spikes needs (no valid cache)
reports as that step: it fills the first half of the dataset's share, and the
sort, the derivation or the spike detection the second. Export reports as `export`, the formats
sharing each dataset's share (the result rows stay `export:<format>`). Analysis reports as `analysis`:
reading the config and each dataset's outputs at 0, then the plots
sharing each dataset's share (`plot <id>`). A
direct `artifactIntervalsFor(d)` reports as `artifacts`, dataset 1 of 1; its
optional third argument `report(done, total, message)` sends the detection's
progress elsewhere.

### Parallel execution

With `Parallel.Enabled`, the two steps that stream the recording chunk by
chunk — `artifacts` (`artifactIntervals`) and detection in `spikes`
(`detectSpikes`) — process their chunks on a **process pool**: the open pool
when there is one, otherwise a pool started with as many workers as the cap
below. The signals, sorting and export steps are unaffected: signals holds the
whole recording in memory and its filters are already multithreaded, sorting is
an external Python process, export is file bound. An artifact detection that
Sorting or Signals runs for want of a cached one goes through the same
`artifactIntervals` call, and so uses the pool. A step's result is
**identical** with and without the pool, so the artifact cache is shared
between modes and a spikes file differs only in `detection.options.UseParallel`.

The number of chunks in flight is derived from memory in one place
(`parallelChunkPool`): each chunk costs about five (artifacts) or six (spikes)
copies of one double-precision chunk, and the cap is
`floor((available − reserve) / perChunk)`, then `min` with `MaxWorkers` and the
pool size, with `reserve = max(2 GB, 10 %)` kept for the client. On a 32 GB
machine with 60-second, 64-channel files that is four or five workers whatever
the pool size. Progress is reported on the client as chunks finish, so the bars
behave as in a serial run, and **Cancel** takes effect after the chunk in
flight: the outstanding chunks are cancelled and nothing is written. When the
pool cannot be used — no Parallel Computing Toolbox, a chunk whose sample count
is unknown, a thread pool open instead of a process pool, memory for fewer than
two workers, or `MaxWorkers` 1 — the step runs serially and warns
`EphysDataset:<method>:SerialFallback` with the reason. The pipeline never
deletes a pool.

What to expect: each chunk is read by its worker, so several workers read the
disk at once. On an internal SSD the steps scale with the worker cap; on a slow
external disk concurrent reads can be no faster than one, so compare the
`Seconds` column of `Results` before relying on it. The spike detector's
workers read the context before their chunk as one short window
(`readWindowUV`, which every built-in reader supports), not the whole
preceding file; only a `Files` list that skips or reorders files makes them
read the previous listed chunk.

---

## EphysPipelineScript

```matlab
txt = EphysPipelineScript.compact(cfg, ConfigFile="D:\EPHYS\pipeline.json", File="run_subj1.m");
txt = EphysPipelineScript.standalone(cfg, File="run_subj1_standalone.m");
```

| Form | Contents |
| --- | --- |
| `compact` | loads the JSON config, builds an `EphysPipeline`, calls `checkRun()` (`run()`'s checks: a config error or a blocking plan row stops the script) and prints the plan, then one `pipe.<step>()` line per step. Disabled steps are written commented out. Override hints for the output root, the selection, the execution mode and the background runs at once are included as comments. Keep the config file next to it |
| `standalone` | every parameter written out as MATLAB literals, in `%%` sections; builds `EphysProject`, selects datasets by key, `refresh()`es them, pushes `ArtifactConfig` and `TrialConfig` onto them, and calls `artifactIntervals`, `runKilosort`, `toMat`, `spikesToMat`, the exporters and the Epsych2 functions directly. Each step does what the runner's does: the behavior step pairs and approves trials as `checkBehavior` does, the default probe is used without being assigned (unless `WriteDefaultToManifest`), for sorting and to place the derived signals' bad channels, and each dataset's export inputs are read once (only the extract files of `Export.Signals`) and passed to every format with their `Sources`. The Analysis step carries the analysis config as its JSON (as it was when the script was written; when it cannot be read then, the script loads the file), points it at the datasets above and runs `EphysAnalysisRunner`, leaving out a dataset whose outputs cannot be read. The runner's cache of artifact detections and its plan checks are left out. It never references the pipeline classes, so it documents exactly what a run does and needs no config file. The config JSON is embedded in the header comment |

Both scripts write to separate output folders when their config does, and
the two produce identical `_extract.mat`, `_spikes.mat`, `_chronux.mat`,
`_fieldtrip.mat` and `settings.json` (paths aside) files
([`test_EphysPipelineScript`](../pipeline/test_EphysPipelineScript.m)).
`EphysPipelineScript.literal(v)` renders strings, string lists, numbers
(including `Inf`, `NaN`, `[]`), logicals and structs so that
`eval(literal(v))` reproduces `v`.

The GUI's **File → Generate script** menu writes either form. Each pipeline
run also saves the standalone form in the project root unless
`Project.SaveScript` is off ([Run](#run)); `standalone(cfg, Note=)` adds the
comment lines that name the run to its header.

---

## Epsych2 sessions

[Epsych2](https://github.com/dstolz/epsych2) saves one plain `.mat` per
subject and session with two variables: `Data` (a struct array, one element
per completed trial, with one field per readable parameter plus `TrialIndex`,
`TrialID`, `computerTimestamp` and `isTest`) and `Info` (the session snapshot:
`Subject`, `StartTime`, `Protocol`, `TrialTable`, ...). No Epsych2 code is
needed to read it.

| Function | Returns |
| --- | --- |
| `[trials, info, meta] = readEpsychSession(file)` | `trials = struct2table(Data)` (values as saved; response codes stay raw bit masks), `info = Info`, `meta` (`file`, `subject`, `startTime`, `nTrials`, `formatVersion`, `responseCodeField`, `parameterNames`, ...). `readEpsychSession:NotEpsych` when `Data` / `Info` are missing |
| `meta = epsychSessionMeta(file)` | the cheap summary (only `Info` is read) |
| `[Data, Info] = stitchEpsychSessions(files, OutFile=)` | several sessions of one subject joined into one, always in chronological order (by `Info.StartTime`, else the first trial's `computerTimestamp`). `Data` gains `StitchPart` (session number) and `StitchPartTrial` (row in that session); `TrialIndex` is renumbered `1..N`; a parameter some sessions lack is `[]`. `Info` is the earliest session's plus `Info.Stitch.Parts` (`File`, `Name`, `Bytes`, `StartTime`, `NTrials`, each session's own `Info`). `OutFile` also saves `Data` and `Info` (`-v7`). Refuses overlapping sessions, different subjects and already stitched files. The Copy tab uses it for [stitched sessions](EphysPipelineApp.md#stitching-epsych-files) |
| `T = findEpsychSessions(dirs, Recursive=true)` | table `File`, `Stem`, `Subject`, `StartTime`, `NTrials`, `FormatVersion`, sorted by start time |
| `match = matchEpsychSession(T, ds, Match=, MaxStartOffsetMin=)` | `"prefix"`: the recording folder name or one of its files starts with the session file stem (how Epsych2 names Intan RHX recordings; the longest stem wins, ties are ambiguous); `"time"`: nearest `StartTime` to the recording's `AcqDate` within the tolerance; `"prefix-then-time"` (default). `match` has `file`, `method`, `candidates`, `ambiguous`, `reason` |

On a dataset: `ds.BehaviorFile`, `ds.readBehavior()` (the three outputs above),
`ds.behaviorStruct()` (`trials`, `info`, `meta`, `file`, `subject`,
`startTime`, `nTrials`, or `[]`), and `ds.behaviorToMat()`, which saves that
struct once as `<outputFolder>/<Name>_behavior.mat` (the behavior step does
this when `Behavior.WriteFile`). No other output carries behavior data. The
manifest records `file` (as recorded, even while it is not there), `exists`,
`subject`, `start_time` and `n_trials`.

**TDT epocs as trials.** A TDT block without an associated Epsych2 session
whose `Behavior.TrialLine` is one of its epoc stores (`"Freq"`, or the name
`Signals.LineNames` gives it) takes its trials from the epocs
(`ds.behaviorSource()` is `"epocs"`; an associated Epsych2 session always
wins). Each epoc of that store on the stream is one trial, and every other
epoc store except `Tick` is a parameter column holding the value that store
has at the trial's onset (see
[TDT Synapse blocks](EphysDataset.md#tdt-synapse-blocks)). The behavior step
pairs them with the store's own event line, which matches one to one, so the
pairing is approved automatically (`auto-approved`), and writes
`<Name>_behavior.mat` as for a session: epoch exports, the analysis module's
grouping, filters and tuning parameters use them unchanged. The step's
association row still reports the Epsych2 outcome (`no session`,
`unmatched`). There are no response codes: a response selection raises
`selectTrials:NoRespCode`. The app's Trials tab still loads only Epsych2 sessions.

### Digital-line names

Readers name digital lines by their native names (`DIGITAL-IN-04` on Intan,
`TTL4` on Open Ephys). Every events output names them by
`Signals.LabelField` (`"custom"`: Intan's custom names, such as the `InTrial`
set in RHX; `"native"`) unless `Signals.LineNames` names a line:
`LineNames = ["TTL1=Trough" "TTL4=InTrial"]` makes Open Ephys lines match the
Epsych2 names. `Behavior.TrialLine` and `Signals.InvertedLines` use the final
names. `validate()` checks the `native=name` form, that names are valid
identifiers and that no native line or name appears twice. The events cache
stores the native names, so renaming a line (the app's **Trials** tab edits
`LineNames` in place) never re-reads a recording. See
[EphysDataset → Digital-line names](EphysDataset.md#digital-line-names).

### Digital-line polarity

Readers return every digital line as its HIGH runs. `Signals.InvertedLines`
lists the lines whose TTL logic is inverted:

| Polarity | On while | Onset | Offset |
| --- | --- | --- | --- |
| normal (default) | high | rising edge: first high sample | last high sample before the falling edge |
| inverted | low | falling edge: first low sample | last low sample before the rising edge |

`digitalLinePolarity(events, invertedLines, nSamples, Fs)` does the
relabelling. An inverted line's intervals are the complement of its high runs
within the recording, so a low stretch at either end of the recording counts,
just as a high stretch there does for a normal line. It applies everywhere
events are produced: `deriveSignals` / `toMat` (option `invertedLines`, by
default the dataset's `TrialConfig.InvertedLines`, also for a hand-run
`toMat` / `deriveSignals` and `ChronuxDataset`'s derived signals;
`info.invertedLines` lists the lines inverted), and therefore the Chronux and
FieldTrip exports built from the extract; `ChronuxDataset` with `Signal="RAW"`
(`SignalOptions.invertedLines`, else `TrialConfig.InvertedLines`, with the line
naming from `TrialConfig` too); `intan2matlab`; and the trial pairing. Names a recording does not have are
ignored. The events cache (`<Name>_events.mat`) keeps the raw high runs.

### Pairing trials with the trial line

Epsych2 holds a digital line on for the duration of every trial (`InTrial`
by default; its Intan dig-in name matches the Epsych2 parameter).
`P = pairEpsychTrials(trials, events, Fs, Name=Value)` pairs each trial with
one interval of that line. It depends on nothing but the trials table and the
universal events struct:

- **Pairing.** The Epsych2 timestamps are not used. The first trial pairs
  with the first interval, the second with the second, and so on: every
  interval is taken to be one trial. When the numbers differ, the first
  `min(nTrials, nIntervals)` still pair in order and the result carries a
  warning (`countMismatch`, `warnings`, and a
  `pairEpsychTrials:CountMismatch` warning unless `Warn=false`). That happens
  when the recording was started after the session began or stopped before
  it ended, or when the line carries intervals that are not trials.
  `CutTrials=[start end]` and `CutIntervals=[start end]` drop trials or
  intervals from either end before pairing; that is how a mismatch is
  resolved, and the only adjustment there is.
- **Intervals at the recording edges.** An interval that begins at the first
  sample or ends at the last sample (`NumSamples`) is partial: the line was
  already on when the recording started (during a trial, or before Epsych2
  had set the line to its idle level, which for an inverted line is high) or
  still on when it stopped. They are listed in `partialIntervals`, their
  trials are flagged `partial`, and the mismatch warning names them, since
  they are usually what has to be cut.
- **Polarity.** `InvertedLines` names lines with inverted polarity
  (`Signals.InvertedLines` in the config, see
  [digital-line polarity](#digital-line-polarity)); pass events that already
  had it applied with `InvertedLines` empty.
- **Output.** `interval`, `onset` / `offset` (s, `t = row/Fs`), `onsetSample` /
  `offsetSample` (1-based rows at `Fs`), `signalSamples.<SIG>`
  (`round((t − 1/Fs) · SignalFs.<SIG>) + 1`: row r at `Fs` lies at
  `(r − 1)/Fs` on the continuous clock, and this is the signal's sample nearest
  it, the `ChronuxDataset.trials` `"event"` onset rule),
  `flag` (`ok`, `partial`, `cut`, `unpaired`), `intervals` and `events`
  (polarity applied), `partialIntervals`, `unpairedTrials`,
  `unpairedIntervals`, `lines.<line>` (per trial, the intervals of every other
  line that overlap it) and `columns`, the table appended to `behavior.trials`.

On a dataset, `P = ds.pairTrials()` reads the session and the digital events.
The events are cached as `<outputFolder>/<Name>_events.mat`, because reading
them can mean reading the recording. The settings come from `ds.TrialConfig`
(`EphysPipelineConfig.trialConfig(cfg)`: the Behavior settings plus
`Signals.LabelField`, `Signals.LineNames`, `Signals.InvertedLines` and the rates of the enabled
LFP / MUA / resampled SPIKE signals). A pairing is reviewed, not trusted:
`ds.setTrialPairing(P, "approved")` stores its cuts in the manifest
(`behavior.pairing`). Later `pairTrials` calls reuse them while the
fingerprint still matches (the session stem, trial count, trial line, polarity
and the line's intervals), and report `stale = true` (cuts dropped)
otherwise; `Cuts="none"` ignores the record and
`Cuts=struct('trials', [s e], 'intervals', [s e])` tries other cuts. With
`Behavior.AutoApprove`, `ds.autoApproveTrialPairing(P)` approves a pairing
that cuts nothing and whose trial and interval counts match, and marks it
automatic (`auto_approved`); mismatches still need review. The app's
**Trials** tab does this interactively, and its **Prefetch ticked** button
reads (and caches) the digital lines of many datasets in one go. In the behavior step a mismatch is a
`count mismatch` result row and a `WARNING` log line.
`ds.behaviorToMat(Pairing=P)` writes the columns and a `pairing` summary into
the behavior file.

---

## Tests

| Suite | Checks |
| --- | --- |
| [`test_EphysPipelineConfig.m`](../pipeline/test_EphysPipelineConfig.m) | exact save / load round trip with `Inf`, `NaN`, `[]`, one-element lists and bands; normalization fills and drops; `BadSchema`; `ks4Settings`; `ks4ProbeDefaults` on synthetic layouts (staggered 4-shank, Neuropixels-like, dense multi-shank, sparse column, 2-D grid, exclusions, shanks without `kcoords`); probe parameter files (`writeKS4Params` / `ks4ForProbe`: round trip, a hand-written subset, refusals, every file shipped in `pipeline/probes` loads); every `signalOptions` error and each `ExcludeHandling` mode; `validate` on enabled steps only, the `Parallel` section (`MaxWorkers`), the background-sorting rule and the unit-label `NamePattern` rule |
| [`test_EphysPipeline.m`](../pipeline/test_EphysPipeline.m) | selection by key with duplicate leaf names; `plan()` writes nothing and flags existing / duplicate outputs, missing probe, sorting output and extract file, unit identity errors and unit label collisions; sorting dry run writes a `settings.json` carrying the KS4 settings; `runSignals` / `runSpikeDetection` / `runExport` outputs equal the direct calls; `runSignals` erases the artifact periods (manual + automatic; manual only without `Artifacts.ApplyToSignals`; none without `Signals.BlankArtifacts`) and every per-type file, the Chronux file and the FieldTrip file carry them; `checkBehavior` associates by prefix and writes the manifest; the artifact cache is reused and invalidated; cancel leaves no partial `.mat`; `Parallel.Enabled` reaches the artifacts and spikes steps and is logged |
| [`test_TrialPairing.m`](../pipeline/test_TrialPairing.m) | `pairEpsychTrials`: equal counts, a recording started late or stopped early (partial intervals at the edges, the count-mismatch warning, the cuts that resolve it), an inverted line idle at the recording start, cut validation, nested lines, derived-signal samples; `digitalEvents` cache; `pairTrials` / `setTrialPairing` manifest round trip with cuts and staleness; `autoApproveTrialPairing` (only matching counts without cuts, the `auto_approved` mark); `behaviorToMat(Pairing=)`; the behavior step records, reuses and reports pairings, `AutoApprove` and a count mismatch included |
| [`test_EphysPipelineScript.m`](../pipeline/test_EphysPipelineScript.m) | both scripts are `checkcode`-clean, run, and produce identical outputs; the standalone text never mentions the pipeline classes; disabled steps are commented out in the compact script; `literal` round-trips; the standalone script carries the `Parallel` section into the chunked steps and the artifact periods into its signals step |
| [`test_OpenEphysReader.m`](../pipeline/test_OpenEphysReader.m) | Open Ephys sessions in every record engine; the `Acquisition` modes; `LineNames` validation and naming; a synthetic Open Ephys project through `EphysPipeline` |
| [`test_TDTReader.m`](../pipeline/test_TDTReader.m) | TDT Synapse blocks: samples from TEV and SEV, stream choice and gain, epocs and their rows, `Acquisition.TDT` |
| [`test_UnitLabels.m`](../pipeline/test_UnitLabels.m) | `nameIdentity` (literal prefix, non-matching names, pattern, subject and date errors, dates and times with separators), class and id padding, identity columns, peak site and template centre, `writeUnitNotes` / `readUnitNotes`, `readSortedUnits` identity errors, `EphysProject.unitIdentities` collisions, `unitTable` (columns, filtering, duplicates, files, refreshed notes) |
| [`test_EpsychSession.m`](../pipeline/test_EpsychSession.m) | synthetic `Data` / `Info` files; `NotEpsych`; matching by prefix, by time, and ambiguity |
| [`test_PipelineAnalysisStep.m`](../analysis/test_PipelineAnalysisStep.m) | the Analysis step over a synthetic project: its validation (the analysis config's own issues under `Plots.<id>.<field>`, its `Source` ignored, a missing file, nothing written, background sorting feeding unit plots), plan rows per dataset and plot and the report row, a dry run writing nothing, a run writing every dataset's figures, the report and both run records with progress that only grows, cancel, a `list` selection with one report per dataset, and both scripts (the standalone one carries the analysis config and writes the report again) |

Run everything with [`run_all_tests.m`](../pipeline/run_all_tests.m).
