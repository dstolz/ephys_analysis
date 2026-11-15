classdef LabSync
    % LabSync  Send what waits in the outbox to the lab database, one record at a time, never in the way.
    %   The apps start one timer per MATLAB (start): every few seconds it
    %   finishes the hashes still needed (LabHasher), gives back the claims
    %   of a MATLAB that stopped, and, when the database answers within 2 s,
    %   sends one record (LabOutbox, oldest first, a record after those it
    %   names in "after"). While a pipeline run or an analysis run is going
    %   (suspend), it waits. flush sends as many as a time budget allows: a
    %   script calls it, and so do the end of EphysPipeline.run and the
    %   scheduled copy.
    %
    %   Sending a record (sendBundle):
    %     - the dataset's session is found by the id its session file holds,
    %       or created: in the folder's storage root, for the subject the
    %       session file names (SubjectAssignDialog) or else the one the
    %       folder's name gives. A subject that is not in the database holds
    %       the record until a person creates it or assigns the session to
    %       another (the folder is never renamed);
    %     - the person who did the work is named: the record's performer,
    %       found by id or email; else, for a record captured under this
    %       computer's login, the person the connection is. A record captured
    %       under another login is held until a person chooses "Send as me"
    %       in the Database window (the database stamps the real login);
    %     - every input whose file the database has is an edge; one it does
    %       not have yet is sent later as an "edges" record; one this
    %       computer cannot name is listed in attributes.unresolved_inputs,
    %       never guessed from its path;
    %     - CarasLabDB.recordEvent writes it once, in one transaction: sent
    %       again, it is "existing".
    %   A connection that breaks or times out puts the record back to wait
    %   (LabDB.lost); the same id with other content is held (a conflict);
    %   anything else the database refuses fails, with its reason. Nothing
    %   is renamed, dropped or merged.
    %
    %     LabSync.start(Parent=fig)     % the timer (once per MATLAB)
    %     r = LabSync.useManual()       % tests: no timer until R is cleared
    %     r = LabSync.suspend()         % no sending until R is cleared
    %     res = LabSync.flush(Budget=10)
    %     res = LabSync.sendNext(backend)
    %     T = LabSync.subjectHolds()    % the records waiting for a subject
    %     LabSync.release(folderId, subjectId, datasets)
    %
    %   See also LabOutbox, LabCapture, LabDB, SubjectAssignDialog, LabDBPanel.

    properties (Constant)
        Period = 15          % seconds between ticks
        TickWait = 2         % seconds a tick waits for the server at most
        EdgesRetry = 600     % seconds an edges record waiting for its files steps aside (unless a record was sent since)
        NeedsSubject = "needs_subject"
        NeedsLogin = "needs_login"       % captured under another login: a person must say "send as me"
        OnBehalf = "on_behalf"
        Transient = ["CarasLabDB:transactionInterrupted" "CarasLabDB:connectionFailed"]
    end

    methods (Static)
        function start(opts)
            %start  The drain timer of this MATLAB (started once); PARENT is the app that may show the subject dialog.
            %   IfEnabled=true starts it only when the database is turned on
            %   here (the apps; the Database window starts it when it is).
            arguments
                opts.Parent = []
                opts.IfEnabled (1,1) logical = false
            end
            if opts.IfEnabled && ~LabCapture.enabled(); return; end
            st = LabSync.state();
            if st.Manual; return; end   % useManual: the tests send by hand
            if ~isempty(opts.Parent); st.Parent = opts.Parent; end
            if ~isempty(st.Timer) && isvalid(st.Timer)
                LabSync.state(st);
                return
            end
            t = timer("Name", "LabSync", "Period", LabSync.Period, "StartDelay", 5, ...
                "ExecutionMode", "fixedSpacing", "BusyMode", "drop", ...
                "TimerFcn", @(~, ~) LabSync.tick());
            st.Timer = t;
            LabSync.state(st);
            start(t);
        end

        function stop()
            %stop  Stop the drain timer.
            st = LabSync.state();
            if ~isempty(st.Timer) && isvalid(st.Timer)
                stop(st.Timer);
                delete(st.Timer);
            end
            st.Timer = [];
            LabSync.state(st);
        end

        function r = useManual()
            %useManual  No timer until R is cleared (tests: they call tick, flush and sendNext themselves).
            LabSync.stop();
            st = LabSync.state();
            st.Manual = true;
            st.Offered = strings(1, 0);
            st.LastSent = NaT("TimeZone", "local");
            LabSync.state(st);
            r = onCleanup(@() LabSync.endManual());
        end

        function r = suspend()
            %suspend  No sending until R is cleared (a pipeline or analysis run is going).
            st = LabSync.state();
            st.Suspended = st.Suspended + 1;
            LabSync.state(st);
            r = onCleanup(@() LabSync.resume());
        end

        function tf = suspended()
            st = LabSync.state();
            tf = st.Suspended > 0;
        end

        function tick()
            %tick  One pass of the timer: hashes, stale claims, and one record sent when the server answers.
            try
                if ~LabCapture.enabled() || LabSync.suspended(); return; end
                LabOutbox.recoverStale();
                sealed = LabHasher.work(Budget=1);
                if isempty(LabSync.nextIds())
                    if sealed > 0; LabDB.outboxChanged(); end
                    return
                end
                b = LabDB.connect(MaxWait=LabSync.TickWait);
                if isempty(b); return; end
                LabSync.sendNext(b);
                LabSync.offerSubjects();
            catch ME
                st = LabSync.state();
                if ~st.Warned
                    warning("LabSync:Tick", "Sending to the lab database stopped for now: %s", ME.message);
                    st.Warned = true;
                    LabSync.state(st);
                end
            end
        end

        function res = flush(opts)
            %flush  Send what can be sent within Budget seconds; RES counts sent, waiting, held, failed.
            arguments
                opts.Budget (1,1) double {mustBeNonnegative} = 10
            end
            res = struct("sent", 0, "pending", 0, "held", 0, "failed", 0, "message", "");
            if ~LabCapture.enabled()
                res.message = "The lab database is turned off on this computer.";
                return
            end
            t0 = tic;
            LabOutbox.recoverStale();
            LabHasher.work(Budget=max(0, opts.Budget / 2));
            if ~isempty(LabSync.nextIds())
                b = LabDB.connect(MaxWait=max(2, min(5, opts.Budget)));
                if isempty(b)
                    res.message = LabDB.status().Message;
                else
                    while toc(t0) < opts.Budget
                        r = LabSync.sendNext(b);
                        if r.outcome == "none"; break; end
                        if r.outcome == "done"; res.sent = res.sent + 1; end
                        if r.outcome == "pending"; break; end   % the server stopped answering
                    end   % ("waiting": an edges record whose files are not there yet steps aside)
                end
            end
            c = LabOutbox.counts();
            res.pending = c.pending + c.claimed;
            res.held = c.held;
            res.failed = c.failed;
            LabDB.outboxChanged();
        end

        function r = sendNext(b)
            %sendNext  Claim and send the next record that may go; R.outcome "none" when nothing may.
            r = struct("id", "", "outcome", "none", "reason", "");
            for id = LabSync.nextIds()
                claim = LabOutbox.claim(id);
                if isempty(claim); continue; end   % another MATLAB took it
                r = LabSync.sendClaimed(b, claim);
                LabDB.outboxChanged();
                return
            end
        end

        function T = subjectHolds()
            %subjectHolds  The records held for a subject: folder_id, name, folder, bundle_id (a row each).
            T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
                'VariableNames', {'folder_id', 'name', 'folder', 'bundle_id'});
            H = LabOutbox.list(State="held");
            for k = 1:height(H)
                n = LabOutbox.note(H.id(k), "held");
                if ~any(n.flags == LabSync.NeedsSubject); continue; end
                b = LabOutbox.read(H.id(k));
                if isempty(b) || b.type ~= "event"; continue; end
                d = b.record.dataset;
                T = [T; table(d.subject_folder_id, d.name, d.folder, b.bundle_id, ...
                    'VariableNames', T.Properties.VariableNames)]; %#ok<AGROW>
            end
        end

        function [t, c] = datasetText(P)
            %datasetText  Where the records of processing block P stand: "4 sent, 1 to send, 1 needs you".
            %   C counts sent, waiting, need (held or failed), discarded and
            %   elsewhere (no record in this computer's outbox: captured
            %   while the database was off, or on another computer). "" when
            %   no record has an event id.
            c = struct("sent", 0, "waiting", 0, "need", 0, "discarded", 0, "elsewhere", 0);
            t = "";
            if ~isstruct(P) || ~isscalar(P); return; end
            any_ = false;
            for k = string(fieldnames(P)).'
                r = P.(k);
                if ~isstruct(r) || ~isscalar(r) || ~isfield(r, "event_id"); continue; end
                any_ = true;
                switch LabOutbox.stateOf(string(r.event_id))
                    case "done";                  c.sent = c.sent + 1;
                    case {"pending", "claimed"};  c.waiting = c.waiting + 1;
                    case {"held", "failed"};      c.need = c.need + 1;
                    case "discarded";             c.discarded = c.discarded + 1;
                    otherwise;                    c.elsewhere = c.elsewhere + 1;
                end
            end
            if ~any_; return; end
            parts = strings(1, 0);
            if c.sent > 0; parts(end + 1) = c.sent + " sent"; end
            if c.waiting > 0; parts(end + 1) = c.waiting + " to send"; end
            if c.need > 0; parts(end + 1) = c.need + LabSync.plural(c.need, " needs you", " need you"); end
            if c.discarded > 0; parts(end + 1) = c.discarded + " discarded"; end
            if c.elsewhere > 0; parts(end + 1) = c.elsewhere + " not recorded here"; end
            t = strjoin(parts, ", ");
        end

        function release(folderId, subjectId, datasets)
            %release  Note SUBJECTID in the session files of DATASETS (table: name, folder) and send their held records again.
            %   FOLDERID is the subject id the folders' names give; the
            %   records held for it whose datasets are among DATASETS go
            %   back to wait.
            for k = 1:height(datasets)
                LabCapture.assignSubject(datasets.folder(k), datasets.name(k), subjectId);
            end
            T = LabSync.subjectHolds();
            keep = T.folder_id == string(folderId) & ...
                ismember(EphysDataset.pathKey(T.folder), EphysDataset.pathKey(string(datasets.folder)));
            for id = reshape(T.bundle_id(keep), 1, [])
                LabOutbox.move(id, "pending", Reason="subject " + subjectId + " assigned");
            end
            LabDB.outboxChanged();
        end

        function r = sendClaimed(be, claim)
            %sendClaimed  Send the claimed record CLAIM through backend BE and end the claim.
            r = struct("id", claim.id, "outcome", "", "reason", "");
            note = LabOutbox.note(claim.id, "claimed");
            % What a person decided (send as me) stays; what the last try
            % found missing is found again by the next.
            keep = reshape(setdiff(note.flags, [LabSync.NeedsSubject, LabSync.NeedsLogin], "stable"), 1, []);
            flags = strings(1, 0);
            try
                b = LabOutbox.read(claim.id);
                if b.type == "edges"
                    [state, reason] = LabSync.sendEdges(be, b);
                else
                    [state, reason, flags] = LabSync.sendEvent(be, b, note);
                end
            catch ME
                [state, reason] = LabSync.classify(ME);
                if state == "pending"; LabDB.lost(ME.message); end
            end
            LabOutbox.finish(claim, state, Reason=reason, ...
                Flags=reshape(unique([keep, reshape(string(flags), 1, [])], "stable"), 1, []));
            r.outcome = state;
            if state == "pending" && startsWith(reason, "waiting")
                r.outcome = "waiting";
            end
            if state == "done"
                st = LabSync.state();
                st.LastSent = datetime("now", "TimeZone", "local");
                LabSync.state(st);
            end
            r.reason = reason;
        end
    end

    methods (Static, Access = private)
        function st = state(new)
            persistent s
            if isempty(s)
                s = struct("Timer", [], "Parent", [], "Suspended", 0, "Warned", false, ...
                    "Offered", strings(1, 0), "Manual", false, ...
                    "LastSent", NaT("TimeZone", "local"));
            end
            if nargin > 0; s = new; end
            st = s;
        end

        function endManual()
            st = LabSync.state();
            st.Manual = false;
            st.Parent = [];
            st.Suspended = 0;
            LabSync.state(st);
        end

        function t = plural(n, one, many)
            if n == 1; t = one; else; t = many; end
        end

        function resume()
            st = LabSync.state();
            st.Suspended = max(0, st.Suspended - 1);
            LabSync.state(st);
        end

        function ids = nextIds()
            %nextIds  The sealed pending records that may go now, oldest first.
            T = LabOutbox.list(State="pending");
            T = T(T.sealed, :);
            ids = strings(1, 0);
            if isempty(T); return; end
            waiting = LabOutbox.list();
            waiting = waiting.id(waiting.state ~= "done" & waiting.state ~= "discarded");
            st = LabSync.state();
            nowT = datetime("now", "TimeZone", "local");
            for k = 1:height(T)
                b = LabOutbox.read(T.id(k));
                if isempty(b); continue; end
                if any(ismember(b.after, waiting)); continue; end   % after a record still to be sent
                if b.type == "edges" && startsWith(T.note(k), "waiting")
                    % its files were not there: tried again once something
                    % was sent since, or after EdgesRetry
                    n = LabOutbox.note(T.id(k), "pending");
                    at = NaT("TimeZone", "local");
                    try
                        at = datetime(n.at, "InputFormat", LabBundles.TimeFormat, "TimeZone", "local");
                    catch
                    end
                    sentSince = ~isnat(st.LastSent) && ~isnat(at) && st.LastSent > at;
                    if ~sentSince && ~isnat(at) && seconds(nowT - at) < LabSync.EdgesRetry; continue; end
                end
                ids(end + 1) = T.id(k); %#ok<AGROW>
            end
        end

        function [state, reason, flags] = sendEvent(be, b, note)
            %sendEvent  Send event record B; STATE done / held / failed / pending, FLAGS for a held one.
            flags = strings(1, 0);
            s = LabDBSettings.load();
            ev = b.record.event;
            by = b.captured_by.db_username;
            if by ~= "" && by ~= s.Username && ~any(note.flags == LabSync.OnBehalf)
                state = "held";
                reason = "Captured under the login " + by + ", not " + s.Username + ...
                    ": send it as yourself from the Database window, or from " + by + "'s login.";
                flags = LabSync.NeedsLogin;
                return
            end
            roots = be.storageRoots();
            [sid, subject, why, need] = LabSync.resolveSession(be, b.record.dataset, roots, s);
            if why ~= ""
                state = "held";
                reason = why;
                if need ~= ""; flags = need; end
                return
            end
            person = LabSync.performer(be, ev.performer, by == "" || by == s.Username || ...
                any(note.flags == LabSync.OnBehalf));
            if person == ""
                state = "held";
                reason = "No lab person is named for this record, and none could be found for it.";
                return
            end
            [outs, why] = LabSync.outputs(b.record.outputs, roots, s);
            if why ~= ""
                state = "held";
                reason = why;
                return
            end
            [ins, unresolved] = LabSync.inputs(be, b.record.inputs, roots, s);
            attr = ev.attributes_json;
            if ~isempty(unresolved)
                attr = LabSync.addMember(attr, "unresolved_inputs", string(jsonencode(unresolved)));
            end
            if any(note.flags == LabSync.OnBehalf)
                attr = LabSync.addMember(attr, "sent_on_behalf_of", string(jsonencode(by)));
            end
            d = ev.detail;
            for f = ["started_at" "finished_at"]
                if isfield(d, f)
                    if string(d.(f)) == ""
                        d = rmfield(d, f);
                    else
                        d.(f) = LabSync.parseTime(d.(f));
                    end
                end
            end
            req = struct("EventType", ev.event_type, "EventId", ev.event_id, "Digest", b.digest, ...
                "OccurredAt", LabSync.parseTime(ev.occurred_at), "SubjectId", subject, "SessionId", sid, ...
                "Notes", ev.notes, "AttributesJson", attr, "RecordedBy", person, "Detail", d, ...
                "Inputs", ins, "Outputs", outs);
            out = be.recordEvent(req);
            state = "done";
            if out.Outcome == "existing"
                reason = "already in the database";
            else
                reason = "sent";
            end
            skipped = reshape(string(out.SkippedInputs), 1, []);
            if ~isempty(skipped)
                items = b.record.inputs(ismember([b.record.inputs.artifact_id], skipped));
                LabOutbox.put(LabBundles.edges(EventId=ev.event_id, Inputs=items, ...
                    CapturedBy=b.captured_by));
                reason = reason + sprintf("; %d input(s) sent later, when their files are in the database", ...
                    numel(skipped));
            end
            if ~isempty(out.SkippedReplaces)
                reason = reason + sprintf("; %d replaced file(s) not in the database, not marked replaced", ...
                    numel(out.SkippedReplaces));
            end
            if any(out.Unchanged)
                reason = reason + sprintf("; %d file(s) already registered with the same bytes", nnz(out.Unchanged));
            end
        end

        function [state, reason] = sendEdges(be, b)
            %sendEdges  Add the input edges of edges record B; what is still missing waits.
            missing = 0;
            for k = 1:numel(b.record.inputs)
                it = b.record.inputs(k);
                try
                    be.addEventInput(b.record.event_id, it.artifact_id, it.role);
                catch ME
                    if endsWith(string(ME.identifier), ":Unreachable") || ...
                            any(string(ME.identifier) == LabSync.Transient)
                        rethrow(ME);
                    end
                    missing = missing + 1;
                end
            end
            if missing == 0
                state = "done";
                reason = "sent";
            else
                state = "pending";
                reason = sprintf("waiting: %d input file(s) not in the database yet", missing);
            end
        end

        function [sid, subject, why, need] = resolveSession(be, ds, roots, s)
            %resolveSession  The record's session in the database, created when it is not there yet.
            sid = string(ds.session_id);
            subject = "";
            why = "";
            need = "";
            if string(ds.folder) == ""
                return   % a record of no dataset
            end
            if sid ~= ""
                T = be.sessions(struct("SessionId", sid));
                if height(T) > 0
                    subject = string(T.subject_id(1));
                    return
                end
            end
            [root, rel, w] = LabRoots.locate(string(ds.folder), s);
            if root == ""
                why = "The dataset folder " + ds.folder + " is not under a storage root mapped here (" + w + ...
                    "): map its root in the Database window.";
                return
            end
            rootId = roots.root_id(string(roots.name) == root);
            if isempty(rootId)
                why = "The storage root " + root + " is not in the database: register it in the Database window.";
                return
            end
            T = be.sessions(struct("StorageRootId", rootId(1), "RelativePath", rel));
            if height(T) > 0
                if sid == "" || string(T.session_id(1)) == sid
                    sid = string(T.session_id(1));
                    subject = string(T.subject_id(1));
                else
                    why = "The folder " + rel + " is session " + string(T.session_id(1)) + ...
                        " in the database, but its session file says " + sid + ".";
                end
                return
            end
            ses = LabCapture.readSession(string(ds.folder), string(ds.name));
            candidate = ses.subject_id;
            if candidate == ""; candidate = string(ds.subject_folder_id); end
            if candidate == ""
                why = "The folder name of " + ds.name + " gives no subject: assign one.";
                need = LabSync.NeedsSubject;
                return
            end
            if height(be.subjects(struct("SubjectId", candidate))) == 0
                why = "Subject " + candidate + " is not in the database: create it, or assign " + ...
                    ds.name + " to a subject that is.";
                need = LabSync.NeedsSubject;
                return
            end
            if sid == ""; sid = LabBundles.newId(); end
            a = struct("SessionId", sid, "SubjectId", candidate, "Label", string(ds.name), ...
                "StorageRootId", rootId(1), "RelativePath", rel, ...
                "StartedAt", LabSync.parseTime(ds.recording_start));
            be.addSession(a);
            subject = candidate;
        end

        function id = performer(be, p, mine)
            %performer  The lab person of performer P; the connection's person for a record of this login (MINE).
            id = string(p.person_id);
            if id ~= ""; return; end
            if string(p.person_email) ~= ""
                T = be.persons(struct("Email", string(p.person_email)));
                if height(T) == 1; id = string(T.person_id(1)); return; end
            end
            if mine
                me = be.person();
                id = string(me.PersonId);
            end
        end

        function [outs, why] = outputs(items, roots, s)
            why = "";
            outs = struct("artifact_id", {}, "storage_root_id", {}, "relative_path", {}, "checksum", {}, ...
                "size_bytes", {}, "role", {}, "format", {}, "attributes_json", {}, "replaces", {});
            for k = 1:numel(items)
                it = items(k);
                root = it.root; rel = it.rel;
                if root == ""
                    [root, rel] = LabRoots.locate(it.path, s);   % a root mapped since it was captured
                end
                if root == ""
                    why = "Output " + it.path + " is not under a storage root mapped here: map its root in the Database window.";
                    return
                end
                rid = roots.root_id(string(roots.name) == root);
                if isempty(rid)
                    why = "The storage root " + root + " is not in the database: register it in the Database window.";
                    return
                end
                outs(end + 1) = struct("artifact_id", it.artifact_id, "storage_root_id", double(rid(1)), ...
                    "relative_path", rel, "checksum", it.sha256, "size_bytes", it.bytes, "role", it.role, ...
                    "format", it.format, "attributes_json", it.attributes_json, "replaces", it.replaces); %#ok<AGROW>
            end
        end

        function [ins, unresolved] = inputs(be, items, roots, s)
            %inputs  The inputs the database can be told of, and those this computer cannot name.
            ins = struct("artifact_id", {}, "role", {});
            unresolved = struct("path", {}, "root", {}, "rel", {}, "bytes", {}, "mtime", {}, "role", {});
            for k = 1:numel(items)
                it = items(k);
                id = it.artifact_id;
                if id == "" && strlength(it.sha256) == 64
                    root = it.root; rel = it.rel;
                    if root == ""; [root, rel] = LabRoots.locate(it.path, s); end
                    rid = roots.root_id(string(roots.name) == root);
                    if ~isempty(rid)
                        T = be.artifacts(struct("StorageRootId", rid(1), "RelativePath", rel));
                        hit = string(T.checksum) == it.sha256;
                        if any(hit); id = string(T.artifact_id(find(hit, 1))); end
                    end
                end
                if id == ""
                    unresolved(end + 1) = struct("path", it.path, "root", it.root, "rel", it.rel, ...
                        "bytes", it.bytes, "mtime", it.mtime, "role", it.role); %#ok<AGROW>
                elseif ~any(string({ins.artifact_id}) == id)
                    ins(end + 1) = struct("artifact_id", id, "role", it.role); %#ok<AGROW>
                end
            end
        end

        function [state, reason] = classify(ME)
            %classify  What a failure means: try again later, hold for a person, or failed.
            id = string(ME.identifier);
            msg = string(ME.message);
            if endsWith(id, ":Unreachable") || any(id == LabSync.Transient) || ...
                    contains(lower(msg), ["timeout", "timed out", "canceling statement", "connection"])
                state = "pending";
                reason = "will try again: " + msg;
            elseif id == "CarasLabDB:idConflict"
                state = "held";
                reason = "Conflict: " + msg;
            else
                state = "failed";
                reason = msg;
            end
        end

        function t = parseTime(txt)
            %parseTime  Zoned text (LabBundles.timeText) as a datetime in UTC (NaT for "").
            txt = string(txt);
            if txt == ""
                t = NaT("TimeZone", "UTC");
                return
            end
            t = datetime(txt, "InputFormat", LabBundles.TimeFormat, "TimeZone", "UTC");
        end

        function txt = addMember(json, name, valueJson)
            %addMember  The JSON object text JSON with member NAME (JSON text VALUEJSON) added, the rest as it was.
            json = strtrim(string(json));
            if ~startsWith(json, "{") || ~endsWith(json, "}")
                error("LabSync:Json", "Not a JSON object: %s", json);
            end
            body = strtrim(extractBetween(json, 2, strlength(json) - 1));
            member = string(jsonencode(char(name))) + ":" + valueJson;
            if body == ""
                txt = "{" + member + "}";
            else
                txt = "{" + body + "," + member + "}";
            end
        end

        function offerSubjects()
            %offerSubjects  Show the subject dialog once for a folder subject that is new, when an app is open.
            st = LabSync.state();
            if isempty(st.Parent) || ~isvalid(st.Parent); return; end
            T = LabSync.subjectHolds();
            ids = setdiff(unique(T.folder_id), st.Offered);
            if isempty(ids); return; end
            st.Offered = [st.Offered, reshape(ids, 1, [])];
            LabSync.state(st);
            SubjectAssignDialog.open(Parent=st.Parent, FolderId=ids(1));
        end
    end
end
