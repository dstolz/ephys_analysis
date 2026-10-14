function figLayerNotes(ax, P, look, drew, emptyText)
%figLayerNotes  Say in a figure panel why a layer, or the whole panel, is not drawn.
%   figLayerNotes(AX, P, LOOK, DREW, EMPTYTEXT) for the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) drawn into AX:
%     P.skip set          its reason, centered (every layer carries it)
%     nothing drawn       (DREW false) the skipped layers' reasons centered,
%                         or EMPTYTEXT (default: the panel has no enabled
%                         layer); the axes keep their box, without y ticks
%                         (and without x ticks unless LOOK.isTime)
%     some layers drawn   each skipped layer's "<name>: <reason>" in small
%                         gray text at the bottom left
%   Disabled layers are not mentioned. The text is tagged "layerNote" and
%   placed in normalized units, so the axes' limits do not move it.
%
%   See also renderFigure, figurePanelLayers.
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
fs = max(6, style.FontSize - 2);
gray = [0.4 0.4 0.4];
if P.skip ~= "" || ~drew
    txt = P.skip;
    if txt == ""
        txt = string(emptyText);
        if ~isempty(notes); txt = strjoin(notes, newline); end
    end
    flat = style;
    flat.XLim = []; flat.YLim = [];
    styleAxes(ax, flat);
    ax.YTick = [];
    if ~(isfield(look, 'isTime') && look.isTime); ax.XTick = []; end
    tagPart(text(ax, 0.5, 0.5, txt, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontSize', fs, 'Color', gray, 'Interpreter', 'none'), "layerNote");
    return
end
if isempty(notes); return; end
tagPart(text(ax, 0.02, 0.03, strjoin(notes, newline), 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'bottom', 'FontSize', fs, 'Color', gray, 'Interpreter', 'none'), "layerNote");
end
