classdef test_LabCapture < matlab.unittest.TestCase
    %test_LabCapture  What the toolbox keeps for the lab database: bundles, the outbox, hashes, capture.
    %   Everything runs in a temporary preference store and a temporary
    %   database folder; nothing is sent (there is no server) and nothing of
    %   the user's is touched.
    %
    %   Covered: fileSha256 (known vectors); LabBundles (zoned times, ids,
    %   the golden bundle testdata/labdb/bundle_event_v1.json: its encoding,
    %   decoding and digest, a list of one still a list); LabOutbox (put,
    %   read, the same bundle twice, a different one refused, claims only
    %   one can win, finish, hold with its reason, stale claims given back);
    %   LabHasher (in MATLAB, a file changed after capture holds its bundle,
    %   out of process); EphysDataset.setProcessing through LabCapture (off:
    %   stamped, nothing in the outbox; on: the bundle, its inputs, outputs,
    %   roots, the session file; a file rewritten replaces the earlier one,
    %   rewritten with the same bytes it is the same file); a sort stamped
    %   at launch keeps its id; a copied session's recording and behavior;
    %   the pipeline run record's event list.
    %
    %   Usage:  runtests("test_LabCapture")

    properties (Access = private)
        Restore = {}
        Top = ""
    end

    methods (TestMethodSetup)
        function isolate(tc)
            tc.Restore = {AppPrefs.useTemporary(), LabDBSecrets.useFake(), LabDB.useTemporary(), ...
                LabSync.useManual()};
            tc.Top = string(tempname);
            mkdir(tc.Top);
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

        function s = enable(tc, opts)
            arguments
                tc
                opts.HashInProcessMB (1,1) double = 256
            end
            s = LabDBSettings.defaults();
            s.Enabled = true;
            s.Server = "labdb.test";
            s.Username = "jdoe";
            s.Roots = struct("Name", "nas", "Path", tc.Top);
            s.HashInProcessMB = opts.HashInProcessMB;
            LabDBSettings.save(s);
            s = LabDBSettings.load();
        end

        function f = writeBytes(~, f, bytes)
            fid = fopen(f, "w");
            fwrite(fid, bytes, "uint8");
            fclose(fid);
        end

        function [ds, folder] = dataset(tc)
            folder = string(fullfile(tc.Top, "SYNTH-01", "SYNTH-01_260702_141210"));
            R = makeSyntheticRecording(folder, Subject="SYNTH-01", Format="one-file-per-signal", ...
                NumChannels=2, NumTrials=4, Fs=2000, SortedOutput=false, Artifacts=false, WriteManifest=false);
            if isfile(R.behaviorFile); delete(R.behaviorFile); end
            ds = EphysDataset(folder);
        end

        function b = goldenBundle(~)
            out = LabBundles.item("/data/nas/G-1/s1/s1_spikes.mat", Role="spikes", Kind="threshold_spikes", ...
                ArtifactId="11111111-1111-4111-8111-111111111111", Root="nas", Rel="G-1/s1/s1_spikes.mat", ...
                Sha256=string(repmat('a', 1, 64)), ...
                Snapshot=struct("bytes", 1234, "mtime", "2026-07-02T14:30:00.000-04:00"));
            in = LabBundles.item("/data/nas/G-1/s1/amplifier.dat", Role="raw", Kind="raw", ...
                Root="nas", Rel="G-1/s1/amplifier.dat", ...
                Snapshot=struct("bytes", 5000000000, "mtime", "2026-07-02T14:12:10.000-04:00"));
            detail = struct("pipeline_name", "ephys_analysis/spikes", "code_version", "abc1234", ...
                "parameters_json", '{"file":"s1_spikes.mat"}', "environment_json", "{}", ...
                "started_at", "2026-07-02T14:29:00.000000-04:00", ...
                "finished_at", "2026-07-02T14:30:00.000000-04:00", "status", "succeeded");
            ds = struct("name", "s1", "folder", "/data/nas/G-1/s1", ...
                "session_id", "33333333-3333-4333-8333-333333333333", "subject_folder_id", "G-1", ...
                "recording_start", "2026-07-02T14:12:10.000000-04:00");
            by = struct("host", "RIG2", "os_user", "jdoe", "db_username", "jdoe", "person_id", "", ...
                "person_email", "");
            b = LabBundles.event(EventId="22222222-2222-4222-8222-222222222222", EventType="analysis", ...
                OccurredAt="2026-07-02T14:29:00.000000-04:00", Detail=detail, ...
                Attributes=struct("step", "spikes"), Dataset=ds, Inputs=in, Outputs=out, ...
                CapturedAt="2026-07-02T14:30:01.000000-04:00", CapturedBy=by);
        end
    end

    methods (Test)
        function sha256KnownVectors(tc)
            tc.verifyEqual(fileSha256("", Text=true), ...
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
            tc.verifyEqual(fileSha256("abc", Text=true), ...
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
            f = fullfile(tc.Top, "abc.txt");
            tc.writeBytes(f, uint8('abc'));
            tc.verifyEqual(fileSha256(f), fileSha256("abc", Text=true), "a file and its bytes as text");
            tc.verifyError(@() fileSha256(fullfile(tc.Top, "none.bin")), "fileSha256:CannotRead");
        end

        function timesAndIds(tc)
            t = LabBundles.timeText(datetime(2026, 7, 2, 14, 30, 0.5, "TimeZone", "America/New_York"));
            tc.verifyEqual(t, "2026-07-02T14:30:00.500000-04:00");
            tc.verifyEqual(LabBundles.timeText(NaT("TimeZone", "UTC")), "");
            tc.verifyError(@() LabBundles.timeText(datetime(2026, 7, 2)), "LabBundles:Unzoned");
            a = LabBundles.newId(); b = LabBundles.newId();
            tc.verifyNotEqual(a, b);
            tc.verifyNotEmpty(regexp(a, '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', 'once'));
        end

        function goldenBundleIsTheFormat(tc)
            golden = strtrim(string(fileread(fullfile(fileparts(mfilename("fullpath")), ...
                "testdata", "labdb", "bundle_event_v1.json"))));
            b = LabBundles.seal(tc.goldenBundle());
            txt = LabBundles.encode(b);
            tc.verifyEqual(txt, golden, "LabBundles.encode is the documented format, byte for byte. Got: " + txt);
            tc.verifyEqual(b.digest, fileSha256(LabBundles.encodeRecord(b.record), Text=true));
            d = LabBundles.decode(golden);
            tc.verifyEqual(LabBundles.encode(d), golden, "decoded and encoded again: the same text");
            tc.verifyEqual(LabBundles.seal(d).digest, b.digest, "the same digest from the file");
            tc.verifyEqual(d.record.outputs(1).bytes, 1234);
            tc.verifyEqual(d.record.inputs(1).bytes, 5000000000);
            tc.verifySubstring(txt, '"outputs":[{', "a list of one is still a list");
            u = tc.goldenBundle();
            u.record.outputs(1).sha256 = "";
            tc.verifyFalse(LabBundles.isSealed(LabBundles.seal(u)), "an output without its hash: not sealed");
        end

        function outboxStatesAndClaims(tc)
            b = LabBundles.seal(tc.goldenBundle());
            LabOutbox.put(b);
            LabOutbox.put(b);   % the same bundle again: nothing new
            c = LabOutbox.counts();
            tc.verifyEqual(c.pending, 1);
            other = b;
            other.record.event.notes = "something else";
            tc.verifyError(@() LabOutbox.put(other), "LabOutbox:Exists");
            [r, st] = LabOutbox.read(b.bundle_id);
            tc.verifyEqual(st, "pending");
            tc.verifyEqual(LabBundles.encode(r), LabBundles.encode(b));
            T = LabOutbox.list();
            tc.verifyEqual(T.id, b.bundle_id);
            tc.verifyTrue(T.sealed);

            claim = LabOutbox.claim(b.bundle_id);
            tc.verifyNotEmpty(claim);
            tc.verifyEmpty(LabOutbox.claim(b.bundle_id), "only one can win a claim");
            LabOutbox.finish(claim, "held", Reason="a subject to assign");
            T = LabOutbox.list(State="held");
            tc.verifyEqual(T.note, "a subject to assign");
            LabOutbox.move(b.bundle_id, "pending");
            claim = LabOutbox.claim(b.bundle_id);
            tc.verifyEqual(LabOutbox.recoverStale(MaxAge=60), 0, "a live claim is kept");
            pause(1.2);
            tc.verifyEqual(LabOutbox.recoverStale(MaxAge=1), 1, "a claim whose MATLAB stopped is given back");
            [~, st] = LabOutbox.read(b.bundle_id);
            tc.verifyEqual(st, "pending");
            claim = LabOutbox.claim(b.bundle_id);
            LabOutbox.finish(claim, "done");
            c = LabOutbox.counts();
            tc.verifyEqual([c.pending c.claimed c.held c.failed c.done], [0 0 0 0 1]);
        end

        function hasherInMatlabAndChangedFiles(tc)
            tc.enable();
            f = string(fullfile(tc.Top, "small.bin"));
            tc.writeBytes(f, uint8(1:200));
            it = LabBundles.item(f, ArtifactId=LabBundles.newId());
            [h, why] = LabHasher.hashNow(it);
            tc.verifyEqual([h, why], [fileSha256(f), ""]);

            b = tc.goldenBundle();
            b.bundle_id = LabBundles.newId();
            b.record.event.event_id = b.bundle_id;
            b.record.outputs = it;
            LabOutbox.put(b);
            tc.verifyEqual(LabHasher.work(), 1, "hashed and sealed");
            r = LabOutbox.read(b.bundle_id);
            tc.verifyTrue(LabBundles.isSealed(r));
            tc.verifyEqual(r.record.outputs.sha256, fileSha256(f));

            g = string(fullfile(tc.Top, "changes.bin"));
            tc.writeBytes(g, uint8(1:100));
            it2 = LabBundles.item(g, ArtifactId=LabBundles.newId());
            pause(1.1);
            tc.writeBytes(g, uint8(1:150));   % rewritten after it was captured
            tc.verifySubstring(LabHasher.changed(it2), "changed after it was captured");
            b2 = b;
            b2.bundle_id = LabBundles.newId();
            b2.record.event.event_id = b2.bundle_id;
            b2.record.outputs = it2;
            LabOutbox.put(b2);
            LabHasher.work();
            [~, st] = LabOutbox.read(b2.bundle_id);
            tc.verifyEqual(st, "held", "no hash of bytes that were not captured");
            T = LabOutbox.list(State="held");
            tc.verifySubstring(T.note, "changed after it was captured");
        end

        function hasherOutOfProcess(tc)
            tc.enable(HashInProcessMB=1e-4);   % about 100 bytes: everything bigger goes out of process
            f = string(fullfile(tc.Top, "large.bin"));
            tc.writeBytes(f, uint8(mod(0:99999, 256)));
            b = tc.goldenBundle();
            b.record.outputs = LabBundles.item(f, ArtifactId=LabBundles.newId());
            LabOutbox.put(b);
            LabHasher.work();   % starts the job
            t0 = tic;
            while toc(t0) < 90 && ~LabBundles.isSealed(LabOutbox.read(b.bundle_id))
                pause(0.5);
                LabHasher.work();
            end
            r = LabOutbox.read(b.bundle_id);
            tc.verifyTrue(LabBundles.isSealed(r), "the separate process hashed it");
            tc.verifyEqual(r.record.outputs.sha256, fileSha256(f));
        end

        function setProcessingWhenOff(tc)
            ds = tc.dataset();
            f = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            tc.writeBytes(f, uint8(1:64));
            r = EphysDataset.processingRecord("file", f, struct("runId", ""), struct("A", 1));
            ds.setProcessing("spikes", r);
            p = ds.Processing.spikes;
            tc.verifyNotEmpty(regexp(p.event_id, '^[0-9a-f-]{36}$', 'once'));
            tc.verifySubstring(p.created_at, "T");
            tc.verifyEqual(numel(p.outputs), 1);
            tc.verifyEqual(p.outputs{1}.bytes, 64);
            tc.verifyEqual(p.outputs{1}.sha256, "", "not hashed while the database is off");
            c = LabOutbox.counts();
            tc.verifyEqual(c.pending, 0, "nothing for the outbox while the database is off");
            tc.verifyFalse(isfile(LabCapture.sessionFile(ds.Folder, ds.Name)));
        end

        function setProcessingCapturesAStep(tc)
            tc.enable();
            ds = tc.dataset();
            f = string(fullfile(ds.outputFolder(), ds.Name + "_spikes.mat"));
            tc.writeBytes(f, uint8(1:64));
            r = EphysDataset.processingRecord("file", f, struct("runId", "run1"), struct("A", 1));
            started = datetime("now", "TimeZone", "local") - seconds(5);
            ds.setProcessing("spikes", r, StartedAt=started, Provenance=ephysProvenance(RunId="run1"));
            p = ds.Processing.spikes;
            tc.verifyEqual(p.outputs{1}.sha256, fileSha256(f), "a small file is hashed at once");
            [b, st] = LabOutbox.read(p.event_id);
            tc.verifyEqual(st, "pending");
            tc.verifyTrue(LabBundles.isSealed(b), "complete: sealed");
            ev = b.record.event;
            tc.verifyEqual(ev.event_type, "analysis");
            tc.verifyEqual(ev.detail.pipeline_name, "ephys_analysis/spikes");
            tc.verifyEqual(ev.detail.parameters_json, string(jsonencode(p)), "the record's own JSON text");
            tc.verifyEqual(ev.occurred_at, LabBundles.timeText(started), "occurred when it started");
            o = b.record.outputs;
            tc.verifyEqual([o.root, o.rel, o.role, o.kind], ...
                ["nas", "SYNTH-01/SYNTH-01_260702_141210/" + ds.Name + "_spikes.mat", "spikes", "threshold_spikes"]);
            in = b.record.inputs;
            tc.verifyEqual(numel(in), numel(ds.Files), "it read the raw files");
            tc.verifyTrue(all([in.role] == "raw"));
            ses = LabCapture.session(ds.Folder, ds.Name);
            tc.verifyEqual(b.record.dataset.session_id, ses.session_id, "the session file names the session");
            tc.verifyEqual(b.record.dataset.subject_folder_id, "SYNTH-01");

            % Rewritten with other bytes: a new file that replaces the first.
            pause(1.1);
            tc.writeBytes(f, uint8(64:-1:1));
            ds.setProcessing("spikes", EphysDataset.processingRecord("file", f, struct("runId", "run2"), struct("A", 2)));
            q = ds.Processing.spikes;
            tc.verifyNotEqual(q.event_id, p.event_id);
            b2 = LabOutbox.read(q.event_id);
            tc.verifyEqual(b2.record.outputs.replaces, p.outputs{1}.artifact_id);
            tc.verifyNotEqual(b2.record.outputs.artifact_id, p.outputs{1}.artifact_id);

            % Rewritten with the same bytes: the same file, nothing replaced.
            pause(1.1);
            tc.writeBytes(f, uint8(64:-1:1));
            ds.setProcessing("spikes", EphysDataset.processingRecord("file", f, struct("runId", "run3"), struct("A", 2)));
            b3 = LabOutbox.read(ds.Processing.spikes.event_id);
            tc.verifyEqual(b3.record.outputs.replaces, "");
            tc.verifyEqual(b3.record.outputs.artifact_id, b2.record.outputs.artifact_id);

            % The same record set again: nothing captured twice.
            n = LabOutbox.counts().pending;
            ds.setProcessing("spikes", ds.Processing.spikes);
            tc.verifyEqual(LabOutbox.counts().pending, n);

            % The run record lists the records of its run.
            L = EphysPipeline.labEvents(ds, "run3");
            tc.verifyEqual(numel(L), 1);
            tc.verifyEqual([L{1}.kind, L{1}.event_id], ["spikes", ds.Processing.spikes.event_id]);
        end

        function sortStampedAtLaunchKeepsItsId(tc)
            tc.enable();
            ds = tc.dataset();
            rd = string(fullfile(ds.outputFolder(), "kilosort4"));
            mkdir(rd);
            for n = ["spike_times.npy" "spike_clusters.npy" "templates.npy" "params.py" "ks4_status.json"]
                tc.writeBytes(fullfile(rd, n), uint8(1:32));
            end
            r = EphysDataset.processingRecord("results_dir", rd, struct("runId", ""), struct("Th", 9));
            r.sorter = "kilosort4";
            r.bin_file = string(fullfile(ds.outputFolder(), ds.Name + ".bin"));
            r = LabCapture.launchStamp(r);
            id = r.event_id;
            ds.setProcessing("sorting", r);
            tc.verifyEqual(ds.Processing.sorting.event_id, id, "recorded under the id it was launched with");
            b = LabOutbox.read(id);
            o = b.record.outputs;
            names = strings(1, numel(o));
            for k = 1:numel(o); [~, nm, ex] = fileparts(o(k).path); names(k) = nm + ex; end
            tc.verifyFalse(any(names == "ks4_status.json"), "the run's status file is no result");
            tc.verifyEqual(o(names == "spike_times.npy").role, "spikes");
            tc.verifyEqual(o(names == "templates.npy").role, "waveforms");
            tc.verifyEqual(o(names == "params.py").role, "derived");
            tc.verifyEqual(b.record.event.detail.pipeline_name, "kilosort4");
            tc.verifyEqual(b.record.event.occurred_at, r.started_at, "it occurred when it was launched");
        end

        function copiedSessionRecordsRecordingAndBehavior(tc)
            tc.enable();
            dest = string(fullfile(tc.Top, "G-1", "G-1_260702_141210"));
            mkdir(dest);
            raw = string(fullfile(dest, "amplifier.dat"));
            tc.writeBytes(raw, uint8(1:100));
            ep = string(fullfile(dest, "G-1_260702T141500.mat"));
            tc.writeBytes(ep, uint8(1:50));
            files = struct("path", {raw, ep}, "sha256", {fileSha256(raw), ""}, "is_epsych", {false, true});
            info = struct("dest", dest, "subject", "G-1", "reader", "intan", ...
                "recording_time", datetime(2026, 7, 2, 14, 12, 10), "recording_duration", 600, ...
                "source_dir", "D:\rig\G-1_260702_141210", "files", files, "epsych_file", ep, ...
                "epsych_time", datetime(2026, 7, 2, 14, 15, 0), "epsych_trials", 42, ...
                "finished", datetime("now", "TimeZone", "local"));
            LabCapture.copiedSession(info);
            ses = LabCapture.session(dest, "G-1_260702_141210");
            tc.verifyNotEqual(ses.recording_event_id, "");
            tc.verifyNotEqual(ses.behavior_event_id, "");
            rec = LabOutbox.read(ses.recording_event_id);
            tc.verifyEqual(rec.record.event.event_type, "recording");
            tc.verifyEqual(rec.record.event.detail.acquisition_system_code, "intan_rhx");
            tc.verifyEqual(rec.record.event.detail.duration_s, 600);
            tc.verifyEqual(rec.record.outputs.sha256, fileSha256(raw), "the copy's own hash, not taken again");
            tc.verifyEqual(rec.record.dataset.recording_start, ...
                LabBundles.timeText(datetime(2026, 7, 2, 14, 12, 10, "TimeZone", LabDBSettings.load().LabTimeZone)), ...
                "a rig time without a zone is read in the lab's time zone");
            beh = LabOutbox.read(ses.behavior_event_id);
            tc.verifyEqual(beh.record.event.event_type, "behavior");
            tc.verifyEqual(beh.record.event.detail.trials_completed, 42);
            tc.verifyEqual(beh.after, ses.recording_event_id, "sent after the recording");
            tc.verifyEqual(numel(ses.raw), 2, "the session file knows the raw files and their ids");
            n = LabOutbox.counts().pending;
            LabCapture.copiedSession(info);
            tc.verifyEqual(LabOutbox.counts().pending, n, "a session captured before is not captured again");
        end
    end
end
