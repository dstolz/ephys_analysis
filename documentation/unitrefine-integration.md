# UnitRefine integration: design evaluation

**Status: evaluation and design proposal, not implemented.** Written
2026-10-07 from the pipeline's source and from the SpikeInterface 0.104.5
wheel (the version [INSTALL.md](../pipeline/INSTALL.md) pins), the
UnitRefine repository's README and the preprint's abstract. What could not
be checked from the session that wrote this (the model cards on Hugging
Face, the preprint's methods, the models' required metrics) is marked as
such. When this page and the code disagree, the code is authoritative.

## Summary

UnitRefine is a supervised classifier of sorted clusters (noise / neural,
then single-unit / multi-unit) that ships inside SpikeInterface. It fits
the pipeline as a labeling stage after any sort, run by a Python driver
the way `run_si.py` already is, writing one more phy label table that the
existing readers pick up with a one-line change. Nothing downstream (phy,
the Review tab, the QC report, the exports, the analysis) needs to know
where a label came from.

Three things decide whether it is worth doing:

1. **Accuracy on this lab's recordings is unknown.** The published models
   were trained on Neuropixels, Utah-array and Behnke-Fried data, not on
   NeuroNexus silicon probes recorded through Intan. The pipeline already
   keeps phy-curated sorts, so the accuracy can be measured before any
   label is trusted (section 5). If it is poor, the same machinery trains
   a lab model from the phy curation.
2. **The sorted `.bin` must still exist** when the labels are computed:
   every metric UnitRefine needs comes from waveforms cut from the
   recording. That ties the stage to the sort run itself, or to any time
   before Clean up removes the `.bin`.
3. **"noise" labels remove units from every export and plot** under the
   current defaults (`Export.Groups`, `UnitSelection.classes`). That is the
   point of the tool, but it is a change in what the outputs contain and
   should be opted into.

Recommendation: build it as `EphysDataset.labelUnits` plus a driver
`label_units.py`, invoked at the end of both sort drivers when the config
asks for it and from the Review tab on demand; keep the raw UnitRefine
labels and probabilities in their own table, write the applied labels as a
sorter-style copy of `cluster_group.tsv` that never overwrites phy's own,
and gate the whole feature on a comparison against the existing phy
curation.

## 1. What UnitRefine is

Jain et al., *UnitRefine: A Community Toolbox for Automated Spike Sorting
Curation*, bioRxiv 10.1101/2025.03.30.645770 (v1 2025-04-04; the
repository cites a v2, not read here). From the abstract: the toolbox trains
machine-learning models on human expert annotations, combines quality and
template metrics, classifies in a cascade, and reports human-level
performance across species, probe types and laboratories (mice, rats, mole
rats, primates, human patients). A GUI fine-tunes models to new data and
shares them on the Hugging Face Hub. The repository
(github.com/anoushkajain/UnitRefine, MIT) lists the training datasets:

| Dataset | Species | Probe | Sorter |
| --- | --- | --- | --- |
| Base dataset | mouse | Neuropixels 1.0 | Kilosort 2.5 |
| IBL | mouse | Neuropixels 1.0 | pyKilosort 2.5 |
| Allen | mouse | Neuropixels 2.0 | Kilosort 4 |
| Mole rat | naked mole rat | Neuropixels 2.0 | Kilosort 4 |
| Monkey | rhesus macaque | Utah array | Kilosort 4 |
| Human | human | Behnke-Fried electrodes | Combinato |

The README claims the models are "agnostic to probe type, species, brain
region, or spike sorter". That is the authors' claim; no dataset in the
table resembles a 32- or 64-site NeuroNexus probe on an Intan headstage.

### The API in SpikeInterface 0.104.5 (read from the wheel)

`spikeinterface.curation.unitrefine_label_units(sorting_analyzer,
noise_neural_classifier=None, sua_mua_classifier=None)`:

- Each classifier argument is a model folder, a `.skops` file, or a
  Hugging Face repo id (anything that is not an existing path). The
  published pair is `SpikeInterface/UnitRefine_noise_neural_classifier`
  and `SpikeInterface/UnitRefine_sua_mua_classifier`; the SpikeInterface
  organization also publishes a `_lightweight` noise/neural model, and the
  first author publishes per-species models under `AnoushkaJain3/`. (The
  0.104.5 curation docs page's example passes `noise_neural_model` /
  `sua_mua_model`, names the 0.104.5 function does not have; the code's
  names above are the ones to call.)
