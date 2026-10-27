classdef OutputFileIndex < handle
    % OutputFileIndex  What each output file holds, kept on this machine so a scan opens it once.
    %   DatasetOutputs.refresh tells a dataset's files apart by what is in
    %   them (a .mat by its variable names, a .npz by its meta member, a
    %   .nwb by its /general/notes, each also by the dataset and recording
    %   folder its provenance names), and finding that out opens every
    %   file: over a network share a few tenths of a second a file, most of
    %   a scan. The index keeps those facts per file, under its path, size
    %   and modification time, so a later scan (in any MATLAB on this
    %   machine) opens only the files that are new or changed since:
    %
    %     facts = OutputFileIndex.lookup(file, bytes, modified)   % [] = not known, or changed since
    %     OutputFileIndex.store(file, bytes, modified, facts)
    %     OutputFileIndex.save()     % write what store added, merged with what the file holds now
    %
    %   BYTES and MODIFIED are the file's dir() bytes and datenum. FACTS is
    %   a scalar struct of string scalars (DatasetOutputs: vars, prov,
    %   tool, dataset, sourceFolder); the index does not look inside it,
    %   but every entry has the same fields (facts with other fields
    %   start the index again).
    %
    %   The index file is %LOCALAPPDATA%\ephys_analysis\output_index.mat
    %   (tempdir without LOCALAPPDATA), or the file the environment
    %   variable EPHYS_OUTPUT_INDEX_FILE names; useTemporary() points it at
    %   a new file until the object it returns is cleared (tests). It keeps
    %   the MaxEntries files stored last. Deleting it costs only the next
    %   scan's time; a file that cannot be read counts as empty, and one
    %   that cannot be written warns once a session (OutputFileIndex:Save).
    %
    %   See also DatasetOutputs.

    properties (Constant)
        EnvVar = "EPHYS_OUTPUT_INDEX_FILE"   % names the index file; "" = the default
        MaxEntries = 20000
    end

    properties (SetAccess = private)
        File (1,1) string = ""
        Keys (:,1) string = strings(0, 1)    % lower-case paths on Windows
        Bytes (:,1) double = zeros(0, 1)
        Modified (:,1) double = zeros(0, 1)
        Stored (:,1) double = zeros(0, 1)    % datenum it was stored (MaxEntries keeps the latest)
        Facts struct = struct()              % one string column per facts field
        Added (1,:) string = string.empty(1, 0)   % keys stored since the last save
    end

    properties (Access = private)
        Rows = []   % containers.Map key -> row
        Warned (1,1) logical = false
    end

    methods (Static)
        function facts = lookup(file, bytes, modified)
            %lookup  The facts stored for FILE while it has this size and modification time; [] otherwise.
            facts = [];
            ix = OutputFileIndex.current();
            k = char(OutputFileIndex.key(file));
            if ~isKey(ix.Rows, k); return; end
            r = ix.Rows(k);
            if ix.Bytes(r) ~= bytes || ix.Modified(r) ~= modified; return; end
            facts = struct();
            for f = reshape(string(fieldnames(ix.Facts)), 1, [])
                facts.(f) = ix.Facts.(f)(r);
            end
        end

        function store(file, bytes, modified, facts)
            %store  Keep FACTS for FILE at this size and modification time (save writes them).
            arguments
                file (1,1) string
                bytes (1,1) double
                modified (1,1) double
                facts (1,1) struct
            end
            ix = OutputFileIndex.current();
            ix.put(OutputFileIndex.key(file), bytes, modified, now, facts); %#ok<TNOW1> a datenum, as dir's
        end

        function save()
            %save  Write the facts stored since the last save into the index file.
            %   What the file holds now (another MATLAB may have written it)
            %   is kept beside them; a file stored again replaces its entry.
            ix = OutputFileIndex.current();
            if isempty(ix.Added); return; end
            ix.writeMerged();
        end

        function f = file()
            %file  The index file: EPHYS_OUTPUT_INDEX_FILE, else %LOCALAPPDATA%\ephys_analysis\output_index.mat.
            f = string(getenv(OutputFileIndex.EnvVar));
            if f ~= ""; return; end
            base = string(getenv('LOCALAPPDATA'));
            if base == ""; base = string(tempdir); end
            f = string(fullfile(base, "ephys_analysis", "output_index.mat"));
        end

        function restore = useTemporary()
            %useTemporary  Use a new, empty index file until RESTORE is cleared.
            %   RESTORE is an onCleanup object: clearing it deletes the file
            %   and puts back the index file in use before.
            previous = string(getenv(OutputFileIndex.EnvVar));
            f = string(tempname) + "_output_index.mat";
            setenv(OutputFileIndex.EnvVar, char(f));
            restore = onCleanup(@() OutputFileIndex.endTemporary(f, previous));
        end
    end

    methods (Static, Hidden)
        function endTemporary(file, previous)
            %endTemporary  Delete the temporary index file and restore the previous one.
            if isfile(file); delete(file); end
            setenv(OutputFileIndex.EnvVar, char(previous));
        end
    end

    methods (Static, Access = private)
        function ix = current()
            %current  The index of the file in use, read once (again when the file in use changes).
            persistent kept
            f = OutputFileIndex.file();
            if isempty(kept) || ~isvalid(kept) || kept.File ~= f
                kept = OutputFileIndex(f);
            end
            ix = kept;
        end

        function k = key(file)
            k = string(file);
            if ispc; k = lower(k); end
        end

        function D = noEntries()
            D = struct('key', strings(0, 1), 'bytes', zeros(0, 1), 'modified', zeros(0, 1), ...
                'stored', zeros(0, 1), 'facts', struct());
        end

        function D = readFile(file)
            %readFile  The index file's entries (a struct of columns), or none when it is not there or cannot be read.
            D = OutputFileIndex.noEntries();
            if ~isfile(file); return; end
            try
                L = load(file, 'index');
                I = L.index;
                n = numel(I.key);
                ok = isstruct(I.facts) && all(structfun(@(c) isstring(c) && numel(c) == n, I.facts)) ...
                    && numel(I.bytes) == n && numel(I.modified) == n && numel(I.stored) == n;
                if ok
                    D = struct('key', I.key(:), 'bytes', I.bytes(:), 'modified', I.modified(:), ...
                        'stored', I.stored(:), 'facts', I.facts);
                end
            catch
            end
        end
    end

    methods (Access = private)
        function obj = OutputFileIndex(file)
            obj.File = file;
            obj.take(OutputFileIndex.readFile(file));
        end

        function take(obj, D)
            %take  Hold the entries D (readFile's columns) and nothing added.
            obj.Keys = D.key; obj.Bytes = D.bytes; obj.Modified = D.modified; obj.Stored = D.stored;
            obj.Facts = D.facts;
            obj.Rows = containers.Map('KeyType', 'char', 'ValueType', 'double');
            if ~isempty(obj.Keys)
                obj.Rows = containers.Map(cellstr(obj.Keys), num2cell(1:numel(obj.Keys)));
            end
            obj.Added = string.empty(1, 0);
        end

        function put(obj, k, bytes, modified, stored, facts)
            %put  Hold one entry (replacing one under the same key); facts with other fields start again.
            fields = string(fieldnames(facts));
            if ~isequal(sort(fields), sort(string(fieldnames(obj.Facts)))) && ~isempty(fieldnames(obj.Facts))
                obj.take(OutputFileIndex.noEntries());
            end
            if isempty(fieldnames(obj.Facts))
                for f = reshape(fields, 1, []); obj.Facts.(f) = strings(numel(obj.Keys), 1); end
            end
            if isKey(obj.Rows, char(k))
                r = obj.Rows(char(k));
            else
                r = numel(obj.Keys) + 1;
                obj.Rows(char(k)) = r;
            end
            obj.Keys(r, 1) = k; obj.Bytes(r, 1) = bytes; obj.Modified(r, 1) = modified; obj.Stored(r, 1) = stored;
            for f = reshape(fields, 1, [])
                obj.Facts.(f)(r, 1) = string(facts.(f));
            end
            obj.Added = unique([obj.Added, k], 'stable');
        end

        function writeMerged(obj)
            %writeMerged  The file's entries now, this index's added ones over them, the latest MaxEntries; written and held.
            mine = cellfun(@(k) obj.Rows(k), cellstr(obj.Added));
            added = struct('key', obj.Keys(mine), 'bytes', obj.Bytes(mine), 'modified', obj.Modified(mine), 'stored', obj.Stored(mine));
            for f = reshape(string(fieldnames(obj.Facts)), 1, []); added.facts.(f) = obj.Facts.(f)(mine); end
            obj.take(OutputFileIndex.readFile(obj.File));   % what another MATLAB wrote meanwhile
            for i = 1:numel(added.key)
                facts = struct();
                for f = reshape(string(fieldnames(added.facts)), 1, []); facts.(f) = added.facts.(f)(i); end
                obj.put(added.key(i), added.bytes(i), added.modified(i), added.stored(i), facts);
            end
            if numel(obj.Keys) > OutputFileIndex.MaxEntries
                [~, o] = sort(obj.Stored, 'descend');
                keep = sort(o(1:OutputFileIndex.MaxEntries));
                D = struct('key', obj.Keys(keep), 'bytes', obj.Bytes(keep), 'modified', obj.Modified(keep), ...
                    'stored', obj.Stored(keep), 'facts', structfun(@(c) c(keep), obj.Facts, 'UniformOutput', false));
                obj.take(D);
            end
            index = struct('key', obj.Keys, 'bytes', obj.Bytes, 'modified', obj.Modified, ...
                'stored', obj.Stored, 'facts', obj.Facts);   % saved by name
            try
                folder = fileparts(obj.File);
                if folder ~= "" && ~isfolder(folder); mkdir(folder); end
                [~, tag] = fileparts(tempname);
                tmp = obj.File + "." + string(tag) + ".mat";
                save(tmp, 'index', '-v7');
                movefile(tmp, obj.File, 'f');   % whole, so another MATLAB never reads it half written
            catch ME
                if ~obj.Warned
                    warning('OutputFileIndex:Save', 'Cannot write the output file index %s (%s); the next scan opens the files again.', ...
                        obj.File, ME.message);
                    obj.Warned = true;
                end
            end
            obj.Added = string.empty(1, 0);
        end
    end
end
