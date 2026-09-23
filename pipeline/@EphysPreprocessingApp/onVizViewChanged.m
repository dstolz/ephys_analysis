function onVizViewChanged(obj)
%onVizViewChanged  The viewer moved: show its view in the fields and the status line.
%   Called by obj.Viewer after every draw and every pan inside what is
%   drawn (EphysTraceViewer.ViewChangedFcn), so it only sets values.
%   The status line names the dataset, signal and time shown, or says
%   the plot shows another dataset than the active one (syncVizDataset).
%
%   See also buildVisualizeTab, syncVizDataset.

v = obj.Viewer;
if isempty(v) || ~isvalid(v) || isempty(obj.VizStatusLabel) || ~isvalid(obj.VizStatusLabel); return; end
shown = obj.currentVizDataset();
active = obj.currentDataset();
if isempty(shown)
    obj.VizStatusLabel.Text = "Open this tab with a dataset active, or press Reload data.";
    obj.VizStatusLabel.FontColor = [0.4 0.4 0.4];
    return
end
obj.VizStartField.Value = v.TStart;
obj.VizDurField.Value = v.TWidth;
obj.VizSpacingField.Value = v.Spacing;

if isempty(active) || shown ~= active
    txt = "The plot shows " + shown.Name + ".";
    if ~isempty(active)
        txt = txt + " " + active.Name + " loads when you open this tab (or press Reload data).";
    end
    obj.VizStatusLabel.Text = txt;
    obj.VizStatusLabel.FontColor = [0.75 0.4 0];
    return
end
what = "spikes";
if ~isempty(v.Source); what = v.Source.Name; end
txt = sprintf("%s | %s | %.4g - %.4g s of %.4g s", shown.Name, what, v.TStart, ...
    v.TStart + v.TWidth, v.TotalDuration);
R = v.LastRender;
if R.error ~= ""
    txt = txt + " | " + R.error;
elseif ~isempty(R.notes)
    txt = txt + " | " + strjoin(R.notes, "; ");
end
obj.VizStatusLabel.Text = txt;
obj.VizStatusLabel.FontColor = [0.4 0.4 0.4];
end
