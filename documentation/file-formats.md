# Files on disk

This page lists every file the pipeline reads or writes, where it lives, and
its schema. JSON is written through `writeJsonFile` (pretty-printed, written to
a temporary file and renamed, so a reader never sees a half-written file).
`NaN` / `Inf` are written as `null` except where a schema says they are
written as the strings `"NaN"` / `"Inf"`. MATLAB's `jsonencode` writes a
one-element array as a scalar, so a list of one is written without its
brackets (`"files": "info.rhd"`, one manual period as `"manual_artifacts": [t0, t1]`);
the readers take both. Probe maps are the exception
([Kilosort4 probe JSON](#kilosort4-probe-json)).

<!-- wiki: What lands where, seen from the app: [Output files](Output-Files). -->

## Folder layout

```text
<Folder>/                               raw recording folder (its recording files are never modified)
├─ *.rhd                                Intan traditional layout, or
├─ info.rhd + amplifier.dat + ...       Intan one-file-per-signal, or
├─ info.rhd + amp-<native>.dat ...      Intan one-file-per-channel, or
├─ recording.json + <data>.bin          the universal binary format (any acquisition system), or
├─ <block>.tsq + .tev + .Tbk, *.sev     a TDT Synapse / OpenEx block (the folder is the block), or
├─ Record Node <id>/                    an Open Ephys GUI session (see below)
├─ <part name>/openephys-part.json      Open Ephys "separate" mode: one part folder per recording (a dataset)
├─ <session>.mat, or <first>_stitched.mat   the Epsych2 session the Copy tab put here
├─ session_manifest.json                where the Copy tab copied the session from (copySessions)
├─ session_copy_robocopy.log            the copy engine's robocopy log
├─ <Name>_manifest.json                 dataset manifest (writeManifest)
└─ <Name>_cleanup.json                  what Clean up removed, how and where to (runLocalCleanup)

<outputFolder>/                         = Folder, or OutputDir, or <OutputRoot>/<Name>
├─ <Name>_artifacts.json                artifact-interval cache (EphysPipeline)
├─ <Name>_extract_<TYPE>.mat            derived signals, one file per type (toMat; the Signals step),
│                                       or <Name>_extract.mat with Signals.SeparateFiles off
├─ <Name>_spikes.mat                    detected spikes (spikesToMat; the Spikes step)
├─ <Name>_behavior.mat                  Epsych2 session data, the only copy (behaviorToMat; the behavior step)
├─ <Name>_events.mat                    digital-input events cache (digitalEvents; trial pairing)
├─ <Name>_envelope_<what>.dat           min / max envelope of one signal for the Visualize tab (EphysTraceEnvelope):
│                                       <what> recording, recording_car / _cmr, bin, LFP, MUA, SPIKE or AUX
├─ <Name>_chronux.mat                   Chronux export (exportChronux; the Export step)
├─ <Name>_fieldtrip.mat                 FieldTrip export (exportFieldTrip; the Export step)
├─ <Name>_epochs.mat                    event-organized export (exportEpochs; the Export step)
├─ <Name>_kcsd.npz                      kCSD-python export, a NumPy archive (exportKCSD; the Export step)
├─ <Name>.nwb, <Name>_nwbinspector.json NWB export and its nwbinspector findings (exportNWB; the Export step)
├─ analysis/                            analysis figures (an analysis config's default Export.Folder)
├─ <Name>.bin + <Name>.json             EphysDataset.toBin (the Sorting step); <Name>_ks4.bin + <Name>_ks4.json
│                                       when <Name>.bin or <Name>.json is one of the recording's own files.
│                                       In Sorting.BinDir instead of here when that is set
└─ kilosort4/                           kilosortDir()
   ├─ settings.json, run_ks4.py         run settings (with bin_scale), copy of the driver used for this run
   ├─ ks4_launch.cmd                    the batch file a background run is started through (Windows)
   ├─ ks4_run.log                       captured stdout/stderr
   ├─ ks4_status.json                   {"state": "done"|"error", ...}
   ├─ ks4_exit.txt                      empty exit marker of a background run
   ├─ <probe>_excluded.json             derived probe when channels are excluded
   ├─ <probe>_spaced.json               derived probe with the shanks moved apart (shank_spacing)
   ├─ dryrun/                           a dry run's settings.json, run_ks4.py (and derived probe)
   ├─ previous_<yyyyMMdd_HHmmss>/       an earlier sort's curation, moved aside by a new sort (launchSorting)
   └─ params.py, spike_*.npy, templates.npy, cluster_*.tsv, ...
                                        Kilosort4 phy output (cluster_notes.tsv holds per-unit notes)
└─ si_<sorter>/                         sortRunDir(sorter): a SpikeInterface sorter's run (runSpikeInterface)
   ├─ settings.json, si_params.json,    run settings (sorter, reference, quality, n_jobs, bin_scale; nt0min
   │  run_si.py                         added by the run), the sorter's parameters as edited, the driver
   ├─ si_launch.cmd, si_run.log,        as kilosort4/'s ks4_launch.cmd, ks4_run.log, ks4_status.json
   │  si_status.json, ks4_exit.txt      ({"state", "num_units", "num_good", ...}) and exit marker
   ├─ <probe>_excluded.json, dryrun/,   as in kilosort4/
   │  previous_<yyyyMMdd_HHmmss>/
   └─ params.py, spike_*.npy, templates.npy, cluster_SILabel.tsv, ...
                                        phy output in Kilosort4's layout (run_si.py)

<OutputRoot, else Root>/
└─ pipeline_runs/<runId>_<name>.json    run record of each pipeline run (EphysPipeline.run; see Run records)

<analysis OutputRoot, else Root>/analysis/   an analysis config's default Report.Folder ({OutputRoot}\analysis)
├─ analysis_report.html, .pdf           analysis report (EphysAnalysisRunner; Report.FileName)
└─ analysis_runs/<runId>_<name>.json    run record of each analysis run (EphysAnalysisRunner.run)

<Root>/
└─ pipeline_<name>.m                    standalone script of the config, saved by each pipeline run while
                                        Project.SaveScript is on (EphysPipeline.writeScript); the next run replaces it

<anywhere>/
├─ <config>.json                        pipeline config (EphysPipelineConfig.save; File → Save),
│                                       or analysis config (EphysAnalysisConfig.save)
└─ <script>.m                           generated script (EphysPipelineScript, EphysAnalysisScript; File → Generate script)

<probe folder>/                         pipeline/probes by default
├─ <probe>.json                         Kilosort4 probe map
├─ <probe>.ks4.json                     its Kilosort4 parameters (writeKS4Params; Sorting → Optimize for probe)
└─ <probe>.chanmap.json                 the chain it was mapped from (ChannelMapperApp export)

pipeline/hardware/                      the channel mapper's hardware bank (HardwareBank)
├─ connectors/<name>.json               connector families
├─ headstages/<manufacturer>/<name>.json
├─ packages/<manufacturer>/<name>.json
├─ probes/<manufacturer>/<name>.json    probe designs (site geometry)
└─ mappings/<name>.json                 saved chains (ChannelMapperApp → Save mapping)
```

Output folders for the Signals, Spikes and Export steps can each be redirected
with their section's `OutputDir`. Sorted output can live anywhere: the manifest
records the folder that is associated with the dataset. Into a recording
folder the pipeline writes only the manifest, the Open Ephys part folders (in
`"separate"` mode) and, without an output root, the outputs; the Copy tab and
the Clean up tab write their own records there.

---

## Universal recording format (`recording.json`)

Any acquisition system can feed the pipeline by converting its recording to a
flat binary plus this descriptor; [`BinaryReader`](EphysDataset.md#acquisition-readers)
reads it. The data file is
**channel-major per sample** (all channels of sample 1, then sample 2, ...): the
Kilosort4 layout, and what `EphysDataset.toBin` writes.

```text
{
  "schema":        "ephys-recording/1",
  "name":          "subj1_day1",                (optional; default = folder leaf)
  "data_file":     "subj1_day1.bin",            relative to the folder
  "dtype":         "int16",                     int16 | uint16 | int32 | uint32 | single | float32 | double | float64
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
`schema` (exactly `"ephys-recording/1"`), `data_file`, `dtype`, `n_chan` and
`fs` are required (`BinaryReader:BadDescriptor` otherwise); `gain_to_uV` and
`offset` default to 1 and 0. A `dig_in_file` takes precedence over `events`:
with both, the events are decoded from the file. Without a readable
`acq_date` the data file's modified time is the recording start.
Only `recording.json` marks a folder as a recording, so the `.bin` + sidecar
pairs that `toBin` writes into output folders are never mistaken for one.
`RecordingFormat` for these datasets is `"binary"`; the manifest's `reader` is
`"binary"`. The optional `"channel_numbers": [0, 1, ...]` gives each channel's
hardware number, reported with sorted units (default `0..n_chan-1`; a probe's
`chanMap` indexes `.bin` rows, not these). The reader's `Files` are
`recording.json`, `data_file` and `dig_in_file` (when named), so the clean-up
and `DatasetTracker` treat the digital-input file as part of the recording.

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
root) its outputs are written into it, and its `Files`, relative to it, start
with `..`. The scan creates missing part folders
and warns (`OpenEphysReader:PartFolder`) when the session is read-only. The
other modes ignore part folders.

---

## Copy manifest (`session_manifest.json`)

<a name="copied-session-folder"></a>

Path: `<Destination>/<SUBJ>/<recording folder name>/session_manifest.json`.
Written by `copySessions` (the app's Copy tab and each scheduled copy) in every
session folder it copies or finds already present (not by a dry run). A
manifest that records a finished copy (`copy.status` `"copied"` or
`"already_present"`) is kept while the batch finds the session complete and
takes no checksums; one left by a cancelled or failed copy is replaced. With
`Verify="hash"`, a session found complete whose manifest records a finished
copy verified with checksums (`copy.verify` `"hash"`), matching
`sha256Source` / `sha256Destination` for every file and the sizes the files
have now, is `already_present` without its files being read again. A
scheduled run leaves a folder whose manifest records a finished copy (or that
holds a clean-up record) as it is, except a recording copied on its own
(`pairingStatus` `"recording_only"`) that now pairs: it gains its ePsych file.

```text
{
  "manifestVersion": 3,
  "subject": <subject ID>,
  "pairingStatus": "paired" | "stitched" | "recording_only" | "epsych_only",
  "deltaT_s": <ePsych start - recording start, s; null when unpaired>,
  "recording": {
    "reader": "intan" | "openephys" | "binary" | "tdt" | "",   the reader that read the folder (findCopySessions' Reader column)
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
  "copy": { "status": "copied" | "already_present" | "failed" | "cancelled", "message",
            "verify": "size" | "hash", "ifExists", "numFiles",
            "totalBytes", "filesAlreadyPresent", "startedAt", "finishedAt",
            "host", "user", "robocopyLog" },
  "tool": { "name": "copySessions", "version": "3.0.0", "gitCommit": <hash or ""> }
}
```

`deltaT_s` is negative when the ePsych session started first. In each
`files` entry, `sizeBytes` is the size listed when the copy was planned,
`sourceSizeBytes` and `destSizeBytes` the sizes checked after the copy, and
`sha256Source` / `sha256Destination` the checksums taken with
`Verify="hash"` (empty with `"size"`). Next to the manifest, robocopy's log
is `session_copy_robocopy.log`.

The Clean up tab (`planLocalCleanup`) reads `recording.files`: a local file
listed there is a raw recording file with a known source.

**The stitched Epsych2 file.** For a stitched session the copy writes
`<first file name>_stitched.mat` into the session folder
([`stitchEpsychSessions`](../pipeline/stitchEpsychSessions.m); the source
files are only read), saved `-v7` to a temporary file and renamed. It holds
`Data`, one element per trial of every session in time order, plus
`StitchPart` (the session it came from, 1 = the earliest) and
`StitchPartTrial` (its place in that session), with `TrialIndex` renumbered
`1..N`; and `Info`, the earliest session's, plus `Info.Stitch` (`Tool`,
`Created`, and `Parts`: `File`, `Name`, `Bytes`, `StartTime`, `NTrials` and
each session's own `Info`).

---

## Clean-up record

Path: `<Folder>/<Name>_cleanup.json`. Written by `runLocalCleanup` (the app's
Clean up tab) in each dataset folder it removed files from; a later clean up
appends a run.

```text
{
  "schema":  "ephys-local-cleanup/3",
  "dataset": <dataset Name>,
  "folder":  <recording folder>,
  "runs": [
    { "time": <"yyyy-MM-dd HH:mm:ss">, "host": <computer>, "user": <user>,
      "method": "delete" | "recycle" | "move",
      "destination": <the folder files were moved into, "" unless "move">,
      "ifExists": "skip" | "overwrite" | "version" (what a move did with a file already
                  at a file's place; "" unless "move"),
      "bytesRemoved": <n>,
      "removed": [ { "file": <local path>,
                     "category": "raw" | "sorter_copy" | "bin" | "envelope" | "sorting" | "output",
                     "step": <the preprocessing step that wrote it: "sorting" | "signals" |
                              "spikes" | "behavior" | "artifacts" | "export", "" for a raw file
                              or an envelope>,
                     "bytes": <n>, "source": <source path for a raw file, else "">,
                     "to": <its new path ("move"), "Recycle Bin" ("recycle", found there
                            afterwards), else "">,
                     "replaced": <true when the moved file replaced one already there>,
                     "note": <e.g. not found in the Recycle Bin afterwards, else ""> }, ... ] }, ...
  ]
}
```

A raw file is only removed while its `source` holds a file of the same size,
so the record says where to copy each one back from. A moved file is at
`<destination>/<dataset key>/<its path in the dataset's recording or output
folder>`, as `to` says, or below `<destination>/<dataset key>_v<n>` when
`ifExists` was `"version"` and a file of the dataset was already there.

---

## Scheduled copy

Path: `%LOCALAPPDATA%\ephys_analysis\copy_schedule\`
([`CopySchedule`](../pipeline/CopySchedule.m); the Copy tab's
[Scheduled copy](EphysPipelineApp.md#scheduled-copy)). Besides
`schedule.json` and `last_run.json` below, the folder holds `task.xml` (the
Windows task as created), the empty `startup.m` MATLAB runs there,
`copy_schedule.log` (every run's lines, appended; the previous 5 MB in
`copy_schedule.1.log`) and `matlab.log` (MATLAB's own output of the last
run).

`schedule.json` holds the settings (`CopySchedule.defaults`): `Subjects`,
`EpsychRoot`, `RecordingRoots` (one or more roots of recording folders),
`DestRoot`, `MaxLeadMin`, `MaxLagMin`, `MarginSec`, `MinDurationMin`,
`Verify`, `IfExists`, `IncludeUnpaired`, `EveryMin`, `LookBackDays`,
`QuietMin` and `RunWhen`. Saving fills in `Start` (the first run), `Code`
(the pipeline folder the task runs), `Matlab` (the MATLAB it starts), `Saved`
and `SavedBy`. It is written as `schedule.json.new` and renamed once Windows
has accepted the task. A single subject or root comes back from JSON as a
string rather than a list; `CopySchedule.normalize` turns it back, and drops
fields that are not settings.

`last_run.json` describes the last run. It is written when the run starts and
again when it ends:

| Field | Contents |
| --- | --- |
| `State` | `running` while the run is under way; then `done`, or `failed` when a session failed or the run could not do its work |
| `Started`, `Finished` | local times, `yyyy-MM-ddTHH:mm:ss` |
| `Host`, `User`, `Pid` | where the run happened |
| `Days` | the first and last day searched, `yyyy-MM-dd` |
| `Errors` | what stopped a subject or the whole run (a destination or source that is not there) |
| `Sessions` | one entry per session found: `Subject`, `Session` (its folder name), `DestDir`, `Status` (one of `CopySchedule.Statuses`), `Message` |

A `last_run.json` that still says `running` after the task has stopped
belongs to a run that was killed; `matlab.log` has MATLAB's own output of
that run.

---

## Dataset manifest

Path: `<Folder>/<Name>_manifest.json`. Written by `EphysDataset.writeManifest`;
`EphysProject.refresh()` (the GUI's Scan, `EphysPipeline`, generated scripts)
rewrites it after restoring the saved state with `applyManifest`. The GUI
also writes it on probe assignment, exclusion changes, manual artifact edits,
sorting and behavior associations, and each sorting launch / completion.
**Dataset → View manifest...** shows it in the
[`ManifestViewerApp`](ManifestViewerApp.md).

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
    "file": <probe .json path or "">, "exists": <bool>, "num_channels": <n>, "num_shanks": <n>,
    "depth_um": <max(yc)-min(yc)>, "notes": <string>
  },
  "exclude_channels": <compact list, e.g. "5,17-18", or "">,
  "reference_exclude": { "channels": <compact list or "">,   left out of the common reference
                         "source": "" | "suggested" | "manual" },
  "manual_artifacts": [[<t0>, <t1>], ...],          seconds, recording-relative
  "artifact_adjustments": [[<det0>, <det1>, <t0>, <t1>], ...],   detected artifacts moved by hand, seconds
  "artifacts": {
    "file": <path of <Name>_artifacts.json>, "exists": <bool>, "created": <"yyyy-MM-dd HH:mm:ss" or "">,
    "detected": <n or null>, "detected_s": <total seconds or null>,
    "manual": <n>, "adjusted": <n>,
    "handling": [] | { "auto_detection": <bool>,
                       "sorting": { "periods": <p>, "treatment": "noise fill" | "zero fill" },
                       "spikes":  { "periods": <p>, "treatment": "events rejected" | "erased" | "none" },
                       "signals": { "periods": <p>, "treatment": "erased" | "none" },
                       "noise_band_hz": <Hz, 0 = broadband>, "noise_seed": <n or null> }
  },
  "bin":      { "file": <BinFile path>, "exists": <true|false> },
  "kilosort": { "sorter": "kilosort4" | <SpikeInterface sorter>, "has_results": <bool>,
                "results_dir": <path or "">, "num_units": <n or null>, "state": <string> },
  "sorting":  { "results_dir": <SortingDir as recorded, else the folder holding params.py, or "">,
                "source": "auto" | "manual", "exists": <bool>, "curated": <bool>,
                "num_units": <n or null>, "updated": <"yyyy-MM-dd HH:mm:ss" or ""> },
  "behavior": { "file": <Epsych2 .mat or "">, "exists": <bool>, "subject": <string>,
                "start_time": <"yyyy-MM-dd HH:mm:ss" or "">, "n_trials": <n or null>,
                "pairing": [] | { "status": "unreviewed" | "approved", "auto_approved": <bool>,
                  "cut_trials": [<from start>, <from end>], "cut_intervals": [<from start>, <from end>],
                  "fingerprint": <string>, "trial_line": <string>, "summary": <string>,
                  "updated": <"yyyy-MM-dd HH:mm:ss"> } }
}
```

- The associations (`probe.file`, `sorting.results_dir` when `"manual"`,
  `behavior.file`) are written as recorded, even while their file or folder is
  not there; `exists` says whether it is there now (for `sorting`: whether
  `results_dir` holds `params.py`).
- `sorting` is the sorted-output association (`EphysDataset.sortingResultsDir`):
  `source` is `"manual"` when `SortingDir` was set explicitly (GUI **Use
  folder...**), else `"auto"` (the dataset's `sortRunDir()`: `kilosort4/`, or
  `si_<sorter>/` for a SpikeInterface sorter). A reader without the pipeline
  config (`DatasetOutputs` of a folder) takes the sort from here when the
  dataset's `kilosort4/` holds none.
  `curated` is true when phy saved the unit labels: `cluster_group.tsv` with
  the header `cluster_id<TAB>group` (Kilosort4 writes its own copy of
  `cluster_KSLabel.tsv` there, header `cluster_id<TAB>KSLabel`, and
  `run_si.py` one of `cluster_SILabel.tsv`, header `cluster_id<TAB>SILabel`).
- `kilosort` describes the run in `sortRunDir()`
  (`DatasetTracker.kilosortRunAt`), kept for the tracker tables; `sorter` is
  the dataset's `Sorter` (the config's `Sorting.Sorter`), recorded and not read
  back; `state` comes from the run's `ks4_status.json` (`si_status.json`), or
  is `"done"` when results exist without a status file.
- `exclude_channels` and `reference_exclude.channels` are compact lists
  (`formatChannelList`); they are read back with `parseChannelList`, which
  parses (never evaluates) numbers and ranges such as `"1 2 5-8"`,
  `"[1:4 9]"` or `N:S:M`.
- `reference_exclude` lists the channels (1-based) kept out of the common
  reference (the pipeline config's `Reference.Mode` `"car"` / `"cmr"`). `source` is
  `"suggested"` (by the noise-floor rule, `suggestReferenceExclude`),
  `"manual"` (typed on the Artifacts tab), or `""` (never set: the first
  referenced read suggests it).
- `artifact_adjustments` lists the detected artifacts whose onset or offset
  was moved by hand (the GUI's Artifacts tab): the artifact as the detector
  found it, `[det0 det1)`, then the bounds used instead, `[t0 t1)`
  (`EphysDataset.ArtifactAdjustments`). A detection is matched by its bounds
  to a quarter of a sample; one the detector no longer finds is not applied.
  One adjustment is written as a flat `[det0, det1, t0, t1]`.
- `artifacts` says how many artifacts were found, how the steps treat them and
  which file holds their definitions. `file` is the artifact-interval file
  ([below](#artifact-cache), `<Name>_artifacts.json`, written only
  while `Artifacts.CacheIntervals` is on); `detected` and `detected_s` are the
  number and total length of the automatically detected artifacts in it, and
  `created` is when it was written (all three empty or null without the file:
  the intervals themselves live only there). `manual` and `adjusted` count
  `manual_artifacts` and `artifact_adjustments`. `handling` is the pipeline
  config as it stood when the manifest was written
  (`EphysPipelineConfig.artifactHandling`), `[]` until a config has been
  applied. `periods` is `"manual + automatic"` or `"manual only"` (the
  automatic ones apply to a step when detection is on and its
  `Artifacts.ApplyTo<Step>` is), `""` when the step leaves the periods alone.
  `treatment` is what the step does with them: the sorting `.bin` gets a line
  across the period plus Gaussian noise matched to each channel's own noise
  (`"noise fill"`, `noise_band_hz` and `noise_seed` from `Artifacts`) or zeros
  (`"zero fill"`); Spikes drops the events inside them (`"events rejected"`) or
  erases them before detection (`"erased"`); Signals erases them before
  deriving. The manifest is rewritten after each detection, so `detected`
  follows it; `applyManifest()` does not read this block.
- `applyManifest()` restores `probe.file`, `exclude_channels`,
  `reference_exclude`, `manual_artifacts`, `artifact_adjustments`, a `"manual"`
  `sorting.results_dir`, `behavior.file` and `behavior.pairing`, the
  associations as recorded even while their file or folder is not there (the
  steps then report them missing rather than use something else).
  Detector and step settings are **not** stored here; they are
  in the pipeline config. The header metadata is always read again from the
  recording. A scan then associates the one Epsych2 session file at the top
  of the recording folder when no behavior file is recorded
  (`associateFolderBehavior`; several such files: none, with a warning).
- `behavior.pairing` is `[]` until the trials have been paired;
  `auto_approved` is true when `Behavior.AutoApprove` approved the pairing
  (`autoApproveTrialPairing`) rather than a review.
- Schema `/1` manifests (probe + exclusions only) are still read; `/2` is a
  superset. A manifest that is not valid JSON or has any other schema (a newer
  version's, say) is ignored with a warning and never overwritten:
  `writeManifest` leaves it for you to fix or delete
  (`EphysDataset:writeManifest:Kept`).

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
  "Acquisition": { "OpenEphys": { "Recordings", "RecordNode", "Stream" }, "TDT": { "Stream", "GainToMicrovolts" } },
  "Parallel":  { "Enabled", "MaxWorkers" },
  "Probe":     { "DefaultProbeFile", "WriteDefaultToManifest", "AutoAssign", "RuleSubjects", "RuleProbes" },
  "Reference": { "Mode", "BadLow", "BadHigh" },
  "Behavior":  { "Enabled", "Search", "SearchDirs", "Match", "MaxStartOffsetMin", "Overwrite", "WriteFile",
                 "PairTrials", "AutoApprove", "TrialLine" },
  "Artifacts": { "Enabled", "Method", "Threshold", ... , "Fill", "NoiseBandHz", "NoiseSeed", "ApplyToSorting", "ApplyToSpikes", "ApplyToSignals", "CacheIntervals" },
  "Sorting":   { "Enabled", "PythonExe", "CondaEnv", "Execution", "MaxConcurrent", "Devices", "DryRun", "SkipExisting", "BinDir",
                 "KS4": {...}, "KS4ExtraJSON" },
  "Signals":   { "Enabled", "OutputDir", "Suffix", ... , "BlankArtifacts", ... , "LabelField", "LineNames", "InvertedLines", ... ,
                 "ExcludeHandling" },
  "Spikes":    { "Enabled", ... , "ArtifactMode", "OutputDir", "Suffix", ... },
  "Export":    { "Enabled", "Formats", "Signals", "IncludeUnits", ... , "EpochNonFinite", "EpochArtifacts", ... },
  "Analysis":  { "Enabled", "ConfigFile", "Figures", "Report" },
  "Transfer":  { "Enabled", "Destination", "Method", "When", "IfExists", "Verify" }
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

<!-- wiki: Every section and field: [Pipeline configs](Pipeline-Configs#every-section-and-field). -->

---

## Artifact cache

Path: `<outputFolder>/<Name>_artifacts.json`. Written by
`EphysPipeline.artifactIntervalsFor` when `Artifacts.CacheIntervals` is on
and automatic detection runs (`Artifacts.Enabled`); with manual periods only,
nothing is written.

```text
{ "schema": "ephys-artifacts/3", "dataset": <Name>, "fingerprint": <string>,
  "intervals": [[t0, t1], ...], "nIntervals": <n>, "created": <timestamp> }
```

`intervals` are the automatic detection alone, in recording-relative seconds,
half-open on the 0-based sample clock: a period `[t0, t1)` covers samples
`round(t0*fs)` to `round(t1*fs) - 1`, the samples `toBin` erases in the `.bin`.
The manual periods are not stored here: they are merged in when the cache is
read. `fingerprint` is `jsonencode` of the schema, the detector settings (the
dataset's `ArtifactConfig`, its reference fields from the config's `Reference`
section included; the fill fields left out), the channels of the common reference, `ExcludeChannels`
and the recording files; a cache whose fingerprint differs from the current
settings (including one written under an earlier schema) is recomputed.
`EphysPipeline.cachedDetection` compares the same fingerprint without
detecting (the Visualize tab says whether the last run's periods are those the
current settings find).

---

## Events cache (`<Name>_events.mat`)

Path: `<outputFolder>/<Name>_events.mat`. Written by
`EphysDataset.digitalEvents` (the Trials tab's **Load** and **Prefetch
ticked**, trial pairing, the Visualize tab's **Read events**) with a plain
`save`, since reading the digital inputs can mean reading the whole
recording. One variable, `digitalEvents`:

| Field | Contents |
| --- | --- |
| `events` | one field per line, keyed by the line's **native** name: `[k x 2]` `[t_on t_off]` seconds (`t = row/Fs`) of its **high** runs, as recorded (the polarity is applied later) |
| `Fs`, `nSamples` | the recording's rate and length |
| `digInNames`, `digInNativeNames` | the lines' names and native names |
| `fingerprint` | the reader, the recording files with their modified times, and the sample count it was read from |

The cache is used while its fingerprint matches, so a recording written again
is read again. The lines are named (`LabelField`, `LineNames`) after loading,
so renaming a line never reads the recording again. Delete the file, or call
`digitalEvents(Refresh=true)`, to read it again anyway.

---

## Signal envelope (`<Name>_envelope_<what>.dat`)

Path: `<outputFolder>/<Name>_envelope_<what>.dat`, one file per signal the
Visualize tab shows: `<what>` is `recording` (as stored), `recording_car` /
`recording_cmr` (with the dataset's common reference, as every step reads it),
`bin` (the Sorting `.bin`), or `LFP` / `MUA` / `SPIKE` / `AUX`. A bare `.bin`
or extract file without a dataset gets `<stem>_envelope_<what>.dat` beside it.
Written by `EphysTraceEnvelope` (built in the background the first time the tab
shows the signal); only the Visualize tab reads it, and deleting it costs only
the time to build it again.

It holds, per channel, the min and max of every block of samples at several
block sizes ("levels"), so a view of any width is drawn from a few thousand
blocks. Little-endian throughout:

```text
bytes 0-7     "EPHYSENV"
bytes 8-15    uint64 H: the length of the header
bytes 16..    H bytes of UTF-8 JSON:
  { "schema": "ephys-envelope/1", "fingerprint": <string>,
    "source": { "kind", "name", "file", "dataset", "reference", "units" },
    "fs", "nSamples", "nChannels", "channelNames": [...],
    "factor": 4, "blocks": [B1, B2, ...], "nBlocks": [n1, n2, ...],
    "dtype": "single", "layout": <text>, "created": <timestamp> }
then          level 1 (n1 blocks), level 2 (n2 blocks), ...: per block
              nChannels float32 minima, then nChannels float32 maxima
```

Block k (0-based) of a level of B samples holds rows `k*B` to `k*B + B - 1`
(0-based) of every channel, the last block what is left; the viewer draws it at
its first sample, `k*B/fs` s. `blocks(1)` is a power of two picked from the
signal's length and channel count, and each further level is 4 times coarser,
down to the first of at most 4096 blocks (`EphysTraceEnvelope.blockSizes`).
The values are those `EphysTraceSource.read` returns (microvolts, volts for
AUX): the reference, and in the `.bin` the filled artifact periods, are those
of the full-rate view. `fingerprint` is `jsonencode` of the schema, the
signal's stamp (`EphysTraceSource.stamp`: the files read with their sizes and
modified times, rows, channels, rate, the reference and the channels it is
taken over, the `.bin`'s type / scale / offset) and the block sizes; a file
whose fingerprint differs, or that is not whole, is never read, and a new one
is built in its place. A build writes `<file>.<token>.partial` and renames it
when the last block is in; a partial file an hour old (a build MATLAB left) is
deleted by the next build of that file.

The files are display caches, so Clean up removes them (`planLocalCleanup`
kind `"envelope"`, ticked by default on the app's Clean up tab, Category
`envelope` in the clean-up record), each found by its name in the dataset's
output folder. A partial file goes with them only once it is an hour old, as
above: a newer one may be being written. An envelope the Visualize tab shows
whose file is removed is noticed within a second (`isReady`) and built again
when the tab next draws.

---

## Kilosort4 probe JSON

Stored in [`pipeline/probes`](../pipeline/probes/README.md) by default. This is
the shape `kilosort.io.load_probe` accepts (checked against Kilosort 4.1.7):

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

- `chanMap`: **0-based** channel per site, integers. Throughout the MATLAB code (sorting,
  `readPhyUnits`, `channelLayout` and the analysis probe maps), the 1-based
  `.bin` channel of a site is `chanMap + 1`; sites are not matched to
  channels by hardware number (see
  [python-drivers.md](python-drivers.md#channel-numbering-caveat)).
- `xc`, `yc`: site positions in µm.
- `kcoords`: shank per site, **required**. Kilosort4 places its templates per
  `kcoords` value and has no default for a JSON probe (it stops with a
  `KeyError`); all zeros on a single shank. The readers (`channelLayout`,
  `DatasetTracker.probeMeta`, the analysis probe maps) still draw a map
  without it, as one shank.
- `n_chan`: total channels, a positive integer, required by Kilosort4. Every
  channel-count check in the code uses `max(n_chan, numel(chanMap))`. An
  `n_chan` smaller than the map length is treated as wrong.
- `notes`: optional text. The GUI Probe tab edits it in place with a minimal textual
  replacement, so the rest of the file's formatting is preserved.
- **No other list.** Kilosort4 turns every JSON array in the file into one
  value per site and then requires equal lengths, so a list of site names,
  say, stops the probe loading. Other text, a number or a nested object is
  left alone.
- Every site array is a JSON list, even for one site. MATLAB's `jsonencode`
  writes a one-element array as a bare number, which Kilosort4 rejects, so
  probe maps are written through [`writeProbeMap`](../pipeline/writeProbeMap.m)
  (`makeSyntheticProbe`, the designer's Save, the derived `_excluded` probe).

[`probeMapProblems`](../pipeline/probeMapProblems.m) checks all of this on a
file or a decoded struct and returns one line per problem, none when
Kilosort4 reads the probe. `runKilosort` refuses a probe with problems before
writing the `.bin` (`EphysDataset:runKilosort:BadProbe`), `writeProbeMap`
refuses to write one (`writeProbeMap:BadProbe`), and the Probe tab and
`DatasetTracker.probeMeta` report them.

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
- The Probe tab does not list `*.ks4.json` files (or `*.chanmap.json`
  sidecars) as probes.

---

## Channel-map sidecar (`<probe>.chanmap.json`)

Path: next to the probe map, `<folder>/<probe>.chanmap.json` for
`<folder>/<probe>.json` (`ChannelMap.sidecarFile`;
`EphysPipelineConfig.ChanMapSidecarSuffix`). Written with the probe map by
`ChannelMap.exportKS4` (**Export Kilosort4 probe .json...** in
[`ChannelMapperApp`](ChannelMapperApp.md)). Read by
`ChannelMapperApp.loadMapping`, which reopens the chain. The pipeline does not
read it.

```json
{
  "schema":    "ephys-channel-map/1",
  "probeFile": "A1x32-6mm-50-177_H32_RHD2132-32ch.json",
  "mapping":   { "...": "a saved mapping, as in pipeline/hardware/mappings" },
  "result": {
    "site":            [1, 2, "..."],
    "hardwareChannel": [16, 17, "..."],
    "recordingRow0":   [16, 17, "..."],
    "flag":            ["", "", "..."]
  },
  "trust":   "verified",
  "written": "2026-09-26T16:40:12",
  "app":     "ChannelMapperApp 0.1.0 (commit ... on main, ...)"
}
```

- `mapping`: the chain: probe design, package, headstages with their channel
  offsets, mates and orientations, and how the rows were chosen (see
  [Hardware bank](#hardware-bank-pipelinehardware)).
- `result`: one entry per site of the design. `recordingRow0` is the 0-based
  recording row (the probe map's `chanMap` for the sites it kept); `null` and
  a `flag` (`GND`, `REF`, `NC`, `unmated`, `not recorded` ...) for a site that
  reaches no recorded channel.
- `trust`: `verified`, `rule-derived` or `unverified` (see
  [ChannelMapperApp](ChannelMapperApp.md#workflow)).
- It never holds a top-level `chanMap`, `xc` or `yc`, so the dataset
  inventory (`DatasetTracker.classifyJson`) does not take it for a probe. The
  Probe tab does not list it, and **Import probe .json into folder...**
  copies it along with its probe.

## Hardware bank (`pipeline/hardware`)

Path: `pipeline/hardware` (`HardwareBank.defaultFolder`), or any folder with
the same layout (the channel mapper's **Browse...**). One JSON file per entry,
`<kind folder>/<manufacturer>/<name>.json` (connectors and mappings have no
manufacturer folder). Read by `HardwareBank`, written by
`HardwareBank.saveEntry` (the channel mapper's editor and **Save mapping**).

Every file has `"schema": "ephys-hardware/1"`, a `kind` that matches its
folder (`connector`, `headstage`, `package`, `probe`, `mapping`; `adaptor`
is reserved), `manufacturer`, `name`, `channels`, `notes` and `source`.

- `connector`: `family`, `rows`, `cols`, `guides` (`[row, column]` of each
  guide post), `oneWay`, `pitchMm`.
- `headstage` / `package`: `faces`, each with an `id`, a `connector`, a
  `gender` (female headstage, male package) and `rows`. Each row is a line of
  text written as the vendor draws the connector looking into it, with the
  guide posts: `"GUIDE REF1 18 27 ... GND GUIDE"`.
  - A package's cells are site numbers, exactly `1..channels`. A headstage's
    cells are 0-based hardware channels.
  - A headstage adds `channelLabel` (`in%d`) and `hardwareChannels` (the first
    and last).
  - A package adds `verifiedHeadstages`, the headstages its chain has been
    checked against.
- `probe`: `shanks`, `sites` (the vendor's 1-based numbers), `x`, `y` (µm,
  y from the tip up), `shank` (from 1), `defaultPackage`, `template`,
  `pitchUm`, `geometrySource`.
- `mapping`: `probe`, `package`, `adaptors`, `headstages` (`id`,
  `channelOffset`), `mates` (`from` `package:<face>`, `to`
  `headstage[<i>]:<face>`, `orientation` `reference` or `rotated`), `rows`
  (`mode` `in-order`, `dataset` or `custom`, `channelNumbers`, `dataset`),
  `kcoords` (empty: each site's Kilosort4 group is its shank; else one whole
  number from 0 per site of the design, in its site order), `result`,
  `problems`, `trust`.

Every list is a JSON list, even with one element. The cell tokens, the
mating rule and full examples are in
[pipeline/hardware/README.md](../pipeline/hardware/README.md).

---

## `.bin` JSON sidecar

Path: `<outputFolder>/<Name>.json` (`<Name>_ks4.json` beside a
`<Name>_ks4.bin`), next to the `.bin`. Written by
`EphysDataset.toBin` (`WriteMeta=true`). Kilosort4 does not read it.
`runKilosort` reads `n_chan_bin` / `fs` (and, for a `.bin` it did not write,
`scale`) from it, and `DatasetTracker` reads
`n_chan_bin`, `fs`, `n_samples` and `source_folder`; the clean-up keeps a
`.bin` whose `source_folder` is another recording's.

| Field | Meaning |
| --- | --- |
| `n_chan_bin`, `fs`, `dtype`, `n_samples`, `byte_order`, `scale`, `offset` | what was written |
| `scale_source` | where `scale` came from: `set: ...` (given), `native: ...` (the recording's own resolution, nothing quantised again) or `default: <why>` (`EphysDataset.binScale`) |
| `bin_file`, `source_folder` | paths |
| `manual_artifacts` | `[k x 2]` seconds (the `ManualArtifacts` in effect) |
| `n_manual_blanked` | samples erased by manual periods |
| `artifact_fill` | `"noise"` or `"zero"`: what replaced the artifact samples |
| `noise_fill` | `bandHz`, `seed`, `sigma` (per channel, the SD of the fill's noise) and `center` (per channel, the level of a period with no clean sample on either side); `[]` for a zero fill |
| `auto_artifacts` | `enabled`, `method`, `threshold`, `rmsWindowMs`, `mergeGapMs`, `minChannels`, `padMs`, `nBlanked`, `fraction`, `pctDuration`, `nIntervals`, `channelCounts` |
| `reference` | `mode` (`"none"`, `"car"` or `"cmr"`) and `channels`, the 1-based channels the common reference was taken over (`[]` for none). `runKilosort` reads `mode` and, for `"car"` / `"cmr"`, sets Kilosort4's `do_CAR = false` |
| `created` | timestamp |
| `provenance` | the code and config that wrote it ([Provenance](#provenance), as JSON) |

`matrixToBin` delegates to [`matrix2kilosort`](../matrix2kilosort.m), which
writes its own sidecar. See that function's help for its fields.

---

## `settings.json`

Path: `<ResultsDir>/settings.json` (a dry run's: `<ResultsDir>/dryrun/settings.json`,
which still names `ResultsDir` as `results_dir`). A SpikeInterface sorter's
run (`runSpikeInterface`) has `sorter`, `n_chan_bin`, `fs`, `data_dtype`,
`filename`, `probe`, `results_dir`, `sorter_params` (`"si_params.json"`, the
parameters as edited, beside it), `reference` (`"none"` / `"car"` /
`"cmr"`: what the `.bin` carries), `quality` (the good-unit criteria, `NaN`
as `"NaN"`), `n_jobs`, `bin_scale` and `provenance`; `run_si.py` adds
`nt0min` once it has written the templates
([`run_si.py`](python-drivers.md#run_sipy)). Kilosort4's fields: `n_chan_bin`, `fs`, `data_dtype`
(from `ds.Dtype`), `filename` (the `.bin`), `probe` (original or
`_excluded.json` / `_spaced.json` probe), `results_dir`, `bin_scale` (the `.bin`'s units per
µV, for `readPhyUnits`; `run_ks4.py` does not pass it to Kilosort4), with
[shank spacing](EphysDataset.md#shank-spacing) `shank_spacing` (µm) and
`true_probe` (the unspaced probe, whose positions `run_ks4.py` writes back
into the output), `provenance` (the code and config that wrote the run,
[Provenance](#provenance); `run_ks4.py` leaves it alone), plus any
`ExtraSettings` fields. Paths use forward slashes. A `torch_device` field picks the GPU; the `--device`
argument a run gets from `Sorting.Devices` overrides it (the device a run
used is in `ks4_run.log` and the manifest's `launchSorting` entry, not
here).

## `ks4_status.json`

Path: in the run folder. Written by the Python driver when it finishes.
A SpikeInterface sorter's run (`run_si.py`) writes `si_status.json` instead,
the same in every other way, with `num_good` (the units labelled `good`) and
`sorter` added.

| Success | Failure |
| --- | --- |
| `{"state":"done","num_units":N,"dropped_params":[...]}` | `{"state":"error","message":"...","traceback":"..."}` |

A run stopped from MATLAB (`EphysDataset.stopSortRun`, the app's **Stop
runs...**) gets `{"state":"cancelled","message":"stopped by the user"}`,
written by MATLAB before it ends the run's processes, so a monitor that polls
while they are ended never sees a run that exited without a status.

`EphysDataset.launchSorting` deletes a stale status file before launching.
The GUI's background monitor polls this file every 3 s.

## `ks4_exit.txt`

Path: next to `ks4_status.json` (`si_status.json`). An empty file that the background launcher
(on Windows `ks4_launch.cmd`, or `si_launch.cmd`, in the run folder) writes once the Python process has
exited, however it ended; `launchSorting` writes it when the launch itself
fails. A run with this
file but no status file failed before the driver could report (a missing
Python or conda env, a crash). `EphysDataset.sortRunState(statusFile)`
reads the two together and returns `"running"`, `"done"`, `"error"` or
`"cancelled"`, so such a run frees its slot instead of looking "running" for
ever. `stopSortRun` writes it too. Its name is `EphysDataset.SortExitMarker`.
Deleted before each launch.

## Kilosort4 / phy output

Read by `EphysDataset.readPhyUnits` (the one reader used by the Review tab,
`spikesToMat`, `ChronuxDataset.spikes` and both exporters) from the folder
that holds `params.py`:

- Required: `spike_times.npy`, `spike_clusters.npy`.
- Optional: `amplitudes.npy`, `templates.npy`, `spike_templates.npy`,
  `channel_map.npy`, `channel_shanks.npy`, `channel_positions.npy`,
  `whitening_mat_inv.npy` (its transpose unwhitens the templates),
  `cluster_group.tsv` (preferred) else `cluster_KSLabel.tsv`, else
  `cluster_SILabel.tsv`, `cluster_Amplitude.tsv`, `cluster_ContamPct.tsv`.
  Kilosort4 writes its own `cluster_group.tsv`, a copy of
  `cluster_KSLabel.tsv` with the header `cluster_id<TAB>KSLabel`, and
  `run_si.py` a copy of `cluster_SILabel.tsv` (`good` / `mua` by the
  good-unit criteria) with the header `cluster_id<TAB>SILabel`
  (`groupSource` `"spikeinterface"`); only one with the header
  `cluster_id<TAB>group` holds phy's curated labels (`groupSource` `"phy"`,
  `curated`).
- Templates: `settings.json`'s `bin_scale` puts them in µV
  (`units.templateUnits`).
- Sample rate: `sample_rate` from `params.py`; otherwise the call errors
  unless `FsFallback=` is given (never a silent 30 kHz).
- Unit position: `channel_positions.npy` gives each unit's peak site and
  template centre, `channel_shanks.npy` its shank.
- Spike waveforms: `EphysDataset.readPhyWaveforms` (the Review tab's shank
  plot) reads the binary file `params.py` names (`dat_path`, `n_channels_dat`,
  `dtype`, `offset`, `hp_filtered`), with `nt`, `nt0min`, `do_CAR`,
  `highpass_cutoff` and `bin_scale` from `settings.json` when it has them.

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
signal type (`LFP`, `MUA`, `SPIKE`, and `AUX` when the recording has aux
inputs), each holding only that signal in `Y` and `info`:

| Variable | Contents |
| --- | --- |
| `Y` | struct with `LFP`, `MUA`, `SPIKE` (`single`, `[nSamples x nChan]`, µV) and `AUX` (volts); unrequested fields are `single([])`. Row k of a signal is at `(k-1)/info.<type>.Fs` |
| `events` | struct, one field per digital-input line, `[k x 2]` `[t_on t_off]` seconds; onset = rising edge, or falling edge for the lines in `info.invertedLines` (`Signals.InvertedLines`) |
| `info` | per signal `Fs` and `nSamples` (the row count; there are no time vectors), `origFs`, `labels`, `invertedLines`, `badChannels` (the columns interpolated, their recording channels, the method per column and the weights), `reference` (the common reference: `mode`, `channels`, and `signals`, the ones it was subtracted from; each signal's own `info.<TYPE>.reference` says `"none"`, `"car"` or `"cmr"`), `artifacts` (the periods erased before any signal was derived: `intervals` `[k x 2]` `[tStart tEnd)` s on the continuous clock, `fill` `"line"`, `nSamples` replaced; in every file, combined or per type), `importOptions`, ...; see [intan2matlab.md](intan2matlab.md#outputs) |
| `conversion` | `tool`, `created`, `dataset`, `sourceFolder`, `recordingFormat`, `matFileVersion`, `matlabVersion`, `provenance` ([Provenance](#provenance)) |

## Spikes `.mat` (`EphysDataset.spikesToMat`; the Spikes step)

Default `<outputFolder>/<Name>_spikes.mat`: threshold detections only. The file
is rewritten as a whole. Sorted units are not in it; they stay in the sorting folder.

| Variable | Contents |
| --- | --- |
| `detected` | `ts {1 x nChan}` spike times (s, `(index-1)/Fs`, recording-relative); `wf {1 x nChan}` `[nSpikes x nWin]` µV or `[]`; `info` (`detectSpikes` info filtered to the kept events); `channels` (1-based recording channels); `channelNames`; `detection` (options used, `artifactMode` (`"reject"`, `"erase"` or `"none"`), artifact intervals applied, `nRejectedArtifact` per channel; after an erase `info.artifacts` gives the periods and the samples erased) |
| `conversion` | `tool`, `created`, `dataset`, `sourceFolder`, `recordingFormat`, `fs`, `matFileVersion`, `matlabVersion`, `provenance` ([Provenance](#provenance)) |

## Behavior `.mat` (`EphysDataset.behaviorToMat`; the behavior step)

Default `<outputFolder>/<Name>_behavior.mat`: the one file that holds a
dataset's Epsych2 session data. No other output carries a `behavior` variable.

| Variable | Contents |
| --- | --- |
| `behavior` | `EphysDataset.behaviorStruct`: `trials` (table, one row per trial), `info` (the Epsych2 `Info` snapshot), `meta`, `file`, `subject`, `startTime`, `nTrials`, `pairing` (`[]` when trials were not paired) |
| `conversion` | `tool`, `created`, `dataset`, `sourceFolder`, `behaviorFile` (the Epsych2 session), `provenance` ([Provenance](#provenance)) |

When trials were paired (`Behavior.PairTrials`), `behavior.trials` also has:

| Column | Contents |
| --- | --- |
| `TrialInterval` | index into the trial line's intervals (`NaN` = cut or unpaired); trials pair in order after the cuts |
| `TrialOnset`, `TrialOffset` | seconds on the recording clock, `t = row/Fs` |
| `TrialOnsetSample`, `TrialOffsetSample` | 1-based rows at the recording rate (first / last on sample) |
| `TrialOnsetSample_<SIG>`, `TrialOffsetSample_<SIG>` | `round((t - 1/Fs) * Fs_SIG) + 1` (`Fs` = `pairing.Fs`, the recording rate) for each enabled derived signal (LFP, MUA, resampled SPIKE): the row of that signal nearest the recording row; the rates are in `pairing.signalFs` |
| `PairingFlag` | `"ok"`, `"partial"` (the interval begins at the first or ends at the last sample of the recording), `"cut"` (dropped by the cuts), `"unpaired"` (no interval left for it) |
| `TrialEvents` | struct per trial: one field per other digital line, `[n x 2]` seconds of its intervals that overlap the trial (polarity applied) |
| `TrialEventSamples` | the same in rows at the recording rate |

`behavior.pairing` holds `status` (`"approved"` only after review, or
automatically with `Behavior.AutoApprove`), `autoApproved`, `trialLine`, `invertedLines`, `Fs`, `nSamples`, `signalFs`, `nTrials`,
`nIntervals`, `nPaired`, `cutTrials` and `cutIntervals` (`[start end]`
counts dropped before pairing), `countMismatch`, `warnings`,
`partialIntervals`, `unpairedTrials`, `unpairedIntervals`, `fingerprint`,
`summary` and `conventions`.

## Chronux export (`EphysDataset.exportChronux`; the Export step)

Default `<outputFolder>/<Name>_chronux.mat`. Everything is in the shapes the
Chronux functions take; no Chronux function is called to produce it.

| Variable | Contents |
| --- | --- |
| `LFP` / `MUA` / `SPIKE` / `AUX` | one struct per exported signal: `data` `[nSamples x nChan]` double µV (AUX: volts), `params` (Chronux params with `Fs` = the signal rate), `t` (`(k-1)/Fs`), `labels`, `info` |
| `sp` | `1 x nUnits` struct array with field `times` (sorted units), or `[]` |
| `spDetected` | the same for threshold-detected spikes, one element per channel, or `[]` |
| `units` | the `readSortedUnits` struct, one row per unit: `unitId`, `label` (`su042_1255_260908T1039`), `class`, `group`, `notes`, `subject`, `recordingStart`, `datasetKey`, `channel`, `channelName`, `ksChannel`, `shank`, `peakX`, `peakY`, `x`, `y`, `nSpikes`, `samples`, `times`, `amplitude`, `contamPct`, `templateWaveform`, `templateTimeMs`, plus `templateUnits` (`"uV"`, `"bin"`, `"whitened"` or `""`), `fs`, `resultsDir`, `groupSource`, `curated`, `channelMap`, `channelMapSource`, ... ([fields](EphysDataset.md#reading-sorted-units)), same order as `sp`, or `[]`. `unitTable` turns it into a table |
| `detected` | the spikes file's `detected` struct, or `[]` |
| `events` | dig-in lines → `[k x 2]` seconds, `t = row/eventFs` on the recording's clock: on a signal at `Fs` that is row `round((t - 1/eventFs)*Fs) + 1` |
| `artifacts` | the extract's `info.artifacts`: `intervals` (`[k x 2]` `[tStart tEnd)` seconds on the continuous clock, the periods erased before the signals were derived; on a signal at `Fs` they touch rows `EphysDataset.intervalRows(intervals, Fs, nRows)`), `fill`, `nSamples`. No intervals: nothing was erased |
| `export` | `tool`, `created`, `dataset`, `sourceFolder`, `sources`, `signals`, `eventFs` (the recording rate), `nUnits`, `nDetectedChannels`, `timeConventions` (`continuous`, `events`, `spikes`, `artifacts`), `provenance` ([Provenance](#provenance)) |

## FieldTrip export (`EphysDataset.exportFieldTrip`; the Export step)

Default `<outputFolder>/<Name>_fieldtrip.mat`. Structures follow
`ft_datatype_raw`, `ft_datatype_spike` and `ft_read_event`
([FieldTripExport.md](FieldTripExport.md)).

| Variable | Contents |
| --- | --- |
| `data_LFP` / `data_MUA` / `data_SPIKE` / `data_AUX` | raw structures, one trial spanning the signal; `cfg.event` holds the events at that signal's rate, each on the sample nearest its recording row; `cfg.artfctdef.preprocessing.artifact` the artifact periods erased before the signals were derived, `[begsample endsample]` rows of that signal on its `sampleinfo` (every sample a period touches; `[]` with none), the matrix `ft_rejectartifact` reads |
| `spike` | spike structure of the sorted units (`label` = unit labels such as `su042_1255_260908T1039`, `timestamp` in 0-based recording samples, `hdr.Fs` the sorting rate; `hdr.orig` keeps the unit fields: class, identity, location, notes), or `[]` |
| `spikeDetected` | the same, one "unit" per detected channel, or `[]` |
| `event` | event struct array at the recording rate: `type` (the line), `sample`, `value`, `offset`, `duration` |
| `export` | `tool`, `created`, `dataset`, `sourceFolder`, `sources`, `signals`, `eventFs`, `artifacts` (the extract's `info.artifacts`, the periods in seconds), `nUnits`, `validation` (per structure: `ok`, `message`, when FieldTrip is on the path), `fieldtripOnPath`, `provenance` ([Provenance](#provenance)) |

## Epoch export (`EphysDataset.exportEpochs`; the Export step)

<a name="epoch-export"></a>

Default `<outputFolder>/<Name>_epochs.mat`: the same recorded samples and spike
times as the other exports, cut into one epoch per event
([`EphysDataset.eventEpochs`](EphysDataset.md#event-organized-epoched-data)).
Nothing is averaged, smoothed or resampled. `DatasetOutputs` finds it as the
`epochs` kind (`out.Epochs`).

| Variable | Contents |
| --- | --- |
| `epochs` | `event` (source, name, window, onset rule, `eventFs` (the recording rate the event times count rows of), onsets / offsets / durations, recording range, what was dropped, `nArtifact`), `trials` (one row per epoch: `EpochIndex`, `EpochOnset`, `EpochOffset`, `EpochDuration`, `EpochComplete` (the window lies inside the recording and inside every signal's rows), `EpochArtifact` (the window touches an artifact period), plus `EventIndex` or `BehaviorRow` and the behavior trial columns), `signals` (per signal: `data` `[nTime x nEpochs x nChan]`, `t` relative to the onset, `fs`, `labels`, `units`, `nArtifact`, `info` with `keptTrials` and `droppedArtifact`), `units` (per unit: `id`, `label`, `class`, `group`, `channel`, `times` `{1 x nEpochs}`, `counts`), `detected`, `spikes` (the stamping rule), `behavior`, `artifacts` (the extract's `info.artifacts`), `meta` |
| `export` | `tool`, `created`, `dataset`, `sources`, `signals`, `eventSource`, `eventName`, `window`, `nEpochs`, the policies applied and the time conventions, `provenance` ([Provenance](#provenance)) |

The same alignment drives the [`analysis`](EphysAnalysis.md) figures, which
index signals with the same event rule; this file is for taking the aligned
data elsewhere.

Epoch *i* of a signal holds rows `base(i)+round(tPre*Fs) … base(i)+round(tPost*Fs)`
with `base(i) = round((onset - 1/eventFs)*Fs) + 1` (`EpochOnsetRule =
"event"`: the signal row nearest the onset's recording row), or
`round(onset*Fs) + 1` (`"sample"`); samples outside the recording are `NaN`,
and `EpochComplete` is true only when the window lies inside the recording (in
seconds) and inside every signal's rows. A spike belongs to epoch *i* when
`t > onset+tPre` and `t <= onset+tPost`, the onset taken on the spikes' clock
(`(row - 1)/eventFs` for a digital-event onset, so a spike in the onset's own
sample is at 0), stamped by `epochs.spikes.timeBase` (`"onset"`: 0 at the
event). `EpochArtifact` is true when the epoch's window on the continuous
clock, onset + `[tPre tPost]` with the onset taken the same way, overlaps a
half-open period of `epochs.artifacts.intervals`; with `EpochArtifacts =
"drop"` (the default) that epoch is left out of every signal
(`info.keptTrials`, `info.droppedArtifact`), while the trials table and the
spike epochs keep it.

## NWB export (`EphysDataset.exportNWB`; the Export step)

Default `<outputFolder>/<Name>.nwb`, an [NWB 2](https://www.nwb.org) HDF5
file written by pynwb ([EphysDataset → NWB](EphysDataset.md#neurodata-without-borders-nwb)
lists what it holds). Read it with pynwb, MatNWB or `h5read`:

| Path | Contents |
| --- | --- |
| `/general/extracellular_ephys/electrodes` | `location`, `group` / `group_name`, `rel_x`, `rel_y` (µm; with a probe), `channel_name`, `recording_channel` (1-based), `interpolated` |
| `/processing/ecephys/LFP/LFP` | `data` `(samples, channels)` float32 µV, attribute `conversion` 1e-6 (volts); `electrodes` (rows of the table); `starting_time` 0 with `rate` |
| `/processing/ecephys/MUA/MUA`, `.../SPIKE/SPIKE` | the same for MUA and SPIKE (`FilteredEphys`) |
| `/acquisition/AUX` | `data` `(samples, channels)` volts |
| `/units` | `spike_times` + `spike_times_index`, `id`, `electrodes`, `class`, `sort_label`, `label`, `channel_name`, `peak_channel`, `shank`, `x_um`, `y_um`, `amplitude`, `contam_pct`, the quality metrics |
| `/intervals/trials` | `start_time`, `stop_time` (continuous clock) and the trial columns |
| `/intervals/<line>` | each digital line's pulses, `start_time` / `stop_time` (continuous clock) |
| `/intervals/invalid_times` | the artifact periods erased, with `reason` |
| `/general/notes` | JSON: `tool` (`EphysDataset.exportNWB`), `dataset`, `sourceFolder`, `sources`, `probeFile`, `provenance` ([Provenance](#provenance)); `DatasetOutputs` finds the file by it |

Next to it, `<Name>_nwbinspector.json` holds every finding of nwbinspector
(`file`, `created`, `versions`, `messages`: `importance`, `check`, `message`,
`objectType`, `objectName`, `location`).

```matlab
lfp = h5read("<Name>.nwb", '/processing/ecephys/LFP/LFP/data').';   % [samples x channels] uV
st  = h5read("<Name>.nwb", '/units/spike_times');
ix  = h5read("<Name>.nwb", '/units/spike_times_index');            % unit k: st(ix(k-1)+1 : ix(k))
```

## kCSD export (`EphysDataset.exportKCSD`; the Export step)

Default `<outputFolder>/<Name>_kcsd.npz`: the LFP and the probe positions of
its channels, as the arrays [kCSD-python](https://github.com/Neuroinflab/kCSD-python)'s
estimators take (`KCSD1D(ele_pos, pots, ...)`, `KCSD2D`), in kCSD-python's
units (mm, mV; its `sigma` is in S/m). It is a NumPy archive, read with
`numpy.load`; in MATLAB, `readNPZ` or `DatasetOutputs.KCSD`. It is written
uncompressed (as `numpy.savez` does), with zip64 records past 4 GB.

```python
import json, numpy as np
from kcsd import KCSD1D, KCSD2D
d = np.load("<Name>_kcsd.npz")
line = list(d["event_names"]).index("Stim")
on = d["event_onset_sample"][d["event_line"] == line]
evoked = np.mean([d["pots"][:, i - 50 : i + 200] for i in on], axis=0)   # at fs = 1 kHz
K = KCSD1D if d["ele_pos"].shape[1] == 1 else KCSD2D
k = K(d["ele_pos"], evoked, sigma=0.3)
k.cross_validate(Rs=np.array([0.05, 0.1, 0.2]), lambdas=np.logspace(-6, -1, 6))
csd = k.values("CSD")
```

Electrodes are the LFP channels on the dataset's probe (its own, a probe rule's
or the default probe) less the bad channels the Signals step interpolated. An
interpolated trace is not a measurement, and kCSD needs no value on a missing
site. They are listed in probe order: by shank, then from the top of the shank
down, then left to right. The export stops with an error when there is no
probe, when fewer than `dim + 1` electrodes are left, or when two electrodes
share a position.

| Array | Contents |
| --- | --- |
| `ele_pos` | `[n_ele x dim]` float64, mm. `dim` is 1 on a single column of one shank: the position along the shank, the probe's `yc` (larger = farther from the tip). Otherwise it is 2: (`xc`, `yc`) |
| `pots` | `[n_ele x N]` float32 LFP in mV (the extract's µV / 1000), row *e* for electrode *e*; sample *i* (0-based) is at `i/fs` s on the continuous clock |
| `fs` | 0-d float64, the LFP rate (Hz) |
| `label`, `shank`, `x_um`, `y_um` | per electrode: its channel label, shank (the probe's `kcoords`) and site position in µm |
| `extract_column`, `recording_channel` | per electrode, 1-based: its LFP column in the MATLAB extract and its amplifier channel |
| `excluded_label`, `excluded_recording_channel`, `excluded_reason` | the LFP channels left out and why (`bad channel (interpolated by the Signals step)`, `not on the probe`) |
| `event_names` | the digital-input lines |
| `event_line`, `event_onset_s`, `event_offset_s`, `event_onset_sample`, `event_offset_sample` | one row per pulse, sorted by onset: 0-based index into `event_names`, the edges in seconds (`t = row/eventFs` on the recording's clock) and as int64 0-based LFP samples, `round((t - 1/eventFs)*fs)` (the LFP sample of the recording row that produced the edge). Empty with `Export.IncludeEvents` off |
| `artifact_s`, `artifact_samples` | the artifact periods erased before the LFP was derived: `[k x 2]` `[tStart tEnd)` seconds, and the merged int64 0-based `[start stop)` LFP samples they touch, so `pots[:, start:stop]` is the erased stretch |
| `meta` | 0-d unicode JSON: `tool`, `created`, `dataset`, `sourceFolder`, `sources` (`extractFile`, `probeFile`), `signal`, `fs`, `eventFs`, `nSamples`, `nElectrodes`, `dim`, `elePosAxes`, `units`, `lfp` (rate, band, notch, filter description, reference), `artifactFill`, `timeConventions`, `provenance` ([Provenance](#provenance), as JSON) |

Sorted units, detected spikes and behavior are not part of it. The `.npz` is
written to `~<name>.partial.npz` and renamed once complete.

All six `.mat` writers save to `~<name>.partial.mat` and rename only after a
warning-free `save()` in which every variable is confirmed present
(`EphysDataset.saveAtomically`).

## Provenance

Every output records the code and the run that wrote it, as the struct
`ephysProvenance` returns: in the `.mat` files as the `provenance` field of
their `conversion` or `export` struct; in the JSON outputs (the `.bin`
sidecar, `settings.json`, the kCSD `meta`) and the run records as an object
whose non-finite numbers are written as the strings `"Inf"` / `"-Inf"` /
`"NaN"`, as a config file holds them (`provenanceForJson`).

| Field | Contents |
| --- | --- |
| `software` | `"ephys_analysis"` |
| `version` | the release number in `VERSION` |
| `commit`, `branch`, `dirty`, `describe` | the git commit checked out, its branch, whether tracked files had uncommitted changes, and `git describe --tags --always --dirty`; `""` / `false` when git cannot tell |
| `code` | all of it on one line, as **Help → About** shows it |
| `matlab`, `platform`, `host`, `user` | MATLAB's version string, `computer`, the machine and the user |
| `created` | when the provenance was made, `yyyy-MM-ddTHH:mm:ss` |
| `runId` | the pipeline run that wrote the output (`yyyyMMddTHHmmssSSS`, its start); `""` for a step called on its own or a writer called directly |
| `configFile`, `config` | the pipeline config's file and the config itself (`EphysPipelineConfig.toStruct`; `EphysPipelineConfig.fromStruct(p.config)` rebuilds it); `""` and empty for a writer called directly |

An output written in a run of `EphysPipeline` (the app's Run, a compact
script) carries the config; one written by a direct call to a writer (a
standalone script, `ds.toMat(...)`) carries the code version only. With
`dirty` true the commit alone does not reproduce the code.

## Unit quality metrics (quality_metrics.json)

Path: `<sort results folder>/quality_metrics.json`, written by
`EphysDataset.unitQuality` / `unitQualityOf` (and so by
`readSortedUnits(Quality=true)`, the exporters, the Review tab and
`selectUnits` with a quality filter) as a cache. Schema `ephys-unit-quality/1`:

```text
{
  "schema":   "ephys-unit-quality/1",
  "inputs":   { "spike_times_npy": { "bytes", "modified" }, ... },   the files the metrics came from:
              spike_times, spike_clusters, amplitudes, spike_positions, templates, params.py,
              settings.json; "modified" in whole seconds (-1 / -1: the file is not there)
  "key":      { "numSamples", "firstSample", "fs", "metrics" },   the sorted span and unitQualityMetrics options
  "definitions": "SpikeInterface 0.105 quality metrics ...",
  "clusters": [ { "unitId", "firingRate", "isiViolationsRatio", "isiViolationsCount", "presenceRatio",
                  "amplitudeCutoff", "snr", "driftPtp", "driftStd", "driftMad" }, ... ],   every cluster of the
              folder; the metrics as "%.17g" strings, which read back to the same doubles ("NaN" for NaN);
              snr is not cached (it is the template over the noise below)
  "noise":    { "channels": [...], "uV": [...] },   the noise of each recording channel measured for SNR
  "provenance": { the code that wrote it }
}
```

The file is used only while every entry of `inputs` and `key` still holds; a
merge or split in phy rewrites `spike_clusters.npy` and so makes it stale.
Deleting it costs only the time to compute it again.

`quality_report.html` (same folder): the QC page `writeUnitQualityReport`
writes (the Review tab's **QC report**). `sortSweep` writes each variant's
sort to `<outputFolder>/kilosort4_sweep/<name>/`, each with its own
`quality_metrics.json` and `quality_report.html`.

In the exports, the units struct carries the metrics as column fields and
`quality` (the settings, the span, how SNR was measured): `units` in
`<Name>_chronux.mat`, `spike.hdr.orig` in `<Name>_fieldtrip.mat`; each unit of
`<Name>_epochs.mat` has `quality`, a struct of its metrics ([] without them).

## Run records

**Pipeline runs.** Path: `<Project.OutputRoot>/pipeline_runs/<runId>_<name>.json`,
or under `Project.Root` without an output root. Written by
`EphysPipeline.run` when the run ends, whether it finished, was cancelled or
failed (not for a dry run). Schema `ephys-pipeline-run/1`:

```text
{
  "schema":   "ephys-pipeline-run/1",
  "runId":    <yyyyMMddTHHmmssSSS>,        the run's start; every output of the run names it
  "name":     <config name>,
  "outcome":  "finished" | "cancelled" | "failed",
  "error":    <identifier: message of the error that stopped a failed run, else "">,
  "started", "finished": <yyyy-MM-ddTHH:mm:ss>,  "seconds": <n>,
  "steps":    [<steps run, in order>],
  "datasets": [ { "key", "name", "folder", "outputFolder" }, ... ],
  "results":  [ { "Step", "Dataset", "Status", "Message", "Output", "Seconds" }, ... ],   the Results table
  "backgroundRuns": [ { "name", "resultsDir", "device" }, ... ],   Kilosort4 runs started in the background
  "script":   <the pipeline script the run saved, <Root>/pipeline_<name>.m; "" when none (Project.SaveScript)>,
  "provenance": { the Provenance fields above, without config },
  "config":   { the pipeline config, as its JSON file holds it }
}
```

`EphysPipeline.RunRecordFile` names the file the last run wrote. A record
that cannot be written is a warning (`EphysPipeline:RunRecord`); the run's
outputs are already on disk.

**Analysis runs.** Path: `<report folder>/analysis_runs/<runId>_<name>.json`,
the report folder being `Report.Folder` resolved for the first dataset
(whether or not a report was written). Written by `EphysAnalysisRunner.run`;
schema `ephys-analysis-run/1`: `runId`, `name`, `outcome` (`finished` |
`cancelled`), `started`, `finished`, `seconds`, `datasets`, `plots`,
`reportFiles`, `results` (the runner's Results rows), `provenance` and
`config` (the analysis config). `EphysAnalysisRunner.RunRecordFile` names it.
The pipeline's Analysis step writes one too (its `config.Source` is the
pipeline's project and selected datasets), and the pipeline run's record
lists the step's rows (`analysis:<plot id>`, `analysis:report`).

## Analysis config JSON

Written by `EphysAnalysisConfig.save` (the analysis app's **File → Save
config**); any name, e.g. `am_quicklook.json`. Schema `ephys-analysis-config`,
version 1; `Inf` / `NaN` are written as the strings `"Inf"` / `"NaN"`
(`writeJsonFile(NonFinite="string")`) and read back as numbers. Another
schema or version fails (`EphysAnalysisConfig:BadSchema`); unknown fields are
dropped and listed in `LoadWarnings`.

| Key | Contents |
| --- | --- |
| `schema`, `version`, `name`, `description` | identification |
| `Source` | `Mode` (`project` / `folders`), `Root`, `OutputRoot`, `NamePattern`, `Recordings` (the Open Ephys recording mode), `Selection`, `Datasets`, `Folders` |
| `Defaults` | `EventRef`, `Window` (`stop` is `[]` or an event reference), `Selection` |
| `Plots` | array of plots: `id`, `kind`, `enabled`, `title`, `source`, `units`, `channels`, `ref` / `window` / `selection` (`"default"` or an object), `bins`, `measure`, `baseline`, `auroc`, `layout`, `withRaster`, `rasterSort`, `histStyle`, `fill`, `fillAlpha`, `normalize`, `stack`, `stackSpacing`, `maskAfterStop`, `param`, `seriesParam`, `value`, `order`, `metric`, `correlation`, `waveform`, `style`, `aesthetics` |
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
several pages gets `_p<page>` unless its pattern tells the pages apart: it
names `{Index}`, or `{Unit}` with a unit filled in (a paged evoked grid's
`{Unit}` is `all` on every page, so it gets `_p<page>` too). With the default
`{Name}_{Plot}`,

```
<outputFolder>/analysis/SYNTH-01_260918_101500_psth_stim_p1.png
<outputFolder>/analysis/SYNTH-01_260918_101500_psth_stim_p2.png
<outputFolder>/analysis/SYNTH-01_260918_101500_lfp_stim.svg
```

## Report files

`<Report.Folder>/<Report.FileName>.html` and / or `.pdf`
(`Report.Format`); with `Report.PerDataset` one pair per dataset,
`<FileName>_<dataset>.html`. The default folder is `{OutputRoot}\analysis`.

- **HTML**: one self-contained file. Under the title, when it was made and
  the code version, MATLAB and machine that made it. A contents list; per dataset its
  summary tables (recording, digital lines, trials by pairing flag and
  response, units by class and shank, the highest rates) and every plot:
  its pages as `data:image/png;base64` images (or inline SVG with
  `EmbedFormat = "svg"`), made from the figures that were exported (an
  exported `.svg` is reused), the caption, links to the exported files
  (relative to the report's folder, each path segment percent-encoded as
  UTF-8; a `file://` URL on another drive or share) and the plot's parameters
  (folded); plots that were skipped or failed with
  the reason; the config JSON at the end (folded).
- **PDF**: a title page (with the code version, MATLAB and machine), a summary page per dataset (listing skipped and
  failed plots) and every plot's pages as vector pages
  (`exportgraphics(ContentType="vector")`), made from the figures that were
  exported (an exported `.pdf` is reused) and joined in that order with the
  Apache PDFBox library MATLAB ships.

## Which writes are atomic

A file written atomically goes to a temporary name next to it and is renamed
once complete, so a reader never sees half of it and a crash leaves the
previous file as it was.

| Written atomically (temporary file + rename) | Written directly |
| --- | --- |
| the six `.mat` outputs (`toMat`, `spikesToMat`, `behaviorToMat`, `exportChronux`, `exportFieldTrip`, `exportEpochs`) via `EphysDataset.saveAtomically`; the stitched Epsych2 file; the kCSD `.npz`; the `.nwb`; the Visualize envelopes | the `.bin` and its JSON sidecar, `settings.json`, `<Name>_events.mat`, generated scripts, analysis figures and reports |
| through `writeJsonFile`: the dataset manifest, the artifact cache, `recording.json` (`writeDescriptor`), `openephys-part.json`, probe maps and the derived `_excluded` / `_spaced` probes (`writeProbeMap`), `<probe>.ks4.json`, `<probe>.chanmap.json`, hardware bank entries, pipeline and analysis configs, run records, `quality_metrics.json`, `<Name>_nwbinspector.json`, `<Name>_cleanup.json`, `session_manifest.json`, the scheduled copy's `schedule.json` and `last_run.json`, and the `ks4_status.json` of a run stopped from MATLAB | everything Python writes (`ks4_status.json`, `ks4_run.log`, the sorter output), and the logs appended a line at a time (`copy_schedule.log`) |
