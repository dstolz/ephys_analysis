# EphysPipelineConfig, EphysPipeline, EphysPipelineScript

Three classes make a preprocessing run reproducible outside the GUI:

| Class | Kind | Role |
| --- | --- | --- |
| [`EphysPipelineConfig`](../intan/@EphysPipelineConfig/EphysPipelineConfig.m) | value | every setting of every step, which steps are enabled, the project root / output root and the dataset selection; round-trips through JSON exactly |
| [`EphysPipeline`](../intan/@EphysPipeline/EphysPipeline.m) | handle | runs a config over an [`EphysProject`](EphysProject.md): plan, validate, run, cancel, progress, results |
| [`EphysPipelineScript`](../intan/@EphysPipelineScript/EphysPipelineScript.m) | static | writes MATLAB scripts that reproduce a config's run, with or without the two classes above |

The GUI ([`EphysPreprocessingApp`](EphysPreprocessingApp.md)) edits one config
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
cfg.Spikes.Enabled = true;  cfg.Spikes.Source = "both";
cfg.Export.Enabled = true;  cfg.Export.Formats = ["chronux" "fieldtrip"];
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
| `Project` | – | `Root`, `OutputRoot` (`""` = outputs next to each recording), `Selection` (`"all"` or `"list"`), `Datasets` (root-relative keys, see [Dataset keys](#dataset-keys)) |
| `Probe` | `probe` (always runs) | `DefaultProbeFile` (assigned to datasets without a probe), `WriteDefaultToManifest` |
| `Behavior` | `behavior` | `Enabled`, `SearchDirs`, `Match` (`"prefix"`, `"time"`, `"prefix-then-time"`), `MaxStartOffsetMin` (30), `Overwrite`, `WriteFile` (`true`: write `<Name>_behavior.mat` for every associated dataset), `PairTrials` (`true`), `TrialLine` (`"InTrial"`), `AlignToleranceS` (0.5) |
| `Artifacts` | `artifacts` | `Enabled` (automatic detection; manual periods always apply), `Method`, `Threshold`, `RmsWindowMs`, `MergeGapMs`, `MinChannels`, `PadMs`, `Filter`, `FilterType`, `FilterCutoff`, `FilterOrder`, `ApplyToSorting`, `ApplyToSpikes`, `CacheIntervals` |
| `Sorting` | `sorting` | `Enabled`, `PythonExe`, `CondaEnv`, `Execution` (`"background"` or `"blocking"`), `DryRun`, `SkipExisting`, `SI` (the [SpikeInterface settings](EphysDataset.md#default-spikeinterface-configuration)), `KS4` (one typed field per `kilosortParamSpec` entry), `KS4ExtraJSON` |
| `Signals` | `signals` | `Enabled`, `OutputDir`, `Suffix` (`"_extract"`), `SeparateFiles` (`true`: `<Name><Suffix>_<TYPE>.mat` per signal type), `MatVersion`, `Overwrite`, `LFP` / `MUA` / `SPIKE`, `LFP_Fs`, `LFP_HighpassOn/Hz`, `LFP_LowpassOn/Hz`, `LFP_NotchOn/Hz/BW`, `MUA_Fs`, `MUA_IntegrationHz`, `MUA_bpLoHi`, `SPIKE_KeepOriginal`, `SPIKE_Fs`, `SPIKE_bpLoHi`, `LabelField`, `InvertedLines` (digital lines with inverted polarity: onset = falling edge; see [polarity](#digital-line-polarity)), `KeepChannels`, `BadMode`, `BadThreshold`, `BadList`, `ChannelRemap`, `ExcludeHandling` (`"none"`, `"drop"`, `"interpolate"`: what to do with the manifest's excluded channels) |
| `Spikes` | `spikes` | `Enabled`, `Source` (`"detect"`, `"sorted"`, `"both"`), the `detectSpikes` options (`Filter`, `Band`, `FilterOrder`, `Polarity`, `ThresholdMethod`, `Threshold` (`NaN` = the method's default), `Align`, `AlignWindowMs`, `MinPeriodMs`, `MaxAmplitudeUV`, `Waveforms`, `WindowMs`, `WaveformSource`, `EdgeHandling`, `MaxChunkSamples`, `EdgePadMs`, `UseParallel`), `Channels` (`"all"`, `"excludeManifest"`, `"list"`) + `ChannelList`, `RejectArtifacts`, the sorted-unit options (`Groups`, `IncludeNoise`, `Templates`), `OutputDir`, `Suffix` (`"_spikes"`), `MatVersion`, `Overwrite` |
| `Export` | `export` | `Enabled`, `Formats` (subset of `["chronux" "fieldtrip"]`), `Signals` (`[]` = every signal in the extract), `IncludeUnits`, `IncludeDetected`, `IncludeEvents`, `Groups`, `Validate`, `OutputDir`, `MatVersion`, `Overwrite` |

`Name` and `Description` are free text. `File` (where the config was loaded
from or saved to) and `LoadWarnings` are transient.

Channel lists (`KeepChannels`, `BadList`, `ChannelRemap`, `ChannelList`) and the
notch list are kept as typed text and parsed when a run starts
(`parseOrderedList`, `parseFreqList`: order and repeats are kept, anything
unparseable is an error).

### JSON

`cfg.save(file)` / `EphysPipelineConfig.load(file)`; the on-disk schema is in
[file-formats.md](file-formats.md#pipeline-config-json). `Inf`, `NaN` and empty
values round-trip exactly (`isequaln(load(save(cfg)), cfg)`). A file with
another `schema` or a newer `version` raises `EphysPipelineConfig:BadSchema`;
there is no migration. Unknown fields are dropped and listed in
`LoadWarnings`.

### Validation

`issues = cfg.validate()` returns a table (`Step`, `Field`, `Severity`,
`Message`). `Project` and `Probe` are always checked; a step section only when
it is enabled. Severity `"error"` stops `run()`. Cross-step rule: a background
sorting run cannot feed the sorted-unit consumers (`Spikes.Source` `"sorted"` /
`"both"`, `Export.IncludeUnits`) in the same run; set
`Sorting.Execution = "blocking"` or run those steps later.

### Helpers

| Static | Returns |
| --- | --- |
| `defaults(section)`, `normalizeSection(section, s)` | defaults; a normalized copy |
| `artifactConfig(A)` | the `EphysDataset.ArtifactConfig` struct for an `Artifacts` section |
| `detectOptions(K)` | `detectSpikes` name-value options for a `Spikes` section |
| `spikeChannels(K, ds)` | the channel list for a dataset (`"all"`, `"excludeManifest"`, `"list"`) |
| `signalOptions(S, ExcludeChannels=, NumChannels=)` | `deriveSignals` options for a `Signals` section, with the exclude handling applied (error IDs `EphysPipelineConfig:Signals*`) |
| `exportOptions(E)` | name-value options shared by `exportChronux` / `exportFieldTrip` |
| `ks4Settings(S)` | the Kilosort4 settings struct (blank / `Inf` fields omitted, `KS4ExtraJSON` merged last) |
| `ks4ParamText`, `ks4ParamFromText`, `kilosortParamSpec` | the typed Kilosort4 parameter spec and its text form (used by the GUI) |
| `validateSuffix(s)` | rejects `\ / : * ? " < > \|` |
| `datasetKey(root, folder)` | root-relative key with forward slashes |

Instance: `stepSection(step)`, `stepEnabled(step)`, `enabledSteps()`,
`isequalConfig(other)`, `toStruct()`, `fromStruct(s)`.

### Dataset keys

Dataset names are folder leaves and are not unique (`mouse1/sess1` and
`mouse2/sess1`). The config's `Project.Datasets` therefore holds
**root-relative keys** with forward slashes (`"mouse1/sess1"`), and
`EphysProject.datasetKey(i)` / `findByKey(key)` map between them and datasets.
`plan()` flags two selected datasets that would write the same
`<OutputRoot>/<Name>` file as `duplicate output`, which is an error.

---

## EphysPipeline

### Construction

```matlab
pipe = EphysPipeline(cfg)                         % EphysProject(cfg.Project.Root, ...) + refresh()
pipe = EphysPipeline(cfg, Project=P)              % reuse a project (the GUI's)
pipe = EphysPipeline(cfg, Project=P, Refresh=false)
```

Construction always calls `EphysPipeline.applyConfigToDatasets(cfg, P)`
(pushes `PythonExe`, `CondaEnv`, `SIConfig`, `ArtifactConfig` and `OutputDir`
into every dataset; never touches `ProbeFile`, `SortingDir` or `BehaviorFile`)
and `selectDatasets()`. Assigning a new `Config` does both again.
`EphysPipeline:NoRoot` when the root does not exist.

### Properties

| Property | Meaning |
| --- | --- |
| `Config`, `Project` | the config and the project it runs on |
| `DatasetIdx` | indices of the selected datasets (`Selection = "all"` → all) |
| `ProgressFcn` | `ProgressFcn(evt)`, `evt` = `step`, `dataset`, `index`, `count`, `done`, `total`, `message` |
| `LogFcn` | one line per event (default `fprintf`) |
| `CancelRequested` | set by `cancel()` |
| `Results` | table `Step`, `Dataset`, `Status`, `Message`, `Output`, `Seconds`, one row per step × dataset |
| `LaunchedRuns` | background Kilosort4 runs (`Name`, `statusFile`, `resultsDir`, `logFile`, `logPos`, `done`), the shape the app's monitor consumes |

### Plan

`T = pipe.plan()` (or `plan(Steps=...)`) returns a table (`Step`, `Dataset`,
`Key`, `Output`, `Status`, `Note`) and writes nothing.

| Status | Meaning |
| --- | --- |
| `ready` | will run |
| `ok` / `associated` | probe already assigned / behavior file already associated |
| `exists: skip`, `exists: overwrite` | the output file exists; `Overwrite` decides |
| `exists: skip (SkipExisting)`, `exists: will re-sort` | sorted output exists |
| `no recording files` | the folder holds no readable recording |
| `no probe`, `probe file missing`, `probe-channel mismatch` | probe preflight |
| `no sorting output` | `Spikes.Source` needs sorted units this dataset lacks |
| `no extract file` | export needs the Signals output |
| `duplicate output` | two selected datasets would write the same file |
| `error: ...` | a setting cannot apply (for example `LFP_Fs` above the recording rate) |

Rows whose status starts with `duplicate` or `error` stop `run()`
(`EphysPipeline:PlanInvalid`); a config with validation errors stops it before
that (`EphysPipeline:ConfigInvalid`).

### Run

`R = pipe.run(Steps=[], DryRun=false)` validates, plans, then runs each enabled
step in `EphysPipelineConfig.StepNames` order:

| Step | Method | Does |
| --- | --- | --- |
| `probe` | `checkProbes()` | assigns `Probe.DefaultProbeFile` to datasets without a probe (written to the manifest when `WriteDefaultToManifest`), reports channel-count mismatches |
| `behavior` | `checkBehavior()` | for datasets without a `BehaviorFile` (or all with `Overwrite`) runs `findEpsychSessions` over `SearchDirs` and `matchEpsychSession`; sets `BehaviorFile`, writes the manifest; reports unmatched and ambiguous datasets. With `WriteFile`, every dataset that ends up associated (matched or kept) gets `behaviorToMat` → `<outputFolder>/<Name>_behavior.mat`, rewritten each run (result step `behavior:file`). With `PairTrials`, trials are first paired with the `TrialLine` intervals (`EphysDataset.pairTrials`, result step `behavior:pairing`): a recorded pairing that still matches is reused (`approved` or `needs review`), anything else is recorded in the manifest as unreviewed (`needs review`); `no trial line` when the recording has no such line. The pairing columns go into the behavior file |
| `artifacts` | `runArtifacts()` | computes `artifactIntervals()` per dataset and caches them (see below) |
| `sorting` | `runSorting()` | `runSpikeInterface(ExtraSettings=ks4Settings, SIConfig=, ArtifactIntervals=, DryRun=, Wait=)`, then `writeManifest`. Background runs are listed in `LaunchedRuns` with status `launched` |
| `signals` | `runSignals()` | `toMat(File=, SeparateFiles=, SignalOptions=, MatVersion=, Overwrite=, ProgressFcn=)` with the configured exclude handling |
| `spikes` | `runSpikeDetection()` | `spikesToMat(Source=, DetectOptions=, Channels=, ArtifactIntervals=, Groups=, IncludeNoise=, Templates=, ...)` |
| `export` | `runExport()` | per format `exportChronux(...)` / `exportFieldTrip(...)` from the extract file, with units, detected spikes and events as configured |

Each step method can be called directly; it then runs even when the step is
disabled in the config. Result statuses are `done`, `skipped`, `dry run`,
`launched`, `error`, `cancelled` and `not run`. Errors on one dataset are
recorded and the run continues with the next.

**Artifact cache.** `artifactIntervalsFor(d)` returns the intervals for a
dataset: manual periods always, automatic detections when `Artifacts.Enabled`.
Automatic detection streams the whole recording, so the result is cached in
`<outputFolder>/<Name>_artifacts.json` (schema in
[file-formats.md](file-formats.md#artifact-cache)), keyed by a fingerprint of
the artifact config and the manual periods. A cache with a different
fingerprint is recomputed. `ApplyToSorting` / `ApplyToSpikes` decide whether
the automatic detections reach those steps (manual periods always do).

**Cancel.** `pipe.cancel()` makes the next progress notification throw
`EphysPipeline:Cancelled`. The current dataset is marked `cancelled` (its
output is written atomically, so nothing half-done is left behind), the
remaining rows are `not run`, and `run()` returns normally.

---

## EphysPipelineScript

```matlab
txt = EphysPipelineScript.compact(cfg, ConfigFile="D:\EPHYS\pipeline.json", File="run_subj1.m");
txt = EphysPipelineScript.standalone(cfg, File="run_subj1_standalone.m");
```

| Form | Contents |
| --- | --- |
| `compact` | loads the JSON config, builds an `EphysPipeline`, prints `plan()`, then one `pipe.<step>()` line per step. Disabled steps are written commented out. Override hints for the output root, the selection and the execution mode are included as comments. Keep the config file next to it |
| `standalone` | every parameter written out as MATLAB literals, in `%%` sections; builds `EphysProject` + `refresh()`, selects datasets by key, and calls `artifactIntervals`, `runSpikeInterface`, `toMat`, `spikesToMat`, `exportChronux`, `exportFieldTrip` and the Epsych2 functions directly. It never references the pipeline classes, so it documents exactly what a run does and needs no config file. The config JSON is embedded in the header comment |

Both scripts write to separate output folders when their config does, and
the two produce identical `_extract.mat`, `_spikes.mat`, `_chronux.mat`,
`_fieldtrip.mat` and `si_config.json` files
([`test_EphysPipelineScript`](../intan/test_EphysPipelineScript.m)).
`EphysPipelineScript.literal(v)` renders strings, string lists, numbers
(including `Inf`, `NaN`, `[]`), logicals and structs so that
`eval(literal(v))` reproduces `v`.

The GUI's **File → Generate script** menu writes either form.

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
| `T = findEpsychSessions(dirs, Recursive=true)` | table `File`, `Stem`, `Subject`, `StartTime`, `NTrials`, `FormatVersion`, sorted by start time |
| `match = matchEpsychSession(T, ds, Match=, MaxStartOffsetMin=)` | `"prefix"`: the recording folder name or one of its files starts with the session file stem (how Epsych2 names Intan RHX recordings; the longest stem wins, ties are ambiguous); `"time"`: nearest `StartTime` to the recording's `AcqDate` within the tolerance; `"prefix-then-time"` (default). `match` has `file`, `method`, `candidates`, `ambiguous`, `reason` |

On a dataset: `ds.BehaviorFile`, `ds.readBehavior()` (the three outputs above),
`ds.behaviorStruct()` (`trials`, `info`, `meta`, `file`, `subject`,
`startTime`, `nTrials`, or `[]`), and `ds.behaviorToMat()`, which saves that
struct once as `<outputFolder>/<Name>_behavior.mat` (the behavior step does
this when `Behavior.WriteFile`). No other output carries behavior data. The
manifest records `file`, `subject`, `start_time` and `n_trials`.

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
events are produced: `deriveSignals` / `toMat` (option `invertedLines`;
`info.invertedLines` lists the lines inverted), and therefore the Chronux and
FieldTrip exports built from the extract; `ChronuxDataset` with `Signal="RAW"`;
`intan2matlab`; and the trial pairing. Names a recording does not have are
ignored. The events cache (`<Name>_events.mat`) keeps the raw high runs.

### Pairing trials with the trial line

Epsych2 holds a digital line high for the duration of every trial
(`InTrial` by default; its Intan dig-in name matches the Epsych2 parameter).
`P = pairEpsychTrials(trials, events, Fs, Name=Value)` pairs each trial with
one interval of that line. It depends on nothing but the trials table and the
universal events struct:

- **Alignment.** Epsych2 stamps `computerTimestamp` when a trial ends, so the
  timestamps are aligned with the interval offsets. The clock offset is the most
  common timestamp - offset difference. Trials and intervals are then paired in
  order by dynamic programming: a pair costs `|residual| / ToleranceS`, capped
  so a trial stamped seconds late still pairs, and an unpaired trial or interval
  costs a fixed gap. A phantom or missing TTL, or a session that stopped early,
  is therefore skipped instead of shifting every later trial. Without timestamps
  trials pair in order; `Assignment=` uses a given interval per trial.
- **Polarity.** `InvertedLines` names lines with inverted polarity
  (`Signals.InvertedLines` in the config, see
  [digital-line polarity](#digital-line-polarity)); pass events that already
  had it applied with `InvertedLines` empty.
- **Output.** `interval`, `onset` / `offset` (s, `t = row/Fs`), `onsetSample` /
  `offsetSample` (1-based rows at `Fs`), `signalSamples.<SIG>`
  (`round(t * SignalFs.<SIG>)`, the `ChronuxDataset.trials` onset rule),
  `residual`, `flag` (`ok`, `timestamp off`, `unpaired`), `unpairedTrials`,
  `unpairedIntervals`, `lines.<line>` (per trial, the intervals of every other
  line that overlap it) and `columns`, the table appended to `behavior.trials`.

On a dataset, `P = ds.pairTrials()` reads the session and the digital events.
The events are cached as `<outputFolder>/<Name>_events.mat`, because reading
them can mean reading the recording. The settings come from `ds.TrialConfig`
(`EphysPipelineConfig.trialConfig(cfg)`: the Behavior settings plus
`Signals.LabelField`, `Signals.InvertedLines` and the rates of the enabled
LFP / MUA / resampled SPIKE signals). A pairing is reviewed,
not trusted: `ds.setTrialPairing(P, "approved")` stores the assignment in the
manifest (`behavior.pairing`). Later `pairTrials` calls reuse it while its
fingerprint still matches (the session stem, trial count, trial line, polarity
and the line's intervals), and report `stale = true` otherwise. The app's
**Trials** tab does this interactively. `ds.behaviorToMat(Pairing=P)` writes
the columns and a `pairing` summary into the behavior file.

On the real sessions this was built against, the timestamps agree with the
interval offsets to ~0.05 s with no drift. About one trial in eight is stamped
1-11 s late; those trials stay paired and are flagged `timestamp off`.

---

## Tests

| Suite | Checks |
| --- | --- |
| [`test_EphysPipelineConfig.m`](../intan/test_EphysPipelineConfig.m) | exact save / load round trip with `Inf`, `NaN`, `[]`, one-element lists and bands; normalization fills and drops; `BadSchema`; `ks4Settings`; every `signalOptions` error and each `ExcludeHandling` mode; `validate` on enabled steps only and the background-sorting rule |
| [`test_EphysPipeline.m`](../intan/test_EphysPipeline.m) | selection by key with duplicate leaf names; `plan()` writes nothing and flags existing / duplicate outputs, missing probe, sorting output and extract file; sorting dry run writes a matching `si_config.json`; `runSignals` / `runSpikeDetection` / `runExport` outputs equal the direct calls; `checkBehavior` associates by prefix and writes the manifest; the artifact cache is reused and invalidated; cancel leaves no partial `.mat` |
| [`test_TrialPairing.m`](../intan/test_TrialPairing.m) | `pairEpsychTrials`: equal counts, late timestamps, phantom / missing TTLs, early stop, no timestamps, manual assignment, active-low lines, nested lines, derived-signal samples; `digitalEvents` cache; `pairTrials` / `setTrialPairing` manifest round trip and staleness; `behaviorToMat(Pairing=)`; the behavior step records, reuses and reports pairings |
| [`test_EphysPipelineScript.m`](../intan/test_EphysPipelineScript.m) | both scripts are `checkcode`-clean, run, and produce identical outputs; the standalone text never mentions the pipeline classes; disabled steps are commented out in the compact script; `literal` round-trips |
| [`test_EpsychSession.m`](../intan/test_EpsychSession.m) | synthetic `Data` / `Info` files; `NotEpsych`; matching by prefix, by time, and ambiguity |

Run everything with [`run_all_tests.m`](../intan/run_all_tests.m).
