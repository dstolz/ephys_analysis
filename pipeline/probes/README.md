# Kilosort4 probe maps

This folder stores Kilosort4 probe map `.json` files used by `EphysPreprocessingApp`
and `EphysDataset.runKilosort`. The app scans this folder (by default) to populate
its probe list, but you can point it at any folder.

## Format

Kilosort4 probe `.json` files have the shape produced by
`kilosort.io.save_probe` / accepted by `kilosort.io.load_probe`:

```json
{
  "chanMap": [0, 1, 2, 3, ...],
  "xc":      [0.0, 0.0, 0.0, ...],
  "yc":      [0.0, 20.0, 40.0, ...],
  "kcoords": [0, 0, 0, ...],
  "n_chan":  32
}
```

- `chanMap` — 0-based channel indices into the `.bin` (length = number of
  recorded/used channels), integers.
- `xc`, `yc` — electrode x/y coordinates in microns (same length as `chanMap`).
- `kcoords` — shank/group index per channel, **required**: Kilosort4 places
  its templates per shank and has no default for the field (a probe without
  it stops with a `KeyError`). All zeros on a single-shank probe.
- `n_chan` — total channel count, a positive integer, required. Because a
  `chanMap` can never have more sites than the total channel count, an
  `n_chan` that is smaller than `numel(chanMap)` is treated as invalid (e.g.
  accidentally written from a 0-based map's *max index*, which is one short
  of the count) and the map length is used instead.
- `notes` — optional text.
- Nothing else in the file may be a list: Kilosort4 reads every JSON array
  as one value per site and then requires equal lengths, so a list of site
  names, say, stops the probe loading. Other text, numbers and nested objects
  are ignored.
- Each site array is a JSON list even for a single site (`"chanMap": [0]`).
  MATLAB's `jsonencode` writes a one-element array as a bare number, which
  Kilosort4 rejects, so write probe maps with `writeProbeMap`, never
  `jsonencode` / `writeJsonFile` directly.

`probeMapProblems(file)` lists what would stop Kilosort4 reading a probe
(nothing when it reads it). `EphysDataset.runKilosort` refuses such a probe
before writing the `.bin` (`EphysDataset:runKilosort:BadProbe`), and the Probe
tab shows the reasons in red when the probe is selected.

## Channel-count checking

The app does a *simple* check: it compares the probe's channel count
(`n_chan`, never fewer than `numel(chanMap)`) against the selected dataset's
amplifier channel count (`EphysDataset.NumChannels`). A mismatch is flagged
but never blocks you — `EphysDataset.runKilosort` warns the same way
(`checkProbeChannels`) and Kilosort4 stops only when a `chanMap` value
reaches `n_chan_bin`.

Drop your probe `.json` files in this folder to have them appear automatically.

## Kilosort4 parameter files (`<probe>.ks4.json`)

Each probe map can keep its Kilosort4 parameters next to it, in
`<probe>.ks4.json` (e.g. `H64LP_4x16lin_probemap.ks4.json`). The Sorting tab's
**Optimize for probe** loads that file into the Kilosort4 parameters. When a
probe has no such file, the app alerts you and offers to generate one from the
current parameters or from the probe layout (the good defaults described
below, which are then loaded). These files are not listed as probes.

The files here hold good defaults for the probe-dependent parameters
(`nblocks`, `dmin`, `dminx`, `nearest_chans`, `nearest_templates`,
`min_template_size`, `x_centers`). `EphysPipelineConfig.ks4ProbeDefaults`
derived them from each layout, following Kilosort4's
[parameter guide](https://kilosort.readthedocs.io/en/latest/parameters.html);
`reasons` in each file says why. Edit a file to tune a probe. It may list any
other Kilosort4 parameter too. The format is in
[file-formats.md](../../documentation/file-formats.md#kilosort4-probe-parameters-probeks4json).
To generate good defaults for a new probe map `pf`:

```matlab
[v, r] = EphysPipelineConfig.ks4ProbeDefaults(pf);
EphysPipelineConfig.writeKS4Params(pf, v, Description=r.Summary, Reasons=r.Reasons);
```

## Creating probes with the designer

Instead of hand-writing the JSON above, use **Probe tab → "Design probe from
probeinterface (library / generate)..."**. The designer (`ProbeDesignerApp`) can:

- **Library** — fetch a manufactured probe from the
  [probeinterface library](https://github.com/SpikeInterface/probeinterface_library)
  (NeuroNexus, Cambridge Neurotech, IMEC, Plexon, …).
- **Generate** — build a standard geometry (linear / multi-column / tetrode).
- **Wire** — map each contact to an Intan amplifier channel (the `chanMap`),
  with Identity / Reverse / load-from-file presets.

It shells out to `@EphysPreprocessingApp/probe_tool.py` in the configured sorting
conda env (probeinterface is already installed there; the library needs internet
on first fetch, then caches) and **writes a plain Kilosort4 `.json` in the schema
above** into this folder — so everything downstream is unchanged. Editing the
wiring/name/notes and saving is done MATLAB-side; probeinterface is only the
front door.

## Where the wiring comes from (the channel mapper)

A probe map's `chanMap` is the 0-based `.bin` row of each site, and working it
out by hand is error-prone. The site goes through the probe's package
(NeuroNexus H32, H64LP ...), the Omnetics connector (which fits two ways),
the headstage's inputs (Intan `in0..in31`) and the order the recording stores
the channels in. **Probe tab → Map channels...** (`ChannelMapperApp`)
composes that chain from the hardware bank in
[`pipeline/hardware`](../hardware/README.md). It shows each site's path, and
**Export Kilosort4 probe .json...** writes the probe map into this folder
with a `<probe>.chanmap.json` sidecar that records the chain it came from
(format in
[file-formats.md](../../documentation/file-formats.md#channel-map-sidecar-probechanmapjson)).
Sidecars are not listed as probes, and **Import probe .json into folder...**
copies them along.

`H64LP_4x16lin_probemap.json` is what the mapper gives for a NeuroNexus
A4x16-Poly2-5mm-20s-lin-160 on an H64LP package, plugged into an Intan
RHD2164 in the reference orientation; `test_ChannelMapper` checks this. See
[ChannelMapperApp](../../documentation/ChannelMapperApp.md).
