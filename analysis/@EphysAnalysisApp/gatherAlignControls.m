function [ref, win, sel] = gatherAlignControls(~, C, ref, win, sel)
%gatherAlignControls  The event reference, window and selection a control set shows.
%   [REF, WIN, SEL] = obj.gatherAlignControls(C, REF0, WIN0, SEL0) takes the
%   values the controls C were applied from (applyAlignControls) and sets
%   every field that has a control. The others keep their values: the stop
%   event's offset, interval length and time range, and the selection's
%   explicit trial rows (a stop event ticked on anew starts from the
%   eventRef defaults). Normalized, not checked: the previews and Validate
%   report values that do not make sense.
ref = EphysAnalysisConfig.normalizeSection("EventRef", ref);
win = EphysAnalysisConfig.normalizeSection("EpochWindow", win);
sel = EphysAnalysisConfig.normalizeSection("TrialSelection", sel);
ref.line = strtrim(string(C.Line.Value));
ref.edge = string(C.Edge.Value);
ref.which = string(C.Which.Value);
ref.n = C.N.Value;
ref.scope = string(C.Scope.Value);
ref.minDurationSec = text2num(C.MinDur.Value, 0);
ref.maxDurationSec = text2num(C.MaxDur.Value, Inf);
ref.timeRange = [text2num(C.TimeFrom.Value, -Inf) text2num(C.TimeTo.Value, Inf)];
ref.offsetSec = C.Offset.Value;
stop = [];
if C.StopOn.Value
    stop = win.stop;
    if isempty(stop); stop = EphysAnalysisConfig.defaults("EventRef"); end
    stop.line = strtrim(string(C.StopLine.Value));
    stop.edge = string(C.StopEdge.Value);
    stop.which = string(C.StopWhich.Value);
    stop.n = C.StopN.Value;
    stop.scope = string(C.StopScope.Value);
end
win.mode = string(C.Mode.Value);
win.pre = C.Pre.Value;
win.post = C.Post.Value;
win.stop = stop;
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
sel.filter = strtrim(string(C.Filter.Value));
sel.response = resp;
sel.pairingFlags = flags;
sel.groupBy = g;
sel.groupOrder = string(C.Order.Value);
sel.maxGroups = C.MaxGroups.Value;
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
