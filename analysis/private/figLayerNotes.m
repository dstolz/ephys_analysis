function figLayerNotes(ax, P, look, drew, emptyText)
%figLayerNotes  Show in a figure panel that a layer, or the whole panel, is not drawn: a sign whose message says why.
%   figLayerNotes(AX, P, LOOK, DREW, EMPTYTEXT) for the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) drawn into AX. The
%   reasons are never written in the panel, where a long one would run
%   over its neighbors: a "cannot draw" sign (brokenGraphic: a gray square
%   struck through in red) holds them, shown on hover and on a click.
%     P.skip set          a sign in the middle, its reason P.skip (every
%                         layer carries it)
%     nothing drawn       (DREW false) a sign in the middle, its reasons the
%                         skipped layers' ("<name>: <reason>", a line each),
%                         or EMPTYTEXT (default: the panel has no enabled
%                         layer); the axes keep their box, without y ticks
%                         (and without x ticks unless LOOK.isTime)
%     some layers drawn   a small sign at the bottom left, its reasons each
%                         skipped layer's "<name>: <reason>"
%   Disabled layers are not mentioned. The sign is tagged "layerNote" and
%   keeps its reasons (appdata "LayerNote", a line each).
%
%   See also renderFigure, figurePanelLayers, brokenGraphic.
if nargin < 5 || string(emptyText) == ""; emptyText = "Nothing to draw: the panel has no enabled layer"; end
style = look.style;
Ls = look.panel.layers;
notes = strings(0, 1);
for j = 1:numel(P.layers)
    s = P.layers(j).skip;
    if s == "" || s == "disabled"; continue; end
    name = P.layers(j).name;
    if name == "" && j <= numel(Ls); name = Ls(j).name; end
    if name == ""; name = P.layers(j).source; end
    notes(end+1, 1) = name + ": " + s; %#ok<AGROW>
end
notes = unique(notes, 'stable');
id = "";
if isfield(look, 'panelId'); id = " " + string(look.panelId); end
if P.skip ~= "" || ~drew
    txt = string(P.skip);
    if txt == ""
        txt = string(emptyText);
        if ~isempty(notes); txt = notes; end
    end
    flat = style;
    flat.XLim = []; flat.YLim = [];
    styleAxes(ax, flat);
    ax.YTick = [];
    if ~(isfield(look, 'isTime') && look.isTime); ax.XTick = []; end
    brokenGraphic(ax, txt, Where="center", FontSize=style.FontSize, Title="Cannot draw panel" + id);
    return
end
if isempty(notes); return; end
brokenGraphic(ax, notes, Where="corner", FontSize=style.FontSize, Title="Not drawn in panel" + id);
end
