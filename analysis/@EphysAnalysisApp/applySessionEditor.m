function applySessionEditor(obj)
%applySessionEditor  Show the selected session plot in the Sessions tab's editor.
%   Every control takes its field of Config.SessionPlots(SelectedSessionPlot)
%   (SessionEditor holds them by field); syncSessionEditor then fills the
%   base plot and layout lists (which follow the config's plots) and shows
%   the rows it uses. No session plot: the note says how to add one.
E = obj.SessionEditor;
k = obj.SelectedSessionPlot;
cfg = obj.Config;
wasApplying = obj.Applying;
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, wasApplying));
if k < 1 || k > numel(cfg.SessionPlots)
    E.id.Value = '';
    E.title.Value = '';
    obj.syncSessionEditor();
    return
end
sp = cfg.SessionPlots(k);
E.enabled.Value = logical(sp.enabled);
E.id.Value = char(sp.id);
E.title.Value = char(sp.title);
E.trialGroups.Value = char(pickFrom(sp.trialGroups, EphysAnalysisConfig.SessionTrialGroups, "pool"));
E.datasets.Value = char(pickFrom(sp.datasets, ["ticked" "list"], "ticked"));
E.datasetKeys.Value = char(strjoin(sp.datasetKeys, ", "));
E.facet.Value = char(pickFrom(sp.facet, EphysAnalysisConfig.SessionFacets, "none"));
E.series.Value = char(pickFrom(sp.series, EphysAnalysisConfig.SessionSeries, "session"));
E.colorOrder.Value = char(pickFrom(sp.colorOrder, EphysAnalysisConfig.SessionColorOrders, "palette"));
E.showMembers.Value = logical(sp.showMembers);
E.error.Value = char(pickFrom(sp.error, EphysAnalysisConfig.SessionErrors, "sem"));
E.match.Value = char(pickFrom(sp.match, EphysAnalysisConfig.SessionMatches, "pool"));
E.mappingFile.Value = char(sp.mappingFile);
E.minSessions.Value = max(1, sp.minSessions);
E.dataResults.Value = ismember("results", sp.data);
E.dataEpochs.Value = ismember("epochs", sp.data);
E.dataSignals.Value = ismember("signals", sp.data);
obj.syncSessionEditor();   % the base plot and layout lists, with their values, and the rows shown
clear restore
end


function v = pickFrom(v, allowed, fallback)
v = string(v);
if ~isscalar(v) || ~ismember(v, allowed); v = fallback; end
end


function setApplying(obj, tf)
if isvalid(obj); obj.Applying = tf; end
end
