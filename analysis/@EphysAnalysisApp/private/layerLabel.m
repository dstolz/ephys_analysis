function t = layerLabel(L)
%layerLabel  A figure layer as the Layers list names it.
%   T = layerLabel(L) for one layer L (defaults("Layer")):
%     events    "events: Stim offset (marks)" (its event's eventRefLabel,
%               and drawn as marks or a train)
%     fixed     "units, fixed: ids 3 5 (mean)", "LFP, fixed: ch 3 5" or
%               "..., fixed: all"; the mean when it averages them, the
%               magnitude when a signal's are one ("AUX, fixed: ch 1 2 3
%               (magnitude)")
%     following "units, follows the observation"
%   Its name, when it has one, comes first in quotes; "  (off)" ends a
%   layer that is not enabled.
%
%   See also EphysAnalysisApp.onLayerSelected.
switch L.source
    case "events"
        t = "events: " + eventRefLabel(eventMarkRef(L.event)) + " (" + L.eventsAs + ")";
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
