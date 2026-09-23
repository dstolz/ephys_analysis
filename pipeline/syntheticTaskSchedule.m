function S = syntheticTaskSchedule(opts)
%syntheticTaskSchedule  The built-in AM-detection task as a synthetic-recording schedule.
%   S = syntheticTaskSchedule(Name=Value) draws (from the current random
%   stream) the trials of an Epsych2 AM-detection session and the six
%   digital lines of the lab's rig while it runs, in RHX order: Trough
%   (nose pokes), Platform, Stim, InTrial (the trial line), RespWindow,
%   Commutator (never active). Scenario says how the recording covers the
%   session (see makeSyntheticRecording). Times are seconds on the
%   recording's clock (0 = its first sample); intervals outside the
%   recording are clipped or dropped when it is written.
%
%   Options
%     NumTrials   12 (at least 4)
%     Scenario    "clean" | "late-start" | "early-stop" | "spurious"
%
%   S fields (the schedule every synthetic recording is written from; see
%   also syntheticSessionSchedule)
%     kind          "task"
%     lineNames     the six lines, in bit order
%     trialLine     "InTrial"
%     events        struct: line -> [k x 2] seconds [on off]
%     duration      recording length (s)
%     trials        table, one row per Epsych2 trial: Onset, Offset (s, the
%                   InTrial interval; outside the recording when the
%                   scenario cut it) and the numeric parameters (TrialType,
%                   Depth, StimDelay, ..., RespCode, RespLatency)
%     Data          the Epsych2 Data struct array (computerTimestamp still
%                   to be set from trialEnd, when the start time is known)
%     Info          [] (makeSyntheticRecording writes it)
%     trialEnd      [nTrials x 1] each trial's end, s after the session start
%     sessionLead   65: the session starts this long before the recording
%     scenario, expectedCuts (trials / intervals [start end])
%
%   See also makeSyntheticRecording, syntheticModel, SyntheticDesign.

arguments
    opts.NumTrials (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(opts.NumTrials, 4)} = 12
    opts.Scenario (1,1) string {mustBeMember(opts.Scenario, ["clean" "late-start" "early-stop" "spurious"])} = "clean"
end

N = opts.NumTrials;
scenario = opts.Scenario;
preS = 65;                  % Epsych2 started this long before the recording (as in the lab)
lineNames = ["Trough" "Platform" "Stim" "InTrial" "RespWindow" "Commutator"];

% --- the Epsych2 trial schedule (seconds; t = 0 is the recording start) --------
lead = 6; tail = 4;
stimDelayMs = 600 + 300 * randi([0 4], N, 1) + randi([-100 100], N, 1);   % 500 .. 1900 ms
stimDurS = 0.5; rwDelayS = 0.6; rwDurS = 1.3; postS = 0.05;
itiS = 1.5 + rand(N, 1);
isCatch = rand(N, 1) < 0.15;
if ~any(isCatch) && N >= 6; isCatch(min(6, N)) = true; end
onS = zeros(N, 1); stimS = zeros(N, 1); offS = zeros(N, 1);
t = lead;
for k = 1:N
    onS(k)   = t;
    stimS(k) = t + stimDelayMs(k) / 1000;
    offS(k)  = stimS(k) + rwDelayS + rwDurS + postS;
    t = offS(k) + itiS(k);
end
% Responses: epsych-like bit mask (Hit 1, Miss 2, CR 4, FA 8, Reward 32,
% Punish 64, NoResponse 128, Response 256, TrialType0 1024, TrialType1 2048).
responded = false(N, 1); latencyMs = NaN(N, 1); respCode = zeros(N, 1);
for k = 1:N
    if isCatch(k)
        responded(k) = rand < 0.3;
        if responded(k); respCode(k) = 8 + 64 + 256 + 2048; else; respCode(k) = 4 + 128 + 2048; end
    else
        responded(k) = rand < 0.75;
        if responded(k); respCode(k) = 1 + 32 + 256 + 1024; else; respCode(k) = 2 + 128 + 1024; end
    end
    if responded(k); latencyMs(k) = round(150 + 750 * rand); end
end

% Scenario: where the recording starts and stops relative to the session.
shift = 0;
if scenario == "late-start"
    shift = -(onS(3) + 1.2);               % the recording starts 1.2 s into trial 3
