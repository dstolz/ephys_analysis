%% DatasetBrowser to Chronux
% A post-processing script of the DatasetBrowser (or run by hand with B in the
% workspace): it turns the browser's spikes or signal into the inputs Chronux
% takes, one struct per dataset, in either of two ways:
%
%   1. Epochs: "Keep single trials" ticked, Compute. Each epoch of R.epochs
%      becomes a Chronux trial, cut as the browser cut it. -> cxEpochs{k}
%        signal (LFP, MUA, SPIKE, AUX): data [nTime x nEpochs x nChan], for
%          mtspectrumc / mtspecgramc / coherencyc on data(:, :, c)
%        spikes (units, detected): sp{u}, a 1 x nEpochs struct array with
%          field times, for mtspectrumpt / mtspecgrampt / coherencypt
%   2. Whole sessions: "Load whole sessions". Each dataset on its own clock,
%      with its kept trials cut in the browser's window around TrialOnset.
%      -> cxSessions{k}
%        signal: cx, a ChronuxDataset holding the whole signal (cx.continuous,
%          cx.trials), and trials [nTime x nTrials x nChan]
%        spikes: sp, every unit over the whole session, and trials{u}, each
%          unit cut into one Chronux trial per kept trial
%
% Either part runs when its data is there; the last section plots one unit's
% spectrogram with mtspecgrampt when there are spikes and Chronux is on the path. The cutting and the params come
% from ChronuxDataset; Chronux itself is needed only for the analysis.
% Every struct carries params (Chronux's params, trialave = 1: Chronux averages
% the trials) and t, the time grid to pass along (mtspectrumpt(sp, params, 0, t)).
% Each trial's group is in group (a row of groupLabels, as in R.data).
%
% Clocks: spikes and signals are on the continuous clock (sample k at
% (k-1)/fs). Trial times are on the digital clock, so they go through
% D.toContinuous first.

if ~exist('B', 'var') || ~isa(B, 'DatasetBrowser')
    error('B is not a DatasetBrowser: run this from the browser (Post-processing script), or set B = DatasetBrowser.open(root) first.');
end
outDir = "";            % a folder to save <dataset>_chronux_*.mat in; "" keeps them in the workspace only
spikeFs = 1000;         % Hz, the point-process grid: params.Fs and t for spikes
tapers = [3 5];         % [TW K], see ChronuxDataset.tapersFor
pad = 0;                % FFT padding
fpass = [0 Inf];        % Hz; Inf = Nyquist
err = 0;                % 0 | [1 p] theoretical | [2 p] jackknife
dropArtifacts = true;   % whole sessions: drop the trials whose window touches an erased period
hasChronux = ChronuxDataset.hasChronux();

%% 1. Epochs (R.epochs) -> one Chronux struct per dataset, a trial per epoch
R = B.Result;
cxEpochs = {};
if ~isempty(R) && ~isempty(R.epochs)
    isUnit = R.rowKind == "unit";
    if isUnit
        % the spikes were kept inside the window's whole bins: that span is
        % the trial, and its start is time 0 of the spike stamps
        bin = R.settings.binSec;
        span = [ceil(R.settings.window.pre / bin - 1e-9), floor(R.settings.window.post / bin + 1e-9)] * bin;
        fs = spikeFs;
        t = (0:round(diff(span) * fs)) / fs;
    else
        fs = 1 / mean(diff(R.t));
        span = R.t([1 end]).';
        t = R.t(:).' - R.t(1);
    end
    params = ChronuxDataset.makeParams(fs, Tapers=tapers, Pad=pad, Fpass=fpass, Err=err, TrialAve=1);

    cxEpochs = cell(numel(R.epochs), 1);
    for k = 1:numel(R.epochs)
        e = R.epochs(k);
        c = struct();
        c.key = e.key;
        c.name = e.name;
        c.rows = R.rows(e.rows, :);
        c.labels = string(c.rows.label).';
        c.group = e.E.resultGroup;              % each trial's group in R.groupLabels
        c.trial = e.E.trial;                    % its trial number in the session
        c.groupLabels = R.groupLabels;
        c.window = span;                        % s from the event; trial time 0 = span(1)
        c.t = t;
        c.params = params;
        if isUnit
            nE = height(e.E);
            c.sp = cell(1, numel(e.spikes));
            for u = 1:numel(e.spikes)
                s = e.spikes(u);
                c.sp{u} = ChronuxDataset.toPointProcess(accumarray(s.epoch(:), s.times(:) - span(1), ...
                    [nE 1], @(x) {sort(x)}, {zeros(0, 1)}));
            end
        else
            c.data = permute(double(e.data), [2 3 1]);   % [nTime x nEpochs x nChan]
            c.units = R.valueUnits;
        end
        cxEpochs{k} = c;
    end
    fprintf('cxEpochs: %d datasets, %d epochs, %s\n', numel(cxEpochs), ...
        sum(cellfun(@(c) numel(c.trial), cxEpochs)), R.labels.description);
