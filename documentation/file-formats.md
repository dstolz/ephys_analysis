# Files on disk

This page lists every file the pipeline reads or writes, where it lives, and
its schema. JSON is written through `writeJsonFile` (pretty-printed, written to
a temporary file and renamed, so a reader never sees a half-written file).
`NaN` / `Inf` are written as `null` except where a schema says they are
written as the strings `"NaN"` / `"Inf"`.

## Folder layout

```text
<Folder>/                               raw recording folder (never modified except for the manifest)
├─ *.rhd                                Intan traditional layout, or
├─ info.rhd + amplifier.dat + ...       Intan one-file-per-signal, or
├─ info.rhd + amp-<native>.dat ...      Intan one-file-per-channel, or
├─ recording.json + <data>.bin          the universal binary format (any acquisition system)
└─ <Name>_manifest.json                 dataset manifest (writeManifest)

<outputFolder>/                         = Folder, or OutputDir, or <OutputRoot>/<Name>
├─ <Name>_artifacts.json                artifact-interval cache (EphysPipeline)
├─ <Name>_extract.mat                   derived signals (toMat; the Signals step)
├─ <Name>_spikes.mat                    detected / sorted spikes (spikesToMat; the Spikes step)
├─ <Name>_chronux.mat                   Chronux export (exportChronux; the Export step)
├─ <Name>_fieldtrip.mat                 FieldTrip export (exportFieldTrip; the Export step)
├─ <Name>.bin + <Name>.json             EphysDataset.toBin (legacy engine only)
└─ kilosort4/                           kilosortDir()
   ├─ si_config.json                    SpikeInterface engine config
   ├─ run_si_ks4.py                     copy of the driver used for this run
   ├─ ks4_run.log                       captured stdout/stderr
   ├─ ks4_status.json                   {"state": "done"|"error", ...}
   ├─ si/                               run_sorter folder, WIPED on every run
   │  └─ sorter_output/                 Kilosort4 phy output (params.py, *.npy, *.tsv)
   │
   │  -- legacy runKilosort engine writes instead, directly in kilosort4/ --
   ├─ settings.json, run_ks4.py
   ├─ <probe>_excluded.json             derived probe when channels are excluded
   └─ params.py, spike_*.npy, templates.npy, cluster_*.tsv, ...

<anywhere>/
├─ <config>.json                        pipeline config (EphysPipelineConfig.save; File → Save)
└─ <script>.m                           generated script (EphysPipelineScript; File → Generate script)
```

Output folders for the Signals, Spikes and Export steps can each be redirected
with their section's `OutputDir`. Sorted output can live anywhere: the manifest
records the folder that is associated with the dataset.

---

## Universal recording format (`recording.json`)

