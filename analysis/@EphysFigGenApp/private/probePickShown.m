function tf = probePickShown(obj, T)
%probePickShown  The figure editor still shows the rows a Probe... window (pickChannels) was opened on: its figure, and for a layer its panel and layer.
%   TF = probePickShown(OBJ, T) for T = OBJ.ProbePickTarget: the figure by
%   id, followed through renames (followedFigureId); with T.Where "layer"
%   also the panel (by id) and the layer (by place) selected.
%
%   See also EphysFigGenApp.pickChannels, closeProbePickDialog.
k = obj.SelectedFigure;
F = obj.Config.Figures;
tf = k >= 1 && k <= numel(F) && F(k).id == followedFigureId(obj, T.FigureId);
if ~tf || T.Where ~= "layer"; return; end
j = obj.SelectedPanel;
tf = j >= 1 && j <= numel(F(k).panels) && F(k).panels(j).id == T.PanelId && obj.SelectedLayer == T.Layer ...
    && T.Layer <= numel(F(k).panels(j).layers);
end
