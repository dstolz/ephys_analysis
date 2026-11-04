function tf = testReportEnable(obj)
%testReportEnable  Whether the Export tab's Test report can run now (onTestReport), as an on / off state.
%   On with a scanned, active dataset, a figure drawn per dataset (not
%   across sessions) selected and an observation picked over the preview
%   (a unit, a channel, or the dataset for a figure of the dataset), while
%   no run goes.
ok = false;
k = obj.SelectedFigure;
T = obj.FigureObservations;
i = obj.FigureObservationDropDown.Value;
if ~obj.Running && ~isempty(obj.Runner) && obj.ActiveIdx >= 1 && k >= 1 && k <= numel(obj.Config.Figures) ...
        && istable(T) && isnumeric(i) && isscalar(i) && i >= 1 && i <= height(T)
    ok = ~obj.Config.Figures(k).sessions.enabled && ismember(T.kind(i), ["unit" "channel" "dataset"]);
end
tf = matlab.lang.OnOffSwitchState(ok);
end
