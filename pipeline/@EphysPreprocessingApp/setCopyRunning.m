function setCopyRunning(obj, running)
%setCopyRunning  Put the Copy tab into (or out of) "a copy is in flight" mode.
%   While the engine is copying, Copy selected becomes Cancel copy and
%   everything that would change the batch under it is disabled. The rest of
%   the app is left alone on purpose: the point of the background copy is that
%   it can be used.
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
end
drawnow limitrate;
end
