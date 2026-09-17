function updatePhyButtonState(obj)
    % Enable "Open in phy" only when the selected dataset has Kilosort4
    % output (a params.py phy can open); disabled otherwise.
    if isempty(obj.LaunchPhyButton) || ~isvalid(obj.LaunchPhyButton); return; end
    d = obj.currentDataset();
    ok = ~isempty(d) && d.hasPhyOutput();
    obj.LaunchPhyButton.Enable = matlab.lang.OnOffSwitchState(ok);
end
