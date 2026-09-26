# Hardware bank

This folder holds the hardware definitions the channel mapper
([`ChannelMapperApp`](../../documentation/ChannelMapperApp.md)) composes into a
probe → package → headstage → recording-row chain. There is one JSON file per
entry, read by [`HardwareBank`](../HardwareBank.m) and resolved by
[`ChannelMap`](../ChannelMap.m).

```
connectors/<name>.json                   connector families: grid, guide posts, one-way or not
headstages/<manufacturer>/<name>.json    headstage faces: 0-based hardware channels
packages/<manufacturer>/<name>.json      probe package faces: probe site numbers
probes/<manufacturer>/<name>.json        probe designs: site geometry
mappings/<name>.json                     saved chains (ChannelMapperApp: Save mapping)
adaptors/<manufacturer>/<name>.json      reserved: adaptors are not supported yet
```

Every file carries `"schema": "ephys-hardware/1"`, its `kind` (which must
match its folder), `manufacturer`, `name`, `channels`, `notes` and `source`
(where the data came from). The id of an entry is `<manufacturer>/<name>`
(`neuronexus/H32`); a connector's or a mapping's id is its name.
`HardwareBank().Entries` lists them all with their problems. Every shipped
entry must have none; `test_ChannelMapper` checks that.

## Connector faces

A **face** is a connector seen looking into its mating face, drawn exactly as
the vendor draws it. It is stored as one line of text per connector row, top
row first, cells separated by spaces:

| Cell | Meaning | Where |
| --- | --- | --- |
| `12` | a probe site number (package), or a 0-based hardware channel, `in12` (headstage) | package, headstage |
| `GND` | ground (vendor `G`) | all |
| `REF`, `REF1`..`REF4` | reference (vendor `R`, `R1`..`R4`) | all |
| `PR` | probe-reference pin (NeuroNexus adaptors) | adaptor |
| `NC` | a pin that is not connected (vendor blank or `x`) | all |
| `GUIDE` | a guide post, no pin | all |

The whole drawing is stored, guide posts included. An Omnetics 36-pin face is
2 × 20 (18 pins and a guide post at each end of each row). An Omnetics 18-pin
face is 2 × 10: the top row is a guide post, 8 pins and a guide post; the
bottom row is 10 pins. Keeping every list a list of strings avoids the shapes
`jsondecode` changes.

**Mating.** A male face (package) and a female face (headstage) of one
connector have the same R rows × N columns.

- **reference**: male (r, c) touches female (r, N+1−c), a column mirror.
- **rotated**: male (r, c) touches female (R+1−r, c), a turn of 180 degrees.

Omnetics 36-pin (four symmetric guide posts) mates both ways. GND and REF sit
so that both ways are electrically safe, but the channel map differs. Omnetics
18-pin (guide posts on one row) mates one way; a rotated mate is reported as
a problem. Two-connector devices (H64LP, RHD2164) pair top with top and bottom
with bottom in the reference orientation, and top with bottom when rotated.

## Schemas

**connector**

```json
{"schema": "ephys-hardware/1", "kind": "connector", "manufacturer": "omnetics",
 "name": "omnetics-nano-36", "channels": 36, "family": "omnetics-nano-36",
 "rows": 2, "cols": 20, "guides": [[1, 1], [1, 20], [2, 1], [2, 20]],
 "oneWay": false, "pitchMm": 0.635, "notes": "", "source": ""}
```

`channels` is the pin count. `guides` lists the `[row, column]` cells of the
guide posts; every face on this connector must have its `GUIDE` cells there.

**headstage**

```json
{"schema": "ephys-hardware/1", "kind": "headstage", "manufacturer": "intan",
 "name": "RHD2132-32ch", "model": "RHD2132 32-channel headstage (C3314 / C3324)",
 "channels": 32, "channelLabel": "in%d", "hardwareChannels": [0, 31],
 "view": "looking into the electrode connector, chip side of the PCB up",
 "faces": [{"id": "main", "connector": "omnetics-nano-36", "gender": "female",
            "rows": ["GUIDE GND 23 22 21 20 19 18 17 16 15 14 13 12 11 10 9 8 REF GUIDE",
                     "GUIDE REF 24 25 26 27 28 29 30 31 0 1 2 3 4 5 6 7 GND GUIDE"]}],
 "source": "https://intantech.com/RHD_headstages.html", "notes": ""}
```

The numbers on the faces are distinct, there are `channels` of them, and
they lie within `hardwareChannels` (first and last).

