# FieldTripExport

[`FieldTripExport`](../pipeline/@FieldTripExport/FieldTripExport.m) is a static
class of pure packaging functions that build the data structures the
[FieldTrip](https://www.fieldtriptoolbox.org/) toolbox documents
(`ft_datatype_raw`, `ft_datatype_spike`, `ft_read_event`) from what this
pipeline already produces. `EphysDataset.exportFieldTrip` writes them to one
`.mat` per dataset. Nothing here reads a recording or calls FieldTrip;
FieldTrip is only needed to analyse the result (and, optionally, to validate
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
| `spike = FieldTripExport.spike(units)` | a spike structure: `label` (`1 x nUnits`, the unit labels, e.g. `su042_1255_260908T1039`), `timestamp{u}` = 0-based recording samples (Kilosort's `spike_times`), `hdr` (`Fs = units.fs`, `FirstTimeStamp = 0`, `TimeStampPerSample = 1`), `cfg`. No `time` / `trial` fields: cut trials in FieldTrip with `ft_spike_maketrials` |
| `spike = FieldTripExport.spikeFromDetected(detected)` | the same, one "unit" per detected channel |
| `event = FieldTripExport.event(events, Fs, EventFs=)` | struct array, one element per digital-input pulse at a signal's rate `Fs`: `type` (line name), `sample = round((t_on - 1/EventFs)*Fs) + 1` (1-based; the pulse times count rows of the `EventFs` clock, `t = row/EventFs`, so at `Fs = EventFs`, the default, it is the row that produced the onset, and otherwise the nearest sample of the signal), `value = 1`, `offset = 0`, `duration = round((t_off - t_on)*Fs) + 1` (samples, inclusive), sorted by sample. `exportFieldTrip` passes the recording rate as `EventFs` |
| `art = FieldTripExport.artifact(intervals, data)` | the artifact periods `intervals` (`[k x 2]` `[tStart tEnd)` seconds on the continuous clock, as the extract's `info.artifacts.intervals`) as `[begsample endsample]` rows of the raw structure `data`, on its `sampleinfo`: every sample of the signal a period touches (`EphysDataset.intervalRows`), so a period shorter than one sample of a derived signal still marks one. It is the matrix `ft_rejectartifact` reads from `cfg.artfctdef.<type>.artifact`; `[]` with no periods. `exportFieldTrip` stores it in each signal's `cfg.artfctdef.preprocessing.artifact` |
| `r = FieldTripExport.validate(data \| spike)` | runs `ft_datatype_raw` / `ft_datatype_spike` when FieldTrip is on the path and reports `ok` / `message`; a no-op otherwise |
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

## Tests

[`test_FieldTripExport.m`](../pipeline/test_FieldTripExport.m): `raw`
(`trial{1}` = `Y.LFP.'`, `time{1}(1) == 0`, `sampleinfo == [1 N]`, labels,
`hdr.TimeStampPerSample == origFs/Fs`), `spike` (timestamps equal the sorted
samples, `FirstTimeStamp == 0`, no `time` / `trial`), `event` (`sample` = the
row at the recording rate; with `EventFs` the nearest sample at a derived
rate, row 180001 at 30 kHz → 6001 at 1 kHz; durations, ordering),
`exportFieldTrip`'s per-signal `cfg.event`, `artifact` (the periods as
`[begsample endsample]` at the LFP rate, a period shorter than one sample
included; at the recording rate exactly its own samples; `[]` with none) and
each signal's `cfg.artfctdef.preprocessing.artifact`, the `export` variable names, and
`Validate` as a no-op without FieldTrip (the checks run `ft_datatype_raw` /
`ft_datatype_spike` when a FieldTrip checkout is on the path).
