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

%% 1. Epochs (R.epochs): a trial per epoch, trialinfo = [group in R.groupLabels, trial]
R = B.Result;
ftEpochs = {};

%% 2. Whole sessions (B.Sessions): one continuous trial, cfg.trl around TrialOnset
S = B.Sessions;
ftSessions = {};
if ~isempty(S)
    S = S(arrayfun(@(D) ~isempty(D.signal), S));   % "Load trials only" brings no signal
    win = B.Settings.window;
    ftSessions = sessionDataFieldTrip(S, Window=[win.pre win.post]);
    fprintf('ftSessions: %d datasets\n', numel(ftSessions));
end

%% Check and save
if ~FieldTripExport.hasFieldTrip()
    addpath('c:\src\fieldtrip\')
    ft_defaults;
end
for d = [ftEpochs; ftSessions].'
    [ok, msg] = FieldTripExport.validate(d{1}, "raw");
    if ~ok, fprintf('%s: %s\n', d{1}.cfg.name, msg), end
end

% With FieldTrip on the path:
cfg = []; cfg.method = 'mtmfft'; cfg.taper = 'hanning'; cfg.foi = 1:100;
cfg.trials = find(ftEpochs{1}.trialinfo(:, 1) == 1);   % the first group
freq = ft_freqanalysis(cfg, ftEpochs{1});

% and a session's trials, without those touching an erased period:
D = ftSessions{1};
cfg = []; cfg.trl = D.cfg.trl; trials = ft_redefinetrial(cfg, D);
cfg = []; cfg.artfctdef = D.cfg.artfctdef; cfg.artfctdef.reject = 'complete';
trials = ft_rejectartifact(cfg, trials);

for d = ftEpochs.'
    data = d{1};
    save(fullfile(outDir, d{1}.cfg.name + "_fieldtrip_epochs.mat"), 'data', '-v7.3');
end
for d = ftSessions.'
    data = d{1};
    save(fullfile(outDir, d{1}.cfg.name + "_fieldtrip_session.mat"), 'data', '-v7.3');
end
