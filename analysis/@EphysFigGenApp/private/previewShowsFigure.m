function [tf, why] = previewShowsFigure(obj)
%previewShowsFigure  The preview shows the selected figure laid out, so its panels can be arranged over it.
%   [TF, WHY] = previewShowsFigure(OBJ) is true when the preview container
%   (FigurePreviewPanel) holds a drawing of the selected figure: its badge
%   Drawn or Out of date (an edit since leaves the page it was laid out
%   on), the editing context renderFigure kept names that figure (as
%   markFigurePanel reads it; or the id it had before a rename:
%   followedFigureId), the layout left its places (appdata
%   FigureLayoutResult: figureLayout) and it is no probe figure (whose
%   panels are drawn in every tile). WHY says what is missing when TF is
%   false, for the status bar: "Arrange: preview psth units first
%   (Ctrl+P)." or "Arrange is off for a probe figure: its panels are drawn
%   in every tile."; "" when TF is true.
%   The Arrange overlay is built on it (syncArrangeOverlay), Set corners
%   and New panel's "Draw it on the preview" wait for it.
%
%   See also EphysFigGenApp.syncArrangeOverlay, EphysFigGenApp.markFigurePanel.
tf = false;
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    why = "Arrange: add or select a figure first.";
    return
end
fig = obj.Config.Figures(k);
why = "Arrange: preview " + fig.id + " first (Ctrl+P).";
if fig.probe.enabled
    why = "Arrange is off for a probe figure: its panels are drawn in every tile.";
    return
end
P = obj.FigurePreviewPanel;
if isempty(P) || ~isvalid(P) || ~ismember(obj.FigurePreviewState, ["drawn" "stale"]) || obj.FigureViewId ~= fig.id; return; end
F = obj.FigurePreviewResult;
if isstruct(F) && isfield(F, 'kind') && string(F.kind) == "probeFigure"
    why = "Arrange is off for a probe figure: its panels are drawn in every tile.";
    return
end
if ~isappdata(P, PlotAesthetics.ContextKey) || ~isappdata(P, 'FigureLayoutResult'); return; end
ctx = getappdata(P, PlotAesthetics.ContextKey);
if ~isstruct(ctx) || ~isfield(ctx, 'id') || followedFigureId(obj, ctx.id) ~= fig.id; return; end   % another figure's drawing (one drawn before its automatic id followed an edit is its own)
R = getappdata(P, 'FigureLayoutResult');
if ~isstruct(R) || ~isfield(R, 'page') || numel(R.page) ~= 4; return; end
tf = true;
why = "";
end
