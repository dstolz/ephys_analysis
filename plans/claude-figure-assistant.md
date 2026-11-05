# Plan: a Claude figure assistant in EphysFigGenApp

## Context

The owner has an Anthropic API key and asked what it would take to put a
Claude chat assistant into EphysFigGenApp to help build figures.

The app computes nothing itself: it edits one `EphysAnalysisConfig` (JSON) and
`EphysAnalysisRunner` draws it (`figureFor` → `figureObservations` →
`computeFigure` → `renderFigure`). So the assistant can work only by editing
figure specs through the config's existing methods, with every number still
computed by the runner. Saved config and Generate script remain the
reproducible record of what was drawn.

## Decisions made with the owner (2026-11-05)

| Question | Answer |
| --- | --- |
| What the assistant may do | **Edit figures**: add and change figures and panels through the config's own methods; each change is one Undo step. No MATLAB code execution. |
| What may be sent to Anthropic | Config / figure JSON (paths removed), dataset metadata, and **preview PNGs** |
| Where the chat lives | A **separate window**, opened from a menu item and a toolbar icon |

## What is required (summary)

1. An Anthropic API key and billing; lab machines must reach
   `https://api.anthropic.com` (MATLAB honors its web proxy preferences).
2. An HTTP client in MATLAB. There is no official Anthropic SDK for MATLAB,
   so the Messages API is called over raw HTTP with `matlab.net.http` (base
   MATLAB, no toolbox).
3. A small set of tools (JSON-schema functions) that map onto existing config
   and app methods; Claude calls them, MATLAB executes them.
4. A chat window, a menu item and toolbar icon, preferences.
5. Key storage outside the config, preferences, Log tab and issue reports.
6. Tests that run with no network (an injected fake transport).
7. Docs: reference page, guide, README Dependencies, CHANGELOG.

## Design

### 1. `analysis/ClaudeClient.m` (new): Messages API client

- `POST https://api.anthropic.com/v1/messages`, headers `x-api-key`,
  `anthropic-version: 2026-10-21`, `content-type: application/json`.
- Defaults (preferences, see §5): model `claude-opus-5-5`; `thinking:
  {type:"adaptive"}`; `output_config.effort: "high"` (Opus 5.5 defaults to
  `medium`, so it is set explicitly); `max_tokens: 16000`, non-streaming;
  top-level `cache_control: {type:"ephemeral"}` so the static system prompt,
  tools and prior turns are cached; `tool_choice` left `auto` (forced tool
  choice is a 400 on Opus 5.5).
- Refusal fallback on by default: `fallbacks: "default"` with header
  `anthropic-beta: server-side-fallback-2026-07-01`; `stop_reason` is checked
  before content is read (`end_turn`, `tool_use`, `max_tokens`, `refusal`).
- Retries: 429 / 5xx / 529 / connection errors, 2 retries honoring
  `retry-after`; 400 / 401 / 403 / 404 not retried, the message shown verbatim.
- `Transport` property: a function handle `(url, headers, bodyText) ->
  (status, headers, bodyText)`, by default the `matlab.net.http` call; tests
  inject a fake.
- **History is kept as raw JSON text, never re-encoded.** `jsondecode` →
  `jsonencode` does not round-trip (a 1-element array becomes a scalar, a
  1x1 struct array an object), and Opus 5.5 rejects or drops thinking blocks
  whose history was edited. So each assistant message's `content` is sliced
  out of the response text and spliced back verbatim into later requests.
  New helper `pipeline/jsonSlice.m` (a bracket- and string-aware scanner,
  beside `pipeline/writeJsonFile.m` / `readJsonFile.m`), unit-tested.
  `jsondecode` is used only to read values (stop_reason, tool_use blocks,
  usage).
- Requests run off the UI thread with `parfeval(backgroundPool, ...)` +
  `afterEach`, as `pipeline/folderReachable.m` and `EphysTraceEnvelope` do.
  **Verify first** that `matlab.net.http` runs on a thread worker in R2025a;
  if not, call synchronously behind an indeterminate `uiprogressdlg` with
  Cancel.