- Cascade: the noise/neural model runs on every unit, the units it calls
  `noise` are removed, the SUA/MUA model runs on the rest. Returns a
  pandas DataFrame indexed by unit id with `unitrefine_label` (`noise`,
  `sua`, `mua`) and `unitrefine_probability` (the winning class's
  probability). It warns when a model returns other labels than expected.
- Under the hood each step is `model_based_label_units(...,
  trust_model=True)`, which loads a scikit-learn `Pipeline` with skops,
  takes the analyzer's metrics through
  `SortingAnalyzer.get_metrics_extension_data()` (every metric extension
  present, concatenated: `quality_metrics` and `template_metrics`), and
  requires exactly the columns in the pipeline's `feature_names_in_`. A
  missing metric is a `ValueError`. Metric parameters that differ from
  the model's `model_info.json` only warn (the UnitRefine entry point does
  not set `enforce_metric_params`). `auto_label_units` is a deprecated
  alias.
- Loading from Hugging Face goes through `huggingface_hub`
  (`list_repo_files`, `hf_hub_download`), so the first use needs network
  access; a local model folder (the `.skops` file plus `model_info.json`)
  needs none and pins the model.
- Packages: the wheel's `full` extra (what INSTALL.md installs) declares
  `skops`, `huggingface_hub` and `scikit-learn<1.8`. INSTALL.md lists
  scikit-learn 1.9.0 as known to work, so the env on the sorting machine
  should be checked for what it actually holds (section 6).

### The metrics it can consume

`quality_metrics` in 0.104.5: `presence_ratio`, `snr`, `snr_baseline`,
`isi_violation`, `rp_violation`, `sliding_rp_violation`, `synchrony`,
`firing_range`, `amplitude_cv`, `amplitude_cutoff`, `amplitude_median`,
`noise_cutoff`, `drift`, `sd_ratio`, plus the PC-based `mahalanobis`,
`d_prime`, `nearest_neighbor`, `nn_advanced`, `silhouette` (computed when
`principal_components` exists, unless `skip_pc_metrics`).

`template_metrics`: `peak_to_trough_duration`,
`main_to_next_extremum_duration`, `half_width`, `repolarization_slope`,
`recovery_slope`, `number_of_peaks`, `waveform_ratios`, `waveform_widths`,
`waveform_baseline_flatness`, and the multi-channel `velocity_fits`,
`exp_decay`, `spread`. The multi-channel ones switch on by themselves at
64 channels or more (`MIN_CHANNELS_FOR_MULTI_CHANNEL_METRICS = 64`),
need 2-D channel locations, and warn when a unit has fewer than 10
channels in its sparsity. So a 64-site probe (H64LP, Buzsaki64) gets them
and a 32-site A4x8 does not unless `include_multi_channel_metrics=True` is
passed.

**Which of these the published models require could not be read from
here** (Hugging Face was unreachable). On the sorting machine:
`load_model(repo_id=...)[0].feature_names_in_` lists them, and
`model_info.json` holds the metric parameters they were computed with.
SpikeInterface's main branch adds `get_required_metrics_from_model` for
the same purpose.

## 2. What the pipeline has today

Facts the design builds on, with where they live:

- **Sorting output** is a phy folder from either driver.
  A Kilosort4 run (`run_ks4.py`) leaves `cluster_KSLabel.tsv` and
  Kilosort4's own copy of it as `cluster_group.tsv` (header
  `cluster_id<TAB>KSLabel`).
  `run_si.py` builds a `SortingAnalyzer` in memory on a 300 Hz high-pass
  of the `.bin` (500 random spikes per unit, waveforms 1 ms before and
  2 ms after, templates, noise levels, spike amplitudes, center-of-mass
  spike locations, six quality metrics with `skip_pc_metrics=True`),
  labels `good` / `mua` by the good-unit criteria (`unitQualityPass`'s
  rules) into `cluster_SILabel.tsv` and copies it to `cluster_group.tsv`
  with the `SILabel` header. Both drivers run in the `kilosort` conda
  Python through `system()`, are copied into the run folder, and write a
  status JSON the app and the scripts poll
  ([python-drivers.md](python-drivers.md)).