Any acquisition system can feed the pipeline by converting its recording to a
flat binary plus this descriptor; [`BinaryReader`](EphysDataset.md#acquisition-readers)
reads it and SpikeInterface reads it with `read_binary`. The data file is
**channel-major per sample** (all channels of sample 1, then sample 2, ...): the
Kilosort4 layout, and what `EphysDataset.toBin` writes.

```text
{
  "schema":        "ephys-recording/1",
  "name":          "subj1_day1",                (optional; default = folder leaf)
  "data_file":     "subj1_day1.bin",            relative to the folder
  "dtype":         "int16",                     int16 | uint16 | int32 | single | float32 | double
  "n_chan":        64,
  "fs":            30000,
  "n_samples":     18000000,                    (optional; else from the file size)
  "byte_order":    "little-endian",             (optional; default)
  "gain_to_uV":    0.195,                       microvolts = (raw - offset) * gain_to_uV
  "offset":        0,                           raw units subtracted before the gain
  "channel_names": ["ch1", ...],                (optional; default "ch1".."chN")
  "native_names":  ["A-000", ...],              (optional; default = channel_names)
  "dig_in_names":  ["din0", ...],               (optional)
  "dig_in_file":   "digitalin.dat",             (optional) uint16 per sample, bit k = line k
  "events":        {"din0": [[t_on, t_off], ...]},   (optional) seconds, t = row/Fs
  "acq_date":      "2026-09-16 10:00:00",       (optional)
  "source":        {...}                        (optional free-form provenance)
}
```

`BinaryReader.writeDescriptor(folder, spec)` writes a validated descriptor.
Only `recording.json` marks a folder as a recording, so the `.bin` + sidecar
pairs that `toBin` writes into output folders are never mistaken for one.
`RecordingFormat` for these datasets is `"binary"`; the manifest's `reader` is
`"binary"`.

---

## Dataset manifest

Path: `<Folder>/<Name>_manifest.json`. Written by `EphysDataset.writeManifest`;
`EphysProject.refresh()` (the GUI's Scan, `EphysPipeline`, generated scripts)
rewrites it after restoring the saved state with `applyManifest`. The GUI
also writes it on probe assignment, exclusion changes, manual artifact edits,
sorting and behavior associations, and each sorting launch / completion.

Schema `intan-dataset-manifest/2` (`null` where a value is `NaN`):

```text
{
  "schema":           "intan-dataset-manifest/2",
  "name":             <dataset Name>,
  "folder":           <recording folder>,
  "recording_format": "traditional" | "one-file-per-signal" | "one-file-per-channel" | "binary" | "unknown",
  "reader":           "intan" | "binary",
  "updated":          <"yyyy-MM-dd HH:mm:ss">,
  "metadata": {
    "fs": <Hz>, "num_channels": <n>, "duration_s": <s>, "num_files": <n>,
    "acq_date": <"yyyy-MM-dd HH:mm:ss" or "">, "files": [<file names>]
  },
  "probe": {
    "file": <probe .json path or "">, "num_channels": <n>, "num_shanks": <n>,
    "depth_um": <max(yc)-min(yc)>, "notes": <string>
  },
  "exclude_channels": <compact list, e.g. "5,17-18", or "">,
  "manual_artifacts": [[<t0>, <t1>], ...],          seconds, recording-relative
  "bin":      { "file": <BinFile path>, "exists": <true|false> },
  "kilosort": { "has_results": <bool>, "results_dir": <path or "">,
                "num_units": <n or null>, "state": <string> },
  "sorting":  { "results_dir": <folder holding params.py, or "">,
                "source": "auto" | "manual", "curated": <bool>,
                "num_units": <n or null>, "updated": <"yyyy-MM-dd HH:mm:ss" or ""> },
  "behavior": { "file": <Epsych2 .mat or "">, "subject": <string>,
                "start_time": <"yyyy-MM-dd HH:mm:ss" or "">, "n_trials": <n or null> },
  "engine":   "spikeinterface",
  "preprocessing": { <the dataset's SIConfig fields> }
}
```

- `sorting` is the sorted-output association (`EphysDataset.sortingResultsDir`):
  `source` is `"manual"` when `SortingDir` was set explicitly (GUI **Use
  folder...**), else `"auto"` (the `kilosort4/si/sorter_output` probe).
  `curated` is true when `cluster_group.tsv` exists (phy was used).
- `kilosort` is the older `DatasetTracker.latestKilosortRun()` block and is
  kept for the tracker tables; `state` there is the tracker's fallback `"done"`
  whenever results exist. The real run state is in `kilosort4/ks4_status.json`.
- `applyManifest()` restores `probe.file` (if the file exists),
  `exclude_channels`, `manual_artifacts`, a `"manual"` `sorting.results_dir`
  (if its `params.py` still exists) and `behavior.file` (if it exists).
  Detector, SpikeInterface and step settings are **not** stored here; they are
  in the pipeline config.
- Schema `/1` manifests (probe + exclusions only) are still read; `/2` is a
  superset. Any other schema is ignored with a warning.

---

## Pipeline config JSON

Written by `EphysPipelineConfig.save` (GUI **File → Save config**). Default
folder for the GUI's dialogs: [`intan/pipeline_configs`](../intan/pipeline_configs),
which holds `H64LP_4x16.json` as a starting point.

```text
{
  "schema":      "ephys-pipeline-config",
  "version":     1,
  "name":        <string>,
  "description": <string>,
  "Project":   { "Root", "OutputRoot", "Selection", "Datasets" },
  "Probe":     { "DefaultProbeFile", "WriteDefaultToManifest" },
  "Behavior":  { "Enabled", "SearchDirs", "Match", "MaxStartOffsetMin", "Overwrite" },
  "Artifacts": { "Enabled", "Method", "Threshold", ... , "ApplyToSorting", "ApplyToSpikes", "CacheIntervals" },
  "Sorting":   { "Enabled", "PythonExe", "CondaEnv", "Execution", "DryRun", "SkipExisting",
                 "SI": {...}, "KS4": {...}, "KS4ExtraJSON" },
  "Signals":   { "Enabled", "OutputDir", "Suffix", ... , "ExcludeHandling", "IncludeBehavior" },
  "Spikes":    { "Enabled", "Source", ... , "Groups", "IncludeNoise", "Templates", "OutputDir", "Suffix", ... },
  "Export":    { "Enabled", "Formats", "Signals", "IncludeUnits", ... }
}
```

The field lists are those of `EphysPipelineConfig.defaults(section)`
([EphysPipeline.md](EphysPipeline.md#sections)). `Inf` / `NaN` are written as
the strings `"Inf"` / `"NaN"` and read back as numbers; empty lists as `[]`.
`KS4` holds one **typed** value per Kilosort4 parameter; nullable parameters
left blank are `[]` and are omitted from the settings sent to Kilosort4.
Loading a file with another `schema` / `version` fails
(`EphysPipelineConfig:BadSchema`); unknown fields are dropped and listed in
`LoadWarnings`.

---

## Artifact cache

Path: `<outputFolder>/<Name>_artifacts.json`. Written by
`EphysPipeline.artifactIntervalsFor` when `Artifacts.CacheIntervals` is on.

```text
{ "schema": "ephys-artifacts/1", "dataset": <Name>, "fingerprint": <string>,
  "intervals": [[t0, t1], ...], "nIntervals": <n>, "created": <timestamp> }
```

`fingerprint` is `jsonencode` of the artifact config and the manual periods;
a cache whose fingerprint differs from the current settings is recomputed.

---

## Kilosort4 probe JSON

Stored in [`intan/probes`](../intan/probes/README.md) by default. This is
the shape `kilosort.io.load_probe` accepts:

```json
{
  "notes":   "optional free text",
  "chanMap": [0, 1, 2, 3],
  "xc":      [0, 0, 0, 0],
  "yc":      [0, 20, 40, 60],
  "kcoords": [0, 0, 0, 0],
  "n_chan":  4
}
```

- `chanMap`: **0-based** channel per site. Throughout the MATLAB code, the
  1-based `.bin` channel of a site is `chanMap + 1`. For how the SpikeInterface
  engine interprets it, see
  [python-drivers.md](python-drivers.md#channel-numbering-caveat).
- `xc`, `yc`: site positions in µm.
- `kcoords`: shank per site. Optional; treated as all zeros when absent.
- `n_chan`: total channels. Every channel-count check in the code uses
  `max(n_chan, numel(chanMap))`, ignoring a missing `n_chan`. An `n_chan`
  smaller than the map length is treated as wrong.
- `notes`: optional. The GUI Probe tab edits it in place with a minimal textual
  replacement, so the rest of the file's formatting is preserved.

---

## `.bin` JSON sidecar

Path: `<outputFolder>/<Name>.json`, next to the `.bin`. Written by
`EphysDataset.toBin` (`WriteMeta=true`). Kilosort4 does not read it.
`runKilosort` reads `n_chan_bin` / `fs` from it, and `DatasetTracker` reads
`n_chan_bin`, `fs`, `n_samples` and `source_folder`.

| Field | Meaning |
| --- | --- |
| `n_chan_bin`, `fs`, `dtype`, `n_samples`, `byte_order`, `scale`, `offset` | what was written |
| `bin_file`, `source_folder` | paths |
| `manual_artifacts` | `[k x 2]` seconds (the `ManualArtifacts` in effect) |
| `n_manual_blanked` | samples zeroed by manual periods |
| `auto_artifacts` | `enabled`, `method`, `threshold`, `rmsWindowMs`, `mergeGapMs`, `minChannels`, `padMs`, `nBlanked`, `fraction`, `pctDuration`, `nIntervals`, `channelCounts` |
| `created` | timestamp |

`matrixToBin` delegates to [`matrix2kilosort`](../matrix2kilosort.m), which
writes its own sidecar. See that function's help for its fields.

---

## `si_config.json`

Path: `<kilosort4>/si_config.json`. Written by
`EphysDataset.runSpikeInterface` and consumed by `run_si_ks4.py`.

Schema (placeholders in `<...>`; all paths use forward slashes):

```text
{
  "schema":           "intan-si-ks4/1",
  "folder":           <recording folder>,
  "recording_format": <RecordingFormat>,
  "files":            [<*.rhd names in order, or ["info.rhd"]>],
  "fs":               <Hz>,
  "n_chan":           <amplifier channels>,
  "recording":        <the reader's siRecordingSpec(), see below>,
  "probe":            <absolute probe .json path>,
  "exclude_channels": [<0-based positions>],
  "results_dir":      <kilosort4>/si,
  "status_path":      <kilosort4>/ks4_status.json,
  "log_path":         <kilosort4>/ks4_run.log,
  "preprocessing": {
    "filter":              { "enabled": <bool>, "freq_min": <Hz>, "freq_max": <Hz> },
    "common_reference":    { "enabled": <bool>, "operator": "median" | "average" },
    "detect_bad_channels": { "enabled": <bool>, "method": <string>, "action": "remove" | "interpolate" },
    "silence_periods":     { "enabled": <bool>, "periods_s": [[<t0>, <t1>], ...] }
  },
  "ks4": { <Kilosort4 settings> }
}
```

- `recording` tells the driver how to load the data: `{"reader": "intan",
  "folder", "recording_format", "files"}` for Intan recordings, or
  `{"reader": "binary", "file", "dtype", "n_chan", "fs", "gain_to_uV",
  "offset", ...}` for the universal format. Configs without it are treated as
  Intan.
- `exclude_channels` are **0-based** positions (`ExcludeChannels − 1`).
- `silence_periods.periods_s` is the merged manual + automatic list from
  `artifactIntervals()`, in recording-relative seconds. This file is the record
  of which periods a run actually silenced.
- `ks4` is the Kilosort4 settings block (`EphysPipelineConfig.ks4Settings` or
  `ExtraSettings=`). `do_CAR: false` is added when the common reference is
  enabled and `do_CAR` was not set explicitly.

## `settings.json` (legacy `runKilosort` engine)

Path: `<ResultsDir>/settings.json`. Fields: `n_chan_bin`, `fs`, `data_dtype`
(from `ds.Dtype`), `filename` (the `.bin`), `probe` (original or
`_excluded.json` probe), `results_dir`, plus any `ExtraSettings` fields. Paths
use forward slashes.

## `ks4_status.json`

Path: in the run folder. Written by the Python driver when it finishes.

| Engine | Success | Failure |
| --- | --- | --- |
| SpikeInterface | `{"state":"done","num_units":N,"bad_channels":[...],"dropped_params":[...]}` | `{"state":"error","message":"...","traceback":"..."}` |
| legacy | `{"state":"done"}` | `{"state":"error","message":"...","traceback":"..."}` |

Both engines delete a stale status file before launching. The GUI's background
monitor polls this file every 3 s.

## Kilosort4 / phy output

Read by `EphysDataset.readPhyUnits` (the one reader used by the Review tab,
`spikesToMat`, `ChronuxDataset.spikes` and both exporters) from the folder
that holds `params.py`:

- Required: `spike_times.npy`, `spike_clusters.npy`.
- Optional: `amplitudes.npy`, `templates.npy`, `spike_templates.npy`,
  `channel_map.npy`, `channel_shanks.npy`, `channel_positions.npy`,
  `whitening_mat_inv.npy`, `cluster_group.tsv` (phy's curated labels, preferred)
  else `cluster_KSLabel.tsv`, `cluster_Amplitude.tsv`, `cluster_ContamPct.tsv`.
- Sample rate: `sample_rate` from `params.py`; otherwise the call errors
  unless `FsFallback=` is given (never a silent 30 kHz).

`.npy` files are read with the built-in little-endian `readNPY` and written
(tests, fixtures) with `writeNPY`. No toolbox is needed.

---

## Derived-signal `.mat` (`EphysDataset.toMat`; the Signals step)

Default `<outputFolder>/<Name>_extract.mat`:

| Variable | Contents |
| --- | --- |
| `Y` | struct with `LFP`, `MUA`, `SPIKE` (`single`, `[nSamples x nChan]`); unrequested fields are `single([])` |
| `events` | struct, one field per digital-input line, `[k x 2]` `[t_on t_off]` seconds |
| `info` | see [intan2matlab.md](intan2matlab.md#outputs) |
| `behavior` | Epsych2 session data (`EphysDataset.behaviorStruct`) or `[]` |
| `conversion` | `tool`, `created`, `dataset`, `sourceFolder`, `recordingFormat`, `matFileVersion`, `matlabVersion` |

## Spikes `.mat` (`EphysDataset.spikesToMat`; the Spikes step)

Default `<outputFolder>/<Name>_spikes.mat`. The file is rewritten as a whole;
sources that were not requested are `[]`.

| Variable | Contents |
| --- | --- |
| `detected` | `ts {1 x nChan}` spike times (s, `(index-1)/Fs`, recording-relative); `wf {1 x nChan}` `[nSpikes x nWin]` µV or `[]`; `info` (`detectSpikes` info filtered to the kept events); `channels` (1-based recording channels); `channelNames`; `detection` (options used, artifact intervals applied, `nRejectedArtifact` per channel) |
| `units` | the `readSortedUnits` struct: `unitId`, `label`, `group`, `nSpikes`, `samples`, `times`, `ksChannel`, `channel`, `shank`, `amplitude`, `contamPct`, `templateWaveform`, `templateTimeMs`, plus `fs`, `resultsDir`, `engine`, `groupSource`, `curated`, `channelMap`, `channelMapSource`, ... |
| `behavior` | as above, or `[]` |
| `conversion` | provenance |

## Chronux export (`EphysDataset.exportChronux`; the Export step)

Default `<outputFolder>/<Name>_chronux.mat`. Everything is in the shapes the
Chronux functions take; no Chronux function is called to produce it.

| Variable | Contents |
| --- | --- |
| `LFP` / `MUA` / `SPIKE` | one struct per exported signal: `data` `[nSamples x nChan]` double µV, `params` (Chronux params with `Fs` = the signal rate), `t` (`(k-1)/Fs`), `labels`, `info` |
| `sp` | `1 x nUnits` struct array with field `times` (sorted units), or `[]` |
| `spDetected` | the same for threshold-detected spikes, one element per channel, or `[]` |
| `units`, `detected` | the source structs, or `[]` |
| `events` | dig-in lines → `[k x 2]` seconds |
| `behavior` | as above, or `[]` |
| `export` | `tool`, `created`, `dataset`, `sources`, `signals` |

## FieldTrip export (`EphysDataset.exportFieldTrip`; the Export step)

Default `<outputFolder>/<Name>_fieldtrip.mat`. Structures follow
`ft_datatype_raw`, `ft_datatype_spike` and `ft_read_event`
([FieldTripExport.md](FieldTripExport.md)).

| Variable | Contents |
| --- | --- |
| `data_LFP` / `data_MUA` / `data_SPIKE` | raw structures, one trial spanning the signal; `cfg.event` holds the events at that signal's rate |
| `spike` | spike structure of the sorted units (`timestamp` in recording samples), or `[]` |
| `spikeDetected` | the same, one "unit" per detected channel, or `[]` |
| `event` | event struct array at the recording rate |
| `behavior` | as above, or `[]` |
| `export` | `tool`, `created`, `dataset`, `sources`, `signals`, `eventFs`, `validation` |

All four `.mat` writers save to `~<name>.partial.mat` and rename only after a
warning-free `save()` in which every variable is confirmed present
(`EphysDataset.saveAtomically`).
