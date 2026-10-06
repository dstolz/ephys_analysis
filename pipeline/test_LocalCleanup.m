classdef test_LocalCleanup < matlab.unittest.TestCase
    %test_LocalCleanup  Tests for planLocalCleanup and runLocalCleanup.
    %   Writes a small synthetic recording as the "source", copies it into a
    %   local session folder with a session_manifest.json as the Copy tab
    %   would, adds a sorting folder, a .bin and pipeline outputs, then checks
    %   what a clean up would remove and keep (by kind, Visualize's envelopes
    %   among them, and by preprocessing step), and that it removes only
    %   that: deleted, moved into a folder (cleanupMoveTargets: a file
    %   already there skipped, overwritten, or the dataset's files put in a
    %   new version folder), or sent to the Recycle Bin (whose items it
    %   empties again afterwards).
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
            tc.verifyEqual(tc.action(T, "kilosort4/temp_wh.dat"), "remove");
            tc.verifyEqual(tc.action(T, tc.Name + ".bin"), "remove");
            tc.verifyEqual(tc.action(T, tc.Name + ".json"), "remove");
            for keep = ["session_manifest.json", tc.Name + "_manifest.json", tc.Name + "_extract_LFP.mat", ...
                    tc.Name + "_spikes.mat", "kilosort4/params.py", ...
                    "kilosort4/spike_times.npy", tc.epsychName()]
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
                string(fullfile(tc.Local, "kilosort4", "temp_wh.dat")));
            tc.verifySubstring(T.Reason(T.File == fullfile(tc.Local, tc.Name + ".bin")), "not selected");
        end

        function envelopesGoAsADisplayCache(tc)
            % Visualize's envelopes (<Name>_envelope_<what>.dat in the output
            % folder, here the recording folder, so not taken for raw .dat
            % files) go by default; a build's .partial only once it is an
            % hour old, since a newer one may be being written.
            env = fullfile(tc.Local, tc.Name + "_envelope_" + ["recording" "LFP"] + ".dat");
            old = fullfile(tc.Local, tc.Name + "_envelope_bin.dat.tp1a2b_3c4d.partial");
            fresh = fullfile(tc.Local, tc.Name + "_envelope_recording_car.dat.tp5e6f_7a8b.partial");
            for f = [env old fresh]
                tc.writeBytes(f, 500);
            end
            tc.assumeTrue(setFileModifiedTime(old, datetime('now') - hours(2)), 'a file''s modification time can be set');
            T = planLocalCleanup(tc.dataset());
            mine = ismember(T.File, [env old fresh]);
            tc.verifyEqual(nnz(mine), 4);
            tc.verifyTrue(all(T.Category(mine) == "envelope") && all(T.Step(mine) == ""));
            tc.verifyTrue(all(T.Action(ismember(T.File, [env old])) == "remove"), 'envelopes go by default');
            tc.verifyEqual(T.What(T.File == env(1)), "Visualize's min / max envelope of the recording");
            tc.verifyEqual(T.What(T.File == env(2)), "Visualize's min / max envelope of LFP");
            tc.verifySubstring(T.Reason(T.File == env(1)), "builds it again");
            tc.verifyEqual(T.What(T.File == old), "Unfinished envelope of the sorting .bin (a build MATLAB left)");
            r = T(T.File == fresh, :);
            tc.verifyEqual([r.Action r.What], ["keep" "Envelope of the recording (CAR) being built"], ...
                'a partial file written in the last hour may be a build under way: kept');
            tc.verifySubstring(r.Reason, "in the last hour");

            T = planLocalCleanup(tc.dataset(), Remove="raw");
            tc.verifyTrue(all(T.Action(T.Category == "envelope") == "keep"), 'kept unless selected');
            tc.verifySubstring(T.Reason(T.File == env(1)), "not selected");

            R = runLocalCleanup(planLocalCleanup(tc.dataset(), Remove="envelope"));
            tc.verifyEqual(sort(R.File), sort([env old].'), 'only the envelopes go');
            tc.verifyTrue(all(R.Status == "removed"), strjoin(R.Message, "; "));
            tc.verifyFalse(any(isfile([env old])));
            tc.verifyTrue(isfile(fresh), 'the partial file a build may be writing stays');
            rec = readJsonFile(fullfile(tc.Local, tc.Name + "_cleanup.json"));
            tc.verifyEqual(unique(string({rec.runs(1).removed.category})), "envelope");

            % with an output folder of its own, the envelopes are found there
            out = fullfile(tc.Root, "out", tc.Name);
            mkdir(out);
            mua = fullfile(out, tc.Name + "_envelope_MUA.dat");
            tc.writeBytes(mua, 300);
            d = tc.dataset();
            d.OutputDir = out;
            T = planLocalCleanup(d);
            r = T(T.File == mua, :);
            tc.verifyEqual([r.Category r.Action r.Root], ["envelope" "remove" string(out)]);
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

            % Its sorting .bin is <Name>_ks4.bin, so toBin never writes over
            % the recording; that pair is what "bin" removes.
            raw = fullfile(local, tc.Name + ".bin");
            tc.verifyEqual(d.BinFile, string(fullfile(local, tc.Name + "_ks4.bin")));
            before = tc.bytesOf(raw);
            d.toBin();
            tc.verifyEqual(tc.bytesOf(raw), before, 'toBin leaves the recording''s data file as it was');
            T = planLocalCleanup(d, Remove="bin");
            pair = fullfile(local, tc.Name + ["_ks4.bin" "_ks4.json"]);
            tc.verifyEqual(T.Category(ismember(T.File, pair)).', ["bin" "bin"]);
            tc.verifyTrue(all(T.Action(ismember(T.File, pair)) == "remove"));
            tc.verifyEqual([T.Category(T.File == raw) T.Action(T.File == raw)], ["raw" "keep"]);
        end

        function anotherRecordingsOutputsAreKept(tc)
            % Two recordings with one name share <OutputRoot>/<Name>: what the
            % other one wrote there (its .bin and sort, a .mat whose
            % provenance names it) never goes with this dataset's outputs.
            out = fullfile(tc.Root, "out", tc.Name);
            other = fullfile(tc.Root, "EPHYS", "SYNTH-02", tc.Name);
            mkdir(fullfile(out, "kilosort4"));
            tc.writeBytes(fullfile(out, "kilosort4", "spike_times.npy"), 100);
            tc.writeBytes(fullfile(out, tc.Name + ".bin"), 3000);
            writeJsonFile(fullfile(out, tc.Name + ".json"), struct('n_chan_bin', 4, ...
                'bin_file', fullfile(out, tc.Name + ".bin"), 'source_folder', other));
            tc.writeMat(fullfile(out, tc.Name + "_extract_LFP.mat"), ...
                struct('Y', 1, 'info', 1, 'conversion', struct('dataset', tc.Name, 'sourceFolder', other)));
            tc.writeMat(fullfile(out, tc.Name + "_spikes.mat"), ...
                struct('detected', 1, 'units', 1, 'conversion', struct('dataset', tc.Name, 'sourceFolder', tc.Local)));
            d = tc.dataset();
            d.OutputDir = out;
            d.DatasetKey = "SYNTH-01/" + tc.Name;
            T = planLocalCleanup(d, Remove=["bin" "sorting" "signals" "spikes"]);
            tc.verifyEqual(T.Action(T.File == fullfile(out, tc.Name + "_spikes.mat")), "remove", 'its own output still goes');
            for f = [fullfile(out, "kilosort4", "spike_times.npy"), fullfile(out, tc.Name + [".bin" ".json" "_extract_LFP.mat"])]
                tc.verifyEqual(T.Action(T.File == f), "keep", f);
            end
            tc.verifySubstring(T.Reason(T.File == fullfile(out, tc.Name + ".bin")), other);
        end

        function binInItsOwnFolderIsRemovedWithTheBin(tc)
            % A dataset with a BinDir keeps its .bin and sidecar there, in a
            % folder that holds other datasets' .bin files too: "bin" finds
            % those two files only, and a clean up leaves the folder and the
            % others alone.
            binDir = string(fullfile(tc.Root, "bins"));
            mkdir(binDir);
            d = tc.dataset();
            d.BinDir = binDir;
            mine = fullfile(binDir, tc.Name + [".bin" ".json"]);
            tc.writeBytes(mine(1), 4000);
            writeJsonFile(mine(2), struct('n_chan_bin', 4, 'bin_file', mine(1), 'source_folder', tc.Local));
            neighbour = fullfile(binDir, "SYNTH-02_260916_110907.bin");
            tc.writeBytes(neighbour, 4000);
            T = planLocalCleanup(d, Remove="bin");
            rows = T(ismember(T.File, mine), :);
            tc.verifyEqual(rows.Category.', ["bin" "bin"]);
            tc.verifyTrue(all(rows.Action == "remove"));
            tc.verifyEqual(rows.Root.', [binDir binDir], 'the BinDir is the root of its files');
            tc.verifyFalse(any(T.File == neighbour), 'another dataset''s .bin in the shared folder is not listed');
            tc.verifyEqual(tc.action(T, tc.Name + ".bin"), "remove", 'a .bin left in the output folder goes too');
            R = runLocalCleanup(T);
            tc.verifyTrue(all(R.Status == "removed"), strjoin(R.Message, "; "));
            tc.verifyFalse(any(isfile(mine)), 'its .bin and sidecar are gone');
            tc.verifyTrue(isfile(neighbour) && isfolder(binDir), 'the shared folder and the other .bin stay');
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
            tc.verifyEqual(string(rec.schema), "ephys-local-cleanup/3");
            run = rec.runs(1);
            if iscell(rec.runs); run = rec.runs{1}; end
            tc.verifyEqual([string(run.method) string(run.destination)], ["delete" ""]);
            tc.verifyEqual(numel(run.removed), height(R));
            tc.verifyEqual(double(run.bytesRemoved), sum(R.Bytes));
            srcs = string({run.removed.source});
            tc.verifyTrue(any(startsWith(srcs, tc.Source)), 'the record says where the raw files came from');

            % a second clean up finds nothing more to remove and appends nothing
            T2 = planLocalCleanup(tc.dataset());
            tc.verifyFalse(any(T2.Action == "remove"));
            tc.verifyEqual(T2.What(T2.File == fullfile(tc.Local, tc.Name + "_cleanup.json")), "Clean-up record");
            fid = fopen(fullfile(tc.Local, "kilosort4", "temp_wh.dat"), 'w');
            fwrite(fid, zeros(1, 64, 'int16'), 'int16'); fclose(fid);
            runLocalCleanup(planLocalCleanup(tc.dataset()));
            rec = readJsonFile(fullfile(tc.Local, tc.Name + "_cleanup.json"));
            tc.verifyEqual(numel(rec.runs), 2, 'a later clean up appends its run');
        end

        function runSkipsFilesThatChangedSinceThePreview(tc)
            T = planLocalCleanup(tc.dataset());
            dat = string(fullfile(tc.Local, "kilosort4", "temp_wh.dat"));
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

        function openEphysRawFilesBelowTheRecordNode(tc)
            % An Open Ephys session keeps its recording under Record Node
            % folders: the files the Copy tab listed there go like any raw
            % file, and without a manifest they are raw and kept.
            name = "SYNTH-01_2026-09-16_11-09-07";
            src = fullfile(tc.Root, "nas3", name);
            local = fullfile(tc.Root, "EPHYS3", "SYNTH-01", name);
            tc.writeRecording(src, "openephys-binary");
            copyfile(src, local);
            D = dir(fullfile(src, "**", "*"));
            D = D(~[D.isdir] & ~endsWith({D.name}, ".mat"));
            full = string(fullfile({D.folder}, {D.name}));
            rel = extractAfter(full, strlength(src) + 1);
            files = struct('relativePath', cellstr(rel), 'source', cellstr(full), 'sizeBytes', num2cell([D.bytes]));
            m = struct('manifestVersion', 3, 'subject', "SYNTH-01", ...
                'recording', struct('reader', "openephys", 'sourceDir', src, 'destDir', local, 'files', {num2cell(files)}));
            writeJsonFile(fullfile(local, "session_manifest.json"), m);

            d = EphysDataset(local, AutoMetadata=false);
            T = planLocalCleanup(d, Remove="raw");
            dat = contains(T.File, filesep + "Record Node 101" + filesep) & endsWith(T.File, "continuous.dat");
            tc.verifyEqual(nnz(dat), 1);
            tc.verifyEqual([T.Category(dat) T.Action(dat)], ["raw" "remove"]);
            tc.verifyEqual(sort(T.File(T.Category == "raw")), sort(string(fullfile(local, rel(:)))), ...
                'every file the manifest lists is raw');

            delete(fullfile(local, "session_manifest.json"));
            T = planLocalCleanup(EphysDataset(local, AutoMetadata=false), Remove="raw");
            dat = contains(T.File, filesep + "Record Node 101" + filesep) & endsWith(T.File, "continuous.dat");
            tc.verifyEqual([T.Category(dat) T.Action(dat)], ["raw" "keep"]);
            tc.verifySubstring(T.Reason(dat), "no source copy is known");
        end

        function nothingToCleanIsAnEmptyPlan(tc)
            T = planLocalCleanup(EphysDataset.empty(1, 0));
            tc.verifyEqual(height(T), 0);
            R = runLocalCleanup(T);
            tc.verifyEqual(height(R), 0);
        end

        function sortingStepTakesTheKilosortFolderAndTheBin(tc)
            ks = fullfile(tc.Local, "kilosort4");
            before = tc.snapshot();
            T = planLocalCleanup(tc.dataset(), Remove="sorting");
            inKs = startsWith(T.File, ks + filesep);
            bin = ismember(T.File, fullfile(tc.Local, tc.Name + [".bin" ".json"]));
            tc.verifyEqual(nnz(inKs), 4);
            tc.verifyTrue(all(T.Action(inKs | bin) == "remove") && all(T.Step(inKs | bin) == "sorting"), ...
                'everything under kilosort4, and the .bin + .json, go with the Sorting step');
            tc.verifySubstring(T.Reason(T.File == fullfile(ks, "ks4_status.json")), "Sorting step");
            tc.verifyFalse(any(T.Action(~(inKs | bin)) == "remove"), 'nothing else goes, not even raw files');
            tc.verifyEqual(tc.action(T, tc.Name + "_extract_LFP.mat"), "keep");

            R = runLocalCleanup(T);
            tc.verifyTrue(all(R.Status == "removed"), strjoin(R.Message, "; "));
            tc.verifyFalse(isfolder(ks), 'the emptied kilosort4 folder is removed too');
            tc.verifyEqual(tc.snapshot(), sort([setdiff(before, T.File(T.Action == "remove")), ...
                string(fullfile(tc.Local, tc.Name + "_cleanup.json"))]), 'every other file stays');
            rec = readJsonFile(fullfile(tc.Local, tc.Name + "_cleanup.json"));
            tc.verifyEqual(unique(string({rec.runs(1).removed.step})), "sorting");
        end

        function stepOutputsAreFoundByWhatTheyHold(tc)
            % Configured suffixes and output folders: a .mat is placed by its
            % variables (DatasetOutputs), else by its default name.
            conv = struct('dataset', tc.Name);
            shared = fullfile(tc.Root, "shared");
            mkdir(shared);
            tc.writeMat(fullfile(tc.Local, tc.Name + "_lfp.mat"), struct('Y', 1, 'info', 1, 'conversion', conv));
            tc.writeMat(fullfile(tc.Local, tc.Name + "_spk.mat"), ...
                struct('detected', 1, 'units', 1, 'conversion', conv));
            tc.writeMat(fullfile(tc.Local, tc.Name + "_behavior.mat"), struct('behavior', 1, 'conversion', conv));
            tc.writeMat(fullfile(shared, tc.Name + "_ft.mat"), struct('export', conv, 'event', 1));
            tc.writeMat(fullfile(shared, "OTHER_ft.mat"), struct('export', struct('dataset', "OTHER"), 'event', 1));
            tc.writeBytes(fullfile(tc.Local, tc.Name + "_events.mat"), 60);
            tc.writeBytes(fullfile(tc.Local, tc.Name + "_artifacts.json"), 30);
            tc.writeBytes(fullfile(tc.Local, "~" + tc.Name + "_extract_MUA.partial.mat"), 70);
            tc.writeBytes(fullfile(tc.Local, tc.Name + "_notes.txt"), 10);
            kcsdMeta = @(name) string(jsonencode(struct('tool', "EphysDataset.exportKCSD", 'dataset', name)));
            writeNPZ(fullfile(shared, tc.Name + "_kcsd.npz"), struct('ele_pos', [0; 1], 'meta', kcsdMeta(tc.Name)), ...
                Shapes=struct('meta', "scalar"));
            writeNPZ(fullfile(tc.Local, tc.Name + "_b_kcsd.npz"), struct('ele_pos', [0; 1], 'meta', kcsdMeta("OTHER")), ...
                Shapes=struct('meta', "scalar"));
            tc.writeBytes(fullfile(tc.Local, "~" + tc.Name + "_kcsd.partial.npz"), 40);
            expect = [tc.Name + "_lfp.mat" "signals"; tc.Name + "_extract_LFP.mat" "signals"
                "~" + tc.Name + "_kcsd.partial.npz" "export"
                "~" + tc.Name + "_extract_MUA.partial.mat" "signals"; tc.Name + "_spk.mat" "spikes"
                tc.Name + "_spikes.mat" "spikes"; tc.Name + "_behavior.mat" "behavior"
                tc.Name + "_events.mat" "behavior"; tc.Name + "_artifacts.json" "artifacts"];
            steps = ["signals" "spikes" "behavior" "artifacts" "export"];

            T = planLocalCleanup(tc.dataset(), Remove=steps, SearchDirs=shared);
            for k = 1:height(expect)
                r = T(T.File == fullfile(tc.Local, expect(k, 1)), :);
                tc.verifyEqual([r.Step r.Action], [expect(k, 2) "remove"], expect(k, 1));
            end
            ft = T(T.File == fullfile(shared, tc.Name + "_ft.mat"), :);
            tc.verifyEqual([ft.Step ft.Action ft.What ft.Root], ["export" "remove" "FieldTrip export" string(shared)], ...
                'an output in a search folder is listed below that folder');
            tc.verifyFalse(any(contains(T.File, "OTHER_ft")), 'another dataset''s file in the search folder is not listed');
            kc = T(T.File == fullfile(shared, tc.Name + "_kcsd.npz"), :);
            tc.verifyEqual([kc.Step kc.Action kc.What], ["export" "remove" "kCSD export"], ...
                'a kCSD .npz is placed by its meta member');
            tc.verifyEqual(tc.action(T, tc.Name + "_b_kcsd.npz"), "keep", 'a .npz whose meta names another dataset stays');
            tc.verifyEqual(T.What(T.File == fullfile(tc.Local, "~" + tc.Name + "_extract_MUA.partial.mat")), ...
                "Unfinished signals output (extract) (a failed write)");
            tc.verifyEqual(tc.action(T, tc.Name + "_notes.txt"), "keep");
            tc.verifyFalse(any(T.Action(T.Step == "" | T.Step == "sorting") == "remove"), ...
                'only the ticked steps'' files go');

            T = planLocalCleanup(tc.dataset(), Remove="spikes", SearchDirs=shared);
            tc.verifyEqual(sort(T.File(T.Action == "remove")), ...
                sort(string(fullfile(tc.Local, tc.Name + ["_spk.mat"; "_spikes.mat"]))));
        end

        function handPickedSortingFolderIsKept(tc)
            curated = fullfile(tc.Root, "curated", tc.Name);
            mkdir(curated);
            tc.writeBytes(fullfile(curated, "params.py"), 50);
            tc.writeBytes(fullfile(curated, "cluster_group.tsv"), 20);
            d = tc.dataset();
            d.SortingDir = curated;
            T = planLocalCleanup(d, Remove="sorting");
            mine = startsWith(T.File, curated + filesep);
            tc.verifyEqual(nnz(mine), 2);
            tc.verifyTrue(all(T.Action(mine) == "keep") && all(T.Step(mine) == ""));
            tc.verifySubstring(T.Reason(find(mine, 1)), "chosen by hand");
            tc.verifyEqual(tc.action(T, "kilosort4/ks4_status.json"), "remove", 'the step''s own folder still goes');
        end

        function moveKeepsTheLayoutAndSkipsWhatIsThere(tc)
            dest = fullfile(tc.Root, "removed");
            T = planLocalCleanup(tc.dataset(), Remove="sorting");
            tc.verifyError(@() runLocalCleanup(T, Method="move", Destination=fullfile(tc.Local, "old")), ...
                'runLocalCleanup:Destination');
            tc.verifyError(@() runLocalCleanup(T, Method="move"), 'runLocalCleanup:Destination');
            tc.verifyError(@() runLocalCleanup(T, Method="move", Destination="relative\folder"), ...
                'runLocalCleanup:Destination');
            taken = fullfile(dest, tc.Name, tc.Name + ".json");
            mkdir(fileparts(taken));
            tc.writeBytes(taken, 5);

            R = runLocalCleanup(T, Method="move", Destination=dest);   % IfExists "skip", the default
            json = R.File == fullfile(tc.Local, tc.Name + ".json");
            tc.verifyEqual(R.Status(json), "skipped");
            tc.verifySubstring(R.Message(json), "already at " + taken);
            tc.verifyTrue(isfile(R.File(json)) && dir(taken).bytes == 5, 'neither file is touched');
            moved = R(~json, :);
            tc.verifyTrue(all(moved.Status == "removed"), strjoin(moved.Message, "; "));
            tc.verifyFalse(any(R.Replaced), 'nothing is replaced');
            want = string(fullfile(dest, tc.Name, extractAfter(moved.File, strlength(tc.Local) + 1)));
            tc.verifyEqual(moved.To, want, 'each file keeps its path below the dataset folder');
            tc.verifyTrue(all(isfile(want)) && ~any(isfile(moved.File)));
            tc.verifyEqual(dir(fullfile(dest, tc.Name, "kilosort4", "temp_wh.dat")).bytes, 4000);
            tc.verifyFalse(isfolder(fullfile(tc.Local, "kilosort4")));
            rec = readJsonFile(fullfile(tc.Local, tc.Name + "_cleanup.json"));
            tc.verifyEqual([string(rec.runs(1).method) string(rec.runs(1).destination) string(rec.runs(1).ifExists)], ...
                ["move" string(dest) "skip"]);
            tc.verifyEqual(sort(string({rec.runs(1).removed.to})).', sort(want));
            tc.verifyFalse(any([rec.runs(1).removed.replaced]));
        end

        function moveTargetsSayWhatIsAlreadyThere(tc)
            dest = string(fullfile(tc.Root, "removed"));
            T = planLocalCleanup(tc.dataset(), Remove="sorting");
            rm = T.Action == "remove";
            M = cleanupMoveTargets(T, dest);
            want = strings(height(T), 1);
            want(rm) = fullfile(dest, tc.Name, extractAfter(T.File(rm), strlength(tc.Local) + 1));
            tc.verifyEqual(M.Target, want, 'each Remove file''s place keeps its path below the dataset folder; Keep rows get none');
            tc.verifyEqual(M.To, want, 'nothing is there: every Remove file goes to its place');
            tc.verifyTrue(all(M.Taken == "") && all(M.Version == "") && ~isfolder(dest), ...
                'a folder that does not exist holds nothing, and looking does not make it');

            json = fullfile(dest, tc.Name, tc.Name + ".json");          % a file at one place
            params = fullfile(dest, tc.Name, "kilosort4", "params.py");  % a folder at another
            mkdir(params);
            tc.writeBytes(json, 5);
            before = tc.snapshot();
            M = cleanupMoveTargets(T, dest);
            tc.verifyEqual(tc.snapshot(), before, 'looking changes nothing');
            j = M.Target == json;
            p = M.Target == params;
            others = rm & ~j & ~p;
            tc.verifyEqual([M.Taken(j) M.Taken(p)], ["file" "folder"]);
            tc.verifyTrue(M.TakenBytes(j) == 5 && ~isnat(M.TakenDate(j)) && isnan(M.TakenBytes(p)) && isnat(M.TakenDate(p)));
            tc.verifyEqual([M.To(j) M.To(p)], ["" ""], 'skip, the default: neither goes');
            tc.verifySubstring(M.Note(j), "already at " + json);
            tc.verifySubstring(M.Note(p), "never replaces a folder");
            tc.verifyEqual(M.To(others), M.Target(others), 'the rest go to their places');
            tc.verifyEqual(unique(M.Version(rm)), string(fullfile(dest, tc.Name + "_v2")), 'the dataset''s first free version folder');

            M = cleanupMoveTargets(T, dest, IfExists="overwrite");
            tc.verifyEqual([M.To(j) M.To(p)], [json ""], 'overwrite: over a file, never over a folder');

            mkdir(fullfile(dest, tc.Name + "_v2"));   % taken, so the next one
            M = cleanupMoveTargets(T, dest, IfExists="version");
            v3 = string(fullfile(dest, tc.Name + "_v3"));
            tc.verifyEqual(M.To(rm), fullfile(v3, extractAfter(T.File(rm), strlength(tc.Local) + 1)), ...
                'version: every file of the dataset goes to the first free version folder, the set kept whole');
            tc.verifyTrue(all(M.Note == ""));

            % Checked: decided again without looking; with the taken ones kept, no version folder is needed
            T2 = T;
            T2.Action(j | p) = "keep";
            M2 = cleanupMoveTargets(T2, dest, IfExists="version", Checked=M);
            tc.verifyEqual(M2.To(others), M.Target(others), 'nothing of the dataset is taken now: each goes to its place');
            tc.verifyEqual([M2.To(j) M2.Taken(j) M2.Version(j)], ["" "file" v3], 'a row now kept is not moved; the look is kept');
            tc.verifyError(@() cleanupMoveTargets(T, dest, Checked=cleanupMoveTargets(T2, dest)), 'cleanupMoveTargets:Checked', ...
                'a Remove row Checked did not look at');
            tc.verifyError(@() cleanupMoveTargets(T, dest, Checked=M(1:end-1, :)), 'cleanupMoveTargets:Checked');

            % one file per place
            T3 = [T; T(find(others, 1), :)];
            M3 = cleanupMoveTargets(T3, dest);
            tc.verifyEqual(M3.To(end), "");
            tc.verifySubstring(M3.Note(end), "another file of this clean up goes to");
        end

        function moveOverwritesWhenAsked(tc)
            dest = fullfile(tc.Root, "removed");
            T = planLocalCleanup(tc.dataset(), Remove="sorting");
            json = fullfile(dest, tc.Name, tc.Name + ".json");
            params = fullfile(dest, tc.Name, "kilosort4", "params.py");
            mkdir(params);
            tc.writeBytes(json, 5);

            R = runLocalCleanup(T, Method="move", Destination=dest, IfExists="overwrite");
            j = R.File == fullfile(tc.Local, tc.Name + ".json");
            p = R.File == fullfile(tc.Local, "kilosort4", "params.py");
            tc.verifyEqual([R.Status(j) R.Status(p)], ["removed" "skipped"]);
            tc.verifyTrue(all(R.Status(~p) == "removed"), strjoin(R.Message, "; "));
            tc.verifyEqual(R.Replaced, j, 'only the file that was there is replaced');
            tc.verifyEqual([dir(json).bytes, double(isfile(R.File(j)))], [30 0], 'the local file took the place of the one there');
            tc.verifySubstring(R.Message(p), "never replaces a folder");
            tc.verifyTrue(isfile(R.File(p)) && isfolder(params), 'a folder is never replaced: the file stays');
            tc.verifyEmpty(dir(fullfile(dest, "**", "*.replaced")), 'the replaced file is deleted, not left aside');
            rec = readJsonFile(fullfile(tc.Local, tc.Name + "_cleanup.json"));
            tc.verifyEqual(string(rec.runs(1).ifExists), "overwrite");
            removed = rec.runs(1).removed;
            tc.verifyEqual(string({removed([removed.replaced]).file}), R.File(j), 'the record says which file replaced one');
        end

        function moveCanWriteANewVersion(tc)
            dest = fullfile(tc.Root, "removed");
            T = planLocalCleanup(tc.dataset(), Remove="sorting");
            taken = fullfile(dest, tc.Name, "kilosort4", "spike_times.npy");
            mkdir(fileparts(taken));
            tc.writeBytes(taken, 7);

            R = runLocalCleanup(T, Method="move", Destination=dest, IfExists="version");
            tc.verifyTrue(all(R.Status == "removed") && ~any(R.Replaced), strjoin(R.Message, "; "));
            want = string(fullfile(dest, tc.Name + "_v2", extractAfter(R.File, strlength(tc.Local) + 1)));
            tc.verifyEqual(R.To, want, 'every file of the dataset goes to the version folder, keeping its path');
            tc.verifyTrue(all(isfile(want)) && ~any(isfile(R.File)));
            tc.verifyEqual(dir(taken).bytes, 7, 'the file there is untouched');
            D = dir(fullfile(dest, tc.Name, "**", "*"));
            tc.verifyEqual(string({D(~[D.isdir]).name}), "spike_times.npy", ...
                'nothing went into the dataset''s own folder: it holds only the file that was there');
            rec = readJsonFile(fullfile(tc.Local, tc.Name + "_cleanup.json"));
            tc.verifyEqual(string(rec.runs(1).ifExists), "version");
        end

        function cancelLeavesTheRestInPlace(tc)
            T = planLocalCleanup(tc.dataset(), Remove="sorting");
            seen = zeros(1, 0);
            R = runLocalCleanup(T, CancelFcn=@stopAfterOne, ProgressFcn=@note);
            tc.verifyEqual(seen, 1, 'progress is reported before each file handled');
            tc.verifyEqual(R.Status(1), "removed");
            tc.verifyTrue(all(R.Status(2:end) == "skipped") && all(R.Message(2:end) == "cancelled"));
            tc.verifyTrue(all(isfile(R.File(2:end))));

            function note(evt)
                seen(end+1) = evt.index;
            end
            function tf = stopAfterOne()
                tf = ~isempty(seen);
            end
        end

        function recycleSendsFilesToTheBinAndChecksThem(tc)
            tc.assumeTrue(ispc, 'the Recycle Bin is Windows only');
            tc.addTeardown(@() tc.purgeFromRecycleBin());
            T = planLocalCleanup(tc.dataset(), Remove="sorting");
            R = runLocalCleanup(T, Method="recycle");
            tc.verifyTrue(all(R.Status == "removed"), strjoin(R.Message, "; "));
            tc.verifyEqual(R.To, repmat("Recycle Bin", height(R), 1), 'each file is found in the bin afterwards');
            tc.verifyFalse(any(isfile(R.File)));
            tc.verifyFalse(isfolder(fullfile(tc.Local, "kilosort4")));
            tc.verifyEqual(sort(tc.binned()), sort(R.File), 'the bin holds them under their own paths');
            rec = readJsonFile(fullfile(tc.Local, tc.Name + "_cleanup.json"));
            tc.verifyEqual(string(rec.runs(1).method), "recycle");
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
            % listing the recording's with their sources.
            copyfile(tc.Source, tc.Local);
            D = dir(tc.Source);
            D = D(~[D.isdir]);
            names = string({D.name});
            isEpsych = names == tc.epsychName();
            files = struct('relativePath', cellstr(names(~isEpsych)), ...
                'source', cellstr(fullfile(tc.Source, names(~isEpsych))), ...
                'sizeBytes', num2cell([D(~isEpsych).bytes]));
            m = struct('manifestVersion', 3, 'subject', "SYNTH-01", ...
                'recording', struct('reader', "intan", 'sourceDir', tc.Source, 'destDir', tc.Local, 'files', {num2cell(files)}), ...
                'epsych', struct('sourceFile', fullfile(tc.Source, tc.epsychName()), ...
                    'destFile', fullfile(tc.Local, tc.epsychName())));
            writeJsonFile(fullfile(tc.Local, "session_manifest.json"), m);

            % after preprocessing: a sort, a .bin, outputs, the manifest
            so = fullfile(tc.Local, "kilosort4");
            mkdir(so);
            tc.writeBytes(fullfile(so, "temp_wh.dat"), 4000);
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
            recs = m.recording.files;
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

        function [paths, records] = binned(tc)
            %binned  Original paths (and $I records) of what this test put in the Recycle Bin.
            paths = strings(0, 1); records = strings(0, 1);
            sid = string(char(System.Security.Principal.WindowsIdentity.GetCurrent().User.Value));
            D = dir(fullfile(extractBefore(tc.Root, 3) + "\", "$RECYCLE.BIN", sid, "$I*"));
            for k = 1:numel(D)
                f = string(fullfile(D(k).folder, D(k).name));
                fid = fopen(f, 'r', 'ieee-le');
                if fid < 0; continue; end
                b = fread(fid, inf, '*uint8');
                fclose(fid);
                if numel(b) < 30 || mod(numel(b), 2) ~= 0; continue; end
                p = string(strtok(char(typecast(b(29:end).', 'uint16')), char(0)));
                if startsWith(lower(p), lower(tc.Root))
                    paths(end+1, 1) = p; %#ok<AGROW>
                    records(end+1, 1) = f; %#ok<AGROW>
                end
            end
        end

        function purgeFromRecycleBin(tc)
            %purgeFromRecycleBin  Empty this test's items (the $I record and $R data of each) from the bin.
            [~, records] = tc.binned();
            for f = records.'
                [fo, na, ex] = fileparts(f);
                delete(f);
                delete(fullfile(fo, "$R" + extractAfter(na, 2) + ex));
            end
        end
    end

    methods (Static)
        function writeBytes(file, n)
            fid = fopen(file, 'w');
            fwrite(fid, zeros(1, n, 'uint8'), 'uint8');
            fclose(fid);
        end

        function b = bytesOf(file)
            fid = fopen(file, 'r');
            b = fread(fid, inf, '*uint8');
            fclose(fid);
        end

        function writeMat(file, S)
            save(file, '-struct', 'S');
        end
    end
end
