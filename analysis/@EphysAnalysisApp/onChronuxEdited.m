function onChronuxEdited(obj, what)
%onChronuxEdited  React to an edit on the Chronux tab.
%   WHAT:
%     "compute"    a setting of what is computed: the plot is Out of date
%                  until Compute
%     "analysis", "timeBase", "taperMode"   the same, and the rows shown change
%     "signal"     another signal: its channels are listed
%     "fromAlign"  the window takes the Alignment tab's (a fixed one)
%     "display"    how the result is drawn: it is drawn again
%     "pagePrev", "pageNext"   another page of the result
switch what
    case {"analysis" "timeBase" "taperMode" "compute"}
        obj.syncChronuxControls();
        markStale(obj);
    case "signal"
        fillChannels(obj);
        markStale(obj);
    case "fromAlign"
        W = obj.Config.Defaults.Window;
        C = obj.ChronuxControls;
        if W.mode == "fixed"
            C.pre.Value = W.pre;
            C.post.Value = W.post;
            obj.syncChronuxControls();
            markStale(obj);
        else
            obj.setStatus("The Alignment tab's epoch window runs to a stop event, so its epochs differ in length; " + ...
                "Chronux needs one length: give the window here.");
        end
    case "display"
        if ~isempty(obj.ChronuxResult); obj.drawChronux(); end
    case {"pagePrev" "pageNext"}
        step = 1 - 2 * (what == "pagePrev");
        obj.ChronuxPage = obj.ChronuxPage + step;
        if ~isempty(obj.ChronuxResult); obj.drawChronux(); end
end
end


function markStale(obj)
if ~isempty(obj.ChronuxResult) && obj.ChronuxState == "drawn"
    obj.setChronuxState("stale");
end
end


function fillChannels(obj)
C = obj.ChronuxControls;
I = obj.ChronuxIndex;
sig = string(C.signal.Value);
if isempty(I) || sig == "" || ~isfield(I.signals, sig)
    set(C.channels, 'Items', {}, 'ItemsData', [], 'Value', {});
    return
end
L = I.signals.(sig);
old = C.channels.Value;
if iscell(old); old = cell2mat(old); end
items = cellstr(L.labels);
C.channels.Items = items;
C.channels.ItemsData = 1:L.nChan;
old = old(old >= 1 & old <= L.nChan);
if isempty(old); C.channels.Value = {}; else; C.channels.Value = old; end
end
