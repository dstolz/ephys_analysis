function syncTrialsCuts(obj)
%syncTrialsCuts  Cut spinners (limits, values, enable) and their labels from TrialsPairing.
%   Setting a spinner's Value here does not fire its callback. Without a
%   pairing the spinners read 0 and are disabled.
P = obj.TrialsPairing;
s = obj.TrialsCutSpinners;
if isempty(P)
    for k = 1:numel(s)
        s(k).Value = 0;                    % always within the limits, old and new
        s(k).Limits = [0 Inf];
        s(k).Enable = "off";
    end
    obj.TrialsCutIntervalsLabel.Text = string(obj.TrialsLineDropDown.Value) + " intervals";
    return
end
vals = [P.cutTrials; P.cutIntervals];
lims = max([P.nTrials; P.nIntervals], 1);
for r = 1:2
    for c = 1:2
        s(r, c).Value = 0;
        s(r, c).Limits = [0 lims(r)];
        s(r, c).Value = min(vals(r, c), lims(r));
        s(r, c).Enable = "on";
    end
end
obj.TrialsCutIntervalsLabel.Text = P.trialLine + " intervals";
end
