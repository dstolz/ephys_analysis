function onChronuxEdited(obj, what)
%onChronuxEdited  React to an edit on the Chronux tab.
%   WHAT:
%     "compute"    a setting of what is computed: the plot is Out of date
%                  until Compute
%     "analysis", "timeBase", "taperMode", "pairMode"   the same, and the rows shown change
%     "signal"     another signal: its channels are listed
%     "spikeSource"  sorted units or detections: its spike trains are listed
%     "fromAlign"  the window takes the Alignment tab's (a fixed one)
%     "display"    how the result is drawn: it is drawn again
%     "pagePrev", "pageNext"   another page of the result
switch what
    case {"analysis" "timeBase" "taperMode" "pairMode" "compute"}
        obj.syncChronuxControls();
        markStale(obj);
    case "signal"
        fillChannels(obj);
        markStale(obj);
    case "spikeSource"
        fillUnits(obj);
        obj.syncChronuxControls();
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
    for dd = [C.seed C.partner C.fieldChannel]; setChoices(dd, strings(1, 0)); end
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
setChoices(C.seed, L.labels);
setChoices(C.partner, L.labels);
setChoices(C.fieldChannel, L.labels);
if L.nChan > 1 && C.partner.Value == C.seed.Value
    C.partner.Value = C.partner.ItemsData(2);
end
end


function fillUnits(obj)
%fillUnits  List the file's spike trains (the sorted units or the detections) and offer them as seed and partner.
C = obj.ChronuxControls;
I = obj.ChronuxIndex;
src = string(C.spikeSource.Value);
labels = strings(1, 0);
if ~isempty(I)
    try
        labels = chronuxSpikeTrains(I, src).labels;
    catch   % the file holds none
    end
end
if src == "units"
    C.unitsLabel.Text = "Units (none picked = all):";
else
    C.unitsLabel.Text = "Detections (none picked = all):";
end
n = numel(labels);
old = C.units.Value;
if iscell(old); old = cell2mat(old); end
set(C.units, 'Items', cellstr(labels), 'ItemsData', 1:n);
old = reshape(old(old >= 1 & old <= n), 1, []);
if isempty(old); C.units.Value = {}; else; C.units.Value = old; end
setChoices(C.unitSeed, labels);
setChoices(C.unitPartner, labels);
if n > 1 && C.unitPartner.Value == C.unitSeed.Value
    C.unitPartner.Value = C.unitPartner.ItemsData(2);
end
end


function setChoices(dd, labels)
%setChoices  The dropdown offers LABELS (their numbers as its data), keeping its choice when it is still there.
old = dd.Value;
n = numel(labels);
if n == 0
    set(dd, 'Items', "(none)", 'ItemsData', 1);
    return
end
dd.Items = cellstr(labels);
dd.ItemsData = 1:n;
if isnumeric(old) && isscalar(old) && old >= 1 && old <= n; dd.Value = old; end
end
