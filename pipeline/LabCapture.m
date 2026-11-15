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
    %   and, when the lab database is turned on here (LabDBSettings.Enabled),
    %   writes a bundle for it to the outbox (LabOutbox): the event, the files
    %   it read (inputs, with their ids when this computer knows them) and the
    %   files it wrote, each as storage root and path (LabRoots). Small files
    %   are hashed at once, large ones out of process (LabHasher). Nothing is
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
    %   See also EphysDataset.setProcessing, LabOutbox, LabBundles, LabHasher, LabRoots.

    properties (Constant)
        SessionFormat = "ephys-labdb-session/1"
        % files of a sort's results folder that are no results
        SortingSkip = ["ks4_status.json" "ks4_exit.txt" "sorting_record.json" "ks4_launch.cmd" ...
            "si_launch.cmd" "settings.json"]
    end

    methods (Static)
        function tf = enabled(s)
            %enabled  True when records are to be kept for the lab database on this computer.
            if nargin < 1; s = LabDBSettings.load(); end
            tf = s.Enabled;
        end

        function p = performer(s)
            %performer  Who is doing the work here: person_id, person_email (as set up), os_user, host.
            if nargin < 1; s = LabDBSettings.load(); end
            p = struct("person_id", s.PersonId, "person_email", s.PersonEmail, ...
                "os_user", LabBundles.osUser(), "host", LabBundles.host());
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
            r.event_id = LabBundles.newId();
            r.started_at = LabBundles.now();
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
            s = LabDBSettings.load();
            on = LabCapture.enabled(s);
            if ~isfield(r, "event_id") || ~LabCapture.isId(r.event_id)
                r.event_id = LabBundles.newId();
            end
            r.created_at = LabBundles.timeText(opts.FinishedAt);
            if ~isfield(r, "started_at") || string(r.started_at) == ""
                r.started_at = "";
                if ~isnat(opts.StartedAt); r.started_at = LabBundles.timeText(LabCapture.zoned(opts.StartedAt, s)); end
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
            items = LabBundles.noItems();
            for p = outPaths
                [role, kd, attr] = LabCapture.roleOf(kind, p, r);
                rel = LabCapture.datasetRel(p, outDir);
                if rel ~= ""; attr.dataset_rel = rel; end
                it = LabBundles.item(p, Role=role, Kind=kd, Attributes=attr);
                if isnan(it.bytes); continue; end   % listed but not written: nothing to record
                k = LabCapture.findKnown(known, p);
                if k > 0 && LabBundles.sameSnapshot(known(k), it)
                    it.artifact_id = known(k).artifact_id;   % this step left the file as it was
                    it.sha256 = known(k).sha256;
                else
                    it.artifact_id = LabBundles.newId();
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
            ins = LabBundles.noItems();
            for p = inPaths
                [role, kd] = LabCapture.inputRole(ds, p);
                it = LabBundles.item(p, Role=role, Kind=kd);
                k = LabCapture.findKnown(known, p);
                if k > 0 && LabBundles.sameSnapshot(known(k), it)
                    it.artifact_id = known(k).artifact_id;
                    it.sha256 = known(k).sha256;
                else
                    k = LabCapture.findKnown(ses.raw, p);
                    if k > 0 && LabBundles.sameSnapshot(ses.raw(k), it)
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
            b = LabBundles.event(EventId=string(r.event_id), EventType="analysis", ...
                OccurredAt=occurred, Detail=detail, Attributes=attr, ...
                Performer=r.performer, Dataset=LabCapture.datasetBlock(ds, ses, s), ...
                Inputs=ins, Outputs=items, CapturedBy=LabBundles.capturedBy(s));
            b = LabBundles.seal(b);
            LabOutbox.put(b);
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
            s = LabDBSettings.load();
            if ~LabCapture.enabled(s); return; end
            finished = datetime("now", "TimeZone", "local");
            started = finished - seconds(max(0, opts.Seconds));
            ins = LabBundles.noItems();
            for p = unique(LabCapture.defaultInputs(ds, kind, struct()), "stable")
                [role, kd] = LabCapture.inputRole(ds, p);
                ins(end + 1) = LabBundles.item(p, Role=role, Kind=kd); %#ok<AGROW>
            end
            known = LabCapture.knownOutputs(ds);
            ses = LabCapture.session(ds.Folder, ds.Name, s);
            for k = 1:numel(ins)
                j = LabCapture.findKnown(known, ins(k).path);
                if j > 0 && LabBundles.sameSnapshot(known(j), ins(k))
                    ins(k).artifact_id = known(j).artifact_id;
                    ins(k).sha256 = known(j).sha256;
                else
                    j = LabCapture.findKnown(ses.raw, ins(k).path);
                    if j > 0 && LabBundles.sameSnapshot(ses.raw(j), ins(k))
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
                "started_at", LabBundles.timeText(started), "finished_at", LabBundles.timeText(finished), ...
                "status", "failed");
            attr = struct("step", kind, "dataset", ds.Name, "run_id", opts.RunId, ...
                "outcome", opts.Outcome, "error", opts.Message);
            perf = LabCapture.performer(s);
            b = LabBundles.event(EventId=LabBundles.newId(), EventType="analysis", ...
                OccurredAt=LabBundles.timeText(started), Detail=detail, Attributes=attr, ...
                Performer=perf, Dataset=LabCapture.datasetBlock(ds, ses, s), Inputs=ins, ...
                CapturedBy=LabBundles.capturedBy(s));
            LabOutbox.put(LabBundles.seal(b));
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
            s = LabDBSettings.load();
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
                "recording_start", LabCapture.timeOrEmpty(info.recording_time, s));
            files = info.files;
            raw = LabBundles.noItems();
            ep = LabBundles.noItems();
            for k = 1:numel(files)
                p = string(files(k).path);
                if files(k).is_epsych
                    it = LabBundles.item(p, Role="raw", Kind="epsych", ArtifactId=LabBundles.newId(), ...
                        Sha256=string(files(k).sha256));
                    if ~isnan(it.bytes); ep(end + 1) = it; end %#ok<AGROW>
                else
                    it = LabBundles.item(p, Role="raw", Kind="raw", ArtifactId=LabBundles.newId(), ...
                        Sha256=string(files(k).sha256), Attributes=struct("reader", string(info.reader)));
                    if ~isnan(it.bytes); raw(end + 1) = it; end %#ok<AGROW>
                end
            end
            raw = LabCapture.hashSmall(LabCapture.locate(raw, s), s);
            ep = LabCapture.hashSmall(LabCapture.locate(ep, s), s);

            recId = LabBundles.newId();
            detail = struct();
            sys = LabCapture.acquisitionSystem(string(info.reader));
            if sys ~= ""; detail.acquisition_system_code = sys; end
            if isfinite(info.recording_duration); detail.duration_s = double(info.recording_duration); end
            occurred = LabCapture.timeOrEmpty(info.recording_time, s);
            if occurred == ""; occurred = LabBundles.timeText(info.finished); end
            attr = struct("copied_from", string(info.source_dir), "captured_by_tool", "copySessions", ...
                "code_version", ver, "occurred_at_source", ...
                LabCapture.ternary(LabCapture.timeOrEmpty(info.recording_time, s) == "", ...
                "copy finished (no recording time known)", "recording folder name"));
            b = LabBundles.event(EventId=recId, EventType="recording", OccurredAt=occurred, ...
                Detail=detail, Attributes=attr, Performer=perf, Dataset=dsb, Outputs=raw, ...
                CapturedBy=LabBundles.capturedBy(s));
            b = LabBundles.seal(b);
            LabOutbox.put(b);
            LabCapture.startLarge(b, s);
            ses.recording_event_id = recId;
            ses.raw = raw;

            if ~isempty(ep)
                behId = LabBundles.newId();
                bd = struct();
                if isfinite(info.epsych_trials); bd.trials_completed = double(info.epsych_trials); end
                occ = LabCapture.timeOrEmpty(info.epsych_time, s);
                if occ == ""; occ = occurred; end
                b2 = LabBundles.event(EventId=behId, EventType="behavior", OccurredAt=occ, ...
                    Detail=bd, Attributes=struct("captured_by_tool", "copySessions", "code_version", ver), ...
                    Performer=perf, Dataset=dsb, Outputs=ep, CapturedBy=LabBundles.capturedBy(s), ...
                    After=recId);
                b2 = LabBundles.seal(b2);
                LabOutbox.put(b2);
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
                "raw", LabBundles.noItems(), "phy_opened", LabCapture.noOpened(), ...
                "curations", LabCapture.noCurations());
            found = false;
            if string(folder) == "" || string(name) == ""; return; end
            f = LabCapture.sessionFile(folder, name);
            if ~isfile(f); return; end
            x = readJsonFile(f, ErrorOnFail=false);
            if ~(isstruct(x) && isfield(x, "session_id") && LabCapture.isId(x.session_id)); return; end
            ses.session_id = lower(string(x.session_id));
            for k = ["created_at" "subject_id" "recording_event_id" "behavior_event_id"]
                if isfield(x, k) && ~isempty(x.(k)); ses.(k) = string(x.(k)); end
            end
            if isfield(x, "raw")
                ses.raw = LabBundles.toItems(x.raw);
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

        function phyOpened(ds, resultsDir)
            %phyOpened  Note in dataset DS's session file that phy was opened on RESULTSDIR from the app, by whom.
            %   The person, login and computer, and when. LabCapture.curation
            %   names them as who opened phy when it records what phy saved
            %   there. Nothing when the database is off here.
            s = LabDBSettings.load();
            if ~LabCapture.enabled(s); return; end
            ses = LabCapture.session(ds.Folder, ds.Name, s);
            if ses.session_id == ""; return; end
            p = LabCapture.performer(s);
            e = LabCapture.noOpened();
            e(1).results_dir = string(resultsDir);
            e(1).at = LabBundles.now();
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
            s = LabDBSettings.load();
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
                if k > 0 && LabBundles.sameSnapshot(known(k), LabBundles.snapshot(p)); continue; end
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
            items = LabBundles.noItems();
            for p = changed
                [role, kd, attr] = LabCapture.roleOf("sorting", p, r);
                rel = LabCapture.datasetRel(p, outDir);
                if rel ~= ""; attr.dataset_rel = rel; end
                attr.curated_in = "phy";
                it = LabBundles.item(p, Role=role, Kind=kd, Attributes=attr);
                if isnan(it.bytes); continue; end
                it.artifact_id = LabBundles.newId();
                k = LabCapture.findKnown(known, p);
                if k > 0; it.replaces = known(k).artifact_id; end
                items(end + 1) = it; %#ok<AGROW>
            end
            items = LabCapture.locate(items, s);
            items = LabCapture.hashSmall(items, s);
            files = LabCapture.noKnown();
            keep = true(1, numel(items));
            id = LabBundles.newId();
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
                "saved", LabBundles.timeText(saved), "files", files);
            outputs = items(keep);
            if isempty(outputs)
                id = "";
            else
                entry.event_id = id;
                ins = LabBundles.noItems();
                seen = strings(1, 0);
                for k = numel(known):-1:1   % each file's latest version, as recorded
                    key = EphysDataset.pathKey(known(k).path);
                    if any(seen == key); continue; end
                    seen(end + 1) = key; %#ok<AGROW>
                    [role, kd] = LabCapture.roleOf("sorting", known(k).path, r);
                    it = LabBundles.item(known(k).path, Role=role, Kind=kd, ...
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
                    "environment_json", "{}", "started_at", started, "finished_at", LabBundles.timeText(saved), ...
                    "status", "succeeded");
                occurred = started;
                if occurred == ""; occurred = LabBundles.timeText(saved); end
                attr = struct("step", "curation", "tool", "phy", "dataset", ds.Name, "results_dir", d, ...
                    "sort_event_id", string(r.event_id), "opened_by", opened, ...
                    "phy_labels", {cellstr(st.labels)}, "phy_label_counts", st.counts, "phy_clusters", st.clusters);
                b = LabBundles.event(EventId=id, EventType="analysis", OccurredAt=occurred, Detail=detail, ...
                    Attributes=attr, Performer=LabCapture.performer(s), Dataset=LabCapture.datasetBlock(ds, ses, s), ...
                    Inputs=ins, Outputs=outputs, CapturedBy=LabBundles.capturedBy(s));
                b = LabBundles.seal(b);
            end
            % The session file first: a curation it does not keep would be
            % captured again at the next look, a second event for one save.
            before = ses;
            ses.curations(end + 1) = entry;
            LabCapture.writeSession(ds.Folder, ds.Name, ses);
            if isempty(outputs); return; end
            try
                LabOutbox.put(b);
            catch ME
                LabCapture.writeSession(ds.Folder, ds.Name, before);   % not captured: looked for again next time
                rethrow(ME);
            end
            LabCapture.startLarge(b, s);
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
            s = LabDBSettings.load();
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
                    if j == 0 || ~LabBundles.sameSnapshot(known(j), LabBundles.snapshot(src))
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
                    it = LabBundles.item(copy, Role=role, Kind=kd, Attributes=attr, ArtifactId=LabBundles.newId(), ...
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
                    fb = LabBundles.files(EventId=groups(g).event, Artifacts=items, After=groups(g).event, ...
                        Attributes=struct("tool", "OutputTransfer", "method", X.Method, "dataset", ds.Name, ...
                        "untracked_files", untracked), CapturedBy=LabBundles.capturedBy(s));
                    LabOutbox.put(fb);
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
                    d = LabBundles.disposition(srcId, "moved", Successor=copyId, ...
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
                    fb = LabBundles.files(EventId=D(g).event, Dispositions=D(g).rows, After=before, ...
                        Attributes=struct("tool", "OutputTransfer", "method", "move", "dataset", ds.Name), ...
                        CapturedBy=LabBundles.capturedBy(s));
                    LabOutbox.put(fb);
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
            s = LabDBSettings.load();
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
                    it = LabBundles.noItems();
                    if method == "move"
                        [role, kd, attr] = LabCapture.roleOfKnown(known(j), evs);
                        attr.copied_from = known(j).artifact_id;
                        attr.copied_from_path = Rf.File(k);
                        attr.copied_from_sha256 = known(j).sha256;
                        attr.overwrote = isequal(Rf.Replaced(k), true);
                        attr.tool = "runLocalCleanup";
                        it = LabBundles.item(string(Rf.To(k)), Role=role, Kind=kd, Attributes=attr, ...
                            ArtifactId=LabBundles.newId());
                        d = LabBundles.disposition(known(j).artifact_id, "moved", Successor=it.artifact_id, ...
                            Attributes=struct("method", "move", "tool", "runLocalCleanup", "to", string(Rf.To(k))));
                    else
                        d = LabBundles.disposition(known(j).artifact_id, "deleted", ...
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
                    fb = LabBundles.files(EventId=groups(g).event, Artifacts=items, Dispositions=groups(g).rows, ...
                        After=groups(g).event, Attributes=struct("tool", "runLocalCleanup", "method", method, ...
                        "dataset", name), CapturedBy=LabBundles.capturedBy(s));
                    LabOutbox.put(fb);
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
            %   the folder's own is meant; SubjectAssignDialog),
            %   recording_event_id, behavior_event_id, raw (the raw files as
            %   captured, LabBundles items). A folder that cannot be written
            %   gives session_id "" (resolved when sent).
            if nargin < 3; s = LabDBSettings.load(); end %#ok<NASGU>
            [ses, found] = LabCapture.readSession(folder, name);
            if found || string(folder) == "" || ~isfolder(folder) || string(name) == ""
                return   % no folder of its own: the session is found when the record is sent
            end
            ses.session_id = LabBundles.newId();
            ses.created_at = LabBundles.now();
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
                    at = datetime(e.at, "InputFormat", LabBundles.TimeFormat, "TimeZone", "local");
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
                t = LabBundles.timeText(LabCapture.zoned(dt, s));
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
                [root, rel] = LabRoots.locate(items(k).path, s);
                items(k).root = root;
                items(k).rel = rel;
            end
        end

        function items = hashSmall(items, s)
            limit = LabHasher.limitBytes(s);
            for k = 1:numel(items)
                if strlength(items(k).sha256) == 64 || items(k).bytes > limit; continue; end
                h = LabHasher.hashNow(items(k));   % "" when it changed meanwhile: left to LabHasher.work
                items(k).sha256 = h;
            end
        end

        function startLarge(b, s)
            %startLarge  Start hashing the outputs of B too large to hash here.
            o = b.record.outputs;
            limit = LabHasher.limitBytes(s);
            for k = 1:numel(o)
                if strlength(o(k).sha256) == 64 || o(k).bytes <= limit; continue; end
                try
                    LabHasher.start(o(k), b.bundle_id + "_" + k);
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
                "recording_start", LabCapture.timeOrEmpty(id.recordingStart, s));
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
