classdef LabBundles
    % LabBundles  What the toolbox records for the lab database, as files: building, sealing, reading.
    %   A bundle is one record waiting in the outbox (LabOutbox) to be sent
    %   to the lab database: an event (a pipeline step that wrote files, a
    %   copied session, ...) with the files it read and the files it wrote.
    %   It is a JSON file in the format caraslabdb-bundle/1
    %   (documentation/file-formats.md):
    %
    %     format       "caraslabdb-bundle/1"
    %     bundle_id    the event's id (a uuid the toolbox minted)
    %     type         "event"
    %     captured_at  when it was captured (zoned, microseconds)
    %     captured_by  host, os_user, db_username, person_id, person_email
    %     after        bundles to send before this one
    %     digest       SHA-256 of the record's canonical JSON text; "" until
    %                  every output's SHA-256 is known (sealed)
    %     record       dataset, event, inputs, outputs
    %
    %   Everything the database stores as JSON (parameters, environment,
    %   attributes) is kept as JSON text in a string member (*_json), so it
    %   is sent exactly as captured and never decoded and encoded again.
    %   Times are text with their zone offset and microseconds (timeText).
    %
    %     b = LabBundles.event(Name=Value)     % build a bundle
    %     it = LabBundles.item(path, Role=, Kind=, ...)   % an input or output file
    %     b = LabBundles.seal(b)               % the digest, once complete
    %     txt = LabBundles.encode(b); b = LabBundles.decode(txt)
    %
    %   The other helpers: timeText (a zoned datetime as text), newId (a
    %   random uuid), snapshot (a file's size and time), sameSnapshot.
    %
    %   See also LabOutbox, LabCapture, LabHasher.

    properties (Constant)
        Format = "caraslabdb-bundle/1"
        TimeFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSxxx"
        MtimeFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSxxx"
        ItemFields = ["artifact_id" "path" "root" "rel" "bytes" "mtime" "sha256" "role" ...
            "format" "kind" "replaces" "attributes_json"]
    end

    methods (Static)
        function t = timeText(dt)
            %timeText  A zoned datetime as text with its offset and microseconds ("" for NaT).
            %   "2026-11-14T09:30:00.123456-05:00". An unzoned datetime is an
            %   error (LabBundles:Unzoned): a record sent later, or from
            %   another computer, must not depend on where it is sent from.
            arguments
                dt (1,1) datetime
            end
            if isnat(dt)
                t = "";
                return
            end
            if isempty(dt.TimeZone)
                error("LabBundles:Unzoned", "A time recorded for the lab database must carry its time zone.");
            end
            dt.Format = LabBundles.TimeFormat;
            t = string(dt);
        end

        function t = now()
            %now  This moment as timeText.
            t = LabBundles.timeText(datetime("now", "TimeZone", "local"));
        end

        function id = newId()
            %newId  A random (version 4) uuid, lowercase.
            id = string(lower(char(java.util.UUID.randomUUID().toString())));
        end

        function s = snapshot(file)
            %snapshot  FILE's size in bytes and modification time (ms, zoned text); NaN and "" when it is not there.
            s = struct("bytes", NaN, "mtime", "");
            d = dir(file);
            if ~isscalar(d) || d.isdir
                return
            end
            s.bytes = double(d.bytes);
            s.mtime = LabBundles.mtimeText(d.datenum);
        end

        function tf = sameSnapshot(a, b)
            %sameSnapshot  True when snapshots (or items) A and B have the same size and time.
            tf = isequal(double(a.bytes), double(b.bytes)) && ~isnan(double(a.bytes)) ...
                && string(a.mtime) == string(b.mtime);
        end

        function it = item(path, opts)
            %item  An input or output file of a record, snapshot taken now.
            %   IT = LabBundles.item(PATH, Role=, Kind=, Format=, ArtifactId=,
            %   Root=, Rel=, Sha256=, Replaces=, Attributes=): the fields of
            %   ItemFields. Format defaults to the extension, lowercase;
            %   attributes_json is the JSON object of Attributes (a struct)
            %   with kind set.
            arguments
                path (1,1) string
                opts.Role (1,1) string = "derived"
                opts.Kind (1,1) string = ""
                opts.Format (1,1) string = string(missing)
                opts.ArtifactId (1,1) string = ""
                opts.Root (1,1) string = ""
                opts.Rel (1,1) string = ""
                opts.Sha256 (1,1) string = ""
                opts.Replaces (1,1) string = ""
                opts.Attributes (1,1) struct = struct()
                opts.Snapshot = []
            end
            fmt = opts.Format;
            if ismissing(fmt)
                [~, ~, ext] = fileparts(path);
                fmt = lower(erase(string(ext), "."));
            end
            snap = opts.Snapshot;
            if isempty(snap); snap = LabBundles.snapshot(path); end
            a = struct("kind", opts.Kind);
            for f = string(fieldnames(opts.Attributes)).'
                a.(f) = opts.Attributes.(f);
            end
            it = struct("artifact_id", opts.ArtifactId, "path", path, "root", opts.Root, ...
                "rel", opts.Rel, "bytes", snap.bytes, "mtime", string(snap.mtime), ...
                "sha256", opts.Sha256, "role", opts.Role, "format", fmt, "kind", opts.Kind, ...
                "replaces", opts.Replaces, "attributes_json", string(jsonencode(a)));
        end

        function items = toItems(in)
            %toItems  IN (a struct array, a cell of structs, [] or a decoded JSON list) as a row of items with every field.
            items = LabBundles.items(in);
        end

        function items = noItems()
            %noItems  An empty list of items, with every field.
            c = cell(1, 2 * numel(LabBundles.ItemFields));
            c(1:2:end) = cellstr(LabBundles.ItemFields);
            c(2:2:end) = {{}};
            items = struct(c{:});
        end

        function b = event(opts)
            %event  A bundle for one event (see the class help for the members).
            %   B = LabBundles.event(EventId=, EventType=, OccurredAt=,
            %   Detail=, Attributes=, Notes=, Performer=, Dataset=, Inputs=,
            %   Outputs=, CapturedAt=, CapturedBy=, After=). EventType is
            %   "analysis", "recording" or "behavior"; OccurredAt text from
            %   timeText; Detail a struct of the type's detail columns
            %   (parameters and environment as parameters_json /
            %   environment_json text); Attributes a struct.
            arguments
                opts.EventId (1,1) string
                opts.EventType (1,1) string {mustBeMember(opts.EventType, ["analysis" "recording" "behavior"])}
                opts.OccurredAt (1,1) string
                opts.Detail (1,1) struct = struct()
                opts.Attributes (1,1) struct = struct()
                opts.Notes (1,1) string = ""
                opts.Performer (1,1) struct = struct("person_id", "", "person_email", "")
                opts.Dataset (1,1) struct = LabBundles.noDataset()
                opts.Inputs struct = LabBundles.noItems()
                opts.Outputs struct = LabBundles.noItems()
                opts.CapturedAt (1,1) string = ""
                opts.CapturedBy (1,1) struct = LabBundles.capturedBy()
                opts.After (1,:) string = string.empty(1, 0)
            end
            if opts.CapturedAt == ""; opts.CapturedAt = LabBundles.now(); end
            ev = struct("event_id", opts.EventId, "event_type", opts.EventType, ...
                "occurred_at", opts.OccurredAt, "notes", opts.Notes, ...
                "performer", struct("person_id", string(opts.Performer.person_id), ...
                "person_email", string(opts.Performer.person_email)), ...
                "attributes_json", string(jsonencode(opts.Attributes)), "detail", opts.Detail);
            rec = struct("dataset", opts.Dataset, "event", ev, ...
                "inputs", LabBundles.items(opts.Inputs), "outputs", LabBundles.items(opts.Outputs));
            b = struct("format", LabBundles.Format, "bundle_id", opts.EventId, "type", "event", ...
                "captured_at", opts.CapturedAt, "captured_by", opts.CapturedBy, ...
                "after", opts.After, "digest", "", "record", rec);
        end

        function d = noDataset()
            %noDataset  The dataset block of a record about no dataset.
            d = struct("name", "", "folder", "", "session_id", "", "subject_folder_id", "", ...
                "recording_start", "");
        end

        function c = capturedBy(s)
            %capturedBy  Who and where a bundle is captured: host, os_user and the database login and person set up here.
            if nargin < 1; s = LabDBSettings.load(); end
            c = struct("host", LabBundles.host(), "os_user", LabBundles.osUser(), ...
                "db_username", s.Username, "person_id", s.PersonId, "person_email", s.PersonEmail);
        end

        function h = host()
            %host  This computer's name.
            h = string(getenv('COMPUTERNAME'));
            if h == ""; h = string(getenv('HOSTNAME')); end
            if h == ""
                [st, out] = system('hostname');
                if st == 0; h = strtrim(string(out)); end
            end
        end

        function u = osUser()
            %osUser  The operating-system user running MATLAB.
            u = string(getenv('USERNAME'));
            if u == ""; u = string(getenv('USER')); end
        end

        function n = missingHashes(b)
            %missingHashes  How many outputs of B have no SHA-256 yet.
            o = b.record.outputs;
            n = 0;
            for k = 1:numel(o)
                if strlength(string(o(k).sha256)) ~= 64; n = n + 1; end
            end
        end

        function b = seal(b)
            %seal  Set B's digest when every output's SHA-256 is known (else leave it "").
            if LabBundles.missingHashes(b) > 0
                b.digest = "";
                return
            end
            b.digest = fileSha256(LabBundles.encodeRecord(b.record), Text=true);
        end

        function tf = isSealed(b)
            %isSealed  True when B carries its digest.
            tf = strlength(string(b.digest)) == 64;
        end

        function txt = encode(b)
            %encode  B as the canonical JSON text written to its file.
            e = b;
            e.after = cellstr(string(b.after));
            e.record = LabBundles.canonicalRecord(b.record);
            txt = string(jsonencode(e));
        end

        function b = decode(txt)
            %decode  A bundle from its JSON text, every list as a struct array with every field.
            %   LabBundles:Format when TXT is not a caraslabdb-bundle/1 bundle.
            try
                b = jsondecode(char(txt));
            catch ME
                error("LabBundles:Format", "Not a bundle: %s", ME.message);
            end
            if ~isstruct(b) || ~isfield(b, "format") || string(b.format) ~= LabBundles.Format ...
                    || ~isfield(b, "record") || ~isfield(b, "bundle_id")
                error("LabBundles:Format", "Not a %s bundle.", LabBundles.Format);
            end
            b.format = string(b.format);
            b.bundle_id = string(b.bundle_id);
            b.type = string(b.type);
            b.captured_at = string(b.captured_at);
            b.digest = string(b.digest);
            b.after = reshape(string(b.after), 1, []);
            if isempty(b.after); b.after = string.empty(1, 0); end
            b.captured_by = LabBundles.strings(b.captured_by);
            r = b.record;
            r.dataset = LabBundles.strings(r.dataset);
            ev = r.event;
            for f = ["event_id" "event_type" "occurred_at" "notes" "attributes_json"]
                ev.(f) = string(ev.(f));
            end
            ev.performer = LabBundles.strings(ev.performer);
            if isempty(ev.detail); ev.detail = struct(); end
            for f = string(fieldnames(ev.detail)).'
                v = ev.detail.(f);
                if ischar(v) || iscellstr(v); ev.detail.(f) = string(v); end
            end
            r.event = ev;
            r.inputs = LabBundles.items(r.inputs);
            r.outputs = LabBundles.items(r.outputs);
            b.record = r;
        end

        function txt = encodeRecord(rec)
            %encodeRecord  The canonical JSON text of a record (what the digest is taken of).
            txt = string(jsonencode(LabBundles.canonicalRecord(rec)));
        end
    end

    methods (Static, Access = private)
        function t = mtimeText(dn)
            %mtimeText  A dir() datenum as zoned text to the millisecond.
            dt = datetime(dn, "ConvertFrom", "datenum", "TimeZone", "local");
            dt.Format = LabBundles.MtimeFormat;
            t = string(dt);
        end

        function items = items(in)
            %items  IN (a struct array, a cell of structs, [] or a decoded list) as a struct row with every item field.
            items = LabBundles.noItems();
            if isempty(in); return; end
            if isstruct(in); in = num2cell(in); end
            for k = 1:numel(in)
                x = in{k};
                it = struct();
                for f = LabBundles.ItemFields
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

        function s = strings(s)
            %strings  Every char member of the scalar struct S as a string.
            if isempty(s); s = struct(); return; end
            for f = string(fieldnames(s)).'
                v = s.(f);
                if ischar(v) || (isnumeric(v) && isempty(v)); s.(f) = string(v); end
                if isempty(s.(f)) && isstring(s.(f)); s.(f) = ""; end
            end
        end

        function r = canonicalRecord(rec)
            %canonicalRecord  REC with its lists as cells, so a list of one is still a JSON list.
            r = rec;
            r.inputs = LabBundles.itemCells(rec.inputs);
            r.outputs = LabBundles.itemCells(rec.outputs);
        end

        function c = itemCells(items)
            items = LabBundles.items(items);
            c = cell(1, numel(items));
            for k = 1:numel(items)
                c{k} = items(k);   % a size not known (NaN) is written null
            end
        end
    end
end
