function [spec, F, titleVars] = figureLabelFill(F, spec)
%figureLabelFill  A figure's texts with their label variables filled in for the result F: what renderFigure draws.
%   [SPEC, F, TITLEVARS] = figureLabelFill(F, SPEC) fills each {Name} of
%   figureLabelVariables in SPEC.title (with the figure's own values),
%   every panel's title, xLabel, yLabel and note text, and the names of
%   F's layers (F.panels(k).layers(j).name; the legend), each with its own
%   panel's values (figureLabelVariables(SPEC, F, Panel=k)). A note drawn
%   with the TeX interpreter gets its values escaped (an "_" in a unit's
%   label stays an underscore). TITLEVARS lists the variables SPEC.title
%   names, as typed (a string row; renderFigure and figureAutoTitle: a
%   title that names the unit or the trial group is not told them again).
%   SPEC keeps its fields: a figure with no brace in any of these texts is
%   returned as it is, at no cost. A
%   probe figure (F.tiles) fills its texts with the page's values; its
%   tiles' layer names are filled by the caller, a tile at a time.
%
%   See also figureLabelVariables, renderFigure, renderProbeFigure.

titleVars = labelNames(spec.title);
if ~anyBrace(F, spec); return; end
[~, V] = figureLabelVariables(spec, F);
spec.title = figureFileName(spec.title, V, Kind="label");
hasPanels = isstruct(F) && isfield(F, 'panels');
for k = 1:numel(spec.panels)
    p = spec.panels(k);
    [~, V] = figureLabelVariables(spec, F, Panel=k);
    for f = ["title" "xLabel" "yLabel"]
        p.(f) = figureFileName(string(p.(f)), V, Kind="label");
    end
    if isfield(p, 'note') && isstruct(p.note) && contains(string(p.note.text), "{")
        Vn = V;
        if isfield(p.note, 'interpreter') && string(p.note.interpreter) == "tex"; Vn = texEscaped(V); end
        p.note.text = figureFileName(string(p.note.text), Vn, Kind="label");
    end
    spec.panels(k) = p;
    if hasPanels && k <= numel(F.panels) && isfield(F.panels(k), 'layers')
        for j = 1:numel(F.panels(k).layers)
            F.panels(k).layers(j).name = figureFileName(string(F.panels(k).layers(j).name), V, Kind="label");
        end
    end
end
end


function tf = anyBrace(F, spec)
%anyBrace  Any text this fills holds a brace.
tf = contains(spec.title, "{");
for k = 1:numel(spec.panels)
    if tf; return; end
    p = spec.panels(k);
    tf = any(contains([string(p.title) string(p.xLabel) string(p.yLabel)], "{"));
    if ~tf && isfield(p, 'note') && isstruct(p.note); tf = contains(string(p.note.text), "{"); end
    if ~tf && isstruct(F) && isfield(F, 'panels') && k <= numel(F.panels) && isfield(F.panels(k), 'layers') ...
            && ~isempty(F.panels(k).layers)
        tf = any(contains(string({F.panels(k).layers.name}), "{"));
    end
end
end


function n = labelNames(txt)
%labelNames  The label variables TXT names (a string row).
n = string.empty(1, 0);
if ~contains(txt, "{"); return; end
found = regexp(txt, '\{(\w+)\}', 'tokens');
n = unique(string(cellfun(@(c) c{1}, found, 'UniformOutput', false)), 'stable');
n = reshape(n(ismember(n, figureLabelVariables().Name)), 1, []);
end


function V = texEscaped(V)
%texEscaped  The values as TeX prints them literally: \ _ ^ { } escaped.
for f = string(fieldnames(V)).'
    V.(f) = regexprep(V.(f), '([\\_\^\{\}])', '\\$1');
end
end
