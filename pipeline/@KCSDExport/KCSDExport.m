classdef KCSDExport
    % KCSDExport  Build kCSD-python inputs from this pipeline's data.
    %   Pure, static packaging functions: nothing here reads a recording or
    %   runs Python. They take the neutral inputs the pipeline already
    %   produces - the extract struct written by EphysDataset.toMat (Y,
    %   events, info) and a probe layout (EphysDataset.channelLayout) - and
    %   return the arrays kCSD-python's estimators take
    %   (https://github.com/Neuroinflab/kCSD-python):
    %       k = KCSD1D(ele_pos, pots, ...)    # or KCSD2D for a 2-D layout
    %   EphysDataset.exportKCSD writes them to a NumPy .npz (writeNPZ).
    %
    %   Conventions
    %   -----------
    %   - ele_pos: [n_ele x dim] electrode positions in mm, kCSD-python's
    %     unit (its tutorials, ValidateKCSD: mm, mV, S/m). dim 1 is the
    %     position along the shank (the probe's yc: larger = farther from
    %     the tip); dim 2 is (xc, yc). "auto" takes 1 when every electrode
    %     is on one shank and one column (one xc), else 2.
    %   - pots: [n_ele x n_time] LFP in mV (the extract's microvolts / 1000),
    %     row e for electrode e of ele_pos; sample i (0-based) is at t = i/fs
    %     seconds on the continuous clock (the extract's row i+1).
    %   - Electrodes: the LFP columns whose amplifier channel sits on the
    %     probe, less the bad channels the Signals step interpolated (an
    %     interpolated trace is not a measurement, and kCSD needs none on a
    %     missing site). Listed in probe order: by shank, then from the top
    %     of the shank down, then left to right (channelLayout's order).
    %   - Events: one row per dig-in pulse; onset_sample = round((t_on -
    %     1/eventFs)*fs), the 0-based LFP sample of the recording row that
    %     produced the onset (row = t*eventFs; t = row/eventFs), the same
    %     for the offset.
    %   - Artifacts: the periods erased before the signals were derived, as
    %     [tStart tEnd) seconds and as 0-based half-open [start stop) LFP
    %     samples covering every sample a period touches
    %     (EphysDataset.intervalRows), so pots[:, start:stop] is the erased
    %     stretch.
    %
    %   See also EphysDataset.exportKCSD, writeNPZ, EphysDataset.channelLayout.

    methods (Static)
        function E = electrodes(S, layout, opts)
            %electrodes  The kCSD electrodes of an extract's LFP on a probe.
            %   E = KCSDExport.electrodes(S, L) with S the toMat extract and
            %   L = ds.channelLayout(ProbeFile=...) gives
            %     column        [n x 1] 1-based LFP columns of S.Y.LFP, in probe order
            %     recordingChannel  [n x 1] their 1-based amplifier channels
            %     label, shank, x_um, y_um   [n x 1] per electrode
            %     dim           1 or 2
            %     ele_pos       [n x dim] mm (dim 1: y; dim 2: x, y)
            %     excluded      table (column, recordingChannel, label, reason)
            %                   of the LFP columns left out
            %   Dim="auto" (default) | 1 | 2 forces the layout's dimension.
            %   Errors: KCSDExport:NoProbe (no electrode on the probe),
            %   KCSDExport:TooFew (under dim + 1 electrodes, kCSD's minimum),
            %   KCSDExport:Duplicate (two electrodes at one position, which
            %   kCSD rejects: e.g. Dim=1 on a probe with several columns).
            arguments
                S (1,1) struct
                layout (1,1) struct
                opts.Dim = "auto"
            end
            dimOpt = string(opts.Dim);
            if ~ismember(dimOpt, ["auto" "1" "2"])
                error('KCSDExport:Dim', 'Dim must be "auto", 1 or 2.');
            end
            if ~isfield(S, 'Y') || ~isfield(S.Y, 'LFP') || isempty(S.Y.LFP)
                error('KCSDExport:SignalMissing', 'The extract holds no LFP signal.');
            end
            nCol = size(S.Y.LFP, 2);
            rec = KCSDExport.recordingChannels(S.info, nCol);
            labels = KCSDExport.labelsFor(S, nCol);

            onProbe = false(nCol, 1);
            shank = NaN(nCol, 1); x = NaN(nCol, 1); y = NaN(nCol, 1);
            if layout.hasProbe
                ok = rec >= 1 & rec <= numel(layout.x);
                shank(ok) = layout.shank(rec(ok));
                x(ok) = layout.x(rec(ok));
                y(ok) = layout.y(rec(ok));
                onProbe = isfinite(x) & isfinite(y);
            end
            bad = false(nCol, 1);
            if isfield(S.info, 'badChannels') && isstruct(S.info.badChannels) ...
                    && isfield(S.info.badChannels, 'channels')
                bad = ismember(rec, double(S.info.badChannels.channels(:)));
            end
            keep = onProbe & ~bad;

            reason = strings(nCol, 1);
            reason(~onProbe) = "not on the probe";
            reason(onProbe & bad) = "bad channel (interpolated by the Signals step)";
            gone = find(~keep);
            E.excluded = table(gone, rec(gone), labels(gone), reason(gone), ...
                'VariableNames', {'column', 'recordingChannel', 'label', 'reason'});

            if ~any(onProbe)
                error('KCSDExport:NoProbe', ...
                    'No LFP channel sits on the probe, so there are no electrode positions for kCSD.');
            end
            % probe order: shank, then top of the shank down, then left to right
            col = find(keep);
            [~, ord] = sortrows([shank(col), -y(col), x(col), col]);
            col = col(ord);

            if dimOpt == "auto"
                oneColumn = isscalar(uniquetol(x(col), 1e-3, 'DataScale', 1));   % within 1 nm
                dim = 2 - (isscalar(unique(shank(col))) && oneColumn);
            else
                dim = double(dimOpt);
            end
            if numel(col) < dim + 1
                error('KCSDExport:TooFew', ...
                    'kCSD needs at least %d electrodes for a %d-D layout; %d LFP channel(s) are on the probe and not bad.', ...
                    dim + 1, dim, numel(col));
            end
            if dim == 1
                pos = y(col);
            else
                pos = [x(col), y(col)];
            end
            [~, first, grp] = unique(round(pos * 1e3), 'rows', 'stable');   % um on a 1 nm grid
            if numel(first) < size(pos, 1)
                dupe = find(accumarray(grp, 1) > 1, 1);
                error('KCSDExport:Duplicate', ...
                    ['Electrodes %s share one position in %d-D (kCSD rejects duplicated electrodes). ' ...
                     'Use Dim=2, or leave all but one of them out.'], ...
                    strjoin(labels(col(grp == dupe)), ", "), dim);
            end

            E.column = col;
            E.recordingChannel = rec(col);
            E.label = labels(col);
            E.shank = shank(col);
            E.x_um = x(col);
            E.y_um = y(col);
            E.dim = dim;
            E.ele_pos = pos / 1000;                                         % um -> mm
            E = orderfields(E, {'column', 'recordingChannel', 'label', 'shank', 'x_um', 'y_um', 'dim', 'ele_pos', 'excluded'});
        end

        function P = pots(S, columns)
            %pots  The LFP of COLUMNS as kCSD potentials: [nSamples x n] single, mV.
            %   Row i is the extract's row i; transpose it for kCSD's
            %   [n_ele x n_time] (writeNPY Shape="transpose" writes it so
            %   without forming the transpose).
            P = single(S.Y.LFP(:, columns));
            P = P / 1000;                                                   % uV -> mV
        end

        function ev = events(events, fs, eventFs)
            %events  Dig-in pulses as flat arrays at the LFP rate FS.
            %   EV = KCSDExport.events(EVENTS, FS, EVENTFS) with EVENTS the
            %   extract's events (line -> [k x 2] [t_on t_off] seconds, t =
            %   row/EVENTFS) gives, one row per pulse sorted by onset:
            %     names      [nLines x 1] the line names
            %     line       [n x 1] 0-based index into names
            %     onset_s, offset_s        [n x 1] seconds (as in the extract)
            %     onset_sample, offset_sample  [n x 1] int64 0-based LFP samples:
            %                round((t - 1/EVENTFS)*FS), the sample of the
            %                recording row that produced the edge
            %   EVENTFS NaN (unknown) takes FS.
            arguments
                events
                fs (1,1) double {mustBePositive}
                eventFs (1,1) double
            end
            if ~isfinite(eventFs); eventFs = fs; end
            ev = struct('names', strings(0, 1), 'line', zeros(0, 1, 'int64'), ...
                'onset_s', zeros(0, 1), 'offset_s', zeros(0, 1), ...
                'onset_sample', zeros(0, 1, 'int64'), 'offset_sample', zeros(0, 1, 'int64'));
            if ~isstruct(events) || isempty(events); return; end
            fn = string(fieldnames(events));
            iv = zeros(0, 2); line = zeros(0, 1);
            for k = 1:numel(fn)
                t = double(events.(fn(k)));
                if isempty(t); continue; end
                if isvector(t) && numel(t) == 2; t = t(:).'; end
                iv = [iv; t(:, 1:2)]; %#ok<AGROW>
                line = [line; repmat(k - 1, size(t, 1), 1)]; %#ok<AGROW>
            end
            ev.names = fn(:);
            [~, ix] = sortrows([iv(:, 1), line]);
            iv = iv(ix, :);
            ev.line = int64(line(ix));
            ev.onset_s = iv(:, 1);
            ev.offset_s = iv(:, 2);
            ev.onset_sample = int64(round((iv(:, 1) - 1 / eventFs) * fs));
            ev.offset_sample = int64(round((iv(:, 2) - 1 / eventFs) * fs));
        end

        function A = artifacts(intervals, fs, nSamples)
            %artifacts  Artifact periods in seconds and as 0-based [start stop) LFP samples.
            %   A = KCSDExport.artifacts(IV, FS, N): IV the [k x 2] [tStart tEnd)
            %   second periods (the extract's info.artifacts.intervals); A.s is
            %   IV, A.samples [m x 2] int64 the merged sample ranges every
            %   period touches, pots[:, start:stop] in NumPy.
            arguments
                intervals (:,2) double
                fs (1,1) double {mustBePositive}
                nSamples (1,1) double
            end
            rows = EphysDataset.intervalRows(intervals, fs, nSamples);    % [first last], 1-based
            A = struct('s', intervals, 'samples', int64([rows(:, 1) - 1, rows(:, 2)]));
        end

        function rec = recordingChannels(info, nCol)
            %recordingChannels  1-based amplifier channel of each extract column.
            %   Column c is keepAmpChannels(channelRemap(c)), deriveSignals'
            %   order of operations; without either option it is channel c.
            rec = (1:nCol).';
            if ~isfield(info, 'importOptions') || ~isstruct(info.importOptions); return; end
            o = info.importOptions;
            k = []; r = [];
            if isfield(o, 'keepAmpChannels'); k = double(o.keepAmpChannels(:)); end
            if isfield(o, 'channelRemap');    r = double(o.channelRemap(:)); end
            if isempty(k); k = (1:max([nCol; r])).'; end
            if isempty(r); r = (1:numel(k)).'; end
            if numel(r) == nCol && all(r >= 1 & r <= numel(k))
                rec = k(r);
            end
        end
    end

    methods (Static, Access = private)
        function labels = labelsFor(S, nCol)
            %labelsFor  The LFP column labels (info.labels), "ch<c>" where missing.
            labels = "ch" + string((1:nCol).');
            if isfield(S.info, 'labels') && numel(S.info.labels) == nCol
                l = reshape(string(S.info.labels), [], 1);
                labels(l ~= "") = l(l ~= "");
            end
        end
    end
end
