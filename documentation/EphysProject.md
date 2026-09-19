# EphysProject

`EphysProject` ([source](../pipeline/@EphysProject/EphysProject.m))
is a `handle` class that discovers **many recordings** under one root folder,
wraps each one as an [`EphysDataset`](EphysDataset.md), and runs batch
operations over them. It holds shared configuration (probe, Python/conda, output
root, scale, dtype) and pushes it down into every dataset.

The GUI ([`EphysPreprocessingApp`](EphysPreprocessingApp.md)) builds one on
every **Scan**; [`EphysPipeline`](EphysPipeline.md) builds one from a config's
`Project.Root`. Both then call `refresh()`.

## Construction

```matlab
P = EphysProject(root)
P = EphysProject(root, ProbeFile=..., PythonExe=..., OutputRoot=...)
P = EphysProject(root, AutoDiscover=false)   % set config, call P.discover() later
```

| Option | Default | Meaning |
| --- | --- | --- |
| `ProbeFile`, `PythonExe`, `CondaEnv` | `""` | pushed to every dataset |
| `OutputRoot` | `""` | when set, each dataset's `OutputDir` = `OutputRoot/<Name>` |
| `Scale` | `1/0.195` | pushed to every dataset |
| `Dtype` | `"int16"` | pushed to every dataset |
| `NamePattern` | `EphysDataset.DefaultNamePattern` | name pattern pushed to every dataset; its `SubjectID`, `Date` and `Time` tokens label sorted units (see [Unit labels](EphysDataset.md#unit-labels)) |
| `Recursive` | `true` | `discover()` searches every sub-folder of `root`; `false` = only `root` and the folders directly in it |
| `ReaderOptions` | `struct()` | reader options (a config's [`Acquisition` section](EphysPipeline.md#acquisition)): used by `discover()` and pushed to every dataset |
| `Manifest` | `[]` | optional shared provenance `Manifest` |
| `AutoDiscover` | `true` | run `discover()` in the constructor |

The constructor errors (`EphysProject:NoRoot`) if `root` does not exist.
`EphysProject()` with no arguments returns an empty object.

## Properties

| Property | Meaning |
| --- | --- |
| `Root` | root folder that was scanned |
| `Recursive` | whether `discover()` searches below the folders directly in `Root` |
| `Datasets` | `EphysDataset` row array, one per recording folder |
| `ProbeFile`, `PythonExe`, `CondaEnv`, `OutputRoot`, `Scale`, `Dtype`, `NamePattern`, `ReaderOptions`, `Manifest` | shared defaults |
| `NumDatasets` (dependent) | `numel(Datasets)` |

Changing a shared property after construction does **not** update existing
datasets by itself. Call `pushConfig(d)` for each dataset (or re-`discover()`).

## Methods

**`discover()`** finds every folder under `Root` that a registered
acquisition reader claims
(`EphysReader.findAllRecordingFolders`): folders that directly contain a
`*.rhd` file (Intan traditional and split layouts, since `info.rhd` matches),
folders holding a `recording.json` descriptor (the
[universal binary format](file-formats.md#universal-recording-format-recordingjson)),
and Open Ephys GUI session folders (the folder holding `Record Node <id>`, found
by its `structure.oebin`, `*.continuous` or `experiment*.nwb` files; see
[Open Ephys sessions](EphysDataset.md#open-ephys-sessions)). With
`ReaderOptions.OpenEphys.Recordings = "separate"` a session with several
recordings is replaced by one part folder per recording, which the scan
creates inside the session folder.
With `Recursive` (the default) every sub-folder is searched; with
`Recursive=false` only `Root` itself and the folders directly in it can be
recordings, so `Root/mouse1/sess1` is not found.
One `EphysDataset` is created per folder with `AutoMetadata=false` (headers are
not parsed yet), and `pushConfig` is applied to each. If nothing is found,
`Datasets` is emptied and a warning is issued (`EphysProject:NoData`).

**`report = refresh(Name=Value)`** runs, for every dataset:

1. `refreshMetadata()`: header-only metadata (Fs, channels, duration);
2. `applyManifest()`: restore the probe, channel exclusions, manual artifact
   periods, sorting and behavior associations from
   `<Folder>/<Name>_manifest.json`, then `associateFolderBehavior()`: a
   dataset with no behavior file takes the one Epsych2 session file in its
   own folder, which is where the app's Copy tab puts it;
3. `writeManifest()`: rewrite the manifest with the fresh metadata.

This is what the GUI's Scan does and what `EphysPipeline` and generated scripts
call, so headless runs and the app agree on the state of each dataset. Options:
`ApplyManifest`, `WriteManifest` (default true), `Force` (re-parse cached
headers), `ProgressFcn(i, n, name)`, `CancelFcn()`. Failures warn and are
recorded in the returned table (`Dataset`, `Key`, `Metadata`, `Manifest`,
`Message`) instead of interrupting the loop.

**`pushConfig(d)`** copies `ProbeFile`, `PythonExe`, `CondaEnv`, `Scale`,
`Dtype`, `NamePattern`, `Manifest`, the dataset's key (`DatasetKey`, saved
with its sorted units) and (when `OutputRoot` is set) `OutputDir = OutputRoot/<Name>`
into one dataset. This **overwrites** that dataset's `ProbeFile`. The GUI and
the pipeline deliberately avoid calling it after scanning so per-dataset probe
assignments survive (`EphysPipeline.applyConfigToDatasets` sets everything
except `ProbeFile`, `SortingDir` and `BehaviorFile`).

### Dataset keys

Dataset names are folder leaves and need not be unique (`mouse1/sess1` and
`mouse2/sess1`). Every place that has to name a dataset durably (the pipeline
config's selection, the refresh report, the GUI table) uses the
**root-relative key** with forward slashes instead.

| Method | Returns |
| --- | --- |
| `datasetKey(i)` | the key of dataset `i` (`"mouse1/sess1"`) |
| `datasetKeys()` | every key, in `Datasets` order |
| `findByKey(keys)` | the index of each key (0 when not found) |
| `EphysProject.relativeKey(root, folder)`, `EphysProject.normalizeKey(s)` | statics: build / normalize a key |
| `d = dataset(idxOrName)` | one dataset by index or by `Name` (the **first** match; `EphysProject:NoSuchDataset` if the name is not found) |
| `dt = tracker(idxOrName)` | `dataset(idxOrName).tracker()`, the [`DatasetTracker`](DatasetTracker.md) inventory of that dataset's output folder |
| `T = unitIdentities(Among=, NamePattern=)` | one row per dataset (`Key`, `Name`, `Subject`, `RecordingStart`, `LabelSuffix`, `Status`, `Message`): how its sorted units are labelled. `Status` is `ok`, why the name cannot label units (`pattern`, `nomatch`, `subject`, `datetime`), or `collision` when another dataset in `Among` (default: all) has the same subject and start minute. `NamePattern` overrides each dataset's own |

### Batch operations

**`T = gatherMetadata(Force=false)`** calls `refreshMetadata` on every dataset
whose `Fs` is still `NaN` (or on all of them with `Force=true`). It returns one
table row per dataset with `Name`, `Folder`, `NumFiles`, `NumChannels`, `Fs`,
`Duration`, `AcqDate`, `ChannelNames`, `HasProbe` (`ProbeFile` is set and
exists), `BinExists`, `HasKilosort` (the dataset's tracker has a run with
`spike_clusters.npy`).

**`infos = toBinAll(Name=Value...)`** calls `toBin` on every dataset, passing
all arguments through to `EphysDataset.toBin`. An error on one dataset is caught,
reported as a warning (`EphysProject:toBinFailed`), and the batch continues.
Each element of `infos` has `Name`, `info` (the `toBin` struct, or `[]` on
failure) and `error` (`""` on success).

**`results = runKilosortAll(Name=Value...)`** calls the native
`EphysDataset.runKilosort` on every dataset with the same error handling
(`EphysProject:runKilosortFailed`).

For everything else (sorting through SpikeInterface, derived signals, spikes,
exports) use [`EphysPipeline`](EphysPipeline.md), which loops over the
project's selected datasets with a config, or loop over `P.Datasets` yourself.

## Example

```matlab
P = EphysProject("D:\experiments", OutputRoot="D:\sorted");
P.refresh();                              % headers + manifests
T = P.gatherMetadata();                   % one row per dataset
i = P.findByKey("mouse1/sess1");
P.Datasets(i).ProbeFile = "C:\src\ephys_analysis\pipeline\probes\H64LP_4x16lin_probemap.json";
P.Datasets(i).writeManifest();

% run a config over the project (see EphysPipeline.md)
cfg = EphysPipelineConfig.load("D:\experiments\pipeline.json");
pipe = EphysPipeline(cfg, Project=P, Refresh=false);
pipe.run(Steps=["signals" "spikes"]);
```
