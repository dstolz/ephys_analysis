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
    %     P.runKilosortAll();            % spawn Kilosort4 for each
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
        Scale      (1,1) double = 1/0.195
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
        infos   = toBinAll(obj, opts)
        results = runKilosortAll(obj, opts)
        report  = refresh(obj, opts)

        function obj = EphysProject(root, opts)
            arguments
                root (1,1) string = ""
                opts.ProbeFile  (1,1) string = ""
                opts.PythonExe  (1,1) string = ""
                opts.CondaEnv   (1,1) string = ""
                opts.OutputRoot (1,1) string = ""
                opts.Scale      (1,1) double = 1/0.195
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
            %   several (Open Ephys recording modes).
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
            if isempty(folders)
                obj.Datasets = EphysDataset.empty(1,0);
                warning('EphysProject:NoData', ...
                    'No recordings found under %s', obj.Root);
                return
            end

            ds = EphysDataset.empty(1, 0);
            for i = 1:numel(folders)
                d = EphysDataset(folders(i), AutoMetadata=false, ReaderOptions=obj.ReaderOptions);
                obj.pushConfig(d);
                ds(end+1) = d; %#ok<AGROW>
            end
            obj.Datasets = ds;

            fprintf('Discovered %d dataset folder(s) under %s\n', numel(ds), obj.Root);
        end

        function pushConfig(obj, d)
            %pushConfig  Copy shared defaults into one EphysDataset.
            %   Also sets its NamePattern and DatasetKey (folder relative to Root),
            %   which label its sorted units.
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
            if obj.OutputRoot ~= ""
                d.OutputDir = fullfile(obj.OutputRoot, d.Name);
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
            %unitIdentities  How each dataset's sorted units are labelled.
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
    end
end
