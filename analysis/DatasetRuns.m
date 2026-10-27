classdef DatasetRuns < handle
    %DatasetRuns  Per-dataset results, computed once and kept: a run engine and its cache.
    %   R = DatasetRuns() keeps one entry per (name, dataset key): the
    %   identity of what was computed (its idText), the stamp of the
    %   dataset's outputs it was computed from (outputsStamp), the status
    %   ("done" or "skipped"), a message, the seconds it took and the
    %   value. run() computes a function over datasets, reporting progress
    %   and stopping on a cancel, and reuses each dataset's entry while its
    %   identity and its stamp are the same:
    %
    %     runs = DatasetRuns();
    %     [values, T] = runs.run(runner, keys, @(src) height(src.trials), Name="nTrials");
    %     [values, T] = runs.run(runner, keys, fn, Name="psth", Id=ID);   % again: "cached", no I/O
    %
    %   epochMatrix keeps its parts here, and DatasetBrowser.forEach keeps
    %   any per-dataset code's results.
    %
    %   [VALUES, T] = run(R, SOURCE, KEYS, FN, Name=Value)
    %     SOURCE   an EphysAnalysisRunner that has found its datasets (each
    %              dataset's source is SOURCE.source(key), its outputs
    %              SOURCE.Outputs(k)), or a function SRC = SOURCE(key)
    %     KEYS     the dataset keys (string), in the order of VALUES and T
    %     FN       VALUE = FN(SRC), FN(SRC, INFO) or FN(SRC, INFO, CHECK) by
    %              nargin(FN): INFO is the dataset's row of Info (a one-row
    %              table; key and name without Info), CHECK the CheckFcn
    %              (a function that does nothing without one)
    %     VALUES   {numel(KEYS) x 1}: each dataset's value ([] where skipped,
    %              failed or canceled)
    %     T        table, one row per key: key, name, status ("done" =
    %              computed now, "cached" = the kept value, "skipped",
    %              "error" or "canceled"), message, seconds (what the
    %              computation took; a cached or skipped entry's, when it
    %              was computed). R.Last holds it too, also after a cancel
    %   Options
    %     Name         the cache name ("" = keep nothing: compute every
    %                  dataset, store none)
    %     Id           the identity of what FN computes (any value
    %                  jsonencode takes; see idText). A kept entry is used
    %                  only while its id text equals this one. Default:
    %                  defaultId(FN), FN's text and, for an anonymous
    %                  function, the values it captured. Edits to the code
    %                  FN calls do not change it: pass Recompute=true then
    %     StampFcn     STAMP = StampFcn(key): text that changes when the
    %                  dataset's outputs change (e.g. outputsStamp of its
    %                  DatasetOutputs), called before each dataset. A kept
    %                  entry, done or skipped, is used only while its stamp
    %                  equals this one; otherwise the dataset is computed
    %                  again, as for another id. [] (default): stamps are
    %                  not compared, and the entries computed keep "" as
    %                  their stamp
    %     Info         table with a key column (and any others, e.g. name,
    %                  subject, date, tags): the row passed to FN; its name
    %                  column names the datasets in T
    %     Recompute    false (default); true: drop NAME's kept entries of
    %                  KEYS first, then compute every dataset, so a run that
    %                  fails or is canceled partway leaves no old entry of
    %                  the datasets it did not finish
    %     ProgressFcn  ProgressFcn(fraction, message) before each dataset
    %     CheckFcn     CheckFcn() called before each dataset, and passed to
    %                  FN as CHECK for its own cancel points
    %     LogFcn       LogFcn(message) after each dataset ([] = quiet, the
    %                  default)
    %     SkipIds      error identifiers that mean "nothing to compute"
    %                  (e.g. "selectUnits:NoUnits"): such a dataset is kept
    %                  as "skipped" with the message, and reported so
    %                  without I/O while the id and the stamp hold
    %     ReleaseFcn   ReleaseFcn(SRC) after each dataset computed (not one
    %                  reused): the default clears SRC.outputs' cache
    %                  (DatasetOutputs.clearCache), so one dataset's signals
    %                  are held at a time; [] = none
    %   A dataset's kept entry is dropped before the dataset is computed, so
    %   whatever happens next never leaves an old value behind. Any error
    %   but a skip leaves no entry: the dataset is "error", with the
    %   warning DatasetRuns:DatasetFailed, and is tried again next run (an
    %   error of StampFcn too, which leaves the entry as it was). An error
    %   whose identifier ends in ":Canceled" (from ProgressFcn, CheckFcn,
    %   StampFcn, SOURCE or FN) marks that dataset and the ones after it
    %   "canceled", keeps the ones finished, and raises
    %   DatasetRuns:Canceled (the original error as its cause).
    %
    %   Other methods
    %     ST = status(R, NAME, KEYS, ID, Stamps=)   per key: "current" (a
    %                  "done" entry of that id), "skipped" (a "skipped"
    %                  one), "old" (an entry of another id, or, with Stamps
    %                  (text, one per key), of another stamp) or "" (none)
    %     V = value(R, NAME, KEY)   the kept value ([] when none)
    %     forget(R), forget(R, NAME), forget(R, NAME, KEYS)   drop entries
    %                  (every one, NAME's, NAME's of KEYS; empty KEYS drops
    %                  nothing)
    %     S = toStruct(R); R = DatasetRuns.fromStruct(S)   a struct that
    %                  save(..., '-v7.3') holds, and back. A struct of an
    %                  older version gives an empty DatasetRuns, with the
    %                  warning DatasetRuns:OldVersion: its results are
    %                  computed again
    %     TXT = DatasetRuns.idText(ID)   the canonical text of an id
    %     ID = DatasetRuns.defaultId(FN)   run's default Id
    %
    %   Errors: DatasetRuns:Canceled, DatasetRuns:NeedId (no Id, and FN
    %   captured a value jsonencode cannot write, e.g. a handle or another
    %   function), DatasetRuns:BadSource, DatasetRuns:BadStruct. Warnings:
    %   DatasetRuns:DatasetFailed, DatasetRuns:OldVersion.
    %
    %   See also epochMatrix, epochMatrixSettings, outputsStamp,
    %   EphysAnalysisRunner.

    properties (SetAccess = private)
        Entries   % struct array: name, key, idText, stamp, status ("done" | "skipped"), message, seconds, value, created
        Last table = table()   % the last run's T
    end

    properties (Constant, Hidden)
        Schema = "dataset-runs"
        Version = 2   % 2: entries hold the outputs' stamp
    end

    methods
        function obj = DatasetRuns()
            obj.Entries = DatasetRuns.emptyEntries();
        end

        function [values, T] = run(obj, source, keys, fn, opts)
            %run  FN over the datasets KEYS of SOURCE, reusing the kept values (see the class help).
            arguments
                obj
                source
                keys
                fn (1,1) function_handle
                opts.Name (1,1) string = ""
                opts.Id = []
                opts.Info = []
                opts.Recompute (1,1) logical = false
                opts.ProgressFcn = []
                opts.CheckFcn = []
                opts.LogFcn = []
                opts.SkipIds (1,:) string = string.empty(1, 0)
                opts.ReleaseFcn = @releaseOutputs
                opts.StampFcn = []
            end
            isRunner = isa(source, 'EphysAnalysisRunner');
            if ~isRunner && ~isa(source, 'function_handle')
                error('DatasetRuns:BadSource', 'SOURCE must be an EphysAnalysisRunner or a function @(key) src.');
            end
            keys = reshape(string(keys), [], 1);
            n = numel(keys);
            id = opts.Id;
            if isempty(id); id = DatasetRuns.defaultId(fn); end
            txt = DatasetRuns.idText(id);
            keep = opts.Name ~= "";
            check = opts.CheckFcn;
            if isempty(check); check = @() []; end
            say = opts.LogFcn;
            if isempty(say); say = @(msg) []; end
            nIn = nargin(fn);
            info = opts.Info;
            if ~isempty(info) && ~istable(info)
                error('DatasetRuns:BadSource', 'Info must be a table with a key column.');
            end
            useStamp = ~isempty(opts.StampFcn);
            if useStamp && ~isa(opts.StampFcn, 'function_handle')
                error('DatasetRuns:BadSource', 'StampFcn must be a function @(key) text.');
            end
            if keep && opts.Recompute
                obj.forget(opts.Name, keys);   % nothing old outlives a recompute stopped partway
            end

            names = keys;
            for j = 1:n
                names(j) = nameOf(keys(j), info, source, isRunner);
            end
            T = table(keys, names, strings(n, 1), strings(n, 1), NaN(n, 1), ...
                'VariableNames', {'key', 'name', 'status', 'message', 'seconds'});
            values = cell(n, 1);
            obj.Last = T;

            for j = 1:n
                key = keys(j);
                try
                    if ~isempty(opts.ProgressFcn)
                        opts.ProgressFcn((j - 1) / n, sprintf('%d/%d %s', j, n, names(j)));
                    end
                    check();
                catch ME
                    if isCancel(ME); obj.cancelAt(T, j, ME); end
                    rethrow(ME);
                end

                stamp = "";
                if useStamp
                    try
                        stamp = stampText(opts.StampFcn(key));
                    catch ME
                        if isCancel(ME); obj.cancelAt(T, j, ME); end
                        T.status(j) = "error";
                        T.message(j) = "outputs stamp: " + string(ME.message);
                        warning('DatasetRuns:DatasetFailed', '%s failed: %s', names(j), T.message(j));
                        obj.Last = T;
                        say(sprintf('%s (%d/%d): error: %s', names(j), j, n, T.message(j)));
                        continue
                    end
                end

                e = obj.entryIndex(opts.Name, key);
                if keep && ~opts.Recompute && ~isempty(e) && obj.Entries(e).idText == txt ...
                        && (~useStamp || obj.Entries(e).stamp == stamp)
                    E = obj.Entries(e);
                    if E.status == "done"
                        T.status(j) = "cached";
                        values{j} = E.value;
                    else
                        T.status(j) = E.status;
                    end
                    T.message(j) = E.message;
                    T.seconds(j) = E.seconds;
                    obj.Last = T;
                    say(sprintf('%s (%d/%d): %s', names(j), j, n, T.status(j)));
                    continue
                end
                if keep && ~isempty(e)
                    obj.Entries(e) = [];   % an error or a cancel below must not leave the old value
                end

                t0 = tic;
                src = [];
                try
                    if isRunner
                        k = source.index(key);
                        if k == 0
                            error('DatasetRuns:BadSource', 'The runner has no dataset "%s".', key);
                        end
                        src = source.source(k);
                    else
                        src = source(key);
                    end
                    if nIn == 0
                        v = fn();
                    elseif nIn == 1
                        v = fn(src);
                    elseif nIn == 2
                        v = fn(src, infoRow(info, key, names(j)));
                    else   % 3 or more, or varargin
                        v = fn(src, infoRow(info, key, names(j)), check);
                    end
                    values{j} = v;
                    T.status(j) = "done";
                    T.seconds(j) = toc(t0);
                    if keep; obj.store(opts.Name, key, txt, stamp, "done", "", T.seconds(j), v); end
                catch ME
                    T.seconds(j) = toc(t0);
                    if isCancel(ME)
                        release(opts.ReleaseFcn, src);
                        obj.cancelAt(T, j, ME);
                    end
                    T.message(j) = string(ME.message);
                    if ismember(string(ME.identifier), opts.SkipIds)
                        T.status(j) = "skipped";
                        if keep; obj.store(opts.Name, key, txt, stamp, "skipped", T.message(j), T.seconds(j), []); end
                    else
                        T.status(j) = "error";
                        warning('DatasetRuns:DatasetFailed', '%s failed: %s', names(j), ME.message);
                    end
                end
                release(opts.ReleaseFcn, src);
                obj.Last = T;
                msg = sprintf('%s (%d/%d): %s, %.1f s', names(j), j, n, T.status(j), T.seconds(j));
                if T.message(j) ~= ""; msg = msg + ": " + T.message(j); end
                say(msg);
            end
            obj.Last = T;
        end

        function st = status(obj, name, keys, id, opts)
            %status  Per key: "current", "skipped", "old" or "" (see the class help).
            %   Stamps= (text, one per key; [] = not compared): an entry of
            %   another stamp is "old", as run would compute it again.
            arguments
                obj
                name (1,1) string
                keys
                id
                opts.Stamps = []
            end
            keys = reshape(string(keys), [], 1);
            txt = DatasetRuns.idText(id);
            useStamp = ~isempty(opts.Stamps);
            if useStamp
                stamps = reshape(string(opts.Stamps), [], 1);
                if numel(stamps) ~= numel(keys)
                    error('DatasetRuns:BadSource', 'Stamps needs one stamp per key (%d, got %d).', numel(keys), numel(stamps));
                end
                stamps(ismissing(stamps)) = "";
            end
            st = strings(numel(keys), 1);
            for j = 1:numel(keys)
                e = obj.entryIndex(name, keys(j));
                if isempty(e); continue; end
                E = obj.Entries(e);
                if E.idText ~= txt || (useStamp && E.stamp ~= stamps(j))
                    st(j) = "old";
                elseif E.status == "done"
                    st(j) = "current";
                else
                    st(j) = "skipped";
                end
            end
        end

        function v = value(obj, name, key)
            %value  The kept value of (NAME, KEY), whatever its id; [] when none.
            v = [];
            e = obj.entryIndex(string(name), string(key));
            if ~isempty(e); v = obj.Entries(e).value; end
        end

        function forget(obj, name, keys)
            %forget  Drop entries: every one, NAME's, or NAME's for KEYS (empty KEYS: none).
            if nargin < 2
                obj.Entries = DatasetRuns.emptyEntries();
                return
            end
            if isempty(obj.Entries); return; end
            drop = [obj.Entries.name] == string(name);
            if nargin > 2
                if isempty(keys); return; end
                drop = drop & ismember([obj.Entries.key], reshape(string(keys), 1, []));
            end
            obj.Entries(drop) = [];
        end

        function s = toStruct(obj)
            %toStruct  schema, version and entries: a struct save(..., '-v7.3') holds.
            s = struct('schema', DatasetRuns.Schema, 'version', DatasetRuns.Version, 'entries', obj.Entries);
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %fromStruct  The DatasetRuns that toStruct gave S.
            if ~(isstruct(s) && isscalar(s) && isfield(s, 'schema') && string(s.schema) == DatasetRuns.Schema ...
                    && isfield(s, 'entries'))
                error('DatasetRuns:BadStruct', 'Not a DatasetRuns struct (schema "%s").', DatasetRuns.Schema);
            end
            if s.version > DatasetRuns.Version
                error('DatasetRuns:BadStruct', 'DatasetRuns version %g is newer than this code reads (%d).', ...
                    s.version, DatasetRuns.Version);
            end
            obj = DatasetRuns();
            E = s.entries;
            if s.version < DatasetRuns.Version
                warning('DatasetRuns:OldVersion', ['These kept results are of DatasetRuns version %g, older than ' ...
                    'this code''s (%d): their %d entries are dropped, and computed again when next asked for.'], ...
                    s.version, DatasetRuns.Version, numel(E));
                return
            end
            if isempty(E); return; end
            need = string(fieldnames(DatasetRuns.emptyEntries()));
            if ~isstruct(E) || ~all(isfield(E, need))
                error('DatasetRuns:BadStruct', 'The entries need the fields %s.', strjoin(need, ", "));
            end
            E = reshape(E, 1, []);
            for i = 1:numel(E)
                for f = ["name" "key" "idText" "stamp" "status" "message"]
                    E(i).(f) = string(E(i).(f));
                end
            end
            obj.Entries = orderfields(E, DatasetRuns.emptyEntries());
        end

        function txt = idText(id)
            %idText  The canonical text of an id: jsonencode, non-finite numbers as strings.
            %   TXT = DatasetRuns.idText(ID) sorts every struct's fields
            %   by name, writes Inf, -Inf and NaN as the strings "Inf",
            %   "-Inf" and "NaN" (stringifyNonFinite) and encodes the
            %   result (jsonencode), so the text is the same for row and
            %   column vectors, for char and string, and after the id has
            %   been written to JSON and read back (jsondecode), as long as
            %   the reader gives back the same values. An id that is
            %   already text is encoded like any other value.
            try
                txt = string(jsonencode(stringifyNonFinite(sortFields(id))));
            catch ME
                error('DatasetRuns:NeedId', 'The id cannot be written as JSON: %s', ME.message);
            end
        end

        function id = defaultId(fn)
            %defaultId  run's default Id: FN's text and, for an anonymous function, what it captured.
            %   DatasetRuns:NeedId when a captured value cannot be written
            %   as JSON (a handle object, another function, ...): pass Id.
            f = functions(fn);
            id = struct('function', string(func2str(fn)));
            if string(f.type) ~= "anonymous"; return; end
            ws = struct();
            if isfield(f, 'workspace') && ~isempty(f.workspace)
                ws = f.workspace;
                if iscell(ws); ws = ws{1}; end
            end
            bad = unencodable(ws, "");
            if bad ~= ""
                error('DatasetRuns:NeedId', ['The function captures %s, which cannot be written as JSON, so it ' ...
                    'cannot be part of the cache identity: pass Id= (any value that names what the function ' ...
                    'computes).'], bad);
            end
            id.workspace = ws;
            try
                DatasetRuns.idText(id);
            catch ME
                error('DatasetRuns:NeedId', '%s Pass Id=.', ME.message);
            end
        end
    end

    methods (Access = private)
        function e = entryIndex(obj, name, key)
            e = [];
            if isempty(obj.Entries) || name == ""; return; end
            e = find([obj.Entries.name] == name & [obj.Entries.key] == key, 1);
        end

        function store(obj, name, key, txt, stamp, status, message, seconds, value)
            E = struct('name', name, 'key', key, 'idText', txt, 'stamp', stamp, 'status', status, 'message', string(message), ...
                'seconds', seconds, 'value', {value}, 'created', datetime('now'));
            e = obj.entryIndex(name, key);
            if isempty(e)
                obj.Entries(end+1) = E;
            else
                obj.Entries(e) = E;
            end
        end

        function cancelAt(obj, T, j, ME)
            %cancelAt  Mark dataset J and the rest canceled, keep T, raise DatasetRuns:Canceled.
            T.status(j:end) = "canceled";
            T.message(j) = string(ME.message);
            obj.Last = T;
            nDone = nnz(ismember(T.status(1:j-1), ["done" "cached"]));
            C = MException('DatasetRuns:Canceled', 'Canceled at %s (%d of %d): %d dataset(s) finished are kept.', ...
                T.name(j), j, height(T), nDone);
            C = C.addCause(ME);
            throwAsCaller(C);
        end
    end

    methods (Static, Access = private)
        function E = emptyEntries()
            E = struct('name', {}, 'key', {}, 'idText', {}, 'stamp', {}, 'status', {}, 'message', {}, 'seconds', {}, ...
                'value', {}, 'created', {});
            E = reshape(E, 1, 0);
        end
    end
