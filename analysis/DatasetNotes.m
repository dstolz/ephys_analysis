classdef DatasetNotes < handle
    %DATASETNOTES  A dataset's notes (on the dataset, its channels, its sorted units), kept beside its outputs.
    %   NOTES = DatasetNotes(TARGET) reads the notes of one dataset from
    %   <Name>_notes.json in its output folder, the folder its <Name>_*.mat
    %   outputs and its stars (DatasetFavorites) are in, so the notes travel
    %   with the data. TARGET is a DatasetOutputs, a loadAnalysisSource
    %   struct (its outputs and folder) or an output folder (Name= its
    %   dataset name, default EphysProject.outputFolderName; the folder is
    %   searched, DatasetOutputs(folder), only when the sort of its units is
    %   first needed). No file is no note. A file that cannot be read is no
    %   note either, with the reason in Problem; setNote then refuses to
    %   write over it.
    %
    %   A note is free text, line breaks kept, on one of a star's levels:
    %     "dataset"  the dataset itself
    %     "channel"  a recording channel, 1-based. A detection channel's
    %                note is its channel's, as its star is
    %     "unit"     a sorted unit by cluster id, recorded with the sort it
    %                was written on (sortIdentity: its folder and the size
    %                of its spike_times.npy, as a star). Only the notes of
    %                the sort in use are the units' (note, hasNote); a new
    %                sort leaves the old notes in the file, on none of its
    %                units, and list(AllSorts=true) still shows them
    %   Each note keeps when it was last written. These notes are not phy's:
    %   the "notes" label of cluster_notes.tsv (the pipeline app's Review
    %   tab, EphysDataset.writeUnitNotes) is another file.
    %
    %     n = DatasetNotes("D:\out\subj1_day1");
    %     n.setNote("unit", 12, "bursty; drifts after 40 min");   % written at once
    %     n.note("unit", 12)                 % "bursty; drifts after 40 min"
    %     n.hasNote("channel", [3 4])        % [false false]
    %     n.setNote("unit", 12, "");         % no text: no note
    %     T = n.list()                       % every note
    %
    %   Properties (read-only)
    %     Name      the dataset name (the file's prefix)
    %     Folder    its output folder (where the file is)
    %     File      Folder/<Name>_notes.json
    %     Notes     every note in the file: struct array of level, id (NaN
    %               for the dataset), sort and spikeTimesBytes (a unit's
    %               sort; "" and NaN for the others), text and updated
    %     Sort      the sort in use: struct(sort, spikeTimesBytes); sort ""
    %               without one (no unit can have a note then)
    %     Updated   when the file was last written (NaT: never)
    %     Problem   why the file could not be read ("" when it was, or there
    %               is none)
    %
    %   Methods
    %     [txt, when] = note(LEVEL, ID)  the note's text and when it was
    %                                  written ("" and NaT when none; LEVEL
    %                                  "dataset": ID is ignored)
    %     tf = hasNote(LEVEL, IDS)     one logical per id (LEVEL "dataset":
    %                                  one logical)
    %     setNote(LEVEL, ID, TEXT)     TEXT (a string, or a text area's lines)
    %                                  becomes the note, written at once;
    %                                  blank TEXT removes it, the same text
    %                                  writes nothing. When it cannot be
    %                                  written (a read-only share, a folder
    %                                  not there) nothing changes and
    %                                  DatasetNotes:CannotWrite says why;
    %                                  DatasetNotes:NoSort for a unit without
    %                                  a sort, DatasetNotes:Unreadable over a
    %                                  file that could not be read
    %     T = list(AllSorts=false)     one row per note: level, id (NaN for
    %                                  the dataset), label ("dataset",
    %                                  "channel 5", "unit 12"), text, updated
    %                                  and current; the dataset, its channels,
    %                                  then its units. AllSorts=true adds the
    %                                  unit notes of other sorts (current
    %                                  false, labeled "unit 12 (another
    %                                  sort)")
    %     save()                       write the file (deleted when it holds
    %                                  no note, of any sort)
    %     reload()                     read the file again
    %   Static
    %     file = DatasetNotes.fileFor(FOLDER, NAME)
    %
    %   The file's shape: documentation/file-formats.md, "Notes".
    %
    %   See also EphysAnalysisApp, NotePad, NoteSearch, DatasetFavorites.

    properties (SetAccess = private)
        Name (1,1) string = ""
        Folder (1,1) string = ""
        Notes struct = struct('level', {}, 'id', {}, 'sort', {}, 'spikeTimesBytes', {}, 'text', {}, 'updated', {})
        Updated (1,1) datetime = NaT
        Problem (1,1) string = ""
    end

    properties (Dependent)
        File
        Sort
    end

    properties (Constant)
        Schema = "ephys-notes/1"
        Levels = ["dataset" "channel" "unit"]
    end

    properties (Access = private)
        Outputs = []          % the DatasetOutputs: its sort, found when first asked (sortInUse); [] for a folder until then
        SortCache = []        % the sort in use, once found
    end

    methods
        function obj = DatasetNotes(target, opts)
            %DatasetNotes  Read the notes of TARGET (DatasetOutputs, loadAnalysisSource struct or output folder).
            arguments
                target
                opts.Name (1,1) string = ""   % the dataset name (default: the DatasetOutputs' Name; a folder's: EphysProject.outputFolderName)
            end
            if isa(target, 'DatasetOutputs')
                out = target;
                if ~isempty(out.Dataset)
                    folder = string(out.Dataset.outputFolder());
                else
                    folder = string(out.Folder);
                end
            elseif isstruct(target) && isfield(target, 'outputs') && isfield(target, 'folder')
                out = target.outputs;
                folder = string(target.folder);
            elseif (isstring(target) || ischar(target)) && isscalar(string(target))
                folder = string(target);
                if ~isfolder(folder)
                    error('DatasetNotes:NoFolder', 'Output folder does not exist: %s', folder);
                end
                out = [];   % searched when the units' sort is first needed (sortInUse)
                if opts.Name == ""; opts.Name = EphysProject.outputFolderName(folder); end
            else
                error('DatasetNotes:BadTarget', 'Pass a DatasetOutputs, a loadAnalysisSource struct or an output folder.');
            end
            obj.Outputs = out;
            if opts.Name ~= ""
                obj.Name = opts.Name;
            else
                obj.Name = string(out.Name);
            end
            obj.Folder = folder;
            obj.reload();
        end

        function f = get.File(obj)
            f = DatasetNotes.fileFor(obj.Folder, obj.Name);
        end

        function s = get.Sort(obj)
            s = sortInUse(obj);
        end

        function reload(obj)
            %reload  Read the file again (no file: no note; a bad one: no note, Problem says why).
            obj.Notes = DatasetNotes.noNotes();
            obj.Updated = NaT;
            obj.Problem = "";
            obj.SortCache = [];   % the sort is looked up again too
            f = obj.File;
            if ~isfile(f); return; end
            try
                J = readJsonFile(f);
                if ~isstruct(J) || ~isfield(J, 'schema') || string(J.schema) ~= DatasetNotes.Schema
                    error('DatasetNotes:BadFile', 'not an %s file', DatasetNotes.Schema);
                end
                N = DatasetNotes.noNotes();
                if isfield(J, 'note') && isstruct(J.note)
                    N = [N noteRow("dataset", NaN, "", NaN, J.note)];
                end
                if isfield(J, 'channels')
                    for c = asStructs(J.channels)
                        N = [N noteRow("channel", double(c.id), "", NaN, c)]; %#ok<AGROW>
                    end
                end
                if isfield(J, 'units')
                    for u = asStructs(J.units)
                        b = NaN;
                        if isfield(u, 'spikeTimesBytes') && isnumeric(u.spikeTimesBytes) && isscalar(u.spikeTimesBytes)
                            b = double(u.spikeTimesBytes);
                        end
                        for c = asStructs(u.notes)
                            N = [N noteRow("unit", double(c.id), string(u.sort), b, c)]; %#ok<AGROW>
                        end
                    end
                end
                if ~isempty(N); N = N([N.text] ~= ""); end   % a blank note is no note
                obj.Notes = N;
                if isfield(J, 'updated') && string(J.updated) ~= ""
                    obj.Updated = stamp(J.updated);
                end
            catch ME
                obj.Notes = DatasetNotes.noNotes();
                obj.Problem = "cannot read " + f + ": " + string(ME.message);
            end
        end

        function [txt, updated] = note(obj, level, id)
            %note  The note on ID at LEVEL and when it was written ("" and NaT when none; LEVEL "dataset": the dataset's, ID ignored).
            arguments
                obj (1,1) DatasetNotes
                level (1,1) string
                id double = NaN
            end
            txt = "";
            updated = NaT;
            level = checkLevel(level);
            if level == "dataset"; id = NaN; end
            k = find(rowsOf(obj, level, id), 1);
            if ~isempty(k)
                txt = obj.Notes(k).text;
                updated = obj.Notes(k).updated;
            end
        end

        function tf = hasNote(obj, level, ids)
            %hasNote  Whether each of IDS has a note at LEVEL (LEVEL "dataset": the dataset, IDS ignored).
            arguments
                obj (1,1) DatasetNotes
                level (1,1) string
                ids double = []
            end
            level = checkLevel(level);
            if level == "dataset"
                tf = any(rowsOf(obj, level, NaN));
                return
            end
            tf = false(size(ids));
            if isempty(obj.Notes) || isempty(ids); return; end
            on = rowsOf(obj, level, NaN, AnyId=true);
            tf = ismember(ids, [obj.Notes(on).id]);
        end

        function setNote(obj, level, id, text)
            %setNote  TEXT becomes the note on ID at LEVEL, written at once (blank TEXT: no note); nothing changes when it cannot be written.
            arguments
                obj (1,1) DatasetNotes
                level (1,1) string
                id double
                text
            end
            level = checkLevel(level);
            if obj.Problem ~= ""
                error('DatasetNotes:Unreadable', 'The notes of %s are not changed: %s. Fix or delete the file first.', ...
                    obj.Name, obj.Problem);
            end
            if level == "dataset"
                id = NaN;
            elseif ~isscalar(id) || ~isfinite(id) || id ~= round(id) || id < (level == "channel")
                error('DatasetNotes:BadId', 'A %s is one whole number%s.', level, ...
                    ternary(level == "channel", " from 1", " from 0"));
            end
            text = cleanText(text);
            s = struct('sort', "", 'spikeTimesBytes', NaN);
            if level == "unit"
                s = sortInUse(obj);
                if s.sort == ""
                    error('DatasetNotes:NoSort', '%s has no sorted units to write a note on.', obj.Name);
                end
            end
            k = find(rowsOf(obj, level, id), 1);
            if isempty(k) && text == ""; return; end
            if ~isempty(k) && obj.Notes(k).text == text; return; end
            before = {obj.Notes, obj.Updated};
            if text == ""
                obj.Notes(k) = [];
            elseif isempty(k)
                obj.Notes(end+1) = struct('level', level, 'id', id, 'sort', s.sort, 'spikeTimesBytes', s.spikeTimesBytes, ...
                    'text', text, 'updated', now_());
            else
                obj.Notes(k).text = text;
                obj.Notes(k).updated = now_();
            end
            try
                obj.save();
            catch ME
                [obj.Notes, obj.Updated] = before{:};
                rethrow(ME);
            end
        end

        function T = list(obj, opts)
            %list  Every note: level, id, label, text, updated, current; the dataset, its channels, then its units (AllSorts=true: of every sort).
            arguments
                obj (1,1) DatasetNotes
                opts.AllSorts (1,1) logical = false
            end
            N = obj.Notes;
            if isempty(N)
                T = table(strings(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), NaT(0, 1), false(0, 1), ...
                    'VariableNames', ["level" "id" "label" "text" "updated" "current"]);
                return
            end
            current = true(1, numel(N));
            isUnit = [N.level] == "unit";
            if any(isUnit)
                current(isUnit) = rowsOf(obj, "unit", NaN, AnyId=true, Rows=find(isUnit));
            end
            if ~opts.AllSorts
                N = N(current);
                current = current(current);
            end
            rank = zeros(1, numel(N));
            for k = 1:numel(N)
                rank(k) = find(DatasetNotes.Levels == N(k).level);
            end
            [~, order] = sortrows([rank; ~current; [N.id]].');
            N = N(order);
            current = reshape(current(order), [], 1);
            level = reshape([N.level], [], 1);
            id = reshape([N.id], [], 1);
            text = reshape([N.text], [], 1);
            updated = reshape([datetime.empty(0, 1); N.updated], [], 1);
            updated.Format = 'yyyy-MM-dd''T''HH:mm:ss';
            label = level + " " + string(id);
            label(level == "dataset") = "dataset";
            label(~current) = label(~current) + " (another sort)";
            T = table(level, id, label, text, updated, current);
        end

        function save(obj)
            %save  Write the file (atomically: writeJsonFile); delete it when it holds no note.
            f = obj.File;
            if ~isfolder(obj.Folder)
                error('DatasetNotes:CannotWrite', 'Cannot write the notes of %s: its output folder is not there (%s).', ...
                    obj.Name, obj.Folder);
            end
            N = obj.Notes;
            if isempty(N)
                if isfile(f)
                    try
                        delete(f);
                    catch ME
                        error('DatasetNotes:CannotWrite', 'Cannot remove %s (read-only?): %s', f, ME.message);
                    end
                    if isfile(f)
                        error('DatasetNotes:CannotWrite', 'Cannot remove %s: the folder is read-only.', f);
                    end
                end
                obj.Updated = NaT;
                return
            end
            J = struct('schema', DatasetNotes.Schema, 'dataset', obj.Name);
            d = N([N.level] == "dataset");
            if ~isempty(d); J.note = noteJson(d(1)); end
            C = N([N.level] == "channel");
            [~, o] = sort([C.id]);
            J.channels = arrayfun(@noteJson, C(o), 'UniformOutput', false);
            U = N([N.level] == "unit");
            sorts = {};
            if ~isempty(U)
                key = [U.sort] + "|" + string([U.spikeTimesBytes]);   % NaN bytes: "NaN", one key still
                [~, first, which] = unique(key, 'stable');
                for g = 1:numel(first)
                    G = U(which == g);
                    [~, o] = sort([G.id]);
                    sorts{end+1} = struct('sort', G(1).sort, 'spikeTimesBytes', G(1).spikeTimesBytes, ...
                        'notes', {arrayfun(@noteJson, G(o), 'UniformOutput', false)}); %#ok<AGROW>
                end
            end
            J.units = sorts;
            t = now_();
            J.updated = string(t);
            try
                writeJsonFile(f, J);
            catch ME
                error('DatasetNotes:CannotWrite', 'Cannot write the notes of %s into %s (read-only?): %s', ...
                    obj.Name, obj.Folder, ME.message);
            end
            obj.Updated = t;
        end
    end

    methods (Static)
        function f = fileFor(folder, name)
            %fileFor  The notes file of dataset NAME in its output folder FOLDER.
            f = string(fullfile(folder, name + "_notes.json"));
        end
    end

    methods (Static, Access = private)
        function N = noNotes()
            N = struct('level', {}, 'id', {}, 'sort', {}, 'spikeTimesBytes', {}, 'text', {}, 'updated', {});
        end
    end

    methods (Access = private)
        function s = sortInUse(obj)
            %sortInUse  The sort the dataset uses now (sortIdentity, as a star's), looked up once.
            if ~isempty(obj.SortCache); s = obj.SortCache; return; end
            [s, obj.Outputs] = sortIdentity(obj.Outputs, obj.Folder, obj.Name);
            obj.SortCache = s;
        end

        function tf = rowsOf(obj, level, id, opts)
            %rowsOf  Which notes (of ROWS, default all) are on ID at LEVEL (AnyId: any id); a unit's only on the sort in use.
            arguments
                obj
                level (1,1) string
                id (1,1) double
                opts.AnyId (1,1) logical = false
                opts.Rows double = 1:numel(obj.Notes)
            end
            N = obj.Notes(opts.Rows);
            tf = false(1, numel(N));
            if isempty(N); return; end
            tf = [N.level] == level;
            if level ~= "dataset" && ~opts.AnyId
                tf = tf & [N.id] == id;
            end
            if level == "unit" && any(tf)
                s = sortInUse(obj);
                tf = tf & strcmpi([N.sort], s.sort) & arrayfun(@(n) isequaln(n.spikeTimesBytes, s.spikeTimesBytes), N);
            end
        end
    end
end


function level = checkLevel(level)
level = lower(string(level));
if ~ismember(level, DatasetNotes.Levels)
    error('DatasetNotes:BadLevel', 'A note''s level is %s (got "%s").', strjoin(DatasetNotes.Levels, ", "), level);
end
end


function t = cleanText(t)
%cleanText  A note's text as one string: a text area's lines joined by line breaks, CR LF as LF, blank ends trimmed.
if iscell(t) || (isstring(t) && ~isscalar(t)) || (ischar(t) && size(t, 1) > 1)
    t = strjoin(reshape(string(cellstr(t)), 1, []), newline);
end
t = string(t);
if isempty(t) || ismissing(t); t = ""; end
t = strtrim(replace(replace(t, sprintf('\r\n'), newline), sprintf('\r'), newline));
end


function S = asStructs(v)
%asStructs  A decoded JSON list of objects as a row of structs (a cell of differing ones joined).
if isempty(v); S = struct([]); S = reshape(S, 1, 0); return; end
if iscell(v); v = [v{:}]; end
S = reshape(v, 1, []);
end


function n = noteRow(level, id, sort, bytes, j)
%noteRow  One entry of Notes from a decoded note object J (text, updated).
t = "";
if isfield(j, 'text'); t = cleanText(j.text); end
u = NaT;
if isfield(j, 'updated'); u = stamp(j.updated); end
n = struct('level', level, 'id', id, 'sort', sort, 'spikeTimesBytes', bytes, 'text', t, 'updated', u);
end


function j = noteJson(n)
%noteJson  A note as it is written: its id (but the dataset's), text and when.
if n.level == "dataset"
    j = struct('text', n.text, 'updated', string(n.updated));
else
    j = struct('id', n.id, 'text', n.text, 'updated', string(n.updated));
end
end


function t = stamp(v)
%stamp  A file's time stamp as a datetime (NaT when blank or not one).
t = NaT;
v = string(v);
if isscalar(v) && ~ismissing(v) && v ~= ""
    try
        t = datetime(v, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss', 'Format', 'yyyy-MM-dd''T''HH:mm:ss');
    catch
    end
end
end


function t = now_()
t = datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss');
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
