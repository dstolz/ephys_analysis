# Installing `EphysPreprocessingApp` on Windows 11

`EphysPreprocessingApp` is a MATLAB `uifigure` GUI (`pipeline/@EphysPreprocessingApp`)
that scans recordings (Intan `.rhd`, or the universal binary format),
previews/filters them, optionally hands them off to **SpikeInterface +
Kilosort4** (running in a separate Python/conda environment) for spike sorting
with **phy** as the curation viewer, and writes derived-signal and spike `.mat`
files plus export files for external analysis toolboxes (Chronux and FieldTrip
so far; more formats will be added). This guide covers everything needed to get a clean
Windows 11 machine running the app end to end. Only MATLAB is required for
everything except sorting and probe design.

## What you need, at a glance

| Component | Purpose | Required? |
| --- | --- | --- |
| MATLAB + Signal Processing Toolbox | Runs the app, reads/filters Intan data | Yes |
| Miniconda (Windows) | Hosts the Python environments below | Yes |
| `kilosort` conda env (spikeinterface, kilosort, probeinterface, neo, torch) | Runs the sorting step and the probe designer | Only for sorting / probe design |
| NVIDIA GPU + driver | Kilosort4 runs dramatically faster on GPU | Recommended, not required |
| `phy` conda env (phy) | Manual curation of sorting results | Optional |
| [FieldTrip](https://www.fieldtriptoolbox.org/) on the MATLAB path | Validates the FieldTrip export; analysing it | Optional |
| [Chronux](http://chronux.org) (bundled in `toolboxes/chronux`) | Analysing the Chronux export | Optional |
| This repository (`ephys_analysis`) | Contains the app and MATLAB path helpers | Yes |

## 1. Install MATLAB

1. Install MATLAB R2023a or later (the Visualize tab uses `xregion`; the code
   also relies on `arguments`-block validation and string arrays). The code
   is developed and tested on R2025a.
2. In the Add-On Explorer / installer, make sure **Signal Processing Toolbox**
   is included — `EphysDataset.filterContinuous` calls `butter`/`filtfilt`
   directly and the Visualize tab's filtering options depend on it.

## 2. Get the repository onto your MATLAB path

1. Install [Git for Windows](https://git-scm.com/download/win) if you don't
   already have it, then clone this repo (or download/unzip it) to somewhere
   like `C:\src\ephys_analysis`.
2. In MATLAB, `cd` to the repo root and run:
   ```matlab
   addpath_nogit(pwd)
   ```
   This adds the repo (including `pipeline` and the vendored `vendor/` helpers) to
   the path while skipping `.git` folders. Save the path (`savepath`) if you
   want this to persist across MATLAB restarts, or re-run it each session.

## 3. (Recommended) Set up an NVIDIA GPU

Kilosort4 can run on CPU, but it is very slow for anything beyond a quick
test. If the machine has an NVIDIA GPU:

1. Install the latest **NVIDIA driver** for the card from
   [nvidia.com/drivers](https://www.nvidia.com/Download/index.aspx) (Game
   Ready or Studio driver, either works). You do **not** need to separately
   install the CUDA Toolkit — the PyTorch wheel installed in step 4 bundles
   its own CUDA runtime.
2. No further action needed until step 4, where you'll install a
   CUDA-enabled build of PyTorch.

If there's no NVIDIA GPU, skip to step 4 and install the CPU build of
PyTorch instead — everything still works, just slower.

## 4. Install Miniconda and the `kilosort` environment

1. Install [Miniconda for Windows](https://docs.conda.io/en/latest/miniconda.html)
   (the 64-bit installer). Default install location is fine
   (`%USERPROFILE%\miniconda3` or `%LOCALAPPDATA%\miniconda3` — the app's
   "Browse Python exe" picker and `EphysPreprocessingApp.defaultPythonExe()` both
   look for these paths automatically).
2. Open **Anaconda Prompt (miniconda3)** from the Start menu and create the
   environment the app expects, named `kilosort`:
   ```bat
   conda create -n kilosort python=3.10 -y
   conda activate kilosort
   ```
3. Install the sorting stack:
   ```bat
   pip install spikeinterface[full]==0.104.5 kilosort==4.1.7 probeinterface==0.3.2 neo==0.14.4
   ```
4. Install PyTorch:
   - **With an NVIDIA GPU (CUDA 11.8):**
     ```bat
     pip install torch==2.7.1 --index-url https://download.pytorch.org/whl/cu118
     ```
   - **CPU only:**
     ```bat
     pip install torch==2.7.1
     ```
5. Sanity check the environment:
   ```bat
   python -c "import spikeinterface, kilosort, probeinterface, torch; print(torch.cuda.is_available())"
   ```
   This should print `True` if the GPU build installed correctly, or `False`
   (no error) for a CPU-only setup.
6. Optional, for Open Ephys sessions recorded in the **NWB** format and sorted
   with the SpikeInterface engine (the default): `pip install h5py` (or
   `conda install -n kilosort h5py`). Binary and Open Ephys format sessions
   need nothing extra, and the native Kilosort4 engine reads NWB files in
   MATLAB.

You do **not** need conda on the Windows `PATH` for the app to work — it
calls the environment's `python.exe` directly by full path
(`%USERPROFILE%\miniconda3\envs\kilosort\python.exe` or similar).

## 5. (Optional) Install `phy` for manual curation

`phy` has its own, older dependency set that conflicts with the `kilosort`
env, so it needs its own environment. From Anaconda Prompt:

```bat
conda create -n phy python=3.11 -y
conda activate phy
pip install phy --pre --upgrade
```

Skip this if you don't plan to manually curate sorting results — Kilosort4
still runs and writes phy-format output either way.

## 6. Point the app at your Python environments

1. Launch the app in MATLAB:
   ```matlab
   EphysPreprocessingApp
   ```
2. Go to the **Sorting** tab:
   - **Python exe** — a new config is seeded with
     `...\miniconda3\envs\kilosort\python.exe` when it exists in a standard
     location; otherwise browse to it with the `...` button. The path is part
     of the pipeline config (`Sorting.PythonExe`), so save the config
     (**File → Save config**).
   - **Conda env** — leave blank (the Python exe above already points inside
     the `kilosort` env).
   - **Phy command** — leave blank to use the default, `conda run -n phy
     phy` (the separate `phy` env from step 5, requires `conda` on PATH); set
     it to `phy` instead if you installed it into the base/PATH environment,
     or to `conda run -n <name> phy` if you named the env something else.

## 7. Verify everything works

Run the MATLAB test suites first; they need no Python and no real data:

```matlab
cd C:\src\ephys_analysis\pipeline
run_all_tests
```

Then use the pipeline's built-in dry run: tick **Dry run** on the Sorting tab
(or **Run → Dry run**) to write `si_config.json` + `run_si_ks4.py` without
launching, and run the driver with `--check` in the conda environment. That
reads a recording, attaches the probe and builds the preprocessing chain
**without** running Kilosort4 — the fastest way to confirm the environment and
a given recording format are compatible:

```bat
"<PythonExe>" "<output>\kilosort4\run_si_ks4.py" "<output>\kilosort4\si_config.json" --check
```

## Troubleshooting

- **"No python executable configured"** — set the Python exe field on the
  Sorting tab (`Sorting.PythonExe` in the config, or `ds.PythonExe` if
  scripting `EphysDataset` directly).
- **`neo`/`read_intan` errors about a missing `.dat` file** — split-format
  Intan recordings need every declared stream's `.dat` file present (e.g.
  `digitalin.dat`), even if you don't use that stream.
- **`torch.cuda.is_available()` returns `False` on a GPU machine** — the
  wrong PyTorch build was installed (CPU wheel instead of `+cu118`); reinstall
  using the CUDA index URL in step 4, and confirm the NVIDIA driver installed
  in step 3 is current.
- **phy fails to launch** — confirm `params.py` exists in the dataset's
  Kilosort4 results folder, and that the "Phy command" field matches how you
  installed phy (base env vs. `conda run -n phy phy`).
