function buildToolbar(obj)
%buildToolbar  Toolbar under the menu bar: the menus' most used commands as icons.
%   Each tool calls the same method as its menu item, and its tooltip names
%   the item's keyboard shortcut when it has one (Ctrl, or Cmd on a Mac).
%   Left to right, in groups:
%     File      New config, Open config, Save config
%     Run       Validate config, Plan, Run pipeline, Dry run, Cancel
%     Dataset   View manifest (the active dataset's)
%     Tools     Open analysis app, Channel mapper (both in the File menu)
%     Help      Help for this tab
%   Run pipeline, Dry run and Cancel follow the Run tab's buttons: the first
%   two are off while a Run goes, Cancel is on only then (runPipeline,
%   onCancelRun). Each tool's Tag names its icon,
%   pipeline/icons/toolbar/<Tag>.svg.

iconDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "icons", "toolbar");
tb = uitoolbar(obj.Fig);
obj.Toolbar = tb;

% --- File: the config ---
addTool(tb, iconDir, "new",  "New config",  "N", @(~,~) obj.onNewConfig());
addTool(tb, iconDir, "open", "Open config", "O", @(~,~) obj.onOpenConfig());
addTool(tb, iconDir, "save", "Save config", "S", @(~,~) obj.onSaveConfig());

% --- Run: as the Run menu ---
addTool(tb, iconDir, "validate", "Validate config", "", @(~,~) obj.onValidate(), Separator=true);
addTool(tb, iconDir, "plan", "Plan (writes nothing)", "", @(~,~) obj.onPlan());
obj.ToolbarRunTool = addTool(tb, iconDir, "run", "Run pipeline", "R", @(~,~) obj.runPipeline());
obj.ToolbarDryRunTool = addTool(tb, iconDir, "dryrun", "Dry run", "", @(~,~) obj.runPipeline(DryRun=true));
obj.ToolbarCancelTool = addTool(tb, iconDir, "cancel", "Cancel run", "", @(~,~) obj.onCancelRun());
obj.ToolbarCancelTool.Enable = "off";

% --- Dataset and the other apps ---
addTool(tb, iconDir, "manifest", "View the active dataset's manifest", "", @(~,~) obj.onViewManifest(), Separator=true);
addTool(tb, iconDir, "analysisapp", "Open analysis app", "", @(~,~) obj.onOpenAnalysisApp(), Separator=true);
addTool(tb, iconDir, "channelmapper", "Channel mapper", "", @(~,~) obj.onOpenChannelMapper());

% --- Help ---
addTool(tb, iconDir, "help", "Help for this tab", "", @(~,~) obj.onHelp("tab"), Separator=true);
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
