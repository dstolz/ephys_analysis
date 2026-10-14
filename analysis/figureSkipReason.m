function [reason, layerReasons] = figureSkipReason(src, spec)
%figureSkipReason  Why a figure, or one of its panels or layers, cannot be computed for a dataset ("" = it can).
%   [REASON, LAYERREASONS] = figureSkipReason(SRC, SPEC) checks what the
%   figure SPEC (EphysAnalysisConfig.figureFor) needs against what
%   loadAnalysisSource found in SRC, with plotSkipReason's rules.
%
%   REASON is the figure's own: "disabled"; what it observes is missing
%   ("no sorted units", "no detected spikes" for a unit observation, "no
%   <SIGNAL> extract" for a channel observation); and, when any panel with
%   an enabled layer is aligned to events, what the figure's alignment
%   needs: "no paired trials" (trial scope, "Trial", a selection that
%   filters or groups trials, an event or stop shifted by a trial
%   parameter), "no line X" (the aligned or stop line, or a line of their
%   sequences) and "no trial parameter X" (groupBy, offsetParam). With a
%   figure-level reason LAYERREASONS is empty.
%
%   LAYERREASONS is a 1 x n struct array with fields panel (the panel's id),
%   layer (the layer's index in the panel; 0 = the panel itself) and
%   reason ("" = it can be computed): one entry per panel, then one per
%   enabled layer of it. A panel's own reasons: an unknown type; its own
%   ref / window (as the figure's above); a behavior panel without paired
%   trials or its param ("no trial parameter X"); a raster sorted by a
%   trial parameter the trials lack, or by an event (rasterSort "event")
%   that names none or whose line is missing; a probe map without a probe
%   map ("no probe map"). A layer's: "no sorted units", "no detected
%   spikes", "no <SIGNAL> extract"; events: "no line X" (or of its
%   sequence), "no paired trials" (trial scope or "Trial"), "no trial
%   parameter X" (offsetParam); trials: "no paired trials", "no trial
%   parameter X" (yParam, seriesParam), "no stop event in the window" for
%   yParam "stop"; a following layer: "AUX has no recording channel: bind
%   it to fixed channels" (an AUX layer following a unit, or a channel of
%   another signal), "no unit or channel observed" (a dataset figure); a
%   source the panel type does not draw, or events drawn as a train on a
%   continuous panel. A figure that passes may still fail for one
%   observation or when it runs (EphysAnalysisRunner.computeFigure keeps
%   such a layer with its reason).
%
%   hasLine and missingStepLine are copies of plotSkipReason's local
%   functions (phase 2 of the figures work moves both to private/).
%
%   See also plotSkipReason, figureObservations, EphysAnalysisRunner.computeFigure.

arguments
    src (1,1) struct
    spec (1,1) struct
end

reason = "";
layerReasons = struct('panel', {}, 'layer', {}, 'reason', {});
if ~spec.enabled; reason = "disabled"; return; end
ob = spec.observe;
switch ob.kind
    case "unit"
        if ob.source == "units" && ~src.hasUnits; reason = "no sorted units"; return; end
        if ob.source == "detected" && ~src.hasDetected; reason = "no detected spikes"; return; end
    case "channel"
        if ~hasSignal(src, ob.signal); reason = "no " + ob.signal + " extract"; return; end
end
PT = EphysAnalysisConfig.panelTypes();
vars = string.empty(1, 0);
if istable(src.trials); vars = string(src.trials.Properties.VariableNames); end
sel = spec.selection;

aligned = false;
for k = 1:numel(spec.panels)
    p = spec.panels(k);
    row = PT.Type == p.type;
    if any(row) && PT.Aligned(row) && ~isempty(p.layers) && any([p.layers.enabled])
        aligned = true;
    end
end
if aligned
    reason = alignReason(src, spec.ref, spec.window, sel, vars, false);
    if reason ~= ""; return; end
end

out = cell(1, numel(spec.panels));
for k = 1:numel(spec.panels)
    p = spec.panels(k);
    row = PT.Type == p.type;
    pr = "";
    if ~any(row)
        pr = "unknown panel type " + p.type;
    else
        own = PT.Aligned(row) && (p.type == "behavior" || ~isequaln(p.ref, spec.ref) || ~isequaln(p.window, spec.window));
        if own
            pr = alignReason(src, p.ref, p.window, sel, vars, p.type == "behavior");
        end
        if pr == ""
            pr = panelReason(src, p, vars);
        end
    end
    e = struct('panel', p.id, 'layer', 0, 'reason', pr);
    for j = 1:numel(p.layers)
        L = p.layers(j);
        if ~L.enabled; continue; end
        lr = "";
        if any(row); lr = layerReason(src, ob, p, L, vars); end
        e(end+1) = struct('panel', p.id, 'layer', j, 'reason', lr); %#ok<AGROW>
    end
    out{k} = e;
end
if ~isempty(out); layerReasons = [layerReasons, out{:}]; end
end


function r = alignReason(src, ref, win, sel, vars, needTrials)
%alignReason  What an alignment (ref, window, the figure's selection) needs that the dataset lacks.
st = win.stop;
restrictive = sel.filter ~= "" || ~isempty(sel.response) || ~isempty(sel.trials) || ~isempty(sel.groupBy);
shifted = ref.offsetParam ~= "" || (~isempty(st) && st.offsetParam ~= "");
if (needTrials || ref.scope == "trial" || ref.line == "Trial" || restrictive || shifted) && ~src.hasTrials
    r = "no paired trials"; return
end
r = lineReason(src, ref);
if r ~= ""; return; end
if ~isempty(st)
    r = lineReason(src, st);
    if r ~= ""; return; end
end
need = [sel.groupBy ref.offsetParam];
if ~isempty(st); need(end+1) = st.offsetParam; end
r = paramReason(need, vars);
end


function r = panelReason(src, p, vars)
%panelReason  What a panel's type and options need beyond its alignment.
r = "";
o = p.options;
switch p.type
    case "raster"
        if o.rasterSort == "event"
            if isempty(o.rasterSortEvent)
                r = "no sort event (rasterSortEvent)"; return
            end
            ref = eventRef(o.rasterSortEvent);
            if (ref.scope == "trial" || ref.line == "Trial" || ref.offsetParam ~= "") && ~src.hasTrials
                r = "no paired trials"; return
            end
            r = lineReason(src, ref);
            if r == ""; r = paramReason(ref.offsetParam, vars); end
        elseif ~ismember(o.rasterSort, ["" "stop"])
            if ~src.hasTrials; r = "no paired trials"; return; end
            r = paramReason(o.rasterSort, vars);
        end
    case "behavior"
        if ~src.hasTrials; r = "no paired trials"; return; end
        if o.param == ""; r = "no trial parameter on the x axis (options.param)"; return; end
        r = paramReason(o.param, vars);
    case "probemap"
        if isempty(src.probe); r = "no probe map"; end
end
end


function r = layerReason(src, ob, p, L, vars)
%layerReason  What one enabled layer needs that the dataset (or the figure's observation) lacks.
r = "";
s = L.source;
if ~ismember(s, EphysAnalysisConfig.FigureSources)
    r = "unknown layer source " + s; return
end
if EphysAnalysisConfig.categoryOf(s, p.type) == ""
    r = "a " + p.type + " panel does not draw " + s; return
end
isSpike = ismember(s, EphysAnalysisConfig.SpikeSources);
isSignal = ismember(s, EphysAnalysisConfig.SignalSources);
if L.binding == "observation" && (isSpike || isSignal)
    if ob.kind == "dataset"
        r = "no unit or channel observed"; return
    end
    if s == "AUX" && ~(ob.kind == "channel" && ob.signal == "AUX")
        r = "AUX has no recording channel: bind it to fixed channels"; return
    end
end
switch s
    case "units"
        if ~src.hasUnits; r = "no sorted units"; end
    case "detected"
        if ~src.hasDetected; r = "no detected spikes"; end
    case "events"
        if L.eventsAs == "train" && ~ismember(p.type, ["raster" "psth" "heatmap"])
            r = "events are drawn as a train only on a raster, PSTH or heat map"; return
        end
        ref = eventMarkRef(L.event);
        if (ref.scope == "trial" || ref.line == "Trial" || ref.offsetParam ~= "") && ~src.hasTrials
            r = "no paired trials"; return
        end
        r = lineReason(src, ref);
        if r == ""; r = paramReason(ref.offsetParam, vars); end
    case "trials"
        if ~src.hasTrials; r = "no paired trials"; return; end
        if L.yParam == "stop"
            if isempty(p.window.stop); r = "no stop event in the window"; return; end
        elseif L.yParam == ""
            r = "no trial value to draw (yParam)"; return
        else
            r = paramReason(L.yParam, vars);
            if r ~= ""; return; end
        end
        r = paramReason(L.seriesParam, vars);
    otherwise   % a signal
        if ~hasSignal(src, s); r = "no " + s + " extract"; end
end
end


function r = lineReason(src, ref)
%lineReason  "no line X" for a reference's line or the first line of its sequence the recording lacks.
if ~hasLine(src, ref)
    r = "no line " + ref.line; return
end
r = missingStepLine(src, ref);
end


function r = paramReason(names, vars)
%paramReason  "no trial parameter X" for the first of NAMES (non-empty) the trials lack.
r = "";
names = string(names);
for p = names(names ~= "")
    if ~ismember(p, vars); r = "no trial parameter " + p; return; end
end
end


function tf = hasSignal(src, signal)
tf = isfield(src.signals, signal) && src.signals.(signal);
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
