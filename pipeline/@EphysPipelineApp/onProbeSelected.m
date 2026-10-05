function onProbeSelected(obj)
%onProbeSelected  Show probe metadata, whether Kilosort4 can read the probe
%   (probeMapProblems) and the simple channel-count check.

pf = obj.selectedProbeFile();
if pf == "" || ~isfile(pf)
    obj.ProbeInfoLabel.Text = "Select a probe.";
    obj.ProbeCheckLabel.Text = "";
    cla(obj.ProbePreviewAxes);
    return
end

[nProbe, info] = probeChannelCount(pf);
problems = probeMapProblems(pf);

% Compare against the active dataset.
d = obj.currentDataset();
exclude = double.empty(1,0);
if ~isempty(d); exclude = EphysDataset.parseChannelList(d.ExcludeChannels); end

showNumbers = ~isempty(obj.ShowChanNumbersCheckBox) ...
    && isvalid(obj.ShowChanNumbersCheckBox) ...
    && logical(obj.ShowChanNumbersCheckBox.Value);
plotProbeArrangement(obj.ProbePreviewAxes, pf, exclude, showNumbers);
[~, pn, pe] = fileparts(pf);
ks4File = EphysPipelineConfig.ks4ParamsFile(pf);
[~, kn, ke] = fileparts(ks4File);
if isfile(ks4File)
    ks4Txt = "Kilosort4 parameters: " + kn + ke;
else
    ks4Txt = "Kilosort4 parameters: no " + kn + ke + " yet (Sorting tab > Optimize for probe offers to generate it)";
end
obj.ProbeInfoLabel.Text = sprintf("%s%s\nn_chan: %s\n%s\n%s", pn, pe, ...
    num2str(nProbe), info, ks4Txt);

% A probe Kilosort4 could not read: say why, in place of the count check
% (runKilosort refuses it with the same reasons).
if ~isempty(problems)
    obj.ProbeCheckLabel.Text = "Kilosort4 cannot read this probe: " + strjoin(problems, "; ");
    obj.ProbeCheckLabel.FontColor = [0.8 0 0];
    return
end

if isempty(d) || isnan(d.NumChannels)
    obj.ProbeCheckLabel.Text = "Scan a project to check the channel count against a dataset.";
    obj.ProbeCheckLabel.FontColor = [0.4 0.4 0.4];
    return
end

% Excluded channels are dropped from the probe at run time; report how many
% sites Kilosort will actually sort.
exTxt = "";
if ~isempty(exclude)
    exTxt = sprintf(" | %d excluded -> %d sorted", ...
        numel(exclude), d.NumChannels - numel(exclude));
end

if isnan(nProbe)
    obj.ProbeCheckLabel.Text = "Could not read channel count from probe JSON." + exTxt;
    obj.ProbeCheckLabel.FontColor = [0.85 0.5 0];
elseif nProbe == d.NumChannels
    obj.ProbeCheckLabel.Text = sprintf("OK: probe %d ch matches '%s' (%d ch)%s.", ...
        nProbe, d.Name, d.NumChannels, exTxt);
    obj.ProbeCheckLabel.FontColor = [0 0.5 0];
else
    obj.ProbeCheckLabel.Text = sprintf("MISMATCH: probe %d ch vs '%s' %d ch%s.", ...
        nProbe, d.Name, d.NumChannels, exTxt);
    obj.ProbeCheckLabel.FontColor = [0.8 0 0];
end
end


function [n, info] = probeChannelCount(pf)
%probeChannelCount  Return n_chan (else numel(chanMap)) and a short summary.
n = NaN;
try
    probe = jsondecode(fileread(pf));
catch ME
    info = "invalid JSON: " + string(ME.message);
    return
end
% A chanMap can never have more sites than total channels, so an n_chan that
% is missing or smaller than numel(chanMap) (e.g. written from a 0-based map's
% max index) is bogus -- fall back to the map length.
nMap = NaN;
if isfield(probe, 'chanMap'); nMap = numel(probe.chanMap); end
if isfield(probe, 'n_chan');  n = double(probe.n_chan);     end
if ~isnan(nMap); n = max([n, nMap], [], 'omitnan'); end
parts = strings(0,1);
if isfield(probe, 'chanMap'); parts(end+1) = "chanMap: " + numel(probe.chanMap); end
if isfield(probe, 'kcoords')
    parts(end+1) = "shanks: " + numel(unique(probe.kcoords));
end
info = strjoin(parts, "  |  ");
end