end


function tf = isCancel(ME)
tf = endsWith(string(ME.identifier), ":Canceled");
end


function s = stampText(v)
%stampText  A StampFcn's value as one string ("" for empty or missing; several lines joined).
if isempty(v)
    s = "";
    return
end
if ~(isstring(v) || ischar(v) || iscellstr(v))
    error('DatasetRuns:BadSource', 'StampFcn must return text (got a %s).', class(v));
end
s = string(v);
s(ismissing(s)) = "";
s = strjoin(reshape(s, 1, []), newline);
end


function releaseOutputs(src)
%releaseOutputs  The default ReleaseFcn: clear the source's outputs cache (its signals, sorting).
if isstruct(src) && isscalar(src) && isfield(src, 'outputs') && isa(src.outputs, 'DatasetOutputs')
    src.outputs.clearCache();
end
end


function release(fcn, src)
if isempty(fcn) || isempty(src); return; end
fcn(src);
end


function name = nameOf(key, info, source, isRunner)
%nameOf  A dataset's name: Info's name column, else the runner's name, else the key.
name = key;
if ~isempty(info) && ismember("name", string(info.Properties.VariableNames)) && ismember("key", string(info.Properties.VariableNames))
    r = find(string(info.key) == key, 1);
    if ~isempty(r) && string(info.name(r)) ~= ""
        name = string(info.name(r));
        return
    end
