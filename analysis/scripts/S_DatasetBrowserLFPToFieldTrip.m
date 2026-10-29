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

%% A sample plot: the first dataset's evoked LFP per group and its spectrum
% ft_timelockanalysis averages the epochs; ft_singleplotER averages the
% channels (cfg.channel = 'all'); give it a channel label to see that one.
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
    figure('Name', data.cfg.name + " (FieldTrip)");
    subplot(2, 1, 1)
    cfg = []; cfg.figure = 'gca'; cfg.interactive = 'no'; cfg.channel = 'all';
    ft_singleplotER(cfg, tl{:});
    xlabel('Time from event (s)'); ylabel("LFP (" + string(data.hdr.chanunit{1}) + ")")
    title(data.cfg.name + ": mean of " + numel(data.label) + " channels", 'Interpreter', 'none')
    legend(groupNames, 'Interpreter', 'none', 'Location', 'best')
    subplot(2, 1, 2)
    cfg = []; cfg.figure = 'gca'; cfg.interactive = 'no'; cfg.channel = 'all'; cfg.parameter = 'powspctrm';
    ft_singleplotER(cfg, freq);
    set(gca, 'YScale', 'log'); xlabel('Frequency (Hz)'); ylabel('Power')
    title("Spectrum, " + groupNames(1) + " (mtmfft, Hanning)", 'Interpreter', 'none')
end

%%
cfg = [];
cfg.figure = 'gca';
cfg.interactive = 'no';
cfg.channel = 'all';
cfg.parameter = 'avg';
ft_multiplotER(cfg,tl{:})