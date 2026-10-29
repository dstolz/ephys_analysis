%% S_ExampleChronuxSpikes  Spike data of every good single unit, converted for Chronux (mtspecgrampt), no GUI.
%   Loads the project at projectRoot, keeps the sorted units classed "su"
%   that meet the good-unit criteria (unitQualityCriteria), or, with
%   spikeSource = "detected", reads the Spikes step's threshold detections
%   (no sorting needed; classes and quality do not apply; one train per
%   channel, or with mergeChannels the channels of neighboring sites that hold
%   one neuron joined into one, named for the one with the largest waveform),
%   and cuts each
%   unit's spike train into one Chronux trial per event (the epochs of
%   epochTable, one group of trials per trial parameter value). The cut is
%   the Chronux point-process form: a 1 x nTrials struct array with field
%   times, spike times in s from the start of the window, plus the time grid
%   t and the params struct that go with it (ChronuxDataset.spikeTrials,
%   createdatamatpt's half-open window rule). Each group of trials then goes
%   to mtspecgrampt, a moving-window multitaper spectrogram averaged over
%   trials.
%
%   The result is one struct, Spec, with one element of Spec.units per unit,
%   carrying its recording session, subject, date and time; and one array,
%   SpecAll [time x freq x groups x units], for plots across the population.
%
%   Chronux wants trials of one length on one time grid, so the epoch window
%   is fixed ([pre post] around the event), not "between" two events. To use
%   the cut trials with another Chronux function (mtspectrumpt, coherencypt,
%   ...), keep the data: set keepTrials = true and read Spec.units(k).trials,
%   a struct array of Chronux data per group, and Spec.chronux (its params).
%
%   mtspecgrampt places its windows from the first to the last spike of the
%   trials it is given, not over the whole epoch, so its time points differ
%   from one unit and group to the next. They are interpolated onto one grid
%   (Spec.t, s from the event); where a unit has no windows (before its first
%   or after its last spike) the spectrogram is NaN.
%
%   The plots show the change relative to a baseline (baseline, baselineSec;
%   "none" plots power in dB instead): each frequency, unit and group against
%   its own mean power over the windows centered in baselineSec, on a diverging
%   colormap centered on no change. Spec.SpecRel holds the same numbers.
%
%   See also S_ExampleSpikeAnalysis, EphysProject, loadAnalysisSource,
%   selectUnits, epochTable, ChronuxDataset.spikeTrials, mtspecgrampt.

%% Parameters
% projectRoot = "S:/ANALYSIS_BACKUPS/Daniel/EPHYS/OFC/Analysis";   % project folder (recordings, or the pipeline's outputs)
projectRoot = "C:/Users/dstolz/My Drive/PROJECTS/OFC_Ephys/Analysis";

spikeSource = "units";                   % "units" (sorted, from the sorting folder) | "detected" (threshold detections of the Spikes step, one train per channel)
alignLine   = "Stim";                    % digital line the trials are aligned to ("Trial" = paired trial line)
alignEdge   = "onset";                   % "onset" | "offset" of each interval
windowSec   = [-1.1 1.1];                   % [pre post] s around the event: every trial is this long
groupBy     = "Depth";                   % 0-2 trial parameters to split trials by, e.g. "Depth"
mergeChannels = true;                    % spikeSource "detected": join the channels of neighboring sites that hold one neuron (groupDetected), named for the one with the largest waveform
unitClasses = "su";                      % sorted-unit classes kept: single units (spikeSource "units" only)
useQuality  = true;                      % also require the good-unit quality criteria (spikeSource "units" only)
criteria    = unitQualityCriteria();     % thresholds (isi violations, presence ratio, amplitude cutoff, ...)

% Chronux params (see mtspecgrampt)
movingwin   = [0.5 0.05];                % [window step] s of the moving window
spikeFs     = 1000;                      % Hz, rate of the time grid the tapers are computed on
tapers      = [3 5];                     % [TW K]: time-bandwidth product and number of tapers (W = TW / movingwin(1))
pad         = 0;                         % FFT padding: -1 none, 0 next power of 2, 1 one more, ...
fpass       = [0 150];                   % Hz, band kept
% err         = [2 0.05];                  % [0 p] none | [1 p] theoretical | [2 p] jackknife error bars
err         = [0 0.05];                  % [0 p] none | [1 p] theoretical | [2 p] jackknife error bars
fscorr      = 1;                         % 1 = finite-size correction for spikes
minTrials   = 2;                         % a group needs at least this many trials (jackknife needs 2)
keepTrials  = false;                     % keep each unit's Chronux data (spike times per trial) in Spec

% Change relative to a baseline: each frequency, unit and group is compared with its own mean power B
% over the windows centered in baselineSec (plots, and Spec.SpecRel)
baseline    = "db";                      % "none" (power, dB) | "db" 10*log10(S/B) | "percent" 100*(S-B)/B | "ratio" S/B | "zscore" (S-B)/SD
baselineSec = [-1 -0.5];                 % [b0 b1] s from the event

%% Load the project
here = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % repository root
addpath(here);                           % addpath_nogit lives there
addpath_nogit(here);                     % pipeline/, analysis/, vendor/ and toolboxes/chronux

ChronuxDataset.requireChronux();
cx = ChronuxDataset();                   % no signal: only used to cut spike trains and make params

P = EphysProject(projectRoot);
P.refresh();
fprintf('%d dataset(s) in %s\n', P.NumDatasets, projectRoot);
includeSubjects = [];                    % subjects to analyze, e.g. ["SUBJ-ID-0001" "SUBJ-ID-0002"]; [] = all
excludeSubjects = [];                    % subjects to leave out, e.g. "SUBJ-ID-0003"; applied after includeSubjects
ident = P.unitIdentities();              % a row per dataset: Subject and RecordingStart, from its name
keep = (isempty(includeSubjects) | ismember(lower(ident.Subject), lower(string(includeSubjects(:))))) & ~ismember(lower(ident.Subject), lower(string(excludeSubjects(:))));
todo = find(keep).';                     % indices of the datasets to analyze

% Unit selection: the sorted units' classes, plus the quality criteria when useQuality;
% detections have neither (one train per channel)
spikeSource = lower(string(spikeSource));
if ~ismember(spikeSource, ["units" "detected"])
    error('S_ExampleChronuxSpikes:BadSource', 'spikeSource must be "units" or "detected".');
end
isDet = spikeSource == "detected";
if isDet; unitWord = "detection channel"; else; unitWord = "good single unit"; end
usel = EphysAnalysisConfig.defaults("UnitSelection");
usel.source = spikeSource;
if isDet
    usel.merge.enabled = mergeChannels;
else
    usel.classes = unitClasses;
    criteria.enabled = useQuality;
    usel.quality = criteria;
end

ref = eventRef(line=alignLine, edge=alignEdge);             % which digital-line event each epoch is aligned to
win = epochWindow(pre=windowSec(1), post=windowSec(2));     % epoch window (fixed length, as Chronux needs)
sel = trialSelection(groupBy=groupBy, maxGroups=100);       % how trials are kept and grouped

% The time grid every spectrogram is put on: window centers, s from the event
tg = (windowSec(1) + movingwin(1)/2 : movingwin(2) : windowSec(2) - movingwin(1)/2).';
nT = numel(tg);

%% Spike trains to Chronux trials to spectrograms, one dataset at a time
units = struct([]);
params = []; f = [];
for k = todo
    ds = P.Datasets(k);
    src = loadAnalysisSource(ds.outputs(), Key=P.datasetKey(k));
    if isDet && ~src.hasDetected
        fprintf('  %s: no detected spikes, skipped\n', ds.Name);
        continue
    elseif ~isDet && ~src.hasUnits
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

    % Good single units (or detection channels) and their spike times (s, continuous clock)
    try
        [st, meta] = selectUnits(src, usel);
    catch ME
        if ismember(ME.identifier, ["selectUnits:NoUnits" "selectUnits:NoDetected" "selectUnits:NoneLeft"])
            fprintf('  %s: no %ss, skipped\n', ds.Name, unitWord);
            continue
        end
        rethrow(ME)
    end

    % Epochs around each event: E.t0Continuous is each trial's time 0 on the spikes' clock
    [E, G] = epochTable(src, ref, Window=win, Selection=sel);
    if height(E) < minTrials
        fprintf(2, '  %s: %d %s event(s), skipped\n', ds.Name, height(E), alignLine);
        continue
    end

    for u = 1:height(meta)
        % One unit's spikes -> a 1 x nEpochs struct array (field times) and params for Chronux.
        % The epochs are already complete (epochTable dropped the others), so keep them all.
        [data, params, ~, info] = cx.spikeTrials(E.t0Continuous, windowSec, ...
            Spikes=struct('times', st{u}), TimeBase="window", Incomplete="keep", ...
            SpikeFs=spikeFs, Tapers=tapers, Pad=pad, Fpass=fpass, Err=err, TrialAve=1);

        % One spectrogram per group of trials: mtspecgrampt averages over the trials it is given
        nG = height(G);
        S = []; Serr = []; rate = nan(nT, nG); nTrials = zeros(1, nG);
        for g = 1:nG
            ig = E.groupIndex == g;
            nTrials(g) = nnz(ig);
            if nTrials(g) < minTrials || ~any(info.counts(ig) > 0)
                continue                                    % too few trials, or no spike in any
            end
            if params.err(1) > 0
                [s, tn, f, r, e] = mtspecgrampt(data(ig), movingwin, params, fscorr);
            else
                [s, tn, f, r] = mtspecgrampt(data(ig), movingwin, params, fscorr);
                e = nan(2, numel(tn), numel(f));
            end
            if numel(tn) < 2
                continue    % its spikes span less than two windows (mtspecgrampt places windows from first to last spike)
            end
            if isempty(S)
                S = nan(nT, numel(f), nG);
                Serr = nan(2, nT, numel(f), nG);
            end

            % tn is s from the window's start: shift to s from the event, then onto the common grid
            tn = tn(:) + windowSec(1);
            S(:, :, g) = interp1(tn, reshape(s, numel(tn), []), tg, 'linear', NaN);
            for b = 1:2
                Serr(b, :, :, g) = interp1(tn, reshape(e(b, :, :), numel(tn), []), tg, 'linear', NaN);
            end
            rate(:, g) = interp1(tn, r(:), tg, 'linear', NaN);   % spikes/s in each window
        end
        if isempty(S)
            continue                                        % no group had spikes: nothing to keep
        end

        % One element per unit: identity, session and its spectrograms [nTime x nFreq x nGroups]
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
        h.groups         = string(G.label(:)).';
        h.nTrials        = nTrials;                  % epochs per group
        h.rate           = rate;                     % [nTime x nGroups] spikes/s (mtspecgrampt's R)
        h.S              = S;                        % [nTime x nFreq x nGroups], spikes/s
        h.Serr           = Serr;                     % [2 x nTime x nFreq x nGroups] lower / upper; NaN without err
        if keepTrials
            h.trials = data;                         % Chronux data, one struct per epoch
            h.trialGroup = E.groupIndex(:).';        % which group each epoch is in
        end
        units = [units, h]; %#ok<AGROW>
    end
    fprintf('  %s: %d unit(s), %d epoch(s)\n', ds.Name, height(meta), height(E));
end

%% Collect into one structure
Spec = struct();
Spec.projectRoot = projectRoot;
Spec.params = struct('spikeSource', spikeSource, 'alignLine', alignLine, 'alignEdge', alignEdge, 'windowSec', windowSec, ...
    'groupBy', groupBy, 'unitClasses', unitClasses, 'useQuality', useQuality, 'criteria', criteria, ...
    'movingwin', movingwin, 'spikeFs', spikeFs, 'tapers', tapers, 'pad', pad, 'fpass', fpass, ...
    'err', err, 'fscorr', fscorr, 'minTrials', minTrials, 'baseline', baseline, 'baselineSec', baselineSec);
Spec.chronux = params;                   % the params struct handed to mtspecgrampt
Spec.t = tg;                             % window centers, s from the event
Spec.f = f(:);                           % frequencies, Hz
Spec.units = units;                      % 1 x nUnits struct
Spec.created = datetime('now');
if isempty(units); nDs = 0; else; nDs = numel(unique([units.dataset])); end
fprintf('%d %s(s) from %d dataset(s)\n', numel(units), unitWord, nDs);
if isempty(units); return; end

%% Arrange the data to a single spectrogram array, SpecAll [time x freq x groups x units]
%   SpecAll(:, :, g, k) is unit k's spectrogram in group g (NaN when the unit had
%   too few trials or no spikes there); RateAll(:, g, k) its rate.
grps = arrayfun(@(a) a.groups, units, 'uni', 0).';
ugrps = unique([grps{:}]);

% Order groups by the number after "Depth = " when there is one, else as sorted
depth = str2double(extractAfter(ugrps, "Depth = "));
if all(isnan(depth)); depth = (1:numel(ugrps)).'; end
[depth, i] = sort(depth(:), 'descend');
ugrps = ugrps(i);

nUnits = numel(units);
SpecAll = nan(nT, numel(Spec.f), numel(ugrps), nUnits);
RateAll = nan(nT, numel(ugrps), nUnits);
for i = 1:nUnits
    [~, gi] = ismember(units(i).groups, ugrps);
    SpecAll(:, :, gi, i) = units(i).S;
    RateAll(:, gi, i) = units(i).rate;
end
Spec.groupLabels = ugrps;
Spec.SpecAll = SpecAll;
Spec.RateAll = RateAll;

%% Change relative to the baseline, Z [time x freq x groups x units] (what the plots show)
%   Same rule as the analysis app's Chronux tab (chronuxNormalize): B is the mean of
%   the windows whose centers lie in baselineSec, per frequency, group and unit.
%   A window whose spikes were never seen (NaN) is left out of B.
baseline = string(baseline);
if baseline == "none"
    Z = 10*log10(SpecAll);                % power in dB, on a sequential colormap
    zLabel = '10 log_{10} S';
    zCenter = [];
else
    inb = tg >= baselineSec(1) - 1e-9 & tg <= baselineSec(2) + 1e-9;
    if ~any(inb)
        error('S_ExampleChronuxSpikes:NoBaseline', ['No spectrogram window is centered in the baseline ' ...
            '[%g %g] s: widen it or shorten movingwin.'], baselineSec(1), baselineSec(2));
    end
    B = mean(SpecAll(inb, :, :, :), 1, 'omitnan');
    switch baseline
        case "db"
            Z = 10*log10(SpecAll ./ B);   zLabel = 'dB change';   zCenter = 0;
        case "percent"
            Z = 100*(SpecAll - B) ./ B;   zLabel = '% change';    zCenter = 0;
        case "ratio"
            Z = SpecAll ./ B;             zLabel = 'ratio';       zCenter = 1;
        case "zscore"
            Z = (SpecAll - B) ./ std(SpecAll(inb, :, :, :), 0, 1, 'omitnan');
            zLabel = 'z';                 zCenter = 0;
        otherwise
            error('S_ExampleChronuxSpikes:BadBaseline', ...
                'baseline must be "none", "db", "percent", "ratio" or "zscore".');
    end
    Spec.SpecRel = Z;                     % [time x freq x groups x units]
end

%% Look at data: one figure per session, a tile per depth (rows) and unit (columns)
sessionDate = arrayfun(@(a) a.sessionDate, units).';
uSessionDate = unique(sessionDate);
nGrp = numel(ugrps);
fr = Spec.f;
for s = 1:numel(uSessionDate)
    ku = find(sessionDate == uSessionDate(s));           % this session's units
    nCol = numel(ku);

    % One color scale for the figure, from the middle 98% of what it shows. A change
    % is drawn on a diverging map, symmetric about no change (blue down, red up).
    v = Z(:, :, :, ku);
    v = v(isfinite(v));
    if isempty(v)
        clims = [0 1];
    elseif isempty(zCenter)
        clims = prctile(v, [1 99]);
    else
        m = max(abs(prctile(v, [1 99]) - zCenter));
        clims = zCenter + [-m m];
    end
    if isempty(zCenter); cmap = parula(256); else; cmap = blueWhiteRed(256); end

    fig = figure('Name', sprintf('Session #%d', s), 'Color', 'w');
    tl = tiledlayout(fig, nGrp, nCol, 'Padding', 'tight', 'TileSpacing', 'tight');
    if baseline == "none"
        what = 'spike spectrograms';
    else
        what = sprintf('spike spectrograms, %s re [%g %g] s', zLabel, baselineSec(1), baselineSec(2));
    end
    title(tl, sprintf('Session #%d, %s: %s, frequency (Hz) by time (s); n = %d', ...
        s, string(uSessionDate(s)), what, nCol));
    xlabel(tl, sprintf('time re %s %s (s)', alignLine, alignEdge));

    ax = gobjects(nGrp, nCol);
    for r = 1:nGrp
        for c = 1:nCol
            ax(r, c) = nexttile(tl);
            hold(ax(r, c), 'on')

            un = units(ku(c));
            img = Z(:, :, r, ku(c)).';                   % [nFreq x nTime]
            if any(isfinite(img), 'all')                 % else this unit has nothing at this depth
                imagesc(ax(r, c), tg, fr, img, 'AlphaData', isfinite(img));
                xline(ax(r, c), 0, 'k', LineWidth=1);
            end
            axis(ax(r, c), 'xy')
            colormap(ax(r, c), cmap)

            if r == 1;      title(ax(r, c), un.unitLabel, 'Interpreter', 'none'); end
            if c == 1;      ylabel(ax(r, c), ugrps(r), 'Interpreter', 'none'); end
            if r < nGrp;    ax(r, c).XTickLabel = []; end   % tick labels on the outer tiles only
            if c > 1;       ax(r, c).YTickLabel = []; end
        end
    end
    linkaxes(ax(:), 'xy')
    xlim(ax(1), [tg(1) tg(end)])
    ylim(ax(1), [fr(1) fr(end)])
    set(ax(:), 'CLim', clims)

    cb = colorbar(ax(1, end));                           % one colorbar for the figure
    cb.Layout.Tile = 'east';
    cb.Label.String = zLabel;
end
