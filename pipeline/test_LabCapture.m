classdef test_LabCapture < matlab.unittest.TestCase
    %test_LabCapture  What the toolbox keeps for the lab database: bundles, the outbox, hashes, capture.
    %   Everything runs in a temporary preference store and a temporary
    %   database folder; nothing is sent (there is no server) and nothing of
    %   the user's is touched.
    %
    %   The shared client's own tests (the SHA-256 vectors, bundles, the golden
    %   bundle, the outbox and its claims, the hashes) are in the CarasLabDB
    %   repository: tests/matlab/LabClientTests.m.
    %
    %   Covered: EphysDataset.setProcessing through LabCapture (off:
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
            tc.Restore = {AppPrefs.useTemporary(), labclient.Secrets.useFake(), labclient.DB.useTemporary(), ...
                labclient.Sync.useManual()};
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
            s = labclient.Settings.defaults();
            s.Enabled = true;
            s.Server = "labdb.test";
            s.Username = "jdoe";
            s.Roots = struct("Name", "nas", "Path", tc.Top);
            s.HashInProcessMB = opts.HashInProcessMB;
            labclient.Settings.save(s);
            s = labclient.Settings.load();
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
    end

    methods (Test)
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
            c = labclient.Outbox.counts();
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
            tc.verifyEqual(p.outputs{1}.sha256, labclient.fileSha256(f), "a small file is hashed at once");
            [b, st] = labclient.Outbox.read(p.event_id);
            tc.verifyEqual(st, "pending");
            tc.verifyTrue(labclient.Bundles.isSealed(b), "complete: sealed");
            ev = b.record.event;
            tc.verifyEqual(ev.event_type, "analysis");
            tc.verifyEqual(ev.detail.pipeline_name, "ephys_analysis/spikes");
            tc.verifyEqual(ev.detail.parameters_json, string(jsonencode(p)), "the record's own JSON text");
            tc.verifyEqual(ev.occurred_at, labclient.Bundles.timeText(started), "occurred when it started");
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
            b2 = labclient.Outbox.read(q.event_id);
            tc.verifyEqual(b2.record.outputs.replaces, p.outputs{1}.artifact_id);
            tc.verifyNotEqual(b2.record.outputs.artifact_id, p.outputs{1}.artifact_id);

            % Rewritten with the same bytes: the same file, nothing replaced.
            pause(1.1);
            tc.writeBytes(f, uint8(64:-1:1));
            ds.setProcessing("spikes", EphysDataset.processingRecord("file", f, struct("runId", "run3"), struct("A", 2)));
            b3 = labclient.Outbox.read(ds.Processing.spikes.event_id);
            tc.verifyEqual(b3.record.outputs.replaces, "");
            tc.verifyEqual(b3.record.outputs.artifact_id, b2.record.outputs.artifact_id);

            % The same record set again: nothing captured twice.
            n = labclient.Outbox.counts().pending;
            ds.setProcessing("spikes", ds.Processing.spikes);
            tc.verifyEqual(labclient.Outbox.counts().pending, n);

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
            b = labclient.Outbox.read(id);
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
            files = struct("path", {raw, ep}, "sha256", {labclient.fileSha256(raw), ""}, "is_epsych", {false, true});
            info = struct("dest", dest, "subject", "G-1", "reader", "intan", ...
                "recording_time", datetime(2026, 7, 2, 14, 12, 10), "recording_duration", 600, ...
                "source_dir", "D:\rig\G-1_260702_141210", "files", files, "epsych_file", ep, ...
                "epsych_time", datetime(2026, 7, 2, 14, 15, 0), "epsych_trials", 42, ...
                "finished", datetime("now", "TimeZone", "local"));
            LabCapture.copiedSession(info);
            ses = LabCapture.session(dest, "G-1_260702_141210");
            tc.verifyNotEqual(ses.recording_event_id, "");
            tc.verifyNotEqual(ses.behavior_event_id, "");
            rec = labclient.Outbox.read(ses.recording_event_id);
            tc.verifyEqual(rec.record.event.event_type, "recording");
            tc.verifyEqual(rec.record.event.detail.acquisition_system_code, "intan_rhx");
            tc.verifyEqual(rec.record.event.detail.duration_s, 600);
            tc.verifyEqual(rec.record.outputs.sha256, labclient.fileSha256(raw), "the copy's own hash, not taken again");
            tc.verifyEqual(rec.record.dataset.recording_start, ...
                labclient.Bundles.timeText(datetime(2026, 7, 2, 14, 12, 10, "TimeZone", labclient.Settings.load().LabTimeZone)), ...
                "a rig time without a zone is read in the lab's time zone");
            beh = labclient.Outbox.read(ses.behavior_event_id);
            tc.verifyEqual(beh.record.event.event_type, "behavior");
            tc.verifyEqual(beh.record.event.detail.trials_completed, 42);
            tc.verifyEqual(beh.after, ses.recording_event_id, "sent after the recording");
            tc.verifyEqual(numel(ses.raw), 2, "the session file knows the raw files and their ids");
            n = labclient.Outbox.counts().pending;
            LabCapture.copiedSession(info);
            tc.verifyEqual(labclient.Outbox.counts().pending, n, "a session captured before is not captured again");
        end
    end
end
