function applyAlignControls(~, C, ref, win, sel)
%applyAlignControls  Show an event reference, window and selection in a control set.
%   The fields without a control (the stop event's offset, interval length
%   and time range; the selection's explicit trial rows) are not shown:
%   gatherAlignControls keeps them from the values it is given. A window
%   mode the mode box does not offer is added to it (syncPlotEditor offers
%   a plot's kind its own modes).
ref = EphysAnalysisConfig.normalizeSection("EventRef", ref);   % shown as is, checked elsewhere
C.Line.Value = char(ref.line);
C.Edge.Value = char(ref.edge);
C.Which.Value = char(ref.which);
C.N.Value = ref.n;
C.Scope.Value = char(ref.scope);
C.Offset.Value = ref.offsetSec;
C.MinDur.Value = num2text(ref.minDurationSec);
C.MaxDur.Value = num2text(ref.maxDurationSec);
C.TimeFrom.Value = num2text(ref.timeRange(1));
C.TimeTo.Value = num2text(ref.timeRange(2));

w = EphysAnalysisConfig.normalizeSection("EpochWindow", win);
setWindowModes(C.Mode, string(C.Mode.ItemsData), w.mode);
C.Pre.Value = w.pre;
C.Post.Value = w.post;
C.StopOn.Value = ~isempty(w.stop);
if ~isempty(w.stop)
    s = w.stop;
    C.StopLine.Value = char(s.line);
    C.StopEdge.Value = char(s.edge);
    C.StopWhich.Value = char(s.which);
    C.StopN.Value = s.n;
    C.StopScope.Value = char(s.scope);
end
s = EphysAnalysisConfig.normalizeSection("TrialSelection", sel);
C.Filter.Value = char(s.filter);
for w = string(fieldnames(C.Response)).'
    C.Response.(w).Value = ismember(w, s.response);
end
for f = string(fieldnames(C.Flags)).'
    C.Flags.(f).Value = ismember(f, s.pairingFlags);
end
g = [s.groupBy "(none)" "(none)"];
setDrop(C.Group1, g(1));
setDrop(C.Group2, g(2));
C.Order.Value = char(s.groupOrder);
C.MaxGroups.Value = s.maxGroups;
syncAlignEnable(C);
end


function t = num2text(x)
if isinf(x)
    if x > 0; t = 'Inf'; else; t = '-Inf'; end
else
    t = char(string(x));
end
end


function setDrop(dd, v)
if ~ismember(v, string(dd.Items)); dd.Items = [string(dd.Items) v]; end
dd.Value = char(v);
end
