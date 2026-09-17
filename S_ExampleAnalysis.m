%%

clear classes
startup
addpath_nogit('c:\src\ephys_analysis')

%

EphysPreprocessingApp



%%

P = EphysProject("D:\EPHYS", ...
    ProbeFile="C:\src\ephys_analysis\pipeline\probes\H64LP_4x16lin_probemap.json");
P.refresh();                     % headers + per-dataset manifests

T = P.gatherMetadata();          % header-only, one row per dataset


%%
% Threshold spike detection over a whole recording (streamed, one chunk at a
% time). TS is {1 x nChan} of spike times in seconds.
[TS,wf,info] = P.Datasets(4).detectSpikes();


%%
MUA = P.Datasets(4).deriveSignals(dataTypeOut = "MUA")


%%

dt = DatasetTracker(P.Root)

%%
% The config-driven pipeline: the same thing the GUI runs. Save the config
% with the GUI (File > Save config) or build it here.
cfg = EphysPipelineConfig();
cfg.Name = "example";
cfg.Project.Root = "D:\EPHYS";
cfg.Project.OutputRoot = "D:\EPHYS_out";
cfg.Probe.DefaultProbeFile = "C:\src\ephys_analysis\pipeline\probes\H64LP_4x16lin_probemap.json";
cfg.Artifacts.Enabled = true;                          % automatic detection (+ manual periods)
cfg.Sorting.Enabled = true;                            % SpikeInterface + Kilosort4 (optional)
cfg.Sorting.PythonExe = "C:\Users\me\miniconda3\envs\kilosort\python.exe";
cfg.Sorting.Execution = "blocking";
cfg.Signals.Enabled = true;  cfg.Signals.LFP = true;  cfg.Signals.MUA = true;
cfg.Spikes.Enabled = true;   cfg.Spikes.Source = "both";
cfg.Export.Enabled = true;   cfg.Export.Formats = ["chronux" "fieldtrip"];
cfg = cfg.save("D:\EPHYS\example_pipeline.json");

pipe = EphysPipeline(cfg);       % scans the root, restores the manifests
disp(pipe.plan())                % what would run; writes nothing
R = pipe.run();                  % every enabled step, in order
disp(R)

% Scripts that reproduce the run (File > Generate script in the GUI):
EphysPipelineScript.compact(cfg, File="D:\EPHYS\run_example.m");
EphysPipelineScript.standalone(cfg, File="D:\EPHYS\run_example_standalone.m");

%%
% Outputs, per dataset under <OutputRoot>/<Name>:
%   <Name>_extract.mat    Y.LFP / Y.MUA, events, info, behavior
%   <Name>_spikes.mat     detected (threshold) + units (sorted, phy labels)
%   <Name>_chronux.mat    LFP.data / params / t, sp, events  -> mtspectrumc, mtspectrumpt, ...
%   <Name>_fieldtrip.mat  data_LFP, spike, event             -> ft_definetrial, ft_spike_maketrials, ...
d = pipe.Project.Datasets(1);
U = d.readSortedUnits();                               % the associated Kilosort/phy output
C = load(fullfile(d.outputFolder(), d.Name + "_chronux.mat"));
[S, f] = mtspectrumc(C.LFP.data(:, 1), C.LFP.params); % needs Chronux on the path
