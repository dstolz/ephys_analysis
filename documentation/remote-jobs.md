# Remote processing: job queue, MATLAB client, web dashboard

> **Status: design proposal. None of this is implemented yet.** Every file and
> class named below is something to build, not something to call. The pages
> beside this one describe code that exists; this one does not.

## Why

Processing currently runs wherever the analyst sits: `EphysPreprocessingApp` or
`EphysPipeline(cfg).run()` executes in the foreground of an interactive MATLAB
session. That ties a multi-hour Kilosort4 + signals + export run to one desk,
one MATLAB seat and one unlocked session, and nothing survives a logoff.

The goal is to move all processing to a dedicated Windows 11 machine — the one
with the NVIDIA GPU and the `kilosort` conda env — submit work to it from
anywhere on the lab network or VPN, and watch it either from MATLAB or from a
browser. Raw data does not live on that machine, so the NAS→local copy has to be
part of the job rather than a separate manual step.

Constraints this design was written against:

- VPN-reachable is sufficient; no public exposure required.
- Only MATLAB and the existing `kilosort` conda env may be installed. No Docker,
  no IIS, no database server.
- Staging (the NAS→local copy) must be part of the job.
- Worker count must be configurable.

## Design in one picture

```
 clients:  MATLAB (EphysJobClient)          browser (dashboard)
                      \                        /
                       \____ REST + SSE ______/          LAN / VPN, bearer token
                                  |
                          ephysd  (FastAPI + uvicorn, in the `kilosort` env,
                                   a Windows service; owns the queue, the
                                   worker slots, auth and the path allowlist)
                                  |  spawns, N at a time
                       matlab -batch "ephysRunJob('<jobdir>')"
                                  |
                   copySessions (staging)  ->  EphysPipeline.run()
                                  |
                jobdir/{status.json, progress.ndjson, job.log, results.json}
```

The job directory is the single source of truth. MATLAB writes it, the service
reads it, and the service can be restarted or absent without losing a run.

## What this reuses

Almost none of this is new machinery; it is existing conventions wired together.

