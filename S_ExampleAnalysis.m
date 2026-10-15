%% S_ExampleAnalysis  A walkthrough of ephys_analysis from a script, on synthetic data.
%   Runs from top to bottom on any machine with MATLAB and the Signal
%   Processing Toolbox. No recording, no Python and no GPU are needed: it
%   writes a small synthetic project (Intan files, Epsych2 sessions, a probe
%   map and ground-truth sorted units) to a temporary folder, runs the
%   pipeline on it, and looks at what came out. Run it a section at a time
%   (Ctrl+Enter) to see each step.
%
%   Sections
%     1  a synthetic project, and the project / dataset objects
%     2  one recording: metadata, the probe, the noise
%     3  the pipeline: plan and run (behavior, signals, spikes, export)
%     4  the outputs: what was written, and loading it back
%     5  sorted units: quality metrics and good-unit criteria
%     6  quick-look analysis: epochs, a PSTH, figures, response statistics
%     7  a population summary over every unit
%   The response tests (6, 7) need the Statistics and Machine Learning
%   Toolbox; without it, the rest still runs.
%
%   See also makeSyntheticProject, EphysProject, EphysDataset, EphysPipeline,
%   DatasetOutputs, unitQualityPass, epochTable, spikePSTH, figureCompute,
%   renderFigure, responseStats, populationAnalysis.

%% 1. A synthetic project
here = fileparts(mfilename('fullpath'));
addpath_nogit(here);                      % pipeline/, analysis/ and vendor/, without .git

root = fullfile(tempdir, "ephys_walkthrough");
S = makeSyntheticProject(root, Preset="small", Scenarios=["clean" "late-start"], NumTrials=24, Overwrite=true);
fprintf('Synthetic project in %s: %d recording(s), config %s\n', root, numel(S.datasets), S.configFile);

P = EphysProject(root);                   % scans the folder for recordings
P.refresh();
disp(P.gatherMetadata());                 % one row per recording: channels, rate, duration, probe, ...

% The late-start recording began during trial 3, so its session has trials
% the recording lacks. The Trials tab is where you would review that; here
% the generator's own cuts are approved, as a reviewer would.
for T = S.datasets
    c = T.expectedCuts;
    if any(c.trials) || any(c.intervals)
        d = P.dataset(T.name);
        d.setTrialPairing(d.pairTrials(Cuts=c, Warn=false), "approved");
    end
end

