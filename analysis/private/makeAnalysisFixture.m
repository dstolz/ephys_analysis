function F = makeAnalysisFixture(root, opts)
%makeAnalysisFixture  A small synthetic project run through the pipeline (test data).
%   F = makeAnalysisFixture(ROOT) writes makeSyntheticProject(Preset="small")
%   under ROOT/proj, approves each dataset's trial pairing with the cuts its
%   scenario needs (so every dataset has correctly paired trials), runs the
%   generated pipeline config with the Behavior, Signals (LFP + MUA + AUX)
%   and Spikes (detected + sorted) steps -- no sorting, artifacts or export
%   -- and returns
%     root, proj, configFile, truth (makeSyntheticProject's datasets),
%     names, folders (output folders), keys, outputs (DatasetOutputs per
%     dataset, CacheData=true), results (the pipeline's Results)
%
%   Options: Scenarios (default ["clean" "late-start"]), NumTrials (12),
%   Seed (1).

arguments
    root (1,1) string
    opts.Scenarios (1,:) string = ["clean" "late-start"]
    opts.NumTrials (1,1) double = 12
    opts.Seed (1,1) double = 1
end

proj = fullfile(root, 'proj');
S = makeSyntheticProject(proj, Preset="small", Scenarios=opts.Scenarios, NumTrials=opts.NumTrials, Seed=opts.Seed);
P = EphysProject(proj);
P.refresh();
for T = S.datasets
    c = T.expectedCuts;
    if any(c.trials) || any(c.intervals)
        d = P.dataset(T.name);
        Pp = d.pairTrials(Cuts=c, Warn=false);
        d.setTrialPairing(Pp, "approved");
    end
end

cfg = EphysPipelineConfig.load(S.configFile);
cfg.Behavior.AutoApprove = true;
cfg.Sorting.Enabled = false;
cfg.Artifacts.Enabled = false;
cfg.Export.Enabled = false;
cfg.Signals.Enabled = true;
cfg.Signals.LFP = true; cfg.Signals.MUA = true; cfg.Signals.SPIKE = false; cfg.Signals.AUX = true;
cfg.Spikes.Enabled = true;
cfg.Spikes.Source = "both";
pipe = EphysPipeline(cfg, Project=P, Refresh=false);
pipe.LogFcn = [];
R = pipe.run();

n = numel(S.datasets);
F = struct();
F.root = string(root);
F.proj = string(proj);
F.configFile = S.configFile;
F.truth = S.datasets;
F.names = [S.datasets.name];
F.folders = strings(1, n);
F.keys = strings(1, n);
F.outputs = DatasetOutputs.empty(1, 0);
for k = 1:n
    d = P.dataset(F.names(k));
    F.folders(k) = string(d.outputFolder());
    F.keys(k) = EphysProject.relativeKey(proj, d.Folder);
    F.outputs(k) = pipe.outputsFor(d, 'CacheData', true);
end
F.results = R;
end
