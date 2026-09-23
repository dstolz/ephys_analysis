# Python drivers

The MATLAB classes never import Python through `pyenv`. They call a Python
executable through `system()`, with the paths double-quoted:

```text
"<PythonExe>" "<script>" <args...>
conda run -n <CondaEnv> "<PythonExe>" "<script>" <args...>     % when CondaEnv is set
```

The scripts below are checked into the repository. The sorting driver is
**copied** into each run folder before it is executed, so every run keeps the
exact script it used. A background sorting run on Windows goes through a
batch file written to the run folder, `ks4_launch.cmd`, which runs that
command (every path in quotes of its own, so paths with `&` or `^` work) and
then writes the exit marker `ks4_exit.txt`.

| Script | Called by | Environment needs |
| --- | --- | --- |
| [`run_ks4.py`](../pipeline/@EphysDataset/run_ks4.py) | `EphysDataset.runKilosort` (the pipeline's Sorting step) | kilosort, torch |
| [`probe_tool.py`](../pipeline/@EphysPreprocessingApp/probe_tool.py) | `EphysPreprocessingApp.runProbeTool` / `ProbeDesignerApp` | probeinterface |

Versions known to work are listed in [INSTALL.md](../pipeline/INSTALL.md):
kilosort 4.1.7, probeinterface 0.3.2, torch 2.7.1.

---

## `run_ks4.py`

Usage: `run_ks4.py <settings.json> [--device <torch device>]`.

1. Loads the probe with `kilosort.io.load_probe(cfg['probe'])`.
2. Sorts the other `settings.json` keys (except the driver's own keys
   `probe`, `data_dtype`, `torch_device` and `bin_scale`, the `.bin`'s units
   per µV that `readPhyUnits` reads and Kilosort4 is not given) with
   `split_settings`:
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
