function syncVizDataset(obj)
%syncVizDataset  Flag a Visualize plot of a dataset other than the active one.
%   The status line says which dataset the plot shows (onVizViewChanged),
%   and artifact marking is off until the plot shows the active dataset: a
%   marked period would go to the plotted dataset, not the one the tab
%   names. The tab loads the active dataset whenever it opens or the
%   active dataset changes while it is open, so this lasts only while the
%   tab is hidden. The two are compared as datasets (handles, not places
%   in the project), so after a rescan a plot is out of date unless the
%   new project still holds its recording (onScan then points the plot at
%   it).
if isempty(obj.VizArtButton) || ~isvalid(obj.VizArtButton); return; end
shown = obj.currentVizDataset();
active = obj.currentDataset();
current = ~isempty(shown) && ~isempty(active) && shown == active;
if ~current && obj.VizArtButton.Value
    obj.VizArtButton.Value = false;
    obj.onVizArtToggle(false);
end
obj.VizArtButton.Enable = matlab.lang.OnOffSwitchState(current);
obj.VizArtClearButton.Enable = matlab.lang.OnOffSwitchState(current);
obj.onVizViewChanged();
end
