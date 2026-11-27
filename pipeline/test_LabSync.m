classdef test_LabSync < matlab.unittest.TestCase
    %test_LabSync  Sending the outbox to the lab database (labclient.Sync), against the in-memory fake.
    %   Everything runs in a temporary preference store, a fake password
    %   vault, a temporary database folder and labclient.FakeBackend; no timer
    %   runs (labclient.Sync.useManual): the tests send by hand.
    %
    %   Covered: a step sent once (its session created in the folder's root,
    %   its file registered with its SHA-256, the person named, inputs this
    %   computer cannot name listed, not guessed), sent again is "existing";
    %   a commit whose answer was lost; the same id with other content held
    %   as a conflict; a subject the database does not have holds the record
    %   until it is assigned (labclient.SubjectAssignDialog: an existing subject, or a
    %   new one); a record of another login held until "Send as me"; a copied
    %   session sent before the step that read its files, and inputs sent
    %   later as an edges record; an unreachable server costs no wait and
    %   leaves the outbox as it was; no sending while suspended; a failed step
    %   recorded as failed; a run of figures (LabCapture.analysisRun): its
    %   inputs, outputs and replaced reports, the config it started with; a
    %   run that throws (EphysAnalysisRunner.run: its run record and its
    %   record failed, with the error, the Log saying what was noted or which
    %   folder is under no mapped root), a run that drew no figure because
    %   each failed recorded as failed, a LogFcn that throws as the run ends
    %   (a warning: the run's error still thrown, a finished run not
    %   failed), kept figure files (Export.Overwrite
    %   off) left out of its outputs, the output ledger written
    %   once per run and never written over when it cannot be read; a
    %   discarded record kept, never sent; where a
    %   dataset's records stand (labclient.Sync.datasetText, the Review tab's
    %   Database column) and the manifest viewer's Database tab (the steps
    %   and files here and in the database, a file's lineage); a move
    %   (OutputTransfer): its copy registered under the step's event before
    %   the source may go, then the source recorded as moved; a copy that is
    %   not its source's bytes held; a clean-up's deletion recorded; finding
    %   recordings through the database (LabLocator: where a session and its
    %   outputs are here, the filters, the last answer while offline) and
    %   picking them (LabLocatorDialog).
    %
    %   Usage:  runtests("test_LabSync")

    properties (Access = private)
        Fake
        Restore = {}
        Top = ""
    end

    methods (TestMethodSetup)
        function isolate(tc)
            tc.Restore = {AppPrefs.useTemporary(), labclient.Secrets.useFake(), labclient.DB.useTemporary(), ...
                labclient.Sync.useManual()};
            tc.Fake = labclient.FakeBackend();
            tc.Fake.Roots = table(1, "nas", "the lab's NAS", 'VariableNames', {'root_id', 'name', 'description'});
            tc.Fake.Subjects = table(["SYNTH-01"; "SYNTH-1"; "G-0421"], ["P1"; "P1"; "P1"], ...
                ["mus_musculus"; "mus_musculus"; "meriones_unguiculatus"], ["F"; "M"; "U"], ...
                'VariableNames', {'subject_id', 'project_id', 'species_code', 'sex'});
            fake = tc.Fake;
            tc.Restore{end + 1} = labclient.DB.useBackend(@() fake);
            tc.Top = string(tempname);
            mkdir(tc.Top);
            s = labclient.Settings.defaults();
            s.Enabled = true;
            s.Server = "labdb.test";
            s.Username = "jdoe";
            s.Roots = struct("Name", "nas", "Path", tc.Top);
            labclient.Settings.save(s);
            labclient.Secrets.setFake(labclient.Settings.load(), fake.Password);
            tc.addTeardown(@() tc.cleanUp());
        end
    end

    methods (Access = private)
        function cleanUp(tc)
            for k = numel(tc.Restore):-1:1
                tc.Restore{k} = [];
            end
            if isfolder(tc.Top); rmdir(tc.Top, "s"); end
        end

        function writeBytes(~, f, bytes)
            fid = fopen(f, "w");
            fwrite(fid, bytes, "uint8");
            fclose(fid);
        end

        function ds = dataset(tc, subject)
            if nargin < 2; subject = "SYNTH-01"; end
            folder = string(fullfile(tc.Top, subject, subject + "_260702_141210"));
            R = makeSyntheticRecording(folder, Subject=subject, Format="one-file-per-signal", ...
                NumChannels=2, NumTrials=4, Fs=2000, SortedOutput=false, Artifacts=false, WriteManifest=false);
            if isfile(R.behaviorFile); delete(R.behaviorFile); end
            ds = EphysDataset(folder);
        end

        function id = captureStep(tc, ds, bytes)
            if nargin < 3; bytes = uint8(1:64); end
            f = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            tc.writeBytes(f, bytes);
            r = EphysDataset.processingRecord("file", f, struct("runId", "run1"), struct("A", 1));
            ds.setProcessing("spikes", r, StartedAt=datetime("now", "TimeZone", "local") - seconds(3));
            id = ds.Processing.spikes.event_id;
        end

        function n = events(tc)
            n = numel(tc.Fake.Events);
        end
    end

    methods (Test)
        function aStepIsSentOnce(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            r = labclient.Sync.flush(Budget=10);
            tc.verifyEqual(r.sent, 1, r.message);
            [~, st] = labclient.Outbox.read(id);
            tc.verifyEqual(st, "done");
            e = tc.Fake.Events(1);
            tc.verifyEqual(e.event_id, id);
            tc.verifyEqual(e.recorded_by, tc.Fake.PersonId, "the person is named, not left to the login");
            tc.verifyEqual(e.detail.status, "succeeded");
            S = tc.Fake.Sessions;
            tc.verifyEqual(height(S), 1);
            tc.verifyEqual(S.session_id, LabCapture.readSession(ds.Folder, ds.Name).session_id, ...
                "the session under the id of its session file");
            tc.verifyEqual([S.subject_id, S.label, S.relative_path], ...
                ["SYNTH-01", ds.Name, "SYNTH-01/" + ds.Name]);
            A = tc.Fake.Artifacts;
            tc.verifyEqual(A.checksum, labclient.fileSha256(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat")));
            tc.verifyEqual(A.produced_by_event_id, id);
            a = jsondecode(char(e.attributes));
            tc.verifyEqual(numel(a.unresolved_inputs), numel(ds.Files), ...
                "raw files this computer cannot name are listed, not guessed");
            tc.verifyEmpty(tc.Fake.Inputs);

            labclient.Outbox.move(id, "pending");   % sent again
            tc.verifyEqual(labclient.Sync.flush(Budget=10).sent, 1);
            tc.verifyEqual(tc.events(), 1, "the same record twice: written once");
            tc.verifySubstring(labclient.Outbox.note(id, "done").reason, "already in the database");
        end

        function aCommitWhoseAnswerWasLost(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            tc.Fake.Fail = struct("Method", "recordEvent", "Identifier", "CarasLabDB:transactionInterrupted", ...
                "Message", "the connection was reset", "AfterWrite", true);
            b = labclient.DB.connect(Force=true);
            r = labclient.Sync.sendNext(b);
            tc.verifyEqual(r.outcome, "pending", "a broken connection: it waits");
            tc.verifyEqual(labclient.DB.status().State, "offline");
            tc.verifyEqual(tc.events(), 1, "the commit went through");
            b = labclient.DB.connect(Force=true);
            r = labclient.Sync.sendNext(b);
            tc.verifyEqual(r.outcome, "done");
            tc.verifySubstring(r.reason, "already in the database");
            tc.verifyEqual(tc.events(), 1);
            [~, st] = labclient.Outbox.read(id);
            tc.verifyEqual(st, "done");
        end

        function sameIdOtherContentIsAConflict(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            labclient.Sync.flush(Budget=10);
            labclient.Outbox.move(id, "pending");
            b = labclient.Outbox.read(id);
            b.record.event.notes = "changed after it was sent";
            labclient.Outbox.update(labclient.Bundles.seal(b));
            labclient.Sync.flush(Budget=10);
            [~, st] = labclient.Outbox.read(id);
            tc.verifyEqual(st, "held");
            tc.verifySubstring(labclient.Outbox.note(id, "held").reason, "Conflict");
            tc.verifyEqual(tc.events(), 1, "nothing written");
        end

        function aSubjectToAssign(tc)
            ds = tc.dataset("SYNTH-O1");   % a letter O for a zero
            id = tc.captureStep(ds);
            labclient.Sync.flush(Budget=10);
            [~, st] = labclient.Outbox.read(id);
            tc.verifyEqual(st, "held");
            tc.verifySubstring(labclient.Outbox.note(id, "held").reason, "SYNTH-O1 is not in the database");
            T = labclient.Sync.subjectHolds();
            tc.verifyEqual(T.folder_id, "SYNTH-O1");
            tc.verifyEmpty(tc.Fake.Sessions, "no session for a subject that is not there");

            dlg = labclient.SubjectAssignDialog.open(FolderId="SYNTH-O1", Visible=false);
            tc.addTeardown(@() dlg.cancel());
            items = string(dlg.Ctl.List.Items);
            tc.verifyEqual(items(1), "SYNTH-01", "the nearest subject first");
            dlg.pick("SYNTH-01");
            dlg.ok();
            tc.verifyEqual(dlg.Result, "SYNTH-01");
            tc.verifyEqual(LabCapture.readSession(ds.Folder, ds.Name).subject_id, "SYNTH-01", ...
                "noted in the session file; the folder keeps its name");
            tc.verifyTrue(isfolder(ds.Folder));
            [~, st] = labclient.Outbox.read(id);
            tc.verifyEqual(st, "pending", "released");
            labclient.Sync.flush(Budget=10);
            tc.verifyEqual(tc.Fake.Sessions.subject_id, "SYNTH-01");
            tc.verifyEqual(tc.events(), 1);
        end

        function aNewSubject(tc)
            ds = tc.dataset("NEW-7");
            id = tc.captureStep(ds);
            labclient.Sync.flush(Budget=10);
            dlg = labclient.SubjectAssignDialog.open(FolderId="NEW-7", Visible=false);
            tc.addTeardown(@() dlg.cancel());
            dlg.choose("create");
            dlg.Ctl.Sex.Value = 'F';
            dlg.ok();
            tc.verifyTrue(any(tc.Fake.Subjects.subject_id == "NEW-7"), "created in the database");
            tc.verifyEqual(tc.Fake.Subjects.sex(tc.Fake.Subjects.subject_id == "NEW-7"), "F");
            labclient.Sync.flush(Budget=10);
            [~, st] = labclient.Outbox.read(id);
            tc.verifyEqual(st, "done");
        end

        function anotherLoginWaitsForSendAsMe(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            b = labclient.Outbox.read(id);
            b.captured_by.db_username = "asmith";
            labclient.Outbox.update(b);   % the envelope, not the record: the digest stays
            labclient.Sync.flush(Budget=10);
            [~, st] = labclient.Outbox.read(id);
            tc.verifyEqual(st, "held");
            tc.verifySubstring(labclient.Outbox.note(id, "held").reason, "asmith");
            p = labclient.Panel.open(Visible=false);
            tc.addTeardown(@() p.close());
            p.release(id, OnBehalf=true);
            labclient.Sync.flush(Budget=10);
            [~, st] = labclient.Outbox.read(id);
            tc.verifyEqual(st, "done");
            a = jsondecode(char(tc.Fake.Events(1).attributes));
            tc.verifyEqual(string(a.sent_on_behalf_of), "asmith");
        end

        function aCopiedSessionAndTheStepThatReadIt(tc)
            ds = tc.dataset();
            files = struct("path", cellstr(fullfile(ds.Folder, ds.Files)), "sha256", "", "is_epsych", false);
            info = struct("dest", ds.Folder, "subject", "SYNTH-01", "reader", "intan", ...
                "recording_time", datetime(2026, 7, 2, 14, 12, 10), "recording_duration", 30, ...
                "source_dir", "D:\rig", "files", files, "epsych_file", "", "epsych_time", NaT, ...
                "epsych_trials", NaN, "finished", datetime("now", "TimeZone", "local"));
            LabCapture.copiedSession(info);
            ses = LabCapture.readSession(ds.Folder, ds.Name);
            labclient.Hasher.work();
            step = tc.captureStep(ds);
            b = labclient.Outbox.read(step);
            tc.verifyTrue(all([b.record.inputs.artifact_id] ~= ""), "the raw files' ids, from the session file");

            % The step goes first (the recording is held): its inputs wait.
            labclient.Outbox.move(ses.recording_event_id, "held");
            labclient.Sync.flush(Budget=10);
            [~, st] = labclient.Outbox.read(step);
            tc.verifyEqual(st, "done");
            tc.verifySubstring(labclient.Outbox.note(step, "done").reason, "sent later");
            tc.verifyEmpty(tc.Fake.Inputs);
            labclient.Outbox.move(ses.recording_event_id, "pending");
            labclient.Sync.flush(Budget=10);
            tc.verifyEqual(tc.events(), 2);
            tc.verifyEqual(height(tc.Fake.Inputs), numel(ds.Files), "the edges, once the raw files are there");
            tc.verifyTrue(all(tc.Fake.Inputs.event_id == step));
            c = labclient.Outbox.counts();
            tc.verifyEqual([c.pending c.held c.failed], [0 0 0]);
        end

        function aSecondCopyIsACopyOfItsRecording(tc)
            ds = tc.dataset();
            files = struct("path", cellstr(fullfile(ds.Folder, ds.Files)), "sha256", "", "is_epsych", false);
            info = struct("dest", ds.Folder, "subject", "SYNTH-01", "reader", "intan", ...
                "recording_time", datetime(2026, 7, 2, 14, 12, 10), "recording_duration", 30, ...
                "source_dir", "D:\rig", "files", files, "epsych_file", "", "epsych_time", NaT, ...
                "epsych_trials", NaN, "finished", datetime("now", "TimeZone", "local"));
            LabCapture.copiedSession(info);
            labclient.Hasher.work();
            labclient.Sync.flush(Budget=10);
            tc.verifyEqual(height(tc.Fake.Sessions), 1);
            S = tc.Fake.Sessions.session_id(1);
            E = LabCapture.readSession(ds.Folder, ds.Name).recording_event_id;
            raw1 = tc.Fake.Artifacts.artifact_id;

            % the same recording copied again, to the backup: its own session file, a new recording record
            dest2 = string(fullfile(tc.Top, "backup", "SYNTH-01", ds.Name));
            for f = reshape(string(ds.Files), 1, [])
                to = fullfile(dest2, f);
                if ~isfolder(fileparts(to)); mkdir(fileparts(to)); end
                copyfile(fullfile(ds.Folder, f), to);
            end
            info.dest = dest2;
            info.files = struct("path", cellstr(fullfile(dest2, ds.Files)), "sha256", "", "is_epsych", false);
            info.source_dir = "D:\rig";
            LabCapture.copiedSession(info);
            labclient.Hasher.work();
            rec2 = LabCapture.readSession(dest2, ds.Name).recording_event_id;
            tc.verifyNotEqual(rec2, E);

            % steps on the copy go first, while its recording record is held
            labclient.Outbox.move(rec2, "held");
            ds2 = EphysDataset(dest2);
            step1 = tc.captureStep(ds2);
            step2 = tc.captureStep(ds2, uint8(65:200));
            labclient.Sync.flush(Budget=20);
            tc.verifyEqual(height(tc.Fake.Sessions), 1, "no second session for one recording");
            ev = @(id) tc.Fake.Events(string({tc.Fake.Events.event_id}) == id);
            tc.verifyEqual(ev(step1).session_id, S, "the copy's step: the recording's session, found by its raw files");
            tc.verifyEqual(ev(step2).session_id, S, "and its next step, through the session file");
            tc.verifyEqual(LabCapture.readSession(dest2, ds.Name).session_id, S);

            % the copy's recording record, sent: copies of the recording's files, not a recording
            labclient.Outbox.move(rec2, "pending");
            labclient.Sync.flush(Budget=20);
            tc.verifyEqual(sum(string({tc.Fake.Events.event_type}) == "recording"), 1, "no second recording event");
            A = tc.Fake.Artifacts(~ismember(tc.Fake.Artifacts.artifact_id, raw1) & tc.Fake.Artifacts.role == "raw", :);
            tc.verifyEqual(height(A), numel(ds.Files), "each raw file of the copy");
            tc.verifyTrue(all(A.produced_by_event_id == E) && all(A.session_id == S), "files of the recording, in its session");
            a = jsondecode(char(A.attributes(1)));
            tc.verifyTrue(ismember(string(a.copied_from), raw1), "copied from the recording's file");
            tc.verifySubstring(labclient.Outbox.note(rec2, "done").reason, "a copy of the recording");
            tc.verifyEqual(LabCapture.readSession(dest2, ds.Name).recording_event_id, E);
            I = tc.Fake.Inputs(tc.Fake.Inputs.event_id == step1, :);
            tc.verifyEqual(sort(I.artifact_id), sort(A.artifact_id), "the steps' raw inputs: the copies, once they are there");
            c = labclient.Outbox.counts();
            tc.verifyEqual([c.pending c.held c.failed], [0 0 0]);
        end

        function aFigureRunIsRecorded(tc)
            ds = tc.dataset();
            key = @(p) EphysDataset.pathKey(string(p));
            f = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            detected = struct("t", 1); conversion = struct("dataset", ds.Name); %#ok<NASGU>
            save(f, "detected", "conversion");
            ds.setProcessing("spikes", EphysDataset.processingRecord("file", f, struct("runId", "run1"), struct("A", 1)), ...
                StartedAt=datetime("now", "TimeZone", "local") - seconds(3));
            labclient.Sync.flush(Budget=10);
            orig = tc.Fake.Artifacts.artifact_id(endsWith(tc.Fake.Artifacts.relative_path, ds.Name + "_spikes.mat"));
            tc.verifySize(orig, [1 1]);

            % the read ledger: what the loads read, a cached read once
            out = DatasetOutputs(ds, CacheData=true);
            out.clearReads();
            out.load("spikes");
            out.load("spikes");
            tc.verifyEqual(height(out.Reads), 1);
            tc.verifyEqual(key(out.Reads.path), key(f));

            rep = string(fullfile(ds.outputFolder(), "report.html"));
            tc.writeBytes(rep, uint8('<html>1</html>'));
            away = string(fullfile(tempname, "fig.png"));   % no storage root holds it
            mkdir(fileparts(away));
            tc.addTeardown(@() rmdir(fileparts(away), "s"));
            tc.writeBytes(away, uint8(1:10));
            r = struct("Outputs", out, "Names", string(ds.Name), "ReportFiles", rep, "Config", EphysAnalysisConfig(), ...
                "Results", table(string(ds.Name), "f1", "figure", "done", "", away, 1, ...
                'VariableNames', {'Dataset', 'Plot', 'Kind', 'Status', 'Message', 'Files', 'Seconds'}));
            id = LabCapture.analysisRun(r, 1, Started=datetime("now") - seconds(5), Finished=datetime("now"));
            tc.verifyNotEqual(id, "");
            labclient.Sync.flush(Budget=10);
            e = tc.Fake.Events(string({tc.Fake.Events.event_id}) == id);
            tc.verifySize(e, [1 1]);
            tc.verifyEqual(string(e.detail.pipeline_name), "ephys_analysis/figures");
            tc.verifyEqual(string(e.detail.status), "succeeded");
            tc.verifyEqual(e.session_id, tc.Fake.Sessions.session_id(1), "a run of one dataset: its session");
            I = tc.Fake.Inputs(tc.Fake.Inputs.event_id == id, :);
            tc.verifyEqual(I.artifact_id, orig, "its input: the spikes file it read, by its id");
            A = tc.Fake.Artifacts(tc.Fake.Artifacts.produced_by_event_id == id, :);
            tc.verifyEqual(height(A), 1, "the report (the figure outside the roots is not recorded)");
            tc.verifyTrue(endsWith(A.relative_path, "/report.html"));
            a = jsondecode(char(e.attributes));
            tc.verifyEqual(key(string(a.unrecorded_outputs)), key(away), "listed instead");

            % the next run writes the report again, other bytes: it replaces the first; it records the config it
            % started with (Config=, as EphysAnalysisRunner.run passes it), not the runner's Config, set meanwhile
            tc.writeBytes(rep, uint8('<html>2</html>'));
            ran = EphysAnalysisConfig();
            ran.Name = "as the run started";
            id2 = LabCapture.analysisRun(r, 1, Started=datetime("now") - seconds(5), Finished=datetime("now"), Config=ran);
            labclient.Sync.flush(Budget=10);
            tc.verifyNotEqual(id2, "");
            D = tc.Fake.Dispositions;
            tc.verifyEqual(D.artifact_id(D.disposition == "replaced"), A.artifact_id, "the report the run rewrote: replaced");
            e2 = tc.Fake.Events(string({tc.Fake.Events.event_id}) == id2);
            tc.verifySize(e2, [1 1]);
            a2 = jsondecode(char(e2.attributes));
            tc.verifyEqual(string(a2.config_name), "as the run started", "the config the run started with, not R.Config");
            tc.verifyNotEqual(string(r.Config.Name), "as the run started");
        end

        function aFigureRunThatThrowsIsRecorded(tc)
            % EphysAnalysisRunner.run stopped by an error at its first dataset: its run record and its record for the
            % lab database are written all the same (failed, the error), the Log says what was noted, the error goes on
            ds = tc.dataset();
            cfg = EphysAnalysisConfig();
            cfg.Name = "stops";
            cfg.Source.Mode = "folders";
            cfg.Source.Folders = string(ds.Folder);
            cfg.Report.Folder = string(fullfile(tc.Top, "analysis"));   % under the storage root "nas"
            logged = containers.Map('KeyType', 'double', 'ValueType', 'any');
            r = EphysAnalysisRunner(cfg, LogFcn=@(m) appendLog(logged, m));
            r.ProgressFcn = @(~, ~) error("test_LabSync:Stopped", "the disk is full");
            tc.verifyError(@() r.run(Export=false, Report=false), "test_LabSync:Stopped", "the caller still sees the error");
            tc.assertNotEqual(r.RunRecordFile, "", "a run that throws still writes its run record");
            rec = readJsonFile(r.RunRecordFile);
            tc.verifyEqual(string(rec.outcome), "failed");
            tc.verifyEqual(string(rec.error), "test_LabSync:Stopped: the disk is full");
            T = labclient.Outbox.list(State="pending");
            tc.assertEqual(height(T), 1, "the run, noted for the lab database");
            b = labclient.Outbox.read(T.id(1));
            ev = b.record.event;
            tc.verifyEqual(string(ev.detail.pipeline_name), "ephys_analysis/figures");
            tc.verifyEqual(string(ev.detail.status), "failed");
            a = jsondecode(char(ev.attributes_json));
            tc.verifyEqual(string(a.outcome), "failed");
            tc.verifyEqual(string(a.error), "test_LabSync:Stopped: the disk is full");
            key = @(p) EphysDataset.pathKey(string(p));
            tc.verifyEqual(key([b.record.outputs.path]), key(r.RunRecordFile), "its output: the run record");
            tc.verifyEmpty(labclient.Bundles.problems(b), "a record the database takes: not held");
            lines = string(logged.values);
            tc.verifyTrue(any(contains(lines, "Lab database: the run is noted as analysis event " + T.id(1)) ...
                & contains(lines, "status failed")), "the Log says what was noted");

            % its run record under no storage root mapped here: nothing to note, and the Log names the folder left out
            away = string(tempname);
            mkdir(away);
            tc.addTeardown(@() rmdir(away, "s"));
            cfg.Report.Folder = away;
            logged2 = containers.Map('KeyType', 'double', 'ValueType', 'any');
            r2 = EphysAnalysisRunner(cfg, LogFcn=@(m) appendLog(logged2, m));
            r2.ProgressFcn = @(~, ~) error("test_LabSync:Stopped", "the disk is full");
            tc.verifyError(@() r2.run(Export=false, Report=false), "test_LabSync:Stopped");
            tc.assertTrue(isfile(r2.RunRecordFile));
            lines2 = string(logged2.values);
            tc.verifyTrue(any(startsWith(lines2, "Lab database: nothing noted for this run")), "nothing noted, and said so");
            tc.verifyTrue(any(contains(lines2, "under no storage root mapped here") ...
                & contains(lines2, string(fileparts(r2.RunRecordFile)))), "the run record's folder named as under no mapped root");
            tc.verifyEqual(height(labclient.Outbox.list(State="pending")), 1, "nothing more in the outbox");
        end

        function aLogThatThrowsHidesNoError(tc)
            % a LogFcn that throws on the lines the run's end writes ("Lab database: ..."): a warning only, so the
            % error that stopped the run still reaches the caller, a run that finished does not fail, and each is noted
            ds = tc.dataset();
            cfg = EphysAnalysisConfig();
            cfg.Name = "log throws";
            cfg.Source.Mode = "folders";
            cfg.Source.Folders = string(ds.Folder);
            cfg.Report.Folder = string(fullfile(tc.Top, "analysis"));   % under the storage root "nas"
            r = EphysAnalysisRunner(cfg, LogFcn=@throwOnLabLine);
            r.ProgressFcn = @(~, ~) error("test_LabSync:Stopped", "the disk is full");
            tc.verifyError(@() r.run(Export=false, Report=false), "test_LabSync:Stopped", ...
                "the error that stopped the run reaches the caller, not the Log's");
            tc.verifyEqual(height(labclient.Outbox.list(State="pending")), 1, "the run is noted");
            r.ProgressFcn = [];
            tc.verifyWarning(@() r.run(Export=false, Report=false), "EphysAnalysisRunner:LogFcn", ...
                "a run that finished: the Log that throws is a warning, not an error");
            tc.verifyEqual(height(labclient.Outbox.list(State="pending")), 2, "that run is noted too");
            tc.verifyTrue(isfile(r.RunRecordFile), "and its run record written");
        end

        function aFigureRunThatDrewNothingIsFailed(tc)
            % a run that finished with every figure it tried an "error" row (the other skipped): failed, not
            % succeeded; one that drew a figure and failed another: succeeded, its failures counted
            ds = tc.dataset();
            rep = string(fullfile(ds.outputFolder(), "report.html"));
            tc.writeBytes(rep, uint8('<html>errors</html>'));
            rows = @(st) table(repmat(string(ds.Name), numel(st), 1), "f" + (1:numel(st)).', repmat("figure", numel(st), 1), ...
                reshape(st, [], 1), repmat("", numel(st), 1), repmat("", numel(st), 1), ones(numel(st), 1), ...
                'VariableNames', {'Dataset', 'Plot', 'Kind', 'Status', 'Message', 'Files', 'Seconds'});
            r = struct("Outputs", DatasetOutputs(ds), "Names", string(ds.Name), "ReportFiles", rep, ...
                "Config", EphysAnalysisConfig(), "Results", rows(["error" "error" "skipped"]));
            [id, info] = LabCapture.analysisRun(r, 1, Started=datetime("now") - seconds(5), Finished=datetime("now"));
            tc.assertNotEqual(id, "");
            b = labclient.Outbox.read(id);
            tc.verifyEqual(string(b.record.event.detail.status), "failed", "it drew no figure: every one it tried failed");
            a = jsondecode(char(b.record.event.attributes_json));
            tc.verifyEqual(string(a.outcome), "finished", "it finished");
            tc.verifyEqual(a.figure_errors, 2);
            tc.verifyEqual(info.status, "failed");

            tc.writeBytes(rep, uint8('<html>one drawn</html>'));
            r.Results = rows(["done" "error"]);
            [id2, info2] = LabCapture.analysisRun(r, 1, Started=datetime("now") - seconds(5), Finished=datetime("now"));
            b2 = labclient.Outbox.read(id2);
            tc.verifyEqual(string(b2.record.event.detail.status), "succeeded", "a figure drawn: succeeded");
            tc.verifyEqual(jsondecode(char(b2.record.event.attributes_json)).figure_errors, 1, "its failure counted");
            tc.verifyEqual(info2.status, "succeeded");
        end

        function keptFigureFilesAreNoOutputsOfTheRun(tc)
            % Export.Overwrite off: a figure file on disk from an earlier run is in Results.Files and KeptFiles; the
            % record leaves it out of its outputs (kept_outputs), so it never claims bytes the run did not write
            ds = tc.dataset();
            key = @(p) EphysDataset.pathKey(string(p));
            old = string(fullfile(ds.outputFolder(), ds.Name + "_map.png"));
            tc.writeBytes(old, uint8(1:20));
            new = string(fullfile(ds.outputFolder(), ds.Name + "_card.png"));
            tc.writeBytes(new, uint8(21:60));
            r = struct("Outputs", DatasetOutputs(ds), "Names", string(ds.Name), "ReportFiles", strings(1, 0), ...
                "Config", EphysAnalysisConfig(), "KeptFiles", old, ...
                "Results", table(string(ds.Name), "f1", "figure", "done", "2 observation(s)" + EphysAnalysisRunner.keptText(1), ...
                old + "; " + new, 1, 'VariableNames', {'Dataset', 'Plot', 'Kind', 'Status', 'Message', 'Files', 'Seconds'}));
            [id, info] = LabCapture.analysisRun(r, 1, Started=datetime("now") - seconds(5), Finished=datetime("now"));
            tc.assertNotEqual(id, "");
            b = labclient.Outbox.read(id);
            tc.verifyEqual(key([b.record.outputs.path]), key(new), "its output: the file it wrote, not the kept one");
            a = jsondecode(char(b.record.event.attributes_json));
            tc.verifyEqual(key(string(a.kept_outputs)), key(old), "the kept file listed apart");
            tc.verifyEqual(key(info.kept), key(old));
            tc.verifyEqual([info.inputs info.outputs], [0 1]);
            tc.verifyEmpty(info.unrecorded);
            tc.verifyEqual(info.why, "");
        end

        function theOutputLedgerIsKeptWhole(tc)
            % LabCapture's output ledger, written once per run: an entry another run here noted
            % stays, every output of this run is noted; a ledger that cannot be read is left as it is (a warning)
            % and the run is noted all the same
            ds = tc.dataset();
            f = string(fullfile(labclient.DB.folder(), "analysis_outputs.json"));
            otherKey = EphysDataset.pathKey(string(fullfile(tc.Top, "elsewhere", "fig.png")));
            otherValue = "11111111-2222-4333-8444-555555555555 " + string(repmat('a', 1, 64));
            writeJsonFile(f, struct("format", "ephys-labdb-outputs/1", "entries", {{struct("path", otherKey, "value", otherValue)}}));
            rep = string(fullfile(ds.outputFolder(), "report.html"));
            tc.writeBytes(rep, uint8('<html>1</html>'));
            fig = string(fullfile(ds.outputFolder(), ds.Name + "_map.png"));
            tc.writeBytes(fig, uint8(1:30));
            r = struct("Outputs", DatasetOutputs(ds), "Names", string(ds.Name), "ReportFiles", rep, "Config", EphysAnalysisConfig(), ...
                "Results", table(string(ds.Name), "f1", "figure", "done", "", fig, 1, ...
                'VariableNames', {'Dataset', 'Plot', 'Kind', 'Status', 'Message', 'Files', 'Seconds'}));
            id = LabCapture.analysisRun(r, 1, Started=datetime("now") - seconds(5), Finished=datetime("now"));
            b = labclient.Outbox.read(id);
            O = b.record.outputs;
            tc.assertNumElements(O, 2, "the report and the figure");
            E = readJsonFile(f).entries;
            paths = string({E.path});
            values = string({E.value});
            tc.verifyNumElements(E, 3, "the entry another run noted, and this run's two outputs");
            tc.verifyEqual(values(paths == otherKey), otherValue, "the other run's entry, as it was");
            for j = 1:numel(O)
                tc.verifyEqual(values(paths == EphysDataset.pathKey(O(j).path)), O(j).artifact_id + " " + O(j).sha256);
            end

            tc.writeBytes(f, uint8('{not json'));
            before = fileread(f);
            tc.writeBytes(rep, uint8('<html>2</html>'));
            id2 = tc.verifyWarning(@() LabCapture.analysisRun(r, 1, Started=datetime("now") - seconds(5), ...
                Finished=datetime("now")), "LabCapture:OutputLedger");
            tc.verifyNotEqual(id2, "", "the run is noted all the same");
            tc.verifyEqual(fileread(f), before, "a ledger that cannot be read is not written over");
        end

        function anUnreachableServerCostsNoWait(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            tc.Fake.Reachable = false;
            t0 = tic;
            r = labclient.Sync.flush(Budget=10);
            tc.verifyLessThan(toc(t0), 3);
            tc.verifyEqual(r.sent, 0);
            tc.verifyNotEqual(r.message, "");
            [~, st] = labclient.Outbox.read(id);
            tc.verifyEqual(st, "pending", "it waits");
            t0 = tic;
            labclient.Sync.tick();
            tc.verifyLessThan(toc(t0), 3, "a tick waits 2 s at most");
        end

        function nothingIsSentWhileSuspended(tc)
            ds = tc.dataset();
            tc.captureStep(ds);
            quiet = labclient.Sync.suspend();
            n = numel(tc.Fake.Calls);
            labclient.Sync.tick();
            tc.verifyEqual(numel(tc.Fake.Calls), n);
            clear quiet
            tc.verifyFalse(labclient.Sync.suspended());
        end

        function aFailedStep(tc)
            ds = tc.dataset();
            LabCapture.failure(ds, "spikes", Outcome="canceled", Message="canceled by the user", Seconds=4, ...
                Parameters=struct("Threshold", 4.5));
            T = labclient.Outbox.list(State="pending");
            tc.verifyEqual(height(T), 1);
            tc.verifyTrue(T.sealed, "no outputs: complete at once");
            labclient.Sync.flush(Budget=10);
            e = tc.Fake.Events(1);
            tc.verifyEqual(e.detail.status, "failed");
            a = jsondecode(char(e.attributes));
            tc.verifyEqual(string(a.outcome), "canceled");
            tc.verifyEmpty(tc.Fake.Artifacts, "nothing a failed step left is registered");
        end

        function whereADatasetsRecordsStand(tc)
            ds = tc.dataset();
            tc.verifyEqual(labclient.Sync.datasetText(ds.Processing), "", "no record yet");
            id = tc.captureStep(ds);
            tc.verifyEqual(labclient.Sync.datasetText(ds.Processing), "1 to send");
            labclient.Sync.flush(Budget=10);
            tc.verifyEqual(labclient.Sync.datasetText(ds.Processing), "1 sent");
            tc.Fake.Verifications = table(tc.Fake.Artifacts.artifact_id(1), "ok", ...
                datetime("now", "TimeZone", "UTC"), 'VariableNames', {'artifact_id', 'status', 'verified_at'});

            ds.writeManifest();
            v = ManifestViewerApp(ds);
            tc.addTeardown(@() delete(v));
            tc.addTeardown(@() delete(findall(groot, 'Tag', 'AppDialogText')));
            S = v.DbStepsTable.Data;
            tc.verifyEqual(string(S(:, 1)), "spikes");
            tc.verifyEqual(string(S{1, 2}), id);
            tc.verifyEqual(string(S{1, 4}), "sent", "where the record is on this computer");
            tc.verifySubstring(string(v.DbStateLabel.Text), LabCapture.readSession(ds.Folder, ds.Name).session_id);
            O = v.DbOutboxTable.Data;
            tc.verifyEqual(string(O(:, 1)), "done", "the dataset's records in the outbox");
            tc.verifyTrue(v.checkDatabase());
            tc.verifyEqual(string(v.DbStepsTable.Data{1, 5}), "in the database");
            F = v.DbFilesTable.Data;
            tc.verifyEqual(string(F{1, 4}), "present");
            tc.verifySubstring(string(F{1, 5}), "ok");
            v.DbFilesTable.Selection = 1;
            txt = v.showLineage();
            tc.verifySubstring(txt, "SYNTH-01/" + ds.Name + "/" + ds.Name + "_spikes.mat");
            tc.verifySubstring(txt, id, "made by the step's event");
        end

        function aMoveIsRecordedBeforeTheSourceGoes(tc)
            ds = tc.dataset();
            tc.captureStep(ds);
            labclient.Sync.flush(Budget=10);
            src = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            destDir = string(fullfile(tc.Top, "backup", "SYNTH-01", ds.Name));
            mkdir(destDir);
            copyfile(src, destDir);
            d = dir(src);
            F = struct("Src", src, "Rel", ds.Name + "_spikes.mat", "Bytes", d.bytes, "Time", d.datenum, ...
                "State", "copied");
            b = struct("Id", 1, "Dataset", ds.Name, "DestDir", destDir, "State", "copied", "Files", F);
            X = struct("Method", "move", "Uid", labclient.Bundles.newId(), "IfExists", "version", ...
                "sha256Of", @(f) "");
            tc.verifyFalse(LabCapture.copyRecorded(X.Uid, src), "nothing noted yet: the source stays");
            LabCapture.transferred(ds, b, X);
            tc.verifyTrue(LabCapture.copyRecorded(X.Uid, src), "the copy is noted: the source may go");
            delete(src);
            b.State = "done";
            b.Files.State = "removed";
            LabCapture.transferred(ds, b, X);
            LabCapture.transferred(ds, b, X);   % told twice: noted once
            T = labclient.Outbox.list(State="pending");
            tc.verifyEqual(height(T), 2, "the copy, then its source moved");
            labclient.Sync.flush(Budget=10);
            A = tc.Fake.Artifacts;
            tc.verifyEqual(height(A), 2);
            tc.verifyEqual(A.produced_by_event_id(2), A.produced_by_event_id(1), "the copy is the step's file too");
            tc.verifyEqual(A.checksum(2), A.checksum(1));
            tc.verifyEqual(A.relative_path(2), "backup/SYNTH-01/" + ds.Name + "/" + ds.Name + "_spikes.mat");
            D = tc.Fake.Dispositions;
            tc.verifyEqual([D.artifact_id, D.disposition, D.successor_artifact_id], ...
                [A.artifact_id(1), "moved", A.artifact_id(2)]);
            c = labclient.Outbox.counts();
            tc.verifyEqual([c.pending c.held c.failed], [0 0 0]);
        end

        function aCopyThatIsNotItsSourceIsHeld(tc)
            ds = tc.dataset();
            tc.captureStep(ds);
            labclient.Sync.flush(Budget=10);
            src = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            destDir = string(fullfile(tc.Top, "backup2"));
            mkdir(destDir);
            copy = fullfile(destDir, ds.Name + "_spikes.mat");
            tc.writeBytes(copy, uint8(200:-1:1));   % other bytes than the source's
            d = dir(src);
            F = struct("Src", src, "Rel", ds.Name + "_spikes.mat", "Bytes", d.bytes, "Time", d.datenum, ...
                "State", "copied");
            b = struct("Id", 1, "Dataset", ds.Name, "DestDir", destDir, "State", "done", "Files", F);
            X = struct("Method", "copy", "Uid", labclient.Bundles.newId(), "IfExists", "version", "sha256Of", @(f) "");
            LabCapture.transferred(ds, b, X);
            labclient.Sync.flush(Budget=10);
            T = labclient.Outbox.list(State="held");
            tc.verifyEqual(height(T), 1);
            tc.verifySubstring(T.note, "is not the bytes of the file it copies");
            tc.verifyEqual(height(tc.Fake.Artifacts), 1, "not registered");
        end

        function aCleanUpDeletionIsRecorded(tc)
            ds = tc.dataset();
            tc.captureStep(ds);
            labclient.Sync.flush(Budget=10);
            ds.writeManifest();
            f = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            d = dir(f);
            R = table(ds.Name, ds.Folder, f, d.bytes, "removed", "", false, ...
                'VariableNames', {'Dataset', 'Folder', 'File', 'Bytes', 'Status', 'To', 'Replaced'});
            delete(f);
            LabCapture.cleanedUp(R, "recycle");
            labclient.Sync.flush(Budget=10);
            D = tc.Fake.Dispositions;
            tc.verifyEqual([D.artifact_id, D.disposition], [tc.Fake.Artifacts.artifact_id(1), "deleted"]);
        end

        function findingRecordingsThroughTheDatabase(tc)
            ds = tc.dataset();
            tc.captureStep(ds);
            labclient.Sync.flush(Budget=10);
            key = @(p) EphysDataset.pathKey(string(p));
            [T, asOf, note] = LabLocator.sessions(Subject="SYNTH-01");
            tc.verifyEqual(height(T), 1);
            tc.verifyEqual(note, "");
            tc.verifyFalse(isnat(asOf));
            tc.verifyEqual(key(T.folder), key(ds.Folder), "the session folder, where it is here");
            tc.verifyTrue(T.reachable);
            tc.verifyEqual(key(T.outputs{1}), key(ds.outputFolder()), "where its outputs are here");
            tc.verifyEqual(height(LabLocator.sessions(Subject="OTHER")), 0);
            tc.verifyEqual(height(LabLocator.sessions(From=datetime(2026, 7, 3))), 0, "recorded before that day");
            tc.verifyEqual(height(LabLocator.sessions(From=datetime(2026, 7, 2), To=datetime(2026, 7, 2))), 1);
            tc.verifyEqual(key(LabLocator.outputFolders(T)), key(ds.outputFolder()));
            ks = string(fullfile(ds.outputFolder(), "kilosort4"));
            mkdir(ks);
            tc.writeBytes(fullfile(ks, "spike_times.npy"), uint8(1:32));
            ds.setProcessing("sorting", EphysDataset.processingRecord("results_dir", ks, struct("runId", "run1"), struct("A", 1)));
            labclient.Sync.flush(Budget=10);
            a = jsondecode(char(tc.Fake.Artifacts.attributes(end)));
            tc.verifyEqual(string(a.dataset_rel), "kilosort4/spike_times.npy", "a file's place in its dataset's output folder");
            [T, asOf] = LabLocator.sessions(Subject="SYNTH-01");   % the last answer now, kept with its time
            tc.verifyEqual(key(T.outputs{1}), key(ds.outputFolder()), "a sort in kilosort4/: the dataset's output folder, not kilosort4");

            tc.Fake.Reachable = false;
            labclient.DB.disconnect();
            [T2, asOf2, note2] = LabLocator.sessions(Subject="SYNTH-01");
            tc.verifySubstring(note2, "does not answer");
            tc.verifyEqual(height(T2), 1, "the last answer, while offline");
            tc.verifyLessThan(abs(seconds(asOf2 - asOf)), 1e-3, "and when it was made (kept to the microsecond)");
            tc.Fake.Reachable = true;

            dlg = LabLocatorDialog.open(Visible=false, OnDone=@(f) assignin("base", "labLocatorPicked", f));
            tc.addTeardown(@() dlg.cancel());
            tc.addTeardown(@() evalin("base", "clear labLocatorPicked"));
            dlg.Ctl.Subject.Value = 'SYNTH-01';
            labclient.DB.connect(Force=true);
            dlg.search();
            tc.verifyEqual(height(dlg.Results), 1);
            dlg.select(1);
            F = dlg.ok();
            picked = evalin("base", "labLocatorPicked");
            tc.verifyEqual(key(F), key(ds.outputFolder()));
            tc.verifyEqual(key(picked), key(ds.outputFolder()), "OnDone gets the output folders");
        end

        function theFolderThatHoldsSessions(tc)
            t = tc.Top;
            key = @(p) EphysDataset.pathKey(string(p));
            [r, d] = LabLocator.commonFolder([fullfile(t, "A", "s1"), fullfile(t, "A", "s2")]);
            tc.verifyEqual(key(r), key(fullfile(t, "A")));
            tc.verifyEqual(d, [1 1]);
            [r, d] = LabLocator.commonFolder([fullfile(t, "A", "s1"), fullfile(t, "B", "x", "s2")]);
            tc.verifyEqual(key(r), key(t));
            tc.verifyEqual(d, [2 3]);
            [r, d] = LabLocator.commonFolder(string(fullfile(t, "A", "s1")) + filesep);
            tc.verifyEqual(key(r), key(fullfile(t, "A")), "a lone session: its parent");
            tc.verifyEqual(d, 1);
            [r, d] = LabLocator.commonFolder([fullfile(t, "A"), fullfile(t, "A", "s1")]);
            tc.verifyEqual(key(r), key(t), "a session that holds another: its parent");
            tc.verifyEqual(d, [1 2]);
            if ispc
                tc.verifyEqual(LabLocator.commonFolder(["C:\a\s1" "D:\b\s2"]), "", "two drives");
                tc.verifyEqual(LabLocator.commonFolder(["\\nas\a\s1" "\\nas\b\s2"]), "", "two shares of a server");
                tc.verifyEqual(LabLocator.commonFolder(["\\nas\a\s1" "\\nas\a\s2"]), "\\nas\a");
                tc.verifyEqual(LabLocator.commonFolder(["D:\s1" "d:\s2"]), "D:\", "a drive's top, case ignored");
            else
                tc.verifyEqual(LabLocator.commonFolder(["/a/s1" "/b/s2"]), "", "nothing but /");
            end
        end

        function openingRecordingsInTheApps(tc)
            tc.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                ["EphysProject:NoData" "EphysProject:OutputsOnly"]));
            ds = tc.dataset();
            other = string(fullfile(tc.Top, "SYNTH-01", "SYNTH-01_260703_101010"));
            makeSyntheticRecording(other, Subject="SYNTH-01", Format="one-file-per-signal", ...
                NumChannels=2, NumTrials=4, Fs=2000, SortedOutput=false, Artifacts=false, WriteManifest=false);
            key = @(p) EphysDataset.pathKey(string(p));

            app = EphysPipelineApp;
            tc.addTeardown(@() delete(app.Fig));
            app.RecursiveCheckBox.Value = false;
            app.onOpenFromDatabase(ds.Folder);
            tc.verifyEqual(key(app.RootPathField.Value), key(fullfile(tc.Top, "SYNTH-01")), "the root: the session's parent");
            tc.verifyEqual(app.Project.NumDatasets, 2, "the root scanned: both sessions in it");
            T = app.DatasetsTable.Data;
            ticked = [app.Project.Datasets(T.DatasetIdx(T.Select)).Folder];
            tc.verifyEqual(key(ticked), key(ds.Folder), "only the session picked is ticked");
            tc.verifySubstring(string(app.StatusBar.Text), "1 ticked");

            app.onOpenFromDatabase([string(ds.Folder), string(fullfile(tc.Top, "elsewhere", "gone"))]);
            tc.verifyEqual(key(app.RootPathField.Value), key(tc.Top));
            tc.verifyTrue(app.RecursiveCheckBox.Value, "a session deeper than the root's folders: Recursive on");
            tc.verifySubstring(string(app.StatusBar.Text), "Recursive is on");
            tc.verifySubstring(string(app.StatusBar.Text), "Not found as datasets by the scan: " + fullfile(tc.Top, "elsewhere", "gone"));

            B = DatasetBrowser("", Visible=false, Scan=false);
            tc.addTeardown(@() delete(B));
            msg = B.openFromDatabase(string(ds.outputFolder()));
            tc.verifyEqual(key(B.Root), key(fullfile(tc.Top, "SYNTH-01")));
            tc.verifyEqual(height(B.Table), 2);
            tc.verifyEqual(numel(B.Selected), 1, msg);
            S = B.Table;
            tc.verifyEqual(S.Name(S.Key == B.Selected), string(ds.Name), "the browser ticks the recording picked");
            tc.verifySubstring(msg, "1 ticked");
        end

        function outputsFoundThroughTheDatabase(tc)
            ds = tc.dataset();
            key = @(p) EphysDataset.pathKey(string(p));
            f = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            detected = struct("t", 1); conversion = struct("dataset", ds.Name); %#ok<NASGU>
            save(f, "detected", "conversion");
            r = EphysDataset.processingRecord("file", f, struct("runId", "run1"), struct("A", 1));
            ds.setProcessing("spikes", r, StartedAt=datetime("now", "TimeZone", "local") - seconds(3));
            ev = ds.Processing.spikes.event_id;
            ds.writeManifest();   % the manifest records the step
            labclient.Sync.flush(Budget=10);
            s = labclient.Settings.load();
            [~, relOld] = labclient.Roots.locate(f, s);
            old = tc.Fake.Artifacts.artifact_id(tc.Fake.Artifacts.relative_path == relOld);
            tc.verifySize(old, [1 1]);
            tc.verifyEqual(DatasetOutputs(ds).pathSource("spikes"), "discovered", "here: the search roots decide");

            % moved elsewhere, as the output transfer records a move: a file at the new place, the old one moved
            there = string(fullfile(tc.Top, "moved", ds.Name));
            mkdir(there);
            copy = string(fullfile(there, ds.Name + "_spikes.mat"));
            movefile(f, copy);
            [~, rel] = labclient.Roots.locate(copy, s);
            d = dir(copy);
            b = labclient.DB.connect();
            id = labclient.Bundles.newId();
            b.addArtifact(struct("ArtifactId", id, "ProducedByEventId", ev, "StorageRootId", 1, "RelativePath", rel, ...
                "Checksum", labclient.fileSha256(copy), "SizeBytes", d.bytes, "Role", "spikes", "Format", "mat", ...
                "AttributesJson", string(jsonencode(struct("kind", "threshold_spikes", "dataset_rel", ds.Name + "_spikes.mat")))));
            b.addDisposition(struct("ArtifactId", old, "Disposition", "moved", "SuccessorArtifactId", id, ...
                "OccurredAt", datetime("now", "TimeZone", "local"), "Note", "", "AttributesJson", "{}"));
            out = DatasetOutputs(ds);
            tc.verifyEqual(key(out.SpikesFile), key(copy), "found in the folder the database names");
            tc.verifyEqual(out.pathSource("spikes"), "database");
            tc.verifyEqual(key(out.databaseFiles()), key(copy), "for the run record (fromDatabase)");
            tc.verifyFalse(out.has("nwb"), "a step the manifest does not record: not looked for");

            % other bytes at that place than the database registered: the search's pick, with a warning
            extra = 1; %#ok<NASGU>
            save(copy, "detected", "conversion", "extra");
            out = DatasetOutputs(ds);
            tc.verifyWarning(@() out.pathSource("spikes"), "DatasetOutputs:DatabaseSize");

            % offline: the local search only, and no long wait
            tc.Fake.Reachable = false;
            labclient.DB.disconnect();
            out = DatasetOutputs(ds);
            t0 = tic;
            tc.verifyFalse(out.has("spikes"));
            tc.verifyLessThan(toc(t0), 5);
        end

        function aPhyCurationIsRecorded(tc)
            ds = tc.dataset();
            tab = char(9);
            ks = string(fullfile(ds.outputFolder(), "kilosort4"));
            mkdir(ks);
            tc.writeBytes(fullfile(ks, "params.py"), uint8('dat_path = "x.bin"'));
            tc.writeBytes(fullfile(ks, "spike_clusters.npy"), uint8(1:40));
            tc.writeBytes(fullfile(ks, "cluster_group.tsv"), uint8(['cluster_id' tab 'KSLabel' newline '0' tab 'good' newline]));
            ds.setProcessing("sorting", EphysDataset.processingRecord("results_dir", ks, struct("runId", "run1"), struct("A", 1)));
            sortId = ds.Processing.sorting.event_id;
            labclient.Sync.flush(Budget=10);
            A0 = tc.Fake.Artifacts;
            tc.verifyEqual(LabCapture.curation(ds), "", "nothing changed since the sort");

            % phy opened from the app, then saved: labels set, a merge (spike_clusters), cluster_info
            LabCapture.phyOpened(ds, ks);
            pause(1.1);   % the save after the launch, also where a file's time is kept to the second
            tc.writeBytes(fullfile(ks, "cluster_group.tsv"), uint8(['cluster_id' tab 'group' newline '0' tab 'mua' newline]));
            tc.writeBytes(fullfile(ks, "spike_clusters.npy"), uint8(41:100));
            tc.writeBytes(fullfile(ks, "cluster_info.tsv"), uint8(['cluster_id' tab 'group' newline '0' tab 'mua' newline]));
            id = LabCapture.curation(ds);
            tc.verifyNotEqual(id, "");
            tc.verifyEqual(LabCapture.curation(ds), "", "one save is captured once");
            labclient.Sync.flush(Budget=10);
            e = tc.Fake.Events(string({tc.Fake.Events.event_id}) == id);
            tc.verifySize(e, [1 1]);
            tc.verifyEqual(string(e.detail.status), "succeeded");
            a = jsondecode(char(e.attributes));
            tc.verifyEqual(string(a.tool), "phy");
            tc.verifyEqual(string(a.sort_event_id), sortId);
            tc.verifyEqual(string(a.opened_by.os_user), labclient.Bundles.osUser(), "who opened phy from the app");
            tc.verifyEqual(string(a.phy_labels), "mua");

            A = tc.Fake.Artifacts(tc.Fake.Artifacts.produced_by_event_id == id, :);
            name = @(p) regexprep(string(p), '^.*[\\/]', '');
            tc.verifyEqual(sort(name(A.relative_path)), ["cluster_group.tsv"; "cluster_info.tsv"; "spike_clusters.npy"]);
            D = tc.Fake.Dispositions;
            old = A0.artifact_id(ismember(name(A0.relative_path), ["cluster_group.tsv" "spike_clusters.npy"]));
            tc.verifyEqual(sort(D.artifact_id(D.disposition == "replaced")), sort(old), "the versions phy changed: replaced");
            I = tc.Fake.Inputs(tc.Fake.Inputs.event_id == id, :);
            tc.verifyEqual(sort(I.artifact_id), sort(A0.artifact_id), "its inputs: the sort as recorded");

            % a later look at a file saved again with the same bytes: nothing new
            bytes = fileread(fullfile(ks, "cluster_info.tsv"));
            pause(1.1);
            tc.writeBytes(fullfile(ks, "cluster_info.tsv"), uint8(bytes));
            tc.verifyEqual(LabCapture.curation(ds), "", "the same bytes again: no curation");
            ses = LabCapture.readSession(ds.Folder, ds.Name);
            tc.verifyEqual(ses.curations(end).event_id, "", "a save that changed no bytes: noted, no event");

            % a re-sort later replaces phy's version of a file, not the sort's first one
            tc.writeBytes(fullfile(ks, "cluster_info.tsv"), uint8(['cluster_id' tab 'group' newline '0' tab 'good' newline '1' tab 'mua' newline]));
            ds.setProcessing("sorting", EphysDataset.processingRecord("results_dir", ks, struct("runId", "run2"), struct("A", 2)));
            b = labclient.Outbox.read(ds.Processing.sorting.event_id);
            o = b.record.outputs(name(string({b.record.outputs.path})) == "cluster_info.tsv");
            tc.verifyEqual(o.replaces, A.artifact_id(name(A.relative_path) == "cluster_info.tsv"), ...
                "the file's latest version is phy's, for a later re-sort, copy or move");
        end

        function anAnalysisCopyIsRecorded(tc)
            tc.assumeTrue(ispc, "the copy runs robocopy (Windows)");
            ds = tc.dataset();
            f = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            detected = struct("t", 1); conversion = struct("dataset", ds.Name); %#ok<NASGU>
            save(f, "detected", "conversion");
            ds.setProcessing("spikes", EphysDataset.processingRecord("file", f, struct("runId", "run1"), struct("A", 1)), ...
                StartedAt=datetime("now", "TimeZone", "local") - seconds(3));
            ev = ds.Processing.spikes.event_id;
            ds.writeManifest();
            labclient.Sync.flush(Budget=10);
            orig = tc.Fake.Artifacts.artifact_id(endsWith(tc.Fake.Artifacts.relative_path, ds.Name + "_spikes.mat"));
            tc.verifySize(orig, [1 1]);

            dlg = AnalysisCopyDialog(ds, Destination=string(fullfile(tc.Top, "laptop")), Visible=false);
            tc.addTeardown(@() delete(dlg));
            dlg.start();
            dlg.wait(120);
            labclient.Sync.flush(Budget=10);
            A = tc.Fake.Artifacts(startsWith(tc.Fake.Artifacts.relative_path, "laptop/"), :);
            tc.verifyEqual(height(A), 1, "the spikes file's copy (the manifest and the rest are no step's file)");
            tc.verifyEqual(A.produced_by_event_id, ev, "a file of the step that wrote it");
            tc.verifyEqual(A.checksum, labclient.fileSha256(f));
            a = jsondecode(char(A.attributes));
            tc.verifyEqual(string(a.copied_from), orig);
            tc.verifyEqual(string(a.dataset_rel), ds.Name + "_spikes.mat", "its place in the copy of the dataset's folder");
        end

        function aDiscardedRecordIsKept(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            p = labclient.Panel.open(Visible=false);
            tc.addTeardown(@() p.close());
            p.discard(id, Confirm=false, Reason="a test recording");
            [~, st] = labclient.Outbox.read(id);
            tc.verifyEqual(st, "discarded");
            tc.verifySubstring(labclient.Outbox.note(id, "discarded").reason, "a test recording");
            labclient.Sync.flush(Budget=10);
            tc.verifyEqual(tc.events(), 0, "never sent");
        end
    end
end


function appendLog(map, msg)
%appendLog  A LogFcn that keeps every line in MAP (a containers.Map, a handle), in order.
map(map.Count + 1) = string(msg); %#ok<NASGU> containers.Map is a handle
end


function throwOnLabLine(msg)
%throwOnLabLine  A LogFcn that throws on the lines about the lab database's record ("Lab database: ...").
if startsWith(string(msg), "Lab database:")
    error("test_LabSync:LogClosed", "the Log is closed");
end
end
