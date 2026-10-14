function it = figureLayerItems(L, obs, observe, chanMeta)
%figureLayerItems  What a figure layer reads for one observation: its units or its extract's columns.
%   IT = figureLayerItems(L, OBS, OBSERVE, CHANMETA) resolves the binding of
%   the layer L (a layer of EphysAnalysisConfig.figureFor's spec: L.units a
%   complete UnitSelection) for the observation OBS (a figureObservations
%   row as a struct: kind, unitId, channel, column) of a figure observing
%   OBSERVE (spec.observe). CHANMETA is selectChannels' META of L's extract
%   over every column (selectChannels(src, L.source, Channels=[]), which
%   does not copy the cached signal); it is needed only by a continuous
%   layer that follows the observation ([] otherwise). Pure: no I/O.
%
%   A fixed layer reads what it names: L.units, or L.channels ([] = every
%   column). A layer following the observation reads
%     units / detected, under a unit observation
%       of the observed source (OBSERVE.source): that unit alone (a
%         UnitSelection of its id, every class, no quality or response
%         filter: the observed unit already passed OBSERVE.units)
%       of the other spike source: L.units on the observed unit's
%         recording channel (units.channels = OBS.channel, ids = [])
%     units / detected, under a channel observation: L.units on the
%       observed channel's recording channel
%     LFP / MUA / SPIKE, under a unit observation: the column of the
%       extract whose recordingChannel is the unit's channel
%     a signal, under a channel observation: OBS.column when it is the
%       observed signal (OBSERVE.signal), else the column of its own extract
%       that records the same channel
%   AUX records no amplifier channel, so an AUX layer can follow only an
%   observed AUX channel; a dataset observation has nothing to follow.
%
%   IT fields
%     what     "units" | "channels" | "events" | "trials"
%     units    the UnitSelection to pass to selectUnits / unitSummary
%              (what "units"; source = L.source)
%     columns  the extract's columns to read (what "channels"; [] = all)
%     follows  true when the layer follows the observation
%     skip     "" or why the layer cannot be resolved for OBS
%
%   See also figureObservations, EphysAnalysisRunner.computeFigure, selectUnits,
%   selectChannels.

arguments
    L (1,1) struct
    obs (1,1) struct
    observe (1,1) struct
    chanMeta = []
end

spike = ismember(L.source, EphysAnalysisConfig.SpikeSources);
signal = ismember(L.source, EphysAnalysisConfig.SignalSources);
it = struct('what', "units", 'units', L.units, 'columns', [], 'follows', false, 'skip', "");
if signal
    it.what = "channels";
    it.columns = L.channels;
elseif ~spike
    it.what = L.source;   % "events" | "trials": always what they name
    return
end
if L.binding ~= "observation"; return; end
it.follows = true;
it.columns = [];

if obs.kind == "dataset" || ~ismember(obs.kind, ["unit" "channel"])
    it.skip = "no unit or channel observed";
    return
end
auxMsg = "AUX has no recording channel: bind it to fixed channels";
rc = obs.channel;   % the observed recording channel (NaN: none, an AUX channel)

if spike
    u = L.units;
    if obs.kind == "unit" && L.source == observe.source
        u = EphysAnalysisConfig.defaults("UnitSelection");
        u.source = L.source;
        u.classes = string.empty(1, 0);   % the observed unit, whatever its class
        u.ids = obs.unitId;
    else
        if ~isfinite(rc)
            it.skip = "the observed " + obs.kind + " has no recording channel";
            return
        end
        u.ids = [];
        u.channels = rc;
    end
    it.units = u;
    return
end

% a signal layer following the observation
if obs.kind == "channel" && L.source == observe.signal
    it.columns = obs.column;
    return
end
if L.source == "AUX"
    it.skip = auxMsg;
    return
end
if ~isfinite(rc)
    if obs.kind == "channel" && observe.signal == "AUX"
        it.skip = "the observed AUX channel has no recording channel for " + L.source + " to follow";
    else
        it.skip = "the observed " + obs.kind + " has no recording channel";
    end
    return
end
if ~istable(chanMeta) || ~ismember("recordingChannel", string(chanMeta.Properties.VariableNames))
    error('figureLayerItems:NoChannels', 'A %s layer following the observation needs its extract''s channel table.', L.source);
end
col = find(chanMeta.recordingChannel == rc, 1);
if isempty(col)
    it.skip = sprintf("no %s column records channel %d", L.source, rc);
    return
end
it.columns = double(chanMeta.channel(col));
end
