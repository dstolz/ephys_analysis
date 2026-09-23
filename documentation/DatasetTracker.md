# DatasetTracker

`DatasetTracker` ([source](../pipeline/@DatasetTracker/DatasetTracker.m)) is a
`handle` class that takes a **read-only filesystem inventory** of one directory:
every file the pipeline produces or consumes.

Discovery only lists files and decodes JSON. It reads no amplifier data and
parses no recording header, so it is cheap. The directory can be a single recording
folder or a parent that contains many recording sub-folders.

The other classes use it so that they share one definition of "a recording",
"a probe map", "a `.bin`" and "a Kilosort4 run":

- `EphysProject.discover` and `findRecordings` both use the reader registry
  (`EphysReader.findAllRecordingFolders`), so a folder is a recording for the
  tracker exactly when a reader claims it.
- `EphysDataset.tracker()` returns a tracker; `EphysDataset.manifestStruct()`
  describes the run in `kilosortDir()` with `kilosortRunAt`.
- The GUI's Probe tab uses `probeMeta` / `readJson`.
- The GUI's Review tab uses `latestKilosortRun`.

## Construction

```matlab
dt = DatasetTracker(folder)                      % scan immediately
dt = DatasetTracker(folder, AutoRefresh=false)   % call dt.refresh() later
dt = DatasetTracker(folder, Recursive=false)     % top level only
dt = DatasetTracker(folder, Name="subj1")
dt = DatasetTracker(folder, ReaderOptions=cfg.Acquisition)   % Open Ephys recording modes
dt = DatasetTracker.fromDataset(ds)              % tracks ds.Folder (not ds.OutputDir)
```

It errors (`DatasetTracker:NoFolder`) if the folder does not exist.
`DatasetTracker()` returns an empty object.

`EphysDataset.tracker()` constructs a tracker of the dataset's `outputFolder()`,
and returns an empty tracker if that folder does not exist yet.
`DatasetTracker.fromDataset(ds)` tracks `ds.Folder`. The two differ when
`OutputDir` is set.

## Properties

