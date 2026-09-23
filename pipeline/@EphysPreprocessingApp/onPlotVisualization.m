function onPlotVisualization(obj)
%onPlotVisualization  Load the active dataset into the Visualize tab and draw it.
%   Finds what the dataset has on disk (EphysDataset.outputs): the
%   recording when its files can be read, the Sorting .bin, the Signals
%   step's LFP / MUA / SPIKE / AUX (EphysTraceSource.forDataset), its
%   sorted units (readSortedUnits on the associated sort) and the Spikes
%   step's detected spikes (<Name>_spikes.mat). The Show box then offers
%   those signals, keeping the kind shown before when this dataset has it,
%   and the viewer draws the window in the Start / Window fields. Nothing
%   is read beyond that window: the signals are read a window at a time as
%   you move (EphysTraceViewer), so this is quick for any recording length.
%   A dataset that was loaded already keeps its view.
%
%   Runs when the tab opens or the active dataset changes while it is open
%   (onTabChanged, selectDataset), and from Reload data, which finds the
%   files again after a run has written new ones.
%
%   See also buildVisualizeTab, onVizControlsChanged, EphysTraceSource,
%   EphysTraceViewer.unitLayer, EphysTraceViewer.detectedLayer.

d = obj.currentDataset();
if isempty(d)
    uialert(obj.Fig, "Scan a project first.", "Visualize");
    return
end
same = ~isempty(obj.VizDataset) && isvalid(obj.VizDataset) && obj.VizDataset == d;

obj.VizPlotButton.Enable = "off";
restore = onCleanup(@() set(obj.VizPlotButton, "Enable", "on"));
dlg = uiprogressdlg(obj.Fig, "Title", "Visualize", "Indeterminate", "on", ...
    "Message", "Finding the processed files of " + d.Name + "...");
closer = onCleanup(@() delete(dlg));
notes = strings(1, 0);
try
    out = d.outputs();
    [sources, skipped] = EphysTraceSource.forDataset(d, Outputs=out);
    notes = [notes, skipped];

    units = [];
    if out.has("sorting")
        dlg.Message = "Reading the sorted units of " + d.Name + "...";
        try
            units = out.readUnits();
        catch ME
            notes(end+1) = "Sorted units not read: " + string(ME.message);
        end
    end
    detected = [];
    if out.has("spikes")
        dlg.Message = "Reading the detected spikes of " + d.Name + "...";
        try
            S = out.load("spikes", "detected");
            if isstruct(S.detected) && isfield(S.detected, 'ts')
                detected = S.detected;
            end
        catch ME
            notes(end+1) = "Detected spikes not read: " + string(ME.message);
        end
    end
catch ME
    uialert(obj.Fig, ME.message, "Visualize failed");
    obj.setStatus("Visualize failed: " + string(ME.message));
    return
end

layers = EphysTraceViewer.emptyLayers();
if ~isempty(units) && ~isempty(units.unitId)
    layers(end+1) = EphysTraceViewer.unitLayer(units);
end
if ~isempty(detected) && ~isempty(detected.ts)
    layers(end+1) = EphysTraceViewer.detectedLayer(detected);
end

obj.VizData = struct('sources', sources, 'units', units, 'detected', detected, ...
    'layers', layers, 'notes', notes);
obj.VizDataset = d;

% The Show box: this dataset's signals, then "None" when it has spikes.
names = cell(1, numel(sources));
kinds = cell(1, numel(sources));
for i = 1:numel(sources)
    names{i} = sourceItem(sources(i));
    kinds{i} = char(sourceKey(sources(i)));
end
if ~isempty(layers)
    names{end+1} = 'None (spikes only)';
    kinds{end+1} = 'none';
end
if isempty(kinds)
    names = {'(nothing to show)'};
    kinds = {'none'};
end
want = obj.VizSourceKind;
obj.VizSourceDropDown.Items = names;
obj.VizSourceDropDown.ItemsData = kinds;
if any(kinds == want)
    obj.VizSourceDropDown.Value = char(want);
else
    obj.VizSourceDropDown.Value = kinds{1};
end

v = obj.Viewer;
t0 = obj.VizStartField.Value;
w = obj.VizDurField.Value;
if same
    t0 = v.TStart;
    w = v.TWidth;
end
v.Duration = datasetDuration(d, sources, layers);
v.DefaultWidth = min(2, v.Duration);
obj.applyVizSettings("all");
v.setView(t0, w);
v.render();                       % now, not after RenderDelay

obj.syncVizDataset();
obj.updateVizArtStatus();
msg = sprintf("Visualize: %s, %d signal(s)", d.Name, numel(sources));
if ~isempty(units); msg = msg + sprintf(", %d units", numel(units.unitId)); end
if ~isempty(detected); msg = msg + ", detected spikes"; end
if ~isempty(notes); msg = msg + ". " + strjoin(notes, " "); end
obj.setStatus(msg, "Wheel zooms time, Ctrl+wheel scales the voltage, drag pans.");
end


function s = sourceItem(src)
%sourceItem  The Show box's text for a source.
s = sprintf('%s (%g Hz, %d ch)', src.Name, src.Fs, src.NumChannels);
end


function k = sourceKey(src)
%sourceKey  The kind shown, kept from one dataset to the next.
switch src.Kind
    case "recording", k = "recording";
    case "bin",       k = "bin";
    otherwise,        k = src.Name;          % LFP, MUA, SPIKE, AUX
end
end


function dur = datasetDuration(d, sources, layers)
%datasetDuration  The time axis: the longest signal, else the recording, else the last spike.
dur = max([0, arrayfun(@(s) s.Duration, sources)]);
if ~(dur > 0) && isfinite(d.Duration); dur = d.Duration; end
if ~(dur > 0)
    for L = layers
        if ~isempty(L.t); dur = max(dur, L.t(end)); end
    end
end
if ~(dur > 0); dur = 1; end
end
