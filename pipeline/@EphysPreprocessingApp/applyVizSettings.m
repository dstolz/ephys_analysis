function applyVizSettings(obj, what)
%applyVizSettings  Hand the Visualize controls to the viewer (without drawing).
%   obj.applyVizSettings(WHAT) applies one group of controls to obj.Viewer
%   for the dataset loaded (VizDataset, VizData):
%     "source"      the signal in the Show box; then its channels and
%                   processing as well
%     "channels"    Channels (recording channels, "all" = every one), in
%                   probe order when "Order by probe" is ticked (the
%                   dataset's probe, else the config's default probe:
%                   by shank, top of the shank first, a dotted line between
%                   shanks), coloured by shank when asked; the units' and
%                   channels' own lanes follow the same order
%     "processing"  Reference, High-pass / Low-pass / Filter order, Remove offset
%     "spikes"      the Sorted units / Detected spikes layers: shown or
%                   not, ticks or waveforms, where they are drawn, which
%                   units by label; and the counts under them
%     "lanes", "mode", "shading"   lanes shown, traces / heatmap and its
%                   colours, the artifact periods shaded
%     "all"         everything
%   The caller draws (onVizControlsChanged, onPlotVisualization).
%
%   See also onVizControlsChanged, EphysTraceViewer, EphysDataset.channelLayout.

v = obj.Viewer;
D = obj.VizData;
d = obj.currentVizDataset();
if isempty(v) || ~isvalid(v) || isempty(D) || isempty(d); return; end
every = what == "all";

if every || what == "source"
    key = string(obj.VizSourceDropDown.Value);
    obj.VizSourceKind = key;
    src = [];
    for s = D.sources
        if sourceKey(s) == key; src = s; break; end
    end
    v.setSource(src);
    isRec = ~isempty(src) && src.Kind == "recording";
    obj.VizRefDropDown.Enable = matlab.lang.OnOffSwitchState(isRec);
    set([obj.VizHighpassField, obj.VizLowpassField, obj.VizOrderField, obj.VizOffsetCheckBox, ...
        obj.VizChannelsField, obj.VizSpacingField, obj.VizModeDropDown, obj.VizSortByProbeCheckBox, ...
        obj.VizColorByShankCheckBox], 'Enable', matlab.lang.OnOffSwitchState(~isempty(src)));
    if isempty(src)
        obj.VizSourceNoteLabel.Text = "Spikes only: one lane per unit or channel.";
    else
        obj.VizSourceNoteLabel.Text = sprintf("%s: %s, %.1f s.", src.Name, src.Note, src.Duration);
    end
end

if every
    v.setLayers(D.layers);          % a newly loaded dataset's spikes
end

if every || what == "source" || what == "processing"
    before = {v.Filter, v.Reference};
    src = v.Source;
    if ~isempty(src) && src.Kind == "recording"
        ref = string(obj.VizRefDropDown.Value);
        if ref == "pipeline"
            src.Reference = "pipeline";
        else
            src.Reference = "none";
        end
        v.Reference = "none";
        if ref == "car" || ref == "cmr"; v.Reference = ref; end
    else
        v.Reference = "none";
    end
    v.Filter = displayFilter(obj, src);
    v.RemoveOffset = logical(obj.VizOffsetCheckBox.Value);
    if what == "processing" && ~isequal(before, {v.Filter, v.Reference})
        v.autoScale();              % a filter changes the scale of the signal
    end
end

