# Lab database

The toolbox can record its work in the lab's
[CarasLabDB](https://github.com/dstolz/CarasLabDB) database: which recordings
there are, which files every step wrote, from what and with which settings,
and where those files are now. The apps also use it to find files. It is
optional. With the database turned off, or out of reach, every app and every
pipeline run works exactly as before: nothing waits for the server and
nothing fails because of it.

> Status, 2026-11-18: everything on this page is in place: the settings, the
> connection, the storage roots and the Database window; the outbox, where
> every pipeline step, copied session, file movement, phy curation and run of
> figures is recorded on this computer as it is written; sending it to the
> server; and finding recordings and files through the database. The client
> itself is the `labclient` package of the CarasLabDB repository (see
> [One client for every toolbox](#one-client-for-every-toolbox-on-the-computer)
> and [Requirements](#requirements)).

## Set it up

Open **File → Database...** in any of the apps (the pipeline app, the
analysis app, the dataset browser), or click the **Database** lamp in the
status bar of the pipeline app, the analysis app or the manifest viewer.

1. Tick **Use the lab database on this computer**.
2. Fill in the **Server**, the **Port** (5432 unless you were told otherwise)
   and the **Database** (`lab`).
3. **Your login** is your own database login, never a shared one. The
   database administrator creates it and maps it to you.
4. **Your email** is needed only when your login is not mapped to you.
5. **Lab time zone** is the zone in which times written without one are read:
   old files and rig clocks. It starts as this computer's zone.
6. Click **Set password...**. MATLAB's own window asks for it and stores it
   in your MATLAB vault. The toolbox never sees it typed, and it is not
   written to the preferences, a config, a script or any file.
7. Click **Test connection** (F5). The window says what came of it, and
   which lab person you are in the database.

The settings are kept in the client's preferences (group `CarasLabDBClient`, the same for every toolbox on the computer). The window's
keys are Ctrl+S (save), F5 (test the connection), Ctrl+R (send now), Esc or
Ctrl+W (close) and Ctrl+? (the list).

## Storage roots

The database stores a file as a *storage root* and a path below it, for
example `nas-main` and
`G-0421/G-0421_260702_141210/G-0421_extract.mat`. Each computer says where
each root is on it, under **Storage roots on this computer**: pick the folder
(**Browse...**), type the root's name and click **Add**. For example,
`nas-main` might be `\\nas\data` on one computer and `/Volumes/data` on
another.

A workstation's own data disk is a root of its own, for example
`ws-rig2-d`, so files written there are recorded as soon as they are
written. Copies and moves to the NAS add their own records. To create such a
root, map it and choose **Remove / Register... → Register**: the root is
added to the database and a marker file (`.caraslabdb-root.json`, holding
the root's name and id) is written at the top of its folder.

A folder whose marker names another root is refused. A mistyped drive letter,
or a share mounted at another letter, therefore cannot file data under the
wrong root. On Windows, paths are stored with the spelling the files have on
disk, so a path typed in another case is not a second file.

## What is recorded

Whenever a step writes a file, a record of it is kept on this computer, in
the *outbox*, until it can be sent. Nothing waits for the server, and a
record that cannot be kept never stops the step (it is a warning).

| Written by | Recorded as |
| --- | --- |
| the artifact detection (when its intervals are kept in a file), `.bin`, Signals, Spikes, Behavior, NWB export | one analysis event per step: `ephys_analysis/<step>`, the record of how the output was made (its own JSON text), the code and the machine, when it started and ended, the files it read and the files it wrote |
| a sort, once it is done | one analysis event, `kilosort4` or `spikeinterface/<sorter>`, under the id it got when it was launched, whichever computer finds it done |
| the Copy tab (`copySessions`), per session copied | a recording event with the recording files where they were copied to, and a behavior event with the ePsych file and its trial count. A session copied again (to a backup, another computer) whose raw files are byte for byte those of a recording already in the database is that recording: its files are recorded as copies of the recording's, in its session, and the folder's session file takes that session; no second session or recording is made. A record of the folder sent before that (a step) waits while its raw files are being hashed, so it finds the session too |
| the pipeline's output transfer (its Transfer section), and the copy for the analysis app (**File → Copy files for the analysis app...**), per batch | each copy of a file a step wrote, as a file of that step; for a move, the source recorded as moved to its copy. A move with the database on checks every copy by SHA-256, and removes a source only once its copy is noted. A copy that is not its source's bytes is held |
| the Clean up tab (`runLocalCleanup`) | each file it removes that a record names: deleted or recycled, recorded as deleted; moved, its new place recorded and the file as moved there |
| a run of figures (the analysis app's Run, the pipeline's Analysis step, `EphysAnalysisRunner.run`) | one analysis event, `ephys_analysis/figures`: the analysis config, the code and the machine, when it started and ended; its inputs the files it read (each dataset's read ledger, by the files' ids where the dataset's records name them as they were read; any other file listed, not guessed); its outputs the reports, the run record and the figure files under a storage root mapped here (the others listed as `unrecorded_outputs`). A report written again at the same place with other bytes replaces the earlier one. It names a session when the run covers one dataset. A canceled run is recorded as failed (`outcome` canceled) |
| phy, saving in a sort a record names (seen at the next scan) | one analysis event, `phy`, ended when phy saved: its inputs the sort's files as recorded, its outputs the files phy changed or added, each changed one replacing the version before. Opened with **Open in phy** in the pipeline app, the launch is noted (who, on which computer, when), and the event names that person as who opened phy; opened another way, the event says it is not known. The event's person is whoever records it |

Previews, results kept in memory, the manifests, locks, logs, caches and the
favorites and notes are not recorded. A record of a step that wrote nothing
(an artifact detection kept in memory) is not kept either.

Each file is recorded with its storage root and path, its size, time and
SHA-256. Files up to **HashInProcessMB** (256 MB) are hashed at once; a larger
one by a separate process (PowerShell's `Get-FileHash` on Windows,
`shasum` / `sha256sum` elsewhere), so no step waits for it. A hash is kept
only for the bytes that were captured: when a file's size or time changes
before it is hashed, its record is held, with the reason, for you to look at.
A file a step rewrote is recorded as a new file that replaces the earlier one;
rewritten with the same bytes, it is the same file.

The records keep their ids, so sending one twice writes it once. The
dataset's session id is kept in its folder, in `<Name>_labdb.json`, so every
record of a dataset names the same session, from every computer.

The outbox is the folder `outbox` in this computer's database folder
(`%LOCALAPPDATA%\caraslabdb\client`, shared with the other toolboxes). Its format is in
[file-formats.md](file-formats.md#lab-database-bundle-caraslabdb-bundle1).

## Sending

What waits in the outbox is sent when the database answers:

- **While an app is open,** every 15 s, one record at a time, oldest first.
  Each try waits 2 s at most for the server. Nothing is sent while a pipeline
  run or an analysis run is going.
- **At the end of a pipeline run** (for up to 10 s), and at the end of a
  scheduled copy (up to a minute). What is left is sent later.
- **From the Database window:** **Send now** (Ctrl+R).

Sending a record twice writes it once: the database keeps each record's id
and digest. A connection that breaks while a record is sent leaves it
waiting; it is sent again later, and the database answers that it has it.

**The session.** A record's session is the one its dataset's session file
names. The first record of a dataset creates it, in the storage root of the
dataset's folder, for the subject the folder's name gives.

**A subject the database does not have** holds the dataset's records. A
window asks what to do (or **Assign subjects...** in the Database window):

- **Create subject**: add it to the database (its id, project, species and
  sex);
- **Assign to existing**: the folder name may be misspelled; the subjects
  are listed nearest first.

The choice is noted in the dataset's session file (and, when you tick it, in
those of the other datasets whose folders name the same subject). Folders
are never renamed. A scheduled copy, which no one watches, leaves the records
held until an app shows the window.

**Who did the work.** Every record names the person: the one set up on the
computer that captured it, or else the person your login is. A record
captured under another login waits for you to choose **Send as me** in the
Database window; the database notes that it was sent on that person's
behalf, and stamps your login.

**Inputs.** Each file a step read is linked to the step when the database has
that file. When it does not have it yet (the copy that registers it is still
waiting), the link is sent later. A file this computer cannot name (one it
did not capture) is listed with the record (`unresolved_inputs`), never
matched by its path alone.

**When the database refuses a record**, it is kept with the reason:

| In the outbox | Means | What to do |
| --- | --- | --- |
| to send | waits for the server, or for its SHA-256 | nothing |
| held | waits for you: a subject, a storage root to map or register, another login, a file that changed after it was captured, a conflict (the same id sent with other content) | read the note; fix it, then **Release** |
| failed | the database refused it, for the reason given | fix the cause, then **Retry** |
| discarded | you chose never to send it (**Discard...**, which asks first); it is kept, with who and why | nothing |

The lamp counts them: **· N to send**, or **· N need you** (held or failed;
the lamp turns red).

## Finding recordings

**File → Open from database...** finds recordings in the lab database: by
subject, project, the days they were recorded (from, to) and tags.
**Search** (Enter) lists each session with where it is on this computer (its
storage root mapped here, and whether the folder is there now) and the
folders here that hold its outputs, wherever they were copied to. **Open**
(Ctrl+Enter) opens the sessions selected:

- **The analysis app** shows their output folders (the source's folders
  mode; the config's figures stay, and the config is unsaved until you save
  it).
- **The pipeline app** makes the folder that holds the session folders the
  project root, scans it, and ticks those sessions (the others unticked).
  It turns **Recursive** on when a session is deeper than the folders
  directly in the root.
- **The dataset browser** makes the folder that holds their output folders
  the root, scans it, and ticks those recordings.

A session that is not on this computer (its storage root not mapped here,
or its folder not there) is named in the message and left out. Sessions on
different drives or shares cannot be opened together in the pipeline app or
the browser: they have no folder in common. The status bar names a folder
the scan did not find as a dataset.

The database only says where to look: the apps read the files they find
there as always. A dataset's output folder is known from its files' rows,
which name each file's place in it (`dataset_rel`, [file formats](file-formats.md)),
never guessed from a path. While the database does not answer, the last
search is shown, with its date.

When a dataset's file is not in its folders but its manifest says it was
written, the apps also look in the folders the database names for its
session (a copy or a move by the output transfer), by the same rules as in
its own folders; a file found in its own folders always wins. See
[DatasetOutputs](DatasetOutputs.md#files-that-have-moved-the-lab-database).

In scripts: `T = LabLocator.sessions(Subject="G-0421")`,
`LabLocator.outputFolders(T)`, and `LabLocator.commonFolder(folders)` (the
folder that holds them, as the apps use it).

## Where a dataset stands

- **The manifest viewer's Database tab** lists the dataset's steps and the
  files they wrote, with where each record is on this computer (sent, to
  send, held or failed with why, discarded, or not recorded here: captured
  while the database was off, or on another computer), and the dataset's
  records in the outbox. **Check the database** asks the database (2 s at
  most) whether it has each step, whether each file is present (or was
  replaced, moved or deleted) and when it was last verified. **Lineage of
  the file...** shows what the selected file was made from.
- **The pipeline app's Review tab** has a **Database** column: the
  dataset's records, as "4 sent, 1 to send".

## The lamp

| Lamp | Meaning |
| --- | --- |
| Database: off | not set up, or turned off, on this computer |
| Database: connected | the connection is open |
| Database: offline | the server did not answer; the apps keep working, and a new try waits a pause that grows with each failure (5 s, 10 s, ... up to 5 minutes) |
| Database: attention | the server answered, but something here must be fixed: no password stored, the login refused, CarasLabDB or the Database Toolbox missing. The tooltip says what |
| ... · N to send | N records wait to be sent |
| ... · N need you | N records are held or failed (the lamp is red): see the outbox in the Database window |

Before opening a connection, the toolbox checks that the server accepts one
within **ConnectTimeout** (default 5 s). An unreachable server therefore costs
a few seconds once, not a window that hangs.


## One client for every toolbox on the computer

The client, the Database window and its lamp are not part of this toolbox:
they are the `+labclient` package of the CarasLabDB repository, shared with
the lab's other MATLAB toolboxes (EPsych records its sessions and weights
through it). A computer is set up once, whichever toolbox records: one set of
settings, one vault password, one map of storage roots, one outbox, one lamp.
Records from several MATLABs wait in the one outbox; a MATLAB sends what it
can send, and leaves a record about a dataset of another toolbox for a MATLAB
that runs that toolbox. This toolbox registers its own (the dataset session
files, `LabCapture.readSession` and the others) under the name
`ephys_analysis`; `LabBridge` does it, the first time anything is captured.
A record written before records named their toolbox (every record from
before the client was shared) names none. The client assumes no toolbox for
it; this toolbox wrote those records, says so when it registers
(`TakesUntagged=true`), and sends them. In a MATLAB that does not run this
toolbox they wait, untouched.

The settings are kept in the MATLAB preferences, group `CarasLabDBClient`;
the outbox, the hashes and the caches in `%LOCALAPPDATA%\caraslabdb\client`.
**The first time this toolbox starts after the client was shared**, it takes
over what it had kept before, once, and says so in
`migration_from_ephys_analysis.log` in the new folder: the settings of the
app preferences (group `LabDB`, preference `Settings`), copied when the
client has none yet, and every file of `%LOCALAPPDATA%\ephys_analysis\labdb`
(the outbox and its notes, the hashes, the finder's cache) that is not at
the same place in the new folder yet, which is moved. A file already there is
never overwritten; what was being sent (`outbox\claimed`) stays where it is.

## In scripts

```matlab
b  = labclient.DB.connect();        % the open connection, or [] (never an error)
st = labclient.DB.status();         % State, Message, Since, NextTry
s  = labclient.Settings.load();     % this computer's settings
[root, rel, why] = labclient.Roots.locate("Z:\data\G-0421\s1\s1_extract.mat", s);
p  = labclient.Roots.resolve("nas-main", "G-0421/s1/s1_extract.mat", s);
```

`labclient.DB.connect(Force=true)` tries again at once, while offline. Turn
the database off for a script with `s.Enabled = false;
labclient.Settings.save(s)`.

A writer called from a script records its work as the pipeline does. What
waits in the outbox, and sending it:

```matlab
T = labclient.Outbox.list();       % id, state, type, captured_at, sealed, file, note
c = labclient.Outbox.counts();     % pending, claimed, held, failed, done, discarded
n = labclient.Hasher.work(Budget=30);   % finish the hashes that are still needed
r = LabBridge.flush(Budget=30);    % send for up to 30 s: sent, pending, held, failed, message
r = ds.Processing.spikes;          % event_id, outputs (path, bytes, mtime, artifact_id, sha256)
```

A writer of your own stores its record the same way:
`ds.setProcessing("spikes", r, StartedAt=t0, Provenance=prov)`. A script that
sends with `labclient.Sync.flush` itself should call `LabBridge.registerTool()`
first (anything captured in that MATLAB has done it already), or the records
of datasets wait for a MATLAB that has.

## Requirements

- The [CarasLabDB](https://github.com/dstolz/CarasLabDB) repository on the
  MATLAB path (its `+labclient` package and its `@CarasLabDB` class folder),
  a version that has the `labclient` package and `recordEvent`. Older
  checkouts are not supported. `useCarasLabDB` puts it on the path when it is
  a folder `CarasLabDB` beside this repository (or beside the folder that
  holds it), or the folder the environment variable `CARASLABDB_DIR` names;
  `run_all_tests` calls it. Otherwise add the checkout to the path yourself
  (`addpath('C:\src\CarasLabDB')`).
- The Database Toolbox (CarasLabDB connects with its native `postgresql`
  interface).
- MATLAB R2024a or later for the vault (`setSecret`, `getSecret`).

Without these, the lamp says **attention** with the reason (the
`labclient` package missing is told in the same way as the CarasLabDB class
missing), and the apps work without the database: nothing is recorded or
sent, and the few things every step stamps in its record (a uuid, a time, a
file's size) are done by `LabBridge` itself.

## Where the code is

The client is in the CarasLabDB repository (`+labclient`: `DB`, `Settings`,
`Secrets`, `Roots`, `Bundles`, `Outbox`, `Hasher`, `Sync`, `SubjectCache`,
`Backend`, `CarasBackend`, `FakeBackend`, `Panel`, `Lamp`,
`SubjectAssignDialog`, `Prefs`, `fileSha256`, `pathKey`); see its README. In
this repository:

| File | What |
| --- | --- |
| [`LabBridge`](../pipeline/LabBridge.m) | the door to the client: whether it is on the path, the lamp, the window, the sending timer, `suspend` and `flush` (all safe with the client missing), this toolbox's tool hooks, the take-over of the earlier settings and outbox |
| [`useCarasLabDB`](../pipeline/useCarasLabDB.m) | puts a CarasLabDB checkout on the path |
| [`LabCapture`](../pipeline/LabCapture.m) | what a step or a copy records, and the session file; `EphysDataset.setProcessing` calls it |
| [`LabLocator`](../pipeline/LabLocator.m), [`LabLocatorDialog`](../pipeline/LabLocatorDialog.m) | finding recordings through the database, and where they are here |

## Tests

`test_LabDB` tests this toolbox's side: `LabBridge`, the hooks it registers,
the hand-over of the test preference store to the client and the take-over of
the earlier settings and outbox. `test_LabCapture` checks what the steps and
copies record, in a temporary preference store and a temporary client folder,
and `test_LabSync` the sending of those records against the client's in-memory
database (`labclient.FakeBackend`): once, a lost answer, a conflict, subjects
to assign, another login, a copy and the step that read it, an unreachable
server, a failed step, a discarded record. They need no server and no
Database Toolbox, and touch nothing of yours. The client's own tests (the
bundles, the outbox, the hashes, the settings, the window, the lamp, the
records of no dataset, the subject cache) are in the CarasLabDB repository,
`tests/matlab/LabClientTests.m`.
