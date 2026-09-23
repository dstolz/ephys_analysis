function onRunDiagramToggled(obj)
%onRunDiagramToggled  Show or hide the Run tab's diagram of the run.
%   Shown (Show the run diagram ticked), it takes the right quarter of
%   the tab's right side (3:1), beside the progress bars, issues, results and log;
%   hidden, those have the whole width again. Before any run it previews
%   the steps the working config would run; during and after a run it shows
%   that run. The switch is a preference (ShowRunDiagram).

show = logical(obj.RunDiagramCheckBox.Value);
if show
    obj.RunSplitGrid.ColumnWidth = {'3x', '1x'};
    obj.RunSplitGrid.ColumnSpacing = 10;
else
    obj.RunSplitGrid.ColumnWidth = {'1x', 0};
    obj.RunSplitGrid.ColumnSpacing = 0;
end
obj.RunDiagramPanel.Visible = show;
if ~show; return; end
if obj.RunDiagram.phase == "idle"
    obj.resetRunDiagram();   % what the checklist would run now
else
    obj.refreshRunDiagram();
end
end