if every || what == "source" || what == "channels"
    [layout, ok] = probeLayout(obj, d);
    rank = [];
    if ok && logical(obj.VizSortByProbeCheckBox.Value)
        rank(layout.order) = 1:numel(layout.order);
    end
    src = v.Source;
    if ~isempty(src)
        cols = channelColumns(obj, src);
        rc = src.RecordingChannels(cols);
        shank = NaN(size(cols));
        onMap = isfinite(rc) & rc >= 1 & rc <= numel(layout.shank);
        shank(onMap) = layout.shank(rc(onMap));
        breaks = double.empty(1, 0);
        if ~isempty(rank)
            r = inf(size(cols));
            inRank = isfinite(rc) & rc >= 1 & rc <= numel(rank);
            r(inRank) = rank(rc(inRank));
            [~, o] = sortrows([r(:), (1:numel(cols)).']);
            cols = cols(o);
            shank = shank(o);
            breaks = find(~sameValue(shank(1:end-1), shank(2:end)));
        end
        colors = [];
        if ok && logical(obj.VizColorByShankCheckBox.Value)
            colors = shankColors(shank, layout.shanks);
        end
        v.setChannels(cols, colors, breaks);
    end
    % The spike layers' own lanes in the same order.
    for L = v.Layers
        chanRank = L.channels;
        if ~isempty(rank)
            inRank = isfinite(L.channels) & L.channels >= 1 & L.channels <= numel(rank);
            chanRank(~inRank) = Inf;
            chanRank(inRank) = rank(L.channels(inRank));
        end
        [~, order] = sortrows([chanRank(:), (1:numel(L.channels)).']);
        v.setLayerGroups(L.name, L.show, order(:).');
    end
end

if every || what == "spikes"
    placement = string(obj.VizPlacementDropDown.Value);
    txt = strings(1, 0);
    for L = v.Layers
        switch L.kind
            case "units"
                on = logical(obj.VizUnitsCheckBox.Value);
                style = string(obj.VizUnitStyleDropDown.Value);
                show = unitGroups(D.units, string(obj.VizUnitGroupsDropDown.Value));
                v.setLayerGroups(L.name, show);
                txt(end+1) = sprintf("%d of %d units, %s spikes", nnz(show), numel(show), ...
                    thousands(nnz(show(L.g)))); %#ok<AGROW>
            otherwise
                on = logical(obj.VizDetectedCheckBox.Value);
                style = string(obj.VizDetectedStyleDropDown.Value);
                txt(end+1) = sprintf("detected on %d channels, %s spikes", numel(L.labels), ...
                    thousands(numel(L.t))); %#ok<AGROW>
        end
        if ~on; style = "off"; end
        v.setLayerStyle(L.name, style, placement);
    end
    hasUnits = any(string({D.layers.kind}) == "units");
    hasDet = any(string({D.layers.kind}) == "detected");
    set([obj.VizUnitsCheckBox, obj.VizUnitStyleDropDown, obj.VizUnitGroupsDropDown], ...
        'Enable', matlab.lang.OnOffSwitchState(hasUnits));
    set([obj.VizDetectedCheckBox, obj.VizDetectedStyleDropDown], 'Enable', matlab.lang.OnOffSwitchState(hasDet));
    obj.VizPlacementDropDown.Enable = matlab.lang.OnOffSwitchState(hasUnits || hasDet);
    if ~hasUnits; txt = ["no sorted units", txt]; end
    if ~hasDet; txt(end+1) = "no detected spikes"; end
    obj.VizSpikesLabel.Text = strjoin(txt, "; ") + ".";
end

if every || what == "lanes"
    v.VisibleLanes = max(1, round(obj.VizLanesField.Value));
end

if every || what == "mode"
    v.Mode = string(obj.VizModeDropDown.Value);
    v.Colormap = string(obj.VizColormapDropDown.Value);
    obj.VizColormapDropDown.Enable = matlab.lang.OnOffSwitchState(v.Mode == "heatmap");
end

if every || what == "shading"
    obj.refreshVizShading(false);
end
end


function k = sourceKey(src)
switch src.Kind
    case "recording", k = "recording";
    case "bin",       k = "bin";
    otherwise,        k = src.Name;
end
end


function f = displayFilter(obj, src)
% The display filter from High-pass / Low-pass (blank = off), below Nyquist.
f = struct('type', "", 'cutoff', [], 'order', obj.VizOrderField.Value);
if isempty(src); return; end
hp = firstNumber(obj.VizHighpassField.Value);
lp = firstNumber(obj.VizLowpassField.Value);
nyq = src.Fs / 2;
if ~isempty(hp) && ~(hp > 0 && hp < nyq); hp = []; end
if ~isempty(lp) && ~(lp > 0 && lp < nyq); lp = []; end
if ~isempty(hp) && ~isempty(lp) && hp < lp
    f.type = "bandpass"; f.cutoff = [hp lp];
elseif ~isempty(lp)
    f.type = "lowpass"; f.cutoff = lp;
elseif ~isempty(hp)
    f.type = "highpass"; f.cutoff = hp;
end
end


function c = firstNumber(s)
c = [];
v = sscanf(char(string(s)), '%g');
if ~isempty(v); c = v(1); end
end


function cols = channelColumns(obj, src)
% Source columns for the Channels field: recording channels (columns
% without one, such as AUX inputs, are numbered by column); "all" or
% blank = every column.
txt = strtrim(string(obj.VizChannelsField.Value));
cols = 1:src.NumChannels;
if txt == "" || lower(txt) == "all"; return; end
try
    ch = EphysDataset.parseChannelList(txt);
catch
    return
end
rc = src.RecordingChannels;
if all(isnan(rc)); rc = 1:src.NumChannels; end
pick = zeros(1, 0);
for c = ch(:).'
    k = find(rc == c, 1);
    if ~isempty(k); pick(end+1) = k; end %#ok<AGROW>
end
if ~isempty(pick); cols = pick; end
end


function [L, ok] = probeLayout(obj, d)
% The dataset's channelLayout on its probe, else on the config's default probe.
pf = d.ProbeFile;
if pf == ""; pf = obj.Config.Probe.DefaultProbeFile; end
L = d.channelLayout(ProbeFile=pf);
ok = L.hasProbe;
end


function tf = sameValue(a, b)
tf = a == b | (isnan(a) & isnan(b));
end


function C = shankColors(shank, shanks)
% One colour per shank (as the Artifacts viewer), grey off the probe.
pal = [0.00 0.45 0.74; 0.13 0.55 0.13; 0.49 0.18 0.56; 0.00 0.60 0.60; ...
       0.35 0.35 0.35; 0.30 0.70 0.95; 0.47 0.67 0.19; 0.25 0.25 0.60];
C = repmat([0.55 0.55 0.55], numel(shank), 1);
[on, si] = ismember(shank, shanks);
C(on, :) = pal(mod(si(on) - 1, size(pal, 1)) + 1, :);
end


function show = unitGroups(units, pick)
% Which units the Units box keeps, by their label.
g = lower(string(units.group(:))).';
switch pick
    case "good",    show = g == "good";
    case "goodmua", show = g == "good" | g == "mua";
    otherwise,      show = true(1, numel(g));
end
end


function s = thousands(n)
% 1234567 -> "1,234,567".
s = string(regexprep(sprintf('%d', n), '(\d)(?=(\d{3})+$)', '$1,'));
end
