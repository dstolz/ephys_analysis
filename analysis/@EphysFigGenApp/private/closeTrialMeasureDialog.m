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
%   The window is the one the app keeps (OBJ.TrialMeasureDialog), so the
%   common case, no window open, costs nothing: applyFigureEditor calls
%   this on every switch of figure, panel or layer, and a search of every
%   open figure (the kept previews, a context menu per drawn object) would
%   cost more than the switch. With FORCE a window by its Tag is closed
%   too, in case one is open that the app does not keep.
%
%   See also trialMeasureDialog, closeSequenceDialog.
if nargin < 2; force = false; end
d = obj.TrialMeasureDialog;
if ~isempty(d) && isvalid(d) && (force || ~showsIt(obj, d.UserData))
    delete(d);
end
if force
    delete(findall(groot, 'Type', 'figure', 'Tag', 'trialMeasureDialog'));
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
