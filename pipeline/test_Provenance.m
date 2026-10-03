classdef test_Provenance < matlab.unittest.TestCase
    %test_Provenance  Outputs record the code and config that wrote them; runs leave a record.
    %   ephysProvenance and provenanceForJson; a pipeline run writes its run
    %   record (pipeline_runs/<runId>_<name>.json) whether it finishes or is
    %   cancelled, and none on a dry run; the spikes file's
    %   conversion.provenance names the same run, the code and the config
    %   (which rebuilds the config); a step called on its own records the
    %   config but no run; a writer called directly records the code only;
    %   settings.json of a Kilosort4 dry run carries it as JSON.
    %
    %   Usage:  runtests("test_Provenance")

    properties (SetAccess = private)
        Root (1,1) string = ""
        ProbeFile (1,1) string = ""
        Cfg = []
    end

    methods (TestClassSetup)
        function makeProject(tc)
            tc.Root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            rng(7);
            Fs = 30000; numAmp = 4; spb = 128; nSamp = 4 * spb;
            ampRaw = uint16(randi([0 65535], numAmp, nSamp));
            digRaw = zeros(1, nSamp); digRaw(50:70) = 1;
            folder = fullfile(tc.Root, "proj", "mouse1", "M1_260101_120000");
            mkdir(folder);
            writeSyntheticRHD(fullfile(folder, 'M1_260101_120000.rhd'), ampRaw, digRaw, Fs, spb);
            tc.ProbeFile = fullfile(tc.Root, "probe.json");
            writeProbeMap(tc.ProbeFile, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), ...
                'yc', (0:numAmp-1) * 20, 'kcoords', zeros(1, numAmp), 'n_chan', numAmp));
            cfg = EphysPipelineConfig();
            cfg.Name = "provenance test";
            cfg.Project.Root = fullfile(tc.Root, "proj");
            cfg.Project.OutputRoot = fullfile(tc.Root, "out");
            cfg.Probe.DefaultProbeFile = tc.ProbeFile;
            cfg.Spikes.Enabled = true;
            cfg.Spikes.Filter = false;
            cfg.Spikes.ThresholdMethod = "absolute";
            cfg.Spikes.Threshold = 2000;
            cfg.Spikes.Overwrite = true;
            tc.Cfg = cfg;
        end
    end

    methods (Test)
        function provenanceStruct(tc)
            p = ephysProvenance(Config=tc.Cfg, RunId="r1");
            v = ephysVersion();
            tc.verifyEqual(p.runId, "r1");
            tc.verifyEqual([p.version p.commit p.code], [v.Version v.Commit v.Text], "the code version is ephysVersion's");
            tc.verifyEqual(p.matlab, string(version));
            tc.verifyTrue(EphysPipelineConfig.fromStruct(p.config).isequalConfig(tc.Cfg), "the config rebuilds the config");
            tc.verifyEmpty(ephysProvenance().config, "no config outside a pipeline");
            q = provenanceForJson(p);
            tc.verifyEqual(q.config.Spikes.MaxAmplitudeUV, "Inf", "non-finite numbers are written as config files write them");
            tc.verifyEqual(q.config.Parallel.MaxWorkers, "NaN");
            tc.verifyEqual(provenanceForJson(ephysProvenance()).config, [], "an empty config is []");
        end

        function runWritesRecordAndOutputs(tc)
            pipe = EphysPipeline(tc.Cfg);
            pipe.LogFcn = [];
            pipe.run();
            file = pipe.RunRecordFile;
            tc.assertTrue(isfile(file), "the run record exists");
            tc.verifyTrue(startsWith(file, fullfile(tc.Root, "out", "pipeline_runs")) ...
                && endsWith(file, "_provenance_test.json"), "it is <OutputRoot>/pipeline_runs/<runId>_<name>.json");
            rec = readJsonFile(file);
            tc.verifyEqual(string(rec.schema), "ephys-pipeline-run/1");
            tc.verifyEqual(string(rec.outcome), "finished");
            tc.verifyTrue(any(string(rec.steps) == "spikes"), "the steps run");
            tc.verifyEqual(string(rec.datasets(1).key), "mouse1/M1_260101_120000");
            res = rec.results;
            if iscell(res); res = [res{:}]; end
            spk = res(string({res.Step}) == "spikes");
            tc.assertNotEmpty(spk, "the Results rows");
            tc.verifyEqual(string(spk(1).Status), "done");
            tc.verifyTrue(EphysPipelineConfig.fromStruct(rec.config).isequalConfig(tc.Cfg), "the record's config rebuilds the config");
            M = load(spk(1).Output);
            p = M.conversion.provenance;
            tc.verifyEqual(p.runId, string(rec.runId), "the spikes file names the run");
            tc.verifyEqual(p.commit, ephysVersion().Commit);
            tc.verifyTrue(EphysPipelineConfig.fromStruct(p.config).isequalConfig(tc.Cfg), "and the config");
            tc.verifyEmpty(pipe.Provenance, "a run's provenance ends with the run");

            pipe.reset();
            pipe.runSpikeDetection();
            M2 = load(pipe.Results.Output(1));
            tc.verifyEqual(M2.conversion.provenance.runId, "", "a step called on its own is no run");
            tc.verifyTrue(EphysPipelineConfig.fromStruct(M2.conversion.provenance.config).isequalConfig(tc.Cfg), ...
                "but records the config");
        end

        function cancelledRunAndDryRun(tc)
            pipe = EphysPipeline(tc.Cfg);
            pipe.LogFcn = [];
            pipe.ProgressFcn = @(evt) pipe.cancel();
            pipe.run();
            tc.assertTrue(isfile(pipe.RunRecordFile), "a cancelled run leaves a record");
            tc.verifyEqual(string(readJsonFile(pipe.RunRecordFile).outcome), "cancelled");
            pipe.ProgressFcn = [];
            before = dir(fullfile(tc.Root, "out", "pipeline_runs", "*.json"));
            pipe.run(DryRun=true);
            after = dir(fullfile(tc.Root, "out", "pipeline_runs", "*.json"));
            tc.verifyEqual(pipe.RunRecordFile, "", "a dry run writes no record");
            tc.verifyEqual(numel(after), numel(before));
        end

        function directWriterAndSortingSettings(tc)
            ds = EphysDataset(fullfile(tc.Root, "proj", "mouse1", "M1_260101_120000"));
            ds.OutputDir = fullfile(tc.Root, "direct");
            r = ds.spikesToMat(File=fullfile(tc.Root, "direct", "x_spikes.mat"), ...
                DetectOptions=struct('Filter', false, 'ThresholdMethod', "absolute", 'Threshold', 2000));
            M = load(r.file);
            p = M.conversion.provenance;
            tc.verifyEqual([p.runId p.commit], ["" ephysVersion().Commit], "a direct call records the code, no run");
            tc.verifyEmpty(p.config, "and no config");
            ds.ProbeFile = tc.ProbeFile;
            ds.PythonExe = "C:\no\python.exe";
            dry = ds.runKilosort(DryRun=true);
            st = readJsonFile(dry.settingsPath);
            tc.verifyTrue(isfield(st, 'provenance') && string(st.provenance.commit) == ephysVersion().Commit, ...
                "settings.json records the code");
        end
    end
end