### 2. `analysis/FigureAssistantTools.m` (new): tools over existing code

All tools are `strict: true` (`additionalProperties:false`, `required`). A
figure is passed as a JSON **string** parameter (`figure_json`), decoded and
normalized by the config's own `Figures` setter, so the schema stays small.

| Tool | Does | Reuses |
| --- | --- | --- |
| `get_state` | figure ids, enabled, panel types, observe, selected figure, Defaults (ref / window / selection), active dataset key; paths removed | the config summary `issueReport.m` already writes, `SelectedFigure` |
| `get_figure(id)` | that figure's JSON as Save config writes it | `figureIndex`, `toStruct`, `writeJsonFile` encoding |
| `get_dataset_info` | digital lines, trial parameters and their values, trials / pairing, unit counts by class and shank, which signals exist; no spike times, no samples, no paths | `obj.Runner.source(k)` (`loadAnalysisSource` fields), the data `refreshDatasetInfo` shows |
| `list_panel_types` | the panel types with their default options and allowed values, and the addFigure template names | `EphysAnalysisConfig.panelTypes()` (`DefaultOptions`), `figureTemplates` |
| `get_reference(topic)` | one section of `documentation/EphysAnalysisConfig.md` (Panel types, Panel options, Figure fields, Layer fields, EventRef, EpochWindow, TrialSelection, ...) | the docs as the single source |
| `add_figure(template, id, figure_json)` | add; **validate; reject on any error, config unchanged**; else apply as one Undo step `"Assistant: add <id>"` | `addFigure`, `validate`, `applyConfig(cfg, Action=...)` |
| `update_figure(id, figure_json)` | replace that figure; the same validate / reject / apply rule | `normalizeFigures`, `validate`, `applyConfig(..., Action=...)` |
| `add_panel(figure_id, type, where, relative_to)` | a panel `below` / `above` / `left` / `right` of another, or `free`; one Undo step | `EphysAnalysisConfig.placePanel`, as `onNewPanel(Type=, Where=)` does |
| `remove_figure(id)` | remove; one Undo step | `applyConfig(..., Action=...)` |
| `preview_figure(id, observation)` | select, compute the preview, return the skip reason (`figureSkipReason` / `figureSkipRemedy`) or the drawn PNG as an image block (≤ 1568 px long edge, base64) | `refreshFigurePreview(Force)`; `onExportPreview` gains `Show=false` (no window; existing behavior unchanged) |

Out of scope for the assistant: Save config, Run / Export, the Source, Export
and Report sections, any file writing, any MATLAB code execution.

System prompt (static, cached): what the app is; never invent line names or
trial parameters, read `get_dataset_info` first; ask when the request is
ambiguous; every edit goes through validation; say what changed and that
Ctrl+Z undoes it.

### 3. `analysis/FigureAssistant.m` (new): the window

