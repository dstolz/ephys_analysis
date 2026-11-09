# Plan: Claude as a figure assistant for EphysFigGenApp

## Context

The owner has an Anthropic API key and asked what it would take to have
Claude help build figures in EphysFigGenApp.

The app computes nothing itself: it edits one `EphysAnalysisConfig` (JSON) and
`EphysAnalysisRunner` draws it (`figureFor` → `figureObservations` →
`computeFigure` → `renderFigure`). So Claude can work only by editing figure
specs through the config's existing methods, with every number still computed
by the runner. Saved config and Generate script remain the reproducible record
of what was drawn.

The first version of this plan built a chat window into the app. It was
revised the same day: Claude Desktop or Claude Code reaches the app through an
**MCP server** (Model Context Protocol). The client runs the conversation with
the model, so the app needs no API client, chat window or key storage. The
in-app window is kept as a later option (§8).

## Decisions made with the owner (2026-11-05)

| Question | Answer |
| --- | --- |
| What Claude may do | **Edit figures**: add and change figures and panels through the config's own methods; each change is one Undo step. No MATLAB code execution through these tools. |
| What may be sent to Anthropic | Config / figure JSON (paths removed), dataset metadata, and **preview PNGs** |
| Where the conversation happens | **Claude Desktop or Claude Code, through an MCP server** attached to the open app (revised from a separate in-app window, which is deferred to §8) |
| Which model | Recommended from a **model evaluation** on the synthetic project (§6) |

## What is required (summary)

1. Each person who uses it: Claude Desktop or Claude Code, signed in to a
   Claude plan or set up with an API key. The model is chosen in the client.
2. A Python that the MCP SDK and MathWorks' MATLAB Engine for Python both
   support, with the packages `mcp` and `matlabengine` (the version matching
   the MATLAB release).
3. The tool layer in MATLAB, `FigureAssistantTools` (§1): the core of the
   work, whatever front end is used.
4. The MCP server (§2): a thin Python bridge from the client to those tools,
   attached to the MATLAB session in which the app is open.
5. **Connect Claude...** in the app (§3): shares the session and gives the
   setup steps.
6. Tests that need no network and no model.
7. Docs: reference page, guide, python-drivers, README Dependencies,
   CHANGELOG.
8. A model evaluation on the synthetic project (§6).

## Design

### 1. `analysis/FigureAssistantTools.m` (new): tools over existing code

One MATLAB implementation, used by the MCP server, the evaluation, and the
in-app window if that is ever built.

- Entry points: `FigureAssistantTools.schemas()` returns the tool definitions
  as JSON (name, description, input schema with `additionalProperties:false`
  and `required`); `FigureAssistantTools.call(name, argsJson)` runs one tool
  on the open app and returns JSON (text, or a PNG path for an image).
  The schemas live here only; the server reads them.
- A figure is passed as a JSON **string** parameter (`figure_json`), decoded
  and normalized by the config's own `Figures` setter, so the schema stays
  small.
- The app is found through a new static `EphysFigGenApp.current()` (the last
  app opened; set in the constructor, cleared in `onClose`). With no app open,
  every tool returns *EphysFigGenApp is not open*.

| Tool | Does | Reuses |
| --- | --- | --- |
| `get_state` | figure ids, enabled, panel types, observe, selected figure, Defaults (ref / window / selection), active dataset key; paths removed | the config summary `issueReport.m` already writes, `SelectedFigure` |
| `get_figure(id)` | that figure's JSON as Save config writes it | `figureIndex`, `toStruct`, `writeJsonFile` encoding |
| `get_dataset_info` | digital lines, trial parameters and their values, trials / pairing, unit counts by class and shank, which signals exist; no spike times, no samples, no paths | `obj.Runner.source(k)` (`loadAnalysisSource` fields), the data `refreshDatasetInfo` shows |
| `list_panel_types` | the panel types with their default options and allowed values, and the addFigure template names | `EphysAnalysisConfig.panelTypes()` (`DefaultOptions`), `figureTemplates` |
| `get_reference(topic)` | one section of `documentation/EphysAnalysisConfig.md` (Panel types, Panel options, Figure fields, Layer fields, EventRef, EpochWindow, TrialSelection, ...) | the docs as the single source |
| `add_figure(template, id, figure_json)` | add; **validate; reject on any error, config unchanged**; else apply as one Undo step `"Claude: add <id>"` | `addFigure`, `validate`, `applyConfig(cfg, Action=...)` |
| `update_figure(id, figure_json)` | replace that figure; the same validate / reject / apply rule | `normalizeFigures`, `validate`, `applyConfig(..., Action=...)` |
| `add_panel(figure_id, type, where, relative_to)` | a panel `below` / `above` / `left` / `right` of another, or `free`; one Undo step | `EphysAnalysisConfig.placePanel`, as `onNewPanel(Type=, Where=)` does |
| `remove_figure(id)` | remove; one Undo step | `applyConfig(..., Action=...)` |
| `preview_figure(id, observation)` | select, compute the preview, return the skip reason (`figureSkipReason` / `figureSkipRemedy`) or the drawn PNG (≤ 1568 px long edge) | `refreshFigurePreview(Force)`; `onExportPreview` gains `Show=false` (no window; existing behavior unchanged) |

