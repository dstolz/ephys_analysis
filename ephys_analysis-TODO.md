# ephys_analysis TO DO

## Instructions for Claude

Evaluate each item below and determine if it is still relevant. If it is, then provide a brief description of what needs to be done to complete the task. If it is not relevant, explain why it can be removed from the list.

Process each item in the list and provide a status update. Ask questions if you need clarification on any of the items.

Provide a concise summary of the completed tasks and any remaining items that need attention. Update the TO DO list accordingly. If you have any suggestions for new tasks or improvements, please add them to the "Suggestions" section at the end of the document, but do not process unless I move them to the TO DO list.

## TO DO

_(nothing open)_

## Suggested TO DOs
_DO NOT PROCESS UNLESS MOVED TO THE TO DO LIST_

- **Show the Run's results table live.** It stays empty until a Run ends: `runPipeline` sets it only at the end. The wiki's Run tab page says it "fills with one row per step and dataset" during a run. `onPipelineProgress` could copy `Pipe.Results` into the table whenever a row is added.
- **Keep the queue across app restarts.** Closing the app drops the queued runs, although their files are written. The queue could be saved (dataset key + prepared result) and offered back on the next launch.
- **Publish the Clean up changes to the wiki.** The Clean-up tab page, the File-Formats clean-up record (schema /2) and the `app-cleanup-tab.png` screenshot (`tools/wiki/wikiScreenshots.m`, Shots="app-cleanup-tab.png") describe the old tab.
- **Warn when runs at once share one GPU.** With `MaxConcurrent` > 1 and zero or one `Devices`, every run goes on the same GPU. On a small card like this laptop's 4 GB RTX 500 that risks CUDA out-of-memory errors. A validation warning (or an info line on the Run tab) would flag it.
- **Visualize: read only the window shown.** Plot still streams the whole recording and decimates it; for a long 64-channel recording that is tens of GB per Plot. Design from the review (item 10 below):
  - A "Window (full rate) / Whole recording (decimated)" choice. Window mode reads [Start − pad, Start + Window + pad] with `readWindowUV`, or only the overlapping chunks for traditional `.rhd`.
  - `MultiChannelViewer` would need a `TimeOffset` and a `TotalDuration` (so panning can pass the cached span) and a `ViewChangedFcn`. The app re-reads, debounced, when the view leaves the cached span.
  - A 2 s × 64-channel read is about 7.7 MB (about 0.1 s).
- **Visualize: show a run's cached artifact detection.** The orange overlay now shows only the Artifacts tab's Detect / Preview of the plotted dataset while its settings still hold. A static, read-only `EphysPipeline.cachedDetection(cfg, d)` would let `vizDetectedIntervals` fall back to what a run detected:
  - It shares the fingerprint with `artifactIntervalsFor`, factored out.
  - It returns ok = false when detection is off, or when a reference is on and `ReferenceExcludeSource` is "".
- **Old Intan files: the software notch filter.** For `.rhd` files older than v3.0 recorded with the software notch on, `read_Intan_RHD2000_file_modified` applies Intan's notch with a per-sample loop. The loop restarts at every file, and `toBin` writes the notch-filtered data. A `filter()` form that carries its state across files would be faster and continuous. No built-in form matched the loop exactly, so it needs a reference test against the loop.
- **PDF reports draw every page again.** The HTML report now reuses the figures the runner already drew. The PDF report still draws each page a second time (as vector graphics).
- **Small API tidy-ups found in the review:**
  - `EphysDataset.setTrialPairing` could return whether it wrote the manifest. The Trials tab's Approve writes the manifest a second time to find out.
  - A public `EphysPipelineConfig.numberText`, so the app's copy can go.
  - Visualize's "Sort by probe map" and channel colours read the probe `.json` themselves (`applyVizChannelOrder`, `applyVizChannelColor`). They sort bottom-up, while the Artifacts viewer (`channelLayout`) sorts top-down. They could use `channelLayout(ProbeFile=)`.
