%% DatasetBrowser to iCSD
% A post-processing script of the DatasetBrowser (or run by hand with B in the
% workspace): it estimates the current source density (CSD) of the browser's
% signal along each shank of the probe with the iCSD toolbox (Pettersen,
% Devor, Ulbert, Dale & Einevoll 2006, J Neurosci Methods 154:116; the
% CSDplotter methods as https://github.com/dstolz/iCSD packages them), in
% either of two ways:
%
%   1. Epochs: "Keep single trials" ticked, Compute, with a signal (LFP as a
%      rule) as the data. Each dataset's epochs are averaged per group and
%      arranged along the probe (epochMatrixCSD: a laminar profile per
%      shank, or per column of a shank; depths in mm below the top channel),
%      and the CSD of every group's evoked potential is estimated with each
%      of `opts.methods`. -> csdEpochs, one element per profile, with
%        pots [nChan x nTime x nGroups] V, the evoked potentials
%        csd.<method> [nZ x nTime x nGroups] uA/mm^3 (positive = source)
%        z.<method>   [nZ x 1] mm below the top channel
%   2. Whole sessions: "Load whole sessions" with a signal. Each session's
%      kept trials are cut in the browser's window around TrialOnset
%      (artifact-touching trials dropped), averaged per group and treated
%      the same (sessionDataCSD). -> csdSessions
%
% Either part runs when its data is there. The methods (icsdEstimate):
%   spline    cubic-spline iCSD, continuous between the channels, smoothed
%   delta     delta-source iCSD: a sheet at each channel, 3-point smoothed;
%             equal spacing needed
%   step      step iCSD: constant between channels; equal spacing needed
%   standard  the second spatial difference (Vaknin's end channels), smoothed
% The toolbox's parameters below are SI (m, S/m), as its functions take
% them. A single trial's CSD, when wanted: icsdEstimate(p.epochs(:, :, j),
% p.depth_mm, Method="spline") for profile p and epoch j.

if ~exist('B', 'var') || ~isa(B, 'DatasetBrowser')
    error('B is not a DatasetBrowser: run this from the browser (Post-processing script), or set B = DatasetBrowser.open(root) first.');
end
opts = struct();                    % the settings, noted whole in each dataset's manifest
opts.icsdPath = 'c:\src\iCSD';           % added (with its methods/ folder) when the toolbox is not on the path
opts.outDir = "";                        % a folder to save <dataset>_icsd_*.mat in; "" keeps them in the workspace only
opts.methods = ["spline" "delta" "step" "standard"];   % the methods estimated; the first is plotted per group
opts.columns = "auto";                   % laminarColumns: "auto" (one profile per shank when its depths are distinct,
                                         % else per x column) | "separate" | "merged"
opts.shanks = [];                        % the shanks to use ([] = all)
opts.sessionAlign = "TrialOnset";        % whole sessions: the trial column the kept trials are cut around (digital clock)
opts.cond = 0.3;                         % S/m, the tissue's conductivity
opts.condTop = [];                       % S/m, the medium above the surface ([] = cond: one layer)
opts.diam = 0.5e-3;                      % m, the active column's diameter (delta, step, spline)
opts.gaussSigma = 0.1e-3;                % m, the spatial smoothing of spline and step (0 = none)
opts.surfaceMm = [];                     % mm, the top channel's depth below the surface ([] = one spacing; two layers only)
opts.plotGroup = [];                     % the group whose CSD every method is drawn for ([] = the first with epochs)

if ~exist('iCSD_spline', 'file') && isfolder(opts.icsdPath); addpath(genpath(opts.icsdPath)); end
if ~exist('iCSD_spline', 'file')
    error('The iCSD toolbox is not on the path: set opts.icsdPath to its folder (it holds iCSD_spline.m and methods/).');
end
estimate = @(pots, depth, method) icsdEstimate(pots, depth, Method=method, Cond=opts.cond, CondTop=opts.condTop, ...
    Diam=opts.diam, GaussSigma=opts.gaussSigma, Surface=opts.surfaceMm);

%% 1. Epochs (R.epochs): the evoked potential of each group, per shank profile
R = B.Result;
csdEpochs = struct([]);
if ~isempty(R) && isfield(R, 'epochs') && ~isempty(R.epochs) && R.rowKind == "channel"
    P = epochMatrixCSD(R, Columns=opts.columns, Shanks=opts.shanks);
    csdEpochs = csdOfProfiles(P, opts.methods, estimate);
    fprintf('csdEpochs: %d profile(s) of %d dataset(s), %s\n', numel(csdEpochs), numel(unique([csdEpochs.key])), R.labels.description);
end

%% 2. Whole sessions (B.Sessions): the kept trials in the browser's window
S = B.Sessions;
csdSessions = struct([]);
win = B.Settings.window;
if ~isempty(S)
    S = S(arrayfun(@(D) ~isempty(D.signal), S));   % spikes or "Load trials only" bring no signal
end
if ~isempty(S)
    P = sessionDataCSD(S, Window=[win.pre win.post], Align=opts.sessionAlign, Columns=opts.columns, Shanks=opts.shanks, ...
        Statistic=B.Settings.signal.statistic);
    csdSessions = csdOfProfiles(P, opts.methods, estimate);
    fprintf('csdSessions: %d profile(s) of %d session(s), %d trial(s) in [%g %g] s around %s\n', numel(csdSessions), ...
        numel(S), sum(arrayfun(@(p) numel(p.trial), csdSessions)), win.pre, win.post, opts.sessionAlign);
end

profiles = [num2cell(csdEpochs(:)); num2cell(csdSessions(:))];   % every profile, the epochs' first
if isempty(profiles)
    error(['Nothing to estimate: Compute a signal (LFP) with "Keep single trials" ticked (B.Result.epochs), ' ...
        'or "Load whole sessions" of a signal (B.Sessions).']);
end
for c = profiles.'
    p = c{1};
    spacing = ''; if ~p.uniform; spacing = ' (unequal)'; end
    fprintf('  %s shank %d: %d channels, %.3g mm apart%s; groups: %s\n', p.name, p.shank, numel(p.rows), ...
        p.h_mm, spacing, strjoin(string(p.groupLabels(:).') + " (n = " + string(p.nEpochs(:).') + ")", ", "));
end

if opts.outDir ~= ""
    saveProfiles(csdEpochs, opts.outDir, "_icsd_epochs.mat");
    saveProfiles(csdSessions, opts.outDir, "_icsd_session.mat");
end

% note it in each dataset's manifest (custom.browser_icsd)
for key = unique(cellfun(@(c) string(c.key), profiles)).'
    B.noteInManifest(key, "icsd", opts, epochs=any([csdEpochs.key] == key), sessions=any([csdSessions.key] == key));
end

%% Plots
% The first profile: the LFP of one group and its CSD by every method, as
% CSDplotter shows them (depth down; positive CSD is a source, red, and a
% sink is blue); then the first method for every group of every profile of
% the first dataset, with the LFP traces overlaid.
p = profiles{1};
g = opts.plotGroup;
if isempty(g); g = find(p.nEpochs > 0, 1); end
fig = figure('Name', sprintf('%s shank %d: iCSD methods (%s)', p.name, p.shank, string(p.groupLabels(g))), ...
    'Color', 'w', 'Position', [80 80 300 * (numel(opts.methods) + 1) 420]);
tl = tiledlayout(fig, 1, numel(opts.methods) + 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);
drawDepthImage(ax, p.t, p.depth_mm, p.pots(:, :, g) * 1e6, 'LFP', '\muV', parula(256));
for m = opts.methods
    if ~isfield(p.csd, m); continue; end
    ax = nexttile(tl);
    drawDepthImage(ax, p.t, p.z.(m), p.csd.(m)(:, :, g), m + " iCSD", '\muA/mm^3', blueWhiteRed(256));
end
title(tl, sprintf('%s, shank %d, %s (n = %d): %s', p.name, p.shank, string(p.groupLabels(g)), p.nEpochs(g), p.cfg.data), ...
    'Interpreter', 'none');

m = opts.methods(1);
own = profiles(cellfun(@(q) q.key == p.key, profiles));
nG = max(cellfun(@(q) numel(q.groupLabels), own));   % a session's groups are its own, a result's the union
fig = figure('Name', sprintf('%s: %s iCSD per group', p.name, m), 'Color', 'w', ...
    'Position', [120 120 300 * nG 360 * numel(own)]);
tl = tiledlayout(fig, numel(own), nG, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:numel(own)
    q = own{i};
    for g = 1:nG
        ax = nexttile(tl);
        if g > numel(q.groupLabels); axis(ax, 'off'); continue; end
        if q.nEpochs(g) == 0 || ~isfield(q.csd, m)
            title(ax, string(q.groupLabels(g)) + ": nothing to draw"); axis(ax, 'off'); continue
        end
        drawDepthImage(ax, q.t, q.z.(m), q.csd.(m)(:, :, g), ...
            sprintf('shank %d, %s (n = %d)', q.shank, string(q.groupLabels(g)), q.nEpochs(g)), '\muA/mm^3', blueWhiteRed(256));
        overlayTraces(ax, q.t, q.depth_mm, q.pots(:, :, g), q.h_mm);
    end
end
title(tl, sprintf('%s: %s iCSD of the %s, traces = the potentials', p.name, m, p.cfg.data), 'Interpreter', 'none');

%% Local functions
function P = csdOfProfiles(P, methods, estimate)
% Add csd.<method>, z.<method> and info.<method> to every laminar profile of P
if isempty(P); return; end
for i = 1:numel(P)
    P(i).csd = struct(); P(i).z = struct(); P(i).info = struct();
    for m = methods
        if any(m == ["step" "delta"]) && ~P(i).uniform
            warning('S_DatasetBrowserToICSD:NotUniform', '%s shank %d: unequal spacing, the %s iCSD is skipped.', P(i).name, P(i).shank, m);
            continue
        end
        [P(i).csd.(m), P(i).z.(m), P(i).info.(m)] = estimate(P(i).pots, P(i).depth_mm, m);
    end
end
end

function saveProfiles(P, outDir, suffix)
% One file per dataset holding its profiles, without the whole session's signal
if isempty(P); return; end
for key = unique([P.key])
    profiles = P([P.key] == key);
    if isfield(profiles, 'signal'); profiles = rmfield(profiles, 'signal'); end
    save(fullfile(outDir, profiles(1).name + suffix), 'profiles', '-v7.3');
end
end

function drawDepthImage(ax, t, z, X, name, unitText, cmap)
imagesc(ax, t, z, X);
set(ax, 'YDir', 'reverse');
cl = max(abs(X(:)), [], 'omitnan');
if isfinite(cl) && cl > 0; clim(ax, [-cl cl]); end
colormap(ax, cmap);
cb = colorbar(ax); cb.Label.String = unitText;
xline(ax, 0, 'k--');
xlabel(ax, 'Time from the event (s)'); ylabel(ax, 'Depth below the top channel (mm)');
title(ax, name, 'Interpreter', 'none');
end

function overlayTraces(ax, t, depth, pots, h)
% The channels' potentials as lines at their depths, 0.45 spacings tall at most
scale = 0.45 * h / max(abs(pots(:)), [], 'omitnan');
if ~isfinite(scale); return; end
hold(ax, 'on');
plot(ax, t, (depth - scale * pots).', 'k', 'LineWidth', 0.5);
hold(ax, 'off');
ylim(ax, [min(depth) - h, max(depth) + h]);
end