**package**: the same shape, with `"gender": "male"`, site numbers in the
cells (exactly `1..channels`) and `"view": "looking into the pins, side
printed NEURONEXUS up"`. A two-connector package has faces `top` and
`bottom`. `verifiedHeadstages` lists the headstages this package has been
checked with (against a recording or probeinterface). A reference chain to
one of them is labelled *verified*; every other reference chain is
*rule-derived*.

**probe** (a probe design's geometry)

```json
{"schema": "ephys-hardware/1", "kind": "probe", "manufacturer": "neuronexus",
 "name": "A1x32-6mm-50-177", "channels": 32, "shanks": 1,
 "sites": [1, 2, ...], "x": [...], "y": [...], "shank": [1, 1, ...],
 "defaultPackage": "neuronexus/H32", "template": "A1x32", "pitchUm": 50,
 "geometrySource": "template", "notes": "", "source": ""}
```

Site numbers are the vendor's (1-based, as on the package map). Positions
are in µm, with y growing away from the tip, the convention the Kilosort4
probe maps in `pipeline/probes` use. Shanks are numbered from 1.
`geometrySource` is `template`, `ks4-json`, `probeinterface`, `csv` or
`editor`.

**mapping** (a saved chain)

```json
{"schema": "ephys-hardware/1", "kind": "mapping", "manufacturer": "",
 "name": "H32_A1x32_RHD2132", "channels": 32,
 "probe": "neuronexus/A1x32-6mm-50-177", "package": "neuronexus/H32", "adaptors": [],
 "headstages": [{"id": "intan/RHD2132-32ch", "channelOffset": 0}],
 "mates": [{"from": "package:main", "to": "headstage[1]:main", "orientation": "reference"}],
 "rows": {"mode": "in-order", "channelNumbers": [], "dataset": ""},
 "result": {"site": [...], "hardwareChannel": [...], "recordingRow0": [...]},
 "problems": [], "trust": "verified", "notes": "", "source": "ChannelMapperApp"}
```

`rows.mode` is `in-order`, `dataset` or `custom`. `channelNumbers` holds the
0-based hardware channels in recording order for the last two. `result` is
what the chain gave when it was saved.

## What is here

| Kind | Entries |
| --- | --- |
| connectors | `omnetics-nano-36`, `omnetics-nano-18` |
| headstages | Intan `RHD2132-32ch`, `RHD2132-16ch` (inputs 8..23), `RHD2164-64ch` (two connectors) |
| packages | NeuroNexus `H32`, `CM32`, `H16`, `H64LP` (two connectors) |
| probes | NeuroNexus `A4x16-Poly2-5mm-20s-lin-160` (the geometry of `pipeline/probes/H64LP_4x16lin_probemap.json`) and template designs `A1x16-5mm-50-177`, `A1x32-6mm-50-177`, `A1x32-6mm-100-177`, `A1x32-Edge-5mm-20-177`, `A1x32-Poly3-10mm-50-177`, `A2x16-10mm-100-500-177`, `A4x8-5mm-50-200-177`, `A4x16-5mm-50-200-177`; generic `linear16`, `linear32`, `linear64` (50 µm) |
| mappings | `H32_A1x32_RHD2132` |

The faces are transcribed from the Intan RHD headstage pinouts and the
NeuroNexus package maps named in each file's `source`. Two chains are checked
(`test_ChannelMapper`):

- H32 + RHD2132 in the reference orientation reproduces probeinterface's
  `H32>RHD2132` wiring.
- H64LP + RHD2164 in the reference orientation reproduces
  `pipeline/probes/H64LP_4x16lin_probemap.json`.

The template designs follow the site-order templates of the package maps
(`ChannelMap.templates`). `A4x8-5mm-50-200-177` and `A1x32-Poly3-10mm-50-177`
match probeinterface. Check the others against the design's own map before
relying on depths.

## Adding hardware

Use the channel mapper's editor (**Bank → New headstage / New package / New
probe design**, or **Edit or copy the selected ...**).

- **Faces**: paste the vendor's rows, one per line, top row first, looking
  into the face as the vendor draws it. Guide posts may be left out.
- **Probe designs**: generate the sites from a template, or import them from
  probeinterface, a Kilosort4 probe `.json` or a CSV.
- The editor checks the entry as you type and refuses to save it with
  problems.

A file written by hand works too. Put it in the right folder, then
**Reload** the bank, or run `HardwareBank().Entries` to see its problems.

Not transcribed yet: the other NeuroNexus packages (HC32, HZ32, Z32, V32,
CM16LP, A16, A64, H64, Buzsaki64 packages ...), the NeuroNexus adaptors, the
Intan RHD2216 and 128-channel headstages, and Open Ephys and TDT headstages.
For TDT, the hardware channel is the stream channel index minus one.
