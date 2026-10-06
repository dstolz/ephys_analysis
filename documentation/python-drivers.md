# Python drivers

The MATLAB classes never import Python through `pyenv`. They call a Python
executable through `system()`, with the paths double-quoted:

```text
"<PythonExe>" "<script>" <args...>
conda run -n <CondaEnv> "<PythonExe>" "<script>" <args...>     % when CondaEnv is set
```

The scripts below are checked into the repository. The sorting drivers are
**copied** into each run folder before they are executed, so every run keeps
the exact script it used. A background sorting run on Windows goes through a
batch file written to the run folder, `ks4_launch.cmd` (`si_launch.cmd` for
a SpikeInterface sorter), which runs that command (every path in quotes of
its own, so paths with `&` or `^` work) and then writes the exit marker
`ks4_exit.txt`.

| Script | Called by | Environment needs |
| --- | --- | --- |
| [`run_ks4.py`](../pipeline/@EphysDataset/run_ks4.py) | `EphysDataset.runKilosort` (the pipeline's Sorting step) | kilosort, torch |
| [`run_si.py`](../pipeline/@EphysDataset/run_si.py) | `EphysDataset.runSpikeInterface` (the Sorting step with a SpikeInterface sorter) | spikeinterface[full], the sorter |
| [`si_sorters.py`](../pipeline/@EphysDataset/si_sorters.py) | `EphysDataset.spikeInterfaceSorters` (the Sorting tab's **Find SpikeInterface sorters**) | spikeinterface |
| [`probe_tool.py`](../pipeline/@EphysPipelineApp/probe_tool.py) | `EphysPipelineApp.runProbeTool` (`runProbeToolWith`) / `ProbeDesignerApp` / `ChannelMapperApp` | probeinterface |
| [`nwb_export.py`](../pipeline/@EphysDataset/nwb_export.py) | `EphysDataset.exportNWB` (the Export step's `nwb` format) | pynwb, nwbinspector |

Versions known to work are listed in
[Installation](../pipeline/INSTALL.md#4-miniconda-and-the-kilosort-environment):
Python 3.11, kilosort 4.1.7, probeinterface 0.3.2, torch 2.7.1 (CUDA 11.8).
How sorting runs are launched and logged, and how GPUs are shared out, is
under [Environment notes](#environment-notes).

---

## `run_ks4.py`

Usage: `run_ks4.py <settings.json> [--device <torch device>]`.

`runKilosort` writes the `.bin` first, with the artifact periods erased
(unless `BinFile` names an existing one), then `settings.json` and a copy of
this script into the run folder
([Running Kilosort4](EphysDataset.md#running-kilosort4)). The script:

1. Sorts the `settings.json` keys with `split_settings`, except the
   driver's own keys: `probe`, `data_dtype`, `torch_device`, `bin_scale`
   (the `.bin`'s units per µV that `readPhyUnits` reads and Kilosort4 is
   not given), `shank_spacing`, `true_probe` and `provenance` (the code and
   config that wrote the run, kept for the record):
   - `run_kilosort` arguments (`do_CAR`, `invert_sign`, `save_extra_vars`,
     `save_preprocessed_copy`, `bad_channels`, `clear_cache`,
     `torch_thread_lim`) are passed as arguments;
   - keys in Kilosort4's `RECOGNIZED_SETTINGS` become `settings`;
   - anything else is **dropped** and logged. Kilosort4 would otherwise refuse
     the whole run with "Unrecognized settings".
2. `--device`, else a `torch_device` in the settings (`"auto"` = none),
   becomes `run_kilosort`'s `device=torch.device(...)`, logged as
   `Kilosort4 on torch device <device>`. Without either, Kilosort4 takes the
   first GPU (or the CPU).
3. Loads the probe with `kilosort.io.load_probe(cfg['probe'])` and calls
   `kilosort.run_kilosort(settings, probe, filename, data_dtype,
   results_dir, **run_args)`, which writes the phy output into
   `results_dir`.
4. With a `true_probe` (the probe was sorted with its shanks moved apart,
   [shank spacing](EphysDataset.md#shank-spacing)), `restore_positions` writes
   the true positions back: `channel_positions.npy` from `true_probe` by
   `chanMap`, and `spike_positions.npy` moved back by the shift of each
   spike's nearest site in the spaced layout.

It writes `ks4_status.json` (`{"state": "done", "num_units", "dropped_params"}`
or `{"state": "error", "message", "traceback"}`,
[format](file-formats.md#ks4_statusjson)) in `results_dir` and prints
`KILOSORT4_DONE units=<n>` / `KILOSORT4_ERROR`. An error in any of the steps
above, a bad probe file included, gives the error form, and the script then
exits with that error.

### Channel-numbering caveat

The probe's `chanMap` values index `.bin` rows (0-based positions), as do
`ExcludeChannels` (1-based). Probe sites are not matched to channels by their
hardware number (`EphysDataset.ChannelNumbers`), for sorting and in the app
alike: the Artifacts tab's probe order (`channelLayout`) and the analysis
probe maps read `chanMap` as `.bin` rows too. The two agree when the
channel numbers equal the positions (0, 1, 2, … with no gaps). When channels
were disabled at acquisition (gaps in the numbering), the probe must already
account for the gap. A recording spanning more than one Intan port (`A-000`
and `B-000`) does not give distinct numbers, so its channels are numbered by
position (`EphysReader:ChannelNumbersNotUnique` warns).

---

## `run_si.py`

Usage: `run_si.py <settings.json> [--device <torch device>]`.

`runSpikeInterface` writes the `.bin` first, as `runKilosort` does, then
`settings.json`, the sorter's parameters (`si_params.json`, as edited) and a
copy of this script into `<output folder>/si_<sorter>`
([Running a SpikeInterface sorter](EphysDataset.md#running-a-spikeinterface-sorter)).
`settings.json` holds `sorter`, `filename`, `n_chan_bin`, `fs`, `data_dtype`,
`probe`, `results_dir`, `sorter_params` (the parameter file, beside it),
`reference` (`none` / `car` / `cmr`: what the `.bin` carries), `quality`
(the good-unit criteria), `n_jobs`, `bin_scale` and `provenance`. The script:

1. merges `si_params.json` over `spikeinterface.sorters.get_default_sorter_params`
   (nested objects key by key) and drops, with a note in the log, top-level
   names the sorter does not have (`run_sorter` would refuse the run);
2. when `reference` is `car` / `cmr`, keeps the sorter from referencing the
   data again: a `do_CAR` / `car` parameter is set false, and the
   `common_reference` that SpikeInterface's internal sorters call on 32
   channels or more is made to return the recording unchanged in the
   sorter's module (logged as `... so it is referenced once`);
3. sets SpikeInterface's jobs to `n_jobs` threads (process pools import
   SpikeInterface again in every worker on Windows, which took most of a
   run's time), deletes an earlier sort's phy files from the folder, reads
   the `.bin` (`read_binary`, no gain: the templates stay in `.bin` units)
   and attaches the probe (`kcoords` become the channel groups);
4. runs `spikeinterface.sorters.run_sorter` in `si_work` and loads the
   sorting into memory, without its empty units (no unit at all is an
   error). `run_sorter` hands the sorter the recording as a JSON file that
   keeps the contact positions and channel groups but not the probe, so
   SpikeInterface's own sorters rebuild a probe from the positions (all they
   use) and warn "There is no Probe attached"; the script silences that
   warning;
5. on a 300 Hz high-pass of the `.bin`, builds a sparse SortingAnalyzer in
   memory: random spikes (500 per unit), waveforms (1 ms before, 2 ms after),
   templates, noise levels, spike amplitudes, spike locations (centre of
   mass) and the quality metrics `firing_rate`, `presence_ratio`, `snr`,
   `isi_violation`, `amplitude_cutoff` and `drift`;
6. labels each unit `good` or `mua` with `unit_labels`, which applies the
   criteria as `unitQualityPass` does (a `NaN` threshold is not applied; a
   `NaN` metric passes unless `unknown` is `fail`);
7. fits the PCs one channel after another (a process pool otherwise) and
   writes the phy files with `spikeinterface.exporters.export_to_phy`
   (`copy_binary=False`), then makes them read as Kilosort4's do:
   `templates.npy` dense (no `template_ind.npy`), `whitening_mat(_inv).npy`
   the identity, `channel_map.npy` the `.bin` rows of the sorted channels,
   `channel_shanks.npy` their `kcoords`, `amplitudes.npy` magnitudes,
   `spike_positions.npy` the spike locations, `params.py` naming the `.bin`
   with all its channels, and `cluster_SILabel.tsv` with its copy as
   `cluster_group.tsv` (header `SILabel`, so it does not read as phy's);
8. adds `nt0min` (the template sample on the spike time) to
   `settings.json` and deletes `si_work`.

It writes `si_status.json` (`{"state": "done", "num_units", "num_good",
"sorter", "dropped_params"}` or `{"state": "error", "message",
"traceback"}`) in the run folder and prints `SPIKEINTERFACE_DONE units=<n>
good=<n>` / `SPIKEINTERFACE_ERROR`. `--device` is logged and not used.
Known to work: spikeinterface 0.104.5 with tridesclous2 (a 32-channel
synthetic recording, 18 units for 16 in the recording); the internal sorters
need the `[full]` extras (pandas, scikit-learn, numba, networkx).

## `si_sorters.py`

Usage: `si_sorters.py <output.json>`. Lists the sorters
`spikeinterface.sorters.installed_sorters()` gives, each with its version, its
default parameters as indented JSON text (so nulls and nested objects reach
the Sorting tab as they are) and the description of each parameter
(`get_sorter_params_description`), in `<output.json>`.

---

## `probe_tool.py`

Usage:

```text
probe_tool.py list-library [--tag TAG]
probe_tool.py get-library <manufacturer> <probe_name> <out.json> [--name N] [--notes S] [--wiring w0,w1,...] [--n-chan K]
probe_tool.py get-contacts <manufacturer> <probe_name> <out.json>
probe_tool.py generate <spec.json> <out.json>
probe_tool.py describe <in.json>
```

| Subcommand | Output |
| --- | --- |
| `list-library` | prints a JSON array of `{manufacturer, probes}`. If probeinterface lacks the listing helpers, it falls back to `neuronexus`, `cambridgeneurotech` and `plexon` with empty probe lists |
| `get-library` | `probeinterface.get_probe(...)` → KS4 JSON written to `out.json`; prints `{out, n_contacts}` |
| `get-contacts` | `probeinterface.get_probe(...)` → `{manufacturer, probe, contact_ids, x, y, shank_ids}` written to `out.json` (not a KS4 file: the contact ids are the vendor's site numbers, for `ChannelMapperApp`'s probe designs); prints `{out, n_contacts}` |
| `generate` | the spec `{type, params, name, notes, n_chan, wiring}` is built with `generate_linear_probe`, `generate_multi_columns_probe` or `generate_tetrode` → KS4 JSON; prints `{out, n_contacts}` |
| `describe` | prints positions / shank ids / device channel indices / `n_chan` / notes for a KS4 JSON or a probeinterface JSON |

The conversion to KS4 JSON (`pi_probe_to_ks4`) works as follows:

- `xc`, `yc` are the contact positions, rounded to 4 decimals.
- `kcoords` are the shank ids mapped to integers in first-seen order.
- `chanMap` is the explicit `--wiring` if given, else the probe's
  `device_channel_indices` if present and all ≥ 0, else `0..n−1`.
- `n_chan` defaults to `max(n, max(chanMap)+1)`.

`runProbeTool` takes the Python and conda env from the Sorting tab and hands them to the static `EphysPipelineApp.runProbeToolWith`, which assembles the command. `ChannelMapperApp` opened on its own calls `runProbeToolWith` with the Python the app last used (its `PythonExe` preference).

On failure the script prints `PROBE_TOOL_ERROR: ...` and exits 1.
`runProbeTool` raises `EphysPipelineApp:runProbeTool:Failed` on a non-zero exit
or that marker. It raises `:NoSubcommand` when called without a subcommand,
`:NoPython` when no Python exe is set, and `:ScriptMissing` when
`probe_tool.py` is not next to the class. On success it `jsondecode`s the
**last** output line that parses as JSON, and returns the raw text when no
line does.

---

## `nwb_export.py`

Usage: `nwb_export.py <stage.json>`. `EphysDataset.exportNWB` fills a staging
folder `~<name>.nwbstage` next to the target and runs the script on it
(`"<PythonExe>" "<script>" "<stage.json>"`, or through `conda run -n`).

| Staging file | Contents |
| --- | --- |
| `stage.json` | format `ephys_analysis-nwb-stage/1`, the target, the session and subject metadata, the device, electrode groups and electrodes (text columns inline, numbers as keys into `stage.npz`), the signals (file, kind `lfp` / `filtered` / `aux`, filtering, description), the units' and trials' columns, the digital lines, the reason for the invalid times |
| `stage.npz` | every number as MATLAB holds it (`writeNPZ`): rates, conversions, electrode positions and rows, spike times (concatenated) with the end index per unit, unit ids and electrodes, `units_resolution`, trial times and numeric columns, the lines' `[start stop]` tables, `invalid_times` |
| `<SIG>.npy` | each signal as stored, shape `(channels, samples)` in C order, so a block of samples is one contiguous run per channel |

The script:

1. Builds an `NWBFile` with pynwb: the session (`session_start_time` from
   the ISO time with its UTC offset that MATLAB computes, so Python needs no
   time-zone database), the subject, the device, one electrode group per
   shank, the electrodes table, and each signal in its container. The
   signals are streamed from a memory map with `DataChunkIterator`, chunked
   `(16384, channels)` and gzip-compressed (level 4) with `H5DataIO`. Then
   come the units (`resolution` set), the trials, one `TimeIntervals` per
   line with pulses, and `invalid_times` with a `reason` column.
2. Writes `~<name>.partial.nwb` next to the target with `NWBHDF5IO`.
3. Runs `nwbinspector.inspect_nwbfile` on it, which includes pynwb's
   validation, unless `inspect` is false.
4. Renames the file into place and writes `nwb_status.json`:
   `{"state": "done", "file", "inspector": [messages], "versions"}`, or
   `{"state": "error", "message", "traceback", "versions"}` after removing
   the partial file. Its last line is `NWB_EXPORT_DONE` or
   `NWB_EXPORT_ERROR`.

Nothing is converted. Each signal keeps its dtype (float32 µV) with
`conversion` 1e-6, and every time is written as MATLAB staged it.
Known to work: Python 3.11, pynwb 4.2.0, hdmf 6.2.0, nwbinspector 0.7.2,
h5py 3.16.0, numpy 2.4.6. The script ran on synthetic staging folders,
including the shapes MATLAB's `jsonencode` gives one-element lists; reading
the file back returned every staged value unchanged.

---

## Environment notes

- Conda need not be on `PATH`: the Python exe is called by its full path.
  Setting **Conda env** wraps the call in `conda run -n <env>`, which needs
  `conda` on `PATH`.
- A blocking sorting run (`Sorting.Execution` `blocking`) captures the
  output and writes it to `ks4_run.log` (`si_run.log`) once the process
  exits. A background run redirects the output there as it comes, with
  `PYTHONUNBUFFERED=1` so that Python does not hold it back. The status a
  background launch returns is the launcher's, not the sorter's exit code:
  read `ks4_status.json` (`si_status.json`).
- `launchSorting` deletes the results folder's `ks4_status.json` and
  `ks4_exit.txt` before each launch, so both describe the latest run only.
  A background run writes the empty `ks4_exit.txt` once its process exits.
  An exit marker without a status file means the run failed before the
  driver could report, for example a missing Python or conda env
  ([`ks4_exit.txt`](file-formats.md#ks4_exittxt)).
- A GPU is optional, but Kilosort4 is much faster on one.
  `python -c "import torch; print(torch.cuda.is_available())"` checks for
  one, and `python -c "import torch; print(torch.cuda.device_count())"`
  counts them. On a machine with several, list them in `Sorting.Devices`
  (the [Run](EphysPipelineApp.md#run) tab's **GPUs**, for example
  `cuda:0, cuda:1`) so that runs going at once each get their own. A
  background run is given the device the fewest running runs use, a
  blocking run the first, and the driver gets it as `--device cuda:N`.
