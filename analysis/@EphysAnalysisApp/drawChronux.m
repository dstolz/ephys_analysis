function drawChronux(obj)
%drawChronux  Draw the Chronux tab's result (renderChronux) as its Display section says, on the page shown.
R = obj.ChronuxResult;
if isempty(R); return; end
try
    S = obj.gatherChronuxSettings();
    d = S.display;
catch
    d = R.settings.display;   % a display value that cannot be used: as computed
end
d.page = max(1, obj.ChronuxPage);
delete(obj.ChronuxPanel.Children);
try
    h = renderChronux(R, obj.ChronuxPanel, Display=d);
catch ME
    obj.setChronuxState("failed", Message="Drawing failed: " + string(ME.message));
    obj.log("Chronux: drawing failed: " + string(ME.message));
    return
end
obj.ChronuxPage = h.page;
obj.ChronuxPrevPageButton.Enable = matlab.lang.OnOffSwitchState(h.page > 1);
obj.ChronuxNextPageButton.Enable = matlab.lang.OnOffSwitchState(h.page < h.pages);
if h.pages > 1
    obj.ChronuxPageLabel.Text = sprintf("page %d of %d", h.page, h.pages);
else
    obj.ChronuxPageLabel.Text = "";
end
if obj.ChronuxState == "stale"
    obj.setChronuxState("stale");   % still out of date (a display edit): the save buttons follow the result
else
    obj.setChronuxState("drawn");
end
end

