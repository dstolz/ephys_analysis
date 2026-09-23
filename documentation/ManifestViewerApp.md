# ManifestViewerApp

`ManifestViewerApp` ([source](../pipeline/ManifestViewerApp.m)) is a `handle`
class that opens a window showing **one dataset manifest**
(`<Folder>/<Name>_manifest.json`, schema in
[file-formats.md](file-formats.md#dataset-manifest)). It only reads the
manifest. The **Rewrite** button writes the file again from the dataset's
current state, and does nothing else to it.

## Opening it

From the GUI: **Dataset → View manifest...** opens the manifest of the
[active dataset](EphysPreprocessingApp.md#which-dataset-does-an-action-act-on)
([`onViewManifest`](../pipeline/@EphysPreprocessingApp/onViewManifest.m)),
with the config's default probe (`Probe.DefaultProbeFile`). A dataset with no
manifest on disk yet gets one written first.

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
| **Summary** | every field, grouped by section (General, Recording, Probe, Channels, Manual artifacts, Binary, Kilosort run, Sorting, Behavior, Other). Fields the viewer does not know are listed under Other, one row per leaf. The **Check** column is worked out when the file is loaded (see below) |
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
- the trial pairing status. `unreviewed` is a warning, and `approved` also
  says whether it was automatic. A pairing record that
  `EphysDataset.normalizeTrialPairing` rejects, and the dataset therefore
  ignores, is a warning;
- the schema is not one that `EphysDataset.applyManifest` reads.

The General section gives how long ago the manifest was `updated`. The
Behavior section gives the session start relative to `metadata.acq_date`.

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
Rewrite that `writeManifest` refuses, and that closing the window deletes the
viewer. [`test_EphysPreprocessingApp.m`](../pipeline/test_EphysPreprocessingApp.m)
opens it from **Dataset → View manifest...**.
