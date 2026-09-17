# ChronuxDataset

`ChronuxDataset` ([source](../pipeline/@ChronuxDataset/ChronuxDataset.m)) is a
`handle` class that connects this pipeline's data to the
[**Chronux**](http://chronux.org) toolbox: it hands Chronux's spectral routines
the data structures they expect, together with a validated `params` struct, and
reports exactly which samples, trials and spikes it passed on.

It **selects and re-packages; it never changes sample values**. No resampling,
rescaling, interpolation or padding happens inside it. Trials that cannot be
filled from the recording, or that contain non-finite samples, are dropped and
listed in the returned `info` rather than being quietly patched.

Chronux itself is not required to prepare data — only to analyse it. A copy is
bundled in [`toolboxes/chronux`](../toolboxes/chronux); add it to the path:

```matlab
addpath(genpath('C:\src\ephys_analysis\toolboxes\chronux'))
ChronuxDataset.hasChronux()      % true when it is there
ChronuxDataset.requireChronux()  % errors with an install hint when it is not
```

---

## What it produces

| Method | Returns | Chronux functions that take it |
| --- | --- | --- |
| [`continuous`](#data-params-info--cxcontinuousnamevalue) | `[nSamples x nChan]` double, µV | `mtspectrumc`, `mtspecgramc`, `coherencyc`, `CrossSpecMatc`, `rmlinesc`, `locdetrend` |
| [`trials`](#data-params-t-info--cxtrialsonsets-twin-namevalue) | `[nTime x nTrials]` (or `x nChan`) epochs | the same, with `params.trialave = 1` |
| [`spikes`](#data-params-t-info--cxspikesnamevalue) | `1 x nUnits` struct array with field `times` | `mtspectrumpt`, `mtspecgrampt`, `coherencypt`, `coherencycpt`, `psth` |
| [`spikeTrials`](#data-params-t-info--cxspiketrialsonsets-twin-namevalue) | `1 x nTrials` struct array with field `times` | the same, with `params.trialave = 1` |
| [`binnedSpikes`](#data-params-t-info--cxbinnedspikesnamevalue) | `[nBins x nUnits]` counts | `mtspectrumpb`, `mtspecgrampb`, `coherencypb`, `coherencycpb` |
| [`eventOnsets`](#onsets-info--cxeventonsetsname-namevalue) | digital-input onset times (s) | trial triggers for the two methods above |

Every data method also returns the `params` struct that goes with **that**
data, so `params.Fs` can never drift away from what was handed over.

---

## Construction

```matlab
cx = ChronuxDataset(ds)                          % an EphysDataset
cx = ChronuxDataset("D:\rec\subj1_day1")         % a recording folder
cx = ChronuxDataset("D:\out\subj1_extract.mat")  % an EphysDataset.toMat output
cx = ChronuxDataset(S)                           % the same, already loaded (struct with Y, events, info)
cx = ChronuxDataset(X, Fs=1000)                  % [nSamples x nChan] µV matrix (single/double)
cx = ChronuxDataset()                            % empty (statics, or a spike-only use)
```

Name-value options: `Fs` (required for a matrix), `Signal`, `SignalOptions`,
`ChannelLabels`, `SpikeFs`, `Tapers`, `Pad`, `Fpass`, `Err`, `TrialAve`,
`Load` (read the signal immediately instead of on first use).

A numeric source must already be in microvolts as `single` or `double`; raw
int16 ADC counts are refused rather than cast, because scaling them
(`0.195 * double(X)` for Intan) is a decision about the data, not about types.

The continuous signal is read **lazily** — nothing is read until a method needs
it, or `cx.loadSignal()` is called. `loadSignal(Force=true)` re-reads after a
change to `Signal` or `SignalOptions`.

| `Signal` | Where the data comes from |
| --- | --- |
| `"LFP"`, `"MUA"`, `"SPIKE"` | `EphysDataset.deriveSignals(SignalOptions..., dataTypeOut=Signal)` — see [intan2matlab](intan2matlab.md) |
| `"RAW"` | `EphysDataset.readData` — broadband amplifier data at the recording rate, unfiltered (only `keepAmpChannels` and `labelField` apply from `SignalOptions`) |

`dataTypeOut` must **not** appear in `SignalOptions`; the `Signal` property is
what selects the signal.

## Properties

| Property | Default | Meaning |
| --- | --- | --- |
| `Signal` | `"LFP"` | which continuous signal this connector serves |
| `SignalOptions` | `struct()` | forwarded to `deriveSignals` |
| `SpikeFs` | `1000` | rate of the point-process **analysis grid**: `params.Fs` for `spikes` / `spikeTrials`, default bin rate for `binnedSpikes`. A property of the analysis, not of the spike times |
| `Tapers` | `[3 5]` | `[TW K]` or `[W T p]` (see [`tapersFor`](#tapers)) |
| `Pad` | `0` | FFT padding factor |
| `Fpass` | `[0 Inf]` | `Inf` becomes `Fs/2` when the params are built |
| `Err` | `0` | `0`, `[1 p]` (theoretical) or `[2 p]` (jackknife) |
| `TrialAve` | `0` | `1` makes Chronux average over the second dimension |

Read-only: `Dataset`, `SourceType` (`"dataset"`, `"file"`, `"struct"`,
`"matrix"`), `SourceFile`, `SourceStruct`, `Data`, `Fs`,
`ChannelLabels`, `Events`, `Info`, `Loaded`, and the dependent `NumSamples`,
`NumChannels`, `Duration`. `cx.summary()` returns all of it as one struct.

---

## Conventions

### Units and time base

- Continuous data is in **microvolts**, sample `k` at **`t = (k-1)/Fs`**
  seconds, recording-relative (first sample of the first file is `t = 0`) —
  `readData`'s `t` vector.
- Digital-input event times keep the convention they are produced with,
  **`t = row/Fs`**, one sample later than the continuous `t` for the same row.
  See [Conventions](README.md#time-and-indexing-conventions).
- Spike times are seconds on the same recording-relative clock:
  `sample_index / sample_rate` for Kilosort output, `(row-1)/Fs` for
  `detectSpikes`.

### Trial sample alignment

With `s0 = round(tPre*Fs)` and `s1 = round(tPost*Fs)`, trial *i* is rows
`base(i)+s0 … base(i)+s1`, so `nTime = s1-s0+1` and `T = (s0:s1)/Fs`. The onset
row `base(i)` follows `OnsetRule`:

| `OnsetRule` | `base` | Use it for |
| --- | --- | --- |
| `"event"` (default) | `round(t*Fs)` | digital-input onsets (`t = row/Fs`), which map back to exactly the sample that produced them. Same indexing as [`extract_trials`](../extract_trials.m) |
| `"sample"` | `round(t*Fs)+1` | times on a continuous time base (`readData`'s `t`, `info.LFP.time`, spike times) |

The two differ by one sample. At a derived rate (`LFP_Fs`) the digital-input
convention and the resampled grid cannot agree more closely than that, so treat
a trial onset as accurate to ±1 sample of the signal's own rate.

Chronux's own `createdatamatc(data, E, Fs, win)` uses `floor(E*Fs)+1` and a
right-exclusive window, so it returns one sample fewer, starting one sample
later, than `OnsetRule="sample"`. Note also that its `win` is `[winl winr]`,
**both positive**, where `twin` here is `[tPre tPost]` with `tPre` normally
negative: `win = [-tPre tPost]`.

### Spike trial windows

`spikeTrials` uses Chronux's `createdatamatpt` rule exactly: trial *i* keeps
spikes with `t > E(i)+tPre` **and** `t <= E(i)+tPost` (half-open, so a spike on
the boundary of two abutting windows is counted once), and by default stamps
them relative to the **start of the window** (`t - E - tPre`, spanning
`[0, tPost-tPre]`). `TimeBase="onset"` stamps relative to the event instead, and
`TimeBase="absolute"` leaves recording times alone (there is then no common
grid, so `T` comes back empty).

### Why `t` matters for point processes


Left to itself, `mtspectrumpt` builds its time grid from the first and last
spike in the data (`mintime-dt : dt : maxtime+dt`), so the rate it reports and
the prolates it uses depend on when the neuron happened to fire. The `t` these
methods return spans the **analysis window** (the recording by default) at
`SpikeFs`. Pass it through:

```matlab
[sp, params, t] = cx.spikes();
[S, f, R] = mtspectrumpt(sp, params, 0, t);
```

### Tapers

`ChronuxDataset.tapersFor(W, T)` returns `[TW K]` with `TW = W*T` and
`K = floor(2*TW) - p` (`p = 1` by default): the most tapers Chronux allows for a
half-bandwidth of `W` Hz over a `T` second window, i.e. the spectrum is smoothed
over `f ± W` Hz. For a spectrogram, `T` is the **moving window** length, not the
recording length.

```matlab
cx.Tapers = ChronuxDataset.tapersFor(2, 1);    % ±2 Hz over 1 s -> [2 3]
[S, t, f] = mtspecgramc(data, [1 0.1], params);
```

`makeParams` validates rather than adjusts: it errors on a non-integer or
non-positive `K`, an `fpass` above Nyquist, a malformed `err`, and warns when
`K > 2*TW-1` (Chronux's stated limit).

---

## Methods

### `[data, params, info] = cx.continuous(Name=Value)`

The loaded signal as `[nSamples x nChan]`.

| Option | Default | Notes |
| --- | --- | --- |
| `Channels` | `[]` (all) | column indices in the order you want, or channel labels |
| `TimeRange` | `[-Inf Inf]` | seconds; keeps samples with `(row-1)/Fs` in `[t0 t1]`, inclusive |
| `Detrend` | `"none"` | `"constant"` (per-column mean) or `"linear"` (`detrend`). Chronux's `locdetrend` is a moving detrend and is not applied here |
| `Class` | `"double"` | `"single"` or `"asis"` — Chronux computes its tapers in double |
| `Tapers`, `Pad`, `Fpass`, `Err`, `TrialAve` | properties | per-call overrides |

`info`: `channels`, `labels`, `sampleRange`, `timeRange`, `fs`, `nSamples`,
`nChan`, `signal`, `units`, `detrend`, `class`, `nonFinite` (a warning is issued
when that is non-zero — Chronux would return NaN).

With `params.trialave = 1` Chronux averages over **columns**, so pass one
channel at a time when you do not want channels averaged together.

### `[data, params, T, info] = cx.trials(onsets, twin, Name=Value)`

Event-aligned epochs; `twin` defaults to `[-0.2 0.5]`. One channel gives
`[nTime x nTrials]` (what Chronux wants); several give
`[nTime x nTrials x nChan]` — pass `data(:,:,c)`.

| Option | Default | Notes |
| --- | --- | --- |
| `Channels` | `[]` (all) | as above |
| `OnsetRule` | `"event"` | see [Trial sample alignment](#trial-sample-alignment) |
| `Incomplete` | `"drop"` | window past the start/end of the recording: drop (with a warning), `"nan"` (keep, pad with NaN), or `"error"` |
| `NonFinite` | `"drop"` | trial whose in-range samples contain NaN/Inf: drop (with a warning), `"keep"`, or `"error"`. Samples padded by `Incomplete="nan"` are not counted here |
| `Detrend` | `"none"` | applied per trial and channel |
| `Class` | `"double"` | as above |
| `Tapers`, `Pad`, `Fpass`, `Err`, `TrialAve` | properties | per-call overrides |

`info` names every trial that was kept (`keptTrials`, indices into `onsets`) and
every one that was not (`droppedIncomplete`, `droppedNonFinite`), plus
`sampleOffsets`, `onsetSamples`, `onsets`, `nTime`, `nTrials`, `nChan`, `T`.

### `[data, params, t, info] = cx.spikes(Name=Value)`

Spike times as a `1 x nUnits` struct array whose only field is `times` (sorted
column vectors of seconds) — the form `mtspectrumpt` and friends read.

| `Source` | Spike times from |
| --- | --- |
| `"auto"` (default) | `"times"` when `Times` is given, else `"kilosort"` when the dataset has results. Never starts detection on its own |
| `"kilosort"` | the sorted units read with [`EphysDataset.readPhyUnits`](EphysDataset.md#reading-sorted-units) from `ResultsDir` (default: the dataset's associated `sortingResultsDir()`): `spike_times.npy` / `sample_rate` from `params.py`. One element per cluster |
| `"detect"` | `EphysDataset.detectSpikes` on the loaded signal (one element per channel) — threshold crossings, not sorted units |
| `"times"` | a numeric vector, a cell array of vectors, or a struct array with a `times` field |

| Option | Default | Notes |
| --- | --- | --- |
| `Units` | `[]` (all) | cluster ids (Kilosort) or channel indices, in the order given |
| `Groups` | `[]` | keep only clusters labelled e.g. `["good" "mua"]` (phy's `cluster_group.tsv` when present, else `cluster_KSLabel.tsv`) |
| `DetectOptions` | `struct()` | `detectSpikes` options (`Source="detect"`) |
| `TimeRange` | `[-Inf Inf]` | analysis window; spikes outside it are dropped and `t` spans it |
| `TimeBase` | `"recording"` | `"window"` subtracts `t0` so the times and `t` start at 0 — what the hybrid routines need (see below) |
| `SpikeFs` | property | grid rate for `t` and `params.Fs` |

The window defaults to the recording duration, then the loaded signal's
duration, then the last spike — the last case warns, because rates and the
taper grid are then set by the spikes themselves. `info` records which
(`timeRangeSource`), plus `unitIds`, `labels`, `groupLabels`, `counts`, `rates`,
`sampleRate` and `nDroppedOutsideRange`.

There is **no silent 30 kHz fallback**: when `params.py` has no `sample_rate`,
the recording's rate is used with a warning, and if no recording is attached the
call errors rather than guess.

### `[data, params, t, info] = cx.spikeTrials(onsets, twin, Name=Value)`

One unit's spike train cut into one Chronux trial per onset (see
[Spike trial windows](#spike-trial-windows)). Options: `Unit` (required when the
source holds several), `TimeBase`, `Incomplete` (`"drop"` by default — a
truncated window holds fewer spikes than it should, which biases both the rate
and the spectrum), `Spikes` (epoch a struct array you already have),
`Source` / `Times` / `ResultsDir` / `Units` / `Groups` / `DetectOptions`
(forwarded to `spikes`), `SpikeFs`, and the params overrides.

### `[data, params, t, info] = cx.binnedSpikes(Name=Value)`

Counts per bin, `[nBins x nUnits]` (or `x nTrials` when handed the output of
`spikeTrials`). Bin *k* covers `[t0+(k-1)/BinFs, t0+k/BinFs)`, half-open, and a
trailing partial bin is dropped; `t` holds each bin's **left edge**. Counts are
counts — never rates, never smoothed. Chronux's binned routines report the rate
as `mean(count)*Fs`, so `params.Fs` is the bin rate.

Options: `Times`, `BinFs` (default `SpikeFs`), `TimeRange`, the `spikes`
forwarding options, and the params overrides. `info.maxCount` reports the
busiest bin; more than one spike in a bin warns, since the binned point-process
routines assume finer bins.

### `[onsets, info] = cx.eventOnsets(name, Name=Value)`

Digital-input onsets as trial triggers. `name` is a line name (`"din0"`) or its
position; it may be omitted when the recording has exactly one line. Options:
`MinDurationSec`, `MaxDurationSec`, `TimeRange`. `info` carries `offsets`,
`durations`, `keptEvents`, `droppedDuration`, `droppedTimeRange` and every line
name in the recording.

### Statics

| Call | Returns |
| --- | --- |
| `ChronuxDataset.makeParams(Fs, Name=Value)` | a validated params struct with Chronux's six fields and nothing else |
| `ChronuxDataset.tapersFor(W, T, P=1)` | `[TW K]`, plus an info struct |
| `ChronuxDataset.toPointProcess(times)` | vector / cell / struct array → `1 x N` struct array of `times` |
| `ChronuxDataset.castTo(X, class)` | `"double"` / `"single"` / `"asis"` |
| `ChronuxDataset.hasChronux()` / `requireChronux()` | is Chronux on the path? |

---

## Examples

### LFP spectrum of one channel

```matlab
cx = ChronuxDataset("D:\rec\subj1_day1", Signal="LFP");
cx.Tapers = ChronuxDataset.tapersFor(2, 10);         % ±2 Hz over the 10 s window
[data, params] = cx.continuous(Channels=1, TimeRange=[0 10], Fpass=[0 100]);
[S, f] = mtspectrumc(data, params);
plot(f, 10*log10(S));
```

### Trial-averaged spectrogram around a digital-input event

```matlab
onsets = cx.eventOnsets("din0", MinDurationSec=0.01);
movingwin = [0.5 0.05];
cx.Tapers = ChronuxDataset.tapersFor(4, movingwin(1));
[D, params, T, info] = cx.trials(onsets, [-0.5 1.5], Channels=5, TrialAve=1);
fprintf('%d of %d trials used\n', info.nTrials, numel(onsets));
[S, t, f] = mtspecgramc(D, movingwin, params);
imagesc(t + info.twin(1), f, 10*log10(S).');   % t starts at 0 in the epoch
```

### Spike-train spectrum

```matlab
cx = ChronuxDataset(ds, Signal="LFP");
[sp, pp, t, si] = cx.spikes(Groups="good", SpikeFs=1000);
[S, f, R] = mtspectrumpt(sp(1), pp, 0, t);
```

### Spike–field coherence (hybrid routines)

`coherencycpt` builds its own grid from the **continuous** data —
`t = 0:1/Fs:(N-1)/Fs` — so the spike times have to be on that same zero-based
clock, and `params.Fs` has to be the continuous rate. `TimeBase="window"` does
the shift:

```matlab
win = [10 70];                                   % the same stretch for both
[lfp, pc, ci] = cx.continuous(Channels=8, TimeRange=win);
sp = cx.spikes(Units=3, TimeRange=win, TimeBase="window", SpikeFs=cx.Fs);
[C, phi, S12, S1, S2, f] = coherencycpt(lfp, sp, pc);
```

`ci.nSamples` samples span `(ci.nSamples-1)/Fs` seconds, exactly the length of
the shifted spike window, so the two describe the same interval.

### Binned counts

```matlab
[counts, params, tb] = cx.binnedSpikes(BinFs=1000, TimeRange=[0 60]);
[S, f, R] = mtspectrumpb(counts, params);
```

`coherencycpb` needs one bin per continuous sample. `continuous` over `[t0 t1]`
returns `(t1-t0)*Fs + 1` samples (both ends inclusive) while bins are half-open,
so add one bin's width to the right edge:

```matlab
[lfp, pc, ci] = cx.continuous(Channels=8, TimeRange=win);
[cnt, ~, ~, bi] = cx.binnedSpikes(BinFs=cx.Fs, ...
    TimeRange=[ci.timeRange(1), ci.timeRange(2) + 1/cx.Fs]);
isequal(bi.nBins, ci.nSamples)      % true: bin k starts on sample k
[C, phi, S12, S1, S2, f] = coherencycpb(lfp, cnt, pc);
```

---

## Things to know

| Topic | Behavior |
| --- | --- |
| Memory | `continuous` and `trials` copy the samples they return (and cast to double by default), on top of the whole signal held by `loadSignal` |
| Point-process grid size | `t` has `(t1-t0)*SpikeFs + 1` points and Chronux computes DPSS over all of it; a warning fires above 10⁷ points. Lower `SpikeFs` or shorten `TimeRange` |
| `trialave` and channels | Chronux averages the second dimension: for `continuous` those are channels, for `trials` they are trials |
| Derived-rate onsets | a dig-in onset is accurate to ±1 sample of the derived rate (1 ms at `LFP_Fs = 1000`) |
| `Signal="SPIKE"` + `Source="detect"` | the signal is already band-passed and `detectSpikes` filters again by default; the call warns and points at `DetectOptions=struct('Filter',false)` |
| Kilosort channel ids | `spikes` reports cluster ids as sorted, not channels; peak channels are in the `units` struct from `EphysDataset.readSortedUnits` (`channel`, 1-based recording channel) |
| Chronux not required | preparing data never calls Chronux; only your analysis does |
| Files for later | `EphysDataset.exportChronux` (the pipeline's Export step) writes `<Name>_chronux.mat` with `LFP` / `MUA` / `SPIKE` structs (`data`, `params`, `t`, `labels`) and `sp` built by this class, so the analysis can run on a machine without the recordings; see [file-formats.md](file-formats.md#chronux-export-ephysdatasetexportchronux-the-export-step) |

## Main error identifiers

| Identifier | Raised when |
| --- | --- |
| `ChronuxDataset:BadSource` / `NoFs` / `NoFile` / `MatrixClass` | constructor could not make sense of the source, or it was an integer matrix |
| `ChronuxDataset:NoSource` / `NoData` | a method needs data but no source was given |
| `ChronuxDataset:BadMat` / `SignalMissing` / `RawFromMat` | a `.mat` source lacks `Y` / `info`, or the requested signal |
| `ChronuxDataset:DataTypeOut` / `RawOptions` | `SignalOptions` conflicts with `Signal` |
| `ChronuxDataset:BadChannel` / `UnknownChannel` | channel selection out of range or unknown |
| `ChronuxDataset:BadTimeRange` / `EmptyTimeRange` | time range reversed, or selecting no samples |
| `ChronuxDataset:BadWindow` / `NoOnsets` / `NoTrials` | trial window reversed, no onsets, or nothing left after the trial policies |
| `ChronuxDataset:IncompleteTrials` / `NonFiniteTrials` | with `"error"` policies (otherwise warnings) |
| `ChronuxDataset:Tapers` / `Fpass` / `Err` / `TrialAve` | `makeParams` validation |
| `ChronuxDataset:NoSpikeSource` / `NoKilosortOutput` / `NoSampleRate` | spikes requested with nothing to read |
| `ChronuxDataset:UnknownUnit` / `UnitRequired` / `NoGroupMatch` | unit selection |
| `ChronuxDataset:NoEvents` / `EventLine` | digital-input line missing or ambiguous |
| `ChronuxDataset:NoChronux` | `requireChronux` and Chronux is not on the path |

## Tests

[`test_ChronuxDataset.m`](../pipeline/test_ChronuxDataset.m) builds its fixtures in
a temp folder and deletes them afterwards. It covers:

| Section (as printed by the test) | Covers |
| --- | --- |
| 1 | `makeParams` / `tapersFor` / `toPointProcess` validation |
| 2 | matrix source and `continuous` (channels, time range, detrend, class) |
| 3 | `trials`: both onset rules, exact rows, incomplete and non-finite policies |
| 4 | a `toMat`-shaped `.mat` source, the same data as a struct source, and `eventOnsets` |
| 5 | `spikes`: struct array, analysis window, `TimeRange` |
| 6 | `spikeTrials`: the `createdatamatpt` selection rule and time bases |
| 7 | `binnedSpikes`: half-open bins and exact counts |
| 8 | the Kilosort4 / phy source, with real `.npy` fixtures written by `writeNPY` (also covers `readNPY`) |
| 9 | guard rails |

Neither Chronux, real recordings, nor MATLAB toolboxes beyond base MATLAB are
needed to run it.
