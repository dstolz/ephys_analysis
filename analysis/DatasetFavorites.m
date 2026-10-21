classdef DatasetFavorites < handle
    %DATASETFAVORITES  A dataset's stars (the dataset, its channels, its sorted units), kept beside its outputs.
    %   FAV = DatasetFavorites(TARGET) reads the stars of one dataset from
    %   <Name>_favorites.json in its output folder, the folder its
    %   <Name>_*.mat outputs are in, so the stars travel with the data: to
    %   the lab's share, another PC, another user. TARGET is a DatasetOutputs,
    %   a loadAnalysisSource struct (its outputs and folder) or an output
    %   folder (Name= its dataset name, default EphysProject.outputFolderName;
    %   the folder is searched, DatasetOutputs(folder), only when the sort of
    %   its units is first needed). No file is no star. A file
    %   that cannot be read is no star either, with the reason in Problem;
    %   star then refuses to write over it.
    %
    %   A star is on or off, at three levels:
    %     "dataset"  the dataset itself
    %     "channel"  recording channels, 1-based (figureObservations'
    %                channel column, selectChannels' recordingChannel). A
    %                detection channel (the "detected" spikes) is starred as
    %                its channel, so a channel's star shows on its LFP, MUA
    %                and SPIKE columns and on its detections alike
    %     "unit"     sorted units by cluster id, recorded with the sort they
    %                were starred on: its folder (relative to the output
    %                folder when inside it, else the full path) and the size
    %                of its spike_times.npy. Only the stars of the sort in use
    %                count (UnitIds). A new sort, in another folder or over
    %                the old one (other spike times), leaves the old stars in
    %                the file on none of its units, so a star never moves to
    %                another unit. Curating in phy keeps spike_times.npy: the
    %                units it leaves alone keep their stars, merged or split
    %                units get new ids and no star
    %
    %     fav = DatasetFavorites("D:\out\subj1_day1");
    %     fav.star("unit", [12 40]);         % written at once
    %     fav.isStarred("unit", [12 13])     % [true false]
    %     fav.star("dataset", [], false);    % unstar
    %     T = fav.list()                     % what is starred
    %
    %   Properties (read-only)
    %     Name      the dataset name (the file's prefix)
    %     Folder    its output folder (where the file is)
    %     File      Folder/<Name>_favorites.json
    %     Dataset   the dataset is starred
    %     Channels  the starred channels, ascending
    %     UnitIds   the starred units of the sort in use, ascending
    %     Units     every sort's starred units: struct array of sort (its
    %               folder), spikeTimesBytes and ids
    %     Sort      the sort in use: struct(sort, spikeTimesBytes); sort ""
    %               without one (no unit can be starred then)
    %     Updated   when the file was last written (NaT: never)
    %     Problem   why the file could not be read ("" when it was, or there
    %               is none)
    %
    %   Methods
    %     tf = isStarred(LEVEL, IDS)   one logical per id (LEVEL "dataset":
    %                                  IDS is ignored, one logical)
    %     tf = observationStarred(T, DATA)
    %                                  one logical per row of T, a
    %                                  figureObservations table of the
    %                                  figure observing DATA (its
    %                                  observe.data): a sorted unit by its
    %                                  id on the sort in use, a detection
    %                                  channel (DATA "detected") and a
    %                                  channel by their recording channel,
    %                                  the dataset by its own star; a row
    %                                  of another kind ("": none) is not
    %     star(LEVEL, IDS, TF)         star (TF true, the default) or unstar
    %                                  IDS and write the file at once. When it
    %                                  cannot be written (a read-only share,
    %                                  a folder not there) nothing changes and
    %                                  DatasetFavorites:CannotWrite says why;
    %                                  DatasetFavorites:NoSort for a unit
    %                                  without a sort, DatasetFavorites:Unreadable
    %                                  over a file that could not be read
    %     T = list()                   what is starred, one row each: level,
    %                                  id (NaN for the dataset), label
    %                                  ("dataset", "channel 5", "unit 12");
    %                                  the dataset, its channels, then the
    %                                  units of the sort in use
    %     save()                       write the file (deleted when nothing,
    %                                  of any sort, is starred)
    %     reload()                     read the file again
    %   Static
    %     file = DatasetFavorites.fileFor(FOLDER, NAME)
    %
    %   The file's shape: documentation/file-formats.md, "Favorites".
    %
    %   See also EphysAnalysisApp, loadAnalysisSource, DatasetOutputs,
    %   figureObservations, unitSummary.

    properties (SetAccess = private)
        Name (1,1) string = ""
        Folder (1,1) string = ""
        Dataset (1,1) logical = false
        Channels (1,:) double = zeros(1, 0)
        Units struct = struct('sort', {}, 'spikeTimesBytes', {}, 'ids', {})
        Updated (1,1) datetime = NaT
        Problem (1,1) string = ""
    end

    properties (Dependent)
        File
        Sort
        UnitIds
    end

    properties (Constant)
        Schema = "ephys-favorites/1"
        Levels = ["dataset" "channel" "unit"]
    end

    properties (Access = private)
        Outputs = []          % the DatasetOutputs: its sort, found when first asked (sortInUse); [] for a folder until then
        SortCache = []        % the sort in use, once found
    end

    methods
        function obj = DatasetFavorites(target, opts)
            %DatasetFavorites  Read the stars of TARGET (DatasetOutputs, loadAnalysisSource struct or output folder).
            arguments
                target
                opts.Name (1,1) string = ""   % the dataset name (default: the DatasetOutputs' Name; a folder's: EphysProject.outputFolderName)
            end
            if isa(target, 'DatasetOutputs')
                out = target;
                folder = folderOf(out);
            elseif isstruct(target) && isfield(target, 'outputs') && isfield(target, 'folder')
                out = target.outputs;
                folder = string(target.folder);
            elseif (isstring(target) || ischar(target)) && isscalar(string(target))
                folder = string(target);
                if ~isfolder(folder)
                    error('DatasetFavorites:NoFolder', 'Output folder does not exist: %s', folder);
                end
                out = [];   % searched when the units' sort is first needed (sortInUse)
                if opts.Name == ""; opts.Name = EphysProject.outputFolderName(folder); end
            else
                error('DatasetFavorites:BadTarget', 'Pass a DatasetOutputs, a loadAnalysisSource struct or an output folder.');
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
            f = DatasetFavorites.fileFor(obj.Folder, obj.Name);
        end

        function s = get.Sort(obj)
            s = sortInUse(obj);
        end

        function ids = get.UnitIds(obj)
            ids = zeros(1, 0);
            k = sortRow(obj);
            if k > 0; ids = obj.Units(k).ids; end
        end

        function reload(obj)
            %reload  Read the file again (no file: no star; a bad one: no star, Problem says why).
            obj.Dataset = false;
            obj.Channels = zeros(1, 0);
            obj.Units = DatasetFavorites.noUnits();
            obj.Updated = NaT;
            obj.Problem = "";
            obj.SortCache = [];   % the sort is looked up again too
            f = obj.File;
            if ~isfile(f); return; end
            try
                J = readJsonFile(f);
                if ~isstruct(J) || ~isfield(J, 'schema') || string(J.schema) ~= DatasetFavorites.Schema
                    error('DatasetFavorites:BadFile', 'not an %s file', DatasetFavorites.Schema);
                end
                if isfield(J, 'starred'); obj.Dataset = isequal(J.starred, true); end
                if isfield(J, 'channels'); obj.Channels = idList(J.channels); end
                if isfield(J, 'units') && ~isempty(J.units)
                    U = J.units;
                    if iscell(U); U = [U{:}]; end
                    for u = reshape(U, 1, [])
                        b = NaN;
                        if isfield(u, 'spikeTimesBytes') && isnumeric(u.spikeTimesBytes) && isscalar(u.spikeTimesBytes)
                            b = double(u.spikeTimesBytes);
                        end
                        obj.Units(end+1) = struct('sort', string(u.sort), 'spikeTimesBytes', b, 'ids', idList(u.ids));
                    end
                end
                if isfield(J, 'updated') && string(J.updated) ~= ""
                    obj.Updated = datetime(string(J.updated), 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
                end
            catch ME
                obj.Dataset = false;
                obj.Channels = zeros(1, 0);
                obj.Units = DatasetFavorites.noUnits();
                obj.Problem = "cannot read " + f + ": " + string(ME.message);
            end
        end

        function tf = isStarred(obj, level, ids)
            %isStarred  Whether each of IDS is starred at LEVEL (LEVEL "dataset": the dataset, IDS ignored).
            arguments
                obj (1,1) DatasetFavorites
                level (1,1) string
                ids double = []
            end
            switch checkLevel(level)
                case "dataset"
                    tf = obj.Dataset;
                case "channel"
                    tf = ismember(ids, obj.Channels);
                case "unit"
                    tf = ismember(ids, obj.UnitIds);
            end
        end

        function tf = observationStarred(obj, T, data)
            %observationStarred  Whether each row of T (figureObservations) is starred, for a figure observing DATA.
            arguments
                obj (1,1) DatasetFavorites
                T table
                data (1,1) string
            end
            tf = false(height(T), 1);
            if height(T) == 0; return; end
            kind = string(T.kind);
            tf(kind == "dataset") = obj.Dataset;
            u = kind == "unit";
            if data == "detected"
                tf(u) = ismember(T.channel(u), obj.Channels);
            elseif any(u)
                tf(u) = ismember(T.unitId(u), obj.UnitIds);
            end
            c = kind == "channel";
            tf(c) = ismember(T.channel(c), obj.Channels);
        end

        function star(obj, level, ids, tf)
            %star  Star (TF true) or unstar IDS at LEVEL and write the file at once; nothing changes when it cannot be written.
            arguments
                obj (1,1) DatasetFavorites
                level (1,1) string
                ids double = []
                tf (1,1) logical = true
            end
            level = checkLevel(level);
            if obj.Problem ~= ""
                error('DatasetFavorites:Unreadable', 'The stars of %s are not changed: %s. Fix or delete the file first.', ...
                    obj.Name, obj.Problem);
            end
            ids = reshape(double(ids), 1, []);
            if level ~= "dataset" && (any(~isfinite(ids)) || any(ids ~= round(ids)) || any(ids < (level == "channel")))
                error('DatasetFavorites:BadId', 'A %s is a whole number%s.', level, ...
                    ternary(level == "channel", " from 1", " from 0"));
            end
            before = {obj.Dataset, obj.Channels, obj.Units, obj.Updated};
            switch level
                case "dataset"
                    obj.Dataset = tf;
                case "channel"
                    obj.Channels = setIds(obj.Channels, ids, tf);
                case "unit"
                    s = sortInUse(obj);
                    if s.sort == ""
                        error('DatasetFavorites:NoSort', '%s has no sorted units to star.', obj.Name);
                    end
                    k = sortRow(obj);
                    if k == 0
                        obj.Units(end+1) = struct('sort', s.sort, 'spikeTimesBytes', s.spikeTimesBytes, 'ids', zeros(1, 0));
                        k = numel(obj.Units);
                    end
                    obj.Units(k).ids = setIds(obj.Units(k).ids, ids, tf);
                    obj.Units = obj.Units(arrayfun(@(u) ~isempty(u.ids), obj.Units));   % a sort left without stars is dropped
            end
            try
                obj.save();
            catch ME
                [obj.Dataset, obj.Channels, obj.Units, obj.Updated] = before{:};
                rethrow(ME);
            end
        end

        function T = list(obj)
            %list  What is starred: level, id, label; the dataset, its channels, then the sort in use's units.
            ch = reshape(obj.Channels, [], 1);
            un = reshape(obj.UnitIds, [], 1);
            level = [repmat("dataset", double(obj.Dataset), 1); repmat("channel", numel(ch), 1); repmat("unit", numel(un), 1)];
            id = [NaN(double(obj.Dataset), 1); ch; un];
            label = [repmat("dataset", double(obj.Dataset), 1); "channel " + string(ch); "unit " + string(un)];
            T = table(level, id, label);
        end

        function save(obj)
            %save  Write the file (atomically: writeJsonFile); delete it when nothing is starred.
            f = obj.File;
            if ~isfolder(obj.Folder)
                error('DatasetFavorites:CannotWrite', 'Cannot write the stars of %s: its output folder is not there (%s).', ...
                    obj.Name, obj.Folder);
            end
            if ~obj.Dataset && isempty(obj.Channels) && isempty(obj.Units)
                if isfile(f)
                    try
                        delete(f);
                    catch ME
                        error('DatasetFavorites:CannotWrite', 'Cannot remove %s (read-only?): %s', f, ME.message);
                    end
                    if isfile(f)
                        error('DatasetFavorites:CannotWrite', 'Cannot remove %s: the folder is read-only.', f);
                    end
                end
                obj.Updated = NaT;
                return
            end
            now_ = datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss');
            U = cell(1, numel(obj.Units));
            for k = 1:numel(obj.Units)
                u = obj.Units(k);
                U{k} = struct('sort', u.sort, 'spikeTimesBytes', u.spikeTimesBytes, 'ids', {num2cell(u.ids)});
            end
            J = struct('schema', DatasetFavorites.Schema, 'dataset', obj.Name, 'starred', obj.Dataset, ...
                'channels', {num2cell(obj.Channels)}, 'units', {U}, 'updated', string(now_));
            try
                writeJsonFile(f, J);
            catch ME
                error('DatasetFavorites:CannotWrite', 'Cannot write the stars of %s into %s (read-only?): %s', ...
                    obj.Name, obj.Folder, ME.message);
            end
            obj.Updated = now_;
        end
    end

    methods (Static)
        function f = fileFor(folder, name)
            %fileFor  The favorites file of dataset NAME in its output folder FOLDER.
            f = string(fullfile(folder, name + "_favorites.json"));
        end
    end

    methods (Static, Access = private)
        function U = noUnits()
            U = struct('sort', {}, 'spikeTimesBytes', {}, 'ids', {});
        end
    end

    methods (Access = private)
        function s = sortInUse(obj)
            %sortInUse  The sort the dataset uses now (sortIdentity: its phy folder and spike_times.npy's size), looked up once.
            if ~isempty(obj.SortCache); s = obj.SortCache; return; end
            [s, obj.Outputs] = sortIdentity(obj.Outputs, obj.Folder, obj.Name);
            obj.SortCache = s;
        end

        function k = sortRow(obj)
            %sortRow  The row of Units recorded on the sort in use (0: none).
            k = 0;
            if isempty(obj.Units); return; end
            s = sortInUse(obj);
            if s.sort == ""; return; end
            same = arrayfun(@(u) strcmpi(u.sort, s.sort) && isequaln(u.spikeTimesBytes, s.spikeTimesBytes), obj.Units);
            k = find(same, 1);
            if isempty(k); k = 0; end
        end
    end
end


function f = folderOf(out)
%folderOf  A DatasetOutputs' output folder: its dataset's outputFolder(), else its Folder.
if ~isempty(out.Dataset)
    f = string(out.Dataset.outputFolder());
else
    f = string(out.Folder);
end
end


function level = checkLevel(level)
level = lower(string(level));
if ~ismember(level, DatasetFavorites.Levels)
    error('DatasetFavorites:BadLevel', 'A star''s level is %s (got "%s").', strjoin(DatasetFavorites.Levels, ", "), level);
end
end


function ids = idList(v)
%idList  A decoded JSON list of ids as a sorted row of doubles.
if iscell(v); v = [v{:}]; end
if isempty(v); ids = zeros(1, 0); return; end
ids = unique(reshape(double(v), 1, []));
end


function ids = setIds(ids, add, tf)
if tf
    ids = unique([ids add]);
else
    ids = setdiff(ids, add);
end
ids = reshape(ids, 1, []);
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