function plotProbeArrangement(ax, pf, exclude, showNumbers)
%plotProbeArrangement  Scatter the probe sites (xc/yc), colored by shank.
%   EXCLUDE (1-based .bin channels) marks dropped sites with a gray X.
%   SHOWNUMBERS (default false) labels each site with its 1-based .bin channel.
if nargin < 3; exclude = double.empty(1,0); end
if nargin < 4; showNumbers = false; end
cla(ax);
try
    probe = jsondecode(fileread(pf));
catch
    title(ax, "Channel arrangement (unreadable)");
    return
end
if ~isfield(probe, 'xc') || ~isfield(probe, 'yc') ...
        || isempty(probe.xc) || isempty(probe.yc)
    title(ax, "Channel arrangement (no xc/yc)");
    return
end

xc = double(probe.xc(:));
yc = double(probe.yc(:));
n  = min(numel(xc), numel(yc));
xc = xc(1:n); yc = yc(1:n);

if isfield(probe, 'kcoords') && numel(probe.kcoords) >= n
    kcoords = double(probe.kcoords(1:n));
else
    kcoords = zeros(n, 1);
end

% Map each site to its 1-based .bin channel (chanMap value + 1; identity if
% no chanMap) so the excluded set can be highlighted.
if isfield(probe, 'chanMap') && numel(probe.chanMap) >= n
    binCh = double(probe.chanMap(1:n)) + 1;
else
    binCh = (1:n).';
end
isExcl = ismember(binCh, exclude(:));

hold(ax, "on");
shanks = unique(kcoords);
cmap = lines(max(numel(shanks), 1));
for s = 1:numel(shanks)
    m = kcoords == shanks(s) & ~isExcl;
    if ~any(m); continue; end
    h = scatter(ax, xc(m), yc(m), 44, cmap(s,:), "filled", ...
        "MarkerEdgeColor", [0.15 0.15 0.15], ...
        "DisplayName", sprintf("shank %g", shanks(s)));
    addSiteDataTips(h, binCh(m), shanks(s));
end
if any(isExcl)
    h = scatter(ax, xc(isExcl), yc(isExcl), 60, [0.5 0.5 0.5], "x", ...
        "LineWidth", 1.8, "DisplayName", "excluded");
    addSiteDataTips(h, binCh(isExcl), kcoords(isExcl));
end

% Optional per-site channel-number labels (1-based .bin channel). Sites sit in
% staggered columns 10-20 um apart, so labels go outward -- the left column of
% a shank labels to the left, the right column to the right -- which keeps
% neighbours in one column from overprinting each other.
if showNumbers
    dx = 0.025 * max(max(xc) - min(xc), 1);
    left = false(n, 1);
    for s = 1:numel(shanks)
        m = kcoords == shanks(s);
        xr = [min(xc(m)) max(xc(m))];
        if diff(xr) > 1
            left(m) = xc(m) < mean(xr);
        end
    end
    txtColor = [0.05 0.05 0.05];
    txtColor = repmat(txtColor, n, 1);
    txtColor(isExcl, :) = 0.45;
    for side = [true false]
        m = left == side;
        if ~any(m); continue; end
        if side
            ha = "right"; sgn = -1;
        else
            ha = "left"; sgn = 1;
        end
        t = text(ax, xc(m) + sgn*dx, yc(m), string(binCh(m)), ...
            "FontSize", 10, "FontWeight", "bold", "Clipping", "on", ...
            "HorizontalAlignment", ha, "VerticalAlignment", "middle");
        set(t, {"Color"}, num2cell(txtColor(m, :), 2));
    end
end
hold(ax, "off");

% Pad the limits so the outermost markers and their labels are not clipped.
padX = max(0.10 * max(range(xc), 1), 15);
padY = max(0.04 * max(range(yc), 1), 15);
axis(ax, "equal");
xlim(ax, [min(xc) - padX, max(xc) + padX]);
ylim(ax, [min(yc) - padY, max(yc) + padY]);
box(ax, "on");
grid(ax, "on");
ax.GridAlpha = 0.25;
ax.FontSize = 11;
title(ax, sprintf("Channel arrangement (%d sites, %d excluded)", n, nnz(isExcl)));
xlabel(ax, "x (\mum)");
ylabel(ax, "y (\mum)");
if numel(shanks) > 1 || any(isExcl)
    % Below the plot: a side legend eats the width the x axis needs.
    lg = legend(ax, "Location", "southoutside", "Orientation", "horizontal");
    lg.NumColumns = min(numel(shanks) + any(isExcl), 5);
    lg.FontSize = 10;
end
end


function addSiteDataTips(h, binCh, shank)
%addSiteDataTips  Hover text for a site scatter: recording channel and shank.
try
    h.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow("channel", binCh);
    h.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow("shank", shank(:) + zeros(size(binCh)));
catch
end
end
