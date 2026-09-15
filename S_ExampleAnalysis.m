%%

addpath_nogit('c:\src\ephys_analysis')

%%

P = EphysProject("D:\EPHYS", ...
    ProbeFile="C:\src\ephys_analysis\intan\probes\H64LP_4x16lin_probemap.json");

T = P.gatherMetadata();          % header-only, one row per dataset


%%
P.Datasets(4).


%%
MUA = P.Datasets(4).deriveSignals(dataTypeOut = "MUA")


%%

dt = DatasetTracker(P.Root) 

%%
% Legacy engine: .bin then Kilosort4
infos   = P.toBinAll();
results = P.runKilosortAll(Wait=false);

% SpikeInterface engine (what the GUI runs): no project wrapper, loop instead
for d = P.Datasets
    d.runSpikeInterface(Wait=false);
end
