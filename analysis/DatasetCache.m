classdef DatasetCache < handle
    %DatasetCache  Each dataset's loaded data (spikes, signals) kept in memory between computes, up to a limit.
    %   C = DatasetCache() holds the data a run loaded for each dataset
    %   (its DatasetOutputs' cache: the spikes file, the sorting, the
    %   signals and their resampled or filtered columns), so the next run
    %   on the same datasets reads nothing from disk: a new event, window,
    %   trial selection, bin or measure works on the data in memory.
    %   DatasetRuns.run (and epochMatrix) take it as their ReleaseFcn:
    %
    %     C = DatasetCache(LimitMB=8192);
    %     R1 = epochMatrix(runner, S1, Runs=runs, ReleaseFcn=@(src) C.release(src));
    %     R2 = epochMatrix(runner, S2, Runs=runs, ReleaseFcn=@(src) C.release(src));   % no file read
    %
    %   The dataset used least recently goes first once the data held pass
    %   LimitMB (a dataset larger than the limit is not kept). Sizes are
    %   whos' counts of what the cache holds (DatasetOutputs.cacheBytes).
    %   A worker's data stay on the worker (DatasetRuns releases them
    %   there); pass LocalFcn=@(key) C.holds(key) so a dataset held here is
    %   computed here.
    %
    %   Properties
    %     Spikes     true (default): keep the spike data (the spikes file,
    %                the sorting); false drops them, also from what is held
    %     Signals    true (default): keep the signals (LFP, MUA, SPIKE, AUX,
    %                with their resampled and filtered columns, and a whole
    %                extract file); false drops them, also from what is held
    %     LimitMB    the most the data held may take, MB (default 4096); a
    %                lower limit drops the datasets used least recently
    %     TotalMB, Count, Keys   what is held (read-only)
    %
    %   Methods
    %     release(C, SRC)        ReleaseFcn: keep SRC's data (SRC.outputs,
    %                            under SRC.key), then keep within LimitMB
    %     release(C, SRC, false) keep nothing new: a dataset not held is
    %                            cleared as DatasetRuns' default does; one
    %                            held stays held (with what was loaded now)
    %     TF = holds(C, KEY)     KEY's data are held
    %     TF = hasRoom(C)        what is held is below LimitMB
    %     clear(C), clear(C, KEYS)   drop every dataset's data, or KEYS'
    %     adopt(C, RUNNER, KEYS) after a new scan: the datasets KEYS (their
    %                            files unchanged) move their data to
    %                            RUNNER's DatasetOutputs (DatasetOutputs.adoptCache;
    %                            the manifest is read again); the others are
    %                            dropped
    %     TXT = summary(C)       "1.2 GB in 3 datasets" ("nothing" when empty)
    %
    %   See also DatasetRuns, DatasetOutputs, epochMatrix, DatasetBrowser.

    properties
        Spikes (1,1) logical = true
        Signals (1,1) logical = true
        LimitMB (1,1) double {mustBePositive} = 4096
    end

    properties (SetAccess = private)
        Held = DatasetCache.emptyHeld()   % key, outputs (DatasetOutputs), bytes; the least recently used first
    end

    properties (Dependent)
        TotalMB
        Count
        Keys
    end

    properties (Constant)
        SpikeKinds = ["spikes" "sorting"]
        SignalKinds = ["LFP" "MUA" "SPIKE" "AUX" "extract"]
    end

    methods
        function obj = DatasetCache(opts)
            arguments
                opts.Spikes (1,1) logical = true
                opts.Signals (1,1) logical = true
                opts.LimitMB (1,1) double {mustBePositive} = 4096
            end
            obj.Spikes = opts.Spikes;
            obj.Signals = opts.Signals;
            obj.LimitMB = opts.LimitMB;
        end

        function delete(obj)
            obj.clear();
        end

        function v = get.TotalMB(obj)
            v = sum([obj.Held.bytes]) / 2^20;
        end

        function n = get.Count(obj)
            n = numel(obj.Held);
        end

        function k = get.Keys(obj)
            k = reshape(string({obj.Held.key}), [], 1);
        end

        function set.Spikes(obj, tf)
            obj.Spikes = tf;
            if ~tf; obj.dropKinds(DatasetCache.SpikeKinds); end
        end

        function set.Signals(obj, tf)
            obj.Signals = tf;
            if ~tf; obj.dropKinds(DatasetCache.SignalKinds); end
        end

        function set.LimitMB(obj, mb)
            obj.LimitMB = mb;
            obj.trim();
        end

        function release(obj, src, keep)
            %release  The ReleaseFcn: keep SRC's loaded data (KEEP false: only when held already), within LimitMB.
            if nargin < 3; keep = true; end
            if ~(isstruct(src) && isscalar(src) && isfield(src, 'outputs') && isa(src.outputs, 'DatasetOutputs')); return; end
            out = src.outputs;
            key = string(src.key);
            i = obj.index(key);
            if ~isempty(i) && obj.Held(i).outputs ~= out
                obj.Held(i).outputs.clearCache();   % another scan's outputs of the same dataset
            end
            if ~keep && isempty(i)
                out.clearCache();   % as DatasetRuns' default
                return
            end
            drop = string.empty(1, 0);
            if ~obj.Spikes; drop = [drop DatasetCache.SpikeKinds]; end
            if ~obj.Signals; drop = [drop DatasetCache.SignalKinds]; end
            if ~isempty(drop); out.clearCache(drop); end
            bytes = out.cacheBytes();
            if ~isempty(i); obj.Held(i) = []; end
            if bytes > 0
                obj.Held(end+1) = struct('key', key, 'outputs', out, 'bytes', bytes);
            end
            obj.trim();
        end

        function tf = holds(obj, key)
            %holds  KEY's data are held.
            tf = ~isempty(obj.index(string(key)));
        end

        function tf = hasRoom(obj)
            %hasRoom  What is held is below LimitMB.
            tf = obj.TotalMB < obj.LimitMB;
        end

        function clear(obj, keys)
            %clear  Drop every dataset's data, or only those of KEYS.
            if isempty(obj.Held); return; end
            drop = true(1, numel(obj.Held));
            if nargin > 1; drop = ismember(string({obj.Held.key}), reshape(string(keys), 1, [])); end
            for i = find(drop)
                o = obj.Held(i).outputs;
                if isvalid(o); o.clearCache(); end
            end
            obj.Held(drop) = [];
        end

        function adopt(obj, runner, keys)
            %adopt  After a new scan: KEYS (files unchanged) take their data to RUNNER's DatasetOutputs; the others go.
            keys = reshape(string(keys), 1, []);
            drop = false(1, numel(obj.Held));
            for i = 1:numel(obj.Held)
                old = obj.Held(i).outputs;
                k = 0;
                if ismember(obj.Held(i).key, keys); k = runner.index(obj.Held(i).key); end
                if k > 0
                    new = runner.Outputs(k);
                    if new ~= old
                        new.adoptCache(old, Except="manifest");   % the manifest is read again (tags, variables)
                        old.clearCache();
                        obj.Held(i).outputs = new;
                        obj.Held(i).bytes = new.cacheBytes();
                    end
                else
                    if isvalid(old); old.clearCache(); end
                    drop(i) = true;
                end
            end
            obj.Held(drop) = [];
        end

        function s = summary(obj)
            %summary  "1.2 GB in 3 datasets" ("nothing" when nothing is held).
            if isempty(obj.Held); s = "nothing"; return; end
            s = DatasetCache.sizeText(obj.TotalMB) + " in " + obj.Count + " dataset";
            if obj.Count ~= 1; s = s + "s"; end
        end
    end

    methods (Static)
        function s = sizeText(mb)
            %sizeText  MB as "350 MB" or "1.2 GB".
            if mb < 1024
                s = sprintf("%.0f MB", mb);
            else
                s = sprintf("%.1f GB", mb / 1024);
            end
        end
    end

    methods (Access = private)
        function i = index(obj, key)
            i = [];
            if isempty(obj.Held); return; end
            i = find(string({obj.Held.key}) == key, 1);
        end

        function trim(obj)
            %trim  Drop the datasets used least recently until what is held fits LimitMB.
            while ~isempty(obj.Held) && sum([obj.Held.bytes]) > obj.LimitMB * 2^20
                o = obj.Held(1).outputs;
                if isvalid(o); o.clearCache(); end
                obj.Held(1) = [];
            end
        end

        function dropKinds(obj, kinds)
            %dropKinds  KINDS out of every held dataset's data (each measured again; one left with nothing goes).
            drop = false(1, numel(obj.Held));
            for i = 1:numel(obj.Held)
                o = obj.Held(i).outputs;
                if ~isvalid(o); drop(i) = true; continue; end
                o.clearCache(kinds);
                obj.Held(i).bytes = o.cacheBytes();
                drop(i) = obj.Held(i).bytes == 0;
            end
            obj.Held(drop) = [];
        end
    end

    methods (Static, Access = private)
        function H = emptyHeld()
            H = reshape(struct('key', {}, 'outputs', {}, 'bytes', {}), 1, 0);
        end
    end
end
