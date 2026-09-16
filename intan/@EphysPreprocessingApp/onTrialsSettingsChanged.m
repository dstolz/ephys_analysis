function onTrialsSettingsChanged(obj)
%onTrialsSettingsChanged  A pairing setting changed: update the config, re-pair.
%   The recorded pairing is reused only while the trial line and polarity
%   still match it (pairTrials reports it as stale otherwise).
obj.onConfigChanged();
if ~isempty(obj.TrialsEvents)
    obj.repairTrials("recorded");
end
end
