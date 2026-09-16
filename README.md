# ephys_analysis

Config-driven preprocessing pipeline for extracellular electrophysiology, in
MATLAB: read recordings (Intan RHD out of the box; any other system through a
universal binary format), screen for artifacts, sort with Kilosort4 through
SpikeInterface (optional), derive LFP / MUA / spike-band signals, detect
spikes and collect sorted units, associate Epsych2 behavior sessions, and
export files for the [Chronux](http://chronux.org) and
[FieldTrip](https://www.fieldtriptoolbox.org/) toolboxes. One JSON config
(`EphysPipelineConfig`) drives the GUI (`EphysPreprocessingApp`), the headless
runner (`EphysPipeline`) and generated scripts (`EphysPipelineScript`).

This repository was split out of
[`helper_fnc`](https://github.com/dstolz/helper_fnc)'s `ephys/` folder on
2026-09-11. `ephys/intan` became [`intan/`](intan) and `ephys/documentation`
became [`documentation/`](documentation) at the repo root; history was not
carried over (fresh initial commit).

See [documentation/README.md](documentation/README.md) for the full pipeline
reference and [intan/INSTALL.md](intan/INSTALL.md) for setup.

## Layout

| Path | Contents |
| --- | --- |
| [`intan/`](intan) | `EphysDataset`, `EphysReader` / `IntanReader` / `BinaryReader`, `EphysProject`, `DatasetTracker`, `EphysPipelineConfig` / `EphysPipeline` / `EphysPipelineScript`, `EphysPreprocessingApp`, `ChronuxDataset`, `FieldTripExport`, Epsych2 readers, probe JSON, pipeline configs, Python drivers, tests |
| [`intan/pipeline_configs/`](intan/pipeline_configs) | starting-point pipeline configs (`H64LP_4x16.json`) |
| [`documentation/`](documentation) | Reference docs for the pipeline |
| [`S_ExampleAnalysis.m`](S_ExampleAnalysis.m) | script walkthrough: project, detection, derived signals, the pipeline and its outputs |
| [`extract_trials.m`](extract_trials.m), [`matrix2kilosort.m`](matrix2kilosort.m) | Top-level helpers used by `intan/` |
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

Tests: `cd intan; run_all_tests`.
