classdef test_OutputTransfer < matlab.unittest.TestCase
    %test_OutputTransfer  Tests for OutputTransfer and the pipeline's Transfer section.
    %   OutputTransfer on small files in a temporary folder: the dataset
    %   folders under the destination (the key's folders, paths below the
    %   output folder kept, hidden folders left out), IfExists ("version"
    %   folders decided once per dataset, "overwrite", "skip"), a move that
    %   removes only once closed and keeps Keep= files, OnMoved, SHA-256
    %   checks, a batch waiting for a background sort's status file (an
    %   earlier run's status ignored, a failed sort skipped), cancel, a file
    %   changed after its batch was copied, progress, and its refusals.
    %   Then the pipeline: the Transfer section (defaults, round trip,
    %   validation), plan rows, run() copying each output after its step or
    %   after the run into <Destination>/<subject>/<session>, a new version
    %   folder on a second run, a move, transferOutputs after step methods,
    %   a moved sort folder recorded as the dataset's sorting folder, and the
    %   scripts. Everything that copies needs Windows (robocopy) and is
    %   skipped elsewhere.
    %
    %   Usage
    %     runtests("test_OutputTransfer")
    %     run_all_tests("test_OutputTransfer")

    properties
        Root string   % temporary folder
        Src  string   % a dataset's output folder: <Root>/out/rec1
        Dest string   % the transfer's destination (not created)
    end

    methods (TestMethodSetup)
        function makeTree(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Root = string(f.Folder);
            tc.Src = fullfile(tc.Root, "out", "rec1");
            tc.Dest = fullfile(tc.Root, "dest");
            mkdir(fullfile(tc.Src, "kilosort4", "sub"));
            mkdir(fullfile(tc.Src, "kilosort4", ".phy"));
            writeBytes(fullfile(tc.Src, "rec1_extract_LFP.mat"), 300000);
            writeBytes(fullfile(tc.Src, "rec1_spikes.mat"), 1000);
            writeBytes(fullfile(tc.Src, "kilosort4", "params.py"), 100);
            writeBytes(fullfile(tc.Src, "kilosort4", "sub", "a.npy"), 2000);
            writeBytes(fullfile(tc.Src, "kilosort4", ".phy", "cache.bin"), 500);
        end
    end

    methods (Test)
        % ---------------------------------------------------------------- where files go
        function copiesIntoTheKeyFolders(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            X = tc.transfer();
            X.add("S1/rec1", [fullfile(tc.Src, "rec1_extract_LFP.mat") fullfile(tc.Src, "kilosort4")], ...
                Base=tc.Src, Label="a");
            X.close();
            X.wait(LogEvery=Inf, Timeout=120);
            folder = fullfile(tc.Dest, "S1", "rec1");
            tc.verifyEqual(X.table().State, "done");
            tc.verifyTrue(isfile(fullfile(folder, "rec1_extract_LFP.mat")));
            tc.verifyTrue(isfile(fullfile(folder, "kilosort4", "sub", "a.npy")), 'a folder keeps its subfolders');
            tc.verifyFalse(isfolder(fullfile(folder, "kilosort4", ".phy")), 'hidden folders are left out');
            tc.verifyTrue(isfile(fullfile(tc.Src, "rec1_spikes.mat")) && isfile(fullfile(tc.Src, "kilosort4", "params.py")), ...
                'a copy leaves the sources');
            tc.verifyEqual(dir(fullfile(folder, "rec1_extract_LFP.mat")).bytes, 300000);
            [st, msg, f] = X.statusOf("S1\rec1");
            tc.verifyEqual(st, "done");
            tc.verifyEqual(f, string(folder));
            tc.verifySubstring(msg, "copied 3 file(s)");
            info = X.progress();
            tc.verifyEqual(info.Fraction, 1);
            tc.verifyEqual(info.Phase, "done");
            tc.verifyEqual(info.BytesDone, info.BytesTotal);
        end

        function fileOutsideTheBaseKeepsItsName(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            other = fullfile(tc.Root, "elsewhere");
            mkdir(other);
            writeBytes(fullfile(other, "rec1_chronux.mat"), 50);
            X = tc.transfer();
            X.add("S1/rec1", fullfile(other, "rec1_chronux.mat"), Base=tc.Src);
            X.close();
            X.wait(LogEvery=Inf, Timeout=120);
            tc.verifyTrue(isfile(fullfile(tc.Dest, "S1", "rec1", "rec1_chronux.mat")));
        end

        function missingPathsAreSkipped(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            X = tc.transfer();
            X.add("S1/rec1", fullfile(tc.Src, "not_there.mat"), Base=tc.Src);
            X.close();
            X.wait(LogEvery=Inf, Timeout=120);
            tc.verifyEqual(X.Batches(1).State, "skipped");
            tc.verifySubstring(X.Batches(1).Message, "nothing to copy");
            tc.verifyFalse(isfolder(tc.Dest));
        end

        % ---------------------------------------------------------------- IfExists
        function versionFolderOncePerDataset(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            X = tc.transfer();
            X.add("S1/rec1", fullfile(tc.Src, "rec1_spikes.mat"), Base=tc.Src);
            X.close(); X.wait(LogEvery=Inf, Timeout=120);
            X = tc.transfer();
            X.add("S1/rec1", fullfile(tc.Src, "rec1_spikes.mat"), Base=tc.Src, Label="first");
            X.poll(); X.wait(LogEvery=Inf, Timeout=120);   % the folder exists now, holding this transfer's file
            X.add("S1/rec1", fullfile(tc.Src, "rec1_extract_LFP.mat"), Base=tc.Src, Label="second");
            X.close(); X.wait(LogEvery=Inf, Timeout=120);
            v2 = fullfile(tc.Dest, "S1", "rec1_v2");
            tc.verifyTrue(isfile(fullfile(v2, "rec1_spikes.mat")) && isfile(fullfile(v2, "rec1_extract_LFP.mat")), ...
                'a transfer keeps the version folder it chose for the dataset');
            tc.verifyFalse(isfile(fullfile(tc.Dest, "S1", "rec1", "rec1_extract_LFP.mat")));
            tc.verifyEqual(OutputTransfer.versionFolder(tc.Dest, "S1/rec1", "version"), string(fullfile(tc.Dest, "S1", "rec1_v3")));
            tc.verifyEqual(OutputTransfer.versionFolder(tc.Dest, "S1/rec1", "overwrite"), string(fullfile(tc.Dest, "S1", "rec1")));
            tc.verifyEqual(OutputTransfer.versionFolder(tc.Dest, "S2/new", "version"), string(fullfile(tc.Dest, "S2", "new")));
        end

        function overwriteReplacesAndSkipKeeps(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            folder = fullfile(tc.Dest, "S1", "rec1");
            mkdir(folder);
            writeBytes(fullfile(folder, "rec1_spikes.mat"), 10);   % an older copy
            X = tc.transfer(IfExists="skip");
            X.add("S1/rec1", [fullfile(tc.Src, "rec1_spikes.mat") fullfile(tc.Src, "rec1_extract_LFP.mat")], Base=tc.Src);
            X.close(); X.wait(LogEvery=Inf, Timeout=120);
            tc.verifyEqual(dir(fullfile(folder, "rec1_spikes.mat")).bytes, 10, 'skip leaves a file already there');
            tc.verifyTrue(isfile(fullfile(folder, "rec1_extract_LFP.mat")), 'skip copies the missing ones');
            tc.verifySubstring(X.Batches(1).Message, "1 already there");
            X = tc.transfer(IfExists="overwrite");
            X.add("S1/rec1", fullfile(tc.Src, "rec1_spikes.mat"), Base=tc.Src);
            X.close(); X.wait(LogEvery=Inf, Timeout=120);
            tc.verifyEqual(dir(fullfile(folder, "rec1_spikes.mat")).bytes, 1000, 'overwrite replaces it');
            tc.verifyFalse(isfolder(fullfile(tc.Dest, "S1", "rec1_v2")));
        end

        % ---------------------------------------------------------------- move
        function moveRemovesOnceClosed(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            keep = fullfile(tc.Root, "rec1_manifest.json");
            writeBytes(keep, 20);
            calls = containers.Map('KeyType', 'double', 'ValueType', 'any');
            X = tc.transfer(Method="move", Verify="hash");
            X.add("S1/rec1", [fullfile(tc.Src, "kilosort4") fullfile(tc.Src, "rec1_spikes.mat")], Base=tc.Src, ...
                OnMoved=@(f, n) record(calls, [string(f), string(n)], "repointed"));
            X.add("S1/rec1", keep, Base=tc.Src, Label="manifest", Keep=keep);
            X.wait(LogEvery=Inf, Timeout=120);
            tc.verifyEqual(X.Batches(1).State, "copied", 'a move waits for close() before it removes anything');
            tc.verifyTrue(isfile(fullfile(tc.Src, "rec1_spikes.mat")));
            tc.verifyFalse(X.Done);
            X.close();
            X.wait(LogEvery=Inf, Timeout=120);
            tc.verifyTrue(X.Done);
            tc.verifyEqual(X.table().State, ["done"; "done"]);
            tc.verifyFalse(isfile(fullfile(tc.Src, "rec1_spikes.mat")));
            tc.verifyFalse(isfile(fullfile(tc.Src, "kilosort4", "params.py")));
            tc.verifyFalse(isfolder(fullfile(tc.Src, "kilosort4", "sub")), 'emptied subfolders go');
            tc.verifyTrue(isfile(fullfile(tc.Src, "kilosort4", ".phy", "cache.bin")), 'what was not copied stays');
            tc.verifyTrue(isfile(keep), 'Keep= files are copied, never removed');
            tc.verifyTrue(isfile(fullfile(tc.Dest, "S1", "rec1", "rec1_manifest.json")));
            tc.verifyTrue(isfile(fullfile(tc.Dest, "S1", "rec1", "kilosort4", "params.py")));
            tc.verifyEqual(double(calls.Count), 1, 'OnMoved once');
            tc.verifyEqual(calls(1), [string(fullfile(tc.Src, "kilosort4")), string(fullfile(tc.Dest, "S1", "rec1", "kilosort4"))], ...
                'OnMoved with the folder and its new place');
            tc.verifySubstring(X.Batches(1).Message, "moved 3 file(s)");
            tc.verifySubstring(X.Batches(1).Message, "repointed");
            tc.verifySubstring(X.statusOf("S1/rec1"), "done");
        end

        % ---------------------------------------------------------------- waiting for a sort
        function waitsForTheSort(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            ks = fullfile(tc.Src, "kilosort4");
            status = fullfile(ks, "ks4_status.json");
            writeJsonFile(status, struct('state', "done", 'message', ""));   % an earlier run's
            since = datetime('now') + seconds(10);
            X = tc.transfer();
            X.add("S1/rec1", ks, Base=tc.Src, Label="sorting", WaitFor=status, Since=since);
            X.poll();
            tc.verifyEqual(X.Batches(1).State, "waiting", 'a status file older than Since is an earlier run''s');
            info = X.progress();
            tc.verifyEqual(info.Waiting, 1);
            X = tc.transfer();
            X.add("S1/rec1", ks, Base=tc.Src, Label="sorting", WaitFor=status, Since=NaT);
            X.close();
            X.wait(LogEvery=Inf, Timeout=120);
            tc.verifyEqual(X.Batches(1).State, "done", 'copied once the sort says done');
            tc.verifyTrue(isfile(fullfile(tc.Dest, "S1", "rec1", "kilosort4", "params.py")));
            writeJsonFile(status, struct('state', "error", 'message', "out of memory"));
            X = tc.transfer(IfExists="overwrite");
            X.add("S1/rec1", ks, Base=tc.Src, Label="sorting", WaitFor=status, Since=NaT);
            X.close();
            X.wait(LogEvery=Inf, Timeout=120);
            tc.verifyEqual(X.Batches(1).State, "skipped");
            tc.verifySubstring(X.Batches(1).Message, "out of memory");
        end

        % ---------------------------------------------------------------- cancel
        function cancelStops(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            X = tc.transfer(Method="move");
            X.add("S1/rec1", fullfile(tc.Src, "rec1_spikes.mat"), Base=tc.Src, Label="first");
            X.wait(LogEvery=Inf, Timeout=120);
            X.add("S1/rec1", fullfile(tc.Src, "kilosort4"), Base=tc.Src, Label="second", ...
                WaitFor=fullfile(tc.Src, "kilosort4", "ks4_status.json"));
            X.cancel();
            X.wait(LogEvery=Inf, Timeout=120);
            tc.verifyTrue(X.Done && X.Cancelled);
            tc.verifyEqual(X.table().State, ["done"; "cancelled"]);
            tc.verifyTrue(isfile(fullfile(tc.Src, "rec1_spikes.mat")), 'a cancelled move removes nothing');
            tc.verifySubstring(X.Batches(1).Message, "nothing removed here");
            X.add("S1/rec1", fullfile(tc.Src, "rec1_extract_LFP.mat"), Base=tc.Src);
            tc.verifyEqual(X.Batches(3).State, "cancelled", 'a batch added after a cancel is not copied');
        end

        % ---------------------------------------------------------------- changed after the copy
        function changedAfterCopyIsCopiedAgainOnClose(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            X = tc.transfer();
            X.add("S1/rec1", [fullfile(tc.Src, "rec1_spikes.mat") fullfile(tc.Src, "kilosort4")], Base=tc.Src);
            X.wait(LogEvery=Inf, Timeout=120);
            pause(2.5);   % the time must differ by more than 2 s
            writeBytes(fullfile(tc.Src, "rec1_spikes.mat"), 1234);
            writeBytes(fullfile(tc.Src, "kilosort4", "quality_metrics.json"), 77);   % written later (the export reads the units)
            X.close();
            X.wait(LogEvery=Inf, Timeout=120);
            folder = fullfile(tc.Dest, "S1", "rec1");
            tc.verifyEqual(dir(fullfile(folder, "rec1_spikes.mat")).bytes, 1234);
            tc.verifyTrue(isfile(fullfile(folder, "kilosort4", "quality_metrics.json")));
            tc.verifyEqual(numel(X.Batches), 2);
            tc.verifySubstring(X.Batches(2).Label, "(again)");
        end

        % ---------------------------------------------------------------- refusals
        function refusals(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.verifyError(@() OutputTransfer("relative\folder"), 'OutputTransfer:BadDestination');
            X = tc.transfer();
            tc.verifyError(@() X.add("../up", tc.Src), 'OutputTransfer:BadKey');
            tc.verifyError(@() X.add("C:/abs", tc.Src), 'OutputTransfer:BadKey');
            X.close();
            tc.verifyError(@() X.add("S1/rec1", tc.Src), 'OutputTransfer:Closed');
            tc.verifyTrue(OutputTransfer.isFullPath("\\server\share\x") && OutputTransfer.isFullPath("D:\x") ...
                && ~OutputTransfer.isFullPath("x\y") && ~OutputTransfer.isFullPath("D:x"));
        end

        % ================================================================ the pipeline
        function configSection(tc)
            cfg = EphysPipelineConfig();
            d = cfg.Transfer;
            tc.verifyEqual(string(fieldnames(d)).', ["Enabled" "Destination" "Method" "When" "IfExists" "Verify"]);
            tc.verifyFalse(d.Enabled);
            tc.verifyEqual([d.Method d.When d.IfExists d.Verify], ["copy" "step" "version" "size"]);
            tc.verifyFalse(ismember("transfer", EphysPipelineConfig.StepNames), 'not a step');
            cfg.Transfer = struct('Enabled', true, 'Destination', "S:\backup", 'Method', "move", 'When', "run", ...
                'IfExists', "skip", 'Verify', "hash");
            f = fullfile(tc.Root, "cfg.json");
            cfg.save(f);
            back = EphysPipelineConfig.load(f);
            tc.verifyTrue(back.isequalConfig(cfg), 'the section round-trips through JSON');
            tc.verifyEqual(back.Transfer.Method, "move");
        end

        function validation(tc)
            cfg = EphysPipelineConfig();
            cfg.Project.Root = tc.Root;
            cfg.Project.OutputRoot = fullfile(tc.Root, "out");
            cfg.Transfer.Enabled = true;
            tc.verifyTrue(hasIssue(cfg, "Destination", "error"), 'no destination');
            cfg.Transfer.Destination = "relative";
            tc.verifyTrue(hasIssue(cfg, "Destination", "error"), 'not a full path');
            cfg.Transfer.Destination = cfg.Project.OutputRoot;
            tc.verifyTrue(hasIssue(cfg, "Destination", "error"), 'the output root itself');
            cfg.Transfer.Destination = fullfile(cfg.Project.OutputRoot, "copies");
            tc.verifyTrue(hasIssue(cfg, "Destination", "error"), 'inside the output root');
            cfg.Transfer.Destination = tc.Root;
            tc.verifyTrue(hasIssue(cfg, "Destination", "error"), 'the project root');
            cfg.Transfer.Destination = tc.Dest;
            tc.verifyTrue(hasIssue(cfg, "Destination", "warning"), 'a destination not there yet is a warning');
            mkdir(tc.Dest);
            tc.verifyFalse(hasIssue(cfg, "Destination", ""), 'a good destination');
            cfg.Transfer.Enabled = false;
            cfg.Transfer.Destination = "";
            tc.verifyFalse(any(cfg.validate().Step == "transfer"), 'off: not checked');
        end

        function runCopiesEachOutputAfterItsStep(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            [cfg, key] = tc.project();
            cfg.Transfer = struct('Enabled', true, 'Destination', tc.Dest, 'Method', "copy", 'When', "step", ...
                'IfExists', "version", 'Verify', "size");
            pipe = EphysPipeline(cfg);
            pipe.LogFcn = @(m) [];
            T = pipe.plan();
            row = T(T.Step == "transfer", :);
            folder = string(fullfile(tc.Dest, key));
            tc.verifyEqual(height(row), 1);
            tc.verifyEqual(row.Status, "ready");
            tc.verifyEqual(row.Output, folder);
            seen = containers.Map('KeyType', 'double', 'ValueType', 'any');
            pipe.TransferFcn = @(X) record(seen, X, []);
            R = pipe.run();
            tc.verifyEqual(double(seen.Count), 1, 'TransferFcn hears of the transfer once');
            tc.verifyTrue(seen(1) == pipe.Transfer);
            d = pipe.selected();
            spikes = d.Name + "_spikes.mat";
            tc.verifyTrue(isfile(fullfile(folder, spikes)), 'the spikes file under <Destination>/<subject>/<session>');
            tc.verifyTrue(isfile(fullfile(folder, d.Name + "_artifacts.json")), 'the artifact cache too');
            tc.verifyTrue(isfile(fullfile(folder, d.Name + "_manifest.json")), 'and the manifest');
            tr = R(R.Step == "transfer", :);
            tc.verifyEqual(height(tr), 1, 'one transfer row per dataset');
            tc.verifyEqual(tr.Status, "done");
            tc.verifyEqual(tr.Output, folder);
            tc.verifyTrue(pipe.Transfer.Done);
            tc.verifyTrue(isfile(fullfile(d.outputFolder(), spikes)), 'a copy leaves the outputs');
            labels = [pipe.Transfer.Batches.Label];
            tc.verifyTrue(all(ismember(["artifacts" "spikes" "manifest"], labels)), 'a batch per output, as each step recorded it');

            % again: a new version folder, in the plan and in the copy
            T = pipe.plan();
            row = T(T.Step == "transfer", :);
            tc.verifyEqual(row.Status, "exists: new version");
            tc.verifyEqual(row.Output, folder + "_v2");
            cfg.Transfer.When = "run";
            pipe.Config = cfg;
            pipe.run();
            tc.verifyTrue(isfile(fullfile(folder + "_v2", spikes)), 'the second run''s copies go to <session>_v2');
            tc.verifyEqual(numel(unique([pipe.Transfer.Batches.Label])), numel([pipe.Transfer.Batches.Label]));

            % move, overwriting
            cfg.Transfer.Method = "move";
            cfg.Transfer.IfExists = "overwrite";
            pipe.Config = cfg;
            pipe.run();
            tc.verifyFalse(isfile(fullfile(d.outputFolder(), spikes)), 'a move removes the outputs here');
            tc.verifyTrue(isfile(fullfile(folder, spikes)));
            tc.verifyTrue(isfile(d.manifestFile()), 'the manifest stays');
            tc.verifyFalse(isfolder(folder + "_v3"));
        end

        function dryRunCopiesNothing(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            [cfg, ~] = tc.project();
            cfg.Transfer = struct('Enabled', true, 'Destination', tc.Dest, 'Method', "copy", 'When', "step", ...
                'IfExists', "version", 'Verify', "size");
            pipe = EphysPipeline(cfg);
            pipe.LogFcn = @(m) [];
            R = pipe.run(DryRun=true);
            tc.verifyEmpty(pipe.Transfer);
            tc.verifyFalse(any(R.Step == "transfer"));
            tc.verifyFalse(isfolder(tc.Dest));
        end

        function transferOutputsAfterStepMethods(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            [cfg, key] = tc.project();
            cfg.Transfer.Destination = tc.Dest;   % Enabled is not read: the script asks for it
            pipe = EphysPipeline(cfg);
            pipe.LogFcn = @(m) [];
            pipe.checkRun();
            pipe.runSpikeDetection();
            X = pipe.transferOutputs();
            tc.verifyTrue(X.Done);
            d = pipe.selected();
            tc.verifyTrue(isfile(fullfile(tc.Dest, key, d.Name + "_spikes.mat")));
            txt = EphysPipelineScript.compact(cfg, ConfigFile=fullfile(tc.Root, "cfg.json"));
            tc.verifySubstring(txt, "% pipe.transferOutputs();");
            cfg.Transfer.Enabled = true;
            txt = EphysPipelineScript.compact(cfg, ConfigFile=fullfile(tc.Root, "cfg.json"));
            tc.verifySubstring(txt, newline + "pipe.transferOutputs();");
            txt = EphysPipelineScript.standalone(cfg);
            tc.verifySubstring(txt, "transfer = OutputTransfer(");
            tc.verifySubstring(txt, "transfer.wait();");
            tc.verifyFalse(contains(txt, "EphysPipeline("));
        end

        function standaloneScriptCopies(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            [cfg, key] = tc.project();
            cfg.Artifacts.Enabled = false;
            cfg.Transfer = struct('Enabled', true, 'Destination', tc.Dest, 'Method', "copy", 'When', "step", ...
                'IfExists', "version", 'Verify', "size");
            cfg.Project.SaveScript = false;
            f = fullfile(tc.Root, "standalone_transfer.m");
            EphysPipelineScript.standalone(cfg, File=f);
            evalc("run('" + f + "')");
            P = EphysProject(cfg.Project.Root, OutputRoot=cfg.Project.OutputRoot);
            d = P.Datasets(P.findByKey(key));
            tc.verifyTrue(isfile(fullfile(tc.Dest, key, d.Name + "_spikes.mat")), 'the standalone script copies the spikes file');
        end

        function movedSortBecomesTheSortingFolder(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            [cfg, key] = tc.project();
            cfg.Spikes.Enabled = false;
            cfg.Artifacts.Enabled = false;
            cfg.Transfer = struct('Enabled', true, 'Destination', tc.Dest, 'Method', "move", 'When', "run", ...
                'IfExists', "version", 'Verify', "size");
            pipe = EphysPipeline(cfg);
            pipe.LogFcn = @(m) [];
            d = pipe.selected();
            ks = string(d.kilosortDir());
            makePhyFixture(ks, 30000);
            tc.verifyTrue(d.hasKilosortResults());
            pipe.addResult("sorting", d.Name, "done", "Kilosort4 finished", ks);   % as a blocking sort records it
            X = pipe.transferOutputs();
            moved = string(fullfile(tc.Dest, key, "kilosort4"));
            tc.verifyTrue(X.Done);
            tc.verifyTrue(isfile(fullfile(moved, "params.py")));
            tc.verifyFalse(isfile(fullfile(ks, "params.py")));
            tc.verifyEqual(d.SortingDir, moved, 'the moved sort folder is the dataset''s sorting folder');
            m = readJsonFile(d.manifestFile());
            tc.verifyEqual(string(m.sorting.results_dir), moved, 'and the manifest says so');
            tc.verifyTrue(d.hasKilosortResults());
        end
    end

    methods
        function X = transfer(tc, varargin)
            X = OutputTransfer(tc.Dest, varargin{:}, LogFcn=@(m) []);
        end

        function [cfg, key] = project(tc)
            %project  One synthetic Intan recording, SUBJ1/SUBJ1_260101_120000, with
            %   the Spikes step and cached artifact detection on.
            rng(3);
            key = "SUBJ1/SUBJ1_260101_120000";
            rec = fullfile(tc.Root, "raw", "SUBJ1", "SUBJ1_260101_120000");
            mkdir(rec);
            spb = 128;
            writeSyntheticRHD(fullfile(rec, "rec.rhd"), uint16(32768 + randi([-300 300], 4, 8 * spb)), ...
                zeros(1, 8 * spb), 30000, spb);
            cfg = EphysPipelineConfig();
            cfg.Name = "transfer test";
            cfg.Project.Root = fullfile(tc.Root, "raw");
            cfg.Project.OutputRoot = fullfile(tc.Root, "outputs");
            cfg.Project.SaveScript = false;
            cfg.Spikes.Enabled = true;
            cfg.Artifacts.Enabled = true;
            cfg.Artifacts.CacheIntervals = true;
        end
    end
end


function writeBytes(f, n)
fid = fopen(f, 'w');
fwrite(fid, randi(255, n, 1, 'uint8'));
fclose(fid);
end


function out = record(map, value, out)
%record  Keep VALUE in MAP (a handle), as call number MAP.Count + 1; return OUT.
map(double(map.Count) + 1) = value; %#ok<NASGU> a handle: the caller sees it
end


function tf = hasIssue(cfg, field, severity)
I = cfg.validate();
I = I(I.Step == "transfer" & I.Field == field, :);
tf = height(I) > 0 && (severity == "" || any(I.Severity == severity));
end
