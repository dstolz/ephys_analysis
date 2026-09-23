function syncVizDataset(obj)
%syncVizDataset  Flag a Visualize plot of a dataset other than the active one.
%   The status line says which dataset the plot shows, and artifact marking
%   is off until Plot shows the active dataset: a marked period would go to
%   the plotted dataset, not the one the tab names. The two are compared as
%   datasets (handles, not places in the project), so after a rescan a plot
%   is out of date unless the new project still holds its recording (onScan
%   then points the plot at it).
if isempty(obj.VizArtButton) || ~isvalid(obj.VizArtButton); return; end
shown = obj.currentVizDataset();
active = obj.currentDataset();
stale = ~isempty(obj.Viewer) && isvalid(obj.Viewer) ...
    && (isempty(shown) || isempty(active) || shown ~= active);
if stale
    if obj.VizArtButton.Value
        obj.VizArtButton.Value = false;
        obj.onVizArtToggle(false);
    end
    txt = "The plot is out of date.";
    if ~isempty(shown); txt = "The plot shows " + shown.Name + "."; end
    if ~isempty(active); txt = txt + " Press Plot to show " + active.Name + "."; end
    obj.VizStatusLabel.Text = txt;
    obj.VizStatusLabel.FontColor = [0.75 0.4 0];
else
    % The line onPlotVisualization wrote for the plot on screen.
    txt = obj.VizStatusLabel.UserData;
    if isempty(txt); txt = ""; end
    obj.VizStatusLabel.Text = txt;
    obj.VizStatusLabel.FontColor = [0.4 0.4 0.4];
end
obj.VizArtButton.Enable = matlab.lang.OnOffSwitchState(~stale);
obj.VizArtClearButton.Enable = matlab.lang.OnOffSwitchState(~stale);
end
