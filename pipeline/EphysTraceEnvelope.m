classdef EphysTraceEnvelope < handle
    % EphysTraceEnvelope  Min / max pyramid of one EphysTraceSource, cached next to the dataset's outputs.
    %   The Visualize tab's viewer (EphysTraceViewer) reads a view at full
    %   rate, so a view of the samples is at most MaxReadSamples (2^27
    %   samples x channels, about 70 s of 64 channels at 30 kHz) wide. An
    %   envelope holds the min and max of every channel over blocks of
    %   samples, the blocks growing level by level, so a view of any width -
    %   the whole recording - is drawn from a few thousand blocks, and the
    %   overview strip can show the signal itself:
    %
    %     env = EphysTraceEnvelope(src);      % src: an EphysTraceSource
    %     env.start();                         % build it in the background
    %     env.build();                         % or here, blocking
    %     [mn, mx] = env.read(level, k0, n, cols);
    %
    %   Levels
    %   ------
    %   Level 1 has blocks of Blocks(1) samples; each further level takes
    %   the min / max of Factor (4) blocks of the one before, up to the
    %   first level of at most MaxLevelBlocks (4096) blocks. Block k (0-based)
    %   of a level of B samples holds rows k*B .. k*B+B-1 (0-based) of every
    %   channel (the last block what is left) and is drawn at its first
    %   sample, k*B/Fs s, as the viewer draws a bin. Blocks(1) is a power of
    %   two (blockSizes): about one block per pixel column of a 4096-pixel
    %   plot for a view just wider than one full-rate read, coarser when
    %   level 1 would hold more than 2^24 blocks x channels (128 MB), finer
    %   when it would have fewer than 2048 blocks (a short source). A view
    %   is drawn from the coarsest level whose blocks are no longer than the
    %   samples of one pixel column (levelFor).
    %
    %   The cache file
    %   --------------
    %   One per source (fileFor), next to the dataset's other outputs:
    %   <outputFolder>/<Name>_envelope_<what>.dat, <what> "recording" (as
    %   stored), "recording_car" / "recording_cmr" (with the dataset's
    %   common reference, as every step reads it), "bin" (the Sorting .bin)
    %   or the signal's type (LFP, MUA, SPIKE, AUX). Its JSON header holds the
    %   Fingerprint: the source's stamp (its files with their sizes and
    %   modified times, rows, channels, rate, the reference subtracted and
    %   its channels, the .bin's scale) and the block sizes. A file whose
    %   fingerprint does not match is never read: State is then "missing"
    %   and a build writes a new one in its place. The layout is in
    %   documentation/file-formats.md.
    %
    %   Building
    %   --------
    %   start() builds it without blocking MATLAB, a span of the source at a
    %   time: on a thread of backgroundPool (parfeval) for the recording and
    %   the .bin, else (a signal: h5read does not run on a thread) a span per
    %   tick of a timer, which leaves MATLAB free between ticks. A span is
    %   read through the source's own read() - so the reference and the
    %   .bin's filled artifact periods are those the viewer draws at full
    %   rate - in pieces of at most PieceValues samples x channels, each
    %   reduced at once, so the memory used stays bounded whatever the
    %   length. MATLAB writes the blocks into <file>.<token>.partial, renamed
    %   to the file once the last span is in, so the file is always whole.
    %   ProgressFcn(env) hears each span, DoneFcn(env) the end (State
    %   "ready" or "failed"). cancel() stops a build and deletes its partial
    %   file, and so does deleting the object. build() builds it here,
    %   blocking. isReady() looks at the .bin or extract file again (at most
    %   once a second): written again since, the envelope is "stale" and
    %   the viewer makes a new one.
    %
    %   See also EphysTraceViewer, EphysTraceSource.stamp, backgroundPool.

    properties (SetAccess = private)
        Source = []                            % the EphysTraceSource
        SourceKey (1,1) string = ""            % Source.key() when it was made (or rebound)
        File (1,1) string = ""                 % the cache file
        Fingerprint (1,1) string = ""          % JSON: what the blocks depend on
        Blocks (1,:) double = double.empty(1, 0)      % samples per block of each level, finest first
        NumBlocks (1,:) double = double.empty(1, 0)   % blocks of each level
        State (1,1) string = "missing"         % "missing" | "building" | "ready" | "failed" | "stale"
        Progress (1,1) double = 0              % share of the source built (0 .. 1)
        Message (1,1) string = ""              % why it failed or stopped, or how long it took
        OnThreads (1,1) logical = false        % the build runs on backgroundPool
    end

    properties
        ProgressFcn = []                       % f(env) after each span
        DoneFcn = []                           % f(env) when a build ends ("ready" or "failed")
        PieceValues (1,1) double = 2^23        % samples x channels read at once
        Period (1,1) double = 0.05             % pause between the ticks of a timer build (s)
    end

    properties (Constant)
        Schema = "ephys-envelope/1"
        Magic = 'EPHYSENV'                     % the file's first 8 bytes
        Factor = 4                             % blocks of a level in one block of the next
        MaxLevelBlocks = 4096                  % the coarsest level has no more blocks
        MinBaseBlocks = 2048                   % level 1 has at least these (a short source)
        MaxBaseValues = 2^24                   % level 1 holds at most these blocks x channels
        FullReadValues = 2^27                  % the widest full-rate read (EphysTraceViewer.MaxReadSamples)
        PlotPixels = 4096                      % columns of the widest plot level 1 serves
    end

    properties (Access = private)
        UseThreads (1,1) logical = true
        Header uint8 = uint8.empty(1, 0)       % the file's header bytes (a build)
        DataStart (1,1) double = 0             % bytes before level 1
        Checked = []                           % tic of the last look at the source's file
        Spans = zeros(0, 2)                    % rows [a z) of each span to build
        Next (1,1) double = 0                  % the step to take next (0: size the file)
        Partial (1,1) string = ""              % the file being written
        Future = []                            % the background step under way
        StepId (1,1) double = 0                % its number: a later one (or a cancel) makes it stale
        Timer = []
        Started = []
    end

    methods
        function obj = EphysTraceEnvelope(src, opts)
            %EphysTraceEnvelope  The envelope of SRC: State "ready" when its cache file holds it.
            %   Options: File (default fileFor(SRC)); Blocks, the samples
            %   per block of each level, B * Factor.^(0:L-1) for a whole B
            %   (default blockSizes); UseThreads (default true: the
            %   recording and the .bin are built on backgroundPool; false:
            %   on a timer, as a signal is).
            arguments
                src (1,1) EphysTraceSource
                opts.File (1,1) string = ""
                opts.Blocks (1,:) double = []
                opts.UseThreads (1,1) logical = true
            end
            f = EphysTraceEnvelope.Factor;
            blocks = opts.Blocks;
            if isempty(blocks)
                blocks = EphysTraceEnvelope.blockSizes(src.NumSamples, src.NumChannels);
            elseif ~(blocks(1) >= 1 && blocks(1) == round(blocks(1)) ...
                    && isequal(blocks, blocks(1) * f .^ (0:numel(blocks) - 1)))
                error('EphysTraceEnvelope:Blocks', 'Blocks must be B * %d.^(0:L-1) for a whole B.', f);
            end
            obj.Source = src;
            obj.SourceKey = src.key();
            obj.Blocks = blocks;
            obj.NumBlocks = ceil(src.NumSamples ./ blocks);
            obj.File = opts.File;
            if obj.File == ""
                obj.File = EphysTraceEnvelope.fileFor(src);
            end
            obj.UseThreads = opts.UseThreads;
            obj.Fingerprint = obj.fingerprintOf(src);
            obj.check();
        end

        function delete(obj)
            obj.cancel();
        end

        function tf = isReady(obj)
            %isReady  True when the cache file holds this envelope (State "ready").
            %   The .bin or extract file read is looked at again at most once
            %   a second: written again since the envelope was made, it is
            %   out of date (State "stale").
            tf = obj.State == "ready";
            if ~tf || obj.Source.Kind == "recording" || (~isempty(obj.Checked) && toc(obj.Checked) < 1)
                return
            end
            obj.Checked = tic;
            if obj.fingerprintOf(obj.Source) ~= obj.Fingerprint || ~isfile(obj.File)
                obj.State = "stale";
                obj.Message = obj.Source.Name + " was written again since its envelope was built";
                tf = false;
            end
        end

        function tf = rebind(obj, src)
            %rebind  Read SRC from now on when it is the same signal: TF false (nothing changed) when not.
            %   The same signal: SRC's envelope would be this one (the same
            %   file and fingerprint), e.g. a source made again by Reload data.
            tf = EphysTraceEnvelope.fileFor(src) == obj.File && obj.fingerprintOf(src) == obj.Fingerprint;
            if tf
                obj.Source = src;
                obj.SourceKey = src.key();
            end
        end

        function start(obj)
            %start  Build the envelope in the background; nothing when it is ready, being built or stale.
            if obj.State ~= "missing" && obj.State ~= "failed"; return; end
            obj.OnThreads = obj.UseThreads && obj.Source.threadSafe();
            obj.prepare();
            if obj.OnThreads
                try
                    obj.submit(0);
                    return
                catch
                    obj.OnThreads = false;    % no background pool here: a timer
                    obj.planSpans(0);
                end
            end
            obj.startTimer();
        end

        function build(obj)
            %build  Build the envelope here, blocking (nothing when it is ready).
            if obj.State == "ready"; return; end
            obj.cancel();
            obj.OnThreads = false;
            obj.prepare();
            try
                EphysTraceEnvelope.allocate(obj.Partial, obj.Header, obj.DataStart + obj.totalBytes(), Inf);
                for k = 1:size(obj.Spans, 1)
                    s = obj.Spans(k, :);
                    [MN, MX] = EphysTraceEnvelope.reduceSpan(obj.Source, s(1), s(2), obj.Blocks, obj.PieceValues);
                    obj.spanBuilt(k, MN, MX);
                end
                if obj.State == "building"   % a source with no rows
                    obj.finish();
                end
            catch ME
                obj.fail(ME);
                rethrow(ME);
            end
        end

        function cancel(obj)
            %cancel  Stop a build: its partial file is deleted, State "missing" again.
            if obj.State ~= "building"; return; end
            obj.State = "missing";
            obj.Message = "cancelled";
            obj.stopWork();
        end

        function [mn, mx] = read(obj, level, k0, n, cols)
            %read  Blocks K0 .. K0+N-1 (0-based) of LEVEL, channels COLS: [n x numel(COLS)] single each.
            %   Clipped to the level. The envelope must be ready.
            if obj.State ~= "ready"
                error('EphysTraceEnvelope:NotReady', 'The envelope of %s is not built (%s).', ...
                    obj.Source.Name, obj.State);
            end
            nC = obj.Source.NumChannels;
            k0 = max(0, floor(k0));
            n = min(floor(n), obj.NumBlocks(level) - k0);
            if n <= 0
                mn = zeros(0, numel(cols), 'single');
                mx = mn;
                return
            end
            fid = fopen(obj.File, 'r', 'ieee-le');
            if fid < 0
                error('EphysTraceEnvelope:Open', 'Could not open %s.', obj.File);
            end
            closer = onCleanup(@() fclose(fid));
            fseek(fid, obj.levelStart(level) + k0 * 8 * nC, 'bof');
            X = fread(fid, [2 * nC, n], '*single');
            if size(X, 2) < n
                error('EphysTraceEnvelope:Short', 'Only %d of %d blocks could be read from %s.', ...
                    size(X, 2), n, obj.File);
            end
            mn = X(cols, :).';
            mx = X(nC + cols, :).';
        end

        function L = levelFor(obj, b)
            %levelFor  The coarsest level whose blocks are no longer than B samples (1 when none is).
            L = find(obj.Blocks <= b, 1, 'last');
            if isempty(L); L = 1; end
        end
    end

    methods (Static)
        function blocks = blockSizes(nSamples, nChannels)
            %blockSizes  Samples per block of each level for a source of NSAMPLES rows of NCHANNELS.
            %   Level 1: a power of two, FullReadValues / nChannels /
            %   PlotPixels (a view just wider than one full-rate read gets
            %   about a block per pixel column of the widest plot), no
            %   coarser than nSamples / MinBaseBlocks, but at least
            %   nChannels * nSamples / MaxBaseValues (the size of level 1).
            %   Each further level is Factor times coarser, up to the first
            %   with at most MaxLevelBlocks blocks.
            N = max(1, nSamples);
            C = max(1, nChannels);
            two = @(v, rnd) 2 .^ rnd(log2(max(1, v)));     % a power of two near V
            fine = two(EphysTraceEnvelope.FullReadValues / C / EphysTraceEnvelope.PlotPixels, @floor);
            short = two(N / EphysTraceEnvelope.MinBaseBlocks, @floor);
            cap = two(C * N / EphysTraceEnvelope.MaxBaseValues, @ceil);
            b0 = max(cap, min(fine, short));
            n0 = ceil(N / b0);
            f = EphysTraceEnvelope.Factor;
            nLevels = 1 + max(0, ceil(log(n0 / EphysTraceEnvelope.MaxLevelBlocks) / log(f) - 1e-9));
            blocks = b0 * f .^ (0:nLevels - 1);
        end

        function file = fileFor(src)
            %fileFor  The cache file of SRC's envelope.
            %   <outputFolder>/<Name>_envelope_<what>.dat for a source of a
            %   dataset; for a bare file, beside it (<stem>_envelope_<what>.dat).
            switch src.Kind
                case "recording"
                    what = "recording";
                    mode = src.appliedReference();
                    if mode ~= "none"; what = what + "_" + mode; end
                case "bin"
                    what = "bin";
                otherwise
                    what = src.Name;      % LFP, MUA, SPIKE, AUX
            end
            d = src.Dataset;
            if ~isempty(d)
                file = string(fullfile(d.outputFolder(), d.Name + "_envelope_" + what + ".dat"));
            else
                [p, stem] = fileparts(src.File);
                file = string(fullfile(p, stem + "_envelope_" + what + ".dat"));
            end
        end

        function [MN, MX] = reduceSpan(src, a, z, blocks, pieceValues)
            %reduceSpan  Rows [A, Z) of SRC as the min / max of every block of each level.
            %   MN{L}, MX{L}: [nBlocks x NumChannels] single for level L of
            %   BLOCKS (A a multiple of the coarsest block, so every block but
            %   the source's last is whole). The rows are read through
            %   src.readMinMax in pieces of whole level-1 blocks of at most
            %   PIECEVALUES samples x channels. It runs on a thread worker for
            %   the sources that can (EphysTraceSource.threadSafe).
            nC = src.NumChannels;
            b0 = blocks(1);
            P = max(b0, floor(pieceValues / nC / b0) * b0);
            n0 = ceil((z - a) / b0);
            mn = zeros(n0, nC, 'single');
            mx = mn;
            k = 0;
            for p = a:P:z - 1
                [pmn, pmx] = src.readMinMax(p, min(p + P, z) - p, b0, 1:nC);
                mn(k + (1:size(pmn, 1)), :) = pmn;
                mx(k + (1:size(pmx, 1)), :) = pmx;
                k = k + size(pmn, 1);
            end
            MN = {mn};
            MX = {mx};
            for L = 2:numel(blocks)
                f = blocks(L) / blocks(L - 1);
                MN{L} = EphysTraceSource.binMinMax(MN{L - 1}, f);
                [~, MX{L}] = EphysTraceSource.binMinMax(MX{L - 1}, f);
            end
        end
    end

    methods (Static, Hidden)
        function done = allocate(file, header, total, most)
            %allocate  Grow FILE (HEADER, then zeros) towards TOTAL bytes, by at most MOST bytes.
            %   A level's blocks are written where they belong, so the file is
            %   given its whole size first (fseek cannot go past the end).
            if isfile(file)
                info = dir(file);
                have = info.bytes;
                fid = fopen(file, 'a', 'ieee-le');
            else
                have = 0;
                fid = fopen(file, 'w', 'ieee-le');
            end
            if fid < 0
                error('EphysTraceEnvelope:Write', 'Could not write %s.', file);
            end
            closer = onCleanup(@() fclose(fid));
            if have == 0
                fwrite(fid, header, 'uint8');
                have = numel(header);
            end
            stop = min(total, have + most);
            z = zeros(2^22, 1, 'uint8');
            while have < stop
                n = min(stop - have, numel(z));
                fwrite(fid, z(1:n), 'uint8');
                have = have + n;
            end
            done = have >= total;
        end
    end

    methods (Hidden)
        function stepDone(obj, g, k, id)
            %stepDone  Background step K (number ID) ended (0: the file sized, else span K reduced); take the next.
            if obj.State ~= "building" || id ~= obj.StepId; return; end
            obj.Future = [];
            try
                if ~isempty(g.Error)
                    % A thread could not do it: go on here, on a timer (a
                    % read that fails anywhere fails there too, and says why).
                    obj.OnThreads = false;
                    if k == 0
                        obj.deletePartial();
                        obj.planSpans(0);
                    else
                        obj.planSpans(obj.Spans(k, 1));
                        obj.Next = 1;
                    end
                    obj.startTimer();
                    return
                end
                if k > 0
                    [MN, MX] = fetchOutputs(g);
                    obj.spanBuilt(k, MN, MX);
                end
                if obj.State == "building"
                    obj.submit(k + 1);
                end
            catch ME
                obj.fail(ME);
            end
        end

        function tick(obj)
            %tick  One step of a timer build: size the file a piece at a time, then a span.
            if obj.State ~= "building"
                obj.stopTimer();
                return
            end
            try
                if obj.Next == 0
                    if EphysTraceEnvelope.allocate(obj.Partial, obj.Header, obj.DataStart + obj.totalBytes(), 2^25)
                        obj.Next = 1;
                    end
                    return
                end
                if obj.Next > size(obj.Spans, 1)   % a source with no rows
                    obj.finish();
                    return
                end
                k = obj.Next;
                s = obj.Spans(k, :);
                [MN, MX] = EphysTraceEnvelope.reduceSpan(obj.Source, s(1), s(2), obj.Blocks, obj.PieceValues);
                obj.spanBuilt(k, MN, MX);
            catch ME
                obj.fail(ME);
            end
        end
    end

    methods (Access = private)
        function fp = fingerprintOf(obj, src)
            fp = string(jsonencode(struct('schema', EphysTraceEnvelope.Schema, 'source', src.stamp(), ...
                'blocks', obj.Blocks)));
        end

        function check(obj)
            % State "ready" when File holds this envelope: its fingerprint, and all of it.
            obj.State = "missing";
            H = EphysTraceEnvelope.readHeader(obj.File);
            if isempty(H) || ~isfield(H, 'fingerprint') || string(H.fingerprint) ~= obj.Fingerprint
                return
            end
            obj.DataStart = H.dataStart;
            info = dir(obj.File);
            if ~isscalar(info) || info.bytes ~= obj.DataStart + obj.totalBytes()
                return
            end
            obj.State = "ready";
            obj.Progress = 1;
            obj.Checked = tic;
        end

        function n = totalBytes(obj)
            n = sum(obj.NumBlocks) * 8 * obj.Source.NumChannels;
        end

        function p = levelStart(obj, level)
            % The byte where LEVEL's first block starts.
            p = obj.DataStart + sum(obj.NumBlocks(1:level - 1)) * 8 * obj.Source.NumChannels;
        end

        function prepare(obj)
            % A new build: the header, the partial file's name, the spans.
            src = obj.Source;
            d = src.Dataset;
            dsName = "";
            if ~isempty(d); dsName = d.Name; end
            h = struct('schema', EphysTraceEnvelope.Schema, 'fingerprint', obj.Fingerprint, ...
                'source', struct('kind', src.Kind, 'name', src.Name, 'file', src.File, ...
                    'dataset', dsName, 'reference', src.appliedReference(), 'units', src.Units), ...
                'fs', src.Fs, 'nSamples', src.NumSamples, 'nChannels', src.NumChannels, ...
                'channelNames', {cellstr(src.ChannelNames)}, 'factor', EphysTraceEnvelope.Factor, ...
                'blocks', obj.Blocks, 'nBlocks', obj.NumBlocks, 'dtype', "single", ...
                'layout', "the levels in order, finest first; per block the min of every channel, then the max of every channel", ...
                'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
            json = unicode2native(char(jsonencode(h)), 'UTF-8');
            obj.Header = [uint8(EphysTraceEnvelope.Magic), typecast(uint64(numel(json)), 'uint8'), json];
            obj.DataStart = numel(obj.Header);
            folder = fileparts(obj.File);
            if folder ~= "" && ~isfolder(folder); mkdir(folder); end
            removeOldPartials(obj.File);
            [~, token] = fileparts(tempname);
            obj.Partial = obj.File + "." + string(token) + ".partial";
            obj.planSpans(0);
            obj.State = "building";
            obj.Progress = 0;
            obj.Message = "";
            obj.Started = tic;
        end

        function planSpans(obj, from)
            % Spans of whole coarsest blocks from row FROM: about 2^25 samples
            % x channels on a thread, 2^22 on the timer (a short tick).
            src = obj.Source;
            bc = obj.Blocks(end);
            values = 2^22;
            if obj.OnThreads; values = 2^25; end
            rows = max(bc, floor(values / src.NumChannels / bc) * bc);
            a = (from:rows:src.NumSamples - 1).';
            obj.Spans = [a, min(a + rows, src.NumSamples)];
            obj.Next = 0;
        end

        function submit(obj, k)
            % Step K on backgroundPool (0: size the file), or finish after the last span.
            if k > size(obj.Spans, 1)
                obj.finish();
                return
            end
            if k == 0
                g = parfeval(backgroundPool, @EphysTraceEnvelope.allocate, 1, obj.Partial, obj.Header, ...
                    obj.DataStart + obj.totalBytes(), Inf);
            else
                s = obj.Spans(k, :);
                g = parfeval(backgroundPool, @EphysTraceEnvelope.reduceSpan, 2, obj.Source, s(1), s(2), ...
                    obj.Blocks, obj.PieceValues);
            end
            obj.Future = g;
            obj.StepId = obj.StepId + 1;
            id = obj.StepId;
            afterEach(g, @(f) envelopeStep(obj, f, k, id), 0, PassFuture=true);
        end

        function startTimer(obj)
            obj.stopTimer();
            % Deleted once stopped (StopFcn), so a stop from its own tick is safe.
            obj.Timer = timer('ExecutionMode', 'fixedSpacing', 'Period', obj.Period, 'BusyMode', 'drop', ...
                'Name', 'EphysTraceEnvelope', 'ObjectVisibility', 'off', ...
                'TimerFcn', @(~, ~) envelopeTick(obj), 'StopFcn', @(t, ~) delete(t));
            start(obj.Timer);
        end

        function stopTimer(obj)
            t = obj.Timer;
            obj.Timer = [];
            if ~isempty(t) && isvalid(t)
                stop(t);
            end
        end

        function spanBuilt(obj, k, MN, MX)
            % Write span K's blocks into the partial file; the last one finishes it.
            nC = obj.Source.NumChannels;
            a = obj.Spans(k, 1);
            fid = fopen(obj.Partial, 'r+', 'ieee-le');
            if fid < 0
                error('EphysTraceEnvelope:Write', 'Could not write %s.', obj.Partial);
            end
            closer = onCleanup(@() fclose(fid));
            for L = 1:numel(obj.Blocks)
                if fseek(fid, obj.levelStart(L) + a / obj.Blocks(L) * 8 * nC, 'bof') ~= 0
                    error('EphysTraceEnvelope:Write', 'Could not write level %d of %s.', L, obj.Partial);
                end
                fwrite(fid, [MN{L}.'; MX{L}.'], 'single');
            end
            clear closer
            obj.Next = k + 1;
            obj.Progress = obj.Spans(k, 2) / obj.Source.NumSamples;
            if k == size(obj.Spans, 1)
                obj.finish();
            elseif ~isempty(obj.ProgressFcn)
                obj.ProgressFcn(obj);
            end
        end

        function finish(obj)
            % The partial file becomes the cache file.
            obj.stopTimer();
            if isfile(obj.File); delete(obj.File); end
            [ok, msg] = movefile(obj.Partial, obj.File, 'f');
            if ~ok
                error('EphysTraceEnvelope:Write', 'Could not rename %s to %s: %s', obj.Partial, obj.File, msg);
            end
            obj.Partial = "";
            obj.State = "ready";
            obj.Progress = 1;
            obj.Checked = tic;
            obj.Message = sprintf("built in %.1f s", toc(obj.Started));
            if ~isempty(obj.DoneFcn)
                obj.DoneFcn(obj);
            end
        end

        function fail(obj, ME)
            obj.State = "failed";
            obj.Message = string(ME.message);
            obj.stopWork();
            if ~isempty(obj.DoneFcn)
                obj.DoneFcn(obj);
            end
        end

        function stopWork(obj)
            % Stop the timer and the background step; delete the partial file.
            obj.stopTimer();
            g = obj.Future;
            obj.Future = [];
            if ~isempty(g)
                try
                    cancel(g);
                catch
                end
            end
            obj.deletePartial();
            obj.Partial = "";
        end

        function deletePartial(obj)
            % Delete the partial file (a file still held by a step being
            % cancelled stays; the next build of this file deletes it).
            if obj.Partial ~= "" && isfile(obj.Partial)
                try
                    delete(obj.Partial);
                catch
                end
            end
        end
    end

    methods (Static, Access = private)
        function H = readHeader(file)
            % The decoded header of FILE with dataStart (bytes before level 1), or [].
            H = [];
            fid = fopen(file, 'r', 'ieee-le');
            if fid < 0; return; end
            closer = onCleanup(@() fclose(fid));
            m = fread(fid, [1 8], '*uint8');
            if ~isequal(m, uint8(EphysTraceEnvelope.Magic)); return; end
            n = fread(fid, 1, 'uint64=>double');
            if isempty(n) || ~(n > 0 && n < 2^26); return; end
            json = fread(fid, [1 n], '*uint8');
            if numel(json) < n; return; end
            try
                H = jsondecode(native2unicode(json, 'UTF-8'));
            catch
                H = [];
                return
            end
            if ~isstruct(H); H = []; return; end
            H.dataStart = 16 + n;
        end
    end
end


function envelopeStep(obj, g, k, id)
% A background step ended (afterEach): on to the envelope, while it is there.
if isvalid(obj)
    obj.stepDone(g, k, id);
end
end


function envelopeTick(obj)
if isvalid(obj)
    obj.tick();
end
end


function removeOldPartials(file)
% Delete the partial files of FILE an hour old or more (a build MATLAB left).
[p, stem, ext] = fileparts(file);
D = dir(fullfile(p, stem + ext + ".*.partial"));
for k = 1:numel(D)
    if now - D(k).datenum > 1 / 24 %#ok<TNOW1>
        try
            delete(fullfile(D(k).folder, D(k).name));
        catch
        end
    end
end
end
