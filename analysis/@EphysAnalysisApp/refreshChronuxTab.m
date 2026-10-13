function refreshChronuxTab(obj)
%refreshChronuxTab  Show the active dataset's Chronux file, its signals and channels, and what can be done.
%   The file (chronuxFileFor: the output folder's, else the local
%   cache's) is indexed once (loadChronuxExport) while it does not change.
%   It says where the file is, when it was made, its signals and units,
%   and when it is older than the dataset's extract (Recreate it). Create
%   needs an extract (the Signals step); Compute needs the file and
%   Chronux on the MATLAB path.
C = obj.ChronuxControls;
if isempty(fieldnames(C)); return; end
amber = [0.55 0.33 0.00];
gray = [0.3 0.3 0.3];
if obj.ChronuxCacheFolder == ""
    obj.ChronuxCacheLabel.Text = "not set";
else
    obj.ChronuxCacheLabel.Text = obj.ChronuxCacheFolder;
end
C.eventText.Text = alignmentText(obj);
k = obj.ActiveIdx;
busy = ismember(obj.ChronuxState, ["computing" "creating"]);
if isempty(obj.Runner) || k < 1 || k > numel(obj.Runner.Outputs)
    setFile(obj, "Scan and pick a dataset.", gray);
    obj.ChronuxCreateButton.Enable = "off";
    obj.ChronuxOpenFolderButton.Enable = "off";
    obj.ChronuxIndex = [];
    obj.ChronuxFile = "";
    fillSignals(obj);
    syncCompute(obj, busy);
    return
end
out = obj.Runner.Outputs(k);
name = obj.Runner.Names(k);
hasExtract = out.has("extract");
[f, where] = obj.chronuxFileFor(k);
if f == ""
    obj.ChronuxIndex = [];
    obj.ChronuxFile = "";
    obj.ChronuxFileWhere = "";
    msg = "No Chronux file for " + name + ".";
    if hasExtract
        msg = msg + " Create it from the dataset's extract, sorted units and detections.";
    else
        msg = msg + " It has no extract either: run the pipeline's Signals step first.";
    end
    setFile(obj, msg, amber);
    obj.ChronuxCreateButton.Text = "Create Chronux file";
else
    d = dir(f);
    if isempty(obj.ChronuxIndex) || obj.ChronuxFile ~= f || isempty(d) || obj.ChronuxIndex.datenum ~= d.datenum
        obj.ChronuxIndex = [];
        obj.ChronuxResult = [];
        try
            obj.ChronuxIndex = loadChronuxExport(f);
        catch ME
            obj.ChronuxFile = f;
            obj.ChronuxFileWhere = where;
            setFile(obj, "Cannot read " + f + ": " + string(ME.message), amber);
        end
    end
    obj.ChronuxFile = f;
    obj.ChronuxFileWhere = where;
    I = obj.ChronuxIndex;
    if ~isempty(I)
        sigs = string(fieldnames(I.signals)).';
        if isempty(sigs); sigs = "none"; end
        if where == "cache"; place = "In the local cache"; else; place = "In the output folder"; end
        msg = sprintf("%s: %s\nMade %s; signals %s; %d sorted unit(s), %d detection channel(s).", place, f, ...
            I.created, strjoin(sigs, ", "), numel(I.sp), numel(I.spDetected));
        color = gray;
        newest = newestExtract(out);
        if newest > I.datenum
            msg = msg + newline + "Older than the dataset's extract: Recreate it.";
            color = amber;
        end
        setFile(obj, msg, color);
    end
    obj.ChronuxCreateButton.Text = "Recreate Chronux file";
end
obj.ChronuxCreateButton.Enable = matlab.lang.OnOffSwitchState(hasExtract && ~busy);
obj.ChronuxOpenFolderButton.Enable = matlab.lang.OnOffSwitchState(obj.ChronuxFile ~= "");
fillSignals(obj);
syncCompute(obj, busy);
obj.syncChronuxControls();
end


function setFile(obj, msg, color)
obj.ChronuxFileLabel.Text = msg;
obj.ChronuxFileLabel.FontColor = color;
obj.ChronuxFileLabel.Tooltip = msg;
end


function fillSignals(obj)
C = obj.ChronuxControls;
I = obj.ChronuxIndex;
if isempty(I) || isempty(fieldnames(I.signals))
    set(C.signal, 'Items', "(none)", 'ItemsData', "");
else
    sigs = string(fieldnames(I.signals)).';
    old = string(C.signal.Value);
    C.signal.Items = sigs;
    C.signal.ItemsData = sigs;
    if ismember(old, sigs)
        C.signal.Value = old;
    elseif ismember("LFP", sigs)
        C.signal.Value = "LFP";
    end
end
obj.onChronuxEdited("signal");
end


function syncCompute(obj, busy)
ok = ~isempty(obj.ChronuxIndex) && ~isempty(fieldnames(obj.ChronuxIndex.signals));
has = ChronuxDataset.hasChronux();
obj.ChronuxComputeButton.Enable = matlab.lang.OnOffSwitchState(ok && has && ~busy);
if ~has
    obj.ChronuxStatusLabel.Text = "The Chronux toolbox is not on the MATLAB path: add toolboxes/chronux " + ...
        "(addpath(genpath(...))) to compute.";
end
end


function t = newestExtract(out)
t = 0;
for f = reshape(string(out.ExtractFiles), 1, [])
    d = dir(f);
    if ~isempty(d); t = max(t, d(1).datenum); end
end
end


function s = alignmentText(obj)
D = obj.Config.Defaults;
s = eventRefLabel(D.EventRef);
sel = D.Selection;
if isfield(sel, 'filter') && string(sel.filter) ~= ""; s = s + "; trials: " + string(sel.filter); end
if isfield(sel, 'groupBy') && ~isempty(sel.groupBy); s = s + "; groups by " + strjoin(string(sel.groupBy), ", "); end
end