Out of scope for the tools: Save config, Run / Export, the Source, Export and
Report sections, any file writing, any MATLAB code execution.

Each tool's description carries the rules the in-app system prompt would have
held: read `get_dataset_info` before naming a line or a trial parameter; every
edit is validated and can be undone with Ctrl+Z in the app; say what changed.

### 2. MCP server: `analysis/mcp/ephys_figures_server.py` (new)

- Python, the official MCP SDK's low-level server over stdio. `list_tools`
  returns `FigureAssistantTools.schemas()`; `call_tool` forwards the name and
  arguments to `FigureAssistantTools.call` and returns its text, or the PNG as
  an image result. The server holds no tool logic, never evaluates MATLAB
  code it receives, and exposes nothing beyond the listed tools.
- It attaches to the shared MATLAB session that **Connect Claude...** named
  (`matlab.engine.find_matlab`, `connect_matlab`). Edits land in the open
  app, show in its figure tree and preview, and Ctrl+Z undoes them there.
- Errors come back as tool errors Claude can read: the app is not open, no
  shared session, the app is busy (an engine call waits while MATLAB runs a
  callback or a preview; the server gives up after a timeout and says so).
- The Python follows `documentation/python-drivers.md`: a new preference
  `McpPythonExe` (and `McpCondaEnv`), defaulting to
  `EphysPipelineApp.defaultPythonExe`. A separate environment is recommended,
  since the sorting environments pin other packages.
- `analysis/mcp/requirements.txt`: `mcp` and `matlabengine` with the version
  of the MATLAB release (25.1.x for R2025a; check PyPI).

### 3. **Connect Claude...** in the app

Edit menu item (`buildMenus.m`; the Help menu must keep ending with the issue
items and About). No toolbar icon, so the toolbar-tags assertion in
`test_EphysFigGenApp` is unchanged. It opens a small dialog that:
1. shares the session with `matlab.engine.shareEngine("EphysFigGenApp")`, and
   says that while it is shared, other programs running as you on this
   computer can connect to this MATLAB;
2. checks the Python in `McpPythonExe` can import `mcp` and `matlab.engine`
   (one `system()` call, as the python drivers do) and says what to install if
   not;
3. shows the entry for Claude Desktop's `claude_desktop_config.json` and the
   `claude mcp add` command for Claude Code, each with **Copy**. Nothing is
   written into either client's settings.

Its Help opens a new `documentation/EphysFigGenApp.md` heading, which
`tools/wiki/test_gen_pages.py` checks.

### 4. Data sent to Anthropic, and what the client can do

- Sent: config / figure JSON with file paths removed, dataset metadata as
  above, and preview PNGs when `preview_figure` is called (these show plotted
  data). Never raw signals, spike times or files through these tools.
- It goes through the person's Claude account, so that account's data terms
  apply; the lab should confirm its plan's terms are acceptable.
- The tools cannot run code. The client is another matter: Claude Desktop
  uses only the tools of the servers installed in it, but Claude Code can run
  shell commands and edit files with the person's permission. The "edit
  figures only" boundary holds for the tools, not for everything Claude Code
  can do.
- MCP clients ask before running a tool unless the person allows it for good;
  the guide recommends allowing the read tools and approving the edits.

