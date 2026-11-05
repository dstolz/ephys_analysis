function T = arrangeParts(obj, id, rect0)
%arrangeParts  What a drag in Arrange moves live: the drawn parts of panel ID (or the floating legend) with their pixel places, for arrangePartsAt.
%   T = arrangeParts(OBJ, ID, RECT0), ID a panel's id or ":legend", RECT0
%   its rect when the drag starts (0-1 of the page), is a struct:
%     h       the parts: the panel's axes (its further axes too: a
%             coherence panel's phase strip), its note band and, for the
%             legend panel, the figure's legend; for ":legend" the floating
%             legend
%     pos     their Positions (px in the canvas) when the drag starts, a row each
%     cb      the color bars of its axes, and cbLoc their Locations: they
%             are placed from their axes again (never given a Position,
%             which would leave them where they are put)
%     box0    RECT0 in px of the canvas (the page as the overlay covers it)
%   read from what figureLayout keeps on the canvas (appdata FigureLayout:
%   each panel's axes and band, the legend). Each part's Units are pixels.
%   [] when the preview holds no drawing of that panel (a panel added
%   since, a drawing laid out its own way).
%
%   See also arrangePartsAt, EphysFigGenApp.onArrangeMoving.
T = [];
O = obj.FigureArrangeOverlay;
P = obj.FigurePreviewPanel;
if ~isstruct(O) || isempty(O.axes) || ~isvalid(O.axes) || isempty(P) || ~isvalid(P) || ~isappdata(P, 'FigureLayout'); return; end
S = getappdata(P, 'FigureLayout');
if ~isstruct(S) || ~isfield(S, 'panels') || isfield(S, 'layoutFcn'); return; end
h = gobjects(1, 0);
G = [];
if isfield(S, 'legend') && isstruct(S.legend) && ~isempty(S.legend) && isgraphics(S.legend.handle); G = S.legend; end
if id == ":legend"
    if isempty(G) || string(G.mode) ~= "float"; return; end
    h = G.handle;
else
    q = 0;
    for i = 1:numel(S.panels)
        if string(S.panels(i).id) == id; q = i; break; end
    end
    if q == 0 || isempty(S.panels(q).axes) || ~all(isgraphics(S.panels(q).axes)); return; end
    A = reshape(S.panels(q).axes, 1, []);
    h = A;
    if ~isempty(S.panels(q).band) && isgraphics(S.panels(q).band); h = [h S.panels(q).band]; end
    if ~isempty(G) && string(G.mode) == "panel" && isfield(G, 'panel') && G.panel == q; h = [h G.handle]; end
end
if isempty(h); return; end
pos = zeros(numel(h), 4);
for i = 1:numel(h)
    if ~strcmp(h(i).Units, 'pixels'); h(i).Units = 'pixels'; end
    pos(i, :) = h(i).Position;
end
cb = gobjects(1, 0);
cbLoc = strings(1, 0);
for a = reshape(h(arrayfun(@(x) isa(x, 'matlab.graphics.axis.Axes'), h)), 1, [])
    c = a.Colorbar;
    if ~isempty(c) && isvalid(c) && strcmp(c.Visible, 'on') && string(c.Location) ~= "manual"
        cb(end+1) = c; %#ok<AGROW>
        cbLoc(end+1) = string(c.Location); %#ok<AGROW>
    end
end
pg = O.axes.Position;
T = struct('h', h, 'pos', pos, 'cb', cb, 'cbLoc', cbLoc, 'box0', [pg(1:2) + rect0(1:2) .* pg(3:4), rect0(3:4) .* pg(3:4)]);
end
