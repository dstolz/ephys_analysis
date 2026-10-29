# Changelog

Notable changes to this repository. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and version numbers
follow [Semantic Versioning](https://semver.org/). The current number is in
[`VERSION`](VERSION); [README.md](README.md#versions-license-and-citation)
says how to cut a release.

## [Unreleased]

### Added

- Several kinds of data at once in the dataset browser: **Data** is a box per kind (`units`, `detected`, `LFP`,
  `MUA`, `SPIKE`, `AUX`), and `epochMatrixSettings`' `data` a string row. **Compute** computes each kind on its
  own (`epochMatrixSettings(S, Kind=K)`, cached per kind) into `B.Results`, by kind; `B.Result` stays the first
  kind's. **Load whole sessions** gives an entry per dataset and kind in `B.Sessions` (`sessionData` returns one
  per kind, leaving out a kind the dataset lacks). The Channels tab is one pick for every probe kind; AUX among
  other kinds keeps all its columns and Magnitude is AUX's. The Cached column, the summary and the exported
  script follow every kind. The result file is version 2 (`results` in place of `result`); a version 1 file's
  result is not read. `epochMatrixSettings:SeveralData` when a cache identity is asked of several kinds (so
  `epochMatrix` given several). The exported script now writes a `data` other than the default (it was left
  out). `S_DatasetBrowserToNeuroGLM.m` takes `withSignal` from `B.Sessions` when that signal was loaded too.

- Current source density connectors for the dataset browser: `laminarColumns` finds the laminar profiles of a
  channel table (a staggered shank merges into one profile, a true two-column shank separates, `"2d"` keeps a
  shank's layout; depths in mm below the top channel), `epochMatrixCSD` and `sessionDataCSD` arrange a signal
  result's epochs or whole sessions' kept trials along them (the evoked potential per group in V, every epoch,
  the whole signal); `icsdEstimate` runs the iCSD toolbox's spline, delta, step and standard methods (Pettersen
  et al. 2006; delta and step refuse unequal spacing), `kcsdEstimate` runs kCSD-python's KCSD1D /
  KCSD2D in a Python with `kcsd` through `kcsd_estimate.py` (`.npz` in and out; `R` and `lambda` cross-validated
  or by L-curve; the fitted potentials back), both in uA/mm^3. The post-processing scripts
  `S_DatasetBrowserToICSD.m` and `S_DatasetBrowserToKCSD.m` estimate and draw them per group and shank;
  `test_CSDEstimate` and `test_DatasetBrowser`'s `csdOfEpochsAndSessions` check them;
  [CSDEstimate.md](documentation/CSDEstimate.md) documents them.

- FieldTrip spikes from the dataset browser: `epochMatrixFieldTrip` turns a spike result's epochs into
  `ft_datatype_spike` structures cut into trials (`time`, `trial`, `trialtime`, `trialinfo`; timestamps on the
  recording with `Fs=`), and `sessionDataFieldTrip` whole spike sessions into timestamped spike structures with a
  `cfg.trl` for `ft_spike_maketrials`; new general builders `FieldTripExport.spikeTimes` and `.spikeTrials`. The
  post-processing script `S_DatasetBrowserLFPToFieldTrip.m` is now `S_DatasetBrowserToFieldTrip.m` and handles
  signals and spikes (a raster and PSTH per group for spikes). `sessionDataFieldTrip:NoSignal` is now
  `sessionDataFieldTrip:NoData`.
- Dataset browser: its post-processing scripts (`S_DatasetBrowser*.m`) moved from `analysis/scripts` to their own
  folder, `analysis/browser_scripts`. Every script there is always listed, first, found again at each start, and
  cannot be taken off the list (`DatasetBrowser:BundledScript`); **+** and **−** add and remove scripts from
  elsewhere, and the `Scripts` preference keeps only those.

- neuroGLM connector: `NeuroGLMExport` (`experiment`, `designSpec`, `fit`, `predict`) hands trials to the
  [neuroGLM](https://github.com/pillowlab/neuroGLM) toolbox (Park, Meister, Huk & Pillow 2014) and fits its Poisson
  GLM, by neuroGLM's own `matRegress` route (`fminunc`, a ridge prior with the paper's evidence optimization) or by
  `glmfit`; `sessionDataNeuroGLM` builds the experiment from a dataset browser whole session (a trial per
  kept trial, every digital line's edges as events, the trial parameters and group as values, optionally a signal as
  a continuous covariate); the post-processing script `S_DatasetBrowserToNeuroGLM.m` fits one unit per dataset and
  draws the kernels, held-out trials and PSTHs. See [NeuroGLMExport](documentation/NeuroGLMExport.md).
- mTRF-Toolbox connector: `mTRFExport` (`resample`, `envelope`, `pulses`, `lines`, `trials`, `segments`, `package`,
  `lagSamples`) prepares stimulus / response pairs for the [mTRF-Toolbox](https://github.com/mickcrosse/mTRF-Toolbox)
  (Crosse et al. 2016: temporal response functions and decoders by ridge regression over time-lagged inputs);
  `epochMatrixMTRF` makes a trial per epoch of a browser result (an impulse of unit area on the event, so the TRF is the
  evoked mean), `sessionDataMTRF` the whole sessions (the signal or binned spike trains resampled; a digital line's
  pulses, a trial parameter, an AUX channel's envelope or a function as the stimulus; artifact-free pieces or the kept
  trials as the folds); the post-processing script `S_DatasetBrowserToMTRF.m` cross-validates, trains, tests and plots
  a TRF and a decoder. See [mTRFExport](documentation/mTRFExport.md).
- Dataset browser: a **Help** menu with the wiki page, the documentation home and **About DatasetBrowser** (the
  version and git commit of the code, the last commits of the browser's files, the result file's and the cache's
  versions, what is loaded; `B.aboutText()`). `showAbout` takes optional detail lines.
- Dataset browser: **File > Export compute script...** (`B.exportScript(file)`) writes the least code that computes
  the current settings on the ticked datasets without the window or the browser: an `EphysAnalysisConfig` with the
  ticked keys, `epochMatrixSettings` with only the settings that differ from the defaults (the trials are its
  `selection`), and `epochMatrix`. See [Export a script](documentation/DatasetBrowser.md#export-a-script).
- Pipeline: **Leave out bad channels** (Artifacts tab, `Artifacts.ExcludeBadChannels`, off by default) leaves each
  dataset's bad channels out of every step that works on the signals, before any of them: the common reference,
  artifact detection, spike detection, the sorter (dropped from its chanMap; they stay in the `.bin`) and the Signals
  step, so the exports. A bad channel's noise floor lies outside the common reference's *Good noise* band
  (`Reference.BadLow` / `BadHigh`); a run suggests them for a dataset whose list was never set
  (`EphysDataset.prepareBadChannels`), and **Suggest** or the *Bad* field set them by hand. The list is the
  dataset's `BadChannels`, kept in the manifest's new `bad_channels` block. See
  [Bad channels](documentation/EphysDataset.md#bad-channels).
- Pipeline app, Artifacts tab: the viewer draws bad channels (and the Probe tab's exclusions) light gray, labeled
  *(bad)* / *(excluded)*, with a legend entry saying whether they are left out; the preview's per-channel table grays
  their rows. Right-click a lane to mark its channel bad or not, or to toggle **Leave out bad channels**.

- Reports: **Per page** (`Report.FiguresPerPage`, 1 to 16; default 1, as before) puts several figure pages on one
  sheet of `Report.PageSize` (`"letter"` or `"a4"`) and `Report.PageOrientation` (`"auto"`, `"portrait"`,
  `"landscape"`). A figure's pages, or with `Order "unit"` an observation's, stay on one sheet when they fit, and a
  figure with more pages than a sheet holds is spread evenly over its own sheets. The new `reportPageLayout` lays out
  each sheet: it picks the rows and orientation that draw the pages largest, draws every page at one scale, and never
  enlarges a page. The PDF tiles the pages as vector forms (PDFBox), and its *Pages by observation* counts sheets. The
  HTML sets the same pages side by side as tiles. `reportImage`'s struct gains `sizeCm`, the drawn page's size. See
  [Figures per page](documentation/EphysAnalysisConfig.md#figures-per-page).
- Analysis figures: *probe figures*. A figure with `probe.enabled` (`defaults("FigureProbe")`, the new `probe` block
  after `sessions`) is drawn once per unit or channel as a small tile at its site on the probe, every tile on one page
  per dataset. The `schematic` layout puts each shank in a column and the sites in rows; the `physical` layout places
  the tiles by their µm and keeps them apart by `nudge`, `lanes`, `shrink` or `allow`. `shanks`, `channels`,
  `depthRange`, `maxTiles` and `maxPerSite` choose the tiles. `sharedY` puts each panel on one y range, and a
  bottom-left scale tile keeps the labels. `figureProbeTiles` picks the tiles, `figureProbeCompute` and
  `EphysAnalysisRunner.computeProbeFigure` compute every tile with the shared steps computed once, and
  `renderFigure` draws the page with the new `renderProbeFigure`. A run writes one page per dataset (`{Unit}`
  `probe`), and the scripts do the same. `cfg.isProbeFigure`, `cfg.probeFigureIds` and validate's
  `<figure>.probe.<field>` rules come with it. The app's Figures tab has a **Probe layout** section and draws the
  preview tile by tile, with Cancel. See [Probe figures](documentation/EphysAnalysisConfig.md#probe-figures).
- Dataset browser: `B.showRasters(row)` opens a window on one row of a
  result computed with **Keep single trials**: a unit's raster (a line of spikes per epoch) or a channel's epochs as an
  image, by group or by time, over the row's trace per group. **◀ Previous** / **Next ▶** and a list step through the
  rows; the window follows each new result and closes with the browser. `B.raster(row)`, the new
  `epochMatrixRaster(R, row)`, gives a script the same row: its epochs in the raster's order, each spike's time and
  line, the spike counts per bin of each epoch, or each epoch's trace. See
  [Trial rasters](documentation/DatasetBrowser.md#trial-rasters).
- Dataset browser: opening it with a process pool already open sets **Workers** to that pool's size (the
  `Workers` option still wins).
- Dataset browser: **Keep single trials, not just averages** (above Compute; `epochMatrixSettings`' new `keepEpochs`) keeps every epoch
  before the average in `R.epochs`, one element per dataset: its epochs table `E` (with `resultGroup`, the group
  in `R.groupLabels`), its rows of `R`, and each row's spike times from the event with their epoch, or each epoch's
  signal trace `data(row, time, epoch)`. These parts are cached apart from those without epochs. The result file
  leaves `R.epochs` out because the kept parts already hold them, and a restore assembles them again. See
  [The result](documentation/DatasetBrowser.md#the-result).
- Dataset browser: **Keep on top** (`B.OnTop`, remembered) holds the window above the other windows.
- Dataset browser: the settings form's **Event** and **Trials** tabs are the analysis app's own event, window and
  trial-selection controls (the new `AlignControls`, which the app now builds from too), so the browser sets every
  field of `ref` and `selection`: event **Sequence**s of any length in the app's *Event sequence* window (*followed
  by* / *not followed by*, **Align to**), **Scope**, **Offset**, **Length**, **Time range**, **Shift by**, the trial
  **Filter**, **Pairing**, two **Group by** parameters, **Max groups** and **Artifacts**. **Epoch Diagram** (and
  `B.showEpochs()`) shows how the settings cut the lists' dataset. The one-step **Then** row is gone. See
  [The settings form](documentation/DatasetBrowser.md#the-settings-form).
- Dataset browser: **Normalize** (`none`, `subtract`, `ratio`, `percent`, `zscore`, `minmax`), **Baseline (s)** and
  *per row* / *per group* normalize each row of the result against its baseline window or to 0 to 1. A change
  normalizes the result in place and computes nothing. `epochMatrixSettings`' new `normalize` field does the same
  in `epochMatrix`, and the new `epochMatrixNormalize(R, N)` normalizes any result again, without stacking. The raw
  values stay in `R.raw`, and `R.labels` names the normalization. See
  [Normalization](documentation/DatasetBrowser.md#normalization).
- Dataset browser: `DatasetBrowser(root)` opens a window over a project's datasets. **Subject**, **Tags** and
  **Search** filter the table, **Use** ticks datasets, the **Settings** form sets the event, window, groups and
  **Data** (`units`, `detected`, `LFP`, `MUA`, `SPIKE`, `AUX`), and **Compute** gives one matrix over the ticked
  datasets, `R.data(row, time, group)`, with `R.rows`, `R.t`, `R.groupLabels` and the other fields of
  `epochMatrix`. A script waits for the window with `B.wait()` and reads `B.Result`, or runs headless
  (`setFilter`, `tickShown`, `compute`). A progress strip with **Cancel** serves the scan, the compute, `forEach` and
  a script's own loop (`progressStart`, `progressStep`, `checkCancel`, `progressFinish`). See
  [DatasetBrowser](documentation/DatasetBrowser.md#the-window).
- New `epochMatrix`, `epochMatrixSettings` (settings in JSON files, `epoch-matrix-settings`) and `DatasetRuns`: each
  dataset's part is kept and reused while the settings and a stamp of the dataset's output files (names, sizes,
  times: `outputsStamp`) are unchanged, so re-sorting a dataset computes it again and ticking one more dataset
  computes only that one. The browser keeps them, with its state and the result, in
  `<root>\DatasetBrowser_results.mat`; `B.forEach(fn)` caches any per-dataset code the same way. See
  [The cache and the result file](documentation/DatasetBrowser.md#the-cache-and-the-result-file) and
  [`forEach`](documentation/DatasetBrowser.md#foreach).
- New `datasetFilter`, the subject, tag and text filter shared by the dataset browser and the analysis app's Data
  tab. See [The filter](documentation/DatasetBrowser.md#the-filter).
- Analysis app, Data tab: a filter over the datasets table. **Subject:** (picked from the subjects in use, or several
  typed, comma-separated, with `*` / `?` wildcards) and **Tags:** (any of / all of the tags picked or typed) show only
  the datasets that pass both; a hidden dataset keeps its **Run** tick, and the line above says *showing k of n (m
  ticked hidden)*. **Tick shown only** ticks exactly the datasets shown; **Untick all** clears every tick. See
  [The filter](documentation/EphysAnalysisApp.md#data-tab).
- Pipeline app: **File > Scan the project at startup** (a check item, on by default, remembered as the `AutoScan`
  preference) turns the startup scan of the reopened config's project off.
- Tags for new datasets. Pipeline app, Project tab, under **Scan**: **Tag new datasets:** with a field of tags and
  **Choose...** (the tag window, from the tags in use). Each dataset a scan finds for the first time (no manifest yet)
  gets those tags, written to its new manifest, so once only. Saved in the config (`Project.AutoTag`,
  `Project.NewDatasetTags`), so each project has its own; `EphysProject.refresh` takes them as `NewTags=` and its
  report gains a `New` column, and `EphysPipeline` and the standalone script pass them too. See
  [Tags for new datasets](documentation/EphysPipelineApp.md#tags-for-new-datasets).
- Tag datasets. A dataset holds up to 12 free-form tags (lowercase letters, digits, `-`, `_`, `.`; 1-50
  characters), kept sorted in its manifest's new `tags` array (`EphysDataset.Tags`); a manifest without the key has
  none, and tags that are not valid are dropped with a warning that the Scan alert shows. Tags are metadata only: no
  step reads them. New `TagSet` holds every rule (check, parse, add/remove, bulk edit with an all-or-nothing or skip
  policy at the limit, any/all filter, search, text in and out) and `TagDialog` edits one dataset or the ticked ones
  (add to all / remove from all, **If a dataset would exceed the limit:** *Cancel the whole edit* or *Skip that
  dataset*). Pipeline app, Project tab: a **Tags** column (click a cell to edit that dataset), a **Tags...** button
  and **Dataset > Tags...** for the ticked datasets, and a **Tags:** filter (any of / all of, plus a search, combined
  with AND). Tags reach `gatherMetadata`'s `Tags` column, the pipeline run record, the `.mat` exports' `export` /
  `conversion` blocks, the kCSD `meta`, the NWB `notes` and the manifest viewer; on the analysis side `src.tags`
  (`loadAnalysisSource`, `outputTags`), the analysis app's Data tab, the report (a Tags row in the Recording table,
  beside the star in HTML, in brackets in the PDF), `sessionTable`'s `tags` column (and the generated scripts) and
  the population tables (`population_units.csv`, `population.json`). Tables join tags with `;`, JSON and `.mat`
  carry the list. See [Dataset tags](documentation/EphysPipelineApp.md#dataset-tags) and
  [Tags](documentation/EphysDataset.md#tags).
- Report order. `Report.Order` (`"figure"`, the default and the order so far, | `"unit"`) arranges each dataset's
  part of the HTML and PDF reports: by figure, each figure with all its observations' pages together; by unit, an
  observation at a time (a unit, a channel, or the dataset for the figures of the dataset) under a heading of its
  label, with its pages of every figure in the figures' order (the HTML contents list the observations; the PDF's
  summary page lists each one's pages). `addReportFigure(Observations=)` keeps each page's observation for it.
  Export tab: **Order** in the report settings. See
  [Report order](documentation/EphysAnalysisConfig.md#report-order).
- A figure's first-spike latency, found once for all its panels, by one of three rules, and the unit's response
  onset by CUSUM. A figure's new `latency` block (`defaults("Latency")`) says how: `method` `"first"` (the first
  spike in the window, as before), `"surprise"` (the first burst whose Poisson surprise against the baseline rate
  passes `surprise`; Legendy & Salcman 1985) or `"poisson"` (the first spike at which the count since the window's
  start is improbable, p < `alpha`; Chase & Young 2007), the window `minSec`-`maxSec`, the baseline (before the
  event or a window of its own; the unit's rate or each trial's) and the onset's CUSUM (`cusumBinSec`,
  `cusumThreshold`, `cusumDrift`, `cusumSustainSec`: Page's one-sided cumulative sum of the PSTH over its baseline,
  Ellaway 1978). `figureCompute` takes them once per unit and alignment and hands them to every panel that reads
  them (`R.latency`, `R.onset`, `F.latency`), kept in the preview's cache: an edit of the block computes them again
  and no panel, and only the panels that read them are drawn again. New `responseOnset`; `firstSpikeLatency` gains
  `Method`, `Baseline`, `BaselineRate`, `Alpha`, `Surprise`, `MinSpikes`. A raster's or PSTH's new
  `options.onsetLine` (`"off"` | `"unit"` | `"groups"`) draws the onset as a dashed line (role `latencyOnset`, its
  data tip the onset). The window left a raster's `firstSpike` and a PSTH's `latencyBox` (their looks alone now)
  and the latency sort: it is the block's. Figures tab: a **First-spike latency** section (Figure supersection)
  edits the block; the raster's window is **First-spike marks...**, both panels gain **Onset line**. See
  [First-spike latency](documentation/EphysAnalysisConfig.md#first-spike-latency).
- Join the detection channels that hold one neuron. `UnitSelection.merge` (`enabled` false) makes
  `selectUnits(source "detected")` return one unit per group of channels of neighboring sites instead of one per
  channel: `groupDetected` joins two sites when the events of one leave the refractory gap (more than the
  Coincidence jitter, at most `refractoryMs`) empty next to the other's, against the count the `flankMs` lags
  predict (Poisson), and names the unit for its channel with the largest mean waveform, holding every spike of the
  group once. The unit table gains `nSites` and `sites`. Needs the Spikes step's Coincidence `"remove"` or `"tag"`.
  See [UnitSelection](documentation/EphysAnalysisConfig.md#unitselection).
- Sort rasters by first-spike latency, and show the trials in each PSTH group. `rasterSort "latency"` orders a
  raster's rows (and a heat map of trials') by each epoch's first spike, within the groups, ascending or
  descending, epochs with no spike in the window last; a raster reads its `firstSpike` window, else the event to
  the window's end. `rasterInto` now takes its order from `figEpochOrder`, which the heat map of trials and the
  event traces already used (a sort key the result lacks sorts in time order instead of erroring). A PSTH's new
  `options.trialCount` (`"off"` | `"text"` | `"legend"`) writes `n = 24` per group in the group's color (role
  `trialCount`; stacked: at each row's right end; heat map: beside each row) or appends ` (n = 24)` to the legend
  entries. Figures tab: **Sort rows by** offers *latency*, new **Trial count** row. See
  [First-spike latency](documentation/EphysAnalysisConfig.md#first-spike-latency) and
  [Trial counts](documentation/EphysAnalysisConfig.md#trial-counts).
- Figures tab: **a figure's page size.** A figure has a `size` (`defaults("Figure").size`: `source`
  `"export"` -- the Export tab's `FigureSizeCm`, taller for the rows as before -- or `"own"`, `width` x `height`
  in `units` `"px"` (pixels of the exported PNG, at the Export `Dpi`), `"in"` or `"cm"`, and `lock`, the editor's
  aspect-ratio lock). `figureExportSize(Export, F, spec)` gives the page in cm and `newExportFigure` draws every
  export on it (runs, Generate, Export preview, generated scripts). The editor's new **Size** row under **Title**
  is an editable drop-down (*Export tab size*, *700 x 800 px*, journal 1, 1.5 and 2 column, *Slide 16:9*,
  *Square*, *Fit preview*, or a typed `6 x 4 in`, `1200x800 px`, `15 x 10 cm`) with **Width x height**, a
  units box and **Lock ratio**. The preview is now the shape of the page, as large as fits and centered (the
  gray round it), with its fonts and lines scaled to the page, so it represents the export; a size edit is one
  undo step (*Size*) that shapes the preview and draws it again from the figure it holds, without computing.
  **Open in window** opens a figure of the page's shape at its true size. New functions `figureExportSize`,
  `figureSizePresets`, `figureSizeParse`, `figureSizeText`, `figureSizeConvert`; tests in `test_EphysAnalysisFigures`
  section 13 and `test_EphysAnalysisApp` section 5o. See
  [The page a figure is exported on](documentation/EphysAnalysisApp.md#the-page-a-figure-is-exported-on).
- Figures tab: **Ctrl+Click a panel** in the preview (or an **Open in window** figure) selects it in the figure
  editor and scrolls to its **Selected panel** section (`renderFigure(..., OnSelect=)`,
  `EphysAnalysisApp.onFigurePanelClicked`). A Ctrl+Click reports the same button as a right-click, so it is told
  by the Ctrl key; the right-click menu is unchanged, and picking a panel is no edit (no undo step, no
  **Apply to figures** although Ctrl is held).
- Analysis app: **remembered panel options.** The options you set on a panel are remembered per panel type, a
  preference (`PanelOptions`), not the config: a new panel (New panel..., and so a figure's first from Add) starts
  from them over the type's defaults, the New panel window's key parameters too; panels you have, and configs, are
  never changed by them. Options naming one dataset's or figure's things are left out (a sort by an event, the
  group shown, a recording range); a sort, tuning parameter or series by a trial parameter is pre-filled only where
  the active dataset has it. **Edit > Reset panel options to defaults** (the selected panel, one undo step, and its
  type's remembered options forgotten) and **Edit > Forget remembered panel options**. `onNewPanel(Type=...)` takes
  `Remembered=true` for the same. See
  [Remembered panel options](documentation/EphysAnalysisApp.md#remembered-panel-options).
- Analysis app: **a color swatch beside every color field** of the Figures editor and of the First-spike latency and
  Latency box plot windows; it shows the field's color and opens the color chooser (`uisetcolor`), the color picked
  written as `#rrggbb`, one named undo step. Names, codes and words such as *groups* can still be typed
  (`private/colorSwatch`; the app's `ColorPicker` property is the chooser). See
  [Picking a color](documentation/EphysAnalysisApp.md#picking-a-color).
- First-spike latency on raster and PSTH panels. `firstSpikeLatency(R, Units=, MinSec=, MaxSec=)` finds each
  epoch's first spike at or after `MinSec` and at or before `MaxSec` (both included, s from the aligned event;
  NaN where none; `MaxSec` `Inf` = the window's end) in a `spikePSTH` result's raster rows, the very spikes the
  raster draws. A raster's new `options.firstSpike` (`defaults("FirstSpike")`: `enabled`, `minSec`, `maxSec`,
  `marker`, `size`, `color` "groups" or a color, `filled`) marks each epoch's first spike on its row, over the
  ticks, whatever the sort, `rasterByGroup` or a further block's band (role `firstSpike`, "First spike" in the
  legend, a data tip naming the trial). A PSTH's new `options.latencyBox` (`defaults("LatencyBox")`: `enabled`,
  `minSec`, `maxSec`, `color`, `lineStyle`, `lineWidth`, `boxHeight`, `fillAlpha`, `outlierMarker`,
  `outlierSize`) draws a box plot of the latencies per trial group (quartiles by `prctile`, the median,
  Tukey's whiskers, outliers) in a band of its own above the traces, or with `stack "groups"` in a lane above
  each row's range (outside the traces in every `yLimMode`) (roles `latencyBox`, `latencyMedian`, `latencyWhisker`, `latencyOutlier`; a data tip with the statistics
  and n); such a PSTH keeps its raster's rows. Both are off by default, validated while on, named in the
  figure's caption and drawn on rows merged across sessions. In the analysis app the raster's **First spike**
  row and the PSTH's **Latency box** row show a summary beside **First-spike latency...** and **Latency box
  plot...**, which open a modal window whose OK is one undo step (*First-spike latency*, *Latency box plot*).
  New suite `test_FirstSpikeLatency`. See
  [First-spike latency](documentation/EphysAnalysisConfig.md#first-spike-latency).
- Figures tab: **each figure keeps its own preview.** The preview has a container per figure (`syncFigureView`;
  uipanels stacked in one cell, the shown one visible, since a tab group's strip cannot be hidden reliably), so a
  figure switched away from keeps its drawing, badge, status line and *Figure:* pick, and switching back shows it
  without computing or drawing it again unless it is out of date (`figureViewKey`: its figure with the defaults it
  uses, the active dataset or the ticked ones, its observation and a scan count; then it is drawn as after an edit).
  The eight figures shown last keep theirs (`EphysAnalysisApp.MaxFigureViews`), Remove frees a figure's container and
  another config drops them all. The tree drives it and marks it (`markFigureTree`): the figure shown bold, a preview
  out of date amber and italic, a failed one red, one not drawn gray; an edit marks only its own figure. The editor
  comes back as each figure left it: its sections and supersections open or collapsed, its scroll, its panel and
  layer (`saveFigureEditorState`, `restoreFigureEditorState`). A switch between drawn figures took about 2.5 s on the
  synthetic test project (a compute and a draw each time) and now about 1.6 s, the editor's own refresh being most
  of what is left. While a preview computes, another figure selected shows in the editor at once and in the preview
  when that one is drawn.
- Automatic y limits, one option on every panel type with `yLim` (PSTH, continuous, waveforms, rate, tuning,
  spectrum, coherence): `options.yLimMode` `"auto"` (each axis fits its data; in a stack each row fits itself,
  its top on the right axis) | `"rows"` (a stack's rows share one scale) | `"batch"` (one range for every
  observation of a run) | `"fixed"` (`yLim`). A run (`EphysAnalysisRunner.run`: Export **Run**, Figures
  **Generate**) measures a batch figure's every observation on every dataset first (`batchYLimits`,
  `figureYExtents`, `figureBatchYLim`; computed figures kept for their pages up to 512 MB) and draws every page at
  the union (`renderFigure(..., BatchYLim=)`, `r.BatchYLim`); session figures measure their matched observations;
  the standalone script writes the same measuring pass. Captions say `y shared across <n> observations`; the
  preview draws its own range and its status line says the run shares it. The editor's **Y limits** row is a
  drop-down (*Auto*, *Shared by rows*, *Shared by batch*, *Fixed*) beside the limits' field, open only for
  *Fixed*; Apply to all panels copies the mode. A migrated version 1 plot's `YLim` becomes `yLimMode "fixed"`.
- Stacks for every panel type that draws trial groups over one shared axis, in one vocabulary
  (`EphysAnalysisConfig.stackModes`): `options.stack` `"off"` | `"groups"` (a row per trial group, the first on
  top) on a PSTH, continuous, heat map (rows `"items"`: a block of units per group), tuning (a row per series),
  spectrum, spectrogram and coherence panel, and `"items"` (a row per channel) on a continuous panel;
  `options.stackSpacing` is the row step times the row height everywhere (default 1.1). Line rows (PSTH,
  continuous, spectrum, coherence, tuning) share `stackLayout`, `stackBaseLines` and `stackAxes`: a gray line
  per row, the groups' values on the left axis, each row's top on the right; image rows (spectrogram,
  coherogram: `drawImageStack`; heat map: `renderHeatmap(..., Stack=true)`) share the time axis and one color
  bar, each with its group's color strip (role `rasterBand`) and name. The editor's **Stack** row (a drop-down
  with its spacing) shows on every such type and hides, with the reason, where stacking makes no sense
  (raster, firing rate, waveforms, probe map, unit correlation, event traces); **Apply to all panels** and a
  type change carry the stack where the type takes its value. Data tips read stacked traces back through
  each row's `StackMap`. A raster keeps listing its groups in blocks, so it takes no stack.

- **Undo** and **Redo** tools on the analysis app's toolbar, after the File group (`undo.svg`, `redo.svg`): the Edit
  menu's items, named in their tooltips (*Undo Add panel (Ctrl+Z)*) and on and off with them (`refreshEditMenu` keeps
  both). Every undo step is named now: the event and sort sequence dialogs (*Event sequence*, *Sort sequence*), the
  overlay buttons (*Add overlay*, *Duplicate overlay*, *Remove overlay*), *Figure id*, *Automatic figure id*, *Panel span*,
  *Layer binding*, *Unit mapping file*, *Edit unit mapping*, *Pick datasets*, and the alignment edits and toggles
  (*Figure window*, *Panel event*, *Figure alignment from Defaults*...); `onConfigChanged("figure", "Name")` takes a
  string as the step's name.
- Figures: a raster panel's `options.tickColor` takes `"groups"` (each trial group's color, the default; it was
  `""`), as `options.backColor` does; the editor's ticks drop-down lists *groups* instead of a blank item. A new
  `options.tickWidth` (the Raster options' *Tick width* row; points, `0` = the plot design's width) sets the
  ticks' line width over the design's; Apply to all panels copies it with the other raster options.
- Axis sides for every panel at once, and axis edits from a panel's axes. Options' **Apply to all panels**
  (`EphysAnalysisConfig.adoptPanelOptions`) now also copies the panel's axis sides (`xSide`, `ySide`) to every
  other panel, of any type, and lists them with the changed fields; the label texts (`xLabel`, `yLabel`) stay
  each panel's own, like its title, and the button is on whenever the figure has another panel. An axis
  label's right-click menu gains **Move every panel's X axis to top** / *bottom* (**... Y axis to right** /
  *left*), one undoable step (*Every panel's axis side*), so a stack of time panels takes its one time axis to
  the top at once. The right-click menu of a panel's axes itself (the plot area) gains **Edit X label
  text...**, **Edit Y label text...**, **Move X axis to top**, **Move Y axis to right** and the every-panel
  moves, in the preview and in an **Open in window** figure, so a label the time stack hides can be set too
  (the status bar says the stack does not show it). renderFigure's `OnAxisEdit` (and
  `EphysAnalysisApp.onFigureAxisEdited`) now takes a string row of panel ids. See
  [Figures tab](documentation/EphysAnalysisApp.md#figures-tab).
- **Starred only** for figures (`observe.starred`, a checkbox in the Figures tab's Observations section): the
  preview's picker, < >, Generate, Export runs and scripts keep only the starred units of the sort in use, the
  starred channels (a detection channel by its recording channel) or a starred dataset, read from
  `<Name>_favorites.json` beside the data; a dataset with none is skipped (`no starred observation`). A session
  figure keeps a match starred on any of its sessions, drawn on all of them. `figureObservations` and
  `figureSessionObservations` gain a `starred` column (`figureObservations(..., Favorites=)` takes the stars in
  memory; `DatasetFavorites.observationStarred`), and `figureCaption` says how many observations are starred
  (*12 observations (sorted units; 3 starred)*) or *starred only*. The Favorites lists label a unit of an opened
  dataset with its class, channel and depth (*subj1_day1 · unit 12 · su · ch 5 · 850 µm*) and a channel with its
  depth, from what is already in memory (app property `DatasetUnits` replaces `DatasetUnitCounts`), and a figure
  across sessions marks its starred matches ★ in the picker. See
  [Favorites](documentation/EphysAnalysisApp.md#favorites).

- Tests by section, and a local runner. `run_all_tests({'test_EphysAnalysisApp:5i,5j'})` runs only those
  sections of a function-style suite that takes them (`TestSections`: `test_EphysAnalysisApp`,
  `test_EphysPipelineApp`, `test_EphysAnalysisFigures`; a section declares what it needs, and every run
  prints each section's seconds), `ExcludeTag=` leaves tests out by tag (`Slow`: the copy schedule's Task
  Scheduler run, the real SpikeInterface sort, the process pool; `Benchmark`) and `ResultsCSV=` writes the
  results table. `tools\Run-Tests.ps1` runs suites or sections in a hidden MATLAB with a log, two test
  MATLABs at most, a timing ledger under `%LOCALAPPDATA%\ephys_analysis`, `-Each` (every section alone) and
  `-Select`, which runs what `.github/scripts/select_suites.py --worktree --sections --why --expect` prints
  for the uncommitted change (the selector now takes a working tree, names sections, says why and how long).
  The analysis app suite's Figures-tab sections draw the preview only where a check reads it instead of after
  every edit. See [Tests](documentation/README.md#tests).

- `removeLineNoise`: removes mains interference (`LineHz`, 60 Hz by default, and its `Harmonics`) by
  subtracting sinusoids refitted in every Hann window (`WindowSec`, 2 s, half overlapping) instead of
  filtering. The frequency is tracked window by window within `MaxDeviationHz` (0.25 Hz) of `LineHz`, from
  all channels together, and steadied by a running median (`SmoothWindows`); `Tracking` `"global"` /
  `"fixed"` and `PerChannel` are the alternatives. Amplitude and phase are each channel's own, and `Gate`
  (`"soft"`) scales each fit by its SNR over the background beside it, so a line-free channel or a broadband
  transient is left alone. It also takes `Exclude` rows, leaves `NaN` alone, and runs in pieces (`FirstRow`,
  `info.MarginRows`) with the same result as one run. It needs no toolbox and takes about 2 min per
  64-channel hour at 30 kHz. Not yet wired into a step. See
  [Line noise](documentation/EphysDataset.md#line-noise-removelinenoise).

- Spikes: one spike seen on neighboring sites, kept once. A detector reports a spike on every site it reaches;
  `detectSpikes` now takes `Coincidence` (`"remove"`, `"tag"`, `"none"`), `CoincidenceRadiusUm` (50 µm),
  `CoincidenceJitterMs` (0.5 ms) and `SitePositions`. Events on sites within the radius of each other (the true
  distance on the probe, `siteNeighbors`) whose troughs lie within the jitter are copies of one spike. Going
  from the deepest trough down, each spike keeps its largest copy (`"remove"`), or every copy is kept and
  numbered (`"tag"`: `info.eventId`, `info.primary`). Copies are found over the whole recording at once, so
  chunk joins play no part. The Spikes step has it on (`Spikes.Coincidence` `"remove"`). `spikesToMat` takes
  the sites from the dataset's probe (`ProbeFile`; the pipeline passes `probeFor`), and without one it keeps
  every copy with a warning; the run's result, the plan and `detected.detection.coincidence` say so. The
  Spikes tab has a **One spike on neighboring sites** section (mode, site radius, jitter), a **Copies**
  column in the preview, and **Neighbors...**, which opens a window (`SpikeNeighborsDialog`) drawing the
  active dataset's probe with each site's neighbors at the radius. The tab now says what Align decides: the
  sample that is each event's time and its waveform's center (*Save waveforms, centered on the trough*). See
  [Spikes](documentation/EphysPipelineApp.md#spikes) and [detectSpikes](documentation/EphysDataset.md#spike-detection).

- Analysis app: notes on a dataset, a channel or a sorted unit, kept beside the data in
  `<Name>_notes.json` in each dataset's output folder (the new `DatasetNotes` class), beside the stars. A
  **✎** button right of each star (Dataset on the Alignment and Figures tabs, Observation on the Figures tab)
  and a **✎** column in the Data tab open a little notepad (`NotePad`) that stays above the app and follows
  the active dataset or the observation as you pick and step, so you can write a line on each unit in turn;
  the note is written when you leave its box, save (Ctrl+S), move on or close it. Buttons with a note turn
  yellow with its first line in the tooltip, and noted items show **✎** in the drop-downs. **Search notes**
  on the toolbar (`NoteSearch`) searches every note of the scanned datasets as you type (every word, any
  case, over the dataset name, the item and the text); **Go to** or a double-click opens the note's dataset
  and picks its unit or channel for the preview, **Edit note** opens it in the notepad. A unit's note is
  recorded with its sort as a star is (`sortIdentity`, now shared by `DatasetFavorites`), so a new sort
  shows none of the old notes, which the search still finds. These are not phy's `cluster_notes.tsv` notes.
  See [Notes](documentation/EphysAnalysisApp.md#notes), [the script API](documentation/EphysAnalysis.md#notes)
  and [the file](documentation/file-formats.md#notes-name_notesjson).

- Figures: sorted units and detected spikes in every spectral panel. A spectrogram panel now reads a spike
  layer too (**Reads** offers *units (sorted)* and *detected spikes* after the signals): `chronuxSpikeSpecgram`
  steps `mtspectrumpt` over the moving window on one window grid per epoch (Chronux's `mtspecgrampt` spans
  the first to the last spike, so its times would change from group to group), at `options.spikeFs` (new for
  spectrograms, the editor's **Spike rate (Hz)** row), with the same baselines, image and color bar as a
  signal's. A coherence panel drawn **Over time** now takes spike layers (it was a validation error):
  spike-field coherograms (`chronuxSpikeField` with `overTime`, Chronux's `cohgramcpt` on the field's samples)
  and unit-unit coherograms (`chronuxUnitCoherence` with `overTime`, `coherencypt` window by window), over
  the epochs or over a stretch of the recording, drawn as the signal coherogram is.

- Figures: an accelerometer's movement in the spectral panels. A fixed signal layer of a spectrum,
  spectrogram or coherence panel takes `aggregate` `"magnitude"` (the editor's **Aggregate** row, *their
  vector magnitude*): its channels become one item, sqrt(x² + y² + z²) at every sample, each channel's
  centered 2 s running mean taken out first (an axis's offset and gravity, the dynamic acceleration of
  VeDBA), so a coherence panel pairs the observed unit (or an LFP channel) with how much the animal moves,
  `u12 x magnitude of 3 AUX channels`. A coherence of two signals at different rates (AUX is at its own rate,
  the LFP at `LFP_Fs`) resamples the faster one to the slower one's rate (`resample`) instead of refusing
  them. `EphysAnalysisConfig.aggregates(type, source)` is the one list validate and the editor offer; a
  type change sets an aggregate the new type does not take to `"each"`.

- Figures tab: **Unit report**, a spot check of one unit. It draws every enabled figure of the active dataset
  (and the selected one, even when off) for the unit or channel picked over the preview only, as an HTML
  report in a new temporary folder that opens in the browser: no figure files, no session figures, the output
  folder untouched, cancelable from the progress dialog. A figure of the same data draws the unit itself; a
  figure of channels or detections draws what is on the unit's recording channel; a figure of the dataset, or
  one with nothing on that channel, is listed in the report as skipped with the reason, and the status bar
  says what was left out. Off for a figure across sessions. `EphysAnalysisRunner.run` and `runDataset` take
  `Observation=`, and `figureObservations(src, spec, Observation=)` returns the matching rows and why none
  matched.
- Analysis app: an **Edit** menu between File and Design with **Undo** (Ctrl+Z) and **Redo** (Ctrl+Y,
  Ctrl+Shift+Z) of the Figures tab's edits. The items name the edit (**Undo Add panel**, **Undo Bin (ms)**: a
  control's row label) and are grayed with nothing to undo, or off the Figures tab. Every edit of the figures
  is a step: the editor's controls, the arrangement, panel types, layers, the figure list (Add, Remove,
  Duplicate, Up / Down, Copy from..., the tree's check boxes), remembered looks and Pick...; quick edits of one
  field make one step. Only `Figures` is kept (`FigureEditHistory`, 100 steps), so an undo leaves the source,
  defaults, export and report settings as they are; the editor goes back to the figure and panel edited, the
  preview follows, and undoing back to the saved figures clears the title's `*`. A new edit drops the redo
  steps; opening or starting a config clears the history.
- Figures: each panel's own axis sides and label text, for every panel type. Panel fields `xLabel` and
  `yLabel` (`""` = automatic, the type's label) replace the labels drawn; `xSide` (`"bottom"` | `"top"`) and
  `ySide` (`"left"` | `"right"`) put the axis' ticks and label on that side (`renderFigure`'s `panelAxes`,
  once the type has drawn). A coherence panel's x axis on top goes on its magnitude, its phase strip
  dropping its tick labels; a stacked PSTH keeps its y axis on each side; a color bar outside on the side
  an axis moves to goes to the opposite side; the layout reserves the room on the new sides. A stack of
  time panels still tells the time once: a time panel with its x axis on top hides it under a matching time
  panel whose x axis is on top too, so a stack with every x axis on top is labeled at its top
  (`figureTimeStack`; a time label of the panel's own replaces `Time (s)`). Validate checks the sides. In
  the editor, the Selected panel section's **X axis** and **Y axis** rows (the label, blank = automatic,
  and the side; the y side grayed out on a stacked PSTH). Right-click a panel's x or y label in the
  preview, or in an **Open in window** figure, for **Edit label text...** and **Move to top** / **bottom**
  (x) or **Move to right** / **left** (y): renderFigure's new `OnAxisEdit` hands the edit to the app
  (`onFigureAxisEdited`), which commits it through the editor's path (`commitFigureEdit`); without one,
  the figure is drawn again with it. **Go to setting** on a label goes to the new rows.
- The pipeline app, the analysis app and the channel mapper start behind a small startup window (`AppSplash`,
  `pipeline/AppSplash.m`): the app's name, its version, the step under way (each tab built, the preferences,
  the config reopened, the scan with its dataset count, the first dataset loaded) and a progress bar whose
  steps are weighted by their measured times. The main window is built hidden and shows when it is ready,
  then the small one closes; on an error both close and the error goes on. On Windows it is a Windows Forms
  window, which paints without `drawnow` (a uifigure splash's redraws pushed the hidden window to the screen
  piece by piece and made the start a third slower); elsewhere a uifigure. Alerts raised while the app starts
  (`uialert` refuses a hidden figure) wait for the main window (`AppSplash.alert`), and the pipeline app's
  scan reports on the small window instead of its progress dialog. `Splash=false` starts without it, the
  default under `matlab -batch`. The manifest viewer and the probe designer open in under 3 s and have none.
- Pipeline app: the startup scans the reopened config's project when its root is there. A root on a network
  share (a `\\server` path or a mapped network drive) is first looked for in the background
  (`folderReachable`, `backgroundPool`): one that does not answer within 5 s is not scanned, nor is a root
  that is gone, and the status bar says why. A sorting queue kept for that root is offered once the window
  shows. The analysis app checks a config's network root the same way before its scan.
- Figures: a PSTH panel drawn as a heat map, `options.display` `"trace"` (bars or a line per trial group, the
  default) or `"heatmap"`: the unit's PSTH as one image, a row per trial group (the first on top, as a raster
  and a stacked PSTH list them), x the PSTH's bins, colored by its rate after measure, smoothing, baseline and
  normalize. The color scale spans that unit's rows only, never other units' (`options.cLim` fixes it; an
  auROC is on 0 to 1, its modulation window a bar over the image), in `options.colormap` (`""`: **Heat
  colors**, else the design's heat colormap; a name that is no colormap function is a validation warning).
  The rows are labeled with the groups' values, the y label names the group-by parameters and a color bar in
  the measure's unit is the scale (inside the axes when the panel shares its column with other time panels,
  as a heat map's). The zero line, stop latencies, event marks and the waveform inset are drawn over it;
  with several units or layers the first is drawn and the others are noted on the panel. Session figures,
  **Export code** and the exports draw it. In the editor, **Display** (PSTH options, and the New panel
  window) toggles it; a heat map shows **Colormap** and **Color limits** and hides **PSTH as**, **Fill**,
  **Stack** and **Y limits**. The heat map panel's `inTimeColumn` is now a shared helper.
- The dataset manifest holds every processing detail: a `processing` block with a record per output, made
  by its writer as it writes it (`EphysDataset.Processing`, restored by `applyManifest`): `artifacts` (the
  automatic detection), `bin`, `sorting`, `signals`, `spikes`, `behavior` and each export (`chronux`,
  `fieldtrip`, `epochs`, `kcsd`, `nwb`). Each names its file, when and in which pipeline run it was written,
  and every option it was made with, defaults and worked-out values included (`processingRecord`,
  `optionsRecord`: the sorter's whole settings.json, deriveSignals' `importOptions`, detectSpikes' options
  as run, which it now returns in `info.options`, ...), plus what was worked out on the way: the common
  reference applied (CAR, CMR or the weighted CAR, the channels it was taken over, the weighted CAR's
  settings and Q, the signals it was subtracted from), whether a sorter added its own (Kilosort4's
  `do_CAR`), the probe given, the artifact periods erased, the inputs an export read. The pipeline, the
  generated scripts and the Trials tab write the manifest after each detection and output. The spikes file
  records the reference detection ran on (`detected.reference`, `EphysDataset.referenceInfo`). The manifest
  viewer lists it all in a **Processing** section, with a warning for a sort referenced twice.
- Figures tab: right-click any part of the preview (or of an **Open in window** figure while the app is
  open) and pick **Go to setting**. It selects the part's panel, opens the supersection and section that
  hold the setting that controls it (the error band: **Show > Error**; a raster's stop dots: **Stop marks**;
  a tile title: **Title**; the legend: **Legend**), scrolls there, puts the keyboard focus in the control
  and highlights its label; a part with no setting of its own goes to Appearance. `figureRoleSettings`
  lists each role's candidate rows, the first the panel shows wins, and a row the panel hides says why in
  the status bar. `renderFigure` takes `OnGoto=` (role, panel id) for the menu item; without it the menu has none.
- Figures tab: the editor's fourteen sections stand under three collapsible **supersections**, FIGURE
  (Observations, Event reference, Epoch window, Trial selection, Sessions, Arrangement), PANEL (Panel,
  Panel alignment, Layers, Options, Text note, Overlays; its dark header names the selected panel) and LOOK
  (Appearance, Looks), reached with **Alt+1** to **Alt+3** and remembered (`FigureSupersectionsCollapsed`);
  the sections are built in that order, so **Tab** follows it, and their keys follow it: Observations
  Ctrl+1, Event reference 2, Epoch window 3, Trial selection 4, Arrangement 5, Panel 6, Panel alignment 7,
  Layers 8, Options 9, Text note 0 (a section's key opens its supersection too). A search field over the
  editor (**Ctrl+F**) finds a setting by its label or tooltip words, listed as *Supersection > Section >
  Row*; **Enter** or a click opens the supersection and section, scrolls there, focuses the control and
  highlights it, and a row the figure does not show says why in the status bar (*Bin (ms) is an option of
  PSTH, heat map and unit correlation panels ...*). The index is read from the rows as built
  (`figureSearchIndex`), so new rows join it. **Ctrl+]** / **Ctrl+[** step through the figure's panels,
  **Ctrl+Alt+arrows** move across its grid, **F6** / **Shift+F6** go from column to column, and the preview
  outlines the selected panel with a blue frame (`markFigurePanel`: preview only, moved without a redraw,
  following a resize). A **?** button (and **Help → Figures tab keys**) lists every key. See
  [Figures tab](documentation/EphysAnalysisApp.md#figures-tab).
- **Open in window** on the Figures tab, under the preview: draws the figure as previewed into a regular MATLAB
  figure window of its own (`onOpenFigureWindow`; named *id: observation (dataset)*, the right-click
  aesthetics editor works there). An out-of-date preview is redrawn first; the window does not follow later edits.
- Figures: a panel's `box` (`"auto"` = the design's and the remembered looks', `"on"`, `"off"`), a row in the
  editor's Panel section for every panel type; `"on"` and `"off"` are set last in `renderFigure`, so they win
  over the design, the remembered looks and the figure's own aesthetics rules. A raster panel's
  `options.yTicks` (default `false`, the Raster options' *Show y ticks* row): the y axis shows no tick marks or
  epoch numbers unless it is on; the y label, and the names of a raster of several blocks, stay.
- Figures: a raster panel's `options.tickColor` (the ticks' color; `""` = black) and `options.backColor` (a
  background for every group's band and the axes; `""` = each group's pale band), the Raster options'
  *Colors* row. A color name or hex code; one that is not a color is a validation warning. With a background
  the legend lists no groups, since the bands no longer tell them apart.
- Figures: data tips that say what a point is. In a visible figure (the Figures tab's preview, or any
  window you draw with `renderFigure`) a tip names the panel's quantities with their units (*Time from
  Stim onset: 0.125 s*, *Rate: 42.1 Hz*), a heat map cell's value and row, a raster tick's trial, trial
  group and (optionally) trial parameters, the unit or channel, layer, panel, observation and dataset,
  instead of a bare X and Y. The new `FigureDataTips` reads them from the computed figure and the parts'
  tags (no compute added; new panel types get them too); `renderFigure` takes `DataTips="auto"`. The new
  `DataTipFieldsDialog` (right-click **Data tip fields...**, or the app's **Design** menu) picks the
  fields shown, a preference (group `FigureDataTips`) applied to the figures on screen at once. See
  [Data tips](documentation/EphysAnalysisApp.md#figures-tab).
- Figures: automatic ids. A figure's new field `autoId` (default `true`) makes its id follow what it holds:
  its active panel types in grid order, then the data it draws, *Raster+PSTH units*, *Continuous LFP*,
  *Raster+PSTH+Continuous units+LFP* (`EphysAnalysisConfig.autoFigureId`, over `panelTypes`' new `Short`
  column), given whenever `Figures` is assigned (every edit, load) and made unique by the next free *(2)*,
  *(3)* (`nextFreeId`; compared as `{Plot}` writes ids); a figure keeps an id that still fits it, so an edit
  renames only the figure edited. An id given (`addFigure(..., Id=)`, an id typed in the app) is the
  figure's own (`autoId` false) and stays. New `cfg.duplicateFigure(id)`: the copy right after it as
  *&lt;id&gt; (n)*. The app's Id row has an **auto** box (the automatic id in gray; typing unticks it,
  ticking it goes back), and the app follows an automatic rename in what it keeps by id (the observation
  picked, the right-click editors' remembered looks, the Spacing window). See
  [Figure ids](documentation/EphysAnalysisConfig.md#figure-ids).
- The **New panel** window (Figures tab, **New panel...** in the Panels section, and after **Add**): a tile
  per panel type, each a small representative plot drawn by the type's real draw function (the new
  `analysis/icons/panels/<type>.png`, made by the new `tools/makePanelThumbnails`; a placeholder for a
  type without one), the panel's name and title, its place beside the selected panel and the type's key
  parameters (what it reads and the binding; a raster's sort, a PSTH's bins and measure, a continuous
  panel's display and error band, a heat map's rows, an event-trace panel's lines, a spectral panel's
  frequency range, ...). New `onNewPanel` (Type= and the choices as options for scripts and tests) and
  `private/newPanelDialog`. See [the New panel window](documentation/EphysAnalysisApp.md#the-new-panel-window).

- Adaptive weighted CAR for the derived signals (Khorasani, Shalchyan & Daliri 2019, *Front. Neurosci.*
  13:350): each channel minus its own Kalman-tracked share of the plain CAR, so an artifact that reaches
  the channels at different strengths is removed from each. The new `weightedCAR` computes the shared
  gain once and runs each channel as a scalar loop, in place (about 8 s per channel-hour at 30 kHz).
  `deriveSignals` (and `toMat`, `intan2matlab`) takes `referenceMethod="weighted"` and `wcarOptions`
  (Order, Alpha1k, DriftPerSec, Q with NaN = automatic, HighpassHz, Estimate "prior" or "posterior").
  It applies to the signals `referenceSignals` names, even with `ArtifactConfig.Reference` `"none"`,
  and is reported as `info.reference.mode` `"wcar"` with `info.reference.wcar`. `prepareReference` and
  `referenceTrace` take `Mode=`. The pipeline config, the app and the Diagram tab take it as a common
  reference for every step (next bullet). See
  [Adaptive weighted CAR](documentation/EphysDataset.md#adaptive-weighted-car).
- The adaptive weighted CAR as the common reference of every step: `Reference.Mode` (and
  `ArtifactConfig.Reference`) `"wcar"`, so artifact detection, the noise level of the artifact fill, the
  sorting `.bin`, spike detection and the viewer read the weighted-CAR referenced recording, as the derived
  signals do. Kilosort4's `do_CAR` is then set false and a SpikeInterface sorter's own common reference is
  kept out (`runKilosort`, `runSpikeInterface`, `run_si.py`; the `.bin` sidecar's `reference.mode`
  `"wcar"`, with `reference.wcar`), so the recording is referenced once. The filter runs through the
  recording, so the new `EphysDataset.prepareWCAR` works its state out once per recording (a pass over every
  channel, about 8 s per channel-hour at 30 kHz, and one before it for an automatic `Q`, the samples
  `deriveSignals` takes), keeps it every 1 s and saves it as `<Name>_wcar.mat`; `readChunkUV` and
  `readWindowUV` run the filter from the checkpoint at or before each read, padding the read by the
  high-pass's memory (23 s on each side at 0.5 Hz), and give what one run over the whole recording gives,
  to about 1e-12 of the signal (exactly with `HighpassHz` 0), whatever the chunks or workers. The streaming
  entry points call it before any chunk is read; the pipeline's artifact detection, Sorting and Spikes steps
  report its passes as their progress and log `[reference]`. `weightedCAR` takes `Rows`, `Initial`,
  `StateRows` and `Output` and returns `info.final` and `info.states`, to run a recording in pieces.
  `ArtifactConfig` gets `ReferenceWCAR` (`EphysDataset.defaultWCAR`), which `deriveSignals`' `wcarOptions`
  now go over; `applyReference` and `referenceTrace` refuse `"wcar"`. The config's `Reference` section gets
  the `WCAR_*` fields (checked by `validate` with `Mode` `"wcar"`; `EphysPipelineConfig.wcarOptions`), and
  `Signals.ReferenceMethod` and `Signals.WCAR_*` are retired: a config saved with them loads with the
  `WCAR_*` fields moved to `Reference`, and `"weighted"` is reported in `LoadWarnings`, not applied. The
  Artifacts tab's reference drop-down gets *WCAR* and the WCAR parameters (moved from the Signals tab); the
  Diagram tab draws one *Adaptive weighted CAR* box with its parameters where the common reference goes. The
  artifact cache's fingerprint takes the WCAR options only with `"wcar"`, so the other caches stay valid.
  See [Streamed (prepareWCAR)](documentation/EphysDataset.md#streamed-preparewcar).

- Figures: panels of different types, drawn for one observation, in the analysis config. A new `Figures`
  list holds figures; each is a grid (rows and columns, relative sizes, spans) of panels, each of one of
  seven types (raster, PSTH, continuous signal, heat map, unit waveforms, probe map, unit
  correlation), and each panel draws one or more layers bound to a source (sorted units, detected spikes,
  an event line, an LFP, MUA, SPIKE or AUX extract). A layer either follows the observation
  (a sorted unit, a channel or the dataset, as the figure's `observe` block says) or is fixed to the units,
  channels or line it names, so a raster flush above its PSTH above the LFP of the same unit's channel,
  with the stimulus offset marked on every raster row, is one figure drawn for one unit at a time.
  `EphysAnalysisConfig` gets `Figures`, `addFigure`, `removeFigure`, `figureIndex`, `figureIds`,
  `enabledFigures` and `figureFor`, the tables `panelTypes`, `sourceCategories` and `figureTemplates`, and
  the grid editors `placePanel`, `removePanel` (which exactly undoes an add), `movePanel` and
  `figureCells`; Validate checks figures. `figureObservations` lists the units, channels or dataset a
  figure can be drawn for and `figureSkipReason` says why a figure or one of its layers cannot be
  computed; `EphysAnalysisRunner.computeFigure` computes one observation with no graphics, reading only
  that unit's spikes or channel's column, and can be canceled; `renderFigure` draws the result on one
  tiled layout with one time axis down a stack, one legend and the plot aesthetics editor (new roles
  `eventLine`, `eventRug` and `layerNote`), each panel type through `figurePanelRegistry`. Figures run, are
  exported and appear in reports too (next bullets). See
  [Figures](documentation/EphysAnalysisConfig.md#figures).
- Figures tab in the analysis app. A new tab beside Plots designs a figure and previews it for one
  observation at a time. The figure list adds a figure from a template ("Raster over PSTH (per unit)" first,
  or one panel of a type) and removes, duplicates and reorders; the editor, in collapsible sections with
  Ctrl+1 to Ctrl+9 and Ctrl+0, sets what the figure is drawn for (a unit with its filter, a channel, or the
  dataset), the arrangement (a schematic to click a panel in, Add panel above, below, left or right of the
  selected one, spans, row heights and column widths, spacing, Remove and Move), the panel (type, title,
  group shown, its own event and window or "Same as the figure"), its layers (a source the type draws,
  following the observation or fixed, with the units, channels or event line it needs) and
  the type's options, besides the figure's event reference, epoch window and trial selection ("Use default"
  for the Alignment tab's) and appearance. Changing a panel's type keeps the options and layers both types
  share. The preview picks the dataset and the observation (< and >, Page Up and Page Down) and computes
  only that unit's spikes or that channel's column, so Auto redraws after every edit unless a preview takes
  2 s or more; it has the Plots tab's badge states and a Cancel, shares the runner with the Plots and
  Sessions previews, remembers looks from the right-click aesthetics editor with the figure, and the
  Epoch Diagram can follow the figure. New preferences `FigureAutoPreview` (on by default) and
  `FigureSectionsCollapsed`. Running, exporting and reporting figures, and the tab's own Generate button,
  are in the next bullets. See
  [Figures tab](documentation/EphysAnalysisApp.md#figures-tab).
- Figures: common options and linked panels. A figure has a `common` block (bins, measure, baseline, mask
  after the stop event, waveform inset) that every panel draws while its own `common` flag is true, the
  default, for the fields its type has (`commonFields`, `commonFieldsOf`); `figureFor` resolves the
  effective options (`panelOptions`), Validate checks the block once and a linked panel's type against the
  common baseline mode, and the pure helpers `adoptPanelOptions`, `adoptPanelAlignment` and `relinkPanels`
  link panels again. In the Figures tab a new Common options section (Ctrl+7; Panel alignment, Layers and
  Options move to Ctrl+8, Ctrl+9 and Ctrl+0, and Appearance and Looks have no key) edits the block; a
  "Common options from the figure" box in the Options header grays a linked panel's common rows, which show
  the figure's values, and unticking copies them into the panel; a panel's Panel alignment rows are locked
  to the figure's while "Same as the figure" is ticked, and unticking copies the figure's event and window
  into the panel; "Apply to all panels" (in Panel alignment and in Options) makes a panel's alignment or
  common options the figure's and links every panel, and "Re-link all panels" links them all again. The
  Behavior panel type was removed from figures (no behavior type or template, no trial source category or
  trials layer, no `yParam` and `seriesParam` layer fields); the behavior plot kind is unchanged. (The
  figure-level block was removed again: see Removed.) See
  [Copying options between panels](documentation/EphysAnalysisConfig.md#copying-options-between-panels).
- Figures in runs, exports, reports, standalone scripts and the pipeline's Analysis step. A run draws each
  enabled figure once per observation (a unit, a channel or the dataset): `EphysAnalysisRunner.run`,
  `runDataset` and `plan` take `Figures=` beside `Plots=`, both with one convention (`[]` = the enabled
  ones, `plan`'s default every one; `string.empty(1, 0)` = none; else ids), so one figure runs alone with
  `run(Figures=id, Plots=string.empty(1, 0))`. A figure is a Results row of `Kind` `"figure"` (`Message`
  `<n> observation(s)`; `skipped` with `figureSkipReason`'s reason or `no observation`), a page per
  observation exported through `newExportFigure` (a figure page is 3.5 cm tall for each row of the
  arrangement plus 2 cm) and `renderFigure`, and one report entry per figure and dataset whose pages are
  the observations, with a caption (`figureCaption`). File names come from `figureOutputName`: `{Plot}` is
  the figure's id, `{Unit}` the observation's short label (`su12`, `ch7`, `dataset`) and `{Index}` its
  number, and a pattern that names neither gets `_<Unit>` appended. Progress reads `<name>: <id> (<i>/<n>)`
  and `cancel()` stops between observations. The run record lists the `figures`. `plan` lists a figure's rows
  (`Source` `unit`, `channel` or `dataset`). The generated standalone script writes an `fspec<k>` per
  enabled figure and calls the new runner-free `figureCompute` (which `EphysAnalysisRunner.computeFigure`
  now wraps), `figureObservations`, `newExportFigure`, `renderFigure` and `exportFigure`; the pipeline's
  Analysis step runs the config's enabled figures, lists them in its dry run (`figure of <kind>`) and
  checks that figures reading sorted units have them. Validate now accepts a config whose only enabled item
  is a figure ("No plot, figure or session plot is enabled."), counts figures in the `{Plot}` warning of the
  file-name pattern, and refuses a figure id that names the same files as a plot's. The Figures tab's new
  **Generate** button runs the selected figure alone (`onGenerateFigure`, through `onRunExport`: the
  Export tab's folder and file names, no report, plots or session plots, a figure that is off drawn for
  that run only, canceled from the progress dialog or either Cancel) and fills the Export tab's results;
  the Export tab's **Plan** and **Run** count the plot runs and the figure runs ("Plan: 4 of 6 plot run(s)
  and 2 of 2 figure run(s) will draw."). See
  [Figures](documentation/EphysAnalysisConfig.md#figures) and
  [Runner](documentation/EphysAnalysis.md#runner).
- Convert a plot to a figure. `EphysAnalysisConfig.plotToFigure(cfg, plotId)` returns a figure that draws
  what a PSTH, raster, evoked potential, heat map, probe map, unit correlation or unit waveforms plot
  draws (a PSTH's raster, event marks, aux signal and waveform inset become panels and layers; the plot's
  alignment, unit filter, bins, baseline and look carry over) with the notes for what a figure cannot
  hold yet (an overlay's raster, text notes, overlays, ...); rate and tuning plots convert too (only
  behavior is refused, `EphysAnalysisConfig:NotConvertible`) and stacking, the auROC baseline, the
  modulation order and the probe layout are carried. `convertPlotToFigure` appends it under the
  id `<plot>_fig` (`_fig2`, ...). The Plots tab gets **Convert to figure** beside **Copy from...**, which
  converts the selected plots, opens the last on the Figures tab and lists the notes in the status bar;
  the Figures tab gets **Copy from...** under the figure list, which copies parts of another figure's
  settings (`figureSettingParts`, `copyFigureSettings`: Observations, Alignment, Common options,
  Arrangement and panels, Appearance, Remembered looks), keeping the figure's id, title and enabled. See
  [Converting a plot](documentation/EphysAnalysisConfig.md#converting-a-plot).
- Figures: firing rate and tuning curve panels, the waveforms probe layout, PSTH stacking and the auROC
  baseline. Two panel types join the seven (nine now): `rate` draws a unit's firing rate per trial group
  as bars with an error bar, boxes or points (`firingRate`: `measure`, `baseline` `none`, `subtract`,
  `ratio` or `zscore`, `display`, `yLim`) and `tuning` the rate against a trial parameter, a curve per
  series with error bars and an optional waveform inset (`tuningCurve`: `param`, which is the figure's
  first group-by parameter when blank, else the first numeric trial parameter with two or more values,
  `seriesParam`, `measure`, `baseline`, `yLim`, `waveform`); both may follow the observation, take a
  `"between"` window and have templates (`"rate"`, `"tuning"`). `figureSkipReason` skips a tuning panel
  with `no trial parameter X` or `no numeric trial parameter to tune over`. A waveforms panel's new
  `layout` `"probe"` draws every unit of its first layer at its place on the probe and frames the units
  of further layers (for example one following the observed unit) in red; Validate warns when the first
  layer follows the observation. A PSTH panel's new `stack` and `stackSpacing` draw one row per trial
  group, a second layer as outlines (`yLim` unused; a raster panel above stands in for a plot's
  `stackRaster`). A PSTH or heat map of spikes takes baseline `Mode` `"auroc"` with an `auroc` options
  block (`defaults("Auroc")`), also in the figure's `common` block (`commonFields` now has six fields, and
  the common baseline modes are `none`, `subtract`, `zscore`, `percent`, `ratio` and `auroc`, each type
  taking its own: a linked panel whose type does not is an error at `<figure>.<panel>.common`). Validate
  checks the auROC windows against the drawing panel's bins; a heat map's `order` gains `"modulation"`
  (auROC only) and a heat map of auROCs is drawn in the diverging colormap. `commonFieldsOf`: rate takes
  `measure` and `baseline`, tuning `measure`, `baseline` and `waveform`, PSTH and heat map also `auroc`.
  A plot's stacked PSTH and auROC drawing (`renderPSTH`) and the probe highlight (`renderWaveforms`) are
  now shared code (`drawStack`, `callMarks`, `modulationWindow`, `rowLabels`), drawn as before. In the
  Figures tab, Common options and a PSTH's or heat map's Options gain the auROC rows, a PSTH gains
  **Stack** with its spacing, a firing rate panel **Display**, a tuning curve **Parameter** and
  **series**, a unit waveforms panel **Layout**, and the heat map's **Row order** *modulation*; the
  Add-panel and template lists offer *Firing rate* and *Tuning curve*. A panel's common rows now open again once the panel is unlinked from the figure's
  Common options (they stayed grayed out). See
  [Panel types](documentation/EphysAnalysisConfig.md#panel-types),
  [Panel options](documentation/EphysAnalysisConfig.md#panel-options) and
  [Copying options between panels](documentation/EphysAnalysisConfig.md#copying-options-between-panels).
- Figures: per-trial traces, a trials-by-time heat map, a panel's own trial selection and one figure per
  trial group. A continuous panel's new `trials` option draws every epoch's trace (`"faint"`: in the
  group's color, paler and thinner, behind the mean and its band; `"only"`: the traces alone, standing for
  the groups in the legend), at most `maxTrials` of them picked evenly over their order (the result gets
  `R.data`, `R.trialEpochs` and `R.trialGroup`; the aesthetics editor a role `trialTrace`, "Trial traces").
  A heat map's new `rows` `"trials"` draws one unit's epochs as rows, every trial group at once (a layer
  that follows the observation or is fixed to one unit), binned as the PSTH counts them (`bins`, `measure`,
  `maskAfterStop`, and a `subtract`, `zscore` or `percent` baseline against each epoch's group; the auROC
  baseline is an error), sorted as a raster's rows (`rasterSort`, `rasterSortEvent`, `rasterSortOrder`,
  `rasterByGroup`), with the groups as a strip along the left edge; `order` and `group` are not used. A
  panel's new `selection` is `"default"` (the figure's) or a trial selection of its own on an aligned type:
  its own epochs and groups, colored apart, with a legend inside the panel and a title that says its
  grouping (`by Depth`, `all trials`) when it differs from the figure's. It is not matched to the figure's
  groups, does not change the shared time axis, is checked by `figureSkipReason` and Validate, and is taken
  by `adoptPanelAlignment` and cleared by `relinkPanels` (so by **Apply to all panels** and **Re-link all
  panels**). A figure's new `observe.perGroup` draws each observation once per trial group of its selection
  (Validate warns while the selection groups by nothing): `figureObservations` gains the columns `group`
  and `groupLabel` and lists a row per observation and group, `figureCompute` keeps that group's epochs
  only, the title and the caption (`one figure per trial group`) name the group and the file-name token
  `{Group}` is its label (`_<Group>` is appended when the pattern names neither `{Group}` nor `{Index}`).
  In the Figures tab, Observations gets **Per trial group** with an "N units x G trial groups" count, Panel
  alignment a **Trial selection as the figure** box with the selection rows under it, a continuous panel's
  Options a **Trials** row with **at most**, a heat map's a **Rows** row (the raster sort rows show for
  trials while **Row order** and **Group shown** hide), and the picker lists each unit's groups. The tab's
  auto-preview limit is now the app's `FigureAutoPreviewSeconds` property (2 s) so its tests no longer
  depend on machine load. `maxTrials` defaults to 100 (`Inf` still draws every epoch), the traces always
  sit under every band and mean, a heat map of trials keeps one unit (a layer that follows the observation
  through a channel is a Validate error, and one that still keeps several is skipped), its rows average
  exactly to the group's PSTH under `maskAfterStop`, and a per-group observation whose group loses every
  epoch to the panels' baselines draws with notes (`F.skip`) instead of failing. See
  [Figures](documentation/EphysAnalysisConfig.md#figures) and the
  [Figures tab](documentation/EphysAnalysisApp.md#figures-tab).
- Figures: spectral panels, three new panel types that draw Chronux analyses of the observed unit or
  fixed channels and units. *Power spectrum* (`spectrum`) overlays each layer's multitaper spectra
  (point and continuous layers, groups overlaid); *Spectrogram* (`spectrogram`) draws one channel's power
  over time from the event and frequency for one trial group on the figure's time axis, optionally against
  a baseline (`db`, `percent`, `zscore`, `ratio`); *Coherence* (`coherence`) takes exactly two layers, the
  seed then its partner (signal x signal, spikes x field, spikes x spikes, signal x spikes), with the
  phase in a strip under the magnitude (`showPhase`; `renderFigure` returns it as `extraAxes`) or, with
  `overTime`, a coherogram. Their options are `chronuxSettings`' (tapers, `fpass`, `err`, `detrend`,
  `scale`, `spikeFs`, `movingwin`, and the range time base that cuts the whole recording into segments
  clear of artifact periods instead of using the figure's epochs); they need Chronux on the path, else the
  panel is skipped with `Chronux is not on the path` and the rest of the figure draws. The Figures tab
  adds the Chronux rows to the Options section, a new coherence panel gets the observed unit and its
  channel's LFP, events layers are offered only on panels that share the time axis (no longer on firing
  rate, tuning, spectrum or coherence panels), and a blank figure previews without failing. Spectral
  panels are not in the plot converter (no plot kind draws them). See
  [Spectral panels](documentation/EphysAnalysisConfig.md#spectral-panels) and the
  [Figures tab](documentation/EphysAnalysisApp.md#figures-tab).
- Figures: session figures, a figure drawn across several datasets. A figure's new `sessions` block
  (`defaults("FigureSessions")`; `observe.datasets` and `observe.datasetKeys` moved into it as
  `sessions.datasets` and `sessions.datasetKeys`) with `enabled` draws it once across the ticked (or listed)
  datasets instead of once per dataset: one observation, a recording channel that has a unit (`match`
  `"site"`; a session with several units on it draws the first in probe order), a cell of a unit-mapping CSV
  (`"mapping"`), a channel or the dataset, is computed on every session and each panel's layers are merged
  with `combineSessions`, so `renderFigure` draws the merged figure as it draws one dataset's. The session
  plots' settings apply: a color per session, per subject (its sessions averaged) or one mean, the error
  band, each session faintly under its summary, colors by date, a figure per subject and a minimum number of
  sessions (applied per merged trial group and layer, so a group too few sessions hold is skipped);
  `trialGroups` pools the figure's trial groups (the sessions are the series), makes a figure per
  group or keeps them as line styles. Events drawn as marks, the probe layout's rings and a heat map of
  trials are skipped across sessions (with their reasons); Validate refuses a probe map, unit correlation,
  spectrum, spectrogram or coherence panel and an auROC baseline in one (`plan` and a run skip the figure),
  and checks the block's values, the mapping file, the warnings above and that its id does not name a
  session plot's files. The pipeline's dry run lists one row per session figure. New functions
  `figureSessionObservations`, `figureSessionCompute`, `figureSessionSpec` and `figureSessionSkipReason`;
  `figureCaption` takes `Sessions=`; `EphysAnalysisConfig` gets `sessionFigureIds`, `enabledSessionFigures`,
  `isSessionFigure`, `FigureSessionMatches` and `FigureSessionUnmerged` (`enabledFigures` leaves session
  figures out); `EphysAnalysisRunner` gets `sessionFigureIndices`, `sessionFigureObservations`,
  `computeSessionFigure`, `runSessionFigure`, `run(SessionFigures=)` and `plan(SessionFigures=)` (one
  `sessions: <facet>` row each). A run draws them after the session plots, in the report's *Across
  sessions* section, a page per observation in `Export.SessionsFolder` (`all_<id>_site_ch7.png`), lists
  them in the run record as `sessionFigures`, and with `Export.Data.Enabled` writes a `.mat` of its own per
  figure (`ephys-analysis-session-figure/1`); the standalone script makes the same calls. In the Figures tab
  a Sessions section holds the rows (**Pick...** for the datasets, **Browse...** and **Edit...** for the
  mapping), the Dataset drop-down is off for a session figure, a **Figure:** drop-down under the preview
  picks one of the figures of a subject or trial group, an edit leaves the preview out of date until
  **Preview**, **Generate** writes across the datasets, and **Copy from...** gets an *Across sessions*
  part. See [Session figures](documentation/EphysAnalysisConfig.md#session-figures),
  [Sessions in the Figures tab](documentation/EphysAnalysisApp.md#sessions-in-the-figures-tab) and
  [Session figure data](documentation/file-formats.md#session-figure-data-mat).
- Figures: a text note and overlays on each panel. A figure panel gets `note` (a note as a plot's, after
  `options`) and `overlays` (lines and semitransparent patches drawn on the panel's own axes, the last field;
  their `panel` is always `"all"`, set by `normalizePanel`). Validate checks them with the plots' rules at
  `<figure>.<panel>.note.<field>` and `<figure>.<panel>.overlays(<k>).<field>` (the plot rules moved into
  `checkNote` / `checkOverlays`, shared; no panel warning; an overlay name shared anywhere in the figure
  warns; a panel of unknown type still has its note checked). `renderFigure` draws a note placed below,
  above, left or right in a band of the panel's tile (the tile becomes a small tiled layout; the band is
  fitted to the text as drawn, at most half the tile; below or above it keeps the axes' left edge and width
  equal to the column's; left or right it keeps both that panel's and the panel below's time tick labels; a
  quarter-turned note reads along y) and a note at a compass point, the center or x, y in the axes; a coherence
  panel's x overlays also go on its phase strip. A note in a band is not listed in the right-click aesthetics
  editor (which now lists nested tiles at any depth in tile order), though its looks,
  the design's and the figure's rules still reach it; the note's and overlays' own looks come after the
  design's and the user's rules and before the figure's own. `h.panels(k)` gains `note` and `overlays`. The
  plot converter now carries a plot's note (below to the bottom panel, above to the top one, else the data
  panel, a note saying which for a figure of several panels) and overlays (`"raster"` to the raster panel,
  `"data"` to every panel but the raster and the aux signal's, `"all"` to every panel; one naming a panel the
  figure lacks becomes a note), where they were notes. The Figures tab gets **Text note** and **Overlays**
  sections for the selected panel (the Plots tab's rows, no key, collapsed until opened; a new or duplicated
  overlay gets a name no overlay of the figure has). See
  [Panel fields](documentation/EphysAnalysisConfig.md#panel-fields),
  [renderFigure](documentation/EphysAnalysisConfig.md#renderfigure) and
  [Converting a plot](documentation/EphysAnalysisConfig.md#converting-a-plot).
- Figures: the figure list is a tree, and a panel is dragged in the schematic. The Figures tab's list is now
  a tree under groups, **Group by** what the figures observe (per unit, per channel, per dataset; the
  default), enabled / off, or none, with a check box on every figure and group (click the box: a figure's
  enables or disables it, a group's ticks all or unticks all when all are ticked), **All**, **None** and
  **Invert** above it, and **Up** / **Down** moving a figure within its group. A figure reads
  `<id>  (<n> panels)`, with the observation kind added unless grouped by it and `(off)` unless grouped by
  status; the selected figure's group always opens. Preferences `FigureGroupBy` and `FigureGroupsCollapsed`.
  In the Arrangement section a panel can be dragged: drop it on an empty cell (its spans clipped to the grid
  with a message; a cell it would still overlap in is not shaded, and a release there says why) or near the
  middle of another panel's edge to put it above, below, left or right of that panel (it keeps its place in
  the panel order; taking it away first drops any row or column no other panel starts in, so a panel
  spanning it loses that span); Escape or a release outside cancels. The Add / Remove / Move buttons
  stay. See the [Figures tab](documentation/EphysAnalysisApp.md#figures-tab).
- Kilosort4 parameter details on the Sorting tab. Each parameter's name is a link that opens a modal
  window with its definition, function, impact, tuning and defaults (this pipeline's and Kilosort4
  4.1.7's own).
- Derived events. A new named line made from an existing one: the intervals of a line (the trial line, a
  stimulus line, or an earlier derived event) in the trials that meet conditions on the trial parameters,
  e.g. `Depth >= -6`, or `Depth < -6` and `Depth >= -10`, several combined with all (AND) or any (OR), in
  the trial-filter language (MATLAB operators and an allow-list, never `eval`). The definitions are a new
  `Behavior.DerivedEvents` list in the pipeline config, kept as typed so they can be changed later, and
  are edited in a Derived events window opened from the Trials tab (`DerivedEventsDialog`: counts on the
  loaded dataset, the trial parameters and their values, the events drawn in the Trials plot).
  `deriveEvents` makes them in the behavior step: `behavior.derivedEvents`, each line in every trial's
  `TrialEvents`, and every export (Chronux, FieldTrip, epochs, kCSD, NWB), the analysis app
  (`loadAnalysisSource`: `src.events`, `src.derivedEvents`, a **Derived from** column on the Data tab) and
  Visualize take them like recorded lines. **Include in the original dataset** (`InDataset`) also puts the
  line in the extract's events (`info.derivedEvents`; an existing extract is brought up to date without
  deriving its signals again, `EphysDataset.writeExtractEvents`) and a true / false trials column in the
  behavior file. A definition a session cannot meet is left out of it with a warning and a
  `behavior:derived` result row. `tableFilterFcn` and `respCodeBits` moved from `analysis/` to `pipeline/`,
  which both use them.
- Plots across sessions. A new `SessionPlots` list in the analysis config: each session plot names a base
  plot (its alignment, units, bins and look) and draws it over several datasets, merged into one result of
  the same kind, so every renderer and design draws it unchanged. A color per session, per subject (its
  sessions averaged) or one mean over all, with a mean ± SEM, SD or *t* 95% CI across sessions and each
  session faintly under its summary (roles `memberLine`, `sessionDivider`); a figure per subject; the
  sessions colored by date; units matched by pooling every session-unit, by recording channel (site) or by a
  unit-mapping CSV naming the same cell in each dataset (`readUnitMapping`, `writeUnitMapping`); the base
  plot's trial groups pooled, a figure per group, or kept as line styles; a minimum number of sessions per
  tile. PSTH, raster, evoked potential, firing rate, tuning, behavior, heatmap (rows are session-units) and
  unit waveforms plots. New functions `sessionTable`, `combineSessions`, `sessionResults`,
  `sessionPlotSkipReason` and `addReportSection`; `EphysAnalysisConfig` gets `addSessionPlot`,
  `removeSessionPlot`, `sessionPlotIndex`, `sessionPlotIds`, `enabledSessionPlots` and `sessionPlotFor`, and
  `Export.SessionsFolder`; Validate checks them. `EphysAnalysisRunner` computes the base plot on each dataset
  once (`ResultCache`, `CacheMaxMB` 512, `cachedPlot`, `computeSessionPlot`, `runSessionPlot`), `plan` lists
  the session plots, and `run` draws them after the datasets (rows `sessions: <label>`, figures in the
  sessions folder, an *Across sessions* section in the HTML and PDF reports (with `Report.PerDataset`, a `_sessions` report
  of their own); the standalone script gets a `Session plots` block. The analysis app gets a **Sessions** tab (the
  session plot list, an editor in collapsible sections, a dataset picker, a mapping-file editor, a preview
  over the ticked datasets with its own badge, cancelable) and the seven tabs are Data, Alignment, Plots,
  Sessions, Export, Chronux and Log. See [Across sessions](documentation/EphysAnalysis.md#across-sessions),
  [Session plots](documentation/EphysAnalysisConfig.md#session-plots) and the
  [Sessions tab](documentation/EphysAnalysisApp.md#sessions-tab).

- The organized data behind the analysis plots, for further analysis in MATLAB. `epochData` gives one
  dataset's epochs (each unit's spike times and binned counts per epoch, or the epoched signal samples),
  `sessionData` gathers a session plot's merged and per-session results and epochs into one struct,
  `writeAnalysisData` saves it as a `.mat` file (`-v7.3` or `-v7`, written atomically) and `epochLongTable`
  unrolls it to a tidy table (values, counts, spikes or signals) for R, pandas or MATLAB's grouping
  functions. A run writes one file per session plot with `Export.Data.Enabled`; the Sessions tab's **To
  workspace** puts the struct in the workspace as `sessions_<id>` and **Save .mat...** saves it, both
  under a cancelable progress dialog. See [Data export](documentation/EphysAnalysis.md#data-export) and
  the [file format](documentation/file-formats.md#session-data-mat).

- Continuous integration: GitHub Actions runs the test suites (`run_all_tests`) on Windows with MATLAB
  R2025a and the Signal Processing, Statistics and Machine Learning, and Parallel Computing toolboxes
  (`.github/workflows/matlab-tests.yml`): every suite on each push to `main`, and on a pull request the
  suites its change can reach (`.github/scripts/select_suites.py`: the changed functions, methods and
  classes and the code that uses them; none for documentation or comments only; all when the test
  runner or the CI changes). The JUnit report is kept as an artifact; **Run workflow** runs chosen
  suites. See [Tests](documentation/README.md#tests).

- More ways to draw the mean aux signal of a PSTH or raster. A plot's `aux` gets `display` (`"lines"`,
  `"stacked"`: a row per trace on one amplitude scale with a scale bar, or `"heatmap"`: an image, a row per
  trace on one color scale, group or channel colors at the rows' edge), `statistic` (`"mean"` or
  `"median"`), `transform` (`"none"` or `"rectify"`: each epoch's absolute value before the statistic),
  `errorType` (`"off"`, `"sem"`, `"std"`, `"ci95"` or `"iqr"`: its own band, no longer taken from
  `Style.ShowSEM` / `Style.ErrorType`; the bands' look is still the Style's) and `colorBy` (`"auto"`,
  `"group"`, the trial selection group's color, or `"channel"`). `evokedPotential` and `auxMean` take
  `Rectify=` and `Statistic=`, and `ErrorType="iqr"`. The Aux signals section of the analysis app gets
  **Display**, **Signal**, **Error band** and **Color by** rows; Validate checks them and the caption
  names the statistic, the transform and the band. See
  [Aux signals](documentation/EphysAnalysisConfig.md#aux-signals).

- The analysis app's Plots tab: **Preview**, **Auto** and the page buttons now sit left of the
  *Active dataset* and *Design* rows, **Preview** as one button over both rows, turning orange while
  the plot is *Out of date*. **Page Up** and **Page Down** flip the preview's pages (named in the
  buttons' tooltips), and the page label at the bottom is smaller.

- A **Chronux** tab in the analysis app: multitaper power spectra (`mtspectrumc`, with jackknife or
  theoretical error bars), spectrograms (`mtspecgramc`, normalized to a baseline), coherence between
  channels (`coherencyc`, over time `cohgramc`), spike-train spectra (`mtspectrumpt`), spike-field
  coherence (`coherencycpt`) and spike-train coherence (`coherencypt`) of the active dataset's Chronux
  file, over the epochs around the Alignment tab's event (per trial group) or over
  segments of a stretch of the recording, nothing that touches an artifact period used. When the
  dataset has no `<Name>_chronux.mat`, **Create** writes it (`exportChronux`) into its output folder,
  or into a local cache folder when that cannot be written. Compute reads only the rows and channels
  needed, can be canceled, and the result is drawn in the plot design (aesthetics editor on a
  right-click), saved as a figure or as a .mat. Scripts get the same steps: `loadChronuxExport`,
  `chronuxSettings`, `chronuxTimeBase`, `chronuxSpectrum`, `chronuxSpecgram`, `chronuxPairs`,
  `chronuxCoherence`, `chronuxSpikeTrains`, `chronuxSpikeSpectrum`, `chronuxSpikeField`,
  `chronuxUnitCoherence`, `renderChronux`.
  `exportChronux` now writes `export.layout`, the index those read a -v7.3 file's signals by.

- The aux signal's place and scale: `aux.yLim` fixes its y limits (a panel's, or over a plot the part of
  the right axis it spans), and `aux.overPosition` (`[bottom top]`, fractions of the plot's height) puts
  it where it should sit over a PSTH or raster, e.g. `[0 0.3]` for the bottom three tenths; the right
  axis is set so the signal's limits fall exactly there, with its ticks along that span only. The
  analysis app's Aux signals section gets **Y limits** and **Over, span** rows; Validate checks both and
  the caption names them.

- Error bands and bars of a chosen kind on every analysis plot that draws them: `Style.ErrorType` is
  `"sem"` (mean ± SEM, the default and the look so far), `"std"` (mean ± SD) or `"ci95"` (the 95%
  confidence interval of the mean from `Style.ErrorResamples` bootstrap resamples, percentile, `bootci`;
  a fixed stream, so a plot gives the same band each run). The compute functions make it over the
  epochs (`spikePSTH`, `evokedPotential`, `firingRate`, `tuningCurve`, `behaviorValues`, `auxMean`,
  `populationSummary` across units: `ErrorType=`, `ErrorResamples=`, result `R.err` with the band's
  `lo` and `hi`); an overlay of several units draws it across the units. Bands are patches
  (`errorPatch`) whose look is set per plot: `ErrorFaceColor`, `ErrorFaceAlpha` (NaN = opaque and paled,
  as before), `ErrorEdgeColor`, `ErrorEdgeStyle`, `ErrorEdgeWidth`; error bars (rates, tuning, behavior)
  draw the chosen error, asymmetric for a CI. Captions name the error and what it is across. The
  analysis app's Appearance section gets **Error**, **Band fill** and **Band edge** rows (the Show box
  is now **Error**). `EphysAnalysisConfig.validate` checks the fields and that `"ci95"` has the
  Statistics and Machine Learning Toolbox. See
  [Error bands](documentation/EphysAnalysisConfig.md#error-bands).

- The mean aux (accelerometer) signal on PSTH and raster plots of spikes. A plot's `aux` (`mode`
  `"channels"`: each channel's mean, or `"magnitude"`: the mean of each epoch's vector magnitude,
  sqrt(x² + y² + z²) at every sample) is cut from the AUX extract over the plot's own epochs and drawn in
  every unit's tile: in a panel `"below"` or `"above"` the unit's PSTH and raster, flush on the same time axis,
  or `"over"` the PSTH (or raster) on a right y axis. `channels` picks the AUX columns, `baseline "subtract"`
  removes each epoch's mean over `baselineWindow` from each channel first (before the magnitude), and
  `byGroup` draws a trace per trial group in its color or one over every epoch. `auxMean` computes it
  (`computePlot` keeps it as `R.aux`; standalone scripts write the calls); `evokedPotential` gets a
  `Magnitude` option for it. Epochs that leave the AUX signal or hold missing samples are dropped from the
  aux mean and the caption counts them; a dataset without an AUX extract skips the plot ("no AUX extract").
  The analysis app's plot editor has an **Aux signals** section (no Ctrl+digit key: the other sections keep
  theirs). Traces and bands are components of their own for the aesthetics editor (`auxTrace`, `auxSem`); an
  overlay on all panels reaches the aux panels too. See
  [Aux signals](documentation/EphysAnalysisConfig.md#aux-signals).

- Check boxes on the analysis app's plot tree: a plot's box is ticked while the plot is enabled
  (click the box to flip it), a group's is ticked when all its plots are and half-filled when some
  are (click it to tick or untick them all). Above the tree, **All**, **None** and **Invert** act on every plot, and a drop-down naming the plots
  selected, or the plots of a plot type, source or layout, with **Check**, **Uncheck** and **Only** (tick
  those and untick the rest). The boxes are icons on the multi-select tree, since MATLAB's check-box tree
  cannot select several nodes for the editor's edit-together.

- Every table that lists things sorts on a header click, and the tables that list datasets show their
  **Subject** and **Date** (the day recorded). The pipeline app's Run results, the Signals, Export and
  Analysis plan tables, the Copy sessions table and the analysis app's Data tab datasets table keep the click
  as the rows are filled again (the Copy sessions are reordered themselves, the datasets table sorts through a
  hidden `Idx` so ticks and clicks reach their own dataset), with right-click → **Clear sort**; the Clean up
  preview gets a Date column beside Subject, and the analysis app's plan and results tables get both.
  `subjectAndDate` gives the two columns from the name pattern and the recording's start. The tables that are
  settings to edit (probe rules, the synthetic design, the probe designer, the channel mapper) do not sort.

- Overlay graphics on analysis plots: lines and semitransparent patches drawn
  on a plot's axes in data units. A plot's `overlays` is a list of any length;
  each overlay is a vertical or horizontal line (`xline` / `yline`) or a patch
  between two x or two y values (`xregion` / `yregion`), with its own panels
  (all, the data panels, or the rasters above a PSTH's rate panels), layer (over
  or under the plot's data), name, color, opacity, line style and width, and
  a patch's fill, fill opacity and outline. The analysis app's Plot editor gets
  a collapsible **Overlays** section: a list with Add line, Add patch,
  Duplicate and Remove, and the rows of the one picked. A line crosses every
  raster row or the full height of a PSTH; the layer puts an overlay in front
  of or behind the data (`drawOverlays`, called by `renderPlot`). Each is a
  component (roles `overlayLine`, `overlayRegion`, grouped by its name) the
  right-click aesthetics editor lists; its own look wins over a design, and a
  design saved from a plot leaves overlays out. `EphysAnalysisConfig.validate`
  checks them. See [Plot overlays](documentation/EphysAnalysisConfig.md#plot-overlays).
  The Overlays section is the editor's tenth: it takes the next step of the section
  title colors and **Ctrl+0** (**Cmd+0** on a Mac) goes to it.

- Raster rows sorted by the latency of another event, e.g. the time from
  each epoch's event to the animal leaving the platform (Platform offset):
  plot option `rasterSort "event"` with `rasterSortEvent`, an event
  reference (line, edge, and optionally a sequence, `which`, scope and
  shifts). The event is found as a stop event is (the first one at or
  after the epoch's event, in its trial when it has one), but the epoch
  window and its stop are left as they are. Epochs without such an event
  sort last and the caption counts them; the y label and caption name the
  event. `eventLatency(src, E, ref)` computes the latencies (`computePlot`
  keeps them as `R.rasterSortEvent`; standalone scripts write the call).
  The analysis app's plot editor has **Sort event** and **Sort sequence**
  rows under **Sort raster by**.

- Colors and keys for the analysis app's plot editor sections. Each of the nine
  section headers (Units & channels, Event reference, Epoch window, Trial
  selection, Bins & baseline, Options, Appearance, Unit waveform, Text note) has
  a title color of its own, a step along the `turbo` map in the order of the
  sections and darkened only as far as it needs to read on the header bar.
  **Ctrl+1** to **Ctrl+9** (**Cmd** on a Mac) on the Plots tab go to the section
  of that number: they open it if it is collapsed, scroll the editor to it and
  focus its header, which names its key. For a section the selected plot does not
  show, the status bar says so.

- Copy just the files the analysis app needs to another folder, from the
  pipeline app: **File → Copy files for the analysis app...** and a toolbar
  tool open a window (`AnalysisCopyDialog`) that lists, for the ticked
  datasets, the manifest, behavior file, the chosen signals' extract files,
  detected spikes, the sorting folder's essential files (or the whole folder),
  optionally the sorted binary, and the probe file, and copies them in the
  background to `<folder>/<subject>/<session>` with a progress bar, a stop
  button and the choice of replacing, keeping or versioning what is there.
  `DatasetOutputs.analysisFiles` makes the list and `DatasetOutputs.probeFile`
  finds the probe file: the manifest names it by its path on the pipeline
  computer, so the copy puts it beside the manifest and the analysis (and a
  dataset's `ProbeFile`) uses that file when the recorded path is not there.

- Copy the files for the analysis app after a Run, from the pipeline app: a
  **Copy files for the analysis app** box on the Run tab (under Copy outputs
  to), saved in the config as the new `AnalysisCopy` section (`Enabled`, off by
  default). Once a Run that was not a dry run has finished, the datasets it
  processed are copied in the background with the settings last used in the
  copy window (`AnalysisCopyDialog.settings`: what to copy, the destination,
  what to do when the folder has files, the checksum), and the copy's progress
  shares the Run tab's last row. A dataset with an error among its results is
  left out, and one whose background sort is still going is copied when that
  sort ends (not at all if it fails). A Run is refused up front when the window
  never had a destination chosen, and the config does not validate together
  with a Copy outputs that moves the outputs. `EphysPipeline.run` does not read
  the section; the app does.

- Several plots edited at once in the analysis app. Ctrl- or Shift-click in the
  plot tree selects several plots. The editor then shows only the options every
  one of them has, with the values of the first picked, and an edit goes to all
  of them. Only the value changed is copied: each plot keeps its own values
  elsewhere, and an edit of an event, window or selection value gives each plot
  its own with that value changed. A look remembered from the preview's
  right-click editor reaches them all too. The preview draws the first plot
  only. An amber banner in the editor and an amber bar over the preview say how
  many plots are being edited. Remove and Duplicate act on every selected plot.

- A text note for every analysis plot: descriptive text beside or over the plot.
  The analysis app's Plot editor gets a **Text note** section (collapsible, like the
  others) with the words, the place (below, above, right of or left of the plot,
  which gives up a band for it; over the plot at a corner, an edge or the center;
  or at x, y), alignment, rotation, font, size, bold, italic, outline, text and
  ground colors and a TeX or as-typed interpreter. In the config it is the plot's
  `note` (`defaults("Note")`), checked by Validate once it has text. The note is
  a component of role `note`, so the right-click aesthetics editor and every
  design (which give it a font and text color) reach it.

- Cancel for the analysis app's plot preview. While a plot computes, the busy
  card has a red **Cancel** button; the compute checks for it between its steps and
  per unit, group or epoch (`EphysAnalysisRunner.PollFcn` / `checkpoint` /
  `clearCancel`; `spikePSTH`, `aurocCurves`, `evokedPotential` and `unitWaveforms`
  take an optional `Check=`), and the badge then says **Canceled**. Edits made
  meanwhile no longer start a second preview inside the first; they leave it
  Out of date. Closing the app stops a computing preview.

- A status badge under the analysis app's plot preview: a colored icon and
  a word for where the preview is (Computing, Drawing, Drawn, Out of date,
  Press Preview, Cannot draw, Failed). While it computes and draws, a card
  with a spinner sits over the last plot and the pointer is a watch; the
  spinners are animated SVG (`analysis/icons/status`), so they turn while
  MATLAB is busy. An edit that auto-preview does not redraw marks the
  preview Out of date.

- Event sequences for the analysis module: an event reference can now be a
  chain of events, e.g. *Trial offset then Trough onset* (the first Trough
  onset after each trial's end). `eventRef` gains `sequence`, a list of steps
  that must (`followedBy`) or must not (`notFollowedBy`) follow the event:
  each step has a line, an edge, the nth event, a maximum gap and an interval
  length. `alignStep` picks the event each epoch is aligned to: the last step
  (default), any step, or the line's own event, which turns the steps into
  conditions. No step looks past the next trial's onset. The epoch keeps the
  trial of the line's own event, so a CR selection keeps the CR trials that a
  Trough onset follows. Stop events and raster marks
  (`rasterEvents.sequences`, `epochEvents(..., Sequences=)`) take sequences
  too. The analysis app edits them in an *Event sequence* window (the
  Alignment tab's and the plot editor's **Sequence** and **Stop sequence**
  rows, the raster's **Mark sequences**). The events a sequence leaves out are
  counted in captions and on the Alignment tab (`nDroppedNoSequence`), and
  `eventRefLabel` names a sequence in titles, captions and legends.
- **Report an issue on GitHub...** and **Request a feature on GitHub...** in
  the analysis app's Help menu, as in the pipeline app: a dialog that
  composes the report from the session (system info, the analysis config and
  the Log tab, each optional), previews it as it will be sent and opens the
  repository's new-issue form prefilled. Nothing is filed until the form is
  submitted. The dialog, the prefilled address and the system lines moved to
  `pipeline/IssueReport.m`, which both apps now use.
- A **Unit waveforms** plot type for the analysis module (`waveforms`,
  `renderWaveforms`): each unit's mean waveform and a subsample of its spikes
  as a plot of its own, a tile per unit or each unit's waveform at its place
  on the probe map. The user picks the mean, the subsample or both, how many
  spikes, each unit's own amplitude scale or one for all (with a scale bar on
  the probe), the glyphs' size, the probe's sites and the units' names, and
  the p-p / spike-count labels. It needs no events, so it runs on any sorted
  or detected dataset (the probe layout needs its probe map).
- The analysis app's Plots tab lists the plots in a tree (`uitree`) grouped by
  plot type, with a **Group by** drop-down for source, layout, enabled / off
  or a flat list (remembered, as are the collapsed groups). The list column is
  half again as wide, the plot-kind drop-down has a row of its own, and
  **Up** / **Down** swap a plot with its neighbor in its group.
- A toolbar in the analysis app, under the menu bar: New, Open and Save
  config; Scan for datasets and Preview the selected plot; Validate config,
  Plan, Run and Cancel run; open the last run's report and figure folder;
  Open pipeline app; Help for this tab. Each tool calls the same method as
  its menu item or tab button, and its tooltip names the menu item's
  shortcut (Ctrl+N, Ctrl+O, Ctrl+S; Cmd on a Mac). Preview shows the Plots
  tab, and Validate, Plan and Run the Export tab, before they act. The run
  and results tools turn on and off with the Export tab's buttons
  (`buildToolbar`; icons in `analysis/icons/toolbar`).
- Plot designs (`PlotDesign`): whole looks for every analysis plot -- the
  ground behind it, the group colors, the heat maps' colors, and
  aesthetics rules for its axes, ticks, fonts, titles, axis labels,
  legends, color bars, lines and marks. Built in: **Tufte** (Edward
  Tufte's data-ink: an off-white page, serif type, no box or grid, gray
  data and muted color), **Journal** (print-ready, color-blind safe),
  **Night** (dark), **Talk** (big type, thick lines) and **Gray panel**
  (the ggplot2 look). Picking one -- the analysis app's **Design** list
  and menu, any plot's right-click **Design** submenu, or
  `PlotDesign.use` -- redraws every plot on screen at once, and runs draw
  their figures in it. **Save look as design...** keeps a plot's look
  (every property of every component, its ground and group colors) as a
  JSON design of your own; designs can be imported, deleted and kept in a
  shared folder. A design is a preference, drawn under your rules and the
  plot's own, so those still win. `renderPlot` takes `Design=`.
- The aesthetics editor sets an axes' tick length, and a legend's or
  color bar's font.

- A behavior plot kind (`behavior`): a per-trial value against a trial
  parameter, e.g. RespLatency by Depth, one series per value of another
  parameter (`param`, `seriesParam`). The value (`yParam`) is a numeric
  trial parameter or `"stop"`, each epoch's stop-event latency in ms (the
  first Trough onset after RespWindow onset, say). Layouts: points (each
  epoch's value, jitter optional, with the mean +/- SEM), line (mean +/-
  SEM), box (`boxchart`), swarm (`swarmchart`) and violin (`violinplot`,
  MATLAB R2024b or later); the x values evenly spaced or at their values
  (`xScale`). Epochs without a value (misses) are left out and counted in
  the caption. `behaviorValues` computes it, `renderBehavior` draws it.
- Events shifted by a trial parameter: an event reference's `offsetParam`
  (and `offsetParamUnit`, ms or s) adds each trial's value of the
  parameter to its event, so plots can be aligned to the response
  (RespWindow onset + RespLatency); events whose trial has no value are
  left out and counted (`nDroppedNoValue`). A stop event takes it too, so
  a stimulus-aligned raster can mark each response and sort by its
  latency. The app's Alignment controls have **Shift by** and **Stop
  shift by**.
- Raster rows: the sort's direction (`rasterSortOrder`, ascending or
  descending; missing values stay last), rows by group first or every
  epoch sorted as one block (`rasterByGroup`), and marks on each row at
  the onsets and / or offsets of digital lines inside its epoch, every one
  of them (several beam crossings in a trial get several marks;
  `rasterEvents`: lines, edge, window or trial scope, marker, size,
  color; `epochEvents`). The marks are named per line and edge for the
  aesthetics editor and listed in the raster's legend. The plot editor
  has controls for all of them.

- A toolbar in the preprocessing app, under the menu bar: New, Open and
  Save config; Validate config, Plan, Run pipeline, Dry run and Cancel run;
  View manifest; Open analysis app and Channel mapper; Help for this tab.
  Each tool calls the same method as its menu item, and its tooltip names
  the item's shortcut (Ctrl+N, Ctrl+O, Ctrl+S, Ctrl+R; Cmd on a Mac). Run
  pipeline, Dry run and Cancel run turn on and off with the Run tab's
  buttons (`buildToolbar`; icons in `pipeline/icons/toolbar`).
- Copying the pipeline's outputs elsewhere: the config's `Transfer`
  section, the Run tab's **Copy outputs to**. A Run copies, or moves, each
  dataset's outputs to `<folder>/<subject>/<session>` (its recording folder
  below the project root), each one as soon as its step has written it
  (`When = "step"`) or all of them once the Run is over (`"run"`). When the
  dataset's folder is already there, `IfExists` puts the Run's copies in a
  new version folder `<session>_v2` (the default), overwrites the files
  there, or skips them. The copying runs outside MATLAB in the Copy tab's
  engine (robocopy), with size or SHA-256 checks, so the Run never waits for
  it: the Run tab's last row shows its progress (rate, time left, the batch
  in flight) with **Stop copying...**, and each dataset has a `transfer`
  result row and a plan row. A move removes the outputs here only once the
  Run is over, keeps the manifest, and records a moved sort folder as the
  dataset's sorting folder. A background sort is copied once it has
  finished. `OutputTransfer` is the transfer on its own;
  `EphysPipeline.transferOutputs` copies a script's step results, and both
  generated scripts copy too. The Diagram tab's data-flow overview draws it
  as Copy outputs, under every file it reads. A version folder reads as its
  dataset again: `EphysProject` over a copy, and `DatasetOutputs(folder)`,
  name the dataset of `<session>_v2` `<session>`
  (`EphysProject.outputFolderName`).
- `EphysProject(root)` reads a root of pipeline outputs without the
  recordings, such as a backup of an `OutputRoot`. When no recording is
  found, each folder laid out as `<OutputRoot>/<Name>` becomes a dataset,
  with a warning (`EphysProject:OutputsOnly`;
  `EphysProject.findOutputFolders`). `refresh()` takes their rate, channels
  and duration from the extract's `info` and writes nothing there.
  `outputs()` reads their files, and their `OutputDir` stays their own
  folder. `EphysDataset.hasRecording()` tells these datasets apart. An
  analysis config's `"project"` source can point at such a copy.
- **Hide unused** on the Diagram tab (`DiagramHideUnused` preference;
  `HideUnused=true` on `PipelineDiagram.overview` / `detail`): leaves out the
  disabled steps, stages and files switched off, arrows not read and inputs
  nothing reads. In the data-flow overview the Spikes step now sits in the
  same row as Signals and Sorting.
- SpikeInterface sorters as an alternative to Kilosort4, on the Sorting tab.
  **Sorter** (`Sorting.Sorter`) is Kilosort4 by default, run as before with
  the same settings and controls, or a sorter SpikeInterface runs
  (`spykingcircus2`, `tridesclous2`, `lupin`, `simple`, and any other
  installed in the Python env). **Find SpikeInterface sorters** lists the
  installed ones (`EphysDataset.spikeInterfaceSorters`, `si_sorters.py`).
  A chosen sorter's parameters replace the Kilosort4 parameters on the tab:
  JSON seeded with SpikeInterface's defaults, beside each parameter's
  description, kept per sorter in `Sorting.SIParams`.
  `EphysDataset.runSpikeInterface` (`run_si.py`) sorts the same `.bin`
  (artifact periods erased, the common reference applied once: the sorter's
  own is kept out when the `.bin` carries one). It writes phy files in
  Kilosort4's layout to `<output folder>/si_<sorter>/`, each unit labeled
  good or mua by the good-unit criteria (`cluster_SILabel.tsv`), so phy,
  the Review tab, the QC report, the exports and the analysis read it
  unchanged. Background runs, the queue, **Stop runs**, Clean up, the
  generated scripts and the diagrams cover it. A dataset's sorted output
  (`sortingResultsDir`) follows the config's sorter (`EphysDataset.Sorter`,
  `sortRunDir`).

- The Review tab reads any of a dataset's sorts. **Sort** lists them: the
  dataset's own first (its pinned folder, else its sorter's run folder),
  marked **in use**, then every other folder under its output folder that
  holds a sort (`kilosort4`, `si_<sorter>`, a sort sweep's variants), each
  with its sorter and number of units. Choosing one loads it and changes
  nothing the other steps read; a folder from **Browse...** / **Load** is
  added as **other**. **Use this sort** makes the sort shown the dataset's
  sorted output, as the Sorting tab's **Use folder...** does (the run
  folder of the config's sorter goes back to auto). The summary names the
  sorter and where the unit groups come from (phy, Kilosort4's `KSLabel`,
  or `SILabel`).

- An Analysis step at the end of the pipeline: it loads an analysis config
  saved in the analysis app (`Analysis.ConfigFile`, read when the step
  runs) and runs it with `EphysAnalysisRunner` over the pipeline's selected
  datasets instead of the config's own source. It writes the figure files
  (`Analysis.Figures`) and the HTML / PDF report (`Analysis.Report`) where
  the analysis config's Export and Report settings say
  (`EphysPipeline.runAnalysis`). Plan, dry run, cancel, progress, run
  records and both generated scripts cover it; the standalone script
  carries the analysis config as JSON. Validation checks the analysis
  config too, and its errors stop the run. The pipeline app has a new
  **Analysis** tab after Export: the config file, its summary and plots,
  **Open in the analysis app**, the figure and report switches, the plan,
  **Run this step**, **Open report** and **Open figures folder**. The step
  is also on the Run tab's checklist, the run diagram and both Diagram
  views. `EphysAnalysisRunner` gained `SearchDirs` (the pipeline's step
  output folders), and its `ProgressFcn` fraction now covers the whole run
  rather than restarting at each dataset.
- Visualize: views wider than one full-rate read, up to the whole
  recording, are drawn from the signal's min / max envelope
  (`EphysTraceEnvelope`), and the overview strip shows the signal itself.
  The envelope is built once in the background (the recording and the
  `.bin` on `backgroundPool` threads, derived signals on a timer; the status
  line shows progress), cached as `<Name>_envelope_<what>.dat` next to the
  outputs, fingerprinted on the files, the reference and the block sizes,
  and built again when stale. `EphysTraceSource.stamp` / `appliedReference`
  / `threadSafe`.
- `EphysPipeline.cachedDetection(cfg, d)`: whether `<Name>_artifacts.json`
  holds what the current settings detect, without detecting or writing
  (`artifactFingerprint`, `detectionConfig`, `artifactsFile`). Visualize
  says whether the last run's periods were found "with the current
  settings" or "with other settings".
- Clean up removes the Visualize tab's envelope caches: kind `"envelope"` of
  `planLocalCleanup`, ticked by default in the free-space group. A build's
  `.partial` file goes only once it is an hour old.
- Clean up's **Move to a folder** checks the folder at Preview: an **In the
  folder** column and the summary line say which files are already there
  (size and date), and **If a file is already there** chooses what the move
  does with them: skip (the default, as before), overwrite (the file there
  is renamed aside and deleted only once the new one is in place), or keep
  both by moving that dataset's files to a new version folder
  `<dataset key>_v2` (`_v3`, ...), so a sort run folder stays whole. The
  check is redone when the folder, the method or the choice changes and
  before the confirmation. `cleanupMoveTargets` is the preview;
  `runLocalCleanup` takes `IfExists=` and reports `Replaced`. The clean-up
  record is now schema `ephys-local-cleanup/3`, with each run's `ifExists`
  and each file's `replaced`.
- Pipeline app: closing with Kilosort4 runs queued offers **Keep the queue
  for next time**, **Drop the queue** or **Cancel**. A kept queue is stored
  per project root (preference `KeptSortingQueue`) and offered back once
  that root is scanned; the runs that cannot go back are listed with why.
  Background runs still going at close are followed again at the next
  launch (`KeptSortingRuns`); one with no process left is logged and left
  out. `EphysDataset.sortRunProcesses(statusFiles)` counts each run's
  processes.
- `EphysPipelineConfig.validate` warns (`sorting`, `MaxConcurrent`) when two
  or more background Kilosort4 runs at once all go on one GPU, which on a
  small card can run out of memory.
- `aurocCall`: the auROC call (95% CI, fixed, test) over every unit and
  group given; `aurocCurves(..., Call=false)` measures without calling, so
  results can be stacked and called together.
- `populationAnalysis` computes each unit's auROC (`Auroc`, per
  `AurocGroupBy` group) and calls every unit x group curve of the family in
  one `aurocCall`, pooling the 95% CI cutoff as Macedo-Lima et al. (2024)
  pooled their units' trial-type curves: `P.auroc` (curves, calls per unit
  and group, each family's cutoff), the unit's call and peak in `P.units`,
  auROC counts and an `auroc` group key in `populationSummary`, the shares
  and cutoff in the fractions figure, `population_auroc.csv` and the cutoff
  in `population.json`.
- `aurocCurves` checked against the paper's published OFC data (DRUM,
  doi:10.13016/qzzx-zfuh): given the spikes and spout-withdrawal times the
  lab used, it reproduces the published curves, apart from the windows the
  lab's code bins with 11 or 9 bins and spikes exactly on a bin edge. With
  the cutoff pooled over all 533 units, the calls match the paper's: 1050 of
  1050 before withdrawal, 1579 of 1583 after (the 4 differed because silent
  units entered the pool; they now stay out of it).
- `reportPdfPage`: a drawn page as the PDF report holds it.
- `IntanReader.notchFilter`: Intan's software notch for RHD2000 files before
  version 3.0 as one `filter` call (Intan's per-sample loop to rounding,
  several times faster), with `IntanReader.notchLeadIn`.
- `EphysPipelineConfig.numberText`: a number as the shortest text that reads
  back as the same double (replaces the pipeline app's private copy).
- `test_ClassdefDeclarations`: every classdef method declaration in
  `pipeline/` and `analysis/` against its method file's inputs and outputs.
- `tools/wiki/gen_pages.py` unwraps wiki-only comments (`<!-- wiki: ... -->`
  or a `<!-- wiki` block), so `documentation/` holds the wiki's screenshots
  too. Every tab page of the pipeline app, the Synthetic tab's new page, the
  analysis pages, File formats, Python drivers, Kilosort4 notes and
  Installation are now generated from `documentation/`; a test checks that
  every page and anchor the apps' Help opens exists.

- Unit waveforms on the analysis plots: a raster, or a PSTH or tuning
  grid, of spikes can draw each unit's mean waveform, a subsample of its
  spikes, or both, as a box in the unit's tile (the plot's `waveform`:
  `mode`, `location` -- north-east by default -- `box` for the axis box,
  `scale`, `maxSpikes`). `unitWaveforms` reads them: sorted units' spikes
  cut from the sorted `.bin` (`DatasetOutputs.readWaveforms`, cached; the
  template when the `.bin` is gone), detections' saved waveforms. The
  app's plot editor has a *Unit waveform* section.
- auROC in the analysis module (Cohen et al. 2012; Macedo-Lima, Hamlette &
  Caras 2024): `aurocCurves` measures each unit's firing in windows along
  the epoch against its baseline, from the trial-averaged PSTH's bins (the
  paper's, matching the Caras lab's `calculate_auROC.py`) or from each
  epoch's counts, in tiled or sliding windows, and calls the units
  modulated up or down by the paper's 95% CI cutoff, a fixed threshold or a
  per-unit test (bootstrap, ranksum or circular-shift shuffle, adjusted
  with `pAdjust`). PSTH and spike-heatmap plots take it as baseline mode
  `"auroc"` (the plot's `auroc` settings): curves on a 0-1 scale, each
  unit's call marked, heatmap rows in modulation order, optionally only
  the modulated units drawn. The unit selection's response test gains
  `"auroc"`. The app's plot editor shows their settings. Test suite
  `test_Auroc`.

- `LICENSE` (MIT), `THIRD_PARTY_NOTICES.md`, `CITATION.cff`, this changelog
  and a `VERSION` file that `ephysVersion` reads; `ephysVersion` also reports
  `git describe` (`Describe`).
- `run_all_tests` runs every suite through `matlab.unittest`: JUnit XML
  (`JUnit=`), HTML or Cobertura coverage (`Coverage=` / `CoverageXML=`),
  selection by name or tag. Function-style suites run as `LegacySuiteTest`,
  each failed check reported on its own; `findTestSuites` lists the suites.
- `AppPrefs` and `AppPrefsFixture`: the apps keep their preferences through
  one store, which tests and screenshot runs point at a temporary file.
- Test suites `test_AppPrefs` and `test_RepositoryMetadata`.
- Warnings, each with an identifier, wherever a read or parse failure used to
  fall back silently and the fallback changes a result: the `.bin` sidecar
  and an unread phy label table (Kilosort's labels then replace phy's), an
  unreadable probe, the manifest's session details, an unparseable name
  pattern in the probe rules, recording start times (binary, Intan, Open
  Ephys NWB), NWB channel types, electrodes and TTL series, Epsych2 start
  times, unreadable output files, the analysis report's unit tables, a copy
  cancel that could not be signalled and a clean-up that could not list a
  dataset's outputs. They are listed in `documentation/README.md`; suite
  `test_DataPathWarnings` checks six of them.
- Provenance in every output: the release, git commit, branch, uncommitted
  changes and `git describe`, MATLAB, host, user and time (`ephysProvenance`),
  plus the run id and the full pipeline config when `EphysPipeline` writes it.
  `.mat` outputs keep it in `conversion.provenance` / `export.provenance`; the
  `.bin` sidecar, `settings.json` and the kCSD `meta` as JSON. Every writer
  takes `Provenance=`.
- Run records: `EphysPipeline.run` writes
  `<OutputRoot or Root>/pipeline_runs/<runId>_<name>.json` (steps, datasets,
  config, code, machine, Results) whether the run finishes, is canceled or
  fails; `EphysAnalysisRunner.run` writes `analysis_runs/<runId>_<name>.json`
  in the report folder. Analysis reports show the code version.
- `stringifyNonFinite` (moved out of `writeJsonFile`), `provenanceForJson`;
  suite `test_Provenance`.
- Recording-wide spike-detection thresholds: `detectSpikes(ThresholdScope=
  "recording")` measures each channel's noise over the whole recording in a
  first pass (the same chunks, context, artifact erasing and band-pass as
  detection; every sample counted once) and detects every chunk against it.
  `std` / `rms` are exact; `mad` / `percentile` come from a 0.05 µV histogram
  over ±2000 µV (`info.noiseEstimate` records how; a statistic beyond the
  range or below one bin leaves the channel degenerate, with a warning).
  `Spikes.ThresholdScope` in the config (default `"chunk"`, the behavior so
  far) and **Noise measured over** on the Spikes tab; the spikes file records
  the scope (`detected.info.thresholdScope`). Suite `test_ThresholdScope`.
- Unit quality metrics with SpikeInterface's definitions (`unitQualityMetrics`:
  firing rate, ISI violations ratio and count, presence ratio, amplitude
  cutoff, SNR, drift), every one checked against SpikeInterface's own values
  (`tools/golden/unit_quality_golden.py`, `pipeline/testdata/`).
  `EphysDataset.unitQuality` / `unitQualityOf` / `readSortedUnits(Quality=true)`
  add them to the units, over the span Kilosort4 sorted, cached per sort in
  `quality_metrics.json`. Good-unit criteria (`unitQualityCriteria`,
  `unitQualityPass`; the Allen Institute's thresholds by default) in the
  pipeline config (`Sorting.Quality`) and the analysis config
  (`UnitSelection.quality`, applied by `selectUnits`). `unitTable` columns;
  the exporters, the Export step and the standalone pipeline script carry the
  metrics (`UnitQuality`, `Export.UnitQuality`, on by default; a failure is a
  warning). Review tab: QC, ISIv, Pres, Cutoff and SNR
  columns, editable criteria, **QC report** (`writeUnitQualityReport`, one HTML
  page per sort). `sortSweep` sorts a dataset with several Kilosort4 settings
  on the same `.bin` and compares the sorts. Suite `test_UnitQuality`.
- `benchmarkDetection`: spike and artifact detection scored against synthetic
  ground truth (per-unit recall with its SNR; per-channel precision, duplicate
  and noise-crossing rates; artifact recall, coverage, edge errors and false
  intervals), with a JSON report. Suite `test_DetectionBenchmark` (tag
  `Benchmark`) holds the default settings to regression floors.
- `Project.SaveScript` (on by default; Project tab, **Save the pipeline script
  on each run**): each pipeline run saves the config's standalone script as
  `<Root>/pipeline_<name>.m` before its first step, replacing the one the
  previous run saved and naming the run in its header; a file of that name
  that no run saved is never overwritten. The run record names the script
  (`script`). `EphysPipeline.writeScript`, `EphysPipeline.ScriptFile`,
  `EphysPipelineScript.standalone(Note=)`; suite `test_PipelineScriptSave`.
- Response statistics in the analysis module: `responseStats` tests every
  unit with the Statistics and Machine Learning Toolbox. `signrank` compares
  the response window's rate with the baseline's over the epochs (two-sided;
  the direction comes from the one-sided tests). With a trial parameter,
  `kruskalwallis` tests the rates across its levels, giving `bestLevel`.
  The p values are adjusted over the units by `pAdjust` (Benjamini-Hochberg,
  Holm, Bonferroni; R's `p.adjust` results, checked against statsmodels:
  `tools/golden/padjust_golden.py`). `UnitSelection.response` (off by
  default) keeps only the units that respond: `selectUnits(..., Ref=,
  Selection=)` with the plot's events, plus the analysis app's
  **Responsive only** row. Suite `test_ResponseStats`.
- Population analysis: `populationAnalysis` puts every unit of an analysis
  config's datasets into one table. It holds each unit's PSTH, rates, the
  response and tuning tests (one correction over every unit or per
  dataset), per-level rates, PSTH peak and latency, and the quality
  metrics. `populationSummary` groups the units by subject, dataset, class,
  shank, depth bin or test outcome: counts, shares responsive and tuned,
  rates, latencies, and mean PSTHs and tuning curves. `renderPopulation`
  draws the PSTH, share, tuning and depth figures. `writePopulation`
  writes the CSV tables, the figures and a JSON record with provenance.
  `responseEpochs`; `responseStats(Tests=false)` gives the rates and
  per-level rates without the toolbox. Suite `test_PopulationAnalysis`.
- NWB 2 export: `EphysDataset.exportNWB` and the Export step's `nwb`
  format write `<Name>.nwb`. It holds electrodes on the probe, LFP / MUA /
  SPIKE (float32 µV with conversion 1e-6), AUX, the sorted units with
  their quality metrics, the paired trials, each digital line's pulses,
  the erased artifact periods as `invalid_times`, and the session,
  subject and provenance. Trial and pulse times are moved to the
  continuous clock. MATLAB stages the data (`stage.json`, `stage.npz`, one
  `.npy` per signal), and `nwb_export.py` writes the file with pynwb and
  checks it with nwbinspector. Findings of importance CRITICAL and above
  warn, and all of them go to `<Name>_nwbinspector.json`.
  `Export.NWB` holds the metadata (nothing is made up when it is left
  blank) and the Python; it is validated, and the Export tab edits it.
  `DatasetOutputs` finds the file (`nwb` kind, `NWBFile`, `NWB`). Suite
  `test_NWBExport`.
- `platformSupport`: the table of the features that depend on the operating
  system (`documentation/platforms.md`). The Windows-only pieces (copying,
  scheduled copies, the Recycle Bin, the resource monitor) refuse other
  platforms through it, with one kind of message naming what they use and
  the alternative; each keeps its own error identifier. On macOS and Linux
  the resource monitor now says it needs Windows instead of failing to
  launch. `openInSystem` opens a folder or file the platform's way (winopen,
  open, xdg-open). The seven places in the apps that open one now call it.
  Off Windows they had used four different fallbacks, and one ran macOS's
  `open` on Linux too. Suite `test_PlatformSupport`.
- Tables keep their sort: a header click in the preprocessing app's Project,
  Trials, Review units, Clean up and Artifacts Selection tables is kept when
  the app fills the table again (another dataset, a reload, an edit, a new
  preview) and in the next session (preference `TableSorts`); right-click →
  **Clear sort** returns to the app's own order. Rows keep their link to
  their dataset, unit, file or trial in any order, and the Clean up table's
  map from a row to the file it removes follows the sort. `TableSort`;
  suite `test_TableSort`.
- `CLAUDE.md`: standing instructions for Claude Code in this repository
  (which MATLAB toolboxes to use, and when to ask first).
- Rasters can sort each group's epochs by something other than trial
  order: plot option `rasterSort` (psth and raster; **Sort raster by** in
  the analysis app) takes `"stop"` (the stop event's latency) or a trial
  parameter, which `computePlot` copies onto the epochs. `renderRaster` and
  `renderPSTH` take `SortBy=`; the y label and the caption name the order.
- Plot aesthetics: right-click any part of an analysis plot (the app's
  preview, or any visible figure `renderPlot` draws into) and pick **Edit
  aesthetics...**. A modal window (`PlotAestheticsDialog`) lists every
  component drawn and edits colors, line styles and widths, markers,
  opacity, fonts, axes, legends and colormaps, with each change shown at
  once. A change goes to this component, the same one in every tile, every
  group of its role, or the rows ticked. **Reset**, **Cancel** and **OK**.
  **Remember for future plots** saves the changes as rules (role, group,
  property, value) with the plot (new plot field `aesthetics`, in the
  config) or for every plot of the kind (preferences, group
  `PlotAesthetics`). `renderPlot` applies the user's rules, then the
  plot's, after drawing; new options `UserAesthetics`, `Editable` and
  `OnRemember`. The renderers name everything they draw (`tagPart`).
  `PlotAesthetics`; suite `test_PlotAesthetics`. The script generator's
  `literal` writes struct arrays.
- Stacked PSTHs can draw each group's raster in its own row, just above its PSTH, instead of one raster
  panel above the stack: plot field `stackRaster` (`renderPSTH` option `StackRaster`), the plot editor's
  **Raster in each row, above its PSTH**. Its ticks can be one height in every row (`stackRasterEqual`) and
  each row can show at most a set number of trials, picked evenly over its sort order (`stackRasterTrials`;
  editor row **Row rasters**).
- The analysis app's plot list has **Copy from...**: another plot's settings onto the selected plots, of any
  plot type (a PSTH's units, alignment, bins and look onto a raster, say), part by part -- one box per editor
  section and the remembered looks, only the parts the two types share. Each plot keeps its id, type, title
  and enabled, and a source, epoch window mode or baseline mode its type does not take. New functions
  `copyPlotSettings` and `plotSettingParts`; suite `test_copyPlotSettings`.
- Event traces: a new figure panel type, `eventTrace` ("Event traces"), draws digital or derived lines as a
  logic analyzer shows them, on the figure's time axis, so it stacks flush above a raster or a PSTH. Each
  events layer is one line in a row of its own, named on the y axis; each interval runs from its onset to its
  offset, clipped at the window's edges. Options: `display` (`"bars"`: solid bars; `"line"`: a logic level that
  rises at each onset and falls at its offset), `trials` (`"overlay"`, the default: every epoch in the line's
  row, translucent, so the timing's spread shows; `"rows"`: a sub-row per epoch, in the raster's group order,
  with `groupBands`), `colorBy` (`"layer"`: the layer's color, else a palette color per line; `"group"`: the
  trial groups' colors, in the legend), `height`, `alpha`, `edgeColor`, `edgeWidth`, `lineWidth`,
  `lineStyle`, `showBaseline` with `baselineColor`, `baselineStyle` and `baselineWidth` (through the bars'
  middle, or at the level's low line) and `rowSpacing`. The parts are the aesthetics roles `eventBar`,
  `eventLevel`, `eventBaseline` and `eventGroupBand`. Its layers are events layers only (Validate refuses
  others; `categoryOf` gives `""`) and a line whose intervals have no offset after their onset is skipped with
  the reason. New template
  `"eventTrace"`, Figures tab Options rows for it, the private `computeEventTracePanel`,
  `drawEventTracePanel` and `epochIntervals`. See [Event traces](documentation/EphysAnalysisConfig.md#event-traces).
- Event traces: `trials "rows"` sorts its sub-rows as a raster (and a heat map of trials) sorts its rows,
  with the raster's options `rasterSort` (`""`, `"stop"`, `"event"` or a trial parameter), `rasterSortEvent`,
  `rasterSortOrder` and `rasterByGroup` (the defaults keep the order by group, then time), validated as the
  raster's and offered by the raster's **Sort rows by** rows in the editor (grayed out while overlaid); the
  order is the private `figEpochOrder`, now shared with `figTrialMatrix`, and the group bands follow each
  run of a group's sub-rows. In bars, `minWidth` (points, default 1; **Narrowest bar**) gives a bar drawn
  narrower than that, a zero-length interval among longer ones too (`epochIntervals` now keeps those), a
  tick that wide through its middle in its color and opacity (aesthetics role `eventTick`), so it shows at
  any zoom and in SVG / PDF / PNG exports. A session figure now holds an event-trace panel
  (`FigureSessionUnmerged` drops `eventTrace`): `combineSessions` concatenates every session's intervals and
  epochs as it does a raster's, so `"overlay"` overlays them all and `"rows"` gives each its sub-row, the
  series (sessions, subjects or all) as the panel's groups.
- Events layers can be drawn as a span (`eventsAs "span"`, Layers **Draw as** *a line from onset to offset*):
  on a raster each row gets a line from each interval's onset to its offset, clipped to the window; on a PSTH,
  continuous signal, heat map or spectrogram panel each trial group gets a line from the median onset to the
  median offset, near the top. Its look is the layer's EventMark `color` and the new `spanStyle`,
  `spanWidth` and `spanAlpha` (Layers row **Span line**); role `eventSpan`. See
  [Spans](documentation/EphysAnalysisConfig.md#raster-event-marks).

- Figures: a panel can be smaller than its cell, and the gaps between panels can be set one by one. A
  panel's new `size` (`[width height]`, its share of its cell, default `[1 1]`) with `align` (left, center,
  right) and `valign` (top, middle, bottom) sizes one panel apart from the others of its row or column
  (the Figures tab's Arrangement rows **Panel size**, % of the cell, and **Align in cell**). `grid.spacing`
  takes `"custom"`: `grid.gapUnits` (`"px"`, or `"%"` of the mean row's plot height / column's plot width,
  so a figure keeps its look at any size), one gap each way (`grid.rowGap`, `grid.colGap`) and, to set gaps
  apart, the lists `grid.rowGaps` (between rows i and i + 1) and `grid.colGaps`; `placePanel` and
  `removePanel` keep the lists sized to the grid (Remove still undoes Add). A gap is the clear space
  between neighboring panels' labels, so labels never collide and 0 is flush. The Arrangement's
  **Spacing...** opens the new Panel spacing window (`private/figureSpacingDialog`): a preset or custom,
  px or %, the one gap between rows and between columns, a table of every gap, Apply / OK / Cancel. The
  schematic draws each panel at its size and alignment and the gaps in proportion. Validate checks the
  new fields; `EphysAnalysisConfig.GridSpacings`, `GridSpacingPx`, `GridGapUnits`, `PanelAligns` and
  `PanelVAligns` list their values. See [grid](documentation/EphysAnalysisConfig.md#figure-grid-and-observe-fields)
  and [the Spacing window](documentation/EphysAnalysisApp.md#figures-tab).
- The analysis app's Dataset drop-downs (Alignment and Figures tabs) name each dataset with
  what it holds of spikes: *subj1_day1  (14 units)* once its sorted units have been counted (the first
  time it is opened in a session, from the units its Data tab reads, so no share is walked for them;
  until then the name alone), *(detected only)* or *(no sorting)*. The Figures tab's Observation
  drop-down ends a sorted unit's label in its number of spikes (*su12  ch 7  -320 µm  (5,210 spikes)*)
  and a detection channel's in its detections; the figure's pick is still remembered by the label
  without the count. New private `refreshDatasetLabels` and app property `DatasetUnitCounts`. See
  [the preview's controls](documentation/EphysAnalysisApp.md#figures-tab).
- **Favorites**: star (on / off) a dataset, a channel or a sorted unit to find it again. The stars are kept
  beside the data, in `<Name>_favorites.json` in the dataset's output folder, so they travel with it to the
  lab's share, another PC or another user; Scan reads them and each toggle writes at once. In the analysis
  app: a **★** column in the Data tab's datasets table, a **☆** toggle beside the Dataset drop-downs
  (Alignment and Figures tabs) and one beside the Figures tab's Observation drop-down, which stars the unit,
  channel (a detection channel is starred as its channel) or dataset previewed; starred items start with
  **★** in those drop-downs. A **Favorites** drop-down on the Alignment and Figures tabs lists every star of
  the scanned datasets, with a filter field that narrows it as you type; picking an entry makes its dataset
  active and previews the unit or channel when the selected figure observes that kind. A unit's star is
  recorded with its sort (the sorting folder and the size of its `spike_times.npy`), so a new sort shows
  none of the old stars rather than moving them to other units. A read-only output folder leaves the star
  off and says why in the status bar. Scripts use the new `DatasetFavorites` class. See
  [Favorites](documentation/EphysAnalysisApp.md#favorites),
  [the script API](documentation/EphysAnalysis.md#favorites-stars) and
  [the file](documentation/file-formats.md#favorites-name_favoritesjson).
- Time left for long operations, in the same words in both apps (*about 40 s left*, *about 3 min left*,
  *about 1 h 20 min left*), from the new `ProgressClock` (pipeline/): the time per fraction so far, shown
  once 1% is done and 5 s have passed, smoothed so it counts down steadily. The pipeline app's Run tab says,
  beside the step's message, the step's time left and the run's elapsed time (*about 3 min left in this
  step, then 2 more steps · 12 min elapsed*; on the run's last step, *about 3 min left in the run*). The
  analysis app's run dialog (**Run**, and the Figures tab's **Generate**) adds it to its message. The
  pipeline app's **Detect / Preview** (Artifacts tab), **Refresh metadata**, the trials prefetch, **Clean
  up** and the Review tab's **QC report** (now counting the good units' waveforms instead of an
  indeterminate bar) say it too.
- With the weighted CAR (Reference WCAR) the app no longer waits silently while the state is worked out:
  **Detect / Preview** and the Visualize tab (*As the pipeline*) work it out first under their dialog,
  which says the window and the time left (*Weighted CAR: state, window 12/80 · about 40 s left*); the
  results are the same. In a Run its windows move the step's **Current** bar (Sorting: a quarter of the
  dataset after its artifact intervals; Spikes: half of what is left; an automatic detection: its first
  half) instead of holding it still; `EphysPipeline.prepareWCARFor` takes the span and says whether it
  worked the state out.
- Writing the analysis report reports its progress (*Writing the report: page 3/12*, sections for the
  HTML), in a share of the run of its own: `writeHtmlReport` and `writePdfReport` take `ProgressFcn=`, and
  so does `writeUnitQualityReport` (each good unit's waveform). Selecting a dataset in the analysis app
  says which one of how many it is loading, and Scan names the root it scans.

### Changed

- Pipeline app: the Project table's **Tags:** filter works as the dataset browser's: a **not** list leaves out the
  datasets holding any of its tags, and **search** (was *search tags*) looks for every word in the name, key and tags.
  `datasetFilter` (and `test_DatasetFilter`) moved from `analysis/` to `pipeline/`, so the app needs no `analysis`
  folder for it.
- Analysis app, Data tab: **Subject:** terms are matched literally apart from the wildcards `*` and `?`; a regular-expression
  character such as `.` or `(` no longer acts as one. See
  [The filter](documentation/DatasetBrowser.md#the-filter).
- Analysis app: **Test report** and the Export tab's **Export preview** swapped places. The Figures tab's column of
  buttons now holds **Export preview** (under **Redraw All**; the one under the preview stays), and the Export tab has
  **Test report** between **Plan** and **Run**. **Ctrl+U** on the Figures tab still runs the Test report.
- Scanning datasets is faster, most of all over a network share. `DatasetOutputs.refresh` reads a `-v7.3` file's
  variable names from its HDF5 root group, which is about ten times faster there than `whos('-file')`. It keeps
  what it read from each output file (variables, or a `.npz`/`.nwb`'s tool, and the dataset and `sourceFolder` its
  provenance names) in a new **`OutputFileIndex`** on this machine
  (`%LOCALAPPDATA%\ephys_analysis\output_index.mat`, or `EPHYS_OUTPUT_INDEX_FILE`), by path, size and
  modification time, so a later scan opens only new or changed files. The analysis app fills its datasets table
  and Dataset labels twice per scan (after the scan, and for the first dataset opened) instead of four times
  (`HoldDatasetViews`); each fill checks every dataset's files. On the lab share's 40 datasets
  (186 files), the analysis app's scan went from 125 s to 42 s the first time and 4 s after that. See
  [Discovery](documentation/DatasetOutputs.md#discovery).
- Review tab: the **Sort** dropdown is gone. The Datasets table has a **Sort** column instead: each row's cell
  picks which of that dataset's sorts to review (a dropdown of the sorts found under the datasets' output folders,
  or **(in use)**, the default, the dataset's own). Showing a dataset loads the sort its cell picks. The pick is for
  review only and is kept for the session; **Use this sort** makes the sort shown the dataset's own and resets the
  cell to **(in use)**.

- Figures tab: **Unit report** is now **Test report** (`onTestReport`, `test_report.html`, Ctrl+U as before), and
  it holds the figures of the dataset too: `run(Observation=)` draws a figure of the dataset for the dataset
  instead of skipping it, and with a figure of the dataset selected (the dataset picked) the report draws the
  dataset's figures. The figures across sessions stay out (they match observations across the datasets) and are
  now listed as skipped under *Across sessions* with why. See the
  [Figures tab](documentation/EphysAnalysisApp.md#figures-tab).

- Figures tab: a switch between figures is faster. Each figure keeps its observation list (`FigurePickers`:
  `keepFigurePicker`, `takeFigurePicker`), so a figure shown again takes its own list, count line and pick back
  instead of running `figureObservations`, unless what the list is made from changed (its observe block, event,
  selection or sorting, the dataset or the ticked ones); a scan, another config and a star or note set or cleared
  forget the kept lists (`forgetFigurePickers`). The editor sets only what changes: `formLayout` and
  `layoutFigureEditor` compare a control's `Layout.Row`, the row heights and the headers before setting them
  (setting `Layout.Row` to the same row costs as much as a move) and a hidden row keeps its own place below the
  shown ones; the drop-downs' lists (`setChoices`, the Observe list, Stack, the aggregate, the *Figure:* picker) are
  set only when they differ; the editor is scrolled back only when its scroll differs, so the switch waits for one
  redraw, not two. Property updates sent to the view per switch: about 390 before, 65 now. A switch between two
  drawn figures on the synthetic test project, timed side by side with the old code on a loaded machine: 3.0 s and
  3.5 s median before, 2.2 s and 2.6 s now.
- Faster app startup. MATLAB spends most of an app's start making the window's components and their views, so
  the analysis and pipeline apps no longer paint the hidden window while they start (`setStatus`, `onScan` and
  `selectDataset` skip `drawnow` while the splash is active): it is laid out once, when it shows. Every tab
  but the one the app opens on (Data, Project) keeps its contents hidden until it is first shown (`revealTab`
  in `onTabChanged`), so that layout covers one tab; the analysis app's Figures tab, three quarters of its
  components, is laid out on its first visit instead. The analysis app also leaves the Alignment tab's epoch
  count and diagram until that tab shows, restores the figure editor's collapsed sections without laying it
  out twice more (`applyConfig` does), and `formLayout` sets only the properties that change (a set costs as
  much when the value stays). On the synthetic test project, with the last config's three figures reopened
  and scanned, the analysis app's warm start went from about 28-31 s to 17-19 s on a loaded machine (cold 68
  s to 49 s); the first visit of the Figures tab takes about 6 s more. The pipeline app's warm start on that
  project went from about 23-25 s to 17-21 s (cold 58 s to 51 s); a tab's first visit takes about 2-3 s more.
- Figures tab: **an edit redraws only what it changed.** What an earlier preview computed on the same data is
  taken again: `figureCompute(..., Reuse=K0)` returns `[F, K]` and reuses each step (skip reasons, epochs, each
  panel's layers) whose inputs are the same, keyed by `figureDataSpec` (the spec without what only the drawing
  reads), so an edit of the looks computes nothing and an edit of one panel computes that panel;
  `EphysAnalysisRunner.computeFigure(..., Reuse=true)` keeps them in `FigureCache` (up to `FigureCacheMB`,
  forgotten by `clearSources`). `renderFigure(..., Reuse=true)` keeps the panels of the target's last drawing
  that would be drawn alike and draws only the others, redoing the legend, title, looks and layout over all of
  them. The right-click menus are made with **Edit aesthetics...** alone and get their other items when they
  first open (`PlotAesthetics.fillMenu`, `menuOf`, `addMenuItem`; "Data tip fields..." too): made at once, the
  menu items took most of a preview's drawing time. On a synthetic dataset of 200 trials (compute, draw and
  paint, medians) an edit of one panel's looks went from 1.3 s to 0.6 s on a raster + PSTH and from 3.7 s to
  0.9 s on a six-panel figure; another observation (all computed and drawn) from 1.9 s to 1.2 s and from
  4.1 s to 2.7 s.
- A PSTH panel's `options.stack` is a string (`"off"` | `"groups"`; it was `true` / `false`), and a continuous
  panel's `options.display` (`"lines"` | `"stacked"`) is gone: its stack of channels is `options.stack "items"`.
  A continuous panel's `stackSpacing` is a multiple of the row height (default 1.1), no longer an offset in the
  signal's units (`NaN` = automatic); a migrated version 1 evoked stack drops its `Style.StackSpacing`. The
  editor's continuous **Display** and **Stack spacing** rows became the shared **Stack** row; the New panel
  window's continuous **Display** is its **Stack**. A PSTH stack's row height now covers the bands too.
- A panel's `yLim` is used only with `yLimMode "fixed"`; with the default `"auto"` a stacked panel scales each
  row to itself (pick *Shared by rows* for the earlier one-scale stack).

- The probe map is drawn as a probe: each shank a pale body with a pointed tip behind its sites, named
  *Shank k* under the tip, with an x tick at each shank; sites are circles (filled in the color scale, open
  without a value), channel numbers on each site's outer side, the units' positions dark dots ringed in the
  ground's color, the color bar named for the value (*Firing rate (Hz)*, *Spikes*, *Units*). A units-per-site
  map draws a site with no unit as one without a value, with a color step per count. The axes have no box
  unless the design or the panel's **Box** gives one. The built-in designs follow: Talk's unit dots are no
  longer 16 pt blobs (its sites are larger, its observed ring 20 pt), Night's sites have a light edge so the
  darkest heat color still shows, Tufte's a gray one, Gray panel draws white shanks without a grid, and no
  design turns the observed unit's red ring black or white any more.

- Figures tab: **Preview**, **Generate**, **Unit report**, **Auto** and **<** **>** stand in a column of
  their own at the left of the header, beside the Dataset, Observation and Favorites rows; **Design** and
  **Save look as design...** sit right of Dataset and Observation, **Export code** left of **Open in window**
  under the preview. Every one of these buttons has a key, named in its tooltip and in the tab's **?** list
  (`pressFigureButton`): Ctrl+P Preview, Ctrl+G Generate, Ctrl+U Unit report, Ctrl+T Auto, Ctrl+E Export
  code, Ctrl+W Open in window (Cmd on a Mac), Page Up / Page Down < and >.
- Figures: raster ticks are drawn in each trial group's color, as the PSTH draws its traces (they were black, with
  the group's color only on a pale band behind its rows): one line object per group, tagged `rasterTicks` with
  the group's label, so the aesthetics editor and rules reach each group's ticks. `options.tickColor` `""` is
  the groups' colors (a color: every tick), and a raster layer's own **Color** overrides both. The pale bands
  are an option, `options.backColor` `"none"` (the default), `"groups"` or one color; the legend swatches are
  ticks. The designs no longer set the ticks' color (their tick widths stay).
- Analysis app opened on a folder (a project root, or one dataset's output folder; the pipeline app's **Open
  analysis app** and its Tools panel open it so): it reopens its last config (`LastConfigFile`) with its
  figures, the config's source switched to that folder's (`Mode` "project" with `Root`, `OutputRoot`,
  `NamePattern`, `Recordings` and the selection, or "folders"), then scans. The config is then unsaved and
  the status bar says so (**Save** writes the new source to its file). With no last config, or one that
  cannot be read, it makes the `<folder> quick look` config as before. A `.json` source still opens as it is.
- The baseline Modes each panel type takes are one list, `EphysAnalysisConfig.baselineModes(type, source)`,
  read by `validate`, the figure editor (`figureEditorChoices`) and `adoptPanelOptions` instead of three copies.
- A stacked PSTH (**Stack**) draws its first trial group's row on top, as a raster lists its groups, so a
  raster panel above it runs through the groups and their colors in the same order (it was the first at
  the bottom). **Order** in Trial selection picks which end is on top for both.
- The Figures tab: **Add** makes a blank figure and opens the New panel window for its first panel
  (Cancel leaves it blank); **Duplicate** names the copy *&lt;id&gt; (2)* (the next free number) instead of
  `figure_<n>`. The editor's Arrangement section is titled **Panels** and its Panel section **Selected
  panel** (their keys, `arrangement` and `panel`, and their Ctrl+2 / Ctrl+3 stay). A figure added without an
  id (`addFigure`) has an automatic id instead of `figure_<n>`.
- The Figures tab's **Design** drop-down and **Save look as design...** sit right of the **Dataset** and
  **Observation** drop-downs, which take a row each under **Preview**, **Generate**, **Auto** and **<** **>**,
  so they keep their width at the default window size.
- Figures: each panel's Options hold all of its own options (bins and smoothing, measure, baseline with its
  window and auROC settings, mask after the stop event, the waveform inset, and the type's own). "Apply to
  all panels" (Options) now copies this panel's values of the rows several types share (bins, smoothing,
  measure, baseline with its window and auROC, mask, waveform inset; `EphysAnalysisConfig.sharedFieldsOf`)
  to every other panel whose type has them, the baseline only where that type takes the mode, and its
  other options onto the other panels of its own type; the status bar names each panel that changed and
  its options, and the panels that kept their baseline. It is on when another panel has one of those rows
  or is of the same type. `adoptPanelOptions` does this and returns what changed (`[fig, changed]`).
  "Re-link all panels" (Panel alignment) re-links only the event reference, epoch window and trial
  selection (`relinkPanels`), and is on while a panel has its own. Validate checks each panel's own
  options field by field. The figure editor's section keys are Ctrl+1 to Ctrl+9: Panel alignment
  Ctrl+7, Layers Ctrl+8, Options Ctrl+9 (nothing on Ctrl+0). A version-1 plot's bins, measure,
  baseline, auROC, mask and waveform go into the options of each migrated panel that has them. See
  [Copying options between panels](documentation/EphysAnalysisConfig.md#copying-options-between-panels)
  and [Figures tab](documentation/EphysAnalysisApp.md#figures-tab).
- A figure's `observe` block names the data it is drawn for in one field, `observe.data` (constant
  `ObserveData`): `"units"` (each sorted unit), `"detected"` (each channel's detections), `"LFP"`,
  `"MUA"`, `"SPIKE"`, `"AUX"` (each channel of that extract) or `"dataset"`. It replaces
  `observe.kind` (with its `"auto"`), `observe.source` and `observe.signal`, and `ObserveKinds`.
  `observeKind(fig)` now follows `observe.data`, and `figureFor` adds `observe.kind` to the spec;
  `addFigure` gives a figure without `observe.data` (every template) what its following layers read
  (new `followedData`: units, else detected, else the first signal, else the dataset). Validate checks
  `<figure>.observe.data`, and warns on every unit or channel observation no layer follows. The
  Figures tab's Observations section starts with one **Observe** drop-down of those data types (what
  the active dataset holds first; a type it lacks marked *(not in <dataset>)* and still selectable),
  and the rows under it follow the choice; **Spike source** and **Signal** are gone. A new figure in
  the app observes its template's data when the active dataset holds it, else the first type it holds,
  and a figure observing the dataset that gets its first following layer (a panel added to a blank
  figure) observes what that layer reads.
  See [Figure, grid and observe fields](documentation/EphysAnalysisConfig.md#figure-grid-and-observe-fields).

- The analysis config is version 2: it holds `Figures` only. A version 1 file is migrated once when it
  is loaded (`load`, and `fromStruct` for a struct whose version is 1): every plot becomes a figure of
  the same id, every session plot a session figure (`match "pool"` becomes `"site"`, aux looks are
  remapped or dropped, a behavior plot is not migrated), and every note is a `LoadWarnings` line, the
  first reading `config version 1: N of M plot(s) and ... migrated to figures; saving writes version 2`.
  Saving writes version 2; any other version is `EphysAnalysisConfig:BadSchema`; a version 2 file that
  still holds `Plots` or `SessionPlots` gets the unknown-field warning. The migration lives in the
  class's private `legacy*` functions. See [Loading a version 1
  config](documentation/EphysAnalysisConfig.md#loading-a-version-1-config).
- "No figure is enabled." replaces the rule that counted plots, figures and session plots (it counts
  figures and session figures); the `units.response` checks moved to the Figures block, on figures that
  observe units (`<figure>.observe.units.response.*` and each spike layer's); the `Export` file-name
  warning counts the enabled figures.
- `EphysAnalysisRunner`: `run(Datasets=, Figures=, SessionFigures=, Export=, Report=)`, `plan(Datasets=,
  Figures=, SessionFigures=)` and `runDataset(k, Figures=, ...)` take figures and session figures only.
  The run record is schema `ephys-analysis-run/2` with `figures` and `sessionFigures` (no `plots` or
  `sessionPlots`). Reports count "N figure(s)"; `addReportFigure` and `newExportFigure` take figures
  only; the errors of the shared drawing helpers are `renderLayout:BadTarget`, `rasterInto:NoSortEvent`
  and `rasterInto:NoSortColumn`. The generated standalone script holds figures and session figures only,
  and passes each figure's auROC calls to its caption (`Auroc=acalls`).
- A figure's caption (`figureCaption`) says what an auROC PSTH or heat map's cutoff called, as the plot
  caption did: `figureCaption(spec, T, Auroc=CALLS)` takes one `figureAurocCalls(F)` result per
  observation, and the runner and the standalone script pass them.
- Plot designs and aesthetics are kept per panel type. `PlotDesign.kindNames()` lists the kinds a
  design's `kinds` and the user's remembered rules can name: every panel type, `"figure"` and the
  Chronux result kinds; a design key that is none of them (a retired plot kind) is dropped with the
  warning `PlotDesign:UnknownKind`. `PlotDesign.capture` reads the editing context `renderFigure` keeps (or takes `Spec=`) to tell each tile's panel type: the axes of heat map, probe map, unit correlation and spectrogram panels give rules for those panel types, the rest common rules. The roles of the retired
  plots (`auxTrace`, `auxSem`, `auxImage`, `auxGroup`, `auxScale`, `behaviorMean`, `swarm`, `violin`)
  are gone from `PlotAesthetics.roles()` and the built-in designs. The aesthetics dialog reads "Figure
  aesthetics", "This figure" and "Every figure (my preferences)" for a figure.
- The pipeline's Analysis step runs figures and session figures only (a plot of a version 1 config runs
  as the figure it migrates to), and counts them in its logs, plan and dry run. A version 1 analysis
  config is migrated on every read there, so the pipeline's validation gives one warning, `analysis
  config <file> is version 1: open and save it in the analysis app to migrate it once`, instead of every
  note; the sorted-units rule reads the figures (a figure that observes sorted units or has a `units`
  layer, session figures included). The pipeline app's Analysis tab lists the config's figures (Figure,
  Observe, Panels, On) and the pipeline diagram's Analysis box reads them.
- The analysis app's Figures tab has the Design row: the "Design:" list (also the Design menu) and
  **Save look as design...**, which captures the figure preview's look per panel type from the panels as drawn, as the preview's right-click **Save this look as a design...** does, and refuses while the preview is out of date. Unticking a dataset marks a session figure's preview (datasets "ticked") out of date and rebuilds its observation list. The toolbar's **Preview** shows the Figures tab,
  lists the selected figure's observations and previews it. Escape cancels a panel drag and Page Up /
  Page Down step the observation, on the Figures tab only, as Ctrl+digit goes to its sections. The epoch
  diagram opens for the selected figure by default (modes "figure" and "defaults"). **Open config...**
  writes every load warning to the Log tab, a version 1 file's migration notes included. The Export tab
  says "Figure parameters", **Plan** reads "Plan: n of m figure run(s) and n of m session figure run(s)
  will draw.", **Run** takes the enabled figures and session figures, the unit-mapping editor has no
  plot target, and the Event sequence window has no mark-list mode.
- The documentation drops the plot kinds: the config page's Plots, Session plots and Converting a plot
  sections, the app page's Plots and Sessions tabs and Plot kinds (now Panel types), the Analysis page's
  session plot, renderer and result-cache text. The shared reference sections (auROC, raster sort and
  event marks, unit waveforms, aux signals, error bands, panel notes and overlays, stacked PSTHs,
  waveforms panels) now describe panels and figures.
- A plot's raster marks, `rasterEvents`, are a list of marks, each an event reference (with or without a
  sequence; `which "all"` and `scope "recording"` by default) with its own `marker`, `size` and `color`
  (`EventMark`). The old `lines`, `edge`, `scope`, `sequences` and one look for all marks are gone: a line's
  events are a mark with no steps. New functions `eventMarkRef`, `rasterMarkLabels` and `rasterMarkLooks`.
  The analysis app's plot editor has an **Event marks** section of its own (between the kind's options and
  Appearance, no Ctrl+number key): **Sequences** (**Edit...**: the *Event sequence* window, a mark per
  sequence) and **Each mark**, a table of every mark's marker, size and color.
- The synthetic data generator (`SyntheticDesign`, `syntheticModel`, `makeSyntheticRecording`, the app's
  Synthetic tab, `makeSyntheticProject`) writes deliberately simple, exactly known signals for
  validating the pipeline and the time-locked analyses. Units have one fixed waveform (a negative
  Gaussian trough of `AmplitudeUV`, sigma 0.2 ms) on their `Channel` only, every spike the same size,
  and fire as a Poisson process whose rate is `BaselineHz` x `Gain` from `LatencyMs` to `LatencyMs +
  DurationMs` after the event's edge (optionally scaled by an Epsych2 `Parameter`). LFP rows are
  evoked potentials only: a raised-cosine deflection of `AmplitudeUV` from `LatencyMs` to `LatencyMs
  + DurationMs`, peaking halfway, on `Channel` or (NaN) every channel. The background is white noise
  (`NoiseUV`, 10 uV) plus a 2 Hz sine (`SineUV`, 100 uV), which keeps the artifact detector's
  running-RMS threshold above spikes and evoked potentials as on real recordings. The accelerometer
  inputs are constant, 0.1 V higher while the trial line is on. The built-in design's units have
  fixed amplitudes (200 down to 60 uV) and rates (5 Hz): half of them x5 from 20 to 220 ms after Stim
  onset, the third silenced from 0 to 500 ms, with a -150 uV evoked potential from 20 to 70 ms. The
  design file schema is `ephys-synthetic-design/2`; older designs are refused by `SyntheticDesign.load`
  and not restored from the app's preferences. `SyntheticDesign.newLFP(event, name)` drops its kind
  argument and `validate` its sample-rate argument. `benchmarkDetection` takes `NoiseUV` and `SineUV`
  instead of `WidthMs` and `Background`; `test_DetectionBenchmark`'s ceiling on isolated noise
  crossings is 1.5 Hz (Gaussian noise gives about 0.95 Hz at 4 x MAD).
- Analysis grids (PSTH, raster, tuning, evoked butterfly and grid, heatmap,
  unit correlation) are labeled once, on their tiled layout: one x label
  under the whole grid and one y label beside it (a PSTH with rasters names
  the rates, then the rasters' rows), with the plot's title above. The
  tiles keep only their own titles. A grid's legend goes east of the grid
  when Style `LegendLocation` is `"auto"`, rather than in its first tile.
  The aesthetics editor and designs reach the grid's labels as the plot's
  own `xlabel` and `ylabel`. **Labels on corner tile only** (Style
  `CornerLabelsOnly`) is gone.
- `EphysAnalysisConfig.addPlot` gives a plot added without a source its
  kind's first source (LFP for an evoked potential; trials for a behavior
  plot), as the app's Add does.
- A psth or raster plot sorted by a trial parameter the dataset lacks is
  skipped ("no trial parameter X") instead of failing when it runs.
- Pipeline app: the Run tab always shows the run diagram and the Resource use
  panel (CPU, memory, disk and GPU). The **Show the run diagram** and
  **Monitor CPU, memory, disk and GPU** switches and their `ShowRunDiagram`
  and `MonitorResources` preferences are gone. The resource sampler starts the
  first time the Run tab is shown (also by Validate, Plan and Run) and runs
  until the app closes.
- Pipeline app: the text that named Kilosort4 for any sort now names the
  sorter. The Run diagram's Sorting step, the Artifacts tab's **Erase in
  sorting** and the Sorting tab's SpikeInterface note follow the selected
  sorter. The background-run label, the queue, **Stop runs...** and the
  close and restart prompts name the sorter of the runs they act on
  ("sorting" when the runs come from more than one sorter). The tooltips,
  Clean up's **Sorting** box (which covers the `si_<sorter>` folders too)
  and the Sorting log are worded for any sorter. Text that only applies
  to Kilosort4 still names it: its parameters, the probe `.json` format,
  `temp_wh.dat` and the GPUs.
- The MUA follows Lakatos et al. (2005, J Neurophysiol 94:1904): band-pass
  `MUA_bpLoHi`, rectify, then a zero-phase 4th-order Butterworth low-pass at
  `MUA_IntegrationHz` (the "integration", 1000 Hz), all at the recording
  rate, then resampled to `MUA_Fs` (2000 Hz). The moving mean after
  resampling is gone: it smoothed the envelope to about 500 Hz and put it
  half a sample (0.25 ms at 2 kHz) late. `MUA_IntegrationHz` is now the
  low-pass cutoff and must be at most `MUA_Fs / 2`
  (`EphysPipelineConfig:SignalsMUAIntegration`,
  `EphysDataset:deriveSignals:MUA_IntegrationNyquist`).
- The QC report (`writeUnitQualityReport`, the Review tab's **QC report**)
  lists the units labeled good first, sorts its table by a click on a
  column header (again: reversed; a third time: back), and draws each good
  unit's mean waveform on its peak channel: the mean and SD of up to
  `WaveformSpikes` (100) of its spikes cut from the sorted `.bin`, else its
  template. A good unit's label in the table links to its waveform.
- The common reference has a config section of its own: `Reference` with
  `Mode` (`"none"` / `"car"` / `"cmr"`), `BadLow` and `BadHigh` (0.3, 2). It
  replaces `Artifacts.Reference`, `Artifacts.ReferenceBadLow` and
  `Artifacts.ReferenceBadHigh`, since every step that reads the recording
  takes it. It is always validated (issues under `reference`), saved as its
  own JSON object and carried onto every dataset's `ArtifactConfig` as
  before. `EphysPipelineConfig.artifactConfig(A, R)` takes both sections.
  The Artifacts tab's panel is titled "Common reference, for every step
  (config: Reference)" and lists the reads it applies to.
- The Intan readers filter a recording's pre-3.0 notch files as one stream:
  no step or ringing at file boundaries. Windows and chunks start the filter
  1.76 s before their first row instead of reading whole files; `readData`
  carries the filter state from file to file; `read_Intan_RHD2000_file_modified`
  takes `Notch=false`.
- `EphysDataset.setTrialPairing` returns `[file, saved]`; the Trials tab's
  Approve no longer writes the manifest twice.
- PDF reports are joined from the pages the runner (and the standalone
  script) drew and exported, with the Apache PDFBox library MATLAB ships; no
  page is drawn twice and no result is kept. A run with both reports took
  about half the time on the test fixture. `addReportFigure` takes `Pages=`;
  `writeHtmlReport` no longer takes `EmbedFormat` / `Dpi`.
- The auROC cutoff warnings are `aurocCall:WideCutoff` /
  `aurocCall:NoCutoff`. `populationAnalysis` builds its epochs with
  `Baseline`, so the PSTH and the auROC share them.
- The pipeline app's Help opens `Run-and-Flow-Tabs#diagram` and `#run`, the
  headings of the page generated from `documentation/`.
- Test descriptions in `documentation/` match the suites; the README table
  lists every suite.

- The analysis app's parameter lists (group-by, tuning x axis and series,
  tuning-test parameter, the dataset's Parameters table, the filter help's
  columns) offer every trial column, `RespCode` among them, in alphabetical
  order (ignoring case). `loadAnalysisSource`'s `paramNames` leaves out only
  the pairing's times and samples; it no longer follows `info.WriteParams`.
- Analysis figures and the HTML report are easier to read:
  - A PSTH grid puts each raster right on top of its rate panel. The two
    sit in a 2 x 1 tiled layout in the unit's tile, so the gap between
    rows falls between units, not between a raster and its own PSTH.
  - A grid page grows taller than `Export.FigureSizeCm(2)` when its rows
    need it: 3 cm a row, 4.5 cm for PSTHs with rasters, plus 1.5 cm. Call
    `newExportFigure(X, R, spec, Page=p)`; the runner, both reports and
    the generated scripts do.
  - In grids of more than one tile, the tick labels are 2 points smaller
    than `Style.FontSize` and each automatic y axis has at most three
    ticks (new private `tileTicks`).
  - A raster drops its ticks in the bottom tenth, and "Epoch" is shown on
    the left column only.
  - Depths in unit titles are whole µm.
  - The probe map writes each site's number on the outer side of its
    column, so the labels stay clear of the markers.
  - The report's digital-line and highest-rate tables have readable
    headers ("Mean duration (s)", "Rate (Hz)") and short unit labels. An
    empty value prints as an empty cell, not `NaN`.
  - A printed report (or one saved as PDF) no longer splits a table or a
    figure across pages, or breaks right after a heading.
  - `Report.Title` defaults to `"{Name}"`. The app names a new config
    `"<folder> quick look"`, so the old default `"{Name} quick look"` read
    "… quick look quick look".
- `EphysPreprocessingApp` is renamed `EphysPipelineApp` (class folder,
  `test_EphysPipelineApp`, `documentation/EphysPipelineApp.md`), and the
  analysis app's **File → Open preprocessing app** is now **Open pipeline
  app** (`onOpenPipelineApp`). Its preferences group is `EphysPipelineApp`,
  so preferences saved under the old name are not read.
- `S_ExampleAnalysis.m` is a walkthrough that runs on any machine. Before,
  it was a launcher with a user-specific path. It writes a synthetic
  project to `tempdir` and goes through the project, pairing review, the
  pipeline, the outputs, unit quality, a PSTH, response statistics and a
  population summary.
- `documentation/` is the one source of the wiki's prose pages.
  `tools/wiki/gen_pages.py` generates them from it, and `pages.json` maps
  each page to its file or sections. Links are rewritten to wiki pages, or
  to GitHub, and the script never runs git. Platforms is generated. The
  other 21 mapped pages are candidates until their wiki-only content is
  merged into `documentation/`: `--report` shows how far each one differs
  (`test_gen_pages.py`).
- The preprocessing app's Diagram pages are drawn by a plain class,
  `PipelineDiagram` (`detail`, `overview`, `zoomFrame`), which needs no app:
  `PipelineDiagram.overview(cfg, [])` writes a config's diagram from a
  script. The app's `flowChartHTML` / `flowOverviewHTML` call it; the code
  moved unchanged. The run monitor's log tail is `readNewLines`. Suite
  `test_ReadNewLines`.
- The Kilosort4 `.bin` keeps the recording's own resolution when it can:
  `EphysDataset.Scale` and `EphysProject.Scale` default to `NaN`, meaning
  `EphysDataset.binScale`, which uses 1 / the recording's µV per stored unit
  when every channel shares it and one stored unit maps onto one int16 unit
  (readers report their storage through `EphysReader.storageFormat`), else
  `1/0.195` as before. Intan and Open Ephys headstage data are unchanged
  (0.195 µV); a `recording.json` recording at another `gain_to_uV` is now
  written to the integer instead of re-quantised. `toBin` returns
  `scaleSource` and the sidecar records `scale_source`. Suite `test_BinScale`.
- The apps and the screenshot tools no longer call `getpref` / `setpref`
  directly. The test suites no longer back up, clear and restore your
  preferences; they never touch them.
- `test_BinaryReader` is a `matlab.unittest.TestCase` class (the pattern for
  new suites), with the same checks.
- `.gitignore` covers MATLAB backups and autosaves, test-runner output,
  `.claude/worktrees` and operating-system files.

- `renderFigure` lays a figure out with its own engine instead of MATLAB's tiled layout
  (`private/figureCanvas`, `figureLayout`, `figureArrange`): one axes per panel placed in pixels, the rows'
  and columns' plot areas lined up and in the exact proportions of `rowHeights` and `colWidths` (no more
  quarter steps of the smallest, no 32-tile cap), the room the labels take measured from each axes
  (`TightInset`, a color bar outside) and the gaps exact; the title and subtitle in a band over the grid
  (a hidden `titleHost` axes, still the editor's `plotTitle` / `plotSubtitle`), the legend in a band beside
  it (made where it is placed: `placeLegend`'s new location `"none"`), a note's band and a coherence panel's phase strip in the panel's own area. The target is laid out
  again whenever it is resized (its `SizeChangedFcn`, chained after the one its owner set), so the app's
  preview follows the window. `h.layout` is now what the figure is laid out on (the target, or a panel
  made in a grid layout); a tiled layout is no longer a target (`renderFigure:BadTarget`). The spacing
  presets are named gaps: loose 24 px, compact 12, tight 6, none 0. A panel smaller than its cell keeps
  its own time tick labels. `PlotAesthetics.components` lists a figure's title from its `titleHost`, and
  `PlotDesign` paints the target itself as the figure's ground.
- Messages that named a panel type now use its label and need no article: *probe map panels are not merged
  across sessions* (`figureSessionCompute`, `figureSessionSkipReason`), *event-trace panels do not draw units*
  (`figureSkipReason`), Validate's *A session figure cannot hold probe map panels: ...* and the Sessions
  note's list (they read *a eventTrace panel*, *a probemap panel*). New private `panelTypeWords`.
- An event-trace panel's logic levels are patch edges (`FaceColor "none"`, the opacity as `EdgeAlpha`), not
  lines given MATLAB's undocumented four-element RGBA color; an SVG export keeps their opacity
  (`stroke-opacity`), as `test_EphysAnalysisFigures` checks.
- Reports and data exports carry the stars: `unitSummary` and `populationAnalysis`' `P.units` have a
  `starred` column per unit, `P.datasets` and `sessionTable` (and so a session figure's data file's
  `sessions`) one per dataset, and `populationSummary` groups by `"starred"`. A report's datasets carry
  `starred`: the HTML report marks a starred dataset with a ★ in the contents and over its section, the PDF
  names it *(starred)*, and the summary's recording table lists **Starred**, the starred channels and
  units, with a **Starred** column in *Highest rates*.
- The Copy tab's and the Run tab's output-copy time left come from `ProgressClock`, as every other time
  left: *about 40 s left* instead of *less than a minute left*, smoothed, and the output copies' only once
  1% is done and 5 s have passed (`CopyStarted` / `TransferStarted` are now `CopyClock` / `TransferClock`).

### Removed

- The Figures tab's template drop-down above **Add**, and the Panels section's **Add panel** drop-down with
  its **Above** / **Below** / **Left** / **Right** buttons (one **New panel...** button and its window
  instead); the app's `onAddPanel`, `FigureTemplateDropDown` and `FigureAddType`. `figureTemplates` and
  `addFigure(template)` stay for scripts and tests (`onAddFigure(template)` too).
- The analysis app's Chronux tab (and its preferences `ChronuxCacheFolder`,
  `ChronuxMaxMB`, `ChronuxSettings`, `ChronuxSectionsCollapsed`, its wiki
  section and its test section): the Figures tab's *Power spectrum*,
  *Spectrogram* and *Coherence* panels compute the same analyses straight from
  the extracts and units, with no Chronux file. The pipeline's Chronux export
  (`<Name>_chronux.mat`) and the `chronux*` analysis functions stay.
- Figures: the figure-level options block and linked panels: a figure's `common` block,
  `defaults("FigureCommon")`, a panel's `common` flag, `commonFields`, `commonFieldsOf` (now
  `sharedFieldsOf`) and `panelOptions`; Validate's `<figure>.common` checks and the
  `<figure>.<panel>.common` error. In the Figures tab, the Common options section and the Options
  header's "Common options from the figure" box. Copy from... has six parts (no Common options). A
  `common` field in a config file is an unknown field, dropped and listed in `LoadWarnings`.
- Plots and session plots from the analysis config and the whole plot path: the `Plots` and
  `SessionPlots` sections, their methods (`addPlot`, `removePlot`, `plotFor`, `convertPlotToFigure`,
  `plotToFigure`, `addSessionPlot`, `sessionPlotFor`, ...), constants (`Kinds`, `AuxModes`,
  `AuxPlacements`, `AuxDisplays`, `AuxColorBy`, `OverlayPanels`, `SessionKinds`, `SessionMatches`,
  `SessionData`), defaults (`Plot`, `SessionPlot`, `Aux`) and validate rules; the runner's plot and
  session-plot paths, `Plots=` and `SessionPlots=` on `run`, `plan` and `runDataset`, `computePlot`,
  `cachedPlot`, `renderPlotFigures`, `computeSessionPlot`, `runSessionPlot`, `sessionData` and the
  per-dataset result cache (`ResultCache`, `CacheMaxMB`, `CacheBytes`, `CacheWanted`,
  `clearResultCache`); the per-kind renderers `renderPlot`, `renderPSTH`, `renderRaster`,
  `renderEvoked`, `renderRates`, `renderTuning` and `renderBehavior`; and the functions only they used
  (`plotCaption`, `plotFileName`, `plotSkipReason`, `plotPageCount`, `plotErrorType`,
  `sessionPlotSkipReason`, `sessionResults`, `sessionData`, `epochData`, `epochLongTable`,
  `behaviorValues`, `auxMean`, `copyPlotSettings`, `plotSettingParts`). Figures (the `Figures` section,
  with session figures) are the only plotting path. The behavior plot has no figure counterpart, and a
  PSTH's aux sub-struct is an AUX layer of a continuous panel. The old session data `.mat` and its epoch
  tables are gone: a session figure's data file is the only data export. `test_plotToFigure` and
  `test_copyPlotSettings` are replaced by `test_ConfigMigration` and `test_copyFigureSettings`.
- The analysis app's Plots and Sessions tabs (it has six tabs now: Data, Alignment, Figures, Export,
  Chronux, Log), with their editors, previews, **Convert to figure**, **To workspace** and **Save
  .mat...**, and the plot and session preferences `AutoPreview`, `PlotGroupBy`, `PlotGroupsCollapsed`,
  `PlotSectionsCollapsed`, `SessionAutoPreview` and `SessionSectionsCollapsed`. The wiki anchors
  `#plots-tab`, `#sessions-tab` and `#plot-kinds` go with them (the page has Panel types instead).
- From the synthetic generator: schedules from a real dataset's Epsych2 session
  (`syntheticSessionSchedule`; `makeSyntheticRecording`'s `Session` and `MaxDuration`; the Synthetic
  tab's Timing from, Dataset, Load source, rebuilt-lines table, Trial (ms) and Max (s)); LFP
  oscillations (phase-locked and induced), depth profiles and jitter; unit waveform widths, spread
  over neighboring sites, response shapes, latency jitter, decreasing tuning and per-spike amplitude
  scatter; values drawn at random for NaN; the background rhythms, 1/f noise and line noise; the
  Synthetic tab's probe-gain plot and its PSTH split by parameter.

- `figureTiles` (a figure's grid as equal tiles of a tiled layout), with the quarter-step rule for row
  heights and column widths.

- The script route to a Chronux export file: `loadChronuxExport` and `chronuxSpikeTrains` (the figures'
  spectral panels read the layers themselves, and the Chronux analyses take their blocks); `chronuxPairs` is a
  local function of `chronuxCoherence` (its error is `chronuxCoherence:BadPair`). The Chronux export
  (`exportChronux`) and its file format stay; the worked example in the analysis documentation goes.

### Fixed

- Pipeline app: at startup the tabs could show as a small 260 x 221 px box in the window's bottom-left corner,
  for seconds to minutes, until another tab was picked. The tab group was sized from its host panel, whose
  laid-out size reaches MATLAB only once the window's first render is over; it is now sized from the window's
  own size before the window shows, and again whenever the window is resized (`fitTabGroup`).
- The probe map moved sites sideways by `kcoords` group: a Kilosort map that parks a site on a group of its
  own (H64LP_4x16lin parks two per shank, on groups 5 to 12) had those sites spread out to the right of the
  probe, under a row of overlapping *Shank 5* ... *Shank 12* labels. Every site is now drawn at its own x
  (`xc`), and a shank is the sites a wide gap in x apart (`probeColumns`), so a parked site sits on the shank
  it is parked above. The waveforms panel's probe layout, which moves a shank only where its glyphs would
  overlap, now moves whole shanks the same way, so it no longer pulls parked sites off their shank.

- After **New config** (a config with no file yet), both apps wrote an empty `LastConfigFile` at close, so the
  next launch opened nothing: they now keep the last file opened or saved.
- Analysis app: a config opened while another config's datasets were listed was scanned with the old Run ticks
  as its selection (they matched the old datasets' count), so a "list" selection came out "all". The scan after
  an open now ticks the opened config's own selection (`scanOpened`).
- A patch overlay was never seen over a raster panel: `drawOverlays` drew it as an `xregion` / `yregion`,
  which MATLAB paints behind every opaque patch whatever the draw order, and a raster's group bands are
  opaque (a PSTH's fills are translucent, so it showed there). A patch is now a patch object spanning the
  axes' limits, refitted when they change, so "over" and "under" the data mean what they say on every panel.

- Unit quality criteria failed with `The length of the sorted recording is unknown (no .bin, no recording
  metadata ...)` (`EphysDataset:unitQuality:NoLength`, from `selectUnits`) on a dataset that holds only the
  pipeline's outputs, such as a backup share (`S_ExampleSpikeAnalysis` over `S:/ANALYSIS_BACKUPS/...`).
  `selectUnits` now asks the dataset only when its recording is there; otherwise it takes the length from
  the source (`fs` x `durationSec`) and leaves SNR unknown, as it does without a dataset.
- The pipeline app's output-copy progress line could fail with `First input must be a string array or cell
  array of character vectors` (`showTransferProgress`, from `pollTransfers`) when the copies finished
  while it was being drawn: the monitor timer's `pollTransfers` emptied the list of transfers between the
  progress line's check and its tooltip. It now works on its own copy of the list, and leaves the row to
  the final "Output copies done" message when the copies finish meanwhile. Seen once in CI
  (`test_EphysPipelineApp`, which passed on the re-run).

- The NWB export failed on Windows machines that treat `AUX.npy` as the reserved device name `AUX`
  (Windows Server, the GitHub-hosted runner): it staged each signal as `<SIG>.npy`. The staged
  signals are now `signal_<SIG>.npy` (`exportNWB`; `nwb_export.py` reads the names from
  `stage.json`).

- A `"*"` probe rule did not match a dataset whose name does not parse with its name pattern,
  although such a dataset has no subject and only a `"*"` rule is meant to match it
  (`EphysPipeline.probeRule`).

- The caption of a PSTH or raster with the mean aux signal failed with `Unrecognized field name
  "yLim"` when the plot's `aux` left out `yLim` or `overPosition`; it now reads them with their
  defaults, as the renderers do (`plotCaption`).

- Tests that failed on any machine or only on a hosted runner, found by the first CI runs:
  `test_ChannelMapper` compares against its own copies of the example mapping and the H64LP probe
  map (`pipeline/testdata/channelmapper`), so editing the lab's files in `pipeline/hardware` and
  `pipeline/probes` no longer changes what it checks; `test_PlotAesthetics` reads an overlay's
  color before the next plot clears it, compares a plot's draw order with the same plot drawn
  where no overlay ever was, and checks that an invisible figure gets no menu on a new figure (its
  shared figure had been drawn editable before); `test_NWBExport` checks the missing-start error on a
  dataset with no recording (a binary recording always has a start: its data file's modified time
  when the descriptor gives none); `test_PlotDesign` compares the ground Default restores with the
  figure's own starting color, not white; `test_IntanReader` checks the notch filter's agreement
  with Intan's loop and its speed-up (now: faster than the loop) separately;
  `test_CopySessions/scheduleRunsAsAWindowsTask` is skipped on GitHub-hosted runners, where the
  MATLAB Task Scheduler starts does not run, and quotes `matlab.log` when it fails elsewhere.

- Analysis plots of threshold detections (source *detected*) and of signals
  labeled every channel "sh0" with no depth, and could not sort them by depth
  or shank, when the dataset's manifest names no probe file: the case for a
  dataset sorted with the pipeline's default probe, which the manifest records
  only with `Probe.WriteDefaultToManifest`. Sorted units were labeled right,
  since their sites come from the sort folder. `loadAnalysisSource` now takes
  the probe map the sort used (`channel_map.npy`, `channel_positions.npy`,
  `channel_shanks.npy`) when there is no probe file, and says which in
  `src.probeSource` (`"manifest"`, `"sorting"` or `""`). Probe maps and
  waveforms on the probe draw from it too, and the report's recording table
  names it.

- `DatasetOutputs.readUnits` on a folder whose manifest named an existing probe
  file failed with `Invalid argument name 'ProbeFile'`: it passed an option
  `readPhyUnits` does not take. The analysis app opened on a single output
  folder could not read its units then.

- A run that launched background sorting runs wrote no run record (warning
  `EphysPipeline:RunRecord`, `Unrecognized field name "name"`): the record
  read each run's name from the wrong field. It now lists them under
  `backgroundRuns` as intended.
- Finding recordings (`EphysProject`, the app's Scan, `DatasetTracker`) and
  a dataset's outputs (`DatasetOutputs`) walk the folder tree once instead of
  once per file pattern, and skip hidden folders such as phy's `.phy`
  caches (`listTree`, `matchFiles`). On a network share holding sorted data
  the scan took minutes: `EphysProject` on a NAS folder of 7 datasets went
  from 125 s to 1.3 s, and `DatasetOutputs` of its sorted dataset from 92 s
  of folder walks to 4.3 s in all. A reader's `findRecordingFolders` takes that
  listing as a fourth input, `files`.
- The Review tab clears its folder field when the active dataset has no
  sorted output (or its pinned folder is not there), so **Load**, **Open
  folder in explorer** and **Open in phy** no longer bring back the
  previous dataset's sort.
- The Run tab's results table fills as the Run goes, one row per step and
  dataset, instead of staying empty until the Run ends; a row the Kilosort4
  monitor restates during the Run shows at once.
- A problem with the common reference colors the Artifacts tab even while
  automatic detection is off.
- `EphysProject.toBinAll` with options failed with "Too many input
  arguments" (its classdef declaration listed `opts` for a `varargin` file).
- A unit with no spike over a group's epochs has no auROC (NaN) and stays
  out of the 95% CI cutoff, as in `calculate_auROC.py`, instead of 0.5.
- A spike on a bin edge (within 1e-9 s) is always counted in the bin that
  starts there (`binCounts`); with spikes and events on one sample grid,
  rounding picked the bin. The auROC stop mask uses the same tolerance.
- The Run tab's Spikes box and the docs said the Spikes step writes
  "detected / sorted" spikes; it writes detections only. The probe tool's
  errors and two help lines still named a "Kilosort tab".
- Test fixtures no longer give extract `info` a `time` vector that real
  extracts do not have.

- `renderProbeMap` held a Latin-1 `µ` in its axis labels, which MATLAB
  reads as UTF-8. It is UTF-8 again.
- `EphysDataset.exportEpochs` no longer passes `Provenance` on to
  `eventEpochs`, which does not take it. Every epochs export given a
  provenance (the pipeline's Export step, generated scripts) failed with
  *Invalid argument name 'Provenance'*.
- The guard that stops `toBin` writing over a recording file now resolves
  `.` and `..` itself when MATLAB runs without Java.
- Visualize: spike ticks are drawn 2 points wide, edged in the plot's
  background color and in front of the traces. Before, they were 1.2-point
  lines inside the trace's own band and hard to see on a dense trace.
  Stored waveforms in µV on their own lanes have a scale of their own
  (`EphysTraceViewer.RasterSpacing`, picked from the units' or channels'
  waveform peaks and given on the status line) instead of the traces'
  Spacing, which on a broadband trace can be many times a spike's
  amplitude and left the waveforms a few pixels tall.

## [0.1.0] - untagged

The code on `main` up to commit `75fa4e2` (2026-10-02), before releases were
tagged. Its history is in git and in the Done list of
[ephys_analysis-TODO.md](ephys_analysis-TODO.md).
