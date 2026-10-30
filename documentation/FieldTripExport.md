# FieldTripExport

[`FieldTripExport`](../pipeline/@FieldTripExport/FieldTripExport.m) is a static
class of pure packaging functions that build the data structures the
[FieldTrip](https://www.fieldtriptoolbox.org/) toolbox documents
(`ft_datatype_raw`, `ft_datatype_spike`, `ft_read_event`) from what this
pipeline already produces. The [DatasetBrowser](DatasetBrowser.md) feeds them
its results, through `epochMatrixFieldTrip` and `sessionDataFieldTrip`
([below](#from-the-analysis-results)). Nothing here reads a recording or calls
FieldTrip; FieldTrip is only needed to analyze the result (and, optionally, to
validate it).

FieldTrip and [Chronux](ChronuxDataset.md) are separate toolboxes with
separate connectors. They take the same neutral inputs but share no code, and
neither output is derived from the other.

## Inputs

| Input | Comes from |
| --- | --- |
| a signal `X` (`[nSamples x nChan]`) and its rate `Fs` | the extract (`EphysDataset.toMat`, the Signals step): `Y.<SIG>` and `info.<SIG>.Fs` |
| spike times `times{u}` (s) | sorted units (`EphysDataset.readSortedUnits` / `readPhyUnits`: `times`) or threshold detections (`EphysDataset.spikesToMat`: `detected.ts`) |
| `events`, `intervals` | the extract's `events` and `info.artifacts.intervals` |

## Static functions

| Call | Returns |
| --- | --- |
| `data = FieldTripExport.continuous(X, Fs, ...)` | a raw structure of any continuous signal `X` (`[nSamples x nChan]`, row `k` at `(k-1)/Fs`) with **one trial spanning the signal**: `label` (`nChan x 1` cellstr), `time{1}` = `(k-1)/Fs`, `trial{1}` = `[nChan x N]` (the transpose of the pipeline's `[N x nChan]`), `fsample`, `sampleinfo = [1 N]`, `hdr` (`Fs`, `nChans`, `nSamples`, `nSamplesPre = 0`, `nTrials = 1`, `label`, `chantype`, `chanunit`, `FirstTimeStamp = 0`, `TimeStampPerSample = OrigFs/Fs`), `cfg`. Options: `Label` (default `ch1..chN`), `ChanType` (`"lfp"`), `ChanUnit` (`"uV"`), `Positions` (`[nChan x 2\|3]` µm: `data.elec`, `unit = 'um'`, when every one is finite; 2-D positions are centered on the probe (`x` and `y` minus their midrange) and get `z = rho/tan(rho/R)`, `rho = hypot(x, y)`, `R = 100*max(rho)`, so the layout FieldTrip makes from `elec` (its default polar projection, e.g. `ft_multiplotER` without `cfg.layout`) keeps the probe's spacing), `OrigFs` (the recording rate, for `TimeStampPerSample`; default `Fs`), `Class`, `Cfg` (fields added to `data.cfg`) |
| `data = FieldTripExport.epochs(X, t, ...)` | a raw structure with **a trial per epoch**: `X` is `[nChan x nTime x nEpochs]` and `t` the `nTime` times, s from each epoch's event (`time{k} = t`, `fsample` from `t`, or `Fs=`). `Onsets=` (each epoch's event, s on the continuous clock of the signal it was cut from) gives `sampleinfo`, the first sample at `round(onset*Fs) + 1 + round(t(1)*Fs)`; without it there is none. `TrialInfo=` (`nEpochs` rows, a matrix or a table) is `trialinfo`. `hdr.nSamplesPre` is the samples before the event. The other options as in `continuous` |
| `[trl, keep] = FieldTripExport.trl(onsets, [pre post], Fs, Info=, NSamples=)` | a trial definition for `ft_redefinetrial` on a `continuous` structure: `[begsample endsample offset]` around event times `onsets` (s on the signal's clock), on the same samples `epochs` gives with those onsets, plus the columns of `Info` (`trialinfo`). Trials with a NaN onset or off a signal of `NSamples` samples are dropped; `keep` marks the onsets kept |
| `spike = FieldTripExport.spikeTimes(times, Fs, Label=, DurationSec=, Cfg=)` | a spike structure from spike trains given as times (`times{u}`, s on the continuous clock): `label` (`1 x nUnits`; default `unit1..unitN`, or the unit labels, e.g. `su042_1255_260908T1039`), `timestamp{u} = round(t*Fs)`, 0-based recording samples (Kilosort's `spike_times`), `hdr` (`Fs`, `FirstTimeStamp = 0`, `TimeStampPerSample = 1`; `DurationSec` gives `nSamples`), `cfg`. No `time` / `trial` fields: cut trials with `ft_spike_maketrials` (`cfg.trl` in these timestamps, `cfg.timestampspersecond = Fs`) |
| `spike = FieldTripExport.spikeTrials(times, trial, [pre post], ...)` | a spike structure of spikes **already cut into trials**, the shape `ft_spike_maketrials` leaves: `time{u}` (s from each trial's event), `trial{u}` (each spike's trial), `trialtime` = `[pre post]` for every trial. `Onsets=` (each trial's event, s on the continuous clock) with `Fs=` (the recording rate) gives `timestamp{u} = round((onset + t)*Fs)`, the spikes' samples on the recording; without them `timestamp` (which FieldTrip requires) is microseconds from each trial's event. `NTrials=` (default: the onsets', else the last trial a spike is in), `TrialInfo=`, `Label=`, `Cfg=` |
| `event = FieldTripExport.event(events, Fs, EventFs=)` | struct array, one element per digital-input pulse at a signal's rate `Fs`: `type` (line name), `sample = round((t_on - 1/EventFs)*Fs) + 1` (1-based; the pulse times count rows of the `EventFs` clock, `t = row/EventFs`, so at `Fs = EventFs`, the default, it is the row that produced the onset, and otherwise the nearest sample of the signal), `value = 1`, `offset = 0`, `duration = round((t_off - t_on)*Fs) + 1` (samples, inclusive), sorted by sample. `sessionDataFieldTrip` passes the recording rate as `EventFs` |
| `art = FieldTripExport.artifact(intervals, data)` | the artifact periods `intervals` (`[k x 2]` `[tStart tEnd)` seconds on the continuous clock, as the extract's `info.artifacts.intervals`) as `[begsample endsample]` rows of the raw structure `data`, on its `sampleinfo`: every sample of the signal a period touches (`EphysDataset.intervalRows`), so a period shorter than one sample of a derived signal still marks one. It is the matrix `ft_rejectartifact` reads from `cfg.artfctdef.<type>.artifact`, to reject the trials that touch a period; `[]` with no periods. `sessionDataFieldTrip` stores it in each signal's `cfg.artfctdef.preprocessing.artifact` |
| `[ok, msg] = FieldTripExport.validate(s, kind)` | `kind` `"raw"` or `"spike"`: runs `ft_datatype_raw(s)` / `ft_datatype_spike(s)` when FieldTrip is on the path; `ok` is false and `msg` FieldTrip's error when the check fails. Without FieldTrip `ok` is true and `msg` says the structure was not validated |
| `FieldTripExport.hasFieldTrip()` | is FieldTrip on the path? |

Raw and spike structures share the recording's sample clock through
`hdr.TimeStampPerSample`, so a spike at (0-based) sample `k` of a 30 kHz sort
lines up with sample `k/30 + 1` of a 1 kHz LFP: FieldTrip reads timestamp `k`
as sample `k/TimeStampPerSample + 1`, the LFP row at `t = k/30000` s. Kilosort index `k` ↔ `t = k/fs`
matches this repository's `t = (row-1)/Fs`, so there is no off-by-one.

## From the analysis results

Two functions in [`analysis/`](../analysis) hand the DatasetBrowser's data
(`epochMatrix` results and `sessionData` sessions) to the general builders.
Each returns a cell column of structures, one per dataset: raw structures
for a signal, spike structures for spikes (units or detected):

| Call | Returns |
| --- | --- |
| `F = epochMatrixFieldTrip(R, Class=)` ([source](../analysis/epochMatrixFieldTrip.m)) | the epochs of a signal result computed with `keepEpochs=true` (`FieldTripExport.epochs`): `F{k}` is `R.epochs(k)`'s, `trial{j}` epoch `j` as the browser averaged it (never normalized), `time{j} = R.t`, `sampleinfo` on the dataset's continuous signal, `trialinfo = [resultGroup trial]` (the group in `R.groupLabels`, the same across datasets; the trial in the session), `elec` from `R.rows.x`/`y`, and in `cfg` the dataset, the description, the event, the window, `groupLabels`, `groups` and `epochs` (the epochs' table). A spike result gives spike structures (`FieldTripExport.spikeTrials`): `time{u}` the spikes inside the window's whole bins (the span the PSTH counts, which is `trialtime`), `trial{u}` each spike's epoch, the same `trialinfo` and `cfg`, and with `Fs=` (the recording rate, one or one per dataset: `B.source(key).fs`) `timestamp{u}` on the recording's samples. A result without epochs raises `epochMatrixFieldTrip:NoEpochs` |
| `F = sessionDataFieldTrip(D, Window=, Align="TrialOnset", Class=)` ([source](../analysis/sessionDataFieldTrip.m)) | whole-session signals (`B.Sessions` after **Load whole sessions** of LFP, MUA, SPIKE or AUX; `FieldTripExport.continuous`): the whole signal as one trial, `elec`, `hdr.TimeStampPerSample` = the recording rate / the signal's, `cfg.event` (every line's pulses at the signal's rate, derived events included), `cfg.artfctdef.preprocessing.artifact` (the erased periods) and `cfg.groups`. Spike sessions (**Load whole sessions** of units or detected; `FieldTripExport.spikeTimes`) give every spike's `timestamp`, 0-based samples at the recording rate (`hdr.Fs`), `cfg.event` at that rate (`sample` = timestamp + 1), the erased periods in `cfg.artifact` (s) and `cfg.groups`. `Window=[pre post]` adds `cfg.trl` (`FieldTripExport.trl`): the kept trials around `Align` (a `D.trials` column on the digital clock, moved to the continuous one), `[beg end offset group trial]`, in samples for `ft_redefinetrial` on a signal, in timestamps for `ft_spike_maketrials` (`cfg.timestampspersecond = hdr.Fs`) on spikes. A session with neither raises `sessionDataFieldTrip:NoData` |

```matlab
R = B.compute();                                  % Data LFP, keepEpochs=true
F = epochMatrixFieldTrip(R);
cfg = []; cfg.method = 'mtmfft'; cfg.taper = 'hanning'; cfg.foi = 1:100;
cfg.trials = find(F{1}.trialinfo(:, 1) == 1);     % the first group
freq = ft_freqanalysis(cfg, F{1});

G = sessionDataFieldTrip(B.loadSessions(), Window=[-0.5 1]);
cfg = []; cfg.trl = G{1}.cfg.trl;
trials = ft_redefinetrial(cfg, G{1});

R = B.compute();                                  % Data units, keepEpochs=true
F = epochMatrixFieldTrip(R, Fs=arrayfun(@(e) B.source(e.key).fs, R.epochs));
cfg = []; cfg.binsize = 0.025; cfg.trials = find(F{1}.trialinfo(:, 1) == 1);
psth = ft_spike_psth(cfg, F{1});

G = sessionDataFieldTrip(B.loadSessions(), Window=[-0.5 1]);   % Data units
cfg = []; cfg.trl = G{1}.cfg.trl; cfg.timestampspersecond = G{1}.hdr.Fs;
spk = ft_spike_maketrials(cfg, G{1});
```

[`S_DatasetBrowserToFieldTrip.m`](../analysis/browser_scripts/S_DatasetBrowserToFieldTrip.m)
does both, for a signal or spikes, as a DatasetBrowser post-processing script.

## Tests

[`test_FieldTripExport.m`](../pipeline/test_FieldTripExport.m): `continuous`
(`trial{1}` = `X.'`, `time{1}(1) == 0`, `sampleinfo == [1 N]`, labels,
`hdr.TimeStampPerSample == origFs/Fs`, `Class`), `event` (`sample` = the
row at the recording rate; with `EventFs` the nearest sample at a derived
rate, row 180001 at 30 kHz → 6001 at 1 kHz; durations, ordering), `artifact`
on a raw structure (the periods as `[begsample endsample]` at the LFP rate, a
period shorter than one sample included; at the recording rate exactly its
own samples; `[]` with none), the general builders (`continuous`: the
transpose, default labels, `elec` only with every position known; `epochs`: a
trial per epoch, `sampleinfo` from the onsets, `trialinfo`; `trl`: the same
samples as `epochs`, NaN and off-signal trials dropped; `spikeTimes`: the
timestamps in 0-based samples; `spikeTrials`: `time` / `trial` / `trialtime` /
`trialinfo` as given, the timestamps on the recording, microseconds without
onsets, a spike outside the trials refused), and `validate` as a no-op
without FieldTrip (the checks run `ft_datatype_raw` / `ft_datatype_spike` when
a FieldTrip checkout is on the path).
[`test_DatasetBrowser.m`](../analysis/test_DatasetBrowser.m)
(`fieldTripOfEpochsAndSessions`) checks `epochMatrixFieldTrip` and
`sessionDataFieldTrip` on the browser's own results: each epoch equals the
session's signal at its `sampleinfo`, every pulse is an event, and the `trl`
holds only the kept trials with their groups; for units, each epoch's spikes
match `R.epochs`, every one is a session spike at the same timestamp, and the
session's `trl` puts each trial's event at its timestamp.
