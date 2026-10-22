function [F, changed, copied] = copyFigureSettings(F, D, from, to, keys)
%copyFigureSettings  Give figures TO the settings KEYS of figure FROM, setting by setting.
%   [F, CHANGED, COPIED] = copyFigureSettings(F, D, FROM, TO, KEYS), F the
%   figures (Config.Figures), D the Defaults, FROM the index of the figure
%   copied from and TO the indices of the figures copied onto (FROM among
%   them is left out), copies FROM's settings KEYS (figureSettingItems'
%   Keys; a part's name, "panel.<panel id>" or any key's start before a
%   dot names every setting under it; default: every setting) onto each
%   figure of TO. The rest of each figure stays as it is, its id (an
%   automatic one follows once the figures are stored in a config, which
%   normalizes them too), title and enabled always. CHANGED are the
%   indices of the figures that changed (one that had every value already
%   did not), COPIED the keys copied (in figureSettingItems' order).
%
%   The copy is Apply to figures' (EphysAnalysisConfig.changeTargets,
%   applyChanges), so a field of an alignment a figure or panel uses but
%   does not have of its own becomes its own first:
%   - the figure's settings, in one go; "arrangement.layout" gives the
%     grid and every panel as they are, panel ids included
%   - the remembered looks picked are added to each figure's own
%     (PlotAesthetics.mergeRules: each replaces the rules it covers)
%   - then each panel setting goes to the panels of each figure (after the
%     layout, when copied) that take it: an option the panel has and its
%     type takes (EphysAnalysisConfig.panelTakes). A panel takes them from
%     the panel of FROM with its id and type, else the first of its type,
%     else from the first panel of FROM that gives it a setting
%   Error: copyFigureSettings:BadSetting (an unknown key),
%   copyFigureSettings:BadFigure (an index out of range).
%
%   See also figureSettingItems, figureSettingParts, figureLookToDesign,
%   EphysAnalysisConfig.changeTargets, EphysAnalysisConfig.applyChanges.
arguments
    F struct
    D (1,1) struct
    from (1,1) double {mustBeInteger}
    to (1,:) double {mustBeInteger}
    keys string = string(missing)
end
n = numel(F);
if from < 1 || from > n || any(to < 1 | to > n)
    error('copyFigureSettings:BadFigure', 'There are %d figures: no figure %s.', n, ...
        strjoin(string(unique([from to(to < 1 | to > n)])), ", "));
end
to = unique(to(to ~= from), 'stable');
I = figureSettingItems(F(from));
pick = pickSettingItems(I, keys, 'copyFigureSettings:BadSetting');
copied = reshape(I.Key(pick), 1, []);
changed = zeros(1, 0);
if isempty(to) || ~any(pick); return; end
G = F([from to]);   % the figure copied from first, then the figures copied onto
G0 = G;

% the figure's settings, in one go
changes = struct('scope', {}, 'path', {}, 'value', {});
for i = reshape(find(pick & I.Scope == "figure"), 1, [])
    for p = I.Paths{i}
        changes(end+1) = struct('scope', "figure", 'path', p, 'value', {valueAt(G(1), p)}); %#ok<AGROW>
    end
end
if ~isempty(changes)
    T = EphysAnalysisConfig.changeTargets(G, D, 1, 0, changes);
    G = EphysAnalysisConfig.applyChanges(G, D, T(~[T.same]), changes);
end

% the remembered looks picked, added to each figure's own
looks = I.Index(pick & I.Scope == "looks");
if ~isempty(looks)
    rules = G(1).aesthetics(looks);
    for t = 2:numel(G)
        G(t).aesthetics = PlotAesthetics.mergeRules(G(t).aesthetics, rules);
    end
end

% the panels' settings, each to the panels that take it
items = find(pick & I.Scope == "panel");
if ~isempty(items)
    src = G(1).panels;
    owner = cell(1, numel(G));   % per figure, each panel's panel of FROM (0: the first that gives it a setting)
    claim = cell(1, numel(G));
    for t = 2:numel(G)
        owner{t} = arrayfun(@(q) ownerOf(src, q), G(t).panels);
        claim{t} = zeros(1, numel(G(t).panels));
    end
    for i = reshape(items, 1, [])
        j = I.Index(i);
        for p = I.Paths{i}
            c = struct('scope', "panel", 'path', p, 'value', {valueAt(src(j), p)});
            T = EphysAnalysisConfig.changeTargets(G, D, 1, j, c);
            keep = false(1, numel(T));
            for r = 1:numel(T)
                t = T(r).figure;
                q = T(r).panel;
                if t < 2 || T(r).same; continue; end
                o = owner{t}(q);
                keep(r) = o == j || (o == 0 && ismember(claim{t}(q), [0 j]));
                if keep(r) && o == 0; claim{t}(q) = j; end
            end
            G = EphysAnalysisConfig.applyChanges(G, D, T(keep), c);
        end
    end
end

for t = 2:numel(G)
    if ~isequaln(G(t), G0(t)); changed(end+1) = to(t - 1); end %#ok<AGROW>
end
F(to) = G(2:end);
end


function o = ownerOf(src, q)
%ownerOf  The panel of SRC that panel Q takes its settings from: its id and type, else the first of its type; 0 when none.
o = find([src.id] == q.id & [src.type] == q.type, 1);
if isempty(o); o = find([src.type] == q.type, 1); end
if isempty(o); o = 0; end
end


function v = valueAt(s, path)
for t = split(path, ".").'
    s = s.(t);
end
v = s;
end
