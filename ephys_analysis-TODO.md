# ephys_analysis TO DO

## Instructions for Claude

Evaluate each item below and determine if it is still relevant. If it is, then provide a brief description of what needs to be done to complete the task. If it is not relevant, explain why it can be removed from the list.

You are the managing process. First, evaluate all items in the list and process them in an efficient order determined by you. Tune subagents to use Sonnet 5.5 or Opus 5.5 as you see fit based on the item's needs. Also tune effort for each agent as you see fit. Ask questions if you need clarification or guidance on any of the items.

Provide a concise summary of the completed tasks and any remaining items that need attention. Update the TO DO list accordingly. If you have any suggestions for new tasks or improvements, please add them to the "Suggestions" section at the end of the document, but do not process unless I move them to the TO DO list.

## TO DO

- Add a new feature to let the user "star" or "favorite" certain datasets for quick access. This should be available at the dataset, channel, and unit levels. The starred datasets should be easily accessible from a dedicated "Favorites" dropdown that is visible in the Figures tab and other relevant areas of the application. The feature should allow users to add or remove datasets from their favorites list, and the list should persist across sessions. The rating system should be intuitive and user-friendly, allowing users to quickly identify their most important datasets. Additionally, consider implementing a search or filter function within the Favorites dropdown to help users find their starred datasets more efficiently. Include the rating in any exported reports or summaries of the datasets, so that users can easily see which datasets they have marked as favorites. Ensure that the feature is well-documented and that users are informed about how to use it effectively.
- **`modulationWindow.m` uses `xregion`** for the auROC window shading, which MATLAB paints behind opaque patches: the same cause as the raster patch-overlay bug fixed today. Draw it as a patch if it ever has to sit over raster bands.
- **Event traces:** sort a trace panel's per-epoch rows as a raster sorts; a minimum drawn width for zero-length intervals in bars mode; event traces in session figures (refused today); the session messages read "a eventTrace panel" (article). Translucent trace lines use MATLAB's undocumented RGBA line color, which SVG export may flatten.
- **Chronux file helpers.** With the Chronux tab gone, `loadChronuxExport`, `chronuxPairs` and `chronuxSpikeTrains` serve only scripts and each other. Keep them unless the "analyze a Chronux file by script" route is retired too.

- **One list of baseline modes per panel type.** The modes each type takes are written in three places (`validate`, `figureEditorChoices`, `adoptPanelOptions`); one static helper would keep them in step.

- Add PSTH option to show as a heatmap (`imagesc()`) instead of a line plot. This would allow for better visualization of firing rate changes over time across multiple trials. The heatmap should be color-coded to represent firing rates, with a clear legend indicating the scale. Users should be able to toggle between the line plot and heatmap views easily. Additionally, implement options for customizing the color map and scaling to enhance interpretability. Ensure that the heatmap is compatible with existing export functions and that it maintains performance with large datasets.
