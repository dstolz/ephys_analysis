# ephys_analysis

**See [Wiki](https://github.com/dstolz/ephys_analysis/wiki) for detailed documentation.**

See [documentation/README.md](documentation/README.md) for the full pipeline
reference and [pipeline/INSTALL.md](pipeline/INSTALL.md) for setup.

## Layout

| Path | Contents |
| --- | --- |
| [`pipeline/`](pipeline) | `EphysDataset`, `EphysReader` / `IntanReader` / `OpenEphysReader` / `BinaryReader`, `EphysProject`, `DatasetTracker`, `EphysPipelineConfig` / `EphysPipeline` / `EphysPipelineScript`, `EphysPreprocessingApp`, `ChronuxDataset`, `FieldTripExport`, Epsych2 readers, probe JSON, pipeline configs, Python drivers, tests |
| [`pipeline/pipeline_configs/`](pipeline/pipeline_configs) | starting-point pipeline configs (`H64LP_4x16.json`) |
| [`analysis/`](analysis) | quick-look figures from the pipeline's outputs: `EphysAnalysisConfig` / `EphysAnalysisRunner` / `EphysAnalysisScript`, `EphysAnalysisApp`, PSTHs, evoked potentials, rates, tuning, heatmaps, probe maps, HTML / PDF reports ([docs](documentation/EphysAnalysis.md)) |
| [`documentation/`](documentation) | Reference docs for the pipeline |
| [`S_ExampleAnalysis.m`](S_ExampleAnalysis.m) | script walkthrough: project, detection, derived signals, the pipeline and its outputs |
| [`extract_trials.m`](extract_trials.m), [`matrix2kilosort.m`](matrix2kilosort.m) | Top-level helpers used by `pipeline/` |
| [`vendor/`](vendor) | Copies of a few `helper_fnc` utilities this pipeline depends on — see [vendor/README.md](vendor/README.md) |
| [`toolboxes/chronux`](toolboxes/chronux) | Bundled copy of the [Chronux](http://chronux.org) toolbox, used with `ChronuxDataset` |

## Quick start

```matlab
addpath_nogit('C:\src\ephys_analysis')   % once per session
EphysPreprocessingApp                    % GUI: File > New, scan, enable steps, Run
```

```matlab
cfg  = EphysPipelineConfig.load("D:\EPHYS\pipeline.json");   % saved from the GUI
pipe = EphysPipeline(cfg);
disp(pipe.plan());  pipe.run();
```

Every sorted unit is labelled with its class, cluster id, subject and recording
start (`su042_1255_260908T1039`), and carries its channel, shank, position and
notes. Gather them across recordings into one table:

```matlab
f  = dir("D:\EPHYS\out\**\*_spikes.mat");
T  = unitTable(string(fullfile({f.folder}, {f.name})));
su = T(T.class == "su" & T.subject == "1255", :);
```

Quick-look figures of the outputs (PSTHs, evoked potentials, rates, tuning
curves, heatmaps, probe maps; aligned to any digital line, grouped by Epsych2
parameters; exported with an HTML / PDF report):

```matlab
EphysAnalysisApp("D:\EPHYS")                                       % GUI
r = EphysAnalysisRunner(EphysAnalysisConfig.load("D:\EPHYS\am.json"));
disp(r.plan());  r.run();                                          % headless
```

Recordings from Intan RHX and from the Open Ephys GUI (Binary, Open Ephys or
NWB format) are read directly; name Open Ephys TTL lines in the config
(`Signals.LineNames = ["TTL4=InTrial" ...]`, or on the Trials tab) and match
its session folders with the name pattern
`{SubjectID}_{Date:yyyy-MM-dd}_{Time:HH-mm-ss}*`.

No data yet? `makeSyntheticProject("D:\scratch\synthetic_ephys")` (or **File →
Create synthetic test project...** in the GUI) writes synthetic recordings
(Intan or Open Ephys) with Epsych2 sessions, sorted output and a ready config
to run.

Tests: `cd pipeline; run_all_tests`.
