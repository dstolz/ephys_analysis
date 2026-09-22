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
├─ recording.json + <data>.bin          the universal binary format (any acquisition system), or
├─ Record Node <id>/                    an Open Ephys GUI session (see below)
├─ <part name>/openephys-part.json      Open Ephys "separate" mode: one part folder per recording (a dataset)
├─ session_manifest.json                where the Copy tab copied the session from (copySessions)
├─ session_copy_robocopy.log            the copy engine's robocopy log
├─ <Name>_manifest.json                 dataset manifest (writeManifest)
└─ <Name>_cleanup.json                  what Clean up removed (runLocalCleanup)

<outputFolder>/                         = Folder, or OutputDir, or <OutputRoot>/<Name>
├─ <Name>_artifacts.json                artifact-interval cache (EphysPipeline)
├─ <Name>_extract_<TYPE>.mat            derived signals, one file per type (toMat; the Signals step),
│                                       or <Name>_extract.mat with Signals.SeparateFiles off
├─ <Name>_spikes.mat                    detected / sorted spikes (spikesToMat; the Spikes step)
├─ <Name>_behavior.mat                  Epsych2 session data, the only copy (behaviorToMat; the behavior step)
├─ <Name>_events.mat                    digital-input events cache (digitalEvents; trial pairing)
├─ <Name>_chronux.mat                   Chronux export (exportChronux; the Export step)
├─ <Name>_fieldtrip.mat                 FieldTrip export (exportFieldTrip; the Export step)
├─ <Name>.bin + <Name>.json             EphysDataset.toBin (native Kilosort4 engine only)
└─ kilosort4/                           kilosortDir()
   ├─ si_config.json                    SpikeInterface engine config
   ├─ run_si_ks4.py                     copy of the driver used for this run
   ├─ ks4_run.log                       captured stdout/stderr
   ├─ ks4_status.json                   {"state": "done"|"error", ...}
   ├─ si/                               run_sorter folder, WIPED on every run
   │  └─ sorter_output/                 Kilosort4 phy output (params.py, *.npy, *.tsv;
   │                                    cluster_notes.tsv holds per-unit notes)
   │
   │  -- the native engine (runKilosort) writes instead, directly in kilosort4/,
   │     and deletes si/ first --
   ├─ settings.json, run_ks4.py
   ├─ <probe>_excluded.json             derived probe when channels are excluded
   └─ params.py, spike_*.npy, templates.npy, cluster_*.tsv, ...

<anywhere>/
├─ <config>.json                        pipeline config (EphysPipelineConfig.save; File → Save)
└─ <script>.m                           generated script (EphysPipelineScript; File → Generate script)

<probe folder>/                         pipeline/probes by default
├─ <probe>.json                         Kilosort4 probe map
└─ <probe>.ks4.json                     its Kilosort4 parameters (writeKS4Params; Sorting → Optimize for probe)
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
`"binary"`. The optional `"channel_numbers": [0, 1, ...]` gives each channel's
hardware number (what a probe `chanMap` refers to; default `0..n_chan-1`).

---

## Open Ephys GUI sessions

