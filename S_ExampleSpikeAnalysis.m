%% S_ExampleSpikeAnalysis  A PSTH of every good single unit in an ephys project, no plots.
%   Loads the project at projectRoot, keeps the sorted units classed "su"
%   that meet the good-unit criteria (unitQualityCriteria), and bins each
%   one's spikes around an event (spikePSTH). The result is one struct,
%   Hist, with one element of Hist.units per unit, carrying its recording
%   session, subject, date and time.
%
%   See also S_ExampleAnalysis, EphysProject, loadAnalysisSource,
%   selectUnits, epochTable, spikePSTH, unitQualityCriteria.

%% Parameters
projectRoot = "D:\EPHYS";                % project folder (recordings, or the pipeline's outputs)
alignLine   = "Trial";                   % digital line the histograms are aligned to ("Trial" = paired trial line)
alignEdge   = "onset";                   % "onset" | "offset" of each interval
windowSec   = [-0.5 1.0];                % [pre post] s around the event
binSec      = 0.010;                     % bin width, s
measure     = "rate";                    % "rate" (spikes/s) | "count" (per bin per epoch) | "probability"
groupBy     = string.empty(1, 0);        % 0-2 trial parameters to split trials by, e.g. "Depth"
unitClasses = "su";                      % sorted-unit classes kept: single units
useQuality  = true;                      % also require the good-unit quality criteria
criteria    = unitQualityCriteria();     % thresholds (isi violations, presence ratio, amplitude cutoff, ...)

%% Load the project
here = fileparts(mfilename('fullpath'));
addpath_nogit(here);                     % pipeline/, analysis/ and vendor/

P = EphysProject(projectRoot);
P.refresh();
fprintf('%d dataset(s) in %s\n', P.NumDatasets, projectRoot);

% Unit selection: classes, plus the quality criteria when useQuality
usel = EphysAnalysisConfig.defaults("UnitSelection");
usel.classes = unitClasses;
q = criteria;
q.enabled = useQuality;
usel.quality = q;

ref = eventRef(line=alignLine, edge=alignEdge);
win = epochWindow(pre=windowSec(1), post=windowSec(2));
sel = trialSelection(groupBy=groupBy);

%% Histograms, one dataset at a time
units = struct([]);
t = []; edges = [];
for k = 1:P.NumDatasets
    ds = P.Datasets(k);
    src = loadAnalysisSource(ds.outputs(), Key=P.datasetKey(k));
    if ~src.hasUnits
        fprintf('  %s: no sorted units, skipped\n', ds.Name);
        continue
    end

    % Subject and recording start from the dataset name; else from the behavior
    try
        id = ds.unitIdentity();
        subject = id.subject;
        recStart = id.recordingStart;
    catch
        subject = src.subject;
        recStart = src.startTime;
    end

    % Good single units and their spike times (s, continuous clock)
    try
        [st, meta] = selectUnits(src, usel);
    catch ME
        if ismember(ME.identifier, ["selectUnits:NoUnits" "selectUnits:NoneLeft"])
            fprintf('  %s: no good single units, skipped\n', ds.Name);
            continue
        end
        rethrow(ME)
    end

    % Epochs around each event, then the histograms
    [E, G] = epochTable(src, ref, Window=win, Selection=sel);
    if height(E) == 0
        fprintf('  %s: no "%s" events, skipped\n', ds.Name, alignLine);
        continue
    end
    R = spikePSTH(st, E, Window=windowSec, BinSec=binSec, Measure=measure, ...
        Raster=false, Groups=G, Meta=meta);
    t = R.t; edges = R.edges;

    % One element per unit: identity, session and its histogram [nBins x nGroups]
    for u = 1:height(meta)
        h = struct();
        h.dataset        = string(ds.Name);          % recording session
        h.datasetKey     = src.key;
        h.subject        = string(subject);
        h.recordingStart = recStart;
        h.sessionDate    = datetime(year(recStart), month(recStart), day(recStart), Format="yyyy-MM-dd");
        h.sessionTime    = timeofday(recStart);
        h.behaviorStart  = src.startTime;            % the behavior session's start (NaT without)
        h.unitLabel      = meta.label(u);
        h.unitId         = meta.unitId(u);
        h.class          = meta.class(u);
        h.channel        = meta.channel(u);
        h.shank          = meta.shank(u);
        h.nSpikes        = meta.nSpikes(u);
        h.groups         = string(R.groups.label(:)).';
        h.nEpochs        = R.nEpochs(:).';
        h.rate           = reshape(R.rate(:, u, :), numel(R.t), []);   % in measure's unit
        h.sem            = reshape(R.sem(:, u, :), numel(R.t), []);
        h.count          = reshape(R.count(:, u, :), numel(R.t), []);  % spikes summed over epochs
        units = [units, h]; %#ok<AGROW>
    end
    fprintf('  %s: %d unit(s), %d epoch(s)\n', ds.Name, height(meta), height(E));
end

%% Collect into one structure
Hist = struct();
Hist.projectRoot = projectRoot;
Hist.params = struct('alignLine', alignLine, 'alignEdge', alignEdge, 'windowSec', windowSec, ...
    'binSec', binSec, 'measure', measure, 'groupBy', groupBy, 'unitClasses', unitClasses, ...
    'useQuality', useQuality, 'criteria', criteria);
Hist.t = t;                              % bin centers, s from the event
Hist.edges = edges;                      % bin edges, s
Hist.units = units;                      % 1 x nUnits struct
Hist.created = datetime('now');
if isempty(units); nDs = 0; else; nDs = numel(unique([units.dataset])); end
fprintf('%d good single unit(s) from %d dataset(s)\n', numel(units), nDs);
