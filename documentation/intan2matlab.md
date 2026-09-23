# intan2matlab / deriveSignals / toMat

These three entry points run the same processing. It reads an Intan recording
(any layout), concatenates it in time, extracts digital-input events, and
derives LFP, MUA and/or spike-band signals.

| Entry point | What it is |
| --- | --- |
| [`intan2matlab(folder, ...)`](../pipeline/intan2matlab.m) | standalone function, a thin wrapper: `EphysDataset(folder)` then `deriveSignals(...)`. With no `ProgressFcn`, it prints a `parfor_progress` bar and a summary of auto-flagged bad channels |
| [`ds.deriveSignals(...)`](../pipeline/@EphysDataset/deriveSignals.m) | the implementation (an `EphysDataset` method) |
| [`ds.toMat(...)`](../pipeline/@EphysDataset/toMat.m) | `deriveSignals` + an atomic save to one `.mat` (see [EphysDataset](EphysDataset.md#derived-signals-the-intan2matlab-processing)) |
| the **Signals** step ([EphysPipeline](EphysPipeline.md), GUI **Signals** tab) | `toMat` over the selected datasets with a config's `Signals` section (see [EphysPreprocessingApp](EphysPreprocessingApp.md#signals)) |

> These files were edited (LFP band-limit and notch options added) while this
> documentation was being written. This page reflects the code as of that
> session; check the source help if in doubt.

```matlab
[Y, events, info] = intan2matlab("D:\rec\subj1_day1");
[Y, events, info] = intan2matlab("D:\rec\subj1_day1", dataTypeOut=["LFP" "MUA"], ...
    LFP_bpLoHi=[1 300], LFP_NotchHz=[60 120 180]);

ds = EphysDataset("D:\rec\subj1_day1");
out = ds.toMat(SignalOptions=struct('dataTypeOut', ["LFP" "SPIKE"]));
```

## Processing order

1. **Read** the whole recording with `readData(Precision="single")`:
   traditional files in chronological order, or the split `.dat` files. Only
   `keepAmpChannels` are kept, in the given order. Digital events are extracted
   here, at the original rate, and named and polarized by `labelField`,
   `lineNames` and `invertedLines`, which default to the dataset's
   `TrialConfig`; explicit values win.
   With a common reference (the dataset's `ArtifactConfig.Reference`,
   `"car"` or `"cmr"`; `intan2matlab`'s own dataset has none) every channel
   is read, the reference is subtracted sample by sample over
   `referenceChannels` (`applyReference`, a block of rows at a time, in
   place), and `keepAmpChannels` are picked after it. `reference=false`
   skips it.
2. **Artifact periods**, if given (`artifactIntervals`, merged): the samples
   each period covers (`EphysDataset.artifactSamples`: 0-based
   `round(t0·Fs)` .. `round(t1·Fs) − 1`, the samples the `.bin` and spike
   rejection take) are replaced in the amplifier data, per channel, by a
   straight line from the mean of the 1 ms before the period to the mean of
   the 1 ms after it (a period at an end of the recording is held at the level
   on its other side). LFP, MUA and SPIKE all derive from the filled data, so
   no filter or resampler spreads an artifact past its period: a 20 mV, 50 ms
   artifact otherwise leaves about 770 µV in a 1 Hz high-passed LFP 0.3 s
   away and 120–150 µV in MUA / SPIKE 5 ms away; filled, under 0.1 µV. AUX and
   the digital events are not touched.
3. **LFP**, if requested: `resample` to `LFP_Fs`. If `LFP_bpLoHi` is not
   `[0 Inf]`, or `LFP_NotchHz` is non-empty, filters are then applied **at
   `LFP_Fs`**, one channel at a time in double precision:
   - a 4th-order Butterworth high-pass, low-pass or bandpass;
   - a 2nd-order Butterworth band-stop for each notch frequency;
   - each as second-order sections, applied with `filtfilt`.
4. **MUA**, if requested: 4th-order Butterworth bandpass `MUA_bpLoHi` at the
   original rate (`filtfilt`) → `abs` → `resample` to `MUA_Fs` → `movmean` with
   a window of `round(MUA_Fs / MUA_IntegrationHz)` samples.
5. **SPIKE**, if requested: `resample` to `SPIKE_Fs` (skipped when `Inf` or
   equal to the original rate) → 4th-order Butterworth bandpass `SPIKE_bpLoHi`
   designed at `SPIKE_Fs` (`filtfilt`). At the original rate the spike band
   overwrites the amplifier data in place.

   The MUA and SPIKE bandpasses run in double through
   `EphysDataset.filterContinuous` (stable second-order sections at low
   cut-offs, the exact and faster transfer function otherwise), one channel at
   a time (8 at a time from 64 channels up), into single outputs.
6. **Bad channels**, if given: the listed **columns** (after `keepAmpChannels`,
   before `channelRemap`: column c is recording channel `keepAmpChannels(c)`)
   are replaced in every signal by the 1/distance-weighted mean of the 4
   nearest good sites on the same shank (and any as near as the 4th), placed by
   the probe (`channelLayout` of `probeFile`, else of the dataset's
   `ProbeFile`). Without a probe layout, or for a site off the probe or with no
   good site on its shank, the warning
   `EphysDataset:deriveSignals:BadChannelGeometry` is issued and the column is
   interpolated across the neighbouring columns with
   `fillmissing(..., 'makima', 2)`.
   - Bad lists are checked before anything is read
     (`EphysDataset:deriveSignals:BadChannels`): positive integers within the
     column count, and not every column.
   - `info.badChannels` records the columns, their recording channels, the
     method per column (`"geometry"` or `"columns"`) and the weights.
   - A negative scalar `badChannels = -z` auto-flags channels with
     `abs(zscore(rms(Y.LFP))) > z`, computed on the LFP after any LFP filtering.
     This requires `"LFP"` and uses `zscore`, from the Statistics and Machine
     Learning Toolbox.
7. **Remap**, if given: `channelRemap` reorders the columns of every signal (a
   permutation of all of them in place), and `info.labels` is reordered to
   match.

**Resampling.** `resample` needs an integer ratio `P/Q`, taken from `rat`:
exact for any rate with a short decimal expansion (24414.0625 Hz to 1000 Hz is
128/3125), with `P` and `Q` up to 2^18 and `P·Q` within `int32`. A ratio that
needs larger factors is approximated (the tolerance loosened up to 1e-4), and
the rate actually produced is the one reported in `info.<type>.Fs` and
`info.importOptions`. A ratio that cannot be had at all raises
`EphysDataset:deriveSignals:ResampleRatio`.

## Options

| Option | Default | Notes |
| --- | --- | --- |
| `dataTypeOut` | `"LFP"` | any of `"LFP"`, `"MUA"`, `"SPIKE"`, `"AUX"` |
| `keepAmpChannels` | `[]` (all) | 1-based amplifier channels, read in this order |
| `channelRemap` | `[]` | final column order, 1-based into the kept channels |
| `badChannels` | `[]` | column indices (after keep, before remap), interpolated from the probe geometry; or a negative scalar for auto |
| `probeFile` | `""` (the dataset's `ProbeFile`) | `deriveSignals` / `toMat`: the probe `.json` whose geometry places the bad channels; `EphysPipeline` passes the probe it sorts with (`probeFor`: the dataset's own, else the config's default). Recorded in `info.importOptions` |
| `ProbeFile` | `""` | `intan2matlab` only: the probe `.json` placing the channels for the bad-channel interpolation (a bare `EphysDataset(folder)` has none). Not stored in `info.importOptions` |
| `LFP_Fs` | 1000 Hz | |
| `LFP_bpLoHi` | `[0 Inf]` | `0` = no high-pass, `Inf` = no low-pass. Finite edges must be < `LFP_Fs/2` |
| `LFP_NotchHz` | `[]` | notch centers, e.g. `[60 120 180]`. Each needs `f − BW/2 > 0` and `f + BW/2 < LFP_Fs/2` |
| `LFP_NotchBW` | 2 Hz | notch width. `f ± BW/2` are the −3 dB points of the design (−6 dB after `filtfilt`) |
| `MUA_Fs` | 2000 Hz | |
| `MUA_IntegrationHz` | 1000 Hz | |
| `MUA_bpLoHi` | `[300 5000]` | high edge < original Fs/2 |
| `SPIKE_Fs` | `Inf` (original rate) | |
| `SPIKE_bpLoHi` | `[300 5000]` | high edge < `SPIKE_Fs/2` |
| `labelField` | `""`: the dataset's `TrialConfig.LabelField` (`intan2matlab`: `"custom"`) | `"custom"` or `"native"`; labels `info.labels` (and the aux labels) and names the `events` fields |
| `lineNames` | `[]`: `TrialConfig.LineNames` (`intan2matlab`: none) | `"native=name"` digital-line names overriding `labelField` (e.g. `"DIGITAL-IN-04=InTrial"`, Open Ephys `"TTL4=InTrial"`) |
| `invertedLines` | `[]`: `TrialConfig.InvertedLines` (`intan2matlab`: none) | digital lines with inverted TTL polarity (on while low): their `events` rows are the low runs, onset = falling edge; `info.invertedLines` lists the lines inverted |
| `reference` | `true` | `deriveSignals` / `toMat`: subtract the dataset's common reference (`ArtifactConfig.Reference`; nothing for `"none"`) before anything else (step 1); `false` reads the recording as stored. Reported in `info.reference` |
| `artifactIntervals` | `zeros(0,2)` | `[k x 2]` artifact periods, `[tStart tEnd)` seconds from the recording start (half-open, as `EphysDataset.artifactIntervals` gives them), erased before any signal is derived (step 2). Reported in `info.artifacts`, not stored in `info.importOptions` |
| `ProgressFcn` | `[]` | `ProgressFcn(nDone, nTotal, message)`: one step per file read, one per processing stage (erasing the artifact periods is one), then `(nTotal, nTotal, "Done")`. It may throw to abort. Not stored in `info` |

All options are validated before any data is read. Band edges are checked
against the header sample rate, and checked again against the rate actually read
if the two differ. Errors use `EphysDataset:deriveSignals:*` identifiers.
`intan2matlab` adds `INTAN2MATLAB:NoFiles`.

The help text notes that `filtfilt` IIR filtering leaves **edge transients** at
the start and end of the recording: up to about 2 s at each end for a 1 Hz
LFP high-pass, and longer for lower cut-offs.

## Outputs

**`Y`**: a struct with `LFP`, `MUA`, `SPIKE`, each `[nSamples x nChan]`, and
`AUX` (the aux inputs, `[nSamples x nAux]` volts at their own rate, not
affected by `keepAmpChannels`, `badChannels` or `channelRemap`). Signals that
were not requested are `single([])`. Row k of a signal is at
`(k-1)/info.<type>.Fs`.

**`events`**: one field per digital-input line. The field name is the line's
`lineNames` entry, else its `labelField` name, passed through
`matlab.lang.makeValidName`. Each field is a
`[k x 2]` array of `[t_on t_off]` in seconds on the original amplifier time
base. Onset/offset times are (1-based sample index)/Fs; see
[Time conventions](README.md#time-and-indexing-conventions).

**`info`**:

| Field | Contents |
| --- | --- |
| `recordingFolder` | recording folder |
| `filenames` | files read |
| `recordingFormat` | layout |
| `labels` | amplifier labels in `Y` column order |
| `origFs` | amplifier sample rate |
| `invertedLines` | the digital lines whose events are low runs |
| `reference` | the common reference subtracted first: `mode` (`"none"`, `"car"` or `"cmr"`) and `channels` (the recording channels it was taken over) |
| `badChannels` | what was interpolated, and how: `columns` (before `channelRemap`), `channels` (their recording channels), `method` per column (`"geometry"` or `"columns"`) and `weights` (`[nKept x nBad]`, each geometry column's weights over the kept columns) |
| `artifacts` | what was erased before any signal was derived: `intervals` (`[k x 2]` `[tStart tEnd)` seconds on the continuous clock, merged; `zeros(0,2)` for none), `fill` (`"line"`) and `nSamples` (recording samples replaced). They hold for every signal and rate: on a signal at `Fs` (row r at `(r−1)/Fs`) a period touches the rows `EphysDataset.intervalRows(intervals, Fs, nRows)` gives |
| `LFP` | `Fs`, `bpLoHi`, `NotchHz`, `NotchBW`, `filter` (text description of the filters applied), `nSamples` |
| `MUA` | `Fs`, `IntegrationHz`, `bpLoHi`, `nSamples` |
| `SPIKE` | `Fs`, `nSamples` |
| `AUX` | `Fs`, `nSamples`, `labels`, `units` (`"volts"`), when the recording has aux inputs |
| `importOptions` | the options actually used: the rates produced (`LFP_Fs`, `MUA_Fs`, `SPIKE_Fs`; `SPIKE_Fs` = `origFs` when `Inf`), `badChannels` the columns actually interpolated, and `labelField` / `lineNames` / `invertedLines` as resolved |

The `LFP`/`MUA`/`SPIKE`/`AUX` sub-structs exist only for requested signals.
Row k of a signal is at `(k-1)/Fs`; `nSamples` is the row count (there are no
time vectors).

## Memory and requirements

- Amplifier data is read as `single`, only the kept channels (split and binary
  recordings stream one window at a time into a preallocated single matrix).
  Each signal is then derived a block of channels at a time into a
  preallocated single matrix, and the spike band at the original rate takes
  over the amplifier data's memory. The help text puts peak memory at about the
  single-precision recording plus the derived signals plus the
  double-precision working copies of one block of channels (at most about the
  recording again); measured, about 1.7x the single-precision recording with
  16 channels and 2.3x with 64, not counting the read.
- Requires the Signal Processing Toolbox (`butter`, `filtfilt`, `resample`,
  `zp2sos`, `sos2tf`). Auto bad-channel detection
  needs `zscore` (Statistics and Machine Learning Toolbox).
- `intan2matlab`'s console progress bar uses
  [`compute/parfor_progress.m`](../vendor/compute/parfor_progress.m).
