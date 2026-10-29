%% DatasetBrowser LFP to FieldTrip
% A post-processing script of the DatasetBrowser (or run by hand with B in the
% workspace): it turns the browser's LFP into FieldTrip raw structures
% (ft_datatype_raw), one per dataset, in either of two ways:
%
%   1. Epochs: Data = LFP, "Keep single trials" ticked, Compute. Each epoch of
%      R.epochs becomes a FieldTrip trial, cut and processed as the browser
%      cut it (window, Detrend, Baseline): epochMatrixFieldTrip. -> ftEpochs
%   2. Whole sessions: Data = LFP, "Load whole sessions". Each dataset's whole
%      signal becomes one continuous trial, with its events, its erased
%      periods and the kept trials in the browser's window as cfg.trl:
%      sessionDataFieldTrip. -> ftSessions
%
% Either part runs when its data is there. FieldTrip itself is needed only to
% validate the structures and to analyze them. Works the same for MUA, SPIKE
% and AUX. The general builders behind both are FieldTripExport.epochs,
% .continuous and .trl, for any signal matrix.

if ~exist('B', 'var') || ~isa(B, 'DatasetBrowser')
    error('B is not a DatasetBrowser: run this from the browser (Post-processing script), or set B = DatasetBrowser.open(root) first.');
end
outDir = "";                    % a folder to save <dataset>_fieldtrip_*.mat in; "" keeps them in the workspace only
fieldTripPath = 'c:\src\fieldtrip\';   % added when FieldTrip is not on the path
trialEvent = "";                % the event line FieldTrip defines a session's trials on; "" takes the browser's

%% 1. Epochs (R.epochs): a trial per epoch, trialinfo = [group in R.groupLabels, trial]
R = B.Result;
ftEpochs = {};
if ~isempty(R) && R.rowKind == "channel" && isfield(R, 'epochs') && ~isempty(R.epochs)
    ftEpochs = epochMatrixFieldTrip(R);
    fprintf('ftEpochs: %d datasets, %d epochs, %s\n', numel(ftEpochs), ...
        sum(cellfun(@(d) numel(d.trial), ftEpochs)), R.labels.description);
end

%% 2. Whole sessions (B.Sessions): one continuous trial, cfg.trl around TrialOnset
S = B.Sessions;
ftSessions = {};
if ~isempty(S)
    S = S(arrayfun(@(D) ~isempty(D.signal), S));   % "Load trials only" brings no signal
    win = B.Settings.window;
    ftSessions = sessionDataFieldTrip(S, Window=[win.pre win.post]);
    fprintf('ftSessions: %d datasets\n', numel(ftSessions));
end

if isempty(ftEpochs) && isempty(ftSessions)
    error(['Nothing to convert: Compute a signal with "Keep single trials" ticked (B.Result.epochs), ' ...
        'or "Load whole sessions" (B.Sessions).']);
end

%% Check and save
if ~FieldTripExport.hasFieldTrip()
    addpath(fieldTripPath)
    ft_defaults;
end
for d = [ftEpochs; ftSessions].'
    [ok, msg] = FieldTripExport.validate(d{1}, "raw");
    if ~ok, fprintf('%s: %s\n', d{1}.cfg.name, msg), end
end

% With FieldTrip on the path, the spectrum of a dataset's epochs of the first group:
if ~isempty(ftEpochs)
    cfg = []; cfg.method = 'mtmfft'; cfg.taper = 'hanning'; cfg.foi = 1:100;
    cfg.trials = find(ftEpochs{1}.trialinfo(:, 1) == 1);
    freq = ft_freqanalysis(cfg, ftEpochs{1});
end

% and a session's trials, without those touching an erased period:
if ~isempty(ftSessions)
    D = ftSessions{1};
    cfg = []; cfg.trl = D.cfg.trl; trials = ft_redefinetrial(cfg, D);
    cfg = []; cfg.artfctdef = D.cfg.artfctdef; cfg.artfctdef.reject = 'complete';
    trials = ft_rejectartifact(cfg, trials);
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

%% Sample plots: every channel's evoked LFP at its probe site (ft_multiplotER)
% The layout comes from data.elec (the probe positions, laid out as on the
% probe); without positions the channels go on a grid ('ordered').

% The first dataset's epochs, one line per group:
if ~isempty(ftEpochs)
    data = ftEpochs{1};
    groups = unique(data.trialinfo(:, 1)).';
    tl = cell(1, numel(groups));
    for g = 1:numel(groups)
        cfg = [];
        cfg.trials = find(data.trialinfo(:, 1) == groups(g));
        tl{g} = ft_timelockanalysis(cfg, data);
    end
    groupNames = string(data.cfg.groupLabels(groups));
    colors = lines(numel(groups));

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

% A session's trials defined by FieldTrip from its events: ft_trialfun_general
% cuts the browser's window around every pulse of trialEvent in cfg.event
% (every pulse, not just the trials the browser keeps, as cfg.trl above
% does); the trials running off the signal or touching an erased period
% are dropped, the rest averaged.
if ~isempty(ftSessions)
    D = ftSessions{1};
    ev = D.cfg.event;
    evType = trialEvent;
    if evType == "", evType = B.Settings.ref.line; end
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
    cfg.hdr = D.hdr;                       % the signal's rate
    cfg.event = ev;
    cfg.trialfun = 'ft_trialfun_general';
    cfg.trialdef.eventtype = char(evType);
    cfg.trialdef.prestim = -win.pre;       % s before the event
    cfg.trialdef.poststim = win.post;      % s after it
    cfg = ft_definetrial(cfg);
    cfg.trl = cfg.trl(cfg.trl(:, 1) >= 1 & cfg.trl(:, 2) <= D.sampleinfo(2), :);
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