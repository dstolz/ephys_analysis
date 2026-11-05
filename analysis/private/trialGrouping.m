function [idx, G] = trialGrouping(how, src, V, G0, opts)
%trialGrouping  The levels of one grouping dimension of a trial panel, and each value's level.
%   [IDX, G] = trialGrouping(HOW, SRC, V, G0, OPTS) for the per-value table
%   V of a trial panel (its R.values: trial, group, session, layer, ... and
%   the parameter columns computeTrialPanel copied from the trials) gives
%   IDX [height(V) x 1], the level of each value (0: in none, left out),
%   and G, one row per level: index, label, color [1 x 3] (a starting
%   color: the draw runs them through groupPalette, isOrdinalGroups), n
%   (values in the level) and value (a number for the level: the
%   parameter's value, a bin's center, else its index; ordinalX places
%   categories at it). HOW:
%     "none"     one level, "all" (a panel without this dimension)
%     "groups"   the figure's trial groups: V.groupIndex (or V.group when
%                numeric), the rows of G0 (selectTrials' groups table),
%                n recounted
%     "param"    the trial parameter OPTS.Param, read from V's column of
%                that name (else from SRC.trials at V.trial): numeric with
%                OPTS.Bins [] each finite value a level ("Depth = 0.5",
%                groupColors(values, true)); a whole number n the range
%                cut into n equal-width bins ("Depth 0.25-0.5"; discretize,
%                the maximum in the last bin); two or more ascending edges
%                those bins (values outside them left out). Every bin is a
%                level, also an empty one. Text: each unique string (sorted;
%                missing and "" left out), lines colors
%     "session"  V.session, labeled by OPTS.Sessions (a table with label,
%                or strings; else "session k" / V.sessionKey)
%     "layer"    V.layer (the layer's index in the panel), labeled by
%                OPTS.Layers (the layers' names, in panel order); only the
%                layers with values are levels
%   Errors: trialMeasure:NoParam ("param" with a column V and SRC lack),
%   trialMeasure:BadParam (bins on a text parameter).
%
%   See also trialPanelStats, trialStats, selectTrials, groupColors.

arguments
    how (1,1) string
    src
    V table
    G0 = []
    opts.Param (1,1) string = ""
    opts.Bins double = []
    opts.Sessions = []
    opts.Layers (1,:) string = string.empty(1, 0)
end

n = height(V);
vars = string(V.Properties.VariableNames);
switch how
    case "none"
        idx = ones(n, 1);
        G = levels("all", [0.15 0.15 0.15], 1);
    case "groups"
        if ismember("groupIndex", vars)
            gi = double(V.groupIndex);
        else
            gi = double(V.group);
        end
        if istable(G0) && height(G0) > 0
            nG = height(G0);
            G = levels(string(G0.label), double(G0.color), (1:nG).');
        else
            nG = max([0; gi(:)]);
            G = levels("group " + (1:nG).', groupColors(1:nG, false), (1:nG).');
        end
        idx = gi;
        idx(~(idx >= 1 & idx <= nG)) = 0;
    case "param"
        [idx, G] = paramLevels(src, V, opts.Param, opts.Bins);
    case "session"
        s = double(V.session);
        if isempty(opts.Sessions)
            u = unique(s(isfinite(s)));
            nS = max([0; u(:)]);
            lab = "session " + (1:nS).';
            if ismember("sessionKey", vars)
                for k = 1:nS
                    r = find(s == k, 1);
                    if ~isempty(r); lab(k) = string(V.sessionKey(r)); end
                end
            end
        elseif istable(opts.Sessions)
            lab = string(opts.Sessions.label);
        else
            lab = string(opts.Sessions(:));
        end
        nS = numel(lab);
        G = levels(lab(:), groupColors(1:nS, false), (1:nS).');
        idx = s;
        idx(~(idx >= 1 & idx <= nS)) = 0;
    case "layer"
        L = double(V.layer);
        u = unique(L(isfinite(L) & L >= 1));
        lab = "layer " + u;
        names = opts.Layers;
        for k = 1:numel(u)
            if u(k) <= numel(names) && names(u(k)) ~= ""; lab(k) = names(u(k)); end
        end
        G = levels(lab(:), groupColors(1:numel(u), false), u(:));
        [~, idx] = ismember(L, u);
    otherwise
        error('trialMeasure:BadGrouping', 'A trial panel groups by groups, param, session or layer, not "%s".', how);
end
idx = reshape(double(idx), [], 1);
idx(isnan(idx)) = 0;
G.n = accumarray(idx(idx > 0), 1, [height(G) 1]);
end


function [idx, G] = paramLevels(src, V, p, bins)
%paramLevels  The levels of a trial parameter: unique values, n equal bins or given edges.
if p == ""
    error('trialMeasure:NoParam', 'Grouping by a trial parameter needs the parameter named.');
end
if ismember(p, string(V.Properties.VariableNames))
    v = V.(p);
elseif isstruct(src) && isfield(src, 'trials') && istable(src.trials) && ismember(p, string(src.trials.Properties.VariableNames))
    w = src.trials.(p);
    if iscell(w); w = string(w); end
    if islogical(w); w = double(w); end
    v = repmat(w(1), height(V), 1);
    ok = isfinite(V.trial) & V.trial >= 1;
    v(ok) = w(V.trial(ok));
    if isnumeric(v); v(~ok) = NaN; else; v(~ok) = missing; end
else
    name = "";
    if isstruct(src) && isfield(src, 'name'); name = string(src.name) + ": "; end
    error('trialMeasure:NoParam', '%sno trial parameter %s to group the values by.', name, p);
end
if iscell(v); v = string(v); end
n = height(V);
if isnumeric(v) || islogical(v)
    v = double(v);
    fin = isfinite(v);
    if isempty(bins)
        u = unique(v(fin));
        lab = p + " = " + compose("%.10g", u);
        G = levels(lab(:), groupColors(u, true), u(:));
        idx = zeros(n, 1);
        [~, idx(fin)] = ismember(v(fin), u);
        return
    end
    if isscalar(bins)
        nb = round(bins);
        lo = min(v(fin)); hi = max(v(fin));
        if isempty(lo); lo = 0; hi = 1; end
        if hi == lo; hi = lo + 1; end
        edges = linspace(lo, hi, nb + 1);
    else
        edges = sort(bins(:).');
    end
    b = discretize(v, edges);
    centers = (edges(1:end-1) + edges(2:end)).' / 2;
    lab = p + " " + compose("%.4g", edges(1:end-1).') + char(8211) + compose("%.4g", edges(2:end).');
    G = levels(lab, groupColors(centers, true), centers);
    idx = b;
    idx(isnan(idx)) = 0;
    return
end
if ~isempty(bins)
    error('trialMeasure:BadParam', 'The trial parameter %s is text, so it cannot be cut into bins.', p);
end
v = string(v);
ok = ~ismissing(v) & v ~= "";
u = unique(v(ok));
G = levels(p + " = " + u(:), groupColors(u, false), (1:numel(u)).');
idx = zeros(n, 1);
[~, idx(ok)] = ismember(v(ok), u);
end


function G = levels(label, color, value)
label = reshape(string(label), [], 1);
nL = numel(label);
G = table((1:nL).', label, reshape(double(color), nL, 3), zeros(nL, 1), reshape(double(value), nL, 1), ...
    'VariableNames', {'index', 'label', 'color', 'n', 'value'});
end
