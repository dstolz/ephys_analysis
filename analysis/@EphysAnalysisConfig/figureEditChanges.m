function changes = figureEditChanges(before, after, panel)
%figureEditChanges  The settings an edit of one figure changed that other figures (or panels) could take too.
%   CHANGES = EphysAnalysisConfig.figureEditChanges(BEFORE, AFTER, PANEL)
%   compares a figure (a Figures entry) before and after an edit made with
%   its panel PANEL (an index; 0 = none) selected, and returns a struct
%   array, one entry per value that changed:
%     scope   "figure" (a setting of the figure) or "panel" (of the panel)
%     path    where, from the figure or the panel: "style.FontSize",
%             "options.stack", "options.bins.BinSec", "ref.line"
%     value   its value after the edit
%   A path goes down into a struct while both sides are scalar structs of
%   the same fields, so an edit of one field names that field; a value
%   that changes shape (an alignment of its own instead of "default", a
%   struct array) is one entry.
%   What belongs to one figure is left out: the figure's id, autoId,
%   title, enabled, panels and remembered looks (aesthetics), its grid
%   but for the spacing and the custom gaps (spacing, gapUnits, rowGap,
%   colGap); the panel's id, type, title, axis labels, place, spans and
%   size, layers, overlays and note text. The panel is compared only when
%   the edit kept the figure's panels (the same ids) and the panel's type.
%   None: an edit of something left out only (a layer, the title).
%
%   See also EphysAnalysisConfig.changeTargets, EphysAnalysisConfig.applyChanges.

arguments
    before (1,1) struct
    after (1,1) struct
    panel (1,1) double = 0
end
changes = struct('scope', {}, 'path', {}, 'value', {});
skip = ["id" "autoId" "title" "enabled" "panels" "aesthetics" "grid"];
for f = string(fieldnames(after)).'
    if ismember(f, skip) || ~isfield(before, f); continue; end
    changes = leafChanges(changes, "figure", f, before.(f), after.(f));
end
for f = ["spacing" "gapUnits" "rowGap" "colGap"]
    if isfield(before.grid, f) && isfield(after.grid, f)
        changes = leafChanges(changes, "figure", "grid." + f, before.grid.(f), after.grid.(f));
    end
end
pb = before.panels;
pa = after.panels;
if panel < 1 || panel > numel(pa) || numel(pb) ~= numel(pa) || ~isequal([pb.id], [pa.id]) || pb(panel).type ~= pa(panel).type
    return
end
skip = ["id" "type" "title" "xLabel" "yLabel" "row" "col" "rowSpan" "colSpan" "size" "layers" "overlays"];
p0 = pb(panel);
p1 = pa(panel);
for f = string(fieldnames(p1)).'
    if ismember(f, skip) || ~isfield(p0, f); continue; end
    changes = leafChanges(changes, "panel", f, p0.(f), p1.(f));
end
if ~isempty(changes); changes = changes([changes.path] ~= "note.text"); end
end


function changes = leafChanges(changes, scope, path, a, b)
%leafChanges  CHANGES with an entry for each value under PATH that differs from A to B.
if isequaln(a, b); return; end
if isstruct(a) && isstruct(b) && isscalar(a) && isscalar(b) && isequal(sort(fieldnames(a)), sort(fieldnames(b)))
    for f = string(fieldnames(b)).'
        changes = leafChanges(changes, scope, path + "." + f, a.(f), b.(f));
    end
    return
end
changes(end+1) = struct('scope', scope, 'path', path, 'value', {b});
end
