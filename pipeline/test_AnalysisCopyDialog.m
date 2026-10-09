classdef test_AnalysisCopyDialog < matlab.unittest.TestCase
    %test_AnalysisCopyDialog  Tests for AnalysisCopyDialog (copy the files the analysis app needs).
    %   A folder of outputs of two datasets (no recordings: an EphysProject
    %   over it gives output-only datasets) with extracts, spikes, behavior,
    %   a sorting folder with a large feature file, a sorted binary, a
    %   manifest naming a probe file and an export the analysis does not
    %   read. The dialog (no window shown) lists the files for its settings,
    %   copies only those to <destination>/<dataset key> with the probe file
    %   beside the manifest, leaves an unticked dataset out, and refuses a
    %   relative destination. The copy is then read as the analysis would
    %   on another machine: the outputs, the units, and the probe file found
    %   beside the manifest (DatasetOutputs.probeFile, EphysDataset.ProbeFile).
    %   Copying needs Windows (robocopy) and is skipped elsewhere.
    %
    %   Usage
    %     runtests("test_AnalysisCopyDialog")
    %     run_all_tests("test_AnalysisCopyDialog")
    %
    %   See also AnalysisCopyDialog, DatasetOutputs.analysisFiles.

    properties
        Root string      % temporary folder
        Src string       % the root of the outputs: <Root>/src/<subject>/<session>
        Dest string      % where the copy goes (not created)
        Names string = ["s1_260901_100000" "s1_260902_100000"]
        Datasets         % the output-only datasets
        Probe string     % the probe file the manifests name (deleted after the copy: another machine)
    end

    methods (TestMethodSetup)
        function makeTree(tc)
            tc.applyFixture(AppPrefsFixture);
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Root = string(f.Folder);
            tc.Src = fullfile(tc.Root, "src");
            tc.Dest = fullfile(tc.Root, "dest");
            tc.Probe = fullfile(tc.Root, "probes", "p4.json");
            mkdir(fullfile(tc.Root, "probes"));
            writeJsonFile(tc.Probe, struct('chanMap', 0:3, 'xc', zeros(1, 4), 'yc', 0:3, 'kcoords', zeros(1, 4)));
            for n = tc.Names
                dir0 = fullfile(tc.Src, "s1", n);
                mkdir(dir0);
                S = struct('Y', struct('LFP', single(ones(10, 4))), ...
                    'info', struct('origFs', 30000, 'labels', {{'a'; 'b'; 'c'; 'd'}}, ...
                    'LFP', struct('Fs', 1000, 'nSamples', 5000)), ...
                    'events', struct('din0', [1 2; 3 4]), ...
                    'conversion', struct('dataset', n));
                save(fullfile(dir0, n + "_extract_LFP.mat"), '-struct', 'S');
                S.Y = struct('MUA', single(ones(10, 4)));
                S.info.MUA = struct('Fs', 1000, 'nSamples', 5000);
                save(fullfile(dir0, n + "_extract_MUA.mat"), '-struct', 'S');
                Sp = test_AnalysisCopyDialog.spikesFor(n);
                save(fullfile(dir0, n + "_spikes.mat"), '-struct', 'Sp');
                B = struct('behavior', struct('nTrials', 3), 'conversion', struct('dataset', n));
                save(fullfile(dir0, n + "_behavior.mat"), '-struct', 'B');
                C = struct('export', struct('dataset', n), 'epochs', 1);
                save(fullfile(dir0, n + "_epochs.mat"), '-struct', 'C');
                makePhyFixture(fullfile(dir0, "kilosort4"), 30000);
                writeBytes(fullfile(dir0, "kilosort4", "pc_features.npy"), 200000);
                writeBytes(fullfile(dir0, n + ".bin"), 5000);
                fid = fopen(fullfile(dir0, "kilosort4", "params.py"), 'w');
                fprintf(fid, 'dat_path = "%s.bin"\nn_channels_dat = 4\ndtype = "int16"\nsample_rate = 30000.\n', n);
                fclose(fid);
                writeJsonFile(fullfile(dir0, n + "_manifest.json"), struct('schema', "intan-dataset-manifest/2", ...
                    'name', n, 'metadata', struct('fs', 30000, 'num_channels', 4, 'duration_s', 5), ...
                    'sorting', struct('results_dir', "", 'source', "auto"), ...
                    'probe', struct('file', tc.Probe)));
            end
            ws = warning('off', 'EphysProject:OutputsOnly');
            restore = onCleanup(@() warning(ws));
            P = EphysProject(tc.Src);
            tc.Datasets = P.Datasets;
        end
    end

    methods (Test)
        function listsOnlyWhatTheAnalysisReads(tc)
            dlg = tc.dialog();
            T = dlg.Files{1};
            tc.verifyEqual(sort(unique(T.Kind)).', ["behavior" "extract" "manifest" "probe" "sorting" "spikes"]);
            tc.verifyFalse(any(contains(T.Path, ["_epochs" "pc_features"])), 'no exports, no large feature files');
            tc.verifyEqual(sum(T.Kind == "extract"), 2, 'LFP and MUA files');
            tc.verifyFalse(any(T.Kind == "sorted data"));
            tc.setControl(dlg, "SPIKE", true);
            tc.setControl(dlg, "MUA", false);
            tc.setControl(dlg, "SortedData", true);
            dlg.refresh();
            T = dlg.Files{1};
            tc.verifyEqual(sum(T.Kind == "extract"), 1, 'only the LFP file once MUA is off (no SPIKE file exists)');
            tc.verifyEqual(sum(T.Kind == "sorted data"), 1, 'the sorted binary on request');
            tbl = findobj(dlg.Fig, 'Type', 'uitable');
            tc.verifyEqual(tbl.Data.Dataset.', tc.keys(), 'the table lists the datasets by their folders');
            tc.verifyTrue(all(tbl.Data.Copy) && all(tbl.Data.Files > 0));
        end

        function copiesTheFilesToTheKeyFolders(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            dlg = tc.dialog();
            tc.setControl(dlg, "Dest", tc.Dest);
            dlg.start();
            dlg.wait(120);
            folder = fullfile(tc.Dest, "s1", tc.Names(1));
            tc.verifyTrue(all(isfile(fullfile(folder, tc.Names(1) + ["_manifest.json" "_behavior.mat" ...
                "_extract_LFP.mat" "_extract_MUA.mat" "_spikes.mat"]))));
            tc.verifyTrue(isfile(fullfile(folder, "kilosort4", "spike_times.npy")) ...
                && isfile(fullfile(folder, "kilosort4", "cluster_KSLabel.tsv")) ...
                && isfile(fullfile(folder, "kilosort4", "params.py")));
            tc.verifyFalse(isfile(fullfile(folder, "kilosort4", "pc_features.npy")), 'the large feature file stays');
            tc.verifyFalse(isfile(fullfile(folder, tc.Names(1) + "_epochs.mat")) ...
                || isfile(fullfile(folder, tc.Names(1) + ".bin")), 'exports and the sorted binary stay');
            tc.verifyTrue(isfile(fullfile(folder, "p4.json")), 'the probe file lands beside the manifest');
            tc.verifyTrue(isfile(fullfile(tc.Src, "s1", tc.Names(1), tc.Names(1) + "_epochs.mat")), 'the sources stay');
            tbl = findobj(dlg.Fig, 'Type', 'uitable');
            tc.verifyEqual(tbl.Data.Status.', ["done" "done"]);

            % Read on "another machine": the manifest's probe path is gone.
            delete(tc.Probe);
            o = DatasetOutputs(folder);
            tc.verifyTrue(o.has("behavior") && o.has("spikes") && o.has("sorting") && o.has("LFP") && o.has("MUA"));
            tc.verifyEqual(o.probeFile(), string(fullfile(folder, "p4.json")));
            U = o.readUnits();
            tc.verifyEqual(U.unitId, [0; 1], 'the units read in folder mode, probe file found');
            ws = warning('off', 'EphysProject:OutputsOnly');
            restore = onCleanup(@() warning(ws));
            P = EphysProject(tc.Dest);
            P.refresh();    % reads the manifests
            tc.verifyEqual(sort(P.datasetKeys()), tc.keys());
            d = P.Datasets(P.findByKey("s1/" + tc.Names(1)));
            tc.verifyEqual(string(d.ProbeFile), string(fullfile(folder, "p4.json")), ...
                'the dataset takes the probe file beside the manifest');
        end

        function leavesAnUntickedDatasetOut(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            dlg = tc.dialog();
            tc.setControl(dlg, "Dest", tc.Dest);
            tbl = findobj(dlg.Fig, 'Type', 'uitable');
            T = tbl.Data;
            T.Copy(2) = false;
            tbl.Data = T;
            dlg.start();
            dlg.wait(120);
            tc.verifyTrue(isfolder(fullfile(tc.Dest, "s1", tc.Names(1))));
            tc.verifyFalse(isfolder(fullfile(tc.Dest, "s1", tc.Names(2))));
        end

        function settingsAreTheDefaultsThenWhatTheWindowSaved(tc)
            s = AnalysisCopyDialog.settings();
            tc.verifyEqual(s.Signals, ["LFP" "MUA" "AUX"]);
            tc.verifyTrue(s.Spikes && s.Probe && ~s.SortedData);
            tc.verifyEqual([s.Sorting s.IfExists s.Verify s.Destination], ["essential" "overwrite" "size" ""], ...
                'nothing saved: the window''s defaults and no destination');
            dlg = tc.dialog();
            tc.verifyEqual(dlg.options().Signals, s.Signals, 'the window opens with the same defaults');
            tc.setControl(dlg, "LFP", false);
            tc.setControl(dlg, "SPIKE", true);
            tc.setControl(dlg, "Spikes", false);
            tc.setControl(dlg, "SortedData", true);
            tc.setControl(dlg, "Sorting", 'all');
            tc.setControl(dlg, "IfExists", 'skip');
            tc.setControl(dlg, "Hash", true);
            tc.setControl(dlg, "Dest", tc.Dest);
            close(dlg.Fig);   % the window saves its settings when it closes
            s = AnalysisCopyDialog.settings();
            tc.verifyEqual(s.Signals, ["MUA" "SPIKE" "AUX"]);
            tc.verifyFalse(s.Spikes);
            tc.verifyTrue(s.SortedData && s.Probe);
            tc.verifyEqual([s.Sorting s.IfExists s.Verify s.Destination], ["all" "skip" "hash" string(tc.Dest)]);
        end

        function refusesARelativeDestination(tc)
            dlg = tc.dialog();
            tc.setControl(dlg, "Dest", "relative\folder");
            tc.verifyWarning(@() dlg.start(), 'AnalysisCopyDialog:Refused');
            tc.verifyFalse(dlg.Running);
            tc.verifyEmpty(dlg.Transfer);
        end
    end

    methods (Access = private)
        function dlg = dialog(tc)
            dlg = AnalysisCopyDialog(tc.Datasets, Visible=false);
            tc.addTeardown(@() delete(dlg));
        end

        function setControl(~, dlg, name, value)
            c = findobj(dlg.Fig, 'Tag', "acd_" + name);
            c.Value = value;
        end

        function k = keys(tc)
            k = "s1/" + tc.Names;
        end
    end

    methods (Static, Access = private)
        function S = spikesFor(n)
            S = struct('detected', struct('ts', {{1, 2}}), 'conversion', struct('dataset', n));
        end
    end
end


function writeBytes(file, n)
fid = fopen(file, 'w');
fwrite(fid, zeros(1, n, 'uint8'));
fclose(fid);
end
