# ManifestViewerApp

`ManifestViewerApp` ([source](../pipeline/ManifestViewerApp.m)) is a `handle`
class that opens a window showing **one dataset manifest**
(`<Folder>/<Name>_manifest.json`, schema in
[file-formats.md](file-formats.md#dataset-manifest)). It only reads the
manifest. The **Rewrite** button writes the file again from the dataset's
current state, and does nothing else to it.

## Opening it

From the GUI: **Dataset → View manifest...** opens the manifest of the
[active dataset](EphysPipelineApp.md#which-dataset-does-an-action-act-on)
([`onViewManifest`](../pipeline/@EphysPipelineApp/onViewManifest.m)),
with the config's default probe (`Probe.DefaultProbeFile`). A dataset with no
manifest on disk yet gets one written first. The Project tab's **Tools** panel
(**Manifest viewer**) does the same for the active dataset or for every
ticked one, a window each.

Programmatically:

```matlab
ManifestViewerApp(ds)                                  % an EphysDataset
ManifestViewerApp("D:\EPHYS\subj1_260101_120000")      % a folder: its newest *_manifest.json
ManifestViewerApp("D:\...\subj1_260101_120000_manifest.json")
ManifestViewerApp()                                    % asks for the file
ManifestViewerApp(ds, DefaultProbeFile=cfg.Probe.DefaultProbeFile)

v = ManifestViewerApp(ds);
v.load(otherDs);      % show another manifest in the same window
v.reload();           % read the file again
tf = v.rewrite();     % ds.writeManifest(), then reload (no confirmation)
v.saveFlowChart("flowchart.html");                       % the Flow chart as a page
T = ManifestViewerApp.summaryRows(readJsonFile(file));   % the Summary table, no window
```

`DefaultProbeFile=` names the probe a dataset without one of its own is used
with, as `EphysPipeline.probeFor` resolves it. The default is used, never
assigned, so the manifest's `probe.file` stays `""`. The Summary names the
default and the probe plot draws it.

A missing file or folder raises `ManifestViewerApp:NotFound`. A file that is
not JSON still opens. Its text is shown on the JSON tab and the error is shown
in the status line.

## Tabs

| Tab | Shows |
| --- | --- |
| **Summary** | every field, grouped by section (General, Recording, Probe, Channels, Manual artifacts, Artifacts, Binary, Kilosort run, Sorting, Processing, Behavior, Other). Fields the viewer does not know are listed under Other, one row per leaf. The **Check** column is worked out when the file is loaded (see below) |
| **Flow chart** | how the outputs were made, as a flow chart ([below](#flow-chart)), with buttons for four levels of detail, from the major steps to each parameter's value |
| **Timeline & probe** | the recording span with the manual artifact periods in red. A marker above each period keeps short ones visible. The behavior session start is drawn as a line when it falls inside the recording, and given in the title otherwise. Below it is the probe geometry from `probe.file`, else the default probe. The excluded channels (`chanMap + 1`) are marked ✕ and the channels left out of the common reference are circled |
| **Tree** | the decoded JSON as an expandable tree |
| **JSON** | the file's text |

Checks on the Summary tab. Rows are tinted red for a missing path and yellow
for a warning:

- each path the manifest names (`folder`, `probe.file`, `bin.file`,
  `kilosort.results_dir`, `sorting.results_dir` needs `params.py`,
  `behavior.file`) is checked on disk now. Where the manifest recorded
  `exists`, a change since it was written is noted. A `.bin` that was there
  when the manifest was written and is gone now is a warning;
- a dataset without a probe of its own names the default probe and checks it
  on disk;
- a probe with more channels than the recording;
- excluded channels and channels left out of the reference that are past the
  recording's channel count. The reference exclusion also gives its `source`
  (suggested, set by hand, or never set);
- artifact periods that end before they start or fall outside the recording;
- how each output was made (the `processing` block): for the artifact
  detection, the sorting `.bin`, the sort, the signals, the spikes, the
  behavior file and each export, its file checked on disk now, when and in
  which pipeline run it was written, the common reference applied in words
  (CAR, CMR or the weighted CAR, the channels it was taken over, the
  weighted CAR's order and Q, the signals it was subtracted from), then
  every option it was made with and every other field of the record, a row
  each (*Signals options.LFP_Fs*). A sort whose sorter added its own
  reference (Kilosort4's `do_CAR`) on top of a referenced `.bin` is a
  warning ("referenced twice"), as is a `.bin` whose reference is unknown.
  The kinds without a record are named in one *Not recorded* row;
- the trial pairing status. `unreviewed` is a warning, and `approved` also
  says whether it was automatic. A pairing record that
  `EphysDataset.normalizeTrialPairing` rejects, and the dataset therefore
  ignores, is a warning;
- tags that are not valid, or past the limit of 12, which
  `EphysDataset.applyManifest` drops (see `TagSet`);
- the schema is not one that `EphysDataset.applyManifest` reads.

The General section gives how long ago the manifest was `updated` and its
**Tags** (`draft, pilot`, or *(none)* when the manifest has no `tags`). The
Behavior section gives the session start relative to `metadata.acq_date`.

## Flow chart

The **Flow chart** tab draws what the manifest says was done to the recording.
The inputs are on top (the behavior session, the recording and the probe map),
then a box per step, with the files it wrote hung under it. An arrow runs from
each input or output to every step that reads it. Hover a box to light its
arrows. The mouse wheel zooms and a drag pans, as on the pipeline app's
[Diagram tab](EphysPipelineApp.md).

The buttons at the top pick how much the chart shows:

| Level | Adds |
| --- | --- |
| **Steps** | the major steps, and whether each ran |
| **Outputs** | the files written and what came of each step: the artifacts found, the trials paired, the units sorted, any warning |
| **Key settings** | the settings that decide the result, in words: the reference, the filters, the thresholds |
| **Every parameter** | every value the manifest holds about each step, by group. It opens at full size, for reading: drag to move around |

The **Direction** buttons beside them draw the flow **Top to bottom** or **Left
to right**. Left to right suits a wide screen: the columns follow the data from
the inputs to the export, and each arrow leaves the right of a box and enters
the left of the next.

An array that is data rather than a setting, such as a pairing's per-trial
columns, is shown as its size, and a run of channels in short (`[1-64]`). The
**Tree** and **JSON** tabs have the values themselves.

Faded means a step has not run. A dashed arrow is a read the step's record
says did not happen: Signals without artifact periods to erase, for example.
**Hide steps not run** leaves these out and closes the rows up. A box's badge
says whether its file is on disk now (`file gone` in red), and a sort with
results but no record of how it was made is `imported`.

**Save as HTML...** writes the chart as one standalone page with all four
levels in both directions, which opens in any browser and prints to PDF. **Open in Browser** opens
the same page, where a large chart is easier to read.

The chart is drawn when the tab is first shown, and the level and direction you
picked are kept when you reload. Each is laid out for the size of its boxes: no box
overlaps another, no arrow runs through a box, and the arrows are ordered to
cross as little as they can.

A script does not need the window:

```matlab
writelines(PipelineDiagram.manifest(ds), "flowchart.html");
[html, summary] = PipelineDiagram.manifest("D:\...\subj1_manifest.json", Level="settings", Direction="horizontal", HideNotRun=true);
```

`src` is an `EphysDataset`, a manifest file, the folder that holds one, or a
decoded manifest struct. `Level` is `"steps"`, `"outputs"` (the default),
`"settings"` or `"parameters"`. `Direction` is `"vertical"` (the default) or
`"horizontal"`. `DefaultProbeFile=` is as for the viewer.

## Buttons

| Button | Does |
| --- | --- |
| **Open...** | show another manifest |
| **Reload** | read the file again (e.g. after the GUI rewrote it) |
| **Open folder** | open the manifest's folder in the file browser |
| **Rewrite** | only when opened from an `EphysDataset`. After a confirmation, `ds.writeManifest()`, then reload. The probe, exclusion, artifact, sorting and behavior entries in the file are replaced by the dataset's in-memory values. A dataset built with `EphysDataset(folder)` has none of these until `applyManifest()` or a project `refresh()` restores them. `writeManifest` never replaces a manifest it cannot read (not JSON, an unknown schema), so Rewrite then leaves the file alone and says why |

## Tests

[`test_ManifestViewerApp.m`](../pipeline/test_ManifestViewerApp.m) opens the
viewer headlessly. It covers the Summary checks on a hand-written manifest, a
pairing record the dataset would ignore, opening from a file, from a folder
with two manifests and from an `EphysDataset` of a synthetic recording, the
timeline and probe plots, the tree, a schema `/1` manifest without a probe
(with and without a default probe), a file that is not JSON, Rewrite, a
Rewrite that `writeManifest` refuses, that closing the window deletes the
viewer, and the Flow chart: what each level shows, that no box overlaps another
and no arrow runs through one at any level in either direction, hiding the steps not run, the tab
drawn when shown and the level kept. [`test_EphysPipelineApp.m`](../pipeline/test_EphysPipelineApp.m)
opens it from **Dataset → View manifest...**.
