function reason = plotSkipReason(src, spec)
%plotSkipReason  Why a plot cannot be drawn for a dataset ("" = it can).
%   REASON = plotSkipReason(SRC, SPEC) checks what the plot SPEC (plotFor)
%   needs against what loadAnalysisSource found in SRC: "disabled", "no
%   sorted units", "no detected spikes", "no <SIGNAL> extract", "no probe
%   map", "no paired trials" (trial scope, "Trial", a selection that filters
%   or groups trials, an event or stop shifted by a trial parameter, a
%   tuning or behavior plot), "no line X" (the aligned or stop line, or a
%   raster's event marks), "no trial parameter X" (grouping, shifting,
%   tuning, behavior and raster sort parameters). A plot that passes may
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
if spec.kind == "probemap"
    if isempty(src.probe); reason = "no probe map"; end
    return
end
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
if ~isempty(st) && ~hasLine(src, st)
    reason = "no line " + st.line; return
end
if ismember(spec.kind, ["psth" "raster"]) && ismember(spec.source, ["units" "detected"])
    for ln = spec.rasterEvents.lines
        if ~(isfield(src.events, ln) || (ln == "Trial" && src.trialLine ~= ""))
            reason = "no line " + ln; return
        end
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
        if ~ismember(spec.rasterSort, ["" "stop"]); need(end+1) = spec.rasterSort; end
end
for p = need(need ~= "")
    if ~ismember(p, vars); reason = "no trial parameter " + p; return; end
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