end

%% 2. Whole sessions (B.Sessions) -> one Chronux struct per dataset
S = B.Sessions;
cxSessions = {};
w = B.Settings.window;
win = [w.pre w.post];   % the browser's epoch window, s, for the trials
if ~isempty(S) && any(arrayfun(@(D) ~isempty(D.signal) || ~isempty(D.spikes), S))
    cxSessions = cell(numel(S), 1);
    for k = 1:numel(S)
        D = S(k);
        isSignal = ~isempty(D.signal);
        if ~isSignal && isempty(D.spikes), continue, end

        c = struct();
        c.key = D.key;
        c.name = D.name;
        c.data = D.data;
        c.groupLabels = D.groups;
        c.window = win;
        c.artifacts = D.artifacts;

        % the kept trials, aligned to TrialOnset (not the browser's event: use
        % D.eventsContinuous.<line>(:, 1) for that) on the continuous clock
        idx = [];
        if D.hasTrials
            idx = find(D.kept);
            on = D.toContinuous(D.trials.TrialOnset(idx));
            if dropArtifacts && ~isempty(D.artifacts)
                a = D.artifacts;
                touch = any(on + win(1) < a(:, 2).' & on + win(2) > a(:, 1).', 2);
                idx = idx(~touch);
                on = on(~touch);
            end
        end

        if isSignal
            % the connector holds the signal; ask it for any stretch or channel
            c.cx = ChronuxDataset(D.signal, Fs=D.signalFs, Signal=D.data, ...
                ChannelLabels=string(D.channels.label).', Tapers=tapers, Pad=pad, Fpass=fpass, Err=err);
            c.channels = D.channels;
            c.labels = string(D.channels.label).';
            c.units = unique(string(D.channels.units));
            c.params = c.cx.params();           % for cx.continuous's data
            if ~isempty(idx)
                % the onsets are continuous-clock times: OnsetRule "sample"
                [X, p, T, info] = c.cx.trials(on, win, OnsetRule="sample", TrialAve=1);
                c.trials = X;                   % [nTime x nTrials x nChan]
                c.trialParams = p;
                c.t = T;                        % s from the onset
                c.trial = idx(info.keptTrials);
                c.group = D.group(c.trial);
            end
        else
            cx = ChronuxDataset(SpikeFs=spikeFs, Tapers=tapers, Pad=pad, Fpass=fpass, Err=err);
            c.units = D.units;
            c.labels = string(D.units.label).';
            [c.sp, c.params, c.t] = cx.spikes(Times=D.spikes, TimeRange=[0 D.durationSec]);
            if ~isempty(idx)
                c.trials = cell(1, numel(c.sp));
                for u = 1:numel(c.sp)
                    [c.trials{u}, c.trialParams, c.trialT, info] = cx.spikeTrials(on, win, ...
                        Spikes=c.sp, Unit=u, TrialAve=1);
                end
                c.trial = idx(info.keptTrials);   % the same trials for every unit
                c.group = D.group(c.trial);
            end
        end
        cxSessions{k} = c;
    end
    fprintf('cxSessions: %d datasets\n', nnz(~cellfun(@isempty, cxSessions)));
end

%% Use and save
if ~hasChronux, disp('Chronux is not on the path: add toolboxes/chronux to analyze.'), end

% With Chronux on the path, an epoch result, first group:
%   c = cxEpochs{1}; g = c.group == 1;
%   [S, f] = mtspectrumc(c.data(:, g, 1), c.params);                % signal, first channel
%   [S, f, R] = mtspectrumpt(c.sp{1}(g), c.params, 0, c.t);         % spikes, first unit
%   [S, t, f] = mtspecgramc(c.data(:, g, 1), [0.5 0.05], c.params); % t from c.window(1)
% and a whole session:
%   c = cxSessions{1};
%   [x, p] = c.cx.continuous(Channels=1, TimeRange=[60 120]);       % signal, any stretch
%   [S, f] = mtspectrumc(x, p);
%   [S, f, R] = mtspectrumpt(c.trials{1}(c.group == 1), c.trialParams, 0, c.trialT);   % spikes, a unit's trials

if outDir ~= ""
    for k = 1:numel(cxEpochs)
        c = cxEpochs{k};
        save(fullfile(outDir, cxEpochs{k}.name + "_chronux_epochs.mat"), '-struct', 'c', '-v7.3');
    end
    for k = 1:numel(cxSessions)
        if isempty(cxSessions{k}), continue, end
        c = cxSessions{k};
        if isfield(c, 'cx')
            % the connector is a handle: save its signal and params instead
            c.signal = c.cx.Data;
            c.fs = c.cx.Fs;
            c = rmfield(c, 'cx');
        end
        save(fullfile(outDir, c.name + "_chronux.mat"), '-struct', 'c', '-v7.3');
    end
end

%% Example plot: one unit's spike spectrogram, a tile per group (mtspecgrampt)
% The busiest unit of the first dataset with spikes: from its epochs when there
% are any, else from a whole session's trials. The spike stamps start at 0 at
% the window's start, so c.window(1) moves the times back to the event.
% mtspecgrampt places its windows from the first to the last spike of the
% trials it is given, not over the whole window, so a group's image may start
% late or end early.
movingwin = [0.25 0.025];   % [window step] s; the half-bandwidth is tapers(1) / movingwin(1) Hz
plotFpass = [0 100];        % Hz shown
src = {};
if ~isempty(cxEpochs) && isfield(cxEpochs{1}, 'sp')
    src = cxEpochs;
elseif ~isempty(cxSessions)
    src = cxSessions(cellfun(@(c) isfield(c, 'trials') && iscell(c.trials), cxSessions));
end


fig = figure('Name', "Spike spectrogram " + c.labels(u), 'Color', 'w');
tl = tiledlayout(fig, 'flow', 'TileSpacing', 'compact');

for si = 1:length(src)
    c = src{si};
    if iscell(c.sp)
        trains = c.sp; p = c.params;            % epochs
    else
        trains = c.trials; p = c.trialParams;   % a session's trials
    end
    [~, u] = max(cellfun(@(tr) numel(vertcat(tr.times)), trains));
    p.fpass = [plotFpass(1) min(plotFpass(2), p.Fs / 2)];
    p.err = 0;

    axs = gobjects(0); clims = [Inf -Inf];
    for g = unique(c.group(c.group > 0)).'
        if istable(c.groupLabels); gl = string(c.groupLabels.label(g)); else; gl = string(c.groupLabels(g)); end
        tr = trains{u}(c.group == g);
        ax = nexttile(tl);
        allT = vertcat(tr.times);
        if numel(allT) < 2 || max(allT) - min(allT) < movingwin(1)
            text(ax, 0.5, 0.5, 'too few spikes', 'Units', 'normalized', 'HorizontalAlignment', 'center');
        else
            [Sg, tn, f] = mtspecgrampt(tr, movingwin, p, 1);   % trials averaged (trialave = 1)
            img = 10 * log10(Sg).';                             % [nFreq x nTime], dB
            imagesc(ax, tn + c.window(1), f, img);
        end
        title(ax, sprintf('%s (%d trials)', gl, numel(tr)), 'Interpreter', 'none');   % after imagesc, which resets the axes
        if numel(allT) < 2 || max(allT) - min(allT) < movingwin(1), continue, end
        axis(ax, 'xy');
        xlim(ax, c.window);
        xline(ax, 0, 'w', LineWidth=1);
        axs(end+1) = ax; %#ok<SAGROW>
        clims = [min(clims(1), min(img(isfinite(img)))), max(clims(2), max(img(isfinite(img))))];
    end
end

if ~isempty(axs)
    set(axs, 'CLim', clims);                            % one color scale for every group
    cb = colorbar(axs(end));
    cb.Layout.Tile = 'east';
    cb.Label.String = '10 log_{10} S';
end
xlabel(tl, 'Time from the event (s)');
ylabel(tl, 'Frequency (Hz)');