### 5. Cost (estimate)

With a Claude plan, use counts against the plan's usage limits instead of
being billed per token. With an API key (Claude Code), the prices apply.
Prices, USD per million tokens, from the Anthropic pricing page
(platform.claude.com/docs/en/about-claude/pricing, read 2026-11-05):

| Model | Input | Cache write (5 min) | Cache read | Output |
| --- | --- | --- | --- | --- |
| Opus 5.5 (`claude-opus-5-5`) | $4 | $5 | $0.20 | $20 |
| Sonnet 5.5 (`claude-sonnet-5-5`) | $2 | $2.50 | $0.10 | $10 |
| Haiku 5.5 (`claude-haiku-5-5`), prompts ≤ 100 K tokens | $0.10 | $0.125 | $0.01 | $0.50 |

**Estimated cost per figure change.** These are modeled numbers, not
measurements:

| Scenario | Opus 5.5 | Sonnet 5.5 | Haiku 5.5 |
| --- | --- | --- | --- |
| Small edit (one option, no preview; 3 requests) | $0.085 | $0.043 | $0.0024 |
| Typical change (read, edit, validate, preview image; 4 requests) | $0.16 | $0.082 | $0.0045 |
| First change of a session, cold cache | $0.18 | $0.092 | $0.0048 |
| 100 typical changes | ≈ $16 | ≈ $8 | ≈ $0.45 |

**Token model behind the estimate** (the same for all three models):
- System prompt and tools: 6 K tokens. Earlier conversation: 10 K tokens.
  Both are cached with automatic caching.
- A typical change takes 4 requests:
  1. The user's message (0.1 K) → Claude calls `get_figure` and
     `get_dataset_info` (0.6 K output).
  2. The tool results (figure JSON 3 K + dataset info 1.5 K) → Claude calls
     `update_figure` (3 K output, thinking included).
  3. The validation result (0.2 K) → Claude calls `preview_figure` (0.3 K out).
  4. The preview image (about 2 K tokens at ≤ 1568 px; roughly one token per
     28×28 px patch) → Claude's reply (0.8 K out).
- Each request reads everything sent before it from the cache and writes only
  its new input. For a typical change that is about 78 K cache reads, 11 K
  cache writes and 4.7 K output tokens.
- The largest prompt is about 27 K tokens, below Haiku's 100 K price step.

**What the estimate leaves out:**
- Claude Desktop and Claude Code send their own system prompts and tools, so
  the cached prefix is larger than the 6 K assumed. Cached reads are cheap,
  so this raises the totals less than in proportion; the evaluation measures
  it.
- Output is about 50–57 % of the cost on every model, so the totals move
  almost in proportion to output tokens. Output depends on the model and the
  effort setting, which the estimate does not vary.
- Each validation rejection and retry adds roughly one request.
- A cheaper model that misreads the config schema more often will need more
  rounds, which narrows the gap.
- Validation catches invalid configs but not a valid figure that differs
  from what was asked (a wrong window or grouping). That risk depends on the
  model, not on price, and should decide the choice more than the cost does.

### 6. Model evaluation (recommends the model)

It runs once the MCP server works, and again whenever the tools or their
descriptions change. It spends money, so the owner approves each run first.
It is not part of `run_all_tests` and never runs in CI. It goes through
Claude Code, the same path people use, so it measures the client's own
overhead too.

**Cases** (`tools/assistant_eval/cases.json`, written with the owner): 20–30
requests a lab member would type. Each case has:
- a starting config (`tools/assistant_eval/configs/`) on the synthetic test
  project, so no lab data is sent during the evaluation;
- the request text;
- the expected result: the figure the owner accepts (JSON, with the fields
  that matter listed in `check`), or `ask` when the request is ambiguous or
  impossible and the right answer is a question.

The cases cover:

| Kind | About |
| --- | --- |
| Small edits (bin, smoothing, a toggle, a color) | 8 |
| Alignment, window, trial selection, group by | 8 |
| New figures with several panels | 6 |
| Session and probe figures | 3 |
| Ambiguous or impossible (a line or parameter the dataset lacks) | 4 |

