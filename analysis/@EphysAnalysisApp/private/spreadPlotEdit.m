function P = spreadPlotEdit(P, k, others, before, D)
%spreadPlotEdit  Give the plots OTHERS of P the edit that made plot K from BEFORE.
%   P = spreadPlotEdit(P, K, OTHERS, BEFORE, D): P(K) is the plot as the
%   editor shows it now, BEFORE as it showed it before the edit, D the
%   config's Defaults. Only what the edit changed goes to the others: each
%   value that differs between BEFORE and P(K), field by field into nested
%   structs, so every plot keeps its own values everywhere else.
%
%   The event reference, window and selection are "default" or a plot's
%   own. Ticking "Use default" gives the others the default too; an edit
%   of a value gives each its own: the one it used (its own, else D's)
%   with that value changed, as unticking the box does with no edit.
%
%   An edit of the raster's sort, or of its sort event, gives a plot that
%   sorts by an event but has none the whole event the editor shows (a
%   field-by-field edit would find no event to change).
%
%   The editor's channels row is a spike plot's units.channels and a
%   signal plot's channels: an edit of it reaches each plot's own. The id,
%   kind, title and aesthetics are never spread (rememberAesthetics
%   spreads the aesthetics).
after = P(k);
skip = ["id" "kind" "title" "aesthetics" "ref" "window" "selection"];
paths = changedPaths(before, after, string.empty(1, 0));
paths = paths(cellfun(@(p) ~ismember(p(1), skip), paths));
chan = cellfun(@(p) isequal(p, "channels") || isequal(p, ["units" "channels"]), paths);
sortEdit = any(cellfun(@(p) ismember(p(1), ["rasterSort" "rasterSortEvent"]), paths));
align = struct('ref', "EventRef", 'window', "Window", 'selection', "Selection");
for j = others(:).'
    q = P(j);
    for p = paths(~chan)
        q = setPath(q, p{1}, getPath(after, p{1}));
    end
    if sortEdit && q.rasterSort == "event" && ~isstruct(q.rasterSortEvent)
        q.rasterSortEvent = after.rasterSortEvent;   % a plot without a sort event takes the whole one shown
    end
    for p = paths(chan)   % last: an edit of the source decides which field the plot's channels are
        to = ["units" "channels"];
        if ismember(q.source, EphysAnalysisConfig.SignalSources); to = "channels"; end
        q = setPath(q, to, getPath(after, p{1}));
    end
    for f = string(fieldnames(align)).'
        q.(f) = spreadAlign(before.(f), after.(f), q.(f), D.(align.(f)));
    end
    P(j) = q;
end
end


function q = spreadAlign(a, b, q, d)
%spreadAlign  Plot Q's event, window or selection after the editor's plot went from A to B (D: the default).
if isequaln(a, b); return; end
if ~isstruct(b)
    q = "default";
    return
end
if ~isstruct(a); a = d; end
if ~isstruct(q); q = d; end
for p = changedPaths(a, b, string.empty(1, 0))
    q = setPath(q, p{1}, getPath(b, p{1}));
end
end


function paths = changedPaths(a, b, prefix)
%changedPaths  The field paths (a cell of string rows) where the structs A and B differ.
%   Scalar structs with the same fields are compared field by field; any
%   other value that differs (a struct array, a struct of other fields) is
%   one path.
paths = {};
for f = string(fieldnames(b)).'
    if ~isfield(a, f)
        paths{end+1} = [prefix f]; %#ok<AGROW>
        continue
    end
    va = a.(f);
    vb = b.(f);
    if isequaln(va, vb); continue; end
    if isstruct(va) && isstruct(vb) && isscalar(va) && isscalar(vb) ...
            && isempty(setxor(fieldnames(va), fieldnames(vb)))
        paths = [paths changedPaths(va, vb, [prefix f])]; %#ok<AGROW>
    else
        paths{end+1} = [prefix f]; %#ok<AGROW>
    end
end
end


function v = getPath(s, path)
%getPath  The field of S at PATH.
v = s;
for f = path
    v = v.(f);
end
end


function s = setPath(s, path, v)
%setPath  S with the field at PATH set to V, when the struct above it has that field.
if ~isstruct(s) || ~isscalar(s) || ~isfield(s, path(1)); return; end
if isscalar(path)
    s.(path) = v;
else
    s.(path(1)) = setPath(s.(path(1)), path(2:end), v);
end
end
