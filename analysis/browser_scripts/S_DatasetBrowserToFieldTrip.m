%% DatasetBrowser to FieldTrip
% A post-processing script of the DatasetBrowser (or run by hand with B in the
% workspace): it turns the browser's data into FieldTrip structures, one per
% dataset, in either of two ways:
%
%   1. Epochs: "Keep single trials" ticked, Compute. Each epoch of R.epochs
%      becomes a FieldTrip trial, cut as the browser cut it:
%      epochMatrixFieldTrip. -> ftEpochs, trialinfo = [group trial]
%        signal (LFP, MUA, SPIKE, AUX): raw structures (ft_datatype_raw),
%          each epoch after Detrend and Baseline
%        spikes (units, detected): spike structures (ft_datatype_spike) as
%          ft_spike_maketrials leaves them (time, trial, trialtime), the
%          timestamps on the recording's samples
%   2. Whole sessions: "Load whole sessions". Each dataset's whole recording,
%      with its events, its erased periods and the kept trials in the
%      browser's window as cfg.trl: sessionDataFieldTrip. -> ftSessions
%        signal: one continuous trial; ft_redefinetrial cuts cfg.trl
%        spikes: every spike's timestamp; ft_spike_maketrials cuts cfg.trl
%
% Either part runs when its data is there. FieldTrip itself is needed only to
% validate the structures and to analyze them. The general builders behind
% both are FieldTripExport.epochs, .continuous, .trl, .spikeTimes and
% .spikeTrials, for any signal matrix or spike times.

if ~exist('B', 'var') || ~isa(B, 'DatasetBrowser')
    error('B is not a DatasetBrowser: run this from the browser (Post-processing script), or set B = DatasetBrowser.open(root) first.');
end
outDir = "";                    % a folder to save <dataset>_fieldtrip_*.mat in; "" keeps them in the workspace only
fieldTripPath = 'c:\src\fieldtrip\';   % added when FieldTrip is not on the path
trialEvent = "";                % the event line FieldTrip defines a session's trials on; "" takes the browser's
psthBin = 0.025;                % s, the spikes' PSTH bins in the plots

%% 1. Epochs (R.epochs): a trial per epoch, trialinfo = [group in R.groupLabels, trial]
R = B.Result;
ftEpochs = {};
if ~isempty(R) && isfield(R, 'epochs') && ~isempty(R.epochs)
    if R.rowKind == "unit"
        % the recording rates place the spikes on the recording (timestamp)
        fs = arrayfun(@(e) B.source(e.key).fs, R.epochs);
        ftEpochs = epochMatrixFieldTrip(R, Fs=fs);
        nTrials = cellfun(@(d) height(d.trialtime), ftEpochs);
    else
        ftEpochs = epochMatrixFieldTrip(R);
        nTrials = cellfun(@(d) numel(d.trial), ftEpochs);
    end
    fprintf('ftEpochs: %d datasets, %d epochs, %s\n', numel(ftEpochs), sum(nTrials), R.labels.description);
end

%% 2. Whole sessions (B.Sessions): the whole recording, cfg.trl around TrialOnset
S = B.Sessions;
ftSessions = {};
win = B.Settings.window;
if ~isempty(S)
    S = S([S.data] ~= "trials");   % "Load trials only" brings no spikes or signal
    ftSessions = sessionDataFieldTrip(S, Window=[win.pre win.post]);
    fprintf('ftSessions: %d datasets\n', numel(ftSessions));
end

if isempty(ftEpochs) && isempty(ftSessions)
    error(['Nothing to convert: Compute with "Keep single trials" ticked (B.Result.epochs), ' ...
        'or "Load whole sessions" (B.Sessions).']);
end
isSpike = @(d) isfield(d, 'timestamp');

%% Check and save
if ~FieldTripExport.hasFieldTrip()
    addpath(fieldTripPath)
    ft_defaults;
end
for d = [ftEpochs; ftSessions].'
    kind = "raw";
    if isSpike(d{1}), kind = "spike"; end
    [ok, msg] = FieldTripExport.validate(d{1}, kind);
    if ~ok, fprintf('%s: %s\n', d{1}.cfg.name, msg), end
end

