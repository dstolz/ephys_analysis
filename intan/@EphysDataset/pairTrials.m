function P = pairTrials(obj, opts)
%pairTrials  Pair the associated Epsych2 trials with the trial digital line.
%   P = ds.pairTrials() loads BehaviorFile (readBehavior) and the digital
%   events (digitalEvents, cached) and runs pairEpsychTrials with
%   TrialConfig. When the manifest holds a recorded pairing (TrialPairing)
%   for the same session and the same trial-line intervals, its assignment
%   is reused, so a reviewed pairing stays exactly as approved. Nothing is
%   written; see setTrialPairing to record or approve a result.
%
%   P is the pairEpsychTrials struct plus
%     status       "approved" | "unreviewed" (recorded or new)
%     recorded     true when the assignment came from TrialPairing
%     stale        true when a recorded pairing no longer matches (the
%                  session or the recording changed) and was re-aligned
%     fingerprint  identifies the session + trial-line intervals
%     digInNames, nSamples, eventsSource
%
%   Options
%     Assignment   "recorded" (default: TrialPairing when it matches, else
%                  automatic) | "auto" | [nTrials x 1] interval indices
%     Events       a digitalEvents struct to use instead of reading one
%     ProgressFcn  forwarded to digitalEvents
%
%   Errors with EphysDataset:readBehavior:NoFile when no session is
%   associated and pairEpsychTrials:NoTrialLine when the line is missing.
%
%   See also pairEpsychTrials, EphysDataset.setTrialPairing,
%   EphysDataset.behaviorToMat.

arguments
    obj (1,1) EphysDataset
    opts.Assignment = "recorded"
    opts.Events = []
    opts.ProgressFcn = []
end

tc = obj.TrialConfig;
trials = obj.readBehavior();
if isempty(opts.Events)
    E = obj.digitalEvents(ProgressFcn=opts.ProgressFcn);
else
    E = opts.Events;
end

trialLine = string(tc.TrialLine);
fp = "";
if isfield(E.events, trialLine)
    rows = round(double(E.events.(trialLine)) * E.Fs);
    [~, stem, ext] = fileparts(obj.BehaviorFile);
    fp = sprintf("%s%s|%d trials|%s|inverted:%s|%d intervals|%.0f|%.0f", stem, ext, height(trials), ...
        trialLine, strjoin(sort(string(tc.InvertedLines)), ","), size(rows, 1), sum(rows(:, 1)), sum(rows(:, 2)));
end

rec = obj.TrialPairing;
recorded = false; stale = false;
assignment = [];
if isnumeric(opts.Assignment)
    assignment = opts.Assignment;
elseif string(opts.Assignment) == "recorded" && ~isempty(rec)
    if rec.fingerprint == fp && numel(rec.assignment) == height(trials)
        assignment = rec.assignment;
        recorded = true;
    else
        stale = true;
    end
end

P = pairEpsychTrials(trials, E.events, E.Fs, TrialLine=trialLine, ...
    InvertedLines=string(tc.InvertedLines), NumSamples=E.nSamples, ...
    ToleranceS=tc.ToleranceS, SignalFs=tc.SignalFs, Assignment=assignment);
if recorded
    P.summary = replace(P.summary, "(" + P.method + ")", "(recorded " + rec.status + ", " + rec.method + ")");
    P.method = rec.method;
    P.status = rec.status;
else
    P.status = "unreviewed";
end
P.recorded = recorded;
P.stale = stale;
P.fingerprint = fp;
P.digInNames = E.digInNames;
P.nSamples = E.nSamples;
P.eventsSource = "";
if isfield(E, 'source'); P.eventsSource = E.source; end
end
