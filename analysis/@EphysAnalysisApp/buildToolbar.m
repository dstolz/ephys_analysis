function buildToolbar(obj)
%buildToolbar  Toolbar under the menu bar: the app's most used commands as icons.
%   Each tool calls the same method as its menu item or tab button, and its
%   tooltip names the menu item's keyboard shortcut when it has one (Ctrl,
%   or Cmd on a Mac). Left to right, in groups:
%     File      New config, Open config, Save config
%     Edit      Undo, Redo of the figure editor's edits (onUndoRedo)
%     Look      Scan for datasets (Data tab), Preview the selected figure
%               (Figures tab), Search notes (onSearchNotes: the notes of
%               every scanned dataset)
%     Run       Validate config, Plan, Run, Cancel run (Export tab)
%     Results   Open the last run's report, its figure folder
%     Tools     Open pipeline app (File menu)
%     Help      Help for this tab
%   Preview shows the Figures tab, and Validate, Plan and Run the Export tab,
%   where they put what they find. Undo and Redo are the Edit menu's items
%   (refreshEditMenu keeps their tooltips, "Undo Add panel (Ctrl+Z)", and
%   their on / off the menu's: on with a step to take, on the Figures tab
%   only). The Run tools follow the Export tab's
%   buttons: Validate, Plan and Run are off while a run goes, Cancel is on
%   only then, and the two Results tools come on when a run wrote a report
%   or figures (onRunExport). Each tool's Tag names its icon,
%   analysis/icons/toolbar/<Tag>.svg.

iconDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "icons", "toolbar");
tb = uitoolbar(obj.Fig);
obj.Toolbar = tb;

% --- File: the config ---
addTool(tb, iconDir, "new",  "New config",  "N", @(~,~) obj.onNewConfig());
addTool(tb, iconDir, "open", "Open config", "O", @(~,~) obj.onOpenConfig());
addTool(tb, iconDir, "save", "Save config", "S", @(~,~) obj.onSaveConfig());

% --- Edit: the figure editor's undo history, as the Edit menu ---
obj.ToolbarUndoTool = addTool(tb, iconDir, "undo", "Undo", "Z", @(~,~) obj.onUndoRedo("undo"), Separator=true);
obj.ToolbarRedoTool = addTool(tb, iconDir, "redo", "Redo", "Y", @(~,~) obj.onUndoRedo("redo"));
obj.ToolbarUndoTool.Enable = "off";
obj.ToolbarRedoTool.Enable = "off";

% --- Look: the datasets and the figure being edited ---
addTool(tb, iconDir, "scan", "Scan for datasets", "", @(~,~) obj.onScan(), Separator=true);
addTool(tb, iconDir, "preview", "Preview the selected figure (Figures tab): the observation picked on the active " + ...
    "dataset, or a session figure over its datasets", "", @(~,~) preview(obj));
addTool(tb, iconDir, "notes", "Search notes: every note on the scanned datasets, their channels and units; " + ...
    "go to the dataset of the one found", "", @(~,~) obj.onSearchNotes());

% --- Run: as the Export tab's buttons ---
obj.ToolbarValidateTool = addTool(tb, iconDir, "validate", "Validate config", "", ...
    @(~,~) onExportTab(obj, @() obj.onValidate()), Separator=true);
obj.ToolbarPlanTool = addTool(tb, iconDir, "plan", "Plan: which figure runs on which ticked dataset", "", ...
    @(~,~) onExportTab(obj, @() obj.onPlan()));
obj.ToolbarRunTool = addTool(tb, iconDir, "run", "Run the enabled figures on the ticked datasets", "", ...
    @(~,~) onExportTab(obj, @() obj.onRunExport()));
obj.ToolbarCancelTool = addTool(tb, iconDir, "cancel", "Cancel run", "", @(~,~) obj.onCancelRun());
obj.ToolbarCancelTool.Enable = "off";

% --- Results: the last run's files ---
obj.ToolbarReportTool = addTool(tb, iconDir, "report", "Open the last run's report", "", ...
    @(~,~) obj.onOpenReport(), Separator=true);
obj.ToolbarReportTool.Enable = "off";
obj.ToolbarFolderTool = addTool(tb, iconDir, "figurefolder", "Open the last run's figure folder", "", ...
    @(~,~) obj.onOpenExportFolder());
obj.ToolbarFolderTool.Enable = "off";

% --- the other app ---
addTool(tb, iconDir, "pipelineapp", "Open pipeline app", "", @(~,~) obj.onOpenPipelineApp(), Separator=true);

% --- Help ---
addTool(tb, iconDir, "help", "Help for this tab", "", @(~,~) obj.onHelp("tab"), Separator=true);
end


function preview(obj)
%preview  The Figures tab, then the selected figure drawn as its Preview button draws it.
%   The tab shows first, with the observations listed, so a slow preview is
%   seen computing. Its hint follows; the auto-preview onTabChanged starts
%   finds the figure drawn.
if obj.Tabs.SelectedTab == obj.TabFigures
    obj.refreshFigurePreview(Force=true);
    return
end
obj.Tabs.SelectedTab = obj.TabFigures;
revealTab(obj, obj.TabFigures);   % its contents shown before the preview draws (onTabChanged comes after it)
obj.refreshFigureObservations();
obj.refreshFigurePreview(Force=true);
obj.onTabChanged();
end


function onExportTab(obj, fcn)
%onExportTab  The Export tab, where the tables show what FCN finds, then FCN.
obj.selectTab(obj.TabExport);
fcn();
end


function t = addTool(tb, iconDir, tag, tip, key, fcn, opts)
%addTool  One push tool: icon <TAG>.svg, tooltip TIP with the shortcut KEY ("" for none).
arguments
    tb
    iconDir (1,1) string
    tag (1,1) string
    tip (1,1) string
    key (1,1) string
    fcn (1,1) function_handle
    opts.Separator (1,1) logical = false
end
if key ~= ""
    if ismac; modifier = "Cmd+"; else; modifier = "Ctrl+"; end
    tip = tip + " (" + modifier + key + ")";
end
t = uipushtool(tb, "Tag", tag, "Icon", fullfile(iconDir, tag + ".svg"), "Tooltip", tip, ...
    "Separator", matlab.lang.OnOffSwitchState(opts.Separator), "ClickedCallback", fcn);
end
