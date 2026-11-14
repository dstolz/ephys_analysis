# Lab database

The toolbox can record its work in the lab's
[CarasLabDB](https://github.com/dstolz/CarasLabDB) database: which recordings
there are, which files every step wrote, from what and with which settings,
and where those files are now. The apps also use it to find files. It is
optional. With the database turned off, or out of reach, every app and every
pipeline run works exactly as before: nothing waits for the server and
nothing fails because of it.

> Status, 2026-11-14: this page describes the parts that are in place: the
> settings, the connection, the storage roots and the Database window, shared
> by every app. Recording the pipeline's steps and the analyses, the outbox
> that keeps them while the server is away, and finding files through the
> database are being added; this page will say so when they are.

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

The settings are kept with the app preferences (group `LabDB`). The window's
keys are Ctrl+S (save), F5 (test the connection), Esc or Ctrl+W (close) and
Ctrl+? (the list).

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

## The lamp

| Lamp | Meaning |
| --- | --- |
| Database: off | not set up, or turned off, on this computer |
| Database: connected | the connection is open |
| Database: offline | the server did not answer; the apps keep working, and a new try waits a pause that grows with each failure (5 s, 10 s, ... up to 5 minutes) |
| Database: attention | the server answered, but something here must be fixed: no password stored, the login refused, CarasLabDB or the Database Toolbox missing. The tooltip says what |

Before opening a connection, the toolbox checks that the server accepts one
within **ConnectTimeout** (default 5 s). An unreachable server therefore costs
a few seconds once, not a window that hangs.

## In scripts

```matlab
b  = LabDB.connect();        % the open connection, or [] (never an error)
st = LabDB.status();         % State, Message, Since, NextTry
s  = LabDBSettings.load();   % this computer's settings
[root, rel, why] = LabRoots.locate("Z:\data\G-0421\s1\s1_extract.mat", s);
p  = LabRoots.resolve("nas-main", "G-0421/s1/s1_extract.mat", s);
```

`LabDB.connect(Force=true)` tries again at once, while offline. Turn the
database off for a script with `s.Enabled = false; LabDBSettings.save(s)`.

## Requirements

- The [CarasLabDB](https://github.com/dstolz/CarasLabDB) repository on the
  MATLAB path (its `@CarasLabDB` class folder), a version that has
  `recordEvent`. Older checkouts are not supported.
- The Database Toolbox (CarasLabDB connects with its native `postgresql`
  interface).
- MATLAB R2024a or later for the vault (`setSecret`, `getSecret`).

Without these, the lamp says **attention** with the reason, and the apps
work without the database.

## Where the code is

| File | What |
| --- | --- |
| [`LabDB`](../pipeline/LabDB.m) | the connection and its state (one per MATLAB): `connect`, `status`, `disconnect`, `folder`, and `useBackend` / `useTemporary` for tests |
| [`LabDBSettings`](../pipeline/LabDBSettings.m) | the settings, in the app preferences |
| [`LabDBSecrets`](../pipeline/LabDBSecrets.m) | the password in the MATLAB vault; `useFake` for tests |
| [`LabRoots`](../pipeline/LabRoots.m) | storage roots: `locate`, `resolve`, the marker files |
| [`LabDBBackend`](../pipeline/LabDBBackend.m) | what the toolbox asks of the database; the only seam to CarasLabDB |
| [`LabDBCarasBackend`](../pipeline/LabDBCarasBackend.m) | that seam through the CarasLabDB class |
| [`LabDBFakeBackend`](../pipeline/LabDBFakeBackend.m) | an in-memory database for the tests |
| [`LabDBPanel`](../pipeline/LabDBPanel.m), [`LabDBLamp`](../pipeline/LabDBLamp.m) | the Database window and the status-bar lamp |

## Tests

`test_LabDB` runs everything against `LabDBFakeBackend`, in a temporary
preference store, a fake vault and a temporary database folder. It needs no
server and no Database Toolbox, and touches nothing of yours.
