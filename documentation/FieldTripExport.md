# FieldTripExport

[`FieldTripExport`](../pipeline/@FieldTripExport/FieldTripExport.m) is a static
class of pure packaging functions that build the data structures the
[FieldTrip](https://www.fieldtriptoolbox.org/) toolbox documents
(`ft_datatype_raw`, `ft_datatype_spike`, `ft_read_event`) from what this
pipeline already produces. `EphysDataset.exportFieldTrip` writes them to one
`.mat` per dataset. Nothing here reads a recording or calls FieldTrip;
FieldTrip is only needed to analyze the result (and, optionally, to validate
it).

FieldTrip and [Chronux](ChronuxDataset.md) are separate toolboxes with
separate exporters. They take the same neutral inputs but share no code, and
neither output is derived from the other.

## Inputs

| Input | Comes from |
| --- | --- |
| extract struct `S` (`Y`, `events`, `info`) | `EphysDataset.toMat` (the Signals step), loaded or as a struct |
| `units` struct | `EphysDataset.readSortedUnits` / `readPhyUnits` (Kilosort4 / phy output) |
| `detected` struct | `EphysDataset.spikesToMat` (threshold detection) |

## Static functions

| Call | Returns |
| --- | --- |
| `data = FieldTripExport.raw(S, "LFP", Class="double")` | a raw structure with **one trial spanning the signal**: `label` (`nChan x 1` cellstr), `time{1}` = `(k-1)/Fs`, `trial{1}` = `[nChan x N]` (the transpose of the pipeline's `[N x nChan]`), `fsample`, `sampleinfo = [1 N]`, `hdr` (`Fs`, `nChans`, `nSamples`, `nSamplesPre = 0`, `nTrials = 1`, `label`, `chantype`, `chanunit = {'uV'}`, `FirstTimeStamp = 0`, `TimeStampPerSample = origFs/Fs`), `cfg` (`exportFieldTrip` adds `cfg.event` at this signal's rate, each onset on the sample nearest its recording row, and `cfg.artfctdef.preprocessing.artifact`, below) |
| `data = FieldTripExport.continuous(X, Fs, ...)` | the general builder of `raw`: a raw structure of any continuous signal `X` (`[nSamples x nChan]`, row `k` at `(k-1)/Fs`), one trial as above. Options: `Label` (default `ch1..chN`), `ChanType` (`"lfp"`), `ChanUnit` (`"uV"`), `Positions` (`[nChan x 2\|3]` µm: `data.elec`, `unit = 'um'`, when every one is finite), `OrigFs` (the recording rate, for `TimeStampPerSample`; default `Fs`), `Class`, `Cfg` (fields added to `data.cfg`) |
| `data = FieldTripExport.epochs(X, t, ...)` | a raw structure with **a trial per epoch**: `X` is `[nChan x nTime x nEpochs]` and `t` the `nTime` times, s from each epoch's event (`time{k} = t`, `fsample` from `t`, or `Fs=`). `Onsets=` (each epoch's event, s on the continuous clock of the signal it was cut from) gives `sampleinfo`, the first sample at `round(onset*Fs) + 1 + round(t(1)*Fs)`; without it there is none. `TrialInfo=` (`nEpochs` rows, a matrix or a table) is `trialinfo`. `hdr.nSamplesPre` is the samples before the event. The other options as in `continuous` |
| `[trl, keep] = FieldTripExport.trl(onsets, [pre post], Fs, Info=, NSamples=)` | a trial definition for `ft_redefinetrial` on a `continuous` structure: `[begsample endsample offset]` around event times `onsets` (s on the signal's clock), on the same samples `epochs` gives with those onsets, plus the columns of `Info` (`trialinfo`). Trials with a NaN onset or off a signal of `NSamples` samples are dropped; `keep` marks the onsets kept |
| `spike = FieldTripExport.spike(units)` | a spike structure: `label` (`1 x nUnits`, the unit labels, e.g. `su042_1255_260908T1039`), `timestamp{u}` = 0-based recording samples (Kilosort's `spike_times`), `hdr` (`Fs = units.fs`, `FirstTimeStamp = 0`, `TimeStampPerSample = 1`), `cfg`. No `time` / `trial` fields: cut trials in FieldTrip with `ft_spike_maketrials` |
| `spike = FieldTripExport.spikeFromDetected(detected)` | the same, one "unit" per detected channel |
| `event = FieldTripExport.event(events, Fs, EventFs=)` | struct array, one element per digital-input pulse at a signal's rate `Fs`: `type` (line name), `sample = round((t_on - 1/EventFs)*Fs) + 1` (1-based; the pulse times count rows of the `EventFs` clock, `t = row/EventFs`, so at `Fs = EventFs`, the default, it is the row that produced the onset, and otherwise the nearest sample of the signal), `value = 1`, `offset = 0`, `duration = round((t_off - t_on)*Fs) + 1` (samples, inclusive), sorted by sample. `exportFieldTrip` passes the recording rate as `EventFs` |
| `art = FieldTripExport.artifact(intervals, data)` | the artifact periods `intervals` (`[k x 2]` `[tStart tEnd)` seconds on the continuous clock, as the extract's `info.artifacts.intervals`) as `[begsample endsample]` rows of the raw structure `data`, on its `sampleinfo`: every sample of the signal a period touches (`EphysDataset.intervalRows`), so a period shorter than one sample of a derived signal still marks one. It is the matrix `ft_rejectartifact` reads from `cfg.artfctdef.<type>.artifact`; `[]` with no periods. `exportFieldTrip` stores it in each signal's `cfg.artfctdef.preprocessing.artifact` |
| `[ok, msg] = FieldTripExport.validate(s, kind)` | `kind` `"raw"` or `"spike"`: runs `ft_datatype_raw(s)` / `ft_datatype_spike(s)` when FieldTrip is on the path; `ok` is false and `msg` FieldTrip's error when the check fails. Without FieldTrip `ok` is true and `msg` says the structure was not validated |
| `FieldTripExport.hasFieldTrip()` | is FieldTrip on the path? |

Raw and spike structures share the recording's sample clock through
`hdr.TimeStampPerSample`, so a spike at (0-based) sample `k` of a 30 kHz sort
lines up with sample `k/30 + 1` of a 1 kHz LFP: FieldTrip reads timestamp `k`
as sample `k/TimeStampPerSample + 1`, the LFP row at `t = k/30000` s. Kilosort index `k` ↔ `t = k/fs`
matches this repository's `t = (row-1)/Fs`, so there is no off-by-one.

## `EphysDataset.exportFieldTrip`

```matlab
out = ds.exportFieldTrip();                        % <outputFolder>/<Name>_fieldtrip.mat
out = ds.exportFieldTrip(Signals="LFP", Units=false, Detected=false);
out = ds.exportFieldTrip(Extract=S, Units=units, File="D:\ft\subj1.mat", Overwrite=true);
```

| Option | Default | Meaning |
| --- | --- | --- |
| `File` | `<outputFolder>/<Name>_fieldtrip.mat` | target |
| `Extract` | `<outputFolder>/<Name>_extract.mat`, else the `<Name>_extract_<TYPE>.mat` files present | other extract file(s) (several are merged; with `Signals`, the per-type files of other signals are not read), or a `toMat`-shaped struct |
| `Signals` | all present | subset of `["LFP" "MUA" "SPIKE" "AUX"]` |
| `Units` | the associated sorted units | a units struct, or `false` |
| `Groups` | `["good" "mua"]` | phy labels kept when reading the units |
| `Detected` | `<Name>_spikes.mat` when present | a spikes file, a `detected` struct, or `false` |
| `Sources` | `struct()` | provenance to record for inputs passed as structs (`extractFile`, `spikesFile`, `sortingDir`); what is read from files replaces it |
| `Events` | `true` | write `event` and each signal's `cfg.event` |
| `Validate` | `true` | validate with FieldTrip when it is on the path; the outcome is recorded in `export.validation` |
| `Overwrite`, `MatVersion` | `false`, `"-v7.3"` | |

Variables in the file: `data_LFP` / `data_MUA` / `data_SPIKE` / `data_AUX`, `spike`,
`spikeDetected`, `event` and `export` (provenance: `tool`,
`created`, `dataset`, `sources`, `signals`, `eventFs`, `artifacts` (the
extract's `info.artifacts`: the periods erased before the signals were
derived, in seconds), `validation`). Absent
inputs are stored as `[]`. The file is written atomically
(`EphysDataset.saveAtomically`). Schema summary in
[file-formats.md](file-formats.md#fieldtrip-export-ephysdatasetexportfieldtrip-the-export-step).

Loading it in FieldTrip:

```matlab
F = load("subj1_fieldtrip.mat");
cfg = [];
cfg.hdr   = F.data_LFP.hdr;                         % sampling rate for the trial definition
cfg.event = F.data_LFP.cfg.event;                   % events at the LFP rate
cfg.trialdef.eventtype = 'din0'; cfg.trialdef.prestim = 0.5; cfg.trialdef.poststim = 1.5;
cfg.trialfun = 'ft_trialfun_general';
cfg = ft_definetrial(cfg);
trials = ft_redefinetrial(cfg, F.data_LFP);
spk = ft_spike_maketrials(struct('trl', cfg.trl, 'trlunit', 'samples', 'hdr', F.data_LFP.hdr), F.spike);
```

`trlunit = 'samples'` with the LFP `hdr` maps the 30 kHz spike timestamps onto
LFP samples through `hdr.TimeStampPerSample`. FieldTrip's samples mode puts a
spike on trial sample *k* at `(k - begsample + 0.5)/Fs + offset/Fs`, so a spike
on the onset's own row reads 0 to +1 LFP sample.

Each `data_<SIG>.cfg.artfctdef.preprocessing.artifact` lists the samples of
that signal the erased artifact periods cover, on its `sampleinfo`: the
matrix `ft_rejectartifact` reads to reject the trials that touch one.

## From the analysis results

Two functions in [`analysis/`](../analysis) hand the DatasetBrowser's data
(`epochMatrix` results and `sessionData` sessions) to the general builders.
Each returns a cell column of raw structures, one per dataset:

| Call | Returns |
| --- | --- |
| `F = epochMatrixFieldTrip(R, Class=)` ([source](../analysis/epochMatrixFieldTrip.m)) | the epochs of a signal result computed with `keepEpochs=true` (`FieldTripExport.epochs`): `F{k}` is `R.epochs(k)`'s, `trial{j}` epoch `j` as the browser averaged it (never normalized), `time{j} = R.t`, `sampleinfo` on the dataset's continuous signal, `trialinfo = [resultGroup trial]` (the group in `R.groupLabels`, the same across datasets; the trial in the session), `elec` from `R.rows.x`/`y`, and in `cfg` the dataset, the description, the event, the window, `groupLabels`, `groups` and `epochs` (the epochs' table). A spike result raises `epochMatrixFieldTrip:NotSignal`, one without epochs `epochMatrixFieldTrip:NoEpochs` |
| `F = sessionDataFieldTrip(D, Window=, Align="TrialOnset", Class=)` ([source](../analysis/sessionDataFieldTrip.m)) | whole-session signals (`B.Sessions` after **Load whole sessions** of LFP, MUA, SPIKE or AUX; `FieldTripExport.continuous`): the whole signal as one trial, `elec`, `hdr.TimeStampPerSample` = the recording rate / the signal's, `cfg.event` (every line's pulses at the signal's rate, derived events included), `cfg.artfctdef.preprocessing.artifact` (the erased periods) and `cfg.groups`. `Window=[pre post]` adds `cfg.trl` (`FieldTripExport.trl`): the kept trials around `Align` (a `D.trials` column on the digital clock, moved to the continuous one), `[begsample endsample offset group trial]`. A session without a signal raises `sessionDataFieldTrip:NoSignal` |

```matlab
R = B.compute();                                  % Data LFP, keepEpochs=true
F = epochMatrixFieldTrip(R);
cfg = []; cfg.method = 'mtmfft'; cfg.taper = 'hanning'; cfg.foi = 1:100;
cfg.trials = find(F{1}.trialinfo(:, 1) == 1);     % the first group
freq = ft_freqanalysis(cfg, F{1});

G = sessionDataFieldTrip(B.loadSessions(), Window=[-0.5 1]);
cfg = []; cfg.trl = G{1}.cfg.trl;
trials = ft_redefinetrial(cfg, G{1});
```

[`S_DatasetBrowserLFPToFieldTrip.m`](../analysis/scripts/S_DatasetBrowserLFPToFieldTrip.m)
does both as a DatasetBrowser post-processing script.

## Tests

[`test_FieldTripExport.m`](../pipeline/test_FieldTripExport.m): `raw`
(`trial{1}` = `Y.LFP.'`, `time{1}(1) == 0`, `sampleinfo == [1 N]`, labels,
`hdr.TimeStampPerSample == origFs/Fs`), `spike` (timestamps equal the sorted
samples, `FirstTimeStamp == 0`, no `time` / `trial`, the unit metadata in
`hdr.orig`), detected spikes (`spikeFromDetected`: one unit per channel),
`event` (`sample` = the
row at the recording rate; with `EventFs` the nearest sample at a derived
rate, row 180001 at 30 kHz → 6001 at 1 kHz; durations, ordering),
`exportFieldTrip`'s per-signal `cfg.event`, `artifact` (the periods as
`[begsample endsample]` at the LFP rate, a period shorter than one sample
included; at the recording rate exactly its own samples; `[]` with none) and
each signal's `cfg.artfctdef.preprocessing.artifact`, the `export` record's event rate and periods,
the general builders (`continuous`: the transpose, default labels, `elec`
only with every position known; `epochs`: a trial per epoch, `sampleinfo`
from the onsets, `trialinfo`; `trl`: the same samples as `epochs`, NaN and
off-signal trials dropped), and
`Validate` as a no-op without FieldTrip (the checks run `ft_datatype_raw` /
`ft_datatype_spike` when a FieldTrip checkout is on the path).
[`test_DatasetBrowser.m`](../analysis/test_DatasetBrowser.m)
(`fieldTripOfEpochsAndSessions`) checks `epochMatrixFieldTrip` and
`sessionDataFieldTrip` on the browser's own results: each epoch equals the
session's signal at its `sampleinfo`, every pulse is an event, and the `trl`
holds only the kept trials with their groups.