%% 2. One recording
ds = P.Datasets(1);
fprintf('%s: %d channels at %g Hz, %.1f s, probe %s\n', ds.Name, ds.NumChannels, ds.Fs, ds.Duration, ds.ProbeFile);
L = ds.channelLayout();                   % where each channel sits on the probe
disp(table((1:numel(L.x)).', L.shank(:), L.x(:), L.y(:), 'VariableNames', {'channel', 'shank', 'x_um', 'y_um'}));
nl = ds.noiseLevels(Filter=true, FilterType="highpass", FilterCutoff=300, MaxChunks=4);
fprintf('Spike-band noise (robust SD) per channel, uV: %s\n', mat2str(round(nl.sigma, 1)));

%% 3. The pipeline: plan, then run
cfg = EphysPipelineConfig.load(S.configFile);
cfg.Behavior.AutoApprove = true;          % approve trial pairings that need no cuts
cfg.Sorting.Enabled = false;              % Kilosort4 needs Python; the project has ground-truth units
pipe = EphysPipeline(cfg, Project=P, Refresh=false);
disp(pipe.plan());                        % what each step would do, per dataset
R = pipe.run();                           % runs the enabled steps; one row per step and dataset
disp(R(:, {'Step', 'Dataset', 'Status', 'Message'}));

%% 4. The outputs
out = ds.outputs();                       % finds every file the pipeline wrote for this dataset
disp(out.inventory());
lfp = out.LFP;                            % the LFP extract: lfp.Y.LFP [samples x channels], uV
fprintf('LFP: %d samples x %d channels at %g Hz\n', size(lfp.Y.LFP, 1), size(lfp.Y.LFP, 2), lfp.info.LFP.Fs);
spk = out.Spikes;                         % threshold detections: spk.detected.ts{channel} (s)
fprintf('Detected spikes per channel: %s\n', mat2str(cellfun(@numel, spk.detected.ts)));

%% 5. Sorted units and their quality
[U, info] = ds.readSortedUnits();         % the ground-truth sort, read as Kilosort4 / phy output
U = ds.unitQuality(U, info);              % SpikeInterface's metrics, cached in the sort folder
[pass, why] = unitQualityPass(U, unitQualityCriteria());
T = unitTable(U, Times=false);
T.qualityPass = pass;
T.qualityFails = why;
disp(T(:, {'label', 'class', 'nSpikes', 'firingRate', 'isiViolationsRatio', 'presenceRatio', 'snr', 'qualityPass'}));

%% 6. Quick-look analysis: epochs around each stimulus, a PSTH, figures, response tests
src = loadAnalysisSource(out);            % events, trials and probe, without loading signals
E = epochTable(src, eventRef(line="Stim"), Window=epochWindow(pre=-0.2, post=0.5));
[st, meta] = selectUnits(src, struct('classes', ["su" "mua"]));
Rp = spikePSTH(st, E, Window=[-0.2 0.5], BinSec=0.01, SmoothSec=0.01, Meta=meta);   % the numbers: Rp.rate [bins x units x groups]

% A figure says what to draw for one observation (a unit, a channel or the
% dataset); figureCompute computes it and renderFigure draws it.
fcfg = EphysAnalysisConfig();
fcfg.Defaults.EventRef.line = "Stim";
fcfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.5, 'stop', []);
fcfg = fcfg.addFigure("rasterPsth", Id="unit_card");   % a unit's raster over its PSTH
spec = fcfg.figureFor("unit_card");
obs = figureObservations(src, spec);      % one row per unit the figure is drawn for
F = figureCompute(src, spec, Observation=obs(1, :));
fig = figure('Name', 'Raster and PSTH of one unit');
renderFigure(F, spec, fig);

meanFig = struct('panels', {{struct('type', "psth", 'layers', struct('source', "units", 'binding', "fixed", ...
    'units', struct('classes', ["su" "mua"]), 'aggregate', "mean"))}});
fcfg = fcfg.addFigure(meanFig, Id="mean_psth");   % one PSTH: the mean over the units, drawn for the dataset
specMean = fcfg.figureFor("mean_psth");
Fmean = figureCompute(src, specMean);
figMean = figure('Name', 'PSTH, mean over units');
renderFigure(Fmean, specMean, figMean);

hasStats = license('test', 'Statistics_Toolbox') && exist('signrank', 'file') > 0;
Er = responseEpochs(src, eventRef(line="Stim"), [], Baseline=[-0.2 0], Window=[0 0.2], Param="Depth");
Tr = responseStats(st, Er, Baseline=[-0.2 0], Window=[0 0.2], Param="Depth", Meta=meta, Tests=hasStats);
disp(Tr);                                 % with the toolbox: pEvoked / qEvoked, direction, pTuning, ...

%% 7. A population summary over every unit of every dataset
acfg = EphysAnalysisConfig();
acfg.Source.Root = root;
acfg.Defaults.EventRef.line = "Stim";
acfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.5, 'stop', []);
[Pop, Sum] = populationAnalysis(acfg, Param="Depth", Tests=hasStats, GroupBy=["subject" "class"], LogFcn=[]);
disp(Sum.groups);
fig2 = figure('Name', 'Population PSTH');
renderPopulation(Pop, Sum, "psth", fig2);
% writePopulation(Pop, Sum, fullfile(root, "population"))   % CSV tables, figures, a JSON record
