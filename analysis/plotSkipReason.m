function reason = plotSkipReason(src, spec)
%plotSkipReason  Why a plot cannot be drawn for a dataset ("" = it can).
%   REASON = plotSkipReason(SRC, SPEC) checks what the plot SPEC (plotFor)
%   needs against what loadAnalysisSource found in SRC: "disabled", "no
%   sorted units", "no detected spikes", "no <SIGNAL> extract", "no probe
%   map" (a probe map, or a waveforms plot in the probe layout), "no paired trials" (trial scope, "Trial", a selection that filters
%   or groups trials, an event or stop shifted by a trial parameter, a
%   tuning or behavior plot), "no line X" (the aligned or stop line, a line
%   of their sequences, a raster's event marks and mark sequences, or the
%   event a drawn raster is sorted by and its sequence), "no trial
%   parameter X" (grouping, shifting (the sort event's too), tuning,
%   behavior and raster sort parameters). A plot that passes may
%   still fail when it runs (e.g. no event survives the selection).
%
%   See also EphysAnalysisRunner.plan, EphysAnalysisRunner.runDataset.

arguments
    src (1,1) struct
    spec (1,1) struct
end

reason = "";
if ~spec.enabled; reason = "disabled"; return; end
switch spec.source
    case "units"
        if ~src.hasUnits; reason = "no sorted units"; return; end
    case "detected"
        if ~src.hasDetected; reason = "no detected spikes"; return; end
    case "trials"
        if ~src.hasTrials; reason = "no paired trials"; return; end
    otherwise
        if ~isfield(src.signals, spec.source) || ~src.signals.(spec.source)
            reason = "no " + spec.source + " extract"; return
        end
end
if spec.kind == "probemap" || (spec.kind == "waveforms" && spec.layout == "probe")
    if isempty(src.probe); reason = "no probe map"; end
    return
end
if spec.kind == "waveforms"; return; end
sel = spec.selection;
st = spec.window.stop;
restrictive = sel.filter ~= "" || ~isempty(sel.response) || ~isempty(sel.trials) || ~isempty(sel.groupBy);
shifted = spec.ref.offsetParam ~= "" || (~isempty(st) && st.offsetParam ~= "");
needTrials = spec.ref.scope == "trial" || spec.ref.line == "Trial" || restrictive || shifted || ...
    ismember(spec.kind, ["tuning" "behavior"]);
if needTrials && ~src.hasTrials
    reason = "no paired trials";
    return
end
if ~hasLine(src, spec.ref)
    reason = "no line " + spec.ref.line; return
end
reason = missingStepLine(src, spec.ref);
if reason ~= ""; return; end
if ~isempty(st)
    if ~hasLine(src, st)
        reason = "no line " + st.line; return
    end
    reason = missingStepLine(src, st);
    if reason ~= ""; return; end
end
sortRef = [];   % the event a drawn raster is sorted by
if ismember(spec.kind, ["psth" "raster"]) && (spec.kind == "raster" || spec.withRaster) && spec.rasterSort == "event"
    sortRef = spec.rasterSortEvent;
end
if ismember(spec.kind, ["psth" "raster"]) && ismember(spec.source, ["units" "detected"])
    for ln = spec.rasterEvents.lines
        if ~(isfield(src.events, ln) || (ln == "Trial" && src.trialLine ~= ""))
            reason = "no line " + ln; return
        end
    end
    for q = 1:numel(spec.rasterEvents.sequences)
        mk = spec.rasterEvents.sequences(q);
        if (mk.scope == "trial" || mk.line == "Trial") && ~src.hasTrials
            reason = "no paired trials"; return
        end
        if ~hasLine(src, mk)
            reason = "no line " + mk.line; return
        end
        reason = missingStepLine(src, mk);
        if reason ~= ""; return; end
    end
    if ~isempty(sortRef)
        if ~hasLine(src, sortRef)
            reason = "no line " + sortRef.line; return
        end
        reason = missingStepLine(src, sortRef);
        if reason ~= ""; return; end
    end
end
vars = string(src.trials.Properties.VariableNames);
need = [sel.groupBy spec.ref.offsetParam];
if ~isempty(st); need(end+1) = st.offsetParam; end
switch spec.kind
    case "tuning"
        need = [need spec.param spec.seriesParam];
    case "behavior"
        need = [need spec.param spec.seriesParam];
        if spec.yParam ~= "stop"; need(end+1) = spec.yParam; end
    case {"psth" "raster"}
        if ~ismember(spec.rasterSort, ["" "stop" "event"]); need(end+1) = spec.rasterSort; end
        if ~isempty(sortRef) && ismember(spec.source, ["units" "detected"]); need(end+1) = sortRef.offsetParam; end
end
for p = need(need ~= "")
    if ~ismember(p, vars); reason = "no trial parameter " + p; return; end
end
end


function reason = missingStepLine(src, ref)
%missingStepLine  "no line X" for the first step of REF's sequence whose line the recording lacks.
reason = "";
for k = 1:numel(ref.sequence)
    ln = ref.sequence(k).line;
    if ln == "Trial" || (src.trialLine ~= "" && ln == src.trialLine)
        ok = src.hasTrials || isfield(src.events, src.trialLine);
    else
        ok = isfield(src.events, ln) || (src.hasTrials && height(src.trials) > 0 && isfield(src.trials.TrialEvents, char(ln)));
    end
    if ~ok
        reason = "no line " + ln;
        return
    end
end
end


function tf = hasLine(src, ref)
%hasLine  The line exists where the reference's scope looks for it.
if ref.line == "Trial" || (src.trialLine ~= "" && ref.line == src.trialLine)
    tf = src.hasTrials || isfield(src.events, src.trialLine);
    return
end
useTrials = ref.scope == "trial" || (ref.scope == "auto" && src.hasTrials);
if useTrials && src.hasTrials && height(src.trials) > 0
    tf = isfield(src.trials.TrialEvents, char(ref.line));
else
    tf = isfield(src.events, ref.line);
end
end
