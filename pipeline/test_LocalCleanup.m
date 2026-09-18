classdef test_LocalCleanup < matlab.unittest.TestCase
    %test_LocalCleanup  Tests for planLocalCleanup and runLocalCleanup.
    %   Writes a small synthetic recording as the "source", copies it into a
    %   local session folder with a session_manifest.json as the Copy tab
    %   would, adds a sorting folder, a .bin and pipeline outputs, then checks
    %   what a clean up would remove and keep, and that it removes only that.
    %
    %   Usage
    %     runtests("test_LocalCleanup")
    %     run_all_tests("test_LocalCleanup")

    properties
        Root   string   % temporary folder
        Source string   % the recording as on the source
        Local  string   % its local session folder
        Name   string   % dataset name (= the folder leaf)
    end

    methods (TestMethodSetup)
        function makeSession(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Root = string(f.Folder);
            tc.Name = "SYNTH-01_260916_110907";
            tc.Source = fullfile(tc.Root, "nas", tc.Name);
            tc.Local = fullfile(tc.Root, "EPHYS", "SYNTH-01", tc.Name);
            tc.writeRecording(tc.Source, "traditional");
            tc.copyToLocal();
        end
    end

    methods (Test)
        function previewSaysWhatGoesAndWhatStays(tc)
            before = tc.snapshot();
            T = planLocalCleanup(tc.dataset());
            tc.verifyEqual(tc.snapshot(), before, 'planning changes nothing on disk');

            raw = T(T.Category == "raw", :);
            tc.verifyGreaterThanOrEqual(height(raw), 2);
            tc.verifyTrue(all(raw.Action == "remove"), 'copied raw files with a same-size source go');
            tc.verifyTrue(all(startsWith(raw.Source, tc.Source)), 'each names its source');
            tc.verifyEqual(tc.action(T, "kilosort4/si/sorter_output/recording.dat"), "remove");
            tc.verifyEqual(tc.action(T, tc.Name + ".bin"), "remove");
            tc.verifyEqual(tc.action(T, tc.Name + ".json"), "remove");
            for keep = ["session_manifest.json", tc.Name + "_manifest.json", tc.Name + "_extract_LFP.mat", ...
                    tc.Name + "_spikes.mat", "kilosort4/si/sorter_output/params.py", ...
                    "kilosort4/si/sorter_output/spike_times.npy", tc.epsychName()]
                tc.verifyEqual(tc.action(T, keep), "keep", keep + " is kept");
            end
            tc.verifyEqual(T.Category(T.File == fullfile(tc.Local, tc.epsychName())), "epsych");
            tc.verifyEqual(T.What(T.File == fullfile(tc.Local, tc.Name + "_extract_LFP.mat")), "Signals output (extract)");
            tc.verifyEqual(height(T), numel(before), 'every local file has one row');
            tc.verifyEqual(T.Action(1), "remove", 'Remove rows come first');
        end

        function rawStaysWithoutAVerifiedSourceCopy(tc)
            raw = tc.rawFiles();
            delete(fullfile(tc.Source, raw(1)));                       % gone from the source
            fid = fopen(fullfile(tc.Source, raw(2)), 'a'); fwrite(fid, 1, 'uint8'); fclose(fid);   % differs
            T = planLocalCleanup(tc.dataset());
            r1 = T(T.File == fullfile(tc.Local, raw(1)), :);
            r2 = T(T.File == fullfile(tc.Local, raw(2)), :);
            tc.verifyEqual([r1.Action r2.Action], ["keep" "keep"]);
            tc.verifySubstring(r1.Reason, "Not found at its source");
            tc.verifySubstring(r2.Reason, "they differ");
            tc.verifyTrue(all(T.Action(T.Category == "raw" & ~ismember(T.File, [r1.File r2.File])) == "remove"), ...
                'the other raw files still go');
        end

        function rawStaysWhenNotCopiedByTheCopyTab(tc)
            delete(fullfile(tc.Local, "session_manifest.json"));
            T = planLocalCleanup(tc.dataset());
            raw = T(T.Category == "raw", :);
            tc.verifyNotEmpty(raw);
            tc.verifyTrue(all(raw.Action == "keep"));
            tc.verifySubstring(raw.Reason(1), "no source copy is known");
        end

        function removeOptionLimitsTheKinds(tc)
            T = planLocalCleanup(tc.dataset(), Remove="sorter_copy");
            tc.verifyEqual(T.File(T.Action == "remove"), ...
                string(fullfile(tc.Local, "kilosort4", "si", "sorter_output", "recording.dat")));
            tc.verifySubstring(T.Reason(T.File == fullfile(tc.Local, tc.Name + ".bin")), "not selected");
        end

        function binaryRecordingDataFileIsRawNotBin(tc)
            % A binary-format recording keeps its samples in <Name>.bin next
            % to recording.json: that file is the recording, not toBin output.
            src = fullfile(tc.Root, "nas2", tc.Name);
            local = fullfile(tc.Root, "EPHYS2", tc.Name);
            tc.writeRecording(src, "binary");
            copyfile(src, local);
            d = EphysDataset(local, AutoMetadata=false);
            T = planLocalCleanup(d, Remove="bin");
            data = T(endsWith(T.File, ".bin"), :);
            tc.verifyNotEmpty(data);
            tc.verifyTrue(all(data.Category == "raw" & data.Action == "keep"));
        end

        function runRemovesOnlyTheRemoveRowsAndKeepsARecord(tc)
            T = planLocalCleanup(tc.dataset());
            R = runLocalCleanup(T);
            tc.verifyEqual(height(R), nnz(T.Action == "remove"));
            tc.verifyTrue(all(R.Status == "removed"), strjoin(R.Message, "; "));
            tc.verifyFalse(any(isfile(R.File)), 'every Remove file is gone');
            kept = T.File(T.Action == "keep");
            tc.verifyTrue(all(isfile(kept)), 'every Keep file is still there');
            tc.verifyTrue(all(isfile(fullfile(tc.Source, tc.rawFiles()))), 'the source is untouched');

            rec = readJsonFile(fullfile(tc.Local, tc.Name + "_cleanup.json"));
            tc.verifyEqual(string(rec.schema), "ephys-local-cleanup/1");
            run = rec.runs(1);
            if iscell(rec.runs); run = rec.runs{1}; end
            tc.verifyEqual(numel(run.removed), height(R));
            tc.verifyEqual(double(run.bytesRemoved), sum(R.Bytes));
            srcs = string({run.removed.source});
            tc.verifyTrue(any(startsWith(srcs, tc.Source)), 'the record says where the raw files came from');

            % a second clean up finds nothing more to remove and appends nothing
            T2 = planLocalCleanup(tc.dataset());
            tc.verifyFalse(any(T2.Action == "remove"));
            tc.verifyEqual(T2.What(T2.File == fullfile(tc.Local, tc.Name + "_cleanup.json")), "Clean-up record");
            fid = fopen(fullfile(tc.Local, "kilosort4", "si", "sorter_output", "recording.dat"), 'w');
            fwrite(fid, zeros(1, 64, 'int16'), 'int16'); fclose(fid);
            runLocalCleanup(planLocalCleanup(tc.dataset()));
            rec = readJsonFile(fullfile(tc.Local, tc.Name + "_cleanup.json"));
            tc.verifyEqual(numel(rec.runs), 2, 'a later clean up appends its run');
        end

        function runSkipsFilesThatChangedSinceThePreview(tc)
            T = planLocalCleanup(tc.dataset());
            dat = string(fullfile(tc.Local, "kilosort4", "si", "sorter_output", "recording.dat"));
            fid = fopen(dat, 'a'); fwrite(fid, 1, 'uint8'); fclose(fid);   % grew
            raw = tc.rawFiles();
            delete(fullfile(tc.Source, raw(1)));                           % source gone
            R = runLocalCleanup(T);
            tc.verifyEqual(R.Status(R.File == dat), "skipped");
            tc.verifySubstring(R.Message(R.File == dat), "size changed");
            r1 = R.File == fullfile(tc.Local, raw(1));
            tc.verifyEqual(R.Status(r1), "skipped");
            tc.verifySubstring(R.Message(r1), "source copy");
            tc.verifyTrue(isfile(dat) && isfile(fullfile(tc.Local, raw(1))), 'skipped files stay');
            tc.verifyTrue(all(R.Status(~(R.File == dat | r1)) == "removed"));
        end

        function nothingToCleanIsAnEmptyPlan(tc)
            T = planLocalCleanup(EphysDataset.empty(1, 0));
            tc.verifyEqual(height(T), 0);
            R = runLocalCleanup(T);
            tc.verifyEqual(height(R), 0);
        end
    end

    methods
        function writeRecording(~, folder, format)
            mkdir(folder);
            makeSyntheticRecording(folder, Format=format, Fs=5000, NumChannels=4, NumTrials=4, ...
                FileSeconds=10, SortedOutput=false, WriteManifest=false, Artifacts=false);
        end

        function copyToLocal(tc)
            % What copySessions leaves: the files, and session_manifest.json
            % listing the Intan ones with their sources.
            copyfile(tc.Source, tc.Local);
            D = dir(tc.Source);
            D = D(~[D.isdir]);
            names = string({D.name});
            isEpsych = names == tc.epsychName();
            files = struct('relativePath', cellstr(names(~isEpsych)), ...
                'source', cellstr(fullfile(tc.Source, names(~isEpsych))), ...
                'sizeBytes', num2cell([D(~isEpsych).bytes]));
            m = struct('manifestVersion', 2, 'subject', "SYNTH-01", ...
                'intan', struct('sourceDir', tc.Source, 'destDir', tc.Local, 'files', {num2cell(files)}), ...
                'epsych', struct('sourceFile', fullfile(tc.Source, tc.epsychName()), ...
                    'destFile', fullfile(tc.Local, tc.epsychName())));
            writeJsonFile(fullfile(tc.Local, "session_manifest.json"), m);

            % after preprocessing: a sort, a .bin, outputs, the manifest
            so = fullfile(tc.Local, "kilosort4", "si", "sorter_output");
            mkdir(so);
            tc.writeBytes(fullfile(so, "recording.dat"), 4000);
            tc.writeBytes(fullfile(so, "spike_times.npy"), 100);
            tc.writeBytes(fullfile(so, "params.py"), 50);
            tc.writeBytes(fullfile(tc.Local, "kilosort4", "ks4_status.json"), 20);
            tc.writeBytes(fullfile(tc.Local, tc.Name + ".bin"), 3000);
            tc.writeBytes(fullfile(tc.Local, tc.Name + ".json"), 30);
            tc.writeBytes(fullfile(tc.Local, tc.Name + "_extract_LFP.mat"), 200);
            tc.writeBytes(fullfile(tc.Local, tc.Name + "_spikes.mat"), 200);
            tc.writeBytes(fullfile(tc.Local, tc.Name + "_manifest.json"), 40);
        end

        function n = epsychName(tc)
            D = dir(fullfile(tc.Source, "*.mat"));
            n = string(D(1).name);
        end

        function names = rawFiles(tc)
            m = readJsonFile(fullfile(tc.Local, "session_manifest.json"));
            recs = m.intan.files;
            if iscell(recs); recs = [recs{:}]; end
            names = string({recs.relativePath});
        end

        function d = dataset(tc)
            d = EphysDataset(tc.Local, AutoMetadata=false);
        end

        function a = action(tc, T, rel)
            a = T.Action(T.File == string(fullfile(tc.Local, strrep(rel, "/", filesep))));
        end

        function s = snapshot(tc)
            D = dir(fullfile(tc.Local, "**", "*"));
            D = D(~[D.isdir]);
            s = sort(string(fullfile({D.folder}, {D.name})));
        end
    end

    methods (Static)
        function writeBytes(file, n)
            fid = fopen(file, 'w');
            fwrite(fid, zeros(1, n, 'uint8'), 'uint8');
            fclose(fid);
        end
    end
end
