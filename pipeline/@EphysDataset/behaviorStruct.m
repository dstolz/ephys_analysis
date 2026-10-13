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
%     derivedEvents   the derived events (deriveEvents' D, 1 x 0 without a
%                pairing or definitions)
%     derivedEventsFailed   the definitions that could not be made here
%                (deriveEvents' FAILED: index, name, identifier, message)
%   Returns [] when no behavior file is associated or it no longer exists,
%   unless the trials come from a TDT block's epocs (behaviorSource
%   "epocs"; file is "" then, see readBehavior).
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
%   With a pairing, the derived events of TrialConfig.DerivedEvents are cut
%   from the pairing's events (deriveEvents) and kept as derivedEvents: each
%   is also added to every trial's TrialEvents / TrialEventSamples like a
%   recorded line, and one marked InDataset adds a logical trials column of
%   its name (true where the trial meets its conditions). A definition that
%   cannot be made for this session (e.g. a condition on a parameter its
%   trials do not have) is left out with a warning
%   (EphysDataset:behaviorStruct:DerivedEvent) and listed in
%   derivedEventsFailed. Without a pairing they are all left out, with a
%   warning (EphysDataset:behaviorStruct:NoPairing).
%
%   See also EphysDataset.readBehavior, EphysDataset.behaviorToMat,
%   EphysDataset.pairTrials, readEpsychSession.

arguments
    obj (1,1) EphysDataset
    opts.Pairing = []
end

b = [];
src = obj.behaviorSource();
if src == "epocs"
    [trials, info, meta] = obj.readBehavior();
elseif obj.BehaviorFile == "" || ~isfile(obj.BehaviorFile)
    return
else
    [trials, info, meta] = readEpsychSession(obj.BehaviorFile);
end
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
    [trials, D, failed] = addDerivedEvents(trials, P, obj.TrialConfig);
    for k = 1:numel(failed)
        warning('EphysDataset:behaviorStruct:DerivedEvent', '%s: derived event left out. %s', obj.Name, failed(k).message);
    end
    pairing = struct();
    for f = ["status" "autoApproved" "trialLine" "invertedLines" "Fs" "nSamples" "signalFs" "nTrials" ...
            "nIntervals" "nPaired" "cutTrials" "cutIntervals" "countMismatch" "warnings" ...
            "partialIntervals" "unpairedTrials" "unpairedIntervals" "fingerprint" "summary"]
        pairing.(f) = P.(f);
    end
    pairing.source = src;
    pairing.conventions = "trials pair in order with the trial line's intervals after the cuts; " + ...
        "seconds: t = row/Fs on the recording clock; *Sample: 1-based row at Fs; " + ...
        "*Sample_<SIG>: round((t - 1/Fs) * signalFs.<SIG>) + 1, the 1-based row of that signal nearest the recording row; " + ...
        "PairingFlag partial: the interval touches the recording start or end; " + ...
        "TrialEvents: intervals of other lines overlapping the trial";
end
if isempty(P)
    [~, D, failed] = deriveEvents(struct(), table(), []);
    if isfield(obj.TrialConfig, 'DerivedEvents') && ~isempty(obj.TrialConfig.DerivedEvents)
        warning('EphysDataset:behaviorStruct:NoPairing', ...
            '%s: the derived events need paired trials and are left out.', obj.Name);
    end
end
b = struct('trials', trials, 'info', info, 'meta', meta, 'file', obj.BehaviorFile, ...
    'subject', meta.subject, 'startTime', meta.startTime, 'nTrials', meta.nTrials, ...
    'pairing', pairing);
b.derivedEvents = D;
b.derivedEventsFailed = failed;
end


function [trials, D, failed] = addDerivedEvents(trials, P, tc)
%addDerivedEvents  Cut the derived events from the pairing's events into the trials.
defs = [];
if isfield(tc, 'DerivedEvents'); defs = tc.DerivedEvents; end
[~, D, failed] = deriveEvents(P.events, trials, defs, TrialLine=P.trialLine, OnError="skip");
if isempty(D)
    return
end
% Each derived line joins the trial's other lines: its intervals overlapping
% the trial, as pairEpsychTrials keeps them.
ev = trials.TrialEvents;
evS = trials.TrialEventSamples;
on = trials.TrialOnset;
off = trials.TrialOffset;
for k = 1:numel(D)
    iv = D(k).intervals;
    for i = 1:height(trials)
        if isfinite(on(i)) && ~isempty(iv)
            x = iv(iv(:, 1) <= off(i) & iv(:, 2) >= on(i), :);
        else
            x = zeros(0, 2);
        end
        ev(i).(D(k).name) = x;
        evS(i).(D(k).name) = round(x * P.Fs);
    end
    if D(k).inDataset
        trials.(D(k).name) = D(k).trials;
    end
end
trials.TrialEvents = ev;
trials.TrialEventSamples = evS;
end
