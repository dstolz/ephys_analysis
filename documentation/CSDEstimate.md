# Current source density: iCSD and kCSD

Two connectors estimate the current source density (CSD) of a laminar
recording from the data the [dataset browser](DatasetBrowser.md) holds, with
two outside toolboxes:

| Connector | Toolbox | Runs in |
| --- | --- | --- |
| [`icsdEstimate`](../analysis/icsdEstimate.m) | [iCSD](https://github.com/dstolz/iCSD): the CSDplotter methods of Pettersen, Devor, Ulbert, Dale & Einevoll 2006 (*J Neurosci Methods* 154:116) — standard, delta, step and spline inverse CSD | MATLAB (the toolbox on the path) |
| [`kcsdEstimate`](../analysis/kcsdEstimate.m) | [kCSD-python](https://github.com/Neuroinflab/kCSD-python): kernel CSD, Potworowski, Jakuczun, Łęski & Wójcik 2012 (*Neural Comput* 24:541) | a Python with `kcsd`, through `system` ([`kcsd_estimate.py`](../analysis/kcsd_estimate.py)); no `pyenv` |

Both take the same inputs and give the same units, so a script can swap one
for the other: potentials in V, positions in mm below the top channel, CSD in
µA/mm³ (positive = source, negative = sink). The potentials come from two
shared builders that arrange the browser's data along the probe:

| Builder | Input | Gives |
| --- | --- | --- |
| [`epochMatrixCSD`](../analysis/epochMatrixCSD.m) | `B.Result` of a signal with *Keep single trials* | the evoked potential of each group per shank profile, plus every epoch |
| [`sessionDataCSD`](../analysis/sessionDataCSD.m) | `B.Sessions` of a signal (*Load whole sessions*) | the whole signal per shank profile and, with `Window=`, the kept trials cut and averaged per group |

Underneath, [`laminarColumns`](../analysis/laminarColumns.m) turns a channel
table (`R.rows`, `D.channels`, `selectChannels`' META) into the profiles.

The [browser scripts](#the-browser-scripts) below run both estimators on the
browser's results.

## Laminar profiles

A CSD is estimated along a line of contacts. `laminarColumns` finds those
lines on the probe:

- Channels without a position (no probe, or `NaN`) are left out, and a
  column of fewer than `MinChannels` (3) channels is dropped.
- Each shank is one profile when no two of its channels share a depth
  (`Columns="auto"`): a staggered design, like the lab's two-column linear
  arrays, interleaves into one profile with twice the resolution, the small
  x offset ignored. When two columns share depths, each x gives its own
  profile. `"separate"` and `"merged"` force either; `"2d"` keeps a shank's
  layout as `[x depth]` positions for `kcsdEstimate`'s KCSD2D.
- `depth_mm` is each channel's distance below the profile's top channel
  (largest y), ascending, so the top channel is at 0 and depth grows down the
  shank. `h_mm` is the spacing (the median step), `uniform` whether every step
  is within 1 % of it (a bad channel left out breaks it; the step iCSD then
  refuses, the others carry on).

The builders then give, per profile, `pots` `[nChan x nTime x nGroups]` in V
(the result's unit, uV as a rule, scaled), channels top down, the group's
epochs averaged as `R.data` is (`signal.statistic`); `epochs`
`[nChan x nTime x nEpochs]` for single trials; `t`, `fs`, `groupLabels`,
`nEpochs` and a `cfg`. The whole-session builder also keeps `signal`
`[nChan x nSamples]`, the `artifacts` and the `events`, and cuts the kept
trials with `mTRFExport.trials` (a trial off the signal or touching an erased
period is dropped) around `Align` (`TrialOnset` by default, a column of the
trials table on the digital clock), whereas the result's epochs are cut around
the browser's event line, so the two routes agree only when that event is the
trial onset and the result applies no detrend or baseline. A group without
trials gives an all-NaN page of `pots`; both estimators leave such pages NaN.

## icsdEstimate

```matlab
[csd, z, info] = icsdEstimate(pots, depth_mm, Method="spline", Cond=0.3);
```

`Method` is `"spline"` (default), `"delta"`, `"step"` or `"standard"`;
`pots` may have a third dimension (every page at once; the methods are
linear). `csd` is `[nZ x nTime (x nGroups)]` in µA/mm³ and `z` the depths
(the channels' own for delta and standard; spline's `NumOut` points and step's
fine grid extend half a spacing past the end channels). The toolbox's
parameters are passed in SI, as its functions take them: `Cond` and
`CondTop` (S/m), `Diam` (m), `GaussSigma` (m, the spatial smoothing of spline
and step), `B0`, `B1` (the 3-point filter of delta and standard) and `Vaknin`.
`Surface` is the top channel's depth below the surface, mm (one spacing by
default); it matters only with two layers (`CondTop` ≠ `Cond`), and `z` stays
relative to the top channel.

Delta and step need equally spaced channels (`icsdEstimate:NotUniform`
otherwise: the toolbox's delta forward matrix is built from the first spacing
alone); spline takes any spacing and standard uses the mean. The spline's
imaginary top node sits at the surface, so `Surface` must be positive for it
(`icsdEstimate:Surface`). One toolbox property to know: its Gaussian smoothing
(spline and step) reports the smoothed profile one grid step shallower than
the unsmoothed one, as CSDplotter 1.0.0 does; with spline's 50 points over a
16-channel, 0.1 mm shank that is about 0.035 mm. `GaussSigma=0` avoids it.

## kcsdEstimate

```matlab
[csd, G, info] = kcsdEstimate(depth_mm, pots, Rs=h * [1 2 3 4], Lambdas=[0 logspace(-8, -1, 15)]);
[csd, G, info] = kcsdEstimate(pos_mm, pots);        % [x depth]: KCSD2D
```

kCSD fits the potentials with a field of Gaussian basis sources of width `R`
under a ridge `lambda` and reads the CSD off a grid finer than the channels:
`csd` is `[nX x nTime (x nGroups)]` on `G.x` (mm below the top channel), or
`[nX x nY x nTime (x nGroups)]` on `G.x`, `G.y` for a 2-D layout. The options
are kCSD's keyword arguments in its units (mm, S/m): `Sigma` (0.3 here; kCSD's
own default is 1), `H`, `NSources`, `RInit`, `Gdx`, `Gdy`, `ExtX`, `ExtY`, the
grid bounds, `Lambda` and `SrcType`. `Lambdas` and `Rs` cross-validate (kCSD's
`cross_validate`, leave one electrode out) and use the best pair;
`CrossValidate=true` does so with kCSD's defaults; `LCurve=true` picks by its
L-curve instead. `info` holds `lambd` and `R` as used, `nSources`, `potEst`
(the potentials the estimate reproduces at the channels, V, a fit check), the
cross-validation table (`cv.errors` `[nRs x nLambdas]`) and the Python used.

The arrays go to Python and back as `.npz` files (`writeNPZ`, `readNPZ`) in a
temporary folder; `kcsd_estimate.py` beside `kcsdEstimate.m` runs the
estimator. The Python is `Python=` when given, else the first of
`KCSD_PYTHON`, MATLAB's `pyenv` executable, a `miniconda3` or `anaconda3`
base install under `%LOCALAPPDATA%` or the profile, and `python` on the PATH
that imports numpy, scipy and kcsd (remembered for the session). `Source=`
names a kCSD-python checkout to import from when the package is not
installed. kCSD-python's validation module still imports
`scipy.integrate.simps`, removed in SciPy 1.14; the script puts the alias back
before importing. Units: positions in mm, potentials in mV and conductivity
in S/m make kCSD's CSD µA/mm³ directly; `kcsdEstimate` converts V to mV on the
way out.

## The browser scripts

[`S_DatasetBrowserToICSD.m`](../analysis/browser_scripts/S_DatasetBrowserToICSD.m)
and [`S_DatasetBrowserToKCSD.m`](../analysis/browser_scripts/S_DatasetBrowserToKCSD.m)
are [post-processing scripts](DatasetBrowser.md#the-post-processing-script)
of the dataset browser. Either works from `B.Result` (a signal computed with
*Keep single trials*: `csdEpochs`) and from `B.Sessions` (whole sessions of a
signal, the kept trials cut in the browser's window around `TrialOnset`:
`csdSessions`), one element per shank profile, and runs when its data is
there. The iCSD script estimates every method in `methods` (`csd.<method>`,
`z.<method>`) and draws the first profile by every method beside its LFP,
then the first method for every group of every profile of the first dataset
with the potentials overlaid. The kCSD script cross-validates `R` over
`rsPerSpacing` channel spacings and `lambda` over `lambdas`, estimates every
group at once (`csd`, `grid`, `info`) and draws the LFP, the kCSD, the fit at
the channels, the cross-validation error per `R` and, for a 2-D layout, a map
of the shank at the largest |CSD|, then every group of every profile. Both
save one file per dataset when `outDir` is set, the whole-session signal left
out.

Positive CSD (red in the plots) is a source and negative (blue) a sink; the
depth axis runs down.

## Tests

`test_CSDEstimate` checks `laminarColumns`, the two builders on made-up data,
and the estimators on known potentials (the standard iCSD recovers the
constant CSD of a quadratic potential; every method and kCSD put a Gaussian
bump's source at its center; pages are linear; cross-validation tables; a
2-D layout; every error). The iCSD section runs when the toolbox is on the
path or at `c:\src\iCSD`, the kCSD section when a Python with kcsd is found.
`test_DatasetBrowser`'s `csdOfEpochsAndSessions` checks the builders on the
analysis fixture: the epochs' and the whole sessions' evoked potentials
agree.
