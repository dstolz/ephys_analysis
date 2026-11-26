classdef LabCapture
    % LabCapture  Note in the outbox what a step wrote, for the lab database; never in the way.
    %   Every pipeline step that writes a file records how it made it in the
    %   dataset's Processing (EphysDataset.setProcessing). LabCapture adds
    %   what the lab database needs to that record, always:
    %
    %     event_id     the step's id (a uuid minted here; a background sort
    %                  gets its id when it is launched, launchStamp)
    %     created_at   when the record was made (zoned, microseconds)
    %     started_at   when the step started ("" when the writer did not say)
    %     performer    person_id, person_email, os_user, host
    %     code_version the commit of this code ("-dirty" with uncommitted changes)
    %     outputs      each file it wrote: path, bytes, mtime, artifact_id,
    %                  sha256 (when known)
    %
    %   and, when the lab database is turned on here (labclient.Settings.Enabled),
    %   writes a bundle for it to the outbox (labclient.Outbox): the event, the files
    %   it read (inputs, with their ids when this computer knows them) and the
    %   files it wrote, each as storage root and path (labclient.Roots). Small files
    %   are hashed at once, large ones out of process (labclient.Hasher). Nothing is
    %   sent from here, and nothing here ever stops a step: a failure is a
    %   warning (LabCapture:Failed).
    %
    %   The dataset's session id is kept in <Folder>/<Name>_labdb.json
    %   (sessionFile), written the first time something of the dataset is
    %   captured (or by copySessions for a copied session): the same session
    %   on every record, from every computer that reads that folder.
    %
    %     r = LabCapture.processing(ds, kind, r, Name=Value)   % setProcessing calls it
    %     r = LabCapture.launchStamp(r)      % a sort record, at launch
    %     LabCapture.copiedSession(info)     % copySessions, per session copied
    %     tf = LabCapture.enabled()
    %
    %   See also EphysDataset.setProcessing, labclient.Outbox, labclient.Bundles, labclient.Hasher, labclient.Roots.

    properties (Constant)
        SessionFormat = "ephys-labdb-session/1"
        % files of a sort's results folder that are no results
        SortingSkip = ["ks4_status.json" "ks4_exit.txt" "sorting_record.json" "ks4_launch.cmd" ...
            "si_launch.cmd" "settings.json"]
    end

    methods (Static)
        function tf = enabled(s)
            %enabled  True when records are to be kept for the lab database on this computer.
            %   The shared client's own test (labclient.Sync.enabled: the
            %   settings say Enabled and CarasLabDB can be used), false while
            %   the labclient package is not on the path (LabBridge).
            %   Registers this toolbox's hooks with the client the first time
            %   it is true, so what is captured here can also be sent from here.
            if ~LabBridge.available(); tf = false; return; end
            if nargin < 1; s = labclient.Settings.load(); end
            tf = labclient.Sync.enabled(s);
            if tf; LabBridge.registerTool(); end
        end

        function s = settings()
            %settings  The shared client's settings (labclient.Settings.load), or switched-off ones while the package is missing.
            if LabBridge.available()
                s = labclient.Settings.load();
            else
                s = LabBridge.offSettings();
            end
        end

        function p = performer(s)
            %performer  Who is doing the work here: person_id, person_email (as set up), os_user, host.
            if nargin < 1; s = LabCapture.settings(); end
            p = struct("person_id", s.PersonId, "person_email", s.PersonEmail, ...
                "os_user", LabBridge.osUser(), "host", LabBridge.host());
        end

        function v = codeVersion(prov)
            %codeVersion  The commit of this code, "-dirty" when it had uncommitted changes; the release without git.
            if nargin < 1 || isempty(prov)
                v0 = ephysVersion();
                prov = struct("commit", v0.Commit, "dirty", v0.Dirty, "version", v0.Version);
            end
            v = string(prov.commit);
            if v == ""
                v = "v" + string(prov.version);
            elseif isequal(prov.dirty, true)
                v = v + "-dirty";
            end
        end

        function r = launchStamp(r, opts)
            %launchStamp  Stamp a sort's record when it is launched: event_id, started_at, performer, code_version.
            %   Written into the run folder's sorting record with it, so the
            %   computer that settles the run records it under that id.
            arguments
                r (1,1) struct
                opts.Provenance = []
            end
            r.event_id = LabBridge.newId();
            r.started_at = LabBridge.now();
            r.performer = LabCapture.performer();
            r.code_version = LabCapture.codeVersion(opts.Provenance);
        end

        function r = processing(ds, kind, r, opts)
            %processing  Stamp the record R of step KIND, list its outputs and, when enabled, capture it.
            %   Called before R takes the place of ds.Processing.(KIND), so a
            %   file the earlier records list is known: one this step left as
            %   it was keeps its id, one it rewrote is a new file that
            %   "replaces" the old. A record that has an event_id (a sort's,
            %   from launchStamp) keeps it. Options:
            %   StartedAt (datetime, zoned), FinishedAt (datetime; default
            %   now), Outputs (paths; default the record's file / files /
            %   results folder), Inputs (paths; default by KIND),
            %   Provenance (the writer's ephysProvenance), Capture (false:
            %   only stamp it, for a record of files written earlier).
            arguments
                ds (1,1) EphysDataset
                kind (1,1) string
                r (1,1) struct
                opts.StartedAt (1,1) datetime = NaT("TimeZone", "local")
                opts.FinishedAt (1,1) datetime = datetime("now", "TimeZone", "local")
                opts.Outputs = []
                opts.Inputs = []
                opts.Provenance = []
                opts.Capture (1,1) logical = true
            end
            s = LabCapture.settings();
            on = LabCapture.enabled(s);
            if ~isfield(r, "event_id") || ~LabCapture.isId(r.event_id)
                r.event_id = LabBridge.newId();
            end
            r.created_at = LabBridge.timeText(opts.FinishedAt);
            if ~isfield(r, "started_at") || string(r.started_at) == ""
                r.started_at = "";
                if ~isnat(opts.StartedAt); r.started_at = LabBridge.timeText(LabCapture.zoned(opts.StartedAt, s)); end
            end
            if ~isfield(r, "performer") || ~isstruct(r.performer)
                r.performer = LabCapture.performer(s);
            end
            if ~isfield(r, "code_version") || string(r.code_version) == ""
                r.code_version = LabCapture.codeVersion(opts.Provenance);
            end

            outPaths = opts.Outputs;
            if isempty(outPaths); outPaths = LabCapture.recordFiles(kind, r); end
            outPaths = unique(reshape(string(outPaths), 1, []), "stable");
            known = LabCapture.knownOutputs(ds);
            outDir = LabCapture.outputFolderOf(ds);
            items = LabBridge.noItems();
            for p = outPaths
                [role, kd, attr] = LabCapture.roleOf(kind, p, r);
                rel = LabCapture.datasetRel(p, outDir);
                if rel ~= ""; attr.dataset_rel = rel; end
                it = LabBridge.item(p, Role=role, Kind=kd, Attributes=attr);
                if isnan(it.bytes); continue; end   % listed but not written: nothing to record
                k = LabCapture.findKnown(known, p);
                if k > 0 && LabBridge.sameSnapshot(known(k), it)
                    it.artifact_id = known(k).artifact_id;   % this step left the file as it was
                    it.sha256 = known(k).sha256;
                else
                    it.artifact_id = LabBridge.newId();
                    if k > 0; it.replaces = known(k).artifact_id; end
                end
                items(end + 1) = it; %#ok<AGROW>
            end
            if on
                items = LabCapture.locate(items, s);
                items = LabCapture.hashSmall(items, s);
                for j = 1:numel(items)
                    % rewritten with the same bytes: the same file, not a replacement
                    k = LabCapture.findKnown(known, items(j).path);
                    if items(j).replaces ~= "" && k > 0 && strlength(known(k).sha256) == 64 ...
                            && known(k).sha256 == items(j).sha256
                        items(j).artifact_id = known(k).artifact_id;
                        items(j).replaces = "";
                    end
                end
            end
            r.outputs = LabCapture.recordOutputs(items);
            % Nothing written (a detection kept in memory) or nothing new
            % (Capture=false: a record read back from its file): no record
            % for the database.
            if ~on || ~opts.Capture || isempty(items); return; end

            inPaths = opts.Inputs;
            if isempty(inPaths); inPaths = LabCapture.defaultInputs(ds, kind, r); end
            inPaths = unique(reshape(string(inPaths), 1, []), "stable");
            ses = LabCapture.session(ds.Folder, ds.Name, s);
            ins = LabBridge.noItems();
            for p = inPaths
                [role, kd] = LabCapture.inputRole(ds, p);
                it = LabBridge.item(p, Role=role, Kind=kd);
                k = LabCapture.findKnown(known, p);
                if k > 0 && LabBridge.sameSnapshot(known(k), it)
                    it.artifact_id = known(k).artifact_id;
                    it.sha256 = known(k).sha256;
                else
                    k = LabCapture.findKnown(ses.raw, p);
                    if k > 0 && LabBridge.sameSnapshot(ses.raw(k), it)
                        it.artifact_id = ses.raw(k).artifact_id;
                        it.sha256 = ses.raw(k).sha256;
                    end
                end
                ins(end + 1) = it; %#ok<AGROW>
            end
            ins = LabCapture.locate(ins, s);

            prov = opts.Provenance;
            env = "{}";
            if ~isempty(prov) && isstruct(prov)
                p2 = prov;
                if isfield(p2, "config"); p2 = rmfield(p2, "config"); end
                env = string(jsonencode(provenanceForJson(p2)));
            end
            detail = struct("pipeline_name", LabCapture.pipelineName(kind, r), ...
                "code_version", string(r.code_version), ...
                "parameters_json", string(jsonencode(r)), "environment_json", env, ...
                "started_at", string(r.started_at), "finished_at", string(r.created_at), ...
                "status", "succeeded");
            occurred = string(r.started_at);
            if occurred == ""; occurred = string(r.created_at); end
            attr = struct("step", kind, "dataset", ds.Name, "run_id", LabCapture.fieldText(r, "run_id"));
            b = labclient.Bundles.event(EventId=string(r.event_id), EventType="analysis", ...
                OccurredAt=occurred, Detail=detail, Attributes=attr, ...
                Performer=r.performer, Dataset=LabCapture.datasetBlock(ds, ses, s), ...
                Inputs=ins, Outputs=items, CapturedBy=labclient.Bundles.capturedBy(s));
            b = labclient.Bundles.seal(b);
            labclient.Outbox.put(b);
            LabCapture.startLarge(b, s);
        end

        function failure(ds, kind, opts)
            %failure  Capture a step that failed, or was canceled while it ran: a failed event, no outputs.
            %   LabCapture.failure(DS, KIND, Outcome="failed" | "canceled",
            %   Message=, Seconds=, Parameters= (the step's settings, a
            %   struct), Provenance=). Nothing a failed step left on disk is
            %   registered. Nothing when the database is off here.
            arguments
                ds (1,1) EphysDataset
                kind (1,1) string
                opts.Outcome (1,1) string {mustBeMember(opts.Outcome, ["failed" "canceled"])} = "failed"
                opts.Message (1,1) string = ""
                opts.Seconds (1,1) double = 0
                opts.Parameters = struct()
                opts.Provenance = []
                opts.RunId (1,1) string = ""
            end
            s = LabCapture.settings();
            if ~LabCapture.enabled(s); return; end
            finished = datetime("now", "TimeZone", "local");
            started = finished - seconds(max(0, opts.Seconds));
            ins = LabBridge.noItems();
            for p = unique(LabCapture.defaultInputs(ds, kind, struct()), "stable")
                [role, kd] = LabCapture.inputRole(ds, p);
                ins(end + 1) = LabBridge.item(p, Role=role, Kind=kd); %#ok<AGROW>
            end
            known = LabCapture.knownOutputs(ds);
            ses = LabCapture.session(ds.Folder, ds.Name, s);
            for k = 1:numel(ins)
                j = LabCapture.findKnown(known, ins(k).path);
                if j > 0 && LabBridge.sameSnapshot(known(j), ins(k))
                    ins(k).artifact_id = known(j).artifact_id;
                    ins(k).sha256 = known(j).sha256;
                else
                    j = LabCapture.findKnown(ses.raw, ins(k).path);
                    if j > 0 && LabBridge.sameSnapshot(ses.raw(j), ins(k))
                        ins(k).artifact_id = ses.raw(j).artifact_id;
                        ins(k).sha256 = ses.raw(j).sha256;
                    end
                end
            end
            ins = LabCapture.locate(ins, s);
            env = "{}";
            if isstruct(opts.Provenance) && ~isempty(opts.Provenance)
                p2 = opts.Provenance;
                if isfield(p2, "config"); p2 = rmfield(p2, "config"); end
                env = string(jsonencode(provenanceForJson(p2)));
            end
            par = "{}";
            if isstruct(opts.Parameters) && isscalar(opts.Parameters)
                par = string(jsonencode(stringifyNonFinite(opts.Parameters)));
            end
            detail = struct("pipeline_name", LabCapture.pipelineName(kind, struct()), ...
                "code_version", LabCapture.codeVersion(opts.Provenance), ...
                "parameters_json", par, "environment_json", env, ...
                "started_at", LabBridge.timeText(started), "finished_at", LabBridge.timeText(finished), ...
                "status", "failed");
            attr = struct("step", kind, "dataset", ds.Name, "run_id", opts.RunId, ...
                "outcome", opts.Outcome, "error", opts.Message);
            perf = LabCapture.performer(s);
            b = labclient.Bundles.event(EventId=LabBridge.newId(), EventType="analysis", ...
                OccurredAt=LabBridge.timeText(started), Detail=detail, Attributes=attr, ...
                Performer=perf, Dataset=LabCapture.datasetBlock(ds, ses, s), Inputs=ins, ...
                CapturedBy=labclient.Bundles.capturedBy(s));
            labclient.Outbox.put(labclient.Bundles.seal(b));
        end

        function copiedSession(info)
            %copiedSession  Capture a session copySessions copied: its recording, and its ePsych session.
            %   INFO: dest (the session folder), subject, reader (the reader's
            %   kind), recording_time, recording_duration (seconds, NaN),
            %   source_dir, files (struct: path, sha256, is_epsych),
            %   epsych_file, epsych_time, epsych_trials, finished (datetime).
            %   Once per session folder: one captured before (its
            %   recording_event_id in the session file) is left as it was.
            %   Nothing when the database is off here.
            s = LabCapture.settings();
            if ~LabCapture.enabled(s); return; end
            dest = string(info.dest);
            [~, name] = fileparts(dest);
            name = string(name);
            ses = LabCapture.session(dest, name, s);
            if ses.recording_event_id ~= ""; return; end
            perf = LabCapture.performer(s);
            ver = LabCapture.codeVersion();
            dsb = struct("name", name, "folder", dest, "session_id", ses.session_id, ...
                "subject_folder_id", string(info.subject), ...
                "recording_start", LabCapture.timeOrEmpty(info.recording_time, s), "tool", LabBridge.Tool);
            files = info.files;
            raw = LabBridge.noItems();
            ep = LabBridge.noItems();
            for k = 1:numel(files)
                p = string(files(k).path);
                if files(k).is_epsych
                    it = LabBridge.item(p, Role="raw", Kind="epsych", ArtifactId=LabBridge.newId(), ...
                        Sha256=string(files(k).sha256));
                    if ~isnan(it.bytes); ep(end + 1) = it; end %#ok<AGROW>
                else
                    it = LabBridge.item(p, Role="raw", Kind="raw", ArtifactId=LabBridge.newId(), ...
                        Sha256=string(files(k).sha256), Attributes=struct("reader", string(info.reader)));
                    if ~isnan(it.bytes); raw(end + 1) = it; end %#ok<AGROW>
                end
            end
            raw = LabCapture.hashSmall(LabCapture.locate(raw, s), s);
            ep = LabCapture.hashSmall(LabCapture.locate(ep, s), s);

            recId = LabBridge.newId();
            detail = struct();
            sys = LabCapture.acquisitionSystem(string(info.reader));
            if sys ~= ""; detail.acquisition_system_code = sys; end
            if isfinite(info.recording_duration); detail.duration_s = double(info.recording_duration); end
            occurred = LabCapture.timeOrEmpty(info.recording_time, s);
            if occurred == ""; occurred = LabBridge.timeText(info.finished); end
            attr = struct("copied_from", string(info.source_dir), "captured_by_tool", "copySessions", ...
                "code_version", ver, "occurred_at_source", ...
                LabCapture.ternary(LabCapture.timeOrEmpty(info.recording_time, s) == "", ...
                "copy finished (no recording time known)", "recording folder name"));
            b = labclient.Bundles.event(EventId=recId, EventType="recording", OccurredAt=occurred, ...
                Detail=detail, Attributes=attr, Performer=perf, Dataset=dsb, Outputs=raw, ...
                CapturedBy=labclient.Bundles.capturedBy(s));
            b = labclient.Bundles.seal(b);
            labclient.Outbox.put(b);
            LabCapture.startLarge(b, s);
            ses.recording_event_id = recId;
            ses.raw = raw;

            if ~isempty(ep)
                behId = LabBridge.newId();
                bd = struct();
                if isfinite(info.epsych_trials); bd.trials_completed = double(info.epsych_trials); end
                occ = LabCapture.timeOrEmpty(info.epsych_time, s);
                if occ == ""; occ = occurred; end
                b2 = labclient.Bundles.event(EventId=behId, EventType="behavior", OccurredAt=occ, ...
                    Detail=bd, Attributes=struct("captured_by_tool", "copySessions", "code_version", ver), ...
                    Performer=perf, Dataset=dsb, Outputs=ep, CapturedBy=labclient.Bundles.capturedBy(s), ...
                    After=recId);
                b2 = labclient.Bundles.seal(b2);
                labclient.Outbox.put(b2);
                LabCapture.startLarge(b2, s);
                ses.behavior_event_id = behId;
                ses.raw = [raw, ep];
            end
            LabCapture.writeSession(dest, name, ses);
        end

        function [ses, found] = readSession(folder, name)
            %readSession  The dataset's session file as a struct (see session); FOUND false, and no id, when there is none.
            ses = struct("format", LabCapture.SessionFormat, "session_id", "", "created_at", "", ...
                "subject_id", "", "recording_event_id", "", "behavior_event_id", "", ...
                "raw", LabBridge.noItems(), "phy_opened", LabCapture.noOpened(), ...
                "curations", LabCapture.noCurations(), "copy_of_session_from", "");
            found = false;
            if string(folder) == "" || string(name) == ""; return; end
            f = LabCapture.sessionFile(folder, name);
            if ~isfile(f); return; end
            x = readJsonFile(f, ErrorOnFail=false);
            if ~(isstruct(x) && isfield(x, "session_id") && LabCapture.isId(x.session_id)); return; end
            ses.session_id = lower(string(x.session_id));
            for k = ["created_at" "subject_id" "recording_event_id" "behavior_event_id" "copy_of_session_from"]
                if isfield(x, k) && ~isempty(x.(k)); ses.(k) = string(x.(k)); end
            end
            if isfield(x, "raw")
                ses.raw = LabBridge.toItems(x.raw);
            end
            if isfield(x, "phy_opened")
                for o = LabCapture.cells(x.phy_opened)
                    v = o{1};
                    e = LabCapture.noOpened();
                    for fn = string(fieldnames(e)).'
                        e(1).(fn) = "";
                        if isfield(v, fn) && ~isempty(v.(fn)); e(1).(fn) = string(v.(fn)); end
                    end
                    ses.phy_opened(end + 1) = e;
                end
            end
            if isfield(x, "curations")
                for c = LabCapture.cells(x.curations)
                    v = c{1};
                    e = struct("event_id", "", "sort_event_id", "", "results_dir", "", "saved", "", ...
                        "files", LabCapture.noKnown());
                    for fn = ["event_id" "sort_event_id" "results_dir" "saved"]
                        if isfield(v, fn) && ~isempty(v.(fn)); e.(fn) = string(v.(fn)); end
                    end
                    if isfield(v, "files")
                        for g = LabCapture.cells(v.files)
                            w = g{1};
                            b = NaN;
                            if isfield(w, "bytes") && ~isempty(w.bytes); b = double(w.bytes); end
                            e.files(end + 1) = struct("path", LabCapture.fieldText(w, "path"), "bytes", b, ...
                                "mtime", LabCapture.fieldText(w, "mtime"), "artifact_id", LabCapture.fieldText(w, "artifact_id"), ...
                                "sha256", LabCapture.fieldText(w, "sha256"), "step", "sorting", ...
                                "event_id", LabCapture.fieldText(w, "event_id"));
                        end
                    end
                    ses.curations(end + 1) = e;
                end
            end
            found = true;
        end

        function assignSubject(folder, name, subjectId)
            %assignSubject  Note in the dataset's session file the database subject its session belongs to.
            %   The folder and its name are not changed. "" goes back to the
            %   subject the folder name gives.
            [ses, found] = LabCapture.readSession(folder, name);
            if ~found
                ses = LabCapture.session(folder, name);
                if ses.session_id == ""
                    error("LabCapture:NoSessionFile", "The session file of %s cannot be written in %s.", ...
                        name, folder);
                end
            end
            ses.subject_id = string(subjectId);
            LabCapture.writeSession(folder, name, ses);
        end

        function copyOfSession(folder, name, sessionId, kind, eventId)
            %copyOfSession  Note in a dataset's session file that its folder is a copy of session SESSIONID.
            %   LabCapture.copyOfSession(FOLDER, NAME, SESSIONID, KIND, EVENTID):
            %   the folder's raw files are, byte for byte, those of a recording
            %   already in the database (labclient.Sync): the session file takes that
            %   session's id, and for KIND "recording" or "behavior" with
            %   EVENTID, that event as the one its raw files belong to. The id
            %   it had is kept as copy_of_session_from. The folder is not
            %   changed otherwise.
            [ses, found] = LabCapture.readSession(folder, name);
            if ~found || ses.session_id == string(sessionId)
                if found && eventId ~= ""
                    if kind == "recording"; ses.recording_event_id = string(eventId); end
                    if kind == "behavior"; ses.behavior_event_id = string(eventId); end
                    LabCapture.writeSession(folder, name, ses);
                end
                return
            end
            ses.copy_of_session_from = ses.session_id;
            ses.session_id = string(sessionId);
            if eventId ~= ""
                if kind == "recording"; ses.recording_event_id = string(eventId); end
                if kind == "behavior"; ses.behavior_event_id = string(eventId); end
            end
            LabCapture.writeSession(folder, name, ses);
        end

        function phyOpened(ds, resultsDir)
            %phyOpened  Note in dataset DS's session file that phy was opened on RESULTSDIR from the app, by whom.
            %   The person, login and computer, and when. LabCapture.curation
            %   names them as who opened phy when it records what phy saved
            %   there. Nothing when the database is off here.
            s = LabCapture.settings();
            if ~LabCapture.enabled(s); return; end
            ses = LabCapture.session(ds.Folder, ds.Name, s);
            if ses.session_id == ""; return; end
            p = LabCapture.performer(s);
            e = LabCapture.noOpened();
            e(1).results_dir = string(resultsDir);
            e(1).at = LabBridge.now();
            e(1).person_id = string(p.person_id);
            e(1).person_email = string(p.person_email);
            e(1).os_user = string(p.os_user);
            e(1).host = string(p.host);
            ses.phy_opened = [ses.phy_opened(max(1, end - 18):end), e];   % the last 20
            LabCapture.writeSession(ds.Folder, ds.Name, ses);
        end

        function id = curation(ds)
            %curation  Capture what phy changed in dataset DS's recorded sort, for the lab database (once per change).
            %   ID = LabCapture.curation(DS) compares the files of the results
            %   folder of DS's sort record (Processing.sorting) with the
            %   versions recorded: the sort's outputs, then the curations of
            %   that sort since. When some changed or are new and phy saved
            %   there (EphysDataset.phyStatus "saved"), it captures one
            %   analysis event, pipeline_name "phy", finished when phy saved:
            %     inputs   the sort's files as recorded (their ids)
            %     outputs  the files phy changed or added, each changed one
            %              replacing the version before (replaces: a
            %              "replaced" disposition when sent)
            %   A file saved again with the same bytes is not a change. The
            %   attributes say who opened phy on the folder from the app
            %   (opened_by, from phyOpened; started_at is then that time), or
            %   "unknown"; the event's person is who records it here. The
            %   session file keeps the curation (curations), so the next look
            %   finds nothing new. ID is the event's id ("" when none).
            %   Nothing when the database is off here. EphysProject.refresh
            %   (a scan) calls it.
            id = "";
            s = LabCapture.settings();
            if ~LabCapture.enabled(s); return; end
            P = ds.Processing;
            if ~isstruct(P) || ~isfield(P, "sorting"); return; end
            r = P.sorting;
            if ~isstruct(r) || ~isscalar(r) || ~isfield(r, "results_dir") || ~isfield(r, "event_id") ...
                    || ~LabCapture.isId(r.event_id); return; end
            d = string(r.results_dir);
            if ~isscalar(d) || d == "" || ~isfolder(d); return; end
            known = LabCapture.knownOutputs(ds);
            if ~isempty(known); known = known([known.step] == "sorting"); end
            changed = strings(1, 0);
            for p = LabCapture.recordFiles("sorting", struct("results_dir", d))
                k = LabCapture.findKnown(known, p);
                if k > 0 && LabBridge.sameSnapshot(known(k), LabBridge.snapshot(p)); continue; end
                changed(end + 1) = p; %#ok<AGROW>
            end
            if isempty(changed); return; end
            st = EphysDataset.phyStatus(d);
            if st.state ~= "saved"; return; end   % changed, but not by phy (a sort still writing)
            ses = LabCapture.session(ds.Folder, ds.Name, s);
            if ses.session_id == ""; return; end   % no session file to keep it in: it would be captured again
            saved = st.saved;
            saved.TimeZone = "local";   % a file's time on this computer
            outDir = LabCapture.outputFolderOf(ds);
            items = LabBridge.noItems();
            for p = changed
                [role, kd, attr] = LabCapture.roleOf("sorting", p, r);
                rel = LabCapture.datasetRel(p, outDir);
                if rel ~= ""; attr.dataset_rel = rel; end
                attr.curated_in = "phy";
                it = LabBridge.item(p, Role=role, Kind=kd, Attributes=attr);
                if isnan(it.bytes); continue; end
                it.artifact_id = LabBridge.newId();
                k = LabCapture.findKnown(known, p);
                if k > 0; it.replaces = known(k).artifact_id; end
                items(end + 1) = it; %#ok<AGROW>
            end
            items = LabCapture.locate(items, s);
            items = LabCapture.hashSmall(items, s);
            files = LabCapture.noKnown();
            keep = true(1, numel(items));
            id = LabBridge.newId();
            for j = 1:numel(items)
                k = LabCapture.findKnown(known, items(j).path);
                ev = id;
                if k > 0 && strlength(known(k).sha256) == 64 && known(k).sha256 == items(j).sha256
                    keep(j) = false;   % saved again with the same bytes: the same file
                    items(j).artifact_id = known(k).artifact_id;
                    ev = known(k).event_id;
                end
                files(end + 1) = struct("path", items(j).path, "bytes", items(j).bytes, "mtime", items(j).mtime, ...
                    "artifact_id", items(j).artifact_id, "sha256", items(j).sha256, "step", "sorting", "event_id", ev); %#ok<AGROW>
            end
            entry = struct("event_id", "", "sort_event_id", string(r.event_id), "results_dir", d, ...
                "saved", LabBridge.timeText(saved), "files", files);
            outputs = items(keep);
            if isempty(outputs)
                id = "";
            else
                entry.event_id = id;
                ins = LabBridge.noItems();
                seen = strings(1, 0);
                for k = numel(known):-1:1   % each file's latest version, as recorded
                    key = EphysDataset.pathKey(known(k).path);
                    if any(seen == key); continue; end
                    seen(end + 1) = key; %#ok<AGROW>
                    [role, kd] = LabCapture.roleOf("sorting", known(k).path, r);
                    it = LabBridge.item(known(k).path, Role=role, Kind=kd, ...
                        Snapshot=struct("bytes", known(k).bytes, "mtime", known(k).mtime));
                    it.artifact_id = known(k).artifact_id;
                    it.sha256 = known(k).sha256;
                    ins(end + 1) = it; %#ok<AGROW>
                end
                ins = LabCapture.locate(fliplr(ins), s);
                o = LabCapture.lastOpened(ses, d, saved);
                started = "";
                opened = "unknown";
                if ~isempty(o)
                    started = o.at;
                    opened = rmfield(o, "results_dir");
                end
                detail = struct("pipeline_name", "phy", "parameters_json", "{}", ...
                    "environment_json", "{}", "started_at", started, "finished_at", LabBridge.timeText(saved), ...
                    "status", "succeeded");
                occurred = started;
                if occurred == ""; occurred = LabBridge.timeText(saved); end
                attr = struct("step", "curation", "tool", "phy", "dataset", ds.Name, "results_dir", d, ...
                    "sort_event_id", string(r.event_id), "opened_by", opened, ...
                    "phy_labels", {cellstr(st.labels)}, "phy_label_counts", st.counts, "phy_clusters", st.clusters);
                b = labclient.Bundles.event(EventId=id, EventType="analysis", OccurredAt=occurred, Detail=detail, ...
                    Attributes=attr, Performer=LabCapture.performer(s), Dataset=LabCapture.datasetBlock(ds, ses, s), ...
                    Inputs=ins, Outputs=outputs, CapturedBy=labclient.Bundles.capturedBy(s));
                b = labclient.Bundles.seal(b);
            end
            % The session file first: a curation it does not keep would be
            % captured again at the next look, a second event for one save.
            before = ses;
            ses.curations(end + 1) = entry;
            LabCapture.writeSession(ds.Folder, ds.Name, ses);
            if isempty(outputs); return; end
            try
                labclient.Outbox.put(b);
            catch ME
                LabCapture.writeSession(ds.Folder, ds.Name, before);   % not captured: looked for again next time
                rethrow(ME);
            end
            LabCapture.startLarge(b, s);
        end

        function [id, info] = analysisRun(r, idx, opts)
            %analysisRun  Capture a run of figures (EphysAnalysisRunner.run) for the lab database: one analysis event.
            %   [ID, INFO] = LabCapture.analysisRun(R, IDX, Started=,
            %   Finished=, Outcome=, Error=, RunRecord=), after runner R ran
            %   its datasets IDX:
            %     inputs   the files the run read (each dataset's read ledger,
            %              DatasetOutputs.Reads), each by its id when the
            %              dataset's records name that file as it was read;
            %              one they do not name is an input this computer
            %              cannot name (listed when sent, never guessed)
            %     outputs  the report files, the run record and the figure
            %              files it wrote that lie under a storage root mapped
            %              here (the others listed in unrecorded_outputs); a
            %              file an earlier run here wrote at the same place
            %              with other bytes is replaced by it. A figure file
            %              kept from an earlier run (R.KeptFiles: on disk with
            %              Export.Overwrite off, not written by this run) is no
            %              output of it: listed in kept_outputs
            %   pipeline_name "ephys_analysis/figures", parameters the
            %   analysis config, the code and the machine, when it started
            %   and finished. Status "succeeded", or "failed": a run that
            %   did not finish (attributes.outcome "canceled", or "failed"
            %   with attributes.error, Error=: the run threw), and a run
            %   that finished having drawn no figure because every one it
            %   tried failed (Results rows "error", none "done"; outcome
            %   "finished"). attributes.figure_errors counts the "error"
            %   rows, so a run that drew some figures and failed others is
            %   "succeeded" and says how many failed. The event names a
            %   session only when the run covers one dataset. ID: the
            %   event's id ("" when nothing was captured: the database off
            %   here, or nothing read or written). Config= (an
            %   EphysAnalysisConfig; default [] = R.Config) is the config
            %   recorded as the parameters and config_name:
            %   EphysAnalysisRunner.run passes the one it started with,
            %   since R.Config may have changed while it ran.
            %
            %   INFO says what was noted, for the run's Log: id, status,
            %   inputs and outputs (how many), unrecorded (the files left
            %   out for being under no storage root mapped here), kept (the
            %   kept figure files left out) and why ("" when noted, "off"
            %   while the database is off here, "nothing" when the run read
            %   nothing and wrote nothing under a mapped root).
            %
            %   The output ledger (outputLedger) is read once per run, for
            %   every output, and written once, after the record is in the
            %   outbox.
            arguments
                r
                idx (1,:) double
                opts.Started (1,1) datetime
                opts.Finished (1,1) datetime
                opts.Outcome (1,1) string {mustBeMember(opts.Outcome, ["finished" "canceled" "failed"])} = "finished"
                opts.Error (1,1) string = ""
                opts.RunRecord (1,1) string = ""
                opts.Config = []
            end
            id = "";
            info = struct("id", "", "status", "", "inputs", 0, "outputs", 0, ...
                "unrecorded", strings(1, 0), "kept", strings(1, 0), "why", "off");
            s = LabCapture.settings();
            if ~LabCapture.enabled(s); return; end
            ins = LabBridge.noItems();
            for k = idx
                out = r.Outputs(k);
                R = out.Reads;
                if height(R) == 0; continue; end
                if ~isempty(out.Dataset)
                    known = LabCapture.knownFiles(out.Dataset);
                else
                    P = struct();
                    try
                        m = out.Manifest;
                        if isfield(m, "processing") && isstruct(m.processing); P = m.processing; end
                    catch
                    end
                    known = LabCapture.knownFiles(P, out.Folder, out.Name);
                end
                for j = 1:height(R)
                    snap = struct("bytes", R.bytes(j), "mtime", R.mtime(j));
                    c = LabCapture.findKnown(known, R.path(j));
                    if c > 0 && LabBridge.sameSnapshot(known(c), snap)
                        [role, kd] = LabCapture.roleOfKnown(known(c), []);
                        it = LabBridge.item(R.path(j), Role=role, Kind=kd, Snapshot=snap);
                        it.artifact_id = known(c).artifact_id;
                        it.sha256 = known(c).sha256;
                    else
                        it = LabBridge.item(R.path(j), Role="derived", Kind="", Snapshot=snap);
                    end
                    ins(end + 1) = it; %#ok<AGROW>
                end
            end
            ins = LabCapture.locate(ins, s);

            % what it wrote
            want = struct("path", {}, "role", {}, "kind", {}, "dataset", {});
            for p = reshape(string(r.ReportFiles), 1, [])
                want(end + 1) = struct("path", p, "role", "report", "kind", "report", "dataset", ""); %#ok<AGROW>
            end
            if opts.RunRecord ~= ""
                want(end + 1) = struct("path", opts.RunRecord, "role", "report", "kind", "run_record", "dataset", "");
            end
            T = r.Results;
            for j = 1:height(T)
                for p = reshape(strtrim(split(string(T.Files(j)), ";")), 1, [])
                    if p == ""; continue; end
                    want(end + 1) = struct("path", p, "role", "figure", "kind", "figure", "dataset", string(T.Dataset(j))); %#ok<AGROW>
                end
            end
            keptKeys = strings(1, 0);   % the figure files on disk from an earlier run, kept (Export.Overwrite off): not this run's
            try
                keptKeys = EphysDataset.pathKey(reshape(string(r.KeptFiles), 1, []));
            catch
            end
            items = LabBridge.noItems();
            unrecorded = strings(1, 0);
            kept = strings(1, 0);
            seen = strings(1, 0);
            for w = want
                key = EphysDataset.pathKey(w.path);
                if any(seen == key) || ~isfile(w.path); continue; end
                seen(end + 1) = key; %#ok<AGROW>
                if w.role == "figure" && any(keptKeys == key)
                    kept(end + 1) = w.path; %#ok<AGROW>   % not written by this run: it would claim bytes it did not make
                    continue
                end
                if labclient.Roots.locate(w.path, s) == ""
                    unrecorded(end + 1) = w.path; %#ok<AGROW>
                    continue
                end
                attr = struct();
                if w.dataset ~= ""; attr.dataset = w.dataset; end
                items(end + 1) = LabBridge.item(w.path, Role=w.role, Kind=w.kind, Attributes=attr, ...
                    ArtifactId=LabBridge.newId()); %#ok<AGROW>
            end
            items = LabCapture.hashSmall(LabCapture.locate(items, s), s);
            if ~isempty(items)
                prev = LabCapture.outputLedger([items.path]);   % one read of the ledger for every output
                for j = 1:numel(items)
                    % a file an earlier run here wrote at this place: the same bytes are that file, other bytes replace it
                    pv = split(prev(j), " ");
                    if numel(pv) == 2 && pv(1) ~= ""
                        if strlength(items(j).sha256) == 64 && items(j).sha256 == pv(2)
                            items(j).artifact_id = pv(1);
                        else
                            items(j).replaces = pv(1);
                        end
                    end
                end
            end
            info.why = "";
            info.unrecorded = unrecorded;
            info.kept = kept;
            if isempty(ins) && isempty(items)
                info.why = "nothing";
                return
            end

            cfg = opts.Config;
            if ~isa(cfg, "EphysAnalysisConfig"); cfg = r.Config; end   % the run's own config, as its run record holds it
            prov = ephysProvenance();
            p2 = prov;
            if isfield(p2, "config"); p2 = rmfield(p2, "config"); end
            started = opts.Started;
            if isempty(started.TimeZone); started.TimeZone = "local"; end
            finished = opts.Finished;
            if isempty(finished.TimeZone); finished.TimeZone = "local"; end
            nError = 0;
            nDone = 0;
            if height(T) > 0
                nError = nnz(string(T.Status) == "error");
                nDone = nnz(string(T.Status) == "done");
            end
            % Failed: it did not finish (canceled, or it threw), or it finished having drawn nothing because every
            % figure it tried failed (the others, if any, skipped). One that drew some and failed others succeeded,
            % and figure_errors says how many failed: the database's status is succeeded | failed, nothing between.
            ok = opts.Outcome == "finished" && ~(nError > 0 && nDone == 0);
            status = LabCapture.ternary(ok, "succeeded", "failed");
            detail = struct("pipeline_name", "ephys_analysis/figures", ...
                "code_version", LabCapture.codeVersion(prov), ...
                "parameters_json", string(jsonencode(stringifyNonFinite(cfg.toStruct()))), ...   % as the run record writes it
                "environment_json", string(jsonencode(provenanceForJson(p2))), ...
                "started_at", LabBridge.timeText(started), "finished_at", LabBridge.timeText(finished), ...
                "status", status);
            attr = struct("step", "analysis", "tool", "EphysAnalysisRunner", "config_name", string(cfg.Name), ...
                "datasets", {cellstr(string(r.Names(idx)))}, "outcome", opts.Outcome, "error", opts.Error, ...
                "figure_errors", nError, "unrecorded_outputs", {cellstr(unrecorded)}, "kept_outputs", {cellstr(kept)});
            dsb = labclient.Bundles.noDataset();
            if isscalar(idx) && ~isempty(r.Outputs(idx).Dataset)
                ds = r.Outputs(idx).Dataset;
                dsb = LabCapture.datasetBlock(ds, LabCapture.session(ds.Folder, ds.Name, s), s);
            end
            id = LabBridge.newId();
            b = labclient.Bundles.event(EventId=id, EventType="analysis", OccurredAt=LabBridge.timeText(started), ...
                Detail=detail, Attributes=attr, Performer=LabCapture.performer(s), Dataset=dsb, ...
                Inputs=ins, Outputs=items, CapturedBy=labclient.Bundles.capturedBy(s));
            b = labclient.Bundles.seal(b);
            labclient.Outbox.put(b);
            LabCapture.startLarge(b, s);
            info.id = id;
            info.status = status;
            info.inputs = numel(ins);
            info.outputs = numel(items);
            if isempty(items); return; end
            try   % the record is in the outbox: a ledger that cannot be written costs the next run its "replaces", not this record
                LabCapture.outputLedger([items.path], [items.artifact_id] + " " + [items.sha256]);   % one write for the run
            catch ME
                warning("LabCapture:OutputLedger", "The outputs of this run could not be noted in this computer's " + ...
                    "output ledger (%s): the next run here will not know which of them it replaces.", ME.message);
            end
        end

        function transferred(ds, b, X)
            %transferred  Note what an OutputTransfer did with dataset DS's files, for the lab database.
            %   Called on every change of batch B of transfer X (the
            %   pipeline's BatchFcn). Once a batch is copied (a copy that is
            %   "done", or a move that is "copied"), each copy of a file the
            %   dataset's records name becomes a new file produced by the same
            %   event, with copied_from (its id, path and SHA-256); a copy into
            %   a file already there (IfExists "overwrite") says so. Once a
            %   move is "done", each source it removed is recorded as moved to
            %   its copy. A file no record names is not registered (counted).
            %   Nothing when the database is off here.
            if ~LabCapture.enabled(); return; end
            copied = (b.State == "done" && X.Method == "copy") || (b.State == "copied" && X.Method == "move");
            moved = b.State == "done" && X.Method == "move";
            if ~copied && ~moved; return; end
            key = X.Uid + "/" + b.Id + "/" + LabCapture.ternary(copied, "copied", "moved");
            if LabCapture.ledger(key) ~= ""; return; end   % noted already
            s = LabCapture.settings();
            F = b.Files;
            [known, evs] = LabCapture.knownFiles(ds);
            if copied
                rows = find(F.State == "copied").';
                groups = struct("event", {}, "items", {});
                untracked = 0;
                for m = rows
                    src = F.Src(m);
                    copy = string(fullfile(b.DestDir, F.Rel(m)));
                    j = LabCapture.findKnown(known, src);
                    if j == 0 || ~LabBridge.sameSnapshot(known(j), LabBridge.snapshot(src))
                        untracked = untracked + 1;
                        LabCapture.ledger(X.Uid + "|" + lower(src), "untracked");
                        continue
                    end
                    ev = known(j).event_id;
                    if ev == ""; untracked = untracked + 1; LabCapture.ledger(X.Uid + "|" + lower(src), "untracked"); continue; end
                    [role, kd, attr] = LabCapture.roleOfKnown(known(j), evs);
                    attr.copied_from = known(j).artifact_id;
                    attr.copied_from_path = src;
                    attr.copied_from_sha256 = known(j).sha256;
                    attr.overwrote = X.IfExists == "overwrite";
                    attr.transfer = X.Uid;
                    rel = LabCapture.carriedRel(LabCapture.datasetRel(src, LabCapture.outputFolderOf(ds)), copy);
                    if rel ~= ""; attr.dataset_rel = rel; end
                    it = LabBridge.item(copy, Role=role, Kind=kd, Attributes=attr, ArtifactId=LabBridge.newId(), ...
                        Sha256=X.sha256Of(src));
                    if isnan(it.bytes); continue; end
                    g = find(string({groups.event}) == ev, 1);
                    if isempty(g)
                        groups(end + 1) = struct("event", ev, "items", it); %#ok<AGROW>
                    else
                        groups(g).items(end + 1) = it;
                    end
                    LabCapture.ledger(X.Uid + "|" + lower(src), it.artifact_id + " " + known(j).artifact_id);
                end
                ids = strings(1, 0);
                for g = 1:numel(groups)
                    items = LabCapture.hashSmall(LabCapture.locate(groups(g).items, s), s);
                    fb = labclient.Bundles.files(EventId=groups(g).event, Artifacts=items, After=groups(g).event, ...
                        Attributes=struct("tool", "OutputTransfer", "method", X.Method, "dataset", ds.Name, ...
                        "untracked_files", untracked), CapturedBy=labclient.Bundles.capturedBy(s));
                    labclient.Outbox.put(fb);
                    LabCapture.startLarge(fb, s);
                    ids(end + 1) = fb.bundle_id; %#ok<AGROW>
                end
                LabCapture.ledger(key, strjoin([ids, "-"], " "));
            else
                rows = find(F.State == "removed").';
                D = struct("event", {}, "rows", {});
                for m = rows
                    e = LabCapture.ledger(X.Uid + "|" + lower(F.Src(m)));
                    if e == "" || e == "untracked"; continue; end
                    parts = split(e, " ");
                    copyId = parts(1); srcId = parts(2);
                    j = find([known.artifact_id] == srcId, 1);
                    if isempty(j); continue; end
                    d = labclient.Bundles.disposition(srcId, "moved", Successor=copyId, ...
                        Attributes=struct("transfer", X.Uid, "to", string(fullfile(b.DestDir, F.Rel(m)))));
                    g = find(string({D.event}) == known(j).event_id, 1);
                    if isempty(g)
                        D(end + 1) = struct("event", known(j).event_id, "rows", d); %#ok<AGROW>
                    else
                        D(g).rows(end + 1) = d;
                    end
                end
                before = split(LabCapture.ledger(X.Uid + "/" + b.Id + "/copied"), " ").';
                before = before(before ~= "" & before ~= "-");
                for g = 1:numel(D)
                    fb = labclient.Bundles.files(EventId=D(g).event, Dispositions=D(g).rows, After=before, ...
                        Attributes=struct("tool", "OutputTransfer", "method", "move", "dataset", ds.Name), ...
                        CapturedBy=labclient.Bundles.capturedBy(s));
                    labclient.Outbox.put(fb);
                end
                LabCapture.ledger(key, "done");
            end
        end

        function tf = copyRecorded(uid, src)
            %copyRecorded  True when transfer UID's copy of SRC is noted (or SRC is a file no record names): SRC may go.
            tf = LabCapture.ledger(string(uid) + "|" + lower(string(src))) ~= "";
        end

        function cleanedUp(R, method)
            %cleanedUp  Note what runLocalCleanup did with the files it removed, for the lab database.
            %   R: its result rows (Dataset, Folder, File, Bytes, Status, To,
            %   Replaced). A file a record of its dataset names (the
            %   manifest's processing outputs, or the session file's raw
            %   files), with the size the record gives: deleted or recycled,
            %   it is recorded as deleted (attributes.method); moved, its new
            %   place is a new file produced by the same event (its SHA-256
            %   taken there) and the old one is recorded as moved to it.
            %   Nothing when the database is off here.
            if ~LabCapture.enabled() || isempty(R); return; end
            s = LabCapture.settings();
            R = R(R.Status == "removed", :);
            for folder = unique(R.Folder).'
                Rf = R(R.Folder == folder, :);
                name = Rf.Dataset(1);
                P = struct();
                m = readJsonFile(fullfile(folder, name + "_manifest.json"), ErrorOnFail=false);
                if isstruct(m) && isfield(m, "processing") && isstruct(m.processing); P = m.processing; end
                [known, evs] = LabCapture.knownFiles(P, folder, name);
                groups = struct("event", {}, "items", {}, "rows", {});
                for k = 1:height(Rf)
                    j = LabCapture.findKnown(known, Rf.File(k));
                    if j == 0 || ~(isnan(known(j).bytes) || known(j).bytes == double(Rf.Bytes(k))) ...
                            || known(j).event_id == ""
                        continue   % a file no record names, or other bytes than recorded
                    end
                    it = LabBridge.noItems();
                    if method == "move"
                        [role, kd, attr] = LabCapture.roleOfKnown(known(j), evs);
                        attr.copied_from = known(j).artifact_id;
                        attr.copied_from_path = Rf.File(k);
                        attr.copied_from_sha256 = known(j).sha256;
                        attr.overwrote = isequal(Rf.Replaced(k), true);
                        attr.tool = "runLocalCleanup";
                        it = LabBridge.item(string(Rf.To(k)), Role=role, Kind=kd, Attributes=attr, ...
                            ArtifactId=LabBridge.newId());
                        d = labclient.Bundles.disposition(known(j).artifact_id, "moved", Successor=it.artifact_id, ...
                            Attributes=struct("method", "move", "tool", "runLocalCleanup", "to", string(Rf.To(k))));
                    else
                        d = labclient.Bundles.disposition(known(j).artifact_id, "deleted", ...
                            Attributes=struct("method", method, "tool", "runLocalCleanup"));
                    end
                    ev = known(j).event_id;
                    g = find(string({groups.event}) == ev, 1);
                    if isempty(g)
                        groups(end + 1) = struct("event", ev, "items", it, "rows", d); %#ok<AGROW>
                    else
                        groups(g).items = [groups(g).items, it];
                        groups(g).rows(end + 1) = d;
                    end
                end
                for g = 1:numel(groups)
                    items = LabCapture.hashSmall(LabCapture.locate(groups(g).items, s), s);
                    fb = labclient.Bundles.files(EventId=groups(g).event, Artifacts=items, Dispositions=groups(g).rows, ...
                        After=groups(g).event, Attributes=struct("tool", "runLocalCleanup", "method", method, ...
                        "dataset", name), CapturedBy=labclient.Bundles.capturedBy(s));
                    labclient.Outbox.put(fb);
                    LabCapture.startLarge(fb, s);
                end
            end
        end

        function f = sessionFile(folder, name)
            %sessionFile  The dataset's session file: <FOLDER>/<NAME>_labdb.json.
            f = string(fullfile(folder, name + "_labdb.json"));
        end

        function ses = session(folder, name, s)
            %session  The dataset's session file as a struct, written with a new session id when missing.
            %   Fields: format, session_id, created_at, subject_id (the
            %   database subject a person assigned the session to, "" when
            %   the folder's own is meant; labclient.SubjectAssignDialog),
            %   recording_event_id, behavior_event_id, raw (the raw files as
            %   captured, labclient.Bundles items). A folder that cannot be written
            %   gives session_id "" (resolved when sent).
            if nargin < 3; s = LabCapture.settings(); end %#ok<NASGU>
            [ses, found] = LabCapture.readSession(folder, name);
            if found || string(folder) == "" || ~isfolder(folder) || string(name) == ""
                return   % no folder of its own: the session is found when the record is sent
            end
            ses.session_id = LabBridge.newId();
            ses.created_at = LabBridge.now();
            try
                LabCapture.writeSession(folder, name, ses);
            catch
                ses.session_id = "";
            end
        end
    end

    methods (Static, Access = private)
        function writeSession(folder, name, ses)
            x = ses;
            x.raw = num2cell(ses.raw);
            x.phy_opened = num2cell(ses.phy_opened);
            c = cell(1, numel(ses.curations));
            for k = 1:numel(ses.curations)
                e = ses.curations(k);
                e.files = num2cell(rmfield(e.files, "step"));
                c{k} = e;
            end
            x.curations = c;
            writeJsonFile(LabCapture.sessionFile(folder, name), x);
        end

        function c = cells(v)
            %cells  A decoded JSON list (a struct array, a cell, [] or one struct) as a row cell of structs.
            if isempty(v); c = {}; return; end
            if isstruct(v); c = reshape(num2cell(v), 1, []); return; end
            if iscell(v); c = reshape(v(cellfun(@isstruct, v)), 1, []); return; end
            c = {};
        end

        function e = noOpened()
            e = struct("results_dir", {}, "at", {}, "person_id", {}, "person_email", {}, "os_user", {}, "host", {});
        end

        function e = noCurations()
            e = struct("event_id", {}, "sort_event_id", {}, "results_dir", {}, "saved", {}, "files", {});
        end

        function k = noKnown()
            k = struct("path", {}, "bytes", {}, "mtime", {}, "artifact_id", {}, "sha256", {}, "step", {}, "event_id", {});
        end

        function known = curatedOutputs(known, P, ses)
            %curatedOutputs  KNOWN, then the files of the curations of the sort record P.sorting (session file SES), oldest first.
            if ~isstruct(P) || ~isscalar(P) || ~isfield(P, "sorting") || ~isstruct(P.sorting) || ~isscalar(P.sorting) ...
                    || ~isfield(P.sorting, "event_id"); return; end
            sortId = string(P.sorting.event_id);
            for c = reshape(ses.curations, 1, [])
                if c.sort_event_id ~= sortId; continue; end
                known = [known, reshape(c.files, 1, [])]; %#ok<AGROW>
            end
        end

        function o = lastOpened(ses, d, upTo)
            %lastOpened  The last time phy was opened from the app on folder D, at or before UPTO (2 s allowed; [] when none).
            o = [];
            for k = numel(ses.phy_opened):-1:1
                e = ses.phy_opened(k);
                if EphysDataset.pathKey(e.results_dir) ~= EphysDataset.pathKey(d); continue; end
                try
                    at = datetime(e.at, "InputFormat", labclient.Bundles.TimeFormat, "TimeZone", "local");
                catch
                    continue
                end
                if at <= upTo + seconds(2); o = e; return; end   % a file's time may be kept to the second (or two)
            end
        end

        function tf = isId(v)
            tf = (ischar(v) || isstring(v)) && isscalar(string(v)) && ~isempty(regexp(char(v), ...
                '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$', 'once'));
        end

        function t = fieldText(r, f)
            t = "";
            if isfield(r, f); t = string(r.(f)); end
            if isempty(t); t = ""; end
        end

        function dt = zoned(dt, s)
            %zoned  DT with a time zone: an unzoned one is read in the lab's time zone.
            if isempty(dt.TimeZone); dt.TimeZone = s.LabTimeZone; end
        end

        function t = timeOrEmpty(dt, s)
            t = "";
            if isdatetime(dt) && isscalar(dt) && ~isnat(dt)
                t = LabBridge.timeText(LabCapture.zoned(dt, s));
            end
        end

        function out = ternary(c, a, b)
            if c; out = a; else; out = b; end
        end

        function files = recordFiles(kind, r)
            %recordFiles  The files a record names: its file, files, or the files of its results folder.
            files = strings(1, 0);
            if isfield(r, "files")
                files = reshape(string(r.files), 1, []);
            elseif isfield(r, "file")
                files = string(r.file);
            elseif isfield(r, "results_dir")
                d = dir(string(r.results_dir));
                d = d(~[d.isdir]);
                names = string({d.name});
                keep = ~ismember(names, LabCapture.SortingSkip) & ~endsWith(names, [".log" ".tmp" ".partial"]);
                files = string(fullfile(string(r.results_dir), names(keep)));
            end
            if kind == "behavior" && isfield(r, "extract_files")
                files = [files, reshape(string(r.extract_files), 1, [])];
            end
            files = files(files ~= "");
        end

        function [role, kind, attr] = roleOf(step, p, r)
            %roleOf  The artifact role, kind and attributes of output P of step STEP.
            [~, nm, ext] = fileparts(p);
            nm = string(nm); ext = lower(string(ext));
            attr = struct();
            role = "derived";
            switch step
                case "artifacts"
                    kind = "artifacts";
                case "bin"
                    kind = "bin";
                    attr.part = LabCapture.ternary(ext == ".bin", "data", "sidecar");
                case "sorting"
                    kind = "sorting";
                    attr.sorter = LabCapture.fieldText(r, "sorter");
                    if ismember(nm + ext, ["spike_times.npy" "spike_clusters.npy"])
                        role = "spikes";
                    elseif nm + ext == "templates.npy"
                        role = "waveforms";
                    end
                case "signals"
                    kind = "signals";
                    types = strings(1, 0);
                    t = regexp(char(nm), '_extract_(LFP|MUA|SPIKE|AUX)$', 'tokens', 'once');
                    if ~isempty(t)
                        types = string(t{1});
                    elseif isfield(r, "types")
                        types = reshape(string(r.types), 1, []);
                    end
                    attr.types = cellstr(types);
                    if any(types == "LFP"); role = "lfp"; end
                case "spikes"
                    kind = "threshold_spikes";
                    role = "spikes";
                case "behavior"
                    if endsWith(nm, "_behavior")
                        kind = "behavior";
                    else
                        kind = "signals";   % an extract file the behavior step added its events to
                        if isfield(r, "types") && any(string(r.types) == "LFP"); role = "lfp"; end
                    end
                case "nwb"
                    kind = "nwb";
                otherwise
                    kind = step;
            end
        end

        function files = defaultInputs(ds, kind, r)
            %defaultInputs  What step KIND read: the raw files, the artifact cache, the .bin, ...
            raw = strings(1, 0);
            if ds.Folder ~= "" && ~isempty(ds.Files)
                raw = reshape(string(fullfile(ds.Folder, ds.Files)), 1, []);
            end
            art = strings(1, 0);
            pa = ds.Processing.artifacts;
            if isstruct(pa) && isfield(pa, "file") && string(pa.file) ~= "" && isfile(string(pa.file))
                art = string(pa.file);
            end
            switch kind
                case "artifacts"
                    files = raw;
                case {"bin", "signals"}
                    files = [raw, art];
                case "sorting"
                    files = strings(1, 0);
                    if isfield(r, "bin_file"); files = string(r.bin_file); end
                case "spikes"
                    files = raw;
                case "behavior"
                    files = strings(1, 0);
                    if isfield(r, "source") && string(r.source) ~= ""
                        files = string(r.source);
                    else
                        files = raw;   % a TDT block's epocs
                    end
                case "nwb"
                    files = strings(1, 0);
                    if isfield(r, "sources") && isstruct(r.sources)
                        if isfield(r.sources, "extractFile")
                            files = strtrim(split(string(r.sources.extractFile), ";")).';
                        end
                        if isfield(r.sources, "sortingDir") && string(r.sources.sortingDir) ~= ""
                            files = [files, LabCapture.recordFiles("sorting", ...
                                struct("results_dir", string(r.sources.sortingDir)))];
                        end
                    end
                otherwise
                    files = strings(1, 0);
            end
            files = files(files ~= "");
        end

        function [role, kind] = inputRole(ds, p)
            if ~isempty(ds.Files) && ds.isRecordingFile(p)
                role = "raw"; kind = "raw";
            elseif endsWith(lower(p), ".mat") && ds.BehaviorFile ~= "" && ...
                    EphysDataset.pathKey(p) == EphysDataset.pathKey(ds.BehaviorFile)
                role = "raw"; kind = "epsych";
            else
                role = "derived"; kind = "";
            end
        end

        function known = knownOutputs(ds)
            %knownOutputs  Every output the dataset's records list, newest record last (DS: an EphysDataset or a processing block).
            %   Fields path, bytes, mtime, artifact_id, sha256, step (the
            %   record's kind) and event_id (the event that wrote it).
            known = struct("path", {}, "bytes", {}, "mtime", {}, "artifact_id", {}, "sha256", {}, ...
                "step", {}, "event_id", {});
            if isa(ds, "EphysDataset"); P = ds.Processing; else; P = ds; end
            if ~isstruct(P) || ~isscalar(P); return; end
            for k = string(fieldnames(P)).'
                r = P.(k);
                if ~isstruct(r) || ~isscalar(r) || ~isfield(r, "outputs"); continue; end
                o = r.outputs;
                if isstruct(o); o = num2cell(o); end
                if ~iscell(o); continue; end
                ev = "";
                if isfield(r, "event_id"); ev = string(r.event_id); end
                for j = 1:numel(o)
                    x = o{j};
                    if ~isstruct(x) || ~all(isfield(x, ["path" "bytes" "mtime" "artifact_id"])); continue; end
                    sha = "";
                    if isfield(x, "sha256"); sha = string(x.sha256); end
                    if isempty(sha); sha = ""; end
                    b = double(x.bytes); if isempty(b); b = NaN; end
                    known(end + 1) = struct("path", string(x.path), "bytes", b, ...
                        "mtime", string(x.mtime), "artifact_id", string(x.artifact_id), "sha256", sha, ...
                        "step", k, "event_id", ev); %#ok<AGROW>
                end
            end
            if isa(ds, "EphysDataset")
                known = LabCapture.curatedOutputs(known, P, LabCapture.readSession(ds.Folder, ds.Name));
            end
        end

        function [known, evs] = knownFiles(ds, folder, name)
            %knownFiles  The files the dataset's records name: its processing outputs and its session file's raw files.
            %   EVS: the session file's recording and behavior event ids.
            if isa(ds, "EphysDataset")
                known = LabCapture.knownOutputs(ds);
                folder = ds.Folder; name = ds.Name;
            else
                known = LabCapture.knownOutputs(ds);
            end
            [ses, found] = LabCapture.readSession(folder, name);
            evs = struct("recording", ses.recording_event_id, "behavior", ses.behavior_event_id);
            if ~found; return; end
            if ~isa(ds, "EphysDataset"); known = LabCapture.curatedOutputs(known, ds, ses); end
            for k = 1:numel(ses.raw)
                it = ses.raw(k);
                ev = ses.recording_event_id;
                step = "raw";
                if it.kind == "epsych"; ev = ses.behavior_event_id; step = "epsych"; end
                known(end + 1) = struct("path", it.path, "bytes", it.bytes, "mtime", it.mtime, ...
                    "artifact_id", it.artifact_id, "sha256", it.sha256, "step", step, "event_id", ev); %#ok<AGROW>
            end
        end

        function [role, kind, attr] = roleOfKnown(k, ~)
            %roleOfKnown  The role, kind and attributes of a copy of known file K.
            switch k.step
                case "raw";    role = "raw"; kind = "raw";    attr = struct();
                case "epsych"; role = "raw"; kind = "epsych"; attr = struct();
                otherwise
                    [role, kind, attr] = LabCapture.roleOf(k.step, k.path, struct());
            end
        end

        function v = outputLedger(p, value)
            %outputLedger  The last analysis outputs recorded here at paths P ("<artifact id> <sha256>" each, "" when none); with VALUE, note them.
            %   V = LabCapture.outputLedger(P) reads the ledger once for
            %   every path of P (a string row); V is a row of the same size.
            %   LabCapture.outputLedger(P, VALUE) notes VALUE(k) for P(k),
            %   all in one write: the ledger is read again just before it
            %   (another MATLAB on this computer may have noted outputs
            %   since) and written once (writeJsonFile: atomic). There is no
            %   lock: two MATLABs that write it within the same moment keep
            %   one's entries, and the other's next run at those paths
            %   records new files without "replaces"; the records already in
            %   the outbox are not affected.
            %   Kept in <labclient.DB.folder()>/analysis_outputs.json, one
            %   entry per path (the latest), so a run after a restart still
            %   knows the file it replaces. Nothing is pruned: an entry is
            %   what the next run that writes its path needs, and a file
            %   that is not there now (deleted, or on a share that is not
            %   mounted) may be written again. A ledger that is there but
            %   cannot be read is left as it is, and nothing is noted
            %   (warning LabCapture:OutputLedger): written over, it would
            %   lose every entry in it.
            f = fullfile(labclient.DB.folder(), "analysis_outputs.json");
            keys = EphysDataset.pathKey(reshape(string(p), 1, []));
            [E, have, readable] = LabCapture.readOutputLedger(f);
            if nargin < 2
                v = strings(1, numel(keys));
                [hit, at] = ismember(keys, have);
                for j = find(hit); v(j) = string(E{at(j)}.value); end
                return
            end
            v = reshape(string(value), 1, []);
            if ~readable
                warning("LabCapture:OutputLedger", "%s cannot be read, so this run's outputs are not noted in it; " + ...
                    "it is left as it is (delete it to start a new one).", f);
                return
            end
            for j = 1:numel(keys)
                e = struct("path", keys(j), "value", v(j));
                k = find(have == keys(j), 1);
                if isempty(k)
                    E{end + 1} = e; %#ok<AGROW>
                    have(end + 1) = keys(j); %#ok<AGROW>
                else
                    E{k} = e;
                end
            end
            writeJsonFile(f, struct("format", "ephys-labdb-outputs/1", "entries", {E}));
        end

        function [E, keys, readable] = readOutputLedger(f)
            %readOutputLedger  The output ledger F's entries (a row cell of structs path, value) and their paths.
            %   READABLE is false when F is there but is no ledger (not JSON,
            %   or no entries); E is then empty.
            E = {};
            keys = strings(1, 0);
            readable = true;
            if ~isfile(f); return; end
            y = readJsonFile(f, ErrorOnFail=false);
            if ~isstruct(y) || ~isscalar(y) || ~isfield(y, "entries")
                readable = false;
                return
            end
            E = LabCapture.cells(y.entries);
            E = E(cellfun(@(e) isfield(e, "path") && isfield(e, "value"), E));
            keys = strings(1, numel(E));
            for k = 1:numel(E); keys(k) = string(E{k}.path); end
        end

        function v = ledger(key, value)
            %ledger  What this MATLAB noted under KEY ("" when nothing); with VALUE, note it.
            persistent m
            if isempty(m); m = containers.Map('KeyType', 'char', 'ValueType', 'char'); end
            key = char(key);
            if nargin > 1
                m(key) = char(value);
                v = string(value);
                return
            end
            v = "";
            if isKey(m, key); v = string(m(key)); end
        end

        function rel = datasetRel(p, folder)
            %datasetRel  P's path inside the dataset's output folder FOLDER, "/" between folders ("" when it is not in it).
            %   Kept as attributes.dataset_rel, so the folder that holds a
            %   dataset's outputs is known from a file's row exactly
            %   (LabLocator), never guessed from its path.
            rel = "";
            if folder == "" || p == ""; return; end
            kp = EphysProject.normalizeKey(p);
            kf = EphysProject.normalizeKey(folder) + "/";
            if ispc; hit = startsWith(lower(kp), lower(kf)); else; hit = startsWith(kp, kf); end
            if hit; rel = extractAfter(kp, strlength(kf)); end
        end

        function rel = carriedRel(rel, p)
            %carriedRel  REL for P, a copy of a file at REL in its dataset's folder: when P ends in REL, else "".
            if rel == ""; return; end
            kp = EphysProject.normalizeKey(p);
            if ispc; hit = endsWith(lower(kp), "/" + lower(rel)); else; hit = endsWith(kp, "/" + rel); end
            if ~hit; rel = ""; end
        end

        function f = outputFolderOf(ds)
            %outputFolderOf  The dataset's output folder ("" when it has none).
            f = "";
            try
                f = string(ds.outputFolder());
            catch
            end
        end

        function k = findKnown(known, p)
            k = 0;
            if isempty(known); return; end
            key = EphysDataset.pathKey(p);
            hit = find(EphysDataset.pathKey(string({known.path})) == key, 1, "last");
            if ~isempty(hit); k = hit; end
        end

        function items = locate(items, s)
            for k = 1:numel(items)
                [root, rel] = labclient.Roots.locate(items(k).path, s);
                items(k).root = root;
                items(k).rel = rel;
            end
        end

        function items = hashSmall(items, s)
            limit = labclient.Hasher.limitBytes(s);
            for k = 1:numel(items)
                if strlength(items(k).sha256) == 64 || items(k).bytes > limit; continue; end
                h = labclient.Hasher.hashNow(items(k));   % "" when it changed meanwhile: left to labclient.Hasher.work
                items(k).sha256 = h;
            end
        end

        function startLarge(b, s)
            %startLarge  Start hashing the outputs of B too large to hash here.
            o = b.record.outputs;
            limit = labclient.Hasher.limitBytes(s);
            for k = 1:numel(o)
                if strlength(o(k).sha256) == 64 || o(k).bytes <= limit; continue; end
                try
                    labclient.Hasher.start(o(k), b.bundle_id + "_" + k);
                catch ME
                    warning("LabCapture:Hash", "Could not start hashing %s: %s", o(k).path, ME.message);
                end
            end
        end

        function o = recordOutputs(items)
            %recordOutputs  The outputs as the processing record keeps them.
            o = cell(1, numel(items));
            for k = 1:numel(items)
                o{k} = struct("path", items(k).path, "bytes", items(k).bytes, "mtime", items(k).mtime, ...
                    "artifact_id", items(k).artifact_id, "sha256", items(k).sha256);
            end
        end

        function d = datasetBlock(ds, ses, s)
            id = EphysDataset.nameIdentity(ds.Name, ds.NamePattern);
            d = struct("name", ds.Name, "folder", ds.Folder, "session_id", ses.session_id, ...
                "subject_folder_id", id.subject, ...
                "recording_start", LabCapture.timeOrEmpty(id.recordingStart, s), "tool", LabBridge.Tool);
        end

        function n = pipelineName(kind, r)
            if kind == "sorting"
                so = LabCapture.fieldText(r, "sorter");
                if so == "" || so == "kilosort4"
                    n = "kilosort4";
                else
                    n = "spikeinterface/" + so;
                end
            else
                n = "ephys_analysis/" + kind;
            end
        end

        function c = acquisitionSystem(reader)
            switch reader
                case "intan";     c = "intan_rhx";
                case "openephys"; c = "open_ephys";
                case "tdt";       c = "tdt_synapse";
                otherwise;        c = "";
            end
        end
    end
end