[`OpenEphysReader`](EphysDataset.md#open-ephys-sessions) reads the folders the
Open Ephys GUI writes; they are never modified. A session folder (named by the
GUI from its prepend text, start time and append text) holds one folder per
Record Node:

```text
SUBJ01_2026-09-17_10-30-00/                  the session folder = the dataset
└─ Record Node 101/
   │  -- Binary (the GUI default) --
   ├─ settings.xml                           signal chain (settings_<E>.xml for later experiments)
   └─ experiment1/recording1/
      ├─ structure.oebin                     JSON: streams (folder_name, sample_rate, num_channels,
      │                                      channels: channel_name, bit_volts, units, type 0/1/2),
      │                                      event channels (folder_name, initial_state)
      ├─ sync_messages.txt                   "Software Time (...): <ms since 1970 UTC>", "Start Time for ...: <sample>"
      ├─ continuous/<proc>-<id>.<stream>/    continuous.dat (int16, channels interleaved),
      │                                      sample_numbers.npy (int64), timestamps.npy (float64)
      └─ events/<proc>-<id>.<stream>/TTL/    states.npy (int16, +/- line), sample_numbers.npy,
                                             timestamps.npy, full_words.npy (uint64 TTL word)
   │  -- Open Ephys format --
   ├─ <proc>_<stream>_<channel>[_<E>].continuous   1024-byte text header (sampleRate, bitVolts,
   │                                         date_created), then 2070-byte records: int64 first
   │                                         sample, uint16 1024, uint16 recording (0-based),
   │                                         1024 big-endian int16, 10-byte marker
   ├─ <proc>_<stream>[_<E>].events           1024-byte header, then 16-byte records: int64 sample,
   │                                         int16, uint8 type (3 = TTL), uint8 processor, uint8
   │                                         state, uint8 line (0-based), uint16 recording
   ├─ messages[_<E>].events                  "<ms>, Software Time (...)" per recording
   ├─ structure[_<E>].openephys              XML (not needed to read)
   │  (GUI 0.4 / 0.5: <proc>_<channel>[_<E>].continuous and all_channels[_<E>].events)
   │  -- NWB 2 --
   └─ experiment<E>.nwb                      /acquisition/<proc>-<id>.<stream>: data [samples x
                                             channels] int16, sync (sample numbers), timestamps,
                                             channel_conversion (V/bit), channel_type, electrodes;
                                             <...>.TTL: data (+/- line), sync, full_word;
                                             sync_messages: data (text), sync
```

`RecordingFormat` is `"openephys-binary"`, `"openephys-legacy"` or
`"openephys-nwb"`; the manifest's `reader` is `"openephys"`. Experiment 1
files have no suffix; experiment *E* > 1 adds `_<E>` (Open Ephys format) or
its own `experiment<E>` folder / file. Recordings of one experiment share its
files in the Open Ephys and NWB formats and have their own folders in Binary.

### Open Ephys part folders

With `Acquisition.OpenEphys.Recordings = "separate"` the scan represents each
recording of a multi-recording session by a part folder inside the session
folder, named from the recording's start (see
[EphysDataset](EphysDataset.md#open-ephys-sessions)) and holding
`openephys-part.json`:

```text
{
  "schema":      "openephys-part/1",
  "record_node": "101",
  "experiment":  1,
  "recording":   2
}
```

A part folder is a dataset like any other: its manifest and (without an output
root) its outputs are written into it. The scan creates missing part folders
and warns (`OpenEphysReader:PartFolder`) when the session is read-only. The
other modes ignore part folders.

---

## Copy manifest (`session_manifest.json`)

Path: `<Destination>/<SUBJ>/<recording folder name>/session_manifest.json`.
Written by `copySessions` (the app's Copy tab and each scheduled copy) in every
session folder it copies or finds already present; one that is already there
is left as it is.

```text
{
  "manifestVersion": 3,
  "subject": <subject ID>,
  "pairingStatus": "paired" | "stitched" | "recording_only" | "epsych_only",
  "deltaT_s": <ePsych start - recording start, s; null when unpaired>,
  "recording": {
    "reader": "intan" | "openephys" | "binary" | "",   the reader that read the folder (findCopySessions' Reader column)
    "sourceDir": <source recording folder>, "destDir": <session folder>,
    "time": <recording start from the folder name, ISO 8601>,
    "files": [ { "relativePath": <path below the folder, e.g. "Record Node 101\experiment1\...">,
                 "source": <source path>, "destination": <local path>,
                 "sizeBytes": <n at planning>, "sourceSizeBytes": <n>, "destSizeBytes": <n>,
                 "sha256Source": <hex or "">, "sha256Destination": <hex or ""> }, ... ]
  },
  "epsych": {
    "sourceFile": <ePsych file, "" for a stitched session>, "destFile": <local file>,
    "time": <ePsych start, ISO 8601>, "files": [ <as above> ],
    "stitch": null | { "file": <local ..._stitched.mat>, "sizeBytes", "nTrials", "sha256",
                       "parts": [ { "source", "name", "sizeBytes", "sourceSizeBytes",
                                    "nTrials", "sha256Source" }, ... ] }
  },
  "copy": { "status", "message", "verify": "size" | "hash", "ifExists", "numFiles",
            "totalBytes", "filesAlreadyPresent", "startedAt", "finishedAt",
            "host", "user", "robocopyLog" },
  "tool": { "name": "copySessions", "version": "3.0.0", "gitCommit": <hash or ""> }
}
```

The Clean up tab (`planLocalCleanup`) reads `recording.files`: a local file
listed there is a raw recording file with a known source.

---

## Clean-up record

Path: `<Folder>/<Name>_cleanup.json`. Written by `runLocalCleanup` (the app's
Clean up tab) in each dataset folder it removed files from; a later clean up
appends a run.

```text
{
  "schema":  "ephys-local-cleanup/1",
  "dataset": <dataset Name>,
  "folder":  <recording folder>,
  "runs": [
    { "time": <"yyyy-MM-dd HH:mm:ss">, "host": <computer>, "user": <user>,
      "bytesRemoved": <n>,
      "removed": [ { "file": <local path>, "category": "raw" | "sorter_copy" | "bin",
                     "bytes": <n>, "source": <source path for a raw file, else ""> }, ... ] }, ...
  ]
}
```

A raw file is only removed while its `source` holds a file of the same size,
so the record says where to copy each one back from.

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
  "recording_format": "traditional" | "one-file-per-signal" | "one-file-per-channel" | "binary" |
                      "openephys-binary" | "openephys-legacy" | "openephys-nwb" | "unknown",
  "reader":           "intan" | "binary" | "openephys",
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
                "start_time": <"yyyy-MM-dd HH:mm:ss" or "">, "n_trials": <n or null>,
                "pairing": null | { "status": "unreviewed" | "approved", "auto_approved": <bool>,
                  "cut_trials": [<from start>, <from end>], "cut_intervals": [<from start>, <from end>],
                  "fingerprint": <string>, "trial_line": <string>, "summary": <string>,
                  "updated": <"yyyy-MM-dd HH:mm:ss"> } },
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
folder for the GUI's dialogs: [`pipeline/pipeline_configs`](../pipeline/pipeline_configs),
which holds `H64LP_4x16.json` as a starting point.

```text
{
  "schema":      "ephys-pipeline-config",
  "version":     1,
  "name":        <string>,
  "description": <string>,
  "Project":   { "Root", "Recursive", "OutputRoot", "Selection", "Datasets", "NamePattern", "TokenColumns" },
  "Acquisition": { "OpenEphys": { "Recordings", "RecordNode", "Stream" } },
  "Parallel":  { "Enabled", "MaxWorkers" },
  "Probe":     { "DefaultProbeFile", "WriteDefaultToManifest" },
  "Behavior":  { "Enabled", "SearchDirs", "Match", "MaxStartOffsetMin", "Overwrite", "WriteFile",
                 "PairTrials", "AutoApprove", "TrialLine" },
  "Artifacts": { "Enabled", "Method", "Threshold", ... , "ApplyToSorting", "ApplyToSpikes", "CacheIntervals" },
  "Sorting":   { "Enabled", "Engine", "PythonExe", "CondaEnv", "Execution", "MaxConcurrent", "Devices", "DryRun", "SkipExisting",
                 "SI": {...}, "KS4": {...}, "KS4ExtraJSON" },
  "Signals":   { "Enabled", "OutputDir", "Suffix", ... , "LabelField", "LineNames", "InvertedLines", ... , "ExcludeHandling" },
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
{ "schema": "ephys-artifacts/2", "dataset": <Name>, "fingerprint": <string>,
  "intervals": [[t0, t1], ...], "nIntervals": <n>, "created": <timestamp> }
```

`intervals` are recording-relative seconds, half-open on the 0-based sample
clock: a period `[t0, t1)` covers samples `round(t0*fs)` to `round(t1*fs) - 1`,
the frames SpikeInterface's `silence_periods` zeros. `fingerprint` is
`jsonencode` of the schema, the artifact config, the manual periods and the
recording files; a cache whose fingerprint differs from the current settings
(including one written under schema 1) is recomputed.

---

## Kilosort4 probe JSON

Stored in [`pipeline/probes`](../pipeline/probes/README.md) by default. This is
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

## Kilosort4 probe parameters (`<probe>.ks4.json`)

Path: next to the probe map, `<folder>/<probe>.ks4.json` for
`<folder>/<probe>.json` (`EphysPipelineConfig.ks4ParamsFile`). Written by
`EphysPipelineConfig.writeKS4Params`, or by the app when **Optimize for probe**
generates it from the current parameters or from the probe layout. Read by
`EphysPipelineConfig.ks4ForProbe` (Sorting → Optimize for probe).

```json
{
  "schema":      "ephys-ks4-params/1",
  "probe":       "H64LP_4x16lin_probemap.json",
  "description": "Good defaults derived from the probe layout by EphysPipelineConfig.ks4ProbeDefaults. ...",
  "KS4": {
    "nblocks": 0, "dmin": 10, "dminx": 17.32, "nearest_chans": 10,
    "nearest_templates": 58, "min_template_size": 15, "x_centers": 4
  },
  "reasons": {
    "nblocks": "64 sites, at most 64: drift estimates are unreliable, so no drift correction",
    "...": "..."
  }
}
```

- `schema`: required; any other value is refused (`EphysPipelineConfig:BadParams`).
- `KS4`: the parameters to set, named as in `kilosortParamSpec` (any subset,
  at least one). Values are read as in a config file: `[]` or `null` is blank
  (Kilosort's own default) and `"Inf"` is `Inf`. An unknown name is refused.
  Parameters the file does not list keep their current values.
- `probe`, `description`, `reasons`: optional and informational. `reasons`
  holds one text per parameter, shown next to its value when the file is
  loaded. Other fields are ignored.
- Generated files hold `EphysPipelineConfig.KS4ProbeParams` (`nblocks`, `dmin`,
  `dminx`, `nearest_chans`, `nearest_templates`, `min_template_size`,
  `x_centers`).
- The Probe tab does not list `*.ks4.json` files as probes.

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

- `recording` tells the driver how to load the data. Every spec has
  `channel_numbers` (the dataset's `ChannelNumbers`); the driver renames the
  recording's channels to them, so the probe `chanMap` matches by number.
  Per reader:

  | `reader` | Fields | Loaded as |
  | --- | --- | --- |
  | `"intan"` | `folder`, `recording_format`, `files` | `read_intan` (amplifier stream) per file, concatenated |
  | `"binary"` | `file`, `dtype`, `n_chan`, `fs`, `gain_to_uV`, `offset`, `byte_order`, `channel_names` | `read_binary` |
  | `"openephys-binary"` | `fs`, `n_chan_stream`, `channel_indices` (0-based headstage positions), `gain_to_uV` (per headstage channel), `parts` [{`file` (continuous.dat), `n_samples`}] | `read_binary` per recording, concatenated, headstage channels selected |
  | `"openephys-legacy"` | as above, `parts` [{`channel_files` (one per headstage channel), `first_record`, `n_records`, `n_samples`}] | memory-mapped `.continuous` records, one segment per recording, concatenated |
  | `"openephys-nwb"` | as above, `parts` [{`file`, `dataset`, `row_start` (0-based), `n_samples`}] | the ElectricalSeries through h5py, one segment per recording, concatenated |

  The Open Ephys specs give the same rows as the MATLAB reader (stored samples,
  recordings end to end). Configs without a `recording` block are treated as
  Intan.
- `exclude_channels` are **0-based** positions (`ExcludeChannels − 1`).
- `silence_periods.periods_s` is the merged manual + automatic list from
  `artifactIntervals()`, in recording-relative seconds. This file is the record
  of which periods a run actually silenced.
- `ks4` is the Kilosort4 settings block (`EphysPipelineConfig.ks4Settings` or
  `ExtraSettings=`). `do_CAR: false` is added when the common reference is
  enabled and `do_CAR` was not set explicitly.

## `settings.json` (native `runKilosort` engine)

Path: `<ResultsDir>/settings.json`. Fields: `n_chan_bin`, `fs`, `data_dtype`
(from `ds.Dtype`), `filename` (the `.bin`), `probe` (original or
`_excluded.json` probe), `results_dir`, plus any `ExtraSettings` fields. Paths
use forward slashes. A `torch_device` field picks the GPU; the `--device`
argument a run gets from `Sorting.Devices` overrides it (the device a run
used is in `ks4_run.log` and the manifest's `launchSorting` entry, not
here).

## `ks4_status.json`

Path: in the run folder. Written by the Python driver when it finishes.

| Engine | Success | Failure |
| --- | --- | --- |
| SpikeInterface | `{"state":"done","num_units":N,"bad_channels":[<channel numbers as strings>],"dropped_params":[...]}` | `{"state":"error","message":"...","traceback":"..."}` |
| native | `{"state":"done","num_units":N,"dropped_params":[...]}` | `{"state":"error","message":"...","traceback":"..."}` |

A run stopped from MATLAB (`EphysDataset.stopSortRun`, the app's **Stop
runs...**) gets `{"state":"cancelled","message":"stopped by the user"}`,
written by MATLAB after it ends the run's processes.

`EphysDataset.launchSorting` deletes a stale status file before launching.
The GUI's background monitor polls this file every 3 s.

## `ks4_exit.txt`

Path: next to `ks4_status.json`. An empty file that the background launcher
writes once the Python process has exited, however it ended. A run with this
file but no status file failed before the driver could report (a missing
Python or conda env, a crash). `EphysDataset.sortRunState` reads the two
together. `stopSortRun` writes it too, since the launcher it ends never
gets to. Deleted before each launch.

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
- Unit position: `channel_positions.npy` gives each unit's peak site and
  template centre, `channel_shanks.npy` its shank.

### Unit notes (`cluster_notes.tsv`)

Written by `EphysDataset.writeUnitNotes` (the Review tab's Notes column) and by
phy, whose custom cluster labels use the same format; read into `units.notes`.

```text
cluster_id<TAB>notes
17<TAB>possibly two cells
42<TAB>clear refractory period; drifts after 40 min
```

One row per cluster with a note, sorted by id. Tabs and line breaks inside a
note are written as spaces; an empty note removes its row. In phy, label a
cluster with the field name `notes` to edit the same text.

`.npy` files are read with the built-in little-endian `readNPY` and written
(tests, fixtures) with `writeNPY`. No toolbox is needed.

---

## Derived-signal `.mat` (`EphysDataset.toMat`; the Signals step)

Default `<outputFolder>/<Name>_extract.mat`, or with `SeparateFiles` (the
Signals step's default) one `<outputFolder>/<Name>_extract_<TYPE>.mat` per
signal type (`LFP`, `MUA`, `SPIKE`), each holding only that signal in `Y` and
`info`:

| Variable | Contents |
| --- | --- |
| `Y` | struct with `LFP`, `MUA`, `SPIKE` (`single`, `[nSamples x nChan]`); unrequested fields are `single([])` |
| `events` | struct, one field per digital-input line, `[k x 2]` `[t_on t_off]` seconds; onset = rising edge, or falling edge for the lines in `info.invertedLines` (`Signals.InvertedLines`) |
| `info` | see [intan2matlab.md](intan2matlab.md#outputs) |
| `conversion` | `tool`, `created`, `dataset`, `sourceFolder`, `recordingFormat`, `matFileVersion`, `matlabVersion` |

## Spikes `.mat` (`EphysDataset.spikesToMat`; the Spikes step)

Default `<outputFolder>/<Name>_spikes.mat`. The file is rewritten as a whole;
sources that were not requested are `[]`.

| Variable | Contents |
| --- | --- |
| `detected` | `ts {1 x nChan}` spike times (s, `(index-1)/Fs`, recording-relative); `wf {1 x nChan}` `[nSpikes x nWin]` µV or `[]`; `info` (`detectSpikes` info filtered to the kept events); `channels` (1-based recording channels); `channelNames`; `detection` (options used, artifact intervals applied, `nRejectedArtifact` per channel) |
| `units` | the `readSortedUnits` struct, one row per unit: `unitId`, `label` (`su042_1255_260908T1039`), `class`, `group`, `notes`, `subject`, `recordingStart`, `datasetKey`, `channel`, `channelName`, `ksChannel`, `shank`, `peakX`, `peakY`, `x`, `y`, `nSpikes`, `samples`, `times`, `amplitude`, `contamPct`, `templateWaveform`, `templateTimeMs`, plus `fs`, `resultsDir`, `engine`, `groupSource`, `curated`, `channelMap`, `channelMapSource`, ... ([fields](EphysDataset.md#reading-sorted-units)). `unitTable` turns it into a table |
| `conversion` | provenance |

## Behavior `.mat` (`EphysDataset.behaviorToMat`; the behavior step)

Default `<outputFolder>/<Name>_behavior.mat`: the one file that holds a
dataset's Epsych2 session data. No other output carries a `behavior` variable.

| Variable | Contents |
| --- | --- |
| `behavior` | `EphysDataset.behaviorStruct`: `trials` (table, one row per trial), `info` (the Epsych2 `Info` snapshot), `meta`, `file`, `subject`, `startTime`, `nTrials`, `pairing` (`[]` when trials were not paired) |

When trials were paired (`Behavior.PairTrials`), `behavior.trials` also has:

| Column | Contents |
| --- | --- |
| `TrialInterval` | index into the trial line's intervals (`NaN` = cut or unpaired); trials pair in order after the cuts |
| `TrialOnset`, `TrialOffset` | seconds on the recording clock, `t = row/Fs` |
| `TrialOnsetSample`, `TrialOffsetSample` | 1-based rows at the recording rate (first / last on sample) |
| `TrialOnsetSample_<SIG>`, `TrialOffsetSample_<SIG>` | `round(t * Fs_SIG)` for each enabled derived signal (LFP, MUA, resampled SPIKE); the rates are in `pairing.signalFs` |
| `PairingFlag` | `"ok"`, `"partial"` (the interval begins at the first or ends at the last sample of the recording), `"cut"` (dropped by the cuts), `"unpaired"` (no interval left for it) |
| `TrialEvents` | struct per trial: one field per other digital line, `[n x 2]` seconds of its intervals that overlap the trial (polarity applied) |
| `TrialEventSamples` | the same in rows at the recording rate |

`behavior.pairing` holds `status` (`"approved"` only after review, or
automatically with `Behavior.AutoApprove`), `autoApproved`, `trialLine`, `invertedLines`, `Fs`, `nSamples`, `signalFs`, `nTrials`,
`nIntervals`, `nPaired`, `cutTrials` and `cutIntervals` (`[start end]`
counts dropped before pairing), `countMismatch`, `warnings`,
`partialIntervals`, `unpairedTrials`, `unpairedIntervals`, `fingerprint`,
`summary` and `conventions`.
| `conversion` | `tool`, `created`, `dataset`, `sourceFolder`, `behaviorFile` (the Epsych2 session) |

## Chronux export (`EphysDataset.exportChronux`; the Export step)

Default `<outputFolder>/<Name>_chronux.mat`. Everything is in the shapes the
Chronux functions take; no Chronux function is called to produce it.

| Variable | Contents |
| --- | --- |
| `LFP` / `MUA` / `SPIKE` | one struct per exported signal: `data` `[nSamples x nChan]` double µV, `params` (Chronux params with `Fs` = the signal rate), `t` (`(k-1)/Fs`), `labels`, `info` |
| `sp` | `1 x nUnits` struct array with field `times` (sorted units), or `[]` |
| `spDetected` | the same for threshold-detected spikes, one element per channel, or `[]` |
| `units`, `detected` | the source structs (`units` as in the spikes file, same order as `sp`), or `[]` |
| `events` | dig-in lines → `[k x 2]` seconds |
| `export` | `tool`, `created`, `dataset`, `sources`, `signals` |

## FieldTrip export (`EphysDataset.exportFieldTrip`; the Export step)

Default `<outputFolder>/<Name>_fieldtrip.mat`. Structures follow
`ft_datatype_raw`, `ft_datatype_spike` and `ft_read_event`
([FieldTripExport.md](FieldTripExport.md)).

| Variable | Contents |
| --- | --- |
| `data_LFP` / `data_MUA` / `data_SPIKE` | raw structures, one trial spanning the signal; `cfg.event` holds the events at that signal's rate |
| `spike` | spike structure of the sorted units (`label` = unit labels such as `su042_1255_260908T1039`, `timestamp` in recording samples; `hdr.orig` keeps the unit fields: class, identity, location, notes), or `[]` |
| `spikeDetected` | the same, one "unit" per detected channel, or `[]` |
| `event` | event struct array at the recording rate |
| `export` | `tool`, `created`, `dataset`, `sources`, `signals`, `eventFs`, `validation` |

## Epoch export (`EphysDataset.exportEpochs`; the Export step)

Default `<outputFolder>/<Name>_epochs.mat`: the same recorded samples and spike
times as the other exports, cut into one epoch per event
([`EphysDataset.eventEpochs`](EphysDataset.md#event-organized-epoched-data)).
Nothing is averaged, smoothed or resampled.

| Variable | Contents |
| --- | --- |
| `epochs` | `event` (source, name, window, onsets / offsets / durations, recording range, what was dropped), `trials` (one row per epoch: `EpochIndex`, `EpochOnset`, `EpochOffset`, `EpochDuration`, `EpochComplete`, plus `EventIndex` or `BehaviorRow` and the behavior trial columns), `signals` (per signal: `data` `[nTime x nEpochs x nChan]`, `t` relative to the onset, `fs`, `labels`, `units`, `info`), `units` (per unit: `id`, `label`, `class`, `group`, `channel`, `times` `{1 x nEpochs}`, `counts`), `detected`, `spikes` (the stamping rule), `behavior`, `meta` |
| `export` | `tool`, `created`, `dataset`, `sources`, `signals`, `eventSource`, `eventName`, `window`, `nEpochs`, the policies applied and the time conventions |

The same alignment drives the [`analysis`](EphysAnalysis.md) figures, which
index signals with the same event rule; this file is for taking the aligned
data elsewhere.

Epoch *i* of a signal holds rows `base(i)+round(tPre*Fs) … base(i)+round(tPost*Fs)`
with `base(i) = round(onset*Fs)` (`EpochOnsetRule = "event"`); samples outside
the recording are `NaN` and `EpochComplete` is false for that row. A spike
belongs to epoch *i* when `t > onset+tPre` and `t <= onset+tPost`, stamped by
`epochs.spikes.timeBase` (`"onset"`: 0 at the event).

All six `.mat` writers save to `~<name>.partial.mat` and rename only after a
warning-free `save()` in which every variable is confirmed present
(`EphysDataset.saveAtomically`).

## Analysis config JSON

Written by `EphysAnalysisConfig.save` (the analysis app's **File → Save
config**); any name, e.g. `am_quicklook.json`. Schema `ephys-analysis-config`,
version 1; `Inf` / `NaN` are written as the strings `"Inf"` / `"NaN"`
(`writeJsonFile(NonFinite="string")`) and read back as numbers.

| Key | Contents |
| --- | --- |
| `schema`, `version`, `name`, `description` | identification |
| `Source` | `Mode` (`project` / `folders`), `Root`, `OutputRoot`, `NamePattern`, `Selection`, `Datasets`, `Folders` |
| `Defaults` | `EventRef`, `Window` (`stop` is `[]` or an event reference), `Selection` |
| `Plots` | array of plots: `id`, `kind`, `enabled`, `title`, `source`, `units`, `channels`, `ref` / `window` / `selection` (`"default"` or an object), `bins`, `baseline`, `layout`, `withRaster`, `histStyle`, `fill`, `fillAlpha`, `normalize`, `stack`, `stackSpacing`, `maskAfterStop`, `param`, `seriesParam`, `value`, `order`, `metric`, `correlation`, `style` |
| `Export` | `Enabled`, `Formats`, `Folder`, `FilenamePattern`, `Dpi`, `FigureSizeCm`, `Overwrite` |
| `Report` | `Enabled`, `Format`, `Title`, `Folder`, `FileName`, `PerDataset`, `EmbedFormat`, `Dpi`, `IncludeSummary`, `IncludeParameters`, `IncludeConfig` |

Every field, its type and default: [EphysAnalysisConfig](EphysAnalysisConfig.md).

## Exported figure names

`<Export.Folder>/<Export.FilenamePattern>.<format>`, one file per page and
format (`png`, `eps`, `svg`, `pdf`). The folder pattern takes
`{OutputFolder}` (the dataset's output folder), `{OutputRoot}`, `{Root}`,
`{Name}` and `{Date}`; the default is `{OutputFolder}\analysis`, next to the
dataset's other outputs. The file-name pattern takes `{Name}` (the dataset),
`{Plot}` (the plot id), `{Kind}`, `{Group}` (`all`), `{Unit}` (the first unit
of a paged grid's page, else `all`), `{Index}` (the page) and `{Date}`
(yyyyMMdd); token values are cleaned to `[A-Za-z0-9_.-]`. A plot drawn on
several pages whose pattern names neither `{Index}` nor `{Unit}` gets
`_p<page>`: with the default `{Name}_{Plot}`,

```
<outputFolder>/analysis/SYNTH-01_260918_101500_psth_stim_p1.png
<outputFolder>/analysis/SYNTH-01_260918_101500_psth_stim_p2.png
<outputFolder>/analysis/SYNTH-01_260918_101500_lfp_stim.svg
```

## Report files

`<Report.Folder>/<Report.FileName>.html` and / or `.pdf`
(`Report.Format`); with `Report.PerDataset` one pair per dataset,
`<FileName>_<dataset>.html`. The default folder is `{OutputRoot}\analysis`.

- **HTML**: one self-contained file. A contents list; per dataset its
  summary tables (recording, digital lines, trials by pairing flag and
  response, units by class and shank, the highest rates) and every plot:
  its pages as `data:image/png;base64` images (or inline SVG with
  `EmbedFormat = "svg"`), the caption, relative links to the exported files
  and the plot's parameters (folded); plots that were skipped or failed with
  the reason; the config JSON at the end (folded).
- **PDF**: a title page, a summary page per dataset (listing skipped and
  failed plots) and every plot's pages drawn again as vector pages
  (`exportgraphics(ContentType="vector", Append=true)`).
