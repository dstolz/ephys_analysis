function syncStepEnableStates(obj)
%syncStepEnableStates  The tab strip colours (syncTabStrip), the Run-tab
%   checklist, the selection summary, (while shown) the Flow chart and,
%   until a run starts, the run diagram's preview follow the working config.
cfg = obj.Config;
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, false));
obj.syncTabStrip();
if ~isempty(obj.TabFlow) && isvalid(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabFlow
    obj.refreshFlowChart();
end
setIf(obj.RunBehaviorCheckBox,  cfg.Behavior.Enabled);
setIf(obj.RunArtifactsCheckBox, cfg.Artifacts.Enabled);
setIf(obj.RunSortingCheckBox,   cfg.Sorting.Enabled);
setIf(obj.RunSignalsCheckBox,   cfg.Signals.Enabled);
setIf(obj.RunSpikesCheckBox,    cfg.Spikes.Enabled);
setIf(obj.RunExportCheckBox,    cfg.Export.Enabled);
setIf(obj.BehEnableCheckBox,    cfg.Behavior.Enabled);
setIf(obj.ArtEnableCheckBox,    cfg.Artifacts.Enabled);
setIf(obj.SortEnableCheckBox,   cfg.Sorting.Enabled);
setIf(obj.SigEnableCheckBox,    cfg.Signals.Enabled);
setIf(obj.SpkEnableCheckBox,    cfg.Spikes.Enabled);
setIf(obj.ExpEnableCheckBox,    cfg.Export.Enabled);
if ~isempty(obj.RunKSAtOnceSpinner) && isvalid(obj.RunKSAtOnceSpinner)
    obj.RunKSAtOnceSpinner.Enable = matlab.lang.OnOffSwitchState(cfg.Sorting.Execution == "background");
end
if ~isempty(obj.RunKSQueueCheckBox) && isvalid(obj.RunKSQueueCheckBox)
    obj.RunKSQueueCheckBox.Enable = matlab.lang.OnOffSwitchState(cfg.Sorting.Execution == "background");
end
% Behavior.Search off: the step uses the associated sessions only, so the
% search settings are idle and the step button no longer finds sessions.
search = cfg.Behavior.Search;
ctrls = {obj.BehSearchDirsField, obj.BehBrowseButton, obj.BehMatchDropDown, obj.BehMaxOffsetField, obj.BehOverwriteCheckBox};
for k = 1:numel(ctrls)
    h = ctrls{k};
    if ~isempty(h) && isvalid(h); h.Enable = matlab.lang.OnOffSwitchState(search); end
end
if ~isempty(obj.BehFindButton) && isvalid(obj.BehFindButton)
    if search
        obj.BehFindButton.Text = "Find sessions for selected";
        obj.BehFindButton.Tooltip = "Run the behavior step on the selected datasets: search the folders for a session for each one that has none, then pair and write as set.";
    else
        obj.BehFindButton.Text = "Write behavior for selected";
        obj.BehFindButton.Tooltip = "Run the behavior step on the selected datasets without a search: pair and write the sessions already associated, as set.";
    end
end
if ~isempty(obj.RunSelectionLabel) && isvalid(obj.RunSelectionLabel)
    if isempty(obj.Project) || obj.Project.NumDatasets == 0
        obj.RunSelectionLabel.Text = "Selection: scan a project root first.";
    elseif cfg.Project.Selection == "list"
        obj.RunSelectionLabel.Text = sprintf("Selection: %d of %d dataset(s) ticked.", ...
            numel(cfg.Project.Datasets), obj.Project.NumDatasets);
    else
        obj.RunSelectionLabel.Text = sprintf("Selection: all %d dataset(s).", obj.Project.NumDatasets);
    end
end
if ~isempty(obj.RunDiagramCheckBox) && isvalid(obj.RunDiagramCheckBox) && obj.RunDiagramCheckBox.Value ...
        && obj.RunDiagram.phase == "idle"
    obj.resetRunDiagram();
end
end


function setIf(ctrl, v)
if ~isempty(ctrl) && isvalid(ctrl)
    ctrl.Value = logical(v);
end
end


function setApplying(obj, tf)
obj.Applying = tf;
end
