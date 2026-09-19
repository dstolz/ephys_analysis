function [ref, win, sel] = gatherAlignControls(~, C)
%gatherAlignControls  The event reference, window and selection a control set shows.
%   Plain structs, not checked: the config normalizes them, and the previews
%   and Validate report values that do not make sense.
ref = struct('line', strtrim(string(C.Line.Value)), 'edge', string(C.Edge.Value), ...
    'which', string(C.Which.Value), 'n', C.N.Value, 'scope', string(C.Scope.Value), ...
    'minDurationSec', text2num(C.MinDur.Value, 0), 'maxDurationSec', text2num(C.MaxDur.Value, Inf), ...
    'timeRange', [text2num(C.TimeFrom.Value, -Inf) text2num(C.TimeTo.Value, Inf)], ...
    'offsetSec', C.Offset.Value);
stop = [];
if C.StopOn.Value
    stop = struct('line', strtrim(string(C.StopLine.Value)), 'edge', string(C.StopEdge.Value), ...
        'which', string(C.StopWhich.Value), 'scope', string(C.StopScope.Value));
end
win = struct('mode', string(C.Mode.Value), 'pre', C.Pre.Value, 'post', C.Post.Value, 'stop', stop);
resp = string(fieldnames(C.Response)).';
resp = resp(arrayfun(@(w) C.Response.(w).Value, resp));
flags = string(fieldnames(C.Flags)).';
flags = flags(arrayfun(@(f) C.Flags.(f).Value, flags));
g = strtrim([string(C.Group1.Value) string(C.Group2.Value)]);
g = g(g ~= "(none)" & g ~= "");
g = unique(g, 'stable');
if isempty(resp); resp = string.empty(1, 0); end
if isempty(flags); flags = string.empty(1, 0); end
if isempty(g); g = string.empty(1, 0); end
sel = struct('filter', strtrim(string(C.Filter.Value)), 'response', resp, 'pairingFlags', flags, ...
    'trials', [], 'groupBy', g, 'groupOrder', string(C.Order.Value), 'maxGroups', C.MaxGroups.Value);
end


function x = text2num(t, default)
t = lower(strtrim(string(t)));
switch t
    case {"inf", "+inf"}, x = Inf;
    case "-inf",          x = -Inf;
    case "",              x = default;
    otherwise
        x = str2double(t);
        if isnan(x); x = default; end
end
end
