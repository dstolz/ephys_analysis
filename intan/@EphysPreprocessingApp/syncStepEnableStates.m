function syncStepEnableStates(obj)
%syncStepEnableStates  Tab titles and colours ("[off]" and greyed for disabled
%   steps, green-tinted when enabled), the Run-tab checklist and the selection
%   summary follow the working config.
cfg = obj.Config;
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, false));
titles = struct('TabArtifacts', "Artifacts", 'TabSorting', "Sorting", 'TabSignals', "Signals", ...
    'TabSpikes', "Spikes", 'TabExport', "Export");
flags  = struct('TabArtifacts', cfg.Artifacts.Enabled, 'TabSorting', cfg.Sorting.Enabled, ...
    'TabSignals', cfg.Signals.Enabled, 'TabSpikes', cfg.Spikes.Enabled, 'TabExport', cfg.Export.Enabled);
for f = string(fieldnames(titles)).'
    tab = obj.(f);
    if isempty(tab) || ~isvalid(tab); continue; end
    if flags.(f)
        tab.Title = char(titles.(f));
        tab.BackgroundColor = [0.86 0.94 0.86];
        tab.ForegroundColor = [0 0.35 0];
    else
        tab.Title = char(titles.(f) + " [off]");
        tab.BackgroundColor = [0.88 0.88 0.88];
        tab.ForegroundColor = [0.5 0.5 0.5];
    end
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
