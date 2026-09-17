function syncStepEnableStates(obj)
%syncStepEnableStates  The tab strip colours (syncTabStrip), the Run-tab
%   checklist, the selection summary and (while shown) the Flow chart
%   follow the working config.
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
end


function setIf(ctrl, v)
if ~isempty(ctrl) && isvalid(ctrl)
    ctrl.Value = logical(v);
end
end


function setApplying(obj, tf)
obj.Applying = tf;
end