- **Flow chart text: bad channels.** `flowChartHTML.m` line 287 labels the bad-channel step "spatial makima". Bad channels are now interpolated from the probe geometry, with makima across columns only as the fallback. This was left alone because another session is refactoring the diagram.
- **Check classdef method declarations against their files.** MATLAB reports a declaration that lists fewer inputs than its method file only when the method is called. The review found one this way: the analysis app could not open. A small check could compare each declaration's input and output count with the `function` line of its file (the review's one-off script did this for all 445 declarations), as a test or under `tools/`.
- **Check the docs' test tables against the new checks.** The review's doc pass covered the fixes but did not compare every test description with its suite. The suites that grew most are `test_CopySessions` and `test_LocalCleanup` (described in EphysPreprocessingApp.md), and `test_EphysPipeline`, `test_SortingConcurrency`, `test_EphysPipelineScript`, `test_TrialPairing`, `test_EventEpochs`, `test_EpsychSession` and `test_EphysPipelineConfig` (in the tests tables).
- **Tests build extract `info` structs with `time` vectors.** `test_ChronuxDataset` (line 171) and `test_FieldTripExport` (line 34) still hand-make `info.LFP.time`, which extracts no longer have. `info.LFP.nSamples` would match real files.



## Done

1. **Kilosort4 runs at once** (done 2026-09-21; pushed as `1315f60`; the CRLF log fix below as `9956da8`). Before this, background sorting started every queued dataset at once.
   - **Setting:** new config field `Sorting.MaxConcurrent` (default 1). It is set on the Run tab ("Kilosort4 runs at once", under the Sorting box) and greyed out when Execution is blocking. Blocking runs always go one at a time.
   - **How the queue works:** the Run writes each dataset's run files (the `.bin` for the native engine) first, then waits for a free slot and starts it. The Run tab stays busy until the last dataset has started. Cancel stops the waiting; runs already started carry on. Runs still going from an earlier Run also take slots.
   - **Progress:** while waiting, the step line reads "waiting for a free Kilosort4 slot (N at a time): R running, F finished, W still to start". The Kilosort4 label reads "Background Kilosort4: F of T finished (R running, W waiting to start)". Each run joins the log monitor as it starts, not after the Run ends.
   - **Also fixed:** a Kilosort4 process that died without writing `ks4_status.json` (bad python/conda env, crash) used to look "running" forever. It now leaves an exit marker (`ks4_exit.txt`) and counts as an error, so it frees its slot.
   - **Also fixed (found by the new test):** the live Kilosort4 log in the app dropped every line of a background run. Python on Windows writes CRLF to a redirected stdout, and the carriage-return collapsing reduced each such line to "". Only the `[done]` / `[error]` lines were getting through.
   - **Scripts:** the generated standalone script honours the same limit (`waitForSortingSlot`).
   - **Tests:** new suite `test_SortingConcurrency` (fake "python" `.cmd` files, no GPU needed), plus checks in `test_EphysPipelineConfig`, `test_EphysPipelineScript` and `test_EphysPreprocessingApp`. Docs are updated in `documentation/`.
2. **Delete `EphysProject.runKilosortAll`** (done 2026-09-21; pushed as `9b1293d`). Removed the method file, its declaration and the class-header example, and the mentions in `documentation/` (EphysProject, EphysDataset, README). Nothing else called it; sorting goes through `EphysPipeline.runSorting`.
3. **Background runs' result rows follow the run to done / error** (done 2026-09-21; pushed as `c36b56b`).
   - When a background run finishes, the monitor (`pollKSRuns`) turns its `launched` row into `done` ("Kilosort4 finished") or `error` (`Kilosort4 failed: <message>`), and adds the time it ran to **Seconds**. `markKSResult` does the update.
   - During a Run it updates the pipeline's `Results` (new `EphysPipeline.updateResult`), so the table the Run shows at its end already has it. After the Run it updates the table and the run diagram.
   - The diagram now counts `launched` / `queued` rows as "in the background" rather than "done", until the run ends.
   - `EphysPipeline.restateResult(T, ...)` is the static form, for scripts.
