classdef test_PipelineScriptSave < matlab.unittest.TestCase
    %test_PipelineScriptSave  Each pipeline run saves its script in the project root.
    %   Project.SaveScript is on by default (and for a config file saved
    %   before it existed); a run then saves the config's standalone script
    %   as <Root>/pipeline_<name>.m, naming the run in its header, and the
    %   run record names the file. The script is standalone(cfg) apart from
    %   those header lines; a run of some steps says so; the next run
    %   replaces it; a file of that name that no run saved is left as it is
    %   (EphysPipeline:ScriptExists). Off, or a dry run: nothing is saved.
    %
    %   Usage:  runtests("test_PipelineScriptSave")

    properties (SetAccess = private)
        Root (1,1) string = ""
        Cfg = []
    end

    methods (TestClassSetup)
        function makeProject(tc)
            tc.Root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            rng(11);
            Fs = 30000; numAmp = 4; spb = 128; nSamp = 4 * spb;
            ampRaw = uint16(randi([0 65535], numAmp, nSamp));
            digRaw = zeros(1, nSamp); digRaw(50:70) = 1;
            folder = fullfile(tc.Root, "proj", "mouse1", "M1_260101_120000");
            mkdir(folder);
            writeSyntheticRHD(fullfile(folder, 'M1_260101_120000.rhd'), ampRaw, digRaw, Fs, spb);
            probe = fullfile(tc.Root, "probe.json");
            writeProbeMap(probe, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), ...
                'yc', (0:numAmp-1) * 20, 'kcoords', zeros(1, numAmp), 'n_chan', numAmp));
            cfg = EphysPipelineConfig();
            cfg.Project.Root = fullfile(tc.Root, "proj");
            cfg.Project.OutputRoot = fullfile(tc.Root, "out");
            cfg.Probe.DefaultProbeFile = probe;
            cfg.Spikes.Enabled = true;
            cfg.Spikes.Filter = false;
            cfg.Spikes.ThresholdMethod = "absolute";
            cfg.Spikes.Threshold = 2000;
            cfg.Spikes.Overwrite = true;
            tc.Cfg = cfg;
        end
    end

    methods (Test)
        function onByDefault(tc)
            tc.verifyTrue(EphysPipelineConfig().Project.SaveScript, "on in a new config");
            s = tc.Cfg.toStruct();
            s.Project = rmfield(s.Project, 'SaveScript');
            tc.verifyTrue(EphysPipelineConfig.fromStruct(s).Project.SaveScript, ...
                "on for a config saved before the option existed");
            cfg = tc.Cfg;
            cfg.Project.SaveScript = false;
            file = fullfile(tc.Root, "off.json");
            cfg.save(file);
            tc.verifyFalse(EphysPipelineConfig.load(file).Project.SaveScript, "off survives the JSON");
        end

        function runSavesScript(tc)
            cfg = tc.config("save test 1");
            pipe = tc.runPipeline(cfg);
            file = fullfile(cfg.Project.Root, "pipeline_save_test_1.m");
            tc.assertTrue(isfile(file), "saved as <Root>/pipeline_<name>.m");
            tc.verifyEqual(pipe.ScriptFile, EphysPipeline.scriptFileFor(pipe.Project.Root, cfg.Name), "ScriptFile names it");
            tc.verifyTrue(EphysPipeline.isSavedScript(file));
            rec = readJsonFile(pipe.RunRecordFile);
            tc.verifyEqual(string(rec.script), pipe.ScriptFile, "the run record names the script");
            txt = string(fileread(file));
            tc.verifyTrue(contains(txt, "% Saved by EphysPipeline.run, run " + string(rec.runId) + " "), ...
                "the header names the run, as the record does");
            tc.verifyFalse(contains(txt, "That run ran"), "a run of the enabled steps adds no note");
            tc.verifyEqual(body(txt), body(EphysPipelineScript.standalone(cfg)), ...
                "the script is the config's standalone script apart from its header lines");
            tc.verifyEqual(height(pipe.Results(pipe.Results.Step == "spikes" & pipe.Results.Status == "done", :)), 1, ...
                "the run itself is unchanged");
        end

        function someStepsAreNamed(tc)
            cfg = tc.config("save test 2");
            pipe = tc.runPipeline(cfg, Steps="probe");
            txt = string(fileread(pipe.ScriptFile));
            tc.verifyTrue(contains(txt, "% That run ran probe only; this script runs the enabled steps (probe, spikes)."), ...
                "a run of some steps says which; the script runs the enabled ones");
        end

        function nextRunReplacesIt(tc)
            cfg = tc.config("save test 3");
            pipe = tc.runPipeline(cfg);
            first = readJsonFile(pipe.RunRecordFile).runId;
            pipe = tc.runPipeline(cfg);
            second = readJsonFile(pipe.RunRecordFile).runId;
            tc.assertNotEqual(string(second), string(first));
            txt = string(fileread(pipe.ScriptFile));
            tc.verifyTrue(contains(txt, ", run " + string(second) + " ") && ~contains(txt, string(first)), ...
                "the second run's script replaced the first's");
        end

        function otherFileIsKept(tc)
            cfg = tc.config("save test 4");
            file = fullfile(cfg.Project.Root, "pipeline_save_test_4.m");
            mine = "disp('a script of my own')" + newline;
            fid = fopen(file, 'w'); fwrite(fid, char(mine), 'char'); fclose(fid);
            tc.addTeardown(@() delete(file));
            pipe = EphysPipeline(cfg);
            pipe.LogFcn = [];
            tc.verifyWarning(@() pipe.run(), 'EphysPipeline:ScriptExists');
            tc.verifyEqual(string(fileread(file)), mine, "the file no run saved is left as it is");
            tc.verifyEqual(pipe.ScriptFile, "");
            tc.verifyEqual(string(readJsonFile(pipe.RunRecordFile).script), "", "the record names no script");
        end

        function offOrDryRunSavesNone(tc)
            cfg = tc.config("save test 5");
            cfg.Project.SaveScript = false;
            pipe = tc.runPipeline(cfg);
            file = fullfile(cfg.Project.Root, "pipeline_save_test_5.m");
            tc.verifyFalse(isfile(file), "off: no script");
            tc.verifyEqual(pipe.ScriptFile, "");
            tc.verifyEqual(string(readJsonFile(pipe.RunRecordFile).script), "");
            cfg.Project.SaveScript = true;
            pipe = tc.runPipeline(cfg, DryRun=true);
            tc.verifyFalse(isfile(file), "a dry run saves no script");
            tc.verifyEqual(pipe.ScriptFile, "");
        end

        function outsideARun(tc)
            cfg = tc.config("save test 6");
            pipe = EphysPipeline(cfg);
            pipe.LogFcn = [];
            file = pipe.writeScript();
            tc.assertTrue(isfile(file), "writeScript saves the script on its own");
            txt = string(fileread(file));
            tc.verifyTrue(contains(txt, "% Saved by EphysPipeline.writeScript, outside a run.") ...
                && EphysPipeline.isSavedScript(file), "it says it was saved outside a run, and a run may replace it");
            pipe.run();
            tc.verifyEqual(pipe.ScriptFile, file);
            tc.verifyTrue(contains(string(fileread(file)), "% Saved by EphysPipeline.run, run "), "the run replaced it");
        end

        function fileNames(tc)
            tc.verifyEqual(EphysPipeline.scriptFileFor("root", "My config-1 (v2)"), ...
                string(fullfile('root', 'pipeline_My_config_1_v2.m')), "runs of other characters become one _");
            tc.verifyEqual(EphysPipeline.scriptFileFor("root", "  "), string(fullfile('root', 'pipeline_config.m')));
            tc.verifyEqual(EphysPipeline.scriptFileFor("root", "__a__"), string(fullfile('root', 'pipeline_a.m')));
        end
    end

    methods (Access = private)
        function cfg = config(tc, name)
            cfg = tc.Cfg;
            cfg.Name = name;
        end

        function pipe = runPipeline(~, cfg, varargin)
            pipe = EphysPipeline(cfg);
            pipe.LogFcn = [];
            pipe.run(varargin{:});
        end
    end
end


function L = body(txt)
%body  Script lines without the ones that differ between two saves.
L = splitlines(string(txt));
drop = startsWith(L, "% Generated ") | startsWith(L, "% " + EphysPipeline.ScriptMarker) ...
    | startsWith(L, "% The next run of this config") | startsWith(L, "% That run ran ");
L = L(~drop);
end
