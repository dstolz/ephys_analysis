function [E, G] = epochTable(src, ref, opts)
%epochTable  One row per epoch: its event, window, trial and group.
%   [E, G] = epochTable(SRC, REF, Window=WIN, Selection=SEL) aligns the
%   dataset SRC (loadAnalysisSource) to the eventRef REF, over the
%   epochWindow WIN, keeping and grouping trials by the trialSelection SEL
%   (structs or [] for the defaults). E has one row per epoch, by time:
%     epoch        1..n
%     trial        row of src.trials the epoch belongs to (NaN: none)
%     t0           the event, s (t = row/Fs)
%     t1           the stop event (WIN.stop), s; NaN without one
%     tStart, tStop   the window: [t0+pre, t0+post] ("fixed") or
%                  [t0+pre, t1+post] ("between")
%     duration     tStop - tStart
%     complete     the window lies inside the recording (0 .. durationSec)
%                  and, in "between" mode, has its stop event
%     groupIndex, group   the epoch's group (row / label of G)
%     <groupBy parameters and Columns>   the trial's values
%   G is selectTrials' groups table with n replaced by the number of epochs
%   in each group and nTrials added (the kept trials of the group).
%
%   The stop event of an epoch is the first (REF.which of WIN.stop) stop
%   event at or after t0: in the same trial when the epoch has one (stop
%   scope "trial" or "auto"), else over the recording.
%   With a restrictive selection (filter, response, trials or groupBy) in
%   recording scope, events outside the kept trials are dropped.
%
%   Options
%     Window       epochWindow (default epochWindow())
%     Selection    trialSelection (default trialSelection())
%     Incomplete   "drop" (default): drop epochs that are not complete;
%                  "keep": keep them (evokedPotential then pads with NaN)
%     Columns      further trial columns to copy onto each epoch (e.g. the
%                  tuning parameter)
%
%   E.Properties.UserData holds ref, window, selection, scope, nEvents,
%   nDroppedNoStop, nDroppedEdge, nTrials, nTrialsSelected and dataset.
%   Errors: epochTable:NoEpochs (every event dropped), epochTable:NoColumn,
%   and those of resolveEvents / selectTrials.
%
%   See also eventRef, epochWindow, trialSelection, resolveEvents, psth,
%   evokedPotential, firingRate.

arguments
    src (1,1) struct
    ref = []
    opts.Window = []
    opts.Selection = []
    opts.Incomplete (1,1) string {mustBeMember(opts.Incomplete, ["drop" "keep"])} = "drop"
    opts.Columns (1,:) string = string.empty(1,0)
end

ref = eventRef(ref);
win = epochWindow(opts.Window);
sel = trialSelection(opts.Selection);
[mask, G, gi] = selectTrials(src, sel);
restrictive = sel.filter ~= "" || ~isempty(sel.response) || ~isempty(sel.trials) || ~isempty(sel.groupBy);
scope = ref.scope;
if scope == "auto"
    if src.hasTrials; scope = "trial"; else; scope = "recording"; end
end
if scope == "trial" || restrictive
    maskArg = mask;
else
    maskArg = [];
end
[t0, trial] = resolveEvents(src, ref, maskArg);
nEv = numel(t0);

% --- stop events ---------------------------------------------------------------
t1 = NaN(nEv, 1);
if ~isempty(win.stop)
    t1 = stopTimes(src, win.stop, t0, trial);
end
tStart = t0 + win.pre;
if win.mode == "fixed"
    tStop = t0 + win.post;
else
    tStop = t1 + win.post;
end
duration = tStop - tStart;
hasStop = isfinite(t1) | win.mode == "fixed";
inRec = tStart >= 0;
if isfinite(src.durationSec)
    inRec = inRec & tStop <= src.durationSec;
end
okLen = ~(win.mode == "between") | duration > 0;
complete = hasStop & inRec & okLen;
nNoStop = nnz(~hasStop | ~okLen);
nEdge = nnz(hasStop & okLen & ~inRec);

