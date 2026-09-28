function P = pairTrials(obj, opts)
%pairTrials  Pair the associated Epsych2 trials, in order, with the trial digital line.
%   P = ds.pairTrials() loads BehaviorFile (readBehavior) and the digital
%   events (digitalEvents, cached) and runs pairEpsychTrials with
%   TrialConfig: trial 1 with the first interval of the trial line, trial 2
%   with the second, and so on. When the manifest holds a recorded pairing
%   (TrialPairing) for the same session and the same trial-line intervals,
%   its cuts (trials / intervals dropped from the start or the end, the
%   resolution of a count mismatch) are reused, so a reviewed pairing stays
%   exactly as approved. Nothing is written; see setTrialPairing to record or
%   approve a result.
%
%   Trials from a TDT block's epocs (behaviorSource "epocs") are paired the
%   same way, with the intervals of the trial store's own event line, so
%   they pair one to one; such a new result is "approved" (autoApproved).
%
%   P is the pairEpsychTrials struct plus
%     status       "approved" | "unreviewed" (recorded or new)
%     source       "epsych2" | "epocs" (behaviorSource)
%     autoApproved true when the recorded approval was automatic
%                  (autoApproveTrialPairing)
%     recorded     true when the cuts came from TrialPairing
%     stale        true when a recorded pairing no longer matched (the
%                  session or the recording changed) and its cuts were dropped
%     fingerprint  identifies the session + trial-line intervals
%     digInNames, eventsSource
%
%   Options
%     Cuts         "recorded" (default: TrialPairing's cuts when it matches,
%                  else none) | "none" | struct with fields trials and
%                  intervals, each [fromStart fromEnd]
%     Events       a digitalEvents struct to use instead of reading one
%     Warn         true (default): a count mismatch also raises
%                  pairEpsychTrials:CountMismatch
%     ProgressFcn  forwarded to digitalEvents
%
%   Errors with EphysDataset:readBehavior:NoFile when no session is
%   associated, pairEpsychTrials:NoTrialLine when the line is missing and
%   pairEpsychTrials:Cuts when the cuts drop more than there is.
%
%   See also pairEpsychTrials, EphysDataset.setTrialPairing,
%   EphysDataset.behaviorToMat.

arguments
    obj (1,1) EphysDataset
    opts.Cuts = "recorded"
    opts.Events = []
    opts.Warn (1,1) logical = true
    opts.ProgressFcn = []
end

tc = obj.TrialConfig;
[src, store] = obj.behaviorSource();
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
    if src == "epocs"; stem = "epocs:" + store; ext = ""; end
    fp = sprintf("%s%s|%d trials|%s|inverted:%s|%d intervals|%.0f|%.0f", stem, ext, height(trials), ...
        trialLine, strjoin(sort(string(tc.InvertedLines)), ","), size(rows, 1), sum(rows(:, 1)), sum(rows(:, 2)));
end

rec = obj.TrialPairing;
recorded = false; stale = false;
cutT = [0 0]; cutI = [0 0];
if isstruct(opts.Cuts)
    cutT = double(opts.Cuts.trials);
    cutI = double(opts.Cuts.intervals);
else
    mode = string(opts.Cuts);
    if ~ismember(mode, ["recorded" "none"])
        error('EphysDataset:pairTrials:Cuts', ...
            'Cuts must be "recorded", "none" or a struct with fields trials and intervals.');
    end
    if mode == "recorded" && ~isempty(rec)
        if rec.fingerprint == fp
            cutT = rec.cut_trials;
            cutI = rec.cut_intervals;
            recorded = true;
        else
            stale = true;
        end
    end
end

P = pairEpsychTrials(trials, E.events, E.Fs, TrialLine=trialLine, ...
    InvertedLines=string(tc.InvertedLines), NumSamples=E.nSamples, ...
    CutTrials=cutT, CutIntervals=cutI, SignalFs=tc.SignalFs, Warn=opts.Warn);
if recorded
    P.status = rec.status;
    P.autoApproved = rec.auto_approved;
elseif src == "epocs" && ~P.countMismatch && ~any(cutT) && ~any(cutI)
    P.status = "approved";                  % epocs and their line are the same events
    P.autoApproved = true;
else
    P.status = "unreviewed";
    P.autoApproved = false;
end
P.source = src;
P.recorded = recorded;
P.stale = stale;
P.fingerprint = fp;
P.digInNames = E.digInNames;
P.eventsSource = "";
if isfield(E, 'source'); P.eventsSource = E.source; end
end