end
if isRunner
    k = source.index(key);
    if k > 0; name = source.Names(k); end
end
end


function row = infoRow(info, key, name)
%infoRow  The dataset's row of Info; a key and name table without one.
if ~isempty(info) && ismember("key", string(info.Properties.VariableNames))
    r = find(string(info.key) == key, 1);
    if ~isempty(r)
        row = info(r, :);
        return
    end
end
row = table(key, name, 'VariableNames', {'key', 'name'});
end


function v = sortFields(v)
%sortFields  Every struct's fields in name order, recursively (struct arrays and cells too).
if isstruct(v)
    if ~isempty(fieldnames(v)); v = orderfields(v); end
    f = fieldnames(v);
    for i = 1:numel(v)
        for k = 1:numel(f)
            v(i).(f{k}) = sortFields(v(i).(f{k}));
        end
    end
elseif iscell(v)
    for i = 1:numel(v)
        v{i} = sortFields(v{i});
    end
end
end


function bad = unencodable(v, path)
%unencodable  The path of the first value JSON cannot hold ("" = none): handles, functions, objects.
bad = "";
if isnumeric(v) || islogical(v) || ischar(v) || isstring(v) || isdatetime(v) || isduration(v) || iscategorical(v)
    return
end
if isstruct(v)
    f = string(fieldnames(v)).';
    for i = 1:numel(v)
        for k = f
            p = k;
            if path ~= ""; p = path + "." + k; end
            bad = unencodable(v(i).(k), p);
            if bad ~= ""; return; end
        end
    end
    return
end
if iscell(v)
    for i = 1:numel(v)
        bad = unencodable(v{i}, path + "{" + i + "}");
        if bad ~= ""; return; end
    end
    return
end
if istable(v)
    return
end
if path == ""; path = "a value"; end
bad = sprintf('"%s" (a %s)', path, class(v));
end
