# Pipeline app guide

The pipeline app, `EphysPipelineApp`, turns raw recordings into files that are
ready to analyze. You set it up once, and it then processes every recording
the same way: today's, and the ones you record next month. This page is for
people who use the app. It needs no programming beyond the one line that opens
the app. Every tab has its own page with the details; this page tells you which
tab to use for what, and in what order.

<!-- wiki: New to the app? The [Quick start](Quick-Start) walks through it in 15 minutes on made-up data. -->

## What it does

For each recording (the app calls one recording a *dataset*), the app can:

| Step | In plain words | Tab |
| --- | --- | --- |
| Copy | bring the day's sessions from the lab's storage to this computer, and check the copy | [Copy](EphysPipelineApp.md#copy) |
| Behavior | match each behavior trial (from the Epsych2 file) with the trial pulses the recording saw | [Trials](EphysPipelineApp.md#trials) |
| Probe | say which probe was used, so every channel has its place on the shank | [Probe](EphysPipelineApp.md#probe) |
| Artifacts | find the stretches ruined by movement or noise, so no later step uses them; mark more by hand | [Artifacts](EphysPipelineApp.md#artifacts) |
| Sorting | sort spikes into units with Kilosort4 (or another sorter), to curate in phy afterward | [Sorting](EphysPipelineApp.md#sorting) |
| Signals | make the LFP, multi-unit activity (MUA), spike band and accelerometer signals | [Signals](EphysPipelineApp.md#signals) |
| Spikes | detect spikes on every channel by a threshold, without sorting | [Spikes](EphysPipelineApp.md#spikes) |
| Export | write an NWB file, the standard format for sharing data | [Export](EphysPipelineApp.md#export) |
| Analysis | draw the analysis app's figures and report for every processed recording | [Analysis](EphysPipelineApp.md#analysis) |

You choose which steps run. Only the probe is required; everything else can
be switched off.

## Before you start

- MATLAB, with this repository on its path. Someone in the lab has usually set
  this up; if not, see [Installation](../pipeline/INSTALL.md).
- Spike sorting also needs a Python environment with Kilosort4 (the same
  page). Everything else runs in MATLAB alone.
- Recordings from Intan, Open Ephys or TDT, or files in the
  [universal recording format](file-formats.md#universal-recording-format-recordingjson).
- A probe map for your probe. The repository has several; the
  [Probe tab](EphysPipelineApp.md#probe) can make a new one.

## Open the app

Type in the MATLAB command window:

```matlab
EphysPipelineApp
```

It opens the settings you used last. No data yet? Choose **File → Create
synthetic test project...**: it writes a small made-up project, with
recordings, behavior and sorted units, and opens it, so you can try every
tab without real data.

<!-- wiki: ![The pipeline app, Project tab, with a scanned project](images/app-project-tab.png) -->

## Find your way around

- **The tabs**, in the order you use them, run from left to right: Copy,
  Project, Trials, Probe, Artifacts, Sorting, Signals, Spikes, Export,
  Analysis, then Diagram and Run, then Review and Visualize, then Synthetic
  and Clean up.
- **The tab colors** tell you what still needs doing. Hover over a tab to see
  why it has its color.

  | Color | Means |
  | --- | --- |
  | green | ready |
  | amber | needs your attention (no datasets scanned, a trial pairing not approved, a dataset without a probe, ...) |
  | red | an error: a run will not start until you fix it |
  | gray | the step is switched off |
  | blue | busy (a run or a copy is going) |

- **The status bar** at the bottom says what was just done on the left, and
  suggests what to do next on the right.
- **Help → Help for this tab** opens the page for the tab you are on.

Three ideas make the rest easy:

- **The config.** Every setting of every step, and which steps run, is one
  *config*. Save it with **File → Save config** and open it again next time:
  the same processing, on new recordings. A `*` in the window's title means
  there are unsaved changes.
- **Ticked and active datasets.** Tick datasets in the Project table to choose
  what a run processes (no ticks means all of them). The *active* dataset, the
  bold row, is the one the single-dataset tools show: the trial pairing, the
  probe's excluded channels, the previews, Visualize and Review. Change it in
  the **Dataset** menu, in the **Dataset** box on a tab, or by clicking a row.
- **The manifest.** What you decide about one recording (its probe, its bad
  channels, the periods you marked, the trials you cut) is saved next to that
  recording, at once, in its manifest file. You never lose it by opening
  another config or scanning again. **Dataset → View manifest...** shows it,
  and its **Flow chart** tab draws how each file was made, from the major
  steps down to each setting.

## A typical session

1. **Copy** (only if the recordings are still on the lab's storage). Find the
   day's sessions, check that each recording has its behavior file, press
   **Preview (dry run)**, then **Copy selected**. The copy runs in the
   background; the copied sessions open as the project when it is done.
2. **Project.** Set the project folder (the folder that holds the
   recordings) and press **Scan**. Set an output folder if you want the
   results kept apart from the recordings. [Tag](#tag-your-datasets) the new
   recordings, then tick the datasets to process.
3. **Trials.** Each recording's behavior file is matched to its trials. Name
   the digital lines if needed, then look at each dataset's pairing and press
   **Approve pairing**. When a count does not match (a session started late,
   say), cut the extra trials at the start or the end, then approve. **Auto
   approve when the counts match** approves the clean ones for you.
4. **Probe.** Pick your probe's map and press **Assign to all datasets** (or
   make it the default probe). Type the bad channels of a recording in
   **Exclude channels**.
5. **Artifacts** (optional). Choose a common reference if you want one, press
   **Detect / Preview** to see what the detector finds, and mark extra noisy
   periods by hand on the plot. **Leave out bad channels** finds dead or noisy
   channels for you.
6. **Choose the steps.** Switch on what you need on the Sorting, Signals,
   Spikes, Export and Analysis tabs, and set their options. The defaults are a
   good start. The **Diagram** tab draws what your config will do, from top
   to bottom or, with **Direction**, from left to right.
7. **Run.** On the Run tab press **Validate config** (it lists any problem),
   **Plan** (what would happen; it writes nothing), then **Run pipeline**. The
   Run tab shows the progress, the computer's load and, at the end, a row of
   results per dataset.
8. **Save the config** (**File → Save config**), so the next batch runs the
   same way.
9. **Review.** Look at the sorted units and their quality, add notes, or open
   them in phy to curate them.
10. **Clean up** (optional). Once everything is written, free the disk space
    the raw recordings and the sorter's copies take, keeping what has a
    checked copy elsewhere.

## Tag your datasets

A *tag* is a short word you attach to a recording: the brain area (`ofc`,
`acx`), the cohort (`cohort-3`), the task or training stage
(`perceptual-training`), the condition (`saline`, `muscimol`), the probe
(`2-shank`) or the recording's state (`pilot`, `exclude`). Tagging takes
seconds, and it pays off every time you come back to the data. Make it a
habit: tag every recording when it is scanned.

**Why tag.**

- **Find recordings again.** All three tools filter by tag: the Project
  table here, the analysis app's Data tab and the dataset browser. "The OFC
  recordings of cohort 3, without the pilots" is a couple of clicks: tags
  *any of* `ofc`, then **not** `pilot`.
- **Choose what to analyze.** In the
  [dataset browser](dataset-browser-guide.md), filter by tag and press
  **Tick shown only**: the result covers exactly that group, and it is
  named after the tags (`ofc_StimOnset_Hit_FiringRate`).
- **Keep track of where each number came from.** Tags travel with the data:
  they are saved in each recording's manifest, and they appear in the
  browser's result (a Tags column for every unit), the analysis reports and
  their tables, and the NWB file.
- **Tag freely.** Tags are labels only. Adding, changing or removing one
  never changes any processing or output, so you can change your mind at
  any time.

**How to tag.**

| To tag | Do this |
| --- | --- |
| one recording | click its **Tags** cell in the Project table, add tags (pick from the ones in use or type new ones), **OK** |
| several at once | select their rows (Shift / Ctrl+click), press **Tags...**, then **Add to all** or **Remove from all** |
| every new recording, automatically | tick **Tag new datasets** under **Scan** and type the tags (`cohort-3, pilot`): each recording a scan finds for the first time gets them. The setting is saved with the config |

A recording holds up to 12 tags, each made of letters, digits, `-`, `_`
and `.`, stored in lowercase. Tags are edited here, in the pipeline app; the
analysis app and the dataset browser show them and filter by them.

**Good habits.**

- Agree on a short list of tags with your lab and spell them the same way
  every time. The tag window lists the tags already in use: pick from it
  rather than typing.
- Use several simple tags (`ofc`, `cohort-3`) rather than one long one
  (`ofc-cohort-3`): the filters combine them with *any of*, *all of* and
  **not**.
- Leave a recording out with a tag (`exclude`, `bad-behavior`), not by
  deleting or moving it, and filter it out with **not**. The reason stays
  visible, and you can bring it back by removing the tag.
- Tag while you still remember what each recording was: right after the
  scan, or let **Tag new datasets** do it for you.

## Common tasks

| ...do this | Do this |
| --- | --- |
| process new recordings the same way as before | **File → Open recent**, pick the config, **Scan**, tick the new datasets, **Run pipeline** |
| see what a run would do, without changing anything | Run tab: **Plan**, or **Dry run** |
| run one step again, on the ticked datasets | that step's tab: **Run this step** |
| look at the raw signal around an event or an artifact | [Visualize](EphysPipelineApp.md#visualize) tab |
| check how well units are sorted | [Review](EphysPipelineApp.md#review) tab, or **Open in phy** |
| label datasets (a brain area, a condition) to find them later | [tag them](#tag-your-datasets): Project tab, select rows, **Tags...** |
| make figures of every processed recording | make them in the [analysis app](analysis-app-guide.md), then choose that config on the Analysis tab |
| analyze on another computer | **File → Copy files for the analysis app...** copies just what the analysis app reads |
| repeat this processing without the app | **File → Generate script**, or the script every run saves in the project folder |
| free disk space | [Clean up](EphysPipelineApp.md#clean-up) tab: **Preview**, then remove |

## Where the results go

Each dataset's files go into one folder: `<output folder>/<dataset name>`, or
the recording's own folder when no output folder is set. The main ones:

| File | Holds |
| --- | --- |
| `<Name>_extract.mat` | the LFP, MUA, spike-band and accelerometer signals, and the digital events |
| `<Name>_spikes.mat` | the spikes detected by threshold |
| `kilosort4/` (or the sorter's folder) | the sorted units, as phy reads them |
| `<Name>_behavior.mat` | the behavior trials, paired with the recording |
| `<Name>.nwb` | the NWB file, when the Export step is on |
| `<Name>_manifest.json` | what was decided about this recording, and how every file was made |

<!-- wiki: Every file is listed on [Output files](Output-Files). -->

## When something goes wrong

- **A tab is red or amber.** Hover over it to see why, or press **Validate
  config** on the Run tab for the full list.
- **A run stopped on a dataset.** The Run tab's results table says what went
  wrong for each dataset, and **Open log** shows the details.
- **Still stuck?** **Help → Report an issue on GitHub...** opens a report with
  your settings and the logs filled in (look it over before you send it).

<!-- wiki: Common problems and their fixes: [Troubleshooting and FAQ](Troubleshooting-and-FAQ). -->

## Next

- To make figures (PSTHs, rasters, tuning curves) and reports of the
  processed recordings: the [analysis app guide](analysis-app-guide.md).
- To gather the responses of many recordings into one table for your own
  analysis: the [dataset browser guide](dataset-browser-guide.md).
<!-- wiki: - To run the same processing from a script, without the app: the [scripting overview](Scripting-Overview). -->