if outDir ~= ""
    for d = ftEpochs.'
        data = d{1};
        save(fullfile(outDir, d{1}.cfg.name + "_fieldtrip_epochs.mat"), 'data', '-v7.3');
    end
    for d = ftSessions.'
        data = d{1};
        save(fullfile(outDir, d{1}.cfg.name + "_fieldtrip_session.mat"), 'data', '-v7.3');
    end
end

%% Use with FieldTrip
% A signal: the spectrum of a dataset's epochs of the first group, and a
% session's trials without those touching an erased period:
%   cfg = []; cfg.method = 'mtmfft'; cfg.taper = 'hanning'; cfg.foi = 1:100;
%   cfg.trials = find(ftEpochs{1}.trialinfo(:, 1) == 1);
%   freq = ft_freqanalysis(cfg, ftEpochs{1});
%   D = ftSessions{1};
%   cfg = []; cfg.trl = D.cfg.trl; trials = ft_redefinetrial(cfg, D);
%   cfg = []; cfg.artfctdef = D.cfg.artfctdef; cfg.artfctdef.reject = 'complete';
%   trials = ft_rejectartifact(cfg, trials);
% Spikes: the rates in the first group's epochs, and a session cut into its
% kept trials (cfg.trl in timestamps):
%   cfg = []; cfg.trials = find(ftEpochs{1}.trialinfo(:, 1) == 1); cfg.latency = [0 0.5];
%   rate = ft_spike_rate(cfg, ftEpochs{1});
%   D = ftSessions{1};
%   cfg = []; cfg.trl = D.cfg.trl; cfg.timestampspersecond = D.hdr.Fs;
%   trials = ft_spike_maketrials(cfg, D);    % trials.trialinfo = [group trial]

%% Sample plots
% Signals: every channel's evoked response at its probe site
% (ft_multiplotER); the layout comes from data.elec (the probe positions),
% else the channels go on a grid ('ordered'). Spikes: the busiest unit's
% raster and PSTH (ft_spike_plot_raster, ft_spike_psth), a line per group.

% The first dataset's epochs, one line per group:
if ~isempty(ftEpochs)
    data = ftEpochs{1};
    groups = unique(data.trialinfo(:, 1)).';
    groupNames = string(data.cfg.groupLabels(groups));
    colors = lines(numel(groups));
    if isSpike(data)
        [~, u] = max(cellfun(@numel, data.time));
        unit = data.label{u};
        fig = figure('Name', sprintf('%s %s epochs (FieldTrip)', data.cfg.name, unit), 'Color', 'w');
        tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');
        ax = nexttile(tl); hold(ax, 'on')
        for g = 1:numel(groups)
            cfg = [];
            cfg.spikechannel = unit;
            cfg.trials = find(data.trialinfo(:, 1) == groups(g));
            cfg.binsize = psthBin;
            psth = ft_spike_psth(cfg, data);
            stairs(ax, psth.time - psthBin / 2, psth.avg, 'Color', colors(g, :));
        end
        xline(ax, 0, ':');
        ylabel(ax, 'Spikes/s'); title(ax, unit, 'Interpreter', 'none')
        legend(ax, groupNames, 'Interpreter', 'none', 'Location', 'northeastoutside')
        % the raster, trials ordered by group (ft_spike_plot_raster draws in the current axes)
        [~, order] = sort(data.trialinfo(:, 1));
        sorted = data;
        [~, rank] = sort(order);
        for v = 1:numel(sorted.trial)
            sorted.trial{v} = reshape(rank(data.trial{v}), 1, []);
        end
        sorted.trialinfo = data.trialinfo(order, :);
        axes(nexttile(tl)); %#ok<LAXES> ft_spike_plot_raster draws in gca
        cfg = [];
        cfg.spikechannel = unit;
        cfg.interactive = 'no';
        ft_spike_plot_raster(cfg, sorted);
        xlabel(tl, 'Time from the event (s)');
    else
        tl = cell(1, numel(groups));
        for g = 1:numel(groups)
            cfg = [];
            cfg.trials = find(data.trialinfo(:, 1) == groups(g));
            tl{g} = ft_timelockanalysis(cfg, data);
        end
        cfg = [];
        if ~isfield(data, 'elec'), cfg.layout = 'ordered'; end
        layout = ft_prepare_layout(cfg, data);
        cfg = [];
        cfg.layout = layout;
        cfg.parameter = 'avg';
        cfg.linecolor = colors;
        cfg.showlabels = 'yes';
        cfg.interactive = 'no';
        cfg.figurename = char(data.cfg.name + " epochs (FieldTrip)");
        ft_multiplotER(cfg, tl{:});
        hold on   % a legend for the groups: ft_multiplotER draws a line per channel
        h = gobjects(1, numel(groups));
        for g = 1:numel(groups)
            h(g) = plot(NaN, NaN, 'Color', colors(g, :));
        end
        legend(h, groupNames, 'Interpreter', 'none', 'Location', 'northeastoutside')
    end
