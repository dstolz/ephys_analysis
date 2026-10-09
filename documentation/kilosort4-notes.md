# Kilosort4 notes

Notes on Kilosort4 parameters that its documentation does not settle, worked
out from the installed source and checked against our probes.

> Written 2026-10-01 from Kilosort **4.1.7** (the `kilosort` conda
> environment, see
> [Installation](../pipeline/INSTALL.md#4-miniconda-and-the-kilosort-environment)).
> Re-check these notes after upgrading Kilosort4: the code is authoritative.

## `whitening_range`

Kilosort4's own description is only "Number of nearby channels used to
estimate the whitening matrix". It gives no rule for choosing it. The default
is 32 ([`kilosortParamSpec`](../pipeline/@EphysPipelineConfig/kilosortParamSpec.m)
uses the same default).

### What Kilosort4 does with it

In `kilosort/preprocessing.py` (`get_whitening_matrix`, `whitening_local`):

1. It builds one channel × channel covariance matrix from the data after the
   common-average reference (when `do_CAR` is on) and the high-pass filter,
   from every `nskip`-th batch.
2. For each channel *j*, it takes the `whitening_range` channels nearest to *j*
   by straight-line distance on the probe's `xc` / `yc` (channel *j*
   included). It whitens that sub-matrix (ZCA) and keeps only channel *j*'s
   row.
3. **`kcoords` is not used.** "Nearest" means nearest in µm, so a
   neighborhood can reach onto other shanks. A value at or above the channel
   count means every channel is used.

### Choosing a value

| Value | Effect |
| --- | --- |
| Too small | Noise shared across many channels is not removed, and the whitening can start to flatten a spike's spread across its neighboring channels. |
| Too large | Each channel is whitened using distant channels that share little of its noise. On a multi-shank probe, the shanks get mixed together. |

Rule of thumb:

- Use about as many channels as one spike's footprint plus the local noise
  correlations cover. On a dense single-shank probe (Neuropixels-like), the
  default of 32 is reasonable.
- On a multi-shank probe, use no more than the number of sites on one shank.
  Then check which channels each neighborhood actually takes (see below):
  sites parked far up a shank can make the nearest sites lie on the next shank.
- Check by eye: compare the whitened traces in the Kilosort4 GUI, and the
  sorting results, at two or three values (for example 8, 16 and 32).

### Example: H64LP 4×16

[`H64LP_4x16lin_probemap.json`](../pipeline/probes/H64LP_4x16lin_probemap.json)
(NeuroNexus A4x16-Poly2): 4 shanks 150 µm apart, each with 14 sites on 10 µm
rows and 2 parked sites 100–500 µm further up. The number of shanks each
channel's whitening neighborhood spans:

| `whitening_range` | shanks per neighborhood (min – max) |
| --- | --- |
| 8 – 12 | 1 – 4 |
| 16 – 32 | 2 – 4 |

- From 16 up, every neighborhood already reaches the next shank, because that
  shank's sites are closer than the parked sites. This includes the 32 in
  [`H64LP_4x16.json`](../pipeline/pipeline_configs/H64LP_4x16.json).
- Even at 8, the parked sites' neighborhoods cross shanks, because those
  sites have no close neighbors.

For this probe, **8 – 12** is the more defensible range. Kilosort4 decides
neighbors by distance alone, so the only way to whiten each shank strictly on
its own channels is to move the shanks further apart. Use
[`shank_spacing`](#shank_spacing) for that: it moves them apart for the sort
only and leaves the probe map as it is.

To check a probe map `pf` (shanks are its `kcoords` groups):

```matlab
p = jsondecode(fileread(pf));
x = p.xc(:); y = p.yc(:); k = p.kcoords(:);
for n = [8 12 16 24 32]
    nShanks = zeros(numel(x), 1);
    for j = 1:numel(x)
        [~, order] = sort((x(j) - x).^2 + (y(j) - y).^2);
        nShanks(j) = numel(unique(k(order(1:min(n, end)))));
    end
    fprintf('%2d: shanks per neighborhood %d-%d\n', n, min(nShanks), max(nShanks));
end
```

### Setting it

- **Per config:** `Sorting.KS4.whitening_range` (the
  [Sorting tab](EphysPipelineApp.md#sorting)'s Preprocessing group).
- **Per probe:** add `"whitening_range"` to the probe's
  [`<probe>.ks4.json`](file-formats.md#kilosort4-probe-parameters-probeks4json).
  **Optimize for probe** then loads it like the other parameters. It is not
  one of the `KS4ProbeParams` that `ks4ProbeDefaults` derives from the layout
  ([Optimize for probe](EphysPipelineApp.md#optimize-for-probe)).

## `shank_spacing`

`shank_spacing` is the pipeline's own setting, not a Kilosort4 one. It puts
extra distance between neighboring shanks, in µm, for the sort only. The
default 0 sorts the probe as it is.

### What it does

[`runKilosort`](EphysDataset.md#shank-spacing) writes a copy of the probe,
`<probe>_spaced.json`, into the run folder, and Kilosort4 sorts with that copy:

- The shanks are the `kcoords` groups, taken in order of their mean `xc`. The
  *k*-th shank (counting from 0) moves *k* × `shank_spacing` µm along x. Each
  pair of neighboring shanks gains `shank_spacing` µm, and each shank keeps
  its own layout.
- The probe map is not changed. A one-shank probe is sorted as it is.
- When Kilosort4 finishes, `run_ks4.py` writes the true positions back into
  `channel_positions.npy` and `spike_positions.npy`. phy, the Review tab and
  `readPhyUnits` then see the real layout.
- What still shows the spaced layout: `ops.npy` (Kilosort4's record of the
  run) and the `spike_positions.png` plot Kilosort4 draws during the run.

Every Kilosort4 step that measures distances between channels then stays on
one shank:

| Step | How x-distance comes in |
| --- | --- |
| Whitening | the `whitening_range` nearest channels (above) |
| Drift correction | interpolation kernel over all sites (`sig_interp`) |
| Template matching | the nearest channels to each template center (`nearest_chans`), within `max_channel_distance` |
| Clustering | spikes grouped around `x_centers` (k-means on the sites' x) |
| Spike positions | weighted mean over a template's nearest channels |

Template centers are placed per `kcoords` shank already, so the spacing does
not change how many there are.

### Choosing a value

The aim: for every site, the nearest site on another shank lies farther away
than the farthest site on its own shank. Then a neighborhood of up to one
shank's worth of sites stays on its shank, whatever `whitening_range` is. A
value that does this is about the farthest distance within one shank (parked
sites included) minus the current distance between the nearest sites of two
shanks. Each run logs both numbers after the spacing:

```text
Shanks 500 um further apart for sorting: nearest sites on different shanks 133.1 -> 632.8 um (farthest sites on one shank 630.1 um).
```

For the [H64LP 4×16](#example-h64lp-416), the farthest sites on one shank
are 630 µm apart (the parked sites) and the nearest sites of two shanks are
133 µm apart, so it needs about 500 µm. The number of shanks each channel's
whitening neighborhood spans (computed as in the check above, on the spaced
`xc`):

| `shank_spacing` | `whitening_range` 8 | 16 | 32 |
| --- | --- | --- | --- |
| 0 | 1 – 4 | 2 – 4 | 2 – 4 |
| 300 | 1 – 2 | 1 – 3 | 2 – 3 |
| 400 | 1 | 1 – 2 | 2 – 3 |
| 500 | 1 | 1 | 2 – 3 |

With 16 sites per shank, a `whitening_range` of 32 always takes in a second
shank. So use `shank_spacing` together with a `whitening_range` of at most the
sites on one shank.

A larger value than needed should do no harm: in the 4.1.7 source, no step
depends on the total width of the probe. Keep `x_centers` at least the number of
shanks: clustering groups templates around `x_centers` positions found by
k-means on the sites' x, and with the shanks far apart those positions fall
on the shanks.

### Setting it

- **Per config:** `Sorting.KS4.shank_spacing` (the
  [Sorting tab](EphysPipelineApp.md#sorting)'s Preprocessing group, next to
  `whitening_range`).
- **Per probe:** add `"shank_spacing"` to the probe's
  [`<probe>.ks4.json`](file-formats.md#kilosort4-probe-parameters-probeks4json).
  **Optimize for probe** loads it with the other parameters.
