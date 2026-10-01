function applyArtMarkSettings(obj, what)
%applyArtMarkSettings  Hand the Mark manual periods controls to its viewer (without drawing).
%   obj.applyArtMarkSettings(WHAT) applies one group of controls to
%   obj.ArtMarkViewer, once a dataset is loaded into it (syncArtMark):
%     "processing"  the High-pass (blank = off); a new filter rescales
%     "channels"    the lane order: the probe's (by shank, top of the shank
%                   first, a dotted line between shanks) while "Order
%                   channels by probe layout" is ticked, else the recording's
%     "lanes"       lanes shown at once
%     "shading"     the detected and manual periods shaded
%     "all"         everything
%   The caller draws (syncArtMark, the controls' callbacks).
%
%   See also syncArtMark, refreshArtMarkShading, EphysTraceViewer.

v = obj.ArtMarkViewer;
d = obj.ArtMarkDataset;
if isempty(v) || ~isvalid(v) || isempty(d) || ~isvalid(d) || isempty(v.Source); return; end
every = what == "all";

if every || what == "processing"
    before = v.Filter;
    v.Filter = displayFilter(obj, v.Source.Fs);
    if what == "processing" && ~isequal(before, v.Filter)
        v.autoScale();              % a filter changes the scale of the signal
    end
end

if every || what == "channels"
    [cols, breaks] = laneOrder(obj, v.Source.NumChannels);
    v.setChannels(cols, [], breaks);
end

if every || what == "lanes"
    v.VisibleLanes = max(1, round(obj.ArtMarkLanesField.Value));
end

if every || what == "shading"
    obj.refreshArtMarkShading(false);
end
end


function f = displayFilter(obj, Fs)
% The display filter from High-pass (blank = off), below Nyquist.
f = struct('type', "", 'cutoff', [], 'order', 4);
hp = sscanf(char(string(obj.ArtMarkHighpassField.Value)), '%g');
if ~isempty(hp) && hp(1) > 0 && hp(1) < Fs / 2
    f.type = "highpass";
    f.cutoff = hp(1);
end
end


function [cols, breaks] = laneOrder(obj, n)
% Source columns in lane order, and the lanes a dotted line follows (shank changes).
cols = 1:n;
breaks = double.empty(1, 0);
L = obj.ArtView.layout;
if isempty(L) || ~L.hasProbe || numel(L.order) ~= n || numel(L.shank) ~= n ...
        || ~logical(obj.ArtProbeOrderCheckBox.Value)
    return
end
cols = reshape(L.order, 1, []);
shank = L.shank(cols);
same = shank(1:end-1) == shank(2:end) | (isnan(shank(1:end-1)) & isnan(shank(2:end)));
breaks = find(~same);
end
