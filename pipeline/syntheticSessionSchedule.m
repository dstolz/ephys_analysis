function S = syntheticSessionSchedule(source, opts)
%syntheticSessionSchedule  A synthetic-recording schedule from a real Epsych2 session.
%   S = syntheticSessionSchedule(DS) takes the Epsych2 session associated
%   with dataset DS (an EphysDataset with a BehaviorFile) and returns the
%   schedule makeSyntheticRecording writes a recording from (Session=S): its
%   digital lines, its trials with their parameters, and the session itself
%   (Data + Info), which is written, as a copy, next to the synthetic
%   recording. The source is only read.
%   S = syntheticSessionSchedule(FILE) does the same from a session .mat
%   alone (Timing "session").
%
%   Timing: where the events come from
%     "recording"  the dataset's recorded digital lines (digitalEvents, cached
%                  next to its outputs; the first read can take a while),
%                  with its line polarity applied, and its trial pairing
%                  (pairTrials, with the reviewed cuts): the synthetic
%                  recording has the same lines, at the same times, over the
%                  same length as the real one
%     "session"    rebuilt from the session alone. Each trial ends at its
%                  computerTimestamp (without timestamps, trials follow one
%                  another ITIDur ms apart, else 2 s) and lasts TrialDuration
%                  ms; the trial line (TrialLine) is on for it, and every
%                  row of Lines adds a line that goes on Onset ms after the
%                  trial starts for Duration ms. Onset, Duration and
%                  TrialDuration are expressions over the trial's numeric
%                  parameters (e.g. "StimDelay + RespWinDelay"); a trial
%                  where one is not a number gets no interval on that line
%     "auto"       (default) "recording" when DS can give its lines, else
%                  "session"
%
%   Options
%     Timing         "auto" | "recording" | "session"
%     TrialLine      session timing: the trial line's name (default: the
%                    dataset's TrialConfig.TrialLine, else "InTrial")
%     TrialDuration  session timing: ms expression ("" = automatic: to the end
%                    of the response window when the session has StimDelay,
%                    RespWinDelay and RespWinDur, else 2000)
%     Lines          session timing: table with string columns Name, Onset,
%                    Duration (ms expressions); [] = automatic (Stim from
%                    StimDelay / StimDur, RespWindow from RespWinDelay /
%                    RespWinDur, Trough at RespLatency into the window)
%     LeadSeconds    5: session timing, recording before the first trial
%     TailSeconds    5: ... and after the last
%     Events         recording timing: a digitalEvents struct to use
%     ProbeFile      the probe for a dataset without its own (the config's
%                    default probe); S.probeFile is the one to use
%     ProgressFcn    forwarded to digitalEvents
%
%   S fields: the schedule (kind, lineNames, trialLine, events, duration,
%   trials; see syntheticTaskSchedule) plus
%     Data, Info       the session as saved
%     behaviorFile     its file
%     timing           "recording" | "session"; note: why "auto" chose it
%     source           dataset name (or the session file's stem)
%     sourceFolder     the dataset's folder ("" for a file)
%     subject          the session's subject
%     sessionStart     Info.StartTime (NaT when absent)
%     acqTime          when the recording started (the dataset's, or
%                      rebuilt: session start + the first trial - lead)
%     Fs, nSamples, nChannels   the dataset's (NaN when unknown)
%     probeFile        its own probe, else ProbeFile
%     ownProbe         true when probeFile is the dataset's own
%     cuts             the pairing's cuts (recording timing), else [0 0]s
%     trialDuration, rules   the expressions used (session timing)
%     summary          one line describing the schedule
%
%   See also makeSyntheticRecording, syntheticTaskSchedule, SyntheticDesign,
%   EphysDataset.pairTrials, readEpsychSession.

arguments
    source
    opts.Timing (1,1) string {mustBeMember(opts.Timing, ["auto" "recording" "session"])} = "auto"
    opts.TrialLine (1,1) string = ""
    opts.TrialDuration (1,1) string = ""
    opts.Lines = []
    opts.LeadSeconds (1,1) double {mustBeNonnegative} = 5
    opts.TailSeconds (1,1) double {mustBeNonnegative} = 5
    opts.Events = []
    opts.ProbeFile (1,1) string = ""
    opts.ProgressFcn = []
end

ds = [];
if isa(source, 'EphysDataset')
    ds = source;
    file = ds.BehaviorFile;
    if file == "" || ~isfile(file)
        error('syntheticSessionSchedule:NoSession', ...
            '%s has no Epsych2 session (associate one on the Project tab).', ds.Name);
    end
    name = ds.Name; folder = ds.Folder;
elseif (ischar(source) || isstring(source)) && isscalar(string(source))
    file = string(source);
    if opts.Timing == "recording"
        error('syntheticSessionSchedule:Timing', 'Recording timing needs a dataset, not a session file.');
    end
    [~, stem] = fileparts(file);
    name = string(stem); folder = "";
else
    error('syntheticSessionSchedule:Source', 'The source must be an EphysDataset or an Epsych2 session file.');
end

[T, info, meta] = readEpsychSession(file);
L = load(file, 'Data');

S = struct();
S.kind         = "session";
S.Data         = L.Data;
S.Info         = info;
S.behaviorFile = string(file);
S.source       = name;
S.sourceFolder = folder;
S.subject      = string(meta.subject);
S.sessionStart = meta.startTime;
S.Fs = NaN; S.nSamples = NaN; S.nChannels = NaN;
S.probeFile = opts.ProbeFile; S.ownProbe = false;
S.acqTime = NaT;
S.cuts = struct('trials', [0 0], 'intervals', [0 0]);
S.trialDuration = ""; S.rules = table(strings(0, 1), strings(0, 1), strings(0, 1), 'VariableNames', {'Name', 'Onset', 'Duration'});
S.note = "";
if ~isempty(ds)
    if isnan(ds.Fs) || isempty(ds.PerFile)
        try ds.refreshMetadata(); catch, end
    end
    S.Fs = ds.Fs; S.nSamples = ds.NumSamples; S.nChannels = ds.NumChannels;
    S.acqTime = ds.AcqDate;
    if ds.ProbeFile ~= ""; S.probeFile = ds.ProbeFile; S.ownProbe = true; end
    if S.subject == ""; S.subject = ds.Name; end
end
if S.subject == ""; S.subject = name; end

timing = opts.Timing;
if timing == "auto"
    timing = "session";
    if ~isempty(ds)
        try
            S = fromRecording(S, ds, T, opts);
            timing = "recording";
        catch ME
            S.note = "Rebuilt from the session: the recorded lines could not be read (" + string(ME.message) + ")";
        end
    else
        S.note = "Rebuilt from the session file.";
    end
elseif timing == "recording"
    S = fromRecording(S, ds, T, opts);
end
if timing == "session"
    S = fromSession(S, ds, T, opts);
end
S.timing = timing;
S.summary = sprintf("%s: %d trial(s), %d line(s) (%s), %.1f s, timing from the %s", S.source, height(S.trials), ...
    numel(S.lineNames), strjoin(S.lineNames, ", "), S.duration, ...
    ternary(timing == "recording", "recorded lines", "Epsych2 session"));
end


%% ---------------------------------------------------------------------------
function S = fromRecording(S, ds, T, opts)
%fromRecording  The dataset's recorded lines (polarity applied) and its trial pairing.
if isempty(opts.Events)
    E = ds.digitalEvents(ProgressFcn=opts.ProgressFcn);
else
    E = opts.Events;
end
tc = ds.TrialConfig;
P = ds.pairTrials(Events=E, Warn=false);
S.lineNames = reshape(string(fieldnames(P.events)), 1, []);
S.trialLine = string(tc.TrialLine);
S.events = P.events;
S.Fs = E.Fs;
S.nSamples = E.nSamples;
S.duration = E.nSamples / E.Fs;
S.trials = [table(P.onset(:), P.offset(:), 'VariableNames', {'Onset', 'Offset'}), parameterTable(T)];
S.cuts = struct('trials', P.cutTrials, 'intervals', P.cutIntervals);
if ~isempty(P.warnings); S.note = strjoin(P.warnings, " "); end
end


function S = fromSession(S, ds, T, opts)
%fromSession  Rebuild the trial line and the other lines from the session's parameters.
n = height(T);
if n == 0
    error('syntheticSessionSchedule:NoTrials', 'The session %s has no trials.', S.behaviorFile);
end
trialLine = opts.TrialLine;
if trialLine == ""
    trialLine = "InTrial";
    if ~isempty(ds); trialLine = string(ds.TrialConfig.TrialLine); end
end
P = parameterTable(T);
[durExpr, rules] = automaticRules(P);
if opts.TrialDuration ~= ""; durExpr = opts.TrialDuration; end
if ~isempty(opts.Lines)
    rules = opts.Lines;
    if isstruct(rules); rules = struct2table(rules, 'AsArray', true); end
    rules = table(string(rules.Name), string(rules.Onset), string(rules.Duration), ...
        'VariableNames', {'Name', 'Onset', 'Duration'});
    rules = rules(rules.Name ~= "", :);
end
if any(rules.Name == trialLine) || numel(unique(rules.Name)) < height(rules)
    error('syntheticSessionSchedule:Lines', 'Line names must be unique and differ from the trial line "%s".', trialLine);
end
bad = rules.Name(~cellfun(@isvarname, cellstr(rules.Name)));
if ~isempty(bad)
    error('syntheticSessionSchedule:Lines', 'Not a valid line name: %s', strjoin(bad, ", "));
end

% trial ends: session-relative seconds
tEnd = [];
if ismember("computerTimestamp", string(T.Properties.VariableNames))
    ts = T.computerTimestamp;
    if iscell(ts); try ts = [ts{:}].'; catch, ts = []; end; end
    if isdatetime(ts) && all(~isnat(ts))
        t0 = S.sessionStart;
        if isnat(t0); t0 = min(ts); end
        tEnd = seconds(ts(:) - t0);
    end
end
dur = evalTrialExpression(durExpr, P, "TrialDuration") / 1000;
if any(~(dur > 0))
    error('syntheticSessionSchedule:TrialDuration', 'TrialDuration "%s" is not a positive number of ms for every trial.', durExpr);
end
if isempty(tEnd)
    iti = 2 * ones(n, 1);
    if ismember("ITIDur", P.Properties.VariableNames); iti = P.ITIDur / 1000; iti(~(iti >= 0)) = 2; end
    tEnd = zeros(n, 1); t = 0;
    for k = 1:n
        t = t + dur(k); tEnd(k) = t; t = t + iti(k);
    end
    S.note = strtrim(S.note + " The session has no trial timestamps: trials follow one another ITIDur apart.");
end
on = tEnd - dur;
t0 = min(on) - opts.LeadSeconds;            % the recording starts here (session-relative)
on = on - t0; off = tEnd - t0;

events = struct();
events.(trialLine) = sortrows([on off]);
for k = 1:height(rules)
    a = evalTrialExpression(rules.Onset(k), P, rules.Name(k) + " onset") / 1000;
    d = evalTrialExpression(rules.Duration(k), P, rules.Name(k) + " duration") / 1000;
    ok = isfinite(a) & isfinite(d) & d > 0;
    events.(rules.Name(k)) = sortrows([on(ok) + a(ok), on(ok) + a(ok) + d(ok)]);
end
S.lineNames = [trialLine, reshape(rules.Name, 1, [])];
S.trialLine = trialLine;
S.events = events;
S.duration = max([off; cellfun(@(x) max([x(:); 0]), struct2cell(events))]) + opts.TailSeconds;
S.trials = [table(on, off, 'VariableNames', {'Onset', 'Offset'}), P];
S.trialDuration = durExpr;
S.rules = rules;
if ~isnat(S.sessionStart)
    S.acqTime = S.sessionStart + seconds(t0);   % else the dataset's own start, if any
end
S.nSamples = NaN;                            % the length is the rebuilt one
end


function [durExpr, rules] = automaticRules(P)
%automaticRules  The lines the lab's AM tasks imply, from the parameters there are.
has = @(v) ismember(v, string(P.Properties.VariableNames));
rules = table(strings(0, 1), strings(0, 1), strings(0, 1), 'VariableNames', {'Name', 'Onset', 'Duration'});
durExpr = "2000";
if has("StimDelay")
    stimDur = "500";
    if has("StimDur"); stimDur = "StimDur"; end
    rules(end+1, :) = {"Stim", "StimDelay", stimDur};
    durExpr = "StimDelay + " + stimDur + " + 500";
    if has("RespWinDelay") && has("RespWinDur")
        rules(end+1, :) = {"RespWindow", "StimDelay + RespWinDelay", "RespWinDur"};
        durExpr = "StimDelay + RespWinDelay + RespWinDur + 50";
        if has("RespLatency")
            rules(end+1, :) = {"Trough", "StimDelay + RespWinDelay + RespLatency", "250"};
        end
    end
end
end


function P = parameterTable(T)
%parameterTable  The session's numeric per-trial parameters (one column each).
P = T(:, []);
for v = string(T.Properties.VariableNames)
    if ismember(v, ["Onset" "Offset"]); continue; end
    x = T.(v);
    if iscell(x)
        ok = all(cellfun(@(c) (isnumeric(c) || islogical(c)) && isscalar(c), x));
        if ~ok; continue; end
        x = cellfun(@double, x);
    end
    if (isnumeric(x) || islogical(x)) && size(x, 2) == 1
        P.(v) = double(x);
    end
end
end


function v = evalTrialExpression(expr, P, what)
%evalTrialExpression  A ms expression over the trial parameters, one value per trial.
%   Only numbers, parameter names, + - * / ( ) and min / max / abs / round /
%   floor / ceil are allowed.
expr = strtrim(string(expr));
n = height(P);
if expr == ""
    error('syntheticSessionSchedule:Expression', '%s: the expression is empty.', what);
end
if ~isempty(regexp(expr, '[^\w\s\.\+\-\*/\(\),]', 'once'))
    error('syntheticSessionSchedule:Expression', '%s: "%s" may only hold numbers, parameter names, + - * / ( ) and min, max, abs, round, floor, ceil.', what, expr);
end
funcs = ["min" "max" "abs" "round" "floor" "ceil"];
ids = unique(string(regexp(expr, '(?<![\w.])[A-Za-z]\w*', 'match')));
params = string(P.Properties.VariableNames);
bad = setdiff(ids, [params funcs]);
if ~isempty(bad)
    error('syntheticSessionSchedule:Expression', '%s: "%s" names %s, which the session has no numeric parameter for (it has: %s).', ...
        what, expr, strjoin(bad, ", "), strjoin(params, ", "));
end
vars = setdiff(ids, funcs, 'stable');
body = regexprep(expr, '(?<!\.)([\*/])', '.$1');
f = str2func("@(" + strjoin(vars, ",") + ") " + body);
args = cell(1, numel(vars));
for k = 1:numel(vars); args{k} = P.(vars(k)); end
try
    v = f(args{:});
catch ME
    error('syntheticSessionSchedule:Expression', '%s: "%s" could not be evaluated: %s', what, expr, ME.message);
end
v = double(v(:));
if isscalar(v); v = repmat(v, n, 1); end
if numel(v) ~= n
    error('syntheticSessionSchedule:Expression', '%s: "%s" does not give one value per trial.', what, expr);
end
end


function s = ternary(tf, a, b)
if tf; s = a; else; s = b; end
end