**Runner** (`tools/assistant_eval/run_eval.py`): Python, because MATLAB
must stay idle to answer the MCP server's calls; a MATLAB runner blocked in
`system()` would never let them through.
1. The owner opens the app on the synthetic project and uses **Connect
   Claude...**.
2. For each case, arm and trial, the runner loads the starting config into
   the app through the engine, runs Claude Code non-interactively with the
   arm's model, only this server's tools allowed and the built-in shell and
   file tools denied, and reads the JSON result (turns, usage, cost).
3. It then grades the app's config through the engine
   (`gradeAssistantCase.m`) and keeps the transcript and the final config.

The Claude Code options for this (non-interactive mode, model, MCP config,
allowed and denied tools, JSON output, effort) are checked against the
installed version before the first run.

**Grading** is done in code; no model judges. The resulting figure is compared
with the expected one after `cfg.figureFor` resolves every `"default"`:
- on the fields `check` names;
- numbers compared as the config stores them, with no tolerance;
- every other figure must be unchanged (`isequaln`).

Each trial gets one outcome:

| Outcome | Meaning |
| --- | --- |
| correct | matches the expected figure |
| **valid but wrong** | passes `validate` but differs from the expected figure, or is an edit made on an `ask` case. This is the outcome that matters most. |
| invalid | ends with validation errors, or with no edit |
| asked | asks a question; correct only on an `ask` case |

Recorded with each trial: turns, validation rejections, tokens and cost as
Claude Code reports them.

**Arms:** 3 trials per case for each arm.

| Arm | Why |
| --- | --- |
| Opus 5.5, effort `high` | the most capable default |
| Opus 5.5, effort `medium` | the larger model at lower effort may match a smaller model's cost with fewer errors (only if Claude Code can set effort for a run) |
| Sonnet 5.5 | |
| Haiku 5.5 | |

