# ephys_analysis

Intan → Kilosort4 electrophysiology pipeline: MATLAB classes that read Intan
RHD recordings, prepare them for spike sorting (directly, or through
SpikeInterface), review sorted units, and export LFP / MUA / spike-band
signals, plus a GUI (`IntanKilosortApp`) that drives the whole workflow.
`ChronuxDataset` connects the recordings, trials and sorted spike trains to the
[Chronux](http://chronux.org) toolbox for multitaper spectral analysis.

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
| [`intan/`](intan) | `IntanDataset`, `IntanKilosortApp`, `IntanKilosortProject`, `DatasetTracker`, `ChronuxDataset`, probe/config JSON, Python drivers |
| [`documentation/`](documentation) | Reference docs for the pipeline |
| [`extract_trials.m`](extract_trials.m), [`matrix2kilosort.m`](matrix2kilosort.m) | Top-level helpers used by `intan/` |
| [`vendor/`](vendor) | Copies of a few `helper_fnc` utilities this pipeline depends on — see [vendor/README.md](vendor/README.md) |

## Quick start

```matlab
addpath_nogit('C:\src\ephys_analysis')   % once per session
IntanKilosortApp
```
