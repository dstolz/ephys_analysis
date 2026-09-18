function setCopyRunning(obj, running)
%setCopyRunning  Put the Copy tab into (or out of) "a copy is in flight" mode.
%   While the engine is copying, Copy selected becomes Cancel copy, the progress
%   panel opens above the table and everything that would change the batch under
%   it is disabled. The rest of the app is left alone on purpose: the point of
%   the background copy is that it can be used. The Copy tab button goes busy so
%   that the copy is visible from the tab the user has moved on to.
others = [obj.CopyFindButton, obj.CopyPreviewButton, obj.CopyStitchButton, obj.CopyUnstitchButton];
others = others(isvalid(others));
if running
    set(others, "Enable", "off");
    obj.CopyRunButton.Text = "Cancel copy";
    obj.CopyRunButton.BackgroundColor = [0.80 0.30 0.20];
    obj.CopyRunButton.Tooltip = "Stop after the file being copied now. What has been copied is kept and can be completed later.";
    obj.CopyRunButton.ButtonPushedFcn = @(~,~) obj.onCopyCancel();
else
    set(others, "Enable", "on");
    obj.CopyRunButton.Text = "Copy selected";
    obj.CopyRunButton.BackgroundColor = [0.96 0.96 0.96];
    obj.CopyRunButton.Tooltip = "Copy the ticked sessions in the background, verify them and write session_manifest.json in each. " + ...
        "The app stays usable while they copy; this button becomes Cancel copy.";
    obj.CopyRunButton.ButtonPushedFcn = @(~,~) obj.onCopyRun(false);
    obj.CopyRunButton.Enable = "on";
    obj.CopyLiveRow = 0;
    obj.CopyLivePos = 0;
    obj.CopyLivePhase = "";
end
showProgressPanel(obj, running);
obj.syncTabStrip();
drawnow limitrate;
end


function showProgressPanel(obj, running)
%showProgressPanel  Open or close the progress panel's row of the Copy tab.
%   A hidden component still fills a "fit" row, so the row itself is closed.
if isempty(obj.CopyProgressPanel) || ~isvalid(obj.CopyProgressPanel); return; end
obj.CopyProgressPanel.Visible = matlab.lang.OnOffSwitchState(running);
if running
    obj.CopyGrid.RowHeight{3} = 'fit';
else
    obj.CopyGrid.RowHeight{3} = 0;
end
end
