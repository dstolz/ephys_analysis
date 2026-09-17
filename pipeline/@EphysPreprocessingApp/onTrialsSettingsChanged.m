function onTrialsSettingsChanged(obj)
%onTrialsSettingsChanged  A pairing setting changed: update the config, re-pair.
%   The recorded cuts are reused only while the trial line and polarity
%   still match the record (pairTrials reports it as stale otherwise).
obj.onConfigChanged();
if ~isempty(obj.TrialsEvents)
    obj.repairTrials("recorded");
end
end