A `uifigure` class in the pattern of `analysis/NotePad.m` / `NoteSearch.m`
(one window, reused, held by the app). Transcript, input box, Send, Stop,
New conversation, and a line with the tokens used and the estimated cost from
`usage`. It runs the loop: send → execute every `tool_use` block → return all
`tool_result`s in one user message → repeat until `end_turn`, capped at 20
rounds per user message. Each tool call is shown in the transcript ("Added
figure unit_card", "Validation rejected: ...").

App wiring: Edit menu item **Figure assistant...** (`buildMenus.m`; the Help
menu must keep ending with the issue items and About), a toolbar icon
(`buildToolbar.m`, SVG in `analysis/icons/toolbar`), a property holding the
window, closed with the app (`onClose.m`). The window's Help opens a new
`documentation/EphysFigGenApp.md` heading, which `tools/wiki/test_gen_pages.py`
checks. A separate window leaves the five tabs and splash steps that
`test_EphysFigGenApp` asserts unchanged; its toolbar-tags assertion gains the
new tag.

### 4. Data sent to Anthropic

Config / figure JSON with file paths removed, dataset metadata as above, and
preview PNGs when `preview_figure` is called (these show plotted data). Never
raw signals, spike times or files. Stated in the window and in the docs.

### 5. Key and preferences

- Key: `getSecret("ANTHROPIC_API_KEY")` on R2024a+ (MATLAB's encrypted
  vault; **Set API key...** in the window calls `setSecret`), else the
  environment variable `ANTHROPIC_API_KEY`. Never written to the config,
  preferences, Log tab or `issueReport`.
- `AppPrefs` group `EphysFigGenApp`: `AssistantModel` (default
  `claude-opus-5-5`), `AssistantEffort` (`high`), `AssistantPosition`.

### 6. Cost (estimate; the window shows actual usage)

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
- Output is about 50–57 % of the cost on every model, so the totals move
  almost in proportion to output tokens. Output depends on the model and the
  effort setting, which the model does not vary.
- Each validation rejection and retry adds roughly one request.
- A cheaper model that misreads the config schema more often will need more
  rounds, which narrows the gap.
- Validation catches invalid configs but not a valid figure that differs
  from what was asked (a wrong window or grouping). That risk depends on the
  model, not on price, and should decide the choice more than the cost does.
- Measure before fixing the default: the window's usage line logs the actual
  tokens per change for each model.

## Files

New: `analysis/ClaudeClient.m`, `analysis/FigureAssistantTools.m`,
`analysis/FigureAssistant.m`, `pipeline/jsonSlice.m`, the toolbar SVG,
`analysis/test_ClaudeClient.m`, `analysis/test_FigureAssistant.m`.

Changed: `analysis/@EphysFigGenApp/EphysFigGenApp.m` (property),
`buildMenus.m`, `buildToolbar.m`, `onClose.m`, `helpURL.m`,
`onExportPreview.m` (`Show=`), `documentation/EphysFigGenApp.md` (new
section, Menus, Toolbar, Preferences, Where the code is, Tests),
`documentation/analysis-app-guide.md`, `documentation/README.md`
(Dependencies: network and key, no toolbox; tests table),
`tools/wiki/gen_api.py` (a group for the new public classes),
`analysis/test_EphysFigGenApp.m` (toolbar tags), `CHANGELOG.md`.

## Verification

- `test_ClaudeClient` (fake transport): request headers and body; strict tool
  schemas; the tool loop; raw history splice byte-identical; 429 → retry; 400
  not retried; `refusal` and `max_tokens` surfaced; `jsonSlice` edge cases
  (escaped quotes, brackets in strings, nested arrays).
- `test_FigureAssistant` on the analysis fixture with a scripted fake
  conversation: add_figure applies and one Undo restores the config exactly
  (`isequalConfig`); an invalid `rect` is rejected and the config is
  unchanged; `get_dataset_info` / `get_state` contain no paths;
  `preview_figure` returns a PNG block or the skip reason; the key never
  appears in the Log tab or `issueReport`.
- The sections of `test_EphysFigGenApp` that build the menus and toolbar and
  `onExportPreview`, plus `test_ClassdefDeclarations`, as `python
  .github/scripts/select_suites.py --worktree --sections --why --expect`
  names them, run via `tools\Run-Tests.ps1`; preferences isolated with
  `AppPrefs.useTemporary()`.
- `python tools/wiki/test_gen_pages.py` for the new Help anchor.
- One manual live check with the owner's key on the synthetic project:
  "a raster over a PSTH grouped by Depth for each SU" → figure added,
  validated, previewed, undone.
- The suites run in CI (R2025a, `matlab-tests.yml`) on the pushed branch, or
  on the owner's machine via `tools\Run-Tests.ps1`. Results reported by suite
  name, run and not run.

## Order of work

1. `ClaudeClient` + `jsonSlice` + `test_ClaudeClient` (no UI).
2. `FigureAssistantTools` + `test_FigureAssistant` (tools driven headlessly).
3. `FigureAssistant` window, menu, toolbar, preferences, `onExportPreview(Show=)`.
4. Docs, CHANGELOG, the gen_api group.

## Open items to settle during step 1

- Whether `matlab.net.http` runs on a `backgroundPool` thread worker in
  R2025a (decides background vs. synchronous with a progress dialog).
- The effort default (`high` vs `medium`): measure on a few real requests via
  the window's usage line before fixing the default.
