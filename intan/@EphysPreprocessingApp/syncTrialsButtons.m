function syncTrialsButtons(obj)
%syncTrialsButtons  Enable the pairing actions only when a pairing is shown.
has = ~isempty(obj.TrialsPairing);
state = matlab.lang.OnOffSwitchState(has);
obj.TrialsResetButton.Enable = state;
obj.TrialsApproveButton.Enable = state;
obj.TrialsRevokeButton.Enable = state;
obj.TrialsWriteButton.Enable = state;
end
