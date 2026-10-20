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
projectRoot = "S:/ANALYSIS_BACKUPS/Daniel/EPHYS/OFC/Analysis";                % project folder (recordings, or the pipeline's outputs)
alignLine   = "Stim";                   % digital line the histograms are aligned to ("Trial" = paired trial line)
alignEdge   = "onset";                   % "onset" | "offset" of each interval
windowSec   = [-1 1.0];                % [pre post] s around the event
binSec      = 0.010;                     % bin width, s
measure     = "rate";                    % "rate" (spikes/s) | "count" (per bin per epoch) | "probability"
groupBy     = "Depth";        % 0-2 trial parameters to split trials by, e.g. "Depth"
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
criteria.enabled = useQuality;
usel.quality = criteria;

ref = eventRef(line=alignLine, edge=alignEdge);             % define which digital-line event to align each epoch
win = epochWindow(pre=windowSec(1), post=windowSec(2));     % define epoch window
sel = trialSelection(groupBy=groupBy,maxGroups=100);        % define how trials should be selected

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
        fprintf(2,'  %s: no %s events, skipped\n', ds.Name, alignLine);
        continue
    elseif height(E) == 1
        fprintf(2,'  %s: only 1 %s event, skipped\n', ds.Name, alignLine)
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

%% Arrange the data to a single response matrix, R

grps = arrayfun(@(a) a.groups,units,'uni',0).';
ugrps = unique([grps{:}]);

sessionDate = arrayfun(@(a) a.sessionDate, units).';
uSessionDate = unique(sessionDate);
sessionNum = 1:numel(uSessionDate);

depth = str2double(extractAfter(ugrps, "Depth = "));
[depth,i] = sort(depth,'descend');
ugrps = ugrps(i);


nUnits = numel(units);

R = nan(length(Hist.t),length(ugrps),nUnits); % preallocate

for i = 1:nUnits
    gind = ismember(ugrps,units(i).groups);

    R(:,gind,i) = units(i).rate;
end

%% Look at data


tiledlayout('flow');
for i = 6:length(sessionNum)

    sind = sessionDate == uSessionDate(i);

    R_mean = mean(R(:,:,sind),3,'omitnan');

    % R_mean = smoothdata(R_mean,1,"gaussian",[2 2]);

    nexttile
    % imagesc(Hist.t,1:length(ugrps),R_mean.')
    surf(Hist.t,1:length(ugrps),R_mean.')

    yticks(1:length(ugrps));
    yticklabels(depth);
    ylabel("depth");

    xlabelf("time re %s",alignLine)
    xline(0,LineWidth=2,Color = 'w')

    titlef('Session #%d; n = %d',sessionNum(i),sum(sind))
    colorbar

    shading interp
end

ax = findobj(gcf,'type','axes');
set(ax,'clim',[0 60])

linkaxes(ax)