4. **One GPU per run on multi-GPU machines** (done 2026-09-21; pushed as `c36b56b`).
   - **Setting:** new config field `Sorting.Devices` (torch devices, e.g. `["cuda:0" "cuda:1"]`; empty = Kilosort4's own choice, the old behaviour). It is set on the Run tab ("GPUs", under "Kilosort4 runs at once").
   - **How runs get a device:** each background run gets the device that the fewest running runs use, the first listed on a tie (new `sortingSlot`). Blocking runs use the first device.
   - **Drivers:** the device reaches the driver as `--device <dev>` on its command line. It is chosen when the run starts, so it cannot be baked into the JSON that was written earlier. `run_si_ks4.py` sets the SpikeInterface wrapper's `torch_device`. `run_ks4.py` passes `run_kilosort(device=torch.device(...))`.
   - **Also fixed:** `run_ks4.py` now honours a `torch_device` in `KS4ExtraJSON`; the native engine used to drop it as unrecognised.
   - **Checked:** in the installed Kilosort4 4.1.7, the hard-coded `torch.device('cuda')` defaults are only fallbacks when no device is passed.
   - **Validation:** a bad device name is an error. Warnings for more devices than runs at once, several devices with blocking runs, and `Devices` next to a `torch_device` in the extra JSON.
   - **Limit:** this machine has one GPU (RTX 500), so real two-GPU runs are untested. The tests check which `--device` each run got, using stand-in `.cmd` "python" files.
5. **Queue the waiting runs so the Run ends at once** (done 2026-09-21; pushed as `c36b56b`).
   - **Setting:** a Run tab checkbox, "Queue the waiting runs; the Run goes on". It is an app preference (`QueueSortingRuns`, off by default), greyed out for blocking runs.
   - **How it works:** when ticked, the sorting step writes each dataset's run files and hands the prepared run to the app (new `EphysPipeline.QueueFcn`). The row says `queued`, and the Run moves on to its next step. The monitor starts queued runs in order as slots free, using the working config's runs-at-once and GPUs at each tick. Each row then turns `launched`, then `done` / `error`.
   - **While a Run waits for its own slots:** the queue is held until that Run ends, so slot counting stays exact.
   - **Stop queue** (beside the Kilosort4 label under the log) drops the queued runs that have not started. Their rows become `cancelled`; their run files stay.
   - **Closing the app** with runs queued asks first. Clean up refuses to delete files while runs are queued.
   - **API change (no back-compat, as agreed):** `runKilosort` / `runSpikeInterface` lost `BeforeLaunchFcn`. They gained `Launch=false`, which writes every file and returns, and `Device`. A new `EphysDataset.launchSorting(res, Wait=, Device=)` starts a prepared run.
   - **Other API changes:** `waitForSortingSlot` now takes run structs, returns the device and has a `Devices` option. `PriorRuns` is now a run struct array (`EphysPipeline.emptyRuns`, now with `device` and `started`). The generated standalone script uses `Launch=false` + `waitForSortingSlot` + `launchSorting`.
   - **Tests** (all passing):
     - `test_SortingConcurrency`: 45 checks, now also covering devices, the queue, `launchSorting` and `restateResult`.
     - `test_EphysPipelineConfig`: 115, with the `Devices` rules and a save/load round trip.
     - `test_EphysPipelineScript`: 26, with scripts for two GPUs and for blocking runs.
     - `test_EphysPreprocessingApp`: 182, with new sections 4e/4f: rows turning `done`, the GPUs field, the queue, Stop queue.
     - `test_EphysDataset` 302 and `test_EphysPipeline` 69 also pass.
   - **Docs:** `documentation/` is updated (EphysDataset, EphysPipeline, EphysPreprocessingApp, python-drivers, file-formats, README), and so is `pipeline/INSTALL.md`.
6. **Stop a background Kilosort4 run from the app** (done 2026-09-21; pushed as `502771b`, together with three commits from another session that you approved).
   - **Button:** a Run tab button, **Stop runs...**, beside Stop queue and on while runs are going. With one run it asks for confirmation; with several it lists them (dataset, GPU, minutes running), all selected. `onStopKSRuns` is the dialog; `stopKSRuns(names)` does the stopping.
   - **How:** the new static `EphysDataset.stopSortRun(statusFile)` finds the run's processes by their command line (the run folder's `run_*.py` driver). It ends them with their children (`taskkill /T /F`; `pkill` off Windows), then writes `ks4_status.json` as `{"state":"cancelled","message":"stopped by the user"}` plus `ks4_exit.txt`, so `sortRunState` returns `"cancelled"` and the slot frees.
   - **Why a command-line search:** background runs are started with `start`, so there is no PID to keep. The run folder is unique. The search pattern goes through an environment variable, so the search's own shell does not match itself.
   - **Monitor:** logs `[stopped] <name>` and turns the row `cancelled` ("stopped before it finished"). What Kilosort4 wrote so far stays.
   - **Limits:** a freed slot goes to the next queued run (press Stop queue too to stop everything). Blocking runs cannot be stopped, since MATLAB waits for them.
   - **Tests:** `test_SortingConcurrency` section 12 (a 30-s stand-in is killed: status cancelled, marker written, its end never reached, slot freed; 50 checks), and new app checks (Stop runs... on only while a run is going; `stopKSRuns` ends it and the row turns `cancelled`; `test_EphysPreprocessingApp` 185/185). Docs updated in `documentation/`.
