classdef test_LabSync < matlab.unittest.TestCase
    %test_LabSync  Sending the outbox to the lab database (LabSync), against the in-memory fake.
    %   Everything runs in a temporary preference store, a fake password
    %   vault, a temporary database folder and LabDBFakeBackend; no timer
    %   runs (LabSync.useManual): the tests send by hand.
    %
    %   Covered: a step sent once (its session created in the folder's root,
    %   its file registered with its SHA-256, the person named, inputs this
    %   computer cannot name listed, not guessed), sent again is "existing";
    %   a commit whose answer was lost; the same id with other content held
    %   as a conflict; a subject the database does not have holds the record
    %   until it is assigned (SubjectAssignDialog: an existing subject, or a
    %   new one); a record of another login held until "Send as me"; a copied
    %   session sent before the step that read its files, and inputs sent
    %   later as an edges record; an unreachable server costs no wait and
    %   leaves the outbox as it was; no sending while suspended; a failed step
    %   recorded as failed; a discarded record kept, never sent; where a
    %   dataset's records stand (LabSync.datasetText, the Review tab's
    %   Database column) and the manifest viewer's Database tab (the steps
    %   and files here and in the database, a file's lineage); a move
    %   (OutputTransfer): its copy registered under the step's event before
    %   the source may go, then the source recorded as moved; a copy that is
    %   not its source's bytes held; a clean-up's deletion recorded.
    %
    %   Usage:  runtests("test_LabSync")

    properties (Access = private)
        Fake
        Restore = {}
        Top = ""
    end

    methods (TestMethodSetup)
        function isolate(tc)
            tc.Restore = {AppPrefs.useTemporary(), LabDBSecrets.useFake(), LabDB.useTemporary(), ...
                LabSync.useManual()};
            tc.Fake = LabDBFakeBackend();
            tc.Fake.Roots = table(1, "nas", "the lab's NAS", 'VariableNames', {'root_id', 'name', 'description'});
            tc.Fake.Subjects = table(["SYNTH-01"; "SYNTH-1"; "G-0421"], ["P1"; "P1"; "P1"], ...
                ["mus_musculus"; "mus_musculus"; "meriones_unguiculatus"], ["F"; "M"; "U"], ...
                'VariableNames', {'subject_id', 'project_id', 'species_code', 'sex'});
            fake = tc.Fake;
            tc.Restore{end + 1} = LabDB.useBackend(@() fake);
            tc.Top = string(tempname);
            mkdir(tc.Top);
            s = LabDBSettings.defaults();
            s.Enabled = true;
            s.Server = "labdb.test";
            s.Username = "jdoe";
            s.Roots = struct("Name", "nas", "Path", tc.Top);
            LabDBSettings.save(s);
            LabDBSecrets.setFake(LabDBSettings.load(), fake.Password);
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
            r = LabSync.flush(Budget=10);
            tc.verifyEqual(r.sent, 1, r.message);
            [~, st] = LabOutbox.read(id);
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
            tc.verifyEqual(A.checksum, fileSha256(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat")));
            tc.verifyEqual(A.produced_by_event_id, id);
            a = jsondecode(char(e.attributes));
            tc.verifyEqual(numel(a.unresolved_inputs), numel(ds.Files), ...
                "raw files this computer cannot name are listed, not guessed");
            tc.verifyEmpty(tc.Fake.Inputs);

            LabOutbox.move(id, "pending");   % sent again
            tc.verifyEqual(LabSync.flush(Budget=10).sent, 1);
            tc.verifyEqual(tc.events(), 1, "the same record twice: written once");
            tc.verifySubstring(LabOutbox.note(id, "done").reason, "already in the database");
        end

        function aCommitWhoseAnswerWasLost(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            tc.Fake.Fail = struct("Method", "recordEvent", "Identifier", "CarasLabDB:transactionInterrupted", ...
                "Message", "the connection was reset", "AfterWrite", true);
            b = LabDB.connect(Force=true);
            r = LabSync.sendNext(b);
            tc.verifyEqual(r.outcome, "pending", "a broken connection: it waits");
            tc.verifyEqual(LabDB.status().State, "offline");
            tc.verifyEqual(tc.events(), 1, "the commit went through");
            b = LabDB.connect(Force=true);
            r = LabSync.sendNext(b);
            tc.verifyEqual(r.outcome, "done");
            tc.verifySubstring(r.reason, "already in the database");
            tc.verifyEqual(tc.events(), 1);
            [~, st] = LabOutbox.read(id);
            tc.verifyEqual(st, "done");
        end

        function sameIdOtherContentIsAConflict(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            LabSync.flush(Budget=10);
            LabOutbox.move(id, "pending");
            b = LabOutbox.read(id);
            b.record.event.notes = "changed after it was sent";
            LabOutbox.update(LabBundles.seal(b));
            LabSync.flush(Budget=10);
            [~, st] = LabOutbox.read(id);
            tc.verifyEqual(st, "held");
            tc.verifySubstring(LabOutbox.note(id, "held").reason, "Conflict");
            tc.verifyEqual(tc.events(), 1, "nothing written");
        end

        function aSubjectToAssign(tc)
            ds = tc.dataset("SYNTH-O1");   % a letter O for a zero
            id = tc.captureStep(ds);
            LabSync.flush(Budget=10);
            [~, st] = LabOutbox.read(id);
            tc.verifyEqual(st, "held");
            tc.verifySubstring(LabOutbox.note(id, "held").reason, "SYNTH-O1 is not in the database");
            T = LabSync.subjectHolds();
            tc.verifyEqual(T.folder_id, "SYNTH-O1");
            tc.verifyEmpty(tc.Fake.Sessions, "no session for a subject that is not there");

            dlg = SubjectAssignDialog.open(FolderId="SYNTH-O1", Visible=false);
            tc.addTeardown(@() dlg.cancel());
            items = string(dlg.Ctl.List.Items);
            tc.verifyEqual(items(1), "SYNTH-01", "the nearest subject first");
            dlg.pick("SYNTH-01");
            dlg.ok();
            tc.verifyEqual(dlg.Result, "SYNTH-01");
            tc.verifyEqual(LabCapture.readSession(ds.Folder, ds.Name).subject_id, "SYNTH-01", ...
                "noted in the session file; the folder keeps its name");
            tc.verifyTrue(isfolder(ds.Folder));
            [~, st] = LabOutbox.read(id);
            tc.verifyEqual(st, "pending", "released");
            LabSync.flush(Budget=10);
            tc.verifyEqual(tc.Fake.Sessions.subject_id, "SYNTH-01");
            tc.verifyEqual(tc.events(), 1);
        end

        function aNewSubject(tc)
            ds = tc.dataset("NEW-7");
            id = tc.captureStep(ds);
            LabSync.flush(Budget=10);
            dlg = SubjectAssignDialog.open(FolderId="NEW-7", Visible=false);
            tc.addTeardown(@() dlg.cancel());
            dlg.choose("create");
            dlg.Ctl.Sex.Value = 'F';
            dlg.ok();
            tc.verifyTrue(any(tc.Fake.Subjects.subject_id == "NEW-7"), "created in the database");
            tc.verifyEqual(tc.Fake.Subjects.sex(tc.Fake.Subjects.subject_id == "NEW-7"), "F");
            LabSync.flush(Budget=10);
            [~, st] = LabOutbox.read(id);
            tc.verifyEqual(st, "done");
        end

        function anotherLoginWaitsForSendAsMe(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            b = LabOutbox.read(id);
            b.captured_by.db_username = "asmith";
            LabOutbox.update(b);   % the envelope, not the record: the digest stays
            LabSync.flush(Budget=10);
            [~, st] = LabOutbox.read(id);
            tc.verifyEqual(st, "held");
            tc.verifySubstring(LabOutbox.note(id, "held").reason, "asmith");
            p = LabDBPanel.open(Visible=false);
            tc.addTeardown(@() p.close());
            p.release(id, OnBehalf=true);
            LabSync.flush(Budget=10);
            [~, st] = LabOutbox.read(id);
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
            LabHasher.work();
            step = tc.captureStep(ds);
            b = LabOutbox.read(step);
            tc.verifyTrue(all([b.record.inputs.artifact_id] ~= ""), "the raw files' ids, from the session file");

            % The step goes first (the recording is held): its inputs wait.
            LabOutbox.move(ses.recording_event_id, "held");
            LabSync.flush(Budget=10);
            [~, st] = LabOutbox.read(step);
            tc.verifyEqual(st, "done");
            tc.verifySubstring(LabOutbox.note(step, "done").reason, "sent later");
            tc.verifyEmpty(tc.Fake.Inputs);
            LabOutbox.move(ses.recording_event_id, "pending");
            LabSync.flush(Budget=10);
            tc.verifyEqual(tc.events(), 2);
            tc.verifyEqual(height(tc.Fake.Inputs), numel(ds.Files), "the edges, once the raw files are there");
            tc.verifyTrue(all(tc.Fake.Inputs.event_id == step));
            c = LabOutbox.counts();
            tc.verifyEqual([c.pending c.held c.failed], [0 0 0]);
        end

        function anUnreachableServerCostsNoWait(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            tc.Fake.Reachable = false;
            t0 = tic;
            r = LabSync.flush(Budget=10);
            tc.verifyLessThan(toc(t0), 3);
            tc.verifyEqual(r.sent, 0);
            tc.verifyNotEqual(r.message, "");
            [~, st] = LabOutbox.read(id);
            tc.verifyEqual(st, "pending", "it waits");
            t0 = tic;
            LabSync.tick();
            tc.verifyLessThan(toc(t0), 3, "a tick waits 2 s at most");
        end

        function nothingIsSentWhileSuspended(tc)
            ds = tc.dataset();
            tc.captureStep(ds);
            quiet = LabSync.suspend();
            n = numel(tc.Fake.Calls);
            LabSync.tick();
            tc.verifyEqual(numel(tc.Fake.Calls), n);
            clear quiet
            tc.verifyFalse(LabSync.suspended());
        end

        function aFailedStep(tc)
            ds = tc.dataset();
            LabCapture.failure(ds, "spikes", Outcome="canceled", Message="canceled by the user", Seconds=4, ...
                Parameters=struct("Threshold", 4.5));
            T = LabOutbox.list(State="pending");
            tc.verifyEqual(height(T), 1);
            tc.verifyTrue(T.sealed, "no outputs: complete at once");
            LabSync.flush(Budget=10);
            e = tc.Fake.Events(1);
            tc.verifyEqual(e.detail.status, "failed");
            a = jsondecode(char(e.attributes));
            tc.verifyEqual(string(a.outcome), "canceled");
            tc.verifyEmpty(tc.Fake.Artifacts, "nothing a failed step left is registered");
        end

        function whereADatasetsRecordsStand(tc)
            ds = tc.dataset();
            tc.verifyEqual(LabSync.datasetText(ds.Processing), "", "no record yet");
            id = tc.captureStep(ds);
            tc.verifyEqual(LabSync.datasetText(ds.Processing), "1 to send");
            LabSync.flush(Budget=10);
            tc.verifyEqual(LabSync.datasetText(ds.Processing), "1 sent");
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
            LabSync.flush(Budget=10);
            src = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            destDir = string(fullfile(tc.Top, "backup", "SYNTH-01", ds.Name));
            mkdir(destDir);
            copyfile(src, destDir);
            d = dir(src);
            F = struct("Src", src, "Rel", ds.Name + "_spikes.mat", "Bytes", d.bytes, "Time", d.datenum, ...
                "State", "copied");
            b = struct("Id", 1, "Dataset", ds.Name, "DestDir", destDir, "State", "copied", "Files", F);
            X = struct("Method", "move", "Uid", LabBundles.newId(), "IfExists", "version", ...
                "sha256Of", @(f) "");
            tc.verifyFalse(LabCapture.copyRecorded(X.Uid, src), "nothing noted yet: the source stays");
            LabCapture.transferred(ds, b, X);
            tc.verifyTrue(LabCapture.copyRecorded(X.Uid, src), "the copy is noted: the source may go");
            delete(src);
            b.State = "done";
            b.Files.State = "removed";
            LabCapture.transferred(ds, b, X);
            LabCapture.transferred(ds, b, X);   % told twice: noted once
            T = LabOutbox.list(State="pending");
            tc.verifyEqual(height(T), 2, "the copy, then its source moved");
            LabSync.flush(Budget=10);
            A = tc.Fake.Artifacts;
            tc.verifyEqual(height(A), 2);
            tc.verifyEqual(A.produced_by_event_id(2), A.produced_by_event_id(1), "the copy is the step's file too");
            tc.verifyEqual(A.checksum(2), A.checksum(1));
            tc.verifyEqual(A.relative_path(2), "backup/SYNTH-01/" + ds.Name + "/" + ds.Name + "_spikes.mat");
            D = tc.Fake.Dispositions;
            tc.verifyEqual([D.artifact_id, D.disposition, D.successor_artifact_id], ...
                [A.artifact_id(1), "moved", A.artifact_id(2)]);
            c = LabOutbox.counts();
            tc.verifyEqual([c.pending c.held c.failed], [0 0 0]);
        end

        function aCopyThatIsNotItsSourceIsHeld(tc)
            ds = tc.dataset();
            tc.captureStep(ds);
            LabSync.flush(Budget=10);
            src = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            destDir = string(fullfile(tc.Top, "backup2"));
            mkdir(destDir);
            copy = fullfile(destDir, ds.Name + "_spikes.mat");
            tc.writeBytes(copy, uint8(200:-1:1));   % other bytes than the source's
            d = dir(src);
            F = struct("Src", src, "Rel", ds.Name + "_spikes.mat", "Bytes", d.bytes, "Time", d.datenum, ...
                "State", "copied");
            b = struct("Id", 1, "Dataset", ds.Name, "DestDir", destDir, "State", "done", "Files", F);
            X = struct("Method", "copy", "Uid", LabBundles.newId(), "IfExists", "version", "sha256Of", @(f) "");
            LabCapture.transferred(ds, b, X);
            LabSync.flush(Budget=10);
            T = LabOutbox.list(State="held");
            tc.verifyEqual(height(T), 1);
            tc.verifySubstring(T.note, "is not the bytes of the file it copies");
            tc.verifyEqual(height(tc.Fake.Artifacts), 1, "not registered");
        end

        function aCleanUpDeletionIsRecorded(tc)
            ds = tc.dataset();
            tc.captureStep(ds);
            LabSync.flush(Budget=10);
            ds.writeManifest();
            f = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            d = dir(f);
            R = table(ds.Name, ds.Folder, f, d.bytes, "removed", "", false, ...
                'VariableNames', {'Dataset', 'Folder', 'File', 'Bytes', 'Status', 'To', 'Replaced'});
            delete(f);
            LabCapture.cleanedUp(R, "recycle");
            LabSync.flush(Budget=10);
            D = tc.Fake.Dispositions;
            tc.verifyEqual([D.artifact_id, D.disposition], [tc.Fake.Artifacts.artifact_id(1), "deleted"]);
        end

        function aDiscardedRecordIsKept(tc)
            ds = tc.dataset();
            id = tc.captureStep(ds);
            p = LabDBPanel.open(Visible=false);
            tc.addTeardown(@() p.close());
            p.discard(id, Confirm=false, Reason="a test recording");
            [~, st] = LabOutbox.read(id);
            tc.verifyEqual(st, "discarded");
            tc.verifySubstring(LabOutbox.note(id, "discarded").reason, "a test recording");
            LabSync.flush(Budget=10);
            tc.verifyEqual(tc.events(), 0, "never sent");
        end
    end
end
