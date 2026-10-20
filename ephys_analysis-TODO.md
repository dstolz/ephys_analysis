# ephys_analysis TO DO

## Instructions for Claude

Evaluate each item below and determine if it is still relevant. If it is, then provide a brief description of what needs to be done to complete the task. If it is not relevant, explain why it can be removed from the list.

You are the managing process. First, evaluate all items in the list and process them in an efficient order determined by you. Tune subagents to use Sonnet 5.5 or Opus 5.5 as you see fit based on the item's needs. Also tune effort for each agent as you see fit. Ask questions if you need clarification or guidance on any of the items.

Provide a concise summary of the completed tasks and any remaining items that need attention. Update the TO DO list accordingly. If you have any suggestions for new tasks or improvements, please add them to the "Suggestions" section at the end of the document, but do not process unless I move them to the TO DO list.

## TO DO

## Suggested TO DOs --- STOP READING HERE

- **Favorites in the pipeline app.** `EphysPipelineApp` neither shows nor sets stars; its datasets table could read `<Name>_favorites.json` (`DatasetFavorites`) the same way.
- **Copy the favorites file with the analysis files.** `DatasetOutputs.analysisFiles` (the File menu's "copy what EphysAnalysisApp reads") leaves `<Name>_favorites.json` behind; whole-folder transfers carry it. About four lines.
- **"Starred only" in the Observations section.** Generate (and the < > stepping) could keep only the starred units or channels, so a batch draws just the favorites.
- **Richer Favorites entries.** The list reads "name · unit 12"; it could add the unit's class, channel and depth once the dataset's source is loaded. A session figure's matched observation shows no star, and `figureCaption` does not mention stars.
- **PSTH heat map:** a group-color strip along the left edge (as the heat map of trials has) if the group colors should show in the image; `display` is not carried over when a PSTH panel's type is changed to Heat map and back.
- **The remaining four-element RGBA line colors** (undocumented; SVG kept them in R2025a, but only the patch route is documented): `rasterInto.m:126`, `figEventMarks.m:114,116` (event spans), `drawRasterPanel.m:157` (a legend swatch). Draw them as patch edges with `EdgeAlpha`, as the event traces now do.
- **One raster sort helper.** `rasterInto` keeps its own copy of the sort key; the heat map of trials and the event traces use the new private `figEpochOrder`.
- **Event-trace ticks after a zoom.** Whether a bar is narrower than `minWidth` is judged when the figure is drawn, not again after an interactive zoom.
- **Wiki:** the pages and screenshots for the Figures tab (PSTH Display, event-trace sort / Narrowest bar, the Favorites rows and star toggles, the Data tab's ★ column) and for the retired Chronux script route are stale.

## Done

### 2026-10-20 (branch `figures-followups`)

- **Favorites (stars) at the dataset, channel and unit level** (906875a, 2803566, 5d3f54a). A plain star, kept in `<Name>_favorites.json` in each dataset's output folder (`DatasetFavorites`), so it travels with the data. A unit's star belongs to the sort it was set on; a detection channel is starred as its recording channel. In the analysis app: a ★ column in the Data tab's datasets table, a ☆/★ toggle beside the Dataset drop-downs (Alignment, Figures) and the Observation drop-down, starred items marked "★" in those drop-downs, and a **Favorites** drop-down with a filter field (Figures and Alignment tabs) that jumps to the dataset and previews the unit or channel. Reports and exports carry the star: a `starred` column in `unitSummary`, `populationAnalysis`, `P.datasets` and `sessionTable`; Starred rows and a column in the report's summary tables; ★ in the HTML report, "(starred)" in the PDF. A read-only folder is reported in the status bar, never a crash.
- **PSTH drawn as a heat map** (24835a3, d61657f). PSTH option **Display** `trace` | `heatmap`: one row per trial group (e.g. each AM depth), first on top, colored by that unit's own PSTH (never scaled across units), a color bar in the measure's unit, per-panel **Colormap** and **Color limits**; auROC on [0 1] with the modulation window as a line over the image. The editor shows only the rows that apply to each display.
- **Event traces** (9ce60ad). Sub-rows sort as a raster's (`rasterSort`, `rasterSortEvent`, `rasterSortOrder`, `rasterByGroup`, via the new `figEpochOrder` shared with the heat map of trials); **Narrowest bar** (`minWidth`, points) gives zero-length and very short bars a visible tick; event-trace panels merge across sessions in session figures; messages use the type's label without an article ("probe map panels are not merged across sessions"); translucent logic levels are patch edges with `EdgeAlpha`, not the undocumented RGBA line color (SVG export keeps `stroke-opacity`, as a test checks).
- **Chronux script route retired** (fc0f06b). `loadChronuxExport` and `chronuxSpikeTrains` deleted, `chronuxPairs` folded into `chronuxCoherence` (error `chronuxCoherence:BadPair`), the worked example and table rows removed from the docs. The figures' spectral panels and the pipeline's Chronux export are unchanged.
- **One list of baseline modes per panel type** (393ab3c). `EphysAnalysisConfig.baselineModes(type, source)` feeds `validate`, the figure editor and `adoptPanelOptions`.
- **`modulationWindow.m` and `xregion`: no change.** Its only caller, the PSTH panel, draws the window behind its own traces, and a PSTH panel has no raster bands, so the case never arises. The new PSTH heat map display, which does draw over an image, marks the window with a line.