end
onS = onS + shift; stimS = stimS + shift; offS = offS + shift;
if scenario == "early-stop"
    L = onS(N-2) + 0.5 * (offS(N-2) - onS(N-2));   % stops in the middle of trial N-2
else
    L = offS(N) + tail;
end

% --- the digital lines (seconds ON) -------------------------------------------
ev = struct();
ev.InTrial    = [onS offS];
ev.Stim       = [stimS, stimS + stimDurS];
ev.RespWindow = [stimS + rwDelayS, stimS + rwDelayS + rwDurS];
if scenario == "spurious"
    ev.InTrial = [onS(1) - 4, onS(1) - 3.96; ev.InTrial];
end
trough = zeros(0, 2);
for k = 1:N
    if responded(k)
        a = stimS(k) + rwDelayS + latencyMs(k) / 1000;
        dur = min(0.25 + 0.25 * rand, offS(k) - 0.02 - a);
        if dur > 0.05; trough(end+1, :) = [a, a + dur]; end %#ok<AGROW>
    end
    if k < N && itiS(k) > 0.9 && rand < 0.4          % a poke during the inter-trial interval
        a = offS(k) + 0.2 + rand * (itiS(k) - 0.8);
        trough(end+1, :) = [a, a + 0.15 + 0.25 * rand]; %#ok<AGROW>
    end
end
ev.Trough = sortrows(trough);
platform = zeros(0, 2);
pStart = onS(1) - 3;
for k = 1:N-1
    if itiS(k) >= 1.2 && rand < 0.3                   % the animal steps off during the ITI
        pEnd = offS(k) + 0.3;
        platform(end+1, :) = [pStart, pEnd]; %#ok<AGROW>
        pStart = pEnd + 0.6 + 0.4 * rand;
    end
end
ev.Platform = [platform; pStart, offS(N) + tail + 10];
ev.Commutator = zeros(0, 2);
events = struct();
for ln = lineNames
    events.(ln) = ev.(ln);
end

switch scenario
    case "clean",      cuts = struct('trials', [0 0], 'intervals', [0 0]);
    case "late-start", cuts = struct('trials', [3 0], 'intervals', [1 0]);
    case "early-stop", cuts = struct('trials', [0 3], 'intervals', [0 1]);
    case "spurious",   cuts = struct('trials', [0 0], 'intervals', [1 0]);
end

% --- the Epsych2 Data (computerTimestamp: makeSyntheticRecording) ---------------
depthList = [0.25 0.5 1];
depth = depthList(randi(3, N, 1)); depth(isCatch) = 0;
Data = struct( ...
    'TrialType',    num2cell(double(isCatch(:)).'), ...
    'Depth',        num2cell(depth(:).'), ...
    'Rate',         num2cell(10 * ones(1, N)), ...
    'StimDelay',    num2cell(stimDelayMs(:).'), ...
    'StimDur',      num2cell(1000 * stimDurS * ones(1, N)), ...
    'RespWinDelay', num2cell(1000 * rwDelayS * ones(1, N)), ...
    'RespWinDur',   num2cell(1000 * rwDurS * ones(1, N)), ...
    'ITIDur',       num2cell(round(1000 * itiS(:).')), ...
    'NoisedBSPL',   num2cell(60 * ones(1, N)), ...
    'NumPellets',   num2cell(ones(1, N)), ...
    'RespCode',     num2cell(respCode(:).'), ...
    'RespLatency',  num2cell(latencyMs(:).'), ...
    'TrialIndex',   num2cell(1:N), ...
    'TrialID',      num2cell(double(isCatch(:)).' + 1), ...
    'computerTimestamp', num2cell(NaT(1, N)), ...
    'isTest',       num2cell(false(1, N)));
params = rmfield(Data, {'computerTimestamp', 'isTest'});
trials = [table(onS, offS, 'VariableNames', {'Onset', 'Offset'}), struct2table(params(:))];

S = struct();
S.kind         = "task";
S.lineNames    = lineNames;
S.trialLine    = "InTrial";
S.events       = events;
S.duration     = L;
S.trials       = trials;
S.Data         = Data;
S.Info         = [];
S.trialEnd     = preS + offS - shift;
S.sessionLead  = preS;
S.scenario     = scenario;
S.expectedCuts = cuts;
end