| Existing | Used for |
| --- | --- |
| [`EphysPipelineConfig`](EphysPipeline.md#ephyspipelineconfig) — exact JSON round trip, `validate()`, `enabledSteps()` | the job payload *is* a saved config; validation happens before a job is accepted |
| [`EphysPipeline`](EphysPipeline.md#ephyspipeline) — `ProgressFcn` (`step, dataset, index, count, done, total, message`), `LogFcn`, `cancel()`, `Results`, `plan()` | every hook the runner needs already exists; nothing in `@EphysPipeline` changes |
| [`runKilosort`](EphysDataset.md#running-kilosort4) + [`pollKSRuns`](../pipeline/@EphysPreprocessingApp/pollKSRuns.m) — detached launch, [`ks4_status.json`](file-formats.md#ks4_statusjson), log tail by byte offset | the status-file and log-offset convention, copied verbatim |
| [`copySessions`](../pipeline/copySessions.m) + [`copy_engine.ps1`](../pipeline/copy_engine.ps1) + [`pollCopyJob`](../pipeline/@EphysPreprocessingApp/pollCopyJob.m) — job JSON, NDJSON progress, status file, cancel sentinel | the queue's on-disk protocol, and the staging step itself |
| [`writeJsonFile`](../pipeline/writeJsonFile.m) (atomic temp + rename, `NonFinite="string"`), [`readJsonFile`](../pipeline/readJsonFile.m) | every status and results write |
| [`runDiagramHTML`](../pipeline/@EphysPreprocessingApp/runDiagramHTML.m) / [`flowChartHTML`](../pipeline/@EphysPreprocessingApp/flowChartHTML.m) — zero-toolchain HTML, data-driven redraw | the dashboard's visual language; the run diagram needs no change to be driven by remote events |
| [`makeSyntheticProject`](../pipeline/makeSyntheticProject.m) | end-to-end queue tests with no real data |
| `matlab -batch` (already how [`run_all_tests`](../pipeline/run_all_tests.m) drives CI) | the runner process |
| [`CopySchedule`](../pipeline/CopySchedule.m) — JSON settings plus a Windows Task Scheduler task that runs `matlab -batch` unattended, with `RunWhen` `"signed_in"` / `"always"` | the phase-1 worker's task registration, and the precedent for the session-0 question below |
| [`resource_monitor.ps1`](../pipeline/resource_monitor.ps1) — detached CPU / memory / disk / GPU sampler writing `sample.json`, with a `stop` sentinel and a parent-pid watchdog | the dashboard's machine-health panel, and GPU-aware scheduling |
| [`planLocalCleanup`](../pipeline/planLocalCleanup.m) / [`runLocalCleanup`](../pipeline/runLocalCleanup.m) — plan and remove (delete, recycle or move) the local raw copies, sorter copies and `.bin` files a dataset no longer needs, or everything a preprocessing step wrote | retention for the staging area; no new policy code needed |
| [`EphysAnalysisRunner`](EphysAnalysis.md) — the analysis-side config-driven runner, with its own `ProgressFcn(fraction, message)`, `LogFcn`, `cancel()` and `Results` | the second job kind (see §2) |

## 1. Job directory — the on-disk contract

Queue root on the Windows 11 box, e.g. `D:\EPHYS\queue`. One directory per job,
named `<ISO timestamp>_<4 hex>`. **The directory never moves**, because the
state lives in `status.json`: moving directories between `queued/` and
`running/` folders invites Windows sharing violations while a process holds a
file open, and changes the address clients hold.

```
D:\EPHYS\queue\jobs\20260918T143207_a7f3\
  job.json          the submission: kind, name, submitter, steps, datasets, dryRun, staging, priority (immutable)
  config.json       the EphysPipelineConfig (or EphysAnalysisConfig) exactly as cfg.save() writes it
  status.json       current state, rewritten atomically (writeJsonFile)
  progress.ndjson   append-only, one JSON object per line, flushed (the copy_engine.ps1 convention)
  job.log           LogFcn lines
  matlab.log        the batch process's stdout / stderr (crash evidence)
  results.json      the final Results table
  plan.json         the plan() table captured before the run
  cancel            sentinel; its existence requests cancellation
```

`status.json`, schema `ephys-job/1` (to be written up in
[file-formats.md](file-formats.md)):

```json
{ "schema":"ephys-job/1", "id":"20260918T143207_a7f3", "name":"su1255 signals+spikes",
  "state":"queued|staging|running|done|failed|cancelled",
  "submitted":"...","started":"...","finished":"...","heartbeat":"...","pid":12345,
  "steps":["copy","probe","behavior","artifacts","sorting","signals","spikes","export"],
  "step":"signals", "dataset":"1255/1255_260908_103912",
  "index":3, "count":12, "done":0.42, "total":1, "message":"deriving LFP",
  "fraction":0.31,
  "counts":{"ok":8,"skipped":1,"error":0,"cancelled":0}, "error":"" }
```

`fraction` is computed **once, by the runner**, from the documented rule
`(max(index,1) - 1 + done/total) / count` weighted across the step list, so
MATLAB and the browser never disagree about how far along a job is.

`heartbeat` is rewritten at least every 15 s even when nothing changed. A job in
`staging` or `running` whose heartbeat is older than 90 s **and** whose process
is gone is marked `failed` with `"error":"runner exited without finishing"`.
That is the only way a MATLAB crash becomes visible.

## 2. The MATLAB runner

**New: `pipeline/ephysRunJob.m`**

```matlab
function status = ephysRunJob(jobDir, opts)
%ephysRunJob  Run one queued job: stage, then run the pipeline, reporting into jobDir.
arguments
    jobDir (1,1) string
    opts.HeartbeatSeconds (1,1) double = 15
end
```

1. `readJsonFile(job.json)`, `EphysPipelineConfig.load(config.json)`.
2. Apply the server's path map (§6) to `Project.Root`, `Project.OutputRoot`,
   `Behavior.SearchDirs` and the per-step `OutputDir`s; force
   `Sorting.PythonExe` and `Sorting.CondaEnv` from the machine's own settings.
3. `cfg.validate()` — any `error` row ends the job as `failed` before anything
   is written.
4. Capture `pipe.plan()` to `plan.json`.
5. If `job.staging` is present, run `copySessions` with the reporter wired in
   (reported as step `"copy"`), then repoint `cfg.Project.Root` at the staged
   destination.
6. `EphysPipeline(cfg)`, wire `ProgressFcn` and `LogFcn`, `run(Steps=, DryRun=)`.
7. Write `results.json` and the terminal `status.json`.

**New: `pipeline/@EphysJobReporter/EphysJobReporter.m`** (handle class) — the one
place that knows the on-disk protocol:

| Method | Does |
| --- | --- |
| `EphysJobReporter(jobDir)` | opens `progress.ndjson` and `job.log` for append, seeds `status.json`, starts the heartbeat `timer` |
| `progress(evt)` | appends an NDJSON line, updates the in-memory status, rewrites `status.json` at most ~1/s, and **checks the cancel sentinel** |
| `log(msg)` | `job.log` plus an NDJSON `{"event":"log"}` line |
| `finish(state, results, message)` | `results.json` and the terminal `status.json`; stops the heartbeat |

`CancelTarget` holds the object to cancel — the `EphysPipeline`, or the
`copySessions` job during staging. When `progress` sees the sentinel it calls
`CancelTarget.cancel()`; `EphysPipeline` then throws `EphysPipeline:Cancelled`
at the next notification, and its atomic writes guarantee nothing half-done is
left behind. This is exactly the contract the GUI's Cancel button already
relies on.

**One `matlab -batch` process per job, not a long-lived daemon.** Isolation (a
crash in a MEX or CUDA path kills one job, not the queue), clean memory between
jobs (the signals step holds whole recordings), and `matlab -batch` is already
how this repo drives CI. MATLAB startup, 20–40 s, is noise against a multi-hour
job; `Parallel.MaxWorkers` still applies inside each job.

**Two job kinds from the start.** The repo now has a second config-driven
runner, [`EphysAnalysisRunner`](EphysAnalysis.md), with the same shape of hooks
(`ProgressFcn`, `LogFcn`, `cancel()`, a `Results` table). Figure and report
generation is exactly the kind of work worth queueing, so `job.json` carries a
`kind` field (`"pipeline"` | `"analysis"`) and `ephysRunJob` dispatches on it.
The one wrinkle: `EphysAnalysisRunner`'s `ProgressFcn` is
`@(fraction, message)`, not the pipeline's event struct, so it needs the same
kind of adapter the staging step needs (§4). Building the queue for one kind and
retrofitting the other later would mean redoing the status schema, so it is
cheaper to allow for both now even if only `"pipeline"` is implemented first.

**Sorting execution mode.** `EphysPipelineConfig.validate()` already forbids
`Sorting.Execution = "background"` feeding the sorted-unit consumers in one run.
For queued jobs the runner **forces `Execution = "blocking"`**: a detached
Kilosort4 that outlived the batch process would make the job's own completion
meaningless. The runner records the override in `job.log`.

## 3. Worker scheduling

Slots are enforced by the service (phase 2) or the PowerShell worker loop
(phase 1), never by MATLAB.

- `max_workers` — configurable, default 2.
- `sorting_slots = 1` — a job whose steps include `sorting` also takes the GPU
  slot. Without this, "N workers" means two Kilosort4 runs fighting over one
  card.
- FIFO within a priority band; `priority` is an integer in `job.json`.

`resource_monitor.ps1` already samples CPU, memory, disk and GPU utilisation
into a `sample.json` from a detached process. Running one instance for the
service gives the scheduler real numbers to hold a job back on (GPU memory
still in use by a sort that has not exited, free disk below what staging needs)
and gives the dashboard a machine-health panel for nothing.

## 4. Staging as step 0

`job.staging` carries exactly the arguments the two existing functions take —
`findCopySessions(subjID, dateSpec, IntanRoot=, EpsychRoot=, DestRoot=,
MaxLeadTime=, MaxLagTime=, AmbiguityMargin=, MinIntanDuration=)` and
`copySessions(T, DestRoot=, DryRun=, IfExists=, Verify=, IncludeUnpaired=,
ProgressFcn=, LogFcn=, CancelFcn=)`:

```json
"staging": { "subject":"SUBJ-ID-1255", "dates":["260908","260916"],
             "intanRoot":"nas:intan_files/Data", "epsychRoot":"nas:epsych_files/Data",
             "destRoot":"data:staged",
             "verify":"size", "ifExists":"resume", "includeUnpaired":false }
```

The runner calls `findCopySessions`, then `copySessions(T, DryRun=false, ...)`
with the reporter wired in. Two adapters are needed, and they are the only
fiddly part:

- `copySessions`' `ProgressFcn` is `@(fraction, message, info)` with
  `info.Phase` / `Session` / `Sessions` / `Bytes` — **not** the pipeline's
  `ProgressFcn(evt)` struct. The reporter maps it to `evt.step = "copy"`,
  `evt.index` / `count` from `info.Sessions`, `evt.done` / `total` from
  `info.Bytes`, `evt.message = info.Phase + ": " + message`.
- `CancelFcn` is `@() logical`, so the reporter hands `copySessions` a closure
  over the same sentinel check the pipeline path uses.

Rows that come back `ambiguous` or `failed` are recorded as `copy` result rows
and, unless `job.staging.continueOnError` is set, end the job before any
processing. Silently processing a partial copy is the worst failure mode here.

After staging, `cfg.Project.Root` is repointed at `<destRoot>/<subject>` and the
effective config is written to the job directory as `config.effective.json`, so
the run stays reproducible. `copySessions` already writes
`session_manifest.json` per session with sizes, hashes and the pairing status;
that manifest is the provenance record and should be referenced from
`results.json`, not duplicated.

## 5. The service

New top-level `server/` — not under `pipeline/`, since it is not on the MATLAB
path:

```
server/ephysd/{__init__,main,queue,runner,paths,auth,config}.py
server/static/{index.html,app.js,style.css}
server/ephysd.example.toml
server/requirements.txt          fastapi, uvicorn[standard], pydantic, tomli
server/install_service.ps1
server/README.md
server/tests/{test_queue,test_paths,test_api}.py
```

Endpoints, all under `/api`, bearer token required except `/api/health`:

| Method | Path | Does |
| --- | --- | --- |
| GET | `/api/health` | version, slots, queue depth |
| GET | `/api/roots` | the allowed path roots and their aliases |
| POST | `/api/jobs` | submit; validates config and paths, writes the job directory |
| POST | `/api/jobs/{id}/plan` | a short `matlab -batch` that returns `plan()` only |
| GET | `/api/jobs` | list, filterable by state / submitter / since |
| GET | `/api/jobs/{id}` | that job's `status.json` |
| GET | `/api/jobs/{id}/progress?since=N` | NDJSON lines after line N |
| GET | `/api/jobs/{id}/log?pos=N` | `{pos, text}` — byte-offset tail |
| GET | `/api/jobs/{id}/results` | `results.json` |
| POST | `/api/jobs/{id}/cancel` | touch the sentinel, or mark cancelled if still queued |
| DELETE | `/api/jobs/{id}` | delete a finished job's directory |
| GET | `/api/events` | SSE stream of status changes |

The `?since` / `?pos` offset tailing is deliberately the same model as
`pollKSRuns`' `logPos`, so the MATLAB client and the web page share one idea of
what is new.

**Running it as a Windows service.** Recommended: **NSSM** wrapping
`python -m uvicorn ephysd.main:app --host 0.0.0.0 --port 8787`, logging on as
the interactive lab user, **not** LocalSystem.

> MATLAB license checkout and NVIDIA CUDA both misbehave in session 0. Verify
> that a *real GPU sort* completes under the service account before trusting it.
> If CUDA refuses, fall back to a Task Scheduler task triggered **At log on**
> with the machine set to auto-login and the console locked — less tidy, but it
> keeps the GPU.

`CopySchedule` has already met this problem and exposes it as `RunWhen`:
`"signed_in"` (the default — a Task Scheduler interactive-token task, which
keeps the user's session and so the GPU) versus `"always"` (a stored-password
task that runs with nobody logged in, at the cost of needing UNC paths because
mapped drives do not exist there). Take the same option, the same default and
the same wording rather than inventing a new one, and reuse its task
registration code.

## 6. Path portability and safety

This is the part that is easy to get wrong. The API accepts a config that names
arbitrary filesystem paths and a Python executable. Left untouched, that is a
remote code execution endpoint for anyone holding the token.

`server/ephysd.toml`:

```toml
max_workers = 2
sorting_slots = 1
queue_root = "D:\\EPHYS\\queue"
matlab_exe = "C:\\Program Files\\MATLAB\\R2025a\\bin\\matlab.exe"
repo_root  = "C:\\src\\ephys_analysis"
python_exe = "C:\\Users\\lab\\miniconda3\\envs\\kilosort\\python.exe"
conda_env  = "kilosort"

[[roots]]
alias = "nas";  path = "\\\\nas01\\ephys";  mode = "read"
[[roots]]
alias = "data"; path = "D:\\EPHYS";         mode = "readwrite"
[[roots]]
alias = "out";  path = "E:\\EPHYS_OUT";     mode = "readwrite"
```

Rules, enforced in `paths.py` at submit time:

1. Every path field in the config must resolve — after `realpath`, symlink and
   `..` normalization — **under one of the roots**, or be written as
   `alias:relative/path`. Anything else is a 400 naming the offending field.
2. A write target must be under a `readwrite` root.
3. `Sorting.PythonExe` and `Sorting.CondaEnv` are **ignored from the client and
   overwritten from `ephysd.toml`**. Same for the MATLAB executable.
4. The runner re-checks the map before it starts, so a job that sat in the queue
   across a config change cannot escape.

Auth: a bearer token in `ephysd.toml` (or a small token file), compared with
`secrets.compare_digest`. Bind to the VPN or LAN interface. For access without
VPN later, put a **Tailscale** node on the box (no inbound firewall change, no
certificate) or a Cloudflare Tunnel — documented in `server/README.md`, not
built now.

## 7. The MATLAB client

**New: `pipeline/@EphysJobClient/EphysJobClient.m`** (handle class)

```matlab
c = EphysJobClient("http://ephysbox:8787", Token="...")
c = EphysJobClient.fromPrefs()                      % getpref('ephys_analysis','remote')
T    = c.roots()
job  = c.submit(cfg, Name=, Steps=, Datasets=, DryRun=, Staging=, Priority=)
T    = c.jobs(State=, Since=)                       % table
s    = c.job(id)
[txt, pos] = c.log(id, pos)                         % same shape as pollKSRuns' tail
evts = c.progress(id, since)
P    = c.plan(cfg, ...)                             % same columns as EphysPipeline.plan
c.cancel(id);  c.remove(id)
c.wait(id, ProgressFcn=, LogFcn=)                   % blocking; prints like a local run
t = c.monitor(id, ProgressFcn=, LogFcn=, Period=2)  % returns a started timer
```

`wait` and `monitor` call `ProgressFcn` with **the same struct `EphysPipeline`
sends**. That is the key design point: anything already written against a local
run — `onPipelineProgress`, the run diagram, an analyst's own script — works
against a remote run with no change.

Transport: `weboptions('HeaderFields', {'Authorization', "Bearer " + token},
'Timeout', 30, 'ContentType', 'json')`, with backoff retry on
`MATLAB:webservices:*` so a VPN blip does not kill a monitor.

**Phase 1 twin: `pipeline/@EphysJobQueue/EphysJobQueue.m`** — the same method
names, but reading and writing job directories directly on a mounted share.
`EphysJobClient` drops in later without touching callers.

## 8. GUI integration

Deliberately small; the app already has every widget needed.

- `pipeline/@EphysPreprocessingApp/buildRemoteTab.m` — server URL and token, a
  **Test** button, the jobs table, a progress bar, the log box, and **Cancel** /
  **Remove** / **Open dashboard** buttons.
- `pollRemoteJobs.m` — a timer in the exact shape of `pollKSRuns.m` and
  `pollCopyJob.m`; new properties `RemoteClient`, `RemoteJobs` and
  `RemoteMonitorTimer` alongside the existing `KSRuns` and `CopyJob` ones.
- `onSubmitRemote.m` — a **Submit to remote...** button next to **Run** on the
  Run tab: `gatherConfig()` → `c.submit(...)` → select the Remote tab. No new
  config plumbing at all.
- When one remote job is selected, its progress events feed straight into the
  existing `onPipelineProgress` and run diagram. Both are already data-driven,
  so neither file changes.

## 9. The dashboard

`server/static/index.html` — one page, no build step, no framework, matching the
repo's existing zero-toolchain HTML. Queue table; an expandable job row showing
the step chain in the same boxes and colours as the Run tab's diagram; a live
log pane fed by SSE; a Cancel button; and a Submit panel that takes a saved
config JSON (drag-drop or paste) plus a dataset selection.

**Do not try to share `runDiagramHTML.m`'s page with the web app.** Different
data sources (`uihtml` `Data` plus `DataChanged` versus SSE) and different
lifetimes; coupling them buys nothing. Share only the step palette: define it
once in MATLAB, expose it at `GET /api/steps` from a small generated JSON, and
have both pages read it. A comment in each file points at the other.

## 10. Documentation to write

| File | Change |
| --- | --- |
| this page | fill in as each phase lands; drop the status banner when phase 2 ships |
| [file-formats.md](file-formats.md) | new sections — `job.json`, `status.json`, `progress.ndjson`, mirroring the existing `ks4_status.json` section |
| [README.md](README.md) | a line in "How the pieces fit" |
| [EphysPreprocessingApp.md](EphysPreprocessingApp.md) | the Remote tab |
| [INSTALL.md](../pipeline/INSTALL.md) | new section — installing `ephysd` into the `kilosort` env, `ephysd.toml`, NSSM registration, the firewall rule, the session-0 / CUDA warning, the smoke test |
| [repo README](../README.md) | a Quick start line for submitting a remote job |
| `server/README.md` | new — operating the service, tunnels, troubleshooting |

## 11. Tests and verification

MATLAB, following the repo's `test_*.m` convention and added to
[`run_all_tests`](../pipeline/run_all_tests.m):

- `pipeline/test_EphysJobReporter.m` — NDJSON and `status.json` shapes;
  `fraction` monotonicity across a synthetic event sequence; atomic writes; the
  cancel sentinel triggers `EphysPipeline:Cancelled`; heartbeat updates.
- `pipeline/test_RemoteJobs.m` — end to end on a synthetic project:
  `makeSyntheticProject` → write a job directory → `ephysRunJob` in process →
  outputs **identical to a direct `EphysPipeline.run()`** of the same config
  (the fidelity check that matters; model it on `test_EphysPipelineScript`'s
  identical-output assertions) → `results.json` matches `pipe.Results`.
- `pipeline/test_EphysJobClient.m` — request construction and response parsing
  against a stub server; skipped when no server is configured.

Python, `server/tests/`:

- `test_paths.py` — traversal attempts (`..`, UNC, symlink, drive-relative, 8.3
  short names), write to a read-only root, the `PythonExe` override.
- `test_queue.py` — slot accounting including the sorting slot, FIFO and
  priority, crash detection via a stale heartbeat, restart rebuilding the index
  from disk.
- `test_api.py` — every endpoint, auth failures, cancelling a queued versus a
  running job.

Manual checklist, on the real machine, in order:

1. `python -m ephysd --check` prints the roots, the MATLAB path and the slot
   config.
2. Submit a synthetic-project job from MATLAB; `c.wait(id)` prints the same
   lines a local run does.
3. The same job is visible and live-updating in the browser; Cancel mid-
   `signals` leaves no partial `.mat` and marks the dataset `cancelled`.
4. A real staging job: NAS → local, then sorting, with a GPU sort completing
   **under the service account**.
5. Kill the `matlab.exe` of a running job; within 90 s it shows `failed` with
   `runner exited without finishing`.
6. Reboot the machine; the service comes back and the queue resumes.

## 12. Phasing

Each phase is independently useful.

**Phase 1 — file-backed queue, runner, staging, MATLAB client.**
`ephysRunJob.m`, `@EphysJobReporter`, `@EphysJobQueue`, and a worker that picks
up queued job directories and spawns `matlab -batch` — registered as a Windows
Task Scheduler task by reusing `CopySchedule`'s code rather than a new
`worker_loop.ps1`. Plus the two MATLAB test suites and the `file-formats.md`
schema sections. Works over a mounted share, unattended, with staging. No
network surface, so no auth needed yet.

**Phase 2 — the service and the dashboard.** `server/`, REST and SSE,
`paths.py` allowlist, token auth, `@EphysJobClient` (drop-in for
`@EphysJobQueue`), NSSM install, `server/README.md`, `INSTALL.md`. This is what
gets processing off the share and onto VPN, and gives the browser view.

**Phase 3 — GUI and polish.** The Remote tab and **Submit to remote...**, the
run diagram driven by remote events, archive and retention, and the documented
Tailscale / Cloudflare option for access without VPN.

## Risks

- **Session 0 and the GPU.** The most likely thing to bite. Verified in the
  manual checklist above, with the auto-login fallback documented.
- **MATLAB licensing.** Each concurrent `matlab -batch` takes a seat. With a
  single-seat licence, `max_workers` is effectively 1 and the sorting slot is
  moot. Confirm the licence type before choosing a default.
- **Client-supplied paths.** Addressed by the root allowlist and the `PythonExe`
  override. Without both, the API is remote code execution.
- **Disk.** Staging copies whole sessions to local disk. `copySessions` already
  warns on insufficient free space — surface that warning as a job-level failure
  rather than a log line — and `planLocalCleanup` / `runLocalCleanup` already
  know how to remove staged raw files whose source copy still exists, so
  retention is a matter of scheduling them (a third job kind, or a `cleanup`
  step after `export`), not of writing a policy.
