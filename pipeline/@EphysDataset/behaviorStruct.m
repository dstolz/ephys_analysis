function b = behaviorStruct(obj, opts)
%behaviorStruct  The associated Epsych2 session as one struct, or [].
%   B = ds.behaviorStruct() loads BehaviorFile (see readBehavior) and packs
%   it as one struct (behaviorToMat saves it as the "behavior" variable of
%   <Name>_behavior.mat):
%     trials     table, one row per trial (readEpsychSession)
%     info       the Epsych2 Info snapshot
%     meta       file, stem, subject, startTime, nTrials, responseCodeField...
%     file, subject, startTime, nTrials   copied from meta for convenience
%     pairing    [] unless a pairing is given (below)
%   Returns [] when no behavior file is associated or it no longer exists.
%
%   B = ds.behaviorStruct(Pairing=P) with P from pairTrials also appends the
%   pairing columns to trials (TrialOnset / TrialOffset seconds, sample rows
%   at the recording rate and per derived signal, PairingFlag, TrialEvents,
%   ... see pairEpsychTrials) and sets pairing to the summary: status,
%   autoApproved, trialLine, invertedLines, Fs, nSamples, signalFs,
%   nTrials, nIntervals, nPaired, cutTrials, cutIntervals, countMismatch,
%   warnings, partialIntervals, unpairedTrials, unpairedIntervals,
%   fingerprint, summary and conventions (how times and samples are
%   counted).
%
%   See also EphysDataset.readBehavior, EphysDataset.behaviorToMat,
%   EphysDataset.pairTrials, readEpsychSession.

arguments
    obj (1,1) EphysDataset
    opts.Pairing = []
end

b = [];
if obj.BehaviorFile == "" || ~isfile(obj.BehaviorFile)
    return
end
[trials, info, meta] = readEpsychSession(obj.BehaviorFile);
pairing = [];
P = opts.Pairing;
if ~isempty(P)
    if height(P.columns) ~= height(trials)
        error('EphysDataset:behaviorStruct:Pairing', ...
            'The pairing has %d trials but %s has %d.', height(P.columns), obj.BehaviorFile, height(trials));
    end
    clash = intersect(string(P.columns.Properties.VariableNames), string(trials.Properties.VariableNames));
    if ~isempty(clash)
        error('EphysDataset:behaviorStruct:Pairing', ...
            'The session already has column(s) %s.', strjoin(clash, ", "));
    end
    trials = [trials, P.columns];
    pairing = struct();
    for f = ["status" "autoApproved" "trialLine" "invertedLines" "Fs" "nSamples" "signalFs" "nTrials" ...
            "nIntervals" "nPaired" "cutTrials" "cutIntervals" "countMismatch" "warnings" ...
            "partialIntervals" "unpairedTrials" "unpairedIntervals" "fingerprint" "summary"]
        pairing.(f) = P.(f);
    end
    pairing.conventions = "trials pair in order with the trial line's intervals after the cuts; " + ...
        "seconds: t = row/Fs on the recording clock; *Sample: 1-based row at Fs; " + ...
        "*Sample_<SIG>: round((t - 1/Fs) * signalFs.<SIG>) + 1, the 1-based row of that signal nearest the recording row; " + ...
        "PairingFlag partial: the interval touches the recording start or end; " + ...
        "TrialEvents: intervals of other lines overlapping the trial";
end
b = struct('trials', trials, 'info', info, 'meta', meta, 'file', obj.BehaviorFile, ...
    'subject', meta.subject, 'startTime', meta.startTime, 'nTrials', meta.nTrials, ...
    'pairing', pairing);
end
