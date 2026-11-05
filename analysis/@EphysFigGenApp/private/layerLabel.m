function t = layerLabel(L, type)
%layerLabel  A figure layer as the Layers list names it.
%   T = layerLabel(L, TYPE) for one layer L (defaults("Layer")) of a panel
%   of TYPE (default "": any):
%     events    "events: Stim offset (marks)" (its event's eventRefLabel,
%               and drawn as marks or a train)
%     trials    "trials: Stim onset → Platform offset (ms)" (its measure's
%               trialMeasureLabel); on a trial scatter "trials: <y> vs
%               <x>" (its xMeasure's)
%     fixed     "units, fixed: ids 3 5 (mean)", "LFP, fixed: ch 3 5" or
%               "..., fixed: all"; the mean when it averages them, the
%               magnitude when a signal's are one ("AUX, fixed: ch 1 2 3
%               (magnitude)")
%     following "units, follows the observation"
%   Its name, when it has one, comes first in quotes; "  (off)" ends a
%   layer that is not enabled.
%
%   See also EphysFigGenApp.onLayerSelected.
arguments
    L (1,1) struct
    type (1,1) string = ""
end
switch L.source
    case "events"
        t = "events: " + eventRefLabel(eventMarkRef(L.event)) + " (" + L.eventsAs + ")";
    case "trials"
        t = "trials: " + trialMeasureLabel(L.measure);
        if type == "trialScatter"; t = t + " vs " + trialMeasureLabel(L.xMeasure); end
    otherwise
        if L.binding == "observation"
            t = L.source + ", follows the observation";
        else
            if ismember(L.source, EphysAnalysisConfig.SignalSources)
                what = "all channels";
                if ~isempty(L.channels); what = "ch " + strjoin(string(L.channels), " "); end
            else
                what = "all kept units";
                if ~isempty(L.units.ids); what = "ids " + strjoin(string(L.units.ids), " "); end
            end
            t = L.source + ", fixed: " + what;
            if L.aggregate == "mean"; t = t + " (mean)"; end
            if L.aggregate == "magnitude" && ismember(L.source, EphysAnalysisConfig.SignalSources); t = t + " (magnitude)"; end
        end
end
if L.name ~= ""; t = """" + L.name + """  " + t; end
if ~L.enabled; t = t + "  (off)"; end
end