| Property | Access | Meaning |
| --- | --- | --- |
| `Root` | public | directory being tracked |
| `Name` | public | defaults to the folder leaf |
| `Recursive` | public | scan sub-folders (default `true`) |
| `ReaderOptions` | public | reader options used to find recordings (default `struct()`; `EphysDataset.tracker()` passes the dataset's) |
| `Recordings`, `ProbeFiles`, `BinFiles`, `KilosortRuns` | read-only | inventory struct arrays (schemas below) |
| `LastRefreshed` | read-only | time of the last successful scan |
| `NumRecordings`, `NumProbeFiles`, `NumBinFiles`, `NumKilosortRuns`, `NumRecordingFiles` | dependent | counts |

The inventory is a **snapshot**. Call `dt.refresh()` after new outputs are
written.

## What counts as each item

### Recordings (`emptyRecordings` schema)

A recording is any folder that a registered [acquisition reader](EphysDataset.md#acquisition-readers)
claims: one that **directly** contains a `*.rhd` file (Intan), a
`recording.json` descriptor (the universal binary format), or an Open Ephys GUI
session folder. `Files` are the reader's.

| Field | Meaning |
| --- | --- |
| `Name` | folder leaf |
| `Folder` | full path |
| `Files` | file names |
| `NumFiles` | count |
| `Format` | the reader's `RecordingFormat` (`traditional`, `one-file-per-signal`, `one-file-per-channel`, `binary`, `openephys-binary`, `openephys-legacy`, `openephys-nwb`) |
| `Reader` | `"intan"`, `"binary"` or `"openephys"` |
| `AcqDate` | the reader's recording start (see [`AcqDate`](EphysDataset.md#metadata-read-only-filled-by-refreshmetadata)) |
| `Bytes` | total bytes of the listed files |
| `IsRoot` | the folder is the tracker root |

For Intan split layouts only `info.rhd` is counted, so `Bytes` does not include
the `.dat` files. A binary recording's files are `recording.json`, the data
file and the `dig_in_file` when it names one, so `Bytes` includes that too.

### Probe files (`emptyProbes` schema)

Every `*.json` under the root is decoded and classified with `classifyJson`.
Only those classified as `"probe"` are kept.

| Field | Meaning |
| --- | --- |
| `Name`, `Path` | file |
| `NumChannels` | `n_chan`, but never fewer than `numel(chanMap)` |
| `NumShanks` | `numel(unique(kcoords))` |
| `DepthUm` | `max(yc) − min(yc)` |
| `Notes` | optional `notes` field |
| `IsDerived` | file name ends in `_excluded`, i.e. a probe derived by `runKilosort` for channel exclusion |

### Bin files (`emptyBins` schema)

Every `*.bin` is listed. The `<name>.json` sidecar written by
`EphysDataset.toBin` is read when present.

| Field | Meaning |
| --- | --- |
| `Name`, `Path`, `Bytes`, `Modified` | file |
| `SidecarPath` | sidecar path or `""` |
| `NChanBin`, `Fs`, `NSamples`, `SourceFolder` | from the sidecar; `NaN` / `""` when absent |

### Kilosort4 runs (`emptyKSRuns` schema)

A run folder is any folder containing one of `spike_clusters.npy`, `params.py`,
`run_ks4.py`, `settings.json` or `ks4_status.json` (the constant
`DatasetTracker.KilosortMarkers`).

| Field | Meaning |
| --- | --- |
| `Name`, `Dir` | folder |
| `HasResults` | `spike_clusters.npy` present |
| `State`, `Message` | from `ks4_status.json`. If there is no status file but results exist, `State` is `"done"` |
| `NumUnits` | data rows of `cluster_KSLabel.tsv` (falling back to `cluster_group.tsv`), blank lines excluded; `NaN` if neither file exists |
| `SettingsPath`, `ScriptPath`, `LogPath`, `StatusPath` | paths or `""` |
| `BinFile`, `ProbeFile`, `Fs`, `NChanBin` | from `settings.json` |
| `Modified` | newest modification time among the folder's direct files |

## Methods

| Method | Returns |
| --- | --- |
| `refresh()` | re-scan and rebuild every inventory |
| `ds = recording(idxOrName, AutoMetadata=false)` | an `EphysDataset` for one tracked recording |
| `probeFile(idx)`, `binFile(idx)` | full path of the idx-th item (default 1) |
| `kilosortRun(idx)` | the idx-th run struct |
| `latestKilosortRun()` | most recently modified run, **preferring runs with results**; `[]` if none |
| `hasBin()`, `hasProbe()` | at least one of each found |
| `hasKilosort()` | at least one run has `spike_clusters.npy` |
| `recordingTable()` | table: `Name`, `Folder`, `Format`, `NumFiles`, `AcqDate`, `SizeMB` |
| `kilosortTable()` | table: `Name`, `State`, `HasResults`, `NumUnits`, `Modified` |
| `disp(dt)` | concise text summary |

Index errors raise `DatasetTracker:BadIndex`. Unknown recording names raise
`DatasetTracker:NoSuchRecording`.

## Static helpers

These are public so the other Intan classes can reuse one implementation.

| Helper | Purpose |
| --- | --- |
| `listFiles(root, pattern, recursive)` | `dir` matches, excluding directories |
| `findRecordings(root, recursive, options)` | the `Recordings` struct array (through the reader registry, with reader options) |
| `findRecordingFolders(root, recursive, options)` | folder paths only |
| `readJson(path)` | `jsondecode(fileread(path))`, or `[]` on any failure |
| `classifyJson(s)` | see the rules below |
| `probeMeta(s)` | `nChan`, `nShank`, `depth`, `notes` from a decoded probe |
| `kilosortRunAt(folder)` | the `KilosortRuns` element of one known run folder, `[]` when it holds none of the `KilosortMarkers`; nothing else is scanned |
| `emptyRecordings()`, `emptyProbes()`, `emptyBins()`, `emptyKSRuns()` | 0×0 templates that define the schemas |

`classifyJson(s)` applies these rules, most specific first:

1. has `results_dir` and `probe` → `"ks-settings"`
2. has `bin_file` or `source_folder` → `"bin-sidecar"`
3. has `state` → `"ks-status"`
4. has `chanMap`, or has both `xc` and `yc` → `"probe"`
5. has `schema` starting with `ephys-recording/` → `"recording-descriptor"`
6. otherwise → `"other"`

## Example

```matlab
dt = DatasetTracker("D:\rec\subj1_day1");
disp(dt)
T  = dt.recordingTable();
if dt.hasKilosort
    r = dt.latestKilosortRun();   % r.Dir holds params.py / spike_clusters.npy
end
ds = dt.recording(1, AutoMetadata=true);
```

## Tests

[`test_DatasetTracker.m`](../pipeline/test_DatasetTracker.m) builds a synthetic tree
(empty `*.rhd` files, a `.bin` + sidecar, a probe `.json` plus a decoy `.json`,
two `kilosort4` folders) and checks recordings, probe classification, bin
sidecars, Kilosort4 runs, accessors/tables, and non-recursive/empty behavior.
