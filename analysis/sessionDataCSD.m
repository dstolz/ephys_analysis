function P = sessionDataCSD(D, opts)
%sessionDataCSD  Laminar potentials of whole sessions, by dataset and shank column, for a CSD estimate.
%   P = sessionDataCSD(D) takes sessionData structs of a signal
%   (DatasetBrowser's B.Sessions after Load whole sessions with data LFP,
%   MUA, SPIKE or AUX) and arranges each session's signal along the probe:
%   a struct array, one element per laminar column of each session
%   (laminarColumns of D.channels), in session then column order, with
%     key, name       the dataset
%     shank, x_um, depth_mm, h_mm, uniform, dim, pos_mm, label, channel
%                     the column (laminarColumns): depth_mm is each
%                     channel's distance below the column's top channel, mm
%     rows            the channels' columns of D.signal (top down)
%     fs              the signal's rate, Hz
%     signal          [nChan x nSamples] single, V: the whole signal of the
%                     column's channels, sample k at (k-1)/fs on the
%                     continuous clock
%     artifacts       [k x 2] s, the periods the Signals step erased
%     events          the session's events on the continuous clock
%                     (D.eventsContinuous: line -> [t_on t_off])
%     units           "V"
%     cfg             dataset, name, data, groups (the session's groups
%                     table), scale (what multiplied the signal to give V)
%   and, with Window=[pre post] (s), the kept trials cut around Align (a
%   column of D.trials on the digital clock, "TrialOnset" by default) as
%   epochMatrixCSD gives a result's epochs:
%     t               s from the event (a column)
%     epochs          [nChan x nTime x nTrials] single, V: each kept trial
%                     whose window lies on the signal and touches no
%                     artifact (mTRFExport.trials)
%     trial, group    [nTrials x 1] each epoch's row of D.trials and its
%                     row of cfg.groups
%     pots            [nChan x nTime x nGroups] double, V: the trials of
%                     each group averaged (Statistic "mean", default, or
%                     "median"); NaN for a group without trials
%     groupLabels     cfg.groups.label; nEpochs [nGroups x 1]
%   Columns=, Shanks=, MinChannels= and Tolerance= go to laminarColumns.
%
%   A kCSD of a stretch of the whole signal, e.g. the first 2 s:
%     p = P(1); i = 1:round(2 * p.fs);
%     [csd, G] = kcsdEstimate(p.pos_mm, p.signal(:, i));
%
%   Errors: sessionDataCSD:NoSignal (spike data or "Load trials only"),
%   sessionDataCSD:NoPositions, sessionDataCSD:NoColumn,
%   sessionDataCSD:NoTrials (Window given, no trials with an Align column),
%   sessionDataCSD:Units.
%
%   See also laminarColumns, epochMatrixCSD, icsdEstimate, kcsdEstimate,
%   sessionData, sessionDataFieldTrip.

arguments
    D struct
    opts.Window double = []
    opts.Align (1,1) string = "TrialOnset"
    opts.Statistic (1,1) string {mustBeMember(opts.Statistic, ["mean" "median"])} = "mean"
    opts.Columns (1,1) string = "auto"
    opts.Shanks double = []
    opts.MinChannels (1,1) double = 3
    opts.Tolerance (1,1) double = 1
end
P = struct([]);
for k = 1:numel(D)
    d = D(k);
    if isempty(d.signal)
        error('sessionDataCSD:NoSignal', '%s holds no signal (data "%s"): load whole sessions of a signal.', d.name, d.data);
    end
    ch = d.channels;
    if ~all(ismember(["x" "y"], string(ch.Properties.VariableNames)))
        error('sessionDataCSD:NoPositions', '%s''s channels have no x and y: the dataset has no probe positions.', d.name);
    end
    scale = voltScale(firstUnits(ch), d.name);
    cols = laminarColumns(ch, Columns=opts.Columns, Shanks=opts.Shanks, ...
        MinChannels=opts.MinChannels, Tolerance=opts.Tolerance);
    fs = d.signalFs;
    cut = ~isempty(opts.Window);
    if cut
        if ~d.hasTrials || ~ismember(opts.Align, string(d.trials.Properties.VariableNames))
            error('sessionDataCSD:NoTrials', '%s has no trials with a %s column.', d.name, opts.Align);
        end
        idx = find(d.kept);
        on = d.toContinuous(d.trials.(opts.Align)(idx));
        nG = height(d.groups);
    end
    for c = cols.'
        p = struct();
        p.key = string(d.key);
        p.name = string(d.name);
        for f = ["shank" "x_um" "depth_mm" "h_mm" "uniform" "dim" "pos_mm" "label" "channel"]
            p.(f) = c.(f);
        end
        p.rows = c.rows;
        p.fs = fs;
        p.signal = single(d.signal(:, c.rows)).' * single(scale);
        p.artifacts = d.artifacts;
        p.events = d.eventsContinuous;
        p.units = "V";
        p.cfg = struct('dataset', p.key, 'name', p.name, 'data', d.data, 'groups', d.groups, 'scale', scale);
        if cut
            [C, keep, t] = mTRFExport.trials(d.signal(:, c.rows), fs, on, opts.Window, Artifacts=d.artifacts);
            p.t = t(:);
            X = zeros(numel(c.rows), numel(t), numel(C), 'single');
            for j = 1:numel(C); X(:, :, j) = single(C{j}).'; end
            p.epochs = X * single(scale);
            p.trial = idx(keep);
            p.group = d.group(p.trial);
            pots = NaN(numel(c.rows), numel(t), nG);
            n = zeros(nG, 1);
            for j = 1:nG
                in = p.group == j;
                n(j) = nnz(in);
                if n(j) == 0; continue; end
                if opts.Statistic == "median"
                    pots(:, :, j) = median(double(X(:, :, in)), 3, 'omitnan');
                else
                    pots(:, :, j) = mean(double(X(:, :, in)), 3, 'omitnan');
                end
            end
            p.pots = pots * scale;
            p.groupLabels = string(d.groups.label);
            p.nEpochs = n;
        end
        if isempty(P); P = p; else; P(end + 1, 1) = p; end %#ok<AGROW>
    end
end
if isempty(P)
    error('sessionDataCSD:NoColumn', ...
        'No session has a shank column of %d or more channels with probe positions.', opts.MinChannels);
end
P = P(:);
end


function u = firstUnits(ch)
u = "uV";
if ismember("units", string(ch.Properties.VariableNames)) && ~isempty(ch.units)
    s = string(ch.units);
    s = s(s ~= "" & ~ismissing(s));
    if ~isempty(s); u = s(1); end
end
end


function s = voltScale(units, name)
switch lower(strtrim(units))
    case {"uv", "µv", "μv", "microvolt", "microvolts"}; s = 1e-6;
    case {"mv", "millivolt", "millivolts"};            s = 1e-3;
    case {"v", "volt", "volts"};                      s = 1;
    otherwise
        error('sessionDataCSD:Units', '%s''s signal unit "%s" is not a voltage (uV, mV or V).', name, units);
end
end
