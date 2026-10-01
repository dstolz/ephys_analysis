# Kilosort4 notes

Notes on Kilosort4 parameters that its documentation does not settle, worked
out from the installed source and checked against our probes.

> Written 2026-10-01 from Kilosort **4.1.7** (the `kilosort` conda
> environment, see [INSTALL.md](../pipeline/INSTALL.md)). Re-check these notes
> after upgrading Kilosort4: the code is authoritative.

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
   neighbourhood can reach onto other shanks. A value at or above the channel
   count means every channel is used.

### Choosing a value

| Value | Effect |
| --- | --- |
| Too small | Noise shared across many channels is not removed, and the whitening can start to flatten a spike's spread across its neighbouring channels. |
| Too large | Each channel is whitened using distant channels that share little of its noise. On a multi-shank probe, the shanks get mixed together. |

Rule of thumb:

- Use about as many channels as one spike's footprint plus the local noise
  correlations cover. On a dense single-shank probe (Neuropixels-like), the
  default of 32 is reasonable.
- On a multi-shank probe, use no more than the number of sites on one shank.
  Then check which channels each neighbourhood actually takes (see below):
  sites parked far up a shank can make the nearest sites lie on the next shank.
- Check by eye: compare the whitened traces in the Kilosort4 GUI, and the
  sorting results, at two or three values (for example 8, 16 and 32).

### Example: H64LP 4×16

[`H64LP_4x16lin_probemap.json`](../pipeline/probes/H64LP_4x16lin_probemap.json)
(NeuroNexus A4x16-Poly2): 4 shanks 150 µm apart, each with 14 sites on 10 µm
rows and 2 parked sites 100–500 µm further up. The number of shanks each
channel's whitening neighbourhood spans:

| `whitening_range` | shanks per neighbourhood (min – max) |
| --- | --- |
| 8 – 12 | 1 – 4 |
| 16 – 32 | 2 – 4 |

- From 16 up, every neighbourhood already reaches the next shank, because that
  shank's sites are closer than the parked sites. This includes the 32 in
  [`H64LP_4x16.json`](../pipeline/pipeline_configs/H64LP_4x16.json).
- Even at 8, the parked sites' neighbourhoods cross shanks, because those
  sites have no close neighbours.

For this probe, **8 – 12** is the more defensible range. Kilosort4 decides
neighbours by distance alone, so the only way to whiten each shank strictly on
its own channels is to space the shanks further apart in the probe map's `xc`.
That also changes every other Kilosort4 step that works from channel
distances.

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
    fprintf('%2d: shanks per neighbourhood %d-%d\n', n, min(nShanks), max(nShanks));
end
```

### Setting it

- **Per config:** `Sorting.KS4.whitening_range` (the Sorting tab's
  preprocessing group).
- **Per probe:** add `"whitening_range"` to the probe's
  [`<probe>.ks4.json`](file-formats.md#kilosort4-probe-parameters-probeks4json).
  **Optimize for probe** then loads it like the other parameters. It is not
  one of the `KS4ProbeParams` that `ks4ProbeDefaults` derives from the layout
  ([Optimize for probe](EphysPreprocessingApp.md#optimize-for-probe)).
