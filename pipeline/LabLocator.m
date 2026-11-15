classdef LabLocator
    % LabLocator  Find recordings through the lab database, and where they are on this computer.
    %   T = LabLocator.sessions(Subject=, Project=, From=, To=, Tags=)
    %   asks the database for its sessions and gives one row each:
    %
    %     session_id, subject_id, label, started_at
    %     root, rel     the session folder's storage root and path below it
    %     folder        that folder on this computer ("" when its root is not
    %                   mapped here, LabRoots)
    %     reachable     the folder is there now (folderReachable)
    %     outputs       the folders here that hold the session's outputs:
    %                   for each of its files the database knows are present
    %                   (not replaced, moved or deleted), raw files left
    %                   out, the dataset output folder it is in, wherever it
    %                   was copied or moved to. A file's row names its place
    %                   in that folder (attributes.dataset_rel, written for
    %                   a step's outputs and for their copies by the
    %                   pipeline's output transfer); a file without one (a
    %                   .bin in its own BinDir, a file a clean up moved) adds
    %                   no folder
    %
    %   The database never decides which file an analysis reads: these are
    %   places to look. Each answer is kept on this computer; while the
    %   database does not answer, sessions gives the last one, with
    %   [T, asOf, note] saying when it was made.
    %
    %     [T, asOf, note] = LabLocator.sessions(...)
    %     F = LabLocator.outputFolders(T)    % every row's outputs, unique
    %     [root, depth] = LabLocator.commonFolder(F)   % the folder that holds them
    %
    %   See also LabLocatorDialog, LabRoots, LabDB.

    methods (Static)
        function [T, asOf, note] = sessions(opts)
            %sessions  The database's sessions that match, with where they are here (the last answer while offline).
            arguments
                opts.Subject (1,1) string = ""
                opts.Project (1,1) string = ""
                opts.From (1,1) datetime = NaT
                opts.To (1,1) datetime = NaT
                opts.Tags (1,:) string = strings(1, 0)
            end
            asOf = NaT("TimeZone", "local");
            note = "";
            b = LabDB.connect(MaxWait=2);
            if isempty(b)
                [T, asOf] = LabLocator.cached();
                note = "The lab database does not answer: " + LabDB.status().Message;
                if ~isnat(asOf)
                    note = note + " Shown: the last answer, of " + string(asOf, "yyyy-MM-dd HH:mm") + ...
                        " (its filters may differ).";
                end
                return
            end
            s = LabDBSettings.load();
            f = struct();
            if opts.Subject ~= ""; f.SubjectId = opts.Subject; end
            if ~isempty(opts.Tags); f.Tags = opts.Tags; end
            S = b.sessions(f);
            if opts.Project ~= "" && height(S) > 0
                subj = b.subjects(struct("ProjectId", opts.Project));
                S = S(ismember(string(S.subject_id), string(subj.subject_id)), :);
            end
            if height(S) > 0 && any(strcmp(S.Properties.VariableNames, "started_at")) && isdatetime(S.started_at)
                t = S.started_at;
                if isempty(t.TimeZone); t.TimeZone = "local"; end   % CarasLabDB gives the workstation's time
                keep = true(height(S), 1);
                if ~isnat(opts.From); keep = keep & ~isnat(t) & t >= LabLocator.zoned(opts.From); end
                if ~isnat(opts.To); keep = keep & ~isnat(t) & t < LabLocator.zoned(opts.To) + days(1); end
                S = S(keep, :);
            end
            roots = b.storageRoots();
            T = LabLocator.empty();
            for k = 1:height(S)
                rootName = LabLocator.rootName(roots, S.storage_root_id(k));
                rel = string(S.relative_path(k));
                folder = "";
                if rootName ~= ""; folder = LabRoots.resolve(rootName, rel, s); end
                started = NaT("TimeZone", "local");
                if any(strcmp(S.Properties.VariableNames, "started_at")) && isdatetime(S.started_at) ...
                        && ~isnat(S.started_at(k))
                    started = S.started_at(k);
                    started.TimeZone = "local";   % unzoned: read as this computer's time; zoned: converted
                end
                A = b.artifacts(struct("SessionId", string(S.session_id(k)), "PresentOnly", true));
                outs = strings(1, 0);
                for j = 1:height(A)
                    if string(A.role(j)) == "raw"; continue; end
                    rn = LabLocator.rootName(roots, A.storage_root_id(j));
                    if rn == ""; continue; end
                    p = LabRoots.resolve(rn, string(A.relative_path(j)), s);
                    if p == ""; continue; end
                    of = LabLocator.datasetFolder(p, LabLocator.attribute(A, j, "dataset_rel"));
                    if of ~= ""; outs(end + 1) = of; end %#ok<AGROW>
                end
                outs = unique(outs, "stable");
                outs = outs(arrayfun(@(x) isfolder(x), outs));
                reach = folder ~= "" && folderReachable(folder, 1);   % a share that does not answer costs 1 s
                T = [T; table(string(S.session_id(k)), string(S.subject_id(k)), string(S.label(k)), started, ...
                    string(rootName), rel, folder, reach, {outs}, 'VariableNames', T.Properties.VariableNames)]; %#ok<AGROW>
            end
            asOf = datetime("now", "TimeZone", "local");
            LabLocator.keep(T, asOf);
        end

        function F = outputFolders(T)
            %outputFolders  Every row's output folders, once each, in order.
            F = strings(1, 0);
            for k = 1:height(T)
                F = [F, reshape(string(T.outputs{k}), 1, [])]; %#ok<AGROW>
            end
            F = unique(F, "stable");
        end

        function [root, depth] = commonFolder(folders)
            %commonFolder  The folder that holds every one of FOLDERS ("" when none), and how deep each is below it.
            %   [ROOT, DEPTH] = LabLocator.commonFolder(FOLDERS): ROOT is their
            %   deepest common folder; a folder that is that folder itself (a
            %   lone session) makes its parent ROOT. DEPTH(k) is how many folders
            %   below ROOT FOLDERS(k) is (1: directly in it). ROOT is "" when
            %   they share no folder: only "/", or "\\server" alone, or not
            %   even a drive or share. A drive's top ("D:\") is a folder.
            %   Case is ignored on Windows.
            %   The apps' "Open from database..." make it the root they scan.
            arguments
                folders (1,:) string
            end
            folders = regexprep(strtrim(folders), '[\\/]+$', '');
            sep = ["/" "\"];
            parts = arrayfun(@(f) reshape(split(f, sep), 1, []), folders, "UniformOutput", false);
            same = @(a, b) strcmp(a, b);
            if ispc; same = @(a, b) strcmpi(a, b); end
            n = min(cellfun(@numel, parts));
            m = 0;
            while m < n && all(cellfun(@(p) same(p(m + 1), parts{1}(m + 1)), parts))
                m = m + 1;
            end
            if any(cellfun(@numel, parts) == m)   % the common folder is one of the sessions
                m = m - 1;
            end
            root = "";
            depth = cellfun(@numel, parts) - m;
            if m < 1 || all(parts{1}(1:m) == "")
                return   % nothing in common but "/" (or "\\"): no project of the whole file system
            end
            root = strjoin(parts{1}(1:m), filesep);
            if ispc && ~isempty(regexp(root, '^[A-Za-z]:$', 'once')); root = root + "\"; end   % "D:" is "D:\"
            if ispc && startsWith(root, "\\") && numel(split(extractAfter(root, 2), "\")) < 2
                root = "";   % "\\server" alone is no folder
            end
        end

        function f = datasetFolder(p, rel)
            %datasetFolder  The folder P is REL in (REL: "/" between folders): P without REL; "" when REL is "" or P does not end in it.
            f = "";
            rel = strip(string(rel), "both", "/");
            if rel == "" || ismissing(rel); return; end
            n = numel(split(rel, "/"));
            f = string(p);
            for k = 1:n
                f = string(fileparts(f));
            end
            if EphysDataset.pathKey(fullfile(f, rel)) ~= EphysDataset.pathKey(p); f = ""; end
        end

        function T = empty()
            %empty  A table of no sessions, with every column.
            T = table(strings(0, 1), strings(0, 1), strings(0, 1), NaT(0, 1, "TimeZone", "local"), ...
                strings(0, 1), strings(0, 1), strings(0, 1), false(0, 1), cell(0, 1), ...
                'VariableNames', {'session_id', 'subject_id', 'label', 'started_at', 'root', 'rel', ...
                'folder', 'reachable', 'outputs'});
        end

        function [T, asOf] = cached()
            %cached  The last answer kept on this computer, and when it was made (empty and NaT when none).
            T = LabLocator.empty();
            asOf = NaT("TimeZone", "local");
            f = LabLocator.cacheFile();
            if ~isfile(f); return; end
            x = readJsonFile(f, ErrorOnFail=false);
            if ~isstruct(x) || ~isfield(x, "sessions"); return; end
            try
                asOf = datetime(string(x.as_of), "InputFormat", LabBundles.TimeFormat, "TimeZone", "local");
            catch
            end
            rows = x.sessions;
            if isstruct(rows); rows = num2cell(rows); end
            if ~iscell(rows); return; end
            s = LabDBSettings.load();
            for k = 1:numel(rows)
                r = rows{k};
                started = NaT("TimeZone", "local");
                if strlength(string(r.started_at)) > 0
                    started = datetime(string(r.started_at), "InputFormat", LabBundles.TimeFormat, "TimeZone", "local");
                end
                folder = "";
                if string(r.root) ~= ""; folder = LabRoots.resolve(string(r.root), string(r.rel), s); end
                outs = reshape(string(r.outputs), 1, []);
                if isempty(outs); outs = strings(1, 0); end
                T = [T; table(string(r.session_id), string(r.subject_id), string(r.label), started, ...
                    string(r.root), string(r.rel), folder, folder ~= "" && isfolder(folder), {outs}, ...
                    'VariableNames', T.Properties.VariableNames)]; %#ok<AGROW>
            end
        end
    end

    methods (Static, Access = private)
        function f = cacheFile()
            d = fullfile(LabDB.folder(), "snapshot");
            if ~isfolder(d); mkdir(d); end
            f = string(fullfile(d, "sessions.json"));
        end

        function keep(T, asOf)
            %keep  The answer, for while the database does not answer (outputs as found here).
            rows = cell(1, height(T));
            for k = 1:height(T)
                rows{k} = struct("session_id", T.session_id(k), "subject_id", T.subject_id(k), ...
                    "label", T.label(k), "started_at", LabBundles.timeText(T.started_at(k)), ...
                    "root", T.root(k), "rel", T.rel(k), "outputs", {cellstr(T.outputs{k})});
            end
            try
                writeJsonFile(LabLocator.cacheFile(), struct("as_of", LabBundles.timeText(asOf), "sessions", {rows}));
            catch
                % a snapshot that cannot be written is only no snapshot
            end
        end

        function v = attribute(A, j, name)
            %attribute  Member NAME of row J's attributes (JSON text or a struct), as text ("" when it has none).
            v = "";
            if ~any(strcmp(A.Properties.VariableNames, "attributes")); return; end
            a = A.attributes(j);
            if iscell(a); a = a{1}; end
            if ~isstruct(a)
                try
                    a = jsondecode(char(string(a)));
                catch
                    return
                end
            end
            if isstruct(a) && isfield(a, name) && (ischar(a.(name)) || isstring(a.(name)))
                v = string(a.(name));
            end
        end

        function n = rootName(roots, id)
            n = "";
            k = find(double(roots.root_id) == double(id), 1);
            if ~isempty(k); n = string(roots.name(k)); end
        end

        function t = zoned(t)
            if isempty(t.TimeZone); t.TimeZone = "local"; end
        end
    end
end
