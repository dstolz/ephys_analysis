# ephys_analysis TO DO

## Instructions for Claude

Evaluate each item below and determine if it is still relevant. If it is, then provide a brief description of what needs to be done to complete the task. If it is not relevant, explain why it can be removed from the list.

You are the managing process. First, evaluate all items in the list and process them in an efficient order determined by you. Tune subagents to use Sonnet 5.5 or Opus 5.5 as you see fit based on the item's needs. Also tune effort for each agent as you see fit. Ask questions if you need clarification or guidance on any of the items.

Provide a concise summary of the completed tasks and any remaining items that need attention. Update the TO DO list accordingly. If you have any suggestions for new tasks or improvements, please add them to the "Suggestions" section at the end of the document, but do not process unless I move them to the TO DO list.

## TO DO

### EphysAnalysisApp:
- Move the current "common options" to be specific to each analysis panel.
- Add keyboard shortcuts to the Figures tab to switch between active panels. Indicate on the plot preview which panel is currently active.
- Add a search field to the Figures tab to locate specific parameters by name.
- Add option to show `box` around individual panels.
- add button to open the current figure in an external MATLAB figure window.
- make default figure ID smarter based on content, e.g., "PSTH" for a PSTH panel, "Raster" for a Raster panel, etc. When  a user duplicates a figure, then the new figure name should be "PSTH (2)" or "Raster (2)" etc.
- Include data type(s) and active panel type(s) in teh figure ID
- add panel option to plot ttl-like event traces (e.g., from digital input channels). The user should be able to select form solid bars represeting the event timing and duration, or a line that rises at onset and falls at offset. Give the user full control over color schemes and aesthetics for these event traces. Include option to draw baselines for events (middle of solid bars or zero line for line traces).
- Remove the plot default style dropdown that is currently above the "Add" button in the Figures tab. Instead, have the user always work on the panels within the arrangement section. Rename the "Arrangement" section to "Panels". 
- Replace "Add panel" dropdown with a "New panel" button that opens a dialog to select the type of panel to add. The dialog should also allow the user to specify the name of the new panel and key parameters for the panel. The dialog should include a schematic for each panel type to help the user understand what each panel does. The schematic should be a small representative plot. 
- Currently, adjusting row height or column width applies to all existing panels within row or column. Add option to adjust row height or column width for individual panels. The user should be able to select a panel and adjust its size independently of other panels in the same row or column.
- Provide a way to allow the user to manual specify spacing between panels. This may be best in a new dialog that allows the user to specify spacing between panels in both the horizontal and vertical directions. The dialog should allow the user to specify spacing in pixels or as a percentage of the panel size. The dialog should also allow the user to specify different spacing for different rows and columns.
- Add more info to the Dataset and Observation dropdowns on teh Figures tab. Add number of units to the Dataset dropdown. Add number of spikes to the Observation dropdown.
- Move the "Design" style dropdown and "Save look as design..." box to the right of the Dataset and Observation dropdowns.
- Patch overlays do not seem to work on the Raster panels.
- Add a layer Line style option to plot a line between onset and offset of the selected event with user control over line aesthetics.
- Allow the user to select different types of observation data based on what exists in the loaded dataset. The user should be able to select Sorted Units, Detected Spikes, MUA, LFP, AUX, and any other data types that may be present in the dataset. The Observation section should update to reflect options for the currently selected data. 
- Move the Chronux plots as panels in the Figures tab. If Chronux formated files do not exist, prompt the user to create it on demand for the selected dataset. The user should be able to select which observation data type to derive the chronux data from.
- Group these subsections into collapsible supersections with clear headings to help the user navigate the interface more easily. Bind keys to switch between super sections. The user should be able to navigate the interface using only the keyboard if desired.
- Improve data tips for plots to show more information about the data point being hovered over, not simply the raw x and y values. Include information about the dataset, observation, and any other relevant metadata. Allow the user to customize what information is shown in the data tips.
- On raster plots, hide y axis ticks by default.
  
## Suggested TO DOs --- STOP READING HERE
_DO NOT PROCESS UNLESS MOVED TO THE TO DO LIST_

- **Real-data checks of the 2026-10-05 batch.** All of it ran on synthetic and test data. Still to see on real recordings: Intan's software notch on a pre-3.0 `.rhd` recorded with the notch on, and the Visualize envelope's build time and disk load on a full 2 h × 64-channel recording on the USB disk. Envelope builds are not paused while a pipeline run reads the same disk.
- **Let the Sorting step write the `.bin`'s envelope.** `EphysTraceEnvelope.build()` exists. Writing it next to the `.bin` would save the first wide Visualize view of it a full read.
- **Clean up: NWB files.** `planLocalCleanup`'s `"export"` kind does not remove `<Name>.nwb` or `<Name>_nwbinspector.json`.
- **The pipeline app's window title** still reads "Ephys preprocessing - <name>" (`buildUI`, `updateTitle`) after the rename to `EphysPipelineApp`.
- **Wiki screenshots in one run.** On 2026-10-05, `wikiScreenshots` lost the app window at the Run tab shot twice, after the earlier tabs (MATLAB's embedded browser view was killed during `exportapp`). Each shot works on its own, so the shots were taken in two MATLAB runs. The script could open a fresh app window per group of shots.
- **API pages for the remaining classes.** `AppPrefs`, `TableSort`, `KCSDExport`, `PipelineDiagram`, `PlotAesthetics` and `PlotAestheticsDialog` have no API page: `tools/wiki/gen_api.py` skips classes outside its maps.
- **`EphysDataset.sortRunProcesses` off Windows.** Its `pgrep` path is untested, and it is not listed in `platformSupport` / `platforms.md`.
- **The standalone analysis script writes no run record**, so the compact-vs-standalone test cannot compare the runner's `analysis_runs/` record with one.

## Done