- **Label precedence** (`readPhyUnits` → `readClusterLabels`):
  `cluster_group.tsv`, else `cluster_KSLabel.tsv`, else
  `cluster_SILabel.tsv`. `groupSource` is `"phy"` only when
  `cluster_group.tsv`'s header is `group` (`EphysDataset.phyCurated`),
  `"spikeinterface"` when the header is `SILabel`, else `"kilosort"`.
  `curated` means `groupSource == "phy"`. Class mapping: `good` → `su`,
  `mua`, `noise`, `unsorted` → `uns`, anything else → `other` with a
  warning.
- **Re-sorting** (`launchSorting`) moves an earlier sort's curation to
  `previous_<time>`: `cluster_notes.tsv`, phy's `cluster_group.tsv`,
  `cluster_info.tsv`, *any other `cluster_*.tsv` but the sorter's own*,
  and the `.phy` cache. A UnitRefine table would be set aside by this
  rule as it stands.
- **Downstream defaults** drop noise: `Export.Groups` is `["good"
  "mua"]`, `readPhyUnits(IncludeNoise=false)`, the analysis
  `UnitSelection.classes` is `["su" "mua"]`.
- **Quality metrics** (`unitQualityMetrics`, `EphysDataset.unitQuality`)
  are a MATLAB re-implementation of six SpikeInterface metrics, validated
  against golden values, cached in `quality_metrics.json`, judged by
  `unitQualityPass` against `Sorting.Quality`. They are computed lazily
  (Review tab, QC report, exports with `UnitQuality`, `selectUnits` with
  `quality.enabled`). They do not need Python or the `.bin` beyond SNR.
- **Run flow**: steps `probe → behavior → artifacts → sorting → signals →
  spikes → export → analysis`. A background sort is still running when
  the Run moves on; its completion is noticed by the app's monitor
  (`pollKSRuns` → `reportFinished`: manifest rewritten, result row marked)
  or, in a generated script, by `waitForSortingSlot` / `launchSorting`.
  There is no post-sort hook today.
- **The `.bin`** is written by the Sorting step and can be removed by the
  Clean up tab (with the whole sort folder) or live in `Sorting.BinDir`.
  The QC report already copes with a missing `.bin` by drawing the
  templates instead of cut spikes; UnitRefine cannot.

## 3. Where it fits: options

| Option | How | For | Against |
| --- | --- | --- | --- |
| A. Tail of the sort drivers | `run_ks4.py` / `run_si.py` call the labeling at the end of the same process when `settings.json` asks | Works unchanged with background and queued runs, the slot, Stop runs, the status file and the scripts; the `.bin` is certainly there; `run_si.py` already has the analyzer | Holds the GPU slot for CPU work (minutes); `run_ks4.py` gains a SpikeInterface dependency when the option is on |
| B. A pipeline step after Sorting | new step `labels` between `sorting` and `signals` | Clean config and plan rows | A background sort is not finished when the next step runs, so the step would need its own trigger from the monitor and from scripts; a second Python launch per dataset |
| C. On demand | a Review tab button and `EphysDataset.labelUnits` | Re-labeling a sort with another model, labeling old sorts, the validation in section 5 | Not part of a Run on its own |
| D. UnitRefine's own GUI | run the `uv` project outside the pipeline, import its CSV | Needed anyway for training and active learning | No pipeline integration |

Recommendation: **A + C** sharing one driver. The drivers call
`label_units.py` as a subprocess with the same Python (so `run_ks4.py`
stays free of SpikeInterface imports when labeling is off), and the
Review tab / `labelUnits` call the same script directly. D is the route
to a lab model (section 5), not a pipeline component. Running Python
through `pyenv` is out: the repository never does
([python-drivers.md](python-drivers.md)).

## 4. Proposed design

### Driver: `pipeline/@EphysDataset/label_units.py`

