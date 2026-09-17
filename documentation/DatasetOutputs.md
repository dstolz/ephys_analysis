# DatasetOutputs

`DatasetOutputs` ([source](../pipeline/@DatasetOutputs/DatasetOutputs.m)) is a
`handle` class that tracks **one dataset's processed files** and loads each
one only when you ask for it. It gives analysis scripts one way to reach the
preprocessed data, wherever the pipeline wrote it:

```matlab
out = ds.outputs();                          % from an EphysDataset
out = DatasetOutputs("D:\out\subj1_day1");   % or from a folder alone

FT  = out.FieldTrip;     % the variables of <Name>_fieldtrip.mat
lfp = out.LFP;           % only the extract file that holds LFP
u   = out.Units;         % Kilosort4 / phy sorted units
beh = out.Behavior;      % the Epsych2 session data
```

It reads no recording data. A folder of processed files copied to another
machine is enough.

`DatasetTracker` answers "what exists under this directory" for many
recordings (probe maps, `.bin` files, Kilosort4 runs). `DatasetOutputs` answers
"give me this dataset's data" for one.

## Construction

```matlab
out = DatasetOutputs(ds)                      % an EphysDataset
out = DatasetOutputs(folder)                  % Name = the folder leaf
out = DatasetOutputs(folder, Name="subj1_day1", SearchDirs="E:\exports")
out = ds.outputs(SearchDirs=..., Recursive=false, CacheData=true)
out = pipe.outputsFor(ds)                     % adds the config's step OutputDirs
out = DatasetOutputs()                        % empty; set Name / Folder, then refresh()
```

| Option | Default | Meaning |
| --- | --- | --- |
| `Name` | `ds.Name`, else the folder leaf | files must start with it |
| `SearchDirs` | none | extra folders to search |
| `Recursive` | `true` | search sub-folders of every root |
| `CacheData` | `false` | keep loaded data in memory; `clearCache()` frees it |
| `AutoRefresh` | `true` | scan on construction |

`EphysPipeline.outputsFor(d)` adds the config's `Signals.OutputDir`,
`Spikes.OutputDir` and `Export.OutputDir` to `SearchDirs`, so files written
by that config into shared folders are found as well.

## Discovery

`refresh()` scans the **roots**: `ds.outputFolder()` and `ds.Folder` for a
dataset, or the folder given, plus `SearchDirs`. It lists every `*.mat` whose
name is `Name` followed by `_`, `-`, `.` or a space, skips `~*.partial.mat`
files, and classifies each file by the **variables it holds**. The suffix does
not matter, so configured `Suffix` values are found:

| Kind | Variables | Written by |
| --- | --- | --- |
| `extract` | `Y` + `info` | `toMat` (Signals step); `<...>_LFP.mat` etc. are per-type files |
| `spikes` | `detected` + `units` + `conversion` | `spikesToMat` |
| `behavior` | `behavior` + `conversion` | `behaviorToMat` (behavior step) |
| `chronux` | `export` + `sp` / `spDetected` | `exportChronux` |
| `fieldtrip` | `export` + `event` / `spike` / `data_*` | `exportFieldTrip` |
| `manifest` | `<Name>_manifest.json` | `writeManifest` |
| `artifacts` | `<Name>_artifacts.json` | `EphysPipeline` artifact cache |

A file whose `conversion.dataset` / `export.dataset` names a different dataset
is skipped. This separates `rec1` from `rec1_b` in a shared folder. Every file
found is listed in `Candidates` (`Kind`, `File`, `Signal`, `Modified`, `Bytes`).
When a kind has several files, **the newest wins**.

The other two paths are resolved when they are read:

- **`SortingDir`**: the dataset's `sortingResultsDir()` when it holds
  `params.py`, else the manifest's `sorting.results_dir`, else the standard
  `kilosort4/si/sorter_output` / `kilosort4` layouts under the roots.
- **`BehaviorFile`**: the newest `<Name>_behavior.mat`. Until one has been
  written, it is the associated Epsych2 session: the dataset's `BehaviorFile`,
  else the manifest's `behavior.file`. Both load into the same struct.

The scan is a snapshot. Call `refresh()` after writing new outputs.

## Paths in effect, and pinning them

| Property | Kind |
| --- | --- |
| `ExtractFiles` | the newest file per signal type plus the newest combined file, newest first |
| `SpikesFile`, `ChronuxFile`, `FieldTripFile`, `BehaviorFile`, `ManifestFile`, `ArtifactsFile` | one file |
| `SortingDir` | a phy results folder |

Reading a path property returns the path in effect. **Assigning** one pins it.
Assigning `""` returns that kind to discovery.

```matlab
out.FieldTripFile = "E:\shared\subj1_ft_v2.mat";
out.SortingDir    = "E:\curated\subj1_day1";
out.ExtractFiles  = ["D:\a\subj1_LFP.mat" "D:\b\subj1_MUA.mat"];
out.pathSource("fieldtrip")    % "manual" | "discovered" | "dataset" | "manifest" | ""
```

## Loading

| Property | Returns |
| --- | --- |
| `Extract` | every `ExtractFiles` file merged into one `toMat`-shaped struct (`Y`, `info`, `events`, `conversion`); when two files hold the same signal the newer one wins |
| `LFP`, `MUA`, `SPIKE`, `AUX` | the `toMat`-shaped struct of the newest file holding that signal, with `Y` / `info` reduced to it |
| `Spikes`, `Chronux`, `FieldTrip` | the file's variables as a struct |
| `Units` | `ds.readSortedUnits(ResultsDir=SortingDir)`, or without a dataset `EphysDataset.readPhyUnits(SortingDir)` with the manifest's probe file |
| `Behavior` | `trials`, `info`, `meta`, `file`, `subject`, `startTime`, `nTrials` |
| `Manifest`, `Artifacts` | the decoded JSON |

Each read loads from disk again unless `CacheData` is on. A missing file
raises `DatasetOutputs:Missing`, and the message names the roots searched and
the property to set.

| Method | Does |
| --- | --- |
| `has(kind)` | true when the file (or `params.py`) exists; `kind` is a `Kinds` value or `"LFP"` / `"MUA"` / `"SPIKE"` / `"AUX"` |
| `load(kind, vars...)` | loads only the listed variables, e.g. `out.load("fieldtrip", "data_LFP", "event")` |
| `readUnits(Name=Value)` | `Units` with reader options (`Groups`, `IncludeNoise`, `Templates`, ...) |
| `signalFile(type)` | the extract file that holds a signal (`""` when none) |
| `inventory()` | table per kind: `Property`, `Path`, `Source`, `Exists`, `Bytes`, `Modified`, `NumCandidates` |
| `refresh()`, `clearCache()` | re-scan; free cached data |

Displaying the object shows the paths only. It never loads data.

## Example: a batch analysis script

```matlab
P = EphysProject("D:\experiments");
P.refresh();
for ds = P.Datasets
    out = ds.outputs();
    if ~out.has("fieldtrip") || ~out.has("behavior"); continue; end
    ft  = out.load("fieldtrip", "data_LFP", "event");
    beh = out.Behavior;
    % ... ft.data_LFP, ft.event, beh.trials
end
```

## Tests

[`test_DatasetOutputs.m`](../pipeline/test_DatasetOutputs.m) covers classification
by variables, how decoys are rejected (name prefix, provenance, partial files),
newest-wins selection, merged and per-signal extracts, units, behavior from
the written file and from the session, pinning and `SearchDirs`, caching, and
dataset mode on a small universal-format recording.
