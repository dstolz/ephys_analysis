function [expt, info] = sessionDataNeuroGLM(D, opts)
%sessionDataNeuroGLM  A neuroGLM experiment struct of one whole-session dataset's spike trains.
%   [EXPT, INFO] = sessionDataNeuroGLM(D) turns a sessionData struct holding
%   spike trains (DatasetBrowser's B.Sessions after Load whole sessions with
%   Data units or detected) into neuroGLM's experiment struct
%   (NeuroGLMExport.experiment), one trial per kept trial of D.trials:
%     spike trains   every element of D.spikes, labeled "sp_<unit label>"
%     timing         every digital line's pulses, "<line>_on" and
%                    "<line>_off" (D.eventsContinuous: the pulses are on the
%                    spikes' clock)
%     values         trialIndex (the row of D.trials), group (the trial's
%                    row of D.groups), the response code (D.respField) and
%                    every trial parameter (D.paramNames)
%     continuous     with Signal=, that signal's channels as one variable
%                    named after its data ("LFP", ...), dim nChannels
%   Labels are made valid and unique field names; INFO maps them back.
%
%   Options
%     Window      [pre post] s around Align: each trial spans
%                 [onset + pre, onset + post). post = Inf (the default,
%                 with pre = -0.5) ends a trial where the next trial of
%                 D.trials begins (its onset + pre), the last at the end of
%                 the recording, so trials tile the session without
%                 overlap. Trials running off the recording are dropped
%     Align       the column of D.trials the trials start from ("TrialOnset")
%     Trials      "kept" (D.kept, the browser's selection; default) | "all"
%     BinMs       neuroGLM's bin, ms (1)
%     Lines       the digital lines included (all)
%     Units       indices into D.spikes (all)
%     Signal      a sessionData struct of the same dataset holding a signal
%                 (B.Settings with data="LFP" through sessionData, or a
%                 second Load whole sessions), its channels as a continuous
%                 variable ([])
%     DropArtifacts   drop the trials whose span touches an erased period
%                 (D.artifacts; true)
%
%   INFO fields: trialIndex (the row of D.trials of each expt.trial), spans
%   ([start stop] s on the continuous clock), units (D.units' rows kept,
%   plus variable), lines (table: line, on, off: the variable names), values
%   (table: column, variable), signal (the continuous variable's name, ""),
%   nDroppedEdge, nDroppedArtifact. expt.param holds key, name, fs, binMs,
%   window, align, trialLine, groups (D.groups) and the same tables.
%
%   Errors: sessionDataNeuroGLM:NoSpikes, :NoTrials, :NoColumn,
%   :SignalMismatch, and NeuroGLMExport's.
%
%   See also NeuroGLMExport, sessionData, DatasetBrowser.

arguments
    D (1,1) struct
    opts.Window (1,2) double = [-0.5 Inf]
    opts.Align (1,1) string = "TrialOnset"
    opts.Trials (1,1) string {mustBeMember(opts.Trials, ["kept" "all"])} = "kept"
    opts.BinMs (1,1) double {mustBePositive} = 1
    opts.Lines string = string.empty
    opts.Units double = []
    opts.Signal = []
    opts.DropArtifacts (1,1) logical = true
end

if isempty(D.spikes)
    error('sessionDataNeuroGLM:NoSpikes', '%s holds no spike trains (data "%s"): load whole sessions with Data units or detected.', D.name, D.data);
end
if ~D.hasTrials || isempty(D.trials)
    error('sessionDataNeuroGLM:NoTrials', '%s has no paired trials.', D.name);
end
if ~ismember(opts.Align, string(D.trials.Properties.VariableNames))
    error('sessionDataNeuroGLM:NoColumn', '%s has no trial column "%s".', D.name, opts.Align);
end
pre = opts.Window(1); post = opts.Window(2);
if ~(pre < post)
    error('sessionDataNeuroGLM:BadWindow', 'Window must be [pre post] with pre < post.');
end

% the trials' spans, on the continuous clock
onAll = D.toContinuous(double(D.trials.(opts.Align)));
if opts.Trials == "kept"; idx = find(D.kept); else; idx = (1:height(D.trials)).'; end
idx = idx(isfinite(onAll(idx)));
on = onAll(idx);
start = on + pre;
if isfinite(post)
    stop = on + post;
else
    sortedOn = sort(onAll(isfinite(onAll)));
    stop = NaN(size(on));
    for k = 1:numel(on)
        nxt = sortedOn(find(sortedOn > on(k), 1));
        if isempty(nxt); stop(k) = D.durationSec; else; stop(k) = nxt + pre; end
    end
end
endSec = D.durationSec;
if ~isfinite(endSec); endSec = Inf; end
inside = start >= 0 & stop <= endSec & stop > start;
nDroppedEdge = nnz(~inside);
idx = idx(inside); start = start(inside); stop = stop(inside);
nDroppedArtifact = 0;
if opts.DropArtifacts && ~isempty(D.artifacts)
    a = D.artifacts;
    touch = any(start < a(:, 2).' & stop > a(:, 1).', 2);
    nDroppedArtifact = nnz(touch);
    idx = idx(~touch); start = start(~touch); stop = stop(~touch);
end
if isempty(idx)
    error('sessionDataNeuroGLM:NoTrials', '%s: no trial is left (%d off the recording, %d on an erased period).', ...
        D.name, nDroppedEdge, nDroppedArtifact);
end
spans = [start stop];

% values: the trial's row, its group, the response code and every parameter
V = table(idx, D.group(idx), 'VariableNames', {'trialIndex', 'group'});
cols = strings(0, 1);
if D.respField ~= "" && ismember(D.respField, string(D.trials.Properties.VariableNames))
    cols(end+1) = D.respField;
end
cols = [cols; reshape(setdiff(string(D.paramNames), cols, 'stable'), [], 1)];
cols = cols(ismember(cols, string(D.trials.Properties.VariableNames)));
for c = cols.'
    V.(c) = D.trials.(c)(idx, :);
end
valueCols = string(V.Properties.VariableNames).';

% lines -> "<line>_on" / "<line>_off"
lines = opts.Lines;
if isempty(lines); lines = string(fieldnames(D.eventsContinuous)).'; end
missing = setdiff(lines, string(fieldnames(D.eventsContinuous)));
if ~isempty(missing)
    error('sessionDataNeuroGLM:NoLine', '%s has no digital line %s.', D.name, strjoin(missing, ', '));
end
lines = reshape(lines, [], 1);

% units
u = opts.Units;
if isempty(u); u = (1:numel(D.spikes)).'; end
u = reshape(u, [], 1);
units = D.units(u, :);

% signal
sigName = "";
if ~isempty(opts.Signal)
    L = opts.Signal;
    if ~isstruct(L) || ~isfield(L, 'signal') || isempty(L.signal)
        error('sessionDataNeuroGLM:SignalMismatch', 'Signal must be a sessionData struct holding a signal.');
    end
    if isfield(L, 'key') && string(L.key) ~= string(D.key)
        error('sessionDataNeuroGLM:SignalMismatch', 'Signal is of dataset %s, not %s.', L.key, D.key);
    end
    sigName = string(L.data);
end

% valid, unique variable names, in one pass
names = [valueCols; lines + "_on"; lines + "_off"; "sp_" + string(units.label); sigName(sigName ~= "")];
valid = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(cellstr(names)));
valid = string(valid(:));
nV = numel(valueCols); nL = numel(lines); nU = height(units);
vValues = valid(1:nV);
vOn  = valid(nV + (1:nL));
vOff = valid(nV + nL + (1:nL));
vSp  = valid(nV + 2 * nL + (1:nU));
vSig = valid(nV + 2 * nL + nU + 1:end);
V.Properties.VariableNames = cellstr(vValues);

E = struct();
Dsc = struct();
for k = 1:nL
    iv = D.eventsContinuous.(lines(k));
    E.(vOn(k)) = iv(:, 1);
    E.(vOff(k)) = iv(:, 2);
    Dsc.(vOn(k)) = lines(k) + " onset";
    Dsc.(vOff(k)) = lines(k) + " offset";
end
Sp = struct();
for k = 1:nU
    Sp.(vSp(k)) = D.spikes{u(k)}(:);
    Dsc.(vSp(k)) = "Unit " + string(units.label(k));
end
C = struct();
if sigName ~= ""
    C.(vSig) = struct('data', opts.Signal.signal, 'fs', opts.Signal.signalFs);
    Dsc.(vSig) = sigName + " (" + strjoin(string(opts.Signal.channels.label), ", ") + ")";
end
for k = 1:nV
    Dsc.(vValues(k)) = valueCols(k);
end

info = struct();
info.units = addvars(units, vSp, 'NewVariableNames', 'variable');
info.lines = table(lines, vOn, vOff, 'VariableNames', {'line', 'on', 'off'});
info.values = table(valueCols, vValues, 'VariableNames', {'column', 'variable'});
info.signal = sigName;
info.nDroppedEdge = nDroppedEdge;
info.nDroppedArtifact = nDroppedArtifact;

param = struct('key', D.key, 'name', D.name, 'fs', D.fs, 'binMs', opts.BinMs, 'window', opts.Window, ...
    'align', opts.Align, 'trialLine', D.trialLine, 'groups', D.groups, ...
    'units', info.units, 'lines', info.lines, 'values', info.values, 'signal', sigName);
if sigName ~= ""; param.channels = opts.Signal.channels; end

[expt, keep] = NeuroGLMExport.experiment(spans, BinMs=opts.BinMs, Spikes=Sp, Events=E, Values=V, ...
    Continuous=C, Id=D.key + "/neuroGLM", Param=param, Describe=Dsc);
info.trialIndex = idx(keep);
info.spans = spans(keep, :);
expt.param.trialIndex = info.trialIndex;
end