end

% A session's trials defined by FieldTrip from its events: ft_trialfun_general
% cuts the browser's window around every pulse of trialEvent in cfg.event
% (every pulse, not just the trials the browser keeps, as cfg.trl above
% does). A signal: the trials running off the signal or touching an erased
% period are dropped, the rest averaged. Spikes: ft_spike_maketrials cuts
% the trials (the event samples are timestamp + 1), and the PSTH of every
% unit is drawn.
if ~isempty(ftSessions)
    D = ftSessions{1};
    ev = D.cfg.event;
    evType = trialEvent;
    if evType == "", evType = B.Settings.ref.line; end
    if evType == "Trial", evType = S(1).trialLine; end   % the browser's "Trial" = the paired trial line
    if ~ismember(evType, string({ev.type}))
        error('%s has no "%s" events to define trials on; set trialEvent to one of: %s.', ...
            D.cfg.name, evType, strjoin(unique(string({ev.type})), ', '));
    end
    if trialEvent == "" && B.Settings.ref.edge == "offset"   % align on the pulses' ends, as the browser does
        for k = find(string({ev.type}) == evType)
            ev(k).sample = ev(k).sample + ev(k).duration - 1;
        end
    end

    cfg = [];
    cfg.hdr = D.hdr;                       % the rate
    if ~isfinite(cfg.hdr.nSamples), cfg.hdr.nSamples = Inf; end   % length unknown: keep every trial
    cfg.event = ev;
    cfg.trialfun = 'ft_trialfun_general';
    cfg.trialdef.eventtype = char(evType);
    cfg.trialdef.prestim = -win.pre;       % s before the event
    cfg.trialdef.poststim = win.post;      % s after it
    cfg = ft_definetrial(cfg);
    trl = cfg.trl;

    if isSpike(D)
        trl(:, 1:2) = trl(:, 1:2) - 1;     % samples -> 0-based timestamps
        cfg = []; cfg.trl = trl; cfg.timestampspersecond = D.hdr.Fs;
        spk = ft_spike_maketrials(cfg, D);
        cfg = []; cfg.binsize = psthBin;
        psth = ft_spike_psth(cfg, spk);
        fig = figure('Name', sprintf('%s: %d %s trials (FieldTrip)', D.cfg.name, size(trl, 1), evType), 'Color', 'w');
        ax = axes(fig);
        imagesc(ax, psth.time, 1:numel(psth.label), psth.avg);
        xline(ax, 0, 'w:');
        set(ax, 'YTick', 1:numel(psth.label), 'YTickLabel', psth.label, 'TickLabelInterpreter', 'none');
        xlabel(ax, sprintf('Time from %s (s)', evType)); ylabel(ax, 'Unit');
        cb = colorbar(ax); cb.Label.String = 'Spikes/s';
    else
        cfg.trl = trl(trl(:, 1) >= 1 & trl(:, 2) <= D.sampleinfo(2), :);
        trialsFT = ft_redefinetrial(cfg, D);
        cfg = []; cfg.artfctdef = D.cfg.artfctdef; cfg.artfctdef.reject = 'complete';
        trialsFT = ft_rejectartifact(cfg, trialsFT);
        tlSession = ft_timelockanalysis([], trialsFT);

        cfg = [];
        if ~isfield(D, 'elec'), cfg.layout = 'ordered'; end
        layout = ft_prepare_layout(cfg, D);
        cfg = [];
        cfg.layout = layout;
        cfg.parameter = 'avg';
        cfg.showlabels = 'yes';
        cfg.interactive = 'no';
        cfg.figurename = sprintf('%s: %d %s trials (FieldTrip)', D.cfg.name, numel(trialsFT.trial), evType);
        ft_multiplotER(cfg, tlSession);
    end
end
