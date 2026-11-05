function closeTrialMeasureDialog(obj, force)
%closeTrialMeasureDialog  Close the Trial measure window when the editor no longer shows the layer it edits.
%   closeTrialMeasureDialog(OBJ) closes the window (trialMeasureDialog, Tag
%   trialMeasureDialog) unless the figure editor shows its figure (by id,
%   followed through renames: followedFigureId), its panel and its layer,
%   still a trials layer: another figure, panel or layer picked, a panel
%   removed or of another type, a config opened, so an OK cannot land on
%   them (as closeSequenceDialog does for the Event sequence window).
%   closeTrialMeasureDialog(OBJ, true) closes it whatever is shown.
%
%   See also trialMeasureDialog, closeSequenceDialog.
if nargin < 2; force = false; end
for d = reshape(findall(groot, 'Type', 'figure', 'Tag', 'trialMeasureDialog'), 1, [])
    if force || ~showsIt(obj, d.UserData); delete(d); end
end
end


function tf = showsIt(obj, D)
%showsIt  Whether the editor shows the figure, panel and layer the window's controls D were opened on.
tf = false;
if ~isstruct(D) || ~all(isfield(D, {'FigureId', 'PanelId', 'LayerIndex', 'Which'})); return; end
k = obj.SelectedFigure;
F = obj.Config.Figures;
if k < 1 || k > numel(F) || F(k).id ~= followedFigureId(obj, D.FigureId); return; end
j = obj.SelectedPanel;
if j < 1 || j > numel(F(k).panels) || F(k).panels(j).id ~= D.PanelId; return; end
p = F(k).panels(j);
i = obj.SelectedLayer;
tf = i == D.LayerIndex && i >= 1 && i <= numel(p.layers) && p.layers(i).source == "trials" ...
    && (D.Which == "measure" || p.type == "trialScatter");
end
