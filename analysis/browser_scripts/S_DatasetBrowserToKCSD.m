%% DatasetBrowser to kCSD
% A post-processing script of the DatasetBrowser (or run by hand with B in the
% workspace): it estimates the current source density (CSD) of the browser's
% signal along each shank of the probe with kCSD-python (kernel CSD:
% Potworowski, Jakuczun, Łęski & Wójcik 2012, Neural Comput 24:541;
% https://github.com/Neuroinflab/kCSD-python), in either of two ways:
%
%   1. Epochs: "Keep single trials" ticked, Compute, with a signal (LFP as a
%      rule) as the data. Each dataset's epochs are averaged per group and
%      arranged along the probe (epochMatrixCSD: a laminar profile per
%      shank, or per column of a shank; depths in mm below the top channel),
%      and the kCSD of every group's evoked potential is estimated at once
%      (kcsdEstimate). -> csdEpochs, one element per profile, with
%        pots [nChan x nTime x nGroups] V, the evoked potentials
%        csd  [nX x nTime x nGroups] uA/mm^3 on the grid (positive = source);
%             [nX x nY x nTime x nGroups] for a 2-D layout (columns = "2d")
%        grid x (mm below the top channel) and, in 2-D, y
%        info lambd and R used, the cross-validation errors, potEst (the
%             potentials the estimate reproduces at the channels)
%   2. Whole sessions: "Load whole sessions" with a signal. Each session's
%      kept trials are cut in the browser's window around TrialOnset
%      (artifact-touching trials dropped), averaged per group and treated
%      the same (sessionDataCSD). -> csdSessions. A stretch of the whole
%      signal can be estimated too: kcsdEstimate(p.pos_mm, p.signal(:, i)).
%
% Either part runs when its data is there. kCSD fits the potentials with a
% field of basis sources of width R and a ridge lambda, both picked here by
% leave-one-electrode-out cross-validation over `rsPerSpacing` x the channel
% spacing and `lambdas` (kCSD's cross_validate); the estimate is read off
% kCSD's grid, finer than the channels. A Python with numpy, scipy and kcsd
% is needed (kcsdEstimate finds one: KCSD_PYTHON, MATLAB's pyenv, a
% miniconda3 base install, python on the PATH); kcsdPython / kcsdSource
% name one by hand. Units are kCSD's: mm, mV (converted here) and S/m.

if ~exist('B', 'var') || ~isa(B, 'DatasetBrowser')
    error('B is not a DatasetBrowser: run this from the browser (Post-processing script), or set B = DatasetBrowser.open(root) first.');
end
kcsdPython = "";                    % python.exe with kcsd ("" = found: KCSD_PYTHON, pyenv, miniconda3, PATH)
kcsdSource = "";                    % a kCSD-python checkout to import kcsd from when it is not installed, e.g. "c:\src\kCSD-python"
outDir = "";                        % a folder to save <dataset>_kcsd_*.mat in; "" keeps them in the workspace only
columns = "auto";                   % laminarColumns: "auto" (one 1-D profile per shank when its depths are distinct,
                                    % else per x column) | "separate" | "merged" | "2d" (KCSD2D over a shank's x and depth)
shanks = [];                        % the shanks to use ([] = all)
sessionAlign = "TrialOnset";        % whole sessions: the trial column the kept trials are cut around (digital clock)
sigma = 0.3;                        % S/m, the tissue's conductivity
rsPerSpacing = [1 2 3 4];           % basis widths R cross-validated, in channel spacings ([] = kCSD's R_init, 0.23 mm)
lambdas = [0 logspace(-8, -1, 15)]; % ridges cross-validated ([] = kCSD's own 1e-2 .. 1e-25 and 0)
crossValidate = true;               % false: R = rsPerSpacing(1) spacings, lambda = 0, no search
gdx = [];                           % mm, the grid step ([] = 1% of the span)
extMm = 0;                          % mm, how far the estimate extends past the end channels
plotGroup = [];                     % the group drawn in the detail figure ([] = the first with epochs)

estimate = @(P) kcsdOf(P, sigma, rsPerSpacing, lambdas, crossValidate, gdx, extMm, kcsdPython, kcsdSource);

%% 1. Epochs (R.epochs): the evoked potential of each group, per shank profile
R = B.Result;
csdEpochs = struct([]);
if ~isempty(R) && isfield(R, 'epochs') && ~isempty(R.epochs) && R.rowKind == "channel"
    P = epochMatrixCSD(R, Columns=columns, Shanks=shanks);
    csdEpochs = estimate(P);
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
    P = sessionDataCSD(S, Window=[win.pre win.post], Align=sessionAlign, Columns=columns, Shanks=shanks, ...
        Statistic=B.Settings.signal.statistic);
    csdSessions = estimate(P);
    fprintf('csdSessions: %d profile(s) of %d session(s), %d trial(s) in [%g %g] s around %s\n', numel(csdSessions), ...
        numel(S), sum(arrayfun(@(p) numel(p.trial), csdSessions)), win.pre, win.post, sessionAlign);
end

profiles = [num2cell(csdEpochs(:)); num2cell(csdSessions(:))];   % every profile, the epochs' first
if isempty(profiles)
    error(['Nothing to estimate: Compute a signal (LFP) with "Keep single trials" ticked (B.Result.epochs), ' ...
        'or "Load whole sessions" of a signal (B.Sessions).']);
end
for c = profiles.'
    p = c{1};
    fprintf('  %s shank %d: %d channels, %.3g mm apart, %d-D; R = %.3g mm, lambda = %.3g, %d sources, %.1f s; groups: %s\n', ...
        p.name, p.shank, numel(p.rows), p.h_mm, p.dim, p.info.R, p.info.lambd, p.info.nSources, p.info.seconds, ...
        strjoin(string(p.groupLabels(:).') + " (n = " + string(p.nEpochs(:).') + ")", ", "));
end

if outDir ~= ""
    saveProfiles(csdEpochs, outDir, "_kcsd_epochs.mat");
    saveProfiles(csdSessions, outDir, "_kcsd_session.mat");
end

%% Plots
% The first profile: the LFP of one group, its kCSD, the fit at the channels
% (measured against reproduced potentials) and the cross-validation error
% over lambda for each R; then the kCSD of every group of every profile of
% the first dataset, with the potentials overlaid. A 2-D layout is drawn
% averaged over x, with a map of the layout at the time of the largest |CSD|.
p = profiles{1};
g = plotGroup;
if isempty(g); g = find(p.nEpochs > 0, 1); end
hasCV = ~isempty(p.info.cv);
fig = figure('Name', sprintf('%s shank %d: kCSD (%s)', p.name, p.shank, string(p.groupLabels(g))), ...
    'Color', 'w', 'Position', [80 80 1250 420]);
tl = tiledlayout(fig, 1, 3 + hasCV + (p.dim == 2), 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);
drawDepthImage(ax, p.t, p.depth_mm, p.pots(:, :, g) * 1e6, 'LFP', '\muV', parula(256));
ax = nexttile(tl);
drawDepthImage(ax, p.t, p.grid.x, laminar(p.csd, p.dim, g), sprintf('kCSD (R = %.3g mm, lambda = %.2g)', p.info.R, p.info.lambd), ...
    '\muA/mm^3', blueWhiteRed(256));
overlayTraces(ax, p.t, p.depth_mm, p.pots(:, :, g), p.h_mm);
ax = nexttile(tl);
meas = p.pots(:, :, g) * 1e6; fit = p.info.potEst(:, :, g) * 1e6;
scale = 0.45 * p.h_mm / max(abs(meas(:)), [], 'omitnan');
hM = plot(ax, p.t, (p.depth_mm - scale * meas).', 'k'); hold(ax, 'on');
hF = plot(ax, p.t, (p.depth_mm - scale * fit).', 'r:', 'LineWidth', 1); hold(ax, 'off');
set(ax, 'YDir', 'reverse'); ylim(ax, [min(p.depth_mm) - p.h_mm, max(p.depth_mm) + p.h_mm]);
xlabel(ax, 'Time from the event (s)'); ylabel(ax, 'Depth below the top channel (mm)');
rFit = corrcoef(meas(:), fit(:), 'Rows', 'complete');
title(ax, sprintf('Fit at the channels (r = %.3f)', rFit(1, 2)));
legend(ax, [hM(1) hF(1)], {'measured', 'reproduced'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
if hasCV
    ax = nexttile(tl);
    cv = p.info.cv;
    l = cv.lambdas; l(l == 0) = min(l(l > 0)) / 10;      % lambda 0 drawn a decade below the smallest
    semilogx(ax, l, cv.errors.', '-o');
    legend(ax, "R = " + string(round(cv.Rs, 3)) + " mm", 'Location', 'best');
    xline(ax, max(p.info.lambd, min(l)), ':', 'HandleVisibility', 'off');
    grid(ax, 'on');
    xlabel(ax, '\lambda'); ylabel(ax, cv.criterion); title(ax, 'Cross-validation');
end
if p.dim == 2
    ax = nexttile(tl);
    X = p.csd(:, :, :, g);
    [~, iPeak] = max(max(abs(reshape(X, [], size(X, 3))), [], 1));
    imagesc(ax, p.grid.x, p.grid.y, squeeze(X(:, :, iPeak)).');
    set(ax, 'YDir', 'reverse'); axis(ax, 'equal'); axis(ax, 'tight');
    cl = max(abs(X(:))); if cl > 0; clim(ax, [-cl cl]); end
    colormap(ax, blueWhiteRed(256)); colorbar(ax);
    hold(ax, 'on'); plot(ax, p.pos_mm(:, 1), p.pos_mm(:, 2), 'k.'); hold(ax, 'off');
    xlabel(ax, 'x (mm)'); ylabel(ax, 'Depth (mm)'); title(ax, sprintf('Layout at t = %.3f s', p.t(iPeak)));
end
title(tl, sprintf('%s, shank %d, %s (n = %d): %s', p.name, p.shank, string(p.groupLabels(g)), p.nEpochs(g), p.cfg.data), ...
    'Interpreter', 'none');

own = profiles(cellfun(@(q) q.key == p.key, profiles));
nG = max(cellfun(@(q) numel(q.groupLabels), own));   % a session's groups are its own, a result's the union
fig = figure('Name', sprintf('%s: kCSD per group', p.name), 'Color', 'w', ...
    'Position', [120 120 300 * nG 360 * numel(own)]);
tl = tiledlayout(fig, numel(own), nG, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:numel(own)
    q = own{i};
    for g = 1:nG
        ax = nexttile(tl);
        if g > numel(q.groupLabels); axis(ax, 'off'); continue; end
        if q.nEpochs(g) == 0
            title(ax, string(q.groupLabels(g)) + ": no epochs"); axis(ax, 'off'); continue
        end
        drawDepthImage(ax, q.t, q.grid.x, laminar(q.csd, q.dim, g), ...
            sprintf('shank %d, %s (n = %d)', q.shank, string(q.groupLabels(g)), q.nEpochs(g)), '\muA/mm^3', blueWhiteRed(256));
        overlayTraces(ax, q.t, q.depth_mm, q.pots(:, :, g), q.h_mm);
    end
end
title(tl, sprintf('%s: kCSD of the %s, traces = the potentials', p.name, p.cfg.data), 'Interpreter', 'none');

%% Local functions
function P = kcsdOf(P, sigma, rsPerSpacing, lambdas, crossValidate, gdx, extMm, python, source)
% Add csd, grid and info (kcsdEstimate) to every laminar profile of P
if isempty(P); return; end
for i = 1:numel(P)
    p = P(i);
    args = {'Sigma', sigma, 'Python', python, 'Source', source};
    if ~isempty(gdx); args = [args {'Gdx', gdx}]; if p.dim == 2; args = [args {'Gdy', gdx}]; end; end %#ok<AGROW>
    if extMm > 0; args = [args {'ExtX', extMm}]; if p.dim == 2; args = [args {'ExtY', extMm}]; end; end %#ok<AGROW>
    Rs = rsPerSpacing * p.h_mm;
    if crossValidate
        if ~isempty(Rs); args = [args {'Rs', Rs}]; end %#ok<AGROW>
        if ~isempty(lambdas); args = [args {'Lambdas', lambdas}]; end %#ok<AGROW>
        args = [args {'CrossValidate', true}]; %#ok<AGROW>
    elseif ~isempty(Rs)
        args = [args {'RInit', Rs(1)}]; %#ok<AGROW>
    end
    % pos_mm: depths for a 1-D profile; x from the leftmost channel and depth for a 2-D layout
    [P(i).csd, P(i).grid, P(i).info] = kcsdEstimate(p.pos_mm, p.pots, args{:});
end
end

function X = laminar(csd, dim, g)
% The depth x time image of group g: a 2-D estimate averaged over x
if dim == 2
    X = squeeze(mean(csd(:, :, :, g), 1));     % [nY x nTime]
else
    X = csd(:, :, g);
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
