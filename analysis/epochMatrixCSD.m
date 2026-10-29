function P = epochMatrixCSD(R, opts)
%epochMatrixCSD  Laminar potentials of a signal result's epochs, by dataset and shank column, for a CSD estimate.
%   P = epochMatrixCSD(R) takes an epochMatrix result of a signal (data
%   "LFP", the usual; "MUA", "SPIKE" or "AUX" work the same) computed with
%   keepEpochs=true ("Keep single trials") and arranges its epochs along
%   the probe: a struct array, one element per laminar column of each
%   dataset of R.keys (laminarColumns of R.rows: a shank, or one x column of
%   a shank), in dataset then column order, with
%     key, name       the dataset
%     shank, x_um, depth_mm, h_mm, uniform, dim, pos_mm, label, channel
%                     the column (laminarColumns): depth_mm is each
%                     channel's distance below the column's top channel, mm,
%                     ascending; pos_mm the positions a 2-D estimate takes
%     rows            the channels' rows of R.rows (top down)
%     t               R.t, s from the event (a column)
%     fs              the epochs' rate, Hz
%     pots            [nChan x nTime x nGroups] double, V: the evoked
%                     potential of each group in R.groupLabels, the group's
%                     epochs averaged as R.data is (R.settings.signal.statistic:
%                     mean or median), channels top down. NaN where the
%                     dataset has no epochs in a group. These are R.data's
%                     rows before normalization, in V
%     epochs          [nChan x nTime x nEpochs] single, V: every epoch
%                     (R.epochs(k).data for the column's rows), for a
%                     single-trial estimate; E its epochs table, group each
%                     epoch's group (E.resultGroup)
%     groupLabels     R.groupLabels; nEpochs [nGroups x 1] the epochs per group
%     units           "V"
%     cfg             dataset, name, data, description, event, window,
%                     groupLabels, groups (R.labels.groups), scale (what
%                     divided the result's values to give V)
%   The potentials are what R.data averages: each epoch after Detrend,
%   Baseline, Magnitude and Rectify, never normalized, scaled from the
%   result's unit (uV, mV or V in R.rows.units, else R.valueUnits) to V.
%   Columns=, Shanks=, MinChannels= and Tolerance= go to laminarColumns.
%
%   The CSD of P(i) is then, with the toolboxes on the path,
%     [csd, z] = icsdEstimate(P(i).pots, P(i).depth_mm, Method="spline");
%     [csd, G] = kcsdEstimate(P(i).pos_mm, P(i).pots);
%   both in uA/mm^3 with z (G.x) in mm below the top channel.
%
%   Errors: epochMatrixCSD:NoEpochs, epochMatrixCSD:NotSignal (a spike
%   result), epochMatrixCSD:NoPositions (R.rows has no x, y),
%   epochMatrixCSD:NoColumn (no column of MinChannels placed channels),
%   epochMatrixCSD:Units (a unit that is not uV, mV or V).
%
%   See also laminarColumns, sessionDataCSD, icsdEstimate, kcsdEstimate,
%   epochMatrix, epochMatrixFieldTrip.

arguments
    R (1,1) struct
    opts.Columns (1,1) string = "auto"
    opts.Shanks double = []
    opts.MinChannels (1,1) double = 3
    opts.Tolerance (1,1) double = 1
end
if ~isfield(R, 'epochs') || isempty(R.epochs)
    error('epochMatrixCSD:NoEpochs', ...
        'The result keeps no epochs: compute with keepEpochs=true ("Keep single trials").');
end
if R.rowKind ~= "channel"
    error('epochMatrixCSD:NotSignal', ...
        'A CSD is estimated from a signal (data LFP, MUA, SPIKE or AUX), not from spikes (data %s).', R.settings.data);
end
if ~all(ismember(["x" "y"], string(R.rows.Properties.VariableNames)))
    error('epochMatrixCSD:NoPositions', 'R.rows has no x and y: the datasets have no probe positions.');
end
stat = "mean";
if isfield(R.settings, 'signal') && isfield(R.settings.signal, 'statistic')
    stat = string(R.settings.signal.statistic);
end
units = string(R.valueUnits);
if isfield(R, 'normalization') && isfield(R.normalization, 'rawUnits')
    units = string(R.normalization.rawUnits);
end
nG = numel(R.groupLabels);

P = emptyProfiles();
for k = 1:numel(R.epochs)
    e = R.epochs(k);
    ch = R.rows(e.rows, :);
    rowUnits = units;
    if ismember("units", string(ch.Properties.VariableNames)) && ~isempty(ch.units)
        u = string(ch.units);
        u = u(u ~= "" & ~ismissing(u));
        if ~isempty(u); rowUnits = u(1); end
    end
    scale = voltScale(rowUnits);
    cols = laminarColumns(ch, Columns=opts.Columns, Shanks=opts.Shanks, ...
        MinChannels=opts.MinChannels, Tolerance=opts.Tolerance);
    for c = cols.'
        p = struct();
        p.key = string(e.key);
        p.name = string(e.name);
        for f = ["shank" "x_um" "depth_mm" "h_mm" "uniform" "dim" "pos_mm" "label" "channel"]
            p.(f) = c.(f);
        end
        p.rows = reshape(e.rows(c.rows), [], 1);
        p.t = R.t(:);
        p.fs = 1 / median(diff(R.t));
        X = e.data(c.rows, :, :);                       % [nChan x nTime x nEpochs] single
        g = e.E.resultGroup;
        pots = NaN(numel(c.rows), numel(R.t), nG);
        n = zeros(nG, 1);
        for j = 1:nG
            in = g == j;
            n(j) = nnz(in);
            if n(j) == 0; continue; end
            if stat == "median"
                pots(:, :, j) = median(double(X(:, :, in)), 3, 'omitnan');
            else
                pots(:, :, j) = mean(double(X(:, :, in)), 3, 'omitnan');
            end
        end
        p.pots = pots * scale;
        p.epochs = X * single(scale);
        p.E = e.E;
        p.group = g(:);
        p.groupLabels = R.groupLabels;
        p.nEpochs = n;
        p.units = "V";
        p.cfg = struct('dataset', p.key, 'name', p.name, 'data', R.settings.data, ...
            'description', R.labels.description, 'event', R.labels.event, 'window', R.labels.window, ...
            'groupLabels', R.groupLabels, 'groups', R.labels.groups, 'scale', scale);
        P(end + 1, 1) = p; %#ok<AGROW>
    end
end
if isempty(P)
    error('epochMatrixCSD:NoColumn', ...
        'No dataset has a shank column of %d or more channels with probe positions.', opts.MinChannels);
end
end


function s = voltScale(units)
%voltScale  What multiplies a value in UNITS to give V.
switch lower(strtrim(units))
    case {"uv", "µv", "μv", "microvolt", "microvolts"}; s = 1e-6;
    case {"mv", "millivolt", "millivolts"};            s = 1e-3;
    case {"v", "volt", "volts"};                      s = 1;
    otherwise
        error('epochMatrixCSD:Units', 'The result''s unit "%s" is not a voltage (uV, mV or V).', units);
end
end


function P = emptyProfiles()
P = struct('key', {}, 'name', {}, 'shank', {}, 'x_um', {}, 'depth_mm', {}, 'h_mm', {}, 'uniform', {}, ...
    'dim', {}, 'pos_mm', {}, 'label', {}, 'channel', {}, 'rows', {}, 't', {}, 'fs', {}, 'pots', {}, ...
    'epochs', {}, 'E', {}, 'group', {}, 'groupLabels', {}, 'nEpochs', {}, 'units', {}, 'cfg', {});
end
