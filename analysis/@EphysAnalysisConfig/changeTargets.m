function T = changeTargets(F, D, k, j, changes)
%changeTargets  The other figures (or panels) that can take the changes made to figure K, with their values now.
%   T = EphysAnalysisConfig.changeTargets(F, D, K, J, CHANGES), F the
%   figures (Config.Figures) after an edit of figure K with its panel J
%   selected, D the Defaults, CHANGES figureEditChanges' entries: a
%   struct array, one row per target:
%     figure     its index in F
%     panel      its panel's index (0: the changes are the figure's)
%     figureId   F(figure).id
%     panelId    the panel's id ("" for a figure)
%     panelType  the panel's type ("" for a figure)
%     current    its values now, a cell per change (an alignment it
%                uses but does not have of its own: the one it uses,
%                the figure's or the Defaults')
%     same       true when it has every changed value already
%   With only figure settings changed, every other figure is a row. With
%   a panel setting among them, every other panel of every figure is a
%   row, figure K's too, when it takes each of them: an option it has
%   and its type takes (panelTakes); the figure settings go to the
%   panel's figure with it. A target without one of the paths (a
%   panel of another type) is not a row.
%
%   See also EphysAnalysisConfig.figureEditChanges, EphysAnalysisConfig.applyChanges,
%   EphysAnalysisConfig.panelTakes.

arguments
    F struct
    D (1,1) struct
    k (1,1) double
    j (1,1) double
    changes struct
end
T = struct('figure', {}, 'panel', {}, 'figureId', {}, 'panelId', {}, 'panelType', {}, 'current', {}, 'same', {});
if isempty(changes) || k < 1 || k > numel(F); return; end
perPanel = any([changes.scope] == "panel");
if perPanel
    if j < 1 || j > numel(F(k).panels); return; end
    P = F(k).panels(j);
end
for i = 1:numel(F)
    fig = F(i);
    if ~perPanel
        if i == k; continue; end
        [cur, ok] = currentValues(fig, 0, changes, D);
        if ok; T(end+1) = row(fig, i, 0, cur, changes); end %#ok<AGROW>
        continue
    end
    for q = 1:numel(fig.panels)
        if i == k && q == j; continue; end
        if ~takesAll(P, fig.panels(q), changes); continue; end
        [cur, ok] = currentValues(fig, q, changes, D);
        if ok; T(end+1) = row(fig, i, q, cur, changes); end %#ok<AGROW>
    end
end
end


function r = row(fig, i, q, cur, changes)
%row  The target row of figure FIG (index I), its panel Q (0: none), its values now CUR.
pid = "";
ptype = "";
if q >= 1
    pid = fig.panels(q).id;
    ptype = fig.panels(q).type;
end
same = true;
for c = 1:numel(changes)
    same = same && isequaln(cur{c}, changes(c).value);
end
r = struct('figure', i, 'panel', q, 'figureId', fig.id, 'panelId', pid, 'panelType', ptype, 'current', {cur}, 'same', same);
end


function tf = takesAll(P, Q, changes)
%takesAll  Whether panel Q takes each of panel P's changed options (panelTakes); its other settings it has.
tf = true;
for c = changes([changes.scope] == "panel")
    if startsWith(c.path, "options.")
        tf = EphysAnalysisConfig.panelTakes(P, Q, extractAfter(c.path, "options."));
        if ~tf; return; end
    end
end
end


function [cur, ok] = currentValues(fig, q, changes, D)
%currentValues  Figure FIG's (its panel Q's) values at the changes' paths; OK false when one is missing.
cur = cell(1, numel(changes));
ok = true;
for c = 1:numel(changes)
    if changes(c).scope == "figure"
        root = fig;
        A = alignmentOf(fig, [], D);
    else
        root = fig.panels(q);
        A = alignmentOf(fig, root, D);
    end
    [cur{c}, ok] = valueAt(root, split(changes(c).path, ".").', A);
    if ~ok; return; end
end
end


function [v, ok] = valueAt(s, tok, A)
%valueAt  The value of struct S at the path TOK (a string row); an alignment S uses but lacks, A's.
ok = false;
v = [];
if numel(tok) > 1 && ismember(tok(1), ["ref" "window" "selection"]) && isfield(s, tok(1)) && ~isstruct(s.(tok(1)))
    s.(tok(1)) = A.(tok(1));
end
for t = tok
    if ~(isstruct(s) && isscalar(s) && isfield(s, t)); return; end
    s = s.(t);
end
v = s;
ok = true;
end