Usage: `label_units.py <labels.json>`. MATLAB writes `labels.json` into
the run folder (as `settings.json` and `si_params.json` are): the sort
folder, the `.bin` (`filename`, `n_chan_bin`, `fs`, `data_dtype`,
`bin_scale`), the probe `.json`, `reference`, the sorter, the models
(`noise_neural`, `sua_mua`: repo ids or folders), `n_jobs`, the analyzer
settings (`highpass_hz` 300, `ms_before` 1, `ms_after` 2, as `run_si.py`
uses), `min_probability`, `write_group`, and `provenance`. The script:

1. Reads the sorting with `read_kilosort(folder, keep_good_only=False)`
   (the same phy layout for both sorters; unit ids are the phy cluster
   ids; `remove_empty_units` defaults to true, so clusters with no spikes
   are not labeled and keep the sorter's label).
2. Reads the `.bin` with `read_binary`, attaches the probe as
   `run_si.py`'s `read_probe` does (`kcoords` become shanks), high-passes
   at 300 Hz. These functions should move from `run_si.py` into a small
   module both drivers copy into the run folder, or `label_units.py`
   should carry its own copies; `run_si.py` must not import from the
   repository checkout, because every run keeps the script it used.
3. Builds a sparse `SortingAnalyzer` (memory, or `binary_folder` under
   the run folder for a 2 h × 64-channel recording) and computes exactly
   the extensions the models need: `random_spikes`, `waveforms`,
   `templates`, `noise_levels`, `spike_amplitudes`, `spike_locations`,
   `principal_components` only if a PC metric is required,
   `quality_metrics` with the required names, `template_metrics` with
   `include_multi_channel_metrics` set from the required names (so a
   32-site probe gets `spread` / `velocity_fits` / `exp_decay` when the
   model wants them). The required names come from the loaded models'
   `feature_names_in_` (load them first), so the script never computes
   metrics a model does not use.
4. Calls `unitrefine_label_units(analyzer, noise_neural_classifier=...,
   sua_mua_classifier=...)`. Metric-parameter warnings are captured into
   the status file, not lost in the log.
5. Writes, into the sort folder:
   - `cluster_unitrefine.tsv`: `cluster_id`, `unitrefine_label` (`sua` /
     `mua` / `noise`, verbatim), `unitrefine_probability`. The record of
     what the models said; phy shows both columns.
   - `cluster_URLabel.tsv`: `cluster_id<TAB>URLabel` with `good` / `mua`
     / `noise` (`sua` written as `good`, the vocabulary phy and
     `readPhyUnits` use). A unit under `min_probability` keeps the
     sorter's own label here, and `cluster_unitrefine.tsv` still holds
     the model's call.
   - when `write_group` is on and `cluster_group.tsv` is **not** phy's
     (header not `group`): a copy of `cluster_URLabel.tsv` as
     `cluster_group.tsv`, header kept, the trick Kilosort4 and `run_si.py`
     use. A phy-curated `cluster_group.tsv` is never touched: the script
     refuses and says so in the status.
   - `unitrefine_status.json`: `state`, counts per label, the models
     (ids or folders, and the contents of each `model_info.json`:
     SpikeInterface version, metric names and parameters), the metrics
     computed, the warnings, `spikeinterface` / `sklearn` / `skops`
     versions, provenance. The equivalent of `ks4_status.json` for this
     stage, and the record the QC report and the manifest read.

### MATLAB

- `EphysDataset.labelUnits(Method=, Models=, ResultsDir=, MinProbability=,
  WriteGroup=, PythonExe=, CondaEnv=, Wait=)`: writes `labels.json`,
  runs the driver through `system()` as `exportNWB` does (blocking: it is
  minutes, not hours), returns the status. Refuses when the `.bin` the
  sort's `settings.json` names is gone (`EphysDataset:labelUnits:NoBin`).
- `readClusterLabels`: header `URLabel` → `groupSource "unitrefine"`;
  `curated` stays `groupSource == "phy"`. `readPhyUnits` / `unitTable`
  gain `labelProbability` (from `cluster_unitrefine.tsv` through
  `lookupByID`, NaN when absent).
- `launchSorting`: `cluster_unitrefine.tsv` and `cluster_URLabel.tsv`
  are already moved to `previous_*` by the "any other `cluster_*.tsv`"
  rule; add `unitrefine_status.json` to what is set aside, and have the
  driver delete its own files first, as `run_si.py` does.
- `phyStatus`: unchanged (it only reads phy's own files).
- Config: `Sorting.Labels` (or `Sorting.Curation`) with `Method`
  (`"sorter"` | `"criteria"` | `"unitrefine"`), `NoiseNeuralModel`,
  `SuaMuaModel`, `MinProbability` (NaN = off), `WriteGroup`. `validate`
  checks the method, that a model is named, and that a folder model
  exists when `CheckPaths`. `"criteria"` would give a Kilosort4 sort the
  good / mua labeling `run_si.py` already gives SpikeInterface sorts,
  from the same driver; a side benefit, not the goal.
- `runKilosort` / `runSpikeInterface`: when the method is not `"sorter"`,
  put the labeling settings into `settings.json`; the drivers call
  `label_units.py` after the sort and fold its status into theirs
  (`ks4_status.json` gains `labels: {...}`), so `sortRunState`, the
  monitor and `waitForSortingSlot` need nothing new. The Sorting tab's
  log line and result row say "N units: good a, mua b, noise c
  (UnitRefine)".
- Review tab: the summary's groups line gets "groups by UnitRefine
  (URLabel)"; a `P` column beside `Group`; a **Label units...** button
  that runs `labelUnits` on the loaded sort and reloads. The QC report
  lists the models and `model_info.json` contents from the status file.
- Generated scripts (`EphysPipelineScript`): the labeling options are
  part of the sort call's settings, so the sorting section passes them
  through; nothing else changes.
- Manifest: `m.sorting` gains `labels` (`source`, models, counts) from
  the status file.
- Analysis: optional `UnitSelection.minLabelProbability`; otherwise
  nothing, since classes and groups already filter.

### Precedence, stated once

phy's `cluster_group.tsv` (header `group`) always wins. Otherwise
`cluster_group.tsv` holds the newest automatic label with its own header
(`KSLabel`, `SILabel` or `URLabel`), which says where it came from. The
raw sorter and UnitRefine tables stay beside it. Nothing is ever
overwritten by the labeling except the sorter-style copy, and phy
curation started after labeling starts from the UnitRefine labels, which
is the intended workflow (curate what the model doubts).

## 5. Validation before any label is used

This is the gate, not an afterthought. The pipeline already knows which
sorts phy curated (`phyStatus`: state `saved`, `modified`, the labels
set in phy), and each curated sort has the `.bin` unless cleaned up.

1. Run the driver on each curated sort with `write_group` off (labels to
   the side tables only; nothing changes).
2. Compare per unit: phy's label against UnitRefine's, against
   Kilosort4's `KSLabel`, and against the good-unit criteria. A small
   helper (`compareUnitLabels(resultsDir)`: confusion matrices, balanced
   accuracy, agreement by probability band, per probe type) belongs with
   `writeUnitQualityReport`. The comparison must be within one sort:
   cluster ids change between sorts, which is why `launchSorting` sets
   curation aside.
3. Decide by probe type whether the published models are usable, and at
   what `MinProbability`. Record the outcome in this page.
4. If they are not: train a lab model. `train_model(mode="analyzers",
   labels=[...], analyzers=[...], folder=..., metric_names=...)` in
   `spikeinterface.curation` takes analyzers built exactly as the driver
   builds them, with the phy labels (`good` → `sua`). The UnitRefine
   README asks for at least 6 labels per class, about 10% of a
   recording's clusters labeled, and more than 50 clusters in all, and
   its GUI offers active learning on the low-confidence clusters. The
   model folder (`.skops` + `model_info.json`) then goes into the config
   as the classifier path; keep it under version control or on the lab
   share, and record it in every status file.

Data fidelity rules the design keeps: the model's own labels and
probabilities are stored unchanged; the applied label is a separate
file; phy's curation is never overwritten; every run records the model
and its metric parameters; nothing is deleted on re-sorting (moved to
`previous_*`).

## 6. Risks and unknowns

- **Required metrics unknown here.** Confirm on the sorting machine
  before writing the driver's compute list (section 1). If the models
  need PC metrics (`nearest_neighbor`, `silhouette`, ...), the stage
  needs `principal_components`, the slow part.
- **Out-of-distribution data.** NeuroNexus 32/64-site probes on Intan
  versus the training table above; waveform metrics depend on sampling
  rate, high-pass and contact pitch, and the multi-channel metrics on the
  layout along the shank. Only section 5 settles it.
- **scikit-learn / skops versions.** The models are scikit-learn
  pipelines serialized with skops. `unitrefine_label_units` silences
  scikit-learn's `InconsistentVersionWarning`, and SpikeInterface's main
  branch carries a patch for a `SimpleImputer` attribute rename across
  scikit-learn 1.5 that 0.104.5 does not have. The 0.104.5 `full` extra
  pins scikit-learn below 1.8 while INSTALL.md records 1.9.0 as known to
  work. Load both models once in the env and run them on one sort before
  anything else; pin what works in INSTALL.md.
- **Network and reproducibility.** A repo id downloads on first use and
  follows the repo's latest revision; a local folder does neither. Prefer
  a local copy, with its `model_info.json` in every status file.
- **The `.bin`.** Labeling after Clean up, or of a sort whose `.bin`
  was never kept, is impossible; the method must say so rather than fall
  back to Kilosort4's templates (whitened, rebuilt from PCs; not what the
  models saw).
- **Time.** Waveforms, templates and metrics over a 2 h × 64-channel
  `.bin` on CPU: minutes to tens of minutes, unmeasured here;
  `run_si.py` does the same work for its sorts. Option A holds the
  Kilosort4 slot meanwhile; `MaxConcurrent` already bounds that.
- **API drift.** SpikeInterface renamed `auto_label_units` to
  `model_based_label_units` within 0.10x and documents the UnitRefine
  arguments under two names. Pin 0.104.5 as INSTALL.md does and call the
  names in the code.
- **Downstream semantics.** `noise` units vanish from exports and plots
  by default. `WriteGroup` off (labels in the side tables only) is the
  safe default until section 5 is done.

## 7. Work involved

| Part | Files |
| --- | --- |
| Driver | new `pipeline/@EphysDataset/label_units.py`; `run_ks4.py`, `run_si.py` (call it; `read_probe` shared) |
| Dataset | new `@EphysDataset/labelUnits.m`; `readPhyUnits.m` (header, probability column); `launchSorting.m` (status file set aside); `runKilosort.m`, `runSpikeInterface.m` (settings); `EphysDataset.m` (declarations, manifest) |
| Config | `@EphysPipelineConfig/defaults.m`, `validate.m`, `normalizeSection.m` |
| App | Sorting tab fields, Review tab summary / column / button, `pollKSRuns` result text |
| Scripts | `@EphysPipelineScript` sorting section |
| Analysis | `selectUnits` probability filter (optional); `unitTable` column |
| Validation | `compareUnitLabels` helper; QC report section |
| Tests | `test_SortedUnits` (new header, column), `test_SpikeInterfaceSorting` pattern for the driver (dry run, stand-in python, a real run when SpikeInterface is in the env), `test_SortingConcurrency` (set-aside), `test_EphysPipelineConfig`, `test_EphysPipelineApp`, `test_EphysPipelineScript`, `test_UnitQuality` (report) |
| Docs | this page; `python-drivers.md`, `file-formats.md` (the three new files), `EphysDataset.md`, `EphysPipelineApp.md`, `INSTALL.md` (skops, huggingface_hub, the model download), README Dependencies |

## Sources

- Preprint record: bioRxiv 10.1101/2025.03.30.645770 (abstract and
  metadata read through the bioRxiv API).
- UnitRefine repository: https://github.com/anoushkajain/UnitRefine
  (README, read 2026-10-07).
- SpikeInterface 0.104.5 wheel from PyPI: `curation/unitrefine_curation.py`,
  `curation/model_based_curation.py`, `curation/train_manual_curation.py`,
  `extractors/phykilosortextractors.py`, `metrics/quality/*.py`,
  `metrics/template/template_metrics.py`, package metadata.
- SpikeInterface main branch: `curation/model_based_curation.py`
  (`get_required_metrics_from_model`, the scikit-learn imputer patch).
- Not reachable from the writing session: the Hugging Face model cards and
  the preprint's full text.
