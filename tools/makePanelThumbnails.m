function files = makePanelThumbnails(opts)
%makePanelThumbnails  Draw the New panel window's pictures: a small representative plot of each figure panel type.
%   FILES = makePanelThumbnails() draws one figure per panel type
%   (EphysAnalysisConfig.panelTypes, each from its template:
%   addFigure(<type>)) for the first observation of a small synthetic
%   dataset, with the real compute and draw functions
%   (EphysAnalysisRunner.computeFigure, renderFigure), strips every text
%   (titles, labels, tick labels, legends, notes) so only the data and the
%   axes are left, scales it down and writes
%   analysis/icons/panels/<type>.png, which the analysis app's New panel
%   window (EphysAnalysisApp, private/newPanelDialog) shows on each type's
%   tile; a type without a picture gets a drawn placeholder there. FILES
%   lists the files written. Run it again after a draw function's look
%   changes, or when a panel type is added, and commit the PNGs.
%
%   The dataset: makeSyntheticProject(Preset="small", Scenarios="clean",
%   NumTrials=12) in a temporary folder, run through the pipeline's
%   Behavior, Signals (LFP, MUA, AUX) and Spikes steps (the sorted units
%   are the ground-truth sorting); aligned to Stim onset, -0.2 to 0.8 s,
%   grouped by TrialType. The spectral types need Chronux: toolboxes/chronux
%   is put on the path. Takes about a minute or two.
%     matlab -batch "addpath('C:\src\ephys_analysis\tools'); makePanelThumbnails()"
%
%   Options
%     Folder  where the PNGs go (default: analysis/icons/panels of this
%             repository)
%     Size    [width height] in px (default [112 84])
%     Types   the panel types drawn (default: every one)
%
%   Toolboxes: Image Processing (imresize).
%
%   See also EphysAnalysisConfig.panelTypes, renderFigure, makeSyntheticProject.

arguments
    opts.Folder (1,1) string = fullfile(fileparts(fileparts(mfilename("fullpath"))), "analysis", "icons", "panels")
    opts.Size (1,2) double {mustBePositive} = [112 84]
    opts.Types (1,:) string = reshape(EphysAnalysisConfig.panelTypes().Type, 1, [])
end

repo = fileparts(fileparts(mfilename("fullpath")));
for sub = ["pipeline" "analysis"]
    if ~contains(path, fullfile(repo, sub)); addpath(fullfile(repo, sub)); end
end
if exist('mtspectrumc', 'file') ~= 2
    addpath(genpath(fullfile(repo, 'toolboxes', 'chronux')));
end
if ~isfolder(opts.Folder); mkdir(opts.Folder); end

% a small synthetic project, run through the pipeline (no sorting: the ground-truth sorting folder)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeRoot(root));
proj = fullfile(root, "proj");
S = makeSyntheticProject(proj, Preset="small", Scenarios="clean", NumTrials=12, Seed=1);
P = EphysProject(proj);
P.refresh();
pcfg = EphysPipelineConfig.load(S.configFile);
pcfg.Behavior.AutoApprove = true;
pcfg.Sorting.Enabled = false;
pcfg.Artifacts.Enabled = false;
pcfg.Export.Enabled = false;
pcfg.Signals.Enabled = true;
pcfg.Signals.LFP = true; pcfg.Signals.MUA = true; pcfg.Signals.SPIKE = false; pcfg.Signals.AUX = true;
pcfg.Spikes.Enabled = true;
pipe = EphysPipeline(pcfg, Project=P, Refresh=false);
pipe.LogFcn = [];
pipe.run();

cfg = EphysAnalysisConfig();
cfg.Source.Root = proj;
cfg.Defaults.EventRef.line = "Stim";
cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
cfg.Defaults.Selection.groupBy = "TrialType";
for t = opts.Types
    cfg = cfg.addFigure(t, Id=t);
end
runner = EphysAnalysisRunner(cfg, LogFcn=[]);
src = runner.source(1);
ws = [warning('off', 'unitWaveforms:Templates') warning('off', 'unitWaveforms:NoWaveforms')];
restoreWarnings = onCleanup(@() warning(ws));

files = strings(1, 0);
W = opts.Size(1);
H = opts.Size(2);
for t = opts.Types
    spec = cfg.figureFor(t);
    T = figureObservations(src, spec);
    if height(T) == 0
        warning('makePanelThumbnails:NoObservation', 'No observation of a %s figure on the fixture: skipped.', t);
        continue
    end
    F = runner.computeFigure(src, spec, Observation=T(1, :));
    f = figure('Visible', 'off', 'Units', 'pixels', 'Position', [50 50 4 * W 4 * H], 'Color', 'w');
    closeIt = onCleanup(@() delete(f));
    renderFigure(F, spec, f, Editable=false, DataTips=false);
    drawnow;
    bare(f);
    tmp = tempname + ".png";
    exportgraphics(f, tmp, 'Resolution', 96, 'BackgroundColor', 'white');
    img = imread(tmp);
    delete(tmp);
    img = fitInto(img, W, H);
    out = fullfile(opts.Folder, t + ".png");
    imwrite(img, out);
    files(end+1) = out; %#ok<AGROW>
    clear closeIt
    fprintf('%s\n', out);
end
end


function bare(f)
%bare  Strip a drawn figure to its data: no text (titles, labels, notes), no tick labels, no legend or colorbar.
set(findall(f, 'Type', 'text'), 'Visible', 'off');
delete(findall(f, 'Type', 'legend'));
delete(findall(f, 'Type', 'colorbar'));
for ax = reshape(findall(f, 'Type', 'axes'), 1, [])
    ax.XTickLabel = {};
    ax.YTickLabel = {};
    ax.Title.Visible = 'off';
    ax.Subtitle.Visible = 'off';
    ax.XLabel.Visible = 'off';
    ax.YLabel.Visible = 'off';
    if numel(ax.YAxis) > 1   % yyaxis: the right axis too
        ax.YAxis(2).TickLabels = {};
        ax.YAxis(2).Label.Visible = 'off';
    end
end
set(findall(f, 'Type', 'subplottext'), 'Visible', 'off');
drawnow;
end


function out = fitInto(img, W, H)
%fitInto  IMG scaled to fit W x H px, its aspect kept, centered on white.
img = im2double(img);
s = min(W / size(img, 2), H / size(img, 1));
img = imresize(img, max(1, round(s * [size(img, 1) size(img, 2)])), 'bicubic');
img = min(max(img, 0), 1);
out = ones(H, W, 3);
r = floor((H - size(img, 1)) / 2) + (1:size(img, 1));
c = floor((W - size(img, 2)) / 2) + (1:size(img, 2));
out(r, c, :) = img(:, :, 1:3);
out = im2uint8(out);
end


function removeRoot(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
