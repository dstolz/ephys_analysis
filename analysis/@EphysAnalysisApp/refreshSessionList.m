function refreshSessionList(obj)
%refreshSessionList  The session plot list and the base plots a new one can take.
%   SessionList reads "<id>  (<base plot>)", with "  (off)" for a disabled
%   one; the selected session plot (SelectedSessionPlot) is its value.
%   AddSessionBaseDropDown lists the plots whose kind can be merged across
%   sessions (EphysAnalysisConfig.SessionKinds), keeping its choice while
%   it is still there; Add is off when there is none.
P = obj.Config.SessionPlots;
lb = obj.SessionList;
n = numel(P);
if n == 0
    set(lb, "Items", {}, "ItemsData", []);
else
    text = [P.id] + "  (" + [P.plot] + ")";
    off = ~[P.enabled];
    text(off) = text(off) + "  (off)";
    k = min(max(obj.SelectedSessionPlot, 1), n);
    set(lb, "Items", cellstr(text), "ItemsData", 1:n, "Value", k);
end

dd = obj.AddSessionBaseDropDown;
ids = string.empty(1, 0);
if ~isempty(obj.Config.Plots)
    Q = obj.Config.Plots;
    ids = [Q(ismember([Q.kind], EphysAnalysisConfig.SessionKinds)).id];
end
if isempty(ids)
    set(dd, "Items", "(no plot to merge: add one on the Plots tab)", "ItemsData", "", "Value", "");
else
    v = string(dd.Value);
    if ~ismember(v, ids); v = ids(1); end
    set(dd, "Items", ids, "ItemsData", ids, "Value", v);
end
obj.AddSessionButton.Enable = matlab.lang.OnOffSwitchState(~isempty(ids));
end
