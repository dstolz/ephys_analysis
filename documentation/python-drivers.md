# Python drivers

The MATLAB classes never import Python through `pyenv`. They call a Python
executable through `system()`, with the paths double-quoted:

```text
"<PythonExe>" "<script>" <args...>
conda run -n <CondaEnv> "<PythonExe>" "<script>" <args...>     % when CondaEnv is set
```

The scripts below are checked into the repository. The two sorting drivers are
**copied** into each run folder before they are executed, so every run keeps
the exact script it used.

| Script | Called by | Environment needs |
| --- | --- | --- |
| [`run_si_ks4.py`](../pipeline/@EphysDataset/run_si_ks4.py) | `EphysDataset.runSpikeInterface` (the pipeline's Sorting step) | spikeinterface, probeinterface, neo, kilosort, torch |
| [`run_ks4.py`](../pipeline/@EphysDataset/run_ks4.py) | `EphysDataset.runKilosort` (native `.bin` engine, `Sorting.Engine = "kilosort"`) | kilosort, torch |
| [`probe_tool.py`](../pipeline/@EphysPreprocessingApp/probe_tool.py) | `EphysPreprocessingApp.runProbeTool` / `ProbeDesignerApp` | probeinterface |

Versions known to work are listed in [INSTALL.md](../pipeline/INSTALL.md):
spikeinterface 0.104.5, kilosort 4.1.7, probeinterface 0.3.2, neo 0.14.4,
torch 2.7.1.

---

## `run_si_ks4.py`

Usage: `run_si_ks4.py <si_config.json> [--check] [--device <torch device>]`.
The config schema is in [file-formats.md](file-formats.md#si_configjson).
`--device` (added by `EphysDataset.launchSorting`, one GPU per run with
`Sorting.Devices`) sets the wrapper's `torch_device`, over any
`torch_device` in the config's `ks4` block, and logs
`Kilosort4 on torch device <device>`.

### Pipeline (`build_pipeline`)

1. **Load** (`load_recording`), dispatching on the config's `recording.reader`
   (written by the dataset reader's `siRecordingSpec()`; configs without it
   are treated as Intan):
   - `intan`, split layouts: `<folder>/info.rhd` with
     `spikeinterface.extractors.read_intan`, using the stream whose name
     contains `"amplifier"` (else the first stream).
   - `intan`, traditional: every listed `.rhd` that exists,
     `concatenate_recordings` in the order given (the MATLAB side passes
     `ds.Files`, which is in chronological order).
   - `binary` (the universal `recording.json` format): `read_binary` over the
     flat channel-major file with the descriptor's `dtype`, `n_chan`, `fs`,
     `gain_to_uV` and `offset`.
   - `openephys-binary`: `read_binary` over each recording's `continuous.dat`
     (int16, every stream channel), concatenated, then the headstage channels
     (`channel_indices`) with their `gain_to_uV`.
   - `openephys-legacy`: `OpenEphysLegacyRecording`, which memory-maps the
     headstage `.continuous` files as 2070-byte records (big-endian samples)
     and exposes each recording's records (`first_record`, `n_records`) as a
     segment; the segments are concatenated.
   - `openephys-nwb`: `OpenEphysNwbRecording`, which reads the stream's
     `ElectricalSeries` rows (`row_start`, `n_samples` per recording) through
     **h5py**. The kilosort environment does not include h5py: install it
     (`conda install -n kilosort h5py`) or sort NWB sessions with the native
     engine (`Sorting.Engine = "kilosort"`), which reads the file in MATLAB.
   The two Open Ephys classes are defined at module level (with a module
   `__version__`) because SpikeInterface serializes a recording by class path
   and rebuilds it. Every loader returns the rows the MATLAB reader returns.
   Then the channels are **renamed to their channel numbers**
   (`recording.channel_numbers`, the dataset's `ChannelNumbers`); a count
   mismatch or a repeated number is an error.
2. **Unsigned → signed.** If the dtype is unsigned, `unsigned_to_signed` is
   applied (Kilosort4 refuses unsigned input).
3. **Crop.** `tmin`/`tmax` are removed from the `ks4` settings block and applied
   as a `frame_slice`, because the SpikeInterface Kilosort4 wrapper does not
   accept them.
4. **Manual exclusions.** `exclude_channels` (0-based positions) are mapped to
   channel IDs **before** the probe is attached.
5. **Attach the probe** (`build_probe`):
   - The KS4 JSON `xc`/`yc`/`chanMap`/`kcoords` are read, and circular contacts
     of radius 6 µm are created.
   - Each `chanMap` value is matched to the recording channel **named by that
     number** (the channel numbers of step 1: `A-016` → 16, `CH17` → 16).
   - Probe sites whose number is not present in the recording are dropped and
     logged ("disabled at acquisition?").
6. **Bandpass**, if `preprocessing.filter.enabled`: `bandpass_filter(freq_min,
   freq_max)`.
7. **Bad channels.**
   - When `detect_bad_channels.enabled`, `detect_bad_channels(method)` runs on
     the bandpassed recording if one exists, otherwise on a 300 Hz
     `highpass_filter` view.
   - The detections are **unioned** with the manual exclusions.
   - The union is removed (`remove_channels`) or interpolated
     (`interpolate_bad_channels`) according to `action`.
   - If the union covers every channel, nothing is removed and a warning is
     logged.
8. **Common reference**, if enabled: `common_reference(operator,
   reference='global')`.
9. **Silence artifacts**, if `silence_periods.enabled`:
   - Each `[t0 t1]` period is shifted by `−tmin` and converted with
     `round(t·fs)`.
   - The result is clamped to the recording, and periods with `end <= start`
     are dropped.
   - The share of the recording they cover is logged. If it is over half
     (`MAX_SILENCED_FRACTION`), the run stops with an error instead of
     sorting. Kilosort4 would find no spikes in the silenced data and fail
     inside its template SVD.
   - With `mode: "noise"` (the default), the per-channel noise level is
     measured over the **whole preprocessed recording** first
     (`noise_levels_whole_recording`): each 10 s block contributes its median
     and robust SD (1.4826 x MAD), and the level is the median of those, so
     the artifacts about to be replaced cannot inflate it. It is measured on a
     high-pass view at `noise_band_hz` (300 Hz; `0` = as recorded), because the
     fill is white and a broadband level - dominated by the LFP - would put far
     more power into the spike band than the signal around it carries. Only
     the measurement is filtered, never the traces.
   - The periods are applied with `silence_periods(mode, noise_levels, seed)`:
     per-channel Gaussian noise at that level, or zeros with `mode: "zeros"`.
     A block of zeros across every channel reads to Kilosort4 as a signal
     discontinuity, which skews its whitening, thresholds and drift estimate.
   - A small in-process patch of `SilencedPeriodsRecording.__init__` rebuilds
     the structured `periods` array after SpikeInterface's JSON round-trip.

### Sorting

- `ks4_params` keeps only the `ks4` keys that
  `get_default_sorter_params('kilosort4')` accepts. The rest are **dropped** and
  logged.
- `delete_recording_dat` defaults to `False`, so the preprocessed
  `recording.dat` is kept for phy.
- The sorter runs as `run_sorter('kilosort4', rec, folder=results_dir,
  remove_existing_folder=True, verbose=True, **params)`. `results_dir` is
  `<kilosort4>/si` and is **wiped** on every run. MATLAB's bookkeeping files live
  one level up, so they survive.

### Status and dry runs

- Success: `ks4_status.json` = `{"state": "done", "num_units", "bad_channels"
  (channel numbers, as strings), "dropped_params"}`, and the log line
  `KILOSORT4_DONE units=N`.
- Failure: `{"state": "error", "message", "traceback"}`, the log line
  `KILOSORT4_ERROR`, and the exception is re-raised.
- `--check` builds the pipeline and the parameter list and prints
  `CHECK OK: ...` without sorting. It does not write `ks4_status.json`. Run it by
  hand in the configured environment:

  ```bat
  "<PythonExe>" "<kilosort4>\run_si_ks4.py" "<kilosort4>\si_config.json" --check
  ```

### Channel-numbering caveat

`build_probe` matches `chanMap` values to channel **numbers**
(`EphysDataset.ChannelNumbers`), whereas `exclude_channels` and the legacy
`.bin` engine use **positions**. The two agree when the channel numbers equal
the positions (0, 1, 2, … with no gaps). They differ when channels were
disabled at acquisition (gaps in the numbering): the probe then drops the
missing sites, while `.bin` rows are positions. A recording spanning more than
one Intan port (`A-000` and `B-000`) does not give distinct numbers, so its
channels are numbered by position (`EphysReader:ChannelNumbersNotUnique`
warns), and a probe for it must use positions `0..n-1`.

---

## `run_ks4.py`

Usage: `run_ks4.py <settings.json> [--device <torch device>]`.

1. Loads the probe with `kilosort.io.load_probe(cfg['probe'])`.
2. Sorts the other `settings.json` keys (except `probe`, `data_dtype` and
   `torch_device`) with `split_settings`:
   - `run_kilosort` arguments (`do_CAR`, `invert_sign`, `save_extra_vars`,
     `save_preprocessed_copy`, `bad_channels`, `clear_cache`,
     `torch_thread_lim`) are passed as arguments;
   - keys in Kilosort4's `RECOGNIZED_SETTINGS` become `settings`;
   - anything else is **dropped** and logged. Kilosort4 would otherwise refuse
     the whole run with "Unrecognized settings".
3. `--device`, else a `torch_device` in the settings (`"auto"` = none),
   becomes `run_kilosort`'s `device=torch.device(...)`, logged as
   `Kilosort4 on torch device <device>`. Without either, Kilosort4 takes the
   first GPU (or the CPU).
4. Calls `kilosort.run_kilosort(settings, probe, filename, data_dtype,
   results_dir, **run_args)`.

It writes `ks4_status.json` (`{"state": "done", "num_units", "dropped_params"}`
or `{"state": "error", "message", "traceback"}`) in `results_dir` and prints
`KILOSORT4_DONE units=<n>` / `KILOSORT4_ERROR`.

---

## `probe_tool.py`

Usage:

```text
probe_tool.py list-library [--tag TAG]
probe_tool.py get-library <manufacturer> <probe_name> <out.json> [--name N] [--notes S] [--wiring w0,w1,...] [--n-chan K]
probe_tool.py generate <spec.json> <out.json>
probe_tool.py describe <in.json>
```

| Subcommand | Output |
| --- | --- |
| `list-library` | prints a JSON array of `{manufacturer, probes}`. If probeinterface lacks the listing helpers, it falls back to `neuronexus`, `cambridgeneurotech` and `plexon` with empty probe lists |
| `get-library` | `probeinterface.get_probe(...)` → KS4 JSON written to `out.json`; prints `{out, n_contacts}` |
| `generate` | the spec `{type, params, name, notes, n_chan, wiring}` is built with `generate_linear_probe`, `generate_multi_columns_probe` or `generate_tetrode` → KS4 JSON; prints `{out, n_contacts}` |
| `describe` | prints positions / shank ids / device channel indices / `n_chan` / notes for a KS4 JSON or a probeinterface JSON |

The conversion to KS4 JSON (`pi_probe_to_ks4`) works as follows:

- `xc`, `yc` are the contact positions, rounded to 4 decimals.
- `kcoords` are the shank ids mapped to integers in first-seen order.
- `chanMap` is the explicit `--wiring` if given, else the probe's
  `device_channel_indices` if present and all ≥ 0, else `0..n−1`.
- `n_chan` defaults to `max(n, max(chanMap)+1)`.

On failure the script prints `PROBE_TOOL_ERROR: ...` and exits 1.
`runProbeTool` raises `EphysPreprocessingApp:runProbeTool:Failed` on a non-zero exit
or that marker. On success it `jsondecode`s the **last** stdout line that parses
as JSON.