**Cost of one run** (30 cases × 3 trials, at §5's typical-change estimate;
the client's overhead adds to it):

| Arm | Estimated cost |
| --- | --- |
| Opus `high` | ≈ $15 |
| Opus `medium` | ≤ $15 |
| Sonnet | ≈ $7 |
| Haiku | < $1 |
| All four | about $40, plus the client's overhead |

Before it starts, the runner prints its estimate and asks to go on. It stops
at a spending cap given as an argument, from the cost Claude Code reports.

**Report** (`tools/assistant_eval/results/<date>.md` and a CSV):
- each arm's count of every outcome, with the case ids;
- the cost per correct change;
- every valid-but-wrong trial, with the field that differed and a link to its
  transcript.

**Decision:** the owner picks the model the guide recommends from the report.
- Proposed bar: the cheapest arm with **no** valid-but-wrong trial, and a
  correct count within a few cases of the best arm.
- If no arm meets the bar, the tools are narrowed (an option tool that takes
  only the values `panelTypes` lists, in place of a whole-figure JSON
  rewrite), and the evaluation is run again.
- If the tool descriptions are tuned by reading these cases, a third of the
  cases are held out of that tuning, and the decision is read on them.

### 7. Later: config files without the app

For people who write scripts: the server starts its own MATLAB when no app is
shared (`matlab.engine.start_matlab`, slow to start) and adds
`open_config(path)` and `save_config_as(path)`, which writes a new file and
never overwrites one. Not in the first version.

### 8. Later, only if the MCP setup proves too much: a window in the app

A separate window (in the pattern of `analysis/NotePad.m`) that runs the same
tools with an API key. Findings to keep from the first version of this plan:
- No official Anthropic SDK exists for MATLAB: the Messages API over raw HTTP
  with `matlab.net.http`, `anthropic-version: 2026-10-21`, `tool_choice`
  left `auto` (forced tool choice is a 400 on Opus 5.5), effort set
  explicitly, refusal fallback (`fallbacks: "default"`), automatic caching.
- The history must be kept as the raw JSON text the API returned:
  `jsondecode` → `jsonencode` does not round-trip (a 1-element array becomes a
  scalar), and Opus 5.5 rejects or drops thinking blocks whose history was
  edited. A small `jsonSlice` helper would cut each `content` out of the
  response text.
- Key in MATLAB's vault (`getSecret` / `setSecret`, R2024a+), else
  `ANTHROPIC_API_KEY`; never in the config, preferences, Log tab or issue
  reports.
- Check whether `matlab.net.http` runs on a `backgroundPool` thread; if not,
  call it synchronously behind a progress dialog.

## Files

New:
- `analysis/FigureAssistantTools.m`, `analysis/test_FigureAssistantTools.m`;
- `analysis/mcp/ephys_figures_server.py`, `analysis/mcp/requirements.txt`,
  `analysis/mcp/test_ephys_figures_server.py`;
- `analysis/@EphysFigGenApp/onConnectClaude.m` (the dialog);
- the evaluation in `tools/assistant_eval/` (`cases.json`, `configs/`,
  `run_eval.py`, `gradeAssistantCase.m`, `results/`) and its test
  `analysis/test_AssistantEval.m`.

Changed:
- `analysis/@EphysFigGenApp/EphysFigGenApp.m` (`current()`), `onClose.m`,
  `buildMenus.m`, `helpURL.m`, `onExportPreview.m` (`Show=`);
- `documentation/EphysFigGenApp.md` (new section, Menus, Preferences, Where
  the code is, Tests), `documentation/analysis-app-guide.md` (setting up and
  using Claude, in plain steps), `documentation/python-drivers.md` (the
  server's row), `documentation/README.md` (Dependencies: the Python
  packages, Claude Desktop or Claude Code; tests table);
- `tools/wiki/gen_api.py` (a group for `FigureAssistantTools`),
  `CHANGELOG.md`.

## Verification

- `test_FigureAssistantTools` on the analysis fixture, headless, no network:
  `schemas()` is valid JSON with strict schemas; `call` with each tool; an
  add applies and one Undo restores the config exactly (`isequalConfig`); an
  invalid `rect` is rejected and the config is unchanged; `get_dataset_info`
  and `get_state` contain no paths; `preview_figure` returns a PNG or the
  skip reason; with the app closed, *EphysFigGenApp is not open*.
- `test_ephys_figures_server.py` (pytest, a fake MATLAB bridge, no engine):
  the tool list comes from the schemas; calls are forwarded unchanged; a PNG
  becomes an image result; not open, busy and timeout become tool errors.
  Run locally (`python -m pytest analysis/mcp`); CI has no Python test job.
- `test_AssistantEval` checks the grader on canned final configs: a correct
  figure, a valid but wrong one, an invalid edit and a question.
- The sections of `test_EphysFigGenApp` that build the menus and
  `onExportPreview`, plus `test_ClassdefDeclarations`, as `python
  .github/scripts/select_suites.py --worktree --sections --why --expect`
  names them, run via `tools\Run-Tests.ps1`; preferences isolated with
  `AppPrefs.useTemporary()`.
- `python tools/wiki/test_gen_pages.py` for the new Help anchor.
- One manual check in Claude Desktop and one in Claude Code on the synthetic
  project: "a raster over a PSTH grouped by Depth for each SU" → figure added
  in the open app, validated, previewed, undone with Ctrl+Z.
- The MATLAB suites run in CI (R2025a, `matlab-tests.yml`) on the pushed
  branch, or on the owner's machine via `tools\Run-Tests.ps1`. Results
  reported by suite name, run and not run.

## Order of work

1. `FigureAssistantTools` (`schemas`, `call`), `EphysFigGenApp.current()`,
   `onExportPreview(Show=)`, `test_FigureAssistantTools`.
2. The MCP server and its tests; **Connect Claude...**; the manual checks in
   Claude Desktop and Claude Code.
3. Model evaluation (§6):
   1. Write the cases with the owner.
   2. Build the runner, the grader and `test_AssistantEval`.
   3. Run it once the owner approves the spend.
   4. The owner picks the recommended model from the report.
4. Docs, CHANGELOG, the gen_api group.
5. Later, only if needed: config files without the app (§7); the in-app
   window (§8).

## Open items

- Step 2: how an engine call behaves while the app runs a callback, a
  preview or a modal dialog (the server's timeout depends on it).
- Step 2: whether sharing the session can be stopped short of quitting
  MATLAB; the dialog says which.
- Step 2: a Python version both `mcp` and `matlabengine` support on the lab's
  machines.
- Step 3: the Claude Code options the runner needs, and whether effort can be
  set per run.
- Before lab members use it: the data terms of the lab's Claude plan.
