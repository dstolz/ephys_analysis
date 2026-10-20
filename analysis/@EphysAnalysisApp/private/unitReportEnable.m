function tf = unitReportEnable(obj)
%unitReportEnable  Whether the Figures tab's Unit report can run now (onUnitReport), as an on / off state.
%   On with a scanned, active dataset, a figure drawn per dataset (not
%   across sessions) selected and a unit or channel picked over the
%   preview, while no run goes.
ok = false;
k = obj.SelectedFigure;
T = obj.FigureObservations;
i = obj.FigureObservationDropDown.Value;
if ~obj.Running && ~isempty(obj.Runner) && obj.ActiveIdx >= 1 && k >= 1 && k <= numel(obj.Config.Figures) ...
        && istable(T) && isnumeric(i) && isscalar(i) && i >= 1 && i <= height(T)
    ok = ~obj.Config.Figures(k).sessions.enabled && ismember(T.kind(i), ["unit" "channel"]);
end
tf = matlab.lang.OnOffSwitchState(ok);
end