7. **Publish the documentation changes to the GitHub wiki** (done 2026-09-22; wiki commit `ac76fe2`; footer: source `502771b`).
   - **What was already there:** the wiki had been refreshed on 2026-09-21 to source `192a48e` (wiki `7fbc336`), so this update covers what came after: `1315f60` and Done items 2–6.
   - **Generated API sections:** all 19 were regenerated with another session's generator (`gen_api.py`), with a new "Background Kilosort4 runs" group for `sortingSlot` / `waitForSortingSlot`.
   - **Prose pages edited:** Run-and-Flow-Tabs (runs at once, GPUs, the queue, Stop runs..., the new statuses), Sorting-Tab, File-Formats, Output-Files, Pipeline-Configs, Python-Drivers, Running-Pipelines-from-Scripts, Working-with-Datasets, Architecture, Testing, Troubleshooting-and-FAQ and Installation, plus the lead paragraphs of API-EphysDataset and API-EphysProject.
   - **Screenshots:** `app-run-plan.png` and `app-run-results.png` were retaken.
   - **Checked:** links check clean, and the page, the image and linked source files are served live.
   - **Preferences:** a hung screenshot run left test state in the R2025a `EphysPreprocessingApp` preferences, which only batch tests use; your R2024b desktop keeps its own. They were put back to the last clean backup (15:07, 2026-09-21).
