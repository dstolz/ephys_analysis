function sp = gatherSessionEditor(obj)
%gatherSessionEditor  The selected session plot as the Sessions tab's editor shows it.
%   SP is Config.SessionPlots(SelectedSessionPlot) with every field that
%   has a control taken from it (SessionEditor); the fields without one
%   keep the config's values: datasetKeys (set by Pick...,
%   onPickSessionDatasets) and aesthetics (rememberSessionAesthetics).
%   gatherConfig puts it back in the config. Error when no session plot is
%   selected.
E = obj.SessionEditor;
k = obj.SelectedSessionPlot;
if k < 1 || k > numel(obj.Config.SessionPlots)
    error('EphysAnalysisApp:NoSessionPlot', 'No session plot is selected.');
end
sp = obj.Config.SessionPlots(k);
sp.enabled = logical(E.enabled.Value);
sp.id = strtrim(string(E.id.Value));
sp.title = string(E.title.Value);
sp.plot = string(E.plot.Value);
layout = string(E.layout.Value);
if layout == "base"; layout = ""; end
sp.layout = layout;
sp.trialGroups = string(E.trialGroups.Value);
sp.datasets = string(E.datasets.Value);
sp.facet = string(E.facet.Value);
sp.series = string(E.series.Value);
sp.colorOrder = string(E.colorOrder.Value);
sp.showMembers = logical(E.showMembers.Value);
sp.error = string(E.error.Value);
sp.match = string(E.match.Value);
sp.mappingFile = strtrim(string(E.mappingFile.Value));
sp.minSessions = double(E.minSessions.Value);
data = EphysAnalysisConfig.SessionData;
sp.data = data([E.dataResults.Value E.dataEpochs.Value E.dataSignals.Value]);
end
