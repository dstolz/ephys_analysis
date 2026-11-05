function errorTypeItems(dd, type)
%errorTypeItems  Offer the figure editor's Error drop-down the error types a panel type draws.
%   errorTypeItems(DD, TYPE) sets the items of DD (the Options section's
%   Error, E.errorType) for a panel of TYPE: a continuous panel's band
%   (EphysAnalysisConfig.AuxErrorTypes, with the interquartile range)
%   and a trial distribution's, histogram's or scatter's summary (the same
%   five: TrialPanelTypes), else a PSTH's band or a rate or tuning panel's
%   error bars
%   (EphysAnalysisConfig.PanelErrorTypes). The value is kept where the new
%   items have it, else it becomes "sem". Called before a panel's value
%   is shown (applyFigureEditor) and when the editor's rows are synced
%   (syncFigureEditor).
%
%   See also EphysAnalysisConfig.panelTypes, buildFiguresTab.

data = EphysAnalysisConfig.PanelErrorTypes;
names = ["Off" "mean ± SEM" "mean ± SD" "bootstrap 95% CI"];
if ismember(string(type), ["continuous" EphysAnalysisConfig.TrialPanelTypes])
    data = EphysAnalysisConfig.AuxErrorTypes;
    names = [names "interquartile range"];
end
if isequal(string(dd.ItemsData), data); return; end
v = string(dd.Value);
if ~ismember(v, data); v = "sem"; end
dd.ItemsData = [];   % the old values need not be among the new items
set(dd, "Items", names, "ItemsData", data, "Value", char(v));
end
