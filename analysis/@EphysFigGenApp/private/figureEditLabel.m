function label = figureEditLabel(obj, src)
%figureEditLabel  The name of an edit made with the figure editor's control SRC, for the Edit menu: its row's label ("Bin (ms)").
%   Read from the editor as built (FigureSearchIndex, as the search reads
%   it): the entry whose control SRC is, else the form row holding SRC
%   (an edit field of a From / To pair), else SRC's own text (a check
%   box), else the title of the section holding it. A SRC that is a string
%   is the name itself (a dialog's OK, a button, a key: the caller names
%   the step). "Edit" for any other SRC outside the editor, or none.
%   An edit of the Probe layout section (the figure's probe block) is
%   "Probe layout" for its On the probe box, "Probe layout: <row>" for
%   one of its rows ("Probe layout: Max tiles").
label = "Edit";
if isstring(src) && isscalar(src) && strlength(strtrim(src)) > 0; label = strtrim(src); return; end
if isempty(src) || ~isscalar(src) || ~isobject(src) || ~isprop(src, 'Parent') || ~isvalid(src); return; end
chain = gobjects(1, 0);   % SRC and the containers up to the editor's grid
h = src;
while ~isequal(h, obj.FigureEditorGrid)
    if isempty(h) || ~isprop(h, 'Parent') || isa(h, 'matlab.ui.Figure'); return; end   % not in the editor
    chain(end+1) = h; %#ok<AGROW>
    h = h.Parent;
end
in = @(c) any(arrayfun(@(a) isequal(a, c), chain));
X = obj.FigureSearchIndex;
for e = reshape(X, 1, [])
    if e.Row ~= 0 && e.Row ~= -2 && isequal(e.Target, src); label = named(e); return; end
end
S = obj.FigureSections;
for e = reshape(X([X.Row] >= 1), 1, [])
    s = S([S.Name] == e.Section);
    if isscalar(s) && e.Row <= numel(s.Items) && any(arrayfun(in, s.Items{e.Row}))
        label = named(e);
        return
    end
end
if isprop(src, 'Text') && strlength(strtrim(strjoin(string(src.Text), " "))) > 0
    label = strtrim(strjoin(string(src.Text), " "));
    return
end
for s = reshape(S, 1, [])
    if s.Title ~= "" && in(s.Body); label = s.Title; return; end
end
end


function label = named(e)
%named  A search entry's name as an edit's: its label, but "Probe layout" (and the row, its words before a bracket) in the Probe layout section.
label = e.Label;
if e.Section ~= "probe"; return; end
if any(e.Keys == "prbEnabled")
    label = "Probe layout";
elseif contains(label, " (")
    label = "Probe layout: " + extractBefore(label, " (");   % "Shared y (each panel ...)": Shared y
else
    label = "Probe layout: " + label;
end
end
