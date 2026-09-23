function syncToolsPanel(obj)
%syncToolsPanel  Name what the Tools panel opens and enable its buttons.
%   The label names the datasets (toolTargets): the active one, or how many
%   are ticked (every dataset when none is), and how many of several have
%   sorted output when not all do. phy is on when at least one has (a
%   params.py), the other buttons whenever there is a dataset. Called when
%   the active dataset, the ticks, the scope or the table's rows change.
%
%   See also EphysPreprocessingApp.onOpenTool.
if isempty(obj.ToolsTargetLabel) || ~isvalid(obj.ToolsTargetLabel); return; end
idx = obj.toolTargets();
n = numel(idx);
nPhy = 0;
for i = idx
    nPhy = nPhy + obj.Project.Datasets(i).hasPhyOutput();
end

if isempty(obj.Project) || obj.Project.NumDatasets == 0
    txt = "Scan a project first.";
elseif n == 0
    txt = "No active dataset.";
elseif obj.ToolsScopeDropDown.Value == "active"
    txt = obj.Project.Datasets(idx).Name;
elseif isempty(obj.tickedDatasetIndices()) && n == 1
    txt = obj.Project.Datasets(idx).Name + " (none ticked: every dataset)";
elseif isempty(obj.tickedDatasetIndices())
    txt = sprintf("All %d datasets (none ticked)", n);
elseif n == 1
    txt = "1 ticked: " + obj.Project.Datasets(idx).Name;
else
    txt = sprintf("%d ticked datasets", n);
end
if n > 1 && nPhy < n
    txt = txt + sprintf("; %d sorted", nPhy);
end
obj.ToolsTargetLabel.Text = txt;
obj.ToolsTargetLabel.Tooltip = txt;   % a long name is clipped in the label

on = matlab.lang.OnOffSwitchState(n > 0);
obj.ToolsManifestButton.Enable = on;
obj.ToolsAnalysisButton.Enable = on;
obj.ToolsFolderButton.Enable = on;
obj.ToolsPhyButton.Enable = matlab.lang.OnOffSwitchState(nPhy > 0);
end
