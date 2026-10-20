function drawAsChoices(dd, type, v)
%drawAsChoices  What the Layers' Draw as drop-down DD offers an events layer on a panel of TYPE, showing V.
%   drawAsChoices(DD, TYPE, V) lists marks, a train and a span (a line
%   from onset to offset), the train only on a raster, PSTH or heat map,
%   and shows V (default: DD's value). A value the list lacks (a train on
%   another type) stays listed, so the box shows what the config holds
%   (Validate reports it).
%
%   See also EphysAnalysisApp.syncFigureEditor, EphysAnalysisApp.applyFigureEditor.
if nargin < 3; v = string(dd.Value); end
v = string(v);
labels = ["marks (on the rows / latency lines)" "a spike train of its own" "a line from onset to offset"];
data = ["marks" "train" "span"];
keep = ismember(type, ["raster" "psth" "heatmap"]) | data ~= "train" | data == v;
if ~isequal(string(dd.ItemsData), data(keep))
    set(dd, "Items", labels(keep), "ItemsData", data(keep));
end
if ismember(v, data(keep)); dd.Value = char(v); end
end