8. **Keep the wiki generator in the repo** (done 2026-09-22; pushed as `ed1d125` + `c2a5e6e`; wiki note `687fb01`). New folder `tools/wiki/`:
   - **`gen_api.py`:** the API generator (from session 651280dc's scratchpad), with its paths now arguments (`--src`, `--wiki`, `--gen`, `--no-splice`) instead of its scratchpad layout. Run against the published wiki and the `502771b` source, it reproduces the pages byte for byte.
   - **`check_links.py`:** the link and anchor check (missing pages, anchors and images; `<Name>` eaten as HTML). It exits 1 on problems.
   - **`wikiScreenshots.m`:** takes the eight app screenshots its help lists, over a synthetic project. It puts only `pipeline`, `analysis`, `vendor` and `toolboxes` of `Source=` on the path, so `.claude/worktrees` copies can't shadow the app. It backs up the preferences to a file and restores them even on an error. It stops the resource monitor's timer before the results shot, which is when `exportapp` had hung twice; with that change it passed.
   - **`restoreAppPrefs.m`:** re-applies that backup if a run has to be killed.
   - **`README.md`:** the whole update workflow (snapshot the commit with `git archive`, generate, hand edits, screenshots, link check, footer, push) and the traps.
   - Linked from `documentation/README.md`. Tested: generator, link check, and the screenshots (all eight taken, in two runs).
9. **Clean up: remove a preprocessing step's output; delete, recycle or move** (done 2026-09-22; committed as `bf2bb68`).
   - **Steps:** new tick boxes on the Clean up tab, one per step that writes files (none ticked by default). Sorting (Kilosort4) takes the whole `kilosort4` folder (sorted units, phy curation, unit notes, logs, the sorter's copy of the recording) and `<Name>.bin` + `.json`; Signals, Spikes and Export take their `.mat` files; Behavior takes `<Name>_behavior.mat` and the events cache; Artifacts the artifact cache. A sorted-output folder chosen by hand is kept. `.mat` outputs are recognised by their variables (`DatasetOutputs`), so configured suffixes and the config's step output folders count. Leftover `~<name>.partial.mat` files go with their step. `planLocalCleanup` gained `Remove` values for the steps, a `SearchDirs` option, and `Step`, `Root` and `Key` columns.
   - **Where files go:** a new **Removed files go** choice: Delete permanently (default), Move to the Recycle Bin, or Move to a folder (with Browse...). `runLocalCleanup` gained `Method`, `Destination`, `ProgressFcn` and `CancelFcn`, and removes the folders it empties.
     - **Recycle Bin:** a file is skipped, not deleted for good, when Windows would not keep it: a network or removable drive, a bin set to delete at once, a file bigger than the bin's maximum size (read per volume from the registry), or a path of 260+ characters. Afterwards each file is looked up in the bin's `$I` records, and one not found there is reported.
     - **Move:** files go to `<folder>\<dataset key>\<path in the dataset folder>` and never overwrite. Across drives the tool copies, checks the size, then deletes. A folder inside a dataset folder, the project root or the output root is refused.
   - **App:** the confirmation depends on the method and warns when phy curation or unit notes would go. A cancellable progress dialog shows during the run. Afterwards the manifests of the datasets that lost files are rewritten, and the Datasets table and Review tab refresh. The Preview and action buttons now sit below the scrolling options. New files: `runCleanup.m` (the part with no dialogs, which tests call), `onCleanupMethodChanged.m`, `onCleanupBrowseDest.m`. The steps, the method and the folder are saved in the preferences.
   - **Record:** `<Name>_cleanup.json` is now schema `ephys-local-cleanup/2`. Each run has `method` and `destination`, and each file has `step`, `to` and `note`.
   - **Tests:** `test_LocalCleanup` has 15 tests, all passing: removing the sorting step, finding outputs by their contents, the hand-picked folder, move, cancel, and a real Recycle Bin round trip that empties its own items afterwards. `test_EphysPreprocessingApp` passes 205/205, with new 4d checks.
   - **Not tested here:** a move between drives (this machine's temp folder and the only other writable fixed drive, G:, are not a safe pair to test on), and the Recycle Bin refusal on a real removable or network drive. The check logic was run against C: (fixed; the 50,772 MB cap read correctly), S: (network) and a UNC path.
10. **Review of the pipeline and basic analysis: errors and inefficiencies** (done 2026-09-23; committed in one commit, together with this entry).
    - **How:** separate review passes covered the readers; derived signals, artifacts and spike detection; events, trials and exports; orchestration and scripts; sorting and units; copying; the preprocessing app; analysis computations; and analysis plots and reports. Together they found about 100 issues. Each issue was checked against the code, then fixed in one of ten fix sets. Each set was built in its own worktree and merged by hand. The Run / Flow diagram files were not touched, because another session is refactoring them.
    - **Could lose or corrupt data (fixed):**
      - With no output root, the sorting `.bin` was `<Name>.bin` in the dataset folder. For a binary-format recording that is the recording's own data file, and `toBin` opened it for writing. The sorting `.bin` is now `<Name>_ks4.bin`, and `toBin` / `matrixToBin` refuse to write any recording file.
      - A scan while a drive was offline dropped the probe, sorted-output folder and behavior file from each manifest, because their targets were missing, and the refresh wrote that back. These associations are now kept, and an unreadable manifest is never overwritten.
      - Copying:
        - A file robocopy was stopped in passed as complete, because robocopy sizes a file when it starts. Size and modified time are now both checked.
        - A robocopy ended from outside (exit 1) with a file unfinished now fails the session.
        - A resume could add the other pairing's behavior file to a session folder.
        - Scheduled runs re-hashed every session and refilled sessions that Clean up had emptied.
      - Re-sorting into the same folder kept the old `cluster_notes.tsv`, so old notes attached to new cluster ids, and it overwrote phy curation without a word. Both now move to `previous_<time>`.
      - Signals:
        - Manifest exclusions (recording channels) were used as column numbers, so the wrong columns were interpolated and the output could widen.
        - Bad channels were interpolated across neighbouring columns in header order, which crosses shanks on the H64LP. A bad channel is now the 1/distance-weighted mean of the 4 nearest good sites on its own shank. The sites are placed by the dataset's own probe, else the default probe.
      - The noise that replaces artifacts in the sorting `.bin` had its level measured on a high-passed view of broadband data. That left a step at every artifact edge. The fill now bridges between the clean data on either side.
      - App:
        - Opening a config for another root while a project was scanned ran the old project with the new config.
        - Plan, while background runs were pending, killed the Kilosort4 monitor.
        - A rescan kept the active dataset by its position, so manual periods could land on another recording.
        - Config edits made during a run reached the datasets being processed.
      - Plots: a PSTH's y-limits were applied to its raster, so groups vanished, and stacked PSTH labels included the trial count.
    - **Timing (one-sample offsets):**
      - Event onsets at derived rates were about one sample early in Chronux trials, event epochs, FieldTrip events, trial pairing and evoked potentials.
      - Spike epochs, and the analysis PSTH, firing rate and correlation, were one recording sample off the events.
      - PSTH bins now start at the event.
      - Visualize's decimation drifted (250 ms after 2 h), which put manual periods early.
      - The conventions throughout: continuous samples and spikes are at (row − 1)/Fs, and digital events at row/Fs.
    - **Numerics:**
      - `filterContinuous` used transfer-function coefficients, which are unstable at low cut-offs (NaN at [100 3000] Hz in single precision). It now uses second-order sections, unless every edge is at least 0.005 × Nyquist and the order is at most 4. In that case the result is the same to 1e-6 µV and 3× faster.
      - MUA and SPIKE are filtered in double precision, and non-integer sample rates resample (`rat`).
      - Artifact detection: the common-mode detector no longer reads the re-referenced data, and excluded channels no longer count toward it. The reference's automatic exclusion uses the median.
    - **Speed and memory:**
      - Digital events no longer read every amplifier channel, which cost up to 2.7 GB per recorded minute for binary recordings. Edge detection is now linear in the number of samples.
      - Traditional `.rhd` files are read by window, so parallel spike detection no longer reads the whole previous file.
      - `readPhyUnits` is several times faster.
      - The artifact cache no longer changes when manual periods do, so detection runs once per run instead of three times.
      - Export reads each dataset's inputs once for all formats.
      - The Kilosort4 monitor refreshes only the table rows that changed.
      - Analysis:
        - Sorted units are cached across plots, and `selectChannels` makes no copy.
        - Bin counts are vectorized.
        - PSTHs render without `linkaxes`, which took two thirds of the render time.
        - The HTML report reuses the figures already drawn.
        - `test_EphysAnalysisRunner` went from 302 s to 159 s.
    - **Sorting and units:**
      - `channelLayout` reads probe `chanMap` values as `.bin` rows, as Kilosort4 does, not as hardware channel numbers.
      - Templates are unwhitened with `Winv.'` and scaled to µV when the run recorded its `bin_scale`; `templateUnits` says which.
      - A sort counts as curated only when phy wrote the labels.
      - Background launches go through `ks4_launch.cmd`, so paths with `&` or `^` work, and a launch that fails writes the exit marker.
      - Manifest channel lists are parsed without `str2num`.
    - **API changes (no back-compat, as agreed):**
      - The Signals bad list is recording channels.
      - `info.<SIG>.time` is gone; use `info.<SIG>.nSamples`.
      - The sorting `.bin` is `<Name>_ks4.bin`, and dry-run files go to `<runDir>\dryrun`.
      - New options: `artifactIntervals(IncludeManual=)`, `channelLayout(ProbeFile=)` and `deriveSignals(probeFile=)`.
      - `spikePSTH` returns `R.window` (whole bins).
    - **Tests:** new suites `test_IntanReader`, `test_BinaryReader`, `test_DeriveSignals` and `test_SortedUnits`, and new checks in most of the other suites (35 in the app suite). **Full run** (2026-09-23, R2025a, all 28 suites in one process, about 12 min): all pass. The first full run caught one more error. `EphysAnalysisApp`'s classdef still declared `gatherAlignControls(obj, C)` after the method file gained three inputs, so the analysis app could not open ("Too many input arguments"). With the declaration fixed, `test_EphysAnalysisApp` passes 32/32. A scan of all 445 method declarations in `pipeline/` and `analysis/` against their files found no other mismatch.
    - **Docs:** `documentation/` is updated. `pipeline/INSTALL.md` notes that `addpath_nogit` now skips hidden folders, so `.claude/worktrees` copies no longer shadow the code.
    - **Left for later:** see Suggested TO DOs: windowed Visualize, a run's cached detection in Visualize, the old notch loop, PDF report redraws, and the small API tidy-ups.