% --- groups ---------------------------------------------------------------------
groupIndex = ones(nEv, 1);
if src.hasTrials
    has = isfinite(trial);
    if restrictive || scope == "trial"
        groupIndex(:) = 0;
        groupIndex(has) = gi(trial(has));
    end
end

keep = true(nEv, 1);
if opts.Incomplete == "drop"
    keep = complete;
end
keep = keep & groupIndex > 0;
if ~any(keep)
    why = strings(0, 1);
    if nNoStop > 0; why(end+1) = sprintf("%d without a stop event", nNoStop); end
    if nEdge > 0;   why(end+1) = sprintf("%d with a window outside the recording", nEdge); end
    error('epochTable:NoEpochs', '%s: none of the %d %s event(s) makes a usable epoch (%s).', ...
        src.name, nEv, ref.line, strjoin(why, "; "));
end
t0 = t0(keep); t1 = t1(keep); trial = trial(keep); tStart = tStart(keep); tStop = tStop(keep);
duration = duration(keep); complete = complete(keep); groupIndex = groupIndex(keep);
n = numel(t0);
epoch = (1:n).';
group = G.label(groupIndex);
E = table(epoch, trial, t0, t1, tStart, tStop, duration, complete, groupIndex, group);

% --- per-epoch trial values -------------------------------------------------------
cols = unique([sel.groupBy, opts.Columns], 'stable');
cols = cols(cols ~= "");
for c = cols
    if ~src.hasTrials || ~ismember(c, string(src.trials.Properties.VariableNames))
        error('epochTable:NoColumn', '%s: no trial column "%s" to copy onto the epochs.', src.name, c);
    end
    v = src.trials.(c);
    if iscell(v); v = string(v); end
    if isnumeric(v) || islogical(v)
        x = NaN(n, 1);
        x(isfinite(trial)) = double(v(trial(isfinite(trial))));
    else
        x = strings(n, 1);
        x(:) = missing;
        x(isfinite(trial)) = string(v(trial(isfinite(trial))));
    end
    E.(c) = x;
end

G.nTrials = G.n;
G.n = accumarray(groupIndex, 1, [height(G) 1]);
E.Properties.UserData = struct('ref', ref, 'window', win, 'selection', sel, 'scope', scope, ...
    'nEvents', nEv, 'nDroppedNoStop', nNoStop * (opts.Incomplete == "drop"), ...
    'nDroppedEdge', nEdge * (opts.Incomplete == "drop"), 'nTrials', src.nTrials, ...
    'nTrialsSelected', nnz(mask), 'dataset', src.name);
end


function t1 = stopTimes(src, stop, t0, trial)
%stopTimes  The stop event following each epoch event (NaN when none).
n = numel(t0);
t1 = NaN(n, 1);
isTrialLine = stop.line == "Trial" || (src.trialLine ~= "" && stop.line == src.trialLine);
recIv = [];
for j = 1:n
    useTrial = stop.scope == "trial" || (stop.scope == "auto" && src.hasTrials && isfinite(trial(j)));
    if useTrial
        if ~src.hasTrials || ~isfinite(trial(j)); continue; end
        r = trial(j);
        T = src.trials;
        if isTrialLine
            iv = [T.TrialOnset(r) T.TrialOffset(r)];
        elseif isfield(T.TrialEvents, char(stop.line))
            iv = double(T.TrialEvents(r).(stop.line));
        else
            error('resolveEvents:NoLine', '%s: no digital line "%s" for the stop event.', src.name, stop.line);
        end
        origin = T.TrialOnset(r);
    else
        if isempty(recIv)
            line = stop.line;
            if isTrialLine; line = src.trialLine; end
            if ~isfield(src.events, line)
                error('resolveEvents:NoLine', '%s: no digital line "%s" for the stop event.', src.name, line);
            end
            recIv = double(src.events.(line));
            if isempty(recIv); recIv = zeros(0, 2); end
        end
        iv = recIv;
        origin = 0;
    end
    e = pickEvents(iv, stop, origin, t0(j) - stop.offsetSec);
    if ~isempty(e); t1(j) = e(1); end
end
end
