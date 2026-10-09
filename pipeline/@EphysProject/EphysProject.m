classdef EphysProject < handle
    % EphysProject  Discover and batch many recordings to Kilosort4.
    %   A project scans a root directory for recording folders (any reader),
    %   wraps each as an EphysDataset, and provides batch operations: gather
    %   metadata into a table, write all .bin files, and launch Kilosort4 for
    %   every dataset. Shared configuration (probe, python/conda, output root,
    %   scale, dtype) is pushed down into each EphysDataset.
    %
    %   Construction
    %   ------------
    %     P = EphysProject(root)
    %     P = EphysProject(root, ProbeFile=..., PythonExe=..., OutputRoot=...)
    %
    %   Workflow
    %   --------
    %     P = EphysProject("D:\experiments");
    %     P.refresh();                   % headers + per-dataset manifests
    %     T = P.gatherMetadata();        % one row per dataset
    %     P.toBinAll();                  % stream every dataset's .bin
    %   Sorting goes through EphysPipeline (runSorting).
    %
    %   Outputs without the recordings
    %   ------------------------------
    %   A root that holds no recording but the pipeline's outputs (a copy of
    %   an OutputRoot, e.g. a backup) gives one dataset per output folder,
    %   with a warning (EphysProject:OutputsOnly; see findOutputFolders):
    %     P = EphysProject("S:\backup\EXTRACT");
    %     P.refresh();                   % metadata from the outputs; nothing written
    %     u = P.Datasets(1).outputs().Units;
    %   Their hasRecording() is false: nothing that reads a recording runs.
    %   A version folder <name>_v<n> that the pipeline's output transfer
    %   made beside an earlier copy is the dataset <name> again (its key
    %   keeps the folder's name): see outputFolderName.
    %
    %   See also EPHYSDATASET.

    properties
        Root (1,1) string = ""
        Datasets (1,:) EphysDataset = EphysDataset.empty(1,0)

        % Shared defaults pushed into each dataset
        ProbeFile  (1,1) string = ""
        PythonExe  (1,1) string = ""
        CondaEnv   (1,1) string = ""
        OutputRoot (1,1) string = ""    % per-dataset output goes under OutputRoot/<Name>
        Scale      (1,1) double = NaN      % .bin units per uV; NaN = each dataset's own (EphysDataset.binScale)
        Dtype      (1,1) string = "int16"
        Manifest                          % optional shared Manifest

        % parseNameTokens pattern splitting dataset names into the SubjectID,
        % Date and Time that label sorted units (see unitIdentities).
        NamePattern (1,1) string = EphysDataset.DefaultNamePattern

        % discover() searches every sub-folder of Root; false = only Root
        % and the folders directly in it.
        Recursive (1,1) logical = true

        % Reader options (the pipeline config's Acquisition section), used
        % to find the recordings (Open Ephys recording modes) and pushed into
        % every dataset.
        ReaderOptions struct = struct()
    end

    properties (Dependent)
        NumDatasets
    end

    methods
        % --- methods defined in separate files ---
        T       = gatherMetadata(obj, opts)
        infos   = toBinAll(obj, varargin)
        report  = refresh(obj, opts)

        function obj = EphysProject(root, opts)
            arguments
                root (1,1) string = ""
                opts.ProbeFile  (1,1) string = ""
                opts.PythonExe  (1,1) string = ""
                opts.CondaEnv   (1,1) string = ""
                opts.OutputRoot (1,1) string = ""
                opts.Scale      (1,1) double = NaN
                opts.Dtype      (1,1) string = "int16"
                opts.NamePattern (1,1) string = EphysDataset.DefaultNamePattern
                opts.Recursive  (1,1) logical = true
                opts.ReaderOptions struct = struct()
                opts.Manifest   = []
                opts.AutoDiscover (1,1) logical = true
            end

            if root == ""
                return
            end
            if ~isfolder(root)
                error('EphysProject:NoRoot', 'Root does not exist: %s', root);
            end

            obj.Root       = string(root);
            obj.ProbeFile  = opts.ProbeFile;
            obj.PythonExe  = opts.PythonExe;
            obj.CondaEnv   = opts.CondaEnv;
            obj.OutputRoot = opts.OutputRoot;
            obj.Scale      = opts.Scale;
            obj.Dtype      = opts.Dtype;
            obj.NamePattern = opts.NamePattern;
            obj.Recursive  = opts.Recursive;
            obj.ReaderOptions = opts.ReaderOptions;
            if ~isempty(opts.Manifest)
                obj.Manifest = opts.Manifest;
            end

            if opts.AutoDiscover
                obj.discover();
            end
        end

        function discover(obj)
            %discover  Find every recording folder under Root (any reader).
            %   One EphysDataset is created per folder with AutoMetadata=false
            %   (cheap); shared config is pushed into each. Folder discovery is
            %   delegated to the EphysReader registry (as in DatasetTracker) so
            %   the project and the tracker agree on what counts as a recording.
            %   With Recursive false only Root and the folders directly in it
            %   are recordings; deeper folders are not searched. ReaderOptions
            %   decide what a recording folder is where a format allows
            %   several (Open Ephys recording modes). When Root holds no
            %   recording, its folders of pipeline outputs are the datasets
            %   instead (findOutputFolders), with a warning
            %   (EphysProject:OutputsOnly): their outputs can be read, but
            %   nothing that reads a recording runs on them.
            opt = obj.ReaderOptions;
            if obj.Recursive
                folders = EphysReader.findAllRecordingFolders(obj.Root, true, Options=opt);
            else
                sub = dir(obj.Root);
                sub = sub([sub.isdir] & ~ismember({sub.name}, {'.', '..'}));
                folders = EphysReader.findAllRecordingFolders(obj.Root, false, Options=opt);
                for k = 1:numel(sub)
                    folders = [folders, EphysReader.findAllRecordingFolders( ...
                        string(fullfile(sub(k).folder, sub(k).name)), false, Options=opt)]; %#ok<AGROW>
                end
                folders = unique(folders, 'stable');
            end
            names = strings(1, numel(folders));   % "": a recording's name is its folder's
            if isempty(folders)
                [folders, names] = EphysProject.findOutputFolders(obj.Root, obj.Recursive);
                if ~isempty(folders)
                    warning('EphysProject:OutputsOnly', ...
                        ['No recordings found under %s; its %d folder(s) of pipeline outputs are the datasets. ' ...
                         'Their outputs can be read (outputs()), but nothing that reads a recording runs on them.'], ...
                        obj.Root, numel(folders));
                end
            end
            if isempty(folders)
                obj.Datasets = EphysDataset.empty(1,0);
                warning('EphysProject:NoData', ...
                    'No recordings found under %s', obj.Root);
                return
            end

            ds = EphysDataset.empty(1, 0);
            for i = 1:numel(folders)
                d = EphysDataset(folders(i), AutoMetadata=false, ReaderOptions=obj.ReaderOptions, Name=names(i));
                obj.pushConfig(d);
                ds(end+1) = d; %#ok<AGROW>
            end
            obj.Datasets = ds;

            fprintf('Discovered %d dataset folder(s) under %s\n', numel(ds), obj.Root);
        end

        function pushConfig(obj, d)
            %pushConfig  Copy shared defaults into one EphysDataset.
            %   Also sets its NamePattern and DatasetKey (folder relative to Root),
            %   which label its sorted units, and its OutputDir:
            %   <OutputRoot>/<Name>, or "" (outputs next to the recording)
            %   without an OutputRoot. A dataset without its recording
            %   (hasRecording false) keeps "": its outputs are in its folder.
            arguments
                obj (1,1) EphysProject
                d (1,1) EphysDataset
            end
            d.ProbeFile = obj.ProbeFile;
            d.PythonExe = obj.PythonExe;
            d.CondaEnv  = obj.CondaEnv;
            d.Scale     = obj.Scale;
            d.Dtype     = obj.Dtype;
            d.NamePattern = obj.NamePattern;
            d.ReaderOptions = obj.ReaderOptions;
            d.DatasetKey  = EphysProject.relativeKey(obj.Root, d.Folder);
            if ~isempty(obj.Manifest)
                d.Manifest = obj.Manifest;
            end
            if obj.OutputRoot ~= "" && d.hasRecording()
                d.OutputDir = fullfile(obj.OutputRoot, d.Name);
            else
                d.OutputDir = "";
            end
        end

        function key = datasetKey(obj, idx)
            %datasetKey  Stable key for dataset IDX: its folder relative to Root.
            %   Names (folder leaves) are not unique across a project tree, so
            %   selections saved to a pipeline config use these keys. Forward
            %   slashes, no leading separator; the Root itself is ".".
            arguments
                obj (1,1) EphysProject
                idx (1,1) double {mustBeInteger, mustBePositive}
            end
            key = EphysProject.relativeKey(obj.Root, obj.Datasets(idx).Folder);
        end

        function keys = datasetKeys(obj)
            %datasetKeys  Relative-path keys of every dataset (1 x N string).
            n = obj.NumDatasets;
            keys = strings(1, n);
            for i = 1:n
                keys(i) = obj.datasetKey(i);
            end
        end

        function idx = findByKey(obj, keys)
            %findByKey  Dataset indices for relative keys (0 where not found).
            arguments
                obj (1,1) EphysProject
                keys (1,:) string
            end
            all = obj.datasetKeys();
            idx = zeros(1, numel(keys));
            for k = 1:numel(keys)
                ix = find(all == EphysProject.normalizeKey(keys(k)), 1);
                if ~isempty(ix); idx(k) = ix; end
            end
        end

        function T = unitIdentities(obj, opts)
            %unitIdentities  How each dataset's sorted units are labeled.
            %   T = P.unitIdentities() has one row per dataset: Key, Name, Subject,
            %   RecordingStart, LabelSuffix ("<subject>_<yyMMdd>T<HHmm>", the tail of
            %   its unit labels), Status and Message. Status is "ok"; why the name
            %   cannot label units ("pattern" | "nomatch" | "subject" | "datetime",
            %   see EphysDataset.nameIdentity); or "collision" when another dataset
            %   in scope has the same LabelSuffix (same subject, recording start in
            %   the same minute), so the two would share unit labels.
            %
            %   Options: Among (dataset indices in scope, default all) and
            %   NamePattern (use this pattern instead of each dataset's own, e.g.
            %   an edit not yet applied).
            arguments
                obj (1,1) EphysProject
                opts.Among (1,:) double = 1:obj.NumDatasets
                opts.NamePattern (1,1) string = ""
            end
            idx = unique(opts.Among(opts.Among >= 1 & opts.Among <= obj.NumDatasets), 'stable');
            n = numel(idx);
            Key = strings(n, 1); Name = strings(n, 1); Subject = strings(n, 1);
            RecordingStart = NaT(n, 1, 'Format', 'yyyy-MM-dd HH:mm:ss');
            LabelSuffix = strings(n, 1); Status = strings(n, 1); Message = strings(n, 1);
            for k = 1:n
                d = obj.Datasets(idx(k));
                pattern = opts.NamePattern;
                if pattern == ""; pattern = d.NamePattern; end
                id = EphysDataset.nameIdentity(d.Name, pattern);
                Key(k) = obj.datasetKey(idx(k));
                Name(k) = d.Name;
                Subject(k) = id.subject;
                RecordingStart(k) = id.recordingStart;
                LabelSuffix(k) = id.labelSuffix;
                Status(k) = "ok";
                if ~id.ok; Status(k) = id.reason; end
                Message(k) = id.message;
            end
            okRows = find(Status == "ok");
            if isempty(okRows); okRows = zeros(0, 1); end
            [~, ~, g] = unique(lower(LabelSuffix(okRows)));
            counts = accumarray(g, 1, [max([g; 0]) 1]);
            for r = okRows(counts(g) > 1).'
                others = Key(okRows(lower(LabelSuffix(okRows)) == lower(LabelSuffix(r))));
                others = others(others ~= Key(r));
                Status(r) = "collision";
                Message(r) = sprintf( ...
                    'Unit labels "..._%s" are also used by %s (same subject, recording start in the same minute).', ...
                    LabelSuffix(r), strjoin(others.', ", "));
            end
            T = table(Key, Name, Subject, RecordingStart, LabelSuffix, Status, Message);
        end

        function d = dataset(obj, idxOrName)
            %dataset  Return one dataset by index or by Name.
            arguments
                obj (1,1) EphysProject
                idxOrName
            end
            if isnumeric(idxOrName)
                d = obj.Datasets(idxOrName);
            else
                names = [obj.Datasets.Name];
                ix = find(names == string(idxOrName), 1);
                if isempty(ix)
                    error('EphysProject:NoSuchDataset', ...
                        'No dataset named "%s".', string(idxOrName));
                end
                d = obj.Datasets(ix);
            end
        end

        function dt = tracker(obj, idxOrName)
            %tracker  DatasetTracker inventory for one dataset (by index or Name).
            %   Convenience wrapper over EphysDataset.tracker so GUIs/scripts can
            %   ask the project for a dataset's *.bin / probe / kilosort4
            %   inventory in one call. See also EphysDataset.tracker, DATASETTRACKER.
            arguments
                obj (1,1) EphysProject
                idxOrName
            end
            dt = obj.dataset(idxOrName).tracker();
        end

        function n = get.NumDatasets(obj)
            n = numel(obj.Datasets);
        end
    end

    methods (Static)
        function key = relativeKey(root, folder)
            %relativeKey  FOLDER relative to ROOT as a forward-slash key.
            %   Returns "." when FOLDER is ROOT, and the absolute folder (with
            %   forward slashes) when FOLDER is not under ROOT.
            r = EphysProject.normalizeKey(root);
            f = EphysProject.normalizeKey(folder);
            if strcmpi(f, r)
                key = ".";
            elseif startsWith(f, r + "/", 'IgnoreCase', ispc)
                key = extractAfter(f, strlength(r) + 1);
            else
                key = f;
            end
        end

        function s = normalizeKey(s)
            %normalizeKey  Forward slashes, no trailing slash.
            s = string(s);
            s = replace(s, "\", "/");
            s = regexprep(s, "/+$", "");
        end

        function [folders, names] = findOutputFolders(root, recursive)
            %findOutputFolders  Folders under ROOT that hold a dataset's pipeline outputs.
            %   FOLDERS = EphysProject.findOutputFolders(ROOT, RECURSIVE) are
            %   the folders (1 x N string, in listing order) laid out as the
            %   pipeline writes <OutputRoot>/<Name>: holding a .mat, .npz or
            %   .nwb named after the folder (its name, then "_", "-", "." or
            %   a space, as DatasetOutputs finds them), its
            %   <name>_manifest.json or <name>_artifacts.json, or a sort run
            %   folder (kilosort4 or si_<sorter>) with a params.py. A version
            %   folder <name>_v<n> (OutputTransfer's IfExists "version")
            %   whose outputs are named after <name> counts too. RECURSIVE
            %   false looks only at ROOT and the folders directly in it. Only
            %   names are compared, no file is opened. discover uses this
            %   when ROOT holds no recording.
            %   [FOLDERS, NAMES] = ... also returns each folder's dataset name
            %   (outputFolderName): its own, or <name> for a version folder.
            arguments
                root (1,1) string
                recursive (1,1) logical = true
            end
            if recursive
                files = listTree(root);
            else
                files = runFiles(root);
                top = dir(root);
                top = top([top.isdir] & ~startsWith({top.name}, '.'));
                for k = 1:numel(top)
                    files = [files; runFiles(fullfile(top(k).folder, top(k).name))]; %#ok<AGROW>
                end
            end
            folders = string.empty(1, 0);
            names = string.empty(1, 0);
            if isempty(files); return; end
            name = string({files.name});
            [where, ~, g] = unique(string({files.folder}), 'stable');
            leaf = regexprep(where, '^.*[\\/]', '');
            for k = 1:numel(where)
                if leaf(k) == ""; continue; end   % a drive root
                here = name(g == k);
                if namesOutputs(EphysProject.outputFolderName(where(k), here), here)
                    folders(end+1) = where(k); %#ok<AGROW>
                end
                if (strcmpi(leaf(k), "kilosort4") || startsWith(leaf(k), "si_", 'IgnoreCase', true)) ...
                        && any(strcmpi(here, 'params.py'))
                    folders(end+1) = regexprep(where(k), '[\\/][^\\/]*$', ''); %#ok<AGROW>
                end
            end
            folders = unique(folders, 'stable');
            % A sort run folder given as ROOT names its parent: not under ROOT.
            key = EphysDataset.pathKey(folders);
            r = EphysDataset.pathKey(root);
            folders = folders(key == r | startsWith(key, r + "/"));
            names = strings(1, numel(folders));
            whereKey = EphysDataset.pathKey(where);
            for k = 1:numel(folders)
                names(k) = EphysProject.outputFolderName(folders(k), ...
                    name(ismember(g, find(whereKey == EphysDataset.pathKey(folders(k))))));
            end
        end

        function name = outputFolderName(folder, files)
            %outputFolderName  The dataset name of a folder of pipeline outputs.
            %   NAME = EphysProject.outputFolderName(FOLDER) is FOLDER's own
            %   name, except for a version folder <name>_v<n> (as
            %   OutputTransfer's IfExists "version" makes them, the
            %   dataset's outputs copied again beside an earlier copy):
            %   when no output in it is named after the folder and one is
            %   named after <name>, the dataset is <name>, so its files are
            %   found (DatasetOutputs) and its units labeled from <name>.
            %   NAME = EphysProject.outputFolderName(FOLDER, FILES) takes the
            %   names of the files directly in FOLDER instead of listing it.
            arguments
                folder (1,1) string
                files = []
            end
            [~, leaf] = fileparts(char(regexprep(folder, '[\\/]+$', '')));   % as EphysDataset names a folder
            name = string(leaf);
            base = regexp(char(name), '^(.+)_v\d+$', 'tokens', 'once');
            if isempty(base); return; end
            if isempty(files)
                L = dir(folder);
                files = string({L(~[L.isdir]).name});
            end
            files = string(files);
            if ~namesOutputs(name, files) && namesOutputs(string(base{1}), files)
                name = string(base{1});
            end
        end
    end
end


function tf = namesOutputs(name, files)
%namesOutputs  Whether any of FILES is a pipeline output of dataset NAME.
%   A .mat, .npz or .nwb named after it (NAME, then "_", "-", "." or a
%   space, as DatasetOutputs finds them), or its _manifest.json or
%   _artifacts.json.
rx = "^" + regexptranslate('escape', name) + "(([_\-. ].*)?\.(mat|npz|nwb)|_(manifest|artifacts)\.json)$";
tf = any(~cellfun('isempty', regexpi(cellstr(files), rx, 'once')));
end


function files = runFiles(folder)
%runFiles  The files directly in FOLDER and in its sort run folders (kilosort4, si_<sorter>).
L = dir(folder);
L = L(~ismember({L.name}, {'.', '..'}));
files = L(~[L.isdir]);
run = L([L.isdir] & (strcmpi({L.name}, 'kilosort4') | startsWith({L.name}, 'si_', 'IgnoreCase', true)));
for k = 1:numel(run)
    files = [files; listTree(fullfile(run(k).folder, run(k).name), false)]; %#ok<AGROW>
end
end
