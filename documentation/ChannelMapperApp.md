# ChannelMapperApp

`ChannelMapperApp` ([source](../pipeline/@ChannelMapperApp/ChannelMapperApp.m)) is a
`handle` class that opens a window for **working out which recording row each
probe site ends up on**. A probe's sites reach the amplifier through a chain
of parts, and each vendor documents only its own link, as a drawing:

- the probe's **package** (NeuroNexus H32, CM32, H16, H64LP ...) routes site
  numbers to connector pins;
- the **headstage** (Intan RHD2132, RHD2164 ...) routes its connector pins to
  amplifier inputs `in0..inN`;
- the acquisition software stores the hardware channels as recording rows.

The mapper composes that chain from a bank of hardware definitions stored in
the repository ([`pipeline/hardware`](../pipeline/hardware/README.md)). It
shows each site's path as a table you can copy and as pictures of the probe
and the mated connectors. It writes the Kilosort4 probe `.json` the pipeline
needs (schema in [file-formats.md](file-formats.md#kilosort4-probe-json)),
with a [`.chanmap.json` sidecar](file-formats.md#channel-map-sidecar-probechanmapjson)
that records the chain.

The logic lives in two GUI-free classes the window sits on:
[`ChannelMap`](../pipeline/ChannelMap.m) (parse, mate, resolve, text, export)
and [`HardwareBank`](../pipeline/HardwareBank.m) (read, check and save the
bank).

## Opening it

From the GUI: **Probe tab → Map channels...**, or **File → Channel mapper...**
([`EphysPreprocessingApp.onOpenChannelMapper`](../pipeline/@EphysPreprocessingApp/onOpenChannelMapper.m)).
It also runs on its own:

```matlab
ChannelMapperApp()                           % standalone
m = ChannelMapperApp(app, Dataset=d);        % from an EphysPreprocessingApp
ChannelMapperApp(Mapping="H32_A1x32_RHD2132") % open a saved mapping
```

| Argument | Meaning |
| --- | --- |
| `app` | the parent `EphysPreprocessingApp`, or `[]`. The mapper uses its probe folder (the export starts there, and the probe list refreshes after an export), its project's datasets (recording rows) and its `runProbeTool` (probeinterface). Nothing is written into the config |
| `BankFolder` | the hardware bank. Default: the last one used, else `pipeline/hardware` |
| `Dataset` | an `EphysDataset`. Its `ChannelNumbers` become the recording rows |
| `Mapping` | a saved mapping's name, or a mapping or `.chanmap.json` file to open |

The window is not modal: several can be open, next to the preprocessing app.
With no mapping given it reopens the chain it showed when it last closed.

## Workflow

1. **Probe**: filter by manufacturer and channel count, then choose a **probe
   design** (the site geometry) and a **package**. A design brings its default
   package. A package with another channel count brings a design made for it,
   or none. *(none)* maps the wiring without geometry; the table still fills
   in, but the export needs a design.
2. **Headstage**: choose the headstage and **how many** of it. Two RHD2132 on
   an H64LP is two headstages; an RHD2164 is one with two connectors. A
   package whose channel count the headstage does not match brings the
   headstage it was verified with, or one with its channel count.
3. **Mates**: one row per package connector. It shows which headstage
   connector the package connector plugs into, the **orientation** and the
   headstage's **channel offset**.
   - **Reference** means both printed sides up, as the vendors draw them.
     **Rotated** means one of them is turned 180 degrees.
   - Omnetics 36-pin connectors fit both ways; the 18-pin ones fit only one
     way, and a rotated mate is reported as a problem.
   - Turning a two-connector package on one headstage re-pairs both
     connectors: rotated puts top on bottom.
   - A second headstage counts on from the first (offset 32 for a second
     32-channel headstage), as the recording software numbers a second port.
4. **Recording rows**: how hardware channels become `.bin` rows.
   - **Headstage channels in order** (the default) ranks every headstage
     channel ascending. The 16-channel RHD2132 wires `in8..in23`, which become
     rows 0..15.
   - **From a dataset** takes a dataset's `ChannelNumbers`: the project's
     datasets when opened from the app, a recording folder when standalone. A
     channel the dataset did not record is flagged *not recorded*, and later
     rows shift.
   - **Custom channel list** takes 0-based hardware numbers in recording
     order, such as `0-31, 32-63`.
5. **Read the result**.
   - The **table** gives each site's row: 0-based for `chanMap`, 1-based as
     the Probe tab and *Exclude channels* use it. It also gives the hardware
     channel, the headstage input, both pins, the shank and x, y. Grey rows
     do not reach a recorded channel.
   - The **pictures** show the probe's sites and each package connector over
     the headstage connector it mates with. Both are drawn looking into the
     face, and the headstage face is mirrored so that pins that touch share a
     column. Flipping the orientation visibly flips it.
   - **Click** a site, a pin or a table row: the site's two pins turn amber,
     its row is selected and the path reads, for example,
     `Site 18 → H32 top:2 → RHD2132-32ch top:17 → in8 → hardware 8 → row 9 (1-based) / 8 (0-based)`.
     A GND or REF pin shows the pin it meets.
   - The line under the path lists the chain's **problems**: GND meeting a
     signal, a site on a reference, a site not mated, two sites on one
     channel, a rotated one-way connector. It is green when there are none.
   - **Label sites by** and **Sort** change the picture and the table order.
     The copied text follows the table order.
6. **Copy table** (tab-separated, pastes into Excel), **Copy CSV**, **Copy
   MATLAB** (`site` and `chanMap` vectors) or **Copy path**. *File → Export CSV...*
   writes a file.
7. **Save mapping...** stores the chain in the bank's `mappings/` folder.
   **Load mapping...** reopens a saved mapping, or the chain recorded in an
   exported probe's `.chanmap.json`.
8. **Export Kilosort4 probe .json...** writes the probe map. It starts in the
   parent's probe folder (`pipeline/probes` standalone). With problems it asks
   first, and sites that reach no recorded channel are left out and named in
   the notes. The new probe appears in the Probe tab.

The **trust** label in panel 1 says how far the result can be believed:

| Trust | When |
| --- | --- |
| verified | one headstage the package lists under `verifiedHeadstages`, every mate reference and face to face (H32 + RHD2132 reproduces probeinterface's `H32>RHD2132`; H64LP + RHD2164 reproduces `pipeline/probes/H64LP_4x16lin_probemap.json`) |
| rule-derived | every mate in the reference orientation, from the vendors' drawings |
| unverified | a rotated mate: check it against a recording |

## The bank

The hardware lives in [`pipeline/hardware`](../pipeline/hardware/README.md) as
one JSON file per entry: connectors, headstages, packages, probe designs and
saved mappings. The README there gives the schemas and how to add hardware.
A connector face is written the way the vendor draws it, one row of text per
connector row (`"GUIDE REF1 18 27 ... GND GUIDE"`).

The **Bank** menu (or **New entry...**) opens the entry editor:

- **Headstage / package**: the name, manufacturer, channel count, model,
  source and notes. For each face (connector) you set its id and connector,
  then **paste the vendor's rows**, one per line, top row first, looking into
  the face.
  - Numbers are site numbers (package) or 0-based inputs (headstage;
    `in12` = 12). `G` / `GND`, `R` / `REF` / `R1..R4`, `x` / `NC` and
    `o` / `GUIDE` are understood, and the guide posts may be left out.
  - The parsed grid is editable, and a preview shows the face.
  - A headstage also has its channel label (`in%d`) and hardware range.
- **Probe design**: the sites table (site, x, y, shank). Fill it from a
  generator (linear, multi-column, tetrode, or a NeuroNexus site-order
  template such as `A1x32` or a full design name such as
  `A4x8-5mm-50-200-177`) or an import.
  - The **probeinterface** import numbers the sites by the probe's contact
    ids, and needs the sorting Python.
  - The **Kilosort4 .json** import numbers the sites by their order in the
    file, and the notes say so.
  - The **CSV** import reads `site,x,y,shank`.
- The checks run on every change. **Save to bank** is refused while there are
  problems, and asks before replacing an entry. Saving under another name adds
  a copy (*Bank → Edit or copy the selected ...*).

## Mating convention

A face is a connector seen looking into its mating face, drawn as the vendor
draws it. A male face (package) and a female face (headstage) of one
connector have the same R rows × N columns.

- **reference**: male cell (r, c) touches female (r, N+1−c), a column mirror.
- **rotated**: male (r, c) touches female (R+1−r, c), a turn of 180 degrees.

Two-connector devices pair top with top and bottom with bottom in the
reference orientation, and top with bottom when rotated.

The hardware channel is the headstage cell plus the headstage's channel
offset. It is 0-based, as `EphysReader.ChannelNumbers` (`"A-012"` → 12). The
recording row is the channel's place in the dataset's `ChannelNumbers`, or
its rank among the headstages' channels.

## What is written

- `<probe>.json`: the Kilosort4 probe map, through `writeProbeMap`:
  - `chanMap`: each site's 0-based recording row
  - `xc`, `yc`: the design's site positions
  - `kcoords`: the shank, numbered from 1 as NeuroNexus does
  - `n_chan`: the larger of the sites and the recorded channels
  - `notes`: the chain, its trust, and the sites left out
- `<probe>.chanmap.json`: the chain, its per-site result and its trust
  ([format](file-formats.md#channel-map-sidecar-probechanmapjson)). The Probe
  tab does not list it as a probe, and *Import probe .json into folder...*
  copies it along.
- `pipeline/hardware/mappings/<name>.json` (**Save mapping**) and bank entries
  (**Save to bank**) ([format](file-formats.md#hardware-bank-pipelinehardware)).
- Preferences (group `ChannelMapperApp`): the window position, the bank folder
  and the last chain.

## Requirements

- MATLAB only. Python is needed just for the editor's probeinterface import:
  the Python set on the preprocessing app's Kilosort tab, whose `kilosort` env
  from [INSTALL.md](../pipeline/INSTALL.md) has probeinterface.
- Adaptors (NeuroNexus Adpt-A32-OM32 and the like, between a Samtec package
  and an Omnetics headstage) are not supported yet. The schema keeps a place
  for them.

Tests: `test_ChannelMapper` (in `pipeline/`).
