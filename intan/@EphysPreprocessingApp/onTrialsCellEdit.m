function onTrialsCellEdit(obj, evt)
%onTrialsCellEdit  An Interval cell was edited: re-pair with the edited assignment.
%   A blank / NaN cell unpairs that trial. An invalid assignment (out of
%   range, or an interval used twice) is refused and the table restored.
P = obj.TrialsPairing;
if isempty(P) || evt.Indices(2) ~= 3; return; end
a = double(P.interval(:));
v = evt.NewData;
if ischar(v) || isstring(v); v = str2double(v); end
if isempty(v); v = NaN; end
a(evt.Indices(1)) = v;
d = obj.currentTrialsDataset();
try
    P2 = d.pairTrials(Events=obj.TrialsEvents, Assignment=a);
catch ME
    obj.refreshTrialsView();
    obj.setStatus("Trials: " + string(ME.message));
    return
end
obj.TrialsPairing = P2;
obj.refreshTrialsView();
obj.setStatus(sprintf("Trials: trial %d -> interval %g (not saved; Approve to keep it).", evt.Indices(1), v));
end
