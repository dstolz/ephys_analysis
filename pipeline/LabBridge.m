classdef LabBridge
    % LabBridge  ephys_analysis's door to the shared lab database client, the labclient package of CarasLabDB.
    %   The client lives in the CarasLabDB repository (its +labclient folder,
    %   beside @CarasLabDB), shared with the other toolboxes of the lab
    %   (EPsych): one settings struct, one vault password, one storage-root
    %   map, one outbox and one lamp per computer. This toolbox needs that
    %   checkout on the MATLAB path (documentation/database.md, Requirements):
    %   `useCarasLabDB` puts it there when it is a sibling of this checkout or
    %   CARASLABDB_DIR names it.
    %
    %   Without it the apps still work, as with the database turned off: the
    %   lamp reads "Database: attention" and says what is missing, the
    %   Database window explains it, nothing is recorded or sent, and the few
    %   helpers every step needs to stamp its record (a uuid, a time, a
    %   file's size and time) are done here. This class is the only place that
    %   knows the package may be absent:
    %
    %     LabBridge.available()          the package is on the path, in a version this toolbox can use
    %     LabBridge.lamp(grid, Row=, Column=, Parent=)   the status-bar lamp
    %     LabBridge.openWindow(Parent=)  the Database window
    %     LabBridge.start(Parent=, IfEnabled=)           the sending timer
    %     r = LabBridge.suspend()        no sending until R is cleared
    %     res = LabBridge.flush(Budget=) send what waits, for up to Budget s
    %     LabBridge.registerTool()       this toolbox's hooks with the client
    %
    %   The tool hooks (labclient.Sync.registerTool) are the toolbox's session
    %   files: readSession, copyOfSession, assignSubject of LabCapture. They
    %   are registered the first time LabCapture.enabled() is true, by the
    %   lamp, the window and a flush, so a MATLAB that captured a dataset's
    %   record is one that can send it. A MATLAB without them (EPsych's, say)
    %   leaves those records in the shared outbox for one that has them.
    %   The records this toolbox wrote before records named their tool (no
    %   dataset.tool: every record from before the client was shared) are
    %   its own too, and it says so when it registers (TakesUntagged=true);
    %   the client assumes no tool for them, so they would wait unsent.
    %
    %   See also LabCapture, useCarasLabDB, labclient.Sync, labclient.Lamp.

    properties (Constant)
        Tool = "ephys_analysis"   % the name of this toolbox's hooks, and dataset.tool of its records
        % The version of the client's interface this toolbox is written for
        % (labclient.Api.Version). It calls what version 2 added
        % (TakesUntagged); the class that says the version came with 3, so 3
        % is the least that can be asked for.
        ClientVersion = 3
    end

    methods (Static)
        function tf = available()
            %available  True when the labclient package is on the MATLAB path, in a version this toolbox can use.
            %   One look in the usual places first (useCarasLabDB). A package
            %   that is there but older than ClientVersion is not used:
            %   calling it would fail part way (recentEnough, missingMessage).
            persistent found
            if ~isempty(found) && found; tf = true; return; end
            tf = LabBridge.packageThere();
            if ~tf
                useCarasLabDB();
                tf = LabBridge.packageThere();
            end
            tf = tf && LabBridge.recentEnough();
            found = tf;
            if tf; LabBridge.migrate(); end
        end

        function tf = recentEnough(needed)
            %recentEnough  True when the labclient package on the path is version NEEDED of its interface, or later.
            %   NEEDED is ClientVersion when left out. A package from before
            %   labclient.Api has no version to ask for, and is older than any
            %   this toolbox can use.
            arguments
                needed (1,1) double = LabBridge.ClientVersion
            end
            tf = exist("labclient.Api", "class") == 8 && labclient.Api.Version >= needed;
        end

        function migrate(opts)
            %migrate  Once per MATLAB, bring this toolbox's earlier settings and outbox into the shared client's places.
            %   Before the client was shared, this toolbox kept the database
            %   settings in its app preferences (group LabDB, preference
            %   Settings) and the outbox, hash jobs and caches in
            %   %LOCALAPPDATA%\ephys_analysis\labdb. Each is taken over once:
            %     - the settings, when the client has none yet (they are
            %       copied, checked, not removed from the old place);
            %     - every file of the old folder (but what is being sent
            %       right now, outbox\claimed) that is not at the same place
            %       in the client's folder yet is MOVED there; a file already
            %       there is never overwritten (the old one stays where it was).
            %   What was done is written to migration_from_ephys_analysis.log in
            %   the client folder, whose presence says it was done: the next
            %   MATLAB does nothing. Not while tests keep the preferences or the
            %   client folder somewhere temporary. Never an error: a failure is
            %   a warning, and the next MATLAB tries again.
            arguments
                opts.Force (1,1) logical = false   % tests: do it now, whatever stores are in use
            end
            persistent tried
            if ~opts.Force
                if ~isempty(tried); return; end
                tried = true;
                if labclient.Prefs.storeFile() ~= "" || string(getenv(labclient.DB.EnvVar)) ~= ""; return; end
            end
            try
                dest = labclient.DB.folder();
                logFile = fullfile(dest, "migration_from_ephys_analysis.log");
                if isfile(logFile); return; end
                lines = strings(0, 1);
                if ~labclient.Prefs.ispref(labclient.Settings.Name) && AppPrefs.ispref("LabDB", "Settings")
                    old = AppPrefs.getpref("LabDB", "Settings");
                    labclient.Settings.save(old);
                    lines(end + 1, 1) = "settings: copied from the app preferences (group LabDB, Settings)";
                end
                base = string(getenv("LOCALAPPDATA"));
                if base == ""; base = string(tempdir); end
                src = string(getenv("EPHYS_LABDB_DIR"));
                if src == ""; src = string(fullfile(base, "ephys_analysis", "labdb")); end
                nMoved = 0; nKept = 0;
                if isfolder(src) && ~strcmpi(char(src), char(dest))
                    L = dir(fullfile(src, "**", "*"));
                    L = L(~[L.isdir]);
                    for k = 1:numel(L)
                        from = string(fullfile(L(k).folder, L(k).name));
                        rel = extractAfter(from, strlength(src) + 1);
                        if startsWith(replace(rel, "\", "/"), "outbox/claimed/"); continue; end
                        to = string(fullfile(dest, rel));
                        if isfile(to); nKept = nKept + 1; continue; end
                        if ~isfolder(fileparts(to)); mkdir(fileparts(to)); end
                        [ok, ~] = movefile(from, to);
                        if ok; nMoved = nMoved + 1; end
                    end
                    lines(end + 1, 1) = sprintf("files: %d moved from %s, %d left because they were at the destination already", ...
                        nMoved, src, nKept);
                end
                if isempty(lines); lines = "nothing to take over"; end
                lines = string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss")) + " " + lines;
                writelines(lines, logFile);
                if nMoved > 0
                    fprintf("ephys_analysis: %d lab database outbox/cache file(s) moved into %s (see migration_from_ephys_analysis.log).\n", ...
                        nMoved, dest);
                end
            catch ME
                warning("LabBridge:Migrate", "The earlier lab database settings and outbox were not taken over (tried again next time): %s", ...
                    ME.message);
                tried = [];
            end
        end

        function m = missingMessage()
            %missingMessage  What the lamp and the window say while the client is missing, or too old to use.
            if LabBridge.packageThere() && ~LabBridge.recentEnough()
                m = "The labclient package on the MATLAB path (the CarasLabDB repository) is older than this " + ...
                    "toolbox needs, which is version " + LabBridge.ClientVersion + " of its interface " + ...
                    "(labclient.Api): update the CarasLabDB checkout (git pull). Nothing is recorded or sent " + ...
                    "to the lab database until then; the apps work as before.";
                return
            end
            m = "The labclient package (the CarasLabDB repository) is not on the MATLAB path: add a current " + ...
                "CarasLabDB checkout to the path, or name it in the environment variable CARASLABDB_DIR. " + ...
                "Nothing is recorded or sent to the lab database until then; the apps work as before.";
        end

        function registerTool()
            %registerTool  Give the client this toolbox's session-file hooks (once per MATLAB).
            %   TakesUntagged: a dataset record that names no tool was written
            %   by this toolbox, before its records said so (dataset.tool), and
            %   the outbox taken over from then holds such records. The client
            %   sends them only through the tool that says they are its own.
            if ~LabBridge.available() || labclient.Sync.hasTool(LabBridge.Tool); return; end
            labclient.Sync.registerTool(LabBridge.Tool, struct( ...
                "readSession", @(folder, name) LabCapture.readSession(folder, name), ...
                "copyOfSession", @(folder, name, sessionId, kind, eventId) ...
                    LabCapture.copyOfSession(folder, name, sessionId, kind, eventId), ...
                "assignSubject", @(folder, name, subjectId) LabCapture.assignSubject(folder, name, subjectId)), ...
                TakesUntagged=true);
        end

        function s = offSettings()
            %offSettings  The settings of a computer with the database off, for use while the package is missing.
            s = struct("Enabled", false, "Server", "", "Port", 5432, "DatabaseName", "lab", "Username", "", ...
                "PersonEmail", "", "PersonId", "", "LabTimeZone", string(datetime("now", "TimeZone", "local").TimeZone), ...
                "ConnectTimeout", 5, "StatementTimeout", 30, "Roots", struct("Name", {}, "Path", {}), ...
                "HashInProcessMB", 256);
        end

        function lamp(grid, opts)
            %lamp  The Database lamp in cell (Row, Column) of GRID: labclient.Lamp, or an "attention" one while the client is missing.
            arguments
                grid
                opts.Row (1,1) double = 1
                opts.Column (1,1) double = 1
                opts.Parent = []
            end
            if LabBridge.available()
                LabBridge.registerTool();
                labclient.Lamp(grid, Row=opts.Row, Column=opts.Column, Parent=opts.Parent);
                return
            end
            b = uibutton(grid, "Text", "Database: attention", "FontSize", 11, "Tag", "LabClientLamp", ...
                "FontColor", [0.75 0.10 0.10], "Tooltip", char(LabBridge.missingMessage()), ...
                "ButtonPushedFcn", @(~, ~) LabBridge.openWindow(Parent=opts.Parent));
            b.Layout.Row = opts.Row;
            b.Layout.Column = opts.Column;
        end

        function openWindow(opts)
            %openWindow  The Database window (labclient.Panel), or the reason there is none while the client is missing.
            arguments
                opts.Parent = []
            end
            if LabBridge.available()
                LabBridge.registerTool();
                if isempty(opts.Parent) || ~isvalid(opts.Parent)
                    labclient.Panel.open();
                else
                    labclient.Panel.open(Parent=opts.Parent);
                end
                return
            end
            if ~isempty(opts.Parent) && isvalid(opts.Parent)
                AppDialog.alert(opts.Parent, LabBridge.missingMessage(), "Lab database", "Icon", "warning");
            else
                warning("LabBridge:Missing", "%s", LabBridge.missingMessage());
            end
        end

        function start(opts)
            %start  The sending timer of this MATLAB (labclient.Sync.start); nothing while the client is missing.
            arguments
                opts.Parent = []
                opts.IfEnabled (1,1) logical = false
            end
            if ~LabBridge.available(); return; end
            LabBridge.registerTool();
            labclient.Sync.start(Parent=opts.Parent, IfEnabled=opts.IfEnabled);
        end

        function r = suspend()
            %suspend  No sending until R is cleared (labclient.Sync.suspend); [] while the client is missing.
            r = [];
            if LabBridge.available(); r = labclient.Sync.suspend(); end
        end

        function res = flush(opts)
            %flush  labclient.Sync.flush, with this toolbox's hooks registered; the same fields while the client is missing.
            arguments
                opts.Budget (1,1) double {mustBeNonnegative} = 10
            end
            if ~LabBridge.available()
                res = struct("sent", 0, "pending", 0, "held", 0, "failed", 0, "message", LabBridge.missingMessage());
                return
            end
            LabBridge.registerTool();
            res = labclient.Sync.flush(Budget=opts.Budget);
        end

        function b = connect(opts)
            %connect  labclient.DB.connect (the open backend or []); [] while the client is missing.
            arguments
                opts.Force (1,1) logical = false
                opts.MaxWait (1,1) double {mustBePositive} = Inf
            end
            b = [];
            if LabBridge.available(); b = labclient.DB.connect(Force=opts.Force, MaxWait=opts.MaxWait); end
        end

        function m = statusMessage()
            %statusMessage  Why the database is in the state it is (labclient.DB.status().Message).
            if LabBridge.available()
                m = labclient.DB.status().Message;
            else
                m = LabBridge.missingMessage();
            end
        end

        % ---- what every step needs to stamp its record, with or without the client ----------------

        function id = newId()
            %newId  A random uuid (labclient.Bundles.newId).
            if LabBridge.available()
                id = labclient.Bundles.newId();
            else
                id = string(lower(char(java.util.UUID.randomUUID().toString())));
            end
        end

        function t = timeText(dt)
            %timeText  A zoned datetime as text with its offset and microseconds (labclient.Bundles.timeText).
            if LabBridge.available()
                t = labclient.Bundles.timeText(dt);
                return
            end
            if isnat(dt); t = ""; return; end
            if isempty(dt.TimeZone)
                error("LabBridge:Unzoned", "A time recorded for the lab database must carry its time zone.");
            end
            dt.Format = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSxxx";
            t = string(dt);
        end

        function t = now()
            %now  This moment as timeText.
            t = LabBridge.timeText(datetime("now", "TimeZone", "local"));
        end

        function u = osUser()
            u = string(getenv('USERNAME'));
            if u == ""; u = string(getenv('USER')); end
        end

        function h = host()
            h = string(getenv('COMPUTERNAME'));
            if h == ""; h = string(getenv('HOSTNAME')); end
        end

        function items = noItems()
            %noItems  An empty list of items, with every field (labclient.Bundles.noItems).
            if LabBridge.available(); items = labclient.Bundles.noItems(); return; end
            names = ["artifact_id" "path" "root" "rel" "bytes" "mtime" "sha256" "role" "format" "kind" ...
                "replaces" "attributes_json"];
            c = cell(1, 2 * numel(names));
            c(1:2:end) = cellstr(names);
            c(2:2:end) = {{}};
            items = struct(c{:});
        end

        function items = toItems(in)
            %toItems  IN (a struct array, a cell of structs, [] or a decoded JSON list) as a row of items with every field.
            if LabBridge.available(); items = labclient.Bundles.toItems(in); return; end
            items = LabBridge.noItems();
            if isempty(in); return; end
            if isstruct(in); in = num2cell(in); end
            for k = 1:numel(in)
                x = in{k};
                it = struct();
                for f = string(fieldnames(items)).'
                    if isfield(x, f); v = x.(f); else; v = []; end
                    if f == "bytes"
                        if isempty(v); v = NaN; end
                        it.(f) = double(v);
                    else
                        if isempty(v); v = ""; end
                        it.(f) = string(v);
                    end
                end
                items(1, end + 1) = it; %#ok<AGROW>
            end
        end

        function s = snapshot(file)
            %snapshot  FILE's size in bytes and modification time (ms, zoned text); NaN and "" when it is not there.
            if LabBridge.available(); s = labclient.Bundles.snapshot(file); return; end
            s = struct("bytes", NaN, "mtime", "");
            d = dir(file);
            if ~isscalar(d) || d.isdir; return; end
            s.bytes = double(d.bytes);
            dt = datetime(d.datenum, "ConvertFrom", "datenum", "TimeZone", "local");
            dt.Format = "yyyy-MM-dd'T'HH:mm:ss.SSSxxx";
            s.mtime = string(dt);
        end

        function tf = sameSnapshot(a, b)
            %sameSnapshot  True when snapshots (or items) A and B have the same size and time.
            tf = isequal(double(a.bytes), double(b.bytes)) && ~isnan(double(a.bytes)) ...
                && string(a.mtime) == string(b.mtime);
        end

        function it = item(path, opts)
            %item  An input or output file of a record, snapshot taken now (labclient.Bundles.item).
            arguments
                path (1,1) string
                opts.Role (1,1) string = "derived"
                opts.Kind (1,1) string = ""
                opts.Attributes (1,1) struct = struct()
                opts.Snapshot = []
                opts.Sha256 (1,1) string = ""
                opts.ArtifactId (1,1) string = ""
            end
            if LabBridge.available()
                it = labclient.Bundles.item(path, Role=opts.Role, Kind=opts.Kind, Attributes=opts.Attributes, ...
                    Snapshot=opts.Snapshot, ArtifactId=opts.ArtifactId, Sha256=opts.Sha256);
                return
            end
            [~, ~, ext] = fileparts(path);
            snap = opts.Snapshot;
            if isempty(snap); snap = LabBridge.snapshot(path); end
            a = struct("kind", opts.Kind);
            for f = string(fieldnames(opts.Attributes)).'
                a.(f) = opts.Attributes.(f);
            end
            it = struct("artifact_id", opts.ArtifactId, "path", path, "root", "", "rel", "", "bytes", snap.bytes, ...
                "mtime", string(snap.mtime), "sha256", opts.Sha256, "role", opts.Role, "format", lower(erase(string(ext), ".")), ...
                "kind", opts.Kind, "replaces", "", "attributes_json", string(jsonencode(a)));
        end

        function h = sha256(file)
            %sha256  The SHA-256 of FILE as 64 lowercase hex digits (labclient.fileSha256, which needs the package).
            if LabBridge.available(); h = labclient.fileSha256(file); return; end
            md = java.security.MessageDigest.getInstance('SHA-256');
            fid = fopen(file, 'r');
            if fid < 0; error("LabBridge:CannotRead", "Cannot open %s to hash it.", file); end
            closer = onCleanup(@() fclose(fid));
            while true
                b = fread(fid, 64 * 2^20, '*uint8');
                if isempty(b); break; end
                md.update(typecast(b, 'int8'));
            end
            h = string(lower(reshape(dec2hex(typecast(md.digest(), 'uint8'), 2).', 1, [])));
        end
    end

    methods (Static, Access = private)
        function tf = packageThere()
            tf = exist("labclient.DB", "class") == 8;
        end
    end
end
