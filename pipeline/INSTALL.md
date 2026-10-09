# Installing `EphysPipelineApp` on Windows 11

[`EphysPipelineApp`](../documentation/EphysPipelineApp.md) is a MATLAB
`uifigure` GUI (`pipeline/@EphysPipelineApp`) for the preprocessing
pipeline. It scans recordings (Intan, Open Ephys GUI sessions, TDT blocks,
or the universal binary format), writes derived-signal and spike `.mat`
files, optionally hands the recordings to **Kilosort4** for spike sorting
(in a separate Python/conda environment, with **phy** to curate the
result), and exports files for other tools (Chronux, FieldTrip, event
epochs, kCSD, NWB). This guide sets up a Windows 11 machine to run the app
end to end (what runs on macOS and Linux:
[platforms.md](../documentation/platforms.md)). Everything except spike
sorting, probe design and the NWB export needs MATLAB alone, so the MATLAB
steps can run before Python is installed.

## What you need, at a glance

| Component | Purpose | Required? |
| --- | --- | --- |
| MATLAB R2023a or later + Signal Processing Toolbox | Runs the app and every MATLAB step | Yes |
| Statistics and Machine Learning Toolbox | Automatic bad-channel detection in derived signals; the analysis module's response statistics and auROC | Optional |
| Parallel Computing Toolbox | Runs artifact scans and spike detection in chunks on a process pool | Optional |
| Miniconda (Windows) | Hosts the Python environments below | Only for sorting, probe design and the NWB export |
| `kilosort` conda env (kilosort, probeinterface, torch) | Runs the sorting step and the probe designer | Only for sorting / probe design |
| spikeinterface (in the `kilosort` env) | The SpikeInterface sorters of the Sorting tab (spykingcircus2, tridesclous2, ...) | Only to sort with them |
| NVIDIA GPU + driver | Kilosort4 runs dramatically faster on GPU | Recommended, not required |
| `phy` conda env (phy) | Manual curation of sorting results | Optional |
| A Python with pynwb and nwbinspector | The NWB export (`Export.Formats` `nwb`, `EphysDataset.exportNWB`) | Only for the NWB export |
| [FieldTrip](https://www.fieldtriptoolbox.org/) on the MATLAB path | Validates the FieldTrip export; analyzing it | Optional |
| [Chronux](http://chronux.org) (bundled in `toolboxes/chronux`) | Analyzing the Chronux export | Optional |
| This repository (`ephys_analysis`) | Contains the app and MATLAB path helpers | Yes |

What each MATLAB toolbox is used for, function by function, is listed under
[Dependencies](../documentation/README.md#dependencies).

## 1. Install MATLAB

1. Install MATLAB R2023a or later (the Artifacts tab uses `xregion`; the code
   also relies on `arguments`-block validation and string arrays). The code
   is developed and tested on R2025a. The analysis plot editor's color
   picker is `uicolorpicker` (R2024a); earlier releases get a swatch that
   opens `uisetcolor`.
2. In the Add-On Explorer or the installer, include the **Signal Processing
   Toolbox**. Filtering, resampling and derived signals call `butter`,
   `filtfilt` and `resample` directly (`EphysDataset.filterContinuous`,
   `deriveSignals`), and the Visualize tab's filtering depends on them.

## 2. Put the repository on the MATLAB path

1. Install [Git for Windows](https://git-scm.com/download/win) if it is not
   there yet, then clone the repository (or download and unzip it), for
   example to `C:\src\ephys_analysis`:
   ```bat
   git clone https://github.com/dstolz/ephys_analysis.git C:\src\ephys_analysis
   ```
2. In MATLAB, `cd` to the repository root and run:
   ```matlab
   addpath_nogit(pwd)
   ```
   This adds the repository and every folder below it (`pipeline/`,
   `analysis/` for the analysis app, the `vendor/` helpers and the bundled
   `toolboxes/chronux`) and skips hidden folders such as `.git` and
   `.claude` (Claude Code keeps whole checkouts in `.claude/worktrees`,
   which would otherwise shadow the real code). Run `savepath` to keep the
   path across MATLAB restarts, or run the line at the start of each session
   (for example in `startup.m`).

   > **Shadowed functions.** The bundled Chronux has its own `findpeaks` and
   > `jackknife`. With the whole repository on the path, they come before the
   > Signal Processing Toolbox's `findpeaks` and the Statistics and Machine
   > Learning Toolbox's `jackknife`. The pipeline and the analysis module
   > call neither. Chronux's `locfit` add-on also has `predict`, `residuals`
   > and `aic`; a call on a model object, such as `predict` on a
   > `LinearModel`, still reaches the object's own method. If your own code
   > needs the toolbox functions, remove Chronux from the path in that
   > session: `rmpath(genpath('C:\src\ephys_analysis\toolboxes\chronux'))`.

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

## 4. Miniconda and the `kilosort` environment

1. Install [Miniconda for Windows](https://docs.conda.io/en/latest/miniconda.html)
   (the 64-bit installer). The default location (`%LOCALAPPDATA%\miniconda3`
   or `%USERPROFILE%\miniconda3`) is fine. A new config in the app starts
   with the Python exe last set in the app. Before one is set, it starts
   with `envs\kilosort\python.exe` of the conda install that `CONDA_EXE`
   names, else of a `miniconda3`, `anaconda3`, `miniforge3` or `mambaforge`
   folder under `%LOCALAPPDATA%`, `%USERPROFILE%`, `%ProgramData%` or `C:\`.
2. Open **Anaconda Prompt (miniconda3)** from the Start menu and create the
   environment the app expects, named `kilosort` (the known-good environment
   uses Python 3.11):
   ```bat
   conda create -n kilosort python=3.11 -y
   conda activate kilosort
   ```
3. Install the sorting stack (known-good versions):
   ```bat
   pip install kilosort==4.1.7 probeinterface==0.3.2
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
   python -c "import kilosort, probeinterface, torch; print(torch.cuda.is_available())"
   ```
   This should print `True` if the GPU build installed correctly, or `False`
   (no error) for a CPU-only setup. On a machine with more than one GPU,
   `python -c "import torch; print(torch.cuda.device_count())"` gives the
   count. List them in the app's Run tab **GPUs** box (`cuda:0, cuda:1`,
   `Sorting.Devices`) so that runs going at once each get their own.

Conda does **not** need to be on the Windows `PATH`: the app calls the
environment's `python.exe` by its full path
(`%LOCALAPPDATA%\miniconda3\envs\kilosort\python.exe` or similar). Only a
**Conda env** set on the Sorting tab needs it (step 6).

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

### (Optional) SpikeInterface sorters

The Sorting tab's **Sorter** can run a sorter through
[SpikeInterface](https://spikeinterface.readthedocs.io) instead of
Kilosort4. Add SpikeInterface to the `kilosort` env, with the extras its own
sorters and the phy export need (pandas, scikit-learn, numba, networkx):

```bat
conda activate kilosort
pip install "spikeinterface[full]==0.104.5"
python -c "import spikeinterface.sorters as ss; print(ss.installed_sorters())"
```

Known to work: spikeinterface 0.104.5, probeinterface 0.3.2, pandas 3.0.3,
scikit-learn 1.9.0, numba 0.65.1 (Python 3.11). That lists `spykingcircus2`,
`tridesclous2`, `lupin` and `simple`, which need nothing else; another sorter
needs its own package in the same env (`pip install mountainsort5`, ...). On
the Sorting tab, **Find SpikeInterface sorters** then lists them.

### (Optional) A Python for the NWB export

The NWB export writes the file with pynwb and checks it with nwbinspector.
Either add them to the `kilosort` env or give them an env of their own. From
Anaconda Prompt:

```bat
conda create -n nwb python=3.11 -y
conda activate nwb
pip install pynwb nwbinspector
```

Known to work: pynwb 4.2.0, hdmf 6.2.0, nwbinspector 0.7.2, h5py 3.16.0,
numpy 2.4.6 (Python 3.11). On the Export tab, set **Python (NWB)** to that
env's `python.exe` (`Export.NWB.PythonExe`). Left blank, the Sorting tab's
Python is used.

## 6. Point the app at your Python environments

1. Launch the app in MATLAB:
   ```matlab
   EphysPipelineApp
   ```
2. Go to the **Sorting** tab:
   - **Python exe**: a new config is seeded with
     `...\miniconda3\envs\kilosort\python.exe` when it exists in a standard
     location (step 4); otherwise browse to it with the `...` button. The path is part
     of the pipeline config (`Sorting.PythonExe`), so save the config
     (**File → Save config**).
   - **Conda env**: leave blank, since the Python exe above already points
     inside the `kilosort` env. When it is set, the drivers run through
     `conda run -n <env>`, which needs `conda` on `PATH`.
   - **Phy command**: leave blank for the default, the `phy` executable of
     the `phy` env from step 5 (`envs\phy\Scripts\phy.exe`). It is looked
     for in the conda install that holds the Python exe, the one
     `CONDA_EXE` names, `%LOCALAPPDATA%\miniconda3`,
     `%USERPROFILE%\miniconda3` and `%USERPROFILE%\anaconda3`; when none has
     it, the default is `conda run -n phy phy`, which needs `conda` on
     `PATH`. Set it to `phy` if phy is on `PATH`, or to
     `conda run -n <name> phy` for an env of another name. The Phy command
     is an app preference, not part of the config.

## 7. Verify everything works

Run the MATLAB test suites first; they need no Python and no real data:

```matlab
cd C:\src\ephys_analysis\pipeline
run_all_tests
```

Then use the pipeline's built-in dry run: tick **Dry run** on the Sorting tab
(or **Run → Dry run**) to write `settings.json` and `run_ks4.py` into
`<output>\kilosort4\dryrun` without writing the `.bin` or launching
Kilosort4, and check the settings, probe and paths it would use.

No recordings yet? **File → Create synthetic test project...** writes a
complete project to try every step on, without real data or Python
([Synthetic test project](../documentation/EphysPipelineApp.md#synthetic-test-project)).
<!-- wiki: See also [Quick start](Quick-Start). -->

## Troubleshooting installation

- **"No python executable configured"**: set the Python exe field on the
  Sorting tab (`Sorting.PythonExe` in the config, or `ds.PythonExe` when
  scripting `EphysDataset` directly).
- **`torch.cuda.is_available()` returns `False` on a GPU machine**: the
  CPU wheel was installed instead of `+cu118`. Reinstall with the CUDA index
  URL in step 4, and check that the NVIDIA driver from step 3 is current.
- **phy fails to launch**: check that `params.py` exists in the dataset's
  sorted-output folder, and that the **Phy command** matches how phy was
  installed (step 6).
- **`Undefined function 'xregion'` on the Artifacts tab**: MATLAB is older
  than R2023a.
- **`butter` or `filtfilt` not found**: the Signal Processing Toolbox is
  missing.

<!-- wiki: More problems and their fixes: [Troubleshooting and FAQ](Troubleshooting-and-FAQ). -->
