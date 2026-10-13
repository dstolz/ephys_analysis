function [E, D, failed, T] = trialsDerived(obj)
%trialsDerived  The loaded pairing's events with the derived events cut from them.
%   [E, D, FAILED, T] = obj.trialsDerived() runs deriveEvents (OnError
%   "skip") on TrialsPairing with the definitions being edited
%   (TrialsDerivedEvents): E is the pairing's events (polarity applied) plus
%   the derived lines, D and FAILED as deriveEvents returns them, and T the
%   trials they were judged on (the session's parameters with the pairing
%   columns, as the behavior file has them). Without a pairing E is
%   struct(), T [] and D, FAILED are empty.
%
%   See also deriveEvents, syncTrialsDerived, refreshTrialsPlot.

[~, D, failed] = deriveEvents(struct(), table(), []);
E = struct();
T = [];
P = obj.TrialsPairing;
if isempty(P)
    return
end
E = P.events;
S = obj.TrialsSession;
T = P.columns;
if istable(S) && height(S) == height(T)
    S = S(:, ~ismember(string(S.Properties.VariableNames), string(T.Properties.VariableNames)));
    T = [S, T];
end
[E, D, failed] = deriveEvents(E, T, obj.TrialsDerivedEvents, TrialLine=P.trialLine, OnError="skip");
end
