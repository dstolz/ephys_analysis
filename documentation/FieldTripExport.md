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
| `data = FieldTripExport.raw(S, "LFP", Class="double")` | a raw structure with **one trial spanning the signal**: `label` (`nChan x 1` cellstr), `time{1}` = `(k-1)/Fs`, `trial{1}` = `[nChan x N]` (the transpose of the pipeline's `[N x nChan]`), `fsample`, `sampleinfo = [1 N]`, `hdr` (`Fs`, `nChans`, `nSamples`, `nSamplesPre = 0`, `nTrials = 1`, `label`, `chantype`, `chanunit = {'uV'}`, `FirstTimeStamp = 0`, `TimeStampPerSample = origFs/Fs`), `cfg` (with `cfg.event` at this signal's rate) |
| `spike = FieldTripExport.spike(units)` | a spike structure: `label` (`1 x nUnits`, `unit<id>`), `timestamp{u}` = 0-based recording samples (Kilosort's `spike_times`), `hdr` (`Fs = units.fs`, `FirstTimeStamp = 0`, `TimeStampPerSample = 1`), `cfg`. No `time` / `trial` fields: cut trials in FieldTrip with `ft_spike_maketrials` |
| `spike = FieldTripExport.spikeFromDetected(detected)` | the same, one "unit" per detected channel |
| `event = FieldTripExport.event(events, Fs)` | struct array, one element per digital-input pulse: `type` (line name), `sample = round(t_on*Fs)` (1-based, the sample that produced the onset with `t = row/Fs`), `value = 1`, `offset = 0`, `duration` (pulse length in samples, inclusive), sorted by sample |
| `r = FieldTripExport.validate(data | spike)` | runs `ft_datatype_raw` / `ft_datatype_spike` when FieldTrip is on the path and reports `ok` / `message`; a no-op otherwise |
| `FieldTripExport.hasFieldTrip()` | is FieldTrip on the path? |

Raw and spike structures share the recording's sample clock through
`hdr.TimeStampPerSample`, so a spike at sample `k` of a 30 kHz sort lines up
with sample `k/30` of a 1 kHz LFP trial. Kilosort index `k` ↔ `t = k/fs`
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
| `Extract` | `<outputFolder>/<Name>_extract.mat`, else the `<Name>_extract_<TYPE>.mat` files present | other extract file(s) (several are merged), or a `toMat`-shaped struct |
| `Signals` | all present | subset of `["LFP" "MUA" "SPIKE"]` |
| `Units` | the associated sorted units | a units struct, or `false` |
| `Groups` | `["good" "mua"]` | phy labels kept when reading the units |
| `Detected` | `<Name>_spikes.mat` when present | a spikes file, a `detected` struct, or `false` |
| `Events` | `true` | write `event` and each signal's `cfg.event` |
| `Validate` | `true` | validate with FieldTrip when it is on the path; the outcome is recorded in `export.validation` |
| `Overwrite`, `MatVersion` | `false`, `"-v7.3"` | |

Variables in the file: `data_LFP` / `data_MUA` / `data_SPIKE`, `spike`,
`spikeDetected`, `event` and `export` (provenance: `tool`,
`created`, `dataset`, `sources`, `signals`, `eventFs`, `validation`). Absent
inputs are stored as `[]`. The file is written atomically
(`EphysDataset.saveAtomically`). Schema summary in
[file-formats.md](file-formats.md#fieldtrip-export).

Loading it in FieldTrip:

```matlab
F = load("subj1_fieldtrip.mat");
cfg = [];  cfg.event = F.data_LFP.cfg.event;         % events at the LFP rate
cfg.trialdef.eventtype = 'din0'; cfg.trialdef.prestim = 0.5; cfg.trialdef.poststim = 1.5;
cfg.trialfun = 'ft_trialfun_general';
cfg = ft_definetrial(cfg);
trials = ft_redefinetrial(cfg, F.data_LFP);
spk = ft_spike_maketrials(struct('trl', cfg.trl, 'timestampspersecond', F.spike.hdr.Fs), F.spike);
```

## Tests

[`test_FieldTripExport.m`](../pipeline/test_FieldTripExport.m): `raw`
(`trial{1}` = `Y.LFP.'`, `time{1}(1) == 0`, `sampleinfo == [1 N]`, labels,
`hdr.TimeStampPerSample == origFs/Fs`), `spike` (timestamps equal the sorted
samples, `FirstTimeStamp == 0`, no `time` / `trial`), `event` (`sample ==
round(t_on*Fs)`, durations, ordering), the `export` variable names, and
`Validate` as a no-op without FieldTrip (the checks run `ft_datatype_raw` /
`ft_datatype_spike` when a FieldTrip checkout is on the path).
